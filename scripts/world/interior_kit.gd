class_name InteriorKit
extends RefCounted
## Інтер'єри хатин (кімната 8×7 м, висота 3.2 м). Двері й вихід — на стіні -Z, піч — біля західної стіни (-X).
## Теми: мисливець, відьма, відлюдник, болото, родина (село), ферма, селище. Усе в PSX-стилі.

const SIT_SPOT := Vector3(-1.85, 0.0, 1.2)
const EXIT_SPOT := Vector3(0.0, 0.0, -2.5)
const SPAWN_SPOT := Vector3(0.0, 0.1, -2.1)
const FIRE_SPOT := Vector3(-2.4, 0.85, 1.2)


static func _bed(kit: MeshKit, x: float, z: float, yaw: float, blanket: String = "cloth_red") -> void:
	var b := Basis(Vector3.UP, yaw)
	var c := Vector3(x, 0.0, z)
	kit.box("wood", Transform3D(b, c + Vector3(0, 0.25, 0)), Vector3(1.05, 0.3, 2.1), true)
	kit.box("cloth_tent", Transform3D(b, c + Vector3(0, 0.45, 0)), Vector3(0.95, 0.14, 1.95))
	kit.box("cloth_black", Transform3D(b, c + b * Vector3(0, 0.58, 0.8)), Vector3(0.6, 0.14, 0.35))
	kit.box(blanket, Transform3D(b, c + b * Vector3(0, 0.56, -0.25)), Vector3(0.98, 0.1, 1.2))
	kit.box("wood", Transform3D(b, c + b * Vector3(0, 0.7, 1.05)), Vector3(1.05, 0.7, 0.1))


static func _table(kit: MeshKit, x: float, z: float, w: float, d: float, yaw: float = 0.0) -> void:
	var b := Basis(Vector3.UP, yaw)
	var c := Vector3(x, 0.0, z)
	kit.box("wood_light", Transform3D(b, c + Vector3(0, 0.8, 0)), Vector3(w, 0.1, d), true)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			kit.box("wood", Transform3D(b, c + b * Vector3(sx * (w * 0.5 - 0.1), 0.38, sz * (d * 0.5 - 0.1))), Vector3(0.12, 0.76, 0.12), true)


static func _stool(kit: MeshKit, x: float, z: float) -> void:
	kit.cylinder_at("wood", Vector3(x, 0.0, z), 0.2, 0.22, 0.46, 7, true)


static func _mug(kit: MeshKit, p: Vector3) -> void:
	kit.cylinder_at("iron", p, 0.07, 0.08, 0.13, 6)


static func _candle(root: Node3D, kit: MeshKit, p: Vector3, energy: float = 0.9) -> void:
	kit.cylinder_at("bone", p, 0.03, 0.03, 0.16, 5)
	kit.box_at("ember", p + Vector3(0, 0.18, 0), Vector3(0.05, 0.08, 0.05))
	BuildingKit._light(root, kit, p + Vector3(0, 0.4, 0), Color("#ffb060"), energy, 6.0, 0.25, 8.0)


static func _shelf(kit: MeshKit, p: Vector3, yaw: float, items: Array) -> void:
	## items — ключі матеріалів предметів на полицях (по 2 яруси).
	var b := Basis(Vector3.UP, yaw)
	for level in range(2):
		var y := 1.1 + float(level) * 0.65
		kit.box("wood", Transform3D(b, p + Vector3(0, y, 0)), Vector3(1.8, 0.07, 0.34))
		for k in range(5):
			var key: String = items[(k + level * 2) % items.size()]
			var off := b * Vector3(-0.7 + float(k) * 0.35, y + 0.17, 0.0)
			if key in ["window_green", "window_blue", "window"]:
				kit.cylinder_at(key, p + off - Vector3(0, 0.0, 0.0), 0.07, 0.07, 0.22, 6)
			elif key == "bone":
				kit.box("bone", Transform3D(b, p + off), Vector3(0.14, 0.16, 0.14))
			else:
				kit.box(key, Transform3D(b, p + off), Vector3(0.2, 0.26, 0.16))
	for sx: float in [-1.0, 1.0]:
		kit.box("wood", Transform3D(b, p + b * Vector3(sx * 0.9, 0.9, 0.0)), Vector3(0.07, 1.8, 0.3))


static func _chest(kit: MeshKit, x: float, z: float, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var c := Vector3(x, 0.0, z)
	kit.box("wood", Transform3D(b, c + Vector3(0, 0.3, 0)), Vector3(1.0, 0.6, 0.55), true)
	kit.box("wood_light", Transform3D(b, c + Vector3(0, 0.66, 0)), Vector3(1.04, 0.12, 0.58))
	for sx: float in [-0.35, 0.35]:
		kit.box("iron", Transform3D(b, c + b * Vector3(sx, 0.4, -0.28)), Vector3(0.08, 0.6, 0.03))


static func _rug(kit: MeshKit, x: float, z: float, w: float, d: float, key: String) -> void:
	kit.box_at(key, Vector3(x, 0.02, z), Vector3(w, 0.03, d))
	kit.box_at("wood", Vector3(x, 0.035, z), Vector3(w - 0.35, 0.02, d - 0.35))


static func _hang(kit: MeshKit, p: Vector3, key: String, length: float) -> void:
	kit.box_at("wood", p + Vector3(0, 0.0, 0), Vector3(0.6, 0.04, 0.04))
	kit.box_at(key, p + Vector3(0, -length * 0.5, 0), Vector3(0.12, length, 0.12))
	kit.box_at(key, p + Vector3(0.22, -length * 0.4, 0), Vector3(0.1, length * 0.8, 0.1))
	kit.box_at(key, p + Vector3(-0.22, -length * 0.35, 0), Vector3(0.1, length * 0.7, 0.1))


static func build(theme: String, seed_value: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Interior_" + theme
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var kit := MeshKit.new()
	# --- Оболонка кімнати ----------------------------------------------------------------------
	kit.box_at("wood", Vector3(0, -0.2, 0), Vector3(8.6, 0.4, 7.6), true)
	kit.box_at("wood_light", Vector3(0, 0.01, 0), Vector3(7.8, 0.02, 6.8))
	for i in range(8):
		kit.box_at("wood", Vector3(0, 0.025, -3.2 + float(i) * 0.9), Vector3(7.8, 0.012, 0.04))
	kit.box_at("wood", Vector3(0, 3.35, 0), Vector3(8.6, 0.3, 7.6), true)
	kit.box_at("wood_light", Vector3(0, 3.2, 0), Vector3(8.0, 0.04, 7.0))
	for i in range(6):
		kit.box_at("wood", Vector3(-3.5 + float(i) * 1.4, 3.05, 0), Vector3(0.22, 0.3, 7.0))
	kit.box_at("wood_light", Vector3(0, 1.6, 3.65), Vector3(8.6, 3.4, 0.3), true)
	kit.box_at("wood_light", Vector3(-4.15, 1.6, 0), Vector3(0.3, 3.4, 7.6), true)
	kit.box_at("wood_light", Vector3(4.15, 1.6, 0), Vector3(0.3, 3.4, 7.6), true)
	# Передня стіна з дверним прорізом (двері — вихід).
	for sx: float in [-1.0, 1.0]:
		kit.box_at("wood_light", Vector3(sx * 2.7, 1.6, -3.65), Vector3(2.9, 3.4, 0.3), true)
	kit.box_at("wood_light", Vector3(0, 2.75, -3.65), Vector3(1.4, 1.0, 0.3), true)
	kit.box_at("wood", Vector3(0, 1.05, -3.52), Vector3(1.3, 2.1, 0.12), true)
	for y: float in [0.5, 1.6]:
		kit.box_at("iron", Vector3(0, y, -3.44), Vector3(1.3, 0.1, 0.03))
	kit.box_at("iron", Vector3(0.5, 1.0, -3.43), Vector3(0.1, 0.1, 0.05))
	# Стовпи по кутах та плінтус.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			kit.box_at("wood", Vector3(sx * 3.95, 1.6, sz * 3.45), Vector3(0.3, 3.2, 0.3))
	# Вікна: світні шибки з віконницями (праворуч і ліворуч).
	for wz: float in [-1.2, 1.8]:
		kit.box_at("window", Vector3(3.97, 1.7, wz), Vector3(0.04, 0.9, 0.8))
		kit.box_at("wood", Vector3(3.95, 1.7, wz), Vector3(0.06, 0.9, 0.05))
		kit.box_at("wood", Vector3(3.95, 1.7, wz), Vector3(0.06, 0.05, 0.8))
	kit.box_at("window", Vector3(0, 1.8, 3.47), Vector3(0.9, 0.8, 0.04))
	kit.box_at("wood", Vector3(0, 1.8, 3.45), Vector3(0.05, 0.8, 0.05))
	# --- Піч біля західної стіни (місце для відпочинку) -------------------------------------------
	kit.box_at("brick", Vector3(-3.4, 0.55, 1.2), Vector3(1.0, 1.1, 1.3), true)
	kit.box_at("stone", Vector3(-3.4, 1.14, 1.2), Vector3(1.1, 0.08, 1.4))
	kit.box_at("cave_dark", Vector3(-2.88, 0.5, 1.2), Vector3(0.05, 0.5, 0.6))
	kit.box_at("ember", Vector3(-2.9, 0.32, 1.2), Vector3(0.05, 0.18, 0.5))
	kit.box_at("brick", Vector3(-3.55, 2.2, 1.2), Vector3(0.5, 2.2, 0.5))
	for k in range(3):
		kit.cylinder_at("wood_light", Vector3(-3.0, 0.15 + float(k) * 0.22, 2.1), 0.1, 0.1, 0.8, 6, false, Vector3(0, 0, PI * 0.5))
	kit.box_at("iron", Vector3(-3.0, 0.1, 0.25), Vector3(0.5, 0.06, 0.4))
	BuildingKit._light(root, kit, FIRE_SPOT, Color("#ff8a3a"), 2.6, 9.0, 0.32, 9.0, false, true)
	# --- Меблі за темою -----------------------------------------------------------------------------
	match theme:
		"hunter":
			_bed(kit, 3.0, 2.4, PI, "cloth_tent")
			_table(kit, 0.5, 0.2, 1.8, 1.0)
			_stool(kit, 0.1, -0.6)
			_stool(kit, 1.1, 1.0)
			_mug(kit, Vector3(0.2, 0.85, 0.1))
			_candle(root, kit, Vector3(0.9, 0.85, 0.3))
			_shelf(kit, Vector3(0.0, 0.0, 3.42), PI, ["bone", "cloth_tent", "iron"])
			# Стійка зі списами, шкури та роги на стінах.
			for k in range(3):
				kit.box_at("wood", Vector3(3.9, 1.3, -1.8 + float(k) * 0.35), Vector3(0.05, 2.2, 0.05), false, Vector3(0.05, 0, 0.08))
				kit.box_at("iron", Vector3(3.88, 2.5, -1.8 + float(k) * 0.35), Vector3(0.06, 0.25, 0.06))
			kit.box_at("cloth_tent", Vector3(-4.0, 2.0, -1.8), Vector3(0.05, 1.3, 0.9))
			kit.box_at("cloth_tent", Vector3(-4.0, 1.9, 3.0), Vector3(0.05, 1.1, 0.8))
			kit.box_at("bone", Vector3(-3.95, 2.7, -0.4), Vector3(0.1, 0.12, 0.6))
			_chest(kit, 3.3, -1.8, PI * 0.5)
			BuildingKit._barrel(kit, Vector3(-3.4, 0.0, -2.8))
			_rug(kit, 0.4, -1.8, 2.4, 1.6, "cloth_tent")
		"witch":
			_bed(kit, 3.0, 2.5, PI)
			_table(kit, 0.0, 0.4, 2.2, 1.1)
			kit.cylinder_at("iron", Vector3(0.6, 0.85, 0.4), 0.28, 0.2, 0.3, 8)
			kit.cylinder_at("window_green", Vector3(0.6, 1.14, 0.4), 0.22, 0.22, 0.03, 8)
			BuildingKit._light(root, kit, Vector3(0.6, 1.6, 0.4), Color("#6fe39a"), 1.8, 7.0, 0.3, 4.0)
			for k in range(4):
				kit.cylinder_at(["window_green", "window_blue", "window", "window_green"][k], Vector3(-0.7 + float(k) * 0.28, 0.85, 0.1), 0.06, 0.06, 0.2, 6)
			_candle(root, kit, Vector3(-0.8, 0.85, 0.8))
			_shelf(kit, Vector3(0.0, 0.0, 3.42), PI, ["window_green", "bone", "window_blue", "cloth_red"])
			_shelf(kit, Vector3(3.95, 0.0, -0.6), -PI * 0.5, ["window_blue", "window_green", "bone"])
			for k in range(3):
				_hang(kit, Vector3(-1.4 + float(k) * 1.6, 3.0, -1.2 + float(k % 2) * 2.2), "moss_stone", 0.7)
			_rug(kit, 0.0, -1.5, 3.0, 2.0, "cloth_red")
			_chest(kit, -3.3, -2.5, 0.0)
			kit.box_at("bone", Vector3(3.0, 1.2, -3.3), Vector3(0.3, 0.3, 0.3))
			BuildingKit._light(root, kit, Vector3(3.0, 1.5, -3.0), Color("#9c72d4"), 1.0, 5.0, 0.2, 3.0)
		"hermit":
			_bed(kit, 3.2, 2.5, PI, "cloth_black")
			_table(kit, 0.4, 0.3, 1.4, 0.9)
			for k in range(4):
				kit.box_at(["wood_light", "cloth_red", "stone", "wood"][k], Vector3(0.0 + float(k % 2) * 0.35, 0.9 + float(k / 2) * 0.1, 0.2 + float(k % 2) * 0.1), Vector3(0.3, 0.1, 0.22))
			_candle(root, kit, Vector3(0.9, 0.85, 0.5), 1.1)
			_candle(root, kit, Vector3(0.0, 0.85, 0.6), 1.1)
			_shelf(kit, Vector3(-0.2, 0.0, 3.42), PI, ["wood_light", "cloth_red", "stone"])
			# Куточок молитви: невеликий вівтар зі свічками.
			kit.box_at("stone", Vector3(3.3, 0.35, -2.4), Vector3(1.0, 0.7, 0.7), true)
			kit.box_at("stone_dark", Vector3(3.3, 0.78, -2.4), Vector3(1.1, 0.1, 0.8))
			_candle(root, kit, Vector3(3.3, 0.83, -2.4), 1.2)
			for k in range(3):
				kit.cylinder_at("moss_stone", Vector3(-1.2 + float(k) * 0.55, 0.0, -2.6), 0.22, 0.18, 0.4, 6)
				kit.pyramid("moss_stone", Transform3D(Basis(), Vector3(-1.2 + float(k) * 0.55, 0.4, -2.6)), 0.5, 0.5, 0.35)
			_rug(kit, 0.3, -0.4, 2.0, 1.4, "cloth_black")
		"swamp":
			_bed(kit, -0.2, 2.6, PI * 0.5, "cloth_black")
			_table(kit, 1.8, -0.3, 1.6, 1.0)
			_stool(kit, 1.0, -0.4)
			_stool(kit, 2.5, -0.9)
			_candle(root, kit, Vector3(1.9, 0.85, -0.2))
			for k in range(2):
				kit.cylinder_at("wood_light", Vector3(2.4 + float(k) * 0.3, 0.85, -0.1), 0.18, 0.15, 0.1, 7)
			_shelf(kit, Vector3(3.95, 0.0, 1.9), -PI * 0.5, ["bone", "cloth_black", "wood_light"])
			# Рибальські сіті й в'ялена риба.
			for k in range(4):
				kit.box_at("cloth_black", Vector3(-1.6 + float(k) * 0.9, 2.2, 3.45), Vector3(0.8, 1.3, 0.03), false, Vector3(0, 0, 0.1 * float(k)))
			for k in range(5):
				kit.box_at("bone", Vector3(-1.0 + float(k) * 0.4, 2.6, -2.4), Vector3(0.05, 0.4, 0.03))
			kit.box_at("wood", Vector3(0.2, 2.9, -2.4), Vector3(2.4, 0.05, 0.05))
			BuildingKit._barrel(kit, Vector3(3.4, 0.0, -2.7))
			BuildingKit._barrel(kit, Vector3(2.7, 0.0, -2.9))
			kit.box_at("wood_light", Vector3(-1.0, 0.02, -1.5), Vector3(2.6, 0.03, 1.8))
		"farm":
			_bed(kit, 3.0, 2.4, PI, "cloth_tent")
			_bed(kit, 1.7, 2.4, PI, "cloth_red")
			_table(kit, 0.3, -0.3, 2.6, 1.0)
			_stool(kit, -0.4, -1.2)
			_stool(kit, 0.4, -1.2)
			_stool(kit, 1.2, 0.5)
			_mug(kit, Vector3(0.0, 0.85, -0.2))
			_mug(kit, Vector3(0.7, 0.85, -0.4))
			_candle(root, kit, Vector3(0.4, 0.85, 0.0))
			# Мішки, сіно та інструменти.
			for k in range(4):
				kit.box_at("cloth_tent", Vector3(-3.3 + float(k % 2) * 0.55, 0.3, 2.9 - float(k / 2) * 0.55), Vector3(0.5, 0.6, 0.4), true, Vector3(0, 0.3 * float(k), 0))
			for k in range(3):
				kit.box_at("wood", Vector3(3.9, 1.5, -2.6 + float(k) * 0.4), Vector3(0.05, 2.0, 0.05), false, Vector3(0.0, 0, 0.1))
				kit.box_at("iron", Vector3(3.85, 2.55, -2.6 + float(k) * 0.4), Vector3(0.05, 0.3, 0.15))
			BuildingKit._crate(kit, Vector3(-3.4, 0.0, -2.8), 0.8, 0.3)
			BuildingKit._crate(kit, Vector3(-2.7, 0.0, -3.0), 0.6, 0.7)
		"village", "hamlet":
			_bed(kit, 3.2, 2.5, PI)
			_bed(kit, 3.2, 0.1, PI)
			kit.box_at("wood_light", Vector3(2.0, 0.3, 2.9), Vector3(0.7, 0.5, 0.5), true)
			_table(kit, 0.2, 0.0, 2.0, 1.1)
			_stool(kit, -0.4, -0.9)
			_stool(kit, 0.5, -0.9)
			_stool(kit, 0.9, 0.9)
			_mug(kit, Vector3(0.0, 0.85, 0.1))
			_mug(kit, Vector3(0.5, 0.85, -0.1))
			kit.cylinder_at("bone", Vector3(0.3, 0.85, 0.3), 0.12, 0.1, 0.07, 7)
			_candle(root, kit, Vector3(-0.3, 0.85, 0.2))
			_shelf(kit, Vector3(-0.2, 0.0, 3.42), PI, ["wood_light", "iron", "cloth_tent", "stone"])
			_chest(kit, 3.2, -2.3, PI * 0.5)
			_rug(kit, 0.3, -1.8, 2.6, 1.8, "cloth_red")
			if theme == "hamlet":
				BuildingKit._barrel(kit, Vector3(-3.5, 0.0, -2.8))
				_hang(kit, Vector3(1.4, 3.0, 2.0), "cloth_tent", 0.5)
			else:
				kit.cylinder_at("wood", Vector3(-3.4, 0.0, -2.6), 0.4, 0.4, 0.5, 8, true)
				kit.cylinder_at("window", Vector3(-3.4, 0.5, -2.6), 0.3, 0.3, 0.02, 8)
		_:
			_bed(kit, 3.2, 2.5, PI)
			_table(kit, 0.2, 0.0, 1.8, 1.0)
			_stool(kit, 0.2, -0.9)
			_candle(root, kit, Vector3(0.3, 0.85, 0.1))
	# Підвішені пучки трав і ліхтар під стелею — у кожного будинку своє розташування.
	var lamp_x := rng.randf_range(-1.5, 1.5)
	kit.box_at("iron", Vector3(lamp_x, 2.95, -0.4), Vector3(0.04, 0.5, 0.04))
	kit.box_at("window", Vector3(lamp_x, 2.6, -0.4), Vector3(0.22, 0.28, 0.22))
	BuildingKit._light(root, kit, Vector3(lamp_x, 2.5, -0.4), Color("#ffb060"), 1.0, 8.0, 0.18, 4.0)
	for key in kit._tools.keys():
		kit.set_material(key, BuildingKit.mat(key))
	kit.build(root, "InteriorMesh", 0.0)
	return root
