class_name HornVoice
extends RefCounted
# Offline synthesis of the Horn's voice: gibberish "language" of formant-filtered saw+noise syllables,
# just-intonation pitch contours, a brass-tube comb, bell shimmer on stresses, Schroeder reverb.
# bake() is heavy: call it from a worker thread, never per frame. Pure functions, no scene access.

const SR := 22050
const ROOT := 73.416 # D2
const TAIL := 2.3
const PEAK := 0.45
# Just-intonation ratios over the root (unison, 9/8, 5/4, 4/3, 3/2, 5/3, 15/8, octave)
const JI: Array = [1.0, 1.125, 1.25, 1.3333333, 1.5, 1.6666667, 1.875, 2.0]
# vowel formants F1,F2,F3 (a, o, u, e, i), shifted low for a large throat
const VOWELS: Array = [
	[700.0, 1100.0, 2600.0],
	[460.0, 800.0, 2500.0],
	[330.0, 680.0, 2400.0],
	[520.0, 1650.0, 2500.0],
	[310.0, 2000.0, 2800.0],
]
const VOWEL_PICK: Array = [0, 0, 1, 1, 2, 2, 3, 4]
const FORMANT_SHIFT := 0.86

static func plan(text: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(text)
	var syl: Array = []
	var words: Array = []
	var t := 0.3
	var pos := 0
	var prev_end := 0
	for tok in text.split(" ", true):
		var i1: int = pos + tok.length()
		pos = i1 + 1
		var letters := 0
		for k in tok.length():
			var ch := tok.substr(k, 1)
			if ch.to_upper() != ch.to_lower():
				letters += 1
		var w_t0 := t
		var last_ch := tok.substr(tok.length() - 1, 1) if tok.length() > 0 else ""
		var is_final := last_ch == "." or last_ch == "!"
		var question := last_ch == "?"
		if letters > 0:
			var n := clampi(int(round(letters / 2.7)), 1, 5)
			var base := rng.randi() % 4
			var shape := rng.randi() % 4
			if is_final:
				shape = 2
				base = rng.randi() % 2
			elif question:
				shape = 0
				base = 2 + rng.randi() % 2
			var stress_k := 0 if rng.randf() < 0.6 else n - 1
			for k in n:
				var fr := 0.0 if n == 1 else float(k) / float(n - 1)
				var idx := base
				match shape:
					0: idx = base + int(round(fr * 3.0))
					1: idx = base + int(round(sin(fr * PI) * 3.0))
					2: idx = base + 3 - int(round(fr * 3.0))
					_: idx = base + (k % 2) * 2
				idx = clampi(idx, 0, 7)
				var stressed := (k == stress_k)
				var d := (0.15 + rng.randf() * 0.05) * (1.4 if stressed else 1.0)
				var f0 := ROOT * float(JI[idx])
				var glide := 1.0 + (rng.randf() - 0.5) * 0.08
				if is_final and k == n - 1:
					glide = 0.8
				syl.append({
					"t0": t, "dur": d, "f0": f0, "f1": f0 * glide,
					"vowel": VOWEL_PICK[rng.randi() % VOWEL_PICK.size()],
					"cons": rng.randi() % 4, "stress": stressed,
				})
				t += d * 0.92
			t += 0.06
		else:
			t += 0.2
		var pause := 0.07
		if tok.ends_with(",") or tok.ends_with(";") or tok.ends_with(":"):
			pause = 0.26
		elif is_final or question:
			pause = 0.5
		t += pause
		words.append({"from": prev_end, "to": i1, "t0": w_t0, "t1": maxf(t - pause, w_t0 + 0.05)})
		prev_end = i1
	return {"syl": syl, "words": words, "dur": t + 0.2}

# Visible character count at time t (letters appear as each word is "spoken").
static func chars_at(p: Dictionary, t: float, total: int) -> int:
	var shown := 0
	for w in p.words:
		if t >= w.t1:
			shown = w.to
		elif t >= w.t0:
			var f: float = (t - w.t0) / maxf(w.t1 - w.t0, 0.001)
			shown = int(w.from + (w.to - w.from) * f)
			break
		else:
			break
	return mini(shown, total)

# Smoothed loudness envelope at ENV_RATE Hz, 0..1, derived from the plan (same on every machine).
const ENV_RATE := 50.0
static func envelope(p: Dictionary) -> PackedFloat32Array:
	var n := int((p.dur + 0.4) * ENV_RATE)
	var env := PackedFloat32Array()
	env.resize(n)
	for s in p.syl:
		var a := int(s.t0 * ENV_RATE)
		var b := mini(n - 1, int((s.t0 + s.dur + 0.1) * ENV_RATE))
		var amp := 1.0 if s.stress else 0.7
		for i in range(a, b + 1):
			var x: float = float(i) / ENV_RATE - s.t0
			var v := minf(maxf(x, 0.0) / 0.03, 1.0)
			if x > s.dur:
				v *= maxf(0.0, 1.0 - (x - s.dur) / 0.1)
			env[i] = maxf(env[i], v * amp)
	return env

static func _res(freq: float, bw: float) -> Vector3:
	var r := exp(-PI * bw / SR)
	return Vector3(1.0 - r, 2.0 * r * cos(TAU * freq / SR), -r * r)

static func bake(text: String) -> Dictionary:
	var p := plan(text)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(text) ^ 0x5bd1e995
	var total := int((p.dur + TAIL) * SR)
	var dry := PackedFloat32Array()
	dry.resize(total)
	var ph := 0.0
	var vib := 0.0
	var lp := 0.0
	var hp_x := 0.0
	var hp_y := 0.0
	var cf1 := 500.0
	var cf2 := 1000.0
	var cf3 := 2500.0
	var a1y1 := 0.0
	var a1y2 := 0.0
	var a2y1 := 0.0
	var a2y2 := 0.0
	var a3y1 := 0.0
	var a3y2 := 0.0
	var k1 := Vector3.ZERO
	var k2 := Vector3.ZERO
	var k3 := Vector3.ZERO
	var nan_count := 0
	for s in p.syl:
		var n0 := int(s.t0 * SR)
		var nd := int(s.dur * SR)
		var nrel := int(0.1 * SR)
		var tgt: Array = VOWELS[s.vowel]
		var t1: float = tgt[0] * FORMANT_SHIFT
		var t2: float = tgt[1] * FORMANT_SHIFT
		var t3: float = tgt[2] * FORMANT_SHIFT
		var amp := 1.0 if s.stress else 0.72
		# consonant onset: 0 hiss, 1 click, 2 nasal murmur (no burst), 3 none
		var cons: int = s.cons
		if cons < 2:
			var nb := int((0.045 if cons == 0 else 0.014) * SR)
			var cfreq := 3600.0 if cons == 0 else 1400.0
			var kc := _res(cfreq, 900.0 if cons == 0 else 500.0)
			var y1 := 0.0
			var y2 := 0.0
			for i in nb:
				var idx := n0 - nb + i
				if idx < 0 or idx >= total:
					continue
				var x := rng.randf() * 2.0 - 1.0
				var y := kc.x * x + kc.y * y1 + kc.z * y2
				y2 = y1
				y1 = y
				var e := sin(PI * float(i) / float(nb))
				dry[idx] += y * e * (0.55 if cons == 0 else 1.1)
		for i in nd + nrel:
			var idx := n0 + i
			if idx >= total:
				break
			if i % 32 == 0:
				cf1 += (t1 - cf1) * 0.12
				cf2 += (t2 - cf2) * 0.12
				cf3 += (t3 - cf3) * 0.12
				k1 = _res(cf1, 95.0)
				k2 = _res(cf2, 120.0)
				k3 = _res(cf3, 180.0)
			var u := clampf(float(i) / float(maxi(nd, 1)), 0.0, 1.0)
			vib += TAU * 4.6 / SR
			var f0: float = lerpf(s.f0, s.f1, u) * (1.0 + 0.007 * sin(vib))
			ph += f0 / SR
			if ph >= 1.0:
				ph -= 1.0
			var saw := 2.0 * ph - 1.0
			lp += 0.28 * (saw - lp)
			var ex := lp * 1.6 + (rng.randf() * 2.0 - 1.0) * 0.07
			# amplitude envelope
			var tt := float(i) / SR
			var env := minf(tt / 0.028, 1.0)
			if i > nd:
				env *= maxf(0.0, 1.0 - float(i - nd) / float(nrel))
			if cons == 2:
				env *= minf(0.35 + tt / 0.06, 1.0)
			var y_a := k1.x * ex + k1.y * a1y1 + k1.z * a1y2
			a1y2 = a1y1
			a1y1 = y_a
			var y_b := k2.x * ex + k2.y * a2y1 + k2.z * a2y2
			a2y2 = a2y1
			a2y1 = y_b
			var y_c := k3.x * ex + k3.y * a3y1 + k3.z * a3y2
			a3y2 = a3y1
			a3y1 = y_c
			var v := (y_a * 1.0 + y_b * 0.55 + y_c * 0.28) * 0.9 + sin(TAU * ph) * 0.35
			dry[idx] += v * env * amp
	# brass-tube colouration: two feedback combs on the tube's harmonic series (~D2 and ~E3)
	var l1 := int(SR / 110.0)
	var l2 := int(SR / 164.8)
	for n in range(l1, total):
		dry[n] += 0.52 * dry[n - l1]
	for n in range(l2, total):
		dry[n] += 0.34 * dry[n - l2]
	# faint inharmonic bell shimmer on stressed syllables (bell partials)
	var partials: Array = [1.0, 2.76, 5.4, 8.93]
	var pamp: Array = [1.0, 0.55, 0.32, 0.18]
	for s in p.syl:
		if not s.stress:
			continue
		var fb: float = ROOT * 6.0 * float(JI[(int(s.f0) % 5) + 1]) * 0.5
		var n0 := int(s.t0 * SR)
		var blen := int(1.4 * SR)
		for m in 4:
			var w := TAU * fb * float(partials[m]) / SR
			var tau := (0.55 / (1.0 + 0.7 * m)) * SR
			var am: float = 0.05 * float(pamp[m])
			for i in range(0, blen, 1):
				var idx := n0 + i
				if idx >= total:
					break
				dry[idx] += am * exp(-float(i) / tau) * sin(w * i) * minf(float(i) / 120.0, 1.0)
	# Schroeder reverb: 4 damped combs + 2 allpasses
	var delays: Array = [655, 818, 906, 964]
	var gains: Array = [0.88, 0.87, 0.875, 0.865]
	var wet := PackedFloat32Array()
	wet.resize(total)
	for c in 4:
		var d: int = delays[c]
		var buf := PackedFloat32Array()
		buf.resize(d)
		var bi := 0
		var damp_s := 0.0
		var g: float = gains[c]
		for n in total:
			var out := buf[bi]
			damp_s = out * 0.65 + damp_s * 0.35
			buf[bi] = dry[n] + damp_s * g
			bi += 1
			if bi >= d:
				bi = 0
			wet[n] += out * 0.25
	for ap in [278, 220]:
		var buf := PackedFloat32Array()
		buf.resize(ap)
		var bi := 0
		for n in total:
			var bo := buf[bi]
			var xin := wet[n]
			var yout := bo - 0.5 * xin
			buf[bi] = xin + 0.5 * bo
			wet[n] = yout
			bi += 1
			if bi >= ap:
				bi = 0
	# mix, DC block, NaN guard, normalise
	var peak := 0.0
	hp_x = 0.0
	hp_y = 0.0
	for n in total:
		var m := dry[n] * 0.78 + wet[n] * 0.55
		var yv := m - hp_x + 0.995 * hp_y
		hp_x = m
		hp_y = yv
		if is_nan(yv) or is_inf(yv):
			nan_count += 1
			yv = 0.0
			hp_y = 0.0
		dry[n] = yv
		peak = maxf(peak, absf(yv))
	var scale := PEAK / maxf(peak, 0.0001)
	var fade_n := int(0.25 * SR)
	var bytes := PackedByteArray()
	bytes.resize(total * 2)
	var out_peak := 0.0
	for n in total:
		var v2 := dry[n] * scale
		if n > total - fade_n:
			v2 *= float(total - n) / float(fade_n)
		if n < 100:
			v2 *= float(n) / 100.0
		out_peak = maxf(out_peak, absf(v2))
		bytes.encode_s16(n * 2, int(clampf(v2, -1.0, 1.0) * 32767.0))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = SR
	st.stereo = false
	st.data = bytes
	return {
		"stream": st, "plan": p, "env": envelope(p),
		"peak": out_peak, "nan": nan_count, "samples": total, "length": float(total) / SR,
	}
