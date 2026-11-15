class_name Spinner
extends Node3D
## Повільне обертання й погойдування декоративних реліквій (браслети, кільця, уламки).

@export var spin: Vector3 = Vector3(0.0, 0.6, 0.0)
@export var bob_amplitude: float = 0.0
@export var bob_speed: float = 1.0
@export var phase: float = 0.0

var _base_y: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	_base_y = position.y
	_t = phase


func _process(delta: float) -> void:
	_t += delta
	rotate_object_local(Vector3.RIGHT, spin.x * delta)
	rotate_object_local(Vector3.UP, spin.y * delta)
	rotate_object_local(Vector3.BACK, spin.z * delta)
	if bob_amplitude > 0.0:
		position.y = _base_y + sin(_t * bob_speed) * bob_amplitude
