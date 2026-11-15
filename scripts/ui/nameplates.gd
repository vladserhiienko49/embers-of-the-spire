extends Control
## Чіткі екранні підписи NPC, ворогів і предметів (поверх PSX-кадру, без пікселізації).
## Маркер — будь-який Node3D у групі "nameplate" з meta: title, subtitle, color, range.

var _labels: Dictionary = {} # instance_id -> Label
var _font_title: int = 17
var _font_subtitle: int = 12


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var alive: Dictionary = {}
	if camera and is_visible_in_tree():
		var camera_position := camera.global_position
		for marker in get_tree().get_nodes_in_group("nameplate"):
			var node := marker as Node3D
			if node == null or not node.is_visible_in_tree():
				continue
			var id := node.get_instance_id()
			var max_range := float(node.get_meta("range", 16.0))
			var world_position := node.global_position
			var distance := camera_position.distance_to(world_position)
			if distance > max_range or camera.is_position_behind(world_position):
				continue
			var label: Label = _labels.get(id, null)
			if label == null:
				label = _make_label(node)
				_labels[id] = label
			alive[id] = true
			var screen := camera.unproject_position(world_position)
			label.reset_size()
			label.position = screen - Vector2(label.size.x * 0.5, label.size.y)
			label.modulate.a = 1.0 - smoothstep(max_range * 0.6, max_range, distance)
			label.visible = true
	for id in _labels.keys():
		if not alive.has(id):
			var stale: Label = _labels[id]
			if not is_instance_valid(instance_from_id(id)):
				stale.queue_free()
				_labels.erase(id)
			else:
				stale.visible = false


func _make_label(node: Node3D) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title := str(node.get_meta("title", ""))
	var subtitle := str(node.get_meta("subtitle", ""))
	label.text = title if subtitle.is_empty() else "%s\n%s" % [title, subtitle]
	var color: Color = node.get_meta("color", Color("#f0dfbf"))
	label.add_theme_font_size_override("font_size", _font_title if subtitle.is_empty() else _font_subtitle + 2)
	label.add_theme_color_override("font_color", color.lightened(0.25))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.015, 0.02, 0.95))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(label)
	return label
