extends Node2D

# LAYER: angel. A distant "biblically accurate" angel (ophanim-style): nested gyroscopic rings
# covered in blinking eyes, a central eye, a halo, radiant rays and three pairs of layered,
# feathered wings. Local origin = angel center; about 150 px across at scale 1. Additive, gold-white.

var t := 0.0
var spread := 1.0   # wing length multiplier (animated during the ascent)
var lod := 1.0      # <1 draws fewer feathers (cheaper)
var redraw_every := 3   # redraw on every Nth frame (staggered with the other layers)
var redraw_phase := 1
var rings: Array = []
var blink := PackedFloat32Array()

const GOLD := Color(1.0, 0.82, 0.45)
const PALE := Color(1.0, 0.96, 0.86)
const ICE := Color(0.75, 0.88, 1.0)


func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m
	rings = [
		{"r": 27.0, "sq": 0.30, "sp": 0.55, "n": 8, "ph": 0.0},
		{"r": 22.0, "sq": 0.95, "sp": -0.80, "n": 7, "ph": 1.0},
		{"r": 34.0, "sq": 0.55, "sp": 0.35, "n": 11, "ph": 2.1},
		{"r": 40.0, "sq": 0.85, "sp": -0.25, "n": 13, "ph": 3.3},
	]
	for i in 60:
		blink.append(randf() * 10.0)


func _process(delta: float) -> void:
	t += delta
	if Engine.get_process_frames() % redraw_every == redraw_phase % redraw_every:
		queue_redraw()


# One feather: tapered, soft-edged blade from base toward `dir`, with a bright shaft and outline.
func _feather(base: Vector2, dir: float, length: float, width: float, col: Color, curl: float) -> void:
	var d := Vector2.from_angle(dir)
	var n := Vector2(-d.y, d.x)
	var mid := base + d * length * 0.5 + n * curl * length * 0.08
	var tip := base + d * length + n * curl * length * 0.2
	var l1 := base + d * length * 0.62 + n * (width * 0.55 + curl * length * 0.12)
	var l2 := base + d * length * 0.62 - n * (width * 0.55 - curl * length * 0.12)
	var pts := PackedVector2Array([base + n * width * 0.4, l1, tip, l2, base - n * width * 0.4])
	var cols := PackedColorArray([
		Color(col, col.a * 0.12), Color(col, col.a), Color(col, col.a * 0.05), Color(col, col.a), Color(col, col.a * 0.12)])
	draw_polygon(pts, cols)
	if lod >= 1.0:
		draw_polyline(PackedVector2Array([base + n * width * 0.4, l1, tip, l2, base - n * width * 0.4]), Color(col, col.a * 1.2), 0.6, true)
	draw_line(base, mid, Color(PALE, col.a * 0.9), 0.7, true)
	draw_line(mid, tip, Color(PALE, col.a * 0.8), 0.6, true)


func _wing_set() -> void:
	# three wing pairs (upper raised, middle spread, lower sweeping). Each wing = 3 feather rows.
	var pairs := [
		{"a": -1.20, "len": 78.0, "fan": 1.00, "flap": 0.08, "ph": 0.0},
		{"a": -0.38, "len": 92.0, "fan": 0.90, "flap": 0.06, "ph": 0.9},
		{"a": 0.72, "len": 66.0, "fan": 0.80, "flap": 0.10, "ph": 1.8},
	]
	var rows := [
		{"n": 11, "scale": 1.00, "w": 9.0, "alpha": 0.20, "tint": 0},
		{"n": 10, "scale": 0.66, "w": 7.5, "alpha": 0.16, "tint": 1},
		{"n": 8, "scale": 0.36, "w": 6.0, "alpha": 0.12, "tint": 1},
	]
	for side in [1.0, -1.0]:
		for p in pairs:
			var flap: float = sin(t * 0.8 + float(p.ph)) * float(p.flap)
			for row in rows:
				var cnt: int = maxi(3, int(round(float(row.n) * lod)))
				for i in cnt:
					var u := float(i) / float(cnt - 1)
					var ang: float = float(p.a) + (u - 0.5) * float(p.fan) + flap * (0.6 + 0.4 * float(row.scale))
					var a2: float = ang if side > 0.0 else PI - ang
					var contour := 0.55 + 0.45 * sin(u * PI * 0.92 + 0.15)
					var len: float = float(p.len) * float(row.scale) * contour * spread
					var base := Vector2(side * 8.0, -3.0 + (u - 0.5) * 7.0)
					var col: Color = GOLD if int(row.tint) == 0 else PALE.lerp(ICE, 0.25)
					col.a = float(row.alpha)
					_feather(base, a2, len, float(row.w), col, (u - 0.5) * 0.5 * side)


func _eye(p: Vector2, s: float, open: float, col: Color) -> void:
	var h := s * 0.58 * open
	if h < 0.4:
		draw_line(p + Vector2(-s, 0), p + Vector2(s, 0), Color(col, 0.6), 0.9, true)
		return
	var pts := PackedVector2Array()
	for i in 13:
		var x := lerpf(-s, s, i / 12.0)
		pts.append(p + Vector2(x, -h * (1.0 - (x / s) * (x / s))))
	for i in 13:
		var x := lerpf(s, -s, i / 12.0)
		pts.append(p + Vector2(x, h * (1.0 - (x / s) * (x / s))))
	pts.append(pts[0])
	draw_polyline(pts, Color(col, 0.95), 1.0, true)
	draw_circle(p, h * 0.66, Color(1.0, 0.72, 0.28, 0.6))
	draw_circle(p, h * 0.34, Color(0.25, 0.12, 0.02, 0.9))
	draw_circle(p + Vector2(-h * 0.14, -h * 0.14), h * 0.14, Color(1.0, 0.95, 0.85, 1.0))


func _draw() -> void:
	var pulse := 0.85 + 0.15 * sin(t * 1.3)

	# soft celestial aura
	for i in 10:
		draw_circle(Vector2.ZERO, 105.0 - i * 9.5, Color(1.0, 0.78, 0.42, 0.0035 * pulse))

	# radiant rays behind the figure
	for i in 14:
		var a := t * 0.04 + i * TAU / 14.0
		var len := 120.0 + 25.0 * sin(t * 0.6 + i * 1.9)
		var d := Vector2.from_angle(a)
		var n := Vector2(-d.y, d.x)
		var pts := PackedVector2Array([d * 18.0 + n * 2.2, d * len, d * 18.0 - n * 2.2])
		var cols := PackedColorArray([Color(GOLD, 0.045 * pulse), Color(GOLD, 0.0), Color(GOLD, 0.045 * pulse)])
		draw_polygon(pts, cols)

	_wing_set()

	# halo above the center
	var hc := Vector2(0, -50)
	draw_arc(hc, 19.0, 0, TAU, 48, Color(GOLD, 0.22), 5.0, true)
	draw_arc(hc, 19.0, 0, TAU, 48, Color(PALE, 0.9 * pulse), 1.5, true)
	draw_arc(hc, 14.5, 0, TAU, 48, Color(GOLD, 0.5), 0.8, true)

	# gyroscopic rings with eyes
	var k := 0
	for r in rings:
		var rot: float = t * float(r.sp) + float(r.ph)
		var sq: float = r.sq
		var rad: float = r.r
		var tilt: float = 0.55 * sin(t * 0.3 + float(r.ph)) + float(r.ph)
		var pts := PackedVector2Array()
		for i in 73:
			var a := TAU * i / 72.0
			pts.append(Vector2(cos(a) * rad, sin(a) * rad * sq).rotated(tilt))
		draw_polyline(pts, Color(GOLD, 0.10), 3.5, true)
		draw_polyline(pts, Color(PALE, 0.85 * pulse), 1.3, true)
		var n: int = r.n
		for i in n:
			var a := rot + TAU * i / n
			var ep := Vector2(cos(a) * rad, sin(a) * rad * sq).rotated(tilt)
			var depth := 0.6 + 0.4 * sin(a)
			var bl := blink[(k + i) % blink.size()]
			var open := 1.0 - clampf((sin(t * 0.7 + bl) - 0.92) / 0.08, 0.0, 1.0)
			_eye(ep, 4.6 * depth, open, Color(GOLD, depth))
		k += n

	# central eye with its own glow
	for i in 6:
		draw_circle(Vector2.ZERO, 13.0 - i * 2.0, Color(1.0, 0.85, 0.5, 0.025 * pulse))
	_eye(Vector2.ZERO, 10.0, 1.0 - clampf((sin(t * 0.5 + 2.0) - 0.96) * 25.0, 0.0, 1.0), PALE)
