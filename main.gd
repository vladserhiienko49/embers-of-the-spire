extends Node3D

const MENU_BACKGROUND: Texture2D = preload("res://assets/menu_bg.png")
const MENU_AMBIENCE: AudioStream = preload("res://audio/music/music_menu.wav")
const INTRO_SOUNDTRACK: AudioStream = preload("res://audio/music/music_prologue.wav")
const INTRO_DURATION: float = 27.0
const EMBER_SCRIPT: GDScript = preload("res://menu_embers.gd")
const WORLD_MAP_SCRIPT: GDScript = preload("res://world_map_view.gd")
const NAMEPLATES_SCRIPT: GDScript = preload("res://scripts/ui/nameplates.gd")
const PIXEL_TITLE_SCRIPT: GDScript = preload("res://scripts/ui/pixel_title.gd")
const GAME_TITLE: String = "EMBERS OF THE SPIRE"
const MENU_CAMERA_SCRIPT: GDScript = preload("res://scripts/ui/menu_camera.gd")
const CUTSCENE_SCRIPT: GDScript = preload("res://scripts/ui/cutscene_director.gd")
## NPC, розмова з якими супроводжується кінематографічним наїздом камери.
## Мешканці східних і південних земель: розмови без квестів (атмосфера, підказки).
const FRONTIER_TALK: Dictionary = {
	"npc_miner": ["ГРІМ — БРИГАДИР КОПАЛЕНЬ", "Сіль тут біла, як кістка, а штольні — чорні, як Око. Минулого тижня з нижнього ярусу вийшла вагонетка без людей. Тепер ми працюємо лише вдень.\n\nЯкщо йдеш на південь — тримайся тракту. Склеп Забутих Королів стережуть ті, хто вже заплатив життям за корону."],
	"npc_herder": ["ОЛЯ — ПАСТУШКА", "Вівці зникають не вночі, а на світанку, коли тінь від Чорної Гори сягає броду. Не питай мене чому — просто не ходи сама за ліс.\n\nУ вежі на захід від нас живе Ліра: вона навчає стріляти з лука навіть тих, хто боїться тятиви."],
	"npc_hermit": ["ЯРИН — ВІДЛЮДНИК", "Я пішов від людей, щоб почути гору. Вона не мовчить, лише чекає. Камені Мовчання на північ звідси — єдине місце, де вона втихає.\n\nЯкщо в тебе є лук, постій тут, коли стемніє: олені виходять до криниці."],
	"npc_border": ["РАТМИР — КОМАНДИР ЗАСТАВИ", "Східна застава тримається двадцять років. Далі — Руїни Вартової Фортеці: там стоїть вартовий, якого ми не змогли підняти з мертвих і не змогли вбити.\n\nЗ мечем у ближньому бою він швидший за тебе. Спробуй дістати його стрілою здалеку."],
	"npc_nun": ["МАР'ЯНА — СЕСТРА МОНАСТИРЯ", "Сіре — колір попелу й спокою. Ми молимось за всіх, хто йде на вершину, навіть за тих, хто не повертається.\n\nСестра Аліна з Руїн Абатства — моя наставниця. Передай їй, що наші свічки ще горять."],
	"npc_farmhand": ["ТАРАС — ФЕРМЕР", "Земля на півдні родюча, хоч і присипана попелом. Опудало на нашому полі уночі ворушить руками — я вже не лякаюсь.\n\nУ клуні є сіно й тепло, але не затримуйся: вартові у Болотній хатині не люблять гостей."],
}

const CINEMATIC_NPCS: Array[String] = ["npc_castellan", "npc_acolyte", "npc_lamplighter", "npc_elder", "npc_priest", "npc_scholar", "npc_mage", "npc_druid", "npc_blacksmith", "npc_merchant", "npc_captain", "npc_marta", "npc_farmer", "npc_archer", "npc_miner", "npc_herder", "npc_hermit", "npc_border", "npc_nun", "npc_farmhand", "npc_priest"]

var score: int = 0
var game_started: bool = false
var current_screen: String = "main"
var settings_return_screen: String = "main"
var music_volume_percent: float = 46.0

var player: CharacterBody3D
var world_generator: Node3D
var objective_label: Label
var interaction_label: Label
var story_toast_panel: PanelContainer
var story_toast_title: Label
var story_toast_body: Label
var story_toast_tween: Tween
var story_layer: CanvasLayer
var story_root: Control
var oath_panel: PanelContainer
var oath_title: Label
var oath_body: Label
var menu_layer: CanvasLayer
var menu_root: Control
var hud_layer: CanvasLayer
var hud_panel: PanelContainer
var hud_root: Control
var score_label: Label
var vitals_panel: PanelContainer
var health_bar: ProgressBar
var stamina_bar: ProgressBar
var health_value_label: Label
var stamina_value_label: Label
var day_cycle_label: Label
var combat_toast_cooldown: float = 0.0
var minimap_panel: PanelContainer
var minimap_view: Control
var map_layer: CanvasLayer
var map_root: Control
var fullscreen_map_view: Control
var music_player: AudioStreamPlayer
var intro_audio_player: AudioStreamPlayer
var intro_layer: CanvasLayer
var intro_root: Control
var intro_background: TextureRect
var intro_black: ColorRect
var intro_copy: Control
var intro_kicker: Label
var intro_body: Label
var intro_playing: bool = false

# Діалогове вікно Частини 3 — окреме від незмінного меню присяги Частини 2.
var world_dialogue_layer: CanvasLayer
var world_dialogue_root: Control
var world_dialogue_title: Label
var world_dialogue_body: Label
var world_dialogue_scroll: ScrollContainer
var world_dialogue_actions: VBoxContainer

# Етап 3 — трекер завдань і повноцінний журнал.
var quest_tracker_panel: PanelContainer
var quest_tracker_title: Label
var quest_tracker_label: Label
var quest_tracker_refresh_timer: float = 0.0
var quest_journal_layer: CanvasLayer
var quest_journal_root: Control
var quest_journal_entries: VBoxContainer
var quest_journal_detail: Label
var quest_journal_return_screen: String = "game"
var nameplate_layer: CanvasLayer
var menu_camera: Camera3D
var cutscene: Node
var _cinematics_seen: Dictionary = {}
var _menu_cam_on: bool = false
var crosshair: ColorRect
var damage_vignette: TextureRect
var extras: GameExtras


func _ready() -> void:
	player = get_node_or_null("Player") as CharacterBody3D
	world_generator = get_node_or_null("WorldGenerator") as Node3D
	if world_generator and world_generator.has_signal("dungeon_exited"):
		world_generator.connect("dungeon_exited", _on_dungeon_exited)
	_create_music()
	_create_hud()
	_create_quest_ui()
	_connect_player_combat_signals()
	if not QuestManager.quest_log_changed.is_connected(_on_quest_log_changed):
		QuestManager.quest_log_changed.connect(_on_quest_log_changed)
	if not QuestManager.quest_progressed.is_connected(_on_quest_progressed):
		QuestManager.quest_progressed.connect(_on_quest_progressed)
	_create_menu_layer()
	_create_menu_camera()
	_create_cutscene_director()
	_create_story_ui()
	_create_world_dialogue_ui()
	_create_map_ui()
	_create_nameplates()
	_compact_hud()
	extras = GameExtras.new()
	extras.name = "GameExtras"
	add_child(extras)
	extras.setup(self)
	AudioManager.register_world(world_generator, player)
	QuestManager.quest_claimed.connect(_on_quest_claimed_sound)
	_apply_psx_materials()
	if player and player.has_signal("damaged"):
		player.connect("damaged", _on_player_damaged)
	QuestManager.quest_unlocked.connect(_on_quest_unlocked)
	QuestManager.item_added.connect(_on_item_added)
	QuestManager.map_piece_added.connect(_on_map_piece_added)
	QuestManager.location_discovered.connect(_on_location_discovered)
	_show_main_menu()
	_update_score()


func _apply_psx_materials() -> void:
	## Решта StandardMaterial3D (лицар, меч, щит, біомні плями) -> PSX-шейдер.
	## Рухомі об'єкти — у локальних координатах, статичний світ — у світових.
	if player:
		PSXMaterials.convert_tree(player, false)
	if world_generator:
		PSXMaterials.convert_tree(world_generator, true)


func _process(delta: float) -> void:
	if minimap_panel:
		minimap_panel.visible = current_screen == "game" and game_started
	if vitals_panel:
		vitals_panel.visible = current_screen == "game" and game_started
	if day_cycle_label:
		day_cycle_label.visible = current_screen == "game" and game_started
		if day_cycle_label.visible and world_generator and world_generator.has_method("get_day_phase_label"):
			day_cycle_label.text = str(world_generator.call("get_day_phase_label"))
	combat_toast_cooldown = maxf(0.0, combat_toast_cooldown - delta)
	_update_audio_context()
	_update_menu_camera()
	if nameplate_layer:
		nameplate_layer.visible = current_screen == "game" and game_started
	if quest_tracker_panel:
		quest_tracker_panel.visible = current_screen == "game" and game_started
	if quest_tracker_panel and quest_tracker_panel.visible:
		quest_tracker_refresh_timer -= delta
		if quest_tracker_refresh_timer <= 0.0:
			quest_tracker_refresh_timer = 0.25
			_refresh_quest_tracker()
	if current_screen != "game" or not game_started or world_generator == null:
		if interaction_label:
			interaction_label.visible = false
		if crosshair:
			crosshair.visible = false
		return
	if objective_label:
		objective_label.text = str(world_generator.call("get_current_objective"))
	if interaction_label:
		var hint: String = str(world_generator.call("get_interaction_hint"))
		interaction_label.text = hint
		interaction_label.visible = not hint.is_empty()
		_update_crosshair(not hint.is_empty())


func _input(event: InputEvent) -> void:
	# Під час катсцени клавіші лише пропускають її (обробляє CutsceneDirector).
	if cutscene and event is InputEventKey and bool(cutscene.call("is_skippable")):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_J:
		if current_screen == "game" and game_started:
			_open_quest_journal("game")
		elif current_screen == "quest_journal":
			_close_quest_journal()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("world_map"):
		if event is InputEventKey and (event as InputEventKey).echo:
			return
		if current_screen == "game" and game_started:
			_open_world_map()
		elif current_screen == "map":
			_close_world_map()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("interact") and current_screen == "game" and game_started:
		_handle_story_interaction()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		if current_screen == "map":
			_close_world_map()
			get_viewport().set_input_as_handled()
		elif current_screen == "game" and game_started:
			_show_pause_menu()
			get_viewport().set_input_as_handled()
		elif current_screen == "oath_choice":
			_close_oath_choice()
			get_viewport().set_input_as_handled()
		elif current_screen == "pause":
			_resume_game()
			get_viewport().set_input_as_handled()
		elif current_screen == "settings":
			_return_from_settings()
			get_viewport().set_input_as_handled()
		elif current_screen == "controls":
			_return_from_controls()
			get_viewport().set_input_as_handled()
		elif current_screen == "credits":
			_show_main_menu()
			get_viewport().set_input_as_handled()
		elif current_screen == "dialogue":
			_close_world_dialogue()
		elif current_screen == "quest_journal":
			_close_quest_journal()
			get_viewport().set_input_as_handled()


func _add_volume_row(column: VBoxContainer, caption: String, key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size = Vector2(178.0, 0.0)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("#ded8ca"))
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value = AudioManager.get_volume(key)
	slider.value_changed.connect(func(value: float) -> void: AudioManager.set_volume(key, value))
	slider.drag_ended.connect(func(_changed: bool) -> void: AudioManager.play_ui("ui_click", -6.0))
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(36.0, 0.0)
	value_label.text = "%d" % int(slider.value)
	value_label.add_theme_font_size_override("font_size", 13)
	value_label.add_theme_color_override("font_color", Color("#c9b88f"))
	slider.value_changed.connect(func(value: float) -> void: value_label.text = "%d" % int(value))
	row.add_child(value_label)


func _update_audio_context() -> void:
	var context := "menu"
	if _ending_started or (world_generator and bool(world_generator.get("eye_destroyed"))):
		context = "finale"
	elif intro_playing:
		context = "intro"
	elif game_started:
		context = "paused" if current_screen in ["pause", "settings", "controls", "map", "quest_journal"] else "game"
	AudioManager.set_context(context)

func add_coin() -> void:
	score += 1
	AudioManager.play_sfx("coin", -3.0, 0.05)
	_update_score()


# -----------------------------------------------------------------------------
# MUSIC
# -----------------------------------------------------------------------------
func _create_music() -> void:
	# Музикою керує AudioManager (autoload): меню, дослідження, каземати, бій.
	pass


func _set_music_volume(value: float) -> void:
	music_volume_percent = value
	AudioManager.set_volume("music", value)


# -----------------------------------------------------------------------------
# IN-GAME HUD
# -----------------------------------------------------------------------------
func _create_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 5
	add_child(hud_layer)

	hud_root = Control.new()
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud_root)

	hud_panel = PanelContainer.new()
	hud_panel.position = Vector2(26.0, 24.0)
	hud_panel.custom_minimum_size = Vector2(190.0, 48.0)
	hud_panel.add_theme_stylebox_override("panel", _make_hud_style())
	hud_root.add_child(hud_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	hud_panel.add_child(margin)

	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 18)
	score_label.add_theme_color_override("font_color", Color("#ead7ad"))
	margin.add_child(score_label)
	hud_panel.visible = false

	objective_label = Label.new()
	objective_label.position = Vector2(26.0, 82.0)
	objective_label.size = Vector2(780.0, 36.0)
	objective_label.add_theme_font_size_override("font_size", 15)
	objective_label.add_theme_color_override("font_color", Color("#e7d5b4"))
	objective_label.add_theme_constant_override("outline_size", 3)
	objective_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	objective_label.visible = false
	hud_root.add_child(objective_label)

	interaction_label = Label.new()
	interaction_label.anchor_left = 0.18
	interaction_label.anchor_top = 0.88
	interaction_label.anchor_right = 0.82
	interaction_label.anchor_bottom = 0.95
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interaction_label.add_theme_font_size_override("font_size", 17)
	interaction_label.add_theme_color_override("font_color", Color("#f2dfb9"))
	interaction_label.add_theme_constant_override("outline_size", 4)
	interaction_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	interaction_label.visible = false
	hud_root.add_child(interaction_label)

	story_toast_panel = PanelContainer.new()
	story_toast_panel.anchor_left = 0.20
	story_toast_panel.anchor_top = 0.72
	story_toast_panel.anchor_right = 0.80
	story_toast_panel.anchor_bottom = 0.91
	story_toast_panel.add_theme_stylebox_override("panel", _make_hud_style())
	story_toast_panel.modulate.a = 0.0
	story_toast_panel.visible = false
	hud_root.add_child(story_toast_panel)
	var toast_margin := MarginContainer.new()
	toast_margin.add_theme_constant_override("margin_left", 22)
	toast_margin.add_theme_constant_override("margin_right", 22)
	toast_margin.add_theme_constant_override("margin_top", 12)
	toast_margin.add_theme_constant_override("margin_bottom", 12)
	story_toast_panel.add_child(toast_margin)
	var toast_column := VBoxContainer.new()
	toast_column.add_theme_constant_override("separation", 6)
	toast_margin.add_child(toast_column)
	story_toast_title = Label.new()
	story_toast_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story_toast_title.add_theme_font_size_override("font_size", 18)
	story_toast_title.add_theme_color_override("font_color", Color("#d7ad70"))
	toast_column.add_child(story_toast_title)
	story_toast_body = Label.new()
	story_toast_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story_toast_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	story_toast_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_toast_body.add_theme_font_size_override("font_size", 15)
	story_toast_body.add_theme_color_override("font_color", Color("#eee6d8"))
	toast_column.add_child(story_toast_body)
	_create_combat_vitals_hud()


func _connect_player_combat_signals() -> void:
	if player == null:
		return
	if player.has_signal("stats_changed"):
		player.connect("stats_changed", Callable(self, "_on_player_stats_changed"))
	if player.has_signal("combat_message"):
		player.connect("combat_message", Callable(self, "_on_combat_message"))
	if player.has_method("notify_stats"):
		player.call_deferred("notify_stats")


func _on_player_stats_changed(current_health: float, max_health_value: float, current_stamina: float, max_stamina_value: float) -> void:
	if health_bar:
		health_bar.max_value = max_health_value
		health_bar.value = current_health
	if stamina_bar:
		stamina_bar.max_value = max_stamina_value
		stamina_bar.value = current_stamina
	if health_value_label:
		health_value_label.text = "%d / %d" % [roundi(current_health), roundi(max_health_value)]
	if stamina_value_label:
		stamina_value_label.text = "%d / %d" % [roundi(current_stamina), roundi(max_stamina_value)]


func _on_combat_message(message: String, positive: bool) -> void:
	if combat_toast_cooldown > 0.0 or message.is_empty():
		return
	if not (message.contains("ПАРИРУВАННЯ") or message.contains("ПРОБИТО") or message.contains("Недостатньо") or message.contains("впав у бою")):
		return
	combat_toast_cooldown = 1.15
	_show_story_toast("БОЙОВИЙ СТАН", message, 2.0)


func _make_vitals_bar_style(background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color("#756044")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 2.0
	style.content_margin_right = 2.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	return style


func _create_combat_vitals_hud() -> void:
	vitals_panel = PanelContainer.new()
	vitals_panel.name = "KnightVitalsPanel"
	vitals_panel.anchor_left = 0.0
	vitals_panel.anchor_top = 1.0
	vitals_panel.anchor_right = 0.0
	vitals_panel.anchor_bottom = 1.0
	vitals_panel.offset_left = 26.0
	vitals_panel.offset_top = -128.0
	vitals_panel.offset_right = 302.0
	vitals_panel.offset_bottom = -22.0
	vitals_panel.add_theme_stylebox_override("panel", _make_hud_style())
	vitals_panel.visible = false
	hud_root.add_child(vitals_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	vitals_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	margin.add_child(column)

	var health_row := HBoxContainer.new()
	column.add_child(health_row)
	var health_caption := Label.new()
	health_caption.text = "ЗДОРОВ'Я"
	health_caption.custom_minimum_size = Vector2(82.0, 0.0)
	health_caption.add_theme_font_size_override("font_size", 11)
	health_caption.add_theme_color_override("font_color", Color("#e5c7b7"))
	health_row.add_child(health_caption)
	health_value_label = Label.new()
	health_value_label.text = "100 / 100"
	health_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	health_value_label.add_theme_font_size_override("font_size", 11)
	health_value_label.add_theme_color_override("font_color", Color("#f0dfc7"))
	health_row.add_child(health_value_label)

	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(0.0, 13.0)
	health_bar.max_value = 100.0
	health_bar.value = 100.0
	health_bar.show_percentage = false
	health_bar.add_theme_stylebox_override("background", _make_vitals_bar_style(Color("#261c1d")))
	health_bar.add_theme_stylebox_override("fill", _make_vitals_bar_style(Color("#9c3536")))
	column.add_child(health_bar)

	var stamina_row := HBoxContainer.new()
	column.add_child(stamina_row)
	var stamina_caption := Label.new()
	stamina_caption.text = "ВИТРИВАЛІСТЬ"
	stamina_caption.custom_minimum_size = Vector2(82.0, 0.0)
	stamina_caption.add_theme_font_size_override("font_size", 11)
	stamina_caption.add_theme_color_override("font_color", Color("#dbc99a"))
	stamina_row.add_child(stamina_caption)
	stamina_value_label = Label.new()
	stamina_value_label.text = "100 / 100"
	stamina_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stamina_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stamina_value_label.add_theme_font_size_override("font_size", 11)
	stamina_value_label.add_theme_color_override("font_color", Color("#f0dfc7"))
	stamina_row.add_child(stamina_value_label)

	stamina_bar = ProgressBar.new()
	stamina_bar.custom_minimum_size = Vector2(0.0, 13.0)
	stamina_bar.max_value = 100.0
	stamina_bar.value = 100.0
	stamina_bar.show_percentage = false
	stamina_bar.add_theme_stylebox_override("background", _make_vitals_bar_style(Color("#211f18")))
	stamina_bar.add_theme_stylebox_override("fill", _make_vitals_bar_style(Color("#ba934b")))
	column.add_child(stamina_bar)

	var hint := Label.new()
	hint.text = "ЛКМ — удар     Q — щит / парирування"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color("#bfb6a5"))
	column.add_child(hint)

	day_cycle_label = Label.new()
	day_cycle_label.name = "DayNightClock"
	day_cycle_label.anchor_left = 0.40
	day_cycle_label.anchor_top = 0.025
	day_cycle_label.anchor_right = 0.60
	day_cycle_label.anchor_bottom = 0.075
	day_cycle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_cycle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	day_cycle_label.add_theme_font_size_override("font_size", 15)
	day_cycle_label.add_theme_color_override("font_color", Color("#e4d2b3"))
	day_cycle_label.add_theme_constant_override("outline_size", 4)
	day_cycle_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	day_cycle_label.visible = false
	hud_root.add_child(day_cycle_label)


# -----------------------------------------------------------------------------
# PART 3 — QUEST TRACKER AND QUEST JOURNAL
# -----------------------------------------------------------------------------
func _create_quest_ui() -> void:
	if hud_root == null:
		return

	# Компактний трекер під мінікартою.
	quest_tracker_panel = PanelContainer.new()
	quest_tracker_panel.name = "QuestTrackerPanel"
	quest_tracker_panel.anchor_left = 1.0
	quest_tracker_panel.anchor_right = 1.0
	quest_tracker_panel.anchor_top = 0.0
	quest_tracker_panel.anchor_bottom = 0.0
	quest_tracker_panel.offset_left = -326.0
	quest_tracker_panel.offset_top = 258.0
	quest_tracker_panel.offset_right = -22.0
	quest_tracker_panel.offset_bottom = 410.0
	quest_tracker_panel.add_theme_stylebox_override("panel", _make_hud_style())
	quest_tracker_panel.visible = false
	hud_root.add_child(quest_tracker_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 13)
	margin.add_theme_constant_override("margin_right", 13)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 9)
	quest_tracker_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	quest_tracker_title = Label.new()
	quest_tracker_title.text = "АКТИВНЕ ДОРУЧЕННЯ"
	quest_tracker_title.add_theme_font_size_override("font_size", 12)
	quest_tracker_title.add_theme_color_override("font_color", Color("#d3a76b"))
	quest_tracker_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(quest_tracker_title)
	var journal_hint := Label.new()
	journal_hint.text = "J"
	journal_hint.add_theme_font_size_override("font_size", 12)
	journal_hint.add_theme_color_override("font_color", Color("#8f8a80"))
	header.add_child(journal_hint)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0.0, 1.0)
	divider.color = Color(0.62, 0.46, 0.27, 0.68)
	column.add_child(divider)

	quest_tracker_label = Label.new()
	quest_tracker_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_tracker_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	quest_tracker_label.add_theme_font_size_override("font_size", 12)
	quest_tracker_label.add_theme_color_override("font_color", Color("#e5dac7"))
	quest_tracker_label.custom_minimum_size = Vector2(0.0, 76.0)
	column.add_child(quest_tracker_label)

	# Окреме вікно журналу, доступне з гри клавішею J або з меню паузи.
	quest_journal_layer = CanvasLayer.new()
	quest_journal_layer.name = "QuestJournalOverlay"
	quest_journal_layer.layer = 38
	add_child(quest_journal_layer)

	quest_journal_root = Control.new()
	quest_journal_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	quest_journal_root.mouse_filter = Control.MOUSE_FILTER_STOP
	quest_journal_root.visible = false
	quest_journal_layer.add_child(quest_journal_root)

	var shade := ColorRect.new()
	shade.color = Color(0.004, 0.006, 0.009, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	quest_journal_root.add_child(shade)

	var panel := PanelContainer.new()
	panel.name = "QuestJournalPanel"
	panel.anchor_left = 0.10
	panel.anchor_top = 0.09
	panel.anchor_right = 0.90
	panel.anchor_bottom = 0.91
	panel.add_theme_stylebox_override("panel", _make_map_panel_style(true))
	quest_journal_root.add_child(panel)

	var outer := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		outer.add_theme_constant_override(side, 22)
	panel.add_child(outer)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	outer.add_child(content)

	var header_row := HBoxContainer.new()
	content.add_child(header_row)
	var journal_title := Label.new()
	journal_title.text = "ЖУРНАЛ ПОДОРОЖІ"
	journal_title.add_theme_font_size_override("font_size", 27)
	journal_title.add_theme_color_override("font_color", Color("#e2c18c"))
	journal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(journal_title)
	var close_button := _make_oath_button("ЗАКРИТИ  •  ESC", Color("#302720"), Color("#967044"))
	close_button.custom_minimum_size = Vector2(190.0, 40.0)
	close_button.pressed.connect(_close_quest_journal)
	header_row.add_child(close_button)

	var subtitle := Label.new()
	subtitle.text = "Відстежуй доручення, шукай докази та повертайся по нагороду."
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color("#aaa397"))
	content.add_child(subtitle)

	var journal_divider := ColorRect.new()
	journal_divider.custom_minimum_size = Vector2(0.0, 2.0)
	journal_divider.color = Color("#8e6b42")
	content.add_child(journal_divider)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 18)
	content.add_child(columns)

	var list_panel := PanelContainer.new()
	list_panel.custom_minimum_size = Vector2(360.0, 0.0)
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_panel.add_theme_stylebox_override("panel", _make_map_panel_style())
	columns.add_child(list_panel)
	var list_margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		list_margin.add_theme_constant_override(side, 10)
	list_panel.add_child(list_margin)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_margin.add_child(scroll)
	quest_journal_entries = VBoxContainer.new()
	quest_journal_entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quest_journal_entries.add_theme_constant_override("separation", 7)
	scroll.add_child(quest_journal_entries)

	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", _make_map_panel_style())
	columns.add_child(detail_panel)
	var detail_margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		detail_margin.add_theme_constant_override(side, 20)
	detail_panel.add_child(detail_margin)
	quest_journal_detail = Label.new()
	quest_journal_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_journal_detail.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	quest_journal_detail.add_theme_font_size_override("font_size", 16)
	quest_journal_detail.add_theme_color_override("font_color", Color("#ded6c8"))
	detail_margin.add_child(quest_journal_detail)

	var footer := Label.new()
	footer.text = "ПІДКАЗКА: підійди до позначеного персонажа або місця та натисни E."
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", Color("#a69a83"))
	content.add_child(footer)

	_refresh_quest_tracker()
	_refresh_quest_journal()


func _on_quest_log_changed() -> void:
	_refresh_quest_tracker()
	if quest_journal_root and quest_journal_root.visible:
		_refresh_quest_journal()


func _on_quest_progressed(quest_id: String, objective_text: String, progress: int, total: int) -> void:
	var summary: Dictionary = QuestManager.get_quest_summary(quest_id)
	if quest_id == "main_story" and str(summary.get("status", "")) == "active":
		_show_story_toast("ГОЛОВНА ЦІЛЬ", str(summary.get("objective_text", "")), 6.0)
		AudioManager.play_ui("quest_progress")
		_refresh_quest_tracker()
		return
	var title_text := str(summary.get("title", "Доручення"))
	_show_story_toast(title_text.to_upper(), "%s\nКрок %d / %d" % [objective_text, progress, total], 3.8)
	AudioManager.play_ui("quest_progress")
	_refresh_quest_tracker()


func _refresh_quest_tracker() -> void:
	if quest_tracker_label == null:
		return
	var summaries: Array[Dictionary] = QuestManager.get_active_summaries()
	if summaries.is_empty():
		quest_tracker_title.text = "АКТИВНІ ДОРУЧЕННЯ"
		quest_tracker_label.text = "Немає активних завдань."
		return

	var tracked: Dictionary = QuestManager.get_tracked_summary()
	if tracked.is_empty():
		tracked = summaries[0]
	quest_tracker_title.text = str(tracked.get("category", "АКТИВНЕ ДОРУЧЕННЯ")).to_upper()
	var status_text := "ГОТОВО ДО ЗДАЧІ" if str(tracked.get("status", "")) == "ready" else "У ПРОЦЕСІ"
	var progress_text := "КРОК %d / %d" % [int(tracked.get("progress", 0)) + (1 if str(tracked.get("status", "")) == "active" else 0), int(tracked.get("total", 0))]
	quest_tracker_label.text = "%s\n› %s\n%s  •  %d ◈" % [str(tracked.get("title", "")), str(tracked.get("objective_text", "")), progress_text if status_text != "ГОТОВО ДО ЗДАЧІ" else status_text, int(tracked.get("reward", 0))]


func _refresh_quest_journal() -> void:
	if quest_journal_entries == null or quest_journal_detail == null:
		return
	for child in quest_journal_entries.get_children():
		quest_journal_entries.remove_child(child)
		child.queue_free()

	var entries: Array[Dictionary] = QuestManager.get_journal_entries()
	if entries.is_empty():
		quest_journal_detail.text = "Тут поки тихо.\n\nЗнайди мешканців Забутих земель і поговори з ними, щоб отримати перші доручення."
		return

	var first_available_id := ""
	for entry in entries:
		var quest_id := str(entry.get("id", ""))
		if first_available_id.is_empty():
			first_available_id = quest_id
		var status := str(entry.get("status", "available"))
		var status_label := "АКТИВНЕ" if status == "active" else ("ЗДАТИ" if status == "ready" else ("ВИКОНАНО" if status == "completed" else "ДОСТУПНЕ"))
		var row_button := Button.new()
		row_button.text = "%s\n%s" % [str(entry.get("title", "Доручення")), status_label]
		row_button.custom_minimum_size = Vector2(0.0, 58.0)
		row_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row_button.add_theme_font_size_override("font_size", 13)
		row_button.add_theme_color_override("font_color", Color("#e4d9c7"))
		# Головне активне — жовте; другорядні активні — сині; неактивні другорядні — лише синя рамка.
		var is_main := quest_id == "main_story"
		var open_status := status in ["active", "ready"]
		var fill := Color(0.035, 0.042, 0.048, 0.86)
		var border := Color(0.38, 0.30, 0.21, 0.75)
		if is_main and open_status:
			fill = Color(0.46, 0.34, 0.06, 0.95)
			border = Color("#ffd24a")
			row_button.add_theme_color_override("font_color", Color("#fff4cc"))
		elif is_main:
			border = Color("#a88a3a")
		elif open_status:
			fill = Color(0.10, 0.22, 0.42, 0.95)
			border = Color("#6aa8ff")
			row_button.add_theme_color_override("font_color", Color("#dcebff"))
		elif status == "completed":
			border = Color("#3a4a5a")
			row_button.add_theme_color_override("font_color", Color("#8a8f98"))
		else:
			border = Color("#4a7ac8")
		row_button.add_theme_stylebox_override("normal", _make_button_style(fill, border))
		row_button.add_theme_stylebox_override("hover", _make_button_style(fill.lightened(0.1), border.lightened(0.25), true))
		row_button.pressed.connect(_select_journal_quest.bind(quest_id))
		quest_journal_entries.add_child(row_button)

	if not first_available_id.is_empty():
		_select_journal_quest(str(QuestManager.get_tracked_summary().get("id", first_available_id)))


func _atlas_journal_text() -> String:
	## Розділ журналу «Атлас Корони»: скільки шматків знайдено й у кого вони були.
	var owned: Array = QuestManager.get_map_pieces()
	var lines := "АТЛАС КОРОНИ: %d / %d ФРАГМЕНТІВ" % [owned.size(), AtlasPieces.total()]
	for id in AtlasPieces.ORDER:
		var info: Dictionary = AtlasPieces.PIECES[id]
		if id in owned:
			lines += "\n  ■ %s — %s" % [str(info["name"]), str(info["from"])]
		else:
			lines += "\n  □ ??? — шматок ще не знайдено"
	if owned.size() < AtlasPieces.total():
		lines += "\nМонахи Ордену Печатки розірвали карту, щоб ніхто не знайшов дороги до Ока. Шматки тримають хранителі — місце Чорної Гори відкриється, коли карта складеться повністю."
	else:
		lines += "\nКарту складено: шлях до Вівтаря Ока позначено на атласі (M)."
	return lines


func _select_journal_quest(quest_id: String) -> void:
	var summary: Dictionary = QuestManager.get_quest_summary(quest_id)
	if summary.is_empty() or quest_journal_detail == null:
		return
	var status := str(summary.get("status", "available"))
	var status_text := "Активне" if status == "active" else ("Готове до здачі" if status == "ready" else ("Виконано" if status == "completed" else "Ще не прийнято"))
	var progress := int(summary.get("progress", 0))
	var total := int(summary.get("total", 0))
	var detail := "%s\n%s\n\n%s\n\nСТАН: %s\nПРОГРЕС: %d / %d\n\nНАСТУПНИЙ КРОК\n%s\n\nЗАМОВНИК: %s\nНАГОРОДА: %d ◈" % [str(summary.get("title", "")), str(summary.get("category", "Доручення")), str(summary.get("description", "")), status_text, progress, total, str(summary.get("objective_text", "")), str(summary.get("giver_name", "")), int(summary.get("reward", 0))]
	if quest_id == "main_story":
		detail += "\n\n" + _atlas_journal_text()
	quest_journal_detail.text = detail
	if status in ["active", "ready"]:
		QuestManager.set_tracked_quest(quest_id)


func _open_quest_journal(return_screen: String = "game") -> void:
	if quest_journal_root == null:
		return
	quest_journal_return_screen = return_screen
	current_screen = "quest_journal"
	AudioManager.play_ui("journal_open")
	game_started = true
	_set_player_controls(false)
	if menu_root:
		menu_root.visible = false
	if minimap_panel:
		minimap_panel.visible = false
	if quest_tracker_panel:
		quest_tracker_panel.visible = false
	_refresh_quest_journal()
	quest_journal_root.visible = true
	quest_journal_root.modulate.a = 0.0
	var fade := create_tween()
	fade.set_trans(Tween.TRANS_SINE)
	fade.set_ease(Tween.EASE_OUT)
	fade.tween_property(quest_journal_root, "modulate:a", 1.0, 0.2)


func _close_quest_journal() -> void:
	if quest_journal_root:
		quest_journal_root.visible = false
	if quest_journal_return_screen == "pause":
		_show_pause_menu()
	else:
		current_screen = "game"
		game_started = true
		if menu_root:
			menu_root.visible = false
		_set_player_controls(true)
		_update_story_hud()


# -----------------------------------------------------------------------------
# PART 4 — WORLD MAP AND LIVE MINIMAP
# -----------------------------------------------------------------------------
func _create_map_ui() -> void:
	if hud_root == null:
		return

	# Квадратна мінікарта у верхньому правому куті HUD.
	minimap_panel = PanelContainer.new()
	minimap_panel.name = "WorldMinimapPanel"
	minimap_panel.anchor_left = 1.0
	minimap_panel.anchor_right = 1.0
	minimap_panel.anchor_top = 0.0
	minimap_panel.anchor_bottom = 0.0
	minimap_panel.offset_left = -246.0
	minimap_panel.offset_top = 22.0
	minimap_panel.offset_right = -22.0
	minimap_panel.offset_bottom = 246.0
	minimap_panel.add_theme_stylebox_override("panel", _make_map_panel_style())
	minimap_panel.visible = false
	hud_root.add_child(minimap_panel)

	var minimap_margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		minimap_margin.add_theme_constant_override(side, 7)
	minimap_panel.add_child(minimap_margin)

	minimap_view = Control.new()
	minimap_view.name = "WorldMinimapView"
	minimap_view.custom_minimum_size = Vector2(210.0, 210.0)
	minimap_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	minimap_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	minimap_view.set_script(WORLD_MAP_SCRIPT)
	minimap_view.call("setup", world_generator, player, true)
	minimap_margin.add_child(minimap_view)

	# Повноекранна карта. CanvasLayer відділений від HUD, меню та діалогів.
	map_layer = CanvasLayer.new()
	map_layer.name = "WorldMapOverlay"
	map_layer.layer = 18
	map_layer.visible = false
	add_child(map_layer)

	map_root = Control.new()
	map_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_root.mouse_filter = Control.MOUSE_FILTER_STOP
	map_layer.add_child(map_root)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.008, 0.012, 0.015, 0.88)
	map_root.add_child(shade)

	var panel := PanelContainer.new()
	panel.name = "FullWorldMapPanel"
	panel.anchor_left = 0.045
	panel.anchor_top = 0.045
	panel.anchor_right = 0.955
	panel.anchor_bottom = 0.955
	panel.add_theme_stylebox_override("panel", _make_map_panel_style(true))
	map_root.add_child(panel)

	var outer_margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		outer_margin.add_theme_constant_override(side, 18)
	panel.add_child(outer_margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	outer_margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)

	var title := Label.new()
	title.text = "АТЛАС ЗАБУТИХ ЗЕМЕЛЬ"
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color("#e0c18a"))
	header.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "  •  EMBERS OF THE SPIRE"
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color("#8f897c"))
	subtitle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(subtitle)

	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)

	var close_hint := Label.new()
	close_hint.text = "M / ESC  —  ЗАКРИТИ"
	close_hint.add_theme_font_size_override("font_size", 13)
	close_hint.add_theme_color_override("font_color", Color("#c3b49a"))
	close_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(close_hint)

	var separator := HSeparator.new()
	separator.add_theme_color_override("separator", Color(0.54, 0.42, 0.26, 0.65))
	column.add_child(separator)

	fullscreen_map_view = Control.new()
	fullscreen_map_view.name = "FullWorldMapView"
	fullscreen_map_view.custom_minimum_size = Vector2(900.0, 490.0)
	fullscreen_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fullscreen_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fullscreen_map_view.set_script(WORLD_MAP_SCRIPT)
	fullscreen_map_view.call("setup", world_generator, player, false)
	column.add_child(fullscreen_map_view)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 22)
	column.add_child(footer)
	_add_map_legend_item(footer, Color("#f4d69a"), "Ти тут")
	_add_map_legend_item(footer, Color("#d6a44e"), "Будівлі")
	_add_map_legend_item(footer, Color("#80c8c3"), "Персонажі")
	_add_map_legend_item(footer, Color("#f3b44b"), "Завдання князівства")
	_add_map_legend_item(footer, Color("#e85a4b"), "Завдання Гори")


func _add_map_legend_item(parent: HBoxContainer, tint: Color, label_text: String) -> void:
	var item := HBoxContainer.new()
	item.add_theme_constant_override("separation", 5)
	parent.add_child(item)
	var swatch := ColorRect.new()
	swatch.color = tint
	swatch.custom_minimum_size = Vector2(9.0, 9.0)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	item.add_child(swatch)
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color("#bdb5a5"))
	item.add_child(label)


func _make_map_panel_style(fullscreen: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.027, 0.025, 0.96)
	style.border_color = Color(0.47, 0.35, 0.20, 0.94)
	style.set_border_width_all(2 if fullscreen else 1)
	style.set_corner_radius_all(8 if fullscreen else 6)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.52)
	style.shadow_size = 14 if fullscreen else 6
	return style


func _open_world_map() -> void:
	if map_layer == null or current_screen != "game" or not game_started:
		return
	current_screen = "map"
	AudioManager.play_ui("journal_open", -2.0)
	map_layer.visible = true
	_set_player_controls(false)
	if interaction_label:
		interaction_label.visible = false
	if minimap_panel:
		minimap_panel.visible = false
	if fullscreen_map_view:
		fullscreen_map_view.call("queue_redraw")


func _close_world_map() -> void:
	if map_layer:
		map_layer.visible = false
	if current_screen == "map":
		current_screen = "game"
		game_started = true
		_set_player_controls(true)
		if minimap_panel:
			minimap_panel.visible = true
		_update_story_hud()


func _create_story_ui() -> void:
	story_layer = CanvasLayer.new()
	story_layer.name = "Part2StoryUI"
	story_layer.layer = 30
	add_child(story_layer)

	story_root = Control.new()
	story_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	story_root.mouse_filter = Control.MOUSE_FILTER_STOP
	story_root.visible = false
	story_layer.add_child(story_root)

	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	story_root.add_child(shade)

	oath_panel = PanelContainer.new()
	oath_panel.set_anchors_preset(Control.PRESET_CENTER)
	oath_panel.offset_left = -370.0
	oath_panel.offset_top = -235.0
	oath_panel.offset_right = 370.0
	oath_panel.offset_bottom = 235.0
	oath_panel.add_theme_stylebox_override("panel", _make_hud_style())
	story_root.add_child(oath_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	oath_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	oath_title = Label.new()
	oath_title.text = "КАМІНЬ ПРИСЯГИ"
	oath_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	oath_title.add_theme_font_size_override("font_size", 27)
	oath_title.add_theme_color_override("font_color", Color("#e4c18a"))
	column.add_child(oath_title)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0.0, 2.0)
	divider.color = Color("#927044")
	column.add_child(divider)

	oath_body = Label.new()
	oath_body.text = "На камені проступають два знаки. Один обіцяє захист людей і порядок князівства. Другий — силу та знання Чорної Гори, але її Око ніколи не дарує нічого без ціни. Твій вибір визначить, чий поклик поведе тебе далі."
	oath_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	oath_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	oath_body.add_theme_font_size_override("font_size", 16)
	oath_body.add_theme_color_override("font_color", Color("#e9e1d4"))
	column.add_child(oath_body)

	var principality_button := _make_oath_button("ПРИСЯГНУТИ КНЯЗІВСТВУ", Color("#3a3020"), Color("#b58a4a"))
	principality_button.pressed.connect(_choose_oath.bind("principality"))
	column.add_child(principality_button)
	var mountain_button := _make_oath_button("ПРИСЯГНУТИ ЧОРНІЙ ГОРІ", Color("#2c2022"), Color("#a64f3f"))
	mountain_button.pressed.connect(_choose_oath.bind("mountain"))
	column.add_child(mountain_button)
	var later_button := Button.new()
	later_button.text = "НЕ ЗАРАЗ"
	later_button.custom_minimum_size = Vector2(0.0, 36.0)
	later_button.flat = true
	later_button.add_theme_color_override("font_color", Color("#b9b2a7"))
	later_button.pressed.connect(_close_oath_choice)
	column.add_child(later_button)


func _create_world_dialogue_ui() -> void:
	world_dialogue_layer = CanvasLayer.new()
	world_dialogue_layer.name = "Part3WorldDialogue"
	world_dialogue_layer.layer = 35
	add_child(world_dialogue_layer)

	world_dialogue_root = Control.new()
	world_dialogue_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world_dialogue_root.mouse_filter = Control.MOUSE_FILTER_STOP
	world_dialogue_root.visible = false
	world_dialogue_layer.add_child(world_dialogue_root)

	var shade := ColorRect.new()
	# Легке затемнення: за діалогом видно кінематографічний кадр із персонажем.
	shade.color = Color(0.0, 0.0, 0.0, 0.28)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	world_dialogue_root.add_child(shade)

	# Панель праворуч, щоб не закривати NPC у центрі кадру.
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_left = -560.0
	panel.offset_top = -210.0
	panel.offset_right = -36.0
	panel.offset_bottom = 210.0
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.add_theme_stylebox_override("panel", _make_hud_style())
	world_dialogue_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 13)
	margin.add_child(column)

	world_dialogue_title = Label.new()
	world_dialogue_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	world_dialogue_title.add_theme_font_size_override("font_size", 26)
	world_dialogue_title.add_theme_color_override("font_color", Color("#e4c18a"))
	column.add_child(world_dialogue_title)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0.0, 2.0)
	divider.color = Color("#927044")
	column.add_child(divider)

	# Текст у прокрутці: довгі записки (лист удови, послання короля) лишаються всередині вікна.
	world_dialogue_scroll = ScrollContainer.new()
	world_dialogue_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	world_dialogue_scroll.custom_minimum_size = Vector2(464.0, 110.0)
	column.add_child(world_dialogue_scroll)
	world_dialogue_body = Label.new()
	world_dialogue_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	world_dialogue_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	world_dialogue_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	world_dialogue_body.custom_minimum_size = Vector2(448.0, 0.0)
	world_dialogue_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	world_dialogue_body.add_theme_font_size_override("font_size", 16)
	world_dialogue_body.add_theme_color_override("font_color", Color("#e9e1d4"))
	world_dialogue_scroll.add_child(world_dialogue_body)

	world_dialogue_actions = VBoxContainer.new()
	world_dialogue_actions.add_theme_constant_override("separation", 8)
	column.add_child(world_dialogue_actions)


func _show_world_dialogue(title_text: String, body_text: String, options: Array = []) -> void:
	if world_dialogue_root == null:
		return
	current_screen = "dialogue"
	game_started = true
	AudioManager.play_ui("note_read" if title_text.begins_with("ЗАПИСКА") else "dialogue_open")
	_set_player_controls(false)
	world_dialogue_title.text = title_text
	world_dialogue_body.text = body_text
	for child in world_dialogue_actions.get_children():
		world_dialogue_actions.remove_child(child)
		child.queue_free()

	for option in options:
		var button_text := str(option.get("label", "ПРОДОВЖИТИ"))
		var action := str(option.get("action", "close"))
		var button := _make_oath_button(button_text, Color("#342b21"), Color("#9f7b4d"))
		button.custom_minimum_size = Vector2(0.0, 44.0)
		button.pressed.connect(_on_world_dialogue_action.bind(action))
		world_dialogue_actions.add_child(button)

	var close_button := Button.new()
	close_button.text = "ЗАКРИТИ  •  ESC"
	close_button.custom_minimum_size = Vector2(0.0, 34.0)
	close_button.flat = true
	close_button.add_theme_color_override("font_color", Color("#b9b2a7"))
	close_button.pressed.connect(_close_world_dialogue)
	world_dialogue_actions.add_child(close_button)

	world_dialogue_root.visible = true
	world_dialogue_root.modulate.a = 0.0
	var fade := create_tween()
	fade.set_trans(Tween.TRANS_SINE)
	fade.set_ease(Tween.EASE_OUT)
	fade.tween_property(world_dialogue_root, "modulate:a", 1.0, 0.22)
	_fit_dialogue_text(options.size())


func _fit_dialogue_text(option_count: int) -> void:
	## Висота тексту обмежена розміром вікна; решта прокручується коліщатком миші.
	world_dialogue_scroll.custom_minimum_size.y = 110.0
	world_dialogue_scroll.scroll_vertical = 0
	await get_tree().process_frame
	if world_dialogue_scroll == null or not is_instance_valid(world_dialogue_scroll):
		return
	var text_h := world_dialogue_body.get_combined_minimum_size().y
	var max_h := get_viewport().get_visible_rect().size.y - 230.0 - float(option_count) * 52.0 - 40.0
	world_dialogue_scroll.custom_minimum_size.y = clampf(text_h + 6.0, 110.0, maxf(max_h, 120.0))
	world_dialogue_scroll.scroll_vertical = 0


func _close_world_dialogue() -> void:
	if world_dialogue_root and world_dialogue_root.visible:
		AudioManager.play_ui("ui_back")
	if world_dialogue_root:
		world_dialogue_root.visible = false
	current_screen = "game"
	if vitals_panel:
		vitals_panel.visible = true
	if day_cycle_label:
		day_cycle_label.visible = true
	game_started = true
	_set_player_controls(true)
	if cutscene:
		cutscene.call("release_focus")
		if bool(cutscene.call("is_orbiting")):
			_set_player_controls(false)
	_update_story_hud()


func _on_world_dialogue_action(action: String) -> void:
	if action == "close":
		_close_world_dialogue()
		return
	AudioManager.play_ui("quest_accept" if (action.begins_with("accept_")) else "ui_click")

	if action == "accept_faction_quest":
		var accepted_world := bool(world_generator.call("start_faction_quest")) if world_generator else false
		var branch := str(world_generator.call("get_oath_choice")) if world_generator else ""
		var accepted_module := QuestManager.start_faction_quest(branch) if accepted_world else false
		_close_world_dialogue()
		if accepted_world and accepted_module:
			_show_story_toast("НОВЕ ДОРУЧЕННЯ", "Знайди позначену знахідку. Повернися до того, хто доручив тобі цю справу.", 5.5)
			_play_cinematic.call_deferred("quest_start")
		elif accepted_world:
			_show_story_toast("ДОРУЧЕННЯ", "Твою ціль уже зареєстровано в журналі.", 4.0)
		_update_story_hud()
		return

	if action == "complete_faction_quest":
		var completed_world := bool(world_generator.call("complete_faction_quest")) if world_generator else false
		var branch := str(world_generator.call("get_faction_quest_branch")) if world_generator else ""
		var reward := QuestManager.claim_quest(QuestManager.get_faction_quest_id(branch)) if completed_world else -1
		_close_world_dialogue()
		if reward >= 0:
			score += reward
			_update_score()
			_show_story_toast("ДОРУЧЕННЯ ВИКОНАНО", "Ти отримав %d монет і прихильність своєї сторони. Твій шлях триває." % reward, 6.0)
		_update_story_hud()
		return

	if action.begins_with("accept_quest:"):
		var quest_id := action.substr("accept_quest:".length())
		var accepted := QuestManager.accept_quest(quest_id)
		_close_world_dialogue()
		if accepted:
			_show_story_toast("НОВЕ ДОРУЧЕННЯ", "Завдання додано до журналу. Натисни J, щоб переглянути наступну ціль.", 5.0)
			if quest_id == "dead_beacon":
				QuestManager.set_tracked_quest(quest_id)
				_show_story_toast("МІСІЯ: ЗГАСЛИЙ МАЯК", "Мітка місії показана на карті й мінікарті. Головний сюжет можна відстежувати в журналі (J).", 6.0)
		_update_story_hud()
		return

	if action.begins_with("turn_in_quest:"):
		var quest_id := action.substr("turn_in_quest:".length())
		var reward := QuestManager.claim_quest(quest_id)
		_close_world_dialogue()
		if reward >= 0:
			score += reward
			_update_score()
			var reward_text := "Ти отримав %d монет." % reward
			if quest_id == "dead_beacon":
				extras.consumables["potion"] = int(extras.consumables["potion"]) + 3
				if player:
					player.set_meta("arrows", int(player.get_meta("arrows", 0)) + 15)
				reward_text += "\n+3 зілля лікування, +15 стріл."
			var data: QuestData = QuestManager.get_data(quest_id)
			if data:
				for item_reward in data.rewards:
					if not item_reward.item_id.is_empty():
						reward_text += "\nПредмет: %s." % item_reward.item_name
			_show_story_toast("ДОРУЧЕННЯ ВИКОНАНО", reward_text + "\nЗапис у журналі оновлено.", 5.5)
		_update_story_hud()
		return

	if action.begins_with("open_shop:"):
		# Діалог ховаємо, але камеру на NPC лишаємо до виходу з магазину.
		world_dialogue_root.visible = false
		extras.open_shop(action.substr("open_shop:".length()))
		return

	if action.begins_with("trial:"):
		_close_world_dialogue()
		world_generator.trials.on_action(action)
		return

	if action.begins_with("stable:"):
		_close_world_dialogue()
		world_generator.horses.on_action(action)
		return

	if action.begins_with("surprise:"):
		_close_world_dialogue()
		world_generator.surprises.on_action(action)
		return

	if action.begins_with("event:"):
		_close_world_dialogue()
		world_generator.events.on_action(action)
		return

	if action == "play_cards":
		world_dialogue_root.visible = false
		extras.cards.open()
		return

	if action == "temper_weapon":
		if player:
			player.set_meta("sword_level", maxi(int(player.get_meta("sword_level", 0)), 1))
			_apply_weapon_tempering()
		_close_world_dialogue()
		_show_story_toast("КЛИНОК ЗАГАРТОВАНО", "Каталан укріпив сталь і наніс на клинок руну. Шкода меча зросла (+9). Далі — апгрейди в кузні за монети.", 5.5)
		return

	if action == "mage_ward":
		if player:
			player.set_meta("mage_ward", true)
		_close_world_dialogue()
		_show_story_toast("ЗНАК МАГА", "Вальмер залишив на тобі захисну руну. Вона зберігатиме силу до наступних випробувань.", 5.5)
		return

	if action == "priest_blessing":
		if player:
			player.set_meta("priest_blessing", true)
		_close_world_dialogue()
		_show_story_toast("ТИХА МОЛИТВА", "Сестра Аліна благословила твій шлях. У затонулій церкві на мить стало тихіше.", 5.5)
		return

	if action == "hunter_supplies":
		if player and not bool(player.get_meta("hunter_supplies_claimed", false)):
			player.set_meta("hunter_supplies_claimed", true)
			for i in range(3):
				add_coin()
		_close_world_dialogue()
		_show_story_toast("ДОПОМОГА МИСЛИВЦЯ", "Рун поділився припасами. Ти отримав 3 монети.", 4.5)
		return

	if action == "druid_mark":
		if player:
			player.set_meta("druid_mark", true)
		_close_world_dialogue()
		_show_story_toast("ЗНАК ЛІСУ", "Старий друїд торкнувся твого чола листком чорного дуба. Лісові духи тепер знають твоє ім'я.", 5.5)
		return

	_close_world_dialogue()


# -----------------------------------------------------------------------------
# ЕТАП 4 — предмети, записки, замовники з QuestData, підписи та сповіщення
# -----------------------------------------------------------------------------
func _open_interactable(interaction_id: String) -> bool:
	if world_generator == null:
		return false
	var interactable = world_generator.call("get_interactable", interaction_id)
	if interactable == null:
		return false
	match int(interactable.kind):
		Interactable.Kind.ITEM:
			QuestManager.add_item(interactable.item_id, interactable.item_name)
			interactable.consume()
		Interactable.Kind.NOTE:
			_show_world_dialogue("ЗАПИСКА  •  " + str(interactable.note_title), str(interactable.note_text))
		_:
			_show_world_dialogue(str(interactable.display_name).to_upper(), str(interactable.note_text))
	return true


func _open_quest_giver_dialogue(giver_id: String, header: String, fallback: String, extra_options: Array = []) -> void:
	## Діалог замовника, повністю керований ресурсом QuestData (+ додаткові кнопки, напр. торгівля).
	var data: QuestData = QuestManager.get_dialogue_quest(giver_id)
	if data == null:
		_show_world_dialogue(header, fallback, extra_options)
		return
	var options: Array = []
	var body := ""
	match QuestManager.get_quest_state(data.id):
		"available":
			body = data.dialogue_offer
			options.append({"label": data.accept_label, "action": "accept_quest:" + data.id})
		"active":
			var summary := QuestManager.get_quest_summary(data.id)
			body = "%s\n\nНАСТУПНИЙ КРОК: %s" % [data.dialogue_active, str(summary.get("objective_text", ""))]
		"ready":
			body = data.dialogue_ready
			options.append({"label": data.turn_in_label, "action": "turn_in_quest:" + data.id})
		_:
			body = data.dialogue_done if not data.dialogue_done.is_empty() else fallback
	options.append_array(extra_options)
	_show_world_dialogue(header, body, options)

func _create_nameplates() -> void:
	nameplate_layer = CanvasLayer.new()
	nameplate_layer.name = "Nameplates"
	nameplate_layer.layer = 3
	add_child(nameplate_layer)
	var view := Control.new()
	view.set_script(NAMEPLATES_SCRIPT)
	nameplate_layer.add_child(view)


func _on_quest_unlocked(quest_id: String) -> void:
	var data: QuestData = QuestManager.get_data(quest_id)
	if data:
		_show_story_toast("НОВЕ ДОРУЧЕННЯ ДОСТУПНЕ", "«%s» — поговори з %s." % [data.title, data.giver_name], 5.0)


func _on_quest_claimed_sound(quest_id: String, _reward: int) -> void:
	AudioManager.play_ui("quest_complete")
	if quest_id == "main_story":
		score += _reward
		_update_score()
		_play_ending.call_deferred()
		return
	# Фінал квесту: повільний обліт замовника (будь-яка клавіша — пропустити).
	if cutscene:
		cutscene.call("finale_orbit", 3.6)


func _on_map_piece_added(piece_id: String, count: int, total: int) -> void:
	## Новий шматок Атласу Корони. Останній («Чорна Гора») показує окрема сцена складання.
	if piece_id == AtlasPieces.FINAL:
		return
	var info: Dictionary = AtlasPieces.PIECES.get(piece_id, {})
	AudioManager.play_ui("discover", -3.0)
	_show_story_toast("ШМАТОК АТЛАСУ  %d / %d" % [count, total],
		"%s — %s\n%s\nВідкрий карту (M): шматок ляже на своє місце." % [str(info.get("name", "")), str(info.get("from", "")), str(info.get("lore", ""))], 7.0)


func _on_item_added(_item_id: String, item_name: String, _total: int) -> void:
	AudioManager.play_ui("item_pickup")
	_show_story_toast("ЗНАЙДЕНО", item_name, 3.5)


func _on_location_discovered(location_id: String, display_name: String) -> void:
	if location_id == "loc_royal_castle":
		_play_cinematic.call_deferred("castle")
	elif location_id == "mountain_foot":
		_play_cinematic.call_deferred("mountain")
	AudioManager.play_ui("discover")
	_show_story_toast("ВІДКРИТО МІСЦЕ", display_name.to_upper(), 3.5)


func _apply_weapon_tempering() -> void:
	if player == null:
		return
	var blade := player.find_child("Blade", true, false) as MeshInstance3D
	if blade == null:
		return
	blade.material_override = PSXMaterials.make(Color("#d5c6a5"), 0.98, 0.16, Color("#a86c31"), 0.22, "metal", false)


func _open_faction_quest_dialogue(giver: String) -> void:
	if world_generator == null:
		return
	var oath: String = str(world_generator.call("get_oath_choice"))
	var branch: String = "mountain" if giver == "mountain" else "principality"
	if oath != branch:
		if branch == "principality":
			_show_world_dialogue("ЕДРИК — КАСТЕЛЯН", "Твоя присяга не князівству. Я не можу доручити тобі справу корони. Шукай відповіді серед тих, кому ти присягнув.")
		else:
			_show_world_dialogue("ВАРК — ПОСЛУШНИК", "Ти не носиш знаку Чорної Гори. Не торкайся її таємниць без дозволу.")
		return

	var quest_id := QuestManager.prepare_faction_quest(branch)
	var state := QuestManager.get_quest_state(quest_id)
	var giver_name := "КАСТЕЛЯН ЕДРИК" if branch == "principality" else "ПОСЛУШНИК ВАРК"
	var target_name := "Печатку Зорі в Зруйнованій Обсерваторії" if branch == "principality" else "Відлуння Ока біля Фортеці Чорного Прапора"

	if state == "available":
		var body := "Край потребує людей, які не тікають від темряви. Вирушай до %s, знайди доказ того, що Чорна Гора знову впливає на ці землі, і повернися. За це отримаєш 12 монет." % target_name
		_show_world_dialogue(giver_name, body, [{"label": "ПРИЙНЯТИ ДОРУЧЕННЯ", "action": "accept_faction_quest"}])
	elif state == "active":
		var summary: Dictionary = QuestManager.get_quest_summary(quest_id)
		_show_world_dialogue(giver_name, "Я чекаю на тебе.\n\nНАСТУПНИЙ КРОК: %s" % str(summary.get("objective_text", "Продовжуй пошуки.")))
	elif state == "ready":
		_show_world_dialogue(giver_name, "Ти повернувся з доказом. Покажи знахідку — і я виконаю свою частину угоди.", [{"label": "ПЕРЕДАТИ ЗНАХІДКУ Й ОТРИМАТИ 12 МОНЕТ", "action": "complete_faction_quest"}])
	else:
		_show_world_dialogue(giver_name, "Ти виконав своє доручення. Твоя відвага не залишилася непоміченою.")

func _try_mission_dialogue(interaction_id: String, step_before: int) -> bool:
	## Ключові розмови місії «Згаслий Маяк»: показуються, коли розмова просунула місію на крок.
	if QuestManager.get_quest_state("dead_beacon") != "active":
		return false
	if QuestManager.get_step("dead_beacon") != step_before + 1:
		return false
	match [step_before, interaction_id]:
		[0, "npc_archer"]:
			_show_world_dialogue("ЛІРА — ЧАРОДІЙКА-ЛУЧНИЦЯ", "Ратмир не обіцяв тобі легкої дороги? Правильно. Лінза маяка тріснула зсередини, наче її розбив той, хто знав, де вдарити. Для нової потрібен Місячний камінь — один є у Склепі Забутих Королів, на південному сході.\n\nЗаверни спершу до Зольного Броду й розпитай Олю: вона бачила, хто ходив південним трактом. І вдягни що-небудь міцніше, ніж дорожній плащ.", [{"label": "ТОРГІВЛЯ: ЛУКИ ТА СТРІЛИ", "action": "open_shop:archer"}])
			return true
		[1, "npc_herder"]:
			_show_world_dialogue("ОЛЯ — ПАСТУШКА", "Вони йшли вночі, мовчки, без ліхтарів — і двоє тягли за собою щось завбільшки з людину. Тракт на південь від нас вони обсіли: там зараз засідка, я бачила з пагорба.\n\nЗнищ їх — і дорога до Склепу вільна. А коли повертатимешся — зазирни до Брода, мені буде спокійніше.")
			return true
		[8, "npc_miner"]:
			extras.consumables["ward"] = int(extras.consumables["ward"]) + 1
			_show_world_dialogue("ГРІМ — БРИГАДИР КОПАЛЕНЬ", "Ото воно, королівське каміння… Холодне, як ранок після бою. Сіль із наших штолень забирає з нього прокляття — потримай на сонці, і буде світитися.\n\nВізьми сувій Оберега про запас: за Бродом чути дим. Здається, вартові пішли в обхід — і наскочили на пастухів.")
			return true
		[10, "npc_archer"]:
			if player:
				player.set_meta("arrows", int(player.get_meta("arrows", 0)) + (15 if int(player.get_meta("bow_level", 0)) >= 1 else 0))
			_show_world_dialogue("ЛІРА — ЧАРОДІЙКА-ЛУЧНИЦЯ", "Камінь чистий. Дивись, як у ньому ховається місяць… Я вставляю його в лінзу — готово. Тепер лишилося найважче: підняти лінзу на маяк у Вартовій Фортеці й запалити.\n\nЯкщо в тебе є лук — це твої стріли, 15 штук. Вартовий Маяка не підпускає до чаші нікого: стріляй здалеку, поки він іде.", [{"label": "ТОРГІВЛЯ: ЛУКИ ТА СТРІЛИ", "action": "open_shop:archer"}])
			return true
	return false


func _try_story_dialogue(interaction_id: String, step_before: int) -> bool:
	## Ключові розмови головного сюжету (кроки 0, 1, 4, 7): показуються рівно тоді, коли розмова просунула квест.
	if QuestManager.get_quest_state("main_story") != "active" and QuestManager.get_quest_state("main_story") != "completed":
		return false
	if QuestManager.get_step("main_story") != step_before + 1:
		return false
	match [step_before, interaction_id]:
		[0, "npc_elder"]:
			_show_world_dialogue("МИРОН — СТАРОСТА", "Ти вийшов із Казематів живим — отже, Око ще не вибрало тебе. Придивись: вогні вздовж доріг гаснуть один за одним. Орест щоночі запалює їх знову, але вони гаснуть щоразу швидше.\n\nСходи до нього — він бачив більше за мене. А потім шукай уламки Стародавньої Печатки: колись її розбили на три частини, щоб Око не прокинулося. За кожного переможеного ворога ти отримаєш монети, а Каталан і Вальмер допоможуть тобі в дорозі.\n\nМета записана в журналі (J). Мітка на карті покаже дорогу.")
			return true
		[1, "npc_lamplighter"]:
			_show_world_dialogue("ОРЕСТ — ЛІХТАРНИК", "Масло цілісіньке, ґноти сухі — а вогонь мертвий. Так гасне лише те, що живилося не олією.\n\nУсе починається на Забутому кладовищі, на схід звідси: там щоночі повертається Лицар Попелу, і вогні гаснуть у його тіні. Піди й подивись сам. Стережися: він носить перший уламок Печатки.")
			return true
		[4, "npc_blacksmith"]:
			_show_world_dialogue("КАТАЛАН — КОВАЛЬ", "Це шматок Печатки. Пізнаю метал: його кували ще за короля Едмара. Дай-но твій меч — загартую його, безкоштовно, бо ти йдеш там, куди не ходить ніхто.\n\nДругий уламок носить Некромант у Руїнах Абатства, на захід від Села Попелу. Повертайся живим — і заходь по апгрейди, коли назбираєш монет.", [{"label": "ЗАГАРТУВАТИ МЕЧ", "action": "temper_weapon"}, {"label": "ТОРГІВЛЯ: КУЗНЯ", "action": "open_shop:blacksmith"}])
			return true
		[7, "npc_mage"]:
			extras.consumables["potion"] = int(extras.consumables["potion"]) + 2
			extras.consumables["ward"] = int(extras.consumables["ward"]) + 1
			_show_world_dialogue("ВАЛЬМЕР — АЛХІМІК", "Два уламки вже в тебе… Вони дзвенять, чуєш? Третій у Попелястій цитаделі, на сході. Його стереже Вартовий — ні живий, ні мертвий. Візьми це на дорогу: два зілля лікування й сувій Оберега.\n\n(Клавіші 1 / 2 / 3 — використати зілля, сувій вогню, оберіг.)\n\nКоли будеш готовий — на вершину Чорної Гори веде серпантин. Там три уламки зростуться на Вівтарі Ока.", [{"label": "ТОРГІВЛЯ: ЗІЛЛЯ ТА СУВОЇ", "action": "open_shop:mage"}])
			return true
	return false


func _open_world_interaction(interaction_id: String) -> void:
	var story_step_before := QuestManager.get_step("main_story")
	var mission_step_before := QuestManager.get_step("dead_beacon")
	# Усі взаємодії, крім сюжетного артефакту, спочатку проходять через QuestManager.
	# Це дозволяє одночасно просувати кілька незалежних доручень.
	AudioManager.play_ui("interact", -4.0)
	if interaction_id != "quest_target":
		QuestManager.record_interaction(interaction_id)
	if _open_interactable(interaction_id):
		return
	if cutscene and interaction_id in CINEMATIC_NPCS and world_generator:
		cutscene.call("focus_npc", world_generator.get_node_or_null(NodePath(interaction_id)) as Node3D)
	if _try_story_dialogue(interaction_id, story_step_before):
		return
	if _try_mission_dialogue(interaction_id, mission_step_before):
		return
	if world_generator and world_generator.eye_finale and world_generator.eye_finale.handle_interaction(interaction_id):
		return
	if world_generator and world_generator.horses and world_generator.horses.handle_interaction(interaction_id):
		return
	if world_generator and world_generator.trials and world_generator.trials.handle_interaction(interaction_id):
		return
	if world_generator and world_generator.surprises and world_generator.surprises.handle_interaction(interaction_id):
		return
	if world_generator and world_generator.events and world_generator.events.handle_interaction(interaction_id):
		return
	if world_generator and world_generator.life and world_generator.life.handle_interaction(interaction_id):
		return
	match interaction_id:
		"npc_lamplighter":
			_open_quest_giver_dialogue("npc_lamplighter", "ОРЕСТ — ЛІХТАРНИК", "Вогні горять, поки є кому їх запалювати.")
		"npc_castellan":
			_open_faction_quest_dialogue("principality")
		"npc_acolyte":
			_open_faction_quest_dialogue("mountain")
		"quest_target":
			var inspected := bool(world_generator.call("inspect_faction_quest_target")) if world_generator else false
			if inspected:
				QuestManager.record_interaction("quest_target")
				var branch: String = str(world_generator.call("get_faction_quest_branch"))
				if branch == "principality":
					_show_world_dialogue("ПЕЧАТКА ЗОРІ", "Серед уламків обсерваторії ти знаходиш золоту печатку. На ній викарбувано королівський герб, але крізь метал проступає той самий знак Ока.")
				else:
					_show_world_dialogue("ВІДЛУННЯ ОКА", "У руїнах ворушиться червоне світло. Воно стискається у чорний уламок, що шепоче твоє ім'я. Відлуння Чорної Гори тепер у твоїх руках.")
				_update_story_hud()
			else:
				_show_world_dialogue("ЗНАЙДІВКА", "Тут більше немає нічого, що можна забрати.")
		"npc_blacksmith":
			_show_world_dialogue("КАТАЛАН — КОВАЛЬ", "Підійди ближче до горна. Сталь пам'ятає кожен удар: я можу загартувати меч, укріпити броню чи викувати нагрудник — усе за монети, що ти забираєш у попелястих вартових.", [{"label": "ТОРГІВЛЯ: КУЗНЯ", "action": "open_shop:blacksmith"}])
		"npc_mage":
			var mage_options: Array = [{"label": "ТОРГІВЛЯ: ЗІЛЛЯ ТА СУВОЇ", "action": "open_shop:mage"}, {"label": "ЗІГРАТИ В КАРТИ  (Попелясте 21)", "action": "play_cards"}]
			if player and not bool(player.get_meta("mage_ward", false)):
				mage_options.append({"label": "ПРИЙНЯТИ ОБЕРІГ", "action": "mage_ward"})
			_show_world_dialogue("МАГІСТР ВАЛЬМЕР — АЛХІМІК", "Око дивиться навіть крізь камінь. Я варю зілля лікування й пишу сувої: Вогню та Оберега. Купуй, але не покладайся на них замість власної голови.", mage_options)
		"npc_merchant":
			_open_quest_giver_dialogue("npc_merchant", "БРУНО — ТОРГОВЕЦЬ", "Заходь, подивися. Усе, що пережило дорогу.", [{"label": "ТОРГІВЛЯ: ТОВАРИ БРУНО", "action": "open_shop:merchant"}])
		"npc_border":
			_open_quest_giver_dialogue("npc_border", "РАТМИР — КОМАНДИР ЗАСТАВИ", str((FRONTIER_TALK["npc_border"] as Array)[1]))
		"npc_archer":
			var archer_options: Array = [{"label": "ТОРГІВЛЯ: ЛУКИ ТА СТРІЛИ", "action": "open_shop:archer"}]
			var has_bow_now: bool = player != null and int(player.get_meta("bow_level", 0)) >= 1
			var archer_text := "Мисливці зі сходу носять мої луки до самої Цитаделі. Місячне дерево не гниє, тятива з жили дракона не рветься. Купуй — і дістань лук клавішею B."
			if has_bow_now:
				archer_text = "Лук у тебе вже є. Тримай стріли про запас, а тятиву я можу підсилити. Не цілься у вартових зблизька — вони швидші, ніж виглядають."
			_show_world_dialogue("ЛІРА — ЧАРОДІЙКА-ЛУЧНИЦЯ", archer_text, archer_options)
		"npc_captain":
			_open_quest_giver_dialogue("npc_captain", "КАПІТАН ГЕДВІГ", "Цитадель тримається, поки ми не втомилися. Не лізь на стіни без дозволу.")
		"npc_marta":
			_open_quest_giver_dialogue("npc_marta", "МАРТА — ВДОВА", "Якщо побачиш у дорозі вартового з синім плащем — не питай, чий він. Просто скажи, що я ще чекаю.")
		"npc_farmer":
			_open_quest_giver_dialogue("npc_farmer", "ЙОГАН — ФЕРМЕР", "Земля тут рідна, але попіл з неї вже не змити.")
		"bonfire":
			if player:
				player.call("heal", 200.0)
			_show_story_toast("ВОГНИЩЕ", "Тепло повертає сили. Тут ти відродишся, якщо Око візьме своє.", 4.5)
		"npc_priest":
			if player and bool(player.get_meta("priest_blessing", false)):
				_show_world_dialogue("СЕСТРА АЛІНА", "Я вже помолилася за тебе. Нехай ця тиша залишиться з тобою, коли знову заговорить Око.")
			else:
				_show_world_dialogue("СЕСТРА АЛІНА", "Колись ця церква була повна голосів. Тепер тут лишилася вода та пам'ять. Схили голову — і я благословлю твою дорогу.", [{"label": "ПРИЙНЯТИ БЛАГОСЛОВЕННЯ", "action": "priest_blessing"}])
		"npc_hunter":
			if player and bool(player.get_meta("hunter_supplies_claimed", false)):
				_open_quest_giver_dialogue("npc_hunter", "РУН — СЛІДОПИТ", "Я вже поділився припасами. Бережи їх — дорога до цитаделі довга.")
			else:
				_open_quest_giver_dialogue("npc_hunter", "РУН — СЛІДОПИТ", "Не йди прямою дорогою після заходу сонця. Дерева біля кладовища шелестять навіть тоді, коли вітру немає. Візьми трохи припасів.", [{"label": "ВЗЯТИ 3 МОНЕТИ-ПРИПАСИ", "action": "hunter_supplies"}])
		"npc_druid":
			if player and bool(player.get_meta("druid_mark", false)):
				_open_quest_giver_dialogue("npc_druid", "ВЕЛЕС — ДРУЇД", "Ліс уже впізнає твій крок. Не ламай старих гілок без потреби.")
			else:
				_open_quest_giver_dialogue("npc_druid", "ВЕЛЕС — ДРУЇД", "Гора не завжди була ворогом. Колись її вершина тримала зорі. Якщо приймеш знак лісу, він нагадає тобі про ціну кожної клятви.", [{"label": "ПРИЙНЯТИ ЗНАК ЛІСУ", "action": "druid_mark"}])
		"npc_scholar":
			var scholar_state := QuestManager.get_quest_state("frozen_signal")
			if scholar_state == "available":
				_show_world_dialogue("РЕНН — ХРАНИТЕЛЬ ОБСЕРВАТОРІЇ", "Тут ми вивчали рух зір. Тепер синій сигнал на Крижаній вежі спалахує щоночі. Перевір його джерело. Я заплачу 8 монет.", [{"label": "ПРИЙНЯТИ: СИГНАЛ ІЗ КРИГИ", "action": "accept_quest:frozen_signal"}])
			elif scholar_state == "ready":
				_show_world_dialogue("РЕНН — ХРАНИТЕЛЬ ОБСЕРВАТОРІЇ", "Ти побачив сигнал зблизька? Розкажи, що знайшов. Ось обіцяна винагорода.", [{"label": "ПЕРЕДАТИ ЗВІТ І ОТРИМАТИ 8 МОНЕТ", "action": "turn_in_quest:frozen_signal"}])
			elif scholar_state == "active":
				var scholar_summary: Dictionary = QuestManager.get_quest_summary("frozen_signal")
				_show_world_dialogue("РЕНН — ХРАНИТЕЛЬ ОБСЕРВАТОРІЇ", "Синій спалах не дає мені спокою.\n\nНАСТУПНИЙ КРОК: %s" % str(scholar_summary.get("objective_text", "Досліди вежу.")))
			else:
				_show_world_dialogue("РЕНН — ХРАНИТЕЛЬ ОБСЕРВАТОРІЇ", "У ніч падіння короля одна зоря зупинилася над Чорною Горою. Відтоді всі зоряні карти брешуть.")
		"npc_elder":
			var elder_state := QuestManager.get_quest_state("village_memory")
			if elder_state == "available":
				_show_world_dialogue("МИРОН — СТАРОСТА", "На Забутому кладовищі з'явилося нове ім'я серед загиблих лицарів. Перевір напис і повернися. За правду я віддячу 6 монетами.", [{"label": "ПРИЙНЯТИ: ІМЕНА ПІД ПОПЕЛОМ", "action": "accept_quest:village_memory"}])
			elif elder_state == "ready":
				_show_world_dialogue("МИРОН — СТАРОСТА", "Ти повернувся. Що було написано на плиті? Ось, візьми обіцяне.", [{"label": "РОЗПОВІСТИ Й ОТРИМАТИ 6 МОНЕТ", "action": "turn_in_quest:village_memory"}])
			elif elder_state == "active":
				var elder_summary: Dictionary = QuestManager.get_quest_summary("village_memory")
				_show_world_dialogue("МИРОН — СТАРОСТА", "Плита чекає на тебе.\n\nНАСТУПНИЙ КРОК: %s" % str(elder_summary.get("objective_text", "Оглянь кладовище.")))
			else:
				_show_world_dialogue("МИРОН — СТАРОСТА", "Ми називаємо це місце Забутим селом, але воно не забуло нічого. Коли король зник, його вершники пройшли цією дорогою на північ — і більше не повернулися.")
		"npc_castle_guard":
			_show_world_dialogue("СЕВРАН — ВАРТОВИЙ", "Далі — володіння Попелястої варти. Не оголюй зброю без причини й не наближайся до брами, коли дзвонить третій дзвін.")
		"building_crypt":
			var crypt_state := QuestManager.get_quest_state("village_memory")
			if crypt_state in ["active", "ready"]:
				_show_world_dialogue("ЗАБУТЕ КЛАДОВИЩЕ", "Ти знаходиш свіжий напис: «Сер Арден не загинув. Його забрали під камінь». Повернися до старости Мирона та розкажи про знахідку.")
			else:
				_show_world_dialogue("ЗАБУТЕ КЛАДОВИЩЕ", "На плитах викарбувано імена лицарів, які загинули до падіння королівства. Останній напис свіжий: «Він прокинувся під каменем».")
		"building_gate":
			_show_world_dialogue("БРАМА ВЕЛЕТНІВ", "На камені видно глибокі подряпини. З іншого боку брами колись щось намагалося пройти крізь неї — і залишило слід завбільшки з людську долоню.")
		"building_citadel":
			_show_world_dialogue("ПОПЕЛЯСТА ЦИТАДЕЛЬ", "За стінами чути дзвони. Королівський прапор давно згорів, але варта досі не зняла присягу. Можливо, саме тут почнеться наступний етап твого шляху.")
		"building_dragon_lair":
			_show_world_dialogue("ЛІГВО ПРАДАВНЬОГО ДРАКОНА", "Повітря пахне сіркою. Камінь під ногами теплий, хоча навколо лежить іній. З глибини долинає низький подих.")
		"building_ice_tower":
			var ice_state := QuestManager.get_quest_state("frozen_signal")
			if ice_state in ["active", "ready"]:
				_show_world_dialogue("КРИЖАНА ВЕЖА", "На верхівці ти знаходиш старий кристалічний передавач. Він не створює сигнал — він відповідає на щось, що світить із-за Чорної Гори. Повернися до Ренна.")
			else:
				_show_world_dialogue("КРИЖАНА ВЕЖА", "Крига всередині вежі не тане навіть біля вогню. На верхівці блимає синє світло — наче хтось відповідає на далекий сигнал.")
		_:
			if FRONTIER_TALK.has(interaction_id):
				var talk: Array = FRONTIER_TALK[interaction_id]
				_open_quest_giver_dialogue(interaction_id, str(talk[0]), str(talk[1]))
			else:
				_show_world_dialogue("ЗЕМЛІ ПОПЕЛУ", "Тут ще залишилися сліди тих, хто жив до падіння королівства.")


func _make_oath_button(label_text: String, background: Color, border: Color) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(0.0, 52.0)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("#f0e4ce"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = background
	normal.border_color = border
	normal.border_width_left = 2
	normal.border_width_top = 1
	normal.border_width_right = 2
	normal.border_width_bottom = 1
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = background.lightened(0.13)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	return button


func _show_story_toast(title_text: String, body_text: String, duration: float = 5.0) -> void:
	if story_toast_panel == null:
		return
	if story_toast_tween and story_toast_tween.is_running():
		story_toast_tween.kill()
	story_toast_title.text = title_text
	story_toast_body.text = body_text
	story_toast_panel.visible = true
	story_toast_panel.size = Vector2.ZERO
	story_toast_panel.reset_size.call_deferred()
	story_toast_panel.modulate.a = 0.0
	story_toast_tween = create_tween()
	story_toast_tween.set_trans(Tween.TRANS_SINE)
	story_toast_tween.set_ease(Tween.EASE_OUT)
	story_toast_tween.tween_property(story_toast_panel, "modulate:a", 1.0, 0.32)
	story_toast_tween.tween_interval(duration)
	story_toast_tween.set_ease(Tween.EASE_IN)
	story_toast_tween.tween_property(story_toast_panel, "modulate:a", 0.0, 0.55)
	story_toast_tween.tween_callback(func(): story_toast_panel.visible = false)


func _update_story_hud() -> void:
	if world_generator and objective_label:
		objective_label.text = str(world_generator.call("get_current_objective"))
		objective_label.visible = game_started
	_refresh_quest_tracker()


func _handle_story_interaction() -> void:
	if world_generator == null:
		return
	var interaction: String = str(world_generator.call("get_nearby_interaction"))
	if interaction == "oath":
		_show_oath_choice()
	elif interaction == "exit":
		world_generator.call("leave_dungeon")
	elif interaction == "exit_locked":
		_show_story_toast("ВИХІД ЗАМКНЕНО", "Спершу знайди Камінь Присяги та обери, кому служитимеш.", 4.0)
	elif interaction != "":
		_open_world_interaction(interaction)


func _show_oath_choice() -> void:
	current_screen = "oath_choice"
	_set_player_controls(false)
	story_root.visible = true
	story_root.modulate.a = 0.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(story_root, "modulate:a", 1.0, 0.25)


func _choose_oath(choice: String) -> void:
	if world_generator == null:
		return
	world_generator.call("commit_oath", choice)
	story_root.visible = false
	current_screen = "game"
	game_started = true
	_set_player_controls(true)
	_update_story_hud()
	if choice == "principality":
		_show_story_toast("ПРИСЯГА КНЯЗІВСТВУ", "«Клянусь берегти останній вогонь корони й захищати тих, хто не може захистити себе». На камені спалахнула золота печать.", 6.0)
	else:
		_show_story_toast("ПРИСЯГА ЧОРНІЙ ГОРІ", "«Клянусь слухати камінь, дивитися в Око й прийняти ціну знання». Червоний знак відповів глухим гулом.", 6.0)


func _close_oath_choice() -> void:
	if story_root:
		story_root.visible = false
	current_screen = "game"
	game_started = true
	_set_player_controls(true)


func _on_dungeon_exited(choice: String) -> void:
	current_screen = "game"
	game_started = true
	_set_player_controls(true)
	# Старт головного сюжету.
	if QuestManager.get_quest_state("main_story") == "available":
		QuestManager.accept_quest("main_story")
		QuestManager.set_tracked_quest("main_story")
	_update_story_hud()
	if choice == "principality":
		_show_story_toast("ПОВЕРНЕННЯ НА ПОВЕРХНЮ", "Над тобою — землі князівства. Далеко на сході здіймається Попеляста Цитадель. Твоя присяга вже має свідків.", 7.0)
	else:
		_show_story_toast("ПОГЛЯД ЧОРНОЇ ГОРИ", "Ти знову бачиш небо. На північному заході височіє Чорна Гора, а її Око ледь помітно пульсує у далечині.", 7.0)


# -----------------------------------------------------------------------------
# Компактний напівпрозорий HUD (не затуляє огляд)
# -----------------------------------------------------------------------------
func _make_compact_style(alpha: float = 0.42) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.022, 0.03, alpha)
	style.border_color = Color(0.62, 0.48, 0.28, 0.32)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	return style


func _set_margins(container: MarginContainer, horizontal: int, vertical: int) -> void:
	container.add_theme_constant_override("margin_left", horizontal)
	container.add_theme_constant_override("margin_right", horizontal)
	container.add_theme_constant_override("margin_top", vertical)
	container.add_theme_constant_override("margin_bottom", vertical)


func _compact_hud() -> void:
	# Монети — маленька плашка зліва вгорі.
	# Монети й головна ціль — в одному вертикальному стеку: панелі не накладаються за жодного розміру вікна.
	var hud_stack := VBoxContainer.new()
	hud_stack.name = "TopLeftStack"
	hud_stack.position = Vector2(14.0, 12.0)
	hud_stack.add_theme_constant_override("separation", 8)
	hud_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(hud_stack)
	hud_panel.get_parent().remove_child(hud_panel)
	hud_stack.add_child(hud_panel)
	hud_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hud_panel.custom_minimum_size = Vector2.ZERO
	hud_panel.add_theme_stylebox_override("panel", _make_compact_style(0.38))
	_set_margins(hud_panel.get_child(0) as MarginContainer, 8, 2)
	score_label.add_theme_font_size_override("font_size", 13)
	# Головна ціль — власна плашка з автопереносом, росте разом із текстом.
	var goal_panel := PanelContainer.new()
	goal_panel.name = "GoalPanel"
	goal_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	goal_panel.add_theme_stylebox_override("panel", _make_compact_style(0.38))
	goal_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var goal_margin := MarginContainer.new()
	_set_margins(goal_margin, 10, 5)
	goal_panel.add_child(goal_margin)
	objective_label.get_parent().remove_child(objective_label)
	objective_label.position = Vector2.ZERO
	objective_label.custom_minimum_size = Vector2(300.0, 0.0)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.add_theme_font_size_override("font_size", 12)
	goal_margin.add_child(objective_label)
	hud_stack.add_child(goal_panel)
	goal_panel.visible = objective_label.visible
	objective_label.visibility_changed.connect(func() -> void:
		goal_panel.visible = objective_label.visible
	)

	# Підказка взаємодії — під прицілом.
	interaction_label.anchor_left = 0.3
	interaction_label.anchor_right = 0.7
	interaction_label.anchor_top = 0.57
	interaction_label.anchor_bottom = 0.62
	interaction_label.add_theme_font_size_override("font_size", 15)

	# Сповіщення — невелика смуга вгорі по центру (як у Skyrim / Dark Souls).
	story_toast_panel.anchor_left = 0.5
	story_toast_panel.anchor_right = 0.5
	story_toast_panel.anchor_top = 0.0
	story_toast_panel.anchor_bottom = 0.0
	story_toast_panel.offset_left = -220.0
	story_toast_panel.offset_right = 220.0
	story_toast_panel.offset_top = 44.0
	story_toast_panel.offset_bottom = 54.0
	story_toast_panel.grow_vertical = Control.GROW_DIRECTION_END
	story_toast_panel.custom_minimum_size = Vector2(440.0, 0.0)
	story_toast_panel.add_theme_stylebox_override("panel", _make_compact_style(0.5))
	_set_margins(story_toast_panel.get_child(0) as MarginContainer, 14, 5)
	(story_toast_title.get_parent() as VBoxContainer).add_theme_constant_override("separation", 1)
	story_toast_title.add_theme_font_size_override("font_size", 13)
	story_toast_body.add_theme_font_size_override("font_size", 12)
	story_toast_body.custom_minimum_size = Vector2(410.0, 0.0)
	story_toast_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	# Здоров'я / витривалість — тонкі смуги зліва внизу.
	vitals_panel.offset_left = 14.0
	vitals_panel.offset_right = 196.0
	vitals_panel.offset_top = -58.0
	vitals_panel.offset_bottom = -12.0
	vitals_panel.add_theme_stylebox_override("panel", _make_compact_style(0.32))
	_set_margins(vitals_panel.get_child(0) as MarginContainer, 8, 4)
	var vitals_column := health_bar.get_parent() as VBoxContainer
	vitals_column.add_theme_constant_override("separation", 1)
	for row in [health_value_label.get_parent(), stamina_value_label.get_parent()]:
		for label in row.get_children():
			(label as Label).add_theme_font_size_override("font_size", 9)
	for bar in [health_bar, stamina_bar]:
		bar.custom_minimum_size = Vector2(0.0, 6.0)
	vitals_column.get_child(vitals_column.get_child_count() - 1).visible = false
	day_cycle_label.anchor_top = 0.008
	day_cycle_label.anchor_bottom = 0.045
	day_cycle_label.add_theme_font_size_override("font_size", 11)

	# Мінікарта — менша й прозоріша.
	minimap_panel.offset_left = -150.0
	minimap_panel.offset_right = -12.0
	minimap_panel.offset_top = 12.0
	minimap_panel.offset_bottom = 150.0
	minimap_panel.add_theme_stylebox_override("panel", _make_compact_style(0.35))
	_set_margins(minimap_panel.get_child(0) as MarginContainer, 3, 3)
	minimap_view.custom_minimum_size = Vector2(130.0, 130.0)
	minimap_view.modulate.a = 0.85

	# Трекер завдань — вузька картка під мінікартою.
	quest_tracker_panel.offset_left = -236.0
	quest_tracker_panel.offset_right = -12.0
	quest_tracker_panel.offset_top = 158.0
	quest_tracker_panel.offset_bottom = 168.0
	quest_tracker_panel.add_theme_stylebox_override("panel", _make_compact_style(0.34))
	_set_margins(quest_tracker_panel.get_child(0) as MarginContainer, 8, 5)
	(quest_tracker_label.get_parent() as VBoxContainer).add_theme_constant_override("separation", 2)
	quest_tracker_title.add_theme_font_size_override("font_size", 10)
	quest_tracker_label.add_theme_font_size_override("font_size", 11)
	quest_tracker_label.custom_minimum_size = Vector2.ZERO

	# Приціл-крапка: золотіє, коли є з чим взаємодіяти.
	crosshair = ColorRect.new()
	crosshair.anchor_left = 0.5
	crosshair.anchor_right = 0.5
	crosshair.anchor_top = 0.5
	crosshair.anchor_bottom = 0.5
	crosshair.offset_left = -1.5
	crosshair.offset_right = 1.5
	crosshair.offset_top = -1.5
	crosshair.offset_bottom = 1.5
	crosshair.color = Color(0.9, 0.88, 0.8, 0.35)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.visible = false
	hud_root.add_child(crosshair)

	# Червоне віньєтування при отриманні шкоди.
	damage_vignette = TextureRect.new()
	damage_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	damage_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	damage_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.5, 0.0, 0.0, 0.0))
	gradient.set_color(1, Color(0.45, 0.02, 0.02, 0.85))
	gradient.add_point(0.55, Color(0.5, 0.0, 0.0, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 1.0)
	texture.width = 256
	texture.height = 256
	damage_vignette.texture = texture
	damage_vignette.modulate.a = 0.0
	hud_root.add_child(damage_vignette)
	hud_root.move_child(damage_vignette, 0)


func _update_crosshair(has_target: bool) -> void:
	if crosshair == null:
		return
	crosshair.visible = current_screen == "game" and game_started and bool(player.get("first_person"))
	var half := 3.0 if has_target else 1.5
	crosshair.offset_left = -half
	crosshair.offset_right = half
	crosshair.offset_top = -half
	crosshair.offset_bottom = half
	crosshair.color = Color(0.95, 0.75, 0.4, 0.9) if has_target else Color(0.9, 0.88, 0.8, 0.35)


func _on_player_damaged(amount: float, blocked: bool) -> void:
	if damage_vignette == null:
		return
	var peak := clampf(amount / 30.0, 0.25, 0.9) * (0.4 if blocked else 1.0)
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(damage_vignette, "modulate:a", peak, 0.06)
	tween.tween_property(damage_vignette, "modulate:a", 0.0, 0.55)


func _make_hud_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.025, 0.033, 0.78)
	style.border_color = Color(0.56, 0.40, 0.19, 0.75)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style


# -----------------------------------------------------------------------------
# FULL-SCREEN MENU
# -----------------------------------------------------------------------------
func _create_menu_layer() -> void:
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 20
	add_child(menu_layer)

	menu_root = Control.new()
	menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_root.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_layer.add_child(menu_root)


func _create_cutscene_director() -> void:
	cutscene = CUTSCENE_SCRIPT.new()
	cutscene.name = "CutsceneDirector"
	add_child(cutscene)
	cutscene.call("setup", world_generator, player)
	cutscene.connect("finished", _on_cutscene_finished)


var _ending_started: bool = false


func _play_ending() -> void:
	## Фінал: світанок над звільненим світом, обліт камери навколо героя, нова музика, потім титри.
	if _ending_started or world_generator == null:
		return
	_ending_started = true
	extras.play_finale()

func _show_ending_credits() -> void:
	var layer := CanvasLayer.new()
	layer.name = "EndingCredits"
	layer.layer = 60
	add_child(layer)
	var root_control := Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root_control)
	var black := ColorRect.new()
	black.color = Color(0.0, 0.0, 0.0, 1.0)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(black)
	var text := Label.new()
	text.text = "ПЕРЕМОГА\n\nСтраж Ока впав. Три уламки Печатки зрослися — і вперше за багато років\nнад землями Попелу зійшов тихий ранок.\n\nОрест запалив перший вогонь, і він більше не гасне.\nМирон відкрив двері Села Попелу для всіх, хто вижив.\nКоли-небудь Око прокинеться знову. Але не сьогодні.\n\n\nEMBERS OF THE SPIRE\n\n\nГра на рушії Godot 4.7 (GDScript)\nПроцедурні світ, архітектура, текстури та обличчя\nМузика, фінальна композиція «Світанок над Попелом», звукові ефекти — синтезовані кодом\nЛицар і анімації — Mixamo\n\n\nДякуємо, що пройшли цей шлях до кінця."
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 22)
	text.add_theme_color_override("font_color", Color("#e8d8b4"))
	text.add_theme_constant_override("line_spacing", 8)
	var view := get_viewport().get_visible_rect().size
	text.size = Vector2(minf(900.0, view.x - 80.0), 10.0)
	text.position = Vector2((view.x - text.size.x) * 0.5, view.y)
	root_control.add_child(text)
	await get_tree().process_frame
	var distance := view.y + text.size.y + 40.0
	var scroll := create_tween()
	scroll.tween_property(text, "position:y", -text.size.y - 40.0, distance / 42.0)
	var menu_button := _make_oath_button("ГОЛОВНЕ МЕНЮ", Color("#342b21"), Color("#9f7b4d"))
	menu_button.anchor_left = 0.5
	menu_button.anchor_right = 0.5
	menu_button.anchor_top = 1.0
	menu_button.anchor_bottom = 1.0
	menu_button.offset_left = -130.0
	menu_button.offset_right = 130.0
	menu_button.offset_top = -80.0
	menu_button.offset_bottom = -30.0
	menu_button.pressed.connect(func() -> void:
		QuestManager.reset_all()
		AudioManager.stop_finale(0.6)
		get_tree().reload_current_scene()
	)
	root_control.add_child(menu_button)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _play_cinematic(kind: String) -> void:
	## Короткі атмосферні катсцени (кожна — лише один раз за гру).
	if cutscene == null or world_generator == null or player == null:
		return
	if _cinematics_seen.has(kind) and kind != "quest_start":
		return
	if bool(cutscene.call("is_busy")) or current_screen != "game" or not game_started:
		return
	var in_dungeon := bool(world_generator.get("player_in_dungeon"))
	if (kind == "dungeon") != in_dungeon:
		return
	var wg := world_generator
	var builder: Node = wg.get("terrain_builder")
	var p0: Vector3
	var p1: Vector3
	var look0: Vector3
	var look1: Vector3
	var seconds := 7.0
	var from_black := true
	match kind:
		"castle":
			var castle: Vector3 = wg.to_global(wg.call("_surface_position", 2930.0, 545.0, 0.0))
			p0 = castle + Vector3(-45.0, 10.0, 80.0)
			p1 = castle + Vector3(22.0, 20.0, 56.0)
			look0 = castle + Vector3(0.0, 16.0, 0.0)
			look1 = castle + Vector3(0.0, 14.0, 0.0)
			seconds = 8.0
		"mountain":
			if builder == null:
				return
			var foot: Vector3 = wg.to_global(builder.call("get_mountain_path_start"))
			var summit: Vector3 = wg.to_global(builder.call("get_summit_position"))
			p0 = foot + Vector3(26.0, 5.0, 30.0)
			p1 = foot + Vector3(16.0, 24.0, 12.0)
			look0 = foot.lerp(summit, 0.3)
			look1 = summit + Vector3(0.0, 12.0, 0.0)
			seconds = 8.0
		"dungeon":
			p0 = wg.to_global(Vector3(36.0, -46.2, -6.0))
			p1 = wg.to_global(Vector3(22.0, -46.6, 2.0))
			look0 = wg.to_global(Vector3(12.0, -47.4, 7.0))
			look1 = look0
			seconds = 6.5
		"quest_start":
			var cam := get_viewport().get_camera_3d()
			if cam == null:
				return
			var goal: Vector3 = wg.get("quest_target_position")
			if goal == Vector3.ZERO:
				return
			p0 = cam.global_position
			p1 = p0 + Vector3(0.0, 9.0, 0.0) - cam.global_transform.basis.z * 3.0
			look0 = p0 - cam.global_transform.basis.z * 8.0
			look1 = goal + Vector3(0.0, 4.0, 0.0)
			seconds = 6.0
			from_black = false
		_:
			return
	_cinematics_seen[kind] = true
	_set_player_controls(false)
	if not bool(cutscene.call("play_shot", p0, p1, look0, look1, seconds, 58.0, from_black)):
		_set_player_controls(true)


func _on_cutscene_finished() -> void:
	# Камеру повернуто гравцеві: після фіналу квесту знову дозволяємо керування.
	if game_started and current_screen == "game":
		_set_player_controls(true)


func _create_menu_camera() -> void:
	## Жива 3D-сцена за меню: камера пролітає над світом (scripts/ui/menu_camera.gd).
	if world_generator == null:
		return
	menu_camera = MENU_CAMERA_SCRIPT.new() as Camera3D
	menu_camera.name = "MenuCamera"
	add_child(menu_camera)
	menu_camera.call("setup", world_generator)


func _update_menu_camera() -> void:
	if menu_camera == null or player == null:
		return
	var want := not game_started and not intro_playing
	if want == _menu_cam_on:
		return
	_menu_cam_on = want
	if want:
		# У меню завжди сутінки з місяцем: вогні та небо найкраще виглядають саме так.
		if world_generator:
			world_generator.set("day_clock", 0.83)
		menu_camera.call("set_active", true)
	else:
		menu_camera.call("set_active", false)
		var player_camera := player.get("camera") as Camera3D
		if player_camera and not (cutscene and bool(cutscene.call("is_busy"))):
			player_camera.make_current()


func _make_shade_texture(offsets: PackedFloat32Array, colors: PackedColorArray, radial: bool) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = offsets
	gradient.colors = colors
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 512
	texture.height = 512 if radial else 4
	if radial:
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 1.0)
	else:
		texture.fill = GradientTexture2D.FILL_LINEAR
		texture.fill_from = Vector2(0.0, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
	return texture


func _make_particle_texture() -> ImageTexture:
	var image := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 1.0))
	return ImageTexture.create_from_image(image)


func _add_menu_particles() -> void:
	## Попіл і іскри, що повільно підіймаються над меню (GPUParticles2D).
	var size := get_viewport().get_visible_rect().size
	var texture := _make_particle_texture()
	for spark in [false, true]:
		var particles := GPUParticles2D.new()
		particles.name = "MenuSparks" if spark else "MenuAsh"
		particles.texture = texture
		particles.amount = 46 if spark else 90
		particles.lifetime = 9.0 if spark else 14.0
		particles.preprocess = particles.lifetime
		particles.position = Vector2(size.x * 0.5, size.y + 12.0)
		particles.visibility_rect = Rect2(-size.x, -size.y * 1.4, size.x * 2.0, size.y * 1.6)
		particles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var process := ParticleProcessMaterial.new()
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		process.emission_box_extents = Vector3(size.x * 0.6, 8.0, 1.0)
		process.direction = Vector3(0.18, -1.0, 0.0)
		process.spread = 24.0
		process.initial_velocity_min = 38.0 if spark else 16.0
		process.initial_velocity_max = 105.0 if spark else 46.0
		process.gravity = Vector3(12.0, -6.0 if not spark else -16.0, 0.0)
		process.scale_min = 1.0 if spark else 1.5
		process.scale_max = 2.0 if spark else 3.2
		process.angular_velocity_min = -40.0
		process.angular_velocity_max = 40.0
		var gradient := Gradient.new()
		if spark:
			gradient.colors = PackedColorArray([Color(1.0, 0.78, 0.36, 0.0), Color(1.0, 0.62, 0.22, 0.95), Color(0.9, 0.25, 0.08, 0.0)])
			gradient.offsets = PackedFloat32Array([0.0, 0.18, 1.0])
			var additive := CanvasItemMaterial.new()
			additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			particles.material = additive
		else:
			gradient.colors = PackedColorArray([Color(0.62, 0.6, 0.58, 0.0), Color(0.62, 0.6, 0.58, 0.5), Color(0.35, 0.34, 0.34, 0.0)])
			gradient.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
		var ramp := GradientTexture1D.new()
		ramp.gradient = gradient
		process.color_ramp = ramp
		particles.process_material = process
		menu_root.add_child(particles)


func _add_menu_backdrop() -> void:
	## Прозорий фон: бачимо живий світ (головне меню) або заморожену гру (пауза).
	var live := not game_started
	if not live:
		var dim := ColorRect.new()
		dim.color = Color(0.0, 0.0, 0.01, 0.42)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		menu_root.add_child(dim)

	var ink := Color(0.004, 0.008, 0.016)
	var side_shade := TextureRect.new()
	side_shade.texture = _make_shade_texture(
		PackedFloat32Array([0.0, 0.40, 0.75, 1.0]),
		PackedColorArray([Color(ink, 0.93), Color(ink, 0.74), Color(ink, 0.14), Color(ink, 0.0)]),
		false
	)
	side_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	side_shade.stretch_mode = TextureRect.STRETCH_SCALE
	side_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	side_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_root.add_child(side_shade)

	var vignette := TextureRect.new()
	vignette.texture = _make_shade_texture(
		PackedFloat32Array([0.0, 0.55, 1.0]),
		PackedColorArray([Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.72)]),
		true
	)
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_root.add_child(vignette)

	if live:
		# Кінематографічні смуги (letterbox) зверху й знизу.
		for top_bar in [true, false]:
			var bar := ColorRect.new()
			bar.color = Color(0.0, 0.0, 0.0, 0.96)
			bar.anchor_left = 0.0
			bar.anchor_right = 1.0
			bar.anchor_top = 0.0 if top_bar else 0.915
			bar.anchor_bottom = 0.085 if top_bar else 1.0
			bar.offset_left = 0.0
			bar.offset_right = 0.0
			bar.offset_top = 0.0
			bar.offset_bottom = 0.0
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			menu_root.add_child(bar)


func _clear_menu() -> void:
	for child in menu_root.get_children():
		menu_root.remove_child(child)
		child.queue_free()


func _build_fullscreen_menu(eyebrow_text: String, title_text: String, subtitle_text: String) -> VBoxContainer:
	_clear_menu()
	menu_root.visible = true
	menu_root.modulate = Color(1.0, 1.0, 1.0, 0.0)

	_add_menu_backdrop()

	_add_menu_particles()

	var column := VBoxContainer.new()
	column.name = "MenuContent"
	column.anchor_left = 0.075
	column.anchor_top = 0.105
	column.anchor_right = 0.445
	column.anchor_bottom = 0.89
	column.add_theme_constant_override("separation", 11)
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	menu_root.add_child(column)

	var eyebrow := Label.new()
	eyebrow.text = eyebrow_text
	eyebrow.add_theme_font_size_override("font_size", 13)
	eyebrow.add_theme_color_override("font_color", Color("#c59a5c"))
	eyebrow.add_theme_constant_override("outline_size", 2)
	eyebrow.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	column.add_child(eyebrow)

	var title := Label.new()
	title.text = title_text
	if title_text == "EMBERS OF THE SPIRE":
		# Заголовок ледь мерехтить, як вогонь факела.
		var flicker := title.create_tween().set_loops()
		flicker.tween_property(title, "modulate", Color(1.0, 0.92, 0.80, 1.0), 1.3).set_trans(Tween.TRANS_SINE)
		flicker.tween_property(title, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.9).set_trans(Tween.TRANS_SINE)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.add_theme_font_size_override("font_size", 58 if title_text == "EMBERS OF THE SPIRE" else 39)
	title.add_theme_color_override("font_color", Color("#efe0c0"))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
	column.add_child(title)
	if title_text == GAME_TITLE:
		# Піксельний готичний заголовок замість звичайного напису.
		title.visible = false
		var pixel_title := PIXEL_TITLE_SCRIPT.new() as Control
		column.add_child(pixel_title)
		column.move_child(pixel_title, title.get_index() + 1)
		pixel_title.call("build", "EMBERS OF THE", "SPIRE")
		var flicker_pixel := pixel_title.create_tween().set_loops()
		flicker_pixel.tween_property(pixel_title, "modulate", Color(1.0, 0.9, 0.78, 1.0), 1.4).set_trans(Tween.TRANS_SINE)
		flicker_pixel.tween_property(pixel_title, "modulate", Color(1.0, 1.0, 1.0, 1.0), 1.0).set_trans(Tween.TRANS_SINE)

	var subtitle := Label.new()
	subtitle.text = subtitle_text
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color("#b7b5ad"))
	column.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 7.0)
	column.add_child(spacer)

	var ornament := HBoxContainer.new()
	ornament.custom_minimum_size = Vector2(0.0, 3.0)
	ornament.add_theme_constant_override("separation", 7)
	column.add_child(ornament)
	var ornament_left := ColorRect.new()
	ornament_left.color = Color("#b88b4e")
	ornament_left.custom_minimum_size = Vector2(76.0, 2.0)
	ornament_left.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	ornament.add_child(ornament_left)
	var ornament_right := ColorRect.new()
	ornament_right.color = Color(0.64, 0.49, 0.29, 0.28)
	ornament_right.custom_minimum_size = Vector2(210.0, 1.0)
	ornament_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ornament.add_child(ornament_right)

	# Невеликий лор-блок врівноважує композицію праворуч.
	var lore := Label.new()
	lore.text = "КОЛИ ОСТАННІЙ ВОГОНЬ ЗГАСНЕ,\nОКО ВСЕ ЩЕ БУДЕ ДИВИТИСЯ."
	lore.anchor_left = 0.64
	lore.anchor_top = 0.79
	lore.anchor_right = 0.93
	lore.anchor_bottom = 0.90
	lore.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lore.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lore.add_theme_font_size_override("font_size", 14)
	lore.add_theme_color_override("font_color", Color(0.84, 0.79, 0.68, 0.78))
	lore.add_theme_constant_override("outline_size", 2)
	lore.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	menu_root.add_child(lore)

	return column


func _make_button_style(background: Color, border: Color, selected: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	# Рамка-«віконце» у стилі PS1: товстий контур і піксельна тінь.
	style.border_width_left = 5 if selected else 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = 1
	style.shadow_offset = Vector2(3.0, 3.0)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.content_margin_left = 20.0
	style.content_margin_right = 18.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style


func _add_menu_button(column: VBoxContainer, button_text: String, callback: Callable, accent: String = "›") -> Button:
	var button := Button.new()
	button.text = "   %s     %s" % [button_text, accent]
	button.custom_minimum_size = Vector2(0.0, 55.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color("#d8d2c4"))
	button.add_theme_color_override("font_hover_color", Color("#fff0cf"))
	button.add_theme_color_override("font_pressed_color", Color("#d5a65d"))
	button.add_theme_stylebox_override("normal", _make_button_style(Color(0.018, 0.025, 0.034, 0.25), Color(0.49, 0.40, 0.27, 0.55)))
	button.add_theme_stylebox_override("hover", _make_button_style(Color(0.10, 0.12, 0.14, 0.76), Color("#c89b5d"), true))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.04, 0.05, 0.06, 0.90), Color("#e1b56c"), true))
	button.add_theme_stylebox_override("focus", _make_button_style(Color(0.07, 0.08, 0.09, 0.60), Color("#b88b4e"), true))
	button.mouse_entered.connect(AudioManager.play_ui.bind("ui_hover"))
	button.focus_entered.connect(AudioManager.play_ui.bind("ui_hover"))
	button.pressed.connect(AudioManager.play_ui.bind("ui_back" if accent == "‹" else "ui_click"))
	button.pressed.connect(callback)
	column.add_child(button)
	return button


func _add_section_label(column: VBoxContainer, text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("#c49b62"))
	column.add_child(label)
	return label


func _show_main_menu() -> void:
	current_screen = "main"
	game_started = false
	if story_root:
		story_root.visible = false
	if vitals_panel:
		vitals_panel.visible = false
	if day_cycle_label:
		day_cycle_label.visible = false
	if world_dialogue_root:
		world_dialogue_root.visible = false
	_set_player_controls(false)
	hud_panel.visible = false
	var column := _build_fullscreen_menu("THE ASHEN KINGDOM AWAITS", "EMBERS OF THE SPIRE", "ОБЕРИ ПРИСЯГУ. ЗМІНИ ДОЛЮ ЗАБУТИХ ЗЕМЕЛЬ.")
	_add_menu_button(column, "ПОЧАТИ ПОДОРОЖ", _start_game, "›")
	_add_menu_button(column, "КЕРУВАННЯ", _show_controls_menu, "›")
	_add_menu_button(column, "НАЛАШТУВАННЯ", _open_settings, "›")
	_add_menu_button(column, "ТИТРИ", _show_credits_menu, "›")
	_add_menu_button(column, "ВИЙТИ З ГРИ", _exit_game, "×")
	_fade_menu_in()


func _show_credits_menu() -> void:
	current_screen = "credits"
	var column := _build_fullscreen_menu("THOSE WHO KEPT THE FIRE", "ТИТРИ", "")
	var credits := Label.new()
	credits.text = "EMBERS OF THE SPIRE\n\nГра на рушії Godot 4.7 (GDScript)\nПроцедурні світ, архітектура, текстури та обличчя\nМузика, фінальна композиція «Світанок над Попелом», звукові ефекти — синтезовані кодом\nЛицар і анімації — Mixamo\n\nДякуємо, що пройшли цей шлях до кінця."
	credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credits.add_theme_font_size_override("font_size", 16)
	credits.add_theme_color_override("font_color", Color("#e0d7c8"))
	credits.custom_minimum_size = Vector2(0.0, 250.0)
	column.add_child(credits)
	_add_menu_button(column, "НАЗАД", _show_main_menu, "‹")
	_fade_menu_in()


func _show_pause_menu() -> void:
	if current_screen == "game":
		AudioManager.play_ui("ui_open")
	current_screen = "pause"
	_set_player_controls(false)
	hud_panel.visible = false
	var column := _build_fullscreen_menu("THE JOURNEY IS NOT OVER", "ПАУЗА", "ПЕРЕДОХНИ. ТІНІ НІКУДИ НЕ ЗНИКНУТЬ.")
	_add_menu_button(column, "ПРОДОВЖИТИ", _resume_game, "›")
	_add_menu_button(column, "ЖУРНАЛ ЗАВДАНЬ", Callable(self, "_open_quest_journal").bind("pause"), "›")
	_add_menu_button(column, "КЕРУВАННЯ", _show_controls_menu, "›")
	_add_menu_button(column, "НАЛАШТУВАННЯ", _open_settings, "›")
	_add_menu_button(column, "ГОЛОВНЕ МЕНЮ", _return_to_main_menu, "›")
	_add_menu_button(column, "ВИЙТИ З ГРИ", _exit_game, "×")
	_fade_menu_in()


func _show_controls_menu() -> void:
	settings_return_screen = current_screen
	current_screen = "controls"
	_set_player_controls(false)
	var column := _build_fullscreen_menu("THE KNIGHT'S PATH", "КЕРУВАННЯ", "РУХАЙСЯ ОБЕРЕЖНО. КОЖЕН УДАР МАЄ ЦІНУ.")

	var controls := Label.new()
	controls.text = "W A S D     Рух лицаря\nSHIFT         Біг — витрачає витривалість\nSPACE         Стрибок\nЛКМ            Удар мечем\nR                 Сховати / дістати меч\nB                 Лук (ЛКМ — натягнути й стріляти)\nQ                 Підняти щит / парирувати\nE                 Взаємодія з NPC та об'єктами\nM                Атлас світу\nJ                 Журнал завдань\nI                  Сумка (інвентар)\nV                 Перша / третя особа\nF                 Факел / ліхтар\nESC             Пауза або закриття вікна"
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_theme_font_size_override("font_size", 16)
	controls.add_theme_color_override("font_color", Color("#e0d7c8"))
	controls.custom_minimum_size = Vector2(0.0, 260.0)
	column.add_child(controls)
	_add_menu_button(column, "НАЗАД", _return_from_controls, "‹")
	_fade_menu_in()


func _return_from_controls() -> void:
	if settings_return_screen == "pause":
		_show_pause_menu()
	else:
		_show_main_menu()


func _show_settings_menu() -> void:
	current_screen = "settings"
	_set_player_controls(false)
	hud_panel.visible = false
	var column := _build_fullscreen_menu("MAKE THE NIGHT YOURS", "НАЛАШТУВАННЯ", "ЗОБРАЖЕННЯ ТА ЗВУК")

	_add_section_label(column, "ЕКРАН")
	var fullscreen_check := CheckButton.new()
	fullscreen_check.text = "Повноекранний режим"
	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_check.add_theme_font_size_override("font_size", 15)
	fullscreen_check.add_theme_color_override("font_color", Color("#ded8ca"))
	fullscreen_check.toggled.connect(_set_fullscreen)
	column.add_child(fullscreen_check)

	_add_section_label(column, "РЕТРО-ГРАФІКА")
	var retro_row := HBoxContainer.new()
	retro_row.add_theme_constant_override("separation", 12)
	column.add_child(retro_row)
	var retro_label := Label.new()
	retro_label.text = "Пікселізація"
	retro_label.custom_minimum_size = Vector2(178.0, 0.0)
	retro_label.add_theme_font_size_override("font_size", 14)
	retro_label.add_theme_color_override("font_color", Color("#ded8ca"))
	retro_row.add_child(retro_label)
	var retro_option := OptionButton.new()
	retro_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retro_option.add_theme_font_size_override("font_size", 14)
	for preset_index in range(RetroFX.PRESET_ORDER.size()):
		var preset_id: String = RetroFX.PRESET_ORDER[preset_index]
		retro_option.add_item(RetroFX.get_preset_label(preset_id), preset_index)
		if preset_id == RetroFX.preset:
			retro_option.select(preset_index)
	retro_option.item_selected.connect(func(index: int) -> void:
		RetroFX.set_preset(RetroFX.PRESET_ORDER[index])
	)
	retro_row.add_child(retro_option)

	var dither_check := CheckButton.new()
	dither_check.text = "Дизеринг і 15-бітний колір PS1"
	dither_check.button_pressed = RetroFX.dither_enabled
	dither_check.add_theme_font_size_override("font_size", 15)
	dither_check.add_theme_color_override("font_color", Color("#ded8ca"))
	dither_check.toggled.connect(RetroFX.set_dither_enabled)
	column.add_child(dither_check)

	var jitter_check := CheckButton.new()
	jitter_check.text = "Тремтіння вершин (vertex jitter)"
	jitter_check.button_pressed = RetroFX.jitter_enabled
	jitter_check.add_theme_font_size_override("font_size", 15)
	jitter_check.add_theme_color_override("font_color", Color("#ded8ca"))
	jitter_check.toggled.connect(RetroFX.set_jitter_enabled)
	column.add_child(jitter_check)

	_add_section_label(column, "ЗВУК")
	_add_volume_row(column, "Загальна гучність", "master")
	_add_volume_row(column, "Музика", "music")
	_add_volume_row(column, "Ефекти", "sfx")
	_add_volume_row(column, "Оточення", "ambient")

	var music_hint := Label.new()
	music_hint.text = "Уся музика та звуки синтезовані спеціально для Embers of the Spire"
	music_hint.add_theme_font_size_override("font_size", 11)
	music_hint.add_theme_color_override("font_color", Color("#aaa79d"))
	column.add_child(music_hint)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, 6.0)
	column.add_child(gap)
	_add_menu_button(column, "НАЗАД", _return_from_settings, "‹")
	_fade_menu_in()


func _fade_menu_in() -> void:
	var fade := create_tween()
	fade.set_trans(Tween.TRANS_SINE)
	fade.set_ease(Tween.EASE_OUT)
	fade.tween_property(menu_root, "modulate:a", 1.0, 0.38)


func _open_settings() -> void:
	settings_return_screen = current_screen
	_show_settings_menu()


func _return_from_settings() -> void:
	if settings_return_screen == "pause":
		_show_pause_menu()
	elif settings_return_screen == "game":
		_resume_game()
	else:
		_show_main_menu()


func _set_fullscreen(enabled: bool) -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


func _start_game() -> void:
	if intro_playing or game_started:
		return
	QuestManager.reset_all()
	if world_generator:
		world_generator.set("day_clock", 0.76)
	score = 0
	_update_score()
	game_started = false
	intro_playing = true
	current_screen = "intro"
	menu_root.visible = false
	hud_panel.visible = false
	_set_player_controls(false)
	await _play_intro_sequence()


func _create_intro_overlay() -> void:
	intro_layer = CanvasLayer.new()
	intro_layer.name = "OpeningCinematic"
	intro_layer.layer = 40
	add_child(intro_layer)

	intro_root = Control.new()
	intro_root.name = "CinematicRoot"
	intro_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_root.mouse_filter = Control.MOUSE_FILTER_STOP
	intro_layer.add_child(intro_root)

	intro_background = TextureRect.new()
	intro_background.name = "CinematicBackground"
	intro_background.texture = MENU_BACKGROUND
	intro_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	intro_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	intro_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_background.pivot_offset = get_viewport().get_visible_rect().size * 0.5
	intro_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Замість картинки — проліт камери над живим світом (CutsceneDirector).
	intro_background.visible = false
	intro_root.add_child(intro_background)

	var tint := ColorRect.new()
	tint.color = Color(0.006, 0.009, 0.016, 0.20)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_root.add_child(tint)

	var embers := Control.new()
	embers.name = "CinematicEmbers"
	embers.set_script(EMBER_SCRIPT)
	embers.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	embers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_root.add_child(embers)

	# Letterbox bars add a cinematic composition without touching the 3D world.
	var top_bar := ColorRect.new()
	top_bar.color = Color(0.004, 0.006, 0.010, 0.94)
	top_bar.anchor_right = 1.0
	top_bar.anchor_bottom = 0.105
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_root.add_child(top_bar)

	var bottom_bar := ColorRect.new()
	bottom_bar.color = Color(0.004, 0.006, 0.010, 0.94)
	bottom_bar.anchor_top = 0.895
	bottom_bar.anchor_right = 1.0
	bottom_bar.anchor_bottom = 1.0
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_root.add_child(bottom_bar)

	var game_title := Label.new()
	game_title.text = "EMBERS OF THE SPIRE"
	game_title.anchor_left = 0.12
	game_title.anchor_top = 0.16
	game_title.anchor_right = 0.88
	game_title.anchor_bottom = 0.25
	game_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_title.add_theme_font_size_override("font_size", 42)
	game_title.add_theme_color_override("font_color", Color("#f0dfbd"))
	game_title.add_theme_constant_override("outline_size", 3)
	game_title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	intro_root.add_child(game_title)

	var divider := ColorRect.new()
	divider.color = Color(0.72, 0.51, 0.27, 0.82)
	divider.anchor_left = 0.38
	divider.anchor_top = 0.285
	divider.anchor_right = 0.62
	divider.anchor_bottom = 0.288
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_root.add_child(divider)

	intro_copy = Control.new()
	intro_copy.name = "StoryText"
	intro_copy.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_copy.modulate.a = 0.0
	intro_copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_root.add_child(intro_copy)

	intro_kicker = Label.new()
	intro_kicker.anchor_left = 0.12
	intro_kicker.anchor_top = 0.36
	intro_kicker.anchor_right = 0.88
	intro_kicker.anchor_bottom = 0.42
	intro_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_kicker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	intro_kicker.add_theme_font_size_override("font_size", 14)
	intro_kicker.add_theme_color_override("font_color", Color("#c79a60"))
	intro_kicker.add_theme_constant_override("outline_size", 2)
	intro_kicker.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	intro_copy.add_child(intro_kicker)

	intro_body = Label.new()
	intro_body.anchor_left = 0.16
	intro_body.anchor_top = 0.44
	intro_body.anchor_right = 0.84
	intro_body.anchor_bottom = 0.69
	intro_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	intro_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_body.add_theme_font_size_override("font_size", 24)
	intro_body.add_theme_color_override("font_color", Color("#eee6d7"))
	intro_body.add_theme_constant_override("outline_size", 3)
	intro_body.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	intro_copy.add_child(intro_body)


	intro_black = ColorRect.new()
	intro_black.color = Color(0.0, 0.0, 0.0, 1.0)
	intro_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_root.add_child(intro_black)


func _play_intro_card(kicker_text: String, body_text: String) -> void:
	intro_kicker.text = kicker_text
	intro_body.text = body_text
	intro_copy.modulate.a = 0.0
	var appear := create_tween()
	appear.set_trans(Tween.TRANS_SINE)
	appear.set_ease(Tween.EASE_OUT)
	appear.tween_property(intro_copy, "modulate:a", 1.0, 0.35)
	await appear.finished
	# Кожна фраза тримається ~5.5 с, щоб її спокійно можна було прочитати.
	await get_tree().create_timer(5.5).timeout
	var disappear := create_tween()
	disappear.set_trans(Tween.TRANS_SINE)
	disappear.set_ease(Tween.EASE_IN)
	disappear.tween_property(intro_copy, "modulate:a", 0.0, 0.35)
	await disappear.finished


func _play_intro_sequence() -> void:
	_create_intro_overlay()
	var start_time_ms: int = Time.get_ticks_msec()

	# Музика головного меню приглушується, щоб було чути окремий вступний саундтрек.
	if music_player:
		var duck := create_tween()
		duck.tween_property(music_player, "volume_db", -24.0, 0.7)

	intro_audio_player = AudioStreamPlayer.new()
	intro_audio_player.name = "OpeningCinematicAudio"
	intro_audio_player.stream = INTRO_SOUNDTRACK
	intro_audio_player.volume_db = -2.0
	intro_audio_player.bus = "Music"
	var intro_wav := INTRO_SOUNDTRACK as AudioStreamWAV
	if intro_wav:
		intro_wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		intro_wav.loop_begin = 0
		intro_wav.loop_end = int(round(intro_wav.get_length() * float(intro_wav.mix_rate)))
	add_child(intro_audio_player)
	intro_audio_player.play()
	if cutscene:
		cutscene.call("play_flyover", INTRO_DURATION)

	var reveal := create_tween()
	reveal.set_trans(Tween.TRANS_SINE)
	reveal.set_ease(Tween.EASE_OUT)
	reveal.tween_property(intro_black, "color:a", 0.0, 0.75)

	# Повільне наближення фону створює відчуття руху камери.
	var camera_move := create_tween()
	camera_move.set_trans(Tween.TRANS_SINE)
	camera_move.set_ease(Tween.EASE_IN_OUT)
	camera_move.tween_property(intro_background, "scale", Vector2(1.13, 1.13), INTRO_DURATION)
	camera_move.parallel().tween_property(intro_background, "position", Vector2(-34.0, -18.0), INTRO_DURATION)

	# Чотири картки займають 14.2 секунди; решта часу — плавне зникнення інтро.
	await _play_intro_card("ПАМ'ЯТЬ КОРОЛІВ", "Колись ці землі були єдиним королівством. Його дороги з'єднували міста, а вогні замків не згасали навіть у найдовшу ніч.")
	await _play_intro_card("ПРОБУДЖЕННЯ ТІНІ", "Та з надр Чорної Гори прокинулося Око. Його погляд приніс попіл, холод і голоси, що кликали живих на ім'я.")
	await _play_intro_card("КОРОНА ПОПЕЛУ", "Король зник. Присяги розсипалися, мов прах. Ті, хто вижив, сховали правду в руїнах і замкнули старі брами.")
	await _play_intro_card("ОСТАННІЙ СПОГАД", "Коли дзвони замовкли, хтось усе ж почув поклик під землею. Історія ще не завершена.")

	var elapsed: float = float(Time.get_ticks_msec() - start_time_ms) / 1000.0
	var remaining: float = maxf(INTRO_DURATION - elapsed, 0.0)
	if remaining > 0.0:
		var fade_time := maxf(remaining, 0.6)
		if cutscene:
			cutscene.call("fade_to_black", fade_time)
		await get_tree().create_timer(fade_time).timeout

	_finish_intro()


func _finish_intro() -> void:
	if cutscene:
		cutscene.call("stop_flyover")
		cutscene.call("fade_from_black", 1.4)
	if intro_audio_player:
		intro_audio_player.stop()
		intro_audio_player.queue_free()
		intro_audio_player = null
	if intro_layer:
		intro_layer.queue_free()
		intro_layer = null
	intro_root = null
	intro_background = null
	intro_black = null
	intro_copy = null
	intro_kicker = null
	intro_body = null

	intro_playing = false
	game_started = true
	current_screen = "game"
	if world_generator and world_generator.has_method("begin_part2_dungeon"):
		world_generator.call("begin_part2_dungeon")
	hud_panel.visible = true
	if vitals_panel:
		vitals_panel.visible = true
	if day_cycle_label:
		day_cycle_label.visible = true
	_set_player_controls(true)
	_update_story_hud()
	get_tree().create_timer(2.2).timeout.connect(func() -> void: _play_cinematic("dungeon"))
	_show_story_toast("ТИ ПРОКИДАЄШСЯ", "Холодний камінь під спиною. Десь за стінами крапає вода. Ти не пам'ятаєш, як опинився в Казематах. Знайди Камінь Присяги — він покаже шлях назовні.", 7.0)

	if music_player:
		var restore := create_tween()
		restore.tween_property(music_player, "volume_db", linear_to_db(maxf(music_volume_percent / 100.0, 0.0001)), 1.2)


func _resume_game() -> void:
	game_started = true
	current_screen = "game"
	menu_root.visible = false
	hud_panel.visible = true
	if vitals_panel:
		vitals_panel.visible = true
	if day_cycle_label:
		day_cycle_label.visible = true
	_set_player_controls(true)
	_update_story_hud()


func _return_to_main_menu() -> void:
	game_started = false
	_show_main_menu()


func _set_player_controls(enabled: bool) -> void:
	if player and player.has_method("set_controls_enabled"):
		player.call("set_controls_enabled", enabled)


func _update_score() -> void:
	if score_label:
		score_label.text = "◈   Монети: %d" % score


func _exit_game() -> void:
	get_tree().quit()
