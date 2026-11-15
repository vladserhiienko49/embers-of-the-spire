class_name WorldHazards
extends Node
## Раптові небезпеки світу: дикі змії (виповзають із землі під час подорожі), зграя воронів
## (атакує зверху, збивається луком чи мечем) та отруйні гриби. Усе попереджає гравця заздалегідь.
## Отруєння — окремий статус: тікає HP до мінімуму 1 (смерті від отрути немає).

const SNAKE_MIN_GAP: float = 90.0
const RAVEN_DELAY: Vector2 = Vector2(150.0, 300.0)
const MUSHROOM_SPOTS: Array = [
	["Болотна хатина", 10.0, 6.0, 16], ["Болотна хатина", -12.0, -4.0, 12], ["Забуте кладовище", -12.0, 10.0, 12],
	["Склеп Забутих Королів", 14.0, 8.0, 12], ["Руїни Абатства", -12.0, -6.0, 14], ["Хатина відьми", 10.0, 8.0, 10],
	["Монастир Сірих Сестер", 15.0, -6.0, 10], ["Коло друїдів", -13.0, 4.0, 12],
]

var world = null
var main = null
var _walked: float = 0.0
var _snake_threshold: float = 160.0
var _since_snake: float = 0.0
var _raven_timer: float = 200.0
var _ravens_active: bool = false
var _mushrooms: Array = []     # [Vector3 position, cluster_id]
var _contact_cd: float = 0.0
var _poison_left: float = 0.0
var _poison_tick: float = 0.0
var _check_timer: float = 0.0
var _poison_layer: CanvasLayer = null
var _poison_tint: ColorRect = null
var _poison_label: Label = null


func setup(world_node) -> void:
	world = world_node
	main = world.get_parent()
	_snake_threshold = randf_range(130.0, 240.0)
	_raven_timer = randf_range(RAVEN_DELAY.x, RAVEN_DELAY.y)
	_build_mushrooms()
	_poison_layer = CanvasLayer.new()
	_poison_layer.layer = 13
	add_child(_poison_layer)
	_poison_tint = ColorRect.new()
	_poison_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_poison_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_poison_tint.color = Color(0.25, 0.8, 0.2, 0.0)
	_poison_layer.add_child(_poison_tint)
	_poison_label = Label.new()
	_poison_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_poison_label.offset_left = -150.0
	_poison_label.offset_right = 150.0
	_poison_label.offset_top = 88.0
	_poison_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_poison_label.add_theme_font_size_override("font_size", 16)
	_poison_label.add_theme_color_override("font_color", Color("#9cff6a"))
	_poison_label.add_theme_constant_override("outline_size", 4)
	_poison_label.add_theme_color_override("font_outline_color", Color(0, 0.1, 0, 0.9))
	_poison_label.visible = false
	_poison_layer.add_child(_poison_label)


func _player() -> CharacterBody3D:
	return world.get("player_ref") as CharacterBody3D


func _toast(title: String, body: String, seconds: float = 3.5) -> void:
	if main and main.has_method("_show_story_toast"):
		main.call("_show_story_toast", title, body, seconds)


## Гравець у «вільному» світі: не в діалозі/меню, не в каземат й не в хаті, живий.
func _outdoors_active() -> bool:
	var p := _player()
	if p == null or not bool(p.get("controls_enabled")) or p.call("is_defeated"):
		return false
	if bool(world.get("player_in_dungeon")):
		return false
	if world.life and world.life._current != "":
		return false
	return str(main.get("current_screen")) == "game"


func _enemy_near(p: Node3D, radius: float) -> bool:
	for e in get_tree().get_nodes_in_group("hostile"):
		var b := e as Node3D
		if b and not bool(b.get("dead")) and b.global_position.distance_to(p.global_position) < radius:
			return true
	return false


func _near_building(p: Node3D, radius: float) -> bool:
	var local: Vector3 = world.to_local(p.global_position)
	for b in world.building_nodes.values():
		var n := b as Node3D
		if n and Vector2(n.position.x - local.x, n.position.z - local.z).length() < radius:
			return true
	return false


# --- Отрута ----------------------------------------------------------------------------------------

func poison(seconds: float) -> void:
	_poison_left = maxf(_poison_left, seconds)
	_poison_tick = 0.0
	_toast("ОТРУЄННЯ", "Отрута пече жили. Вона слабшає з часом — зілля й вогнище лікують швидше.", 3.5)


func _update_poison(delta: float) -> void:
	var p := _player()
	if _poison_left > 0.0 and p and bool(p.get("controls_enabled")):
		_poison_left = maxf(0.0, _poison_left - delta)
		_poison_tick -= delta
		if _poison_tick <= 0.0:
			_poison_tick = 1.0
			if float(p.get("health")) > 1.5:
				p.set("health", maxf(1.0, float(p.get("health")) - 1.5))
				p.call("notify_stats")
	var k := clampf(_poison_left / 2.0, 0.0, 1.0)
	_poison_tint.color.a = k * (0.12 + 0.05 * sin(Time.get_ticks_msec() * 0.006))
	_poison_label.visible = _poison_left > 0.0
	_poison_label.text = "ОТРУЄННЯ  ☠  %d с" % int(ceil(_poison_left))


func cure_poison() -> void:
	_poison_left = 0.0


# --- Головний цикл -----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_update_poison(delta)
	_contact_cd = maxf(0.0, _contact_cd - delta)
	if not _outdoors_active():
		return
	var p := _player()
	_since_snake += delta
	# Подорож: накопичуємо пройдений шлях пішки.
	if p.is_on_floor():
		_walked += Vector2(p.velocity.x, p.velocity.z).length() * delta
	if _walked >= _snake_threshold and _since_snake > SNAKE_MIN_GAP:
		if _near_building(p, 28.0) or _enemy_near(p, 18.0):
			_walked = _snake_threshold - 30.0
		else:
			_spawn_snake_event(p)
			_walked = 0.0
			_since_snake = 0.0
			_snake_threshold = randf_range(150.0, 280.0)
	_raven_timer -= delta
	if _raven_timer <= 0.0 and not _ravens_active:
		if _near_building(p, 22.0) or _enemy_near(p, 20.0) or world.to_local(p.global_position).y > 80.0:
			_raven_timer = 25.0
		else:
			_start_ravens(p)
			_raven_timer = randf_range(RAVEN_DELAY.x, RAVEN_DELAY.y)
	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = 0.12
		_check_mushrooms(p)


# --- Змії ----------------------------------------------------------------------------------------------

func _spawn_snake_event(p: CharacterBody3D) -> void:
	var fwd := Vector3(p.velocity.x, 0.0, p.velocity.z)
	if fwd.length() < 0.5:
		fwd = -p.global_transform.basis.z
	fwd = fwd.normalized().rotated(Vector3.UP, randf_range(-0.5, 0.5))
	var pos: Vector3 = p.global_position + fwd * 4.8
	var snake := Snake.new()
	snake.hazards = self
	snake.target = p
	snake.world = world
	world.add_child(snake)
	var sl: Vector3 = world.to_local(pos)
	pos = world.to_global(Vector3(sl.x, float(world._terrain_height_at_world(sl.x, sl.z)), sl.z))
	snake.global_position = pos
	# Попередження: тремтіння землі й шипіння ще до появи.
	AudioManager.play_sfx_3d("snake_hiss", pos, -2.0, 20.0, 4.0)
	_toast("ШУРХІТ У ТРАВІ", "Земля ворушиться попереду — відступи й дочекайся змії!", 2.5)


class Snake extends CharacterBody3D:
	var hazards = null
	var world = null
	var target: CharacterBody3D = null
	var health: float = 24.0
	var dead: bool = false
	var _t: float = 0.0
	var _state: String = "emerge"
	var _segs: Array = []
	var _head: Node3D
	var _tongue: MeshInstance3D
	var _strikes: int = 0
	var _strike_from: Vector3
	var _strike_to: Vector3
	var _strike_t: float = 0.0
	var _hit_done: bool = false
	var _rear: float = 0.0
	var _root: Node3D

	func _ready() -> void:
		add_to_group("hostile")
		collision_layer = 2
		collision_mask = 0
		var shape := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.4
		cap.height = 0.9
		shape.shape = cap
		shape.position = Vector3(0, 0.45, 0)
		add_child(shape)
		_root = Node3D.new()
		add_child(_root)
		var a := PSXMaterials.make(Color("#4a5a2a"), 0.0, 0.9, Color.BLACK, 0.0, "cloth", false)
		var b := PSXMaterials.make(Color("#2a2418"), 0.0, 0.9, Color.BLACK, 0.0, "cloth", false)
		for i in range(8):
			var m := MeshInstance3D.new()
			var box := BoxMesh.new()
			var w := lerpf(0.2, 0.06, float(i) / 7.0)
			box.size = Vector3(w, w, 0.24)
			m.mesh = box
			m.material_override = a if i % 2 == 0 else b
			_root.add_child(m)
			_segs.append(m)
		_head = Node3D.new()
		_root.add_child(_head)
		var hm := MeshInstance3D.new()
		var hb := BoxMesh.new()
		hb.size = Vector3(0.2, 0.12, 0.26)
		hm.mesh = hb
		hm.material_override = a
		_head.add_child(hm)
		for sx: float in [-1.0, 1.0]:
			var eye := MeshInstance3D.new()
			var eb := BoxMesh.new()
			eb.size = Vector3(0.04, 0.04, 0.03)
			eye.mesh = eb
			eye.material_override = PSXMaterials.make(Color("#ffe040"), 0.0, 0.4, Color("#ffd020"), 2.5, "none", false)
			eye.position = Vector3(sx * 0.07, 0.04, -0.12)
			_head.add_child(eye)
		_tongue = MeshInstance3D.new()
		var tb := BoxMesh.new()
		tb.size = Vector3(0.02, 0.01, 0.14)
		_tongue.mesh = tb
		_tongue.material_override = PSXMaterials.make(Color("#c02030"), 0.0, 0.8, Color.BLACK, 0.0, "none", false)
		_tongue.position = Vector3(0, -0.01, -0.2)
		_head.add_child(_tongue)
		_pose(0.0, 0.0)
		_dirt_burst()

	func _dirt_burst() -> void:
		var dirt := PSXMaterials.make(Color("#4a3a28"), 0.0, 1.0, Color.BLACK, 0.0, "none", false)
		for i in range(9):
			var m := MeshInstance3D.new()
			var bx := BoxMesh.new()
			bx.size = Vector3.ONE * randf_range(0.08, 0.16)
			m.mesh = bx
			m.material_override = dirt
			add_child(m)
			var dir := Vector3(randf_range(-1, 1), randf_range(1.2, 2.2), randf_range(-1, 1))
			var tw := create_tween().set_parallel(true)
			tw.tween_property(m, "position", dir * 0.7, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(m, "scale", Vector3.ONE * 0.05, 0.5)
			tw.chain().tween_callback(m.queue_free)

	## rear (0..1) — наскільки голова піднята; sink (0..1) — наскільки тіло в землі.
	func _pose(rear: float, sink: float) -> void:
		var wig := _t * 6.0
		for i in range(_segs.size()):
			var k := float(i) / 7.0
			var s: MeshInstance3D = _segs[i]
			var lift := rear * 0.62 * maxf(0.0, 1.0 - k * 1.6)
			s.position = Vector3(sin(wig + k * 5.0) * 0.13 * (1.0 - rear * 0.7), 0.1 + lift - sink * 0.6, 0.22 + k * 1.45 * (1.0 - rear * 0.25))
		_head.position = Vector3(0, 0.1 + rear * 0.62 - sink * 0.6, 0.0)
		_head.rotation.x = -rear * 0.5
		_tongue.visible = fmod(_t * 5.0, 1.0) < 0.5

	func _face_target(delta: float) -> void:
		if target == null or not is_instance_valid(target):
			return
		var d := target.global_position - global_position
		var want := atan2(-d.x, -d.z)
		rotation.y = lerp_angle(rotation.y, want, minf(1.0, delta * 8.0))

	func _physics_process(delta: float) -> void:
		if dead or target == null or not is_instance_valid(target):
			return
		_t += delta
		match _state:
			"emerge":
				_face_target(delta)
				_pose(0.0, 1.0 - clampf(_t / 0.7, 0.0, 1.0))
				if _t > 0.7:
					_state = "warn"
					_t = 0.0
					AudioManager.play_sfx_3d("snake_hiss", global_position, 0.0, 22.0, 4.0)
			"warn":
				# Піднята голова, шипіння: 0.8 с на реакцію перед укусом.
				_face_target(delta)
				_rear = lerpf(_rear, 1.0, delta * 8.0)
				_pose(_rear, 0.0)
				if _t > 0.8:
					_begin_strike()
			"strike":
				_strike_t += delta / 0.22
				global_position = _strike_from.lerp(_strike_to, clampf(_strike_t, 0.0, 1.0))
				_pose(1.0 - clampf(_strike_t, 0.0, 1.0) * 0.6, 0.0)
				if _strike_t >= 0.7 and not _hit_done:
					_hit_done = true
					if global_position.distance_to(target.global_position) < 1.7:
						hazards._snake_bite(self, target)
				if _strike_t >= 1.0:
					_state = "recover"
					_t = 0.0
			"recover":
				_rear = lerpf(_rear, 0.35, delta * 3.0)
				_pose(_rear, 0.0)
				_face_target(delta)
				if _t > 1.3:
					_strikes += 1
					if _strikes >= 3:
						_state = "burrow"
						_t = 0.0
					else:
						_state = "warn"
						_t = 0.0
						AudioManager.play_sfx_3d("snake_hiss", global_position, -3.0, 20.0, 4.0)
			"burrow":
				_pose(0.0, clampf(_t / 0.8, 0.0, 1.0))
				if _t > 0.8:
					queue_free()

	func _begin_strike() -> void:
		_state = "strike"
		_strike_t = 0.0
		_hit_done = false
		_strike_from = global_position
		var d := target.global_position - global_position
		d.y = 0.0
		_strike_to = global_position + d.normalized() * minf(d.length() - 0.5, 2.4)

	func take_damage(amount: float, _source: Node = null) -> void:
		if dead:
			return
		health -= amount
		AudioManager.play_sfx_3d("wraith_hurt", global_position, -6.0, 20.0, 4.0)
		if health <= 0.0:
			dead = true
			collision_layer = 0
			QuestManager.reward_coins(2, "Змія")
			QuestManager.notify_kill("snake")
			var tw := create_tween()
			tw.tween_method(func(v: float) -> void: _pose(0.0, v), 0.0, 1.0, 0.6)
			tw.tween_callback(queue_free)
		else:
			_rear = 0.0


func _snake_bite(snake: Node3D, victim: CharacterBody3D) -> void:
	victim.call("take_damage", 9.0, snake)
	AudioManager.play_sfx("hit_flesh", -3.0, 0.1)
	poison(4.0)


# --- Ворони ----------------------------------------------------------------------------------------------

func _start_ravens(p: CharacterBody3D) -> void:
	_ravens_active = true
	_toast("КАРКАННЯ НАД ГОЛОВОЮ", "Зграя воронів кружляє зверху! Дістань лук (B) і збивай їх, або відбивайся мечем.", 4.5)
	var count := 4 + randi() % 2
	var flock: Array = []
	for i in range(count):
		var raven := Raven.new()
		raven.hazards = self
		raven.target = p
		raven.slot = i
		raven.angle = TAU * float(i) / float(count)
		raven.attack_at = 2.4 + float(i) * 1.3
		world.add_child(raven)
		raven.global_position = p.global_position + Vector3(cos(raven.angle), 0.0, sin(raven.angle)) * 13.0 + Vector3(0, 15.0, 0)
		flock.append(raven)
	for k in range(3):
		AudioManager.play_sfx_3d("crow", p.global_position + Vector3(0, 12, 0), 1.0, 60.0, 10.0)
		await get_tree().create_timer(0.7).timeout
	await get_tree().create_timer(18.0).timeout
	for r in flock:
		if is_instance_valid(r):
			(r as Raven).leave()
	await get_tree().create_timer(4.0).timeout
	_ravens_active = false


class Raven extends CharacterBody3D:
	var hazards = null
	var target: CharacterBody3D = null
	var slot: int = 0
	var angle: float = 0.0
	var attack_at: float = 3.0
	var health: float = 10.0
	var dead: bool = false
	var _t: float = 0.0
	var _mode: String = "circle"
	var _dive_t: float = 0.0
	var _dive_from: Vector3
	var _dive_to: Vector3
	var _dives: int = 0
	var _wing_l: Node3D
	var _wing_r: Node3D
	var _fall: float = 0.0
	var _leaving: bool = false

	func _ready() -> void:
		add_to_group("hostile")
		collision_layer = 2
		collision_mask = 0
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.5
		shape.shape = sphere
		add_child(shape)
		var black := PSXMaterials.make(Color("#0e0e12"), 0.2, 0.7, Color.BLACK, 0.0, "cloth", false)
		var beak := PSXMaterials.make(Color("#b08a2a"), 0.0, 0.6, Color.BLACK, 0.0, "none", false)
		var body := MeshInstance3D.new()
		var bb := BoxMesh.new()
		bb.size = Vector3(0.22, 0.2, 0.46)
		body.mesh = bb
		body.material_override = black
		add_child(body)
		var head := MeshInstance3D.new()
		var hb := BoxMesh.new()
		hb.size = Vector3(0.14, 0.14, 0.16)
		head.mesh = hb
		head.material_override = black
		head.position = Vector3(0, 0.06, -0.28)
		add_child(head)
		var bk := MeshInstance3D.new()
		var kb := BoxMesh.new()
		kb.size = Vector3(0.05, 0.05, 0.14)
		bk.mesh = kb
		bk.material_override = beak
		bk.position = Vector3(0, 0.04, -0.4)
		add_child(bk)
		var eye := MeshInstance3D.new()
		var eb := BoxMesh.new()
		eb.size = Vector3(0.1, 0.03, 0.03)
		eye.mesh = eb
		eye.material_override = PSXMaterials.make(Color("#ff4020"), 0.0, 0.4, Color("#ff2010"), 2.0, "none", false)
		eye.position = Vector3(0, 0.1, -0.35)
		add_child(eye)
		for sx: float in [-1.0, 1.0]:
			var wing := Node3D.new()
			wing.position = Vector3(sx * 0.1, 0.05, 0.0)
			add_child(wing)
			var wm := MeshInstance3D.new()
			var wb := BoxMesh.new()
			wb.size = Vector3(0.7, 0.03, 0.34)
			wm.mesh = wb
			wm.material_override = black
			wm.position = Vector3(sx * 0.35, 0, 0)
			wing.add_child(wm)
			if sx < 0.0:
				_wing_l = wing
			else:
				_wing_r = wing
		var tail := MeshInstance3D.new()
		var tb := BoxMesh.new()
		tb.size = Vector3(0.16, 0.03, 0.26)
		tail.mesh = tb
		tail.material_override = black
		tail.position = Vector3(0, 0, 0.34)
		add_child(tail)

	func leave() -> void:
		_leaving = true

	func _flap(speed: float) -> void:
		var f := sin(_t * speed) * 0.7
		_wing_l.rotation.z = -f
		_wing_r.rotation.z = f

	func _look(dir: Vector3) -> void:
		if dir.length() > 0.01:
			look_at(global_position + dir, Vector3.UP)

	func _physics_process(delta: float) -> void:
		_t += delta
		if dead:
			_fall += delta
			global_position.y -= (4.0 + _fall * 9.0) * delta
			rotation.z += delta * 6.0
			if _fall > 2.0 or global_position.y < world_floor():
				queue_free()
			return
		if target == null or not is_instance_valid(target):
			queue_free()
			return
		_flap(16.0 if _mode == "circle" else 24.0)
		var tp := target.global_position
		match _mode:
			"circle":
				# Попередження: птах кружляє над героєм, ще не атакує.
				angle += delta * 0.9
				var orbit := Vector3(cos(angle), 0.0, sin(angle)) * 11.0
				var goal := tp + orbit + Vector3(0, 13.0 + sin(_t * 2.0 + float(slot)), 0)
				var move := goal - global_position
				global_position += move * minf(1.0, delta * 2.2)
				_look(Vector3(-sin(angle), 0.0, cos(angle)))
				if _leaving:
					_mode = "leave"
				elif _t >= attack_at and _dives < 2 and hazards._outdoors_active():
					_mode = "tell"
					_dive_t = 0.0
					AudioManager.play_sfx_3d("crow", global_position, 2.0, 50.0, 8.0)
			"tell":
				# 0.7 с: птах завмирає й падає в крок — час зреагувати (ухилитися чи стрільнути).
				_dive_t += delta
				_look(tp - global_position)
				rotation.z += sin(_t * 40.0) * 0.02
				if _dive_t >= 0.7:
					_mode = "dive"
					_dive_t = 0.0
					_dive_from = global_position
					_dive_to = tp + Vector3(0, 1.3, 0)
			"dive":
				_dive_t += delta / 0.9
				var k := clampf(_dive_t, 0.0, 1.0)
				var path := _dive_from.lerp(_dive_to, k * k)
				global_position = path
				_look(_dive_to - _dive_from)
				if k >= 1.0:
					if global_position.distance_to(target.global_position + Vector3(0, 1.1, 0)) < 1.9:
						target.call("take_damage", 4.0, self)
						AudioManager.play_sfx("hit_flesh", -4.0, 0.15)
					_dives += 1
					_mode = "climb"
					_dive_t = 0.0
			"climb":
				_dive_t += delta
				global_position += Vector3(0, 8.0, 0) * delta + (global_position - tp).normalized() * 2.0 * delta
				if _dive_t > 1.4:
					_mode = "circle"
					_t = 0.0
					attack_at = 3.5 + float(slot) * 0.8
			"leave":
				global_position += Vector3(cos(angle), 0.6, sin(angle)) * 9.0 * delta
				if global_position.distance_to(tp) > 70.0:
					queue_free()

	func world_floor() -> float:
		return target.global_position.y - 3.0 if target and is_instance_valid(target) else -100.0

	func take_damage(amount: float, _source: Node = null) -> void:
		if dead:
			return
		health -= amount
		if health <= 0.0:
			dead = true
			collision_layer = 0
			QuestManager.reward_coins(1, "Ворон")
			QuestManager.notify_kill("raven")
			AudioManager.play_sfx_3d("crow", global_position, 0.0, 40.0, 6.0)


# --- Отруйні гриби ------------------------------------------------------------------------------------------

func _build_mushrooms() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7077
	var cap_mat := PSXMaterials.make(Color("#6a2a8a"), 0.0, 0.8, Color("#3a1a5a"), 0.6, "none", false)
	var cap_mat2 := PSXMaterials.make(Color("#2a8a4a"), 0.0, 0.8, Color("#1a6a30"), 0.7, "none", false)
	var stem_mat := PSXMaterials.make(Color("#c8c0a0"), 0.0, 0.9, Color.BLACK, 0.0, "none", false)
	var spot_mat := PSXMaterials.make(Color("#c8ff60"), 0.0, 0.4, Color("#90ff30"), 3.0, "none", false)
	var cluster_id := 0
	for spot in MUSHROOM_SPOTS:
		var center: Vector3 = world._building_local_point(str(spot[0]), Vector3(float(spot[1]), 0.0, float(spot[2])))
		if center == Vector3.ZERO:
			continue
		var kit := MeshKit.new()
		kit.set_material("stem", stem_mat)
		kit.set_material("cap_a", cap_mat)
		kit.set_material("cap_b", cap_mat2)
		kit.set_material("spot", spot_mat)
		var count := int(spot[3])
		for i in range(count):
			var a := rng.randf() * TAU
			var r := sqrt(rng.randf()) * 3.6
			var p := center + Vector3(cos(a) * r, 0.0, sin(a) * r)
			p.y = world._terrain_height_at_world(p.x, p.z)
			var h := rng.randf_range(0.5, 1.5)
			var cap_r := rng.randf_range(0.35, 0.75) * (0.6 + h * 0.5)
			var key := "cap_a" if i % 3 != 0 else "cap_b"
			kit.cylinder_at("stem", p - Vector3(0, 0.1, 0), 0.1, 0.07, h + 0.1, 6)
			kit.cylinder_at(key, p + Vector3(0, h, 0), cap_r, cap_r * 0.35, 0.28, 8)
			kit.pyramid(key, Transform3D(Basis(), p + Vector3(0, h + 0.28, 0)), cap_r * 0.9, cap_r * 0.9, 0.2)
			for s in range(3):
				var sa := rng.randf() * TAU
				kit.box_at("spot", p + Vector3(cos(sa) * cap_r * 0.55, h + 0.3, sin(sa) * cap_r * 0.55), Vector3(0.09, 0.05, 0.09))
			_mushrooms.append([p, cluster_id, cap_r])
		kit.build(world, "PoisonShrooms_%d" % cluster_id, 160.0)
		# Тьмяне зеленувате світло й спори: гриби помітні вночі, на них видно «зону».
		var glow := OmniLight3D.new()
		glow.light_color = Color("#7aff50")
		glow.light_energy = 0.9
		glow.omni_range = 7.0
		glow.position = center + Vector3(0, 1.0, 0)
		glow.distance_fade_enabled = true
		glow.distance_fade_begin = 55.0
		glow.distance_fade_length = 20.0
		world.add_child(glow)
		var spores := GPUParticles3D.new()
		spores.position = center + Vector3(0, 0.4, 0)
		spores.amount = 14
		spores.lifetime = 4.0
		spores.visibility_aabb = AABB(Vector3(-5, -1, -5), Vector3(10, 6, 10))
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 25.0
		pm.initial_velocity_min = 0.2
		pm.initial_velocity_max = 0.5
		pm.gravity = Vector3(0, 0.08, 0)
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 3.2
		spores.process_material = pm
		var quad := QuadMesh.new()
		quad.size = Vector2(0.09, 0.09)
		quad.material = PSXMaterials.make(Color("#a8ff70"), 0.0, 1.0, Color("#80ff40"), 2.5, "none", false)
		spores.draw_pass_1 = quad
		world.add_child(spores)
		cluster_id += 1


func _check_mushrooms(p: CharacterBody3D) -> void:
	if _contact_cd > 0.0 or _mushrooms.is_empty():
		return
	var local: Vector3 = world.to_local(p.global_position)
	for m in _mushrooms:
		var mp: Vector3 = m[0]
		if Vector2(mp.x - local.x, mp.z - local.z).length() < 0.75 + float(m[2]) * 0.5 and absf(local.y - mp.y) < 2.2:
			_contact_cd = 1.4
			p.call("take_damage", 5.0, self)
			AudioManager.play_sfx("land", -6.0, 0.2)
			_puff(world.to_global(mp + Vector3(0, 0.9, 0)))
			poison(5.0)
			return


func _puff(at: Vector3) -> void:
	var mat := PSXMaterials.make(Color("#90e060"), 0.0, 1.0, Color("#60c030"), 1.5, "none", false)
	for i in range(8):
		var m := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3.ONE * 0.18
		m.mesh = bx
		m.material_override = mat
		get_tree().current_scene.add_child(m)
		m.global_position = at
		var dir := Vector3(randf_range(-1, 1), randf_range(0.4, 1.4), randf_range(-1, 1))
		var tw := create_tween().set_parallel(true)
		tw.tween_property(m, "global_position", at + dir * 1.0, 0.7)
		tw.tween_property(m, "scale", Vector3.ONE * 0.05, 0.7)
		tw.chain().tween_callback(m.queue_free)
