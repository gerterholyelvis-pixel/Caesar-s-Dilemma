extends Button

# LAYER: start_button. The only UI element. Emits `pressed` (built-in). Text must stay "Start".
# start_screen.gd anchors it bottom-center; keep custom_minimum_size around 240x70.
# Everything is drawn procedurally in _draw (glass panel, shimmering ornate border, runes, text glow).

const SIZE_PX := Vector2(240, 70)
const CUT := 16.0          # chamfer of the corners
const PATH_STEPS := 6

var _t := 0.0
var _hover := 0.0          # 0..1 eased by tween
var _press := 0.0          # 0..1 eased by tween
var _sweep := 0.0          # shimmer phase 0..1 (looping)
var _speed := 0.18
var _font: FontVariation
var _path := PackedVector2Array()
var _path_len := PackedFloat32Array()
var _total := 1.0
var _tw_hover: Tween
var _tw_press: Tween
var _tw_scale: Tween

const COL_ICE := Color(0.62, 0.86, 1.0)
const COL_GOLD := Color(1.0, 0.86, 0.55)


func _ready() -> void:
	text = "Start"
	custom_minimum_size = SIZE_PX
	pivot_offset = SIZE_PX * 0.5
	focus_mode = Control.FOCUS_NONE
	clip_contents = false
	var f := FontVariation.new()
	f.base_font = ThemeDB.fallback_font
	f.spacing_glyph = 7
	_font = f
	add_theme_font_override("font", _font)
	add_theme_font_size_override("font_size", 28)
	# text is drawn by _draw (with glow); hide the built-in one
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
		add_theme_color_override(c, Color(0, 0, 0, 0))
	var e := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(s, e)
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	resized.connect(_build_path)
	_build_path()


func _on_enter() -> void:
	_kill(_tw_hover); _kill(_tw_scale)
	_tw_hover = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw_hover.tween_property(self, "_hover", 1.0, 0.28)
	_tw_scale = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw_scale.tween_property(self, "scale", Vector2(1.06, 1.06), 0.3)


func _on_exit() -> void:
	_kill(_tw_hover); _kill(_tw_scale)
	_tw_hover = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw_hover.tween_property(self, "_hover", 0.0, 0.4)
	_tw_scale = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw_scale.tween_property(self, "scale", Vector2.ONE, 0.3)


func _on_down() -> void:
	_kill(_tw_press); _kill(_tw_scale)
	_tw_press = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw_press.tween_property(self, "_press", 1.0, 0.08)
	_tw_scale = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw_scale.tween_property(self, "scale", Vector2(0.96, 0.96), 0.08)


func _on_up() -> void:
	_kill(_tw_press); _kill(_tw_scale)
	_tw_press = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_tw_press.tween_property(self, "_press", 0.0, 0.5)
	var target := Vector2(1.06, 1.06) if is_hovered() else Vector2.ONE
	_tw_scale = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw_scale.tween_property(self, "scale", target, 0.3)


func _kill(t: Tween) -> void:
	if t and t.is_valid():
		t.kill()


func _process(delta: float) -> void:
	_t += delta
	_speed = lerpf(0.16, 0.55, _hover)
	_sweep = fmod(_sweep + delta * _speed, 1.0)
	queue_redraw()


# Chamfered rounded outline, clockwise from the top-left, closed.
func _build_path() -> void:
	var w := size.x
	var h := size.y
	if w < 10.0:
		return
	var pts := PackedVector2Array()
	var c := CUT
	var r := 9.0
	# corners as small arcs after the chamfer: use chamfer + slight rounding
	var corners := [
		[Vector2(c, 0), Vector2(w - c, 0)],
		[Vector2(w, c), Vector2(w, h - c)],
		[Vector2(w - c, h), Vector2(c, h)],
		[Vector2(0, h - c), Vector2(0, c)],
	]
	for seg in corners:
		pts.append(seg[0])
		pts.append(seg[1])
	# densify
	var dense := PackedVector2Array()
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var n := 1 if (i % 2 == 1) else 10
		for k in n:
			dense.append(a.lerp(b, float(k) / n))
	dense.append(dense[0])
	_path = dense
	_path_len = PackedFloat32Array()
	var acc := 0.0
	_path_len.append(0.0)
	for i in range(1, dense.size()):
		acc += dense[i].distance_to(dense[i - 1])
		_path_len.append(acc)
	_total = maxf(acc, 1.0)
	_r_unused(r)


func _r_unused(_r: float) -> void:
	pass


func _poly(inset: float) -> PackedVector2Array:
	var w := size.x
	var h := size.y
	var c := CUT
	var i := inset
	return PackedVector2Array([
		Vector2(c + i * 0.4, i), Vector2(w - c - i * 0.4, i), Vector2(w - i, c + i * 0.4),
		Vector2(w - i, h - c - i * 0.4), Vector2(w - c - i * 0.4, h - i), Vector2(c + i * 0.4, h - i),
		Vector2(i, h - c - i * 0.4), Vector2(i, c + i * 0.4)])


func _draw() -> void:
	if _path.is_empty():
		return
	var w := size.x
	var h := size.y
	var center := size * 0.5
	var breathe := 0.5 + 0.5 * sin(_t * 1.6)
	var energy := 0.55 + 0.25 * breathe + 0.5 * _hover + 0.3 * _press

	# ---- outer soft glow (stacked expanding polys) ----
	for i in 7:
		var k := float(i) / 6.0
		var grow := 3.0 + k * 20.0
		var a := (1.0 - k) * (1.0 - k) * 0.055 * energy
		var col := COL_ICE.lerp(Color(0.5, 0.6, 1.0), k)
		col.a = a
		draw_colored_polygon(_poly(-grow), col)

	# ---- glass body ----
	var body := _poly(1.0)
	var top := Color(0.16, 0.24, 0.46, 0.50 + 0.12 * _hover)
	var bot := Color(0.04, 0.07, 0.20, 0.72)
	var cols := PackedColorArray()
	for p in body:
		cols.append(top.lerp(bot, clampf(p.y / h, 0.0, 1.0)))
	draw_polygon(body, cols)
	# inner glow rising from the bottom and from the edges
	for i in 6:
		var k := float(i) / 5.0
		var ins := 2.0 + k * 11.0
		var col := Color(0.35, 0.65, 1.0, (1.0 - k) * 0.06 * energy)
		draw_polyline(_close(_poly(ins)), col, 3.0 + k * 3.0, true)
	# frosted top highlight (specular band)
	var hl := PackedVector2Array([Vector2(CUT, 3), Vector2(w - CUT, 3), Vector2(w - CUT - 5, h * 0.46), Vector2(CUT + 5, h * 0.46)])
	var hc := PackedColorArray([Color(1, 1, 1, 0.17), Color(1, 1, 1, 0.17), Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.02)])
	draw_polygon(hl, hc)
	# pulsing center bloom
	var cg := Color(0.45, 0.75, 1.0, 0.05 + 0.08 * _hover + 0.03 * breathe)
	for i in 4:
		draw_circle(center, 60.0 - i * 13.0, Color(cg, cg.a * 0.6))

	# ---- static dim border ----
	var closed := _path
	draw_polyline(_close(_poly(0.0)), Color(0.45, 0.65, 1.0, 0.42 + 0.2 * _hover), 1.6, true)
	# fine inner line
	draw_polyline(_close(_poly(5.0)), Color(0.7, 0.85, 1.0, 0.13 + 0.07 * _hover), 1.0, true)

	# ---- shimmer sweep around border ----
	var n := closed.size()
	var colors := PackedColorArray()
	var colors2 := PackedColorArray()
	for i in n:
		var u := _path_len[i] / _total
		var d := fposmod(u - _sweep, 1.0)       # distance behind head
		var tail := exp(-d * 9.0) * (1.0 if d < 0.6 else 0.0)
		var d2 := fposmod(u - (_sweep + 0.5), 1.0)
		var tail2 := exp(-d2 * 14.0) * 0.6
		var v := clampf(tail + tail2, 0.0, 1.0)
		var hot := COL_ICE.lerp(Color.WHITE, v)
		var intensity := 0.15 + 1.15 * v + 0.25 * _hover * v
		colors.append(Color(hot.r * (0.6 + 1.2 * v), hot.g * (0.6 + 1.2 * v), hot.b * (0.7 + 1.2 * v), clampf(0.55 + v, 0.0, 1.0) * clampf(intensity * 1.2, 0.0, 1.0)))
		colors2.append(Color(0.5, 0.75, 1.3, v * 0.28 * (1.0 + _hover)))
	draw_polyline_colors(closed, colors2, 6.0, true)
	draw_polyline_colors(closed, colors, 2.0 + _hover * 0.6, true)

	# ---- corner studs + end ornaments ----
	_ornament(Vector2(-4, center.y), -1.0, energy, breathe)
	_ornament(Vector2(w + 4, center.y), 1.0, energy, breathe)
	for p in [Vector2(CUT, 0), Vector2(w - CUT, 0), Vector2(CUT, h), Vector2(w - CUT, h)]:
		_diamond(p, 2.4, Color(COL_GOLD.r * 1.25, COL_GOLD.g * 1.2, COL_GOLD.b * 1.1, 0.95))

	# ---- text with glow ----
	var fs := 28
	var ts := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos := Vector2(center.x - ts.x * 0.5 + 3.5, center.y + _font.get_ascent(fs) * 0.5 - _font.get_descent(fs) * 0.0 - 5.0 + _press * 1.5)
	pos.y = center.y - ts.y * 0.5 + _font.get_ascent(fs) + _press * 1.5
	var glow := 0.14 + 0.1 * breathe + 0.2 * _hover
	for o in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2), Vector2(-3, 3), Vector2(3, 3), Vector2(-3, -3), Vector2(3, -3)]:
		draw_string(_font, pos + o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.4, 0.75, 1.3, glow))
	draw_string(_font, pos + Vector2(0, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0.02, 0.1, 0.7))
	var tc := Color(0.92, 0.97, 1.0).lerp(Color(1.15, 1.12, 1.0), _hover)
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tc)


func _close(p: PackedVector2Array) -> PackedVector2Array:
	var q := p.duplicate()
	q.append(p[0])
	return q


func _diamond(c: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), col)


# Small rune cluster at each end: halo, diamond, flanking dashes
func _ornament(c: Vector2, dir: float, energy: float, breathe: float) -> void:
	var gold := Color(1.2, 0.95, 0.6)
	for i in 4:
		draw_circle(c, 14.0 - i * 3.0, Color(1.0, 0.8, 0.45, 0.05 * energy))
	_diamond(c, 8.0, Color(0.05, 0.08, 0.2, 0.9))
	draw_polyline(PackedVector2Array([c + Vector2(0, -8), c + Vector2(8, 0), c + Vector2(0, 8), c + Vector2(-8, 0), c + Vector2(0, -8)]), Color(gold, 0.9), 1.5, true)
	_diamond(c, 3.0 + 0.6 * breathe, Color(1.3, 1.05, 0.7, 1.0))
	# rune dashes outward
	var o := dir * 13.0
	draw_line(c + Vector2(o, 0), c + Vector2(o + dir * 9.0, 0), Color(gold, 0.7), 1.3, true)
	draw_line(c + Vector2(o + dir * 4.0, -4), c + Vector2(o + dir * 4.0, 4), Color(gold, 0.6), 1.3, true)
	_diamond(c + Vector2(o + dir * 14.0, 0), 1.8, Color(gold, 0.9))
