class_name HumanoidKit
extends RefCounted
## Процедурне гуманоїдне тіло з окремих анатомічних частин: ноги (стегно, коліно, гомілка, чобіт),
## тулуб (груди, пояс, плечові накладки), шия, голова з обличчям (FaceKit), руки (плече, лікоть,
## передпліччя, кисть), головний убір і зброя в руці. Рухом керує humanoid_anim.gd
## (ходьба, дихання, замах, жести під час розмови). Персонаж дивиться в -Z, ноги стоять на y = 0.

const ANIM_SCRIPT: GDScript = preload("res://scripts/world/humanoid_anim.gd")

## Готові вигляди мешканців. Ключ — «style», який передає world_generator.
const NPC_PRESETS: Dictionary = {
	"mage": {"build": "robe", "helm": "hat", "weapon": "staff", "orb": true},
	"alchemist": {"build": "robe", "helm": "hood", "weapon": "flask", "belt": true},
	"druid": {"build": "robe", "helm": "hood", "weapon": "staff", "orb": false},
	"priest": {"build": "robe", "helm": "none", "weapon": "staff", "orb": false},
	"scholar": {"build": "robe", "helm": "hat", "weapon": "book"},
	"elder": {"build": "robe", "helm": "none", "weapon": "cane"},
	"blacksmith": {"build": "smith", "helm": "none", "weapon": "hammer"},
	"guard": {"build": "armor", "helm": "helm", "weapon": "spear", "shield": true, "pauldrons": true},
	"captain": {"build": "armor", "helm": "plume", "weapon": "greatsword", "cape": true, "pauldrons": true},
	"hunter": {"build": "tunic", "helm": "hood", "weapon": "bow"},
	"merchant": {"build": "tunic", "helm": "hat", "weapon": "none", "pack": true, "belt": true},
	"villager": {"build": "tunic", "helm": "none", "weapon": "none"},
	"farmer": {"build": "tunic", "helm": "hat", "weapon": "pitchfork"},
	"woman": {"build": "robe", "helm": "hood", "weapon": "none"},
	"archer": {"build": "robe", "helm": "hood", "weapon": "bow"},
	"ghost": {"build": "robe", "helm": "hood", "weapon": "flask", "belt": true},
	"bard": {"build": "tunic", "helm": "skull", "weapon": "cane"},
	"barrelknight": {"build": "armor", "helm": "helm", "weapon": "none", "pauldrons": true},
}

## Вороги. Ключ — enemy_type із ashen_wraith.gd.
const ENEMY_PRESETS: Dictionary = {
	"ashen_wraith": {"build": "armor", "helm": "skull", "weapon": "sword", "cape": true, "cloth": "#2b2b31", "armor": "#5c4636", "accent": "#7a5a3c", "glow": "#d0352a", "face": "skull", "shield": false},
	"tower_guardian": {"build": "armor", "helm": "horned", "weapon": "axe", "shield": true, "pauldrons": true, "cloth": "#2a2c33", "armor": "#4a4d57", "accent": "#8a6a3a", "glow": "#d86a2a", "face": "skull", "scale": 1.25},
	"ash_knight": {"build": "armor", "helm": "plume", "weapon": "greatsword", "cape": true, "pauldrons": true, "cloth": "#1c1b20", "armor": "#2d2c34", "accent": "#a8431f", "glow": "#ff6a2a", "face": "skull", "scale": 1.3},
	"necromancer": {"build": "robe", "helm": "skullhood", "weapon": "staff", "orb": true, "cloth": "#22182e", "armor": "#3a2b4c", "accent": "#6bd68a", "glow": "#74f09a", "face": "skull", "scale": 1.1},
	"citadel_guardian": {"build": "armor", "helm": "crown", "weapon": "hammer", "shield": true, "cape": true, "pauldrons": true, "cloth": "#2a2220", "armor": "#5a5148", "accent": "#c29a58", "glow": "#e0a040", "face": "skull", "scale": 1.45},
	"enemy_knight": {"build": "armor", "helm": "helm", "weapon": "sword", "shield": true, "cape": true, "pauldrons": true, "cloth": "#15151c", "armor": "#3a3d48", "accent": "#a02a22", "glow": "#d03020", "face": "skull", "scale": 1.05},
	"skeleton": {"build": "tunic", "helm": "none", "weapon": "sword", "cloth": "#4a463c", "armor": "#6b6560", "accent": "#8a8272", "glow": "#b8e8c0", "face": "skull", "scale": 0.98, "bones": true},
	"skirmisher": {"build": "tunic", "helm": "skull", "weapon": "sword", "cloth": "#2e2c26", "armor": "#6b6560", "accent": "#a02a20", "glow": "#ffd060", "face": "skull", "scale": 0.94, "bones": true},
	"bone_knight": {"build": "armor", "helm": "horned", "weapon": "hammer", "shield": true, "cape": true, "pauldrons": true, "cloth": "#16161a", "armor": "#cfc7ae", "accent": "#5a5a40", "glow": "#70ff90", "face": "skull", "scale": 1.4},
	"bone_seer": {"build": "robe", "helm": "skullhood", "weapon": "staff", "orb": true, "cloth": "#241a34", "armor": "#3a2b4c", "accent": "#ff7a20", "glow": "#ff8a30", "face": "skull", "scale": 1.05},
	"skeleton_witch": {"build": "robe", "helm": "hat", "weapon": "staff", "orb": false, "skull_staff": true, "bones": true, "cloth": "#1c1424", "armor": "#3a2b4c", "accent": "#6a2a90", "glow": "#a060ff", "face": "skull", "scale": 1.12},
	"ancient_mage": {"build": "robe", "helm": "hood", "weapon": "staff", "orb": true, "cloth": "#14263a", "armor": "#3a5a7a", "accent": "#6ac8ff", "glow": "#7ad8ff", "face": "skull", "scale": 1.2},
	"eye_guardian": {"build": "armor", "helm": "crown", "weapon": "greatsword", "cape": true, "pauldrons": true, "eye": true, "cloth": "#1a1214", "armor": "#3b2124", "accent": "#d0302a", "glow": "#ff3a2a", "face": "skull", "scale": 1.7},
}


static func _mi(parent: Node3D, node_name: String, mesh: Mesh, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _cyl(top: float, bottom: float, height: float, seg: int = 7) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = seg
	mesh.rings = 1
	return mesh


static func _sph(radius: float, seg: int = 9) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = seg
	mesh.rings = maxi(seg / 2, 4)
	return mesh


static func _pivot(parent: Node3D, node_name: String, pos: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	node.position = pos
	parent.add_child(node)
	return node


static func _color(spec: Dictionary, key: String, fallback: String) -> Color:
	return Color(str(spec.get(key, fallback)))


static func spec_for_npc(style: String, robe_hex: String, accent_hex: String) -> Dictionary:
	var spec: Dictionary = (NPC_PRESETS.get(style, NPC_PRESETS["villager"]) as Dictionary).duplicate()
	spec["cloth"] = robe_hex
	spec["accent"] = accent_hex
	spec["armor"] = Color(robe_hex).lightened(0.18).to_html(false) if str(spec.get("build", "")) == "armor" else "#6b6560"
	spec["glow"] = accent_hex
	spec["face"] = "npc"
	return spec


static func spec_for_enemy(enemy_type: String) -> Dictionary:
	return (ENEMY_PRESETS.get(enemy_type, ENEMY_PRESETS["ashen_wraith"]) as Dictionary).duplicate()


static func build(parent: Node3D, spec: Dictionary, face_id: String = "") -> Node3D:
	## Збирає персонажа. Повертає вузол-ріг (з анімацією); rig.flash_materials — матеріали для спалаху удару.
	var rig := Node3D.new()
	rig.name = "HumanoidRig"
	rig.set_script(ANIM_SCRIPT)
	rig.scale = Vector3.ONE * float(spec.get("scale", 1.0))
	parent.add_child(rig)

	var build_kind := str(spec.get("build", "tunic"))
	var cloth_color := _color(spec, "cloth", "#4a4036")
	var accent_color := _color(spec, "accent", "#a08050")
	var armor_color := _color(spec, "armor", "#6b6560")
	var glow_color := _color(spec, "glow", "#d0352a")
	var is_skull: bool = str(spec.get("face", "npc")) == "skull"

	var cloth_mat := PSXMaterials.make(cloth_color, 0.0, 0.92, Color.BLACK, 0.0, "cloth", false)
	var pants_mat := PSXMaterials.make(cloth_color.darkened(0.25), 0.0, 0.92, Color.BLACK, 0.0, "cloth", false)
	var armor_mat := PSXMaterials.make(armor_color, 0.7, 0.42, Color.BLACK, 0.0, "metal", false)
	var accent_mat := PSXMaterials.make(accent_color, 0.35, 0.55, Color.BLACK, 0.0, "metal", false)
	var leather_mat := PSXMaterials.make(Color("#3a2a1e"), 0.0, 0.95, Color.BLACK, 0.0, "cloth", false)
	var boot_mat := PSXMaterials.make(Color("#26201c"), 0.0, 0.95, Color.BLACK, 0.0, "cloth", false)
	var bone_color := Color("#b4aa92") if is_skull else Color(str(FaceKit.config_for(face_id)["skin"]))
	var skin_mat := PSXMaterials.make(bone_color, 0.0, 0.95, Color.BLACK, 0.0, "stone" if is_skull else "none", false)
	var glow_mat := PSXMaterials.make(glow_color, 0.0, 0.3, glow_color, 2.4, "none", false)
	var wood_mat := PSXMaterials.make(Color("#4a3322"), 0.0, 0.95, Color.BLACK, 0.0, "planks", false)
	var steel_mat := PSXMaterials.make(Color("#b9bcc2"), 0.9, 0.3, Color.BLACK, 0.0, "metal", false)
	var rust_mat := PSXMaterials.make(Color("#6d4a34"), 0.8, 0.45, Color.BLACK, 0.0, "metal", false)
	var blade_mat: ShaderMaterial = rust_mat if str(spec.get("cloth", "")) == "#2b2b31" else steel_mat

	var robed: bool = build_kind == "robe"
	var armored: bool = build_kind == "armor"
	var chest_mat: ShaderMaterial = armor_mat if armored else cloth_mat
	var sleeve_mat: ShaderMaterial = armor_mat if armored else (skin_mat if build_kind == "smith" else cloth_mat)
	var greave_mat: ShaderMaterial = armor_mat if armored else pants_mat

	var parts: Dictionary = {}
	var body := _pivot(rig, "Body", Vector3.ZERO)
	parts["body"] = body

	# --- Ноги -------------------------------------------------------------------------------
	_mi(body, "Pelvis", _box(Vector3(0.40, 0.20, 0.25)), Vector3(0.0, 0.86, 0.0), pants_mat)
	for side in [-1, 1]:
		var tag: String = "L" if side < 0 else "R"
		var hip := _pivot(body, "Hip" + tag, Vector3(side * 0.115, 0.88, 0.0))
		_mi(hip, "Thigh", _cyl(0.09, 0.072, 0.44), Vector3(0.0, -0.22, 0.0), pants_mat)
		var knee := _pivot(hip, "Knee" + tag, Vector3(0.0, -0.44, 0.0))
		_mi(knee, "KneeCap", _sph(0.075, 7), Vector3.ZERO, greave_mat)
		_mi(knee, "Shin", _cyl(0.075, 0.056, 0.40), Vector3(0.0, -0.20, 0.0), greave_mat)
		_mi(knee, "Boot", _box(Vector3(0.15, 0.13, 0.31)), Vector3(0.0, -0.38, -0.05), boot_mat)
		parts["hip_" + tag.to_lower()] = hip
		parts["knee_" + tag.to_lower()] = knee

	if robed:
		_mi(body, "RobeSkirt", _cyl(0.23, 0.42, 0.86, 9), Vector3(0.0, 0.50, 0.0), cloth_mat)
		_mi(body, "RobeHem", _cyl(0.425, 0.43, 0.06, 9), Vector3(0.0, 0.09, 0.0), accent_mat)
	elif armored:
		_mi(body, "Tasset", _box(Vector3(0.42, 0.26, 0.30)), Vector3(0.0, 0.72, 0.0), cloth_mat)
	elif build_kind == "smith":
		_mi(body, "Apron", _box(Vector3(0.36, 0.62, 0.05)), Vector3(0.0, 0.58, -0.15), leather_mat)

	# --- Тулуб ------------------------------------------------------------------------------
	var spine := _pivot(body, "Spine", Vector3(0.0, 0.90, 0.0))
	parts["spine"] = spine
	_mi(spine, "Chest", _box(Vector3(0.50, 0.52, 0.28)), Vector3(0.0, 0.27, 0.0), chest_mat)
	_mi(spine, "Belt", _box(Vector3(0.46, 0.07, 0.30)), Vector3(0.0, 0.02, 0.0), accent_mat if not robed else leather_mat)
	_mi(spine, "BeltBuckle", _box(Vector3(0.08, 0.07, 0.02)), Vector3(0.0, 0.02, -0.155), steel_mat)
	if armored:
		_mi(spine, "Breastplate", _box(Vector3(0.44, 0.34, 0.06)), Vector3(0.0, 0.32, -0.15), accent_mat if str(spec.get("cloth", "")) != "#2b2b31" else rust_mat)
		_mi(spine, "Gorget", _cyl(0.17, 0.22, 0.10, 8), Vector3(0.0, 0.54, 0.0), armor_mat)
	if robed:
		_mi(spine, "Collar", _cyl(0.14, 0.27, 0.16, 8), Vector3(0.0, 0.52, 0.0), cloth_mat)
		_mi(spine, "Sash", _box(Vector3(0.1, 0.5, 0.02)), Vector3(0.0, 0.27, -0.145), accent_mat, Vector3(0.0, 0.0, 0.0))
	if bool(spec.get("eye", false)):
		_mi(spine, "EyeSocket", _cyl(0.14, 0.14, 0.04, 10), Vector3(0.0, 0.30, -0.175), armor_mat, Vector3(PI * 0.5, 0.0, 0.0))
		_mi(spine, "EyeCore", _sph(0.085, 8), Vector3(0.0, 0.30, -0.19), glow_mat, Vector3.ZERO, Vector3(1.0, 1.0, 0.5))
	if bool(spec.get("cape", false)):
		var cape := _mi(spine, "Cape", _box(Vector3(0.46, 0.95, 0.03)), Vector3(0.0, 0.0, 0.2), cloth_mat, Vector3(0.12, 0.0, 0.0))
		cape.mesh = _box(Vector3(0.46, 0.95, 0.03))
	if bool(spec.get("bones", false)):
		var bone_mat := PSXMaterials.make(Color("#d8d0b8"), 0.0, 0.9, Color.BLACK, 0.0, "stone", false)
		for i in range(4):
			_mi(spine, "Rib%d" % i, _box(Vector3(0.40 - float(i) * 0.04, 0.035, 0.04)), Vector3(0.0, 0.1 + float(i) * 0.1, -0.16), bone_mat)
		_mi(spine, "BoneSpine", _box(Vector3(0.05, 0.46, 0.04)), Vector3(0.0, 0.28, -0.165), bone_mat)
		for side in [-1.0, 1.0]:
			_mi(spine, "BoneSpikeA", _cyl(0.0, 0.045, 0.30, 5), Vector3(side * 0.40, 0.62, 0.0), bone_mat, Vector3(0.0, 0.0, -side * 0.9))
			_mi(spine, "BoneSpikeB", _cyl(0.0, 0.035, 0.22, 5), Vector3(side * 0.34, 0.66, 0.1), bone_mat, Vector3(0.4, 0.0, -side * 0.5))
	if bool(spec.get("pack", false)):
		_mi(spine, "Backpack", _box(Vector3(0.40, 0.46, 0.22)), Vector3(0.0, 0.26, 0.24), leather_mat)
		_mi(spine, "Bedroll", _cyl(0.1, 0.1, 0.5, 8), Vector3(0.0, 0.54, 0.26), cloth_mat, Vector3(0.0, 0.0, PI * 0.5))
	if bool(spec.get("belt", false)):
		for i in range(3):
			_mi(spine, "Pouch%d" % i, _box(Vector3(0.07, 0.09, 0.06)), Vector3(-0.17 + i * 0.12, -0.03, -0.17), leather_mat)

	# --- Шия й голова ------------------------------------------------------------------------
	_mi(spine, "Neck", _cyl(0.065, 0.075, 0.12, 7), Vector3(0.0, 0.58, 0.0), skin_mat)
	var head := _pivot(spine, "HeadPivot", Vector3(0.0, 0.78, 0.0))
	parts["head"] = head
	_mi(head, "Head", _sph(0.22, 10), Vector3.ZERO, skin_mat)
	_add_headgear(head, str(spec.get("helm", "none")), armor_mat, cloth_mat, accent_mat, glow_mat, steel_mat)
	if is_skull:
		FaceKit.attach_wraith(head, Vector3.ZERO)
		for side in [-1.0, 1.0]:
			_mi(head, "EyeGlow", _sph(0.04, 6), Vector3(side * 0.085, 0.02, -0.2), glow_mat)
	else:
		FaceKit.attach_npc(head, face_id, Vector3.ZERO)

	# --- Руки -------------------------------------------------------------------------------
	for side in [-1, 1]:
		var tag2: String = "l" if side < 0 else "r"
		var shoulder := _pivot(spine, "Shoulder" + tag2.to_upper(), Vector3(side * 0.33, 0.46, 0.0))
		_mi(shoulder, "UpperArm", _cyl(0.075, 0.062, 0.30), Vector3(0.0, -0.15, 0.0), sleeve_mat)
		if bool(spec.get("pauldrons", false)):
			_mi(shoulder, "Pauldron", _sph(0.135, 8), Vector3(side * 0.02, 0.03, 0.0), armor_mat, Vector3.ZERO, Vector3(1.1, 0.8, 1.0))
			_mi(shoulder, "PauldronEdge", _cyl(0.12, 0.15, 0.05, 8), Vector3(side * 0.03, -0.04, 0.0), accent_mat)
		else:
			_mi(shoulder, "ShoulderJoint", _sph(0.08, 7), Vector3.ZERO, sleeve_mat)
		var elbow := _pivot(shoulder, "Elbow" + tag2.to_upper(), Vector3(0.0, -0.30, 0.0))
		_mi(elbow, "ElbowJoint", _sph(0.063, 7), Vector3.ZERO, sleeve_mat if not armored else armor_mat)
		_mi(elbow, "Forearm", _cyl(0.062, 0.05, 0.27), Vector3(0.0, -0.14, 0.0), armor_mat if armored else (skin_mat if build_kind in ["smith"] else sleeve_mat))
		_mi(elbow, "Hand", _box(Vector3(0.095, 0.10, 0.10)), Vector3(0.0, -0.32, 0.0), leather_mat if armored else skin_mat)
		var grip := _pivot(elbow, "Grip" + tag2.to_upper(), Vector3(0.0, -0.32, 0.0))
		parts["sh_" + tag2] = shoulder
		parts["el_" + tag2] = elbow
		parts["grip_" + tag2] = grip

	# --- Зброя та щит ------------------------------------------------------------------------
	var weapon := str(spec.get("weapon", "none"))
	var rest := _weapon_rest(weapon)
	var grip_r: Node3D = parts["grip_r"]
	_add_weapon(grip_r, weapon, steel_mat if blade_mat == steel_mat else rust_mat, wood_mat, accent_mat, glow_mat, armor_mat, leather_mat, bool(spec.get("orb", false)))
	grip_r.rotation.x = float(rest["target"]) - (float(rest["sh"]) + float(rest["el"]))
	if bool(spec.get("skull_staff", false)):
		var bone2 := PSXMaterials.make(Color("#d8d0b8"), 0.0, 0.9, Color.BLACK, 0.0, "stone", false)
		var gr: Node3D = parts["grip_r"]
		_mi(gr, "StaffSkull", _sph(0.15, 8), Vector3(0.0, 1.44, 0.0), bone2, Vector3.ZERO, Vector3(1.0, 1.1, 1.0))
		_mi(gr, "StaffJaw", _box(Vector3(0.13, 0.05, 0.12)), Vector3(0.0, 1.31, -0.04), bone2)
		for side in [-1.0, 1.0]:
			_mi(gr, "StaffEye", _sph(0.035, 5), Vector3(side * 0.06, 1.46, -0.125), glow_mat)
			_mi(gr, "StaffHorn", _cyl(0.0, 0.03, 0.34, 5), Vector3(side * 0.12, 1.62, 0.0), bone2, Vector3(0.0, 0.0, -side * 0.6))
		var sl := OmniLight3D.new()
		sl.name = "OrbLight"
		sl.light_color = glow_color
		sl.light_energy = 0.9
		sl.omni_range = 5.0
		sl.position = Vector3(0.0, 1.44, 0.0)
		gr.add_child(sl)
	if bool(spec.get("shield", false)):
		var el_l: Node3D = parts["el_l"]
		_mi(el_l, "Shield", _cyl(0.30, 0.30, 0.05, 10), Vector3(-0.12, -0.22, -0.02), armor_mat, Vector3(0.0, 0.0, PI * 0.5), Vector3(1.0, 1.0, 1.0))
		_mi(el_l, "ShieldBoss", _sph(0.07, 6), Vector3(-0.15, -0.22, -0.02), accent_mat)
		_mi(el_l, "ShieldRim", _cyl(0.31, 0.31, 0.02, 10), Vector3(-0.145, -0.22, -0.02), accent_mat, Vector3(0.0, 0.0, PI * 0.5))
	if weapon == "book":
		var grip_l: Node3D = parts["grip_l"]
		_mi(grip_l, "Book", _box(Vector3(0.22, 0.06, 0.30)), Vector3(0.0, 0.0, -0.1), accent_mat)
		_mi(grip_l, "BookPages", _box(Vector3(0.2, 0.05, 0.28)), Vector3(0.0, 0.005, -0.1), PSXMaterials.make(Color("#d8cfb8"), 0.0, 0.95, Color.BLACK, 0.0, "none", false))

	rig.call("setup", parts, rest, weapon)
	rig.set("flash_materials", [cloth_mat, armor_mat, pants_mat])
	return rig


static func _weapon_rest(weapon: String) -> Dictionary:
	## Стійка правої руки: кут плеча, кут ліктя, куди дивиться «вісь зброї» (радіани в площині YZ).
	match weapon:
		"staff", "pitchfork", "spear", "cane":
			return {"sh": 0.12, "el": 0.45, "target": -0.12}
		"hammer", "axe", "greatsword":
			return {"sh": 0.35, "el": 1.0, "target": -0.55}
		"sword":
			return {"sh": 0.45, "el": 1.1, "target": -0.8}
		"bow":
			return {"sh": 0.55, "el": 0.7, "target": -0.2}
		"flask":
			return {"sh": 0.7, "el": 1.5, "target": -0.2}
		_:
			return {"sh": 0.05, "el": 0.15, "target": 0.0}


static func _add_headgear(head: Node3D, kind: String, armor_mat: Material, cloth_mat: Material, accent_mat: Material, glow_mat: Material, steel_mat: Material) -> void:
	match kind:
		"hood", "skullhood":
			_mi(head, "Hood", _sph(0.255, 9), Vector3(0.0, 0.10, -0.075), cloth_mat, Vector3.ZERO, Vector3(1.0, 0.78, 1.0))
			_mi(head, "HoodBack", _box(Vector3(0.44, 0.50, 0.12)), Vector3(0.0, -0.03, 0.17), cloth_mat)
			_mi(head, "HoodPeak", _cyl(0.0, 0.14, 0.26, 6), Vector3(0.0, 0.22, 0.16), cloth_mat, Vector3(-0.5, 0.0, 0.0))
		"hat":
			_mi(head, "Hat", _cyl(0.015, 0.30, 0.52, 7), Vector3(0.0, 0.41, 0.0), accent_mat)
			_mi(head, "HatBrim", _cyl(0.36, 0.36, 0.03, 9), Vector3(0.0, 0.17, 0.0), accent_mat)
		"helm", "horned", "plume", "crown", "skull":
			_mi(head, "Helmet", _sph(0.245, 9), Vector3(0.0, 0.10, 0.06), armor_mat, Vector3.ZERO, Vector3(1.0, 0.70, 1.05))
			_mi(head, "HelmBack", _box(Vector3(0.40, 0.40, 0.08)), Vector3(0.0, -0.05, 0.19), armor_mat)
			for side in [-1.0, 1.0]:
				_mi(head, "CheekGuard", _box(Vector3(0.04, 0.22, 0.20)), Vector3(side * 0.205, -0.07, -0.02), armor_mat)
			if kind != "skull":
				_mi(head, "Nasal", _box(Vector3(0.035, 0.16, 0.03)), Vector3(0.0, -0.03, -0.235), armor_mat)
			if kind == "horned":
				for side in [-1.0, 1.0]:
					_mi(head, "Horn", _cyl(0.0, 0.05, 0.34, 6), Vector3(side * 0.26, 0.2, 0.0), steel_mat, Vector3(0.0, 0.0, -side * 0.7))
			elif kind == "plume":
				_mi(head, "Crest", _box(Vector3(0.05, 0.12, 0.40)), Vector3(0.0, 0.3, 0.04), accent_mat)
				_mi(head, "Plume", _cyl(0.02, 0.09, 0.42, 6), Vector3(0.0, 0.34, 0.28), glow_mat, Vector3(1.2, 0.0, 0.0))
			elif kind == "crown":
				_mi(head, "CrownRing", _cyl(0.23, 0.24, 0.07, 10), Vector3(0.0, 0.24, 0.0), accent_mat)
				for i in range(7):
					var angle := TAU * float(i) / 7.0
					_mi(head, "CrownSpike%d" % i, _cyl(0.0, 0.035, 0.18, 5), Vector3(cos(angle) * 0.22, 0.34, sin(angle) * 0.22), accent_mat)
			elif kind == "skull":
				_mi(head, "Rag", _box(Vector3(0.36, 0.08, 0.04)), Vector3(0.0, 0.12, -0.2), armor_mat)
		_:
			pass


static func _add_weapon(grip: Node3D, weapon: String, blade_mat: Material, wood_mat: Material, accent_mat: Material, glow_mat: Material, armor_mat: Material, leather_mat: Material, orb: bool) -> void:
	match weapon:
		"sword", "greatsword":
			var big: bool = weapon == "greatsword"
			var blade_len: float = 1.25 if big else 0.82
			var blade_w: float = 0.14 if big else 0.07
			_mi(grip, "Handle", _cyl(0.026, 0.026, 0.24, 6), Vector3(0.0, 0.0, 0.0), leather_mat)
			_mi(grip, "Pommel", _sph(0.04, 6), Vector3(0.0, -0.13, 0.0), accent_mat)
			_mi(grip, "Guard", _box(Vector3(0.34 if big else 0.26, 0.045, 0.06)), Vector3(0.0, 0.13, 0.0), accent_mat)
			_mi(grip, "Blade", _box(Vector3(blade_w, blade_len, 0.02)), Vector3(0.0, 0.14 + blade_len * 0.5, 0.0), blade_mat)
			_mi(grip, "BladeTip", _cyl(0.0, blade_w * 0.5, 0.14, 4), Vector3(0.0, 0.14 + blade_len + 0.07, 0.0), blade_mat)
			if big:
				_mi(grip, "BladeGlow", _box(Vector3(0.03, blade_len * 0.8, 0.026)), Vector3(0.0, 0.14 + blade_len * 0.5, 0.0), glow_mat)
		"axe":
			_mi(grip, "Haft", _cyl(0.03, 0.035, 1.05, 6), Vector3(0.0, 0.3, 0.0), wood_mat)
			_mi(grip, "AxeHead", _box(Vector3(0.34, 0.26, 0.05)), Vector3(0.17, 0.72, 0.0), blade_mat)
			_mi(grip, "AxeEdge", _cyl(0.0, 0.15, 0.1, 4), Vector3(0.38, 0.72, 0.0), blade_mat, Vector3(0.0, 0.0, -PI * 0.5), Vector3(1.0, 1.0, 0.4))
			_mi(grip, "AxeSpike", _cyl(0.0, 0.04, 0.2, 4), Vector3(0.0, 0.9, 0.0), blade_mat)
		"hammer":
			_mi(grip, "Haft", _cyl(0.03, 0.035, 0.95, 6), Vector3(0.0, 0.28, 0.0), wood_mat)
			_mi(grip, "HammerHead", _box(Vector3(0.30, 0.2, 0.2)), Vector3(0.0, 0.82, 0.0), blade_mat if armor_mat == null else armor_mat)
			_mi(grip, "HammerBand", _box(Vector3(0.32, 0.04, 0.22)), Vector3(0.0, 0.82, 0.0), accent_mat)
		"staff":
			_mi(grip, "StaffShaft", _cyl(0.03, 0.04, 1.9, 6), Vector3(0.0, 0.35, 0.0), wood_mat)
			if orb:
				_mi(grip, "StaffOrb", _sph(0.12, 8), Vector3(0.0, 1.38, 0.0), glow_mat)
				for side in [-1.0, 1.0]:
					_mi(grip, "StaffClaw", _cyl(0.0, 0.035, 0.26, 5), Vector3(side * 0.09, 1.28, 0.0), wood_mat, Vector3(0.0, 0.0, -side * 0.35))
				var light := OmniLight3D.new()
				light.name = "OrbLight"
				light.light_color = (glow_mat as ShaderMaterial).get_shader_parameter("emission_color")
				light.light_energy = 0.9
				light.omni_range = 4.5
				light.position = Vector3(0.0, 1.38, 0.0)
				grip.add_child(light)
			else:
				_mi(grip, "StaffTop", _sph(0.07, 6), Vector3(0.0, 1.32, 0.0), accent_mat)
		"cane":
			_mi(grip, "Cane", _cyl(0.025, 0.035, 1.15, 6), Vector3(0.0, 0.1, 0.0), wood_mat)
			_mi(grip, "CaneKnob", _sph(0.05, 6), Vector3(0.0, 0.7, 0.0), accent_mat)
		"spear":
			_mi(grip, "SpearShaft", _cyl(0.025, 0.035, 2.3, 6), Vector3(0.0, 0.5, 0.0), wood_mat)
			_mi(grip, "SpearTip", _cyl(0.0, 0.07, 0.3, 5), Vector3(0.0, 1.78, 0.0), blade_mat)
		"pitchfork":
			_mi(grip, "ForkShaft", _cyl(0.025, 0.03, 1.7, 6), Vector3(0.0, 0.4, 0.0), wood_mat)
			for i in range(3):
				_mi(grip, "Tine%d" % i, _cyl(0.0, 0.015, 0.3, 4), Vector3(-0.08 + i * 0.08, 1.38, 0.0), blade_mat)
			_mi(grip, "ForkBar", _box(Vector3(0.2, 0.025, 0.03)), Vector3(0.0, 1.24, 0.0), blade_mat)
		"bow":
			var bow := _mi(grip, "Bow", TorusMesh.new(), Vector3(0.0, 0.2, 0.0), wood_mat, Vector3(0.0, PI * 0.5, 0.0), Vector3(1.0, 1.0, 1.0))
			(bow.mesh as TorusMesh).inner_radius = 0.34
			(bow.mesh as TorusMesh).outer_radius = 0.38
			(bow.mesh as TorusMesh).rings = 8
			(bow.mesh as TorusMesh).ring_segments = 5
		"flask":
			_mi(grip, "Flask", _sph(0.09, 7), Vector3(0.0, 0.08, 0.0), glow_mat)
			_mi(grip, "FlaskNeck", _cyl(0.03, 0.03, 0.1, 6), Vector3(0.0, 0.2, 0.0), accent_mat)
		_:
			pass
