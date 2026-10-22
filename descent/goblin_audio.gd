extends RefCounted

## Sound of GRIK, synthesised in code (call bake() on a Thread; poll job.cancel to abort). Peak < 0.5.
## Theory: E1 just-intonation drone (1, 3/2, 2, 12/5, then the 32/15 minor second grinding against the octave, the
## 45/16 tritone when the eyes open); choir = ratio chords through vowel formants; coins = free-disc inharmonic
## partials (1, 2.756, 5.404, 8.933) at just-intonation pitches placed by Euclidean rhythms E(5,8) and E(7,12);
## the final bell uses church-bell partials (0.5, 1, 1.183, 1.506, 2, 2.514, 2.662, 3.011, 4.166); the goblin's
## whisper/giggle is a glottal saw + breath noise through three two-pole formant resonators, in E(5,8) bursts;
## cracking = decaying-density click clouds + a ringing inharmonic glass triplet + sub thump; a Schroeder reverb
## puts it all in a stone cavern. At 42.0 s everything cuts: stinger, silence, one low bell.

const DUR := 47.0
const RATE := 16000
const CRACK_T: Array = [8.6, 9.4, 10.2, 11.2, 12.4, 13.4, 14.0, 18.9, 19.6, 24.9, 25.6, 31.4, 32.2, 33.0, 34.0, 35.2, 36.4]
const FLICKER: Array = [2.2, 2.55, 2.7, 3.3, 3.45, 4.0]
const T_CUT := 42.0

const VOW_A := [800.0, 1150.0, 2900.0]
const VOW_I := [300.0, 2250.0, 3010.0]
const VOW_U := [330.0, 700.0, 2600.0]
const VOW_E := [500.0, 1800.0, 2700.0]
const VOW_O := [450.0, 850.0, 2800.0]
const COIN_P: Array = [1.0, 9.0 / 8.0, 5.0 / 4.0, 3.0 / 2.0, 5.0 / 3.0, 2.0]


static func _ss(a: float, b: float, x: float) -> float:
	return smoothstep(a, b, x)


static func _euclid(k: int, n: int, i: int) -> bool:
	return (i * k) % n < k


static func bake(job: Dictionary) -> AudioStreamWAV:
	var n := int((DUR + 0.5) * RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1313131
	var dry := PackedFloat32Array()
	dry.resize(n)
	var wet := PackedFloat32Array()
	wet.resize(n)

	# ---- drone @2 kHz -----------------------------------------------------------------
	var dr := 2000
	var dn := int((DUR + 0.5) * dr)
	var drone := PackedFloat32Array()
	drone.resize(dn)
	var f0 := 41.203   # E1
	var voices: Array = [[1.0, 0.0, 1.0], [1.5, 1.0, 0.5], [2.0, 0.0, 0.55], [2.4, 14.0, 0.28], [32.0 / 15.0, 20.0, 0.32],
		[45.0 / 16.0, 32.0, 0.34], [3.0, 22.0, 0.20], [4.0, 6.0, 0.14]]
	for i in dn:
		if i % 4096 == 0 and job.get("cancel", false):
			return null
		var t := float(i) / dr
		var s := 0.0
		for v in voices:
			var g: float = v[2] * _ss(v[1], v[1] + 5.0, t)
			if g <= 0.0:
				continue
			var f: float = f0 * v[0]
			var lfo := 0.72 + 0.28 * sin(TAU * (0.05 + 0.013 * v[0]) * t + v[0] * 2.0)
			var w := TAU * f * t
			s += g * lfo * (sin(w) + 0.45 * sin(2.0 * w + 0.6) + 0.22 * sin(3.0 * w + 1.3))
		var env := _ss(0.4, 4.0, t) * (0.45 + 0.55 * _ss(8.0, 34.0, t))
		if t >= T_CUT:
			env *= 0.12 + 0.88 * exp(-(t - T_CUT) * 2.5)
			env *= 0.4 + 0.6 * _ss(T_CUT, T_CUT + 0.05, t)
		drone[i] = s * env * 0.15

	# ---- choir @4 kHz ----------------------------------------------------------------------
	var cr := 4000
	var cn := int((DUR + 0.5) * cr)
	var choir := PackedFloat32Array()
	choir.resize(cn)
	var chords: Array = [
		[1.0, 6.0 / 5.0, 3.0 / 2.0, 2.0],
		[1.0, 16.0 / 15.0, 3.0 / 2.0, 8.0 / 5.0],
		[1.0, 6.0 / 5.0, 45.0 / 32.0, 9.0 / 5.0],
		[1.0, 16.0 / 15.0, 45.0 / 32.0, 3.0 / 2.0]]
	var cbase := 164.81   # E3
	for i in cn:
		if i % 4096 == 0 and job.get("cancel", false):
			return null
		var t := float(i) / cr
		var amp := _ss(13.0, 28.0, t) * 0.5 + _ss(32.0, 41.0, t) * 0.8
		if t >= T_CUT:
			amp = 0.25 * _ss(43.0, 45.0, t) * (1.0 - _ss(45.5, 47.0, t))
		if amp <= 0.0:
			continue
		var ci := int(t / 8.0) % 4
		var cj := (ci + 1) % 4
		var mx := _ss(6.0, 8.0, fmod(t, 8.0))
		var s := 0.0
		for vi in 4:
			var ratio: float = lerpf(chords[ci][vi], chords[cj][vi], mx)
			var vib := 1.0 + 0.004 * sin(TAU * (5.0 + 0.3 * vi) * t + vi)
			var f := cbase * ratio * vib * (0.5 if vi == 0 else 1.0)
			var w := TAU * f * t
			for hn in range(1, 6):
				var fh := f * hn
				var form := exp(-pow((fh - 560.0) / 260.0, 2.0)) + 0.6 * exp(-pow((fh - 950.0) / 300.0, 2.0)) + 0.2 / hn
				s += form * sin(w * hn + vi * 1.7) / hn * 0.9
		choir[i] = s * amp * 0.05

	# ---- stone rumble @8 kHz -----------------------------------------------------------------
	var rr := 8000
	var rn := int((DUR + 0.5) * rr)
	var rumble := PackedFloat32Array()
	rumble.resize(rn)
	var l1 := 0.0
	var l2 := 0.0
	for i in rn:
		if i % 4096 == 0 and job.get("cancel", false):
			return null
		var t := float(i) / rr
		var nz := rng.randf() * 2.0 - 1.0
		l1 += 0.045 * (nz - l1)
		l2 += 0.09 * (l1 - l2)
		var g := 0.35 + 0.65 * _ss(1.0, 10.0, t)
		g *= 0.7 + 0.3 * sin(TAU * 0.11 * t + 1.0)
		for ct in CRACK_T:
			if t > ct - 0.2 and t < ct + 4.0:
				g += 1.4 * exp(-absf(t - ct) * 1.8)
		var sub := sin(TAU * 31.0 * t + 2.0 * sin(TAU * 0.23 * t)) * 0.5
		var r := (l2 * 9.0 + sub * 0.6) * g
		if t >= T_CUT:
			r *= exp(-(t - T_CUT) * 6.0)
		rumble[i] = r * 0.12

	# ---- foley: flicker pops, cracks, ember crackle ----------------------------------------------
	for ft in FLICKER:
		_pop(dry, wet, rng, ft, 0.5)
	for k in CRACK_T.size():
		if job.get("cancel", false):
			return null
		_crack(dry, wet, rng, CRACK_T[k], 0.55 + 0.05 * k)
	var tc := 2.0
	while tc < T_CUT:
		var rate := lerpf(4.0, 55.0, _ss(2.0, 30.0, tc))
		tc += -log(maxf(rng.randf(), 0.0001)) / rate
		var i0 := int(tc * RATE)
		var ln := int((0.0006 + rng.randf() * 0.003) * RATE)
		var a2 := (0.1 + rng.randf() * 0.5) * 0.18
		var sg := 1.0
		for j in ln:
			if i0 + j >= n:
				break
			sg = -sg if rng.randf() < 0.6 else sg
			var v := sg * a2 * exp(-float(j) / (ln * 0.35))
			dry[i0 + j] += v
			wet[i0 + j] += v * 0.3

	# ---- coin chimes: Euclid E(5,8), a slow offer ring, E(7,12) cascade, the final coin ------------------
	var step := 0
	var tt := 15.0
	while tt < 18.6:
		if _euclid(5, 8, step):
			_coin(dry, wet, tt, 1046.5 * COIN_P[(step * 3 + step / 8) % COIN_P.size()], 0.35 if step % 8 == 0 else 0.22)
		step += 1
		tt += 0.28
	_coin(dry, wet, 21.4, 1046.5, 0.30, 2.2)
	_coin(dry, wet, 22.6, 1046.5 * 1.5, 0.30, 2.2)
	step = 0
	tt = 26.2
	while tt < 30.0:
		if _euclid(7, 12, step):
			_coin(dry, wet, tt, 1568.0 / COIN_P[(step / 2) % COIN_P.size()], 0.16 * (1.0 - (tt - 26.2) / 4.5), 0.8)
		step += 1
		tt += 0.165
	_coin(dry, wet, 41.15, 1046.5 * 0.75, 0.5, 2.5)

	# ---- voices ----------------------------------------------------------------------------------
	# the name, whispered: gri-ik
	_voice(dry, wet, rng, 9.55, 0.16, 160.0, VOW_U, 0.92, 0.5, 0.8, 0.0)
	_voice(dry, wet, rng, 9.75, 0.30, 170.0, VOW_I, 0.88, 0.5, 0.8, 0.2)
	_burst(dry, wet, rng, 10.12, 0.04, 0.35)
	# counting murmur (the keeper's tally), E(5,8) @ 0.2 s
	var vows: Array = [VOW_A, VOW_O, VOW_E, VOW_I, VOW_U]
	for i in 24:
		if _euclid(5, 8, i):
			var tv := 15.1 + i * 0.2
			if tv < 18.6:
				_voice(dry, wet, rng, tv, 0.13, 140.0 + 12.0 * (i % 4), vows[(i * 2) % 5], 0.9, 0.22, 0.8, 0.0)
	# the offer: a low coaxing hush, E(3,8)
	for i in 28:
		if _euclid(3, 8, i):
			var tv2 := 20.4 + i * 0.22
			if tv2 < 24.2:
				_voice(dry, wet, rng, tv2, 0.19, 118.0, vows[(i * 3 + 1) % 5], 0.7, 0.28, 0.9, -0.15)
	# distant tittering while he falls
	for tv3 in [27.6, 28.9, 29.5]:
		_voice(dry, wet, rng, tv3, 0.09, 520.0, VOW_I, 0.55, 0.16, 1.0, 0.1)
	# THE GIGGLE: E(5,8) at 0.125 s, rising then breaking
	var gi := 0
	var tg := 38.45
	while tg < 41.55:
		if _euclid(5, 8, gi):
			var prog := (tg - 38.45) / 3.1
			var f := 330.0 + 140.0 * sin(prog * PI) + 90.0 * prog
			var vw: Array = VOW_I if gi % 3 != 2 else VOW_E
			_voice(dry, wet, rng, tg, 0.085, f, vw, 0.42, 0.55 + 0.4 * prog, 0.6, 0.12)
		gi += 1
		tg += 0.125 * (1.0 - 0.15 * (tg - 38.45) / 3.1)
	_voice(dry, wet, rng, 41.55, 0.35, 150.0, VOW_A, 0.55, 0.45, 0.8, -0.3)   # the low "heh"
	_voice(dry, wet, rng, 45.0, 0.5, 130.0, VOW_O, 0.85, 0.25, 1.0, -0.2)     # last whisper

	# ---- riser into the cut: resonant noise sweep ----------------------------------------------------
	var low := 0.0
	var band := 0.0
	var i_r0 := int(37.8 * RATE)
	var i_r1 := int(T_CUT * RATE)
	for i in range(i_r0, i_r1):
		if i % 4096 == 0 and job.get("cancel", false):
			return null
		var t := float(i) / RATE
		var u := (t - 37.8) / (T_CUT - 37.8)
		var fc := 180.0 + 3200.0 * u * u
		var ff := 2.0 * sin(PI * fc / RATE)
		var nz := rng.randf() * 2.0 - 1.0
		low += ff * band
		var high := nz - low - 0.25 * band
		band += ff * high
		var v := band * (0.05 + 0.45 * u * u * u)
		dry[i] += v * 0.35
		wet[i] += v * 0.2
		dry[i] += sin(TAU * lerpf(40.0, 82.0, u * u) * t) * 0.18 * u * u

	# ---- stinger at the cut: gong + sub boom + noise crash -----------------------------------------------
	var gong: Array = [1.0, 1.59, 2.14, 2.30, 2.65, 2.91, 3.50, 4.20, 5.40]
	var i_s := int(T_CUT * RATE)
	for pi in gong.size():
		var f: float = 55.0 * gong[pi]
		var dec := 3.0 / (1.0 + pi * 0.45)
		var ph0 := pi * 1.3
		for j in int(4.0 * RATE):
			if i_s + j >= n:
				break
			var tau := float(j) / RATE
			var e := exp(-tau / dec) * (1.0 - exp(-tau * 300.0))
			var v := sin(TAU * f * tau + ph0 + 0.5 * sin(TAU * (0.8 + pi * 0.2) * tau)) * e * (0.55 / (1.0 + pi * 0.35))
			dry[i_s + j] += v
			wet[i_s + j] += v * 0.35
	var bph := 0.0
	for j in int(1.6 * RATE):
		if i_s + j >= n:
			break
		var tau := float(j) / RATE
		var fq := 28.0 + 55.0 * exp(-tau / 0.12)
		bph += TAU * fq / RATE
		dry[i_s + j] += sin(bph) * exp(-tau / 0.55) * 1.1
	var lp := 0.0
	for j in int(0.9 * RATE):
		if i_s + j >= n:
			break
		var tau := float(j) / RATE
		lp += 0.35 * ((rng.randf() * 2.0 - 1.0) - lp)
		var v := lp * exp(-tau / 0.16) * 0.8
		dry[i_s + j] += v
		wet[i_s + j] += v * 0.4
	# silence-after: the last bell, low and alone, under "Four more are listening."
	_bell(dry, wet, 43.5, 98.0, 0.30, 3.4)

	# ---- Schroeder reverb on the wet bus -------------------------------------------------------------------
	var rev := _reverb(wet, job)
	if rev.is_empty():
		return null

	# ---- mix --------------------------------------------------------------------------------------------------
	var out := PackedFloat32Array()
	out.resize(n)
	var peak := 0.0001
	for i in n:
		if i % 8192 == 0 and job.get("cancel", false):
			return null
		var t := float(i) / RATE
		var fd := float(i) * dr / RATE
		var i1 := mini(int(fd), dn - 2)
		var a := fd - i1
		var v := lerpf(drone[i1], drone[i1 + 1], a)
		fd = float(i) * cr / RATE
		i1 = mini(int(fd), cn - 2)
		a = fd - i1
		v += lerpf(choir[i1], choir[i1 + 1], a)
		fd = float(i) * rr / RATE
		i1 = mini(int(fd), rn - 2)
		a = fd - i1
		v += lerpf(rumble[i1], rumble[i1 + 1], a)
		v += dry[i] + rev[i] * 0.55
		v = tanh(v * 0.45) * 0.5     # soft-clip: keeps the quiet foley audible beside the stinger
		v *= _ss(0.0, 0.8, t) * (1.0 - _ss(DUR - 1.2, DUR, t))
		out[i] = v
		peak = maxf(peak, absf(v))
	var sc := 0.46 / peak
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(out[i] * sc, -0.49, 0.49) * 32767.0))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = RATE
	st.stereo = false
	st.data = bytes
	return st


# ---- building blocks -----------------------------------------------------------------------------------
static func _pop(dry: PackedFloat32Array, wet: PackedFloat32Array, rng: RandomNumberGenerator, t0: float, g: float) -> void:
	# an ember catching: soft fwump (low-passed noise) + a click
	var i0 := int(t0 * RATE)
	var lp := 0.0
	for j in int(0.18 * RATE):
		if i0 + j >= dry.size():
			break
		var tau := float(j) / RATE
		lp += 0.12 * ((rng.randf() * 2.0 - 1.0) - lp)
		var v := (lp * 1.8 + sin(TAU * 70.0 * tau) * 0.4) * exp(-tau / 0.05) * g * (1.0 - exp(-tau * 900.0))
		dry[i0 + j] += v
		wet[i0 + j] += v * 0.3


static func _burst(dry: PackedFloat32Array, wet: PackedFloat32Array, rng: RandomNumberGenerator, t0: float, dur: float, g: float) -> void:
	var i0 := int(t0 * RATE)
	var prev := 0.0
	for j in int(dur * RATE):
		if i0 + j >= dry.size():
			break
		var x := rng.randf() * 2.0 - 1.0
		var v := (x - prev) * exp(-float(j) / (dur * RATE * 0.35)) * g
		prev = x
		dry[i0 + j] += v
		wet[i0 + j] += v * 0.5


static func _crack(dry: PackedFloat32Array, wet: PackedFloat32Array, rng: RandomNumberGenerator, t0: float, g: float) -> void:
	var i0 := int(t0 * RATE)
	# snap: differentiated noise
	var prev := 0.0
	for j in int(0.06 * RATE):
		if i0 + j >= dry.size():
			break
		var tau := float(j) / RATE
		var x := rng.randf() * 2.0 - 1.0
		var v := (x - prev) * exp(-tau / 0.011) * g * 0.55
		prev = x
		dry[i0 + j] += v
		wet[i0 + j] += v * 0.4
	# splintering cloud: density decays
	var cnt := int(28.0 * g + 10.0)
	for c in cnt:
		var dt := -log(maxf(rng.randf(), 0.001)) * 0.16
		var ic := i0 + int(dt * RATE) + int(0.01 * RATE)
		var ln := int((0.0005 + rng.randf() * 0.0025) * RATE)
		var amp := (0.15 + rng.randf() * 0.6) * g * 0.35
		var sg := 1.0
		for j in ln:
			if ic + j >= dry.size():
				break
			sg = -sg if rng.randf() < 0.55 else sg
			var v := sg * amp * exp(-float(j) / (ln * 0.4))
			dry[ic + j] += v
			wet[ic + j] += v * 0.4
	# ringing glass triplet (inharmonic)
	var fb := 1900.0 + rng.randf() * 900.0
	var rat: Array = [1.0, 2.32, 4.18]
	for pi in 3:
		var f: float = fb * rat[pi]
		if f > 7200.0:
			continue
		var dec := 0.22 / (1.0 + pi)
		for j in int(0.8 * RATE):
			if i0 + j >= dry.size():
				break
			var tau := float(j) / RATE
			var v := sin(TAU * f * tau) * exp(-tau / dec) * g * 0.07 / (1.0 + pi)
			dry[i0 + j] += v
			wet[i0 + j] += v * 0.7
	# stone thud
	var ph := 0.0
	for j in int(0.5 * RATE):
		if i0 + j >= dry.size():
			break
		var tau := float(j) / RATE
		ph += TAU * (48.0 + 40.0 * exp(-tau / 0.04)) / RATE
		dry[i0 + j] += sin(ph) * exp(-tau / 0.14) * g * 0.7


static func _coin(dry: PackedFloat32Array, wet: PackedFloat32Array, t0: float, f0: float, g: float, ring: float = 1.0) -> void:
	var parts: Array = [[1.0, 1.0, 0.45], [2.756, 0.7, 0.22], [5.404, 0.45, 0.11], [8.933, 0.3, 0.06]]
	var i0 := int(t0 * RATE)
	for p in parts:
		var f: float = f0 * p[0]
		if f > 7300.0:
			continue
		var dec: float = p[2] * ring
		var cnt := int(minf(dec * 5.0, 3.0) * RATE)
		for j in cnt:
			if i0 + j >= dry.size():
				break
			var tau := float(j) / RATE
			var e := exp(-tau / dec) * (1.0 - exp(-tau * 2500.0))
			var v := (sin(TAU * f * tau) + 0.5 * sin(TAU * f * 1.0035 * tau + 1.0)) * e * g * float(p[1]) * 0.45
			dry[i0 + j] += v
			wet[i0 + j] += v * 0.6


static func _bell(dry: PackedFloat32Array, wet: PackedFloat32Array, t0: float, f0: float, g: float, ring: float) -> void:
	var ratios: Array = [0.5, 1.0, 1.183, 1.506, 2.0, 2.514, 2.662, 3.011, 4.166]
	var i0 := int(t0 * RATE)
	for pi in ratios.size():
		var f: float = f0 * ratios[pi]
		var dec := ring / (1.0 + pi * 0.5)
		for j in int(minf(dec * 4.0, 3.4) * RATE):
			if i0 + j >= dry.size():
				break
			var tau := float(j) / RATE
			var e := exp(-tau / dec) * (1.0 - exp(-tau * 40.0))
			var v := sin(TAU * f * tau + pi) * e * g / (1.0 + pi * 0.3)
			dry[i0 + j] += v
			wet[i0 + j] += v * 0.5


## whisper / voice syllable: glottal saw + breath noise through three two-pole formant resonators
static func _voice(dry: PackedFloat32Array, wet: PackedFloat32Array, rng: RandomNumberGenerator, t0: float, dur: float,
		f0: float, vow: Array, breath: float, g: float, wetk: float, glide: float) -> void:
	var i0 := int(t0 * RATE)
	var r1 := exp(-PI * 90.0 / RATE)
	var r2 := exp(-PI * 120.0 / RATE)
	var r3 := exp(-PI * 180.0 / RATE)
	var A1 := -2.0 * r1 * cos(TAU * float(vow[0]) / RATE)
	var A2 := -2.0 * r2 * cos(TAU * float(vow[1]) / RATE)
	var A3 := -2.0 * r3 * cos(TAU * float(vow[2]) / RATE)
	var y11 := 0.0
	var y12 := 0.0
	var y21 := 0.0
	var y22 := 0.0
	var y31 := 0.0
	var y32 := 0.0
	var phase := 0.0
	var cnt := int(dur * RATE)
	for j in cnt:
		if i0 + j >= dry.size():
			break
		var tau := float(j) / RATE
		var env := smoothstep(0.0, 0.012, tau) * (1.0 - smoothstep(dur * 0.5, dur, tau))
		phase += f0 * (1.0 + glide * tau / dur) * (1.0 + 0.025 * sin(TAU * 6.0 * tau)) / RATE
		var saw := 2.0 * fposmod(phase, 1.0) - 1.0
		var src := (1.0 - breath) * saw + breath * (rng.randf() * 2.0 - 1.0) * 1.3
		var y1 := (1.0 - r1) * src - A1 * y11 - r1 * r1 * y12
		y12 = y11
		y11 = y1
		var y2 := (1.0 - r2) * src - A2 * y21 - r2 * r2 * y22
		y22 = y21
		y21 = y2
		var y3 := (1.0 - r3) * src - A3 * y31 - r3 * r3 * y32
		y32 = y31
		y31 = y3
		var v := (y1 * 1.0 + y2 * 0.7 + y3 * 0.35) * env * g * 2.2
		dry[i0 + j] += v * (1.0 - wetk * 0.5)
		wet[i0 + j] += v * wetk


static func _reverb(wet: PackedFloat32Array, job: Dictionary) -> PackedFloat32Array:
	var n := wet.size()
	var out := PackedFloat32Array()
	out.resize(n)
	var delays := [0.0297, 0.0371, 0.0411, 0.0437, 0.0531]
	var fbs := [0.86, 0.85, 0.84, 0.83, 0.82]
	var lens: Array = []
	var offs: Array = []
	var tot := 0
	for d in delays:
		var L := int(d * RATE)
		offs.append(tot)
		lens.append(L)
		tot += L
	var cb := PackedFloat32Array()
	cb.resize(tot)
	var lps := [0.0, 0.0, 0.0, 0.0, 0.0]
	var ap1 := PackedFloat32Array()
	ap1.resize(int(0.005 * RATE))
	var ap2 := PackedFloat32Array()
	ap2.resize(int(0.0017 * RATE))
	var p1 := 0
	var p2 := 0
	for i in n:
		if i % 8192 == 0 and job.get("cancel", false):
			return PackedFloat32Array()
		var x := wet[i]
		var s := 0.0
		for k in 5:
			var L: int = lens[k]
			var idx: int = int(offs[k]) + i % L
			var y := cb[idx]
			lps[k] += 0.35 * (y - lps[k])
			cb[idx] = x + lps[k] * fbs[k]
			s += y
		s *= 0.2
		# allpass 1
		var z1 := ap1[p1]
		var o1 := -0.5 * s + z1
		ap1[p1] = s + 0.5 * o1
		p1 = (p1 + 1) % ap1.size()
		var z2 := ap2[p2]
		var o2 := -0.5 * o1 + z2
		ap2[p2] = o1 + 0.5 * o2
		p2 = (p2 + 1) % ap2.size()
		out[i] = o2
	return out
