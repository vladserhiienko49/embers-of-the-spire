class_name PlayerFX
extends Node
## Відчуття від першої особи для лицаря Embers of the Spire:
## • погойдування камери (кроки синхронізовані зі звуком), нахил при стрейфі, «присідання» при приземленні;
## • FOV-кік під час бігу, легке дихання в спокої;
## • тряска камери (trauma), hit-stop, іскри/попіл при ударі та блоці;
## • факел або ліхтар у лівій руці (F), з мерехтливим світлом і тінями.

signal step(sprinting: bool)
signal landed(fall_speed: float)

const BASE_FOV: float = 72.0
const SPRINT_FOV: float = 79.0
const BOB_RATE: float = 1.05          # радіан фази на метр
const BOB_VERTICAL: float = 0.045
const BOB_HORIZONTAL: float = 0.028
const STRAFE_ROLL_DEG: float = 1.6
const HAND_REST: Vector3 = Vector3(-0.52, -0.6, -1.05)
const HAND_HIDDEN: Vector3 = Vector3(-0.5, -1.25, -0.7)

var player: CharacterBody3D
var camera: Camera3D

var _phase: float = 0.0
var _step_index: int = 0
var _bob_amount: float = 0.0
var _roll: float = 0.0
var _land_offset: float = 0.0
var _was_on_floor: bool = true
var _last_fall_speed: float = 0.0
var _time: float = 0.0
var _trauma: float = 0.0
var _noise: FastNoiseLite
var _hit_stop_active: bool = false

var light_enabled: bool = true
var light_kind: String = "torch"
var _hand: Node3D
var _hand_model: Node3D
var _flame: Node3D
var _light: OmniLight3D
var _embers: GPUParticles3D
var _light_base_energy: float = 1.9
var _light_flicker: float = 0.25
var _hand_target: Vector3 = HAND_REST


func setup(owner_player: CharacterBody3D, owner_camera: Camera3D) -> void:
	player = owner_player
	camera = owner_camera
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 1.0
	_hand = Node3D.new()
	_hand.name = "FPLightHand"
	_hand.position = HAND_REST
	camera.add_child(_hand)
	_light = OmniLight3D.new()
	_light.name = "HandLight"
	_light.shadow_enabled = true
	_light.shadow_bias = 0.08
	_light.omni_attenuation = 1.3
	_light.light_volumetric_fog_energy = 1.2
	_embers = _make_embers()
	_build_light_model("torch")
	if not QuestManager.item_added.is_connected(_on_item_added):
		QuestManager.item_added.connect(_on_item_added)


# --- Факел / ліхтар ---------------------------------------------------------------

func _build_light_model(kind: String) -> void:
	light_kind = kind
	if _hand_model:
		_hand_model.queue_free()
	_hand_model = Node3D.new()
	_hand_model.name = "Model"
	_hand.add_child(_hand_model)
	var kit := MeshKit.new()
	var flame_kit := MeshKit.new()
	var flame_pos: Vector3
	if kind == "lantern":
		# Ліхтар Ореста: кована рамка, скло, кільце для руки.
		kit.box_at("wood", Vector3(0, -0.12, 0), Vector3(0.05, 0.22, 0.05))
		kit.cylinder_at("iron", Vector3(0, 0.0, 0), 0.11, 0.11, 0.025, 8)
		for corner in [Vector3(-0.08, 0, -0.08), Vector3(0.08, 0, -0.08), Vector3(-0.08, 0, 0.08), Vector3(0.08, 0, 0.08)]:
			kit.box_at("iron", corner + Vector3(0, 0.12, 0), Vector3(0.018, 0.24, 0.018))
		kit.pyramid("iron", Transform3D(Basis(), Vector3(0, 0.24, 0)), 0.22, 0.22, 0.09)
		kit.cylinder_at("iron", Vector3(0, 0.36, 0), 0.04, 0.04, 0.012, 8, false, Vector3(PI * 0.5, 0, 0))
		flame_kit.box_at("glass", Vector3(0, 0.12, 0), Vector3(0.14, 0.2, 0.14))
		flame_kit.set_material("glass", PSXMaterials.make(Color("#ffd28a"), 0.0, 0.3, Color("#ffb050"), 3.5, "none", false))
		flame_pos = Vector3(0, 0.12, 0)
		_light.light_color = Color("#ffc47e")
		_light_base_energy = 2.4
		_light.omni_range = 15.0
		_light_flicker = 0.06
		_hand_model.rotation_degrees = Vector3(0, 0, 0)
	else:
		# Простий факел: держак, просмолена ганчірка, полум'я.
		kit.cylinder_at("wood", Vector3(0, -0.36, 0), 0.026, 0.032, 0.5, 6)
		kit.cylinder_at("cloth_black", Vector3(0, 0.12, 0), 0.045, 0.052, 0.1, 6)
		flame_kit.cylinder_at("flame", Vector3(0, 0.21, 0), 0.05, 0.0, 0.15, 5)
		flame_kit.cylinder_at("flame_core", Vector3(0, 0.215, 0), 0.028, 0.0, 0.09, 4)
		flame_kit.set_material("flame", PSXMaterials.make(Color("#ff7a28"), 0.0, 0.3, Color("#ff4a10"), 4.0, "none", false))
		flame_kit.set_material("flame_core", PSXMaterials.make(Color("#ffd27a"), 0.0, 0.3, Color("#ffc060"), 5.0, "none", false))
		flame_pos = Vector3(0, 0.26, 0)
		_light.light_color = Color("#ff8f42")
		_light_base_energy = 1.9
		_light.omni_range = 11.0
		_light_flicker = 0.25
		_hand_model.rotation_degrees = Vector3(-8, 0, 14)
	for key in kit._tools.keys():
		if not kit.has_material(key):
			kit.set_material(key, PSXMaterials.make(Color(str(BuildingKit.MAT_DEFS[key][0])), float(BuildingKit.MAT_DEFS[key][1]), 0.9, Color.BLACK, 0.0, str(BuildingKit.MAT_DEFS[key][5]), false))
	var body := kit.build(_hand_model, "Body")
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flame = flame_kit.build(_hand_model, "Flame")
	(_flame as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _light.get_parent():
		_light.get_parent().remove_child(_light)
	if _embers.get_parent():
		_embers.get_parent().remove_child(_embers)
	_hand_model.add_child(_light)
	_light.position = flame_pos + Vector3(0.05, 0.05, 0.1)
	_hand_model.add_child(_embers)
	_embers.position = flame_pos
	_embers.emitting = kind == "torch"
	_apply_light_state()


func _make_embers() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "Embers"
	particles.amount = 10
	particles.lifetime = 0.9
	particles.local_coords = false
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, 1, 0)
	process.spread = 25.0
	process.initial_velocity_min = 0.4
	process.initial_velocity_max = 1.0
	process.gravity = Vector3(0, 0.6, 0)
	process.scale_min = 0.6
	process.scale_max = 1.0
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.75, 0.3, 1.0))
	gradient.set_color(1, Color(1.0, 0.3, 0.05, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	particles.process_material = process
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.015, 0.015, 0.015)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	particles.draw_pass_1 = mesh
	return particles


func toggle_light() -> void:
	light_enabled = not light_enabled
	AudioManager.play_sfx("torch_on" if light_enabled else "torch_off", -3.0, 0.04)
	_apply_light_state()


func _apply_light_state() -> void:
	if _hand == null:
		return
	_light.visible = light_enabled
	_hand_model.visible = light_enabled
	_embers.emitting = light_enabled and light_kind == "torch"


func set_first_person(enabled: bool) -> void:
	## Від першої особи світло в руці, від третьої — над плечем лицаря.
	if _light == null:
		return
	_hand.visible = enabled
	_light.get_parent().remove_child(_light)
	if enabled:
		_hand_model.add_child(_light)
		_light.position = Vector3(0.05, 0.4, 0.1)
	else:
		player.add_child(_light)
		_light.position = Vector3(-0.45, 1.1, -0.35)
	_light.visible = light_enabled


func _on_item_added(item_id: String, _item_name: String, _total: int) -> void:
	if item_id == "orest_lantern":
		_build_light_model("lantern")
		light_enabled = true
		_apply_light_state()
		set_first_person(bool(player.get("first_person")))


# --- Камера ----------------------------------------------------------------------

func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func process_camera(delta: float, input_dir: Vector2, sprinting: bool, first_person: bool, blocking: bool) -> void:
	_time += delta
	var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length()
	var on_floor := player.is_on_floor()

	# Приземлення: камера коротко «осідає».
	if on_floor and not _was_on_floor and _last_fall_speed > 4.0:
		_land_offset = -clampf(_last_fall_speed / 40.0, 0.05, 0.18)
		add_trauma(clampf(_last_fall_speed / 60.0, 0.0, 0.25))
		landed.emit(_last_fall_speed)
	if not on_floor:
		_last_fall_speed = maxf(0.0, -player.velocity.y)
	_was_on_floor = on_floor
	_land_offset = move_toward(_land_offset, 0.0, delta * 0.6)

	# Погойдування від кроків.
	var moving := on_floor and horizontal_speed > 0.8
	_bob_amount = move_toward(_bob_amount, clampf(horizontal_speed / 6.0, 0.0, 1.6) if moving else 0.0, delta * 4.0)
	if moving:
		_phase += horizontal_speed * BOB_RATE * delta
		var index := int(floor((_phase + PI * 0.5) / PI))
		if index != _step_index:
			_step_index = index
			step.emit(sprinting)
	var bob_y := -absf(sin(_phase)) * BOB_VERTICAL * _bob_amount
	var bob_x := sin(_phase) * BOB_HORIZONTAL * _bob_amount
	var breath := sin(_time * 1.7) * 0.006 * (1.0 - clampf(_bob_amount, 0.0, 1.0))
	_roll = lerpf(_roll, deg_to_rad(-input_dir.x * STRAFE_ROLL_DEG) + sin(_phase) * deg_to_rad(0.35) * _bob_amount, delta * 8.0)

	# Тряска (trauma²) — плавний шум, не випадковий стрибок.
	_trauma = maxf(0.0, _trauma - delta * 1.7)
	var shake := _trauma * _trauma
	var shake_rot := Vector3(
		_noise.get_noise_2d(_time * 28.0, 1.0),
		_noise.get_noise_2d(_time * 28.0, 50.0),
		_noise.get_noise_2d(_time * 28.0, 99.0)
	) * shake * deg_to_rad(4.0)

	if first_person:
		camera.position = Vector3(bob_x, bob_y + breath + _land_offset, 0.0)
		camera.rotation = Vector3(shake_rot.x, shake_rot.y, _roll + shake_rot.z)
		var target_fov := SPRINT_FOV if (sprinting and horizontal_speed > 7.0) else BASE_FOV
		camera.fov = lerpf(camera.fov, target_fov, delta * 6.0)
	else:
		camera.h_offset = shake_rot.y * 3.0
		camera.v_offset = shake_rot.x * 3.0
		camera.fov = lerpf(camera.fov, BASE_FOV, delta * 6.0)

	# Рука зі світлом опускається, коли піднято щит.
	_hand_target = HAND_HIDDEN if blocking else HAND_REST
	_hand.position = _hand.position.lerp(_hand_target, delta * 10.0)
	if _light.visible:
		var n := _noise.get_noise_2d(_time * 7.0, 300.0)
		_light.light_energy = _light_base_energy * (1.0 + n * _light_flicker)
		if _flame and light_kind == "torch":
			_flame.scale = Vector3(1.0, 1.0 + n * 0.25, 1.0)


func reset_camera() -> void:
	camera.h_offset = 0.0
	camera.v_offset = 0.0


# --- Бойовий фідбек ----------------------------------------------------------------

func on_swing() -> void:
	add_trauma(0.1)


func on_hit(world_position: Vector3) -> void:
	add_trauma(0.38)
	_burst(world_position, Color(0.85, 0.2, 0.12), Color(0.25, 0.22, 0.24), 26)
	hit_stop(0.065, 0.04)


func on_block(world_position: Vector3, parried: bool) -> void:
	if parried:
		add_trauma(0.42)
		_burst(world_position, Color(1.0, 0.92, 0.6), Color(1.0, 0.6, 0.2), 34)
		hit_stop(0.11, 0.03)
	else:
		add_trauma(0.24)
		_burst(world_position, Color(1.0, 0.75, 0.35), Color(0.6, 0.3, 0.1), 16)


func on_damaged() -> void:
	add_trauma(0.55)


func hit_stop(duration: float, time_scale: float) -> void:
	if _hit_stop_active:
		return
	_hit_stop_active = true
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hit_stop_active = false


func _burst(world_position: Vector3, color_a: Color, color_b: Color, amount: int) -> void:
	## Короткий сплеск іскор/попелу у точці удару.
	var particles := GPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = amount
	particles.lifetime = 0.55
	particles.local_coords = false
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, 1, 0)
	process.spread = 75.0
	process.initial_velocity_min = 2.0
	process.initial_velocity_max = 5.5
	process.gravity = Vector3(0, -9.0, 0)
	process.scale_min = 0.6
	process.scale_max = 1.4
	var gradient := Gradient.new()
	gradient.set_color(0, color_a)
	gradient.set_color(1, Color(color_b, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	particles.process_material = process
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.045, 0.045, 0.045)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	particles.draw_pass_1 = mesh
	get_tree().current_scene.add_child(particles)
	particles.global_position = world_position
	particles.emitting = true
	var flash := OmniLight3D.new()
	flash.light_color = color_a
	flash.light_energy = 2.5
	flash.omni_range = 4.0
	get_tree().current_scene.add_child(flash)
	flash.global_position = world_position
	var tween := flash.create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(flash, "light_energy", 0.0, 0.18)
	tween.tween_callback(flash.queue_free)
	get_tree().create_timer(1.2, true, false, true).timeout.connect(particles.queue_free)
