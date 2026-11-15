class_name CardGame
extends CanvasLayer
## «Попелясте двадцять одне» — карткова гра гравця проти мага Вальмера.
## Колода: 40 карт (1–10 у чотирьох мастях). Мета — набрати ближче до 21, ніж маг, не перебравши.
## Ставка в монетах; маг сам ухвалює рішення (бере карту, поки вважає ризик виправданим).

const SUITS: Array = [["♦", Color("#d9503a"), "Вогонь"], ["♠", Color("#aeb4c0"), "Попіл"], ["♥", Color("#7aa8ff"), "Місяць"], ["♣", Color("#b080e8"), "Око"]]
const BETS: Array = [10, 25, 50]
const TEXT := Color("#e9dfc9")
const GOLD := Color("#e4c18a")

var main: Node = null
var _root: Control
var _coins_label: Label
var _status: Label
var _mage_row: HBoxContainer
var _player_row: HBoxContainer
var _mage_total: Label
var _player_total: Label
var _bet_row: HBoxContainer
var _action_row: HBoxContainer
var _rules_panel: PanelContainer
var _deck: Array = []
var _player_hand: Array = []
var _mage_hand: Array = []
var _bet: int = 10
var _state: String = "bet"
var _mage_hidden: bool = true
var _busy: bool = false


func setup(main_node: Node) -> void:
	main = main_node
	layer = 38
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func is_open() -> bool:
	return _root != null and _root.visible


func open() -> void:
	main.set("current_screen", "cards")
	main.call("_set_player_controls", false)
	_state = "bet"
	_clear_hands()
	_status.text = "Обери ставку й роздай карти. Правила — кнопка внизу."
	_refresh()
	_root.visible = true
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.2)
	AudioManager.play_ui("dialogue_open")


func close() -> void:
	if not is_open():
		return
	_root.visible = false
	AudioManager.play_ui("ui_back")
	main.call("_close_world_dialogue")


func _input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("ui_cancel"):
		if _rules_panel.visible:
			_rules_panel.visible = false
		elif not _busy:
			close()
		get_viewport().set_input_as_handled()


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, handler: Callable, width: float = 170.0) -> Button:
	var b: Button = main.call("_make_oath_button", text, Color("#342b21"), Color("#9f7b4d"))
	b.custom_minimum_size = Vector2(width, 46.0)
	b.pressed.connect(handler)
	return b


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -430.0
	panel.offset_right = 430.0
	panel.offset_top = -330.0
	panel.offset_bottom = 330.0
	panel.add_theme_stylebox_override("panel", InventoryScreen._box_style(Color(0.05, 0.075, 0.06, 0.98), Color("#8a6a3a"), 3))
	_root.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	head.add_child(_label("ПОПЕЛЯСТЕ 21  •  ГРА З ВАЛЬМЕРОМ", 22, GOLD))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	_coins_label = _label("", 18, Color("#f2d27a"))
	head.add_child(_coins_label)
	col.add_child(_label("МАГІСТР ВАЛЬМЕР", 14, Color("#9c72d4")))
	_mage_row = HBoxContainer.new()
	_mage_row.custom_minimum_size = Vector2(0, 118)
	_mage_row.add_theme_constant_override("separation", 8)
	col.add_child(_mage_row)
	_mage_total = _label("", 14, TEXT)
	col.add_child(_mage_total)
	_status = _label("", 17, GOLD)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0, 52)
	col.add_child(_status)
	col.add_child(_label("ТИ", 14, Color("#8fd19a")))
	_player_row = HBoxContainer.new()
	_player_row.custom_minimum_size = Vector2(0, 118)
	_player_row.add_theme_constant_override("separation", 8)
	col.add_child(_player_row)
	_player_total = _label("", 14, TEXT)
	col.add_child(_player_total)
	_bet_row = HBoxContainer.new()
	_bet_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_bet_row.add_theme_constant_override("separation", 10)
	col.add_child(_bet_row)
	_action_row = HBoxContainer.new()
	_action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_action_row.add_theme_constant_override("separation", 10)
	col.add_child(_action_row)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 12)
	col.add_child(foot)
	foot.add_child(_button("ПРАВИЛА", func() -> void: _rules_panel.visible = true, 150.0))
	foot.add_child(_button("ВСТАТИ З-ЗА СТОЛУ  (ESC)", close, 260.0))
	# Правила — накладка поверх столу.
	_rules_panel = PanelContainer.new()
	_rules_panel.set_anchors_preset(Control.PRESET_CENTER)
	_rules_panel.custom_minimum_size = Vector2(620, 0)
	_rules_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_rules_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_rules_panel.add_theme_stylebox_override("panel", InventoryScreen._box_style(Color(0.04, 0.03, 0.025, 1.0), Color("#c9a977"), 3))
	_rules_panel.visible = false
	_root.add_child(_rules_panel)
	var rm := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		rm.add_theme_constant_override("margin_" + side, 22)
	_rules_panel.add_child(rm)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 10)
	rm.add_child(rv)
	rv.add_child(_label("ПРАВИЛА", 22, GOLD))
	var rules := _label("• Колода — 40 карт: числа від 1 до 10 у мастях Вогонь, Попіл, Місяць, Око.\n• Мета — набрати суму ближче до 21, ніж у Вальмера, але не більше 21.\n• Кожному роздають по 2 карти. Одна карта мага закрита до кінця раунду.\n• «Взяти карту» додає ще одну. Якщо сума перевищила 21 — це перебір і програш.\n• «Достатньо» передає хід магові: він сам вирішує, чи брати карти.\n• Хто ближче до 21 — виграє ставку. Рівна сума — нічия, ставку повернуто.\n• 21 із двох карт (10 і 1) — «Попелясте очко»: виплата 3 до 2.\n• Ставки: 10, 25 або 50 монет. Монети беруться з твого гаманця.", 15, TEXT)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.custom_minimum_size = Vector2(570, 0)
	rv.add_child(rules)
	rv.add_child(_button("ЗРОЗУМІЛО", func() -> void: _rules_panel.visible = false, 200.0))


# --- Логіка гри ----------------------------------------------------------------------------------

func _score() -> int:
	return int(main.get("score"))


func _add_coins(delta: int) -> void:
	main.set("score", maxi(0, _score() + delta))
	main.call("_update_score")


func _new_deck() -> void:
	_deck.clear()
	for s in range(4):
		for v in range(1, 11):
			_deck.append([v, s])
	_deck.shuffle()


func _draw() -> Array:
	if _deck.is_empty():
		_new_deck()
	return _deck.pop_back()


func _total(hand: Array) -> int:
	var t := 0
	for c in hand:
		t += int(c[0])
	return t


func _clear_hands() -> void:
	_player_hand.clear()
	_mage_hand.clear()
	_mage_hidden = true


func _deal() -> void:
	if _score() < _bet:
		_status.text = "Не вистачає монет на ставку %d." % _bet
		return
	_new_deck()
	_clear_hands()
	_player_hand = [_draw(), _draw()]
	_mage_hand = [_draw(), _draw()]
	_state = "player"
	_status.text = "Твій хід: взяти карту чи вистачить?"
	AudioManager.play_ui("item_pickup")
	_refresh()
	if _total(_player_hand) == 21:
		_stand()


func _hit() -> void:
	if _state != "player" or _busy:
		return
	_player_hand.append(_draw())
	AudioManager.play_ui("note_read")
	if _total(_player_hand) > 21:
		_mage_hidden = false
		_finish("bust")
	elif _total(_player_hand) == 21:
		_stand()
	else:
		_refresh()


func _stand() -> void:
	if _state != "player" or _busy:
		return
	_state = "mage"
	_mage_hidden = false
	_busy = true
	_status.text = "Вальмер перевертає карту…"
	_refresh()
	_mage_turn()


func _mage_wants_card() -> bool:
	## Бот: бере до 17; якщо програє гравцю й ризик малий — ризикує; з 19 і більше зупиняється.
	var m := _total(_mage_hand)
	var p := _total(_player_hand)
	if m >= 19:
		return false
	if m < 12:
		return true
	if m < 17:
		return true
	return m < p and m <= 18 and randf() < 0.55


func _mage_turn() -> void:
	await get_tree().create_timer(0.9).timeout
	if not is_open():
		_busy = false
		return
	while _mage_wants_card():
		_status.text = "Вальмер бере карту…"
		_mage_hand.append(_draw())
		AudioManager.play_ui("note_read")
		_refresh()
		await get_tree().create_timer(0.9).timeout
		if not is_open():
			_busy = false
			return
	_busy = false
	var m := _total(_mage_hand)
	var p := _total(_player_hand)
	if m > 21:
		_finish("mage_bust")
	elif p > m:
		_finish("win")
	elif p < m:
		_finish("lose")
	else:
		_finish("push")


func _finish(result: String) -> void:
	_state = "result"
	var natural := _player_hand.size() == 2 and _total(_player_hand) == 21
	match result:
		"win", "mage_bust":
			var gain := int(float(_bet) * 1.5) if natural and result == "win" else _bet
			_add_coins(gain)
			_status.text = ("Попелясте очко! +%d монет." if natural else ("Маг перебрав! +%d монет." if result == "mage_bust" else "Ти виграв раунд! +%d монет.")) % gain
			AudioManager.play_ui("quest_complete", -6.0)
		"lose":
			_add_coins(-_bet)
			_status.text = "Вальмер виграв: %d проти %d. −%d монет." % [_total(_mage_hand), _total(_player_hand), _bet]
			AudioManager.play_ui("ui_back")
		"bust":
			_add_coins(-_bet)
			_status.text = "Перебір (%d)! −%d монет." % [_total(_player_hand), _bet]
			AudioManager.play_ui("ui_back")
		"push":
			_status.text = "Нічия: по %d. Ставку повернуто." % _total(_player_hand)
	_refresh()


# --- Відображення ------------------------------------------------------------------------------------

func _card_widget(card: Array, hidden: bool) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(76, 108)
	var suit: Array = SUITS[int(card[1])]
	var border: Color = suit[1] if not hidden else Color("#6a5a44")
	p.add_theme_stylebox_override("panel", InventoryScreen._box_style(Color("#1a1410") if hidden else Color("#e8dcc0"), border, 3))
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 30)
	if hidden:
		l.text = "?"
		l.add_theme_color_override("font_color", Color("#9c72d4"))
	else:
		l.text = "%d\n%s" % [int(card[0]), suit[0]]
		l.add_theme_color_override("font_color", (suit[1] as Color).darkened(0.35))
	p.add_child(l)
	return p


func _fill_row(row: HBoxContainer, hand: Array, hide_second: bool) -> void:
	for c in row.get_children():
		row.remove_child(c)
		c.queue_free()
	for i in range(hand.size()):
		row.add_child(_card_widget(hand[i], hide_second and i == 1))


func _refresh() -> void:
	_coins_label.text = "◈  Монети: %d" % _score()
	_fill_row(_mage_row, _mage_hand, _mage_hidden)
	_fill_row(_player_row, _player_hand, false)
	_mage_total.text = "" if _mage_hand.is_empty() else ("Сума: %d" % (_total(_mage_hand) if not _mage_hidden else int(_mage_hand[0][0])) + ("  (+ закрита карта)" if _mage_hidden else ""))
	_player_total.text = "" if _player_hand.is_empty() else "Сума: %d" % _total(_player_hand)
	for c in _bet_row.get_children():
		_bet_row.remove_child(c)
		c.queue_free()
	for c in _action_row.get_children():
		_action_row.remove_child(c)
		c.queue_free()
	if _state == "bet" or _state == "result":
		_bet_row.add_child(_label("Ставка:", 16, TEXT))
		for b in BETS:
			var btn := _button(("● %d" if int(b) == _bet else "%d") % int(b), func() -> void:
				_bet = int(b)
				_refresh(), 90.0)
			_bet_row.add_child(btn)
		_action_row.add_child(_button("РОЗДАТИ КАРТИ", _deal, 220.0))
	elif _state == "player":
		_action_row.add_child(_button("ВЗЯТИ КАРТУ", _hit, 200.0))
		_action_row.add_child(_button("ДОСТАТНЬО", _stand, 200.0))
