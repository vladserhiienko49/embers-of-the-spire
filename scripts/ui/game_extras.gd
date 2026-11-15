class_name GameExtras
extends Node
## Доповнення до main.gd: магазини (коваль / алхімік / торговець), витратні предмети (клавіші 1–3),
## екран смерті гравця та фінальна кінематографічна сцена зі світанком.

const SHOPS: Dictionary = {
	"blacksmith": {
		"title": "КАТАЛАН — КУЗНЯ",
		"greeting": "Сталь не прощає недбальства. Залиш монети — і я зроблю з твого заліза щось гідне Чорної Гори.",
		"items": [
			{"id": "sword", "kind": "sword", "name": "Загартувати меч", "desc": "+9 до шкоди (рівень %d/3)", "price": [40, 80, 140]},
			{"id": "armor", "kind": "armor", "name": "Підсилити броню", "desc": "−7%% отриманої шкоди (рівень %d/4)", "price": [35, 70, 110, 160]},
			{"id": "chain", "kind": "chain", "tier": 1, "name": "Кольчуга", "desc": "Комплект обладунку: −12% отриманої шкоди", "price": [180]},
			{"id": "plate", "kind": "plate", "tier": 2, "name": "Посилений латний обладунок", "desc": "Потрібна кольчуга. −24% шкоди, синя гартована сталь", "price": [420]},
			{"id": "legend", "kind": "legend", "tier": 3, "name": "Попелястий Лицарський Обладунок", "desc": "Рідкісний, потрібен латний обладунок. −38% шкоди, золото з жаром. Лише один комплект", "price": [1100]},
			{"id": "vitality", "kind": "vitality", "name": "Нагрудник із кованої сталі", "desc": "+20 до здоров'я (рівень %d/2)", "price": [90, 150]},
		],
	},
	"mage": {
		"title": "ВАЛЬМЕР — АЛХІМІК",
		"greeting": "Зілля пахнуть погано, зате діють. Сувої — на крайній випадок: вони горять швидше, ніж я їх пишу.",
		"items": [
			{"id": "potion", "kind": "potion", "name": "Зілля лікування  [1]", "desc": "Відновлює 55 здоров'я", "price": [15]},
			{"id": "fire", "kind": "fire", "name": "Сувій Вогню  [2]", "desc": "Спалює ворогів навколо (80 шкоди)", "price": [30]},
			{"id": "ward", "kind": "ward", "name": "Сувій Оберега  [3]", "desc": "8 секунд невразливості", "price": [25]},
		],
	},
	"archer": {
		"title": "ЛІРА — ЧАРОДІЙКА-ЛУЧНИЦЯ",
		"greeting": "Місячне дерево, жила дракона замість тятиви. Куплений лук дістається клавішею B, а стріли — тільки в мене.",
		"items": [
			{"id": "bow", "kind": "bow", "name": "Місячний лук  [B]", "desc": "Дальня зброя: ЛКМ — натягнути, відпустити — вистрілити. У комплекті 25 стріл", "price": [70]},
			{"id": "arrows", "kind": "arrows", "name": "Пучок стріл ×15", "desc": "Боєприпаси для лука", "price": [14]},
			{"id": "bowdmg", "kind": "bowdmg", "name": "Підсилена тятива", "desc": "+7 до шкоди стріл (рівень %d/3)", "price": [60, 100, 160]},
		],
	},
	"merchant": {
		"title": "БРУНО — ТОРГОВЕЦЬ",
		"greeting": "Усе, що пережило дорогу. Ціни чесні, бо інших покупців тут не лишилося.",
		"items": [
			{"id": "potion", "kind": "potion", "name": "Зілля лікування  [1]", "desc": "Відновлює 55 здоров'я", "price": [18]},
			{"id": "stamina", "kind": "stamina", "name": "Оберіг витривалості", "desc": "+20 до витривалості (рівень %d/2)", "price": [60, 110]},
			{"id": "ward", "kind": "ward", "name": "Сувій Оберега  [3]", "desc": "8 секунд невразливості", "price": [30]},
		],
	},
}

var main: Node = null
var consumables: Dictionary = {"potion": 0, "fire": 0, "ward": 0}

var _hud_layer: CanvasLayer
var _hud_panel: PanelContainer
var _hud_label: Label
var _shop_layer: CanvasLayer
var _shop_root: Control
var _shop_title: Label
var _shop_coins: Label
var _shop_body: Label
var _shop_list: VBoxContainer
var _shop_id: String = ""
var _death_layer: CanvasLayer = null
var _death_buttons: VBoxContainer = null

# Фінал
var _fin_cam: Camera3D = null
var _fin_t: float = -1.0
var _fin_center: Vector3 = Vector3.ZERO
var _fin_sun_flat: Vector3 = Vector3(-0.62, 0.0, -0.77)
var _fin_base_az: float = 0.0
var _fin_faded: bool = false
const FINALE_LENGTH: float = 92.0


func setup(main_node: Node) -> void:
	main = main_node
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()
	_build_shop_ui()
	inventory = InventoryScreen.new()
	inventory.name = "InventoryScreen"
	add_child(inventory)
	inventory.setup(main, self)
	cards = CardGame.new()
	cards.name = "CardGame"
	add_child(cards)
	cards.setup(main)
	map_scene = MapFragmentScene.new()
	map_scene.name = "MapFragmentScene"
	add_child(map_scene)
	map_scene.setup(main)
	var player: Node = main.get("player")
	if player and player.has_signal("died"):
		player.connect("died", show_death)
	QuestManager.coins_earned.connect(_on_coins_earned)


# --- Монети ----------------------------------------------------------------------------

func _on_coins_earned(amount: int, reason: String) -> void:
	main.set("score", int(main.get("score")) + amount)
	main.call("_update_score")
	AudioManager.play_sfx("coin", -3.0, 0.05)
	var player: Node = main.get("player")
	if player and player.has_signal("combat_message"):
		player.emit_signal("combat_message", "+%d монет  •  %s" % [amount, reason.capitalize() if reason.length() < 3 else reason], true)


# --- HUD витратних предметів ---------------------------------------------------------------

func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 5
	add_child(_hud_layer)
	_hud_panel = PanelContainer.new()
	_hud_panel.add_theme_stylebox_override("panel", main.call("_make_compact_style", 0.4))
	_hud_panel.anchor_left = 0.5
	_hud_panel.anchor_right = 0.5
	_hud_panel.anchor_top = 1.0
	_hud_panel.anchor_bottom = 1.0
	_hud_panel.offset_left = -170.0
	_hud_panel.offset_right = 170.0
	_hud_panel.offset_top = -66.0
	_hud_panel.offset_bottom = -10.0
	_hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(_hud_panel)
	# Компактна швидка панель: піктограми з кількістю замість довгого текстового рядка.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_panel.add_child(row)
	for entry in [["1", "potion"], ["2", "scroll_fire"], ["3", "scroll_ward"], ["B", "arrows"]]:
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(52.0, 44.0)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(slot)
		var icon := InventoryScreen.SlotIcon.new()
		icon.kind = str(entry[1])
		icon.position = Vector2(6.0, 0.0)
		icon.size = Vector2(34.0, 34.0)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		var key_label := Label.new()
		key_label.text = str(entry[0])
		key_label.add_theme_font_size_override("font_size", 10)
		key_label.add_theme_color_override("font_color", Color("#c9a977"))
		key_label.position = Vector2(0.0, 24.0)
		slot.add_child(key_label)
		var count_label := Label.new()
		count_label.add_theme_font_size_override("font_size", 13)
		count_label.add_theme_color_override("font_color", Color("#f2d27a"))
		count_label.position = Vector2(30.0, 22.0)
		slot.add_child(count_label)
		_quick_slots[str(entry[1])] = {"root": slot, "count": count_label, "icon": icon}
	_hud_label = Label.new()
	_hud_label.text = "I"
	_hud_label.add_theme_font_size_override("font_size", 11)
	_hud_label.add_theme_color_override("font_color", Color("#9f9684"))
	_hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_label.text = "[I] СУМКА"
	_hud_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_hud_label)


var _quick_slots: Dictionary = {}
var inventory: InventoryScreen = null
var cards: CardGame = null
var map_scene: MapFragmentScene = null


func open_inventory() -> void:
	if inventory and str(main.get("current_screen")) == "game" and bool(main.get("game_started")):
		inventory.open()


func close_inventory() -> void:
	if inventory:
		inventory.close()


func _process(_delta: float) -> void:
	if main == null:
		return
	var in_game: bool = str(main.get("current_screen")) == "game" and bool(main.get("game_started"))
	if _hud_panel:
		_hud_panel.visible = in_game
		var hud_player := main.get("player") as Node
		var counts := {"potion": int(consumables["potion"]), "scroll_fire": int(consumables["fire"]), "scroll_ward": int(consumables["ward"]), "arrows": 0}
		var has_bow := false
		if hud_player:
			has_bow = int(hud_player.get_meta("bow_level", 0)) >= 1
			counts["arrows"] = int(hud_player.get_meta("arrows", 0))
		for key in _quick_slots.keys():
			var q: Dictionary = _quick_slots[key]
			var slot_root := q["root"] as Control
			slot_root.visible = key != "arrows" or has_bow
			(q["count"] as Label).text = "×%d" % int(counts[key])
			(q["icon"] as InventoryScreen.SlotIcon).dim = int(counts[key]) <= 0
			(q["icon"] as InventoryScreen.SlotIcon).queue_redraw()
	if _fin_t >= 0.0:
		_step_finale(_delta)


func _unhandled_input(event: InputEvent) -> void:
	if main == null or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_I:
		if inventory and inventory.is_open():
			inventory.close()
			get_viewport().set_input_as_handled()
		elif str(main.get("current_screen")) == "game" and bool(main.get("game_started")):
			open_inventory()
			get_viewport().set_input_as_handled()
		return
	if str(main.get("current_screen")) != "game" or not bool(main.get("game_started")):
		return
	match key.keycode:
		KEY_1: _use_item("potion")
		KEY_2: _use_item("fire")
		KEY_3: _use_item("ward")


func _use_item(kind: String) -> void:
	var player: Node = main.get("player")
	if player == null or bool(player.call("is_defeated")) or int(consumables.get(kind, 0)) <= 0:
		if player:
			player.emit_signal("combat_message", "Немає такого предмета.", false)
		return
	match kind:
		"potion":
			if float(player.get("health")) >= float(player.get("max_health")) - 0.5:
				player.emit_signal("combat_message", "Здоров'я й так повне.", false)
				return
			player.call("heal", 55.0)
			var wg = main.get("world_generator")
			if wg and wg.hazards:
				wg.hazards.cure_poison()
			player.emit_signal("combat_message", "Зілля лікування: +55 здоров'я", true)
			AudioManager.play_ui("quest_progress")
		"fire":
			_fire_burst(player as Node3D)
		"ward":
			player.call("grant_invulnerability", 8.0)
			player.emit_signal("combat_message", "Оберіг: 8 секунд невразливості", true)
			AudioManager.play_ui("discover")
			_flash_light(player as Node3D, Color("#7aa8ff"), 3.0, 8.0)
	consumables[kind] = int(consumables[kind]) - 1


func _flash_light(at: Node3D, color: Color, energy: float, seconds: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 9.0
	light.shadow_enabled = false
	at.add_child(light)
	light.position = Vector3(0.0, 1.2, 0.0)
	var tween := create_tween()
	tween.tween_property(light, "light_energy", 0.0, seconds)
	tween.tween_callback(light.queue_free)


func _fire_burst(at: Node3D) -> void:
	_flash_light(at, Color("#ff7a30"), 7.0, 1.2)
	AudioManager.play_ui("torch_on")
	var hits := 0
	for enemy in get_tree().get_nodes_in_group("hostile"):
		var body := enemy as Node3D
		if body and not bool(body.get("dead")) and body.global_position.distance_to(at.global_position) < 11.0 and body.has_method("take_damage"):
			body.call("take_damage", 80.0, at)
			hits += 1
	var ring := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	ring.mesh = sphere
	ring.material_override = PSXMaterials.make(Color("#ff8a3a"), 0.0, 0.5, Color("#ff6a20"), 3.0, "none", false)
	ring.scale = Vector3.ONE * 0.5
	at.get_parent().add_child(ring)
	ring.global_position = at.global_position + Vector3(0.0, 1.0, 0.0)
	var grow := create_tween()
	grow.tween_property(ring, "scale", Vector3.ONE * 9.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	grow.tween_callback(ring.queue_free)
	at.emit_signal("combat_message", "Сувій Вогню: уражено ворогів — %d" % hits, true)


# --- Магазин ---------------------------------------------------------------------------------

func _build_shop_ui() -> void:
	_shop_layer = CanvasLayer.new()
	_shop_layer.layer = 36
	add_child(_shop_layer)
	_shop_root = Control.new()
	_shop_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shop_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_shop_root.visible = false
	_shop_layer.add_child(_shop_root)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.3)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shop_root.add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = -600.0
	panel.offset_right = -30.0
	panel.add_theme_stylebox_override("panel", main.call("_make_hud_style"))
	_shop_root.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	_shop_title = Label.new()
	_shop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_title.add_theme_font_size_override("font_size", 26)
	_shop_title.add_theme_color_override("font_color", Color("#e4c18a"))
	column.add_child(_shop_title)
	_shop_coins = Label.new()
	_shop_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_coins.add_theme_font_size_override("font_size", 18)
	_shop_coins.add_theme_color_override("font_color", Color("#f2d27a"))
	column.add_child(_shop_coins)
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0.0, 2.0)
	divider.color = Color("#927044")
	column.add_child(divider)
	_shop_body = Label.new()
	_shop_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shop_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_body.custom_minimum_size = Vector2(500.0, 0.0)
	_shop_body.add_theme_font_size_override("font_size", 15)
	_shop_body.add_theme_color_override("font_color", Color("#e9e1d4"))
	column.add_child(_shop_body)
	_shop_list = VBoxContainer.new()
	_shop_list.add_theme_constant_override("separation", 8)
	column.add_child(_shop_list)
	var close := Button.new()
	close.text = "ПІТИ  •  ESC"
	close.flat = true
	close.custom_minimum_size = Vector2(0.0, 34.0)
	close.add_theme_color_override("font_color", Color("#b9b2a7"))
	close.pressed.connect(close_shop)
	column.add_child(close)


func is_shop_open() -> bool:
	return _shop_root != null and _shop_root.visible


func open_shop(shop_id: String) -> void:
	if not SHOPS.has(shop_id):
		return
	_shop_id = shop_id
	main.set("current_screen", "shop")
	main.call("_set_player_controls", false)
	var data: Dictionary = SHOPS[shop_id]
	_shop_title.text = str(data["title"])
	_shop_body.text = str(data["greeting"])
	_rebuild_shop()
	_shop_root.visible = true
	_shop_root.modulate.a = 0.0
	create_tween().tween_property(_shop_root, "modulate:a", 1.0, 0.2)
	AudioManager.play_ui("dialogue_open")


func close_shop() -> void:
	if not is_shop_open():
		return
	_shop_root.visible = false
	_shop_id = ""
	AudioManager.play_ui("ui_back")
	main.call("_close_world_dialogue")


func _level_of(kind: String) -> int:
	var player: Node = main.get("player")
	if player == null:
		return 0
	return int(player.get_meta(kind + "_level", 0))


func _item_price(item: Dictionary) -> int:
	## -1 — досягнуто максимального рівня.
	var prices: Array = item["price"]
	var kind := str(item["kind"])
	if kind in ["chain", "plate", "legend"]:
		# Комплекти обладунків: купуються по черзі й лише раз. -1 — вже куплено, -2 — потрібен попередній.
		var tier := int(item["tier"])
		var owned := int((main.get("player") as Node).get_meta("armor_set", 0))
		if owned >= tier:
			return -1
		return -2 if owned < tier - 1 else int(prices[0])
	if kind in ["sword", "armor", "vitality", "stamina", "bow", "bowdmg"]:
		var level := _level_of(kind)
		return -1 if level >= prices.size() else int(prices[level])
	return int(prices[0])


func _rebuild_shop() -> void:
	_shop_coins.text = "◈  Монети: %d" % int(main.get("score"))
	for child in _shop_list.get_children():
		_shop_list.remove_child(child)
		child.queue_free()
	var data: Dictionary = SHOPS[_shop_id]
	for item in data["items"]:
		var kind := str(item["kind"])
		var price := _item_price(item)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_shop_list.add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var name_label := Label.new()
		name_label.text = str(item["name"])
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.add_theme_color_override("font_color", Color("#f0e4ce"))
		info.add_child(name_label)
		var desc_label := Label.new()
		var desc := str(item["desc"])
		if "%d" in desc:
			desc = desc % _level_of(kind)
		elif kind in ["potion", "fire", "ward"]:
			desc += "   (у сумці: %d)" % int(consumables.get(kind, 0))
		elif kind == "arrows":
			desc += "   (у сагайдаку: %d)" % int((main.get("player") as Node).get_meta("arrows", 0))
		desc_label.text = desc
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.add_theme_color_override("font_color", Color("#a99f8c"))
		info.add_child(desc_label)
		var label_text := "КУПИТИ  %d" % price
		if price == -1:
			label_text = "КУПЛЕНО" if kind in ["chain", "plate", "legend"] else "МАКС."
		elif price == -2:
			label_text = "ПОТРІБЕН ПОПЕРЕДНІЙ"
		var button: Button = main.call("_make_oath_button", label_text, Color("#342b21"), Color("#9f7b4d"))
		button.custom_minimum_size = Vector2(150.0, 46.0)
		button.disabled = price < 0
		if price >= 0:
			button.pressed.connect(_buy.bind(str(item["id"])))
		row.add_child(button)


func _buy(item_id: String) -> void:
	var data: Dictionary = SHOPS[_shop_id]
	for item in data["items"]:
		if str(item["id"]) != item_id:
			continue
		var price := _item_price(item)
		var score := int(main.get("score"))
		if price < 0:
			return
		if score < price:
			AudioManager.play_ui("ui_back")
			_shop_body.text = "Бракує %d монет. Повертайся, коли розживешся." % (price - score)
			return
		main.set("score", score - price)
		main.call("_update_score")
		_apply_purchase(str(item["kind"]))
		AudioManager.play_ui("quest_accept")
		_shop_body.text = "Домовились. Бережи себе."
		_rebuild_shop()
		return


func _apply_purchase(kind: String) -> void:
	var player: Node = main.get("player")
	match kind:
		"bow":
			player.set_meta("bow_level", 1)
			player.set_meta("arrows", int(player.get_meta("arrows", 0)) + 25)
			player.emit_signal("combat_message", "Ти отримав Місячний лук і 25 стріл. Натисни B, щоб дістати його.", true)
		"chain", "plate", "legend":
			var tier := 1 if kind == "chain" else (2 if kind == "plate" else 3)
			player.set_meta("armor_set", tier)
			KnightArmor.apply_tier(tier)
			player.emit_signal("combat_message", "Новий обладунок надіто: захист зріс.", true)
		"arrows":
			player.set_meta("arrows", int(player.get_meta("arrows", 0)) + 15)
		"sword", "armor", "vitality", "stamina", "bowdmg":
			player.set_meta(kind + "_level", _level_of(kind) + 1)
			if kind == "vitality":
				player.set("max_health", float(player.get("max_health")) + 20.0)
				player.call("heal", 20.0)
			elif kind == "stamina":
				player.set("max_stamina", float(player.get("max_stamina")) + 20.0)
				player.call("notify_stats")
			elif kind == "sword":
				main.call("_apply_weapon_tempering")
		_:
			consumables[kind] = int(consumables.get(kind, 0)) + 1


func _input(event: InputEvent) -> void:
	if is_shop_open() and event.is_action_pressed("ui_cancel"):
		close_shop()
		get_viewport().set_input_as_handled()


# --- Екран смерті ------------------------------------------------------------------------------

func show_death() -> void:
	if _death_layer != null:
		return
	main.set("current_screen", "dead")
	_death_layer = CanvasLayer.new()
	_death_layer.layer = 55
	add_child(_death_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_death_layer.add_child(root)

	var dark := ColorRect.new()
	dark.color = Color(0.0, 0.0, 0.0, 0.0)
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dark)
	var blood := ColorRect.new()
	blood.color = Color(0.25, 0.0, 0.0, 0.0)
	blood.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(blood)

	var title := Label.new()
	title.text = "ВИ ЗАГИНУЛИ"
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.grow_vertical = Control.GROW_DIRECTION_BOTH
	title.offset_top = -120.0
	title.offset_bottom = 0.0
	title.offset_left = -500.0
	title.offset_right = 500.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 92)
	title.add_theme_color_override("font_color", Color("#9a1010"))
	title.add_theme_color_override("font_outline_color", Color("#1a0000"))
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	title.add_theme_constant_override("shadow_offset_y", 5)
	title.modulate.a = 0.0
	root.add_child(title)

	var sub := Label.new()
	sub.text = "Попіл не відпускає тих, хто ще не завершив свій шлях."
	sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	sub.offset_left = -400.0
	sub.offset_right = 400.0
	sub.offset_top = 16.0
	sub.offset_bottom = 56.0
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 17)
	sub.add_theme_color_override("font_color", Color("#9c8f86"))
	sub.modulate.a = 0.0
	root.add_child(sub)

	_death_buttons = VBoxContainer.new()
	_death_buttons.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_death_buttons.offset_left = -190.0
	_death_buttons.offset_right = 190.0
	_death_buttons.offset_top = 96.0
	_death_buttons.offset_bottom = 230.0
	_death_buttons.add_theme_constant_override("separation", 12)
	_death_buttons.modulate.a = 0.0
	_death_buttons.visible = false
	root.add_child(_death_buttons)
	var respawn_button: Button = main.call("_make_oath_button", "ВІДРОДИТИСЯ БІЛЯ ВОГНИЩА", Color("#2a1613"), Color("#8f2a22"))
	respawn_button.pressed.connect(_respawn)
	_death_buttons.add_child(respawn_button)
	var menu_button: Button = main.call("_make_oath_button", "ГОЛОВНЕ МЕНЮ", Color("#242120"), Color("#6b625a"))
	menu_button.pressed.connect(_death_to_menu)
	_death_buttons.add_child(menu_button)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var show := create_tween()
	show.set_parallel(true)
	show.tween_property(dark, "color:a", 0.86, 1.6)
	show.tween_property(blood, "color:a", 0.22, 1.2)
	show.tween_property(title, "modulate:a", 1.0, 1.8).set_delay(0.6)
	show.tween_property(sub, "modulate:a", 1.0, 1.5).set_delay(1.6)
	show.chain().tween_callback(func() -> void:
		if _death_buttons != null and is_instance_valid(_death_buttons):
			_death_buttons.visible = true
			create_tween().tween_property(_death_buttons, "modulate:a", 1.0, 0.7)
	)
	AudioManager.play_ui("quest_complete", -8.0)


func _respawn() -> void:
	var player: Node = main.get("player")
	var world: Node = main.get("world_generator")
	if player == null or world == null or _death_layer == null:
		return
	var lost := int(float(int(main.get("score"))) * 0.3)
	main.set("score", int(main.get("score")) - lost)
	main.call("_update_score")
	var spot: Vector3 = world.call("get_respawn_world_position")
	player.call("respawn_at", spot)
	_death_layer.queue_free()
	_death_layer = null
	_death_buttons = null
	main.set("current_screen", "game")
	main.call("_set_player_controls", true)
	AudioManager.play_ui("quest_accept")
	var where := "Вогнище Села Попелу зігріло тебе знову."
	if str(world.get("checkpoint_label")) != "" and not bool(world.get("player_in_dungeon")):
		where = str(world.get("checkpoint_label")) + ". Ти не втратив прогрес."
	main.call("_show_story_toast", "ТИ ВІДРОДИВСЯ", "%s%s" % [where, "\nВтрачено монет: %d." % lost if lost > 0 else ""], 5.0)
	if world.get("trials"):
		world.trials.on_player_respawn()


func _death_to_menu() -> void:
	QuestManager.reset_all()
	AudioManager.stop_finale(0.2)
	get_tree().reload_current_scene()


# --- Фінал: світанок над звільненим світом ----------------------------------------------------------

func play_finale() -> void:
	if _fin_t >= 0.0:
		return
	var world: Node3D = main.get("world_generator")
	var player: Node3D = main.get("player")
	if world == null or player == null:
		return
	main.set("current_screen", "ending")
	main.call("_set_player_controls", false)
	if bool(player.get("first_person")):
		player.call("set_first_person", false)
	# Герой переходить на оглядову точку на краю плато (за ареною): позаду — руїни Корони,
	# попереду — світанок. Раніше камера стартувала там, де помер бос, і залазила в мури.
	_fin_sun_flat = Vector3(-0.62, 0.0, -0.77).normalized()
	if world.has_method("get_finale_viewpoint"):
		var vp: Dictionary = world.call("get_finale_viewpoint")
		_fin_sun_flat = (vp["facing"] as Vector3).normalized()
		var spot: Vector3 = world.call("_raycast_ground_position", vp["position"], 1.05)
		player.global_position = spot
	player.set("velocity", Vector3.ZERO)
	player.rotation.y = atan2(-_fin_sun_flat.x, -_fin_sun_flat.z)
	var knight: Node3D = player.get("knight_model")
	if knight:
		knight.rotation = Vector3(0.0, PI, 0.0)
	var anim: AnimationPlayer = player.get("anim_player")
	if anim:
		anim.seek(0.0, true)
		anim.pause()
	# Тепле контрове світло від світанку окреслює силует, роги шолома й плащ.
	var rim := OmniLight3D.new()
	rim.name = "FinaleRimLight"
	rim.light_color = Color("#ffb070")
	rim.light_energy = 2.2
	rim.omni_range = 7.0
	rim.position = Vector3(0.0, 1.8, -1.6)
	player.add_child(rim)
	_fin_center = player.global_position + Vector3(0.0, 0.9, 0.0)
	_fin_base_az = atan2(_fin_sun_flat.x, _fin_sun_flat.z)
	_fin_cam = Camera3D.new()
	_fin_cam.name = "FinaleCamera"
	_fin_cam.far = 2200.0
	_fin_cam.fov = 60.0
	add_child(_fin_cam)
	_fin_cam.make_current()
	world.set("day_clock", 0.02)
	world.set("finale_dawn", 0.001)
	var cutscene: Node = main.get("cutscene")
	if cutscene:
		cutscene.call("_bars", true, 1.5)
	AudioManager.play_finale()
	_fin_t = 0.0
	_fin_faded = false
	_step_finale(0.0)


func _ease(x: float) -> float:
	var k := clampf(x, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


func _step_finale(delta: float) -> void:
	_fin_t += delta
	var world: Node3D = main.get("world_generator")
	var k := clampf(_fin_t / FINALE_LENGTH, 0.0, 1.0)
	var e := _ease(k)
	# Небо: найтемніша ніч → золотий світанок → ясний яскравий ранок (туман розходиться, світ барвистий).
	var dawn := _ease(clampf((_fin_t - 4.0) / 42.0, 0.0, 1.0))
	world.set("finale_dawn", maxf(dawn, 0.001))
	world.set("world_renew", _ease(clampf((_fin_t - 44.0) / 30.0, 0.0, 1.0)))
	world.set("day_clock", lerpf(0.02, 0.27, dawn))
	world.set("day_night_update_timer", 1.0)

	# Камера: 1) спереду знизу — герой на тлі руїн Корони (масштаб замку й героя);
	# 2) обліт збоку за спину; 3) з-за плеча на світанок і піднесення над світом.
	var dolly := _ease(clampf(k / 0.22, 0.0, 1.0))
	var orbit := _ease(clampf((k - 0.2) / 0.45, 0.0, 1.0))
	# 4) Повільний великий відліт угору й назад — видно масштаб світу, який герой урятував.
	var rise := _ease(clampf((k - 0.55) / 0.45, 0.0, 1.0))
	var azimuth := _fin_base_az + PI * orbit
	var radius := lerpf(lerpf(10.5, 7.5, dolly), 12.0, orbit) + rise * rise * 170.0
	var height := lerpf(0.2, 3.8, orbit) + rise * rise * 120.0
	var offset := Vector3(sin(azimuth), 0.0, cos(azimuth)) * radius
	var target_hero := _fin_center + Vector3(0.0, lerpf(2.4, 1.0, orbit), 0.0)
	var target_far := _fin_center + Vector3(_fin_sun_flat.x, 0.16, _fin_sun_flat.z).normalized() * 600.0
	# На відльоті камера дивиться не в сонце, а вниз на долини й гори — герой лишається в кадрі.
	var target_land := _fin_center + Vector3(_fin_sun_flat.x, 0.0, _fin_sun_flat.z).normalized() * 220.0 + Vector3(0.0, -45.0, 0.0)
	var look := target_hero.lerp(target_far, orbit * 0.12).lerp(target_land, rise * 0.62)
	var pos := _fin_center + offset + Vector3(0.0, height, 0.0)
	# Не опускатися нижче рельєфу і не заходити в мури: промінь від героя до камери.
	var ground: Vector3 = world.call("_raycast_ground_position", pos, 1.2)
	pos.y = maxf(pos.y, ground.y)
	var player_node: Node3D = main.get("player")
	var space := world.get_world_3d().direct_space_state
	var head := _fin_center + Vector3(0.0, 0.7, 0.0)
	var query := PhysicsRayQueryParameters3D.create(head, pos, 1)
	if player_node is CollisionObject3D:
		query.exclude = [(player_node as CollisionObject3D).get_rid()]
	var hit := space.intersect_ray(query)
	# Високо в небі руїни між героєм і камерою вже не заважають — не притягуємо камеру до мурів.
	if not hit.is_empty() and rise < 0.25:
		pos = (hit["position"] as Vector3) + (head - pos).normalized() * 0.6
	_fin_cam.global_position = pos
	if pos.distance_to(look) > 0.1:
		_fin_cam.look_at(look, Vector3.UP)
	_fin_cam.fov = lerpf(58.0, 74.0, e)

	var cutscene: Node = main.get("cutscene")
	if _fin_t > FINALE_LENGTH - 6.0 and not _fin_faded:
		_fin_faded = true
		if cutscene:
			cutscene.call("fade_to_black", 5.0)
	if _fin_t >= FINALE_LENGTH:
		_fin_t = -1.0
		if cutscene:
			cutscene.call("_bars", false, 0.1)
		main.call("_show_ending_credits")
