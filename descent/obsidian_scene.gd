extends Control

# THE OBSIDIAN DEEP: bottom of hell, where the new game starts. A calm, fixed, very low-lit cavern
# of black volcanic glass. Later game objects go on the floor at GROUND_Y.

const GROUND_Y := 0.80
const FADE_TIME := 3.0
const MIX_RATE := 11025
const LOOP_SECS := 16.0

var parallax_enabled := true

var _mat: ShaderMaterial
var _rect: ColorRect
var _t := 0.0
var _par := Vector2.ZERO
var _player: AudioStreamPlayer
var _thread: Thread

func ground_y_px() -> float:
	return size.y * GROUND_Y

func _ready() -> void:
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
	_player = AudioStreamPlayer.new()
	_player.volume_db = -80.0
	add_child(_player)
	_thread = Thread.new()
	_thread.start(_bake_audio)

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
	if _player and _player.playing:
		_player.volume_db = lerpf(-40.0, -3.0, f)

func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()

# ---------------- audio (baked on a thread) ----------------
func _bake_audio() -> void:
	var n := int(MIX_RATE * LOOP_SECS)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 666
	var tau := TAU
	# just-intonation drone on D1: 1, 3/2, 2, 9/4, 3, 4, 5 (snapped to whole cycles per loop)
	var base := 36.71
	var ratios := [1.0, 1.5, 2.0, 2.25, 3.0, 4.0, 5.0]
	var amps := [0.30, 0.16, 0.14, 0.05, 0.05, 0.03, 0.015]
	for k in ratios.size():
		var f := roundf(base * ratios[k] * LOOP_SECS) / LOOP_SECS
		var lfo_f := float(1 + k % 3) / LOOP_SECS
		var ph := rng.randf() * tau
		var lph := rng.randf() * tau
		var a: float = amps[k]
		for i in n:
			var t := float(i) / MIX_RATE
			buf[i] += a * (0.75 + 0.25 * sin(tau * lfo_f * t + lph)) * sin(tau * f * t + ph)
	# stone rumble: low periodic sines with random phases
	for j in 12:
		var f := float(int(rng.randf_range(16.0, 90.0) * LOOP_SECS)) / LOOP_SECS
		var ph := rng.randf() * tau
		var a := rng.randf_range(0.012, 0.03)
		var lf := float(rng.randi_range(1, 4)) / LOOP_SECS
		var lp := rng.randf() * tau
		for i in n:
			var t := float(i) / MIX_RATE
			buf[i] += a * (0.5 + 0.5 * sin(tau * lf * t + lp)) * sin(tau * f * t + ph)
	# rare distant glass chimes (just ratios of 880) and stone groans
	var chime_r := [1.0, 1.25, 1.5, 1.875, 2.0, 2.5]
	for c in 3:
		var t0 := rng.randf_range(1.0, LOOP_SECS - 5.0)
		var f: float = 880.0 * chime_r[rng.randi() % chime_r.size()]
		var a := rng.randf_range(0.02, 0.04)
		var len := int(MIX_RATE * 4.5)
		var s0 := int(t0 * MIX_RATE)
		for i in len:
			var t := float(i) / MIX_RATE
			var env := exp(-t * 1.5) * minf(t * 40.0, 1.0)
			buf[(s0 + i) % n] += a * env * (sin(tau * f * t) + 0.35 * sin(tau * f * 2.76 * t) * exp(-t * 2.0))
	for g in 2:
		var t0 := rng.randf_range(0.0, LOOP_SECS - 4.0)
		var s0 := int(t0 * MIX_RATE)
		var len := int(MIX_RATE * 3.5)
		var f0 := rng.randf_range(45.0, 70.0)
		var ph := 0.0
		for i in len:
			var t := float(i) / MIX_RATE
			var env := sin(PI * t / 3.5)
			env *= env
			ph += tau * (f0 * (1.0 - 0.18 * t / 3.5) + 6.0 * sin(t * 9.0)) / MIX_RATE
			buf[(s0 + i) % n] += 0.12 * env * (sin(ph) + 0.4 * sin(ph * 2.0 + 1.0))
	var peak := 0.0001
	for i in n:
		peak = maxf(peak, absf(buf[i]))
	var sc := 0.30 / peak
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(buf[i] * sc, -0.34, 0.34) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	wav.data = bytes
	call_deferred("_start_audio", wav)

func _start_audio(wav: AudioStreamWAV) -> void:
	if _player == null or not is_inside_tree():
		return
	_player.stream = wav
	_player.play()
