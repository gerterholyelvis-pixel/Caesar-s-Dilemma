extends Control

# One answer choice, written in pictograms that read as nothing. A dark tablet with a gold
# cartouche border; on hover the glyphs brighten and the whole tablet glows.

signal chosen(index: int)

const GlyphsLib = preload("res://glyphs.gd")
const GOLD := Color(0.93, 0.80, 0.52)

var index := 0
var glyph_ids: Array = []
var enabled := false
var hover := 0.0
var _t := randf() * 10.0
var _box := StyleBoxFlat.new()
var _tw: Tween


func _ready() -> void:
	size = Vector2(300, 58)
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_box.set_corner_radius_all(12)
	_box.set_border_width_all(2)
	mouse_entered.connect(func(): _hover_to(1.0))
	mouse_exited.connect(func(): _hover_to(0.0))


func _hover_to(v: float) -> void:
	if not enabled and v > 0.0:
		return
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(self, "hover", v, 0.18)
	_tw.tween_property(self, "scale", Vector2.ONE * (1.045 if v > 0.0 else 1.0), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _gui_input(event: InputEvent) -> void:
	if enabled and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		chosen.emit(index)


func _process(delta: float) -> void:
	_t += delta
	if modulate.a > 0.01:
		queue_redraw()


func _draw() -> void:
	_box.bg_color = Color(0.06, 0.055, 0.075, 0.93).lerp(Color(0.12, 0.10, 0.10, 0.96), hover)
	_box.border_color = Color(GOLD, 0.55 + 0.45 * hover)
	_box.shadow_color = Color(GOLD, 0.10 + 0.28 * hover)
	_box.shadow_size = int(5 + 9 * hover)
	draw_style_box(_box, Rect2(Vector2.ZERO, size))

	# cartouche bars at each end
	var bar := Color(GOLD, 0.5 + 0.4 * hover)
	for x in [15.0, size.x - 15.0]:
		draw_line(Vector2(x, 13), Vector2(x, size.y - 13), bar, 2.0, true)
		draw_circle(Vector2(x, 13), 2.0, bar)
		draw_circle(Vector2(x, size.y - 13), 2.0, bar)

	# the "text"
	var n := glyph_ids.size()
	var span := size.x - 74.0
	var step := span / maxf(n, 1.0)
	var col := GOLD.lerp(Color(1.0, 0.97, 0.88), hover)
	for i in n:
		var cx := 37.0 + step * (i + 0.5)
		var wob := sin(_t * 2.2 + i * 1.3) * (0.8 + 2.0 * hover)
		var a := 0.82 + 0.18 * sin(_t * 3.0 + i)
		GlyphsLib.draw(self, int(glyph_ids[i]), Vector2(cx, size.y * 0.5 + wob), 30.0, Color(col, a), 1.9 + hover * 0.4)
