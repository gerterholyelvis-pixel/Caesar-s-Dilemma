class_name Music
extends Node
## Adaptive generative score, fully synthesised in code from music theory and math.
## 6 themes x 4 stems (0 pad/drone, 1 melody, 2 Euclidean percussion + arpeggio, 3 dense polyrhythm layer),
## baked once on worker threads into looping AudioStreamWAV (16 kHz mono) and faded by set_tension().
##
## Theory used:
##  * TUNING   just-intonation ratio tables (ptolemaic 5-limit, pythagorean 3-limit, septimal 7-limit); the lexicon
##             seed picks the tuning, mode, root and a few cents of root detune (no 12-TET frequencies are used).
##  * HARMONY  modal triads on scale degrees, optimal VOICE LEADING (Viterbi over voicings, common tones cost 0),
##             cadences (authentic / plagal) or deliberately unresolved endings (half cadence / suspended chord).
##  * RHYTHM   Euclidean rhythms E(k,n), polyrhythms 3:2 / 4:3, golden-ratio swing, Fibonacci phrase lengths
##             (bars 3,5,8,13), per-theme tempo and meter; set_tension fades in denser Euclid / polyrhythm layers.
##  * MELODY   L-system (Fibonacci word A->AB, B->A) chooses the per-bar transformation; the motif contains a half-scale
##             copy of itself (fractal self-similarity); weighted scale-degree walk; chord tones on strong beats.
##  * DANGER   tritone 45:32 and minor second 16:15 reserved for battle (touch) and boss (drone).

const RATE := 16000
const STEMS := 4
const PHI := 1.6180339887
const FIB: Array[int] = [1, 2, 3, 5, 8, 13, 21, 34]
const MODE_NAMES: Array[String] = ["dorian", "phrygian", "lydian", "aeolian", "pentatonic", "mixolydian", "pent_minor"]
const MODE_STEPS: Array = [
	[0, 2, 3, 5, 7, 9, 10], [0, 1, 3, 5, 7, 8, 10], [0, 2, 4, 6, 7, 9, 11], [0, 2, 3, 5, 7, 8, 10],
	[0, 2, 4, 7, 9], [0, 2, 4, 5, 7, 9, 10], [0, 3, 5, 7, 10]]
## Just-intonation ratio of each of the 12 chromatic steps above the root, per tuning family.
const TUNING_NAMES: Array[String] = ["ptolemaic", "pythagorean", "septimal"]
const TUNINGS: Array = [
	[1.0, 16.0 / 15.0, 9.0 / 8.0, 6.0 / 5.0, 5.0 / 4.0, 4.0 / 3.0, 45.0 / 32.0, 3.0 / 2.0, 8.0 / 5.0, 5.0 / 3.0, 9.0 / 5.0, 15.0 / 8.0],
	[1.0, 256.0 / 243.0, 9.0 / 8.0, 32.0 / 27.0, 81.0 / 64.0, 4.0 / 3.0, 729.0 / 512.0, 3.0 / 2.0, 128.0 / 81.0, 27.0 / 16.0, 16.0 / 9.0, 243.0 / 128.0],
	[1.0, 16.0 / 15.0, 9.0 / 8.0, 7.0 / 6.0, 5.0 / 4.0, 4.0 / 3.0, 7.0 / 5.0, 3.0 / 2.0, 14.0 / 9.0, 5.0 / 3.0, 7.0 / 4.0, 15.0 / 8.0]]
const TRITONE := 45.0 / 32.0
const MINOR_SECOND := 16.0 / 15.0
const STEM_PEAK: Array[float] = [0.16, 0.15, 0.13, 0.12]
const THEME_NAMES: Array[String] = ["limbo", "garden", "map", "battle", "boss", "shrine"]
## beats = beats per bar (meter), bars = Fibonacci phrase length, k = Euclid onsets [calm, dense] in n = beats*npb steps,
## cad: authentic | plagal (resolved) | half | sus (unresolved), swing: golden-ratio swing, poly: a:b polyrhythm,
## danger: 0 none, 1 minor second touch, 2 tritone + minor second drone.
const THEMES := {
	"limbo": {"bpm": 48.0, "beats": 3, "bars": 5, "prog": [0, 5, 3, 6, 4], "cad": "sus", "mel_base": 67, "voice": "bell", "gap": 2, "perc": "heart", "arp": "", "npb": 2, "k": [2, 3], "swing": false, "poly": [3, 2], "danger": 0, "b1": 0.45, "b2": 0.0},
	"garden": {"bpm": 66.0, "beats": 3, "bars": 8, "prog": [0, 2, 3, 0, 5, 3, 4, 0], "cad": "authentic", "mel_base": 69, "voice": "glass", "gap": 1, "perc": "heart", "arp": "", "npb": 2, "k": [2, 4], "swing": true, "poly": [3, 2], "danger": 0, "b1": 0.5, "b2": 0.0},
	"map": {"bpm": 56.0, "beats": 4, "bars": 5, "prog": [0, 4, 5, 3, 4], "cad": "half", "mel_base": 64, "voice": "bell", "gap": 1, "perc": "heart", "arp": "", "npb": 2, "k": [3, 5], "swing": true, "poly": [3, 2], "danger": 0, "b1": 0.5, "b2": 0.0},
	"battle": {"bpm": 112.0, "beats": 4, "bars": 8, "prog": [0, 5, 3, 4, 0, 5, 3, 0], "cad": "plagal", "mel_base": 60, "voice": "pluck", "gap": 1, "perc": "march", "arp": "eighths", "npb": 2, "k": [3, 5], "swing": false, "poly": [3, 2], "danger": 1, "b1": 0.7, "b2": 0.6},
	"boss": {"bpm": 126.0, "beats": 4, "bars": 13, "prog": [0, 1, 0, 1, 0, 5, 1, 0, 5, 1, 6, 4, 4], "cad": "sus", "mel_base": 57, "voice": "pluck", "gap": 1, "perc": "drive", "arp": "eighths", "npb": 3, "k": [5, 7], "swing": false, "poly": [4, 3], "danger": 2, "b1": 0.8, "b2": 0.8},
	"shrine": {"bpm": 48.0, "beats": 5, "bars": 3, "prog": [0, 2, 4], "cad": "sus", "mel_base": 72, "voice": "glass", "gap": 1, "perc": "none", "arp": "shimmer", "npb": 2, "k": [3, 5], "swing": false, "poly": [3, 2], "danger": 0, "b1": 0.45, "b2": 0.0},
}

var master_db := -6.0
var fade_sec := 2.0
var baked := false

var _seed := 0
var _threads: Array[Thread] = []
var _mutex := Mutex.new()
var _done := {}          # theme -> Array[PackedByteArray] (written by workers)
var _streams := {}       # theme -> Array[AudioStreamWAV]
var _players := {}       # theme -> Array[AudioStreamPlayer]
var _tgain := {}         # theme -> current crossfade gain 0..1
var _target := ""
var _tension := 0.0
var _tension_s := 0.0


static func install(parent: Node, lexicon_seed: int) -> Music:
	var m := Music.new()
	m.name = "Music"
	m._seed = lexicon_seed
	parent.add_child(m)
	return m


func _ready() -> void:
	for t in THEME_NAMES:
		_tgain[t] = 0.0
		var th := Thread.new()
		th.start(_bake_worker.bind(t))
		_threads.append(th)


func _exit_tree() -> void:
	for th in _threads:
		if th.is_started():
			th.wait_to_finish()
	_threads.clear()


func _bake_worker(theme: String) -> void:
	var r := bake_theme(theme, _seed)
	var bytes: Array = []
	for s in r["stems"]:
		bytes.append(Sfx.to_pcm(s))
	_mutex.lock()
	_done[theme] = bytes
	_mutex.unlock()


func set_theme(theme_name: String) -> void:
	_target = theme_name if THEMES.has(theme_name) else ""


func set_tension(v: float) -> void:
	_tension = clampf(v, 0.0, 1.0)


## Hook: replace a baked stem with a composed stream later (theme, stem 0..3).
func override_stem(theme: String, idx: int, stream: AudioStream) -> void:
	if _players.has(theme) and idx >= 0 and idx < STEMS:
		(_players[theme][idx] as AudioStreamPlayer).stream = stream


func _collect() -> void:
	_mutex.lock()
	var ready_keys := _done.keys()
	_mutex.unlock()
	for t in ready_keys:
		if _streams.has(t):
			continue
		_mutex.lock()
		var bytes: Array = _done[t]
		_mutex.unlock()
		var arr: Array = []
		var pl: Array = []
		for b in bytes:
			var w := AudioStreamWAV.new()
			w.format = AudioStreamWAV.FORMAT_16_BITS
			w.mix_rate = RATE
			w.stereo = false
			w.data = b
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = b.size() / 2
			arr.append(w)
			var p := AudioStreamPlayer.new()
			p.stream = w
			p.volume_db = -80.0
			add_child(p)
			pl.append(p)
		_streams[t] = arr
		_players[t] = pl
	baked = _streams.size() == THEME_NAMES.size()


func _process(dt: float) -> void:
	if _streams.size() < THEME_NAMES.size():
		_collect()
	_tension_s += (_tension - _tension_s) * minf(1.0, dt * 1.5)
	for t in _players:
		var th: Dictionary = THEMES[t]
		var g: float = _tgain[t]
		var want := 1.0 if t == _target else 0.0
		g = move_toward(g, want, dt / fade_sec)
		_tgain[t] = g
		var pl: Array = _players[t]
		if g <= 0.0005 and want == 0.0:
			if (pl[0] as AudioStreamPlayer).playing:
				for p in pl:
					(p as AudioStreamPlayer).stop()
			continue
		var gs: Array[float] = [
			1.0,
			lerpf(float(th["b1"]), 1.0, _tension_s),
			clampf(float(th["b2"]) + _tension_s * 1.4 - 0.3, 0.0, 1.0),
			clampf((_tension_s - 0.35) * 1.6, 0.0, 1.0)]   # denser Euclid / polyrhythm layer
		for i in STEMS:
			var p: AudioStreamPlayer = pl[i]
			if not p.playing:
				p.play()
			p.volume_db = linear_to_db(maxf(g * g * gs[i], 0.00001)) + master_db


# ------------------------------------------------------------------ musical profile / tuning

static func _mix(x: int) -> int:
	x = (x * 0x9E3779B1 + 0x7F4A7C15) & 0xFFFFFFFF
	x = ((x ^ (x >> 15)) * 0x85EBCA6B) & 0xFFFFFFFF
	x = ((x ^ (x >> 13)) * 0xC2B2AE35) & 0xFFFFFFFF
	return x ^ (x >> 16)


static func cents(ratio: float) -> float:
	return 1200.0 * log(ratio) / log(2.0)


static func profile(lexicon_seed: int) -> Dictionary:
	var h := _mix(lexicon_seed)
	var mode := h % MODE_NAMES.size()
	var tuning := (h >> 12) % TUNINGS.size()
	var detune := float((h >> 16) % 41) - 20.0                 # root detune in cents, +-20
	var root := 45 + ((h >> 8) % 7)
	var root_hz := 440.0 * pow(2.0, (float(root) - 69.0) / 12.0) * pow(2.0, detune / 1200.0)
	var steps: Array = MODE_STEPS[mode]
	var table: Array = TUNINGS[tuning]
	var sc: Array = []
	for s in steps:
		sc.append(cents(float(table[int(s)])) + detune)          # cent-accurate scale (absolute detune included)
	return {"seed": lexicon_seed, "mode": mode, "mode_name": MODE_NAMES[mode], "steps": steps,
		"root": root, "motif_seed": _mix(h ^ 0x5BD1E995), "tuning": tuning, "tuning_name": TUNING_NAMES[tuning],
		"ratios": table, "detune_cents": detune, "root_hz": root_hz, "scale_cents": sc}


## MIDI-like note number for scale degree `deg` (may be negative / beyond one octave) near register `base`.
## The integer is only a register/pitch-class label; use freq() for the actual just-intonation frequency.
static func midi(P: Dictionary, deg: int, base := 57) -> int:
	var steps: Array = P["steps"]
	var l := steps.size()
	var pc: int = int(P["root"]) % 12
	var r := pc + 12 * roundi(float(base - pc) / 12.0)
	return r + int(steps[posmod(deg, l)]) + 12 * floori(float(deg) / l)


## 12-TET reference frequency (kept for API compatibility; the score itself uses freq()).
static func mtof(m: int) -> float:
	return 440.0 * pow(2.0, (float(m) - 69.0) / 12.0)


## Just-intonation frequency of note label `m` in the profile's tuning: root_hz * ratio[step] * 2^octave.
static func freq(P: Dictionary, m: int) -> float:
	var o: int = m - int(P["root"])
	var table: Array = P["ratios"]
	return float(P["root_hz"]) * float(table[posmod(o, 12)]) * pow(2.0, floorf(float(o) / 12.0))


static func deg_freq(P: Dictionary, deg: int, base := 57) -> float:
	return freq(P, midi(P, deg, base))


# ------------------------------------------------------------------ rhythm / structure theory

## Euclidean rhythm E(k,n) as bools (evenly spread onsets; floor method, first onset at step 0).
static func euclid(k: int, n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append((i * k) % n < k)
	return out


static func euclid_onsets(k: int, n: int) -> Array:
	var out: Array = []
	var p := euclid(k, n)
	for i in n:
		if p[i]:
			out.append(i)
	return out


## Onset times (beats) of an a:b polyrhythm over `length` beats.
static func polyrhythm(a: int, b: int, length: float) -> Dictionary:
	var ta: Array = []
	var tb: Array = []
	for i in a:
		ta.append(length * float(i) / a)
	for i in b:
		tb.append(length * float(i) / b)
	return {"a": ta, "b": tb}


static func is_fib(n: int) -> bool:
	return FIB.has(n) or n == 1


static func golden_bar(bars: int) -> int:
	return int(round(float(bars) / PHI))


## Golden-ratio swing: the off-beat eighth sits at phi/(1+phi) = 0.618 of the beat instead of 0.5.
static func swing_pos(frac: float) -> float:
	return PHI / (1.0 + PHI) if absf(frac - 0.5) < 1e-6 else frac


static func lsystem(axiom: String, rules: Dictionary, iters: int) -> String:
	var s := axiom
	for i in iters:
		var o := ""
		for ch in s:
			o += String(rules.get(ch, ch))
		s = o
	return s


# ------------------------------------------------------------------ harmony theory

## Chord as scale degrees: stacked thirds (root, 3rd, 5th), or suspended (root, 4th, 5th).
static func chord_degrees(c: int, sus := false) -> Array:
	return [c, c + 3, c + 4] if sus else [c, c + 2, c + 4]


static func voicing_cost(a: Array, b: Array) -> float:
	var s := 0.0
	for i in 3:
		s += absf(float(a[i]) - float(b[i]))
	return s


static func _candidates(P: Dictionary, chord: Array) -> Array:
	var opts: Array = []
	for d in chord:
		var m0 := midi(P, int(d), 60)
		var o: Array = []
		for k in [-12, 0, 12]:
			var m: int = m0 + k
			if m >= 46 and m <= 74:
				o.append(m)
		opts.append(o)
	var out: Array = []
	for x in opts[0]:
		for y in opts[1]:
			for z in opts[2]:
				var v := [x, y, z]
				v.sort()
				if int(v[1]) - int(v[0]) >= 2 and int(v[2]) - int(v[1]) >= 2:
					out.append(v)
	if out.is_empty():   # very tight chord: allow any spacing
		for x in opts[0]:
			for y in opts[1]:
				for z in opts[2]:
					var v := [x, y, z]
					v.sort()
					out.append(v)
	return out


## Optimal voice leading across the (cyclic) progression: minimises summed semitone-ish motion per voice;
## common tones stay put (cost 0). Returns one sorted 3-note voicing per chord.
static func voice_lead(P: Dictionary, chords: Array) -> Array:
	var cands: Array = []
	for c in chords:
		cands.append(_candidates(P, c))
	var best_cost := 1e9
	var best: Array = []
	var starts: Array = cands[0]
	for si in starts.size():
		var cost: Array = [0.0]
		var back: Array = [[]]
		# viterbi from fixed start state si
		var prev_cost: Array = []
		for j in cands[0].size():
			prev_cost.append(0.0 if j == si else 1e9)
		var back_all: Array = []
		for b in range(1, chords.size()):
			var cur_c: Array = []
			var cur_b: Array = []
			for j in cands[b].size():
				var bc := 1e9
				var bi := 0
				for i in cands[b - 1].size():
					var c: float = float(prev_cost[i]) + voicing_cost(cands[b - 1][i], cands[b][j])
					if c < bc:
						bc = c
						bi = i
				cur_c.append(bc)
				cur_b.append(bi)
			prev_cost = cur_c
			back_all.append(cur_b)
		var last := chords.size() - 1
		for j in cands[last].size():
			var total: float = float(prev_cost[j]) + voicing_cost(cands[last][j], starts[si])   # wrap
			if total < best_cost:
				best_cost = total
				var path: Array = [j]
				var cj: int = j
				for b in range(last - 1, -1, -1):
					cj = int(back_all[b][cj])
					path.push_front(cj)
				best = []
				for b in chords.size():
					best.append(cands[b][path[b]])
	return best


## Average motion per voice (semitone labels) between consecutive chords, optionally including the loop wrap.
static func avg_motion(voicings: Array, wrap := true) -> float:
	var tot := 0.0
	var cnt := 0
	var n := voicings.size()
	for i in (n if wrap else n - 1):
		tot += voicing_cost(voicings[i], voicings[(i + 1) % n]) / 3.0
		cnt += 1
	return tot / maxf(cnt, 1)


## Nearest scale degree to `deg` (within +-2) that belongs to the chord.
static func snap_to_chord(deg: int, chord: Array, l: int) -> int:
	var set: Array = []
	for c in chord:
		set.append(posmod(int(c), l))
	for k in [0, -1, 1, -2, 2]:
		if set.has(posmod(deg + k, l)):
			return deg + k
	return deg


# ------------------------------------------------------------------ fractal motif

## Weighted scale-degree walk of `count` notes (offsets from the start), pulled to chord tones and the centre.
static func walk(rng: RandomNumberGenerator, count: int, l: int) -> Array:
	var deg := 0
	var out: Array = [0]
	var steps := [-2, -1, 0, 1, 2, 3]
	for i in range(1, count):
		var w := [1.0, 3.0, 0.6, 3.0, 1.2, 0.5]
		for k in 6:
			var nd: int = deg + steps[k]
			if nd > 5 or nd < -3:
				w[k] *= 0.15
			if [0, 2, 4].has(posmod(nd, l)):
				w[k] *= 1.8
		var tot := 0.0
		for x in w:
			tot += x
		var r := rng.randf() * tot
		var pick := 0
		for k in 6:
			r -= w[k]
			if r <= 0.0:
				pick = k
				break
		deg += steps[pick]
		out.append(deg)
	return out


## Self-similar motif for a bar of B beats. Level 0 = 3-note cell with Euclid E(3,B) durations spanning B/2 beats;
## each further level is a COPY of the cell at `scale` times the duration, transposed up 2 degrees; a held note
## fills the rest of the bar. notes: {d: degree offset, t: start beat, len: beats, lvl: level, hold: bool}.
static func make_motif(rng: RandomNumberGenerator, B: int, depth: int, scale: float, l: int) -> Array:
	var span := float(B) * 0.5
	var on := euclid_onsets(3, B)
	var gaps: Array = []
	for i in 3:
		gaps.append(float((int(on[(i + 1) % 3]) - int(on[i]) + B) % B) * 0.5)
	var offs := walk(rng, 3, l)
	var notes: Array = []
	var t0 := 0.0
	var sc := 1.0
	var tr := 0
	for lvl in depth + 1:
		var tt := t0
		for i in 3:
			notes.append({"d": int(offs[i]) + tr, "t": tt, "len": float(gaps[i]) * sc, "lvl": lvl, "hold": false})
			tt += float(gaps[i]) * sc
		t0 += span * sc
		sc *= scale
		tr += 2
	notes.append({"d": 0, "t": t0, "len": float(B) - t0, "lvl": -1, "hold": true})
	return notes


# ------------------------------------------------------------------ baking (pure, thread-safe)

## Returns {"stems": [4 float buffers], "n": samples, "mode", "bpm", "motif", "voicings", "chords", "prog",
## "cad", "bars", "beats", "golden_bar", "melody": [{bar,t,deg,chord,strong,hold,m}], "tuning", "euclid": [k_lo,k_hi,n]}.
static func bake_theme(theme: String, lexicon_seed: int) -> Dictionary:
	var cfg: Dictionary = THEMES[theme]
	var P := profile(lexicon_seed)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(P["motif_seed"]) ^ Sfx.hash_str(theme)
	var B: int = cfg["beats"]
	var bars: int = cfg["bars"]
	var bs := int(round(60.0 / float(cfg["bpm"]) * RATE))   # samples per beat
	var n := bs * B * bars
	var prog: Array = cfg["prog"]
	var cad: String = cfg["cad"]
	var l: int = (P["steps"] as Array).size()
	var chords: Array = []
	for b in bars:
		chords.append(chord_degrees(int(prog[b]), cad == "sus" and b == bars - 1))
	var voic := voice_lead(P, chords)
	var danger: int = cfg["danger"]

	# --- stem 0: pad + drone from the voice-led chords (equal-power crossfades, wraps seamlessly)
	var pad := PackedFloat32Array()
	pad.resize(n)
	var fade := bs * 3 / 2
	for b in bars:
		var dis := danger
		if danger == 1 and b != bars - 2:
			dis = 0
		_pad_chord(pad, P, voic[b], midi(P, int(prog[b]), 33), b * B * bs - fade / 2, B * bs + fade, fade, dis)

	# --- stem 1: melody
	var mel := PackedFloat32Array()
	mel.resize(n)
	var cache := {}
	var voice: String = cfg["voice"]
	var motif := make_motif(rng, B, 1, 0.5, l)
	var notes := _melody(P, cfg, rng, chords, motif)
	for nt in notes:
		_add_note(mel, cache, voice, freq(P, int(nt["m"])), (float(nt["bar"]) * B + float(nt["t"])) * bs, float(nt["vel"]), bs)
	var dry := mel.duplicate()
	for tap in [[0.75, 0.3], [1.5, 0.18]]:   # circular echo: dotted-eighth and dotted-quarter
		var d := int(float(tap[0]) * bs)
		var g: float = tap[1]
		for i in n:
			mel[i] += dry[(i - d + n) % n] * g

	# --- stems 2/3: Euclidean percussion, arpeggio, polyrhythm
	var npb: int = cfg["npb"]
	var steps := B * npb
	var klo: int = cfg["k"][0]
	var khi: int = cfg["k"][1]
	var per := PackedFloat32Array()
	per.resize(n)
	var dense := PackedFloat32Array()
	dense.resize(n)
	var prng := RandomNumberGenerator.new()
	prng.seed = rng.seed + 99
	_percussion(per, dense, String(cfg["perc"]), P, bars, B, steps, klo, khi, bs, prng)
	var arp := String(cfg["arp"])
	if arp == "eighths":
		var pat := [0, 1, 2, 1, 0, 2, 1, 2]
		for b in bars:
			var vb: Array = voic[b]
			for s in B * 2:
				var m: int = int(vb[int(pat[s % 8])]) + (-12 if theme == "boss" else 0)
				_add_note(per, cache, "pluck", freq(P, m), (b * float(B) + s * 0.5) * bs, 1.0 if s % 4 == 0 else 0.55, bs)
	elif arp == "shimmer":
		var on := euclid_onsets(klo, steps)
		for b in bars:
			var vb: Array = voic[b]
			for s in on:
				var m: int = int(vb[prng.randi() % 3]) + 12 * (prng.randi() % 2)
				_add_note(per, cache, "glass", freq(P, m + 12), (b * float(B) + float(s) / npb) * bs, 0.5 + prng.randf() * 0.4, bs)
	# dense stem: a:b polyrhythm of chord tones over each bar (3:2 or 4:3)
	var pr: Array = cfg["poly"]
	var poly := polyrhythm(int(pr[0]), int(pr[1]), float(B))
	for b in bars:
		var vb: Array = voic[b]
		for i in (poly["a"] as Array).size():
			_add_note(dense, cache, "glass", freq(P, int(vb[i % 3]) + 12), (b * float(B) + float(poly["a"][i])) * bs, 0.6, bs)
		for i in (poly["b"] as Array).size():
			_add_note(dense, cache, "bell", freq(P, int(vb[(i + 1) % 3])), (b * float(B) + float(poly["b"][i]) + 0.25) * bs, 0.5, bs)

	var stems: Array = [pad, mel, per, dense]
	for i in STEMS:
		_normalize(stems[i], STEM_PEAK[i])
	return {"stems": stems, "n": n, "mode": P["mode_name"], "bpm": cfg["bpm"], "motif": motif, "voicings": voic,
		"chords": chords, "prog": prog, "cad": cad, "bars": bars, "beats": B, "golden_bar": golden_bar(bars),
		"melody": notes, "tuning": P["tuning_name"], "euclid": [klo, khi, steps]}


static func _normalize(b: PackedFloat32Array, peak: float) -> void:
	var mx := 0.0
	for v in b:
		mx = maxf(mx, absf(v))
	if mx < 1e-5:
		return
	var k := peak / mx
	for i in b.size():
		b[i] *= k


## Melody notes for all bars: the fractal motif transformed per bar by the Fibonacci-word L-system
## (A = as is, B = up one step), golden-section climax bar, chord tones on strong beats, cadence at the end.
static func _melody(P: Dictionary, cfg: Dictionary, rng: RandomNumberGenerator, chords: Array, motif: Array) -> Array:
	var B: int = cfg["beats"]
	var bars: int = cfg["bars"]
	var prog: Array = cfg["prog"]
	var cad: String = cfg["cad"]
	var l: int = (P["steps"] as Array).size()
	var word := lsystem("A", {"A": "AB", "B": "A"}, 6)
	var gb := golden_bar(bars)
	var mbase: int = cfg["mel_base"]
	var out: Array = []
	for b in bars:
		var last := b == bars - 1
		if int(cfg["gap"]) == 2 and b % 2 == 1 and not last:
			continue
		var c: int = prog[b]
		var shift := (1 if word[b % word.length()] == "B" else 0) + (2 if b == gb else 0)
		for nt in motif:
			var d: int = c + int(nt["d"]) + shift
			var t := float(nt["t"])
			var hold: bool = nt["hold"]
			var strong: bool = hold or (is_equal_approx(t, floorf(t)) and int(t) % 2 == 0)
			if hold and last:
				match cad:
					"sus":
						d = c + 4                       # 5th over the sus4 chord: the hanging 4th (tonic) is never resolved
					"half":
						d = c + 4                       # lands on the 5th of V
					_:
						d = 0                           # cadence resolves to the tonic
			elif strong:
				d = snap_to_chord(d, chords[b], l)
			if cfg["swing"]:
				t = floorf(t) + swing_pos(t - floorf(t))
			var m := midi(P, d, mbase)
			while m > mbase + 17:
				m -= 12
			out.append({"bar": b, "t": t, "deg": d, "m": m, "chord": c, "strong": strong, "hold": hold, "lvl": nt["lvl"],
				"vel": 1.0 if (strong and not hold) else (1.0 if hold else 0.6 + rng.randf() * 0.25)})
	return out


static func _add_note(out: PackedFloat32Array, cache: Dictionary, voice: String, f: float, start: float, vel: float, bs: int) -> void:
	var key := voice + "%.2f" % f
	if not cache.has(key):
		var nb: PackedFloat32Array
		match voice:
			"bell":
				nb = Sfx.buf(1.9)
				Sfx.partials(nb, 0.0, f, 1.9, 1.0, Sfx.BELL, Sfx.BELL_A, 2.6, 0.005)
			"glass":
				nb = Sfx.buf(1.5)
				Sfx.partials(nb, 0.0, f, 1.5, 1.0, Sfx.GLASS, Sfx.GLASS_A, 3.3, 0.006)
			_:
				nb = Sfx.buf(0.9)
				Sfx.partials(nb, 0.0, f, 0.9, 1.0, [1.0, 2.0, 3.0, 4.0], [1.0, 0.5, 0.3, 0.15], 7.0, 0.003)
		cache[key] = nb
	var src: PackedFloat32Array = cache[key]
	var n := out.size()
	var s0 := int(start)
	for i in src.size():
		out[(s0 + i) % n] += src[i] * vel


## One pad chord: drone root + pure fifth (3:2) + three voice-led chord voices, each a harmonic stack
## (1, 2) with a slightly detuned chorus partner; raised-cosine fades so neighbours crossfade at constant power.
## dis 1 adds a minor second (16:15) beating against the drone, dis 2 adds tritone 45:32 as well.
static func _pad_chord(out: PackedFloat32Array, P: Dictionary, voices: Array, bass_m: int, start: int, length: int, fade: int, dis: int) -> void:
	var n := out.size()
	var f0 := freq(P, bass_m)
	var w0 := TAU * f0 / RATE
	var ws: Array[float] = []
	for m in voices:
		ws.append(TAU * freq(P, int(m)) / RATE)
	var w1: float = ws[0]
	var w2: float = ws[1]
	var w3: float = ws[2]
	var wd := w0 * 2.0 * MINOR_SECOND
	var wt := w0 * 2.0 * TRITONE
	for j in length:
		var e := 1.0
		if j < fade:
			e = sin(PI * 0.5 * j / fade)
			e *= e
		elif j > length - fade:
			e = sin(PI * 0.5 * (length - j) / fade)
			e *= e
		var v := sin(w0 * j) * 0.8 + sin(w0 * 1.5 * j) * 0.22
		v += (sin(w1 * j) + sin(w1 * 1.0035 * j) * 0.7) * 0.35
		v += (sin(w2 * j) + sin(w2 * 0.9965 * j) * 0.7) * 0.3
		v += (sin(w3 * j) + sin(w3 * 2.0 * j) * 0.25) * 0.25
		if dis >= 1:
			v += (sin(w0 * 2.0 * j) + sin(wd * j)) * 0.14
		if dis >= 2:
			v += sin(wt * j) * 0.18
		out[posmod(start + j, n)] += v * e


## Euclidean percussion tuned to the root (kick = root sweeping down two octaves, tom = fifth falling to the root).
## Calm stem gets E(klo,n); the dense stem gets the extra onsets of E(khi,n) plus hats.
static func _percussion(out: PackedFloat32Array, dense: PackedFloat32Array, kind: String, P: Dictionary, bars: int, B: int,
		steps: int, klo: int, khi: int, bs: int, rng: RandomNumberGenerator) -> void:
	if kind == "none":
		return
	var rhz: float = P["root_hz"]
	var kick := Sfx.buf(0.5)
	Sfx.sweep(kick, 0.0, rhz if kind != "heart" else rhz * 0.8, rhz * 0.25, 0.4, 1.0, 9.0 if kind != "heart" else 12.0, 0.004)
	var tom := Sfx.buf(0.4)
	Sfx.sweep(tom, 0.0, rhz * 1.5, rhz, 0.3, 0.8, 11.0, 0.003)
	var hat := Sfx.buf(0.1)
	Sfx.noise(hat, 0.0, 0.08, 0.6, 50.0, 0.9, rng, 0.35)
	var lo := euclid(klo, steps)
	var hi := euclid(khi, steps)
	var n := out.size()
	for b in bars:
		for s in steps:
			var beat := b * float(B) + float(s) * float(B) / steps
			var s0 := int(beat * bs)
			var acc := 1.0 if s == 0 else 0.7
			var hits: Array = []      # [buffer, amp, target]
			if lo[s]:
				hits.append([kick, acc * (1.0 if kind != "heart" else 0.7), 0])
			elif kind != "heart" and s % 2 == 1:
				hits.append([hat, 0.25, 0])
			if hi[s] and not lo[s]:
				hits.append([tom, 0.55, 1])
			elif kind != "heart" and s % 2 == 0 and not lo[s]:
				hits.append([hat, 0.3, 1])
			for h in hits:
				var src: PackedFloat32Array = h[0]
				var a: float = float(h[1]) * (0.9 + rng.randf() * 0.2)
				for i in src.size():
					if int(h[2]) == 0:
						out[(s0 + i) % n] += src[i] * a
					else:
						dense[(s0 + i) % n] += src[i] * a
