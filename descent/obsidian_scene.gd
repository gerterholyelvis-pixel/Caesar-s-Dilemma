extends Control

# THE OBSIDIAN DEEP: where the fall ends and the new game begins. Stub: owned by the obsidian agent.

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.015, 0.02)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
