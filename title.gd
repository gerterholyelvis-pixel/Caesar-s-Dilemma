extends Control

# Game title "Caesar's Dilemma" in an invented alien stroke font (vector polylines, no fonts/images).
# play()     pops the letters in (staggered overshoot + strokes drawing on + soft flash), readable by ~0.5 s
# fade_out() fades everything in ~0.45 s. Designed in a 960x640 space and scaled with the control.

const DW := 960.0
const DH := 640.0
const SY := 2.35
const UNIT := 37.0          # design px per glyph width unit
const GAP := 0.2
const POP_STAGGER := 0.024
const POP_TIME := 0.2
const FADE_TIME := 0.45

# y: 0 = cap top, 0.4 = x-height, 1 = baseline.  Each stroke = flat array of x,y pairs.
const G := {
	"C": {"w": 1.0, "s": [
		[0.95, 0.10, 0.6, 0.0, 0.18, 0.14, 0.02, 0.5, 0.18, 0.86, 0.6, 1.0, 0.95, 0.9],
		[0.95, 0.10, 0.82, 0.32],
		[0.5, 0.5, 0.6, 0.5]], "n": [[0.95, 0.10], [0.95, 0.9]], "r": [[0.5, 0.5, 0.07]]},
	"a": {"w": 0.95, "s": [
		[0.12, 0.52, 0.4, 0.4, 0.75, 0.44, 0.86, 0.6, 0.86, 0.94, 1.0, 1.0],
		[0.86, 0.68, 0.4, 0.66, 0.1, 0.82, 0.3, 1.0, 0.86, 0.94]], "n": [[0.12, 0.52], [1.0, 1.0]], "r": []},
	"e": {"w": 0.95, "s": [
		[0.1, 0.7, 0.86, 0.7, 0.8, 0.5, 0.5, 0.4, 0.15, 0.55, 0.05, 0.84, 0.35, 1.0, 0.88, 0.92],
		[0.35, 0.7, 0.4, 0.88]], "n": [[0.88, 0.92], [0.1, 0.7]], "r": []},
	"s": {"w": 0.88, "s": [
		[0.85, 0.5, 0.55, 0.4, 0.2, 0.5, 0.2, 0.68, 0.72, 0.78, 0.8, 0.92, 0.5, 1.0, 0.1, 0.9],
		[0.5, 0.4, 0.5, 0.26]], "n": [[0.85, 0.5], [0.1, 0.9], [0.5, 0.26]], "r": []},
	"r": {"w": 0.8, "s": [
		[0.1, 0.4, 0.1, 1.0],
		[0.1, 0.62, 0.35, 0.42, 0.7, 0.42, 0.82, 0.58]], "n": [[0.1, 1.0], [0.82, 0.58]], "r": []},
	"'": {"w": 0.3, "s": [
		[0.2, 0.0, 0.05, 0.34]], "n": [[0.2, 0.0], [0.05, 0.34]], "r": []},
	"D": {"w": 1.05, "s": [
		[0.1, -0.08, 0.1, 1.08],
		[0.1, 0.0, 0.6, 0.0, 1.0, 0.3, 1.0, 0.7, 0.6, 1.0, 0.1, 1.0],
		[0.38, 0.28, 0.66, 0.5, 0.38, 0.72]], "n": [[0.1, -0.08], [0.1, 1.08], [0.38, 0.28], [0.38, 0.72]], "r": []},
	"i": {"w": 0.3, "s": [
		[0.12, 0.4, 0.12, 1.0]], "n": [[0.12, 1.0]], "r": [[0.12, 0.14, 0.08]]},
	"l": {"w": 0.42, "s": [
		[0.12, 0.0, 0.12, 0.88, 0.34, 1.0]], "n": [[0.12, 0.0], [0.34, 1.0]], "r": []},
	"m": {"w": 1.25, "s": [
		[0.1, 1.0, 0.1, 0.4],
		[0.1, 0.56, 0.3, 0.4, 0.6, 0.56, 0.6, 1.0],
		[0.6, 0.56, 0.82, 0.4, 1.1, 0.56, 1.1, 1.0]], "n": [[0.1, 1.0], [0.6, 1.0], [1.1, 1.0], [0.1, 0.4]], "r": []},
}

var letters: Array = []         # {strokes: Array[PackedVector2Array], lens, nodes, rings, c (pivot), x0, x1, delay}
var flourish: Array = []        # {pts: PackedVector2Array, w: float, d: float (reveal order 0..1)}
var total_w := 1.0
var t := -1.0                   # time since play(); -1 = idle
var fade := -1.0                # time since fade_out()
var gold := Color(1.0, 0.8, 0.36)
var ice := Color(0.7, 0.98, 1.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func play() -> void:
	t = 0.0
	fade = -1.0
	modulate.a = 1.0
	visible = true
	set_process(true)
	queue_redraw()


func fade_out() -> void:
	if fade < 0.0:
		fade = 0.0


func _process(d: float) -> void:
	if t < 0.0:
		return
	t += d
	if fade < 0.0 and t >= 2.65:   # safety: never lingers past ~3 s even if nobody calls fade_out()
		fade = 0.0
	if fade >= 0.0:
		fade += d
		modulate.a = clampf(1.0 - fade / FADE_TIME, 0.0, 1.0)
		if fade >= FADE_TIME:
			t = -1.0
			visible = false
			set_process(false)
			return
	queue_redraw()


# ---------------------------------------------------------------- build
func _build() -> void:
	var text := "Caesar's Dilemma"
	var x := 0.0
	var idx := 0
	for ch in text:
		if ch == " ":
			x += 0.55
			continue
		var g: Dictionary = G[ch]
		var L := {"strokes": [], "lens": [], "nodes": [], "rings": [], "x0": x, "x1": x + g.w, "delay": idx * POP_STAGGER}
		for s in g.s:
			var pa := PackedVector2Array()
			for i in range(0, s.size(), 2):
				pa.append(Vector2((x + s[i]) * UNIT, s[i + 1] * UNIT * SY))
			L.strokes.append(pa)
			L.lens.append(_len(pa))
		for n in g.n:
			L.nodes.append(Vector2((x + n[0]) * UNIT, n[1] * UNIT * SY))
		for r in g.r:
			L.rings.append([Vector2((x + r[0]) * UNIT, r[1] * UNIT * SY), r[2] * UNIT])
		L.c = Vector2((x + g.w * 0.5) * UNIT, 0.55 * UNIT * SY)
		letters.append(L)
		x += g.w + GAP
		idx += 1
	total_w = (x - GAP) * UNIT
	# recentre around x = 0
	for L in letters:
		var o := Vector2(total_w * 0.5, 0.0)
		L.c -= o
		for s in L.strokes:
			for i in s.size():
				s[i] -= o
		for i in L.nodes.size():
			L.nodes[i] -= o
		for r in L.rings:
			r[0] -= o
	_build_flourish()


func _len(pa: PackedVector2Array) -> float:
	var s := 0.0
	for i in range(1, pa.size()):
		s += pa[i].distance_to(pa[i - 1])
	return s


# Self-similar underline: a spine, a recursive hanging branch tree in the centre, and a spiral at each end that
# sprouts a smaller spiral at its tip, which sprouts a smaller one still.
func _build_flourish() -> void:
	var y0 := UNIT * SY * 1.0 + 20.0
	var hw := total_w * 0.5
	flourish.append({"pts": PackedVector2Array([Vector2(-hw * 0.78, y0), Vector2(-24, y0)]), "w": 2.4, "d": 0.0})
	flourish.append({"pts": PackedVector2Array([Vector2(24, y0), Vector2(hw * 0.78, y0)]), "w": 2.4, "d": 0.0})
	_branch(Vector2(0, y0 - 6.0), Vector2(0, 1), 34.0, 4, 0.1)
	_spiral(Vector2(-hw * 0.78, y0), -1.0, 27.0, 3, 0.15)
	_spiral(Vector2(hw * 0.78, y0), 1.0, 27.0, 3, 0.15)


func _branch(p: Vector2, dir: Vector2, l: float, depth: int, d: float) -> void:
	var q := p + dir * l
	flourish.append({"pts": PackedVector2Array([p, q]), "w": 0.8 + depth * 0.45, "d": d})
	if depth <= 0:
		flourish.append({"pts": PackedVector2Array(), "node": q, "d": d})
		return
	_branch(q, dir.rotated(0.62), l * 0.66, depth - 1, d + 0.12)
	_branch(q, dir.rotated(-0.62), l * 0.66, depth - 1, d + 0.12)
	if depth == 4:
		_branch(q, dir, l * 0.5, depth - 2, d + 0.12)


func _spiral(c: Vector2, side: float, r0: float, depth: int, d: float) -> void:
	# starts at c heading toward the centre of the title, curling downward and in
	var pts := PackedVector2Array()
	var steps := 18
	for i in range(steps + 1):
		var u := float(i) / steps
		var a := u * 1.55 * TAU
		var r := r0 * (1.0 - u * 0.9)
		# centre of spiral sits r0 below-outside the start
		var ctr := c + Vector2(side * 0.0, r0)
		pts.append(ctr + Vector2(-side * sin(a) * r, -cos(a) * r))
	flourish.append({"pts": pts, "w": 1.0 + depth * 0.5, "d": d})
	if depth > 0:
		var tip := pts[pts.size() - 1]
		_spiral(tip + Vector2(0, -2), -side, r0 * 0.42, depth - 1, d + 0.2)
	else:
		flourish.append({"pts": PackedVector2Array(), "node": pts[pts.size() - 1], "d": d + 0.2})


# ---------------------------------------------------------------- draw
func _ease_back(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	var c1 := 2.4
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


func _trim(pa: PackedVector2Array, total: float, f: float) -> PackedVector2Array:
	if f >= 0.999:
		return pa
	var out := PackedVector2Array()
	var want := total * f
	var acc := 0.0
	out.append(pa[0])
	for i in range(1, pa.size()):
		var sl := pa[i].distance_to(pa[i - 1])
		if acc + sl >= want:
			out.append(pa[i - 1].lerp(pa[i], (want - acc) / maxf(sl, 0.0001)))
			return out
		acc += sl
		out.append(pa[i])
	return out


func _col(px: float, a: float) -> Color:
	var u := clampf((px / total_w) + 0.5, 0.0, 1.0)
	var c := ice.lerp(gold, smoothstep(0.15, 0.95, u))
	c.a = a
	return c


func _stroke(pa: PackedVector2Array, w: float, a: float, pop: float = 1.0) -> void:
	if pa.size() < 2:
		return
	var cols := PackedColorArray()
	for p in pa:
		cols.append(_col(p.x, a))
	draw_polyline_colors(pa, cols, w, true)


func _draw() -> void:
	if t < 0.0:
		return
	var s := size.x / DW
	var cx := size.x * 0.5
	var cy := size.y * 0.25
	# overall scale so total width is about 66% of the screen width
	s *= (DW * 0.66) / total_w
	draw_set_transform(Vector2(cx, cy), 0.0, Vector2(s, s))
	var wv := 1.0 / maxf(s, 0.001)   # px -> design

	# soft flash behind the title: fires at the pop and decays
	var fl := exp(-t * 4.5) * clampf(t * 14.0, 0.0, 1.0)
	var halo := 0.16 + 0.5 * fl
	for i in range(6):
		var k := float(i) / 5.0
		draw_set_transform(Vector2(cx, cy + 36.0 * s), 0.0, Vector2(s * (1.0 + (1.0 - k) * 0.0), s * 0.34))
		draw_circle(Vector2.ZERO, total_w * (0.62 - 0.07 * i), Color(0.01, 0.06, 0.1, 0.1 * halo * 2.0 if i < 4 else 0.0))
	draw_set_transform(Vector2(cx, cy + 36.0 * s), 0.0, Vector2(s, s * 0.34))
	draw_circle(Vector2.ZERO, total_w * 0.42, Color(1.0, 0.95, 0.8, 0.05 * fl))
	draw_circle(Vector2.ZERO, total_w * 0.26, Color(1.0, 0.97, 0.88, 0.07 * fl))
	draw_set_transform(Vector2(cx, cy), 0.0, Vector2(s, s))

	var shimmer := 0.5 + 0.5 * sin(t * 2.2)
	for L in letters:
		var p: float = (t - float(L.delay)) / POP_TIME
		if p <= 0.0:
			continue
		var sc: float = _ease_back(p)
		var draw_f: float = clampf(p * 1.5, 0.0, 1.0)
		var c: Vector2 = L.c
		var ink: float = clampf(p * 3.0, 0.0, 1.0)
		for si in L.strokes.size():
			var src: PackedVector2Array = L.strokes[si]
			var pa := _trim(src, L.lens[si], draw_f)
			var tp := PackedVector2Array()
			for q in pa:
				tp.append(c + (q - c) * sc)
			_stroke(tp, 22.0, 0.10 * ink)
			_stroke(tp, 11.0, 0.24 * ink)
			_stroke(tp, 5.0, 1.0 * ink)
		if draw_f > 0.95:
			for n in L.nodes:
				var q: Vector2 = c + (n - c) * sc
				draw_circle(q, 7.5, _col(q.x, 0.3 * ink))
				draw_circle(q, 3.4, Color(1, 1, 1, 0.95 * ink))
			for r in L.rings:
				var q: Vector2 = c + (r[0] - c) * sc
				draw_arc(q, r[1], 0.0, TAU, 20, _col(q.x, 0.9 * ink), 2.0, true)
				draw_circle(q, r[1] * 2.2, _col(q.x, 0.14 * ink))
				draw_circle(q, 1.6, Color(1, 1, 1, 0.95 * ink))

	# fractal flourish, reveals after the letters
	var fp := clampf((t - 0.15) / 0.5, 0.0, 1.0)
	var fa := clampf((t - 0.15) / 0.3, 0.0, 1.0)
	for f in flourish:
		var rv: float = clampf((fp - float(f.d) * 0.8) / 0.35, 0.0, 1.0)
		if rv <= 0.0:
			continue
		if f.has("node"):
			var q: Vector2 = f.node
			draw_circle(q, 3.4, _col(q.x, 0.25 * rv))
			draw_circle(q, 1.7, Color(1, 1, 1, 0.9 * rv))
			continue
		var pa: PackedVector2Array = f.pts
		pa = _trim(pa, _len(pa), rv)
		if pa.size() < 2:
			continue
		_stroke(pa, f.w * 3.2, 0.10 * fa)
		_stroke(pa, f.w, 0.85 * fa)
