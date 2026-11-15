extends Control

var particles: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	randomize()
	var viewport_size: Vector2 = get_viewport_rect().size
	for i in range(72):
		particles.append({
			"position": Vector2(randf_range(0.0, viewport_size.x), randf_range(0.0, viewport_size.y)),
			"speed": randf_range(9.0, 32.0),
			"size": randf_range(1.0, 2.6),
			"alpha": randf_range(0.16, 0.65),
			"drift": randf_range(-8.0, 8.0),
			"phase": randf_range(0.0, TAU)
		})


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	for i in range(particles.size()):
		var particle: Dictionary = particles[i]
		var pos: Vector2 = particle["position"]
		pos.y -= float(particle["speed"]) * delta
		pos.x += (float(particle["drift"]) + sin(Time.get_ticks_msec() * 0.0007 + float(particle["phase"])) * 5.0) * delta
		if pos.y < -8.0:
			pos.y = viewport_size.y + randf_range(0.0, 35.0)
			pos.x = randf_range(0.0, viewport_size.x)
		particle["position"] = pos
		particles[i] = particle
	queue_redraw()


func _draw() -> void:
	for particle in particles:
		var pos: Vector2 = particle["position"]
		var size: float = particle["size"]
		var alpha: float = particle["alpha"]
		draw_circle(pos, size * 2.7, Color(0.95, 0.34, 0.10, alpha * 0.12))
		draw_circle(pos, size, Color(1.0, 0.65, 0.30, alpha))
