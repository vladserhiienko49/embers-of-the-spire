extends Camera3D
## Камера головного меню: повільні проліти над живим світом (вогні, дим, туман, місяць).
## Кожен «кадр» — плавний рух від точки A до B із м'яким погойдуванням; між кадрами — затемнення.
## Координати — карта світу (як у WorldGenerator), висота — над землею.

const FADE_TIME: float = 1.1

const SHOTS: Array = [
	{"from": Vector2(1880, 2300), "to": Vector2(1740, 2130), "h0": 2.2, "h1": 3.0, "summit": true, "look_up": 34.0, "duration": 20.0},
	{"from": Vector2(1050, 2330), "to": Vector2(1330, 2330), "h0": 5.5, "h1": 4.5, "look": Vector2(1180, 2060), "look_h": 4.0, "duration": 14.0},
	{"from": Vector2(1100, 1060), "to": Vector2(950, 930), "h0": 14.0, "h1": 22.0, "summit": true, "duration": 16.0},
	{"from": Vector2(2240, 1150), "to": Vector2(2340, 1180), "h0": 5.0, "h1": 5.0, "look": Vector2(2240, 1330), "look_h": 4.0, "duration": 14.0},
	{"from": Vector2(2700, 850), "to": Vector2(2960, 850), "h0": 8.0, "h1": 8.0, "look": Vector2(2930, 545), "look_h": 12.0, "duration": 16.0},
]

var world: Node3D = null
var active: bool = false

var _index: int = 0
var _time: float = 0.0
var _fade_layer: CanvasLayer
var _fade_rect: ColorRect


func setup(world_node: Node3D) -> void:
	world = world_node
	fov = 60.0
	far = 1500.0
	# Затемнення між кадрами лежить під меню (шар 20), тож текст меню не блимає.
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 19
	_fade_layer.visible = false
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_rect)


func set_active(enabled: bool) -> void:
	active = enabled
	if _fade_layer:
		_fade_layer.visible = enabled
	if enabled:
		_index = 0
		_time = 0.0
		_apply(0.0)
		make_current()


func _process(delta: float) -> void:
	if not active or world == null:
		return
	_time += delta
	var shot: Dictionary = SHOTS[_index]
	var duration: float = float(shot["duration"])
	if _time >= duration:
		_index = (_index + 1) % SHOTS.size()
		_time = 0.0
		shot = SHOTS[_index]
		duration = float(shot["duration"])
	_apply(_time)
	# Вхід із чорного на початку кадру та вихід у чорне наприкінці.
	var fade_in := 1.0 - clampf(_time / FADE_TIME, 0.0, 1.0)
	var fade_out := clampf((_time - (duration - FADE_TIME)) / FADE_TIME, 0.0, 1.0)
	_fade_rect.color.a = maxf(fade_in, fade_out)


func _apply(time_value: float) -> void:
	var shot: Dictionary = SHOTS[_index]
	var t := clampf(time_value / float(shot["duration"]), 0.0, 1.0)
	var eased := lerpf(t, t * t * (3.0 - 2.0 * t), 0.5)
	var from_point: Vector2 = shot["from"]
	var to_point: Vector2 = shot["to"]
	var point := from_point.lerp(to_point, eased)
	var height := lerpf(float(shot["h0"]), float(shot["h1"]), eased)
	var local_position: Vector3 = world.call("_surface_position", point.x, point.y, height)
	var position_world: Vector3 = world.to_global(local_position)
	# М'яке погойдування, ніби камера дихає.
	position_world += Vector3(sin(time_value * 0.35) * 0.25, sin(time_value * 0.5) * 0.12, cos(time_value * 0.3) * 0.2)

	var target_local: Vector3
	if bool(shot.get("summit", false)):
		var builder: Node = world.get("terrain_builder")
		target_local = builder.call("get_summit_position") + Vector3(0.0, float(shot.get("look_up", 10.0)), 0.0) if builder else local_position + Vector3(0, 0, -50)
	else:
		var look_point: Vector2 = shot["look"]
		target_local = world.call("_surface_position", look_point.x, look_point.y, float(shot.get("look_h", 3.0)))
	var target_world: Vector3 = world.to_global(target_local)
	global_position = position_world
	if position_world.distance_to(target_world) > 0.5:
		look_at(target_world, Vector3.UP)
