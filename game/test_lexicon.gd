extends SceneTree

var fails := 0
var learned_log: Array[String] = []


func check(ok: bool, msg: String) -> void:
	print(("PASS " if ok else "FAIL ") + msg)
	if not ok:
		fails += 1


func roots() -> Array:
	var out: Array = []
	for k in Lexicon.all_keys():
		for g in Lexicon.word_for(k).slice(1):
			out.append(g)
	return out


func _init() -> void:
	Lexicon.init(1234)
	var snap: Array = []
	for k in Lexicon.all_keys():
		snap.append(Lexicon.word_for(k))
	Lexicon.init(1234)
	var same := true
	var i := 0
	for k in Lexicon.all_keys():
		if Lexicon.word_for(k) != snap[i]:
			same = false
		i += 1
	check(same, "deterministic per seed")

	var r: Array = roots()
	var seen := {}
	var uniq := true
	for g in r:
		if seen.has(g) or g < 0 or g >= Lexicon.POOL:
			uniq = false
		seen[g] = true
	check(uniq, "all root/modifier glyph ids unique and in 0..4999 (%d)" % r.size())

	var counts := {0: 14, 1: 12, 2: 10, 3: 5, 4: 2, 5: 3, 6: 8, 7: 12}
	var ok_counts := true
	for c in counts:
		if Lexicon.all_keys(c).size() < counts[c]:
			ok_counts = false
	check(ok_counts, "category minimum counts")
	var ok_cat := true
	for k in Lexicon.all_keys():
		if Lexicon.word_for(k)[0] != Lexicon.category_of(k):
			ok_cat = false
	check(ok_cat and Lexicon.category_of("item:x") == 0 and Lexicon.category_of("qual:x") == 7 and Lexicon.category_of("zzz") == -1, "category ids")

	var diff := 0
	var a_roots: Array = []
	for k in Lexicon.all_keys():
		a_roots.append(Lexicon.root_of(k))
	Lexicon.init(98765)
	var idx := 0
	for k in Lexicon.all_keys():
		if Lexicon.root_of(k) != a_roots[idx]:
			diff += 1
		idx += 1
	check(diff > a_roots.size() * 0.95, "different seeds differ (%d/%d)" % [diff, a_roots.size()])

	Lexicon.init(7)
	Lexicon.on_learned = func(k: String) -> void: learned_log.append(k)
	check(Lexicon.display_name("item:bone_blade") == "", "unknown hides name")
	check(Lexicon.readable_name("item:bone_blade") == "Bone Blade", "readable_name always")
	Lexicon.guess("item:bone_blade", "axe")
	check(Lexicon.guess_of("item:bone_blade") == "axe" and not Lexicon.confirm_guess_if_correct("item:bone_blade"), "wrong guess not confirmed")
	Lexicon.guess("item:bone_blade", " bone BLADE ")
	check(Lexicon.confirm_guess_if_correct("item:bone_blade") and Lexicon.is_known("item:bone_blade"), "correct guess confirms")
	check(Lexicon.display_name("item:bone_blade") == "Bone Blade" and learned_log == ["item:bone_blade"], "display + on_learned hook")
	check(not Lexicon.learn("item:bone_blade"), "relearn returns false")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var lk: String = Lexicon.learn_random(Lexicon.CAT_HERO, rng)
	check(Lexicon.category_of(lk) == 4 and Lexicon.is_known(lk), "learn_random")
	Lexicon.learn_random(Lexicon.CAT_HERO, rng)
	check(Lexicon.learn_random(Lexicon.CAT_HERO, rng) == "", "learn_random exhausted")
	check(Lexicon.known_fraction(Lexicon.CAT_HERO) == 1.0 and Lexicon.known_fraction() > 0.0, "known_fraction")

	check(Lexicon.register("item:new_thing", "New Thing") and Lexicon.word_for("item:new_thing").size() == 2, "register more")
	Lexicon.guess("act:use", "use?")
	var st: Dictionary = Lexicon.export_state()
	var before: Array = Lexicon.word_for("item:bone_blade")
	Lexicon.init(1)
	Lexicon.import_state(st)
	check(Lexicon.is_known("item:bone_blade") and Lexicon.word_for("item:bone_blade") == before and Lexicon.guess_of("act:use") == "use?", "export/import")

	Lexicon.on_learned = Callable()
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
