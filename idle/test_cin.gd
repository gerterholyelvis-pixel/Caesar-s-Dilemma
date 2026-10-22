extends SceneTree
## Headless sanity test for FirstSproutCinematic: it plays, can be skipped, finishes exactly once and frees itself.
var fails := 0

func ok(c: bool, m: String) -> void:
	if not c:
		fails += 1
		print("FAIL ", m)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	Hub.enabled = false
	var host := Control.new()
	root.add_child(host)
	var fin := [0]
	var cin_ref: Array = []
	# 1) skip after a few frames
	var task := func() -> void:
		await FirstSproutCinematic.play(host)
		fin[0] += 1
	task.call()
	await process_frame
	await process_frame
	var cin: FirstSproutCinematic = null
	for c in host.get_children():
		if c is FirstSproutCinematic:
			cin = c
	ok(cin != null, "cinematic added to parent")
	if cin != null:
		var fired := [0]
		cin.finished.connect(func(): fired[0] += 1)
		for i in 5:
			await process_frame
		ok(cin.t > 0.0 and cin.t < FirstSproutCinematic.DURATION, "t advancing, t=%s" % cin.t)
		ok(cin.cs != null and absf(cin.cs.duration() - FirstSproutCinematic.DURATION) < 0.2, "timeline ~10 s")
		cin.skip()
		cin.skip()
		for i in 4:
			await process_frame
		ok(fired[0] == 1, "finished emitted exactly once (%d)" % fired[0])
		ok(fin[0] == 1, "play() returned once (%d)" % fin[0])
		ok(not is_instance_valid(cin) or cin.is_queued_for_deletion(), "frees itself")
	# 2) any key skips
	var fin2 := [0]
	var task2 := func() -> void:
		await FirstSproutCinematic.play(host)
		fin2[0] += 1
	task2.call()
	for i in 3:
		await process_frame
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = KEY_SPACE
	Input.parse_input_event(ev)
	for i in 6:
		await process_frame
	ok(fin2[0] == 1, "key press skips (%d)" % fin2[0])
	for c in host.get_children():
		ok(not (c is FirstSproutCinematic) or c.is_queued_for_deletion(), "no leftover cinematic")
	# 3) invalid parent is a no-op
	await FirstSproutCinematic.play(null)
	print("test_cin fails=", fails)
	quit(1 if fails > 0 else 0)
