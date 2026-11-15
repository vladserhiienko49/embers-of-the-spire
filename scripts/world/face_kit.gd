class_name FaceKit
extends RefCounted
## Обличчя у стилі PS1: піксельна текстура 48×48 (очі, брови, темні кола, зморшки, шрами,
## щетина) на «декалі» перед сферою голови + об'ємні деталі (ніс, брови-надбрів'я, вуха,
## волосся, борода, вуса). Рот — окрема текстура, яку NpcFace перемикає під час розмови.

const SIZE: int = 48
const NPC_FACE_SCRIPT: GDScript = preload("res://scripts/world/npc_face.gd")

static var _cache: Dictionary = {}

const DEFAULT_CONFIG: Dictionary = {
	"skin": "#c29a7e", "hair": "#4a3d32", "beard": "none", "hair_style": "short",
	"brows": "normal", "eyes": "#46586a", "scar": "none",
	"wrinkles": false, "circles": false, "soot": false,
}

const CONFIGS: Dictionary = {
	"npc_castellan": {"skin": "#c8987c", "hair": "#3e362f", "beard": "mustache", "scar": "cheek", "brows": "stern", "eyes": "#3a5f86"},
	"npc_castle_guard": {"skin": "#c09a80", "hair": "#3a342e", "beard": "mustache", "brows": "stern", "eyes": "#4a4a5a", "hair_style": "bald"},
	"npc_acolyte": {"skin": "#9c8a86", "hair": "#1d1517", "hair_style": "bald", "circles": true, "brows": "stern", "eyes": "#c04437"},
	"npc_lamplighter": {"skin": "#b98f6e", "hair": "#6a5a48", "beard": "stubble", "wrinkles": true, "eyes": "#4a3a28"},
	"npc_elder": {"skin": "#c7a58a", "hair": "#d8d4cc", "beard": "long", "hair_style": "sides", "wrinkles": true, "brows": "bushy", "eyes": "#5a6a7a"},
	"npc_priest": {"skin": "#d1ab94", "hair": "#5a4636", "hair_style": "long", "brows": "soft", "eyes": "#4d7a5a"},
	"npc_scholar": {"skin": "#c2a187", "hair": "#7a7870", "beard": "goatee", "wrinkles": true, "eyes": "#4a6a7a"},
	"npc_mage": {"skin": "#b6948a", "hair": "#2e2540", "beard": "long", "circles": true, "brows": "stern", "eyes": "#9c72d4"},
	"npc_druid": {"skin": "#a88a66", "hair": "#586a40", "beard": "long", "hair_style": "long", "brows": "bushy", "scar": "brow", "eyes": "#8eb76d"},
	"npc_blacksmith": {"skin": "#a97c62", "hair": "#2a2018", "beard": "full", "soot": true, "brows": "bushy", "scar": "chin", "eyes": "#3a2a20"},
	"npc_hunter": {"skin": "#b58d6a", "hair": "#5b4830", "beard": "stubble", "scar": "eye", "brows": "stern", "eyes": "#5a7a4a"},
	"npc_merchant": {"skin": "#c49a7a", "hair": "#5a3a24", "beard": "goatee", "brows": "normal", "eyes": "#6a5a3a", "hair_style": "short"},
	"npc_captain": {"skin": "#b8896c", "hair": "#2e2a28", "beard": "mustache", "scar": "cheek", "brows": "stern", "eyes": "#3a4a6a", "hair_style": "bald"},
	"npc_archer": {"skin": "#d6b09a", "hair": "#cfd6dc", "hair_style": "long", "brows": "soft", "eyes": "#7fd0c0"},
	"npc_marta": {"skin": "#d1ab94", "hair": "#6a4a38", "hair_style": "long", "brows": "soft", "circles": true, "eyes": "#5a6a8a"},
	"npc_farmer": {"skin": "#b98f6e", "hair": "#8a7a5a", "beard": "stubble", "wrinkles": true, "brows": "bushy", "eyes": "#5a7a5a"},
	"knight": {"skin": "#c4977a", "hair": "#3a2e26", "beard": "stubble", "scar": "eye", "brows": "stern", "eyes": "#456a8c", "hair_style": "bald"},
}


static func config_for(npc_id: String) -> Dictionary:
	var cfg: Dictionary = DEFAULT_CONFIG.duplicate()
	cfg.merge(CONFIGS.get(npc_id, {}), true)
	return cfg


# --- Піксельні примітиви ----------------------------------------------------------------

static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, xx, yy, c)


static func _line(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color, thick: int = 1) -> void:
	var steps := maxi(absi(x1 - x0), absi(y1 - y0))
	for i in range(steps + 1):
		var t := float(i) / float(maxi(steps, 1))
		var x := int(round(lerpf(float(x0), float(x1), t)))
		var y := int(round(lerpf(float(y0), float(y1), t)))
		_rect(img, x, y, thick, thick, c)


static func _eye(img: Image, cx: int, cy: int, iris: Color, blink: bool, circles: bool, lashes: bool) -> void:
	var lid := Color(0.08, 0.05, 0.05, 1.0)
	if circles:
		_rect(img, cx - 4, cy + 3, 9, 2, Color(0.22, 0.12, 0.28, 0.65))
	if blink:
		_rect(img, cx - 4, cy, 9, 1, lid)
		return
	_rect(img, cx - 4, cy - 1, 9, 4, Color(0.93, 0.92, 0.88, 1.0))
	_rect(img, cx - 3, cy - 2, 7, 1, Color(0.93, 0.92, 0.88, 1.0))
	_rect(img, cx - 1, cy - 2, 3, 5, iris)
	_px(img, cx, cy, Color(0.02, 0.02, 0.03, 1.0))
	_px(img, cx - 1, cy - 1, Color(1, 1, 1, 0.9))
	_rect(img, cx - 4, cy - 3, 9, 1, lid)
	if lashes:
		_px(img, cx - 5, cy - 2, lid)
		_px(img, cx + 5, cy - 2, lid)


static func _brow(img: Image, left: bool, style: String, hair: Color) -> void:
	var x0 := 8 if left else 29
	var thick := 3 if style == "bushy" else (1 if style == "soft" else 2)
	for i in range(11):
		var inner := (i if left else 10 - i)  # 0 = зовнішній край, 10 = біля перенісся
		var y := 11
		match style:
			"stern":
				y = 10 + int(float(inner) * 0.35)
			"soft":
				y = 11 - int(sin(float(i) / 10.0 * PI) * 1.5)
			_:
				y = 11
		_rect(img, x0 + i, y, 1, thick, hair.darkened(0.2))


static func _face_image(cfg: Dictionary, blink: bool) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var skin := Color(str(cfg["skin"]))
	var hair := Color(str(cfg["hair"]))
	var shade := skin.darkened(0.35)
	var style := str(cfg["hair_style"])
	var beard := str(cfg["beard"])
	rng_seed(cfg)

	# Чубчик / волосся по боках лиця.
	if style == "short" or style == "long":
		_rect(img, 4, 0, 40, 4, hair)
		_rect(img, 2, 0, 6, 12, hair)
		_rect(img, 40, 0, 6, 12, hair)
		for i in range(12):
			_px(img, 6 + i * 3, 4, hair)
	if style == "long":
		_rect(img, 0, 0, 5, 36, hair)
		_rect(img, 43, 0, 5, 36, hair)
	elif style == "sides":
		_rect(img, 0, 8, 4, 22, hair)
		_rect(img, 44, 8, 4, 22, hair)

	# Борода й щетина (під очима і ротом).
	match beard:
		"stubble":
			for y in range(28, 46):
				for x in range(8, 40):
					if _hash(x, y) < 0.34:
						_px(img, x, y, Color(hair, 0.55))
		"mustache":
			_rect(img, 16, 29, 16, 3, hair)
			_rect(img, 14, 31, 3, 3, hair)
			_rect(img, 31, 31, 3, 3, hair)
		"goatee":
			_rect(img, 19, 38, 10, 7, hair)
			_rect(img, 17, 30, 14, 2, hair)
		"full", "long":
			for y in range(27, 48):
				var half := 21 - maxi(0, (y - 38)) * 1
				for x in range(24 - half, 24 + half + 1):
					var tone := hair.lightened(0.1) if _hash(x, y) > 0.82 else hair
					_px(img, x, y, tone)
			_rect(img, 0, 22, 4, 14, hair)
			_rect(img, 44, 22, 4, 14, hair)
	# Верхня межа бороди: щоб щоки не були квадратними.
	if beard == "full" or beard == "long":
		for x in range(0, SIZE):
			if _hash(x, 99) < 0.4:
				_px(img, x, 27, Color(0, 0, 0, 0))

	# Очі, брови, ніс.
	var iris := Color(str(cfg["eyes"]))
	var lashes := str(cfg["brows"]) == "soft"
	_eye(img, 14, 19, iris, blink, bool(cfg["circles"]), lashes)
	_eye(img, 34, 19, iris, blink, bool(cfg["circles"]), lashes)
	_brow(img, true, str(cfg["brows"]), hair)
	_brow(img, false, str(cfg["brows"]), hair)
	_rect(img, 22, 24, 1, 6, Color(shade, 0.5))
	_px(img, 22, 30, shade)
	_px(img, 26, 30, shade)

	# Зморшки, шрами, кіптява.
	if bool(cfg["wrinkles"]):
		for y in [5, 7, 9]:
			_rect(img, 12, y, 24, 1, Color(shade, 0.4))
		_line(img, 6, 20, 9, 23, Color(shade, 0.5))
		_line(img, 42, 20, 39, 23, Color(shade, 0.5))
		_line(img, 17, 27, 14, 33, Color(shade, 0.45))
		_line(img, 31, 27, 34, 33, Color(shade, 0.45))
	var scar_color := skin.lightened(0.28).lerp(Color(0.75, 0.35, 0.35), 0.35)
	match str(cfg["scar"]):
		"cheek":
			_line(img, 6, 26, 16, 35, scar_color, 1)
			_line(img, 8, 29, 11, 27, scar_color)
		"eye":
			_line(img, 13, 8, 16, 28, scar_color, 1)
			_line(img, 11, 15, 18, 14, scar_color)
		"brow":
			_line(img, 30, 9, 40, 12, scar_color, 1)
		"chin":
			_line(img, 22, 40, 29, 46, scar_color, 1)
	if bool(cfg["soot"]):
		for i in range(60):
			var x := int(_hash(i, 3) * 40.0) + 4
			var y := int(_hash(i, 7) * 34.0) + 8
			_px(img, x, y, Color(0.05, 0.04, 0.04, 0.45))
	return img


static func _skull_image() -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var black := Color(0.02, 0.015, 0.02, 1.0)
	var bone_shade := Color(0.4, 0.36, 0.3, 0.9)
	for cx in [14, 34]:
		_rect(img, cx - 5, 14, 11, 9, black)
		_rect(img, cx - 6, 16, 13, 5, black)
	_rect(img, 22, 26, 5, 5, black)
	_rect(img, 23, 24, 3, 2, black)
	_line(img, 24, 2, 21, 12, bone_shade)
	_line(img, 21, 12, 24, 14, bone_shade)
	_line(img, 5, 6, 12, 13, bone_shade)
	_rect(img, 12, 37, 24, 6, Color(0.82, 0.78, 0.68, 1.0))
	for x in range(13, 36, 3):
		_rect(img, x, 37, 1, 6, black)
	_rect(img, 12, 40, 24, 1, black)
	return img


static func _mouth_image(cfg: Dictionary, open: bool) -> Image:
	var img := Image.create(16, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var skin := Color(str(cfg["skin"]))
	var lip := skin.darkened(0.45).lerp(Color(0.5, 0.15, 0.15), 0.4)
	if open:
		_rect(img, 3, 1, 10, 5, Color(0.1, 0.03, 0.04, 1.0))
		_rect(img, 4, 1, 8, 2, Color(0.9, 0.88, 0.8, 1.0))
		_rect(img, 5, 5, 6, 1, Color(0.62, 0.2, 0.22, 1.0))
		_rect(img, 2, 3, 1, 2, lip)
		_rect(img, 13, 3, 1, 2, lip)
	else:
		_rect(img, 3, 3, 10, 2, lip)
		_rect(img, 5, 5, 6, 1, Color(lip, 0.5))
	return img


static func rng_seed(_cfg: Dictionary) -> void:
	pass


static func _hash(x: int, y: int) -> float:
	return fposmod(sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453, 1.0)


static func _texture(key: String, image: Image) -> ImageTexture:
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(image)
	return _cache[key]


static func _decal_material(tex: Texture2D) -> ShaderMaterial:
	var mat := PSXMaterials.make(Color.WHITE, 0.0, 1.0, Color.BLACK, 0.0, "none", false, true)
	mat.set_shader_parameter("use_albedo_texture", true)
	mat.set_shader_parameter("albedo_texture", tex)
	return mat


static func _solid(color_hex: String, lighten: float = 0.0) -> ShaderMaterial:
	var color := Color(color_hex)
	color = color.lightened(lighten) if lighten > 0.0 else color.darkened(-lighten)
	return PSXMaterials.make(color, 0.0, 1.0, Color.BLACK, 0.0, "cloth", false)


static func _mesh_node(parent: Node3D, node_name: String, mesh: Mesh, pos: Vector3, material: Material, mesh_scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = pos
	mi.scale = mesh_scale
	mi.material_override = material
	parent.add_child(mi)
	return mi


static func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	return mesh


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


# --- Збирання голови ----------------------------------------------------------------------

static func _build_head_details(rig: Node3D, cfg: Dictionary, with_volume: bool) -> void:
	var skin_hex := str(cfg["skin"])
	var hair_hex := str(cfg["hair"])
	var cfg_key := "%s|%s|%s|%s|%s|%s|%s|%s|%s" % [skin_hex, hair_hex, cfg["beard"], cfg["scar"], cfg["brows"], cfg["eyes"], cfg["wrinkles"], cfg["circles"], cfg["soot"]]
	var open_tex := _texture("face_open|" + cfg_key + "|" + str(cfg["hair_style"]), _face_image(cfg, false))
	var blink_tex := _texture("face_blink|" + cfg_key + "|" + str(cfg["hair_style"]), _face_image(cfg, true))
	var mouth_closed := _texture("mouth_c|" + skin_hex, _mouth_image(cfg, false))
	var mouth_open := _texture("mouth_o|" + skin_hex, _mouth_image(cfg, true))

	var face_mat := _decal_material(open_tex)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.31, 0.31)
	var face := _mesh_node(rig, "FaceDecal", quad, Vector3(0.0, -0.005, -0.212), face_mat)
	face.rotation.y = PI
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mouth_mat := _decal_material(mouth_closed)
	var mouth_quad := QuadMesh.new()
	mouth_quad.size = Vector2(0.11, 0.055)
	var mouth := _mesh_node(rig, "Mouth", mouth_quad, Vector3(0.0, -0.11, -0.2125), mouth_mat)
	mouth.rotation.y = PI
	mouth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	if with_volume:
		var skin_mat := _solid(skin_hex)
		var dark_skin := _solid(skin_hex, -0.12)
		_mesh_node(rig, "BrowRidge", _box(Vector3(0.27, 0.03, 0.05)), Vector3(0.0, 0.07, -0.19), dark_skin)
		_mesh_node(rig, "Nose", _sphere(0.04), Vector3(0.0, -0.03, -0.222), skin_mat, Vector3(0.85, 1.3, 1.5))
		for side in [-1.0, 1.0]:
			_mesh_node(rig, "Ear", _sphere(0.045), Vector3(side * 0.215, -0.005, 0.0), skin_mat, Vector3(0.45, 1.0, 0.8))
		var hair_mat := _solid(hair_hex)
		match str(cfg["hair_style"]):
			"short":
				_mesh_node(rig, "Hair", _sphere(0.235), Vector3(0.0, 0.075, 0.03), hair_mat, Vector3(1.0, 0.62, 1.02))
			"long":
				_mesh_node(rig, "Hair", _sphere(0.235), Vector3(0.0, 0.075, 0.03), hair_mat, Vector3(1.0, 0.62, 1.02))
				_mesh_node(rig, "HairBack", _box(Vector3(0.42, 0.42, 0.07)), Vector3(0.0, -0.1, 0.19), hair_mat)
				for side in [-1.0, 1.0]:
					_mesh_node(rig, "HairSide", _box(Vector3(0.05, 0.36, 0.2)), Vector3(side * 0.205, -0.08, 0.06), hair_mat)
			"sides":
				for side in [-1.0, 1.0]:
					_mesh_node(rig, "HairSide", _box(Vector3(0.05, 0.14, 0.2)), Vector3(side * 0.205, -0.0, 0.05), hair_mat)
				_mesh_node(rig, "HairBack", _box(Vector3(0.34, 0.12, 0.05)), Vector3(0.0, 0.0, 0.2), hair_mat)
		match str(cfg["beard"]):
			"mustache":
				_mesh_node(rig, "Mustache", _box(Vector3(0.15, 0.035, 0.045)), Vector3(0.0, -0.07, -0.225), hair_mat)
			"goatee":
				_mesh_node(rig, "Goatee", _sphere(0.06), Vector3(0.0, -0.175, -0.165), hair_mat, Vector3(0.9, 1.2, 0.8))
			"full":
				_mesh_node(rig, "Beard", _sphere(0.17), Vector3(0.0, -0.13, -0.09), hair_mat, Vector3(1.0, 0.8, 0.65))
			"long":
				_mesh_node(rig, "Beard", _sphere(0.17), Vector3(0.0, -0.13, -0.09), hair_mat, Vector3(1.0, 0.8, 0.65))
				var cone := CylinderMesh.new()
				cone.top_radius = 0.13
				cone.bottom_radius = 0.015
				cone.height = 0.36
				cone.radial_segments = 7
				_mesh_node(rig, "BeardLong", cone, Vector3(0.0, -0.31, -0.1), hair_mat)

	rig.call("setup", face_mat, mouth_mat, open_tex, blink_tex, mouth_closed, mouth_open)


static func attach_npc(npc: Node3D, npc_id: String, head_position: Vector3) -> void:
	## Створює FaceRig: переносить частини голови (голова, каптур, капелюх, шолом) у риг,
	## додає обличчя й об'ємні деталі та підключає анімацію розмови.
	var cfg := config_for(npc_id)
	var rig := Node3D.new()
	rig.name = "FaceRig"
	rig.set_script(NPC_FACE_SCRIPT)
	rig.position = head_position
	npc.add_child(rig)
	for piece_name in ["Head", "Hood", "Hat", "Helmet"]:
		var piece := npc.get_node_or_null(piece_name) as Node3D
		if piece:
			piece.reparent(rig, true)
			if piece_name == "Hood":
				# Каптур відсунуто назад і вгору: лице лишається відкритим.
				piece.position += Vector3(0.0, 0.04, 0.07)
	_build_head_details(rig, cfg, true)


static func attach_wraith(wraith: Node3D, skull_position: Vector3) -> void:
	## Череп попелястого вартового: порожні очниці, дірка носа, потріскана кістка, зуби.
	var tex := _texture("skull", _skull_image())
	var quad := QuadMesh.new()
	quad.size = Vector2(0.31, 0.31)
	var decal := MeshInstance3D.new()
	decal.name = "SkullDecal"
	decal.mesh = quad
	decal.material_override = _decal_material(tex)
	decal.position = skull_position + Vector3(0.0, 0.01, -0.205)
	decal.rotation.y = PI
	decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wraith.add_child(decal)
	var brow := MeshInstance3D.new()
	brow.name = "SkullBrow"
	brow.mesh = _box(Vector3(0.28, 0.035, 0.05))
	brow.material_override = _solid("#8a8170")
	brow.position = skull_position + Vector3(0.0, 0.085, -0.18)
	wraith.add_child(brow)
