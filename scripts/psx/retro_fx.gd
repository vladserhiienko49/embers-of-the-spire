extends CanvasLayer
## RetroFX (Autoload) — PSX-пост-процесинг поверх 3D-кадру та глобальні
## параметри вершинного тремтіння. 3D рендериться у зниженій роздільності
## (scaling_3d_scale), а шейдер вирівнює кадр у чіткі «пікселі».

signal settings_changed

const POST_SHADER: Shader = preload("res://shaders/psx_post.gdshader")
const SETTINGS_PATH: String = "user://retro_fx.cfg"
## Цільова вертикальна роздільність кожного пресету (0 — без пікселізації).
const PRESETS: Dictionary = {"off": 0, "sharp": 480, "soft": 360, "psx": 240, "crunchy": 180}
const PRESET_ORDER: Array[String] = ["off", "sharp", "soft", "psx", "crunchy"]
const PRESET_LABELS: Dictionary = {
	"off": "Вимкнено",
	"sharp": "Чітка — 480p",
	"soft": "Класична — 360p",
	"psx": "PSX — 240p",
	"crunchy": "Груба — 180p"
}
## Множник сітки тремтіння: 0.5 = зсув на 2 віртуальні пікселі.
const JITTER_GRID_SCALE: float = 1.0
const SETTINGS_VERSION: int = 2

var preset: String = "soft"
var dither_enabled: bool = true
var jitter_enabled: bool = true

var _rect: ColorRect
var _material: ShaderMaterial


func _ready() -> void:
	layer = 1 # нижче за HUD (5) та меню (20+)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_material = ShaderMaterial.new()
	_material.shader = POST_SHADER
	_rect = ColorRect.new()
	_rect.name = "PSXPostProcess"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.material = _material
	add_child(_rect)
	_load_settings()
	get_tree().root.size_changed.connect(apply)
	apply()


func apply() -> void:
	var root := get_tree().root
	var window_size := Vector2(root.size)
	if window_size.y <= 0.0:
		return
	var target := int(PRESETS.get(preset, 240))
	var pixel_size := 1.0
	if target > 0:
		pixel_size = maxf(1.0, roundf(window_size.y / float(target)))

	_rect.visible = target > 0 or dither_enabled
	_material.set_shader_parameter("pixel_size", pixel_size)
	_material.set_shader_parameter("dither_strength", 1.0 if dither_enabled else 0.0)
	_material.set_shader_parameter("color_levels", 32.0 if dither_enabled else 256.0)

	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = clampf(1.0 / pixel_size, 0.25, 1.0)

	# Сітка тремтіння прив'язана до віртуальної роздільності; без пікселізації — до ~240p.
	var virtual_height := float(target) if target > 0 else 240.0
	var virtual_size := Vector2(window_size.x / window_size.y * virtual_height, virtual_height)
	RenderingServer.global_shader_parameter_set("psx_snap_resolution", virtual_size * JITTER_GRID_SCALE)
	RenderingServer.global_shader_parameter_set("psx_snap_enabled", 1.0 if jitter_enabled else 0.0)
	settings_changed.emit()


func set_preset(value: String) -> void:
	if not PRESETS.has(value):
		return
	preset = value
	apply()
	_save_settings()


func set_dither_enabled(value: bool) -> void:
	dither_enabled = value
	apply()
	_save_settings()


func set_jitter_enabled(value: bool) -> void:
	jitter_enabled = value
	apply()
	_save_settings()


func get_preset_label(value: String = "") -> String:
	return str(PRESET_LABELS.get(value if not value.is_empty() else preset, preset))


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	var saved := str(cfg.get_value("retro", "preset", preset))
	# Старі налаштування (v1) мали 240p за замовчуванням — переходимо на 360p.
	if int(cfg.get_value("retro", "version", 1)) < SETTINGS_VERSION and saved == "psx":
		saved = "soft"
	if PRESETS.has(saved):
		preset = saved
	dither_enabled = bool(cfg.get_value("retro", "dither", dither_enabled))
	jitter_enabled = bool(cfg.get_value("retro", "jitter", jitter_enabled))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("retro", "version", SETTINGS_VERSION)
	cfg.set_value("retro", "preset", preset)
	cfg.set_value("retro", "dither", dither_enabled)
	cfg.set_value("retro", "jitter", jitter_enabled)
	cfg.save(SETTINGS_PATH)
