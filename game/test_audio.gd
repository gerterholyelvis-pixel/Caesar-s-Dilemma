extends SceneTree

var fails := 0

func check(ok: bool, msg: String) -> void:
	print(("PASS " if ok else "FAIL ") + msg)
	if not ok:
		fails += 1

func peak(b: PackedFloat32Array) -> float:
	var m := 0.0
	for v in b:
		m = maxf(m, absf(v))
	return m

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	# determinism + different seeds
	var a := Music.bake_theme("limbo", 1234)
	var b := Music.bake_theme("limbo", 1234)
	check(hash(a["stems"][1].to_byte_array()) == hash(b["stems"][1].to_byte_array()), "limbo deterministic")
	var modes := {}
	for s in [1, 2, 3, 42, 777, 9001, 31337, 123456]:
		modes[Music.profile(s)["mode_name"]] = true
	check(modes.size() >= 4, "seeds give varied modes: %s" % str(modes.keys()))
	var c := Music.bake_theme("limbo", 777)
	check(hash(a["stems"][0].to_byte_array()) != hash(c["stems"][0].to_byte_array()) or a["mode"] != c["mode"], "different seed differs")
	var tot_bytes := 0
	var tmax := 0
	var tsum := 0
	for th in Music.THEME_NAMES:
		var t1 := Time.get_ticks_msec()
		var r := Music.bake_theme(th, 1234)
		var dt := Time.get_ticks_msec() - t1
		tmax = maxi(tmax, dt)
		tsum += dt
		var ok := true
		var msg := ""
		for i in Music.STEMS:
			var st: PackedFloat32Array = r["stems"][i]
			tot_bytes += st.size() * 2
			var pk := peak(st)
			if pk >= 0.5 or (pk < 0.02 and not (th == "shrine" and i == 2 and false) and not (th == "shrine" and pk == 0.0 and i == 2 and false)):
				ok = false
				msg += " stem%d peak=%.3f" % [i, pk]
			var d := absf(st[st.size() - 1] - st[0])
			if d > 0.04:
				ok = false
				msg += " stem%d loopgap=%.3f" % [i, d]
		check(ok, "%s mode=%s n=%d bake=%dms%s" % [th, r["mode"], r["n"], dt, msg])
	check(tot_bytes < 40 * 1024 * 1024, "memory %.1f MB" % (tot_bytes / 1048576.0))
	check(tsum < 6000, "music total bake %d ms" % tsum)
	theory()
	var t2 := Time.get_ticks_msec()
	var bank := Sfx.bake_all(1234)
	print("sfx bake ms ", Time.get_ticks_msec() - t2)
	var names: Array = Sfx.NAMES.duplicate()
	for id in ItemDB.all_ids():
		names.append("item_" + id)
	for k in range(1, 7):
		names.append("syn_%d" % k)
	check(ItemDB.all_ids().size() == 26, "26 items")
	var hashes := {}
	for nm in names:
		var ok2: bool = bank.has(nm)
		var pk2 := 0.0
		if ok2:
			var bf: PackedFloat32Array = bank[nm]
			pk2 = peak(bf)
			ok2 = pk2 > 0.1 and pk2 < 0.5 and absf(bf[0]) < 0.01 and absf(bf[bf.size() - 1]) < 0.01
			hashes[hash(bf.to_byte_array())] = true
		check(ok2, "%s peak=%.2f" % [nm, pk2])
	check(hashes.size() == names.size(), "all sounds unique")
	# previews
	var dir := ProjectSettings.globalize_path("res://").path_join("../audio_preview")
	DirAccess.make_dir_recursive_absolute(dir)
	_save(_mix_theme(Music.bake_theme("limbo", 1234), [1.0, 0.8, 0.0], 2), dir.path_join("limbo.wav"))
	_save(_mix_theme(Music.bake_theme("battle", 1234), [1.0, 1.0, 1.0], 2), dir.path_join("battle.wav"))
	_save(bank["item_bone_blade"], dir.path_join("item_bone_blade.wav"))
	print("total ms ", Time.get_ticks_msec() - t0, " max theme ms ", tmax)
	print("FAILS: ", fails)
	quit(1 if fails > 0 else 0)

func _mix_theme(r: Dictionary, g: Array, reps: int) -> PackedFloat32Array:
	var n: int = r["n"]
	var o := PackedFloat32Array()
	o.resize(n * reps)
	for i in n * reps:
		var j := i % n
		o[i] = r["stems"][0][j] * g[0] + r["stems"][1][j] * g[1] + r["stems"][2][j] * g[2]
	return o

func _save(buf: PackedFloat32Array, path: String) -> void:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 16000
	w.data = Sfx.to_pcm(buf)
	print("save ", path, " ", w.save_to_wav(path))


func near(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


func theory() -> void:
	var seeds := [1, 2, 3, 42, 777, 9001, 31337, 123456]
	# --- tuning: cent-accurate just-intonation tables
	var tun := {}
	for s in seeds:
		tun[Music.profile(s)["tuning_name"]] = true
	check(tun.size() >= 2, "seeds give varied tunings %s" % str(tun.keys()))
	var ok := true
	for t in Music.TUNINGS:
		ok = ok and near(t[7], 1.5, 1e-9) and near(t[5], 4.0 / 3.0, 1e-9) and near(t[0], 1.0, 0.0)
		for i in range(1, 12):
			ok = ok and t[i] > t[i - 1]
	check(ok, "tuning tables monotonic, fifth 3:2, fourth 4:3")
	check(near(Music.cents(3.0 / 2.0), 701.955, 0.001) and near(Music.cents(45.0 / 32.0), 590.224, 0.001) and near(Music.cents(16.0 / 15.0), 111.731, 0.001), "cents: 3:2=701.955 tritone 45:32=590.224 16:15=111.731")
	var P := Music.profile(1234)
	var root_hz: float = P["root_hz"]
	check(near(Music.freq(P, int(P["root"]) + 7) / root_hz, float(P["ratios"][7]), 1e-9) and near(Music.freq(P, int(P["root"]) + 12) / root_hz, 2.0, 1e-9), "freq(): fifth ratio exact, octave 2:1 (%s, detune %.0f c)" % [P["tuning_name"], P["detune_cents"]])
	var sc_ok := true
	for i in (P["steps"] as Array).size():
		var want: float = Music.cents(float(P["ratios"][int(P["steps"][i])])) + float(P["detune_cents"])
		sc_ok = sc_ok and near(P["scale_cents"][i], want, 1e-6)
	check(sc_ok, "scale_cents table matches ratios")
	# --- Euclid
	ok = true
	for kn in [[3, 8], [5, 8], [7, 12], [2, 6], [5, 12], [3, 5], [4, 10], [7, 16]]:
		var on := Music.euclid_onsets(kn[0], kn[1])
		var gmin := 99
		var gmax := 0
		for i in on.size():
			var g: int = (int(on[(i + 1) % on.size()]) - int(on[i]) + kn[1]) % kn[1]
			gmin = mini(gmin, g)
			gmax = maxi(gmax, g)
		ok = ok and on.size() == kn[0] and gmax - gmin <= 1
	check(ok, "Euclid E(k,n): k onsets, gaps differ by <= 1")
	var e38 := ""
	for v in Music.euclid(3, 8):
		e38 += "x" if v else "."
	var rot_ok := false
	for r in 8:
		if (e38.substr(r) + e38.substr(0, r)) == "x..x..x.":
			rot_ok = true
	check(rot_ok, "E(3,8) is a rotation of x..x..x. (%s)" % e38)
	# --- polyrhythm 3:2 and 4:3
	var pr := Music.polyrhythm(3, 2, 6.0)
	var shared := 0
	for ta in pr["a"]:
		for tb in pr["b"]:
			if near(ta, tb, 1e-9):
				shared += 1
	check(near(pr["a"][1], 2.0, 1e-9) and near(pr["b"][1], 3.0, 1e-9) and shared == 1, "polyrhythm 3:2 coincides only at the downbeat")
	var p43 := Music.polyrhythm(4, 3, 12.0)
	check(near(p43["a"][1], 3.0, 1e-9) and near(p43["b"][1], 4.0, 1e-9), "polyrhythm 4:3")
	# --- golden / Fibonacci
	check(near(Music.swing_pos(0.5), 0.618034, 1e-5) and near(Music.swing_pos(0.0), 0.0, 0.0), "golden swing 0.618")
	var word := Music.lsystem("A", {"A": "AB", "B": "A"}, 6)
	check(word.length() == 21 and Music.lsystem("A", {"A": "AB", "B": "A"}, 5).length() == 13, "L-system Fibonacci word lengths 13, 21")
	ok = true
	for th in Music.THEME_NAMES:
		var c: Dictionary = Music.THEMES[th]
		ok = ok and Music.is_fib(int(c["bars"])) and (c["prog"] as Array).size() == int(c["bars"])
	check(ok, "all theme phrase lengths are Fibonacci numbers (3,5,8,13)")
	check(Music.golden_bar(13) == 8 and Music.golden_bar(8) == 5 and Music.golden_bar(5) == 3, "golden-section climax bars")
	# --- per-theme harmony, voice leading, cadences, strong beats, motif memory
	var worst := 0.0
	var cad_ok := true
	var strong_ok := true
	var motif_ok := true
	var ratio_ok := true
	for th in Music.THEME_NAMES:
		for s in [1234, 777, 42]:
			var r := Music.bake_theme(th, s)
			var Pr := Music.profile(s)
			var vo: Array = r["voicings"]
			worst = maxf(worst, Music.avg_motion(vo, true))
			var l: int = (Pr["steps"] as Array).size()
			var mel: Array = r["melody"]
			var chords: Array = r["chords"]
			for nt in mel:
				if nt["strong"] and not (nt["hold"] and int(nt["bar"]) == int(r["bars"]) - 1 and r["cad"] in ["sus", "half"]):
					var cs: Array = []
					for d in chords[int(nt["bar"])]:
						cs.append(posmod(int(d), l))
					strong_ok = strong_ok and cs.has(posmod(int(nt["deg"]), l))
			var last: Dictionary = mel[mel.size() - 1]
			var ld := posmod(int(last["deg"]), l)
			var resolved: bool = r["cad"] in ["authentic", "plagal"]
			var lastc := int(r["prog"][int(r["bars"]) - 1])
			if resolved:
				cad_ok = cad_ok and ld == 0 and lastc == 0
			else:
				cad_ok = cad_ok and ld != 0 and lastc != 0
			for b in vo.size():
				var pcs: Array = []
				for d in chords[b]:
					pcs.append(Music.midi(Pr, int(d), 60) % 12)
				for m in vo[b]:
					ratio_ok = ratio_ok and pcs.has(int(m) % 12)
			var mo: Array = r["motif"]
			for i in 3:
				motif_ok = motif_ok and near(mo[3 + i]["len"], mo[i]["len"] * 0.5, 1e-9) \
					and int(mo[3 + i]["d"]) - int(mo[3]["d"]) == int(mo[i]["d"]) - int(mo[0]["d"])
	check(worst < 3.0, "voice leading: worst avg motion %.2f semitones/voice (< 3.0)" % worst)
	check(strong_ok, "strong-beat melody notes are chord tones")
	check(cad_ok, "resolved themes end on tonic; limbo/map/boss/shrine end unresolved")
	check(ratio_ok, "voicing pitches are chord tones")
	check(motif_ok, "motif contains a half-duration copy of itself with identical contour")
	var Pn := Music.profile(1234)
	var rb := Music.bake_theme("battle", 1234)
	var naive: Array = []
	for c in rb["chords"]:
		var v: Array = []
		for d in c:
			v.append(Music.midi(Pn, int(d), 60))
		v.sort()
		naive.append(v)
	check(Music.avg_motion(rb["voicings"]) <= Music.avg_motion(naive), "optimised voice leading <= root-position motion (%.2f vs %.2f)" % [Music.avg_motion(rb["voicings"]), Music.avg_motion(naive)])
	check(near(Music.TRITONE, 45.0 / 32.0, 1e-12) and near(Music.MINOR_SECOND, 16.0 / 15.0, 1e-12) and int(Music.THEMES["boss"]["danger"]) == 2, "boss uses tritone 45:32 + 16:15")
	var ec: Array = rb["euclid"]
	check(int(ec[1]) > int(ec[0]), "dense Euclid layer E(%d,%d) > calm E(%d,%d)" % [ec[1], ec[2], ec[0], ec[2]])
	ok = true
	for th in Music.THEME_NAMES:
		var x := Music.bake_theme(th, 4242)
		var y := Music.bake_theme(th, 4242)
		for i in Music.STEMS:
			ok = ok and hash(x["stems"][i].to_byte_array()) == hash(y["stems"][i].to_byte_array())
	check(ok, "all themes/stems deterministic per seed")
	# --- SFX theory
	var sp := Music.profile(1234)
	for c in range(1, 7):
		var fr := Sfx.synergy_freqs(c, sp)
		var good: bool = fr.size() == c + 1
		var rr := ""
		for i in fr.size():
			var q: float = float(fr[i]) / float(fr[0])
			good = good and near(q * 4.0, roundf(q * 4.0), 1e-9)
			rr += "%.3f " % q
		check(good, "synergy %d ratios %s" % [c, rr])
	var sf := Sfx.synergy_freqs(3, sp)
	check(near(float(sf[1]) / float(sf[0]), 1.5, 1e-9) and near(float(sf[3]) / float(sf[0]), 1.75, 1e-9), "synergy stacks 3:2 and 7:4")
	var pa := Sfx.item_profile("bone_blade", ["bladed", "weapon"])
	var pb := Sfx.item_profile("moon_bloom", ["bloom", "plant"])
	var pc := Sfx.item_profile("bone_blade", ["bladed", "weapon"])
	check(pa["ratios"] == pc["ratios"] and pa["ratios"] != pb["ratios"], "item partial sets: deterministic per id, differ across ids")
	var inh := false
	for q in pa["ratios"]:
		inh = inh or absf(float(q) - roundf(float(q))) > 0.2
	check(inh and int(pa["fm_c"]) <= 7 and int(pa["fm_m"]) <= 7, "item bell partials inharmonic, FM ratio %d:%d small-integer" % [pa["fm_c"], pa["fm_m"]])
