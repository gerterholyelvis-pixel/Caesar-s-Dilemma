extends Control

# THE OBSIDIAN DEEP: bottom of hell, where the new game starts. A calm, fixed, very low-lit cavern
# of black volcanic glass. Later game objects go on the floor at GROUND_Y.

const GROUND_Y := 0.80
const FADE_TIME := 3.0

var parallax_enabled := true

var _mat: ShaderMaterial
var _rect: ColorRect
var _t := 0.0
var _par := Vector2.ZERO
var _row: Control

func ground_y_px() -> float:
	return size.y * GROUND_Y

func _ready() -> void:
	Hub.theme("")   # the deep is silent: no music at all
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://descent/obsidian_deep.gdshader")
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	add_child(_rect)
	_mat.set_shader_parameter("fade", 0.0)
	_row = load("res://descent/statue_row.gd").new()
	add_child(_row)

func _process(delta: float) -> void:
	_t += delta
	var f := clampf(_t / FADE_TIME, 0.0, 1.0)
	f = f * f * (3.0 - 2.0 * f)
	var flick := 0.88 + 0.08 * sin(_t * 0.7) + 0.04 * sin(_t * 2.3 + 1.0) + 0.02 * sin(_t * 7.1)
	var target := Vector2.ZERO
	if parallax_enabled and is_inside_tree():
		var vs := get_viewport_rect().size
		var m := get_viewport().get_mouse_position()
		if vs.x > 0.0 and vs.y > 0.0:
			target = ((m / vs) - Vector2(0.5, 0.5)).clampf(-0.5, 0.5) * 0.04
	_par = _par.lerp(target, clampf(delta * 2.0, 0.0, 1.0))
	_mat.set_shader_parameter("fade", f)
	_mat.set_shader_parameter("flick", flick)
	_mat.set_shader_parameter("t_now", _t)
	_mat.set_shader_parameter("par", _par)
	_row.floor_y = size.y * (GROUND_Y + 0.05)
	_row.fade = clampf((_t - 1.5) / 3.0, 0.0, 1.0)
