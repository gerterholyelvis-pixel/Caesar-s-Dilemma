extends Control
## Renders the built-in shop menu over the garden: godot --path . game/test_run_view.tscn -- --cam=1
func _ready() -> void:
	Meta.reset_for_tests("user://test_run_view.cfg")
	Lexicon.init(Meta.lexicon_seed, Meta.known_words)
	var g: Control = (load("res://garden.tscn") as PackedScene).instantiate()
	add_child(g)
	var r := Run.new()
	r.instant = true
	add_child(r)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.hp = 31; r.gold = 57; r.depth = 3
	r._build_chrome()
	r.bp = Run.make_pack("seshat", "eclipse")
	r._shop()
