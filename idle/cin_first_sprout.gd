class_name FirstSproutCinematic
extends Control
## "Us planting the sap": the ~10 s cinematic that plays when the first Sprout is bought.
##   await FirstSproutCinematic.play(self)      # adds itself to `self`, frees itself, skippable with any key / click
## Shot 1 (0-3.5)  a luminous droplet of living Sap swells at a fractal leaf tip (macro, refracting the garden).
## Shot 2 (3.5-6) it falls in slow motion and lands in the soil: ripple, halo, lifting particles.
## Shot 3 (6-9)    a fractal sprout unfurls while the camera pulls back and rack-focuses to the garden; one cryptic line.
## 9-10            long soft dissolve back to the game.
## Imagery: idle/cin_sprout.gdshader (one macro-photograph shader) + idle/cin_post.gdshader (bloom, streak, grade, grain).
## Audio: a dedicated procedural stem baked on a Thread (FirstSproutCinematic.prebake() warms it early).

signal finished

const DURATION := 10.0
const T_RELEASE := 3.5
const T_IMPACT := 5.45
const SCENE_SHADER := preload("res://idle/cin_sprout.gdshader")
const POST_SHADER := preload("res://idle/cin_post.gdshader")
const RATE := 16000
const WORD_KEY := "act:remember"
const LINE := "Something remembers."

static var _thr: Thread = null
static var _stem: AudioStreamWAV = null

var t := 0.0
var cs: Cutscene
var done := false
var _vp: SubViewport
var _tex: TextureRect
var _scene: ColorRect
var _post: ColorRect
var _text: Control
var _mat: ShaderMaterial
var _pmat: ShaderMaterial
var _player: AudioStreamPlayer
var _font: SystemFont
var _ids: Array[int] = []
var _word := "REMEMBER"
var _fin_count := 0


static func play(parent: Node) -> void:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var c := FirstSproutCinematic.new()
	parent.add_child(c)
	await c.run()


## Start baking the audio stem in the background (optional; play() does it anyway).
static func prebake() -> void:
	if _stem != null or _thr != null or DisplayServer.get_name() == "headless":
		return
	_thr = Thread.new()
	_thr.start(_bake_stem)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 0.0
	_vp = SubViewport.new()
	_vp.use_hdr_2d = true
	_vp.transparent_bg = false
	_vp.size = Vector2i(1280, 720)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_scene = ColorRect.new()
	_mat = ShaderMaterial.new()
	_mat.shader = SCENE_SHADER
	_scene.material = _mat
	_scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vp.add_child(_scene)
	_text = TextLayer.new()
	_text.owner_cin = self
	_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp.add_child(_text)
	_post = ColorRect.new()
	_pmat = ShaderMaterial.new()
	_pmat.shader = POST_SHADER
	_post.material = _pmat
	_post.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp.add_child(_post)
	_tex = TextureRect.new()
	_tex.texture = _vp.get_texture()
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tex)
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Palatino Linotype", "Georgia", "Cambria", "Garamond", "Times New Roman", "serif"])
	_font.font_italic = true
	if Lexicon.has_concept(WORD_KEY):
		_ids = Lexicon.word_for(WORD_KEY)
		_word = Lexicon.readable_name(WORD_KEY).to_upper()
	else:
		_ids = [17, 52, 31]
	_resize_vp()
	_apply()


## Awaitable. Returns once the cinematic has finished (end or skip) and is being freed.
func run() -> void:
	cs = Cutscene.new().bind(self)
	cs.tween(self, "t", DURATION, DURATION, 0.0, Tween.TRANS_LINEAR)
	cs.letterbox(true, 1.0)
	cs.letterbox(false, 0.9, 9.1)
	_start_audio()
	await cs.play()
	_end()


func skip() -> void:
	if cs != null and is_instance_valid(cs):
		cs.skip()


func _end() -> void:
	if done:
		return
	done = true
	_fin_count += 1
	if _player != null and is_instance_valid(_player):
		_player.stop()
	if cs != null and is_instance_valid(cs):
		cs.queue_free()
	finished.emit()
	queue_free()


func _exit_tree() -> void:
	if not done and cs != null and is_instance_valid(cs):
		done = true
		finished.emit()


func _gui_input(ev: InputEvent) -> void:
	if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventKey and ev.pressed):
		skip()
		accept_event()


func _process(_dt: float) -> void:
	if done:
		return
	_resize_vp()
	_apply()
	_poll_audio()


func _resize_vp() -> void:
	var sc := get_viewport().get_final_transform().get_scale()
	var px := Vector2i(maxi(int(size.x * sc.x), 64), maxi(int(size.y * sc.y), 64))
	if DisplayServer.get_name() == "headless":
		px = Vector2i(320, 180)
	if px != _vp.size:
		_vp.size = px


# ---------------------------------------------------------------------------------------- choreography
static func _e(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)


static func _seg(tt: float, a: float, b: float) -> float:
	return _e((tt - a) / (b - a))


func _apply() -> void:
	var tt := t
	var res := Vector2(_vp.size)
	# camera
	var s1 := _seg(tt, 0.0, 3.5)
	var s2 := _seg(tt, 3.5, 6.0)
	var s3 := _seg(tt, 5.9, 9.6)
	var fl := 2.5 + 0.2 * s1
	fl = lerpf(fl, 3.05, s2)
	fl = lerpf(fl, 1.15, s3)
	var cx := lerpf(-0.02, 0.0, s1)
	cx = lerpf(cx, 0.0, s2)
	cx = lerpf(cx, 0.035, s3)
	var cy := lerpf(0.198, 0.19, s1)
	cy = lerpf(cy, 0.065, s2)
	cy = lerpf(cy, 0.15, s3)
	var hy := lerpf(0.04, 0.036, s1)
	hy = lerpf(hy, 0.10, s2)
	hy = lerpf(hy, -0.02, s3)
	var focus := lerpf(1.0, 2.3, _seg(tt, 7.0, 9.2))
	var aperture := lerpf(1.0, 0.85, s3)
	var lit := lerpf(0.12, 1.0, _seg(tt, 5.6, 9.4))
	# leaf, drop
	var tip := Vector2(0.0, 0.27)
	var r0 := lerpf(0.030, 0.055, _e(tt / 3.4)) + 0.0014 * sin(tt * 3.0) * clampf(1.0 - _seg(tt, 3.0, 3.5), 0.0, 1.0)
	var st := 0.30 * _seg(tt, 1.2, 3.4)
	var c := Vector2(0.0, tip.y - 0.012 - r0 * (1.0 + st))
	var neck := 1.0 - _seg(tt, 2.3, 3.5)
	var vis := 1.0
	var sq := 0.0
	var imp := -1.0
	if tt >= T_RELEASE:
		var tau := tt - T_RELEASE
		var y0 := c.y
		neck = 0.0
		var g := 2.0 * (y0 - (r0 * (1.0 + 0.12))) / pow(T_IMPACT - T_RELEASE, 2.0)
		var yy := y0 - 0.5 * g * tau * tau
		st = lerpf(0.30, 0.12, _e(tau / 1.2))
		c.y = maxf(yy, r0 * 0.5)
		c.x = 0.0
		if tt >= T_IMPACT:
			imp = tt - T_IMPACT
			sq = _e(imp / 0.18)
			vis = 1.0 - _seg(tt, T_IMPACT + 0.04, T_IMPACT + 0.42)
			c.y = r0 * (1.0 - 0.55 * sq) * 0.95 + 0.0
	var grow := _seg(tt, 5.95, 8.7)
	_mat.set_shader_parameter("res", res)
	_mat.set_shader_parameter("t", tt)
	_mat.set_shader_parameter("fl", fl)
	_mat.set_shader_parameter("cam", Vector2(cx, cy))
	_mat.set_shader_parameter("hy", hy)
	_mat.set_shader_parameter("focus", focus)
	_mat.set_shader_parameter("aperture", aperture)
	_mat.set_shader_parameter("tip", tip)
	_mat.set_shader_parameter("drop_c", c)
	_mat.set_shader_parameter("drop_r", r0)
	_mat.set_shader_parameter("drop_st", st)
	_mat.set_shader_parameter("drop_sq", sq)
	_mat.set_shader_parameter("drop_vis", vis)
	_mat.set_shader_parameter("neck", neck)
	_mat.set_shader_parameter("imp", imp)
	_mat.set_shader_parameter("grow", grow)
	_mat.set_shader_parameter("lit", lit)
	# post
	var open := _seg(tt, 0.0, 1.4)
	_pmat.set_shader_parameter("res", res)
	_pmat.set_shader_parameter("t", tt)
	_pmat.set_shader_parameter("exposure", lerpf(0.35, 1.0, open) * (1.0 - 0.25 * _seg(tt, 9.0, 10.0)))
	_pmat.set_shader_parameter("bloom", 0.75 + 0.5 * clampf(1.0 - absf(tt - T_IMPACT - 0.2) / 0.5, 0.0, 1.0))
	# dissolve in from / out to the game
	modulate.a = _seg(tt, 0.0, 0.7) * (1.0 - _seg(tt, 9.0, 10.0))
	_text.queue_redraw()


# ---------------------------------------------------------------------------------------- text
class TextLayer extends Control:
	var owner_cin: FirstSproutCinematic

	func _draw() -> void:
		if owner_cin == null:
			return
		var tt := owner_cin.t
		var u := size.y / 800.0
		var fade_out := 1.0 - FirstSproutCinematic._seg(tt, 9.0, 9.55)
		var gA := FirstSproutCinematic._seg(tt, 6.7, 7.5) * fade_out
		if gA > 0.002:
			var resolve := FirstSproutCinematic._seg(tt, 7.5, 8.5)
			var ga := gA * (1.0 - resolve)
			var ids := owner_cin._ids
			var gs := 46.0 * u
			var total := (ids.size() - 1) * gs * 1.25
			var x := size.x * 0.5 - total * 0.5
			var y := size.y * 0.235
			if ga > 0.002:
				for g in ids:
					GlyphGen.draw(self, int(g), Vector2(x, y), gs, Color(0.55, 1.0, 0.9, ga * 0.9), 2.2 * u)
					GlyphGen.draw(self, int(g), Vector2(x, y), gs, Color(0.4, 0.9, 1.0, ga * 0.25), 6.0 * u)
					x += gs * 1.25
			# english letters resolve one by one
			var f: Font = owner_cin._font
			var fs := int(46.0 * u)
			var word: String = owner_cin._word
			var tr := 20.0 * u
			var w := 0.0
			for ch in word:
				w += f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + tr
			w -= tr
			var lx := size.x * 0.5 - w * 0.5
			for i in word.length():
				var ch := word[i]
				var a := gA * FirstSproutCinematic._seg(tt, 7.65 + i * 0.06, 8.15 + i * 0.06)
				var cw := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				if a > 0.002:
					draw_string(f, Vector2(lx + 2.0, y + 14.0 * u + 2.0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0.03, 0.03, a * 0.8))
					draw_string(f, Vector2(lx, y + 14.0 * u), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.94, 0.76, a))
				lx += cw + tr
		var la := FirstSproutCinematic._seg(tt, 8.0, 8.7) * fade_out
		if la > 0.002:
			var f2: Font = owner_cin._font
			var fs2 := int(40.0 * u)
			var wd := f2.get_string_size(LINE, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
			var p := Vector2(size.x * 0.5 - wd * 0.5, size.y * 0.80)
			draw_string(f2, p + Vector2(2, 2) * u, LINE, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(0.0, 0.02, 0.02, la * 0.55))
			draw_string(f2, p, LINE, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(1.0, 0.92, 0.70, la * 0.95))


# ---------------------------------------------------------------------------------------- audio
func _start_audio() -> void:
	if DisplayServer.get_name() == "headless" or not Hub.enabled:
		return
	if _stem == null and _thr == null:
		prebake()
	_player = AudioStreamPlayer.new()
	_player.volume_db = -3.0
	add_child(_player)
	_poll_audio()


func _poll_audio() -> void:
	if _player == null or _player.playing:
		return
	if _stem == null and _thr != null and not _thr.is_alive():
		_thr.wait_to_finish()
		_thr = null
	if _stem != null and t < DURATION - 0.3:
		_player.stream = _stem
		_player.play(minf(t, DURATION - 0.4))


## Tiny additive synth. `div` renders at RATE/div (cheap for low, tonal material) and upsamples at the end.
class Synth:
	var n := 0
	var div := 1
	var rate := 16000.0
	var L := PackedFloat32Array()
	var R := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()

	func _init(seconds: float, p_div := 1) -> void:
		div = p_div
		rate = float(FirstSproutCinematic.RATE) / div
		n = int(seconds * rate)
		L.resize(n)
		R.resize(n)
		rng.seed = 20260 + p_div

	## Sum of harmonics (phasor recurrences, no sin() per sample) with smooth attack/release: no clicks.
	func tone(t0: float, dur: float, f: float, amp: float, atk: float, rel: float, pan: float, harm: Array, detune := 0.0) -> void:
		var i0 := int(t0 * rate)
		var cnt := int(dur * rate)
		var nh := harm.size()
		var amps := PackedFloat64Array()
		var cl := PackedFloat64Array()
		var sl := PackedFloat64Array()
		var cr := PackedFloat64Array()
		var sr := PackedFloat64Array()
		var kc := PackedFloat64Array()
		var ks := PackedFloat64Array()
		var kc2 := PackedFloat64Array()
		var ks2 := PackedFloat64Array()
		for h in harm:
			amps.append(h[1])
			var a1: float = TAU * f * h[0] / rate
			var a2: float = TAU * f * (1.0 + detune) * h[0] / rate
			kc.append(cos(a1))
			ks.append(sin(a1))
			kc2.append(cos(a2))
			ks2.append(sin(a2))
			cl.append(1.0)
			sl.append(0.0)
			cr.append(cos(0.7))
			sr.append(sin(0.7))
		var gl := amp * (1.0 - clampf(pan, -1.0, 1.0) * 0.5) * 0.85
		var gr := amp * (1.0 + clampf(pan, -1.0, 1.0) * 0.5) * 0.85
		for k in cnt:
			var tt := float(k) / rate
			var e := minf(tt / atk, 1.0) * minf((dur - tt) / rel, 1.0)
			e = e * e * (3.0 - 2.0 * e)
			var v := 0.0
			var vv := 0.0
			for j in nh:
				v += amps[j] * sl[j]
				vv += amps[j] * sr[j]
				var c := cl[j] * kc[j] - sl[j] * ks[j]
				sl[j] = sl[j] * kc[j] + cl[j] * ks[j]
				cl[j] = c
				var c2 := cr[j] * kc2[j] - sr[j] * ks2[j]
				sr[j] = sr[j] * kc2[j] + cr[j] * ks2[j]
				cr[j] = c2
			var i := i0 + k
			if i >= 0 and i < n:
				L[i] += v * e * gl
				R[i] += (vv if detune != 0.0 else v) * e * gr

	## Glassy bell: partials with their own exponential decays (recurrences), 4 ms attack ramp.
	func bell(t0: float, f: float, amp: float, pan: float, decay := 1.6) -> void:
		var parts := [[1.0, 1.0, 1.0], [2.0, 0.40, 0.7], [3.0, 0.22, 0.5], [4.16, 0.10, 0.35]]
		var i0 := int(t0 * rate)
		var cnt := int(decay * 2.4 * rate)
		var gl := amp * (1.0 - pan * 0.5)
		var gr := amp * (1.0 + pan * 0.5)
		var amps := PackedFloat64Array()
		var dfs := PackedFloat64Array()
		var cs := PackedFloat64Array()
		var ss := PackedFloat64Array()
		var kc := PackedFloat64Array()
		var ks := PackedFloat64Array()
		for p in parts:
			if f * p[0] > 7000.0:
				continue
			amps.append(p[1])
			dfs.append(exp(-1.0 / (rate * decay * p[2])))
			var a: float = TAU * f * p[0] / rate
			kc.append(cos(a))
			ks.append(sin(a))
			cs.append(1.0)
			ss.append(0.0)
		var nh := amps.size()
		var ramp := 0.004 * rate
		for k in cnt:
			var v := 0.0
			for j in nh:
				v += amps[j] * ss[j]
				amps[j] *= dfs[j]
				var c := cs[j] * kc[j] - ss[j] * ks[j]
				ss[j] = ss[j] * kc[j] + cs[j] * ks[j]
				cs[j] = c
			v *= minf(float(k) / ramp, 1.0)
			var i := i0 + k
			if i >= 0 and i < n:
				L[i] += v * gl
				R[i] += v * gr

	## Liquid drip: a sine that glides up quickly with a fast decay.
	func drip(t0: float, f0: float, amp: float, pan := 0.0) -> void:
		var i0 := int(t0 * rate)
		var cnt := int(0.5 * rate)
		var ph := 0.0
		for k in cnt:
			var tt := float(k) / rate
			var f := f0 * (1.0 + 1.6 * (1.0 - exp(-tt / 0.035)))
			ph += TAU * f / rate
			var e := exp(-tt / 0.07) * minf(tt / 0.003, 1.0)
			var v := sin(ph) * e + 0.25 * sin(ph * 2.0) * exp(-tt / 0.03)
			var i := i0 + k
			if i >= 0 and i < n:
				L[i] += v * amp * (1.0 - pan * 0.5)
				R[i] += v * amp * (1.0 + pan * 0.5)

	## Soft wet impact: low thump + softly filtered noise puff.
	func impact(t0: float, amp: float) -> void:
		var i0 := int(t0 * rate)
		var cnt := int(0.9 * rate)
		var lp := 0.0
		var lp2 := 0.0
		var ph := 0.0
		for k in cnt:
			var tt := float(k) / rate
			var f := 52.0 + 70.0 * exp(-tt / 0.05)
			ph += TAU * f / rate
			var th := sin(ph) * exp(-tt / 0.22) * minf(tt / 0.006, 1.0)
			lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.07
			lp2 += (lp - lp2) * 0.12
			var nz := lp2 * exp(-tt / 0.10) * minf(tt / 0.006, 1.0) * 5.0
			var v := (th * 0.9 + nz * 0.45) * amp
			var i := i0 + k
			if i >= 0 and i < n:
				L[i] += v
				R[i] += v

	func wind(amp_fn: Callable) -> void:
		var a1 := 0.0
		var a2 := 0.0
		var b1 := 0.0
		var b2 := 0.0
		for i in n:
			var tt := float(i) / rate
			var amp: float = amp_fn.call(tt)
			a1 += (rng.randf_range(-1.0, 1.0) - a1) * 0.14
			a2 += (a1 - a2) * 0.2
			b1 += (rng.randf_range(-1.0, 1.0) - b1) * 0.14
			b2 += (b1 - b2) * 0.2
			var m := 0.55 + 0.45 * sin(tt * 0.9 + 1.0 * sin(tt * 0.37))
			L[i] += a2 * amp * m * 5.0
			R[i] += b2 * amp * (1.1 - m * 0.6) * 5.0

	## Linear upsample to the full rate (identity when div == 1). Returns [L, R].
	func full(total: int) -> Array:
		if div == 1:
			return [L, R]
		var oL := PackedFloat32Array()
		var oR := PackedFloat32Array()
		oL.resize(total)
		oR.resize(total)
		for i in total:
			var x := float(i) / div
			var j := int(x)
			var fr := x - j
			var j2 := mini(j + 1, n - 1)
			j = mini(j, n - 1)
			oL[i] = L[j] + (L[j2] - L[j]) * fr
			oR[i] = R[j] + (R[j2] - R[j]) * fr
		return [oL, oR]


const TOTAL := 10.4
const A_HZ := 110.0


static func _euclid(k: int, nn: int) -> Array:
	var out: Array = []
	for i in nn:
		out.append(((i * k) % nn) < k)
	return out


## Drone (just-intonation stack 1, 3:2, 5:4 over a sub root) + wind, rendered at 4 kHz.
static func _job_drone() -> Array:
	var S := Synth.new(TOTAL, 4)
	var drone := [[0.5, 0.20], [0.75, 0.16], [1.0, 0.13], [1.25, 0.10], [1.5, 0.09], [2.0, 0.05]]
	for k in 3:
		S.tone(k * 3.5, 4.6 if k < 2 else 3.9, A_HZ, 0.34 * (0.7 + 0.2 * k), 1.5, 1.6, 0.0, drone, 0.0011)
	S.wind(func(tt: float) -> float:
		return 0.010 + 0.006 * sin(tt * 0.6) + 0.016 * smoothstep(5.8, 8.0, tt) + 0.006 * smoothstep(0.0, 1.0, tt))
	return S.full(int(TOTAL * RATE))


## The sprout blooms: a rising, resolving chord (A, C#, E, A, C#, E) as soft pad voices, rendered at 8 kHz.
static func _job_pad() -> Array:
	var S := Synth.new(TOTAL, 2)
	var pad := [[1.0, 1.0], [2.0, 0.28], [3.0, 0.10]]
	var notes := [[6.2, 220.0], [6.7, 275.0], [7.2, 330.0], [7.7, 440.0], [8.2, 550.0], [8.65, 660.0]]
	for i in notes.size():
		var nt: Array = notes[i]
		S.tone(nt[0], 10.3 - nt[0], nt[1], 0.055 + 0.01 * i, 0.9, 1.6, -0.4 + 0.16 * i, pad, 0.0013)
	S.tone(5.8, 4.6, A_HZ * 6.0, 0.012, 1.4, 1.4, 0.3, [[1.0, 1.0], [1.5, 0.6]], 0.0016)
	return S.full(int(TOTAL * RATE))


## Sparse bells on a Euclidean E(3,8) grid (5-limit just scale), the drip, the soft impact, the bloom sparkles.
static func _job_events() -> Array:
	var S := Synth.new(TOTAL, 1)
	var scale := [1.0, 9.0 / 8.0, 5.0 / 4.0, 3.0 / 2.0, 5.0 / 3.0, 2.0]
	var pat := _euclid(3, 8)
	var step := 0.62
	var idx := 0
	var tb := 0.7
	while tb < 5.2:
		var si := int(round(tb / step)) % 8
		if pat[si]:
			S.bell(tb, 440.0 * scale[(idx * 2 + 1) % scale.size()], 0.045 * (1.0 - 0.15 * idx), -0.5 + 0.35 * (idx % 3), 1.5)
			idx += 1
		tb += step * 0.5
	S.drip(T_RELEASE, 640.0, 0.16, -0.1)
	S.impact(T_IMPACT, 0.34)
	S.drip(T_IMPACT + 0.02, 360.0, 0.12, 0.1)
	S.bell(T_IMPACT + 0.05, 880.0, 0.10, 0.0, 2.2)
	S.bell(T_IMPACT + 0.07, 1320.0, 0.05, 0.3, 2.0)
	var sparkle := [[7.4, 1320.0, -0.4], [7.95, 1650.0, 0.3], [8.45, 1980.0, -0.2], [8.95, 1320.0, 0.45]]
	for sp in sparkle:
		S.bell(sp[0], sp[1], 0.035, sp[2], 1.6)
	return [S.L, S.R]


## Bakes the whole stem: three worker threads (drone, pad, events), then master fades, soft limit, peak 0.45.
static func _bake_stem() -> void:
	var th: Array[Thread] = []
	for fn in [_job_drone, _job_pad, _job_events]:
		var t := Thread.new()
		t.start(fn)
		th.append(t)
	var parts: Array = []
	for t in th:
		parts.append(t.wait_to_finish())
	var n := int(TOTAL * RATE)
	var L := PackedFloat32Array()
	var R := PackedFloat32Array()
	L.resize(n)
	R.resize(n)
	var peak := 0.0001
	var aL: PackedFloat32Array = parts[0][0]
	var aR: PackedFloat32Array = parts[0][1]
	var bL: PackedFloat32Array = parts[1][0]
	var bR: PackedFloat32Array = parts[1][1]
	var cL: PackedFloat32Array = parts[2][0]
	var cR: PackedFloat32Array = parts[2][1]
	for i in n:
		var tt := float(i) / RATE
		var m := smoothstep(0.0, 0.7, tt) * (1.0 - smoothstep(8.9, 10.2, tt))
		var l := tanh((aL[i] + bL[i] + cL[i]) * 1.1) * m
		var r := tanh((aR[i] + bR[i] + cR[i]) * 1.1) * m
		L[i] = l
		R[i] = r
		peak = maxf(peak, maxf(absf(l), absf(r)))
	var g := 0.45 / peak
	var data := PackedByteArray()
	data.resize(n * 4)
	for i in n:
		data.encode_s16(i * 4, int(clampf(L[i] * g, -0.5, 0.5) * 32767.0))
		data.encode_s16(i * 4 + 2, int(clampf(R[i] * g, -0.5, 0.5) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.stereo = true
	w.mix_rate = RATE
	w.data = data
	_stem = w
