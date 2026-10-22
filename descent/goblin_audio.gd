extends RefCounted

## Sound of GRIK, synthesised in code (call bake() on a Thread; poll job.cancel to abort). Stereo, peak <= 0.5.
## Retimed to the 84 s film (72 bpm, beat 0.8333 s, hard cut at 74.0): bake(job, dur) lays cues at the absolute times of
## GOBLIN_STORY.md; dur (default job["dur"] or 84) only sets the buffer length (the tail past 84 is silent).
## Theory: E1 just-intonation drone (1, 3/2, 2, 12/5, the 32/15 minor ninth grinding the octave, the 45/16 tritone when
## the eyes open) whose dissonant voices glide into 5/2, 2, 3 and 5 at the bloom (66.7 s); a 5-voice vowel-formant choir
## whose chords move hollow fifths -> cluster -> minor -> maj7 -> cluster -> glass -> tritone -> pure major -> minor;
## coins = free-disc inharmonic partials (1, 2.756, 5.404, 8.933); the shovel dig is spaced by Fibonacci beat gaps; the
## fall is a Shepard-Risset endless rise plus a wind whoosh; the goblin: glottal saw + breath through three two-pole formant
## resonators (formant glide, pitch arc, jitter), phrases of Fibonacci syllable counts, E(5,8) giggles, a breathy intake
## before the eyes open; the heartbeat rides the beat grid and snaps to the cracks; a stereo Schroeder comb/allpass cavern.
## 74.0 hard cut -> stinger -> true silence -> low bell 75.6 -> whisper 79.5 -> one faint high tone 82.2 -> end.

const DUR := 84.0
const RATE := 16000
const BEAT := 60.0 / 72.0
const T_CUT := 74.0
const CRACK_T: Array = [20.83, 21.67, 22.5, 24.17, 25.0, 26.67, 27.5, 28.33, 30.0, 30.83, 31.67, 33.33, 42.5, 49.17, 55.83, 62.5, 63.33]
const SPARK_T: Array = [22.0, 27.8, 31.2, 34.6, 64.17, 70.0]
const FLICKER: Array = [2.6, 2.95, 3.1, 3.7, 3.85, 4.4]

const VOW_A := [800.0, 1150.0, 2900.0]
const VOW_I := [300.0, 2250.0, 3010.0]
const VOW_U := [330.0, 700.0, 2600.0]
const VOW_E := [500.0, 1800.0, 2700.0]
const VOW_O := [450.0, 850.0, 2800.0]
const COIN_P: Array = [1.0, 9.0 / 8.0, 5.0 / 4.0, 3.0 / 2.0, 5.0 / 3.0, 2.0]


static func crack_times() -> Array:
	return CRACK_T.duplicate()


static func _ss(a: float, b: float, x: float) -> float:
	return smoothstep(a, b, x)


static func _euclid(k: int, n: int, i: int) -> bool:
	return (i * k) % n < k


static func _gl(p: float) -> float:
	return cos((clampf(p, -1.0, 1.0) + 1.0) * PI * 0.25)


static func _gr(p: float) -> float:
	return sin((clampf(p, -1.0, 1.0) + 1.0) * PI * 0.25)


## 100 Hz control curve from [[seconds, value], ...] keyframes, smoothstep between keys
static func _curve(pts: Array, dur: float) -> PackedFloat32Array:
	var m := int(dur * 100.0) + 4
	var c := PackedFloat32Array()
	c.resize(m)
	var k := 0
	var np := pts.size()
	for i in m:
		var f := float(i) / 100.0
		while k < np - 2 and f > float((pts[k + 1] as Array)[0]):
			k += 1
		var a: Array = pts[k]
		var b: Array = pts[mini(k + 1, np - 1)]
		var span := maxf(float(b[0]) - float(a[0]), 0.000001)
		c[i] = lerpf(float(a[1]), float(b[1]), smoothstep(0.0, 1.0, clampf((f - float(a[0])) / span, 0.0, 1.0)))
	return c


static func _lk(c: PackedFloat32Array, t: float) -> float:
	var x := t * 100.0
	var i := int(x)
	if i >= c.size() - 1:
		return c[c.size() - 1]
	return lerpf(c[i], c[i + 1], x - i)


static func bake(job: Dictionary, dur_in: float = -1.0) -> AudioStreamWAV:
	var D: float = dur_in if dur_in > 0.0 else float(job.get("dur", DUR))
	var n := int((D + 0.5) * RATE)
	n = (n >> 3) << 3
	var rng := RandomNumberGenerator.new()
	rng.seed = 1313131
	var tcut := T_CUT
	var CL := D + 8.0   # curve length: covers the whole timeline
	var L := PackedFloat32Array()
	L.resize(n)
	var R := PackedFloat32Array()
	R.resize(n)
	var W := PackedFloat32Array()
	W.resize(n)
	var cracks := crack_times()

	var dr := 2000
	var dn := (n >> 3) + 4
	var drone := PackedFloat32Array()
	drone.resize(dn)
	var f0 := 41.203   # E1
	var vsp: Array = [[1.0, 1.0, 0.0, 1.0], [1.5, 1.5, 2.5, 0.5], [2.0, 2.0, 5.0, 0.55], [2.4, 2.5, 9.0, 0.28],
		[32.0 / 15.0, 2.0, 17.0, 0.34], [45.0 / 16.0, 3.0, 64.17, 0.36], [3.0, 3.0, 11.0, 0.2], [4.0, 5.0, 7.0, 0.14]]
	var denv := _curve([[0.0, 0.0], [0.6, 0.22], [2.4, 0.3], [12.0, 0.4], [20.0, 0.55], [30.0, 0.75], [36.0, 0.7], [50.0, 0.8],
		[62.4, 0.85], [62.5, 0.3], [64.1, 0.3], [64.17, 1.0], [66.7, 2.4], [69.0, 2.0], [72.0, 2.2], [73.99, 1.8], [74.0, 0.0], [90.0, 0.0]], CL)
	var dph := PackedFloat32Array()
	dph.resize(8)
	var dinc := PackedFloat32Array()
	dinc.resize(8)
	var dgn := PackedFloat32Array()
	dgn.resize(8)
	for i in dn:
		if i % 4096 == 0 and job.get("cancel", false):
			return null
		var t := float(i) / dr
		if i % 32 == 0:
			var res := _ss(66.3, 67.6, t)
			for k in 8:
				var v: Array = vsp[k]
				var ratio := lerpf(float(v[0]), float(v[1]), res)
				dinc[k] = TAU * f0 * ratio / dr
				var lfo := 0.72 + 0.28 * sin(TAU * (0.05 + 0.013 * ratio) * t + ratio * 2.0)
				var gk := float(v[3]) * _ss(float(v[2]), float(v[2]) + 4.0, t) * lfo
				if k == 4:
					gk *= 1.0 - 0.7 * res
				dgn[k] = gk
		var s := 0.0
		for k in 8:
			var ph := dph[k] + dinc[k]
			if ph > TAU:
				ph -= TAU
			dph[k] = ph
			var s1 := sin(ph)
			var c1 := cos(ph)
			var s2 := 2.0 * s1 * c1
			var c2 := 1.0 - 2.0 * s1 * s1
			s += dgn[k] * (s1 + 0.45 * s2 + 0.22 * (s2 * c1 + c2 * s1))
		drone[i] = s * _lk(denv, t) * 0.15

	var cr := 4000
	var cn := (n >> 2) + 4
	var chL := PackedFloat32Array()
	chL.resize(cn)
	var chR := PackedFloat32Array()
	chR.resize(cn)
	var chords: Array = [
		[0.0, 1.0, [1.0, 1.5, 2.0, 3.0, 4.0]],
		[18.0, 2.5, [1.0, 1.5, 2.0, 32.0 / 15.0, 3.0]],
		[20.8, 1.2, [1.0, 16.0 / 15.0, 1.5, 2.0, 32.0 / 15.0]],
		[36.67, 0.8, [1.0, 6.0 / 5.0, 1.5, 9.0 / 5.0, 12.0 / 5.0]],
		[43.33, 0.8, [1.0, 5.0 / 4.0, 1.5, 15.0 / 8.0, 2.5]],
		[50.0, 0.8, [1.0, 16.0 / 15.0, 45.0 / 32.0, 1.5, 16.0 / 9.0]],
		[56.67, 0.8, [1.0, 6.0 / 5.0, 45.0 / 32.0, 5.0 / 3.0, 12.0 / 5.0]],
		[62.5, 0.2, [1.0, 1.5, 2.0, 3.0, 4.0]],
		[64.17, 0.4, [1.0, 16.0 / 15.0, 45.0 / 32.0, 1.5, 32.0 / 15.0]],
		[66.7, 1.4, [1.0, 5.0 / 4.0, 1.5, 2.0, 2.5]],
		[72.0, 1.4, [1.0, 6.0 / 5.0, 1.5, 2.0, 12.0 / 5.0]]]
	var cenv := _curve([[0.0, 0.0], [8.0, 0.0], [14.0, 0.05], [18.0, 0.12], [20.8, 0.3], [30.0, 0.35], [35.9, 0.35], [36.6, 0.2],
		[37.2, 0.4], [50.0, 0.5], [62.4, 0.6], [62.5, 0.04], [64.1, 0.04], [64.17, 0.6], [66.6, 1.0], [66.7, 3.2], [69.2, 2.2],
		[73.5, 2.4], [73.99, 1.8], [74.0, 0.0], [90.0, 0.0]], CL)
	var cbase := 164.81   # E3
	var cph := PackedFloat32Array()
	cph.resize(5)
	var cinc := PackedFloat32Array()
	cinc.resize(5)
	var cw := PackedFloat32Array()
	cw.resize(20)
	var cgl := PackedFloat32Array()
	cgl.resize(5)
	var cgr := PackedFloat32Array()
	cgr.resize(5)
	var cpan: Array = [-0.6, -0.25, 0.0, 0.25, 0.6]
	var nch := chords.size()
	for i in cn:
		if i % 4096 == 0 and job.get("cancel", false):
			return null
		var t := float(i) / cr
		if i % 128 == 0:
			var ae := _lk(cenv, t)
			var ci := 0
			while ci + 1 < nch and float((chords[ci + 1] as Array)[0]) - float((chords[ci + 1] as Array)[1]) * 0.5 <= t:
				ci += 1
			var rt0: Array = (chords[ci] as Array)[2]
			var rt1: Array = rt0
			var mxw := 1.0
			if ci >= 1:
				var cc: Array = chords[ci]
				rt1 = (chords[ci - 1] as Array)[2]
				mxw = _ss(float(cc[0]) - float(cc[1]) * 0.5, float(cc[0]) + float(cc[1]) * 0.5, t)
			var F1 := 470.0 + 220.0 * sin(TAU * t / 23.0)
			var F2 := 1000.0 + 450.0 * sin(TAU * t / 31.0 + 1.0)
			for vi in 5:
				var ratio := lerpf(float(rt1[vi]), float(rt0[vi]), mxw)
				var vib := 1.0 + 0.004 * sin(TAU * (5.0 + 0.3 * vi) * t + vi)
				var f := cbase * ratio * vib * (0.5 if vi == 0 else 1.0)
				cinc[vi] = TAU * f / cr
				for hn in 4:
					var fh := f * (hn + 1)
					var wgt := 0.0
					if fh < 1500.0 and ae > 0.0001:
						wgt = (exp(-pow((fh - F1) / 260.0, 2.0)) + 0.6 * exp(-pow((fh - F2) / 300.0, 2.0)) + 0.2 / (hn + 1)) / (hn + 1) * 0.9
					cw[vi * 4 + hn] = wgt * ae * (0.8 + 0.2 * sin(TAU * (0.07 + 0.02 * vi) * t + vi * 1.3))
				var pp := clampf(float(cpan[vi]) + 0.2 * sin(TAU * 0.04 * t + vi * 2.1), -1.0, 1.0)
				cgl[vi] = _gl(pp)
				cgr[vi] = _gr(pp)
		var sl := 0.0
		var sr := 0.0
		for vi in 5:
			var ph := cph[vi] + cinc[vi]
			if ph > TAU:
				ph -= TAU
			cph[vi] = ph
			var b := vi * 4
			if cw[b] == 0.0 and cw[b + 1] == 0.0:
				continue
			var s1 := sin(ph)
			var c1 := cos(ph)
			var s2 := 2.0 * s1 * c1
			var c2 := 1.0 - 2.0 * s1 * s1
			var acc := cw[b] * s1 + cw[b + 1] * s2 + cw[b + 2] * (s2 * c1 + c2 * s1) + cw[b + 3] * 2.0 * s2 * c2
			sl += acc * cgl[vi]
			sr += acc * cgr[vi]
		chL[i] = sl * 0.05
		chR[i] = sr * 0.05

	var rr := 8000
	var rn := (n >> 1) + 4
	var rumL := PackedFloat32Array()
	rumL.resize(rn)
	var rumR := PackedFloat32Array()
	rumR.resize(rn)
	var rg := _curve([[0.0, 0.0], [2.2, 0.0], [3.2, 0.15], [12.0, 0.2], [20.0, 0.35], [22.0, 0.5], [30.0, 0.6], [35.9, 0.55],
		[36.6, 0.4], [50.0, 0.5], [62.4, 0.55], [62.5, 0.0], [64.1, 0.0], [64.17, 0.9], [66.7, 1.1], [73.99, 1.0], [74.0, 0.0], [90.0, 0.0]], CL)
	var wgc := _curve([[0.0, 0.0], [2.4, 0.0], [3.5, 0.06], [20.0, 0.08], [36.0, 0.0], [36.67, 0.5], [39.0, 0.8], [42.4, 0.2], [43.0, 0.0],
		[49.9, 0.0], [50.0, 0.3], [53.0, 1.0], [55.7, 2.0], [55.82, 2.0], [55.83, 0.0], [90.0, 0.0]], CL)
	var wfc := _curve([[0.0, 250.0], [20.0, 350.0], [36.67, 300.0], [39.0, 520.0], [42.4, 300.0], [50.0, 250.0], [53.0, 800.0],
		[55.82, 3000.0], [55.83, 300.0], [90.0, 300.0]], CL)
	var boost := PackedFloat32Array()
	boost.resize(int(CL * 100.0) + 4)
	for i in boost.size():
		var tb := float(i) / 100.0
		var bs := 0.0
		for ct in cracks:
			var dtc: float = tb - float(ct)
			if dtc > -0.2 and dtc < 4.0:
				var kb := 0.25 if (float(ct) > 62.0 and float(ct) < 64.0) else 1.0
				bs += 1.4 * kb * exp(-absf(dtc) * 1.8)
		boost[i] = bs
	var l1a := 0.0
	var l2a := 0.0
	var l1b := 0.0
	var l2b := 0.0
	var wlA := 0.0
	var wbA := 0.0
	var wlB := 0.0
	var wbB := 0.0
	var wf := 0.1
	var wgn := 0.0
	for i in rn:
		if i % 4096 == 0 and job.get("cancel", false):
			return null
		var t := float(i) / rr
		if t > tcut:
			break
		var nzA := rng.randf() * 2.0 - 1.0
		var nzB := rng.randf() * 2.0 - 1.0
		l1a += 0.045 * (nzA - l1a)
		l2a += 0.09 * (l1a - l2a)
		l1b += 0.045 * (nzB - l1b)
		l2b += 0.09 * (l1b - l2b)
		if i % 64 == 0:
			wf = 2.0 * sin(PI * clampf(_lk(wfc, t), 40.0, 1800.0) / rr)
			wgn = _lk(wgc, t) * (0.65 + 0.35 * sin(TAU * 0.21 * t + 2.0 * sin(TAU * 0.05 * t)))
		if wgn > 0.002:
			wlA += wf * wbA
			var whA := nzA - wlA - 0.18 * wbA
			wbA += wf * whA
			wlB += wf * wbB
			var whB := nzB - wlB - 0.18 * wbB
			wbB += wf * whB
		else:
			wlA = 0.0
			wbA = 0.0
			wlB = 0.0
			wbB = 0.0
		var rgt := _lk(rg, t)
		var g := rgt * (0.7 + 0.3 * sin(TAU * 0.11 * t + 1.0)) + _lk(boost, t) * (1.0 if t > 2.4 else 0.0)
		var sub := sin(TAU * 31.0 * t + 2.0 * sin(TAU * 0.23 * t)) * 0.3
		rumL[i] = ((l2a * 9.0 + sub) * g + wbA * wgn * 0.55) * 0.12
		rumR[i] = ((l2b * 9.0 + sub) * g + wbB * wgn * 0.55) * 0.12

	var erate := _curve([[0.0, 0.0], [2.3, 0.0], [2.5, 1.0], [12.0, 3.0], [20.0, 6.0], [30.0, 12.0], [36.0, 10.0], [50.0, 14.0],
		[62.4, 16.0], [62.5, 0.0], [64.1, 0.0], [64.2, 20.0], [70.0, 30.0], [73.9, 26.0], [74.0, 0.0], [90.0, 0.0]], CL)
	var te := 2.4
	while te < tcut - 0.1:
		if job.get("cancel", false):
			return null
		var rt := _lk(erate, te)
		if rt < 0.3:
			te += 0.1
			continue
		te += -log(maxf(rng.randf(), 0.0001)) / rt
		var pe := clampf(0.75 * sin(0.6 * te + 1.3 * sin(0.17 * te)) + 0.3 * (rng.randf() - 0.5), -1.0, 1.0)
		var dist := rng.randf()
		var kind := rng.randf()
		var ge := (0.06 + rng.randf() * 0.5) * 0.2 * (1.0 - 0.6 * dist)
		_tick(L, R, W, rng, te, ge, pe, 0.25 + 0.6 * dist, 0 if kind < 0.7 else (1 if kind < 0.92 else 2))
	for ft in FLICKER:
		_pop(L, R, W, rng, float(ft), 0.5, -0.5 + rng.randf())

	_bell(L, R, W, 6.0, 1318.5, 0.045, 3.0, 0.7)
	_bell(L, R, W, 10.0, 1318.5 * 1.5, 0.04, 3.0, -0.6)
	_bell(L, R, W, 16.7, 1318.5 * 1.25, 0.035, 3.0, 0.2)
	_creak(L, R, W, rng, 5.0, 2.2, 0.12, 0.4, 70.0, 300.0, 520.0)
	_grind(L, R, W, rng, 8.3, 3.2, 0.14, -0.3, 420.0)
	_creak(L, R, W, rng, 14.2, 1.8, 0.16, 0.5, 58.0, 420.0, 260.0)
	_grind(L, R, W, rng, 17.5, 3.0, 0.2, 0.3, 500.0)
	# the title: a whispered "gri-ik" at 12.5
	_swell(L, R, W, rng, 11.3, 1.2, 0.08, 0.0, true)
	_voice(L, R, W, rng, 12.5, 0.16, 160.0, VOW_U, 0.92, 0.5, 0.8, 0.0, -0.1, [], 1.1, 0.0, 0.1)
	_voice(L, R, W, rng, 12.7, 0.30, 170.0, VOW_I, 0.88, 0.5, 0.8, 0.2, -0.1, [], 1.1, 0.1, 0.1)
	_burst(L, R, W, rng, 13.07, 0.04, 0.35, -0.1, 1)

	_grind(L, R, W, rng, 19.4, 2.6, 0.30, -0.4, 480.0)
	_creak(L, R, W, rng, 21.0, 1.6, 0.22, 0.5, 66.0, 380.0, 900.0)
	_grind(L, R, W, rng, 23.0, 2.2, 0.32, 0.4, 700.0)
	_creak(L, R, W, rng, 24.6, 1.9, 0.26, -0.55, 84.0, 900.0, 520.0)
	_grind(L, R, W, rng, 26.0, 2.8, 0.36, 0.0, 380.0)
	_creak(L, R, W, rng, 28.4, 2.0, 0.30, 0.3, 72.0, 500.0, 1300.0)
	_grind(L, R, W, rng, 30.0, 2.4, 0.34, -0.2, 900.0)
	_creak(L, R, W, rng, 32.0, 2.4, 0.28, -0.3, 62.0, 600.0, 300.0)
	_phrase(L, R, W, rng, 23.3, 3, 130.0, 0.10, 0.95, 0.9, -0.5, 1.1)
	_phrase(L, R, W, rng, 27.0, 5, 135.0, 0.14, 0.95, 0.9, 0.5, 1.1)
	_phrase(L, R, W, rng, 31.6, 8, 140.0, 0.18, 0.92, 0.85, -0.2, 1.12)
	for k in SPARK_T.size():
		var ts: float = SPARK_T[k]
		_coin(L, R, W, ts, 2093.0 * float(COIN_P[(k * 2) % 6]), 0.10, 3.0, sin(float(k) * 2.0) * 0.8)
		_burst(L, R, W, rng, ts, 0.03, 0.12, sin(float(k) * 2.0) * 0.8, 2)

	var births: Array = [36.67, 43.33, 50.0, 56.67]
	for k in 4:
		var tb2: float = births[k]
		_thump(L, R, W, tb2, 0.5, 60.0, 0.12, 0.0)
		_coin(L, R, W, tb2 + 0.02, 1046.5 * float(COIN_P[k + 1]), 0.18, 1.5, -0.4 + 0.3 * k)
		_swell(L, R, W, rng, tb2 - 1.3, 1.3, 0.14, 0.0, true)

	# -- the grave 36.67-42.5: Fibonacci-gapped shovel, funeral toll, eight coins counted, tally murmur
	_bell(L, R, W, 36.8, 123.5, 0.20, 4.5, -0.3)
	_bell(L, R, W, 41.0, 123.5, 0.16, 4.0, 0.3)
	var tg := 37.5
	var gi := 0
	for gp in [1.0, 1.0, 2.0, 1.0, 3.0]:
		if tg < 42.2:
			_shovel(L, R, W, rng, tg, 0.5 + 0.08 * gi, -0.5 + 0.35 * (gi % 4))
		tg += float(gp) * BEAT
		gi += 1
	for k in 8:
		_coin(L, R, W, 37.3 + k * 0.5, 1046.5 * float(COIN_P[(k * 2) % 6]) * 0.5, 0.07, 0.7, -0.6 + 0.17 * k)
	var vows: Array = [VOW_A, VOW_O, VOW_E, VOW_I, VOW_U]
	for i in 24:
		if _euclid(5, 8, i):
			var tv := 37.2 + i * 0.2
			if tv < 41.8:
				_voice(L, R, W, rng, tv, 0.13, 140.0 + 12.0 * (i % 4), vows[(i * 2) % 5], 0.9, 0.22, 0.8, 0.0, sin(float(i)) * 0.5, [], 1.1)

	# -- the offer 43.33-49.17: the red-hat angel, harp, glass halo, the faceless coin, the hush
	_pluck_run(L, R, W, 44.0, 0.16)
	_pluck_run(L, R, W, 46.6, 0.13)
	_shimmer(L, R, W, 43.8, 4.9, 880.0, 0.11)
	_coin(L, R, W, 46.67, 1046.5, 0.30, 2.4, -0.3)
	_coin(L, R, W, 47.5, 1046.5 * 1.5, 0.28, 2.4, 0.3)
	_bell(L, R, W, 48.4, 440.0 * 16.0 / 15.0, 0.10, 3.0, 0.0)
	for i in 28:
		if _euclid(3, 8, i):
			var tv2 := 44.0 + i * 0.22
			if tv2 < 48.5:
				_voice(L, R, W, rng, tv2, 0.19, 118.0, vows[(i * 3 + 1) % 5], 0.7, 0.28, 0.9, -0.15, -0.3, [], 1.0)

	# -- the fall 50-55.83: Shepard-Risset rise, wind whoosh (above), tittering 52-55, impact on the crack
	_shepard(L, R, W, 50.0, 5.8, 0.55)
	for tv3 in [52.0, 52.8, 53.5, 54.2, 54.9]:
		_voice(L, R, W, rng, tv3, 0.09, 520.0, VOW_I, 0.55, 0.18, 1.0, 0.1, rng.randf() * 1.6 - 0.8, [], 1.0)
	_thump(L, R, W, 55.83, 1.6, 36.0, 0.5, 0.0)
	_burst(L, R, W, rng, 55.83, 0.25, 0.5, 0.0, 1)

	# -- the glass 56.67-62.5: bowl pings on five sigils, whispers, then the shatter at 61.8
	_shimmer(L, R, W, 57.2, 4.3, 1100.0, 0.09)
	var sig: Array = [1.0, 9.0 / 8.0, 5.0 / 4.0, 3.0 / 2.0, 5.0 / 3.0]
	for k in 5:
		_bell(L, R, W, 57.5 + k * BEAT, 1318.5 * float(sig[k]), 0.07, 2.5, -0.7 + 0.35 * k)
	_phrase(L, R, W, rng, 58.2, 5, 140.0, 0.16, 0.9, 0.9, -0.3, 1.1)
	_phrase(L, R, W, rng, 60.2, 3, 145.0, 0.16, 0.9, 0.9, 0.3, 1.1)
	_crack(L, R, W, rng, 61.8, 1.1, 0.0)
	for k in 10:
		_clink(L, R, W, rng, 61.82 + rng.randf() * 0.7, 0.14, rng.randf() * 1.8 - 0.9)
		_coin(L, R, W, 61.85 + k * 0.06, 2093.0 * float(COIN_P[k % 6]) * (1.0 + 0.5 * float(k % 3)), 0.07, 1.4, rng.randf() * 1.6 - 0.8)

	# held silence 62.5-64.17 (drone only) -- one breath, barely there; eyes open 64.17-66.7 with a rising tritone
	_inhale(L, R, W, rng, 63.2, 0.95, 0.22, 0.0)
	_rise(L, R, W, 64.17, 2.53, 0.5)
	_thump(L, R, W, 64.17, 1.3, 42.0, 0.35, 0.0)
	_bell(L, R, W, 64.17, 330.0, 0.18, 4.0, -0.2)
	_bell(L, R, W, 64.17, 330.0 * 45.0 / 32.0, 0.13, 3.0, 0.3)
	_burst(L, R, W, rng, 64.17, 0.09, 0.4, 0.0, 2)
	# the bloom at 66.7: dissonance resolves; church bells on the pure triad
	_bell(L, R, W, 66.7, 164.8, 0.26, 5.5, -0.3)
	_bell(L, R, W, 66.75, 164.8 * 1.25, 0.18, 5.0, 0.3)
	_bell(L, R, W, 66.8, 164.8 * 1.5, 0.18, 5.0, 0.0)
	_thump(L, R, W, 66.7, 1.3, 40.0, 0.45, 0.0)
	# "He knows what the coin costs": a low gloating murmur, the smirk's breath, then the giggle
	_phrase(L, R, W, rng, 67.7, 5, 110.0, 0.26, 0.6, 0.8, -0.3, 1.0)
	_inhale(L, R, W, rng, 68.75, 0.4, 0.28, 0.1)
	var runs: Array = [[69.2, 2.0], [71.4, 2.0]]
	for rg2 in runs:
		var tg0: float = rg2[0]
		var rl: float = rg2[1]
		var gj := 0
		var tgg := tg0
		while tgg < tg0 + rl:
			if _euclid(5, 8, gj):
				var prog := (tgg - tg0) / rl
				var fg := 330.0 + 140.0 * sin(prog * PI) + 90.0 * prog
				var vw: Array = VOW_I if gj % 3 != 2 else VOW_E
				_voice(L, R, W, rng, tgg, 0.085, fg, vw, 0.42, 0.55 + 0.4 * prog, 0.6, 0.12, 0.7 * sin(float(gj) * 1.9), [], 1.1, 0.05, 0.1)
			gj += 1
			tgg += 0.125 * (1.0 - 0.15 * (tgg - tg0) / rl)
	_voice(L, R, W, rng, 73.2, 0.4, 150.0, VOW_A, 0.55, 0.45, 0.8, -0.3, 0.0, VOW_O, 1.0, 0.0, 0.2)
	# riser: resonant noise sweep slammed shut by the cut
	var rs0 := 71.0
	var rs1 := tcut
	var rlow := 0.0
	var rband := 0.0
	for i in range(int(rs0 * RATE), int(rs1 * RATE)):
		if i % 4096 == 0 and job.get("cancel", false):
			return null
		var tr2 := float(i) / RATE
		var u := (tr2 - rs0) / (rs1 - rs0)
		var fcr := 180.0 + 3200.0 * u * u
		var ff := 2.0 * sin(PI * fcr / RATE)
		var nz := rng.randf() * 2.0 - 1.0
		rlow += ff * rband
		var rhigh := nz - rlow - 0.25 * rband
		rband += ff * rhigh
		var v := rband * (0.05 + 0.45 * u * u * u)
		var pr := sin(tr2 * 3.0) * 0.5
		L[i] += v * 0.35 * _gl(pr)
		R[i] += v * 0.35 * _gr(pr)
		W[i] += v * 0.2
		var sb := sin(TAU * lerpf(40.0, 82.0, u * u) * tr2) * 0.18 * u * u
		L[i] += sb
		R[i] += sb

	var used: Array = []
	used.resize(cracks.size())
	used.fill(false)
	var segs: Array = [[19.17, 36.67, 2.0 * BEAT], [36.67, 62.5, BEAT], [64.17, 73.9, BEAT]]
	for sg in segs:
		var hb: float = sg[0]
		var hper: float = sg[2]
		while hb < float(sg[1]):
			var snapped := false
			for ci in cracks.size():
				var cth: float = cracks[ci]
				if not used[ci] and cth > hb - 0.3 * hper and cth < hb + 0.5 * hper:
					hb = cth
					used[ci] = true
					snapped = true
					break
			var hg := lerpf(0.2, 0.85, _ss(19.0, 73.0, hb))
			if not snapped:
				_thump(L, R, W, hb, hg, 56.0, 0.14, 0.0)
			_thump(L, R, W, hb + minf(0.3 * hper, 0.26), hg * 0.6, 50.0, 0.12, 0.0)
			hb += hper
	# the cracks themselves
	for k in cracks.size():
		if job.get("cancel", false):
			return null
		var cg := 0.55 + 0.025 * k
		if k == 14:
			cg = 1.1
		elif k >= 15:
			cg = 1.0
		_crack(L, R, W, rng, float(cracks[k]), cg, sin(float(k) * 2.3) * 0.7)

	var gong: Array = [1.0, 1.59, 2.14, 2.30, 2.65, 2.91, 3.50, 4.20, 5.40]
	var i_s := int(tcut * RATE)
	var stl := int(0.55 * RATE)
	for pi in gong.size():
		var f: float = 55.0 * gong[pi]
		var dec := 3.0 / (1.0 + pi * 0.45)
		var ph0 := pi * 1.3
		var pg := ((pi % 2) * 2.0 - 1.0) * 0.5
		var gl := _gl(pg)
		var gr := _gr(pg)
		for j in stl:
			if i_s + j >= n:
				break
			var tau := float(j) / RATE
			var e := exp(-tau / dec) * (1.0 - exp(-tau * 300.0)) * (1.0 - smoothstep(0.38, 0.55, tau))
			var v := sin(TAU * f * tau + ph0 + 0.5 * sin(TAU * (0.8 + pi * 0.2) * tau)) * e * (0.55 / (1.0 + pi * 0.35))
			L[i_s + j] += v * gl
			R[i_s + j] += v * gr
			W[i_s + j] += v * 0.35
	var bph := 0.0
	for j in stl:
		if i_s + j >= n:
			break
		var tau := float(j) / RATE
		var fq := 28.0 + 55.0 * exp(-tau / 0.12)
		bph += TAU * fq / RATE
		var v := sin(bph) * exp(-tau / 0.4) * 1.1 * (1.0 - smoothstep(0.4, 0.55, tau))
		L[i_s + j] += v
		R[i_s + j] += v
	var lpa := 0.0
	var lpb := 0.0
	for j in int(0.5 * RATE):
		if i_s + j >= n:
			break
		var tau := float(j) / RATE
		lpa += 0.35 * ((rng.randf() * 2.0 - 1.0) - lpa)
		lpb += 0.35 * ((rng.randf() * 2.0 - 1.0) - lpb)
		var e2 := exp(-tau / 0.14) * 0.8 * (1.0 - smoothstep(0.38, 0.5, tau))
		L[i_s + j] += lpa * e2
		R[i_s + j] += lpb * e2
		W[i_s + j] += (lpa + lpb) * 0.2 * e2

	_bell(L, R, W, 75.6, 98.0, 0.30, 3.4, 0.0)
	_phrase(L, R, W, rng, 79.5, 5, 118.0, 0.22, 0.97, 1.0, 0.0, 1.0)
	var ir := int(82.2 * RATE)
	for j in int(1.7 * RATE):
		if ir + j >= n:
			break
		var tau := float(j) / RATE
		var e3 := smoothstep(0.0, 0.7, tau) * (1.0 - smoothstep(0.9, 1.7, tau))
		var v := sin(TAU * 2637.0 * tau + 0.3 * sin(TAU * 4.0 * tau)) * e3 * 0.03
		L[ir + j] += v
		R[ir + j] += v
		W[ir + j] += v * 0.5

	var rev := _reverb(W, job, tcut + 0.55)
	if rev.is_empty():
		return null
	var rvL: PackedFloat32Array = rev[0]
	var rvR: PackedFloat32Array = rev[1]

	var outL := PackedFloat32Array()
	outL.resize(n)
	var outR := PackedFloat32Array()
	outR.resize(n)
	var peak := 0.0001
	var nanc := 0
	var iend := int(D * RATE)
	for i in n:
		if i % 8192 == 0 and job.get("cancel", false):
			return null
		if i >= iend:
			continue
		var t := float(i) / RATE
		var i8 := i >> 3
		var a8 := float(i & 7) * 0.125
		var vd := lerpf(drone[i8], drone[i8 + 1], a8)
		var i4 := i >> 2
		var a4 := float(i & 3) * 0.25
		var i2 := i >> 1
		var a2 := 0.5 * float(i & 1)
		var rk := 1.0 - _ss(tcut + 0.45, tcut + 0.55, t) if (t > tcut and t < 75.6) else 1.0
		var vl := vd + lerpf(chL[i4], chL[i4 + 1], a4) + lerpf(rumL[i2], rumL[i2 + 1], a2) + L[i] + lerpf(rvL[i2], rvL[i2 + 1], a2) * 0.55 * rk
		var vr := vd + lerpf(chR[i4], chR[i4 + 1], a4) + lerpf(rumR[i2], rumR[i2 + 1], a2) + R[i] + lerpf(rvR[i2], rvR[i2 + 1], a2) * 0.55 * rk
		var m := _ss(0.0, 0.5, t) * (1.0 - _ss(D - 0.7, D, t))
		vl = tanh(vl * 0.45) * 0.5 * m
		vr = tanh(vr * 0.45) * 0.5 * m
		if is_nan(vl) or is_nan(vr) or is_inf(vl) or is_inf(vr):
			nanc += 1
			vl = 0.0
			vr = 0.0
		outL[i] = vl
		outR[i] = vr
		peak = maxf(peak, maxf(absf(vl), absf(vr)))
	var sc := 0.46 / peak
	var bytes := PackedByteArray()
	bytes.resize(n * 4)
	for i in n:
		bytes.encode_s16(i * 4, int(clampf(outL[i] * sc, -0.49, 0.49) * 32767.0))
		bytes.encode_s16(i * 4 + 2, int(clampf(outR[i] * sc, -0.49, 0.49) * 32767.0))
	job["nan"] = nanc
	job["peak"] = peak * sc
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = RATE
	st.stereo = true
	st.data = bytes
	return st


## rising tritone: root E3 -> E4 with a partner a 45/32 above it, swelling then cut as the eyes finish opening
static func _rise(L: PackedFloat32Array, R: PackedFloat32Array, W: PackedFloat32Array, t0: float, dur: float, g: float) -> void:
	var i0 := int(t0 * RATE)
	var cnt := int(dur * RATE)
	var pa := 0.0
	var pb := 0.0
	for j in cnt:
		if i0 + j >= L.size():
			break
		var u := float(j) / cnt
		var fa := 164.8 * pow(2.0, u * u)
		pa += TAU * fa / RATE
		pb += TAU * fa * 45.0 / 32.0 * (1.0 + 0.003 * sin(TAU * 5.0 * u * dur)) / RATE
		if pa > TAU * 1000.0:
			pa = fmod(pa, TAU)
		if pb > TAU * 1000.0:
			pb = fmod(pb, TAU)
		var env := (0.15 + 0.85 * u * u) * smoothstep(0.0, 0.1, u) * (1.0 - smoothstep(0.96, 1.0, u))
		var va := (sin(pa) + 0.4 * sin(2.0 * pa)) * env * g * 0.18
		var vb := (sin(pb) + 0.4 * sin(2.0 * pb)) * env * g * 0.18
		L[i0 + j] += va * 0.8 + vb * 0.4
		R[i0 + j] += va * 0.4 + vb * 0.8
		W[i0 + j] += (va + vb) * 0.4


static func _pluck_run(L: PackedFloat32Array, R: PackedFloat32Array, W: PackedFloat32Array, t0: float, g: float) -> void:
	var harp: Array = [1.0, 9.0 / 8.0, 5.0 / 4.0, 3.0 / 2.0, 5.0 / 3.0, 15.0 / 8.0, 2.0, 9.0 / 4.0, 5.0 / 2.0]
	for hi in harp.size():
		_pluck(L, R, W, t0 + hi * 0.11, 659.3 * float(harp[hi]), g, -0.7 + 1.4 * hi / 8.0)


# ---- building blocks -----------------------------------------------------------------------------------
static func _pop(L: PackedFloat32Array, R: PackedFloat32Array, W: PackedFloat32Array, rng: RandomNumberGenerator, t0: float, g: float, pan: float) -> void:
	# an ember catching: soft fwump (low-passed noise) + a click
	var i0 := int(t0 * RATE)
	var gl := _gl(pan)
	var gr := _gr(pan)
	var lp := 0.0
	for j in int(0.18 * RATE):
		if i0 + j >= L.size():
			break
		var tau := float(j) / RATE
		lp += 0.12 * ((rng.randf() * 2.0 - 1.0) - lp)
		var v := (lp * 1.8 + sin(TAU * 70.0 * tau) * 0.4) * exp(-tau / 0.05) * g * (1.0 - exp(-tau * 900.0))
		L[i0 + j] += v * gl
		R[i0 + j] += v * gr
		W[i0 + j] += v * 0.3


## spatial ember event: 0 = tick, 1 = soft pop, 2 = spit
static func _tick(L: PackedFloat32Array, R: PackedFloat32Array, W: PackedFloat32Array, rng: RandomNumberGenerator, t0: float, g: float, pan: float, wk: float, kind: int) -> void:
	var i0 := int(t0 * RATE)
	var gl := _gl(pan)
	var gr := _gr(pan)
	var sz := L.size()
	if kind == 0:
		var ln := int((0.0006 + rng.randf() * 0.003) * RATE)
		var sg := 1.0
		for j in ln:
			if i0 + j >= sz:
				break
			sg = -sg if rng.randf() < 0.6 else sg
			var v := sg * g * exp(-float(j) / (ln * 0.35))
			L[i0 + j] += v * gl
			R[i0 + j] += v * gr
			W[i0 + j] += v * wk
	elif kind == 1:
		var lp := 0.0
		var fq := 120.0 + rng.randf() * 220.0
		for j in int(0.045 * RATE):
			if i0 + j >= sz:
				break
			var tau := float(j) / RATE
			lp += 0.2 * ((rng.randf() * 2.0 - 1.0) - lp)
			var v := (lp * 1.6 + sin(TAU * fq * tau) * 0.3) * exp(-tau / 0.012) * g * 1.4
			L[i0 + j] += v * gl
			R[i0 + j] += v * gr
			W[i0 + j] += v * wk
	else:
		var prev := 0.0
		for j in int(0.03 * RATE):
			if i0 + j >= sz:
				break
			var tau := float(j) / RATE
			var x := rng.randf() * 2.0 - 1.0
			var v := (x - prev) * exp(-tau / 0.007) * g * 0.8
			prev = x
			L[i0 + j] += v * gl
			R[i0 + j] += v * gr
			W[i0 + j] += v * wk


## differentiated-noise burst (hp = 1 plosive "k", 2 sibilant "s")
static func _burst(L: PackedFloat32Array, R: PackedFloat32Array, W: PackedFloat32Array, rng: RandomNumberGenerator, t0: float, dur: float, g: float, pan: float, hp: int = 1) -> void:
	var i0 := int(t0 * RATE)
	var gl := _gl(pan)
	var gr := _gr(pan)
	var p1 := 0.0
	var p2 := 0.0
	for j in int(dur * RATE):
		if i0 + j >= L.size():
			break
		var x := rng.randf() * 2.0 - 1.0
		var v := (x - p1) if hp == 1 else (x - 2.0 * p1 + p2) * 0.5
		p2 = p1
		p1 = x
		v *= exp(-float(j) / (dur * RATE * 0.35)) * g
		L[i0 + j] += v * gl
		R[i0 + j] += v * gr
		W[i0 + j] += v * 0.5


## thump: the heartbeat, a stone thud body; sine sweep with a click of low-passed noise
static func _thump(L: PackedFloat32Array, R: PackedFloat32Array, W: PackedFloat32Array, t0: float, g: float, f0: float, dec: float, pan: float) -> void:
	var i0 := int(t0 * RATE)
	var gl := _gl(pan)
	var gr := _gr(pan)
	var ph := 0.0
	for j in int(dec * 5.0 * RATE):
		if i0 + j >= L.size():
			break
		var tau := float(j) / RATE
		ph += TAU * (f0 * (1.0 + 1.1 * exp(-tau / 0.035))) / RATE
		var v := sin(ph) * exp(-tau / dec) * (1.0 - exp(-tau * 700.0)) * g * 0.7
		L[i0 + j] += v * gl
		R[i0 + j] += v * gr
		W[i0 + j] += v * 0.15


static func _crack(L: PackedFloat32Array, R: PackedFloat32Array, W: PackedFloat32Array, rng: RandomNumberGenerator, t0: float, g: float, pan: float) -> void:
	var i0 := int(t0 * RATE)
	var sz := L.size()
	var gl := _gl(pan)
	var gr := _gr(pan)
	# transient: a 3-sample impulse (the hairline break), then a second-difference snap
	for j in 3:
		if i0 + j < sz:
			var v: float = float([1.0, -0.8, 0.45][j]) * g * 0.9
			L[i0 + j] += v * gl
			R[i0 + j] += v * gr
			W[i0 + j] += v * 0.3
	var p1 := 0.0
	var p2 := 0.0
	var lp := 0.0
	for j in int(0.09 * RATE):
		if i0 + j >= sz:
			break
		var tau := float(j) / RATE
		var x := rng.randf() * 2.0 - 1.0
		var sn := (x - 2.0 * p1 + p2) * exp(-tau / 0.006) * g * 0.35
		p2 = p1
		p1 = x
		lp += 0.28 * (x - lp)
		var cr2 := lp * exp(-tau / 0.03) * g * 0.7 * (1.0 - exp(-tau * 1500.0))
		var v := sn + cr2
		L[i0 + j] += v * gl
		R[i0 + j] += v * gr
		W[i0 + j] += v * 0.4
	# splintering debris: density decays, each fragment placed in the stereo field
	var cnt := int(28.0 * g + 14.0)
	for c in cnt:
		var dt := -log(maxf(rng.randf(), 0.001)) * 0.2
		var ic := i0 + int(dt * RATE) + int(0.01 * RATE)
		var ln := int((0.0005 + rng.randf() * 0.0025) * RATE)
		var amp := (0.15 + rng.randf() * 0.6) * g * 0.35 * exp(-dt / 0.35)
		var pc := pan + (rng.randf() - 0.5) * 1.2
		var cgl := _gl(pc)
		var cgr := _gr(pc)
		var sg := 1.0
		for j in ln:
			if ic + j >= sz:
				break
			sg = -sg if rng.randf() < 0.55 else sg
			var v := sg * amp * exp(-float(j) / (ln * 0.4))
			L[ic + j] += v * cgl
			R[ic + j] += v * cgr
			W[ic + j] += v * 0.4
	# ringing glass (inharmonic triplet; big cracks get a longer ring)
	var fb := 1900.0 + rng.randf() * 900.0
	var rat: Array = [1.0, 2.32, 4.18]
	for pi in 3:
		var f: float = fb * rat[pi]
		if f > 7200.0:
			continue
		var dec := (0.22 + 0.25 * g) / (1.0 + pi)
		for j in int(1.0 * RATE):
			if i0 + j >= sz:
				break
			var tau := float(j) / RATE
			var v := sin(TAU * f * tau) * exp(-tau / dec) * g * 0.07 / (1.0 + pi)
			L[i0 + j] += v * gl
			R[i0 + j] += v * gr
			W[i0 + j] += v * 0.7
	# stone thud
	var ph := 0.0
	for j in int(0.5 * RATE):
		if i0 + j >= sz:
			break
		var tau := float(j) / RATE
		ph += TAU * (48.0 + 40.0 * exp(-tau / 0.04)) / RATE
		var v := sin(ph) * exp(-tau / 0.14) * g * 0.7
		L[i0 + j] += v
		R[i0 + j] += v


## stone grinding: low-passed noise, stick-slip AM, a resonant body
static func _grind(L: PackedFloat32Array, R: PackedFloat32Array, W: PackedFloat32Array, rng: RandomNumberGenerator, t0: float, dur: float, g: float, pan: float, fc: float) -> void:
	var i0 := int(t0 * RATE)
	var gl := _gl(pan)
	var gr := _gr(pan)
	var a := clampf(TAU * fc / RATE, 0.01, 0.6)
	var l1 := 0.0
	var l2 := 0.0
	var ph := 0.0
	var rb := 0.0
	var rb2 := 0.0
	var rf := 2.0 * cos(TAU * 105.0 / RATE)
	var cnt := int(dur * RATE)
	for j in cnt:
		if i0 + j >= L.size():
			break
		var tau := float(j) / RATE
		var u := float(j) / cnt
		var nz := rng.randf() * 2.0 - 1.0
		l1 += a * (nz - l1)
		l2 += a * (l1 - l2)
		ph += TAU * (14.0 + 12.0 * sin(TAU * 0.9 * tau) + 6.0 * sin(TAU * 2.3 * tau + 1.0)) / RATE
		var am := 0.5 + 0.5 * sin(ph)
		am = am * am * am
		var grit := 0.0
		if rng.randf() < 0.004:
			grit = (rng.randf() - 0.5) * 3.0
		var src := l2 * 5.0 * am + grit
		var res := rf * 0.995 * rb - 0.99 * rb2 + src * 0.02
		rb2 = rb
		rb = res
		var env := smoothstep(0.0, 0.25, u) * (1.0 - smoothstep(0.65, 1.0, u)) * (0.7 + 0.3 * sin(TAU * 0.6 * tau))
		var v := (src * 0.45 + res * 4.0) * env * g * 0.04
		L[i0 + j] += v * gl
		R[i0 + j] += v * gr
		W[i0 + j] += v * 0.35


## stone/ice creak: jittered pulse train through two sweeping resonators
static func _creak(L: PackedFloat32Array, R: PackedFloat32Array, W: PackedFloat32Array, rng: RandomNumberGenerator, t0: float, dur: float, g: float, pan: float, fp: float, fc0: float, fc1: float) -> void:
	var i0 := int(t0 * RATE)
	var gl := _gl(pan)
	var gr := _gr(pan)
	var ph := 0.0
	var y11 := 0.0
	var y12 := 0.0
	var y21 := 0.0
	var y22 := 0.0
	var r1 := exp(-PI * 70.0 / RATE)
	var r2 := exp(-PI * 110.0 / RATE)
	var A1 := 0.0
	var A2 := 0.0
	var jit := 0.0
	var cnt := int(dur * RATE)
	for j in cnt:
		if i0 + j >= L.size():
			break
		var tau := float(j) / RATE
		var u := float(j) / cnt
		if j % 16 == 0:
			var fcn := lerpf(fc0, fc1, u * u * (3.0 - 2.0 * u)) * (1.0 + 0.04 * sin(TAU * 7.0 * tau))
			A1 = -2.0 * r1 * cos(TAU * fcn / RATE)
			A2 = -2.0 * r2 * cos(TAU * fcn * 2.13 / RATE)
			jit += 0.15 * ((rng.randf() - 0.5) - jit)
		ph += fp * (1.0 + 0.25 * jit + 0.2 * sin(TAU * 3.1 * tau)) / RATE
		var saw := 2.0 * fposmod(ph, 1.0) - 1.0
		var sl := 0.0 if saw < -0.7 else saw
		var src := sl * (0.6 + 0.4 * sin(TAU * 11.0 * tau + 2.0 * jit)) + 0.12 * (rng.randf() * 2.0 - 1.0)
		var y1 := (1.0 - r1) * src - A1 * y11 - r1 * r1 * y12
		y12 = y11
		y11 = y1
		var y2 := (1.0 - r2) * src - A2 * y21 - r2 * r2 * y22
		y22 = y21
		y21 = y2
		var env := smoothstep(0.0, 0.3, u) * (1.0 - smoothstep(0.7, 1.0, u))
		var v := (y1 + 0.5 * y2) * env * g * 1.6
		L[i0 + j] += v * gl
		R[i0 + j] += v * gr
		W[i0 + j] += v * 0.45


## breathy intake: noise through a bandpass that climbs, building until it stops abruptly
static func _inhale(L: PackedFloat32Array, R: PackedFloat32Array, W: PackedFloat32Array, rng: RandomNumberGenerator, t0: float, dur: float, g: float, pan: float) -> void:
	var i0 := int(t0 * RATE)
	var gl := _gl(pan)
	var gr := _gr(pan)
	var lo := 0.0
	var bd := 0.0
	var ff := 0.1
	var cnt := int(dur * RATE)
	for j in cnt:
		if i0 + j >= L.size() or i0 + j < 0:
			break
		var u := float(j) / cnt
		if j % 32 == 0:
			ff = 2.0 * sin(PI * (550.0 + 1500.0 * u) / RATE)
		var nz := rng.randf() * 2.0 - 1.0
		lo += ff * bd
		var hi := nz - lo - 0.5 * bd
		bd += ff * hi
		var env := pow(u, 1.6) * smoothstep(0.0, 0.08, u) * (1.0 - smoothstep(0.97, 1.0, u))
		env *= 0.75 + 0.25 * sin(TAU * 4.0 * u * dur)
		var v := bd * env * g * 1.5
		L[i0 + j] += v * gl
		R[i0 + j] += v * gr
		W[i0 + j] += v * 0.6


## soft sweep (noise whoosh), up = rising band, for memory transitions
static func _swell(L: PackedFloat32Array, R: PackedFloat32Array, W: PackedFloat32Array, rng: RandomNumberGenerator, t0: float, dur: float, g: float, pan: float, up: bool) -> void:
	if g <= 0.0:
		return
	var i0 := maxi(int(t0 * RATE), 0)
	var lo := 0.0
	var bd := 0.0
	var ff := 0.1
	var cnt := int(dur * RATE)
	for j in cnt:
		if i0 + j >= L.size():
			break
		var u := float(j) / cnt
		if j % 32 == 0:
			var fcs := 300.0 + 2400.0 * (u * u if up else (1.0 - u))
			ff = 2.0 * sin(PI * fcs / RATE)
		var nz := rng.randf() * 2.0 - 1.0
		lo += ff * bd
		var hi := nz - lo - 0.2 * bd
		bd += ff * hi
		var env := smoothstep(0.0, 1.0, u) * (1.0 - smoothstep(0.92, 1.0, u))
		var v := bd * env * g * 0.8
		var pp := pan + 0.5 * sin(u * 5.0)
		L[i0 + j] += v * _gl(pp)
		R[i0 + j] += v * _gr(pp)
		W[i0 + j] += v * 0.5


## shovel: scrape (sweeping band), earth thud (low noise + sub), scattering clods
static func _shovel(L: PackedFloat32Array, R: PackedFloat32Array, W: PackedFloat32Array, rng: RandomNumberGenerator, t0: float, g: float, pan: float) -> void:
	var gl := _gl(pan)
	var gr := _gr(pan)
	var i0 := int(t0 * RATE)
	var lo := 0.0
	var bd := 0.0
	var cnt := int(0.26 * RATE)
	for j in cnt:
		if i0 + j >= L.size():
			break
		var u := float(j) / cnt
		var ff := 2.0 * sin(PI * lerpf(1000.0, 420.0, u) / RATE)
		var nz := rng.randf() * 2.0 - 1.0
		lo += ff * bd
		var hi := nz - lo - 0.35 * bd
		bd += ff * hi
		var gr2 := 0.0
		if rng.randf() < 0.01:
			gr2 = (rng.randf() - 0.5)
		var v := (bd + gr2) * smoothstep(0.0, 0.2, u) * (1.0 - smoothstep(0.7, 1.0, u)) * g * 0.35
		L[i0 + j] += v * gl
		R[i0 + j] += v * gr
		W[i0 + j] += v * 0.3
	var it := i0 + int(0.3 * RATE)
	var lp := 0.0
	var ph := 0.0
	for j in int(0.5 * RATE):
		if it + j >= L.size():
			break
		var tau := float(j) / RATE
		lp += 0.06 * ((rng.randf() * 2.0 - 1.0) - lp)
		ph += TAU * (40.0 + 22.0 * exp(-tau / 0.05)) / RATE
		var v := (lp * 3.5 * exp(-tau / 0.07) + sin(ph) * exp(-tau / 0.16) * 0.9) * (1.0 - exp(-tau * 800.0)) * g * 0.8
		L[it + j] += v * gl
		R[it + j] += v * gr
		W[it + j] += v * 0.25
	for c in 9:
		var ic := it + int((0.05 + rng.randf() * 0.4) * RATE)
		var pc := pan + (rng.randf() - 0.5) * 1.0
		var cgl := _gl(pc)
		var cgr := _gr(pc)
		var lq := 0.0
		for j in int(0.02 * RATE):
			if ic + j >= L.size():
				break
			lq += 0.25 * ((rng.randf() * 2.0 - 1.0) - lq)
			var v := lq * exp(-float(j) / (0.006 * RATE)) * g * 0.28
			L[ic + j] += v * cgl
			R[ic + j] += v * cgr
			W[ic + j] += v * 0.25


static func _clink(L: PackedFloat32Array, R: PackedFloat32Array, W: PackedFloat32Array, rng: RandomNumberGenerator, t0: float, g: float, pan: float) -> void:
	var i0 := int(t0 * RATE)
	var gl := _gl(pan)
	var gr := _gr(pan)
	var f := 2800.0 + rng.randf() * 2400.0
	for j in int(0.06 * RATE):
		if i0 + j >= L.size():
			break
		var tau := float(j) / RATE
		var v := (sin(TAU * f * tau) + 0.6 * sin(TAU * f * 2.76 * tau)) * exp(-tau / 0.012) * g * 0.3 * (1.0 - exp(-tau * 4000.0))
		L[i0 + j] += v * gl
		R[i0 + j] += v * gr
		W[i0 + j] += v * 0.5


static func _coin(L: PackedFloat32Array, R: PackedFloat32Array, W: PackedFloat32Array, t0: float, f0: float, g: float, ring: float, pan: float) -> void:
	var parts: Array = [[1.0, 1.0, 0.45], [2.756, 0.7, 0.22], [5.404, 0.45, 0.11], [8.933, 0.3, 0.06]]
	var i0 := int(t0 * RATE)
	var gl := _gl(pan)
	var gr := _gr(pan)
	for p in parts:
		var f: float = f0 * p[0]
		if f > 7300.0:
			continue
		var dec: float = p[2] * ring
		var cnt := int(minf(dec * 5.0, 3.0) * RATE)
		for j in cnt:
			if i0 + j >= L.size():
				break
			var tau := float(j) / RATE
			var e := exp(-tau / dec) * (1.0 - exp(-tau * 2500.0))
			var v := (sin(TAU * f * tau) + 0.5 * sin(TAU * f * 1.0035 * tau + 1.0)) * e * g * float(p[1]) * 0.45
			L[i0 + j] += v * gl
			R[i0 + j] += v * gr
			W[i0 + j] += v * 0.6


static func _pluck(L: PackedFloat32Array, R: PackedFloat32Array, W: PackedFloat32Array, t0: float, f0: float, g: float, pan: float) -> void:
	var i0 := int(t0 * RATE)
	var gl := _gl(pan)
	var gr := _gr(pan)
	for h in 4:
		var f := f0 * (h + 1) * (1.0 + 0.0006 * h * h)
		if f > 7300.0:
			break
		var dec := 0.9 / (1.0 + h * 0.8)
		for j in int(dec * 4.0 * RATE):
			if i0 + j >= L.size():
				break
			var tau := float(j) / RATE
			var v := sin(TAU * f * tau) * exp(-tau / dec) * (1.0 - exp(-tau * 1500.0)) * g / (1.0 + h * 0.9)
			L[i0 + j] += v * gl
			R[i0 + j] += v * gr
			W[i0 + j] += v * 0.7


## sustained glass-bell halo: just-intonation partials with slow tremolo; a semitone sours it downward at the end
static func _shimmer(L: PackedFloat32Array, R: PackedFloat32Array, W: PackedFloat32Array, t0: float, dur: float, f0: float, g: float) -> void:
	var i0 := int(t0 * RATE)
	var rats: Array = [1.0, 5.0 / 4.0, 3.0 / 2.0, 15.0 / 8.0, 2.0, 5.0 / 2.0]
	var ph := PackedFloat32Array()
	ph.resize(6)
	var kg := PackedFloat32Array()
	kg.resize(6)
	var kl := PackedFloat32Array()
	kl.resize(6)
	var kr := PackedFloat32Array()
	kr.resize(6)
	var cnt := int(dur * RATE)
	for j in cnt:
		if i0 + j >= L.size():
			break
		var tau := float(j) / RATE
		var u := float(j) / cnt
		var sour := 1.0 - 0.055 * smoothstep(0.78, 1.0, u)
		var env := smoothstep(0.0, 0.25, u) * (1.0 - smoothstep(0.85, 1.0, u))
		if j % 64 == 0:
			for k in 6:
				kg[k] = (0.6 + 0.4 * sin(TAU * (0.4 + 0.13 * k) * tau + k * 1.7)) / (1.0 + k * 0.35)
				kl[k] = _gl(-0.7 + 0.28 * k) * kg[k]
				kr[k] = _gr(-0.7 + 0.28 * k) * kg[k]
		var sl := 0.0
		var sr := 0.0
		for k in 6:
			var p := ph[k] + TAU * f0 * float(rats[k]) * sour / RATE
			if p > TAU:
				p -= TAU
			ph[k] = p
			var sp := sin(p)
			sl += sp * kl[k]
			sr += sp * kr[k]
		sl *= env * g
		sr *= env * g
		L[i0 + j] += sl
		R[i0 + j] += sr
		W[i0 + j] += (sl + sr) * 0.4


## Shepard-Risset glissando: seven octave-spaced partials under a raised-cosine spectral window, ever rising and quickening
static func _shepard(L: PackedFloat32Array, R: PackedFloat32Array, W: PackedFloat32Array, t0: float, dur: float, g: float) -> void:
	var i0 := int(t0 * RATE)
	var nc := 7
	var ph := PackedFloat32Array()
	ph.resize(nc)
	var inc := PackedFloat32Array()
	inc.resize(nc)
	var amp := PackedFloat32Array()
	amp.resize(nc)
	var pos := 0.0
	var spl := 0.7
	var spr := 0.7
	var cnt := int(dur * RATE)
	for j in cnt:
		if i0 + j >= L.size():
			break
		var u := float(j) / cnt
		if j % 64 == 0:
			pos += lerpf(0.3, 1.5, u * u) * 64.0 / RATE
			for k in nc:
				var x := fposmod(pos + k, float(nc))
				inc[k] = TAU * 32.7 * pow(2.0, x) / RATE
				var s0 := sin(PI * x / nc)
				amp[k] = s0 * s0
		var s := 0.0
		for k in nc:
			var p := ph[k] + inc[k]
			if p > TAU:
				p -= TAU
			ph[k] = p
			s += amp[k] * sin(p)
		var env := smoothstep(0.0, 0.2, u) * (0.35 + 0.65 * u)
		var v := s * env * g * 0.22
		if j % 64 == 0:
			var pp := 0.5 * sin(TAU * 0.35 * u * dur)
			spl = _gl(pp)
			spr = _gr(pp)
		L[i0 + j] += v * spl
		R[i0 + j] += v * spr
		W[i0 + j] += v * 0.3


static func _bell(L: PackedFloat32Array, R: PackedFloat32Array, W: PackedFloat32Array, t0: float, f0: float, g: float, ring: float, pan: float) -> void:
	var ratios: Array = [0.5, 1.0, 1.183, 1.506, 2.0, 2.514, 2.662, 3.011, 4.166]
	var i0 := int(t0 * RATE)
	var gl := _gl(pan)
	var gr := _gr(pan)
	for pi in ratios.size():
		var f: float = f0 * ratios[pi]
		if f > 7300.0:
			continue
		var dec := ring / (1.0 + pi * 0.5)
		for j in int(minf(dec * 4.0, 3.4) * RATE):
			if i0 + j >= L.size():
				break
			var tau := float(j) / RATE
			var e := exp(-tau / dec) * (1.0 - exp(-tau * 40.0))
			var v := sin(TAU * f * tau + pi) * e * g / (1.0 + pi * 0.3)
			L[i0 + j] += v * gl
			R[i0 + j] += v * gr
			W[i0 + j] += v * 0.5


## whisper / voice syllable: glottal saw + breath noise through three two-pole formant resonators.
## vow2 (optional) = vowel to glide to; fs = formant scale (goblin: small tract, >1); arch = pitch arc; rasp = jitter
static func _voice(L: PackedFloat32Array, R: PackedFloat32Array, W: PackedFloat32Array, rng: RandomNumberGenerator, t0: float, dur: float,
		f0: float, vow: Array, breath: float, g: float, wetk: float, glide: float, pan: float = 0.0, vow2: Array = [],
		fs: float = 1.0, arch: float = 0.0, rasp: float = 0.0) -> void:
	var i0 := int(t0 * RATE)
	var gl := _gl(pan)
	var gr := _gr(pan)
	var v2: Array = vow2 if not vow2.is_empty() else vow
	var r1 := exp(-PI * 90.0 / RATE)
	var r2 := exp(-PI * 120.0 / RATE)
	var r3 := exp(-PI * 180.0 / RATE)
	var A1 := -2.0 * r1 * cos(TAU * float(vow[0]) * fs / RATE)
	var A2 := -2.0 * r2 * cos(TAU * float(vow[1]) * fs / RATE)
	var A3 := -2.0 * r3 * cos(TAU * float(vow[2]) * fs / RATE)
	var y11 := 0.0
	var y12 := 0.0
	var y21 := 0.0
	var y22 := 0.0
	var y31 := 0.0
	var y32 := 0.0
	var phase := 0.0
	var cnt := int(dur * RATE)
	for j in cnt:
		if i0 + j >= L.size() or i0 + j < 0:
			break
		var tau := float(j) / RATE
		var u := float(j) / cnt
		if j % 16 == 0:
			var mw := smoothstep(0.0, 1.0, u)
			A1 = -2.0 * r1 * cos(TAU * lerpf(float(vow[0]), float(v2[0]), mw) * fs / RATE)
			A2 = -2.0 * r2 * cos(TAU * lerpf(float(vow[1]), float(v2[1]), mw) * fs / RATE)
			A3 = -2.0 * r3 * cos(TAU * lerpf(float(vow[2]), float(v2[2]), mw) * fs / RATE)
		var env := smoothstep(0.0, 0.012, tau) * (1.0 - smoothstep(dur * 0.5, dur, tau))
		phase += f0 * (1.0 + glide * u + arch * sin(PI * u)) * (1.0 + 0.025 * sin(TAU * 6.0 * tau) + rasp * (rng.randf() - 0.5)) / RATE
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
		var vd := v * (1.0 - wetk * 0.5)
		L[i0 + j] += vd * gl
		R[i0 + j] += vd * gr
		W[i0 + j] += v * wetk


## a phrase of `nsyl` whispered/voiced gibberish syllables (counts are Fibonacci numbers), pitch arcing, consonant bursts between
static func _phrase(L: PackedFloat32Array, R: PackedFloat32Array, W: PackedFloat32Array, rng: RandomNumberGenerator, t0: float, nsyl: int,
		f0: float, g: float, breath: float, wetk: float, pan: float, fs: float) -> float:
	var vows: Array = [VOW_A, VOW_O, VOW_E, VOW_I, VOW_U]
	var t := t0
	for s in nsyl:
		var u := float(s) / maxf(float(nsyl - 1), 1.0)
		var d := 0.085 + rng.randf() * 0.09
		var f := f0 * (1.0 + 0.25 * sin(PI * u) - 0.12 * u + 0.1 * (rng.randf() - 0.5))
		var va: Array = vows[rng.randi() % 5]
		var vb: Array = vows[rng.randi() % 5]
		var gs := g * (0.6 + 0.4 * sin(PI * (0.1 + 0.8 * u)))
		_voice(L, R, W, rng, t, d, f, va, breath, gs, wetk, rng.randf() * 0.3 - 0.15, pan + 0.15 * (rng.randf() - 0.5), vb, fs, 0.05, 0.12)
		t += d
		var c := rng.randf()
		if c < 0.35:
			_burst(L, R, W, rng, t, 0.012, gs * 0.7, pan, 1)
		elif c < 0.6:
			_burst(L, R, W, rng, t, 0.05, gs * 0.5, pan, 2)
		t += 0.03 + rng.randf() * 0.05
	return t


## Schroeder reverb at 8 kHz: four damped combs mixed to L/R by orthogonal sign rows, then per-channel allpass pairs
static func _reverb(W: PackedFloat32Array, job: Dictionary, kill_t: float = 1.0e9) -> Array:
	var ki := int(minf(kill_t, 1.0e6) * 8000.0)
	var rr := 8000
	var m := (W.size() >> 1) + 2
	var oL := PackedFloat32Array()
	oL.resize(m)
	var oR := PackedFloat32Array()
	oR.resize(m)
	var d0 := int(0.0437 * rr)
	var d1 := int(0.0517 * rr)
	var d2 := int(0.0611 * rr)
	var d3 := int(0.0709 * rr)
	var c0 := PackedFloat32Array()
	c0.resize(d0)
	var c1 := PackedFloat32Array()
	c1.resize(d1)
	var c2 := PackedFloat32Array()
	c2.resize(d2)
	var c3 := PackedFloat32Array()
	c3.resize(d3)
	var p0 := 0
	var p1 := 0
	var p2 := 0
	var p3 := 0
	var lp0 := 0.0
	var lp1 := 0.0
	var lp2 := 0.0
	var lp3 := 0.0
	var aL1 := PackedFloat32Array()
	aL1.resize(41)
	var aL2 := PackedFloat32Array()
	aL2.resize(14)
	var aR1 := PackedFloat32Array()
	aR1.resize(49)
	var aR2 := PackedFloat32Array()
	aR2.resize(17)
	var q1 := 0
	var q2 := 0
	var q3 := 0
	var q4 := 0
	var wn := W.size()
	for i in m:
		if i % 4096 == 0 and job.get("cancel", false):
			return []
		if i == ki:
			c0.fill(0.0)
			c1.fill(0.0)
			c2.fill(0.0)
			c3.fill(0.0)
			aL1.fill(0.0)
			aL2.fill(0.0)
			aR1.fill(0.0)
			aR2.fill(0.0)
			lp0 = 0.0
			lp1 = 0.0
			lp2 = 0.0
			lp3 = 0.0
		var k := i * 2
		var x := 0.5 * ((W[k] if k < wn else 0.0) + (W[k + 1] if k + 1 < wn else 0.0))
		var y0 := c0[p0]
		lp0 += 0.4 * (y0 - lp0)
		c0[p0] = x + lp0 * 0.89
		p0 += 1
		if p0 >= d0:
			p0 = 0
		var y1 := c1[p1]
		lp1 += 0.4 * (y1 - lp1)
		c1[p1] = x + lp1 * 0.885
		p1 += 1
		if p1 >= d1:
			p1 = 0
		var y2 := c2[p2]
		lp2 += 0.4 * (y2 - lp2)
		c2[p2] = x + lp2 * 0.88
		p2 += 1
		if p2 >= d2:
			p2 = 0
		var y3 := c3[p3]
		lp3 += 0.4 * (y3 - lp3)
		c3[p3] = x + lp3 * 0.875
		p3 += 1
		if p3 >= d3:
			p3 = 0
		var sL := (y0 + y1 - y2 - y3) * 0.35
		var sR := (y0 - y1 + y2 - y3) * 0.35
		var z1 := aL1[q1]
		var o1 := -0.5 * sL + z1
		aL1[q1] = sL + 0.5 * o1
		q1 += 1
		if q1 >= 41:
			q1 = 0
		var z2 := aL2[q2]
		var o2 := -0.5 * o1 + z2
		aL2[q2] = o1 + 0.5 * o2
		q2 += 1
		if q2 >= 14:
			q2 = 0
		oL[i] = o2
		var z3 := aR1[q3]
		var o3 := -0.5 * sR + z3
		aR1[q3] = sR + 0.5 * o3
		q3 += 1
		if q3 >= 49:
			q3 = 0
		var z4 := aR2[q4]
		var o4 := -0.5 * o3 + z4
		aR2[q4] = o3 + 0.5 * o4
		q4 += 1
		if q4 >= 17:
			q4 = 0
		oR[i] = o4
	return [oL, oR]
