extends Node
## QuestManager (Autoload) — модульна система завдань Embers of the Spire.
## • Визначення — ресурси QuestData у res://quests/*.tres (редагуються в інспекторі).
## • Цілі: TALK / COLLECT / REACH / KILL / INTERACT, з лічильниками.
## • Стани: locked → available → active → ready → completed.
## • Передумови пов'язують квести в ланцюжки; нагороди — монети та предмети.
## Публічний API сумісний зі старою версією (main.gd, журнал, трекер).

signal quest_log_changed
signal quest_progressed(quest_id: String, objective_text: String, progress: int, total: int)
signal quest_claimed(quest_id: String, reward: int)
signal quest_unlocked(quest_id: String)
signal item_added(item_id: String, item_name: String, total: int)
signal location_discovered(location_id: String, display_name: String)
## Монети за перемогу над ворогом (UI додає їх до гаманця).
signal coins_earned(amount: int, reason: String)
## Новий шматок Атласу Корони (count — скільки вже складено, total — усього).
signal map_piece_added(piece_id: String, count: int, total: int)

const QUEST_DIR: String = "res://quests"

var _definitions: Dictionary = {}   # id -> QuestData
var _order: Array[String] = []
var _states: Dictionary = {}        # id -> {"status", "step", "count"}
var _inventory: Dictionary = {}     # item_id -> count
var _item_names: Dictionary = {}
var _discovered: Dictionary = {}
var _tracked_quest_id: String = ""


func _ready() -> void:
	_load_definitions()
	_init_atlas()


# --- Завантаження ------------------------------------------------------------------

func _load_definitions() -> void:
	_definitions.clear()
	_order.clear()
	var dir := DirAccess.open(QUEST_DIR)
	if dir == null:
		push_warning("QuestManager: немає папки %s" % QUEST_DIR)
		return
	var files := dir.get_files()
	files.sort()
	for file_name in files:
		var clean := file_name.trim_suffix(".remap")
		if not (clean.ends_with(".tres") or clean.ends_with(".res")):
			continue
		var data := load(QUEST_DIR.path_join(clean)) as QuestData
		if data == null or data.id.is_empty():
			push_warning("QuestManager: пропущено %s" % clean)
			continue
		register_data(data)
	_register_main_story()
	_register_side_quests()
	_register_dead_beacon()
	_register_bone_widow()
	_refresh_locks(false)


func _register_bone_widow() -> void:
	## Побічне доручення Руна Слідопита: стара відьма оселилась у Болотній хатині й піднімає мерців із землі.
	var T := QuestObjective.Type
	_make_side_quest("bone_widow", "Кістяна Вдова", "npc_hunter", "Рун Слідопит",
		"Троє мисливців пішли в болота й не повернулися. Рун знайшов їхні сліди, що закінчуються біля Болотної хатини, і череп-жердини навколо. Це робота Кістяної Вдови: вона піднімає скелетів із землі.",
		[[T.REACH, "mission_swamp", "Дійди до логова відьми перед Болотною хаткою (південний захід від села)"],
		[T.KILL, "skeleton_witch", "Знищ Кістяну Вдову, поки вона не призвала нових скелетів"]], 150,
		["Троє моїх хлопців пішли на болото по дичину — і лише сліди. Знайшов біля Болотної хатини череп на жердинах, а земля там свіжа, наче розрита зсередини. Кістяна Вдова, стара відьма: піднімає мертвих просто з ґрунту. Не стій на місці, коли вона зупиниться й підніме руки: це ритуал. Бий її одразу — тоді він зірветься. Принеси мені її череп-посох.",
		"Вдова ще там. Пам'ятай: коли вона піднімає руки — біжи до неї й руби. Вона слабка в ближньому бою.",
		"Її посох?! Ти справді… Дякую, мандрівнику. Мої хлопці спочиватимуть тепер спокійно. Ось плата, ти її заслужив.",
		"Болото затихло. Дякую тобі за хлопців.", "ПРИЙНЯТИ: КІСТЯНА ВДОВА"])
	var data: QuestData = _definitions["bone_widow"]
	data.category = "Побічне доручення"
	data.turn_in_label = "ПЕРЕДАТИ ПОСОХ ВДОВИ І ОТРИМАТИ НАГОРОДУ"


func _register_dead_beacon() -> void:
	## Місія «Згаслий Маяк» (≈8–10 хв): застава → Ліра → Зольний Брід → засідка → Склеп королів →
	## уламки → саркофаг і Хранитель → Копальні → оборона броду → Ліра → маяк і Вартовий → здача.
	var T := QuestObjective.Type
	var specs: Array = [
		[T.TALK, "npc_archer", "Знайди чародійку Ліру у Вежі Місячної Лучниці та розпитай про лінзу маяка"],
		[T.TALK, "npc_herder", "Розпитай пастушку Олю в Зольному Броді: хто проходив тракт на південь"],
		[T.KILL, "ashen_wraith", "Прорвися через засідку на південному тракті: знищ трьох Попелястих вартових", 3],
		[T.REACH, "mission_crypt", "Дійди до Склепу Забутих Королів (південний схід)"],
		[T.KILL, "ashen_wraith", "Відбийся від вартових, що прокинулися біля склепу", 2],
		[T.COLLECT, "moon_shard", "Збери три уламки місячного скла, розкидані навколо склепу", 3],
		[T.INTERACT, "mission_sarcophagus", "Відкрий королівський саркофаг і візьми Місячний камінь"],
		[T.KILL, "tower_guardian", "Здолай Хранителя Місячного Каменю"],
		[T.TALK, "npc_miner", "Заверни в Селище Соляних Копалень: Грім знає, як очистити камінь"],
		[T.KILL, "ashen_wraith", "Захисти Зольний Брід: на селище напали вартові", 3],
		[T.TALK, "npc_archer", "Віднеси Місячний камінь Лірі: вона вставить його в лінзу"],
		[T.INTERACT, "mission_beacon", "Піднімися до Руїн Вартової Фортеці та запали маяк"],
		[T.KILL, "tower_guardian", "Здолай Вартового Маяка, який не дає вогню розгорітися"],
	]
	_make_side_quest("dead_beacon", "Згаслий Маяк", "npc_border", "Командир Ратмир",
		"Східний маяк Вартової Фортеці погас, і разом із ним зникли вісім дозорних. Ліра знає, як відновити лінзу, але для цього потрібен Місячний камінь зі Склепу Забутих Королів. Дорога на південь небезпечна.",
		specs, 220,
		["Маяк на Вартовій Фортеці погас дві ночі тому. Вісім моїх людей пішли його запалити — і не повернулися. Лінзу робила чародійка Ліра, її вежа на захід від застави. Іди до неї: без лінзи маяк не запалити, а без маяка Око бачить нас, як на долоні.",
		"Маяк досі мертвий. Не повертайся без Місячного каменю — а краще з маяком, що горить.",
		"Ти запалив його?! Бачу вогонь на горі навіть звідси… Вісім моїх людей не повернулися, але тепер хоч дорога освітлена. Візьми плату — і Місячну лінзу: чародійка казала, вона посилює удари по всьому, що породило Око.",
		"Маяк горить, застава жива. Якщо будеш у Вартовій Фортеці — підніми руку, дозорні тебе пам'ятатимуть.",
		"ПРИЙНЯТИ МІСІЮ: ЗГАСЛИЙ МАЯК"])
	var data: QuestData = _definitions["dead_beacon"]
	data.category = "Місія"
	data.turn_in_label = "ВІДДАТИ ЗВІТ І ОТРИМАТИ НАГОРОДУ"
	var lens := QuestReward.new()
	lens.item_id = "moon_lens"
	lens.item_name = "Місячна лінза"
	lens.item_count = 1
	data.rewards.append(lens)


func _register_main_story() -> void:
	## Головний сюжет «Попіл і Корона» (12 кроків): староста → ліхтарник → кладовище → Лицар Попелу →
	## коваль → руїни абатства → Некромант → маг → Попеляста цитадель → вершина → вівтар → Страж Ока.
	var T := QuestObjective.Type
	var specs: Array = [
		[T.TALK, "npc_elder", "Поговори зі старостою Мироном у Селі Попелу: чому гаснуть вогні?"],
		[T.TALK, "npc_lamplighter", "Розпитай ліхтарника Ореста про згаслі вогні вздовж дороги"],
		[T.REACH, "story_cemetery", "Дійди до Забутого кладовища та огляни згаслі вогні (схід від села)"],
		[T.KILL, "ash_knight", "Здолай Лицаря Попелу — перший уламок Печатки в нього"],
		[T.TALK, "npc_blacksmith", "Віднеси уламок ковалю Каталану в кузню (схід)"],
		[T.REACH, "story_abbey", "Дійди до Руїн Абатства (захід від села)"],
		[T.KILL, "necromancer", "Здолай Некроманта Руїн — другий уламок Печатки"],
		[T.TALK, "npc_mage", "Покажи уламки магу Вальмеру в його хатині на півночі"],
		[T.KILL, "citadel_guardian", "Здолай Вартового Цитаделі в Попелястій цитаделі — третій уламок"],
		[T.REACH, "summit_crown", "Зійди серпантином на вершину Чорної Гори (північний захід)"],
		[T.INTERACT, "story_altar", "З'єднай три уламки Печатки на Вівтарі Ока"],
		[T.KILL, "eye_guardian", "Переможи Стража Ока"],
		[T.INTERACT, "eye_destroyed", "Дістанься до Вівтаря Ока й вирви Око з його місця"],
	]
	var data := QuestData.new()
	data.id = "main_story"
	data.title = "Попіл і Корона"
	data.category = "Головний сюжет"
	data.giver_id = "npc_elder"
	data.giver_name = "Староста Мирон"
	data.description = "Вогні Попелястих земель гаснуть один за одним: Око Чорної Гори прокинулося. Три уламки Стародавньої Печатки, розкидані по землях, можуть його приспати — якщо зібрати їх і з'єднати на Вівтарі Ока. Дороги до Вівтаря не знає ніхто: монахи Ордену Печатки колись розірвали Атлас Корони й роздали шматки хранителям."
	data.turn_in = false
	for spec in specs:
		var objective := QuestObjective.new()
		objective.type = spec[0]
		objective.target_id = str(spec[1])
		objective.text = str(spec[2])
		data.objectives.append(objective)
	var reward := QuestReward.new()
	reward.coins = 150
	data.rewards.append(reward)
	register_data(data)


func _make_side_quest(quest_id: String, title: String, giver_id: String, giver_name: String, description: String, objective_specs: Array, coins: int, dialogues: Array) -> void:
	## dialogues: [пропозиція, активний, готовий, виконаний, текст кнопки прийняття]
	var data := QuestData.new()
	data.id = quest_id
	data.title = title
	data.category = "Побічне доручення"
	data.giver_id = giver_id
	data.giver_name = giver_name
	data.description = description
	for spec in objective_specs:
		var objective := QuestObjective.new()
		objective.type = spec[0]
		objective.target_id = str(spec[1])
		objective.text = str(spec[2])
		if spec.size() > 3:
			objective.count = int(spec[3])
		data.objectives.append(objective)
	var reward := QuestReward.new()
	reward.coins = coins
	data.rewards.append(reward)
	data.dialogue_offer = str(dialogues[0])
	data.dialogue_active = str(dialogues[1])
	data.dialogue_ready = str(dialogues[2])
	data.dialogue_done = str(dialogues[3])
	data.accept_label = str(dialogues[4])
	register_data(data)


func _register_side_quests() -> void:
	## Міні-квести мешканців Села Попелу та околиць.
	var T := QuestObjective.Type
	_make_side_quest("marta_candle", "Свічка на вікні", "npc_marta", "Марта",
		"Марта щовечора ставить свічку на вікно — раптом Арне повернеться. Свічки закінчилися. Сестра Аліна в Руїнах Абатства має освячені.",
		[[T.TALK, "npc_priest", "Попроси в сестри Аліни освячену свічку (Руїни Абатства, захід)"]], 14,
		["Мій Арне пішов у вартові й не повернувся. Я лишаю свічку на вікні, але вона догоріла. Сестра Аліна в абатстві має освячені — принесеш одну?",
		"Свічка на вікні ще горить. Але ненадовго.", "Це вона? Свічка тепла, наче її тримали в долонях… Дякую тобі, мандрівнику. Ось, візьми — усе, що можу дати.",
		"Світло на вікні знову горить. Хай вогонь береже й тебе.", "ПРИЙНЯТИ: СВІЧКА НА ВІКНІ"])
	_make_side_quest("captain_patrol", "Дозір Капітана", "npc_captain", "Капітан Гедвіг",
		"Капітан Гедвіг просить зачистити дорогу від попелястих вартових: чотири переможені — і тракт знову безпечний.",
		[[T.KILL, "ashen_wraith", "Знищ чотирьох Попелястих вартових на дорогах", 4]], 30,
		["Кожної ночі до цитаделі підбираються мертві вартові. У мене лишилося дев'ятеро втомлених людей. Вбий чотирьох — і я заплачу з власної кишені.",
		"Дозвіл на дозір дано. Чотири вартові, не менше.", "Дорога спокійна. Бачу це за твоїми очима. Ось плата, воїне.", "Тракт чистий. Якщо знову запахне попелом — я пошлю по тебе.", "ПРИЙНЯТИ: ДОЗІР КАПІТАНА"])
	_make_side_quest("merchant_crate", "Загублений вантаж", "npc_merchant", "Торговець Бруно",
		"Торговець Бруно загубив ящик із товаром біля Табору вигнанців.",
		[[T.COLLECT, "merchant_crate", "Знайди ящик Бруно біля Табору вигнанців (поруч зі стартом)"]], 20,
		["Мій віз перекинувся ще на тракті, ящик із ліками зник біля Табору вигнанців. Принеси — і я заплачу.",
		"Ящик має бути десь біля Табору вигнанців.", "Мій ящик! Цілий! Ти врятував мене від розорення. Ось нагорода.", "Якщо потрібні припаси — заходь, торгуватимемо.", "ПРИЙНЯТИ: ЗАГУБЛЕНИЙ ВАНТАЖ"])
	_make_side_quest("farmer_herbs", "Трави для вдови", "npc_farmer", "Йоган",
		"Йоган просить зібрати три пучки цілющих трав навколо села.",
		[[T.COLLECT, "healing_herb", "Збери три пучки цілющих трав навколо Села Попелу", 3]], 16,
		["Моя дружина хворіє. Цілющі трави ще ростуть навколо села, але вночі я не наважуюсь вийти. Збери три пучки, добре?",
		"Трав треба три. Шукай світлі пучки біля дороги.", "Три пучки… Вона житиме. Візьми монети, більше не маю чим віддячити.", "Дружині краще. Дякуємо, мандрівнику.", "ПРИЙНЯТИ: ТРАВИ ДЛЯ ВДОВИ"])


func get_step(quest_id: String) -> int:
	return int(_states.get(quest_id, {}).get("step", 0))


func get_target_id(quest_id: String) -> String:
	## ID поточної цілі квесту (для маркерів на карті).
	if not _definitions.has(quest_id) or get_quest_state(quest_id) != "active":
		return ""
	var data: QuestData = _definitions[quest_id]
	var step := get_step(quest_id)
	return data.objectives[step].target_id if step < data.objectives.size() else ""


func register_data(data: QuestData) -> void:
	if not _definitions.has(data.id):
		_order.append(data.id)
	_definitions[data.id] = data


func register_quest(quest_id: String, definition: Dictionary) -> void:
	## Сумісність: опис квесту словником (ціль interaction_id = INTERACT/TALK).
	if quest_id.is_empty():
		return
	var data := QuestData.new()
	data.id = quest_id
	data.title = str(definition.get("title", quest_id))
	data.category = str(definition.get("category", "Доручення"))
	data.giver_id = str(definition.get("giver_id", ""))
	data.giver_name = str(definition.get("giver_name", ""))
	data.description = str(definition.get("description", ""))
	data.set_meta("branch", str(definition.get("branch", "")))
	for objective_def in definition.get("objectives", []):
		var objective := QuestObjective.new()
		objective.type = QuestObjective.Type.INTERACT
		objective.target_id = str(objective_def.get("interaction_id", ""))
		objective.text = str(objective_def.get("text", ""))
		data.objectives.append(objective)
	var reward := QuestReward.new()
	reward.coins = int(definition.get("reward", 0))
	data.rewards.append(reward)
	register_data(data)


func get_data(quest_id: String) -> QuestData:
	return _definitions.get(quest_id, null)


# --- Фракційне доручення (будується залежно від присяги) ----------------------------------

func prepare_faction_quest(branch: String) -> String:
	if branch not in ["principality", "mountain"]:
		return ""
	var quest_id := get_faction_quest_id(branch)
	if _definitions.has(quest_id):
		return quest_id
	var giver_id := "npc_castellan" if branch == "principality" else "npc_acolyte"
	var giver_name := "Кастелян Едрик" if branch == "principality" else "Послушник Варк"
	var target_text := "Печатку Зорі в Зруйнованій Обсерваторії" if branch == "principality" else "Відлуння Ока біля Фортеці Чорного Прапора"
	register_quest(quest_id, {
		"title": "Печатка Зорі" if branch == "principality" else "Відлуння Ока",
		"category": "Сюжетне доручення",
		"giver_id": giver_id,
		"giver_name": giver_name,
		"branch": branch,
		"description": "Знайди %s та поверни доказ тому, кому присягнув." % target_text,
		"reward": 12,
		"objectives": [
			{"text": "Знайти %s" % target_text, "interaction_id": "quest_target"},
			{"text": "Повернутися до %s" % giver_name, "interaction_id": giver_id}
		]
	})
	_states[quest_id] = {"status": "available", "step": 0, "count": 0}
	return quest_id


func start_faction_quest(branch: String) -> bool:
	var quest_id := prepare_faction_quest(branch)
	return false if quest_id.is_empty() else accept_quest(quest_id)


func get_faction_quest_id(branch: String) -> String:
	return "faction_mountain" if branch == "mountain" else "faction_principality"


# --- Перебіг квесту -----------------------------------------------------------------

func get_quest_state(quest_id: String) -> String:
	if not _definitions.has(quest_id):
		return "unknown"
	return str(_states.get(quest_id, {}).get("status", "available"))


func accept_quest(quest_id: String) -> bool:
	if not _definitions.has(quest_id):
		push_warning("QuestManager: невідомий квест '%s'." % quest_id)
		return false
	if get_quest_state(quest_id) != "available":
		return false
	_states[quest_id] = {"status": "active", "step": 0, "count": 0}
	if _tracked_quest_id.is_empty() or get_quest_state(_tracked_quest_id) not in ["active", "ready"]:
		_tracked_quest_id = quest_id
	_check_collect(quest_id)
	quest_log_changed.emit()
	return true


func record_interaction(interaction_id: String) -> bool:
	## Розмова з NPC або огляд об'єкта світу (цілі TALK та INTERACT).
	var changed := _notify(["talk", "interact"], interaction_id, 1)
	if changed:
		quest_log_changed.emit()
	return changed


func reward_coins(amount: int, reason: String = "") -> void:
	if amount > 0:
		coins_earned.emit(amount, reason)


func notify_kill(enemy_type: String) -> void:
	if _notify(["kill"], enemy_type, 1):
		quest_log_changed.emit()
	# Міні-боси охороняють шматки Атласу Корони.
	if AtlasPieces.BY_KILL.has(enemy_type):
		add_map_piece(str(AtlasPieces.BY_KILL[enemy_type]))


func set_objective_text(quest_id: String, index: int, text: String) -> void:
	## Живий прогрес у журналі й на HUD (напр. «Хвиля 2 з 3»).
	if not _definitions.has(quest_id):
		return
	var data: QuestData = _definitions[quest_id]
	if index < 0 or index >= data.objectives.size() or data.objectives[index].text == text:
		return
	data.objectives[index].text = text
	quest_log_changed.emit()


func atlas_gate_open() -> bool:
	for id in AtlasPieces.GATE:
		if not has_map_piece(str(id)):
			return false
	return true


func notify_reach(location_id: String) -> void:
	if _notify(["reach"], location_id, 1):
		quest_log_changed.emit()


func discover_location(location_id: String, display_name: String) -> void:
	# На вершину не пускає неповний Атлас: без нього шлях невідомий, зона не зараховується.
	if location_id == "summit_crown" and not has_map_piece(AtlasPieces.FINAL):
		return
	if not _discovered.has(location_id):
		_discovered[location_id] = true
		location_discovered.emit(location_id, display_name)
	notify_reach(location_id)


func _notify(types: Array, target_id: String, amount: int) -> bool:
	var changed := false
	for quest_id in _order:
		var state: Dictionary = _states.get(quest_id, {})
		if str(state.get("status", "")) != "active":
			continue
		var data: QuestData = _definitions[quest_id]
		var step := int(state.get("step", 0))
		if step >= data.objectives.size():
			continue
		var objective: QuestObjective = data.objectives[step]
		if objective.type_key() not in types or objective.target_id != target_id:
			continue
		state["count"] = int(state.get("count", 0)) + amount
		_states[quest_id] = state
		if int(state["count"]) >= maxi(objective.count, 1):
			_advance(quest_id)
		else:
			quest_progressed.emit(quest_id, "%s (%d/%d)" % [objective.text, int(state["count"]), objective.count], step, data.objectives.size())
		changed = true
	return changed


func _advance(quest_id: String) -> void:
	var data: QuestData = _definitions[quest_id]
	var state: Dictionary = _states[quest_id]
	var step := int(state.get("step", 0))
	var finished: QuestObjective = data.objectives[step]
	step += 1
	state["step"] = step
	state["count"] = 0
	if step >= data.objectives.size():
		state["status"] = "ready"
	_states[quest_id] = state
	quest_progressed.emit(quest_id, finished.text, step, data.objectives.size())
	if step >= data.objectives.size() and not data.turn_in:
		claim_quest(quest_id)
		return
	_check_collect(quest_id)


func _check_collect(quest_id: String) -> void:
	## Якщо предмет для поточної цілі вже є в сумці — ціль зараховується одразу.
	var data: QuestData = _definitions[quest_id]
	var state: Dictionary = _states[quest_id]
	var step := int(state.get("step", 0))
	if str(state.get("status", "")) != "active" or step >= data.objectives.size():
		return
	var objective: QuestObjective = data.objectives[step]
	if objective.type == QuestObjective.Type.COLLECT and get_item_count(objective.target_id) >= maxi(objective.count, 1):
		_advance(quest_id)


func claim_quest(quest_id: String) -> int:
	## Повертає монети нагороди; -1 — квест ще не готовий до здачі.
	if get_quest_state(quest_id) != "ready":
		return -1
	var data: QuestData = _definitions[quest_id]
	_states[quest_id]["status"] = "completed"
	for reward in data.rewards:
		if not reward.item_id.is_empty():
			add_item(reward.item_id, reward.item_name, reward.item_count)
	if _tracked_quest_id == quest_id:
		_tracked_quest_id = _find_next_tracked_quest()
	var coins := data.total_coins()
	quest_claimed.emit(quest_id, coins)
	_refresh_locks(true)
	quest_log_changed.emit()
	return coins


func _refresh_locks(emit_unlocks: bool) -> void:
	for quest_id in _order:
		var status := str(_states.get(quest_id, {}).get("status", ""))
		if status in ["active", "ready", "completed"]:
			continue
		var data: QuestData = _definitions[quest_id]
		var open := true
		for prerequisite in data.prerequisites:
			if get_quest_state(prerequisite) != "completed":
				open = false
				break
		var new_status := "available" if open else "locked"
		if new_status != status:
			_states[quest_id] = {"status": new_status, "step": 0, "count": 0}
			if new_status == "available" and status == "locked" and emit_unlocks:
				quest_unlocked.emit(quest_id)


# --- Атлас Корони (розірвана карта) ----------------------------------------------------
## Знайдені шматки живуть окремо від інвентарю й ніколи не забираються (лише нова гра скидає їх).

var _map_pieces: Array[String] = []
var _map_seen: Array[String] = []


func _init_atlas() -> void:
	_map_pieces = [AtlasPieces.START]
	_map_seen = [AtlasPieces.START]
	_inventory["atlas_piece"] = 1
	_item_names["atlas_piece"] = "Фрагменти Атласу Корони"


func add_map_piece(piece_id: String) -> bool:
	if not AtlasPieces.PIECES.has(piece_id) or piece_id in _map_pieces:
		return false
	_map_pieces.append(piece_id)
	_inventory["atlas_piece"] = _map_pieces.size()
	_item_names["atlas_piece"] = "Фрагменти Атласу Корони"
	map_piece_added.emit(piece_id, _map_pieces.size(), AtlasPieces.total())
	quest_log_changed.emit()
	return true


func has_map_piece(piece_id: String) -> bool:
	return piece_id in _map_pieces


func get_map_pieces() -> Array[String]:
	return _map_pieces.duplicate()


func get_map_piece_count() -> int:
	return _map_pieces.size()


func is_map_piece_seen(piece_id: String) -> bool:
	return piece_id in _map_seen


func mark_map_piece_seen(piece_id: String) -> void:
	if piece_id in _map_pieces and not piece_id in _map_seen:
		_map_seen.append(piece_id)


# --- Інвентар ------------------------------------------------------------------------

func add_item(item_id: String, item_name: String = "", amount: int = 1) -> void:
	_inventory[item_id] = get_item_count(item_id) + amount
	if not item_name.is_empty():
		_item_names[item_id] = item_name
	item_added.emit(item_id, get_item_name(item_id), _inventory[item_id])
	var changed := false
	for quest_id in _order:
		var before := str(_states.get(quest_id, {}).get("step", -1))
		_check_collect(quest_id)
		if str(_states.get(quest_id, {}).get("step", -1)) != before:
			changed = true
	if changed:
		quest_log_changed.emit()


func get_item_count(item_id: String) -> int:
	return int(_inventory.get(item_id, 0))


func has_item(item_id: String) -> bool:
	return get_item_count(item_id) > 0


func get_item_name(item_id: String) -> String:
	return str(_item_names.get(item_id, item_id))


func get_inventory() -> Dictionary:
	return _inventory.duplicate()


# --- Запити для UI --------------------------------------------------------------------

func get_quests_for_giver(giver_id: String) -> Array[QuestData]:
	var result: Array[QuestData] = []
	for quest_id in _order:
		var data: QuestData = _definitions[quest_id]
		if data.giver_id == giver_id:
			result.append(data)
	return result


func get_dialogue_quest(giver_id: String) -> QuestData:
	## Найактуальніший квест замовника: готовий до здачі > активний > доступний > останній виконаний.
	var best: QuestData = null
	var best_rank := -1
	for data in get_quests_for_giver(giver_id):
		var rank: int = {"ready": 4, "active": 3, "available": 2, "completed": 1}.get(get_quest_state(data.id), 0)
		if rank > best_rank:
			best_rank = rank
			best = data
	return best if best_rank > 0 else null


func get_quest_summary(quest_id: String) -> Dictionary:
	if not _definitions.has(quest_id):
		return {}
	var data: QuestData = _definitions[quest_id]
	var state: Dictionary = _states.get(quest_id, {})
	var status := str(state.get("status", "available"))
	var step := int(state.get("step", 0))
	var current_text := "Замовник: %s. Поговори, щоб отримати доручення." % (data.giver_name if not data.giver_name.is_empty() else "невідомо")
	if status == "active" and step < data.objectives.size():
		var objective: QuestObjective = data.objectives[step]
		current_text = objective.text
		if objective.count > 1:
			current_text += "  (%d/%d)" % [int(state.get("count", 0)), objective.count]
	elif status == "ready":
		current_text = "Повернися до замовника (%s) та забери нагороду." % data.giver_name
	elif status == "completed":
		current_text = "Доручення виконано. Нагороду отримано."
	elif status == "locked":
		current_text = "Ще не час."
	return {
		"id": quest_id,
		"title": data.title,
		"category": data.category,
		"giver_name": data.giver_name,
		"description": data.description,
		"status": status,
		"progress": step,
		"total": data.objectives.size(),
		"objective_text": current_text,
		"reward": data.total_coins(),
		"branch": str(data.get_meta("branch", ""))
	}


func get_journal_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for quest_id in _order:
		if get_quest_state(quest_id) == "locked":
			continue
		entries.append(get_quest_summary(quest_id))
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("title", "")) < str(b.get("title", ""))
	)
	return entries


func get_active_summaries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for quest_id in _order:
		if get_quest_state(quest_id) in ["active", "ready"]:
			entries.append(get_quest_summary(quest_id))
	return entries


func get_tracked_summary() -> Dictionary:
	if _tracked_quest_id.is_empty() or get_quest_state(_tracked_quest_id) not in ["active", "ready"]:
		_tracked_quest_id = _find_next_tracked_quest()
	return {} if _tracked_quest_id.is_empty() else get_quest_summary(_tracked_quest_id)


func set_tracked_quest(quest_id: String) -> bool:
	if get_quest_state(quest_id) not in ["active", "ready"]:
		return false
	if _tracked_quest_id != quest_id:
		_tracked_quest_id = quest_id
		quest_log_changed.emit()
	return true


func get_tracked_target_id() -> String:
	## ID поточної цілі відстежуваного квесту (для маркерів у світі).
	var quest_id := _tracked_quest_id if not _tracked_quest_id.is_empty() else _find_next_tracked_quest()
	if quest_id.is_empty():
		return ""
	var data: QuestData = _definitions[quest_id]
	var state: Dictionary = _states.get(quest_id, {})
	if str(state.get("status", "")) == "ready":
		return data.giver_id
	var step := int(state.get("step", 0))
	return data.objectives[step].target_id if step < data.objectives.size() else ""


func reset_all() -> void:
	_states.clear()
	_inventory.clear()
	_item_names.clear()
	_discovered.clear()
	_init_atlas()
	_tracked_quest_id = ""
	for branch in ["principality", "mountain"]:
		var quest_id := get_faction_quest_id(branch)
		if _definitions.has(quest_id):
			_definitions.erase(quest_id)
			_order.erase(quest_id)
	_refresh_locks(false)
	quest_log_changed.emit()


func get_completed_count() -> int:
	var count := 0
	for quest_id in _order:
		if get_quest_state(quest_id) == "completed":
			count += 1
	return count


func _find_next_tracked_quest() -> String:
	for quest_id in _order:
		if get_quest_state(quest_id) in ["active", "ready"]:
			return quest_id
	return ""
