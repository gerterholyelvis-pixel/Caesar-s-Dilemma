extends SceneTree

var fails := 0

func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		print("FAIL: ", msg)

func _init() -> void:
	var ec := Economy.new()
	for i in 9:
		ec.tap()
	check(not ec.can_buy_sprout() and not ec.buy_sprout(), "9 taps cannot buy")
	check(ec.panel_unlocked, "panel unlocked after 5 taps")
	ec.tap()
	check(ec.can_buy_sprout(), "10 taps buys the first sprout")
	check(ec.buy_sprout() and ec.sprouts == 1 and ec.sap.is_zero(), "bought")
	check(ec.sprout_cost().cmp(BigNum.of(12.0)) == 0, "second costs 12: " + ec.sprout_cost().fmt())
	check(is_equal_approx(ec.sap_per_sec().to_float(), 0.4), "rate")
	ec.advance(29.0)
	check(not ec.can_buy_sprout(), "not yet at 29 s")
	ec.advance(1.5)
	check(ec.can_buy_sprout(), "second sprout affordable by ~30 s")
	check(ec.sprout_cost(10).to_float() > ec.sprout_cost(9).to_float(), "cost grows")
	var snap := ec.to_dict()
	var e2 := Economy.new()
	e2.from_dict(JSON.parse_string(JSON.stringify(snap)))
	check(e2.sprouts == ec.sprouts and e2.taps == ec.taps and e2.sap.cmp(ec.sap) == 0 and e2.panel_unlocked, "save roundtrip via JSON")
	var g := e2.apply_offline(1.0e9)
	check(is_equal_approx(g.to_float(), 0.4 * Economy.OFFLINE_CAP * Economy.OFFLINE_EFFICIENCY), "offline capped")
	print("test_economy fails=", fails)
	quit(1 if fails > 0 else 0)
