extends Control
## Renders a real battle over the locked garden: godot --path . game/test_flow_view.tscn -- --cam=1 --hero=thoth --seed=3
## (auto-picks the first node, then plays a few battle steps so the screenshot shows live combat)
var rs: Control
var steps := 0
func _ready() -> void:
	rs = (load("res://game/run_scene.gd") as GDScript).new()
	add_child(rs)
	rs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	await get_tree().process_frame
	rs.run.screen_hook = _hook
	get_tree().create_timer(1.5).timeout.connect(func() -> void: rs.run.map.call("autoplay_step", RandomNumberGenerator.new()))

func _hook(kind: String, node: Node) -> void:
	if kind == "map" and false:
		get_tree().create_timer(0.4).timeout.connect(func() -> void: node.call("autoplay_step", RandomNumberGenerator.new()))
	elif kind == "battle":
		for i in 3:
			await get_tree().create_timer(0.9).timeout
			if is_instance_valid(node):
				node.call("auto_step")
