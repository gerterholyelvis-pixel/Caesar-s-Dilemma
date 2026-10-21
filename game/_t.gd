extends SceneTree
func _init() -> void:
	for th in Music.THEME_NAMES:
		var t := Time.get_ticks_msec()
		var r := Music.bake_theme(th, 1234)
		print(th, " ", Time.get_ticks_msec() - t, " ", Music.avg_motion(r["voicings"]))
	quit()
