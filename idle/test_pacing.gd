extends SceneTree
## Pacing sim: a bot taps ~3/s and buys greedily (best payback among affordable generators, any affordable upgrade).

var fails := 0

func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		print("FAIL: ", msg)

func _init() -> void:
	var e := Economy.new()
	var t := 0.0
	var tap_acc := 0.0
	var marks := {}
	var last_buy := 0.0
	var max_gap := 0.0
	var gap_at := 0.0
	var first_sprout := -1.0
	while t < 720.0:
		t += 0.1
		tap_acc += 0.3
		while tap_acc >= 1.0:
			tap_acc -= 1.0
			e.tap()
		e.advance(0.1)
		var bought := false
		var again := true
		while again:
			again = false
			var best := ""
			var bp := INF
			for g in Content.GENS:
				var id: String = g["id"]
				if e.gen_visible(id) and e.can_buy(id, 1):
					var pb := e.cost_at(id, e.count(id)).to_float() / e.rate_each(id)
					if pb < bp:
						bp = pb
						best = id
			if best != "" and e.buy(best, 1):
				bought = true
				again = true
				if first_sprout < 0.0 and best == "sprout":
					first_sprout = t
			for u in Content.UPGRADES:
				if e.can_buy_upgrade(u["id"]):
					e.buy_upgrade(u["id"])
					bought = true
					again = true
		for k in e.unlocked:
			if not marks.has(k):
				marks[k] = t
		if bought:
			if t - last_buy > max_gap:
				max_gap = t - last_buy
				gap_at = t
			last_buy = t
	print("first sprout %.1f s | upgrades tab %.0f | fern %.0f | gardener %.0f | tree %.0f | bloom %.0f | max gap %.0f s at %.0f | sap/s at 12 min %s" % [
		first_sprout, marks.get("tab_upgrades", -1.0), marks.get("fern", -1.0), marks.get("gardener", -1.0), marks.get("fractal_tree", -1.0), marks.get("crystal_bloom", -1.0), max_gap, gap_at, e.sap_per_sec().fmt(1)])
	check(first_sprout >= 1.0 and first_sprout <= 60.0, "first Sprout within 60 s")
	check(marks.get("tab_upgrades", 9999.0) >= 60.0 and marks.get("tab_upgrades", 9999.0) <= 120.0, "Upgrades tab 1-2 min")
	check(marks.get("fern", 9999.0) >= 150.0 and marks.get("fern", 9999.0) <= 210.0, "Fern ~3 min")
	check(marks.get("fractal_tree", 9999.0) >= 270.0 and marks.get("fractal_tree", 9999.0) <= 330.0, "Fractal Tree ~5 min")
	check(max_gap <= 90.0, "no dead gap > 90 s (%.0f)" % max_gap)
	print("test_pacing fails=", fails)
	quit(1 if fails > 0 else 0)
