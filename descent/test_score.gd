extends SceneTree
# headless: godot --headless --path . -s res://descent/test_score.gd   (bakes the 4 score variants, checks peaks)

func _init() -> void:
	var FS = load("res://descent/fall_score.gd")
	var ok := true
	for v in 4:
		var st: AudioStreamWAV = FS.bake(v, 46.5)
		if st == null:
			print("variant ", v, " null")
			ok = false
			continue
		var d := st.data
		var n := d.size() / 2
		var peak := 0.0
		var rms := []
		var acc := 0.0
		for i in n:
			var s := absf(d.decode_s16(i * 2) / 32768.0)
			peak = maxf(peak, s)
			acc += s * s
			if (i + 1) % (st.mix_rate * 4) == 0:
				rms.append(snappedf(sqrt(acc / (st.mix_rate * 4)), 0.001))
				acc = 0.0
		print("variant ", v, " ", FS.LETTERS[v], " ms=", FS.last_ms, " peak=", snappedf(peak, 0.001), " len=", n / float(st.mix_rate), " rms/4s=", rms)
		if peak > 0.5:
			ok = false
	print("SCORE TEST ", "OK" if ok else "FAIL")
	quit(0 if ok else 1)
