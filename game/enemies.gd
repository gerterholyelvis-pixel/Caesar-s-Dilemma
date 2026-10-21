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
		"max_hp": 18, "scale": 1.0,
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
		"max_hp": 24, "scale": 1.0,
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
		"max_hp": 16, "scale": 0.85,
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
		"max_hp": 34, "scale": 1.25,
		"lore": "Hollow. Something taps from inside.",
		"traits": ["brittle"],
		"intents": [
			{"type": "block", "amount": 9, "glyphs": [11, 13]},
			{"type": "attack", "amount": 11, "glyphs": [4, 13]},
			{"type": "attack", "amount": 7, "glyphs": [4]},
		],
	},
	"cascade_warden": {
		"id": "cascade_warden", "name": "The Cascade Warden", "art": "cascade_warden",
		"max_hp": 60, "scale": 1.7,
		"lore": "The water falls upward here. It keeps count.",
		"traits": ["cascade", "summons"],
		"phases": [
			{"below": 1.0, "omen": "", "intents": [
				{"type": "attack", "amount": 8, "glyphs": [8, 4]},
				{"type": "block", "amount": 8, "glyphs": [8, 11]},
				{"type": "attack", "amount": 10, "glyphs": [8, 4, 6]},
			]},
			{"below": 0.66, "omen": "The falls grow loud.", "intents": [
				{"type": "attack", "amount": 5, "hits": 3, "glyphs": [8, 12, 12]},
				{"type": "split", "amount": 0, "spawn": "spore_sprout", "glyphs": [8, 3]},
				{"type": "attack", "amount": 12, "glyphs": [8, 4, 6]},
			]},
			{"below": 0.33, "omen": "It stops counting. It begins to pour.", "intents": [
				{"type": "attack", "amount": 7, "hits": 3, "glyphs": [8, 12, 12]},
				{"type": "heal", "amount": 6, "glyphs": [8, 9]},
				{"type": "attack", "amount": 16, "glyphs": [8, 4, 6, 13]},
			]},
		],
	},
}

const POOL_EARLY: Array[String] = ["spore_sprout", "thorn_crawler"]
const POOL_MID: Array[String] = ["spore_sprout", "thorn_crawler", "crystal_moth"]
const POOL_LATE: Array[String] = ["thorn_crawler", "crystal_moth", "glass_golem"]


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
	return out
