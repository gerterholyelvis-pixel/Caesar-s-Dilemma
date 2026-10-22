extends Control
# Renders the goblin cinematic alone. Args after '--':  --t=SECONDS (start offset)  --noaudio
# --bake: bake the score on this thread, print its duration / peak / bake time, then quit.

func _ready() -> void:
	var bake := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--t="):
			GoblinCinematic.debug_t0 = float(a.substr(4))
		elif a == "--noaudio":
			GoblinCinematic.debug_noaudio = true
		elif a == "--bake":
			bake = true
	if bake:
		var t0 := Time.get_ticks_msec()
		var st: AudioStreamWAV = load("res://descent/goblin_audio.gd").bake({"cancel": false})
		var d := st.data
		var peak := 0.0
		for i in range(0, d.size(), 2):
			peak = maxf(peak, absf(d.decode_s16(i)) / 32768.0)
		print("bake ms=", Time.get_ticks_msec() - t0, " len_s=", float(d.size() / 2) / st.mix_rate, " peak=", peak)
		var line := ""
		for w in 16:
			var pk := 0.0
			for i in range(w * 3 * 16000, mini((w + 1) * 3 * 16000, d.size() / 2), 7):
				pk = maxf(pk, absf(d.decode_s16(i * 2)) / 32768.0)
			line += "%.2f " % pk
		print("peak per 3s: ", line)
		get_tree().quit()
		return
	await GoblinCinematic.play(self)
	print("goblin finished")
	get_tree().quit()
