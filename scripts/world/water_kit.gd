class_name WaterKit
extends RefCounted
## Водяні поверхні Embers of the Spire: стрічка річки з напрямком течії та диск озера.
## Матеріал — shaders/water_psx.gdshader; кольори неба/світла оновлюються з циклу дня й ночі.

const SHADER: Shader = preload("res://shaders/water_psx.gdshader")


static func make_material(swirl: float = 0.0, shore_depth: float = 0.3, edge_fade: bool = true) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("swirl", swirl)
	mat.set_shader_parameter("shore_depth", shore_depth)
	mat.set_shader_parameter("foam_depth", minf(shore_depth * 0.2, 0.07))
	mat.set_shader_parameter("edge_fade", edge_fade)
	mat.render_priority = -2
	return mat


static func update_material(mat: ShaderMaterial, night: float, daylight_dir: Vector3, moon_dir: Vector3) -> void:
	var day := 1.0 - night
	mat.set_shader_parameter("sky_horizon", Color("#22283f").lerp(Color("#707580"), day))
	mat.set_shader_parameter("sky_zenith", Color("#05070f").lerp(Color("#3d4658"), day))
	mat.set_shader_parameter("light_color", Color("#9db3e8").lerp(Color("#f0c89a"), day * 0.8))
	mat.set_shader_parameter("light_dir", moon_dir.lerp(daylight_dir, day).normalized())
	mat.set_shader_parameter("brightness", lerpf(0.5, 0.95, day))


static func _smooth(points: Array, subdivisions: int) -> Array:
	if points.size() < 3:
		return points
	var result: Array = []
	for i in range(points.size() - 1):
		var p0: Vector3 = points[maxi(i - 1, 0)]
		var p1: Vector3 = points[i]
		var p2: Vector3 = points[i + 1]
		var p3: Vector3 = points[mini(i + 2, points.size() - 1)]
		for s in range(subdivisions):
			var t := float(s) / float(subdivisions)
			var t2 := t * t
			var t3 := t2 * t
			result.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	result.append(points[points.size() - 1])
	return result


static func build_ribbon(parent: Node3D, node_name: String, center_points: Array, width: float, material: Material) -> MeshInstance3D:
	## center_points — точки русла (x, y рівня води, z), з'єднуються гладкою кривою. Колір вершин = напрямок течії.
	var pts := _smooth(center_points, 8)
	# Згладжуємо рівень води, щоб не було ступенів між сегментами.
	for pass_index in range(3):
		for i in range(1, pts.size() - 1):
			var v: Vector3 = pts[i]
			v.y = (pts[i - 1].y + pts[i].y * 2.0 + pts[i + 1].y) * 0.25
			pts[i] = v
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in range(pts.size()):
		var p: Vector3 = pts[i]
		var prev: Vector3 = pts[maxi(i - 1, 0)]
		var next: Vector3 = pts[mini(i + 1, pts.size() - 1)]
		var dir := Vector3(next.x - prev.x, 0.0, next.z - prev.z)
		if dir.length() < 0.001:
			dir = Vector3(0, 0, 1)
		dir = dir.normalized()
		var side := Vector3(-dir.z, 0.0, dir.x)
		# Русло злегка розширюється й звужується.
		var w := width * (0.5 + 0.08 * sin(float(i) * 0.7))
		for s in [-1.0, 1.0]:
			verts.append(p + side * w * float(s))
			normals.append(Vector3.UP)
			uvs.append(Vector2(0.5 + 0.5 * float(s), float(i)))
			colors.append(Color(dir.x * 0.5 + 0.5, dir.z * 0.5 + 0.5, 0.0, 1.0))
	for i in range(pts.size() - 1):
		var a := i * 2
		indices.append_array([a, a + 2, a + 1, a + 1, a + 2, a + 3])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


static func build_disc(parent: Node3D, node_name: String, center: Vector3, radius: float, material: Material) -> MeshInstance3D:
	## Озеро: плоский диск; течії немає (flow = 0), лише вихор у шейдері.
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var segments := 48
	var rings := 6
	verts.append(Vector3.ZERO)
	normals.append(Vector3.UP)
	colors.append(Color(0.5, 0.5, 0.0, 1.0))
	for r in range(1, rings + 1):
		for s in range(segments):
			var a := TAU * float(s) / float(segments)
			verts.append(Vector3(cos(a), 0.0, sin(a)) * radius * float(r) / float(rings))
			normals.append(Vector3.UP)
			colors.append(Color(0.5, 0.5, 0.0, 1.0))
	for s in range(segments):
		indices.append_array([0, 1 + (s + 1) % segments, 1 + s])
	for r in range(1, rings):
		var inner := 1 + (r - 1) * segments
		var outer := 1 + r * segments
		for s in range(segments):
			var n := (s + 1) % segments
			indices.append_array([inner + s, inner + n, outer + s, outer + s, inner + n, outer + n])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = center
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node
