extends Node
# Dev helper: renders the obsidian scene at --t=SECONDS to a PNG (--out=path). Run windowed off-screen.
func _ready() -> void:
	var t := 8.0
	var out := "res://shots/obsidian_shot.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--t="): t = float(a.substr(4))
		elif a.begins_with("--out="): out = a.substr(6)
	var s: Control = load("res://descent/obsidian_scene.tscn").instantiate()
	s.parallax_enabled = false
	add_child(s)
	s.set_process(false)
	s._t = t
	for i in 4:
		s._process(0.016)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
