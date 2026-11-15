extends Node
## CutsceneDirector — короткі кінематографічні сцени на рушії:
## • flyover: проліт камери над світом до Чорної Гори (початок гри);
## • focus: плавний наїзд на важливого NPC на час діалогу, смуги letterbox;
## • finale: повільний обліт NPC після здачі квесту (будь-яка клавіша — пропуск);
## • fade_to_black / fade_from_black для переходів.

signal finished   # камеру повернено гравцеві

const FLYOVER_PATH: Array = [
	Vector3(1950.0, 2450.0, 14.0),
	Vector3(1500.0, 1900.0, 60.0),
	Vector3(1050.0, 1250.0, 75.0),
	Vector3(800.0, 850.0, 38.0),
]
const BAR_FRACTION: float = 0.1

var world: Node3D = null
var player: Node3D = null

var _cam: Camera3D = null
var _fill_light: OmniLight3D = null
var _mode: String = ""
var _t: float = 0.0
var _dur: float = 1.0
var _from_pos: Vector3
var _from_look: Vector3
var _to_pos: Vector3
var _to_look: Vector3
var _from_fov: float = 72.0
var _target: Node3D = null
var _talk_body: Node = null
var _talk_rig: Node = null
var _orbit_start_angle: float = 0.0
var _orbit_sweep: float = 0.0
var _orbit_radius: float = 3.0
var _bars_layer: CanvasLayer
var _top_bar: ColorRect
var _bottom_bar: ColorRect
var _fade_layer: CanvasLayer
var _fade: ColorRect


func setup(world_node: Node3D, player_node: Node3D) -> void:
	world = world_node
	player = player_node
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bars_layer = CanvasLayer.new()
	_bars_layer.layer = 17
	add_child(_bars_layer)
	_top_bar = _make_bar(true)
	_bottom_bar = _make_bar(false)
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 45
	add_child(_fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade)


func _make_bar(top: bool) -> ColorRect:
	var bar := ColorRect.new()
	bar.color = Color(0.0, 0.0, 0.0, 0.96)
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 0.0 if top else 1.0
	bar.anchor_bottom = 0.0 if top else 1.0
	bar.offset_left = 0.0
	bar.offset_right = 0.0
	bar.offset_top = 0.0
	bar.offset_bottom = 0.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars_layer.add_child(bar)
	return bar


func is_busy() -> bool:
	return _mode != ""


func is_orbiting() -> bool:
	return _mode == "orbit"


func is_skippable() -> bool:
	return _mode == "orbit" or _mode == "shot"


func _bars(show_bars: bool, seconds: float = 0.6) -> void:
	var height := get_viewport().get_visible_rect().size.y * BAR_FRACTION if show_bars else 0.0
	var tween := create_tween().set_parallel(true)
	tween.set_ignore_time_scale(true)
	tween.tween_property(_top_bar, "offset_bottom", height, seconds).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_bottom_bar, "offset_top", -height, seconds).set_trans(Tween.TRANS_SINE)


func fade_to_black(seconds: float) -> void:
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(_fade, "color:a", 1.0, seconds)


func fade_from_black(seconds: float) -> void:
	_fade.color.a = 1.0
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(_fade, "color:a", 0.0, seconds)


func _new_camera() -> void:
	if _cam == null:
		_cam = Camera3D.new()
		_cam.name = "CutsceneCamera"
		_cam.far = 1500.0
		add_child(_cam)
		# Тепле заповнювальне світло з боку камери: обличчя NPC читається і вночі.
		_fill_light = OmniLight3D.new()
		_fill_light.light_color = Color("#ffc48a")
		_fill_light.light_energy = 1.5
		_fill_light.omni_range = 7.0
		_fill_light.visible = false
		_cam.add_child(_fill_light)
		_fill_light.position = Vector3(0.6, 0.5, 0.2)


func _player_camera() -> Camera3D:
	return player.get("camera") as Camera3D if player else null


func _place(pos: Vector3, look: Vector3) -> void:
	_cam.global_position = pos
	if pos.distance_to(look) > 0.1:
		_cam.look_at(look, Vector3.UP)


func _summit_world() -> Vector3:
	var builder: Node = world.get("terrain_builder")
	var local: Vector3 = builder.call("get_summit_position") if builder else Vector3.ZERO
	return world.to_global(local + Vector3(0.0, 10.0, 0.0))


# --- Проліт над світом ---------------------------------------------------------------

func play_flyover(seconds: float) -> void:
	_new_camera()
	_mode = "flyover"
	_t = 0.0
	_dur = maxf(seconds, 1.0)
	_cam.fov = 66.0
	_cam.make_current()
	_bars(true, 0.8)
	_step_flyover(0.0)


func stop_flyover() -> void:
	if _mode == "flyover":
		_mode = ""
		_bars(false, 0.4)
		var cam := _player_camera()
		if cam:
			cam.make_current()


func _bezier(points: Array, u: float) -> Vector3:
	var p0: Vector3 = points[0]
	var p1: Vector3 = points[1]
	var p2: Vector3 = points[2]
	var p3: Vector3 = points[3]
	var iu := 1.0 - u
	return p0 * iu * iu * iu + p1 * 3.0 * iu * iu * u + p2 * 3.0 * iu * u * u + p3 * u * u * u


func _step_flyover(delta: float) -> void:
	_t += delta
	var k := clampf(_t / _dur, 0.0, 1.0)
	var e := lerpf(k, k * k * (3.0 - 2.0 * k), 0.6)
	var point := _bezier(FLYOVER_PATH, e)
	var local: Vector3 = world.call("_surface_position", point.x, point.y, point.z)
	var pos := world.to_global(local)
	# Погляд спершу на гору здалеку, наприкінці — на вінець руїн.
	var summit := _summit_world()
	var look := summit + Vector3(0.0, lerpf(60.0, 0.0, e), 0.0)
	_place(pos, look)


# --- Наїзд на NPC під час діалогу ---------------------------------------------------------

func focus_npc(npc: Node3D) -> void:
	if npc == null or _mode != "" or player == null:
		return
	var start_cam := get_viewport().get_camera_3d()
	if start_cam == null:
		return
	_new_camera()
	_target = npc
	_cam.global_transform = start_cam.global_transform
	_cam.fov = start_cam.fov
	_cam.make_current()
	_from_fov = start_cam.fov
	_from_pos = start_cam.global_position
	_from_look = _from_pos - start_cam.global_transform.basis.z * 6.0
	var head := npc.global_position + Vector3(0.0, 1.68, 0.0)
	var away := player.global_position - npc.global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.BACK
	var side := away.cross(Vector3.UP) * 0.6
	_to_pos = head + away * 1.6 + side * 0.75 + Vector3(0.0, 0.0, 0.0)
	_to_look = head + Vector3(0.0, -0.02, 0.0) - side * 0.3
	_talk_rig = npc.find_child("FaceRig", true, false)
	if _talk_rig:
		_talk_rig.call("set_talking", true)
	_talk_body = npc.get_node_or_null("HumanoidRig")
	if _talk_body:
		_talk_body.set("talking", true)
	_fill_light.visible = true
	_t = 0.0
	_dur = 1.1
	_mode = "focus_in"
	_bars(true)


func release_focus() -> void:
	if _mode != "focus_in" and _mode != "focus_hold":
		return
	_begin_release()


func _begin_release() -> void:
	_stop_talking()
	var player_cam := _player_camera()
	if player_cam == null or _cam == null:
		_end_release()
		return
	_from_pos = _cam.global_position
	_from_look = _from_pos - _cam.global_transform.basis.z * 6.0
	_from_fov = _cam.fov
	_to_pos = player_cam.global_position
	_to_look = _to_pos - player_cam.global_transform.basis.z * 6.0
	_t = 0.0
	_dur = 0.6
	_mode = "release"
	_bars(false)


func _stop_talking() -> void:
	if _talk_rig and is_instance_valid(_talk_rig):
		_talk_rig.call("set_talking", false)
	_talk_rig = null
	if _talk_body and is_instance_valid(_talk_body):
		_talk_body.set("talking", false)
	_talk_body = null


func _end_release() -> void:
	_stop_talking()
	_mode = ""
	if _fill_light:
		_fill_light.visible = false
	_target = null
	var cam := _player_camera()
	if cam:
		cam.make_current()
	finished.emit()


# --- Короткий атмосферний проліт між двома точками світу -------------------------------------

func play_shot(p0: Vector3, p1: Vector3, look0: Vector3, look1: Vector3, seconds: float, shot_fov: float = 58.0, from_black: bool = true) -> bool:
	if _mode != "" and _mode != "release":
		return false
	_new_camera()
	_fill_light.visible = false
	_cam.fov = shot_fov
	_from_pos = p0
	_to_pos = p1
	_from_look = look0
	_to_look = look1
	_t = 0.0
	_dur = maxf(seconds, 1.0)
	_mode = "shot"
	_cam.make_current()
	_bars(true, 0.6)
	if from_black:
		fade_from_black(0.9)
	_place(p0, look0)
	return true


# --- Фінал квесту: повільний обліт NPC --------------------------------------------------

func finale_orbit(seconds: float) -> void:
	if _mode != "focus_hold" and _mode != "focus_in":
		return
	if _target == null:
		return
	var head := _target.global_position + Vector3(0.0, 1.6, 0.0)
	var offset := _cam.global_position - head
	_orbit_radius = clampf(Vector2(offset.x, offset.z).length(), 1.8, 4.0)
	_orbit_start_angle = atan2(offset.z, offset.x)
	_orbit_sweep = deg_to_rad(70.0)
	_t = 0.0
	_dur = maxf(seconds, 1.0)
	_mode = "orbit"


func _input(event: InputEvent) -> void:
	if is_skippable() and event is InputEventKey and event.pressed and not event.echo:
		_begin_release()
		get_viewport().set_input_as_handled()


# --- Покадровий рух ---------------------------------------------------------------------

func _process(delta: float) -> void:
	if _mode == "" or _cam == null:
		return
	match _mode:
		"flyover":
			_step_flyover(delta)
		"focus_in":
			_t += delta
			var k := clampf(_t / _dur, 0.0, 1.0)
			var e := k * k * (3.0 - 2.0 * k)
			_place(_from_pos.lerp(_to_pos, e), _from_look.lerp(_to_look, e))
			_cam.fov = lerpf(_from_fov, 44.0, e)
			if k >= 1.0:
				_mode = "focus_hold"
		"focus_hold":
			# Ледь помітне дихання камери, щоб кадр не був мертвим.
			_t += delta
			var sway := Vector3(sin(_t * 0.6) * 0.012, sin(_t * 0.8) * 0.008, 0.0)
			_place(_to_pos + sway, _to_look)
		"shot":
			_t += delta
			var ks := clampf(_t / _dur, 0.0, 1.0)
			var es := lerpf(ks, ks * ks * (3.0 - 2.0 * ks), 0.5)
			_place(_from_pos.lerp(_to_pos, es), _from_look.lerp(_to_look, es))
			if ks >= 1.0:
				_begin_release()
		"orbit":
			_t += delta
			var k2 := clampf(_t / _dur, 0.0, 1.0)
			var e2 := lerpf(k2, k2 * k2 * (3.0 - 2.0 * k2), 0.5)
			var angle := _orbit_start_angle + _orbit_sweep * e2
			var head := _target.global_position + Vector3(0.0, 1.6, 0.0)
			var pos := head + Vector3(cos(angle) * _orbit_radius, 0.1 + 0.25 * e2, sin(angle) * _orbit_radius)
			_place(pos, head - Vector3(0.0, 0.08, 0.0))
			_cam.fov = lerpf(48.0, 42.0, e2)
			if k2 >= 1.0:
				_begin_release()
		"release":
			_t += delta
			var k3 := clampf(_t / _dur, 0.0, 1.0)
			var e3 := k3 * k3 * (3.0 - 2.0 * k3)
			_place(_from_pos.lerp(_to_pos, e3), _from_look.lerp(_to_look, e3))
			var player_cam := _player_camera()
			_cam.fov = lerpf(_from_fov, player_cam.fov if player_cam else 72.0, e3)
			if k3 >= 1.0:
				_end_release()
