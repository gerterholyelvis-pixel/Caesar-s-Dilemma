class_name Meta
extends RefCounted
## Permanent, cross-run profile saved to user://meta.cfg. All static; call Meta.load() once at startup.
## Words are keyed by Lexicon concept keys ("item:bone_blade", "loc:fight", ...).

static var save_path: String = "user://meta.cfg"
## Optional hook fired as hook.call(item_id, secret_id) when a secret is discovered for the first time
## (the run layer can point it at ItemDB.discovered without Meta depending on ItemDB).
static var on_secret_discovered: Callable = Callable()

static var lexicon_seed: int = 0                 # random 63-bit, created once, never changed
static var known_words: Dictionary = {}          # concept_key -> true
static var guesses: Dictionary = {}              # concept_key -> String (player's pencilled guess)
static var known_items: Dictionary = {}          # item id -> true (identified)
static var discovered_secrets: Dictionary = {}   # "item_id/secret_id" -> true (a set)
static var bestiary: Dictionary = {}             # enemy id -> {"seen": int, "traits": Array[String]}
static var best_progress: int = 0                # deepest route depth reached
static var unlocked_heroes: Array = ["seshat"]
static var unlocked_origins: Array = ["eclipse", "mirror", "cathedral"]
static var hero_stats: Dictionary = {}           # hero id -> {"runs": int, "wins": int, "best": int}

const SECTION := "meta"

static func _reset_defaults() -> void:
	lexicon_seed = 0
	known_words = {}
	guesses = {}
	known_items = {}
	discovered_secrets = {}
	bestiary = {}
	best_progress = 0
	unlocked_heroes = ["seshat"]
	unlocked_origins = ["eclipse", "mirror", "cathedral"]
	hero_stats = {}

## Points Meta at another file (tests), wipes memory to fresh defaults and deletes any file there.
static func reset_for_tests(path: String) -> void:
	save_path = path
	_reset_defaults()
	on_secret_discovered = Callable()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	_ensure_seed()

static func _new_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var s: int = (int(rng.randi()) << 31) ^ int(rng.randi())
	s &= 0x7FFFFFFFFFFFFFFF
	return maxi(s, 1)

static func _ensure_seed() -> void:
	if lexicon_seed == 0:
		lexicon_seed = _new_seed()
		save()

## Loads the profile (missing file or keys fall back to defaults); creates and saves the seed on first launch.
static func load() -> void:
	_reset_defaults()
	var cfg := ConfigFile.new()
	if cfg.load(save_path) == OK:
		lexicon_seed = int(cfg.get_value(SECTION, "lexicon_seed", 0))
		known_words = cfg.get_value(SECTION, "known_words", {})
		guesses = cfg.get_value(SECTION, "guesses", {})
		known_items = cfg.get_value(SECTION, "known_items", {})
		discovered_secrets = cfg.get_value(SECTION, "discovered_secrets", {})
		bestiary = cfg.get_value(SECTION, "bestiary", {})
		best_progress = int(cfg.get_value(SECTION, "best_progress", 0))
		unlocked_heroes = cfg.get_value(SECTION, "unlocked_heroes", ["seshat"])
		unlocked_origins = cfg.get_value(SECTION, "unlocked_origins", ["eclipse", "mirror", "cathedral"])
		hero_stats = cfg.get_value(SECTION, "hero_stats", {})
		if not unlocked_heroes.has("seshat"):
			unlocked_heroes.append("seshat")
	_ensure_seed()

static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "lexicon_seed", lexicon_seed)
	cfg.set_value(SECTION, "known_words", known_words)
	cfg.set_value(SECTION, "guesses", guesses)
	cfg.set_value(SECTION, "known_items", known_items)
	cfg.set_value(SECTION, "discovered_secrets", discovered_secrets)
	cfg.set_value(SECTION, "bestiary", bestiary)
	cfg.set_value(SECTION, "best_progress", best_progress)
	cfg.set_value(SECTION, "unlocked_heroes", unlocked_heroes)
	cfg.set_value(SECTION, "unlocked_origins", unlocked_origins)
	cfg.set_value(SECTION, "hero_stats", hero_stats)
	cfg.save(save_path)

# --- words & items ------------------------------------------------------------------------------

static func is_known(key: String) -> bool:
	return known_words.has(key) or known_items.has(key.trim_prefix("item:"))

## Marks a concept key known. "item:<id>" keys also identify the item. Returns true when it was new.
static func mark_known(key: String) -> bool:
	var fresh: bool = not is_known(key)
	known_words[key] = true
	guesses.erase(key)
	if key.begins_with("item:"):
		known_items[key.trim_prefix("item:")] = true
	if fresh:
		save()
	return fresh

static func is_item_known(id: String) -> bool:
	return known_items.has(id) or known_words.has("item:" + id)

static func mark_item_known(id: String) -> bool:
	return mark_known("item:" + id)

static func set_guess(key: String, text: String) -> void:
	if known_words.has(key):
		return
	if text.strip_edges() == "":
		guesses.erase(key)
	else:
		guesses[key] = text.strip_edges()
	save()

static func get_guess(key: String) -> String:
	return str(guesses.get(key, ""))

# --- secrets ------------------------------------------------------------------------------------

static func _secret_key(item_id: String, secret_id: String) -> String:
	return item_id + "/" + secret_id

static func is_secret_discovered(item_id: String, secret_id: String) -> bool:
	return discovered_secrets.has(_secret_key(item_id, secret_id))

static func secrets_of(item_id: String) -> Array[String]:
	var out: Array[String] = []
	var prefix: String = item_id + "/"
	for k: String in discovered_secrets:
		if k.begins_with(prefix):
			out.append(k.trim_prefix(prefix))
	return out

## Records a secret permanently and fires on_secret_discovered once. Returns true when it was new.
static func discover_secret(item_id: String, secret_id: String) -> bool:
	if is_secret_discovered(item_id, secret_id):
		return false
	discovered_secrets[_secret_key(item_id, secret_id)] = true
	save()
	if on_secret_discovered.is_valid():
		on_secret_discovered.call(item_id, secret_id)
	return true

# --- bestiary -----------------------------------------------------------------------------------

static func see_enemy(enemy_id: String) -> void:
	var e: Dictionary = bestiary.get(enemy_id, {"seen": 0, "traits": []})
	e["seen"] = int(e["seen"]) + 1
	bestiary[enemy_id] = e
	save()

## Records a hidden enemy trait (e.g. "splits"). Returns true when new.
static func discover_trait(enemy_id: String, trait_id: String) -> bool:
	var e: Dictionary = bestiary.get(enemy_id, {"seen": 0, "traits": []})
	var traits: Array = e["traits"]
	if traits.has(trait_id):
		return false
	traits.append(trait_id)
	e["traits"] = traits
	bestiary[enemy_id] = e
	save()
	return true

static func has_trait(enemy_id: String, trait_id: String) -> bool:
	var e: Dictionary = bestiary.get(enemy_id, {})
	return e.has("traits") and (e["traits"] as Array).has(trait_id)

# --- progress, heroes, origins --------------------------------------------------------------------

static func record_progress(depth: int) -> void:
	if depth > best_progress:
		best_progress = depth
		save()

## Alias for the contract's `best_floor`.
static func get_best_floor() -> int:
	return best_progress

static func is_hero_unlocked(id: String) -> bool:
	return unlocked_heroes.has(id)

static func unlock_hero(id: String) -> bool:
	if unlocked_heroes.has(id):
		return false
	unlocked_heroes.append(id)
	save()
	return true

static func is_origin_unlocked(id: String) -> bool:
	return unlocked_origins.has(id)

static func unlock_origin(id: String) -> bool:
	if unlocked_origins.has(id):
		return false
	unlocked_origins.append(id)
	save()
	return true

## Records the end of a run for a hero; unlocks Thoth the first time Seshat wins (or any hero reaches depth 6+).
## Returns the list of newly unlocked hero ids.
static func record_run(hero: String, won: bool, depth: int) -> Array[String]:
	var s: Dictionary = hero_stats.get(hero, {"runs": 0, "wins": 0, "best": 0})
	s["runs"] = int(s["runs"]) + 1
	s["wins"] = int(s["wins"]) + (1 if won else 0)
	s["best"] = maxi(int(s["best"]), depth)
	hero_stats[hero] = s
	if depth > best_progress:
		best_progress = depth
	var fresh: Array[String] = []
	if (won or depth >= 6) and unlock_hero("thoth"):
		fresh.append("thoth")
	save()
	return fresh
