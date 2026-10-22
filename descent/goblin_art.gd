extends RefCounted

## Procedural art for the goblin cinematic: a detailed obsidian close-up bust of GRIK (lit by a flickering ember
## from below), the crack network that glows from within, and four ink-and-gold memory vignettes.
## World units: y down, head centre ~ (0,0), skull ~420 wide. The caller sets the draw transform.

const EMBER := Color(1.0, 0.40, 0.10)
const COLD := Color(0.30, 0.38, 0.55)
const BASE := Color(0.018, 0.018, 0.026)
const GOLD := Color(0.96, 0.78, 0.38)
const INK := Color(0.012, 0.010, 0.014)

var t := 0.0
var lit := 1.0                  # ember intensity (flicker)
var lpos := Vector2(-300, 420)  # ember source in world units
var hot := 0.0                  # whole-statue inner heat
var crack_heat := 0.0
var eye := 0.0                  # 0 closed .. 1 open
var smirk := 0.0
var mouth_glow := 0.0
var cracks: Array = []          # {pts, t0, dur, w, ph}
var facets: Array = []          # {pts, ang, ph}


func build(crack_times: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	# [origin, heading] - later cracks reach the eyes and mouth
	var origins: Array = [
		[Vector2(20, -215), 1.75], [Vector2(0, 350), -2.0], [Vector2(150, -120), 1.2], [Vector2(-165, 60), 2.4],
		[Vector2(-250, 330), -1.3], [Vector2(20, 255), -1.5], [Vector2(260, 350), -2.0], [Vector2(-10, -60), 1.4],
		[Vector2(-175, -110), 2.8], [Vector2(150, 80), 0.5], [Vector2(-195, -60), 3.1], [Vector2(195, -50), 0.1],
		[Vector2(30, 262), 1.7], [Vector2(-60, -195), 1.3], [Vector2(130, 150), -0.7], [Vector2(-92, -46), 3.6],
		[Vector2(92, -46), -0.4]]
	for k in origins.size():
		var t0: float = crack_times[k % crack_times.size()]
		var o: Vector2 = origins[k][0]
		var ang: float = origins[k][1]
		var pts := PackedVector2Array([o])
		var nseg := rng.randi_range(11, 20)
		var p := o
		var a := ang
		var branches: Array = []
		for i in nseg:
			a += rng.randfn(0.0, 0.34)
			p += Vector2.from_angle(a) * rng.randf_range(14.0, 26.0)
			if not _inside(p):
				break
			pts.append(p)
			if i > 2 and rng.randf() < 0.26:
				branches.append([i, p, a + (rng.randf_range(0.5, 1.0) * (1.0 if rng.randf() < 0.5 else -1.0))])
		if pts.size() < 3:
			continue
		var dur := 0.45 + pts.size() * 0.03
		cracks.append({"pts": pts, "t0": t0, "dur": dur, "w": 2.5, "ph": rng.randf() * 6.28})
		for b in branches:
			var bp := PackedVector2Array([b[1]])
			var q: Vector2 = b[1]
			var ba: float = b[2]
			for j in rng.randi_range(3, 8):
				ba += rng.randfn(0.0, 0.4)
				q += Vector2.from_angle(ba) * rng.randf_range(10.0, 20.0)
				if not _inside(q):
					break
				bp.append(q)
			if bp.size() >= 2:
				cracks.append({"pts": bp, "t0": t0 + dur * float(b[0]) / float(pts.size()), "dur": 0.3 + bp.size() * 0.04, "w": 1.4, "ph": rng.randf() * 6.28})
	# glassy facets
	var tries := 0
	while facets.size() < 110 and tries < 3000:
		tries += 1
		var c := Vector2(rng.randf_range(-220, 220), rng.randf_range(-260, 620))
		if not _inside(c):
			continue
		var sz := rng.randf_range(26.0, 66.0)
		var a0 := rng.randf() * TAU
		var tri := PackedVector2Array()
		for i in 3:
			tri.append(c + Vector2.from_angle(a0 + i * 2.1 + rng.randf_range(-0.4, 0.4)) * sz * rng.randf_range(0.6, 1.1))
		facets.append({"pts": tri, "ang": rng.randf() * TAU, "ph": rng.randf() * 6.28})


func _inside(p: Vector2) -> bool:
	var e := Vector2(p.x / 200.0, (p.y + 20.0) / 255.0)
	if e.length_squared() < 1.0:
		return true
	if absf(p.x) < 380.0 and p.y > 250.0 and p.y < 620.0:
		return true
	return absf(p.x) < 120.0 and p.y > 200.0


# --- lighting helpers --------------------------------------------------------------------------
func _shade(pos: Vector2, nrm: Vector2, base: Color, k: float) -> Color:
	var c := base
	var top := clampf(-nrm.y, 0.0, 1.0)
	# two embers: the main one low-left, a fainter one low-right
	for li in 2:
		var lp := lpos if li == 0 else Vector2(-lpos.x * 1.1 + 40.0, lpos.y * 0.9)
		var gain := 1.0 if li == 0 else 0.55
		var ld := (lp - pos).normalized()
		var fall := clampf(1.3 - pos.distance_to(lp) / 1500.0, 0.25, 1.2)
		var f := clampf(nrm.dot(ld), 0.0, 1.0)
		var e := minf(lit, 1.0) * fall * k * gain
		c += EMBER * (pow(f, 2.5) * 0.85 * e)
		c += EMBER * (pow(f, 8.0) * 2.6 * e)
	c += COLD * (top * 0.06 * (0.4 + 0.6 * lit))
	c += Color(0.5, 0.15, 0.03) * (hot * 0.05)
	c.a = 1.0
	return c


## rim-lit solid: dark glassy core, ember catching only the edges that face the light
func _ring(ci: CanvasItem, pts: PackedVector2Array, nrm: PackedVector2Array, base: Color, k: float) -> void:
	var n := pts.size()
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= n
	var inner := PackedVector2Array()
	var icol := PackedColorArray()
	var ocol := PackedColorArray()
	for i in n:
		var oc := _shade(pts[i], nrm[i], base, k)
		ocol.append(oc)
		inner.append(c + (pts[i] - c) * 0.5)
		var ic := base.lerp(oc, 0.22)
		ic.a = 1.0
		icol.append(ic)
	ci.draw_polygon(inner, icol)
	for i in n:
		var j := (i + 1) % n
		ci.draw_polygon(PackedVector2Array([pts[i], pts[j], inner[j], inner[i]]),
			PackedColorArray([ocol[i], ocol[j], icol[j], icol[i]]))
		# glassy edge highlight where the rim faces the ember
		var ld := (lpos - pts[i]).normalized()
		var fc := nrm[i].dot(ld)
		if fc > 0.5 and lit > 0.05:
			var hc := EMBER * ((fc - 0.5) * 2.2 * minf(lit, 1.0) * k)
			hc.r *= 1.6
			hc.g *= 1.4
			hc.a = 0.9
			ci.draw_line(pts[i], pts[j], hc, 2.2)


func _lit_poly(ci: CanvasItem, pts: PackedVector2Array, base: Color, k: float = 1.0) -> void:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	var nr := PackedVector2Array()
	for p in pts:
		var n := (p - c)
		nr.append(n.normalized() if n.length() > 0.01 else Vector2.UP)
	_ring(ci, pts, nr, base, k)


func _blob(ci: CanvasItem, c: Vector2, r: Vector2, base: Color, k: float = 1.0, rot: float = 0.0, segs: int = 20) -> void:
	var pts := PackedVector2Array()
	var nr := PackedVector2Array()
	for i in segs:
		var a := TAU * i / segs
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot))
		nr.append(Vector2(cos(a) / r.x, sin(a) / r.y).normalized().rotated(rot))
	_ring(ci, pts, nr, base, k)


func _tri(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, base: Color, k: float = 1.0) -> void:
	_lit_poly(ci, PackedVector2Array([a, b, c]), base, k)


# --- backdrop: the other statues, almost swallowed by the dark -----------------------------------
func draw_backdrop(ci: CanvasItem) -> void:
	for s: float in [-1.0, 1.0]:
		var x: float = s * 1250.0
		var pts := PackedVector2Array([Vector2(x - 150, 900), Vector2(x - 120, 100), Vector2(x - 60, -140), Vector2(x, -230),
			Vector2(x + 60, -140), Vector2(x + 120, 100), Vector2(x + 150, 900)])
		var cols := PackedColorArray()
		for p in pts:
			var side := -s * clampf((p.x - x) / 150.0, -1.0, 1.0)     # inner edge catches the glow
			var c := Color(0.006, 0.006, 0.009)
			c += EMBER * (clampf(side, 0.0, 1.0) * 0.06 * lit)
			c.a = 1.0
			cols.append(c)
		ci.draw_polygon(pts, cols)
	# far pillars
	for i in 6:
		var x := -2400.0 + i * 960.0 + 120.0 * sin(i * 2.7)
		ci.draw_rect(Rect2(x, -900, 70 + 20 * (i % 3), 2200), Color(0.008, 0.008, 0.012))


# --- the bust ----------------------------------------------------------------------------------
func draw_bust(ci: CanvasItem) -> void:
	var skin := BASE
	# torso + arms
	_lit_poly(ci, PackedVector2Array([Vector2(-130, 220), Vector2(-300, 270), Vector2(-470, 380), Vector2(-540, 700),
		Vector2(540, 700), Vector2(470, 380), Vector2(300, 270), Vector2(130, 220)]), skin, 0.35)
	_blob(ci, Vector2(-300, 420), Vector2(160, 230), skin, 0.3, 0.35)
	_blob(ci, Vector2(300, 420), Vector2(160, 230), skin, 0.3, -0.35)
	# tattered collar: jagged hood rim
	var rim := PackedVector2Array()
	for i in 15:
		var u := float(i) / 14.0
		rim.append(Vector2(lerpf(-250, 250, u), 292 + 40.0 * sin(u * PI) - 14.0 * (i % 2) + 6.0 * sin(u * 31.0)))
	ci.draw_polyline(rim, _shade(Vector2(0, 300), Vector2(0, -1), Color(0.05, 0.045, 0.06), 0.8), 6.0)
	# neck
	_blob(ci, Vector2(0, 245), Vector2(125, 115), skin, 1.0)
	# ears (long, pointed, slightly drooped) with inner hollow
	for s: float in [-1.0, 1.0]:
		var ear := PackedVector2Array([Vector2(s * 175, -110), Vector2(s * 260, -190), Vector2(s * 340, -240), Vector2(s * 485, -262),
			Vector2(s * 430, -150), Vector2(s * 350, -70), Vector2(s * 262, 8), Vector2(s * 190, 36)])
		_lit_poly(ci, ear, skin, 1.1)
		var inner := PackedVector2Array([Vector2(s * 205, -85), Vector2(s * 290, -168), Vector2(s * 415, -232), Vector2(s * 372, -130),
			Vector2(s * 292, -52), Vector2(s * 218, 4)])
		_lit_poly(ci, inner, Color(0.006, 0.006, 0.01), 0.5)
		# cartilage ridges
		for j in 3:
			var a := Vector2(s * (230 + j * 40), -100 + j * 8)
			var b := Vector2(s * (340 + j * 25), -190 + j * 30)
			ci.draw_line(a, b, Color(0.0, 0.0, 0.0, 0.7), 3.0)
	# skull
	_blob(ci, Vector2(0, -30), Vector2(206, 242), skin, 1.0, 0.0, 30)
	# forehead bumps
	_blob(ci, Vector2(-88, -168), Vector2(66, 44), skin, 0.9, 0.2)
	_blob(ci, Vector2(88, -168), Vector2(66, 44), skin, 0.9, -0.2)
	# cheekbones
	_blob(ci, Vector2(-122, 38), Vector2(78, 54), skin, 1.0, 0.5)
	_blob(ci, Vector2(122, 38 - smirk * 18.0), Vector2(78, 54), skin, 1.0, -0.5)
	# cheek mass
	_blob(ci, Vector2(-108, 120), Vector2(72, 70), skin, 0.9)
	_blob(ci, Vector2(108, 120 - smirk * 26.0), Vector2(72 + smirk * 8.0, 70 - smirk * 12.0), skin, 0.9)
	# jaw + pointed chin
	_lit_poly(ci, PackedVector2Array([Vector2(-150, 70), Vector2(-132, 160), Vector2(-96, 214), Vector2(-40, 266), Vector2(0, 284),
		Vector2(40, 266), Vector2(96, 214), Vector2(132, 160), Vector2(150, 70), Vector2(0, 60)]), skin, 1.0)
	_blob(ci, Vector2(0, 236), Vector2(46, 34), skin, 1.1)
	# eye sockets
	for s: float in [-1.0, 1.0]:
		_blob(ci, Vector2(s * 92, -46), Vector2(74, 42), Color(0.002, 0.002, 0.004), 0.25, s * 0.18)
	# nose
	_lit_poly(ci, PackedVector2Array([Vector2(-26, -76), Vector2(26, -76), Vector2(42, 8), Vector2(-42, 8)]), skin, 1.0)
	_blob(ci, Vector2(0, 54), Vector2(56, 62), skin, 1.2)
	_blob(ci, Vector2(-42, 72), Vector2(28, 25), skin, 1.0, 0.4)
	_blob(ci, Vector2(42, 72), Vector2(28, 25), skin, 1.0, -0.4)
	_blob(ci, Vector2(0, 92), Vector2(26, 14), skin, 1.2)
	for s: float in [-1.0, 1.0]:
		_blob(ci, Vector2(s * 22, 88), Vector2(12, 8), Color(0.0, 0.0, 0.0), 0.0, s * 0.4, 10)
	# warts
	for w in [Vector2(-18, 40), Vector2(30, 62), Vector2(-138, 92), Vector2(60, -150), Vector2(150, 112)]:
		_blob(ci, w, Vector2(9, 8), skin, 1.4, 0.0, 10)
	# brow ridge: heavy V of stone
	_lit_poly(ci, PackedVector2Array([Vector2(-208, -82), Vector2(-140, -132), Vector2(-60, -116), Vector2(0, -88), Vector2(60, -116), Vector2(140, -132),
		Vector2(208, -82), Vector2(150, -58), Vector2(60, -82), Vector2(0, -52), Vector2(-60, -82), Vector2(-150, -58)]), skin, 1.3)
	# eyes
	for s: float in [-1.0, 1.0]:
		_draw_eye(ci, s)
	# upper lid shadow ledge
	for s: float in [-1.0, 1.0]:
		ci.draw_line(Vector2(s * 40, -62), Vector2(s * 150, -80), Color(0, 0, 0, 0.8), 6.0)
	# mouth
	_draw_mouth(ci)
	# wrinkles
	var wr := Color(0.0, 0.0, 0.0, 0.7)
	var hi := _shade(Vector2(0, 40), Vector2(0, 1), Color(0.03, 0.03, 0.04), 0.6)
	hi.a = 0.5
	for k in 3:
		var y := -150.0 - k * 17.0
		var pw := PackedVector2Array()
		for i in 11:
			var u := float(i) / 10.0
			pw.append(Vector2(lerpf(-130, 130, u), y - 12.0 * sin(u * PI) + 3.0 * sin(u * 23.0 + k)))
		ci.draw_polyline(pw, wr, 2.2)
		ci.draw_polyline(pw + PackedVector2Array(_fill_v(pw.size(), Vector2(0, 3))), hi, 1.2)
	for s: float in [-1.0, 1.0]:
		var nl := PackedVector2Array([Vector2(s * 56, 58), Vector2(s * 84, 94), Vector2(s * 112, 136 - smirk * 22.0), Vector2(s * 128, 160 - smirk * 40.0)])
		ci.draw_polyline(nl, wr, 3.0)
		ci.draw_polyline(nl + PackedVector2Array(_fill_v(4, Vector2(s * 3, 3))), hi, 1.5)
		ci.draw_polyline(PackedVector2Array([Vector2(s * 70, -20), Vector2(s * 96, 8), Vector2(s * 118, 18)]), wr, 2.0)
	# glass facets: planes catching the ember
	for i in facets.size():
		var f: Dictionary = facets[i]
		var n := Vector2.from_angle(f.ang)
		var c: Vector2 = (f.pts[0] + f.pts[1] + f.pts[2]) / 3.0
		var ld := (lpos - c).normalized()
		var fc := clampf(n.dot(ld), 0.0, 1.0)
		var tw := 0.75 + 0.25 * sin(t * (1.3 + fmod(f.ph, 1.0)) + f.ph)
		var a := (0.015 + 0.16 * pow(fc, 2.0)) * lit * tw * clampf(1.25 - c.distance_to(lpos) / 950.0, 0.1, 1.0)
		var col := Color(EMBER.r, EMBER.g * 0.8, EMBER.b * 0.7, a)
		ci.draw_colored_polygon(f.pts, col)
		ci.draw_polyline(PackedVector2Array([f.pts[0], f.pts[1], f.pts[2], f.pts[0]]), Color(0, 0, 0, 0.35), 1.2)
	# pendant coin on a cord
	ci.draw_polyline(PackedVector2Array([Vector2(-72, 240), Vector2(-40, 330), Vector2(0, 356)]), Color(0.01, 0.01, 0.012), 4.0)
	ci.draw_polyline(PackedVector2Array([Vector2(72, 240), Vector2(40, 330), Vector2(0, 356)]), Color(0.01, 0.01, 0.012), 4.0)
	_blob(ci, Vector2(0, 396), Vector2(50, 50), Color(0.02, 0.02, 0.03), 1.4, 0.0, 28)
	var ring := _shade(Vector2(0, 396), Vector2(-0.5, 0.8), Color(0.04, 0.04, 0.05), 1.3)
	ci.draw_arc(Vector2(0, 396), 38.0, 0.0, TAU, 28, ring, 3.0)
	ci.draw_polyline(PackedVector2Array([Vector2(-16, 410), Vector2(-16, 384), Vector2(0, 396), Vector2(16, 384), Vector2(16, 410)]), ring, 3.0)
	# earring coin in the left ear
	ci.draw_arc(Vector2(-222, 62), 20.0, 0.0, TAU, 20, _shade(Vector2(-222, 62), Vector2(0, 1), Color(0.04, 0.04, 0.05), 1.5), 4.0)
	# top light: a faint cold line along the skull
	var topl := PackedVector2Array()
	for i in 21:
		var a := lerpf(PI * 1.12, PI * 1.88, float(i) / 20.0)
		topl.append(Vector2(cos(a) * 205.0, -30.0 + sin(a) * 242.0))
	ci.draw_polyline(topl, Color(0.3, 0.4, 0.6, 0.10 * (0.4 + 0.6 * lit)), 3.0)


func _fill_v(n: int, v: Vector2) -> Array:
	var a := []
	for i in n:
		a.append(v)
	return a


func _draw_eye(ci: CanvasItem, s: float) -> void:
	var E := Vector2(s * 92.0, -46.0)
	if eye < 0.03:
		# closed: carved slit, a fleck of amber bleeding through
		ci.draw_line(E + Vector2(-48, 4), E + Vector2(48, -4 + 8 * s * 0.0), Color(0, 0, 0, 0.95), 6.0)
		ci.draw_line(E + Vector2(-46, 7), E + Vector2(46, 3), _shade(E, Vector2(0, 1), Color(0.03, 0.03, 0.04), 1.0), 2.0)
		return
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var cols_o := PackedColorArray()
	var cols_i := PackedColorArray()
	for k in 2:
		var pts := PackedVector2Array()
		var sc := 1.0 if k == 0 else 0.62
		for i in 13:
			var u := lerpf(-1.0, 1.0, float(i) / 12.0)
			var yo := -u * s * 10.0
			pts.append(E + Vector2(u * 54.0 * sc, yo - 23.0 * eye * sc * pow(1.0 - u * u, 0.8)))
		for i in 13:
			var u := lerpf(1.0, -1.0, float(i) / 12.0)
			var yo := -u * s * 10.0
			pts.append(E + Vector2(u * 54.0 * sc, yo + 15.0 * eye * sc * pow(1.0 - u * u, 0.8)))
		if k == 0:
			outer = pts
		else:
			inner = pts
	for i in outer.size():
		cols_o.append(Color(1.3, 0.22, 0.03))
	for i in inner.size():
		cols_i.append(Color(3.4, 2.0, 0.6))
	ci.draw_polygon(outer, cols_o)
	ci.draw_polygon(inner, cols_i)
	# slit pupil
	var pr := Vector2(3.0 + 3.0 * eye, 19.0 * eye)
	var pp := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		pp.append(E + Vector2(cos(a) * pr.x, sin(a) * pr.y))
	ci.draw_colored_polygon(pp, Color(0.02, 0.0, 0.0))


func _mouth_y(u: float, my: float, sm: float) -> float:
	var c := lerpf(0.55, -0.9, sm)
	return my + c * u * u * 28.0 - sm * 18.0 * u


func _draw_mouth(ci: CanvasItem) -> void:
	var my := 168.0
	var W := 132.0
	var N := 17
	var up := PackedVector2Array()
	var lo := PackedVector2Array()
	var gap := 6.0 + smirk * 24.0
	for i in N:
		var u := lerpf(-1.0, 1.0, float(i) / float(N - 1))
		var y := _mouth_y(u, my, smirk)
		up.append(Vector2(u * W, y))
		lo.append(Vector2(u * W, y + gap * pow(maxf(1.0 - u * u, 0.0), 0.6)))
	# lower lip mass
	var lipcol := _shade(Vector2(0, my + 20), Vector2(0, 1), BASE, 1.2)
	var jaw := PackedVector2Array()
	for p in lo:
		jaw.append(p)
	for i in range(N - 1, -1, -1):
		var u := lerpf(-1.0, 1.0, float(i) / float(N - 1))
		jaw.append(Vector2(u * (W - 10.0), my + 48.0 + 26.0 * (1.0 - u * u) + gap * 0.5))
	_lit_poly(ci, jaw, BASE, 1.1)
	# interior
	var inside := PackedVector2Array()
	for p in up:
		inside.append(p)
	for i in range(N - 1, -1, -1):
		inside.append(lo[i])
	var ic := Color(0.004, 0.0, 0.0) + Color(1.6, 0.30, 0.04) * (mouth_glow * 0.9)
	ic.a = 1.0
	ci.draw_colored_polygon(inside, ic)
	# teeth: upper row small, lower tusks
	for k in range(-4, 5):
		var u := float(k) / 4.6
		var x := u * W * 0.9
		var y := _mouth_y(u * 0.9, my, smirk)
		var l := 11.0 + 7.0 * absf(sin(k * 2.3))
		var tc := _shade(Vector2(x, y + 6), Vector2(0, 1), Color(0.07, 0.07, 0.08), 1.8) + Color(1.4, 0.5, 0.15, 0.0) * (mouth_glow * 0.55)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 10, y), Vector2(x + 10, y), Vector2(x + 1.5 * sin(k), y + l)]), tc)
	for s: float in [-1.0, 1.0]:
		var ux := s * 0.56
		var x := ux * W
		var yl := _mouth_y(ux, my, smirk) + gap * pow(1.0 - ux * ux, 0.6)
		var h := 46.0 + smirk * 10.0
		var tc := _shade(Vector2(x, yl - 20), Vector2(0, -1).rotated(s * 0.3), Color(0.06, 0.06, 0.07), 1.7)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 12, yl + 2), Vector2(x + 12, yl + 2), Vector2(x + s * 8.0, yl - h)]), tc)
	for i in 8:
		var x := lerpf(-60.0, 60.0, float(i) / 7.0)
		var yl := _mouth_y(x / W, my, smirk) + gap * pow(1.0 - pow(x / W, 2.0), 0.6)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 7, yl + 1), Vector2(x + 7, yl + 1), Vector2(x, yl - 9.0)]), _shade(Vector2(x, yl), Vector2(0, -1), Color(0.04, 0.04, 0.05), 1.3))
	# lips as thick lit lines
	ci.draw_polyline(up, Color(0, 0, 0, 0.9), 7.0)
	ci.draw_polyline(up, lipcol, 2.0)
	ci.draw_polyline(lo, Color(0, 0, 0, 0.8), 5.0)
	# corner creases
	for s: float in [-1.0, 1.0]:
		var c := up[N - 1] if s > 0.0 else up[0]
		var cr := PackedVector2Array([c, c + Vector2(s * 14, -10 - smirk * 14), c + Vector2(s * 18, -26 - smirk * 24)])
		ci.draw_polyline(cr, Color(0, 0, 0, 0.8), 3.0)


# --- cracks ------------------------------------------------------------------------------------
func _partial(pts: PackedVector2Array, p: float) -> PackedVector2Array:
	var n := pts.size() - 1
	var f := p * n
	var k := int(floor(f))
	var out := PackedVector2Array()
	for i in mini(k, n) + 1:
		out.append(pts[i])
	if k < n:
		out.append(pts[k].lerp(pts[k + 1], f - k))
	return out


func draw_cracks_dark(ci: CanvasItem) -> void:
	for c in cracks:
		var p := clampf((t - c.t0) / c.dur, 0.0, 1.0)
		if p <= 0.0:
			continue
		var pp := _partial(c.pts, p)
		if pp.size() < 2:
			continue
		ci.draw_polyline(pp, Color(0, 0, 0, 0.95), c.w + 1.5)


func draw_glow(ci: CanvasItem) -> void:
	# glass lit from within: stacked soft ellipses
	if hot > 0.01:
		for i in 7:
			var f := 1.0 - float(i) / 7.0
			var e := Color(1.0, 0.30, 0.05, hot * 0.003)
			_ellipse(ci, Vector2(0, -20), Vector2(200, 250) * (0.35 + 0.65 * f), e)
		for i in 5:
			var f := 1.0 - float(i) / 5.0
			_ellipse(ci, Vector2(0, 420), Vector2(380, 230) * (0.3 + 0.7 * f), Color(1.0, 0.25, 0.04, hot * 0.005))
	for c in cracks:
		var age := t - float(c.t0)
		var p := clampf(age / c.dur, 0.0, 1.0)
		if p <= 0.0:
			continue
		var pp := _partial(c.pts, p)
		if pp.size() < 2:
			continue
		var b := (0.30 + 0.70 * smoothstep(0.0, 2.5, age)) * (0.30 + 0.70 * crack_heat) * (0.85 + 0.15 * sin(t * 2.1 + c.ph))
		b += exp(-age * 2.2) * 1.6
		var w: float = c.w
		ci.draw_polyline(pp, Color(1.0, 0.28, 0.04, 0.012 * b), w * 8.0)
		ci.draw_polyline(pp, Color(1.2, 0.42, 0.07, 0.05 * b), w * 3.2)
		ci.draw_polyline(pp, Color(3.0, 1.7, 0.5, 0.85 * minf(b, 1.5)), w * 0.9)
		# the tip burns brightest
		if p < 1.0:
			var tip := pp[pp.size() - 1]
			ci.draw_circle(tip, 9.0, Color(1.5, 0.7, 0.2, 0.30))
			ci.draw_circle(tip, 3.5, Color(3.0, 2.2, 1.0, 0.9))
	# eye halos
	if eye > 0.02:
		for s: float in [-1.0, 1.0]:
			var E := Vector2(s * 92.0, -46.0)
			for hk in 10:
				var hf := float(hk) / 9.0
				ci.draw_circle(E, lerpf(150.0, 40.0, hf), Color(1.2, 0.45, 0.08, (0.006 + 0.010 * hf) * eye))
	if mouth_glow > 0.01:
		var mc := Vector2(0, 170)
		_ellipse(ci, mc, Vector2(190, 90), Color(1.0, 0.25, 0.04, 0.03 * mouth_glow))
		_ellipse(ci, mc, Vector2(120, 45), Color(1.2, 0.35, 0.05, 0.05 * mouth_glow))
	# the coin pendant and ear coin glow with the gold in the glass
	var gl := smoothstep(0.02, 0.6, hot) * (0.7 + 0.3 * sin(t * 1.7))
	if gl > 0.01:
		ci.draw_circle(Vector2(0, 396), 80.0, Color(1.0, 0.55, 0.12, 0.05 * gl))
		ci.draw_arc(Vector2(0, 396), 38.0, 0.0, TAU, 28, Color(2.6, 1.5, 0.4, 0.8 * gl), 2.5)
		ci.draw_polyline(PackedVector2Array([Vector2(-16, 410), Vector2(-16, 384), Vector2(0, 396), Vector2(16, 384), Vector2(16, 410)]), Color(2.6, 1.5, 0.4, 0.8 * gl), 2.5)
		ci.draw_arc(Vector2(-222, 62), 20.0, 0.0, TAU, 20, Color(2.6, 1.5, 0.4, 0.7 * gl), 3.0)
		ci.draw_circle(Vector2(-222, 62), 40.0, Color(1.0, 0.55, 0.12, 0.04 * gl))


func _ellipse(ci: CanvasItem, c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	ci.draw_colored_polygon(pts, col)


# --- memory vignettes (ink and gold) -------------------------------------------------------------
## kind 0 grave & shovel, 1 the offer (red hat), 2 the fall. p = 0..1 progress, a = alpha, sc = pixel scale (disc r = 300).
func draw_memory(ci: CanvasItem, kind: int, p: float, a: float, center: Vector2, sc: float) -> void:
	if a <= 0.001:
		return
	ci.draw_set_transform(center, 0.0, Vector2(sc, sc))
	# parchment-gold glow disc (radial by stacked circles)
	for i in 40:
		var f := float(i) / 39.0
		ci.draw_circle(Vector2.ZERO, 330.0 * (1.0 - f * 0.94), Color(0.95, 0.62, 0.22, a * 0.022))
	var gold := Color(GOLD.r, GOLD.g, GOLD.b, a)
	var ink := Color(INK.r, INK.g, INK.b, a)
	match kind:
		0: _mem_grave(ci, p, a, gold, ink)
		1: _mem_offer(ci, p, a, gold, ink)
		2: _mem_fall(ci, p, a, gold, ink)
	# ink frame ring
	ci.draw_arc(Vector2.ZERO, 318.0, 0.0, TAU, 80, Color(gold.r, gold.g, gold.b, a * 0.5), 2.0)
	ci.draw_arc(Vector2.ZERO, 326.0, 0.0, TAU, 80, Color(gold.r, gold.g, gold.b, a * 0.25), 1.0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _coin(ci: CanvasItem, c: Vector2, r: float, spin: float, a: float, bright: float = 1.0) -> void:
	var w := maxf(absf(cos(spin)), 0.08)
	var pts := PackedVector2Array()
	for i in 20:
		var an := TAU * i / 20.0
		pts.append(c + Vector2(cos(an) * r * w, sin(an) * r))
	var face := Color(1.5, 1.0, 0.35, a) * bright
	face.a = a
	ci.draw_colored_polygon(pts, face)
	var edge := Color(0.55, 0.32, 0.06, a)
	var cl := pts.duplicate()
	cl.append(pts[0])
	ci.draw_polyline(cl, edge, maxf(r * 0.12, 1.5))
	if w > 0.4:
		var sm := PackedVector2Array()
		for i in 15:
			var an := TAU * i / 14.0
			sm.append(c + Vector2(cos(an) * r * 0.62 * w, sin(an) * r * 0.62))
		ci.draw_polyline(sm, Color(0.6, 0.35, 0.07, a * 0.8), 1.4)
		# stamped glyph: a little crown
		ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.28 * w, r * 0.2), c + Vector2(-r * 0.28 * w, -r * 0.18), c + Vector2(-r * 0.1 * w, 0.0),
			c + Vector2(0, -r * 0.25), c + Vector2(r * 0.1 * w, 0.0), c + Vector2(r * 0.28 * w, -r * 0.18), c + Vector2(r * 0.28 * w, r * 0.2)]), Color(0.5, 0.28, 0.05, a * 0.9), 1.4)
	# glint
	var g := 0.5 + 0.5 * sin(spin * 2.0)
	ci.draw_line(c + Vector2(-r * 0.5, -r * 0.5) * w, c + Vector2(r * 0.3, r * 0.3) * w, Color(2.5, 2.2, 1.6, a * 0.5 * g), 1.5)


func _star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), col, 1.5)
	ci.draw_line(c + Vector2(0, -r), c + Vector2(0, r), col, 1.5)
	ci.draw_line(c + Vector2(-r, -r) * 0.5, c + Vector2(r, r) * 0.5, Color(col.r, col.g, col.b, col.a * 0.6), 1.0)
	ci.draw_line(c + Vector2(r, -r) * 0.5, c + Vector2(-r, r) * 0.5, Color(col.r, col.g, col.b, col.a * 0.6), 1.0)


func _mem_grave(ci: CanvasItem, p: float, a: float, gold: Color, ink: Color) -> void:
	# moon
	ci.draw_circle(Vector2(150, -150), 52.0, Color(1.3, 0.95, 0.5, a * 0.85))
	ci.draw_circle(Vector2(168, -158), 46.0, Color(0.42, 0.27, 0.09, a * 0.9))
	# far hills
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-320, 60), Vector2(-200, 20), Vector2(-60, 50), Vector2(100, 10), Vector2(320, 55), Vector2(320, 140), Vector2(-320, 140)]), Color(0.10, 0.065, 0.03, a))
	# ground
	var ground := PackedVector2Array([Vector2(-320, 124), Vector2(-150, 108), Vector2(0, 118), Vector2(150, 104), Vector2(320, 122), Vector2(320, 320), Vector2(-320, 320)])
	ci.draw_colored_polygon(ground, ink)
	ci.draw_polyline(PackedVector2Array([Vector2(-320, 124), Vector2(-150, 108), Vector2(0, 118), Vector2(150, 104), Vector2(320, 122)]), gold, 2.0)
	# tombstones
	for tb in [[-215.0, 74.0, -0.10], [-95.0, 96.0, 0.06], [215.0, 84.0, 0.12], [150.0, 62.0, -0.05]]:
		var x: float = tb[0]
		var h: float = tb[1]
		var tl: float = tb[2]
		var base := Vector2(x, 116.0)
		var top := base + Vector2(0, -h).rotated(tl)
		var pts := PackedVector2Array([base + Vector2(-26, 0), base + Vector2(-26, 0) + Vector2(0, -h * 0.8).rotated(tl)])
		for i in 9:
			var an := lerpf(PI, TAU, float(i) / 8.0)
			pts.append(top + Vector2(cos(an) * 26.0, sin(an) * 22.0).rotated(tl))
		pts.append(base + Vector2(26, 0))
		ci.draw_colored_polygon(pts, ink)
		var ol := pts.duplicate()
		ci.draw_polyline(ol, gold, 1.6)
		ci.draw_line(top + Vector2(0, 2).rotated(tl), top + Vector2(0, 26).rotated(tl), Color(gold.r, gold.g, gold.b, a * 0.6), 1.4)
		ci.draw_line(top + Vector2(-8, 12).rotated(tl), top + Vector2(8, 12).rotated(tl), Color(gold.r, gold.g, gold.b, a * 0.6), 1.4)
	# open grave
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-40, 116), Vector2(30, 112), Vector2(46, 150), Vector2(-60, 156)]), Color(0, 0, 0, a))
	# dirt mound beside the grave
	var mound := PackedVector2Array()
	for i in 13:
		var u := float(i) / 12.0
		mound.append(Vector2(lerpf(60, 190, u), 114.0 - 46.0 * sin(u * PI) * (0.9 + 0.1 * sin(u * 9.0))))
	ci.draw_colored_polygon(mound, ink)
	ci.draw_polyline(mound, Color(gold.r, gold.g, gold.b, a * 0.8), 1.6)
	# the digger: hooded mortal bent over with a lantern
	var bob := sin(p * 22.0) * 4.0 * smoothstep(0.1, 0.3, p)
	var dg := Vector2(-150, 122)
	ci.draw_colored_polygon(PackedVector2Array([dg + Vector2(-26, 0), dg + Vector2(-30, -50), dg + Vector2(-12, -86 + bob), dg + Vector2(14, -84 + bob), dg + Vector2(26, -44), dg + Vector2(30, 0)]), ink)
	ci.draw_polyline(PackedVector2Array([dg + Vector2(-26, 0), dg + Vector2(-30, -50), dg + Vector2(-12, -86 + bob), dg + Vector2(14, -84 + bob), dg + Vector2(26, -44), dg + Vector2(30, 0)]), Color(gold.r, gold.g, gold.b, a * 0.75), 1.6)
	ci.draw_circle(dg + Vector2(2, -92 + bob), 17.0, ink)
	ci.draw_arc(dg + Vector2(2, -92 + bob), 18.0, PI * 1.05, PI * 1.9, 10, Color(gold.r, gold.g, gold.b, a * 0.8), 1.5)
	# shovel in his hands: handle up, blade in the earth, dirt arcs flying
	var sh := dg + Vector2(34, -40 + bob)
	ci.draw_line(sh + Vector2(26, 160), sh + Vector2(-10, -78), Color(gold.r, gold.g, gold.b, a * 0.9), 9.0)
	ci.draw_line(sh + Vector2(26, 160), sh + Vector2(-10, -78), ink, 6.0)
	ci.draw_arc(sh + Vector2(-16, -86), 14.0, PI, TAU + 0.8, 10, Color(gold.r, gold.g, gold.b, a * 0.9), 3.0)
	ci.draw_colored_polygon(PackedVector2Array([sh + Vector2(16, 118), sh + Vector2(46, 118), sh + Vector2(52, 152), sh + Vector2(32, 176), sh + Vector2(12, 152)]), Color(0.45, 0.28, 0.07, a))
	for i in 7:
		var ph := fmod(p * 1.6 + i * 0.141, 1.0)
		var d0 := sh + Vector2(40, 110)
		var v := Vector2(60 + i * 12.0, -230.0)
		var pos := d0 + v * ph + Vector2(0, 560.0 * ph * ph)
		ci.draw_circle(pos, 3.0, Color(0.7, 0.45, 0.15, a * (1.0 - ph) * 0.9))
	# lantern light
	var lp := dg + Vector2(-48, -10)
	ci.draw_line(dg + Vector2(-22, -40), lp + Vector2(0, -14), Color(gold.r, gold.g, gold.b, a * 0.7), 1.5)
	ci.draw_circle(lp, 60.0, Color(1.4, 0.8, 0.2, a * 0.05))
	ci.draw_circle(lp, 28.0, Color(1.6, 1.0, 0.3, a * 0.10))
	ci.draw_circle(lp, 9.0, Color(3.0, 2.0, 0.7, a))
	# coins gather on the earth one by one: the keeper's tally
	for i in 8:
		var on := smoothstep(0.18 + i * 0.07, 0.24 + i * 0.07, p)
		if on <= 0.0:
			continue
		var cx := lerpf(-10.0, 170.0, float(i) / 7.0)
		var cy := 126.0 + 14.0 * sin(i * 1.7)
		_coin(ci, Vector2(cx, cy - 24.0 * (1.0 - on)), 10.0, 0.0, a * on)
		_star(ci, Vector2(cx + 6, cy - 8), 8.0 * (1.0 - smoothstep(0.0, 0.5, fmod(p * 3.0 + i * 0.3, 1.0))), Color(2.5, 2.0, 1.2, a * on))


func _mem_offer(ci: CanvasItem, p: float, a: float, gold: Color, ink: Color) -> void:
	# drifting dust
	for i in 30:
		var x := -280.0 + fmod(i * 97.3 + p * 25.0 * (1 + i % 3), 560.0)
		var y := -260.0 + fmod(i * 53.1 - p * 18.0 * (1 + i % 2) + 560.0, 520.0)
		ci.draw_circle(Vector2(x, y), 1.4 + (i % 3) * 0.6, Color(1.4, 0.9, 0.4, a * 0.35))
	# the little black angel in his red hat, faceless; breathes and leans in
	var lean := smoothstep(0.1, 0.7, p) * 24.0
	var bx := 60.0 - lean
	var base := Vector2(bx, 190.0)
	var k := 1.4
	var black := Color(0.006, 0.006, 0.01, a)
	var body := PackedVector2Array([Vector2(-14, -2), Vector2(-20, -62), Vector2(-9, -105), Vector2(9, -105), Vector2(20, -62), Vector2(14, -2)])
	var wl := PackedVector2Array([Vector2(-14, -80), Vector2(-62, -120), Vector2(-48, -40)])
	var wr := PackedVector2Array([Vector2(14, -80), Vector2(62, -120), Vector2(48, -40)])
	var flap := 1.0 + 0.04 * sin(p * 14.0)
	for poly in [body, wl, wr]:
		var q := PackedVector2Array()
		for v in poly:
			q.append(base + Vector2(v.x * flap, v.y) * k)
		ci.draw_colored_polygon(q, black)
		var qc := q.duplicate()
		qc.append(q[0])
		ci.draw_polyline(qc, Color(gold.r, gold.g, gold.b, a * 0.55), 1.4)
	var head := base + Vector2(0, -122) * k
	ci.draw_circle(head, 25.0 * k, black)
	ci.draw_arc(head, 25.0 * k, 0.0, TAU, 28, Color(gold.r, gold.g, gold.b, a * 0.6), 1.4)
	# the hat: the only red in the whole memory
	var hp := PackedVector2Array([Vector2(-30, -138), Vector2(-17, -168), Vector2(0, -158), Vector2(17, -168), Vector2(30, -138)])
	var hq := PackedVector2Array()
	for v in hp:
		hq.append(base + v * k)
	var pulse := 0.85 + 0.15 * sin(p * 9.0)
	ci.draw_circle(base + Vector2(0, -152) * k, 66.0, Color(1.5, 0.08, 0.06, a * 0.07 * pulse))
	ci.draw_circle(base + Vector2(0, -152) * k, 34.0, Color(1.6, 0.10, 0.07, a * 0.12 * pulse))
	ci.draw_colored_polygon(hq, Color(1.9, 0.10, 0.10, a))
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-34, -138) * k, base + Vector2(34, -138) * k, base + Vector2(30, -130) * k, base + Vector2(-30, -130) * k]), Color(0.75, 0.04, 0.05, a))
	# the offer: his small hand reaches in from the left, the angel's hand from the right; a coin between
	var reach := smoothstep(0.05, 0.6, p)
	var hx := lerpf(-230.0, -70.0, reach)
	var arm := PackedVector2Array([Vector2(-330, 80), Vector2(-200, 70), Vector2(hx, 40 + 6 * sin(p * 5.0))])
	ci.draw_polyline(arm, black, 18.0)
	ci.draw_polyline(arm, Color(gold.r, gold.g, gold.b, a * 0.3), 1.2)
	var h := Vector2(hx, 40.0)
	for f in 4:
		var fa := -0.5 + f * 0.30
		ci.draw_line(h, h + Vector2(cos(fa), sin(fa)) * 24.0 * (0.8 + 0.2 * float(f % 2)), black, 6.0)
	var ax := lerpf(bx - 18.0, bx - 90.0, reach)
	ci.draw_polyline(PackedVector2Array([base + Vector2(-10, -60) * k, Vector2(ax + 40, 60), Vector2(ax, 50)]), black, 10.0)
	var cp := Vector2((hx + ax) * 0.5 + 6.0, 32.0 + 10.0 * sin(p * 7.0))
	ci.draw_circle(cp, 40.0, Color(1.6, 0.8, 0.2, a * 0.06))
	_coin(ci, cp, 21.0, p * 9.0, a)
	_star(ci, cp + Vector2(10, -12), 14.0 * (0.5 + 0.5 * sin(p * 12.0)), Color(2.8, 2.3, 1.5, a * 0.8))
	# ground line
	ci.draw_line(Vector2(-320, 195), Vector2(320, 195), Color(gold.r, gold.g, gold.b, a * 0.4), 1.5)


func _mem_fall(ci: CanvasItem, p: float, a: float, gold: Color, ink: Color) -> void:
	var glass := smoothstep(0.55, 0.92, p)
	# speed lines streaking upward
	for i in 40:
		var x := -300.0 + fmod(i * 61.7, 600.0)
		var spd := 220.0 + (i % 5) * 90.0
		var y0 := -320.0 + fmod(i * 131.3 + p * spd * 3.0, 700.0)
		var ln := 22.0 + (i % 4) * 14.0
		var ph := 1.0 - 0.6 * glass
		ci.draw_line(Vector2(x, 320.0 - (y0 + 320.0)), Vector2(x, 320.0 - (y0 + 320.0) - ln), Color(gold.r, gold.g, gold.b, a * 0.35 * ph), 1.3)
	# coins streaming upward from his pockets as he drops
	for i in 11:
		var ph := fmod(p * 1.1 + i * 0.093, 1.0)
		var cx := -60.0 + 130.0 * sin(i * 2.3) * (0.4 + ph)
		var cy := 40.0 - 420.0 * ph
		_coin(ci, Vector2(cx, cy), 12.0 + (i % 3) * 3.0, p * 14.0 + i, a * (1.0 - ph) * (1.0 - 0.7 * glass))
	# the red dot of the hat, far above, shrinking
	var hy := -250.0 - 40.0 * p
	ci.draw_circle(Vector2(30, hy), 22.0, Color(1.5, 0.08, 0.06, a * 0.10))
	ci.draw_circle(Vector2(30, hy), 6.0 * (1.0 - 0.4 * p), Color(1.9, 0.12, 0.10, a))
	# the tumbling goblin-to-be
	var c := Vector2(0, 20.0)
	var rot := p * 5.4 + 0.6
	var tr := Transform2D(rot, c) * Transform2D.IDENTITY.scaled(Vector2(1.5, 1.5))
	var ink2 := Color(INK.r, INK.g, INK.b, a)
	var line_col: Color = ink2.lerp(Color(1.8, 2.2, 2.6, a), glass)
	var limbs := [[Vector2(0, -34), Vector2(0, 40)], [Vector2(0, -20), Vector2(-44, -52)], [Vector2(0, -20), Vector2(46, -6)],
		[Vector2(0, 40), Vector2(-30, 86)], [Vector2(0, 40), Vector2(34, 80)]]
	var body := PackedVector2Array([Vector2(-18, -30), Vector2(-24, 10), Vector2(0, 46), Vector2(24, 10), Vector2(18, -30)])
	var bq := PackedVector2Array()
	for v in body:
		bq.append(tr * v)
	ci.draw_colored_polygon(bq, ink2.lerp(Color(0.2, 0.3, 0.4, a * 0.5), glass))
	for l in limbs:
		ci.draw_line(tr * l[0], tr * l[1], Color(gold.r, gold.g, gold.b, a * 0.5), 12.0)
		ci.draw_line(tr * l[0], tr * l[1], ink2.lerp(Color(0.15, 0.25, 0.35, a), glass), 9.0)
	ci.draw_circle(tr * Vector2(0, -50), 20.0, ink2.lerp(Color(0.2, 0.3, 0.4, a * 0.6), glass))
	# pointed ears: the change has begun
	var ears := smoothstep(0.25, 0.6, p)
	ci.draw_colored_polygon(PackedVector2Array([tr * Vector2(-16, -56), tr * Vector2(-16 - 34 * ears, -78 - 6 * ears), tr * Vector2(-10, -42)]), ink2.lerp(line_col, glass))
	ci.draw_colored_polygon(PackedVector2Array([tr * Vector2(16, -56), tr * Vector2(16 + 34 * ears, -78 - 6 * ears), tr * Vector2(10, -42)]), ink2.lerp(line_col, glass))
	# glass: faceted shards and cracking light across the body
	if glass > 0.01:
		var ga := a * glass
		for i in 9:
			var an := TAU * i / 9.0 + rot
			var r0 := 30.0 + 14.0 * sin(i * 3.1)
			var q0 := c + Vector2.from_angle(an) * r0
			var q1 := c + Vector2.from_angle(an + 0.6) * (r0 + 30.0)
			var q2 := c + Vector2.from_angle(an + 1.2) * (r0 + 8.0)
			ci.draw_colored_polygon(PackedVector2Array([q0, q1, q2]), Color(0.5, 0.8, 1.2, ga * 0.22))
			ci.draw_polyline(PackedVector2Array([q0, q1, q2, q0]), Color(2.2, 2.4, 2.6, ga * 0.7), 1.2)
		for i in 6:
			var an := i * 1.05 + rot * 0.5
			ci.draw_line(c, c + Vector2.from_angle(an) * (50.0 + 20.0 * sin(i * 2.0)), Color(3.0, 1.8, 0.6, ga * 0.9), 1.6)
		_star(ci, c + Vector2(12, -50), 22.0 * ga, Color(3.0, 2.8, 2.4, ga))
