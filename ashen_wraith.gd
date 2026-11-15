extends CharacterBody3D

@export var max_health: float = 92.0
@export var move_speed: float = 2.35
@export var detection_range: float = 18.0
@export var attack_range: float = 2.5
@export var attack_damage: float = 17.0

## Нагорода монетами за перемогу та предмет (уламок Печатки), що випадає з міні-боса.
const COIN_REWARDS: Dictionary = {
	"ashen_wraith": 3, "tower_guardian": 15, "ash_knight": 40, "necromancer": 55,
	"citadel_guardian": 70, "eye_guardian": 100,
	"skeleton": 2, "skirmisher": 6, "bone_knight": 28, "bone_seer": 14, "skeleton_witch": 70, "ancient_mage": 120,
}
const DROPS: Dictionary = {
	"ash_knight": ["seal_fragment_1", "Уламок Печатки I"],
	"necromancer": ["seal_fragment_2", "Уламок Печатки II"],
	"citadel_guardian": ["seal_fragment_3", "Уламок Печатки III"],
	"skeleton_witch": ["witch_skull_staff", "Череп-посох Кістяної Вдови"],
	"ancient_mage": ["frost_core", "Крижане Серце Мага"],
}

var health: float = 92.0
var target: CharacterBody3D = null
var attack_cooldown: float = 1.1
var attack_windup: float = 0.0
var stagger_timer: float = 0.0
var dead: bool = false
var _rig: Node3D
var _collision_shape: CollisionShape3D
var _name_plate: Marker3D
var _aggro: bool = false
var _last_hit_dir: Vector3 = Vector3.ZERO
## Тип ворога для цілей квестів та підпис над головою.
var enemy_type: String = "ashen_wraith"
var display_name: String = "ПОПЕЛЯНИЙ ВАРТОВИЙ"
## Інший вигляд (напр. «enemy_knight») без зміни типу для квестів; і власна нагорода в монетах.
var visual_type: String = ""
var reward_override: int = -1
## Окрема поведінка нових ворогів (див. scripts/world/enemy_brain.gd): skeleton_witch, skirmisher, bone_knight, bone_seer.
var brain_kind: String = ""
## Груповий бій (MassBattle): поки squad_engage = false, ворог не лізе у ближній бій,
## а займає позицію squad_goal (обхід із флангу або тримається позаду).
var squad_mode: bool = false
var squad_engage: bool = true
var squad_goal: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group("hostile")
	collision_layer = 2
	collision_mask = 1
	health = max_health
	_create_visuals()
	if brain_kind != "" and _brain == null and get_parent():
		var brain := EnemyBrain.new()
		brain.name = "EnemyBrain"
		add_child(brain)
		brain.setup(self, get_parent(), brain_kind)
		_brain = brain


func set_target(value: CharacterBody3D) -> void:
	target = value


func _create_visuals() -> void:
	_collision_shape = CollisionShape3D.new()
	_collision_shape.name = "WraithCollision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.43
	capsule.height = 1.92
	_collision_shape.shape = capsule
	_collision_shape.position = Vector3(0.0, 0.96, 0.0)
	add_child(_collision_shape)

	var spec := HumanoidKit.spec_for_enemy(visual_type if visual_type != "" else enemy_type)
	spec["scale"] = 1.0  # масштаб задає сам вузол (scale у props), щоб колайдер росте разом із тілом
	_rig = HumanoidKit.build(self, spec)

	_name_plate = Marker3D.new()
	_name_plate.name = "NameTag"
	_name_plate.position = Vector3(0.0, 2.2, 0.0)
	_name_plate.set_meta("title", display_name)
	_name_plate.set_meta("color", Color("#e0765f"))
	_name_plate.set_meta("range", 14.0)
	_name_plate.add_to_group("nameplate")
	add_child(_name_plate)

	var glow := OmniLight3D.new()
	glow.name = "WraithCoreLight"
	glow.position = Vector3(0.0, 1.5, -0.3)
	glow.light_color = Color(str(spec.get("glow", "#b52c25")))
	glow.light_energy = 0.7
	glow.omni_range = 4.5
	glow.shadow_enabled = false
	add_child(glow)


## Окремий «мозок» для фінального боса (EyeBossBrain): фази, телепорти, спецатаки.
var _brain: Node = null


func _physics_process(delta: float) -> void:
	if dead:
		return
	if _brain:
		attack_cooldown = maxf(0.0, attack_cooldown - delta)
		stagger_timer = maxf(0.0, stagger_timer - delta)
		_brain.call("tick", delta)
		return
	if not is_on_floor():
		velocity += get_gravity() * delta
	if _rig:
		_rig.set("walk", clampf(Vector2(velocity.x, velocity.z).length() / maxf(move_speed, 0.1), 0.0, 1.0))

	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	stagger_timer = maxf(0.0, stagger_timer - delta)

	if target == null or not is_instance_valid(target):
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 4.0)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 4.0)
		move_and_slide()
		return

	# Вороги також завмирають у меню паузи, діалогах та на повній карті.
	if not bool(target.get("controls_enabled")):
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 5.0)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 5.0)
		move_and_slide()
		return

	var to_target := target.global_position - global_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance <= detection_range and not _aggro:
		_aggro = true
		AudioManager.play_sfx_3d("wraith_growl", global_position + Vector3(0.0, 1.5, 0.0), 2.0, 48.0, 7.0)
	elif distance > detection_range * 1.6:
		_aggro = false
	if distance > 0.08 and distance <= detection_range:
		look_at(Vector3(target.global_position.x, global_position.y, target.global_position.z), Vector3.UP)

	if stagger_timer > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 5.0)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 5.0)
		move_and_slide()
		return

	if attack_windup > 0.0:
		attack_windup -= delta
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 5.0)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 5.0)
		if attack_windup <= 0.0:
			if is_instance_valid(target) and global_position.distance_to(target.global_position) <= (attack_range + 0.7) * scale.x:
				if target.has_method("take_damage"):
					target.call("take_damage", attack_damage, self)
			attack_cooldown = 1.65
		move_and_slide()
		return

	if squad_mode and not squad_engage:
		var to_goal := squad_goal - global_position
		to_goal.y = 0.0
		if to_goal.length() > 1.2:
			var step_dir := to_goal.normalized()
			velocity.x = step_dir.x * move_speed * 0.92
			velocity.z = step_dir.z * move_speed * 0.92
		else:
			velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 5.0)
			velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 5.0)
		if distance > 0.08:
			look_at(Vector3(target.global_position.x, global_position.y, target.global_position.z), Vector3.UP)
		move_and_slide()
		return

	if distance <= attack_range * scale.x and attack_cooldown <= 0.0:
		attack_windup = 0.58
		if _rig:
			_rig.call("start_attack", 0.58)
		AudioManager.play_sfx_3d("wraith_swing", global_position + Vector3(0.0, 1.3, 0.0), 0.0, 36.0, 6.0)
		return

	if distance < detection_range and distance > attack_range * scale.x * 0.78:
		var direction := to_target.normalized()
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 5.0)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 5.0)
	move_and_slide()


func take_damage(amount: float, source: Node = null) -> void:
	if dead:
		return
	if _brain and bool(_brain.get("invulnerable")):
		return
	if _brain and _brain.has_method("modify_damage"):
		amount = float(_brain.call("modify_damage", amount))
	# Місячна лінза (нагорода місії «Згаслий Маяк») посилює удари по породженнях Ока.
	if enemy_type in ["eye_guardian", "citadel_guardian", "necromancer", "ash_knight"] and QuestManager.has_item("moon_lens"):
		amount *= 1.25
	health = maxf(0.0, health - maxf(amount, 0.0))
	if health > 0.0:
		AudioManager.play_sfx_3d("wraith_hurt", global_position + Vector3(0.0, 1.4, 0.0), 0.0, 40.0, 6.0)
	# Звичайний удар перериває підготовку атаки й відштовхує ворога.
	attack_windup = 0.0
	if _rig:
		_rig.call("cancel_attack")
	stagger_timer = maxf(stagger_timer, 0.22)
	if source is Node3D:
		var away := global_position - (source as Node3D).global_position
		away.y = 0.0
		if away.length_squared() > 0.001:
			away = away.normalized()
			_last_hit_dir = away
			velocity.x = away.x * 3.4
			velocity.z = away.z * 3.4
	if _rig:
		var flash := create_tween()
		flash.tween_method(_set_hit_flash, 1.6, 0.0, 0.22)
	if health <= 0.0:
		_die()


func _set_hit_flash(energy: float) -> void:
	if _rig and is_instance_valid(_rig):
		_rig.call("flash", energy)


func receive_parry(source: Node = null) -> void:
	if dead:
		return
	stagger_timer = 1.25
	attack_windup = 0.0
	attack_cooldown = 1.2
	if source is Node3D:
		var away := (global_position - (source as Node3D).global_position).normalized()
		velocity.x = away.x * 5.0
		velocity.z = away.z * 5.0
	if _rig:
		_rig.call("cancel_attack")


func _die() -> void:
	dead = true
	if _brain:
		_brain.call("cleanup")
	AudioManager.play_sfx_3d("wraith_death", global_position + Vector3(0.0, 1.2, 0.0), 2.0, 50.0, 7.0)
	if _name_plate:
		_name_plate.remove_from_group("nameplate")
		_name_plate.hide()
	if _rig:
		_rig.set("walk", 0.0)
		_rig.call("cancel_attack")
	var coins: int = reward_override if reward_override >= 0 else int(COIN_REWARDS.get(enemy_type, 3))
	if DROPS.has(enemy_type):
		var drop: Array = DROPS[enemy_type]
		QuestManager.add_item(str(drop[0]), str(drop[1]))
	QuestManager.reward_coins(coins, display_name)
	QuestManager.notify_kill(enemy_type)
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	if _collision_shape:
		_collision_shape.set_deferred("disabled", true)
	_play_death()


## Смерть залежить від типу: попелясті розсипаються, броньовані гуркотливо падають,
## некромант розчиняється в магії, Страж Ока здригається й обвалюється всередину.
func _play_death() -> void:
	var parts: Dictionary = _rig.get("parts") if _rig else {}
	if _rig:
		_rig.set_process(false)
	var back := Vector3(_last_hit_dir.x, 0.0, _last_hit_dir.z)
	if back.length() < 0.1:
		back = global_transform.basis.z
	back = back.normalized()
	var core := get_node_or_null("WraithCoreLight") as OmniLight3D
	var base_y := position.y
	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	match visual_type if visual_type != "" else enemy_type:
		"skeleton_witch":
			# Відьма верещить, руки до неба, спалах магії — і розсипається купою кісток.
			_pose(parts, {"sh_l": 2.6, "sh_r": 2.6, "el_l": 0.2, "el_r": 0.2}, 0.35)
			t.tween_property(self, "position:y", base_y + 0.5, 0.6)
			if core:
				t.parallel().tween_property(core, "light_energy", 5.0, 0.5)
				t.parallel().tween_property(core, "light_color", Color("#b070ff"), 0.5)
			t.tween_callback(_bone_burst)
			t.tween_property(self, "scale", scale * Vector3(1.2, 0.05, 1.2), 0.55).set_ease(Tween.EASE_IN)
			if core:
				t.parallel().tween_property(core, "light_energy", 0.0, 0.55)
			t.tween_callback(queue_free)
		"necromancer", "bone_seer", "ancient_mage":
			# Руки догори, левітація, спалах магії й згасання.
			_pose(parts, {"sh_l": 2.4, "sh_r": 2.4, "el_l": 0.2, "el_r": 0.2}, 0.5)
			t.tween_property(self, "position:y", base_y + 0.9, 0.9)
			t.parallel().tween_property(self, "rotation:y", rotation.y + 1.6, 1.4)
			if core:
				t.parallel().tween_property(core, "light_energy", 6.0, 0.9)
				t.parallel().tween_property(core, "light_color", Color("#c080ff"), 0.9)
			t.tween_property(self, "scale", scale * Vector3(0.2, 1.6, 0.2), 0.5).set_ease(Tween.EASE_IN)
			if core:
				t.parallel().tween_property(core, "light_energy", 0.0, 0.5)
			t.tween_callback(queue_free)
		"eye_guardian":
			_pose(parts, {"sh_l": 1.6, "sh_r": 1.6, "el_l": 0.4, "el_r": 0.4}, 0.4)
			for i in range(8):
				t.tween_property(self, "rotation:z", (0.06 if i % 2 == 0 else -0.06), 0.07)
			t.tween_property(self, "position:y", base_y + 1.4, 0.9)
			if core:
				t.parallel().tween_property(core, "light_energy", 9.0, 0.9)
			t.tween_property(self, "scale", scale * 0.04, 1.1).set_ease(Tween.EASE_IN)
			t.parallel().tween_property(self, "rotation:y", rotation.y + TAU * 2.0, 1.1)
			if core:
				t.parallel().tween_property(core, "light_energy", 0.0, 1.1)
			t.tween_callback(queue_free)
		"ashen_wraith", "skeleton", "skirmisher":
			# Відкидання, підгинання колін, падіння долілиць і розсипання в попіл.
			t.tween_property(self, "position", position + back * 0.9, 0.35)
			_pose(parts, {"knee_l": -1.3, "knee_r": -1.1, "hip_l": 0.7, "hip_r": 0.5, "sh_l": -0.7, "sh_r": 0.6}, 0.35)
			t.parallel().tween_property(self, "rotation:x", deg_to_rad(-20.0), 0.35)
			t.tween_property(self, "rotation:x", deg_to_rad(75.0), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.parallel().tween_property(self, "position:y", base_y - 0.35, 0.5)
			t.tween_interval(0.5)
			t.tween_property(self, "scale", Vector3(scale.x * 1.15, 0.03, scale.z * 1.15), 0.9).set_ease(Tween.EASE_IN)
			if core:
				t.parallel().tween_property(core, "light_energy", 0.0, 0.9)
			t.tween_callback(queue_free)
		"citadel_guardian":
			# Падає на коліна й повільно завалюється вперед.
			_pose(parts, {"knee_l": -1.5, "knee_r": -1.5, "hip_l": 1.1, "hip_r": 1.1, "sh_l": 0.5, "sh_r": 0.5}, 0.6)
			t.tween_property(self, "position:y", base_y - 0.45, 0.6)
			t.tween_interval(0.5)
			t.tween_property(self, "rotation:x", deg_to_rad(88.0), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.tween_callback(func() -> void: AudioManager.play_sfx_3d("parry_ring", global_position, -2.0, 40.0, 6.0))
			t.tween_interval(2.2)
			t.tween_property(self, "position:y", base_y - 1.4, 1.2)
			t.tween_callback(queue_free)
		_:
			# Броньовані (лицар, вартові склепів): хитаються назад і гуркотливо падають навзнак.
			t.tween_property(self, "position", position + back * 1.2, 0.45)
			_pose(parts, {"sh_l": -0.8, "sh_r": 1.0, "el_l": 0.3, "el_r": 0.3, "hip_l": 0.4, "knee_l": -0.5}, 0.4)
			t.parallel().tween_property(self, "rotation:x", deg_to_rad(-18.0), 0.45)
			t.tween_property(self, "rotation:x", deg_to_rad(-88.0), 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			t.parallel().tween_property(self, "position:y", base_y - 0.1, 0.55)
			t.tween_callback(func() -> void: AudioManager.play_sfx_3d("block_thud", global_position, 0.0, 40.0, 6.0))
			t.tween_interval(2.0)
			t.tween_property(self, "position:y", base_y - 1.2, 1.2)
			t.tween_callback(queue_free)


func _bone_burst() -> void:
	## Кістки розлітаються з місця смерті (дешеві коробки, кілька десятків кадрів).
	var bone := PSXMaterials.make(Color("#d8d0b8"), 0.0, 0.9, Color.BLACK, 0.0, "stone", false)
	for i in range(10):
		var m := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(0.07, randf_range(0.2, 0.45), 0.07)
		m.mesh = bx
		m.material_override = bone
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		get_tree().current_scene.add_child(m)
		m.global_position = global_position + Vector3(0, 1.0, 0)
		m.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		var dir := Vector3(randf_range(-1, 1), randf_range(0.8, 2.0), randf_range(-1, 1))
		var tw := m.create_tween()
		tw.tween_property(m, "global_position", global_position + dir * 1.8 + Vector3(0, -0.8, 0), 0.7).set_ease(Tween.EASE_OUT)
		tw.tween_interval(2.5)
		tw.tween_property(m, "scale", Vector3.ONE * 0.02, 0.6)
		tw.tween_callback(m.queue_free)


func _pose(parts: Dictionary, targets: Dictionary, duration: float) -> void:
	var tw := create_tween().set_parallel(true)
	for key in targets.keys():
		var node := parts.get(key) as Node3D
		if node:
			tw.tween_property(node, "rotation:x", float(targets[key]), duration)
