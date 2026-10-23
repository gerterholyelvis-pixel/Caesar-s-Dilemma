extends Node
# Dev helper: renders the chamber to a PNG. Args: --cam=x,y,z,yaw,pitch  --out=path  --noaudio  --frames=N  --open
func _ready() -> void:
	var cam := [0.2, 1.65, -1.6, 0.0, 0.0]
	var out := "res://shots/chamber_shot.png"
	var frames := 14
	var open := false
	var horn := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cam="):
			var p := a.substr(6).split(",")
			for i in mini(5, p.size()):
				cam[i] = float(p[i])
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--frames="):
			frames = int(a.substr(9))
		elif a == "--horn":
			horn = true
		elif a == "--open":
			open = true
	var ch: Node3D = load("res://act1/chamber.tscn").instantiate()
	add_child(ch)
	var guard := 0
	while not ch.built and guard < 2000:
		await get_tree().process_frame
		guard += 1
	ch.skip_fade()
	ch.player.sway_enabled = false
	ch.place_player(cam[0], cam[1], cam[2], cam[3], cam[4])
	if horn and ch.horn != null:
		ch.horn.call("interact")
	if open:
		ch.open_door()
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
