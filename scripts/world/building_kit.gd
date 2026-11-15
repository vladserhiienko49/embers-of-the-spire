class_name BuildingKit
extends RefCounted
## Процедурні споруди Embers of the Spire у стилі PS1 dark fantasy.
## Кожна будівля — один меш (по поверхні на матеріал) + прості колізії + вогні.
## Локальна система: центр на землі, фасад/двері дивляться на -Z.

const VISIBILITY_END: float = 520.0

const MAT_DEFS: Dictionary = {
	"stone": ["#4a4946", 0.0, 0.92, "", 0.0, "stone"],
	"stone_dark": ["#2e2d31", 0.0, 0.92, "", 0.0, "brick"],
	"brick": ["#4b4643", 0.0, 0.9, "", 0.0, "brick"],
	"moss_stone": ["#3d4539", 0.0, 0.95, "", 0.0, "stone"],
	"wood": ["#2e2016", 0.0, 0.85, "", 0.0, "planks"],
	"wood_light": ["#5a402b", 0.0, 0.85, "", 0.0, "planks"],
	"thatch": ["#53412a", 0.0, 0.95, "", 0.0, "thatch"],
	"shingle": ["#2b2428", 0.0, 0.9, "", 0.0, "shingles"],
	"shingle_blue": ["#2b3442", 0.0, 0.9, "", 0.0, "shingles"],
	"iron": ["#3a3c41", 0.8, 0.4, "", 0.0, "metal"],
	"window": ["#ffb050", 0.0, 0.3, "#ff8a2a", 3.8, "none"],
	"window_blue": ["#a8d8ff", 0.0, 0.3, "#5fb4ff", 3.4, "none"],
	"window_green": ["#9cffb0", 0.0, 0.3, "#3fdc7a", 2.6, "none"],
	"ember": ["#ff7030", 0.0, 0.3, "#ff4a10", 5.0, "none"],
	"cloth_black": ["#1a181d", 0.0, 0.95, "", 0.0, "cloth"],
	"cloth_red": ["#5e1c1e", 0.0, 0.95, "", 0.0, "cloth"],
	"cloth_tent": ["#5e4630", 0.0, 0.95, "", 0.0, "cloth"],
	"bone": ["#b3aa95", 0.0, 0.9, "", 0.0, "stone"],
	"rock": ["#3a383d", 0.0, 0.95, "", 0.0, "rock"],
	"bark": ["#3b2818", 0.0, 0.92, "", 0.0, "bark"],
	"cave_dark": ["#050506", 0.0, 1.0, "", 0.0, "none"],
	"water": ["#1d3a44", 0.45, 0.15, "#0a2a30", 0.35, "none"],
}

static var _cache: Dictionary = {}


static func mat(key: String) -> Material:
	if _cache.has(key):
		return _cache[key]
	var d: Array = MAT_DEFS.get(key, MAT_DEFS["stone"])
	var emission := Color(str(d[3])) if str(d[3]) != "" else Color.BLACK
	var material := PSXMaterials.make(Color(str(d[0])), float(d[1]), float(d[2]), emission, float(d[4]), str(d[5]))
	_cache[key] = material
	return material


static func _wall_mat(color: Color) -> Material:
	var key := "wall_" + color.to_html(false)
	if not _cache.has(key):
		_cache[key] = PSXMaterials.make(color, 0.0, 0.92, Color.BLACK, 0.0, "plaster")
	return _cache[key]


static func _finish(kit: MeshKit, root: Node3D, node_name: String, wall_color: Color, visibility_end: float = VISIBILITY_END) -> MeshInstance3D:
	for key in kit._tools.keys():
		if not kit.has_material(key):
			kit.set_material(key, _wall_mat(wall_color) if key == "wall" else mat(key))
	return kit.build(root, node_name, visibility_end)


static func _facade_fill(root: Node3D, instance: MeshInstance3D) -> void:
	## М'яке тепле світло перед фасадом (-Z): будівлю видно вночі, але без «прожектора».
	if instance == null or instance.mesh == null:
		return
	var box := instance.mesh.get_aabb()
	var fill := OmniLight3D.new()
	fill.name = "FacadeFill"
	fill.light_color = Color("#ffb784")
	fill.light_energy = 1.1
	fill.omni_range = clampf(maxf(box.size.x, box.size.y) * 0.95, 10.0, 34.0)
	fill.omni_attenuation = 1.2
	fill.light_volumetric_fog_energy = 0.4
	fill.light_specular = 0.2
	fill.distance_fade_enabled = true
	fill.distance_fade_begin = 140.0
	fill.distance_fade_length = 40.0
	fill.position = Vector3(box.get_center().x, clampf(box.size.y * 0.35, 2.0, 9.0), box.position.z - clampf(box.size.z * 0.3, 3.0, 8.0))
	root.add_child(fill)
	# Слабке холодне контрове світло ззаду-зверху відділяє силует від неба.
	var rim := OmniLight3D.new()
	rim.name = "RimFill"
	rim.light_color = Color("#7f93d6")
	rim.light_energy = 0.5
	rim.omni_range = fill.omni_range
	rim.light_volumetric_fog_energy = 0.0
	rim.light_specular = 0.0
	rim.distance_fade_enabled = true
	rim.distance_fade_begin = 120.0
	rim.distance_fade_length = 40.0
	rim.position = Vector3(box.get_center().x, box.size.y * 0.8, box.end.z + 3.0)
	root.add_child(rim)


static func _light(root: Node3D, kit: MeshKit, local_pos: Vector3, color: Color, energy: float, light_range: float, flicker: float = 0.2, speed: float = 6.0, shadows: bool = false, crackle: bool = false) -> FlickerLight:
	var light := FlickerLight.create(color, energy, light_range, flicker, speed)
	light.crackle = crackle
	light.position = kit.origin * local_pos
	light.shadow_enabled = shadows
	root.add_child(light)
	return light


static func _smoke(root: Node3D, kit: MeshKit, local_pos: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.name = "ChimneySmoke"
	particles.position = kit.origin * local_pos
	particles.amount = 12
	particles.lifetime = 7.0
	particles.preprocess = 7.0
	particles.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 16, 12))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.15, 1.0, 0.0)
	process.spread = 12.0
	process.initial_velocity_min = 0.5
	process.initial_velocity_max = 0.9
	process.gravity = Vector3(0.18, 0.12, 0.0)
	process.scale_min = 0.8
	process.scale_max = 1.3
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.4))
	scale_curve.add_point(Vector2(1.0, 2.6))
	var scale_texture := CurveTexture.new()
	scale_texture.curve = scale_curve
	process.scale_curve = scale_texture
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.3, 0.29, 0.33, 0.0))
	gradient.set_color(1, Color(0.3, 0.29, 0.33, 0.0))
	gradient.add_point(0.15, Color(0.16, 0.155, 0.18, 0.32))
	gradient.add_point(0.7, Color(0.14, 0.135, 0.16, 0.14))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(1.1, 1.1)
	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_mat.vertex_color_use_as_albedo = true
	smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smoke_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	smoke_mat.albedo_texture = PSXTextures.get_texture("grime")
	quad.material = smoke_mat
	particles.draw_pass_1 = quad
	root.add_child(particles)


static func build(kind: String, building_name: String, width: float, depth: float, wall_color: Color, seed_value: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Building"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var kit := MeshKit.new()
	match kind:
		"hut":
			var hut_w := clampf(width, 8.0, 11.0)
			var hut_d := clampf(depth, 7.0, 9.0)
			_hut(kit, root, hut_w, hut_d, rng, "shingle" if building_name.contains("відлюдника") or building_name.contains("відьми") else "thatch")
			_hut_yard(kit, root, hut_w, hut_d, rng, building_name)
		"village":
			_village(kit, root, rng)
		"hamlet":
			_hamlet(kit, root, rng, building_name)
		"farmstead":
			_farmstead(kit, root, rng)
		"tower":
			if building_name.contains("Крижана"):
				_gothic_tower(kit, root, width, rng, "ice")
			elif building_name.contains("Обсерваторія"):
				_gothic_tower(kit, root, width, rng, "ruined")
			elif building_name.contains("сторожова"):
				_gothic_tower(kit, root, width, rng, "watch")
			else:
				_gothic_tower(kit, root, width, rng, "gothic")
		"church":
			_church(kit, root, width, depth, rng, building_name.contains("Затонула"))
		"crypt":
			_cemetery(kit, root, rng)
		"forge":
			_forge(kit, root, rng)
		"gate":
			_giant_gate(kit, root, rng)
		"castle":
			_castle(kit, root, rng, 1.0)
		"ruins":
			_ruins(kit, root, rng)
		"camp":
			_camp(kit, root, rng)
		"obelisk":
			_stone_circle(kit, root, rng)
		"lair":
			_lair(kit, root, rng)
		_:
			_hut(kit, root, clampf(width, 8.0, 11.0), clampf(depth, 7.0, 9.0), rng, "shingle")
	_facade_fill(root, _finish(kit, root, "BuildingMesh", wall_color))
	return root


static func build_fortress(wall_color: Color, seed_value: int, scale: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Fortress"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var kit := MeshKit.new()
	_castle(kit, root, rng, scale)
	_facade_fill(root, _finish(kit, root, "FortressMesh", wall_color, 0.0))
	return root


# --- Дрібні деталі ---------------------------------------------------------------

static func _face(yaw: float, pos: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), pos)


static func _window(kit: MeshKit, xf: Transform3D, w: float, h: float, pane: String = "window", shutters: bool = true) -> void:
	## Вікно на стіні; локальна -Z дивиться назовні.
	kit.box(pane, xf * Transform3D(Basis(), Vector3(0, 0, -0.02)), Vector3(w, h, 0.08))
	kit.box("wood", xf * Transform3D(Basis(), Vector3(0, h * 0.5 + 0.06, -0.06)), Vector3(w + 0.24, 0.12, 0.14))
	kit.box("wood", xf * Transform3D(Basis(), Vector3(-w * 0.5 - 0.06, 0, -0.06)), Vector3(0.12, h, 0.14))
	kit.box("wood", xf * Transform3D(Basis(), Vector3(w * 0.5 + 0.06, 0, -0.06)), Vector3(0.12, h, 0.14))
	kit.box("wood", xf * Transform3D(Basis(), Vector3(0, 0, -0.07)), Vector3(0.07, h, 0.08))
	kit.box("wood", xf * Transform3D(Basis(), Vector3(0, h * 0.1, -0.07)), Vector3(w, 0.07, 0.08))
	kit.box("stone", xf * Transform3D(Basis(), Vector3(0, -h * 0.5 - 0.08, -0.12)), Vector3(w + 0.4, 0.14, 0.3))
	if shutters:
		for side: float in [-1.0, 1.0]:
			kit.box("wood_light", xf * Transform3D(Basis(Vector3.UP, side * 0.25), Vector3(side * (w * 0.5 + w * 0.3), 0, -0.12)), Vector3(w * 0.5, h * 1.02, 0.06))


static func _lancet(kit: MeshKit, xf: Transform3D, w: float, h: float, pane: String = "window") -> void:
	## Готичне стрілчасте вікно з кам'яним обрамленням.
	kit.box(pane, xf * Transform3D(Basis(), Vector3(0, 0, -0.03)), Vector3(w, h, 0.08))
	kit.pyramid(pane, xf * Transform3D(Basis(), Vector3(0, h * 0.5, -0.03)), w, 0.08, w * 0.8)
	kit.box("stone", xf * Transform3D(Basis(), Vector3(-w * 0.5 - 0.1, 0, -0.08)), Vector3(0.2, h, 0.18))
	kit.box("stone", xf * Transform3D(Basis(), Vector3(w * 0.5 + 0.1, 0, -0.08)), Vector3(0.2, h, 0.18))
	kit.box("stone", xf * Transform3D(Basis(), Vector3(0, -h * 0.5 - 0.1, -0.1)), Vector3(w + 0.5, 0.2, 0.26))
	kit.pyramid("stone", xf * Transform3D(Basis(), Vector3(0, h * 0.5 + 0.02, -0.09)), w + 0.4, 0.16, w * 0.95)


static func _door(kit: MeshKit, xf: Transform3D, w: float, h: float, pointed: bool = false) -> void:
	kit.box("wood", xf * Transform3D(Basis(), Vector3(0, h * 0.5, -0.04)), Vector3(w, h, 0.12))
	for y: float in [h * 0.25, h * 0.72]:
		kit.box("iron", xf * Transform3D(Basis(), Vector3(0, y, -0.12)), Vector3(w * 0.92, 0.1, 0.05))
	kit.box("wood_light", xf * Transform3D(Basis(), Vector3(-w * 0.5 - 0.1, h * 0.5, -0.1)), Vector3(0.2, h + 0.1, 0.22))
	kit.box("wood_light", xf * Transform3D(Basis(), Vector3(w * 0.5 + 0.1, h * 0.5, -0.1)), Vector3(0.2, h + 0.1, 0.22))
	if pointed:
		kit.pyramid("stone", xf * Transform3D(Basis(), Vector3(0, h, -0.1)), w + 0.6, 0.3, w * 0.75)
	else:
		kit.box("wood_light", xf * Transform3D(Basis(), Vector3(0, h + 0.12, -0.1)), Vector3(w + 0.5, 0.24, 0.26))


static func _barrel(kit: MeshKit, pos: Vector3) -> void:
	kit.cylinder_at("wood_light", pos, 0.38, 0.38, 0.95, 8, true)
	kit.cylinder_at("iron", pos + Vector3(0, 0.18, 0), 0.4, 0.4, 0.08, 8)
	kit.cylinder_at("iron", pos + Vector3(0, 0.7, 0), 0.4, 0.4, 0.08, 8)


static func _crate(kit: MeshKit, pos: Vector3, size: float, yaw: float) -> void:
	kit.box_at("wood_light", pos + Vector3(0, size * 0.5, 0), Vector3.ONE * size, true, Vector3(0, yaw, 0))
	kit.box_at("wood", pos + Vector3(0, size * 0.5, 0), Vector3(size * 1.02, size * 0.16, size * 1.02), false, Vector3(0, yaw, 0))


static func _crenels(kit: MeshKit, key: String, y: float, half_w: float, half_d: float, block: float = 0.6) -> void:
	var step := block * 2.0
	for side: float in [-1.0, 1.0]:
		var x := -half_w
		while x <= half_w + 0.01:
			kit.box_at(key, Vector3(x, y + block * 0.6, side * half_d), Vector3(block, block * 1.2, block))
			x += step
		var z := -half_d + step
		while z <= half_d - step + 0.01:
			kit.box_at(key, Vector3(side * half_w, y + block * 0.6, z), Vector3(block, block * 1.2, block))
			z += step


static func _ring_crenels(kit: MeshKit, key: String, center: Vector3, radius: float, count: int, block: float) -> void:
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		kit.box_at(key, center + Vector3(cos(angle) * radius, block * 0.6, sin(angle) * radius), Vector3(block, block * 1.2, block), false, Vector3(0, -angle, 0))


static func _arch(kit: MeshKit, key: String, center: Vector3, radius: float, thickness: float, depth: float, segments: int, skip: Array = []) -> void:
	## Кам'яна арка з клинчастих блоків у площині XY.
	for i in range(segments):
		if i in skip:
			continue
		var a := PI * (float(i) + 0.5) / float(segments)
		var r := radius + thickness * 0.5
		var length := PI * r / float(segments) * 1.08
		var size := Vector3(length, thickness, depth)
		if i == segments / 2:
			size = Vector3(length * 1.25, thickness * 1.3, depth * 1.1)
		kit.box(key, Transform3D(Basis(Vector3.BACK, a + PI * 0.5), center + Vector3(cos(a) * r, sin(a) * r, 0)), size, true)


# --- Хатина -------------------------------------------------------------------------

static func _hut(kit: MeshKit, root: Node3D, w: float, d: float, rng: RandomNumberGenerator, roof: String = "thatch", lights: bool = true) -> void:
	var plinth := 0.6
	var wall_h := 3.2
	var top := plinth + wall_h
	# Кам'яний цоколь заглиблений у землю на 1.6 м: хата завжди спирається на рельєф, навіть на схилі.
	kit.box_at("stone", Vector3(0, (plinth - 1.6) * 0.5, 0), Vector3(w + 0.6, plinth + 1.6, d + 0.6), true)
	for fx: float in [-1.0, 1.0]:
		for fz: float in [-1.0, 1.0]:
			kit.box_at("stone_dark", Vector3(fx * (w * 0.5 + 0.1), -0.5, fz * (d * 0.5 + 0.1)), Vector3(0.9, 2.6, 0.9))
	kit.box_at("wall", Vector3(0, plinth + wall_h * 0.5, 0), Vector3(w, wall_h, d), true)
	# Фахверк: кутові стовпи, пояси та розкоси.
	for cx: float in [-w * 0.5, w * 0.5]:
		for cz: float in [-d * 0.5, d * 0.5]:
			kit.box_at("wood", Vector3(cx, plinth + wall_h * 0.5, cz), Vector3(0.34, wall_h, 0.34))
	for y: float in [plinth + wall_h * 0.5, top - 0.12]:
		kit.box_at("wood", Vector3(0, y, -d * 0.5 - 0.05), Vector3(w, 0.22, 0.16))
		kit.box_at("wood", Vector3(0, y, d * 0.5 + 0.05), Vector3(w, 0.22, 0.16))
		kit.box_at("wood", Vector3(-w * 0.5 - 0.05, y, 0), Vector3(0.16, 0.22, d))
		kit.box_at("wood", Vector3(w * 0.5 + 0.05, y, 0), Vector3(0.16, 0.22, d))
	for side: float in [-1.0, 1.0]:
		for k: float in [-1.0, 1.0]:
			kit.box_at("wood", Vector3(side * (w * 0.5 + 0.06), plinth + wall_h * 0.25, k * d * 0.27), Vector3(0.14, wall_h * 0.62, 0.16), false, Vector3(k * 0.62, 0, 0))
			kit.box_at("wood", Vector3(k * w * 0.36, plinth + wall_h * 0.75, d * 0.5 + 0.07), Vector3(0.16, wall_h * 0.6, 0.14), false, Vector3(0, 0, k * 0.6))

	# Двері, сходинки, вікна з віконницями.
	_door(kit, _face(0.0, Vector3(0, plinth, -d * 0.5 - 0.02)), 1.3, 2.2)
	kit.box_at("stone", Vector3(0, plinth * 0.67 * 0.5, -d * 0.5 - 0.6), Vector3(1.9, plinth * 0.67, 0.6), true)
	kit.box_at("stone", Vector3(0, plinth * 0.33 * 0.5, -d * 0.5 - 1.15), Vector3(2.1, plinth * 0.33, 0.55), true)
	for wx: float in [-w * 0.3, w * 0.3]:
		_window(kit, _face(0.0, Vector3(wx, plinth + wall_h * 0.55, -d * 0.5 - 0.02)), 0.9, 1.0)
	_window(kit, _face(PI * 0.5, Vector3(-w * 0.5 - 0.02, plinth + wall_h * 0.55, 0)), 0.8, 0.9)
	_window(kit, _face(-PI * 0.5, Vector3(w * 0.5 + 0.02, plinth + wall_h * 0.55, 0)), 0.8, 0.9, "window", false)

	# Крутий дах із виносом, гребенем і фронтонами.
	var roof_h := d * 0.62
	kit.gable_roof(roof, "wall", Transform3D(Basis(), Vector3(0, top, 0)), w, d, roof_h, 0.7, 0.24)
	# Димар.
	var chimney_h := roof_h + 1.6
	kit.box_at("stone", Vector3(w * 0.28, top + chimney_h * 0.5 - 0.3, d * 0.18), Vector3(0.95, chimney_h, 0.95))
	kit.box_at("stone_dark", Vector3(w * 0.28, top + chimney_h - 0.22, d * 0.18), Vector3(1.15, 0.18, 1.15))
	_smoke(root, kit, Vector3(w * 0.28, top + chimney_h, d * 0.18))

	# Ліхтар біля дверей, бочки, ящики.
	var lamp := Vector3(1.05, plinth + 2.45, -d * 0.5 - 0.35)
	kit.box_at("iron", lamp + Vector3(0, 0.32, 0.2), Vector3(0.06, 0.06, 0.45))
	kit.box_at("window", lamp, Vector3(0.24, 0.32, 0.24))
	kit.pyramid("iron", Transform3D(Basis(), lamp + Vector3(0, 0.16, 0)), 0.34, 0.34, 0.2)
	_barrel(kit, Vector3(-w * 0.5 - 0.3, 0, -d * 0.5 - 0.6))
	if rng.randf() > 0.4:
		_barrel(kit, Vector3(-w * 0.5 + 0.55, 0, -d * 0.5 - 0.95))
	_crate(kit, Vector3(w * 0.5 + 0.7, 0, d * 0.2), 0.8, rng.randf() * 0.5)
	if lights:
		_light(root, kit, lamp + Vector3(0, -0.2, -0.3), Color("#ffa04a"), 1.3, 8.0, 0.18, 5.0)
		_light(root, kit, Vector3(0, plinth + 1.8, -d * 0.5 - 1.8), Color("#ff9440"), 0.9, 7.0, 0.1, 2.0)


static func _village(kit: MeshKit, root: Node3D, rng: RandomNumberGenerator) -> void:
	var layout := [
		[Vector3(-8.5, 0, 1.5), 0.22, 7.5, 6.5, "thatch"],
		[Vector3(8.0, 0, 2.5), -0.28, 7.0, 6.0, "shingle"],
		[Vector3(0.0, 0, 10.0), 0.0, 8.0, 6.5, "thatch"],
	]
	for i in range(layout.size()):
		var item: Array = layout[i]
		kit.origin = Transform3D(Basis(Vector3.UP, float(item[1])), item[0])
		_hut(kit, root, float(item[2]), float(item[3]), rng, str(item[4]), i != 2)
	kit.origin = Transform3D.IDENTITY
	# Криниця.
	var well := Vector3(0, 0, -3.5)
	kit.cylinder_at("stone", well, 1.15, 1.1, 0.95, 8, true)
	kit.cylinder_at("cave_dark", well + Vector3(0, 0.96, 0), 0.85, 0.85, 0.02, 8)
	for side: float in [-1.0, 1.0]:
		kit.box_at("wood", well + Vector3(side * 1.05, 1.5, 0), Vector3(0.18, 2.2, 0.18))
	kit.gable_roof("shingle", "wood", Transform3D(Basis(), well + Vector3(0, 2.55, 0)), 2.6, 1.6, 0.8, 0.2, 0.12)
	kit.cylinder_at("wood_light", well + Vector3(-0.9, 2.0, 0), 0.12, 0.12, 1.8, 6, false, Vector3(0, 0, -PI * 0.5))
	# Частокіл позаду села.
	var x := -14.0
	while x <= 14.0:
		var h := rng.randf_range(1.5, 1.9)
		kit.box_at("wood", Vector3(x, h * 0.5, 15.5), Vector3(0.22, h, 0.22), false, Vector3(0, 0, rng.randf_range(-0.06, 0.06)))
		x += 0.45
	kit.box_at("wood", Vector3(0, 0.6, 15.35), Vector3(28.5, 0.14, 0.1), true)
	kit.box_at("wood", Vector3(0, 1.2, 15.35), Vector3(28.5, 0.14, 0.1))
	_crate(kit, Vector3(3.5, 0, -2.5), 0.75, 0.3)
	_crate(kit, Vector3(4.1, 0, -1.6), 0.6, 0.9)
	_barrel(kit, Vector3(-3.6, 0, -2.2))
	# Життя села: господарські дрібниці, лампи, огорожі, візок і сіно.
	_cart(kit, Vector3(-15.5, 0, 6.0), 0.5)
	_haystack(kit, Vector3(15.0, 0, 11.0), 0.9)
	_woodpile(kit, Vector3(-4.2, 0, 15.2), 0.0)
	_drying_rack(kit, Vector3(2.0, 0, 6.2), 0.0, "cloth_red")
	_lamp_post(root, kit, Vector3(-4.8, 0, -5.5))
	_fence(kit, Vector3(-13.0, 0, -1.5), Vector3(-6.0, 0, -4.5), rng)
	_fence(kit, Vector3(6.0, 0, -4.5), Vector3(13.0, 0, -1.0), rng)
	_garden(kit, Vector3(-3.0, 0, 5.2), 0.0, 2, 3.2)
	_light(root, kit, well + Vector3(0, 2.3, 0), Color("#ffa04a"), 1.2, 10.0, 0.15, 4.0)


# --- Двори хатин, хутори та селища ----------------------------------------------------

static func _fence(kit: MeshKit, a: Vector3, b: Vector3, rng: RandomNumberGenerator) -> void:
	var dir := b - a
	var length := dir.length()
	if length < 0.5:
		return
	var yaw := atan2(-dir.z, dir.x)
	var count := maxi(int(length / 1.7), 1)
	for i in range(count + 1):
		var p := a + dir * (float(i) / float(count))
		var h := rng.randf_range(1.05, 1.4)
		kit.box_at("wood", p + Vector3(0, h * 0.5, 0), Vector3(0.14, h, 0.14), false, Vector3(0, 0, rng.randf_range(-0.05, 0.05)))
	for y: float in [0.45, 0.95]:
		kit.box_at("wood_light", a + dir * 0.5 + Vector3(0, y, 0), Vector3(length, 0.09, 0.07), false, Vector3(0, yaw, 0))


static func _woodpile(kit: MeshKit, pos: Vector3, yaw: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	for row in range(3):
		for i in range(4 - row):
			var off := Vector3((float(i) - float(3 - row) * 0.5) * 0.3, 0.14 + float(row) * 0.25, 0.0)
			kit.cylinder_at("wood_light", pos + basis * off, 0.13, 0.13, 1.0, 6, false, Vector3(0, yaw, PI * 0.5))
	kit.box_at("wood", pos + Vector3(0, 0.05, 0), Vector3(1.0, 0.1, 0.9), false, Vector3(0, yaw, 0))


static func _stump_axe(kit: MeshKit, pos: Vector3) -> void:
	kit.cylinder_at("bark", pos + Vector3(0, 0.25, 0), 0.32, 0.38, 0.5, 7, true)
	kit.box_at("wood_light", pos + Vector3(0.05, 0.78, 0), Vector3(0.07, 0.6, 0.07), false, Vector3(0, 0, 0.5))
	kit.box_at("iron", pos + Vector3(0.2, 0.96, 0), Vector3(0.22, 0.18, 0.05), false, Vector3(0, 0, 0.5))


static func _drying_rack(kit: MeshKit, pos: Vector3, yaw: float, cloth_key: String = "cloth_tent") -> void:
	var basis := Basis(Vector3.UP, yaw)
	for side: float in [-1.0, 1.0]:
		kit.box_at("wood", pos + basis * Vector3(side * 1.1, 1.0, 0), Vector3(0.1, 2.0, 0.1))
	kit.box_at("wood", pos + Vector3(0, 1.95, 0), Vector3(2.3, 0.08, 0.08), false, Vector3(0, yaw, 0))
	for k: float in [-0.6, 0.0, 0.6]:
		kit.box_at(cloth_key, pos + basis * Vector3(k, 1.45, 0.02), Vector3(0.45, 0.95, 0.04), false, Vector3(0, yaw, 0))


static func _haystack(kit: MeshKit, pos: Vector3, scale_value: float) -> void:
	kit.cylinder_at("thatch", pos + Vector3(0, 0.7 * scale_value, 0), 1.05 * scale_value, 1.15 * scale_value, 1.4 * scale_value, 8, true)
	kit.pyramid("thatch", Transform3D(Basis(), pos + Vector3(0, 1.4 * scale_value, 0)), 2.1 * scale_value, 2.1 * scale_value, 1.1 * scale_value)


static func _scarecrow(kit: MeshKit, pos: Vector3, yaw: float) -> void:
	kit.box_at("wood", pos + Vector3(0, 1.1, 0), Vector3(0.09, 2.2, 0.09))
	kit.box_at("wood", pos + Vector3(0, 1.6, 0), Vector3(1.4, 0.08, 0.08), false, Vector3(0, yaw, 0))
	kit.box_at("cloth_tent", pos + Vector3(0, 1.3, 0), Vector3(0.4, 0.7, 0.2), false, Vector3(0, yaw, 0))
	kit.box_at("bone", pos + Vector3(0, 2.0, 0), Vector3(0.3, 0.3, 0.3), false, Vector3(0, yaw, 0))
	kit.pyramid("cloth_black", Transform3D(Basis(Vector3.UP, yaw), pos + Vector3(0, 2.15, 0)), 0.6, 0.6, 0.35)


static func _cart(kit: MeshKit, pos: Vector3, yaw: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	kit.box_at("wood_light", pos + basis * Vector3(0, 0.7, 0), Vector3(2.2, 0.18, 1.3), true, Vector3(0, yaw, 0))
	for side: float in [-1.0, 1.0]:
		kit.box_at("wood", pos + basis * Vector3(0, 1.0, side * 0.65), Vector3(2.2, 0.5, 0.08), false, Vector3(0, yaw, 0))
		kit.cylinder_at("wood", pos + basis * Vector3(0.2, 0.5, side * 0.75), 0.5, 0.5, 0.1, 8, false, Vector3(PI * 0.5, yaw, 0))
	kit.box_at("wood", pos + basis * Vector3(-1.9, 0.75, 0), Vector3(1.6, 0.08, 0.1), false, Vector3(0, yaw, 0.15))
	kit.box_at("cloth_tent", pos + basis * Vector3(0, 1.2, 0), Vector3(1.4, 0.6, 0.9), false, Vector3(0, yaw, 0))


static func _garden(kit: MeshKit, pos: Vector3, yaw: float, rows: int, row_length: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	for i in range(rows):
		var p := pos + basis * Vector3(0, 0, float(i) * 0.85)
		kit.box_at("bark", p + Vector3(0, 0.11, 0), Vector3(row_length, 0.22, 0.45), false, Vector3(0, yaw, 0))
		var n := int(row_length / 0.7)
		for k in range(n):
			var q := p + basis * Vector3((float(k) - float(n - 1) * 0.5) * 0.7, 0.3, 0)
			kit.pyramid("moss_stone", Transform3D(Basis(Vector3.UP, yaw), q), 0.32, 0.32, 0.4)


static func _lamp_post(root: Node3D, kit: MeshKit, pos: Vector3, energy: float = 1.2) -> void:
	kit.box_at("wood", pos + Vector3(0, 1.4, 0), Vector3(0.14, 2.8, 0.14))
	kit.box_at("wood", pos + Vector3(0.3, 2.7, 0), Vector3(0.65, 0.1, 0.1))
	kit.box_at("window", pos + Vector3(0.55, 2.4, 0), Vector3(0.24, 0.32, 0.24))
	kit.pyramid("iron", Transform3D(Basis(), pos + Vector3(0.55, 2.56, 0)), 0.34, 0.34, 0.2)
	_light(root, kit, pos + Vector3(0.55, 2.3, 0), Color("#ffa04a"), energy, 9.0, 0.18, 4.0)


static func _hut_yard(kit: MeshKit, root: Node3D, w: float, d: float, rng: RandomNumberGenerator, building_name: String) -> void:
	## Двір хатини: господарські дрібниці за темою мешканця (мисливець, відьма, відлюдник, болото).
	var side := -1.0 if rng.randf() > 0.5 else 1.0
	var sx := side * (w * 0.5 + 2.4)
	if building_name.contains("відьми"):
		# Казан над вогнем, грядки трав, кістяний стовп.
		var pot := Vector3(sx, 0, -d * 0.5 - 1.4)
		kit.cylinder_at("iron", pot + Vector3(0, 0.6, 0), 0.62, 0.45, 0.7, 8, true)
		kit.cylinder_at("window_green", pot + Vector3(0, 0.97, 0), 0.52, 0.52, 0.05, 8)
		for a in range(3):
			kit.box_at("wood", pot + Vector3(cos(float(a) * 2.1) * 0.7, 0.2, sin(float(a) * 2.1) * 0.7), Vector3(0.08, 0.4, 0.08), false, Vector3(0.4, float(a), 0.4))
		_light(root, kit, pot + Vector3(0, 1.4, 0), Color("#6fe39a"), 1.6, 9.0, 0.3, 5.0)
		_garden(kit, Vector3(-sx * 0.8, 0, d * 0.5 + 1.6), 0.0, 3, 3.0)
		kit.box_at("wood", Vector3(sx * 1.2, 1.3, d * 0.5 + 1.0), Vector3(0.12, 2.6, 0.12))
		kit.box_at("bone", Vector3(sx * 1.2, 2.7, d * 0.5 + 1.0), Vector3(0.36, 0.34, 0.36))
		_drying_rack(kit, Vector3(-sx * 1.1, 0, -d * 0.2), PI * 0.5, "cloth_red")
	elif building_name.contains("мисливця"):
		_drying_rack(kit, Vector3(sx, 0, -d * 0.5 - 1.2), 0.0, "cloth_tent")
		_woodpile(kit, Vector3(-sx, 0, d * 0.1), PI * 0.5)
		_stump_axe(kit, Vector3(-sx * 0.8, 0, -d * 0.5 - 1.6))
		kit.box_at("wood", Vector3(sx * 1.1, 1.0, d * 0.5 + 0.8), Vector3(0.12, 2.0, 0.12))
		kit.box_at("bone", Vector3(sx * 1.1, 2.1, d * 0.5 + 0.8), Vector3(0.7, 0.14, 0.14))
	elif building_name.contains("відлюдника"):
		_garden(kit, Vector3(-sx * 0.9, 0, d * 0.5 + 1.2), 0.0, 4, 3.4)
		_woodpile(kit, Vector3(sx, 0, d * 0.1), PI * 0.5)
		for k in range(3):
			var a := float(k) * 0.9 - 0.9
			kit.box_at("stone", Vector3(sx * 1.3 + a * 0.3, 0.3 + float(k % 2) * 0.1, -d * 0.5 - 2.0 + a * 0.5), Vector3(0.5, 0.6, 0.4))
		kit.box_at("bone", Vector3(sx * 1.3, 0.8, -d * 0.5 - 2.0), Vector3(0.14, 0.3, 0.14))
		_light(root, kit, Vector3(sx * 1.3, 1.1, -d * 0.5 - 2.0), Color("#ffb060"), 0.9, 6.0, 0.3, 7.0)
	elif building_name.contains("Болотна"):
		for k in range(5):
			kit.box_at("wood_light", Vector3(sx + float(k) * 0.0, 0.1, -d * 0.5 - 1.5 - float(k) * 1.2), Vector3(1.4, 0.12, 1.0), false, Vector3(0, float(k) * 0.12, 0))
		_barrel(kit, Vector3(-sx, 0, -d * 0.5 - 0.8))
		_barrel(kit, Vector3(-sx - 0.9, 0, -d * 0.5 - 0.3))
		_drying_rack(kit, Vector3(-sx * 1.0, 0, d * 0.5 + 1.5), 0.0, "cloth_black")
		_lamp_post(root, kit, Vector3(sx * 1.3, 0, -d * 0.5 - 3.6), 1.4)
	else:
		_woodpile(kit, Vector3(sx, 0, d * 0.2), PI * 0.5)
		_stump_axe(kit, Vector3(-sx, 0, -d * 0.5 - 1.2))
	# Низький тин із прогалиною для стежки перед хатиною.
	var fz := d * 0.5 + 3.2
	_fence(kit, Vector3(-w * 0.5 - 4.0, 0, fz), Vector3(-1.5, 0, fz), rng)
	_fence(kit, Vector3(1.5, 0, fz), Vector3(w * 0.5 + 4.0, 0, fz), rng)


static func _hamlet(kit: MeshKit, root: Node3D, rng: RandomNumberGenerator, building_name: String) -> void:
	## Кругле селище: чотири хати довкола вогнища, колодязь, паркани, лампи, воза, сіно.
	var huts := [
		[Vector3(-10.5, 0, 3.0), 7.5, 6.0, "thatch"],
		[Vector3(10.5, 0, 4.5), 7.0, 6.5, "shingle"],
		[Vector3(-7.5, 0, 14.0), 6.5, 5.5, "shingle"],
		[Vector3(7.5, 0, 15.0), 8.0, 6.0, "thatch"],
	]
	var center := Vector3(0, 0, 8.0)
	for i in range(huts.size()):
		var item: Array = huts[i]
		var p: Vector3 = item[0]
		var yaw := atan2(p.x - center.x, p.z - center.z) + rng.randf_range(-0.12, 0.12)
		kit.origin = Transform3D(Basis(Vector3.UP, yaw), p)
		_hut(kit, root, float(item[1]), float(item[2]), rng, str(item[3]), i % 2 == 0)
	kit.origin = Transform3D.IDENTITY
	# Центральне вогнище з лавами-колодами.
	for i in range(8):
		var a := TAU * float(i) / 8.0
		kit.rock("stone", Transform3D(Basis(Vector3.UP, a), center + Vector3(cos(a) * 1.0, 0, sin(a) * 1.0)), Vector3(0.45, 0.32, 0.4), rng)
	kit.cylinder_at("wood", center + Vector3(0, 0.15, 0), 0.12, 0.12, 1.4, 6, false, Vector3(0, 0.6, PI * 0.5))
	kit.cylinder_at("wood", center + Vector3(0, 0.15, 0), 0.12, 0.12, 1.4, 6, false, Vector3(0, -0.6, PI * 0.5))
	kit.cylinder_at("ember", center, 0.5, 0.0, 1.1, 5)
	for a in [0.4, 2.2, 4.1]:
		kit.cylinder_at("wood_light", center + Vector3(cos(a) * 2.8, 0.28, sin(a) * 2.8), 0.26, 0.26, 2.0, 7, true, Vector3(0.0, -a + PI * 0.5, PI * 0.5))
	_light(root, kit, center + Vector3(0, 1.4, 0), Color("#ff6a1c"), 3.4, 17.0, 0.36, 9.0, false, true)
	# Колодязь.
	var well := Vector3(0, 0, -5.0)
	kit.cylinder_at("stone", well, 1.0, 1.0, 0.9, 8, true)
	kit.cylinder_at("cave_dark", well + Vector3(0, 0.91, 0), 0.75, 0.75, 0.02, 8)
	for side: float in [-1.0, 1.0]:
		kit.box_at("wood", well + Vector3(side * 0.95, 1.4, 0), Vector3(0.16, 2.0, 0.16))
	kit.gable_roof("shingle", "wood", Transform3D(Basis(), well + Vector3(0, 2.4, 0)), 2.4, 1.5, 0.7, 0.2, 0.1)
	# Господарство.
	_cart(kit, Vector3(14.5, 0, -2.0), 0.4)
	_haystack(kit, Vector3(-15.5, 0, 9.0), 1.0)
	_haystack(kit, Vector3(15.5, 0, 12.0), 0.8)
	_woodpile(kit, Vector3(-15.0, 0, -1.0), 0.2)
	_drying_rack(kit, Vector3(-1.5, 0, 17.5), 0.0, "cloth_black")
	_lamp_post(root, kit, Vector3(-6.0, 0, -4.0))
	_lamp_post(root, kit, Vector3(6.0, 0, -4.0))
	_barrel(kit, Vector3(3.0, 0, -4.0))
	_crate(kit, Vector3(3.8, 0, -3.2), 0.7, 0.4)
	# Частокіл позаду та по боках.
	_fence(kit, Vector3(-17.0, 0, 21.0), Vector3(17.0, 0, 21.0), rng)
	_fence(kit, Vector3(-17.0, 0, 21.0), Vector3(-19.0, 0, 6.0), rng)
	_fence(kit, Vector3(17.0, 0, 21.0), Vector3(19.0, 0, 7.0), rng)
	if building_name.contains("Копалень"):
		# Вхід у шахту: підпірки, темний отвір, вагонетки з рудою.
		var m := Vector3(0, 0, 25.5)
		kit.rock("rock", Transform3D(Basis(), m + Vector3(0, -1.0, 4.0)), Vector3(14.0, 8.0, 9.0), rng, true)
		kit.box_at("cave_dark", m + Vector3(0, 1.6, -0.4), Vector3(3.6, 3.2, 0.4))
		for side: float in [-1.0, 1.0]:
			kit.box_at("wood", m + Vector3(side * 2.1, 1.8, -0.5), Vector3(0.4, 3.6, 0.4), true)
		kit.box_at("wood", m + Vector3(0, 3.7, -0.5), Vector3(4.8, 0.4, 0.5), true)
		_cart(kit, m + Vector3(-6.0, 0, -3.5), 1.2)
		_crate(kit, m + Vector3(5.5, 0, -2.5), 0.9, 0.3)
		_crate(kit, m + Vector3(6.4, 0, -1.6), 0.7, 0.8)
		_light(root, kit, m + Vector3(0, 3.0, -1.4), Color("#ff9440"), 1.3, 9.0, 0.3, 6.0)


static func _farmstead(kit: MeshKit, root: Node3D, rng: RandomNumberGenerator) -> void:
	## Хутір: хата, клуня з великим дахом, поле з опудалом, сіно, загін та колодязь.
	kit.origin = Transform3D(Basis(Vector3.UP, 0.15), Vector3(-9.0, 0, 0.0))
	_hut(kit, root, 7.5, 6.5, rng, "thatch", true)
	# Клуня.
	kit.origin = Transform3D(Basis(Vector3.UP, -0.12), Vector3(8.5, 0, 2.0))
	kit.box_at("stone", Vector3(0, 0.25, 0), Vector3(10.6, 0.5, 7.6), true)
	kit.box_at("wall", Vector3(0, 2.5, 0), Vector3(10.0, 4.0, 7.0), true)
	for cx: float in [-5.0, 5.0]:
		for cz: float in [-3.5, 3.5]:
			kit.box_at("wood", Vector3(cx, 2.5, cz), Vector3(0.34, 4.0, 0.34))
	for y: float in [1.4, 3.6]:
		kit.box_at("wood", Vector3(0, y, -3.55), Vector3(10.0, 0.22, 0.14))
	kit.gable_roof("thatch", "wall", Transform3D(Basis(), Vector3(0, 4.5, 0)), 10.0, 7.0, 3.6, 0.8, 0.26)
	for side: float in [-1.0, 1.0]:
		kit.box_at("wood_light", Vector3(side * 1.1, 1.9, -3.58), Vector3(2.1, 3.0, 0.14), false, Vector3(0, side * 0.05, 0))
	kit.box_at("iron", Vector3(0, 1.9, -3.7), Vector3(4.4, 0.12, 0.06))
	kit.box_at("window", Vector3(0, 5.6, -3.5), Vector3(0.9, 0.9, 0.08))
	_lamp_post(root, kit, Vector3(-3.4, 0, -5.2))
	kit.origin = Transform3D.IDENTITY
	# Поле та загін.
	_garden(kit, Vector3(-6.0, 0, 11.0), 0.0, 5, 10.0)
	_scarecrow(kit, Vector3(-1.0, 0, 13.0), 0.3)
	_fence(kit, Vector3(-12.0, 0, 9.0), Vector3(3.0, 0, 9.0), rng)
	_fence(kit, Vector3(-12.0, 0, 9.0), Vector3(-12.0, 0, 17.5), rng)
	_fence(kit, Vector3(-12.0, 0, 17.5), Vector3(3.0, 0, 17.5), rng)
	_fence(kit, Vector3(3.0, 0, 17.5), Vector3(3.0, 0, 9.0), rng)
	_haystack(kit, Vector3(15.5, 0, 9.5), 1.0)
	_haystack(kit, Vector3(13.0, 0, 11.5), 0.8)
	_cart(kit, Vector3(1.5, 0, 4.5), 0.9)
	_barrel(kit, Vector3(-3.2, 0, -4.2))
	var well := Vector3(-2.5, 0, 3.0)
	kit.cylinder_at("stone", well, 0.85, 0.9, 0.85, 8, true)
	kit.cylinder_at("cave_dark", well + Vector3(0, 0.86, 0), 0.62, 0.62, 0.02, 8)


# --- Вежі -------------------------------------------------------------------------

static func _gothic_tower(kit: MeshKit, root: Node3D, width: float, rng: RandomNumberGenerator, variant: String) -> void:
	var w := clampf(width * 0.62, 6.0, 8.0)
	var h := 18.0
	var pane := "window"
	if variant == "ice":
		h = 23.0
		pane = "window_blue"
	elif variant == "ruined":
		h = 14.0
	elif variant == "watch":
		h = 13.0
	var hw := w * 0.5
	kit.box_at("stone", Vector3(0, 0.5, 0), Vector3(w + 1.4, 1.0, w + 1.4), true)
	kit.box_at("brick", Vector3(0, 1.0 + h * 0.5, 0), Vector3(w, h, w), true)
	for band: float in [0.34, 0.68]:
		kit.box_at("stone", Vector3(0, 1.0 + h * band, 0), Vector3(w + 0.35, 0.35, w + 0.35))
	# Ступінчасті контрфорси.
	for cx: float in [-1.0, 1.0]:
		for cz: float in [-1.0, 1.0]:
			var corner := Vector3(cx * hw, 0, cz * hw)
			kit.box_at("stone", corner + Vector3(0, 1.0 + h * 0.28, 0), Vector3(1.2, h * 0.56, 1.2), true)
			kit.box_at("stone", corner + Vector3(0, 1.0 + h * 0.56 + h * 0.15, 0), Vector3(0.85, h * 0.3, 0.85))
			kit.pyramid("stone", Transform3D(Basis(), corner + Vector3(0, 1.0 + h * 0.86, 0)), 0.85, 0.85, 1.0)
	# Стрілчасті вікна на всіх гранях.
	for face in range(4):
		var yaw := PI * 0.5 * float(face)
		for level: float in [0.5, 0.82]:
			if variant == "ruined" and level > 0.8 and face % 2 == 1:
				continue
			var use_pane := pane if (level > 0.7 or face == 0) else "stone_dark"
			_lancet(kit, Transform3D(Basis(Vector3.UP, yaw), Basis(Vector3.UP, yaw) * Vector3(0, 1.0 + h * level, -hw - 0.02)), 0.7, 1.7, use_pane)
	_door(kit, _face(0.0, Vector3(0, 1.0, -hw - 0.02)), 1.5, 2.6, true)
	kit.box_at("stone", Vector3(0, 0.25, -hw - 1.1), Vector3(2.4, 0.5, 1.2), true)
	var top := 1.0 + h

	match variant:
		"ruined":
			# Обвалена верхівка, зламаний купол і уламки довкола.
			for i in range(10):
				var a := TAU * float(i) / 10.0
				var bh := rng.randf_range(0.4, 3.2)
				kit.box_at("brick", Vector3(cos(a) * hw * 0.8, top + bh * 0.5, sin(a) * hw * 0.8), Vector3(1.6, bh, 1.0), false, Vector3(0, -a, 0))
			for i in range(7):
				var a := PI * float(i) / 6.0
				kit.box_at("stone", Vector3(cos(a) * hw * 0.75, top + 2.5 + sin(a) * 2.6, 0.4), Vector3(0.9, 0.5, 2.4), false, Vector3(0, 0, a + PI * 0.5))
			for i in range(9):
				var a := rng.randf() * TAU
				var r := rng.randf_range(hw + 1.5, hw + 5.0)
				var s := rng.randf_range(0.6, 1.5)
				kit.rock("stone", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(cos(a) * r, 0, sin(a) * r)), Vector3(s * 1.4, s, s * 1.2), rng, s > 1.0)
			_light(root, kit, Vector3(0, top - 2.0, -hw - 0.8), Color("#ffb060"), 1.4, 10.0, 0.25, 4.0)
		"watch":
			kit.box_at("wood", Vector3(0, top + 0.15, 0), Vector3(w + 2.4, 0.3, w + 2.4), true)
			for cx: float in [-1.0, 1.0]:
				for cz: float in [-1.0, 1.0]:
					kit.box_at("wood", Vector3(cx * (hw + 1.0), top + 1.5, cz * (hw + 1.0)), Vector3(0.25, 2.7, 0.25))
			kit.box_at("wood_light", Vector3(0, top + 0.9, -hw - 1.1), Vector3(w + 2.2, 0.12, 0.1))
			kit.box_at("wood_light", Vector3(0, top + 0.9, hw + 1.1), Vector3(w + 2.2, 0.12, 0.1))
			kit.pyramid("thatch", Transform3D(Basis(), Vector3(0, top + 2.8, 0)), w + 3.2, w + 3.2, 3.6)
			kit.box_at("iron", Vector3(0, top + 0.6, 0), Vector3(0.8, 0.6, 0.8))
			kit.box_at("ember", Vector3(0, top + 1.0, 0), Vector3(0.6, 0.3, 0.6))
			_light(root, kit, Vector3(0, top + 1.6, 0), Color("#ff8a3a"), 2.6, 18.0, 0.32, 8.0)
		_:
			kit.box_at("stone", Vector3(0, top + 0.25, 0), Vector3(w + 0.9, 0.5, w + 0.9))
			_crenels(kit, "stone", top + 0.5, hw + 0.3, hw + 0.3, 0.55)
			var roof_key := "shingle_blue" if variant == "ice" else "shingle"
			kit.pyramid(roof_key, Transform3D(Basis(), Vector3(0, top + 0.5, 0)), w - 0.2, w - 0.2, w * 1.7)
			for cx: float in [-1.0, 1.0]:
				for cz: float in [-1.0, 1.0]:
					kit.pyramid(roof_key, Transform3D(Basis(), Vector3(cx * (hw + 0.1), top + 1.2, cz * (hw + 0.1))), 0.6, 0.6, 2.2)
			if variant == "ice":
				# Синій сигнал на верхівці (квест «Сигнал із криги»).
				kit.box_at("window_blue", Vector3(0, top + w * 1.7 + 0.8, 0), Vector3(0.5, 0.9, 0.5), false, Vector3(0, PI * 0.25, 0))
				_light(root, kit, Vector3(0, top + w * 1.7 + 1.0, 0), Color("#6fb8ff"), 3.5, 26.0, 0.45, 2.5)
				_light(root, kit, Vector3(0, 3.0, -hw - 2.0), Color("#8ccaff"), 1.2, 9.0, 0.15, 3.0)
			else:
				_light(root, kit, Vector3(0, 3.2, -hw - 1.8), Color("#ffa04a"), 1.3, 9.0, 0.18, 4.0)


# --- Церква ------------------------------------------------------------------------

static func _church(kit: MeshKit, root: Node3D, width: float, depth: float, rng: RandomNumberGenerator, flooded: bool) -> void:
	var nw := clampf(width * 0.55, 7.0, 9.0)
	var nl := clampf(depth, 12.0, 15.0)
	var zc := 1.5
	var wall_h := 6.5
	var plinth := 0.6
	var top := plinth + wall_h
	kit.box_at("stone", Vector3(0, plinth * 0.5, zc), Vector3(nw + 0.8, plinth, nl + 0.8), true)
	kit.box_at("wall", Vector3(0, plinth + wall_h * 0.5, zc), Vector3(nw, wall_h, nl), true)
	kit.gable_roof("shingle", "wall", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, top, zc)), nl, nw, nw * 0.75, 0.5, 0.26)
	# Контрфорси та стрілчасті вікна вздовж нави.
	var bays := 4
	for i in range(bays + 1):
		var z := zc - nl * 0.5 + nl * float(i) / float(bays)
		for side: float in [-1.0, 1.0]:
			kit.box_at("stone", Vector3(side * (nw * 0.5 + 0.45), plinth + wall_h * 0.4, z), Vector3(0.9, wall_h * 0.8, 1.0), true)
			kit.pyramid("stone", Transform3D(Basis(), Vector3(side * (nw * 0.5 + 0.45), plinth + wall_h * 0.8, z)), 0.9, 1.0, 1.2)
	for i in range(bays):
		var z := zc - nl * 0.5 + nl * (float(i) + 0.5) / float(bays)
		_lancet(kit, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-nw * 0.5 - 0.02, plinth + wall_h * 0.52, z)), 0.8, 2.6)
		_lancet(kit, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(nw * 0.5 + 0.02, plinth + wall_h * 0.52, z)), 0.8, 2.6)
	# Апсида.
	kit.cylinder_at("wall", Vector3(0, plinth, zc + nl * 0.5), nw * 0.48, nw * 0.48, wall_h * 0.85, 8, true)
	kit.cylinder_at("shingle", Vector3(0, plinth + wall_h * 0.85, zc + nl * 0.5), nw * 0.55, 0.0, 3.2, 8)
	# Дзвіниця з порталом і шпилем.
	var tw := 4.6
	var th := 15.0
	var tz := zc - nl * 0.5 - tw * 0.3
	kit.box_at("brick", Vector3(0, plinth + th * 0.5, tz), Vector3(tw, th, tw), true)
	kit.box_at("stone", Vector3(0, plinth + th * 0.62, tz), Vector3(tw + 0.3, 0.3, tw + 0.3))
	for face in range(4):
		var yaw := PI * 0.5 * float(face)
		var basis := Basis(Vector3.UP, yaw)
		kit.box("cave_dark", Transform3D(basis, Vector3(0, plinth + th - 1.8, tz) + basis * Vector3(0, 0, -tw * 0.5 - 0.02)), Vector3(1.0, 2.0, 0.08))
		kit.pyramid("cave_dark", Transform3D(basis, Vector3(0, plinth + th - 0.8, tz) + basis * Vector3(0, 0, -tw * 0.5 - 0.02)), 1.0, 0.08, 0.7)
	kit.box_at("stone", Vector3(0, plinth + th + 0.2, tz), Vector3(tw + 0.6, 0.4, tw + 0.6))
	_crenels(kit, "stone", plinth + th + 0.4, tw * 0.5 + 0.2, tw * 0.5 + 0.2, 0.5)
	kit.pyramid("shingle", Transform3D(Basis(), Vector3(0, plinth + th + 0.4, tz)), tw - 0.4, tw - 0.4, 9.0)
	kit.box_at("iron", Vector3(0, plinth + th + 9.8, tz), Vector3(0.12, 1.4, 0.12))
	kit.box_at("iron", Vector3(0, plinth + th + 10.0, tz), Vector3(0.7, 0.12, 0.12))
	_door(kit, _face(0.0, Vector3(0, plinth, tz - tw * 0.5 - 0.02)), 1.8, 3.2, true)
	kit.cylinder_at("window", Vector3(0, plinth + 6.0, tz - tw * 0.5 - 0.16), 0.85, 0.85, 0.06, 10, false, Vector3(PI * 0.5, 0, 0))
	kit.cylinder_at("stone", Vector3(0, plinth + 6.0, tz - tw * 0.5 - 0.09), 1.1, 1.1, 0.08, 10, false, Vector3(PI * 0.5, 0, 0))
	kit.box_at("stone", Vector3(0, plinth * 0.5 * 0.5, tz - tw * 0.5 - 0.9), Vector3(3.2, plinth * 0.5, 1.2), true)
	if flooded:
		kit.box_at("water", Vector3(0, 0.18, zc - 1.0), Vector3(nw + 16.0, 0.06, nl + 16.0))
	_light(root, kit, Vector3(0, plinth + 2.5, tz - tw * 0.5 - 1.8), Color("#ffb060"), 1.4, 10.0, 0.15, 3.0)
	_light(root, kit, Vector3(0, plinth + 6.0, tz - tw * 0.5 - 2.5), Color("#ffc070"), 1.0, 9.0, 0.08, 2.0)


# --- Цвинтар -----------------------------------------------------------------------

static func _cemetery(kit: MeshKit, root: Node3D, rng: RandomNumberGenerator) -> void:
	# Мавзолей.
	var mw := 5.6
	var md := 7.0
	var mz := 5.0
	var wall_h := 3.6
	kit.box_at("stone", Vector3(0, 0.4, mz), Vector3(mw + 0.8, 0.8, md + 0.8), true)
	kit.box_at("moss_stone", Vector3(0, 0.8 + wall_h * 0.5, mz), Vector3(mw, wall_h, md), true)
	kit.gable_roof("stone_dark", "moss_stone", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 0.8 + wall_h, mz)), md, mw, 2.2, 0.35, 0.3)
	var porch_z := mz - md * 0.5 - 1.3
	for side: float in [-1.0, 1.0]:
		kit.cylinder_at("stone", Vector3(side * 1.7, 0.8, porch_z), 0.3, 0.26, wall_h, 8, true)
	kit.box_at("stone", Vector3(0, 0.8 + wall_h + 0.2, porch_z + 0.4), Vector3(4.4, 0.4, 2.0))
	kit.pyramid("stone_dark", Transform3D(Basis(), Vector3(0, 0.8 + wall_h + 0.4, porch_z + 0.4)), 4.4, 2.0, 1.2)
	kit.box_at("iron", Vector3(0, 0.8 + 1.25, mz - md * 0.5 - 0.06), Vector3(1.6, 2.5, 0.12))
	for y: float in [1.0, 2.0, 2.9]:
		kit.box_at("stone_dark", Vector3(0, y, mz - md * 0.5 - 0.14), Vector3(1.7, 0.08, 0.06))
	kit.box_at("stone", Vector3(0, 0.2, porch_z - 1.0), Vector3(3.4, 0.4, 1.0), true)
	# Кована огорожа з брамою.
	var hw := 11.0
	var hd := 10.0
	var z0 := 0.5
	var corners := [Vector3(-hw, 0, z0 - hd), Vector3(hw, 0, z0 - hd), Vector3(hw, 0, z0 + hd), Vector3(-hw, 0, z0 + hd)]
	for i in range(4):
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var length := a.distance_to(b)
		var steps := int(length / 0.9)
		for s in range(steps + 1):
			var p := a.lerp(b, float(s) / float(steps))
			if i == 0 and absf(p.x) < 1.8:
				continue
			kit.box_at("iron", p + Vector3(0, 0.85, 0), Vector3(0.07, 1.7, 0.07))
			kit.pyramid("iron", Transform3D(Basis(), p + Vector3(0, 1.7, 0)), 0.14, 0.14, 0.25)
		var mid := (a + b) * 0.5
		var along := (b - a).normalized()
		var yaw := atan2(-along.z, along.x)
		for y: float in [0.45, 1.45]:
			if i == 0:
				for side: float in [-1.0, 1.0]:
					var seg_len := hw - 1.8
					kit.box_at("iron", Vector3(side * (1.8 + seg_len * 0.5), y, a.z), Vector3(seg_len, 0.06, 0.06), y < 1.0)
			else:
				kit.box_at("iron", mid + Vector3(0, y, 0), Vector3(length, 0.06, 0.06), y < 1.0, Vector3(0, yaw, 0))
	for side: float in [-1.0, 1.0]:
		kit.box_at("stone", Vector3(side * 1.9, 1.1, z0 - hd), Vector3(0.7, 2.2, 0.7), true)
		kit.pyramid("stone", Transform3D(Basis(), Vector3(side * 1.9, 2.2, z0 - hd)), 0.8, 0.8, 0.6)
	# Надгробки рядами.
	for row in range(6):
		for col in range(-4, 5):
			var x := float(col) * 2.1 + rng.randf_range(-0.3, 0.3)
			var z := z0 - hd + 2.2 + float(row) * 2.4 + rng.randf_range(-0.3, 0.3)
			if absf(x) < 1.8 or (absf(x) < mw * 0.5 + 1.5 and z > mz - md * 0.5 - 2.6):
				continue
			if rng.randf() < 0.18:
				continue
			_tombstone(kit, Vector3(x, 0, z), rng)
	# Свічки та примарне світло.
	for i in range(5):
		var p := Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-6, 3))
		kit.box_at("window", p + Vector3(0, 0.15, 0), Vector3(0.08, 0.3, 0.08))
	_light(root, kit, Vector3(0, 2.0, porch_z - 0.5), Color("#a6f0c0"), 1.4, 11.0, 0.3, 3.5)
	_light(root, kit, Vector3(-5.0, 1.0, -2.0), Color("#ffb060"), 0.7, 6.0, 0.35, 7.0)


static func _tombstone(kit: MeshKit, p: Vector3, rng: RandomNumberGenerator) -> void:
	var tilt := Vector3(rng.randf_range(-0.14, 0.14), rng.randf_range(-0.2, 0.2), rng.randf_range(-0.12, 0.12))
	var basis := Basis.from_euler(tilt)
	var kind := rng.randi_range(0, 3)
	var key := "moss_stone" if rng.randf() > 0.5 else "stone"
	match kind:
		0:
			kit.box(key, Transform3D(basis, p + Vector3(0, 0.5, 0)), Vector3(0.7, 1.0, 0.18))
			kit.cylinder(key, Transform3D(basis * Basis(Vector3.RIGHT, PI * 0.5), p + basis * Vector3(0, 1.0, -0.09)), 0.35, 0.35, 0.18, 8)
		1:
			kit.box(key, Transform3D(basis, p + Vector3(0, 0.7, 0)), Vector3(0.16, 1.4, 0.16))
			kit.box(key, Transform3D(basis, p + basis * Vector3(0, 1.05, 0)), Vector3(0.75, 0.15, 0.15))
		2:
			kit.box(key, Transform3D(basis, p + Vector3(0, 0.25, 0)), Vector3(0.6, 0.5, 0.6))
			kit.pyramid(key, Transform3D(basis, p + Vector3(0, 0.5, 0)), 0.4, 0.4, 1.4)
		_:
			kit.box(key, Transform3D(basis, p + Vector3(0, 0.12, 0.5)), Vector3(0.9, 0.24, 1.9))
			kit.box(key, Transform3D(basis, p + Vector3(0, 0.45, -0.45)), Vector3(0.8, 0.9, 0.16))


# --- Кузня ---------------------------------------------------------------------------

static func _forge(kit: MeshKit, root: Node3D, rng: RandomNumberGenerator) -> void:
	_hut(kit, root, 8.0, 7.0, rng, "shingle", false)
	var x0 := 4.0
	# Навіс на стовпах.
	for px: float in [x0 + 0.3, x0 + 4.2]:
		for pz: float in [-3.0, 3.0]:
			kit.box_at("wood", Vector3(px, 1.6, pz), Vector3(0.28, 3.2, 0.28), true)
	kit.box_at("shingle", Vector3(x0 + 2.25, 3.35, 0), Vector3(5.2, 0.22, 7.2), false, Vector3(0, 0, -0.18))
	# Горно, димар, жар, ковадло, бочка.
	var hearth := Vector3(x0 + 2.3, 0, 1.4)
	kit.box_at("brick", hearth + Vector3(0, 0.7, 0), Vector3(2.4, 1.4, 2.0), true)
	kit.box_at("brick", hearth + Vector3(0, 3.2, 0.7), Vector3(1.2, 6.4, 0.9))
	kit.box_at("ember", hearth + Vector3(0, 1.42, -0.2), Vector3(1.4, 0.12, 1.0))
	kit.box_at("cave_dark", hearth + Vector3(0, 1.0, -1.01), Vector3(1.0, 0.6, 0.04))
	_smoke(root, kit, hearth + Vector3(0, 6.5, 0.7))
	var anvil := Vector3(x0 + 2.0, 0, -1.6)
	kit.box_at("wood", anvil + Vector3(0, 0.35, 0), Vector3(0.7, 0.7, 0.7), true)
	kit.box_at("iron", anvil + Vector3(0, 0.85, 0), Vector3(0.5, 0.3, 0.35))
	kit.box_at("iron", anvil + Vector3(0, 1.05, 0), Vector3(1.1, 0.16, 0.42))
	_barrel(kit, Vector3(x0 + 3.8, 0, -2.4))
	kit.cylinder_at("stone", Vector3(x0 + 0.9, 0.7, -2.6), 0.55, 0.55, 0.22, 10, false, Vector3(PI * 0.5, 0, 0))
	_light(root, kit, hearth + Vector3(0, 1.8, -1.4), Color("#ff7a36"), 3.0, 12.0, 0.32, 5.5, true, true)


# --- Брама велетнів --------------------------------------------------------------------

static func _giant_gate(kit: MeshKit, root: Node3D, rng: RandomNumberGenerator) -> void:
	var px := 5.6
	var ph := 12.0
	for side: float in [-1.0, 1.0]:
		kit.box_at("stone", Vector3(side * px, 0.6, 0), Vector3(4.0, 1.2, 4.0), true)
		kit.box_at("moss_stone", Vector3(side * px, 1.2 + ph * 0.5, 0), Vector3(3.0, ph, 3.0), true)
		kit.box_at("stone", Vector3(side * px, 1.2 + ph, 0), Vector3(3.6, 0.6, 3.6))
		# Обвалені стіни, що тягнуться в боки.
		var x := side * (px + 2.5)
		for i in range(5):
			var h := rng.randf_range(3.0, 8.0) * (1.0 - float(i) * 0.12)
			kit.box_at("moss_stone", Vector3(x, h * 0.5, rng.randf_range(-0.2, 0.2)), Vector3(2.0, h, 2.4), true)
			x += side * 2.0
	_arch(kit, "moss_stone", Vector3(0, 1.2 + ph + 0.3, 0), px - 1.5, 1.6, 3.0, 11, [2, 3])
	for i in range(6):
		var p := Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6))
		var s := rng.randf_range(0.8, 1.8)
		kit.rock("moss_stone", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p), Vector3(s * 1.5, s, s * 1.3), rng, s > 1.2)
	# Глибокі подряпини на лівому пілоні.
	for i in range(3):
		kit.box_at("cave_dark", Vector3(-px + 0.4 + float(i) * 0.35, 5.0, -1.52), Vector3(0.1, 3.2, 0.04), false, Vector3(0, 0, 0.25))
	_light(root, kit, Vector3(0, 2.0, -4.0), Color("#c9b0ff"), 0.9, 10.0, 0.4, 1.5)


# --- Замок / цитадель ---------------------------------------------------------------------

static func _castle(kit: MeshKit, root: Node3D, rng: RandomNumberGenerator, s: float) -> void:
	var hw := 8.0 * s
	var hd := 7.0 * s
	var wall_h := 7.0 * s
	var wall_t := 1.6 * s
	var tower_r := 2.2 * s
	var tower_h := 12.5 * s
	var gate_w := 4.0 * s
	# Кутові вежі з конічними дахами.
	for cx: float in [-1.0, 1.0]:
		for cz: float in [-1.0, 1.0]:
			var c := Vector3(cx * hw, 0, cz * hd)
			# Вежа стоїть на фундаменті під землею; дах сидить прямо на кам'яному вінці (без щілини).
			kit.cylinder_at("brick", c + Vector3(0, -3.0, 0), tower_r * 1.08, tower_r, tower_h + 3.0, 10, true)
			kit.cylinder_at("stone", c + Vector3(0, tower_h, 0), tower_r * 1.22, tower_r * 1.22, 0.45 * s, 10)
			kit.cylinder_at("shingle", c + Vector3(0, tower_h + 0.4 * s, 0), tower_r * 1.32, 0.0, 5.0 * s, 10)
			for level: float in [0.45, 0.75]:
				var dir := Vector3(cx, 0, cz).normalized()
				var yaw := atan2(-dir.x, -dir.z)
				_lancet(kit, Transform3D(Basis(Vector3.UP, yaw),c + dir * (tower_r + 0.02) + Vector3(0, tower_h * level, 0)), 0.5 * s, 1.2 * s, "window" if level > 0.6 else "stone_dark")
	# Куртини з зубцями (у фасаді — проїзд).
	var walls := [
		[Vector3(0, 0, hd), Vector3(hw * 2.0, 0, 0)],
		[Vector3(-hw, 0, 0), Vector3(0, 0, hd * 2.0)],
		[Vector3(hw, 0, 0), Vector3(0, 0, hd * 2.0)],
	]
	for wdef in walls:
		var center: Vector3 = wdef[0]
		var span: Vector3 = wdef[1]
		# Раніше накривка мала висоту всієї стіни (2× заввишки): тепер тонкий парапет на фундаменті.
		var size := Vector3(maxf(span.x, wall_t), wall_h + 3.0, maxf(span.z, wall_t))
		kit.box_at("brick", center + Vector3(0, (wall_h - 3.0) * 0.5, 0), size, true)
		kit.box_at("stone", center + Vector3(0, wall_h + 0.15 * s, 0), Vector3(size.x + 0.3, 0.3 * s, size.z + 0.3))
	_crenels(kit, "stone", wall_h + 0.3 * s, hw, hd, 0.55 * s)
	var front_len := hw - gate_w * 0.5 - 1.2 * s
	for side: float in [-1.0, 1.0]:
		var cx := side * (gate_w * 0.5 + 1.2 * s + front_len * 0.5)
		kit.box_at("brick", Vector3(cx, (wall_h - 3.0) * 0.5, -hd), Vector3(front_len, wall_h + 3.0, wall_t), true)
		kit.box_at("stone", Vector3(cx, wall_h + 0.15 * s, -hd), Vector3(front_len + 0.3, 0.3 * s, wall_t + 0.3))
		# Надбрамні вежі.
		kit.box_at("brick", Vector3(side * (gate_w * 0.5 + 1.2 * s), (wall_h + 3.0 * s - 3.0) * 0.5, -hd - 0.4 * s), Vector3(2.4 * s, wall_h + 3.0 * s + 3.0, 2.8 * s), true)
		kit.box_at("stone", Vector3(side * (gate_w * 0.5 + 1.2 * s), wall_h + 3.0 * s + 0.2 * s, -hd - 0.4 * s), Vector3(2.8 * s, 0.4 * s, 3.2 * s))
		# Стяг вішається впритул до фасаду вежі (раніше висів у повітрі за 0.6 м).
		kit.box_at("cloth_red", Vector3(side * (gate_w * 0.5 + 1.2 * s), wall_h * 0.62, -hd - 1.8 * s - 0.04), Vector3(1.3 * s, 3.2 * s, 0.05))
	_arch(kit, "stone", Vector3(0, wall_h * 0.62, -hd - 0.4 * s), gate_w * 0.5, 0.9 * s, 2.8 * s, 7)
	kit.box_at("brick", Vector3(0, wall_h * 0.62 + gate_w * 0.5 + 1.6 * s, -hd - 0.4 * s), Vector3(gate_w + 1.0 * s, 2.0 * s + wall_h * 0.38 - gate_w * 0.5, 2.8 * s))
	for i in range(5):
		# Герса підвішена до склепіння арки: кожен прут іде від верху арки вниз.
		var gx := -gate_w * 0.4 + gate_w * 0.8 * float(i) / 4.0
		var arch_top := wall_h * 0.62 + sqrt(maxf(pow(gate_w * 0.5, 2.0) - gx * gx, 0.01)) + 0.1
		var bar_bottom := wall_h * 0.62 + 0.8
		kit.box_at("iron", Vector3(gx, (arch_top + bar_bottom) * 0.5, -hd - 0.4 * s), Vector3(0.12 * s, arch_top - bar_bottom, 0.12 * s))
	# Донжон.
	var keep_w := 7.0 * s
	var keep_h := 14.0 * s
	var keep_z := hd * 0.25
	kit.box_at("brick", Vector3(0, (keep_h - 3.0) * 0.5, keep_z), Vector3(keep_w, keep_h + 3.0, keep_w), true)
	kit.box_at("stone", Vector3(0, keep_h + 0.2 * s, keep_z), Vector3(keep_w + 0.6, 0.4 * s, keep_w + 0.6))
	_crenels(kit, "stone", keep_h + 0.4 * s, keep_w * 0.5 + 0.2, keep_w * 0.5 + 0.2, 0.6 * s)
	kit.pyramid("shingle", Transform3D(Basis(), Vector3(0, keep_h + 0.4 * s, keep_z)), keep_w * 0.7, keep_w * 0.7, keep_w * 0.9)
	for face in range(4):
		var basis := Basis(Vector3.UP, PI * 0.5 * float(face))
		for level: float in [0.55, 0.8]:
			_lancet(kit, Transform3D(basis, Vector3(0, keep_h * level, keep_z) + basis * Vector3(0, 0, -keep_w * 0.5 - 0.02)), 0.7 * s, 1.6 * s, "window" if (face == 0 or level > 0.7) else "stone_dark")
	_light(root, kit, Vector3(0, wall_h * 0.4, -hd - 3.0 * s), Color("#ffa04a"), 1.6, 12.0 * s, 0.2, 5.0)
	_light(root, kit, Vector3(-hw + 1.0, wall_h + 1.0, -hd + 1.0), Color("#ff8a3a"), 1.2, 9.0 * s, 0.3, 7.0)
	_light(root, kit, Vector3(hw - 1.0, wall_h + 1.0, -hd + 1.0), Color("#ff8a3a"), 1.2, 9.0 * s, 0.3, 7.0)


# --- Руїни фортеці Чорного Прапора ---------------------------------------------------------

static func _ruins(kit: MeshKit, root: Node3D, rng: RandomNumberGenerator) -> void:
	var hw := 9.0
	var hd := 8.0
	var corners := [Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd), Vector3(hw, 0, hd), Vector3(-hw, 0, hd)]
	for i in range(4):
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var length := a.distance_to(b)
		var steps := int(length / 2.0)
		var along := (b - a).normalized()
		var yaw := atan2(-along.z, along.x)
		for s in range(steps):
			var p := a.lerp(b, (float(s) + 0.5) / float(steps))
			if i == 0 and absf(p.x) < 2.5:
				continue
			if rng.randf() < 0.22:
				continue
			var h := rng.randf_range(1.0, 6.5)
			kit.box_at("stone_dark", p + Vector3(0, h * 0.5, 0), Vector3(2.05, h, 1.6), h > 1.2, Vector3(0, yaw, 0))
			if h > 3.0 and rng.randf() > 0.5:
				kit.box_at("stone_dark", p + Vector3(0, h + 0.3, 0), Vector3(0.7, 0.6, 1.6), false, Vector3(0, yaw, 0))
	# Обвалена вежа.
	var tower := Vector3(hw, 0, hd)
	kit.cylinder_at("stone_dark", tower, 3.2, 2.9, 9.0, 10, true)
	for i in range(8):
		var a := TAU * float(i) / 8.0
		var h := rng.randf_range(0.5, 3.5)
		kit.box_at("stone_dark", tower + Vector3(cos(a) * 2.6, 9.0 + h * 0.5, sin(a) * 2.6), Vector3(1.3, h, 0.9), false, Vector3(0, -a, 0))
	# Арка всередині.
	for side: float in [-1.0, 1.0]:
		kit.box_at("stone", Vector3(side * 2.4, 2.6, 1.0), Vector3(1.0, 5.2, 1.4), true)
	_arch(kit, "stone", Vector3(0, 5.2, 1.0), 1.9, 0.8, 1.3, 7, [5, 6])
	for i in range(10):
		var p := Vector3(rng.randf_range(-hw, hw), 0, rng.randf_range(-hd, hd))
		var s := rng.randf_range(0.5, 1.4)
		kit.rock("stone_dark", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p), Vector3(s * 1.4, s * 0.8, s * 1.1), rng, s > 1.0)
	# Чорні та червоний стяги, жаровня.
	var banners := [Vector3(-4.5, 0, -hd - 1.0), Vector3(4.5, 0, -hd - 1.0), Vector3(-hw + 1.5, 0, 2.0)]
	for i in range(banners.size()):
		var p: Vector3 = banners[i]
		kit.cylinder_at("wood", p, 0.1, 0.08, 7.0, 6, true)
		kit.box_at("wood", p + Vector3(0.7, 6.7, 0), Vector3(1.6, 0.1, 0.1))
		kit.box_at("cloth_red" if i == 2 else "cloth_black", p + Vector3(0.75, 5.1, 0), Vector3(1.3, 3.1, 0.05), false, Vector3(0, 0, 0.03))
	var brazier := Vector3(0, 0, -hd + 2.5)
	kit.cylinder_at("iron", brazier, 0.25, 0.6, 1.1, 6, true)
	kit.box_at("ember", brazier + Vector3(0, 1.12, 0), Vector3(0.7, 0.14, 0.7))
	_light(root, kit, brazier + Vector3(0, 1.8, 0), Color("#ff4a2a"), 2.4, 13.0, 0.35, 8.0, true, true)


# --- Табір ---------------------------------------------------------------------------

static func _camp(kit: MeshKit, root: Node3D, rng: RandomNumberGenerator) -> void:
	var fire := Vector3(0, 0, -2.0)
	var tents := [[Vector3(-5.2, 0, 0.5), 0.5], [Vector3(5.2, 0, 0.5), -0.5], [Vector3(0, 0, 4.2), 0.0]]
	for t in tents:
		var p: Vector3 = t[0]
		var yaw: float = t[1]
		kit.gable_roof("cloth_tent", "cloth_tent", Transform3D(Basis(Vector3.UP, yaw + PI * 0.5), p), 3.8, 3.2, 2.5, 0.05, 0.08)
		kit.box_at("wood", p + Vector3(0, 1.3, 0), Vector3(0.1, 2.6, 0.1), true)
	for i in range(8):
		var a := TAU * float(i) / 8.0
		kit.rock("stone", Transform3D(Basis(Vector3.UP, a), fire + Vector3(cos(a) * 1.1, 0, sin(a) * 1.1)), Vector3(0.5, 0.35, 0.4), rng)
	kit.cylinder_at("wood", fire + Vector3(0, 0.15, 0), 0.12, 0.12, 1.6, 6, false, Vector3(0, 0.6, PI * 0.5))
	kit.cylinder_at("wood", fire + Vector3(0, 0.15, 0), 0.12, 0.12, 1.6, 6, false, Vector3(0, -0.6, PI * 0.5))
	kit.cylinder_at("ember", fire, 0.55, 0.0, 1.2, 5)
	for side: float in [-1.0, 1.0]:
		kit.cylinder_at("wood_light", fire + Vector3(side * 2.8, 0.3, 0.6), 0.28, 0.28, 2.2, 7, true, Vector3(0.3, 0, PI * 0.5))
	_crate(kit, Vector3(-2.8, 0, 3.0), 0.8, 0.4)
	_barrel(kit, Vector3(2.9, 0, 3.4))
	kit.box_at("wood", Vector3(7.5, 1.0, -1.0), Vector3(0.12, 2.0, 0.12))
	kit.box_at("wood", Vector3(7.5, 1.6, -1.0), Vector3(0.12, 0.12, 1.8))
	_light(root, kit, fire + Vector3(0, 1.4, 0), Color("#ff6a1c"), 4.0, 18.0, 0.36, 9.0, true, true)


# --- Коло друїдів ----------------------------------------------------------------------

static func _stone_circle(kit: MeshKit, root: Node3D, rng: RandomNumberGenerator) -> void:
	var count := 10
	var radius := 7.0
	var tops: Array[Vector3] = []
	for i in range(count):
		var a := TAU * float(i) / float(count) + 0.2
		var p := Vector3(cos(a) * radius, 0, sin(a) * radius)
		var h := rng.randf_range(3.8, 5.6)
		var basis := Basis(Vector3.UP, -a) * Basis.from_euler(Vector3(rng.randf_range(-0.08, 0.08), 0, rng.randf_range(-0.1, 0.1)))
		kit.box("moss_stone", Transform3D(basis, p + Vector3(0, h * 0.5, 0)), Vector3(1.5, h, 1.0), true)
		kit.pyramid("moss_stone", Transform3D(basis, p + Vector3(0, h, 0)), 1.4, 0.95, 0.5)
		tops.append(p + Vector3(0, h, 0))
	for pair in [[0, 1], [5, 6]]:
		var a: Vector3 = tops[pair[0]]
		var b: Vector3 = tops[pair[1]]
		var mid := (a + b) * 0.5
		var dir := b - a
		var yaw := atan2(-dir.z, dir.x)
		kit.box_at("moss_stone", Vector3(mid.x, maxf(a.y, b.y) + 0.45, mid.z), Vector3(dir.length() + 1.4, 0.9, 1.1), false, Vector3(0, yaw, 0))
	kit.box_at("stone", Vector3(0, 0.4, 0), Vector3(2.6, 0.8, 1.5), true)
	kit.box_at("window_green", Vector3(0, 0.84, 0), Vector3(0.9, 0.08, 0.5))
	kit.box_at("moss_stone", Vector3(0, 1.4, 1.3), Vector3(0.8, 2.8, 0.4))
	kit.box_at("window_green", Vector3(0, 1.8, 1.08), Vector3(0.2, 1.1, 0.04))
	_light(root, kit, Vector3(0, 2.0, 0), Color("#6fe39a"), 2.2, 13.0, 0.25, 2.0)


# --- Лігво дракона -------------------------------------------------------------------------

static func _lair(kit: MeshKit, root: Node3D, rng: RandomNumberGenerator) -> void:
	kit.rock("rock", Transform3D(Basis(), Vector3(0, -1.0, 6.0)), Vector3(18.0, 10.0, 14.0), rng, true)
	kit.box_at("cave_dark", Vector3(0, 2.4, -0.6), Vector3(5.5, 4.8, 0.4))
	for i in range(7):
		var a := lerpf(-0.2, PI + 0.2, float(i) / 6.0)
		var p := Vector3(cos(a) * 5.0, 0, -sin(a) * 1.6 + 0.2)
		var s := rng.randf_range(2.5, 4.5)
		if absf(p.x) < 2.6 and i > 1 and i < 5:
			p.y = 4.6
			s *= 0.7
		kit.rock("rock", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p), Vector3(s, s * 0.9, s), rng, true)
	# Велетенські ребра вздовж підходу.
	for r in range(4):
		var z := -3.0 - float(r) * 2.4
		for side: float in [-1.0, 1.0]:
			for k in range(4):
				var a := float(k) / 4.0 * PI * 0.5
				var p := Vector3(side * (3.6 - sin(a) * 1.8 - float(r) * 0.2), cos(a) * 3.2 * (1.0 - float(r) * 0.12), z)
				kit.box_at("bone", p + Vector3(0, 0.3, 0), Vector3(0.32, 1.2, 0.32), false, Vector3(0, 0, side * (a + 0.2)))
	kit.rock("bone", Transform3D(Basis(Vector3.UP, 0.6), Vector3(4.5, 0, -7.0)), Vector3(1.6, 1.1, 2.2), rng, true)
	kit.box_at("cave_dark", Vector3(4.2, 0.65, -7.9), Vector3(0.4, 0.3, 0.1))
	kit.box_at("cave_dark", Vector3(4.9, 0.65, -7.8), Vector3(0.4, 0.3, 0.1))
	for i in range(6):
		kit.box_at("ember", Vector3(rng.randf_range(-1.8, 1.8), 0.1, rng.randf_range(0.0, 1.5)), Vector3(0.5, 0.15, 0.4), false, Vector3(0, rng.randf() * TAU, 0))
	_light(root, kit, Vector3(0, 1.5, 0.6), Color("#ff3a14"), 3.0, 14.0, 0.4, 1.4)


# --- Руїни на вершині Чорної Гори (головний орієнтир) ---------------------------------------

static func build_summit_ruins(seed_value: int, arena_center: Vector3 = Vector3(9999, 0, 9999), arena_clear: float = 0.0) -> Node3D:
	## «Попеляста Корона»: зруйнований готичний замок на вершині.
	## Висока вежа з тліючим вінцем видно з будь-якої точки світу.
	## arena_center/arena_clear — зона арени фінального бою, де мури й брили не ставляться.
	var root := Node3D.new()
	root.name = "SummitRuins"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var kit := MeshKit.new()
	var arena_flat := Vector2(arena_center.x, arena_center.z)
	# Кільце зруйнованих мурів по краю плато.
	var wall_r := 21.0
	for i in range(36):
		var a := TAU * float(i) / 36.0
		if rng.randf() < 0.2 or (i >= 3 and i <= 5):
			continue
		var h := rng.randf_range(2.5, 9.0)
		var p := Vector3(cos(a) * wall_r, 0, sin(a) * wall_r)
		if Vector2(p.x, p.z).distance_to(arena_flat) < arena_clear:
			# Пролом у мурі на арену: лише низький уламок.
			kit.box_at("stone_dark", p + Vector3(0, 0.2, 0), Vector3(3.0, 0.9, 2.0), false, Vector3(0.1, -a + PI * 0.5, 0.15))
			continue
		kit.box_at("stone_dark", p + Vector3(0, h * 0.5 - 0.5, 0), Vector3(3.9, h + 1.0, 2.2), true, Vector3(0, -a + PI * 0.5, 0))
		if h > 6.0:
			kit.box_at("stone_dark", p + Vector3(0, h + 0.4, 0), Vector3(1.0, 0.8, 2.2), false, Vector3(0, -a + PI * 0.5, 0))
	# Донжон зі зламаним верхом.
	var keep := Vector3(3.0, 0, 2.0)
	kit.box_at("stone_dark", keep + Vector3(0, 12.0, 0), Vector3(12.0, 24.0, 11.0), true)
	for i in range(12):
		var t := float(i) / 11.0
		var h := rng.randf_range(0.5, 5.0)
		kit.box_at("stone_dark", keep + Vector3(-5.5 + t * 11.0, 24.0 + h * 0.5, -5.0), Vector3(1.0, h, 1.0))
		h = rng.randf_range(0.5, 4.0)
		kit.box_at("stone_dark", keep + Vector3(-5.5 + t * 11.0, 24.0 + h * 0.5, 5.0), Vector3(1.0, h, 1.0))
	for face in range(4):
		var basis := Basis(Vector3.UP, PI * 0.5 * float(face))
		for level: float in [9.0, 15.0, 20.0]:
			var lit := rng.randf() > 0.55
			_lancet(kit, Transform3D(basis, keep + Vector3(0, level, 0) + basis * Vector3(rng.randf_range(-2.5, 2.5), 0, -5.52 if face % 2 == 0 else -6.02)), 0.9, 2.6, "window" if lit else "cave_dark")
	_arch(kit, "stone", keep + Vector3(0, 0, -5.6), 2.2, 0.9, 1.0, 7)
	kit.box_at("cave_dark", keep + Vector3(0, 1.6, -5.55), Vector3(4.2, 3.2, 0.1))
	# Головна вежа «Корони».
	var spire := Vector3(-7.0, 0, -4.0)
	var sw := 6.0
	var sh := 48.0
	kit.box_at("stone_dark", spire + Vector3(0, sh * 0.5, 0), Vector3(sw, sh, sw), true)
	for band: float in [0.25, 0.5, 0.75]:
		kit.box_at("stone", spire + Vector3(0, sh * band, 0), Vector3(sw + 0.5, 0.5, sw + 0.5))
	for cx: float in [-1.0, 1.0]:
		for cz: float in [-1.0, 1.0]:
			var c := spire + Vector3(cx * sw * 0.5, 0, cz * sw * 0.5)
			kit.box_at("stone_dark", c + Vector3(0, sh * 0.35, 0), Vector3(1.4, sh * 0.7, 1.4))
			kit.pyramid("stone_dark", Transform3D(Basis(), c + Vector3(0, sh * 0.7, 0)), 1.4, 1.4, 3.5)
	for face in range(4):
		var basis := Basis(Vector3.UP, PI * 0.5 * float(face))
		for level: float in [0.4, 0.62, 0.84]:
			_lancet(kit, Transform3D(basis, spire + Vector3(0, sh * level, 0) + basis * Vector3(0, 0, -sw * 0.5 - 0.02)), 0.8, 2.8, "window" if level > 0.8 else "cave_dark")
	kit.box_at("stone", spire + Vector3(0, sh + 0.3, 0), Vector3(sw + 1.4, 0.6, sw + 1.4))
	_crenels(kit, "stone", sh + 0.6, sw * 0.5 + 0.5, sw * 0.5 + 0.5, 0.7)
	# Тліючий вінець — вісім кам'яних зубців, розжарених зсередини.
	for i in range(8):
		var a := TAU * float(i) / 8.0
		var p := spire + Vector3(cos(a) * 2.2, sh + 0.6, sin(a) * 2.2)
		kit.cylinder("stone_dark", Transform3D(Basis(Vector3(sin(a), 0, -cos(a)), -0.18), p), 0.55, 0.0, 6.5 if i % 2 == 0 else 4.5, 4)
	kit.cylinder_at("ember", spire + Vector3(0, sh + 0.6, 0), 1.6, 0.4, 2.2, 8)
	# Дві менші вежі.
	var towers := [[Vector3(12.0, 0, -9.0), 4.0, 30.0, true], [Vector3(-11.0, 0, 10.0), 4.5, 19.0, false]]
	for t in towers:
		var p: Vector3 = t[0]
		var w: float = t[1]
		var h: float = t[2]
		kit.box_at("stone_dark", p + Vector3(0, h * 0.5, 0), Vector3(w, h, w), true)
		if bool(t[3]):
			kit.pyramid("shingle", Transform3D(Basis(), p + Vector3(0, h, 0)), w + 0.4, w + 0.4, w * 2.6)
			_lancet(kit, Transform3D(Basis(), p + Vector3(0, h * 0.75, -w * 0.5 - 0.02)), 0.6, 1.8, "window")
		else:
			for i in range(6):
				var bh := rng.randf_range(0.5, 3.0)
				kit.box_at("stone_dark", p + Vector3(rng.randf_range(-1.5, 1.5), h + bh * 0.5, rng.randf_range(-1.5, 1.5)), Vector3(1.2, bh, 1.2))
	for i in range(14):
		var a := rng.randf() * TAU
		var r := rng.randf_range(6.0, 19.0)
		var s := rng.randf_range(0.6, 2.0)
		if Vector2(cos(a) * r, sin(a) * r).distance_to(arena_flat) < arena_clear:
			continue
		kit.rock("stone_dark", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(cos(a) * r, 0, sin(a) * r)), Vector3(s * 1.5, s, s * 1.2), rng, s > 1.2)
	for key in kit._tools.keys():
		kit.set_material(key, mat(key))
	kit.build(root, "SummitRuinsMesh", 0.0)
	# Світло: пульсуюче Око-вінець (видно здалеку), теплі вікна, жаровні біля входу.
	var crown := OmniLight3D.new()
	crown.name = "EmberCrownLight"
	crown.light_color = Color("#ff4a1c")
	crown.light_energy = 6.0
	crown.omni_range = 70.0
	crown.light_volumetric_fog_energy = 2.5
	crown.position = spire + Vector3(0, sh + 3.0, 0)
	root.add_child(crown)
	root.set_meta("crown_light", crown)
	var torch_a := FlickerLight.create(Color("#ff8a3a"), 2.0, 14.0, 0.3, 7.0)
	torch_a.position = Vector3(cos(TAU * 4.0 / 36.0) * 18.0, 2.5, sin(TAU * 4.0 / 36.0) * 18.0)
	torch_a.fade_begin = 260.0
	root.add_child(torch_a)
	var window_glow := FlickerLight.create(Color("#ffb060"), 1.6, 12.0, 0.15, 3.0)
	window_glow.position = keep + Vector3(0, 6.0, -8.0)
	window_glow.fade_begin = 260.0
	root.add_child(window_glow)
	return root
