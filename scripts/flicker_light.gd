class_name FlickerLight
extends OmniLight3D
## Тепле джерело світла з природним мерехтінням на шумі (факели, вікна, вогнища).
## Далекі вогні автоматично гаснуть (distance fade) — це дешево для продуктивності.

@export var base_energy: float = 1.6
@export_range(0.0, 1.0) var flicker_amount: float = 0.22
@export var flicker_speed: float = 7.0
@export var fade_begin: float = 70.0
## Додає 3D-звук потріскування вогню (для багать, горнів, факелів).
@export var crackle: bool = false

static var _noise: FastNoiseLite

var _time: float = 0.0
var _seed_offset: float = 0.0


static func create(color: Color, energy: float, light_range: float, flicker: float = 0.22, speed: float = 7.0) -> FlickerLight:
	var light := FlickerLight.new()
	light.light_color = color
	light.base_energy = energy
	light.light_energy = energy
	light.omni_range = light_range
	light.flicker_amount = flicker
	light.flicker_speed = speed
	light.shadow_enabled = false
	return light


func _ready() -> void:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		_noise.frequency = 1.0
		_noise.fractal_octaves = 2
	_seed_offset = randf() * 1000.0
	omni_attenuation = 1.4
	distance_fade_enabled = true
	distance_fade_begin = fade_begin
	distance_fade_length = 25.0
	light_volumetric_fog_energy = 1.6
	if crackle:
		var stream := ResourceLoader.load(AudioCatalog.AMBIENT["fire"]) as AudioStream
		if stream:
			if stream is AudioStreamWAV:
				var wav := stream as AudioStreamWAV
				wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
				wav.loop_begin = 0
				wav.loop_end = int(round(wav.get_length() * float(wav.mix_rate)))
			var fire := AudioStreamPlayer3D.new()
			fire.name = "Crackle"
			fire.stream = stream
			fire.bus = "Ambient"
			fire.volume_db = -8.0 + 6.0 * clampf(base_energy / 4.0, 0.0, 1.0)
			fire.max_distance = 26.0
			fire.unit_size = 3.5
			fire.autoplay = true
			add_child(fire)
			fire.play(randf() * 6.0)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta * flicker_speed
	var n := _noise.get_noise_2d(_time, _seed_offset) # -1..1
	var gust := _noise.get_noise_2d(_seed_offset, _time * 0.21)
	light_energy = base_energy * (1.0 + n * flicker_amount + minf(gust, 0.0) * flicker_amount * 0.8)
