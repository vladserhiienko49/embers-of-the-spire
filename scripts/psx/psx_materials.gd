class_name PSXMaterials
extends RefCounted
## Фабрика PSX-матеріалів (вершинне тремтіння + nearest-текстури)
## і конвертер наявних StandardMaterial3D у дереві сцени.

const SHADER_OPAQUE: Shader = preload("res://shaders/psx_lit.gdshader")
const SHADER_ALPHA: Shader = preload("res://shaders/psx_lit_alpha.gdshader")

## Щільність текстури (повторів на метр у світових координатах).
const DENSITY: Dictionary = {
	"grime": 0.35, "stone": 0.4, "rock": 0.14, "brick": 0.38, "tiles": 0.3,
	"planks": 0.45, "shingles": 0.5, "thatch": 0.4, "bark": 0.55, "foliage": 0.32,
	"metal": 0.9, "cloth": 0.9, "plaster": 0.28, "dirt": 0.22, "grass": 0.3
}
const LOCAL_DENSITY_MULTIPLIER: float = 2.6

static var _converted: Dictionary = {}


static func make(color: Color, metallic: float = 0.0, roughness: float = 0.85,
		emission: Color = Color.BLACK, emission_energy: float = 0.0,
		detail: String = "grime", world_space: bool = true, transparent: bool = false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_ALPHA if (transparent or color.a < 0.999) else SHADER_OPAQUE
	mat.set_shader_parameter("albedo_color", color)
	# PS1 не мав відбиттів: метал лише трохи блищить, а не чорніє.
	mat.set_shader_parameter("metallic_value", metallic * 0.55)
	# Неметалеві поверхні (камінь, дерево, земля, тканина) — повністю матові.
	if metallic < 0.5:
		mat.set_shader_parameter("roughness_value", maxf(roughness, 0.95))
		mat.set_shader_parameter("specular_value", 0.0)
	else:
		mat.set_shader_parameter("roughness_value", maxf(roughness, 0.35))
		mat.set_shader_parameter("specular_value", metallic * 0.5)
	mat.set_shader_parameter("emission_color", emission)
	mat.set_shader_parameter("emission_energy", emission_energy)
	mat.set_shader_parameter("world_space_detail", world_space)
	if detail.is_empty() or detail == "none":
		mat.set_shader_parameter("detail_strength", 0.0)
	else:
		mat.set_shader_parameter("detail_texture", PSXTextures.get_texture(detail))
		var density := float(DENSITY.get(detail, 0.4))
		if not world_space:
			density *= LOCAL_DENSITY_MULTIPLIER
		mat.set_shader_parameter("texel_density", density)
	return mat


static func from_standard(source: StandardMaterial3D, world_space: bool) -> Material:
	## Повертає PSX-еквівалент або null, якщо матеріал варто лишити як є.
	if source == null:
		return null
	# Вершинні кольори без текстури — це ефекти (слід меча); їх не чіпаємо.
	if source.vertex_color_use_as_albedo and source.albedo_texture == null:
		return null
	if source.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return null
	if source.has_meta("psx_skip"):
		return null
	var key := "%d_%s" % [source.get_instance_id(), str(world_space)]
	if _converted.has(key):
		return _converted[key]

	var emission := Color.BLACK
	var energy := 0.0
	if source.emission_enabled:
		emission = source.emission
		energy = source.emission_energy_multiplier
	var detail := "metal" if source.metallic >= 0.5 else "grime"
	if energy > 0.5:
		detail = "none"
	var transparent := source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	var color := source.albedo_color
	if not transparent:
		color.a = 1.0
	var mat := make(color, source.metallic, source.roughness, emission, energy, detail, world_space, transparent)
	if source.albedo_texture:
		mat.set_shader_parameter("use_albedo_texture", true)
		mat.set_shader_parameter("albedo_texture", source.albedo_texture)
		mat.set_shader_parameter("uv_scale", Vector2(source.uv1_scale.x, source.uv1_scale.y))
		mat.set_shader_parameter("detail_strength", 0.2)
	_converted[key] = mat
	return mat


static func convert_tree(root: Node, world_space: bool = true) -> int:
	## Обходить піддерево й замінює StandardMaterial3D на PSX. Повертає кількість замін.
	var count := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node.has_meta("psx_skip"):
			continue
		if node is MeshInstance3D:
			count += _convert_mesh_instance(node as MeshInstance3D, world_space)
		elif node is CSGShape3D and "material" in node:
			var csg_mat = node.get("material")
			if csg_mat is StandardMaterial3D:
				var converted := from_standard(csg_mat, world_space)
				if converted:
					node.set("material", converted)
					count += 1
		for child in node.get_children():
			stack.append(child)
	return count


static func _convert_mesh_instance(mi: MeshInstance3D, world_space: bool) -> int:
	var count := 0
	if mi.material_override is StandardMaterial3D:
		var converted := from_standard(mi.material_override, world_space)
		if converted:
			mi.material_override = converted
			count += 1
		return count
	if mi.material_override != null or mi.mesh == null:
		return count
	for surface in range(mi.mesh.get_surface_count()):
		var mat := mi.get_surface_override_material(surface)
		if mat == null:
			mat = mi.mesh.surface_get_material(surface)
		if mat is StandardMaterial3D:
			var converted := from_standard(mat, world_space)
			if converted:
				mi.set_surface_override_material(surface, converted)
				count += 1
	return count


# --- Зміна параметрів, сумісна з обома типами матеріалів ----------------------

static func set_albedo(mat: Material, color: Color) -> void:
	if mat is ShaderMaterial:
		(mat as ShaderMaterial).set_shader_parameter("albedo_color", color)
	elif mat is StandardMaterial3D:
		(mat as StandardMaterial3D).albedo_color = color


static func set_emission(mat: Material, color: Color, energy: float = -1.0) -> void:
	if mat is ShaderMaterial:
		(mat as ShaderMaterial).set_shader_parameter("emission_color", color)
		if energy >= 0.0:
			(mat as ShaderMaterial).set_shader_parameter("emission_energy", energy)
	elif mat is StandardMaterial3D:
		var std := mat as StandardMaterial3D
		std.emission_enabled = true
		std.emission = color
		if energy >= 0.0:
			std.emission_energy_multiplier = energy


static func set_emission_energy(mat: Material, energy: float) -> void:
	if mat is ShaderMaterial:
		(mat as ShaderMaterial).set_shader_parameter("emission_energy", energy)
	elif mat is StandardMaterial3D:
		(mat as StandardMaterial3D).emission_energy_multiplier = energy
