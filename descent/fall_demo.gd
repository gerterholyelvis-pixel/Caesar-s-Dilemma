extends Control
# Renders the fall alone. Args after '--':  --t=SECONDS (start offset)  --noaudio  --hold  (e.g. -- --t=15 --noaudio)

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--t="):
			FallCinematic.debug_t0 = float(a.substr(4))
		elif a == "--nopost":
			FallCinematic.debug_nopost = true
		elif a == "--noaudio":
			FallCinematic.debug_noaudio = true
	await FallCinematic.play(self)
	print("fall finished")
	get_tree().quit()
