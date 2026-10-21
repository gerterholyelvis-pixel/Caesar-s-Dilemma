extends SceneTree

var fails := 0
var got := {}

func check(ok: bool, msg: String) -> void:
	print(("PASS " if ok else "FAIL ") + msg)
	if not ok:
		fails += 1

func _init() -> void:
	Lexicon.init(77)
	Meta.reset_for_tests("user://t_screens.cfg")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var loot := LootUI.new()
	root.add_child(loot)
	loot.chosen.connect(func(id): got["loot"] = id)
	var offers := ItemDB.roll_loot(rng, 3)
	loot.show_offers(offers)
	await create_timer(0.3).timeout
	loot.pick(1)
	await create_timer(1.0).timeout
	check(got.get("loot", "") == offers[1], "loot chosen")
	var dl := DilemmaUI.new()
	root.add_child(dl)
	dl.chosen.connect(func(i): got["dil"] = i)
	var dd := DilemmaDB.roll(rng)
	dl.show_dilemma(dd)
	await create_timer(0.3).timeout
	dl.skip_text()
	await create_timer(0.3).timeout
	dl.choose(0)
	await create_timer(1.0).timeout
	check(got.get("dil", -1) == 0, "dilemma chosen")
	check(DilemmaUI.effect_line({"type": "hp", "amount": -7})[0] == "-7 HP", "effect text")
	var sh := ShrineUI.new()
	root.add_child(sh)
	sh.done.connect(func(): got["shrine"] = true)
	sh.open(rng)
	var k := sh.reveal()
	check(k != "" and Lexicon.is_known(k), "shrine reveals a word")
	sh._unknown_words()
	var u: String = sh._unknown[0]
	check(not sh.guess_word(u, "wrong"), "wrong guess stays")
	check(sh.guess_word(u, Lexicon.readable_name(u)), "right guess learns")
	await create_timer(0.2).timeout
	sh.leave()
	check(got.has("shrine"), "shrine done")
	var hs := HeroSelectUI.new()
	root.add_child(hs)
	hs.picked.connect(func(h, o): got["hero"] = [h, o])
	hs.open()
	hs.choose("thoth", "mirror")
	check(hs.hero == "seshat", "locked hero refused")
	hs.choose("seshat", "mirror")
	hs.confirm()
	await create_timer(1.0).timeout
	check(got.get("hero", []) == ["seshat", "mirror"], "hero picked")
	print("FAILS: ", fails)
	quit(fails)
