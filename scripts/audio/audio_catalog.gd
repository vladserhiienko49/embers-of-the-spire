class_name AudioCatalog
extends RefCounted
## Каталог згенерованих звуків Ashen Crown (tools/audio_synth.gd створює файли).
## Запис "ім'я": кількість варіантів. Файл: res://audio/sfx/<ім'я>_<n>.wav (або <ім'я>.wav, якщо варіант один).

const SFX: Dictionary = {
	# Кроки по поверхнях
	"step_grass": 4, "step_dirt": 4, "step_stone": 4, "step_wood": 4, "step_snow": 4, "step_water": 3,
	"land": 2,
	# Бій
	"sword_swing": 3, "hit_flesh": 3, "parry_ring": 2, "block_thud": 2, "player_hurt": 3,
	"wraith_growl": 2, "wraith_swing": 2, "wraith_hurt": 2, "wraith_death": 1,
	"bird_chirp": 2, "snake_hiss": 1, "cat_meow": 1, "cat_purr": 1, "bow_shot": 1, "bow_draw": 1, "arrow_hit": 1,
	"strange_whisper": 1, "strange_scrape": 1, "far_horn": 1,
	# Взаємодія та інтерфейс
	"ui_hover": 1, "ui_click": 1, "ui_back": 1, "ui_open": 1, "journal_open": 1, "dialogue_open": 1,
	"note_read": 1, "interact": 1, "coin": 2, "item_pickup": 1, "discover": 1,
	"quest_accept": 1, "quest_progress": 1, "quest_complete": 1, "torch_on": 1, "torch_off": 1,
	# Одноразові звуки природи
	"owl": 2, "wolf_howl": 1, "crow": 2, "distant_bell": 1,
}

## Старі файли проєкту використовуються як додаткові варіанти.
const LEGACY: Dictionary = {}

const AMBIENT: Dictionary = {
	"wind": "res://audio/ambient/amb_wind.wav",
	"night": "res://audio/ambient/amb_night.wav",
	"dungeon": "res://audio/ambient/amb_dungeon.wav",
	"fire": "res://audio/ambient/amb_fire.wav",
}

const MUSIC: Dictionary = {
	"explore": "res://audio/music/music_explore.wav",
	"dungeon": "res://audio/music/music_dungeon.wav",
	"combat": "res://audio/music/music_combat.wav",
	"boss": "res://audio/music/music_boss.wav",
	"mass": "res://audio/music/music_mass.wav",
	"menu": "res://audio/music/music_menu.wav",
}


## Фінальна композиція (світанок після перемоги над Стражем Ока).
const FINALE: String = "res://audio/music/music_finale.wav"


static func sfx_paths(sfx_name: String) -> Array[String]:
	var paths: Array[String] = []
	var count: int = int(SFX.get(sfx_name, 0))
	if count == 1:
		paths.append("res://audio/sfx/%s.wav" % sfx_name)
	else:
		for i in range(1, count + 1):
			paths.append("res://audio/sfx/%s_%d.wav" % [sfx_name, i])
	for legacy_path in LEGACY.get(sfx_name, []):
		paths.append(legacy_path)
	return paths
