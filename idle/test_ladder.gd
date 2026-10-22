extends SceneTree

var fails := 0

func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		print("FAIL: ", msg)

func _init() -> void:
	var e := Economy.new()
	e.panel_unlocked = true
	# cost curve and closed-form bulk vs loop
	for id in ["sprout", "fern", "tree", "bloom"]:
		for k in [0, 7, 30]:
			for n in [1, 10, 100]:
				var loop := 0.0
				for j in n:
					loop += float(Content.gen(id)["cost"]) * pow(1.15, k + j)
				var cf := e.bulk_cost(id, n, k).to_float()
				check(absf(cf - loop) <= maxf(loop * 1e-9, 1.0), "bulk %s k=%d n=%d: %f vs %f" % [id, k, n, cf, loop])
	check(e.cost_at("sprout", 0).to_float() == 10.0 and e.cost_at("sprout", 1).to_float() == 12.0, "sprout costs 10, 12")
	# max affordable is exactly the largest affordable n
	e.sap = BigNum.of(5000.0)
	var m := e.max_affordable("sprout")
	check(m > 1 and e.sap.gte(e.bulk_cost("sprout", m)) and not e.sap.gte(e.bulk_cost("sprout", m + 1)), "max exact: %d" % m)
	check(e.max_affordable("fern") >= 1 and e.mode_count("fern", -1) == e.max_affordable("fern"), "max mode")
	e.sap = BigNum.of(5.0)
	check(e.max_affordable("sprout") == 0 and e.mode_count("sprout", -1) == 1, "max 0 shows x1")
	# buying bulk
	e.sap = BigNum.of(1.0e6)
	var before := e.sap
	check(e.buy("sprout", 10) and e.count("sprout") == 10, "buy 10")
	check(absf(before.sub(e.sap).to_float() - e.bulk_cost("sprout", 10, 0).to_float()) < 1.0, "paid the closed form")
	# milestones: x2 at 25/50/100/200
	e.owned["sprout"] = 24
	var r24 := e.rate_each("sprout")
	e.owned["sprout"] = 25
	check(is_equal_approx(e.rate_each("sprout"), r24 * 2.0), "x2 at 25")
	e.owned["sprout"] = 200
	check(is_equal_approx(e.rate_each("sprout"), r24 * 16.0) and e.next_milestone("sprout") == -1, "x16 at 200")
	e.owned["sprout"] = 30
	check(e.next_milestone("sprout") == 50 and absf(e.milestone_progress("sprout") - 0.2) < 1e-6, "progress to 50")
	# upgrades
	e = Economy.new()
	e.panel_unlocked = true
	e.unlocked["tab_upgrades"] = true
	e.owned["sprout"] = 2
	e.sap = BigNum.of(200.0)
	check(e.upgrade_visible("sprout_1") and not e.upgrade_visible("fern_1"), "visibility by relevance")
	var base := e.rate_each("sprout")
	check(e.buy_upgrade("sprout_1") and not e.buy_upgrade("sprout_1"), "one-time")
	e.sap = BigNum.of(1.0e5)
	check(is_equal_approx(e.rate_each("sprout"), base * 2.0), "sprout x2")
	check(is_equal_approx(e.tap_value().to_float(), 1.0), "plain tap 1")
	e.buy_upgrade("touch_1")
	check(is_equal_approx(e.tap_value().to_float(), 2.0), "touch x2")
	var pre := e.rate_each("sprout")
	e.buy_upgrade("all_1")
	check(is_equal_approx(e.rate_each("sprout"), pre * 1.25), "all x1.25")
	# unlock rules
	e = Economy.new()
	e.panel_unlocked = true
	e.advance(80.0)
	check(not e.unlocked.get("tab_upgrades", false), "no tab without Sap")
	e._gain(BigNum.of(100.0))
	e.advance(0.2)
	check(e.unlocked.get("tab_upgrades", false) and e.unlocked.get("buy_x10", false), "tab at 75 s + 60 Sap")
	check(not e.unlocked.get("fern", false), "fern not yet")
	e.advance(12.0)
	e._gain(BigNum.of(5000.0))
	e.advance(0.2)
	check(e.unlocked.get("fern", false) and e.unlocked.get("gardener", false), "skilled path: fern + gardener via total Sap")
	var f := Economy.new()
	f.panel_unlocked = true
	f.advance(335.0)
	check(f.unlocked.get("fern", false) and f.unlocked.get("tab_upgrades", false), "slow players are never blocked")
	# gardener auto-buy picks the cheapest affordable
	var g := Economy.new()
	g.panel_unlocked = true
	g.unlocked["fern"] = true
	g.upgrades["gardener"] = true
	g.sap = BigNum.of(500.0)
	check(g.gardener_pick() == "sprout", "cheapest pick")
	g.advance(Content.GARDENER_INTERVAL + 0.2)
	check(g.sprouts == 1, "gardener bought one")
	# one-shot milestones
	var h := Economy.new()
	h.panel_unlocked = true
	h.sap = BigNum.of(1.0e6)
	h.buy("sprout", 1)
	h.buy("sprout", 9)
	var ids: Array = []
	for ev in h.events:
		if ev["t"] == "milestone":
			ids.append(ev["id"])
	check(ids == ["first_sprout", "sprouts_10"], "milestones fire once: " + str(ids))
	h.events.clear()
	h.buy("sprout", 1)
	check(h.events.is_empty(), "never repeat")
	var h2 := Economy.new()
	h2.from_dict(JSON.parse_string(JSON.stringify(h.to_dict())))
	check(h2.fired.has("first_sprout") and h2.fired.has("sprouts_10") and h2.events.is_empty(), "milestones persist")
	# seeds: tap by type and level
	var s := Economy.new()
	check(is_equal_approx(s.tap_value().to_float(), 1.0), "plain seed tap 1")
	check(s.grant_seed("amber_seed") and not s.grant_seed("amber_seed") and not s.grant_seed("nope"), "grant")
	check(is_equal_approx(s.tap_value().to_float(), 1.5), "amber level 0 = x1.5")
	var expect := [1.5, 3.75, 7.03125]
	for L in 3:
		check(absf(s.tap_value_at("amber_seed", L).to_float() - float(expect[L])) < 1e-6, "amber L%d: %f" % [L, s.tap_value_at("amber_seed", L).to_float()])
	check(s.tap_value_at("amber_seed", 10).to_float() > 100.0, "L10 satisfying")
	s.sap = BigNum.of(1000.0)
	check(s.seed_level_cost().to_float() == 200.0 and s.buy_seed_level() and s.seed_level == 1 and s.seed_level_cost().to_float() == 340.0, "level costs 200, 340")
	s.owned["sprout"] = 10
	var sps := s.sap_per_sec().to_float() * 0.01              # +1% of Sap/s per tap
	check(absf(s.tap_value().to_float() - (3.75 + sps)) < 1e-6, "pct part")
	s.upgrades["touch_1"] = true
	check(absf(s.tap_value().to_float() - (7.5 + sps)) < 1e-6, "upgrades stack with the seed")
	check(s.seed_tooltip().contains("level 1") and s.seed_tooltip().contains("Next level"), "tooltip maths")
	# save roundtrip + migration of a piece-1 save
	var s2 := Economy.new()
	s2.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check(s2.seed_type == "amber_seed" and s2.seed_level == 1 and s2.count("sprout") == 10 and s2.has_upgrade("touch_1"), "v2 roundtrip")
	var old := {"v": 1, "sap": [2.5, 1], "total": [4.0, 2], "taps": 40, "sprouts": 4, "panel": true}
	var m1 := Economy.new()
	m1.from_dict(old)
	check(m1.sprouts == 4 and m1.panel_unlocked and m1.sap.to_float() == 25.0 and m1.seed_type == "plain" and m1.fired.has("first_sprout"), "v1 migration")
	check(m1.play_time > 0.0 and m1.events.is_empty(), "migration sets a clock, no replayed events")
	var bad := Economy.new()
	bad.from_dict({"v": 99, "owned": {"sprout": 3, "nope": 5}, "upgrades": ["touch_1", "zzz"], "seed": "ghost", "unlocked": 5})
	check(bad.sprouts == 3 and bad.has_upgrade("touch_1") and not bad.has_upgrade("zzz") and bad.seed_type == "plain", "tolerates odd data")
	print("test_ladder fails=", fails)
	quit(1 if fails > 0 else 0)
