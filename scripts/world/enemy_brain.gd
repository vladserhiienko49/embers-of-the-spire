class_name EnemyBrain
extends Node
## «Мозок» нових ворогів поверх базового ashen_wraith (здоров'я, шкода, смерть, нагорода лишаються там).
##  • skeleton_witch — Скелетна відьма: тримає дистанцію, відступає, б'є посохом (кістяна куля з попередженням)
##    і призиває скелетів із землі (темні кола-попередження → тріщини → руки → скелети виповзають).
##    Ліміт одночасних скелетів, перезарядка, перерва при ударі в момент чаклунства. Мертва — не призиває.
##  • skirmisher — швидкий скелет-воїн: кружляє навколо гравця (оточення зграєю), стрибком кидається й відходить.
##  • bone_knight — важкий лицар-мрець: повільний, стійкий до відкидання, подвійний удар із червоним колом-попередженням.
##  • bone_seer — віщун: б'є вогняними кулями здалеку й блимає (телепортує) геть, коли підійти впритул.

const MAX_MINIONS: int = 4
const SUMMON_CD: float = 15.0

var w: CharacterBody3D = null
var world = null
var kind: String = ""
var invulnerable: bool = false

var _state: String = "idle"
var _t: float = 0.0
var _aware: bool = false
var _cd_bolt: float = 2.0
var _cd_summon: float = 4.0
var _cd_blink: float = 0.0
var _cd_lunge: float = 1.5
var _cd_sweep: float = 5.0
var _hit_done: bool = false
var _minions: Array = []
var _rings: Array = []
var _spots: Array = []
var _telegraph: MeshInstance3D = null
var _ground_mark: MeshInstance3D = null
var _strafe: float = 1.0
var _slot: float = 0.0
var _ring_radius: float = 5.5
var _sweep: bool = false
var _base_scale: Vector3 = Vector3.ONE
var _burst: int = 0

const PARAMS: Dictionary = {
	"skeleton_witch": {"detect": 40.0, "speed": 3.4},
	"skirmisher": {"detect": 34.0, "speed": 6.0},
	"bone_knight": {"detect": 26.0, "speed": 1.9},
	"bone_seer": {"detect": 42.0, "speed": 3.0},
	"ancient_mage": {"detect": 55.0, "speed": 3.4},
}


func setup(body: CharacterBody3D, world_node, brain_kind: String) -> void:
	w = body
	world = world_node
	kind = brain_kind
	_base_scale = w.scale
	_strafe = 1.0 if randf() < 0.5 else -1.0
	_slot = float(w.get_instance_id() % 7) * TAU / 7.0
	_ring_radius = randf_range(4.6, 6.8)
	_cd_lunge = randf_range(1.0, 3.0)
	_cd_bolt = randf_range(1.5, 3.0)
	_cd_summon = randf_range(2.5, 4.5)


func modify_damage(amount: float) -> float:
	return amount * (0.65 if kind == "bone_knight" else 1.0)


func cleanup() -> void:
	## Відьма мертва — нові скелети не з'являться; кола-попередження й телеграфи зникають.
	_clear_rings()
	_clear_telegraph()
	_clear_ground_mark()
	_mage_cleanup()
	var rig := _rig()
	if rig:
		rig.set("cast", 0.0)


func _rig() -> Node3D:
	return w.get("_rig") as Node3D


func _player() -> CharacterBody3D:
	return w.target


func _speed() -> float:
	return float(PARAMS[kind]["speed"])


func _face(target: Vector3, delta: float, rate: float = 8.0) -> void:
	var d := target - w.global_position
	d.y = 0.0
	if d.length() < 0.05:
		return
	w.rotation.y = lerp_angle(w.rotation.y, atan2(-d.x, -d.z), minf(1.0, delta * rate))


func _hurt(amount: float) -> void:
	var p := _player()
	if p and p.has_method("take_damage"):
		p.call("take_damage", amount, w)


func _shake(amount: float) -> void:
	var p := _player()
	if p:
		var fx = p.get("fx")
		if fx:
			fx.add_trauma(amount)


func _ground_at(global_pos: Vector3) -> Vector3:
	var l: Vector3 = world.to_local(global_pos)
	l.y = world._terrain_height_at_world(l.x, l.z)
	return world.to_global(l)


func _walk_anim(speed_ref: float) -> void:
	var rig := _rig()
	if rig:
		rig.set("walk", clampf(Vector2(w.velocity.x, w.velocity.z).length() / maxf(speed_ref, 0.1), 0.0, 1.0))


func _stop() -> void:
	w.velocity.x = 0.0
	w.velocity.z = 0.0


func _move_toward(dir: Vector3, speed: float) -> void:
	w.velocity.x = dir.x * speed
	w.velocity.z = dir.z * speed


# --- Головний цикл ----------------------------------------------------------------------------------

func _has_floor(global_pos: Vector3) -> bool:
	## Є реальна поверхня під точкою (щоб телепорт не кинув ворога в прірву чи під воду).
	var space := w.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_pos + Vector3(0, 6.0, 0), global_pos + Vector3(0, -10.0, 0), 1)
	return not space.intersect_ray(q).is_empty()


func _anti_fall() -> void:
	## Страховка: якщо тіло опинилось нижче рельєфу — повертаємо на землю (ніхто не провалюється).
	var l: Vector3 = world.to_local(w.global_position)
	var g: float = world._terrain_height_at_world(l.x, l.z)
	if l.y < g - 5.0:
		l.y = g + 0.6
		w.global_position = world.to_global(l)
		w.velocity = Vector3.ZERO


func tick(delta: float) -> void:
	_anti_fall()
	if not w.is_on_floor():
		w.velocity += w.get_gravity() * delta
	var p := _player()
	if p == null or not is_instance_valid(p) or not bool(p.get("controls_enabled")) or bool(p.call("is_defeated")):
		_stop()
		_walk_anim(1.0)
		w.move_and_slide()
		return
	_t += delta
	_cd_bolt -= delta
	_cd_summon -= delta
	_cd_blink -= delta
	_cd_lunge -= delta
	_cd_sweep -= delta
	var to_p := p.global_position - w.global_position
	to_p.y = 0.0
	var dist := to_p.length()
	var detect: float = float(PARAMS[kind]["detect"])
	if not _aware:
		if dist <= detect:
			_aware = true
			AudioManager.play_sfx_3d("wraith_growl", w.global_position + Vector3(0, 1.5, 0), 2.0, 50.0, 7.0)
			_go("kite" if kind in ["skeleton_witch", "bone_seer", "ancient_mage"] else ("circle" if kind == "skirmisher" else "chase"))
		else:
			_stop()
			_walk_anim(1.0)
			w.move_and_slide()
			return
	elif dist > detect * 2.2:
		_aware = false
		_go("idle")
		_clear_rings()
		return
	var staggered := float(w.get("stagger_timer"))
	if kind == "bone_knight":
		# Важкий лицар не здригається від звичайних ударів; лише ідеальне парирування збиває його.
		if staggered <= 0.9:
			w.set("stagger_timer", 0.0)
			staggered = 0.0
	if staggered > 0.0:
		_stop_slide(delta)
		if kind == "skeleton_witch" and _state == "summon" and _t < 2.0:
			_interrupt_summon()
		elif _state in ["bolt", "lunge", "slam"] and staggered > 0.9:
			_cancel_attack()
		_walk_anim(1.0)
		w.move_and_slide()
		return
	match kind:
		"skeleton_witch":
			_tick_witch(delta, p, dist)
		"skirmisher":
			_tick_skirmisher(delta, p, dist)
		"bone_knight":
			_tick_knight(delta, p, dist)
		"bone_seer":
			_tick_seer(delta, p, dist)
		"ancient_mage":
			if _state in ["vanish", "appear"]:
				_tick_seer(delta, p, dist)
			else:
				_tick_mage(delta, p, dist)
	w.move_and_slide()


func _stop_slide(delta: float) -> void:
	w.velocity.x = move_toward(w.velocity.x, 0.0, 14.0 * delta)
	w.velocity.z = move_toward(w.velocity.z, 0.0, 14.0 * delta)


func _go(state: String) -> void:
	_state = state
	_t = 0.0
	_hit_done = false


func _cancel_attack() -> void:
	var rig := _rig()
	if rig:
		rig.call("cancel_attack")
	_clear_telegraph()
	_clear_ground_mark()
	_go("kite" if kind in ["skeleton_witch", "bone_seer", "ancient_mage"] else ("circle" if kind == "skirmisher" else "chase"))


# --- Скелетна відьма -----------------------------------------------------------------------------------

func _alive_minions() -> int:
	var n := 0
	for i in range(_minions.size() - 1, -1, -1):
		var m = _minions[i]
		if not is_instance_valid(m) or bool(m.get("dead")):
			_minions.remove_at(i)
		else:
			n += 1
	return n


func _player_busy(p: CharacterBody3D) -> bool:
	## Гравець зайнятий іншими ворогами — відьма використовує момент.
	var count := 0
	for e in w.get_tree().get_nodes_in_group("hostile"):
		var b := e as Node3D
		if b == null or b == w or bool(b.get("dead")) or b is Area3D:
			continue
		if b.global_position.distance_to(p.global_position) < 9.0:
			count += 1
	return count >= 1


func _tick_witch(delta: float, p: CharacterBody3D, dist: float) -> void:
	var rig := _rig()
	match _state:
		"kite":
			_face(p.global_position, delta)
			var dir := (p.global_position - w.global_position)
			dir.y = 0.0
			dir = dir.normalized()
			var side := dir.rotated(Vector3.UP, PI * 0.5) * _strafe
			if dist < 7.5:
				_move_toward(-dir * 0.85 + side * 0.5, 3.8)
			elif dist > 14.5:
				_move_toward(dir, 2.6)
			else:
				_move_toward(side, 1.3)
			if randf() < delta * 0.15:
				_strafe = -_strafe
			_walk_anim(3.8)
			var minions := _alive_minions()
			var busy := _player_busy(p)
			if _cd_summon <= 0.0 and minions < MAX_MINIONS and (dist < 26.0):
				_go("summon")
			elif _cd_bolt <= 0.0 and dist < 24.0 and (not busy or minions >= MAX_MINIONS or _cd_summon > 4.0):
				_go("bolt")
		"bolt":
			_stop()
			_face(p.global_position, delta, 10.0)
			if _t < 0.03 and rig:
				rig.call("start_attack", 0.95)
				_make_telegraph(Color("#a060ff"), 0.95)
				AudioManager.play_sfx_3d("strange_whisper", w.global_position, -6.0, 40.0, 6.0)
			if _t >= 1.0 and not _hit_done:
				_hit_done = true
				_clear_telegraph()
				var aim := p.global_position + Vector3(p.velocity.x, 0.0, p.velocity.z) * 0.25 + Vector3(0, 1.0, 0)
				_fire(aim, Color("#b070ff"), 11.5, 16.0, 0.36)
			if _t > 1.55:
				_cd_bolt = randf_range(2.4, 3.6)
				_go("kite")
		"summon":
			_stop()
			_face(p.global_position, delta, 4.0)
			_summon_step()
			_walk_anim(1.0)


func _summon_step() -> void:
	var rig := _rig()
	# 0 – 0.7 с: підняти руки; 0.2–1.9 с: кола-попередження; 1.9 с: тріщини й руки; 2.25 с: скелети виповзають.
	if _t < 0.03:
		_pick_spots()
		AudioManager.play_sfx_3d("strange_whisper", w.global_position, 2.0, 60.0, 8.0)
		AudioManager.play_sfx_3d("far_horn", w.global_position, -8.0, 60.0, 8.0)
		var tw := create_tween()
		tw.tween_property(rig, "cast", 1.0, 0.7)
		_rings = _make_rings(_spots)
	_pulse_rings()
	if _t >= 1.9 and _burst == 0:
		_burst = 1
		AudioManager.play_sfx_3d("block_thud", w.global_position, 4.0, 60.0, 8.0)
		_shake(0.18)
		for s in _spots:
			_dust(s, Color("#6a5a48"), 10)
			_bone_hands(s)
	if _t >= 2.25 and _burst == 1:
		_burst = 2
		for s in _spots:
			_raise_skeleton(s)
		_clear_rings()
	if _t > 3.3:
		var tw2 := create_tween()
		tw2.tween_property(rig, "cast", 0.0, 0.4)
		_burst = 0
		_cd_summon = SUMMON_CD
		_cd_bolt = 1.6
		_go("kite")


func _interrupt_summon() -> void:
	## Удар у момент чаклунства зриває ритуал: кола гаснуть, нових скелетів не буде, перезарядка коротша.
	_clear_rings()
	_burst = 0
	var rig := _rig()
	if rig:
		create_tween().tween_property(rig, "cast", 0.0, 0.2)
	AudioManager.play_sfx_3d("parry_ring", w.global_position, -2.0, 40.0, 6.0)
	_cd_summon = 7.0
	_go("kite")


func _pick_spots() -> void:
	_spots.clear()
	var p := _player()
	var alive := _alive_minions()
	var count := mini(3, MAX_MINIONS - alive)
	for i in range(count):
		var a := randf() * TAU
		var r := randf_range(3.8, 8.0)
		var pos := p.global_position + Vector3(cos(a), 0.0, sin(a)) * r
		if pos.distance_to(w.global_position) < 3.0:
			pos = w.global_position + Vector3(cos(a), 0.0, sin(a)) * 4.0
		_spots.append(_ground_at(pos))


func _make_rings(spots: Array) -> Array:
	var mat := PSXMaterials.make(Color(0.45, 0.08, 0.8, 0.55), 0.0, 1.0, Color("#8a30ff"), 2.4, "none", false, true)
	var out: Array = []
	for s in spots:
		var m := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 1.5
		c.bottom_radius = 1.5
		c.height = 0.04
		c.radial_segments = 14
		m.mesh = c
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.get_tree().current_scene.add_child(m)
		m.global_position = (s as Vector3) + Vector3(0, 0.1, 0)
		m.scale = Vector3(0.1, 1.0, 0.1)
		create_tween().tween_property(m, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK)
		out.append(m)
	return out


func _pulse_rings() -> void:
	var k := 1.0 + 0.08 * sin(_t * 14.0)
	for r in _rings:
		if is_instance_valid(r) and _t > 0.6:
			(r as Node3D).scale = Vector3(k, 1.0, k)


func _clear_rings() -> void:
	for r in _rings:
		if is_instance_valid(r):
			(r as Node).queue_free()
	_rings.clear()


func _dust(at: Vector3, color: Color, count: int) -> void:
	var mat := PSXMaterials.make(color, 0.0, 1.0, Color.BLACK, 0.0, "none", false)
	for i in range(count):
		var m := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3.ONE * randf_range(0.18, 0.4)
		m.mesh = bx
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.get_tree().current_scene.add_child(m)
		m.global_position = at + Vector3(randf_range(-0.6, 0.6), 0.2, randf_range(-0.6, 0.6))
		var dir := Vector3(randf_range(-1, 1), randf_range(0.6, 1.8), randf_range(-1, 1))
		var tw := m.create_tween().set_parallel(true)
		tw.tween_property(m, "global_position", m.global_position + dir * 1.4, 0.9)
		tw.tween_property(m, "scale", Vector3.ONE * 0.05, 0.9)
		tw.chain().tween_callback(m.queue_free)


func _bone_hands(at: Vector3) -> void:
	## Із тріщин вистромляються кістляві руки й тягнуться вгору.
	var bone := PSXMaterials.make(Color("#d8d0b8"), 0.0, 0.9, Color.BLACK, 0.0, "stone", false)
	for i in range(3):
		var root := Node3D.new()
		w.get_tree().current_scene.add_child(root)
		var a := TAU * float(i) / 3.0 + randf()
		root.global_position = at + Vector3(cos(a), 0.0, sin(a)) * 0.7
		root.rotation = Vector3(randf_range(-0.3, 0.3), randf() * TAU, randf_range(-0.3, 0.3))
		var arm := MeshInstance3D.new()
		var ab := BoxMesh.new()
		ab.size = Vector3(0.07, 0.7, 0.07)
		arm.mesh = ab
		arm.material_override = bone
		arm.position = Vector3(0, 0.35, 0)
		arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(arm)
		var hand := MeshInstance3D.new()
		var hb := BoxMesh.new()
		hb.size = Vector3(0.16, 0.1, 0.1)
		hand.mesh = hb
		hand.material_override = bone
		hand.position = Vector3(0, 0.75, 0)
		hand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(hand)
		root.scale = Vector3(1.0, 0.05, 1.0)
		var tw := root.create_tween()
		tw.tween_property(root, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK)
		tw.tween_interval(1.4)
		tw.tween_property(root, "scale", Vector3(1.0, 0.02, 1.0), 0.5)
		tw.tween_callback(root.queue_free)


func _raise_skeleton(at: Vector3) -> void:
	var local: Vector3 = world.to_local(at)
	var props := {"enemy_type": "skeleton", "visual_type": "skeleton", "display_name": "ПРИЗВАНИЙ СКЕЛЕТ", "max_health": 48.0, "attack_damage": 9.0,
		"move_speed": 3.5, "detection_range": 60.0, "scale": 1.0, "reward_override": 2}
	var sk = world._spawn_special_wraith(local, props)
	if sk == null:
		return
	_minions.append(sk)
	# Виповзання з-під землі: тіло не взаємодіє зі світом, поки не вибереться; потім біжить на гравця.
	sk.set_physics_process(false)
	sk.collision_layer = 0
	sk.collision_mask = 0
	sk.global_position = at + Vector3(0, -1.9, 0)
	var rig: Node3D = sk.get("_rig")
	if rig:
		rig.set("cast", 0.55)
	_dust(at, Color("#6a5a48"), 8)
	AudioManager.play_sfx_3d("step_dirt", at, 3.0, 40.0, 6.0)
	var tw: Tween = sk.create_tween()
	tw.tween_property(sk, "global_position:y", at.y + 0.05, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(sk):
			return
		sk.collision_layer = 2
		sk.collision_mask = 1
		sk.set_physics_process(true)
		if rig and is_instance_valid(rig):
			create_tween().tween_property(rig, "cast", 0.0, 0.3)
		_dust(sk.global_position, Color("#6a5a48"), 5))


# --- Снаряди --------------------------------------------------------------------------------------------------

func _make_telegraph(color: Color, duration: float) -> void:
	## Світна куля на вершині посоха росте перед пострілом — гравець бачить, що зараз прилетить.
	_clear_telegraph()
	var rig := _rig()
	if rig == null:
		return
	var parts: Dictionary = rig.get("parts")
	var grip := parts.get("grip_r") as Node3D
	if grip == null:
		return
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.2
	s.height = 0.4
	s.radial_segments = 8
	s.rings = 4
	m.mesh = s
	m.material_override = PSXMaterials.make(color, 0.0, 0.3, color, 3.5, "none", false)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = Vector3(0, 1.55, 0)
	m.scale = Vector3.ONE * 0.2
	grip.add_child(m)
	_telegraph = m
	var tw := m.create_tween()
	tw.tween_property(m, "scale", Vector3.ONE * 1.5, duration)


func _clear_telegraph() -> void:
	if _telegraph and is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null


func _make_ground_mark(center: Vector3, radius: float, color: Color) -> void:
	_clear_ground_mark()
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = 0.04
	c.radial_segments = 16
	m.mesh = c
	m.material_override = PSXMaterials.make(Color(color.r, color.g, color.b, 0.5), 0.0, 1.0, color, 2.4, "none", false, true)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.get_tree().current_scene.add_child(m)
	m.global_position = _ground_at(center) + Vector3(0, 0.1, 0)
	m.scale = Vector3(0.2, 1.0, 0.2)
	_ground_mark = m
	m.create_tween().tween_property(m, "scale", Vector3.ONE, 1.0)


func _clear_ground_mark() -> void:
	if _ground_mark and is_instance_valid(_ground_mark):
		_ground_mark.queue_free()
	_ground_mark = null


func _fire(aim: Vector3, color: Color, speed: float, damage: float, size: float) -> void:
	var rig := _rig()
	var origin := w.global_position + Vector3(0, 1.6, 0) - w.global_transform.basis.z * 0.9
	if rig:
		var parts: Dictionary = rig.get("parts")
		var grip := parts.get("grip_r") as Node3D
		if grip:
			origin = grip.global_position + Vector3(0, 1.5, 0)
	var bolt := Bolt.new()
	bolt.setup(w, _player(), (aim - origin).normalized(), speed, damage, color, size)
	w.get_tree().current_scene.add_child(bolt)
	bolt.global_position = origin
	AudioManager.play_sfx_3d("wraith_swing", origin, 1.0, 45.0, 6.0)
	AudioManager.play_sfx_3d("strange_scrape", origin, -9.0, 45.0, 6.0)


class Bolt extends Node3D:
	var owner_body: Node3D = null
	var target: Node3D = null
	var dir: Vector3 = Vector3.FORWARD
	var speed: float = 10.0
	var damage: float = 10.0
	var life: float = 4.5

	func setup(from: Node3D, to: Node3D, direction: Vector3, spd: float, dmg: float, color: Color, size: float) -> void:
		owner_body = from
		target = to
		dir = direction
		speed = spd
		damage = dmg
		var m := MeshInstance3D.new()
		var s := BoxMesh.new()
		s.size = Vector3(size, size, size * 2.2)
		m.mesh = s
		m.material_override = PSXMaterials.make(color, 0.0, 0.3, color, 3.5, "none", false)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)

	func _physics_process(delta: float) -> void:
		life -= delta
		if life <= 0.0:
			queue_free()
			return
		var step := dir * speed * delta
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(global_position, global_position + step, 1)
		if not space.intersect_ray(q).is_empty():
			queue_free()
			return
		global_position += step
		look_at(global_position + dir, Vector3.UP)
		rotate_z(life * 6.0)
		if target and is_instance_valid(target) and global_position.distance_to(target.global_position + Vector3(0, 1.0, 0)) < 0.95:
			if target.has_method("take_damage"):
				target.call("take_damage", damage, owner_body if is_instance_valid(owner_body) else null)
			queue_free()


# --- Швидкий скелет-воїн ----------------------------------------------------------------------------------------

func _tick_skirmisher(delta: float, p: CharacterBody3D, dist: float) -> void:
	var rig := _rig()
	var sp := _speed()
	match _state:
		"circle":
			_face(p.global_position, delta, 10.0)
			# Оточення: кожен займає свій кут навколо гравця, і всі повільно обертаються.
			var ang := _slot + Time.get_ticks_msec() * 0.0006 * _strafe
			var spot := p.global_position + Vector3(cos(ang), 0.0, sin(ang)) * _ring_radius
			var to_spot := spot - w.global_position
			to_spot.y = 0.0
			if to_spot.length() > 0.8:
				_move_toward(to_spot.normalized(), sp)
			else:
				_stop()
			_walk_anim(sp)
			if _cd_lunge <= 0.0 and dist < 10.0:
				_go("windup")
		"windup":
			_stop()
			_face(p.global_position, delta, 14.0)
			if _t < 0.03 and rig:
				rig.call("start_attack", 0.4)
				AudioManager.play_sfx_3d("snake_hiss", w.global_position, -4.0, 30.0, 5.0)
			if _t >= 0.42:
				_go("lunge")
		"lunge":
			var dir := p.global_position - w.global_position
			dir.y = 0.0
			dir = dir.normalized()
			_move_toward(dir, 13.0)
			w.rotation.y = atan2(-dir.x, -dir.z)
			_walk_anim(8.0)
			if not _hit_done and dist < 1.7:
				_hit_done = true
				_hurt(10.0)
				AudioManager.play_sfx_3d("hit_flesh", w.global_position, 0.0, 30.0, 5.0)
			if _t > 0.42 or _hit_done:
				_cd_lunge = randf_range(2.2, 3.8)
				_go("recover")
		"recover":
			var away := w.global_position - p.global_position
			away.y = 0.0
			_move_toward(away.normalized(), 5.0)
			_face(p.global_position, delta, 10.0)
			_walk_anim(5.0)
			if _t > 0.7:
				_go("circle")


# --- Важкий лицар-мрець ----------------------------------------------------------------------------------------

func _tick_knight(delta: float, p: CharacterBody3D, dist: float) -> void:
	var rig := _rig()
	match _state:
		"chase":
			_face(p.global_position, delta, 4.0)
			if dist > 3.4:
				var dir := (p.global_position - w.global_position)
				dir.y = 0.0
				_move_toward(dir.normalized(), _speed())
			else:
				_stop()
			_walk_anim(_speed())
			if dist < 3.9 and _cd_sweep <= 0.0 and randf() < 0.35:
				_sweep = true
				_go("slam")
			elif dist < 3.6:
				_sweep = false
				_go("slam")
		"slam":
			_stop()
			_face(p.global_position, delta, 2.5 if _t < 0.9 else 0.5)
			var windup := 1.3
			if _t < 0.03 and rig:
				rig.call("start_attack", windup)
				AudioManager.play_sfx_3d("wraith_growl", w.global_position, 4.0, 50.0, 7.0)
				var fwd := -w.global_transform.basis.z
				var center := w.global_position if _sweep else w.global_position + fwd * 2.4
				_make_ground_mark(center, 2.6 if _sweep else 2.2, Color("#ff3a20"))
			if _t >= windup + 0.05 and not _hit_done:
				_hit_done = true
				var center2 := w.global_position if _sweep else w.global_position - w.global_transform.basis.z * 2.4
				var dd := p.global_position - center2
				dd.y = 0.0
				if dd.length() < (2.7 if _sweep else 2.3):
					_hurt(24.0 if _sweep else 38.0)
				_shake(0.4)
				AudioManager.play_sfx_3d("block_thud", center2, 6.0, 60.0, 8.0)
				_dust(center2, Color("#6a5a48"), 8)
				_clear_ground_mark()
			if _t > windup + 1.0:
				_cd_sweep = randf_range(5.0, 8.0)
				_go("chase")


# --- Віщун ---------------------------------------------------------------------------------------------------------

func _tick_seer(delta: float, p: CharacterBody3D, dist: float) -> void:
	var rig := _rig()
	match _state:
		"kite":
			_face(p.global_position, delta)
			var dir := p.global_position - w.global_position
			dir.y = 0.0
			dir = dir.normalized()
			var side := dir.rotated(Vector3.UP, PI * 0.5) * _strafe
			if dist < 10.0:
				_move_toward(-dir * 0.8 + side * 0.4, 3.4)
			elif dist > 18.0:
				_move_toward(dir, 2.8)
			else:
				_move_toward(side, 1.2)
			if randf() < delta * 0.2:
				_strafe = -_strafe
			_walk_anim(3.4)
			if dist < 6.0 and _cd_blink <= 0.0:
				_go("vanish")
			elif _cd_bolt <= 0.0 and dist < 30.0:
				_burst = 3 if float(w.get("health")) < float(w.get("max_health")) * 0.5 else 1
				_go("bolt")
		"bolt":
			_stop()
			_face(p.global_position, delta, 10.0)
			if _t < 0.03 and rig:
				rig.call("start_attack", 0.85)
				_make_telegraph(Color("#ff7a20"), 0.85)
			if _t >= 0.9 and not _hit_done:
				_hit_done = true
				_clear_telegraph()
				_fire(p.global_position + Vector3(0, 1.0, 0), Color("#ff6a20"), 9.5, 14.0, 0.4)
				_burst -= 1
			if _t > 1.35:
				if _burst > 0:
					_go("bolt")
				else:
					_cd_bolt = randf_range(2.3, 3.4)
					_go("kite")
		"vanish":
			_stop()
			var k := clampf(_t / 0.3, 0.0, 1.0)
			w.scale = _base_scale * lerpf(1.0, 0.05, k)
			if _t < 0.03:
				_dust(w.global_position, Color("#4a2a6a"), 8)
				AudioManager.play_sfx_3d("distant_bell", w.global_position, -6.0, 50.0, 7.0)
			if k >= 1.0:
				var away := w.global_position - p.global_position
				away.y = 0.0
				away = away.normalized().rotated(Vector3.UP, randf_range(-0.8, 0.8))
				var dest := _ground_at(p.global_position + away * randf_range(14.0, 17.0))
				if not _has_floor(dest):
					dest = _ground_at(w.global_position)
				w.global_position = dest + Vector3(0, 0.4, 0)
				_dust(dest, Color("#4a2a6a"), 8)
				_cd_blink = 7.0
				_go("appear")
		"appear":
			var k2 := clampf(_t / 0.3, 0.0, 1.0)
			w.scale = _base_scale * lerpf(0.05, 1.0, k2)
			if k2 >= 1.0:
				_cd_bolt = 0.6
				_go("kite")


# --- Давній маг (міні-бос): три фази зі зміною тактики ----------------------------------------------------------
## Фаза 1: віяла крижаних куль і блимання. Фаза 2 (<66 %): щит із двох крижаних сфер, що кружляють навколо:
## поки вони живі, маг невразливий — треба збивати сфери; плюс крижана хвиля навколо нього. Фаза 3 (<33 %):
## сипле крижані шипи по гравцю (кола з запалом) і блимає втричі частіше — але вразливий.

var _phase: int = 1
var _shield_orbs: Array = []
var _spike_marks: Array = []
var _spike_t: float = 0.0
var _nova_done: bool = false


func _mage_phase_check() -> void:
	var ratio := float(w.get("health")) / maxf(float(w.get("max_health")), 1.0)
	var want := 1 if ratio > 0.66 else (2 if ratio > 0.33 else 3)
	if want > _phase and _state not in ["shift", "vanish", "appear"]:
		_phase = want
		_go("shift")


func _mage_cleanup() -> void:
	for o in _shield_orbs:
		if is_instance_valid(o):
			(o as Node).queue_free()
	_shield_orbs.clear()
	for m in _spike_marks:
		if is_instance_valid(m[0]):
			(m[0] as Node).queue_free()
	_spike_marks.clear()


func _spawn_shield_orbs() -> void:
	for i in range(2):
		var orb := ShieldOrb.new()
		orb.mage = w
		orb.angle = PI * float(i)
		orb.brain = self
		w.get_tree().current_scene.add_child(orb)
		orb.global_position = w.global_position + Vector3(0, 1.4, 0)
		_shield_orbs.append(orb)
	invulnerable = true


func orb_destroyed() -> void:
	var left := 0
	for o in _shield_orbs:
		if is_instance_valid(o) and not bool(o.get("dead")):
			left += 1
	if left == 0 and invulnerable:
		invulnerable = false
		_dust(w.global_position + Vector3(0, 1.0, 0), Color("#9ad8ff"), 14)
		AudioManager.play_sfx_3d("parry_ring", w.global_position, 3.0, 50.0, 7.0)
		var main = world.get_parent()
		main.call("_show_story_toast", "ЩИТ ЗЛАМАНО", "Маг відкритий! Руйнуй його, поки сфери не відновились.", 3.5)
		_cd_sweep = 6.0


func _fire_fan(aim: Vector3, count: int, spread_deg: float, color: Color, speed: float, dmg: float) -> void:
	var origin := w.global_position + Vector3(0, 1.8, 0)
	var rig := _rig()
	if rig:
		var grip := (rig.get("parts") as Dictionary).get("grip_r") as Node3D
		if grip:
			origin = grip.global_position + Vector3(0, 1.5, 0)
	var base := (aim - origin).normalized()
	for i in range(count):
		var off := deg_to_rad((float(i) - float(count - 1) * 0.5) * spread_deg)
		var bolt := Bolt.new()
		bolt.setup(w, _player(), base.rotated(Vector3.UP, off), speed, dmg, color, 0.34)
		w.get_tree().current_scene.add_child(bolt)
		bolt.global_position = origin
	AudioManager.play_sfx_3d("wraith_swing", origin, 2.0, 50.0, 7.0)
	AudioManager.play_sfx_3d("strange_scrape", origin, -6.0, 50.0, 7.0)


func _tick_mage(delta: float, p: CharacterBody3D, dist: float) -> void:
	var rig := _rig()
	_mage_phase_check()
	match _state:
		"kite":
			_face(p.global_position, delta)
			var dir := p.global_position - w.global_position
			dir.y = 0.0
			dir = dir.normalized()
			var side := dir.rotated(Vector3.UP, PI * 0.5) * _strafe
			if dist < 8.0:
				_move_toward(-dir * 0.8 + side * 0.5, 3.6)
			elif dist > 17.0:
				_move_toward(dir, 3.0)
			else:
				_move_toward(side, 1.5)
			if randf() < delta * 0.2:
				_strafe = -_strafe
			_walk_anim(3.6)
			var blink_cd := 7.0 if _phase < 3 else 2.8
			if dist < 5.5 and _cd_blink <= 0.0:
				_cd_blink = blink_cd
				_go("vanish")
			elif _phase == 2 and _cd_sweep <= 0.0 and dist < 12.0 and not invulnerable:
				_go("nova")
			elif _phase == 2 and _cd_sweep <= 0.0 and invulnerable and dist < 9.0:
				_go("nova")
			elif _phase == 3 and _cd_summon <= 0.0:
				_go("spikes")
			elif _cd_bolt <= 0.0 and dist < 32.0:
				_go("bolt")
		"bolt":
			_stop()
			_face(p.global_position, delta, 10.0)
			if _t < 0.03 and rig:
				rig.call("start_attack", 0.9)
				_make_telegraph(Color("#7ad8ff"), 0.9)
			if _t >= 0.95 and not _hit_done:
				_hit_done = true
				_clear_telegraph()
				_fire_fan(p.global_position + Vector3(0, 1.0, 0), 3 if _phase == 1 else 5, 14.0, Color("#8ae0ff"), 10.0, 14.0)
			if _t > 1.5:
				_cd_bolt = randf_range(2.2, 3.2) if _phase < 3 else randf_range(1.5, 2.2)
				_go("kite")
		"nova":
			_stop()
			if _t < 0.03:
				_make_ground_mark(w.global_position, 6.0, Color("#6ac8ff"))
				if rig:
					create_tween().tween_property(rig, "cast", 1.0, 0.6)
				AudioManager.play_sfx_3d("far_horn", w.global_position, -2.0, 60.0, 8.0)
			if _t >= 1.5 and not _hit_done:
				_hit_done = true
				_clear_ground_mark()
				var dd := p.global_position - w.global_position
				dd.y = 0.0
				if dd.length() < 6.2 and p.is_on_floor():
					_hurt(26.0)
				_shake(0.4)
				_dust(w.global_position, Color("#9ad8ff"), 14)
				AudioManager.play_sfx_3d("block_thud", w.global_position, 6.0, 60.0, 8.0)
			if _t > 2.1:
				if rig:
					create_tween().tween_property(rig, "cast", 0.0, 0.3)
				_cd_sweep = 8.0
				_go("kite")
		"spikes":
			_stop()
			_face(p.global_position, delta, 5.0)
			if _t < 0.03:
				_spike_marks.clear()
				if rig:
					create_tween().tween_property(rig, "cast", 1.0, 0.5)
				AudioManager.play_sfx_3d("strange_whisper", w.global_position, 0.0, 60.0, 8.0)
				for i in range(4):
					var a := TAU * float(i) / 4.0 + randf() * 0.6
					var c := p.global_position + Vector3(cos(a), 0.0, sin(a)) * (0.0 if i == 0 else randf_range(2.0, 4.5))
					var m := _mark_at(c, 1.7, Color("#7ad8ff"))
					_spike_marks.append([m, c])
			if _t >= 1.25 and not _hit_done:
				_hit_done = true
				for mk in _spike_marks:
					var c2: Vector3 = mk[1]
					var d2 := p.global_position - c2
					d2.y = 0.0
					if d2.length() < 1.9:
						_hurt(22.0)
					_dust(c2, Color("#bfeaff"), 6)
					if is_instance_valid(mk[0]):
						(mk[0] as Node).queue_free()
				_spike_marks.clear()
				_shake(0.3)
				AudioManager.play_sfx_3d("parry_ring", w.global_position, 0.0, 60.0, 8.0)
			if _t > 1.9:
				if rig:
					create_tween().tween_property(rig, "cast", 0.0, 0.3)
				_cd_summon = 4.5
				_go("kite")
		"shift":
			# Зміна фази: нова тактика, коротка невразливість і спалах.
			_stop()
			_face(p.global_position, delta)
			if _t < 0.03:
				invulnerable = true
				_clear_telegraph()
				if rig:
					create_tween().tween_property(rig, "cast", 1.0, 0.4)
				_dust(w.global_position + Vector3(0, 1.0, 0), Color("#9ad8ff"), 16)
				AudioManager.play_sfx_3d("far_horn", w.global_position, 3.0, 80.0, 10.0)
				_shake(0.35)
				var main = world.get_parent()
				if _phase == 2:
					main.call("_show_story_toast", "ДАВНІЙ МАГ: ЩИТ", "Навколо мага кружляють крижані сфери — він невразливий, доки вони живі. Бий по сферах!", 5.0)
				else:
					main.call("_show_story_toast", "ДАВНІЙ МАГ: ШИПИ", "Маг сипле крижані шипи по землі. Тікай із синіх кіл, поки вони не спалахнули!", 5.0)
			if _t > 1.3:
				if rig:
					create_tween().tween_property(rig, "cast", 0.0, 0.3)
				if _phase == 2:
					_spawn_shield_orbs()
				else:
					invulnerable = false
				_cd_summon = 2.0
				_cd_bolt = 1.0
				_go("kite")


func _mark_at(center: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = 0.04
	c.radial_segments = 14
	m.mesh = c
	m.material_override = PSXMaterials.make(Color(color.r, color.g, color.b, 0.55), 0.0, 1.0, color, 2.4, "none", false, true)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.get_tree().current_scene.add_child(m)
	m.global_position = _ground_at(center) + Vector3(0, 0.1, 0)
	m.scale = Vector3(0.2, 1.0, 0.2)
	m.create_tween().tween_property(m, "scale", Vector3.ONE, 1.0)
	return m


class ShieldOrb extends CharacterBody3D:
	## Крижана сфера-щит: збивається звичайним ударом чи стрілою; поки хоч одна жива — маг невразливий.
	var mage: Node3D = null
	var brain = null
	var angle: float = 0.0
	var health: float = 45.0
	var dead: bool = false
	var _mesh: MeshInstance3D = null

	func _ready() -> void:
		add_to_group("hostile")
		collision_layer = 2
		collision_mask = 0
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.7
		shape.shape = sphere
		add_child(shape)
		_mesh = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 8
		sm.rings = 4
		_mesh.mesh = sm
		_mesh.material_override = PSXMaterials.make(Color("#a8e4ff"), 0.0, 0.2, Color("#6ac8ff"), 3.0, "none", false)
		_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_mesh)

	func _physics_process(delta: float) -> void:
		if dead:
			return
		if mage == null or not is_instance_valid(mage) or bool(mage.get("dead")):
			queue_free()
			return
		angle += delta * 1.9
		global_position = mage.global_position + Vector3(cos(angle) * 2.3, 1.5 + sin(angle * 2.0) * 0.3, sin(angle) * 2.3)

	func take_damage(amount: float, _source: Node = null) -> void:
		if dead:
			return
		health -= amount
		AudioManager.play_sfx_3d("parry_ring", global_position, -4.0, 40.0, 6.0)
		if health <= 0.0:
			dead = true
			collision_layer = 0
			remove_from_group("hostile")
			AudioManager.play_sfx_3d("hit_flesh", global_position, 0.0, 40.0, 6.0)
			var tw := create_tween()
			tw.tween_property(_mesh, "scale", Vector3.ONE * 2.2, 0.15)
			tw.tween_property(_mesh, "scale", Vector3.ONE * 0.01, 0.12)
			tw.tween_callback(queue_free)
			if brain:
				brain.call_deferred("orb_destroyed")
