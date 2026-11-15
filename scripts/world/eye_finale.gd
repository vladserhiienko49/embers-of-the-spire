class_name EyeFinale
extends Node
## Фінальна сюжетна подія після перемоги над Стражем: герой підходить до Вівтаря Ока й вириває Око.
## 1) Боротьба: тисни E, щоб притягнути Око (воно опирається й відштовхує).
## 2) Вирване Око перетворюється на вогняного змія, що шалено кружляє довкола вершини.
## 3) Змій стискається в точку й вибухає; темна сила зникає. Лише тоді зараховується крок сюжету
##    й запускається фінальна катсцена (світанок).

const SERPENT_SEGMENTS: int = 18

var world = null
var main = null
var armed: bool = false
var running: bool = false
var _phase: String = ""
var _t: float = 0.0
var _bar: float = 0.0
var _pulse_t: float = 0.0
var _altar_local: Vector3 = Vector3.ZERO
var _cam: Camera3D = null
var _eye: Node3D = null
var _eye_top: Vector3 = Vector3.ZERO
var _hand: Vector3 = Vector3.ZERO
var _serpent: Array = []
var _rings: Array = []
var _flash_light: OmniLight3D = null
var _ui: CanvasLayer = null
var _ui_bar: ProgressBar = null
var _ui_label: Label = null
var _white: ColorRect = null
var _spin: float = 0.0
var _cam_angle: float = 0.0


func setup(world_node) -> void:
	world = world_node
	main = world.get_parent()
	_ui = CanvasLayer.new()
	_ui.layer = 41
	add_child(_ui)
	_white = ColorRect.new()
	_white.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_white.color = Color(1.0, 0.95, 0.85, 0.0)
	_white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_white)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.offset_left = -260.0
	box.offset_right = 260.0
	box.offset_top = -150.0
	box.offset_bottom = -70.0
	box.add_theme_constant_override("separation", 8)
	_ui.add_child(box)
	_ui_label = Label.new()
	_ui_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ui_label.add_theme_font_size_override("font_size", 20)
	_ui_label.add_theme_color_override("font_color", Color("#ffd8a0"))
	_ui_label.add_theme_constant_override("outline_size", 5)
	_ui_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	box.add_child(_ui_label)
	_ui_bar = ProgressBar.new()
	_ui_bar.custom_minimum_size = Vector2(520, 22)
	_ui_bar.max_value = 1.0
	_ui_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.03, 0.03, 0.9)
	bg.border_color = Color("#8a2a1a")
	bg.set_border_width_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#e04a1a")
	_ui_bar.add_theme_stylebox_override("background", bg)
	_ui_bar.add_theme_stylebox_override("fill", fill)
	box.add_child(_ui_bar)
	box.visible = false
	_ui_bar.set_meta("box", box)


func _player() -> CharacterBody3D:
	return world.get("player_ref") as CharacterBody3D


func _toast(title: String, body: String, seconds: float = 4.5) -> void:
	main.call("_show_story_toast", title, body, seconds)


func arm() -> void:
	## Страж переможений: Око на Вівтарі стає доступним для фінальної взаємодії.
	if armed:
		return
	armed = true
	_altar_local = world.get_arena_altar_local()
	world.story_positions["eye_destroyed"] = _altar_local
	var altar_int = world.story_nodes.get("altar_interactable")
	if altar_int and is_instance_valid(altar_int):
		altar_int.set("radius", 0.0)
	world._register_world_interaction("eye_tear", "Вівтар Ока", _altar_local + Vector3(0, 1.0, 0), 5.5, "E  —  ВИРВАТИ ОКО")
	_toast("СТРАЖ ПОВАЛЕНИЙ", "Але Око досі горить над Вівтарем і шепоче. Підійди до Вівтаря й вирви його (E).", 7.0)


func handle_interaction(interaction_id: String) -> bool:
	if interaction_id != "eye_tear":
		return false
	if armed and not running:
		_start()
	return true


func _floater() -> Node3D:
	var altar_int = world.story_nodes.get("altar_interactable")
	return (altar_int as Node).find_child("FloatingSlab", true, false) as Node3D if altar_int else null


# --- Сцена ---------------------------------------------------------------------------------------------

func _start() -> void:
	var p := _player()
	if p == null:
		return
	if world.horses and world.horses.mounted:
		world.horses.dismount()
	running = true
	main.set("current_screen", "eye_event")
	main.call("_set_player_controls", false)
	var altar_g: Vector3 = world.to_global(_altar_local)
	# Герой стає перед вівтарем (з боку, звідки підійшов) і дивиться на Око.
	var from := p.global_position - altar_g
	from.y = 0.0
	from = from.normalized() if from.length() > 0.1 else Vector3(0, 0, 1)
	var stand: Vector3 = world._raycast_ground_position(altar_g + from * 3.4, 1.0)
	p.global_position = stand
	p.velocity = Vector3.ZERO
	p.rotation.y = atan2(from.x, from.z)
	var knight := p.get("knight_model") as Node3D
	if knight:
		knight.rotation.y = PI
	var anim := p.get("anim_player") as AnimationPlayer
	if anim:
		anim.seek(0.0, true)
		anim.pause()
	var reach = p.get("_reach")
	if reach:
		reach.set_pose(Vector3(-0.25, 0.85, 0.45), Vector3(-0.1, 0.95, 0.3))
		create_tween().tween_property(reach, "reach", 1.0, 0.6)
	# Окреме Око (копія) замість того, що на плиті.
	var floater := _floater()
	_eye_top = altar_g + Vector3(0, 8.7, 0)
	if floater:
		for n in ["EyeBall", "EyeIris", "EyePupil"]:
			var part := floater.find_child(n, true, false) as Node3D
			if part:
				_eye_top = part.global_position if n == "EyeBall" else _eye_top
				part.hide()
	_hand = stand + Vector3(0, 1.8, 0) - from * 0.9
	_eye = _make_eye()
	get_tree().current_scene.add_child(_eye)
	_eye.global_position = _eye_top
	_cam = Camera3D.new()
	_cam.fov = 62.0
	_cam.far = 1500.0
	get_tree().current_scene.add_child(_cam)
	_cam.make_current()
	_cam_angle = atan2(from.x, from.z) + 0.6
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color("#ff4a1a")
	_flash_light.light_energy = 2.0
	_flash_light.omni_range = 22.0
	get_tree().current_scene.add_child(_flash_light)
	_flash_light.global_position = altar_g + Vector3(0, 6.0, 0)
	_bar = 0.15
	_phase = "struggle"
	_t = 0.0
	_ui_label.text = "ТИСНИ  [E]  —  ВИРИВАЙ ОКО!"
	(_ui_bar.get_meta("box") as Control).visible = true
	AudioManager.play_sfx("wraith_growl", 4.0, 0.0)
	_toast("ОКО ОПИРАЄТЬСЯ", "Воно тягне тебе до себе. Тисни E знову й знову, поки Око не зірветься з плити!", 5.0)


func _make_eye() -> Node3D:
	var root := Node3D.new()
	root.name = "TornEye"
	var ball := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.85
	s.height = 1.7
	s.radial_segments = 10
	s.rings = 5
	ball.mesh = s
	ball.material_override = PSXMaterials.make(Color("#d8cdb8"), 0.0, 0.7, Color("#401008"), 0.6, "none", false)
	root.add_child(ball)
	var iris := MeshInstance3D.new()
	var si := SphereMesh.new()
	si.radius = 0.42
	si.height = 0.84
	si.radial_segments = 8
	si.rings = 4
	iris.mesh = si
	iris.material_override = PSXMaterials.make(Color("#ff5a2a"), 0.0, 0.3, Color("#ff2a00"), 5.0, "none", false)
	iris.position = Vector3(0, 0, -0.55)
	root.add_child(iris)
	var pupil := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.18
	sp.height = 0.36
	sp.radial_segments = 6
	sp.rings = 3
	pupil.mesh = sp
	pupil.material_override = PSXMaterials.make(Color("#050304"), 0.0, 1.0, Color.BLACK, 0.0, "none", false)
	pupil.position = Vector3(0, 0, -0.92)
	root.add_child(pupil)
	return root


func _input(event: InputEvent) -> void:
	if not running or _phase != "struggle":
		return
	if event.is_action_pressed("interact") and not (event is InputEventKey and (event as InputEventKey).echo):
		_bar = minf(1.0, _bar + 0.075)
		AudioManager.play_sfx("parry_ring", -10.0, 0.2)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not running:
		return
	_t += delta
	var altar_g: Vector3 = world.to_global(_altar_local)
	match _phase:
		"struggle":
			if _bar >= 0.999:
				_torn()
				return
			_bar = maxf(0.0, _bar - delta * 0.11)
			_pulse_t -= delta
			if _pulse_t <= 0.0:
				# Око б'є хвилею: відкидає прогрес і трусить камеру.
				_pulse_t = randf_range(1.4, 2.2)
				_bar = maxf(0.0, _bar - 0.1)
				_flash_light.light_energy = 6.0
				AudioManager.play_sfx("wraith_hurt", -2.0, 0.1)
			_flash_light.light_energy = lerpf(_flash_light.light_energy, 2.0 + _bar * 2.0, delta * 4.0)
			_ui_bar.value = _bar
			var jitter := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * (0.05 + _bar * 0.12)
			_eye.global_position = _eye_top.lerp(_hand, smoothstep(0.0, 1.0, _bar)) + jitter
			_eye.look_at(_player().global_position + Vector3(0, 1.5, 0), Vector3.UP)
			_eye.rotate_object_local(Vector3.UP, PI)
			# Камера на рівні Ока (над плитою), щоб видно було і Око, і героя внизу.
			_set_cam(altar_g, 10.5, maxf(_eye.global_position.y - altar_g.y + 2.2, 3.0), _eye.global_position.lerp(_player().global_position + Vector3(0, 1.2, 0), 0.35), delta * 0.15)
		"torn":
			# Око в руці героя: воно тремтить і рветься назовні.
			_eye.global_position = _hand + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.12
			_eye.rotate_y(delta * 8.0)
			_set_cam(altar_g, 7.0, 3.0, _eye.global_position, delta * 0.2)
			if _t > 1.8:
				_begin_serpent(altar_g)
		"serpent":
			_update_serpent(altar_g, delta)
			_set_cam(altar_g, lerpf(14.0, 22.0, clampf(_t / 6.0, 0.0, 1.0)), lerpf(6.0, 12.0, clampf(_t / 6.0, 0.0, 1.0)), altar_g + Vector3(0, 8.0, 0), delta * 0.35)
			if _t > 7.0:
				_explode(altar_g)
		"aftermath":
			_white.color.a = maxf(0.0, _white.color.a - delta * 0.6)
			_set_cam(altar_g, 20.0, 9.0, altar_g + Vector3(0, 5.0, 0), delta * 0.12)
			if _t > 5.0:
				_finish()


func _set_cam(center: Vector3, radius: float, height: float, look: Vector3, spin: float) -> void:
	_cam_angle += spin
	var shake := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * (0.08 if _phase in ["struggle", "serpent"] else 0.0)
	_cam.global_position = center + Vector3(sin(_cam_angle), 0, cos(_cam_angle)) * radius + Vector3(0, height, 0) + shake
	_cam.look_at(look, Vector3.UP)


func _torn() -> void:
	_phase = "torn"
	_t = 0.0
	(_ui_bar.get_meta("box") as Control).visible = false
	_white.color.a = 0.5
	create_tween().tween_property(_white, "color:a", 0.0, 0.6)
	AudioManager.play_sfx("block_thud", 6.0, 0.0)
	AudioManager.play_sfx("wraith_death", 4.0, 0.0)
	_toast("ОКО ВИРВАНО", "Воно горить у долоні — і починає змінювати форму!", 4.0)
	var p := _player()
	var reach = p.get("_reach") if p else null
	if reach:
		create_tween().tween_property(reach, "reach", 0.0, 0.8)


func _begin_serpent(altar_g: Vector3) -> void:
	_phase = "serpent"
	_t = 0.0
	var head_mat := PSXMaterials.make(Color("#ff6a2a"), 0.0, 0.3, Color("#ff3a10"), 4.0, "none", false)
	var body_mat := PSXMaterials.make(Color("#a020a0"), 0.0, 0.4, Color("#c03aff"), 3.0, "none", false)
	var body_mat2 := PSXMaterials.make(Color("#ff3a2a"), 0.0, 0.4, Color("#ff2010"), 3.0, "none", false)
	for i in range(SERPENT_SEGMENTS):
		var seg := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = lerpf(0.75, 0.18, float(i) / float(SERPENT_SEGMENTS - 1))
		s.height = s.radius * 2.0
		s.radial_segments = 8
		s.rings = 4
		seg.mesh = s
		seg.material_override = body_mat if i % 2 == 0 else body_mat2
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		get_tree().current_scene.add_child(seg)
		seg.global_position = _eye.global_position
		_serpent.append(seg)
	_eye.reparent(_serpent[0], false)
	_eye.position = Vector3.ZERO
	_eye.scale = Vector3.ONE * 1.25
	for k in range(2):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 6.0 + float(k) * 3.0
		torus.outer_radius = 6.3 + float(k) * 3.0
		torus.rings = 32
		torus.ring_segments = 4
		ring.mesh = torus
		ring.material_override = head_mat if k == 0 else body_mat
		get_tree().current_scene.add_child(ring)
		ring.global_position = altar_g + Vector3(0, 7.0 + float(k) * 2.0, 0)
		_rings.append(ring)
	AudioManager.play_sfx("wolf_howl", 2.0, 0.0)
	_toast("ЗМІЙ ОКА", "Око розгортається у вогняного змія й шалено кружляє над вершиною!", 4.0)


func _update_serpent(altar_g: Vector3, delta: float) -> void:
	var k := clampf(_t / 6.0, 0.0, 1.0)
	_spin += delta * lerpf(2.5, 11.0, k * k)
	var radius := lerpf(3.0, 9.0, smoothstep(0.0, 0.4, k)) * (1.0 - smoothstep(0.8, 1.0, k))
	var height := lerpf(3.0, 13.0, smoothstep(0.0, 0.6, k))
	for i in range(_serpent.size()):
		var seg: MeshInstance3D = _serpent[i]
		var a := _spin - float(i) * 0.32
		var h := height - float(i) * 0.28 + sin(_t * 5.0 + float(i) * 0.5) * 0.6
		var target := altar_g + Vector3(cos(a) * radius, h, sin(a) * radius)
		seg.global_position = seg.global_position.lerp(target, minf(1.0, delta * 10.0))
	for j in range(_rings.size()):
		var ring: MeshInstance3D = _rings[j]
		ring.rotate_object_local(Vector3.RIGHT if j == 0 else Vector3.BACK, delta * (2.0 + 4.0 * k))
		ring.rotate_y(delta * 3.0)
		ring.scale = Vector3.ONE * lerpf(1.0, 0.2, smoothstep(0.75, 1.0, k))
	# Спалахи енергії в такт обертанню.
	_flash_light.light_energy = 3.0 + 5.0 * absf(sin(_t * (4.0 + 8.0 * k)))
	_flash_light.global_position = altar_g + Vector3(0, height, 0)
	if fmod(_t, 1.2) < delta:
		AudioManager.play_sfx("torch_on", 0.0, 0.2)


func _explode(altar_g: Vector3) -> void:
	_phase = "aftermath"
	_t = 0.0
	var center := altar_g + Vector3(0, 9.0, 0)
	_white.color.a = 1.0
	AudioManager.play_sfx("block_thud", 10.0, 0.0)
	AudioManager.play_sfx("parry_ring", 4.0, 0.0)
	var p := _player()
	if p and p.get("fx"):
		p.get("fx").add_trauma(1.0)
	for seg in _serpent:
		if is_instance_valid(seg):
			(seg as Node).queue_free()
	_serpent.clear()
	for ring in _rings:
		if is_instance_valid(ring):
			(ring as Node).queue_free()
	_rings.clear()
	# Куля світла та ударне кільце, що розходяться й гаснуть (кілька мешів — без важких частинок).
	var orb := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 12
	s.rings = 6
	orb.mesh = s
	var orb_mat := PSXMaterials.make(Color(1.0, 0.85, 0.6, 0.85), 0.0, 1.0, Color("#ffd8a0"), 4.0, "none", false, true)
	orb.material_override = orb_mat
	get_tree().current_scene.add_child(orb)
	orb.global_position = center
	var tw := create_tween().set_parallel(true)
	tw.tween_property(orb, "scale", Vector3.ONE * 26.0, 1.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(orb.queue_free)
	var wave := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 4
	wave.mesh = torus
	wave.material_override = orb_mat
	get_tree().current_scene.add_child(wave)
	wave.global_position = altar_g + Vector3(0, 0.5, 0)
	var tw2 := create_tween()
	tw2.tween_property(wave, "scale", Vector3(45.0, 2.0, 45.0), 1.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw2.tween_callback(wave.queue_free)
	_flash_light.light_color = Color("#ffe0b0")
	_flash_light.light_energy = 12.0
	_flash_light.omni_range = 60.0
	create_tween().tween_property(_flash_light, "light_energy", 0.0, 3.0)
	# Темна сила зникає: вінець гасне, вівтар чорніє, кільця й маяк зникають.
	world.eye_destroyed = true
	# Бойова тиша змінюється епічною фінальною темою саме в мить вибуху; життя починає проростати.
	AudioManager.play_finale()
	world.start_renewal()
	var altar_int = world.story_nodes.get("altar_interactable")
	if altar_int and is_instance_valid(altar_int):
		for n in ["FloatingSlab", "OrbitRingA", "OrbitRingB", "ShardCloud", "Beacon"]:
			var node := (altar_int as Node).find_child(n, true, false) as Node3D
			if node:
				node.hide()
		for light in (altar_int as Node).find_children("*", "OmniLight3D", true, false):
			(light as OmniLight3D).light_energy = 0.0
	if world.eye_halo:
		world.eye_halo.hide()
	_toast("ОКО ЗНИЩЕНО", "Вибух розлітається над вершиною — і темрява, що століттями лежала на Землях Попелу, розсіюється.", 6.0)


func _finish() -> void:
	running = false
	armed = false
	_phase = ""
	for i in range(world.world_interactions.size() - 1, -1, -1):
		if str(world.world_interactions[i].get("id", "")) == "eye_tear":
			world.world_interactions.remove_at(i)
	if _cam and is_instance_valid(_cam):
		_cam.queue_free()
	if _flash_light and is_instance_valid(_flash_light):
		_flash_light.queue_free()
	var p := _player()
	if p:
		var cam := p.get("camera") as Camera3D
		if cam:
			cam.make_current()
	main.set("current_screen", "game")
	# Лише тепер зараховується останній крок сюжету — це запускає фінальну катсцену.
	QuestManager.record_interaction("eye_destroyed")
