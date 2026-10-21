class_name CreatureArt
extends RefCounted
## Procedural fractal creatures + the pack-grown hero body. Pure _draw helpers (call from any CanvasItem._draw).
## draw(ci, kind, center, size, t, hurt, scale_f)       -- enemies
## draw_player(ci, bp, hero_id, center, size, t, hurt, grow)
## pack_signature(bp) -> int

const TEAL := Color(0.10, 0.80, 0.62)
const DEEP := Color(0.02, 0.16, 0.18)
const VIOLET := Color(0.55, 0.30, 0.95)
const MAGENTA := Color(0.95, 0.30, 0.75)
const GOLD := Color(1.0, 0.82, 0.38)
const CYAN := Color(0.45, 0.95, 1.0)
const INK := Color(0.03, 0.03, 0.07)

static var _H := 0.0  # current hurt amount (set per draw call)

# ------------------------------------------------------------------ helpers
static func _c(c: Color, a := -1.0) -> Color:
	var o := c.lerp(Color(1, 0.9, 0.9), _H * 0.75)
	if a >= 0.0:
		o.a = a
	return o

static func _glow(ci: CanvasItem, p: Vector2, r: float, col: Color, a := 0.5, layers := 4) -> void:
	var n := layers + 3
	for i in n:
		var k := float(i + 1) / n
		ci.draw_circle(p, r * (1.25 - k * 0.95), _c(col, a * 0.16 * k))

static func _pts(ci: CanvasItem, pts: PackedVector2Array, fill: Color, rim: Color, w := 1.5) -> void:
	ci.draw_colored_polygon(pts, fill)
	var cl := pts.duplicate()
	cl.append(pts[0])
	ci.draw_polyline(cl, rim, w, true)

static func _rot(v: Vector2, a: float) -> Vector2:
	return v.rotated(a)

static func _eye(ci: CanvasItem, p: Vector2, r: float, col: Color, t: float) -> void:
	_glow(ci, p, r * 2.4, col, 0.5, 3)
	ci.draw_circle(p, r, _c(INK))
	ci.draw_circle(p + Vector2(sin(t * 1.3) * r * 0.25, 0), r * 0.55, _c(col))
	ci.draw_circle(p + Vector2(-r * 0.2, -r * 0.25), r * 0.2, _c(Color.WHITE, 0.9))

## Recursive self-similar branch: each tip forks into two smaller copies.
static func _branch(ci: CanvasItem, p: Vector2, ang: float, ln: float, depth: int, col: Color, tip: Color, t: float, w: float) -> void:
	var sway := sin(t * 1.4 + depth * 1.7 + p.x * 0.05) * 0.12
	var e := p + Vector2.from_angle(ang + sway) * ln
	ci.draw_line(p, e, _c(col), w, true)
	if depth <= 0:
		_glow(ci, e, w * 2.2, tip, 0.8, 3)
		ci.draw_circle(e, w * 0.9, _c(tip))
		return
	var spread := 0.5 + 0.12 * sin(t * 0.8 + depth)
	_branch(ci, e, ang + sway - spread, ln * 0.68, depth - 1, col, tip, t, w * 0.72)
	_branch(ci, e, ang + sway + spread, ln * 0.68, depth - 1, col, tip, t, w * 0.72)

static func _tri(ci: CanvasItem, a: Vector2, b: Vector2, d: Vector2, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([a, b, d]), col)

static func _hash(s: String) -> int:
	return absi(s.hash())

# ------------------------------------------------------------------ enemies
static func draw(ci: CanvasItem, kind: String, center: Vector2, size: float, t: float, hurt := 0.0, scale_f := 1.0) -> void:
	_H = clampf(hurt, 0.0, 1.0)
	var s := size * scale_f
	var shake := Vector2(sin(t * 90.0), cos(t * 77.0)) * _H * s * 0.04
	var c := center + shake
	match kind:
		"spore_sprout": _spore_sprout(ci, c, s, t)
		"thorn_crawler": _thorn_crawler(ci, c, s, t)
		"crystal_moth": _crystal_moth(ci, c, s, t)
		"glass_golem": _glass_golem(ci, c, s, t)
		"cascade_warden": _cascade_warden(ci, c, s, t)
		"mire_leech": _mire_leech(ci, c, s, t)
		"ember_wisp": _ember_wisp(ci, c, s, t)
		"mirror_wraith": _mirror_wraith(ci, c, s, t)
		"shard_hound": _shard_hound(ci, c, s, t)
		"prism_sentinel": _prism_sentinel(ci, c, s, t)
		"root_tyrant": _root_tyrant(ci, c, s, t)
		_: _spore_sprout(ci, c, s, t)
	_H = 0.0

static func _spore_sprout(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var bob := sin(t * 2.0) * s * 0.03
	var sq := 1.0 + sin(t * 2.0) * 0.04
	var b := c + Vector2(0, s * 0.12 + bob)
	_glow(ci, b, s * 0.5, TEAL, 0.5)
	# roots
	for i in 5:
		var a := PI * (0.15 + 0.175 * i)
		var e := b + Vector2(cos(a), sin(a) * 0.45) * s * 0.42
		ci.draw_line(b + Vector2(0, s * 0.2), e + Vector2(0, s * 0.18), _c(DEEP.lightened(0.15)), s * 0.03, true)
	# body bulb
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		var r := s * 0.32 * (1.0 + 0.06 * sin(a * 3.0 + t))
		pts.append(b + Vector2(cos(a) * r, sin(a) * r * 0.9 * sq))
	_pts(ci, pts, _c(Color(0.08, 0.45, 0.38)), _c(GOLD, 0.8), 1.5)
	ci.draw_circle(b + Vector2(-s * 0.1, -s * 0.1), s * 0.12, _c(TEAL, 0.35))
	# cap with spots
	var cap := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		cap.append(b + Vector2(cos(a) * s * 0.4, sin(a) * s * 0.3 - s * 0.14))
	_pts(ci, cap, _c(Color(0.35, 0.18, 0.62)), _c(MAGENTA, 0.9), 1.5)
	for i in 4:
		var a := PI * (1.2 + 0.2 * i)
		ci.draw_circle(b + Vector2(cos(a) * s * 0.24, sin(a) * s * 0.2 - s * 0.14), s * 0.03, _c(CYAN, 0.9))
	# fractal sprouts
	_branch(ci, b + Vector2(-s * 0.08, -s * 0.38), -PI * 0.5 - 0.5, s * 0.17, 2, TEAL, GOLD, t, s * 0.02)
	_branch(ci, b + Vector2(s * 0.12, -s * 0.38), -PI * 0.5 + 0.5, s * 0.2, 3, TEAL, MAGENTA, t + 1.0, s * 0.022)
	_eye(ci, b + Vector2(-s * 0.1, s * 0.02), s * 0.055, CYAN, t)
	_eye(ci, b + Vector2(s * 0.1, s * 0.02), s * 0.055, CYAN, t + 0.5)
	# spores
	for i in 6:
		var ph := fposmod(t * 0.25 + i * 0.167, 1.0)
		var sp := b + Vector2(sin(i * 2.4 + t) * s * 0.4, -s * 0.2 - ph * s * 0.6)
		ci.draw_circle(sp, s * 0.015 * (1.0 - ph) + 1.0, _c(GOLD, 0.8 * (1.0 - ph)))

static func _thorn_crawler(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var base := c + Vector2(0, s * 0.22)
	_glow(ci, base, s * 0.55, VIOLET, 0.35)
	var n := 6
	var segs: Array[Vector2] = []
	for i in n:
		var u := float(i) / (n - 1)
		segs.append(base + Vector2(lerpf(-s * 0.46, s * 0.4, u), -sin(u * PI) * s * 0.08 + sin(t * 3.0 - i * 0.9) * s * 0.025))
	# legs
	for i in n:
		var sp: Vector2 = segs[i]
		var ph := sin(t * 5.0 - i * 1.1)
		for sd in [-1, 1]:
			var foot := sp + Vector2(sd * s * 0.07 + ph * s * 0.03 * sd, s * 0.17 - maxf(0.0, ph) * s * 0.03)
			ci.draw_polyline(PackedVector2Array([sp + Vector2(0, s * 0.03), sp + Vector2(sd * s * 0.1, s * 0.07), foot]), _c(DEEP.lightened(0.25)), s * 0.018, true)
	# body segments (head last = right)
	for i in n:
		var r := s * (0.13 + 0.05 * sin(float(i) / (n - 1) * PI))
		var sp2: Vector2 = segs[i]
		ci.draw_circle(sp2, r * 1.15, _c(INK))
		ci.draw_circle(sp2, r, _c(Color(0.16, 0.38, 0.30).lerp(VIOLET, float(i) / n * 0.4)))
		ci.draw_arc(sp2, r, PI, TAU, 10, _c(GOLD, 0.7), 1.2, true)
		# thorn spikes (fractal: spike with two baby spikes)
		var tl := r * 1.2
		var tp := sp2 + Vector2(0, -r)
		var sway := sin(t * 2.0 + i) * 0.08
		_pts(ci, PackedVector2Array([tp + Vector2(-r * 0.3, 0), tp + Vector2(sway * r, -tl), tp + Vector2(r * 0.3, 0)]), _c(MAGENTA.darkened(0.2)), _c(GOLD, 0.8), 1.0)
		for sd in [-1, 1]:
			var bp: Vector2 = tp + Vector2(sd * r * 0.2, -tl * 0.4)
			ci.draw_line(bp, bp + Vector2(sd * tl * 0.35, -tl * 0.35), _c(GOLD, 0.8), 1.0, true)
	var head: Vector2 = segs[n - 1]
	_eye(ci, head + Vector2(s * 0.04, -s * 0.03), s * 0.045, MAGENTA, t)
	_eye(ci, head + Vector2(s * 0.04, s * 0.05), s * 0.03, MAGENTA, t + 1.0)
	for sd in [-1, 1]:
		ci.draw_line(head + Vector2(s * 0.1, 0), head + Vector2(s * 0.2, sd * s * 0.07 + sin(t * 6.0) * s * 0.02), _c(CYAN, 0.8), 1.5, true)

static func _crystal_moth(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var hov := sin(t * 2.2) * s * 0.05
	var b := c + Vector2(0, hov)
	var flap := 0.8 + 0.2 * sin(t * 9.0)
	_glow(ci, b, s * 0.6, CYAN, 0.45)
	for sd in [-1, 1]:
		# upper + lower crystalline wings (faceted fan of triangles)
		for wi in 2:
			var ang := (-0.55 if wi == 0 else 0.5)
			var ln := s * (0.8 if wi == 0 else 0.55)
			var tip := b + Vector2(sd * ln * flap, ang * ln * 0.9)
			var m1 := b + Vector2(sd * ln * 0.55 * flap, ang * ln * 0.2 - ln * 0.25)
			var m2 := b + Vector2(sd * ln * 0.6 * flap, ang * ln * 0.8 + ln * 0.15)
			var col := CYAN.lerp(VIOLET, 0.35 + 0.4 * wi)
			ci.draw_colored_polygon(PackedVector2Array([b, m1, tip]), _c(col, 0.35))
			ci.draw_colored_polygon(PackedVector2Array([b, tip, m2]), _c(col.lightened(0.2), 0.28))
			ci.draw_polyline(PackedVector2Array([b, m1, tip, m2, b]), _c(GOLD, 0.8), 1.2, true)
			ci.draw_line(b, tip, _c(Color.WHITE, 0.45), 1.0, true)
			ci.draw_circle(tip, s * 0.02, _c(Color.WHITE, 0.9))
	# body
	for i in 4:
		ci.draw_circle(b + Vector2(0, -s * 0.1 + i * s * 0.085), s * (0.05 - i * 0.006), _c(Color(0.12, 0.2, 0.4).lerp(CYAN, 0.1 * i)))
	ci.draw_circle(b + Vector2(0, -s * 0.14), s * 0.06, _c(INK))
	_eye(ci, b + Vector2(-s * 0.03, -s * 0.15), s * 0.025, MAGENTA, t)
	_eye(ci, b + Vector2(s * 0.03, -s * 0.15), s * 0.025, MAGENTA, t)
	for sd in [-1, 1]:
		_branch(ci, b + Vector2(sd * s * 0.03, -s * 0.2), -PI * 0.5 + sd * 0.7, s * 0.12, 2, CYAN, GOLD, t, s * 0.01)
	# siphon motes spiral inward
	for i in 5:
		var ph := fposmod(t * 0.4 + i * 0.2, 1.0)
		var a := i * 1.7 + t
		ci.draw_circle(b + Vector2(cos(a), sin(a)) * s * 0.6 * (1.0 - ph), 1.5 + (1.0 - ph) * 1.5, _c(GOLD, ph))

static func _glass_golem(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var b := c + Vector2(0, sin(t * 1.3) * s * 0.015)
	_glow(ci, b, s * 0.6, TEAL, 0.3)
	var glass := _c(Color(0.35, 0.8, 0.85), 0.28)
	var rim := _c(CYAN, 0.9)
	# legs
	for sd in [-1, 1]:
		_pts(ci, PackedVector2Array([b + Vector2(sd * s * 0.06, s * 0.2), b + Vector2(sd * s * 0.22, s * 0.2), b + Vector2(sd * s * 0.2, s * 0.44), b + Vector2(sd * s * 0.08, s * 0.44)]), glass, rim)
	# torso: hex shell
	var torso := PackedVector2Array([b + Vector2(-s * 0.28, -s * 0.2), b + Vector2(0, -s * 0.34), b + Vector2(s * 0.28, -s * 0.2), b + Vector2(s * 0.3, s * 0.12), b + Vector2(0, s * 0.26), b + Vector2(-s * 0.3, s * 0.12)])
	_pts(ci, torso, glass, rim, 2.0)
	# facets (self-similar inner hexes)
	for k in 3:
		var f := 0.72 - k * 0.2
		var inner := PackedVector2Array()
		for p in torso:
			inner.append(b + (p - b) * f)
		var cl := inner.duplicate()
		cl.append(inner[0])
		ci.draw_polyline(cl, _c(GOLD if k == 1 else CYAN, 0.35 + 0.1 * k), 1.0, true)
	# arms
	for sd in [-1, 1]:
		var sh := b + Vector2(sd * s * 0.3, -s * 0.15)
		var hand := b + Vector2(sd * s * 0.44, s * 0.14 + sin(t * 1.5 + sd) * s * 0.02)
		_pts(ci, PackedVector2Array([sh, sh + Vector2(sd * s * 0.1, s * 0.03), hand + Vector2(sd * s * 0.04, 0), hand + Vector2(-sd * s * 0.04, 0)]), glass, rim)
	# head
	_pts(ci, PackedVector2Array([b + Vector2(-s * 0.1, -s * 0.36), b + Vector2(0, -s * 0.5), b + Vector2(s * 0.1, -s * 0.36), b + Vector2(0, -s * 0.3)]), glass.lightened(0.1), rim)
	# the thing inside: pulsing core that taps
	var tap := pow(maxf(0.0, sin(t * 3.0)), 8.0)
	var core := b + Vector2(0, -s * 0.03)
	_glow(ci, core, s * (0.16 + tap * 0.05), MAGENTA, 0.8)
	ci.draw_circle(core, s * 0.05, _c(Color.WHITE, 0.9))
	ci.draw_arc(core, s * 0.1 + tap * s * 0.04, 0, TAU, 16, _c(GOLD, 0.7), 1.2, true)
	_eye(ci, b + Vector2(0, -s * 0.38), s * 0.025, MAGENTA, t)
	# cracks
	for i in 4:
		var a := -0.9 + i * 0.9
		var p0 := core + Vector2.from_angle(a) * s * 0.1
		ci.draw_polyline(PackedVector2Array([p0, p0 + Vector2.from_angle(a + 0.3) * s * 0.07, p0 + Vector2.from_angle(a - 0.2) * s * 0.14]), _c(Color.WHITE, 0.45 + tap * 0.4), 1.0, true)

static func _cascade_warden(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var b := c
	_glow(ci, b, s * 0.62, VIOLET, 0.35, 5)
	_glow(ci, b + Vector2(0, -s * 0.1), s * 0.4, TEAL, 0.35)
	# waterfalls rising upward
	for i in 14:
		var u := float(i) / 13.0
		var x := lerpf(-s * 0.42, s * 0.42, u)
		var ph := fposmod(t * 0.35 + i * 0.37, 1.0)
		var y0 := s * 0.42
		var top := -s * (0.35 + 0.35 * sin(u * PI))
		var y := lerpf(y0, top, ph)
		ci.draw_line(Vector2(x, y0) + b, Vector2(x, lerpf(y0, top, minf(1.0, ph + 0.35))) + b, _c(CYAN, 0.18 * (1.0 - ph) + 0.05), 1.5, true)
		ci.draw_line(Vector2(x, y) + b, Vector2(x, y - s * 0.07) + b, _c(CYAN, 0.8 * (1.0 - ph)), 2.0, true)
	# nested arches (fractal gate), each smaller & brighter
	for k in 5:
		var f := 1.0 - k * 0.17
		var col := TEAL.lerp(GOLD, k / 4.0)
		var r := s * 0.4 * f
		var ctr := b + Vector2(0, s * 0.18 - k * s * 0.02)
		ci.draw_arc(ctr, r, PI, TAU, 28, _c(col, 0.9), maxf(1.0, s * 0.025 * f), true)
		ci.draw_line(ctr + Vector2(-r, 0), ctr + Vector2(-r, s * 0.24 * f), _c(col, 0.7), maxf(1.0, s * 0.02 * f), true)
		ci.draw_line(ctr + Vector2(r, 0), ctr + Vector2(r, s * 0.24 * f), _c(col, 0.7), maxf(1.0, s * 0.02 * f), true)
	# robed body
	var robe := PackedVector2Array([b + Vector2(-s * 0.13, s * 0.4), b + Vector2(-s * 0.1, -s * 0.05), b + Vector2(0, -s * 0.12), b + Vector2(s * 0.1, -s * 0.05), b + Vector2(s * 0.13, s * 0.4)])
	_pts(ci, robe, _c(INK, 0.95), _c(GOLD, 0.9), 1.5)
	ci.draw_line(b + Vector2(0, -s * 0.1), b + Vector2(0, s * 0.4), _c(VIOLET, 0.8), 1.5, true)
	# head + three eyes + crown of counted rays
	var hd := b + Vector2(0, -s * 0.2)
	ci.draw_circle(hd, s * 0.075, _c(INK))
	ci.draw_arc(hd, s * 0.075, 0, TAU, 16, _c(GOLD), 1.5, true)
	_eye(ci, hd + Vector2(-s * 0.03, 0), s * 0.017, CYAN, t)
	_eye(ci, hd + Vector2(s * 0.03, 0), s * 0.017, CYAN, t)
	_eye(ci, hd + Vector2(0, -s * 0.035), s * 0.017, MAGENTA, t)
	for i in 9:
		var a := -PI + PI * (i + 0.5) / 9.0
		var l := s * (0.13 + 0.05 * (i % 2))
		ci.draw_line(hd + Vector2.from_angle(a) * s * 0.09, hd + Vector2.from_angle(a) * (s * 0.09 + l), _c(GOLD, 0.8), 1.5, true)
		ci.draw_circle(hd + Vector2.from_angle(a) * (s * 0.09 + l), 2.0, _c(Color.WHITE, 0.9))
	# arms that fork recursively
	for sd in [-1, 1]:
		_branch(ci, b + Vector2(sd * s * 0.08, -s * 0.05), -PI * 0.5 + sd * 1.0, s * 0.2, 3, VIOLET, CYAN, t + sd, s * 0.022)
	# orbiting counted runes
	for i in 6:
		var a := t * 0.5 + i * TAU / 6.0
		var p := b + Vector2(cos(a) * s * 0.5, sin(a) * s * 0.14 - s * 0.05)
		_glow(ci, p, s * 0.04, GOLD, 0.8, 3)
		ci.draw_circle(p, 2.0, _c(Color.WHITE))

# ------------------------------------------------------------------ hero
static func pack_signature(bp) -> int:
	if bp == null:
		return 0
	var parts: Array[String] = []
	for e in bp.placed:
		parts.append("%d:%s:%d,%d:%d" % [int(e.uid), String(e.id), int(e.pos.x), int(e.pos.y), int(e.rot)])
	parts.sort()
	return absi((",".join(parts)).hash()) + parts.size()

static func _hero_cols(hero_id: String) -> Array:
	if hero_id == "thoth":
		return [VIOLET, TEAL, Color(0.75, 0.55, 1.0)]
	return [GOLD, CYAN, Color(1.0, 0.92, 0.6)]

static func _organ_kind(id: String) -> String:
	var d: Dictionary = ItemDB.get_def(id)
	var tags: Array = d.get("tags", [])
	var ef := String(d.get("effect", {}).get("type", ""))
	if "cursed" in tags: return "eye"
	if "fractal" in tags: return "sprout"
	if ef == "heal" or "bloom" in tags: return "bloom"
	if ef == "energy" or "light" in tags: return "shard"
	if "armor" in tags or ef.begins_with("block") or ef.begins_with("turn_start_block"): return "plate"
	if "weapon" in tags or ef.begins_with("damage") or ef == "multi_damage": return "spike"
	return "orb"

static func _organ_color(id: String, hero: Array) -> Color:
	var d: Dictionary = ItemDB.get_def(id)
	var tags: Array = d.get("tags", [])
	var base := TEAL
	if "crystal" in tags: base = CYAN
	elif "bone" in tags: base = Color(0.92, 0.88, 0.75)
	elif "plant" in tags or "living" in tags: base = Color(0.3, 0.95, 0.55)
	elif "water" in tags: base = Color(0.3, 0.6, 1.0)
	elif "potion" in tags: base = MAGENTA
	var hv := float(_hash(id) % 100) / 100.0
	return base.lerp(hero[0], 0.15 + hv * 0.25)

static func _seed_form(ci: CanvasItem, hero_id: String, c: Vector2, r: float, t: float, hero: Array) -> void:
	var a: Color = hero[0]
	var b2: Color = hero[1]
	var hi: Color = hero[2]
	_glow(ci, c, r * 1.5, a, 0.55, 5)
	ci.draw_circle(c, r * 0.9, _c(INK, 0.9))
	if hero_id == "thoth":
		# ibis crescent + prism triangle
		var cres := PackedVector2Array()
		for i in 17:
			var an := -PI * 0.15 - PI * 1.3 * i / 16.0 + t * 0.15
			cres.append(c + Vector2.from_angle(an) * r * 0.85)
		for i in 17:
			var an2 := -PI * 0.15 - PI * 1.3 * (16 - i) / 16.0 + t * 0.15
			cres.append(c + Vector2.from_angle(an2) * r * (0.45 + 0.12 * sin(i * 0.4)))
		_pts(ci, cres, _c(a, 0.55), _c(hi, 0.95), 1.5)
		var tri := PackedVector2Array()
		for i in 3:
			tri.append(c + Vector2.from_angle(-PI * 0.5 + i * TAU / 3.0 - t * 0.2) * r * 0.5)
		_pts(ci, tri, _c(b2, 0.35), _c(b2.lightened(0.4), 0.95), 1.5)
		var tri2 := PackedVector2Array()
		for p in tri:
			tri2.append(c + (p - c) * 0.5)
		_pts(ci, tri2, _c(hi, 0.4), _c(Color.WHITE, 0.8), 1.0)
		# beak
		var bk := c + Vector2.from_angle(-PI * 0.15 + t * 0.15) * r * 0.85
		ci.draw_polyline(PackedVector2Array([bk, bk + Vector2(r * 0.25, r * 0.05), bk + Vector2(r * 0.4, r * 0.25)]), _c(GOLD), 2.0, true)
	else:
		# measuring spiral (phyllotaxis) + star lattice
		for k in 8:
			var an := TAU * k / 8.0 + t * 0.12
			ci.draw_line(c, c + Vector2.from_angle(an) * r * (0.95 if k % 2 == 0 else 0.6), _c(b2, 0.6), 1.2, true)
			ci.draw_line(c + Vector2.from_angle(an) * r * 0.95, c + Vector2.from_angle(an + TAU / 8.0 * 2.0) * r * (0.95 if k % 2 == 0 else 0.6), _c(a, 0.4), 1.0, true)
		for i in 22:
			var an3 := i * 2.39996 + t * 0.2
			var rr := r * 0.9 * sqrt((i + 1.0) / 22.0)
			ci.draw_circle(c + Vector2.from_angle(an3) * rr, 1.0 + r * 0.04 * (1.0 - float(i) / 22.0), _c(hi if i % 3 == 0 else a, 0.9))
	var pulse := 0.5 + 0.5 * sin(t * 2.0)
	_glow(ci, c, r * (0.28 + pulse * 0.06), Color.WHITE, 0.9, 3)
	ci.draw_arc(c, r * 0.95, 0, TAU, 40, _c(GOLD, 0.85), 1.6, true)

static func draw_player(ci: CanvasItem, bp, hero_id: String, center: Vector2, size: float, t: float, hurt := 0.0, grow := 1.0) -> void:
	_H = clampf(hurt, 0.0, 1.0)
	var hero := _hero_cols(hero_id)
	var g := clampf(grow, 0.0, 1.0)
	var eg := g * g * (3.0 - 2.0 * g)
	var shake := Vector2(sin(t * 90.0), cos(t * 77.0)) * _H * size * 0.03
	var c := center + shake + Vector2(0, sin(t * 1.6) * size * 0.02)
	var core_r := size * 0.26 * (0.6 + 0.4 * eg)
	var organs: Array = []  # {uid, pos, ang, kind, col, id, r}
	var gw := 5.0
	var gh := 4.0
	var items: Array[int] = []
	if bp != null:
		gw = float(bp.w)
		gh = float(bp.h)
		items = bp.uids()
	var by_uid := {}
	var n := items.size()
	for idx in n:
		var uid: int = items[idx]
		var id: String = bp.id_of(uid)
		var cells: Array = bp.cells_of(uid)
		var cen := Vector2.ZERO
		for cc in cells:
			cen += Vector2(cc.x + 0.5, cc.y + 0.5)
		cen /= maxf(1.0, cells.size())
		var rel := cen - Vector2(gw, gh) * 0.5
		var h := _hash(id)
		var ang := rel.angle() if rel.length() > 0.35 else (h % 628) / 100.0
		# spread organs so they don't overlap: nudge by index
		ang += (float(idx) / maxf(1.0, n) - 0.5) * 0.25
		var dist := size * (0.62 + 0.1 * float(h % 5) / 4.0 + minf(rel.length(), 3.0) * 0.03)
		var o := {"uid": uid, "id": id, "ang": ang, "kind": _organ_kind(id), "col": _organ_color(id, hero), "dist": dist, "size": float(cells.size())}
		organs.append(o)
		by_uid[uid] = o
	# wide aura
	_glow(ci, c, size * (0.55 + 0.15 * eg + 0.02 * n), hero[1], 0.28, 6)
	# resonance links first (under organs)
	var seen := {}
	for o in organs:
		var pa: Vector2 = c + Vector2.from_angle(float(o.ang) + sin(t * 0.7) * 0.05) * float(o.dist) * eg
		o["pos"] = pa
	for o in organs:
		for nu in bp.neighbors(int(o.uid)):
			var key := "%d_%d" % [mini(int(o.uid), nu), maxi(int(o.uid), nu)]
			if seen.has(key) or not by_uid.has(nu):
				continue
			seen[key] = true
			var o2: Dictionary = by_uid[nu]
			var p1: Vector2 = o.pos
			var p2: Vector2 = o2.pos
			var mid := (p1 + p2) * 0.5
			var bulge := (mid - c).normalized() * size * 0.12 + (mid - c) * 0.1
			var ctrl := mid + bulge
			var pl := PackedVector2Array()
			for i in 11:
				var u := float(i) / 10.0
				pl.append(p1.lerp(ctrl, u).lerp(ctrl.lerp(p2, u), u))
			var pulse := 0.6 + 0.4 * sin(t * 3.0 + p1.x * 0.02)
			ci.draw_polyline(pl, _c(hero[1], 0.18 * eg), 6.0, true)
			ci.draw_polyline(pl, _c(hero[2], 0.85 * eg * pulse), 1.5, true)
			var bead := pl[int(fposmod(t * 4.0 + p1.y * 0.03, 1.0) * 10.0)]
			_glow(ci, bead, size * 0.035, Color.WHITE, 0.9 * eg, 3)
	# tethers from core to organs
	for o in organs:
		var p: Vector2 = o.pos
		var col: Color = o.col
		ci.draw_line(c, c.lerp(p, eg), _c(col, 0.45), 2.0, true)
	# core
	_seed_form(ci, hero_id, c, core_r * 1.6, t, hero)
	# organs
	for o in organs:
		_organ(ci, o, c, size * 0.27 * (0.8 + 0.08 * float(o.size)) * eg, t, hero)
	# growth rings: faint fractal echo, more rings for fuller packs
	for k in mini(n, 4):
		ci.draw_arc(c, size * (0.42 + 0.07 * k) * eg, t * 0.2 * (k + 1) * (1 if k % 2 == 0 else -1), t * 0.2 * (k + 1) * (1 if k % 2 == 0 else -1) + PI * 0.5, 14, _c(hero[0], 0.35), 1.0, true)
	_H = 0.0

static func _organ(ci: CanvasItem, o: Dictionary, c: Vector2, r: float, t: float, hero: Array) -> void:
	var p: Vector2 = o.pos
	var out: Vector2 = (p - c).normalized() if (p - c).length() > 0.1 else Vector2.RIGHT
	var ang := out.angle()
	var col: Color = o.col
	var hi: Color = hero[2]
	var ph := float(_hash(String(o.id)) % 100) * 0.1
	_glow(ci, p, r * 1.1, col, 0.5, 3)
	match String(o.kind):
		"spike":
			# three-bladed fractal thorn
			for k in 3:
				var a := ang + (k - 1) * 0.5
				var ln := r * (1.7 if k == 1 else 1.1)
				var base := p + Vector2.from_angle(a + PI) * r * 0.1
				var tip := p + Vector2.from_angle(a) * ln
				var side := Vector2.from_angle(a + PI * 0.5) * r * 0.2
				_pts(ci, PackedVector2Array([base + side, tip, base - side]), _c(col.darkened(0.25)), _c(hi, 0.95), 1.2)
				ci.draw_line(base, tip, _c(Color.WHITE, 0.6), 1.0, true)
			ci.draw_circle(p, r * 0.3, _c(INK))
			ci.draw_arc(p, r * 0.3, 0, TAU, 10, _c(GOLD), 1.2, true)
		"plate":
			for k in 3:
				var rr := r * (1.0 - k * 0.22)
				var a0 := ang - 1.0 + sin(t + ph) * 0.05
				ci.draw_arc(p, rr, a0, a0 + 2.0, 10, _c(col.lightened(k * 0.15), 0.9), maxf(1.5, r * 0.22 - k * 2.0), true)
			ci.draw_arc(p, r * 1.1, ang - 1.05, ang + 1.05, 10, _c(GOLD, 0.9), 1.2, true)
			ci.draw_circle(p, r * 0.22, _c(hi, 0.9))
		"bloom":
			var pet := 6
			for k in pet:
				var a := TAU * k / pet + t * 0.3 + ph
				var br := 1.0 + 0.12 * sin(t * 2.0 + k)
				var pa := p + Vector2.from_angle(a) * r * 0.65 * br
				_pts(ci, PackedVector2Array([p, pa + Vector2.from_angle(a + 1.57) * r * 0.25, p + Vector2.from_angle(a) * r * 1.1 * br, pa + Vector2.from_angle(a - 1.57) * r * 0.25]), _c(col.lerp(MAGENTA, 0.5), 0.75), _c(hi, 0.7), 1.0)
			ci.draw_circle(p, r * 0.25, _c(GOLD))
		"shard":
			for k in 3:
				var a := t * (0.9 + 0.3 * k) + ph + k * TAU / 3.0
				var sp := p + Vector2.from_angle(a) * r * (0.9 + 0.2 * k)
				var d := Vector2.from_angle(a + PI * 0.5)
				_pts(ci, PackedVector2Array([sp + d * r * 0.3, sp + Vector2.from_angle(a) * r * 0.22, sp - d * r * 0.3, sp - Vector2.from_angle(a) * r * 0.22]), _c(col.lightened(0.2), 0.85), _c(Color.WHITE, 0.9), 1.0)
				_glow(ci, sp, r * 0.3, col, 0.6, 2)
			ci.draw_arc(p, r * 0.95, 0, TAU, 20, _c(col, 0.35), 1.0, true)
			ci.draw_circle(p, r * 0.25, _c(Color.WHITE, 0.9))
		"eye":
			ci.draw_circle(p, r * 0.8, _c(INK))
			ci.draw_arc(p, r * 0.8, 0, TAU, 14, _c(col), 1.6, true)
			for k in 6:
				var a := TAU * k / 6.0 + t * 0.4 + ph
				ci.draw_line(p + Vector2.from_angle(a) * r * 0.8, p + Vector2.from_angle(a) * r * 1.35, _c(hi, 0.85), 1.2, true)
			ci.draw_circle(p, r * 0.32, _c(col.lightened(0.3)))
			ci.draw_circle(p, r * 0.13, _c(INK))
		"sprout":
			_branch(ci, p, ang, r * 0.9, 3, col, hi, t + ph, maxf(1.5, r * 0.14))
			ci.draw_circle(p, r * 0.22, _c(GOLD))
		_:
			ci.draw_circle(p, r * 0.7, _c(INK))
			ci.draw_arc(p, r * 0.7, 0, TAU, 14, _c(col), 1.6, true)
			ci.draw_arc(p, r * 0.45, t + ph, t + ph + 4.0, 10, _c(hi, 0.8), 1.2, true)
			ci.draw_circle(p, r * 0.18, _c(col.lightened(0.4)))


# ------------------------------------------------------------------ v2 enemies
static func _mire_leech(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var base := c + Vector2(0, s * 0.15)
	_glow(ci, base, s * 0.5, TEAL, 0.4)
	var segs: Array[Vector2] = []
	for i in 9:
		var f := float(i) / 8.0
		segs.append(base + Vector2(lerpf(-s * 0.4, s * 0.3, f), sin(f * 5.0 + t * 3.0) * s * 0.08 - sin(f * PI) * s * 0.12))
	for i in 9:
		var f := float(i) / 8.0
		var r := s * (0.05 + 0.09 * sin(f * PI * 0.9 + 0.2))
		ci.draw_circle(segs[i], r, _c(Color(0.04, 0.22, 0.24).lerp(Color(0.08, 0.4, 0.4), f)))
		ci.draw_arc(segs[i], r, 0, TAU, 12, _c(TEAL, 0.7), 1.2, true)
	# ringed mouth with siphon glow
	var m := segs[8] + Vector2(s * 0.05, 0)
	_glow(ci, m, s * 0.18, CYAN, 0.6, 3)
	for k in 3:
		ci.draw_arc(m, s * (0.12 - 0.03 * k), 0, TAU, 14, _c(GOLD if k == 1 else VIOLET, 0.9), 1.4, true)
	ci.draw_circle(m, s * 0.025, _c(INK))
	for i in 5:
		var ph := fposmod(t * 0.7 + i * 0.2, 1.0)
		ci.draw_circle(m + Vector2(s * 0.3 * ph, -s * 0.05 * ph), 1.5, _c(CYAN, 0.8 * ph))
	_eye(ci, segs[6] + Vector2(0, -s * 0.07), s * 0.025, GOLD, t)

static func _ember_wisp(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var b := c + Vector2(0, sin(t * 2.5) * s * 0.05)
	_glow(ci, b, s * 0.55, GOLD, 0.5, 5)
	_glow(ci, b, s * 0.35, VIOLET, 0.35, 3)
	var fl := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		var tip := 1.0 + (0.9 * pow(maxf(0.0, -sin(a)), 3.0)) * (1.0 + 0.15 * sin(t * 6.0 + i))
		fl.append(b + Vector2(cos(a) * s * 0.18, sin(a) * s * 0.2 * tip + (-s * 0.02 if sin(a) < 0 else 0.0)))
	_pts(ci, fl, _c(Color(1.0, 0.55, 0.15, 0.9)), _c(GOLD, 0.95), 1.4)
	var inner := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		var tip := 1.0 + 0.7 * pow(maxf(0.0, -sin(a)), 3.0)
		inner.append(b + Vector2(cos(a) * s * 0.09, sin(a) * s * 0.1 * tip))
	ci.draw_colored_polygon(inner, _c(Color(1, 0.95, 0.7)))
	# face-less glyph core (counted nested rings)
	for k in 3:
		ci.draw_arc(b + Vector2(0, s * 0.02), s * (0.12 - 0.03 * k), t * (1 + k) * 0.8, t * (1 + k) * 0.8 + 4.0, 10, _c(VIOLET, 0.9), 1.3, true)
	for i in 5:
		var ph := fposmod(t * 0.4 + i * 0.2, 1.0)
		ci.draw_circle(b + Vector2(sin(i * 3.1 + t) * s * 0.15, -s * 0.2 - ph * s * 0.4), 1.5, _c(GOLD, 0.8 * (1.0 - ph)))

static func _mirror_wraith(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var b := c
	_glow(ci, b, s * 0.55, Color(0.5, 0.8, 0.9), 0.35, 4)
	var hood := PackedVector2Array([b + Vector2(-s * 0.3, s * 0.42), b + Vector2(-s * 0.2, -s * 0.1), b + Vector2(-s * 0.08, -s * 0.34), b + Vector2(s * 0.08, -s * 0.34), b + Vector2(s * 0.2, -s * 0.1), b + Vector2(s * 0.3, s * 0.42), b + Vector2(s * 0.12, s * 0.34), b + Vector2(0, s * 0.44), b + Vector2(-s * 0.12, s * 0.34)])
	_pts(ci, hood, _c(Color(0.55, 0.72, 0.78, 0.85)), _c(Color(0.9, 1, 1), 0.95), 1.6)
	# glass facets
	for i in 4:
		var x := -s * 0.15 + i * s * 0.1
		ci.draw_line(b + Vector2(x, -s * 0.2 + (i % 2) * s * 0.1), b + Vector2(x * 1.6, s * 0.36), _c(Color.WHITE, 0.3), 1.0, true)
	# reflected silhouette: a little dark figure inside the hood
	var fy := b + Vector2(sin(t * 1.2) * s * 0.01, s * 0.05)
	ci.draw_circle(fy + Vector2(0, -s * 0.12), s * 0.05, _c(INK, 0.9))
	ci.draw_colored_polygon(PackedVector2Array([fy + Vector2(-s * 0.08, s * 0.2), fy + Vector2(0, -s * 0.06), fy + Vector2(s * 0.08, s * 0.2)]), _c(INK, 0.9))
	_eye(ci, b + Vector2(-s * 0.05, -s * 0.15), s * 0.018, CYAN, t)
	_eye(ci, b + Vector2(s * 0.05, -s * 0.15), s * 0.018, CYAN, t + 0.7)
	# thorny reflections
	for sd in [-1, 1]:
		for k in 3:
			var p := b + Vector2(float(sd) * s * (0.22 + 0.04 * k), -s * 0.05 + k * s * 0.13)
			var a: float = (-PI * 0.5 + sd * (0.7 + 0.25 * k)) + sin(t + k) * 0.05
			_pts(ci, PackedVector2Array([p + Vector2(0, -s * 0.03), p + Vector2.from_angle(a) * s * 0.2, p + Vector2(0, s * 0.03)]), _c(Color(0.7, 0.9, 1.0, 0.6)), _c(CYAN, 0.9), 1.0)
	ci.draw_arc(b + Vector2(0, -s * 0.34), s * 0.1, PI * 1.1, PI * 1.9, 8, _c(GOLD, 0.9), 1.4, true)

static func _shard_hound(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var b := c + Vector2(0, s * 0.15)
	_glow(ci, b, s * 0.55, CYAN, 0.35, 4)
	var bob := sin(t * 3.0) * s * 0.01
	# four legs
	for i in 4:
		var x := -s * 0.28 + i * s * 0.17 + (s * 0.04 if i > 1 else 0.0)
		var sw := sin(t * 3.0 + i * 1.6) * s * 0.03
		var f := b + Vector2(x, s * 0.05)
		var p := f + Vector2(sw, s * 0.28)
		ci.draw_line(f, p, _c(Color(0.12, 0.45, 0.55)), s * 0.045, true)
		_tri(ci, p + Vector2(-s * 0.03, 0), p + Vector2(s * 0.05, 0), p + Vector2(s * 0.01, -s * 0.06), _c(CYAN, 0.9))
	# body
	var body := PackedVector2Array([b + Vector2(-s * 0.36, -s * 0.02 + bob), b + Vector2(-s * 0.2, -s * 0.14), b + Vector2(s * 0.15, -s * 0.12), b + Vector2(s * 0.34, -s * 0.04), b + Vector2(s * 0.3, s * 0.1), b + Vector2(-s * 0.3, s * 0.12)])
	_pts(ci, body, _c(Color(0.05, 0.22, 0.3)), _c(CYAN, 0.9), 1.5)
	# jagged shard fur (self-similar: each shard has a smaller one)
	for i in 9:
		var x := -s * 0.3 + i * s * 0.07
		var h := s * (0.12 + 0.07 * ((i * 5) % 3)) * (1.0 + 0.1 * sin(t * 4.0 + i))
		var bx := b + Vector2(x, -s * 0.13 + (s * 0.03 if i > 6 else 0.0))
		_pts(ci, PackedVector2Array([bx + Vector2(-s * 0.03, 0), bx + Vector2(s * 0.01, -h), bx + Vector2(s * 0.035, 0)]), _c(CYAN.darkened(0.3), 0.85), _c(Color.WHITE, 0.8), 1.0)
		_tri(ci, bx + Vector2(0, -h * 0.5), bx + Vector2(s * 0.03, -h * 0.65), bx + Vector2(0.0, -h * 0.9), _c(GOLD, 0.6))
	# head
	var h0 := b + Vector2(s * 0.36, -s * 0.06)
	_pts(ci, PackedVector2Array([h0 + Vector2(-s * 0.06, -s * 0.1), h0 + Vector2(s * 0.2, -s * 0.02), h0 + Vector2(s * 0.2, s * 0.05), h0 + Vector2(-s * 0.02, s * 0.1)]), _c(Color(0.08, 0.35, 0.45)), _c(GOLD, 0.9), 1.4)
	_tri(ci, h0 + Vector2(-s * 0.04, -s * 0.1), h0 + Vector2(s * 0.03, -s * 0.2), h0 + Vector2(s * 0.06, -s * 0.07), _c(CYAN))
	_eye(ci, h0 + Vector2(s * 0.06, -s * 0.03), s * 0.025, GOLD, t)
	# ringing arcs
	for k in 3:
		var ph := fposmod(t * 0.8 + k / 3.0, 1.0)
		ci.draw_arc(h0 + Vector2(s * 0.1, 0), s * (0.1 + 0.3 * ph), -0.7, 0.7, 10, _c(CYAN, 0.6 * (1.0 - ph)), 1.3, true)

static func _prism_sentinel(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var b := c + Vector2(0, sin(t * 1.2) * s * 0.015)
	_glow(ci, b, s * 0.7, VIOLET, 0.4, 5)
	_glow(ci, b + Vector2(0, s * 0.3), s * 0.35, Color(0, 0, 0), 0.5, 3)
	var cols := [CYAN, GOLD, VIOLET, MAGENTA, TEAL]
	var rot := t * 0.5
	var n := 5
	# rotating faceted column: 5 faces as slivers across a hexagonal prism
	for i in n:
		var a0 := rot + TAU * i / n
		var a1 := rot + TAU * (i + 1) / n
		var x0 := sin(a0) * s * 0.2
		var x1 := sin(a1) * s * 0.2
		if cos(a0) + cos(a1) < -0.1:
			continue
		var vis := clampf((cos((a0 + a1) * 0.5) + 1.0) * 0.5, 0.25, 1.0)
		var col: Color = cols[i]
		var face := PackedVector2Array([b + Vector2(x0, -s * 0.3), b + Vector2(x1, -s * 0.3), b + Vector2(x1, s * 0.3), b + Vector2(x0, s * 0.3)])
		ci.draw_colored_polygon(face, _c(col.darkened(0.4), 0.55 + 0.35 * vis))
		ci.draw_polyline(face, _c(col.lightened(0.3), 0.9), 1.6, true)
		# brittle seam
		ci.draw_line(b + Vector2(lerpf(x0, x1, 0.3), -s * 0.3), b + Vector2(lerpf(x0, x1, 0.6), s * 0.05), _c(Color.WHITE, 0.6), 1.0, true)
	# pyramid caps (menacing spires)
	_pts(ci, PackedVector2Array([b + Vector2(-s * 0.2, -s * 0.3), b + Vector2(0, -s * 0.56), b + Vector2(s * 0.2, -s * 0.3)]), _c(CYAN.darkened(0.3), 0.9), _c(Color.WHITE, 0.95), 1.6)
	_pts(ci, PackedVector2Array([b + Vector2(-s * 0.2, s * 0.3), b + Vector2(0, s * 0.52), b + Vector2(s * 0.2, s * 0.3)]), _c(VIOLET.darkened(0.3), 0.9), _c(GOLD, 0.95), 1.6)
	# razor shards orbiting
	for k in 6:
		var a := t * 0.9 + k * TAU / 6.0
		var p := b + Vector2(cos(a) * s * 0.42, sin(a) * s * 0.12 - s * 0.05 + (k % 2) * s * 0.1)
		_tri(ci, p + Vector2(0, -s * 0.07), p + Vector2(s * 0.025, s * 0.03), p + Vector2(-s * 0.025, s * 0.03), _c(cols[k % 5], 0.9))
	# single hard core + glare
	_glow(ci, b + Vector2(0, -s * 0.05), s * 0.1, Color.WHITE, 0.9, 4)
	ci.draw_circle(b + Vector2(0, -s * 0.05), s * 0.025, _c(Color.WHITE))
	ci.draw_arc(b, s * 0.46, -0.4, 0.4 + sin(t) * 0.2, 12, _c(GOLD, 0.7), 1.5, true)

static func _root_tyrant(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var b := c + Vector2(0, s * 0.05)
	_glow(ci, b, s * 0.65, Color(0.1, 0.5, 0.3), 0.4, 5)
	_glow(ci, b + Vector2(0, -s * 0.1), s * 0.4, VIOLET, 0.3, 3)
	# colossal fractal root-arms
	for i in 7:
		var a := -PI * 0.5 + (i - 3) * 0.48
		_branch(ci, b + Vector2((i - 3) * s * 0.05, -s * 0.05), a, s * 0.22, 3, Color(0.16, 0.3, 0.12), GOLD if i % 2 == 0 else VIOLET, t + i, s * 0.045)
	# lower roots gripping the ground
	for i in 5:
		var a := PI * (0.1 + 0.2 * i)
		_branch(ci, b + Vector2(0, s * 0.25), a, s * 0.14, 2, Color(0.12, 0.22, 0.1), TEAL, t * 0.5 + i, s * 0.04)
	# gnarled trunk body
	var tr := PackedVector2Array()
	for i in 22:
		var a := TAU * i / 22.0
		var r := s * (0.27 + 0.05 * sin(a * 5.0 + 1.0) + 0.02 * sin(t + a * 3.0))
		tr.append(b + Vector2(cos(a) * r, sin(a) * r * 1.05))
	_pts(ci, tr, _c(Color(0.1, 0.12, 0.06)), _c(Color(0.45, 0.65, 0.25), 0.9), 2.0)
	for i in 5:
		var x := -s * 0.18 + i * s * 0.09
		ci.draw_line(b + Vector2(x, -s * 0.22), b + Vector2(x * 1.2 + sin(i) * s * 0.03, s * 0.24), _c(Color(0.3, 0.45, 0.15), 0.6), 1.5, true)
	# crown of thorns
	for i in 9:
		var a := -PI + PI * (i + 0.5) / 9.0
		var p := b + Vector2.from_angle(a) * s * 0.27
		_tri(ci, p + Vector2.from_angle(a + 1.57) * s * 0.025, p + Vector2.from_angle(a) * s * (0.12 + 0.05 * (i % 2)), p + Vector2.from_angle(a - 1.57) * s * 0.025, _c(Color(0.5, 0.45, 0.2)))
	# tiny buried eyes
	for e in [Vector2(-0.1, -0.06), Vector2(0.09, -0.08), Vector2(0.0, 0.03), Vector2(-0.14, 0.08), Vector2(0.13, 0.06)]:
		_eye(ci, b + e * s, s * 0.016, GOLD if e.x < 0.0 else VIOLET, t + e.x * 5.0)
	# slow hanging spores
	for i in 4:
		var ph := fposmod(t * 0.2 + i * 0.25, 1.0)
		ci.draw_circle(b + Vector2(sin(i * 2.0) * s * 0.35, -s * 0.2 + ph * s * 0.6), 2.0, _c(GOLD, 0.7 * (1.0 - ph)))
