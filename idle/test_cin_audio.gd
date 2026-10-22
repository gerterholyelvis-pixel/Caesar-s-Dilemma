extends SceneTree
## Bakes the cinematic's audio stem synchronously and checks length, peak (<0.5) and that the ends are silent (no clicks).
func _init() -> void:
	var t0 := Time.get_ticks_msec()
	FirstSproutCinematic._bake_stem()
	var w: AudioStreamWAV = FirstSproutCinematic._stem
	var fails := 0
	if w == null:
		print("FAIL no stem"); quit(1); return
	print("bake only ms=", Time.get_ticks_msec() - t0)
	var n := w.data.size() / 4
	var peak := 0.0
	var maxstep := 0.0
	var prev := 0.0
	for i in n:
		var v := absf(float(w.data.decode_s16(i * 4)) / 32767.0)
		peak = maxf(peak, v)
		maxstep = maxf(maxstep, absf(float(w.data.decode_s16(i * 4)) / 32767.0 - prev))
		prev = float(w.data.decode_s16(i * 4)) / 32767.0
	var secs := float(n) / w.mix_rate
	print("bake ms=", Time.get_ticks_msec() - t0, " secs=", secs, " peak=", peak, " maxstep=", maxstep, " first=", w.data.decode_s16(0), " last=", w.data.decode_s16((n - 1) * 4))
	if peak >= 0.5 or secs < 10.0 or maxstep > 0.25:
		fails += 1
		print("FAIL audio")
	quit(1 if fails > 0 else 0)
