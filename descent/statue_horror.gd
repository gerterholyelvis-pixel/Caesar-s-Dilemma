extends RefCounted
## Obsidian horror statue: tall, wrong, many-limbed. Called from a CanvasItem's _draw().

const BODY := Color(0.022, 0.024, 0.032)
const BODY2 := Color(0.04, 0.042, 0.055)
const RIM := Color(0.62, 0.26, 0.15)
const PALE := Color(0.78, 0.9, 0.95)


static func _P(b: Vector2, h: float, x: float, y: float) -> Vector2:
	return b + Vector2(x * h, -y * h)


static func _poly(ci: CanvasItem, b: Vector2, h: float, pts: Array, col: Color) -> void:
	var v := PackedVector2Array()
	for p in pts:
		v.append(_P(b, h, p.x, p.y))
	ci.draw_colored_polygon(v, col)


static func _limb(ci: CanvasItem, b: Vector2, h: float, pts: Array, w: float, rim: Color) -> void:
	w *= 1.5
	var v := PackedVector2Array()
	for p in pts:
		v.append(_P(b, h, p.x, p.y))
	ci.draw_polyline(v, Color(0, 0, 0, 0.55), w + 2.0, true)
	ci.draw_polyline(v, BODY, w, true)
	var o := PackedVector2Array()
	for p in v:
		o.append(p + Vector2(w * 0.32, -w * 0.18))
	ci.draw_polyline(o, rim, maxf(1.0, w * 0.22), true)
	for p in v:
		ci.draw_circle(p, w * 0.62, BODY2)
	ci.draw_circle(v[1] if v.size() > 1 else v[0], 1.4, rim)


static func _hand(ci: CanvasItem, b: Vector2, h: float, wrist: Vector2, dir: float, n: int, spread: float, flen: float, t: float, seed: float, rim: Color) -> void:
	for i in n:
		var k := float(i) / float(maxi(n - 1, 1)) - 0.5
		var tw := 1.0 if i == 2 else 0.3
		var a := dir + k * spread + sin(t * 0.9 + seed + i * 1.7) * 0.05 * tw
		var l1 := flen * (0.9 + 0.2 * sin(seed * 3.0 + i * 2.1))
		var p1 := wrist + Vector2(cos(a), sin(a)) * l1 * 0.55
		var a2 := a + (0.5 if i % 2 == 0 else -0.35) + sin(t * 1.3 + seed + i) * 0.04
		var p2 := p1 + Vector2(cos(a2), sin(a2)) * l1 * 0.6
		var a3 := a2 + 0.7
		var p3 := p2 + Vector2(cos(a3), sin(a3)) * l1 * 0.3
		var v := PackedVector2Array([_P(b, h, wrist.x, wrist.y), _P(b, h, p1.x, p1.y), _P(b, h, p2.x, p2.y), _P(b, h, p3.x, p3.y)])
		ci.draw_polyline(v, BODY, 1.8, true)
		ci.draw_polyline(PackedVector2Array([v[1] + Vector2(0.8, -0.5), v[2] + Vector2(0.8, -0.5), v[3] + Vector2(0.8, -0.5)]), rim, 1.0, true)


static func _eye(ci: CanvasItem, c: Vector2, r: float, glow: bool, t: float, ph: float, hot: float) -> void:
	ci.draw_circle(c, r * 1.5, Color(0, 0, 0, 0.8))
	if glow:
		var blink := 1.0
		if fposmod(t * 0.37 + ph, 1.0) > 0.94:
			blink = 0.05
		var a := (0.45 + 0.35 * hot) * blink
		ci.draw_circle(c, r * 3.2, Color(PALE.r, PALE.g, PALE.b, 0.06 * blink))
		ci.draw_circle(c, r, Color(PALE.r, PALE.g, PALE.b, a))
		ci.draw_circle(c, r * 0.4, Color(1, 1, 1, a))
	else:
		ci.draw_circle(c, r * 0.8, Color(0.12, 0.13, 0.16, 0.9))
		ci.draw_circle(c + Vector2(r * 0.25, -r * 0.25), r * 0.25, Color(0.5, 0.45, 0.45, 0.5))


static func draw(ci: CanvasItem, base: Vector2, h: float, t: float, hot: float) -> void:
	var rim := Color(RIM.r, RIM.g, RIM.b, 0.36 + 0.4 * hot + 0.04 * sin(t * 1.7))
	var rim2 := Color(rim.r, rim.g, rim.b, rim.a * 0.55)
	# contact shadow, hot glow on glass, reflection
	for i in 5:
		var f := 1.0 - i * 0.17
		var pts := PackedVector2Array()
		for j in 24:
			var a := TAU * j / 24.0
			pts.append(base + Vector2(cos(a) * h * 0.34 * f, sin(a) * h * 0.035 * f + 2))
		ci.draw_colored_polygon(pts, Color(0, 0, 0, 0.16))
	if hot > 0.01:
		var gp := PackedVector2Array()
		for j in 24:
			var a := TAU * j / 24.0
			gp.append(base + Vector2(cos(a) * h * 0.3, sin(a) * h * 0.03))
		ci.draw_colored_polygon(gp, Color(0.6, 0.22, 0.1, 0.07 * hot))
	for i in 6:
		var y0 := 0.02 + i * 0.07
		ci.draw_line(_P(base, -h, -0.03 + i * 0.004, y0), _P(base, -h, 0.03 - i * 0.004, y0), Color(0.5, 0.22, 0.14, 0.05 * (1.0 - i / 6.0)), 2.0)
	# legs (folded, mantis-like)
	_limb(ci, base, h, [Vector2(-0.04, 0.30), Vector2(-0.17, 0.27), Vector2(-0.13, 0.12), Vector2(-0.14, 0.0)], 5.0, rim)
	_limb(ci, base, h, [Vector2(0.04, 0.30), Vector2(0.19, 0.2), Vector2(0.09, 0.1), Vector2(0.11, 0.0)], 5.0, rim)
	_limb(ci, base, h, [Vector2(0.0, 0.3), Vector2(-0.03, 0.15), Vector2(-0.02, 0.0)], 4.0, rim2)
	# back arms
	_limb(ci, base, h, [Vector2(-0.05, 0.74), Vector2(-0.24, 0.9), Vector2(-0.29, 0.62), Vector2(-0.22, 0.4)], 3.5, rim2)
	_limb(ci, base, h, [Vector2(0.05, 0.74), Vector2(0.26, 0.86), Vector2(0.31, 0.55), Vector2(0.2, 0.36)], 3.5, rim2)
	# torso
	var torso := [Vector2(-0.05, 0.30), Vector2(-0.075, 0.46), Vector2(-0.055, 0.62), Vector2(-0.085, 0.74),
		Vector2(-0.03, 0.80), Vector2(0.04, 0.80), Vector2(0.075, 0.72), Vector2(0.05, 0.58), Vector2(0.07, 0.44), Vector2(0.05, 0.30)]
	_poly(ci, base, h, torso, BODY)
	_poly(ci, base, h, [Vector2(-0.01, 0.30), Vector2(-0.02, 0.5), Vector2(-0.01, 0.78), Vector2(0.04, 0.79), Vector2(0.075, 0.72), Vector2(0.05, 0.58), Vector2(0.07, 0.44), Vector2(0.05, 0.30)], BODY2)
	for i in 8:
		var y := 0.34 + i * 0.05
		var wv := 0.045 + 0.012 * sin(i * 1.3)
		ci.draw_line(_P(base, h, -wv, y), _P(base, h, wv * 0.9, y + 0.012), Color(0, 0, 0, 0.6), 1.5)
		ci.draw_line(_P(base, h, -wv, y + 0.006), _P(base, h, wv * 0.9, y + 0.018), Color(rim.r, rim.g, rim.b, 0.12), 1.0)
	var rl := PackedVector2Array()
	for i in range(5, 10):
		rl.append(_P(base, h, torso[i].x, torso[i].y))
	ci.draw_polyline(rl, rim, 1.5, true)
	var ll := PackedVector2Array()
	for i in range(0, 5):
		ll.append(_P(base, h, torso[i].x, torso[i].y))
	ci.draw_polyline(ll, rim2, 1.0, true)
	ci.draw_polyline(PackedVector2Array([_P(base, h, 0.03, 0.5), _P(base, h, 0.0, 0.44), _P(base, h, 0.012, 0.38), _P(base, h, -0.02, 0.33)]), Color(rim.r, rim.g, rim.b, 0.35 + 0.2 * hot), 1.0, true)
	# second face on chest
	var cf := _P(base, h, 0.005, 0.60)
	ci.draw_circle(cf, h * 0.022, Color(0.01, 0.01, 0.015, 0.9))
	_eye(ci, cf + Vector2(-h * 0.008, -h * 0.004), 1.5, true, t, 0.3, hot)
	_eye(ci, cf + Vector2(h * 0.009, -h * 0.002), 1.3, false, t, 0.0, hot)
	var cm := PackedVector2Array()
	for i in 9:
		var k := i / 8.0
		cm.append(cf + Vector2(lerpf(-h * 0.016, h * 0.016, k), h * 0.011 + sin(k * PI) * h * 0.006))
	ci.draw_polyline(cm, Color(0.6, 0.65, 0.7, 0.35), 1.0, true)
	# front arms (y-up wrist coords; hand dir angles are screen-space radians, y down)
	_limb(ci, base, h, [Vector2(-0.06, 0.74), Vector2(-0.17, 0.86), Vector2(-0.12, 0.66), Vector2(-0.03, 0.62)], 3.8, rim)
	_hand(ci, base, h, Vector2(-0.03, 0.62), -0.2, 6, 0.9, 0.09, t, 1.0, rim)
	_limb(ci, base, h, [Vector2(0.06, 0.73), Vector2(0.2, 0.83), Vector2(0.12, 0.60), Vector2(0.035, 0.54)], 3.8, rim)
	_hand(ci, base, h, Vector2(0.035, 0.54), 2.9, 7, 1.0, 0.1, t, 2.3, rim)
	_limb(ci, base, h, [Vector2(-0.07, 0.68), Vector2(-0.2, 0.7), Vector2(-0.22, 0.5), Vector2(-0.12, 0.45)], 3.2, rim2)
	_hand(ci, base, h, Vector2(-0.12, 0.45), 0.9, 5, 0.8, 0.075, t, 4.1, rim2)
	_limb(ci, base, h, [Vector2(0.07, 0.66), Vector2(0.15, 0.58), Vector2(0.2, 0.45), Vector2(0.15, 0.30)], 3.0, rim2)
	_hand(ci, base, h, Vector2(0.15, 0.30), 1.9, 6, 0.9, 0.08, t, 5.7, rim2)
	_hand(ci, base, h, Vector2(-0.22, 0.4), 1.6, 5, 0.9, 0.08, t, 6.4, rim2)
	_hand(ci, base, h, Vector2(0.2, 0.36), 1.4, 6, 1.0, 0.085, t, 7.2, rim2)
	# neck + tilted head
	_limb(ci, base, h, [Vector2(0.0, 0.79), Vector2(0.02, 0.86), Vector2(0.062, 0.885)], 4.5, rim)
	var hc := Vector2(0.105, 0.968)
	var tilt := -0.5 + sin(t * 0.3) * 0.015
	var hp := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		var lx := cos(a) * 0.046
		var ly := sin(a) * 0.095
		if ly < 0:
			lx *= 0.65
		hp.append(_P(base, h, hc.x + lx * cos(tilt) - ly * sin(tilt), hc.y + lx * sin(tilt) + ly * cos(tilt)))
	ci.draw_colored_polygon(hp, BODY)
	var hl := PackedVector2Array()
	for i in range(0, 11):
		hl.append(hp[(i + 15) % 20])
	ci.draw_polyline(hl, rim, 1.4, true)
	var hx := func(lx: float, ly: float) -> Vector2:
		return _P(base, h, hc.x + lx * cos(tilt) - ly * sin(tilt), hc.y + lx * sin(tilt) + ly * cos(tilt))
	var mw := 0.006 + 0.002 * sin(t * 0.8)
	var mouth := PackedVector2Array([hx.call(0.0, 0.065), hx.call(mw + 0.006, 0.02), hx.call(mw + 0.004, -0.03),
		hx.call(0.0, -0.058), hx.call(-mw - 0.004, -0.03), hx.call(-mw - 0.006, 0.02)])
	ci.draw_colored_polygon(mouth, Color(0.0, 0.0, 0.0, 0.95))
	for i in 11:
		var ly := 0.055 - i * 0.0105
		var ww := (0.006 + 0.0045 * sin(i / 10.0 * PI)) + mw * 0.8
		for s in [-1.0, 1.0]:
			for row in 2:
				var xx: float = s * (ww - row * 0.0028)
				var tp := PackedVector2Array([hx.call(xx, ly), hx.call(xx - s * 0.0034, ly + 0.0036 - row * 0.002), hx.call(xx - s * 0.0034, ly - 0.0036 - row * 0.002)])
				ci.draw_colored_polygon(tp, Color(0.6, 0.66, 0.68, 0.38 + 0.2 * hot))
	var eyes := [[-0.018, 0.04, 1.8, true], [0.02, 0.05, 1.3, false], [-0.026, 0.0, 1.1, true], [0.025, 0.012, 1.6, true],
		[-0.012, -0.03, 0.9, false], [0.022, -0.035, 1.0, true], [0.0, 0.08, 0.8, false], [-0.03, 0.065, 0.8, false]]
	var idx := 0
	for e in eyes:
		_eye(ci, hx.call(e[0], e[1]), e[2], e[3], t, idx * 0.17, hot)
		idx += 1
	ci.draw_line(_P(base, h, 0.045, 0.74), _P(base, h, 0.038, 0.52), Color(0.7, 0.75, 0.85, 0.07), 1.0)
	ci.draw_line(_P(base, h, -0.06, 0.7), _P(base, h, -0.045, 0.6), Color(0.7, 0.75, 0.85, 0.05), 1.0)
