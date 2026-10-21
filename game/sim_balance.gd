extends SceneTree
## Balance simulation: godot --headless --path . -s game/sim_balance.gd [-- runs_per_combo]
## A greedy bot plays seeded runs with the REAL ItemDB / Backpack / Combat / EnemyDB / RouteMap / DilemmaDB logic
## (Run's economy and effect rules are mirrored here, minus UI). Prints win rate / depth per hero and origin,
## damage per fight type, turns per fight, and per-item offer/pick/win lift.

const HEROES := ["seshat", "thoth"]
const ORIGINS := ["eclipse", "mirror", "cathedral"]
const MAX_TURNS := 40
const MAX_W := 7
const MAX_H := 6
# Mirrors Run.HEROES / Run.ORIGINS / Run.make_pack (kept local so the sim compiles without the UI chain; keep in sync).
const HERO_DEFS := {
	"seshat": {"hp": 40, "items": ["bone_blade", "whetstone", "reed_buckler", "moss_charm", "spore_flask"], "adjacency_bonus": 1},
	"thoth": {"hp": 36, "items": ["glyph_lens", "crystal_bow", "quiver", "lapis_shield", "fractal_seed"], "adjacency_bonus": 0},
}
const ORIGIN_DEFS := {
	"eclipse": {"w": 4, "h": 4, "item": "sun_shard", "gold": 0},
	"mirror": {"w": 5, "h": 4, "item": "@weapon", "gold": 10},
	"cathedral": {"w": 6, "h": 4, "item": "healing_bloom", "gold": 25},
}

var rng := RandomNumberGenerator.new()
var runs_per := 400

# per-run state
var hp := 0
var max_hp := 0
var gold := 0
var depth := 0
var bp: Backpack
var hero := "seshat"
var cursed := 0
var used_ids: Dictionary = {}
var thoth_words := 0

# stats
var combo: Dictionary = {}       # "hero/origin" -> {runs, wins, depth_sum}
var fight_stat: Dictionary = {}  # type -> {n, dmg, turns, losses}
var item_offered: Dictionary = {}
var item_picked: Dictionary = {}   # id -> {runs, wins}
var item_uses: Dictionary = {}     # id -> total uses
var pending: Array = []
var all_runs := 0
var all_wins := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and String(args[0]).is_valid_int():
		runs_per = int(args[0])
	Lexicon.init(7)
	var t0 := Time.get_ticks_msec()
	for h in HEROES:
		for o in ORIGINS:
			for i in runs_per:
				_play(h, o, 1000 + i)
	_report()
	print("elapsed %.1fs" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit(0)


func _make_pack(p_hero: String, p_origin: String) -> Backpack:
	var hd: Dictionary = HERO_DEFS[p_hero]
	var od: Dictionary = ORIGIN_DEFS[p_origin]
	var pack := Backpack.new()
	pack.w = int(od["w"])
	pack.h = int(od["h"])
	pack.adjacency_bonus = int(hd.get("adjacency_bonus", 0))
	var ids: Array = (hd["items"] as Array).duplicate()
	var extra: String = String(od["item"])
	if extra == "@weapon":
		extra = "bone_blade"
		for id in ids:
			if ItemDB.has_tag(String(id), "weapon"):
				extra = String(id)
				break
	ids.append(extra)
	for id in ids:
		var spot: Dictionary = pack.find_spot(String(id))
		var tries := 0
		while spot.is_empty() and tries < 4:
			if pack.w <= pack.h:
				pack.w += 1
			else:
				pack.h += 1
			spot = pack.find_spot(String(id))
			tries += 1
		if not spot.is_empty():
			pack.place(String(id), spot["pos"], int(spot["rot"]))
	return pack


# ------------------------------------------------------------------ one run
func _play(h: String, o: String, seed_v: int) -> void:
	hero = h
	rng.seed = hash("%s:%s:%d" % [h, o, seed_v])
	max_hp = int((HERO_DEFS[h] as Dictionary)["hp"])
	hp = max_hp
	gold = int((ORIGIN_DEFS[o] as Dictionary)["gold"])
	depth = 0
	cursed = 0
	thoth_words = 0
	used_ids.clear()
	bp = _make_pack(h, o)
	var map := RouteMap.new()
	map.generate(rng.randi(), o, h)
	var won := false
	var alive := true
	var picked: Dictionary = {}
	var guard := 0
	while alive and guard < 60:
		guard += 1
		var opts: Array = map.reachable_ids()
		if opts.is_empty():
			break
		var cid: int = _choose_node(map, opts)
		map.choose(cid)
		var node: Dictionary = map.nodes[cid]
		var d: int = int(node["depth"])
		depth = maxi(depth, d + 1)
		var t: String = String(node["type"])
		if t == "mystery":
			t = String(node.get("resolved", "fight"))
		var floor_n: int = 1 + (d * 2) / 3
		match t:
			"fight":
				alive = _fight(EnemyDB.floor_enemies(floor_n, rng), floor_n, "fight", picked)
				if alive:
					gold += rng.randi_range(5, 10) + floor_n * 2
					_loot(ItemDB.roll_loot(rng, 3, 0.0), picked)
			"elite":
				alive = _fight(EnemyDB.floor_enemies(floor_n + 2, rng), floor_n + 1, "elite", picked)
				if alive:
					gold += rng.randi_range(5, 10) + (floor_n + 1) * 2 + 10
					_loot(ItemDB.roll_loot(rng, 3, 0.8), picked)
			"boss":
				alive = _fight([EnemyDB.BOSS_ID], floor_n + 2, "boss", picked)
				won = alive
				break
			"treasure":
				gold += rng.randi_range(8, 16) + floor_n * 2
				_loot(ItemDB.roll_loot(rng, 3, 0.6), picked)
			"shop":
				_shop(picked)
			"rest":
				if hp < max_hp * 0.8:
					hp = mini(max_hp, hp + ceili(max_hp * 0.3))
			"shrine":
				_learn()
			"dilemma":
				_dilemma(picked)
	map.free()
	var key := "%s/%s" % [h, o]
	var c: Dictionary = combo.get(key, {"runs": 0, "wins": 0, "depth": 0})
	c["runs"] += 1
	c["wins"] += 1 if won else 0
	c["depth"] += depth
	combo[key] = c
	all_runs += 1
	all_wins += 1 if won else 0
	pending.append({"key": key, "won": won, "items": picked.keys()})


func _choose_node(map: RouteMap, opts: Array) -> int:
	var best := -1
	var best_s := -1e9
	for id in opts:
		var n: Dictionary = map.nodes[int(id)]
		var t: String = String(n["type"])
		var s := rng.randf() * 0.5
		var ratio := float(hp) / float(max_hp)
		match t:
			"rest": s += 3.0 if ratio < 0.65 else 0.2
			"shop": s += 2.5 if gold >= 30 else 0.3
			"treasure": s += 2.0
			"shrine": s += 0.8
			"mystery": s += 1.2
			"fight": s += 1.0
			"elite": s += 1.6 if ratio > 0.7 else -2.0
			"boss": s += 5.0
		if s > best_s:
			best_s = s
			best = int(id)
	return best


# ------------------------------------------------------------------ fights
func _fight(ids: Array, floor_n: int, ftype: String, picked: Dictionary) -> bool:
	var c := Combat.new()
	var taken := [0]
	c.damage_dealt.connect(func(target: String, amount: int, _i: int) -> void:
		if target == "player":
			taken[0] += amount)
	c.start(bp, ids, {"hp": hp, "max_hp": max_hp, "floor": floor_n}, rng)
	var turns := 0
	while not c.is_over() and turns < MAX_TURNS:
		turns += 1
		var safety := 0
		while safety < 20:
			safety += 1
			var uid := _best_use(c)
			if uid < 0:
				break
			var id: String = bp.id_of(uid)
			item_uses[id] = int(item_uses.get(id, 0)) + 1
			if not used_ids.has(id):
				used_ids[id] = true
				_learn()
			c.use(uid, _target(c))
			if c.is_over():
				break
		if c.is_over():
			break
		c.end_turn()
	hp = clampi(int(c.player["hp"]), 0, max_hp)
	var victory: bool = c.won and hp > 0
	var s: Dictionary = fight_stat.get(ftype, {"n": 0, "dmg": 0, "turns": 0, "losses": 0})
	s["n"] += 1
	s["dmg"] += taken[0]
	s["turns"] += turns
	s["losses"] += 0 if victory else 1
	fight_stat[ftype] = s
	return victory


func _target(c: Combat) -> int:
	var best := 0
	var bh := 1 << 30
	for i in c.enemies.size():
		var e: Dictionary = c.enemies[i]
		if bool(e["alive"]) and int(e["hp"]) + int(e["block"]) < bh:
			bh = int(e["hp"]) + int(e["block"])
			best = i
	return best


func _incoming(c: Combat) -> int:
	var n := 0
	for e in c.enemies:
		if bool(e["alive"]) and not bool(e["stunned"]) and String(e["intent"].get("type", "")) == "attack":
			n += int(e["intent"]["amount"]) * int(e["intent"].get("hits", 1))
	return n


func _best_use(c: Combat) -> int:
	var inc := _incoming(c)
	var best := -1
	var best_r := 0.0
	var missing: int = int(c.player["max_hp"]) - int(c.player["hp"])
	var pending_cost := 0
	var energy_uids: Array[int] = []
	var foe_hp := 0
	for e in c.enemies:
		if bool(e["alive"]):
			foe_hp += int(e["hp"])
	for uid in bp.uids():
		var def: Dictionary = ItemDB.get_def(bp.id_of(uid))
		if String(def.get("kind", "")) != "active" or uid in c.used:
			continue
		if String(def["effect"]["type"]) == "energy":
			energy_uids.append(uid)
		elif int(def.get("cost", 0)) > 0:
			pending_cost += int(def["cost"])
	for uid in bp.uids():
		if not c.can_use(uid):
			continue
		var def: Dictionary = ItemDB.get_def(bp.id_of(uid))
		var eff: Dictionary = bp.effective_effect(uid)
		var amt: int = int(eff.get("amount", 0))
		var v := 0.0
		match String(eff.get("type", "")):
			"damage": v = amt
			"multi_damage": v = amt * int(eff.get("hits", 1)) * 0.9
			"damage_per_adjacent": v = amt * bp.neighbors(uid).size()
			"block": v = minf(amt, maxf(0.0, inc - int(c.player["block"]))) * 1.1
			"heal":
				v = minf(amt, missing) * (1.5 if float(c.player["hp"]) < 0.5 * float(c.player["max_hp"]) else 1.1)
				if bool(def.get("consumable", false)) and missing < amt * 0.6:
					v = 0.0
			"energy":
				var en: int = int(c.player["energy"])
				v = 50.0 if pending_cost > en else 0.0
		if v <= 0.0:
			continue
		var r: float = v / maxf(float(def.get("cost", 0)), 0.4)
		if r > best_r:
			best_r = r
			best = uid
	return best


# ------------------------------------------------------------------ economy / dilemmas
func _learn() -> void:
	if hero == "thoth" and thoth_words < 8:   # Thoth: each new glyph word is a small blessing
		thoth_words += 1
		max_hp += 1
		hp = mini(max_hp, hp + 2)


func _score_item(id: String) -> float:
	var def: Dictionary = ItemDB.get_def(id)
	var s: float = float(def.get("rarity", 1)) * 0.8 + rng.randf() * 2.5
	match String(def["effect"]["type"]):
		"damage", "multi_damage", "damage_per_adjacent": s += 3.0
		"block": s += 2.2
		"heal": s += 1.6
		"energy": s += 1.2
		_: s += 1.0
	return s


func _loot(ids: Array, picked: Dictionary) -> void:
	var best := ""
	var bs := -1.0
	for id in ids:
		item_offered[id] = int(item_offered.get(id, 0)) + 1
		if bp.find_spot(String(id)).is_empty():
			continue
		var s := _score_item(String(id))
		if s > bs:
			bs = s
			best = String(id)
	if best == "":
		gold += 6 + 4 * int(ItemDB.get_def(String(ids[0])).get("rarity", 1)) if not ids.is_empty() else 0
		return
	_add(best, picked)


func _add(id: String, picked: Dictionary) -> bool:
	var spot: Dictionary = bp.find_spot(id)
	if spot.is_empty():
		return false
	bp.place(id, spot["pos"], int(spot["rot"]))
	if depth <= 5:   # only early picks count toward lift, to limit survivor bias (long runs acquire more items)	if depth <= 5:   # only early picks count toward lift, to limit survivor bias (long runs acquire more items)
		picked[id] = true
	return true


func _shop(picked: Dictionary) -> void:
	var stock: Array = ItemDB.roll_loot(rng, 3, 0.3)
	var sc: Dictionary = {}
	for id in stock:
		sc[id] = _score_item(String(id))
	stock.sort_custom(func(a, b) -> bool: return sc[a] > sc[b])
	for id in stock:
		var price: int = 16 + 14 * int(ItemDB.get_def(String(id)).get("rarity", 1))
		if gold >= price and not bp.find_spot(String(id)).is_empty():
			gold -= price
			_add(String(id), picked)


func _dilemma(picked: Dictionary) -> void:
	var d: Dictionary = DilemmaDB.roll(rng, {"hp": hp, "max_hp": max_hp, "gold": gold, "depth": depth})
	if d.is_empty():
		return
	var best: Array = []
	var bs := -1e9
	for ch in d["choices"]:
		var s := 0.0
		for e in ch["effects"]:
			var a: int = int(e.get("amount", 0))
			match String(e["type"]):
				"hp": s += a * (1.5 if hp < max_hp * 0.5 else 0.8)
				"max_hp": s += a * 1.3
				"heal_all": s += (max_hp - hp) * 1.0
				"gold": s += a * 0.12
				"item": s += 6.0
				"curse_item": s -= 5.0
				"remove_item": s -= 6.0
				"shrink_pack": s -= 4.0 * maxi(1, a)
				"grow_pack": s += 4.0 * maxi(1, a)
				"reveal_glyph": s += 0.8
		s += rng.randf() * 2.0
		if s > bs:
			bs = s
			best = ch["effects"]
	for e in best:
		var a: int = int(e.get("amount", 0))
		match String(e["type"]):
			"max_hp":
				max_hp = maxi(5, max_hp + a)
				if a > 0:
					hp += a
				hp = clampi(hp, 1, max_hp)
			"hp": hp = clampi(hp + a, 1, max_hp)
			"heal_all": hp = max_hp
			"gold": gold = maxi(0, gold + a)
			"item":
				var id := String(e.get("id", ""))
				if id == "" or ItemDB.get_def(id).is_empty():
					var r: Array[String] = ItemDB.roll_loot(rng, 1, 0.5)
					id = r[0] if not r.is_empty() else "bone_blade"
				_add(id, picked)
			"curse_item":
				max_hp = maxi(5, max_hp - 3)
				hp = clampi(hp, 1, max_hp)
			"remove_item":
				var us: Array[int] = bp.uids()
				if us.size() > 1:
					bp.remove(us[rng.randi() % us.size()])
			"shrink_pack":
				if bp.w * bp.h > 9 and bp.resize(bp.w - 1, bp.h):
					pass
				elif bp.h > 3:
					bp.resize(bp.w, bp.h - 1)
			"grow_pack":
				if bp.w <= bp.h and bp.w < MAX_W:
					bp.resize(bp.w + 1, bp.h)
				elif bp.h < MAX_H:
					bp.resize(bp.w, bp.h + 1)
			"reveal_glyph": _learn()


# ------------------------------------------------------------------ report
func _pct(a: float, b: float) -> String:
	return "%5.1f%%" % (100.0 * a / maxf(b, 1.0))


func _report() -> void:
	print("== BALANCE  runs/combo=%d  total=%d  overall win %s ==" % [runs_per, all_runs, _pct(all_wins, all_runs)])
	var by_hero: Dictionary = {}
	var by_origin: Dictionary = {}
	for k in combo:
		var parts: PackedStringArray = String(k).split("/")
		for pair in [[by_hero, parts[0]], [by_origin, parts[1]]]:
			var m: Dictionary = pair[0]
			var s: Dictionary = m.get(pair[1], {"runs": 0, "wins": 0, "depth": 0})
			s["runs"] += combo[k]["runs"]
			s["wins"] += combo[k]["wins"]
			s["depth"] += combo[k]["depth"]
			m[pair[1]] = s
	for title in [["hero", by_hero], ["origin", by_origin], ["hero/origin", combo]]:
		for k in (title[1] as Dictionary):
			var s: Dictionary = title[1][k]
			print("%-12s %-18s win %s  avg depth %.2f" % [title[0], k, _pct(s["wins"], s["runs"]), float(s["depth"]) / float(s["runs"])])
	for t in fight_stat:
		var s: Dictionary = fight_stat[t]
		print("fight %-6s n=%6d  avg dmg taken %5.1f  avg turns %4.1f  loss rate %s" % [t, s["n"], float(s["dmg"]) / s["n"], float(s["turns"]) / s["n"], _pct(s["losses"], s["n"])])
	var base: float = float(all_wins) / maxf(all_runs, 1)
	# lift = wins / expected wins, where expected uses the hero/origin win rate of each run that acquired the item
	var agg: Dictionary = {}
	for r in pending:
		var cb: Dictionary = combo[r["key"]]
		var exp_rate: float = float(cb["wins"]) / float(cb["runs"])
		for id in r["items"]:
			var a: Dictionary = agg.get(id, {"runs": 0, "wins": 0, "exp": 0.0})
			a["runs"] += 1
			a["wins"] += 1 if r["won"] else 0
			a["exp"] += exp_rate
			agg[id] = a
	var rows: Array = []
	for id in ItemDB.all_ids():
		var p: Dictionary = agg.get(id, {"runs": 0, "wins": 0, "exp": 0.0})
		var off: int = int(item_offered.get(id, 0))
		var lift: float = float(p["wins"]) / maxf(float(p["exp"]), 0.01) if p["runs"] > 0 else 0.0
		rows.append({"id": id, "off": off, "runs": p["runs"], "lift": lift, "uses": item_uses.get(id, 0)})
	rows.sort_custom(func(a, b) -> bool: return a["lift"] > b["lift"])
	var lifts: Array = []
	for r in rows:
		if r["runs"] >= 50:
			lifts.append(r["lift"])
	lifts.sort()
	var med: float = lifts[lifts.size() / 2] if not lifts.is_empty() else 1.0
	print("item lift (acquired items; wins / expected-by-hero-origin); median %.2f" % med)
	for r in rows:
		print("  %-15s acquired-in %5d runs  offered %5d  uses %6d  lift %.2f  (x%.2f of median)" % [r["id"], r["runs"], r["off"], r["uses"], r["lift"], r["lift"] / med])
