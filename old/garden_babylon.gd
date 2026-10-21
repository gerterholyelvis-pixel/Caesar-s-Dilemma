extends Control

# The Hanging Gardens of Babylon: where the game begins. Background shader + living FX, and a
# warm fade-in from the golden flash that carries the player out of Limbo.

var mat: ShaderMaterial
var mat_fg: ShaderMaterial
var look := Vector2.ZERO


func _ready() -> void:
	get_viewport().use_hdr_2d = false

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = load("res://garden.gdshader")
	bg.material = mat
	add_child(bg)

	var fx := Node2D.new()
	fx.set_script(load("res://garden_fx.gd"))
	add_child(fx)

	var fg := ColorRect.new()
	fg.set_anchors_preset(Control.PRESET_FULL_RECT)
	fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat_fg = ShaderMaterial.new()
	mat_fg.shader = load("res://garden_fg.gdshader")
	fg.material = mat_fg
	add_child(fg)

	# arrive out of the same warm light we left Limbo in
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.95, 0.82, 1.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.0, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(flash.queue_free)


func _process(delta: float) -> void:
	var m := get_local_mouse_position() / size - Vector2(0.5, 0.5)
	look = look.lerp(m.clamp(Vector2(-0.5, -0.5), Vector2(0.5, 0.5)), 1.0 - exp(-3.0 * delta))
	mat.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	mat.set_shader_parameter("look", look * 0.06)
	mat_fg.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	mat_fg.set_shader_parameter("look", look * 0.12)   # foreground moves more: parallax
