extends Control
## Піксельний готичний заголовок без шрифтових файлів: текст малюється у SubViewport
## низької роздільності, збільшується nearest-фільтром, а шейдер робить краї різкими,
## фарбує літери золотом→жаром і лишає чорний контур.

const PIXEL_SCALE: float = 3.0
const VIEW_SIZE: Vector2i = Vector2i(180, 58)

const SHADER_CODE: String = """
shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = step(0.42, c.a);
	float lum = dot(c.rgb, vec3(0.3333));
	vec3 gold = mix(vec3(1.0, 0.88, 0.58), vec3(0.88, 0.40, 0.13), smoothstep(0.15, 0.95, UV.y));
	vec3 col = lum > 0.45 ? gold : vec3(0.015, 0.01, 0.015);
	COLOR = vec4(col, a);
}
"""


func build(small_line: String, big_line: String) -> void:
	custom_minimum_size = Vector2(VIEW_SIZE) * PIXEL_SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(viewport)

	var small := _make_label(small_line, 14)
	small.position = Vector2(4.0, 1.0)
	viewport.add_child(small)
	var big := _make_label(big_line, 40)
	big.position = Vector2(2.0, 12.0)
	viewport.add_child(big)

	# Готичні «шипи»: тонкі лінії з обох боків малого рядка.
	for x_range in [Vector2(118.0, 176.0)]:
		var rule := ColorRect.new()
		rule.color = Color(1.0, 1.0, 1.0, 1.0)
		rule.position = Vector2(x_range.x, 8.0)
		rule.size = Vector2(x_range.y - x_range.x, 1.0)
		viewport.add_child(rule)

	var display := TextureRect.new()
	display.texture = viewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER_CODE
	var material := ShaderMaterial.new()
	material.shader = shader
	display.material = material
	add_child(display)

	# Тінь-дублікат зі зсувом — об'єм «вирізаного в камені» напису.
	var shadow := TextureRect.new()
	shadow.texture = viewport.get_texture()
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_SCALE
	shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shadow.offset_left = PIXEL_SCALE
	shadow.offset_top = PIXEL_SCALE
	shadow.offset_right = PIXEL_SCALE
	shadow.offset_bottom = PIXEL_SCALE
	shadow.modulate = Color(0.0, 0.0, 0.0, 0.7)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shadow)
	move_child(shadow, 1)


func _make_label(text_value: String, size_value: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 3)
	return label
