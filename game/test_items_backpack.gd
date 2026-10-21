extends SceneTree

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS ", label)
	else:
		print("FAIL ", label)
		fails += 1

func _init() -> void:
	test_definitions()
	test_rotation()
	test_placement()
	test_adjacency()
	test_synergies()
	test_secrets()
	test_serialisation()
	test_loot()
	print("RESULT ", "ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(0 if fails == 0 else 1)

func test_definitions() -> void:
	var required := ["bone_blade", "shard_axe", "thorn_dagger", "crystal_bow", "lapis_shield", "reed_buckler",
		"whetstone", "quiver", "spore_flask", "healing_bloom", "sun_shard", "moss_charm", "fractal_seed", "glyph_lens"]
	var ok := true
	for id in required:
		var d := ItemDB.get_def(id)
		if d.is_empty() or d.id != id or d.shape.is_empty() or d.glyphs.size() < 3 or d.glyphs.size() > 5:
			ok = false
		for g in d.glyphs:
			if int(g) < 0 or int(g) > 13:
				ok = false
	check(ok, "14 required items well formed")
	var with_secrets := 0
	for id in ItemDB.all_ids():
		if not ItemDB.secrets_of(id).is_empty():
			with_secrets += 1
	check(with_secrets >= 5, "at least 5 items have secrets (%d)" % with_secrets)

func test_rotation() -> void:
	var ok := true
	for id in ItemDB.all_ids():
		var base := ItemDB.shape_rotated(id, 0)
		for r in 4:
			var cells := ItemDB.shape_rotated(id, r)
			var mx := 99
			var my := 99
			for c in cells:
				mx = mini(mx, c.x)
				my = mini(my, c.y)
			if cells.size() != base.size() or mx != 0 or my != 0:
				ok = false
		if ItemDB.shape_rotated(id, 4) != base:
			ok = false
		if ItemDB.shape_rotated(ItemDB.shape_rotated(id, 1), 1) != ItemDB.shape_rotated(id, 2):
			ok = false
	check(ok, "every shape: normalised, size kept, rot4 == rot0, composes")
	check(ItemDB.shape_size("bone_blade", 0) == Vector2i(1, 3), "blade vertical 1x3")
	check(ItemDB.shape_size("bone_blade", 1) == Vector2i(3, 1), "blade rot1 horizontal 3x1")
	var axe1 := ItemDB.shape_rotated("shard_axe", 1)
	var want: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]
	check(axe1 == want, "L-tromino rot1 exact cells %s" % str(axe1))
	var t1 := ItemDB.shape_rotated("fractal_seed", 1)
	check(t1.has(Vector2i(0, 1)) and ItemDB.shape_size("fractal_seed", 1) == Vector2i(2, 3), "T rot1 is 2x3")

func test_placement() -> void:
	var bp := Backpack.new()
	var u := bp.place("lapis_shield", Vector2i(0, 0), 0)
	check(u != -1, "place 2x2")
	check(bp.place("whetstone", Vector2i(1, 1), 0) == -1, "overlap rejected")
	check(bp.place("bone_blade", Vector2i(4, 2), 0) == -1, "bottom bound (3 tall at y=2, h=4)")
	check(bp.place("bone_blade", Vector2i(5, 0), 0) == -1, "right bound")
	check(bp.place("bone_blade", Vector2i(-1, 0), 0) == -1, "negative bound")
	check(bp.place("bone_blade", Vector2i(2, 0), 1) != -1, "rotated blade horizontal fits at x=2")
	check(bp.place("bone_blade", Vector2i(3, 0), 1) == -1, "rotated blade overflows right")
	check(bp.can_place("lapis_shield", Vector2i(1, 1), 0, u), "ignore_uid allows moving over self")
	check(bp.uid_at(Vector2i(1, 1)) == u and bp.uid_at(Vector2i(4, 3)) == -1, "uid_at")
	check(bp.cells_of(u).size() == 4, "cells_of")
	check(bp.remove(u).id == "lapis_shield" and bp.uid_at(Vector2i(0, 0)) == -1, "remove frees cells")
	check(bp.remove(999).is_empty(), "remove unknown -> {}")
	check(bp.place("nonsense", Vector2i(0, 0), 0) == -1, "unknown id rejected")
	# find_spot: fill with 1x1s until the only gap is a single column cell
	var full := Backpack.new()
	full.w = 2
	full.h = 3
	check(full.find_spot("bone_blade") == {"pos": Vector2i(0, 0), "rot": 0}, "find_spot first fit")
	full.place("whetstone", Vector2i(0, 0), 0)
	var s := full.find_spot("bone_blade")
	check(s == {"pos": Vector2i(1, 0), "rot": 0}, "find_spot skips occupied: %s" % str(s))
	full.place("quiver", Vector2i(1, 1), 0)
	check(full.find_spot("bone_blade").is_empty(), "find_spot {} when nothing fits")
	check(not full.find_spot("moss_charm").is_empty(), "find_spot 1x1 still fits")
	var fs := Backpack.new()
	fs.w = 3
	fs.h = 1
	check(fs.find_spot("bone_blade").get("rot", -1) == 1, "find_spot rotates to fit")
	var rs := Backpack.new()
	var ru := rs.place("bone_blade", Vector2i(0, 0), 0)
	check(not rs.resize(5, 2) and rs.resize(5, 3), "resize refuses to cut items")
	check(rs.move(ru, Vector2i(1, 0), 0) and not rs.move(ru, Vector2i(5, 0), 0), "move")

func test_adjacency() -> void:
	var bp := Backpack.new()
	var a := bp.place("bone_blade", Vector2i(0, 0), 0)  # x0, y0..2
	var b := bp.place("whetstone", Vector2i(1, 1), 0)   # edge-adjacent
	var c := bp.place("quiver", Vector2i(1, 3), 0)      # diagonal to blade bottom (0,2)
	var d := bp.place("moss_charm", Vector2i(3, 0), 0)  # far
	check(bp.neighbors(a) == [b], "edge neighbour only, diagonal excluded: %s" % str(bp.neighbors(a)))
	check(bp.neighbors(b) == [a], "symmetric")
	check(bp.neighbors(c).is_empty() and bp.neighbors(d).is_empty(), "isolated items have none")
	var e := bp.place("quiver", Vector2i(0, 3), 0)
	check(bp.neighbors(a) == [b, e] and bp.neighbors(c) == [e], "multi-cell touch counted once")

func test_synergies() -> void:
	ItemDB.discovered.clear()
	var bp := Backpack.new()
	var blade := bp.place("bone_blade", Vector2i(0, 0), 0)
	check(bp.effective_effect(blade).amount == 6, "blade base 6")
	bp.place("whetstone", Vector2i(1, 0), 0)
	check(bp.effective_effect(blade).amount == 8, "whetstone boost +2 -> 8")
	var bow_bp := Backpack.new()
	var bow := bow_bp.place("crystal_bow", Vector2i(0, 0), 0)
	bow_bp.place("quiver", Vector2i(1, 0), 0)
	check(bow_bp.effective_effect(bow).amount == 5 + 2 + 1, "bow: quiver synergy +2 and boost +1 = 8")
	# fractal seed scales with neighbours
	var fb := Backpack.new()
	var seed := fb.place("fractal_seed", Vector2i(1, 1), 0)  # cells (1,1)(2,1)(3,1)(2,2)
	check(fb.effective_effect(seed).total == 0, "seed alone deals 0")
	fb.place("whetstone", Vector2i(0, 1), 0)
	fb.place("quiver", Vector2i(4, 1), 0)
	fb.place("moss_charm", Vector2i(2, 3), 0)
	var fe := fb.effective_effect(seed)
	check(fe.adjacent_count == 3 and fe.total == 9, "seed with 3 neighbours = 9 (%s)" % str(fe.total))
	fb.place("sun_shard", Vector2i(1, 2), 0)
	check(fb.effective_effect(seed).total == 4 * 3 + 4 * 1, "seed: sun_shard is crystal -> facets +1 per crystal, hidden but active (16)")
	# dagger multi-hit with plant synergy
	var db := Backpack.new()
	var dag := db.place("thorn_dagger", Vector2i(0, 0), 0)
	db.place("moss_charm", Vector2i(1, 0), 0)  # plant -> +1 (visible)
	var de := db.effective_effect(dag)
	check(de.amount == 4 and de.hits == 2 and de.total == 8, "dagger plant synergy: 4 x 2 = 8")
	db.place("spore_flask", Vector2i(1, 1), 0)  # plant +1 and secret venom +1 hit
	de = db.effective_effect(dag)
	check(de.amount == 5 and de.hits == 3 and de.total == 15, "dagger: flask plant +1 dmg, venom +1 hit = 5x3 (%s)" % str(de))
	# when_alone secret and adjacency_bonus hook
	var sb := Backpack.new()
	var sh := sb.place("lapis_shield", Vector2i(0, 0), 0)
	check(sb.effective_effect(sh).amount == 11, "lapis alone: bastion +4")
	sb.adjacency_bonus = 1
	var rb := sb.place("reed_buckler", Vector2i(2, 0), 0)
	check(sb.effective_effect(sh).amount == 7 + 2 + 1, "lapis+buckler armor synergy 2+1 hook (bastion gone)")
	check(sb.effective_effect(rb).amount == 4 + 1 + 1, "buckler armor synergy 1+1 hook")
	# passives keep their amount
	var pb := Backpack.new()
	var mc := pb.place("moss_charm", Vector2i(0, 0), 0)
	pb.place("reed_buckler", Vector2i(1, 0), 0)
	var me := pb.effective_effect(mc)
	check(me.total == 2 and me.amount == 2, "moss turn-start block scales with adjacency")

func test_secrets() -> void:
	ItemDB.discovered.clear()
	var bp := Backpack.new()
	var blade := bp.place("bone_blade", Vector2i(0, 0), 0)
	bp.place("healing_bloom", Vector2i(1, 0), 0)  # living -> marrow secret
	var eff := bp.effective_effect(blade)
	check(eff.amount == 8, "secret active though undiscovered: 8")
	check(eff.secrets_triggered == [{"item_id": "bone_blade", "secret_id": "marrow"}], "secrets_triggered reported")
	var tip := bp.describe(blade)
	check("Deal 6 damage" in tip, "tooltip hides secret numbers while undiscovered")
	check(not ("marrow" in tip) and not ("Hungers" in tip), "tooltip does not name secret")
	check("there is more" in tip, "tooltip hints at more")
	ItemDB.mark_discovered("bone_blade", "marrow")
	tip = bp.describe(blade)
	check("Deal 8 damage" in tip and "Hungers" in tip, "after discovery: real number + secret text")
	check(not ("there is more" in tip), "no hint when all secrets discovered")
	# injectable callable override
	ItemDB.discovered.clear()
	ItemDB.discovered_check = func(i: String, s: String) -> bool: return i == "bone_blade" and s == "marrow"
	check(ItemDB.is_discovered("bone_blade", "marrow"), "callable override used")
	ItemDB.discovered_check = Callable()
	check(not ItemDB.is_discovered("bone_blade", "marrow"), "override cleared")
	# visible synergies listed always
	var bb := Backpack.new()
	var bow := bb.place("crystal_bow", Vector2i(0, 0), 0)
	check("Adjacent quiver: +2" in bb.describe(bow), "visible synergy listed")
	check(bb.describe(999) == "", "describe unknown uid is empty")

func test_serialisation() -> void:
	var bp := Backpack.new()
	bp.w = 6
	bp.h = 5
	bp.place("shard_axe", Vector2i(0, 0), 3)
	bp.place("fractal_seed", Vector2i(2, 1), 1)
	var gone := bp.place("quiver", Vector2i(5, 4), 0)
	bp.place("moss_charm", Vector2i(4, 0), 0)
	bp.remove(gone)
	var back := Backpack.from_dict(bp.to_dict())
	check(back.w == 6 and back.h == 5 and back.placed.size() == 3, "round trip size/grid")
	var same := true
	for e in bp.placed:
		var f := back.entry(int(e.uid))
		if f.is_empty() or f.id != e.id or f.pos != e.pos or f.rot != e.rot:
			same = false
	check(same, "round trip entries identical (uids kept)")
	var nu := back.place("quiver", Vector2i(5, 4), 0)
	check(nu > 4 and back.entry(nu).id == "quiver", "uid counter continues past loaded uids")
	var json := JSON.stringify(bp.to_array())
	var parsed: Array = JSON.parse_string(json)
	check(Backpack.from_array(parsed, 6, 5).placed.size() == 3, "survives JSON")
	check(Backpack.from_array([{"id": "bone_blade", "pos": [9, 9], "rot": 0}]).placed.is_empty(), "invalid entry dropped")

func test_loot() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ok := true
	for i in 50:
		var l := ItemDB.roll_loot(rng, 3)
		if l.size() != 3 or l[0] == l[1] or l[1] == l[2] or l[0] == l[2]:
			ok = false
	check(ok, "roll_loot returns 3 distinct ids")
	check(ItemDB.roll_loot(rng, 99).size() == ItemDB.all_ids().size(), "count capped at pool size")
	var common := 0
	var rare_lo := 0
	var rare_hi := 0
	for i in 600:
		for id in ItemDB.roll_loot(rng, 1):
			if ItemDB.get_def(id).rarity == 1:
				common += 1
		for id in ItemDB.roll_loot(rng, 1, 0.0):
			if ItemDB.get_def(id).rarity == 3:
				rare_lo += 1
		for id in ItemDB.roll_loot(rng, 1, 3.0):
			if ItemDB.get_def(id).rarity == 3:
				rare_hi += 1
	check(common > 600 * 0.45, "commons dominate (%d/600)" % common)
	check(rare_hi > rare_lo, "rarity_bias raises rare odds (%d > %d)" % [rare_hi, rare_lo])
