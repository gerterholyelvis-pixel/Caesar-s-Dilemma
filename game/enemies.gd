class_name EnemyDB
extends RefCounted
## Enemy definitions. Pure data + encounter picking. Lore lines are deliberately cryptic.
## Intent entry: {type: "attack"|"block"|"heal"|"split", amount:int, hits:int(optional), glyphs:Array[int],
## spawn:String(optional, for "split")}. `phases` (optional) = ordered list of {below: float hp fraction,
## intents: Array, omen: String}; the first phase has below = 1.0. Without phases, `intents` cycles forever.
## `traits` are HIDDEN: Combat reveals each one the first time it fires (enemy_trait_revealed).

const MAX_ENEMIES := 4
const BOSS_ID := "cascade_warden"

const ENEMIES: Dictionary = {
	"spore_sprout": {
		"id": "spore_sprout", "name": "Spore Sprout", "art": "spore_sprout",
		"max_hp": 36, "scale": 1.0,
		"lore": "It remembers being whole.",
		"traits": ["splits"],
		"intents": [
			{"type": "attack", "amount": 4, "glyphs": [3, 7]},
			{"type": "heal", "amount": 3, "glyphs": [9]},
			{"type": "attack", "amount": 5, "glyphs": [3, 7, 1]},
		],
	},
	"thorn_crawler": {
		"id": "thorn_crawler", "name": "Thorn Crawler", "art": "thorn_crawler",
		"max_hp": 48, "scale": 1.0,
		"lore": "Touch it and it touches back.",
		"traits": ["thorns"],
		"intents": [
			{"type": "attack", "amount": 6, "glyphs": [5, 2]},
			{"type": "block", "amount": 5, "glyphs": [11]},
			{"type": "attack", "amount": 8, "glyphs": [5, 2, 6]},
		],
	},
	"crystal_moth": {
		"id": "crystal_moth", "name": "Crystal Moth", "art": "crystal_moth",
		"max_hp": 32, "scale": 0.85,
		"lore": "Drawn to the light you carry.",
		"traits": ["siphon"],
		"intents": [
			{"type": "attack", "amount": 3, "hits": 2, "glyphs": [12, 0]},
			{"type": "attack", "amount": 5, "glyphs": [12]},
			{"type": "block", "amount": 4, "glyphs": [11, 0]},
		],
	},
	"glass_golem": {
		"id": "glass_golem", "name": "Glass Golem", "art": "glass_golem",
		"max_hp": 68, "scale": 1.25,
		"lore": "Hollow. Something taps from inside.",
		"traits": ["brittle"],
		"intents": [
			{"type": "block", "amount": 9, "glyphs": [11, 13]},
			{"type": "attack", "amount": 11, "glyphs": [4, 13]},
			{"type": "attack", "amount": 7, "glyphs": [4]},
		],
	},
	# ---- expansion ------------------------------------------------------------
	"mire_leech": {
		"id": "mire_leech", "name": "Mire Leech", "art": "mire_leech",
		"max_hp": 28, "scale": 0.8,
		"lore": "It only wants what you were about to lose.",
		"traits": ["siphon"],
		"intents": [
			{"type": "attack", "amount": 3, "glyphs": [8, 12]},
			{"type": "attack", "amount": 4, "glyphs": [8, 12, 0]},
			{"type": "heal", "amount": 4, "glyphs": [8]},
		],
	},
	"ember_wisp": {
		"id": "ember_wisp", "name": "Ember Wisp", "art": "ember_wisp",
		"max_hp": 24, "scale": 0.75,
		"lore": "A small flame, holding a larger one's place.",
		"traits": [],
		"intents": [
			{"type": "attack", "amount": 2, "hits": 4, "glyphs": [7, 0]},
			{"type": "block", "amount": 3, "glyphs": [7]},
			{"type": "attack", "amount": 3, "hits": 3, "glyphs": [7, 0, 4]},
		],
	},
	"mirror_wraith": {
		"id": "mirror_wraith", "name": "Mirror Wraith", "art": "mirror_wraith",
		"max_hp": 44, "scale": 1.05,
		"lore": "It copies the hand you reach with.",
		"traits": ["thorns"],
		"intents": [
			{"type": "block", "amount": 6, "glyphs": [3, 11]},
			{"type": "attack", "amount": 9, "glyphs": [3, 11, 3]},
			{"type": "attack", "amount": 4, "hits": 2, "glyphs": [3]},
		],
	},
	"shard_hound": {
		"id": "shard_hound", "name": "Shard Hound", "art": "shard_hound",
		"max_hp": 40, "scale": 1.0,
		"lore": "It does not bark. The ground rings instead.",
		"traits": ["brittle"],
		"intents": [
			{"type": "attack", "amount": 3, "hits": 3, "glyphs": [9, 2]},
			{"type": "attack", "amount": 7, "glyphs": [9, 2, 5]},
			{"type": "block", "amount": 5, "glyphs": [9]},
			{"type": "attack", "amount": 4, "hits": 3, "glyphs": [9, 2, 13]},
		],
	},
	"prism_sentinel": {
		"id": "prism_sentinel", "name": "Prism Sentinel", "art": "prism_sentinel", "elite": true,
		"max_hp": 46, "scale": 1.4,
		"lore": "Every face of it is a different verdict.",
		"traits": ["brittle", "cascade"],
		"phases": [
			{"below": 1.0, "omen": "", "intents": [
				{"type": "block", "amount": 8, "glyphs": [11, 13, 9]},
				{"type": "attack", "amount": 8, "glyphs": [13, 9]},
				{"type": "attack", "amount": 4, "hits": 3, "glyphs": [9, 2]},
			]},
			{"below": 0.5, "omen": "It turns, and the light turns with it.", "intents": [
				{"type": "attack", "amount": 5, "hits": 3, "glyphs": [13, 9, 2]},
				{"type": "block", "amount": 10, "glyphs": [11, 13]},
				{"type": "attack", "amount": 12, "glyphs": [13, 9, 2, 4]},
			]},
		],
	},
	"root_tyrant": {
		"id": "root_tyrant", "name": "Root Tyrant", "art": "root_tyrant", "elite": true,
		"max_hp": 52, "scale": 1.5,
		"lore": "It was here before the ground was.",
		"traits": ["thorns", "splits", "summons"],
		"phases": [
			{"below": 1.0, "omen": "", "intents": [
				{"type": "attack", "amount": 6, "glyphs": [5, 6]},
				{"type": "heal", "amount": 4, "glyphs": [5, 12]},
				{"type": "attack", "amount": 8, "glyphs": [5, 6, 12]},
			]},
			{"below": 0.6, "omen": "The soil lifts, listening.", "intents": [
				{"type": "split", "amount": 0, "spawn": "spore_sprout", "glyphs": [5, 3]},
				{"type": "attack", "amount": 5, "hits": 2, "glyphs": [5, 6]},
				{"type": "block", "amount": 7, "glyphs": [5, 11]},
			]},
			{"below": 0.3, "omen": "Every root points at you.", "intents": [
				{"type": "attack", "amount": 4, "hits": 4, "glyphs": [5, 6, 6]},
				{"type": "split", "amount": 0, "spawn": "mire_leech", "glyphs": [5, 8]},
				{"type": "attack", "amount": 13, "glyphs": [5, 6, 12, 2]},
			]},
		],
	},
	"cascade_warden": {
		"id": "cascade_warden", "name": "The Cascade Warden", "art": "cascade_warden",
		"max_hp": 90, "scale": 1.7,
		"lore": "The water falls upward here. It keeps count.",
		"traits": ["cascade", "summons"],
		"phases": [
			{"below": 1.0, "omen": "", "intents": [
				{"type": "attack", "amount": 6, "glyphs": [8, 4]},
				{"type": "block", "amount": 8, "glyphs": [8, 11]},
				{"type": "attack", "amount": 8, "glyphs": [8, 4, 6]},
			]},
			{"below": 0.66, "omen": "The falls grow loud.", "intents": [
				{"type": "attack", "amount": 4, "hits": 3, "glyphs": [8, 12, 12]},
				{"type": "split", "amount": 0, "spawn": "spore_sprout", "glyphs": [8, 3]},
				{"type": "attack", "amount": 9, "glyphs": [8, 4, 6]},
			]},
			{"below": 0.33, "omen": "It stops counting. It begins to pour.", "intents": [
				{"type": "attack", "amount": 5, "hits": 3, "glyphs": [8, 12, 12]},
				{"type": "heal", "amount": 6, "glyphs": [8, 9]},
				{"type": "attack", "amount": 12, "glyphs": [8, 4, 6, 13]},
			]},
			{"below": 0.12, "omen": "The falls fold back on themselves.", "intents": [
				{"type": "split", "amount": 0, "spawn": "mirror_wraith", "glyphs": [8, 3, 11]},
				{"type": "attack", "amount": 7, "hits": 3, "glyphs": [8, 12, 12]},
				{"type": "attack", "amount": 15, "glyphs": [8, 4, 6, 13, 2]},
			]},
		],
	},
}

const POOL_EARLY: Array[String] = ["spore_sprout", "thorn_crawler", "mire_leech", "ember_wisp"]
const POOL_MID: Array[String] = ["spore_sprout", "thorn_crawler", "crystal_moth", "mire_leech", "ember_wisp", "shard_hound"]
const POOL_LATE: Array[String] = ["thorn_crawler", "crystal_moth", "glass_golem", "mirror_wraith", "shard_hound", "ember_wisp"]
## Elites: hidden traits, multi-phase. Rolled by floor_enemies from floor 5 (elite nodes
## run at floor+2) and directly via elite_enemies().
const ELITES: Array[String] = ["prism_sentinel", "root_tyrant"]


static func get_def(id: String) -> Dictionary:
	return ENEMIES.get(id, {})


static func all_ids() -> Array[String]:
	var out: Array[String] = []
	for k in ENEMIES.keys():
		out.append(String(k))
	return out


## Phase index for an hp fraction (highest phase whose threshold has been crossed).
static func phase_for(id: String, hp_frac: float) -> int:
	var phases: Array = get_def(id).get("phases", [])
	var idx := 0
	for i in range(1, phases.size()):
		var below: float = phases[i]["below"]
		if hp_frac < below:
			idx = i
	return idx


## Intent list for the enemy in a given phase (phase 0 when it has no phases).
static func intents_for(id: String, phase: int) -> Array:
	var d: Dictionary = get_def(id)
	if d.has("phases"):
		var phases: Array = d["phases"]
		return phases[clampi(phase, 0, phases.size() - 1)]["intents"]
	return d.get("intents", [])


## Encounter for a floor (1-based). Never returns the boss; see BOSS_ID.
static func floor_enemies(floor: int, rng: RandomNumberGenerator) -> Array[String]:
	var out: Array[String] = []
	var count := 1
	var pool: Array[String] = POOL_EARLY
	if floor >= 2:
		pool = POOL_MID
		count = 1 + (1 if rng.randf() < 0.45 else 0)
	if floor >= 4:
		pool = POOL_LATE if rng.randf() < 0.5 else POOL_MID
		count = 2 if rng.randf() < 0.7 else 1
	if floor >= 6:
		count = 2 + (1 if rng.randf() < 0.35 else 0)
	for i in range(mini(count, MAX_ENEMIES)):
		out.append(pool[rng.randi() % pool.size()])
	if floor >= 5 and rng.randf() < 0.3:
		out[0] = ELITES[rng.randi() % ELITES.size()]
	return out


static func is_elite(id: String) -> bool:
	return bool(get_def(id).get("elite", false))


## Elite encounter (an elite, plus a lesser escort from floor 4). Never the boss.
static func elite_enemies(floor: int, rng: RandomNumberGenerator) -> Array[String]:
	var out: Array[String] = [ELITES[rng.randi() % ELITES.size()]]
	if floor >= 4 and rng.randf() < 0.5:
		out.append(POOL_MID[rng.randi() % POOL_MID.size()])
	return out
