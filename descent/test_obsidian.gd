extends SceneTree

func _initialize() -> void:
	var s: Control = load("res://descent/obsidian_scene.tscn").instantiate()
	root.add_child(s)
	var n := 0
	while n < 40:
		await process_frame
		n += 1
	print("OBSIDIAN OK ground=", s.ground_y_px())
	s.queue_free()
	await process_frame
	quit(0)
