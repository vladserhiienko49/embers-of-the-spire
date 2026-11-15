class_name LandmarkKit
extends RefCounted
## Великі орієнтири світу: арковані мости, Камінь Присяги з реліквіями, Вівтар Ока та Фортеця Чорного Прапора на воді.
## Усе складається з MeshKit (PSX-стиль), локальні координати: Y = 0 — рівень землі.


static func _spinner(parent: Node3D, node_name: String, pos: Vector3, spin: Vector3, bob: float = 0.0, bob_speed: float = 1.0, phase: float = 0.0) -> Spinner:
	var s := Spinner.new()
	s.name = node_name
	s.position = pos
	s.spin = spin
	s.bob_amplitude = bob
	s.bob_speed = bob_speed
	s.phase = phase
	parent.add_child(s)
	return s


static func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	node.rotation = rot
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


static func _torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 12
	t.ring_segments = 6
	return t


# =====================================================================================
# Арковий дерев'яний міст
# =====================================================================================

static func build_arched_bridge(length: float, width: float, rise: float, ground_a: float, ground_b: float, with_lights: bool = true) -> Node3D:
	## Вісь моста — локальна Z: від -length/2 (кінець A) до +length/2 (кінець B).
	## ground_a/b — висота землі на кінцях відносно початку координат вузла.
	var root := Node3D.new()
	root.name = "ArchedBridge"
	var kit := MeshKit.new()
	var half := length * 0.5
	var hw := width * 0.5
	var n := 16
	var deck_pts: Array[Vector3] = []
	var rib_pts: Array[Vector3] = []
	for i in range(n + 1):
		var t := float(i) / float(n)
		var arch := rise * (1.0 - pow(2.0 * t - 1.0, 2.0))
		var base := lerpf(ground_a, ground_b, t)
		deck_pts.append(Vector3(0.0, base + 0.22 + arch, -half + length * t))
		rib_pts.append(Vector3(0.0, base - 0.35 + arch * 0.52, -half + length * t))
	for i in range(n):
		var a := deck_pts[i]
		var b := deck_pts[i + 1]
		var mid := (a + b) * 0.5
		var seg := b - a
		var seg_len := seg.length()
		var pitch := atan2(seg.y, seg.z)
		var basis := Basis(Vector3.RIGHT, -pitch)
		# Настил із двох шарів дощок і бічні лежні.
		kit.box("wood_light", Transform3D(basis, mid), Vector3(width, 0.22, seg_len + 0.06), true)
		for k: float in [-0.25, 0.25]:
			kit.box("wood", Transform3D(basis, mid + basis * Vector3(0, 0.125, seg_len * k)), Vector3(width - 0.12, 0.03, seg_len * 0.46))
		for side: float in [-1.0, 1.0]:
			kit.box("wood", Transform3D(basis, mid + basis * Vector3(side * (hw - 0.1), -0.32, 0)), Vector3(0.28, 0.42, seg_len + 0.06))
			# Поручні: верхній і нижній.
			kit.box("wood_light", Transform3D(basis, mid + basis * Vector3(side * (hw - 0.12), 1.12, 0)), Vector3(0.13, 0.13, seg_len + 0.04))
			kit.box("wood", Transform3D(basis, mid + basis * Vector3(side * (hw - 0.12), 0.6, 0)), Vector3(0.08, 0.08, seg_len + 0.04))
		# Дугові ребра під настилом.
		var ra := rib_pts[i]
		var rb := rib_pts[i + 1]
		var rmid := (ra + rb) * 0.5
		var rseg := rb - ra
		var rbasis := Basis(Vector3.RIGHT, -atan2(rseg.y, rseg.z))
		for side: float in [-1.0, 1.0]:
			kit.box("wood", Transform3D(rbasis, rmid + Vector3(side * (hw - 0.55), 0, 0)), Vector3(0.36, 0.5, rseg.length() + 0.08))
	for i in range(n + 1):
		var p := deck_pts[i]
		var rp := rib_pts[i]
		for side: float in [-1.0, 1.0]:
			var x := side * (hw - 0.12)
			kit.box_at("wood", Vector3(x, p.y + 0.62, p.z), Vector3(0.15, 1.16, 0.15))
			if i % 2 == 0 and i > 0 and i < n:
				# Стійки між настилом і дугою.
				var gap := p.y - 0.11 - (rp.y + 0.25)
				if gap > 0.1:
					kit.box_at("wood", Vector3(side * (hw - 0.55), rp.y + 0.25 + gap * 0.5, p.z), Vector3(0.18, gap, 0.18))
		if i % 4 == 0 and i > 0 and i < n:
			kit.box_at("wood", Vector3(0, rp.y + 0.1, p.z), Vector3(width - 1.0, 0.14, 0.14))
	# Кам'яні опори на кінцях: глибоко в землі, з вінцем.
	for end_sign: float in [-1.0, 1.0]:
		var g := ground_a if end_sign < 0.0 else ground_b
		var z := end_sign * (half - 0.4)
		var bottom := minf(ground_a, ground_b) - 3.2
		var top := g + 0.1
		kit.box_at("stone", Vector3(0, (top + bottom) * 0.5, z), Vector3(width + 1.4, top - bottom, 2.2), true)
		kit.box_at("stone_dark", Vector3(0, top + 0.05, z), Vector3(width + 1.7, 0.18, 2.5))
		# Вхідні стовпи з ліхтарями.
		for side: float in [-1.0, 1.0]:
			var px := side * (hw + 0.05)
			var pz := end_sign * (half - 0.15)
			kit.box_at("wood", Vector3(px, g + 1.0, pz), Vector3(0.3, 2.0, 0.3))
			kit.pyramid("iron", Transform3D(Basis(), Vector3(px, g + 2.0, pz)), 0.42, 0.42, 0.26)
			kit.box_at("window", Vector3(px, g + 1.7, pz - end_sign * 0.2), Vector3(0.16, 0.22, 0.12))
	# Дерев'яні палі під дугою, що йдуть у дно.
	for t_pile: float in [0.3, 0.7]:
		var idx := int(round(t_pile * float(n)))
		var rp2 := rib_pts[idx]
		var floor_y := lerpf(ground_a, ground_b, t_pile) - 1.6
		for side: float in [-1.0, 1.0]:
			kit.box_at("bark", Vector3(side * (hw - 0.55), (rp2.y + floor_y) * 0.5, rp2.z), Vector3(0.34, rp2.y - floor_y, 0.34))
	for key in kit._tools.keys():
		kit.set_material(key, BuildingKit.mat(key))
	kit.build(root, "BridgeMesh", 420.0)
	if with_lights:
		for end_sign: float in [-1.0, 1.0]:
			var g2 := ground_a if end_sign < 0.0 else ground_b
			var light := FlickerLight.create(Color("#ffa04a"), 0.9, 8.0, 0.2, 5.0)
			light.position = Vector3(hw + 0.05, g2 + 1.7, end_sign * (half - 0.15))
			light.fade_begin = 60.0
			root.add_child(light)
	return root


# =====================================================================================
# Камінь Присяги (Каземати)
# =====================================================================================

static func build_oath_altar(gold_mat: Material, red_mat: Material) -> Node3D:
	## Камінь Присяги: триярусний постамент, різьблена стела з рунами та два плаваючі браслети-реліквії:
	## золотий «Браслет Зорі» (князівство) і залізний «Браслет Ока» (Гора).
	var root := Node3D.new()
	root.name = "OathAltar"
	var kit := MeshKit.new()
	kit.cylinder_at("stone_dark", Vector3(0, 0.0, 0), 3.6, 3.4, 0.45, 8, true)
	kit.cylinder_at("stone", Vector3(0, 0.45, 0), 2.9, 2.7, 0.4, 8, true)
	kit.cylinder_at("moss_stone", Vector3(0, 0.85, 0), 2.1, 1.95, 0.35, 8, true)
	# Стела: звужується догори, на гранях світяться руни, на вершині — шпиль.
	kit.box_at("stone_dark", Vector3(0, 2.4, 0), Vector3(1.5, 2.7, 1.1), true)
	kit.box_at("stone", Vector3(0, 3.95, 0), Vector3(1.2, 0.4, 0.9))
	kit.pyramid("stone_dark", Transform3D(Basis(), Vector3(0, 4.15, 0)), 0.95, 0.7, 1.0)
	for rz: float in [-1.0, 1.0]:
		for k in range(5):
			var y := 1.5 + float(k) * 0.5
			kit.box_at("window", Vector3(0, y, rz * 0.56), Vector3(0.9 - float(k % 2) * 0.35, 0.09, 0.04))
		kit.box_at("window", Vector3(0, 2.4, rz * 0.56), Vector3(0.09, 2.0, 0.04))
	# Чотири рунічні камені по колу та жаровні.
	for i in range(8):
		var a := TAU * float(i) / 8.0 + PI / 8.0
		var p := Vector3(cos(a) * 4.5, 0.0, sin(a) * 4.5)
		if i % 2 == 0:
			kit.box_at("stone_dark", p + Vector3(0, 0.9, 0), Vector3(0.7, 1.8, 0.5), true, Vector3(0, -a + PI * 0.5, 0))
			kit.box_at("window", p + Vector3(cos(a) * -0.27, 1.1, sin(a) * -0.27), Vector3(0.12, 0.8, 0.04), false, Vector3(0, -a + PI * 0.5, 0))
		else:
			kit.cylinder_at("iron", p, 0.28, 0.5, 0.9, 6)
			kit.box_at("ember", p + Vector3(0, 0.92, 0), Vector3(0.4, 0.12, 0.4))
	# Постаменти для двох браслетів — перед стелою, там, де стоїть герой.
	for side: float in [-1.0, 1.0]:
		var px := side * 2.4
		kit.cylinder_at("stone", Vector3(px, 0.0, -2.35), 0.6, 0.42, 1.15, 8, true)
		kit.cylinder_at("stone_dark", Vector3(px, 1.15, -2.35), 0.55, 0.55, 0.12, 8)
	for key in kit._tools.keys():
		kit.set_material(key, BuildingKit.mat(key))
	kit.build(root, "OathAltarMesh", 160.0)
	# Плаваючі браслети над постаментами.
	var gem_mat := PSXMaterials.make(Color("#9ab8ff"), 0.0, 0.3, Color("#6a9cff"), 2.4, "none", false)
	var gold_gem := PSXMaterials.make(Color("#ffdf8a"), 0.0, 0.3, Color("#ffcf5a"), 2.0, "none", false)
	var left := _spinner(root, "BraceletOfDawn", Vector3(-2.4, 1.95, -2.35), Vector3(0.0, 0.9, 0.0), 0.12, 1.4, 0.0)
	var left_tilt := Node3D.new()
	left_tilt.rotation = Vector3(deg_to_rad(70.0), 0.0, 0.0)
	left.add_child(left_tilt)
	_mesh(left_tilt, _torus(0.26, 0.36), gold_mat)
	_mesh(left_tilt, _torus(0.1, 0.13), gold_mat, Vector3(0.0, 0.0, 0.0))
	for g in range(4):
		var ga := TAU * float(g) / 4.0
		var gem := SphereMesh.new()
		gem.radius = 0.075
		gem.height = 0.15
		gem.radial_segments = 6
		gem.rings = 3
		_mesh(left_tilt, gem, gold_gem if g % 2 == 0 else gem_mat, Vector3(cos(ga) * 0.31, 0.06, sin(ga) * 0.31))
	var right := _spinner(root, "BraceletOfEye", Vector3(2.4, 1.95, -2.35), Vector3(0.0, -0.9, 0.0), 0.12, 1.4, 1.8)
	var right_tilt := Node3D.new()
	right_tilt.rotation = Vector3(deg_to_rad(70.0), 0.0, 0.0)
	right.add_child(right_tilt)
	_mesh(right_tilt, _torus(0.26, 0.36), red_mat)
	var spike_mat := PSXMaterials.make(Color("#2a1a1a"), 0.6, 0.5, Color.BLACK, 0.0, "metal", false)
	for g in range(6):
		var ga := TAU * float(g) / 6.0
		var dir := Vector3(cos(ga), 0.0, sin(ga))
		var spike := CylinderMesh.new()
		spike.top_radius = 0.0
		spike.bottom_radius = 0.06
		spike.height = 0.24
		spike.radial_segments = 5
		var spike_node := _mesh(right_tilt, spike, spike_mat, dir * 0.4)
		spike_node.basis = Basis(Vector3.UP.cross(dir).normalized(), PI * 0.5)
	var eye_gem := SphereMesh.new()
	eye_gem.radius = 0.12
	eye_gem.height = 0.24
	eye_gem.radial_segments = 8
	eye_gem.rings = 4
	_mesh(right_tilt, eye_gem, PSXMaterials.make(Color("#ff4a2a"), 0.0, 0.3, Color("#ff3010"), 3.0, "none", false), Vector3(0.0, 0.1, 0.0))
	# Рунічне кільце над стелою.
	var halo := _spinner(root, "RuneHalo", Vector3(0, 5.3, 0), Vector3(0.0, 0.5, 0.0), 0.1, 1.0, 0.7)
	_mesh(halo, _torus(0.92, 1.0), gold_mat, Vector3.ZERO, Vector3(deg_to_rad(90.0), 0.0, 0.0))
	_mesh(halo, _torus(0.5, 0.55), gold_mat, Vector3.ZERO, Vector3(deg_to_rad(90.0), 0.0, 0.0))
	return root


# =====================================================================================
# Фортеця Чорного Прапора: місто-острів посеред озера
# =====================================================================================

const FORT_RADIUS: float = 37.5
const FORT_SIDES: int = 16
const FORT_WALL_H: float = 11.0


static func _wall_segment(kit: MeshKit, a: Vector2, b: Vector2, h: float, thickness: float, rng: RandomNumberGenerator) -> void:
	var mid := (a + b) * 0.5
	var t := b - a
	var length := t.length()
	var yaw := atan2(-t.y, t.x)
	var outward := mid.normalized()
	kit.box_at("brick", Vector3(mid.x, (h - 3.0) * 0.5, mid.y), Vector3(length + 0.4, h + 3.0, thickness), true, Vector3(0, yaw, 0))
	kit.box_at("stone", Vector3(mid.x, h + 0.15, mid.y), Vector3(length + 0.6, 0.3, thickness + 0.4), false, Vector3(0, yaw, 0))
	# Кам'яний цоколь, що виходить із води, та зубці з зовнішнього боку.
	var plinth_mid := mid + outward * 0.5
	kit.box_at("stone_dark", Vector3(plinth_mid.x, -0.7, plinth_mid.y), Vector3(length + 0.9, 3.6, thickness + 1.4), false, Vector3(0, yaw, 0))
	var count := int(length / 2.4)
	for i in range(count):
		var k := (float(i) + 0.5) / float(count) - 0.5
		var p := mid + t.normalized() * (k * length) + outward * (thickness * 0.5 - 0.35)
		kit.box_at("stone", Vector3(p.x, h + 0.3 + 0.7, p.y), Vector3(1.15, 1.4, 0.8), false, Vector3(0, yaw, 0))
	# Бійниці під зубцями.
	if rng.randf() > 0.3:
		var slit := mid + outward * (thickness * 0.5 + 0.02)
		kit.box_at("cave_dark", Vector3(slit.x, h - 3.0, slit.y), Vector3(0.28, 1.5, 0.06), false, Vector3(0, yaw, 0))


static func _round_tower(kit: MeshKit, p: Vector2, r: float, h: float, roof_key: String, banner: bool, rng: RandomNumberGenerator) -> void:
	var base := Vector3(p.x, 0.0, p.y)
	kit.cylinder_at("stone_dark", base + Vector3(0, -3.0, 0), r * 1.2, r * 1.1, 3.6, 10, true)
	kit.cylinder_at("brick", base + Vector3(0, 0.6, 0), r * 1.05, r, h - 0.6, 10, true)
	kit.cylinder_at("stone", base + Vector3(0, h, 0), r * 1.22, r * 1.22, 0.5, 10)
	kit.cylinder_at(roof_key, base + Vector3(0, h + 0.5, 0), r * 1.35, 0.0, r * 2.4, 10)
	var outward := Vector3(p.x, 0.0, p.y).normalized()
	var yaw := atan2(-outward.x, -outward.z)
	BuildingKit._lancet(kit, Transform3D(Basis(Vector3.UP, yaw), base + outward * (r + 0.02) + Vector3(0, h * 0.62, 0)), 0.5, 1.4, "window")
	if banner:
		kit.box_at("wood", base + Vector3(0, h + r * 2.4 + 1.4, 0), Vector3(0.1, 2.8, 0.1))
		kit.box_at("cloth_black", base + Vector3(0.9, h + r * 2.4 + 2.0, 0), Vector3(1.6, 1.0, 0.05), false, Vector3(0, 0, 0.04))


static func _house(kit: MeshKit, root: Node3D, p: Vector2, face: Vector2, w: float, d: float, roof: String, rng: RandomNumberGenerator, lit: bool) -> void:
	var f := (face - p).normalized()
	var yaw := atan2(-f.x, -f.y)
	kit.origin = Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, 0.0, p.y))
	BuildingKit._hut(kit, root, w, d, rng, roof, lit)
	kit.origin = Transform3D.IDENTITY


static func build_waterfort(seed_value: int) -> Node3D:
	## Фортеця Чорного Прапора: кругла стіна з 16 вежами просто з води, брама на -Z (до мосту),
	## усередині — вулиці, площа з обеліском, ринок, будинки, дві готичні вежі й цитадель-донжон.
	var root := Node3D.new()
	root.name = "BlackBannerCitadel"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var kit := MeshKit.new()
	var r := FORT_RADIUS
	var h := FORT_WALL_H
	# Стіна та вежі на вершинах 16-кутника; брама — у сегменті навпроти -Z.
	var verts: Array[Vector2] = []
	for i in range(FORT_SIDES):
		var a := -PI * 0.5 + (float(i) - float(FORT_SIDES) * 0.5 + 0.5) * TAU / float(FORT_SIDES)
		verts.append(Vector2(cos(a), sin(a)) * r)
	var gate_index := -1
	for i in range(FORT_SIDES):
		var a: Vector2 = verts[i]
		var b: Vector2 = verts[(i + 1) % FORT_SIDES]
		var mid := (a + b) * 0.5
		if mid.y < -r * 0.97 and absf(mid.x) < 1.0:
			gate_index = i
			continue
		_wall_segment(kit, a, b, h, 3.2, rng)
	for i in range(FORT_SIDES):
		_round_tower(kit, verts[i], 3.5, 16.0 + float(i % 2) * 2.5, "shingle", i % 2 == 0, rng)
	# Брама: дві опори, арка, фронтон над нею, герса та стяги.
	if gate_index >= 0:
		var gz := (verts[gate_index].y + verts[(gate_index + 1) % FORT_SIDES].y) * 0.5
		for side: float in [-1.0, 1.0]:
			kit.box_at("brick", Vector3(side * 3.9, (h + 1.0 - 3.0) * 0.5, gz), Vector3(1.8, h + 4.0, 3.4), true)
			kit.box_at("stone_dark", Vector3(side * 3.9, -0.7, gz - 0.4), Vector3(2.6, 3.6, 4.2))
		BuildingKit._arch(kit, "stone", Vector3(0, 5.2, gz), 3.0, 0.9, 3.4, 9)
		kit.box_at("brick", Vector3(0, 10.3, gz), Vector3(8.0, 4.4, 3.2), true)
		kit.box_at("stone", Vector3(0, 12.7, gz), Vector3(8.6, 0.4, 3.6))
		for k in range(4):
			kit.box_at("stone", Vector3(-3.2 + float(k) * 2.1, 13.6, gz - 1.2), Vector3(1.2, 1.4, 0.8))
		for i in range(5):
			var gx := -2.3 + 4.6 * float(i) / 4.0
			var top := 5.2 + sqrt(maxf(9.0 - gx * gx, 0.01)) + 0.1
			kit.box_at("iron", Vector3(gx, (top + 6.2) * 0.5, gz), Vector3(0.14, top - 6.2, 0.14))
		kit.box_at("cloth_black", Vector3(-5.3, 8.0, gz - 1.72), Vector3(1.8, 5.0, 0.05))
		kit.box_at("cloth_black", Vector3(5.3, 8.0, gz - 1.72), Vector3(1.8, 5.0, 0.05))
		BuildingKit._light(root, kit, Vector3(-4.8, 4.5, gz - 2.6), Color("#ff8a3a"), 1.6, 11.0, 0.3, 6.0)
		BuildingKit._light(root, kit, Vector3(4.8, 4.5, gz - 2.6), Color("#ff8a3a"), 1.6, 11.0, 0.3, 6.0)
	# Валуни-хвилерізи по колу біля основи.
	for i in range(18):
		var a := TAU * float(i) / 18.0 + 0.1
		kit.rock("stone_dark", Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * (r + 2.6), -0.6, sin(a) * (r + 2.6))), Vector3(1.6, 1.3, 1.5), rng)

	# --- Місто всередині --------------------------------------------------------------------------
	var plaza := Vector2(0.0, 2.0)
	# Бруківка: головна вулиця від брами, поперечна вулиця, кругла площа.
	kit.box_at("stone", Vector3(0, 0.07, (gate_z_fallback(verts, gate_index) + plaza.y) * 0.5), Vector3(6.4, 0.14, plaza.y - gate_z_fallback(verts, gate_index) + 2.0))
	kit.box_at("stone", Vector3(0, 0.07, plaza.y), Vector3(58.0, 0.14, 5.0))
	kit.cylinder_at("stone", Vector3(plaza.x, 0.0, plaza.y), 11.0, 11.0, 0.16, 16)
	kit.cylinder_at("stone_dark", Vector3(plaza.x, 0.16, plaza.y), 7.0, 7.0, 0.05, 16)
	# Центр площі: чаша, обеліск Чорного Прапора, жаровні.
	kit.cylinder_at("stone", Vector3(plaza.x, 0.0, plaza.y), 3.2, 3.0, 1.0, 12, true)
	kit.cylinder_at("water", Vector3(plaza.x, 0.95, plaza.y), 2.8, 2.8, 0.04, 12)
	kit.box_at("stone_dark", Vector3(plaza.x, 4.2, plaza.y), Vector3(1.3, 6.4, 1.3), true)
	kit.pyramid("stone", Transform3D(Basis(), Vector3(plaza.x, 7.4, plaza.y)), 1.7, 1.7, 1.8)
	for face in range(4):
		var yaw := PI * 0.5 * float(face)
		var basis := Basis(Vector3.UP, yaw)
		kit.box("cloth_black", Transform3D(basis, Vector3(plaza.x, 5.0, plaza.y) + basis * Vector3(0, 0, -0.68)), Vector3(0.9, 3.6, 0.05))
		kit.box("ember", Transform3D(basis, Vector3(plaza.x, 6.6, plaza.y) + basis * Vector3(0, 0, -0.68)), Vector3(0.3, 0.3, 0.04))
	BuildingKit._light(root, kit, Vector3(plaza.x, 3.0, plaza.y - 2.5), Color("#ff7a30"), 2.6, 18.0, 0.3, 6.0, false, true)
	# Ринкові ятки навколо площі.
	for i in range(6):
		var a := TAU * float(i) / 6.0 + 0.5
		var sp := plaza + Vector2(cos(a), sin(a)) * 8.2
		var sb := Basis(Vector3.UP, atan2(-(plaza.x - sp.x), -(plaza.y - sp.y)))
		var base := Vector3(sp.x, 0.0, sp.y)
		for sx: float in [-1.0, 1.0]:
			kit.box_at("wood", base + sb * Vector3(sx * 1.3, 1.2, 0.6), Vector3(0.12, 2.4, 0.12))
			kit.box_at("wood", base + sb * Vector3(sx * 1.3, 0.9, -0.7), Vector3(0.12, 1.8, 0.12))
		kit.box("wood_light", Transform3D(sb, base + sb * Vector3(0, 0.9, -0.1)), Vector3(2.8, 0.9, 1.0), true)
		kit.box("cloth_red" if i % 2 == 0 else "cloth_tent", Transform3D(sb * Basis(Vector3.RIGHT, 0.25), base + sb * Vector3(0, 2.35, -0.05)), Vector3(3.2, 0.06, 1.9))
		BuildingKit._crate(kit, base + sb * Vector3(0.7, 0.0, -1.3), 0.6, 0.4)
		BuildingKit._barrel(kit, base + sb * Vector3(-1.0, 0.0, -1.4))
	# Будинки (вікна й димарі від _hut), двері обернені до вулиць.
	# [позиція, ширина, глибина, дах, точка, на яку дивляться двері]
	var houses := [
		[Vector2(-11, -28), 7.0, 5.5, "thatch", Vector2(0, -28)], [Vector2(11, -28), 7.5, 6.0, "shingle", Vector2(0, -28)],
		[Vector2(-11, -18), 6.5, 5.5, "shingle", Vector2(0, -18)], [Vector2(11, -18), 7.0, 5.5, "thatch", Vector2(0, -18)],
		[Vector2(-22, -22), 7.5, 6.0, "thatch", Vector2(-11, -22)], [Vector2(22, -22), 7.0, 6.0, "shingle", Vector2(11, -22)],
		[Vector2(-26, -9), 7.0, 6.0, "shingle", Vector2(-26, 2)], [Vector2(26, -9), 7.5, 6.0, "thatch", Vector2(26, 2)],
		[Vector2(-28, 9), 8.0, 6.5, "thatch", Vector2(-28, 2)], [Vector2(28, 9), 8.0, 6.5, "shingle", Vector2(28, 2)],
		[Vector2(-23, 18), 7.0, 5.5, "shingle", Vector2(-23, 2)], [Vector2(23, 18), 7.0, 5.5, "thatch", Vector2(23, 2)],
		[Vector2(-13, 13), 6.5, 5.5, "thatch", plaza], [Vector2(13, 13), 6.5, 5.5, "shingle", plaza],
	]
	for i in range(houses.size()):
		var hd: Array = houses[i]
		_house(kit, root, hd[0], hd[4], float(hd[1]), float(hd[2]), str(hd[3]), rng, i % 4 == 0)
	# Дві готичні вежі в кварталі храму.
	for side: float in [-1.0, 1.0]:
		var tp := Vector2(side * 17.0, 6.5)
		var ty := atan2(-(plaza.x - tp.x), -(plaza.y - tp.y))
		kit.origin = Transform3D(Basis(Vector3.UP, ty), Vector3(tp.x, 0.0, tp.y))
		BuildingKit._gothic_tower(kit, root, 7.0, rng, "gothic")
		kit.origin = Transform3D.IDENTITY
	# Цитадель Чорного Прапора: зала, центральна вежа, чотири башточки, стяги, ґратчаста брама.
	var kz := 25.0
	kit.box_at("brick", Vector3(0, (8.0 - 3.0) * 0.5, kz), Vector3(24.0, 11.0, 14.0), true)
	kit.box_at("stone", Vector3(0, 8.15, kz), Vector3(24.8, 0.3, 14.8))
	kit.gable_roof("shingle", "brick", Transform3D(Basis(), Vector3(0, 8.3, kz)), 24.0, 14.0, 5.0, 0.8, 0.26)
	kit.box_at("brick", Vector3(0, (24.0 - 3.0) * 0.5, kz + 3.0), Vector3(8.5, 27.0, 8.5), true)
	kit.box_at("stone", Vector3(0, 24.25, kz + 3.0), Vector3(9.3, 0.5, 9.3))
	kit.origin = Transform3D(Basis(), Vector3(0, 0, kz + 3.0))
	BuildingKit._crenels(kit, "stone", 24.5, 4.5, 4.5, 0.7)
	kit.origin = Transform3D.IDENTITY
	kit.pyramid("shingle", Transform3D(Basis(), Vector3(0, 24.5, kz + 3.0)), 6.0, 6.0, 9.0)
	kit.box_at("wood", Vector3(0, 36.5, kz + 3.0), Vector3(0.14, 3.0, 0.14))
	kit.box_at("cloth_black", Vector3(1.1, 36.8, kz + 3.0), Vector3(2.0, 1.2, 0.05))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var cp := Vector3(sx * 11.5, 0.0, kz + sz * 6.5)
			kit.cylinder_at("brick", cp + Vector3(0, -3.0, 0), 2.4, 2.1, 17.0, 8, true)
			kit.cylinder_at("shingle", cp + Vector3(0, 14.0, 0), 2.7, 0.0, 5.0, 8)
	for level: float in [0.35, 0.65, 0.88]:
		for sx: float in [-1.0, 1.0]:
			BuildingKit._lancet(kit, Transform3D(Basis(Vector3.UP, 0.0), Vector3(sx * 2.2, 24.0 * level, kz - 1.35)), 0.8, 2.0, "window" if level > 0.6 else "stone_dark")
	for sx: float in [-1.0, 1.0]:
		kit.box_at("cloth_black", Vector3(sx * 8.0, 5.0, kz - 7.1), Vector3(2.0, 7.0, 0.05))
	BuildingKit._door(kit, Transform3D(Basis(Vector3.UP, 0.0), Vector3(0, 0.0, kz - 7.05)), 3.2, 5.2, true)
	for i in range(5):
		kit.box_at("iron", Vector3(-1.2 + float(i) * 0.6, 3.0, kz - 7.2), Vector3(0.08, 5.0, 0.08))
	BuildingKit._light(root, kit, Vector3(0, 4.5, kz - 9.0), Color("#ff7a30"), 2.2, 14.0, 0.3, 6.0)
	BuildingKit._light(root, kit, Vector3(0, 22.0, kz - 1.0), Color("#ff3a1a"), 2.0, 16.0, 0.3, 3.0)
	# Лампи вздовж головної вулиці та причали з човнами за брамою.
	for lz: float in [-30.0, -20.0, -10.0]:
		for side: float in [-1.0, 1.0]:
			kit.box_at("wood", Vector3(side * 3.9, 1.4, lz), Vector3(0.14, 2.8, 0.14))
			kit.box_at("window", Vector3(side * 3.9, 2.9, lz), Vector3(0.22, 0.3, 0.22))
			kit.pyramid("iron", Transform3D(Basis(), Vector3(side * 3.9, 3.05, lz)), 0.34, 0.34, 0.2)
	BuildingKit._lamp_post(root, kit, Vector3(-3.9, 0.0, -25.0), 1.3)
	BuildingKit._lamp_post(root, kit, Vector3(3.9, 0.0, -15.0), 1.3)
	for side: float in [-1.0, 1.0]:
		var pier_x := side * 13.0
		for k in range(8):
			kit.box_at("wood_light", Vector3(pier_x, 0.28, -r - 4.5 - float(k) * 1.0), Vector3(2.2, 0.14, 0.95))
		for k in range(4):
			for px: float in [-1.0, 1.0]:
				kit.box_at("bark", Vector3(pier_x + px * 1.0, -0.5, -r - 4.5 - float(k) * 2.2), Vector3(0.22, 2.0, 0.22))
		# Човен біля причалу.
		var bz := -r - 9.0
		kit.box_at("wood", Vector3(pier_x + side * 2.2, -0.3, bz), Vector3(1.3, 0.5, 3.6))
		kit.pyramid("wood", Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(pier_x + side * 2.2, -0.3, bz - 1.8)), 1.3, 0.5, 0.9)
		kit.box_at("wood_light", Vector3(pier_x + side * 2.2, -0.02, bz), Vector3(1.0, 0.06, 3.0))
	for key in kit._tools.keys():
		kit.set_material(key, BuildingKit._wall_mat(Color("#3b3946")) if key == "wall" else BuildingKit.mat(key))
	kit.build(root, "BlackBannerCityMesh", 900.0)
	return root


static func gate_z_fallback(verts: Array[Vector2], gate_index: int) -> float:
	if gate_index < 0:
		return -FORT_RADIUS
	return (verts[gate_index].y + verts[(gate_index + 1) % FORT_SIDES].y) * 0.5


# =====================================================================================
# Вівтар Ока на вершині (плаваюча споруда)
# =====================================================================================

static func build_eye_altar() -> Node3D:
	## Навмисна левітація: кам'яна плита й Око висять над рунічним постаментом, між ними — стовп світла.
	var root := Node3D.new()
	root.name = "EyeAltar"
	var kit := MeshKit.new()
	# Постамент: низькі яруси, опорна колона та чотири обеліски по колу.
	kit.cylinder_at("stone_dark", Vector3(0, -0.4, 0), 7.6, 7.2, 0.7, 12)
	kit.cylinder_at("stone", Vector3(0, 0.0, 0), 6.2, 5.9, 0.3, 12)
	kit.cylinder_at("stone_dark", Vector3(0, 0.25, 0), 4.6, 4.3, 0.2, 12)
	kit.cylinder_at("stone", Vector3(0, 0.4, 0), 1.35, 1.0, 1.1, 8, true)
	kit.cylinder_at("ember", Vector3(0, 1.5, 0), 0.95, 0.95, 0.08, 8)
	for i in range(12):
		var a := TAU * float(i) / 12.0
		kit.box_at("window", Vector3(cos(a) * 5.35, 0.3, sin(a) * 5.35), Vector3(0.9, 0.06, 0.2), false, Vector3(0, -a + PI * 0.5, 0))
	for i in range(4):
		var a := TAU * float(i) / 4.0 + PI * 0.25
		var p := Vector3(cos(a) * 6.5, 0.0, sin(a) * 6.5)
		var basis := Basis(Vector3.UP, -a)
		kit.box("stone_dark", Transform3D(basis, p + Vector3(0, 3.0, 0)), Vector3(1.3, 6.0, 1.3), true)
		kit.pyramid("stone", Transform3D(basis, p + Vector3(0, 6.0, 0)), 1.5, 1.5, 1.4)
		kit.box("ember", Transform3D(basis, p + basis * Vector3(0, 4.2, -0.66)), Vector3(0.22, 1.8, 0.05))
		kit.box("ember", Transform3D(basis, p + basis * Vector3(0, 1.3, -0.66)), Vector3(0.5, 0.12, 0.05))
	for i in range(6):
		var a := TAU * float(i) / 6.0 + 0.3
		kit.rock("stone_dark", Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * 8.0, -0.2, sin(a) * 8.0)), Vector3(1.4, 0.9, 1.2), RandomNumberGenerator.new())
	for key in kit._tools.keys():
		kit.set_material(key, BuildingKit.mat(key))
	kit.build(root, "EyeAltarBase", 400.0)
	# Стовп світла між колоною та плитою.
	var beam_mat := PSXMaterials.make(Color(1.0, 0.25, 0.1, 0.35), 0.0, 1.0, Color("#ff3a10"), 2.2, "none", false, true)
	var beam := CylinderMesh.new()
	beam.top_radius = 0.5
	beam.bottom_radius = 0.9
	beam.height = 4.6
	beam.radial_segments = 8
	_mesh(root, beam, beam_mat, Vector3(0, 3.9, 0))
	# Плаваюча плита з Оком.
	var slab_mat := PSXMaterials.make(Color("#26232b"), 0.1, 0.9, Color.BLACK, 0.0, "stone", false)
	var rune_mat := PSXMaterials.make(Color("#ff7030"), 0.0, 0.4, Color("#ff4a10"), 3.2, "none", false)
	var iris_mat := PSXMaterials.make(Color("#ff5a2a"), 0.0, 0.3, Color("#ff2a00"), 4.0, "none", false)
	var floater := _spinner(root, "FloatingSlab", Vector3(0, 7.2, 0), Vector3(0.0, 0.18, 0.0), 0.35, 0.9, 0.0)
	var slab := BoxMesh.new()
	slab.size = Vector3(4.6, 0.7, 2.8)
	_mesh(floater, slab, slab_mat, Vector3.ZERO)
	var top := BoxMesh.new()
	top.size = Vector3(4.0, 0.14, 2.3)
	_mesh(floater, top, rune_mat, Vector3(0, 0.38, 0))
	for k in range(5):
		var rune := BoxMesh.new()
		rune.size = Vector3(0.14, 0.5, 0.05)
		_mesh(floater, rune, rune_mat, Vector3(-1.8 + float(k) * 0.9, 0.0, -1.42))
	var eye := SphereMesh.new()
	eye.radius = 0.85
	eye.height = 1.7
	eye.radial_segments = 10
	eye.rings = 5
	_mesh(floater, eye, PSXMaterials.make(Color("#d8cdb8"), 0.0, 0.7, Color.BLACK, 0.0, "none", false), Vector3(0, 1.5, 0)).name = "EyeBall"
	var iris := SphereMesh.new()
	iris.radius = 0.42
	iris.height = 0.84
	iris.radial_segments = 8
	iris.rings = 4
	_mesh(floater, iris, iris_mat, Vector3(0, 1.5, -0.55)).name = "EyeIris"
	var pupil := SphereMesh.new()
	pupil.radius = 0.18
	pupil.height = 0.36
	pupil.radial_segments = 6
	pupil.rings = 3
	_mesh(floater, pupil, PSXMaterials.make(Color("#050304"), 0.0, 1.0, Color.BLACK, 0.0, "none", false), Vector3(0, 1.5, -0.92)).name = "EyePupil"
	# Обертові кільця навколо Ока та хмара уламків.
	var ring_a := _spinner(root, "OrbitRingA", Vector3(0, 8.7, 0), Vector3(0.35, 0.0, 0.25), 0.2, 0.9, 1.0)
	_mesh(ring_a, _torus(2.5, 2.62), slab_mat, Vector3.ZERO, Vector3(deg_to_rad(90.0), 0.0, 0.0))
	var ring_b := _spinner(root, "OrbitRingB", Vector3(0, 8.7, 0), Vector3(-0.25, 0.4, 0.0), 0.2, 0.9, 1.0)
	_mesh(ring_b, _torus(3.3, 3.4), rune_mat, Vector3.ZERO, Vector3(deg_to_rad(90.0), 0.0, 0.0))
	var shard_group := _spinner(root, "ShardCloud", Vector3(0, 7.4, 0), Vector3(0.0, 0.55, 0.0))
	for i in range(8):
		var a := TAU * float(i) / 8.0
		var shard := BoxMesh.new()
		shard.size = Vector3(0.45, 0.9 + float(i % 3) * 0.3, 0.35)
		_mesh(shard_group, shard, slab_mat, Vector3(cos(a) * 4.4, sin(a * 2.0) * 1.2, sin(a) * 4.4), Vector3(0.4 * float(i), a, 0.3))
	var light := OmniLight3D.new()
	light.light_color = Color("#ff5a2a")
	light.light_energy = 2.6
	light.omni_range = 20.0
	light.position = Vector3(0, 7.6, 0)
	root.add_child(light)
	return root
