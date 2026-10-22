extends Control
## godot --path . res://idle/farmer_demo.tscn -- --which=farmer [--speed=N]
func _ready() -> void:
	var speed := 1.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--speed="):
			speed = float(a.substr(8))
	FarmerScene.time_scale = speed
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--line="):
			FarmerScene.start_line = int(a.substr(7))
	if not Lexicon.has_concept("bonus:growth"):
		Lexicon.init(12345)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.12, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	await FarmerScene.play(self, func(id): print("granted ", id), true)
	print("farmer done")
	get_tree().quit()
