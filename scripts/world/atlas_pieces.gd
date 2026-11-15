class_name AtlasPieces
extends RefCounted
## Атлас Корони, розірваний Орденом Печатки.
## Лор: коли Око приспали вперше, монахи Абатства розірвали єдину карту з дорогою до Вівтаря на вісім частин
## і роздали їх хранителям — людям, яким довіряли, та лицарям-вартовим Ордену. Восьму частину, саму Чорну Гору,
## вони вплели в Печатку: вона проступає лише тоді, коли три уламки Печатки знову разом.
## Шматки — комірки Вороного навколо «насіння» (рвані краї однакові для сусідніх шматків).

const START: String = "village"
const FINAL: String = "mountain"
const BASE_SIZE: Vector2 = Vector2(1206.0, 864.0)

## Порядок збирання = порядок сюжету.
const ORDER: Array = ["village", "cemetery", "south", "forge", "west", "north", "royal", "mountain"]

const PIECES: Dictionary = {
	"village": {"name": "Село Попелу", "seed": Vector2(230.0, 410.0), "from": "Твій власний клапоть",
		"lore": "Обірваний шматок атласу, з яким ти прийшов: лише рідне село та дорога довкола."},
	"cemetery": {"name": "Забуте кладовище", "seed": Vector2(410.0, 230.0), "from": "Лицар Попелу",
		"lore": "Лицар Ордену беріг свою частину атласу й після смерті: шматок прикипів до його нагрудника."},
	"south": {"name": "Південні тракти", "seed": Vector2(430.0, 650.0), "from": "Брама Південної Застави",
		"lore": "Механізм брами тримав частину атласу в схованці: відкрилась лише після оборони від трьох хвиль мерців."},
	"forge": {"name": "Кузня й Цитадель", "seed": Vector2(720.0, 460.0), "from": "Вартовий Цитаделі",
		"lore": "Вартовий носив шматок під мантією як присягу: він востаннє виконав наказ Ордену."},
	"west": {"name": "Руїни Абатства", "seed": Vector2(90.0, 330.0), "from": "Некромант Руїн",
		"lore": "Колишній настоятель Абатства зрадив Орден, але свою частину атласу так і не знищив."},
	"north": {"name": "Північні пагорби", "seed": Vector2(330.0, 80.0), "from": "Німі Камені",
		"lore": "Три рунічні стовпи Німих Каменів відкрили нішу, де монахи сховали шматок."},
	"royal": {"name": "Королівська північ", "seed": Vector2(800.0, 160.0), "from": "Давній Маг Крижаної Вежі",
		"lore": "Маг, що відповідав на сигнал Ока, тримав шматок як ключ до своєї вежі. Тепер він твій."},
	"mountain": {"name": "Чорна Гора", "seed": Vector2(110.0, 110.0), "from": "Стародавня Печатка",
		"lore": "Останній шматок був вплетений у Печатку: він проступив, щойно три уламки зрослися."},
}

## Крок головного сюжету (progress) → шматок, який герой отримує.
const BY_KILL: Dictionary = {"ash_knight": "cemetery", "necromancer": "west", "citadel_guardian": "forge", "ancient_mage": "royal"}
## Шматки, потрібні перед фінальним зшиванням (все, крім «Чорної Гори»).
const GATE: Array = ["cemetery", "south", "forge", "west", "north", "royal"]

const JAG_STEP: float = 13.0
const JAG_AMP: float = 5.5

static var _cache_size: Vector2 = Vector2.ZERO
static var _cache: Dictionary = {}


static func total() -> int:
	return ORDER.size()


static func piece_name(piece_id: String) -> String:
	return str(PIECES.get(piece_id, {}).get("name", piece_id))


static func seed_of(piece_id: String, world_size: Vector2) -> Vector2:
	var s: Vector2 = PIECES[piece_id]["seed"]
	return s / BASE_SIZE * world_size


static func piece_at(world_pos: Vector2, world_size: Vector2) -> String:
	## Шматок, якому належить точка (найближче насіння).
	var best := ""
	var best_d := INF
	for id in ORDER:
		var d := world_pos.distance_squared_to(seed_of(id, world_size))
		if d < best_d:
			best_d = d
			best = id
	return best


static func polygons(world_size: Vector2) -> Dictionary:
	## id → PackedVector2Array (світові координати мапи), з рваними внутрішніми краями.
	if _cache_size == world_size and not _cache.is_empty():
		return _cache
	_cache.clear()
	_cache_size = world_size
	var seeds := {}
	for id in ORDER:
		seeds[id] = seed_of(id, world_size)
	for i in range(ORDER.size()):
		var id: String = ORDER[i]
		var s: Vector2 = seeds[id]
		var poly := PackedVector2Array([Vector2.ZERO, Vector2(world_size.x, 0.0), world_size, Vector2(0.0, world_size.y)])
		for other in ORDER:
			if other == id:
				continue
			poly = _clip(poly, s, seeds[other])
			if poly.is_empty():
				break
		_cache[id] = _jag(poly, i, seeds)
	return _cache


static func _clip(poly: PackedVector2Array, s: Vector2, q: Vector2) -> PackedVector2Array:
	## Залишає півплощину, ближчу до s, ніж до q (Сазерленд — Ходжмен).
	var m := (s + q) * 0.5
	var n := q - s
	var out := PackedVector2Array()
	var count := poly.size()
	for k in range(count):
		var a := poly[k]
		var b := poly[(k + 1) % count]
		var da := (a - m).dot(n)
		var db := (b - m).dot(n)
		if da <= 0.0:
			out.append(a)
		if (da <= 0.0) != (db <= 0.0):
			out.append(a.lerp(b, da / (da - db)))
	return out


static func _jag(poly: PackedVector2Array, index: int, seeds: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	var count := poly.size()
	for k in range(count):
		var a := poly[k]
		var b := poly[(k + 1) % count]
		out.append(a)
		# Яка сусідня комірка ділить це ребро? (обидва кінці лежать на бісектрисі)
		var mine: Vector2 = seeds[ORDER[index]]
		for j in range(ORDER.size()):
			if j == index:
				continue
			var q: Vector2 = seeds[ORDER[j]]
			var n := (q - mine).normalized()
			var m := (q + mine) * 0.5
			if absf((a - m).dot(n)) > 0.05 or absf((b - m).dot(n)) > 0.05:
				continue
			# Канонічна система для пари (lo, hi): однакові точки для обох сусідів.
			var lo := mini(index, j)
			var hi := maxi(index, j)
			var s_lo: Vector2 = seeds[ORDER[lo]]
			var s_hi: Vector2 = seeds[ORDER[hi]]
			var normal := (s_hi - s_lo).normalized()
			var dir := normal.orthogonal()
			var mid := (s_lo + s_hi) * 0.5
			var ta := (a - mid).dot(dir)
			var tb := (b - mid).dot(dir)
			var step := 1 if tb > ta else -1
			var k0 := int(ceil(minf(ta, tb) / JAG_STEP))
			var k1 := int(floor(maxf(ta, tb) / JAG_STEP))
			var knots: Array = []
			for kk in range(k0, k1 + 1):
				var t := float(kk) * JAG_STEP
				if absf(t - ta) < 3.0 or absf(t - tb) < 3.0:
					continue
				knots.append(kk)
			if step < 0:
				knots.reverse()
			for kk in knots:
				var h := fposmod(sin(float(lo * 97 + hi * 13) * 7.31 + float(kk) * 12.9898) * 43758.5453, 1.0) * 2.0 - 1.0
				out.append(mid + dir * float(kk) * JAG_STEP + normal * h * JAG_AMP)
			break
	return out
