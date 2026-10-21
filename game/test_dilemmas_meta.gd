extends SceneTree

var fails: int = 0
const VALID_EFFECTS := ["max_hp", "hp", "gold", "item", "curse_item", "remove_item", "shrink_pack", "grow_pack",
	"reveal_glyph", "change_path", "heal_all"]
var got: Array = []

func check(cond: bool, label: String) -> void:
	print(("PASS " if cond else "FAIL ") + label)
	if not cond:
		fails += 1

func _on_secret(item: String, secret: String) -> void:
	got.append(item + "/" + secret)

func _init() -> void:
	test_dilemmas()
	test_expansion_dilemmas()
	test_meta()
	quit(1 if fails > 0 else 0)

func test_dilemmas() -> void:
	check(DilemmaDB.DILEMMAS.size() >= 12, "at least 12 dilemmas")
	var ids: Dictionary = {}
	var ok: bool = true
	for d: Dictionary in DilemmaDB.DILEMMAS:
		ids[d["id"]] = true
		var n: int = (d["choices"] as Array).size()
		ok = ok and n >= 2 and n <= 3 and str(d["title"]) != "" and str(d["text"]) != ""
		for c: Dictionary in d["choices"]:
			for e: Dictionary in c["effects"]:
				ok = ok and VALID_EFFECTS.has(e["type"])
	check(ids.size() == DilemmaDB.DILEMMAS.size(), "unique ids")
	check(ok, "shape: 2-3 choices, valid effect types")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ctx: Dictionary = {"seen": []}
	var picked: Dictionary = {}
	var repeat: bool = false
	for i in DilemmaDB.DILEMMAS.size():
		var d: Dictionary = DilemmaDB.roll(rng, ctx)
		if picked.has(d["id"]):
			repeat = true
		picked[d["id"]] = true
	check(not repeat and picked.size() == DilemmaDB.DILEMMAS.size(), "no repeats until pool exhausted")
	var again: Dictionary = DilemmaDB.roll(rng, ctx)
	check(not again.is_empty() and (ctx["seen"] as Array).size() == 1, "pool restarts after exhaustion")
	check(not DilemmaDB.roll(rng).is_empty(), "roll works with no context")

func test_meta() -> void:
	var path: String = "user://test_meta_tmp.cfg"
	Meta.reset_for_tests(path)
	check(Meta.lexicon_seed > 0, "seed created on first launch")
	var s: int = Meta.lexicon_seed
	check(s <= 0x7FFFFFFFFFFFFFFF, "seed is 63-bit")
	check(Meta.is_hero_unlocked("seshat") and not Meta.is_hero_unlocked("thoth"), "seshat unlocked, thoth locked")
	check(Meta.unlocked_origins.size() == 3, "three origins")
	check(not Meta.is_known("item:bone_blade"), "unknown at first")
	Meta.set_guess("item:bone_blade", "sword?")
	check(Meta.get_guess("item:bone_blade") == "sword?", "guess stored")
	Meta.mark_known("item:bone_blade")
	check(Meta.is_known("item:bone_blade") and Meta.known_items.has("bone_blade") and Meta.get_guess("item:bone_blade") == "", "mark_known identifies item, clears guess")
	Meta.on_secret_discovered = _on_secret
	check(Meta.discover_secret("bone_blade", "echo"), "secret discovered first time")
	check(not Meta.discover_secret("bone_blade", "echo") and got.size() == 1, "hook fires once")
	Meta.see_enemy("spore_sprout")
	check(Meta.discover_trait("spore_sprout", "splits") and not Meta.discover_trait("spore_sprout", "splits"), "bestiary trait once")
	Meta.record_progress(4)
	var unlocked: Array[String] = Meta.record_run("seshat", true, 5)
	check(unlocked == ["thoth"] and Meta.best_progress == 5, "winning unlocks thoth, progress recorded")
	# reload from disk
	Meta.load()
	check(Meta.lexicon_seed == s, "seed survives reload unchanged")
	check(Meta.is_known("item:bone_blade") and Meta.is_secret_discovered("bone_blade", "echo"), "known + secret persisted")
	check(Meta.is_hero_unlocked("thoth") and Meta.has_trait("spore_sprout", "splits"), "heroes + bestiary persisted")
	check(Meta.hero_stats["seshat"]["wins"] == 1, "hero stats persisted")
	DirAccess.remove_absolute(path)

func test_expansion_dilemmas() -> void:
	check(DilemmaDB.DILEMMAS.size() >= 26, "at least 26 dilemmas (%d)" % DilemmaDB.DILEMMAS.size())
	var items_given: Dictionary = {}
	var reveal := 0
	var modes: Dictionary = {}
	var ok: bool = true
	for d: Dictionary in DilemmaDB.DILEMMAS:
		for c: Dictionary in d["choices"]:
			ok = ok and str(c["label"]) != "" and str(c["flavor"]) != ""
			for e: Dictionary in c["effects"]:
				if e["type"] == "item" and str(e.get("id", "")) != "":
					items_given[e["id"]] = true
					ok = ok and not ItemDB.get_def(str(e["id"])).is_empty()
				if e["type"] == "reveal_glyph":
					reveal += 1
					ok = ok and int(e["amount"]) >= 1
				if e["type"] == "change_path":
					modes[e["mode"]] = true
	check(ok, "every dilemma choice has text; item ids exist")
	check(reveal >= 12, "glyph reveals are common (%d)" % reveal)
	check(modes.has("wither") and modes.has("sprout") and modes.has("swap") and modes.has("reveal") and modes.has("hide"), "all 5 route modes used")
	for id in ["prism_lattice", "mirror_shard", "ember_censer", "void_lantern", "tide_flute", "cursed_crown",
			"hungry_maw", "echo_bell", "spiral_shell", "hollow_idol", "grafted_heart"]:
		check(items_given.has(id), "a dilemma offers " + id)
