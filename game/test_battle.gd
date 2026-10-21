extends SceneTree
## Headless: auto-plays a full battle with real classes, no UI assertions.
## Run: godot --headless --path . -s game/test_battle.gd

static func make_pack() -> Backpack:
	var bp := Backpack.new()
	bp.place("bone_blade", Vector2i(0, 0), 0)
	bp.place("whetstone", Vector2i(1, 0), 0)
	bp.place("spore_flask", Vector2i(1, 1), 0)
	bp.place("moss_charm", Vector2i(2, 0), 0)
	bp.place("lapis_shield", Vector2i(3, 0), 0)
	bp.place("thorn_dagger", Vector2i(0, 3), 1)
	return bp


func _init() -> void:
	Meta.reset_for_tests("user://test_battle_meta.cfg")
	Lexicon.init(4242)
	var b := Battle.new()
	b.size = Vector2(960, 640)
	root.add_child(b)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var res := {"done": false, "won": false}
	b.finished.connect(func(w: bool, st: Dictionary) -> void:
		res["done"] = true
		res["won"] = w
		print("finished won=%s hp=%s" % [w, st.get("hp")]))
	b.start(make_pack(), ["spore_sprout", "thorn_crawler"], {"hp": 40, "max_hp": 40}, "seshat", rng)
	var steps := 0
	while b.auto_step() and steps < 400:
		steps += 1
		await process_frame
	var frames := 0
	while not res["done"] and frames < 400:
		frames += 1
		await create_timer(0.02).timeout
	var ok: bool = res["done"]
	print("steps=%d over=%s %s" % [steps, b.combat.is_over(), "PASS" if ok else "FAIL"])
	DirAccess.remove_absolute("user://test_battle_meta.cfg")
	quit(0 if ok else 1)
