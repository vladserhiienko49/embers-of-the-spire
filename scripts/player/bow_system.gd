class_name BowSystem
extends Node
## Лук і стріли гравця. Клавіша B — дістати/сховати лук (потрібно купити у чародійки Іліри),
## ЛКМ — натягнути тятиву (чим довше, тим сильніше й далі), відпустити — вистрілити.
## Стріли летять по параболі, вражають ворогів (постріл у голову — ×1.6) і застрягають у землі.

const DRAW_TIME: float = 0.85
const MIN_CHARGE: float = 0.22
const BASE_DAMAGE: float = 24.0
const MAX_BONUS_DAMAGE: float = 40.0
const SPEED_MIN: float = 32.0
const SPEED_MAX: float = 70.0
const FP_BOW_POS: Vector3 = Vector3(-0.34, -0.3, -0.85)
const FP_BOW_ROT: Vector3 = Vector3(0.0, 14.0, 8.0)
const TP_BOW_POS: Vector3 = Vector3(-0.32, 1.22, -0.5)
const LIMB_POINTS: Array = [Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.26, 0.02), Vector3(0.0, 0.5, 0.1), Vector3(0.0, 0.7, 0.22)]

var player: CharacterBody3D = null
var camera: Camera3D = null
var equipped: bool = false
var charging: bool = false
var charge: float = 0.0
var _cooldown: float = 0.0
var _anchor_fp: Node3D = null
var _anchor_tp: Node3D = null
var _model: Node3D = null
var _string_top: MeshInstance3D = null
var _string_bottom: MeshInstance3D = null
var _nocked: Node3D = null
var _hud_layer: CanvasLayer = null
var _hud_root: Control = null
var _hud_bar: ColorRect = null
var _draw_sound_played: bool = false


func setup(owner_player: CharacterBody3D, owner_camera: Camera3D) -> void:
	player = owner_player
	camera = owner_camera
	_anchor_fp = Node3D.new()
	_anchor_fp.name = "FPBowAnchor"
	_anchor_fp.position = FP_BOW_POS
	_anchor_fp.rotation_degrees = FP_BOW_ROT
	camera.add_child(_anchor_fp)
	_anchor_tp = Node3D.new()
	_anchor_tp.name = "TPBowAnchor"
	_anchor_tp.position = TP_BOW_POS
	player.add_child(_anchor_tp)
	_build_model()
	_build_hud()
	_apply_visibility()


# --- Модель ----------------------------------------------------------------------------------

func _segment(parent: Node3D, a: Vector3, b: Vector3, thickness: float, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(thickness, thickness, maxf(a.distance_to(b), 0.001))
	mesh.mesh = box
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	_place_segment(mesh, a, b)
	return mesh


func _place_segment(mesh: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var dir := b - a
	if dir.length() < 0.001:
		return
	(mesh.mesh as BoxMesh).size.z = dir.length()
	mesh.transform = Transform3D(Basis.looking_at(dir.normalized(), Vector3.RIGHT), (a + b) * 0.5)


func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "Bow"
	var wood := PSXMaterials.make(Color("#4a2f1b"), 0.0, 0.9, Color.BLACK, 0.0, "planks", false)
	var dark := PSXMaterials.make(Color("#2a1b10"), 0.0, 0.95, Color.BLACK, 0.0, "planks", false)
	var cord := PSXMaterials.make(Color("#c9bfa0"), 0.0, 1.0, Color.BLACK, 0.0, "none", false)
	var iron := PSXMaterials.make(Color("#4a4c52"), 0.7, 0.5, Color.BLACK, 0.0, "metal", false)
	# Дві дуги-плеча (вгору й вниз) та руків'я.
	for sign_y in [1.0, -1.0]:
		for i in range(LIMB_POINTS.size() - 1):
			var a: Vector3 = LIMB_POINTS[i]
			var b: Vector3 = LIMB_POINTS[i + 1]
			_segment(_model, Vector3(a.x, a.y * sign_y, a.z), Vector3(b.x, b.y * sign_y, b.z), 0.045 - 0.008 * float(i), wood)
	_segment(_model, Vector3(0, -0.1, 0.0), Vector3(0, 0.1, 0.0), 0.06, dark)
	var tip: Vector3 = LIMB_POINTS[LIMB_POINTS.size() - 1]
	for sign_y in [1.0, -1.0]:
		var cap := MeshInstance3D.new()
		var cap_mesh := BoxMesh.new()
		cap_mesh.size = Vector3(0.05, 0.05, 0.05)
		cap.mesh = cap_mesh
		cap.material_override = iron
		cap.position = Vector3(0.0, tip.y * sign_y, tip.z)
		_model.add_child(cap)
	_string_top = _segment(_model, Vector3(0, tip.y, tip.z), Vector3(0, 0, tip.z), 0.012, cord)
	_string_bottom = _segment(_model, Vector3(0, 0, tip.z), Vector3(0, -tip.y, tip.z), 0.012, cord)
	# Стріла на тятиві.
	_nocked = Node3D.new()
	_nocked.name = "NockedArrow"
	_build_arrow_mesh(_nocked, 0.78)
	_model.add_child(_nocked)
	_update_string(0.0)


static func _build_arrow_mesh(parent: Node3D, length: float) -> void:
	## Стріла вздовж -Z: хвіст у (0,0,0), вістря попереду.
	var shaft_mat := PSXMaterials.make(Color("#8a6a42"), 0.0, 0.9, Color.BLACK, 0.0, "planks", false)
	var tip_mat := PSXMaterials.make(Color("#8c8f99"), 0.8, 0.4, Color.BLACK, 0.0, "metal", false)
	var feather_mat := PSXMaterials.make(Color("#a83b2c"), 0.0, 1.0, Color.BLACK, 0.0, "cloth", false)
	var shaft := MeshInstance3D.new()
	var shaft_mesh := BoxMesh.new()
	shaft_mesh.size = Vector3(0.018, 0.018, length)
	shaft.mesh = shaft_mesh
	shaft.material_override = shaft_mat
	shaft.position = Vector3(0, 0, -length * 0.5)
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(shaft)
	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.04, 0.012, 0.09)
	head.mesh = head_mesh
	head.material_override = tip_mat
	head.position = Vector3(0, 0, -length - 0.03)
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(head)
	for rot in [0.0, PI * 0.5]:
		var feather := MeshInstance3D.new()
		var feather_mesh := BoxMesh.new()
		feather_mesh.size = Vector3(0.07, 0.006, 0.12)
		feather.mesh = feather_mesh
		feather.material_override = feather_mat
		feather.position = Vector3(0, 0, -0.08)
		feather.rotation.z = rot
		feather.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(feather)


func _update_string(amount: float) -> void:
	var tip: Vector3 = LIMB_POINTS[LIMB_POINTS.size() - 1]
	var nock := Vector3(0.0, 0.0, tip.z + 0.4 * amount)
	_place_segment(_string_top, Vector3(0, tip.y, tip.z), nock)
	_place_segment(_string_bottom, nock, Vector3(0, -tip.y, tip.z))
	if _nocked:
		_nocked.position = nock
		_nocked.visible = equipped and (charging or amount > 0.02)


# --- HUD: приціл і шкала натягу -----------------------------------------------------------

func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 6
	add_child(_hud_layer)
	_hud_root = Control.new()
	_hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(_hud_root)
	for off in [Vector2(-9, 0), Vector2(5, 0), Vector2(0, -9), Vector2(0, 5)]:
		var tick := ColorRect.new()
		tick.color = Color(0.95, 0.88, 0.7, 0.8)
		tick.anchor_left = 0.5
		tick.anchor_right = 0.5
		tick.anchor_top = 0.5
		tick.anchor_bottom = 0.5
		var horizontal := absf(off.x) > 0.0
		tick.offset_left = off.x
		tick.offset_top = off.y
		tick.offset_right = off.x + (4.0 if horizontal else 2.0)
		tick.offset_bottom = off.y + (2.0 if horizontal else 4.0)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud_root.add_child(tick)
	var back := ColorRect.new()
	back.color = Color(0, 0, 0, 0.45)
	back.anchor_left = 0.5
	back.anchor_right = 0.5
	back.anchor_top = 0.5
	back.anchor_bottom = 0.5
	back.offset_left = -30.0
	back.offset_right = 30.0
	back.offset_top = 22.0
	back.offset_bottom = 27.0
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(back)
	_hud_bar = ColorRect.new()
	_hud_bar.color = Color("#e0b060")
	_hud_bar.offset_left = 1.0
	_hud_bar.offset_top = 1.0
	_hud_bar.offset_bottom = 4.0
	_hud_bar.offset_right = 1.0
	_hud_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(_hud_bar)
	_hud_root.visible = false


# --- Логіка ---------------------------------------------------------------------------------------

func has_bow() -> bool:
	return player != null and int(player.get_meta("bow_level", 0)) >= 1


func arrows() -> int:
	return int(player.get_meta("arrows", 0)) if player else 0


func add_arrows(amount: int) -> void:
	player.set_meta("arrows", arrows() + amount)


func is_drawing() -> bool:
	return equipped and charging


func toggle_equip() -> void:
	if equipped:
		unequip()
	else:
		equip()


func equip() -> bool:
	if not has_bow():
		player.emit_signal("combat_message", "У тебе немає лука. Його продає чародійка Ліра на сході.", false)
		return false
	if player.has_method("set_weapon_drawn"):
		player.call("set_weapon_drawn", false, true)
	if player.has_method("cancel_block"):
		player.call("cancel_block")
	equipped = true
	charging = false
	charge = 0.0
	_apply_visibility()
	AudioManager.play_sfx("bow_draw", -8.0, 0.1)
	player.emit_signal("combat_message", "Лук наготові  (ЛКМ — натягнути, відпусти — стріляти).  Стріл: %d" % arrows(), true)
	return true


func unequip(draw_sword: bool = true) -> void:
	if not equipped:
		return
	cancel()
	equipped = false
	_apply_visibility()
	if draw_sword and player.has_method("set_weapon_drawn"):
		player.call("set_weapon_drawn", true, true)


func cancel() -> void:
	charging = false
	charge = 0.0
	_draw_sound_played = false
	if _string_top:
		_update_string(0.0)
	if _hud_bar:
		_hud_bar.offset_right = 1.0


func begin_draw() -> void:
	if not equipped or charging or _cooldown > 0.0:
		return
	if arrows() <= 0:
		player.emit_signal("combat_message", "Немає стріл! Купи їх у чародійки Ліри.", false)
		return
	charging = true
	charge = 0.0
	_draw_sound_played = false


func release() -> void:
	if not equipped or not charging:
		return
	var power := clampf(charge / DRAW_TIME, 0.0, 1.0)
	cancel()
	if power < MIN_CHARGE:
		return
	if arrows() <= 0:
		return
	player.set_meta("arrows", arrows() - 1)
	_cooldown = 0.28
	_fire(power)


func _fire(power: float) -> void:
	var forward := -camera.global_transform.basis.z
	# Від третьої особи стріла вилітає з-перед героя (а не з камери позаду), але летить у центр прицілу.
	var lead := 0.9
	if not bool(player.get("first_person")):
		var arm = player.get("spring_arm")
		lead = (float(arm.get_hit_length()) if arm else 4.0) + 0.9
	var origin := camera.global_position + forward * lead + camera.global_transform.basis.y * -0.14 + camera.global_transform.basis.x * -0.04
	var arrow := Arrow.new()
	arrow.shooter = player
	arrow.damage = (BASE_DAMAGE + MAX_BONUS_DAMAGE * power + 7.0 * float(int(player.get_meta("bowdmg_level", 0)))) * (0.6 + 0.4 * power)
	arrow.velocity = forward * lerpf(SPEED_MIN, SPEED_MAX, power)
	arrow.power = power
	var scene := player.get_tree().current_scene
	scene.add_child(arrow)
	arrow.global_position = origin
	arrow.orient()
	AudioManager.play_sfx("bow_shot", -3.0, 0.08)
	var player_fx = player.get("fx")
	if player_fx != null and player_fx.has_method("on_swing"):
		player_fx.on_swing()
	if arrows() <= 3:
		player.emit_signal("combat_message", "Залишилося стріл: %d" % arrows(), false)


func _apply_visibility() -> void:
	var fp := bool(player.get("first_person"))
	if _model == null:
		return
	var anchor := _anchor_fp if fp else _anchor_tp
	if _model.get_parent() != anchor:
		if _model.get_parent():
			_model.get_parent().remove_child(_model)
		anchor.add_child(_model)
	_model.visible = equipped
	_model.scale = Vector3.ONE * (0.55 if fp else 0.9)
	if _hud_root:
		_hud_root.visible = equipped
	if _nocked:
		_nocked.visible = equipped and charging


func refresh_view() -> void:
	_apply_visibility()


func _process(delta: float) -> void:
	if player == null:
		return
	if _cooldown > 0.0:
		_cooldown = maxf(0.0, _cooldown - delta)
	if equipped and (not bool(player.get("controls_enabled")) or bool(player.call("is_defeated"))):
		if charging:
			cancel()
	if not equipped:
		return
	if charging:
		charge = minf(DRAW_TIME, charge + delta)
		var amount := charge / DRAW_TIME
		_update_string(amount)
		if not _draw_sound_played and charge > 0.05:
			_draw_sound_played = true
			AudioManager.play_sfx("bow_draw", -9.0, 0.05)
		if _hud_bar:
			_hud_bar.offset_right = 1.0 + 58.0 * amount
			_hud_bar.color = Color("#e0b060") if amount < 1.0 else Color("#ff7a3a")
		# Лук тремтить при повному натягу.
		_model.rotation.z = sin(Time.get_ticks_msec() * 0.03) * 0.012 * smoothstep(0.7, 1.0, amount)
	else:
		_model.rotation.z = 0.0


## Стріла: летить по параболі, шукає зіткнення променем між кадрами фізики.
class Arrow extends Node3D:
	var velocity: Vector3 = Vector3.ZERO
	var damage: float = 30.0
	var power: float = 1.0
	var shooter: Node3D = null
	var _life: float = 0.0
	var _stuck: bool = false

	func _init() -> void:
		BowSystem._build_arrow_mesh(self, 0.8)

	func orient() -> void:
		var dir := velocity.normalized()
		if dir.length() < 0.01:
			return
		var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
		global_transform = Transform3D(Basis.looking_at(dir, up), global_position)

	func _physics_process(delta: float) -> void:
		_life += delta
		if _stuck:
			if _life > 14.0:
				queue_free()
			return
		if _life > 8.0:
			queue_free()
			return
		velocity.y -= 11.0 * delta
		var from := global_position
		var to := from + velocity * delta
		var query := PhysicsRayQueryParameters3D.create(from, to, 3)
		if shooter:
			query.exclude = [shooter.get_rid()]
		query.collide_with_areas = false
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			global_position = to
			orient()
			return
		global_position = hit["position"]
		var body := hit["collider"] as Node
		if body and body.is_in_group("hostile") and body.has_method("take_damage") and not bool(body.get("dead")):
			var amount := damage
			var head := false
			var body3d := body as Node3D
			if body3d and global_position.y > body3d.global_position.y + 1.45 * body3d.scale.y:
				amount *= 1.6
				head = true
			body.call("take_damage", amount, shooter)
			AudioManager.play_sfx("hit_flesh", -2.0, 0.08)
			if shooter and shooter.has_signal("combat_message"):
				shooter.emit_signal("combat_message", ("ВЛУЧНО В ГОЛОВУ!  -%d" if head else "СТРІЛА!  -%d") % int(amount), true)
			var fx = shooter.get("fx") if shooter else null
			if fx and fx.has_method("on_hit"):
				fx.on_hit(global_position)
			queue_free()
			return
		_stuck = true
		_life = 0.0
		AudioManager.play_sfx_3d("arrow_hit", global_position, -4.0, 30.0, 4.0)
		# Стріла застрягає у поверхні під кутом польоту.
		global_position -= velocity.normalized() * 0.1
