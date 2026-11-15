class_name WorldTrials
extends Node
## «Розділ II · Дороги Корони»: шість випробувань із різною ідеєю (замість «піди — принеси — повернися») та
## міні-бос Давній Маг. Шматки розірваного Атласу дають міні-боси й випробування, а без них шлях до гори невідомий.
##   • ch_gate     — ОБОРОНА: протримайся, поки механізм Південної Брами відкривається, хвилі різних ворогів.
##   • ch_stones   — МЕХАНІЗМИ: активуй три руни Німих Каменів за обмежений час; кожна будить власну засідку.
##   • ch_obelisks — РИТУАЛ: зруйнуй три темні обеліски; їх захищають охоронці й тіньові імпульси.
##   • ch_pit      — ЗАМКНЕНА АРЕНА: Кістяна Яма: огорожа піднімається, три хвилі, вийти не можна.
##   • ch_stag     — СТЕЖЕННЯ: йди за духом-ланню до прихованої печери (засідки по дорозі).
##   • ch_lost     — ПОШУК: знайди мандрівника в тумані, де щодваддцять секунд виходять тіні.
## Кожне можна провалити й почати знову; ворогів ніколи не більше фіксованої кількості.

const CHAPTER: String = "Розділ II · Дороги Корони"

const TRIALS: Dictionary = {
	"ch_gate": {"kind": "waves", "title": "Брама Південної Застави", "building": "Південна Брама", "front": 16.0, "lat": 0.0,
		"giver": "npc_nun", "giver_name": "Сестра Мар'яна", "coins": 90, "color": "#ffb050",
		"desc": "Під Південною Брамою заклинений давній механізм: коли його запустити, брама відкриє схованку Ордену Печатки зі шматком атласу. Але мертві чують його гул і йдуть хвилями.",
		"offer": "Давні монахи ховали карту в брамі-механізмі на півдні. Щоб відкрити її, треба запустити механізм і втриматися, поки він набирає хід: мертві йтимуть хвилями. Ти не один такий сміливий, але вижив лише один — і той недовго.",
		"active": "Механізм Південної Брами чекає. Біля нього — стій і тримайся: хвилі мертвих не припиняться, поки брама не відкриється.",
		"ready": "Брама відкрилась?! Я чула гул аж до монастиря. Ось нагорода, воїне, ти її заслужив.", "done": "Брама відкрита. Нехай відпочине той, хто там не вистояв.",
		"accept": "ПРИЙНЯТИ: БРАМА ПІВДНЯ", "site_obj": "Дійди до механізму Південної Брами (південь, біля дороги)", "base_obj": "Запусти механізм брами й протримайся до відкриття",
		"intro": "Давній механізм Південної Брами. Запустивши його, ти не зможеш зупинити — брама відкриється лише через дві хвилини. Весь цей час мертві йтимуть із трьох боків: не віддаляйся від механізму.",
		"piece": "south", "upgrade": "armor", "duration": 120.0},
	"ch_stones": {"kind": "mech", "title": "Німі Камені", "building": "Камені Мовчання", "front": 6.0, "lat": 0.0,
		"giver": "npc_hermit", "giver_name": "Ярин-відлюдник", "coins": 80, "color": "#9ab8ff",
		"desc": "Камені Мовчання — єдине місце, де гора втихає. Ярин каже, що три рунічні стовпи колись відкривали нішу зі схованкою Ордену. Стовпи треба активувати за один подих.",
		"offer": "Я чую гору. Вона замовкає тільки біля Німих Каменів — і лише коли три стовпи горять разом. Спробуй: торкнися кожного. Камінь пам'ятає лише хвилину-дві, тож не барись. І будь готовий: кожен стовп будить своїх.",
		"active": "Три стовпи — три пробудження. Торкнись усіх за одну хвилину, чужинцю.", "ready": "Ніша відкрилась? Тоді тепер гора знає, що ти торкався її. Нагорода твоя.",
		"done": "Німі Камені знову замовкли. Дякую, що почув їх.", "accept": "ПРИЙНЯТИ: НІМІ КАМЕНІ",
		"site_obj": "Дійди до Німих Каменів (північний схід)", "base_obj": "Активуй три рунічні стовпи (E) менш ніж за 100 с і виживи",
		"intro": "Три рунічні стовпи оточують старі камені. Після першого дотику камінь пам'ятає 100 секунд: усі три мають горіти разом. Кожен стовп пробуджує власну засідку.",
		"piece": "north", "upgrade": "sword", "window": 100.0},
	"ch_obelisks": {"kind": "ritual", "title": "Темні Обеліски", "building": "Хутір Сухих Борозен", "front": 14.0, "lat": 0.0,
		"giver": "npc_miner", "giver_name": "Грім-бригадир", "coins": 110, "color": "#c060ff",
		"desc": "Навколо Хутора Сухих Борозен із землі проросли три чорні обеліски: від них гниють поля, а мертві стягаються до ритуалу. Охорона не дасть розбити їх просто так.",
		"offer": "На півдні, біля Хутора, виросли три чорні стовпи. Від них земля мертвіє, а мертві стоять навколо, наче сторожа. Зруйнуй їх. Спершу — охорону: поки вона жива, обеліск закритий тіньовим щитом.",
		"active": "Три чорні обеліски на півдні. Знищ охорону — й розбий каміння.", "ready": "Земля здихнула. Вперше за місяць поле пахне землею, а не попелом. Це тобі.",
		"done": "Хутір ожив. Дякуємо, мандрівнику.", "accept": "ПРИЙНЯТИ: ТЕМНІ ОБЕЛІСКИ",
		"site_obj": "Дійди до Хутора Сухих Борозен (південь)", "base_obj": "Знищ три темні обеліски, поки їх охороняють",
		"intro": "Три чорні обеліски. Їх охороняють мерці й тіньові імпульси. Спочатку вбий охорону біля обеліска, потім розбий його (E). Поки ритуал не зруйновано, тінь час від часу піднімає нових мерців.",
		"upgrade": "vitality", "item": ""},
	"ch_pit": {"kind": "arena", "title": "Кістяна Яма", "building": "Брама велетнів", "front": 24.0, "lat": 16.0,
		"giver": "npc_captain", "giver_name": "Капітан Гедвіг", "coins": 100, "color": "#ff6040",
		"desc": "За Брамою велетнів старі гладіатори викопали Яму: коло, з якого нікому не вдавалося вийти, не перемігши трьох хвиль. Капітан Гедвіг хоче знати, чи вистоїш ти.",
		"offer": "За Брамою велетнів є Яма: коло, де наші діди випробовували воїнів. Огорожа зростається, коли ти заходиш, і не відпускає, доки не впадуть три хвилі. Мертві там теж є. Переможеш — тримай печать Ями та мою вдячність.",
		"active": "Яма за Брамою велетнів. Вхід — у коло, вихід — лише через три хвилі.", "ready": "Живий і з печаттю Ями! Вперше за сорок років. Ось плата, воїне.",
		"done": "Яма мовчить. Ти доведеш, що наша варта ще має зуби.", "accept": "ПРИЙНЯТИ: КІСТЯНА ЯМА",
		"site_obj": "Дійди до Кістяної Ями біля Брами велетнів", "base_obj": "Виживи в замкненій Яме: три хвилі",
		"intro": "Кістяна Яма. Щойно увійдеш у коло, огорожа підніметься. Три хвилі різних ворогів: підніжки, шакали, а наприкінці — вартовий і віщун. Утекти не вийде.",
		"upgrade": "bowdmg", "item": "pit_sigil"},
	"ch_stag": {"kind": "follow", "title": "Біла Лань", "building": "Коло друїдів", "front": 6.0, "lat": 0.0,
		"giver": "npc_druid", "giver_name": "Велес-друїд", "coins": 100, "color": "#bfe8ff",
		"desc": "У Колі друїдів ночами з'являється біла лань — дух старого лісу. Велес вірить, що вона веде до прихованої печери, де зберігається Амулет Лісу.",
		"offer": "Біла лань приходить до Кола вночі, коли ліс згадує себе. Вона веде до печери, де ми заховали Амулет. Йди за нею й не відставай: якщо загубиш — вона зупиниться й чекатиме. Дорогою тебе не раз зустрінуть ті, хто не хоче, щоб ти дійшов.",
		"active": "Лань чекає біля Кола друїдів. Не відставай — і дивись у кущі.", "ready": "Амулет у тебе? Ліс тебе прийняв. Бери мою вдячність.",
		"done": "Ліс пам'ятає тебе. Нехай лань веде й надалі.", "accept": "ПРИЙНЯТИ: БІЛА ЛАНЬ",
		"site_obj": "Дійди до Кола друїдів (захід)", "base_obj": "Іди за Білою Ланню до печери (не відставай)",
		"intro": "Біла Лань виходить із туману й дивиться на тебе. Іди за нею: якщо відстанеш, вона зупиниться. Дорогою на тебе нападуть двічі.",
		"upgrade": "stamina", "item": "stag_amulet"},
	"ch_lost": {"kind": "find", "title": "Зниклий Мандрівник", "building": "Ферма Попелястих Полів", "front": 12.0, "lat": 0.0,
		"giver": "npc_farmhand", "giver_name": "Тарас-фермер", "coins": 90, "color": "#a0e0a0",
		"desc": "Брат Тараса, мандрівник-мисливець, пішов у низину за фермою й зник у тумані. Туди не заходять: із туману виходять тіні, щойно стихає кроки.",
		"offer": "Мій брат пішов у низину за фермою — і не повернувся. Там туман, як молоко, і щось ходить. Кажуть, він живий: стогнав вночі. Знайди його. Тіні йдуть на кожен звук, тож шукай швидко.",
		"active": "Низина за фермою, туман. Чуй стогін, брате — і поспішай.", "ready": "Він живий! Каже, що ти йому врятував життя. Ось, візьми, що можу дати.",
		"done": "Брат поправляється. Дякую тобі.", "accept": "ПРИЙНЯТИ: ЗНИКЛИЙ МАНДРІВНИК",
		"site_obj": "Дійди до туманної низини за Фермою Попелястих Полів (південь)", "base_obj": "Знайди мандрівника в тумані (прислухайся до підказок)",
		"intro": "Туманна низина. Мандрівник десь тут. Кожні двадцять секунд із туману виходять тіні, доки ти всередині, тож рухайся й шукай підказки.",
		"upgrade": "", "item": "traveller_flask"},
}

const SKELETON: Dictionary = {"enemy_type": "skeleton", "visual_type": "skeleton", "display_name": "КІСТЯНИЙ ВОЇН", "max_health": 50.0, "attack_damage": 10.0,
	"move_speed": 3.5, "detection_range": 90.0, "scale": 1.0, "reward_override": 2}
const UPGRADE_CAP: Dictionary = {"sword": 3, "armor": 4, "vitality": 2, "stamina": 2, "bowdmg": 3}
const UPGRADE_NAME: Dictionary = {"sword": "Меч загартовано (+9 шкоди)", "armor": "Броню підсилено (−7 % шкоди)", "vitality": "Здоров'я +20", "stamina": "Витривалість +20", "bowdmg": "Тятива підсилена (+7 шкоди стріл)"}

var world = null
var main = null
var _center: Dictionary = {}         # tid -> центр локації (локальні координати)
var _site: Dictionary = {}           # tid -> місце стартового каменя
var _done: Dictionary = {}
var _active: String = ""
var _s: Dictionary = {}              # стан активного випробування
var _foes: Array = []
var _fx: Array = []                  # тимчасові вузли (огорожа, стовпи, олень) — вивільняються при скиданні
var _mage: Node = null
var _mage_spawned: bool = false
var _tick: float = 0.0


func setup(world_node) -> void:
	world = world_node
	main = world.get_parent()
	for tid in TRIALS.keys():
		_register_quest(str(tid))
		_build_site(str(tid))
	QuestManager._refresh_locks(false)


func _player() -> CharacterBody3D:
	return world.get("player_ref") as CharacterBody3D


func _toast(title: String, body: String, seconds: float = 4.0) -> void:
	main.call("_show_story_toast", title, body, seconds)


func _ground(l: Vector3) -> Vector3:
	var r := l
	r.y = world._terrain_height_at_world(l.x, l.z)
	return r


func _ring(center: Vector3, radius: float, angle: float) -> Vector3:
	return _ground(center + Vector3(cos(angle), 0.0, sin(angle)) * radius)


# --- Квести ------------------------------------------------------------------------------------------------

func _register_quest(tid: String) -> void:
	var spec: Dictionary = TRIALS[tid]
	if QuestManager.get_quest_summary(tid).is_empty():
		var T := QuestObjective.Type
		QuestManager._make_side_quest(tid, str(spec["title"]), str(spec["giver"]), str(spec["giver_name"]), str(spec["desc"]),
			[[T.REACH, tid + "_site", str(spec["site_obj"])], [T.INTERACT, tid + "_done", str(spec["base_obj"])]], int(spec["coins"]),
			[str(spec["offer"]), str(spec["active"]), str(spec["ready"]), str(spec["done"]), str(spec["accept"])])
		var data: QuestData = QuestManager._definitions[tid]
		data.category = CHAPTER
		data.turn_in_label = "ДОПОВІСТИ ПРО ПЕРЕМОГУ"


func marker_for(quest_id: String) -> Vector3:
	## Куди вказує мітка журналу для випробувань.
	if not TRIALS.has(quest_id) or QuestManager.get_quest_state(quest_id) != "active":
		return Vector3.ZERO
	if _active == quest_id:
		return _active_marker(quest_id)
	if QuestManager.get_step(quest_id) == 0 or not _site.has(quest_id):
		return _site.get(quest_id, Vector3.ZERO)
	return _site.get(quest_id, Vector3.ZERO)


func _active_marker(tid: String) -> Vector3:
	match str(TRIALS[tid]["kind"]):
		"ritual":
			for o in _s.get("obelisks", []):
				if not bool(o["destroyed"]):
					return o["pos"]
		"mech":
			for o2 in _s.get("pillars", []):
				if not bool(o2["lit"]):
					return o2["pos"]
		"follow":
			var deer: Node3D = _s.get("deer")
			if deer and is_instance_valid(deer):
				return world.to_local(deer.global_position)
			return _s.get("cave", _site[tid])
		"find":
			return _center[tid]
	return _center.get(tid, _site[tid])


# --- Місця -------------------------------------------------------------------------------------------------

func _build_site(tid: String) -> void:
	var spec: Dictionary = TRIALS[tid]
	var b: Node3D = world.building_nodes.get(str(spec["building"])) as Node3D
	var front: Vector3 = world._building_front_position(str(spec["building"]), float(spec["front"]), float(spec["lat"]))
	if b == null or front == Vector3.ZERO:
		return
	_center[tid] = _ground(b.position)
	_site[tid] = _ground(front)
	LocationTrigger.create(world, _site[tid] + Vector3(0, 2.0, 0), tid + "_site", str(spec["title"]), 30.0)
	_make_marker(tid)


func _make_marker(tid: String) -> void:
	var spec: Dictionary = TRIALS[tid]
	var col := Color(str(spec["color"]))
	var root := Node3D.new()
	root.name = "TrialStone_" + tid
	world.add_child(root)
	root.position = _site[tid]
	var stone := PSXMaterials.make(Color("#4a4a52"), 0.0, 0.95, Color.BLACK, 0.0, "stone", false)
	var glow := PSXMaterials.make(col, 0.0, 0.3, col, 2.6, "none", false)
	for k in range(3):
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.6 - float(k) * 0.12, 0.7, 0.6 - float(k) * 0.12)
		m.mesh = bm
		m.material_override = stone
		m.position = Vector3(0, 0.35 + float(k) * 0.7, 0)
		root.add_child(m)
	var rune := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(0.2, 0.2, 0.05)
	rune.mesh = rm
	rune.material_override = glow
	rune.position = Vector3(0, 1.2, -0.25)
	root.add_child(rune)
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 1.1
	light.omni_range = 7.0
	light.position = Vector3(0, 2.0, 0)
	root.add_child(light)
	_fx_stone[tid] = root
	world._register_world_interaction("trial:" + tid, str(spec["title"]), _site[tid] + Vector3(0, 1.0, 0), 3.6, "E  —  ВИПРОБУВАННЯ: " + str(spec["title"]).to_upper())


var _fx_stone: Dictionary = {}


func _remove_interaction(id: String) -> void:
	for i in range(world.world_interactions.size() - 1, -1, -1):
		if str(world.world_interactions[i].get("id", "")) == id:
			world.world_interactions.remove_at(i)


func _add_obj_interaction(id: String, name: String, local_pos: Vector3, hint: String, radius: float = 3.2) -> void:
	world._register_world_interaction(id, name, local_pos + Vector3(0, 1.0, 0), radius, hint)


# --- Взаємодія ---------------------------------------------------------------------------------------------

func handle_interaction(interaction_id: String) -> bool:
	if interaction_id.begins_with("trial:"):
		_open_site(interaction_id.substr(6))
		return true
	if interaction_id.begins_with("tobj:"):
		var parts := interaction_id.split(":")
		if parts.size() >= 3:
			_object_used(parts[1], int(parts[2]))
		return true
	if interaction_id == "npc_lost_traveller":
		_rescue()
		return true
	return false


func _open_site(tid: String) -> void:
	var spec: Dictionary = TRIALS[tid]
	if _done.has(tid):
		main.call("_show_world_dialogue", str(spec["title"]).to_upper(), "Випробування пройдено. Слід від нього ще тримається в повітрі, але тут уже тихо.", [{"label": "ДОБРЕ", "action": "close"}])
		return
	if _active == tid:
		_toast(str(spec["title"]).to_upper(), "Випробування триває. " + str(spec["base_obj"]), 3.0)
		return
	if _active != "":
		_toast("ВЖЕ ТРИВАЄ", "Спершу закінчи випробування: " + str(TRIALS[_active]["title"]), 3.5)
		return
	main.call("_show_world_dialogue", str(spec["title"]).to_upper(), str(spec["intro"]), [
		{"label": "ПОЧАТИ ВИПРОБУВАННЯ", "action": "trial:start:" + tid},
		{"label": "ПІЗНІШЕ", "action": "close"},
	])


func on_action(action: String) -> void:
	var parts := action.split(":")
	if parts.size() >= 3 and parts[1] == "start":
		_start(parts[2])
	elif parts.size() >= 3 and parts[1] == "done":
		finish_dialogue(action)


func _start(tid: String) -> void:
	if _active != "" or _done.has(tid) or not _site.has(tid):
		return
	var player := _player()
	if player == null:
		return
	if QuestManager.get_quest_state(tid) == "available":
		QuestManager.accept_quest(tid)
	QuestManager.notify_reach(tid + "_site")
	QuestManager.set_tracked_quest(tid)
	_active = tid
	_s = {"t": 0.0, "wave": 0, "pulse": 0, "pulse_t": 0.0, "away": 0.0}
	world.set_checkpoint(_site[tid] + Vector3(2.5, 0.0, 2.5), "Контрольна точка: " + str(TRIALS[tid]["title"]))
	AudioManager.play_sfx("far_horn", -4.0, 0.0)
	match str(TRIALS[tid]["kind"]):
		"waves":
			_toast("МЕХАНІЗМ ЗАПУЩЕНО", "Брама відкривається: 0 %. Мертві йдуть із трьох боків — тримайся біля механізму!", 5.0)
		"mech":
			_start_mech(tid)
		"ritual":
			_start_ritual(tid)
		"arena":
			_toast("КІСТЯНА ЯМА", "Увійди в коло — огорожа піднімається. Три хвилі.", 4.0)
			_s["state"] = "await"
		"follow":
			_start_follow(tid)
		"find":
			_start_find(tid)


func _object_used(tid: String, index: int) -> void:
	if _active != tid:
		return
	match str(TRIALS[tid]["kind"]):
		"mech":
			_use_pillar(index)
		"ritual":
			_use_obelisk(index)
		"follow":
			_open_chest()


# --- Спільні помічники: вороги ------------------------------------------------------------------------------

func _spawn(kind: String, local_pos: Vector3, rise: bool = false, hp_scale: float = 1.0) -> Node:
	var props: Dictionary
	if kind == "skeleton":
		props = SKELETON.duplicate()
	else:
		props = (EnemyEncounters.KINDS[kind] as Dictionary).duplicate()
	props["max_health"] = float(props["max_health"]) * hp_scale
	var e = world._spawn_special_wraith(local_pos, props)
	if e == null:
		return null
	_foes.append(e)
	if rise:
		_emerge(e)
	return e


func _emerge(e: Node) -> void:
	var at: Vector3 = e.global_position
	e.set_physics_process(false)
	e.collision_layer = 0
	e.collision_mask = 0
	e.global_position = at + Vector3(0, -1.9, 0)
	var rig: Node3D = e.get("_rig")
	if rig:
		rig.set("cast", 0.5)
	_dust(at, 6)
	var tw: Tween = e.create_tween()
	tw.tween_property(e, "global_position:y", at.y, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(e):
			return
		e.collision_layer = 2
		e.collision_mask = 1
		e.set_physics_process(true)
		if rig and is_instance_valid(rig):
			rig.set("cast", 0.0))


func _dust(at: Vector3, count: int) -> void:
	var mat := PSXMaterials.make(Color("#6a5a48"), 0.0, 1.0, Color.BLACK, 0.0, "none", false)
	for i in range(count):
		var m := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3.ONE * randf_range(0.18, 0.4)
		m.mesh = bx
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		get_tree().current_scene.add_child(m)
		m.global_position = at + Vector3(randf_range(-0.6, 0.6), 0.2, randf_range(-0.6, 0.6))
		var tw := m.create_tween().set_parallel(true)
		tw.tween_property(m, "global_position", m.global_position + Vector3(randf_range(-1, 1), randf_range(0.6, 1.8), randf_range(-1, 1)) * 1.4, 0.9)
		tw.tween_property(m, "scale", Vector3.ONE * 0.05, 0.9)
		tw.chain().tween_callback(m.queue_free)


func _alive() -> int:
	var n := 0
	for i in range(_foes.size() - 1, -1, -1):
		var e = _foes[i]
		if not is_instance_valid(e) or bool(e.get("dead")):
			_foes.remove_at(i)
		else:
			n += 1
	return n


func _clear_foes() -> void:
	for e in _foes:
		if is_instance_valid(e):
			(e as Node).queue_free()
	_foes.clear()


func _clear_fx() -> void:
	for i in range(world.world_interactions.size() - 1, -1, -1):
		var iid := str(world.world_interactions[i].get("id", ""))
		if iid.begins_with("tobj:") or iid == "npc_lost_traveller":
			world.world_interactions.remove_at(i)
	for n in _fx:
		if is_instance_valid(n):
			(n as Node).queue_free()
	_fx.clear()


func _spawn_group(center: Vector3, mix: Array, radius_min: float, radius_max: float, rise_skeletons: bool = true) -> void:
	## mix: [[вид, кількість], ...] — по кільцю довкола center, не в одній точці.
	var total := 0
	for m in mix:
		total += int(m[1])
	var i := 0
	var base := randf() * TAU
	for m in mix:
		for k in range(int(m[1])):
			var a := base + TAU * float(i) / float(maxi(total, 1)) + randf_range(-0.25, 0.25)
			var pos := _ring(center, randf_range(radius_min, radius_max), a)
			pos = world.mass._find_free(pos, Vector3(cos(a), 0.0, sin(a))) if world.mass else pos
			_spawn(str(m[0]), pos, str(m[0]) == "skeleton" and rise_skeletons)
			i += 1


# --- Головний цикл -----------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_mage_watch(delta)
	if _active == "":
		return
	var player := _player()
	if player == null:
		return
	if player.is_defeated():
		_fail("Ти впав. Випробування скинуто: починай знову біля каменя.")
		return
	_s["t"] = float(_s["t"]) + delta
	_tick -= delta
	if _tick > 0.0:
		return
	var dt := 0.25
	_tick = dt
	match str(TRIALS[_active]["kind"]):
		"waves":
			_tick_waves(dt, player)
		"mech":
			_tick_mech(dt, player)
		"ritual":
			_tick_ritual(dt, player)
		"arena":
			_tick_arena(dt, player)
		"follow":
			_tick_follow(dt, player)
		"find":
			_tick_find(dt, player)


func on_player_respawn() -> void:
	if _active != "":
		_fail("")


func _fail(message: String) -> void:
	var tid := _active
	if tid == "":
		return
	_clear_foes()
	_clear_fx()
	_active = ""
	_s = {}
	QuestManager.set_objective_text(tid, 1, str(TRIALS[tid]["base_obj"]))
	if message != "":
		_toast("ВИПРОБУВАННЯ ПРОВАЛЕНО", message, 5.0)


func _complete() -> void:
	var tid := _active
	var spec: Dictionary = TRIALS[tid]
	_clear_foes()
	_clear_fx()
	_active = ""
	_s = {}
	_done[tid] = true
	_remove_interaction("trial:" + tid)
	if _fx_stone.has(tid) and is_instance_valid(_fx_stone[tid]):
		var st: Node3D = _fx_stone[tid]
		for c in st.get_children():
			if c is OmniLight3D:
				(c as OmniLight3D).light_energy = 0.2
	QuestManager.record_interaction(tid + "_done")
	AudioManager.play_ui("quest_complete")
	var lines: Array = []
	if str(spec.get("piece", "")) != "":
		QuestManager.add_map_piece(str(spec["piece"]))
		lines.append("Шматок Атласу Корони")
	if str(spec.get("item", "")) != "":
		var item := str(spec["item"])
		QuestManager.add_item(item, str(QuestManager.get_item_name(item)))
	_grant_upgrade(str(spec.get("upgrade", "")), lines)
	if tid == "ch_lost":
		var extras = main.get("extras")
		if extras:
			extras.consumables["potion"] = int(extras.consumables.get("potion", 0)) + 3
		lines.append("3 зілля лікування")
	QuestManager.reward_coins(40, "Випробування пройдено")
	_toast("ВИПРОБУВАННЯ ПРОЙДЕНО: " + str(spec["title"]).to_upper(), "Нагорода: " + ", ".join(lines) + ". Здай звіт " + str(spec["giver_name"]) + ".", 7.0)


func _grant_upgrade(kind: String, lines: Array) -> void:
	if kind == "":
		return
	var extras = main.get("extras")
	var player: Node = main.get("player")
	if extras == null or player == null:
		return
	if int(player.get_meta(kind + "_level", 0)) >= int(UPGRADE_CAP.get(kind, 0)):
		QuestManager.reward_coins(60, "Покращення вже максимальне")
		lines.append("+60 монет (покращення вже максимальне)")
		return
	extras._apply_purchase(kind)
	lines.append(str(UPGRADE_NAME.get(kind, kind)))


# --- Тип: хвилі (оборона брами) --------------------------------------------------------------------------------

func _tick_waves(dt: float, player: CharacterBody3D) -> void:
	var tid := _active
	var c: Vector3 = _center[tid]
	var t: float = _s["t"]
	var dur: float = float(TRIALS[tid]["duration"])
	var local: Vector3 = world.to_local(player.global_position)
	if Vector2(local.x - c.x, local.z - c.z).length() > 55.0:
		_s["away"] = float(_s["away"]) + dt
		if float(_s["away"]) > 8.0:
			_fail("Ти покинув механізм: брама закрилась. Повертайся й починай знову.")
		elif int(_s["away"] * 4.0) % 8 == 0:
			_toast("ПОВЕРНИСЬ ДО БРАМИ", "Механізм потребує, щоб ти був поруч!", 1.5)
		return
	_s["away"] = 0.0
	var plan := [0.0, 38.0, 80.0]
	var w: int = _s["wave"]
	if w < 3 and (t >= float(plan[w]) or (w > 0 and _alive() <= 1 and t >= float(plan[w]) - 18.0)):
		_s["wave"] = w + 1
		_spawn_wave(w, c)
	var pct := int(clampf(t / dur, 0.0, 1.0) * 100.0)
	QuestManager.set_objective_text(tid, 1, "Брама відкривається: %d %% (хвиля %d з 3). Тримайся біля механізму" % [pct, int(_s["wave"])])
	if t >= dur:
		for e in _foes:
			if is_instance_valid(e) and not bool(e.get("dead")):
				e.take_damage(99999.0, player)
		_toast("БРАМА ВІДКРИЛАСЬ", "Механізм загув востаннє, і мертві розсипались.", 4.0)
		_complete()


func _spawn_wave(w: int, c: Vector3) -> void:
	var mixes := [
		[["skeleton", 7], ["skirmisher", 2]],
		[["skirmisher", 3], ["bone_seer", 2], ["skeleton", 4]],
		[["bone_knight", 1], ["bone_seer", 2], ["skeleton", 4]],
	]
	_toast("ХВИЛЯ %d З 3" % (w + 1), ["Мертві виповзають із землі довкола.", "Швидкі шакали й віщуни: тримай дистанцію до віщунів.", "Важкий вартовий і віщуни. Остання хвиля!"][w], 3.5)
	AudioManager.play_sfx("wraith_growl", 2.0, 0.1)
	_spawn_group(c, mixes[w], 16.0, 28.0)


# --- Тип: механізми (Німі Камені) -----------------------------------------------------------------------------

func _start_mech(tid: String) -> void:
	var c: Vector3 = _center[tid]
	var pillars: Array = []
	var glow_off := PSXMaterials.make(Color("#3a3a50"), 0.0, 0.5, Color("#ff4020"), 1.2, "none", false)
	for i in range(3):
		var a := TAU * float(i) / 3.0 + 0.5
		var pos := _ring(c, 11.0, a)
		var root := Node3D.new()
		world.add_child(root)
		root.position = pos
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.7, 3.0, 0.7)
		m.mesh = bm
		m.material_override = PSXMaterials.make(Color("#4a4a58"), 0.0, 0.9, Color.BLACK, 0.0, "stone", false)
		m.position = Vector3(0, 1.5, 0)
		root.add_child(m)
		var rune := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.36, 0.36, 0.06)
		rune.mesh = rm
		rune.material_override = glow_off
		rune.position = Vector3(0, 1.8, -0.36)
		root.add_child(rune)
		var light := OmniLight3D.new()
		light.light_color = Color("#ff5030")
		light.light_energy = 1.0
		light.omni_range = 6.0
		light.position = Vector3(0, 3.2, 0)
		root.add_child(light)
		_fx.append(root)
		pillars.append({"pos": pos, "lit": false, "light": light, "rune": rune})
		_add_obj_interaction("tobj:%s:%d" % [tid, i], "Рунічний стовп", pos, "E  —  АКТИВУВАТИ РУНУ")
	_s["pillars"] = pillars
	_s["first"] = -1.0
	QuestManager.set_objective_text(tid, 1, "Активуй три рунічні стовпи (E): 0 з 3")
	_toast("НІМІ КАМЕНІ", "Три стовпи по колу. Після першого дотику — 100 секунд.", 4.0)


func _use_pillar(index: int) -> void:
	var pillars: Array = _s.get("pillars", [])
	if index >= pillars.size() or bool(pillars[index]["lit"]):
		return
	var p: Dictionary = pillars[index]
	p["lit"] = true
	(p["light"] as OmniLight3D).light_color = Color("#60d0ff")
	(p["light"] as OmniLight3D).light_energy = 2.2
	PSXMaterials.set_emission(p["rune"].material_override, Color("#60d0ff"), 3.0)
	_remove_interaction("tobj:%s:%d" % [_active, index])
	if float(_s["first"]) < 0.0:
		_s["first"] = _s["t"]
	AudioManager.play_ui("discover")
	AudioManager.play_sfx("far_horn", -6.0, 0.0)
	var lit := 0
	for q in pillars:
		if bool(q["lit"]):
			lit += 1
	QuestManager.set_objective_text(_active, 1, "Активуй три рунічні стовпи (E): %d з 3 — тримай темп" % lit)
	# Кожен стовп будить свою засідку.
	var pos: Vector3 = p["pos"]
	match index % 3:
		0:
			_toast("СТОВП ПРОБУДЖЕНО", "Земля довкола тріскається: мертві виповзають!", 3.0)
			_spawn_group(pos, [["skeleton", 6]], 5.0, 9.0)
		1:
			_toast("СТОВП ПРОБУДЖЕНО", "Швидкі тіні виринають із повітря, віщун мружить очі.", 3.0)
			_spawn_group(pos, [["skirmisher", 3], ["bone_seer", 1]], 9.0, 14.0)
		_:
			var w = _spawn("witch", _ring(pos, 12.0, randf() * TAU), true, 0.55)
			_toast("СТОВП ПРОБУДЖЕНО", "З-під землі підіймається чаклунка з посохом. Бий її першою!", 3.5)
			_spawn_group(pos, [["skeleton", 2]], 6.0, 9.0)
			if w:
				w.set("display_name", "ТІНЬ КІСТЯНОЇ ВДОВИ")
	if lit >= 3:
		_s["all_lit"] = true


func _tick_mech(dt: float, player: CharacterBody3D) -> void:
	var tid := _active
	var pillars: Array = _s.get("pillars", [])
	var lit := 0
	for q in pillars:
		if bool(q["lit"]):
			lit += 1
	if bool(_s.get("all_lit", false)):
		QuestManager.set_objective_text(tid, 1, "Усі три руни горять. Знищ тих, кого розбудили (%d)" % _alive())
		if _alive() == 0:
			_toast("НІША ВІДКРИТА", "Камені затихли. У ніші лежить старий шматок карти.", 4.0)
			_complete()
		return
	if lit > 0 and float(_s["first"]) >= 0.0:
		var left: float = float(TRIALS[tid]["window"]) - (float(_s["t"]) - float(_s["first"]))
		if int(left * 4.0) % 40 == 0:
			QuestManager.set_objective_text(tid, 1, "Активуй три рунічні стовпи (E): %d з 3 — лишилось %d с" % [lit, int(left)])
		if left <= 0.0:
			# Камінь забув: руни гаснуть, засідки лишаються.
			_toast("КАМІНЬ ЗАБУВ", "Руни згасли: не встиг. Спробуй ще раз, швидше!", 4.0)
			for i in range(pillars.size()):
				var p: Dictionary = pillars[i]
				if bool(p["lit"]):
					p["lit"] = false
					(p["light"] as OmniLight3D).light_color = Color("#ff5030")
					(p["light"] as OmniLight3D).light_energy = 1.0
					PSXMaterials.set_emission(p["rune"].material_override, Color("#ff4020"), 1.2)
					_add_obj_interaction("tobj:%s:%d" % [tid, i], "Рунічний стовп", p["pos"], "E  —  АКТИВУВАТИ РУНУ")
			_s["first"] = -1.0
			QuestManager.set_objective_text(tid, 1, "Активуй три рунічні стовпи (E): 0 з 3")


# --- Тип: ритуал (темні обеліски) ----------------------------------------------------------------------------

func _start_ritual(tid: String) -> void:
	var c: Vector3 = _center[tid]
	var obelisks: Array = []
	var mats := PSXMaterials.make(Color("#16121c"), 0.0, 0.9, Color("#6a20a0"), 0.9, "stone", false)
	var guards := [[["skeleton", 5]], [["skirmisher", 3], ["bone_seer", 1]], [["bone_knight", 1], ["skeleton", 3]]]
	for i in range(3):
		var a := TAU * float(i) / 3.0 + 0.7
		var pos := _ring(c, 30.0, a)
		var root := Node3D.new()
		world.add_child(root)
		root.position = pos
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.0, 4.5, 1.0)
		m.mesh = bm
		m.material_override = mats
		m.position = Vector3(0, 2.25, 0)
		root.add_child(m)
		var tip := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.7
		cm.height = 1.2
		cm.radial_segments = 4
		tip.mesh = cm
		tip.material_override = mats
		tip.position = Vector3(0, 5.1, 0)
		root.add_child(tip)
		var light := OmniLight3D.new()
		light.light_color = Color("#a040ff")
		light.light_energy = 1.6
		light.omni_range = 9.0
		light.position = Vector3(0, 3.0, 0)
		root.add_child(light)
		_fx.append(root)
		obelisks.append({"pos": pos, "destroyed": false, "node": root})
		_add_obj_interaction("tobj:%s:%d" % [tid, i], "Темний обеліск", pos, "E  —  ЗРУЙНУВАТИ ОБЕЛІСК", 3.6)
		_spawn_group(pos, guards[i], 6.0, 11.0)
	_s["obelisks"] = obelisks
	QuestManager.set_objective_text(tid, 1, "Зруйнуй обеліски (0 з 3). Спершу знищ охоронців біля кожного")
	_toast("ТЕМНІ ОБЕЛІСКИ", "Три стовпи на кільці довкола Хутора. Біля кожного — охорона.", 4.0)


func _use_obelisk(index: int) -> void:
	var obelisks: Array = _s.get("obelisks", [])
	if index >= obelisks.size() or bool(obelisks[index]["destroyed"]):
		return
	var o: Dictionary = obelisks[index]
	var pos: Vector3 = o["pos"]
	for e in _foes:
		if is_instance_valid(e) and not bool(e.get("dead")) and world.to_local(e.global_position).distance_to(pos) < 15.0:
			_toast("ОБЕЛІСК ЗАХИЩЕНИЙ", "Тіньовий щит. Знищ охорону поруч!", 2.5)
			AudioManager.play_sfx("parry_ring", -2.0, 0.0)
			return
	o["destroyed"] = true
	_remove_interaction("tobj:%s:%d" % [_active, index])
	var node: Node3D = o["node"]
	_dust(world.to_global(pos) + Vector3(0, 1.5, 0), 12)
	AudioManager.play_sfx("block_thud", 4.0, 0.0)
	AudioManager.play_sfx("wraith_death", 0.0, 0.0)
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector3(1.0, 0.02, 1.0), 0.6)
	tw.tween_callback(node.queue_free)
	var left := 0
	for q in obelisks:
		if not bool(q["destroyed"]):
			left += 1
	QuestManager.set_objective_text(_active, 1, "Зруйнуй обеліски (%d з 3). Зараз ти бачиш: тінь шле нових мерців" % (3 - left))
	if left == 0:
		_toast("РИТУАЛ ЗРУЙНОВАНО", "Останній обеліск тріснув, і чорне повітря згасло.", 4.0)
		_complete()


func _tick_ritual(dt: float, player: CharacterBody3D) -> void:
	# Тіньові імпульси: до чотирьох разів, і лише коли живих ворогів небагато.
	_s["pulse_t"] = float(_s["pulse_t"]) + dt
	if float(_s["pulse_t"]) >= 26.0 and int(_s["pulse"]) < 4 and _alive() < 9:
		_s["pulse_t"] = 0.0
		_s["pulse"] = int(_s["pulse"]) + 1
		_toast("ТІНЬОВИЙ ІМПУЛЬС", "Обеліски пульсують: мертві виповзають довкола тебе!", 3.0)
		AudioManager.play_sfx("strange_whisper", 0.0, 0.0)
		_spawn_group(world.to_local(player.global_position), [["skeleton", 3]], 7.0, 11.0)


# --- Тип: замкнена арена (Кістяна Яма) ---------------------------------------------------------------------------

func _tick_arena(dt: float, player: CharacterBody3D) -> void:
	var tid := _active
	var c: Vector3 = _site[tid]
	_s["arena_c"] = c
	var local: Vector3 = world.to_local(player.global_position)
	var state: String = _s.get("state", "await")
	var dist := Vector2(local.x - c.x, local.z - c.z).length()
	if state == "await":
		if dist < 9.0:
			_s["state"] = "fight"
			_s["wave"] = 0
			_s["pause"] = 1.5
			_raise_fence(c, 17.0)
			_toast("ОГОРОЖА ПІДНІМАЄТЬСЯ", "Вороги в Ямі. Дороги назад нема.", 3.5)
			AudioManager.play_sfx("block_thud", 6.0, 0.0)
			AudioManager.play_sfx("wolf_howl", 0.0, 0.0)
		return
	# Вороги не можуть вийти з кола (блимання віщунів): повертаємо всередину.
	for e in _foes:
		if is_instance_valid(e) and not bool(e.get("dead")):
			var el: Vector3 = world.to_local((e as Node3D).global_position)
			var d := Vector2(el.x - c.x, el.z - c.z)
			if d.length() > 16.0:
				var inner := c + Vector3(d.normalized().x, 0.0, d.normalized().y) * 12.0
				inner.y = world._terrain_height_at_world(inner.x, inner.z)
				(e as Node3D).global_position = world.to_global(inner) + Vector3(0, 0.5, 0)
	if _alive() == 0:
		_s["pause"] = float(_s["pause"]) - dt
		if float(_s["pause"]) <= 0.0:
			var w: int = _s["wave"]
			if w >= 3:
				_toast("ЯМА ПРОЙДЕНА", "Огорожа осідає. Ти витримав усіх трьох.", 4.0)
				_complete()
				return
			var mixes := [[["skeleton", 6]], [["skirmisher", 4], ["skeleton", 2]], [["bone_knight", 1], ["bone_seer", 2]]]
			_s["wave"] = w + 1
			_s["pause"] = 3.0
			_toast("ХВИЛЯ %d З 3" % (w + 1), ["Мертві піднімаються з піску Ями.", "Швидкі шакали — не дай обійти себе.", "Вартовий і два віщуни: віщуни блимають, вартовий б'є важко."][w], 3.0)
			_spawn_group(c, mixes[w], 7.0, 13.0)
	QuestManager.set_objective_text(tid, 1, "Кістяна Яма: хвиля %d з 3, ворогів: %d" % [int(_s["wave"]), _alive()])


func _raise_fence(center: Vector3, radius: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	world.add_child(body)
	body.position = Vector3(center.x, 0.0, center.z)
	var wood := PSXMaterials.make(Color("#3a2a1e"), 0.0, 0.95, Color.BLACK, 0.0, "planks", false)
	var bone := PSXMaterials.make(Color("#d8d0b8"), 0.0, 0.9, Color.BLACK, 0.0, "stone", false)
	var n := 40
	for i in range(n):
		var a := TAU * float(i) / float(n)
		var gx := center.x + cos(a) * radius
		var gz := center.z + sin(a) * radius
		var gy: float = world._terrain_height_at_world(gx, gz)
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.3, 4.2, 0.3)
		post.mesh = pm
		post.material_override = wood
		post.position = Vector3(cos(a) * radius, gy - center.y + 1.4, sin(a) * radius)
		post.rotation.y = -a
		body.add_child(post)
		var skull := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.2
		sm.height = 0.4
		sm.radial_segments = 6
		sm.rings = 3
		skull.mesh = sm
		skull.material_override = bone
		skull.position = post.position + Vector3(0, 2.3, 0)
		body.add_child(skull)
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.3, 6.0, TAU * radius / float(n) + 0.7)
		col.shape = bs
		col.position = post.position + Vector3(0, 0.8, 0)
		col.rotation.y = -a
		body.add_child(col)
	body.position.y -= 5.0
	body.create_tween().tween_property(body, "position:y", body.position.y + 5.0, 1.0).set_trans(Tween.TRANS_BACK)
	_fx.append(body)


# --- Тип: стеження за ланню -----------------------------------------------------------------------------------

func _start_follow(tid: String) -> void:
	var start: Vector3 = _site[tid]
	var cave := _find_spot(start, 110.0, 140.0)
	_s["cave"] = cave
	var pts: Array = []
	for i in range(1, 6):
		var k := float(i) / 5.0
		var wp := start.lerp(cave, k)
		var side := Vector3(-(cave.z - start.z), 0.0, cave.x - start.x).normalized() * sin(k * PI * 2.0) * 14.0
		pts.append(_ground(wp + side))
	_s["pts"] = pts
	_s["i"] = 0
	_s["ambush"] = [1, 3]
	_s["hold"] = false
	var deer := _make_deer()
	world.add_child(deer)
	deer.position = _ground(start + Vector3(3.0, 0.0, 2.0))
	_s["deer"] = deer
	_fx.append(deer)
	QuestManager.set_objective_text(tid, 1, "Іди за Білою Ланню (не відставай). Етап 1 з 5")
	_toast("БІЛА ЛАНЬ", "Лань озирається й іде в туман. Йди за нею.", 4.0)
	AudioManager.play_sfx("strange_whisper", -4.0, 0.0)


func _find_spot(from: Vector3, rmin: float, rmax: float) -> Vector3:
	## Тихе місце на землі: не вода, без будівель, відносно рівне.
	var best := _ground(from + Vector3(rmin, 0, 0))
	var best_score := -1e9
	for i in range(20):
		var a := TAU * float(i) / 20.0
		var r := rmin + (rmax - rmin) * float(i % 3) / 2.0
		var p := _ring(from, r, a)
		if p.y < 2.0 or p.y > 70.0:
			continue
		var score := 0.0
		for off in [Vector2(6, 0), Vector2(-6, 0), Vector2(0, 6), Vector2(0, -6)]:
			score -= absf(world._terrain_height_at_world(p.x + off.x, p.z + off.y) - p.y)
		for b in world.building_nodes.values():
			var n := b as Node3D
			if n and Vector2(n.position.x - p.x, n.position.z - p.z).length() < 35.0:
				score -= 100.0
		if score > best_score:
			best_score = score
			best = p
	return best


func _make_deer() -> Node3D:
	var root := Node3D.new()
	root.name = "WhiteStag"
	var mat := PSXMaterials.make(Color("#d8ecff"), 0.0, 0.5, Color("#8ad0ff"), 1.4, "none", false)
	for spec in [[Vector3(0.5, 0.5, 1.2), Vector3(0, 1.1, 0)], [Vector3(0.22, 0.6, 0.24), Vector3(0, 1.55, -0.65)], [Vector3(0.26, 0.26, 0.5), Vector3(0, 1.85, -0.85)],
			[Vector3(0.12, 0.7, 0.12), Vector3(-0.18, 0.4, -0.45)], [Vector3(0.12, 0.7, 0.12), Vector3(0.18, 0.4, -0.45)],
			[Vector3(0.12, 0.7, 0.12), Vector3(-0.18, 0.4, 0.45)], [Vector3(0.12, 0.7, 0.12), Vector3(0.18, 0.4, 0.45)]]:
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = spec[0]
		m.mesh = bm
		m.material_override = mat
		m.position = spec[1]
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(m)
	for sx: float in [-1.0, 1.0]:
		var a := MeshInstance3D.new()
		var ab := BoxMesh.new()
		ab.size = Vector3(0.05, 0.7, 0.05)
		a.mesh = ab
		a.material_override = mat
		a.position = Vector3(sx * 0.18, 2.25, -0.85)
		a.rotation = Vector3(0.0, 0.0, -sx * 0.5)
		root.add_child(a)
	var light := OmniLight3D.new()
	light.light_color = Color("#a8dcff")
	light.light_energy = 1.2
	light.omni_range = 8.0
	light.position = Vector3(0, 1.8, 0)
	root.add_child(light)
	return root


func _tick_follow(dt: float, player: CharacterBody3D) -> void:
	var tid := _active
	var deer: Node3D = _s.get("deer")
	var pts: Array = _s.get("pts", [])
	if deer == null or not is_instance_valid(deer):
		return
	var idx: int = _s["i"]
	var state := str(_s.get("state", "walk"))
	var d_player := deer.global_position.distance_to(player.global_position)
	if state == "ambush":
		if _alive() == 0:
			_s["state"] = "walk"
			_toast("ЛАНЬ ЙДЕ ДАЛІ", "Шлях вільний. Лань кличе тебе далі.", 2.5)
		return
	if state == "arrived":
		return
	if d_player > 24.0:
		# Чекає: повертається до героя й стоїть.
		var look := player.global_position
		look.y = deer.global_position.y
		if look.distance_to(deer.global_position) > 0.1:
			deer.look_at(look, Vector3.UP)
		return
	if idx >= pts.size():
		_s["state"] = "arrived"
		_arrive_cave()
		return
	var target: Vector3 = pts[idx]
	var cur: Vector3 = world.to_local(deer.global_position)
	var to := target - cur
	to.y = 0.0
	if to.length() < 1.2:
		_s["i"] = idx + 1
		QuestManager.set_objective_text(tid, 1, "Іди за Білою Ланню (не відставай). Етап %d з 5" % mini(idx + 2, 5))
		if (_s["ambush"] as Array).has(idx):
			_s["state"] = "ambush"
			_ambush_here(cur, idx)
		return
	var step := to.normalized() * 4.4 * dt
	var nxt := cur + step
	nxt.y = world._terrain_height_at_world(nxt.x, nxt.z)
	deer.position = nxt
	deer.look_at(deer.global_position + world.global_transform.basis * step.normalized(), Vector3.UP)
	deer.position.y += absf(sin(float(_s["t"]) * 5.0)) * 0.08


func _ambush_here(local_pos: Vector3, idx: int) -> void:
	_toast("ЗАСІДКА В ЛІСІ", "Лань завмерла: із кущів виходять тіні.", 3.0)
	AudioManager.play_sfx("wraith_growl", 2.0, 0.1)
	if idx == 1:
		_spawn_group(local_pos, [["skeleton", 4], ["skirmisher", 2]], 9.0, 14.0)
	else:
		_spawn_group(local_pos, [["bone_seer", 1], ["skirmisher", 2], ["skeleton", 3]], 10.0, 15.0)


func _arrive_cave() -> void:
	var tid := _active
	var cave: Vector3 = _s["cave"]
	var deer: Node3D = _s["deer"]
	if deer and is_instance_valid(deer):
		_dust(deer.global_position + Vector3(0, 1.0, 0), 8)
		deer.hide()
	var root := Node3D.new()
	world.add_child(root)
	root.position = cave
	var rock := PSXMaterials.make(Color("#2a2a30"), 0.0, 0.95, Color.BLACK, 0.0, "stone", false)
	for spec in [[Vector3(1.2, 4.0, 1.4), Vector3(-2.2, 2.0, 0)], [Vector3(1.2, 4.0, 1.4), Vector3(2.2, 2.0, 0)], [Vector3(5.6, 1.3, 1.6), Vector3(0, 4.4, 0)], [Vector3(4.0, 3.8, 0.6), Vector3(0, 1.9, 2.2)]]:
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = spec[0]
		m.mesh = bm
		m.material_override = rock
		m.position = spec[1]
		root.add_child(m)
	var chest := MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = Vector3(0.9, 0.55, 0.6)
	chest.mesh = cb
	chest.material_override = PSXMaterials.make(Color("#6a4a2a"), 0.2, 0.7, Color("#ffd060"), 0.6, "planks", false)
	chest.position = Vector3(0, 0.3, 0.9)
	root.add_child(chest)
	var light := OmniLight3D.new()
	light.light_color = Color("#a8dcff")
	light.light_energy = 1.6
	light.omni_range = 9.0
	light.position = Vector3(0, 2.2, 0.6)
	root.add_child(light)
	_fx.append(root)
	_add_obj_interaction("tobj:%s:0" % tid, "Скриня печери", cave + Vector3(0, 0, 0.9), "E  —  ВІДКРИТИ СКРИНЮ", 3.0)
	QuestManager.set_objective_text(tid, 1, "Відкрий скриню в прихованій печері")
	_toast("ПРИХОВАНА ПЕЧЕРА", "Лань розчинилась у повітрі. За старою аркою мерехтить скриня.", 5.0)
	AudioManager.play_ui("discover")


func _open_chest() -> void:
	_remove_interaction("tobj:%s:0" % _active)
	AudioManager.play_ui("item_pickup")
	_complete()


# --- Тип: пошук у тумані ----------------------------------------------------------------------------------------

func _start_find(tid: String) -> void:
	var zone := _find_spot(_site[tid], 45.0, 65.0)
	_center[tid] = zone
	var spots: Array = []
	for i in range(3):
		spots.append(_ring(zone, randf_range(14.0, 30.0), TAU * float(i) / 3.0 + randf_range(-0.4, 0.4)))
	var pick: Vector3 = spots[randi() % 3]
	_s["target"] = pick
	_s["zone"] = zone
	_s["hint_t"] = 8.0
	var to_g: Vector3 = world.to_global(pick)
	var npc: Node3D = world._create_world_npc("npc_lost_traveller", "Поранений мандрівник", "Лежить у тумані", pick, "#3a4538", "#8aa070", "hunter", randf() * TAU)
	npc.rotation.x = 0.0
	_fx.append(npc)
	_s["npc"] = npc
	QuestManager.set_objective_text(tid, 1, "Знайди мандрівника в тумані (радіус ~40 м від позначеного місця)")
	_toast("ТУМАННА НИЗИНА", "Кожні 20 с із туману виходять тіні. Прислухайся: мандрівник стогне.", 5.0)


func _tick_find(dt: float, player: CharacterBody3D) -> void:
	var tid := _active
	var zone: Vector3 = _s["zone"]
	var local: Vector3 = world.to_local(player.global_position)
	var inside := Vector2(local.x - zone.x, local.z - zone.z).length() < 48.0
	if not inside:
		return
	_s["pulse_t"] = float(_s["pulse_t"]) + dt
	if float(_s["pulse_t"]) >= 20.0 and int(_s["pulse"]) < 4 and _alive() < 5:
		_s["pulse_t"] = 0.0
		_s["pulse"] = int(_s["pulse"]) + 1
		AudioManager.play_sfx("strange_whisper", 0.0, 0.0)
		var mixes := [[["skeleton", 3]], [["skirmisher", 2]], [["skeleton", 2], ["bone_seer", 1]], [["skirmisher", 2], ["skeleton", 2]]]
		_toast("ТІНІ З ТУМАНУ", "Щось ворушиться поруч…", 2.0)
		_spawn_group(local, mixes[int(_s["pulse"]) - 1], 9.0, 14.0)
	_s["hint_t"] = float(_s["hint_t"]) - dt
	if _s["hint_t"] <= 0.0:
		_s["hint_t"] = 14.0
		var target: Vector3 = _s["target"]
		var d := target - local
		var dist := Vector2(d.x, d.z).length()
		var dir := ("півночі" if d.z < 0.0 else "півдня") if absf(d.z) > absf(d.x) else ("сходу" if d.x > 0.0 else "заходу")
		var warm := "гарячіше!" if dist < 18.0 else ("тепліше" if dist < 35.0 else "далеко")
		_toast("ЧУТИ СТОГІН", "Стогін долинає з %s: %s" % [dir, warm], 3.0)


func _rescue() -> void:
	if _active != "ch_lost":
		return
	var npc: Node3D = _s.get("npc")
	_remove_interaction("npc_lost_traveller")
	main.call("_show_world_dialogue", "ПОРАНЕНИЙ МАНДРІВНИК", "Дякую, чужинцю… Я бачив, що йшло за мною. Я був у Ордені, коли монахи розривали Атлас: вісім шматків — вісім ключів до Вівтаря. Страж Ока ходить лише тим шляхом, який показує Око. А ще є Давній Маг у Крижаній вежі: він слухає Око й відповідає йому. Його серце — ключ до шматка з півночі. Бери флягу. І бережи Атлас.", [{"label": "ДЯКУЮ. ЙДУ", "action": "trial:done:ch_lost"}])


func finish_dialogue(action: String) -> void:
	if action == "trial:done:ch_lost" and _active == "ch_lost":
		_complete()


# --- Давній маг: міні-бос Крижаної вежі --------------------------------------------------------------------

func _mage_watch(delta: float) -> void:
	if _mage_spawned and (_mage == null or not is_instance_valid(_mage)):
		return
	var player := _player()
	if player == null:
		return
	if not _mage_spawned:
		var tower: Node3D = world.building_nodes.get("Крижана вежа") as Node3D
		if tower == null or QuestManager.has_map_piece("royal"):
			return
		if world.to_local(player.global_position).distance_to(tower.position) > 70.0:
			return
		_mage_spawned = true
		var front: Vector3 = _ground(world._building_front_position("Крижана вежа", 13.0, 0.0))
		var e = world._spawn_special_wraith(front, {"enemy_type": "ancient_mage", "brain_kind": "ancient_mage", "display_name": "ДАВНІЙ МАГ", "max_health": 520.0,
			"attack_damage": 15.0, "move_speed": 3.4, "detection_range": 55.0, "scale": 1.2})
		_mage = e
		if e:
			world.story_nodes["ancient_mage"] = e
			world.set_checkpoint(front + Vector3(0, 0, 14.0), "Контрольна точка: Крижана вежа")
			_toast("ДАВНІЙ МАГ", "На верхівці вежі спалахнуло синє світло. Із нього виходить постать у крижаній мантії: він відповідав на сигнал Ока.", 6.0)
			AudioManager.play_sfx("far_horn", 2.0, 0.0)
		return
