class_name WorldEvents
extends Node
## Події на дорозі до Чорної Гори: пастки, каменепад на серпантині, засідки з флангів, дивні зустрічі
## (привид-крамар, лицар у бочці, скелет-співак) і масова засідка ворожих лицарів хвилями.
## Кінь біля засідки — ключ до її проходження: на швидкості він збиває лицарів.

const TRAP_FRACTIONS: Array = [0.12, 0.3, 0.37, 0.57, 0.7, 0.88]
const FLANK_FRACTIONS: Array = [0.1, 0.33, 0.72]
const KNIGHT_AMBUSH_FRACTION: float = 0.52
const KNIGHT_WAVES: Array = [4, 5, 5]
const NPC_POSTS: Array = [
	{"id": "npc_ghost", "name": "Шепіт", "role": "Привид-крамар", "f": 0.16, "lat": 6.5, "style": "ghost", "robe": "#8a96a8", "accent": "#c8d4e8",
		"toast": "З придорожнього туману виринає прозора постать із візком, повним нічого…"},
	{"id": "npc_barrelknight", "name": "Сер Бочкин", "role": "Лицар, що застряг у бочці", "f": 0.38, "lat": -6.0, "style": "barrelknight", "robe": "#4a4d57", "accent": "#a8431f",
		"toast": "Із узбіччя долинає приглушений крик: хтось у латах застряг у бочці!"},
	{"id": "npc_bard", "name": "Гнат Кісточка", "role": "Скелет-співак", "f": 0.6, "lat": 6.0, "style": "bard", "robe": "#5a3a4a", "accent": "#d8c060",
		"toast": "Біля дороги хтось дуже скрипучим голосом виводить балади…"},
]

var world = null
var main = null
var _road: Array = []
var _path: PackedVector3Array = PackedVector3Array()
var _traps: Array = []        # {node, jaw_l, jaw_r, pos, armed, rearm}
var _rockfalls: Array = []    # {center, armed, cd}
var _flanks: Array = []       # {center, done}
var _posts: Array = []        # {spec, pos, spawned}
var _check: float = 0.0
var _slow_left: float = 0.0
# Засідка лицарів
var _amb_center: Vector3 = Vector3.ZERO
var _amb_state: String = "idle"   # idle | fighting | done
var _amb_wave: int = 0
var _amb_wave_t: float = 0.0
var _knights: Array = []
var _ghost_bought: bool = false
var _bard_paid: bool = false
var _bard_listened: bool = false


func setup(world_node) -> void:
	world = world_node
	main = world.get_parent()
	_road = world.routes_3d[1] if world.routes_3d.size() > 1 else []
	if _road.size() < 2:
		return
	if world.terrain_builder:
		_path = world.terrain_builder.get("mountain_path")
	_build_traps()
	_build_rockfalls()
	for f in FLANK_FRACTIONS:
		_flanks.append({"center": _road_point(float(f), 0.0), "done": false})
	for spec in NPC_POSTS:
		_posts.append({"spec": spec, "pos": _road_point(float(spec["f"]), float(spec["lat"])), "spawned": false})
	_amb_center = _road_point(KNIGHT_AMBUSH_FRACTION, 0.0)
	# Кінь на узбіччі перед ділянкою засідки.
	if world.horses:
		world.horses.add_horse(_road_point(KNIGHT_AMBUSH_FRACTION - 0.045, 4.5), 0.6, Color("#3a2a22"))


func _road_point(fraction: float, lateral: float) -> Vector3:
	var p: Vector3 = world._polyline_point(_road, fraction)
	var q: Vector3 = world._polyline_point(_road, minf(fraction + 0.01, 1.0))
	var dir := Vector3(q.x - p.x, 0.0, q.z - p.z)
	if dir.length() < 0.01:
		dir = Vector3(0, 0, 1)
	dir = dir.normalized()
	var perp := Vector3(-dir.z, 0.0, dir.x)
	var r := p + perp * lateral
	r.y = world._terrain_height_at_world(r.x, r.z)
	return r


func _player() -> CharacterBody3D:
	return world.get("player_ref") as CharacterBody3D


func _toast(title: String, body: String, seconds: float = 4.0) -> void:
	if main and main.has_method("_show_story_toast"):
		main.call("_show_story_toast", title, body, seconds)


func _smoke(at: Vector3, color: Color = Color("#8a8a92")) -> void:
	var mat := PSXMaterials.make(color, 0.0, 1.0, Color.BLACK, 0.0, "none", false)
	for i in range(10):
		var m := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3.ONE * randf_range(0.25, 0.5)
		m.mesh = bx
		m.material_override = mat
		get_tree().current_scene.add_child(m)
		m.global_position = at
		var dir := Vector3(randf_range(-1, 1), randf_range(0.3, 1.3), randf_range(-1, 1))
		var tw := create_tween().set_parallel(true)
		tw.tween_property(m, "global_position", at + dir * 1.6, 0.9)
		tw.tween_property(m, "scale", Vector3.ONE * 0.05, 0.9)
		tw.chain().tween_callback(m.queue_free)


# --- Побудова ---------------------------------------------------------------------------------------

func _build_traps() -> void:
	var iron := PSXMaterials.make(Color("#4a4c52"), 0.8, 0.45, Color.BLACK, 0.0, "metal", false)
	var rust := PSXMaterials.make(Color("#6a3a20"), 0.5, 0.7, Color.BLACK, 0.0, "metal", false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 818
	for f in TRAP_FRACTIONS:
		var pos := _road_point(float(f), rng.randf_range(-1.4, 1.4))
		var node := Node3D.new()
		node.name = "BearTrap"
		world.add_child(node)
		node.position = pos
		node.rotation.y = rng.randf() * TAU
		var plate := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(0.5, 0.05, 0.4)
		plate.mesh = pb
		plate.material_override = rust
		plate.position = Vector3(0, 0.03, 0)
		node.add_child(plate)
		var jaws: Array = []
		for sz: float in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(0, 0.06, sz * 0.2)
			node.add_child(pivot)
			var jaw := MeshInstance3D.new()
			var jb := BoxMesh.new()
			jb.size = Vector3(0.5, 0.04, 0.22)
			jaw.mesh = jb
			jaw.material_override = iron
			jaw.position = Vector3(0, 0, -sz * 0.11)
			pivot.add_child(jaw)
			for k in range(5):
				var tooth := MeshInstance3D.new()
				var tb := BoxMesh.new()
				tb.size = Vector3(0.04, 0.09, 0.03)
				tooth.mesh = tb
				tooth.material_override = iron
				tooth.position = Vector3(-0.2 + float(k) * 0.1, 0.05, -sz * 0.21)
				pivot.add_child(tooth)
			pivot.rotation.x = sz * deg_to_rad(-62.0)
			jaws.append(pivot)
		_traps.append({"node": node, "jaws": jaws, "pos": pos, "armed": true, "rearm": 0.0})


func _build_rockfalls() -> void:
	if _path.size() < 20:
		return
	for frac in [0.3, 0.55, 0.8]:
		var idx := clampi(int(float(_path.size() - 1) * float(frac)), 1, _path.size() - 2)
		_rockfalls.append({"center": _path[idx], "armed": true, "cd": 0.0})


# --- Цикл ---------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	var player := _player()
	if player == null:
		return
	if _slow_left > 0.0:
		_slow_left -= delta
		if _slow_left <= 0.0:
			player.set_meta("slow_mult", 1.0)
	for t in _traps:
		if not bool(t["armed"]):
			t["rearm"] = float(t["rearm"]) - delta
			if float(t["rearm"]) <= 0.0:
				_set_trap(t, true)
	if _amb_state == "fighting":
		_amb_wave_t += delta
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.1
	if not world.hazards._outdoors_active():
		return
	var local: Vector3 = world.to_local(player.global_position)
	_check_traps(player, local)
	_check_rockfalls(player, local)
	_check_flanks(local)
	_check_posts(local)
	_check_knight_ambush(local)


func _set_trap(t: Dictionary, open: bool) -> void:
	t["armed"] = open
	var jaws: Array = t["jaws"]
	for i in range(jaws.size()):
		var sz := -1.0 if i == 0 else 1.0
		var tw := create_tween()
		tw.tween_property(jaws[i], "rotation:x", sz * deg_to_rad(-62.0) if open else 0.0, 0.12)


func _check_traps(player: CharacterBody3D, local: Vector3) -> void:
	for t in _traps:
		if not bool(t["armed"]):
			continue
		var p: Vector3 = t["pos"]
		if Vector2(p.x - local.x, p.z - local.z).length() < 0.8 and absf(local.y - p.y) < 2.5 and player.is_on_floor():
			_set_trap(t, false)
			t["rearm"] = 40.0
			player.call("take_damage", 10.0, self)
			player.set_meta("slow_mult", 0.35)
			_slow_left = 2.5
			AudioManager.play_sfx("block_thud", 2.0, 0.05)
			AudioManager.play_sfx("parry_ring", -4.0, 0.1)
			_toast("ПАСТКА!", "Ведмежий капкан клацнув на нозі — рух сповільнено. Дивись під ноги!", 3.0)


func _check_rockfalls(player: CharacterBody3D, local: Vector3) -> void:
	for r in _rockfalls:
		var c: Vector3 = r["center"]
		var d := Vector2(c.x - local.x, c.z - local.z).length()
		if not bool(r["armed"]):
			if d > 28.0 and float(r["cd"]) <= 0.0:
				r["armed"] = true
			r["cd"] = float(r["cd"]) - 0.1
			continue
		if d < 8.0 and absf(local.y - c.y) < 6.0:
			r["armed"] = false
			r["cd"] = 60.0
			_rockfall(player)


func _rockfall(player: CharacterBody3D) -> void:
	_toast("ГРУКІТ ЗВЕРХУ!", "Схил здригається — червоні кола показують, де впаде каміння. Відскочи!", 3.0)
	AudioManager.play_sfx("land", 4.0, 0.0)
	var ring_mat := PSXMaterials.make(Color(1.0, 0.15, 0.08, 0.5), 0.0, 1.0, Color("#ff2a10"), 1.8, "none", false, true)
	var rock_mat := PSXMaterials.make(Color("#3a383d"), 0.0, 0.95, Color.BLACK, 0.0, "rock", false)
	var spots: Array = []
	var base := player.global_position
	spots.append(base + player.velocity * 0.8)
	for i in range(3):
		spots.append(base + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5)))
	var rings: Array = []
	for s in spots:
		var ring := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 2.0
		cyl.bottom_radius = 2.0
		cyl.height = 0.05
		ring.mesh = cyl
		ring.material_override = ring_mat
		get_tree().current_scene.add_child(ring)
		var g: Vector3 = world.to_local(s)
		g.y = world._terrain_height_at_world(g.x, g.z) + 0.1
		ring.global_position = world.to_global(g)
		rings.append(ring)
	await get_tree().create_timer(1.6).timeout
	for i in range(spots.size()):
		var ring: MeshInstance3D = rings[i]
		var ground: Vector3 = ring.global_position
		var rock := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(1.8, 1.5, 1.6)
		rock.mesh = rb
		rock.material_override = rock_mat
		get_tree().current_scene.add_child(rock)
		rock.global_position = ground + Vector3(0, 22.0, 0)
		rock.rotation = Vector3(randf(), randf(), randf())
		var tw := create_tween()
		tw.tween_property(rock, "global_position", ground + Vector3(0, 0.6, 0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			AudioManager.play_sfx_3d("block_thud", ground, 3.0, 40.0, 6.0)
			_smoke(ground + Vector3(0, 0.6, 0), Color("#6a5a48"))
			if is_instance_valid(player) and Vector2(player.global_position.x - ground.x, player.global_position.z - ground.z).length() < 2.3 and player.global_position.y - ground.y < 2.5:
				player.call("take_damage", 14.0, self))
		tw.tween_interval(6.0)
		tw.tween_property(rock, "scale", Vector3.ONE * 0.01, 1.0)
		tw.tween_callback(rock.queue_free)
		ring.queue_free()


func _spawn_enemy(local_pos: Vector3, props: Dictionary) -> Node:
	return world._spawn_special_wraith(local_pos, props)


func _check_flanks(local: Vector3) -> void:
	for f in _flanks:
		if bool(f["done"]):
			continue
		var c: Vector3 = f["center"]
		if Vector2(c.x - local.x, c.z - local.z).length() < 17.0:
			f["done"] = true
			_toast("ЗАСІДКА З ФЛАНГІВ", "Із-за каміння виринають тіні — вони обходять тебе з боків!", 3.0)
			AudioManager.play_sfx("wraith_growl", 2.0, 0.1)
			for i in range(3):
				var a := TAU * float(i) / 3.0 + 1.1
				var p := c + Vector3(cos(a), 0, sin(a)) * 13.0
				p.y = world._terrain_height_at_world(p.x, p.z)
				_spawn_enemy(p, {"enemy_type": "ashen_wraith", "display_name": "Засадник", "max_health": 80.0, "detection_range": 40.0, "scale": 1.05})


# --- Дивні зустрічі ----------------------------------------------------------------------------------------------

func _check_posts(local: Vector3) -> void:
	for post in _posts:
		if bool(post["spawned"]):
			continue
		var pos: Vector3 = post["pos"]
		if Vector2(pos.x - local.x, pos.z - local.z).length() < 32.0:
			post["spawned"] = true
			var spec: Dictionary = post["spec"]
			var toward: Vector3 = world.to_global(_road_point(float(spec["f"]), 0.0)) - world.to_global(pos)
			var facing := atan2(-toward.x, -toward.z) + PI
			var npc: Node3D = world._create_world_npc(str(spec["id"]), str(spec["name"]), str(spec["role"]), pos, str(spec["robe"]), str(spec["accent"]), str(spec["style"]), facing)
			_smoke(world.to_global(pos) + Vector3(0, 1.0, 0), Color("#a8a8b8"))
			AudioManager.play_ui("discover")
			_toast("ДИВНА ЗУСТРІЧ", str(spec["toast"]), 4.5)
			if str(spec["id"]) == "npc_barrelknight":
				var barrel := MeshInstance3D.new()
				barrel.name = "KnightBarrel"
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.55
				cyl.bottom_radius = 0.5
				cyl.height = 0.95
				cyl.radial_segments = 8
				barrel.mesh = cyl
				barrel.material_override = PSXMaterials.make(Color("#5a402b"), 0.0, 0.85, Color.BLACK, 0.0, "planks", false)
				barrel.position = Vector3(0, 0.5, 0)
				npc.add_child(barrel)


func handle_interaction(interaction_id: String) -> bool:
	match interaction_id:
		"npc_ghost":
			main.call("_show_world_dialogue", "ШЕПІТ — ПРИВИД-КРАМАР", "Ш-ш-ш… Вітаю, живий! Продаю найкращий товар у світі, якого ніхто не бачив. Усе з довічною гарантією: помрете — гроші не повернемо.\n\n«Банка Темряви» — темрява найвищої якості, відкривати лише вночі. «Пучок Минулого Тижня» — свіжі трави з іншого понеділка.", [
				{"label": "КУПИТИ БАНКУ ТЕМРЯВИ  (5 монет)", "action": "event:ghost_jar"},
				{"label": "КУПИТИ ПУЧОК МИНУЛОГО ТИЖНЯ  (3 монети)", "action": "event:ghost_leaf"},
			])
			return true
		"npc_barrelknight":
			main.call("_show_world_dialogue", "СЕР БОЧКИН", "Мммф! Я, сер Бочкин, Пострах Трьох Королівств, застряг у бочці! Не питайте як. Це була засідка. Бочкова. Дуже підступна!\n\nВитягніть мене, і я — ну, в загальному, дякую. Можливо, навіть заплачу.", [
				{"label": "ВИТЯГНУТИ ЛИЦАРЯ З БОЧКИ", "action": "event:knight_pull"},
			])
			return true
		"npc_bard":
			var body := "Ах, мандрівнику! Мої кістки скриплять від натхнення! Послухай «Оду до Власної Ключиці», хіт трьох останніх епох!\n\n«О, ключице моя, ти така… ключична!»"
			if _bard_listened and _bard_paid:
				body = "Дякую за гонорар, друже! Більше не маю чим віддячити, окрім ще однієї оди. Не треба? Ну й добре."
			main.call("_show_world_dialogue", "ГНАТ КІСТОЧКА — СКЕЛЕТ-СПІВАК", body, [
				{"label": "ПОСЛУХАТИ ОДУ (безкоштовно)", "action": "event:bard_listen"},
				{"label": "ЗАПЛАТИТИ ГОНОРАР  (10 монет)", "action": "event:bard_pay"},
			])
			return true
	return false


func _coins() -> int:
	return int(main.get("score"))


func _spend(amount: int) -> bool:
	if _coins() < amount:
		_toast("БРАКУЄ МОНЕТ", "Потрібно %d монет." % amount, 2.5)
		return false
	main.set("score", _coins() - amount)
	main.call("_update_score")
	return true


func on_action(action: String) -> void:
	var player := _player()
	match action:
		"event:ghost_jar":
			if _spend(5):
				QuestManager.add_item("dark_jar", "Банка Темряви")
				_toast("ТОВАР ПРИДБАНО", "Банка Темряви. Всередині — суцільна темрява. Гарантія: довічна (твоя).", 4.0)
		"event:ghost_leaf":
			if _spend(3) and player:
				player.call("heal", 12.0)
				_toast("СВІЖИЙ ПУЧОК", "Трави з минулого тижня на смак як сьогодні. +12 здоров'я.", 3.5)
		"event:knight_pull":
			_toast("ЛИЦАР ЗВІЛЬНЕНИЙ", "Бочка лунає, як дзвін. Сер Бочкин вистрибує, кидає 25 монет і з криком «Це не кінець!» тікає в туман.", 5.0)
			QuestManager.reward_coins(25, "Сер Бочкин")
			var node := world.get_node_or_null("npc_barrelknight") as Node3D
			if node:
				_smoke(node.global_position + Vector3(0, 1.0, 0))
				node.queue_free()
			for i in range(world.world_interactions.size() - 1, -1, -1):
				if str(world.world_interactions[i].get("id", "")) == "npc_barrelknight":
					world.world_interactions.remove_at(i)
		"event:bard_listen":
			_bard_listened = true
			if player:
				player.call("heal", 10.0)
			_toast("ОДА ДО КЛЮЧИЦІ", "Так жахливо, що аж щемить у грудях… і чомусь стає легше. +10 здоров'я.", 4.0)
		"event:bard_pay":
			if not _bard_paid and _spend(10):
				_bard_paid = true
				if player:
					player.set_meta("arrows", int(player.get_meta("arrows", 0)) + 10)
				_toast("ГОНОРАР ПРИЙНЯТО", "Гнат у захваті. Він дарує тобі 10 стріл «з власного ребра». Тримай.", 4.0)
			elif _bard_paid:
				_toast("ГНАТ", "Гонорар уже отримано. Ще одну оду?", 2.5)


# --- Масова засідка ворожих лицарів ---------------------------------------------------------------

func _check_knight_ambush(local: Vector3) -> void:
	if _amb_state == "done":
		return
	if _amb_state == "idle":
		if Vector2(_amb_center.x - local.x, _amb_center.z - local.z).length() < 58.0:
			_amb_state = "fighting"
			_amb_wave = 0
			_amb_wave_t = 0.0
			AudioManager.play_sfx("wolf_howl", 2.0, 0.0)
			_toast("ЗАСІДКА ЛИЦАРІВ ЧОРНОГО ПРАПОРА", "З обох боків дороги вискакують лицарі! Біля узбіччя стоїть кінь: сядь (E), розженися і топчи їх — шеренги не витримають скачки.", 7.0)
			_spawn_wave()
		return
	# Наступна хвиля — коли попередню майже розбито або минуло 30 с.
	var alive := _alive_knights()
	if _amb_wave < KNIGHT_WAVES.size() and (alive <= 1 or _amb_wave_t > 30.0):
		_spawn_wave()
	elif _amb_wave >= KNIGHT_WAVES.size() and alive == 0:
		_amb_state = "done"
		QuestManager.reward_coins(80, "Розбита засідка лицарів")
		_toast("ЗАСІДКУ РОЗБИТО", "Усі 14 лицарів Чорного Прапора лежать на дорозі. Шлях до гори вільний. +80 монет.", 6.0)
		AudioManager.play_ui("quest_complete")


func _alive_knights() -> int:
	var n := 0
	for k in _knights:
		if is_instance_valid(k) and not bool(k.get("dead")):
			n += 1
	return n


func _spawn_wave() -> void:
	var count := int(KNIGHT_WAVES[_amb_wave])
	_amb_wave += 1
	_amb_wave_t = 0.0
	if _amb_wave > 1:
		_toast("НОВИЙ ЗАГІН", "Хвиля %d з %d: підкріплення виходить із тіней." % [_amb_wave, KNIGHT_WAVES.size()], 3.0)
		AudioManager.play_sfx("wraith_growl", 2.0, 0.1)
	var p := _road_point(KNIGHT_AMBUSH_FRACTION, 0.0)
	var q := _road_point(KNIGHT_AMBUSH_FRACTION + 0.01, 0.0)
	var dir := Vector3(q.x - p.x, 0.0, q.z - p.z).normalized()
	var perp := Vector3(-dir.z, 0.0, dir.x)
	for i in range(count):
		# Лицарі розставлені по обидва боки дороги й уздовж неї (не в одній точці й не на самій дорозі).
		var side := 1.0 if i % 2 == 0 else -1.0
		var pos := p + perp * side * randf_range(9.0, 24.0) + dir * randf_range(-30.0, 30.0)
		pos.y = world._terrain_height_at_world(pos.x, pos.z)
		var knight = _spawn_enemy(pos, {
			"enemy_type": "ashen_wraith", "visual_type": "enemy_knight", "display_name": "ВОРОЖИЙ ЛИЦАР",
			"max_health": 85.0, "attack_damage": 13.0, "move_speed": 3.1, "detection_range": 95.0, "scale": 1.05, "reward_override": 8,
		})
		if knight:
			_knights.append(knight)
			# Групова поведінка: штурмовики, обхідники та резерв; музика масового бою.
			if world.mass:
				world.mass.adopt("road_ambush", knight, "", 0)
		await get_tree().create_timer(0.35).timeout
