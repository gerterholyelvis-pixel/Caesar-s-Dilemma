extends Control
class_name GoblinCinematic

# GRIK (~84 s, 72 bpm, skippable with any key / click). See GOBLIN_STORY.md.
#  I   ARRIVAL     0-22   black, ember pops, wide blurred establishing shot, slow dolly + rack focus, title card
#  II  AWAKENING  22-36   the glass cracks, slow-mo spark beats, heat; the camera breathes
#  III MEMORIES   36-63   grave (iris) / offer (letterbox) / fall (tall window) / the glass (five sigils); cracks between
#  IV  CONFRONT   63-74   match cut glint -> eyes, locked-off camera, rack to the mouth, smirk, hard cut
#  V   CODA       74-84   silence, a bell, "Four more are listening.", five sigils, one red point
# play() is awaitable and frees the node when finished.

const DUR := 84.0
const T_CUT := 74.0
const BEAT := 60.0 / 72.0
const Audio := preload("res://descent/goblin_audio.gd")
const Art := preload("res://descent/goblin_art.gd")
const NOISE := 256
const FLICKER: Array = [2.6, 2.95, 3.1, 3.7, 3.85, 4.4]
## art crack k uses time k: twelve in the awakening, one after each of the first three memories, two before the eyes
const CRACK_T: Array = [20.83, 21.67, 22.5, 24.17, 25.0, 26.67, 27.5, 28.33, 30.0, 30.83, 31.67, 33.33, 42.5, 49.17, 55.83, 62.5, 63.33]
const SPARK_T := [22.0, 27.8, 31.2, 34.6, 64.17, 70.0]
## memory windows [start, end, kind]; each is seven beats, and a crack lands on the beat it ends
const MEM := [[36.67, 42.5, 0], [43.33, 49.17, 1], [50.0, 55.83, 2], [56.67, 62.5, 3]]
const LINES := [
	["Not always stone.", 8.33, 12.5, 0],
	["G R I K", 12.5, 19.17, 1],
	["Stone is only a held breath.", 22.5, 26.5, 0],
	["He still feels the weight\nof every coin.", 28.33, 32.6, 0],
	["He buried the dead.\nHe kept their coins.", 37.2, 41.8, 0],
	["A small thing in a red hat\noffered him more.", 43.9, 48.5, 0],
	["He took it.\nHe was the first to fall.", 50.6, 55.1, 0],
	["Glass remembers every lie.", 57.3, 61.8, 0],
	["He knows what the coin costs.", 67.6, 72.0, 0],
	["Four more are listening.", 76.4, 81.6, 2]]
const CAM_Z := [[0.0, 0.62], [12.0, 0.72], [22.0, 0.86], [36.0, 1.16], [46.0, 1.24], [56.0, 1.34], [62.5, 1.56], [65.4, 1.56], [68.4, 1.58], [70.8, 1.92], [74.0, 2.0]]
const CAM_Y := [[0.0, 200.0], [12.0, 182.0], [22.0, 150.0], [36.0, 40.0], [56.0, 10.0], [62.5, -42.0], [65.4, -42.0], [68.4, -42.0], [70.8, 148.0], [74.0, 150.0]]

## test hooks (goblin_demo)
static var debug_t0 := 0.0
static var debug_noaudio := false

var time := 0.0: set = _set_time

var _ready_done := false
var _vp: SubViewport
var _shown: TextureRect
var _ghosts: Array = []
var _stage: Control
var _glow: Control
var _mem: Control
var _coda: Control
var _m_fx: ShaderMaterial
var _m_post: ShaderMaterial
var _fade: ColorRect
var _bar_t: ColorRect
var _bar_b: ColorRect
var _labels: Array = []      # [Label, t_in, t_out, kind, FontVariation]
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
	_art.build(CRACK_T)

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
	_sparks.lifetime = 3.4
	_sparks.one_shot = true
	_sparks.emitting = false
	_sparks.explosiveness = 0.92
	_sparks.speed_scale = 0.4            # slow-mo tails
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

	_shown = _new_view()
	add_child(_shown)
	# rack-focus: six ghost copies of the frame, averaged, are a cheap lens defocus
	for i in 6:
		var g := _new_view()
		g.visible = false
		add_child(g)
		_ghosts.append(g)

	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	_coda = Control.new()
	_coda.set_anchors_preset(Control.PRESET_FULL_RECT)
	_coda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coda.draw.connect(_draw_coda)
	add_child(_coda)

	_bar_t = ColorRect.new()
	_bar_t.color = Color.BLACK
	_bar_t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar_t)
	_bar_b = ColorRect.new()
	_bar_b.color = Color.BLACK
	_bar_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar_b)

	for l in LINES:
		_add_line(l[0], l[1], l[2], l[3])

	resized.connect(_on_resized)
	_on_resized.call_deferred()
	_ready_done = true
	_apply(time)
	if not debug_noaudio:
		_thread = Thread.new()
		_thread.start(_bake_audio)


func _new_view() -> TextureRect:
	var v := TextureRect.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v.stretch_mode = TextureRect.STRETCH_SCALE
	v.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	v.texture = _vp.get_texture()
	v.set_anchors_preset(Control.PRESET_TOP_LEFT)
	return v


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
	var fv := FontVariation.new()
	fv.base_font = f
	l.add_theme_font_override("font", fv)
	var col := Color(0.93, 0.86, 0.76)
	if kind == 1:
		col = Color(0.96, 0.78, 0.38)
	elif kind == 2:
		col = Color(0.95, 0.80, 0.70)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 8)
	l.add_theme_constant_override("outline_size", 2)
	l.modulate.a = 0.0
	add_child(l)
	_labels.append([l, t_in, t_out, kind, fv])


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


## smooth (cardinal Hermite) curve through [t, v] keys: continuous velocity, so a dolly never stops and starts
func _kf(t: float, keys: Array) -> float:
	var n := keys.size()
	if t <= keys[0][0]:
		return keys[0][1]
	if t >= keys[n - 1][0]:
		return keys[n - 1][1]
	var i := 0
	while keys[i + 1][0] < t:
		i += 1
	var t0: float = keys[i][0]
	var t1: float = keys[i + 1][0]
	var v0: float = keys[i][1]
	var v1: float = keys[i + 1][1]
	var m0 := 0.0
	var m1 := 0.0
	if i > 0:
		m0 = (v1 - float(keys[i - 1][1])) / (t1 - float(keys[i - 1][0]))
	if i + 2 < n:
		m1 = (float(keys[i + 2][1]) - v0) / (float(keys[i + 2][0]) - t0)
	var h := t1 - t0
	var u := (t - t0) / h
	var u2 := u * u
	var u3 := u2 * u
	return (2.0 * u3 - 3.0 * u2 + 1.0) * v0 + (u3 - 2.0 * u2 + u) * h * m0 + (-2.0 * u3 + 3.0 * u2) * v1 + (u3 - u2) * h * m1


func _bump(t: float, a: float, b: float, c: float, d: float) -> float:
	return _ss(a, b, t) * (1.0 - _ss(c, d, t))


## ember light: stuttering ignition, then a living flicker that strengthens as the glass heats
func _light(t: float) -> float:
	var pulse := 0.0
	for p in FLICKER:
		pulse = maxf(pulse, _ss(p, p + 0.03, t) * (1.0 - _ss(p + 0.10, p + 0.17, t)))
	var steady := _ss(4.8, 6.5, t)
	var fl := 0.80 + 0.10 * sin(t * 7.3) + 0.06 * sin(t * 13.1 + 1.0) + 0.05 * sin(t * 29.7 + 2.0) + 0.04 * sin(t * 51.0)
	var base := 0.5 + 0.5 * _ss(6.0, 40.0, t)
	return maxf(pulse * 0.75, steady * fl * base)


func _beat_ramp(t: float) -> float:
	return _ss(20.0, 26.0, t) * (1.0 - _ss(62.4, 63.2, t)) + 0.9 * _ss(64.6, 66.0, t) * (1.0 - _ss(73.6, 74.0, t))


func _apply(t: float) -> void:
	var vs := _vp.size
	var aspect := vs.x / vs.y
	var bp := exp(-fmod(t, BEAT) * 5.0) * _beat_ramp(t)     # the 72 bpm heart
	# the held silence before the eyes: light drains, then ignites
	var dip := 1.0 - 0.45 * _bump(t, 62.5, 62.9, 63.9, 64.5)
	var I := _light(t) * dip
	I += 0.10 * bp
	var eye := _ss(64.17, 66.7, t) * (1.0 - 0.9 * exp(-pow((t - 67.9) / 0.07, 2.0)))
	var smirk := _ss(69.17, 71.67, t)
	I += 0.35 * eye
	_lit = I
	var hot := _ss(20.83, 70.0, t) * 0.85
	var heat := 0.2 + 0.8 * _ss(21.0, 62.0, t) - 0.5 * _ss(68.0, 71.0, t)

	# camera: continuous dolly (keyframed), handheld that dies when his eyes open, beat kicks, crack shake
	var hh := 1.0 - 0.94 * _ss(62.4, 63.6, t) + 0.5 * _ss(69.5, 70.6, t)
	var zoom := _kf(t, CAM_Z) * (1.0 + 0.004 * bp)
	var fy := _kf(t, CAM_Y)
	var fx := hh * (12.0 * sin(t * 0.21) + 5.0 * sin(t * 0.53) + 1.6 * sin(t * 1.9 + 1.0))
	fy += hh * (4.0 * sin(t * 0.37 + 0.5) + 1.4 * sin(t * 1.3))
	var roll := hh * (0.014 * sin(t * 0.13) + 0.004 * sin(t * 0.47) + 0.0015 * sin(t * 1.7))
	var shk := Vector2.ZERO
	for ct in CRACK_T:
		if t > ct and t < ct + 1.0:
			var k := exp(-(t - ct) * 6.0)
			shk += Vector2(sin(t * 83.0 + ct), cos(t * 97.0 + ct * 2.0)) * 6.0 * k
			zoom *= 1.0 + 0.010 * k
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
	a.set("mouth_glow", _ss(69.5, 71.5, t) * 0.8 + hot * 0.08)

	# flashes: each memory's birth, each crack, the match cut, the eyes, the cut
	var flash := 0.0
	for m in MEM:
		if t >= m[0]:
			flash = maxf(flash, 0.55 * exp(-(t - m[0]) * 7.0))
	for ct in CRACK_T:
		if t >= ct:
			flash = maxf(flash, 0.12 * exp(-(t - ct) * 14.0))
	flash = maxf(flash, 0.5 * exp(-pow((t - 62.55) / 0.12, 2.0)))
	flash = maxf(flash, 0.4 * exp(-pow((t - 64.3) / 0.3, 2.0)))
	flash = maxf(flash, 1.6 * _ss(T_CUT - 0.22, T_CUT, t) * (1.0 - _ss(T_CUT, T_CUT + 0.001, t)))

	var cut := 1.0 - _ss(T_CUT - 0.05, T_CUT, t)
	var x := _m_fx
	x.set_shader_parameter("T", t)
	x.set_shader_parameter("aspect", aspect)
	var lp_uv := Vector2(0.28, 1.12)
	x.set_shader_parameter("lpos", lp_uv)
	x.set_shader_parameter("haze", (0.25 + 0.75 * _ss(3.0, 14.0, t)) * (0.4 + 0.3 * heat) * cut)
	x.set_shader_parameter("embers", (0.25 + 0.75 * _ss(1.0, 8.0, t)) * (0.45 + 0.55 * I) * cut)
	x.set_shader_parameter("flick", clampf(I, 0.0, 1.3))
	x.set_shader_parameter("rays", _ss(6.0, 18.0, t) * (0.5 + 0.5 * heat))
	x.set_shader_parameter("zoom", zoom)
	x.set_shader_parameter("pan", Vector2(fx, fy) * 0.001)

	var p := _m_post
	p.set_shader_parameter("T", t)
	p.set_shader_parameter("shimmer", 0.0016 + 0.0030 * heat * _ss(6.0, 24.0, t))
	p.set_shader_parameter("aberr", 0.0018 + 0.0045 * _ss(63.0, 66.0, t) + 0.01 * flash * 0.5)
	p.set_shader_parameter("bloom", 0.26 + 0.30 * eye + 0.10 * hot)
	p.set_shader_parameter("vig", 0.66 - 0.06 * _ss(3.0, 14.0, t) + 0.20 * _ss(55.0, 70.0, t))
	p.set_shader_parameter("grain", 0.07)
	p.set_shader_parameter("expo", 1.0 + 0.18 * I)
	p.set_shader_parameter("flash", flash)
	p.set_shader_parameter("aspect", aspect)
	p.set_shader_parameter("lpos", lp_uv)

	# slow-mo spark bursts
	if _last_t >= 0.0 and t > _last_t and t - _last_t < 0.3 and t < T_CUT:
		for st in SPARK_T:
			if _last_t < st and t >= st:
				var f := Vector2(randf_range(-140.0, 140.0), randf_range(-160.0, 220.0))
				_sparks.position = _xf * f
				_sparks.restart()
				_sparks.emitting = true
	_last_t = t
	_embers.modulate.a = (0.3 + 0.7 * I) * cut

	_stage.queue_redraw()
	_glow.queue_redraw()
	var mem_a := 0.0
	for m in MEM:
		mem_a = maxf(mem_a, _ss(m[0], m[0] + 0.6, t) * (1.0 - _ss(m[1] - 0.8, m[1], t)))
	_glow.modulate.a = 1.0 - 0.92 * mem_a
	_mem.queue_redraw()
	_coda.queue_redraw()

	# rack focus (px of defocus): establishing pull, title, memories, the held breath, eyes -> mouth
	var blur := 9.0 * (1.0 - _ss(4.0, 11.0, t))
	blur += 3.0 * _bump(t, 12.5, 14.0, 18.0, 19.17)
	blur += 4.0 * mem_a
	blur += 9.0 * _ss(62.5, 62.6, t) * (1.0 - _ss(63.4, 65.2, t))
	blur += 6.0 * _bump(t, 69.0, 69.7, 69.9, 71.2)
	var br := blur * size.y / 700.0
	_shown.position = Vector2.ZERO
	_shown.size = size
	for i in _ghosts.size():
		var g: TextureRect = _ghosts[i]
		g.visible = br > 0.4
		if g.visible:
			g.position = Vector2.from_angle(i * TAU / 6.0 + 0.4) * br * (0.55 + 0.45 * float(i % 2))
			g.size = size
			g.modulate.a = 1.0 / float(i + 2)

	_fade.color = Color(0.0, 0.0, 0.0, maxf(1.0 - _ss(0.3, 3.0, t), 1.0 if t >= T_CUT else 0.0))
	var bh := size.y * (0.06 + 0.025 * _ss(62.5, 70.0, t))
	_bar_t.position = Vector2.ZERO
	_bar_t.size = Vector2(size.x, bh)
	_bar_b.position = Vector2(0.0, size.y - bh)
	_bar_b.size = Vector2(size.x, bh)

	for e in _labels:
		var l: Label = e[0]
		var t_in: float = e[1]
		var t_out: float = e[2]
		var kind: int = e[3]
		var life := t_out - t_in
		if t < t_in - 0.2 or t > t_out + 0.2:
			l.modulate.a = 0.0
			continue
		var txt_len := l.text.length()
		var ink := clampf((t - t_in) / (0.8 + 0.05 * txt_len), 0.0, 1.0)
		l.visible_ratio = ink
		var fade_in := 0.5 if kind == 0 else 1.2
		l.modulate.a = _ss(t_in, t_in + fade_in, t) * (1.0 - _ss(t_out - 1.1, t_out, t)) * (0.95 if kind != 1 else 1.0)
		var lines := l.text.count("\n") + 1
		var fs := float(l.get_theme_font_size("font_size"))
		# kerning: letters drift apart as the line lives (the title opens like a held breath)
		var u := clampf((t - t_in) / life, 0.0, 1.0)
		var track := 0.0
		if kind == 1:
			track = fs * lerpf(0.02, 0.26, _ss(0.0, 1.0, u))
		elif kind == 2:
			track = fs * lerpf(0.0, 0.07, u)
		else:
			track = fs * lerpf(0.0, 0.035, u)
		var fv: FontVariation = e[4]
		if absf(fv.spacing_glyph - track) >= 1.0:
			fv.spacing_glyph = int(track)
		l.size = Vector2(size.x, fs * 1.4 * lines)
		var y := size.y * 0.855 - fs * 1.32 * lines
		if kind == 1:
			y = size.y * 0.115
		elif kind == 2:
			y = size.y * 0.40 - fs * 0.6
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


# --- memories ---------------------------------------------------------------------------------
func _draw_mem() -> void:
	var t := time
	var vs := _vp.size
	var gold := Art.GOLD
	# title glyph: the broken triangle that contains itself
	var ta := _bump(t, 12.8, 14.6, 18.0, 19.17)
	if ta > 0.002:
		var c := Vector2(vs.x * 0.5, vs.y * 0.205)
		var r := vs.y * 0.19 * (0.94 + 0.06 * _ss(12.5, 19.0, t))
		var depth := 1 + int(3.0 * _ss(13.0, 16.5, t))
		_sierp(_mem, c, r, depth, t * 0.06, Color(gold.r, gold.g, gold.b, 0.32 * ta), 1.4)
		_mem.draw_circle(c, r * 0.9, Color(1.0, 0.6, 0.2, 0.025 * ta))
	for m in MEM:
		var a := _ss(m[0], m[0] + 0.6, t) * (1.0 - _ss(m[1] - 0.8, m[1], t))
		if a <= 0.001:
			continue
		var p := clampf((t - m[0]) / (m[1] - m[0]), 0.0, 1.0)
		var open := _ss(m[0], m[0] + 0.9, t)
		var wob := Vector2(sin(t * 1.3), cos(t * 1.7)) * vs.y * 0.004
		match int(m[2]):
			0:    # iris: the circle of a lantern, pushing in
				_mem.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.006, 0.004, 0.006, 0.93 * a))
				var c := Vector2(vs.x * 0.5, vs.y * 0.44) + wob
				var sc := vs.y * 0.36 / 300.0 * (1.0 + 0.14 * p)
				_art.draw_memory(_mem, 0, p, a, c, sc)
				_mem.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				_mem.draw_arc(c, 330.0 * sc * (0.2 + 0.8 * open) + 1200.0, 0.0, TAU, 128, Color(0.004, 0.003, 0.005, a), 2400.0)
			1:    # letterbox: the offer, close and wide, a slow lateral slide
				_mem.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.006, 0.004, 0.006, 0.97 * a))
				var c1 := Vector2(vs.x * (0.58 - 0.16 * p), vs.y * 0.6) + wob
				var sc1 := vs.y * 0.5 / 300.0
				_art.draw_memory(_mem, 1, p, a, c1, sc1)
				_mem.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				var bh := vs.y * (0.5 - 0.30 * open)
				_mem.draw_rect(Rect2(0, 0, vs.x, bh), Color(0.0, 0.0, 0.0, a))
				_mem.draw_rect(Rect2(0, vs.y - bh, vs.x, bh), Color(0.0, 0.0, 0.0, a))
				_mem.draw_line(Vector2(0, bh), Vector2(vs.x, bh), Color(gold.r, gold.g, gold.b, 0.5 * a), 1.5)
				_mem.draw_line(Vector2(0, vs.y - bh), Vector2(vs.x, vs.y - bh), Color(gold.r, gold.g, gold.b, 0.5 * a), 1.5)
			2:    # tall window: the fall, slides in from the sides
				_mem.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.006, 0.004, 0.006, 0.97 * a))
				var c2 := Vector2(vs.x * 0.5, vs.y * (0.5 + 0.03 * (0.5 - p))) + wob
				var sc2 := vs.y * 0.52 / 320.0
				_art.draw_memory(_mem, 2, p, a, c2, sc2)
				_mem.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				var hw := vs.y * (0.30 + 0.9 * (1.0 - open))
				_mem.draw_rect(Rect2(0, 0, vs.x * 0.5 - hw, vs.y), Color(0.0, 0.0, 0.0, a))
				_mem.draw_rect(Rect2(vs.x * 0.5 + hw, 0, vs.x * 0.5 - hw, vs.y), Color(0.0, 0.0, 0.0, a))
				_mem.draw_line(Vector2(vs.x * 0.5 - hw, 0), Vector2(vs.x * 0.5 - hw, vs.y), Color(gold.r, gold.g, gold.b, 0.5 * a), 1.5)
				_mem.draw_line(Vector2(vs.x * 0.5 + hw, 0), Vector2(vs.x * 0.5 + hw, vs.y), Color(gold.r, gold.g, gold.b, 0.5 * a), 1.5)
			3:
				_mem.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.004, 0.005, 0.008, 0.97 * a))
				_mem_glass(p, a, Vector2(vs.x * 0.5, vs.y * 0.5) + wob, vs.y * 0.0017 * (1.0 + 0.10 * p))
	_mem.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _sp(out: Array, a: Vector2, b: Vector2, c: Vector2, d: int) -> void:
	if d <= 0:
		out.append([a, b, c])
		return
	var ab := (a + b) * 0.5
	var bc := (b + c) * 0.5
	var ca := (c + a) * 0.5
	_sp(out, a, ab, ca, d - 1)
	_sp(out, ab, b, bc, d - 1)
	_sp(out, ca, bc, c, d - 1)


## Sierpinski glyph: the same broken triangle folded inside itself
func _sierp(ci: CanvasItem, c: Vector2, r: float, depth: int, rot: float, col: Color, w: float) -> void:
	var v: Array = []
	for i in 3:
		v.append(c + Vector2.from_angle(rot + i * TAU / 3.0 - PI * 0.5) * r)
	var tris: Array = []
	_sp(tris, v[0], v[1], v[2], depth)
	for tr in tris:
		ci.draw_polyline(PackedVector2Array([tr[0], tr[1], tr[2], tr[0]]), col, w)
	ci.draw_polyline(PackedVector2Array([v[0], v[1], v[2], v[0]]), Color(col.r, col.g, col.b, col.a * 1.4), w * 1.6)


## the five: goblin, devil, angel, a horror (a ring of eyes), a plain dark man
func _sigil(ci: CanvasItem, kind: int, c: Vector2, r: float, col: Color) -> void:
	var w := maxf(r * 0.07, 1.2)
	ci.draw_arc(c, r, 0.0, TAU, 32, Color(col.r, col.g, col.b, col.a * 0.45), w * 0.7)
	match kind:
		0:
			ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.95, -r * 0.35), c + Vector2(-r * 0.3, -r * 0.12), c + Vector2(0, r * 0.62),
				c + Vector2(r * 0.3, -r * 0.12), c + Vector2(r * 0.95, -r * 0.35)]), col, w)
			ci.draw_circle(c + Vector2(-r * 0.2, r * 0.04), w * 0.9, col)
			ci.draw_circle(c + Vector2(r * 0.2, r * 0.04), w * 0.9, col)
		1:
			ci.draw_arc(c + Vector2(0, r * 0.12), r * 0.42, 0.0, TAU, 20, col, w)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.4, -r * 0.1), c + Vector2(-r * 0.6, -r * 0.62), c + Vector2(-r * 0.15, -r * 0.3)]), col, w)
			ci.draw_polyline(PackedVector2Array([c + Vector2(r * 0.4, -r * 0.1), c + Vector2(r * 0.6, -r * 0.62), c + Vector2(r * 0.15, -r * 0.3)]), col, w)
		2:
			ci.draw_arc(c + Vector2(0, r * 0.16), r * 0.36, 0.0, TAU, 20, col, w)
			ci.draw_arc(c + Vector2(0, -r * 0.42), r * 0.34, 0.0, TAU, 20, col, w * 0.8)
		3:
			for i in 7:
				ci.draw_circle(c + Vector2.from_angle(i * TAU / 7.0) * r * 0.55, w * 1.1, col)
			ci.draw_circle(c, w * 1.4, col)
		4:
			ci.draw_arc(c + Vector2(0, -r * 0.28), r * 0.26, 0.0, TAU, 16, col, w)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.5, r * 0.62), c + Vector2(-r * 0.42, r * 0.18), c + Vector2(r * 0.42, r * 0.18), c + Vector2(r * 0.5, r * 0.62)]), col, w)


func _glass_poly(ex: float, apex: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2(-ex, 230.0))
	pts.append(Vector2(-ex, -60.0))
	for i in 11:
		var u := float(i + 1) / 12.0
		pts.append(Vector2(-ex * (1.0 - u) , lerpf(-60.0, apex, pow(sin(u * PI * 0.5), 0.9))))
	pts.append(Vector2(0, apex))
	for i in 11:
		var u := 1.0 - float(i + 1) / 12.0
		pts.append(Vector2(ex * (1.0 - u), lerpf(-60.0, apex, pow(sin(u * PI * 0.5), 0.9))))
	pts.append(Vector2(ex, -60.0))
	pts.append(Vector2(ex, 230.0))
	return pts


func _mem_glass(p: float, a: float, c: Vector2, sc: float) -> void:
	var ci := _mem
	ci.draw_set_transform(c, 0.0, Vector2(sc, sc))
	var gold := Color(Art.GOLD.r, Art.GOLD.g, Art.GOLD.b, a)
	# cold moon-glow behind the glass
	for i in 30:
		var f := float(i) / 29.0
		ci.draw_circle(Vector2(0, -10), 330.0 * (1.0 - f * 0.94), Color(0.35, 0.50, 0.75, a * 0.018))
	# the glyph etched around the mirror, folding deeper as it remembers
	var depth := 2 + int(2.0 * _ss(0.1, 0.6, p))
	_sierp(ci, Vector2(0, 40), 215.0, depth, 0.0, Color(gold.r, gold.g, gold.b, a * 0.30), 1.5)
	# the five sigils on an arc: the goblin lit first, the rest unlit and listening
	for i in 5:
		var an := deg_to_rad(-160.0 + 35.0 * i)
		var sp := Vector2(0, 30) + Vector2.from_angle(an) * 262.0
		var lit_k := 1.0 if i == 0 else 0.22 + 0.5 * _ss(0.72, 0.95, p) * (0.6 + 0.4 * sin(time * 2.3 + i * 1.7))
		var on := _ss(0.06 + 0.07 * i, 0.16 + 0.07 * i, p)
		_sigil(ci, i, sp, 19.0, Color(gold.r, gold.g, gold.b, a * on * lit_k))
	# mirror frame + glass
	var poly := _glass_poly(118.0, -190.0)
	ci.draw_colored_polygon(poly, Color(0.04, 0.07, 0.11, a))
	var closed := poly.duplicate()
	closed.append(poly[0])
	ci.draw_polyline(closed, Color(gold.r, gold.g, gold.b, a * 0.85), 3.0)
	var inner := _glass_poly(104.0, -172.0)
	inner.append(inner[0])
	ci.draw_polyline(inner, Color(gold.r, gold.g, gold.b, a * 0.35), 1.2)
	# the reflection: mortal -> goblin -> the thing in the red hat (the glass remembers the lie)
	var m_a := 1.0 - _ss(0.28, 0.46, p)
	var g_a := _ss(0.28, 0.46, p) * (1.0 - _ss(0.58, 0.74, p))
	var h_a := _ss(0.58, 0.74, p)
	var ink := Color(0.01, 0.01, 0.015, a)
	var base := Vector2(0, 205)
	if m_a > 0.01:
		var col := Color(ink.r, ink.g, ink.b, a * m_a)
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-34, 0), base + Vector2(-30, -92), base + Vector2(-12, -140), base + Vector2(12, -140), base + Vector2(30, -92), base + Vector2(34, 0)]), col)
		ci.draw_circle(base + Vector2(0, -158), 22.0, col)
		ci.draw_arc(base + Vector2(0, -158), 23.0, PI * 1.05, PI * 1.9, 10, Color(gold.r, gold.g, gold.b, a * m_a * 0.7), 1.6)
		ci.draw_circle(base + Vector2(46, -70), 16.0, Color(1.6, 0.9, 0.3, a * m_a * 0.10))
		ci.draw_circle(base + Vector2(46, -70), 5.0, Color(3.0, 2.0, 0.7, a * m_a))
	if g_a > 0.01:
		var col2 := Color(ink.r, ink.g, ink.b, a * g_a)
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-34, 0), base + Vector2(-32, -92), base + Vector2(-14, -136), base + Vector2(14, -136), base + Vector2(32, -92), base + Vector2(34, 0)]), col2)
		ci.draw_circle(base + Vector2(0, -156), 22.0, col2)
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-18, -166), base + Vector2(-66, -190), base + Vector2(-14, -148)]), col2)
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(18, -166), base + Vector2(66, -190), base + Vector2(14, -148)]), col2)
		ci.draw_circle(base + Vector2(-8, -158), 2.4, Color(2.6, 1.7, 0.5, a * g_a))
		ci.draw_circle(base + Vector2(8, -158), 2.4, Color(2.6, 1.7, 0.5, a * g_a))
	if h_a > 0.01:
		var col3 := Color(0.0, 0.0, 0.0, a * h_a)
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-20, 0), base + Vector2(-26, -86), base + Vector2(-12, -128), base + Vector2(12, -128), base + Vector2(26, -86), base + Vector2(20, 0)]), col3)
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-16, -96), base + Vector2(-76, -150), base + Vector2(-60, -50)]), col3)
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(16, -96), base + Vector2(76, -150), base + Vector2(60, -50)]), col3)
		ci.draw_circle(base + Vector2(0, -148), 26.0, col3)
		ci.draw_circle(base + Vector2(0, -170), 60.0, Color(1.5, 0.08, 0.06, a * h_a * 0.07))
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-32, -166), base + Vector2(-18, -198), base + Vector2(0, -188), base + Vector2(18, -198), base + Vector2(32, -166)]), Color(1.9, 0.10, 0.10, a * h_a))
	# the glass cracks, and two small lights open in it (match cut: his eyes)
	var cr := _ss(0.82, 0.97, p)
	if cr > 0.0:
		var pts := PackedVector2Array([Vector2(0, -190), Vector2(-14, -130), Vector2(10, -70), Vector2(-8, -10), Vector2(18, 60), Vector2(-4, 130), Vector2(8, 220)])
		var n := int(float(pts.size()) * cr)
		if n >= 2:
			ci.draw_polyline(pts.slice(0, n), Color(2.4, 2.6, 2.8, a * 0.9), 1.8)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var glint := _ss(0.88, 1.0, p) * a
	if glint > 0.0:
		var vs := _vp.size
		var ex := vs.y * 0.143       # eye spacing at the camera framing that follows the cut
		for sgn in [-1.0, 1.0]:
			var ep := Vector2(vs.x * 0.5 + sgn * ex, vs.y * 0.5)
			ci.draw_circle(ep, vs.y * 0.05 * glint, Color(1.5, 0.9, 0.3, 0.10 * glint))
			ci.draw_line(ep + Vector2(-vs.y * 0.05, 0), ep + Vector2(vs.y * 0.05, 0), Color(3.0, 2.8, 2.4, 0.9 * glint), 1.6)
			ci.draw_line(ep + Vector2(0, -vs.y * 0.04), ep + Vector2(0, vs.y * 0.04), Color(3.0, 2.8, 2.4, 0.9 * glint), 1.6)
			ci.draw_circle(ep, 2.5, Color(3.0, 2.6, 2.0, glint))


# --- coda: over the black ---------------------------------------------------------------------
func _draw_coda() -> void:
	var t := time
	if t < T_CUT:
		return
	var vs := size
	var gold := Art.GOLD
	var sa := _ss(77.5, 79.3, t) * (1.0 - _ss(83.0, 83.5, t))
	if sa > 0.001:
		var y := vs.y * 0.6
		var sp := vs.y * 0.13
		for i in 5:
			var base_a := 1.0 if i == 0 else 0.2 + 0.1 * sin(t * 2.0 + i * 1.7) + 0.35 * _ss(80.5, 82.2, t)
			_sigil(_coda, i, Vector2(vs.x * 0.5 + (i - 2) * sp, y), vs.y * 0.04, Color(gold.r, gold.g, gold.b, sa * base_a))
	var rd := _ss(82.2, 82.5, t) * (1.0 - _ss(83.55, 83.6, t))
	if rd > 0.001:
		var c := Vector2(vs.x * 0.5, vs.y * 0.745)
		var pul := 0.75 + 0.25 * sin((t - 82.2) * 9.0)
		_coda.draw_circle(c, vs.y * 0.05, Color(1.0, 0.05, 0.04, 0.05 * rd * pul))
		_coda.draw_circle(c, vs.y * 0.02, Color(1.0, 0.07, 0.05, 0.14 * rd * pul))
		_coda.draw_circle(c, maxf(vs.y * 0.004, 2.0), Color(1.0, 0.16, 0.12, rd))


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
