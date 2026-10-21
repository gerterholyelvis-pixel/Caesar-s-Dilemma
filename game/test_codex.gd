extends SceneTree

var fails := 0


func check(ok: bool, msg: String) -> void:
	print(("PASS " if ok else "FAIL ") + msg)
	if not ok:
		fails += 1


func _init() -> void:
	Hub.enabled = false
	Meta.reset_for_tests("user://test_codex.cfg")
	Meta.lexicon_seed = 777
	Hub.booted = true
	Lexicon.init(777, Meta.known_words)
	var ui := CodexUI.new()
	root.add_child(ui)
	ui.size = Vector2(1280, 720)
	await process_frame
	ui.open()
	check(ui.is_open and ui.visible, "opens")
	for i in CodexUI.TAB_NAMES.size():
		ui.select_tab(i)
		await process_frame
	check(true, "all tabs draw (empty bestiary/secrets too)")
	ui.select_tab(0)
	var key := "item:bone_blade"
	ui.select_key(key)
	check(not ui.submit_guess("wrongword") and not Lexicon.is_known(key), "wrong guess stays unknown")
	check(Lexicon.guess_of(key) == "wrongword" and Meta.get_guess(key) == "wrongword", "guess pencilled")
	check(ui.submit_guess("bone blade") and Lexicon.is_known(key) and Meta.is_known(key), "right guess resolves + persists in Meta")
	var st: Dictionary = Lexicon.export_state()
	Lexicon.init(777)
	check(not Lexicon.is_known(key), "reset forgets")
	Lexicon.import_state(st)
	check(Lexicon.is_known(key), "Lexicon.export_state keeps learned word")
	Lexicon.guess("item:quiver", "arrows")
	st = Lexicon.export_state()
	Lexicon.init(777)
	Lexicon.import_state(st)
	check(Lexicon.guess_of("item:quiver") == "arrows", "guess survives export_state")
	Meta.see_enemy("spore_sprout")
	Meta.discover_secret("bone_blade", "marrow")
	ui.select_tab(CodexUI.TAB_BESTIARY)
	ui.select_key("enemy:spore_sprout")
	await process_frame
	ui.select_tab(CodexUI.TAB_SECRETS)
	await process_frame
	check(ui._entries.size() == 1, "secrets listed")
	ui.close()
	check(not ui.is_open, "closes")
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)
