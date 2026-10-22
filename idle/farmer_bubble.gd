extends Control

# The angel's speech bubble: an ink-black, hand-cut panel with a shimmering gold border, an inner
# rule, corner diamonds, a little pictogram eye set into the top edge, and a tail that curls out of
# the speaker's mouth like a wisp of smoke with an ember in it.
# Usage: bubble.fit("full line") to size it, then set bubble.shown to reveal the text.

const GlyphsLib = preload("res://glyphs.gd")
const GOLD := Color(0.96, 0.82, 0.48)
const INK_TOP := Color(0.13, 0.115, 0.14)
const INK_BOT := Color(0.045, 0.04, 0.055)
const CREAM := Color(0.97, 0.93, 0.84)
const EMBER := Color(1.0, 0.72, 0.25)
const PAD := Vector2(36, 20)

var shown := ""
var word_key := ""
var word_on := 0.0
var word_a := 0.0
var word_text := "SAP"
var word_w := 64.0
var hint_a := 0.0
var hint_text := "tap to continue"
var font: Font
var font_size := 27
var tail_tip := Vector2(-50, 108)   # local position of the mouth the tail points at

var _shape := PackedVector2Array()
var _inner := StyleBoxFlat.new()
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Palatino Linotype", "Book Antiqua", "Georgia", "Garamond", "Times New Roman"])
	f.font_weight = 600
	f.antialiasing = TextServer.FONT_ANTIALIASING_LCD
	font = f
	_inner.bg_color = Color(0, 0, 0, 0)
	_inner.set_border_width_all(1)
	_inner.border_color = Color(GOLD, 0.38)
	_inner.set_corner_radius_all(11)


func fit(full: String) -> void:
	var lines := full.split("
")
	var mw := 0.0
	for ln in lines:
		mw = maxf(mw, font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var lh := font.get_height(font_size) + 4.0
	size = Vector2(maxf(mw + PAD.x * 2.0, 150.0), lh * lines.size() - 4.0 + PAD.y * 2.0)
	_build_shape()


# Rounded rectangle, densified and nudged so the edge looks cut by hand rather than computed.
func _build_shape() -> void:
	var w := size.x
	var h := size.y
	var r := 19.0
	var corners := [
		[Vector2(r, r), PI, 1.5 * PI], [Vector2(w - r, r), 1.5 * PI, 2.0 * PI],
		[Vector2(w - r, h - r), 0.0, 0.5 * PI], [Vector2(r, h - r), 0.5 * PI, PI]]
	var base := PackedVector2Array()
	for c in corners:
		for i in 7:
			var a: float = lerpf(c[1], c[2], i / 6.0)
			base.append((c[0] as Vector2) + Vector2.from_angle(a) * r)
	var pts := PackedVector2Array()
	for i in base.size():
		var a := base[i]
		var b := base[(i + 1) % base.size()]
		var n := maxi(1, int(a.distance_to(b) / 22.0))
		for k in n:
			pts.append(a.lerp(b, float(k) / n))
	_shape = PackedVector2Array()
	for i in pts.size():
		_shape.append(pts[i] + Vector2(sin(i * 2.31 + 0.7), cos(i * 1.93)) * 0.85)


func _process(delta: float) -> void:
	_t += delta
	if visible and scale.x > 0.01:
		queue_redraw()


func _bezier(p0: Vector2, c1: Vector2, c2: Vector2, p3: Vector2, u: float) -> Vector2:
	var v := 1.0 - u
	return p0 * v * v * v + c1 * 3.0 * v * v * u + c2 * 3.0 * v * u * u + p3 * u * u * u


func _draw() -> void:
	if _shape.is_empty():
		return
	var w := size.x
	var h := size.y
	var closed := _shape.duplicate()
	closed.append(_shape[0])

	# drop shadow
	draw_set_transform(Vector2(3, 6), 0.0, Vector2.ONE)
	draw_colored_polygon(_shape, Color(0, 0, 0, 0.38))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# ink fill, lighter toward the top
	var cols := PackedColorArray()
	for p in _shape:
		cols.append(INK_TOP.lerp(INK_BOT, clampf(p.y / h, 0.0, 1.0)))
	draw_polygon(_shape, cols)

	# soft gold bloom hugging the edge
	draw_polyline(closed, Color(GOLD, 0.07), 10.0, true)
	draw_polyline(closed, Color(GOLD, 0.11), 5.0, true)

	# border with a light that travels around it
	var n := closed.size()
	var colors := PackedColorArray()
	for i in n:
		var u := float(i) / n
		var d := fposmod(u - fmod(_t * 0.22, 1.0), 1.0)
		var v := exp(-d * 10.0)
		colors.append(Color(GOLD.r, GOLD.g, GOLD.b, 0.62 + 0.38 * v).lerp(Color(1, 0.97, 0.88, 1.0), v * 0.8))
	draw_polyline_colors(closed, colors, 2.2, true)

	# inner rule
	draw_style_box(_inner, Rect2(Vector2(7, 7), size - Vector2(14, 14)))

	# corner diamonds
	for c in [Vector2(11, 11), Vector2(w - 11, 11), Vector2(w - 11, h - 11), Vector2(11, h - 11)]:
		var d := PackedVector2Array([c + Vector2(0, -4), c + Vector2(4, 0), c + Vector2(0, 4), c + Vector2(-4, 0)])
		draw_colored_polygon(d, Color(GOLD, 0.9))

	# a pictogram eye set into the top edge
	draw_rect(Rect2(w * 0.5 - 20, -3, 40, 7), INK_TOP)
	GlyphsLib.draw(self, 0, Vector2(w * 0.5, 0), 20.0, Color(GOLD, 0.95), 1.4)

	# the tail: a curling wisp that tapers to the mouth
	var p0 := Vector2(40, h - 1)
	# S-shaped curl: swings out and down first, then hooks back in to the mouth
	var c1 := p0 + Vector2(34.0, 46.0)
	var c2 := tail_tip + Vector2(46.0, -34.0)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in 17:
		var u := i / 16.0
		var pt := _bezier(p0, c1, c2, tail_tip, u)
		var tg := (_bezier(p0, c1, c2, tail_tip, minf(u + 0.02, 1.0)) - pt).normalized()
		var nr := Vector2(-tg.y, tg.x)
		var wd := 9.0 * pow(1.0 - u, 1.1) + 0.5
		left.append(pt + nr * wd)
		right.append(pt - nr * wd)
	var tail := PackedVector2Array()
	tail.append_array(left)
	var rr := right.duplicate()
	rr.reverse()
	tail.append_array(rr)
	draw_colored_polygon(tail, INK_BOT.lerp(INK_TOP, 0.4))
	draw_polyline(left, Color(GOLD, 0.85), 1.5, true)
	draw_polyline(right, Color(GOLD, 0.85), 1.5, true)
	# ember riding the wisp
	var ep := _bezier(p0, c1, c2, tail_tip, 0.42 + 0.06 * sin(_t * 3.0))
	draw_circle(ep, 6.0, Color(EMBER, 0.18))
	draw_circle(ep, 3.2, Color(EMBER, 0.95))
	draw_circle(ep, 1.3, Color(1.0, 0.95, 0.75, 1.0))

	# text
	var base_y := PAD.y + font.get_ascent(font_size)
	var lh := font.get_height(font_size) + 4.0
	var li := 0
	for ln in shown.split("
"):
		var p := Vector2(PAD.x, base_y + li * lh)
		draw_string(font, p + Vector2(1.5, 1.5), ln, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.7))
		draw_string(font, p, ln, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, CREAM)
		li += 1

	# glyph word that resolves into English
	if word_key != "" and word_on > 0.01:
		var c := Vector2(PAD.x + word_w * 0.5, base_y - font_size * 0.32)
		var ga := word_on * (1.0 - word_a)
		if ga > 0.01:
			UiKit.word(self, word_key, c, 21.0, Color(0.55, 0.95, 0.85, ga), 2.0)
		if word_a > 0.01:
			var ts := font.get_string_size(word_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var o := Vector2(PAD.x + (word_w - ts.x) * 0.5, base_y)
			draw_string(font, o, word_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(GOLD, word_a))
			draw_arc(c, 26.0 + 30.0 * (1.0 - word_a), 0, TAU, 28, Color(GOLD, 0.5 * (1.0 - word_a) * word_on), 1.5, true)

	# unobtrusive hint
	if hint_a > 0.01:
		var hs := 14
		var hw := font.get_string_size(hint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, hs).x
		var pulse := 0.55 + 0.25 * sin(_t * 3.0)
		draw_string(font, Vector2(w - hw - 24, h - 9), hint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, hs, Color(GOLD, pulse * hint_a))
