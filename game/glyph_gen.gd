class_name GlyphGen
extends RefCounted
## Generative pictogram engine: glyph id 0..POOL-1 -> composition of 2-4 "radicals"
## (48 hand-coded stroke shapes) with mirror/rotation/scale/placement. Everything is a
## list of polylines in a unit box [-1,1]^2 (1-point polylines are dots), cached per id.

const POOL := 5000
const RADICALS := 48
const SALT := 0x5EED1E55
const GOLDEN := -7046029254386353131   # 0x9E3779B97F4A7C15 as signed int64
const CACHE_MAX := 3000

## Layout archetypes: parts as [x, y, sx, sy] (centre + non-uniform scale into the cell).
const LAYOUTS := [
	[[0.0, -0.5, 0.8, 0.45], [0.0, 0.5, 0.8, 0.45]],                                   # 0 stack2
	[[-0.5, 0.0, 0.45, 0.8], [0.5, 0.0, 0.45, 0.8]],                                   # 1 side2
	[[0.0, 0.22, 0.72, 0.68], [0.0, -0.76, 0.5, 0.24]],                               # 2 main+crown
	[[0.0, -0.18, 0.72, 0.66], [0.0, 0.78, 0.7, 0.2]],                                 # 3 main+base
	[[0.0, -0.5, 0.8, 0.4], [-0.5, 0.52, 0.46, 0.44], [0.5, 0.52, 0.46, 0.44]],          # 4 trio
	[[0.0, -0.68, 0.75, 0.28], [0.0, 0.0, 0.75, 0.28], [0.0, 0.68, 0.75, 0.28]],       # 5 column3
	[[0.0, 0.0, 0.52, 0.8], [-0.78, 0.0, 0.2, 0.5], [0.78, 0.0, 0.2, 0.5]],            # 6 flanked
	[[-0.5, -0.5, 0.46, 0.46], [0.5, -0.5, 0.46, 0.46], [-0.5, 0.5, 0.46, 0.46], [0.5, 0.5, 0.46, 0.46]], # 7 quad
	[[0.0, 0.0, 0.95, 0.95], [0.0, 0.05, 0.42, 0.42], [0.0, -0.3, 0.2, 0.2]],          # 8 framed
	[[-0.45, -0.45, 0.5, 0.5], [0.45, 0.45, 0.5, 0.5], [0.52, -0.55, 0.34, 0.34]],     # 9 diagonal
	[[-0.38, 0.0, 0.4, 0.92], [0.58, -0.5, 0.36, 0.36], [0.58, 0.5, 0.36, 0.36]],      # 10 tall+side
	[[0.0, 0.55, 0.92, 0.4], [-0.5, -0.4, 0.42, 0.46], [0.5, -0.4, 0.42, 0.46]],       # 11 wide+two
	[[0.0, 0.0, 0.95, 0.95], [0.0, 0.1, 0.4, 0.4], [0.0, -0.45, 0.2, 0.2], [0.0, 0.62, 0.22, 0.2]], # 12 framed4
]
const FLANKED := 6
const FRAMED := [8, 12]
const FRAME_RADICALS := [0, 11, 15, 37, 17, 44, 22, 12]
## Radicals that look right when turned by 45 degrees.
const SYMMETRIC := [0, 1, 11, 15, 16, 26, 36, 37, 45, 47, 7]

static var glow := true
static var _cache := {}

class Rng:
	var s: int
	func _init(seed_value: int) -> void:
		s = GlyphGen._mix(seed_value)
	func n(m: int) -> int:
		s = GlyphGen._mix(s + GlyphGen.GOLDEN)
		return ((s >> 11) & 0xFFFFFFFF) % m

static func _mix(x: int) -> int:
	x = (x ^ ((x >> 30) & 0x3FFFFFFFF)) * -4658895280553007687
	x = (x ^ ((x >> 27) & 0x1FFFFFFFFF)) * -7723592293110705685
	return x ^ ((x >> 31) & 0x1FFFFFFFF)

static func radical_count() -> int:
	return RADICALS

# ------------------------------------------------------------------ composition

## Describes how glyph `id` is composed: {layout, parts:[{k, v, mx, rot, x, y, sx, sy}]}.
static func spec(id: int) -> Dictionary:
	id = posmod(id, POOL)
	var r := Rng.new(id * 2654435761 + SALT)
	var layout: int = r.n(LAYOUTS.size())
	var cells: Array = LAYOUTS[layout]
	var parts: Array = []
	for i in cells.size():
		var c: Array = cells[i]
		var part := {"x": c[0], "y": c[1], "sx": c[2], "sy": c[3]}
		if layout == FLANKED and i == 2:
			var twin: Dictionary = parts[1]
			part.merge({"k": twin.k, "v": twin.v, "mx": not twin.mx, "rot": twin.rot})
		else:
			part.merge(_roll_part(r, parts, i == 0 and layout in FRAMED))
		parts.append(part)
	return {"layout": layout, "parts": parts}

static func _roll_part(r: Rng, prev: Array, is_frame: bool) -> Dictionary:
	var k := 0
	for _try in 8:
		k = FRAME_RADICALS[r.n(FRAME_RADICALS.size())] if is_frame else r.n(RADICALS)
		var clash := false
		for p in prev:
			clash = clash or p.k == k
		if not clash:
			break
	var rot := 0
	var roll := r.n(10)
	if k in SYMMETRIC and roll < 3:
		rot = 45 * (1 + r.n(3))
	elif roll >= 6 and not is_frame:
		rot = 90 * (1 + r.n(3))
	return {"k": k, "v": r.n(4), "mx": r.n(2) == 1, "rot": rot}

## Unit-space stroke list for glyph `id` (cached).
static func strokes(id: int) -> Array:
	id = posmod(id, POOL)
	if _cache.has(id):
		return _cache[id]
	var out: Array = []
	for part in spec(id).parts:
		out.append_array(_place_part(part))
	if _cache.size() >= CACHE_MAX:
		_cache.clear()
	_cache[id] = out
	return out

static func _place_part(part: Dictionary) -> Array:
	var rot_t := Transform2D(deg_to_rad(float(part.rot)), Vector2.ZERO)
	var scale_t := Transform2D(Vector2(part.sx, 0.0), Vector2(0.0, part.sy), Vector2(part.x, part.y))
	var t := scale_t * rot_t
	var out: Array = []
	for st: PackedVector2Array in _rad(part.k, part.v):
		var pts := PackedVector2Array()
		for p in st:
			pts.append(t * Vector2(-p.x if part.mx else p.x, p.y))
		out.append(pts)
	return out

## Hash of the quantised stroke list: identical drawings give identical signatures.
static func signature(id: int) -> int:
	var h := 1469598103
	for st: PackedVector2Array in strokes(id):
		h = _mix(h ^ st.size())
		for p in st:
			h = _mix(h + int(roundf(p.x * 64.0)) * 4099 + int(roundf(p.y * 64.0)))
	return h

## 0 (nothing in common) .. 1 (same composition), for tests and for assigning confusable meanings apart.
static func similarity_hint(a: int, b: int) -> float:
	var sa := spec(a)
	var sb := spec(b)
	var shared := 0
	var exact := 0
	for pa: Dictionary in sa.parts:
		for pb: Dictionary in sb.parts:
			if pa.k == pb.k:
				shared += 1
				if pa.v == pb.v and pa.mx == pb.mx and pa.rot == pb.rot:
					exact += 1
				break
	var n := float(maxi(sa.parts.size(), sb.parts.size()))
	var layout_same := 1.0 if sa.layout == sb.layout else 0.0
	return clampf(0.25 * layout_same + 0.45 * shared / n + 0.3 * exact / n, 0.0, 1.0)

# ------------------------------------------------------------------ drawing

## Draw glyph `id` centred at `center`, fitting a size x size box. `width` = stroke px.
static func draw(ci: CanvasItem, id: int, center: Vector2, size: float, col: Color, width := 2.0) -> void:
	_draw_strokes(ci, strokes(id), center, size * 0.5 * 0.94, col, width)

static func _draw_strokes(ci: CanvasItem, list: Array, center: Vector2, half: float, col: Color, width: float) -> void:
	var t := Transform2D(Vector2(half, 0.0), Vector2(0.0, half), center)
	var glow_col := Color(col.r, col.g, col.b, col.a * 0.12)
	var caps := width >= 1.4
	for pass_i in (2 if glow else 1):
		var is_glow := glow and pass_i == 0
		var w := width * 2.8 if is_glow else width
		var c := glow_col if is_glow else col
		for st: PackedVector2Array in list:
			if st.size() == 1:
				ci.draw_circle(t * st[0], w * (0.8 if is_glow else 1.25), c)
				continue
			var pts := t * st
			ci.draw_polyline(pts, c, w, true)
			if caps and not is_glow and st[0].distance_to(st[st.size() - 1]) > 0.02:
				ci.draw_circle(pts[0], w * 0.5, c)
				ci.draw_circle(pts[pts.size() - 1], w * 0.5, c)

## Category determinatives (0 item, 1 bonus, 2 location, 3 enemy, 4 hero, 5 origin, 6 action, 7 quality).
static func draw_frame(ci: CanvasItem, kind: int, rect: Rect2, col: Color) -> void:
	var half := minf(rect.size.x, rect.size.y) * 0.5 * 0.92
	var w := maxf(1.5, half * 0.1)
	_draw_strokes(ci, _frame(kind), rect.get_center(), half, col, w)

static func _frame(kind: int) -> Array:
	var s: Array = []
	match posmod(kind, 8):
		0:  # cartouche: stadium with the closing bar
			var loop := _arc(0.3, 0, 0.5, 0.5, -PI / 2, PI / 2, 10)
			loop.append_array(_arc(-0.3, 0, 0.5, 0.5, PI / 2, PI * 1.5, 10))
			loop.append(loop[0])
			s.append(loop)
			s.append(_pl([0.93, -0.32, 0.93, 0.32]))
			s.append(_pl([-0.3, 0.0]))
		1:  # concave four-point star
			s.append(_star(4, 0.95, 0.26))
			s.append(_pl([0.0, 0.0]))
		2:  # city: ring crossed
			s.append(_ell(0, 0, 0.8, 0.8))
			s.append(_pl([-0.8, 0.0, 0.8, 0.0]))
			s.append(_pl([0.0, -0.8, 0.0, 0.8]))
		3:  # thorn ring
			s.append(_star(10, 0.97, 0.5))
			s.append(_pl([0.0, 0.0]))
		4:  # eye in a diamond
			s.append(_poly([0, -0.95, 0.95, 0, 0, 0.95, -0.95, 0], true))
			s.append(_bez(Vector2(-0.55, 0), Vector2(0, -0.5), Vector2(0.55, 0), 10) + _bez(Vector2(0.55, 0), Vector2(0, 0.5), Vector2(-0.55, 0), 10))
			s.append(_ell(0, 0, 0.14, 0.14, 12))
		5:  # shen rope ring
			s.append(_ell(0, -0.08, 0.68, 0.68))
			s.append(_pl([-0.55, 0.82, 0.55, 0.82]))
		6:  # double chevron
			s.append(_pl([-0.75, -0.62, -0.1, 0.0, -0.75, 0.62]))
			s.append(_pl([0.0, -0.62, 0.65, 0.0, 0.0, 0.62]))
		7:  # feather
			var leaf := _bez(Vector2(0, 0.9), Vector2(0.75, 0.0), Vector2(0, -0.9), 12)
			leaf.append_array(_bez(Vector2(0, -0.9), Vector2(-0.75, 0.0), Vector2(0, 0.9), 12))
			s.append(leaf)
			s.append(_pl([0.0, 0.95, 0.0, -0.5]))
			s.append(_pl([0.0, 0.25, 0.4, -0.05]))
			s.append(_pl([0.0, 0.25, -0.4, -0.05]))
	return s

# ------------------------------------------------------------------ stroke helpers

static func _pl(v: Array) -> PackedVector2Array:
	var o := PackedVector2Array()
	for i in range(0, v.size() - 1, 2):
		o.append(Vector2(v[i], v[i + 1]))
	return o

static func _poly(v: Array, closed: bool) -> PackedVector2Array:
	var o := _pl(v)
	if closed:
		o.append(o[0])
	return o

static func _arc(cx: float, cy: float, rx: float, ry: float, a0: float, a1: float, n := 14) -> PackedVector2Array:
	var o := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		o.append(Vector2(cx + rx * cos(a), cy + ry * sin(a)))
	return o

static func _ell(cx: float, cy: float, rx: float, ry: float, n := 20) -> PackedVector2Array:
	return _arc(cx, cy, rx, ry, 0.0, TAU, n)

static func _bez(p0: Vector2, p1: Vector2, p2: Vector2, n := 10) -> PackedVector2Array:
	var o := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		o.append(p0.lerp(p1, t).lerp(p1.lerp(p2, t), t))
	return o

static func _star(points: int, r_out: float, r_in: float) -> PackedVector2Array:
	var o := PackedVector2Array()
	for i in points * 2:
		var r := r_out if i % 2 == 0 else r_in
		var a := -PI / 2 + PI * i / points
		o.append(Vector2(r * cos(a), r * sin(a)))
	o.append(o[0])
	return o

static func _ngon(sides: int, r: float, rot := -PI / 2) -> PackedVector2Array:
	var o := PackedVector2Array()
	for i in sides:
		o.append(Vector2(r * cos(rot + TAU * i / sides), r * sin(rot + TAU * i / sides)))
	o.append(o[0])
	return o

static func _spiral(cx: float, cy: float, r0: float, r1: float, turns: float, dir: float, n := 28) -> PackedVector2Array:
	var o := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		var a := dir * t * turns * TAU
		var r := lerpf(r0, r1, t)
		o.append(Vector2(cx + r * cos(a), cy + r * sin(a)))
	return o

static func _swap(list: Array) -> Array:
	var out: Array = []
	for st: PackedVector2Array in list:
		var o := PackedVector2Array()
		for p in st:
			o.append(Vector2(p.y, p.x))
		out.append(o)
	return out

# ------------------------------------------------------------------ radicals

static func _rad(k: int, v: int) -> Array:
	if k < 16:
		return _rad_a(k, v)
	if k < 32:
		return _rad_b(k, v)
	return _rad_c(k, v)

static func _rad_a(k: int, v: int) -> Array:
	var s: Array = []
	match k:
		0:  # loop
			s.append(_ell(0, 0, 0.8, 0.45 + 0.15 * v))
			if v >= 2:
				s.append(_pl([0.0, 0.0]))
		1:  # sun disc
			s.append(_ell(0, 0, 0.6, 0.6))
			s.append(_pl([0.0, 0.0]))
			if v & 1:
				s.append(_ell(0, 0, 0.9, 0.9, 24))
			if v & 2:
				for a in 4:
					s.append(_pl([0.75 * cos(a * PI / 2 + PI / 4), 0.75 * sin(a * PI / 2 + PI / 4), 0.95 * cos(a * PI / 2 + PI / 4), 0.95 * sin(a * PI / 2 + PI / 4)]))
		2:  # bar
			if v == 1:
				s.append(_pl([-0.9, -0.22, 0.9, -0.22]))
				s.append(_pl([-0.9, 0.22, 0.9, 0.22]))
			else:
				s.append(_pl([-0.9, 0.0, 0.9, 0.0]))
			if v == 2:
				s.append(_pl([-0.9, -0.28, -0.9, 0.28]))
				s.append(_pl([0.9, -0.28, 0.9, 0.28]))
			if v == 3:
				s.append(_pl([0.0, -0.45]))
				s.append(_pl([0.0, 0.45]))
		3:  # vertical bar
			s.append_array(_swap(_rad_a(2, v)))
		4:  # hook
			s.append(_pl([0.3, -0.9, 0.3, 0.2]) + _arc(-0.2, 0.2, 0.5, 0.5, 0.0, PI, 10))
			if v & 1:
				s.append(_pl([-0.2, 0.2]))
			if v & 2:
				s.append(_pl([0.05, -0.5, 0.55, -0.5]))
		5:  # spiral
			s.append(_spiral(0, 0, 0.08, 0.85, 1.6 + 0.5 * (v & 1), -1.0 if v & 2 else 1.0))
		6:  # crescent
			var cx := 0.3 + 0.1 * v
			var tip := Vector2(0.8 * cos(1.05), 0.8 * sin(1.05))
			var r_in := Vector2(tip.x - cx, tip.y).length()
			var a_in := atan2(tip.y, tip.x - cx)
			var cres := _arc(0, 0, 0.8, 0.8, 1.05, TAU - 1.05, 16)
			cres.append_array(_arc(cx, 0, r_in, r_in, TAU - a_in, a_in, 14))
			s.append(cres)
			if v & 1:
				s.append(_pl([0.5, 0.0]))
		7:  # dots
			var sets := [[0.0, -0.5, -0.5, 0.4, 0.5, 0.4], [-0.6, 0.0, 0.0, 0.0, 0.6, 0.0], [0.0, -0.6, 0.0, 0.0, 0.0, 0.6], [-0.45, -0.45, 0.45, -0.45, -0.45, 0.45, 0.45, 0.45]]
			var pts: Array = sets[v]
			for i in range(0, pts.size(), 2):
				s.append(_pl([pts[i], pts[i + 1]]))
		8:  # wings
			var feathers := 1 + v % 3
			for side in [-1.0, 1.0]:
				var p0 := Vector2(0.12 * side, 0.45)
				var p1 := Vector2(0.65 * side, 0.55)
				var p2 := Vector2(0.95 * side, -0.4)
				s.append(_bez(p0, p1, p2, 10))
				for i in feathers:
					var t := float(i + 1) / (feathers + 1)
					var q := p0.lerp(p1, t).lerp(p1.lerp(p2, t), t)
					s.append(_pl([q.x, q.y, q.x - 0.12 * side, q.y + 0.45]))
			if v == 3:
				s.append(_pl([0.0, 0.9, 0.0, 0.1]))
		9:  # wave
			var periods := 1.5 + 0.5 * (v & 1)
			for off in ([0.0] if v < 2 else [-0.38, 0.38]):
				var w := PackedVector2Array()
				for i in 25:
					var x := lerpf(-0.9, 0.9, i / 24.0)
					w.append(Vector2(x, off + 0.3 * sin((x + 0.9) / 1.8 * periods * TAU)))
				s.append(w)
		10:  # fork / trident
			s.append(_arc(0, -0.2, 0.55, 0.55, 0.0, PI, 10))
			s.append(_pl([-0.55, -0.2, -0.55, -0.85]))
			s.append(_pl([0.55, -0.2, 0.55, -0.85]))
			s.append(_pl([0.0, 0.35, 0.0, 0.92]))
			if v != 1:
				s.append(_pl([0.0, 0.0, 0.0, -0.85]))
			if v == 2:
				s.append(_pl([-0.55, -0.85]))
				s.append(_pl([0.55, -0.85]))
			if v == 3:
				s.append(_arc(0, -0.2, 0.28, 0.28, 0.0, PI, 8))
		11:  # diamond
			s.append(_poly([0, -0.9, 0.7, 0, 0, 0.9, -0.7, 0], true))
			if v == 1:
				s.append(_poly([0, -0.4, 0.3, 0, 0, 0.4, -0.3, 0], true))
			elif v == 2:
				s.append(_pl([0.0, 0.0]))
			elif v == 3:
				s.append(_pl([-0.7, 0.0, 0.7, 0.0]))
		12:  # eye
			s.append(_bez(Vector2(-0.9, 0), Vector2(0, -0.8), Vector2(0.9, 0), 12) + _bez(Vector2(0.9, 0), Vector2(0, 0.8), Vector2(-0.9, 0), 12))
			s.append(_ell(0, 0, 0.22, 0.22, 12))
			if v == 1:
				for x in [-0.4, 0.0, 0.4]:
					s.append(_pl([x, 0.42, x * 1.2, 0.8]))
			elif v == 2:
				s.append(_pl([0.0, 0.4, 0.0, 0.9]))
			elif v == 3:
				s.append(_bez(Vector2(-0.7, -0.65), Vector2(0, -1.1), Vector2(0.7, -0.65), 10))
		13:  # crown
			s.append(_poly([-0.8, 0.5, -0.8, -0.4, -0.4, 0.0, 0.0, -0.7, 0.4, 0.0, 0.8, -0.4, 0.8, 0.5], true))
			if v & 1:
				for x in [-0.8, 0.0, 0.8]:
					s.append(_pl([x, -0.85 if x == 0.0 else -0.6]))
			if v & 2:
				s.append(_pl([-0.8, 0.18, 0.8, 0.18]))
		14:  # ladder
			s.append(_pl([-0.35, -0.9, -0.35, 0.9]))
			s.append(_pl([0.35, -0.9, 0.35, 0.9]))
			var rungs := 3 + v % 3
			for i in rungs:
				var y := lerpf(-0.65, 0.65, float(i) / (rungs - 1))
				s.append(_pl([-0.35, y, 0.35, y]))
		15:  # nested squares
			var sizes := [0.85, 0.55, 0.25]
			for i in 2 + (v & 1):
				var q: float = sizes[i]
				if i == 2 and (v & 2):
					s.append(_poly([0, -q * 1.3, q * 1.3, 0, 0, q * 1.3, -q * 1.3, 0], true))
				else:
					s.append(_poly([-q, -q, q, -q, q, q, -q, q], true))
	return s

static func _rad_b(k: int, v: int) -> Array:
	var s: Array = []
	match k:
		16:  # rays
			var n := 4 + v
			for i in n:
				var a := lerpf(-PI * 0.95, -PI * 0.05, float(i) / (n - 1))
				s.append(_pl([0.3 * cos(a), 0.55 + 0.3 * sin(a), 0.95 * cos(a), 0.55 + 0.95 * sin(a) * 1.1]))
			s.append(_pl([0.0, 0.55]))
			if v & 2:
				s.append(_pl([-0.7, 0.9, 0.7, 0.9]))
		17:  # triangle
			s.append(_poly([0, -0.85, 0.8, 0.7, -0.8, 0.7], true))
			if v == 1:
				s.append(_pl([-0.4, 0.0, 0.4, 0.0]))
			elif v == 2:
				s.append(_pl([0.0, 0.25]))
			elif v == 3:
				s.append(_poly([0, 0.45, 0.35, -0.1, -0.35, -0.1], true))
		18:  # zigzag
			var n := 5 + (v & 1) * 2
			for off in ([0.0] if v < 2 else [-0.4, 0.4]):
				var z := PackedVector2Array()
				for i in n:
					z.append(Vector2(lerpf(-0.9, 0.9, float(i) / (n - 1)), off + (0.4 if i % 2 else -0.4) * (0.7 if v >= 2 else 1.0)))
				s.append(z)
		19:  # ankh
			s.append(_ell(0, -0.5, 0.32, 0.4) if v != 2 else _poly([0, -0.95, 0.35, -0.5, 0, -0.1, -0.35, -0.5], true))
			s.append(_pl([0.0, -0.1, 0.0, 0.92]))
			s.append(_pl([-0.55, 0.1, 0.55, 0.1]))
			if v == 1:
				s.append(_pl([-0.35, 0.42, 0.35, 0.42]))
			if v == 3:
				s.append(_pl([0.0, -0.5]))
		20:  # reed
			s.append(_pl([0.0, 0.92, 0.0, -0.85]))
			var leaves := 2 + (v & 1) + (v >> 1)
			for i in leaves:
				var y := 0.55 - i * 0.42
				var side := 1.0 if i % 2 == 0 else -1.0
				s.append(_bez(Vector2(0, y), Vector2(side * 0.5, y - 0.05), Vector2(side * 0.6, y - 0.45), 8))
		21:  # snake
			var sn := _bez(Vector2(-0.85, 0.5), Vector2(-0.4, -1.0), Vector2(0.0, 0.0), 10)
			sn.append_array(_bez(Vector2(0.0, 0.0), Vector2(0.4, 1.0), Vector2(0.8, -0.4), 10))
			s.append(sn)
			s.append(_pl([0.8, -0.4]))
			if v & 1:
				s.append(_pl([0.8, -0.4, 0.95, -0.6]))
				s.append(_pl([0.8, -0.4, 1.0, -0.3]))
			if v & 2:
				s = _swap(s)
		22:  # bowl
			s.append(_arc(0, -0.1, 0.75, 0.7, 0.0, PI, 12))
			s.append(_pl([-0.75, -0.1, 0.75, -0.1]))
			if v & 1:
				s.append(_pl([0.0, 0.25]))
			if v & 2:
				s.append(_ell(0, -0.5, 0.2, 0.2, 12))
		23:  # horns around a disc
			s.append(_arc(0, -0.1, 0.8, 0.75, PI * 0.1, PI * 0.9, 12))
			s.append(_ell(0, -0.3, 0.28, 0.28, 14))
			if v & 1:
				s.append(_ell(0, -0.3, 0.12, 0.12, 10))
			if v & 2:
				s.append(_pl([-0.5, 0.88, 0.5, 0.88]))
		24:  # comb
			s.append(_pl([-0.9, 0.5, 0.9, 0.5]))
			var teeth := 4 + (v & 1) + (v >> 1)
			for i in teeth:
				var x := lerpf(-0.8, 0.8, float(i) / (teeth - 1))
				s.append(_pl([x, 0.5, x, -0.4 if (v < 2 or i % 2 == 0) else 0.0]))
		25:  # hourglass
			s.append(_poly([-0.6, -0.8, 0.6, -0.8, -0.6, 0.8, 0.6, 0.8], true))
			if v & 1:
				s.append(_pl([-0.85, -0.8, 0.85, -0.8]))
				s.append(_pl([-0.85, 0.8, 0.85, 0.8]))
			if v & 2:
				s.append(_pl([0.0, 0.55]))
		26:  # lattice
			if v < 2:
				s.append(_pl([-0.3, -0.85, -0.3, 0.85]))
				s.append(_pl([0.3, -0.85, 0.3, 0.85]))
				s.append(_pl([-0.85, -0.3, 0.85, -0.3]))
				s.append(_pl([-0.85, 0.3, 0.85, 0.3]))
				if v == 1:
					for p in [[-0.6, -0.6], [0.6, -0.6], [-0.6, 0.6], [0.6, 0.6]]:
						s.append(_pl(p))
			else:
				s.append(_pl([-0.7, -0.7, 0.7, 0.7]))
				s.append(_pl([0.7, -0.7, -0.7, 0.7]))
				s.append(_pl([0.0, 0.0] if v == 2 else [0.0, -0.85, 0.0, 0.85]))
		27:  # sunrise
			s.append(_pl([-0.9, 0.4, 0.9, 0.4]))
			s.append(_arc(0, 0.4, 0.55, 0.55, PI, TAU, 12))
			for i in 1 + v:
				var a := -PI / 2 + (i - v * 0.5) * 0.7
				s.append(_pl([0.7 * cos(a), 0.4 + 0.7 * sin(a), 0.98 * cos(a), 0.4 + 0.98 * sin(a)]))
		28:  # stairs
			var n := 3 + (v & 1)
			var st := PackedVector2Array([Vector2(-0.9, 0.8)])
			var x := -0.9
			var y := 0.8
			var dx := (1.8 if not (v & 2) else 0.9) / n
			var dy := 1.4 / n
			for i in n:
				y -= dy
				st.append(Vector2(x, y))
				x += dx
				st.append(Vector2(x, y))
			if v & 2:
				for i in n:
					st.append(Vector2(x, y))
					y += dy
					st.append(Vector2(x, y))
					x += dx
					st.append(Vector2(x, y))
			st.append(Vector2(x, 0.8))
			s.append(st)
		29:  # feather
			s.append(_bez(Vector2(0, 0.92), Vector2(0.35, 0.0), Vector2(0, -0.9), 12))
			var barbs := 4 + v
			for i in barbs:
				var t := (i + 1.0) / (barbs + 1)
				var q := Vector2(0, 0.92).lerp(Vector2(0.35, 0.0), t).lerp(Vector2(0.35, 0.0).lerp(Vector2(0, -0.9), t), t)
				var reach := 0.5 * (1.0 - absf(t - 0.5))
				s.append(_pl([q.x, q.y, q.x - reach, q.y - 0.3]))
				if v & 1 or i % 2 == 0:
					s.append(_pl([q.x, q.y, q.x + reach * 0.8, q.y - 0.25]))
		30:  # chevrons
			var n := 2 + (v & 1)
			var flip := -1.0 if v & 2 else 1.0
			for i in n:
				var y := (-0.45 + i * 0.5) * flip
				s.append(_pl([-0.7, y + 0.35 * flip, 0.0, y - 0.15 * flip, 0.7, y + 0.35 * flip]))
		31:  # lemniscate
			var lem := PackedVector2Array()
			for i in 33:
				var t := TAU * i / 32.0
				lem.append(Vector2(0.9 * sin(t), 0.75 * sin(t) * cos(t)))
			s.append(lem)
			if v & 2:
				s.append(_pl([0.0, 0.0]))
			if v & 1:
				s = _swap(s)
	return s

static func _rad_c(k: int, v: int) -> Array:
	var s: Array = []
	match k:
		32:  # arrow
			s.append(_pl([-0.85, 0.0, 0.85, 0.0]))
			s.append(_pl([0.4, -0.4, 0.85, 0.0, 0.4, 0.4]))
			if v & 1:
				s.append(_pl([0.1, -0.3, 0.5, 0.0, 0.1, 0.3]))
			if v & 2:
				s.append(_pl([-0.85, -0.35, -0.55, 0.0, -0.85, 0.35]))
		33:  # scarab
			s.append(_ell(0, 0.1, 0.5, 0.65))
			s.append(_arc(0, -0.55, 0.28, 0.22, PI, TAU, 8))
			for side in [-1.0, 1.0]:
				for y in [-0.1, 0.25, 0.6]:
					s.append(_pl([0.5 * side * 0.95, y, 0.9 * side, y + 0.2]))
			if v & 1:
				s.append(_pl([0.0, -0.4, 0.0, 0.75]))
			if v & 2:
				s.append(_pl([0.0, -0.55]))
		34:  # water
			var n := 2 + (v & 1) + (v >> 1)
			for j in n:
				var zz := PackedVector2Array()
				var y := lerpf(-0.45, 0.45, float(j) / maxf(1.0, n - 1.0)) if n > 1 else 0.0
				for i in 7:
					zz.append(Vector2(lerpf(-0.9, 0.9, i / 6.0), y + (0.17 if i % 2 else -0.17)))
				s.append(zz)
		35:  # lotus
			var mid := _bez(Vector2(0, 0.6), Vector2(-0.4, -0.15), Vector2(0, -0.85), 8)
			mid.append_array(_bez(Vector2(0, -0.85), Vector2(0.4, -0.15), Vector2(0, 0.6), 8))
			s.append(mid)
			s.append(_bez(Vector2(0, 0.6), Vector2(-0.95, 0.1), Vector2(-0.75, -0.5), 8))
			s.append(_bez(Vector2(0, 0.6), Vector2(0.95, 0.1), Vector2(0.75, -0.5), 8))
			s.append(_pl([-0.8, 0.8, 0.8, 0.8]))
			if v & 1:
				s.append(_bez(Vector2(0, 0.6), Vector2(-0.6, 0.45), Vector2(-0.95, 0.2), 6))
				s.append(_bez(Vector2(0, 0.6), Vector2(0.6, 0.45), Vector2(0.95, 0.2), 6))
		36:  # star
			s.append(_star([4, 5, 6, 8][v], 0.9, 0.38))
		37:  # polygon ring
			s.append(_ngon(5 + v, 0.82))
			if v & 1:
				s.append(_ell(0, 0, 0.3, 0.3, 14))
			else:
				s.append(_pl([0.0, 0.0]))
		38:  # brackets
			if v & 1:
				s.append(_arc(0.6, 0, 0.5, 0.85, PI * 0.55, PI * 1.45, 10))
				s.append(_arc(-0.6, 0, 0.5, 0.85, -PI * 0.45, PI * 0.45, 10))
			else:
				s.append(_pl([-0.35, -0.85, -0.8, -0.85, -0.8, 0.85, -0.35, 0.85]))
				s.append(_pl([0.35, -0.85, 0.8, -0.85, 0.8, 0.85, 0.35, 0.85]))
			s.append(_pl([0.0, 0.0]))
			if v & 2:
				s.append(_pl([0.0, -0.6, 0.0, 0.6]))
		39:  # double spiral
			s.append(_spiral(-0.45, 0, 0.05, 0.42, 1.3, 1.0))
			s.append(_spiral(0.45, 0, 0.05, 0.42, 1.3, -1.0))
			if v & 1:
				s.append(_pl([-0.85, 0.75, 0.85, 0.75]))
			if v & 2:
				s.append(_pl([0.0, -0.75]))
		40:  # fractal tree
			_tree(s, Vector2(0, 0.92), -PI / 2, 0.8, 2 + (v & 1), 0.45 + 0.2 * (v >> 1))
		41:  # bird
			s.append(_ell(-0.25, -0.4, 0.27, 0.27, 14))
			s.append(_poly([0.0, -0.5, 0.6, -0.33, 0.0, -0.25], false))
			s.append(_bez(Vector2(-0.45, -0.2), Vector2(-0.9, 0.8), Vector2(0.5, 0.65), 10))
			s.append(_pl([0.5, 0.65, 0.95, 0.9]))
			if v & 1:
				s.append(_pl([-0.4, -0.65, -0.65, -0.9]))
			if v & 2:
				s.append(_pl([-0.2, 0.55, -0.2, 0.95]))
			s.append(_pl([-0.2, -0.42]))
		42:  # key
			s.append(_ell(0, -0.55, 0.3, 0.3, 14))
			s.append(_pl([0.0, -0.25, 0.0, 0.92]))
			s.append(_pl([0.0, 0.62, 0.35, 0.62]))
			s.append(_pl([0.0, 0.9, 0.35, 0.9] if not (v & 1) else [0.0, 0.9, -0.35, 0.9]))
			if v & 2:
				s.append(_pl([0.0, -0.55]))
		43:  # rainbow
			for i in (2 if v == 0 else 3):
				var r := 0.85 - i * 0.27
				s.append(_arc(0, 0.6, r, r, PI, TAU, 12))
			if v & 2:
				s.append(_pl([-0.9, 0.6, 0.9, 0.6]))
		44:  # arch
			s.append(_pl([-0.65, 0.88, -0.65, 0.0]) + _arc(0, 0, 0.65, 0.65, PI, TAU, 12) + _pl([0.65, 0.0, 0.65, 0.88]))
			if v == 1:
				s.append(_arc(0, 0, 0.32, 0.32, PI, TAU, 8))
			elif v == 2:
				s.append(_pl([0.0, 0.3]))
			elif v == 3:
				s.append(_pl([0.0, -0.8]))
		45:  # cross of dots
			s.append(_pl([-0.5, 0.0, 0.5, 0.0]))
			s.append(_pl([0.0, -0.5, 0.0, 0.5]))
			for p in [[-0.65, -0.65], [0.65, -0.65], [-0.65, 0.65], [0.65, 0.65]]:
				if v == 0 or (v == 1 and p[0] < 0) or (v == 2 and p[1] < 0) or v == 3:
					s.append(_pl(p))
		46:  # drop
			s.append(_bez(Vector2(0, -0.9), Vector2(0.9, 0.3), Vector2(0, 0.85), 10) + _bez(Vector2(0, 0.85), Vector2(-0.9, 0.3), Vector2(0, -0.9), 10))
			if v == 1:
				s.append(_pl([0.0, 0.3]))
			elif v == 2:
				s.append(_bez(Vector2(-0.3, 0.1), Vector2(-0.35, 0.5), Vector2(-0.05, 0.6), 6))
			elif v == 3:
				s.append(_ell(0, 0.25, 0.25, 0.28, 10))
		47:  # chain
			if v & 2:
				s.append(_ell(-0.4, 0, 0.4, 0.4, 14))
				s.append(_ell(0.4, 0, 0.4, 0.4, 14))
				s.append(_pl([-0.4, 0.0, 0.4, 0.0]))
			else:
				for x in [-0.5, 0.0, 0.5]:
					s.append(_ell(x, 0, 0.32, 0.32, 12))
			if v & 1:
				s = _swap(s)
	return s

static func _tree(out: Array, base: Vector2, ang: float, length: float, depth: int, spread: float) -> void:
	var tip := base + Vector2(cos(ang), sin(ang)) * length
	out.append(PackedVector2Array([base, tip]))
	if depth <= 0:
		return
	_tree(out, tip, ang - spread, length * 0.62, depth - 1, spread)
	_tree(out, tip, ang + spread, length * 0.62, depth - 1, spread)
