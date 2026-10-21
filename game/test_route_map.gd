extends SceneTree

var fails := 0


func check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL " + msg)


func count_type(m: RouteMap, t: String) -> int:
	var c := 0
	for n in m.nodes:
		if n.type == t:
			c += 1
	return c


func snap(m: RouteMap) -> Dictionary:
	var s := {}
	for n in m.nodes:
		if n.revealed or n.state == "done" or n.state == "current":
			s[n.id] = [n.type, n.state, n.revealed]
	return s


func _init() -> void:
	Lexicon.init(7)
	var modes := ["wither", "sprout", "swap", "reveal", "hide"]
	var origins := ["eclipse", "mirror", "cathedral", ""]
	var heroes := ["seshat", "thoth", ""]
	var changed_modes := {}
	for s in 500:
		var m := RouteMap.new()
		m.generate(s, origins[s % 4], heroes[s % 3])
		var D := m.depth_max
		check(D >= 9 and D <= 10, "depth %d seed %d" % [D, s])
		check(m.can_reach_boss(), "boss reachable seed %d" % s)
		check(count_type(m, "boss") == 1 and m.nodes[m.boss_id].depth == D, "single boss %d" % s)
		var d1 := 0
		for n in m.nodes:
			if n.depth == 1:
				d1 += 1
				check(n.type == "fight", "row1 fight %d" % s)
			if n.depth == 2:
				check(n.type == "fight", "row2 fight %d" % s)
			if n.depth == D / 2:
				check(n.type == "treasure", "mid treasure %d" % s)
			if n.depth == D - 1:
				check(n.type == "rest" and n.children == [m.boss_id], "rest before boss %d" % s)
			if n.type == "elite":
				check(n.depth > D / 2, "elite late %d" % s)
			if n.depth < D:
				check(n.children.size() >= 1, "no dead end %d" % s)
			for c in n.children:
				check(m.nodes[c].depth == n.depth + 1 and m.nodes[c].parents.has(n.id), "link %d" % s)
		check(d1 >= 2, "trunk forks %d" % s)
		# fractal structure: several fork levels, bounded leaves, well separated + in-area positions
		var forks := 0
		var leaves := 0
		var fork_depths := {}
		for n in m.nodes:
			if n.children.size() >= 2 and n.type != "boss":
				forks += 1
				fork_depths[n.depth] = true
			if n.depth == D - 1:
				leaves += 1
		check(forks >= 3 and fork_depths.size() >= 2, "recursive forks %d (%d/%d)" % [s, forks, fork_depths.size()])
		check(leaves >= 5 and leaves <= 14, "leaf count %d: %d" % [s, leaves])
		var mind := 9999.0
		for i in m.nodes.size():
			var pi: Vector2 = m.target_point(i)
			check(pi.x > 20 and pi.x < 940 and pi.y > 20 and pi.y < 620, "in area %d" % s)
			for j in range(i + 1, m.nodes.size()):
				mind = minf(mind, pi.distance_to(m.target_point(j)))
		check(mind >= 34.0, "separation %d: %.1f" % [s, mind])
		check(count_type(m, "shop") >= 1 and count_type(m, "shrine") >= 1 and count_type(m, "elite") >= 1, "staples %d" % s)
		check(count_type(m, "mystery") >= 1, "has mystery %d" % s)
		var m2 := RouteMap.new()
		m2.generate(s, origins[s % 4], heroes[s % 3])
		check(JSON.stringify(m.export_state()) == JSON.stringify(m2.export_state()), "deterministic %d" % s)
		# walk with mutations
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var guard := 0
		while m.current_id != m.boss_id and guard < 30:
			guard += 1
			for k in 2:
				var mode: String = modes[rng.randi() % 5]
				var before := snap(m)
				var ch := m.mutate(mode)
				if ch.size() > 0:
					changed_modes[mode] = true
				check(m.can_reach_boss(), "reach after %s seed %d" % [mode, s])
				check(m.reachable_ids().size() > 0 or m.current_id == m.boss_id, "has move %s %d" % [mode, s])
				if mode != "hide" and mode != "reveal":
					for id in before:
						var n: Dictionary = m.nodes[id]
						check([n.type, n.state, n.revealed] == before[id], "seen untouched %s %d" % [mode, s])
				if mode == "reveal":
					for id in before:
						check(m.nodes[id].type == before[id][0] and m.nodes[id].state == before[id][1], "reveal safe %d" % s)
				if mode == "hide":
					check(m.nodes[m.current_id].revealed, "hide keeps current %d" % s)
					for c in m.nodes[m.current_id].children:
						check(m.nodes[c].revealed, "hide keeps choices %d" % s)
			if not m.autoplay_step(rng):
				check(false, "stuck seed %d" % s)
				break
		check(m.current_id == m.boss_id, "walked to boss %d" % s)
		# save roundtrip
		if s % 10 == 0:
			var js := JSON.stringify(m.export_state())
			var m3 := RouteMap.new()
			m3.import_state(JSON.parse_string(js))
			check(JSON.stringify(m3.export_state()) == js, "json roundtrip %d" % s)
			m3.free()
		m.free()
		m2.free()
	for md in modes:
		check(changed_modes.has(md), "mode %s did something" % md)
	# mystery balance
	var mm := RouteMap.new()
	mm.generate(1, "", "")
	var cnt := {}
	for i in 2000:
		mm.nodes[1].erase("resolved")
		var r := mm.resolve_mystery(1)
		cnt[r] = cnt.get(r, 0) + 1
	check(cnt.get("dilemma", 0) > 20 and cnt.get("dilemma", 0) < 240, "dilemma rare %s" % str(cnt))
	check(cnt.size() == 6, "all mystery outcomes %s" % str(cnt))
	print(cnt)
	print("ROUTE_MAP %s (%d fails)" % ["OK" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)
