extends Node3D
## Анімація голови персонажа: моргання, легке погойдування, а під час розмови —
## кивки та рухи рота (перемикання текстур рота «закритий / відкритий»).

var face_mat: ShaderMaterial
var mouth_mat: ShaderMaterial
var tex_open: Texture2D
var tex_blink: Texture2D
var mouth_closed: Texture2D
var mouth_open: Texture2D

var talking: bool = false

var _time: float = 0.0
var _phase: float = 0.0
var _blink_in: float = 2.0
var _blink_left: float = 0.0
var _mouth_timer: float = 0.0
var _mouth_is_open: bool = false


func setup(face_material: ShaderMaterial, mouth_material: ShaderMaterial, open_texture: Texture2D, blink_texture: Texture2D, closed_mouth: Texture2D, open_mouth: Texture2D) -> void:
	face_mat = face_material
	mouth_mat = mouth_material
	tex_open = open_texture
	tex_blink = blink_texture
	mouth_closed = closed_mouth
	mouth_open = open_mouth
	_phase = randf() * TAU
	_blink_in = randf_range(1.5, 5.0)


func set_talking(value: bool) -> void:
	talking = value
	if not value:
		_set_mouth(false)


func _set_mouth(open: bool) -> void:
	_mouth_is_open = open
	if mouth_mat:
		mouth_mat.set_shader_parameter("albedo_texture", mouth_open if open else mouth_closed)


func _process(delta: float) -> void:
	if face_mat == null:
		return
	# Далекі персонажі не анімуються — економимо процесорний час.
	var camera := get_viewport().get_camera_3d()
	if camera and camera.global_position.distance_squared_to(global_position) > 1600.0:
		return
	_time += delta

	_blink_in -= delta
	if _blink_left > 0.0:
		_blink_left -= delta
		if _blink_left <= 0.0:
			face_mat.set_shader_parameter("albedo_texture", tex_open)
	elif _blink_in <= 0.0:
		_blink_left = 0.13
		_blink_in = randf_range(2.5, 6.0)
		face_mat.set_shader_parameter("albedo_texture", tex_blink)

	rotation.y = sin(_time * 0.4 + _phase) * 0.07
	rotation.x = sin(_time * 0.3 + _phase) * 0.02
	if talking:
		_mouth_timer -= delta
		if _mouth_timer <= 0.0:
			_set_mouth(not _mouth_is_open if randf() < 0.85 else true)
			_mouth_timer = randf_range(0.07, 0.19)
		rotation.x += sin(_time * 5.2) * 0.05
		rotation.y += sin(_time * 1.6) * 0.1
