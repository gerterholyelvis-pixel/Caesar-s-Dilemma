class_name Cinematics
extends RefCounted
## Five procedural full-screen cinematics built on Cutscene. Every func is an awaitable coroutine:
##   await Cinematics.hero_reveal(parent, "seshat")      await Cinematics.boss_intro(parent, "cascade_warden")
##   await Cinematics.first_glyph(parent, "item:lens")   await Cinematics.death(parent)
##   await Cinematics.ending(parent, "thoth")
## Any key / click skips. Cinematics.instant = true (also automatic when headless) returns immediately.

static var instant := false

const TEAL := Color(0.10, 0.80, 0.62)
const VIOLET := Color(0.55, 0.30, 0.95)
const GOLD := Color(1.0, 0.82, 0.38)
const CYAN := Color(0.45, 0.95, 1.0)
const INK := Color(0.02, 0.02, 0.05)
const RED := Color(0.85, 0.12, 0.14)


## One overlay: `t` (seconds) is tweened by the Cutscene; layers redraw from it.
class Cine extends Control:
	var t := 0.0
	var fade := 1.0          ## black veil alpha (drawn last)
	var white := 0.0         ## white/ash veil alpha
	var white_col := Color.WHITE
	var cs: Cutscene
	var layers: Array = []   ## Callables(layer: Control, cine: Cine)

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		for fn in layers:
			var l := Layer.new()
			l.fn = fn
			l.cine = self
			l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(l)

	func _process(_d: float) -> void:
		queue_redraw()
		for c in get_children():
			if c is Layer:
				c.queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), INK)

	func _gui_input(ev: InputEvent) -> void:
		if cs != null and ((ev is InputEventKey and ev.pressed) or (ev is InputEventMouseButton and ev.pressed)):
			cs.skip()
			accept_event()


class Layer extends Control:
	var fn: Callable
	var cine: Cine

	func _draw() -> void:
		if fn.is_valid() and cine != null:
			fn.call(self, cine)


class Veil extends Control:
	var cine: Cine

	func _draw() -> void:
		if cine == null:
			return
		if cine.white > 0.001:
			draw_rect(Rect2(Vector2.ZERO, size), Color(cine.white_col, cine.white))
		if cine.fade > 0.001:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, cine.fade))

	func _process(_d: float) -> void:
		queue_redraw()


# --------------------------------------------------------------------------- plumbing
static func _skip() -> bool:
	return instant or DisplayServer.get_name() == "headless"


static func _sfx(n: String) -> void:
	Hub.sfx(n)


static func _run(parent: Node, dur: float, layers: Array, setup: Callable, white_col := Color.WHITE) -> void:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var c := Cine.new()
	c.layers = layers
	c.white_col = white_col
	parent.add_child(c)
	var veil := Veil.new()
	veil.cine = c
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(veil)
	var cs := Cutscene.new().bind(c)
	c.cs = cs
	cs.tween(c, "t", dur, dur, 0.0, Tween.TRANS_LINEAR)
	cs.letterbox(true, 0.7).letterbox(false, 0.6, dur - 0.7)
	setup.call(cs, c)
	await cs.play()
	if is_instance_valid(cs):
		cs.queue_free()
	if is_instance_valid(c):
		c.queue_free()


static func _u(l: Control) -> float:
	return l.size.y / 720.0


static func _sm(a: float, b: float, x: float) -> float:
	return smoothstep(a, b, x)


static func _glow(l: Control, p: Vector2, r: float, col: Color, a := 0.5, n := 6) -> void:
	for i in n:
		var k := float(i + 1) / n
		l.draw_circle(p, r * (1.0 - k * 0.8) * 1.0, Color(col, a * k * k / n * 2.2))


static func _hash(s: String) -> int:
	return absi(s.hash())


static func _glyph_ids(key: String, fallback_seed: String, n := 3) -> Array[int]:
	if Lexicon.has_concept(key):
		return Lexicon.word_for(key)
	var out: Array[int] = []
	var h := _hash(fallback_seed)
	for i in n:
		out.append((h >> (i * 5)) % 97 + i * 13)
	return out


static func _draw_ids(l: Control, ids: Array, center: Vector2, size: float, col: Color, a := 1.0, w := 2.5) -> void:
	var total := (ids.size() - 1) * size * 1.1
	var x := center.x - total * 0.5
	for g in ids:
		GlyphGen.draw(l, int(g), Vector2(x, center.y), size, Color(col, a), w)
		x += size * 1.1


static func _text(l: Control, s: String, p: Vector2, fs: int, col: Color, spacing := 0.0) -> void:
	var f: Font = ThemeDB.fallback_font
	if spacing > 0.0:
		var w := 0.0
		for ch in s:
			w += f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + spacing
		w -= spacing
		var x := p.x - w * 0.5
		for ch in s:
			l.draw_string(f, Vector2(x, p.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
			x += f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + spacing
	else:
		l.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_CENTER, 1200, fs, col)


## Recursive growing fractal arm. g = growth 0..1 for the whole tree.
static func _fractal(l: Control, p: Vector2, ang: float, ln: float, depth: int, g: float, col: Color, tip: Color, w: float, spread := 0.5) -> void:
	if depth <= 0 or g <= 0.0:
		return
	var gg := clampf(g * 1.6, 0.0, 1.0)
	var e := p + Vector2.from_angle(ang) * ln * gg
	var c := col.lerp(tip, 1.0 - float(depth) / 6.0)
	l.draw_line(p, e, c, maxf(w, 1.0), true)
	if gg < 1.0:
		return
	var g2 := g - 0.35
	_fractal(l, e, ang - spread, ln * 0.68, depth - 1, g2 * 1.4, col, tip, w * 0.7, spread)
	_fractal(l, e, ang + spread, ln * 0.68, depth - 1, g2 * 1.4, col, tip, w * 0.7, spread)


static func _star_poly(n: int, r_out: float, r_in: float, rot: float, c: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n * 2:
		var r := r_out if i % 2 == 0 else r_in
		pts.append(c + Vector2.from_angle(rot + i * PI / n) * r)
	pts.append(pts[0])
	return pts


# --------------------------------------------------------------------------- 1. hero reveal
static func hero_reveal(parent: Node, hero_id: String) -> void:
	if _skip():
		return
	var thoth := hero_id == "thoth"
	var c1 := VIOLET if thoth else GOLD
	var c2 := TEAL if thoth else CYAN
	var name_s := "THOTH" if thoth else "SESHAT"
	var ids := _glyph_ids("hero:" + hero_id, "hero_" + hero_id, 3)
	var draw_fn := func(l: Control, c: Cine) -> void:
		var u := _u(l)
		var ctr := l.size * 0.5 + Vector2(0, -20 * u)
		var t := c.t
		var grow := _sm(0.3, 3.4, t)
		# fractal growth: eight arms spiral inward-out
		var burst := _sm(3.4, 3.7, t)
		var form := _sm(3.5, 5.0, t)
		if t < 3.9:
			var gal := 1.0 - _sm(3.4, 3.9, t)
			for i in 8:
				var a := i * TAU / 8.0 + t * 0.25
				_fractal(l, ctr + Vector2.from_angle(a) * 36 * u * (1.0 - grow * 0.4), a, 120 * u * (1.0 + grow * 0.2), 6, grow * (1.0 - burst * 0.5), Color(c1, 0.8 * gal), Color(c2, 0.8 * gal), 3.0 * u)
			_glow(l, ctr, 70 * u * (0.5 + grow), c2, 0.35 * gal)
		# the hero form
		if form > 0.0:
			var R := 150 * u * (0.7 + 0.3 * form)
			var a_f := form
			var rot := t * 0.35
			_glow(l, ctr, R * 1.5, c1, 0.22 * a_f)
			if not thoth:
				# measuring spiral + nested star lattice
				for k in 5:
					var sc := 1.0 - k * 0.17
					var pts := _star_poly(8, R * sc, R * sc * 0.55, rot * (1 if k % 2 == 0 else -1) + k * 0.2, ctr)
					l.draw_polyline(pts, Color(c1 if k % 2 == 0 else c2, 0.85 * a_f), 2.0 * u, true)
				var sp := PackedVector2Array()
				for i in 90:
					var f := i / 89.0
					sp.append(ctr + Vector2.from_angle(f * TAU * 2.6 - rot * 2.0) * R * 1.15 * pow(f, 0.8))
				l.draw_polyline(sp, Color(CYAN, 0.9 * a_f), 2.5 * u, true)
				for i in 12:
					var tk := ctr + Vector2.from_angle(i * TAU / 12.0 + rot) * R * 1.3
					l.draw_line(tk, ctr + (tk - ctr) * 0.94, Color(GOLD, 0.7 * a_f), 2.0 * u)
			else:
				# ibis-curved prism: faceted triangle prism with a curved neck and beak
				var tri := PackedVector2Array()
				for i in 3:
					tri.append(ctr + Vector2.from_angle(-PI / 2 + i * TAU / 3.0 + sin(t) * 0.05) * R)
				for k in 4:
					var s := 1.0 - k * 0.2
					var poly := PackedVector2Array()
					for p in tri:
						poly.append(ctr + (p - ctr) * s)
					poly.append(poly[0])
					l.draw_polyline(poly, Color(c1 if k % 2 == 0 else c2, 0.85 * a_f), 2.0 * u, true)
				var neck := PackedVector2Array()
				for i in 40:
					var f := i / 39.0
					neck.append(ctr + Vector2(-R * 0.2 + sin(f * 2.6) * R * 0.5, R * 0.1 - f * R * 1.35 + cos(f * 3.0) * R * 0.1))
				l.draw_polyline(neck, Color(CYAN, 0.9 * a_f), 3.0 * u, true)
				var tip: Vector2 = neck[neck.size() - 1]
				l.draw_line(tip, tip + Vector2(R * 0.42, R * 0.2), Color(GOLD, 0.95 * a_f), 3.0 * u, true)
				l.draw_circle(tip + Vector2(-4 * u, 2 * u), 4 * u, Color(GOLD, a_f))
			_glow(l, ctr, 26 * u, Color.WHITE, 0.5 * a_f)
		# glyph name, then it resolves
		var gy := l.size.y * 0.80
		var ga := _sm(4.2, 4.9, t) * (1.0 - _sm(5.6, 6.3, t))
		if ga > 0.0:
			_draw_ids(l, ids, Vector2(l.size.x * 0.5, gy), 56 * u, c1, ga, 3.0)
		var ea := _sm(5.7, 6.5, t)
		if ea > 0.0:
			_text(l, name_s, Vector2(l.size.x * 0.5, gy + 12 * u), int(46 * u), Color(1, 0.95, 0.85, ea), 18 * u * (1.4 - 0.4 * ea))
		# the burst
		var br := _sm(3.3, 4.3, t)
		if t > 3.3 and br < 1.0:
			l.draw_arc(ctr, br * l.size.x * 0.7, 0, TAU, 96, Color(c2, 1.0 - br), 4 * u, true)
			l.draw_arc(ctr, br * l.size.x * 0.45, 0, TAU, 96, Color(c1, 0.8 * (1.0 - br)), 6 * u, true)
	await _run(parent, 7.4, [draw_fn], func(cs: Cutscene, c: Cine) -> void:
		cs.tween(c, "fade", 0.0, 1.0)
		cs.sound("secret_found", 1.0)
		cs.sound("boss_sting", 3.4)
		cs.sound("glyph_learn", 5.7)
		cs.tween(c, "white", 0.8, 0.12, 3.4)
		cs.tween(c, "white", 0.0, 0.9, 3.55)
		cs.tween(c, "fade", 1.0, 0.8, 6.6)
		cs.shake(6.0, 0.5, 3.4))


# --------------------------------------------------------------------------- 2. boss intro
static func boss_intro(parent: Node, boss_id: String) -> void:
	if _skip():
		return
	var ids := _glyph_ids("enemy:" + boss_id, boss_id, 3)
	var title := boss_id.replace("_", " ").to_upper()
	if title == "CASCADE WARDEN":
		title = "THE CASCADE WARDEN"
	var mist := func(l: Control, c: Cine, front: bool) -> void:
		var u := _u(l)
		var t := c.t
		var W := l.size.x
		var H := l.size.y
		for i in (5 if front else 7):
			var k := float(i) / 6.0
			var y := H * (0.95 - 0.1 * i) - (0.0 if front else 0.0) + sin(t * 0.5 + i) * 14 * u
			var rise := _sm(0.0, 3.0, t)
			if front:
				y += rise * H * 0.55
			if y > H - 40 * u:
				continue
			var col := Color(0.12, 0.35 + 0.1 * k, 0.4 + 0.1 * k, 0.16 if front else 0.2)
			var pts := PackedVector2Array([Vector2(0, H), Vector2(0, y)])
			for j in 25:
				var x := W * j / 24.0
				pts.append(Vector2(x, y + sin(x * 0.01 + t * 0.7 + i * 2.0) * 22 * u + sin(x * 0.027 - t) * 9 * u))
			pts.append(Vector2(W, H))
			l.draw_colored_polygon(pts, col)
	var back := func(l: Control, c: Cine) -> void:
		var u := _u(l)
		var t := c.t
		var W := l.size.x
		var H := l.size.y
		# waterfall streaks falling behind
		for i in 60:
			var x := W * fposmod(i * 0.6180339, 1.0)
			var sp := 0.25 + fposmod(i * 0.37, 0.5)
			var y := fposmod(t * sp + i * 0.113, 1.0) * H
			var ln := (80 + (i % 7) * 20) * u
			l.draw_line(Vector2(x, y), Vector2(x, y + ln), Color(TEAL, 0.12 + 0.1 * sin(i)), 2.0 * u)
		_glow(l, Vector2(W * 0.5, H * 0.45), 320 * u, VIOLET, 0.25 * _sm(0.5, 3.0, t))
		mist.call(l, c, false)
	var actor := func(l: Control, c: Cine) -> void:
		var u := _u(l)
		var t := c.t
		var rise := _sm(0.8, 4.2, t)
		var a := _sm(0.8, 2.6, t)
		var pos := Vector2(l.size.x * 0.5, l.size.y * (0.88 - 0.26 * rise))
		l.modulate.a = a
		CreatureArt.draw(l, boss_id, pos, 300 * u * (0.9 + 0.2 * rise), t)
	var front := func(l: Control, c: Cine) -> void:
		var u := _u(l)
		var t := c.t
		mist.call(l, c, true)
		var ta := _sm(3.6, 4.4, t) * (1.0 - _sm(6.4, 7.0, t))
		if ta > 0.0:
			var cy := l.size.y * 0.21
			_draw_ids(l, ids, Vector2(l.size.x * 0.5, cy), 46 * u, GOLD, ta, 3.0)
			var rr := _sm(4.6, 5.6, t)
			_text(l, title, Vector2(l.size.x * 0.5, cy + 62 * u), int(34 * u), Color(1, 0.92, 0.75, ta * rr), 14 * u)
			l.draw_line(Vector2(l.size.x * 0.5 - 180 * u * rr, cy + 80 * u), Vector2(l.size.x * 0.5 + 180 * u * rr, cy + 80 * u), Color(GOLD, ta * 0.8), 2.0 * u)
	await _run(parent, 7.2, [back, actor, front], func(cs: Cutscene, c: Cine) -> void:
		cs.tween(c, "fade", 0.0, 0.9)
		cs.sound("boss_sting", 1.0)
		cs.sound("secret_found", 3.6)
		cs.shake(5.0, 0.8, 3.3)
		cs.tween(c, "fade", 1.0, 0.5, 6.7)
		cs.at(0.1, func(): Hub.tension(0.9)))


# --------------------------------------------------------------------------- 3. first glyph
static func first_glyph(parent: Node, concept_key: String) -> void:
	if _skip():
		return
	var ids := _glyph_ids(concept_key, concept_key, 2)
	var meaning := Lexicon.readable_name(concept_key) if Lexicon.has_concept(concept_key) else concept_key.get_slice(":", 1).replace("_", " ")
	meaning = meaning.to_upper()
	var draw_fn := func(l: Control, c: Cine) -> void:
		var u := _u(l)
		var t := c.t
		var ctr := l.size * 0.5 + Vector2(0, -30 * u)
		var arise := _sm(0.3, 1.3, t)
		var dis := _sm(2.3, 3.6, t)
		var res := _sm(2.4, 3.6, t)
		_glow(l, ctr, 260 * u, GOLD, 0.16 * arise)
		# faint orbiting lattice rings
		for k in 4:
			var r := (90 + k * 55) * u * (0.8 + 0.2 * arise)
			l.draw_arc(ctr, r, t * 0.4 * (1 if k % 2 == 0 else -1), t * 0.4 * (1 if k % 2 == 0 else -1) + TAU * 0.7, 64, Color(CYAN if k % 2 else GOLD, 0.18 * arise), 1.5 * u, true)
		var ga := arise * (1.0 - dis)
		if ga > 0.0:
			_draw_ids(l, ids, ctr, 120 * u * (1.0 + dis * 0.25), Color(GOLD.lerp(Color.WHITE, 0.4 * sin(t * 4.0) * 0.5 + 0.2), 1.0), ga, 3.5 * u)
		# dissolve: motes spiral from the glyph to the meaning line
		if dis > 0.0 and dis < 1.0:
			for i in 70:
				var h := fposmod(i * 0.754877, 1.0)
				var src := ctr + Vector2((h - 0.5) * 220 * u * ids.size(), sin(i * 1.7) * 60 * u)
				var dst := Vector2(l.size.x * 0.5 + (fposmod(i * 0.31, 1.0) - 0.5) * 320 * u, ctr.y + 150 * u)
				var f := clampf(dis * 1.3 - h * 0.3, 0.0, 1.0)
				var p := src.lerp(dst, f) + Vector2(sin(f * PI * 3 + i), -sin(f * PI) * 40 * u)
				l.draw_circle(p, 2.5 * u, Color(CYAN.lerp(GOLD, h), sin(f * PI)))
		var ma := _sm(3.0, 3.9, t) * (1.0 - _sm(5.0, 5.4, t))
		if ma > 0.0:
			_text(l, meaning, Vector2(l.size.x * 0.5, ctr.y + 168 * u), int(44 * u), Color(1, 0.96, 0.85, ma), 16 * u * (1.5 - 0.5 * res))
			l.draw_line(Vector2(l.size.x * 0.5 - 140 * u * res, ctr.y + 188 * u), Vector2(l.size.x * 0.5 + 140 * u * res, ctr.y + 188 * u), Color(GOLD, ma * 0.7), 2 * u)
	await _run(parent, 5.5, [draw_fn], func(cs: Cutscene, c: Cine) -> void:
		cs.tween(c, "fade", 0.55, 0.5)
		cs.sound("secret_found", 0.5)
		cs.sound("glyph_learn", 2.4)
		cs.sound("heal", 2.9)
		cs.tween(c, "fade", 0.0, 0.01, 5.0)
		cs.tween(c, "fade", 1.0, 0.01, 5.49))


# --------------------------------------------------------------------------- 4. death
static func death(parent: Node) -> void:
	if _skip():
		return
	var draw_fn := func(l: Control, c: Cine) -> void:
		var u := _u(l)
		var t := c.t
		var W := l.size.x
		var H := l.size.y
		var fall := t * t * 38.0 * u   # cumulative downward speed
		# cloud bands rushing UP past the camera
		for i in 14:
			var depth := 0.4 + 0.6 * fposmod(i * 0.381966, 1.0)
			var y := fposmod(H * 1.2 - (t * 160.0 * depth * u + i * 97.0 * u), H * 1.3) - H * 0.15
			var x := fposmod(i * 211.0 + t * 12.0, W + 400 * u) - 200 * u
			var col := Color(0.25, 0.28, 0.38, 0.20 * depth).lerp(Color(0.6, 0.6, 0.7, 0.25 * depth), _sm(3.0, 6.0, t))
			for k in 4:
				l.draw_circle(Vector2(x + k * 70 * u * depth, y + sin(k * 2.0 + i) * 14 * u), (110 + k * 12) * u * depth, col)
		# the traveler: a fractal tree body that unravels
		var base := Vector2(W * 0.5, H * 0.35 + minf(fall * 0.04, 60 * u))
		var unravel := _sm(0.8, 4.5, t)
		var body_a := 1.0 - _sm(4.8, 6.0, t)
		_glow(l, base, 120 * u, VIOLET, 0.25 * body_a)
		var segs: Array = []
		_tree_segs(segs, Vector2.ZERO, -PI / 2, 110.0, 6, 0)
		for s in segs:
			var delay: float = s.d
			var f := clampf((unravel - delay * 0.6) * 2.5, 0.0, 1.0)
			var sh: float = s.h
			var drift: Vector2 = Vector2(sin(sh * 9.0) * 90 * u, 0) * f
			var off: Vector2 = drift + Vector2(0, f * f * (300 + sh * 400) * u)
			var rot: float = f * (sh - 0.5) * 3.0
			var a: Vector2 = base + (s.a * u).rotated(rot * 0.3) + off
			var b: Vector2 = base + (s.b * u).rotated(rot * 0.3) + off
			var col: Color = Color(GOLD, 0.9).lerp(Color(CYAN, 0.7), float(s.depth) / 6.0)
			col.a *= body_a * (1.0 - f * 0.6)
			l.draw_line(a, b, col, maxf(1.0, (6.0 - float(s.depth)) * 0.9 * u), true)
			if s.depth == 5 and f > 0.1:
				l.draw_circle(b, 2.5 * u, Color(CYAN, col.a))
		# the little red hat, the last thing to go
		var hat := base + Vector2(0, -122 * u) + Vector2(0, _sm(2.5, 5.0, t) * 360 * u)
		l.draw_colored_polygon(PackedVector2Array([hat + Vector2(-9, 0) * u, hat + Vector2(9, 0) * u, hat + Vector2(2, -14) * u]), Color(RED, body_a))
		# ash motes
		for i in 40:
			var p := Vector2(fposmod(i * 0.618 * W + sin(t + i) * 30 * u, W), fposmod(H * 1.1 - t * (30 + i % 9 * 8) * u - i * 40 * u, H * 1.1))
			l.draw_circle(p, 1.6 * u, Color(0.8, 0.8, 0.85, 0.35 * _sm(2.0, 4.0, t)))
	await _run(parent, 7.0, [draw_fn], func(cs: Cutscene, c: Cine) -> void:
		cs.tween(c, "fade", 0.0, 0.8)
		cs.sound("lose", 0.5)
		cs.sound("hit_player", 0.9)
		cs.shake(7.0, 0.5, 0.8)
		cs.tween(c, "white", 1.0, 2.0, 4.8)
		cs.at(6.9, func(): c.fade = 0.0), Color(0.82, 0.82, 0.86))


static func _tree_segs(out: Array, p: Vector2, ang: float, ln: float, depth: int, level: int) -> void:
	if depth <= 0:
		return
	var e := p + Vector2.from_angle(ang) * ln
	var h := fposmod(sin(p.x * 12.9898 + p.y * 78.233 + depth * 3.1) * 43758.5453, 1.0)
	out.append({"a": p, "b": e, "d": 1.0 - float(depth) / 6.0 + h * 0.15, "h": h, "depth": level})
	_tree_segs(out, e, ang - 0.5, ln * 0.7, depth - 1, level + 1)
	_tree_segs(out, e, ang + 0.5, ln * 0.7, depth - 1, level + 1)


# --------------------------------------------------------------------------- 5. ending
static func ending(parent: Node, hero_id: String) -> void:
	if _skip():
		return
	var thoth := hero_id == "thoth"
	var hc := VIOLET if thoth else GOLD
	var ids := _glyph_ids("title:caesar", "caesars_dilemma", 4)
	var draw_fn := func(l: Control, c: Cine) -> void:
		var u := _u(l)
		var t := c.t
		var W := l.size.x
		var H := l.size.y
		var turn := _sm(2.2, 4.2, t)       # water -> light
		var pull := _sm(3.0, 8.0, t)       # camera pull-back
		var zoom := lerpf(1.7, 0.72, pull)
		var ctr := l.size * 0.5
		l.draw_set_transform(ctr + Vector2(0, lerpf(60, 0, pull)) * u, 0.0, Vector2(zoom, zoom))
		# sky glow
		_glow(l, Vector2(0, -120 * u), 480 * u, VIOLET.lerp(GOLD, turn), 0.25)
		# cliff walls
		l.draw_colored_polygon(PackedVector2Array([Vector2(-W, -H), Vector2(-150 * u, -H), Vector2(-120 * u, 0), Vector2(-190 * u, H), Vector2(-W, H)]), Color(0.03, 0.04, 0.09))
		l.draw_colored_polygon(PackedVector2Array([Vector2(W, -H), Vector2(150 * u, -H), Vector2(120 * u, 0), Vector2(190 * u, H), Vector2(W, H)]), Color(0.03, 0.04, 0.09))
		# the waterfall: teal streaks that become rising light
		for i in 70:
			var f := fposmod(i * 0.6180339, 1.0)
			var x := lerpf(-135, 135, f) * u
			var sp := 0.35 + fposmod(i * 0.29, 0.5)
			var dirn := lerpf(1.0, -1.0, turn)
			var y := (fposmod(t * sp * dirn + i * 0.173, 1.0) - 0.5) * H * 1.5
			var ln := (90 + (i % 5) * 30) * u
			var col := TEAL.lerp(GOLD.lerp(Color.WHITE, 0.4), turn)
			l.draw_line(Vector2(x, y), Vector2(x, y + ln), Color(col, 0.35 + 0.35 * turn), (2.0 + turn * 2.0) * u)
		# the figure at the water's edge
		var fy := 150 * u
		_glow(l, Vector2(0, fy), 70 * u, hc, 0.3 + 0.3 * turn)
		var a_ := 1.0
		if thoth:
			var tri := PackedVector2Array()
			for i in 3:
				tri.append(Vector2(0, fy) + Vector2.from_angle(-PI / 2 + i * TAU / 3.0) * 30 * u)
			tri.append(tri[0])
			l.draw_polyline(tri, Color(VIOLET, a_), 2.0 * u, true)
			l.draw_polyline(tri, Color(TEAL, 0.6), 1.0 * u, true)
		else:
			l.draw_polyline(_star_poly(8, 30 * u, 17 * u, t * 0.3, Vector2(0, fy)), Color(GOLD, a_), 2.0 * u, true)
			l.draw_polyline(_star_poly(8, 20 * u, 11 * u, -t * 0.4, Vector2(0, fy)), Color(CYAN, 0.8), 1.5 * u, true)
		# pool shimmer rings
		for k in 4:
			var r := fposmod(t * 0.3 + k * 0.25, 1.0)
			l.draw_arc(Vector2(0, 230 * u), r * 260 * u, 0, TAU, 64, Color(GOLD, (1.0 - r) * 0.4 * turn), 1.5 * u, true)
		l.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# title returns
		var ta := _sm(6.3, 7.6, t)
		if ta > 0.0:
			_draw_ids(l, ids, Vector2(W * 0.5, H * 0.17), 44 * u, GOLD, ta * 0.9, 3.0)
			_text(l, "CAESAR'S DILEMMA", Vector2(W * 0.5, H * 0.17 + 78 * u), int(40 * u), Color(1, 0.94, 0.78, ta), 12 * u)
	await _run(parent, 10.0, [draw_fn], func(cs: Cutscene, c: Cine) -> void:
		cs.tween(c, "fade", 0.0, 1.2)
		cs.sound("win", 0.8)
		cs.sound("secret_found", 2.4)
		cs.sound("glyph_learn", 6.4)
		cs.tween(c, "white", 0.7, 0.6, 2.6)
		cs.tween(c, "white", 0.0, 1.6, 3.2)
		cs.tween(c, "fade", 1.0, 1.0, 9.0)
		cs.at(0.1, func(): Hub.tension(0.0)), Color(1, 0.95, 0.8))
