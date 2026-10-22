extends Control

# The five statues of the obsidian deep, in one evenly spaced row on the glass floor.
# Only statue 1 (the goblin) answers to the mouse; it opens its cinematic.

const Goblin := preload("res://descent/statue_goblin.gd")
const Devil := preload("res://descent/statue_devil.gd")
const Angel := preload("res://descent/statue_angel.gd")
const Horror := preload("res://descent/statue_horror.gd")
const Man := preload("res://descent/statue_man.gd")

# height as a fraction of the screen, in slot order 1..5
const HEIGHTS: Array[float] = [0.20, 0.50, 0.42, 0.40, 0.27]
const SLOT_X: Array[float] = [0.085, 0.29, 0.5, 0.71, 0.915]

var floor_y := 0.0
var fade := 0.0
var _t := 0.0
var _hot := 0.0
var _busy := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _centre(i: int) -> Vector2:
	return Vector2(size.x * SLOT_X[i], floor_y)


func _goblin_rect() -> Rect2:
	var h := size.y * HEIGHTS[0]
	var c := _centre(0)
	return Rect2(c.x - h * 0.45, c.y - h * 1.05, h * 0.9, h * 1.1)


func _process(delta: float) -> void:
	_t += delta
	size = (get_parent() as Control).size
	var over := not _busy and _goblin_rect().has_point(get_local_mouse_position())
	_hot = move_toward(_hot, 1.0 if over else 0.0, delta * 4.0)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if over else Control.CURSOR_ARROW
	queue_redraw()


func _input(event: InputEvent) -> void:
	if _busy or fade < 0.9:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _goblin_rect().has_point(get_local_mouse_position()):
			_open_goblin()


func _open_goblin() -> void:
	_busy = true
	if ResourceLoader.exists("res://descent/goblin_cinematic.gd"):
		var s: GDScript = load("res://descent/goblin_cinematic.gd")
		await s.call("play", get_parent())
	_busy = false


func _draw() -> void:
	var a := clampf(fade, 0.0, 1.0)
	if a <= 0.0:
		return
	for i in 5:
		var c := _centre(i)
		var h := size.y * HEIGHTS[i]
		# low obsidian plinth: one identical slab per statue keeps the row tidy
		var pw := size.x * 0.17
		var ph := 11.0
		draw_rect(Rect2(c.x - pw * 0.5, c.y - ph, pw, ph), Color(0.035, 0.03, 0.04, a))
		draw_rect(Rect2(c.x - pw * 0.5, c.y - ph, pw, 1.5), Color(0.55, 0.22, 0.1, 0.5 * a))
		c.y -= ph
		# a faint pool of ember light on the glass under each statue
		draw_set_transform(c + Vector2(0, 6), 0.0, Vector2(1.0, 0.16))
		for k in 5:
			draw_circle(Vector2.ZERO, h * (0.62 - k * 0.1), Color(0.5, 0.18, 0.08, 0.035 * a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var hot := _hot if i == 0 else 0.0
		match i:
			0: Goblin.draw(self, c, h, _t, hot)
			1: Devil.draw(self, c, h, _t, 0.0)
			2: Angel.draw(self, c, h, _t, 0.0)
			3: Horror.draw(self, c, h, _t, 0.0)
			4: Man.draw(self, c, h, _t, 0.0)
	# fade the row in with the room
	if a < 1.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 1.0 - a))
