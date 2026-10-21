class_name Lexicon
extends RefCounted
## Per-profile secret language. Concepts ("item:bone_blade", "loc:fight", ...) get unique
## root glyph ids from a seeded shuffle. Words = [kind_id, root(, modifier)].
## Pure numbers/logic: no drawing. Glyph shapes come from GlyphsLib/GlyphGen elsewhere.

const POOL := 5000
const CAT_ITEM := 0
const CAT_BONUS := 1
const CAT_LOC := 2
const CAT_ENEMY := 3
const CAT_HERO := 4
const CAT_ORIGIN := 5
const CAT_ACT := 6
const CAT_QUAL := 7
const PREFIXES: Array[String] = ["item", "bonus", "loc", "enemy", "hero", "origin", "act", "qual"]
const MAX_CONCEPTS := POOL / 2

static var seed_value: int = 0
static var on_learned: Callable = Callable()   # called as on_learned.call(key: String)

static var _names: Dictionary = {}       # key -> readable English name
static var _order: Array[String] = []    # registration order (index drives glyph assignment)
static var _compound: Dictionary = {}    # key -> true (gets a modifier glyph)
static var _perm: Array[int] = []        # seeded shuffle of 0..POOL-1
static var _words: Dictionary = {}       # key -> Array[int]
static var _known: Dictionary = {}       # key -> true
static var _guesses: Dictionary = {}     # key -> String


static func init(p_seed: int, known: Dictionary = {}) -> void:
	seed_value = p_seed
	_names.clear()
	_order.clear()
	_compound.clear()
	_words.clear()
	_known = known.duplicate()
	_guesses.clear()
	_make_perm()
	_register_defaults()


static func _make_perm() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_perm = []
	for i in POOL:
		_perm.append(i)
	for i in range(POOL - 1, 0, -1):   # Fisher-Yates
		var j: int = rng.randi_range(0, i)
		var tmp: int = _perm[i]
		_perm[i] = _perm[j]
		_perm[j] = tmp


## Registers a new concept (idempotent). The key prefix decides the category.
static func register(key: String, readable: String, compound := false) -> bool:
	if _names.has(key):
		return true
	if category_of(key) < 0 or _order.size() >= MAX_CONCEPTS:
		return false
	var idx: int = _order.size()
	_order.append(key)
	_names[key] = readable
	if compound:
		_compound[key] = true
	var w: Array[int] = [category_of(key), _perm[idx]]
	if compound:
		w.append(_perm[MAX_CONCEPTS + idx])
	_words[key] = w
	return true


static func category_of(key: String) -> int:
	var p: int = key.find(":")
	if p <= 0:
		return -1
	return PREFIXES.find(key.substr(0, p))


static func has_concept(key: String) -> bool:
	return _names.has(key)


static func word_for(key: String) -> Array[int]:
	var out: Array[int] = []
	if _words.has(key):
		out.assign(_words[key])
	return out


static func root_of(key: String) -> int:
	return _words[key][1] if _words.has(key) else -1


static func readable_name(key: String) -> String:
	return _names.get(key, "")


## Readable name only once learned (or a confirmed guess); else '' (show glyphs).
static func display_name(key: String) -> String:
	return readable_name(key) if is_known(key) else ""


static func is_known(key: String) -> bool:
	return _known.has(key)


static func learn(key: String) -> bool:
	if not _names.has(key) or _known.has(key):
		return false
	_known[key] = true
	_guesses.erase(key)
	if on_learned.is_valid():
		on_learned.call(key)
	return true


static func guess(key: String, text: String) -> void:
	if _names.has(key) and not _known.has(key):
		_guesses[key] = text.strip_edges()


static func guess_of(key: String) -> String:
	return _guesses.get(key, "")


static func _norm(s: String) -> String:
	return s.strip_edges().to_lower().replace("_", " ")


## If the pencilled guess matches the real name, learns the word. Returns true on success.
static func confirm_guess_if_correct(key: String) -> bool:
	if not _guesses.has(key) or not _names.has(key):
		return false
	if _norm(_guesses[key]) != _norm(_names[key]):
		return false
	return learn(key)


## category < 0 means every category.
static func all_keys(category := -1) -> Array[String]:
	var out: Array[String] = []
	for k in _order:
		if category < 0 or category_of(k) == category:
			out.append(k)
	return out


static func known_fraction(category := -1) -> float:
	var keys: Array[String] = all_keys(category)
	if keys.is_empty():
		return 0.0
	var n := 0
	for k in keys:
		if _known.has(k):
			n += 1
	return float(n) / float(keys.size())


## Reveals one unknown word of a category; returns its key or '' if none left.
static func learn_random(category: int, rng: RandomNumberGenerator) -> String:
	var pool: Array[String] = []
	for k in all_keys(category):
		if not _known.has(k):
			pool.append(k)
	if pool.is_empty():
		return ""
	var key: String = pool[rng.randi_range(0, pool.size() - 1)]
	learn(key)
	return key


static func export_state() -> Dictionary:
	return {"seed": seed_value, "known": _known.duplicate(), "guesses": _guesses.duplicate()}


static func import_state(d: Dictionary) -> void:
	init(int(d.get("seed", 0)), d.get("known", {}))
	_guesses = d.get("guesses", {}).duplicate()


static func _register_defaults() -> void:
	var items := {
		"bone_blade": "Bone Blade", "shard_axe": "Shard Axe", "thorn_dagger": "Thorn Dagger",
		"crystal_bow": "Crystal Bow", "lapis_shield": "Lapis Shield", "reed_buckler": "Reed Buckler",
		"whetstone": "Whetstone", "quiver": "Quiver", "spore_flask": "Spore Flask",
		"healing_bloom": "Healing Bloom", "sun_shard": "Sun Shard", "moss_charm": "Moss Charm",
		"fractal_seed": "Fractal Seed", "glyph_lens": "Glyph Lens"}
	for id in items:
		register("item:" + id, items[id], id in ["fractal_seed", "glyph_lens", "healing_bloom"])
	var bonuses := {
		"damage": "Damage", "block": "Block", "heal": "Heal", "energy": "Energy",
		"adjacency": "Adjacency", "multi": "Many Strikes", "thorns": "Thorns", "poison": "Poison",
		"draw": "Insight", "growth": "Growth", "echo": "Echo", "luck": "Luck"}
	for id in bonuses:
		register("bonus:" + id, bonuses[id], id in ["adjacency", "multi"])
	var locs := {
		"fight": "Fight", "elite": "Elite", "treasure": "Treasure", "shop": "Shop", "rest": "Rest",
		"shrine": "Shrine", "dilemma": "Dilemma", "mystery": "Mystery",
		"waterfall": "Waterfall", "limbo": "Limbo"}
	for id in locs:
		register("loc:" + id, locs[id], id in ["waterfall", "limbo", "elite"])
	var enemies := {
		"spore_sprout": "Spore Sprout", "thorn_crawler": "Thorn Crawler", "crystal_moth": "Crystal Moth",
		"glass_golem": "Glass Golem", "cascade_warden": "Cascade Warden"}
	for id in enemies:
		register("enemy:" + id, enemies[id], id == "cascade_warden")
	register("hero:seshat", "Seshat")
	register("hero:thoth", "Thoth")
	register("origin:eclipse", "Eclipse")
	register("origin:mirror", "Mirror")
	register("origin:cathedral", "Cathedral")
	var acts := {
		"use": "Use", "give": "Give", "take": "Take", "spare": "Spare", "flee": "Flee",
		"remember": "Remember", "forget": "Forget", "ask": "Ask"}
	for id in acts:
		register("act:" + id, acts[id])
	var quals := {
		"fire": "Fire", "still": "Still", "many": "Many", "hidden": "Hidden", "high": "High",
		"deep": "Deep", "water": "Water", "bright": "Bright", "dark": "Dark",
		"broken": "Broken", "whole": "Whole", "old": "Old"}
	for id in quals:
		register("qual:" + id, quals[id])
