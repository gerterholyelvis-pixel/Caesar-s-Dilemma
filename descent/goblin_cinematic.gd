extends Control
class_name GoblinCinematic

# GRIK (~47 s, skippable with any key / click): the camera creeps in on the obsidian goblin statue in near-darkness;
# an ember flickers on; the stone cracks and glows from within while ink-and-gold memories of a gravedigger,
# a small black angel in a red hat, and the first fall flash past; the amber eyes open, the stone mouth smirks,
# hard cut to black and one last line. play() is awaitable and frees the node when finished.

const DUR := 47.0
const T_CUT := 42.0
const Audio := preload("res://descent/goblin_audio.gd")
const Art := preload("res://descent/goblin_art.gd")
const NOISE := 256
const MEM := [[14.2, 18.8, 0], [19.8, 24.6, 1], [25.8, 30.6, 2]]
const SPARK_T := [8.6, 14.0, 18.9, 24.9, 31.4, 34.0, 36.4, 39.5]
const LINES := [
	["Not always stone.", 4.6, 8.8, 0],
	["G R I K", 9.8, 14.2, 1],
	["He buried the dead.\nHe kept their coins.", 14.8, 18.7, 0],
	["A small thing in a red hat\noffered him more.", 20.0, 24.4, 0],
	["He took it.\nHe was the first to fall.", 26.0, 30.4, 0],
	["Glass remembers every lie.", 32.0, 37.6, 0],
	["Four more are listening.", 43.4, 46.7, 2]]

## test hooks (goblin_demo)
static var debug_t0 := 0.0
static var debug_noaudio := false

var time := 0.0: set = _set_time

var _ready_done := false
var _vp: SubViewport
var _shown: TextureRect
var _stage: Control
var _glow: Control
var _mem: Control
var _m_fx: ShaderMaterial
var _m_post: ShaderMaterial
var _fade: ColorRect
var _labels: Array = []      # [Label, t_in, t_out, kind]
var _art: RefCounted
var _cs: Cutscene
var _player: AudioStreamPlayer
var _thread: Thread
var _job := {"cancel": false}
var _noise_tex: ImageTexture
var _embers: CPUParticles2D
var _sparks: CPUParticles2D
var _xf := Transform2D.IDENTITY
var _last_t := -1.0
var _lit := 0.0
var _cam := {}


static func play(parent: Node) -> void:
	var c := GoblinCinematic.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	await c.run()
	Hub.theme("")
	Hub.tension(0.0)
	if is_instance_valid(c):
		c.queue_free()


func run() -> void:
	var t0 := debug_t0
	time = t0
	Hub.audio(get_tree())
	Hub.theme("")          # our own score only
	Hub.tension(0.0)
	_cs = Cutscene.new().bind(self)
	_cs.tween(self, "time", DUR, DUR - t0, 0.0, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	_cs.finished.connect(_stop_audio, CONNECT_ONE_SHOT)
	await _cs.play()


func _ready() -> void:
	clip_contents = true
	var nz := FastNoiseLite.new()
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.fractal_type = FastNoiseLite.FRACTAL_FBM
	nz.fractal_octaves = 4
	nz.frequency = 0.012
	nz.seed = 4242
	var img := nz.get_seamless_image(NOISE, NOISE, false, false, 0.1, true)
	img.generate_mipmaps()
	_noise_tex = ImageTexture.create_from_image(img)

	_art = Art.new()
	_art.build(Audio.CRACK_T)

	_vp = SubViewport.new()
	_vp.use_hdr_2d = true
	_vp.disable_3d = true
	_vp.transparent_bg = false
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)

	_stage = Control.new()
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.draw.connect(_draw_stage)
	_vp.add_child(_stage)

	_glow = Control.new()
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_glow.draw.connect(_draw_glow)
	_vp.add_child(_glow)

	var dot := GradientTexture2D.new()
	dot.width = 32
	dot.height = 32
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(0.5, 0.0)
	var gr := Gradient.new()
	gr.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	gr.offsets = PackedFloat32Array([0.0, 1.0])
	dot.gradient = gr
	var life := Gradient.new()
	life.colors = PackedColorArray([Color(1.0, 0.8, 0.5, 0.0), Color(1.0, 0.55, 0.25, 1.0), Color(0.8, 0.2, 0.08, 0.0)])
	life.offsets = PackedFloat32Array([0.0, 0.25, 1.0])

	_embers = CPUParticles2D.new()
	_embers.texture = dot
	_embers.material = add.duplicate()
	_embers.amount = 70
	_embers.lifetime = 12.0
	_embers.preprocess = 12.0
	_embers.speed_scale = 0.7
	_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_embers.direction = Vector2(0, -1)
	_embers.spread = 30.0
	_embers.gravity = Vector2(0, -3)
	_embers.initial_velocity_min = 16.0
	_embers.initial_velocity_max = 50.0
	_embers.scale_amount_min = 0.06
	_embers.scale_amount_max = 0.22
	_embers.color = Color(2.4, 1.0, 0.28)
	_embers.color_ramp = life
	_vp.add_child(_embers)

	_sparks = CPUParticles2D.new()
	_sparks.texture = dot
	_sparks.material = add.duplicate()
	_sparks.amount = 36
	_sparks.lifetime = 2.6
	_sparks.one_shot = true
	_sparks.emitting = false
	_sparks.explosiveness = 0.92
	_sparks.speed_scale = 0.55
	_sparks.direction = Vector2(0, -1)
	_sparks.spread = 80.0
	_sparks.gravity = Vector2(0, 60)
	_sparks.initial_velocity_min = 60.0
	_sparks.initial_velocity_max = 260.0
	_sparks.damping_min = 40.0
	_sparks.damping_max = 90.0
	_sparks.scale_amount_min = 0.03
	_sparks.scale_amount_max = 0.10
	_sparks.color = Color(3.0, 1.6, 0.5)
	_sparks.color_ramp = life
	_vp.add_child(_sparks)

	_mem = Control.new()
	_mem.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mem.draw.connect(_draw_mem)
	_vp.add_child(_mem)

	var fx := ColorRect.new()
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_m_fx = _mat("res://descent/goblin_fx.gdshader")
	fx.material = _m_fx
	_vp.add_child(fx)

	var post := ColorRect.new()
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_m_post = _mat("res://descent/goblin_post.gdshader")
	post.material = _m_post
	_vp.add_child(post)

	_shown = TextureRect.new()
	_shown.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shown.stretch_mode = TextureRect.STRETCH_SCALE
	_shown.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_shown.texture = _vp.get_texture()
	add_child(_shown)

	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	for l in LINES:
		_add_line(l[0], l[1], l[2], l[3])

	resized.connect(_on_resized)
	_on_resized.call_deferred()
	_ready_done = true
	_apply(time)
	if not debug_noaudio:
		_thread = Thread.new()
		_thread.start(_bake_audio)


func _mat(path: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	m.set_shader_parameter("noise_tex", _noise_tex)
	return m


func _add_line(txt: String, t_in: float, t_out: float, kind: int) -> void:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Palatino Linotype", "Book Antiqua", "Garamond", "Georgia", "Times New Roman", "serif"])
	f.font_italic = kind != 1
	f.font_weight = 700 if kind == 1 else 400
	l.add_theme_font_override("font", f)
	var col := Color(0.93, 0.86, 0.76)
	if kind == 1:
		col = Color(0.96, 0.78, 0.38)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 8)
	l.add_theme_constant_override("outline_size", 2)
	l.modulate.a = 0.0
	add_child(l)
	_labels.append([l, t_in, t_out, kind])


func _on_resized() -> void:
	if _vp == null:
		return
	var s := Vector2i((size * 0.85).round())
	s = Vector2i(maxi(s.x, 160), maxi(s.y, 100))
	_vp.size = s
	_embers.position = Vector2(s.x * 0.5, s.y * 1.04)
	_embers.emission_rect_extents = Vector2(s.x * 0.62, 8.0)
	_embers.scale_amount_min = 0.06 * s.y / 700.0
	_embers.scale_amount_max = 0.22 * s.y / 700.0
	_embers.initial_velocity_min = 16.0 * s.y / 700.0
	_embers.initial_velocity_max = 50.0 * s.y / 700.0
	_embers.restart()
	for e in _labels:
		var l: Label = e[0]
		var fs := int(size.y * (0.12 if e[3] == 1 else 0.052))
		l.add_theme_font_size_override("font_size", maxi(fs, 14))
	_apply(time)


func _set_time(v: float) -> void:
	time = v
	if _ready_done:
		_apply(v)


func _ss(a: float, b: float, x: float) -> float:
	return smoothstep(a, b, x)


## ember light: stuttering ignition (matches the audio pops), then a living flicker that strengthens as the glass heats
func _light(t: float) -> float:
	var pulse := 0.0
	for p in Audio.FLICKER:
		pulse = maxf(pulse, _ss(p, p + 0.03, t) * (1.0 - _ss(p + 0.10, p + 0.17, t)))
	var steady := _ss(4.0, 5.5, t)
	var fl := 0.80 + 0.10 * sin(t * 7.3) + 0.06 * sin(t * 13.1 + 1.0) + 0.05 * sin(t * 29.7 + 2.0) + 0.04 * sin(t * 51.0)
	var base := 0.55 + 0.45 * _ss(5.0, 34.0, t)
	return maxf(pulse * 0.75, steady * fl * base)


func _apply(t: float) -> void:
	var vs := _vp.size
	var aspect := vs.x / vs.y
	var I := _light(t)
	# eyes light the face once open
	var eye := _ss(33.6, 36.2, t) * (1.0 - 0.9 * exp(-pow((t - 37.3) / 0.07, 2.0)))
	var smirk := _ss(38.2, 40.6, t)
	I += 0.35 * eye
	_lit = I
	var hot := _ss(8.6, 40.0, t) * 0.85
	var heat := 0.2 + 0.8 * _ss(9.0, 36.0, t) - 0.5 * _ss(37.4, 39.4, t)

	# camera: slow creep + two committed pushes (the eyes, the mouth)
	var zoom := 0.84 + 0.36 * (t / 33.0) + 0.36 * _ss(33.0, 35.4, t) + 0.34 * _ss(37.6, 39.4, t)
	var fy := lerpf(150.0, 0.0, clampf(t / 33.0, 0.0, 1.0)) - 42.0 * _ss(33.0, 34.8, t) + 190.0 * _ss(37.6, 38.9, t)
	var fx := 10.0 * sin(t * 0.21) + 4.0 * sin(t * 0.53)
	var roll := 0.014 * sin(t * 0.13) + 0.004 * sin(t * 0.47)
	var shk := Vector2.ZERO
	for ct in Audio.CRACK_T:
		if t > ct and t < ct + 0.8:
			var k := exp(-(t - ct) * 9.0)
			shk += Vector2(sin(t * 83.0 + ct), cos(t * 97.0 + ct * 2.0)) * 6.0 * k
	var s := vs.y / 1000.0 * zoom
	_xf = Transform2D(roll, Vector2(vs) * 0.5 + shk * s) * Transform2D.IDENTITY.scaled(Vector2(s, s)) * Transform2D.IDENTITY.translated(-Vector2(fx, fy))
	_cam = {"s": s}

	var a: Object = _art
	a.set("t", t)
	a.set("lit", I)
	a.set("lpos", Vector2(-300.0 + 26.0 * sin(t * 3.1) + 14.0 * sin(t * 8.7), 420.0 + 18.0 * cos(t * 2.3)))
	a.set("hot", hot)
	a.set("crack_heat", heat)
	a.set("eye", eye)
	a.set("smirk", smirk)
	a.set("mouth_glow", _ss(38.0, 40.0, t) * 0.8 + hot * 0.08)

	# flashes: each memory's birth, each crack, the cut
	var flash := 0.0
	for m in MEM:
		if t >= m[0]:
			flash = maxf(flash, 0.55 * exp(-(t - m[0]) * 7.0))
	for ct in Audio.CRACK_T:
		if t >= ct:
			flash = maxf(flash, 0.12 * exp(-(t - ct) * 14.0))
	flash = maxf(flash, 1.6 * _ss(41.78, 42.0, t) * (1.0 - _ss(42.0, 42.001, t)))
	flash = maxf(flash, 0.5 * exp(-pow((t - 34.6) / 0.25, 2.0)))

	var x := _m_fx
	x.set_shader_parameter("T", t)
	x.set_shader_parameter("aspect", aspect)
	var lp_uv := Vector2(0.28, 1.12)
	x.set_shader_parameter("lpos", lp_uv)
	x.set_shader_parameter("haze", (0.25 + 0.75 * _ss(3.0, 12.0, t)) * (0.4 + 0.3 * heat) * (1.0 - _ss(T_CUT - 0.05, T_CUT, t)))
	x.set_shader_parameter("embers", (0.25 + 0.75 * _ss(1.0, 7.0, t)) * (0.45 + 0.55 * I) * (1.0 - _ss(T_CUT - 0.05, T_CUT, t)))
	x.set_shader_parameter("flick", clampf(I, 0.0, 1.3))
	x.set_shader_parameter("rays", _ss(5.0, 14.0, t) * (0.5 + 0.5 * heat))
	x.set_shader_parameter("zoom", zoom)
	x.set_shader_parameter("pan", Vector2(fx, fy) * 0.001)

	var p := _m_post
	p.set_shader_parameter("T", t)
	p.set_shader_parameter("shimmer", 0.0016 + 0.0030 * heat * _ss(6.0, 20.0, t))
	p.set_shader_parameter("aberr", 0.0018 + 0.0045 * _ss(33.0, 36.0, t) + 0.01 * flash * 0.5)
	p.set_shader_parameter("bloom", 0.26 + 0.30 * eye + 0.10 * hot)
	p.set_shader_parameter("vig", 0.62 + 0.20 * _ss(30.0, 42.0, t))
	p.set_shader_parameter("grain", 0.07)
	p.set_shader_parameter("expo", 1.0 + 0.18 * I)
	p.set_shader_parameter("flash", flash)
	p.set_shader_parameter("aspect", aspect)
	p.set_shader_parameter("lpos", lp_uv)

	# slow-mo spark bursts at the cracks
	if _last_t >= 0.0 and t > _last_t and t - _last_t < 0.3 and t < T_CUT:
		for st in SPARK_T:
			if _last_t < st and t >= st:
				var f := Vector2(randf_range(-140.0, 140.0), randf_range(-160.0, 220.0))
				_sparks.position = _xf * f
				_sparks.restart()
				_sparks.emitting = true
	_last_t = t
	_embers.modulate.a = (0.3 + 0.7 * I) * (1.0 - _ss(T_CUT - 0.05, T_CUT, t))

	_stage.queue_redraw()
	_glow.queue_redraw()
	var mem_a := 0.0
	for m in MEM:
		mem_a = maxf(mem_a, _ss(m[0], m[0] + 0.6, t) * (1.0 - _ss(m[1] - 0.8, m[1], t)))
	_glow.modulate.a = 1.0 - 0.92 * mem_a
	_mem.queue_redraw()

	_fade.color = Color(0.0, 0.0, 0.0, maxf(1.0 - _ss(0.0, 1.6, t), 1.0 if t >= T_CUT else 0.0))
	for e in _labels:
		var l: Label = e[0]
		var t_in: float = e[1]
		var t_out: float = e[2]
		var kind: int = e[3]
		var txt_len := l.text.length()
		var ink := clampf((t - t_in) / (0.8 + 0.05 * txt_len), 0.0, 1.0)
		l.visible_ratio = ink
		l.modulate.a = _ss(t_in, t_in + 0.5, t) * (1.0 - _ss(t_out - 1.1, t_out, t)) * (0.95 if kind != 1 else 1.0)
		var lines := l.text.count("\n") + 1
		var fs := float(l.get_theme_font_size("font_size"))
		l.size = Vector2(size.x, fs * 1.4 * lines)
		var y := size.y * 0.89 - fs * 1.32 * lines
		if kind == 1:
			y = size.y * 0.05
		elif kind == 2:
			y = size.y * 0.47 - fs * 0.6
		l.position = Vector2(0.0, y - 4.0 * (t - t_in) * 0.3)


func _draw_stage() -> void:
	var vs := _vp.size
	var I := _lit
	# the dark behind: near-black, a last ember-red glow on the floor
	var floor_c := Color(0.045, 0.012, 0.006) * (0.2 + 0.9 * I)
	floor_c.a = 1.0
	_stage.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(vs.x, 0), Vector2(vs.x, vs.y), Vector2(0, vs.y)]),
		PackedColorArray([Color(0.002, 0.002, 0.004), Color(0.002, 0.002, 0.004), floor_c, floor_c]))
	_stage.draw_set_transform_matrix(_xf)
	_art.draw_backdrop(_stage)
	_art.draw_bust(_stage)
	_art.draw_cracks_dark(_stage)
	_stage.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_glow() -> void:
	_glow.draw_set_transform_matrix(_xf)
	_art.draw_glow(_glow)
	_glow.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_mem() -> void:
	var t := time
	var vs := _vp.size
	for m in MEM:
		var a := _ss(m[0], m[0] + 0.6, t) * (1.0 - _ss(m[1] - 0.8, m[1], t))
		if a <= 0.001:
			continue
		_mem.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.006, 0.004, 0.006, 0.93 * a))
		var p := clampf((t - m[0]) / (m[1] - m[0]), 0.0, 1.0)
		_art.draw_memory(_mem, m[2], p, a, Vector2(vs.x * 0.5, vs.y * 0.44), vs.y * 0.36 / 300.0)
		# slow ink-and-gold jitter: a faint second pass offset a hair for a printed look
	_mem.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- audio ------------------------------------------------------------------------------------
func _bake_audio() -> AudioStreamWAV:
	return Audio.bake(_job)


func _process(_d: float) -> void:
	if _thread != null and _player == null and _thread.is_started() and not _thread.is_alive():
		var st: AudioStreamWAV = _thread.wait_to_finish()
		_thread = null
		if st != null and not _job.cancel and is_inside_tree():
			_player = AudioStreamPlayer.new()
			_player.stream = st
			_player.volume_db = -6.0
			add_child(_player)
			_player.play(clampf(time, 0.0, DUR - 0.1))


func _stop_audio() -> void:
	_job.cancel = true
	if _player != null and is_instance_valid(_player):
		_player.stop()


func _exit_tree() -> void:
	_job.cancel = true
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
		_thread = null
