extends Control
## Render harness: the open codex on a dark backdrop.

func _ready() -> void:
	Hub.enabled = false
	Meta.reset_for_tests("user://test_codex_view.cfg")
	Meta.lexicon_seed = 4242
	Hub.booted = true
	Lexicon.init(4242, Meta.known_words)
	for k in ["item:bone_blade", "item:quiver", "item:whetstone", "bonus:damage"]:
		Lexicon.learn(k)
		Meta.mark_known(k)
	Lexicon.guess("item:shard_axe", "axe of glass")
	var ui := CodexUI.new()
	add_child(ui)
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	ui.open(0)
	ui.select_key("item:crystal_bow")
