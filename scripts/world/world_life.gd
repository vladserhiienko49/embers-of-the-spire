class_name WorldLife
extends Node
## «Живий світ»: входи в хатини з інтер'єрами, відпочинок біля печі, коти, ягідні кущі.
## Працює через наявну систему взаємодій WorldGenerator (world_interactions + клавіша E):
## id взаємодій: enter:<будівля>, interior_exit:<n>, interior_sit:<n>, cat:<n>, berry:<n>.

const BUILDING_THEMES: Dictionary = {
	"Хатина мисливця": "hunter", "Хатина відьми": "witch", "Хатина відлюдника": "hermit", "Болотна хатина": "swamp",
	"Село Попелу": "village", "Зольний Брід": "hamlet", "Селище Соляних Копалень": "hamlet",
	"Хутір Сухих Борозен": "farm", "Ферма Попелястих Полів": "farm",
}
const CAT_SPOTS: Array = [
	["Село Попелу", 5.0, 4.0, "#c8782e"], ["Село Попелу", 6.0, -9.0, "#2a2a30"],
	["Зольний Брід", 3.0, 5.0, "#8a8a92"], ["Селище Соляних Копалень", 2.0, 6.0, "#e0d8c8"],
	["Хутір Сухих Борозен", 3.0, 4.0, "#c8782e"], ["Ферма Попелястих Полів", 3.0, 4.0, "#2a2a30"],
	["Табір вигнанців", 3.0, 6.0, "#8a6a4a"], ["Хатина мисливця", 4.0, 3.0, "#8a8a92"],
]
const BUSH_SPOTS: Array = [
	["Село Попелу", -18.0, -6.0], ["Село Попелу", 17.0, 8.0], ["Табір вигнанців", 11.0, 6.0], ["Табір вигнанців", -10.0, 9.0],
	["Хатина мисливця", 10.0, 4.0], ["Хатина мисливця", -9.0, 6.0], ["Хатина відлюдника", 9.0, 5.0], ["Болотна хатина", -9.0, 5.0],
	["Болотна хатина", 8.0, -6.0], ["Зольний Брід", 22.0, 5.0], ["Зольний Брід", -21.0, 12.0], ["Хутір Сухих Борозен", -18.0, 6.0],
	["Хутір Сухих Борозен", 18.0, 16.0], ["Ферма Попелястих Полів", -16.0, 8.0], ["Монастир Сірих Сестер", 14.0, 5.0],
	["Монастир Сірих Сестер", -14.0, -4.0], ["Коло друїдів", 11.0, 0.0], ["Коло друїдів", -10.0, 6.0], ["Камені Мовчання", 9.0, 6.0],
	["Селище Соляних Копалень", -22.0, 6.0], ["Хатина відьми", 9.0, -4.0], ["Стара сторожова вежа", 8.0, 7.0],
]
const BERRIES_PER_BUSH: int = 4
const BERRY_HEAL: float = 10.0
const BERRY_REGROW_SECONDS: float = 150.0
const PICK_SECONDS: float = 1.5
const PET_SECONDS: float = 1.9

var world = null
var main = null
var _interiors: Dictionary = {}    # building -> {"index", "node", "origin"}
var _current: String = ""
var _return_global: Vector3 = Vector3.ZERO
var _return_yaw: float = 0.0
var _resting: bool = false
var _busy: bool = false
var _cats: Array = []
var _bushes: Array = []
var _fire_player: AudioStreamPlayer = null
var _rest_label: Label = null


func setup(world_node) -> void:
	world = world_node
	main = world.get_parent()
	_fire_player = AudioStreamPlayer.new()
	_fire_player.bus = "Ambient"
	add_child(_fire_player)
	var path: String = str(AudioCatalog.AMBIENT["fire"])
	if ResourceLoader.exists(path):
		var stream := ResourceLoader.load(path) as AudioStream
		if stream is AudioStreamWAV:
			var wav := stream as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(round(wav.get_length() * float(wav.mix_rate)))
		_fire_player.stream = stream
	_register_doors()
	_spawn_cats()
	_spawn_bushes()
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_rest_label = Label.new()
	_rest_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_rest_label.offset_top = -150.0
	_rest_label.offset_left = -300.0
	_rest_label.offset_right = 300.0
	_rest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rest_label.add_theme_font_size_override("font_size", 18)
	_rest_label.add_theme_color_override("font_color", Color("#f2d9a8"))
	_rest_label.add_theme_constant_override("outline_size", 4)
	_rest_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_rest_label.visible = false
	layer.add_child(_rest_label)


func _player() -> CharacterBody3D:
	return world.get("player_ref") as CharacterBody3D


func _toast(title: String, body: String, seconds: float = 3.5) -> void:
	if main and main.has_method("_show_story_toast"):
		main.call("_show_story_toast", title, body, seconds)


func _message(text: String, positive: bool = true) -> void:
	var p := _player()
	if p:
		p.emit_signal("combat_message", text, positive)


# --- Двері й інтер'єри -----------------------------------------------------------------------

func _register_doors() -> void:
	var index := 0
	for building_name in BUILDING_THEMES.keys():
		var front: Vector3 = world._building_front_position(building_name, 1.2, -2.6)
		if front == Vector3.ZERO:
			continue
		front.y = world._terrain_height_at_world(front.x, front.z)
		world._register_world_interaction("enter:" + building_name, building_name, front, 4.2, "E  —  УВІЙТИ ДО БУДИНКУ")
		_interiors[building_name] = {"index": index, "node": null, "origin": Vector3(-700.0, 420.0, float(index) * 24.0)}
		var origin: Vector3 = _interiors[building_name]["origin"]
		world._register_world_interaction("interior_exit:" + building_name, "Двері", origin + InteriorKit.EXIT_SPOT, 2.4, "E  —  ВИЙТИ НА ВУЛИЦЮ")
		world._register_world_interaction("interior_sit:" + building_name, "Піч", origin + InteriorKit.SIT_SPOT, 1.9, "E  —  СІСТИ БІЛЯ ПЕЧІ")
		index += 1


func handle_interaction(interaction_id: String) -> bool:
	if interaction_id.begins_with("enter:") and world.horses and world.horses.mounted:
		_toast("СПЕРШУ ЗІЙДИ З КОНЯ", "У хату на коні не заїдеш: натисни E, щоб зійти.", 2.5)
		return true
	if _busy or _resting:
		return interaction_id.contains(":")
	if interaction_id.begins_with("enter:"):
		_enter(interaction_id.substr(6))
		return true
	if interaction_id.begins_with("interior_exit:"):
		_exit()
		return true
	if interaction_id.begins_with("interior_sit:"):
		_start_rest()
		return true
	if interaction_id.begins_with("cat:"):
		_pet_cat(int(interaction_id.substr(4)))
		return true
	if interaction_id.begins_with("berry:"):
		_pick_berry(int(interaction_id.substr(6)))
		return true
	return false


func _enter(building_name: String) -> void:
	var info: Dictionary = _interiors.get(building_name, {})
	var player := _player()
	if info.is_empty() or player == null:
		return
	if info["node"] == null:
		var node := InteriorKit.build(str(BUILDING_THEMES[building_name]), hash(building_name))
		node.position = info["origin"]
		world.add_child(node)
		info["node"] = node
	_current = building_name
	_return_global = player.global_position
	_return_yaw = player.rotation.y
	player.velocity = Vector3.ZERO
	player.global_position = world.to_global(Vector3(info["origin"]) + InteriorKit.SPAWN_SPOT)
	player.rotation.y = PI
	player.reset_physics_interpolation()
	if _fire_player.stream:
		_fire_player.volume_db = -12.0
		_fire_player.play()
	AudioManager.play_sfx("step_wood", -3.0, 0.05)
	_toast(building_name.to_upper(), "Тепло, пахне деревом і димом. Піч біля стіни — можна присісти відпочити.", 4.0)


func _exit() -> void:
	var player := _player()
	if player == null or _current == "":
		return
	player.velocity = Vector3.ZERO
	player.global_position = _return_global
	player.rotation.y = _return_yaw
	player.reset_physics_interpolation()
	_current = ""
	_fire_player.stop()
	AudioManager.play_sfx("step_wood", -3.0, 0.05)


func _start_rest() -> void:
	var player := _player()
	if player == null or _current == "":
		return
	var info: Dictionary = _interiors[_current]
	var spot: Vector3 = Vector3(info["origin"]) + InteriorKit.SIT_SPOT
	_resting = true
	main.set("current_screen", "rest")
	main.call("_set_player_controls", false)
	player.global_position = world.to_global(spot)
	player.velocity = Vector3.ZERO
	player.rotation.y = PI * 0.5   # обличчям до печі (на захід)
	var anim := player.get("anim_player") as AnimationPlayer
	if anim:
		anim.seek(0.0, true)
		anim.pause()
	player.call("set_sit_pose", true)
	_fire_player.volume_db = -3.0
	_rest_label.visible = true
	AudioManager.play_ui("torch_on")


func _stop_rest() -> void:
	if not _resting:
		return
	_resting = false
	var player := _player()
	if player:
		player.call("set_sit_pose", false)
	_rest_label.visible = false
	_fire_player.volume_db = -12.0
	main.set("current_screen", "game")
	main.call("_set_player_controls", true)
	AudioManager.play_ui("ui_back")


func _unhandled_input(event: InputEvent) -> void:
	if _resting and (event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept")):
		_stop_rest()
		get_viewport().set_input_as_handled()


# --- Коти ---------------------------------------------------------------------------------------------

func _spawn_cats() -> void:
	var i := 0
	for spot in CAT_SPOTS:
		var p: Vector3 = world._building_front_position(str(spot[0]), float(spot[1]), float(spot[2]))
		if p == Vector3.ZERO:
			continue
		p.y = world._terrain_height_at_world(p.x, p.z)
		var cat := Cat.new()
		cat.world = world
		cat.home = p
		cat.name = "Cat_%d" % i
		world.add_child(cat)
		cat.position = p
		cat.build(Color(str(spot[3])))
		world._register_world_interaction("cat:%d" % i, "Кіт", p, 2.6, "E  —  ПОГЛАДИТИ КОТА")
		cat.interaction = world.world_interactions[world.world_interactions.size() - 1]
		_cats.append(cat)
		i += 1


func _face(player: Node3D, target: Vector3) -> void:
	var d := target - player.global_position
	d.y = 0.0
	if d.length() > 0.05:
		player.rotation.y = atan2(-d.x, -d.z)


func _lock(seconds: float) -> void:
	_busy = true
	main.call("_set_player_controls", false)
	await get_tree().create_timer(seconds).timeout
	_busy = false
	if not _resting and str(main.get("current_screen")) == "game":
		main.call("_set_player_controls", true)


func _pet_cat(index: int) -> void:
	var player := _player()
	if index < 0 or index >= _cats.size() or player == null:
		return
	var cat: Node3D = _cats[index]
	_face(player, cat.global_position)
	var anim := player.get("anim_player") as AnimationPlayer
	if anim:
		anim.seek(0.0, true)
		anim.pause()
	player.call("play_reach_pose", Vector3(-0.25, -0.5, 0.85), Vector3(-0.1, -0.7, 0.75), PET_SECONDS)
	cat.call("be_petted", player.global_position, PET_SECONDS)
	_lock(PET_SECONDS)
	player.call("heal", 3.0)
	_message("Кіт муркоче. Тепло розтікається по грудях  (+3 здоров'я)")


# --- Ягоди -------------------------------------------------------------------------------------------------

func _spawn_bushes() -> void:
	var leaf := PSXMaterials.make(Color("#2c4a2a"), 0.0, 0.95, Color.BLACK, 0.0, "none", false)
	var leaf_dark := PSXMaterials.make(Color("#1f3520"), 0.0, 0.95, Color.BLACK, 0.0, "none", false)
	var berry_mat := PSXMaterials.make(Color("#a01838"), 0.0, 0.4, Color("#6a0c24"), 0.8, "none", false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var index := 0
	for spot in BUSH_SPOTS:
		var p: Vector3 = world._building_local_point(str(spot[0]), Vector3(float(spot[1]), 0.0, float(spot[2])))
		if p == Vector3.ZERO:
			continue
		var bush := Node3D.new()
		bush.name = "BerryBush_%d" % index
		bush.position = p
		bush.rotation.y = rng.randf() * TAU
		world.add_child(bush)
		var kit := MeshKit.new()
		for k in range(7):
			var a := TAU * float(k) / 7.0 + rng.randf() * 0.4
			var r := 0.0 if k == 0 else 0.5
			var s := rng.randf_range(0.5, 0.75)
			kit.pyramid("leaf" if k % 2 == 0 else "leaf_dark", Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * r, 0.0, sin(a) * r)), s * 1.5, s * 1.5, s * 1.4)
			kit.box_at("leaf_dark", Vector3(cos(a) * r, 0.4, sin(a) * r), Vector3(s, 0.5, s), false, Vector3(0, a, 0))
		kit.set_material("leaf", leaf)
		kit.set_material("leaf_dark", leaf_dark)
		kit.build(bush, "BushMesh", 140.0)
		var berries: Array = []
		for k in range(BERRIES_PER_BUSH):
			var a := TAU * float(k) / float(BERRIES_PER_BUSH) + 0.5
			var berry := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.09
			sphere.height = 0.18
			sphere.radial_segments = 6
			sphere.rings = 3
			berry.mesh = sphere
			berry.material_override = berry_mat
			berry.position = Vector3(cos(a) * 0.62, 0.55 + float(k % 2) * 0.22, sin(a) * 0.62)
			berry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			bush.add_child(berry)
			berries.append(berry)
		world._register_world_interaction("berry:%d" % index, "Ягідний кущ", p + Vector3(0, 0.5, 0), 2.6, "E  —  ЗІРВАТИ ЯГОДИ (%d)" % BERRIES_PER_BUSH)
		_bushes.append({"node": bush, "berries": berries, "left": BERRIES_PER_BUSH, "timer": 0.0, "interaction": world.world_interactions[world.world_interactions.size() - 1]})
		index += 1


func _update_bush_hint(bush: Dictionary) -> void:
	var left := int(bush["left"])
	bush["interaction"]["hint"] = "E  —  ЗІРВАТИ ЯГОДИ (%d)" % left if left > 0 else "Ягоди ще не дозріли"


func _pick_berry(index: int) -> void:
	var player := _player()
	if index < 0 or index >= _bushes.size() or player == null:
		return
	var bush: Dictionary = _bushes[index]
	if int(bush["left"]) <= 0:
		_message("На кущі вже немає стиглих ягід. Повернись пізніше.", false)
		return
	if float(player.get("health")) >= float(player.get("max_health")) - 0.5:
		_message("Здоров'я повне — ягоди краще залишити.", false)
		return
	_face(player, (bush["node"] as Node3D).global_position)
	var anim := player.get("anim_player") as AnimationPlayer
	if anim:
		anim.seek(0.0, true)
		anim.pause()
	# Рука тягнеться до куща, зривання на середині анімації (≈1.5 с).
	player.call("play_reach_pose", Vector3(-0.3, 0.3, 0.9), Vector3(-0.1, 0.2, 0.95), PICK_SECONDS)
	_lock(PICK_SECONDS)
	await get_tree().create_timer(PICK_SECONDS * 0.5).timeout
	var berries: Array = bush["berries"]
	var picked: MeshInstance3D = null
	for b in berries:
		if is_instance_valid(b) and (b as MeshInstance3D).visible:
			picked = b
			break
	if picked == null:
		return
	bush["left"] = int(bush["left"]) - 1
	bush["timer"] = BERRY_REGROW_SECONDS
	var shrink := create_tween()
	shrink.tween_property(picked, "scale", Vector3.ONE * 0.01, 0.25)
	shrink.tween_callback(picked.hide)
	player.call("heal", BERRY_HEAL)
	AudioManager.play_sfx("item_pickup", -4.0, 0.1)
	_message("Ягода смачна й терпка  (+%d здоров'я)" % int(BERRY_HEAL))
	_update_bush_hint(bush)


# --- Оновлення ------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	var player := _player()
	if player and bool(player.get("controls_enabled")):
		for bush in _bushes:
			if int(bush["left"]) < BERRIES_PER_BUSH:
				bush["timer"] = float(bush["timer"]) - delta
				if float(bush["timer"]) <= 0.0:
					var berries: Array = bush["berries"]
					for b in berries:
						if is_instance_valid(b) and not (b as MeshInstance3D).visible:
							(b as MeshInstance3D).show()
							(b as MeshInstance3D).scale = Vector3.ONE
							break
					bush["left"] = int(bush["left"]) + 1
					bush["timer"] = BERRY_REGROW_SECONDS
					_update_bush_hint(bush)
	if _resting and player:
		player.call("heal", 6.0 * delta)
		player.set("stamina", minf(float(player.get("max_stamina")), float(player.get("stamina")) + 25.0 * delta))
		var hp := int(player.get("health"))
		_rest_label.text = "Ти відпочиваєш біля печі…  ❤ %d / %d\n[E] / [ESC] — підвестися" % [hp, int(player.get("max_health"))]


## Кіт: сидить, іноді обходить подвір'я, махає хвостом; при погладжуванні вигинається й муркоче.
class Cat extends Node3D:
	var world = null
	var home: Vector3 = Vector3.ZERO
	var interaction: Dictionary = {}
	var _body: Node3D
	var _head: Node3D
	var _tail: Node3D
	var _tail_tip: Node3D
	var _eyes: Array = []
	var _ears: Array = []
	var _state: String = "idle"
	var _timer: float = 2.0
	var _target: Vector3 = Vector3.ZERO
	var _time: float = 0.0
	var _pet_left: float = 0.0
	var _seed: float = 0.0

	func _part(parent: Node3D, size: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = size
		m.mesh = b
		m.material_override = mat
		m.position = pos
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(m)
		return m

	func build(fur: Color) -> void:
		_seed = randf() * TAU
		var fur_mat := PSXMaterials.make(fur, 0.0, 1.0, Color.BLACK, 0.0, "cloth", false)
		var dark_mat := PSXMaterials.make(fur.darkened(0.35), 0.0, 1.0, Color.BLACK, 0.0, "cloth", false)
		var eye_mat := PSXMaterials.make(Color("#c8e060"), 0.0, 0.5, Color("#a8c040"), 0.8, "none", false)
		var pink := PSXMaterials.make(Color("#d89aa0"), 0.0, 1.0, Color.BLACK, 0.0, "none", false)
		_body = Node3D.new()
		add_child(_body)
		_part(_body, Vector3(0.2, 0.2, 0.42), fur_mat, Vector3(0, 0.22, 0))
		_part(_body, Vector3(0.16, 0.16, 0.22), dark_mat, Vector3(0, 0.2, -0.18))
		for sx: float in [-1.0, 1.0]:
			_part(_body, Vector3(0.06, 0.18, 0.07), fur_mat, Vector3(sx * 0.07, 0.09, 0.15))
			_part(_body, Vector3(0.06, 0.18, 0.07), fur_mat, Vector3(sx * 0.07, 0.09, -0.15))
		_head = Node3D.new()
		_head.position = Vector3(0, 0.36, -0.26)
		_body.add_child(_head)
		_part(_head, Vector3(0.18, 0.15, 0.15), fur_mat, Vector3.ZERO)
		_part(_head, Vector3(0.08, 0.05, 0.05), pink, Vector3(0, -0.03, -0.08))
		for sx: float in [-1.0, 1.0]:
			var ear := _part(_head, Vector3(0.06, 0.08, 0.04), dark_mat, Vector3(sx * 0.06, 0.1, 0.0))
			_ears.append(ear)
			var eye := _part(_head, Vector3(0.035, 0.035, 0.02), eye_mat, Vector3(sx * 0.045, 0.02, -0.075))
			_eyes.append(eye)
		_tail = Node3D.new()
		_tail.position = Vector3(0, 0.26, 0.2)
		_body.add_child(_tail)
		_part(_tail, Vector3(0.05, 0.05, 0.22), fur_mat, Vector3(0, 0, 0.11))
		_tail_tip = Node3D.new()
		_tail_tip.position = Vector3(0, 0, 0.22)
		_tail.add_child(_tail_tip)
		_part(_tail_tip, Vector3(0.045, 0.045, 0.2), dark_mat, Vector3(0, 0, 0.1))
		rotation.y = randf() * TAU

	func be_petted(player_pos: Vector3, seconds: float) -> void:
		_pet_left = seconds
		_state = "pet"
		var d := player_pos - global_position
		rotation.y = atan2(-d.x, -d.z)
		AudioManager.play_sfx_3d("cat_purr", global_position + Vector3(0, 0.3, 0), -2.0, 14.0, 3.0)
		for i in range(3):
			_heart(i)

	func _heart(i: int) -> void:
		await get_tree().create_timer(0.2 + float(i) * 0.45).timeout
		if not is_inside_tree():
			return
		var l := Label3D.new()
		l.text = "♥"
		l.font_size = 64
		l.pixel_size = 0.006
		l.modulate = Color("#ff6a7a")
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		add_child(l)
		l.position = Vector3(randf_range(-0.12, 0.12), 0.65, randf_range(-0.1, 0.1))
		var tw := create_tween().set_parallel(true)
		tw.tween_property(l, "position:y", 1.3, 1.1)
		tw.tween_property(l, "modulate:a", 0.0, 1.1)
		tw.chain().tween_callback(l.queue_free)

	func _process(delta: float) -> void:
		if _body == null:
			return
		var cam := get_viewport().get_camera_3d()
		if cam and cam.global_position.distance_squared_to(global_position) > 3600.0:
			return
		_time += delta
		var sway := sin(_time * 1.8 + _seed)
		match _state:
			"pet":
				_pet_left -= delta
				var k := clampf(_pet_left / 1.9, 0.0, 1.0)
				# Вигинає спину назустріч руці, тулить вуха, прикриває очі, хвіст трубою.
				_body.scale = Vector3(1.0, 1.0 + 0.18 * sin(_time * 5.0) * 0.5 + 0.12, 1.0)
				_body.position.y = 0.0
				_tail.rotation.x = lerpf(_tail.rotation.x, 1.2, delta * 6.0)
				_tail_tip.rotation.x = lerpf(_tail_tip.rotation.x, 0.5, delta * 6.0)
				_head.rotation.x = lerpf(_head.rotation.x, 0.35, delta * 6.0)
				for eye in _eyes:
					(eye as Node3D).scale.y = lerpf((eye as Node3D).scale.y, 0.12, delta * 10.0)
				for ear in _ears:
					(ear as Node3D).rotation.z = lerpf((ear as Node3D).rotation.z, (0.5 if (ear as Node3D).position.x > 0 else -0.5), delta * 6.0)
				if _pet_left <= 0.0:
					_state = "idle"
					_timer = randf_range(2.0, 5.0)
					AudioManager.play_sfx_3d("cat_meow", global_position + Vector3(0, 0.3, 0), -4.0, 18.0, 3.0)
			"walk":
				var to := _target - position
				to.y = 0.0
				if to.length() < 0.15:
					_state = "idle"
					_timer = randf_range(3.0, 7.0)
				else:
					var dir := to.normalized()
					rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), delta * 6.0)
					position += dir * 0.9 * delta
					position.y = world._terrain_height_at_world(position.x, position.z)
					_body.position.y = absf(sin(_time * 9.0)) * 0.025
					_body.scale = Vector3.ONE
					_tail.rotation.x = 0.3 + sway * 0.1
			_:
				_body.scale = _body.scale.lerp(Vector3.ONE, delta * 6.0)
				_body.position.y = 0.0
				_tail.rotation.y = sway * 0.45
				_tail.rotation.x = lerpf(_tail.rotation.x, -0.2, delta * 4.0)
				_tail_tip.rotation.y = sin(_time * 2.4 + _seed) * 0.5
				_head.rotation.x = lerpf(_head.rotation.x, 0.0, delta * 5.0)
				for eye in _eyes:
					(eye as Node3D).scale.y = lerpf((eye as Node3D).scale.y, 1.0 if fmod(_time + _seed, 5.0) > 0.15 else 0.1, delta * 14.0)
				for ear in _ears:
					(ear as Node3D).rotation.z = lerpf((ear as Node3D).rotation.z, 0.0, delta * 6.0)
				_timer -= delta
				if _timer <= 0.0:
					_state = "walk"
					_target = home + Vector3(randf_range(-5.0, 5.0), 0.0, randf_range(-5.0, 5.0))
		if not interaction.is_empty():
			interaction["position"] = global_position
