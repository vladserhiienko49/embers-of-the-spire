class_name InventoryScreen
extends CanvasLayer
## Повноцінний екран інвентарю (клавіша I) у стилі PS1 dark fantasy.
## Секції: зброя й спорядження (меч, лук, стріли, світло, щит), витратні предмети, сюжетні предмети,
## характеристики. Вибір слота показує опис; дії (дістати, сховати, використати) реально змінюють гравця.

const STORY_ITEM_INFO: Dictionary = {
	"seal_fragment_1": {"icon": "fragment_red", "desc": "Перший уламок Стародавньої Печатки. Пульсує теплом: Лицар Попелу носив його на грудях."},
	"seal_fragment_2": {"icon": "fragment_violet", "desc": "Другий уламок Печатки. Холодний і тихий. Некромант Руїн ховав його під каптуром."},
	"seal_fragment_3": {"icon": "fragment_gold", "desc": "Третій уламок Печатки. Його стерегла вартова Цитаделі. На Вівтарі Ока три уламки зростуться."},
	"lamp_oil": {"icon": "oil", "desc": "Фляга ліхтарної олії з Забутого кладовища. Потрібна Оресту."},
	"orest_lantern": {"icon": "lantern", "desc": "Ліхтар Ореста: світить рівніше за факел."},
	"merchant_crate": {"icon": "crate", "desc": "Ящик із ліками, загублений Бруно біля Табору вигнанців."},
	"healing_herb": {"icon": "herb", "desc": "Цілюща трава з-під Села Попелу. Збери три пучки для Йохана."},
	"atlas_piece": {"icon": "atlas", "desc": "Шматки Атласу Корони. Монахи Ордену Печатки розірвали карту й роздали частини хранителям, щоб ніхто не знайшов Ока. Кожен знайдений шматок одразу вклеєно в карту (M) — загубити його неможливо."},
	"horse_deed": {"icon": "note", "desc": "Кінь куплений у Хорена зі стайні біля Села Попелу. Свисни (H) просто неба — гнідий прибіжить. Сісти: E, зійти: E, галоп: Shift, вид від першої особи: V."},
	"witch_skull_staff": {"icon": "shard", "desc": "Череп-посох Кістяної Вдови: доказ її смерті. Очниці досі слабо світяться фіолетовим. Віднеси Руну Слідопиту."},
	"frost_core": {"icon": "gem_blue", "desc": "Крижане Серце Давнього Мага: холодний кристал, що відповідав на сигнал Ока. Віднеси Ренну в Обсерваторію."},
	"stag_amulet": {"icon": "gem_blue", "desc": "Амулет Лісу з прихованої печери Білої Лані: зерно живого світла в холодному камені."},
	"pit_sigil": {"icon": "shard", "desc": "Печать Кістяної Ями: давня нагорода тим, хто витримав три хвилі в замкненому колі."},
	"traveller_flask": {"icon": "herb", "desc": "Фляга врятованого мандрівника: на денці лишився ковток цілющого зілля й складена записка."},
	"map_fragment": {"icon": "note", "desc": "Відірваний край атласу з місцем Ока. Герой зшив його з картою: відкрийте атлас (M)."},
	"moon_shard": {"icon": "shard", "desc": "Уламок місячного скла зі Склепу Забутих Королів. Мерехтить без світла."},
	"moon_stone": {"icon": "gem_blue", "desc": "Місячний камінь із королівського саркофага. Холодний, як вода зі студні. Потрібен Лірі для лінзи маяка."},
	"moon_lens": {"icon": "gem_blue", "desc": "Місячна лінза — нагорода за Згаслий Маяк. Удари по породженнях Ока наносять на чверть більше шкоди."},
}

const BG := Color(0.04, 0.032, 0.03, 0.98)
const BORDER := Color(0.55, 0.42, 0.24, 1.0)
const BORDER_SEL := Color(0.98, 0.82, 0.42, 1.0)
const SLOT_BG := Color(0.09, 0.07, 0.06, 1.0)
const TEXT := Color("#e9dfc9")
const TEXT_DIM := Color("#9f9684")
const GOLD := Color("#e4c18a")

var main: Node = null
var extras: Node = null
var _root: Control = null
var _coins_label: Label = null
var _weapon_grid: GridContainer = null
var _consumable_grid: GridContainer = null
var _story_grid: GridContainer = null
var _stats_label: Label = null
var _detail_icon: SlotIcon = null
var _detail_title: Label = null
var _detail_state: Label = null
var _detail_body: Label = null
var _action_button: Button = null
var _selected: String = "sword"
var _items: Dictionary = {}
var _slot_buttons: Dictionary = {}


func setup(main_node: Node, extras_node: Node) -> void:
	main = main_node
	extras = extras_node
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func is_open() -> bool:
	return _root != null and _root.visible


func open() -> void:
	if is_open():
		return
	main.set("current_screen", "inventory")
	main.call("_set_player_controls", false)
	_selected = "sword" if not _items.has(_selected) else _selected
	_refresh()
	_root.visible = true
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.16)
	AudioManager.play_ui("journal_open")


func close() -> void:
	if not is_open():
		return
	_root.visible = false
	AudioManager.play_ui("ui_back")
	main.call("_close_world_dialogue")


# --- Побудова інтерфейсу ----------------------------------------------------------------

static func _box_style(fill: Color, border: Color, width: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(0)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _section_header(parent: Control, text: String) -> void:
	var l := _label(text, 15, GOLD)
	parent.add_child(l)
	var line := ColorRect.new()
	line.color = Color(0.55, 0.42, 0.24, 0.8)
	line.custom_minimum_size = Vector2(0.0, 2.0)
	parent.add_child(line)


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -560.0
	panel.offset_right = 560.0
	panel.offset_top = -330.0
	panel.offset_bottom = 330.0
	panel.add_theme_stylebox_override("panel", _box_style(BG, BORDER, 3))
	_root.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	# Шапка.
	var header := HBoxContainer.new()
	column.add_child(header)
	header.add_child(_label("СУМКА", 28, GOLD))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_coins_label = _label("", 20, Color("#f2d27a"))
	header.add_child(_coins_label)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(26.0, 0.0)
	header.add_child(gap)
	header.add_child(_label("I / ESC — ЗАКРИТИ", 13, TEXT_DIM))
	var divider := ColorRect.new()
	divider.color = BORDER
	divider.custom_minimum_size = Vector2(0.0, 3.0)
	column.add_child(divider)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)

	# Ліва колонка: зброя та витратні.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.custom_minimum_size = Vector2(380.0, 0.0)
	body.add_child(left)
	_section_header(left, "ЗБРОЯ ТА СПОРЯДЖЕННЯ")
	_weapon_grid = GridContainer.new()
	_weapon_grid.columns = 3
	_weapon_grid.add_theme_constant_override("h_separation", 8)
	_weapon_grid.add_theme_constant_override("v_separation", 8)
	left.add_child(_weapon_grid)
	_section_header(left, "ВИТРАТНІ ПРЕДМЕТИ")
	_consumable_grid = GridContainer.new()
	_consumable_grid.columns = 3
	_consumable_grid.add_theme_constant_override("h_separation", 8)
	_consumable_grid.add_theme_constant_override("v_separation", 8)
	left.add_child(_consumable_grid)

	# Середня колонка: сюжетні предмети і характеристики.
	var middle := VBoxContainer.new()
	middle.add_theme_constant_override("separation", 8)
	middle.custom_minimum_size = Vector2(340.0, 0.0)
	body.add_child(middle)
	_section_header(middle, "СЮЖЕТНІ ПРЕДМЕТИ")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 232.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	middle.add_child(scroll)
	_story_grid = GridContainer.new()
	_story_grid.columns = 3
	_story_grid.add_theme_constant_override("h_separation", 8)
	_story_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_story_grid)
	_section_header(middle, "ХАРАКТЕРИСТИКИ")
	_stats_label = _label("", 14, TEXT)
	middle.add_child(_stats_label)

	# Права колонка: опис вибраного предмета.
	var right := PanelContainer.new()
	right.custom_minimum_size = Vector2(290.0, 0.0)
	right.add_theme_stylebox_override("panel", _box_style(Color(0.06, 0.048, 0.04, 1.0), BORDER, 2))
	body.add_child(right)
	var rm := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		rm.add_theme_constant_override("margin_" + side, 14)
	right.add_child(rm)
	var rc := VBoxContainer.new()
	rc.add_theme_constant_override("separation", 8)
	rm.add_child(rc)
	_detail_icon = SlotIcon.new()
	_detail_icon.custom_minimum_size = Vector2(150.0, 150.0)
	_detail_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rc.add_child(_detail_icon)
	_detail_title = _label("", 20, GOLD)
	_detail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rc.add_child(_detail_title)
	_detail_state = _label("", 13, Color("#8fd19a"))
	_detail_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rc.add_child(_detail_state)
	_detail_body = _label("", 14, TEXT)
	_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_body.custom_minimum_size = Vector2(250.0, 0.0)
	_detail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rc.add_child(_detail_body)
	_action_button = Button.new()
	_action_button.custom_minimum_size = Vector2(0.0, 50.0)
	_action_button.add_theme_font_size_override("font_size", 16)
	_action_button.add_theme_color_override("font_color", TEXT)
	_action_button.add_theme_stylebox_override("normal", _box_style(Color("#342b21"), Color("#9f7b4d"), 2))
	_action_button.add_theme_stylebox_override("hover", _box_style(Color("#4a3c2c"), BORDER_SEL, 2))
	_action_button.add_theme_stylebox_override("pressed", _box_style(Color("#5a4830"), BORDER_SEL, 2))
	_action_button.add_theme_stylebox_override("disabled", _box_style(Color("#1e1a16"), Color("#4a4136"), 2))
	_action_button.pressed.connect(_on_action_pressed)
	rc.add_child(_action_button)


func _input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


# --- Дані --------------------------------------------------------------------------------------

func _player() -> Node:
	return main.get("player") as Node


func _collect() -> void:
	_items.clear()
	var player := _player()
	if player == null:
		return
	var bow: Object = player.get("bow")
	var bow_owned := int(player.get_meta("bow_level", 0)) >= 1
	var bow_out: bool = bow != null and bool(bow.get("equipped"))
	var sword_out: bool = bool(player.get("weapon_drawn")) and not bow_out
	var sword_damage := 36 + 9 * int(player.get_meta("sword_level", 0)) + (12 if bool(player.get_meta("weapon_tempered", false)) else 0)
	_items["sword"] = {"name": "Попелястий меч", "icon": "sword", "section": "weapon", "count": -1,
		"state": "У РУЦІ" if sword_out else "У ПІХВАХ", "good": sword_out,
		"desc": "Шкода удару: %d.\nЛКМ — удар, Q — щит із парируванням. Загартування в Каталана збільшує шкоду." % sword_damage,
		"action": "СХОВАТИ МЕЧ  (R)" if sword_out else "ДІСТАТИ МЕЧ", "enabled": true}
	var arrows := int(player.get_meta("arrows", 0))
	var bow_damage := int(24.0 + 40.0 + 7.0 * float(int(player.get_meta("bowdmg_level", 0))))
	_items["bow"] = {"name": "Місячний лук", "icon": "bow", "section": "weapon", "count": -1,
		"state": ("У РУЦІ" if bow_out else "ЗА СПИНОЮ") if bow_owned else "НЕ КУПЛЕНО", "good": bow_out, "locked": not bow_owned,
		"desc": ("Дальня зброя: ЛКМ — натягнути, відпустити — вистрілити. Повний натяг до %d шкоди, постріл у голову ×1.6. Рівень тятиви: %d/3." % [bow_damage, int(player.get_meta("bowdmg_level", 0))]) if bow_owned else "Лук продає Ліра, чародійка-лучниця, у Вежі Місячної Лучниці на сході.",
		"action": "СХОВАТИ ЛУК  (B)" if bow_out else "ДІСТАТИ ЛУК  (B)", "enabled": bow_owned}
	_items["arrows"] = {"name": "Стріли", "icon": "arrows", "section": "weapon", "count": arrows if bow_owned else -1,
		"state": "У САГАЙДАКУ" if bow_owned else "НЕМАЄ ЛУКА", "good": arrows > 0, "locked": not bow_owned,
		"desc": "Боєприпаси для лука: %d шт. Нові стріли продає Ліра." % arrows,
		"action": "ПОСТРІЛ — ЛКМ З ЛУКОМ", "enabled": false}
	var fx: Object = player.get("fx")
	var lantern: bool = fx != null and str(fx.get("light_kind")) == "lantern"
	var light_on: bool = fx != null and bool(fx.get("light_enabled"))
	_items["light"] = {"name": "Ліхтар Ореста" if lantern else "Факел", "icon": "lantern" if lantern else "torch", "section": "weapon", "count": -1,
		"state": "ГОРИТЬ" if light_on else "ПОГАШЕНО", "good": light_on,
		"desc": "Світло в лівій руці. F — запалити чи погасити. Ліхтар Ореста горить рівніше за факел.",
		"action": "ПОГАСИТИ  (F)" if light_on else "ЗАПАЛИТИ  (F)", "enabled": fx != null}
	_items["shield"] = {"name": "Щит", "icon": "shield", "section": "weapon", "count": -1,
		"state": "ЕКІПІРОВАНО", "good": true,
		"desc": "Q — підняти щит. Вчасний блок — ідеальне парирування: ворог втрачає рівновагу. Утримання щита витрачає витривалість. З луком щит недоступний.",
		"action": "ПІДНІМАЄТЬСЯ КЛАВІШЕЮ Q", "enabled": false}
	var cons: Dictionary = extras.get("consumables")
	_items["potion"] = {"name": "Зілля лікування", "icon": "potion", "section": "consumable", "count": int(cons.get("potion", 0)),
		"state": "КЛАВІША 1", "good": false, "desc": "Відновлює 55 здоров'я. Купується в Вальмера та Бруно.",
		"action": "ВИПИТИ  (1)", "enabled": int(cons.get("potion", 0)) > 0}
	_items["fire"] = {"name": "Сувій Вогню", "icon": "scroll_fire", "section": "consumable", "count": int(cons.get("fire", 0)),
		"state": "КЛАВІША 2", "good": false, "desc": "Спалює ворогів у радіусі 11 м (80 шкоди кожному).",
		"action": "ПРОЧИТАТИ  (2)", "enabled": int(cons.get("fire", 0)) > 0}
	_items["ward"] = {"name": "Сувій Оберега", "icon": "scroll_ward", "section": "consumable", "count": int(cons.get("ward", 0)),
		"state": "КЛАВІША 3", "good": false, "desc": "8 секунд невразливості. Видимий синій ореол навколо героя.",
		"action": "ПРОЧИТАТИ  (3)", "enabled": int(cons.get("ward", 0)) > 0}
	var inv: Dictionary = QuestManager.get_inventory()
	var ids: Array = inv.keys()
	ids.sort()
	for item_id in ids:
		var amount := int(inv[item_id])
		if amount <= 0:
			continue
		var info: Dictionary = STORY_ITEM_INFO.get(str(item_id), {})
		var desc := str(info.get("desc", "Предмет із журналу завдань."))
		if str(item_id) == "atlas_piece":
			desc += "\n\nЗнайдено: %d / %d." % [QuestManager.get_map_piece_count(), AtlasPieces.total()]
			for pid in QuestManager.get_map_pieces():
				desc += "\n• %s — %s" % [AtlasPieces.piece_name(pid), str(AtlasPieces.PIECES[pid]["from"])]
		_items["story:" + str(item_id)] = {"name": QuestManager.get_item_name(str(item_id)), "icon": str(info.get("icon", "gem")), "section": "story",
			"count": amount, "state": "СЮЖЕТНИЙ ПРЕДМЕТ", "good": false,
			"desc": desc, "action": "ВИКОРИСТОВУЄТЬСЯ В КВЕСТАХ", "enabled": false}


func _refresh() -> void:
	if _root == null or _player() == null:
		return
	_collect()
	_slot_buttons.clear()
	for grid in [_weapon_grid, _consumable_grid, _story_grid]:
		for child in grid.get_children():
			grid.remove_child(child)
			child.queue_free()
	for key in _items.keys():
		var item: Dictionary = _items[key]
		var grid: GridContainer = _weapon_grid
		match str(item["section"]):
			"consumable": grid = _consumable_grid
			"story": grid = _story_grid
		grid.add_child(_make_slot(str(key), item))
	if _story_grid.get_child_count() == 0:
		var empty := _label("Сюжетних предметів поки немає.", 13, TEXT_DIM)
		_story_grid.add_child(empty)
	if not _items.has(_selected):
		_selected = "sword"
	_coins_label.text = "◈  Монети: %d" % int(main.get("score"))
	_update_stats()
	_update_detail()
	_apply_selection_styles()


func _make_slot(key: String, item: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(110.0, 110.0)
	button.focus_mode = Control.FOCUS_NONE
	var locked: bool = bool(item.get("locked", false))
	var good: bool = bool(item.get("good", false))
	var base_border := Color("#4a6a4e") if good else Color("#5a4a34")
	button.add_theme_stylebox_override("normal", _box_style(SLOT_BG, base_border, 3 if good else 2))
	button.add_theme_stylebox_override("hover", _box_style(Color(0.14, 0.11, 0.08), BORDER, 3))
	button.add_theme_stylebox_override("pressed", _box_style(Color(0.18, 0.14, 0.09), BORDER_SEL, 3))
	button.pressed.connect(_on_slot_pressed.bind(key))
	var icon := SlotIcon.new()
	icon.kind = str(item["icon"])
	icon.dim = locked
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 10.0
	icon.offset_right = -10.0
	icon.offset_top = 6.0
	icon.offset_bottom = -22.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	var name_label := _label(str(item["name"]), 10, TEXT_DIM if locked else TEXT)
	name_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.offset_top = -20.0
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(name_label)
	var count := int(item.get("count", -1))
	if count >= 0:
		var count_label := _label("×%d" % count, 17, Color("#f2d27a") if count > 0 else Color("#7a6a52"))
		count_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		count_label.offset_left = -50.0
		count_label.offset_top = 3.0
		count_label.offset_right = -6.0
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(count_label)
	if good and str(item["section"]) == "weapon" and key in ["sword", "bow"]:
		var tag := _label("● В РУЦІ", 9, Color("#8fd19a"))
		tag.position = Vector2(6.0, 3.0)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(tag)
	_slot_buttons[key] = button
	return button


func _apply_selection_styles() -> void:
	for key in _slot_buttons.keys():
		var button: Button = _slot_buttons[key]
		if str(key) == _selected:
			button.add_theme_stylebox_override("normal", _box_style(Color(0.16, 0.12, 0.08), BORDER_SEL, 4))


func _update_stats() -> void:
	var player := _player()
	var lines: Array[String] = []
	lines.append("Здоров'я:   %d / %d" % [int(player.get("health")), int(player.get("max_health"))])
	lines.append("Витривалість:   %d / %d" % [int(player.get("stamina")), int(player.get("max_stamina"))])
	lines.append("Меч:   рівень %d/3      Броня:   %d/4" % [int(player.get_meta("sword_level", 0)), int(player.get_meta("armor_level", 0))])
	lines.append("Нагрудник:   %d/2      Оберіг сил:   %d/2" % [int(player.get_meta("vitality_level", 0)), int(player.get_meta("stamina_level", 0))])
	lines.append("Обладунок:   %s" % ["лицарський гамбезон", "кольчуга (−12%)", "посилений латний (−24%)", "Попелястий лицарський (−38%)"][clampi(int(player.get_meta("armor_set", 0)), 0, 3)])
	if int(player.get_meta("bow_level", 0)) >= 1:
		lines.append("Тятива лука:   %d/3" % int(player.get_meta("bowdmg_level", 0)))
	if QuestManager.has_item("moon_lens"):
		lines.append("Місячна лінза:   +25% проти породжень Ока")
	_stats_label.text = "\n".join(lines)


func _update_detail() -> void:
	var item: Dictionary = _items.get(_selected, {})
	if item.is_empty():
		return
	_detail_icon.kind = str(item["icon"])
	_detail_icon.dim = bool(item.get("locked", false))
	_detail_icon.queue_redraw()
	_detail_title.text = str(item["name"]).to_upper()
	_detail_state.text = str(item["state"])
	_detail_state.add_theme_color_override("font_color", Color("#8fd19a") if bool(item.get("good", false)) else Color("#c9a977"))
	_detail_body.text = str(item["desc"])
	_action_button.text = str(item["action"])
	_action_button.disabled = not bool(item.get("enabled", false))


func _on_slot_pressed(key: String) -> void:
	_selected = key
	AudioManager.play_ui("ui_click")
	_refresh()


func _on_action_pressed() -> void:
	var player := _player()
	if player == null:
		return
	var bow: Object = player.get("bow")
	match _selected:
		"sword":
			var sword_out: bool = bool(player.get("weapon_drawn")) and not (bow != null and bool(bow.get("equipped")))
			player.call("set_weapon_drawn", not sword_out)
		"bow":
			if bow != null:
				bow.call("toggle_equip")
		"light":
			var fx: Object = player.get("fx")
			if fx != null:
				fx.call("toggle_light")
		"potion", "fire", "ward":
			extras.call("_use_item", _selected)
	_refresh()


## Піктограма слота: малюється кодом у стилі PSX (плоскі кольори, темні контури).
class SlotIcon extends Control:
	var kind: String = "gem"
	var dim: bool = false

	func _draw() -> void:
		var s := minf(size.x, size.y)
		if s <= 1.0:
			return
		var u := s / 100.0
		var tint := Color(0.4, 0.4, 0.4, 1.0) if dim else Color.WHITE
		draw_set_transform(size * 0.5, 0.0, Vector2.ONE)
		var ink := Color(0.05, 0.035, 0.03) * tint
		match kind:
			"sword":
				draw_set_transform(size * 0.5, -0.72, Vector2.ONE)
				draw_rect(Rect2(-5 * u, -42 * u, 10 * u, 64 * u), Color("#aeb4c0") * tint)
				draw_colored_polygon(PackedVector2Array([Vector2(-5 * u, -42 * u), Vector2(5 * u, -42 * u), Vector2(0, -54 * u)]), Color("#d8dde6") * tint)
				draw_rect(Rect2(-5 * u, -42 * u, 10 * u, 64 * u), ink, false, 2.0)
				draw_rect(Rect2(-18 * u, 20 * u, 36 * u, 7 * u), Color("#c29a58") * tint)
				draw_rect(Rect2(-18 * u, 20 * u, 36 * u, 7 * u), ink, false, 2.0)
				draw_rect(Rect2(-4 * u, 27 * u, 8 * u, 18 * u), Color("#5a3a22") * tint)
				draw_circle(Vector2(0, 48 * u), 5 * u, Color("#c29a58") * tint)
			"bow":
				var wood := Color("#7a4e2c") * tint
				var center := Vector2(14 * u, 0)
				draw_arc(center, 44 * u, PI * 0.62, PI * 1.38, 18, wood, 7 * u, true)
				var p1 := center + Vector2(cos(PI * 0.62), sin(PI * 0.62)) * 44 * u
				var p2 := center + Vector2(cos(PI * 1.38), sin(PI * 1.38)) * 44 * u
				draw_line(p1, p2, Color("#d8cfae") * tint, 2.0)
				draw_line(Vector2(-14 * u, 0), Vector2(40 * u, 0), Color("#8a6a42") * tint, 3.0)
				draw_colored_polygon(PackedVector2Array([Vector2(40 * u, -5 * u), Vector2(52 * u, 0), Vector2(40 * u, 5 * u)]), Color("#aeb4c0") * tint)
				draw_colored_polygon(PackedVector2Array([Vector2(-14 * u, 0), Vector2(-24 * u, -6 * u), Vector2(-18 * u, 0), Vector2(-24 * u, 6 * u)]), Color("#a83b2c") * tint)
			"arrows":
				draw_set_transform(size * 0.5, -0.6, Vector2.ONE)
				for k in range(3):
					var x := float(k - 1) * 17 * u
					draw_line(Vector2(x, 38 * u), Vector2(x, -34 * u), Color("#a88a5a") * tint, 4.0)
					draw_colored_polygon(PackedVector2Array([Vector2(x - 6 * u, -32 * u), Vector2(x + 6 * u, -32 * u), Vector2(x, -48 * u)]), Color("#aeb4c0") * tint)
					draw_colored_polygon(PackedVector2Array([Vector2(x, 38 * u), Vector2(x - 8 * u, 50 * u), Vector2(x, 44 * u), Vector2(x + 8 * u, 50 * u)]), Color("#a83b2c") * tint)
			"potion":
				draw_circle(Vector2(0, 14 * u), 28 * u, Color("#b02a3a") * tint)
				draw_arc(Vector2(0, 14 * u), 28 * u, 0.0, TAU, 20, ink, 3.0, true)
				draw_rect(Rect2(-9 * u, -34 * u, 18 * u, 24 * u), Color("#9fb4b8") * tint)
				draw_rect(Rect2(-9 * u, -34 * u, 18 * u, 24 * u), ink, false, 2.0)
				draw_rect(Rect2(-11 * u, -42 * u, 22 * u, 9 * u), Color("#7a5a3a") * tint)
				draw_circle(Vector2(-10 * u, 6 * u), 6 * u, Color(1, 0.7, 0.7, 0.45) * tint)
			"oil":
				draw_circle(Vector2(0, 14 * u), 26 * u, Color("#c88a3c") * tint)
				draw_arc(Vector2(0, 14 * u), 26 * u, 0.0, TAU, 20, ink, 3.0, true)
				draw_rect(Rect2(-7 * u, -30 * u, 14 * u, 22 * u), Color("#c8b890") * tint)
				draw_rect(Rect2(-9 * u, -38 * u, 18 * u, 8 * u), Color("#6a4a2a") * tint)
			"scroll_fire", "scroll_ward", "note":
				draw_rect(Rect2(-30 * u, -34 * u, 60 * u, 68 * u), Color("#d8c8a0") * tint)
				draw_rect(Rect2(-30 * u, -34 * u, 60 * u, 68 * u), ink, false, 2.0)
				draw_rect(Rect2(-36 * u, -40 * u, 72 * u, 10 * u), Color("#a88a5a") * tint)
				draw_rect(Rect2(-36 * u, 30 * u, 72 * u, 10 * u), Color("#a88a5a") * tint)
				if kind == "scroll_fire":
					draw_colored_polygon(PackedVector2Array([Vector2(0, -22 * u), Vector2(14 * u, 6 * u), Vector2(0, 22 * u), Vector2(-14 * u, 6 * u), Vector2(-6 * u, -4 * u)]), Color("#e8742a") * tint)
					draw_colored_polygon(PackedVector2Array([Vector2(0, -6 * u), Vector2(7 * u, 8 * u), Vector2(0, 18 * u), Vector2(-7 * u, 8 * u)]), Color("#f6c84a") * tint)
				elif kind == "scroll_ward":
					draw_arc(Vector2(0, 0), 18 * u, 0.0, TAU, 24, Color("#4a78d8") * tint, 5.0, true)
					draw_circle(Vector2(0, 0), 7 * u, Color("#9ab8ff") * tint)
			"torch":
				draw_set_transform(size * 0.5, 0.35, Vector2.ONE)
				draw_rect(Rect2(-6 * u, -6 * u, 12 * u, 60 * u), Color("#5a3a22") * tint)
				draw_rect(Rect2(-6 * u, -6 * u, 12 * u, 60 * u), ink, false, 2.0)
				draw_colored_polygon(PackedVector2Array([Vector2(-14 * u, -6 * u), Vector2(14 * u, -6 * u), Vector2(8 * u, -16 * u), Vector2(-8 * u, -16 * u)]), Color("#3a3c41") * tint)
				draw_colored_polygon(PackedVector2Array([Vector2(0, -52 * u), Vector2(14 * u, -28 * u), Vector2(8 * u, -16 * u), Vector2(-8 * u, -16 * u), Vector2(-14 * u, -28 * u)]), Color("#e8742a") * tint)
				draw_colored_polygon(PackedVector2Array([Vector2(0, -38 * u), Vector2(7 * u, -24 * u), Vector2(0, -16 * u), Vector2(-7 * u, -24 * u)]), Color("#f6c84a") * tint)
			"lantern":
				draw_arc(Vector2(0, -26 * u), 16 * u, PI, TAU, 12, Color("#3a3c41") * tint, 4.0, true)
				draw_rect(Rect2(-18 * u, -26 * u, 36 * u, 6 * u), Color("#3a3c41") * tint)
				draw_rect(Rect2(-16 * u, -20 * u, 32 * u, 46 * u), Color("#ffb050") * tint)
				draw_rect(Rect2(-16 * u, -20 * u, 32 * u, 46 * u), ink, false, 3.0)
				draw_line(Vector2(0, -20 * u), Vector2(0, 26 * u), ink, 2.0)
				draw_rect(Rect2(-20 * u, 26 * u, 40 * u, 8 * u), Color("#3a3c41") * tint)
			"shield":
				var pts := PackedVector2Array([Vector2(-34 * u, -38 * u), Vector2(34 * u, -38 * u), Vector2(34 * u, 4 * u), Vector2(0, 46 * u), Vector2(-34 * u, 4 * u)])
				draw_colored_polygon(pts, Color("#5a4a3a") * tint)
				draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[0]]), Color("#aeb4c0") * tint, 4.0)
				draw_circle(Vector2(0, -4 * u), 11 * u, Color("#c29a58") * tint)
				draw_arc(Vector2(0, -4 * u), 11 * u, 0.0, TAU, 14, ink, 2.0, true)
				draw_line(Vector2(0, -38 * u), Vector2(0, 40 * u), Color("#3a2e24") * tint, 3.0)
			"fragment_red", "fragment_violet", "fragment_gold":
				var col := Color("#e8503a") if kind == "fragment_red" else (Color("#a070e0") if kind == "fragment_violet" else Color("#e8c050"))
				var shard := PackedVector2Array([Vector2(-6 * u, -42 * u), Vector2(22 * u, -20 * u), Vector2(30 * u, 14 * u), Vector2(8 * u, 40 * u), Vector2(-24 * u, 28 * u), Vector2(-32 * u, -6 * u)])
				draw_colored_polygon(shard, col * tint)
				draw_polyline(PackedVector2Array([shard[0], shard[1], shard[2], shard[3], shard[4], shard[5], shard[0]]), ink, 3.0)
				draw_line(Vector2(-6 * u, -42 * u), Vector2(2 * u, 6 * u), ink, 2.0)
				draw_line(Vector2(2 * u, 6 * u), Vector2(30 * u, 14 * u), ink, 2.0)
				draw_line(Vector2(2 * u, 6 * u), Vector2(-24 * u, 28 * u), ink, 2.0)
			"atlas":
				var piece := PackedVector2Array([Vector2(-34 * u, -30 * u), Vector2(-8 * u, -38 * u), Vector2(6 * u, -28 * u), Vector2(30 * u, -36 * u), Vector2(36 * u, -6 * u), Vector2(28 * u, 10 * u), Vector2(34 * u, 34 * u), Vector2(4 * u, 38 * u), Vector2(-12 * u, 28 * u), Vector2(-36 * u, 34 * u), Vector2(-30 * u, 4 * u)])
				draw_colored_polygon(piece, Color("#d8bc84") * tint)
				draw_polyline(piece + PackedVector2Array([piece[0]]), ink, 3.0)
				draw_polyline(PackedVector2Array([Vector2(-26 * u, 18 * u), Vector2(-8 * u, 4 * u), Vector2(10 * u, 10 * u), Vector2(26 * u, -14 * u)]), Color("#7a2a18") * tint, 2.5)
				draw_line(Vector2(-14 * u, -18 * u), Vector2(-4 * u, -8 * u), Color("#5a3a20") * tint, 2.0)
				draw_line(Vector2(-4 * u, -18 * u), Vector2(-14 * u, -8 * u), Color("#5a3a20") * tint, 2.0)
			"herb":
				for k in range(3):
					var a := -0.7 + float(k) * 0.7
					draw_set_transform(size * 0.5 + Vector2(0, 30 * u), a, Vector2.ONE)
					draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(-9 * u, -34 * u), Vector2(0, -62 * u), Vector2(9 * u, -34 * u)]), Color("#5a9a4a") * tint)
					draw_line(Vector2(0, 0), Vector2(0, -56 * u), ink, 2.0)
			"crate":
				draw_rect(Rect2(-34 * u, -28 * u, 68 * u, 60 * u), Color("#7a5a3a") * tint)
				draw_rect(Rect2(-34 * u, -28 * u, 68 * u, 60 * u), ink, false, 3.0)
				draw_line(Vector2(-34 * u, -8 * u), Vector2(34 * u, -8 * u), ink, 2.0)
				draw_line(Vector2(-34 * u, 12 * u), Vector2(34 * u, 12 * u), ink, 2.0)
				draw_line(Vector2(-34 * u, -28 * u), Vector2(34 * u, 32 * u), Color("#4a3a26") * tint, 3.0)
			"shard":
				draw_colored_polygon(PackedVector2Array([Vector2(0, -44 * u), Vector2(18 * u, -4 * u), Vector2(6 * u, 40 * u), Vector2(-14 * u, 18 * u), Vector2(-18 * u, -14 * u)]), Color("#9ab8ff") * tint)
				draw_polyline(PackedVector2Array([Vector2(0, -44 * u), Vector2(18 * u, -4 * u), Vector2(6 * u, 40 * u), Vector2(-14 * u, 18 * u), Vector2(-18 * u, -14 * u), Vector2(0, -44 * u)]), ink, 3.0)
				draw_line(Vector2(0, -44 * u), Vector2(-2 * u, 20 * u), Color(1, 1, 1, 0.6) * tint, 2.0)
			"gem_blue":
				var gem := PackedVector2Array([Vector2(0, -42 * u), Vector2(30 * u, -8 * u), Vector2(0, 42 * u), Vector2(-30 * u, -8 * u)])
				draw_colored_polygon(gem, Color("#7aa8ff") * tint)
				draw_polyline(PackedVector2Array([gem[0], gem[1], gem[2], gem[3], gem[0]]), ink, 3.0)
				draw_line(Vector2(-30 * u, -8 * u), Vector2(30 * u, -8 * u), ink, 2.0)
				draw_colored_polygon(PackedVector2Array([Vector2(0, -42 * u), Vector2(30 * u, -8 * u), Vector2(0, -8 * u)]), Color("#c8dcff") * tint)
			_:
				var d := PackedVector2Array([Vector2(0, -38 * u), Vector2(28 * u, 0), Vector2(0, 38 * u), Vector2(-28 * u, 0)])
				draw_colored_polygon(d, Color("#c29a58") * tint)
				draw_polyline(PackedVector2Array([d[0], d[1], d[2], d[3], d[0]]), ink, 3.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
