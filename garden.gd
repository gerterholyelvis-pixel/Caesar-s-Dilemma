extends Control

# The garden: where Caesar's Dilemma begins. A parallax world seen side-on. On arrival the camera
# travels through it for about 5 seconds until it reaches a great waterfall, the title pops up,
# and then the camera locks so the world can host the game's mechanics.
#
# Test switches (after `--`):  --cam=0.5   freeze the camera at that progress (no fly-through, no title)
#                              --title     freeze at the end and show the title immediately

signal intro_finished

const SPAN := 3.0                 # how far (in screen heights) the nearest layer travels over the fly-through
const GROUND_Y := 0.80            # UV height of the line characters will stand on (mechanics hook)
const FLY_TIME := 5.2
# back to front; the shader layers use garden_<name>.gdshader. "fx" is the Node2D particle layer.
const LAYERS := [["sky", 0.06], ["mid", 0.30], ["falls", 0.50], ["ground", 1.0], ["fx", 0.0], ["fg", 1.5]]

var mats: Dictionary = {}
var cam := 0.0
var look := Vector2.ZERO
var look_gain := 1.0
var title: Control
var locked := false


func _ready() -> void:
	get_viewport().use_hdr_2d = false
	Hub.boot()
	Hub.audio(get_tree())
	Hub.theme("garden")

	for l in LAYERS:
		var name: String = l[0]
		if name == "fx":
			var fx := Node2D.new()
			fx.set_script(load("res://garden_fx.gd"))
			add_child(fx)
			continue
		var r := ColorRect.new()
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := ShaderMaterial.new()
		m.shader = load("res://garden_%s.gdshader" % name)
		m.set_shader_parameter("span", SPAN)
		m.set_shader_parameter("par", float(l[1]))
		r.material = m
		add_child(r)
		mats[name] = m

	title = Control.new()
	title.set_script(load("res://title.gd"))
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	# arrive out of the warm light we left Limbo in
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.95, 0.85, 1.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(flash.queue_free)

	var args := OS.get_cmdline_user_args()
	var fixed := -1.0
	for a in args:
		if a.begins_with("--cam="):
			fixed = float(a.substr(6))
	if "--title" in args:
		cam = 1.0
		_lock()
		title.play()
	elif fixed >= 0.0:
		cam = fixed
		_lock()
	else:
		_fly()


func _fly() -> void:
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(self, "cam", 1.0, FLY_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_arrive)


func _arrive() -> void:
	title.play()
	# the title is on screen for about 3 seconds in total: ~0.5 s pop-in, ~2.1 s hold, ~0.45 s fade
	await get_tree().create_timer(2.6).timeout
	title.fade_out()
	_lock()
	intro_finished.emit()


# Freeze the world in place: the mouse no longer shifts the camera, so game objects can be placed
# against a background that stays put.
func _lock() -> void:
	locked = true
	create_tween().tween_property(self, "look_gain", 0.0, 0.8)


func ground_y_px() -> float:
	return size.y * GROUND_Y


func _process(delta: float) -> void:
	var m := get_local_mouse_position() / size - Vector2(0.5, 0.5)
	look = look.lerp(m.clamp(Vector2(-0.5, -0.5), Vector2(0.5, 0.5)), 1.0 - exp(-3.0 * delta))
	var aspect := size.x / maxf(size.y, 1.0)
	for k in mats:
		var mt: ShaderMaterial = mats[k]
		mt.set_shader_parameter("aspect", aspect)
		mt.set_shader_parameter("cam", cam)
		mt.set_shader_parameter("look", look * 0.05 * look_gain)
