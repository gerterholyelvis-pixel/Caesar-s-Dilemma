extends RefCounted
class_name FallScore

## Fully synthesised orchestral-awe score for the fall. bake(variant, dur) is meant for a worker Thread.
## Everything is D (D1 = 36.708 Hz) in just intonation: 1, 16/15, 5/4, 4/3, 3/2, 8/5, 9/5 (phrygian dominant).
## Variants: 0 A "Cathedral abyss" (formant choir over sub drone, Euclidean timpani, held then cut)
##           1 B "Endless descent"  (Shepard-Risset falling tones, rising brass swell, accelerating heartbeat, colossal chord)
##           2 C "Grand minor-sublime" (Fibonacci-phrased phrygian-dominant melody, gong + chord change at every vista)
##           3 D "Mixture" (the lot, edited for restraint)
## Common tools: additive voices with slow attacks, vowel-formant harmonic weights, inharmonic bell/gong partials,
## Schroeder comb/allpass hall, tanh glue, final peak <= 0.48.

const RATE := 16000
const D1 := 36.708
const VT := [14.8, 18.8, 22.8, 26.6, 30.2, 33.4]
const T_CEIL := 36.5
const LETTERS := ["A", "B", "C", "D"]
const TITLES := ["Cathedral abyss", "Endless descent", "Grand minor-sublime", "Mixture"]
const PD := [1.0, 16.0 / 15.0, 5.0 / 4.0, 4.0 / 3.0, 3.0 / 2.0, 8.0 / 5.0, 9.0 / 5.0]
const BELL_R := [0.5, 1.0, 1.183, 1.506, 2.0, 2.514, 2.662, 3.0, 4.166, 5.43]
const BELL_A := [0.6, 1.0, 0.7, 0.55, 0.6, 0.35, 0.3, 0.25, 0.15, 0.1]
const BELL_T := [4.0, 3.5, 3.0, 2.6, 2.2, 1.8, 1.6, 1.3, 1.0, 0.8]
const GONG_R := [1.0, 1.19, 1.52, 1.98, 2.51, 2.74, 3.41, 4.17, 5.1, 7.3, 9.8]
const GONG_A := [1.0, 0.8, 0.7, 0.6, 0.5, 0.45, 0.35, 0.25, 0.15, 0.08, 0.05]
const GONG_T := [7.0, 6.0, 5.5, 5.0, 4.2, 3.5, 3.0, 2.2, 1.5, 1.2, 1.0]
const VOWELS := [
	[[800.0, 1.0, 90.0], [1150.0, 0.55, 110.0], [2900.0, 0.18, 200.0]],   # ah
	[[450.0, 1.0, 70.0], [820.0, 0.45, 90.0], [2830.0, 0.10, 180.0]],     # oh
	[[300.0, 0.8, 60.0], [2300.0, 0.6, 150.0], [3000.0, 0.3, 200.0]],     # ee
]
const ENERGY := [[0.0, 0.0], [3.0, 0.07], [8.0, 0.16], [12.0, 0.30], [14.8, 0.50], [18.8, 0.58], [22.8, 0.68], [26.6, 0.78],
	[30.2, 0.88], [33.4, 0.97], [36.5, 1.0], [39.5, 0.85], [42.0, 0.55], [44.0, 0.38], [46.0, 0.0]]

static var current := 3
static var cancel := false
static var last_ms := 0


static func parse_cmdline() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--score="):
			var i := LETTERS.find(a.substr(8).to_upper())
			if i >= 0:
				current = i


static func letter() -> String:
	return LETTERS[clampi(current, 0, 3)]


# ---------------------------------------------------------------- curves / helpers
static func _kf(t: float, keys: Array) -> float:
	if t <= float(keys[0][0]):
		return float(keys[0][1])
	for j in keys.size() - 1:
		if t <= float(keys[j + 1][0]):
			return lerpf(float(keys[j][1]), float(keys[j + 1][1]), smoothstep(float(keys[j][0]), float(keys[j + 1][0]), t))
	return float(keys[keys.size() - 1][1])


static func _curve(keys: Array, dur: float) -> PackedFloat32Array:
	var n := int(dur * 100.0) + 3
	var c := PackedFloat32Array()
	c.resize(n)
	for i in n:
		c[i] = _kf(i * 0.01, keys)
	return c


static func _pw(c: PackedFloat32Array, p: float) -> PackedFloat32Array:
	var o := PackedFloat32Array()
	o.resize(c.size())
	for i in c.size():
		o[i] = pow(c[i], p)
	return o


static func _cv(c: PackedFloat32Array, t: float) -> float:
	var ci := t * 100.0
	var k := clampi(int(ci), 0, c.size() - 2)
	return lerpf(c[k], c[k + 1], clampf(ci - k, 0.0, 1.0))


static func _step_for(fp: float) -> int:
	if fp < 180.0:
		return 8
	if fp < 700.0:
		return 4
	if fp < 2400.0:
		return 2
	return 1


static func _freq(idx: int) -> float:
	# phrygian-dominant degree index, 0 = D2, 7 = D3
	return D1 * 2.0 * float(PD[posmod(idx, 7)]) * pow(2.0, floorf(idx / 7.0))


## Euclidean rhythm hit test (Bresenham form): E(k, n)
static func _hit(i: int, k: int, n: int) -> bool:
	return (posmod(i, n) * k) % n < k


# ---------------------------------------------------------------- voices
## additive tone with slow attack; partial p = ratios[p] * f, weights amps[p]; curve = loudness over absolute time
static func _tone(b: PackedFloat32Array, t0: float, dur: float, f: float, ratios: Array, amps: Array, gain: float,
		atk: float, rel: float, curve: PackedFloat32Array, vib := 0.0, vhz := 5.2, vph := 0.0) -> void:
	if cancel:
		return
	var i0 := maxi(int(t0 * RATE), 0)
	var cnt := mini(int(dur * RATE), b.size() - i0)
	if cnt <= 8:
		return
	var nb := (cnt >> 4) + 2
	var env := PackedFloat32Array()
	env.resize(nb)
	var vp := PackedFloat32Array()
	if vib > 0.0:
		vp.resize(nb)
	var cl := curve.size() - 2
	var inv_a := 1.0 / maxf(atk, 0.001)
	var inv_r := 1.0 / maxf(rel, 0.001)
	var rc := 100.0 / RATE
	for q in nb:
		var j := mini(q << 4, cnt - 1)
		var t := float(j) / RATE
		var ea := minf(t * inv_a, 1.0)
		var er := clampf((dur - t) * inv_r, 0.0, 1.0)
		var ci := float(i0 + j) * rc
		var k := mini(int(ci), cl)
		env[q] = ea * ea * (3.0 - 2.0 * ea) * er * er * (3.0 - 2.0 * er) * lerpf(curve[k], curve[k + 1], ci - k) * gain
		if vib > 0.0:
			vp[q] = vib * minf(t * 0.4, 1.0) * sin(TAU * vhz * t + vph)
	var w := TAU * f / RATE
	for p in ratios.size():
		var r: float = ratios[p]
		var a: float = amps[p]
		if a <= 0.0:
			continue
		var st := _step_for(f * r)
		var wr := w * r
		var prev := 0.0
		for j in range(0, cnt, st):
			var ph := wr * j
			if vib > 0.0:
				ph += r * vp[j >> 4]
			var v := a * env[j >> 4] * sin(ph)
			b[i0 + j] += v
			if st > 1 and j > 0:
				var y := prev
				var dy := (v - prev) / st
				for m in range(1, st):
					y += dy
					b[i0 + j - st + m] += y
			prev = v


## struck inharmonic partials (bells, gongs); each partial decays with its own time constant
static func _strike(b: PackedFloat32Array, t0: float, f: float, ratios: Array, amps: Array, taus: Array, gain: float,
		atk: float, dur: float, tscale := 1.0) -> void:
	if cancel:
		return
	var i0 := maxi(int(t0 * RATE), 0)
	var cnt := mini(int(dur * RATE), b.size() - i0)
	if cnt <= 8:
		return
	for p in ratios.size():
		var r: float = ratios[p]
		var fp := f * r
		if fp > 7000.0:
			continue
		var st := _step_for(fp)
		var wr := TAU * fp / RATE
		var e := 1.0
		var dec := exp(-float(st) / (float(taus[p]) * tscale * RATE))
		var ae := 1.0 if atk > 0.0 else 0.0
		var aec := exp(-float(st) / (atk * RATE)) if atk > 0.0 else 0.0
		var ga := gain * float(amps[p])
		var prev := 0.0
		for j in range(0, cnt, st):
			var v := ga * e * (1.0 - ae) * sin(wr * j)
			e *= dec
			ae *= aec
			b[i0 + j] += v
			if st > 1 and j > 0:
				var y := prev
				var dy := (v - prev) / st
				for m in range(1, st):
					y += dy
					b[i0 + j - st + m] += y
			prev = v


## membrane drum: pitch-dropping sine, skin overtone and a soft noise thump (sk = amount of skin/thump)
static func _drum(b: PackedFloat32Array, t0: float, f: float, gain: float, tau: float, sk: float) -> void:
	if cancel:
		return
	var i0 := maxi(int(t0 * RATE), 0)
	var cnt := mini(int(tau * 6.0 * RATE), b.size() - i0)
	if cnt <= 8:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(t0 * 1000.0) + int(f)
	var ph := 0.0
	var lp := 0.0
	for j in cnt:
		var t := float(j) / RATE
		ph += TAU * f * (1.0 + 0.5 * exp(-t * 22.0)) / RATE
		lp += 0.2 * (rng.randf() * 2.0 - 1.0 - lp)
		var v := sin(ph) * exp(-t / tau)
		if sk > 0.0:
			v += sk * (0.35 * sin(ph * 1.505) * exp(-t * 2.0 / tau) + 1.4 * lp * exp(-t * 70.0))
		b[i0 + j] += v * gain


## vowel-formant harmonic weights for a sung note at f
static func _vowel(f: float, vi: int) -> Array:
	var fm: Array = VOWELS[vi]
	var rs := []
	var am := []
	var mx := 0.0
	var tot := 0.0
	var k := 1
	while k * f < 2400.0 and k <= 40:
		var kf := f * k
		var a := 0.0
		for q in fm:
			var z: float = (kf - float(q[0])) / float(q[2])
			a += float(q[1]) * exp(-0.5 * z * z)
		a = a * pow(float(k), -0.45) + 0.02
		if k == 1:
			a += 0.5
		elif k == 2:
			a += 0.18
		rs.append(float(k))
		am.append(a)
		mx = maxf(mx, a)
		tot += a * a
		k += 1
	var ro := []
	var ao := []
	var nrm := 1.0 / sqrt(maxf(tot, 0.001))
	for i in rs.size():
		if float(am[i]) >= 0.16 * mx and ro.size() < 10:
			ro.append(rs[i])
			ao.append(float(am[i]) * nrm)
	return [ro, ao]


static func _choir(b: PackedFloat32Array, t0: float, dur: float, f: float, vi: int, gain: float, atk: float, rel: float,
		curve: PackedFloat32Array) -> void:
	var va := _vowel(f, vi)
	_tone(b, t0, dur, f * 0.9962, va[0], va[1], gain, atk, rel, curve, 0.12, 4.9, f * 0.37)
	_tone(b, t0, dur, f * 1.0041, va[0], va[1], gain, atk, rel, curve, 0.12, 5.5, f * 0.91)


## ratios are multiples of D1
static func _chord(b: PackedFloat32Array, t0: float, dur: float, rs: Array, vi: int, gain: float, atk: float, rel: float,
		curve: PackedFloat32Array) -> void:
	for i in rs.size():
		_choir(b, t0, dur, D1 * float(rs[i]), vi, gain * (1.0 - 0.05 * i), atk, rel, curve)


## orchestral brass/string-like swell: dark layer follows the curve, bright layer opens only near the peak
static func _brass(b: PackedFloat32Array, t0: float, dur: float, f: float, gain: float, atk: float, rel: float,
		curve: PackedFloat32Array, bright: PackedFloat32Array) -> void:
	var lr := [1.0, 2.0, 3.0, 4.0, 5.0]
	var la := [1.0, 0.8, 0.6, 0.45, 0.3]
	var hr := [6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 14.0]
	var ha := [0.22, 0.2, 0.17, 0.14, 0.12, 0.1, 0.08, 0.06]
	for d in [0.9972, 1.0031]:
		_tone(b, t0, dur, f * d, lr, la, gain, atk, rel, curve, 0.08, 4.4, f)
		_tone(b, t0, dur, f * d, hr, ha, gain * 1.4, atk, rel, bright, 0.08, 4.4, f)


static func _sub(b: PackedFloat32Array, t0: float, dur: float, gain: float, curve: PackedFloat32Array) -> void:
	_tone(b, t0, dur, D1, [1.0, 2.0, 3.0], [1.0, 0.35, 0.12], gain, 6.0, 4.0, curve)
	_tone(b, t0, dur, D1 * 1.0036, [1.0, 2.0], [0.7, 0.25], gain, 8.0, 4.0, curve)     # ~0.13 Hz beating
	_tone(b, t0, dur, D1 * 1.5, [1.0, 2.0], [0.5, 0.15], gain * 0.6, 9.0, 4.0, curve)


## Shepard-Risset glissando: octave-spaced sines under a fixed gaussian spectral window sliding down forever
static func _shepard(b: PackedFloat32Array, t0: float, t1: float, gain: float, curve: PackedFloat32Array, rate_keys: Array,
		sets: Array, fmin := 30.0, noct := 7) -> void:
	if cancel:
		return
	var i0 := maxi(int(t0 * RATE), 0)
	var i1 := mini(int(t1 * RATE), b.size())
	var nc := noct * sets.size()
	var ph := PackedFloat64Array()
	ph.resize(nc)
	var am := PackedFloat32Array()
	am.resize(nc)
	var fr := PackedFloat32Array()
	fr.resize(nc)
	var s := 0.0
	for i in range(i0, i1):
		var t := float(i) / RATE
		if (i & 63) == 0:
			var e := _cv(curve, t) * gain * smoothstep(t0, t0 + 3.0, t) * (1.0 - smoothstep(t1 - 3.0, t1, t))
			for o in sets.size():
				for c in noct:
					var x := fposmod(c - s + float(sets[o][0]), float(noct))
					var z := (x - noct * 0.5) / (noct * 0.2)
					var q := o * noct + c
					fr[q] = TAU * fmin * pow(2.0, x) / RATE
					am[q] = exp(-0.5 * z * z) * e * float(sets[o][1])
		s += _kf(t, rate_keys) / RATE
		var v := 0.0
		for q in nc:
			ph[q] += fr[q]
			if am[q] > 0.004:
				v += am[q] * sin(ph[q])
		b[i] += v


## rising riser: exponential upward sweep, three harmonics
static func _riser(b: PackedFloat32Array, t0: float, t1: float, f0: float, f1: float, gain: float, curve: PackedFloat32Array) -> void:
	if cancel:
		return
	var i0 := maxi(int(t0 * RATE), 0)
	var i1 := mini(int(t1 * RATE), b.size())
	var ph := 0.0
	for i in range(i0, i1):
		var t := float(i) / RATE
		var u := (t - t0) / (t1 - t0)
		var f := f0 * pow(f1 / f0, u * u * (3.0 - 2.0 * u) * 0.5 + u * 0.5)
		ph += TAU * f / RATE
		var e := _cv(curve, t) * gain * smoothstep(0.0, 0.1, u) * (1.0 - smoothstep(0.9, 1.0, u))
		b[i] += e * (sin(ph) + 0.4 * sin(2.0 * ph + 0.5) + 0.2 * sin(3.0 * ph + 1.1))


static func _note(b: PackedFloat32Array, t: float, d: float, f: float, gain: float, ec: PackedFloat32Array, bells: bool) -> void:
	var rr := [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 2.76, 5.4]
	var aa := [1.0, 0.7, 0.55, 0.4, 0.28, 0.2, 0.13, 0.09, 0.1, 0.05]
	_tone(b, t, d, f, rr, aa, gain, 0.5, 1.5, ec, 0.12, 5.1, f)
	_tone(b, t, d, f * 2.0, rr, aa, gain * 0.45, 0.6, 1.6, ec, 0.1, 5.4, f * 0.3)
	_tone(b, t, d, f * 0.5, [1.0, 2.0, 3.0, 4.0], [1.0, 0.6, 0.35, 0.15], gain * 0.7, 0.7, 1.8, ec)
	if bells:
		_strike(b, t, f * 2.0, BELL_R, BELL_A, BELL_T, gain * 0.28, 0.004, 3.2, 0.6)


static func _gong(b: PackedFloat32Array, t: float, root: float, gain: float) -> void:
	_strike(b, t, D1 * 2.0 * root, GONG_R, GONG_A, GONG_T, gain, 0.3, 9.0)


static func _timp_run(b: PackedFloat32Array, t0: float, t1: float, step: float, k: int, n: int, ec: PackedFloat32Array, gain: float) -> void:
	var i := 0
	var t := t0
	while t < t1:
		if _hit(i, k, n):
			var acc := posmod(i, n) == 0
			var e := _cv(ec, t)
			_drum(b, t, D1 * (1.5 if acc else 2.0), gain * (0.45 + 0.7 * e) * (1.0 if acc else 0.75), 0.55 if acc else 0.42, 1.0)
		i += 1
		t += step


static func _heart(b: PackedFloat32Array, t0: float, t1: float, bpm0: float, bpm1: float, gain: float, ec: PackedFloat32Array) -> void:
	var t := t0
	while t < t1:
		var u := (t - t0) / (t1 - t0)
		var per := 60.0 / lerpf(bpm0, bpm1, u * u)
		var g := gain * (0.35 + 0.65 * _cv(ec, t)) * (1.0 - smoothstep(0.85, 1.0, u))
		_drum(b, t, 50.0, g, 0.11, 0.2)
		_drum(b, t + minf(0.3, per * 0.34), 58.0, g * 0.7, 0.10, 0.15)
		t += per


static func _sparkle(b: PackedFloat32Array, t0: float, t1: float, gain: float, curve: PackedFloat32Array) -> void:
	var rs := [16.0, 18.0, 20.0, 24.0, 27.0, 30.0, 32.0, 36.0]
	var t := t0
	var i := 0
	while t < t1:
		var r: float = rs[(i * 3 + i / 3) % rs.size()]
		_tone(b, t, 7.0, D1 * r, [1.0], [1.0], gain, 3.0, 4.0, curve, 0.2, 3.1, i * 1.7)
		t += 3.1 + 0.5 * float(i % 3)
		i += 1


## Fibonacci-phrased melody on the phrygian dominant, durations are Fibonacci multiples of `beat`
static func _melody(b: PackedFloat32Array, t0: float, t1: float, beat: float, gain: float, ec: PackedFloat32Array, bells: bool, n0 := 0, n1 := 99) -> void:
	var fibs := [3, 2, 5, 3, 5, 3, 8, 2, 3, 5, 3, 5, 8, 3, 2, 5, 8, 3, 5, 2, 3, 8, 5, 13]
	var contour := [7, 6, 4, 3, 4, 6, 7, 9, 8, 6, 4, 6, 8, 10, 11, 13, 12, 11, 9, 11, 13, 14, 15, 14, 13, 11, 10, 9, 7]
	var t := t0
	var i := 0
	while t < t1 and i < fibs.size():
		var d: float = float(fibs[i]) * beat
		var idx: int = contour[mini(i, contour.size() - 1)]
		if i >= n0 and i < n1:
			_note(b, t, d + 1.3, _freq(idx), gain, ec, bells)
		t += d
		i += 1


## one vista mark: gong strike + swelling chord change that peaks at the strike
static func _vista(b: PackedFloat32Array, k: int, ec: PackedFloat32Array, gong_g: float, chord_g: float) -> void:
	var roots := [[1.0, 5.0 / 4.0], [16.0 / 15.0, 5.0 / 4.0], [4.0 / 3.0, 6.0 / 5.0], [3.0 / 2.0, 5.0 / 4.0], [8.0 / 5.0, 5.0 / 4.0], [1.0, 5.0 / 4.0]]
	var t: float = VT[k]
	var r: float = roots[k][0]
	var th: float = roots[k][1]
	var e := _cv(ec, t)
	_gong(b, t, r, gong_g * (0.5 + 0.8 * e))
	_chord(b, t - 2.4, 7.5, [r * 2.0, r * 3.0, r * 4.0, r * th * 4.0, r * 6.0], 0, chord_g * (0.6 + 0.6 * e), 2.4, 3.2, ec)


# ---------------------------------------------------------------- variants (each layer = one job on the worker pool)
## jobs: [bus (0 dry / 1 wet), Callable(buf)]
static func _cj(J: Array, t0: float, dur: float, rs: Array, vi: int, gain: float, atk: float, rel: float, curve: PackedFloat32Array) -> void:
	for i in rs.size():
		var f := D1 * float(rs[i])
		var g := gain * (1.0 - 0.05 * i)
		J.append([1, func(b: PackedFloat32Array) -> void: _choir(b, t0, dur, f, vi, g, atk, rel, curve)])


static func _bj(J: Array, t0: float, dur: float, f: float, gain: float, atk: float, rel: float, curve: PackedFloat32Array, bright: PackedFloat32Array) -> void:
	J.append([1, func(b: PackedFloat32Array) -> void: _brass(b, t0, dur, f, gain, atk, rel, curve, bright)])


static func _mj(J: Array, t0: float, t1: float, beat: float, gain: float, ec: PackedFloat32Array) -> void:
	for h in 3:
		J.append([1, func(b: PackedFloat32Array) -> void: _melody(b, t0, t1, beat, gain, ec, true, h * 8, h * 8 + 8)])


static func _vj(J: Array, ec: PackedFloat32Array, gong_g: float, chord_g: float) -> void:
	for k in 6:
		J.append([1, func(b: PackedFloat32Array) -> void: _vista(b, k, ec, gong_g, chord_g)])


static func _score_a(J: Array, ec: PackedFloat32Array, T: float) -> void:
	var e2 := _pw(ec, 2.0)
	var end := T - 1.55
	J.append([0, func(b: PackedFloat32Array) -> void: _sub(b, 0.5, T - 1.0, 0.36, ec)])
	_cj(J, 2.0, 15.0, [2.0, 3.0, 4.0, 6.0, 8.0], 0, 0.085, 5.0, 4.0, ec)
	_cj(J, 12.0, 14.0, [3.2, 4.8, 6.4, 9.6], 0, 0.085, 4.0, 4.0, ec)
	_cj(J, 20.0, 14.0, [8.0 / 3.0, 4.0, 16.0 / 3.0, 6.4, 8.0], 1, 0.085, 4.0, 4.0, ec)
	_cj(J, 29.0, end - 29.0, [2.0, 3.0, 4.0, 5.0, 6.0, 8.0, 10.0, 12.0], 0, 0.075, 5.0, 0.05, ec)
	_cj(J, 30.0, end - 30.0, [2.0, 3.0, 4.0, 6.0, 8.0], 1, 0.05, 6.0, 0.05, e2)
	var fn := func(b: PackedFloat32Array) -> void:
		_timp_run(b, 8.0, 24.0, 1.0, 3, 8, ec, 0.8)
		_timp_run(b, 24.0, 38.0, 0.8, 5, 8, ec, 0.85)
		_drum(b, T_CEIL, D1 * 1.5, 1.0, 0.8, 1.0)
		_drum(b, T_CEIL + 0.02, D1, 0.9, 1.0, 0.6)
	J.append([1, fn])
	J.append([1, func(b: PackedFloat32Array) -> void: _sparkle(b, 12.0, end - 4.0, 0.028, e2)])


static func _score_b(J: Array, ec: PackedFloat32Array, T: float) -> void:
	var e2 := _pw(ec, 2.0)
	var e3 := _pw(ec, 3.0)
	J.append([0, func(b: PackedFloat32Array) -> void: _sub(b, 1.0, T - 3.0, 0.25, ec)])
	J.append([1, func(b: PackedFloat32Array) -> void: _shepard(b, 0.5, T - 2.0, 0.11, ec, [[0.0, 0.07], [14.0, 0.11], [30.0, 0.2], [T, 0.26]], [[0.0, 1.0], [0.585, 0.55]])])
	J.append([1, func(b: PackedFloat32Array) -> void: _riser(b, 4.0, T_CEIL, 55.0, 880.0, 0.06, e2)])
	_bj(J, 6.0, 12.0, D1 * 2.0, 0.05, 5.0, 3.0, ec, e3)
	_bj(J, 6.0, 12.0, D1 * 3.0, 0.045, 5.0, 3.0, ec, e3)
	_bj(J, 15.0, 12.0, D1 * 4.0, 0.05, 4.0, 3.0, ec, e3)
	_bj(J, 15.0, 12.0, D1 * 4.8, 0.045, 4.0, 3.0, ec, e3)
	_bj(J, 24.0, 14.0, D1 * 6.0, 0.05, 4.0, 3.0, ec, e3)
	J.append([0, func(b: PackedFloat32Array) -> void: _heart(b, 4.0, 40.5, 48.0, 132.0, 0.42, ec)])
	var t := T_CEIL - 2.4
	for r in [1.0, 2.0, 3.0, 4.0, 4.8, 6.0, 8.0, 9.6, 12.0]:
		_bj(J, t, 9.0, D1 * float(r), 0.055, 2.4, 4.0, ec, ec)
	_cj(J, t, 9.0, [2.0, 3.0, 4.0, 6.0, 8.0], 0, 0.08, 2.4, 4.0, ec)
	var fn := func(b: PackedFloat32Array) -> void:
		_gong(b, T_CEIL, 1.0, 1.0)
		_drum(b, T_CEIL, D1 * 1.5, 1.0, 0.9, 1.0)
	J.append([1, fn])


static func _score_c(J: Array, ec: PackedFloat32Array, T: float) -> void:
	var e2 := _pw(ec, 2.0)
	J.append([0, func(b: PackedFloat32Array) -> void: _sub(b, 0.5, T - 1.5, 0.34, ec)])
	var fn := func(b: PackedFloat32Array) -> void:
		_tone(b, 1.0, T - 4.0, D1 * 2.0, [1.0, 2.0, 3.0, 4.0], [1.0, 0.5, 0.3, 0.12], 0.07, 7.0, 5.0, ec, 0.05, 0.11)
		_tone(b, 3.0, T - 6.0, D1 * 3.0, [1.0, 2.0, 3.0], [1.0, 0.4, 0.2], 0.05, 8.0, 5.0, ec)
	J.append([1, fn])
	_mj(J, 3.5, 42.0, 0.72, 0.1, ec)
	_vj(J, ec, 0.95, 0.075)
	_cj(J, T_CEIL - 2.5, 8.0, [2.0, 3.0, 4.0, 5.0, 6.0, 8.0, 12.0], 0, 0.085, 2.5, 4.0, ec)
	J.append([1, func(b: PackedFloat32Array) -> void: _sparkle(b, 14.0, 40.0, 0.024, e2)])


static func _score_d(J: Array, ec: PackedFloat32Array, T: float) -> void:
	var e2 := _pw(ec, 2.0)
	var e3 := _pw(ec, 3.0)
	J.append([0, func(b: PackedFloat32Array) -> void: _sub(b, 0.5, T - 1.5, 0.36, ec)])
	_cj(J, 2.0, T - 4.0, [2.0, 3.0, 4.0, 6.0], 0, 0.06, 6.0, 3.5, ec)
	_cj(J, 10.0, T - 12.0, [8.0, 9.0], 1, 0.025, 6.0, 3.5, e2)
	J.append([1, func(b: PackedFloat32Array) -> void: _strike(b, 5.0, D1 * 8.0, BELL_R, BELL_A, BELL_T, 0.1, 0.004, 7.0, 1.4)])
	J.append([1, func(b: PackedFloat32Array) -> void: _shepard(b, 7.0, 41.0, 0.06, ec, [[0.0, 0.06], [20.0, 0.1], [T, 0.2]], [[0.0, 1.0]], 30.0, 7)])
	J.append([0, func(b: PackedFloat32Array) -> void: _heart(b, 8.0, 34.0, 52.0, 104.0, 0.3, ec)])
	var fn := func(b: PackedFloat32Array) -> void:
		_timp_run(b, 10.0, 24.0, 1.0, 3, 8, ec, 0.6)
		_timp_run(b, 24.0, 38.0, 0.8, 5, 8, ec, 0.7)
		_drum(b, T_CEIL, D1 * 1.5, 1.0, 0.9, 1.0)
		_drum(b, T_CEIL, D1, 0.9, 1.0, 0.6)
	J.append([1, fn])
	_mj(J, 12.5, 42.0, 0.8, 0.055, ec)
	_vj(J, ec, 0.7, 0.07)
	_bj(J, 17.0, 20.0, D1 * 2.0, 0.035, 5.0, 4.0, ec, e3)
	_bj(J, 17.0, 20.0, D1 * 3.0, 0.03, 5.0, 4.0, ec, e3)
	J.append([1, func(b: PackedFloat32Array) -> void: _riser(b, 24.0, T_CEIL, 110.0, 1320.0, 0.035, e2)])
	var t := T_CEIL - 2.6
	for r in [2.0, 3.0, 4.0, 6.0, 8.0, 12.0]:
		_bj(J, t, 9.0, D1 * float(r), 0.045, 2.6, 4.2, ec, ec)
	_cj(J, t, 9.0, [2.0, 3.0, 4.0, 5.0, 6.0, 8.0, 10.0, 12.0], 0, 0.085, 2.6, 4.2, ec)
	var fg := func(b: PackedFloat32Array) -> void:
		_gong(b, T_CEIL, 1.0, 1.0)
		_gong(b, T_CEIL + 0.03, 0.5, 0.8)
	J.append([1, fg])
	J.append([1, func(b: PackedFloat32Array) -> void: _sparkle(b, 11.0, 41.0, 0.025, e2)])


static func _render(J: Array, n: int) -> Array:
	var bufs := []
	for j in J:
		var b := PackedFloat32Array()
		b.resize(n)
		bufs.append(b)
	var task := func(i: int) -> void:
		var fn: Callable = J[i][1]
		fn.call(bufs[i])
	var gid := WorkerThreadPool.add_group_task(task, J.size(), -1, true, "fall_score")
	WorkerThreadPool.wait_for_group_task_completion(gid)
	var dry := PackedFloat32Array()
	dry.resize(n)
	var wet := PackedFloat32Array()
	wet.resize(n)
	var cs := n / 16 + 1
	var sm := func(c: int) -> void:
		var a: int = c * cs
		var e: int = mini(a + cs, n)
		for q in J.size():
			var src: PackedFloat32Array = bufs[q]
			if int(J[q][0]) == 0:
				for i in range(a, e):
					dry[i] += src[i]
			else:
				for i in range(a, e):
					wet[i] += src[i]
	var gid2 := WorkerThreadPool.add_group_task(sm, 16, -1, true, "fall_score_sum")
	WorkerThreadPool.wait_for_group_task_completion(gid2)
	return [dry, wet]


# ---------------------------------------------------------------- hall + master
static func _reverb(x: PackedFloat32Array, rt60: float) -> PackedFloat32Array:
	var n := x.size()
	var out := PackedFloat32Array()
	out.resize(n)
	for d in [0.0437, 0.0571, 0.0683, 0.0797, 0.0929]:
		if cancel:
			return out
		var L := int(float(d) * RATE)
		var g := pow(10.0, -3.0 * float(d) / rt60)
		var buf := PackedFloat32Array()
		buf.resize(L)
		var idx := 0
		var lp := 0.0
		for i in n:
			var y := buf[idx]
			lp = y * 0.62 + lp * 0.38
			buf[idx] = x[i] + g * lp
			idx += 1
			if idx == L:
				idx = 0
			out[i] += y * 0.35
	for ap in [[0.0089, 0.7], [0.0031, 0.7]]:
		var L2 := int(float(ap[0]) * RATE)
		var g2: float = ap[1]
		var buf2 := PackedFloat32Array()
		buf2.resize(L2)
		var id2 := 0
		for i in n:
			var wd := buf2[id2]
			var w := out[i] + g2 * wd
			buf2[id2] = w
			out[i] = wd - g2 * w
			id2 += 1
			if id2 == L2:
				id2 = 0
	return out


static func _rms(x: PackedFloat32Array) -> float:
	var s := 0.0
	for i in range(0, x.size(), 4):
		s += x[i] * x[i]
	return sqrt(s / maxf(x.size() / 4.0, 1.0))


static func bake(variant: int, dur: float) -> AudioStreamWAV:
	var t_ms := Time.get_ticks_msec()
	var v := clampi(variant, 0, 3)
	var n := int(dur * RATE)
	var T := dur - 0.5
	var ec := _curve(ENERGY, dur)
	var J := []
	match v:
		0:
			_score_a(J, ec, T)
		1:
			_score_b(J, ec, T)
		2:
			_score_c(J, ec, T)
		_:
			_score_d(J, ec, T)
	var bus := _render(J, n)
	if cancel:
		return null
	var dry: PackedFloat32Array = bus[0]
	var wet: PackedFloat32Array = bus[1]
	var rt: float = [5.5, 5.0, 6.5, 6.0][v]
	var rev := _reverb(wet, rt)
	if cancel:
		return null
	# hall level relative to the wet bus, so the balance is independent of the gains above
	var ratio: float = [0.85, 0.8, 1.05, 0.95][v]
	var rg := ratio * _rms(wet) / maxf(_rms(rev), 1e-6)
	var pd := int(0.03 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var cs := n / 16 + 1
	var peaks := PackedFloat32Array()
	peaks.resize(16)
	var p1 := func(c: int) -> void:
		var pk := 0.0
		for i in range(c * cs, mini((c + 1) * cs, n)):
			var t := float(i) / RATE
			var m := smoothstep(0.0, 0.6, t)
			if v == 0:
				m *= 1.0 - smoothstep(T - 1.55, T - 1.51, t)      # held, then cut
			else:
				m *= 1.0 - smoothstep(T - 4.0, T - 0.6, t)
			var r := rev[i - pd] if i >= pd else 0.0
			var s := (dry[i] + wet[i] * 0.7 + r * rg) * m
			out[i] = s
			pk = maxf(pk, absf(s))
		peaks[c] = pk
	var g1 := WorkerThreadPool.add_group_task(p1, 16, -1, true, "fall_mix")
	WorkerThreadPool.wait_for_group_task_completion(g1)
	var pkmax := 0.0
	for q in 16:
		pkmax = maxf(pkmax, peaks[q])
	var nrm := 1.0 / maxf(pkmax, 1e-6)
	var tn := tanh(1.5)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var p2 := func(c: int) -> void:
		for i in range(c * cs, mini((c + 1) * cs, n)):
			var s := tanh(out[i] * nrm * 1.5) / tn * 0.48
			bytes.encode_s16(i * 2, int(clampf(s, -0.5, 0.5) * 32767.0))
	var g2 := WorkerThreadPool.add_group_task(p2, 16, -1, true, "fall_enc")
	WorkerThreadPool.wait_for_group_task_completion(g2)
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = RATE
	st.stereo = false
	st.data = bytes
	last_ms = Time.get_ticks_msec() - t_ms
	return st
