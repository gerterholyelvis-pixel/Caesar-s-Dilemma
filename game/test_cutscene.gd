extends SceneTree
var fails := 0

func ok(c: bool, m: String) -> void:
	if not c:
		fails += 1
		print("FAIL ", m)

func build(b: Node2D, log: Array) -> Cutscene:
	var cs := Cutscene.new()
	cs.at(0.3, func(): log.append("b")).at(0.1, func(): log.append("a")) \
		.tween(b, "rotation", 10.0, 0.4).tween(b, "position:x", 50.0, 0.2, 0.1) \
		.at(0.5, func(): log.append("c")).wait(0.2).at(0.7, func(): log.append("z"))
	return cs

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	var b := Node2D.new()
	root.add_child(b)
	var log := []
	var cs := build(b, log)
	var steps := []
	cs.step.connect(func(i): steps.append(i))
	var fin := [0]
	cs.finished.connect(func(): fin[0] += 1)
	ok(is_equal_approx(cs.duration(), 0.7), "duration %s" % cs.duration())
	var t0 := Time.get_ticks_msec()
	await cs.play()
	var el := (Time.get_ticks_msec() - t0) / 1000.0
	ok(el >= 0.65 and el < 1.5, "play time %s" % el)
	ok(log == ["a", "b", "c", "z"], "order %s" % [log])
	ok(steps.size() == 4 and fin[0] == 1, "steps/finished")
	var end_rot := b.rotation
	var end_x := b.position.x
	ok(end_rot == 10.0 and end_x == 50.0, "end state")
	# skip + double skip
	var b2 := Node2D.new()
	root.add_child(b2)
	var log2 := []
	var cs2 := build(b2, log2)
	var fin2 := [0]
	cs2.finished.connect(func(): fin2[0] += 1)
	cs2.play()
	await process_frame
	cs2.skip()
	cs2.skip()
	await process_frame
	ok(b2.rotation == end_rot and b2.position.x == end_x, "skip end state")
	ok(log2 == ["a", "b", "c", "z"] and fin2[0] == 1, "skip once %s %s" % [log2, fin2])
	ok(cs2._tw == null or not cs2._tw.is_valid(), "no orphan tween")
	# skip before play is a no-op
	var cs3 := build(b, [])
	cs3.skip()
	ok(not cs3.done, "skip before play")
	# freed owner
	var own := Node2D.new()
	root.add_child(own)
	var cs4 := Cutscene.new().bind(own)
	var fin4 := [0]
	cs4.finished.connect(func(): fin4[0] += 1)
	cs4.tween(own, "rotation", 1.0, 0.5)
	cs4.play()
	await process_frame
	own.free()
	await process_frame
	ok(fin4[0] == 1, "freed owner finished")
	# freed target
	var tgt := Node2D.new()
	root.add_child(tgt)
	var cs5 := Cutscene.new().tween(tgt, "rotation", 3.0, 0.2, 0.1)
	cs5.play()
	tgt.free()
	await create_timer(0.5).timeout
	ok(cs5.done, "freed target ok")
	print("test_cutscene: ", "PASS" if fails == 0 else "FAILED %d" % fails)
	quit(fails)
