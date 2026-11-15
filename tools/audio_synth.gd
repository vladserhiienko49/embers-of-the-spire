extends SceneTree
## Офлайн-синтезатор звуків Embers of the Spire (чистий GDScript, без зовнішніх ассетів).
## Запуск:  godot --headless --path . -s res://tools/audio_synth.gd
## Фільтр:  SYNTH_ONLY=sfx | ambient | music | finale  (змінна оточення)
## Усі звуки — 22050 Гц, 16 біт: це дає характерне «лоу-фай» звучання PS1.

const SR: int = 22050
const OUT: String = "res://audio"

var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	var only := OS.get_environment("SYNTH_ONLY")
	for sub in ["sfx", "ambient", "music"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "/" + sub))
	var started := Time.get_ticks_msec()
	if only == "" or only == "sfx":
		gen_sfx()
		print("SFX done in ", Time.get_ticks_msec() - started, " ms")
	if only == "" or only == "ambient":
		gen_ambient()
		print("AMBIENT done in ", Time.get_ticks_msec() - started, " ms")
	if only == "" or only == "music":
		gen_music()
		print("MUSIC done in ", Time.get_ticks_msec() - started, " ms")
	if only == "" or only == "finale":
		gen_finale()
		print("FINALE done in ", Time.get_ticks_msec() - started, " ms")
	if only == "cat":
		gen_cat_sfx()
	if only == "menu":
		gen_menu_intro()
	if only == "mass":
		gen_surprise_sfx()
		gen_mass()
		print("MASS done in ", Time.get_ticks_msec() - started, " ms")
	if only == "boss":
		gen_bow_sfx()
		gen_boss()
		print("BOSS done in ", Time.get_ticks_msec() - started, " ms")
	quit()


# =====================================================================================
# DSP-примітиви
# =====================================================================================

func nsamp(seconds: float) -> int:
	return int(seconds * float(SR))


func zeros(n: int) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(n)
	return a


func white(n: int, seed_value: int) -> PackedFloat32Array:
	rng.seed = seed_value
	var a := zeros(n)
	for i in range(n):
		a[i] = rng.randf() * 2.0 - 1.0
	return a


func lp(x: PackedFloat32Array, fc: float) -> PackedFloat32Array:
	var k := 1.0 - exp(-TAU * fc / float(SR))
	var y := 0.0
	var o := zeros(x.size())
	for i in range(x.size()):
		y += k * (x[i] - y)
		o[i] = y
	return o


func hp(x: PackedFloat32Array, fc: float) -> PackedFloat32Array:
	var l := lp(x, fc)
	var o := zeros(x.size())
	for i in range(x.size()):
		o[i] = x[i] - l[i]
	return o


func bp(x: PackedFloat32Array, fc: float, q: float) -> PackedFloat32Array:
	## Резонансний смуговий фільтр (Chamberlin SVF), підсилення ~ q.
	var f := 2.0 * sin(PI * clampf(fc, 20.0, 4600.0) / float(SR))
	var damp := 1.0 / maxf(q, 0.5)
	var low := 0.0
	var band := 0.0
	var o := zeros(x.size())
	for i in range(x.size()):
		low += f * band
		var high := x[i] - low - damp * band
		band += f * high
		o[i] = band * damp
	return o


func bp_sweep(x: PackedFloat32Array, f0: float, f1: float, q: float, power: float = 1.0) -> PackedFloat32Array:
	var n := x.size()
	var damp := 1.0 / maxf(q, 0.5)
	var low := 0.0
	var band := 0.0
	var o := zeros(n)
	for i in range(n):
		var fc := f0 + (f1 - f0) * pow(float(i) / float(n), power)
		var f := 2.0 * sin(PI * clampf(fc, 20.0, 4600.0) / float(SR))
		low += f * band
		var high := x[i] - low - damp * band
		band += f * high
		o[i] = band * damp
	return o


func lp_sweep(x: PackedFloat32Array, f0: float, f1: float) -> PackedFloat32Array:
	var n := x.size()
	var y := 0.0
	var o := zeros(n)
	for i in range(n):
		var fc := f0 + (f1 - f0) * float(i) / float(n)
		y += (1.0 - exp(-TAU * fc / float(SR))) * (x[i] - y)
		o[i] = y
	return o


func env(n: int, attack: float, decay: float) -> PackedFloat32Array:
	## Лінійна атака, далі експоненційний спад (секунди).
	var e := zeros(n)
	for i in range(n):
		var t := float(i) / float(SR)
		e[i] = t / attack if t < attack else exp(-(t - attack) / decay)
	return e


func mul(x: PackedFloat32Array, e: PackedFloat32Array) -> PackedFloat32Array:
	var o := zeros(x.size())
	for i in range(x.size()):
		o[i] = x[i] * e[i]
	return o


func gain(x: PackedFloat32Array, g: float) -> PackedFloat32Array:
	var o := zeros(x.size())
	for i in range(x.size()):
		o[i] = x[i] * g
	return o


func add_into(dest: PackedFloat32Array, src: PackedFloat32Array, start: int, g: float = 1.0, wrap: bool = false) -> void:
	var n := dest.size()
	for i in range(src.size()):
		var j := start + i
		if wrap:
			j = posmod(j, n)
		elif j < 0 or j >= n:
			continue
		dest[j] += src[i] * g


func mix2(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var o := zeros(maxi(a.size(), b.size()))
	for i in range(a.size()):
		o[i] += a[i]
	for i in range(b.size()):
		o[i] += b[i]
	return o


func peak(x: PackedFloat32Array) -> float:
	var p := 0.0
	for v in x:
		p = maxf(p, absf(v))
	return p


func normalize(x: PackedFloat32Array, target: float = 0.85) -> PackedFloat32Array:
	var p := peak(x)
	return x if p < 0.00001 else gain(x, target / p)


func fade_edges(x: PackedFloat32Array, in_s: float = 0.002, out_s: float = 0.01) -> PackedFloat32Array:
	var o := x.duplicate()
	var a := mini(nsamp(in_s), o.size())
	var b := mini(nsamp(out_s), o.size())
	for i in range(a):
		o[i] *= float(i) / float(a)
	for i in range(b):
		o[o.size() - 1 - i] *= float(i) / float(b)
	return o


func tone(freq: float, dur: float, decay: float, attack: float = 0.004, harm2: float = 0.0) -> PackedFloat32Array:
	var n := nsamp(dur)
	var o := zeros(n)
	var w := TAU * freq / float(SR)
	for i in range(n):
		var t := float(i) / float(SR)
		var e := (t / attack if t < attack else exp(-(t - attack) / decay))
		o[i] = (sin(w * i) + harm2 * sin(2.0 * w * i)) * e
	return o


func glide_tone(f0: float, f1: float, dur: float, decay: float, attack: float = 0.004, curve: float = 1.0) -> PackedFloat32Array:
	var n := nsamp(dur)
	var o := zeros(n)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / float(SR)
		var f := f0 + (f1 - f0) * pow(float(i) / float(n), curve)
		phase += TAU * f / float(SR)
		var e := (t / attack if t < attack else exp(-(t - attack) / decay))
		o[i] = sin(phase) * e
	return o


func bell(freq: float, dur: float, decay: float, bright: float = 1.0, inharmonic: bool = true) -> PackedFloat32Array:
	var ratios: Array = [1.0, 2.76, 5.40, 8.93] if inharmonic else [1.0, 2.0, 3.0, 4.0]
	var amps: Array = [1.0, 0.55 * bright, 0.3 * bright, 0.15 * bright]
	var decs: Array = [1.0, 0.6, 0.35, 0.2]
	var n := nsamp(dur)
	var o := zeros(n)
	for k in range(4):
		var f: float = freq * float(ratios[k])
		if f > 9000.0:
			continue
		var w := TAU * f / float(SR)
		var a: float = amps[k]
		var d: float = decay * float(decs[k])
		for i in range(n):
			var t := float(i) / float(SR)
			o[i] += a * sin(w * float(i)) * exp(-t / d) * minf(1.0, t / 0.002)
	return o


func saw_voice(freq: float, dur: float, lp_hz: float, attack: float, release: float, detune: float = 0.004) -> PackedFloat32Array:
	## Два детюновані пили → ФНЧ → амплітудна обвідка (атака/спад).
	var n := nsamp(dur)
	var o := zeros(n)
	var inc1 := freq * (1.0 - detune) / float(SR)
	var inc2 := freq * (1.0 + detune) / float(SR)
	var p1 := rng.randf()
	var p2 := rng.randf()
	var k := 1.0 - exp(-TAU * lp_hz / float(SR))
	var y := 0.0
	for i in range(n):
		p1 += inc1
		if p1 >= 1.0:
			p1 -= 1.0
		p2 += inc2
		if p2 >= 1.0:
			p2 -= 1.0
		y += k * ((p1 + p2) - 1.0 - y)
		var t := float(i) / float(SR)
		var e := minf(1.0, t / attack) * minf(1.0, (dur - t) / release)
		o[i] = y * e
	return o


func formant_voice(f0: float, f1: float, dur: float, formants: Array, vib_hz: float = 0.0, vib_depth: float = 0.0, glide_power: float = 1.0) -> PackedFloat32Array:
	## Пилоподібне джерело з ковзанням висоти → паралельні формантні фільтри.
	var n := nsamp(dur)
	var src := zeros(n)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / float(SR)
		var f := f0 + (f1 - f0) * pow(float(i) / float(n), glide_power)
		f += sin(TAU * vib_hz * t) * vib_depth * minf(1.0, t / 0.4)
		phase += f / float(SR)
		if phase >= 1.0:
			phase -= 1.0
		src[i] = phase * 2.0 - 1.0
	var out := zeros(n)
	for fm in formants:
		var band := bp(src, float(fm.x), float(fm.y))
		for i in range(n):
			out[i] += band[i]
	return out


func dup2(x: PackedFloat32Array) -> PackedFloat32Array:
	var o := zeros(x.size() * 2)
	for i in range(x.size()):
		o[i] = x[i]
		o[i + x.size()] = x[i]
	return o


func second_half(x: PackedFloat32Array) -> PackedFloat32Array:
	var n := x.size() / 2
	var o := zeros(n)
	for i in range(n):
		o[i] = x[n + i]
	return o


func _reverb_channel(x: PackedFloat32Array, spread: int, fb: float, damp: float) -> PackedFloat32Array:
	var n := x.size()
	var o := zeros(n)
	for base in [558, 594, 638, 678]:
		var length: int = int(base) + spread
		var line := zeros(length)
		var idx := 0
		var store := 0.0
		for i in range(n):
			var d := line[idx]
			store = d * (1.0 - damp) + store * damp
			line[idx] = x[i] + store * fb
			idx += 1
			if idx >= length:
				idx = 0
			o[i] += d
	for base in [112, 170]:
		var length: int = int(base) + spread / 3
		var line := zeros(length)
		var idx := 0
		for i in range(n):
			var b := line[idx]
			var v := o[i] + 0.5 * b
			line[idx] = v
			o[i] = b - 0.5 * v
			idx += 1
			if idx >= length:
				idx = 0
	return gain(o, 0.28)


func reverb(l: PackedFloat32Array, r: PackedFloat32Array, wet: float, fb: float = 0.84, damp: float = 0.35, loop: bool = false) -> Array:
	## Стерео-реверб Шредера. loop=true — безшовний хвіст для зациклених звуків.
	var li := dup2(l) if loop else l
	var ri := dup2(r) if loop else r
	var wl := _reverb_channel(li, 0, fb, damp)
	var wr := _reverb_channel(ri, 23, fb, damp)
	var ol := zeros(li.size())
	var orr := zeros(ri.size())
	for i in range(li.size()):
		ol[i] = li[i] + wl[i] * wet * 3.0
		orr[i] = ri[i] + wr[i] * wet * 3.0
	if loop:
		return [second_half(ol), second_half(orr)]
	return [ol, orr]


func reverb_mono(x: PackedFloat32Array, wet: float, fb: float = 0.7, damp: float = 0.4, tail: float = 0.0) -> PackedFloat32Array:
	var padded := x
	if tail > 0.0:
		padded = zeros(x.size() + nsamp(tail))
		for i in range(x.size()):
			padded[i] = x[i]
	var res := reverb(padded, padded, wet, fb, damp, false)
	var l: PackedFloat32Array = res[0]
	var r: PackedFloat32Array = res[1]
	var o := zeros(l.size())
	for i in range(l.size()):
		o[i] = (l[i] + r[i]) * 0.5
	return o


func echo_pingpong(l: PackedFloat32Array, r: PackedFloat32Array, delay_s: float, fb: float, wet: float, loop: bool = false) -> Array:
	var li := dup2(l) if loop else l
	var ri := dup2(r) if loop else r
	var d := nsamp(delay_s)
	var ol := li.duplicate()
	var orr := ri.duplicate()
	for i in range(d, li.size()):
		ol[i] += orr[i - d] * fb * wet + li[i - d] * 0.0
		orr[i] += ol[i - d] * fb * wet
	# Друга гілка: повернути чисте відлуння, а не лише мікс.
	if loop:
		return [second_half(ol), second_half(orr)]
	return [ol, orr]


func make_loop(raw: PackedFloat32Array, loop_len: int) -> PackedFloat32Array:
	## Безшовний цикл: хвіст (raw[loop_len..]) вкладається в початок з рівнопотужним кросфейдом.
	var xf := raw.size() - loop_len
	var o := zeros(loop_len)
	for i in range(loop_len):
		o[i] = raw[i]
	for i in range(xf):
		var s := float(i) / float(xf)
		o[i] = raw[i] * sin(s * PI * 0.5) + raw[loop_len + i] * cos(s * PI * 0.5)
	return o


func save(file_name: String, l: PackedFloat32Array, r: PackedFloat32Array = PackedFloat32Array()) -> void:
	var stereo := r.size() > 0
	var n := l.size()
	var bytes := PackedByteArray()
	bytes.resize(n * (4 if stereo else 2))
	for i in range(n):
		if stereo:
			bytes.encode_s16(i * 4, int(clampf(l[i], -1.0, 1.0) * 32767.0))
			bytes.encode_s16(i * 4 + 2, int(clampf(r[i], -1.0, 1.0) * 32767.0))
		else:
			bytes.encode_s16(i * 2, int(clampf(l[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SR
	wav.stereo = stereo
	wav.data = bytes
	var err := wav.save_to_wav(file_name)
	if err != OK:
		push_error("Не вдалося зберегти %s (%d)" % [file_name, err])
	else:
		print("  ", file_name.get_file(), "  ", snappedf(float(n) / float(SR), 0.01), " c  peak ", snappedf(peak(l), 0.01))


const LEVELS: Dictionary = {
	"ui_hover": 0.3, "ui_click": 0.5, "ui_back": 0.45, "ui_open": 0.55, "journal_open": 0.5, "note_read": 0.5, "dialogue_open": 0.55,
	"interact": 0.5, "coin": 0.5, "item_pickup": 0.55, "discover": 0.6, "quest_accept": 0.65, "quest_progress": 0.55, "quest_complete": 0.7,
	"torch_on": 0.5, "torch_off": 0.45, "owl": 0.5, "crow": 0.5, "wolf_howl": 0.55, "distant_bell": 0.55,
	"step_grass": 0.4, "step_dirt": 0.45, "step_stone": 0.45, "step_wood": 0.45, "step_snow": 0.4, "step_water": 0.45, "land": 0.55,
	"sword_swing": 0.5, "wraith_swing": 0.5, "hit_flesh": 0.85, "parry_ring": 0.8, "block_thud": 0.7, "player_hurt": 0.7,
}


func sfx(name: String, variant: int, x: PackedFloat32Array, count: int = 1) -> void:
	var file := "%s/sfx/%s.wav" % [OUT, name] if count == 1 else "%s/sfx/%s_%d.wav" % [OUT, name, variant]
	save(file, fade_edges(normalize(x, float(LEVELS.get(name, 0.8)))))


# =====================================================================================
# SFX
# =====================================================================================

func gen_sfx() -> void:
	for v in range(1, 5):
		sfx("step_grass", v, step_grass(100 + v), 4)
		sfx("step_dirt", v, step_dirt(200 + v), 4)
		sfx("step_stone", v, step_stone(300 + v), 4)
		sfx("step_wood", v, step_wood(400 + v), 4)
		sfx("step_snow", v, step_snow(500 + v), 4)
	for v in range(1, 4):
		sfx("step_water", v, step_splash(600 + v), 3)
		sfx("sword_swing", v, swing(700 + v, 700.0 + float(v) * 90.0, 2800.0 + float(v) * 300.0, 0.3), 3)
		sfx("hit_flesh", v, hit_flesh(800 + v), 3)
		sfx("player_hurt", v, player_hurt(900 + v, 118.0 - float(v) * 8.0), 3)
	for v in range(1, 3):
		sfx("land", v, land(1000 + v), 2)
		sfx("parry_ring", v, parry_ring(1100 + v, 1500.0 + float(v) * 260.0), 2)
		sfx("block_thud", v, block_thud(1200 + v), 2)
		sfx("wraith_growl", v, wraith_growl(1300 + v, 72.0 + float(v) * 14.0), 2)
		sfx("wraith_swing", v, swing(1400 + v, 260.0 + float(v) * 60.0, 1100.0, 0.42), 2)
		sfx("wraith_hurt", v, wraith_hurt(1500 + v, 340.0 + float(v) * 50.0), 2)
		sfx("owl", v, owl(1600 + v, 430.0 - float(v) * 40.0), 2)
		sfx("crow", v, crow(1700 + v), 2)
		sfx("coin", v, coin(1800 + v, 2400.0 + float(v) * 350.0), 2)
	sfx("wraith_death", 1, wraith_death())
	sfx("wolf_howl", 1, wolf_howl())
	sfx("distant_bell", 1, distant_bell())
	sfx("ui_hover", 1, ui_hover())
	sfx("ui_click", 1, ui_click())
	sfx("ui_back", 1, ui_back())
	sfx("ui_open", 1, ui_open())
	sfx("journal_open", 1, paper(2001, 0.42, 0.9))
	sfx("note_read", 1, paper(2002, 0.6, 0.6))
	sfx("dialogue_open", 1, dialogue_open())
	sfx("interact", 1, interact())
	sfx("item_pickup", 1, item_pickup())
	sfx("discover", 1, discover())
	sfx("quest_accept", 1, quest_accept())
	sfx("quest_progress", 1, quest_progress())
	sfx("quest_complete", 1, quest_complete())
	sfx("torch_on", 1, torch_on())
	sfx("torch_off", 1, torch_off())


func _thump(freq0: float, freq1: float, dur: float, decay: float) -> PackedFloat32Array:
	return glide_tone(freq0, freq1, dur, decay, 0.002, 0.5)


func step_grass(seed_value: int) -> PackedFloat32Array:
	rng.seed = seed_value
	var n := nsamp(0.24)
	var base := bp(white(n, seed_value), rng.randf_range(1500.0, 2300.0), 1.2)
	var body := mul(base, env(n, 0.012, 0.045))
	var rustle := mul(lp(hp(white(n, seed_value + 9), 1800.0), 4200.0), env(n, 0.04, 0.07))
	var thump := mul(tone(rng.randf_range(78.0, 96.0), 0.24, 0.035, 0.003), gain(env(n, 0.003, 0.04), 1.0))
	return mix2(mix2(gain(body, 1.0), gain(rustle, 0.35)), gain(thump, 0.55))


func step_dirt(seed_value: int) -> PackedFloat32Array:
	rng.seed = seed_value
	var n := nsamp(0.22)
	var o := mul(lp(white(n, seed_value), rng.randf_range(2000.0, 2800.0)), env(n, 0.002, 0.03))
	for g in range(16):
		var start := nsamp(rng.randf_range(0.0, 0.11))
		var grain := mul(bp(white(nsamp(0.006), seed_value * 7 + g), rng.randf_range(2400.0, 4200.0), 2.0), env(nsamp(0.006), 0.0005, 0.0018))
		add_into(o, grain, start, rng.randf_range(0.3, 0.7))
	return mix2(o, gain(mul(tone(rng.randf_range(90.0, 115.0), 0.22, 0.04), env(n, 0.003, 0.05)), 0.6))


func step_stone(seed_value: int) -> PackedFloat32Array:
	rng.seed = seed_value
	var n := nsamp(0.2)
	var click := mul(lp(hp(white(n, seed_value), 1100.0), 6500.0), env(n, 0.0008, 0.011))
	var slap := mul(bp(white(n, seed_value + 3), 2400.0, 2.0), env(n, 0.001, 0.03))
	var body := tone(rng.randf_range(130.0, 170.0), 0.2, 0.05, 0.002)
	var dry := mix2(mix2(click, gain(slap, 0.5)), gain(body, 0.5))
	return mix2(dry, gain(reverb_mono(dry, 0.5, 0.62, 0.5, 0.25), 0.7))


func step_wood(seed_value: int) -> PackedFloat32Array:
	rng.seed = seed_value
	var f := rng.randf_range(185.0, 235.0)
	var knock := glide_tone(f * 1.15, f, 0.22, 0.07, 0.002, 0.4)
	var overtone := glide_tone(f * 2.1, f * 1.9, 0.22, 0.04, 0.002, 0.4)
	var click := mul(bp(white(nsamp(0.22), seed_value), 1800.0, 2.0), env(nsamp(0.22), 0.001, 0.012))
	return mix2(mix2(knock, gain(overtone, 0.4)), gain(click, 0.55))


func step_snow(seed_value: int) -> PackedFloat32Array:
	rng.seed = seed_value
	var n := nsamp(0.28)
	var o := mul(lp(white(n, seed_value), 1500.0), env(n, 0.03, 0.06))
	o = gain(o, 0.4)
	for g in range(34):
		var start := nsamp(rng.randf_range(0.0, 0.17))
		var len := nsamp(0.004)
		var grain := mul(bp(white(len, seed_value * 5 + g), rng.randf_range(2200.0, 3800.0), 1.6), env(len, 0.0004, 0.0012))
		add_into(o, grain, start, rng.randf_range(0.25, 0.6))
	return o


func step_splash(seed_value: int) -> PackedFloat32Array:
	rng.seed = seed_value
	var n := nsamp(0.36)
	var wash := mul(bp_sweep(white(n, seed_value), 700.0, 2300.0, 1.4), env(n, 0.03, 0.11))
	for b in range(3):
		var bubble := glide_tone(rng.randf_range(450.0, 700.0), rng.randf_range(1200.0, 1800.0), 0.05, 0.02, 0.002)
		add_into(wash, bubble, nsamp(rng.randf_range(0.04, 0.22)), 0.25)
	return wash


func land(seed_value: int) -> PackedFloat32Array:
	var n := nsamp(0.3)
	var thud := _thump(110.0, 55.0, 0.3, 0.09)
	var dust := mul(lp(white(n, seed_value), 700.0), env(n, 0.002, 0.05))
	var jingle := mul(bp(white(n, seed_value + 4), 2600.0, 2.0), env(n, 0.001, 0.02))
	return mix2(mix2(thud, gain(dust, 0.9)), gain(jingle, 0.25))


func swing(seed_value: int, f0: float, f1: float, dur: float) -> PackedFloat32Array:
	var n := nsamp(dur)
	var sweep := bp_sweep(white(n, seed_value), f0, f1, 1.4, 1.5)
	var shape := zeros(n)
	for i in range(n):
		var s := float(i) / float(n)
		shape[i] = pow(sin(clampf(s, 0.0, 1.0) * PI), 1.6) * (0.4 + 0.6 * s)
	return mul(sweep, shape)


func hit_flesh(seed_value: int) -> PackedFloat32Array:
	var n := nsamp(0.34)
	var thump := _thump(135.0, 52.0, 0.34, 0.08)
	var slap := mul(lp(white(n, seed_value), 1900.0), env(n, 0.001, 0.025))
	var wet := mul(bp(white(n, seed_value + 5), 700.0, 2.2), env(n, 0.003, 0.07))
	var edge := mul(hp(white(n, seed_value + 8), 3500.0), env(n, 0.0005, 0.008))
	var dry := mix2(mix2(gain(thump, 0.9), gain(slap, 0.8)), mix2(gain(wet, 0.5), gain(edge, 0.25)))
	return mix2(dry, gain(reverb_mono(dry, 0.3, 0.6, 0.5, 0.2), 0.4))


func parry_ring(seed_value: int, base: float) -> PackedFloat32Array:
	var ring := bell(base, 1.4, 0.5, 1.3)
	var click := mul(hp(white(nsamp(1.4), seed_value), 2500.0), env(nsamp(1.4), 0.0005, 0.006))
	var dry := mix2(ring, gain(click, 0.7))
	return mix2(dry, gain(reverb_mono(dry, 0.35, 0.7, 0.4, 0.5), 0.5))


func block_thud(seed_value: int) -> PackedFloat32Array:
	var thump := _thump(150.0, 60.0, 0.3, 0.07)
	var metal := bell(880.0 + float(seed_value % 7) * 40.0, 0.3, 0.07, 1.0)
	var n := nsamp(0.3)
	var noise_hit := mul(lp(white(n, seed_value), 1600.0), env(n, 0.001, 0.02))
	return mix2(mix2(gain(thump, 0.9), gain(metal, 0.35)), gain(noise_hit, 0.5))


func player_hurt(seed_value: int, f: float) -> PackedFloat32Array:
	var v := formant_voice(f * 1.25, f * 0.8, 0.38, [Vector2(520.0, 5.0), Vector2(1050.0, 6.0)], 6.0, 4.0)
	var n := v.size()
	var breath := mul(bp(white(n, seed_value), 1500.0, 1.0), env(n, 0.01, 0.1))
	return mul(mix2(v, gain(breath, 0.3)), env(n, 0.012, 0.16))


func wraith_growl(seed_value: int, f: float) -> PackedFloat32Array:
	var dur := 1.0
	var v := formant_voice(f, f * 0.78, dur, [Vector2(380.0, 6.0), Vector2(720.0, 6.0), Vector2(1400.0, 3.0)], 5.0, 3.0)
	var n := v.size()
	var growl := zeros(n)
	for i in range(n):
		growl[i] = v[i] * (0.55 + 0.45 * sin(TAU * 26.0 * float(i) / float(SR)))
	var rasp := mul(bp(white(n, seed_value), 1200.0, 2.0), env(n, 0.15, 0.4))
	var o := mul(mix2(growl, gain(rasp, 0.5)), env(n, 0.18, 0.55))
	return mix2(o, gain(reverb_mono(o, 0.4, 0.75, 0.5, 0.6), 0.6))


func wraith_hurt(seed_value: int, f: float) -> PackedFloat32Array:
	var v := formant_voice(f * 1.3, f * 0.6, 0.5, [Vector2(900.0, 5.0), Vector2(1800.0, 4.0)], 7.0, 14.0)
	var n := v.size()
	var rasp := mul(bp(white(n, seed_value), 2000.0, 1.5), env(n, 0.01, 0.2))
	var o := mul(mix2(v, gain(rasp, 0.6)), env(n, 0.02, 0.22))
	return mix2(o, gain(reverb_mono(o, 0.4, 0.75, 0.5, 0.5), 0.5))


func wraith_death() -> PackedFloat32Array:
	var v := formant_voice(430.0, 55.0, 1.9, [Vector2(600.0, 5.0), Vector2(1100.0, 5.0), Vector2(2200.0, 3.0)], 6.0, 16.0, 0.7)
	var n := v.size()
	var rasp := mul(bp(white(n, 77), 1600.0, 1.2), env(n, 0.05, 0.6))
	var o := mul(mix2(v, gain(rasp, 0.5)), env(n, 0.04, 0.8))
	return mix2(o, gain(reverb_mono(o, 0.5, 0.82, 0.5, 1.5), 0.8))


func owl(seed_value: int, f: float) -> PackedFloat32Array:
	var n := nsamp(1.8)
	var o := zeros(n)
	for k in range(2):
		var start := nsamp(0.1 + float(k) * 0.62)
		var hoot := glide_tone(f * (1.06 - float(k) * 0.05), f * (0.9 - float(k) * 0.04), 0.4, 0.2, 0.07)
		var breath := mul(bp(white(nsamp(0.4), seed_value + k), 900.0, 3.0), env(nsamp(0.4), 0.07, 0.15))
		add_into(o, mix2(hoot, gain(breath, 0.22)), start, 1.0 - float(k) * 0.15)
	return mix2(o, gain(reverb_mono(o, 0.45, 0.78, 0.5, 1.0), 0.8))


func wolf_howl() -> PackedFloat32Array:
	var dur := 4.4
	var n := nsamp(dur)
	var src := zeros(n)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / float(SR)
		var f: float
		if t < 1.3:
			f = lerpf(250.0, 470.0, pow(t / 1.3, 0.8))
		elif t < 2.8:
			f = lerpf(470.0, 450.0, (t - 1.3) / 1.5)
		else:
			f = lerpf(450.0, 300.0, pow((t - 2.8) / 1.6, 1.3))
		f += sin(TAU * 5.4 * t) * 7.0 * clampf((t - 1.2) / 0.8, 0.0, 1.0)
		phase += f / float(SR)
		if phase >= 1.0:
			phase -= 1.0
		src[i] = phase * 2.0 - 1.0
	var voiced := bp(src, 900.0, 3.0)
	var voiced2 := bp(src, 1700.0, 2.5)
	var breath := lp(white(n, 321), 1500.0)
	var e := zeros(n)
	for i in range(n):
		var t := float(i) / float(SR)
		e[i] = minf(1.0, t / 0.6) * clampf((dur - t) / 1.3, 0.0, 1.0)
	var o := mul(mix2(mix2(voiced, gain(voiced2, 0.5)), gain(breath, 0.08)), e)
	return mix2(o, gain(reverb_mono(o, 0.6, 0.86, 0.5, 2.0), 0.9))


func crow(seed_value: int) -> PackedFloat32Array:
	rng.seed = seed_value
	var o := zeros(nsamp(1.6))
	for k in range(3):
		var f := rng.randf_range(650.0, 780.0)
		var v := formant_voice(f, f * 0.72, 0.26, [Vector2(1300.0, 3.0), Vector2(2200.0, 3.0)], 0.0, 0.0)
		var n := v.size()
		var rough := zeros(n)
		for i in range(n):
			rough[i] = v[i] * (0.6 + 0.4 * sin(TAU * 90.0 * float(i) / float(SR)))
		add_into(o, mul(rough, env(n, 0.015, 0.1)), nsamp(0.05 + float(k) * 0.42), 1.0)
	return mix2(o, gain(reverb_mono(o, 0.45, 0.75, 0.5, 0.8), 0.7))


func distant_bell() -> PackedFloat32Array:
	var strike := bell(175.0, 8.0, 3.8, 1.0)
	var n := strike.size()
	var thump := mul(lp(white(n, 31), 400.0), env(n, 0.001, 0.02))
	var dry := mix2(strike, gain(thump, 0.4))
	return mix2(dry, gain(reverb_mono(dry, 0.55, 0.88, 0.5, 2.0), 0.8))


func coin(seed_value: int, f: float) -> PackedFloat32Array:
	var a := bell(f, 0.5, 0.12, 1.2)
	var b := bell(f * 1.5, 0.5, 0.09, 1.0)
	var o := a.duplicate()
	add_into(o, b, nsamp(0.045), 0.7)
	return o


# --- Інтерфейс ------------------------------------------------------------------------

func ui_hover() -> PackedFloat32Array:
	var n := nsamp(0.06)
	var tick := mul(lp(hp(white(n, 11), 2200.0), 5000.0), env(n, 0.0005, 0.006))
	return mix2(gain(tick, 0.8), gain(tone(1250.0, 0.06, 0.012, 0.001), 0.35))


func ui_click() -> PackedFloat32Array:
	var n := nsamp(0.22)
	var thock := mul(lp(white(n, 12), 1200.0), env(n, 0.001, 0.02))
	var body := tone(210.0, 0.22, 0.045, 0.002)
	var chime := bell(880.0, 0.22, 0.09, 0.8, false)
	return mix2(mix2(gain(thock, 0.8), gain(body, 0.7)), gain(chime, 0.3))


func ui_back() -> PackedFloat32Array:
	var o := zeros(nsamp(0.3))
	add_into(o, tone(520.0, 0.14, 0.05, 0.002, 0.3), 0, 0.8)
	add_into(o, tone(390.0, 0.18, 0.07, 0.002, 0.3), nsamp(0.08), 0.8)
	return o


func ui_open() -> PackedFloat32Array:
	var n := nsamp(0.55)
	var whoosh := mul(lp_sweep(white(n, 13), 300.0, 1400.0), env(n, 0.16, 0.14))
	var low := mul(tone(80.0, 0.55, 0.2, 0.05), env(n, 0.05, 0.3))
	return mix2(gain(whoosh, 0.9), gain(low, 0.8))


func dialogue_open() -> PackedFloat32Array:
	var b := bell(147.0, 1.3, 0.7, 0.9)
	var shimmer := bell(588.0, 1.0, 0.35, 0.7, false)
	var dry := mix2(b, gain(shimmer, 0.3))
	return mix2(dry, gain(reverb_mono(dry, 0.35, 0.72, 0.5, 0.5), 0.6))


func paper(seed_value: int, dur: float, intensity: float) -> PackedFloat32Array:
	rng.seed = seed_value
	var n := nsamp(dur)
	var raw := hp(white(n, seed_value), 2500.0)
	var crinkle := zeros(n)
	var level := 0.0
	var target := 0.0
	for i in range(n):
		if i % 220 == 0:
			target = rng.randf() * rng.randf()
		level += (target - level) * 0.05
		crinkle[i] = level
	var shaped := mul(mul(raw, crinkle), env(n, 0.02, dur * 0.5))
	return mix2(gain(shaped, 3.0 * intensity), gain(mul(lp(white(n, seed_value + 1), 900.0), env(n, 0.05, 0.1)), 0.15))


func interact() -> PackedFloat32Array:
	var n := nsamp(0.14)
	return mix2(gain(mul(lp(white(n, 14), 900.0), env(n, 0.001, 0.025)), 0.9), gain(tone(180.0, 0.14, 0.04, 0.002), 0.7))


func item_pickup() -> PackedFloat32Array:
	var o := zeros(nsamp(0.7))
	var notes := [1760.0, 2349.0, 3136.0]
	for k in range(3):
		add_into(o, bell(float(notes[k]), 0.5, 0.11, 1.1, false), nsamp(0.045 * float(k)), 0.7)
	return mix2(o, gain(reverb_mono(o, 0.2, 0.6, 0.4, 0.3), 0.4))


func discover() -> PackedFloat32Array:
	var low := bell(196.0, 2.4, 1.1, 0.9)
	var mid := bell(392.0, 2.0, 0.7, 0.8, false)
	var shimmer := bell(1568.0, 1.6, 0.35, 0.6, false)
	var o := mix2(mix2(low, gain(mid, 0.5)), gain(shimmer, 0.25))
	return mix2(o, gain(reverb_mono(o, 0.45, 0.8, 0.5, 1.2), 0.7))


func quest_accept() -> PackedFloat32Array:
	var o := zeros(nsamp(1.6))
	var seq := [293.66, 440.0, 587.33]
	for k in range(3):
		add_into(o, bell(float(seq[k]), 1.1, 0.4, 1.0, false), nsamp(0.2 * float(k)), 0.7)
	var pad := saw_voice(146.83, 1.5, 700.0, 0.25, 0.9)
	add_into(o, pad, 0, 0.18)
	return normalize(mix2(o, gain(reverb_mono(o, 0.4, 0.8, 0.5, 1.2), 0.7)), 0.8)


func quest_progress() -> PackedFloat32Array:
	var o := zeros(nsamp(1.1))
	add_into(o, bell(659.25, 0.8, 0.25, 1.0, false), 0, 0.8)
	add_into(o, bell(880.0, 0.9, 0.3, 1.0, false), nsamp(0.13), 0.8)
	return mix2(o, gain(reverb_mono(o, 0.3, 0.7, 0.5, 0.5), 0.5))


func quest_complete() -> PackedFloat32Array:
	var o := zeros(nsamp(3.2))
	var seq := [293.66, 369.99, 440.0, 587.33]
	for k in range(4):
		add_into(o, bell(float(seq[k]), 1.8, 0.55, 1.0, false), nsamp(0.17 * float(k)), 0.65)
	for f in [146.83, 185.0, 220.0, 293.66]:
		add_into(o, saw_voice(float(f), 2.8, 900.0, 0.5, 1.4), nsamp(0.3), 0.12)
	return normalize(mix2(o, gain(reverb_mono(o, 0.5, 0.84, 0.5, 2.0), 0.8)), 0.8)


func torch_on() -> PackedFloat32Array:
	var n := nsamp(0.45)
	var fwoosh := mul(lp_sweep(white(n, 15), 300.0, 2600.0), env(n, 0.09, 0.14))
	var thump := mul(tone(70.0, 0.45, 0.1, 0.04), env(n, 0.02, 0.12))
	return mix2(gain(fwoosh, 0.9), gain(thump, 0.5))


func torch_off() -> PackedFloat32Array:
	var n := nsamp(0.3)
	var puff := mul(bp_sweep(white(n, 16), 2200.0, 500.0, 1.1), env(n, 0.01, 0.09))
	return gain(puff, 0.9)


# =====================================================================================
# Амбієнти
# =====================================================================================

func _save_stereo_normalized(file_name: String, pair: Array, target: float) -> void:
	var l: PackedFloat32Array = pair[0]
	var r: PackedFloat32Array = pair[1]
	var k := target / maxf(maxf(peak(l), peak(r)), 0.00001)
	save(file_name, gain(l, k), gain(r, k))


func gen_ambient() -> void:
	_save_stereo_normalized("%s/ambient/amb_wind.wav" % OUT, ambient_wind(), 0.7)
	_save_stereo_normalized("%s/ambient/amb_night.wav" % OUT, ambient_night(), 0.6)
	_save_stereo_normalized("%s/ambient/amb_dungeon.wav" % OUT, ambient_dungeon(), 0.7)
	save("%s/ambient/amb_fire.wav" % OUT, normalize(ambient_fire(), 0.7))

func _wind_channel(seed_value: int, loop_len: int, phase_shift: float) -> PackedFloat32Array:
	var n := loop_len + nsamp(3.0)
	var noise := white(n, seed_value)
	var state_low := 0.0
	var band := 0.0
	var res_low := 0.0
	var o := zeros(n)
	for i in range(n):
		var t := float(i) / float(SR)
		var gust := 0.5 + 0.5 * sin(TAU * 0.043 * t + phase_shift) * sin(TAU * 0.071 * t + phase_shift * 1.7)
		gust = clampf(gust * 1.6, 0.0, 1.0)
		var fc := 260.0 + 900.0 * gust
		state_low += (1.0 - exp(-TAU * fc / float(SR))) * (noise[i] - state_low)
		# Тонке «виття»: резонанс, що пливе по висоті.
		var fr := 2.0 * sin(PI * (360.0 + 160.0 * sin(TAU * 0.09 * t + phase_shift)) / float(SR))
		res_low += fr * band
		var high := noise[i] - res_low - 0.12 * band
		band += fr * high
		o[i] = (state_low * (0.35 + 0.65 * gust) + band * 0.045 * (0.3 + gust)) * 1.5
	return make_loop(o, loop_len)


func ambient_wind() -> Array:
	var loop_len := nsamp(24.0)
	return [_wind_channel(4101, loop_len, 0.0), _wind_channel(4102, loop_len, 1.3)]


func ambient_night() -> Array:
	var n := nsamp(20.0)
	var l := zeros(n)
	var r := zeros(n)
	rng.seed = 5150
	# Дві «зграї» цвіркунів: кожен має власну частоту, період і панораму.
	for c in range(7):
		var f := rng.randf_range(4200.0, 5300.0)
		var period := rng.randf_range(0.38, 0.62)
		var pan := rng.randf_range(0.1, 0.9)
		var phase_offset := rng.randf() * period
		var chirps := int(20.0 / period)
		for k in range(chirps):
			if rng.randf() < 0.25:
				continue
			var t0 := phase_offset + float(k) * period + rng.randf_range(-0.02, 0.02)
			for p in range(4):
				var plen := nsamp(0.013)
				var pulse := zeros(plen)
				var w := TAU * f / float(SR)
				for i in range(plen):
					pulse[i] = sin(w * float(i)) * sin(PI * float(i) / float(plen))
				var start := nsamp(t0 + float(p) * 0.026)
				add_into(l, pulse, start, 0.05 * (1.0 - pan), true)
				add_into(r, pulse, start, 0.05 * pan, true)
	var hum := lp(white(n, 5151), 220.0)
	for i in range(n):
		l[i] += hum[i] * 0.35
	var hum2 := lp(white(n, 5152), 220.0)
	for i in range(n):
		r[i] += hum2[i] * 0.35
	return [l, r]


func ambient_dungeon() -> Array:
	var n := nsamp(24.0)
	var rumble_l := lp(white(n, 6101), 110.0)
	var rumble_r := lp(white(n, 6102), 110.0)
	var l := zeros(n)
	var r := zeros(n)
	for i in range(n):
		var t := float(i) / float(SR)
		var swell := 0.55 + 0.45 * sin(TAU * t / 12.0)
		l[i] = rumble_l[i] * 2.6 * swell
		r[i] = rumble_r[i] * 2.6 * (1.0 - 0.2 * swell)
	# Краплі води.
	rng.seed = 6200
	for d in range(9):
		var f := rng.randf_range(850.0, 1600.0)
		var drop := glide_tone(f * 1.25, f, 0.09, 0.02, 0.001)
		var pan := rng.randf()
		var start := nsamp(rng.randf_range(0.5, 22.0))
		add_into(l, drop, start, 0.45 * (1.0 - pan), true)
		add_into(r, drop, start, 0.45 * pan, true)
	# Далекі металеві скрипи.
	for s in range(2):
		var creak := mul(bp_sweep(white(nsamp(1.6), 6300 + s), 700.0, 1300.0 + float(s) * 400.0, 10.0), env(nsamp(1.6), 0.5, 0.5))
		add_into(l, creak, nsamp(6.0 + float(s) * 11.0), 0.04, true)
		add_into(r, creak, nsamp(6.4 + float(s) * 11.0), 0.04, true)
	var res := reverb(l, r, 0.5, 0.87, 0.5, true)
	return [res[0], res[1]]


func ambient_fire() -> PackedFloat32Array:
	var n := nsamp(8.0)
	var o := zeros(n)
	var bed := lp(white(n, 7101), 420.0)
	var wobble := lp(white(n, 7102), 6.0)
	for i in range(n):
		o[i] = bed[i] * (0.5 + wobble[i] * 14.0) * 0.9
	rng.seed = 7103
	for c in range(52):
		var len := nsamp(rng.randf_range(0.003, 0.016))
		var snap := mul(bp(white(len, 7200 + c), rng.randf_range(1400.0, 4200.0), 2.0), env(len, 0.0004, rng.randf_range(0.001, 0.005)))
		add_into(o, snap, nsamp(rng.randf_range(0.0, 7.9)), rng.randf_range(0.2, 0.9), true)
	return o


# =====================================================================================
# Музика
# =====================================================================================

func gen_music() -> void:
	var explore := music_explore()
	save("%s/music/music_explore.wav" % OUT, explore[0], explore[1])
	var dungeon := music_dungeon()
	save("%s/music/music_dungeon.wav" % OUT, dungeon[0], dungeon[1])
	var combat := music_combat()
	save("%s/music/music_combat.wav" % OUT, combat[0], combat[1])


func _pan(l: PackedFloat32Array, r: PackedFloat32Array, voice: PackedFloat32Array, start: int, amp: float, pan: float) -> void:
	add_into(l, voice, start, amp * (1.0 - pan), true)
	add_into(r, voice, start, amp * pan, true)


func music_explore() -> Array:
	## 64 с, ре мінор: повільні падові акорди, низький дрон, дзвони з відлунням, примарний «хор».
	var total := 64.0
	var n := nsamp(total)
	var pad_l := zeros(n)
	var pad_r := zeros(n)
	var chords := [
		[146.83, 174.61, 220.0, 293.66],   # Dm
		[116.54, 146.83, 174.61, 233.08],  # Bb
		[98.0, 116.54, 146.83, 196.0],     # Gm
		[110.0, 138.59, 164.81, 220.0],    # A
	]
	rng.seed = 8001
	for c in range(4):
		var t0 := float(c) * 16.0 - 3.0
		var notes: Array = chords[c]
		for k in range(notes.size()):
			var v := saw_voice(float(notes[k]), 23.0, 780.0 + float(k) * 90.0, 5.0, 8.0)
			_pan(pad_l, pad_r, v, nsamp(t0), 0.055, 0.15 + 0.7 * float(k) / 3.0)
	# Низький дрон D2 із повільним тремоло.
	var drone := zeros(n)
	for i in range(n):
		var t := float(i) / float(SR)
		var trem := 0.75 + 0.25 * sin(TAU * t / 8.0)
		drone[i] = (sin(TAU * 73.4375 * t) + 0.7 * sin(TAU * 73.75 * t) + 0.25 * sin(TAU * 146.875 * t)) * 0.07 * trem
	# «Хор»: два найвищі голоси акорду крізь формантні фільтри.
	var choir_l := zeros(n)
	var choir_r := zeros(n)
	for c in range(4):
		var notes: Array = chords[c]
		for k in [2, 3]:
			var dur := 20.0
			var f: float = float(notes[k]) * 2.0
			var cv := formant_voice(f, f, dur, [Vector2(700.0, 6.0), Vector2(1100.0, 6.0), Vector2(2600.0, 3.0)], 5.2, 2.5)
			for i in range(cv.size()):
				var t := float(i) / float(SR)
				cv[i] *= minf(1.0, t / 6.0) * clampf((dur - t) / 7.0, 0.0, 1.0)
			_pan(choir_l, choir_r, cv, nsamp(float(c) * 16.0 - 2.0), 0.014, 0.3 + 0.4 * float(k - 2))
	# Дзвони: розріджена мелодія з нот поточного акорду.
	var bell_l := zeros(n)
	var bell_r := zeros(n)
	var tcur := 2.5
	var chord_index := 0
	var tones_by_chord := [
		[293.66, 349.23, 440.0, 587.33, 698.46],
		[233.08, 293.66, 349.23, 466.16, 587.33],
		[196.0, 233.08, 293.66, 392.0, 466.16],
		[220.0, 277.18, 329.63, 440.0, 554.37],
	]
	while tcur < total - 6.0:
		chord_index = clampi(int(tcur / 16.0), 0, 3)
		var pool: Array = tones_by_chord[chord_index]
		var f: float = float(pool[rng.randi_range(0, pool.size() - 1)])
		var b := bell(f, 7.0, 2.4, 1.0)
		_pan(bell_l, bell_r, b, nsamp(tcur), 0.08, rng.randf_range(0.25, 0.75))
		tcur += rng.randf_range(3.2, 6.4)
	var echoed := echo_pingpong(bell_l, bell_r, 0.62, 0.78, 0.55, true)
	var l := zeros(n)
	var r := zeros(n)
	for i in range(n):
		l[i] = pad_l[i] + drone[i] + choir_l[i] + echoed[0][i]
		r[i] = pad_r[i] + drone[i] + choir_r[i] + echoed[1][i]
	var wet := reverb(l, r, 0.34, 0.86, 0.4, true)
	var out_l: PackedFloat32Array = wet[0]
	var out_r: PackedFloat32Array = wet[1]
	var p := maxf(peak(out_l), peak(out_r))
	return [gain(out_l, 0.8 / p), gain(out_r, 0.8 / p)]


func music_dungeon() -> Array:
	## 48 с: глухий дрон, тремтливий кластер, повільне «серцебиття», низькі дзвони та скрипи.
	var total := 48.0
	var n := nsamp(total)
	var l := zeros(n)
	var r := zeros(n)
	var drone := zeros(n)
	for i in range(n):
		var t := float(i) / float(SR)
		var trem := 0.7 + 0.3 * sin(TAU * t / 6.0)
		drone[i] = (sin(TAU * 55.0 * t) + 0.8 * sin(TAU * 55.3333333 * t) + 0.3 * sin(TAU * 110.5 * t)) * 0.09 * trem
	var clusters := [[110.0, 116.54, 164.81], [98.0, 103.83, 146.83]]
	for c in range(2):
		var notes: Array = clusters[c]
		for k in range(notes.size()):
			var v := saw_voice(float(notes[k]), 30.0, 520.0, 8.0, 10.0, 0.006)
			_pan(l, r, v, nsamp(float(c) * 24.0 - 4.0), 0.05, 0.2 + 0.3 * float(k))
	# Серцебиття раз на 4 с.
	for beat in range(12):
		var t0 := float(beat) * 4.0 + 0.5
		var h1 := _thump(62.0, 38.0, 0.45, 0.14)
		var h2 := _thump(56.0, 36.0, 0.45, 0.12)
		_pan(l, r, h1, nsamp(t0), 0.28, 0.5)
		_pan(l, r, h2, nsamp(t0 + 0.34), 0.2, 0.5)
	# Низькі дзвони і скрипи.
	_pan(l, r, bell(82.41, 8.0, 3.5, 0.8), nsamp(9.0), 0.1, 0.4)
	_pan(l, r, bell(77.78, 8.0, 3.5, 0.8), nsamp(33.0), 0.1, 0.6)
	for s in range(2):
		var scrape := mul(bp_sweep(white(nsamp(2.4), 8300 + s), 1100.0, 2100.0, 9.0), env(nsamp(2.4), 0.8, 0.8))
		_pan(l, r, scrape, nsamp(19.0 + float(s) * 21.0), 0.05, 0.3 + 0.4 * float(s))
	for i in range(n):
		l[i] += drone[i]
		r[i] += drone[i]
	var wet := reverb(l, r, 0.5, 0.88, 0.5, true)
	var out_l: PackedFloat32Array = wet[0]
	var out_r: PackedFloat32Array = wet[1]
	var p := maxf(peak(out_l), peak(out_r))
	return [gain(out_l, 0.8 / p), gain(out_r, 0.8 / p)]


# =====================================================================================
# Фінальна композиція «Світанок над Попелом» (оригінальна, ~84 с + хвіст)
# Тривожний початок → гул → наростання чистих акордів → кульмінація на світанку (ре мажор).
# =====================================================================================

func gen_finale() -> void:
	var finale := music_finale()
	save("%s/music/music_finale.wav" % OUT, finale[0], finale[1])


func _put(l: PackedFloat32Array, r: PackedFloat32Array, voice: PackedFloat32Array, t_sec: float, amp: float, pan: float) -> void:
	var start := nsamp(t_sec)
	add_into(l, voice, start, amp * (1.0 - pan))
	add_into(r, voice, start, amp * pan)


func _pts(t: float, points: Array) -> float:
	## Кусково-лінійна обвідка: points = [[час, значення], ...].
	if t <= float(points[0][0]):
		return float(points[0][1])
	for i in range(1, points.size()):
		var t1: float = points[i][0]
		if t <= t1:
			var t0: float = points[i - 1][0]
			var k := (t - t0) / maxf(t1 - t0, 0.0001)
			return lerpf(float(points[i - 1][1]), float(points[i][1]), k)
	return float(points[points.size() - 1][1])


func _pad(l: PackedFloat32Array, r: PackedFloat32Array, notes: Array, t0: float, dur: float, lp_hz: float, amp: float, atk: float, rel: float) -> void:
	for k in range(notes.size()):
		var voice := saw_voice(float(notes[k]), dur, lp_hz + float(k) * 70.0, atk, rel, 0.005)
		_put(l, r, voice, t0, amp, 0.18 + 0.64 * float(k) / maxf(float(notes.size() - 1), 1.0))


func _choir(l: PackedFloat32Array, r: PackedFloat32Array, freq: float, t0: float, dur: float, amp: float, pan: float, fade_in: float, fade_out: float) -> void:
	var cv := formant_voice(freq, freq, dur, [Vector2(700.0, 6.0), Vector2(1150.0, 6.0), Vector2(2700.0, 3.0)], 5.0, freq * 0.004)
	for i in range(cv.size()):
		var t := float(i) / float(SR)
		cv[i] *= minf(1.0, t / fade_in) * clampf((dur - t) / fade_out, 0.0, 1.0)
	_put(l, r, cv, t0, amp, pan)


func music_finale() -> Array:
	var n := nsamp(92.0)
	var l := zeros(n)
	var r := zeros(n)
	rng.seed = 7742

	# 1. Глибокий дрон: D1 + D2 + D3, нестабільний на початку, світлий у кульмінації.
	var drone := zeros(n)
	var drone_env := [[0.0, 0.0], [7.0, 0.55], [30.0, 0.7], [57.0, 0.85], [60.0, 1.0], [78.0, 0.9], [90.0, 0.0]]
	for i in range(n):
		var t := float(i) / float(SR)
		var a := _pts(t, drone_env)
		var trem := 0.82 + 0.18 * sin(TAU * t / 7.0)
		var v := sin(TAU * 36.7083 * t) * 0.95 + sin(TAU * 73.4166 * t) * 0.5 + sin(TAU * 73.62 * t) * 0.28
		v += sin(TAU * 146.83 * t) * 0.14 * smoothstep(40.0, 60.0, t)
		drone[i] = v * a * trem * 0.105
	for i in range(n):
		l[i] += drone[i]
		r[i] += drone[i]

	# 2. Тривожне серцебиття (глухі удари) → пульс → бойові барабани кульмінації.
	var t_beat := 3.0
	while t_beat < 38.0:
		var amp := lerpf(0.16, 0.34, (t_beat - 3.0) / 35.0)
		_put(l, r, _thump(60.0, 36.0, 0.5, 0.15), t_beat, amp, 0.5)
		_put(l, r, _thump(54.0, 34.0, 0.5, 0.12), t_beat + 0.36, amp * 0.7, 0.5)
		t_beat += 4.0
	t_beat = 38.0
	while t_beat < 58.0:
		var k := (t_beat - 38.0) / 20.0
		_put(l, r, _thump(64.0, 38.0, 0.45, 0.14), t_beat, lerpf(0.3, 0.5, k), 0.5)
		t_beat += lerpf(1.6, 0.75, k)
	var tk := 58.0
	var beat_index := 0
	while tk < 76.0:
		_put(l, r, _taiko(86.0 if beat_index % 4 != 0 else 70.0, 0.22), tk, 0.55 if beat_index % 4 == 0 else 0.34, 0.5)
		tk += 0.75
		beat_index += 1

	# 3. Струнні: від низьких тривожних кластерів до яскравого ре мажору.
	_pad(l, r, [73.42, 77.78, 110.0], 0.0, 16.0, 380.0, 0.05, 6.0, 7.0)               # D, Eb, A — тривога
	_pad(l, r, [146.83, 174.61, 220.0], 10.0, 18.0, 520.0, 0.055, 6.0, 6.0)             # Dm
	_pad(l, r, [116.54, 146.83, 174.61, 233.08], 26.0, 14.0, 640.0, 0.055, 4.5, 5.0)    # Bb
	_pad(l, r, [174.61, 220.0, 261.63, 349.23], 38.0, 13.0, 820.0, 0.055, 4.0, 4.0)     # F
	_pad(l, r, [196.0, 233.08, 293.66, 392.0], 48.0, 12.0, 980.0, 0.06, 3.5, 3.5)       # Gm
	_pad(l, r, [146.83, 185.0, 220.0, 293.66, 369.99], 57.0, 18.0, 1700.0, 0.075, 1.2, 4.5)  # D мажор — світанок
	_pad(l, r, [73.42, 110.0, 146.83, 220.0, 293.66], 57.0, 18.0, 900.0, 0.06, 1.0, 5.0)
	_pad(l, r, [146.83, 185.0, 220.0, 293.66, 440.0], 74.0, 15.0, 1500.0, 0.06, 3.0, 8.0)   # фінальний D мажор
	_pad(l, r, [73.42, 110.0, 146.83], 74.0, 15.0, 700.0, 0.05, 3.0, 8.0)

	# 4. Мелодія: віолончельна тема надії (повільна), потім тема кульмінації у скрипок.
	var cello := [
		[18.0, 146.83, 5.0], [23.0, 220.0, 4.0], [27.0, 233.08, 5.0], [32.0, 220.0, 3.0],
		[35.0, 174.61, 4.5], [39.5, 220.0, 3.0], [42.5, 261.63, 5.0], [47.5, 293.66, 4.0],
		[51.5, 293.66, 3.0], [54.5, 329.63, 3.5],
	]
	for note in cello:
		var v := saw_voice(float(note[1]), float(note[2]) + 0.8, 760.0, 0.7, 1.2, 0.007)
		_put(l, r, v, float(note[0]), 0.12, 0.38)
	var lead := [
		[58.0, 369.99, 2.0], [60.0, 440.0, 2.0], [62.0, 587.33, 3.0], [65.0, 659.25, 1.5],
		[66.5, 739.99, 3.5], [70.0, 659.25, 1.5], [71.5, 587.33, 3.0], [74.5, 440.0, 3.0], [77.5, 587.33, 6.0],
	]
	for note in lead:
		var f: float = float(note[1])
		var dur: float = float(note[2])
		var v := saw_voice(f, dur + 0.7, 2400.0, 0.28, 0.9, 0.006)
		_put(l, r, v, float(note[0]), 0.1, 0.62)
		var v_low := saw_voice(f * 0.5, dur + 0.7, 1300.0, 0.3, 0.9, 0.004)
		_put(l, r, v_low, float(note[0]), 0.08, 0.35)
		_choir(l, r, f, float(note[0]), dur + 0.6, 0.02, 0.5, 0.5, 0.7)

	# 5. Хор «аа»: тихо вступає у середині й підіймається разом із сонцем.
	for c in [[40.0, 440.0], [40.0, 523.25], [48.0, 392.0], [48.0, 587.33]]:
		_choir(l, r, float(c[1]), float(c[0]), 10.0, 0.014, 0.3 + 0.4 * randf_range(0.0, 1.0), 4.0, 4.0)
	for c in [[57.0, 587.33, 0.3], [57.0, 739.99, 0.5], [57.0, 880.0, 0.7], [74.0, 587.33, 0.35], [74.0, 880.0, 0.65]]:
		_choir(l, r, float(c[1]), float(c[0]), 15.0, 0.022, float(c[2]), 2.5, 6.0)

	# 6. Дзвони та арпеджіо: поодинокі тривожні ноти → висхідні арпеджіо надії.
	var sparse := [[6.0, 146.83], [13.0, 110.0], [21.0, 233.08], [29.0, 293.66], [34.0, 440.0]]
	for b in sparse:
		_put(l, r, bell(float(b[1]), 8.0, 3.0, 0.9), float(b[0]), 0.07, 0.5)
	var arp_notes := [293.66, 349.23, 440.0, 523.25, 587.33, 698.46, 880.0]
	var ta := 36.0
	var ai := 0
	while ta < 57.0:
		var f2: float = float(arp_notes[ai % arp_notes.size()])
		_put(l, r, bell(f2, 4.0, 1.6, 0.8, false), ta, 0.06, 0.3 + 0.4 * float(ai % 3) / 2.0)
		ta += lerpf(1.5, 0.75, (ta - 36.0) / 21.0)
		ai += 1
	var d_major := [293.66, 369.99, 440.0, 587.33, 739.99, 880.0, 1174.66]
	ta = 58.0
	ai = 0
	while ta < 80.0:
		var f3: float = float(d_major[ai % d_major.size()])
		_put(l, r, bell(f3, 5.0, 2.0, 0.9, false), ta, 0.055, 0.25 + 0.5 * float(ai % 4) / 3.0)
		ta += 0.75
		ai += 1
	_put(l, r, bell(146.83, 12.0, 5.0, 1.0), 58.0, 0.18, 0.5)
	_put(l, r, bell(293.66, 12.0, 5.0, 1.0), 58.0, 0.12, 0.5)

	# 7. Наростання шуму перед світанком і тарілка на першому промені.
	var swell_n := nsamp(3.0)
	var swell := bp_sweep(white(swell_n, 5511), 700.0, 5200.0, 1.3)
	for i in range(swell_n):
		var k2 := float(i) / float(swell_n)
		swell[i] *= k2 * k2
	_put(l, r, swell, 55.0, 0.2, 0.5)
	_put(l, r, mul(hp(white(nsamp(4.0), 55), 3200.0), env(nsamp(4.0), 0.004, 1.2)), 58.0, 0.2, 0.5)

	var wet := reverb(l, r, 0.3, 0.87, 0.42, false)
	var out_l: PackedFloat32Array = wet[0]
	var out_r: PackedFloat32Array = wet[1]
	var p := maxf(peak(out_l), peak(out_r))
	var g := 0.86 / maxf(p, 0.0001)
	for i in range(n):
		var t2 := float(i) / float(SR)
		var edge := minf(1.0, t2 / 2.5) * clampf((91.0 - t2) / 6.0, 0.0, 1.0)
		out_l[i] *= g * edge
		out_r[i] *= g * edge
	return [out_l, out_r]

# =====================================================================================
# Бойова тема фінального боса «Око прокинулось» (оригінальна, 48 с, зациклена)
# Ре мінор, 120 уд./хв: тайко, галопуючий бас, мідні акорди, хор і висхідна тема.
# =====================================================================================

func gen_bow_sfx() -> void:
	var twang := mix2(glide_tone(190.0, 118.0, 0.38, 0.09, 0.001, 0.6), gain(swing(1950, 1800.0, 5200.0, 0.22), 0.7))
	sfx("bow_shot", 1, twang)
	var creak_n := nsamp(0.6)
	sfx("bow_draw", 1, mul(bp_sweep(white(creak_n, 1951), 280.0, 880.0, 4.0), env(creak_n, 0.22, 0.3)))
	var thud_n := nsamp(0.12)
	sfx("arrow_hit", 1, mix2(glide_tone(210.0, 90.0, 0.14, 0.04, 0.001, 0.5), gain(mul(hp(white(thud_n, 1952), 1500.0), env(thud_n, 0.001, 0.03)), 0.5)))


func gen_cat_sfx() -> void:
	var meow := zeros(nsamp(0.7))
	add_into(meow, glide_tone(520.0, 880.0, 0.2, 0.12, 0.02, 0.8), 0, 0.8)
	add_into(meow, glide_tone(880.0, 430.0, 0.45, 0.3, 0.01, 1.2), nsamp(0.16), 0.9)
	add_into(meow, glide_tone(1760.0, 860.0, 0.45, 0.25, 0.01, 1.2), nsamp(0.16), 0.25)
	sfx("cat_meow", 1, lp(meow, 3200.0))
	var n := nsamp(1.8)
	var purr := lp(white(n, 2020), 380.0)
	for i in range(n):
		var t := float(i) / float(SR)
		var pulse := 0.55 + 0.45 * sin(TAU * 24.0 * t)
		purr[i] *= pulse * minf(1.0, t / 0.2) * clampf((1.8 - t) / 0.3, 0.0, 1.0)
	sfx("cat_purr", 1, purr)
	var hn := nsamp(0.9)
	var hiss := hp(white(hn, 2121), 2800.0)
	for i in range(hn):
		var t2 := float(i) / float(SR)
		hiss[i] *= minf(1.0, t2 / 0.08) * clampf((0.9 - t2) / 0.5, 0.0, 1.0) * (0.75 + 0.25 * sin(TAU * 11.0 * t2))
	sfx("snake_hiss", 1, hiss)
	for v in range(1, 3):
		var chirp := zeros(nsamp(0.5))
		var notes := [[0.0, 2600.0, 3600.0], [0.12, 3100.0, 4200.0], [0.26, 2800.0, 3900.0]] if v == 1 else [[0.0, 3400.0, 2600.0], [0.1, 3600.0, 2900.0], [0.2, 3900.0, 3100.0], [0.3, 4200.0, 3300.0]]
		for nt in notes:
			add_into(chirp, glide_tone(float(nt[1]), float(nt[2]), 0.09, 0.04, 0.004, 0.6), nsamp(float(nt[0])), 0.8)
		sfx("bird_chirp", v, chirp, 2)


func gen_boss() -> void:
	var boss := music_boss()
	save("%s/music/music_boss.wav" % OUT, boss[0], boss[1])


func music_boss() -> Array:
	rng.seed = 90210
	var beat := 0.5
	var bar := beat * 4.0
	var total := bar * 24.0
	var n := nsamp(total)
	var l := zeros(n)
	var r := zeros(n)
	var chords := [
		{"root": 73.42, "notes": [146.83, 174.61, 220.0, 293.66]},    # Dm
		{"root": 58.27, "notes": [116.54, 146.83, 174.61, 233.08]},   # Bb
		{"root": 98.0, "notes": [196.0, 233.08, 293.66, 392.0]},      # Gm
		{"root": 55.0, "notes": [110.0, 138.59, 164.81, 220.0]},      # A (домінанта)
	]
	var kick_hi := _taiko(96.0, 0.26)
	var kick_lo := _taiko(66.0, 0.34)
	var hat := mul(hp(white(nsamp(0.06), 301), 6500.0), env(nsamp(0.06), 0.001, 0.02))
	for cycle in range(3):
		var cycle_t := float(cycle) * bar * 8.0
		# Тарілка на початку кожного циклу.
		var crash := mul(hp(white(nsamp(2.6), 400 + cycle), 3000.0), env(nsamp(2.6), 0.003, 0.9))
		_pan(l, r, crash, nsamp(cycle_t), 0.2 + 0.05 * float(cycle), 0.5)
		for c in range(4):
			var chord: Dictionary = chords[c]
			var root: float = chord["root"]
			var notes: Array = chord["notes"]
			for b in range(2):
				var bar_t := cycle_t + (float(c) * 2.0 + float(b)) * bar
				# Тайко: сильна доля, «і» третьої, четверта.
				_pan(l, r, kick_lo, nsamp(bar_t), 0.62, 0.5)
				_pan(l, r, kick_hi, nsamp(bar_t + 2.0 * beat), 0.46, 0.42)
				_pan(l, r, kick_hi, nsamp(bar_t + 2.5 * beat), 0.3, 0.58)
				_pan(l, r, kick_lo, nsamp(bar_t + 3.0 * beat), 0.4, 0.5)
				if cycle >= 1:
					_pan(l, r, kick_hi, nsamp(bar_t + 1.0 * beat), 0.28, 0.4)
					for h in range(8):
						_pan(l, r, hat, nsamp(bar_t + float(h) * beat * 0.5 + beat * 0.25), 0.07, 0.3 + 0.4 * float(h % 2))
				# Галопуючий бас по восьмих.
				for e in range(8):
					var ratio := 1.0 if e not in [2, 5] else 2.0
					if e == 7 and c == 3:
						ratio = 1.1225
					var pluck := saw_voice(root * ratio, 0.3, 560.0, 0.004, 0.18)
					var acc := 1.0 if e % 4 == 0 else 0.62
					_pan(l, r, pluck, nsamp(bar_t + float(e) * beat * 0.5), 0.17 * acc, 0.5)
				# Мідні: довга нота у першому циклі, різкі удари далі.
				if cycle == 0:
					if b == 0:
						for f in notes:
							_pan(l, r, saw_voice(float(f), bar * 2.0 + 0.3, 760.0, 0.5, 0.9, 0.006), nsamp(bar_t), 0.05, 0.3 + 0.4 * float(f > 200.0))
				else:
					for f in notes:
						_pan(l, r, saw_voice(float(f), 0.55, 1900.0, 0.01, 0.25, 0.006), nsamp(bar_t), 0.06, 0.3 + 0.4 * float(f > 200.0))
						_pan(l, r, saw_voice(float(f), 0.4, 1700.0, 0.01, 0.2, 0.006), nsamp(bar_t + 2.5 * beat), 0.04, 0.3 + 0.4 * float(f > 200.0))
				# Хор на останньому циклі: довгі голоси над акордом.
				if cycle == 2 and b == 0:
					for fi in range(notes.size()):
						_choir(l, r, float(notes[fi]) * 2.0, bar_t, bar * 2.0 + 0.6, 0.02, 0.25 + 0.5 * float(fi) / 3.0, 0.6, 0.9)
	# Тема: 4 фрази (у кожній — акорд на 2 такти); у другому циклі — основна, у третьому — октавою вище.
	var theme := [
		[0.0, 440.0, 2.0], [2.0, 587.33, 1.0], [3.0, 698.46, 1.0], [4.0, 659.25, 2.0], [6.0, 587.33, 2.0],
		[8.0, 466.16, 2.0], [10.0, 587.33, 1.0], [11.0, 698.46, 1.0], [12.0, 587.33, 2.0], [14.0, 523.25, 2.0],
		[16.0, 587.33, 2.0], [18.0, 698.46, 1.0], [19.0, 784.0, 1.0], [20.0, 698.46, 2.0], [22.0, 587.33, 2.0],
		[24.0, 554.37, 2.0], [26.0, 659.25, 1.0], [27.0, 587.33, 1.0], [28.0, 554.37, 2.0], [30.0, 440.0, 2.0],
	]
	for cycle in [1, 2]:
		var octave := 1.0 if cycle == 1 else 2.0
		var cycle_t2 := float(cycle) * bar * 8.0
		for note in theme:
			var dur: float = float(note[2]) * beat
			var f: float = float(note[1]) * octave * (0.5 if cycle == 1 else 1.0)
			var voice := saw_voice(f, dur + 0.25, 2600.0, 0.03, 0.25, 0.006)
			_pan(l, r, voice, nsamp(cycle_t2 + float(note[0]) * beat), 0.085, 0.62)
			if cycle == 2:
				_pan(l, r, saw_voice(f * 0.5, dur + 0.25, 1400.0, 0.03, 0.25, 0.005), nsamp(cycle_t2 + float(note[0]) * beat), 0.06, 0.38)
	# Підйоми перед кожним новим циклом.
	for cycle in range(3):
		var end_t := (float(cycle) + 1.0) * bar * 8.0
		var riser_n := nsamp(bar * 1.0)
		var riser := bp_sweep(white(riser_n, 800 + cycle), 500.0, 6000.0, 1.2)
		for i in range(riser_n):
			var k := float(i) / float(riser_n)
			riser[i] *= k * k
		_pan(l, r, riser, nsamp(end_t - bar * 1.0), 0.16, 0.5)
		for k in range(8):
			_pan(l, r, kick_hi, nsamp(end_t - beat * 2.0 + float(k) * beat * 0.25), 0.18 + 0.05 * float(k), 0.5)
	var wet := reverb(l, r, 0.18, 0.8, 0.45, true)
	var out_l: PackedFloat32Array = wet[0]
	var out_r: PackedFloat32Array = wet[1]
	var p := maxf(peak(out_l), peak(out_r))
	var g := 0.86 / maxf(p, 0.0001)
	return [gain(out_l, g), gain(out_r, g)]


func _taiko(freq0: float, decay: float) -> PackedFloat32Array:
	var n := nsamp(0.7)
	var body := glide_tone(freq0, freq0 * 0.42, 0.7, decay, 0.002, 0.35)
	var skin := mul(bp(white(n, 91), 900.0, 2.0), env(n, 0.001, 0.03))
	return mix2(body, gain(skin, 0.35))


func music_combat() -> Array:
	## 30 с, 96 уд./хв: бойові тайко, пульсуючий бас, дисонансні акорди (тритон).
	var beat := 60.0 / 96.0
	var total := beat * 48.0
	var n := nsamp(total)
	var l := zeros(n)
	var r := zeros(n)
	var kick := _taiko(120.0, 0.22)
	var kick_low := _taiko(90.0, 0.3)
	for bar in range(12):
		var t0 := float(bar) * 4.0 * beat
		_pan(l, r, kick, nsamp(t0), 0.55, 0.5)
		_pan(l, r, kick_low, nsamp(t0 + 2.0 * beat), 0.42, 0.5)
		_pan(l, r, kick_low, nsamp(t0 + 2.5 * beat), 0.22, 0.45)
		if bar % 4 == 3:
			# Підхід перед новою фразою: швидкі удари.
			for k in range(6):
				_pan(l, r, kick, nsamp(t0 + 3.0 * beat + float(k) * beat / 6.0 * 2.0 / 2.0), 0.28 + 0.05 * float(k), 0.35 + 0.06 * float(k))
	# Бас-остинато по 8-х (фрігійський лад).
	var bass := [73.42, 73.42, 73.42, 87.31, 73.42, 73.42, 77.78, 73.42]
	var eighth := beat / 2.0
	for step in range(96):
		var f: float = float(bass[step % 8])
		var pluck := saw_voice(f, 0.34, 520.0, 0.004, 0.2)
		var accent := 1.0 if step % 8 == 0 else 0.62
		_pan(l, r, pluck, nsamp(float(step) * eighth), 0.2 * accent, 0.5)
	# Дисонансні «струни» на початку кожних двох тактів.
	for bar in range(0, 12, 2):
		var t0 := float(bar) * 4.0 * beat
		for f in [146.83, 207.65, 220.0]:
			var stab := saw_voice(float(f), 2.2, 1500.0, 0.03, 1.4, 0.007)
			_pan(l, r, stab, nsamp(t0), 0.085, 0.3 + 0.4 * float(f > 200.0))
	var wet := reverb(l, r, 0.2, 0.78, 0.5, true)
	var out_l: PackedFloat32Array = wet[0]
	var out_r: PackedFloat32Array = wet[1]
	var p := maxf(peak(out_l), peak(out_r))
	return [gain(out_l, 0.85 / p), gain(out_r, 0.85 / p)]


# =====================================================================================
# Масовий бій: оригінальний індустріальний метал (Мі фрігійський, 140 уд./хв, 24 такти, цикл)
# Власний рифф, ритм і звук: перегазована гітара-«цеглина», подвійна бочка, ковадла та
# металевий лязг, сабсинтезатор і сирена-«тривога». Жодної мелодії/вокалу з чужих пісень.
# =====================================================================================

func _dist(x: PackedFloat32Array, drive: float) -> PackedFloat32Array:
	var o := zeros(x.size())
	for i in range(x.size()):
		var v := x[i] * drive
		o[i] = v / (1.0 + absf(v)) * 0.5 + tanh(v * 0.8) * 0.5
	return o


func _anvil(seed_value: int, freq: float) -> PackedFloat32Array:
	## Індустріальний лязг: коротка нев'язка з металевими обертонами + стрибок шуму.
	var n := nsamp(0.45)
	var ring := bell(freq, 0.45, 0.16, 1.4, true)
	var clang := mul(bp(white(n, seed_value), freq * 3.1, 3.0), env(n, 0.0005, 0.05))
	return mix2(ring, gain(clang, 0.8))


func _snare_ind(seed_value: int) -> PackedFloat32Array:
	var n := nsamp(0.5)
	var body := glide_tone(240.0, 130.0, 0.5, 0.07, 0.0008, 0.5)
	var crack := mul(hp(white(n, seed_value), 1400.0), env(n, 0.0005, 0.1))
	var metal := mul(bp(white(n, seed_value + 7), 3200.0, 2.0), env(n, 0.0005, 0.16))
	return mix2(mix2(body, gain(crack, 0.9)), gain(metal, 0.45))


func music_mass() -> Array:
	rng.seed = 140140
	var beat := 60.0 / 140.0
	var sx := beat / 4.0                    # шістнадцята
	var bars := 24
	var bar := beat * 4.0
	var total := bar * float(bars)
	var n := nsamp(total)
	var dl := zeros(n)   # ударні
	var dr := zeros(n)
	var gl := zeros(n)   # гітари (потім перегаз)
	var gr := zeros(n)
	var bl := zeros(n)   # бас/саб
	var br := zeros(n)
	var yl := zeros(n)   # синтезатор/сирена
	var yr := zeros(n)

	var kick := mix2(glide_tone(135.0, 38.0, 0.5, 0.11, 0.0008, 0.3), gain(mul(hp(white(nsamp(0.03), 11), 2500.0), env(nsamp(0.03), 0.0003, 0.008)), 0.6))
	var kick2 := mix2(glide_tone(110.0, 42.0, 0.35, 0.07, 0.0008, 0.3), gain(mul(hp(white(nsamp(0.025), 12), 3000.0), env(nsamp(0.025), 0.0003, 0.006)), 0.4))
	var snare_a := _snare_ind(21)
	var snare_b := _snare_ind(22)
	var hat := mul(hp(white(nsamp(0.05), 31), 7000.0), env(nsamp(0.05), 0.0004, 0.014))
	var hat_o := mul(hp(white(nsamp(0.22), 32), 6000.0), env(nsamp(0.22), 0.0006, 0.07))
	var anvils := [_anvil(41, 520.0), _anvil(42, 610.0), _anvil(43, 392.0)]
	var crash := mul(hp(white(nsamp(2.4), 51), 2800.0), env(nsamp(2.4), 0.002, 0.8))

	# Тони рифу у піввисотах від E2 (82.41 Гц): 0, 1 (b2), 3, 6 (тритон), 7.
	var e2 := 82.41
	var riffs := [
		[0, 0, -1, 0, 0, -1, 0, 0, 1, -1, 0, 0, -1, 0, 3, -1],        # A: «жорна»
		[0, 0, 0, -1, 0, 0, 6, -1, 5, -1, 0, 0, 1, -1, 0, -1],        # B: з тритоном
		[0, -1, 0, 0, 3, -1, 3, 0, 0, -1, 6, 6, 5, -1, 1, 0],         # C: стрибки
		[0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0],             # D: суцільний «каток»
	]
	var chug_cache := {}
	var sub_cache := {}
	for bar_i in range(bars):
		var t0 := float(bar_i) * bar
		var section := bar_i / 8                 # 0: тема, 1: наростання, 2: апогей
		var riff_id: int = [0, 1, 0, 2, 0, 1, 2, 3][bar_i % 8]
		if section == 0 and bar_i % 8 < 2:
			riff_id = 0
		var riff: Array = riffs[riff_id]
		if bar_i % 8 == 0:
			_pan(dl, dr, crash, nsamp(t0), 0.22, 0.5)
		# --- Бочка: чотири долі; у секціях 1–2 подвійна по шістнадцятих на кінці такту.
		for b in range(4):
			_pan(dl, dr, kick, nsamp(t0 + float(b) * beat), 0.62, 0.5)
		_pan(dl, dr, kick2, nsamp(t0 + 2.5 * beat), 0.42, 0.5)
		if section >= 1:
			for k in range(8):
				_pan(dl, dr, kick2, nsamp(t0 + 3.0 * beat + float(k) * sx * 0.5), 0.26, 0.5)
		if section == 2 and bar_i % 2 == 0:
			for k in range(8):
				_pan(dl, dr, kick2, nsamp(t0 + 1.0 * beat + float(k) * sx * 0.5), 0.2, 0.5)
		# --- Малий барабан на 2 і 4; ковадло на «і» третьої.
		_pan(dl, dr, snare_a, nsamp(t0 + beat), 0.5, 0.45)
		_pan(dl, dr, snare_b, nsamp(t0 + 3.0 * beat), 0.5, 0.55)
		_pan(dl, dr, anvils[bar_i % 3], nsamp(t0 + 2.5 * beat), 0.22, 0.3 + 0.4 * float(bar_i % 2))
		if section >= 1:
			_pan(dl, dr, anvils[(bar_i + 1) % 3], nsamp(t0 + 0.5 * beat), 0.16, 0.7 - 0.4 * float(bar_i % 2))
		# --- Хет по шістнадцятих.
		for h in range(16):
			var h_amp := 0.075 if h % 4 == 0 else 0.045
			_pan(dl, dr, hat if h != 14 else hat_o, nsamp(t0 + float(h) * sx), h_amp, 0.3 + 0.4 * float(h % 2))
		# --- Гітара: «цегла» по рифу (палм-мют) + акорд-удар на початку такту.
		for step in range(16):
			var semis: int = int(riff[step])
			if semis < 0:
				continue
			var f := e2 * pow(2.0, float(semis) / 12.0)
			if not chug_cache.has(semis):
				chug_cache[semis] = saw_voice(f, 0.2, 2100.0, 0.002, 0.07, 0.006)
			var acc := 1.0 if step % 4 == 0 else 0.7
			_pan(gl, gr, chug_cache[semis], nsamp(t0 + float(step) * sx), 0.34 * acc, 0.22)
			_pan(gl, gr, chug_cache[semis], nsamp(t0 + float(step) * sx + 0.004), 0.34 * acc, 0.78)
		if bar_i % 4 == 0:
			var stab := saw_voice(e2 * 2.0, beat * 1.6, 2600.0, 0.003, 0.5, 0.01)
			var stab5 := saw_voice(e2 * 3.0, beat * 1.6, 2600.0, 0.003, 0.5, 0.01)
			_pan(gl, gr, stab, nsamp(t0), 0.3, 0.3)
			_pan(gl, gr, stab5, nsamp(t0), 0.26, 0.7)
		# --- Бас: довга нота кореня й підкид по рифу; саб-синус під бочкою.
		var root_semi := 0
		if riff_id == 2 and bar_i % 2 == 1:
			root_semi = 1
		var rf := e2 * pow(2.0, float(root_semi) / 12.0) * 0.5
		if not sub_cache.has(root_semi):
			sub_cache[root_semi] = mix2(tone(rf, bar * 0.95, 1.6, 0.01, 0.35), gain(saw_voice(rf * 2.0, bar * 0.95, 380.0, 0.01, 0.1, 0.005), 0.35))
		_pan(bl, br, sub_cache[root_semi], nsamp(t0), 0.52, 0.5)
		# --- Сирена-«тривога»: тритон, що тягнеться, у секціях 1–2.
		if section >= 1 and bar_i % 2 == 0:
			var siren := saw_voice(e2 * 8.0 * (1.0 if section == 1 else 1.5), bar * 1.9, 1700.0, 0.4, 0.8, 0.012)
			_pan(yl, yr, siren, nsamp(t0), 0.07 if section == 1 else 0.1, 0.25)
			_pan(yl, yr, saw_voice(e2 * 8.0 * 1.4142 * (1.0 if section == 1 else 1.5), bar * 1.9, 1700.0, 0.4, 0.8, 0.012), nsamp(t0), 0.07 if section == 1 else 0.1, 0.75)
		# --- Метроном заводу: удар по залізу на кожній першій долі апогею.
		if section == 2:
			_pan(dl, dr, anvils[2], nsamp(t0), 0.28, 0.5)
		# --- Перехід: перед новою секцією — наростання шуму й тріск малого.
		if bar_i % 8 == 7:
			var rn := nsamp(bar * 0.5)
			var riser := bp_sweep(white(rn, 700 + bar_i), 400.0, 7000.0, 1.4)
			for i in range(rn):
				var k := float(i) / float(rn)
				riser[i] *= k * k
			_pan(yl, yr, riser, nsamp(t0 + bar * 0.5), 0.2, 0.5)
			for k in range(8):
				_pan(dl, dr, snare_a, nsamp(t0 + 3.0 * beat + float(k) * sx * 0.5 * 2.0), 0.28 + 0.04 * float(k), 0.5)

	# Перегаз гітар + шапка вище 4 кГц, щоб не різало; бас окремо легко «брудниться».
	var gdl := lp(_dist(gl, 7.0), 4200.0)
	var gdr := lp(_dist(gr, 7.0), 4200.0)
	var bdl := _dist(bl, 1.8)
	var bdr := _dist(br, 1.8)
	var out_l := zeros(n)
	var out_r := zeros(n)
	for i in range(n):
		out_l[i] = dl[i] * 0.95 + gdl[i] * 0.55 + bdl[i] * 0.5 + yl[i]
		out_r[i] = dr[i] * 0.95 + gdr[i] * 0.55 + bdr[i] * 0.5 + yr[i]
	# М'яке стиснення, щоб усе «тиснуло» разом.
	for i in range(n):
		out_l[i] = tanh(out_l[i] * 1.5) * 0.9
		out_r[i] = tanh(out_r[i] * 1.5) * 0.9
	var wet := reverb(out_l, out_r, 0.1, 0.7, 0.6, true)
	var wl: PackedFloat32Array = wet[0]
	var wr: PackedFloat32Array = wet[1]
	var p := maxf(peak(wl), peak(wr))
	var g := 0.9 / maxf(p, 0.0001)
	return [gain(wl, g), gain(wr, g)]


func gen_mass() -> void:
	var m := music_mass()
	save("%s/music/music_mass.wav" % OUT, m[0], m[1])


func gen_surprise_sfx() -> void:
	# Невидиме джерело: шепіт, що ковзає між двома нотами, скрегіт заліза, далекий ріг.
	var wn := nsamp(2.4)
	var wh := zeros(wn)
	var base := bp(white(wn, 6001), 1900.0, 2.2)
	var base2 := bp(white(wn, 6002), 900.0, 2.6)
	for i in range(wn):
		var t := float(i) / float(SR)
		var amp := (0.5 + 0.5 * sin(TAU * 3.1 * t + sin(t * 1.7) * 2.0)) * minf(1.0, t / 0.4) * clampf((2.4 - t) / 0.8, 0.0, 1.0)
		wh[i] = (base[i] + base2[i] * 0.7) * amp
	sfx("strange_whisper", 1, mix2(wh, gain(reverb_mono(wh, 0.5, 0.8, 0.5, 1.2), 0.8)))
	var sn := nsamp(2.2)
	var sc := bp_sweep(white(sn, 6003), 700.0, 3200.0, 5.0)
	var sc_env := zeros(sn)
	for i in range(sn):
		var t := float(i) / float(SR)
		sc_env[i] = minf(1.0, t / 0.12) * clampf((2.2 - t) / 0.9, 0.0, 1.0) * (0.6 + 0.4 * sin(TAU * 7.0 * t))
	var scr := mul(sc, sc_env)
	add_into(scr, mul(saw_voice(233.0, 2.0, 1800.0, 0.2, 1.0, 0.03), env(nsamp(2.0), 0.2, 1.0)), 0, 0.35)
	sfx("strange_scrape", 1, mix2(scr, gain(reverb_mono(scr, 0.4, 0.75, 0.5, 1.0), 0.6)))
	var horn := mix2(saw_voice(98.0, 3.2, 520.0, 0.6, 1.4, 0.006), gain(saw_voice(147.0, 3.2, 520.0, 0.6, 1.4, 0.006), 0.6))
	sfx("far_horn", 1, mix2(horn, gain(reverb_mono(horn, 0.7, 0.88, 0.5, 2.5), 1.0)))


# =====================================================================================
# Власна музика меню та інтро (замінює сторонні ashen_ambient / prologue_cinematic)
# =====================================================================================

func gen_menu_intro() -> void:
	var m := music_menu()
	save("%s/music/music_menu.wav" % OUT, m[0], m[1])
	var pr := music_prologue()
	save("%s/music/music_prologue.wav" % OUT, pr[0], pr[1])


func _wind_layer(n: int, seed_value: int, amp: float) -> PackedFloat32Array:
	var w := bp(white(n, seed_value), 420.0, 0.9)
	for i in range(n):
		var t := float(i) / float(SR)
		w[i] *= amp * (0.55 + 0.45 * sin(TAU * 0.07 * t + float(seed_value)))
	return w


func music_menu() -> Array:
	## 48 с, цикл: низький дрон ре мінор, повільні дзвони, подих вітру. Спокійно й тривожно.
	rng.seed = 5150
	var total := 48.0
	var n := nsamp(total)
	var l := zeros(n)
	var r := zeros(n)
	_pad(l, r, [73.42, 110.0, 146.83], 0.0, total + 2.0, 380.0, 0.2, 6.0, 6.0)
	_pad(l, r, [87.31, 130.81, 174.61], 12.0, 22.0, 420.0, 0.12, 5.0, 5.0)
	_pad(l, r, [82.41, 123.47, 164.81], 30.0, 18.0, 420.0, 0.1, 5.0, 5.0)
	var bells := [[2.0, 293.66], [9.5, 349.23], [17.0, 220.0], [25.0, 293.66], [33.5, 261.63], [41.0, 220.0]]
	for b in bells:
		_put(l, r, bell(float(b[1]), 5.0, 2.4, 0.8), float(b[0]), 0.1, 0.3 + 0.4 * rng.randf())
	add_into(l, _wind_layer(n, 11, 0.07), 0, 1.0, true)
	add_into(r, _wind_layer(n, 12, 0.07), 0, 1.0, true)
	var wet := reverb(l, r, 0.3, 0.86, 0.45, true)
	var wl: PackedFloat32Array = wet[0]
	var wr: PackedFloat32Array = wet[1]
	var p := maxf(peak(wl), peak(wr))
	var g := 0.8 / maxf(p, 0.0001)
	return [gain(wl, g), gain(wr, g)]


func music_prologue() -> Array:
	## 56 с: тиха ніч → дзвони → наростання з низьких барабанів і хору перед назвою гри.
	rng.seed = 7007
	var total := 56.0
	var n := nsamp(total)
	var l := zeros(n)
	var r := zeros(n)
	_pad(l, r, [55.0, 82.41, 110.0], 0.0, 58.0, 340.0, 0.2, 5.0, 8.0)
	_pad(l, r, [73.42, 110.0, 146.83, 174.61], 16.0, 40.0, 460.0, 0.13, 8.0, 8.0)
	for k in range(5):
		_put(l, r, bell(220.0 * (1.0 if k % 2 == 0 else 1.1892), 6.0, 2.8, 0.7), 3.0 + float(k) * 6.5, 0.09, 0.25 + 0.5 * float(k % 2))
	var drum := _taiko(70.0, 0.4)
	var t_d := 28.0
	var gap := 3.0
	while t_d < 52.0:
		_put(l, r, drum, t_d, 0.3 + (t_d - 28.0) * 0.012, 0.5)
		gap = maxf(0.9, gap * 0.9)
		t_d += gap
	for f in [146.83, 174.61, 220.0, 293.66]:
		_choir(l, r, float(f), 34.0, 20.0, 0.025, 0.2 + 0.6 * rng.randf(), 8.0, 6.0)
	var riser_n := nsamp(10.0)
	var riser := bp_sweep(white(riser_n, 99), 300.0, 5000.0, 1.2)
	for i in range(riser_n):
		var k2 := float(i) / float(riser_n)
		riser[i] *= k2 * k2
	_put(l, r, riser, 44.0, 0.14, 0.5)
	add_into(l, _wind_layer(n, 21, 0.05), 0, 1.0)
	add_into(r, _wind_layer(n, 22, 0.05), 0, 1.0)
	var wet := reverb(l, r, 0.28, 0.85, 0.45, false)
	var wl: PackedFloat32Array = wet[0]
	var wr: PackedFloat32Array = wet[1]
	var p := maxf(peak(wl), peak(wr))
	var g := 0.84 / maxf(p, 0.0001)
	for i in range(wl.size()):
		var t := float(i) / float(SR)
		var edge := minf(1.0, t / 2.0) * clampf((total + 1.0 - t) / 3.0, 0.0, 1.0)
		wl[i] *= g * edge
		wr[i] *= g * edge
	return [wl, wr]
