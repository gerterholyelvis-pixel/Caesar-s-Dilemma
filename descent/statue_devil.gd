extends RefCounted
## Obsidian devil colossus: horned, winged, hands on a chained pillar. Pure draw helper.
## Unit coords: x/h, y up/h (horns may exceed 1.0 and get cropped by the screen).

const BODY := Color(0.034, 0.035, 0.05)
const FACET := Color(0.072, 0.075, 0.098)
const RIM := Color(0.95, 0.33, 0.08)


static func draw(ci: CanvasItem, base: Vector2, h: float, t: float, hot: float) -> void:
	var b := base
	var flick: float = 1.0 + 0.07 * sin(t * 4.1) + 0.04 * sin(t * 11.3 + 2.0)
	var spec := Color(0.6, 0.68, 0.9, 0.20)
	var crack := Color(1.0, 0.35, 0.08, 0.16 + 0.4 * hot)

	# ---------- silhouette parts ----------
	var wing_l: Array = [Vector2(-0.20, 0.74), Vector2(-0.34, 0.93), Vector2(-0.49, 1.07), Vector2(-0.47, 0.88), Vector2(-0.54, 0.66), Vector2(-0.46, 0.48), Vector2(-0.49, 0.30), Vector2(-0.38, 0.40), Vector2(-0.32, 0.27), Vector2(-0.27, 0.45), Vector2(-0.24, 0.60)]
	var wing_r: Array = _mx(wing_l)
	var horn_l: Array = _tube(_smooth([Vector2(-0.07, 0.905), Vector2(-0.17, 0.925), Vector2(-0.27, 0.985), Vector2(-0.33, 1.08), Vector2(-0.30, 1.17), Vector2(-0.22, 1.22), Vector2(-0.16, 1.19)], 6), 0.07, 0.004)
	var horn_r: Array = _mx(horn_l)
	var leg_l: Array = [Vector2(-0.25, 0.0), Vector2(-0.04, 0.0), Vector2(-0.06, 0.12), Vector2(-0.05, 0.36), Vector2(-0.22, 0.38), Vector2(-0.28, 0.17)]
	var leg_r: Array = _mx(leg_l)
	var toes_l: Array = [Vector2(-0.25, 0.0), Vector2(-0.33, 0.006), Vector2(-0.27, 0.03)]
	var toes_r: Array = _mx(toes_l)
	var loin: Array = [Vector2(-0.22, 0.34), Vector2(0.22, 0.34), Vector2(0.20, 0.47), Vector2(-0.20, 0.47)]
	var torso: Array = [Vector2(-0.19, 0.44), Vector2(0.19, 0.44), Vector2(0.28, 0.60), Vector2(0.34, 0.72), Vector2(0.17, 0.77), Vector2(-0.17, 0.77), Vector2(-0.34, 0.72), Vector2(-0.28, 0.60)]
	var neck: Array = [Vector2(-0.07, 0.72), Vector2(0.07, 0.72), Vector2(0.08, 0.80), Vector2(-0.08, 0.80)]
	var head: Array = [Vector2(-0.095, 0.80), Vector2(-0.06, 0.755), Vector2(0.06, 0.755), Vector2(0.095, 0.80), Vector2(0.105, 0.87), Vector2(0.075, 0.925), Vector2(-0.075, 0.925), Vector2(-0.105, 0.87)]
	var brow: Array = [Vector2(-0.12, 0.88), Vector2(0.12, 0.88), Vector2(0.095, 0.91), Vector2(0.0, 0.895), Vector2(-0.095, 0.91)]
	var sh_l: Array = [Vector2(-0.40, 0.70), Vector2(-0.36, 0.78), Vector2(-0.24, 0.79), Vector2(-0.19, 0.72), Vector2(-0.24, 0.64), Vector2(-0.36, 0.63)]
	var sh_r: Array = _mx(sh_l)
	var spike_l: Array = _tube([Vector2(-0.34, 0.77), Vector2(-0.38, 0.84), Vector2(-0.39, 0.92)], 0.05, 0.004)
	var spike_r: Array = _mx(spike_l)
	var arm_l: Array = _tube(_smooth([Vector2(-0.33, 0.70), Vector2(-0.30, 0.60), Vector2(-0.21, 0.52), Vector2(-0.12, 0.485)], 5), 0.105, 0.075)
	var arm_r: Array = _mx(arm_l)
	var pillar: Array = [Vector2(-0.095, 0.0), Vector2(0.095, 0.0), Vector2(0.082, 0.40), Vector2(0.115, 0.435), Vector2(0.115, 0.475), Vector2(-0.115, 0.475), Vector2(-0.115, 0.435), Vector2(-0.082, 0.40)]
	var all_parts: Array = [wing_l, wing_r, leg_l, leg_r, torso, head, sh_l, sh_r, pillar]

	# ---------- floor ----------
	_shadow(ci, b, h * 0.30, hot)
	_ell(ci, b + Vector2(0, 4), h * 0.26, h * 0.022, Color(RIM.r, RIM.g, RIM.b, 0.045 + 0.06 * hot))
	_reflect(ci, b, h, all_parts, hot)

	# ---------- back layer: wings and horns ----------
	_part(ci, b, h, wing_r, hot, Color(0.028, 0.029, 0.042))
	_part(ci, b, h, wing_l, hot, Color(0.028, 0.029, 0.042))
	_part(ci, b, h, horn_r, hot, Color(0.05, 0.045, 0.055))
	_part(ci, b, h, horn_l, hot, Color(0.05, 0.045, 0.055))
	# wing bones / ribs and membrane sheen
	for s in [-1.0, 1.0]:
		var sx: float = s
		_line(ci, b, h, [Vector2(sx * 0.22, 0.75), Vector2(sx * 0.34, 0.93), Vector2(sx * 0.49, 1.06)], Color(0.1, 0.1, 0.13, 0.9), 0.014)
		_line(ci, b, h, [Vector2(sx * 0.34, 0.93), Vector2(sx * 0.46, 0.50), Vector2(sx * 0.49, 0.30)], Color(0.09, 0.09, 0.12, 0.9), 0.010)
		_line(ci, b, h, [Vector2(sx * 0.34, 0.93), Vector2(sx * 0.38, 0.40), Vector2(sx * 0.32, 0.28)], Color(0.09, 0.09, 0.12, 0.9), 0.008)
		_line(ci, b, h, [Vector2(sx * 0.30, 0.90), Vector2(sx * 0.27, 0.45)], Color(0.09, 0.09, 0.12, 0.9), 0.007)
		_line(ci, b, h, [Vector2(sx * 0.49, 1.06), Vector2(sx * 0.50, 0.90), Vector2(sx * 0.53, 0.68)], Color(0.6, 0.7, 0.95, 0.16), 0.004)
	# horn ridges + glint
	for s2 in [-1.0, 1.0]:
		var sg: float = s2
		_line(ci, b, h, [Vector2(sg * 0.10, 0.92), Vector2(sg * 0.22, 0.97), Vector2(sg * 0.31, 1.06), Vector2(sg * 0.31, 1.15)], Color(0.7, 0.75, 0.95, 0.22), 0.005)
		for k in range(4):
			var ry: float = 0.935 + float(k) * 0.028
			var rx: float = 0.13 + float(k) * 0.055
			_line(ci, b, h, [Vector2(sg * rx, ry), Vector2(sg * (rx + 0.012), ry + 0.022)], Color(0.0, 0.0, 0.0, 0.5), 0.004)

	# ---------- body ----------
	_part(ci, b, h, leg_r, hot)
	_part(ci, b, h, toes_r, hot)
	_part(ci, b, h, leg_l, hot)
	_part(ci, b, h, toes_l, hot)
	_part(ci, b, h, loin, hot)
	_part(ci, b, h, torso, hot)
	_part(ci, b, h, neck, hot)
	_part(ci, b, h, head, hot)
	_part(ci, b, h, spike_r, hot)
	_part(ci, b, h, spike_l, hot)
	_part(ci, b, h, sh_r, hot)
	_part(ci, b, h, sh_l, hot)
	_part(ci, b, h, arm_r, hot)
	_part(ci, b, h, arm_l, hot)
	_part(ci, b, h, pillar, hot, Color(0.042, 0.042, 0.056))

	# ---------- facets: pecs, abs, shoulders, thighs ----------
	_facet(ci, b, h, [Vector2(-0.28, 0.72), Vector2(-0.18, 0.755), Vector2(-0.02, 0.73), Vector2(-0.02, 0.62), Vector2(-0.14, 0.60), Vector2(-0.24, 0.64)], FACET)
	_facet(ci, b, h, [Vector2(0.02, 0.62), Vector2(0.02, 0.73), Vector2(0.17, 0.75), Vector2(0.26, 0.70), Vector2(0.22, 0.62), Vector2(0.12, 0.60)], Color(0.052, 0.054, 0.072))
	_facet(ci, b, h, [Vector2(-0.14, 0.58), Vector2(0.14, 0.58), Vector2(0.12, 0.48), Vector2(-0.12, 0.48)], Color(0.055, 0.057, 0.076))
	_facet(ci, b, h, [Vector2(-0.38, 0.72), Vector2(-0.34, 0.77), Vector2(-0.25, 0.78), Vector2(-0.30, 0.70)], FACET)
	_facet(ci, b, h, [Vector2(-0.24, 0.37), Vector2(-0.08, 0.36), Vector2(-0.10, 0.20), Vector2(-0.24, 0.20)], Color(0.058, 0.06, 0.08))
	_facet(ci, b, h, [Vector2(0.08, 0.36), Vector2(0.22, 0.37), Vector2(0.24, 0.24), Vector2(0.10, 0.22)], Color(0.045, 0.046, 0.062))
	_facet(ci, b, h, [Vector2(-0.085, 0.80), Vector2(-0.07, 0.87), Vector2(-0.03, 0.86), Vector2(-0.04, 0.78)], FACET)
	# abdomen lines & sternum
	_line(ci, b, h, [Vector2(0.0, 0.74), Vector2(0.0, 0.46)], Color(0, 0, 0, 0.7), 0.004)
	for k in range(3):
		var ay: float = 0.55 - float(k) * 0.035
		_line(ci, b, h, [Vector2(-0.11, ay), Vector2(0.11, ay)], Color(0, 0, 0, 0.55), 0.003)
	# loin chain-cloth and belt
	_line(ci, b, h, [Vector2(-0.21, 0.455), Vector2(0.21, 0.455)], Color(0.1, 0.09, 0.1, 0.9), 0.012)
	_facet(ci, b, h, [Vector2(-0.04, 0.46), Vector2(0.04, 0.46), Vector2(0.0, 0.36)], Color(0.045, 0.04, 0.05))

	# ---------- specular streaks ----------
	_line(ci, b, h, [Vector2(-0.33, 0.70), Vector2(-0.28, 0.745), Vector2(-0.20, 0.765)], spec, 0.004)
	_line(ci, b, h, [Vector2(-0.27, 0.62), Vector2(-0.30, 0.70)], spec, 0.004)
	_line(ci, b, h, [Vector2(-0.26, 0.38), Vector2(-0.27, 0.20)], spec, 0.004)
	_line(ci, b, h, [Vector2(-0.10, 0.90), Vector2(-0.07, 0.92), Vector2(0.0, 0.925)], Color(0.7, 0.75, 0.95, 0.3), 0.004)
	_line(ci, b, h, [Vector2(-0.10, 0.82), Vector2(-0.10, 0.87)], spec, 0.003)
	_line(ci, b, h, [Vector2(-0.30, 0.66), Vector2(-0.24, 0.58), Vector2(-0.14, 0.52)], spec, 0.004)

	# ---------- cracks ----------
	_line(ci, b, h, [Vector2(0.20, 0.72), Vector2(0.15, 0.66), Vector2(0.19, 0.60), Vector2(0.13, 0.52), Vector2(0.16, 0.46)], crack, 0.003)
	_line(ci, b, h, [Vector2(-0.19, 0.68), Vector2(-0.12, 0.64), Vector2(-0.15, 0.58)], crack, 0.003)
	_line(ci, b, h, [Vector2(0.16, 0.34), Vector2(0.14, 0.26), Vector2(0.17, 0.18), Vector2(0.14, 0.08)], crack, 0.003)
	_line(ci, b, h, [Vector2(-0.14, 0.30), Vector2(-0.17, 0.20)], crack, 0.003)
	_line(ci, b, h, [Vector2(-0.05, 0.30), Vector2(-0.04, 0.22), Vector2(-0.065, 0.12)], crack, 0.0025)
	_line(ci, b, h, [Vector2(0.03, 0.32), Vector2(0.06, 0.24)], crack, 0.0025)
	_line(ci, b, h, [Vector2(0.05, 0.36), Vector2(0.06, 0.30), Vector2(0.04, 0.24)], crack, 0.003)

	# ---------- pillar: carving + great chain ----------
	_facet(ci, b, h, [Vector2(-0.09, 0.40), Vector2(-0.05, 0.40), Vector2(-0.05, 0.02), Vector2(-0.09, 0.02)], Color(0.07, 0.07, 0.09))
	_line(ci, b, h, [Vector2(-0.082, 0.43), Vector2(0.082, 0.43)], Color(0, 0, 0, 0.6), 0.004)
	for k in range(9):
		var cy: float = 0.045 + float(k) * 0.041
		var lean: float = 0.04 if k % 2 == 0 else -0.04
		var link: Array = _circ(Vector2(lean * 0.4, cy), 0.034, 0.024, 10)
		var pl: PackedVector2Array = _P(b, h, link)
		pl.append(pl[0])
		ci.draw_polyline(pl, Color(0.12, 0.115, 0.14, 0.9), maxf(1.5, 0.009 * h), true)
		ci.draw_polyline(pl, Color(RIM.r, RIM.g, RIM.b, 0.12 + 0.25 * hot), maxf(1.0, 0.003 * h), true)
	# chain draping from left hand to the floor
	var drape: Array = _smooth([Vector2(-0.14, 0.455), Vector2(-0.19, 0.38), Vector2(-0.17, 0.24), Vector2(-0.21, 0.10), Vector2(-0.30, 0.02)], 5)
	_line(ci, b, h, drape, Color(0.1, 0.1, 0.13, 0.95), 0.012)
	var dn: int = drape.size()
	for i in range(0, dn, 2):
		var dp: Vector2 = drape[i]
		ci.draw_colored_polygon(_P(b, h, _circ(dp, 0.013, 0.017, 8)), Color(RIM.r, RIM.g, RIM.b, 0.18 + 0.3 * hot))

	# ---------- clawed hands over the pillar top ----------
	for s3 in [-1.0, 1.0]:
		var hs: float = s3
		for k in range(4):
			var fx: float = hs * (0.02 + float(k) * 0.030)
			var f: Array = [Vector2(fx - 0.014, 0.475), Vector2(fx + 0.014, 0.475), Vector2(fx + hs * 0.008, 0.40)]
			_part(ci, b, h, f, hot, Color(0.05, 0.05, 0.065))
		_part(ci, b, h, _circ(Vector2(hs * 0.085, 0.50), 0.05, 0.034, 12), hot, BODY)
		_line(ci, b, h, [Vector2(hs * 0.10, 0.52), Vector2(hs * 0.06, 0.525)], spec, 0.004)

	# ---------- eyes: burning-dim red slits under a heavy brow ----------
	_part(ci, b, h, brow, hot, Color(0.025, 0.025, 0.035))
	_line(ci, b, h, [Vector2(-0.105, 0.905), Vector2(0.0, 0.89), Vector2(0.105, 0.905)], Color(0.7, 0.75, 0.95, 0.12), 0.003)
	var ea: float = (0.5 + 0.5 * hot) * flick
	var ec := Color(1.0, 0.16, 0.04)
	for s4 in [-1.0, 1.0]:
		var es: float = s4
		var a: Vector2 = b + Vector2(es * 0.022 * h, -0.866 * h)
		var c: Vector2 = b + Vector2(es * 0.075 * h, -0.880 * h)
		_glow(ci, (a + c) * 0.5, h * 0.016, ec, ea)
		ci.draw_line(a, c, Color(1.0, 0.25, 0.06, minf(ea, 1.0)), maxf(1.5, 0.0085 * h), true)
		ci.draw_line(a.lerp(c, 0.2), a.lerp(c, 0.8), Color(1.0, 0.8, 0.5, minf(ea, 1.0) * 0.8), maxf(1.0, 0.0035 * h), true)
	# fanged maw
	_line(ci, b, h, [Vector2(-0.055, 0.785), Vector2(0.0, 0.775), Vector2(0.055, 0.785)], Color(0, 0, 0, 0.9), 0.006)
	for k in range(-2, 3):
		var tx: float = float(k) * 0.02
		ci.draw_colored_polygon(_P(b, h, [Vector2(tx - 0.007, 0.783), Vector2(tx + 0.007, 0.783), Vector2(tx, 0.763)]), Color(0.5, 0.45, 0.42, 0.18 + 0.25 * hot))
	# beard-like jaw spikes
	_facet(ci, b, h, [Vector2(-0.04, 0.765), Vector2(0.04, 0.765), Vector2(0.0, 0.73)], Color(0.05, 0.05, 0.065))

	# ember motes drifting off the horns, tiny and deterministic
	for i in range(6):
		var ph: float = float(i) * 1.7
		var life: float = fposmod(t * 0.18 + ph * 0.37, 1.0)
		var mx: float = (-0.30 if i % 2 == 0 else 0.30) + 0.03 * sin(t + ph)
		var my: float = 1.05 + life * 0.18
		ci.draw_circle(b + Vector2(mx * h, -my * h), maxf(0.8, h * 0.0018), Color(1.0, 0.4, 0.1, (1.0 - life) * (0.25 + 0.4 * hot)))


static func _P(b: Vector2, h: float, pts: Array, off: Vector2 = Vector2.ZERO, mir: bool = false) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		var q: Vector2 = p
		var y: float = -q.y * h
		if mir:
			y = q.y * h * 0.5
		out.append(Vector2(b.x + q.x * h + off.x, b.y + y + off.y))
	return out


static func _mx(pts: Array) -> Array:
	var out: Array = []
	for p in pts:
		var q: Vector2 = p
		out.append(Vector2(-q.x, q.y))
	return out


static func _smooth(p: Array, n: int = 6) -> Array:
	var out: Array = []
	var cnt: int = p.size()
	for i in range(cnt - 1):
		var p0: Vector2 = p[maxi(i - 1, 0)]
		var p1: Vector2 = p[i]
		var p2: Vector2 = p[i + 1]
		var p3: Vector2 = p[mini(i + 2, cnt - 1)]
		for k in range(n):
			out.append(p1.cubic_interpolate(p2, p0, p3, float(k) / float(n)))
	out.append(p[cnt - 1])
	return out


static func _tube(c: Array, w0: float, w1: float) -> Array:
	var l: Array = []
	var r: Array = []
	var n: int = c.size()
	for i in range(n):
		var a: Vector2 = c[maxi(i - 1, 0)]
		var bb: Vector2 = c[mini(i + 1, n - 1)]
		var d: Vector2 = (bb - a).normalized()
		var nr := Vector2(-d.y, d.x)
		var w: float = maxf(lerpf(w0, w1, float(i) / float(n - 1)), 0.0015) * 0.5
		var cc: Vector2 = c[i]
		l.append(cc + nr * w)
		r.append(cc - nr * w)
	r.reverse()
	return l + r


static func _circ(c: Vector2, rx: float, ry: float, n: int = 16) -> Array:
	var out: Array = []
	for i in range(n):
		var a: float = TAU * float(i) / float(n)
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return out


static func _part(ci: CanvasItem, b: Vector2, h: float, pts: Array, hot: float, body: Color = BODY) -> void:
	ci.draw_colored_polygon(_P(b, h, pts, Vector2(-0.004 * h, 0.0)), Color(0.45, 0.6, 0.9, 0.15))
	ci.draw_colored_polygon(_P(b, h, pts, Vector2(0.007 * h, 0.006 * h)), Color(RIM.r, RIM.g, RIM.b, 0.24 + 0.5 * hot))
	ci.draw_colored_polygon(_P(b, h, pts), body)


static func _facet(ci: CanvasItem, b: Vector2, h: float, pts: Array, col: Color) -> void:
	ci.draw_colored_polygon(_P(b, h, pts), col)


static func _line(ci: CanvasItem, b: Vector2, h: float, pts: Array, col: Color, w: float) -> void:
	ci.draw_polyline(_P(b, h, pts), col, maxf(1.0, w * h), true)


static func _glow(ci: CanvasItem, p: Vector2, r: float, col: Color, a: float) -> void:
	for k in range(5):
		ci.draw_circle(p, r * (0.5 + float(k) * 1.0), Color(col.r, col.g, col.b, a * 0.34 / (1.0 + float(k) * 0.7)))


static func _ell(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	var out := PackedVector2Array()
	for i in range(28):
		var a: float = TAU * float(i) / 28.0
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(out, col)


static func _shadow(ci: CanvasItem, b: Vector2, w: float, hot: float) -> void:
	for k in range(7):
		var s: float = 1.0 + float(k) * 0.16
		_ell(ci, b, w * s, w * s * 0.11, Color(0, 0, 0, 0.16))
	for k in range(4):
		var s2: float = 0.5 + float(k) * 0.28
		_ell(ci, b + Vector2(0, 2), w * s2, w * s2 * 0.10, Color(RIM.r, RIM.g, RIM.b, (0.035 + 0.05 * hot) / (1.0 + float(k))))


static func _reflect(ci: CanvasItem, b: Vector2, h: float, parts: Array, hot: float) -> void:
	for pt in parts:
		ci.draw_colored_polygon(_P(b, h, pt, Vector2.ZERO, true), Color(RIM.r, RIM.g, RIM.b, 0.035 + 0.05 * hot))
