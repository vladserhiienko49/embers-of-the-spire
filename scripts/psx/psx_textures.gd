class_name PSXTextures
extends RefCounted
## Процедурні тайлові текстури 64×64 у стилі PS1.
## Текстури сірі (деталь), колір дає матеріал: albedo × текстура × detail_gain.
## Генеруються один раз за потреби та кешуються.

const SIZE: int = 64
const TARGET_MEAN: float = 0.82

static var _cache: Dictionary = {}


static func get_texture(kind: String) -> Texture2D:
	if _cache.has(kind):
		return _cache[kind]
	var values := _generate(kind)
	_normalize(values)
	var data := PackedByteArray()
	data.resize(SIZE * SIZE * 3)
	for i in range(SIZE * SIZE):
		var b := int(clampf(values[i], 0.0, 1.0) * 255.0)
		data[i * 3] = b
		data[i * 3 + 1] = b
		data[i * 3 + 2] = b
	var image := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGB8, data)
	var texture := ImageTexture.create_from_image(image)
	_cache[kind] = texture
	return texture


static func _normalize(values: PackedFloat32Array) -> void:
	var total := 0.0
	for v in values:
		total += v
	var mean := total / float(values.size())
	if mean <= 0.001:
		return
	var k := TARGET_MEAN / mean
	for i in range(values.size()):
		values[i] = clampf(values[i] * k, 0.0, 1.0)


# --- Тайлова value-noise -------------------------------------------------------

static func _lattice(px: int, py: int, seed_value: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var arr := PackedFloat32Array()
	arr.resize(px * py)
	for i in range(px * py):
		arr[i] = rng.randf()
	return arr


static func _field(px: int, py: int, octaves: int, seed_value: int) -> PackedFloat32Array:
	## Фрактальний шум, що безшовно тайлиться (періоди кратні розміру).
	var out := PackedFloat32Array()
	out.resize(SIZE * SIZE)
	var amp := 1.0
	var amp_total := 0.0
	var cx := px
	var cy := py
	for octave in range(octaves):
		var lat := _lattice(cx, cy, seed_value + octave * 977)
		for y in range(SIZE):
			var fy := float(y) * float(cy) / float(SIZE)
			var iy := int(fy)
			var ty := fy - float(iy)
			ty = ty * ty * (3.0 - 2.0 * ty)
			var y0 := iy % cy
			var y1 := (iy + 1) % cy
			for x in range(SIZE):
				var fx := float(x) * float(cx) / float(SIZE)
				var ix := int(fx)
				var tx := fx - float(ix)
				tx = tx * tx * (3.0 - 2.0 * tx)
				var x0 := ix % cx
				var x1 := (ix + 1) % cx
				var a := lat[y0 * cx + x0]
				var b := lat[y0 * cx + x1]
				var c := lat[y1 * cx + x0]
				var d := lat[y1 * cx + x1]
				out[y * SIZE + x] += lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty) * amp
		amp_total += amp
		amp *= 0.5
		cx = mini(cx * 2, SIZE)
		cy = mini(cy * 2, SIZE)
	for i in range(out.size()):
		out[i] /= amp_total
	return out


static func _speckle(seed_value: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := PackedFloat32Array()
	out.resize(SIZE * SIZE)
	for i in range(out.size()):
		out[i] = rng.randf()
	return out


# --- Генератори -----------------------------------------------------------------

static func _generate(kind: String) -> PackedFloat32Array:
	match kind:
		"stone": return _gen_stone(0.18)
		"rock": return _gen_rock()
		"brick": return _gen_blocks(16, 8, 8, 0.30, 1201)
		"tiles": return _gen_blocks(16, 16, 8, 0.34, 1307)
		"planks": return _gen_planks()
		"shingles": return _gen_shingles()
		"thatch": return _gen_thatch()
		"bark": return _gen_bark()
		"foliage": return _gen_foliage()
		"metal": return _gen_metal()
		"cloth": return _gen_cloth()
		"plaster": return _gen_plaster()
		"dirt": return _gen_dirt()
		"grass": return _gen_grass()
		_: return _gen_grime()


static func _gen_grime() -> PackedFloat32Array:
	var n := _field(4, 4, 4, 11)
	var s := _speckle(12)
	var out := PackedFloat32Array()
	out.resize(SIZE * SIZE)
	for i in range(out.size()):
		out[i] = 0.62 + n[i] * 0.32 - (0.12 if s[i] > 0.94 else 0.0)
	return out


static func _gen_stone(crack_amount: float) -> PackedFloat32Array:
	var n := _field(8, 8, 3, 21)
	var c := _field(4, 4, 2, 22)
	var s := _speckle(23)
	var out := PackedFloat32Array()
	out.resize(SIZE * SIZE)
	for i in range(out.size()):
		var crack := 1.0 if absf(c[i] - 0.5) < 0.025 else 0.0
		out[i] = 0.5 + n[i] * 0.42 - crack * crack_amount - (0.08 if s[i] > 0.9 else 0.0)
	return out


static func _gen_rock() -> PackedFloat32Array:
	var n := _field(4, 4, 4, 31)
	var c := _field(8, 8, 2, 32)
	var out := PackedFloat32Array()
	out.resize(SIZE * SIZE)
	for i in range(out.size()):
		var crack := 1.0 if absf(c[i] - 0.5) < 0.03 else 0.0
		out[i] = 0.3 + pow(n[i], 1.3) * 0.75 - crack * 0.22
	return out


static func _gen_blocks(block_w: int, block_h: int, row_offset: int, mortar: float, seed_value: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var tones := PackedFloat32Array()
	tones.resize(64)
	for i in range(64):
		tones[i] = rng.randf_range(0.58, 0.9)
	var n := _field(16, 16, 2, seed_value + 5)
	var out := PackedFloat32Array()
	out.resize(SIZE * SIZE)
	for y in range(SIZE):
		var row := y / block_h
		var ly := y % block_h
		var shift := row_offset if row % 2 == 1 else 0
		for x in range(SIZE):
			var sx := (x + shift) % SIZE
			var col := sx / block_w
			var lx := sx % block_w
			var i := y * SIZE + x
			if ly == 0 or lx == 0:
				out[i] = mortar
			else:
				var tone := tones[(row * 7 + col * 3) % 64]
				var shade := -0.1 if ly == block_h - 1 else (0.06 if ly == 1 else 0.0)
				out[i] = tone + (n[i] - 0.5) * 0.24 + shade
	return out


static func _gen_planks() -> PackedFloat32Array:
	var grain := _field(32, 2, 3, 41)
	var knots := _speckle(42)
	var rng := RandomNumberGenerator.new()
	rng.seed = 43
	var tones := [rng.randf_range(0.6, 0.85), rng.randf_range(0.6, 0.85), rng.randf_range(0.6, 0.85), rng.randf_range(0.6, 0.85)]
	var out := PackedFloat32Array()
	out.resize(SIZE * SIZE)
	for y in range(SIZE):
		for x in range(SIZE):
			var i := y * SIZE + x
			var plank := x / 16
			if x % 16 == 0:
				out[i] = 0.22
			else:
				var g := grain[i]
				out[i] = float(tones[plank]) + (g - 0.5) * 0.5 - (0.2 if knots[i] > 0.997 else 0.0)
	return out


static func _gen_shingles() -> PackedFloat32Array:
	var n := _field(16, 8, 2, 51)
	var rng := RandomNumberGenerator.new()
	rng.seed = 52
	var tones := PackedFloat32Array()
	tones.resize(64)
	for i in range(64):
		tones[i] = rng.randf_range(0.55, 0.88)
	var out := PackedFloat32Array()
	out.resize(SIZE * SIZE)
	for y in range(SIZE):
		var row := y / 8
		var ly := y % 8
		var shift := 4 if row % 2 == 1 else 0
		for x in range(SIZE):
			var sx := (x + shift) % SIZE
			var i := y * SIZE + x
			if sx % 8 == 0:
				out[i] = 0.3
			else:
				var tone := tones[(row * 8 + sx / 8) % 64]
				out[i] = tone * (1.05 - float(ly) / 8.0 * 0.45) + (n[i] - 0.5) * 0.15
	return out


static func _gen_thatch() -> PackedFloat32Array:
	var streak := _field(32, 2, 3, 61)
	var fine := _speckle(62)
	var out := PackedFloat32Array()
	out.resize(SIZE * SIZE)
	for y in range(SIZE):
		for x in range(SIZE):
			var i := y * SIZE + x
			var band := 0.75 if y % 16 >= 14 else 1.0
			out[i] = (0.45 + streak[i] * 0.55 + (fine[i] - 0.5) * 0.12) * band
	return out


static func _gen_bark() -> PackedFloat32Array:
	var grooves := _field(16, 2, 3, 71)
	var n := _field(8, 8, 2, 72)
	var out := PackedFloat32Array()
	out.resize(SIZE * SIZE)
	for i in range(out.size()):
		var g := grooves[i]
		out[i] = (0.25 if g < 0.38 else 0.5 + g * 0.45) + (n[i] - 0.5) * 0.15
	return out


static func _gen_foliage() -> PackedFloat32Array:
	var blobs := _field(8, 8, 3, 81)
	var s := _speckle(82)
	var out := PackedFloat32Array()
	out.resize(SIZE * SIZE)
	for i in range(out.size()):
		var b := blobs[i]
		out[i] = (0.35 if b < 0.42 else 0.62 + b * 0.35) + (0.15 if s[i] > 0.96 else 0.0)
	return out


static func _gen_metal() -> PackedFloat32Array:
	var n := _field(8, 8, 3, 91)
	var out := PackedFloat32Array()
	out.resize(SIZE * SIZE)
	for i in range(out.size()):
		out[i] = 0.72 + (n[i] - 0.5) * 0.22
	var rng := RandomNumberGenerator.new()
	rng.seed = 92
	for scratch in range(7):
		var x := rng.randi_range(0, SIZE - 1)
		var y := rng.randi_range(0, SIZE - 1)
		var length := rng.randi_range(6, 18)
		var dx := 1 if rng.randf() > 0.5 else -1
		for step in range(length):
			out[((y + step) % SIZE) * SIZE + ((x + step * dx + SIZE) % SIZE)] = 0.95
	return out


static func _gen_cloth() -> PackedFloat32Array:
	var n := _field(4, 4, 3, 101)
	var out := PackedFloat32Array()
	out.resize(SIZE * SIZE)
	for y in range(SIZE):
		for x in range(SIZE):
			var weave := 0.08 if (x + y) % 2 == 0 else -0.04
			out[y * SIZE + x] = 0.62 + n[y * SIZE + x] * 0.25 + weave
	return out


static func _gen_plaster() -> PackedFloat32Array:
	var n := _field(4, 4, 4, 111)
	var stains := _field(2, 4, 2, 112)
	var out := PackedFloat32Array()
	out.resize(SIZE * SIZE)
	for y in range(SIZE):
		for x in range(SIZE):
			var i := y * SIZE + x
			var stain := 0.18 if stains[i] > 0.66 else 0.0
			out[i] = 0.72 + (n[i] - 0.5) * 0.22 - stain
	return out


static func _gen_dirt() -> PackedFloat32Array:
	var n := _field(8, 8, 4, 121)
	var s := _speckle(122)
	var out := PackedFloat32Array()
	out.resize(SIZE * SIZE)
	for i in range(out.size()):
		var pebble := 0.2 if s[i] > 0.97 else (-0.12 if s[i] < 0.03 else 0.0)
		out[i] = 0.48 + n[i] * 0.45 + pebble
	return out


static func _gen_grass() -> PackedFloat32Array:
	var n := _field(8, 8, 3, 131)
	var blades := _field(64, 16, 1, 132)
	var s := _speckle(133)
	var out := PackedFloat32Array()
	out.resize(SIZE * SIZE)
	for i in range(out.size()):
		out[i] = 0.42 + n[i] * 0.3 + blades[i] * 0.28 + (0.12 if s[i] > 0.95 else 0.0)
	return out
