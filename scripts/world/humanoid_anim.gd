extends Node3D
## Анімація гуманоїда з HumanoidKit: ходьба (ноги, коліна, руки), дихання, замах зброєю
## та жести під час розмови. Далекі персонажі не анімуються.

var parts: Dictionary = {}
var rest: Dictionary = {}
var weapon: String = "none"
var flash_materials: Array = []

var walk: float = 0.0          # цільова швидкість ходьби 0..1 (виставляє власник)
var talking: bool = false
var cast: float = 0.0          # 0..1: обидві руки догори (чаклунство)
## Стани героя (процедурні, без motion capture): біг, повітря, щит, сидіння, тягнення руки, віддача.
var run: float = 0.0           # 0..1: спринт (нахил, ширші кроки)
var air: float = 0.0           # 0..1: у стрибку/падінні (ноги підібрані)
var guard: float = 0.0         # 0..1: щит піднято (ліва рука вперед)
var bash: float = 0.0          # 0..1: поштовх щитом (парирування)
var sit: float = 0.0           # 0..1: сидіння
var saddle: bool = false       # сидіння в сідлі (ноги по боках), а не на стільці
var reach: float = 0.0         # 0..1: права рука тягнеться (reach_a — кут плеча, reach_e — кут ліктя)
var reach_a: float = 0.0
var reach_e: float = 0.0
var flinch: float = 0.0        # імпульс віддачі: гасне сам (викликай hit_react)
var _run_s: float = 0.0
var _air_s: float = 0.0
var _land: float = 0.0
var _flinch_dir: float = 1.0
var attack_t: float = -1.0     # -1 немає; 0..0.5 замах, 0.5..0.75 удар, 0.75..1 повернення

var _walk_smooth: float = 0.0
var _phase: float = 0.0
var _time: float = 0.0
var _seed: float = 0.0
var _attack_tween: Tween = null


func setup(new_parts: Dictionary, new_rest: Dictionary, new_weapon: String) -> void:
	parts = new_parts
	rest = new_rest
	weapon = new_weapon
	_seed = randf() * TAU


func start_attack(windup_seconds: float) -> void:
	if _attack_tween and _attack_tween.is_valid():
		_attack_tween.kill()
	attack_t = 0.0
	_attack_tween = create_tween()
	_attack_tween.tween_property(self, "attack_t", 0.5, maxf(windup_seconds, 0.1)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_attack_tween.tween_property(self, "attack_t", 0.75, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_attack_tween.tween_property(self, "attack_t", 1.0, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_attack_tween.tween_callback(func() -> void: attack_t = -1.0)


func hit_react(strength: float = 1.0) -> void:
	## Віддача: корпус відкидає назад, голова смикається.
	flinch = clampf(strength, 0.2, 1.5)
	_flinch_dir = 1.0


func cancel_attack() -> void:
	if _attack_tween and _attack_tween.is_valid():
		_attack_tween.kill()
	attack_t = -1.0


func flash(energy: float) -> void:
	for mat in flash_materials:
		PSXMaterials.set_emission(mat, Color("#b43a24"), energy)


func _rot(node_name: String, axis: String, value: float) -> void:
	var node := parts.get(node_name) as Node3D
	if node == null:
		return
	match axis:
		"x": node.rotation.x = value
		"y": node.rotation.y = value
		"z": node.rotation.z = value


func _process(delta: float) -> void:
	if parts.is_empty():
		return
	var camera := get_viewport().get_camera_3d()
	if camera and camera.global_position.distance_squared_to(global_position) > 2500.0:
		return
	_time += delta
	_walk_smooth = move_toward(_walk_smooth, walk, delta * 5.0)
	var w := _walk_smooth
	if w > 0.02:
		_phase += delta * (4.2 + 4.0 * w) * (1.0 + 0.5 * _run_s)
	_run_s = move_toward(_run_s, run, delta * 6.0)
	var was_air := _air_s
	_air_s = move_toward(_air_s, air, delta * (9.0 if air > _air_s else 7.0))
	if was_air > 0.5 and _air_s <= 0.5 and air <= 0.01:
		_land = 1.0
	_land = move_toward(_land, 0.0, delta * 5.0)
	flinch = move_toward(flinch, 0.0, delta * 4.0)
	var s := sin(_phase)
	var c := cos(_phase)
	var breathe := sin(_time * 1.6 + _seed)

	# Ноги: стегна хитаються, коліно згинається, коли нога йде вперед.
	var stride := 0.75 + 0.3 * _run_s
	var bend := 0.95 + 0.45 * _run_s
	_rot("hip_l", "x", s * stride * w)
	_rot("hip_r", "x", -s * stride * w)
	_rot("knee_l", "x", -(maxf(0.0, c) * bend * w + 0.03))
	_rot("knee_r", "x", -(maxf(0.0, -c) * bend * w + 0.03))
	var body := parts.get("body") as Node3D
	if body:
		body.position.y = absf(c) * (0.035 + 0.035 * _run_s) * w + breathe * 0.004 - _land * 0.14
	var spine := parts.get("spine") as Node3D
	var spine_x := 0.04 * w + 0.2 * _run_s * w + breathe * 0.012
	var spine_y := 0.0

	# Руки: ліва — протифаза до ходьби; права тримає зброю.
	var sh_rest := float(rest.get("sh", 0.1))
	var el_rest := float(rest.get("el", 0.3))
	var left_sh := -s * (0.55 + 0.45 * _run_s) * w + 0.04 + breathe * 0.01
	var left_el := 0.25 + maxf(0.0, s) * 0.4 * w
	var right_sh := sh_rest + s * 0.07 * w + breathe * 0.012
	var right_el := el_rest + 0.05 * breathe

	if talking:
		var g := sin(_time * 3.1)
		right_sh = sh_rest + 0.35 + g * 0.18
		right_el = el_rest + 0.5 + sin(_time * 4.3) * 0.25
		left_sh = 0.3 + sin(_time * 2.4 + 1.0) * 0.15
		left_el = 0.7 + sin(_time * 3.7) * 0.2

	# Замах: рука з оруддям піднімається за голову, потім рубає вперед.
	if attack_t >= 0.0:
		var t := attack_t
		if t < 0.5:
			var k := t / 0.5
			right_sh = lerpf(sh_rest, 2.55, k)
			right_el = lerpf(el_rest, 0.45, k)
			left_sh = lerpf(left_sh, -0.4, k)
			spine_x = lerpf(spine_x, -0.18, k)
			spine_y = lerpf(0.0, 0.35, k)
		elif t < 0.75:
			var k2 := (t - 0.5) / 0.25
			right_sh = lerpf(2.55, 0.55, k2)
			right_el = lerpf(0.45, 0.2, k2)
			left_sh = lerpf(-0.4, 0.5, k2)
			spine_x = lerpf(-0.18, 0.32, k2)
			spine_y = lerpf(0.35, -0.3, k2)
		else:
			var k3 := (t - 0.75) / 0.25
			right_sh = lerpf(0.55, sh_rest, k3)
			right_el = lerpf(0.2, el_rest, k3)
			left_sh = lerpf(0.5, left_sh, k3)
			spine_x = lerpf(0.32, spine_x, k3)
			spine_y = lerpf(-0.3, 0.0, k3)

	if guard > 0.0 or bash > 0.0:
		# Щит: рука піднімається вперед і зігнута; парирування додає поштовх уперед.
		left_sh = lerpf(left_sh, 1.25 + 0.3 * bash, guard)
		left_el = lerpf(left_el, 1.5 - 0.5 * bash, guard)
		spine_y = lerpf(spine_y, -0.18, guard)
	if reach > 0.0:
		right_sh = lerpf(right_sh, reach_a, reach)
		right_el = lerpf(right_el, reach_e, reach)
	if cast > 0.0:
		right_sh = lerpf(right_sh, 2.75, cast)
		left_sh = lerpf(left_sh, 2.55, cast)
		right_el = lerpf(right_el, 0.25, cast)
		left_el = lerpf(left_el, 0.4, cast)
		spine_x = lerpf(spine_x, -0.28, cast)
		_rot("head", "x", -0.32 * cast)
	_rot("sh_l", "x", left_sh)
	_rot("el_l", "x", left_el)
	_rot("sh_r", "x", right_sh)
	_rot("el_r", "x", right_el)
	_rot("sh_l", "z", 0.1)
	_rot("sh_r", "z", -0.1)
	if spine:
		spine.rotation.x = spine_x - flinch * 0.35
		spine.rotation.y = spine_y
	var head_n := parts.get("head") as Node3D
	if head_n and cast <= 0.0:
		head_n.rotation.x = flinch * 0.4 - _run_s * 0.12 * w
	# Повітря: ноги підібрані, руки трохи розведені.
	if _air_s > 0.01:
		_rot("hip_l", "x", lerpf(s * stride * w, 0.55, _air_s))
		_rot("hip_r", "x", lerpf(-s * stride * w, -0.35, _air_s))
		_rot("knee_l", "x", lerpf(-(maxf(0.0, c) * bend * w + 0.03), -0.9, _air_s))
		_rot("knee_r", "x", lerpf(-(maxf(0.0, -c) * bend * w + 0.03), -0.5, _air_s))
		if body:
			body.position.y += 0.0
		if spine:
			spine.rotation.x -= 0.1 * _air_s
	# Сидіння: стегна вперед, коліна зігнуті; у сідлі ноги розведені по боках коня.
	if sit > 0.01:
		var hip_x := 0.8 if saddle else 1.45
		var knee_x := -1.15 if saddle else -1.5
		for side in ["l", "r"]:
			var sg := -1.0 if side == "l" else 1.0
			_rot("hip_" + side, "x", lerpf(float(parts["hip_" + side].rotation.x), hip_x, sit))
			_rot("knee_" + side, "x", lerpf(float(parts["knee_" + side].rotation.x), knee_x, sit))
			if saddle:
				_rot("hip_" + side, "z", sg * 0.42 * sit)
	elif parts.has("hip_l"):
		_rot("hip_l", "z", 0.0)
		_rot("hip_r", "z", 0.0)
