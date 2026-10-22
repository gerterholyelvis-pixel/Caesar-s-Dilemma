extends SceneTree
## godot --headless --path . -s res://idle/test_farmer.gd

var fails := 0
var granted: Array[String] = []

func check(ok: bool, msg: String) -> void:
	print(("PASS " if ok else "FAIL ") + msg)
	if not ok:
		fails += 1


func _init() -> void:
	_run()


func _run() -> void:
	IdleFlags.path = "user://test_idle_flags.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(IdleFlags.path))
	IdleFlags._loaded_path = ""
	Lexicon.init(4242)
	FarmerScene.time_scale = 6.0
	check(not FarmerScene.seen(), "not seen initially")
	var host := Control.new()
	host.size = Vector2(960, 640)
	root.add_child(host)
	var state := {"done": false}
	var runner := func():
		await FarmerScene.play(host, func(id): granted.append(id))
		state["done"] = true
	runner.call()
	await process_frame
	var sc: FarmerScene = null
	for c in host.get_children():
		if c is FarmerScene:
			sc = c
	check(sc != null, "scene instantiated")
	var frames := 0
	var lines := 0
	while not state["done"] and frames < 6000:
		await process_frame
		if is_instance_valid(sc):
			lines = sc.lines_shown
			sc.advance()
		frames += 1
	check(state["done"], "finished by advancing (frames %d)" % frames)
	check(lines == FarmerScene.LINES.size(), "all lines shown")
	check(granted == ["amber_seed"], "seed granted once")
	await process_frame
	check(not is_instance_valid(sc) or sc.is_queued_for_deletion(), "scene freed")
	check(FarmerScene.seen(), "flag persisted")
	check(Lexicon.has_concept("item:sap") and Lexicon.has_concept("item:amber_seed"), "glyph words registered")
	IdleFlags._loaded_path = ""
	check(FarmerScene.seen(), "flag reloads from disk")
	# second play is a no-op
	await FarmerScene.play(host)
	check(host.get_child_count() == 0, "plays once")
	# skip-all still grants
	granted.clear()
	state["done"] = false
	var r2 := func():
		await FarmerScene.play(host, func(id): granted.append(id), true)
		state["done"] = true
	r2.call()
	await process_frame
	for c in host.get_children():
		if c is FarmerScene and not c.is_queued_for_deletion():
			sc = c
	sc.skip_all()
	frames = 0
	while not state["done"] and frames < 3000:
		await process_frame
		frames += 1
	check(state["done"] and granted == ["amber_seed"], "skip-all finishes and still grants")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(IdleFlags.path))
	print("FAILS: ", fails)
	quit(fails)
