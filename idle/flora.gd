class_name Flora
extends RefCounted
## Procedural garden plants. Geometry is BAKED once per variant (static cache, deterministic by index) in local space
## (base at (0,0), up = -y, ~60 px tall); per frame only a transform (grow-in, sway, mirror) and a few draw calls are used.
## Sprouts: tapered curved stem, plump cotyledons, true leaves with midrib + veins, back-lit translucent tissue, dew drops.

const GOLD := Color(0.93, 0.80, 0.52)
const TEAL := Color(0.15, 0.85, 0.75)
const CYAN := Color(0.45, 0.95, 1.0)
const VIOLET := Color(0.66, 0.38, 1.0)

static var _sprouts := {}
static var _ferns := {}
static var _trees := {}


static func _dir(a: float) -> Vector2:
	return Vector2(sin(a), -cos(a))


static func _lerp3(t: float, a: Color, b: Color, c: Color) -> Color:
	return a.lerp(b, minf(t * 2.0, 1.0)).lerp(c, maxf(t * 2.0 - 1.0, 0.0))


## A leaf (outline polygon with per-vertex colours, inner glow polygon, midrib, veins, centre).
static func _leaf(base: Vector2, ang: float, length: float, wid: float, curl: float, plump: float) -> Dictionary:
	var d := _dir(ang)
	var perp := Vector2(-d.y, d.x)
	var n := 10
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var inl := PackedVector2Array()
	var inr := PackedVector2Array()
	var cols := PackedColorArray()
	var mid := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		var c := base + d * length * t + perp * curl * length * sin(PI * t) * 0.3
		var w := wid * sin(PI * pow(t, plump)) * 0.5
		mid.append(c)
		left.append(c + perp * w)
		right.append(c - perp * w)
		if t > 0.08 and t < 0.92:
			inl.append(c + perp * w * 0.5)
			inr.append(c - perp * w * 0.5)
		cols.append(_lerp3(t, Color(0.10, 0.42, 0.28, 0.96), Color(0.30, 0.80, 0.46, 0.92), Color(0.62, 1.0, 0.72, 0.88)))
	var poly := PackedVector2Array()
	poly.append_array(left)
	var rr := right.duplicate()
	rr.reverse()
	poly.append_array(rr)
	var pc := PackedColorArray()
	pc.append_array(cols)
	var cr := cols.duplicate()
	cr.reverse()
	pc.append_array(cr)
	var inner := PackedVector2Array()
	inner.append_array(inl)
	var ir := inr.duplicate()
	ir.reverse()
	inner.append_array(ir)
	var veins := PackedVector2Array()
	for i in range(2, n - 1, 2):
		var t := float(i) / n
		veins.append(mid[i])
		veins.append(left[i + 1].lerp(mid[i + 1], 0.12))
		veins.append(mid[i])
		veins.append(right[i + 1].lerp(mid[i + 1], 0.12))
	return {"poly": poly, "cols": pc, "inner": inner, "mid": mid, "veins": veins, "center": base + d * length * 0.5}


static func sprout(i: int) -> Dictionary:
	var v := i % 6
	if _sprouts.has(v):
		return _sprouts[v]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7700 + v * 131
	var L := 52.0 + rng.randf() * 16.0
	var bend := (0.22 + rng.randf() * 0.25) * (1.0 if v % 2 == 0 else -1.0)
	var p0 := Vector2.ZERO
	var p1 := Vector2(bend * L * 0.45, -L * 0.55)
	var p2 := Vector2(bend * L * 0.55, -L)
	var pts: Array[Vector2] = []
	for k in 9:
		var s := float(k) / 8.0
		pts.append(p0.lerp(p1, s).lerp(p1.lerp(p2, s), s))
	var sl := PackedVector2Array()
	var sr := PackedVector2Array()
	var scol := PackedColorArray()
	for k in 9:
		var s := float(k) / 8.0
		var tan := (pts[mini(k + 1, 8)] - pts[maxi(k - 1, 0)]).normalized()
		var nrm := Vector2(-tan.y, tan.x)
		var w := lerpf(2.8, 1.0, s)
		sl.append(pts[k] + nrm * w)
		sr.append(pts[k] - nrm * w)
		scol.append(Color(0.70, 0.88, 0.55).lerp(Color(0.30, 0.82, 0.58), s))
	var spoly := PackedVector2Array()
	spoly.append_array(sl)
	var srr := sr.duplicate()
	srr.reverse()
	spoly.append_array(srr)
	var spc := PackedColorArray()
	spc.append_array(scol)
	var sc2 := scol.duplicate()
	sc2.reverse()
	spc.append_array(sc2)
	var leaves: Array[Dictionary] = []
	var at_c := pts[4]
	var at_u := pts[6]
	var top := pts[8]
	var j := rng.randf_range(-0.12, 0.12)
	# plump cotyledons (seed leaves), true leaves above, small terminal leaf
	leaves.append(_leaf(at_c, -1.25 + j, 19.0, 11.0, 0.35, 0.9))
	leaves.append(_leaf(at_c, 1.25 - j, 19.0, 11.0, -0.35, 0.9))
	leaves.append(_leaf(at_u, -0.82 + j, 25.0 + rng.randf() * 4.0, 10.0, 0.25, 0.7))
	leaves.append(_leaf(at_u, 0.9 - j, 23.0 + rng.randf() * 4.0, 9.5, -0.25, 0.7))
	leaves.append(_leaf(top, -0.1 + j, 18.0, 7.5, 0.15, 0.7))
	var dew: Array[Vector3] = []     # x, y, radius
	for li in [1, 2, 4]:
		var m: PackedVector2Array = leaves[li]["mid"]
		var q := m[4 + rng.randi() % 2]
		dew.append(Vector3(q.x + rng.randf_range(-1.5, 1.5), q.y + 1.0, rng.randf_range(1.9, 3.0)))
	var out := {"stem": spoly, "stem_cols": spc, "leaves": leaves, "dew": dew, "top": top, "h": L}
	_sprouts[v] = out
	return out


## Sprout at ground point `p`; gp = grow-in 0..1 (back-eased), sc = size, flip = +-1, phase = sway offset.
static func draw_sprout(ci: CanvasItem, glow: CanvasItem, p: Vector2, v: Dictionary, gp: float, sc: float, flip: float, t: float, phase: float, light: float) -> void:
	var sway := sin(t * 1.15 + phase) * 0.045 + sin(t * 0.37 + phase * 2.0) * 0.03
	var s := sc * maxf(gp, 0.01)
	ci.draw_set_transform(p, sway, Vector2(s * flip, s))
	ci.draw_polygon(v["stem"], v["stem_cols"])
	var leaves: Array = v["leaves"]
	for li in leaves.size():
		var lf: Dictionary = leaves[li]
		ci.draw_polygon(lf["poly"], lf["cols"])
		ci.draw_colored_polygon(lf["inner"], Color(0.80, 1.0, 0.65, 0.20 + 0.10 * light))      # back-lit tissue
		ci.draw_polyline(lf["mid"], Color(0.82, 1.0, 0.78, 0.55), 1.0, true)
		ci.draw_multiline(lf["veins"], Color(0.82, 1.0, 0.78, 0.28), 0.8, true)
	for dw: Vector3 in v["dew"]:
		var c := Vector2(dw.x, dw.y)
		ci.draw_circle(c + Vector2(0.4, 0.6), dw.z + 0.6, Color(0.0, 0.12, 0.1, 0.35))
		ci.draw_circle(c, dw.z, Color(0.7, 0.98, 1.0, 0.55))
		ci.draw_circle(c + Vector2(0.0, dw.z * 0.25), dw.z * 0.55, Color(0.3, 0.9, 0.9, 0.35))
		ci.draw_circle(c + Vector2(-dw.z * 0.35, -dw.z * 0.4), maxf(dw.z * 0.28, 0.6), Color(1, 1, 1, 0.95))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if glow != null:
		glow.draw_set_transform(p, sway, Vector2(s * flip, s))
		for li in [0, 2, 4]:
			var cc: Vector2 = leaves[li]["center"]
			glow.draw_circle(cc, 15.0, Color(0.4, 1.0, 0.6, 0.045 + 0.03 * light))
		glow.draw_circle(v["top"], 5.0, Color(GOLD, 0.35))
		glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Soft contact shadow + ambient occlusion on the ground.
static func draw_shadow(ci: CanvasItem, p: Vector2, r: float, gp: float) -> void:
	ci.draw_set_transform(p + Vector2(4, 1), 0.0, Vector2(1.0, 0.22))
	ci.draw_circle(Vector2.ZERO, r * 1.1 * gp, Color(0, 0, 0, 0.16))
	ci.draw_circle(Vector2.ZERO, r * 0.7 * gp, Color(0, 0, 0, 0.22))
	ci.draw_circle(Vector2.ZERO, r * 0.35 * gp, Color(0, 0, 0, 0.30))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ------------------------------------------------------------------------------------------ ferns

static func fern(i: int) -> Dictionary:
	var v := i % 4
	if _ferns.has(v):
		return _ferns[v]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4100 + v * 977
	var fronds: Array[Dictionary] = []
	for f in 5:
		var a0 := lerpf(-1.05, 1.05, float(f) / 4.0) + rng.randf_range(-0.1, 0.1)
		var k := (1.0 if a0 >= 0.0 else -1.0) * rng.randf_range(2.2, 3.0) * (1.0 if f != 2 else 0.5)
		var n := 22
		var step := (4.6 + rng.randf()) * (1.0 - 0.28 * absf(a0))
		var pts := PackedVector2Array()
		var leaf := PackedVector2Array()
		var q := Vector2.ZERO
		pts.append(q)
		for s in range(1, n + 1):
			var u := float(s) / n
			var h := a0 * 0.55 + k * u * u
			q += _dir(h) * step * (1.0 - 0.55 * u)
			pts.append(q)
			if s >= 2:
				var tan := _dir(h)
				var nrm := Vector2(-tan.y, tan.x)
				var l := 7.5 * pow(1.0 - u, 0.8) + 1.2
				leaf.append(q + nrm * l)
				leaf.append(q - nrm * l)
		fronds.append({"line": pts, "leaf": leaf, "tip": q})
	var out := {"fronds": fronds}
	_ferns[v] = out
	return out


static func draw_fern(ci: CanvasItem, glow: CanvasItem, p: Vector2, v: Dictionary, gp: float, sc: float, flip: float, t: float, phase: float, dim: float) -> void:
	var sway := sin(t * 0.9 + phase) * 0.035
	var s := sc * maxf(gp, 0.01)
	ci.draw_set_transform(p, sway, Vector2(s * flip, s))
	var fr: Array = v["fronds"]
	for f in fr:
		ci.draw_multiline(f["leaf"], Color(0.18, 0.62, 0.42, 0.8 * dim), 1.3, true)
		ci.draw_polyline(f["line"], Color(0.35, 0.85, 0.6, dim), 2.0, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if glow != null:
		glow.draw_set_transform(p, sway, Vector2(s * flip, s))
		var pulse := 0.6 + 0.4 * sin(t * 2.0 + phase)
		for f in fr:
			glow.draw_circle(f["tip"], 6.5, Color(GOLD, 0.16 * pulse * dim))
			glow.draw_circle(f["tip"], 2.4, Color(1.0, 0.92, 0.6, 0.85 * dim))
		glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ------------------------------------------------------------------------------------------ fractal trees

static func tree(i: int) -> Dictionary:
	var v := i % 3
	if _trees.has(v):
		return _trees[v]
	var rng := RandomNumberGenerator.new()
	rng.seed = 9100 + v * 313
	var segs: Array[PackedVector2Array] = []
	for d in 6:
		segs.append(PackedVector2Array())
	var tips := PackedVector2Array()
	_branch(rng, segs, tips, Vector2.ZERO, 0.0, 40.0, 0)
	var out := {"segs": segs, "tips": tips}
	_trees[v] = out
	return out


static func _branch(rng: RandomNumberGenerator, segs: Array[PackedVector2Array], tips: PackedVector2Array, p: Vector2, a: float, ln: float, d: int) -> void:
	var q := p + _dir(a) * ln
	segs[d].append(p)
	segs[d].append(q)
	if d >= 5:
		tips.append(q)
		return
	var spread := 0.5 + rng.randf_range(-0.1, 0.12)
	_branch(rng, segs, tips, q, a - spread, ln * (0.72 + rng.randf() * 0.04), d + 1)
	_branch(rng, segs, tips, q, a + spread, ln * (0.72 + rng.randf() * 0.04), d + 1)


static func draw_tree(ci: CanvasItem, glow: CanvasItem, p: Vector2, v: Dictionary, gp: float, sc: float, flip: float, t: float, phase: float, dim: float) -> void:
	var sway := sin(t * 0.6 + phase) * 0.02
	var s := sc * maxf(gp, 0.01)
	ci.draw_set_transform(p, sway, Vector2(s * flip, s))
	var segs: Array = v["segs"]
	for d in segs.size():
		var k := float(d) / 5.0
		ci.draw_multiline(segs[d], Color(0.20, 0.52, 0.46).lerp(Color(0.55, 1.0, 0.85), k) * Color(1, 1, 1, dim), maxf(5.0 - d * 0.85, 1.0), true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if glow != null:
		glow.draw_set_transform(p, sway, Vector2(s * flip, s))
		var tips: PackedVector2Array = v["tips"]
		for k in range(0, tips.size(), 3):
			var pulse := 0.6 + 0.4 * sin(t * 1.7 + phase + k)
			glow.draw_circle(tips[k], 5.0, Color(GOLD, 0.14 * pulse * dim))
			glow.draw_circle(tips[k], 2.0, Color(1.0, 0.9, 0.6, 0.8 * dim))
		glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ------------------------------------------------------------------------------------------ crystal bloom

static func draw_crystal(ci: CanvasItem, glow: CanvasItem, p: Vector2, gp: float, sc: float, t: float, phase: float) -> void:
	var s := sc * maxf(gp, 0.01)
	var base := p + Vector2(0, -22.0 * s)
	ci.draw_line(p, base, Color(0.3, 0.7, 0.7), 2.0 * s, true)
	var pulse := 0.5 + 0.5 * sin(t * 1.6 + phase)
	for k in 7:
		var a := (float(k) / 7.0 - 0.5) * 2.2 + sin(t * 0.7 + phase) * 0.04
		var d := _dir(a)
		var nrm := Vector2(-d.y, d.x)
		var l := (24.0 if k % 2 == 0 else 17.0) * s
		var w := 5.5 * s
		var tip := base + d * l
		var mid := base + d * l * 0.45
		var col := CYAN.lerp(VIOLET, float(k) / 6.0)
		ci.draw_colored_polygon(PackedVector2Array([base, mid + nrm * w, tip, mid - nrm * w]), Color(col, 0.55))
		ci.draw_colored_polygon(PackedVector2Array([base, mid + nrm * w, tip]), Color(1, 1, 1, 0.16))
		ci.draw_polyline(PackedVector2Array([base, mid + nrm * w, tip, mid - nrm * w, base]), Color(col.lerp(Color.WHITE, 0.5), 0.8), 1.0, true)
	if glow != null:
		glow.draw_circle(base, 26.0 * s, Color(VIOLET, 0.05 + 0.04 * pulse))
		glow.draw_circle(base, 5.0 * s, Color(1, 1, 1, 0.4 + 0.3 * pulse))


# ------------------------------------------------------------------------------------------ medallion emblems (UI)

## Ornate medallion: faceted gold frame, layered rings, rotating rim light, emblem inside. kind: sprout|fern|tree|crystal
static func medallion(ci: CanvasItem, c: Vector2, r: float, kind: String, t: float, locked := false) -> void:
	var a := 0.45 if locked else 1.0
	for k in 5:
		ci.draw_circle(c, r * (1.25 - k * 0.1), Color(TEAL.lerp(VIOLET, 0.25 * k), 0.035 * a))
	var oct := PackedVector2Array()
	for k in 8:
		oct.append(c + Vector2.from_angle(TAU * k / 8.0 + PI / 8.0) * r)
	ci.draw_colored_polygon(oct, Color(0.02, 0.03, 0.05, 0.95))
	for k in 8:                                      # faceted crystal frame: alternating bevels
		var a0 := TAU * k / 8.0 + PI / 8.0
		var p0 := c + Vector2.from_angle(a0) * r
		var p1 := c + Vector2.from_angle(a0 + TAU / 8.0) * r
		var in0 := c + Vector2.from_angle(a0) * r * 0.8
		var in1 := c + Vector2.from_angle(a0 + TAU / 8.0) * r * 0.8
		ci.draw_colored_polygon(PackedVector2Array([p0, p1, in1, in0]), Color(GOLD.lerp(TEAL, 0.5 if k % 2 == 0 else 0.0), (0.22 if k % 2 == 0 else 0.1) * a))
	oct.append(oct[0])
	ci.draw_polyline(oct, Color(GOLD, 0.95 * a), 2.0, true)
	ci.draw_arc(c, r * 0.78, 0, TAU, 40, Color(TEAL, 0.55 * a), 1.2, true)
	ci.draw_arc(c, r * 0.68, 0, TAU, 40, Color(GOLD, 0.35 * a), 1.0, true)
	for k in 16:                                      # tick marks
		var d := Vector2.from_angle(TAU * k / 16.0 + t * 0.05)
		ci.draw_line(c + d * r * 0.70, c + d * r * (0.76 if k % 2 == 0 else 0.73), Color(GOLD, 0.6 * a), 1.0)
	var sh := t * 0.9                                 # shimmer: a bright comet running round the rim
	for k in 8:
		var f := float(k) / 8.0
		ci.draw_arc(c, r * 0.99, sh - f * 0.9, sh - f * 0.9 + 0.22, 6, Color(1.0, 0.95, 0.75, (1.0 - f) * 0.75 * a), 2.4, true)
	_emblem(ci, c + Vector2(0, r * 0.12), r * 0.62, kind, t, a)


static func _emblem(ci: CanvasItem, c: Vector2, r: float, kind: String, t: float, a: float) -> void:
	var pulse := 0.6 + 0.4 * sin(t * 2.0)
	match kind:
		"sprout":
			var stem := PackedVector2Array()
			for k in 9:
				var s := float(k) / 8.0
				stem.append(c + Vector2(sin(s * 2.4) * r * 0.16, r * 0.85 - s * r * 1.45))
			ci.draw_polyline(stem, Color(TEAL, 0.25 * a), 6.0, true)
			ci.draw_polyline(stem, Color(0.6, 1.0, 0.8, a), 2.2, true)
			var top: Vector2 = stem[8]
			for side in [-1.0, 1.0]:                  # two leaves, each a faceted teardrop with a glowing rib
				var d := Vector2(side * 0.9, -0.45).normalized()
				var nrm := Vector2(-d.y, d.x)
				var b: Vector2 = stem[5]
				var tip := b + d * r * 0.95
				var pts := PackedVector2Array([b, b + d * r * 0.4 + nrm * r * 0.3, tip, b + d * r * 0.4 - nrm * r * 0.3])
				ci.draw_colored_polygon(pts, Color(0.2, 0.8, 0.6, 0.55 * a))
				ci.draw_colored_polygon(PackedVector2Array([b, b + d * r * 0.4 + nrm * r * 0.3, tip]), Color(1, 1, 1, 0.12 * a))
				ci.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0.7, 1.0, 0.9, 0.9 * a), 1.2, true)
				ci.draw_line(b, tip, Color(GOLD, 0.8 * a), 1.0, true)
				ci.draw_circle(tip, 2.2, Color(GOLD, a))
				ci.draw_circle(tip, 5.0, Color(GOLD, 0.2 * a * pulse))
			for side in [-1.0, 1.0]:                  # fractal buds at the crown
				var q: Vector2 = top + Vector2(side * r * 0.28, -r * 0.2)
				ci.draw_line(top, q, Color(0.7, 1.0, 0.9, a), 1.4, true)
				ci.draw_circle(q, 2.0, Color(CYAN, a))
			ci.draw_circle(top, 3.0, Color(1, 0.95, 0.75, a))
			ci.draw_circle(top, 8.0, Color(GOLD, 0.25 * a * pulse))
		"fern":
			var pts := PackedVector2Array()
			var leaf := PackedVector2Array()
			var q := c + Vector2(-r * 0.2, r * 0.85)
			var tip := q
			for s in range(0, 22):
				var u := float(s) / 21.0
				var h := 0.15 + 2.9 * u * u
				q += _dir(h) * r * 0.075 * (1.0 - 0.55 * u) * 3.0
				pts.append(q)
				var d := _dir(h)
				var nrm := Vector2(-d.y, d.x)
				var l := r * 0.28 * (1.0 - u) + 1.0
				leaf.append(q + nrm * l)
				leaf.append(q - nrm * l)
				tip = q
			ci.draw_polyline(pts, Color(TEAL, 0.25 * a), 6.0, true)
			ci.draw_multiline(leaf, Color(0.4, 0.95, 0.7, 0.8 * a), 1.2, true)
			ci.draw_polyline(pts, Color(0.75, 1.0, 0.85, a), 2.0, true)
			ci.draw_circle(tip, 2.4, Color(GOLD, a))
			ci.draw_circle(tip, 6.0, Color(GOLD, 0.22 * a * pulse))
		"tree":
			_emb_tree(ci, c + Vector2(0, r * 0.9), 0.0, r * 0.62, 0, a, pulse)
		"crystal":
			var ctr := c + Vector2(0, r * 0.1)
			for k in 6:
				var ang := TAU * k / 6.0 + 0.2
				var d := Vector2.from_angle(ang)
				var nrm := Vector2(-d.y, d.x)
				var tip := ctr + d * r * 0.95
				var col := CYAN.lerp(VIOLET, float(k) / 5.0)
				ci.draw_colored_polygon(PackedVector2Array([ctr, ctr + d * r * 0.5 + nrm * r * 0.22, tip, ctr + d * r * 0.5 - nrm * r * 0.22]), Color(col, 0.6 * a))
				ci.draw_line(ctr, tip, Color(1, 1, 1, 0.5 * a), 1.0, true)
				ci.draw_circle(tip, 2.0, Color(1, 1, 1, a))
			ci.draw_circle(ctr, r * 0.25, Color(1, 0.95, 0.8, 0.6 * a * pulse + 0.2))


static func _emb_tree(ci: CanvasItem, p: Vector2, ang: float, ln: float, d: int, a: float, pulse: float) -> void:
	var q := p + _dir(ang) * ln
	ci.draw_line(p, q, Color(0.4, 0.95, 0.8, a).lerp(Color(0.9, 1.0, 0.85, a), d / 4.0), maxf(3.0 - d * 0.6, 1.0), true)
	if d >= 4:
		ci.draw_circle(q, 1.8, Color(GOLD, a))
		ci.draw_circle(q, 4.0, Color(GOLD, 0.2 * a * pulse))
		return
	_emb_tree(ci, q, ang - 0.55, ln * 0.7, d + 1, a, pulse)
	_emb_tree(ci, q, ang + 0.55, ln * 0.7, d + 1, a, pulse)
