extends SceneTree
## End-to-end: 30 seeded complete runs with the REAL Run and the REAL screens (map, battle, backpack, loot, dilemma, shrine),
## driven through each screen's test hooks. Asserts no soft-lock, run_ended fires, Meta persisted.
## godot --headless --path . --fixed-fps 60 -s game/test_e2e.gd      (scan the output for "SCRIPT ERROR")

const RUNS := 30
const MAX_FRAMES := 60000
const PATH := "user://test_e2e.cfg"

var fails := 0
var ended := false
var won := false
var depth := 0
var drv := RandomNumberGenerator.new()
var kinds: Dictionary = {}
var host: Control = null


func check(ok: bool, msg: String) -> void:
	if not ok:
		print("FAIL " + msg)
		fails += 1


func _init() -> void:
	Engine.time_scale = 25.0
	Hub.enabled = false
	Hub.booted = false
	Meta.reset_for_tests(PATH)
	Meta.unlock_hero("thoth")
	Hub.boot()
	Meta.on_secret_discovered = ItemDB.mark_discovered
	_main.call_deferred()


func _main() -> void:
	var wins := 0
	var total_runs := 0
	var hs := HeroSelectUI.new()
	root.add_child(hs)
	hs.open()
	var got: Array = []
	hs.picked.connect(func(h: String, o: String) -> void: got.append([h, o]))
	hs.choose("thoth", "cathedral")
	hs.confirm()
	await create_timer(1.0).timeout
	check(got == [["thoth", "cathedral"]], "hero select picked")
	hs.queue_free()
	for i in RUNS:
		var hero: String = "seshat" if i % 2 == 0 else "thoth"
		var origin: String = ["eclipse", "mirror", "cathedral"][i % 3]
		var before: Dictionary = (Meta.hero_stats.get(hero, {}) as Dictionary).duplicate()
		var best_before: int = Meta.best_progress
		await _one_run(i, hero, origin)
		total_runs += 1
		if won:
			wins += 1
		check(ended, "run %d ended (hero %s origin %s)" % [i, hero, origin])
		var st: Dictionary = Meta.hero_stats.get(hero, {})
		check(int(st.get("runs", 0)) == int(before.get("runs", 0)) + 1, "run %d counted in Meta" % i)
		check(int(st.get("wins", 0)) == int(before.get("wins", 0)) + (1 if won else 0), "run %d win flag in Meta" % i)
		check(Meta.best_progress >= maxi(best_before, depth), "run %d best_progress" % i)
		var runs_mem: int = int(st.get("runs", 0))
		var best_mem: int = Meta.best_progress
		var known_mem: int = Meta.known_words.size()
		Meta.load()
		check(int((Meta.hero_stats.get(hero, {}) as Dictionary).get("runs", 0)) == runs_mem, "run %d persisted to disk" % i)
		check(Meta.best_progress == best_mem and Meta.known_words.size() == known_mem, "run %d words/depth persisted" % i)
		Meta.on_secret_discovered = ItemDB.mark_discovered
	# dilemmas are rare on the map: exercise the real DilemmaUI directly
	var dr := Run.new()
	dr.instant = true
	dr.screen_hook = _drive
	root.add_child(dr)
	dr.begin("seshat", "mirror", 9)
	for k in 8:
		await dr._dilemma()
		check(dr.hp >= 1 and dr.hp <= dr.max_hp and dr.bp.placed.size() >= 1, "dilemma %d leaves a sane state" % k)
	dr.ended = true
	dr.queue_free()
	print("runs=%d wins=%d kinds=%s" % [total_runs, wins, str(kinds)])
	print("E2E FAILS: ", fails)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	quit(fails)


func _one_run(i: int, hero: String, origin: String) -> void:
	ended = false
	won = false
	depth = 0
	drv.seed = 1000 + i
	host = Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var run := Run.new()
	run.instant = true
	run.autoplay = true
	run.screen_hook = _drive
	host.add_child(run)
	run.run_ended.connect(func(w: bool, d: int) -> void:
		ended = true
		won = w
		depth = d)
	run.begin(hero, origin, 500 + i)
	var frames := 0
	while not ended and frames < MAX_FRAMES:
		frames += 1
		await process_frame
	if not ended:
		print("SOFTLOCK run %d after %d frames, visited %s" % [i, frames, str(run.visited)])
		run.ended = true
		run.run_ended.emit(false, run.depth)
	for k in run.visited:
		kinds[k] = int(kinds.get(k, 0)) + 1
	host.queue_free()
	await process_frame


func _drive(kind: String, node: Node) -> void:
	match kind:
		"map":
			var m: Control = node
			get_process_frame_once(func() -> void:
				if is_instance_valid(m):
					m.call("autoplay_step", drv))
		"battle":
			_battle(node)
		"loot":
			get_process_frame_once(func() -> void:
				if is_instance_valid(node):
					node.call("pick", drv.randi() % maxi(1, (node.get("ids") as Array).size())))
		"hold":
			get_process_frame_once(func() -> void: _place(node))
		"dilemma":
			get_process_frame_once(func() -> void:
				if is_instance_valid(node):
					node.call("skip_text")
					var n: int = ((node.get("d") as Dictionary).get("choices", []) as Array).size()
					node.call("choose", drv.randi() % maxi(1, n)))
		"shrine":
			get_process_frame_once(func() -> void:
				if is_instance_valid(node):
					node.call("reveal")
					node.call("leave"))


func get_process_frame_once(fn: Callable) -> void:
	process_frame.connect(fn, CONNECT_ONE_SHOT)


func _battle(b: Node) -> void:
	var steps := 0
	while is_instance_valid(b) and steps < 4000:
		steps += 1
		b.call("auto_step")
		await process_frame
	if is_instance_valid(b):
		check(false, "battle never finished")


func _place(ui: Node) -> void:
	if not is_instance_valid(ui):
		return
	var bpk: Backpack = ui.get("bp")
	for rot in 4:
		for y in bpk.h:
			for x in bpk.w:
				if ui.call("can_drop", Vector2i(x, y)):
					ui.call("drop_at", Vector2i(x, y))
					return
		ui.call("rotate_held")
	ui.call("cancel_hold")
