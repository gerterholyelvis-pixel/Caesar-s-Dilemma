class_name UiKit
extends RefCounted
## Shared look for the step-3 screens: ink glass, gold rims, glyph words, guarded art calls.

const GOLD := Color(0.93, 0.80, 0.52)
const CREAM := Color(0.97, 0.93, 0.84)
const INK_TOP := Color(0.13, 0.115, 0.14)
const INK_BOT := Color(0.045, 0.04, 0.055)
const TEAL := Color(0.15, 0.85, 0.75)
const VIOLET := Color(0.66, 0.38, 1.0)
const MAGENTA := Color(1.0, 0.35, 0.8)
const CYAN := Color(0.45, 0.95, 1.0)
const RARITY := {1: Color(0.15, 0.85, 0.75), 2: Color(0.66, 0.38, 1.0), 3: Color(1.0, 0.82, 0.4)}

static var _font: Font


static func font() -> Font:
	if _font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Palatino Linotype", "Book Antiqua", "Georgia", "Garamond", "Times New Roman"])
		f.font_weight = 600
		f.antialiasing = TextServer.FONT_ANTIALIASING_LCD
		_font = f
	return _font


static func ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0)


## Ink-black glass panel with gold rim; hot 0..1 lifts glow, tint colours the glow.
static func panel(ci: CanvasItem, r: Rect2, tint: Color, hot := 0.0, alpha := 1.0, radius := 16) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = INK_TOP.lerp(INK_BOT, 0.4)
	sb.bg_color.a = 0.9 * alpha
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(2)
	sb.border_color = GOLD.lerp(tint, 0.35 + 0.4 * hot)
	sb.border_color.a = (0.55 + 0.45 * hot) * alpha
	sb.shadow_color = Color(tint, (0.12 + 0.4 * hot) * alpha)
	sb.shadow_size = int(8 + 22 * hot)
	ci.draw_style_box(sb, r)
	var inner := StyleBoxFlat.new()
	inner.bg_color = Color(0, 0, 0, 0)
	inner.set_border_width_all(1)
	inner.set_corner_radius_all(maxi(radius - 5, 2))
	inner.border_color = Color(GOLD, 0.25 * alpha)
	ci.draw_style_box(inner, r.grow(-6))
	for c in [r.position + Vector2(10, 10), Vector2(r.end.x - 10, r.position.y + 10),
			r.end - Vector2(10, 10), Vector2(r.position.x + 10, r.end.y - 10)]:
		ci.draw_circle(c, 2.2, Color(GOLD, 0.7 * alpha))


static func glow(ci: CanvasItem, c: Vector2, rad: float, col: Color) -> void:
	for i in 6:
		var k := float(i) / 6.0
		ci.draw_circle(c, rad * (1.0 - k * 0.8), Color(col, col.a * (0.05 + 0.1 * k)))


static func text(ci: CanvasItem, s: String, pos: Vector2, size: int, col: Color, width := -1.0,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	ci.draw_string(font(), pos, s, align, width, size, col)


static func wrapped(ci: CanvasItem, s: String, pos: Vector2, size: int, col: Color, width: float,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> float:
	ci.draw_multiline_string(font(), pos, s, align, width, size, -1, col)
	var h := font().get_multiline_string_size(s, align, width, size).y
	return h


## Draw a Lexicon word (determinative + roots) as glyphs centred at c; returns total width.
static func word(ci: CanvasItem, key: String, c: Vector2, size: float, col: Color, width := 2.0) -> float:
	var w: Array[int] = Lexicon.word_for(key)
	if w.is_empty():
		return 0.0
	var gap := size * 1.05
	var total := gap * (w.size() - 1)
	var x := c.x - total * 0.5
	for i in w.size():
		var cc := col if i > 0 else Color(col.r, col.g, col.b, col.a * 0.7)
		GlyphGen.draw(ci, w[i], Vector2(x + gap * i, c.y), size * (1.0 if i > 0 else 0.8), cc, width)
	return total + size


## Item icon through ItemIcons if present, else a glowing rounded rect.
static func icon(ci: CanvasItem, id: String, r: Rect2, t := 0.0, glow_amt := 0.0) -> void:
	var s: Script = load("res://game/item_icons.gd") if ResourceLoader.exists("res://game/item_icons.gd") else null
	if s != null and s.has_method("draw"):
		s.call("draw", ci, id, r, t, glow_amt)
		return
	var col := Color.from_hsv(float(hash(id) % 360) / 360.0, 0.55, 0.9)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col, 0.55)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = col.lightened(0.3)
	sb.shadow_color = Color(col, 0.3 + 0.4 * glow_amt)
	sb.shadow_size = 8
	ci.draw_style_box(sb, r.grow(-3))


static func fit_control(c: Control) -> void:
	if c.size.x < 10.0:
		c.size = Vector2(960, 640)


static func fade_in(c: Control, dur := 0.5) -> void:
	c.modulate.a = 0.0
	c.create_tween().tween_property(c, "modulate:a", 1.0, dur).set_trans(Tween.TRANS_SINE)
