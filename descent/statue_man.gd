extends RefCounted
## Obsidian statue of a plain man in a long coat. Called from a CanvasItem's _draw().

const BODY := Color(0.02, 0.022, 0.03)
const BODY2 := Color(0.035, 0.04, 0.052)


static func _P(b: Vector2, h: float, x: float, y: float) -> Vector2:
	return b + Vector2(x * h, -y * h)


static func _poly(ci: CanvasItem, b: Vector2, h: float, pts: Array, col: Color) -> void:
	var v := PackedVector2Array()
	for p in pts:
		v.append(_P(b, h, p[0], p[1]))
	ci.draw_colored_polygon(v, col)


static func _line(ci: CanvasItem, b: Vector2, h: float, pts: Array, col: Color, w: float) -> void:
	var v := PackedVector2Array()
	for p in pts:
		v.append(_P(b, h, p[0], p[1]))
	ci.draw_polyline(v, col, w, true)


static func draw(ci: CanvasItem, base: Vector2, h: float, t: float, hot: float) -> void:
	var rim := Color(0.5, 0.78, 0.82, 0.30 + 0.35 * hot + 0.03 * sin(t * 1.1))
	var rim2 := Color(rim.r, rim.g, rim.b, rim.a * 0.45)
	# long faint shadow + contact shadow
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-h * 0.1, 0), base + Vector2(h * 0.1, 1),
		base + Vector2(h * 0.95, h * 0.045), base + Vector2(h * 0.6, h * 0.0)]), Color(0, 0, 0, 0.18))
	for i in 4:
		var f := 1.0 - i * 0.2
		var pts := PackedVector2Array()
		for j in 20:
			var a := TAU * j / 20.0
			pts.append(base + Vector2(cos(a) * h * 0.2 * f, sin(a) * h * 0.03 * f + 1))
		ci.draw_colored_polygon(pts, Color(0, 0, 0, 0.18))
	if hot > 0.01:
		var gp := PackedVector2Array()
		for j in 20:
			var a := TAU * j / 20.0
			gp.append(base + Vector2(cos(a) * h * 0.2, sin(a) * h * 0.025))
		ci.draw_colored_polygon(gp, Color(0.3, 0.6, 0.65, 0.07 * hot))
	for i in 5:
		ci.draw_line(_P(base, -h, -0.07 + i * 0.006, 0.01 + i * 0.05), _P(base, -h, 0.07 - i * 0.006, 0.01 + i * 0.05), Color(0.45, 0.7, 0.75, 0.04 * (1.0 - i / 5.0)), 2.0)
	# shoes + trousers
	_poly(ci, base, h, [[-0.075, 0.0], [-0.07, 0.025], [-0.02, 0.025], [-0.015, 0.0]], BODY2)
	_poly(ci, base, h, [[0.015, 0.0], [0.02, 0.025], [0.075, 0.025], [0.085, 0.0]], BODY2)
	_poly(ci, base, h, [[-0.06, 0.02], [-0.065, 0.08], [-0.01, 0.08], [-0.005, 0.02]], Color(0.015, 0.016, 0.022))
	_poly(ci, base, h, [[0.01, 0.02], [0.01, 0.08], [0.07, 0.08], [0.07, 0.02]], Color(0.015, 0.016, 0.022))
	# long coat
	var coat := [[-0.085, 0.10], [-0.095, 0.3], [-0.11, 0.55], [-0.125, 0.74], [-0.11, 0.80], [-0.05, 0.835], [0.05, 0.835],
		[0.11, 0.80], [0.125, 0.74], [0.11, 0.55], [0.1, 0.3], [0.09, 0.10]]
	_poly(ci, base, h, coat, BODY)
	_poly(ci, base, h, [[0.03, 0.11], [0.025, 0.3], [0.04, 0.6], [0.05, 0.82], [0.11, 0.8], [0.125, 0.74], [0.11, 0.55], [0.1, 0.3], [0.09, 0.11]], BODY2)
	_line(ci, base, h, [[0.0, 0.1], [0.003, 0.4], [0.0, 0.76]], Color(0, 0, 0, 0.7), 1.5)
	_line(ci, base, h, [[0.0, 0.76], [-0.045, 0.7], [-0.02, 0.62]], Color(0, 0, 0, 0.6), 1.4)
	_line(ci, base, h, [[0.0, 0.76], [0.045, 0.7], [0.02, 0.62]], rim2, 1.0)
	for i in 4:
		ci.draw_circle(_P(base, h, 0.012, 0.56 - i * 0.1), 1.0, Color(rim.r, rim.g, rim.b, 0.25))
	for xf in [-0.05, 0.065]:
		_line(ci, base, h, [[xf, 0.1], [xf * 1.05, 0.3], [xf * 1.1, 0.5]], Color(0, 0, 0, 0.4), 1.6)
	_line(ci, base, h, [[0.09, 0.11], [0.1, 0.3], [0.11, 0.55]], rim2, 1.0)
	# arms hanging, hands
	_poly(ci, base, h, [[-0.125, 0.74], [-0.145, 0.6], [-0.14, 0.38], [-0.125, 0.33], [-0.1, 0.34], [-0.1, 0.6], [-0.095, 0.72]], BODY)
	_poly(ci, base, h, [[0.125, 0.74], [0.145, 0.6], [0.14, 0.38], [0.125, 0.33], [0.1, 0.34], [0.1, 0.6], [0.095, 0.72]], BODY2)
	_line(ci, base, h, [[-0.125, 0.74], [-0.145, 0.6], [-0.14, 0.38]], rim2, 1.0)
	_line(ci, base, h, [[0.125, 0.74], [0.145, 0.6], [0.14, 0.38]], rim, 1.3)
	_poly(ci, base, h, [[-0.14, 0.38], [-0.145, 0.3], [-0.13, 0.28], [-0.115, 0.3], [-0.12, 0.35]], BODY2)
	_poly(ci, base, h, [[0.14, 0.38], [0.15, 0.3], [0.135, 0.28], [0.12, 0.3], [0.12, 0.35]], BODY2)
	_line(ci, base, h, [[0.15, 0.31], [0.147, 0.29]], rim, 1.0)
	# collar + neck
	_poly(ci, base, h, [[-0.035, 0.82], [-0.03, 0.87], [0.03, 0.87], [0.035, 0.82]], BODY2)
	_poly(ci, base, h, [[-0.06, 0.82], [-0.03, 0.86], [0.0, 0.8], [0.03, 0.86], [0.06, 0.82], [0.0, 0.77]], BODY)
	_line(ci, base, h, [[0.03, 0.86], [0.06, 0.82]], rim, 1.0)
	# head, lowered slightly forward
	var hc := Vector2(0.012, 0.915)
	var hp := PackedVector2Array()
	for i in 22:
		var a := TAU * i / 22.0
		var x := cos(a) * 0.04
		var y := sin(a) * 0.052
		if y < 0:
			x *= 0.8 + 0.2 * (1.0 + y / 0.052)
		hp.append(_P(base, h, hc.x + x, hc.y + y))
	ci.draw_colored_polygon(hp, Color(0.016, 0.017, 0.022))
	var hair := PackedVector2Array()
	for i in range(0, 13):
		var a := PI * 0.02 + PI * 0.98 * i / 12.0
		hair.append(_P(base, h, hc.x + cos(a) * 0.043, hc.y + 0.004 + sin(a) * 0.056))
	hair.append(_P(base, h, hc.x - 0.04, hc.y + 0.012))
	hair.append(_P(base, h, hc.x + 0.038, hc.y + 0.018))
	ci.draw_colored_polygon(hair, BODY2)
	var hr := PackedVector2Array()
	for i in range(0, 8):
		var a := PI * 0.05 + PI * 0.45 * i / 7.0
		hr.append(_P(base, h, hc.x + cos(a) * 0.044, hc.y + 0.004 + sin(a) * 0.057))
	ci.draw_polyline(hr, rim, 1.3, true)
	var jaw := PackedVector2Array()
	for i in range(0, 7):
		var a := -PI * 0.05 - PI * 0.4 * i / 6.0
		jaw.append(_P(base, h, hc.x + cos(a) * 0.04 * (0.9 if a < -0.5 else 1.0), hc.y + sin(a) * 0.052))
	ci.draw_polyline(jaw, Color(rim.r, rim.g, rim.b, minf(rim.a * 1.4, 1.0)), 1.3, true)
	var ey := _P(base, h, hc.x + 0.014, hc.y - 0.002)
	ci.draw_line(ey + Vector2(-2.5, 0), ey + Vector2(2.5, 0.3), Color(0.8, 0.95, 1.0, 0.35 + 0.35 * hot), 1.0)
	ci.draw_line(_P(base, h, hc.x - 0.03, hc.y + 0.012), _P(base, h, hc.x + 0.035, hc.y + 0.012), Color(0, 0, 0, 0.55), 2.5)
	ci.draw_line(_P(base, h, 0.075, 0.7), _P(base, h, 0.08, 0.45), Color(0.7, 0.85, 0.9, 0.08), 1.0)
	ci.draw_line(_P(base, h, 0.05, 0.3), _P(base, h, 0.055, 0.15), Color(0.7, 0.85, 0.9, 0.06), 1.0)
	_line(ci, base, h, [[-0.06, 0.5], [-0.07, 0.42], [-0.055, 0.36], [-0.065, 0.28]], Color(rim.r, rim.g, rim.b, 0.18), 1.0)
