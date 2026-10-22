extends RefCounted
## Obsidian angel: robed, hooded, wings half-open, hands on the hilt of a colossal sword. Pure draw helper.

const BODY := Color(0.034, 0.035, 0.05)
const FACET := Color(0.072, 0.075, 0.098)
const RIM := Color(0.95, 0.33, 0.08)


static func draw(ci: CanvasItem, base: Vector2, h: float, t: float, hot: float) -> void:
	var b := base
	var flick: float = 1.0 + 0.06 * sin(t * 3.7) + 0.04 * sin(t * 9.1 + 0.6)
	var spec := Color(0.6, 0.7, 0.95, 0.20)
	var ice := Color(0.55, 0.78, 1.0)
	var crack := Color(1.0, 0.35, 0.08, 0.14 + 0.35 * hot)

	# ---------- silhouette parts ----------
	var robe: Array = [Vector2(-0.19, 0.0), Vector2(0.19, 0.0), Vector2(0.165, 0.18), Vector2(0.13, 0.42), Vector2(0.125, 0.58), Vector2(0.115, 0.72), Vector2(-0.115, 0.72), Vector2(-0.125, 0.58), Vector2(-0.13, 0.42), Vector2(-0.165, 0.18)]
	var hem: Array = [Vector2(-0.20, 0.0), Vector2(-0.14, 0.035), Vector2(-0.07, 0.0), Vector2(0.0, 0.04), Vector2(0.07, 0.0), Vector2(0.14, 0.035), Vector2(0.20, 0.0)]
	var mantle: Array = [Vector2(-0.17, 0.70), Vector2(-0.10, 0.76), Vector2(0.10, 0.76), Vector2(0.17, 0.70), Vector2(0.19, 0.60), Vector2(0.0, 0.64), Vector2(-0.19, 0.60)]
	var hood: Array = [Vector2(-0.10, 0.74), Vector2(-0.085, 0.84), Vector2(-0.05, 0.925), Vector2(0.0, 0.945), Vector2(0.05, 0.925), Vector2(0.085, 0.84), Vector2(0.10, 0.74), Vector2(0.0, 0.72)]
	var sleeve_l: Array = _tube(_smooth([Vector2(-0.14, 0.70), Vector2(-0.17, 0.64), Vector2(-0.10, 0.60), Vector2(-0.025, 0.575)], 5), 0.085, 0.06)
	var sleeve_r: Array = _mx(sleeve_l)
	var sword_blade: Array = [Vector2(-0.024, 0.52), Vector2(0.024, 0.52), Vector2(0.026, 0.12), Vector2(0.0, -0.025), Vector2(-0.026, 0.12)]
	var guard: Array = [Vector2(-0.125, 0.515), Vector2(-0.10, 0.535), Vector2(0.10, 0.535), Vector2(0.125, 0.515), Vector2(0.11, 0.50), Vector2(0.03, 0.51), Vector2(-0.03, 0.51), Vector2(-0.11, 0.50)]
	var grip: Array = [Vector2(-0.014, 0.535), Vector2(0.014, 0.535), Vector2(0.014, 0.625), Vector2(-0.014, 0.625)]
	var pommel: Array = _circ(Vector2(0.0, 0.64), 0.024, 0.024, 12)
	var wing_bone_l: Array = _smooth([Vector2(-0.08, 0.70), Vector2(-0.20, 0.82), Vector2(-0.34, 0.90), Vector2(-0.47, 0.93)], 6)
	var wing_bone_r: Array = _mx(wing_bone_l)

	# feathers: layered, drooping and fanning outward (half-open)
	var feathers_l: Array = []
	var nb: int = wing_bone_l.size()
	for i in range(0, nb, 2):
		var bp: Vector2 = wing_bone_l[i]
		var f: float = float(i) / float(nb - 1)
		var tipv := Vector2(-0.06 - 0.09 * f, -(0.27 - 0.10 * f) - 0.03 * sin(float(i) * 1.3))
		feathers_l.append(_tube(_smooth([bp, bp + tipv * 0.5 + Vector2(-0.015, 0.0), bp + tipv], 4), 0.05, 0.006))
	var all_parts: Array = [robe, mantle, hood, sword_blade]
	for fe in feathers_l:
		all_parts.append(fe)
		all_parts.append(_mx(fe))

	# ---------- floor ----------
	_shadow(ci, b, h * 0.26, hot)
	_ell(ci, b + Vector2(0, 3), h * 0.22, h * 0.018, Color(RIM.r, RIM.g, RIM.b, 0.04 + 0.05 * hot))
	_reflect(ci, b, h, all_parts, hot)
	# blade reflection (cold)
	ci.draw_line(b + Vector2(0, h * 0.012), b + Vector2(0, h * 0.14), Color(ice.r, ice.g, ice.b, 0.05 + 0.06 * hot), maxf(1.5, h * 0.004), true)

	# ---------- halo (cracked, dim) behind the head ----------
	var hc: Vector2 = b + Vector2(0.0, -0.925 * h)
	var seg: Array = [[0.15, 1.1], [1.35, 2.4], [2.65, 4.5], [4.75, 6.1]]
	for sgm in seg:
		var a0: float = sgm[0]
		var a1: float = sgm[1]
		var pts := PackedVector2Array()
		for k in range(11):
			var aa: float = lerpf(a0, a1, float(k) / 10.0)
			pts.append(hc + Vector2(cos(aa) * h * 0.105, sin(aa) * h * 0.105 * 0.55))
		ci.draw_polyline(pts, Color(0.30, 0.26, 0.28, 0.20), maxf(3.0, h * 0.012), true)
		ci.draw_polyline(pts, Color(0.55, 0.5, 0.52, 0.22), maxf(1.0, h * 0.004), true)
		ci.draw_polyline(pts, Color(RIM.r, RIM.g, RIM.b, 0.12 + 0.3 * hot), maxf(1.0, h * 0.0025), true)

	# ---------- wings (back layer) ----------
	for i2 in range(feathers_l.size() - 1, -1, -1):
		var fl: Array = feathers_l[i2]
		var fr: Array = _mx(fl)
		var tone: float = 0.026 + 0.004 * float(i2 % 2)
		_part(ci, b, h, fr, hot, Color(tone, tone + 0.001, tone + 0.014))
		_part(ci, b, h, fl, hot, Color(tone, tone + 0.001, tone + 0.014))
		# feather spine highlight
		var c0: Vector2 = fl[0]
		var cm: Vector2 = fl[fl.size() / 2]
		_line(ci, b, h, [c0, (c0 + cm) * 0.5 + Vector2(-0.01, -0.05), cm + Vector2(0.0, -0.01)], Color(0.6, 0.7, 0.95, 0.09), 0.003)
	var bone_l: Array = _tube(wing_bone_l, 0.035, 0.012)
	_part(ci, b, h, _mx(bone_l), hot, Color(0.05, 0.05, 0.065))
	_part(ci, b, h, bone_l, hot, Color(0.05, 0.05, 0.065))
	_line(ci, b, h, wing_bone_l, spec, 0.004)
	_line(ci, b, h, wing_bone_r, Color(0.5, 0.6, 0.9, 0.12), 0.003)

	# ---------- body ----------
	_part(ci, b, h, robe, hot)
	_part(ci, b, h, hem, hot, Color(0.045, 0.046, 0.062))
	_part(ci, b, h, mantle, hot, Color(0.045, 0.046, 0.062))
	_part(ci, b, h, hood, hot)
	# robe fold planes
	_facet(ci, b, h, [Vector2(-0.18, 0.18), Vector2(-0.10, 0.20), Vector2(-0.08, 0.04), Vector2(-0.17, 0.02)], FACET)
	_facet(ci, b, h, [Vector2(-0.12, 0.44), Vector2(-0.05, 0.46), Vector2(-0.06, 0.20), Vector2(-0.13, 0.20)], Color(0.06, 0.062, 0.082))
	_facet(ci, b, h, [Vector2(0.06, 0.42), Vector2(0.12, 0.40), Vector2(0.15, 0.18), Vector2(0.08, 0.20)], Color(0.05, 0.052, 0.07))
	_facet(ci, b, h, [Vector2(-0.12, 0.70), Vector2(-0.04, 0.72), Vector2(-0.05, 0.62), Vector2(-0.12, 0.60)], FACET)
	_facet(ci, b, h, [Vector2(-0.16, 0.69), Vector2(-0.10, 0.75), Vector2(-0.12, 0.65)], Color(0.09, 0.092, 0.115))
	for fx in [-0.12, -0.06, 0.05, 0.11]:
		_line(ci, b, h, [Vector2(fx, 0.50), Vector2(fx * 1.2, 0.30), Vector2(fx * 1.5, 0.04)], Color(0, 0, 0, 0.55), 0.004)
	_line(ci, b, h, [Vector2(-0.12, 0.58), Vector2(-0.13, 0.30), Vector2(-0.17, 0.10)], spec, 0.004)
	_line(ci, b, h, [Vector2(-0.12, 0.74), Vector2(-0.085, 0.84), Vector2(-0.05, 0.92)], Color(0.7, 0.78, 0.98, 0.26), 0.004)
	# face void under hood
	var face: Array = _circ(Vector2(0.0, 0.83), 0.046, 0.065, 18)
	_facet(ci, b, h, face, Color(0.006, 0.006, 0.01))
	_line(ci, b, h, face + [face[0]], Color(0.4, 0.5, 0.75, 0.10), 0.003)
	# stern mark: two faint cold-ember eye points and a brow cut
	var ea: float = 0.14 + 0.35 * hot
	var el := b + Vector2(-0.018 * h, -0.835 * h)
	var er := b + Vector2(0.018 * h, -0.835 * h)
	_glow(ci, el, h * 0.007, ice, ea * flick)
	_glow(ci, er, h * 0.007, ice, ea * flick)
	_line(ci, b, h, [Vector2(-0.04, 0.855), Vector2(-0.01, 0.846)], Color(0.2, 0.25, 0.4, 0.4), 0.003)
	_line(ci, b, h, [Vector2(0.04, 0.855), Vector2(0.01, 0.846)], Color(0.2, 0.25, 0.4, 0.4), 0.003)

	# ---------- sword (in front) ----------
	_part(ci, b, h, sword_blade, hot, Color(0.05, 0.055, 0.075))
	# fuller
	_line(ci, b, h, [Vector2(0.0, 0.50), Vector2(0.0, 0.10)], Color(0.01, 0.01, 0.02, 0.8), 0.006)
	# cold edge glint, brightens with hover
	var gl: float = 0.38 + 0.4 * hot
	_line(ci, b, h, [Vector2(-0.024, 0.515), Vector2(-0.0255, 0.12), Vector2(0.0, -0.022)], Color(ice.r, ice.g, ice.b, gl), 0.0035)
	_line(ci, b, h, [Vector2(0.024, 0.515), Vector2(0.0255, 0.12), Vector2(0.0, -0.022)], Color(ice.r, ice.g, ice.b, gl * 0.6), 0.0030)
	# travelling glint
	var gy: float = 0.08 + 0.4 * fposmod(t * 0.12, 1.0)
	_glow(ci, b + Vector2(-0.024 * h, -gy * h), h * 0.006, ice, 0.5 + 0.4 * hot)
	_part(ci, b, h, guard, hot, Color(0.055, 0.055, 0.075))
	_line(ci, b, h, [Vector2(-0.125, 0.515), Vector2(-0.10, 0.535), Vector2(0.10, 0.535), Vector2(0.125, 0.515)], Color(0.7, 0.8, 1.0, 0.3), 0.003)
	_part(ci, b, h, grip, hot, Color(0.04, 0.04, 0.055))
	for k in range(5):
		var gy2: float = 0.545 + float(k) * 0.016
		_line(ci, b, h, [Vector2(-0.014, gy2), Vector2(0.014, gy2 + 0.008)], Color(0, 0, 0, 0.7), 0.003)
	_part(ci, b, h, pommel, hot, Color(0.06, 0.06, 0.08))
	_line(ci, b, h, [Vector2(-0.016, 0.655), Vector2(0.0, 0.664)], spec, 0.003)

	# sleeves and hands gripping the hilt
	_part(ci, b, h, sleeve_r, hot, Color(0.04, 0.041, 0.056))
	_part(ci, b, h, sleeve_l, hot, Color(0.04, 0.041, 0.056))
	_part(ci, b, h, _circ(Vector2(-0.012, 0.585), 0.026, 0.022, 10), hot, Color(0.05, 0.05, 0.068))
	_part(ci, b, h, _circ(Vector2(0.014, 0.610), 0.026, 0.022, 10), hot, Color(0.05, 0.05, 0.068))
	for k in range(4):
		var fy: float = 0.575 + float(k) * 0.016
		_line(ci, b, h, [Vector2(-0.034, fy), Vector2(-0.01, fy + 0.002)], Color(0, 0, 0, 0.6), 0.003)
	_line(ci, b, h, [Vector2(-0.17, 0.66), Vector2(-0.12, 0.59), Vector2(-0.05, 0.575)], spec, 0.004)

	# ---------- cracks ----------
	_line(ci, b, h, [Vector2(0.10, 0.66), Vector2(0.14, 0.58), Vector2(0.11, 0.50), Vector2(0.15, 0.40)], crack, 0.003)
	_line(ci, b, h, [Vector2(-0.10, 0.34), Vector2(-0.13, 0.26), Vector2(-0.10, 0.18), Vector2(-0.14, 0.08)], crack, 0.003)
	_line(ci, b, h, [Vector2(0.08, 0.26), Vector2(0.11, 0.18), Vector2(0.09, 0.08)], crack, 0.003)
	_line(ci, b, h, [Vector2(0.07, 0.88), Vector2(0.05, 0.82), Vector2(0.07, 0.77)], crack, 0.003)
	_line(ci, b, h, [Vector2(-0.30, 0.90), Vector2(-0.34, 0.86), Vector2(-0.31, 0.80)], crack, 0.003)


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
