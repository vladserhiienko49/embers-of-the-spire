class_name EyeBossBrain
extends Node
## Поведінка Стража Ока: три фази, телепорти з попередженням (червоне коло + дзвін у місці появи),
## удари мечем, кільцева ударна хвиля (перестрибнути), залпи вогняних очей і удар-телепорт за спину.
## Керує тілом ashen_wraith (CharacterBody3D) замість його звичайного переслідування.

const ARENA_TP_RADIUS: float = 13.0

var w: CharacterBody3D = null
var world = null
var invulnerable: bool = false
var phase: int = 1
var _state: String = "intro"
var _t: float = 0.0
var _cd_slash: float = 1.0
var _cd_special: float = 4.0
var _cd_tp: float = 9.0
var _special_i: int = 0
var _hit_done: bool = false
var _combo: int = 0
var _dest: Vector3 = Vector3.ZERO
var _marker: Node3D = null
var _ring: MeshInstance3D = null
var _ring_r: float = 0.0
var _ring_max: float = 13.0
var _ring_hit: bool = false
var _orbs: Array = []
var _volley_left: int = 0
var _volley_t: float = 0.0
var _summoned: bool = false
var _base_scale: Vector3 = Vector3.ONE
var _glow_mat: Material = null


func setup(body: CharacterBody3D, world_node) -> void:
	w = body
	world = world_node
	_base_scale = w.scale
	_glow_mat = PSXMaterials.make(Color(1.0, 0.2, 0.08, 0.55), 0.0, 1.0, Color("#ff2a10"), 2.6, "none", false, true)


func _player() -> CharacterBody3D:
	return w.target


func _arena_center() -> Vector3:
	return world.to_global(world.get_arena_center_local())


func _altar() -> Vector3:
	return world.to_global(world.get_arena_altar_local())


func _ground(at: Vector3) -> Vector3:
	var l: Vector3 = world.to_local(at)
	l.y = world._terrain_height_at_world(l.x, l.z)
	return world.to_global(l)


func _rig() -> Node3D:
	return w.get("_rig") as Node3D


func _face(target: Vector3, delta: float, rate: float = 7.0) -> void:
	var d := target - w.global_position
	d.y = 0.0
	if d.length() < 0.05:
		return
	w.rotation.y = lerp_angle(w.rotation.y, atan2(-d.x, -d.z), minf(1.0, delta * rate))


func _shake(amount: float) -> void:
	var p := _player()
	if p:
		var fx = p.get("fx")
		if fx:
			fx.add_trauma(amount)


func _hurt(amount: float) -> void:
	var p := _player()
	if p and p.has_method("take_damage"):
		p.call("take_damage", amount, w)


# --- Головний цикл ---------------------------------------------------------------------------------

func tick(delta: float) -> void:
	_t += delta
	_update_orbs(delta)
	_update_ring(delta)
	var p := _player()
	if _state != "away" and not w.is_on_floor():
		w.velocity += w.get_gravity() * delta
	if p == null or not is_instance_valid(p) or not bool(p.get("controls_enabled")):
		w.velocity.x = 0.0
		w.velocity.z = 0.0
		if _state != "away":
			w.move_and_slide()
		return
	_check_phase()
	_cd_slash -= delta
	_cd_special -= delta
	_cd_tp -= delta
	var rig := _rig()
	var to_p := p.global_position - w.global_position
	to_p.y = 0.0
	var dist := to_p.length()
	# Ідеальне парирування гравця збиває Стража з ритму.
	if float(w.get("stagger_timer")) > 0.9 and _state in ["chase", "slash"]:
		_state = "stunned"
		_t = 0.0
		if rig:
			rig.call("cancel_attack")
	match _state:
		"intro":
			w.velocity = Vector3.ZERO
			_face(p.global_position, delta)
			if _t > 1.6:
				_go("chase")
		"stunned":
			w.velocity.x = 0.0
			w.velocity.z = 0.0
			if _t > 1.1:
				_go("chase")
		"chase":
			_face(p.global_position, delta)
			var speed := [2.7, 3.3, 4.0][phase - 1] as float
			if dist > 3.2:
				var dir := to_p.normalized()
				w.velocity.x = dir.x * speed
				w.velocity.z = dir.z * speed
			else:
				w.velocity.x = 0.0
				w.velocity.z = 0.0
			if rig:
				rig.set("walk", clampf(Vector2(w.velocity.x, w.velocity.z).length() / speed, 0.0, 1.0))
			if dist < 3.6 and _cd_slash <= 0.0:
				_combo = 2 if phase == 3 else 1
				_go("slash")
			elif _cd_tp <= 0.0:
				if phase == 3 and randf() < 0.5:
					_go("tp_strike")
				else:
					_begin_vanish(_random_destination(p.global_position))
			elif _cd_special <= 0.0:
				_choose_special()
		"slash":
			w.velocity.x = 0.0
			w.velocity.z = 0.0
			_face(p.global_position, delta, 3.0)
			if _t < 0.02 and rig:
				rig.call("start_attack", 0.62 if phase < 3 else 0.48)
				_hit_done = false
			var hit_at := 0.66 if phase < 3 else 0.52
			if _t >= hit_at and not _hit_done:
				_hit_done = true
				if dist < 4.0:
					_hurt([30.0, 34.0, 38.0][phase - 1] as float)
				AudioManager.play_sfx_3d("wraith_swing", w.global_position, 2.0, 40.0, 6.0)
			if _t > hit_at + 0.5:
				_combo -= 1
				if _combo > 0:
					_go("slash")
				else:
					_cd_slash = [2.0, 1.6, 1.2][phase - 1] as float
					_go("chase")
		"slam":
			w.velocity.x = 0.0
			w.velocity.z = 0.0
			if _t < 0.02:
				if rig:
					rig.call("start_attack", 0.85)
				AudioManager.play_sfx_3d("wraith_growl", w.global_position, 4.0, 60.0, 8.0)
			if _t >= 0.9 and _ring == null:
				_spawn_ring(w.global_position, 13.0)
				_shake(0.45)
				AudioManager.play_sfx_3d("block_thud", w.global_position, 6.0, 60.0, 8.0)
			if _t > 1.6:
				_cd_special = [6.0, 4.5, 3.5][phase - 1] as float
				_go("chase")
		"volley":
			w.velocity.x = 0.0
			w.velocity.z = 0.0
			_face(p.global_position, delta)
			_volley_t -= delta
			if _volley_left > 0 and _volley_t <= 0.0:
				_volley_left -= 1
				_volley_t = 0.28
				_spawn_orb(p)
			if _volley_left <= 0 and _t > 1.6:
				_cd_special = [6.0, 4.0, 3.2][phase - 1] as float
				_go("chase")
		"vanishing":
			# Страж тане (0.35 с), у місці появи вже горить коло.
			w.velocity = Vector3.ZERO
			var k := clampf(_t / 0.35, 0.0, 1.0)
			w.scale = _base_scale * lerpf(1.0, 0.05, k)
			if k >= 1.0:
				_go("away")
		"away":
			if _t >= (1.1 if phase < 3 else 0.85):
				_appear()
		"appearing":
			var k2 := clampf(_t / 0.3, 0.0, 1.0)
			w.scale = _base_scale * lerpf(0.05, 1.0, k2)
			if k2 >= 1.0:
				invulnerable = false
				w.collision_layer = 2
				_go("chase")
		"tp_strike":
			# Коло слідує за героєм 1 с, потім фіксується; Страж падає з неба просто туди.
			w.velocity = Vector3.ZERO
			if _t < 0.02:
				_dest = _ground(p.global_position)
				_place_marker(_dest, 3.2)
				_vanish_now()
				AudioManager.play_sfx("distant_bell", 2.0, 0.0)
			if _t < 1.0:
				_dest = _ground(p.global_position)
				if _marker:
					_marker.global_position = _dest + Vector3(0, 0.08, 0)
			if _t >= 1.45:
				w.global_position = _dest + Vector3(0, 0.3, 0)
				w.scale = _base_scale
				_clear_marker()
				invulnerable = false
				w.collision_layer = 2
				_shake(0.6)
				AudioManager.play_sfx_3d("block_thud", _dest, 8.0, 60.0, 8.0)
				var pd := p.global_position - _dest
				pd.y = 0.0
				if pd.length() < 3.2:
					_hurt(30.0)
				_spawn_ring(_dest, 6.0)
				_cd_tp = 6.0
				_go("chase")
	if _state != "away" and _state != "vanishing":
		w.move_and_slide()


func _go(state: String) -> void:
	_state = state
	_t = 0.0


func _check_phase() -> void:
	var ratio := float(w.get("health")) / maxf(float(w.get("max_health")), 1.0)
	var want := 1 if ratio > 0.66 else (2 if ratio > 0.33 else 3)
	if want <= phase:
		return
	phase = want
	var main = world.get_parent()
	if phase == 2:
		main.call("_show_story_toast", "СТРАЖ ЛЮТУЄ", "Око відкривається ширше: Страж метає вогняні зіниці. Ухиляйся або прикривайся щитом!", 4.5)
	else:
		main.call("_show_story_toast", "ОСТАННІЙ ПОДИХ ОКА", "Страж розривається між тінями й падає з неба там, де стоїш. Тікай із червоного кола!", 4.5)
		if not _summoned:
			_summoned = true
			for i in range(2):
				var a := TAU * float(i) / 2.0 + 0.7
				var pos: Vector3 = world.get_arena_center_local() + Vector3(cos(a), 0, sin(a)) * 12.0
				pos.y = world._terrain_height_at_world(pos.x, pos.z)
				world._spawn_special_wraith(pos, {"enemy_type": "ashen_wraith", "display_name": "Тінь Ока", "max_health": 70.0, "detection_range": 40.0})
	AudioManager.play_sfx_3d("wraith_growl", w.global_position, 6.0, 80.0, 10.0)
	_shake(0.5)
	_begin_vanish(_random_destination(_player().global_position if _player() else w.global_position))


func _choose_special() -> void:
	_special_i += 1
	match phase:
		1:
			_go("slam")
		2:
			if _special_i % 2 == 0:
				_go("slam")
			else:
				_volley_left = 3
				_volley_t = 0.4
				_go("volley")
		_:
			if _special_i % 3 == 0:
				_go("slam")
			else:
				_volley_left = 5
				_volley_t = 0.3
				_go("volley")


# --- Телепорт -------------------------------------------------------------------------------------------

func _random_destination(player_pos: Vector3) -> Vector3:
	var c := _arena_center()
	var altar := _altar()
	for i in range(16):
		var a := randf() * TAU
		var r := randf_range(4.0, ARENA_TP_RADIUS)
		var p := c + Vector3(cos(a), 0, sin(a)) * r
		if Vector2(p.x - player_pos.x, p.z - player_pos.z).length() < 6.5:
			continue
		if Vector2(p.x - altar.x, p.z - altar.z).length() < 9.0:
			continue
		return _ground(p)
	return _ground(c)


func _vanish_now() -> void:
	invulnerable = true
	w.collision_layer = 0
	w.scale = _base_scale * 0.05
	var rig := _rig()
	if rig:
		rig.call("cancel_attack")


func _begin_vanish(dest: Vector3) -> void:
	_dest = dest
	invulnerable = true
	w.collision_layer = 0
	_place_marker(dest, 2.6)
	AudioManager.play_sfx_3d("distant_bell", dest, 4.0, 70.0, 10.0)
	AudioManager.play_sfx_3d("wraith_hurt", w.global_position, 0.0, 40.0, 6.0)
	_cd_tp = [11.0, 8.0, 6.0][phase - 1] as float
	_go("vanishing")


func _appear() -> void:
	w.global_position = _dest + Vector3(0, 0.3, 0)
	w.velocity = Vector3.ZERO
	_clear_marker()
	AudioManager.play_sfx_3d("wraith_growl", _dest, 3.0, 60.0, 8.0)
	_go("appearing")


func _place_marker(at: Vector3, radius: float) -> void:
	_clear_marker()
	_marker = Node3D.new()
	w.get_parent().add_child(_marker)
	_marker.global_position = at + Vector3(0, 0.08, 0)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.25
	torus.outer_radius = radius
	torus.rings = 24
	torus.ring_segments = 4
	ring.mesh = torus
	ring.material_override = _glow_mat
	_marker.add_child(ring)
	var core := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius * 0.35
	cyl.bottom_radius = radius * 0.35
	cyl.height = 0.03
	core.mesh = cyl
	core.material_override = _glow_mat
	_marker.add_child(core)
	var light := OmniLight3D.new()
	light.light_color = Color("#ff3a1a")
	light.light_energy = 2.5
	light.omni_range = radius * 2.5
	light.position = Vector3(0, 1.0, 0)
	_marker.add_child(light)
	var tw := _marker.create_tween().set_loops()
	tw.tween_property(ring, "scale", Vector3.ONE * 0.8, 0.25)
	tw.tween_property(ring, "scale", Vector3.ONE, 0.25)


func _clear_marker() -> void:
	if _marker and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null


# --- Ударна хвиля ----------------------------------------------------------------------------------------

func _spawn_ring(at: Vector3, max_r: float) -> void:
	if _ring and is_instance_valid(_ring):
		_ring.queue_free()
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.82
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 4
	_ring.mesh = torus
	_ring.material_override = _glow_mat
	w.get_parent().add_child(_ring)
	_ring.global_position = _ground(at) + Vector3(0, 0.25, 0)
	_ring.scale = Vector3(0.1, 1.5, 0.1)
	_ring_r = 0.1
	_ring_max = max_r
	_ring_hit = false


func _update_ring(delta: float) -> void:
	if _ring == null or not is_instance_valid(_ring):
		return
	_ring_r += delta * 12.0
	_ring.scale = Vector3(_ring_r, 1.5, _ring_r)
	var p := _player()
	if p and not _ring_hit:
		var d := Vector2(p.global_position.x - _ring.global_position.x, p.global_position.z - _ring.global_position.z).length()
		# Хвиля котиться по землі: стрибок (Space) її пропускає.
		if absf(d - _ring_r) < 0.9 and p.global_position.y - _ring.global_position.y < 1.9:
			_ring_hit = true
			_hurt(22.0)
	if _ring_r >= _ring_max:
		_ring.queue_free()
		_ring = null


# --- Вогняні зіниці ----------------------------------------------------------------------------------------

func _spawn_orb(p: CharacterBody3D) -> void:
	var orb := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.45
	s.height = 0.9
	s.radial_segments = 8
	s.rings = 4
	orb.mesh = s
	orb.material_override = PSXMaterials.make(Color("#ff5a20"), 0.0, 0.4, Color("#ff3010"), 4.0, "none", false)
	var pupil := MeshInstance3D.new()
	var ps := SphereMesh.new()
	ps.radius = 0.2
	ps.height = 0.4
	ps.radial_segments = 6
	ps.rings = 3
	pupil.mesh = ps
	pupil.material_override = PSXMaterials.make(Color("#050304"), 0.0, 1.0, Color.BLACK, 0.0, "none", false)
	pupil.position = Vector3(0, 0, -0.33)
	orb.add_child(pupil)
	var light := OmniLight3D.new()
	light.light_color = Color("#ff4a1a")
	light.light_energy = 1.4
	light.omni_range = 5.0
	orb.add_child(light)
	w.get_parent().add_child(orb)
	var start := w.global_position + Vector3(0, 3.2 * _base_scale.y / 1.7, 0) + w.global_transform.basis.x * randf_range(-1.2, 1.2)
	orb.global_position = start
	var aim := p.global_position + Vector3(0, 0.8, 0) + p.velocity * 0.4
	_orbs.append({"node": orb, "vel": (aim - start).normalized() * (9.0 + float(phase)), "life": 4.0})
	AudioManager.play_sfx_3d("torch_on", start, 2.0, 40.0, 6.0)


func _update_orbs(delta: float) -> void:
	var p := _player()
	for i in range(_orbs.size() - 1, -1, -1):
		var o: Dictionary = _orbs[i]
		var node: MeshInstance3D = o["node"]
		if not is_instance_valid(node):
			_orbs.remove_at(i)
			continue
		o["life"] = float(o["life"]) - delta
		if p and is_instance_valid(p):
			# Легке самонаведення — але від нього можна відбігти вбік.
			var want := (p.global_position + Vector3(0, 0.8, 0) - node.global_position).normalized() * (o["vel"] as Vector3).length()
			o["vel"] = (o["vel"] as Vector3).lerp(want, delta * 0.7)
		node.global_position += (o["vel"] as Vector3) * delta
		node.look_at(node.global_position + (o["vel"] as Vector3), Vector3.UP)
		var hit := false
		if p and node.global_position.distance_to(p.global_position + Vector3(0, 0.8, 0)) < 1.1:
			_hurt(12.0)
			hit = true
		if hit or float(o["life"]) <= 0.0 or node.global_position.y < _ground(node.global_position).y:
			node.queue_free()
			_orbs.remove_at(i)


func cleanup() -> void:
	_clear_marker()
	if _ring and is_instance_valid(_ring):
		_ring.queue_free()
	for o in _orbs:
		if is_instance_valid(o["node"]):
			(o["node"] as Node).queue_free()
	_orbs.clear()
