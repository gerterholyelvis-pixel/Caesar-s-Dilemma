
extends RefCounted

## Sound of the fall, synthesised in code (call bake() on a Thread; poll job.cancel to abort).
## Theory: D1 just-intonation drone (1, 3/2, 2, then 6/5 and a 16/15 minor second against the octave grinding
## at ~5 Hz, finally the 45/32 tritone); choir = stacked ratio chords (minor -> phrygian -> tritone) through vowel
## formants with vibrato; Euclidean heartbeat E(2..7,8) whose tempo accelerates 48 -> 132 BPM then dies;
## wind roar = resonant state-variable filter swept by fall speed; fire crackle; stone groans (FM sub-bass).

const DUR := 46.0
const RATE := 16000
const KEYS: Array = [[0.0, 1.2], [4.0, 3.0], [9.0, 8.0], [12.5, 15.0], [14.8, 6.5], [17.0, 15.0], [18.8, 6.5], [21.0, 15.0], [22.8, 6.5], [24.7, 15.0], [26.6, 6.5], [28.5, 15.0], [30.2, 6.5], [32.0, 15.0], [33.4, 8.0], [36.0, 20.0], [40.0, 12.0], [43.0, 6.0], [46.0, 3.0]]


static func speed_at(t: float) -> float:
	if t <= 0.0:
		return KEYS[0][1]
	for i in KEYS.size() - 1:
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if t <= b[0]:
			return lerpf(a[1], b[1], smoothstep(a[0], b[0], t))
	return KEYS[KEYS.size() - 1][1]


static func _ss(a: float, b: float, x: float) -> float:
	return smoothstep(a, b, x)


static func bake(job: Dictionary) -> AudioStreamWAV:
	var n := int((DUR + 0.5) * RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6660666

	# ---- drone @2 kHz -------------------------------------------------------
	var dr := 2000
	var dn := int((DUR + 0.5) * dr)
	var drone := PackedFloat32Array()
	drone.resize(dn)
	var f0 := 36.708   # D1
	# [ratio, onset s, gain]
	var voices: Array = [[1.0, 0.0, 1.0], [1.5, 0.0, 0.5], [2.0, 0.0, 0.55], [2.4, 9.0, 0.30], [32.0 / 15.0, 14.0, 0.34],
		[45.0 / 16.0, 24.0, 0.32], [4.0, 18.0, 0.18], [3.0, 12.0, 0.25]]
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
		var env := _ss(0.0, 5.0, t) * (1.0 - 0.7 * _ss(39.0, 44.0, t))
		drone[i] = s * env * 0.16

	# ---- choir @4 kHz -------------------------------------------------------
	var cr := 4000
	var cn := int((DUR + 0.5) * cr)
	var choir := PackedFloat32Array()
	choir.resize(cn)
	var chords: Array = [
		[1.0, 6.0 / 5.0, 3.0 / 2.0, 2.0],
		[1.0, 16.0 / 15.0, 3.0 / 2.0, 8.0 / 5.0],
		[1.0, 6.0 / 5.0, 45.0 / 32.0, 9.0 / 5.0],
		[1.0, 16.0 / 15.0, 45.0 / 32.0, 3.0 / 2.0]]
	var cbase := 146.83   # D3
	for i in cn:
		if i % 4096 == 0 and job.get("cancel", false):
			return null
		var t := float(i) / cr
		var amp := _ss(11.0, 22.0, t) * (1.0 - _ss(37.0, 43.0, t))
		if amp <= 0.0:
			continue
		var ci := int(t / 7.5) % 4
		var cj := (ci + 1) % 4
		var mx := _ss(5.5, 7.5, fmod(t, 7.5))   # glide to the next chord near the end of each 7.5 s span
		var s := 0.0
		for vi in 4:
			var ratio: float = lerpf(chords[ci][vi], chords[cj][vi], mx)
			var vib := 1.0 + 0.004 * sin(TAU * (5.1 + 0.3 * vi) * t + vi)
			var f := cbase * ratio * vib * (0.5 if vi == 0 else 1.0)
			var w := TAU * f * t
			for hn in range(1, 7):
				var fh := f * hn
				var form := exp(-pow((fh - 650.0) / 280.0, 2.0)) + 0.6 * exp(-pow((fh - 1080.0) / 320.0, 2.0)) + 0.25 / hn
				s += form * sin(w * hn + vi * 1.7) / hn * 0.9
		choir[i] = s * amp * 0.045

	# ---- wind @8 kHz --------------------------------------------------------
	var wr := 8000
	var wn := int((DUR + 0.5) * wr)
	var wind := PackedFloat32Array()
	wind.resize(wn)
	var low := 0.0
	var band := 0.0
	var lp2 := 0.0
	for i in wn:
		if i % 4096 == 0 and job.get("cancel", false):
			return null
		var t := float(i) / wr
		var sp := speed_at(t) / 21.0
		var fc := 140.0 + 1500.0 * pow(sp, 1.1) * (0.8 + 0.2 * sin(t * 0.9))
		var f := 2.0 * sin(PI * fc / wr)
		var nz := rng.randf() * 2.0 - 1.0
		low += f * band
		var high := nz - low - 0.35 * band
		band += f * high
		lp2 += 0.04 * (nz - lp2)
		var g := pow(sp, 1.4) * (0.35 + 0.65 * _ss(1.0, 12.0, t))
		wind[i] = (band * 0.55 + low * 0.2 + lp2 * 2.2) * g * 0.35

	# ---- percussion: Euclidean heartbeat + groans @4 kHz --------------------
	var perc := PackedFloat32Array()
	perc.resize(cn)
	var t_ev := 10.0
	var step := 0
	while t_ev < 44.0:
		if job.get("cancel", false):
			return null
		var bpm: float
		if t_ev < 36.0:
			bpm = lerpf(48.0, 132.0, pow((t_ev - 10.0) / 26.0, 1.4))
		else:
			bpm = lerpf(132.0, 62.0, _ss(36.0, 42.0, t_ev))
		var kk := 2 if t_ev < 17.0 else (3 if t_ev < 24.0 else (5 if t_ev < 31.0 else 7))
		var si := step % 8
		if (si * kk) % 8 < kk:
			var accent := 1.0 if si == 0 else 0.6
			var gain := accent * _ss(10.0, 14.0, t_ev) * (1.0 - _ss(41.0, 44.0, t_ev))
			var f1 := 48.0 + 6.0 * (1.0 if si == 0 else 0.0)
			var i0 := int(t_ev * cr)
			for j in int(0.6 * cr):
				if i0 + j >= cn:
					break
				var tau := float(j) / cr
				var fq := f1 + 55.0 * exp(-tau / 0.045)
				var ph := TAU * (f1 * tau + 55.0 * 0.045 * (1.0 - exp(-tau / 0.045)))
				var e := exp(-tau / 0.13) * (1.0 - exp(-tau * 500.0))
				perc[i0 + j] += (sin(ph) + 0.35 * sin(2.0 * ph)) * e * gain * 0.9
				if fq < 0.0:
					break
		t_ev += 60.0 / bpm / 2.0
		step += 1
	for gt in [16.5, 21.0, 25.5, 29.0, 33.0, 38.0]:
		var i0 := int(gt * cr)
		var f_base := 34.0 + rng.randf() * 10.0
		var phase := 0.0
		for j in int(3.0 * cr):
			if i0 + j >= cn:
				break
			var tau := float(j) / cr
			var env := _ss(0.0, 0.8, tau) * (1.0 - _ss(1.8, 3.0, tau))
			var fm := f_base * (1.0 + 0.12 * sin(TAU * 0.9 * tau) + 0.04 * sin(TAU * 7.3 * tau))
			phase += TAU * fm / cr
			var g := (sin(phase) + 0.5 * sin(2.0 * phase + sin(phase * 0.5) * 2.0)) * (0.65 + 0.35 * sin(TAU * 11.0 * tau))
			perc[i0 + j] += g * env * 0.55 * (1.0 - _ss(39.0, 44.0, gt))

	# ---- fire crackle @16 kHz (sparse impulses) -----------------------------
	var crack := PackedFloat32Array()
	crack.resize(n)
	var tc := 13.0
	while tc < 44.0:
		var rate := lerpf(10.0, 90.0, _ss(14.0, 30.0, tc)) * (1.0 - 0.8 * _ss(38.0, 44.0, tc))
		tc += -log(maxf(rng.randf(), 0.0001)) / rate
		var i0 := int(tc * RATE)
		var ln := int((0.0008 + rng.randf() * 0.004) * RATE)
		var amp2 := (0.1 + rng.randf() * 0.5) * 0.3
		var sg := 1.0
		for j in ln:
			if i0 + j >= n:
				break
			sg = -sg if rng.randf() < 0.6 else sg
			crack[i0 + j] += sg * amp2 * exp(-float(j) / (ln * 0.35))

	# ---- mix ----------------------------------------------------------------
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
		v += lerpf(choir[i1], choir[i1 + 1], a) + lerpf(perc[i1], perc[i1 + 1], a)
		fd = float(i) * wr / RATE
		i1 = mini(int(fd), wn - 2)
		a = fd - i1
		v += lerpf(wind[i1], wind[i1 + 1], a)
		v += crack[i]
		v *= _ss(0.0, 1.0, t) * (1.0 - _ss(DUR - 3.0, DUR, t))
		out[i] = v
		peak = maxf(peak, absf(v))
	var sc := 0.46 / peak
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(out[i] * sc, -0.5, 0.5) * 32767.0))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = RATE
	st.stereo = false
	st.data = bytes
	return st
