class_name Interactable
extends Node3D
## Об'єкт, з яким можна взаємодіяти клавішею E: записка з лором, предмет або огляд.
## WorldGenerator знаходить найближчий доступний Interactable у полі зору гравця.

enum Kind { INSPECT, NOTE, ITEM }

@export var interaction_id: String = ""
@export var display_name: String = ""
@export var prompt: String = "ОГЛЯНУТИ"
@export var radius: float = 2.6
@export var kind: Kind = Kind.INSPECT
@export var note_title: String = ""
@export_multiline var note_text: String = ""
@export var item_id: String = ""
@export var item_name: String = ""

var consumed: bool = false


func _ready() -> void:
	add_to_group("interactables")


func is_available() -> bool:
	return not consumed and is_visible_in_tree()


func get_hint() -> String:
	return "[E]  %s" % prompt


func consume() -> void:
	consumed = true
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, 0.25)
	tween.tween_callback(hide)


static func spawn(parent: Node3D, local_position: Vector3, id: String, kind_value: Kind, title: String, prompt_text: String, glow: Color) -> Interactable:
	## Створює Interactable із простою PSX-моделлю, м'яким світлом і підписом.
	var node := Interactable.new()
	node.name = id
	node.interaction_id = id
	node.display_name = title
	node.prompt = prompt_text
	node.kind = kind_value
	node.position = local_position
	var kit := MeshKit.new()
	match kind_value:
		Kind.ITEM:
			kit.cylinder_at("glass", Vector3(0, 0.0, 0), 0.16, 0.16, 0.34, 6)
			kit.cylinder_at("glass", Vector3(0, 0.34, 0), 0.07, 0.07, 0.12, 6)
			kit.box_at("wood", Vector3(0, 0.49, 0), Vector3(0.1, 0.06, 0.1))
			kit.set_material("glass", PSXMaterials.make(Color("#c88a3c"), 0.2, 0.3, Color("#ff9a3c"), 1.6, "none"))
		Kind.NOTE:
			kit.box_at("stone", Vector3(0, 0.45, 0), Vector3(0.6, 0.9, 0.45))
			kit.box_at("paper", Vector3(0, 0.92, 0), Vector3(0.42, 0.03, 0.3), false, Vector3(-0.2, 0.15, 0))
			kit.box_at("window", Vector3(0.2, 0.98, 0.1), Vector3(0.06, 0.12, 0.06))
			kit.set_material("paper", PSXMaterials.make(Color("#d8c8a0"), 0.0, 0.95, Color("#5a4a30"), 0.3, "plaster"))
		_:
			kit.box_at("stone", Vector3(0, 0.3, 0), Vector3(0.5, 0.6, 0.5))
	for key in kit._tools.keys():
		if not kit.has_material(key):
			kit.set_material(key, BuildingKit.mat(key))
	kit.build(node, "Model", 120.0)
	var light := OmniLight3D.new()
	light.light_color = glow
	light.light_energy = 0.9
	light.omni_range = 4.5
	light.position = Vector3(0, 1.0, 0)
	light.distance_fade_enabled = true
	light.distance_fade_begin = 50.0
	node.add_child(light)
	var plate := Marker3D.new()
	plate.name = "Nameplate"
	plate.position = Vector3(0, 1.35, 0)
	plate.set_meta("title", title)
	plate.set_meta("color", glow)
	plate.set_meta("range", 9.0)
	plate.add_to_group("nameplate")
	node.add_child(plate)
	parent.add_child(node)
	return node
