class_name Content
extends RefCounted
## Data tables for the idle game (piece 2): generators, upgrades, unlock rules, tabs. Everything is plain dictionaries so
## content is added by data. Unlock clauses: a rule fires when ANY clause holds; a clause holds when ALL its fields hold:
##   time (seconds played >=), total (total Sap earned >=), owned {gen_id: n}, unlocked [ids], upgrades [ids].
## Time + total clauses pace the average player; a pure high-total clause lets skilled players skip ahead; a pure time
## clause makes sure slow players are never blocked.

const R := 1.15
const MILESTONES: Array[int] = [25, 50, 100, 200]       # owned counts that each double a generator
const GARDENER_INTERVAL := 6.0                           # seconds between auto-buys

const GENS: Array[Dictionary] = [
	{"id": "sprout", "name": "Sprout", "cost": 10.0, "rate": 0.4, "growth": R, "key": "item:sprout", "visual": "sprout",
		"unlock": "", "cap": 12, "blurb": "A fractal shoot that drips Sap."},
	{"id": "fern", "name": "Fern", "cost": 120.0, "rate": 3.0, "growth": R, "key": "item:fern", "visual": "fern",
		"unlock": "fern", "cap": 8, "blurb": "Spiral fronds with glowing tips."},
	{"id": "tree", "name": "Fractal Tree", "cost": 1400.0, "rate": 22.0, "growth": R, "key": "item:fractal_tree", "visual": "tree",
		"unlock": "fractal_tree", "cap": 5, "blurb": "A branching tree that remembers itself."},
	{"id": "bloom", "name": "Crystal Bloom", "cost": 16000.0, "rate": 160.0, "growth": R, "key": "item:crystal_bloom", "visual": "crystal",
		"unlock": "crystal_bloom", "cap": 5, "blurb": "A faceted flower that rings with light."},
]

## Seed types (the central Seed). `plain` has no upgrade line. A granted seed (e.g. the Sap Farmer's Amber Seed) multiplies taps by
## tap_mul and adds `pct` of Sap/s per tap; its level line (Upgrades tab) costs level_cost x level_growth^level and gives
## +level_add base tap and x level_mul tap per level. tap = (1 + level_add*L) x tap_mul x level_mul^L x upgrades + pct x Sap/s.
const SEEDS: Array[Dictionary] = [
	{"id": "plain", "name": "Seed", "tap_mul": 1.0, "pct": 0.0, "key": ""},
	{"id": "amber_seed", "name": "Amber Seed", "tap_mul": 1.5, "pct": 0.01, "key": "item:amber_seed",
		"level_cost": 200.0, "level_growth": 1.7, "level_add": 1.0, "level_mul": 1.25, "max_level": 40},
]

## kind: tap_mul (value x tap) | tap_pct (tap also gives value x Sap/s) | gen_mul (target x value) | all_mul | auto | auto_speed
const UPGRADES: Array[Dictionary] = [
	{"id": "touch_1", "name": "Dewdrop Touch", "cost": 80.0, "kind": "tap_mul", "value": 2.0, "show": {"total": 40.0}},
	{"id": "sprout_1", "name": "Bright Sprouts", "cost": 150.0, "kind": "gen_mul", "target": "sprout", "value": 2.0, "show": {"owned": {"sprout": 2}}},
	{"id": "gardener", "name": "Gardener", "cost": 900.0, "kind": "auto", "value": 1.0, "show": {"unlocked": ["gardener"]}},
	{"id": "touch_2", "name": "Golden Touch", "cost": 700.0, "kind": "tap_mul", "value": 2.0, "show": {"total": 400.0}},
	{"id": "fern_1", "name": "Curling Fronds", "cost": 1500.0, "kind": "gen_mul", "target": "fern", "value": 2.0, "show": {"owned": {"fern": 1}}},
	{"id": "sprout_2", "name": "Deep Roots", "cost": 2500.0, "kind": "gen_mul", "target": "sprout", "value": 2.0, "show": {"owned": {"sprout": 10}}},
	{"id": "all_1", "name": "Warm Light", "cost": 4000.0, "kind": "all_mul", "value": 1.25, "show": {"total": 2500.0}},
	{"id": "touch_3", "name": "Resonant Touch", "cost": 6000.0, "kind": "tap_pct", "value": 0.05, "show": {"total": 3000.0}},
	{"id": "gardener_2", "name": "Quick Gardener", "cost": 12000.0, "kind": "auto_speed", "value": 0.5, "show": {"upgrades": ["gardener"], "total": 6000.0}},
	{"id": "fern_2", "name": "Glowing Tips", "cost": 15000.0, "kind": "gen_mul", "target": "fern", "value": 2.0, "show": {"owned": {"fern": 10}}},
	{"id": "sprout_3", "name": "Sprout Choir", "cost": 30000.0, "kind": "gen_mul", "target": "sprout", "value": 2.0, "show": {"owned": {"sprout": 25}}},
	{"id": "tree_1", "name": "Deeper Branching", "cost": 40000.0, "kind": "gen_mul", "target": "tree", "value": 2.0, "show": {"owned": {"tree": 1}}},
	{"id": "all_2", "name": "Waking Garden", "cost": 100000.0, "kind": "all_mul", "value": 1.5, "show": {"total": 60000.0}},
	{"id": "tree_2", "name": "Ancient Rings", "cost": 250000.0, "kind": "gen_mul", "target": "tree", "value": 2.0, "show": {"owned": {"tree": 10}}},
	{"id": "bloom_1", "name": "Prism Petals", "cost": 2500000.0, "kind": "gen_mul", "target": "bloom", "value": 2.0, "show": {"owned": {"bloom": 1}}},
]

## Each entry: id, any = clauses, word = glyph concept key (flourish), title, msg = one plain line, quiet = no flourish word.
const UNLOCKS: Array[Dictionary] = [
	{"id": "tab_upgrades", "word": "bonus:upgrades", "title": "Upgrades", "msg": "New tab: Upgrades, one-time boosts for tapping and your plants.",
		"any": [{"time": 75.0, "total": 60.0}, {"time": 75.0, "owned": {"sprout": 3}}, {"time": 200.0}]},
	{"id": "buy_x10", "quiet": true, "msg": "Buy x10 unlocked.", "any": [{"unlocked": ["tab_upgrades"]}]},
	{"id": "fern", "word": "item:fern", "title": "Fern", "msg": "New plant: Fern, makes more Sap per second than a Sprout.",
		"any": [{"time": 170.0, "total": 500.0}, {"time": 90.0, "total": 3000.0}, {"time": 330.0}]},
	{"id": "gardener", "word": "hero:gardener", "title": "Gardener", "msg": "The Gardener can be hired in Upgrades: it buys the cheapest plant for you.",
		"any": [{"unlocked": ["fern"]}]},
	{"id": "fractal_tree", "word": "item:fractal_tree", "title": "Fractal Tree", "msg": "New plant: Fractal Tree. Own 25 of a plant to double its Sap.",
		"any": [{"time": 290.0, "total": 6000.0, "unlocked": ["fern"]}, {"time": 150.0, "total": 60000.0, "unlocked": ["fern"]}, {"time": 480.0, "unlocked": ["fern"]}]},
	{"id": "buy_bulk", "quiet": true, "msg": "Buy x100 and Max unlocked, and the milestone bars.", "any": [{"unlocked": ["fractal_tree"]}]},
	{"id": "crystal_bloom", "word": "item:crystal_bloom", "title": "Crystal Bloom", "msg": "New plant: Crystal Bloom, the strongest plant so far.",
		"any": [{"time": 700.0, "total": 150000.0, "unlocked": ["fractal_tree"]}, {"total": 3000000.0, "unlocked": ["fractal_tree"]}, {"time": 1100.0, "unlocked": ["fractal_tree"]}]},
]

## Tab rail data. `unlock` = id in UNLOCKS ("" = always). Tabs without a rule yet are simply never shown (later pieces add rules).
const TABS: Array[Dictionary] = [
	{"id": "garden", "name": "Garden", "icon": "garden", "unlock": ""},
	{"id": "upgrades", "name": "Upgrades", "icon": "upgrades", "unlock": "tab_upgrades"},
	{"id": "research", "name": "Research", "icon": "research", "unlock": "tab_research"},
	{"id": "heroes", "name": "Heroes", "icon": "heroes", "unlock": "tab_heroes"},
	{"id": "expeditions", "name": "Expeditions", "icon": "expeditions", "unlock": "tab_expeditions"},
	{"id": "crafting", "name": "Crafting", "icon": "crafting", "unlock": "tab_crafting"},
	{"id": "achievements", "name": "Achievements", "icon": "achievements", "unlock": "tab_achievements"},
	{"id": "prestige", "name": "Prestige", "icon": "prestige", "unlock": "tab_prestige"},
]

const WORDS := {
	"item:sprout": "Sprout", "item:fern": "Fern", "item:fractal_tree": "Fractal Tree", "item:crystal_bloom": "Crystal Bloom",
	"bonus:upgrades": "Upgrades", "item:amber_seed": "Amber Seed", "hero:gardener": "Gardener",
}

static var _gen_idx := {}
static var _up_idx := {}


static func gen(id: String) -> Dictionary:
	if _gen_idx.is_empty():
		for i in GENS.size():
			_gen_idx[GENS[i]["id"]] = i
	return GENS[_gen_idx[id]] if _gen_idx.has(id) else {}


static func upgrade(id: String) -> Dictionary:
	if _up_idx.is_empty():
		for i in UPGRADES.size():
			_up_idx[UPGRADES[i]["id"]] = i
	return UPGRADES[_up_idx[id]] if _up_idx.has(id) else {}


static func seed_def(id: String) -> Dictionary:
	for s in SEEDS:
		if s["id"] == id:
			return s
	return SEEDS[0]


static func unlock_def(id: String) -> Dictionary:
	for u in UNLOCKS:
		if u["id"] == id:
			return u
	return {}


## Registers the concept keys used by flourishes (idempotent; call after Hub.boot()).
static func register_words() -> void:
	for k in WORDS:
		Lexicon.register(k, WORDS[k])
