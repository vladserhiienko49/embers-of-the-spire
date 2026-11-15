class_name MapFragmentScene
extends CanvasLayer
## Сцена складання Атласу Корони: три уламки Печатки зростаються, з їхнього світла проступає останній шматок —
## Чорна Гора. Герой кладе його на атлас (той самий рендер карти, що й у меню M), карта складається повністю,
## і вперше видно місце Ока та шлях до нього.

const WORLD_MAP_SCRIPT: GDScript = preload("res://world_map_view.gd")
const MAP_SIZE := Vector2(1000.0, 600.0)

var main: Node = null
var _root: Control
var _map: Control
var _line: Label
var _on_done: Callable
var _can_skip: bool = false
var _finished: bool = false
var _waiting_atlas: bool = false
var _wait_t: float = 0.0
var _glow_t: float = -1.0


func setup(main_node: Node) -> void:
	main = main_node
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	_line = Label.new()
	_line.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_line.offset_left = -440.0
	_line.offset_right = 440.0
	_line.offset_top = -120.0
	_line.offset_bottom = -30.0
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.add_theme_font_size_override("font_size", 19)
	_line.add_theme_color_override("font_color", Color("#e8d6ae"))
	_root.add_child(_line)


func _make_map() -> void:
	## Справжній атлас гри (без маркерів міні-карти): анімує всі ще не покладені шматки.
	if _map and is_instance_valid(_map):
		return
	var world: Node = main.get("world_generator")
	var player: Node3D = main.get("player")
	_map = Control.new()
	_map.name = "AtlasAssembly"
	_map.set_script(WORLD_MAP_SCRIPT)
	_map.anchor_left = 0.5
	_map.anchor_right = 0.5
	_map.anchor_top = 0.5
	_map.anchor_bottom = 0.5
	_map.offset_left = -MAP_SIZE.x * 0.5
	_map.offset_right = MAP_SIZE.x * 0.5
	_map.offset_top = -MAP_SIZE.y * 0.5 - 50.0
	_map.offset_bottom = MAP_SIZE.y * 0.5 - 50.0
	_root.add_child(_map)
	_map.call("setup", world, player, false)


func play(on_done: Callable) -> void:
	_on_done = on_done
	_finished = false
	_can_skip = false
	_waiting_atlas = false
	_glow_t = -1.0
	main.set("current_screen", "map_scene")
	main.call("_set_player_controls", false)
	_make_map()
	_root.visible = true
	_root.modulate.a = 0.0
	_line.text = ""
	AudioManager.play_ui("journal_open")
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.8)
	tw.tween_callback(func() -> void: _say("Ти розгортаєш Атлас Корони, зшитий зі шматків хранителів. Не вистачає лише одного — серця карти."))
	tw.tween_interval(3.2)
	tw.tween_callback(func() -> void:
		_say("Три уламки Печатки зростаються в долонях — і з їхнього світла проступає останній клапоть: Чорна Гора.")
		AudioManager.play_ui("discover", -4.0))
	tw.tween_interval(2.4)
	tw.tween_callback(func() -> void:
		QuestManager.add_map_piece(AtlasPieces.FINAL)
		_say("Ти кладеш його на місце. Краї сходяться, нитки Печатки зшивають папір…")
		_waiting_atlas = true
		_wait_t = 0.0)


func _process(delta: float) -> void:
	if not _root.visible or _finished:
		return
	if _waiting_atlas:
		_wait_t += delta
		# Атлас сам анімує всі ще не покладені шматки; страховка — 20 с.
		if (_wait_t > 0.6 and bool(_map.call("is_atlas_idle"))) or _wait_t > 20.0:
			_waiting_atlas = false
			_on_atlas_complete()


func _on_atlas_complete() -> void:
	for id in AtlasPieces.ORDER:
		QuestManager.mark_map_piece_seen(str(id))
	var world: Node = main.get("world_generator")
	if world:
		world.set("eye_map_known", true)
	AudioManager.play_ui("quest_complete", -2.0)
	_say("АТЛАС СКЛАДЕНО.  Вперше видно Чорну Гору й Вівтар Ока: тракт із Села Попелу на північний захід, далі серпантин до вершини.\n[будь-яка клавіша — продовжити]")
	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.tween_callback(func() -> void: _can_skip = true)
	tw.tween_interval(7.0)
	tw.tween_callback(_finish)


func _say(text: String) -> void:
	_line.text = text
	_line.modulate.a = 0.0
	create_tween().tween_property(_line, "modulate:a", 1.0, 0.6)


func _input(event: InputEvent) -> void:
	if not _root.visible or _finished:
		return
	if _can_skip and (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_finish()
		get_viewport().set_input_as_handled()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_root.visible = false
	if _on_done.is_valid():
		_on_done.call()
	main.call("_show_story_toast", "АТЛАС КОРОНИ СКЛАДЕНО", "Місце Ока відкрито на карті (M). Шлях: тракт із Села Попелу на північний захід, серпантин Чорної Гори.", 7.0)
	main.call("_close_world_dialogue")
