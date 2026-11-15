class_name PropScatter
extends RefCounted
## Розсаджує оточення через MultiMesh: ялини, сухі криві дерева, брили, суху траву,
## а вздовж доріг — ліхтарні стовпи з мерехтливим світлом.
## MultiMesh розбито на клітинки 128 м: далекі клітинки відсікаються visibility range.

const CELL: float = 128.0

static var _meshes: Dictionary = {}


static func _material(key: String) -> Material:
	return BuildingKit.mat(key)


static func _foliage_mat(color: String) -> Material:
	var key := "foliage_" + color
	if not _meshes.has(key):
		_meshes[key] = PSXMaterials.make(Color(color), 0.0, 0.95, Color.BLACK, 0.0, "foliage")
	return _meshes[key]


static func _finish_mesh(kit: MeshKit) -> ArrayMesh:
	for key in kit._tools.keys():
		if not kit.has_material(key):
			if key.begins_with("leaf_"):
				kit.set_material(key, _foliage_mat(key.substr(5)))
			else:
				kit.set_material(key, _material(key))
	return kit.build_mesh()


static func pine_mesh(variant: int) -> ArrayMesh:
	var key := "pine_%d" % variant
	if _meshes.has(key):
		return _meshes[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + variant
	var kit := MeshKit.new()
	kit.cylinder_at("bark", Vector3.ZERO, 0.32, 0.18, 3.2, 6)
	var tiers := 4 if variant == 0 else 5
	var colors := ["#14261a", "#1b3222", "#20392a", "#244030", "#2a4734"]
	for i in range(tiers):
		var t := float(i) / float(tiers - 1)
		var r := lerpf(2.5, 0.8, t)
		var y := 1.8 + float(i) * (5.2 / float(tiers))
		kit.cylinder("leaf_" + colors[i], Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.06, 0.06), rng.randf() * TAU, rng.randf_range(-0.06, 0.06))), Vector3(0, y, 0)), r, 0.0, lerpf(2.8, 2.0, t), 7)
	var mesh := _finish_mesh(kit)
	_meshes[key] = mesh
	return mesh


static func dead_tree_mesh(variant: int) -> ArrayMesh:
	var key := "dead_%d" % variant
	if _meshes.has(key):
		return _meshes[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 700 + variant * 31
	var kit := MeshKit.new()
	var height := rng.randf_range(5.0, 7.0)
	var bend := Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
	var segments := 3
	var base := Vector3.ZERO
	var radius := 0.38
	var points: Array[Vector3] = []
	for s in range(segments):
		var seg_h := height / float(segments)
		var top := base + Vector3(0, seg_h, 0) + bend * (float(s + 1) / float(segments)) * 0.6
		var dir := top - base
		var basis := _basis_from_up(dir.normalized())
		kit.cylinder("bark_dead", Transform3D(basis, base), radius, radius * 0.7, dir.length(), 6, false)
		points.append(top)
		base = top
		radius *= 0.7
	# Гілки: кручені, спрямовані вгору й назовні.
	var branch_count := rng.randi_range(4, 6)
	for b in range(branch_count):
		var start: Vector3 = points[rng.randi_range(0, segments - 1)].lerp(points[segments - 1], rng.randf() * 0.4)
		var yaw := rng.randf() * TAU
		var dir := Vector3(cos(yaw), rng.randf_range(0.35, 0.9), sin(yaw)).normalized()
		var length := rng.randf_range(1.6, 3.2)
		kit.cylinder("bark_dead", Transform3D(_basis_from_up(dir), start), 0.13, 0.04, length, 5, false)
		var tip := start + dir * length * 0.7
		var twig := (dir + Vector3(rng.randf_range(-0.7, 0.7), 0.4, rng.randf_range(-0.7, 0.7))).normalized()
		kit.cylinder("bark_dead", Transform3D(_basis_from_up(twig), tip), 0.06, 0.02, length * 0.5, 4, false)
	kit.set_material("bark_dead", PSXMaterials.make(Color("#2b2622"), 0.0, 0.95, Color.BLACK, 0.0, "bark"))
	var mesh := _finish_mesh(kit)
	_meshes[key] = mesh
	return mesh


static func rock_mesh(variant: int) -> ArrayMesh:
	var key := "rock_%d" % variant
	if _meshes.has(key):
		return _meshes[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 500 + variant * 17
	var kit := MeshKit.new()
	kit.rock("rock", Transform3D(), Vector3(2.0, 1.3, 1.6), rng)
	if variant == 2:
		kit.rock("rock", Transform3D(Basis(), Vector3(1.1, 0, 0.6)), Vector3(1.0, 0.7, 0.9), rng)
	kit.set_material("rock", PSXMaterials.make(Color("#46444a"), 0.0, 0.95, Color.BLACK, 0.0, "rock"))
	var mesh := _finish_mesh(kit)
	_meshes[key] = mesh
	return mesh


static func grass_mesh() -> ArrayMesh:
	if _meshes.has("grass"):
		return _meshes["grass"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 321
	var kit := MeshKit.new()
	for i in range(7):
		var a := rng.randf() * TAU
		var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 0.35)
		var tilt := Basis.from_euler(Vector3(rng.randf_range(-0.35, 0.35), rng.randf() * TAU, rng.randf_range(-0.35, 0.35)))
		kit.cylinder("leaf_#5a5232", Transform3D(tilt, p), 0.06, 0.0, rng.randf_range(0.5, 0.9), 3, false)
	var mesh := _finish_mesh(kit)
	_meshes["grass"] = mesh
	return mesh


static func lantern_mesh() -> ArrayMesh:
	if _meshes.has("lantern"):
		return _meshes["lantern"]
	var kit := MeshKit.new()
	kit.box_at("stone", Vector3(0, 0.2, 0), Vector3(0.6, 0.4, 0.6))
	kit.box_at("wood", Vector3(0, 1.9, 0), Vector3(0.2, 3.4, 0.2))
	kit.box_at("wood", Vector3(0.45, 3.45, 0), Vector3(1.1, 0.14, 0.14))
	kit.box_at("wood", Vector3(0.2, 3.1, 0), Vector3(0.1, 0.6, 0.1), false, Vector3(0, 0, -0.8))
	kit.box_at("iron", Vector3(0.85, 3.2, 0), Vector3(0.04, 0.4, 0.04))
	kit.box_at("window", Vector3(0.85, 2.85, 0), Vector3(0.26, 0.34, 0.26))
	kit.pyramid("iron", Transform3D(Basis(), Vector3(0.85, 3.02, 0)), 0.38, 0.38, 0.22)
	kit.box_at("iron", Vector3(0.85, 2.67, 0), Vector3(0.32, 0.05, 0.32))
	var mesh := _finish_mesh(kit)
	_meshes["lantern"] = mesh
	return mesh


static func _basis_from_up(up: Vector3) -> Basis:
	var y := up.normalized()
	var x := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var z := x.cross(y).normalized()
	x = y.cross(z).normalized()
	return Basis(x, y, z)


# --- Розсадження ------------------------------------------------------------------

static func populate(parent: Node3D, terrain: Node, forbidden_zones: Array, routes_3d: Array, spawn_position: Vector3, world_size: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var buckets: Dictionary = {} # "type|cell" -> Array[Transform3D]
	var colliders := StaticBody3D.new()
	colliders.name = "PropColliders"
	var mountain_center: Vector2 = terrain.get("mountain_center")
	var mountain_radius: float = float(terrain.call("get_mountain_radius"))
	var dead_zones: Array = [
		[Vector2(1750, 1300) * 0.18, 70.0], [mountain_center, mountain_radius * 1.35],
		[Vector2(3050, 2100) * 0.18, 60.0], [Vector2(2670, 1020) * 0.18, 50.0], [Vector2(1953, 673) * 0.18, 55.0]
	]

	var tree_target := 1300
	var placed := 0
	var attempts := 0
	while placed < tree_target and attempts < 7000:
		attempts += 1
		var p := Vector2(rng.randf_range(-110.0, world_size.x + 110.0), rng.randf_range(-110.0, world_size.y + 110.0))
		if not _is_free(p, terrain, forbidden_zones, spawn_position, mountain_center, mountain_radius, 6.5):
			continue
		var height: float = float(terrain.call("get_height_at_world", p))
		var slope: float = float(terrain.call("get_slope_at_world", p))
		if height < 0.2 or slope > 0.75:
			continue
		var dead_chance := 0.18
		for zone in dead_zones:
			if p.distance_to(zone[0]) < float(zone[1]):
				dead_chance = 0.85
		if height > 55.0:
			dead_chance = 1.0
		var is_dead := rng.randf() < dead_chance
		var scale := rng.randf_range(0.8, 1.35)
		var variant := rng.randi_range(0, 2) if is_dead else rng.randi_range(0, 1)
		var prop_type := ("dead_%d" % variant) if is_dead else ("pine_%d" % variant)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale), Vector3(p.x, height - 0.1, p.y))
		_add(buckets, prop_type, p, xf)
		var trunk := CylinderShape3D.new()
		trunk.radius = 0.38 * scale
		trunk.height = 3.0 * scale
		var collision := CollisionShape3D.new()
		collision.shape = trunk
		collision.position = Vector3(p.x, height + 1.5 * scale, p.y)
		colliders.add_child(collision)
		placed += 1

	# Брили: частіше на схилах і біля гори.
	placed = 0
	attempts = 0
	while placed < 520 and attempts < 4000:
		attempts += 1
		var p := Vector2(rng.randf_range(-100.0, world_size.x + 100.0), rng.randf_range(-100.0, world_size.y + 100.0))
		if p.distance_to(mountain_center) < mountain_radius * 1.2 and rng.randf() < 0.5:
			var a := rng.randf() * TAU
			p = mountain_center + Vector2(cos(a), sin(a)) * rng.randf_range(mountain_radius * 0.45, mountain_radius * 1.15)
		if not _is_free(p, terrain, forbidden_zones, spawn_position, mountain_center, mountain_radius * 0.2, 4.0):
			continue
		var height: float = float(terrain.call("get_height_at_world", p))
		var scale := rng.randf_range(0.5, 2.2)
		var xf := Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2))).scaled(Vector3(scale, scale * rng.randf_range(0.7, 1.2), scale)), Vector3(p.x, height - 0.25 * scale, p.y))
		_add(buckets, "rock_%d" % rng.randi_range(0, 2), p, xf)
		if scale > 1.1:
			var box := BoxShape3D.new()
			box.size = Vector3(1.6, 1.0, 1.3) * scale
			var collision := CollisionShape3D.new()
			collision.shape = box
			collision.position = Vector3(p.x, height + 0.4 * scale, p.y)
			colliders.add_child(collision)
		placed += 1

	# Суха трава (без колізій).
	placed = 0
	attempts = 0
	while placed < 4200 and attempts < 9000:
		attempts += 1
		var p := Vector2(rng.randf_range(0.0, world_size.x), rng.randf_range(0.0, world_size.y))
		if float(terrain.call("get_path_amount_at_world", p)) > 0.05:
			continue
		var height: float = float(terrain.call("get_height_at_world", p))
		if height < 0.1 or height > 60.0:
			continue
		var scale := rng.randf_range(0.7, 1.4)
		_add(buckets, "grass", p, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale), Vector3(p.x, height, p.y)))
		placed += 1

	_spawn_lanterns(parent, terrain, routes_3d, forbidden_zones, mountain_center, mountain_radius, buckets)
	parent.add_child(colliders)
	_build_multimeshes(parent, buckets)


static func _is_free(p: Vector2, terrain: Node, forbidden_zones: Array, spawn_position: Vector3, mountain_center: Vector2, mountain_keepout: float, road_clearance: float) -> bool:
	if p.distance_to(Vector2(spawn_position.x, spawn_position.z)) < 20.0:
		return false
	if p.distance_to(mountain_center) < mountain_keepout:
		return false
	if float(terrain.call("distance_to_roads", p)) < road_clearance:
		return false
	if float(terrain.call("distance_to_river", p)) < 7.0:
		return false
	if p.distance_to(mountain_center) < 150.0 and float(terrain.call("distance_to_mountain_path", p)) < 6.0:
		return false
	for zone in forbidden_zones:
		var zp: Vector3 = zone["pos"]
		if p.distance_to(Vector2(zp.x, zp.z)) < float(zone["radius"]):
			return false
	return true


static func _add(buckets: Dictionary, prop_type: String, p: Vector2, xf: Transform3D) -> void:
	var key := "%s|%d|%d" % [prop_type, int(floor(p.x / CELL)), int(floor(p.y / CELL))]
	if not buckets.has(key):
		buckets[key] = []
	buckets[key].append(xf)


static func _mesh_for(prop_type: String) -> ArrayMesh:
	if prop_type.begins_with("pine_"):
		return pine_mesh(int(prop_type.substr(5)))
	if prop_type.begins_with("dead_"):
		return dead_tree_mesh(int(prop_type.substr(5)))
	if prop_type.begins_with("rock_"):
		return rock_mesh(int(prop_type.substr(5)))
	if prop_type == "lantern":
		return lantern_mesh()
	return grass_mesh()


static func _build_multimeshes(parent: Node3D, buckets: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "Props"
	parent.add_child(root)
	for key in buckets.keys():
		var prop_type := str(key).get_slice("|", 0)
		var transforms: Array = buckets[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = _mesh_for(prop_type)
		multimesh.instance_count = transforms.size()
		for i in range(transforms.size()):
			multimesh.set_instance_transform(i, transforms[i])
		var instance := MultiMeshInstance3D.new()
		instance.name = str(key).replace("|", "_")
		instance.multimesh = multimesh
		var visible_end := 480.0
		if prop_type == "grass":
			visible_end = 90.0
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif prop_type.begins_with("rock_"):
			visible_end = 340.0
		instance.visibility_range_end = visible_end + CELL * 0.7
		instance.visibility_range_end_margin = 30.0
		instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		root.add_child(instance)


static func _spawn_lanterns(parent: Node3D, terrain: Node, routes_3d: Array, forbidden_zones: Array, mountain_center: Vector2, mountain_radius: float, buckets: Dictionary) -> void:
	var lights := Node3D.new()
	lights.name = "RoadLanterns"
	parent.add_child(lights)
	var side := 1.0
	for route in routes_3d:
		var carried := 20.0
		for i in range(route.size() - 1):
			var a3: Vector3 = route[i]
			var b3: Vector3 = route[i + 1]
			var a := Vector2(a3.x, a3.z)
			var b := Vector2(b3.x, b3.z)
			var seg_len := a.distance_to(b)
			var dir := (b - a).normalized()
			var normal := Vector2(-dir.y, dir.x)
			var t := carried
			while t < seg_len:
				var s := side
				var p := a + dir * t + normal * s * 3.4
				t += 42.0
				side = -side
				if p.distance_to(mountain_center) < mountain_radius * 0.85:
					continue
				if float(terrain.call("distance_to_river", p)) < 8.0:
					continue
				var blocked := false
				for zone in forbidden_zones:
					var zp: Vector3 = zone["pos"]
					if p.distance_to(Vector2(zp.x, zp.z)) < float(zone["radius"]) * 0.6:
						blocked = true
						break
				if blocked:
					continue
				var height: float = float(terrain.call("get_height_at_world", p))
				# Кронштейн ліхтаря (+X) нахилено до дороги.
				var to_road := -normal * s
				var xf := Transform3D(Basis(Vector3.UP, atan2(-to_road.y, to_road.x)), Vector3(p.x, height, p.y))
				_add(buckets, "lantern", p, xf)
				var light := FlickerLight.create(Color("#ffa24a"), 1.5, 11.0, 0.2, 5.0)
				light.position = xf * Vector3(0.85, 2.7, 0)
				light.fade_begin = 55.0
				lights.add_child(light)
			carried = t - seg_len
