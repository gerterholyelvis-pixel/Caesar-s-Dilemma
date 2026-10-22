extends Control
class_name FallCinematic

# THE FALL: after the angel's last words, the floor of Limbo gives way and the traveler falls through ever deeper hells.
# Stub: owned by the cinematic agent. play() is awaitable and frees itself when finished (~40 s, skippable).

static func play(parent: Node) -> void:
	var c := FallCinematic.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(c)
	await parent.get_tree().create_timer(0.1).timeout
	c.queue_free()
