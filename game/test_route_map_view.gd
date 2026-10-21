extends Control
## Off-screen render test. Default: fresh growing tree. Pass user arg "mid" for a mid-run map
## (some nodes done / withered / sprouted, one word learned).


func _ready() -> void:
	Lexicon.init(7)
	Lexicon.learn("loc:fight")
	var m := RouteMap.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(m)
	m.generate(42, "eclipse", "seshat")
	if "mid" in OS.get_cmdline_user_args():
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for i in 4:
			m.autoplay_step(rng)
		m.mutate("wither")
		m.mutate("wither")
		m.mutate("sprout")
		m.mutate("reveal")
		m._grow = 1.0
