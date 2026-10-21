extends SceneTree
## Headless full-run simulation with stub screens: godot --headless --path . -s game/test_run.gd
## 100 seeded runs (random valid choices), checks no soft-lock, sane progression, pack integrity and Meta updates.

const RUNS := 100
const MAX_FRAMES := 4000

var fails: int = 0
var run_done := false
var run_won := false
var run_depth := 0
var stub_rng := RandomNumberGenerator.new()
var calls: Dictionary = {}


func check(cond: bool, label: String) -> void:
	if not cond:
		print("FAIL " + label)
		fails += 1


# --- stubs ----------------------------------------------------------------------------------------

class StubMap extends Control:
	signal node_chosen(node: Dictionary)
	var levels: Array = []
	var cur := -1
	var src: RandomNumberGenerator
	var mutations: Array = []
	func generate(p_seed: int, _origin: String, _hero: String) -> void:
		src = RandomNumberGenerator.new()
		src.seed = p_seed
		var types := ["fight", "fight", "treasure", "shop", "rest", "shrine", "dilemma", "mystery", "elite"]
		for d in 7:
			var row: Array = []
			for i in 2:
				row.append({"id": d * 2 + i, "type": types[src.randi() % types.size()] if d > 0 else "fight", "depth": d,
						"children": [], "revealed": true, "state": "open"})
			levels.append(row)
		levels.append([{"id": 99, "type": "boss", "depth": 7, "children": [], "revealed": true, "state": "open"}])
	func reveal_choices() -> void:
		cur += 1
		var row: Array = levels[mini(cur, levels.size() - 1)]
		node_chosen.emit(row[src.randi() % row.size()])
	func mutate(mode: String) -> void:
		mutations.append(mode)

class StubBattle extends Control:
	signal finished(won: bool, player_state: Dictionary)
	var src: RandomNumberGenerator
	func start(bp: Backpack, ids: Array, ps: Dictionary, _hero: String, _rng: RandomNumberGenerator) -> void:
		assert(bp != null and ids.size() >= 1 and ps.has("hp"))
		var win: bool = src.randf() < (0.8 if ids[0] != EnemyDB.BOSS_ID else 0.7)
		var out := ps.duplicate()
		out["hp"] = maxi(1, int(ps["hp"]) - src.randi_range(0, 10)) if win else 0
		finished.emit(win, out)

class StubLoot extends Control:
	signal chosen(id: String)
	var src: RandomNumberGenerator
	func show_offers(ids: Array) -> void:
		assert(ids.size() == 3)
		chosen.emit("" if src.randf() < 0.1 else String(ids[src.randi() % ids.size()]))

class StubDilemma extends Control:
	signal chosen(index: int)
	var src: RandomNumberGenerator
	func show_dilemma(d: Dictionary) -> void:
		chosen.emit(src.randi() % (d["choices"] as Array).size())

class StubShrine extends Control:
	signal done
	var key := ""
	func open(_rng: RandomNumberGenerator = null) -> void:
		key = Lexicon.learn_random(-1, _rng)
		done.emit()

class StubBackpack extends Control:
	signal hold_finished(placed: bool)
	var bp: Backpack
	var src: RandomNumberGenerator
	func setup(p_bp: Backpack, _mode: String) -> void:
		bp = p_bp
	func hold(id: String) -> void:
		var spot: Dictionary = bp.find_spot(id)
		var ok: bool = not spot.is_empty() and src.randf() > 0.1
		if ok:
			bp.place(id, spot["pos"], int(spot["rot"]))
		hold_finished.emit(ok)


func factory(kind: String) -> Node:
	calls[kind] = int(calls.get(kind, 0)) + 1
	var n: Node = null
	match kind:
		"map": n = StubMap.new()
		"battle": n = StubBattle.new(); n.src = stub_rng
		"loot": n = StubLoot.new(); n.src = stub_rng
		"dilemma": n = StubDilemma.new(); n.src = stub_rng
		"shrine": n = StubShrine.new()
		"backpack": n = StubBackpack.new(); n.src = stub_rng
	return n


# --- helpers --------------------------------------------------------------------------------------

func pack_ok(bp: Backpack) -> bool:
	var seen: Dictionary = {}
	for uid in bp.uids():
		for c in bp.cells_of(uid):
			if c.x < 0 or c.y < 0 or c.x >= bp.w or c.y >= bp.h or seen.has(c):
				return false
			seen[c] = true
			if bp.uid_at(c) != uid:
				return false
	return true


func _on_end(won: bool, depth: int) -> void:
	run_done = true
	run_won = won
	run_depth = depth


func _init() -> void:
	_main.call_deferred()


func _main() -> void:
	Meta.reset_for_tests("user://test_run_meta.cfg")
	var heroes := ["seshat", "thoth"]
	var origins := ["eclipse", "mirror", "cathedral"]

	# starting packs
	for h in heroes:
		for o in origins:
			var pk: Backpack = Run.make_pack(h, o)
			var want: int = (Run.HEROES[h]["items"] as Array).size() + 1
			check(pk.placed.size() == want, "start pack %s/%s places all %d items (got %d)" % [h, o, want, pk.placed.size()])
			check(pack_ok(pk), "start pack valid %s/%s" % [h, o])
	check(Run.make_pack("thoth", "eclipse").placed.any(func(e: Dictionary) -> bool: return e.id == "glyph_lens"), "thoth starts with glyph_lens")
	check(Run.make_pack("seshat", "eclipse").adjacency_bonus == 1, "seshat adjacency bonus")

	var wins := 0
	var depth_sum := 0
	var max_depth := 0
	var effects_seen: Dictionary = {}
	for i in RUNS:
		stub_rng.seed = 1000 + i
		var run := Run.new()
		run.instant = true
		run.autoplay = true
		run.screen_factory = factory
		get_root().add_child(run)
		run_done = false
		run.run_ended.connect(_on_end)
		var hero: String = heroes[i % 2]
		var origin: String = origins[i % 3]
		var uses_before: int = int(Meta.hero_stats.get(hero, {"runs": 0})["runs"])
		run.begin(hero, origin, 5000 + i)
		var frames := 0
		while not run_done and frames < MAX_FRAMES:
			await process_frame
			frames += 1
		check(run_done, "run %d finished (no soft-lock, %d frames)" % [i, frames])
		check(run.depth >= 1 and run.depth <= 8, "run %d sane depth %d" % [i, run.depth])
		check(run.hp >= 1 or not run_won, "run %d hp sane when won" % i)
		check(run.max_hp >= 5 and run.gold >= 0 and run.hp <= run.max_hp, "run %d state bounds" % i)
		check(pack_ok(run.bp), "run %d pack valid" % i)
		check(run.bp.placed.size() >= 1, "run %d pack not empty" % i)
		check(not run_won or run_depth == 8, "run %d win only at the boss (depth %d)" % [i, run_depth])
		check(int(Meta.hero_stats[hero]["runs"]) == uses_before + 1, "run %d recorded in Meta" % i)
		if run_won:
			wins += 1
		depth_sum += run.depth
		max_depth = maxi(max_depth, run.depth)
		for k in run.visited:
			effects_seen[k] = true
		run.queue_free()
		await process_frame

	check(wins > 0 and wins < RUNS, "mixed outcomes (%d wins / %d)" % [wins, RUNS])
	check(Meta.best_progress == max_depth, "Meta.best_progress == %d (got %d)" % [max_depth, Meta.best_progress])
	check(Meta.known_words.size() > 0, "lexicon words learned")
	check(Meta.bestiary.size() > 0, "bestiary filled")
	check(Meta.is_hero_unlocked("thoth"), "thoth unlocked by progress")
	for t in ["fight", "treasure", "shop", "rest", "shrine", "dilemma", "elite", "boss"]:
		check(effects_seen.has(t), "node type visited: " + t)

	# every dilemma choice applies cleanly
	var applied := 0
	for did in DilemmaDB.all_ids():
		var d: Dictionary = DilemmaDB.get_def(did)
		for ch: Dictionary in d["choices"]:
			var run2 := Run.new()
			run2.instant = true
			run2.autoplay = true
			stub_rng.seed = 77
			run2.screen_factory = factory
			get_root().add_child(run2)
			run2.begin("seshat", "eclipse", 9)
			await process_frame
			await run2.apply_effects(ch["effects"])
			check(run2.hp >= 1 and run2.hp <= run2.max_hp and run2.gold >= 0, "dilemma %s effects keep state sane" % did)
			check(pack_ok(run2.bp) and run2.bp.placed.size() >= 1, "dilemma %s keeps pack valid" % did)
			applied += 1
			run2.ended = true
			run2.queue_free()
			await process_frame
	check(applied >= 24, "applied all dilemma choices (%d)" % applied)

	# shrink/grow extremes
	var run3 := Run.new()
	run3.instant = true
	run3.screen_factory = factory
	get_root().add_child(run3)
	run3.begin("thoth", "cathedral", 3)
	await process_frame
	await run3.apply_effects([{"type": "shrink_pack", "amount": 12}])
	check(pack_ok(run3.bp) and run3.bp.w >= 3 and run3.bp.h >= 3, "shrink floors at 3x3 and stays valid")
	await run3.apply_effects([{"type": "grow_pack", "amount": 12}])
	check(run3.bp.w <= Run.MAX_W and run3.bp.h <= Run.MAX_H, "grow capped")
	run3.ended = true

	DirAccess.remove_absolute("user://test_run_meta.cfg")
	print("RESULT " + ("ALL PASS" if fails == 0 else "FAILS: %d" % fails) + " wins=%d/%d avg_depth=%.2f calls=%s" % [wins, RUNS, float(depth_sum) / RUNS, str(calls)])
	quit(1 if fails > 0 else 0)
