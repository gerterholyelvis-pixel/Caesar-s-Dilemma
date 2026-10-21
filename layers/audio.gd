extends Node

# LAYER: audio. Synthesized, no downloaded files. Everything is pre-rendered ONCE on a background
# thread into AudioStreamWAV buffers (a seamless ambient loop, a handful of chimes, click/hover),
# so nothing is generated per frame on the main thread. That removes both the frame-time cost and
# the buffer-underrun crackle the old live synthesis produced when the frame rate dipped.

const RATE := 16000
const LOOP_SEC := 12

const PAD_FREQ: Array[float] = [55.0, 82.41, 110.0, 164.81, 220.0, 130.81]
const PAD_DET: Array[float] = [0.0, 0.35, -0.4, 0.5, -0.3, 0.25]
const PAD_LFO_K: Array[int] = [1, 2, 1, 3, 2, 1]          # integer cycles per loop -> seamless
const PENTA: Array[float] = [440.0, 523.25, 587.33, 659.25, 783.99, 880.0, 1046.5, 1318.5]

var _thread: Thread
var _amb: AudioStreamPlayer
var _chime_players: Array[AudioStreamPlayer] = []
var _ui_players: Array[AudioStreamPlayer] = []
var _chimes: Array[AudioStreamWAV] = []
var _click: AudioStreamWAV
var _hover: AudioStreamWAV
var _timer: Timer
var _ci := 0
var _ui := 0
var _ready_audio := false


func _ready() -> void:
	_thread = Thread.new()
	_thread.start(_bake)


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()


# ---------------- background thread ----------------

func _bake() -> Dictionary:
	var out := {}
	out["amb"] = _bake_ambient()
	var ch: Array = []
	for f in PENTA:
		ch.append(_bake_chime(f, 3.4))
	out["chimes"] = ch
	out["click"] = _bake_click()
	out["hover"] = _bake_hover()
	call_deferred("_on_baked")
	return out


func _to_pcm(buf: PackedFloat32Array) -> PackedByteArray:
	var d := PackedByteArray()
	d.resize(buf.size() * 2)
	for i in buf.size():
		d.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	return d


func _bake_ambient() -> PackedByteArray:
	var n := RATE * LOOP_SEC
	var xf := RATE * 2   # wind crossfade length
	var pad := PackedFloat32Array()
	pad.resize(n)
	var BLK := 64
	for k in PAD_FREQ.size():
		# snap to a whole number of cycles per loop so the pad loops with no seam
		var f := roundf((PAD_FREQ[k] + PAD_DET[k] * 0.3) * LOOP_SEC) / float(LOOP_SEC)
		var w := TAU * f / RATE
		var base := 0.030 if k < 3 else 0.017
		var lfo_w := TAU * float(PAD_LFO_K[k]) / float(n)
		var i := 0
		while i < n:
			var g := base * (0.5 + 0.5 * sin(lfo_w * i + k * 1.7))
			var end := mini(i + BLK, n)
			for j in range(i, end):
				pad[j] += sin(w * j) * g
			i = end

	# wind: low-passed noise, amplitude swells that loop; crossfaded so the seam disappears
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var wind := PackedFloat32Array()
	wind.resize(n + xf)
	var lp1 := 0.0
	var lp2 := 0.0
	var hp := 0.0
	var sw_w := TAU * 2.0 / float(n)
	for j in n + xf:
		var nz := rng.randf() * 2.0 - 1.0
		var swell := 0.5 + 0.5 * sin(sw_w * j) * sin(sw_w * 0.5 * j + 1.3)
		var k := 0.04 + 0.08 * swell
		lp1 += (nz - lp1) * k
		lp2 += (lp1 - lp2) * k
		hp += (lp2 - hp) * 0.01
		wind[j] = (lp2 - hp) * (0.05 + 0.30 * swell * swell)
	var mix := PackedFloat32Array()
	mix.resize(n)
	for j in n:
		var wv := wind[j]
		if j < xf:
			var s := float(j) / xf
			wv = wind[j] * s + wind[n + j] * (1.0 - s)
		var v := pad[j] + wv
		mix[j] = tanh(v / 0.4) * 0.4   # gentle limiter
	return _to_pcm(mix)


func _bake_chime(freq: float, dur: float) -> PackedByteArray:
	var n := int(RATE * dur)
	var dry := PackedFloat32Array()
	dry.resize(n)
	var w := TAU * freq / RATE
	for i in n:
		var tt := float(i) / RATE
		var env := minf(tt / 0.004, 1.0) * exp(-tt * 1.9)
		dry[i] = (sin(w * i) + 0.35 * sin(w * 2.76 * i)) * env * 0.16
	# baked-in echo so no runtime delay line is needed
	var out := PackedFloat32Array()
	out.resize(n)
	var d1 := int(RATE * 0.37)
	var d2 := int(RATE * 0.74)
	for i in n:
		var v := dry[i]
		if i >= d1:
			v += dry[i - d1] * 0.42
		if i >= d2:
			v += dry[i - d2] * 0.2
		out[i] = v
	return _to_pcm(out)


func _bake_click() -> PackedByteArray:
	var n := int(RATE * 1.4)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var notes := [880.0, 1318.5, 1760.0]
	for k in 3:
		var start := int(RATE * 0.05 * k)
		var w := TAU * float(notes[k]) / RATE
		for i in range(start, n):
			var tt := float(i - start) / RATE
			var env := minf(tt / 0.004, 1.0) * exp(-tt * 3.2)
			buf[i] += (sin(w * (i - start)) + 0.3 * sin(w * 2.76 * (i - start))) * env * 0.12
	return _to_pcm(buf)


func _bake_hover() -> PackedByteArray:
	var n := int(RATE * 0.3)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var w1 := TAU * 2093.0 / RATE
	var w2 := TAU * 3136.0 / RATE
	for i in n:
		var tt := float(i) / RATE
		var env := minf(tt / 0.004, 1.0) * exp(-tt * 14.0)
		buf[i] = (sin(w1 * i) * 0.5 + sin(w2 * i) * 0.3) * env * 0.05
	return _to_pcm(buf)


# ---------------- main thread ----------------

func _wav(data: PackedByteArray, loop := false) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = data.size() / 2
	return w


func _on_baked() -> void:
	var res: Dictionary = _thread.wait_to_finish()
	_amb = AudioStreamPlayer.new()
	_amb.stream = _wav(res["amb"], true)
	_amb.volume_db = -45.0
	add_child(_amb)
	_amb.play()
	create_tween().tween_property(_amb, "volume_db", -13.0, 3.0)

	for d in res["chimes"]:
		_chimes.append(_wav(d))
	for i in 3:
		var p := AudioStreamPlayer.new()
		p.volume_db = -15.0
		add_child(p)
		_chime_players.append(p)
	_click = _wav(res["click"])
	_hover = _wav(res["hover"])
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -8.0
		add_child(p)
		_ui_players.append(p)

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_random_chime)
	add_child(_timer)
	_timer.start(1.5)
	_ready_audio = true


func _random_chime() -> void:
	var p := _chime_players[_ci % _chime_players.size()]
	_ci += 1
	p.stream = _chimes[randi() % _chimes.size()]
	p.play()
	_timer.start(randf_range(2.5, 6.5))


func _play_ui(w: AudioStreamWAV) -> void:
	if not _ready_audio:
		return
	var p := _ui_players[_ui % _ui_players.size()]
	_ui += 1
	p.stream = w
	p.play()


func play_click() -> void:
	_play_ui(_click)


func play_hover() -> void:
	_play_ui(_hover)
