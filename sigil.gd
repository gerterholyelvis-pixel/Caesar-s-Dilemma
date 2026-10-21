extends Node2D

# Engraved luminous rune array. Drawn additively; glow = a few wide faint strokes under crisp cores.

var t := 0.0
var runes: Array = []   # each: Array of PackedVector2Array polylines in unit space (x -1..1, y -1..1)
var radius := 190.0

const CORE := Color(0.82, 0.97, 1.0)
const MID := Color(0.5, 0.78, 1.0)
const GLOW := Color(0.28, 0.55, 1.0)
const GOLD := Color(1.0, 0.86, 0.6)

const NR := 40


func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in NR:
		var lines: Array = []
		# Common stave, every rune shares it so the script reads as one alphabet
		lines.append(PackedVector2Array([Vector2(0, -1), Vector2(0, 1)]))
		var feats := rng.randi_range(2, 3)
		var used := []
		for f in feats:
			var kind := rng.randi_range(0, 6)
			while kind in used:
				kind = rng.randi_range(0, 6)
			used.append(kind)
			var side := 1.0 if rng.randf() > 0.5 else -1.0
			var y := rng.randf_range(-0.7, 0.7)
			match kind:
				0:  # diagonal branch
					lines.append(PackedVector2Array([Vector2(0, y), Vector2(side * 0.8, y - 0.55)]))
				1:  # chevron
					lines.append(PackedVector2Array([Vector2(side * 0.8, y - 0.5), Vector2(0, y), Vector2(side * 0.8, y + 0.5)]))
				2:  # cross tick
					lines.append(PackedVector2Array([Vector2(-0.6, y), Vector2(0.6, y)]))
				3:  # hook from top/bottom
					var ye := -1.0 if rng.randf() > 0.5 else 1.0
					lines.append(PackedVector2Array([Vector2(0, ye), Vector2(side * 0.7, ye * 0.6), Vector2(side * 0.7, ye * 0.1)]))
				4:  # diamond
					lines.append(PackedVector2Array([Vector2(0, y - 0.35), Vector2(0.55, y), Vector2(0, y + 0.35), Vector2(-0.55, y), Vector2(0, y - 0.35)]))
				5:  # zig branch
					lines.append(PackedVector2Array([Vector2(0, y), Vector2(side * 0.6, y), Vector2(side * 0.6, y + 0.5)]))
				6:  # triangle
					lines.append(PackedVector2Array([Vector2(0, y - 0.4), Vector2(side * 0.7, y), Vector2(0, y + 0.4)]))
		runes.append(lines)


func _process(delta: float) -> void:
	t += delta
	if Engine.get_process_frames() % 3 == 0:
		queue_redraw()


func _col(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, clampf(a, 0.0, 1.0))


# Ring with soft under-glow and crisp core
func _ring(r: float, w: float, a: float, glow := true) -> void:
	if glow:
		draw_arc(Vector2.ZERO, r, 0, TAU, 96, _col(GLOW, 0.07 * a), w + 7.0, true)
		draw_arc(Vector2.ZERO, r, 0, TAU, 96, _col(MID, 0.12 * a), w + 3.0, true)
	draw_arc(Vector2.ZERO, r, 0, TAU, 96, _col(CORE, 0.8 * a), w, true)


func _seg_glow(p: Vector2, q: Vector2, w: float, a: float) -> void:
	draw_line(p, q, _col(GLOW, 0.1 * a), w + 4.0, true)
	draw_line(p, q, _col(CORE, 0.78 * a), w, true)


func _poly_glow(pts: PackedVector2Array, w: float, a: float) -> void:
	draw_polyline(pts, _col(GLOW, 0.1 * a), w + 4.0, true)
	draw_polyline(pts, _col(CORE, 0.78 * a), w, true)


# Gem / node: halo, faceted diamond, bright centre
func _gem(p: Vector2, s: float, a: float, c := CORE) -> void:
	draw_circle(p, s * 2.6, _col(GLOW, 0.10 * a))
	draw_circle(p, s * 1.7, _col(MID, 0.14 * a))
	var d := PackedVector2Array([p + Vector2(0, -s * 1.3), p + Vector2(s, 0), p + Vector2(0, s * 1.3), p + Vector2(-s, 0)])
	draw_colored_polygon(d, _col(c, 0.55 * a))
	draw_polyline(PackedVector2Array([d[0], d[1], d[2], d[3], d[0]]), _col(CORE, 0.9 * a), 1.0, true)
	draw_circle(p, s * 0.4, _col(Color.WHITE, 0.85 * a))


# Travelling pulse arc along a ring
func _pulse(r: float, speed: float, phase: float, w: float, a: float, span := 0.9) -> void:
	var a0 := t * speed + phase
	draw_arc(Vector2.ZERO, r, a0 - span, a0, 32, _col(GLOW, 0.12 * a), w + 6.0, true)
	for i in 4:
		var f := float(i + 1) / 4.0
		draw_arc(Vector2.ZERO, r, a0 - span * f, a0, 24, _col(CORE, 0.22 * a), w + 0.6, true)
	draw_circle(Vector2.from_angle(a0) * r, w * 1.8, _col(Color.WHITE, 0.55 * a))


func _star(n: int, k: int, r: float, rot: float, w: float, a: float) -> void:
	for i in n:
		var p := Vector2.from_angle(rot + i * TAU / n) * r
		var q := Vector2.from_angle(rot + (i + k) * TAU / n) * r
		_seg_glow(p, q, w, a)


func _draw() -> void:
	var r := radius
	var pulse := 0.88 + 0.12 * sin(t * 1.6)
	var c := Vector2.ZERO

	# Soft aura (depth: brightest toward the rune band)
	for i in 8:
		draw_circle(c, r * (1.55 - i * 0.12), _col(GLOW, 0.007 * pulse))
	draw_arc(c, r * 0.94, 0, TAU, 96, _col(GLOW, 0.035), r * 0.22, true)

	# --- outer bezel: double stroke + beads + fine ticks --------------------------
	_ring(r * 1.07, 1.0, 0.55)
	_ring(r * 1.03, 2.2, 0.95 * pulse)
	_ring(r * 0.995, 0.8, 0.6, false)
	for i in 60:
		var a := i * TAU / 60.0 + t * 0.02
		var l := 7.0 if i % 5 == 0 else 3.0
		var u := Vector2.from_angle(a)
		draw_line(u * r * 1.07, u * (r * 1.07 + l), _col(CORE, 0.45 if l > 2.5 else 0.3), 1.0 if l < 5 else 1.5, true)
	for i in 20:
		var a := -i * TAU / 20.0 + t * 0.045
		var p := Vector2.from_angle(a) * r * 1.07
		draw_circle(p, 3.2, _col(GLOW, 0.18))
		draw_circle(p, 1.5, _col(CORE, 0.9))

	# --- inscription band (runes between rings) ----------------------------------
	var rb := r * 0.885
	_ring(r * 0.96, 1.4, 0.85)
	_ring(r * 0.81, 1.8, 0.9 * pulse)
	_ring(r * 0.78, 0.8, 0.55, false)
	var bandw := r * 0.12
	for i in NR:
		var ang := t * 0.07 + i * TAU / NR
		var u := Vector2.from_angle(ang)
		var tg := Vector2(-u.y, u.x)
		var flick := 0.72 + 0.28 * sin(t * 1.3 + i * 2.1)
		# a travelling wave brightens runes in turn
		var wave := pow(maxf(0.0, cos(ang - t * 0.9)), 6.0)
		var al := flick * 0.85 + wave * 0.5
		var ctr := u * rb
		var gh := bandw * 0.40
		var gw := TAU * rb / NR * 0.26
		for ln in runes[i]:
			var pts := PackedVector2Array()
			for v in ln:
				pts.append(ctr + tg * v.x * gw + u * v.y * gh)
			draw_polyline(pts, _col(GLOW, 0.11 * al), 3.6, true)
			draw_polyline(pts, _col(CORE, 0.8 * al), 1.1, true)
		# cell dividers
		var da := ang + PI / NR
		var du := Vector2.from_angle(da)
		draw_line(du * (rb - bandw * 0.45), du * (rb + bandw * 0.45), _col(MID, 0.35), 0.8, true)

	# --- filigree scallops between band and lattice ---------------------------
	_ring(r * 0.745, 1.0, 0.65)
	var ns := 24
	for i in ns:
		var a := i * TAU / ns - t * 0.05
		var a2 := a + TAU / ns
		var cp := Vector2.from_angle((a + a2) * 0.5)
		# scallop: arc bulging inward, centre on the ring
		var sc := cp * r * 0.745
		var sr := r * 0.745 * sin(TAU / ns * 0.5)
		var am := (a + a2) * 0.5
		draw_arc(sc, sr, am + PI * 0.5 + 0.0, am + PI * 1.5, 14, _col(CORE, 0.55), 1.0, true)
		draw_circle(Vector2.from_angle(a) * r * 0.745, 1.6, _col(CORE, 0.8))
		draw_circle(sc - cp * sr * 0.55, 1.2, _col(MID, 0.7))

	# --- dashed segmented ring ----------------------------------------------------
	var rs := r * 0.665
	for i in 36:
		var a := t * 0.12 + i * TAU / 36
		var span := TAU / 36 * (0.62 if i % 3 else 0.35)
		draw_arc(c, rs, a, a + span, 6, _col(CORE, 0.8), 2.6 if i % 3 == 0 else 1.6, true)
	draw_arc(c, rs, 0, TAU, 96, _col(GLOW, 0.06), 9.0, true)
	_ring(rs - 7.0, 0.8, 0.5, false)

	# --- layered counter-rotating lattices ---------------------------------------
	# {12/5} faint web
	_star(12, 5, r * 0.60, -t * 0.045, 0.7, 0.38)
	# two hexagrams counter-rotating
	var rh := r * 0.585
	_star(6, 2, rh, t * 0.11, 1.5, 0.95)
	_star(6, 2, rh, -t * 0.11 + PI / 6, 1.0, 0.65)
	# square pair (octagram) in a ring
	_ring(r * 0.43, 1.6, 0.9)
	_ring(r * 0.40, 0.7, 0.5, false)
	var sq := PackedVector2Array()
	for k in 2:
		sq.clear()
		for i in 5:
			sq.append(Vector2.from_angle(-t * 0.16 + k * PI / 4 + i * TAU / 4) * r * 0.43)
		_poly_glow(sq, 1.2, 0.8)
	# inner triangle pair, other direction
	var tri := PackedVector2Array()
	for k in 2:
		tri.clear()
		for i in 4:
			tri.append(Vector2.from_angle(t * 0.3 + k * PI + i * TAU / 3) * r * 0.31)
		_poly_glow(tri, 1.2, 0.85)

	# small symbol ring: circles / bars between inner rings
	for i in 16:
		var a := -t * 0.2 + i * TAU / 16
		var u := Vector2.from_angle(a)
		var tg := Vector2(-u.y, u.x)
		var p := u * r * 0.365
		match i % 4:
			0: draw_arc(p, 3.2, 0, TAU, 12, _col(CORE, 0.85), 1.0, true)
			1: draw_line(p - u * 3.5, p + u * 3.5, _col(CORE, 0.85), 1.1, true)
			2: _poly_glow(PackedVector2Array([p + u * 3.5, p + tg * 3.0 - u * 2.5, p - tg * 3.0 - u * 2.5, p + u * 3.5]), 0.9, 0.9)
			3: draw_circle(p, 1.4, _col(CORE, 0.95))

	# --- hex vertex gems + inner nodes -------------------------------------------
	for i in 6:
		var a := t * 0.11 + i * TAU / 6
		_gem(Vector2.from_angle(a) * rh, 3.4, 0.95 * (0.85 + 0.15 * sin(t * 2.0 + i)))
	for i in 4:
		_gem(Vector2.from_angle(-t * 0.16 + i * TAU / 4) * r * 0.43, 2.4, 0.85, GOLD)

	# --- central eye: petals, rings, core ---------------------------------------
	var er := r * 0.2
	for i in 8:
		var a := t * 0.4 + i * TAU / 8
		var u := Vector2.from_angle(a)
		var tg := Vector2(-u.y, u.x)
		var pts := PackedVector2Array()
		for k in 11:
			var f := k / 10.0
			var wdt := sin(f * PI) * er * 0.28
			pts.append(u * (er * 0.25 + f * er * 1.0) + tg * wdt)
		for k in 11:
			var f := 1.0 - k / 10.0
			var wdt := sin(f * PI) * er * 0.28
			pts.append(u * (er * 0.25 + f * er * 1.0) - tg * wdt)
		pts.append(pts[0])
		draw_polyline(pts, _col(CORE, 0.6), 1.0, true)
	_ring(er * 1.3, 1.4, 0.9 * pulse)
	_ring(er * 0.62, 1.2, 0.8)
	for i in 6:
		draw_circle(c, er * (0.6 - i * 0.08), _col(GLOW, 0.05))
	draw_circle(c, er * 0.30 * (0.9 + 0.1 * pulse), _col(MID, 0.5))
	draw_circle(c, er * 0.17, _col(Color.WHITE, 0.9))
	for i in 3:
		var a := -t * 0.5 + i * TAU / 3
		_seg_glow(Vector2.from_angle(a) * er * 0.65, Vector2.from_angle(a) * er * 1.3, 1.0, 0.7)

	# --- energy pulses travelling the rings --------------------------------------
	_pulse(r * 1.03, 0.9, 0.0, 2.2, pulse)
	_pulse(r * 0.81, -1.3, 2.0, 1.8, pulse, 0.7)
	_pulse(r * 0.43, 1.7, 4.0, 1.6, pulse, 0.8)
	_pulse(rs, -0.8, 1.0, 1.6, pulse, 0.6)
