class_name MassBattle
extends Node
## Масові бої (10–15 ворогів) у сюжетних місцях та групова поведінка для будь-якого загону
## (напр. засідка лицарів на дорозі до гори — вона підключається через adopt()).
##
## Група діє злагоджено: одночасно в ближньому бою лише кілька «штурмовиків»; «обхідники» ідуть
## гравцеві за спину; «тримачі» стоять колом на відстані й вступають у бій, коли звільняється місце.
## Музика масового бою вмикається автоматично й повертається до звичайної після завершення.

const TICK: float = 0.25
const SPAWN_MAX_TRIES: int = 6
const GIVE_UP_DISTANCE: float = 190.0

## Місця битв. step — крок головного сюжету «Попіл і Корона», на якому вони можливі.
const SITES: Array = [
	{"id": "cemetery", "anchor": "story_cemetery", "step": 2, "trigger": 75.0, "reward": 70,
		"title": "ОРДА ПОПЕЛУ", "text": "Кладовище кишить Попелястими вартовими — їх понад десяток, і вони йдуть з усіх боків!",
		"mix": [["wraith", 9], ["heavy", 3]]},
	{"id": "abbey", "anchor": "story_abbey", "step": 5, "trigger": 75.0, "reward": 90,
		"title": "ЗАГІН ЧОРНОГО ПРАПОРА", "text": "Біля Абатства чекає застава лицарів Чорного Прапора: частина піде в лоб, частина — в обхід.",
		"mix": [["knight", 9], ["wraith", 3], ["heavy", 1]]},
	{"id": "citadel", "anchor": "story_citadel", "step": 8, "trigger": 80.0, "reward": 120,
		"title": "ГАРНІЗОН ЦИТАДЕЛІ", "text": "Гарнізон Цитаделі виходить із-за мурів — п'ятнадцять клинків проти тебе одного. Не дай оточити себе!",
		"mix": [["knight", 10], ["wraith", 3], ["heavy", 2]]},
]

const KINDS: Dictionary = {
	"wraith": {"enemy_type": "ashen_wraith", "display_name": "ПОПЕЛЯСТИЙ ВАРТОВИЙ", "max_health": 72.0, "attack_damage": 11.0, "move_speed": 2.9, "scale": 1.0, "reward_override": 4},
	"knight": {"enemy_type": "ashen_wraith", "visual_type": "enemy_knight", "display_name": "ВОРОЖИЙ ЛИЦАР", "max_health": 85.0, "attack_damage": 13.0, "move_speed": 3.0, "scale": 1.05, "reward_override": 6},
	"heavy": {"enemy_type": "ashen_wraith", "visual_type": "enemy_knight", "display_name": "ЛИЦАР-ВАРТОВИЙ", "max_health": 150.0, "attack_damage": 18.0, "move_speed": 2.6, "scale": 1.25, "reward_override": 12},
}

var world = null
var main = null
var _tick: float = 0.0
var _squads: Array = []          # {id, members: Array, roles: Dictionary, goals: Dictionary, age, title, reward, site, stuck: Dictionary}
var _done_sites: Dictionary = {}
var _poll: float = 0.0


func setup(world_node) -> void:
	world = world_node
	main = world.get_parent()


func _player() -> CharacterBody3D:
	return world.get("player_ref") as CharacterBody3D


func _toast(title: String, body: String, seconds: float = 5.0) -> void:
	if main and main.has_method("_show_story_toast"):
		main.call("_show_story_toast", title, body, seconds)


func is_battle_active() -> bool:
	return not _squads.is_empty()


func _process(delta: float) -> void:
	var player := _player()
	if player == null:
		return
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.5
		_check_sites(player)
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		_update_squads(player)
	AudioManager.set_mass_battle(not _squads.is_empty(), "mass")


# --- Запуск битв у сюжетних місцях -------------------------------------------------------------

func _check_sites(player: CharacterBody3D) -> void:
	if not _squads.is_empty() or player.is_defeated():
		return
	if not world.hazards._outdoors_active():
		return
	if QuestManager.get_quest_state("main_story") != "active":
		return
	var step := QuestManager.get_step("main_story")
	var local: Vector3 = world.to_local(player.global_position)
	for site in SITES:
		var sid := str(site["id"])
		if _done_sites.has(sid) or int(site["step"]) != step:
			continue
		var anchor: Vector3 = world.story_positions.get(str(site["anchor"]), Vector3.ZERO)
		if anchor == Vector3.ZERO:
			continue
		if Vector2(anchor.x - local.x, anchor.z - local.z).length() < float(site["trigger"]):
			_start_site(site, anchor, local)
			return


func _start_site(site: Dictionary, anchor: Vector3, player_local: Vector3) -> void:
	var squad := _new_squad(str(site["id"]), str(site["title"]), int(site["reward"]))
	squad["site"] = str(site["id"])
	squad["spawning"] = true
	_squads.append(squad)
	AudioManager.play_sfx("wolf_howl", 2.0, 0.0)
	_toast("ВЕЛИКА БИТВА: " + str(site["title"]), str(site["text"]), 7.0)
	var kinds: Array = []
	for pair in site["mix"]:
		for i in range(int(pair[1])):
			kinds.append(str(pair[0]))
	kinds.shuffle()
	_spawn_squad(squad, kinds, anchor, player_local)


func _new_squad(id: String, title: String, reward: int) -> Dictionary:
	return {"id": id, "members": [], "roles": {}, "goals": {}, "slot": {}, "age": 0.0, "title": title, "reward": reward,
		"site": "", "stuck": {}, "spawning": false, "engaged": {}, "closed": false}


## Підключає вже створених ворогів (напр. засідка лицарів) до групової поведінки.
func adopt(squad_id: String, enemy: Node, title: String = "ЗАСІДКА", reward: int = 0) -> void:
	if enemy == null:
		return
	var squad: Dictionary = {}
	for s in _squads:
		if str(s["id"]) == squad_id:
			squad = s
			break
	if squad.is_empty():
		squad = _new_squad(squad_id, title, reward)
		squad["spawning"] = false
		_squads.append(squad)
	_add_member(squad, enemy, 0)


func _add_member(squad: Dictionary, enemy: Node, index: int) -> void:
	var members: Array = squad["members"]
	members.append(enemy)
	# Ролі: ~40 % штурмовики, 30 % обхідники, 30 % тримаються позаду.
	var r := index % 10
	var role := "charge" if r < 4 else ("flank" if r < 7 else "hold")
	var roles: Dictionary = squad["roles"]
	roles[enemy] = role
	var slot: Dictionary = squad["slot"]
	slot[enemy] = {"angle": randf() * TAU, "side": 1.0 if randf() < 0.5 else -1.0, "ring": randf_range(11.0, 15.0)}
	var engaged: Dictionary = squad["engaged"]
	var engaged_count := 0
	for v in engaged.values():
		if bool(v):
			engaged_count += 1
	var starts_engaged := role == "charge" and engaged_count < 4
	enemy.set("squad_mode", true)
	enemy.set("squad_engage", starts_engaged)
	enemy.set("detection_range", 130.0)
	engaged[enemy] = starts_engaged


func _spawn_squad(squad: Dictionary, kinds: Array, anchor: Vector3, player_local: Vector3) -> void:
	## Загін розставляється не в одній точці: авангард, два фланги й резерв позаду.
	var toward := Vector3(anchor.x - player_local.x, 0.0, anchor.z - player_local.z)
	if toward.length() < 1.0:
		toward = Vector3(0, 0, -1)
	toward = toward.normalized()
	var side := Vector3(-toward.z, 0.0, toward.x)
	var count := kinds.size()
	for i in range(count):
		var group := i % 4           # 0 авангард, 1 лівий фланг, 2 правий фланг, 3 резерв
		var forward := 26.0
		var lateral := randf_range(-9.0, 9.0)
		match group:
			1:
				forward = randf_range(30.0, 44.0)
				lateral = randf_range(-42.0, -26.0)
			2:
				forward = randf_range(30.0, 44.0)
				lateral = randf_range(26.0, 42.0)
			3:
				forward = randf_range(48.0, 62.0)
				lateral = randf_range(-16.0, 16.0)
			_:
				forward = randf_range(22.0, 34.0)
		var pos := _find_free(player_local + toward * forward + side * lateral, toward)
		var props: Dictionary = (KINDS[str(kinds[i])] as Dictionary).duplicate()
		props["detection_range"] = 130.0
		var enemy = world._spawn_special_wraith(pos, props)
		if enemy:
			if bool(squad["closed"]):
				enemy.queue_free()
				return
			_add_member(squad, enemy, i)
			_puff(world.to_global(pos))
		if i % 3 == 2:
			await get_tree().create_timer(0.12).timeout
			if bool(squad["closed"]):
				return
	squad["spawning"] = false


func _find_free(candidate: Vector3, toward: Vector3) -> Vector3:
	## Місце без колізій (будівлі, мури): кілька спроб зі зсувом, інакше ближче до гравця.
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = 0.7
	var pos := candidate
	for attempt in range(SPAWN_MAX_TRIES):
		pos.y = world._terrain_height_at_world(pos.x, pos.z)
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = shape
		q.collision_mask = 1
		q.transform = Transform3D(Basis(), world.to_global(pos + Vector3(0, 1.3, 0)))
		if space.intersect_shape(q, 1).is_empty():
			return pos
		pos = candidate - toward * float(attempt + 1) * 4.5 + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
	pos.y = world._terrain_height_at_world(pos.x, pos.z)
	return pos


func _puff(at: Vector3) -> void:
	var m := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(0.9, 0.9, 0.9)
	m.mesh = bx
	m.material_override = PSXMaterials.make(Color("#4a4048"), 0.0, 1.0, Color.BLACK, 0.0, "none", false)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(m)
	m.global_position = at + Vector3(0, 1.0, 0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(m, "scale", Vector3.ONE * 2.4, 0.7)
	tw.tween_property(m, "position:y", m.position.y + 1.4, 0.7)
	tw.chain().tween_callback(m.queue_free)


# --- Групова поведінка ---------------------------------------------------------------------------

func _alive(squad: Dictionary) -> Array:
	var out: Array = []
	for e in squad["members"]:
		if is_instance_valid(e) and not bool(e.get("dead")):
			out.append(e)
	return out


func _update_squads(player: CharacterBody3D) -> void:
	for si in range(_squads.size() - 1, -1, -1):
		var squad: Dictionary = _squads[si]
		squad["age"] = float(squad["age"]) + TICK
		var alive := _alive(squad)
		# Гравець загинув чи втік далеко: загін розсіюється, битву можна повторити.
		var far := true
		for e in alive:
			if (e as Node3D).global_position.distance_to(player.global_position) < GIVE_UP_DISTANCE:
				far = false
				break
		if player.is_defeated() or (not alive.is_empty() and far):
			_abort_squad(si, squad)
			continue
		if alive.is_empty():
			if bool(squad["spawning"]):
				continue
			_finish_squad(si, squad)
			continue
		_assign(squad, alive, player)


func _assign(squad: Dictionary, alive: Array, player: CharacterBody3D) -> void:
	var p := player.global_position
	var facing := -player.global_transform.basis.z
	facing.y = 0.0
	facing = facing.normalized() if facing.length() > 0.01 else Vector3(0, 0, -1)
	var age: float = squad["age"]
	var roles: Dictionary = squad["roles"]
	var slots: Dictionary = squad["slot"]
	var engaged: Dictionary = squad["engaged"]
	var cap := 4 if alive.size() <= 9 else 5
	var engaged_now := 0
	for e in alive:
		if bool(engaged.get(e, false)):
			engaged_now += 1
	# Кандидати на вступ у бій: чим менший бал — тим раніше.
	var candidates: Array = []
	for e in alive:
		if bool(engaged.get(e, false)):
			continue
		var dist := (e as Node3D).global_position.distance_to(p)
		var role := str(roles.get(e, "hold"))
		var score := dist
		match role:
			"flank":
				if age < 3.5:
					continue
				var goal: Vector3 = (e as Node).get_meta("goal", p)
				if (e as Node3D).global_position.distance_to(goal) > 11.0 and age < 12.0:
					continue
				score += 5.0
			"hold":
				if age < 9.0 and alive.size() > 5:
					continue
				score += 12.0
		candidates.append({"e": e, "s": score})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) < float(b["s"]))
	var free_slots := cap - engaged_now
	for k in range(mini(free_slots, candidates.size())):
		var e = candidates[k]["e"]
		engaged[e] = true
		e.set("squad_engage", true)
	# Позиції тих, хто чекає.
	for e in alive:
		var node := e as Node3D
		var dist := node.global_position.distance_to(p)
		var core := node.get_node_or_null("WraithCoreLight") as OmniLight3D
		if core:
			core.visible = dist < 36.0
		if bool(engaged.get(e, false)):
			continue
		var role := str(roles.get(e, "hold"))
		var slot: Dictionary = slots.get(e, {})
		var goal := p
		if role == "flank":
			# Обхід: зайти гравцеві за спину по дузі ±(35–75)°.
			var back := (-facing).rotated(Vector3.UP, float(slot.get("side", 1.0)) * deg_to_rad(55.0))
			goal = p + back * 8.0
		else:
			var a: float = slot.get("angle", 0.0)
			goal = p + Vector3(cos(a), 0.0, sin(a)) * float(slot.get("ring", 13.0))
		node.set_meta("goal", goal)
		node.set("squad_goal", goal)
	# Застрягли (будівлі, мури) — переносимо ближче до гравця, щоб бій не зависав.
	var stuck: Dictionary = squad["stuck"]
	for e in alive:
		var node := e as Node3D
		var rec: Dictionary = stuck.get(e, {"pos": node.global_position, "t": 0.0})
		var moved := node.global_position.distance_to(rec["pos"] as Vector3)
		var dist2 := node.global_position.distance_to(p)
		if moved < 0.35 and dist2 > 6.5 and not bool(e.get("dead")):
			rec["t"] = float(rec["t"]) + TICK
		else:
			rec["t"] = 0.0
			rec["pos"] = node.global_position
		if float(rec["t"]) > 6.0:
			var a2 := randf() * TAU
			var local_pos: Vector3 = world.to_local(p) + Vector3(cos(a2), 0.0, sin(a2)) * 17.0
			local_pos = _find_free(local_pos, Vector3(cos(a2), 0, sin(a2)))
			_puff(node.global_position)
			node.global_position = world.to_global(local_pos) + Vector3(0, 0.1, 0)
			_puff(node.global_position)
			rec["t"] = 0.0
			rec["pos"] = node.global_position
		stuck[e] = rec


func _finish_squad(index: int, squad: Dictionary) -> void:
	squad["closed"] = true
	_squads.remove_at(index)
	var site_id := str(squad["site"])
	if site_id != "":
		_done_sites[site_id] = true
	var reward := int(squad["reward"])
	if reward > 0:
		QuestManager.reward_coins(reward, "Виграна битва")
	if str(squad["title"]) != "" and (site_id != "" or reward > 0):
		var body := "Ворогів більше немає."
		if reward > 0:
			body += " +%d монет." % reward
		_toast("БИТВУ ВИГРАНО", body, 4.5)
		AudioManager.play_ui("quest_complete", -2.0)


func _abort_squad(index: int, squad: Dictionary) -> void:
	## Гравець загинув або покинув поле бою: вороги розсіюються, бій можна почати знову.
	squad["closed"] = true
	_squads.remove_at(index)
	for e in squad["members"]:
		if is_instance_valid(e) and not bool(e.get("dead")):
			(e as Node).queue_free()
	# Засідка на дорозі не обнуляється: її веде WorldEvents.
