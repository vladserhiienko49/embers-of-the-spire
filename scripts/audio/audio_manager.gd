extends Node
## AudioManager (Autoload) — уся звукова система Ashen Crown.
## • Шини: Master → Music / SFX (з реверберацією) / Ambient / UI; гучності зберігаються у user://audio.cfg.
## • Музика: шари explore / dungeon / combat / menu з плавним кросфейдом за станом гри.
## • Амбієнти: вітер (гучніший на висоті), цвіркуни вночі, каземати; випадкові звуки природи.
## • SFX: пули плеєрів, випадкові варіанти, 3D-звуки у світі, кроки за типом поверхні.

signal volumes_changed

const SETTINGS_PATH: String = "user://audio.cfg"
const BUS_NAMES: Array[String] = ["Music", "SFX", "Ambient", "UI"]
## Базова гучність шини (дБ) при 100 % повзунка.
const BUS_BASE_DB: Dictionary = {"Music": -4.0, "SFX": 0.0, "Ambient": -5.0, "UI": -2.0}
const DEFAULT_PERCENT: Dictionary = {"master": 100.0, "music": 70.0, "sfx": 85.0, "ambient": 80.0}
const MUSIC_TRIM_DB: Dictionary = {"explore": 0.0, "dungeon": 0.0, "combat": -2.0, "menu": -3.0, "boss": -1.0, "mass": -1.5}
## Відстань до Стража Ока, на якій вмикається музика фінального бою.
const BOSS_RADIUS: float = 80.0
const SFX_TRIM_DB: Dictionary = {
	"ui_hover": -9.0, "ui_click": -4.0, "owl": -6.0, "crow": -6.0, "wolf_howl": -4.0, "distant_bell": -5.0,
	"step_grass": -1.0, "step_dirt": -1.0,
}
const FADE_SECONDS: float = 3.0
const COMBAT_RADIUS: float = 17.0

var percent: Dictionary = DEFAULT_PERCENT.duplicate()
var context: String = "menu"

var world: Node3D = null
var player: Node3D = null

var _streams: Dictionary = {}
var _last_variant: Dictionary = {}
var _sfx_pool: Array[AudioStreamPlayer] = []
var _ui_pool: Array[AudioStreamPlayer] = []
var _sfx_cursor: int = 0
var _ui_cursor: int = 0
var _layers: Dictionary = {}   # "music/explore" -> {player, level, target, trim}
var _music_filter: AudioEffectLowPassFilter
var _sfx_reverb: AudioEffectReverb
var _poll_timer: float = 0.0
var _combat: bool = false
var _combat_hold: float = 0.0
var _boss: bool = false
## Масовий бій (10–15 ворогів): вмикає MassBattle; індустріально-металева тема замінює explore/combat.
var mass_battle: bool = false
var _in_dungeon: bool = false
var _night: float = 0.5
var _altitude: float = 0.0
var _oneshot_timer: float = 25.0
var _bell_timer: float = 90.0
var _filter_cutoff: float = 20500.0
var _muffled: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_load_settings()
	_apply_volumes()
	for i in range(12):
		_sfx_pool.append(_make_player("SFX"))
	for i in range(5):
		_ui_pool.append(_make_player("UI"))
	for key in AudioCatalog.MUSIC.keys():
		_add_layer("music/" + str(key), str(AudioCatalog.MUSIC[key]), "Music", float(MUSIC_TRIM_DB.get(key, 0.0)))
	for key in ["wind", "night", "dungeon"]:
		_add_layer("amb/" + key, str(AudioCatalog.AMBIENT[key]), "Ambient", 0.0)
	_update_targets()


## Фінальна композиція (одноразова, без зациклення): див. tools/audio_synth.gd → music_finale.
var _finale_player: AudioStreamPlayer = null


func play_finale() -> bool:
	if _finale_player and _finale_player.playing:
		return true
	if not ResourceLoader.exists(AudioCatalog.FINALE):
		push_warning("AudioManager: немає %s (SYNTH_ONLY=finale)" % AudioCatalog.FINALE)
		return false
	var stream := ResourceLoader.load(AudioCatalog.FINALE) as AudioStream
	if stream == null:
		return false
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
	if _finale_player == null:
		_finale_player = _make_player("Music")
	_finale_player.stream = stream
	_finale_player.volume_db = 1.0
	_finale_player.play()
	set_context("finale")
	return true


func stop_finale(fade_seconds: float = 1.5) -> void:
	if _finale_player == null or not _finale_player.playing:
		return
	var player_ref: AudioStreamPlayer = _finale_player
	var tween := create_tween()
	tween.tween_property(player_ref, "volume_db", -60.0, maxf(fade_seconds, 0.05))
	tween.tween_callback(player_ref.stop)


func register_world(world_node: Node3D, player_node: Node3D) -> void:
	world = world_node
	player = player_node


# --- Шини та гучність ---------------------------------------------------------------

func _setup_buses() -> void:
	for bus_name in BUS_NAMES:
		if AudioServer.get_bus_index(bus_name) == -1:
			var index := AudioServer.bus_count
			AudioServer.add_bus(index)
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")
	_music_filter = AudioEffectLowPassFilter.new()
	_music_filter.cutoff_hz = 20500.0
	_music_filter.resonance = 0.6
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Music"), _music_filter)
	_sfx_reverb = AudioEffectReverb.new()
	_sfx_reverb.room_size = 0.4
	_sfx_reverb.damping = 0.6
	_sfx_reverb.wet = 0.1
	_sfx_reverb.dry = 1.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"), _sfx_reverb)


func _make_player(bus_name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus_name
	add_child(p)
	return p


func _percent_to_db(value: float) -> float:
	return -80.0 if value <= 0.5 else linear_to_db(value / 100.0)


func _apply_volumes() -> void:
	AudioServer.set_bus_volume_db(0, _percent_to_db(float(percent["master"])))
	var map := {"Music": "music", "SFX": "sfx", "Ambient": "ambient", "UI": "sfx"}
	for bus_name in BUS_NAMES:
		var index := AudioServer.get_bus_index(bus_name)
		var db := _percent_to_db(float(percent[map[bus_name]]))
		AudioServer.set_bus_volume_db(index, -80.0 if db <= -79.0 else float(BUS_BASE_DB[bus_name]) + db)


func set_volume(key: String, value: float) -> void:
	if not percent.has(key):
		return
	percent[key] = clampf(value, 0.0, 100.0)
	_apply_volumes()
	_save_settings()
	volumes_changed.emit()


func get_volume(key: String) -> float:
	return float(percent.get(key, 100.0))


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for key in percent.keys():
		percent[key] = clampf(float(cfg.get_value("volume", key, percent[key])), 0.0, 100.0)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in percent.keys():
		cfg.set_value("volume", key, percent[key])
	cfg.save(SETTINGS_PATH)


# --- Музика й амбієнти (шари) ---------------------------------------------------------

func _add_layer(key: String, path: String, bus_name: String, trim_db: float) -> void:
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: немає %s (запусти tools/audio_synth.gd)" % path)
		return
	var stream := ResourceLoader.load(path) as AudioStream
	if stream == null:
		return
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(round(wav.get_length() * float(wav.mix_rate)))
	var p := _make_player(bus_name)
	p.stream = stream
	p.volume_db = -80.0
	_layers[key] = {"player": p, "level": 0.0, "target": 0.0, "trim": trim_db}


func _set_target(key: String, value: float) -> void:
	if _layers.has(key):
		_layers[key]["target"] = value


func set_mass_battle(active: bool, _source: String = "") -> void:
	if mass_battle == active:
		return
	mass_battle = active
	_update_targets()


func set_context(new_context: String) -> void:
	if new_context == context:
		return
	context = new_context
	_muffled = context == "paused"
	_update_targets()


func _update_targets() -> void:
	var ambient_scale := 0.55 if context == "paused" else 1.0
	var in_game := context == "game" or context == "paused"
	_set_target("music/menu", 1.0 if context == "menu" else 0.0)
	var explore := 0.0
	var dungeon := 0.0
	var combat := 0.0
	if in_game:
		if _in_dungeon:
			dungeon = 0.5 if _combat else 1.0
		else:
			explore = 0.35 if _combat else 1.0
		combat = 1.0 if _combat else 0.0
		if _boss:
			explore = 0.0
			dungeon = 0.0
			combat = 0.0
		elif mass_battle:
			explore = 0.0
			dungeon = 0.0
			combat = 0.0
	_set_target("music/boss", 1.0 if (in_game and _boss) else 0.0)
	_set_target("music/mass", 1.0 if (in_game and mass_battle and not _boss) else 0.0)
	_set_target("music/explore", explore)
	_set_target("music/dungeon", dungeon)
	_set_target("music/combat", combat)
	var wind := 0.0
	var night := 0.0
	var dungeon_amb := 0.0
	if in_game:
		if _in_dungeon:
			dungeon_amb = 1.0
		else:
			wind = clampf(0.5 + _altitude / 150.0, 0.4, 1.0)
			night = clampf(_night, 0.0, 1.0) * 0.9
	_set_target("amb/wind", wind * ambient_scale)
	_set_target("amb/night", night * ambient_scale)
	_set_target("amb/dungeon", dungeon_amb * ambient_scale)


func _process(delta: float) -> void:
	_poll_timer -= delta
	if _poll_timer <= 0.0:
		_poll_timer = 0.25
		_poll_world()
	for key in _layers.keys():
		var layer: Dictionary = _layers[key]
		var p: AudioStreamPlayer = layer["player"]
		var rate := delta / FADE_SECONDS if float(layer["target"]) > float(layer["level"]) else delta / (FADE_SECONDS * 0.8)
		layer["level"] = move_toward(float(layer["level"]), float(layer["target"]), rate)
		var level: float = layer["level"]
		if level <= 0.002:
			if p.playing:
				p.stop()
			continue
		if not p.playing:
			p.play(randf() * 4.0 if str(key).begins_with("amb/") else 0.0)
		p.volume_db = linear_to_db(level) + float(layer["trim"])
	var target_cutoff := 1100.0 if _muffled else 20500.0
	_filter_cutoff = lerpf(_filter_cutoff, target_cutoff, clampf(delta * 5.0, 0.0, 1.0))
	_music_filter.cutoff_hz = _filter_cutoff
	var wet_target := 0.34 if _in_dungeon else 0.1
	_sfx_reverb.wet = lerpf(_sfx_reverb.wet, wet_target, clampf(delta * 2.0, 0.0, 1.0))
	_sfx_reverb.room_size = lerpf(_sfx_reverb.room_size, 0.85 if _in_dungeon else 0.4, clampf(delta * 2.0, 0.0, 1.0))
	if context == "game":
		_update_oneshots(delta)


func _poll_world() -> void:
	if context != "game" and context != "paused":
		return
	if world and is_instance_valid(world):
		_in_dungeon = bool(world.get("player_in_dungeon"))
		if world.has_method("get_night_amount"):
			_night = float(world.call("get_night_amount"))
	if player and is_instance_valid(player):
		_altitude = player.global_position.y - (world.global_position.y if world else 0.0)
		var near := false
		for enemy in get_tree().get_nodes_in_group("hostile"):
			var body := enemy as Node3D
			if body == null or bool(body.get("dead")):
				continue
			if body.global_position.distance_to(player.global_position) < COMBAT_RADIUS:
				near = true
				break
		if near:
			_combat_hold = 5.0
		else:
			_combat_hold = maxf(0.0, _combat_hold - 0.25)
		_combat = _combat_hold > 0.0
		_boss = _is_boss_fight_active()
	_update_targets()


func _is_boss_fight_active() -> bool:
	## Бій із Стражем Ока: бос живий, гравець поруч і не загинув. Музика сама стихає
	## після перемоги (бос мертвий) або смерті гравця; далі грає фінал.
	if world == null or player == null or not is_instance_valid(world) or not is_instance_valid(player):
		return false
	var nodes = world.get("story_nodes")
	if typeof(nodes) != TYPE_DICTIONARY:
		return false
	var boss_v = (nodes as Dictionary).get("eye_guardian")
	if boss_v == null or not is_instance_valid(boss_v) or bool(boss_v.get("dead")):
		# Давній Маг — міні-бос Крижаної вежі: та сама бойова тема боса.
		boss_v = (nodes as Dictionary).get("ancient_mage")
	if boss_v == null or not is_instance_valid(boss_v):
		return false
	var boss := boss_v as Node3D
	if boss == null or bool(boss.get("dead")):
		return false
	if player.has_method("is_defeated") and bool(player.call("is_defeated")):
		return false
	return boss.global_position.distance_to(player.global_position) < BOSS_RADIUS


func _update_oneshots(delta: float) -> void:
	if _in_dungeon or player == null:
		return
	_oneshot_timer -= delta
	if _oneshot_timer <= 0.0:
		_oneshot_timer = randf_range(28.0, 65.0)
		var roll := randf()
		var angle := randf() * TAU
		var spot := player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(22.0, 44.0) + Vector3(0, 4.0, 0)
		if _night > 0.55:
			if roll < 0.55:
				play_sfx_3d("owl", spot, -4.0, 70.0, 9.0, "Ambient")
			elif roll < 0.8:
				play_sfx_3d("wolf_howl", spot + Vector3(cos(angle), 0, sin(angle)) * 60.0, -2.0, 160.0, 14.0, "Ambient")
		elif _night < 0.45 and roll < 0.7:
			play_sfx_3d("crow", spot, -4.0, 70.0, 9.0, "Ambient")
	_bell_timer -= delta
	if _bell_timer <= 0.0:
		_bell_timer = randf_range(120.0, 220.0)
		play_sfx("distant_bell", -7.0, 0.01, false, "Ambient")


# --- SFX --------------------------------------------------------------------------------

func _get_streams(sfx_name: String) -> Array:
	if _streams.has(sfx_name):
		return _streams[sfx_name]
	var list: Array = []
	for path in AudioCatalog.sfx_paths(sfx_name):
		if ResourceLoader.exists(path):
			var stream := ResourceLoader.load(path) as AudioStream
			if stream:
				list.append(stream)
	if list.is_empty():
		push_warning("AudioManager: немає звуку '%s'" % sfx_name)
	_streams[sfx_name] = list
	return list


func _pick(sfx_name: String) -> AudioStream:
	var list := _get_streams(sfx_name)
	if list.is_empty():
		return null
	var index := randi() % list.size()
	if list.size() > 1 and index == int(_last_variant.get(sfx_name, -1)):
		index = (index + 1) % list.size()
	_last_variant[sfx_name] = index
	return list[index]


func play_sfx(sfx_name: String, volume_db: float = 0.0, pitch_jitter: float = 0.05, ui: bool = false, bus_name: String = "") -> void:
	var stream := _pick(sfx_name)
	if stream == null:
		return
	var p: AudioStreamPlayer
	if ui:
		p = _ui_pool[_ui_cursor]
		_ui_cursor = (_ui_cursor + 1) % _ui_pool.size()
	else:
		p = _sfx_pool[_sfx_cursor]
		_sfx_cursor = (_sfx_cursor + 1) % _sfx_pool.size()
	if not bus_name.is_empty():
		p.bus = bus_name
	else:
		p.bus = "UI" if ui else "SFX"
	p.stream = stream
	p.volume_db = volume_db + float(SFX_TRIM_DB.get(sfx_name, 0.0))
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func play_ui(sfx_name: String, volume_db: float = 0.0) -> void:
	play_sfx(sfx_name, volume_db, 0.02, true)


func play_sfx_3d(sfx_name: String, world_position: Vector3, volume_db: float = 0.0, max_distance: float = 45.0, unit_size: float = 6.0, bus_name: String = "SFX") -> void:
	var stream := _pick(sfx_name)
	var scene := get_tree().current_scene
	if stream == null or scene == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = bus_name
	p.volume_db = volume_db + float(SFX_TRIM_DB.get(sfx_name, 0.0))
	p.pitch_scale = 1.0 + randf_range(-0.05, 0.05)
	p.max_distance = max_distance
	p.unit_size = unit_size
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	scene.add_child(p)
	p.global_position = world_position
	p.finished.connect(p.queue_free)
	p.play()


func play_footstep(surface: String, sprinting: bool) -> void:
	var sfx_name := "step_" + surface
	if not AudioCatalog.SFX.has(sfx_name):
		sfx_name = "step_dirt"
	play_sfx(sfx_name, -2.5 if sprinting else -5.5, 0.07)


func play_hurt_voice() -> void:
	play_sfx("player_hurt", -1.0, 0.06)
