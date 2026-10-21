extends Control
## godot --path . game/cinematics_demo.tscn -- --which=hero_reveal|boss_intro|first_glyph|death|ending [--arg=hero/boss/key]

func _ready() -> void:
	var which := "hero_reveal"
	var arg := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--which="):
			which = a.substr(8)
		elif a.begins_with("--arg="):
			arg = a.substr(6)
	Meta.load()
	Lexicon.init(Meta.lexicon_seed, Meta.known_words)
	Cinematics.instant = false
	match which:
		"hero_reveal": await Cinematics.hero_reveal(self, arg if arg != "" else "seshat")
		"boss_intro": await Cinematics.boss_intro(self, arg if arg != "" else "cascade_warden")
		"first_glyph": await Cinematics.first_glyph(self, arg if arg != "" else "item:lens")
		"death": await Cinematics.death(self)
		"ending": await Cinematics.ending(self, arg if arg != "" else "seshat")
	print("cinematic done: ", which)
	get_tree().quit()
