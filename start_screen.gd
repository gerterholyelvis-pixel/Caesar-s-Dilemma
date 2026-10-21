extends Control

# Compositor for the start screen. Stacks the layers described in CONTRACT.md.

var shader_layers: Array[ShaderMaterial] = []
var layer_nodes: Array[Control] = []
var cloud_vp: SubViewport
var angel_vp: SubViewport
var sigil_vp: SubViewport
var angel_spr: Sprite2D
var sigil_spr: Sprite2D
var angel_px := 1.0
var sigil_px := 1.0
var angel: Node2D
var sigil: Node2D
var sigil_fx: Node2D
var start_btn: Button
var audio: Node
var t := 0.0
var look := Vector2.ZERO


func _ready() -> void:
	var s0 := minf(get_viewport_rect().size.x / 960.0, get_viewport_rect().size.y / 640.0)
	sigil_px = s0
	angel_px = s0 * 1.35
	_make_bloom()

	_add_shader_layer("res://layers/sky_back.gdshader")
	_add_shader_layer("res://layers/celestial.gdshader")
	_add_shader_layer("res://layers/clouds_high.gdshader")
	_add_clouds()

	angel = Node2D.new()
	angel.set_script(load("res://layers/angel.gd"))
	angel.modulate = Color(0.8, 0.8, 0.8, 1.0)
	angel.set("lod", 0.55)
	var b1 := _bake(angel, 165.0, angel_px)   # drawn once per ~3 frames into a texture, not every frame
	angel_vp = b1[0]
	angel_spr = b1[1]

	sigil = Node2D.new()
	sigil.set_script(load("res://sigil.gd"))
	sigil.modulate = Color(1.25, 1.25, 1.45)   # >1 so the bloom picks it up
	var b2 := _bake(sigil, 330.0, sigil_px)
	sigil_vp = b2[0]
	sigil_spr = b2[1]

	sigil_fx = Node2D.new()
	sigil_fx.set_script(load("res://layers/sigil_fx.gd"))
	add_child(sigil_fx)

	var amb := Node2D.new()
	amb.set_script(load("res://layers/ambient_fx.gd"))
	add_child(amb)

	_add_shader_layer("res://layers/post.gdshader", false)

	start_btn = Button.new()
	start_btn.set_script(load("res://layers/start_button.gd"))
	start_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 50)
	add_child(start_btn)

	audio = Node.new()
	audio.set_script(load("res://layers/audio.gd"))
	add_child(audio)
	start_btn.mouse_entered.connect(audio.play_hover)
	start_btn.pressed.connect(func():
		audio.play_click()
		_on_start())

	_layout()
	# fade the whole scene in
	modulate = Color(0, 0, 0, 1)
	create_tween().tween_property(self, "modulate", Color.WHITE, 1.6)
	# profiling hook: `-- --skip=clouds,sigil` hides layers (sky celestial high clouds angel sigil sigilfx ambient post button)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--skip="):
			for nm in a.substr(7).split(","):
				var n: Node = {"sky": layer_nodes[0], "celestial": layer_nodes[1], "high": layer_nodes[2], "clouds": layer_nodes[3],
					"angel": angel, "sigil": sigil, "sigilfx": sigil_fx, "ambient": amb, "post": layer_nodes[4], "button": start_btn}.get(nm)
				if n:
					n.visible = false
	# test hook: `godot --path . -- --autostart` triggers the Start sequence by itself
	if "--autostart" in OS.get_cmdline_user_args():
		get_tree().create_timer(2.0).timeout.connect(_on_start)


func _add_shader_layer(path: String, track := true) -> void:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load(path)
	r.material = m
	add_child(r)
	layer_nodes.append(r)
	if track:
		shader_layers.append(m)


# The raymarched cloud deck is by far the most expensive shader, and clouds are soft anyway, so it
# renders into a half-resolution SubViewport that is scaled up (about 4x fewer pixels to shade).
func _add_clouds() -> void:
	cloud_vp = SubViewport.new()
	cloud_vp.transparent_bg = true
	cloud_vp.disable_3d = true
	cloud_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	cloud_vp.size = Vector2i(480, 320)
	add_child(cloud_vp)
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://layers/clouds.gdshader")
	r.material = m
	cloud_vp.add_child(r)
	shader_layers.append(m)
	var tr := TextureRect.new()
	tr.texture = cloud_vp.get_texture()
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	layer_nodes.append(tr)


# Render an additive Node2D layer into its own HDR texture and show that as a single sprite.
# The node keeps its own (throttled) _draw; the main canvas only has to draw one image per frame
# instead of replaying thousands of line/arc/polygon commands every frame.
func _bake(node: Node2D, radius: float, px: float) -> Array:
	var vp := SubViewport.new()
	var d := int(ceil(radius * 2.0 * px))
	vp.size = Vector2i(d, d)
	vp.transparent_bg = false
	vp.disable_3d = true
	vp.use_hdr_2d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var bg := ColorRect.new()          # opaque black, so additive content adds onto nothing
	bg.color = Color.BLACK
	bg.size = Vector2(d, d)
	vp.add_child(bg)
	node.position = Vector2(d, d) * 0.5
	node.scale = Vector2.ONE * px
	vp.add_child(node)
	var spr := Sprite2D.new()
	spr.texture = vp.get_texture()
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	spr.material = m
	add_child(spr)
	return [vp, spr]


func _make_bloom() -> void:
	get_viewport().use_hdr_2d = true
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.1
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(1, 1.0)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(5, 0.8)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _layout() -> void:
	var aspect := size.x / maxf(size.y, 1.0)
	var half := Vector2i((size * 0.5).round()).clamp(Vector2i(320, 200), Vector2i(1280, 800))
	if cloud_vp and cloud_vp.size != half:
		cloud_vp.size = half
	for m in shader_layers:
		m.set_shader_parameter("aspect", aspect)
		m.set_shader_parameter("look", look * Vector2(-0.05, -0.03))
	var s := minf(size.x / 960.0, size.y / 640.0)
	var base := Vector2(size.x / 2, size.y * 0.40)
	var pos := base + Vector2(look.x * size.x * 0.03, sin(t * 0.8) * 8.0 + look.y * size.y * 0.03)
	sigil_spr.position = pos
	sigil_spr.scale = Vector2.ONE * (s * zoom / sigil_px)
	sigil_fx.position = pos
	sigil_fx.scale = Vector2(s, s) * zoom
	# small distant angel, upper right, drifting gently with a little parallax
	angel_spr.position = Vector2(size.x * 0.85, size.y * 0.21 + sin(t * 0.5) * 5.0) + look * Vector2(size.x, size.y) * 0.012
	angel_spr.scale = Vector2.ONE * (s * 1.35 / angel_px)


func _process(delta: float) -> void:
	t += delta
	var m := get_local_mouse_position() / size - Vector2(0.5, 0.5)
	look = look.lerp(m.clamp(Vector2(-0.5, -0.5), Vector2(0.5, 0.5)), 1.0 - exp(-3.0 * delta))
	if shake > 0.01:
		position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake
	# refresh the baked sigil/angel textures on alternating frames (their scripts redraw on the same frames)
	var fr := Engine.get_process_frames()
	if fr % 3 == 0:
		sigil_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	elif fr % 3 == 1:
		angel_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_layout()


const LIMBO_SCENE := "res://limbo.tscn"

var started := false
var zoom := 1.0     # sigil zoom during the ascent
var shake := 0.0    # screen shake amplitude (px)


# ~3 s cinematic: a great winged angel rises through the clouds and the sigil, the sky blazes
# white, and we are carried into Limbo.
func _on_start() -> void:
	if started:
		return
	started = true
	start_btn.disabled = true
	var s := minf(size.x / 960.0, size.y / 640.0)

	var rising := Node2D.new()
	rising.set_script(load("res://layers/angel.gd"))
	rising.modulate = Color(0.5, 0.5, 0.5, 0.0)
	rising.set("redraw_every", 1)   # full-rate redraw for the cinematic
	rising.position = Vector2(size.x * 0.5, size.y + 280.0 * s)
	rising.scale = Vector2.ONE * s * 1.4
	add_child(rising)
	move_child(rising, start_btn.get_index())   # in front of sigil/fx, behind the button

	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.97, 0.9, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(start_btn, "modulate:a", 0.0, 0.4)
	# the angel climbs up through the screen, slow at first, then surges toward the viewer
	tw.tween_property(rising, "position", Vector2(size.x * 0.5, size.y * 0.40), 2.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(rising, "scale", Vector2.ONE * s * 4.2, 2.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(rising, "modulate:a", 1.0, 0.7)
	tw.tween_property(rising, "spread", 1.7, 2.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# the sigil flares open and dissolves as the angel passes through it
	tw.tween_property(self, "zoom", 2.1, 2.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(sigil, "modulate:a", 0.0, 1.0).set_delay(1.4)
	tw.tween_property(sigil_fx, "modulate:a", 0.0, 1.0).set_delay(1.4)
	# the world trembles
	tw.tween_property(self, "shake", 9.0, 1.8).set_delay(0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# blinding light, then Limbo
	var seq := create_tween()
	seq.tween_interval(2.15)
	seq.tween_property(flash, "color:a", 1.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	seq.tween_callback(func(): get_tree().change_scene_to_file(LIMBO_SCENE))
