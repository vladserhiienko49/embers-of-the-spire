extends CharacterBody3D

signal stats_changed(health: float, max_health: float, stamina: float, max_stamina: float)
signal combat_message(message: String, positive: bool)
signal damaged(amount: float, blocked: bool)
## Гравець загинув: камера вже падає на землю, UI показує екран смерті.
signal died

const SWORD_SCENE: PackedScene = preload("res://sword.tscn")
const WALK_SPEED: float = 6.0
const SPRINT_SPEED: float = 11.5
const BLOCK_SPEED: float = 2.15
const JUMP_VELOCITY: float = 7.5
const MOUSE_SENSITIVITY: float = 0.003
const ATTACK_COST: float = 22.0
const SPRINT_DRAIN_PER_SECOND: float = 11.5
const BLOCK_DRAIN_PER_SECOND: float = 15.0
const STAMINA_REGEN_PER_SECOND: float = 18.0
const STAMINA_REGEN_DELAY: float = 0.85
const PARRY_WINDOW: float = 0.24

# --- Камера від першої особи (основна) / третьої (клавіша V) -----------------
const FP_EYE_HEIGHT: float = 0.62
const FP_PITCH_LIMIT_DEG: float = 82.0
# Меч у кадрі: руків'я внизу праворуч, клинок трохи вгору, вперед і вліво.
const FP_SWORD_PIVOT_POS: Vector3 = Vector3(0.64, -0.74, -1.05)
const FP_SWORD_PIVOT_ROT: Vector3 = Vector3(0.0, -10.0, 9.0)
const FP_SWORD_MODEL_POS: Vector3 = Vector3(0.0, 0.12, 0.0)
const FP_SWORD_MODEL_ROT: Vector3 = Vector3(-22.0, 0.0, 0.0)
const FP_SHIELD_REST_POS: Vector3 = Vector3(-0.62, -0.95, -0.7)
const FP_SHIELD_REST_ROT: Vector3 = Vector3(10.0, 18.0, 0.0)
const FP_SHIELD_BLOCK_POS: Vector3 = Vector3(-0.34, -0.36, -0.8)
const FP_SHIELD_BLOCK_ROT: Vector3 = Vector3(0.0, 6.0, 0.0)
const HAND_SHIELD_REST_POS: Vector3 = Vector3(-0.07, -0.04, -0.09)
const HAND_SHIELD_REST_ROT: Vector3 = Vector3(0.0, 0.0, 0.0)
const HAND_SHIELD_BLOCK_POS: Vector3 = Vector3(-0.04, -0.05, -0.1)
const HAND_SHIELD_BLOCK_ROT: Vector3 = Vector3(0.0, 0.0, 0.0)

@export var max_health: float = 100.0
@export var max_stamina: float = 100.0
@export var sword_hand_position: Vector3 = Vector3(0.0, 0.0, 0.0)
@export var sword_hand_rotation_degrees: Vector3 = Vector3(90.0, 0.0, 0.0)
@export var sword_model_offset: Vector3 = Vector3(0.0, 0.0, 0.0)
@export var sword_model_rotation_degrees: Vector3 = Vector3(-90.0, 0.0, 0.0)

var health: float = 100.0
var stamina: float = 100.0
var is_attacking: bool = false
var is_blocking: bool = false
var controls_enabled: bool = false
var _defeated: bool = false
var _death_t: float = 0.0
var _death_pitch0: float = 0.0
var _damage_invulnerability: float = 0.0
var _parry_window_left: float = 0.0
var _stamina_regen_delay: float = 0.0
var _footstep_timer: float = 0.0
var _world_ref: Node = null
var _hit_targets: Array[Node] = []
var _attack_tween: Tween = null
var _shield_pose_tween: Tween = null
var _attack_serial: int = 0
var _sword_hit_window_active: bool = false

var sword_pivot: Node3D = null
var sword_swing: Node3D = null
var sword_instance: Node3D = null
var sword_hitbox: Area3D = null
var shield_pivot: Node3D = null
var trail_instance: MeshInstance3D = null
var trail_mesh: ImmediateMesh = null
var trail_material: StandardMaterial3D = null
var _trail_active: bool = false
var _trail_samples: Array[Dictionary] = []

## Основний вигляд — від третьої особи (V перемикає на першу).
@export var first_person: bool = false
var third_person_distance: float = 6.0
var _knight_meshes: Array[MeshInstance3D] = []
var _fp_sword_pivot: Node3D = null
var _fp_shield_anchor: Node3D = null
var _hand_shield_attachment: Node3D = null
var _tp_camera_transform: Transform3D
var _tp_arm_height: float = 1.2
var _tp_hitbox_shape: Shape3D = null
var _fp_hitbox_shape: BoxShape3D = null
var _sword_hit_collision: CollisionShape3D = null
var fx: PlayerFX = null

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D
## Власний процедурний герой (HeroRig). anim_player лишено для сумісності (завжди null).
var anim_player: AnimationPlayer = null
var knight_model: Node3D = null
var hero_rig: Node3D = null
var hero_parts: Dictionary = {}
var _hero_armor: Dictionary = {}


func _ready() -> void:
	health = max_health
	stamina = max_stamina
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_hero()
	for mesh_node in knight_model.find_children("*", "MeshInstance3D", true, false):
		_knight_meshes.append(mesh_node as MeshInstance3D)
	_tp_camera_transform = camera.transform
	_tp_arm_height = spring_arm.position.y
	_attach_sword_to_right_hand()
	_attach_shield_to_left_hand()
	_dress_knight()
	_setup_third_person_camera()
	_create_first_person_rig()
	_create_sword_trail()
	fx = PlayerFX.new()
	fx.name = "PlayerFX"
	add_child(fx)
	fx.setup(self, camera)
	fx.step.connect(_on_fx_step)
	fx.landed.connect(_on_fx_landed)
	bow = BowSystem.new()
	bow.name = "BowSystem"
	add_child(bow)
	bow.setup(self, camera)
	set_first_person(first_person)
	# Герой починає з мечем у піхвах на спині; ЛКМ або R дістає його.
	weapon_drawn = false
	_finish_sheath(false)
	notify_stats()


func _create_first_person_rig() -> void:
	## Точки кріплення зброї в просторі камери: меч і щит не хитаються з анімацією.
	_fp_sword_pivot = Node3D.new()
	_fp_sword_pivot.name = "FPSwordPivot"
	_fp_sword_pivot.position = FP_SWORD_PIVOT_POS
	_fp_sword_pivot.rotation_degrees = FP_SWORD_PIVOT_ROT
	camera.add_child(_fp_sword_pivot)
	_fp_shield_anchor = Node3D.new()
	_fp_shield_anchor.name = "FPShieldAnchor"
	camera.add_child(_fp_shield_anchor)
	if sword_instance:
		_sword_hit_collision = sword_instance.get_node_or_null("SwordHitbox/CollisionShape3D") as CollisionShape3D
	if _sword_hit_collision:
		_tp_hitbox_shape = _sword_hit_collision.shape
		# Від першої особи меч ближче до камери — подовжуємо зону ураження.
		_fp_hitbox_shape = BoxShape3D.new()
		_fp_hitbox_shape.size = Vector3(0.5, 2.1, 0.5)


func set_first_person(enabled: bool) -> void:
	first_person = enabled
	_cancel_attack()
	if _sheath_t >= 0.0:
		_finish_sheath(_sheath_to_hand)
	if bow:
		bow.refresh_view()
	if sword_swing and _fp_sword_pivot and sword_pivot:
		var sword_parent: Node3D = _fp_sword_pivot if enabled else sword_pivot
		if not weapon_drawn and not enabled and _back_anchor:
			sword_parent = _back_anchor
		sword_swing.reparent(sword_parent, false)
		sword_swing.position = Vector3.ZERO
		sword_swing.rotation = Vector3.ZERO
		sword_swing.visible = weapon_drawn or not enabled
	for armor_mesh in _armor_meshes:
		if is_instance_valid(armor_mesh):
			armor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if sword_instance:
		sword_instance.position = FP_SWORD_MODEL_POS if enabled else sword_model_offset
		sword_instance.rotation_degrees = FP_SWORD_MODEL_ROT if enabled else sword_model_rotation_degrees
	if _sword_hit_collision:
		_sword_hit_collision.shape = _fp_hitbox_shape if enabled else _tp_hitbox_shape
		_sword_hit_collision.position = Vector3(0.0, 0.9 if enabled else 0.48, 0.0)
	if shield_pivot and _fp_shield_anchor and _hand_shield_attachment:
		shield_pivot.reparent(_fp_shield_anchor if enabled else _hand_shield_attachment, false)
		var rest := _shield_rest_pose(false)
		shield_pivot.position = rest[0]
		shield_pivot.rotation_degrees = rest[1]
	var face_rig := knight_model.get_node_or_null("FaceRig") as Node3D
	if face_rig:
		face_rig.visible = false # обличчя сховане під закритим шоломом
	for mesh_node in _knight_meshes:
		if is_instance_valid(mesh_node):
			mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if enabled:
		spring_arm.position.y = FP_EYE_HEIGHT
		spring_arm.spring_length = 0.0
		camera.transform = Transform3D.IDENTITY
		camera.near = 0.04
		knight_model.rotation.y = PI
		if fx:
			fx.reset_camera()
	else:
		spring_arm.position.y = _tp_arm_height
		camera.transform = _tp_camera_transform
		camera.near = 0.05
		spring_arm.rotation.x = clampf(spring_arm.rotation.x, deg_to_rad(-60.0), deg_to_rad(30.0))
	if fx:
		fx.set_first_person(enabled)


func _on_fx_landed(fall_speed: float) -> void:
	AudioManager.play_sfx("land", clampf(fall_speed / 12.0, 0.0, 1.0) * 4.0 - 6.0, 0.06)


func _on_fx_step(sprinting: bool) -> void:
	if first_person and controls_enabled and not _defeated:
		_play_footstep(sprinting)


func set_third_person_distance(distance: float) -> void:
	third_person_distance = distance


func _shield_rest_pose(blocking: bool) -> Array:
	if first_person:
		return [FP_SHIELD_BLOCK_POS, FP_SHIELD_BLOCK_ROT] if blocking else [FP_SHIELD_REST_POS, FP_SHIELD_REST_ROT]
	return [HAND_SHIELD_BLOCK_POS, HAND_SHIELD_BLOCK_ROT] if blocking else [HAND_SHIELD_REST_POS, HAND_SHIELD_REST_ROT]


func _process(delta: float) -> void:
	_update_sword_trail(delta)
	_update_sheath(delta)
	_update_shield_orient()


func _update_shield_orient() -> void:
	## Щит тримається диском уперед у просторі тіла, хоч би як рука піднімалась; під час блоку трохи розвернутий.
	if shield_pivot == null or hero_rig == null or first_person or shield_pivot.get_parent() != _hand_shield_attachment:
		return
	var yaw := deg_to_rad(-16.0) * float(hero_rig.get("guard"))
	shield_pivot.global_basis = hero_rig.global_basis * Basis(Vector3.UP, yaw)


const TP_DISTANCE: float = 4.3
const TP_ARM_HEIGHT: float = 1.35


func _setup_third_person_camera() -> void:
	## Камера позаду й трохи вище героя; пружина з колізією не дає їй залазити в стіни й скелі.
	third_person_distance = TP_DISTANCE
	spring_arm.position.y = TP_ARM_HEIGHT
	_tp_arm_height = TP_ARM_HEIGHT
	spring_arm.spring_length = TP_DISTANCE
	spring_arm.collision_mask = 1
	spring_arm.margin = 0.3
	spring_arm.add_excluded_object(get_rid())
	spring_arm.rotation.x = deg_to_rad(-8.0)
	# Легкий нахил камери вниз: герой у нижній третині кадру, видно дорогу попереду.
	_tp_camera_transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-11.0)), Vector3(0.35, 0.0, 0.0))


func notify_stats() -> void:
	stats_changed.emit(health, max_health, stamina, max_stamina)


func set_controls_enabled(enabled: bool) -> void:
	if enabled and _defeated:
		return
	controls_enabled = enabled
	if not enabled:
		# Пауза, діалог і карта не повинні залишати активний удар або хітбокс.
		_cancel_attack()
		if is_blocking:
			_end_block()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		velocity.x = 0.0
		velocity.z = 0.0
		_footstep_timer = 0.0
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _set_sword_hitbox_active(active: bool) -> void:
	_sword_hit_window_active = active
	if sword_hitbox and is_instance_valid(sword_hitbox):
		# Deferred-зміна безпечна навіть коли PhysicsServer обробляє зіткнення.
		sword_hitbox.set_deferred("monitoring", active)
		sword_hitbox.set_deferred("monitorable", active)


func _cancel_attack() -> void:
	_attack_serial += 1
	if _attack_tween and is_instance_valid(_attack_tween) and _attack_tween.is_running():
		_attack_tween.kill()
	_attack_tween = null
	is_attacking = false
	_set_sword_hitbox_active(false)
	_trail_active = false
	_trail_samples.clear()
	if sword_swing and is_instance_valid(sword_swing):
		sword_swing.rotation = Vector3.ZERO
		sword_swing.position = Vector3.ZERO
	if knight_model and is_instance_valid(knight_model):
		knight_model.rotation.x = 0.0
	if trail_mesh:
		trail_mesh.clear_surfaces()
	if trail_instance:
		trail_instance.visible = false


func _build_hero() -> void:
	## Герой збирається кодом: тіло HumanoidKit + обладунок. Стопи на висоті -0.8357 від центру капсули (як раніше).
	knight_model = Node3D.new()
	knight_model.name = "Hero"
	knight_model.position = Vector3(0.0, -0.8357, 0.0)
	knight_model.rotation.y = PI
	add_child(knight_model)
	_hero_armor = HeroRig.build(knight_model)
	hero_rig = _hero_armor["rig"]
	hero_parts = _hero_armor["parts"]


func _attach_sword_to_right_hand() -> void:
	var hand_attachment: Node3D = hero_parts.get("grip_r") as Node3D
	if hand_attachment == null:
		push_error("Герой не має правої кисті (grip_r). Меч не прикріплено.")
		return

	sword_pivot = Node3D.new()
	sword_pivot.name = "SwordPivot"
	sword_pivot.position = sword_hand_position
	sword_pivot.rotation_degrees = sword_hand_rotation_degrees
	hand_attachment.add_child(sword_pivot)

	sword_swing = Node3D.new()
	sword_swing.name = "SwordSwing"
	sword_pivot.add_child(sword_swing)

	sword_instance = SWORD_SCENE.instantiate() as Node3D
	if sword_instance == null:
		push_error("Не вдалося створити модель меча з sword.tscn.")
		return
	sword_instance.name = "Sword"
	sword_instance.position = sword_model_offset
	sword_instance.rotation_degrees = sword_model_rotation_degrees
	sword_swing.add_child(sword_instance)

	sword_hitbox = sword_instance.get_node_or_null("SwordHitbox") as Area3D
	if sword_hitbox:
		sword_hitbox.monitoring = false
		sword_hitbox.monitorable = false
		sword_hitbox.collision_layer = 0
		sword_hitbox.collision_mask = 2
		sword_hitbox.body_entered.connect(_on_sword_hitbox_body_entered)
	else:
		push_warning("У sword.tscn не знайдено SwordHitbox.")


func _attach_shield_to_left_hand() -> void:
	var attachment: Node3D = hero_parts.get("grip_l") as Node3D
	if attachment == null:
		return

	shield_pivot = Node3D.new()
	shield_pivot.name = "ShieldPivot"
	shield_pivot.position = HAND_SHIELD_REST_POS
	shield_pivot.rotation_degrees = HAND_SHIELD_REST_ROT
	attachment.add_child(shield_pivot)
	_hand_shield_attachment = attachment

	var shield_body := MeshInstance3D.new()
	shield_body.name = "ShieldBody"
	var shield_mesh := CylinderMesh.new()
	shield_mesh.top_radius = 0.39
	shield_mesh.bottom_radius = 0.34
	shield_mesh.height = 0.105
	shield_mesh.radial_segments = 8
	shield_body.mesh = shield_mesh
	shield_body.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	shield_body.position = Vector3(0.0, 0.0, -0.045)
	var shield_material := StandardMaterial3D.new()
	shield_material.albedo_color = Color("#343b45")
	shield_material.metallic = 0.84
	shield_material.roughness = 0.3
	shield_body.material_override = shield_material
	shield_pivot.add_child(shield_body)

	var rim := MeshInstance3D.new()
	rim.name = "ShieldRim"
	var rim_mesh := TorusMesh.new()
	rim_mesh.inner_radius = 0.315
	rim_mesh.outer_radius = 0.355
	rim.mesh = rim_mesh
	rim.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	rim.position = Vector3(0.0, 0.0, -0.105)
	var rim_material := StandardMaterial3D.new()
	rim_material.albedo_color = Color("#b18a4a")
	rim_material.metallic = 0.92
	rim_material.roughness = 0.2
	rim.material_override = rim_material
	shield_pivot.add_child(rim)

	var boss := MeshInstance3D.new()
	boss.name = "ShieldBoss"
	var boss_mesh := SphereMesh.new()
	boss_mesh.radius = 0.13
	boss_mesh.height = 0.22
	boss.mesh = boss_mesh
	boss.position = Vector3(0.0, 0.0, -0.12)
	var boss_material := StandardMaterial3D.new()
	boss_material.albedo_color = Color("#c39b5d")
	boss_material.metallic = 0.96
	boss_material.roughness = 0.16
	boss.material_override = boss_material
	shield_pivot.add_child(boss)

	var crest := MeshInstance3D.new()
	crest.name = "ShieldCrest"
	var crest_mesh := BoxMesh.new()
	crest_mesh.size = Vector3(0.075, 0.20, 0.025)
	crest.mesh = crest_mesh
	crest.position = Vector3(0.0, 0.0, -0.225)
	crest.material_override = boss_material
	shield_pivot.add_child(crest)


func _create_sword_trail() -> void:
	trail_mesh = ImmediateMesh.new()
	trail_material = StandardMaterial3D.new()
	trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_material.vertex_color_use_as_albedo = true
	trail_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	trail_material.albedo_color = Color(0.55, 0.78, 1.0, 0.58)
	trail_material.emission_enabled = true
	trail_material.emission = Color(0.35, 0.68, 1.0)
	trail_material.emission_energy_multiplier = 1.8

	trail_instance = MeshInstance3D.new()
	trail_instance.name = "SwordSlashTrail"
	trail_instance.mesh = trail_mesh
	trail_instance.material_override = trail_material
	trail_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail_instance.top_level = true
	add_child(trail_instance)
	trail_instance.global_transform = Transform3D.IDENTITY
	trail_instance.visible = false


func _update_sword_trail(delta: float) -> void:
	if _trail_active and sword_instance != null and is_instance_valid(sword_instance):
		var base_point := sword_instance.to_global(Vector3(0.0, 0.12, 0.0))
		var tip_point := sword_instance.to_global(Vector3(0.0, 0.98, 0.0))
		if _trail_samples.is_empty() or (base_point.distance_to(_trail_samples.back()["base"]) > 0.025):
			_trail_samples.append({"base": base_point, "tip": tip_point, "age": 0.0})

	for sample in _trail_samples:
		sample["age"] = float(sample["age"]) + delta
	while not _trail_samples.is_empty() and float(_trail_samples[0]["age"]) > 0.22:
		_trail_samples.pop_front()

	if trail_mesh == null:
		return
	trail_mesh.clear_surfaces()
	if _trail_samples.size() < 2:
		trail_instance.visible = false
		return

	trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, trail_material)
	for sample in _trail_samples:
		var alpha := clampf(1.0 - float(sample["age"]) / 0.22, 0.0, 1.0) * 0.58
		var base_position: Vector3 = sample["base"]
		var tip_position: Vector3 = sample["tip"]
		trail_mesh.surface_set_color(Color(0.68, 0.86, 1.0, alpha))
		trail_mesh.surface_add_vertex(base_position)
		trail_mesh.surface_set_color(Color(0.88, 0.96, 1.0, alpha))
		trail_mesh.surface_add_vertex(tip_position)
	trail_mesh.surface_end()
	trail_instance.visible = true


func _set_shield_pose(blocking: bool) -> Tween:
	if shield_pivot == null:
		return null
	if _shield_pose_tween and is_instance_valid(_shield_pose_tween) and _shield_pose_tween.is_running():
		_shield_pose_tween.kill()
	_shield_pose_tween = create_tween()
	_shield_pose_tween.set_trans(Tween.TRANS_QUAD)
	_shield_pose_tween.set_ease(Tween.EASE_OUT)
	var pose := _shield_rest_pose(blocking)
	var duration := 0.13 if blocking else 0.18
	if hero_rig:
		_shield_pose_tween.parallel().tween_property(hero_rig, "guard", 1.0 if blocking else 0.0, duration)
	_shield_pose_tween.tween_property(shield_pivot, "rotation_degrees", pose[1], duration)
	_shield_pose_tween.parallel().tween_property(shield_pivot, "position", pose[0], duration)
	return _shield_pose_tween


func _begin_block() -> void:
	if not controls_enabled or is_attacking or is_blocking or stamina < 3.0 or _defeated:
		return
	if bow and bow.equipped:
		return
	is_blocking = true
	# Вікно парирування почнеться лише після того, як щит підніметься.
	_parry_window_left = 0.0
	_stamina_regen_delay = STAMINA_REGEN_DELAY
	var shield_tween := _set_shield_pose(true)
	if shield_tween:
		shield_tween.finished.connect(_open_parry_window, CONNECT_ONE_SHOT)
	combat_message.emit("ЩИТ ПІДНЯТО — вчасний блок відбиває удар.", true)


func _open_parry_window() -> void:
	if is_blocking and controls_enabled and not _defeated:
		_parry_window_left = PARRY_WINDOW


func _end_block() -> void:
	if not is_blocking:
		return
	is_blocking = false
	_parry_window_left = 0.0
	_set_shield_pose(false)


func _input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventKey and (event as InputEventKey).echo:
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		spring_arm.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		if first_person:
			spring_arm.rotation.x = clampf(spring_arm.rotation.x, deg_to_rad(-FP_PITCH_LIMIT_DEG), deg_to_rad(FP_PITCH_LIMIT_DEG))
		else:
			spring_arm.rotation.x = clampf(spring_arm.rotation.x, deg_to_rad(-60.0), deg_to_rad(30.0))

	if event.is_action_pressed("toggle_view"):
		if riding:
			ride_fp = not ride_fp
		else:
			set_first_person(not first_person)
		return
	if event.is_action_pressed("toggle_light") and fx:
		fx.toggle_light()
		return

	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).physical_keycode == KEY_R:
		if bow and bow.equipped:
			bow.unequip(false)
		elif not is_attacking and not _defeated:
			set_weapon_drawn(not weapon_drawn)
		return
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).physical_keycode == KEY_B:
		if bow and not is_attacking and not _defeated and not riding:
			bow.toggle_equip()
		return

	if bow and bow.equipped:
		# З луком: ЛКМ натягує тятиву, відпускання стріляє; щит недоступний.
		if event.is_action_pressed("attack"):
			bow.begin_draw()
		elif event.is_action_released("attack"):
			bow.release()
		return

	if event.is_action_pressed("block"):
		_begin_block()
	elif event.is_action_released("block"):
		_end_block()

	if event.is_action_pressed("attack") and not is_attacking and not is_blocking:
		perform_attack()


## Лук і стріли (клавіша B): див. scripts/player/bow_system.gd.
var bow: BowSystem = null


func cancel_block() -> void:
	if is_blocking:
		_end_block()


## Меч у піхвах (R): у мирний час вільний огляд, лише факел у лівій руці.
var weapon_drawn: bool = true
var _scabbard: MeshInstance3D = null


func set_weapon_drawn(drawn: bool, silent: bool = false) -> void:
	if drawn == weapon_drawn or _sheath_t >= 0.0:
		return
	if drawn and bow and bow.equipped:
		bow.unequip(false)
	weapon_drawn = drawn
	_set_sword_hitbox_active(false)
	_start_sheath_anim(drawn)
	if not silent:
		AudioManager.play_sfx("sword_swing", -9.0, 0.12)
		combat_message.emit("Меч дістано" if drawn else "Меч сховано в піхви на спину", false)


func _update_scabbard() -> void:
	## Піхви тепер частина обладунку (на спині); від першої особи меч у піхвах не видно.
	if sword_swing and is_instance_valid(sword_swing) and _sheath_t < 0.0:
		sword_swing.visible = weapon_drawn or not first_person


# --- Меч на спині: анімація діставання / ховання -------------------------------------------------
const SHEATH_TIME: float = 0.6
var _sheath_t: float = -1.0
var _sheath_to_hand: bool = true
var _back_anchor: Node3D = null
var _reach: ArmReachModifier = null
var _armor_meshes: Array[MeshInstance3D] = []


func _dress_knight() -> void:
	## Обладунок уже зібрано разом із героєм (HeroRig/KnightArmor.dress_rig): беремо піхви на спині та деталі.
	_back_anchor = _hero_armor.get("back_anchor") as Node3D
	for attachment in _hero_armor["attachments"]:
		for m in (attachment as Node).find_children("*", "MeshInstance3D", true, false):
			_armor_meshes.append(m as MeshInstance3D)
	_reach = ArmReachModifier.new()
	_reach.name = "ArmReach"
	add_child(_reach)
	_reach.setup(hero_rig)


func _sword_hand_parent() -> Node3D:
	return _fp_sword_pivot if first_person else sword_pivot


func _start_sheath_anim(to_hand: bool) -> void:
	if sword_swing == null or not is_instance_valid(sword_swing):
		return
	if first_person or _back_anchor == null or sword_pivot == null:
		_finish_sheath(to_hand)
		return
	_sheath_to_hand = to_hand
	_sheath_t = 0.0
	if _reach:
		_reach.set_pose(ArmReachModifier.BACK_UPPER, ArmReachModifier.BACK_FORE)
	sword_swing.visible = true
	var gt := sword_swing.global_transform
	sword_swing.top_level = true
	sword_swing.global_transform = gt


func _update_sheath(delta: float) -> void:
	if _sheath_t < 0.0:
		return
	_sheath_t = minf(_sheath_t + delta / SHEATH_TIME, 1.0)
	var t := _sheath_t
	# Рука тягнеться за плече до руків'я й повертається; меч іде по дузі між спиною і долонею.
	var move_k := smoothstep(0.38, 1.0, t) if _sheath_to_hand else 1.0 - smoothstep(0.0, 0.62, t)
	if _reach:
		_reach.reach = sin(t * PI)
	if _back_anchor and sword_pivot:
		var xf := _back_anchor.global_transform.interpolate_with(sword_pivot.global_transform, move_k)
		xf.origin += Vector3.UP * sin(move_k * PI) * 0.22
		sword_swing.global_transform = xf
	if _sheath_t >= 1.0:
		_finish_sheath(_sheath_to_hand)


func _finish_sheath(to_hand: bool) -> void:
	_sheath_t = -1.0
	if _reach:
		_reach.reach = 0.0
	if sword_swing == null or not is_instance_valid(sword_swing):
		return
	sword_swing.top_level = false
	var target: Node3D = _sword_hand_parent() if to_hand else (_back_anchor if (_back_anchor and not first_person) else sword_pivot)
	if target and sword_swing.get_parent() != target:
		sword_swing.reparent(target, false)
	sword_swing.transform = Transform3D.IDENTITY
	sword_swing.scale = Vector3.ONE
	sword_swing.visible = to_hand or not first_person
	if hero_rig:
		HeroRig.apply_stance(hero_rig, to_hand)
	if to_hand and _attack_after_draw:
		_attack_after_draw = false
		perform_attack.call_deferred()
	_attack_after_draw = false


var _attack_after_draw: bool = false
var _knight_rest_y: float = NAN

# --- Верхова їзда -----------------------------------------------------------------------------------
const WALK_RIDE_SPEED: float = 4.6
const TROT_SPEED: float = 9.5
const GALLOP_SPEED: float = 17.0
const GALLOP_DRAIN: float = 13.0
const RIDE_EYE_HEIGHT: float = 1.2
const RIDE_TP_DISTANCE: float = 6.6
const RIDE_TP_HEIGHT: float = 2.0
var riding: bool = false
var ride_speed: float = 0.0
## Хід коня: idle | walk | trot | gallop. Галоп (Shift) витрачає витривалість; при нулі кінь переходить на рись.
var gait: String = "idle"
var ride_fp: bool = false           # вид від першої особи в сідлі (V)
var _ride_fp_k: float = 0.0         # плавний перехід 0..1
var _gallop_locked: bool = false
var _ride_bob_phase: float = 0.0


func set_riding(on: bool) -> void:
	riding = on
	ride_speed = 0.0
	gait = "idle"
	_gallop_locked = false
	if not on:
		_ride_fp_k = 0.0
		if knight_model:
			knight_model.visible = true
		if camera:
			camera.position = _tp_camera_transform.origin
			camera.rotation = _tp_camera_transform.basis.get_euler()
	if on:
		if first_person:
			set_first_person(false)
		if bow and bow.equipped:
			bow.unequip(false)
	if is_nan(_knight_rest_y):
		_knight_rest_y = knight_model.position.y
	if _reach:
		var tw := create_tween().set_parallel(true)
		_reach.saddle = on
		tw.tween_property(_reach, "sit", 1.0 if on else 0.0, 0.5)
		tw.tween_property(knight_model, "position:y", _knight_rest_y + (0.36 if on else 0.0), 0.5)
		if on:
			knight_model.rotation.y = PI
	# Камера далі й вище, щоб показувати вершника й коня.
	third_person_distance = RIDE_TP_DISTANCE if on else TP_DISTANCE
	spring_arm.position.y = RIDE_TP_HEIGHT if on else TP_ARM_HEIGHT
	_tp_arm_height = TP_ARM_HEIGHT


func _ride_physics(delta: float, input_dir: Vector2) -> void:
	## Керування конем: W розганяє, S гальмує, A/D — повороти корпусу, Shift — галоп, Space — стрибок.
	rotate_y(-input_dir.x * (1.9 if absf(ride_speed) > 1.0 else 1.0) * delta)
	var throttle := -input_dir.y
	var wants_gallop := Input.is_action_pressed("sprint")
	if _gallop_locked and stamina > 22.0:
		_gallop_locked = false
	var gallop := wants_gallop and not _gallop_locked and stamina > 4.0
	var slow_walk := Input.is_physical_key_pressed(KEY_CTRL)
	var target := 0.0
	gait = "idle"
	if throttle > 0.1:
		if slow_walk:
			target = WALK_RIDE_SPEED
			gait = "walk"
		elif gallop:
			target = GALLOP_SPEED
			gait = "gallop"
		else:
			target = TROT_SPEED
			gait = "trot"
	elif throttle < -0.1:
		target = -2.5
		gait = "walk"
	target *= float(get_meta("slow_mult", 1.0))
	# Галоп втомлює: витривалість спливає, коли порожня — кінь сам переходить на рись.
	if gait == "gallop" and ride_speed > 10.0:
		stamina = maxf(0.0, stamina - GALLOP_DRAIN * delta)
		_stamina_regen_delay = STAMINA_REGEN_DELAY
		if stamina <= 0.5:
			_gallop_locked = true
			combat_message.emit("Кінь захекався: рись, доки відновиться витривалість", false)
	elif _stamina_regen_delay <= 0.0:
		stamina = minf(max_stamina, stamina + STAMINA_REGEN_PER_SECOND * 0.8 * delta)
	var rate := 8.0 if absf(target) > absf(ride_speed) else 14.0
	ride_speed = move_toward(ride_speed, target, rate * delta)
	var forward := -transform.basis.z
	velocity.x = forward.x * ride_speed
	velocity.z = forward.z * ride_speed
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = 6.5
	move_and_slide()
	knight_model.rotation.y = PI
	if fx:
		fx.process_camera(delta, Vector2(input_dir.x, 0.0), gallop and ride_speed > 12.0, false, false)
	_update_ride_camera(delta)
	_update_hero_anim(false, false)
	if Engine.get_physics_frames() % 6 == 0:
		notify_stats()


func _update_hero_anim(moving: bool, sprinting: bool) -> void:
	## Стан героя → параметри процедурної анімації (ходьба, біг, стрибок, щит).
	if hero_rig == null:
		return
	var h_speed := Vector2(velocity.x, velocity.z).length()
	var airborne := not is_on_floor() and not riding
	var walk := 0.0
	if moving and not riding:
		walk = clampf(h_speed / WALK_SPEED, 0.25, 1.0) * (0.65 if is_blocking else 1.0)
	hero_rig.set("walk", walk)
	hero_rig.set("run", 1.0 if (sprinting and moving and not riding) else 0.0)
	hero_rig.set("air", 1.0 if airborne else 0.0)


func _update_ride_camera(delta: float) -> void:
	## Плавний перехід між виглядом ззаду й від першої особи (рівень голови вершника).
	var want := 1.0 if ride_fp else 0.0
	_ride_fp_k = move_toward(_ride_fp_k, want, delta * 2.2)
	var k := _ride_fp_k * _ride_fp_k * (3.0 - 2.0 * _ride_fp_k)
	third_person_distance = lerpf(RIDE_TP_DISTANCE, 0.0, k)
	spring_arm.position.y = lerpf(RIDE_TP_HEIGHT, RIDE_EYE_HEIGHT, k)
	if knight_model:
		knight_model.visible = k < 0.8
	camera.near = lerpf(0.05, 0.04, k)
	if k > 0.001:
		# Природне погойдування залежно від швидкості: вертикальний поштовх у ритмі кроку й легкий крен.
		var sp := clampf(absf(ride_speed) / GALLOP_SPEED, 0.0, 1.0)
		var rate := 5.5 + sp * 9.0
		_ride_bob_phase += rate * delta * (0.2 + 0.8 * sp)
		var bob_y := -absf(sin(_ride_bob_phase)) * (0.015 + 0.06 * sp) * k
		var bob_x := sin(_ride_bob_phase * 0.5) * 0.01 * sp * k
		camera.position = Vector3(bob_x, bob_y, 0.0)
		camera.rotation = Vector3(sin(_ride_bob_phase) * 0.006 * sp * k, 0.0, sin(_ride_bob_phase * 0.5) * 0.012 * sp * k)
	elif camera.position != _tp_camera_transform.origin:
		camera.position = _tp_camera_transform.origin
		camera.rotation = _tp_camera_transform.basis.get_euler()


func play_reach_pose(upper: Vector3, fore: Vector3, duration: float) -> void:
	## Права рука тягнеться в заданому напрямку (скелетний простір) і повертається: ягоди, кіт.
	if _reach == null:
		return
	_reach.set_pose(upper, fore)
	var tw := create_tween()
	tw.tween_property(_reach, "reach", 1.0, duration * 0.3)
	tw.tween_interval(duration * 0.4)
	tw.tween_property(_reach, "reach", 0.0, duration * 0.3)
	tw.tween_callback(func() -> void: _reach.set_pose(ArmReachModifier.BACK_UPPER, ArmReachModifier.BACK_FORE))


func set_sit_pose(on: bool) -> void:
	if _reach == null or knight_model == null:
		return
	if is_nan(_knight_rest_y):
		_knight_rest_y = knight_model.position.y
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_reach, "sit", 1.0 if on else 0.0, 0.6)
	tw.tween_property(knight_model, "position:y", _knight_rest_y - (0.52 if on else 0.0), 0.6)
	if on:
		knight_model.rotation.y = PI


func perform_attack() -> void:
	if not controls_enabled or is_attacking or is_blocking or _defeated:
		return
	if bow and bow.equipped:
		return
	if _sheath_t >= 0.0:
		return
	if not weapon_drawn:
		set_weapon_drawn(true)
		if _sheath_t >= 0.0:
			# Меч дістається зі спини — удар виконається одразу після анімації.
			_attack_after_draw = true
			return
	if stamina < ATTACK_COST:
		combat_message.emit("Недостатньо витривалості для удару.", false)
		return
	if sword_swing == null:
		combat_message.emit("Меч не прикріплений до руки.", false)
		return

	stamina = maxf(0.0, stamina - ATTACK_COST)
	_stamina_regen_delay = STAMINA_REGEN_DELAY
	notify_stats()
	is_attacking = true
	_sword_hit_window_active = false
	_hit_targets.clear()
	_trail_samples.clear()
	_trail_active = false

	_attack_serial += 1
	var attack_id := _attack_serial

	sword_swing.rotation = Vector3.ZERO
	sword_swing.position = Vector3.ZERO
	_attack_tween = create_tween()
	_attack_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)

	# Від третьої особи — горизонтальний мах рукою; від першої — діагональний удар
	# справа-згори вліво-донизу в просторі камери.
	var windup_rot := Vector3(-6.0, -14.0, 8.0)
	var windup_pos := Vector3(0.0, 0.0, 0.0)
	var strike_rot := Vector3(4.0, 18.0, -6.0)
	var strike_pos := Vector3(0.0, 0.0, 0.0)
	if hero_rig and not first_person:
		hero_rig.call("start_attack", 0.16)
	if first_person:
		windup_rot = Vector3(26.0, -34.0, -40.0)
		windup_pos = Vector3(0.06, 0.1, 0.0)
		strike_rot = Vector3(-50.0, 56.0, 34.0)
		strike_pos = Vector3(-0.24, -0.1, -0.18)

	# Підготовка: лицар відводить меч назад і трохи переносить вагу.
	_attack_tween.tween_property(
		sword_swing,
		"rotation_degrees",
		windup_rot,
		0.16
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_attack_tween.parallel().tween_property(
		sword_swing,
		"position",
		windup_pos,
		0.16
	)
	_attack_tween.parallel().tween_property(
		knight_model,
		"rotation_degrees:x",
		-3.0,
		0.16
	)

	# Активуємо шкоду та слід лише на час реального проходження клинка.
	_attack_tween.tween_callback(_activate_sword_hit_window.bind(attack_id))
	_attack_tween.tween_property(
		sword_swing,
		"rotation_degrees",
		strike_rot,
		0.22
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_attack_tween.parallel().tween_property(
		sword_swing,
		"position",
		strike_pos,
		0.22
	)
	_attack_tween.parallel().tween_property(
		knight_model,
		"rotation_degrees:x",
		2.0,
		0.22
	)
	_attack_tween.tween_callback(_deactivate_sword_hit_window.bind(attack_id))

	# Відновлення бойової стійки.
	_attack_tween.tween_property(
		sword_swing,
		"rotation_degrees",
		Vector3.ZERO,
		0.21
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_attack_tween.parallel().tween_property(
		sword_swing,
		"position",
		Vector3.ZERO,
		0.21
	)
	_attack_tween.parallel().tween_property(
		knight_model,
		"rotation_degrees:x",
		0.0,
		0.21
	)
	_attack_tween.tween_callback(_finish_attack.bind(attack_id))


func _activate_sword_hit_window(attack_id: int) -> void:
	if attack_id != _attack_serial or not controls_enabled or not is_attacking:
		return
	_set_sword_hitbox_active(true)
	_trail_active = true
	if fx:
		fx.on_swing()
	AudioManager.play_sfx("sword_swing", -2.5, 0.07)


func _deactivate_sword_hit_window(attack_id: int) -> void:
	if attack_id != _attack_serial:
		return
	_set_sword_hitbox_active(false)
	_trail_active = false


func _finish_attack(attack_id: int) -> void:
	if attack_id != _attack_serial:
		return
	_set_sword_hitbox_active(false)
	_trail_active = false
	is_attacking = false
	_attack_tween = null
	if sword_swing:
		sword_swing.rotation = Vector3.ZERO
		sword_swing.position = Vector3.ZERO
	if knight_model:
		knight_model.rotation.x = 0.0
	notify_stats()


func _on_sword_hitbox_body_entered(body: Node3D) -> void:
	if not is_attacking or not _sword_hit_window_active or body == self or body in _hit_targets:
		return
	if not body.is_in_group("hostile"):
		return
	_hit_targets.append(body)
	var damage := 36.0 + 9.0 * float(int(get_meta("sword_level", 0)))
	if bool(get_meta("weapon_tempered", false)):
		damage += 12.0
	if body.has_method("take_damage"):
		body.call("take_damage", damage, self)
		if fx:
			fx.on_hit(body.global_position + Vector3(0.0, 1.1, 0.0))
		AudioManager.play_sfx("hit_flesh", 0.0, 0.08)
		combat_message.emit("УДАР!  -%d" % int(damage), true)


func take_damage(amount: float, attacker: Node = null) -> void:
	if _defeated or _damage_invulnerability > 0.0:
		return
	var incoming := maxf(amount, 0.0)

	if is_blocking and stamina > 0.0:
		if _parry_window_left > 0.0:
			_parry_window_left = 0.0
			stamina = minf(max_stamina, stamina + 9.0)
			_damage_invulnerability = 0.5
			if attacker and attacker.has_method("receive_parry"):
				attacker.call("receive_parry", self)
			AudioManager.play_sfx("parry_ring", -1.0, 0.04)
			if hero_rig:
				var bash_tw := create_tween()
				bash_tw.tween_property(hero_rig, "bash", 1.0, 0.07)
				bash_tw.tween_property(hero_rig, "bash", 0.0, 0.25)
			combat_message.emit("ІДЕАЛЬНЕ ПАРИРУВАННЯ! Ворог втратив рівновагу.", true)
			if fx:
				fx.on_block(_shield_world_point(), true)
			notify_stats()
			return

		# Звичайний блок поглинає більшу частину шкоди, але витрачає витривалість.
		stamina = maxf(0.0, stamina - incoming * 0.85)
		incoming *= 0.28
		if fx:
			fx.on_block(_shield_world_point(), false)
		damaged.emit(incoming, true)
		_stamina_regen_delay = STAMINA_REGEN_DELAY
		_damage_invulnerability = 0.16
		AudioManager.play_sfx("block_thud", -2.0, 0.06)
		if hero_rig:
			hero_rig.call("hit_react", 0.35)
		if stamina <= 0.0:
			_end_block()
			combat_message.emit("ЩИТ ПРОБИТО! Витривалість вичерпана.", false)
	else:
		incoming *= 1.0 if not bool(get_meta("mage_ward", false)) else 0.82
		var armor_mul := (1.0 - 0.07 * float(int(get_meta("armor_level", 0)))) * float([1.0, 0.88, 0.76, 0.62][clampi(int(get_meta("armor_set", 0)), 0, 3)])
		incoming *= maxf(0.32, armor_mul)
		if fx:
			fx.on_damaged()
		if hero_rig:
			hero_rig.call("hit_react", clampf(incoming / 22.0, 0.5, 1.4))
		AudioManager.play_hurt_voice()
		damaged.emit(incoming, false)

	health = maxf(0.0, health - incoming)
	_damage_invulnerability = maxf(_damage_invulnerability, 0.55)
	_stamina_regen_delay = STAMINA_REGEN_DELAY
	notify_stats()
	if health <= 0.0:
		_handle_defeat()


func _shield_world_point() -> Vector3:
	if first_person:
		return camera.global_transform * Vector3(-0.25, -0.2, -0.9)
	return global_position + Vector3(0.0, 1.2, 0.0) - global_transform.basis.z * 0.6


func _handle_defeat() -> void:
	if _defeated:
		return
	_defeated = true
	if bow:
		bow.cancel()
	_death_t = 0.0
	_death_pitch0 = spring_arm.rotation.x
	_cancel_attack()
	set_controls_enabled(false)
	velocity = Vector3.ZERO
	AudioManager.play_hurt_voice()
	combat_message.emit("Ти впав у бою…", false)
	if not first_person and knight_model:
		var fall := create_tween()
		fall.tween_property(knight_model, "rotation_degrees:x", -88.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(1.7).timeout
	if is_inside_tree() and _defeated:
		died.emit()


func _update_death_cam(delta: float) -> void:
	## Камера падає: опускається до землі, дивиться в небо й хилиться набік.
	_death_t += delta
	var k := clampf(_death_t / 1.3, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - k, 3.0)
	if first_person:
		spring_arm.position.y = lerpf(FP_EYE_HEIGHT, 0.16, e)
		spring_arm.rotation.x = lerpf(_death_pitch0, deg_to_rad(-34.0), e)
		camera.position = Vector3.ZERO
	else:
		spring_arm.position.y = lerpf(_tp_arm_height, 0.5, e)
		spring_arm.rotation.x = lerpf(_death_pitch0, deg_to_rad(-20.0), e)
	camera.rotation = Vector3(0.0, 0.0, deg_to_rad(42.0) * e)


func is_defeated() -> bool:
	return _defeated


func respawn_at(world_position: Vector3) -> void:
	## Відродження біля вогнища: повертає камеру, здоров'я та керування (керування вмикає UI).
	_defeated = false
	health = max_health * 0.7
	stamina = max_stamina
	_damage_invulnerability = 2.5
	global_position = world_position
	velocity = Vector3.ZERO
	spring_arm.rotation.x = 0.0
	if knight_model:
		knight_model.rotation.x = 0.0
	camera.rotation = Vector3.ZERO
	set_first_person(first_person)
	notify_stats()


func heal(amount: float) -> void:
	health = minf(max_health, health + amount)
	notify_stats()


func grant_invulnerability(seconds: float) -> void:
	_damage_invulnerability = maxf(_damage_invulnerability, seconds)

func _play_footstep(sprinting: bool) -> void:
	if _world_ref == null and get_parent():
		_world_ref = get_parent().get_node_or_null("WorldGenerator")
	var surface := "grass"
	if _world_ref and _world_ref.has_method("get_surface_type"):
		surface = str(_world_ref.call("get_surface_type", global_position))
	AudioManager.play_footstep(surface, sprinting)


func _physics_process(delta: float) -> void:
	if not first_person:
		spring_arm.spring_length = move_toward(spring_arm.spring_length, third_person_distance, delta * 24.0)
	if _parry_window_left > 0.0:
		_parry_window_left = maxf(0.0, _parry_window_left - delta)
	if _stamina_regen_delay > 0.0:
		_stamina_regen_delay = maxf(0.0, _stamina_regen_delay - delta)
	if _damage_invulnerability > 0.0:
		_damage_invulnerability = maxf(0.0, _damage_invulnerability - delta)

	if not is_on_floor():
		velocity += get_gravity() * 1.5 * delta

	if not controls_enabled or _defeated:
		velocity.x = move_toward(velocity.x, 0.0, WALK_SPEED * 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, WALK_SPEED * 10.0 * delta)
		move_and_slide()
		if _defeated:
			_update_death_cam(delta)
			return
		if fx:
			fx.process_camera(delta, Vector2.ZERO, false, first_person, false)
		return

	if riding:
		_ride_physics(delta, Input.get_vector("move_left", "move_right", "move_forward", "move_back"))
		return

	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not is_blocking:
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var is_moving := direction.length_squared() > 0.001
	var wants_sprint := Input.is_action_pressed("sprint") and not is_blocking and not is_attacking
	var is_sprinting := wants_sprint and is_moving and stamina > 1.0
	var current_speed := (BLOCK_SPEED if is_blocking else (SPRINT_SPEED if is_sprinting else WALK_SPEED)) * float(get_meta("slow_mult", 1.0))
	if bow and bow.is_drawing():
		current_speed = minf(current_speed, 3.4)

	if is_sprinting:
		stamina = maxf(0.0, stamina - SPRINT_DRAIN_PER_SECOND * delta)
		_stamina_regen_delay = STAMINA_REGEN_DELAY
	elif is_blocking:
		stamina = maxf(0.0, stamina - BLOCK_DRAIN_PER_SECOND * delta)
		_stamina_regen_delay = STAMINA_REGEN_DELAY
		if stamina <= 0.0:
			_end_block()
	elif not is_attacking and _stamina_regen_delay <= 0.0:
		stamina = minf(max_stamina, stamina + STAMINA_REGEN_PER_SECOND * delta)

	if is_moving:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		var target_angle := PI if first_person else atan2(input_dir.x, input_dir.y)
		knight_model.rotation.y = lerp_angle(knight_model.rotation.y, target_angle, delta * 10.0)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()
	if fx:
		fx.process_camera(delta, input_dir, is_sprinting, first_person, is_blocking)

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if not first_person and is_on_floor() and horizontal_speed > 1.0:
		_footstep_timer -= delta
		if _footstep_timer <= 0.0:
			_play_footstep(is_sprinting)
			_footstep_timer = 0.32 if is_sprinting else 0.47
	else:
		_footstep_timer = minf(_footstep_timer, 0.08)

	_update_hero_anim(is_moving, is_sprinting)

	# Надсилаємо оновлення HUD лише коли значення реально змінилися.
	if Engine.get_physics_frames() % 6 == 0:
		notify_stats()
