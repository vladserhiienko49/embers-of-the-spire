class_name HorseSystem
extends Node
## Кінь не дається безкоштовно: у стайні Села Попелу його продає Хорен-конярь за монети. Після купівлі
## (предмет «horse_deed» в інвентарі QuestManager — разом із рештою прогресу) кінь відкритий назавжди:
## E — сісти (з анімацією), W — рись, Ctrl — крок, Shift — галоп (витрачає витривалість), S — гальмо,
## V — вигляд від першої особи в сідлі, H — свиснути (кінь підбіжить просто неба). Топче ворогів на швидкості.

const STABLE_SPOT: Array = ["Село Попелу", 9.0, -10.0]
const HORSE_PRICE: int = 300
const TRAMPLE_MIN_SPEED: float = 8.0
const CALL_COOLDOWN: float = 6.0

var world = null
var main = null
var mounted: bool = false
var _ride_rig: Dictionary = {}
var _idle: Array = []          # [{node, rig, interaction, home}]
var _active: int = -1
var _hoof_timer: float = 0.0
var _trample_cd: Dictionary = {}
var _transition: bool = false
var _hoof_phase: int = 0
var _call_cd: float = 0.0
var _stable_pos: Vector3 = Vector3.ZERO


func is_owned() -> bool:
	return QuestManager.has_item("horse_deed")


# --- Модель ----------------------------------------------------------------------------------------

static func _box(parent: Node3D, size: Vector3, mat: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.position = pos
	m.rotation_degrees = rot_deg
	parent.add_child(m)
	return m


static func build_horse(coat: Color = Color("#4a2f1e")) -> Dictionary:
	## Кінь дивиться в -Z, копита на y = 0, спина ≈ 1.3 м.
	var root := Node3D.new()
	root.name = "Horse"
	var coat_m := PSXMaterials.make(coat, 0.0, 0.9, Color.BLACK, 0.0, "cloth", false)
	var dark := PSXMaterials.make(coat.darkened(0.55), 0.0, 0.95, Color.BLACK, 0.0, "cloth", false)
	var leather := PSXMaterials.make(Color("#3a2414"), 0.0, 0.85, Color.BLACK, 0.0, "cloth", false)
	var cloth := PSXMaterials.make(Color("#5e1c1e"), 0.0, 0.95, Color.BLACK, 0.0, "cloth", false)
	var iron := PSXMaterials.make(Color("#4a4c52"), 0.7, 0.5, Color.BLACK, 0.0, "metal", false)
	var eye := PSXMaterials.make(Color("#ffb040"), 0.0, 0.4, Color("#ff8a20"), 1.0, "none", false)
	_box(root, Vector3(0.56, 0.62, 1.3), coat_m, Vector3(0, 1.0, 0))
	_box(root, Vector3(0.52, 0.72, 0.5), coat_m, Vector3(0, 1.04, -0.62))
	_box(root, Vector3(0.54, 0.64, 0.5), coat_m, Vector3(0, 1.02, 0.58))
	_box(root, Vector3(0.26, 0.74, 0.34), coat_m, Vector3(0, 1.42, -1.0), Vector3(32, 0, 0))
	for i in range(5):
		_box(root, Vector3(0.07, 0.2, 0.12), dark, Vector3(0, 1.62 - float(i) * 0.14, -0.84 - float(i) * 0.06), Vector3(32, 0, 0))
	var head := Node3D.new()
	head.position = Vector3(0, 1.74, -1.3)
	root.add_child(head)
	_box(head, Vector3(0.22, 0.24, 0.56), coat_m, Vector3(0, -0.06, -0.2), Vector3(38, 0, 0))
	_box(head, Vector3(0.18, 0.18, 0.2), dark, Vector3(0, -0.22, -0.44), Vector3(38, 0, 0))
	_box(head, Vector3(0.24, 0.05, 0.1), iron, Vector3(0, -0.13, -0.3), Vector3(38, 0, 0))
	for sx: float in [-1.0, 1.0]:
		_box(head, Vector3(0.06, 0.16, 0.05), dark, Vector3(sx * 0.08, 0.15, 0.02), Vector3(-10, 0, sx * 12.0))
		_box(head, Vector3(0.04, 0.04, 0.03), eye, Vector3(sx * 0.115, 0.0, -0.12))
	var tail := Node3D.new()
	tail.position = Vector3(0, 1.28, 0.82)
	root.add_child(tail)
	_box(tail, Vector3(0.12, 0.78, 0.14), dark, Vector3(0, -0.36, 0.06), Vector3(-14, 0, 0))
	var legs: Array = []
	for corner in [Vector3(-0.2, 0.74, -0.6), Vector3(0.2, 0.74, -0.6), Vector3(-0.2, 0.74, 0.62), Vector3(0.2, 0.74, 0.62)]:
		var hip := Node3D.new()
		hip.position = corner
		root.add_child(hip)
		_box(hip, Vector3(0.15, 0.4, 0.17), coat_m, Vector3(0, -0.2, 0))
		var knee := Node3D.new()
		knee.position = Vector3(0, -0.4, 0)
		hip.add_child(knee)
		_box(knee, Vector3(0.1, 0.38, 0.12), dark, Vector3(0, -0.19, 0))
		_box(knee, Vector3(0.14, 0.08, 0.18), iron, Vector3(0, -0.4, 0.0))
		legs.append([hip, knee])
	# Сідло, попона, стремена, вуздечка.
	_box(root, Vector3(0.6, 0.08, 0.52), leather, Vector3(0, 1.35, 0.0))
	_box(root, Vector3(0.64, 0.5, 0.06), cloth, Vector3(-0.28, 1.12, 0.0), Vector3(0, 0, 10))
	_box(root, Vector3(0.64, 0.5, 0.06), cloth, Vector3(0.28, 1.12, 0.0), Vector3(0, 0, -10))
	_box(root, Vector3(0.1, 0.14, 0.1), leather, Vector3(0, 1.46, 0.28))
	for sx: float in [-1.0, 1.0]:
		_box(root, Vector3(0.03, 0.34, 0.03), leather, Vector3(sx * 0.34, 1.2, 0.0))
		_box(root, Vector3(0.12, 0.03, 0.12), iron, Vector3(sx * 0.34, 1.02, 0.0))
	return {"root": root, "legs": legs, "head": head, "tail": tail, "t": randf() * 6.0}


static func animate(rig: Dictionary, speed01: float, delta: float) -> void:
	rig["t"] = float(rig["t"]) + delta * (2.0 + 9.0 * speed01)
	var t: float = rig["t"]
	var legs: Array = rig["legs"]
	var amp := 0.15 + 0.85 * speed01
	var phases := [0.0, PI * 0.5, PI, PI * 1.5]
	for i in range(4):
		var hip: Node3D = legs[i][0]
		var knee: Node3D = legs[i][1]
		var s := sin(t + float(phases[i]) * (1.0 if speed01 > 0.55 else 1.0))
		hip.rotation.x = s * 0.7 * amp * (1.0 if speed01 > 0.03 else 0.0)
		knee.rotation.x = -maxf(0.0, -s) * 0.9 * amp if i < 2 else maxf(0.0, s) * 0.8 * amp
	(rig["root"] as Node3D).rotation.x = sin(t) * 0.025 * speed01
	var head: Node3D = rig["head"]
	head.rotation.x = sin(t * 0.5) * (0.04 + 0.12 * speed01)
	var tail: Node3D = rig["tail"]
	tail.rotation.x = 0.12 + speed01 * 0.5
	tail.rotation.z = sin(t * 0.6) * (0.08 + 0.2 * speed01)


# --- Система -------------------------------------------------------------------------------------------

func setup(world_node) -> void:
	world = world_node
	main = world.get_parent()
	_build_stable()


func _build_stable() -> void:
	## Стайня біля Села Попелу: загорожа, дах на стовпах, сіно, вивіска; у стійлі — кінь на продаж, поруч Хорен.
	var p: Vector3 = world._building_front_position(str(STABLE_SPOT[0]), float(STABLE_SPOT[1]), float(STABLE_SPOT[2]))
	if p == Vector3.ZERO:
		return
	p.y = world._terrain_height_at_world(p.x, p.z)
	_stable_pos = p
	var root := Node3D.new()
	root.name = "HorseStable"
	world.add_child(root)
	root.position = p
	var wood := PSXMaterials.make(Color("#4a3322"), 0.0, 0.95, Color.BLACK, 0.0, "planks", false)
	var roof := PSXMaterials.make(Color("#3a2a24"), 0.0, 0.95, Color.BLACK, 0.0, "planks", false)
	var hay := PSXMaterials.make(Color("#b8962e"), 0.0, 1.0, Color.BLACK, 0.0, "cloth", false)
	var sign_m := PSXMaterials.make(Color("#6a4a2a"), 0.0, 0.9, Color.BLACK, 0.0, "planks", false)
	for sx: float in [-2.2, 2.2]:
		for sz: float in [-1.8, 1.8]:
			_box(root, Vector3(0.22, 3.0, 0.22), wood, Vector3(sx, 1.5, sz))
	_box(root, Vector3(5.4, 0.18, 4.4), roof, Vector3(0, 3.1, 0))
	_box(root, Vector3(5.6, 0.14, 2.4), roof, Vector3(0, 3.4, -0.9), Vector3(-18, 0, 0))
	_box(root, Vector3(5.6, 0.14, 2.4), roof, Vector3(0, 3.4, 0.9), Vector3(18, 0, 0))
	for i in range(5):
		var x := -4.0 + float(i) * 2.0
		_box(root, Vector3(0.14, 1.1, 0.14), wood, Vector3(x, 0.55, -3.4))
		_box(root, Vector3(2.0, 0.1, 0.08), wood, Vector3(x + 1.0, 0.9, -3.4))
		_box(root, Vector3(2.0, 0.1, 0.08), wood, Vector3(x + 1.0, 0.5, -3.4))
	for sz: float in [-2.0, 0.0, 2.0]:
		for sx: float in [-4.0, 4.0]:
			_box(root, Vector3(0.14, 1.1, 0.14), wood, Vector3(sx, 0.55, sz))
			_box(root, Vector3(0.08, 0.1, 2.0), wood, Vector3(sx, 0.9, sz + 1.0))
	for k in range(3):
		_box(root, Vector3(0.9, 0.5, 0.6), hay, Vector3(2.8, 0.25 + 0.5 * float(k % 2), 2.6 - float(k) * 0.7), Vector3(0, 12.0 * float(k), 0))
	_box(root, Vector3(0.08, 1.9, 0.08), wood, Vector3(-4.6, 0.95, 3.6))
	_box(root, Vector3(1.5, 0.5, 0.06), sign_m, Vector3(-4.0, 1.7, 3.6))
	# Кінь на продаж: сісти на нього можна лише після купівлі.
	add_horse(p, 0.0, Color("#4a2f1e"))
	var seller_pos := p + Vector3(4.8, 0.0, 2.8)
	seller_pos.y = world._terrain_height_at_world(seller_pos.x, seller_pos.z)
	var to_horse: Vector3 = world.to_global(p) - world.to_global(seller_pos)
	var facing := atan2(-to_horse.x, -to_horse.z) + PI
	world._create_world_npc("npc_horsetrader", "Хорен", "Конярь із Села Попелу", seller_pos, "#4e3b2a", "#b08a4a", "farmer", facing)


func add_horse(local_pos: Vector3, yaw: float, coat: Color = Color("#4a2f1e")) -> int:
	var rig := build_horse(coat)
	var node: Node3D = rig["root"]
	world.add_child(node)
	node.position = local_pos
	node.rotation.y = yaw
	var idx := _idle.size()
	world._register_world_interaction("horse:%d" % idx, "Кінь", local_pos + Vector3(0, 1.0, 0), 3.0, _horse_hint(idx))
	_idle.append({"node": node, "rig": rig, "interaction": world.world_interactions[world.world_interactions.size() - 1]})
	return idx


func _player() -> CharacterBody3D:
	return world.get("player_ref") as CharacterBody3D


func _horse_hint(idx: int) -> String:
	if is_owned():
		return "E  —  СІСТИ НА КОНЯ"
	return "E  —  ОГЛЯНУТИ КОНЯ" if idx == 0 else "E  —  ЧУЖИЙ КІНЬ"


func _refresh_hints() -> void:
	for i in range(_idle.size()):
		_idle[i]["interaction"]["hint"] = _horse_hint(i)


func _toast(title: String, body: String, seconds: float = 4.0) -> void:
	main.call("_show_story_toast", title, body, seconds)


func handle_interaction(interaction_id: String) -> bool:
	if interaction_id == "npc_horsetrader":
		_seller_dialogue()
		return true
	if not interaction_id.begins_with("horse:"):
		return false
	if mounted or _transition:
		return true
	var idx := int(interaction_id.substr(6))
	if not is_owned():
		if idx == 0:
			_look_dialogue()
		else:
			_toast("ЧУЖИЙ КІНЬ", "Осідланий, але не твій. Свого коня можна купити у Хорена в стайні біля Села Попелу.", 4.5)
		return true
	mount(idx)
	return true


func _seller_dialogue() -> void:
	if is_owned():
		main.call("_show_world_dialogue", "ХОРЕН — КОНЯР", "Ну що, як тобі гнідий? Береги ноги йому й собі. Загубиш — свисни (H), прибіжить хоч де: у чистому полі, звісно. У підземеллі чи на вершині він дурний, не піде.", [{"label": "ДЯКУЮ", "action": "close"}])
		return
	var coins := int(main.get("score"))
	var body := "Дивись, чужинцю: гнідий жеребець, п'ять років, не лякається ні вогню, ні воронів. Тепер таких не знайдеш: війна з'їла майже всіх коней.\n\nЦіна — %d монет. Дешевше — це вже не кінь, а ослик із претензіями." % HORSE_PRICE
	if coins < HORSE_PRICE:
		body += "\n\nУ тебе зараз %d. Не вистачає %d. Повертайся, як назбираєш: без грошей навіть вуздечки не віддам." % [coins, HORSE_PRICE - coins]
	main.call("_show_world_dialogue", "ХОРЕН — КОНЯР", body, [
		{"label": "ОГЛЯНУТИ КОНЯ", "action": "stable:look"},
		{"label": "КУПИТИ КОНЯ  (%d монет)" % HORSE_PRICE, "action": "stable:buy"},
		{"label": "ПІЗНІШЕ", "action": "close"},
	])


func _look_dialogue() -> void:
	main.call("_show_world_dialogue", "ГНІДИЙ ЖЕРЕБЕЦЬ", "Високий, міцний, шкура лискуча. Копита кровні, у боках широкий: витримає і галоп, і важкого вершника в латах. Сідло й вуздечка в комплекті.\n\nРись: W. Крок: Ctrl+W. Галоп: Shift (втомлює коня). Вид від першої особи в сідлі: V.\nЦіна: %d монет." % HORSE_PRICE, [
		{"label": "КУПИТИ КОНЯ  (%d монет)" % HORSE_PRICE, "action": "stable:buy"},
		{"label": "ПІЗНІШЕ", "action": "close"},
	])


func on_action(action: String) -> void:
	match action:
		"stable:look":
			_look_dialogue()
		"stable:buy":
			if is_owned():
				return
			var coins := int(main.get("score"))
			if coins < HORSE_PRICE:
				main.call("_show_world_dialogue", "ХОРЕН — КОНЯР", "Ні-ні, друже. У тебе %d монет, а кінь — %d. Бракує %d. Я не добрий дядько, я конярь: приходь із повною калитою." % [coins, HORSE_PRICE, HORSE_PRICE - coins], [{"label": "ЗРОЗУМІЛО", "action": "close"}])
				AudioManager.play_ui("ui_back")
				return
			main.set("score", coins - HORSE_PRICE)
			main.call("_update_score")
			QuestManager.add_item("horse_deed", "Кінь із конюшні Хорена")
			_refresh_hints()
			AudioManager.play_ui("quest_complete")
			AudioManager.play_sfx("wolf_howl", -16.0, 0.2)
			_toast("КОНЯ КУПЛЕНО", "Гнідий твій назавжди. Підійди до коня й сядь (E). Загубиш — свисни (H).", 6.0)


func _can_ride_here(player: CharacterBody3D) -> bool:
	if bool(world.get("player_in_dungeon")):
		return false
	if world.life and world.life._current != "":
		return false
	if world.eye_finale and world.eye_finale.running:
		return false
	var local: Vector3 = world.to_local(player.global_position)
	var arena: Vector3 = world.get_arena_center_local()
	if arena != Vector3.ZERO and Vector2(local.x - arena.x, local.z - arena.z).length() < 70.0:
		return false
	return true


func mount(idx: int) -> void:
	var player := _player()
	if player == null or idx < 0 or idx >= _idle.size() or mounted or _transition:
		return
	if not is_owned():
		return
	if not _can_ride_here(player):
		_toast("ТУТ НЕ ПОЇДЕШ", "У підземеллі, будівлях і на вершині кінь не пройде.", 3.0)
		return
	_active = idx
	var h: Dictionary = _idle[idx]
	var node: Node3D = h["node"]
	h["interaction"]["position"] = Vector3(0, -9999.0, 0)
	h["run"] = false
	_transition = true
	var was_enabled := bool(player.get("controls_enabled"))
	player.set("controls_enabled", false)
	var start := player.global_position
	var target := node.global_position + Vector3(0, 1.0, 0)
	var yaw0 := player.rotation.y
	var yaw1 := node.rotation.y
	AudioManager.play_sfx("step_dirt", -2.0, 0.1)
	# Посадка: герой підступає до коня, пружно здіймається в сідло.
	var tw := create_tween()
	var step_in := func(t: float) -> void:
		player.velocity = Vector3.ZERO
		player.global_position = start.lerp(target, t) + Vector3(0, sin(t * PI) * 0.8, 0)
		player.rotation.y = lerp_angle(yaw0, yaw1, t)
	tw.tween_method(step_in, 0.0, 1.0, 0.7)
	tw.tween_callback(func() -> void: _finish_mount(player, node, was_enabled))


func _finish_mount(player: CharacterBody3D, node: Node3D, was_enabled: bool) -> void:
	node.hide()
	player.global_position = node.global_position + Vector3(0, 1.0, 0)
	player.velocity = Vector3.ZERO
	player.rotation.y = node.rotation.y
	_ride_rig = build_horse(Color("#4a2f1e"))
	_ride_rig["ride"] = true
	player.add_child(_ride_rig["root"])
	(_ride_rig["root"] as Node3D).position = Vector3(0, -_ground_offset(player), 0)
	player.call("set_riding", true)
	mounted = true
	_transition = false
	player.set("controls_enabled", was_enabled)
	AudioManager.play_sfx("snake_hiss", -14.0, 0.3)
	AudioManager.play_sfx("wolf_howl", -16.0, 0.2)
	main.call("_show_story_toast", "У СІДЛІ", "W — рись, Ctrl+W — крок, Shift — галоп (втомлює), A/D — повороти, S — гальмо. V — вид від першої особи. E — зійти.", 6.0)


func _ground_offset(player: Node3D) -> float:
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(player.global_position, player.global_position + Vector3(0, -4.0, 0), 1)
	q.exclude = [(player as CollisionObject3D).get_rid()]
	var hit := space.intersect_ray(q)
	return player.global_position.y - float(hit["position"].y) if not hit.is_empty() else 0.9


func dismount() -> void:
	var player := _player()
	if player == null or not mounted or _transition:
		return
	mounted = false
	_transition = true
	var was_enabled := bool(player.get("controls_enabled"))
	player.call("set_riding", false)
	if _ride_rig.has("root") and is_instance_valid(_ride_rig["root"]):
		(_ride_rig["root"] as Node3D).queue_free()
	_ride_rig = {}
	var start := player.global_position
	var side := player.global_transform.basis.x * 1.9
	if _active >= 0 and _active < _idle.size():
		var h: Dictionary = _idle[_active]
		var node: Node3D = h["node"]
		var local: Vector3 = world.to_local(start)
		local.y = world._terrain_height_at_world(local.x, local.z)
		node.position = local
		node.rotation.y = player.rotation.y
		node.show()
		h["interaction"]["position"] = world.to_global(local + Vector3(0, 1.0, 0))
	AudioManager.play_sfx("wolf_howl", -18.0, 0.2)
	player.set("controls_enabled", false)
	# Спішування: перекидає ногу й зістрибує вбік.
	var tw := create_tween()
	var step_out := func(t: float) -> void:
		player.velocity = Vector3.ZERO
		player.global_position = start + side * t + Vector3(0, sin(t * PI) * 0.45, 0)
	tw.tween_method(step_out, 0.0, 1.0, 0.5)
	tw.tween_callback(func() -> void:
		player.set("controls_enabled", was_enabled)
		_transition = false
		AudioManager.play_sfx("land", -8.0, 0.1))
	_active = -1


func _input(event: InputEvent) -> void:
	if mounted and event.is_action_pressed("interact"):
		dismount()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo \
			and (event as InputEventKey).physical_keycode == KEY_H:
		_call_horse()


func _call_horse() -> void:
	## Свист: кінь прибігає з-за спини, якщо гравець просто неба. У підземеллях, будівлях, на арені — ні.
	var player := _player()
	if player == null or not is_owned() or mounted or _transition or _idle.is_empty() or _call_cd > 0.0:
		return
	if str(main.get("current_screen")) != "game" or bool(player.call("is_defeated")):
		return
	if not _can_ride_here(player):
		_toast("КІНЬ НЕ ПОЧУЄ", "Тут свист не долине. Покличеш його просто неба.", 3.0)
		return
	_call_cd = CALL_COOLDOWN
	var h: Dictionary = _idle[0]
	var node: Node3D = h["node"]
	var fwd := -player.global_transform.basis.z
	fwd.y = 0.0
	var local: Vector3 = world.to_local(player.global_position + fwd.normalized() * 4.5 + player.global_transform.basis.x * 1.6)
	local.y = world._terrain_height_at_world(local.x, local.z)
	var from: Vector3 = local + Vector3(fwd.x, 0.0, fwd.z).normalized() * 24.0
	from.y = world._terrain_height_at_world(from.x, from.z)
	node.position = from
	node.rotation.y = atan2(-(local.x - from.x), -(local.z - from.z))
	node.show()
	h["run"] = true
	h["interaction"]["position"] = Vector3(0, -9999.0, 0)
	AudioManager.play_sfx("wolf_howl", -10.0, 0.1)
	var tw := create_tween()
	tw.tween_property(node, "position", local, 1.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		h["run"] = false
		node.rotation.y = player.rotation.y + 0.7
		h["interaction"]["position"] = world.to_global(local + Vector3(0, 1.0, 0)))


func _process(delta: float) -> void:
	_call_cd = maxf(0.0, _call_cd - delta)
	for h in _idle:
		if (h["node"] as Node3D).visible:
			animate(h["rig"], 0.8 if bool(h.get("run", false)) else 0.0, delta)
			(h["rig"]["tail"] as Node3D).rotation.z = sin(Time.get_ticks_msec() * 0.0015 + float(h["rig"]["t"])) * 0.12
	if not mounted:
		return
	var player := _player()
	if player == null or bool(player.call("is_defeated")):
		dismount()
		return
	if not _can_ride_here(player):
		dismount()
		return
	var speed := float(player.get("ride_speed"))
	animate(_ride_rig, clampf(absf(speed) / 17.0, 0.0, 1.0), delta)
	_hoof_timer -= delta
	if absf(speed) > 1.5 and _hoof_timer <= 0.0 and player.is_on_floor():
		var gait := str(player.get("gait"))
		_hoof_timer = 0.5 if gait == "walk" else (0.29 if gait == "trot" else 0.19)
		_hoof_phase += 1
		# Копита: звук залежить від поверхні (трава, ґрунт, камінь, міст-дерево, сніг, вода).
		var surface := str(world.get_surface_type(player.global_position))
		AudioManager.play_footstep(surface, gait == "gallop")
		if gait != "walk" and _hoof_phase % 2 == 0:
			AudioManager.play_sfx("block_thud", -17.0, 0.25)
	# Топтання: ворог перед конем, коли швидкість висока.
	for k in _trample_cd.keys():
		_trample_cd[k] = float(_trample_cd[k]) - delta
	if speed >= TRAMPLE_MIN_SPEED:
		var forward := -player.global_transform.basis.z
		for e in get_tree().get_nodes_in_group("hostile"):
			var b := e as Node3D
			if b == null or bool(b.get("dead")) or not b.has_method("take_damage"):
				continue
			var d := b.global_position - player.global_position
			d.y = 0.0
			if d.length() > 2.1 or forward.dot(d.normalized()) < 0.2:
				continue
			var id := b.get_instance_id()
			if float(_trample_cd.get(id, 0.0)) > 0.0:
				continue
			_trample_cd[id] = 0.9
			b.call("take_damage", 58.0 + speed * 3.2, player)
			if b is CharacterBody3D:
				(b as CharacterBody3D).velocity = forward * (7.0 + speed * 0.3) + Vector3(0, 3.0, 0)
			AudioManager.play_sfx("hit_flesh", 0.0, 0.1)
			var fx = player.get("fx")
			if fx:
				fx.add_trauma(0.25)
