class_name LocationTrigger
extends Node3D
## Зона локації: перше відвідування показує «Відкрито місце», а QuestManager
## зараховує цілі «дістатися» (REACH) з тим самим location_id.
## Перевірка відстані раз на 0.4 с — дешево й не спрацьовує, поки гравець у меню.

@export var location_id: String = ""
@export var display_name: String = ""
@export var radius: float = 20.0

var _timer: float = 0.0
var _inside: bool = false


static func create(parent: Node3D, local_position: Vector3, id: String, title: String, trigger_radius: float) -> LocationTrigger:
	var trigger := LocationTrigger.new()
	trigger.name = "Location_" + id
	trigger.location_id = id
	trigger.display_name = title
	trigger.radius = trigger_radius
	trigger.position = local_position
	parent.add_child(trigger)
	return trigger


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.4
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null or not bool(player.get("controls_enabled")):
		return
	var inside := player.global_position.distance_to(global_position) <= radius
	if inside and not _inside:
		QuestManager.discover_location(location_id, display_name)
	_inside = inside
