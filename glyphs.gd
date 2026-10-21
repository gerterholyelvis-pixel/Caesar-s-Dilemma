extends RefCounted

# A small alphabet of Egyptian-looking pictograms, drawn as vector strokes (no font, no images).
# Used to write text that looks like language but reads as nothing.
# Glyph coordinates live in a unit box (-1..1); `draw` scales them to `sz` pixels.

const COUNT := 14


static func _pl(ci: CanvasItem, pts: Array, c: Vector2, h: float, col: Color, w: float) -> void:
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + (p as Vector2) * h)
	ci.draw_polyline(out, col, w, true)


static func _ellipse(rx: float, ry: float, cx := 0.0, cy := 0.0, n := 22, closed := true) -> Array:
	var pts: Array = []
	for i in n + (1 if closed else 0):
		var a := TAU * i / n
		pts.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	return pts


static func draw(ci: CanvasItem, id: int, c: Vector2, sz: float, col: Color, w := 2.0) -> void:
	var h := sz * 0.5
	match id % COUNT:
		0:  # the eye
			var up: Array = []
			var lo: Array = []
			for i in 15:
				var x := -1.0 + 2.0 * i / 14.0
				up.append(Vector2(x * 0.95, -0.5 * (1.0 - x * x) * 0.9))
				lo.append(Vector2(x * 0.95, 0.32 * (1.0 - x * x)))
			_pl(ci, up, c, h, col, w)
			_pl(ci, lo, c, h, col, w)
			_pl(ci, _ellipse(0.26, 0.26, 0.05, -0.04), c, h, col, w)
			ci.draw_circle(c + Vector2(0.05, -0.04) * h, h * 0.1, col)
			_pl(ci, [Vector2(0.15, 0.42), Vector2(0.15, 0.92), Vector2(0.55, 0.92)], c, h, col, w)
			_pl(ci, [Vector2(-0.5, 0.3), Vector2(-0.72, 0.78)], c, h, col, w)
		1:  # ankh
			_pl(ci, _ellipse(0.32, 0.4, 0.0, -0.5), c, h, col, w)
			_pl(ci, [Vector2(0, -0.1), Vector2(0, 0.95)], c, h, col, w)
			_pl(ci, [Vector2(-0.55, 0.15), Vector2(0.55, 0.15)], c, h, col, w)
		2:  # sun disc with a rising horn
			_pl(ci, _ellipse(0.42, 0.42, 0.0, -0.05), c, h, col, w)
			ci.draw_circle(c + Vector2(0, -0.05) * h, h * 0.13, col)
			_pl(ci, [Vector2(-0.85, -0.45), Vector2(-0.6, -0.85), Vector2(-0.35, -0.7)], c, h, col, w)
			_pl(ci, [Vector2(0.85, -0.45), Vector2(0.6, -0.85), Vector2(0.35, -0.7)], c, h, col, w)
			_pl(ci, [Vector2(-0.85, 0.7), Vector2(0.85, 0.7)], c, h, col, w)
		3:  # water
			for k in 3:
				var y := -0.55 + k * 0.55
				var pts: Array = []
				for i in 7:
					pts.append(Vector2(-0.9 + i * 0.3, y + (0.15 if i % 2 == 0 else -0.15)))
				_pl(ci, pts, c, h, col, w)
		4:  # owl
			_pl(ci, _ellipse(0.46, 0.62, 0.0, 0.1), c, h, col, w)
			_pl(ci, _ellipse(0.14, 0.14, -0.2, -0.15, 12), c, h, col, w)
			_pl(ci, _ellipse(0.14, 0.14, 0.2, -0.15, 12), c, h, col, w)
			_pl(ci, [Vector2(-0.07, 0.0), Vector2(0, 0.16), Vector2(0.07, 0.0)], c, h, col, w)
			_pl(ci, [Vector2(-0.2, 0.7), Vector2(-0.2, 0.95)], c, h, col, w)
			_pl(ci, [Vector2(0.2, 0.7), Vector2(0.2, 0.95)], c, h, col, w)
		5:  # serpent
			var pts: Array = []
			for i in 20:
				var x := -0.9 + i * 0.09
				pts.append(Vector2(x, 0.3 * sin(x * 5.5) + 0.2))
			_pl(ci, pts, c, h, col, w)
			var hd: Vector2 = pts[pts.size() - 1]
			ci.draw_circle(c + (hd + Vector2(0.05, -0.05)) * h, h * 0.13, col)
			_pl(ci, [hd + Vector2(0.15, -0.02), hd + Vector2(0.3, -0.1), hd + Vector2(0.3, 0.06)], c, h, col, w * 0.7)
		6:  # feather
			var edge_l: Array = []
			var edge_r: Array = []
			for i in 13:
				var u := i / 12.0
				var y := 0.95 - 1.9 * u
				var half := 0.3 * sin(u * PI) * (1.0 - 0.2 * u)
				edge_l.append(Vector2(-half, y))
				edge_r.append(Vector2(half, y))
			_pl(ci, edge_l, c, h, col, w)
			_pl(ci, edge_r, c, h, col, w)
			_pl(ci, [Vector2(0, 1.0), Vector2(0, -0.95)], c, h, col, w)
			for k in 4:
				var y := 0.5 - k * 0.3
				_pl(ci, [Vector2(0, y), Vector2(-0.25, y - 0.2)], c, h, col, w * 0.6)
				_pl(ci, [Vector2(0, y), Vector2(0.25, y - 0.2)], c, h, col, w * 0.6)
		7:  # reed
			_pl(ci, [Vector2(0, 0.95), Vector2(0, -0.2)], c, h, col, w)
			_pl(ci, [Vector2(0, 0.45), Vector2(-0.45, 0.1), Vector2(-0.55, -0.4)], c, h, col, w)
			_pl(ci, [Vector2(0, 0.45), Vector2(0.45, 0.1), Vector2(0.55, -0.4)], c, h, col, w)
			_pl(ci, _ellipse(0.12, 0.16, 0.0, -0.4, 12), c, h, col, w)
		8:  # arm and hand
			_pl(ci, [Vector2(-0.95, 0.5), Vector2(-0.05, 0.5)], c, h, col, w * 1.6)
			_pl(ci, [Vector2(-0.05, 0.4), Vector2(0.25, 0.4), Vector2(0.25, 0.7), Vector2(-0.05, 0.7)], c, h, col, w)
			_pl(ci, [Vector2(0.25, 0.45), Vector2(0.8, 0.1)], c, h, col, w)
			_pl(ci, [Vector2(0.25, 0.55), Vector2(0.9, 0.55)], c, h, col, w)
			_pl(ci, [Vector2(0.25, 0.65), Vector2(0.8, 0.95)], c, h, col, w)
		9:  # pyramid and star
			_pl(ci, [Vector2(-0.85, 0.75), Vector2(0, -0.45), Vector2(0.85, 0.75), Vector2(-0.85, 0.75)], c, h, col, w)
			_pl(ci, [Vector2(0, -0.45), Vector2(0, 0.75)], c, h, col, w * 0.7)
			ci.draw_circle(c + Vector2(0, -0.8) * h, h * 0.1, col)
		10:  # scarab
			_pl(ci, _ellipse(0.34, 0.44, 0.0, 0.15), c, h, col, w)
			_pl(ci, _ellipse(0.15, 0.15, 0.0, -0.42, 12), c, h, col, w)
			_pl(ci, [Vector2(-0.3, -0.05), Vector2(-0.8, -0.3), Vector2(-0.92, 0.15)], c, h, col, w)
			_pl(ci, [Vector2(0.3, -0.05), Vector2(0.8, -0.3), Vector2(0.92, 0.15)], c, h, col, w)
			_pl(ci, [Vector2(-0.3, 0.3), Vector2(-0.6, 0.6)], c, h, col, w * 0.8)
			_pl(ci, [Vector2(0.3, 0.3), Vector2(0.6, 0.6)], c, h, col, w * 0.8)
			_pl(ci, [Vector2(0, -0.28), Vector2(0, 0.58)], c, h, col, w * 0.6)
		11:  # scepter
			_pl(ci, [Vector2(0, 0.95), Vector2(0, -0.6)], c, h, col, w)
			_pl(ci, [Vector2(0, -0.6), Vector2(0.18, -0.85), Vector2(0.45, -0.7)], c, h, col, w)
			_pl(ci, [Vector2(0, 0.95), Vector2(-0.22, 0.75)], c, h, col, w)
			_pl(ci, [Vector2(0, 0.95), Vector2(0.22, 0.75)], c, h, col, w)
		12:  # mouth
			_pl(ci, _ellipse(0.62, 0.28, 0.0, 0.0), c, h, col, w)
			_pl(ci, [Vector2(-0.62, 0.0), Vector2(0.62, 0.0)], c, h, col, w * 0.8)
			_pl(ci, [Vector2(-0.3, -0.5), Vector2(-0.3, -0.85)], c, h, col, w)
			_pl(ci, [Vector2(0.3, -0.5), Vector2(0.3, -0.85)], c, h, col, w)
		13:  # basket
			var bowl: Array = []
			for i in 15:
				var x := -0.85 + 1.7 * i / 14.0
				bowl.append(Vector2(x, 0.05 + 0.65 * sqrt(maxf(1.0 - (x / 0.85) * (x / 0.85), 0.0))))
			_pl(ci, bowl, c, h, col, w)
			_pl(ci, [Vector2(-0.85, 0.05), Vector2(0.85, 0.05)], c, h, col, w)
			_pl(ci, [Vector2(-0.5, 0.05), Vector2(-0.35, -0.55), Vector2(0, -0.8), Vector2(0.35, -0.55), Vector2(0.5, 0.05)], c, h, col, w)
