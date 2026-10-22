extends Control
class_name FallCinematic

# THE FALL (~46 s, skippable with any key / click): the floor of Limbo gives way and the traveler falls down a vast
# shaft into hell. Act 1 looking up at the black eclipse and the tiny angel (the red hat the last red dot);
# act 2 ash storm turning to cinders; act 3 the throat of hell (gothic ribs, faces, bridges, lava falls);
# act 4 the lake of fire under a smoke ceiling; the light dies; fade to the obsidian dark.
# play() is awaitable and frees the node when finished.

const DUR := 46.0
const Audio := preload("res://descent/fall_audio.gd")
const NOISE := 256
const FADE_COL := Color(0.02, 0.015, 0.02)
const T_CEIL := 36.5          # the moment we pass beneath the smoke ceiling
const VISTA_PITCH := 0.50
const VISTA_DROP := 17.0
const VT := [14.8, 18.8, 22.8, 26.6, 30.2, 33.4]            # vista stations: ribs, furnaces, face, facade, stairs+bridge, lava gargoyle
const VYAW := [1.31, 0.45, -0.45, 0.35, -0.35, 0.2]

## test hooks (fall_demo): start at this time offset, skip audio
static var debug_t0 := 0.0
static var debug_noaudio := false
static var debug_nopost := false

var time := 0.0: set = _set_time

var _ready_done := false
var _vp: SubViewport
var _shown: TextureRect
var _m_scene: ShaderMaterial
var _m_fx: ShaderMaterial
var _m_post: ShaderMaterial
var _angel: Control
var _fade: ColorRect
var _lines: Array = []       # [Label, t_in, t_out]
var _ytab := PackedFloat32Array()
var _ceil_y := 0.0
var _floor_y := 0.0
var _cs: Cutscene
var _player: AudioStreamPlayer
var _thread: Thread
var _job := {"cancel": false}
var _noise_tex: ImageTexture
var _flashes := [10.3, 11.6, 12.4, 13.5, 17.2, 21.6, 29.4]
var _cur := {}               # last camera state, for the angel overlay
var _vy := PackedFloat32Array()
var _va := PackedFloat32Array()
var _yaw_keys: Array = []


static func play(parent: Node) -> void:
	var c := FallCinematic.new()
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
	# dramatic score: the "boss" theme (tritone + minor-second drone, driving polyrhythm) swells with the fall
	# and is faded out for the last 2 s so the obsidian deep starts in silence
	Hub.audio(get_tree())
	Hub.theme("boss")
	Hub.tension(0.25)
	var mt := create_tween()
	mt.tween_method(Hub.tension, 0.25, 1.0, (DUR - t0) * 0.8)
	get_tree().create_timer(maxf(DUR - t0 - 2.0, 0.1)).timeout.connect(func() -> void: Hub.theme(""))
	_cs = Cutscene.new().bind(self)
	_cs.tween(self, "time", DUR, DUR - t0, 0.0, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	_cs.finished.connect(_stop_audio, CONNECT_ONE_SHOT)
	await _cs.play()


func _ready() -> void:
	clip_contents = true
	# speed integral -> depth table
	var steps := int(DUR / 0.02) + 2
	_ytab.resize(steps)
	var y := 5.0
	for i in steps:
		_ytab[i] = y
		y += Audio.speed_at(i * 0.02) * 0.02
	_ceil_y = _y_at(T_CEIL)
	_floor_y = _y_at(DUR) + 24.0
	_yaw_keys = [[0.0, 0.0], [7.0, 0.15], [13.2, VYAW[0]]]
	for k in VT.size():
		_vy.append(_y_at(VT[k]) + VISTA_DROP)
		_va.append(PI * 0.5 + VYAW[k])
		_yaw_keys.append([VT[k] - 0.7, VYAW[k]])
		_yaw_keys.append([VT[k] + 0.7, VYAW[k]])
	_yaw_keys.append([DUR, VYAW[5] + 0.1])

	var nz := FastNoiseLite.new()
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.fractal_type = FastNoiseLite.FRACTAL_FBM
	nz.fractal_octaves = 4
	nz.frequency = 0.012
	nz.seed = 1313
	var img := nz.get_seamless_image(NOISE, NOISE, false, false, 0.1, true)
	img.generate_mipmaps()
	_noise_tex = ImageTexture.create_from_image(img)

	_vp = SubViewport.new()
	_vp.use_hdr_2d = true
	_vp.disable_3d = true
	_vp.transparent_bg = false
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var sc := ColorRect.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_m_scene = _mat("res://descent/fall_shaft.gdshader")
	sc.material = _m_scene
	_vp.add_child(sc)

	_angel = Control.new()
	_angel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_angel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_angel.draw.connect(_draw_angel)
	_vp.add_child(_angel)

	var fx := ColorRect.new()
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_m_fx = _mat("res://descent/fall_fx.gdshader")
	fx.material = _m_fx
	_vp.add_child(fx)

	var post := ColorRect.new()
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_m_post = _mat("res://descent/fall_post.gdshader")
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

	_add_line("Down.", 13.2, 17.6)
	_add_line("Deeper than names.", 26.0, 31.0)
	_add_line("Be still.", 41.0, 44.6)

	_fade = ColorRect.new()
	_fade.color = FADE_COL
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

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


func _add_line(txt: String, t_in: float, t_out: float) -> void:
	var l := Label.new()
	l.text = txt
	l.set_anchors_preset(Control.PRESET_TOP_LEFT)
	l.anchor_top = 0.0
	l.offset_top = 0.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Palatino Linotype", "Book Antiqua", "Garamond", "Georgia", "Times New Roman", "serif"])
	f.font_italic = true
	l.add_theme_font_override("font", f)
	l.add_theme_color_override("font_color", Color(0.93, 0.86, 0.76))
	l.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 8)
	l.modulate.a = 0.0
	add_child(l)
	_lines.append([l, t_in, t_out])


func _on_resized() -> void:
	if _vp == null:
		return
	var s := Vector2i((size * 0.8).round())
	s = Vector2i(maxi(s.x, 160), maxi(s.y, 100))
	_vp.size = s
	var fs := int(size.y * 0.062)
	for e in _lines:
		e[0].add_theme_font_size_override("font_size", maxi(fs, 14))
	_apply(time)


func _set_time(v: float) -> void:
	time = v
	if _ready_done:
		_apply(v)


func _y_at(t: float) -> float:
	var f := clampf(t, 0.0, DUR) / 0.02
	var i := mini(int(f), _ytab.size() - 2)
	return lerpf(_ytab[i], _ytab[i + 1], f - i)


func _kf(t: float, keys: Array) -> float:
	# keys: [[t, v], ...] smooth interpolation
	if t <= keys[0][0]:
		return keys[0][1]
	for i in keys.size() - 1:
		if t <= keys[i + 1][0]:
			return lerpf(keys[i][1], keys[i + 1][1], smoothstep(keys[i][0], keys[i + 1][0], t))
	return keys[keys.size() - 1][1]


func _apply(t: float) -> void:
	var cy := _y_at(t)
	var spd: float = Audio.speed_at(t)
	var vs := _vp.size
	var flip := smoothstep(7.2, 13.8, t)
	var phi := lerpf(-1.30, VISTA_PITCH, flip) + 0.45 * smoothstep(34.5, 44.0, t) + 0.04 * sin(t * 0.7) * (1.0 - flip) + 0.03 * sin(t * 1.3) * flip
	var roll := 0.30 * sin(PI * flip) + 0.025 * sin(t * 0.43) + 0.03 * sin(t * 0.17) * smoothstep(14.0, 30.0, t)
	var yaw := _kf(t, _yaw_keys) + 0.01 * sin(t * 0.8)
	var calm := 1.0 - smoothstep(38.0, 44.0, t)
	var sway := Vector2(sin(t * 0.37) * 1.7, cos(t * 0.29) * 1.3) * smoothstep(5.0, 16.0, t) * (0.3 + 0.7 * calm)
	var sh_amt := (smoothstep(9.0, 36.0, t) * 0.9 + 0.12) * calm * (0.4 + 0.6 * smoothstep(0.0, 4.0, t))
	var shk := Vector2(sin(t * 61.0) + sin(t * 97.0 + 1.0), sin(t * 73.0 + 2.0) + sin(t * 113.0)) * 0.0022 * sh_amt
	var heat := _kf(t, [[0.0, 0.0], [6.0, 0.0], [10.0, 0.25], [14.0, 0.45], [24.0, 0.62], [32.0, 1.0], [40.0, 0.95], [46.0, 0.8]])
	var fogd := _kf(t, [[0.0, 0.020], [8.0, 0.022], [11.0, 0.034], [14.0, 0.026], [18.0, 0.013], [26.0, 0.011], [34.0, 0.010], [38.0, 0.007], [46.0, 0.006]])
	var fog_x := exp(-pow((cy - _ceil_y) / 16.0, 2.0)) * 0.16
	var lake := 1.0 - 0.96 * smoothstep(38.5, 44.5, t)
	var expo := 1.0 - 0.80 * smoothstep(40.0, 45.5, t)
	var smoke := _kf(t, [[0.0, 0.0], [9.0, 0.2], [12.0, 1.0], [24.0, 0.8], [34.0, 0.5], [46.0, 0.3]])
	var lim := 1.0 - smoothstep(6.0, 14.0, t) * 0.92
	var flash := 0.0
	for ft in _flashes:
		flash = maxf(flash, exp(-(t - ft) * 9.0) * (1.0 if t >= ft else 0.0) * (0.7 + 0.3 * sin(t * 90.0)))
	var bolt_a := 0.0
	var bolt_s := 0.0
	for ft in _flashes:
		if t >= ft and t < ft + 0.32:
			bolt_a = exp(-(t - ft) * 11.0) * (0.75 + 0.25 * sin(t * 140.0))
			bolt_s = ft
	var fl := 0.78
	var aspect := vs.x / vs.y

	_cur = {"cy": cy, "phi": phi, "roll": roll, "yaw": yaw, "off": sway, "shk": shk, "fl": fl, "aspect": aspect}

	var m := _m_scene
	m.set_shader_parameter("T", t)
	m.set_shader_parameter("camY", cy)
	m.set_shader_parameter("phi", phi)
	m.set_shader_parameter("yaw", yaw)
	m.set_shader_parameter("roll", roll)
	m.set_shader_parameter("fl", fl)
	m.set_shader_parameter("res", vs)
	m.set_shader_parameter("cam_off", sway)
	m.set_shader_parameter("shake", shk)
	m.set_shader_parameter("heat", heat)
	m.set_shader_parameter("fogd", fogd)
	m.set_shader_parameter("fog_extra", fog_x)
	m.set_shader_parameter("vY", _vy)
	m.set_shader_parameter("vA", _va)
	m.set_shader_parameter("chain_amt", (0.0 + 1.0 * maxf(exp(-pow((t - 18.8) / 2.6, 2.0)), exp(-pow((t - 33.4) / 2.4, 2.0)))) * smoothstep(13.0, 16.0, t) * (1.0 - smoothstep(35.0, 37.0, t)))
	m.set_shader_parameter("ceilY", _ceil_y)
	m.set_shader_parameter("floorY", _floor_y)
	m.set_shader_parameter("lake", lake)
	m.set_shader_parameter("expo", expo)
	m.set_shader_parameter("limbo_light", lim)
	m.set_shader_parameter("smoke_amt", smoke)
	m.set_shader_parameter("flash", flash)

	# nadir position on screen (polar origin of embers); p-space, y down
	var nad := Vector2(0.0, cos(phi) / maxf(sin(phi), 0.05) * fl) * 1.0
	var x := _m_fx
	x.set_shader_parameter("T", t)
	x.set_shader_parameter("camY", cy)
	x.set_shader_parameter("speed", spd)
	x.set_shader_parameter("fl", fl)
	x.set_shader_parameter("res", vs)
	x.set_shader_parameter("nadir", nad)
	var look_down := smoothstep(-0.15, 0.35, phi)
	x.set_shader_parameter("ember_amt", smoothstep(13.0, 20.0, t) * look_down * (1.0 - 0.9 * smoothstep(39.0, 44.0, t)))
	x.set_shader_parameter("ash_amt", smoothstep(8.0, 12.0, t) * look_down * (1.0 - smoothstep(18.0, 30.0, t) * 0.7) * (1.0 - smoothstep(38.0, 44.0, t)))
	x.set_shader_parameter("expo", expo)
	x.set_shader_parameter("flash", flash)
	x.set_shader_parameter("bolt_amt", bolt_a)
	x.set_shader_parameter("bolt_x", fposmod(bolt_s * 0.37, 1.0) * 0.6 + 0.2)
	x.set_shader_parameter("bolt_seed", bolt_s)

	var p := _m_post
	p.set_shader_parameter("T", t)
	p.set_shader_parameter("heat", heat)
	p.set_shader_parameter("shimmer", 0.0025 * smoothstep(12.0, 28.0, t) * (1.0 - smoothstep(38.0, 44.0, t)) * (0.4 + heat))
	p.set_shader_parameter("blur", 0.003 + 0.030 * smoothstep(11.0, 16.0, spd) * smoothstep(8.0, 12.0, t) * look_down)
	p.set_shader_parameter("aberr", 0.0015 + 0.010 * smoothstep(10.0, 16.0, spd))
	p.set_shader_parameter("bloom", 0.35 + 0.25 * heat)
	p.set_shader_parameter("vig", 0.62 + 0.25 * smoothstep(40.0, 46.0, t))
	p.set_shader_parameter("grain", 0.05)
	p.set_shader_parameter("aspect", aspect)
	p.set_shader_parameter("center", Vector2(0.5, 0.5) + (Vector2(nad.x / aspect, nad.y) * look_down).limit_length(0.8))

	if debug_nopost:
		p.set_shader_parameter("bloom", 0.0)
		p.set_shader_parameter("blur", 0.0)
		p.set_shader_parameter("shimmer", 0.0)
	_angel.queue_redraw()
	_fade.color = Color(FADE_COL, maxf(1.0 - smoothstep(0.0, 1.4, t), smoothstep(44.0, 46.0, t)))
	for e in _lines:
		var l: Label = e[0]
		l.modulate.a = smoothstep(e[1], e[1] + 1.2, t) * (1.0 - smoothstep(e[2] - 1.5, e[2], t)) * 0.9
		l.position.y = size.y * 0.30 - 1.0 * (t - e[1]) * 2.0
		l.size = Vector2(size.x, size.y * 0.16)


## the tiny black angel in his red hat, standing on the lip of the hole above us; the hat is the last red dot
func _draw_angel() -> void:
	if _cur.is_empty():
		return
	var t := time
	var vs := _vp.size
	var cy: float = _cur.cy
	var phi: float = _cur.phi
	var P := Vector3(0.45, -1.0, 0.25)
	var dv := Vector3(P.x - _cur.off.x, P.y - cy, P.z - _cur.off.y)
	var yw: float = _cur.yaw
	var xz := Vector2(dv.x, dv.z).rotated(-yw)
	dv = Vector3(xz.x, dv.y, xz.y)
	var depth := dv.y * sin(phi) + dv.z * cos(phi)
	if depth < 0.5:
		return
	var up := dv.y * -cos(phi) + dv.z * sin(phi)
	var qv: Vector2 = Vector2(dv.x, up) * (_cur.fl / depth)
	var qq := Vector2(qv.x, -qv.y).rotated(-_cur.roll)
	var px := Vector2((qq.x / _cur.aspect + 0.5 - _cur.shk.x) * vs.x, (qq.y + 0.5 - _cur.shk.y) * vs.y)
	var sc: float = 1.7 * _cur.fl / depth * vs.y / 190.0    # angel is ~190 units tall in his own drawing
	var vis := 1.0 - smoothstep(10.0, 12.5, t)
	if vis <= 0.0:
		return
	_angel.draw_set_transform(px, 0.0, Vector2(sc, sc))
	var black := Color(0.02, 0.02, 0.026)
	var rim := Color(0.6, 0.62, 0.7, 0.4)
	# upside-down view from below is fine: he stands upright in the world, we look up at him
	var body := PackedVector2Array([Vector2(-14, -2), Vector2(-20, -62), Vector2(-9, -105), Vector2(9, -105), Vector2(20, -62), Vector2(14, -2)])
	_angel.draw_colored_polygon(body, black)
	_angel.draw_colored_polygon(PackedVector2Array([Vector2(-14, -80), Vector2(-62, -120), Vector2(-48, -40)]), black)
	_angel.draw_colored_polygon(PackedVector2Array([Vector2(14, -80), Vector2(62, -120), Vector2(48, -40)]), black)
	_angel.draw_arc(Vector2(0, -122), 17.0, 0.0, TAU, 20, black, 34.0)
	_angel.draw_polyline(PackedVector2Array([Vector2(-20, -62), Vector2(-9, -105), Vector2(9, -105), Vector2(20, -62)]), rim, 2.0 / maxf(sc, 0.05))
	var red := Color(0.86, 0.07, 0.09)
	var hat := PackedVector2Array([Vector2(-30, -138), Vector2(-17, -168), Vector2(0, -158), Vector2(17, -168), Vector2(30, -138)])
	_angel.draw_colored_polygon(hat, red)
	_angel.draw_colored_polygon(PackedVector2Array([Vector2(-34, -138), Vector2(34, -138), Vector2(30, -131), Vector2(-30, -131)]), red.darkened(0.45))
	_angel.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the red dot: glows to the very end
	var dot_p := px + Vector2(0, -150.0 * sc)
	var gr := maxf(2.2, 24.0 * sc * 0.5)
	_angel.draw_circle(dot_p, gr * 2.4, Color(0.95, 0.1, 0.08, 0.10 * vis))
	_angel.draw_circle(dot_p, gr * 1.2, Color(1.0, 0.15, 0.1, 0.30 * vis))
	_angel.draw_circle(dot_p, maxf(1.2, gr * 0.55), Color(1.0, 0.35, 0.3, 0.9 * vis))


# --- audio -----------------------------------------------------------------
func _bake_audio() -> AudioStreamWAV:
	return Audio.bake(_job)


func _process(_d: float) -> void:
	if _thread != null and _player == null and _thread.is_started() and not _thread.is_alive():
		var st: AudioStreamWAV = _thread.wait_to_finish()
		_thread = null
		if st != null and not _job.cancel and is_inside_tree():
			_player = AudioStreamPlayer.new()
			_player.stream = st
			_player.volume_db = -8.0
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
