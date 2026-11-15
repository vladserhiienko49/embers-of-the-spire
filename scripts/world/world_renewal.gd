class_name WorldRenewal
extends Node
## Світ оживає після знищення Ока: від Вівтаря хвилею розходяться квіти й трава (MultiMesh,
## без тисяч окремих вузлів), над вершиною з'являються зграї птахів зі щебетанням.

const FLOWER_COLORS: Array = ["#e8402a", "#f2c838", "#f4efe2", "#a070e0", "#ff8ab0"]
const FLOWERS_PER_COLOR: int = 650
const GRASS_COUNT: int = 2600
const GROW_SECONDS: float = 38.0
const BIRD_COUNT: int = 16

var world = null
var _origin: Vector3 = Vector3.ZERO     # точка, звідки росте життя (Вівтар Ока), локально у WorldGenerator
var _sets: Array = []                   # {mm: MultiMesh, xforms: Array[Transform3D], dist: PackedFloat32Array}
var _t: float = 0.0
var _update_t: float = 0.0
var _max_dist: float = 260.0
var _birds: Array = []
var _chirp_t: float = 1.0


func setup(world_node, origin_local: Vector3) -> void:
	world = world_node
	_origin = origin_local
	var rng := RandomNumberGenerator.new()
	rng.seed = 1999
	for c in FLOWER_COLORS:
		_sets.append(_scatter(_flower_mesh(Color(str(c))), FLOWERS_PER_COLOR, rng, 0.8, 1.4))
	_sets.append(_scatter(_grass_mesh(), GRASS_COUNT, rng, 0.9, 1.8))
	for i in range(BIRD_COUNT):
		_spawn_bird(i)


static func _mat(color: Color, emission: float = 0.0) -> Material:
	return PSXMaterials.make(color, 0.0, 0.9, color if emission > 0.0 else Color.BLACK, emission, "none", false)


func _flower_mesh(petal: Color) -> Mesh:
	var kit := MeshKit.new()
	kit.set_material("stem", _mat(Color("#3a7a2a")))
	kit.set_material("petal", _mat(petal, 0.35))
	kit.set_material("core", _mat(Color("#ffd040"), 0.5))
	kit.box_at("stem", Vector3(0, 0.18, 0), Vector3(0.03, 0.36, 0.03))
	kit.box_at("stem", Vector3(0.05, 0.12, 0), Vector3(0.1, 0.02, 0.05), false, Vector3(0, 0, 0.4))
	for k in range(4):
		var a := TAU * float(k) / 4.0
		kit.box_at("petal", Vector3(cos(a) * 0.06, 0.38, sin(a) * 0.06), Vector3(0.09, 0.025, 0.09), false, Vector3(0, a, 0.25))
	kit.box_at("core", Vector3(0, 0.395, 0), Vector3(0.05, 0.03, 0.05))
	return kit.build_mesh()


func _grass_mesh() -> Mesh:
	var kit := MeshKit.new()
	kit.set_material("blade", _mat(Color("#4c9a34")))
	kit.set_material("blade2", _mat(Color("#6ab840")))
	for k in range(5):
		var a := TAU * float(k) / 5.0
		kit.pyramid("blade" if k % 2 == 0 else "blade2", Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 0.18), Vector3(cos(a) * 0.08, 0, sin(a) * 0.08)), 0.09, 0.05, 0.45)
	return kit.build_mesh()


func _scatter(mesh: Mesh, count: int, rng: RandomNumberGenerator, s_min: float, s_max: float) -> Dictionary:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	var xforms: Array = []
	var dist := PackedFloat32Array()
	dist.resize(count)
	for i in range(count):
		# Густо біля Вівтаря й на вершині, рідше — схилами гори й рівниною довкола.
		var r := pow(rng.randf(), 1.7) * _max_dist
		var a := rng.randf() * TAU
		var x := _origin.x + cos(a) * r
		var z := _origin.z + sin(a) * r
		var y: float = world._terrain_height_at_world(x, z)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(s_min, s_max))
		xforms.append(Transform3D(basis, Vector3(x, y - 0.02, z)))
		dist[i] = r + rng.randf_range(0.0, 12.0)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.001), Vector3(x, y - 1.0, z)))
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(node)
	return {"mm": mm, "xforms": xforms, "dist": dist, "done": false}


func _process(delta: float) -> void:
	_t += delta
	_update_t -= delta
	if _update_t <= 0.0:
		_update_t = 0.08
		_grow()
	_update_birds(delta)


func _grow() -> void:
	# Фронт росту рухається від Вівтаря назовні; кожна рослина за ~1.5 с виростає з землі.
	var front := (_t / GROW_SECONDS) * (_max_dist + 20.0)
	for s in _sets:
		if bool(s["done"]):
			continue
		var mm: MultiMesh = s["mm"]
		var xforms: Array = s["xforms"]
		var dist: PackedFloat32Array = s["dist"]
		var all_done := true
		for i in range(mm.instance_count):
			var k := clampf((front - dist[i]) / 18.0, 0.0, 1.0)
			if k < 1.0:
				all_done = false
			if k <= 0.0:
				continue
			var xf: Transform3D = xforms[i]
			mm.set_instance_transform(i, Transform3D(xf.basis.scaled(Vector3.ONE * maxf(k, 0.001)), xf.origin))
		s["done"] = all_done


# --- Птахи --------------------------------------------------------------------------------------------------

func _spawn_bird(i: int) -> void:
	var root := Node3D.new()
	var body_m := _mat(Color("#f2efe6") if i % 3 != 0 else Color("#c8a070"))
	var wing_m := _mat(Color("#dcd6c8"))
	var body := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.14, 0.12, 0.34)
	body.mesh = bb
	body.material_override = body_m
	root.add_child(body)
	var wings: Array = []
	for sx: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(sx * 0.06, 0.03, 0)
		root.add_child(pivot)
		var w := MeshInstance3D.new()
		var wb := BoxMesh.new()
		wb.size = Vector3(0.42, 0.02, 0.2)
		w.mesh = wb
		w.material_override = wing_m
		w.position = Vector3(sx * 0.21, 0, 0)
		pivot.add_child(w)
		wings.append(pivot)
	world.add_child(root)
	var center := _origin + Vector3(randf_range(-40, 40), 0, randf_range(-40, 40))
	_birds.append({
		"node": root, "wings": wings, "center": center,
		"radius": randf_range(8.0, 34.0), "height": randf_range(6.0, 26.0),
		"speed": randf_range(0.35, 0.8) * (1.0 if i % 2 == 0 else -1.0),
		"angle": randf() * TAU, "phase": randf() * TAU,
	})


func _update_birds(delta: float) -> void:
	for b in _birds:
		var node: Node3D = b["node"]
		b["angle"] = float(b["angle"]) + float(b["speed"]) * delta
		var a: float = b["angle"]
		var c: Vector3 = b["center"]
		var ground: float = world._terrain_height_at_world(c.x, c.z)
		var pos := c + Vector3(cos(a) * float(b["radius"]), 0.0, sin(a) * float(b["radius"]))
		pos.y = ground + float(b["height"]) + sin(_t * 0.7 + float(b["phase"])) * 2.0
		var prev := node.position
		node.position = pos
		var dir := pos - prev
		if dir.length() > 0.001:
			node.look_at(node.global_position + dir, Vector3.UP)
		var flap := sin(_t * 14.0 + float(b["phase"])) * 0.8
		(b["wings"][0] as Node3D).rotation.z = -flap
		(b["wings"][1] as Node3D).rotation.z = flap
	_chirp_t -= delta
	if _chirp_t <= 0.0 and not _birds.is_empty():
		_chirp_t = randf_range(0.4, 1.2)
		var b2: Dictionary = _birds[randi() % _birds.size()]
		if randf() < 0.5:
			AudioManager.play_sfx_3d("bird_chirp", (b2["node"] as Node3D).global_position, -2.0, 90.0, 18.0, "Ambient")
		else:
			# Щебетання чути й на далеких планах фінальної камери.
			AudioManager.play_sfx("bird_chirp", -11.0, 0.15, false, "Ambient")
