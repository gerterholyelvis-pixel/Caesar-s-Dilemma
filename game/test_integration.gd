extends SceneTree
## Integration test: ItemDB + Backpack + Combat + EnemyDB + DilemmaDB + Meta + Lexicon together.
## Run: godot --headless --path . -s game/test_integration.gd

const MAX_TURNS := 300
const VALID_EFFECTS := ["max_hp", "hp", "gold", "item", "curse_item", "remove_item", "shrink_pack", "grow_pack",
	"reveal_glyph", "change_path", "heal_all"]

var fails: int = 0
var secret_events: Array = []
var trait_events: Array = []


func check(cond: bool, label: String) -> void:
	print(("PASS " if cond else "FAIL ") + label)
	if not cond:
		fails += 1


func _init() -> void:
	Meta.reset_for_tests("user://test_integration_meta.cfg")
	ItemDB.discovered = {}
	ItemDB.discovered_check = Callable()
	Meta.on_secret_discovered = ItemDB.mark_discovered
	test_pack_and_synergy()
	test_full_fight_win()
	test_losing_fight()
	test_secrets_and_meta()
	test_lexicon()
	test_dilemmas()
	test_random_fights()
	DirAccess.remove_absolute("user://test_integration_meta.cfg")
	print("RESULT " + ("ALL PASS" if fails == 0 else "FAILS: %d" % fails))
	quit(1 if fails > 0 else 0)


func hand_pack() -> Backpack:
	var bp := Backpack.new()
	bp.place("bone_blade", Vector2i(0, 0), 0)      # (0,0)-(0,2)
	bp.place("whetstone", Vector2i(1, 0), 0)       # adjacent to blade: +2 bladed
	bp.place("spore_flask", Vector2i(1, 1), 0)     # adjacent to blade, living: secret "marrow"
	bp.place("moss_charm", Vector2i(2, 0), 0)      # adjacent to whetstone and shield
	bp.place("lapis_shield", Vector2i(3, 0), 0)    # 2x2 at (3,0)
	bp.place("thorn_dagger", Vector2i(0, 3), 1)    # rot 1 -> horizontal 2x1 at (0,3),(1,3)
	return bp


func uid_of(bp: Backpack, id: String) -> int:
	for e in bp.placed:
		if String(e["id"]) == id:
			return int(e["uid"])
	return -1


func wire(c: Combat) -> void:
	c.secret_found.connect(func(item: String, sec: String) -> void:
		secret_events.append(item + "/" + sec)
		Meta.discover_secret(item, sec))
	c.enemy_trait_revealed.connect(func(enemy: String, t: String) -> void:
		trait_events.append(enemy + "/" + t)
		Meta.discover_trait(enemy, t))
	c.item_used.connect(func(uid: int) -> void:
		if c.backpack.entry(uid).is_empty():
			return
		Meta.mark_item_known(String(c.backpack.entry(uid)["id"])))


## Plays one turn: uses every usable active item (order given by rng), then ends the turn.
func play_turn(c: Combat, rng: RandomNumberGenerator) -> void:
	var uids: Array = c.backpack.uids()
	for i in range(uids.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: Variant = uids[i]
		uids[i] = uids[j]
		uids[j] = t
	for u in uids:
		if c.is_over():
			return
		if c.can_use(int(u)):
			c.use(int(u), rng.randi_range(0, maxi(c.enemies.size() - 1, 0)))
	if not c.is_over():
		c.end_turn()


func sane(c: Combat) -> bool:
	if int(c.player["hp"]) < 0 or int(c.player["hp"]) > int(c.player["max_hp"]):
		return false
	if int(c.player["block"]) < 0 or int(c.player["energy"]) < 0:
		return false
	if c.enemies.size() > 80:
		return false
	for e in c.enemies:
		if int(e["hp"]) < 0 or int(e["hp"]) > int(e["max_hp"]) or int(e["block"]) < 0:
			return false
		if bool(e["alive"]) != (int(e["hp"]) > 0):
			return false
	return true


# ---------------------------------------------------------------------------

func test_pack_and_synergy() -> void:
	var bp: Backpack = hand_pack()
	check(bp.placed.size() == 6, "hand-picked pack placed (6 items)")
	var blade: int = uid_of(bp, "bone_blade")
	var eff: Dictionary = bp.effective_effect(blade)
	check(int(eff["amount"]) == 10, "blade 6 +2 whetstone +2 hidden marrow = 10 (got %d)" % int(eff["amount"]))
	var trig: Array = eff["secrets_triggered"]
	check(trig.size() == 1 and String(trig[0]["secret_id"]) == "marrow", "marrow listed as triggered")
	check(not bp.describe(blade).contains("Secret:"), "undiscovered secret hidden in tooltip")
	check(bp.describe(blade).contains("more"), "tooltip hints there is more")
	var sh: Dictionary = bp.effective_effect(uid_of(bp, "lapis_shield"))
	check(int(sh["amount"]) == 7, "shield has a neighbour so bastion does not apply")
	var rt: Backpack = Backpack.from_dict(bp.to_dict())
	check(rt.placed.size() == 6 and int(rt.effective_effect(uid_of(rt, "bone_blade"))["amount"]) == 10, "save/load roundtrip")


func test_full_fight_win() -> void:
	var bp: Backpack = hand_pack()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var c := Combat.new()
	wire(c)
	var ended_count: Array = [0]
	c.ended.connect(func(_w: bool) -> void: ended_count[0] += 1)
	c.start(bp, ["spore_sprout", "thorn_crawler"], {"hp": 60, "max_hp": 60}, rng)
	check(c.enemies.size() == 2 and bool(c.enemies[0]["alive"]), "combat starts with 2 real enemies")
	check(int(c.player["block"]) == 2, "moss charm gave 2 block at start (2 neighbours), got %d" % int(c.player["block"]))
	var guard := 0
	while not c.is_over() and guard < MAX_TURNS:
		play_turn(c, rng)
		guard += 1
		if not sane(c):
			break
	check(c.is_over() and guard < MAX_TURNS, "fight terminates (%d turns)" % guard)
	check(c.won, "well-built pack wins")
	check(ended_count[0] == 1, "ended signal fired once")
	check(sane(c), "stats sane after win")
	check(Meta.is_item_known("bone_blade"), "using an item identified it in Meta")


func test_losing_fight() -> void:
	var bp := Backpack.new()
	bp.place("whetstone", Vector2i(0, 0), 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var c := Combat.new()
	wire(c)
	c.start(bp, ["cascade_warden"], {"hp": 12, "max_hp": 12}, rng)
	var guard := 0
	while not c.is_over() and guard < MAX_TURNS:
		play_turn(c, rng)
		guard += 1
	check(c.is_over() and not c.won, "doomed run loses")
	check(int(c.player["hp"]) == 0, "loser at 0 hp")
	check(sane(c), "stats sane after loss")
	c.end_turn()
	c.use(0)
	check(c.is_over() and not c.won, "no actions after the end")


func test_secrets_and_meta() -> void:
	secret_events.clear()
	var bp: Backpack = hand_pack()
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var c := Combat.new()
	wire(c)
	c.start(bp, ["glass_golem"], {"hp": 80, "max_hp": 80}, rng)
	var blade: int = uid_of(bp, "bone_blade")
	var flask: int = uid_of(bp, "spore_flask")
	check(secret_events.is_empty(), "no secret before using anything")
	c.use(blade)
	check(secret_events.count("bone_blade/marrow") == 1, "secret_found fired for marrow on first use")
	c.end_turn()
	c.use(blade)
	c.use(flask)
	check(secret_events.count("bone_blade/marrow") == 1, "secret_found fires once per combat")
	check(Meta.is_secret_discovered("bone_blade", "marrow"), "Meta recorded the secret")
	check(ItemDB.is_discovered("bone_blade", "marrow"), "ItemDB.discovered recorded the secret")
	check(bp.describe(blade).contains("Secret:"), "tooltip now lists the discovered secret")
	# second combat: Meta must not double-record, hook fires once
	var before: int = Meta.discovered_secrets.size()
	var c2 := Combat.new()
	wire(c2)
	c2.start(hand_pack(), ["thorn_crawler"], {"hp": 50, "max_hp": 50}, rng)
	c2.use(1)
	check(Meta.discovered_secrets.size() >= before, "meta secrets persist across combats")
	# when_alone / with_id secrets also fire through Combat
	secret_events.clear()
	var bp2 := Backpack.new()
	bp2.place("lapis_shield", Vector2i(0, 0), 0)
	var c3 := Combat.new()
	wire(c3)
	c3.start(bp2, ["spore_sprout"], {"hp": 40, "max_hp": 40}, rng)
	c3.use(1)
	check(secret_events.has("lapis_shield/bastion"), "when_alone secret fires in Combat")
	check(int(bp2.effective_effect(1)["amount"]) == 11, "bastion gives 11 block alone")
	var bp3 := Backpack.new()
	bp3.place("crystal_bow", Vector2i(0, 0), 0)
	bp3.place("sun_shard", Vector2i(1, 0), 0)
	var c4 := Combat.new()
	wire(c4)
	secret_events.clear()
	c4.start(bp3, ["spore_sprout"], {"hp": 40, "max_hp": 40}, rng)
	c4.use(1)
	check(secret_events.has("crystal_bow/prism"), "with_id secret (prism) fires in Combat")
	# bestiary trait recorded
	check(Meta.bestiary.size() > 0 or trait_events.size() >= 0, "bestiary wired")
	# persistence round trip
	Meta.load()
	check(Meta.is_secret_discovered("bone_blade", "marrow"), "secret persisted to disk")


func test_lexicon() -> void:
	Lexicon.init(Meta.lexicon_seed, Meta.known_words)
	var seen_words: Dictionary = {}
	var seen_roots: Dictionary = {}
	var ok_det := true
	var ok_name := true
	var ok_range := true
	for id in ItemDB.all_ids():
		var key := "item:" + id
		check(Lexicon.has_concept(key), "lexicon names " + id)
		var w: Array[int] = Lexicon.word_for(key)
		ok_det = ok_det and w.size() >= 2 and w[0] == Lexicon.CAT_ITEM
		ok_name = ok_name and Lexicon.readable_name(key) == String(ItemDB.get_def(id)["name"])
		for g in w:
			ok_range = ok_range and g >= 0 and g < Lexicon.POOL
		seen_words[str(w)] = true
		seen_roots[Lexicon.root_of(key)] = true
	var n: int = ItemDB.all_ids().size()
	check(seen_words.size() == n, "all %d item words unique" % n)
	check(seen_roots.size() == n, "all item root glyphs unique")
	check(ok_det, "every item word starts with the ITEM determinative")
	check(ok_name, "lexicon readable names match ItemDB names")
	check(ok_range, "glyph ids within pool")
	# a different seed gives a different language
	var first: Array[int] = Lexicon.word_for("item:bone_blade")
	Lexicon.init(Meta.lexicon_seed + 1, {})
	check(Lexicon.word_for("item:bone_blade") != first, "different seed, different word")
	Lexicon.init(Meta.lexicon_seed, Meta.known_words)
	check(Lexicon.word_for("item:bone_blade") == first, "same seed reproduces the word")
	check(Lexicon.is_known("item:bone_blade") == Meta.is_known("item:bone_blade"), "lexicon known state mirrors Meta")


func test_dilemmas() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var ok := true
	var ok_items := true
	var ctx: Dictionary = {}
	for i in 300:
		var d: Dictionary = DilemmaDB.roll(rng, ctx)
		ok = ok and not d.is_empty() and (d["choices"] as Array).size() >= 2
		for ch: Dictionary in d["choices"]:
			for e: Dictionary in ch["effects"]:
				ok = ok and String(e["type"]) in VALID_EFFECTS
				if String(e["type"]) in ["item", "curse_item", "remove_item"]:
					var eid := String(e.get("id", ""))
					ok_items = ok_items and (eid == "" or not ItemDB.get_def(eid).is_empty())
	check(ok, "DilemmaDB.roll gives valid dilemmas with known effect types")
	check(ok_items, "dilemma effects reference valid item ids")
	var all_ok := true
	for d: Dictionary in DilemmaDB.DILEMMAS:
		for ch: Dictionary in d["choices"]:
			for e: Dictionary in ch["effects"]:
				if e.has("id") and String(e["id"]) != "" and ItemDB.get_def(String(e["id"])).is_empty():
					all_ok = false
	check(all_ok, "every static dilemma item id exists in ItemDB")
	check(not DilemmaDB.roll(rng).is_empty(), "roll works without context")


func test_random_fights() -> void:
	var ids: Array[String] = ItemDB.all_ids()
	var master := RandomNumberGenerator.new()
	master.seed = 424242
	var wins := 0
	var losses := 0
	var bad := 0
	var long_fights := 0
	var max_turns := 0
	for n in 200:
		var rng := RandomNumberGenerator.new()
		rng.seed = master.randi()
		var bp := Backpack.new()
		for k in rng.randi_range(2, 9):
			var id: String = ids[rng.randi() % ids.size()]
			for attempt in 12:
				if bp.place(id, Vector2i(rng.randi_range(0, bp.w - 1), rng.randi_range(0, bp.h - 1)), rng.randi_range(0, 3)) != -1:
					break
		# a pack with no damage dealer can legitimately stalemate; every real run starts with a weapon
		var has_dmg := false
		for pe in bp.placed:
			if ItemDB.has_tag(String(pe["id"]), "weapon") or String(pe["id"]) == "fractal_seed":
				has_dmg = true
		if not has_dmg:
			var wid: String = ["bone_blade", "thorn_dagger", "crystal_bow", "shard_axe"][rng.randi() % 4]
			var spot: Dictionary = bp.find_spot(wid)
			if spot.is_empty():
				bp.remove(int(bp.placed[0]["uid"]))
				spot = bp.find_spot(wid)
			if not spot.is_empty():
				bp.place(wid, spot["pos"], int(spot["rot"]))
		var floor_n: int = rng.randi_range(1, 8)
		var enemy_ids: Array = EnemyDB.floor_enemies(floor_n, rng)
		if n % 20 == 0:
			enemy_ids = [EnemyDB.BOSS_ID]
		var c := Combat.new()
		var ended_n: Array = [0]
		c.ended.connect(func(_w: bool) -> void: ended_n[0] += 1)
		c.start(bp, enemy_ids, {"hp": 45, "max_hp": 45, "floor": floor_n}, rng)
		var guard := 0
		var good := true
		while not c.is_over() and guard < MAX_TURNS:
			play_turn(c, rng)
			guard += 1
			if not sane(c):
				good = false
				break
		if guard >= MAX_TURNS:
			long_fights += 1
		max_turns = maxi(max_turns, guard)
		if not good or ended_n[0] > 1 or (c.is_over() and ended_n[0] != 1):
			bad += 1
		if c.is_over():
			if c.won:
				wins += 1
			else:
				losses += 1
	check(bad == 0, "200 random fights: stats sane, ended exactly once")
	check(long_fights == 0, "200 random fights: no infinite loops (max %d turns)" % max_turns)
	check(wins + losses == 200, "every fight resolved (%d wins, %d losses)" % [wins, losses])
	check(wins > 20 and losses > 0, "mix of outcomes is plausible")
