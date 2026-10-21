extends SceneTree
## godot --headless --path . -s game/test_combat_enemies.gd

class FakeBackpack extends RefCounted:
	var placed: Array[Dictionary] = []
	var links: Dictionary = {}  # uid -> Array[int]
	func add(uid: int, id: String, adj: Array) -> void:
		placed.append({"uid": uid, "id": id, "pos": Vector2i.ZERO, "rot": 0})
		var typed: Array[int] = []
		for a in adj:
			typed.append(int(a))
		links[uid] = typed
	func entry(uid: int) -> Dictionary:
		for p in placed:
			if p["uid"] == uid:
				return p
		return {}
	func neighbors(uid: int) -> Array[int]:
		return links.get(uid, [] as Array[int])
	func effective_effect(uid: int) -> Dictionary:
		var e: Dictionary = FAKE_DEFS[String(entry(uid)["id"])]["effect"].duplicate()
		if String(entry(uid)["id"]) == "blade":
			e["amount"] = int(e["amount"]) + 3 * neighbors(uid).size()
		return e

const FAKE_DEFS := {
	"blade": {"id": "blade", "name": "Blade", "kind": "active", "cost": 1, "consumable": false, "tags": ["weapon"],
		"effect": {"type": "damage", "amount": 6},
		"secrets": [{"id": "whet", "with_tag": "stone", "bonus": {"amount": 3}}]},
	"stone": {"id": "stone", "name": "Stone", "kind": "passive", "cost": 0, "tags": ["stone"], "effect": {"type": "none", "amount": 0}},
	"dagger": {"id": "dagger", "name": "Dagger", "kind": "active", "cost": 1, "consumable": false, "tags": [],
		"effect": {"type": "multi_damage", "amount": 3, "hits": 2}},
	"shield": {"id": "shield", "name": "Shield", "kind": "active", "cost": 1, "consumable": false, "tags": [],
		"effect": {"type": "block", "amount": 7}},
	"flask": {"id": "flask", "name": "Flask", "kind": "active", "cost": 0, "consumable": true, "tags": [],
		"effect": {"type": "heal", "amount": 5}},
	"sun": {"id": "sun", "name": "Sun", "kind": "active", "cost": 0, "consumable": true, "tags": [],
		"effect": {"type": "energy", "amount": 2}},
	"charm": {"id": "charm", "name": "Charm", "kind": "passive", "cost": 0, "tags": [],
		"effect": {"type": "turn_start_block_per_adjacent", "amount": 1}},
	"seed": {"id": "seed", "name": "Seed", "kind": "active", "cost": 2, "consumable": false, "tags": [],
		"effect": {"type": "damage_per_adjacent", "amount": 3}},
	"mega": {"id": "mega", "name": "Mega", "kind": "active", "cost": 0, "consumable": false, "tags": [],
		"effect": {"type": "damage", "amount": 999}},
}

var fails := 0
var secrets: Array = []
var traits: Array = []
var ended_log: Array = []


func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS ", label)
	else:
		print("FAIL ", label)
		fails += 1


func fake_def(id: String) -> Dictionary:
	return FAKE_DEFS.get(id, {})


func make(bp: FakeBackpack, enemy_ids: Array, state := {}) -> Combat:
	var c := Combat.new()
	c.def_provider = Callable(self, "fake_def")
	c.secret_found.connect(func(i: String, s: String) -> void: secrets.append([i, s]))
	c.enemy_trait_revealed.connect(func(i: String, t: String) -> void: traits.append([i, t]))
	c.ended.connect(func(w: bool) -> void: ended_log.append(w))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var st := {"hp": 40, "max_hp": 40}
	st.merge(state, true)
	c.start(bp, enemy_ids, st, rng)
	return c


func _init() -> void:
	test_enemydb()
	test_basic_use()
	test_effects()
	test_turn_cycle_and_enemy()
	test_split_and_traits()
	test_boss()
	test_win_lose()
	print("RESULT ", "FAIL (%d)" % fails if fails > 0 else "ALL PASS")
	quit(1 if fails > 0 else 0)


func test_enemydb() -> void:
	for id in ["spore_sprout", "thorn_crawler", "crystal_moth", "glass_golem", "cascade_warden"]:
		var d := EnemyDB.get_def(id)
		check(not d.is_empty() and d["art"] == id and d["max_hp"] > 0 and d["lore"] != "", "enemydb " + id)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for f in [1, 3, 5, 8]:
		var ids := EnemyDB.floor_enemies(f, rng)
		check(ids.size() >= 1 and ids.size() <= 4 and not (EnemyDB.BOSS_ID in ids), "floor_enemies %d" % f)
	check(EnemyDB.phase_for("cascade_warden", 1.0) == 0 and EnemyDB.phase_for("cascade_warden", 0.5) == 1 \
		and EnemyDB.phase_for("cascade_warden", 0.2) == 2, "boss phases")


func test_basic_use() -> void:
	var bp := FakeBackpack.new()
	bp.add(1, "blade", [2])
	bp.add(2, "stone", [1])
	var c := make(bp, ["thorn_crawler"])
	check(c.player["energy"] == 3 and c.turn == 1, "start energy/turn")
	secrets.clear()
	var hp0: int = c.enemies[0]["hp"]
	check(c.can_use(1), "can_use blade")
	c.use(1, 0)
	check(c.enemies[0]["hp"] == hp0 - 9, "blade 6+3 adjacency")
	check(c.player["energy"] == 2, "energy spent")
	check(not c.can_use(1), "once per turn")
	check(secrets == [["blade", "whet"]], "secret_found emitted once")
	check(not c.can_use(2), "passive not usable")
	check(c.player["hp"] == 39, "thorns reflected 1")
	check(["thorn_crawler", "thorns"] in traits, "thorns trait revealed")


func test_effects() -> void:
	var bp := FakeBackpack.new()
	bp.add(1, "dagger", [])
	bp.add(2, "shield", [])
	bp.add(3, "flask", [])
	bp.add(4, "sun", [])
	bp.add(5, "seed", [6, 7, 8])
	bp.add(6, "stone", [5])
	bp.add(7, "stone", [5])
	bp.add(8, "stone", [5])
	var c := make(bp, ["glass_golem"], {"hp": 20})
	var hp0: int = c.enemies[0]["hp"]
	c.use(1)
	check(c.enemies[0]["hp"] == hp0 - 6, "multi_damage 3x2")
	c.use(2)
	check(c.player["block"] == 7, "block")
	c.use(3)
	check(c.player["hp"] == 25, "consumable heal")
	check(not c.can_use(3), "consumable once")
	c.use(4)
	check(c.player["energy"] == 3 - 1 - 1 + 2, "energy gain")
	c.use(5)
	check(c.enemies[0]["hp"] == hp0 - 6 - 9, "damage_per_adjacent 3x3")
	c.end_turn()
	check(not c.can_use(3), "consumable stays used next turn")
	check(c.used.is_empty(), "used cleared")


func test_turn_cycle_and_enemy() -> void:
	var bp := FakeBackpack.new()
	bp.add(1, "shield", [2, 3])
	bp.add(2, "charm", [1])
	bp.add(3, "stone", [1])
	var c := make(bp, ["thorn_crawler"])
	check(c.player["block"] == 1, "passive block at start (1 adjacent)")
	var intent: Dictionary = c.enemies[0]["intent"]
	check(intent["type"] == "attack" and intent["amount"] == 6, "intent shown")
	c.end_turn()
	check(c.turn == 2 and c.player["hp"] == 40 - 5, "enemy attack minus block")
	check(c.player["block"] == 1 and c.player["energy"] == 3, "block reset, energy refilled")
	check(c.enemies[0]["intent"]["type"] == "block", "intent cycles")
	c.end_turn()
	check(c.enemies[0]["block"] == 5, "enemy block set")
	c.use(1)  # nothing to break it with except shield; use dagger-less hit via mega below
	var bp2 := FakeBackpack.new()
	bp2.add(1, "dagger", [])
	var g := make(bp2, ["glass_golem"])
	g.end_turn()  # golem blocks 9
	check(g.enemies[0]["block"] == 9, "golem block")
	bp2.add(2, "mega", [])
	g.use(2)  # 999 breaks block completely
	check(g.is_over() and g.won, "mega kills golem")


func test_split_and_traits() -> void:
	var bp := FakeBackpack.new()
	bp.add(1, "dagger", [])
	var c := make(bp, ["spore_sprout"], {"floor": 1})
	c.enemies[0]["hp"] = 11
	c.use(1)  # 6 dmg: 5/18 < half
	check(c.enemies.size() == 2, "sprout split")
	check(c.enemies[1]["alive"] and c.enemies[1]["scale"] < c.enemies[0]["scale"], "smaller copy")
	check(["spore_sprout", "splits"] in traits, "splits revealed")
	check(c.enemies[1]["split_done"], "copy does not split again")
	# moth siphon
	var m := make(bp, ["crystal_moth"])
	m.end_turn()
	check(["crystal_moth", "siphon"] in traits, "siphon revealed")
	# golem stun when block broken
	var g := make(bp, ["glass_golem"])
	g.end_turn()
	check(g.enemies[0]["block"] == 9, "golem armoured")
	g.enemies[0]["block"] = 2
	g.use(1)  # 3 dmg breaks the 2 block
	check(g.enemies[0]["stunned"] and ["glass_golem", "brittle"] in traits, "brittle stun")
	var hp: int = g.player["hp"]
	g.end_turn()
	check(g.player["hp"] == hp, "stunned golem skips")


func test_boss() -> void:
	var bp := FakeBackpack.new()
	bp.add(1, "dagger", [])
	var c := make(bp, ["cascade_warden"])
	check(c.enemies[0]["max_hp"] == 60, "boss hp 60")
	c.enemies[0]["hp"] = 35
	c.use(1)  # 29 -> phase 1 (<0.66)
	check(c.enemies[0]["phase"] == 1 and c.enemies[0]["intent"]["hits"] == 3, "boss phase 2 intent")
	c.enemies[0]["hp"] = 12
	bp.add(2, "dagger", [])
	c.end_turn()
	c.use(2)
	check(c.enemies[0]["phase"] == 2, "boss phase 3")
	# step through a phase-2 cycle to the summon
	var d := make(bp, ["cascade_warden"])
	d.enemies[0]["hp"] = 30
	d.use(1)
	d.end_turn()  # attack x3
	d.end_turn()  # split
	check(d.enemies.size() >= 2 and ["cascade_warden", "summons"] in traits, "boss summons")
	check(["cascade_warden", "cascade"] in traits and d.enemies[0]["bonus"] >= 1, "cascade growth")


func test_win_lose() -> void:
	var bp := FakeBackpack.new()
	bp.add(1, "mega", [])
	ended_log.clear()
	var c := make(bp, ["spore_sprout", "thorn_crawler"])
	c.use(1, 0)
	check(not c.is_over(), "one left")
	c.use(1, 5)  # invalid target retargets; mega already used -> no-op
	bp.add(2, "mega", [])
	c.use(2, 9)
	check(c.is_over() and c.won and ended_log == [true], "win via retarget")
	c.end_turn()
	check(ended_log == [true], "no double end")
	var weak := FakeBackpack.new()
	var l := make(weak, ["glass_golem", "glass_golem", "glass_golem"], {"hp": 5})
	l.end_turn()
	l.end_turn()
	l.end_turn()
	check(l.is_over() and not l.won and ended_log[-1] == false, "lose")
