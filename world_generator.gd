extends Node3D

const TERRAIN_BUILDER_SCRIPT: Script = preload("res://terrain_builder.gd")
const NIGHT_SKY_SHADER: Shader = preload("res://shaders/night_sky.gdshader")
## Напрямок на місяць: над Чорною Горою, трохи правіше вершини (якщо дивитися зі старту).
const MOON_DIRECTION: Vector3 = Vector3(-0.68, 0.5, -0.54)
const WRAITH_SCENE: PackedScene = preload("res://ashen_wraith.tscn")
const SCALE = 0.12
const WORLD_W = 6700.0
const WORLD_H = 4800.0
const VIEW_DISTANCE = 260.0

var buildings_data = [
	{"name": "Хатина мисливця", "kind": "hut", "x": 900, "y": 1500, "w": 150, "h": 112, "col": "#5b4830"},
	{"name": "Хатина відьми", "kind": "hut", "x": 1500, "y": 430, "w": 150, "h": 118, "col": "#3f3043"},
	{"name": "Село Попелу", "kind": "village", "x": 1180, "y": 2070, "w": 255, "h": 190, "col": "#4e392b"},
	{"name": "Зруйнована Обсерваторія", "kind": "tower", "x": 2200, "y": 700, "w": 180, "h": 166, "col": "#5c5243"},
	{"name": "Забуте кладовище", "kind": "crypt", "x": 2240, "y": 1330, "w": 205, "h": 142, "col": "#4c4d49"},
	{"name": "Руїни Абатства", "kind": "church", "x": 600, "y": 2040, "w": 210, "h": 162, "col": "#435447"},
	{"name": "Крижана вежа", "kind": "tower", "x": 3280, "y": 280, "w": 142, "h": 206, "col": "#687e8b"},
	{"name": "Кузня Каталана", "kind": "forge", "x": 3450, "y": 2010, "w": 196, "h": 132, "col": "#6f452b"},
	{"name": "Брама велетнів", "kind": "gate", "x": 3070, "y": 1570, "w": 235, "h": 168, "col": "#5b574e"},
	{"name": "Попеляста цитадель", "kind": "castle", "x": 3240, "y": 2300, "w": 280, "h": 220, "col": "#523d39"},
	{"name": "Фортеця Чорного Прапора", "kind": "waterfort", "x": 3113, "y": 1161, "w": 420, "h": 420, "col": "#3b3946"},
	{"name": "Табір вигнанців", "kind": "camp", "x": 1670, "y": 2260, "w": 190, "h": 140, "col": "#573926"},
	{"name": "Стара сторожова вежа", "kind": "tower", "x": 1860, "y": 410, "w": 130, "h": 178, "col": "#534e43"},
	{"name": "Коло друїдів", "kind": "obelisk", "x": 590, "y": 1510, "w": 150, "h": 130, "col": "#4a5043"},
	{"name": "Лігво Прадавнього Дракона", "kind": "lair", "x": 1953, "y": 673, "w": 270, "h": 210, "col": "#472a27"},
	# --- Розширення карти: схід і південь ---
	{"name": "Вежа Місячної Лучниці", "kind": "tower", "x": 4100, "y": 1500, "w": 150, "h": 190, "col": "#4f5c66"},
	{"name": "Зольний Брід", "kind": "hamlet", "x": 4650, "y": 2150, "w": 250, "h": 190, "col": "#4a3a2c"},
	{"name": "Східна сторожова застава", "kind": "tower", "x": 5150, "y": 1550, "w": 130, "h": 178, "col": "#4f4a40"},
	{"name": "Руїни Вартової Фортеці", "kind": "ruins", "x": 5950, "y": 1250, "w": 225, "h": 176, "col": "#463e39"},
	{"name": "Камені Мовчання", "kind": "obelisk", "x": 5400, "y": 450, "w": 150, "h": 130, "col": "#4a5043"},
	{"name": "Табір мисливців Півночі", "kind": "camp", "x": 4300, "y": 600, "w": 190, "h": 140, "col": "#573926"},
	{"name": "Хатина відлюдника", "kind": "hut", "x": 5850, "y": 330, "w": 150, "h": 112, "col": "#4a3f33"},
	{"name": "Хутір Сухих Борозен", "kind": "farmstead", "x": 4150, "y": 2650, "w": 240, "h": 180, "col": "#5a4a35"},
	{"name": "Селище Соляних Копалень", "kind": "hamlet", "x": 4750, "y": 3350, "w": 250, "h": 190, "col": "#4f4a45"},
	{"name": "Склеп Забутих Королів", "kind": "crypt", "x": 5900, "y": 3850, "w": 205, "h": 142, "col": "#4c4d49"},
	{"name": "Табір прикордонників", "kind": "camp", "x": 6150, "y": 4250, "w": 190, "h": 140, "col": "#4d3a2a"},
	{"name": "Монастир Сірих Сестер", "kind": "church", "x": 2900, "y": 3750, "w": 210, "h": 162, "col": "#4b5148"},
	{"name": "Південна сторожова застава", "kind": "tower", "x": 3550, "y": 4050, "w": 130, "h": 178, "col": "#524c42"},
	{"name": "Болотна хатина", "kind": "hut", "x": 1650, "y": 3050, "w": 150, "h": 112, "col": "#3d4a3a"},
	{"name": "Ферма Попелястих Полів", "kind": "farmstead", "x": 2250, "y": 3050, "w": 240, "h": 180, "col": "#5a4a35"},
	{"name": "Південна Брама", "kind": "gate", "x": 4300, "y": 4150, "w": 235, "h": 168, "col": "#5b574e"}
]

var base_routes = [
	[Vector2(1810, 2390), Vector2(1800, 2050), Vector2(1900, 1740), Vector2(2180, 1460), Vector2(2400, 1160), Vector2(2810, 900)],
	[Vector2(1900, 1740), Vector2(1540, 1450), Vector2(1210, 1150), Vector2(950, 900), Vector2(700, 700)],
	[Vector2(2180, 1460), Vector2(2450, 1560), Vector2(2820, 1730), Vector2(3230, 1850)],
	[Vector2(1800, 2050), Vector2(1450, 2240), Vector2(1050, 2300), Vector2(650, 2220)],
	[Vector2(2180, 1460), Vector2(2180, 1050), Vector2(2320, 740), Vector2(2580, 500), Vector2(2860, 360)],
	[Vector2(1540, 1450), Vector2(1750, 1050), Vector2(2050, 740), Vector2(2350, 500)],
	[Vector2(2450, 1560), Vector2(2550, 1940), Vector2(2810, 2220), Vector2(3190, 2400)],
	# --- Розширення: східний тракт, північна гілка, південний шлях, діагональ до копалень ---
	[Vector2(3230, 1850), Vector2(3800, 1850), Vector2(4250, 1950), Vector2(4500, 2020), Vector2(5000, 1800), Vector2(5500, 1600), Vector2(6000, 1500), Vector2(6400, 1400)],
	[Vector2(2860, 360), Vector2(3500, 500), Vector2(4200, 700), Vector2(4800, 900), Vector2(5400, 800), Vector2(6000, 600)],
	[Vector2(4800, 900), Vector2(5000, 1300), Vector2(5000, 1800)],
	[Vector2(1810, 2390), Vector2(1950, 2900), Vector2(2300, 3400), Vector2(2800, 3800), Vector2(3400, 4100), Vector2(4100, 4300)],
	[Vector2(3190, 2400), Vector2(3700, 2700), Vector2(4300, 3000), Vector2(4600, 3500), Vector2(4100, 4300)],
	[Vector2(4500, 2020), Vector2(4400, 2500), Vector2(4300, 3000)],
	[Vector2(4600, 3500), Vector2(5200, 3800), Vector2(5900, 4000), Vector2(6300, 4300)]
]

signal dungeon_exited(oath_choice: String)

const DUNGEON_SPAWN_LOCAL := Vector3(29.0, -49.0, -3.0)
const DUNGEON_RETURN_LOCAL := Vector3(-25.0, -49.0, 0.0)
const OATH_ALTAR_LOCAL := Vector3(12.0, -49.0, 7.0)
const DUNGEON_EXIT_LOCAL := Vector3(-32.0, -49.0, 0.0)

# Безпечний майданчик на поверхні поруч із дорогою. Центр розташований
# у межах пласкої зони TerrainBuilder, але не прямо на декоративній дорозі.
const SURFACE_EXIT_MAP_POSITION := Vector2(1700.0, 2210.0)
const SURFACE_SPAWN_CLEARANCE := 1.42

var routes_3d = []
var forbidden_zones = []
var stream_objects = []
var player_ref: Node3D = null
var player_in_dungeon: bool = false
var oath_choice: String = ""
var oath_altar_light: OmniLight3D = null
var oath_altar_material: Material = null
var dungeon_lights: Array[OmniLight3D] = []
var dungeon_light_clock: float = 0.0

# Частина 3: мешканці світу, точки взаємодії та невелике фракційне доручення.
var building_nodes: Dictionary = {}
var building_depths: Dictionary = {}
var world_interactions: Array[Dictionary] = []
var faction_quest_stage: int = 0 # 0 — не взято, 1 — знайти доказ, 2 — повернутися, 3 — завершено.
var faction_quest_branch: String = ""
var quest_target_position: Vector3 = Vector3.ZERO
var quest_target_marker: Node3D = null
var principality_marker: Node3D = null
var mountain_marker: Node3D = null

# Етап 1: модульний рельєф та атмосферні елементи Гори-Ока.
var terrain_builder: Node3D = null
var eye_light: OmniLight3D = null
var eye_halo: MeshInstance3D = null
var eye_beam: SpotLight3D = null
var eye_clock: float = 0.0

# Цикл дня і ночі. Час зупиняється разом із керуванням гравця (меню/пауза/діалоги).
@export_range(180.0, 1800.0, 30.0) var day_cycle_duration_seconds: float = 720.0
var day_clock: float = 0.76 # 18:14 — герой виходить у світ на заході сонця
var world_environment: Environment = null
var sky_material_ref: ShaderMaterial = null
var sun_light: DirectionalLight3D = null
var moon_light: DirectionalLight3D = null
var combat_enemies: Array[Node3D] = []
var day_night_update_timer: float = 0.0
var day_night_initialized: bool = false
var night_amount_cached: float = 0.5
var story_positions: Dictionary = {}
var story_nodes: Dictionary = {}
var bridge_positions: Array[Vector3] = []
var water_materials: Array[ShaderMaterial] = []
var life: WorldLife = null
var hazards: WorldHazards = null
var horses: HorseSystem = null
var events: WorldEvents = null
var mass: MassBattle = null
var trials: WorldTrials = null
var encounters: EnemyEncounters = null
var surprises: WorldSurprises = null
var eye_finale: EyeFinale = null
## Око вирвано й знищено: вінець на вершині згасає.
var eye_destroyed: bool = false
## Відродження світу після знищення Ока (0..1): яскраве небо, сонце, туман розсіюється.
var world_renew: float = 0.0
var renewal: WorldRenewal = null


func start_renewal() -> void:
	## Після вибуху Ока від Вівтаря хвилею ростуть квіти й трава, прилітають птахи.
	if renewal:
		return
	renewal = WorldRenewal.new()
	renewal.name = "WorldRenewal"
	add_child(renewal)
	renewal.setup(self, get_arena_altar_local())
## Фрагмент карти з Оком: до проходження випробувань місце Ока на атласі прихована.
var eye_map_known: bool = false
## Фінальний світанок (0..1) — керується з GameExtras; сонце над Чорною Горою.
var finale_dawn: float = 0.0
var bonfire_local: Vector3 = Vector3.ZERO

func _ready():
	setup_environment()
	_create_terrain_system()
	_create_surface_landing_pad()
	build_biomes()
	build_roads()
	build_rivers_and_bridges()
	build_barad_dur_mountain()
	build_main_castle()
	prepare_buildings()
	prepare_trees_and_rocks()
	build_world_npcs_and_interactions()
	build_dungeon_portal_and_interior()
	safe_spawn_player()
	_spawn_combat_enemies()
	# Живий світ: інтер'єри хатин, відпочинок біля печі, коти, ягідні кущі.
	life = WorldLife.new()
	life.name = "WorldLife"
	add_child(life)
	life.setup(self)
	hazards = WorldHazards.new()
	hazards.name = "WorldHazards"
	add_child(hazards)
	hazards.setup(self)
	horses = HorseSystem.new()
	horses.name = "HorseSystem"
	add_child(horses)
	horses.setup(self)
	events = WorldEvents.new()
	events.name = "WorldEvents"
	add_child(events)
	events.setup(self)
	mass = MassBattle.new()
	mass.name = "MassBattle"
	add_child(mass)
	mass.setup(self)
	surprises = WorldSurprises.new()
	surprises.name = "WorldSurprises"
	add_child(surprises)
	surprises.setup(self)
	trials = WorldTrials.new()
	trials.name = "WorldTrials"
	add_child(trials)
	trials.setup(self)
	encounters = EnemyEncounters.new()
	encounters.name = "EnemyEncounters"
	add_child(encounters)
	encounters.setup(self)
	eye_finale = EyeFinale.new()
	eye_finale.name = "EyeFinale"
	add_child(eye_finale)
	eye_finale.setup(self)
	_update_day_night_cycle(0.0)

func _create_terrain_system() -> void:
	## TerrainSystem — дочірній модуль у сцені WorldGenerator.
	terrain_builder = get_node_or_null("TerrainSystem") as Node3D
	if terrain_builder == null:
		# Резервний шлях: дає змогу запустити сцену навіть якщо вузол ще не додали в main.tscn.
		terrain_builder = TERRAIN_BUILDER_SCRIPT.new() as Node3D
		terrain_builder.name = "TerrainSystem"
		add_child(terrain_builder)

	terrain_builder.call("configure", 1.5 * SCALE, WORLD_W, WORLD_H, base_routes, buildings_data)
	terrain_builder.call("build_terrain")


func _terrain_height_at_world(world_x: float, world_z: float) -> float:
	if terrain_builder == null:
		return 0.0
	return float(terrain_builder.call("get_height_at_world", Vector2(world_x, world_z)))


func _surface_position(map_x: float, map_y: float, extra_height: float = 0.0) -> Vector3:
	var position := to_3d(map_x, map_y, 0.0)
	position.y = _terrain_height_at_world(position.x, position.z) + extra_height
	return position


func _surface_exit_local_position(extra_height: float = 0.0) -> Vector3:
	return _surface_position(
		SURFACE_EXIT_MAP_POSITION.x,
		SURFACE_EXIT_MAP_POSITION.y,
		extra_height
	)


func _create_surface_landing_pad() -> void:
	# Окремий опуклий колайдер гарантує надійне приземлення після телепортації.
	# Він не залежить від трикутної колізії великої процедурної сітки.
	var surface_position := _surface_exit_local_position(0.0)
	var pad_height := 0.36
	var pad_top_offset := 0.08

	var pad_body := StaticBody3D.new()
	pad_body.name = "SurfaceExitLandingPad"
	pad_body.position = surface_position + Vector3(0.0, pad_top_offset - pad_height * 0.5, 0.0)
	pad_body.collision_layer = 1
	pad_body.collision_mask = 1

	var pad_shape := CylinderShape3D.new()
	pad_shape.radius = 8.0
	pad_shape.height = pad_height
	var pad_collision := CollisionShape3D.new()
	pad_collision.name = "LandingPadCollision"
	pad_collision.shape = pad_shape
	pad_body.add_child(pad_collision)

	var pad_mesh := MeshInstance3D.new()
	pad_mesh.name = "LandingPadStone"
	var stone_mesh := CylinderMesh.new()
	stone_mesh.top_radius = 7.8
	stone_mesh.bottom_radius = 8.2
	stone_mesh.height = pad_height
	stone_mesh.radial_segments = 16
	pad_mesh.mesh = stone_mesh
	pad_mesh.material_override = make_material("#34343a", 0.18, 0.88, "", 0.0, "tiles")
	pad_body.add_child(pad_mesh)

	var rune_ring := MeshInstance3D.new()
	rune_ring.name = "LandingPadRuneRing"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 6.65
	ring_mesh.outer_radius = 6.78
	rune_ring.mesh = ring_mesh
	rune_ring.position.y = pad_height * 0.5 + 0.025
	rune_ring.material_override = make_material("#7d6746", 0.5, 0.48, "#82643b", 0.45)
	pad_body.add_child(rune_ring)

	add_child(pad_body)


func to_3d(x2d: float, y2d: float, height: float = 0.0) -> Vector3:
	return Vector3(x2d * 1.5 * SCALE, height, y2d * 1.5 * SCALE)

func make_material(hex_color: String, metallic: float = 0.0, rough: float = 0.85, emit_hex: String = "", emit_power: float = 0.0, detail: String = "") -> Material:
	## PSX-матеріал: вершинне тремтіння + тайлова nearest-текстура (detail).
	## Без detail: метал -> "metal", яскраве світіння -> без текстури, інше -> "grime".
	var emission := Color(emit_hex) if emit_hex != "" else Color.BLACK
	var energy := emit_power if emit_hex != "" else 0.0
	if detail.is_empty():
		if energy > 0.5:
			detail = "none"
		elif metallic >= 0.5:
			detail = "metal"
		else:
			detail = "grime"
	return PSXMaterials.make(Color(hex_color), metallic, rough, emission, energy, detail)

func setup_environment():
	# Етап 2: власне небо з місяцем і хмарами, густий фіолетово-сірий туман,
	# об'ємний туман, у якому світяться факели. Цикл доби плавно змінює параметри.
	sky_material_ref = ShaderMaterial.new()
	sky_material_ref.shader = NIGHT_SKY_SHADER
	sky_material_ref.set_shader_parameter("moon_dir", MOON_DIRECTION)

	var sky := Sky.new()
	sky.sky_material = sky_material_ref
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_32

	world_environment = Environment.new()
	world_environment.background_mode = Environment.BG_SKY
	world_environment.sky = sky
	world_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	world_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.tonemap_exposure = 1.3
	world_environment.tonemap_white = 6.0
	world_environment.glow_enabled = true
	world_environment.glow_intensity = 0.85
	world_environment.glow_bloom = 0.04
	world_environment.glow_hdr_threshold = 0.85
	world_environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	# Глибинний туман + стелений туман у низинах.
	world_environment.fog_enabled = true
	# Туман глибини: починається на 22 м і густішає з відстанню — ближній план чистий,
	# а дальній (гора, вежі) тоне в серпанку, не зникаючи повністю.
	world_environment.fog_mode = Environment.FOG_MODE_DEPTH
	world_environment.fog_depth_begin = 22.0
	world_environment.fog_depth_end = 520.0
	world_environment.fog_depth_curve = 1.2
	world_environment.fog_light_energy = 1.0
	world_environment.fog_sun_scatter = 0.0
	world_environment.fog_aerial_perspective = 0.35
	world_environment.fog_sky_affect = 0.28
	world_environment.fog_height = 3.5
	world_environment.fog_height_density = 0.012

	# Об'ємний туман не підсвічується небом (інакше кадр «вигорає»),
	# його запалюють лише місяць, вікна, факели й магічні вогні.
	world_environment.volumetric_fog_enabled = true
	world_environment.volumetric_fog_density = 0.006
	world_environment.volumetric_fog_albedo = Color("#4d4a5e")
	world_environment.volumetric_fog_ambient_inject = 0.0
	world_environment.volumetric_fog_sky_affect = 0.0
	world_environment.volumetric_fog_length = 110.0
	world_environment.volumetric_fog_detail_spread = 2.0
	world_environment.volumetric_fog_anisotropy = 0.35

	world_environment.ssao_enabled = true
	world_environment.ssao_radius = 1.6
	world_environment.ssao_intensity = 1.8
	world_environment.ssao_power = 1.4
	world_environment.adjustment_enabled = true
	world_environment.adjustment_contrast = 1.08
	world_environment.adjustment_saturation = 0.9

	var world_env_node := WorldEnvironment.new()
	world_env_node.name = "DynamicWorldEnvironment"
	world_env_node.environment = world_environment
	add_child(world_env_node)

	sun_light = get_parent().get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if sun_light:
		sun_light.light_color = Color("#c5c9d4")
		sun_light.light_energy = 0.6
		sun_light.shadow_enabled = true
		sun_light.shadow_bias = 0.04
		sun_light.shadow_normal_bias = 1.2
		sun_light.light_volumetric_fog_energy = 0.25

	# Місяць — головне нічне світло: холодне, з тінями, світить з того ж боку,
	# де він висить на небі (над Горою на північному заході).
	moon_light = DirectionalLight3D.new()
	moon_light.name = "MoonDirectionalLight"
	moon_light.light_color = Color("#8ea2d8")
	moon_light.light_energy = 0.0
	moon_light.shadow_enabled = true
	moon_light.shadow_bias = 0.05
	moon_light.shadow_normal_bias = 1.4
	moon_light.directional_shadow_max_distance = 140.0
	moon_light.light_volumetric_fog_energy = 0.7
	moon_light.basis = Basis.looking_at(-MOON_DIRECTION.normalized(), Vector3.UP)
	# Батьківський вузол ще ініціалізує дітей — додаємо відкладено.
	get_parent().add_child.call_deferred(moon_light)

	var cam := get_parent().find_child("Camera3D", true, false) as Camera3D
	if cam:
		cam.far = 1500.0
		cam.fov = 72.0


func _smooth01(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _update_day_night_cycle(delta: float) -> void:
	if world_environment == null or sky_material_ref == null:
		return

	# Не прискорюємо час у головному меню, під час паузи або діалогів.
	if player_ref and is_instance_valid(player_ref) and bool(player_ref.get("controls_enabled")) and not player_in_dungeon:
		day_clock = fposmod(day_clock + delta / maxf(day_cycle_duration_seconds, 180.0), 1.0)

	# 10 Гц достатньо для повільного циклу; небо анімується саме (TIME у шейдері).
	day_night_update_timer += delta
	if day_night_initialized and day_night_update_timer < 0.10:
		return
	day_night_initialized = true
	day_night_update_timer = 0.0

	var angle := day_clock * TAU - PI * 0.5
	var sun_elevation := sin(angle)
	# День у Землях Попелу — лише похмурі сірі сутінки під важкими хмарами.
	var daylight := _smooth01((sun_elevation + 0.1) / 0.55)
	var night_amount := 1.0 - daylight
	night_amount_cached = night_amount
	var dusk_amount := (1.0 - _smooth01(absf(sun_elevation) / 0.6)) * 0.85

	if sun_light and is_instance_valid(sun_light):
		sun_light.rotation_degrees = Vector3(-90.0 + cos(angle) * 90.0, -38.0, 0.0)
		sun_light.light_color = Color("#e08a5c").lerp(Color("#b9c0cc"), daylight)
		sun_light.light_energy = daylight * 0.62 + dusk_amount * 0.18
		sun_light.shadow_enabled = sun_light.light_energy > 0.05
		if sun_elevation < -0.1:
			sun_light.light_energy = 0.0

	if moon_light and is_instance_valid(moon_light):
		moon_light.light_energy = 0.3 + night_amount * 0.65
		moon_light.shadow_enabled = night_amount > 0.3

	var zenith := Color("#070a16").lerp(Color("#3a4252"), daylight).lerp(Color("#1c1430"), dusk_amount * 0.55)
	var horizon := Color("#222840").lerp(Color("#6e727c"), daylight).lerp(Color("#6a3446"), dusk_amount)
	sky_material_ref.set_shader_parameter("zenith_color", zenith)
	sky_material_ref.set_shader_parameter("horizon_color", horizon)
	sky_material_ref.set_shader_parameter("ground_color", horizon.darkened(0.7))
	sky_material_ref.set_shader_parameter("moon_visibility", lerpf(1.0, 0.28, daylight))
	sky_material_ref.set_shader_parameter("star_intensity", night_amount * night_amount * (1.0 - dusk_amount * 0.6))
	sky_material_ref.set_shader_parameter("halo_color", Color("#6b75b0").lerp(Color("#9a8a9a"), dusk_amount * 0.5) * lerpf(1.0, 0.35, daylight))
	sky_material_ref.set_shader_parameter("cloud_color", Color("#1a1c2e").lerp(Color("#4a4d58"), daylight).lerp(Color("#3a1f2c"), dusk_amount * 0.7))
	sky_material_ref.set_shader_parameter("cloud_lit_color", Color("#7c86b4").lerp(Color("#c08a7a"), dusk_amount * 0.6))
	sky_material_ref.set_shader_parameter("cloud_coverage", lerpf(0.5, 0.68, daylight))
	sky_material_ref.set_shader_parameter("sky_energy", lerpf(1.0, 0.9, daylight))

	# Туман: холодний синій уночі, фіолетово-сірий у сутінки, сірий удень.
	var fog_color := Color("#2a3250").lerp(Color("#5a5d68"), daylight).lerp(Color("#4a3a5e"), dusk_amount * 0.75)
	world_environment.fog_light_color = fog_color
	# Помірна глибинна густина лишає силует Гори видимим; низини тоне у стеленому тумані.
	world_environment.fog_density = lerpf(0.72, 0.55, daylight)
	world_environment.volumetric_fog_albedo = fog_color.lightened(0.25)
	world_environment.volumetric_fog_emission = fog_color.darkened(0.55)
	world_environment.volumetric_fog_emission_energy = lerpf(0.5, 0.6, daylight)
	world_environment.ambient_light_color = Color("#46528a").lerp(Color("#7b818e"), daylight).lerp(Color("#5a3c55"), dusk_amount * 0.35)
	world_environment.ambient_light_energy = lerpf(1.1, 0.85, daylight)
	if finale_dawn > 0.0:
		_apply_finale_dawn()
	# Вода: відображення неба, блік місяця/сонця та яскравість залежать від часу доби.
	if not water_materials.is_empty():
		var sun_dir := MOON_DIRECTION
		if sun_light and is_instance_valid(sun_light):
			sun_dir = sun_light.global_transform.basis.z
		for water_mat in water_materials:
			WaterKit.update_material(water_mat, night_amount, sun_dir, MOON_DIRECTION.normalized())


func _apply_finale_dawn() -> void:
	## Небо плавно змінюється з темної ночі на золотий світанок: сонце підіймається над горою.
	var d := _smooth01(finale_dawn)
	var sun_dir := Vector3(-0.62, lerpf(0.02, 0.30, d), -0.77).normalized()
	var zenith := Color("#0c1230").lerp(Color("#5d86c8"), d)
	var horizon := Color("#5a3550").lerp(Color("#ffb877"), _smooth01(d * 1.4))
	sky_material_ref.set_shader_parameter("zenith_color", zenith)
	sky_material_ref.set_shader_parameter("horizon_color", horizon)
	sky_material_ref.set_shader_parameter("ground_color", horizon.darkened(0.55))
	sky_material_ref.set_shader_parameter("star_intensity", maxf(0.0, 1.0 - d * 2.2))
	sky_material_ref.set_shader_parameter("moon_visibility", (1.0 - d) * 0.5)
	sky_material_ref.set_shader_parameter("cloud_color", Color("#4a3a52").lerp(Color("#b98f86"), d))
	sky_material_ref.set_shader_parameter("cloud_lit_color", Color("#ffc795"))
	sky_material_ref.set_shader_parameter("cloud_coverage", lerpf(0.55, 0.42, d))
	sky_material_ref.set_shader_parameter("sun_dir", sun_dir)
	sky_material_ref.set_shader_parameter("sun_amount", _smooth01(d * 1.6))
	sky_material_ref.set_shader_parameter("sun_color", Color("#ffcf8f").lerp(Color("#fff0c8"), d))
	var fog_color := Color("#3a3558").lerp(Color("#e0b58f"), d)
	world_environment.fog_light_color = fog_color
	world_environment.fog_density = lerpf(0.6, 0.38, d)
	world_environment.volumetric_fog_albedo = fog_color.lightened(0.2)
	world_environment.ambient_light_color = Color("#5a5486").lerp(Color("#d2a98c"), d)
	world_environment.ambient_light_energy = lerpf(1.0, 1.35, d)
	if sun_light and is_instance_valid(sun_light):
		sun_light.basis = Basis.looking_at(-sun_dir, Vector3.UP)
		sun_light.light_color = Color("#ff9a5c").lerp(Color("#ffe0b0"), d)
		sun_light.light_energy = d * 1.7
		sun_light.shadow_enabled = d > 0.08
	if moon_light and is_instance_valid(moon_light):
		moon_light.light_energy = (1.0 - d) * 0.5
	_apply_world_renewal()


func _apply_world_renewal() -> void:
	## Другий етап фіналу: з золотого світанку — у ясний, барвистий ранок. Похмурий туман розходиться.
	if world_renew <= 0.0:
		return
	var r := _smooth01(world_renew)
	var d := _smooth01(finale_dawn)
	var sun_dir := Vector3(-0.62, lerpf(lerpf(0.02, 0.30, d), 0.55, r), -0.77).normalized()
	sky_material_ref.set_shader_parameter("zenith_color", Color("#5d86c8").lerp(Color("#3f8ae8"), r))
	sky_material_ref.set_shader_parameter("horizon_color", Color("#ffb877").lerp(Color("#ffe9c4"), r))
	sky_material_ref.set_shader_parameter("ground_color", Color("#a08a70").lerp(Color("#9ab88a"), r))
	sky_material_ref.set_shader_parameter("cloud_color", Color("#b98f86").lerp(Color("#f4f0ea"), r))
	sky_material_ref.set_shader_parameter("cloud_lit_color", Color("#ffc795").lerp(Color("#ffffff"), r))
	sky_material_ref.set_shader_parameter("cloud_coverage", lerpf(0.42, 0.3, r))
	sky_material_ref.set_shader_parameter("sun_dir", sun_dir)
	sky_material_ref.set_shader_parameter("sun_amount", 1.0)
	sky_material_ref.set_shader_parameter("star_intensity", 0.0)
	sky_material_ref.set_shader_parameter("moon_visibility", 0.0)
	var fog_color := Color("#e0b58f").lerp(Color("#cfe0f0"), r)
	world_environment.fog_light_color = fog_color
	world_environment.fog_density = lerpf(0.38, 0.06, r)
	world_environment.fog_depth_end = lerpf(520.0, 2400.0, r)
	world_environment.fog_height_density = lerpf(0.012, 0.0, r)
	world_environment.volumetric_fog_density = lerpf(0.006, 0.0004, r)
	world_environment.volumetric_fog_albedo = fog_color
	world_environment.ambient_light_color = Color("#d2a98c").lerp(Color("#d8e6d0"), r)
	world_environment.ambient_light_energy = lerpf(1.35, 1.7, r)
	world_environment.adjustment_saturation = lerpf(0.9, 1.3, r)
	world_environment.adjustment_contrast = lerpf(1.08, 1.12, r)
	world_environment.adjustment_brightness = lerpf(1.0, 1.08, r)
	if sun_light and is_instance_valid(sun_light):
		sun_light.basis = Basis.looking_at(-sun_dir, Vector3.UP)
		sun_light.light_color = Color("#ffe0b0").lerp(Color("#fff6e4"), r)
		sun_light.light_energy = lerpf(1.7, 2.3, r)
		sun_light.shadow_enabled = true
	if moon_light and is_instance_valid(moon_light):
		moon_light.light_energy = 0.0


func get_night_amount() -> float:
	return night_amount_cached


func get_surface_type(world_position: Vector3) -> String:
	## Тип поверхні під гравцем для звуку кроків.
	if player_in_dungeon:
		return "stone"
	var local := to_local(world_position)
	var point := Vector2(local.x, local.z)
	for bridge in bridge_positions:
		if Vector2(local.x - bridge.x, local.z - bridge.z).length() < 8.0 and local.y > bridge.y - 1.2:
			return "wood"
	if terrain_builder:
		var summit: Vector3 = terrain_builder.call("get_summit_position")
		if point.distance_to(Vector2(summit.x, summit.z)) < 46.0 and local.y > summit.y - 2.0:
			return "stone"
		if local.y > 105.0:
			return "snow"
		if float(terrain_builder.call("distance_to_river", point)) < 3.2 and local.y < 0.6:
			return "water"
		for building_position in building_nodes.values():
			var b: Node3D = building_position as Node3D
			if b and point.distance_to(Vector2(b.position.x, b.position.z)) < 5.0:
				return "stone"
		if float(terrain_builder.call("get_path_amount_at_world", point)) > 0.35:
			return "dirt"
	return "grass"


func get_day_phase_label() -> String:
	var hour_value := day_clock * 24.0
	var hour := int(floor(hour_value)) % 24
	var minute := int(floor((hour_value - floor(hour_value)) * 60.0))
	var phase := "ДЕНЬ"
	if hour < 5 or hour >= 21:
		phase = "НІЧ"
	elif hour < 7:
		phase = "СВІТАНОК"
	elif hour >= 18:
		phase = "СУТІНКИ"
	return "%02d:%02d  •  %s" % [hour, minute, phase]

func make_ground_shader_material() -> ShaderMaterial:
	var ground_shader = Shader.new()
	ground_shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

float hash_value(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise_value(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash_value(i);
	float b = hash_value(i + vec2(1.0, 0.0));
	float c = hash_value(i + vec2(0.0, 1.0));
	float d = hash_value(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 p = UV * vec2(180.0, 125.0);
	float broad = noise_value(p * 0.28);
	float fine = noise_value(p * 2.6);
	vec3 dark_soil = vec3(0.045, 0.055, 0.043);
	vec3 moss_soil = vec3(0.105, 0.125, 0.078);
	vec3 ground = mix(dark_soil, moss_soil, smoothstep(0.18, 0.84, broad));
	ground += (fine - 0.5) * 0.028;
	ALBEDO = ground;
	ROUGHNESS = 0.96;
}
"""
	var material = ShaderMaterial.new()
	material.shader = ground_shader
	return material

func build_solid_ground() -> void:
	# Сумісний псевдонім для старих викликів; тепер тут не PlaneMesh, а рельєф.
	if terrain_builder == null:
		_create_terrain_system()


func build_biomes():
	# Біоми тепер фарбують сам рельєф (відтінок + іній у вершинних кольорах).
	pass

func _create_terrain_following_biome_patch(biome: Dictionary) -> void:
	## Створює напівпрозору кольорову зону, вершини якої лягають на той самий heightmap.
	var center_map := Vector2(float(biome["x"]), float(biome["y"]))
	var center_world := Vector2(center_map.x * 1.5 * SCALE, center_map.y * 1.5 * SCALE)
	var radius: float = float(biome["r"]) * 1.5 * SCALE
	var elevation: float = float(biome.get("h", 0.08))
	var segment_count: int = 48
	var ring_count: int = 4

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	# Центральна вершина.
	var center_height: float = _terrain_height_at_world(center_world.x, center_world.y) + elevation
	vertices.append(Vector3(0.0, center_height, 0.0))
	normals.append(_terrain_normal_at(center_world.x, center_world.y))
	uvs.append(Vector2(0.5, 0.5))

	# Чотири кільця вершин плавно повторюють схил від центру до краю.
	for ring in range(1, ring_count + 1):
		var ring_factor: float = float(ring) / float(ring_count)
		for segment in range(segment_count):
			var angle: float = TAU * float(segment) / float(segment_count)
			var offset := Vector2(cos(angle), sin(angle)) * radius * ring_factor
			var sample_x: float = center_world.x + offset.x
			var sample_z: float = center_world.y + offset.y
			var sample_height: float = _terrain_height_at_world(sample_x, sample_z) + elevation
			vertices.append(Vector3(offset.x, sample_height, offset.y))
			normals.append(_terrain_normal_at(sample_x, sample_z))
			uvs.append(Vector2(0.5 + offset.x / (radius * 2.0), 0.5 + offset.y / (radius * 2.0)))

	# Віяло від центру та смуги між кільцями. Порядок індексів спрямований угору.
	for segment in range(segment_count):
		var next_segment: int = (segment + 1) % segment_count
		indices.append(0)
		indices.append(1 + next_segment)
		indices.append(1 + segment)

	for ring in range(1, ring_count):
		var inner_start: int = 1 + (ring - 1) * segment_count
		var outer_start: int = 1 + ring * segment_count
		for segment in range(segment_count):
			var next_segment: int = (segment + 1) % segment_count
			var a: int = inner_start + segment
			var b: int = inner_start + next_segment
			var c: int = outer_start + segment
			var d: int = outer_start + next_segment
			indices.append(a)
			indices.append(b)
			indices.append(c)
			indices.append(c)
			indices.append(b)
			indices.append(d)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var patch_mesh := ArrayMesh.new()
	patch_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var patch_material := StandardMaterial3D.new()
	var tint := Color(str(biome["col"]))
	tint.a = 0.32
	patch_material.albedo_color = tint
	patch_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	patch_material.roughness = 0.98
	patch_mesh.surface_set_material(0, patch_material)

	var patch := MeshInstance3D.new()
	patch.name = "Biome_%s" % str(biome["col"]).trim_prefix("#")
	patch.mesh = patch_mesh
	patch.position = Vector3(center_world.x, 0.0, center_world.y)
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(patch)


func _terrain_normal_at(world_x: float, world_z: float) -> Vector3:
	## Оцінює нормаль з перепаду висоти; використовується декоративними патчами біомів.
	var sample_step: float = 0.45
	var slope_x: float = (_terrain_height_at_world(world_x + sample_step, world_z) - _terrain_height_at_world(world_x - sample_step, world_z)) / (sample_step * 2.0)
	var slope_z: float = (_terrain_height_at_world(world_x, world_z + sample_step) - _terrain_height_at_world(world_x, world_z - sample_step)) / (sample_step * 2.0)
	return Vector3(-slope_x, 1.0, -slope_z).normalized()

func build_roads():
	# Дороги тепер «намальовані» у шейдері рельєфу (утоптана земля з камінцями)
	# і м'яко лягають на пагорби. Тут лишаються лише 3D-точки для карти й логіки.
	routes_3d.clear()
	for route in base_routes:
		var pts_3d = []
		for pt in route:
			pts_3d.append(_surface_position(pt.x, pt.y, 0.0))
		routes_3d.append(pts_3d)

func build_rivers_and_bridges():
	var river_pts = [
		Vector2(3300, 0), Vector2(3060, 400), Vector2(2850, 760), Vector2(2650, 1120),
		Vector2(2410, 1440), Vector2(2180, 1760), Vector2(1900, 2100), Vector2(1640, 2600)
	]
	# Вода: одна стрічка вздовж русла (течія, брижі, піна біля берегів) замість стику плоских коробок.
	var river_mat := WaterKit.make_material(0.0)
	water_materials.append(river_mat)
	var water_pts: Array = []
	for rp in river_pts:
		var wp: Vector3 = _surface_position(rp.x, rp.y, 0.0)
		wp.y = _terrain_height_at_world(wp.x, wp.z) + 0.26
		water_pts.append(wp)
	WaterKit.build_ribbon(self, "RiverWater", water_pts, 11.0, river_mat)
	for i in range(river_pts.size() - 1):
		var mid_2d = (river_pts[i] + river_pts[i + 1]) / 2.0
		forbidden_zones.append({"pos": to_3d(mid_2d.x, mid_2d.y), "radius": 12.0})

	# Арковані дерев'яні мости впоперек русла (вісь — перпендикуляр до течії).
	var bridges = [Vector2(2690, 1060), Vector2(2200, 1740), Vector2(3064, 430)]
	for br in bridges:
		var center := _surface_position(br.x, br.y, 0.0)
		var flow := Vector2(0.0, 1.0)
		var best_dist := INF
		for i in range(river_pts.size() - 1):
			var a: Vector2 = river_pts[i]
			var b: Vector2 = river_pts[i + 1]
			var closest := Geometry2D.get_closest_point_to_segment(br, a, b)
			if br.distance_to(closest) < best_dist:
				best_dist = br.distance_to(closest)
				flow = (b - a).normalized()
		var axis := Vector3(flow.y, 0.0, -flow.x)
		var span := 17.0
		var end_a := center - axis * span * 0.5
		var end_b := center + axis * span * 0.5
		var ga := _terrain_height_at_world(end_a.x, end_a.z)
		var gb := _terrain_height_at_world(end_b.x, end_b.z)
		var bridge := LandmarkKit.build_arched_bridge(span, 4.8, 1.9, ga, gb)
		bridge.position = Vector3(center.x, 0.0, center.z)
		bridge.rotation.y = atan2(axis.x, axis.z)
		add_child(bridge)
		bridge_positions.append(Vector3(center.x, center.y + 1.0, center.z))

func build_barad_dur_mountain():
	## Чорна Гора — сам пік вбудовано в рельєф (TerrainBuilder), тут — руїни
	## «Попелястої Корони» на вершині та кам'яні віхи на серпантині.
	if terrain_builder == null:
		return
	var summit: Vector3 = terrain_builder.call("get_summit_position")
	var center := Vector3(summit.x, 0.0, summit.z)
	forbidden_zones.append({"pos": center, "radius": float(terrain_builder.call("get_mountain_radius")) * 0.5})
	var arena_offset := Vector3(ARENA_DIR.x, 0.0, ARENA_DIR.y) * ARENA_DISTANCE
	var ruins := BuildingKit.build_summit_ruins(1337, arena_offset, ARENA_RADIUS + 3.0)
	ruins.position = summit
	add_child(ruins)
	_build_boss_arena(summit)
	var crown = ruins.get_meta("crown_light", null)
	if crown is OmniLight3D:
		eye_light = crown
	# Віхи-ліхтарі вздовж серпантину: видно, куди йти вночі.
	var path: PackedVector3Array = terrain_builder.get("mountain_path")
	var kit := MeshKit.new()
	var step := 18
	for index in range(step, path.size() - 2, step):
		var p := path[index]
		var next := path[mini(index + 1, path.size() - 1)]
		var dir := Vector3(next.x - p.x, 0, next.z - p.z).normalized()
		var outward := Vector3(p.x - summit.x, 0, p.z - summit.z).normalized()
		var post := p + outward * 3.6
		post.y = _terrain_height_at_world(post.x, post.z)
		kit.box_at("stone", post + Vector3(0, 0.7, 0), Vector3(0.7, 1.4, 0.7))
		kit.pyramid("stone", Transform3D(Basis(), post + Vector3(0, 1.4, 0)), 0.8, 0.8, 0.5)
		kit.box_at("ember", post + Vector3(0, 1.2, 0) - outward * 0.36, Vector3(0.3, 0.3, 0.06), false, Vector3(0, atan2(dir.x, dir.z), 0))
		var light := FlickerLight.create(Color("#ff7a36"), 1.1, 8.0, 0.25, 4.0)
		light.position = post + Vector3(0, 1.6, 0) - outward * 0.8
		light.fade_begin = 70.0
		add_child(light)
	for key in kit._tools.keys():
		kit.set_material(key, BuildingKit.mat(key))
	kit.build(self, "MountainPathCairns", 400.0)

# --- Арена фінального бою на вершині ---------------------------------------------------------
## Арена — у пролом мурів Корони, з боку світанку; Вівтар Ока збоку від центру, щоб лишити місце для бою.
const ARENA_DIR := Vector2(-0.259, -0.966)
const ARENA_DISTANCE: float = 26.0
const ARENA_RADIUS: float = 18.0


func get_arena_center_local() -> Vector3:
	if terrain_builder == null:
		return Vector3.ZERO
	var summit: Vector3 = terrain_builder.call("get_summit_position")
	var p := summit + Vector3(ARENA_DIR.x, 0.0, ARENA_DIR.y) * ARENA_DISTANCE
	p.y = _terrain_height_at_world(p.x, p.z)
	return p


func get_arena_altar_local() -> Vector3:
	var c := get_arena_center_local()
	var side := Vector3(-ARENA_DIR.y, 0.0, ARENA_DIR.x)
	var p := c + side * 10.5
	p.y = _terrain_height_at_world(p.x, p.z)
	return p


func get_finale_viewpoint() -> Dictionary:
	## Оглядова точка фіналу: край плато за ареною; герой дивиться на світанок, руїни Корони — позаду.
	var c := get_arena_center_local()
	var p := c + Vector3(ARENA_DIR.x, 0.0, ARENA_DIR.y) * 15.0
	p.y = _terrain_height_at_world(p.x, p.z)
	return {"position": to_global(p), "facing": Vector3(-0.62, 0.0, -0.77).normalized()}


func _build_boss_arena(summit: Vector3) -> void:
	var c := get_arena_center_local()
	var kit := MeshKit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4096
	var altar := get_arena_altar_local()
	# Кільце зламаних колон (укриття для ухилянь) з проходом до руїн і до вівтаря.
	for i in range(18):
		var a := TAU * float(i) / 18.0
		var p := c + Vector3(cos(a), 0.0, sin(a)) * (ARENA_RADIUS + 1.5)
		if Vector2(p.x - altar.x, p.z - altar.z).length() < 10.0:
			continue
		if Vector2(p.x - summit.x, p.z - summit.z).length() < 15.0:
			continue
		if i % 3 == 1:
			continue
		p.y = _terrain_height_at_world(p.x, p.z)
		var h := rng.randf_range(2.5, 6.5)
		kit.box_at("stone_dark", p + Vector3(0, h * 0.5 - 0.6, 0), Vector3(1.4, h + 1.2, 1.4), true, Vector3(0, -a, 0))
		kit.box_at("stone", p + Vector3(0, h + 0.05, 0), Vector3(1.8, 0.35, 1.8), false, Vector3(0, -a, 0))
		if i % 2 == 0:
			kit.rock("stone_dark", Transform3D(Basis(Vector3.UP, a), p + Vector3(cos(a) * 1.4, 0, sin(a) * 1.4)), Vector3(1.1, 0.7, 0.9), rng)
	# Рунічне коло на землі (плоскі світні плити) — межа арени видно навіть уночі.
	for i in range(36):
		var a := TAU * float(i) / 36.0
		var p := c + Vector3(cos(a), 0.0, sin(a)) * (ARENA_RADIUS - 1.0)
		p.y = _terrain_height_at_world(p.x, p.z) + 0.03
		kit.box_at("ember" if i % 3 == 0 else "stone_dark", p, Vector3(1.6, 0.06, 0.5), false, Vector3(0, -a + PI * 0.5, 0))
	for i in range(12):
		var a := TAU * float(i) / 12.0 + 0.13
		var p := c + Vector3(cos(a), 0.0, sin(a)) * 6.0
		p.y = _terrain_height_at_world(p.x, p.z) + 0.03
		kit.box_at("ember", p, Vector3(0.9, 0.05, 0.25), false, Vector3(0, -a, 0))
	for key_name in kit._tools.keys():
		kit.set_material(key_name, BuildingKit.mat(key_name))
	kit.build(self, "BossArena", 500.0)
	# Чотири жаровні по краю арени.
	for i in range(4):
		var a := TAU * float(i) / 4.0 + PI * 0.25
		var p := c + Vector3(cos(a), 0.0, sin(a)) * (ARENA_RADIUS - 3.5)
		if Vector2(p.x - altar.x, p.z - altar.z).length() < 9.0:
			p = c + Vector3(cos(a), 0.0, sin(a)) * (ARENA_RADIUS - 0.5)
		p.y = _terrain_height_at_world(p.x, p.z)
		var bkit := MeshKit.new()
		bkit.cylinder_at("iron", p, 0.35, 0.75, 1.3, 6, true)
		bkit.box_at("ember", p + Vector3(0, 1.32, 0), Vector3(0.9, 0.16, 0.9))
		for key_name in bkit._tools.keys():
			bkit.set_material(key_name, BuildingKit.mat(key_name))
		bkit.build(self, "ArenaBrazier_%d" % i, 400.0)
		var fire := FlickerLight.create(Color("#ff6a2a"), 2.4, 15.0, 0.35, 8.0)
		fire.position = p + Vector3(0, 2.0, 0)
		fire.fade_begin = 160.0
		add_child(fire)


func build_main_castle():
	## Королівська фортеця: вежі з конічними дахами, куртини із зубцями,
	## надбрамні вежі з аркою та гратами, донжон. Брама дивиться на південь (+Z).
	var pos = _surface_position(2930, 545, 0.0)
	forbidden_zones.append({"pos": pos, "radius": 48.0})
	var fortress := BuildingKit.build_fortress(Color("#2c2a30"), 2930, 2.5)
	fortress.position = pos
	fortress.rotation.y = PI
	add_child(fortress)

func get_nearest_road_point(pos: Vector3) -> Vector3:
	# Дороги шукаються в площині XZ: висота пагорба не повинна спотворювати відстань.
	var query := Vector2(pos.x, pos.z)
	var best_pt := Vector3(pos.x, _terrain_height_at_world(pos.x, pos.z), pos.z)
	var best_dist: float = INF
	for route in routes_3d:
		for i in range(route.size() - 1):
			var a: Vector3 = route[i]
			var b: Vector3 = route[i + 1]
			var a2 := Vector2(a.x, a.z)
			var ab := Vector2(b.x - a.x, b.z - a.z)
			var len_sq: float = ab.length_squared()
			var t: float = 0.0
			if len_sq > 0.001:
				t = clampf((query - a2).dot(ab) / len_sq, 0.0, 1.0)
			var projected := a2 + ab * t
			var distance: float = query.distance_to(projected)
			if distance < best_dist:
				best_dist = distance
				best_pt = Vector3(projected.x, _terrain_height_at_world(projected.x, projected.y), projected.y)
	return best_pt

func is_near_road(pos: Vector3, min_dist: float) -> bool:
	var road_point := get_nearest_road_point(pos)
	return Vector2(pos.x, pos.z).distance_to(Vector2(road_point.x, road_point.z)) < min_dist

func _build_black_banner_citadel(b: Dictionary) -> void:
	## Фортеця Чорного Прапора стоїть на острові посеред озера (рельєф формує TerrainBuilder),
	## брама дивиться на північний захід до дороги; до брами веде арковий дерев'яний міст.
	var center := to_3d(float(b["x"]), float(b["y"]), 0.0)
	var level := float(terrain_builder.get("lake_level")) if terrain_builder else 0.0
	center.y = level
	var toward_road := Vector2(2810.0 - float(b["x"]), 900.0 - float(b["y"])).normalized()
	# Локальний -Z фортеці дивиться в бік дороги (брама), -Z повернутий на yaw збігається з forward.
	var forward := Vector3(toward_road.x, 0.0, toward_road.y)
	var yaw := atan2(-forward.x, -forward.z)
	var fort := LandmarkKit.build_waterfort(hash(str(b["name"])))
	fort.position = center
	fort.rotation.y = yaw
	add_child(fort)
	building_nodes[str(b["name"])] = fort
	building_depths[str(b["name"])] = 50.0
	forbidden_zones.append({"pos": center, "radius": 100.0})
	# Озеро: диск води під рівнем острова; течія — повільний вихор.
	var lake_mat := WaterKit.make_material(1.0, 1.2, false)
	water_materials.append(lake_mat)
	WaterKit.build_disc(self, "BlackBannerLake", center + Vector3(0.0, -0.5, 0.0), 80.0, lake_mat)
	# Міст від брами (локальний z = -40) до берега (z = -77).
	var dir := forward
	var a_pos := center + dir * 39.5
	var b_pos := center + dir * 77.0
	var ground_a := 0.0
	var ground_b := _terrain_height_at_world(b_pos.x, b_pos.z) - level
	var mid := (a_pos + b_pos) * 0.5
	var bridge := LandmarkKit.build_arched_bridge(a_pos.distance_to(b_pos), 5.2, 2.3, ground_a, ground_b)
	bridge.name = "BlackBannerBridge"
	bridge.position = Vector3(mid.x, level, mid.z)
	bridge.rotation.y = atan2(dir.x, dir.z)
	add_child(bridge)
	bridge_positions.append(Vector3(mid.x, level + 1.0, mid.z))


func prepare_buildings():
	for b in buildings_data:
		if str(b.get("kind", "")) == "waterfort":
			_build_black_banner_citadel(b)
			continue
		var raw_pos = to_3d(b["x"], b["y"], 0)
		raw_pos.y = _terrain_height_at_world(raw_pos.x, raw_pos.z)
		var road_pt = get_nearest_road_point(raw_pos)
		var bw = clamp(b["w"] * 1.5 * SCALE * 0.55, 8.0, 16.0)
		var bd = clamp(b["h"] * 1.5 * SCALE * 0.55, 7.0, 14.0)
		var safe_offset = max(bw, bd) * 0.7 + 4.5
		
		var final_pos = raw_pos
		if raw_pos.distance_to(road_pt) < safe_offset:
			var dir_away = (raw_pos - road_pt)
			dir_away.y = 0
			if dir_away.length() < 0.1:
				dir_away = Vector3(1, 0, 0)
			final_pos = road_pt + dir_away.normalized() * safe_offset
			
		final_pos.y = _terrain_height_at_world(final_pos.x, final_pos.z)
		forbidden_zones.append({"pos": final_pos, "radius": max(bw, bd) + 5.5})
		
		var house_node = create_detailed_building(b["name"], b["kind"], bw, bd, b["col"], final_pos, road_pt)
		building_nodes[b["name"]] = house_node
		building_depths[b["name"]] = bd
		add_child(house_node)


# -----------------------------------------------------------------------------
# PART 3 — NPCs, BUILDING INTERACTIONS AND A FACTION QUEST
# -----------------------------------------------------------------------------
func _building_front_position(building_name: String, front_offset: float = 3.2, side_offset: float = 0.0) -> Vector3:
	var building: Node3D = building_nodes.get(building_name) as Node3D
	if building == null:
		return Vector3.ZERO
	var depth: float = float(building_depths.get(building_name, 8.0))
	var facing: Basis = building.transform.basis.orthonormalized()
	# Повертаємо координати локально відносно WorldGenerator: NPC та маркери
	# будуть дітьми того самого вузла. Глобальні координати створюються окремо.
	return building.position + facing * Vector3(side_offset, 0.0, -(depth * 0.5 + front_offset))


func _register_world_interaction(interaction_id: String, display_name: String, world_position: Vector3, radius: float = 5.4, hint: String = "E — ВЗАЄМОДІЯ") -> void:
	world_interactions.append({
		"id": interaction_id,
		"name": display_name,
		"position": to_global(world_position),
		"radius": radius,
		"hint": hint
	})


func _add_npc_piece(parent: Node3D, piece_name: String, mesh: Mesh, local_position: Vector3, material: Material, local_rotation: Vector3 = Vector3.ZERO, local_scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.name = piece_name
	piece.mesh = mesh
	piece.position = local_position
	piece.rotation = local_rotation
	piece.scale = local_scale
	piece.material_override = material
	parent.add_child(piece)
	return piece


func _create_world_npc(interaction_id: String, npc_name: String, role: String, world_position: Vector3, robe_color: String, accent_color: String, style: String, facing_y: float = 0.0) -> StaticBody3D:
	var npc := StaticBody3D.new()
	npc.name = interaction_id
	npc.position = world_position
	npc.rotation.y = facing_y
	npc.collision_layer = 1
	npc.collision_mask = 1
	add_child(npc)

	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.78
	collider.shape = capsule
	collider.position = Vector3(0.0, 0.88, 0.0)
	npc.add_child(collider)

	# Повноцінне тіло з окремих частин + обличчя PS1 та жести під час розмови.
	HumanoidKit.build(npc, HumanoidKit.spec_for_npc(style, robe_color, accent_color), interaction_id)
	_add_nameplate(npc, Vector3(0.0, 2.35, 0.0), npc_name, role, Color("#f0dfbf"), 18.0)

	_register_world_interaction(interaction_id, npc_name, world_position, 5.7, "E  —  ГОВОРИТИ: %s" % npc_name.to_upper())
	return npc

func _add_nameplate(parent: Node3D, local_position: Vector3, title: String, subtitle: String, color: Color, max_range: float) -> Marker3D:
	## Точка для чіткого екранного підпису (scripts/ui/nameplates.gd).
	var marker := Marker3D.new()
	marker.name = "Nameplate"
	marker.position = local_position
	marker.set_meta("title", title)
	marker.set_meta("subtitle", subtitle)
	marker.set_meta("color", color)
	marker.set_meta("range", max_range)
	marker.add_to_group("nameplate")
	parent.add_child(marker)
	return marker


func _spawn_npc_at_building(interaction_id: String, npc_name: String, role: String, building_name: String, robe_color: String, accent_color: String, style: String, side_offset: float = 2.6) -> void:
	var position := _building_front_position(building_name, 3.8, side_offset)
	if position == Vector3.ZERO:
		push_warning("NPC %s: не знайдено будівлю %s." % [npc_name, building_name])
		return
	var building: Node3D = building_nodes.get(building_name) as Node3D
	var facing_y: float = building.rotation.y if building else 0.0
	_create_world_npc(interaction_id, npc_name, role, position, robe_color, accent_color, style, facing_y)


func _create_quest_marker(marker_name: String, marker_position: Vector3, color_hex: String, label_text: String) -> Node3D:
	var root := Node3D.new()
	root.name = marker_name
	root.position = marker_position
	root.visible = false
	add_child(root)

	var pedestal := MeshInstance3D.new()
	var pedestal_mesh := CylinderMesh.new()
	pedestal_mesh.top_radius = 0.58
	pedestal_mesh.bottom_radius = 0.78
	pedestal_mesh.height = 0.42
	pedestal.mesh = pedestal_mesh
	pedestal.position = Vector3(0.0, 0.22, 0.0)
	pedestal.material_override = make_material("#393632", 0.2, 0.72)
	root.add_child(pedestal)

	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.52
	ring_mesh.outer_radius = 0.64
	ring.mesh = ring_mesh
	ring.rotation.x = deg_to_rad(90.0)
	ring.position = Vector3(0.0, 1.18, 0.0)
	ring.material_override = make_material(color_hex, 0.2, 0.25, color_hex, 3.0)
	root.add_child(ring)

	var crystal := MeshInstance3D.new()
	var crystal_mesh := SphereMesh.new()
	crystal_mesh.radius = 0.28
	crystal_mesh.height = 0.62
	crystal.mesh = crystal_mesh
	crystal.position = Vector3(0.0, 1.22, 0.0)
	crystal.material_override = make_material(color_hex, 0.15, 0.18, color_hex, 4.0)
	root.add_child(crystal)

	_add_nameplate(root, Vector3(0.0, 2.0, 0.0), label_text, "", Color(color_hex), 14.0)

	var light := OmniLight3D.new()
	light.light_color = Color(color_hex)
	light.light_energy = 1.3
	light.omni_range = 7.5
	light.position = Vector3(0.0, 1.5, 0.0)
	light.shadow_enabled = false
	root.add_child(light)
	return root


func build_world_npcs_and_interactions() -> void:
	world_interactions.clear()

	_spawn_npc_at_building("npc_hunter", "Рун Слідопит", "Мисливець прикордоння", "Хатина мисливця", "#4b4937", "#9b8050", "hunter")
	_spawn_npc_at_building("npc_mage", "Магістр Вальмер", "Маг-алхімік", "Хатина відьми", "#302944", "#9c72d4", "mage")
	_spawn_npc_at_building("npc_elder", "Мирон", "Староста Села Попелу", "Село Попелу", "#51402b", "#b18d58", "elder")
	_spawn_npc_at_building("npc_scholar", "Ренн", "Хранитель Обсерваторії", "Зруйнована Обсерваторія", "#3b4651", "#83a8c0", "scholar")
	_spawn_npc_at_building("npc_priest", "Сестра Аліна", "Остання служителька", "Руїни Абатства", "#364b45", "#b4c6a2", "priest")
	_spawn_npc_at_building("npc_blacksmith", "Каталан", "Коваль-майстер", "Кузня Каталана", "#514039", "#bd713d", "blacksmith")
	_spawn_npc_at_building("npc_druid", "Велес", "Сторож Кола друїдів", "Коло друїдів", "#304437", "#8eb76d", "druid")
	_spawn_npc_at_building("npc_acolyte", "Варк", "Послушник Чорної Гори", "Фортеця Чорного Прапора", "#382a2a", "#c04437", "mage")

	# Нові мешканці: торговець, капітан варти, вдова та фермер із власними дорученнями.
	_spawn_npc_at_building("npc_merchant", "Бруно", "Мандрівний торговець", "Табір вигнанців", "#5a4630", "#c8a050", "merchant", -3.4)
	_spawn_npc_at_building("npc_marta", "Марта", "Вдова з Села Попелу", "Село Попелу", "#4a3a46", "#a08a9a", "woman", 7.0)
	_spawn_npc_at_building("npc_farmer", "Йоган", "Фермер", "Село Попелу", "#5a5238", "#8a7a4a", "farmer", -6.5)
	_spawn_npc_at_building("npc_captain", "Гедвіг", "Капітан варти", "Попеляста цитадель", "#3b3a3c", "#c29a58", "captain", 3.0)
	# Розширення карти: чародійка-лучниця (продає лук) і мешканці східних та південних поселень.
	_spawn_npc_at_building("npc_archer", "Ліра", "Чародійка-лучниця", "Вежа Місячної Лучниці", "#22424a", "#7fd0c0", "archer", 2.4)
	_spawn_npc_at_building("npc_miner", "Грім", "Бригадир копалень", "Селище Соляних Копалень", "#4b4038", "#9a7a50", "blacksmith", -2.2)
	_spawn_npc_at_building("npc_herder", "Оля", "Пастушка Зольного Броду", "Зольний Брід", "#5a4a3a", "#a89070", "woman", 1.5)
	_spawn_npc_at_building("npc_hermit", "Ярин", "Відлюдник", "Хатина відлюдника", "#3a4538", "#8aa070", "druid", 4.4)
	_spawn_npc_at_building("npc_border", "Ратмир", "Командир застави", "Східна сторожова застава", "#3d3c38", "#b08a4a", "guard", 3.0)
	_spawn_npc_at_building("npc_nun", "Мар'яна", "Сестра Сірого Монастиря", "Монастир Сірих Сестер", "#3d4a42", "#b4c6a2", "priest", 2.8)
	_spawn_npc_at_building("npc_farmhand", "Тарас", "Фермер", "Хутір Сухих Борозен", "#5a5238", "#8a7a4a", "farmer", 1.0)
	_spawn_side_quest_items()

	# Кастелян і вартовий стоять перед окремою королівською фортецею.
	var castle_center := _surface_position(2930.0, 545.0, 0.0)
	_create_world_npc("npc_castellan", "Едрик", "Кастелян Попелястої варти", castle_center + Vector3(-5.0, 0.0, 24.0), "#3d3b39", "#c29a58", "guard", PI)
	_create_world_npc("npc_castle_guard", "Севран", "Вартовий брами", castle_center + Vector3(6.0, 0.0, 24.0), "#42434a", "#9e9b8e", "guard", PI)

	# Додаткові входи/місця, з якими можна взаємодіяти клавішею E.
	_register_building_interaction("Забуте кладовище", "building_crypt", "E  —  ОГЛЯНУТИ СТАРІ НАПИСИ")
	_register_building_interaction("Брама велетнів", "building_gate", "E  —  ДОСЛІДИТИ ДАВНЮ БРАМУ")
	_register_building_interaction("Попеляста цитадель", "building_citadel", "E  —  ОГЛЯНУТИ ЗНАКИ ЦИТАДЕЛІ")
	_register_building_interaction("Лігво Прадавнього Дракона", "building_dragon_lair", "E  —  ПРИСЛУХАТИСЯ ДО ЛІГВА")
	_register_building_interaction("Крижана вежа", "building_ice_tower", "E  —  ДОСЛІДИТИ КРИЖАНУ ВЕЖУ")

	# Дві сюжетні знахідки. Активується лише та, що відповідає обраній присязі.
	var observatory_position := _building_front_position("Зруйнована Обсерваторія", 6.0, -1.8)
	var black_banner_position := _building_front_position("Фортеця Чорного Прапора", 6.0, 1.8)
	principality_marker = _create_quest_marker("RoyalAstralEvidence", observatory_position, "#d6a44e", "ПЕЧАТКА ЗОРІ")
	mountain_marker = _create_quest_marker("EyeEchoEvidence", black_banner_position, "#d74b3f", "ВІДЛУННЯ ОКА")

	_build_stage4_content()
	_build_frontier_content()
	_build_main_story()
	_build_bonfire()


# -----------------------------------------------------------------------------
# ЕТАП 4 — ліхтарник Орест, предмети, записки з лором і зони локацій
# -----------------------------------------------------------------------------
func _building_local_point(building_name: String, local_offset: Vector3) -> Vector3:
	var building: Node3D = building_nodes.get(building_name) as Node3D
	if building == null:
		return Vector3.ZERO
	var point := building.transform * local_offset
	point.y = _terrain_height_at_world(point.x, point.z)
	return point


func _build_stage4_content() -> void:
	# Ліхтарник Орест стоїть біля дороги поруч із місцем виходу з Казематів.
	var orest_position := _surface_position(1752.0, 2168.0, 0.0)
	var spawn_position := _surface_exit_local_position(0.0)
	var facing := atan2(spawn_position.x - orest_position.x, spawn_position.z - orest_position.z) + PI
	_create_world_npc("npc_lamplighter", "Орест", "Ліхтарник придорожніх вогнів", orest_position, "#3e3a33", "#d89a48", "elder", facing)
	var kit := MeshKit.new()
	var post := orest_position + Vector3(1.4, 0.0, 0.6)
	kit.origin = Transform3D(Basis(Vector3.UP, facing), post)
	kit.box_at("wood", Vector3(0, 1.4, 0), Vector3(0.18, 2.8, 0.18))
	kit.box_at("wood", Vector3(0.35, 2.7, 0), Vector3(0.8, 0.12, 0.12))
	kit.box_at("window", Vector3(0.65, 2.35, 0), Vector3(0.26, 0.34, 0.26))
	kit.pyramid("iron", Transform3D(Basis(), Vector3(0.65, 2.52, 0)), 0.36, 0.36, 0.2)
	_barrel_with_kit(kit, Vector3(-0.8, 0, 0.5))
	for key in kit._tools.keys():
		kit.set_material(key, BuildingKit.mat(key))
	kit.build(self, "OrestLanternPost", 200.0)
	var orest_light := FlickerLight.create(Color("#ffa24a"), 1.6, 10.0, 0.18, 4.0)
	orest_light.position = kit.origin * Vector3(0.65, 2.2, 0)
	add_child(orest_light)

	# Фляга олії між могилами Забутого кладовища (квест «Погаслі ліхтарі»).
	var oil_position := _building_local_point("Забуте кладовище", Vector3(-6.3, 0.0, 3.4))
	if oil_position != Vector3.ZERO:
		var oil := Interactable.spawn(self, oil_position, "item_lamp_oil", Interactable.Kind.ITEM, "Фляга олії", "ПІДНЯТИ ФЛЯГУ ОЛІЇ", Color("#ffb060"))
		oil.item_id = "lamp_oil"
		oil.item_name = "Фляга ліхтарної олії"

	# Записки зі світобудовою.
	var summit: Vector3 = terrain_builder.call("get_summit_position") if terrain_builder else Vector3.ZERO
	_spawn_note(summit + Vector3(2.6, 0.0, -10.5), "note_kings_last_words", "Послання короля",
		"ОСТАННЄ ПОСЛАННЯ КОРОЛЯ",
		"Тому, хто прийде після мене.\n\nЯ не втік. Я підняв Корону на вершину, бо внизу її хотіли розколоти на три мечі. Вогонь у ній — не прокляття, а клятва: поки він горить, Око не відкриється повністю.\n\nЯкщо вінець згасне, спускайся до Казематів і шукай Камінь Присяги. Обери, кому служити. Але пам'ятай: Корона не належить ні князям, ні Горі.\n\n— Едмар, останній із Попелястих")
	_spawn_note(_building_local_point("Село Попелу", Vector3(2.4, 0.0, -5.0)), "note_widow_letter", "Лист удови",
		"ЛИСТ, ЗАЛИШЕНИЙ БІЛЯ КРИНИЦІ",
		"Арне, ти обіцяв повернутися до першого снігу. Сніг випав тричі.\n\nСтароста каже, що лицарів забрали під камінь, а ліхтарник щоночі запалює вогні вздовж дороги, щоб ви знайшли шлях додому. Я теж залишаю свічку на вікні.\n\nЯкщо ти читаєш це — не йди на вершину сам.")
	_spawn_note(_building_local_point("Табір вигнанців", Vector3(1.8, 0.0, 0.2)), "note_exile_orders", "Наказ вигнанцям",
		"НАКАЗ, ПРИБИТИЙ ДО ЯЩИКА",
		"Хто ще тримає меч — стерегти дорогу до порталу Казематів.\n\nПопеляні вартові ходять колом між могилами й не перетинають світло ліхтарів. Не гасіть вогні. Не відповідайте, коли вас кличуть на ім'я з боку кладовища.\n\nТой, хто піде на гору без олії для віх, назад не повернеться.")

	# Зони локацій: «Відкрито місце» + цілі «дістатися».
	for building_name in building_nodes.keys():
		var building: Node3D = building_nodes[building_name]
		LocationTrigger.create(self, building.position + Vector3(0, 2.0, 0), "loc_" + str(hash(building_name)), str(building_name), 26.0)
	if terrain_builder:
		var foot: Vector3 = terrain_builder.call("get_mountain_path_start")
		LocationTrigger.create(self, foot + Vector3(0, 2.0, 0), "mountain_foot", "Підніжжя Чорної Гори", 20.0)
		LocationTrigger.create(self, summit + Vector3(0, 2.0, 0), "summit_crown", "Руїни Попелястої Корони", 24.0)
	var castle_center := _surface_position(2930.0, 545.0, 0.0)
	LocationTrigger.create(self, castle_center + Vector3(0, 2.0, 0), "loc_royal_castle", "Королівська фортеця", 40.0)


func _polyline_point(points: Array, fraction: float) -> Vector3:
	var total := 0.0
	for i in range(points.size() - 1):
		total += (points[i + 1] - points[i]).length()
	var target := total * clampf(fraction, 0.0, 1.0)
	for i in range(points.size() - 1):
		var seg: Vector3 = points[i + 1] - points[i]
		if target <= seg.length():
			return points[i] + seg.normalized() * target
		target -= seg.length()
	return points[points.size() - 1]


func _build_road_monsters() -> void:
	## Дорога до Попелястої Корони (Чорна Гора): групи вартових збоку від дороги, засідки на серпантині
	## й сильніші воїни ближче до вершини. Лише ashen_wraith-типи: сюжетні цілі (боси) не зачіпаються.
	var road: Array = routes_3d[1] if routes_3d.size() > 1 else []
	if road.size() < 2:
		return
	# 1) Рівнина: групи стоять на узбіччі (±8 м), дорога лишається вільною.
	var plain := [[0.22, 2, 1.0], [0.42, 3, 1.0], [0.62, 3, 1.1], [0.82, 4, 1.1]]
	var side := 1.0
	for group in plain:
		var p: Vector3 = _polyline_point(road, float(group[0]))
		var ahead: Vector3 = _polyline_point(road, minf(float(group[0]) + 0.02, 1.0))
		var dir := Vector3(ahead.x - p.x, 0.0, ahead.z - p.z).normalized()
		var perp := Vector3(-dir.z, 0.0, dir.x) * side
		var center := p + perp * 9.0
		center.y = _terrain_height_at_world(center.x, center.z)
		_spawn_road_group(center, int(group[1]), 3.0, float(group[2]), "Мародер тракту", 22.0)
		side = -side
	# 2) Серпантин: засідки по обидва боки поступово посилюються.
	var path: PackedVector3Array = terrain_builder.get("mountain_path") if terrain_builder else PackedVector3Array()
	if path.size() < 20:
		return
	var summit: Vector3 = terrain_builder.call("get_summit_position")
	var stops := [[0.08, 2, 1.0, 120.0], [0.22, 3, 1.05, 130.0], [0.36, 3, 1.1, 150.0], [0.5, 3, 1.15, 170.0], [0.64, 4, 1.2, 190.0], [0.78, 4, 1.25, 210.0]]
	for stop in stops:
		var idx := clampi(int(float(path.size() - 1) * float(stop[0])), 1, path.size() - 2)
		var p := path[idx]
		var inward := Vector3(summit.x - p.x, 0.0, summit.z - p.z).normalized()
		var center := p + inward * 3.0
		center.y = _terrain_height_at_world(center.x, center.z)
		_spawn_road_group(center, int(stop[1]), 2.2, float(stop[2]), "Страж серпантину", float(stop[3]))
	# 3) Сильні воїни ближче до замку (вище по схилу) — окремі, з більшим запасом здоров'я.
	for strong in [[0.58, 1.35, 260.0], [0.74, 1.45, 320.0], [0.9, 1.55, 400.0]]:
		var idx2 := clampi(int(float(path.size() - 1) * float(strong[0])), 1, path.size() - 2)
		var sp := path[idx2]
		var sin_dir := Vector3(summit.x - sp.x, 0.0, summit.z - sp.z).normalized()
		var spot := sp + sin_dir * 4.0
		spot.y = _terrain_height_at_world(spot.x, spot.z)
		_spawn_special_wraith(spot, {"enemy_type": "ashen_wraith", "display_name": "ПОПЕЛЯСТИЙ ВОЇН", "max_health": float(strong[2]), "attack_damage": 26.0, "move_speed": 2.7, "detection_range": 34.0, "scale": float(strong[1])})


func _spawn_road_group(center: Vector3, count: int, radius: float, scale_value: float, label: String, health: float) -> void:
	for i in range(count):
		var a := TAU * float(i) / float(maxi(count, 1)) + 0.4
		var point := center + Vector3(cos(a), 0.0, sin(a)) * radius
		point.y = _terrain_height_at_world(point.x, point.z)
		_spawn_special_wraith(point, {"enemy_type": "ashen_wraith", "display_name": label, "max_health": maxf(health * 0.5, 60.0), "detection_range": 24.0, "scale": scale_value})


func _build_frontier_content() -> void:
	## Східні й південні землі: охоронці руїн, вартові склепу, записки з лором.
	var guards := [
		["Руїни Вартової Фортеці", Vector3(0.0, 0.0, -9.0), "tower_guardian", "ВАРТОВИЙ РУЇН", 1.3, 230.0],
		["Склеп Забутих Королів", Vector3(-4.0, 0.0, -9.0), "tower_guardian", "СТОРОЖ СКЛЕПУ", 1.3, 260.0],
		["Склеп Забутих Королів", Vector3(7.0, 0.0, -7.0), "ashen_wraith", "Попелястий вартовий", 1.0, 60.0],
		["Південна Брама", Vector3(-5.0, 0.0, -8.0), "ashen_wraith", "Попелястий вартовий", 1.0, 60.0],
		["Південна Брама", Vector3(6.0, 0.0, -9.0), "ashen_wraith", "Попелястий вартовий", 1.0, 60.0],
		["Руїни Вартової Фортеці", Vector3(8.0, 0.0, -5.0), "ashen_wraith", "Попелястий вартовий", 1.0, 60.0],
		["Монастир Сірих Сестер", Vector3(0.0, 0.0, -14.0), "ashen_wraith", "Тінь монастиря", 1.0, 60.0],
	]
	for guard in guards:
		var point := _building_local_point(str(guard[0]), guard[1])
		if point == Vector3.ZERO:
			continue
		_spawn_special_wraith(point, {"enemy_type": str(guard[2]), "display_name": str(guard[3]), "scale": float(guard[4]), "max_health": float(guard[5])})
	_spawn_note(_building_local_point("Склеп Забутих Королів", Vector3(-5.5, 0.0, 3.0)), "note_kings_crypt", "Плита королів",
		"ПЛИТА У СКЛЕПІ ЗАБУТИХ КОРОЛІВ",
		"Тут лежать ті, хто тримав корону до Едмара. Їхні імена стерті не часом, а долотом: кожен наступний король стирав попередніх.\n\nЛише один напис вціліл: «Око не вмирає. Воно змінює господаря».")
	_spawn_note(_building_local_point("Руїни Вартової Фортеці", Vector3(5.0, 0.0, 2.0)), "note_watch_fortress", "Журнал вартового",
		"ЖУРНАЛ ВАРТОВОГО ФОРТЕЦІ",
		"День 41. Вогні на заході гаснуть по одному.\nДень 42. Командир наказав стріляти по всьому, що йде з боку гори. Стріли відскакують.\nДень 43. Лише тятива з жили дракона бере їх. Надішлемо гінця до вежі на заході.")
	_spawn_note(_building_local_point("Монастир Сірих Сестер", Vector3(3.2, 0.0, -4.0)), "note_grey_sisters", "Лист сестер",
		"ЛИСТ СЕСТЕР СІРОГО МОНАСТИРЯ",
		"Сестро Аліно, ми залишаємо тобі ключ від північної брами. Дорога до Села Попелу безпечна лише вдень. Якщо побачиш на тракті вартового без обличчя — не відповідай йому, а запали свічку.")
	_build_dead_beacon_world()
	_build_road_monsters()


# -----------------------------------------------------------------------------
# МІСІЯ «ЗГАСЛИЙ МАЯК»: світові події, предмети, засідки та маркери цілей
# -----------------------------------------------------------------------------
const MISSION_MARKERS: Array = [
	"npc_archer", "npc_herder", "mission_ambush", "mission_crypt", "mission_crypt", "mission_shards", "mission_sarcophagus",
	"mission_boss", "npc_miner", "mission_hamlet", "npc_archer", "mission_beacon", "mission_beacon_boss", "npc_border",
]
var _mission_handled: Dictionary = {}
var _mission_sarcophagus: Interactable = null
var _mission_beacon_item: Interactable = null
var _mission_beacon_anchor: Node3D = null


func _event_toast(title: String, body: String, seconds: float = 5.0) -> void:
	var host := get_parent()
	if host and host.has_method("_show_story_toast"):
		host.call("_show_story_toast", title, body, seconds)


func _ground_local(map_x: float, map_y: float) -> Vector3:
	return _surface_position(map_x, map_y, 0.0)


func _spawn_wave(center: Vector3, count: int, spread: float, label: String = "Попелястий вартовий") -> void:
	for i in range(count):
		var angle := TAU * float(i) / float(maxi(count, 1)) + 0.7
		var point := center + Vector3(cos(angle) * spread, 0.0, sin(angle) * spread)
		point.y = _terrain_height_at_world(point.x, point.z)
		_spawn_special_wraith(point, {"enemy_type": "ashen_wraith", "display_name": label, "detection_range": 34.0})


func _build_dead_beacon_world() -> void:
	story_positions["mission_ambush"] = _ground_local(4350.0, 2850.0)
	var crypt := _building_local_point("Склеп Забутих Королів", Vector3.ZERO)
	var hamlet := _building_local_point("Зольний Брід", Vector3.ZERO)
	var ruins := _building_local_point("Руїни Вартової Фортеці", Vector3.ZERO)
	if crypt == Vector3.ZERO or ruins == Vector3.ZERO:
		return
	story_positions["mission_crypt"] = crypt
	story_positions["mission_shards"] = crypt
	story_positions["mission_boss"] = crypt
	story_positions["mission_hamlet"] = hamlet
	LocationTrigger.create(self, crypt + Vector3(0, 2.0, 0), "mission_crypt", "Склеп Забутих Королів", 34.0)
	# Королівський саркофаг біля входу в склеп.
	var sarcophagus_pos := _building_front_position("Склеп Забутих Королів", 5.5, 0.0)
	sarcophagus_pos.y = _terrain_height_at_world(sarcophagus_pos.x, sarcophagus_pos.z)
	_mission_sarcophagus = Interactable.spawn(self, sarcophagus_pos, "mission_sarcophagus", Interactable.Kind.INSPECT, "Королівський саркофаг", "ОГЛЯНУТИ САРКОФАГ", Color("#9ab8ff"))
	_mission_sarcophagus.radius = 3.4
	story_positions["mission_sarcophagus"] = sarcophagus_pos
	_mission_sarcophagus.note_text = "Кришка вкрита інеєм і королівськими печатками. Усередині щось тихо дзвенить, як лід."
	var smesh := MeshKit.new()
	smesh.box_at("stone_dark", Vector3(0, 0.5, 0), Vector3(2.3, 1.0, 1.1), true)
	smesh.box_at("stone", Vector3(0, 1.08, 0), Vector3(2.5, 0.2, 1.3))
	smesh.box_at("window_blue", Vector3(0, 1.22, 0), Vector3(0.9, 0.06, 0.4))
	for key_name in smesh._tools.keys():
		smesh.set_material(key_name, BuildingKit.mat(key_name))
	smesh.build(_mission_sarcophagus, "SarcophagusMesh", 150.0)
	# Мертва чаша маяка у Вартовій Фортеці.
	var beacon_pos := _building_front_position("Руїни Вартової Фортеці", 6.5, 0.0)
	beacon_pos.y = _terrain_height_at_world(beacon_pos.x, beacon_pos.z)
	story_positions["mission_beacon"] = beacon_pos
	story_positions["mission_beacon_boss"] = beacon_pos
	_mission_beacon_item = Interactable.spawn(self, beacon_pos, "mission_beacon", Interactable.Kind.INSPECT, "Чаша маяка", "ЗАПАЛИТИ МАЯК", Color("#ffcf7a"))
	_mission_beacon_item.radius = 3.6
	_mission_beacon_item.note_text = "Чаша маяка холодна. Лінза всередині розтрощена, а попіл — свіжий. Без Місячного каменю тут нічого не запалити."
	var bmesh := MeshKit.new()
	bmesh.box_at("stone", Vector3(0, 0.9, 0), Vector3(1.6, 1.8, 1.6), true)
	bmesh.cylinder_at("iron", Vector3(0, 2.0, 0), 1.2, 0.9, 0.5, 8, true)
	bmesh.cylinder_at("cave_dark", Vector3(0, 2.26, 0), 0.8, 0.8, 0.05, 8)
	for key_name in bmesh._tools.keys():
		bmesh.set_material(key_name, BuildingKit.mat(key_name))
	bmesh.build(_mission_beacon_item, "BeaconBowlMesh", 220.0)
	if not QuestManager.quest_progressed.is_connected(_on_mission_progress):
		QuestManager.quest_progressed.connect(_on_mission_progress)


func _on_mission_progress(quest_id: String, _text: String, progress: int, _total: int) -> void:
	if quest_id != "dead_beacon":
		return
	# Часткові зарахування цілей (n/m) надсилають той самий номер кроку: подія має спрацювати один раз.
	if _mission_handled.has(progress):
		return
	_mission_handled[progress] = true
	var crypt: Vector3 = story_positions.get("mission_crypt", Vector3.ZERO)
	match progress:
		1:
			_event_toast("ЛІРА", "«Лінза тріснула зсередини — її розбив хтось із Попелястих. Запитай Олю в Зольному Броді: вона бачила тих, хто йшов тим трактом.»", 6.0)
		2:
			# Засідка на південному тракті.
			var ambush: Vector3 = story_positions.get("mission_ambush", Vector3.ZERO)
			_event_toast("ЗАСІДКА", "На тракті між Зольним Бродом і Копальнями ворушаться тіні. Попелянські вартові чекають на тебе.", 5.0)
			_spawn_wave(ambush, 3, 6.0, "Вартовий із засідки")
		3:
			# Подія дорогою: загиблий дозорний із записками та одинокий вартовий на тракті.
			var note_at := _ground_local(5050.0, 3620.0)
			_spawn_note(note_at, "note_dead_scout", "Журнал дозорного",
				"ЖУРНАЛ ЗАГИБЛОГО ДОЗОРНОГО",
				"День третій. Ми дійшли до склепу. Саркофаг короля сам відкривається вночі — всередині не мертвий, а світло. Командир наказав взяти камінь. Ліхтар гасне. Коли чуєш кроки без тіней — не оглядайся.")
			_spawn_special_wraith(_ground_local(5000.0, 3700.0), {"enemy_type": "ashen_wraith", "display_name": "Вартовий тракту", "detection_range": 34.0})
			_event_toast("ТРАКТ ДО СКЛЕПУ", "Біля дороги лежить дозорний із застави. Хтось залишив при ньому записник.", 5.0)
		4:
			_event_toast("СКЛЕП ПРОКИДАЄТЬСЯ", "Кам'яні двері грюкнули. З темряви виходять королівські вартові.", 5.0)
			_spawn_wave(crypt, 2, 9.0, "Королівський вартовий")
		5:
			_event_toast("УЛАМКИ МІСЯЧНОГО СКЛА", "Тріснуте місячне скло розсипане навколо склепу. Збери три уламки: вони холодно мерехтять.", 6.0)
			var offsets := [Vector3(-9.0, 0.0, 6.0), Vector3(1.0, 0.0, 13.0), Vector3(11.0, 0.0, -1.0)]
			for i in range(offsets.size()):
				var shard_pos := _building_local_point("Склеп Забутих Королів", offsets[i])
				if shard_pos == Vector3.ZERO:
					continue
				var shard := Interactable.spawn(self, shard_pos, "item_moon_shard_%d" % i, Interactable.Kind.ITEM, "Уламок місячного скла", "ПІДНЯТИ УЛАМОК", Color("#9ab8ff"))
				shard.item_id = "moon_shard"
				shard.item_name = "Уламок місячного скла"
		6:
			if _mission_sarcophagus:
				_mission_sarcophagus.note_text = "Уламки скла самі лягають у пази кришки. Печатки тріскають, віко повільно зсувається…"
		7:
			# Відкрився саркофаг: з'являється Хранитель Каменю.
			_event_toast("ХРАНИТЕЛЬ", "Із саркофага піднімається тінь у короні. Він не віддасть камінь без бою.", 5.5)
			var boss_pos := _building_front_position("Склеп Забутих Королів", 11.0, 0.0)
			boss_pos.y = _terrain_height_at_world(boss_pos.x, boss_pos.z)
			story_nodes["mission_boss"] = _spawn_special_wraith(boss_pos, {
				"enemy_type": "tower_guardian", "display_name": "ХРАНИТЕЛЬ МІСЯЧНОГО КАМЕНЮ",
				"max_health": 380.0, "attack_damage": 26.0, "move_speed": 2.7, "detection_range": 50.0, "scale": 1.45,
			})
		8:
			QuestManager.add_item("moon_stone", "Місячний камінь")
			if _mission_sarcophagus:
				_mission_sarcophagus.note_text = "Саркофаг порожній. Королівський вінець розсипався на попіл."
			_event_toast("МІСЯЧНИЙ КАМІНЬ", "Камінь холодний, як вода зі студні. Грім із Копалень знає, як його очистити — шлях на північ.", 6.0)
		9:
			var hamlet: Vector3 = story_positions.get("mission_hamlet", Vector3.ZERO)
			_event_toast("ЗОЛЬНИЙ БРІД ГОРИТЬ", "Над селищем піднявся дим. Вартові напали на хати — поспішай на допомогу!", 6.0)
			_spawn_wave(hamlet, 3, 12.0, "Нападник на брід")
		10:
			_event_toast("ПОВЕРНЕННЯ ДО ЛІРИ", "Брід врятовано. Камінь у тебе — Ліра чекає у вежі, на захід від застави.", 5.0)
		11:
			if _mission_beacon_item:
				_mission_beacon_item.note_text = "Ти вкладаєш Місячний камінь у розтрощену лінзу. Скло гуде, чаша наповнюється білим світлом…"
			_event_toast("МАЯК", "Ліра вставила камінь у нову лінзу. Піднімайся до Вартової Фортеці й запали вогонь.", 5.0)
		12:
			# Маяк спалахує: з'являється Вартовий Маяка та його підкріплення.
			var bp: Vector3 = story_positions.get("mission_beacon", Vector3.ZERO)
			if bp != Vector3.ZERO:
				_mission_beacon_anchor = Node3D.new()
				_mission_beacon_anchor.name = "LitBeacon"
				_mission_beacon_anchor.position = bp + Vector3(0, 2.1, 0)
				add_child(_mission_beacon_anchor)
				_add_beacon(_mission_beacon_anchor, Color("#ffd27a"))
				_event_toast("МАЯК СПАЛАХНУВ", "Біле полум'я здіймається над руїнами. З тіней виходить Вартовий Маяка — він не дасть вогню горіти.", 6.0)
				_spawn_wave(bp, 2, 11.0, "Тінь маяка")
				var guard_pos := bp + Vector3(0.0, 0.0, 12.0)
				guard_pos.y = _terrain_height_at_world(guard_pos.x, guard_pos.z)
				story_nodes["mission_beacon_boss"] = _spawn_special_wraith(guard_pos, {
					"enemy_type": "tower_guardian", "display_name": "ВАРТОВИЙ МАЯКА",
					"max_health": 460.0, "attack_damage": 30.0, "move_speed": 3.0, "detection_range": 55.0, "scale": 1.5,
				})
		13:
			_event_toast("МАЯК ГОРИТЬ", "Вартовий упав, а вогонь не гасне. Поверніся до Ратмира на східну заставу.", 6.0)


func _mission_marker_local() -> Vector3:
	var state := QuestManager.get_quest_state("dead_beacon")
	if state != "active" and state != "ready":
		return Vector3.ZERO
	var step := 13 if state == "ready" else clampi(QuestManager.get_step("dead_beacon"), 0, 13)
	var key := str(MISSION_MARKERS[step])
	if key.begins_with("npc_"):
		for item in world_interactions:
			if str(item.get("id", "")) == key:
				return to_local(item.get("position", Vector3.ZERO))
	var node := story_nodes.get(key) as Node3D
	if node and is_instance_valid(node) and node.is_inside_tree() and not bool(node.get("dead")):
		return to_local(node.global_position)
	return story_positions.get(key, Vector3.ZERO)


func _spawn_special_wraith(local_position: Vector3, props: Dictionary) -> CharacterBody3D:
	var target := get_parent().get_node_or_null("Player") as CharacterBody3D
	var wraith := WRAITH_SCENE.instantiate() as CharacterBody3D
	if wraith == null or target == null:
		return null
	for key in props.keys():
		if str(key) == "scale":
			wraith.scale = Vector3.ONE * float(props[key])
		else:
			wraith.set(str(key), props[key])
	add_child(wraith)
	wraith.position = local_position + Vector3(0.0, 0.1, 0.0)
	wraith.call("set_target", target)
	combat_enemies.append(wraith)
	return wraith


func _add_beacon(node: Node3D, color: Color) -> void:
	## Високий світний стовп і сильне світло — ціль видно здалеку.
	var beam := MeshInstance3D.new()
	beam.name = "Beacon"
	beam.mesh = BoxMesh.new()
	(beam.mesh as BoxMesh).size = Vector3(0.14, 16.0, 0.14)
	beam.position = Vector3(0.0, 8.0, 0.0)
	beam.material_override = PSXMaterials.make(color, 0.0, 0.5, color, 4.0, "none", false)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(beam)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.4
	light.omni_range = 24.0
	light.position = Vector3(0.0, 2.5, 0.0)
	node.add_child(light)


func _build_main_story() -> void:
	## Об'єкти головного сюжету: тригери локацій, маяки, Вівтар Ока на вершині. Міні-боси
	## з'являються, коли до них доходить черга (див. _on_story_progress).
	var locations := {
		"story_cemetery": ["Забуте кладовище", "Забуте Кладовище", Color("#9ad6a0")],
		"story_abbey": ["Руїни Абатства", "Руїни Абатства", Color("#9ab8ff")],
		"story_citadel": ["Попеляста цитадель", "Попеляста Цитадель", Color("#ffb060")],
	}
	for story_id in locations.keys():
		var info: Array = locations[story_id]
		var point := _building_local_point(str(info[0]), Vector3.ZERO)
		if point == Vector3.ZERO:
			continue
		story_positions[story_id] = point
		LocationTrigger.create(self, point + Vector3(0.0, 2.0, 0.0), story_id, str(info[1]), 30.0)
		var beacon_anchor := Node3D.new()
		beacon_anchor.name = "Beacon_" + story_id
		beacon_anchor.position = point + Vector3(0.0, 1.0, 0.0)
		beacon_anchor.visible = false
		add_child(beacon_anchor)
		_add_beacon(beacon_anchor, info[2])
		story_nodes["beacon_" + story_id] = beacon_anchor
	story_positions["ash_knight"] = _building_front_position("Забуте кладовище", 6.0, 0.0)
	story_positions["necromancer"] = _building_front_position("Руїни Абатства", 6.0, 0.0)
	story_positions["citadel_guardian"] = _building_front_position("Попеляста цитадель", 8.0, -6.0)

	if terrain_builder:
		var summit_local: Vector3 = terrain_builder.call("get_summit_position")
		story_positions["summit_crown"] = summit_local
		var altar_pos := get_arena_altar_local()
		story_positions["story_altar"] = altar_pos
		story_positions["eye_guardian"] = altar_pos
		var altar := Interactable.spawn(self, altar_pos, "story_altar", Interactable.Kind.INSPECT, "Вівтар Ока", "З'ЄДНАТИ УЛАМКИ ПЕЧАТКИ", Color("#ff5a2a"))
		altar.radius = 4.0
		altar.note_text = "Ти вкладаєш три уламки Стародавньої Печатки в різьблений камінь. Вони зростаються, і Вівтар спалахує червоним: гора здригається — із попелу піднімається Страж Ока."
		# Вівтар Ока: навмисно левітує — плита з Оком висить над рунічним постаментом.
		altar.add_child(LandmarkKit.build_eye_altar())
		story_nodes["altar_interactable"] = altar
		_add_beacon(altar, Color("#ff5a2a"))

	if not QuestManager.quest_progressed.is_connected(_on_story_progress):
		QuestManager.quest_progressed.connect(_on_story_progress)
	if not QuestManager.map_piece_added.is_connected(_on_piece_added):
		QuestManager.map_piece_added.connect(_on_piece_added)
	_refresh_atlas_goal()


func _on_story_progress(quest_id: String, _text: String, progress: int, _total: int) -> void:
	if quest_id != "main_story":
		return
	# Шматки Атласу тепер дають міні-боси й випробування; поки їх не зібрано, шлях до гори невідомий.
	_refresh_atlas_goal()
	_try_reveal_map()
	# Контрольні точки: після смерті не повертаємося до початку гри.
	var cp := {2: "story_cemetery", 3: "story_cemetery", 5: "story_abbey", 6: "story_abbey", 8: "story_citadel"}
	if cp.has(progress):
		set_checkpoint(story_positions.get(str(cp[progress]), Vector3.ZERO) + Vector3(5.0, 0.0, 6.0), "Контрольна точка: " + str(cp[progress]).trim_prefix("story_"))
	# Маяки показують поточну локацію сюжету.
	var beacon_by_step := {2: "story_cemetery", 3: "story_cemetery", 5: "story_abbey", 6: "story_abbey", 8: "story_citadel"}
	for story_id in ["story_cemetery", "story_abbey", "story_citadel"]:
		var beacon := story_nodes.get("beacon_" + story_id) as Node3D
		if beacon:
			beacon.visible = str(beacon_by_step.get(progress, "")) == story_id
	var bosses := {
		3: {"id": "ash_knight", "name": "ЛИЦАР ПОПЕЛУ", "hp": 380.0, "dmg": 24.0, "speed": 2.9, "range": 34.0, "scale": 1.3},
		6: {"id": "necromancer", "name": "НЕКРОМАНТ РУЇН", "hp": 320.0, "dmg": 20.0, "speed": 2.5, "range": 34.0, "scale": 1.15},
		8: {"id": "citadel_guardian", "name": "ВАРТОВИЙ ЦИТАДЕЛІ", "hp": 560.0, "dmg": 30.0, "speed": 2.3, "range": 34.0, "scale": 1.45},
		11: {"id": "eye_guardian", "name": "СТРАЖ ОКА", "hp": 1300.0, "dmg": 34.0, "speed": 3.3, "range": 55.0, "scale": 1.7},
	}
	# Страж упав — фінальна фаза: дійти до Вівтаря та вирвати Око (кінцівка лише після цього).
	if progress == 12 and eye_finale:
		eye_finale.arm()
	if progress == 11:
		set_checkpoint(get_arena_center_local() + Vector3(0, 0, 14.0), "Контрольна точка: арена Ока")
	if not bosses.has(progress):
		return
	var boss: Dictionary = bosses[progress]
	var boss_id := str(boss["id"])
	var spawn_at: Vector3 = story_positions.get(boss_id, Vector3.ZERO)
	if boss_id == "eye_guardian":
		spawn_at = get_arena_center_local() + Vector3(0.0, 0.6, 0.0)
	if spawn_at == Vector3.ZERO:
		return
	story_nodes[boss_id] = _spawn_special_wraith(spawn_at, {
		"enemy_type": boss_id, "display_name": str(boss["name"]),
		"max_health": float(boss["hp"]), "attack_damage": float(boss["dmg"]),
		"move_speed": float(boss["speed"]), "detection_range": float(boss["range"]),
		"scale": float(boss["scale"])
	})
	if boss_id == "eye_guardian" and story_nodes[boss_id]:
		var brain := EyeBossBrain.new()
		brain.name = "EyeBossBrain"
		story_nodes[boss_id].add_child(brain)
		brain.setup(story_nodes[boss_id], self)
		story_nodes[boss_id].set("_brain", brain)


func _eye_map_position() -> Vector2:
	if terrain_builder == null:
		return Vector2(-1000.0, -1000.0)
	var s: Vector3 = terrain_builder.call("get_summit_position")
	return Vector2(s.x, s.z)


var _map_scene_started: bool = false
var _atlas_pending: Array[String] = []


func _grant_atlas_piece(piece_id: String) -> void:
	## Шматок приходить за кілька секунд після кроку сюжету, щоб не перекрити тост головної цілі.
	if QuestManager.has_map_piece(piece_id) or piece_id in _atlas_pending:
		return
	_atlas_pending.append(piece_id)
	await get_tree().create_timer(3.4).timeout
	_atlas_pending.erase(piece_id)
	QuestManager.add_map_piece(piece_id)


var checkpoint_local: Vector3 = Vector3.ZERO
var checkpoint_label: String = ""


func set_checkpoint(local_pos: Vector3, label: String) -> void:
	if local_pos == Vector3.ZERO:
		return
	checkpoint_local = local_pos
	checkpoint_label = label


func _on_piece_added(_id: String, _count: int, _total: int) -> void:
	_refresh_atlas_goal()
	_try_reveal_map()


func _refresh_atlas_goal() -> void:
	var missing: Array = []
	for id in AtlasPieces.GATE:
		if not QuestManager.has_map_piece(str(id)):
			missing.append(AtlasPieces.piece_name(str(id)))
	var text := "Зійди серпантином на вершину Чорної Гори (північний захід)"
	if not missing.is_empty() and not eye_map_known:
		text = "Шлях до гори невідомий: Атлас Корони неповний (%d/8). Не вистачає: %s. Шукай їх у випробуваннях і в міні-босів" % [QuestManager.get_map_piece_count(), ", ".join(missing)]
	QuestManager.set_objective_text("main_story", 9, text)


func _try_reveal_map() -> void:
	if eye_map_known or _map_scene_started:
		return
	if QuestManager.get_step("main_story") >= 9 and QuestManager.atlas_gate_open():
		reveal_eye_map_scene()


func reveal_eye_map_scene() -> void:
	## Усі три уламки Печатки зібрано: з них проступає останній шматок Атласу — Чорна Гора.
	## Герой складає карту повністю, і лише тоді вперше видно місце Ока й шлях до нього.
	if _map_scene_started or eye_map_known:
		return
	_map_scene_started = true
	await get_tree().create_timer(2.8).timeout
	var host := get_parent()
	if host and host.get("extras") and host.extras.map_scene:
		host.extras.map_scene.play(func() -> void:
			eye_map_known = true
			QuestManager.quest_log_changed.emit()
		)
	else:
		QuestManager.add_map_piece(AtlasPieces.FINAL)
		QuestManager.mark_map_piece_seen(AtlasPieces.FINAL)
		eye_map_known = true


func get_story_target_local() -> Vector3:
	# Випробування «Розділу II»: мітка веде до каменя випробування, а під час нього — до цілі етапу.
	if trials:
		var tracked_id := str(QuestManager.get_tracked_summary().get("id", ""))
		var tm: Vector3 = trials.marker_for(tracked_id)
		if tm != Vector3.ZERO:
			return tm
	# Побічне доручення «Кістяна Вдова»: логово, а далі сама відьма.
	if str(QuestManager.get_tracked_summary().get("id", "")) == "bone_widow" and QuestManager.get_quest_state("bone_widow") == "active":
		var widow := QuestManager.get_target_id("bone_widow")
		var wnode: Node3D = encounters.witch as Node3D if encounters else null
		if widow == "skeleton_witch" and wnode and is_instance_valid(wnode) and not bool(wnode.get("dead")):
			return to_local(wnode.global_position)
		return story_positions.get("mission_swamp", Vector3.ZERO)
	if not eye_map_known and str(QuestManager.get_tracked_summary().get("id", "")) != "dead_beacon" \
			and QuestManager.get_target_id("main_story") in ["summit_crown", "story_altar", "eye_guardian"]:
		return Vector3.ZERO
	## Локальна позиція поточної цілі: відстежувана місія «Згаслий Маяк» або головний сюжет (Vector3.ZERO — немає).
	if str(QuestManager.get_tracked_summary().get("id", "")) == "dead_beacon":
		var mission_target := _mission_marker_local()
		if mission_target != Vector3.ZERO:
			return mission_target
	if QuestManager.get_quest_state("main_story") != "active":
		return Vector3.ZERO
	var target_id := QuestManager.get_target_id("main_story")
	if target_id.begins_with("npc_"):
		for item in world_interactions:
			if str(item.get("id", "")) == target_id:
				return to_local(item.get("position", Vector3.ZERO))
	var node := story_nodes.get(target_id) as Node3D
	if node and is_instance_valid(node) and node.is_inside_tree() and not bool(node.get("dead")):
		return to_local(node.global_position)
	return story_positions.get(target_id, Vector3.ZERO)

func _build_bonfire() -> void:
	## Вогнище біля Села Попелу: місце відродження після смерті та відпочинку.
	var p := _building_front_position("Село Попелу", 9.0, -1.5)
	if p == Vector3.ZERO:
		return
	p.y = _terrain_height_at_world(p.x, p.z)
	bonfire_local = p
	var kit := MeshKit.new()
	kit.origin = Transform3D(Basis(), p)
	for i in range(8):
		var a := TAU * float(i) / 8.0
		kit.box_at("stone_dark", Vector3(cos(a) * 0.95, 0.16, sin(a) * 0.95), Vector3(0.42, 0.32, 0.34), false)
	kit.box_at("wood", Vector3(0.0, 0.2, 0.0), Vector3(1.3, 0.2, 0.2))
	kit.box_at("wood", Vector3(0.0, 0.34, 0.0), Vector3(0.2, 0.2, 1.3))
	kit.pyramid("ember", Transform3D(Basis(), Vector3(0.0, 0.4, 0.0)), 0.55, 0.55, 1.0)
	for key_name in kit._tools.keys():
		kit.set_material(key_name, BuildingKit.mat(key_name))
	kit.build(self, "VillageBonfire", 220.0)
	var fire_light := FlickerLight.create(Color("#ff9a3a"), 3.2, 16.0, 0.22, 5.0)
	fire_light.position = p + Vector3(0.0, 1.1, 0.0)
	add_child(fire_light)
	_register_world_interaction("bonfire", "Вогнище Села Попелу", p, 4.6, "E  —  ВІДПОЧИТИ БІЛЯ ВОГНИЩА")


func get_respawn_world_position() -> Vector3:
	## Куди повертає смерть: вогнище села (або вхід у Каземати, якщо загинув під землею).
	if player_in_dungeon:
		return to_global(DUNGEON_SPAWN_LOCAL)
	if checkpoint_local != Vector3.ZERO:
		return _raycast_ground_position(to_global(checkpoint_local), 1.4)
	var local := bonfire_local + Vector3(2.4, 0.0, 1.4) if bonfire_local != Vector3.ZERO else _surface_exit_local_position(0.0)
	return _raycast_ground_position(to_global(local), 1.4)

func _spawn_side_quest_items() -> void:
	## Ящик торговця біля Табору вигнанців та три пучки цілющих трав навколо Села Попелу.
	var crate_pos := _building_front_position("Табір вигнанців", 9.0, 6.0)
	if crate_pos != Vector3.ZERO:
		var crate := Interactable.spawn(self, crate_pos, "item_merchant_crate", Interactable.Kind.ITEM, "Ящик торговця", "ПІДНЯТИ ЯЩИК БРУНО", Color("#ffcf7a"))
		crate.item_id = "merchant_crate"
		crate.item_name = "Ящик Бруно з ліками"
	var herb_offsets := [Vector2(-14.0, 20.0), Vector2(18.0, 24.0), Vector2(-3.0, 31.0)]
	var index := 0
	for offset in herb_offsets:
		var herb_pos := _building_front_position("Село Попелу", 10.0 + offset.y * 0.3, offset.x)
		if herb_pos != Vector3.ZERO:
			herb_pos.y = _terrain_height_at_world(herb_pos.x, herb_pos.z)
			var herb := Interactable.spawn(self, herb_pos, "item_herb_%d" % index, Interactable.Kind.ITEM, "Цілюща трава", "ЗІРВАТИ ЦІЛЮЩУ ТРАВУ", Color("#8cf09a"))
			herb.item_id = "healing_herb"
			herb.item_name = "Цілюща трава"
		index += 1

func _spawn_note(position_value: Vector3, id: String, short_name: String, title: String, text: String) -> void:
	if position_value == Vector3.ZERO:
		return
	var note := Interactable.spawn(self, position_value, id, Interactable.Kind.NOTE, short_name, "ПРОЧИТАТИ: %s" % short_name.to_upper(), Color("#e8d29a"))
	note.note_title = title
	note.note_text = text


func _barrel_with_kit(kit: MeshKit, pos: Vector3) -> void:
	kit.cylinder_at("wood_light", pos, 0.38, 0.38, 0.95, 8, true)
	kit.cylinder_at("iron", pos + Vector3(0, 0.18, 0), 0.4, 0.4, 0.08, 8)
	kit.cylinder_at("iron", pos + Vector3(0, 0.7, 0), 0.4, 0.4, 0.08, 8)



func _spawn_combat_enemies() -> void:
	# Невеликі бойові зустрічі біля кладовища та фортеці. Вони не блокують сюжетні NPC.
	for map_point in [Vector2(2130.0, 1450.0), Vector2(2240.0, 1500.0), Vector2(2700.0, 880.0)]:
		_spawn_wraith(map_point)
	if not QuestManager.quest_log_changed.is_connected(_ensure_quest_enemies):
		QuestManager.quest_log_changed.connect(_ensure_quest_enemies)


func _spawn_wraith(map_point: Vector2) -> CharacterBody3D:
	var target := get_parent().get_node_or_null("Player") as CharacterBody3D
	if target == null:
		return null
	var wraith := WRAITH_SCENE.instantiate() as CharacterBody3D
	if wraith == null:
		return null
	wraith.name = "AshenWraith_%02d" % (combat_enemies.size() + 1)
	add_child(wraith)
	wraith.global_position = to_global(_surface_position(map_point.x, map_point.y, 0.04))
	wraith.call("set_target", target)
	combat_enemies.append(wraith)
	return wraith


func _ensure_quest_enemies() -> void:
	## Якщо ціль квесту — знищити вартових, а біля кладовища їх не лишилося, вони повстають знову.
	if QuestManager.get_quest_state("captain_patrol") == "active":
		var citadel := _surface_position(3100.0, 2300.0, 0.0)
		var patrol_alive := 0
		for enemy in combat_enemies:
			if is_instance_valid(enemy) and not bool(enemy.get("dead")) and enemy.position.distance_to(citadel) < 90.0:
				patrol_alive += 1
		for map_point in [Vector2(2980.0, 2250.0), Vector2(3060.0, 2160.0), Vector2(2900.0, 2330.0), Vector2(3160.0, 2430.0)]:
			if patrol_alive >= 4:
				break
			_spawn_wraith(map_point)
			patrol_alive += 1
	if QuestManager.get_quest_state("lamplighter_oil") != "active":
		return
	if QuestManager.get_tracked_target_id() != "ashen_wraith" and not _quest_needs_wraiths():
		return
	var cemetery := _surface_position(2240.0, 1330.0, 0.0)
	var alive := 0
	for enemy in combat_enemies:
		if is_instance_valid(enemy) and not bool(enemy.get("dead")) and enemy.position.distance_to(cemetery) < 70.0:
			alive += 1
	var spawn_points := [Vector2(2150.0, 1440.0), Vector2(2320.0, 1420.0), Vector2(2200.0, 1240.0)]
	var index := 0
	while alive < 2 and index < spawn_points.size():
		_spawn_wraith(spawn_points[index])
		alive += 1
		index += 1


func _quest_needs_wraiths() -> bool:
	var summary := QuestManager.get_quest_summary("lamplighter_oil")
	return str(summary.get("objective_text", "")).begins_with("Знищити")

func _register_building_interaction(building_name: String, interaction_id: String, hint: String) -> void:
	var position := _building_front_position(building_name, 5.0, 0.0)
	if position != Vector3.ZERO:
		_register_world_interaction(interaction_id, building_name, position, 5.6, hint)


func _get_nearest_world_interaction() -> String:
	## Найближча доступна взаємодія в полі зору гравця (конус ~110°).
	if player_ref == null:
		return ""
	var origin := player_ref.global_position
	var forward := -player_ref.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var best_id := ""
	var best_score := INF
	var candidates: Array = []
	for item in world_interactions:
		var interaction_id: String = str(item.get("id", ""))
		if interaction_id == "quest_target" and faction_quest_stage != 1:
			continue
		candidates.append([interaction_id, item.get("position", Vector3.ZERO), float(item.get("radius", 5.0))])
	if faction_quest_stage == 1 and quest_target_position != Vector3.ZERO:
		candidates.append(["quest_target", quest_target_position, 5.8])
	for node in get_tree().get_nodes_in_group("interactables"):
		var interactable := node as Interactable
		if interactable and interactable.is_available():
			candidates.append([interactable.interaction_id, interactable.global_position, interactable.radius])
	for candidate in candidates:
		var point: Vector3 = candidate[1]
		var distance: float = origin.distance_to(point)
		if distance > float(candidate[2]):
			continue
		var flat := Vector3(point.x - origin.x, 0.0, point.z - origin.z)
		var facing := 1.0 if flat.length() < 1.4 else forward.dot(flat.normalized())
		if facing < 0.25:
			continue
		# Пріоритет: те, що ближче і прямо перед гравцем.
		var score := distance * (1.6 - facing)
		if score < best_score:
			best_score = score
			best_id = str(candidate[0])
	return best_id


func get_interactable(interaction_id: String) -> Interactable:
	for node in get_tree().get_nodes_in_group("interactables"):
		var interactable := node as Interactable
		if interactable and interactable.interaction_id == interaction_id:
			return interactable
	return null

func start_faction_quest() -> bool:
	if player_in_dungeon or oath_choice == "" or faction_quest_stage != 0:
		return false
	faction_quest_branch = oath_choice
	if oath_choice == "principality":
		if principality_marker == null:
			return false
		quest_target_position = principality_marker.global_position
		quest_target_marker = principality_marker
		principality_marker.visible = true
		if mountain_marker:
			mountain_marker.visible = false
	else:
		if mountain_marker == null:
			return false
		quest_target_position = mountain_marker.global_position
		quest_target_marker = mountain_marker
		mountain_marker.visible = true
		if principality_marker:
			principality_marker.visible = false
	faction_quest_stage = 1
	return true


func inspect_faction_quest_target() -> bool:
	if faction_quest_stage != 1:
		return false
	faction_quest_stage = 2
	if quest_target_marker:
		quest_target_marker.visible = false
	if principality_marker:
		principality_marker.visible = false
	if mountain_marker:
		mountain_marker.visible = false
	return true


func complete_faction_quest() -> bool:
	if faction_quest_stage != 2:
		return false
	faction_quest_stage = 3
	return true


func get_faction_quest_stage() -> int:
	return faction_quest_stage


func get_faction_quest_branch() -> String:
	return faction_quest_branch


func get_oath_choice() -> String:
	return oath_choice

func create_detailed_building(b_name: String, kind: String, bw: float, bd: float, hex_col: String, pos: Vector3, look_target: Vector3) -> Node3D:
	## Будівля з BuildingKit; фасад (двері) розвернуто до найближчої дороги.
	var root = Node3D.new()
	root.name = "Building_%s" % b_name.replace(" ", "_")
	root.position = pos
	root.look_at_from_position(pos, Vector3(look_target.x, pos.y, look_target.z), Vector3.UP)
	var building := BuildingKit.build(kind, b_name, bw, bd, Color(hex_col), hash(b_name))
	root.add_child(building)
	return root

func prepare_trees_and_rocks():
	## Ялини, сухі дерева, брили, суха трава й придорожні ліхтарі (MultiMesh).
	var spawn_pos = _surface_position(1810.0, 2210.0)
	PropScatter.populate(self, terrain_builder, forbidden_zones, routes_3d, spawn_pos, Vector2(WORLD_W * 1.5 * SCALE, WORLD_H * 1.5 * SCALE))

func build_dungeon_portal_and_interior():
	# Наземний портал залишаємо зі старої версії, щоб до Казематів
	# можна було повернутися і після завершення вступного прологу.
	var portal_pos = _surface_position(1850.0, 2140.0, 1.8)
	var world_portal = Area3D.new()
	world_portal.name = "WorldToDungeonPortal"
	world_portal.position = portal_pos

	# Скельний вхід над порталом: дві природні опори та кам'яна перемичка.
	var cave_rock_material := make_material("#36343a", 0.08, 0.96, "", 0.0, "rock")
	for side: float in [-1.0, 1.0]:
		var cave_pillar := CSGCylinder3D.new()
		cave_pillar.name = "DungeonCavePillar"
		cave_pillar.sides = 7
		cave_pillar.radius = 1.35
		cave_pillar.height = 5.2
		cave_pillar.position = portal_pos + Vector3(side * 2.35, 0.8, 0.0)
		cave_pillar.rotation.z = side * deg_to_rad(5.0)
		cave_pillar.material = cave_rock_material
		cave_pillar.use_collision = true
		add_child(cave_pillar)

	var cave_lintel := CSGBox3D.new()
	cave_lintel.name = "DungeonCaveLintel"
	cave_lintel.size = Vector3(6.5, 1.65, 2.0)
	cave_lintel.position = portal_pos + Vector3(0.0, 3.7, 0.0)
	cave_lintel.rotation.z = deg_to_rad(-3.0)
	cave_lintel.material = cave_rock_material
	cave_lintel.use_collision = true
	add_child(cave_lintel)

	# Невисокі кам'яні сходинки ведуть до порталу й підкреслюють вхід у схил.
	for step_index in range(3):
		var stair := CSGBox3D.new()
		stair.name = "DungeonEntranceStep_%d" % step_index
		stair.size = Vector3(4.7, 0.22, 0.85)
		stair.position = portal_pos + Vector3(0.0, -1.48 - float(step_index) * 0.14, 1.8 + float(step_index) * 0.78)
		stair.material = cave_rock_material
		stair.use_collision = true
		add_child(stair)

	var torus := TorusMesh.new()
	torus.inner_radius = 1.3
	torus.outer_radius = 1.7
	var world_ring := MeshInstance3D.new()
	world_ring.name = "PortalRing"
	world_ring.mesh = torus
	world_ring.rotation.x = deg_to_rad(90.0)
	world_ring.material_override = make_material("#8a2be2", 0.0, 0.2, "#9b30ff", 4.0)
	world_portal.add_child(world_ring)

	_add_nameplate(world_portal, Vector3(0.0, 2.6, 0.0), "КАЗЕМАТИ СМЕРТІ", "", Color("#c79bff"), 26.0)

	var world_shape := SphereShape3D.new()
	world_shape.radius = 2.2
	var world_collision := CollisionShape3D.new()
	world_collision.shape = world_shape
	world_portal.add_child(world_collision)
	world_portal.body_entered.connect(_on_surface_portal_body_entered)
	add_child(world_portal)

	_build_dungeon_chamber(torus)


func _add_dungeon_box(box_name: String, box_size: Vector3, box_position: Vector3, material: Material, collision: bool = true) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.name = box_name
	box.size = box_size
	box.position = box_position
	box.material = material
	box.use_collision = collision
	add_child(box)
	return box


func _add_dungeon_pillar(pillar_position: Vector3, stone_material: Material) -> void:
	var base := CSGCylinder3D.new()
	base.sides = 8
	base.radius = 1.35
	base.height = 0.7
	base.position = pillar_position + Vector3(0.0, -4.8, 0.0)
	base.material = stone_material
	base.use_collision = true
	add_child(base)

	var column := CSGCylinder3D.new()
	column.sides = 8
	column.radius = 0.82
	column.height = 9.0
	column.position = pillar_position
	column.material = stone_material
	column.use_collision = true
	add_child(column)

	var capital := CSGCylinder3D.new()
	capital.sides = 8
	capital.radius = 1.35
	capital.height = 0.75
	capital.position = pillar_position + Vector3(0.0, 4.8, 0.0)
	capital.material = stone_material
	capital.use_collision = true
	add_child(capital)


func _add_dungeon_torch(torch_position: Vector3, flame_material: Material) -> void:
	var bracket := MeshInstance3D.new()
	var bracket_mesh := BoxMesh.new()
	bracket_mesh.size = Vector3(0.24, 1.15, 0.24)
	bracket.mesh = bracket_mesh
	bracket.position = torch_position
	bracket.material_override = make_material("#34251b", 0.35, 0.65)
	add_child(bracket)

	var flame := MeshInstance3D.new()
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.28
	flame_mesh.height = 0.72
	flame.mesh = flame_mesh
	flame.position = torch_position + Vector3(0.0, 0.75, 0.0)
	flame.scale = Vector3(0.72, 1.35, 0.72)
	flame.material_override = flame_material
	add_child(flame)

	var light := FlickerLight.create(Color("#ff8a45"), 1.7, 13.0, 0.28, 8.0)
	light.position = torch_position + Vector3(0.0, 1.0, 0.0)
	light.shadow_enabled = true
	light.crackle = true
	add_child(light)


func _build_dungeon_chamber(portal_mesh: TorusMesh) -> void:
	# Уся геометрія нижче нульового рівня світу; гравець не провалюється,
	# бо має окремі підлогу, стіни, стелю та коридор із колізіями.
	var floor_material := make_material("#292a2d", 0.0, 0.98, "", 0.0, "tiles")
	var wall_material := make_material("#343236", 0.0, 0.96, "", 0.0, "brick")
	var trim_material := make_material("#514b45", 0.15, 0.82, "", 0.0, "stone")
	var dark_material := make_material("#141519", 0.0, 0.98, "", 0.0, "stone")
	var gold_material := make_material("#8c6536", 0.55, 0.42, "#c58a3e", 1.5)
	var red_material := make_material("#642c2c", 0.25, 0.45, "#b43129", 2.2)
	var flame_material := make_material("#ff9a4c", 0.0, 0.3, "#ff641d", 3.6)

	# Центральна зала.
	_add_dungeon_box("CryptMainFloor", Vector3(50.0, 2.0, 36.0), Vector3(20.0, -51.0, 0.0), floor_material)
	_add_dungeon_box("CryptNorthWall", Vector3(50.0, 12.0, 2.0), Vector3(20.0, -44.0, -18.0), wall_material)
	_add_dungeon_box("CryptSouthWall", Vector3(50.0, 12.0, 2.0), Vector3(20.0, -44.0, 18.0), wall_material)
	_add_dungeon_box("CryptEastWall", Vector3(2.0, 12.0, 36.0), Vector3(45.0, -44.0, 0.0), wall_material)
	# Західна стіна має широкий прохід до довгого коридору.
	_add_dungeon_box("CryptWestWallNorth", Vector3(2.0, 12.0, 12.0), Vector3(-5.0, -44.0, -12.0), wall_material)
	_add_dungeon_box("CryptWestWallSouth", Vector3(2.0, 12.0, 12.0), Vector3(-5.0, -44.0, 12.0), wall_material)
	_add_dungeon_box("CryptCeiling", Vector3(50.0, 1.6, 36.0), Vector3(20.0, -37.5, 0.0), dark_material, false)

	# Коридор до виходу на поверхню.
	_add_dungeon_box("CryptExitFloor", Vector3(32.0, 2.0, 14.0), Vector3(-21.0, -51.0, 0.0), floor_material)
	_add_dungeon_box("CryptExitNorthWall", Vector3(32.0, 12.0, 1.6), Vector3(-21.0, -44.0, -7.4), wall_material)
	_add_dungeon_box("CryptExitSouthWall", Vector3(32.0, 12.0, 1.6), Vector3(-21.0, -44.0, 7.4), wall_material)
	_add_dungeon_box("CryptExitEndWall", Vector3(2.0, 12.0, 14.0), Vector3(-37.0, -44.0, 0.0), wall_material)
	_add_dungeon_box("CryptCorridorCeiling", Vector3(32.0, 1.6, 14.0), Vector3(-21.0, -37.5, 0.0), dark_material, false)

	# Кам'яні ребра, колони й уламки роблять залу схожою на стару гробницю.
	for pillar_pos in [
		Vector3(0.0, -44.0, -13.0), Vector3(39.0, -44.0, -13.0),
		Vector3(0.0, -44.0, 13.0), Vector3(39.0, -44.0, 13.0)
	]:
		_add_dungeon_pillar(pillar_pos, trim_material)

	for debris_data in [
		[Vector3(34.0, -49.3, 13.0), Vector3(2.4, 0.65, 1.2), 0.24],
		[Vector3(5.0, -49.4, -13.5), Vector3(1.8, 0.7, 1.0), -0.36],
		[Vector3(-1.0, -49.5, 10.0), Vector3(2.1, 0.8, 1.2), 0.42],
		[Vector3(27.0, -49.5, -14.0), Vector3(1.5, 0.7, 1.0), -0.18]
	]:
		var rubble := MeshInstance3D.new()
		var rubble_mesh := BoxMesh.new()
		rubble_mesh.size = debris_data[1]
		rubble.mesh = rubble_mesh
		rubble.position = debris_data[0]
		rubble.rotation.y = debris_data[2]
		rubble.material_override = trim_material
		add_child(rubble)

	# Старий саркофаг збоку від місця пробудження.
	var coffin := CSGBox3D.new()
	coffin.name = "BrokenSarcophagus"
	coffin.size = Vector3(5.0, 1.25, 2.8)
	coffin.position = Vector3(34.0, -49.25, 6.5)
	coffin.material = trim_material
	coffin.use_collision = true
	add_child(coffin)
	var coffin_lid := CSGBox3D.new()
	coffin_lid.size = Vector3(5.2, 0.5, 3.0)
	coffin_lid.position = Vector3(33.2, -48.35, 6.5)
	coffin_lid.rotation.z = deg_to_rad(13.0)
	coffin_lid.material = wall_material
	coffin_lid.use_collision = true
	add_child(coffin_lid)

	# Камінь Присяги — центральна точка сюжету Частини 2.
	# Новий вівтар: ступінчастий постамент, стела з рунами, браслети-реліквії (золотий і залізний).
	oath_altar_material = gold_material
	var oath_altar := LandmarkKit.build_oath_altar(gold_material, red_material)
	oath_altar.name = "OathAltarModel"
	oath_altar.position = Vector3(OATH_ALTAR_LOCAL.x, -50.0, OATH_ALTAR_LOCAL.z)
	add_child(oath_altar)

	_add_nameplate(self, OATH_ALTAR_LOCAL + Vector3(0.0, 4.4, 0.0), "КАМІНЬ ПРИСЯГИ", "", Color("#e8c78e"), 22.0)

	oath_altar_light = OmniLight3D.new()
	oath_altar_light.name = "OathStoneLight"
	oath_altar_light.light_color = Color("#d49a50")
	oath_altar_light.light_energy = 1.8
	oath_altar_light.omni_range = 12.0
	oath_altar_light.position = OATH_ALTAR_LOCAL + Vector3(0.0, 3.8, 0.0)
	oath_altar_light.shadow_enabled = false
	add_child(oath_altar_light)

	# Теплі факели й слабке холодне світло з тріщин.
	_add_dungeon_torch(Vector3(1.5, -43.5, -16.2), flame_material)
	_add_dungeon_torch(Vector3(38.0, -43.5, -16.2), flame_material)
	_add_dungeon_torch(Vector3(1.5, -43.5, 16.2), flame_material)
	_add_dungeon_torch(Vector3(38.0, -43.5, 16.2), flame_material)
	_add_dungeon_torch(Vector3(-20.0, -43.5, -6.2), flame_material)
	_add_dungeon_torch(Vector3(-20.0, -43.5, 6.2), flame_material)

	var cold_light := OmniLight3D.new()
	cold_light.light_color = Color("#8b9fc2")
	cold_light.light_energy = 0.55
	cold_light.omni_range = 22.0
	cold_light.position = Vector3(20.0, -40.0, 0.0)
	cold_light.shadow_enabled = false
	add_child(cold_light)

	# Портал у західному коридорі. Взаємодія з ним перевіряється через E.
	var exit_ring := MeshInstance3D.new()
	exit_ring.name = "DungeonExitRune"
	exit_ring.mesh = portal_mesh
	exit_ring.rotation.z = deg_to_rad(90.0)
	exit_ring.position = DUNGEON_EXIT_LOCAL + Vector3(-0.4, 0.0, 0.0)
	exit_ring.material_override = make_material("#4a9d83", 0.0, 0.18, "#43d5a5", 3.4)
	add_child(exit_ring)

	_add_nameplate(self, DUNGEON_EXIT_LOCAL + Vector3(-0.7, 3.0, 0.0), "ВИХІД НА ПОВЕРХНЮ", "", Color("#a7e1ca"), 22.0)


func _on_surface_portal_body_entered(body: Node3D) -> void:
	if body != player_ref or player_in_dungeon:
		return
	player_in_dungeon = true
	call_deferred("_teleport_player_to_dungeon_return")


func _teleport_player_to_dungeon_return() -> void:
	var player_body := player_ref as CharacterBody3D
	if player_body == null:
		return
	player_body.velocity = Vector3.ZERO
	player_body.global_position = to_global(DUNGEON_RETURN_LOCAL)
	player_body.rotation.y = -PI / 2.0
	if player_body.has_method("set_third_person_distance"):
		player_body.call("set_third_person_distance", 4.8)


func begin_part2_dungeon() -> void:
	player_ref = get_parent().find_child("Player", true, false) as Node3D
	if player_ref == null:
		push_error("Part 2: Player не знайдено — не вдалося розмістити героя в Казематах.")
		return
	player_in_dungeon = true
	oath_choice = ""
	faction_quest_stage = 0
	faction_quest_branch = ""
	quest_target_position = Vector3.ZERO
	quest_target_marker = null
	if principality_marker:
		principality_marker.visible = false
	if mountain_marker:
		mountain_marker.visible = false
	if oath_altar_material:
		PSXMaterials.set_albedo(oath_altar_material, Color("#8c6536"))
		PSXMaterials.set_emission(oath_altar_material, Color("#c58a3e"))
	if oath_altar_light:
		oath_altar_light.light_color = Color("#d49a50")
		oath_altar_light.light_energy = 1.8
	var player_body := player_ref as CharacterBody3D
	if player_body:
		player_body.velocity = Vector3.ZERO
		player_body.global_position = to_global(DUNGEON_SPAWN_LOCAL)
		player_body.rotation.y = PI / 2.0
		if player_body.has_method("set_third_person_distance"):
			player_body.call("set_third_person_distance", 4.8)


func get_nearby_interaction() -> String:
	if player_ref == null:
		return ""
	if player_in_dungeon:
		var player_position := player_ref.global_position
		var altar_position := to_global(OATH_ALTAR_LOCAL)
		var exit_position := to_global(DUNGEON_EXIT_LOCAL)
		if oath_choice == "" and player_position.distance_to(altar_position) <= 5.2:
			return "oath"
		if player_position.distance_to(exit_position) <= 6.5:
			if oath_choice == "":
				return "exit_locked"
			return "exit"
		return ""
	return _get_nearest_world_interaction()


func get_interaction_hint() -> String:
	if player_ref == null:
		return ""
	if player_in_dungeon:
		var player_position := player_ref.global_position
		var altar_distance := player_position.distance_to(to_global(OATH_ALTAR_LOCAL))
		var exit_distance := player_position.distance_to(to_global(DUNGEON_EXIT_LOCAL))
		if oath_choice == "" and altar_distance <= 5.2:
			return "[E]  ПРОЧИТАТИ КАМІНЬ ПРИСЯГИ"
		if exit_distance <= 6.5 and oath_choice == "":
			return "ВИХІД ЗАМКНЕНО  •  СПЕРШУ ОБЕРИ ПРИСЯГУ"
		if oath_choice != "" and exit_distance <= 6.5:
			return "[E]  ВИЙТИ НА ПОВЕРХНЮ"
		return ""
	var interaction_id := _get_nearest_world_interaction()
	if interaction_id == "":
		return ""
	if interaction_id == "quest_target":
		return "[E]  ДОСЛІДИТИ СЮЖЕТНУ ЗНАХІДКУ"
	var interactable := get_interactable(interaction_id)
	if interactable:
		return interactable.get_hint()
	for item in world_interactions:
		if str(item.get("id", "")) == interaction_id:
			return str(item.get("hint", "E  —  ВЗАЄМОДІЯ")).replace("E  —  ", "[E]  ")
	return "[E]  ВЗАЄМОДІЯ"

func commit_oath(choice: String) -> void:
	if choice not in ["principality", "mountain"]:
		return
	oath_choice = choice
	if oath_altar_material:
		if choice == "principality":
			PSXMaterials.set_albedo(oath_altar_material, Color("#c79a58"))
			PSXMaterials.set_emission(oath_altar_material, Color("#e3a64c"))
		else:
			PSXMaterials.set_albedo(oath_altar_material, Color("#8b3934"))
			PSXMaterials.set_emission(oath_altar_material, Color("#e34838"))
	if oath_altar_light:
		oath_altar_light.light_color = Color("#e4b05b") if choice == "principality" else Color("#ed5141")
		oath_altar_light.light_energy = 2.8


func leave_dungeon() -> void:
	if not player_in_dungeon or oath_choice == "" or player_ref == null:
		return
	var player_body := player_ref as CharacterBody3D
	if player_body == null:
		return

	# Підіймаємо центр капсули вище поверхні: старі 0.9 м залишали
	# нижню частину двометрової капсули всередині землі після телепортації.
	player_body.velocity = Vector3.ZERO
	player_body.global_position = _raycast_ground_position(to_global(_surface_exit_local_position(0.0)))
	player_body.rotation.y = 0.0
	player_body.floor_snap_length = 0.5
	player_body.reset_physics_interpolation()

	if player_body.has_method("set_third_person_distance"):
		player_body.call("set_third_person_distance", 6.0)

	player_in_dungeon = false
	dungeon_exited.emit(oath_choice)


func get_current_objective() -> String:
	var story := QuestManager.get_quest_summary("main_story")
	if str(story.get("status", "")) == "active":
		return "ГОЛОВНА ЦІЛЬ: %s" % str(story.get("objective_text", ""))
	if player_in_dungeon:
		if oath_choice == "":
			return "ЗАВДАННЯ: знайди Камінь Присяги в центрі Казематів."
		return "ЗАВДАННЯ: дістанься західного порталу та вийди на поверхню."
	if faction_quest_stage == 1:
		if faction_quest_branch == "principality":
			return "ДОРУЧЕННЯ КАСТЕЛЯНА: знайди Печатку Зорі в Зруйнованій Обсерваторії."
		return "ДОРУЧЕННЯ ЧОРНОЇ ГОРИ: знайди Відлуння Ока біля Фортеці Чорного Прапора."
	if faction_quest_stage == 2:
		if faction_quest_branch == "principality":
			return "ПОВЕРНИСЯ ДО КАСТЕЛЯНА ЕДРИКА З ПЕЧАТКОЮ ЗОРІ."
		return "ПОВЕРНИСЯ ДО ПОСЛУШНИКА ВАРКА З ВІДЛУННЯМ ОКА."
	if oath_choice == "principality":
		return "ПРИСЯГА КНЯЗІВСТВУ: вирушай до Попелястої Цитаделі на сході."
	if oath_choice == "mountain":
		return "ПРИСЯГА ГОРІ: прямуй до Чорної Гори на північному заході."
	return "ЗАВДАННЯ: досліди землі, що прокинулися після падіння королівства."

func _process(delta):
	_update_day_night_cycle(delta)
	# Тліючий вінець на вершині повільно «дихає» — Око Чорної Гори.
	eye_clock += delta
	if is_instance_valid(eye_light):
		eye_light.light_energy = 0.0 if eye_destroyed else 5.5 + sin(eye_clock * 1.3) * 1.6 + sin(eye_clock * 3.7) * 0.4
	if not player_ref:
		player_ref = get_parent().find_child("Player", true, false)
	_recover_player_if_underground()

func _raycast_ground_position(world_position: Vector3, clearance: float = 2.5) -> Vector3:
	## Надійний спавн: вертикальний промінь зверху вниз знаходить реальну поверхню землі.
	## Гравець ставиться на `clearance` метрів вище точки влучання; без влучання — на +3 м
	## над розрахунковою висотою рельєфу.
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(world_position.x, 200.0, world_position.z),
		Vector3(world_position.x, -100.0, world_position.z),
		1
	)
	if player_ref is CollisionObject3D:
		query.exclude = [(player_ref as CollisionObject3D).get_rid()]
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		return Vector3(world_position.x, float(hit["position"].y) + clearance, world_position.z)
	var local := to_local(world_position)
	var ground_y := to_global(Vector3(local.x, _terrain_height_at_world(local.x, local.z), local.z)).y
	return Vector3(world_position.x, ground_y + maxf(clearance, 3.0), world_position.z)


func _recover_player_if_underground() -> void:
	## Запобіжник: якщо гравець опинився під поверхнею (поза каземами) — піднімаємо його.
	if player_ref == null or player_in_dungeon or not bool(player_ref.get("controls_enabled")):
		return
	var local := to_local(player_ref.global_position)
	if local.y < _terrain_height_at_world(local.x, local.z) - 4.0:
		var body := player_ref as CharacterBody3D
		if body:
			body.velocity = Vector3.ZERO
		player_ref.global_position = _raycast_ground_position(player_ref.global_position)


func safe_spawn_player() -> void:
	player_ref = get_parent().find_child("Player", true, false)
	if player_ref:
		player_ref.set_physics_process(false)
		var safe_position := _raycast_ground_position(to_global(_surface_exit_local_position(0.0)))
		player_ref.global_position = safe_position
		if player_ref is CharacterBody3D:
			(player_ref as CharacterBody3D).velocity = Vector3.ZERO
		await get_tree().physics_frame
		await get_tree().physics_frame
		# Колізія рельєфу вже в фізичному просторі — уточнюємо точку променем.
		safe_position = _raycast_ground_position(to_global(_surface_exit_local_position(0.0)))
		player_ref.global_position = safe_position
		if player_ref is CharacterBody3D:
			(player_ref as CharacterBody3D).velocity = Vector3.ZERO
			(player_ref as CharacterBody3D).reset_physics_interpolation()
		player_ref.set_physics_process(true)

# -----------------------------------------------------------------------------
# PART 4 — MAP DATA API
# -----------------------------------------------------------------------------
const MAP_HEIGHT_COLS := 170
const MAP_HEIGHT_ROWS := 122
var _map_heights: PackedFloat32Array = PackedFloat32Array()
var _map_river: PackedVector2Array = PackedVector2Array()


func _ensure_map_terrain_cache() -> void:
	if _map_heights.size() > 0:
		return
	var world_size := Vector2(WORLD_W * 1.5 * SCALE, WORLD_H * 1.5 * SCALE)
	_map_heights.resize(MAP_HEIGHT_COLS * MAP_HEIGHT_ROWS)
	for row in range(MAP_HEIGHT_ROWS):
		for col in range(MAP_HEIGHT_COLS):
			var wx := world_size.x * float(col) / float(MAP_HEIGHT_COLS - 1)
			var wz := world_size.y * float(row) / float(MAP_HEIGHT_ROWS - 1)
			_map_heights[row * MAP_HEIGHT_COLS + col] = _terrain_height_at_world(wx, wz)
	for river_point in [Vector2(3300, 0), Vector2(3060, 400), Vector2(2850, 760), Vector2(2650, 1120), Vector2(2410, 1440), Vector2(2180, 1760), Vector2(1900, 2100), Vector2(1640, 2600)]:
		var rp := to_3d(river_point.x, river_point.y, 0.0)
		_map_river.append(Vector2(rp.x, rp.z))


func get_map_snapshot() -> Dictionary:
	_ensure_map_terrain_cache()
	var map_routes: Array = []
	for route in routes_3d:
		var points := PackedVector2Array()
		for world_point in route:
			points.append(Vector2(world_point.x, world_point.z))
		map_routes.append(points)

	var map_buildings: Array[Dictionary] = []
	for building_data in buildings_data:
		var building_name: String = str(building_data.get("name", ""))
		var building_node := building_nodes.get(building_name) as Node3D
		var local_position: Vector3 = building_node.position if building_node else to_3d(float(building_data.get("x", 0.0)), float(building_data.get("y", 0.0)), 0.0)
		map_buildings.append({
			"name": building_name,
			"kind": str(building_data.get("kind", "")),
			"position": Vector2(local_position.x, local_position.z)
		})

	var map_npcs: Array[Dictionary] = []
	for interaction in world_interactions:
		var interaction_id: String = str(interaction.get("id", ""))
		if not interaction_id.begins_with("npc_"):
			continue
		var global_position: Vector3 = interaction.get("position", Vector3.ZERO)
		var local_position := to_local(global_position)
		map_npcs.append({
			"id": interaction_id,
			"name": str(interaction.get("name", "Мандрівник")),
			"position": Vector2(local_position.x, local_position.z)
		})

	var map_regions: Array[Dictionary] = []
	var biome_data: Array[Dictionary] = [
		{"x": 650.0, "y": 550.0, "r": 120.0, "color": Color(0.18, 0.30, 0.22, 0.22)},
		{"x": 3050.0, "y": 400.0, "r": 115.0, "color": Color(0.30, 0.39, 0.46, 0.20)},
		{"x": 500.0, "y": 1950.0, "r": 110.0, "color": Color(0.17, 0.29, 0.19, 0.20)},
		{"x": 1750.0, "y": 1300.0, "r": 95.0, "color": Color(0.31, 0.30, 0.26, 0.19)},
		{"x": 3050.0, "y": 2100.0, "r": 115.0, "color": Color(0.38, 0.23, 0.20, 0.20)},
		{"x": 2100.0, "y": 2150.0, "r": 100.0, "color": Color(0.38, 0.34, 0.22, 0.18)}
	]
	for biome in biome_data:
		var region_position := to_3d(float(biome["x"]), float(biome["y"]), 0.0)
		map_regions.append({
			"position": Vector2(region_position.x, region_position.z),
			"radius": float(biome["r"]),
			"color": biome["color"]
		})

	var mountain_position := to_3d(670.0, 650.0, 0.0)
	var castle_position := to_3d(2930.0, 545.0, 0.0)
	var landmarks: Array[Dictionary] = [
		{"name": "ЧОРНА ГОРА • ПОПЕЛЯСТА КОРОНА", "position": Vector2(mountain_position.x, mountain_position.z), "color": Color("#ef633e")},
		{"name": "КОРОЛІВСЬКИЙ ЗАМОК", "position": Vector2(castle_position.x, castle_position.z), "color": Color("#d6b16f")}
	]

	var quest_is_visible := faction_quest_stage == 1 or faction_quest_stage == 2
	var quest_position := Vector2(-10000.0, -10000.0)
	if faction_quest_stage == 1 and quest_target_position != Vector3.ZERO:
		var local_target := to_local(quest_target_position)
		quest_position = Vector2(local_target.x, local_target.z)
	elif faction_quest_stage == 2:
		var return_npc_id := "npc_castellan" if faction_quest_branch == "principality" else "npc_acolyte"
		for interaction in world_interactions:
			if str(interaction.get("id", "")) == return_npc_id:
				var npc_local := to_local(interaction.get("position", Vector3.ZERO))
				quest_position = Vector2(npc_local.x, npc_local.z)
				break

	# Головний сюжет: мітка поточної цілі на мінікарті та атласі.
	var story_target := get_story_target_local()
	if story_target != Vector3.ZERO:
		quest_is_visible = true
		quest_position = Vector2(story_target.x, story_target.z)

	var player_position := Vector2.ZERO
	if player_ref and is_instance_valid(player_ref):
		var local_player := to_local(player_ref.global_position)
		player_position = Vector2(local_player.x, local_player.z)

	return {
		"world_size": Vector2(WORLD_W * 1.5 * SCALE, WORLD_H * 1.5 * SCALE),
		"routes": map_routes,
		"heights": _map_heights,
		"eye_known": eye_map_known,
		"atlas_owned": QuestManager.get_map_pieces(),
		"eye_position": _eye_map_position(),
		"height_cols": MAP_HEIGHT_COLS,
		"height_rows": MAP_HEIGHT_ROWS,
		"river": _map_river,
		"buildings": map_buildings,
		"npcs": map_npcs,
		"regions": map_regions,
		"landmarks": landmarks,
		"player_position": player_position,
		"quest_position": quest_position,
		"quest_visible": quest_is_visible,
		"quest_branch": faction_quest_branch,
		"quest_stage": faction_quest_stage,
		"oath_choice": oath_choice,
		"player_in_dungeon": player_in_dungeon
	}

