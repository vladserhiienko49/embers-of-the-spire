extends Node3D

## TerrainBuilder — рельєф Embers of the Spire (Етап 3).
## • Сітка з кроком 2.5 м, порізана на чанки (кращий frustum culling).
## • Висоти рахуються паралельно (WorkerThreadPool) і кешуються у user://.
## • Чорна Гора — величний пік ~150 м із серпантином до руїн на вершині.
## • Дороги не вирізаються «в нуль», а м'яко лягають на рельєф і малюються в шейдері.
## • Колізія — HeightMapShape3D (дешевше за трикутну сітку).
## Усі координати локальні відносно WorldGenerator.

const TERRAIN_VERSION: int = 7

# Озеро Фортеці Чорного Прапора: плоский острів, неглибока чаша, берег і плавний перехід до рельєфу.
const LAKE_MAP: Vector2 = Vector2(3113.0, 1161.0)
const LAKE_ISLAND_R: float = 41.0
const LAKE_R: float = 66.0
const LAKE_FADE_END: float = 100.0
const LAKE_DEPTH: float = 1.6
const CELL_SIZE: float = 2.5
const EXTRA_BORDER: float = 140.0
const CHUNK_CELLS: int = 64
const MIN_HEIGHT: float = -2.0
const MAX_HEIGHT: float = 230.0

# Чорна Гора (координати карти 670, 650).
const MOUNTAIN_MAP: Vector2 = Vector2(670.0, 650.0)
const MOUNTAIN_RADIUS: float = 138.0
const MOUNTAIN_HEIGHT: float = 148.0
## Плато вершини розширене (було 26 м): поруч із руїнами Корони — простора арена фінального бою.
const SUMMIT_RADIUS: float = 46.0
const PATH_GRADE: float = 0.17
const PATH_STEP: float = 3.0

# Біоми: відтінок рельєфу (множник кольору) та іній.
const BIOMES: Array = [
	{"map": Vector2(650, 550), "r": 170.0, "tint": Color(0.86, 0.84, 0.92), "frost": 0.0},
	{"map": Vector2(3050, 400), "r": 150.0, "tint": Color(0.92, 1.0, 1.12), "frost": 0.75},
	{"map": Vector2(500, 1950), "r": 120.0, "tint": Color(0.82, 1.08, 0.86), "frost": 0.0},
	{"map": Vector2(1750, 1300), "r": 110.0, "tint": Color(0.95, 0.93, 0.9), "frost": 0.15},
	{"map": Vector2(3050, 2100), "r": 130.0, "tint": Color(1.18, 0.86, 0.78), "frost": 0.0},
	{"map": Vector2(2100, 2150), "r": 110.0, "tint": Color(1.08, 1.0, 0.82), "frost": 0.0},
	# Розширення: заболочений південь, золисте плато сходу, інійна півн.-схід, багряні руїни, склеп королів.
	{"map": Vector2(1900, 3200), "r": 130.0, "tint": Color(0.78, 1.02, 0.84), "frost": 0.0},
	{"map": Vector2(4650, 2150), "r": 120.0, "tint": Color(1.1, 0.98, 0.86), "frost": 0.0},
	{"map": Vector2(5400, 550), "r": 150.0, "tint": Color(0.92, 1.0, 1.12), "frost": 0.7},
	{"map": Vector2(5950, 1250), "r": 130.0, "tint": Color(1.16, 0.88, 0.8), "frost": 0.0},
	{"map": Vector2(5900, 3850), "r": 140.0, "tint": Color(0.82, 0.8, 0.9), "frost": 0.1},
	{"map": Vector2(3100, 3750), "r": 120.0, "tint": Color(0.9, 1.02, 0.92), "frost": 0.0},
]

var _world_scale: float = 0.18
var _map_width: float = 5400.0
var _map_height: float = 3900.0
var _routes: Array = []
var _building_data: Array = []
var _flat_areas: Array[Dictionary] = []
var _river_path: Array[Vector2] = []
var _route_segments: Array = [] # [a, b, min, max]
var _river_segments: Array = []
var _large_noise: FastNoiseLite
var _detail_noise: FastNoiseLite
var _mountain_noise: FastNoiseLite

var lake_center: Vector2 = Vector2.ZERO
var lake_level: float = 0.0
var mountain_center: Vector2 = Vector2.ZERO
var summit_height: float = 0.0
var mountain_path: PackedVector3Array = PackedVector3Array()
var _path_segments: Array = []

var _grid_w: int = 0
var _grid_h: int = 0
var _min_x: float = 0.0
var _min_z: float = 0.0
var _heights: PackedFloat32Array = PackedFloat32Array()
var _colors: PackedColorArray = PackedColorArray()
var _extras: PackedVector2Array = PackedVector2Array()
var _grid_ready: bool = false
var _rows_mutex: Mutex = Mutex.new()
var _row_heights: Array = []
var _row_colors: Array = []
var _row_extras: Array = []

var terrain_body: StaticBody3D
var terrain_material: ShaderMaterial


func configure(world_scale: float, map_width: float, map_height: float, routes: Array, buildings: Array) -> void:
	_world_scale = world_scale
	_map_width = map_width
	_map_height = map_height
	_routes = routes.duplicate(true)
	_building_data = buildings.duplicate(true)
	_prepare_noise()
	mountain_center = MOUNTAIN_MAP * _world_scale
	lake_center = LAKE_MAP * _world_scale
	lake_level = _ground_level(lake_center.x, lake_center.y)
	_prepare_route_segments()
	_prepare_river_path()
	_prepare_flat_areas()
	_prepare_mountain_path()


func _prepare_noise() -> void:
	_large_noise = FastNoiseLite.new()
	_large_noise.seed = 81427
	_large_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_large_noise.frequency = 0.0028
	_large_noise.fractal_octaves = 4
	_large_noise.fractal_lacunarity = 2.0
	_large_noise.fractal_gain = 0.48

	_detail_noise = FastNoiseLite.new()
	_detail_noise.seed = 22091
	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail_noise.frequency = 0.018
	_detail_noise.fractal_octaves = 2
	_detail_noise.fractal_gain = 0.42

	_mountain_noise = FastNoiseLite.new()
	_mountain_noise.seed = 66013
	_mountain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_mountain_noise.frequency = 0.022
	_mountain_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_mountain_noise.fractal_octaves = 4


func _prepare_route_segments() -> void:
	_route_segments.clear()
	for route in _routes:
		for index in range(route.size() - 1):
			var a: Vector2 = Vector2(route[index]) * _world_scale
			var b: Vector2 = Vector2(route[index + 1]) * _world_scale
			_route_segments.append([a, b, Vector2(minf(a.x, b.x), minf(a.y, b.y)), Vector2(maxf(a.x, b.x), maxf(a.y, b.y))])


func _prepare_river_path() -> void:
	_river_path = [
		Vector2(3300, 0), Vector2(3060, 400), Vector2(2850, 760),
		Vector2(2650, 1120), Vector2(2410, 1440), Vector2(2180, 1760),
		Vector2(1900, 2100), Vector2(1640, 2600)
	]
	_river_segments.clear()
	for index in range(_river_path.size() - 1):
		var a := _river_path[index] * _world_scale
		var b := _river_path[index + 1] * _world_scale
		_river_segments.append([a, b, Vector2(minf(a.x, b.x), minf(a.y, b.y)), Vector2(maxf(a.x, b.x), maxf(a.y, b.y))])


func _prepare_flat_areas() -> void:
	_flat_areas.clear()
	for building in _building_data:
		if str(building.get("kind", "")) == "waterfort":
			continue # острів і озеро формує _sample
		var center := Vector2(float(building.get("x", 0.0)), float(building.get("y", 0.0))) * _world_scale
		var width := float(building.get("w", 120.0)) * _world_scale * 0.55
		var depth := float(building.get("h", 100.0)) * _world_scale * 0.55
		var radius: float = clampf(maxf(width, depth) + 9.0, 17.0, 29.0)
		_flat_areas.append({"center": center, "radius": radius, "fade": 16.0, "height": _ground_level(center.x, center.y)})
	# Королівський замок, стартовий майданчик і портал.
	_add_flat_area_from_map(2930.0, 545.0, 48.0, 22.0)
	_add_flat_area_from_map(1810.0, 2210.0, 28.0, 20.0)
	_add_flat_area_from_map(1850.0, 2140.0, 18.0, 15.0)
	_add_flat_area_from_map(1700.0, 2210.0, 14.0, 12.0)


func _add_flat_area_from_map(map_x: float, map_y: float, radius: float, fade: float) -> void:
	var center := Vector2(map_x, map_y) * _world_scale
	_flat_areas.append({"center": center, "radius": radius, "fade": fade, "height": _ground_level(center.x, center.y)})


# --- Чорна Гора ----------------------------------------------------------------

func _mountain_profile(distance: float) -> float:
	## Відносна висота гори (без шуму) як функція відстані від центру.
	if distance >= MOUNTAIN_RADIUS:
		return 0.0
	if distance <= SUMMIT_RADIUS:
		return MOUNTAIN_HEIGHT
	var s := 1.0 - (distance - SUMMIT_RADIUS) / (MOUNTAIN_RADIUS - SUMMIT_RADIUS)
	return MOUNTAIN_HEIGHT * pow(s, 1.55)


func _mountain_height(x: float, z: float) -> float:
	var offset := Vector2(x, z) - mountain_center
	var distance := offset.length()
	if distance >= MOUNTAIN_RADIUS:
		return 0.0
	var s := clampf(1.0 - (distance - SUMMIT_RADIUS) / (MOUNTAIN_RADIUS - SUMMIT_RADIUS), 0.0, 1.0)
	var h := _mountain_profile(distance)
	# Радіальні хребти й ущелини, сильніші посередині схилу.
	var angle := atan2(offset.y, offset.x)
	var warp := _large_noise.get_noise_2d(x * 1.7, z * 1.7) * 2.6
	var ridges := sin(angle * 7.0 + warp) * 0.5 + 0.5
	var slope_band := s * (1.0 - s) * 4.0
	h += (ridges - 0.5) * 22.0 * slope_band
	# Скелясті ребра (ridged noise) роблять силует зубчастим.
	h += _mountain_noise.get_noise_2d(x, z) * 9.0 * slope_band
	# М'який перехід у рівнину.
	h *= smoothstep(MOUNTAIN_RADIUS, MOUNTAIN_RADIUS * 0.82, distance)
	return h


func _prepare_mountain_path() -> void:
	## Серпантин із постійним ухилом: стежка «шукає» висоту на схилі.
	mountain_path = PackedVector3Array()
	_path_segments.clear()
	var base_center := _ground_level(mountain_center.x, mountain_center.y)
	summit_height = base_center + MOUNTAIN_HEIGHT
	# Початок — там, де дорога з рівнини підходить до підніжжя (з боку села).
	var approach := Vector2(950.0, 900.0) * _world_scale
	var angle := atan2(approach.y - mountain_center.y, approach.x - mountain_center.x)
	var rel_height := 2.0
	var guard := 0
	while rel_height < MOUNTAIN_HEIGHT - 0.5 and guard < 2000:
		guard += 1
		var s := pow(clampf(rel_height / MOUNTAIN_HEIGHT, 0.0, 1.0), 1.0 / 1.55)
		var radius := SUMMIT_RADIUS + (1.0 - s) * (MOUNTAIN_RADIUS - SUMMIT_RADIUS)
		radius = maxf(radius, SUMMIT_RADIUS + 3.0)
		var point := mountain_center + Vector2(cos(angle), sin(angle)) * radius
		var abs_height := lerpf(_ground_level(point.x, point.y), summit_height, clampf(rel_height / MOUNTAIN_HEIGHT, 0.0, 1.0))
		mountain_path.append(Vector3(point.x, abs_height, point.y))
		angle += PATH_STEP / maxf(radius, 1.0)
		rel_height += PATH_STEP * PATH_GRADE
	var top := mountain_center + Vector2(cos(angle), sin(angle)) * (SUMMIT_RADIUS - 4.0)
	mountain_path.append(Vector3(top.x, summit_height, top.y))
	for index in range(mountain_path.size() - 1):
		var a := mountain_path[index]
		var b := mountain_path[index + 1]
		_path_segments.append([a, b, Vector2(minf(a.x, b.x), minf(a.z, b.z)), Vector2(maxf(a.x, b.x), maxf(a.z, b.z))])


func get_mountain_path_start() -> Vector3:
	return mountain_path[0] if mountain_path.size() > 0 else Vector3.ZERO


func get_summit_position() -> Vector3:
	return Vector3(mountain_center.x, summit_height, mountain_center.y)


func get_mountain_radius() -> float:
	return MOUNTAIN_RADIUS


func distance_to_roads(point: Vector2) -> float:
	return _distance_to_segments(point, _route_segments, 30.0)


func distance_to_river(point: Vector2) -> float:
	return _distance_to_segments(point, _river_segments, 30.0)


func distance_to_mountain_path(point: Vector2) -> float:
	var best := INF
	for segment in _path_segments:
		var a3: Vector3 = segment[0]
		var b3: Vector3 = segment[1]
		var d := _distance_to_segment(point, Vector2(a3.x, a3.z), Vector2(b3.x, b3.z))
		best = minf(best, d)
	return best


# --- Висоти ----------------------------------------------------------------------

func _ground_level(x: float, z: float) -> float:
	## Згладжена висота рівнини: по ній ідуть дороги й стоять будівлі.
	var h := _large_noise.get_noise_2d(x, z) * 7.2
	h += _hill(x, z, Vector2(760.0, 170.0), 128.0, 27.0)
	h += _hill(x, z, Vector2(735.0, 590.0), 115.0, 23.0)
	h += _hill(x, z, Vector2(245.0, 615.0), 104.0, 19.0)
	h += _hill(x, z, Vector2(475.0, 380.0), 96.0, 13.0)
	return h * 0.55


func _raw_height(x: float, z: float) -> float:
	var broad := _large_noise.get_noise_2d(x, z)
	var detail := _detail_noise.get_noise_2d(x, z)
	var height := broad * 7.2 + detail * 1.35
	height += _hill(x, z, Vector2(760.0, 170.0), 128.0, 27.0)
	height += _hill(x, z, Vector2(735.0, 590.0), 115.0, 23.0)
	height += _hill(x, z, Vector2(245.0, 615.0), 104.0, 19.0)
	height += _hill(x, z, Vector2(475.0, 380.0), 96.0, 13.0)
	var ridge := 1.0 - absf(_large_noise.get_noise_2d(x * 0.72 + 500.0, z * 0.72 - 300.0))
	height += pow(ridge, 2.4) * 2.8
	return height


func _sample(point: Vector2) -> Array:
	## Повертає [висота, відтінок біому, Vector2(стежка, іній)].
	var x := point.x
	var z := point.y
	var height := _raw_height(x, z)
	var mountain_distance := point.distance_to(mountain_center)
	var mountain_fade := smoothstep(MOUNTAIN_RADIUS * 0.75, MOUNTAIN_RADIUS * 1.05, mountain_distance)

	# Дороги лягають на згладжений рельєф (на горі їх замінює серпантин).
	var path_amount := 0.0
	var road_distance := _distance_to_segments(point, _route_segments, 24.0)
	if road_distance < 24.0:
		var flatten := (1.0 - smoothstep(3.0, 15.0, road_distance)) * mountain_fade
		height = lerpf(height, _ground_level(x, z), flatten)
		path_amount = (1.0 - smoothstep(1.8, 3.6, road_distance)) * mountain_fade

	var river_distance := _distance_to_segments(point, _river_segments, 22.0)
	if river_distance < 22.0:
		height = lerpf(height, minf(height, -0.42), 1.0 - smoothstep(5.0, 22.0, river_distance))

	for area in _flat_areas:
		var center: Vector2 = area["center"]
		var radius: float = float(area["radius"])
		var fade: float = float(area["fade"])
		var distance_sq := point.distance_squared_to(center)
		var outer := radius + fade
		if distance_sq < outer * outer:
			var influence := 1.0 - smoothstep(radius, outer, sqrt(distance_sq))
			height = lerpf(height, float(area["height"]), influence)

	# Озеро Фортеці Чорного Прапора.
	var lake_d := point.distance_to(lake_center)
	if lake_d < LAKE_FADE_END:
		var floor_h := lake_level - LAKE_DEPTH
		var island := 1.0 - smoothstep(LAKE_ISLAND_R, LAKE_ISLAND_R + 6.0, lake_d)
		var banked := maxf(height, lake_level + 0.35)
		var outer := 1.0 - smoothstep(LAKE_R + 12.0, LAKE_FADE_END, lake_d)
		var outside := lerpf(height, banked, outer)
		var bowl := smoothstep(LAKE_R - 2.0, LAKE_R + 12.0, lake_d)
		height = lerpf(lerpf(floor_h, outside, bowl), lake_level, island)

	if mountain_distance < MOUNTAIN_RADIUS:
		height += _mountain_height(x, z)
		var plateau := 1.0 - smoothstep(SUMMIT_RADIUS - 1.0, SUMMIT_RADIUS + 4.0, mountain_distance)
		height = lerpf(height, summit_height + _detail_noise.get_noise_2d(x, z) * 0.12, plateau)
		# Серпантин: полиця, вирізана у схилі.
		var best := INF
		var best_height := 0.0
		for segment in _path_segments:
			var lo: Vector2 = segment[2]
			var hi: Vector2 = segment[3]
			if x < lo.x - 10.0 or x > hi.x + 10.0 or z < lo.y - 10.0 or z > hi.y + 10.0:
				continue
			var a3: Vector3 = segment[0]
			var b3: Vector3 = segment[1]
			var a := Vector2(a3.x, a3.z)
			var ab := Vector2(b3.x, b3.z) - a
			var denominator := ab.length_squared()
			var t := 0.0
			if denominator > 0.0001:
				t = clampf((point - a).dot(ab) / denominator, 0.0, 1.0)
			var d := point.distance_to(a + ab * t)
			if d < best:
				best = d
				best_height = lerpf(a3.y, b3.y, t)
		if best < 10.0:
			height = lerpf(height, best_height, 1.0 - smoothstep(3.2, 9.0, best))
			path_amount = maxf(path_amount, 1.0 - smoothstep(1.6, 3.4, best))

	# Біоми.
	var tint := Color(1, 1, 1)
	var frost := 0.0
	for biome in BIOMES:
		var center: Vector2 = Vector2(biome["map"]) * _world_scale
		var radius: float = float(biome["r"])
		var distance := point.distance_to(center)
		if distance < radius:
			var weight := 1.0 - smoothstep(radius * 0.45, radius, distance)
			tint = tint.lerp(biome["tint"], weight)
			frost = maxf(frost, float(biome["frost"]) * weight)

	return [clampf(height, MIN_HEIGHT, MAX_HEIGHT), Color(tint.r * 0.5, tint.g * 0.5, tint.b * 0.5, 1.0), Vector2(path_amount, frost)]


func _compute_row(z_index: int) -> void:
	var heights := PackedFloat32Array()
	var colors := PackedColorArray()
	var extras := PackedVector2Array()
	heights.resize(_grid_w)
	colors.resize(_grid_w)
	extras.resize(_grid_w)
	var world_z := _min_z + float(z_index) * CELL_SIZE
	for x_index in range(_grid_w):
		var result := _sample(Vector2(_min_x + float(x_index) * CELL_SIZE, world_z))
		heights[x_index] = result[0]
		colors[x_index] = result[1]
		extras[x_index] = result[2]
	_rows_mutex.lock()
	_row_heights[z_index] = heights
	_row_colors[z_index] = colors
	_row_extras[z_index] = extras
	_rows_mutex.unlock()


func _cache_path() -> String:
	return "user://terrain_cache_v%d_%dx%d.bin" % [TERRAIN_VERSION, _grid_w, _grid_h]


func _load_cache() -> bool:
	var file := FileAccess.open(_cache_path(), FileAccess.READ)
	if file == null:
		return false
	var data = file.get_var()
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var heights: PackedFloat32Array = data.get("h", PackedFloat32Array())
	if heights.size() != _grid_w * _grid_h:
		return false
	_heights = heights
	_colors = data.get("c", PackedColorArray())
	_extras = data.get("e", PackedVector2Array())
	return _colors.size() == heights.size() and _extras.size() == heights.size()


func _save_cache() -> void:
	var file := FileAccess.open(_cache_path(), FileAccess.WRITE)
	if file == null:
		return
	file.store_var({"h": _heights, "c": _colors, "e": _extras})
	file.close()


func _build_grid() -> void:
	_min_x = -EXTRA_BORDER
	_min_z = -EXTRA_BORDER
	_grid_w = int(ceil((_map_width * _world_scale + EXTRA_BORDER * 2.0) / CELL_SIZE)) + 1
	_grid_h = int(ceil((_map_height * _world_scale + EXTRA_BORDER * 2.0) / CELL_SIZE)) + 1
	if not _load_cache():
		var started := Time.get_ticks_msec()
		_row_heights.resize(_grid_h)
		_row_colors.resize(_grid_h)
		_row_extras.resize(_grid_h)
		var task := WorkerThreadPool.add_group_task(_compute_row, _grid_h, -1, true, "TerrainRows")
		WorkerThreadPool.wait_for_group_task_completion(task)
		_heights = PackedFloat32Array()
		_colors = PackedColorArray()
		_extras = PackedVector2Array()
		for z_index in range(_grid_h):
			_heights.append_array(_row_heights[z_index])
			_colors.append_array(_row_colors[z_index])
			_extras.append_array(_row_extras[z_index])
		_row_heights.clear()
		_row_colors.clear()
		_row_extras.clear()
		_save_cache()
		print("TerrainBuilder: рельєф %dx%d згенеровано за %d мс" % [_grid_w, _grid_h, Time.get_ticks_msec() - started])
	_grid_ready = true


func build_terrain() -> void:
	for child in get_children():
		child.queue_free()
	_build_grid()
	terrain_material = _make_terrain_material()
	_build_chunks()
	_build_collision()


func _height_at(xi: int, zi: int) -> float:
	return _heights[clampi(zi, 0, _grid_h - 1) * _grid_w + clampi(xi, 0, _grid_w - 1)]


func _build_chunks() -> void:
	var chunk_root := Node3D.new()
	chunk_root.name = "TerrainChunks"
	add_child(chunk_root)
	var cells_x := _grid_w - 1
	var cells_z := _grid_h - 1
	for chunk_z in range(0, cells_z, CHUNK_CELLS):
		for chunk_x in range(0, cells_x, CHUNK_CELLS):
			var x_end := mini(chunk_x + CHUNK_CELLS, cells_x)
			var z_end := mini(chunk_z + CHUNK_CELLS, cells_z)
			var w := x_end - chunk_x + 1
			var vertices := PackedVector3Array()
			var normals := PackedVector3Array()
			var colors := PackedColorArray()
			var uv2s := PackedVector2Array()
			var indices := PackedInt32Array()
			for zi in range(chunk_z, z_end + 1):
				for xi in range(chunk_x, x_end + 1):
					var index := zi * _grid_w + xi
					vertices.append(Vector3(_min_x + float(xi) * CELL_SIZE, _heights[index], _min_z + float(zi) * CELL_SIZE))
					var dx := _height_at(xi + 1, zi) - _height_at(xi - 1, zi)
					var dz := _height_at(xi, zi + 1) - _height_at(xi, zi - 1)
					normals.append(Vector3(-dx, 2.0 * CELL_SIZE, -dz).normalized())
					colors.append(_colors[index])
					uv2s.append(_extras[index])
			for zi in range(z_end - chunk_z):
				for xi in range(x_end - chunk_x):
					var a := zi * w + xi
					var b := a + 1
					var c := a + w
					var d := c + 1
					# Діагональ a-d збігається з тріангуляцією HeightMapShape3D (Jolt).
					indices.append(a)
					indices.append(c)
					indices.append(d)
					indices.append(a)
					indices.append(d)
					indices.append(b)
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_COLOR] = colors
			arrays[Mesh.ARRAY_TEX_UV2] = uv2s
			arrays[Mesh.ARRAY_INDEX] = indices
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(0, terrain_material)
			var chunk := MeshInstance3D.new()
			chunk.name = "Chunk_%d_%d" % [chunk_x / CHUNK_CELLS, chunk_z / CHUNK_CELLS]
			chunk.mesh = mesh
			chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			chunk_root.add_child(chunk)


func _build_collision() -> void:
	# HeightMapShape3D має одиничний крок, тому масштабуємо вузол рівномірно,
	# а висоти ділимо на той самий масштаб.
	var shape := HeightMapShape3D.new()
	shape.map_width = _grid_w
	shape.map_depth = _grid_h
	var scaled := PackedFloat32Array()
	scaled.resize(_heights.size())
	for i in range(_heights.size()):
		scaled[i] = _heights[i] / CELL_SIZE
	shape.map_data = scaled
	terrain_body = StaticBody3D.new()
	terrain_body.name = "TerrainCollision"
	terrain_body.collision_layer = 1
	terrain_body.collision_mask = 1
	var collision := CollisionShape3D.new()
	collision.name = "TerrainHeightMap"
	collision.shape = shape
	collision.scale = Vector3.ONE * CELL_SIZE
	collision.position = Vector3(
		_min_x + float(_grid_w - 1) * CELL_SIZE * 0.5,
		0.0,
		_min_z + float(_grid_h - 1) * CELL_SIZE * 0.5
	)
	terrain_body.add_child(collision)
	add_child(terrain_body)


func get_height_at_world(point: Vector2) -> float:
	## Висота поверхні. Після побудови — білінійна вибірка з сітки (збігається з мешем).
	if not _grid_ready:
		return float(_sample(point)[0])
	var fx := (point.x - _min_x) / CELL_SIZE
	var fz := (point.y - _min_z) / CELL_SIZE
	var xi := clampi(int(floor(fx)), 0, _grid_w - 2)
	var zi := clampi(int(floor(fz)), 0, _grid_h - 2)
	var tx := clampf(fx - float(xi), 0.0, 1.0)
	var tz := clampf(fz - float(zi), 0.0, 1.0)
	var h00 := _heights[zi * _grid_w + xi]
	var h10 := _heights[zi * _grid_w + xi + 1]
	var h01 := _heights[(zi + 1) * _grid_w + xi]
	var h11 := _heights[(zi + 1) * _grid_w + xi + 1]
	# Та сама діагональ, що й у меші: точна висота трикутника.
	if tx >= tz:
		return h00 + (h11 - h10) * tz + (h10 - h00) * tx
	return h00 + (h11 - h01) * tx + (h01 - h00) * tz


func get_slope_at_world(point: Vector2) -> float:
	var e := CELL_SIZE
	var dx := get_height_at_world(point + Vector2(e, 0)) - get_height_at_world(point - Vector2(e, 0))
	var dz := get_height_at_world(point + Vector2(0, e)) - get_height_at_world(point - Vector2(0, e))
	return Vector2(dx, dz).length() / (2.0 * e)


func get_path_amount_at_world(point: Vector2) -> float:
	if not _grid_ready:
		return 0.0
	var xi := clampi(int(round((point.x - _min_x) / CELL_SIZE)), 0, _grid_w - 1)
	var zi := clampi(int(round((point.y - _min_z) / CELL_SIZE)), 0, _grid_h - 1)
	return _extras[zi * _grid_w + xi].x


func _hill(x: float, z: float, center: Vector2, radius: float, amplitude: float) -> float:
	return amplitude * exp(-Vector2(x, z).distance_squared_to(center) / (radius * radius))


func _distance_to_segments(point: Vector2, segments: Array, max_distance: float) -> float:
	var best := INF
	for segment in segments:
		var lo: Vector2 = segment[2]
		var hi: Vector2 = segment[3]
		if point.x < lo.x - max_distance or point.x > hi.x + max_distance or point.y < lo.y - max_distance or point.y > hi.y + max_distance:
			continue
		best = minf(best, _distance_to_segment(point, segment[0], segment[1]))
	return best


func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var denominator: float = ab.length_squared()
	var t: float = 0.0
	if denominator > 0.0001:
		t = clampf((point - a).dot(ab) / denominator, 0.0, 1.0)
	return point.distance_to(a + ab * t)


func _make_terrain_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

#include "res://shaders/psx_common.gdshaderinc"

uniform sampler2D grass_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D stone_tex : source_color, filter_nearest, repeat_enable;
uniform float detail_gain = 1.22;

varying float terrain_height;
varying float terrain_slope;
varying vec2 terrain_world_xz;
varying vec3 biome_tint;
varying vec2 extra;

float terrain_hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void vertex() {
    vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    terrain_height = world_position.y;
    terrain_world_xz = world_position.xz;
    terrain_slope = 1.0 - clamp(NORMAL.y, 0.0, 1.0);
    biome_tint = COLOR.rgb * 2.0;
    extra = UV2;
    POSITION = psx_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
}

void fragment() {
    float broad_noise = terrain_hash(floor(terrain_world_xz * 0.095));
    float fine_noise = terrain_hash(floor(terrain_world_xz * 0.72));

    vec3 grass_dark = vec3(0.075, 0.105, 0.070);
    vec3 grass_moss = vec3(0.145, 0.165, 0.105);
    vec3 soil = vec3(0.19, 0.16, 0.115);
    vec3 rock = vec3(0.21, 0.205, 0.215);
    vec3 cold_stone = vec3(0.36, 0.37, 0.41);
    vec3 ash_snow = vec3(0.56, 0.57, 0.62);

    vec3 grass_detail = texture(grass_tex, terrain_world_xz * 0.3).rgb * detail_gain;
    vec3 dirt_detail = texture(dirt_tex, terrain_world_xz * 0.22).rgb * detail_gain;
    vec3 rock_detail = texture(rock_tex, terrain_world_xz * 0.14).rgb * detail_gain;
    vec3 stone_detail = texture(stone_tex, terrain_world_xz * 0.45).rgb * detail_gain;

    vec3 ground = mix(grass_dark, grass_moss, smoothstep(0.12, 0.88, broad_noise)) * grass_detail;
    ground = mix(ground, soil * dirt_detail, smoothstep(0.64, 0.94, fine_noise) * 0.38);
    ground *= biome_tint;
    float rockiness = smoothstep(0.2, 0.5, terrain_slope);
    ground = mix(ground, rock * rock_detail, rockiness);
    ground = mix(ground, cold_stone * rock_detail, smoothstep(40.0, 90.0, terrain_height) * 0.85);

    // Попелястий сніг на вершині та іній у холодних біомах — лише на пологих ділянках.
    float flat_amount = 1.0 - smoothstep(0.18, 0.42, terrain_slope);
    float snow = max(smoothstep(105.0, 135.0, terrain_height), extra.y * 0.7) * flat_amount;
    ground = mix(ground, ash_snow * rock_detail, snow);

    // Стежки: утоптана земля з камінцями посередині.
    float path = smoothstep(0.1, 0.9, extra.x);
    vec3 path_color = mix(soil * 0.85 * dirt_detail, vec3(0.24, 0.22, 0.2) * stone_detail, smoothstep(0.75, 1.0, extra.x) * 0.55);
    ground = mix(ground, path_color, path);

    ground *= 0.94 + broad_noise * 0.11;
    ALBEDO = ground;
    // Матова земля: жодних відблисків.
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
    METALLIC = 0.0;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("grass_tex", PSXTextures.get_texture("grass"))
	material.set_shader_parameter("dirt_tex", PSXTextures.get_texture("dirt"))
	material.set_shader_parameter("rock_tex", PSXTextures.get_texture("rock"))
	material.set_shader_parameter("stone_tex", PSXTextures.get_texture("stone"))
	return material
