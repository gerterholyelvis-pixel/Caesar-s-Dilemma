extends SceneTree
# headless: play the fall, skip with a key press, assert it finishes once and frees itself.
var fails := 0

func ok(c: bool, m: String) -> void:
	if not c:
		fails += 1
		print("FAIL ", m)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	var host := Control.new()
	root.add_child(host)
	var n_before := host.get_child_count()
	var done := [0]
	var t0 := Time.get_ticks_msec()
	var runner := func():
		await FallCinematic.play(host)
		done[0] += 1
	runner.call()
	await create_timer(0.6).timeout
	ok(done[0] == 0, "still playing before skip")
	ok(host.get_child_count() == n_before + 1, "cinematic node added")
	var cin: Node = host.get_child(host.get_child_count() - 1)
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = KEY_SPACE
	root.push_input(ev)
	for i in 30:
		await process_frame
		if done[0] > 0:
			break
	ok(done[0] == 1, "finished exactly once after skip (%s)" % done[0])
	await process_frame
	await process_frame
	ok(not is_instance_valid(cin) or cin.is_queued_for_deletion(), "frees itself")
	ok(host.get_child_count() == n_before, "no leftover children (%s)" % host.get_child_count())
	var el := (Time.get_ticks_msec() - t0) / 1000.0
	ok(el < 8.0, "skip is quick (%s s)" % el)
	print("test_fall: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)
