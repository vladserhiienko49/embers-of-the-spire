class_name WorldSurprises
extends Node
## Режисер раптових подій подорожі: розширює існуючі WorldHazards (змії, ворони-нападники, гриби)
## та WorldEvents (пастки, дивні зустрічі на тракті), не дублюючи їх. Керована випадковість:
## різні ваги, власні «охолодження» для кожної події, пауза після будь-якої з них, рідкісні події
## трапляються нечасто й помітно відрізняються від звичайних. Лише атмосфера й дрібні небезпеки.

const FIRST_DELAY: Vector2 = Vector2(55.0, 100.0)
const GAP: Vector2 = Vector2(70.0, 150.0)
const RARE_EXTRA_GAP: float = 90.0

## id, вага, охолодження (с), чи рідкісна, нічна перевага (0 — денна, 1 — нічна, 0.5 — однаково)
const EVENTS: Array = [
	{"id": "ravens_takeoff", "w": 5.0, "cd": 110.0, "rare": false, "night": 0.2},
	{"id": "strange_sound", "w": 6.0, "cd": 80.0, "rare": false, "night": 0.7},
	{"id": "distant_creature", "w": 3.0, "cd": 240.0, "rare": false, "night": 0.8},
	{"id": "sudden_enemy", "w": 3.0, "cd": 190.0, "rare": false, "night": 0.6},
	{"id": "omen_ravens", "w": 2.0, "cd": 400.0, "rare": false, "night": 0.4},
	{"id": "oddball", "w": 2.0, "cd": 330.0, "rare": false, "night": 0.6},
	{"id": "pale_lights", "w": 1.0, "cd": 720.0, "rare": true, "night": 1.0},
]

## «Чудіки»: дивні, але похмурі. Репліка при появі, діалог за E, потім зникають.
const ODDBALLS: Dictionary = {
	"counter": {"name": "Той, що рахує", "role": "Лічильник", "style": "druid", "robe": "#4a4a52", "accent": "#a8a8b8",
		"toast": "Із кущів зіскакує постать у каптурі й шепоче: «…дев'ятсот сорок один… сорок два… а ти — сорок третій!»",
		"talk": "Я рахую тих, хто проходить цією дорогою. Позаминулого тижня було шістнадцять. Минулого — жодного. Тепер ти. Не збивай мене, будь ласка: на кожному числі я щось втрачаю.",
		"ask": "ЗАПИТАТИ: ЩО СТАЛОСЯ З ТИМИ, ХТО ПРОХОДИВ?",
		"answer": "Вони ще на дорозі. Просто я більше не бачу їх при світлі. Рахую — і вони трохи реальніші. Йди, сорок третій. Йди повільно: Око любить тих, хто поспішає."},
	"lantern": {"name": "Дівчинка з ліхтарем", "role": "Нічна гостя", "style": "woman", "robe": "#8a96b4", "accent": "#d8e4ff",
		"toast": "На дорозі стоїть бліда дівчинка з ліхтарем. Вона не кліпає. «Не йди туди, де не горять вогні», — каже вона.",
		"talk": "Не йди туди, де не горять вогні. Там уже всіх порахували. Мій ліхтар не гасне, бо його нема кому погасити. Хочеш — візьми трохи світла. Лише трохи.",
		"ask": "ВЗЯТИ ТРОХИ СВІТЛА",
		"answer": "Тепле світло лягає на плечі, і рани тихо стягуються. Дівчинка киває й розчиняється в повітрі разом із ліхтарем. +20 здоров'я."},
	"stone": {"name": "Тихон Каменяр", "role": "Той, що слухає каміння", "style": "villager", "robe": "#5a5046", "accent": "#a89478",
		"toast": "Із бур'яну виринає чоловік, прикладає вухо до каменя й шипить: «Тсс! Він майже відповів!»",
		"talk": "Камінь пам'ятає більше за нас. Двадцять літ питаю одне: що сталося з Короною? Він мовчить… але вночі іноді зітхає. Сьогодні — не зітхнув. Це погано.",
		"ask": "ЗАПИТАТИ: ЩО КАМІНЬ ГОВОРИТЬ ПРО ОКО?",
		"answer": "Тільки одне слово, давно. «Дивиться.» Не «стежить», не «чекає» — «дивиться». Наче воно вже тут. Прикрий хоч спину плащем, чужинцю."},
	"crow": {"name": "Дід Крук", "role": "Годувальник воронів", "style": "elder", "robe": "#2c2c34", "accent": "#8a7a4a",
		"toast": "Старий із кошиком крихт вискакує зі рівчака: «Не руш! Вони мої! Сьогодні далеко хтось помре — я знаю!»",
		"talk": "Вони сідають там, де буде мертвий. Я годую їх — вони розповідають мені. Сьогодні розповіли про дорогу на південь. Не питай, про що саме. Хоча… у тебе на плечі вже сиділа одна. Ні, привиділося.",
		"ask": "ВІДДАТИ ХЛІБА ЗА ПОРАДУ  (3 монети)",
		"answer": "Дід дякує, кидає вороні крихту й показує на схід: «Там кружляють». Якщо побачиш чорні кола над лісом — ідеш обережно або не ідеш зовсім."},
}

var world = null
var main = null
var _rng := RandomNumberGenerator.new()
var _timer: float = 80.0
var _clock: float = 0.0
var _last_used: Dictionary = {}
var _flocks: Array = []           # {birds: Array, kind: String, center: Vector3, state: String, t: float, resolved: bool}
var _creatures: Array = []        # {node, dir, t, life, speed, kind, step}
var _oddballs: Array = []         # {id, type, node, t, state}
var _odd_counter: int = 0
var _check: float = 0.0


func setup(world_node) -> void:
	world = world_node
	main = world.get_parent()
	_rng.randomize()
	_timer = _rng.randf_range(FIRST_DELAY.x, FIRST_DELAY.y)


func _player() -> CharacterBody3D:
	return world.get("player_ref") as CharacterBody3D


func _toast(title: String, body: String, seconds: float = 4.0) -> void:
	if main and main.has_method("_show_story_toast"):
		main.call("_show_story_toast", title, body, seconds)


func _process(delta: float) -> void:
	_clock += delta
	_update_flocks(delta)
	_update_creatures(delta)
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.5
	_update_oddballs(0.5)
	_update_omens()
	var player := _player()
	if player == null or world.hazards == null or not world.hazards._outdoors_active():
		return
	if world.mass and world.mass.is_battle_active():
		return
	# Таймер іде лише під час подорожі: стоячи на місці — повільніше.
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	_timer -= 0.5 * (1.0 if speed > 1.2 else 0.25)
	if _timer > 0.0:
		return
	if _try_event(player):
		_timer = _rng.randf_range(GAP.x, GAP.y)
	else:
		_timer = 8.0     # умови не підійшли — спробуємо трохи згодом


# --- Вибір події ----------------------------------------------------------------------------------

func _try_event(player: CharacterBody3D) -> bool:
	if world.hazards._near_building(player, 30.0) or world.hazards._enemy_near(player, 38.0):
		return false
	if world.to_local(player.global_position).y > 95.0:
		return false  # на вершині — арена Ока: ніяких «дрібниць»
	var night := clampf(world.get_night_amount(), 0.0, 1.0)
	var pool: Array = []
	var total := 0.0
	for ev in EVENTS:
		var id := str(ev["id"])
		if _clock - float(_last_used.get(id, -9999.0)) < float(ev["cd"]):
			continue
		if id in ["ravens_takeoff", "omen_ravens"] and world.hazards._ravens_active:
			continue
		if id == "oddball" and not _oddballs.is_empty():
			continue
		if id == "omen_ravens" and _has_omen():
			continue
		# Нічні події частіші вночі, денні — вдень.
		var pref: float = float(ev["night"])
		var weight: float = float(ev["w"]) * lerpf(1.0 - pref, pref, night) * 2.0
		if bool(ev["rare"]):
			weight *= 0.8 if night > 0.5 else 0.15
		if weight <= 0.0:
			continue
		pool.append([id, weight, bool(ev["rare"])])
		total += weight
	if pool.is_empty():
		return false
	var pick := _rng.randf() * total
	var chosen: Array = pool[0]
	for item in pool:
		pick -= float(item[1])
		if pick <= 0.0:
			chosen = item
			break
	var ok := _run(str(chosen[0]), player)
	if ok:
		_last_used[str(chosen[0])] = _clock
		if bool(chosen[2]):
			_timer = RARE_EXTRA_GAP
	return ok


func _run(id: String, player: CharacterBody3D) -> bool:
	match id:
		"ravens_takeoff":
			return _ev_ravens_takeoff(player)
		"strange_sound":
			return _ev_strange_sound(player)
		"distant_creature":
			return _ev_distant_creature(player)
		"sudden_enemy":
			return _ev_sudden_enemy(player)
		"omen_ravens":
			return _ev_omen_ravens(player)
		"oddball":
			return _ev_oddball(player)
		"pale_lights":
			return _ev_pale_lights(player)
	return false


func debug_run(id: String) -> bool:
	## Для перевірки: запустити конкретну подію негайно.
	var player := _player()
	return player != null and _run(id, player)


# --- Допоміжне: точки навколо гравця ---------------------------------------------------------------

func _heading(player: CharacterBody3D) -> Vector3:
	var h := Vector3(player.velocity.x, 0.0, player.velocity.z)
	if h.length() < 1.0:
		h = -player.global_transform.basis.z
		h.y = 0.0
	return h.normalized() if h.length() > 0.01 else Vector3(0, 0, -1)


func _point_ahead(player: CharacterBody3D, dist: float, spread_deg: float) -> Vector3:
	## Точка у локальних координатах світу, поперед гравця (або збоку), на землі.
	var dir := _heading(player).rotated(Vector3.UP, deg_to_rad(_rng.randf_range(-spread_deg, spread_deg)))
	var local: Vector3 = world.to_local(player.global_position) + dir * dist
	local.y = world._terrain_height_at_world(local.x, local.z)
	return local


func _near_building_local(local: Vector3, radius: float) -> bool:
	for b in world.building_nodes.values():
		var n := b as Node3D
		if n and Vector2(n.position.x - local.x, n.position.z - local.z).length() < radius:
			return true
	return false


func _puff(at_global: Vector3, color: Color = Color("#6a6a76"), count: int = 8) -> void:
	var mat := PSXMaterials.make(color, 0.0, 1.0, Color.BLACK, 0.0, "none", false)
	for i in range(count):
		var m := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3.ONE * _rng.randf_range(0.25, 0.5)
		m.mesh = bx
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		get_tree().current_scene.add_child(m)
		m.global_position = at_global
		var dir := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.3, 1.3), _rng.randf_range(-1, 1))
		var tw := create_tween().set_parallel(true)
		tw.tween_property(m, "global_position", at_global + dir * 1.6, 0.9)
		tw.tween_property(m, "scale", Vector3.ONE * 0.05, 0.9)
		tw.chain().tween_callback(m.queue_free)


# --- Птахи ---------------------------------------------------------------------------------------------

func _make_bird() -> Dictionary:
	var root := Node3D.new()
	var black := PSXMaterials.make(Color("#101016"), 0.1, 0.8, Color.BLACK, 0.0, "none", false)
	var body := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.2, 0.18, 0.42)
	body.mesh = bb
	body.material_override = black
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(body)
	var head := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(0.13, 0.13, 0.16)
	head.mesh = hb
	head.material_override = black
	head.position = Vector3(0, 0.05, -0.27)
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(head)
	var wings: Array = []
	for sx: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(sx * 0.08, 0.04, 0.0)
		root.add_child(pivot)
		var w := MeshInstance3D.new()
		var wb := BoxMesh.new()
		wb.size = Vector3(0.62, 0.025, 0.3)
		w.mesh = wb
		w.material_override = black
		w.position = Vector3(sx * 0.31, 0, 0)
		w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(w)
		wings.append(pivot)
	world.add_child(root)
	return {"node": root, "wl": wings[0], "wr": wings[1], "t": _rng.randf() * 6.0, "vel": Vector3.ZERO,
		"angle": 0.0, "radius": 8.0, "height": 15.0, "speed": 0.6, "life": 12.0}


func _spawn_flock(kind: String, center: Vector3, count: int) -> Dictionary:
	var flock := {"birds": [], "kind": kind, "center": center, "state": "circle" if kind == "circle" else "takeoff", "t": 0.0, "resolved": false}
	for i in range(count):
		var b := _make_bird()
		var node: Node3D = b["node"]
		if kind == "circle":
			b["angle"] = TAU * float(i) / float(count)
			b["radius"] = _rng.randf_range(6.0, 11.0)
			b["height"] = _rng.randf_range(13.0, 19.0)
			b["speed"] = _rng.randf_range(0.5, 0.85) * (1.0 if i % 2 == 0 else -0.8)
			node.position = center + Vector3(0, b["height"], 0)
		else:
			node.position = center + Vector3(_rng.randf_range(-1.2, 1.2), _rng.randf_range(0.6, 1.6), _rng.randf_range(-1.2, 1.2))
		(flock["birds"] as Array).append(b)
	_flocks.append(flock)
	return flock


func _scatter(flock: Dictionary, away: Vector3) -> void:
	flock["state"] = "takeoff"
	for b in flock["birds"]:
		var d := away.rotated(Vector3.UP, _rng.randf_range(-0.9, 0.9))
		b["vel"] = d * _rng.randf_range(4.0, 7.0) + Vector3(0, _rng.randf_range(5.0, 8.5), 0)
		b["life"] = 11.0


func _update_flocks(delta: float) -> void:
	var player := _player()
	for fi in range(_flocks.size() - 1, -1, -1):
		var flock: Dictionary = _flocks[fi]
		flock["t"] = float(flock["t"]) + delta
		var birds: Array = flock["birds"]
		for bi in range(birds.size() - 1, -1, -1):
			var b: Dictionary = birds[bi]
			var node: Node3D = b["node"]
			if not is_instance_valid(node):
				birds.remove_at(bi)
				continue
			b["t"] = float(b["t"]) + delta
			var flap_rate := 15.0
			if str(flock["state"]) == "wait":
				continue
			if str(flock["state"]) == "circle":
				b["angle"] = float(b["angle"]) + float(b["speed"]) * delta
				var c: Vector3 = flock["center"]
				var a: float = b["angle"]
				var target := c + Vector3(cos(a) * float(b["radius"]), float(b["height"]) + sin(float(b["t"]) * 0.8) * 1.5, sin(a) * float(b["radius"]))
				var prev := node.position
				node.position = target
				var dir := target - prev
				if dir.length() > 0.001:
					node.look_at(node.global_position + world.global_transform.basis * dir, Vector3.UP)
				flap_rate = 7.0
			else:
				var vel: Vector3 = b["vel"]
				if vel.length() < 0.1:
					vel = Vector3(0, 5, 0)
				vel.y += 1.6 * delta
				vel += vel.normalized() * 2.0 * delta
				b["vel"] = vel
				node.position += vel * delta
				node.look_at(node.global_position + world.global_transform.basis * vel, Vector3.UP)
				b["life"] = float(b["life"]) - delta
				if float(b["life"]) <= 0.0 or (player and node.global_position.distance_to(player.global_position) > 150.0):
					node.queue_free()
					birds.remove_at(bi)
					continue
			var flap := sin(float(b["t"]) * flap_rate) * 0.85
			(b["wl"] as Node3D).rotation.z = -flap
			(b["wr"] as Node3D).rotation.z = flap
		if birds.is_empty():
			_flocks.remove_at(fi)


func _has_omen() -> bool:
	for f in _flocks:
		if str(f["kind"]) == "circle" and not bool(f["resolved"]):
			return true
	return false


# --- Події ------------------------------------------------------------------------------------------------

func _ev_ravens_takeoff(player: CharacterBody3D) -> bool:
	var spot := _point_ahead(player, _rng.randf_range(15.0, 24.0), 55.0)
	if _near_building_local(spot, 14.0):
		return false
	var flock := _spawn_flock("takeoff", spot, _rng.randi_range(8, 13))
	_puff(world.to_global(spot + Vector3(0, 1.0, 0)), Color("#2a3a2a"), 6)
	AudioManager.play_sfx_3d("crow", world.to_global(spot + Vector3(0, 2, 0)), 3.0, 70.0, 12.0)
	var away: Vector3 = world.to_local(player.global_position) - spot
	away.y = 0.0
	flock["state"] = "wait"
	# Зграя злітає не відразу, а за мить: на шум кроків.
	var scatter_dir := -away.normalized()
	get_tree().create_timer(0.35).timeout.connect(func() -> void:
		if not (flock["birds"] as Array).is_empty():
			_scatter(flock, scatter_dir)
		AudioManager.play_sfx_3d("crow", world.to_global(spot + Vector3(0, 6, 0)), 1.0, 70.0, 12.0))
	get_tree().create_timer(0.9).timeout.connect(func() -> void:
		AudioManager.play_sfx_3d("crow", world.to_global(spot + Vector3(0, 9, 0)), 1.0, 70.0, 12.0))
	return true


func _ev_strange_sound(player: CharacterBody3D) -> bool:
	var night: float = world.get_night_amount()
	var options: Array = [
		["strange_whisper", "ШЕПІТ", "Поруч хтось шепоче. Ти озираєшся — нікого."],
		["strange_scrape", "СКРЕГІТ", "Десь скрегоче залізо, наче волокли щось важке. Джерела не видно."],
		["far_horn", "РІГ", "Із глибини земель долинає низький протяжний ріг. Йому ніхто не відповідає."],
		["distant_bell", "ДЗВІН", "Дзвін без дзвіниці: на дорозі, де його нема кому бити."],
		["cat_meow", "МЯУКАННЯ", "Тонке нявкання з порожнього рову. Тут немає жодної живої душі."],
	]
	if night > 0.4:
		options.append(["wolf_howl", "ВИТТЯ", "Вовче виття — надто близько й надто рівне, наче його вчили."])
	var pick: Array = options[_rng.randi() % options.size()]
	var dir := Vector3(1, 0, 0).rotated(Vector3.UP, _rng.randf() * TAU)
	var at: Vector3 = player.global_position + dir * _rng.randf_range(16.0, 32.0)
	AudioManager.play_sfx_3d(str(pick[0]), at, 4.0, 90.0, 14.0)
	if _rng.randf() < 0.4:
		_toast("ДИВНИЙ ЗВУК: " + str(pick[1]), str(pick[2]), 3.2)
	return true


func _ev_sudden_enemy(player: CharacterBody3D) -> bool:
	var spot := _point_ahead(player, _rng.randf_range(20.0, 27.0), 35.0)
	if _near_building_local(spot, 25.0) or not world.mass:
		return false
	spot = world.mass._find_free(spot, _heading(player))
	AudioManager.play_sfx("crow", 0.0, 0.1)
	var knight := _rng.randf() < 0.3
	var props := {"enemy_type": "ashen_wraith", "display_name": "ЗАБЛУКЛИЙ ЛИЦАР" if knight else "ЗАБЛУКЛИЙ ВАРТОВИЙ", "max_health": 95.0 if knight else 75.0,
		"attack_damage": 13.0 if knight else 11.0, "move_speed": 3.0, "detection_range": 55.0, "scale": 1.05 if knight else 1.0, "reward_override": 6 if knight else 4}
	if knight:
		props["visual_type"] = "enemy_knight"
	world._spawn_special_wraith(spot, props)
	_puff(world.to_global(spot + Vector3(0, 0.8, 0)), Color("#3a3038"), 8)
	_toast("РАПТОВА ЗУСТРІЧ", "Із-за дерев на дорогу виходить самотній воїн. Він вже тебе бачить.", 3.0)
	AudioManager.play_sfx("wraith_growl", 1.0, 0.1)
	return true


# --- Далека істота й бліді вогні ------------------------------------------------------------------------

func _ev_distant_creature(player: CharacterBody3D) -> bool:
	var dir := Vector3(1, 0, 0).rotated(Vector3.UP, _rng.randf() * TAU)
	var local: Vector3 = world.to_local(player.global_position) + dir * _rng.randf_range(82.0, 105.0)
	local.y = world._terrain_height_at_world(local.x, local.z)
	var tangent := Vector3(-dir.z, 0.0, dir.x) * (1.0 if _rng.randf() < 0.5 else -1.0)
	var root := Node3D.new()
	var dark := PSXMaterials.make(Color("#0c0a10"), 0.0, 0.95, Color.BLACK, 0.0, "none", false)
	var eye := PSXMaterials.make(Color("#ff3a20"), 0.0, 0.3, Color("#ff2a10"), 3.0, "none", false)
	var parts: Dictionary = {}
	for spec in [["torso", Vector3(2.0, 3.2, 1.2), Vector3(0, 6.2, 0)], ["head", Vector3(1.1, 1.2, 1.1), Vector3(0, 8.6, 0.1)],
			["arm_l", Vector3(0.5, 4.4, 0.5), Vector3(-1.4, 5.4, 0)], ["arm_r", Vector3(0.5, 4.4, 0.5), Vector3(1.4, 5.4, 0)],
			["leg_l", Vector3(0.8, 4.2, 0.8), Vector3(-0.55, 2.1, 0)], ["leg_r", Vector3(0.8, 4.2, 0.8), Vector3(0.55, 2.1, 0)]]:
		var m := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = spec[1]
		m.mesh = bx
		m.material_override = dark
		m.position = spec[2]
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(m)
		parts[str(spec[0])] = m
	for sx: float in [-0.25, 0.25]:
		var e := MeshInstance3D.new()
		var eb := BoxMesh.new()
		eb.size = Vector3(0.22, 0.12, 0.1)
		e.mesh = eb
		e.material_override = eye
		e.position = Vector3(sx, 8.7, -0.5)
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(e)
	world.add_child(root)
	root.position = local
	root.look_at(root.global_position + world.global_transform.basis * tangent, Vector3.UP)
	_creatures.append({"node": root, "dir": tangent, "t": 0.0, "life": 24.0, "speed": 3.0, "parts": parts, "step": 0.0, "kind": "giant"})
	_toast("У ДАЛИНІ", "На обрії повільно йде щось надто високе для людини. Воно не озирається.", 4.0)
	AudioManager.play_sfx_3d("far_horn", world.to_global(local), 0.0, 220.0, 40.0)
	return true


func _ev_pale_lights(player: CharacterBody3D) -> bool:
	var dir := _heading(player).rotated(Vector3.UP, _rng.randf_range(-1.2, 1.2))
	var start: Vector3 = world.to_local(player.global_position) + dir * 70.0
	var tangent := Vector3(-dir.z, 0.0, dir.x)
	var root := Node3D.new()
	world.add_child(root)
	root.position = Vector3(start.x, 0.0, start.z)
	var mat := PSXMaterials.make(Color("#cfe4ff"), 0.0, 0.3, Color("#9ac4ff"), 3.0, "none", false)
	for i in range(5):
		var orb := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3.ONE * 0.5
		orb.mesh = bx
		orb.material_override = mat
		orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		orb.position = tangent * float(i) * 5.0 + Vector3(0, 6.0 + float(i % 2) * 1.5, 0)
		var light := OmniLight3D.new()
		light.light_color = Color("#a8ccff")
		light.light_energy = 1.2
		light.omni_range = 9.0
		light.shadow_enabled = false
		orb.add_child(light)
		root.add_child(orb)
	_creatures.append({"node": root, "dir": tangent, "t": 0.0, "life": 32.0, "speed": 1.8, "parts": {}, "step": 0.0, "kind": "lights"})
	_toast("БЛІДІ ВОГНІ", "Над землею пливуть п'ять холодних вогнів. Вони не відкидають тіней і не гаснуть від вітру.", 4.5)
	AudioManager.play_sfx_3d("far_horn", world.to_global(start), 0.0, 240.0, 50.0)
	AudioManager.play_sfx("strange_whisper", -10.0, 0.0)
	return true


func _update_creatures(delta: float) -> void:
	var player := _player()
	for ci in range(_creatures.size() - 1, -1, -1):
		var c: Dictionary = _creatures[ci]
		var node: Node3D = c["node"]
		if not is_instance_valid(node):
			_creatures.remove_at(ci)
			continue
		c["t"] = float(c["t"]) + delta
		var dir: Vector3 = c["dir"]
		node.position += dir * float(c["speed"]) * delta
		if str(c["kind"]) == "giant":
			node.position.y = world._terrain_height_at_world(node.position.x, node.position.z)
			var parts: Dictionary = c["parts"]
			c["step"] = float(c["step"]) + delta
			var sway := sin(float(c["step"]) * 1.7) * 0.35
			(parts["leg_l"] as Node3D).rotation.x = sway
			(parts["leg_r"] as Node3D).rotation.x = -sway
			(parts["arm_l"] as Node3D).rotation.x = -sway * 0.6
			(parts["arm_r"] as Node3D).rotation.x = sway * 0.6
			if fmod(float(c["step"]), 3.7) < delta and float(c["t"]) > 1.0:
				AudioManager.play_sfx_3d("block_thud", node.global_position, 2.0, 200.0, 35.0)
			if float(c["life"]) - float(c["t"]) < 3.0:
				node.position.y -= (3.0 - (float(c["life"]) - float(c["t"]))) * 1.6
		else:
			for ch in node.get_children():
				var orb := ch as Node3D
				if orb:
					orb.position.y += sin(float(c["t"]) * 1.4 + orb.position.x) * 0.4 * delta
			node.position.y = world._terrain_height_at_world(node.position.x, node.position.z)
		if float(c["t"]) >= float(c["life"]) or (player and node.global_position.distance_to(player.global_position) > 260.0):
			node.queue_free()
			_creatures.remove_at(ci)


# --- Ворони над місцем майбутньої події --------------------------------------------------------------------

func _ev_omen_ravens(player: CharacterBody3D) -> bool:
	var spot := _point_ahead(player, _rng.randf_range(48.0, 62.0), 40.0)
	if _near_building_local(spot, 22.0):
		return false
	var flock := _spawn_flock("circle", spot, 6)
	flock["resolved"] = false
	flock["expires"] = 100.0
	AudioManager.play_sfx_3d("crow", world.to_global(spot + Vector3(0, 14, 0)), 3.0, 110.0, 18.0)
	_toast("ВОРОНИ НАД ЛІСОМ", "Там, попереду, чорні птахи кружляють над одним місцем. Щось уже сталося — або ось-ось станеться.", 5.0)
	return true


func _update_omens() -> void:
	var player := _player()
	if player == null:
		return
	for flock in _flocks:
		if str(flock["kind"]) != "circle" or bool(flock["resolved"]):
			continue
		var c: Vector3 = flock["center"]
		var local: Vector3 = world.to_local(player.global_position)
		var dist := Vector2(c.x - local.x, c.z - local.z).length()
		if dist < 24.0:
			flock["resolved"] = true
			_resolve_omen(flock, player)
		elif float(flock["t"]) > float(flock.get("expires", 100.0)) or dist > 170.0:
			flock["resolved"] = true
			_scatter(flock, Vector3(1, 0, 0).rotated(Vector3.UP, _rng.randf() * TAU))


func _resolve_omen(flock: Dictionary, player: CharacterBody3D) -> void:
	var c: Vector3 = flock["center"]
	_scatter(flock, (world.to_local(player.global_position) - c).normalized() * -1.0)
	AudioManager.play_sfx_3d("crow", world.to_global(c + Vector3(0, 8, 0)), 3.0, 90.0, 14.0)
	if _rng.randf() < 0.6 and world.mass:
		_toast("ЗАСІДКА", "Ворони зірвались у небо — під ними чекали! З кущів вискакують озброєні тіні.", 4.0)
		AudioManager.play_sfx("wraith_growl", 2.0, 0.1)
		var count := _rng.randi_range(4, 5)
		var local_p: Vector3 = world.to_local(player.global_position)
		for i in range(count):
			var a := TAU * float(i) / float(count) + _rng.randf_range(-0.4, 0.4)
			var pos: Vector3 = world.mass._find_free(local_p + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(14.0, 20.0), Vector3(cos(a), 0, sin(a)))
			var knight := i == 0
			var props := {"enemy_type": "ashen_wraith", "display_name": "СТЕРВ'ЯТНИК" if not knight else "ВОЖАК СТЕРВ'ЯТНИКІВ", "max_health": 70.0 if not knight else 130.0,
				"attack_damage": 11.0 if not knight else 15.0, "move_speed": 3.0, "detection_range": 60.0, "scale": 1.0 if not knight else 1.2, "reward_override": 4 if not knight else 10}
			if knight:
				props["visual_type"] = "enemy_knight"
			world._spawn_special_wraith(pos, props)
	else:
		# Спорожніле майно мандрівника.
		var coins := _rng.randi_range(14, 32)
		QuestManager.reward_coins(coins, "Знахідка під воронами")
		var notes: Array = [
			"Під воронами лежить розпорота торба. Усередині — монети й шматок пергаменту: «Не оглядайся на дзвін».",
			"Мандрівник давно мертвий. У руці затиснуто записку: «Вогні гаснуть не самі. Хтось їх рахує».",
			"Ворони кружляли над порожньою торбою. На дні — кілька монет і слід босих ніг, що веде в ліс і зникає.",
		]
		_toast("ЗНАХІДКА  +%d" % coins, str(notes[_rng.randi() % notes.size()]), 6.0)
		AudioManager.play_ui("discover")


# --- «Чудіки» ----------------------------------------------------------------------------------------------

func _ev_oddball(player: CharacterBody3D) -> bool:
	var keys: Array = ODDBALLS.keys()
	var night: float = world.get_night_amount()
	var kind := str(keys[_rng.randi() % keys.size()])
	if kind == "lantern" and night < 0.35 and _rng.randf() < 0.7:
		kind = "counter"
	var spec: Dictionary = ODDBALLS[kind]
	var h := _heading(player)
	var side := Vector3(-h.z, 0.0, h.x) * (1.0 if _rng.randf() < 0.5 else -1.0)
	var local: Vector3 = world.to_local(player.global_position) + h * 9.0 + side * 6.5
	if _near_building_local(local, 20.0):
		return false
	local.y = world._terrain_height_at_world(local.x, local.z)
	_odd_counter += 1
	var id := "odd_%s_%d" % [kind, _odd_counter]
	var to_player: Vector3 = player.global_position - world.to_global(local)
	var facing := atan2(-to_player.x, -to_player.z) + PI
	var npc: Node3D = world._create_world_npc(id, str(spec["name"]), str(spec["role"]), local, str(spec["robe"]), str(spec["accent"]), str(spec["style"]), facing)
	_puff(world.to_global(local) + Vector3(0, 1.0, 0), Color("#2a3a2a"), 9)
	# Стрибок із кущів.
	npc.position.y = local.y - 0.6
	var tw := create_tween()
	tw.tween_property(npc, "position:y", local.y + 0.9, 0.22).set_ease(Tween.EASE_OUT)
	tw.tween_property(npc, "position:y", local.y, 0.2).set_ease(Tween.EASE_IN)
	AudioManager.play_sfx_3d("crow", world.to_global(local) + Vector3(0, 3, 0), -2.0, 50.0, 8.0)
	_toast("ДИВНА ЗУСТРІЧ", str(spec["toast"]), 5.5)
	_oddballs.append({"id": id, "type": kind, "node": npc, "t": 0.0, "state": "wait"})
	return true


func _update_oddballs(delta: float) -> void:
	var player := _player()
	for oi in range(_oddballs.size() - 1, -1, -1):
		var o: Dictionary = _oddballs[oi]
		var node: Node3D = o["node"]
		if not is_instance_valid(node):
			_oddballs.remove_at(oi)
			continue
		o["t"] = float(o["t"]) + delta
		var far: bool = player != null and node.global_position.distance_to(player.global_position) > 38.0
		if str(o["state"]) == "wait" and (float(o["t"]) > 70.0 or far):
			_vanish(o, oi)
		elif str(o["state"]) == "leaving" and float(o["t"]) > 5.0:
			_vanish(o, oi)


func _remove_interaction(id: String) -> void:
	for i in range(world.world_interactions.size() - 1, -1, -1):
		if str(world.world_interactions[i].get("id", "")) == id:
			world.world_interactions.remove_at(i)


func _vanish(o: Dictionary, index: int) -> void:
	var node: Node3D = o["node"]
	_remove_interaction(str(o["id"]))
	if is_instance_valid(node):
		_puff(node.global_position + Vector3(0, 1.0, 0), Color("#8a8a96"), 8)
		node.queue_free()
	_oddballs.remove_at(index)


func _flee(o: Dictionary) -> void:
	## Чудік не залишається: тікає геть (чи розчиняється) за кілька секунд після розмови.
	o["state"] = "leaving"
	o["t"] = 0.0
	_remove_interaction(str(o["id"]))
	var node: Node3D = o["node"]
	if not is_instance_valid(node):
		return
	var player := _player()
	var away := node.global_position - (player.global_position if player else node.global_position)
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else Vector3(1, 0, 0)
	if str(o["type"]) == "lantern":
		_puff(node.global_position + Vector3(0, 1.0, 0), Color("#cfe0ff"), 10)
		node.queue_free()
		return
	var tw := create_tween()
	tw.tween_property(node, "global_position", node.global_position + away * 26.0, 4.5)


func _find_odd(id: String) -> Dictionary:
	for o in _oddballs:
		if str(o["id"]) == id:
			return o
	return {}


func handle_interaction(interaction_id: String) -> bool:
	if not interaction_id.begins_with("odd_"):
		return false
	var o := _find_odd(interaction_id)
	if o.is_empty():
		return false
	var kind := str(o["type"])
	var spec: Dictionary = ODDBALLS[kind]
	var body := str(spec["talk"])
	if kind == "counter" and _rng.randf() < 0.2:
		body = "Знаєш, скільки кроків ти зробив від Села Попелу? Я теж ні. А я рахував. Ні, брешу — збився. Спочатку."
	main.call("_show_world_dialogue", (str(spec["name"]) + " — " + str(spec["role"])).to_upper(), body, [
		{"label": str(spec["ask"]), "action": "surprise:ask:" + interaction_id},
		{"label": "ЙТИ СВОЇМ ШЛЯХОМ", "action": "surprise:bye:" + interaction_id},
	])
	return true


func on_action(action: String) -> void:
	var parts := action.split(":")
	if parts.size() < 3:
		return
	var id := parts[2]
	var o := _find_odd(id)
	if o.is_empty():
		return
	var spec: Dictionary = ODDBALLS[str(o["type"])]
	var player := _player()
	if parts[1] == "ask":
		var answer := str(spec["answer"])
		match str(o["type"]):
			"lantern":
				if player:
					player.call("heal", 20.0)
			"crow":
				var coins := int(main.get("score"))
				if coins >= 3:
					main.set("score", coins - 3)
					main.call("_update_score")
				else:
					answer = "Дід довго дивиться на порожню долоню. «Без хліба вони мовчать. І я теж.»"
		_toast((str(spec["name"])).to_upper(), answer, 7.0)
	_flee(o)
