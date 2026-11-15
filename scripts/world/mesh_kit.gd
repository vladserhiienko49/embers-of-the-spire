class_name MeshKit
extends RefCounted
## Збирає процедурну low-poly геометрію в ОДИН ArrayMesh (по поверхні на матеріал)
## плюс прості колізії. Пласкі нормалі — чистий PS1-вигляд, мінімум draw calls.
## Усі фігури задаються в локальній системі, зсунутій на `origin`.

var origin: Transform3D = Transform3D.IDENTITY
var _tools: Dictionary = {}
var _materials: Dictionary = {}
var _boxes: Array = []      # [Transform3D, Vector3]
var _cylinders: Array = []  # [Transform3D, radius, height]


func set_material(key: String, material: Material) -> void:
	_materials[key] = material


func has_material(key: String) -> bool:
	return _materials.has(key)


func _tool(key: String) -> SurfaceTool:
	if not _tools.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[key] = st
	return _tools[key]


# --- Примітиви -----------------------------------------------------------------

func tri(key: String, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	## Трикутник у локальних координатах; порядок вершин виправляється за `outward`.
	var wa := origin * a
	var wb := origin * b
	var wc := origin * c
	var n := (wb - wa).cross(wc - wa)
	var out_world := origin.basis * outward
	if n.dot(out_world) < 0.0:
		var tmp := wb
		wb = wc
		wc = tmp
		n = -n
	if n.length_squared() < 0.0000001:
		return
	n = n.normalized()
	var st := _tool(key)
	st.set_normal(n)
	st.add_vertex(wa)
	st.set_normal(n)
	st.add_vertex(wb)
	st.set_normal(n)
	st.add_vertex(wc)


func quad(key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	tri(key, a, b, c, outward)
	tri(key, a, c, d, outward)


func box(key: String, xf: Transform3D, size: Vector3, collide: bool = false) -> void:
	var h := size * 0.5
	var p := [
		xf * Vector3(-h.x, -h.y, -h.z), xf * Vector3(h.x, -h.y, -h.z),
		xf * Vector3(h.x, -h.y, h.z), xf * Vector3(-h.x, -h.y, h.z),
		xf * Vector3(-h.x, h.y, -h.z), xf * Vector3(h.x, h.y, -h.z),
		xf * Vector3(h.x, h.y, h.z), xf * Vector3(-h.x, h.y, h.z)
	]
	var b := xf.basis
	quad(key, p[4], p[5], p[6], p[7], b.y)
	quad(key, p[0], p[1], p[2], p[3], -b.y)
	quad(key, p[0], p[1], p[5], p[4], -b.z)
	quad(key, p[3], p[2], p[6], p[7], b.z)
	quad(key, p[0], p[3], p[7], p[4], -b.x)
	quad(key, p[1], p[2], p[6], p[5], b.x)
	if collide:
		_boxes.append([origin * xf, size])


func box_at(key: String, pos: Vector3, size: Vector3, collide: bool = false, rot: Vector3 = Vector3.ZERO) -> void:
	box(key, Transform3D(Basis.from_euler(rot), pos), size, collide)


func cylinder(key: String, xf: Transform3D, r_bottom: float, r_top: float, height: float, sides: int = 8, caps: bool = true, collide: bool = false) -> void:
	## Циліндр/конус уздовж локальної осі Y, основа на y = 0.
	var bottom: Array[Vector3] = []
	var top: Array[Vector3] = []
	for i in range(sides):
		var angle := TAU * float(i) / float(sides)
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		bottom.append(xf * (dir * r_bottom))
		top.append(xf * (dir * r_top + Vector3(0.0, height, 0.0)))
	var axis := xf.basis.y.normalized()
	var center_bottom := xf * Vector3.ZERO
	var center_top := xf * Vector3(0.0, height, 0.0)
	for i in range(sides):
		var j := (i + 1) % sides
		var mid := (bottom[i] + bottom[j] + top[i] + top[j]) * 0.25
		var out := mid - (center_bottom + center_top) * 0.5
		out -= axis * out.dot(axis)
		if r_top <= 0.001:
			tri(key, bottom[i], bottom[j], center_top, out)
		else:
			quad(key, bottom[i], bottom[j], top[j], top[i], out)
	if caps:
		for i in range(sides):
			var j := (i + 1) % sides
			tri(key, center_bottom, bottom[i], bottom[j], -axis)
			if r_top > 0.001:
				tri(key, center_top, top[i], top[j], axis)
	if collide:
		_cylinders.append([origin * xf.translated_local(Vector3(0.0, height * 0.5, 0.0)), maxf(r_bottom, r_top), height])


func cylinder_at(key: String, pos: Vector3, r_bottom: float, r_top: float, height: float, sides: int = 8, collide: bool = false, rot: Vector3 = Vector3.ZERO) -> void:
	cylinder(key, Transform3D(Basis.from_euler(rot), pos), r_bottom, r_top, height, sides, true, collide)


func pyramid(key: String, xf: Transform3D, width: float, depth: float, height: float) -> void:
	## Чотирисхилий дах/шпиль, основа на y = 0.
	var hw := width * 0.5
	var hd := depth * 0.5
	var a := xf * Vector3(-hw, 0, -hd)
	var b := xf * Vector3(hw, 0, -hd)
	var c := xf * Vector3(hw, 0, hd)
	var d := xf * Vector3(-hw, 0, hd)
	var apex := xf * Vector3(0, height, 0)
	var center := xf * Vector3(0, height * 0.3, 0)
	for face in [[a, b], [b, c], [c, d], [d, a]]:
		var p0: Vector3 = face[0]
		var p1: Vector3 = face[1]
		tri(key, p0, p1, apex, (p0 + p1 + apex) / 3.0 - center)
	quad(key, a, b, c, d, -xf.basis.y)


func gable_roof(roof_key: String, gable_key: String, xf: Transform3D, width: float, depth: float, height: float, overhang: float = 0.6, thickness: float = 0.22) -> void:
	## Двосхилий дах: гребінь уздовж локальної X, схили дивляться на ±Z.
	## Основа на y = 0 (верх стін). Фронтони заповнюються матеріалом gable_key.
	var half_d := depth * 0.5
	var slope_len := sqrt(half_d * half_d + height * height)
	var angle := atan2(height, half_d)
	for side: float in [-1.0, 1.0]:
		var dir := Vector3(0.0, height, -side * half_d).normalized() # від карниза до гребеня
		var mid := Vector3(0.0, height * 0.5, side * half_d * 0.5)
		var normal := Vector3(0.0, half_d, side * height).normalized()
		var center := mid - dir * (overhang * 0.5) + normal * (thickness * 0.5)
		var rot := Basis(Vector3.RIGHT, side * angle)
		box(roof_key, xf * Transform3D(rot, center), Vector3(width + overhang * 2.0, thickness, slope_len + overhang))
	for side: float in [-1.0, 1.0]:
		var x := side * width * 0.5
		tri(gable_key, xf * Vector3(x, 0, -half_d), xf * Vector3(x, 0, half_d), xf * Vector3(x, height, 0), xf.basis.x * side)
	box(roof_key, xf * Transform3D(Basis(), Vector3(0.0, height + thickness * 0.6, 0.0)), Vector3(width + overhang * 2.0 + 0.1, 0.24, 0.3))


func rock(key: String, xf: Transform3D, size: Vector3, rng: RandomNumberGenerator, collide: bool = false) -> void:
	## Неправильна брила: верх, два кільця по 6 вершин і низ із випадковим зсувом.
	var ring_lo: Array[Vector3] = []
	var ring_hi: Array[Vector3] = []
	var sides := 6
	var spin := rng.randf() * TAU
	for i in range(sides):
		var angle := spin + TAU * float(i) / float(sides)
		var r1 := rng.randf_range(0.8, 1.1)
		var r2 := rng.randf_range(0.55, 0.85)
		ring_lo.append(xf * Vector3(cos(angle) * size.x * 0.5 * r1, size.y * rng.randf_range(0.15, 0.3), sin(angle) * size.z * 0.5 * r1))
		ring_hi.append(xf * Vector3(cos(angle + 0.4) * size.x * 0.5 * r2, size.y * rng.randf_range(0.6, 0.8), sin(angle + 0.4) * size.z * 0.5 * r2))
	var top := xf * Vector3(rng.randf_range(-0.15, 0.15) * size.x, size.y, rng.randf_range(-0.15, 0.15) * size.z)
	var bottom := xf * Vector3(0, -size.y * 0.15, 0)
	var center := xf * Vector3(0, size.y * 0.45, 0)
	for i in range(sides):
		var j := (i + 1) % sides
		tri(key, bottom, ring_lo[i], ring_lo[j], (ring_lo[i] + ring_lo[j]) * 0.5 - center + Vector3.DOWN)
		quad(key, ring_lo[i], ring_lo[j], ring_hi[j], ring_hi[i], (ring_lo[i] + ring_lo[j] + ring_hi[i] + ring_hi[j]) * 0.25 - center)
		tri(key, ring_hi[i], ring_hi[j], top, (ring_hi[i] + ring_hi[j] + top) / 3.0 - center)
	if collide:
		_boxes.append([origin * xf.translated_local(Vector3(0, size.y * 0.4, 0)), Vector3(size.x * 0.8, size.y * 0.8, size.z * 0.8)])


func add_box_collider(xf: Transform3D, size: Vector3) -> void:
	_boxes.append([origin * xf, size])


# --- Збирання -------------------------------------------------------------------

func build_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for key in _tools.keys():
		var st: SurfaceTool = _tools[key]
		st.commit(mesh)
		var surface := mesh.get_surface_count() - 1
		if _materials.has(key):
			mesh.surface_set_material(surface, _materials[key])
	return mesh


func build(parent: Node3D, node_name: String, visibility_end: float = 0.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = build_mesh()
	if visibility_end > 0.0:
		instance.visibility_range_end = visibility_end
		instance.visibility_range_end_margin = 30.0
		instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(instance)
	if not _boxes.is_empty() or not _cylinders.is_empty():
		var body := StaticBody3D.new()
		body.name = node_name + "_Collision"
		body.collision_layer = 1
		body.collision_mask = 1
		for entry in _boxes:
			var shape := BoxShape3D.new()
			shape.size = entry[1]
			var collision := CollisionShape3D.new()
			collision.shape = shape
			collision.transform = entry[0]
			body.add_child(collision)
		for entry in _cylinders:
			var cyl := CylinderShape3D.new()
			cyl.radius = entry[1]
			cyl.height = entry[2]
			var collision := CollisionShape3D.new()
			collision.shape = cyl
			collision.transform = entry[0]
			body.add_child(collision)
		parent.add_child(body)
	return instance
