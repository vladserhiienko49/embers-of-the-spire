class_name KnightArmor
extends RefCounted
## Повний обладунок темного лицаря (PS1 dark fantasy), власний процедурний лицар (dress_rig на HumanoidKit).
## Кожна деталь — дочірній вузол частини ріґа HumanoidKit, тому анімації героя працюють без змін.
## Повертає словник із вузлами: "back_anchor" (меч на спині), "attachments".

const STEEL := Color("#3a3d45")
const STEEL_DARK := Color("#24262c")
const TRIM := Color("#8a6a34")
const LEATHER := Color("#3b2a1c")
const CLOTH := Color("#4a1414")
const CHAIN := Color("#55585e")
const FUR := Color("#2a2420")

static var _mats: Dictionary = {}


static func _mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m: Material
	match key:
		"steel": m = PSXMaterials.make(STEEL, 0.75, 0.38, Color.BLACK, 0.0, "metal", false)
		"steel_dark": m = PSXMaterials.make(STEEL_DARK, 0.7, 0.45, Color.BLACK, 0.0, "metal", false)
		"trim": m = PSXMaterials.make(TRIM, 0.85, 0.3, Color("#3a2a10"), 0.25, "metal", false)
		"leather": m = PSXMaterials.make(LEATHER, 0.0, 0.85, Color.BLACK, 0.0, "cloth", false)
		"cloth": m = PSXMaterials.make(CLOTH, 0.0, 0.95, Color.BLACK, 0.0, "cloth", false)
		"chain": m = PSXMaterials.make(CHAIN, 0.6, 0.55, Color.BLACK, 0.0, "metal", false)
		"fur": m = PSXMaterials.make(FUR, 0.0, 1.0, Color.BLACK, 0.0, "cloth", false)
		"visor": m = PSXMaterials.make(Color("#050405"), 0.0, 1.0, Color.BLACK, 0.0, "none", false)
		"eyes": m = PSXMaterials.make(Color("#ff7a30"), 0.0, 0.4, Color("#ff5a10"), 3.2, "none", false)
		"horn": m = PSXMaterials.make(Color("#1c1a1a"), 0.2, 0.6, Color.BLACK, 0.0, "none", false)
		_: m = PSXMaterials.make(Color.MAGENTA)
	_mats[key] = m
	return m


## Рівень обладунку змінює вигляд: 1 кольчуга (світліша сталь), 2 посилена (темно-синя), 3 легендарна (золото з жаром).
static func apply_tier(tier: int) -> void:
	var steel := _mat("steel")
	var dark := _mat("steel_dark")
	var trim := _mat("trim")
	match tier:
		1:
			PSXMaterials.set_albedo(steel, Color("#555a63"))
		2:
			PSXMaterials.set_albedo(steel, Color("#3a4a66"))
			PSXMaterials.set_albedo(dark, Color("#1c2438"))
		3:
			PSXMaterials.set_albedo(steel, Color("#8a6a24"))
			PSXMaterials.set_albedo(dark, Color("#241a0a"))
			PSXMaterials.set_albedo(trim, Color("#e8c050"))
			PSXMaterials.set_emission(steel, Color("#5a3a08"), 0.35)
			PSXMaterials.set_emission(trim, Color("#ffd060"), 0.9)


static func _piece(parent: Node3D, mesh: Mesh, mat_key: String, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = _mat(mat_key)
	n.position = pos
	n.rotation_degrees = rot_deg
	n.scale = scl
	parent.add_child(n)
	return n


static func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


static func _cyl(r_bottom: float, r_top: float, h: float, sides: int = 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.bottom_radius = r_bottom
	c.top_radius = r_top
	c.height = h
	c.radial_segments = sides
	c.rings = 1
	return c


static func _sphere(r: float, hemi: bool = false) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r if hemi else r * 2.0
	s.is_hemisphere = hemi
	s.radial_segments = 8
	s.rings = 4
	return s


## Обладунок на процедурному ріґу HumanoidKit (замість кісток Mixamo). Система координат ріґа: перед — -Z,
## ліва рука — -X, праве плече — +X. Повертає те саме, що й dress(): "attachments" та "back_anchor".
static func dress_rig(parts: Dictionary) -> Dictionary:
	var result := {"attachments": [], "back_anchor": null}
	var list: Array = result["attachments"]

	# --- Таз: пояс, набедреники, табард -------------------------------------------------------
	var body: Node3D = parts["body"]
	var a := Node3D.new()
	a.name = "ArmorHips"
	body.add_child(a)
	list.append(a)
	_piece(a, _cyl(0.235, 0.23, 0.09, 10), "leather", Vector3(0, 0.93, 0))
	_piece(a, _box(0.09, 0.07, 0.03), "trim", Vector3(0, 0.93, -0.235))
	_piece(a, _cyl(0.26, 0.23, 0.17, 10), "steel", Vector3(0, 0.80, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.85))
	for side: float in [-1.0, 1.0]:
		_piece(a, _box(0.14, 0.22, 0.04), "steel_dark", Vector3(side * 0.22, 0.7, 0.0), Vector3(0, side * 80.0, side * 10.0))
	_piece(a, _box(0.24, 0.6, 0.025), "cloth", Vector3(0, 0.58, -0.205), Vector3(-5.0, 0, 0))
	_piece(a, _box(0.26, 0.58, 0.025), "cloth", Vector3(0, 0.6, 0.2), Vector3(5.0, 0, 0))
	_piece(a, _box(0.25, 0.03, 0.03), "trim", Vector3(0, 0.29, -0.23), Vector3(-5.0, 0, 0))

	# --- Тулуб: кіраса, наспинник, комір із хутра, плащ і меч у піхвах на спині ----------------
	var spine: Node3D = parts["spine"]
	var b := Node3D.new()
	b.name = "ArmorChest"
	spine.add_child(b)
	list.append(b)
	_piece(b, _cyl(0.22, 0.265, 0.5, 10), "steel", Vector3(0, 0.27, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.8))
	_piece(b, _cyl(0.2, 0.215, 0.14, 10), "chain", Vector3(0, 0.0, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.82))
	for k in range(3):
		_piece(b, _box(0.34, 0.045, 0.06), "steel", Vector3(0, 0.04 + 0.05 * float(k), -0.17), Vector3(6.0, 0, 0))
	_piece(b, _box(0.05, 0.3, 0.05), "steel_dark", Vector3(0, 0.3, -0.2), Vector3(0, 45.0, 0))
	_piece(b, _box(0.44, 0.035, 0.33), "trim", Vector3(0, 0.52, 0))
	_piece(b, _box(0.1, 0.1, 0.02), "trim", Vector3(0, 0.3, -0.21), Vector3(0, 0, 45.0))
	_piece(b, _cyl(0.28, 0.2, 0.1, 10), "fur", Vector3(0, 0.58, 0.02), Vector3.ZERO, Vector3(1.0, 1.0, 0.85))
	_piece(b, _cyl(0.14, 0.1, 0.12, 10), "steel", Vector3(0, 0.64, 0))
	var cape := Node3D.new()
	cape.name = "Cape"
	cape.position = Vector3(0, 0.55, 0.17)
	cape.rotation_degrees = Vector3(9.0, 0, 0)
	b.add_child(cape)
	_piece(cape, _box(0.5, 0.62, 0.025), "cloth", Vector3(0, -0.31, 0))
	_piece(cape, _box(0.54, 0.5, 0.025), "cloth", Vector3(0, -0.85, 0.04), Vector3(5.0, 0, 0))
	_piece(cape, _box(0.54, 0.04, 0.03), "trim", Vector3(0, -1.09, 0.06), Vector3(5.0, 0, 0))
	_piece(b, _box(0.05, 0.6, 0.02), "leather", Vector3(0.02, 0.3, -0.215), Vector3(0, 0, 21.0))
	# Піхви: руків'я над правим плечем (+X), клинок униз до лівого стегна (-X). Клинок меча йде вздовж -Z якоря.
	var anchor := Node3D.new()
	anchor.name = "BackSwordAnchor"
	anchor.transform = Transform3D(Basis(Vector3(-0.93, 0.36, 0.0), Vector3(0, 0, 1), Vector3(0.36, 0.93, 0.0)), Vector3(0.17, 0.6, 0.23))
	b.add_child(anchor)
	var scab := Node3D.new()
	scab.name = "Scabbard"
	anchor.add_child(scab)
	_piece(scab, _box(0.085, 0.045, 0.86), "leather", Vector3(0, 0.0, -0.57))
	_piece(scab, _box(0.095, 0.055, 0.06), "trim", Vector3(0, 0.0, -0.15))
	_piece(scab, _box(0.095, 0.055, 0.08), "trim", Vector3(0, 0.0, -0.99))
	result["back_anchor"] = anchor

	# --- Шолом: закритий, щілина візора з тліючими очима, гребінь, роги --------------------------
	var head: Node3D = parts["head"]
	var h := Node3D.new()
	h.name = "ArmorHelm"
	head.add_child(h)
	list.append(h)
	_piece(h, _cyl(0.245, 0.235, 0.4, 10), "steel", Vector3(0, 0.0, 0.0), Vector3.ZERO, Vector3(1.0, 1.0, 1.05))
	_piece(h, _sphere(0.24, true), "steel", Vector3(0, 0.2, 0.0), Vector3.ZERO, Vector3(1.0, 0.75, 1.05))
	_piece(h, _box(0.2, 0.028, 0.04), "visor", Vector3(0, 0.03, -0.235))
	_piece(h, _box(0.028, 0.14, 0.035), "visor", Vector3(0, -0.05, -0.24))
	for side: float in [-1.0, 1.0]:
		_piece(h, _box(0.035, 0.018, 0.02), "eyes", Vector3(side * 0.05, 0.03, -0.25))
	_piece(h, _box(0.03, 0.06, 0.34), "trim", Vector3(0, 0.37, 0.0))
	_piece(h, _box(0.24, 0.03, 0.03), "trim", Vector3(0, -0.12, -0.22))
	for side: float in [-1.0, 1.0]:
		var horn := Node3D.new()
		horn.position = Vector3(side * 0.22, 0.15, 0.0)
		horn.rotation_degrees = Vector3(-25.0, 0, side * -55.0)
		h.add_child(horn)
		_piece(horn, _cyl(0.035, 0.026, 0.12, 6), "horn", Vector3(0, 0.06, 0))
		_piece(horn, _cyl(0.026, 0.0, 0.16, 6), "horn", Vector3(0, 0.17, 0.02), Vector3(30.0, 0, side * 20.0))

	# --- Руки: наплічники, наручі, лікті, рукавиці ---------------------------------------------------
	for tag in ["l", "r"]:
		var sh: Node3D = parts["sh_" + tag]
		var c := Node3D.new()
		c.name = "ArmorArm_" + tag
		sh.add_child(c)
		list.append(c)
		_piece(c, _sphere(0.14, true), "steel", Vector3(0, 0.02, 0.0), Vector3.ZERO, Vector3(1.25, 1.1, 1.25))
		for k in range(3):
			_piece(c, _cyl(0.15 - float(k) * 0.012, 0.13 - float(k) * 0.012, 0.045, 8), "steel_dark" if k % 2 == 0 else "steel", Vector3(0, -0.01 - 0.045 * float(k), 0))
		_piece(c, _cyl(0.078, 0.07, 0.24, 8), "steel", Vector3(0, -0.2, 0))
		var el: Node3D = parts["el_" + tag]
		var f := Node3D.new()
		f.name = "ArmorFore_" + tag
		el.add_child(f)
		list.append(f)
		_piece(f, _sphere(0.07), "steel_dark", Vector3(0, 0.0, 0.0))
		_piece(f, _cyl(0.068, 0.056, 0.25, 8), "steel", Vector3(0, -0.15, 0))
		_piece(f, _cyl(0.072, 0.072, 0.025, 8), "trim", Vector3(0, -0.27, 0))
		var gr: Node3D = parts["grip_" + tag]
		var g := Node3D.new()
		g.name = "ArmorGauntlet_" + tag
		gr.add_child(g)
		list.append(g)
		_piece(g, _cyl(0.07, 0.08, 0.08, 8), "steel_dark", Vector3(0, 0.0, 0))
		_piece(g, _box(0.095, 0.08, 0.05), "steel", Vector3(0, -0.07, 0.0))

	# --- Ноги: набедреники, наколінники, поножі, сабатони -----------------------------------------------
	for tag in ["l", "r"]:
		var hip: Node3D = parts["hip_" + tag]
		var t := Node3D.new()
		t.name = "ArmorThigh_" + tag
		hip.add_child(t)
		list.append(t)
		_piece(t, _cyl(0.1, 0.11, 0.38, 8), "chain", Vector3(0, -0.22, 0))
		_piece(t, _cyl(0.085, 0.105, 0.28, 8), "steel", Vector3(0, -0.2, -0.014), Vector3.ZERO, Vector3(1.0, 1.0, 1.05))
		var knee: Node3D = parts["knee_" + tag]
		var s := Node3D.new()
		s.name = "ArmorShin_" + tag
		knee.add_child(s)
		list.append(s)
		_piece(s, _sphere(0.085), "steel", Vector3(0, 0.0, -0.03))
		_piece(s, _box(0.11, 0.1, 0.025), "steel_dark", Vector3(0, -0.03, -0.085))
		_piece(s, _cyl(0.08, 0.062, 0.3, 8), "steel", Vector3(0, -0.2, 0.0))
		_piece(s, _cyl(0.075, 0.082, 0.1, 8), "leather", Vector3(0, -0.34, 0))
		_piece(s, _cyl(0.085, 0.085, 0.025, 8), "trim", Vector3(0, -0.3, 0))
		_piece(s, _box(0.118, 0.07, 0.2), "steel_dark", Vector3(0, -0.37, -0.06))
	return result
