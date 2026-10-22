extends SceneTree

const Audio := preload("res://descent/goblin_audio.gd")


func _init() -> void:
	var job := {"cancel": false}
	var t0 := Time.get_ticks_msec()
	var st: AudioStreamWAV = Audio.bake(job, 84.0)
	var el := (Time.get_ticks_msec() - t0) / 1000.0
	if st == null:
		print("BAKE RETURNED NULL")
		quit(1)
		return
	var d := st.data
	var n := d.size() / 4
	print("bake secs=", el, " frames=", n, " stereo=", st.stereo, " nan=", job.get("nan", -1), " peak=", job.get("peak", 0.0))
	var pk := 0.0
	var secs := n / Audio.RATE
	var line := ""
	for s in secs:
		var acc := 0.0
		var mx := 0.0
		for i in range(s * Audio.RATE, (s + 1) * Audio.RATE):
			var l := d.decode_s16(i * 4) / 32768.0
			var r := d.decode_s16(i * 4 + 2) / 32768.0
			acc += l * l + r * r
			mx = maxf(mx, maxf(absf(l), absf(r)))
		pk = maxf(pk, mx)
		line += "%d:%.3f " % [s, sqrt(acc / (2.0 * Audio.RATE))]
		if s % 12 == 11:
			print(line)
			line = ""
	print(line)
	var nz1 := 0
	for i in range(int(74.6 * Audio.RATE), int(75.59 * Audio.RATE)):
		if d.decode_s16(i * 4) != 0 or d.decode_s16(i * 4 + 2) != 0:
			nz1 += 1
	var nz2 := 0
	for i in range(int(84.0 * Audio.RATE), n):
		if d.decode_s16(i * 4) != 0 or d.decode_s16(i * 4 + 2) != 0:
			nz2 += 1
	print("peak=", pk, " nonzero 74.6-75.59: ", nz1, " nonzero after 84: ", nz2)
	quit(0)
