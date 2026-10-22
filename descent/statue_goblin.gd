extends RefCounted
## Obsidian goblin statue: small, hunched, mischievous. Pure draw helper.

const BODY := Color(0.034, 0.035, 0.05)
const FACET := Color(0.072, 0.075, 0.098)
const RIM := Color(0.95, 0.33, 0.08)


static func draw(ci: CanvasItem, base: Vector2, h: float, t: float, hot: float) -> void:
	var b := base
	var flick: float = 1.0 + 0.09 * sin(t * 6.3) + 0.05 * sin(t * 13.7 + 1.0)

	# --- silhouette parts (unit coords: x/h, y up/h) ---
	var leg_l: Array = [Vector2(-0.30, 0.0), Vector2(-0.09, 0.0), Vector2(-0.11, 0.09), Vector2(-0.06, 0.24), Vector2(-0.20, 0.30), Vector2(-0.27, 0.15)]
	var leg_r: Array = [Vector2(0.05, 0.0), Vector2(0.30, 0.0), Vector2(0.26, 0.07), Vector2(0.21, 0.24), Vector2(0.07, 0.30), Vector2(0.09, 0.12)]
	var claw_l: Array = [Vector2(-0.30, 0.0), Vector2(-0.38, 0.004), Vector2(-0.29, 0.035)]
	var claw_r: Array = [Vector2(0.30, 0.0), Vector2(0.38, 0.004), Vector2(0.29, 0.035)]
	var torso: Array = [Vector2(-0.22, 0.28), Vector2(0.17, 0.28), Vector2(0.25, 0.44), Vector2(0.22, 0.60), Vector2(0.06, 0.68), Vector2(-0.16, 0.66), Vector2(-0.27, 0.50)]
	var hump: Array = [Vector2(-0.02, 0.66), Vector2(0.10, 0.73), Vector2(0.22, 0.66), Vector2(0.24, 0.58), Vector2(0.06, 0.64)]
	var arm_r: Array = _tube(_smooth([Vector2(0.12, 0.64), Vector2(0.22, 0.54), Vector2(0.27, 0.44), Vector2(0.24, 0.36)], 5), 0.055, 0.035)
	var arm_l: Array = _tube(_smooth([Vector2(-0.20, 0.62), Vector2(-0.28, 0.52), Vector2(-0.32, 0.42), Vector2(-0.30, 0.37)], 5), 0.055, 0.035)
	var pouch: Array = _circ(Vector2(0.25, 0.31), 0.062, 0.07)
	var ear_l: Array = [Vector2(-0.22, 0.85), Vector2(-0.36, 0.90), Vector2(-0.56, 0.99), Vector2(-0.40, 0.80), Vector2(-0.24, 0.76)]
	var ear_r: Array = [Vector2(0.02, 0.82), Vector2(0.14, 0.90), Vector2(0.35, 0.97), Vector2(0.22, 0.78), Vector2(0.05, 0.74)]
	var head: Array = [Vector2(-0.26, 0.74), Vector2(-0.21, 0.68), Vector2(-0.08, 0.66), Vector2(0.03, 0.70), Vector2(0.06, 0.80), Vector2(0.00, 0.88), Vector2(-0.15, 0.89), Vector2(-0.25, 0.84)]
	var nose: Array = [Vector2(-0.25, 0.80), Vector2(-0.44, 0.73), Vector2(-0.27, 0.735)]
	var neck: Array = [Vector2(-0.14, 0.62), Vector2(0.02, 0.64), Vector2(0.0, 0.72), Vector2(-0.15, 0.72)]
	var dagger: Array = _tube([Vector2(-0.30, 0.43), Vector2(-0.305, 0.52), Vector2(-0.315, 0.64)], 0.04, 0.004)
	var hilt: Array = [Vector2(-0.345, 0.425), Vector2(-0.26, 0.425), Vector2(-0.26, 0.44), Vector2(-0.345, 0.44)]
	var all_parts: Array = [leg_l, leg_r, torso, hump, arm_r, arm_l, head, ear_l, ear_r, nose, dagger, pouch]

	# --- floor: shadow, warm underglow, reflection ---
	_shadow(ci, b, h * 0.36, hot)
	_ell(ci, b + Vector2(0, 3), h * 0.30, h * 0.035, Color(RIM.r, RIM.g, RIM.b, 0.05 + 0.07 * hot))
	_reflect(ci, b, h, all_parts, hot)

	# --- body ---
	_part(ci, b, h, leg_r, hot)
	_part(ci, b, h, claw_r, hot)
	_part(ci, b, h, leg_l, hot)
	_part(ci, b, h, claw_l, hot)
	_part(ci, b, h, torso, hot)
	_part(ci, b, h, hump, hot)
	_part(ci, b, h, arm_r, hot)
	_part(ci, b, h, pouch, hot, Color(0.05, 0.045, 0.055))
	_part(ci, b, h, neck, hot)
	_part(ci, b, h, ear_r, hot)
	_part(ci, b, h, ear_l, hot)
	_part(ci, b, h, head, hot)
	_part(ci, b, h, nose, hot)
	_part(ci, b, h, arm_l, hot)
	_part(ci, b, h, hilt, hot, Color(0.06, 0.05, 0.055))
	_part(ci, b, h, dagger, hot, Color(0.05, 0.055, 0.08))

	# --- sculpted facets (lighter planes, upper-left light) ---
	_facet(ci, b, h, [Vector2(-0.20, 0.64), Vector2(-0.02, 0.66), Vector2(0.08, 0.60), Vector2(-0.10, 0.52), Vector2(-0.22, 0.54)], FACET)
	_facet(ci, b, h, [Vector2(-0.20, 0.50), Vector2(-0.04, 0.46), Vector2(-0.10, 0.34), Vector2(-0.20, 0.32)], Color(0.055, 0.057, 0.075))
	_facet(ci, b, h, [Vector2(-0.22, 0.28), Vector2(-0.12, 0.30), Vector2(-0.18, 0.12), Vector2(-0.26, 0.15)], Color(0.06, 0.062, 0.08))
	_facet(ci, b, h, [Vector2(-0.24, 0.83), Vector2(-0.16, 0.88), Vector2(-0.06, 0.86), Vector2(-0.20, 0.80)], FACET)
	_facet(ci, b, h, [Vector2(-0.30, 0.88), Vector2(-0.42, 0.94), Vector2(-0.34, 0.86)], Color(0.1, 0.06, 0.06))
	_facet(ci, b, h, [Vector2(0.12, 0.86), Vector2(0.27, 0.94), Vector2(0.18, 0.82)], Color(0.1, 0.06, 0.06))
	_facet(ci, b, h, [Vector2(0.02, 0.68), Vector2(0.12, 0.70), Vector2(0.18, 0.62), Vector2(0.08, 0.62)], FACET)

	# --- specular streaks ---
	var spec := Color(0.55, 0.65, 0.85, 0.20)
	_line(ci, b, h, [Vector2(-0.25, 0.52), Vector2(-0.22, 0.60), Vector2(-0.15, 0.65)], spec, 0.006)
	_line(ci, b, h, [Vector2(-0.23, 0.84), Vector2(-0.17, 0.885), Vector2(-0.08, 0.885)], Color(0.7, 0.75, 0.95, 0.28), 0.006)
	_line(ci, b, h, [Vector2(-0.27, 0.16), Vector2(-0.22, 0.28)], spec, 0.005)
	_line(ci, b, h, [Vector2(0.08, 0.12), Vector2(0.10, 0.24)], spec, 0.005)
	_line(ci, b, h, [Vector2(-0.52, 0.98), Vector2(-0.38, 0.90), Vector2(-0.24, 0.86)], spec, 0.005)

	# --- cracks (ember seeping) ---
	var crack := Color(1.0, 0.4, 0.1, 0.20 + 0.35 * hot)
	_line(ci, b, h, [Vector2(0.10, 0.56), Vector2(0.14, 0.48), Vector2(0.11, 0.42), Vector2(0.16, 0.34)], crack, 0.004)
	_line(ci, b, h, [Vector2(-0.14, 0.24), Vector2(-0.17, 0.18), Vector2(-0.13, 0.10)], crack, 0.004)
	_line(ci, b, h, [Vector2(0.16, 0.22), Vector2(0.13, 0.15)], crack, 0.004)

	# --- brow, grin, teeth ---
	_line(ci, b, h, [Vector2(-0.215, 0.825), Vector2(-0.15, 0.80), Vector2(-0.09, 0.795)], Color(0.0, 0.0, 0.0, 0.9), 0.012)
	_line(ci, b, h, [Vector2(-0.07, 0.80), Vector2(0.0, 0.832)], Color(0.0, 0.0, 0.0, 0.9), 0.012)
	var grin: Array = _smooth([Vector2(-0.235, 0.725), Vector2(-0.17, 0.700), Vector2(-0.08, 0.692), Vector2(0.0, 0.705), Vector2(0.04, 0.735)], 5)
	_line(ci, b, h, grin, Color(0, 0, 0, 0.95), 0.016)
	var tooth_col := Color(0.62, 0.5, 0.42, 0.42 + 0.35 * hot)
	var tn: int = grin.size()
	for i in range(1, tn - 1, 2):
		var g0: Vector2 = grin[i]
		var g1: Vector2 = grin[mini(i + 1, tn - 1)]
		var tip: Vector2 = (g0 + g1) * 0.5 + Vector2(0.0, -0.026 if i % 4 == 1 else -0.018)
		var up: Vector2 = Vector2(0.0, 0.012)
		ci.draw_colored_polygon(_P(b, h, [g0 + up, g1 + up, tip]), tooth_col)
	# a few lower teeth peeking up
	for i in range(2, tn - 2, 4):
		var q: Vector2 = grin[i]
		ci.draw_colored_polygon(_P(b, h, [q + Vector2(-0.01, -0.012), q + Vector2(0.01, -0.012), q + Vector2(0.0, 0.016)]), Color(0.5, 0.4, 0.34, 0.3 + 0.3 * hot))

	# --- eyes: amber, alive ---
	var ea: float = (0.55 + 0.45 * hot) * flick
	var eye_c := Color(1.0, 0.62, 0.12)
	var e1 := b + Vector2(-0.150 * h, -0.790 * h)
	var e2 := b + Vector2(-0.040 * h, -0.800 * h)
	_glow(ci, e1, h * 0.016, eye_c, ea)
	_glow(ci, e2, h * 0.016, eye_c, ea)
	ci.draw_circle(e1, h * 0.0105, Color(1.0, 0.72, 0.22, minf(ea, 1.0)))
	ci.draw_circle(e2, h * 0.0105, Color(1.0, 0.72, 0.22, minf(ea, 1.0)))
	ci.draw_circle(e1, h * 0.0045, Color(1.0, 0.95, 0.7, minf(ea * 1.2, 1.0)))
	ci.draw_circle(e2, h * 0.0045, Color(1.0, 0.95, 0.7, minf(ea * 1.2, 1.0)))

	# --- dagger glint + grip fingers ---
	_line(ci, b, h, [Vector2(-0.312, 0.62), Vector2(-0.304, 0.50), Vector2(-0.298, 0.45)], Color(0.55, 0.75, 1.0, 0.45 + 0.3 * hot), 0.005)
	_line(ci, b, h, [Vector2(-0.322, 0.60), Vector2(-0.314, 0.48)], Color(1.0, 0.45, 0.12, 0.25 + 0.3 * hot), 0.004)
	for k in range(3):
		var fy: float = 0.375 + float(k) * 0.016
		_line(ci, b, h, [Vector2(-0.33, fy), Vector2(-0.28, fy - 0.004)], Color(0.0, 0.0, 0.0, 0.6), 0.004)
	# pouch drawstring
	_line(ci, b, h, [Vector2(0.20, 0.355), Vector2(0.25, 0.37), Vector2(0.30, 0.355)], Color(0.7, 0.4, 0.2, 0.25 + 0.2 * hot), 0.004)
	_line(ci, b, h, [Vector2(0.20, 0.30), Vector2(0.215, 0.26)], Color(0.7, 0.75, 0.9, 0.18), 0.004)
	# spine bumps
	for k in range(4):
		var sx: float = 0.02 + float(k) * 0.065
		var sy: float = 0.725 - float(k) * 0.045
		_facet(ci, b, h, [Vector2(sx, sy), Vector2(sx + 0.03, sy + 0.035), Vector2(sx + 0.045, sy - 0.01)], Color(0.05, 0.05, 0.065))


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
