class_name Sfx
extends Node
## Procedural sound effects. Every sound is synthesised ONCE on a worker thread into
## AudioStreamWAV banks (16 kHz mono); playback is a pool of AudioStreamPlayers.
## Pitches come from the profile's lexicon-seed mode (Music.profile), so the whole
## game rings in one key.  Also hosts the small DSP toolkit used by Music.

const RATE := 16000
const PEAK := 0.42
const POOL := 12
const NAMES: Array[String] = [
	"ui_click", "ui_hover", "place_item", "rotate_item", "invalid", "hit_enemy", "hit_player",
	"block", "heal", "energy", "end_turn", "win", "lose", "glyph_learn", "secret_found", "path_change", "boss_sting"]
const BELL := [1.0, 2.0, 2.76, 5.4]
const BELL_A := [1.0, 0.45, 0.28, 0.1]
const METAL := [1.0, 2.76, 5.4, 8.93]
const METAL_A := [1.0, 0.6, 0.35, 0.18]
const GLASS := [1.0, 2.01, 3.0, 4.17]
const GLASS_A := [1.0, 0.5, 0.3, 0.18]
const SOFT := [1.0, 2.0, 3.0]
const SOFT_A := [1.0, 0.35, 0.12]

var volume_db := -3.0
var _seed := 0
var _thread: Thread
var _players: Array[AudioStreamPlayer] = []
var _streams := {}
var _last := {}
var _pi := 0
var baked := false


static func install(parent: Node, lexicon_seed: int) -> Sfx:
	var s := Sfx.new()
	s.name = "Sfx"
	s._seed = lexicon_seed
	parent.add_child(s)
	return s


func _ready() -> void:
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.volume_db = volume_db
		add_child(p)
		_players.append(p)
	_thread = Thread.new()
	_thread.start(_bake_thread)


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()


func _bake_thread() -> Dictionary:
	var bufs := bake_all(_seed)
	var out := {}
	for k in bufs:
		out[k] = to_pcm(bufs[k])
	call_deferred("_on_baked")
	return out


func _on_baked() -> void:
	var out: Dictionary = _thread.wait_to_finish()
	for k in out:
		var w := AudioStreamWAV.new()
		w.format = AudioStreamWAV.FORMAT_16_BITS
		w.mix_rate = RATE
		w.stereo = false
		w.data = out[k]
		_streams[k] = w
	baked = true


func _play_stream(key: String, vol := 0.0, pitch := 1.0) -> void:
	if not baked or not _streams.has(key):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last.get(key, -1000)) < 35:
		return
	_last[key] = now
	var p := _players[_pi]
	_pi = (_pi + 1) % POOL
	p.stream = _streams[key]
	p.volume_db = volume_db + vol
	p.pitch_scale = pitch
	p.play()


func play(sfx_name: String) -> void:
	_play_stream(sfx_name)


func play_item(item_id: String) -> void:
	_play_stream("item_" + item_id)


func play_synergy(count: int) -> void:
	_play_stream("syn_%d" % clampi(count, 1, 6))


# ------------------------------------------------------------------ bank

## All sounds as float buffers (also used by tests). name -> PackedFloat32Array.
static func bake_all(lexicon_seed: int) -> Dictionary:
	var P := Music.profile(lexicon_seed)
	var out := {}
	for n in NAMES:
		out[n] = named(n, P)
	for id in ItemDB.all_ids():
		out["item_" + id] = item_sound(id, P)
	for c in range(1, 7):
		out["syn_%d" % c] = synergy(c, P)
	return out


static func hash_str(s: String) -> int:
	var h := 5381
	for i in s.length():
		h = ((h << 5) + h + s.unicode_at(i)) & 0x7FFFFFFF
	return h


static func _f(P: Dictionary, deg: int, base := 57) -> float:
	return Music.freq(P, Music.midi(P, deg, base))   # just intonation, never 12-TET


static func named(n: String, P: Dictionary) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash_str(n) ^ int(P["seed"])
	var b: PackedFloat32Array
	match n:
		"ui_click":
			b = buf(0.14)
			noise(b, 0.0, 0.012, 0.5, 0.0, 0.5, rng, 0.2)
			partials(b, 0.0, _f(P, 4, 69), 0.12, 0.5, GLASS, GLASS_A, 38.0)
			return finish(b, 0.3)
		"ui_hover":
			b = buf(0.1)
			partials(b, 0.0, _f(P, 2, 81), 0.09, 0.5, SOFT, SOFT_A, 45.0, 0.01)
			return finish(b, 0.12)
		"place_item":
			b = buf(0.5)
			sweep(b, 0.0, 150.0, 62.0, 0.2, 0.9, 16.0)
			noise(b, 0.0, 0.03, 0.25, 40.0, 0.15, rng)
			partials(b, 0.02, _f(P, 2, 64), 0.4, 0.45, GLASS, GLASS_A, 9.0)
			return finish(b)
		"rotate_item":
			b = buf(0.2)
			sweep(b, 0.0, 330.0, 700.0, 0.14, 0.5, 14.0, 0.02)
			noise(b, 0.0, 0.14, 0.1, 18.0, 0.3, rng, 0.05, 0.03)
			return finish(b, 0.25)
		"invalid":
			b = buf(0.35)
			var f := _f(P, 0, 45)
			partials(b, 0.0, f, 0.3, 0.7, SOFT, SOFT_A, 10.0, 0.005)
			partials(b, 0.0, f * Music.MINOR_SECOND, 0.3, 0.7, SOFT, SOFT_A, 10.0, 0.005)   # 16:15 minor second
			sweep(b, 0.0, 120.0, 70.0, 0.12, 0.3, 20.0)
			return finish(b, 0.32)
		"hit_enemy":
			b = buf(0.5)
			noise(b, 0.0, 0.1, 1.0, 28.0, 0.35, rng)
			sweep(b, 0.0, 200.0, 70.0, 0.16, 0.9, 18.0)
			partials(b, 0.0, _f(P, 3, 62), 0.4, 0.3, METAL, METAL_A, 11.0)
			return finish(b)
		"hit_player":
			b = buf(0.6)
			noise(b, 0.0, 0.14, 0.9, 20.0, 0.12, rng)
			sweep(b, 0.0, 120.0, 40.0, 0.3, 1.0, 9.0)
			sweep(b, 0.02, 300.0, 120.0, 0.3, 0.35, 10.0)
			partials(b, 0.03, _f(P, 1, 45), 0.4, 0.25, SOFT, SOFT_A, 7.0)
			partials(b, 0.03, _f(P, 0, 45) * Music.TRITONE, 0.4, 0.2, SOFT, SOFT_A, 8.0)   # 45:32 tritone over the root
			return finish(b)
		"block":
			b = buf(0.8)
			noise(b, 0.0, 0.02, 0.8, 0.0, 0.6, rng, 0.2)
			sweep(b, 0.0, 130.0, 65.0, 0.18, 0.8, 18.0)
			partials(b, 0.0, _f(P, 0, 60), 0.75, 0.55, METAL, METAL_A, 5.5)
			partials(b, 0.0, _f(P, 4, 72), 0.6, 0.2, GLASS, GLASS_A, 7.0)
			return finish(b)
		"heal":
			b = buf(1.1)
			for i in 4:
				partials(b, i * 0.1, _f(P, [0, 2, 4, 7][i], 64), 0.9 - i * 0.05, 0.5, SOFT, SOFT_A, 3.5, 0.05)
			partials(b, 0.3, _f(P, 7, 64) * 2.0, 0.6, 0.15, [1.0, 1.005], [1.0, 1.0], 5.0, 0.1)
			return finish(echo(b, [0.13, 0.27], [0.3, 0.15], 0.3), 0.32, 0.01)
		"energy":
			b = buf(0.5)
			sweep(b, 0.0, 220.0, 880.0, 0.3, 0.6, 3.0, 0.08)
			sweep(b, 0.0, 223.0, 884.0, 0.3, 0.6, 3.0, 0.08)
			partials(b, 0.25, _f(P, 4, 81), 0.25, 0.4, GLASS, GLASS_A, 14.0)
			return finish(b, 0.3)
		"end_turn":
			b = buf(1.2)
			partials(b, 0.0, _f(P, 0, 40), 1.1, 0.9, [1.0, 2.0, 3.01], [1.0, 0.4, 0.2], 3.2, 0.02)
			sweep(b, 0.0, 100.0, 50.0, 0.3, 0.6, 9.0)
			partials(b, 0.12, _f(P, 4, 60), 0.9, 0.25, BELL, BELL_A, 4.0)
			return finish(echo(b, [0.2], [0.25], 0.2), 0.35, 0.01, 0.1)
		"win":
			b = buf(2.0)
			for i in 5:
				partials(b, i * 0.13, _f(P, [0, 2, 4, 7, 9][i], 60), 1.5, 0.45, BELL, BELL_A, 2.6)
			partials(b, 0.0, _f(P, 0, 48), 1.8, 0.35, SOFT, SOFT_A, 1.6, 0.15)
			return finish(echo(b, [0.19, 0.41], [0.3, 0.18], 0.5), 0.36, 0.01, 0.2)
		"lose":
			b = buf(2.4)
			for i in 4:
				partials(b, i * 0.28, _f(P, [4, 2, 1, 0][i], 52), 1.3, 0.5, GLASS, GLASS_A, 2.4, 0.01)
			partials(b, 0.0, _f(P, 0, 33), 2.2, 0.7, SOFT, SOFT_A, 1.2, 0.3)
			partials(b, 0.3, _f(P, 0, 33) * Music.TRITONE, 2.0, 0.35, SOFT, SOFT_A, 1.4, 0.4)   # tritone and
			partials(b, 0.6, _f(P, 0, 45) * Music.MINOR_SECOND, 1.8, 0.3, SOFT, SOFT_A, 1.5, 0.3)   # minor second tension
			return finish(echo(b, [0.3, 0.6], [0.3, 0.15], 0.5), 0.36, 0.01, 0.3)
		"glyph_learn":
			b = buf(2.2)
			for i in 6:
				partials(b, 0.7 + i * 0.07, _f(P, [0, 2, 4, 7, 9, 11][i], 72), 1.3, 0.35, GLASS, GLASS_A, 3.0, 0.01)
			var f0 := _f(P, 0, 48)
			partials(b, 0.0, f0, 1.0, 0.6, SOFT, SOFT_A, 0.8, 0.65)   # swell leads into the cluster
			partials(b, 0.0, f0 * 1.5, 1.0, 0.4, SOFT, SOFT_A, 0.8, 0.65)
			return finish(echo(b, [0.23, 0.47], [0.35, 0.2], 0.6), 0.38, 0.05, 0.3)
		"secret_found":
			b = buf(1.5)
			partials(b, 0.0, _f(P, 4, 69), 1.1, 0.5, BELL, BELL_A, 3.0)
			partials(b, 0.28, _f(P, 6, 69), 1.1, 0.5, BELL, BELL_A, 3.0)
			for i in 5:
				partials(b, 0.5 + i * 0.06, _f(P, 9 + i, 69), 0.4, 0.15, GLASS, GLASS_A, 10.0)
			noise(b, 0.0, 0.6, 0.05, 4.0, 0.03, rng, 0.0, 0.2)
			return finish(echo(b, [0.31, 0.62], [0.35, 0.2], 0.5), 0.34, 0.01, 0.2)
		"boss_sting":
			b = buf(2.2)
			var r0 := _f(P, 0, 33)
			partials(b, 0.0, r0, 2.0, 0.8, SOFT, SOFT_A, 1.5, 0.05)
			partials(b, 0.0, r0 * Music.TRITONE, 2.0, 0.5, SOFT, SOFT_A, 1.6, 0.08)
			partials(b, 0.15, r0 * 2.0 * Music.MINOR_SECOND, 1.8, 0.35, SOFT, SOFT_A, 1.8, 0.1)
			sweep(b, 0.0, 90.0, 38.0, 0.5, 0.9, 6.0)
			partials(b, 0.4, r0 * 4.0 * Music.TRITONE, 1.4, 0.3, METAL, METAL_A, 3.5)
			return finish(echo(b, [0.31, 0.5], [0.3, 0.18], 0.5), 0.4, 0.01, 0.3)
		"path_change":
			b = buf(0.9)
			sweep(b, 0.0, 90.0, 180.0, 0.5, 0.6, 3.5, 0.15)
			partials(b, 0.12, _f(P, 0, 62), 0.7, 0.4, BELL, BELL_A, 4.0)
			partials(b, 0.3, _f(P, 4, 62), 0.55, 0.4, BELL, BELL_A, 4.0)
			return finish(echo(b, [0.25], [0.25], 0.2), 0.34, 0.01, 0.12)
	b = buf(0.2)
	partials(b, 0.0, 440.0, 0.15, 0.5, SOFT, SOFT_A, 20.0)
	return finish(b)


## Synergy chord: absolute ratios above the root, stacked from small integers: 1, 3:2, 5:2 (=5:4 up an octave),
## 7:4, 9:4, 11:4, 15:4. Pairwise they give 3:2, 5:3, 7:4, 5:2 ...; every ratio has denominator <= 4.
const SYN_RATIOS := [1.0, 3.0 / 2.0, 5.0 / 2.0, 7.0 / 4.0, 9.0 / 4.0, 11.0 / 4.0, 15.0 / 4.0]
const FM_PAIRS := [[1, 1], [2, 1], [3, 2], [3, 1], [5, 3], [4, 3], [5, 2], [7, 4]]   # carrier:modulator small-integer ratios


static func synergy_freqs(count: int, P: Dictionary) -> Array:
	var root: float = float(P["root_hz"]) * 4.0 * Music.TUNINGS[int(P["tuning"])][0]
	var out: Array = []
	for i in mini(count + 1, 7):
		out.append(root * float(SYN_RATIOS[i]))
	return out


static func synergy(count: int, P: Dictionary) -> PackedFloat32Array:
	var b := buf(2.0)
	var fr := synergy_freqs(count, P)
	for i in fr.size():
		partials(b, i * 0.045, float(fr[i]), 1.6, 0.5 - i * 0.03, BELL, BELL_A, 2.4 + i * 0.15)
	partials(b, 0.0, float(P["root_hz"]) * 2.0, 1.8, 0.5, SOFT, SOFT_A, 1.5, 0.08)
	return finish(echo(b, [0.2, 0.2 * Music.PHI], [0.25, 0.14], 0.4), 0.2 + 0.03 * count, 0.01, 0.25)


## Item voice definition from id + tags: inharmonic partial set (family table with id-hash-perturbed ratios, plus one
## small-integer harmonic per tag) and a ratio-locked FM pair p:q with modulation index.
static func item_profile(id: String, tags: Array) -> Dictionary:
	var h := hash_str(id)
	var fam: Array = SOFT
	var fam_a: Array = SOFT_A
	if tags.has("bladed") or tags.has("armor") or tags.has("weapon"):
		fam = METAL
		fam_a = METAL_A
	elif tags.has("crystal") or tags.has("light") or tags.has("charm") or tags.has("fractal"):
		fam = GLASS
		fam_a = GLASS_A
	elif tags.has("tool") or tags.has("ranged"):
		fam = BELL
		fam_a = BELL_A
	var ratios: Array = []
	var amps: Array = []
	for i in fam.size():
		ratios.append(float(fam[i]) * (1.0 + float(((h >> (i * 4)) & 15) - 7) / 700.0))
		amps.append(float(fam_a[i]) * (0.75 + 0.5 * float((h >> (i * 3 + 1)) & 7) / 7.0))
	for t in tags:
		ratios.append(float(2 + hash_str(String(t)) % 6) + float(h & 3) / 400.0)   # one harmonic per tag
		amps.append(0.18)
	var pair: Array = FM_PAIRS[(h >> 8) % FM_PAIRS.size()]
	return {"ratios": ratios, "amps": amps, "fm_c": int(pair[0]), "fm_m": int(pair[1]), "index": 0.8 + float((h >> 12) & 7) * 0.3}


## Ratio-locked FM voice: carrier fc, modulator fc * m / c (integer-ratio locked), exponentially decaying index.
static func fm(out: PackedFloat32Array, t0: float, fc: float, c: int, m: int, index: float, dur: float, amp: float,
		decay: float, attack := 0.004) -> void:
	var n := out.size()
	var s0 := int(t0 * RATE)
	var cnt := int(dur * RATE)
	var att := maxi(int(attack * RATE), 1)
	var rel := maxi(int(0.012 * RATE), 1)
	var wc := TAU * fc / RATE
	var wm := wc * float(m) / float(c)
	var dm := exp(-decay / RATE)
	var im := exp(-decay * 1.7 / RATE)
	var g := 1.0
	var ix := index
	for i in cnt:
		var idx := s0 + i
		if idx >= n:
			break
		var e := g
		if i < att:
			e *= float(i) / att
		elif i > cnt - rel:
			e *= float(cnt - i) / rel
		out[idx] += sin(wc * i + ix * sin(wm * i)) * e * amp
		g *= dm
		ix *= im


## Signature sound for one item, derived from its id (pitch, detail) and tags (timbre).
static func item_sound(id: String, P: Dictionary) -> PackedFloat32Array:
	var d := ItemDB.get_def(id)
	var tags: Array = d.get("tags", [])
	var h := hash_str(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = h
	var deg := h % 7
	var f := _f(P, deg, 57 + 12 * (h >> 4 & 1))
	var b := buf(1.4)
	var kind := String(d.get("kind", "active"))
	if tags.has("bladed"):
		noise(b, 0.0, 0.015, 0.7, 0.0, 0.7, rng, 0.25)                 # steel scrape
		sweep(b, 0.0, f * 3.0, f * 2.0, 0.05, 0.25, 30.0)
		partials(b, 0.0, f * 2.0, 1.0, 0.7, METAL, METAL_A, 4.5 + float(h % 5) * 0.4)
	elif tags.has("ranged"):
		sweep(b, 0.0, f * 2.0, f * 1.55, 0.1, 0.6, 20.0)                # string twang
		partials(b, 0.0, f * 1.5, 0.7, 0.5, [1.0, 2.0, 3.0, 4.0], [1.0, 0.6, 0.4, 0.2], 7.0)
		noise(b, 0.05, 0.14, 0.2, 14.0, 0.25, rng, 0.0, 0.04)           # arrow hiss
	if tags.has("armor"):
		sweep(b, 0.0, 150.0, 55.0, 0.22, 1.0, 14.0)                    # dull thud
		noise(b, 0.0, 0.03, 0.3, 40.0, 0.1, rng)
		partials(b, 0.03, f * 1.5, 0.9, 0.4, GLASS, GLASS_A, 5.0)       # lapis chime
		partials(b, 0.03, f * 2.25, 0.9, 0.22, GLASS, GLASS_A, 6.0)
	if tags.has("potion"):
		for i in 4:
			var t0 := 0.03 + i * 0.09 + rng.randf() * 0.03
			var fb := f * (2.0 + rng.randf() * 2.0)
			sweep(b, t0, fb, fb * 1.6, 0.07, 0.4, 26.0, 0.005)            # bubbles
	if tags.has("bloom") or (tags.has("living") and not tags.has("potion") and not tags.has("fractal")):
		var amp := 0.7 if tags.has("bloom") else 0.4
		partials(b, 0.0, f, 1.1, amp, SOFT, SOFT_A, 3.0, 0.16)          # bloom swell
		partials(b, 0.05, f * 1.5, 1.0, amp * 0.6, SOFT, SOFT_A, 3.0, 0.2)
	if tags.has("plant") and not (tags.has("bloom") or tags.has("living")):
		partials(b, 0.0, f, 0.9, 0.5, SOFT, SOFT_A, 4.0, 0.06)
	if tags.has("crystal") and not tags.has("armor"):
		partials(b, 0.0, f * 2.0, 1.3, 0.55, GLASS, GLASS_A, 2.8 + float(h % 3) * 0.3)
		partials(b, 0.07, f * 3.0, 1.0, 0.3, GLASS, GLASS_A, 3.4)
	if tags.has("light"):
		for i in 5:   # shimmer: a fast rising sprinkle
			partials(b, i * 0.045, f * 4.0 * (1.0 + 0.1 * i), 0.45, 0.2, GLASS, GLASS_A, 8.0)
	if tags.has("tool"):
		noise(b, 0.0, 0.02, 0.6, 0.0, 0.3, rng, 0.1)                     # wooden tick
		partials(b, 0.0, f, 0.35, 0.4, [1.0, 2.3, 4.1], [1.0, 0.4, 0.2], 14.0)
		if tags.has("lens"):
			partials(b, 0.1, f * 4.0, 0.7, 0.35, BELL, BELL_A, 4.0)
		if tags.has("whetstone"):
			noise(b, 0.0, 0.2, 0.25, 12.0, 0.4, rng, 0.2, 0.01)
		if tags.has("quiver"):
			noise(b, 0.0, 0.1, 0.3, 20.0, 0.1, rng, 0.0, 0.01)
	if tags.has("charm"):
		for i in 3:
			partials(b, i * 0.12, _f(P, deg + i * 2, 69), 0.7, 0.4, BELL, BELL_A, 4.5)
	if tags.has("fractal"):
		# self-similar arpeggio: the figure repeats at 1/2 scale and 1/2 amplitude, three levels deep
		var base := 0.0
		var scale := 1.0
		for lvl in 3:
			for k in 3:
				var fk := _f(P, deg + k * 2 + lvl * 2, 60)
				partials(b, base + k * 0.1 * scale, fk * (1.0 + lvl), 0.9 * scale + 0.15, 0.55 * scale, GLASS, GLASS_A, 4.0 + lvl * 3.0)
			base += 0.3 * scale
			scale *= 0.5
	if tags.has("weapon") and not tags.has("bladed") and not tags.has("ranged"):
		partials(b, 0.0, f, 0.6, 0.5, METAL, METAL_A, 7.0)
	if kind == "passive":
		partials(b, 0.0, f * 0.5, 1.0, 0.25, SOFT, SOFT_A, 3.0, 0.12)   # passives hum softly
	var ip := item_profile(id, tags)
	partials(b, 0.0, f * 2.0, 1.2, 0.3, ip["ratios"], ip["amps"], 4.0 + float(h % 3))   # id+tag-derived inharmonic bell
	fm(b, 0.0, f, int(ip["fm_c"]), int(ip["fm_m"]), float(ip["index"]), 0.9, 0.3, 5.0)
	return finish(echo(b, [0.17, 0.17 * Music.PHI], [0.2, 0.1], 0.3), 0.36, 0.004, 0.12)


# ------------------------------------------------------------------ DSP toolkit

static func buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * RATE))
	return b


## Additive inharmonic note, summed into out at t0 seconds. Higher partials decay faster.
static func partials(out: PackedFloat32Array, t0: float, freq: float, dur: float, amp: float,
		ratios: Array, amps: Array, decay: float, attack := 0.004, wrap := false) -> void:
	var n := out.size()
	var s0 := int(t0 * RATE)
	var cnt := int(dur * RATE)
	var att := maxi(int(attack * RATE), 1)
	var rel := maxi(int(0.012 * RATE), 1)
	for p in ratios.size():
		var fp := freq * float(ratios[p])
		if fp > 7400.0:
			continue
		var w := TAU * fp / RATE
		var a := amp * float(amps[p])
		var dm := exp(-decay * (1.0 + 0.3 * p) / RATE)
		var g := 1.0
		for i in cnt:
			var idx := s0 + i
			if wrap:
				idx %= n
			elif idx >= n:
				break
			var e := g
			if i < att:
				e *= float(i) / att
			elif i > cnt - rel:
				e *= float(cnt - i) / rel
			out[idx] += sin(w * i) * e * a
			g *= dm


## Sine with exponential pitch glide f0 -> f1.
static func sweep(out: PackedFloat32Array, t0: float, f0: float, f1: float, dur: float, amp: float,
		decay: float, attack := 0.003, wrap := false) -> void:
	var n := out.size()
	var s0 := int(t0 * RATE)
	var cnt := maxi(int(dur * RATE), 2)
	var att := maxi(int(attack * RATE), 1)
	var rel := maxi(int(0.01 * RATE), 1)
	var fm := pow(f1 / f0, 1.0 / cnt)
	var dm := exp(-decay / RATE)
	var f := f0
	var ph := 0.0
	var g := 1.0
	for i in cnt:
		var idx := s0 + i
		if wrap:
			idx %= n
		elif idx >= n:
			break
		var e := g
		if i < att:
			e *= float(i) / att
		elif i > cnt - rel:
			e *= float(cnt - i) / rel
		out[idx] += sin(ph) * e * amp
		ph += TAU * f / RATE
		f *= fm
		g *= dm


## Low-passed (lp = coefficient 0..1) noise burst, optional high-pass (hp coefficient).
static func noise(out: PackedFloat32Array, t0: float, dur: float, amp: float, decay: float, lp: float,
		rng: RandomNumberGenerator, hp := 0.0, attack := 0.001, wrap := false) -> void:
	var n := out.size()
	var s0 := int(t0 * RATE)
	var cnt := int(dur * RATE)
	var att := maxi(int(attack * RATE), 1)
	var rel := maxi(int(0.006 * RATE), 1)
	var dm := exp(-decay / RATE)
	var g := 1.0
	var l := 0.0
	var h := 0.0
	for i in cnt:
		var idx := s0 + i
		if wrap:
			idx %= n
		elif idx >= n:
			break
		l += (rng.randf() * 2.0 - 1.0 - l) * lp
		var v := l
		if hp > 0.0:
			h += (v - h) * hp
			v -= h
		var e := g
		if i < att:
			e *= float(i) / att
		elif i > cnt - rel:
			e *= float(cnt - i) / rel
		out[idx] += v * e * amp
		g *= dm


## Normalise to `peak` and fade the edges (no clicks).
static func finish(b: PackedFloat32Array, peak := PEAK, fade_in := 0.003, fade_out := 0.03) -> PackedFloat32Array:
	var mx := 0.0001
	for v in b:
		mx = maxf(mx, absf(v))
	var k := peak / mx
	var n := b.size()
	var fi := maxi(int(fade_in * RATE), 1)
	var fo := maxi(int(fade_out * RATE), 1)
	for i in n:
		var e := k
		if i < fi:
			e *= float(i) / fi
		if i >= n - fo:
			var r := float(n - 1 - i) / fo
			e *= r * r
		b[i] *= e
	return b


## Dry buffer + discrete echo taps (no feedback), extended by `tail` seconds.
static func echo(src: PackedFloat32Array, delays: Array, gains: Array, tail: float) -> PackedFloat32Array:
	var out := src.duplicate()
	out.resize(src.size() + int(tail * RATE))
	for t in delays.size():
		var d := int(float(delays[t]) * RATE)
		var g := float(gains[t])
		for i in mini(src.size(), out.size() - d):
			out[i + d] += src[i] * g
	return out


static func to_pcm(b: PackedFloat32Array) -> PackedByteArray:
	var d := PackedByteArray()
	d.resize(b.size() * 2)
	for i in b.size():
		d.encode_s16(i * 2, int(clampf(b[i], -1.0, 1.0) * 32767.0))
	return d
