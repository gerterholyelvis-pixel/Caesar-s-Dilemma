extends Control
## godot --path . res://idle/cin_demo.tscn -- --which=first_sprout

func _ready() -> void:
	var which := "first_sprout"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--which="):
			which = a.substr(8)
	Hub.boot()
	match which:
		"first_sprout":
			await FirstSproutCinematic.play(self)
	print("cinematic done: ", which)
	get_tree().quit()
