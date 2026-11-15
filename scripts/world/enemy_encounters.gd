class_name EnemyEncounters
extends Node
## Продумані зустрічі з новими ворогами (замість випадкового розкидання):
##  • Логово Кістяної Вдови біля Болотної хатини: ритуальне коло з черепами. Відьма з'являється з-під землі,
##    коли герой, виконуючи доручення Руна Слідопита «Кістяна Вдова», доходить до логова.
##  • Кістяні шакали, важкий кістяний вартовий і віщуни стережуть конкретні місця: брід, браму, обсерваторію, південну браму.

const KINDS: Dictionary = {
	"witch": {"enemy_type": "skeleton_witch", "brain_kind": "skeleton_witch", "display_name": "КІСТЯНА ВДОВА", "max_health": 280.0, "attack_damage": 12.0,
		"move_speed": 3.4, "detection_range": 45.0, "scale": 1.12},
	"skirmisher": {"enemy_type": "skirmisher", "brain_kind": "skirmisher", "display_name": "КІСТЯНИЙ ШАКАЛ", "max_health": 55.0, "attack_damage": 10.0,
		"move_speed": 6.0, "detection_range": 34.0, "scale": 0.95},
	"bone_knight": {"enemy_type": "bone_knight", "brain_kind": "bone_knight", "display_name": "КІСТЯНИЙ ВАРТОВИЙ", "max_health": 320.0, "attack_damage": 30.0,
		"move_speed": 1.9, "detection_range": 26.0, "scale": 1.4},
	"bone_seer": {"enemy_type": "bone_seer", "brain_kind": "bone_seer", "display_name": "ПОПЕЛЯСТИЙ ВІЩУН", "max_health": 90.0, "attack_damage": 10.0,
		"move_speed": 3.0, "detection_range": 42.0, "scale": 1.05},
}

## Групи: [будівля, відступ уперед, відступ убік, [[вид, зсув x, зсув z], ...]]
const GROUPS: Array = [
	["Зольний Брід", 30.0, 16.0, [["skirmisher", 0.0, 0.0], ["skirmisher", 4.0, 3.0], ["skirmisher", -3.0, 5.0]]],
	["Брама велетнів", 9.0, 0.0, [["bone_knight", 0.0, 0.0]]],
	["Зруйнована Обсерваторія", 12.0, 0.0, [["bone_seer", -6.0, 0.0], ["bone_seer", 6.0, 3.0]]],
	["Південна Брама", 16.0, 0.0, [["bone_knight", 0.0, 0.0], ["bone_seer", 8.0, 4.0], ["skirmisher", -6.0, 2.0], ["skirmisher", -8.0, -3.0]]],
]

var world = null
var main = null
var lair: Vector3 = Vector3.ZERO
var witch: Node = null
var _witch_spawned: bool = false


func setup(world_node) -> void:
	world = world_node
	main = world.get_parent()
	for g in GROUPS:
		var base: Vector3 = world._building_front_position(str(g[0]), float(g[1]), float(g[2]))
		if base == Vector3.ZERO:
			continue
		for m in g[3]:
			var pos := base + Vector3(float(m[1]), 0.0, float(m[2]))
			pos.y = world._terrain_height_at_world(pos.x, pos.z)
			spawn(str(m[0]), pos)
	_build_lair()
	if not QuestManager.quest_progressed.is_connected(_on_progress):
		QuestManager.quest_progressed.connect(_on_progress)


func spawn(kind: String, local_pos: Vector3) -> Node:
	var props: Dictionary = (KINDS[kind] as Dictionary).duplicate()
	return world._spawn_special_wraith(local_pos, props)


func _build_lair() -> void:
	## Ритуальне коло перед Болотною хаткою: темний диск, вісім жердин із черепами, кістки.
	var p: Vector3 = world._building_front_position("Болотна хатина", 14.0, 0.0)
	if p == Vector3.ZERO:
		return
	p.y = world._terrain_height_at_world(p.x, p.z)
	lair = p
	world.story_positions["mission_swamp"] = p
	LocationTrigger.create(world, p + Vector3(0, 2.0, 0), "mission_swamp", "Логово Кістяної Вдови", 30.0)
	var root := Node3D.new()
	root.name = "WitchLair"
	world.add_child(root)
	root.position = p
	var bone := PSXMaterials.make(Color("#d8d0b8"), 0.0, 0.9, Color.BLACK, 0.0, "stone", false)
	var wood := PSXMaterials.make(Color("#2e2218"), 0.0, 0.95, Color.BLACK, 0.0, "planks", false)
	var dark := PSXMaterials.make(Color(0.1, 0.04, 0.16), 0.0, 1.0, Color("#3a1060"), 0.8, "none", false)
	var glow := PSXMaterials.make(Color("#a060ff"), 0.0, 0.3, Color("#a060ff"), 2.5, "none", false)
	var disc := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 6.2
	dm.bottom_radius = 6.4
	dm.height = 0.06
	dm.radial_segments = 16
	disc.mesh = dm
	disc.material_override = dark
	disc.position = Vector3(0, 0.12, 0)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(disc)
	for i in range(8):
		var a := TAU * float(i) / 8.0
		var pole := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.12, 2.6, 0.12)
		pole.mesh = pm
		pole.material_override = wood
		pole.position = Vector3(cos(a) * 7.0, 1.3, sin(a) * 7.0)
		root.add_child(pole)
		var skull := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.2
		sm.height = 0.4
		sm.radial_segments = 8
		sm.rings = 4
		skull.mesh = sm
		skull.material_override = bone
		skull.position = Vector3(cos(a) * 7.0, 2.7, sin(a) * 7.0)
		root.add_child(skull)
		for side in [-1.0, 1.0]:
			var eye := MeshInstance3D.new()
			var em := BoxMesh.new()
			em.size = Vector3(0.06, 0.06, 0.04)
			eye.mesh = em
			eye.material_override = glow
			eye.position = skull.position + Vector3(cos(a + 0.35 * side) * 0.18, 0.04, sin(a + 0.35 * side) * 0.18)
			root.add_child(eye)
	for i in range(9):
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.08, randf_range(0.3, 0.6), 0.08)
		b.mesh = bm
		b.material_override = bone
		var a2 := randf() * TAU
		var r2 := randf_range(1.0, 5.5)
		b.position = Vector3(cos(a2) * r2, 0.18, sin(a2) * r2)
		b.rotation = Vector3(randf_range(1.2, 1.9), randf() * TAU, randf_range(-0.3, 0.3))
		root.add_child(b)


func _on_progress(quest_id: String, _text: String, progress: int, _total: int) -> void:
	if quest_id == "bone_widow" and progress >= 1 and not _witch_spawned and lair != Vector3.ZERO:
		_witch_spawned = true
		_rise_witch()


func _rise_witch() -> void:
	## Відьма виростає з ритуального кола: земля тремтить, шепіт, вона піднімається разом із пилом.
	await get_tree().create_timer(1.0).timeout
	witch = spawn("witch", lair)
	if witch == null:
		return
	var rig: Node3D = witch.get("_rig")
	witch.set_physics_process(false)
	witch.collision_layer = 0
	witch.collision_mask = 0
	var at: Vector3 = world.to_global(lair)
	witch.global_position = at + Vector3(0, -2.4, 0)
	if rig:
		rig.set("cast", 1.0)
	AudioManager.play_sfx("strange_whisper", 2.0, 0.0)
	AudioManager.play_sfx("far_horn", -4.0, 0.0)
	main.call("_show_story_toast", "ЛОГОВО КІСТЯНОЇ ВДОВИ", "Земля в колі череп'яних жердин тремтить: з неї повільно підіймається висока постать у капелюсі.", 6.0)
	var tw: Tween = witch.create_tween()
	tw.tween_property(witch, "global_position:y", at.y + 0.1, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(witch):
			return
		witch.collision_layer = 2
		witch.collision_mask = 1
		witch.set_physics_process(true)
		if rig:
			create_tween().tween_property(rig, "cast", 0.0, 0.5)
		AudioManager.play_sfx_3d("wraith_growl", witch.global_position, 4.0, 60.0, 8.0))
