extends Control

## Map renderer for the Embers of the Spire world. It is used by both the small HUD map
## and the fullscreen map opened with M.

var world_source: Node = null
var player_source: Node3D = null
var minimap_mode: bool = true
var _redraw_clock: float = 0.0
var _parchment: ImageTexture = null
var _trees: PackedVector2Array = PackedVector2Array()

const INK := Color(0.20, 0.13, 0.07, 1.0)
const HALO := Color(0.86, 0.76, 0.55, 0.9)

const MAP_BG := Color(0.035, 0.055, 0.047, 0.96)
const MAP_BORDER := Color(0.62, 0.48, 0.27, 0.95)
const ROAD_DARK := Color(0.12, 0.105, 0.085, 0.96)
const ROAD_LIGHT := Color(0.48, 0.40, 0.29, 0.92)
const PLAYER_COLOR := Color(0.98, 0.88, 0.63, 1.0)
const QUEST_GOLD := Color(1.0, 0.72, 0.28, 1.0)
const QUEST_RED := Color(0.96, 0.25, 0.19, 1.0)


func setup(world_node: Node, player_node: Node3D, is_minimap: bool = true) -> void:
	world_source = world_node
	player_source = player_node
	minimap_mode = is_minimap
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	queue_redraw()


# --- Розірваний Атлас: анімація шматка, що лягає на своє місце -------------------------------
const ATLAS_VOID := Color(0.035, 0.03, 0.028, 1.0)
const ATLAS_LAND_T: float = 1.5
const ATLAS_ANIM_LEN: float = 2.9
var _anim_id: String = ""
var _anim_t: float = 0.0
var _anim_wait: float = 0.0
var _anim_sfx: int = 0


func is_atlas_idle() -> bool:
	if _anim_id != "":
		return false
	for id in AtlasPieces.ORDER:
		if QuestManager.has_map_piece(id) and not QuestManager.is_map_piece_seen(id):
			return false
	return true


func _step_atlas_anim(delta: float) -> void:
	if _anim_id == "":
		_anim_wait -= delta
		if _anim_wait > 0.0:
			return
		for id in AtlasPieces.ORDER:
			if QuestManager.has_map_piece(id) and not QuestManager.is_map_piece_seen(id):
				_anim_id = id
				_anim_t = 0.0
				_anim_sfx = 0
				AudioManager.play_ui("journal_open", -5.0)
				break
		return
	_anim_t += delta
	if _anim_sfx == 0 and _anim_t >= ATLAS_LAND_T:
		_anim_sfx = 1
		AudioManager.play_ui("item_pickup", -2.0)
		AudioManager.play_ui("discover", -7.0)
	if _anim_t >= ATLAS_ANIM_LEN:
		QuestManager.mark_map_piece_seen(_anim_id)
		_anim_id = ""
		_anim_wait = 0.35


func _process(delta: float) -> void:
	if not minimap_mode and is_visible_in_tree() and world_source != null:
		_step_atlas_anim(delta)
	_redraw_clock += delta
	if _redraw_clock >= (0.10 if minimap_mode else 0.04):
		_redraw_clock = 0.0
		if visible:
			queue_redraw()


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var bounds := Rect2(Vector2.ZERO, size)
	draw_rect(bounds, MAP_BG, true)
	draw_rect(bounds, MAP_BORDER, false, 1.5, true)

	if world_source == null or player_source == null or not is_instance_valid(world_source) or not is_instance_valid(player_source):
		_draw_centered_text("КАРТА НЕДОСТУПНА", bounds, Color(0.85, 0.78, 0.65, 1.0), 16)
		return

	var snapshot: Dictionary = world_source.call("get_map_snapshot")
	if bool(snapshot.get("player_in_dungeon", false)):
		_draw_dungeon_map(snapshot, bounds)
	elif minimap_mode:
		_draw_minimap_world(snapshot, bounds)
	else:
		_draw_full_world_map(snapshot, bounds)

	if minimap_mode:
		draw_rect(bounds, MAP_BORDER, false, 2.0, true)


func _draw_minimap_world(snapshot: Dictionary, bounds: Rect2) -> void:
	var player_pos: Vector2 = snapshot.get("player_position", Vector2.ZERO)
	var map_rect := Rect2(Vector2(7.0, 24.0), Vector2(bounds.size.x - 14.0, bounds.size.y - 31.0))
	draw_string(ThemeDB.fallback_font, Vector2(12.0, 17.0), "ЗЕМЛІ ПОПЕЛУ", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color(0.82, 0.72, 0.54, 1.0))
	_draw_grid(map_rect, 5, Color(0.42, 0.46, 0.35, 0.16))
	_draw_biomes(snapshot, map_rect, true, player_pos)
	_draw_routes(snapshot, map_rect, true, player_pos)
	_draw_buildings(snapshot, map_rect, true, player_pos)
	_draw_npcs(snapshot, map_rect, true, player_pos)
	_draw_quest(snapshot, map_rect, true, player_pos)
	_draw_player_marker(map_rect.get_center(), true)
	_draw_compass(bounds)


func _draw_full_world_map(snapshot: Dictionary, bounds: Rect2) -> void:
	var world_size: Vector2 = snapshot.get("world_size", Vector2(972.0, 702.0))
	var pad := 18.0
	var available := Rect2(Vector2(pad, pad), bounds.size - Vector2(pad * 2.0, pad * 2.0))
	var aspect := world_size.x / maxf(world_size.y, 1.0)
	var map_w := available.size.x
	var map_h := map_w / aspect
	if map_h > available.size.y:
		map_h = available.size.y
		map_w = map_h * aspect
	var map_rect := Rect2(available.get_center() - Vector2(map_w, map_h) * 0.5, Vector2(map_w, map_h))

	if _parchment == null and snapshot.has("heights"):
		_build_parchment(snapshot)
	if _parchment:
		draw_texture_rect(_parchment, map_rect, false)
	else:
		draw_rect(map_rect, Color(0.78, 0.67, 0.47, 1.0), true)
	_draw_trees(map_rect)
	_draw_full_river(snapshot, map_rect, world_size)
	_draw_full_roads(snapshot, map_rect, world_size)
	_draw_full_places(snapshot, map_rect, world_size)
	_draw_eye_layer(snapshot, map_rect, world_size)
	_draw_atlas(snapshot, map_rect, world_size)
	_draw_quest(snapshot, map_rect, false, Vector2.ZERO)
	var player_pos: Vector2 = snapshot.get("player_position", Vector2.ZERO)
	_draw_player_marker(_world_to_full_map(player_pos, map_rect, world_size), false)
	_draw_compass_rose(map_rect)
	draw_rect(map_rect, INK, false, 2.5, true)
	draw_rect(map_rect.grow(-5.0), Color(INK.r, INK.g, INK.b, 0.55), false, 1.0, true)
	_draw_map_coordinates(map_rect, world_size)
	_draw_atlas_counter(snapshot, map_rect)


func _draw_dungeon_map(snapshot: Dictionary, bounds: Rect2) -> void:
	var map_rect := Rect2(Vector2(12.0, 34.0), bounds.size - Vector2(24.0, 46.0))
	draw_string(ThemeDB.fallback_font, Vector2(15.0, 23.0), "КАЗЕМАТИ СМЕРТІ", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(0.86, 0.72, 0.53, 1.0))
	_draw_grid(map_rect, 6, Color(0.48, 0.43, 0.34, 0.13))
	var center := map_rect.get_center()
	var unit := minf(map_rect.size.x / 118.0, map_rect.size.y / 70.0)
	var main_room := Rect2(center + Vector2(0.0, -17.0) * unit, Vector2(52.0, 34.0) * unit)
	var corridor := Rect2(center + Vector2(-54.0, -8.0) * unit, Vector2(57.0, 16.0) * unit)
	draw_rect(main_room, Color(0.24, 0.23, 0.20, 0.95), true)
	draw_rect(corridor, Color(0.20, 0.20, 0.18, 0.95), true)
	draw_rect(main_room, MAP_BORDER, false, 1.5)
	draw_rect(corridor, Color(0.46, 0.40, 0.30, 0.9), false, 1.2)

	var altar := _dungeon_to_screen(Vector2(12.0, 7.0), center, unit)
	var exit_point := _dungeon_to_screen(Vector2(-32.0, 0.0), center, unit)
	var player_pos: Vector2 = snapshot.get("player_position", Vector2.ZERO)
	var player_point := _dungeon_to_screen(player_pos, center, unit)
	draw_circle(altar, 5.0, Color(0.84, 0.56, 0.25, 1.0))
	draw_circle(exit_point, 4.5, Color(0.30, 0.75, 0.48, 1.0))
	draw_string(ThemeDB.fallback_font, altar + Vector2(8.0, -8.0), "Камінь Присяги", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(0.93, 0.82, 0.63, 1.0))
	draw_string(ThemeDB.fallback_font, exit_point + Vector2(-10.0, 17.0), "Вихід", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(0.62, 0.87, 0.69, 1.0))
	_draw_player_marker(player_point, true)


func _dungeon_to_screen(point: Vector2, center: Vector2, unit: float) -> Vector2:
	return center + Vector2(point.x, point.y) * unit


func _draw_grid(rect: Rect2, divisions: int, color: Color) -> void:
	for i in range(1, divisions):
		var x := rect.position.x + rect.size.x * float(i) / float(divisions)
		var y := rect.position.y + rect.size.y * float(i) / float(divisions)
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), color, 1.0, true)
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), color, 1.0, true)


func _draw_biomes(snapshot: Dictionary, rect: Rect2, mini: bool, center_pos: Vector2) -> void:
	var regions: Array = snapshot.get("regions", [])
	for region in regions:
		var pos: Vector2 = region.get("position", Vector2.ZERO)
		var point := _map_point(pos, rect, mini, center_pos, snapshot)
		var radius_world := float(region.get("radius", 35.0))
		var radius_px := radius_world * _map_scale(rect, mini, snapshot)
		var tint: Color = region.get("color", Color(0.2, 0.28, 0.2, 0.2))
		draw_circle(point, maxf(radius_px, 2.0), tint)


func _draw_routes(snapshot: Dictionary, rect: Rect2, mini: bool, center_pos: Vector2) -> void:
	var routes: Array = snapshot.get("routes", [])
	for route_variant in routes:
		var route: PackedVector2Array = route_variant
		if route.size() < 2:
			continue
		var points := PackedVector2Array()
		for world_point in route:
			points.append(_map_point(world_point, rect, mini, center_pos, snapshot))
		draw_polyline(points, ROAD_DARK, 4.2 if not mini else 3.0, true)
		draw_polyline(points, ROAD_LIGHT, 2.0 if not mini else 1.2, true)


func _draw_landmarks(snapshot: Dictionary, rect: Rect2) -> void:
	var world_size: Vector2 = snapshot.get("world_size", Vector2(972.0, 702.0))
	var landmarks: Array = snapshot.get("landmarks", [])
	for landmark in landmarks:
		var pos: Vector2 = landmark.get("position", Vector2.ZERO)
		var point := _world_to_full_map(pos, rect, world_size)
		var color_value: Color = landmark.get("color", Color(0.9, 0.55, 0.25, 1.0))
		draw_circle(point, 7.0, Color(0.02, 0.02, 0.02, 0.85))
		draw_circle(point, 4.5, color_value)
		draw_string(ThemeDB.fallback_font, point + Vector2(9.0, -6.0), str(landmark.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.88, 0.83, 0.70, 1.0))


func _draw_buildings(snapshot: Dictionary, rect: Rect2, mini: bool, center_pos: Vector2) -> void:
	var world_size: Vector2 = snapshot.get("world_size", Vector2(972.0, 702.0))
	var buildings: Array = snapshot.get("buildings", [])
	for building in buildings:
		var pos: Vector2 = building.get("position", Vector2.ZERO)
		var point := _map_point(pos, rect, mini, center_pos, snapshot)
		var kind := str(building.get("kind", ""))
		var color_value := _building_color(kind)
		var radius := 3.4 if mini else 5.0
		draw_circle(point, radius + 1.8, Color(0.02, 0.025, 0.02, 0.92))
		draw_circle(point, radius, color_value)
		if not mini:
			var label := str(building.get("name", ""))
			draw_string(ThemeDB.fallback_font, point + Vector2(7.0, -5.0), label, HORIZONTAL_ALIGNMENT_LEFT, 155.0, 10, Color(0.84, 0.81, 0.73, 1.0))


func _draw_npcs(snapshot: Dictionary, rect: Rect2, mini: bool, center_pos: Vector2) -> void:
	var npcs: Array = snapshot.get("npcs", [])
	for npc in npcs:
		var pos: Vector2 = npc.get("position", Vector2.ZERO)
		var point := _map_point(pos, rect, mini, center_pos, snapshot)
		draw_circle(point, 4.1 if mini else 4.7, Color(0.10, 0.16, 0.18, 1.0))
		draw_circle(point, 2.8 if mini else 3.2, Color(0.48, 0.80, 0.79, 1.0))
		if not mini:
			draw_string(ThemeDB.fallback_font, point + Vector2(6.0, 3.0), str(npc.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, 120.0, 9, Color(0.63, 0.79, 0.76, 1.0))


func _draw_quest(snapshot: Dictionary, rect: Rect2, mini: bool, center_pos: Vector2) -> void:
	if not bool(snapshot.get("quest_visible", false)):
		return
	var pos: Vector2 = snapshot.get("quest_position", Vector2.ZERO)
	var point := _map_point(pos, rect, mini, center_pos, snapshot)
	var branch := str(snapshot.get("quest_branch", "principality"))
	var tint := QUEST_RED if branch == "mountain" else QUEST_GOLD
	if mini:
		draw_circle(point, 9.0, Color(tint.r, tint.g, tint.b, 0.22))
	else:
		draw_arc(point, 10.0, 0.0, TAU, 24, Color(tint.r, tint.g, tint.b, 0.9), 1.6, true)
	draw_circle(point, 5.6 if mini else 6.0, tint)
	draw_circle(point, 2.1, Color(0.08, 0.06, 0.04, 1.0))
	if not mini:
		draw_string(ThemeDB.fallback_font, point + Vector2(10.0, -8.0), "ЦІЛЬ", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, tint)


func _draw_player_marker(point: Vector2, mini: bool) -> void:
	if player_source == null or not is_instance_valid(player_source):
		return
	var forward: Vector3 = -player_source.global_transform.basis.z
	var direction := Vector2(forward.x, forward.z).normalized()
	if direction.length_squared() < 0.01:
		direction = Vector2(0.0, -1.0)
	var perpendicular := Vector2(-direction.y, direction.x)
	var length := 10.0 if mini else 13.0
	var points := PackedVector2Array([
		point + direction * length,
		point - direction * length * 0.70 + perpendicular * length * 0.58,
		point - direction * length * 0.70 - perpendicular * length * 0.58
	])
	draw_colored_polygon(points, Color(0.02, 0.025, 0.02, 1.0))
	var inner := PackedVector2Array([
		point + direction * (length - 2.0),
		point - direction * length * 0.52 + perpendicular * length * 0.43,
		point - direction * length * 0.52 - perpendicular * length * 0.43
	])
	draw_colored_polygon(inner, PLAYER_COLOR)


func _draw_compass(bounds: Rect2) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(bounds.size.x - 20.0, 18.0), "N", HORIZONTAL_ALIGNMENT_CENTER, 14.0, 11, Color(0.92, 0.84, 0.67, 1.0))
	draw_line(Vector2(bounds.size.x - 20.0, 23.0), Vector2(bounds.size.x - 20.0, 29.0), MAP_BORDER, 1.0, true)


func _draw_map_coordinates(rect: Rect2, world_size: Vector2) -> void:
	var coords := ["ЗАХІД", "СХІД"]
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(2.0, -4.0), "ПІВНІЧ", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(0.75, 0.72, 0.62, 0.85))
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(2.0, rect.size.y + 14.0), coords[0], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(0.75, 0.72, 0.62, 0.85))
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(rect.size.x - 38.0, rect.size.y + 14.0), coords[1], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(0.75, 0.72, 0.62, 0.85))


func _building_color(kind: String) -> Color:
	match kind:
		"castle", "waterfort": return Color(0.83, 0.65, 0.38, 1.0)
		"forge": return Color(0.91, 0.43, 0.22, 1.0)
		"church": return Color(0.62, 0.76, 0.65, 1.0)
		"tower": return Color(0.64, 0.72, 0.81, 1.0)
		"crypt", "ruins", "lair": return Color(0.72, 0.56, 0.48, 1.0)
		"village", "camp", "hut": return Color(0.72, 0.65, 0.46, 1.0)
		_: return Color(0.67, 0.68, 0.57, 1.0)


func _map_scale(rect: Rect2, mini: bool, snapshot: Dictionary) -> float:
	if mini:
		return minf(rect.size.x / 360.0, rect.size.y / 360.0)
	var world_size: Vector2 = snapshot.get("world_size", Vector2(972.0, 702.0))
	return minf(rect.size.x / world_size.x, rect.size.y / world_size.y)


func _map_point(point: Vector2, rect: Rect2, mini: bool, center_pos: Vector2, snapshot: Dictionary) -> Vector2:
	if mini:
		var scale_value := _map_scale(rect, true, snapshot)
		return rect.get_center() + Vector2(point.x - center_pos.x, point.y - center_pos.y) * scale_value
	var world_size: Vector2 = snapshot.get("world_size", Vector2(972.0, 702.0))
	return _world_to_full_map(point, rect, world_size)


func _world_to_full_map(point: Vector2, rect: Rect2, world_size: Vector2) -> Vector2:
	return rect.position + Vector2(point.x / maxf(world_size.x, 1.0) * rect.size.x, point.y / maxf(world_size.y, 1.0) * rect.size.y)


# --- Стилізований пергаментний атлас -------------------------------------------------

func _bilinear(heights: PackedFloat32Array, cols: int, rows: int, u: float, v: float) -> float:
	var fx := clampf(u, 0.0, 1.0) * float(cols - 1)
	var fy := clampf(v, 0.0, 1.0) * float(rows - 1)
	var x0 := int(fx)
	var y0 := int(fy)
	var x1 := mini(x0 + 1, cols - 1)
	var y1 := mini(y0 + 1, rows - 1)
	var tx := fx - float(x0)
	var ty := fy - float(y0)
	var top := lerpf(heights[y0 * cols + x0], heights[y0 * cols + x1], tx)
	var bottom := lerpf(heights[y1 * cols + x0], heights[y1 * cols + x1], tx)
	return lerpf(top, bottom, ty)


func _build_parchment(snapshot: Dictionary) -> void:
	var heights: PackedFloat32Array = snapshot["heights"]
	var cols: int = int(snapshot["height_cols"])
	var rows: int = int(snapshot["height_rows"])
	var map_world: Vector2 = snapshot.get("world_size", Vector2(1206.0, 864.0))
	var img_w := 520
	var img_h := int(round(float(img_w) * map_world.y / maxf(map_world.x, 1.0)))
	var field := PackedFloat32Array()
	field.resize(img_w * img_h)
	for y in range(img_h):
		for x in range(img_w):
			field[y * img_w + x] = _bilinear(heights, cols, rows, float(x) / float(img_w - 1), float(y) / float(img_h - 1))

	var grain := FastNoiseLite.new()
	grain.seed = 4242
	grain.frequency = 0.035
	grain.fractal_octaves = 3
	var fiber := FastNoiseLite.new()
	fiber.seed = 77
	fiber.frequency = 0.45
	var data := PackedByteArray()
	data.resize(img_w * img_h * 3)
	var base_a := Color(0.86, 0.76, 0.56)
	var base_b := Color(0.74, 0.62, 0.41)
	var rock := Color(0.58, 0.49, 0.37)
	for y in range(img_h):
		for x in range(img_w):
			var h := field[y * img_w + x]
			var n := grain.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var col := base_a.lerp(base_b, n)
			col = col.lerp(rock, clampf(h / 110.0, 0.0, 1.0) * 0.45)
			col = col.darkened((fiber.get_noise_2d(float(x), float(y)) * 0.5 + 0.5) * 0.06)
			var xl := field[y * img_w + maxi(x - 1, 0)]
			var xr := field[y * img_w + mini(x + 1, img_w - 1)]
			var yu := field[maxi(y - 1, 0) * img_w + x]
			var yd := field[mini(y + 1, img_h - 1) * img_w + x]
			# Світло з північного заходу: схили, звернені на північ-захід, світліші.
			var shade := clampf(((xl - xr) + (yu - yd)) * 0.045, -0.3, 0.3)
			col = col.lightened(shade) if shade > 0.0 else col.darkened(-shade)
			var level := floori(h / 6.0)
			var on_line := level != floori(xr / 6.0) or level != floori(yd / 6.0)
			if on_line:
				var strong := level % 4 == 0 or floori(xr / 6.0) % 4 == 0 or floori(yd / 6.0) % 4 == 0
				col = col.lerp(INK, 0.78 if strong else 0.38)
			# Постарілі краї.
			var edge := maxf(absf(float(x) / float(img_w) - 0.5), absf(float(y) / float(img_h) - 0.5)) * 2.0
			col = col.darkened(smoothstep(0.78, 1.0, edge) * 0.38)
			var i := (y * img_w + x) * 3
			data[i] = int(clampf(col.r, 0.0, 1.0) * 255.0)
			data[i + 1] = int(clampf(col.g, 0.0, 1.0) * 255.0)
			data[i + 2] = int(clampf(col.b, 0.0, 1.0) * 255.0)
	_parchment = ImageTexture.create_from_image(Image.create_from_data(img_w, img_h, false, Image.FORMAT_RGB8, data))
	_scatter_trees(snapshot, field, img_w, img_h)


func _dist_to_polyline(point: Vector2, line: PackedVector2Array) -> float:
	var best := 1.0e9
	for i in range(line.size() - 1):
		var closest := Geometry2D.get_closest_point_to_segment(point, line[i], line[i + 1])
		best = minf(best, point.distance_to(closest))
	return best


func _scatter_trees(snapshot: Dictionary, field: PackedFloat32Array, img_w: int, img_h: int) -> void:
	_trees = PackedVector2Array()
	var world_size: Vector2 = snapshot.get("world_size", Vector2(972.0, 702.0))
	var forest := FastNoiseLite.new()
	forest.seed = 909
	forest.frequency = 0.011
	forest.fractal_octaves = 2
	var rng := RandomNumberGenerator.new()
	rng.seed = 31337
	var lines: Array[PackedVector2Array] = []
	for route_variant in snapshot.get("routes", []):
		var route: PackedVector2Array = route_variant
		var scaled := PackedVector2Array()
		for p in route:
			scaled.append(Vector2(p.x / world_size.x * float(img_w), p.y / world_size.y * float(img_h)))
		lines.append(scaled)
	var river := PackedVector2Array()
	for p in snapshot.get("river", PackedVector2Array()):
		river.append(Vector2(p.x / world_size.x * float(img_w), p.y / world_size.y * float(img_h)))
	var places := PackedVector2Array()
	for b in snapshot.get("buildings", []):
		var bp: Vector2 = b.get("position", Vector2.ZERO)
		places.append(Vector2(bp.x / world_size.x * float(img_w), bp.y / world_size.y * float(img_h)))
	var step := 8.0
	var y := 6.0
	while y < float(img_h) - 6.0:
		var x := 6.0
		while x < float(img_w) - 6.0:
			var p := Vector2(x + rng.randf_range(-3.0, 3.0), y + rng.randf_range(-3.0, 3.0))
			var h := field[clampi(int(p.y), 0, img_h - 1) * img_w + clampi(int(p.x), 0, img_w - 1)]
			var density := forest.get_noise_2d(p.x, p.y)
			if density > 0.12 and h < 20.0 and rng.randf() < 0.45 + density:
				var blocked := false
				for place in places:
					if place.distance_to(p) < 17.0:
						blocked = true
						break
				if not blocked:
					for line in lines:
						if _dist_to_polyline(p, line) < 4.5:
							blocked = true
							break
				if not blocked and river.size() > 1 and _dist_to_polyline(p, river) < 6.0:
					blocked = true
				if not blocked:
					_trees.append(Vector2(p.x / float(img_w), p.y / float(img_h)))
			x += step
		y += step


func _draw_trees(map_rect: Rect2) -> void:
	for t in _trees:
		var p := map_rect.position + Vector2(t.x * map_rect.size.x, t.y * map_rect.size.y)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0.0, -5.0), p + Vector2(-2.8, 1.0), p + Vector2(2.8, 1.0)]), Color(0.22, 0.30, 0.16, 0.92))
		draw_colored_polygon(PackedVector2Array([p + Vector2(0.0, -2.5), p + Vector2(-3.4, 3.2), p + Vector2(3.4, 3.2)]), Color(0.19, 0.27, 0.14, 0.95))
		draw_line(p + Vector2(0.0, 3.2), p + Vector2(0.0, 5.0), INK_SOFT, 1.0)


const INK_SOFT := Color(0.30, 0.20, 0.11, 0.9)


func _smooth(points: PackedVector2Array, subdivisions: int = 7) -> PackedVector2Array:
	if points.size() < 3:
		return points
	var result := PackedVector2Array()
	for i in range(points.size() - 1):
		var p0 := points[maxi(i - 1, 0)]
		var p1 := points[i]
		var p2 := points[i + 1]
		var p3 := points[mini(i + 2, points.size() - 1)]
		for s in range(subdivisions):
			var t := float(s) / float(subdivisions)
			var t2 := t * t
			var t3 := t2 * t
			result.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	result.append(points[points.size() - 1])
	return result


func _draw_full_river(snapshot: Dictionary, map_rect: Rect2, world_size: Vector2) -> void:
	var river: PackedVector2Array = snapshot.get("river", PackedVector2Array())
	if river.size() < 2:
		return
	var pts := PackedVector2Array()
	for p in river:
		pts.append(_world_to_full_map(p, map_rect, world_size))
	pts = _smooth(pts)
	draw_polyline(pts, Color(0.14, 0.22, 0.26, 0.9), 6.0, true)
	draw_polyline(pts, Color(0.38, 0.58, 0.62, 1.0), 3.6, true)
	draw_polyline(pts, Color(0.62, 0.78, 0.76, 0.7), 1.2, true)


func _draw_dashed(points: PackedVector2Array, color: Color, width: float, dash: float, gap: float) -> void:
	var drawing := true
	var carry := 0.0
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var seg := a.distance_to(b)
		if seg < 0.01:
			continue
		var dir := (b - a) / seg
		var pos := 0.0
		while pos < seg:
			var target := dash if drawing else gap
			var step := minf(target - carry, seg - pos)
			if drawing:
				draw_line(a + dir * pos, a + dir * (pos + step), color, width, true)
			pos += step
			carry += step
			if carry >= target - 0.001:
				carry = 0.0
				drawing = not drawing


func _draw_full_roads(snapshot: Dictionary, map_rect: Rect2, world_size: Vector2) -> void:
	for route_variant in snapshot.get("routes", []):
		var route: PackedVector2Array = route_variant
		if route.size() < 2:
			continue
		var pts := PackedVector2Array()
		for p in route:
			pts.append(_world_to_full_map(p, map_rect, world_size))
		pts = _smooth(pts)
		draw_polyline(pts, Color(0.93, 0.85, 0.66, 0.55), 4.2, true)
		_draw_dashed(pts, Color(0.26, 0.15, 0.08, 0.95), 2.0, 7.0, 4.0)


func _eye_torn_polygon(center: Vector2, radius: float, map_rect: Rect2) -> PackedVector2Array:
	## Рвана межа вирваного фрагмента навколо Ока (детермінована: однакова до і після зшивання).
	var pts := PackedVector2Array()
	var n := 26
	for i in range(n):
		var a := TAU * float(i) / float(n)
		var h := fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)
		var r := radius * (0.8 + 0.32 * h)
		var p := center + Vector2(cos(a), sin(a)) * r
		pts.append(Vector2(clampf(p.x, map_rect.position.x, map_rect.end.x), clampf(p.y, map_rect.position.y, map_rect.end.y)))
	return pts


func _draw_eye_layer(snapshot: Dictionary, map_rect: Rect2, world_size: Vector2) -> void:
	var eye_world: Vector2 = snapshot.get("eye_position", Vector2(-1000.0, -1000.0))
	var center := _world_to_full_map(eye_world, map_rect, world_size)
	var font := ThemeDB.fallback_font
	if not bool(snapshot.get("eye_known", false)) or _atlas_hidden(AtlasPieces.FINAL, snapshot):
		return # місце Ока ховає відсутній шматок «Чорна Гора»
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
	draw_arc(center, 14.0 + 4.0 * pulse, 0.0, TAU, 24, Color(0.95, 0.25, 0.1, 0.55), 2.0, true)
	var eye := PackedVector2Array([Vector2(-12, 0), Vector2(-6, -6), Vector2(0, -7), Vector2(6, -6), Vector2(12, 0), Vector2(6, 6), Vector2(0, 7), Vector2(-6, 6)])
	for i in range(eye.size()):
		eye[i] += center
	draw_colored_polygon(eye, Color(0.85, 0.12, 0.06))
	draw_circle(center, 3.2, Color(0.04, 0.02, 0.02))
	draw_string(font, center + Vector2(16.0, -12.0), "ОКО", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.55, 0.06, 0.04))
	var routes: Array = snapshot.get("routes", [])
	if routes.size() > 1:
		var line := PackedVector2Array()
		for rp in routes[1]:
			line.append(_world_to_full_map(rp, map_rect, world_size))
		line = _smooth(line)
		_draw_dashed(line, Color(0.7, 0.1, 0.06, 0.95), 3.0, 9.0, 5.0)
	var caption := "ШЛЯХ ДО ОКА:  тракт із Села Попелу на північний захід  →  серпантин Чорної Гори  →  вершина"
	var cs := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11)
	var plate := Rect2(Vector2(map_rect.position.x + 10.0, map_rect.end.y - 26.0), cs + Vector2(14.0, 8.0))
	draw_rect(plate, Color(0.1, 0.07, 0.04, 0.85), true)
	draw_string(font, plate.position + Vector2(7.0, cs.y + 1.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color(0.95, 0.85, 0.62))


func _draw_compass_rose(map_rect: Rect2) -> void:
	var c := map_rect.end - Vector2(52.0, 52.0)
	var r := 26.0
	draw_arc(c, r * 0.62, 0.0, TAU, 28, Color(INK.r, INK.g, INK.b, 0.6), 1.0, true)
	var north := PackedVector2Array([c + Vector2(0.0, -r), c + Vector2(-5.0, 0.0), c + Vector2(5.0, 0.0)])
	var south := PackedVector2Array([c + Vector2(0.0, r * 0.75), c + Vector2(-5.0, 0.0), c + Vector2(5.0, 0.0)])
	var west := PackedVector2Array([c + Vector2(-r * 0.75, 0.0), c + Vector2(0.0, -5.0), c + Vector2(0.0, 5.0)])
	var east := PackedVector2Array([c + Vector2(r * 0.75, 0.0), c + Vector2(0.0, -5.0), c + Vector2(0.0, 5.0)])
	draw_colored_polygon(north, Color(0.6, 0.15, 0.1, 0.95))
	for poly in [south, west, east]:
		draw_colored_polygon(poly, INK)
	draw_string(ThemeDB.fallback_font, c + Vector2(-5.0, -r - 4.0), "N", HORIZONTAL_ALIGNMENT_CENTER, 10.0, 13, INK)


func _draw_icon(kind: String, p: Vector2, s: float) -> void:
	var fill := Color(0.55, 0.33, 0.20)
	var stone := Color(0.52, 0.48, 0.42)
	match kind:
		"castle", "royal", "waterfort":
			var body := Rect2(p + Vector2(-s, -s * 0.35), Vector2(s * 2.0, s * 1.05))
			draw_rect(body, Color(0.50, 0.24, 0.17), true)
			for sx in [-1.0, 1.0]:
				var tw := Rect2(p + Vector2(sx * s - s * 0.35, -s * 0.95), Vector2(s * 0.7, s * 1.65))
				draw_rect(tw, Color(0.58, 0.28, 0.20), true)
				draw_rect(tw, INK, false, 1.2)
				draw_colored_polygon(PackedVector2Array([tw.position + Vector2(-1.0, 0.0), tw.position + Vector2(tw.size.x + 1.0, 0.0), tw.position + Vector2(tw.size.x * 0.5, -s * 0.5)]), INK)
			draw_rect(body, INK, false, 1.2)
			draw_rect(Rect2(p + Vector2(-s * 0.2, s * 0.05), Vector2(s * 0.4, s * 0.65)), INK, true)
		"tower":
			var tw := Rect2(p + Vector2(-s * 0.38, -s * 0.5), Vector2(s * 0.76, s * 1.25))
			draw_rect(tw, stone, true)
			draw_rect(tw, INK, false, 1.2)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.55, -s * 0.5), p + Vector2(s * 0.55, -s * 0.5), p + Vector2(0.0, -s * 1.15)]), Color(0.38, 0.22, 0.2))
			draw_polyline(PackedVector2Array([p + Vector2(-s * 0.55, -s * 0.5), p + Vector2(0.0, -s * 1.15), p + Vector2(s * 0.55, -s * 0.5), p + Vector2(-s * 0.55, -s * 0.5)]), INK, 1.2)
		"village", "camp", "hut":
			var houses := [Vector2(-s * 0.55, 0.0), Vector2(s * 0.55, 0.15)] if kind == "village" else [Vector2.ZERO]
			for off in houses:
				var hp: Vector2 = p + off
				var hs := s * (0.62 if kind == "village" else 0.85)
				if kind == "camp":
					draw_colored_polygon(PackedVector2Array([hp + Vector2(-hs, hs * 0.6), hp + Vector2(hs, hs * 0.6), hp + Vector2(0.0, -hs)]), Color(0.62, 0.42, 0.24))
					draw_polyline(PackedVector2Array([hp + Vector2(-hs, hs * 0.6), hp + Vector2(0.0, -hs), hp + Vector2(hs, hs * 0.6), hp + Vector2(-hs, hs * 0.6)]), INK, 1.2)
				else:
					draw_rect(Rect2(hp + Vector2(-hs * 0.8, -hs * 0.1), Vector2(hs * 1.6, hs * 0.85)), Color(0.66, 0.50, 0.32), true)
					draw_rect(Rect2(hp + Vector2(-hs * 0.8, -hs * 0.1), Vector2(hs * 1.6, hs * 0.85)), INK, false, 1.1)
					draw_colored_polygon(PackedVector2Array([hp + Vector2(-hs * 1.0, -hs * 0.1), hp + Vector2(hs * 1.0, -hs * 0.1), hp + Vector2(0.0, -hs * 0.85)]), Color(0.45, 0.22, 0.16))
					draw_polyline(PackedVector2Array([hp + Vector2(-hs, -hs * 0.1), hp + Vector2(0.0, -hs * 0.85), hp + Vector2(hs, -hs * 0.1)]), INK, 1.1)
		"church":
			draw_rect(Rect2(p + Vector2(-s * 0.7, -s * 0.1), Vector2(s * 1.4, s * 0.85)), Color(0.60, 0.62, 0.55), true)
			draw_rect(Rect2(p + Vector2(-s * 0.7, -s * 0.1), Vector2(s * 1.4, s * 0.85)), INK, false, 1.2)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.85, -s * 0.1), p + Vector2(s * 0.85, -s * 0.1), p + Vector2(0.0, -s * 0.7)]), Color(0.38, 0.30, 0.26))
			draw_line(p + Vector2(0.0, -s * 0.7), p + Vector2(0.0, -s * 1.3), INK, 1.4)
			draw_line(p + Vector2(-s * 0.3, -s * 1.05), p + Vector2(s * 0.3, -s * 1.05), INK, 1.4)
		"crypt":
			draw_rect(Rect2(p + Vector2(-s * 0.5, -s * 0.2), Vector2(s, s * 0.95)), stone, true)
			draw_circle(p + Vector2(0.0, -s * 0.2), s * 0.5, stone)
			draw_arc(p + Vector2(0.0, -s * 0.2), s * 0.5, PI, TAU, 12, INK, 1.2, true)
			draw_line(p + Vector2(-s * 0.5, -s * 0.2), p + Vector2(-s * 0.5, s * 0.75), INK, 1.2)
			draw_line(p + Vector2(s * 0.5, -s * 0.2), p + Vector2(s * 0.5, s * 0.75), INK, 1.2)
			draw_line(p + Vector2(-s * 0.5, s * 0.75), p + Vector2(s * 0.5, s * 0.75), INK, 1.2)
			draw_line(p + Vector2(0.0, -s * 0.55), p + Vector2(0.0, s * 0.15), INK, 1.4)
			draw_line(p + Vector2(-s * 0.25, -s * 0.3), p + Vector2(s * 0.25, -s * 0.3), INK, 1.4)
		"ruins":
			for k in range(3):
				var px := float(k - 1) * s * 0.62
				var ph := s * (1.1 - 0.35 * float(k % 2) - 0.1 * float(k))
				draw_rect(Rect2(p + Vector2(px - s * 0.2, s * 0.7 - ph), Vector2(s * 0.4, ph)), stone, true)
				draw_rect(Rect2(p + Vector2(px - s * 0.2, s * 0.7 - ph), Vector2(s * 0.4, ph)), INK, false, 1.1)
			draw_line(p + Vector2(-s, s * 0.7), p + Vector2(s, s * 0.7), INK, 1.4)
		"lair":
			draw_circle(p, s * 0.85, Color(0.52, 0.16, 0.12))
			draw_arc(p, s * 0.85, 0.0, TAU, 20, INK, 1.4, true)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.6, -s * 0.5), p + Vector2(-s * 0.95, -s * 1.15), p + Vector2(-s * 0.15, -s * 0.7)]), INK)
			draw_colored_polygon(PackedVector2Array([p + Vector2(s * 0.6, -s * 0.5), p + Vector2(s * 0.95, -s * 1.15), p + Vector2(s * 0.15, -s * 0.7)]), INK)
			draw_circle(p + Vector2(-s * 0.3, -s * 0.05), s * 0.17, HALO)
			draw_circle(p + Vector2(s * 0.3, -s * 0.05), s * 0.17, HALO)
		"forge":
			draw_rect(Rect2(p + Vector2(-s * 0.7, -s * 0.1), Vector2(s * 1.4, s * 0.45)), Color(0.34, 0.31, 0.30), true)
			draw_rect(Rect2(p + Vector2(-s * 0.3, s * 0.35), Vector2(s * 0.6, s * 0.4)), Color(0.34, 0.31, 0.30), true)
			draw_rect(Rect2(p + Vector2(-s * 0.7, -s * 0.1), Vector2(s * 1.4, s * 0.45)), INK, false, 1.2)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.25, -s * 0.15), p + Vector2(s * 0.25, -s * 0.15), p + Vector2(0.0, -s * 0.95)]), Color(0.88, 0.42, 0.14))
		"gate":
			for sx in [-1.0, 1.0]:
				draw_rect(Rect2(p + Vector2(sx * s * 0.7 - s * 0.25, -s * 0.7), Vector2(s * 0.5, s * 1.45)), stone, true)
				draw_rect(Rect2(p + Vector2(sx * s * 0.7 - s * 0.25, -s * 0.7), Vector2(s * 0.5, s * 1.45)), INK, false, 1.2)
			draw_rect(Rect2(p + Vector2(-s * 0.95, -s * 0.95), Vector2(s * 1.9, s * 0.35)), stone, true)
			draw_rect(Rect2(p + Vector2(-s * 0.95, -s * 0.95), Vector2(s * 1.9, s * 0.35)), INK, false, 1.2)
		"obelisk":
			for k in range(3):
				var ox := float(k - 1) * s * 0.7
				var oh := s * (0.9 + 0.3 * float(k == 1))
				draw_colored_polygon(PackedVector2Array([p + Vector2(ox - s * 0.2, s * 0.6), p + Vector2(ox + s * 0.2, s * 0.6), p + Vector2(ox + s * 0.1, s * 0.6 - oh), p + Vector2(ox - s * 0.1, s * 0.6 - oh)]), Color(0.48, 0.52, 0.42))
				draw_polyline(PackedVector2Array([p + Vector2(ox - s * 0.2, s * 0.6), p + Vector2(ox - s * 0.1, s * 0.6 - oh), p + Vector2(ox + s * 0.1, s * 0.6 - oh), p + Vector2(ox + s * 0.2, s * 0.6)]), INK, 1.1)
		"mountain":
			var peaks := [[-0.9, 0.2, 0.7], [0.9, 0.3, 0.6], [0.0, 0.0, 1.15]]
			for peak in peaks:
				var cx: float = p.x + float(peak[0]) * s
				var base_y: float = p.y + s * 0.75
				var top := Vector2(cx, base_y - float(peak[2]) * s * 1.6)
				var hw := float(peak[2]) * s * 0.95
				draw_colored_polygon(PackedVector2Array([Vector2(cx - hw, base_y), top, Vector2(cx + hw, base_y)]), Color(0.32, 0.27, 0.24))
				draw_colored_polygon(PackedVector2Array([top, Vector2(cx + hw, base_y), Vector2(cx + hw * 0.1, base_y)]), Color(0.20, 0.16, 0.14))
				draw_colored_polygon(PackedVector2Array([top, top + Vector2(-hw * 0.28, hw * 0.55), top + Vector2(hw * 0.28, hw * 0.55)]), Color(0.9, 0.86, 0.76))
				draw_polyline(PackedVector2Array([Vector2(cx - hw, base_y), top, Vector2(cx + hw, base_y)]), INK, 1.3)
		_:
			draw_circle(p, s * 0.55, fill)
			draw_arc(p, s * 0.55, 0.0, TAU, 14, INK, 1.2, true)


func _label_candidates(p: Vector2, size_px: Vector2, half: float) -> Array:
	return [
		Rect2(p + Vector2(half + 4.0, -size_px.y * 0.5), size_px),
		Rect2(p + Vector2(-half - 4.0 - size_px.x, -size_px.y * 0.5), size_px),
		Rect2(p + Vector2(-size_px.x * 0.5, half + 4.0), size_px),
		Rect2(p + Vector2(-size_px.x * 0.5, -half - 4.0 - size_px.y), size_px),
		Rect2(p + Vector2(half + 4.0, half * 0.2), size_px),
		Rect2(p + Vector2(-half - 4.0 - size_px.x, half * 0.2), size_px),
	]


func _draw_map_label(text: String, rect: Rect2, font_size: int, color: Color) -> void:
	var base := rect.position + Vector2(1.0, rect.size.y - 4.0)
	for off in [Vector2(-1.2, 0.0), Vector2(1.2, 0.0), Vector2(0.0, -1.2), Vector2(0.0, 1.2), Vector2(-1.0, -1.0), Vector2(1.0, 1.0)]:
		draw_string(ThemeDB.fallback_font, base + off, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, HALO)
	draw_string(ThemeDB.fallback_font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _draw_full_places(snapshot: Dictionary, map_rect: Rect2, world_size: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var mouse := get_local_mouse_position()
	var items: Array[Dictionary] = []
	for landmark in snapshot.get("landmarks", []):
		var lm_pos: Vector2 = landmark.get("position", Vector2.ZERO)
		var is_mountain := str(landmark.get("name", "")).begins_with("ЧОРНА")
		if is_mountain and not bool(snapshot.get("eye_known", false)):
			continue # місце Ока на карті приховане, доки фрагмент не складено
		if _atlas_hidden_at(lm_pos, snapshot, world_size):
			continue
		items.append({"p": _world_to_full_map(lm_pos, map_rect, world_size), "kind": "mountain" if is_mountain else "royal", "text": str(landmark.get("name", "")), "half": 15.0 if is_mountain else 11.0, "font": 13, "prio": 0})
	for building in snapshot.get("buildings", []):
		var kind := str(building.get("kind", ""))
		if _atlas_hidden_at(building.get("position", Vector2.ZERO), snapshot, world_size):
			continue
		items.append({"p": _world_to_full_map(building.get("position", Vector2.ZERO), map_rect, world_size), "kind": kind, "text": str(building.get("name", "")), "half": 9.0 if kind in ["castle", "waterfort"] else 7.5, "font": 11, "prio": 1 if kind in ["castle", "waterfort", "village", "church", "crypt", "tower"] else 2})
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["prio"]) < int(b["prio"]))

	var occupied: Array[Rect2] = []
	for item in items:
		var p: Vector2 = item["p"]
		var half: float = float(item["half"])
		occupied.append(Rect2(p - Vector2(half, half), Vector2(half, half) * 2.0))
	for item in items:
		_draw_icon(str(item["kind"]), item["p"], float(item["half"]) * (1.0 if str(item["kind"]) != "mountain" else 0.9))

	var hovered_text := ""
	var hovered_pos := Vector2.ZERO
	for item in items:
		var p: Vector2 = item["p"]
		var text := str(item["text"])
		var fsize := int(item["font"])
		var size_px := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsize) + Vector2(4.0, 4.0)
		var placed := false
		for cand in _label_candidates(p, size_px, float(item["half"])):
			var fits := map_rect.grow(-4.0).encloses(cand)
			if fits:
				for other in occupied:
					if other.intersects(cand.grow(1.5)):
						fits = false
						break
			if fits:
				occupied.append(cand)
				var tint := Color(0.42, 0.10, 0.06) if str(item["kind"]) in ["mountain", "royal"] else INK
				_draw_map_label(text, cand, fsize, tint)
				placed = true
				break
		if p.distance_to(mouse) < float(item["half"]) + 5.0 and not placed:
			hovered_text = text
			hovered_pos = p

	# NPC — лише крапки; ім'я з'являється при наведенні курсора.
	var npc_hover_text := ""
	var npc_hover_pos := Vector2.ZERO
	var best := 9.0
	for npc in snapshot.get("npcs", []):
		if _atlas_hidden_at(npc.get("position", Vector2.ZERO), snapshot, world_size):
			continue
		var np := _world_to_full_map(npc.get("position", Vector2.ZERO), map_rect, world_size)
		draw_circle(np, 3.4, INK)
		draw_circle(np, 2.2, Color(0.42, 0.72, 0.70))
		var d := np.distance_to(mouse)
		if d < best:
			best = d
			npc_hover_text = str(npc.get("name", ""))
			npc_hover_pos = np
	if npc_hover_text != "":
		hovered_text = npc_hover_text
		hovered_pos = npc_hover_pos
	if hovered_text != "":
		var tsize := font.get_string_size(hovered_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12) + Vector2(14.0, 8.0)
		var plate := Rect2(hovered_pos + Vector2(-tsize.x * 0.5, -tsize.y - 12.0), tsize)
		plate.position.x = clampf(plate.position.x, map_rect.position.x + 4.0, map_rect.end.x - tsize.x - 4.0)
		plate.position.y = maxf(plate.position.y, map_rect.position.y + 4.0)
		draw_rect(plate, Color(0.10, 0.07, 0.04, 0.94), true)
		draw_rect(plate, Color(0.78, 0.62, 0.34, 1.0), false, 1.2)
		draw_string(font, plate.position + Vector2(7.0, tsize.y - 6.0), hovered_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.96, 0.9, 0.74))


func _draw_centered_text(text_value: String, rect: Rect2, color_value: Color, font_size: int) -> void:
	var text_size := ThemeDB.fallback_font.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	draw_string(ThemeDB.fallback_font, rect.get_center() - Vector2(text_size.x * 0.5, -font_size * 0.35), text_value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color_value)


# --- Розірваний Атлас Корони ---------------------------------------------------------------------

func _atlas_hidden(piece_id: String, snapshot: Dictionary) -> bool:
	var owned: Array = snapshot.get("atlas_owned", [])
	if owned.is_empty():
		return false
	if not piece_id in owned:
		return true
	return piece_id == _anim_id and _anim_t < ATLAS_LAND_T


func _atlas_hidden_at(world_pos: Vector2, snapshot: Dictionary, world_size: Vector2) -> bool:
	if (snapshot.get("atlas_owned", []) as Array).is_empty():
		return false
	return _atlas_hidden(AtlasPieces.piece_at(world_pos, world_size), snapshot)


func _atlas_screen(poly: PackedVector2Array, map_rect: Rect2, world_size: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		out.append(_world_to_full_map(p, map_rect, world_size))
	return out


func _centroid(pts: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	return c / maxf(float(pts.size()), 1.0)


func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array(pts)
	if pts.size() > 0:
		out.append(pts[0])
	return out


func _draw_atlas(snapshot: Dictionary, map_rect: Rect2, world_size: Vector2) -> void:
	var owned: Array = snapshot.get("atlas_owned", [])
	if owned.is_empty():
		return
	var polys: Dictionary = AtlasPieces.polygons(world_size)
	var font := ThemeDB.fallback_font
	# 1) Шви між уже складеними шматками: тонка нитка зі стібками.
	for id in AtlasPieces.ORDER:
		if _atlas_hidden(id, snapshot) or id == _anim_id:
			continue
		var pts := _atlas_screen(polys[id], map_rect, world_size)
		if pts.size() < 3:
			continue
		draw_polyline(_closed(pts), Color(0.36, 0.22, 0.1, 0.55), 1.2, true)
		for i in range(0, pts.size(), 2):
			var a := pts[i]
			var b := pts[(i + 1) % pts.size()]
			if not map_rect.grow(-3.0).has_point((a + b) * 0.5):
				continue
			var n := (b - a).orthogonal().normalized() * 3.0
			var mid := (a + b) * 0.5
			draw_line(mid - n, mid + n, Color(0.62, 0.42, 0.18, 0.75), 1.2, true)
	# 2) Відсутні шматки: порожнеча з рваним паперовим краєм.
	for id in AtlasPieces.ORDER:
		if not _atlas_hidden(id, snapshot):
			continue
		var pts := _atlas_screen(polys[id], map_rect, world_size)
		if pts.size() < 3:
			continue
		var c := _centroid(pts)
		var grown := PackedVector2Array()
		for p in pts:
			grown.append(p + (p - c).normalized() * 1.5)
		draw_colored_polygon(grown, ATLAS_VOID)
		var closed := _closed(pts)
		draw_polyline(closed, Color(0.93, 0.84, 0.62, 0.95), 2.4, true)
		draw_polyline(closed, Color(0.25, 0.15, 0.07, 0.8), 1.0, true)
		draw_string(font, c + Vector2(-9.0, 10.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 32, Color(0.55, 0.46, 0.32, 0.85))
		var cap := "ВІДІРВАНО"
		var cs := font.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10)
		draw_string(font, c + Vector2(-cs.x * 0.5, 30.0), cap, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(0.62, 0.53, 0.38, 0.85))
	# 3) Шматок, що зараз лягає на місце.
	if _anim_id != "" and polys.has(_anim_id):
		_draw_atlas_flying(polys[_anim_id], map_rect, world_size)


func _draw_atlas_flying(poly: PackedVector2Array, map_rect: Rect2, world_size: Vector2) -> void:
	var pts := _atlas_screen(poly, map_rect, world_size)
	if pts.size() < 3:
		return
	var c := _centroid(pts)
	var fly := clampf(_anim_t / ATLAS_LAND_T, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - fly, 3.0)
	var outward := c - map_rect.get_center()
	outward = outward.normalized() if outward.length() > 1.0 else Vector2(-0.6, -0.8)
	var start := outward * map_rect.size.x * 0.45 + Vector2(0.0, -70.0)
	var off := start * (1.0 - e)
	var rot := 0.55 * (1.0 - e) * (1.0 if outward.x < 0.0 else -1.0)
	var sc := 1.0 + 0.22 * (1.0 - e)
	var moved := PackedVector2Array()
	var uvs := PackedVector2Array()
	for p in pts:
		moved.append(c + (p - c).rotated(rot) * sc + off)
		uvs.append((p - map_rect.position) / map_rect.size)
	if fly < 1.0:
		# Тінь шматка над столом і сам клапоть пергаменту.
		var shadow := PackedVector2Array()
		for p in moved:
			shadow.append(p + Vector2(10.0, 14.0) * (1.0 - e) + Vector2(2.0, 3.0))
		draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.45))
		if _parchment:
			draw_colored_polygon(moved, Color(1.0, 0.97, 0.9), uvs, _parchment)
		else:
			draw_colored_polygon(moved, Color(0.84, 0.72, 0.5))
		draw_polyline(_closed(moved), Color(0.95, 0.88, 0.68, 1.0), 2.4, true)
		draw_polyline(_closed(moved), Color(0.35, 0.22, 0.1, 0.8), 1.0, true)
		return
	# Шматок ліг: золоті стібки біжать уздовж краю, шов світиться й згасає.
	var k := clampf((_anim_t - ATLAS_LAND_T) / (ATLAS_ANIM_LEN - ATLAS_LAND_T), 0.0, 1.0)
	var glow := 1.0 - k
	draw_polyline(_closed(pts), Color(1.0, 0.78, 0.32, 0.25 + 0.6 * glow), 5.0 * glow + 1.5, true)
	var upto := int(float(pts.size()) * clampf(k * 1.6, 0.0, 1.0))
	for i in range(upto):
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var n := (b - a).orthogonal().normalized() * 4.5
		var mid := (a + b) * 0.5
		draw_line(mid - n, mid + n, Color(0.98, 0.78, 0.32, 0.95), 2.0, true)


func _draw_atlas_counter(snapshot: Dictionary, map_rect: Rect2) -> void:
	var owned: Array = snapshot.get("atlas_owned", [])
	if owned.is_empty():
		return
	var font := ThemeDB.fallback_font
	var total := AtlasPieces.total()
	var title := "АТЛАС КОРОНИ  ·  ФРАГМЕНТИ: %d / %d" % [owned.size(), total]
	var sub := "Карта складена: шлях до Ока відкрито."
	if owned.size() < total:
		sub = "Шматки тримають хранителі Ордену Печатки. Місце Ока невідоме."
	if _anim_id != "":
		var info: Dictionary = AtlasPieces.PIECES.get(_anim_id, {})
		sub = "Шматок лягає на місце: %s  (%s)" % [str(info.get("name", "")), str(info.get("from", ""))]
	var ts := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14)
	var ss := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11)
	var plate := Rect2(map_rect.position + Vector2(10.0, 10.0), Vector2(maxf(ts.x, ss.x) + 20.0, 46.0))
	draw_rect(plate, Color(0.1, 0.07, 0.04, 0.88), true)
	draw_rect(plate, Color(0.78, 0.62, 0.34, 1.0), false, 1.2)
	draw_string(font, plate.position + Vector2(10.0, 19.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.98, 0.86, 0.55))
	draw_string(font, plate.position + Vector2(10.0, 37.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color(0.86, 0.78, 0.62))
	# Ряд маленьких «клаптиків»: світлі — знайдені, темні — ще відірвані.
	for i in range(total):
		var id: String = AtlasPieces.ORDER[i]
		var r := Rect2(plate.position + Vector2(plate.size.x + 8.0 + float(i) * 15.0, 16.0), Vector2(11.0, 14.0))
		draw_rect(r, Color(0.86, 0.72, 0.46) if id in owned else Color(0.08, 0.06, 0.05, 0.85), true)
		draw_rect(r, Color(0.35, 0.22, 0.1), false, 1.0)
