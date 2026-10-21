class_name ItemDB
extends RefCounted
## Item definitions and shape helpers. Pure data/logic, no scene code.
##
## Secrets (def key "secrets") share the synergy shape plus "id" and "text":
##   {id, with_tag | with_id | when_alone, bonus:{amount, hits}, text}
## They are ALWAYS active in play; discovery (ItemDB.discovered) only changes
## what tooltips show. Meta fills `discovered` with "item_id:secret_id" -> true.
## Bonus "amount" modifies the effect amount (per hit / per adjacent item).

const GLYPH_COUNT := 14
const RARITY_WEIGHT := {1: 60.0, 2: 30.0, 3: 10.0}

## Filled by Meta (permanent). Keys: "item_id:secret_id".
static var discovered: Dictionary = {}
## Optional override: Callable(item_id: String, secret_id: String) -> bool.
static var discovered_check: Callable = Callable()

const ITEMS: Dictionary = {
	"bone_blade": {
		"id": "bone_blade", "name": "Bone Blade", "glyphs": [3, 7, 1],
		"shape": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)],
		"cost": 1, "kind": "active", "tags": ["weapon", "bladed", "bone"],
		"effect": {"type": "damage", "amount": 5},
		"synergies": [],
		"secrets": [{"id": "marrow", "with_tag": "living", "bonus": {"amount": 2},
				"text": "Hungers beside living things: +2 damage each."},
			{"id": "twin", "with_id": "bone_blade", "bonus": {"amount": 3},
				"text": "Beside its twin it cuts deeper: +3 damage."}],
		"rarity": 1, "desc": "A rib that remembers being a spine.", "consumable": false,
	},
	"shard_axe": {
		"id": "shard_axe", "name": "Shard Axe", "glyphs": [9, 2, 11, 5],
		"shape": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)],
		"cost": 2, "kind": "active", "tags": ["weapon", "bladed", "crystal"],
		"effect": {"type": "damage", "amount": 14},
		"synergies": [],
		"secrets": [{"id": "resonance", "with_tag": "crystal", "bonus": {"amount": 3},
			"text": "Rings against other crystal: +3 damage each."}],
		"rarity": 2, "desc": "Cut from a wall that was still growing.", "consumable": false,
	},
	"thorn_dagger": {
		"id": "thorn_dagger", "name": "Thorn Dagger", "glyphs": [6, 0, 12],
		"shape": [Vector2i(0, 0), Vector2i(0, 1)],
		"cost": 1, "kind": "active", "tags": ["weapon", "bladed", "plant"],
		"effect": {"type": "multi_damage", "amount": 3, "hits": 2},
		"synergies": [{"with_tag": "plant", "bonus": {"amount": 1}}],
		"secrets": [{"id": "venom", "with_id": "spore_flask", "bonus": {"hits": 1},
			"text": "Drinks from spore flasks: +1 hit."}],
		"rarity": 1, "desc": "Two quick pricks.", "consumable": false,
	},
	"crystal_bow": {
		"id": "crystal_bow", "name": "Crystal Bow", "glyphs": [4, 13, 8, 2],
		"shape": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)],
		"cost": 1, "kind": "active", "tags": ["weapon", "ranged", "crystal"],
		"effect": {"type": "damage", "amount": 7},
		"synergies": [{"with_tag": "quiver", "bonus": {"amount": 2}}],
		"secrets": [{"id": "prism", "with_id": "sun_shard", "bonus": {"amount": 4},
				"text": "Light bent through a sun shard: +4 damage."},
			{"id": "second_string", "with_id": "crystal_bow", "bonus": {"amount": 3},
				"text": "A second bow hums the same note: +3 damage."}],
		"rarity": 2, "desc": "The string is a held note.", "consumable": false,
	},
	"lapis_shield": {
		"id": "lapis_shield", "name": "Lapis Shield", "glyphs": [10, 1, 6, 9, 3],
		"shape": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
		"cost": 1, "kind": "active", "tags": ["armor", "crystal"],
		"effect": {"type": "block", "amount": 8},
		"synergies": [{"with_tag": "armor", "bonus": {"amount": 2}}],
		"secrets": [
			{"id": "bastion", "when_alone": true, "bonus": {"amount": 4},
				"text": "Stands taller untouched: +4 block with no neighbours."},
			{"id": "mirror", "with_id": "glyph_lens", "bonus": {"amount": 3},
				"text": "Sees itself in the lens: +3 block."},
		],
		"rarity": 2, "desc": "Cold, blue, and very sure of itself.", "consumable": false,
	},
	"reed_buckler": {
		"id": "reed_buckler", "name": "Reed Buckler", "glyphs": [12, 5, 0],
		"shape": [Vector2i(0, 0), Vector2i(1, 0)],
		"cost": 1, "kind": "active", "tags": ["armor", "plant", "water"],
		"effect": {"type": "block", "amount": 4},
		"synergies": [{"with_tag": "armor", "bonus": {"amount": 1}}],
		"secrets": [{"id": "tide", "with_tag": "water", "bonus": {"amount": 2},
			"text": "Swells beside water: +2 block each."}],
		"rarity": 1, "desc": "Woven where the river forgot to leave.", "consumable": false,
	},
	"whetstone": {
		"id": "whetstone", "name": "Whetstone", "glyphs": [7, 11, 3],
		"shape": [Vector2i(0, 0)],
		"cost": 0, "kind": "passive", "tags": ["tool", "whetstone"],
		"effect": {"type": "none", "amount": 0},
		"boost_tag": "bladed", "boost_amount": 2,
		"synergies": [], "secrets": [],
		"rarity": 1, "desc": "Adjacent bladed items deal +2.", "consumable": false,
	},
	"quiver": {
		"id": "quiver", "name": "Quiver", "glyphs": [1, 8, 13],
		"shape": [Vector2i(0, 0)],
		"cost": 0, "kind": "passive", "tags": ["tool", "quiver"],
		"effect": {"type": "none", "amount": 0},
		"boost_tag": "ranged", "boost_amount": 2,
		"synergies": [], "secrets": [],
		"rarity": 1, "desc": "Adjacent ranged items deal +2.", "consumable": false,
	},
	"spore_flask": {
		"id": "spore_flask", "name": "Spore Flask", "glyphs": [0, 6, 10, 4],
		"shape": [Vector2i(0, 0)],
		"cost": 1, "kind": "active", "tags": ["potion", "plant", "living"],
		"effect": {"type": "heal", "amount": 6},
		"synergies": [],
		"secrets": [{"id": "bloom", "with_id": "healing_bloom", "bonus": {"amount": 3},
			"text": "Wakes sleeping blooms: +3 healing."}],
		"rarity": 1, "desc": "Drink once. Something drinks back.", "consumable": true,
	},
	"healing_bloom": {
		"id": "healing_bloom", "name": "Healing Bloom", "glyphs": [5, 12, 2],
		"shape": [Vector2i(0, 0), Vector2i(0, 1)],
		"cost": 1, "kind": "active", "tags": ["plant", "living", "bloom"],
		"effect": {"type": "heal", "amount": 2},
		"synergies": [{"with_tag": "water", "bonus": {"amount": 2}}],
		"secrets": [{"id": "sunlit", "with_id": "sun_shard", "bonus": {"amount": 3},
			"text": "Turns to a sun shard: +3 healing."}],
		"rarity": 2, "desc": "It opens when you are not looking.", "consumable": false,
	},
	"sun_shard": {
		"id": "sun_shard", "name": "Sun Shard", "glyphs": [13, 9, 1, 7],
		"shape": [Vector2i(0, 0)],
		"cost": 0, "kind": "active", "tags": ["crystal", "light"],
		"effect": {"type": "energy", "amount": 1},
		"synergies": [],
		"secrets": [{"id": "radiance", "with_id": "fractal_seed", "bonus": {"amount": 1},
			"text": "Feeds the seed and is fed back: +1 energy."}],
		"rarity": 3, "desc": "Crack it for a little noon.", "consumable": true,
	},
	"moss_charm": {
		"id": "moss_charm", "name": "Moss Charm", "glyphs": [8, 4, 11],
		"shape": [Vector2i(0, 0)],
		"cost": 0, "kind": "passive", "tags": ["plant", "charm", "living"],
		"effect": {"type": "turn_start_block_per_adjacent", "amount": 1},
		"synergies": [],
		"secrets": [{"id": "hush", "with_tag": "bloom", "bonus": {"amount": 1},
			"text": "Blooms whisper to it: +1 block per adjacent bloom."}],
		"rarity": 1, "desc": "At turn start, gain 1 block per adjacent item.", "consumable": false,
	},
	"fractal_seed": {
		"id": "fractal_seed", "name": "Fractal Seed", "glyphs": [2, 10, 13, 5, 8],
		"shape": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
		"cost": 2, "kind": "active", "tags": ["fractal", "plant", "living"],
		"effect": {"type": "damage_per_adjacent", "amount": 4},
		"synergies": [],
		"secrets": [
			{"id": "recursion", "with_id": "fractal_seed", "bonus": {"amount": 2},
				"text": "Another seed beside it: +2 damage per adjacent item."},
			{"id": "facets", "with_tag": "crystal", "bonus": {"amount": 1},
				"text": "Crystal gives it edges: +1 damage per crystal."},
		],
		"rarity": 3, "desc": "Deal damage for each adjacent item. It grows with the pack.", "consumable": false,
	},
	"glyph_lens": {
		"id": "glyph_lens", "name": "Glyph Lens", "glyphs": [11, 3, 9],
		"shape": [Vector2i(0, 0)],
		"cost": 0, "kind": "passive", "tags": ["tool", "light", "lens"],
		"effect": {"type": "identify", "amount": 1},
		"synergies": [], "secrets": [],
		"rarity": 2, "desc": "Items beside it reveal their names.", "consumable": false,
	},
	# ---- expansion: adjacency / tag-diversity / shape / risk items --------------
	"prism_lattice": {
		"id": "prism_lattice", "name": "Prism Lattice", "glyphs": [9, 13, 2, 11, 6],
		"shape": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)],
		"cost": 2, "kind": "active", "tags": ["crystal", "fractal", "light"],
		"effect": {"type": "damage_per_adjacent", "amount": 2},
		"synergies": [],
		"secrets": [
			{"id": "facet_crystal", "with_tag": "crystal", "bonus": {"amount": 1},
				"text": "Each crystal beside it adds an edge: +1 damage per crystal."},
			{"id": "facet_light", "with_tag": "light", "bonus": {"amount": 1},
				"text": "Light folds through every face: +1 damage per light."},
			{"id": "facet_fractal", "with_tag": "fractal", "bonus": {"amount": 2},
				"text": "It recognises its own pattern: +2 damage per fractal."},
		],
		"rarity": 3, "desc": "A cross of glass. Each arm holds a smaller cross.", "consumable": false,
	},
	"mirror_shard": {
		"id": "mirror_shard", "name": "Mirror Shard", "glyphs": [3, 11, 3],
		"shape": [Vector2i(0, 0)],
		"cost": 0, "kind": "active", "tags": ["crystal", "mirror"],
		"effect": {"type": "block", "amount": 1},
		"synergies": [{"with_tag": "mirror", "bonus": {"amount": 2}}],
		"secrets": [
			{"id": "twin", "with_id": "mirror_shard", "bonus": {"amount": 3},
				"text": "Faces its twin: +3 block."},
			{"id": "reflected_plate", "with_id": "lapis_shield", "bonus": {"amount": 2},
				"text": "Doubles a lapis shield's blue: +2 block."},
		],
		"rarity": 1, "desc": "A face that is not yours, looking back.", "consumable": false,
	},
	"ember_censer": {
		"id": "ember_censer", "name": "Ember Censer", "glyphs": [7, 0, 12, 4],
		"shape": [Vector2i(0, 0), Vector2i(1, 0)],
		"cost": 1, "kind": "active", "tags": ["fire", "tool", "censer"],
		"effect": {"type": "multi_damage", "amount": 2, "hits": 3},
		"synergies": [],
		"secrets": [
			{"id": "steam", "with_tag": "water", "bonus": {"amount": 2},
				"text": "Hisses beside water: +2 damage per hit."},
			{"id": "kindling", "with_tag": "plant", "bonus": {"hits": 1},
				"text": "Plants feed the coals: +1 hit each."},
		],
		"rarity": 2, "desc": "Smoke that writes in a hand you almost know.", "consumable": false,
	},
	"void_lantern": {
		"id": "void_lantern", "name": "Void Lantern", "glyphs": [13, 5, 13],
		"shape": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)],
		"cost": 0, "kind": "active", "tags": ["light", "void", "lantern"],
		"effect": {"type": "energy", "amount": 2},
		"synergies": [],
		"secrets": [
			{"id": "dark_oil", "when_alone": true, "bonus": {"amount": 2},
				"text": "Burns brightest in the dark: +2 energy with no neighbours."},
			{"id": "borrowed_noon", "with_id": "sun_shard", "bonus": {"amount": 1},
				"text": "Eats a sun shard's light and gives it back: +1 energy."},
		],
		"rarity": 3, "desc": "It shines inward.", "consumable": true,
	},
	"tide_flute": {
		"id": "tide_flute", "name": "Tide Flute", "glyphs": [8, 12, 1],
		"shape": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
		"cost": 1, "kind": "active", "tags": ["water", "instrument", "bone"],
		"effect": {"type": "heal", "amount": 2},
		"synergies": [{"with_tag": "water", "bonus": {"amount": 2}}],
		"secrets": [
			{"id": "overtone", "with_tag": "crystal", "bonus": {"amount": 2},
				"text": "Crystal sings the second note: +2 healing each."},
			{"id": "lullaby", "with_id": "healing_bloom", "bonus": {"amount": 3},
				"text": "Blooms open to the tune: +3 healing."},
		],
		"rarity": 2, "desc": "Played with the breath of a river.", "consumable": false,
	},
	"oath_stone": {
		"id": "oath_stone", "name": "Oath Stone", "glyphs": [4, 10, 7],
		"shape": [Vector2i(0, 0), Vector2i(0, 1)],
		"cost": 0, "kind": "passive", "tags": ["tool", "stone"],
		"effect": {"type": "none", "amount": 0},
		"boost_tag": "weapon", "boost_amount": 2,
		"synergies": [], "secrets": [],
		"rarity": 1, "desc": "Adjacent weapons deal +2. It has made worse promises.", "consumable": false,
	},
	"cursed_crown": {
		"id": "cursed_crown", "name": "Cursed Crown", "glyphs": [11, 6, 2, 9, 0],
		"shape": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(2, 1)],
		"cost": 3, "kind": "active", "tags": ["cursed", "crown", "weapon"],
		"effect": {"type": "damage", "amount": 20},
		"synergies": [],
		"secrets": [
			{"id": "sole_ruler", "when_alone": true, "bonus": {"amount": 8},
				"text": "A crown alone rules: +8 damage with no neighbours."},
			{"id": "court", "with_tag": "cursed", "bonus": {"amount": 4},
				"text": "The cursed kneel to it: +4 damage each."},
		],
		"rarity": 3, "desc": "Wearing it costs your whole turn. It always has.", "consumable": false,
	},
	"hungry_maw": {
		"id": "hungry_maw", "name": "Hungry Maw", "glyphs": [1, 12, 6, 3],
		"shape": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)],
		"cost": 2, "kind": "active", "tags": ["living", "bone", "cursed"],
		"effect": {"type": "damage_per_adjacent", "amount": 2},
		"synergies": [],
		"secrets": [
			{"id": "gnaw", "with_tag": "bone", "bonus": {"amount": 1},
					"text": "Gnaws bone: +1 damage per bone."},
			{"id": "swallow", "with_tag": "living", "bonus": {"amount": 1},
				"text": "Swallows the living: +1 damage per living neighbour."},
		],
		"rarity": 2, "desc": "A mouth that closes around whatever sits in it.", "consumable": false,
	},
	"echo_bell": {
		"id": "echo_bell", "name": "Echo Bell", "glyphs": [10, 2, 10],
		"shape": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],
		"cost": 1, "kind": "active", "tags": ["echo", "crystal", "bell"],
		"effect": {"type": "damage", "amount": 2},
		"synergies": [{"with_tag": "weapon", "bonus": {"amount": 3}}],
		"secrets": [
			{"id": "second_ring", "with_tag": "echo", "bonus": {"amount": 3},
				"text": "Answers another echo: +3 damage."},
			{"id": "struck_axe", "with_id": "shard_axe", "bonus": {"amount": 2},
				"text": "Rings with the axe's edge: +2 damage."},
		],
		"rarity": 2, "desc": "It repeats the loudest thing beside it, a little late.", "consumable": false,
	},
	"spiral_shell": {
		"id": "spiral_shell", "name": "Spiral Shell", "glyphs": [5, 8, 13, 4],
		"shape": [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)],
		"cost": 1, "kind": "active", "tags": ["fractal", "water", "armor"],
		"effect": {"type": "block", "amount": 6},
		"synergies": [{"with_tag": "fractal", "bonus": {"amount": 2}}],
		"secrets": [
			{"id": "recurse", "with_id": "fractal_seed", "bonus": {"amount": 4},
				"text": "Curls around a fractal seed: +4 block."},
			{"id": "deep_hum", "with_tag": "water", "bonus": {"amount": 1},
				"text": "Remembers the sea: +1 block per water."},
		],
		"rarity": 2, "desc": "Each turn of it is a smaller turn of itself.", "consumable": false,
	},
	"hollow_idol": {
		"id": "hollow_idol", "name": "Hollow Idol", "glyphs": [6, 0, 9],
		"shape": [Vector2i(0, 0), Vector2i(0, 1)],
		"cost": 0, "kind": "passive", "tags": ["charm", "idol", "cursed"],
		"effect": {"type": "turn_start_block_per_adjacent", "amount": 1},
		"synergies": [],
		"secrets": [{"id": "pact", "with_tag": "cursed", "bonus": {"amount": 1},
			"text": "Bargains with cursed things: +1 block per adjacent cursed item."}],
		"rarity": 2, "desc": "At turn start, gain 1 block per adjacent item. Nobody remembers who is inside.", "consumable": false,
	},
	"grafted_heart": {
		"id": "grafted_heart", "name": "Grafted Heart", "glyphs": [2, 12, 5, 12],
		"shape": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)],
		"cost": 1, "kind": "active", "tags": ["living", "cursed", "heart"],
		"effect": {"type": "heal", "amount": 12},
		"synergies": [],
		"secrets": [
			{"id": "second_beat", "with_tag": "cursed", "bonus": {"amount": 4},
				"text": "Beats faster beside curses: +4 healing each."},
			{"id": "rooted", "with_tag": "plant", "bonus": {"amount": 2},
				"text": "Takes root in plants: +2 healing each."},
		],
		"rarity": 3, "desc": "It was someone's. It is yours now, and it knows.", "consumable": true,
	},
}

static func get_def(id: String) -> Dictionary:
	return ITEMS.get(id, {})

static func all_ids() -> Array[String]:
	var out: Array[String] = []
	for k in ITEMS.keys():
		out.append(String(k))
	return out

static func has_tag(id: String, tag: String) -> bool:
	var tags: Array = get_def(id).get("tags", [])
	return tags.has(tag)

# --- secrets -------------------------------------------------------------

static func is_discovered(item_id: String, secret_id: String) -> bool:
	if discovered_check.is_valid():
		return bool(discovered_check.call(item_id, secret_id))
	return discovered.has(item_id + ":" + secret_id)

static func mark_discovered(item_id: String, secret_id: String) -> void:
	discovered[item_id + ":" + secret_id] = true

static func secrets_of(id: String) -> Array:
	return get_def(id).get("secrets", [])

static func has_undiscovered_secrets(id: String) -> bool:
	for s in secrets_of(id):
		var sd: Dictionary = s
		if not is_discovered(id, String(sd.get("id", ""))):
			return true
	return false

# --- shapes --------------------------------------------------------------

## Rotate clockwise by rot * 90 degrees (y axis points down), then normalise
## so min x = min y = 0. Result is sorted by (y, x) for stable comparisons.
static func shape_rotated(id_or_cells, rot: int) -> Array[Vector2i]:
	var cells: Array = []
	if id_or_cells is String or id_or_cells is StringName:
		cells = get_def(String(id_or_cells)).get("shape", [])
	else:
		cells = id_or_cells
	var out: Array[Vector2i] = []
	var r: int = posmod(rot, 4)
	for c in cells:
		var v: Vector2i = c
		for i in r:
			v = Vector2i(-v.y, v.x)
		out.append(v)
	if out.is_empty():
		return out
	var min_x: int = out[0].x
	var min_y: int = out[0].y
	for v in out:
		min_x = mini(min_x, v.x)
		min_y = mini(min_y, v.y)
	for i in out.size():
		out[i] -= Vector2i(min_x, min_y)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return out

static func shape_size(id_or_cells, rot: int) -> Vector2i:
	var mx := 0
	var my := 0
	for v in shape_rotated(id_or_cells, rot):
		mx = maxi(mx, v.x)
		my = maxi(my, v.y)
	return Vector2i(mx + 1, my + 1)

# --- loot ----------------------------------------------------------------

## Distinct ids, weighted by rarity. rarity_bias > 0 favours rarer items
## (weight multiplied by 1 + bias * (rarity - 1)); negative favours commons.
static func roll_loot(rng: RandomNumberGenerator, count: int, rarity_bias := 0.0) -> Array[String]:
	var pool: Array[String] = all_ids()
	pool.sort()
	var out: Array[String] = []
	while out.size() < count and not pool.is_empty():
		var weights: Array[float] = []
		var total := 0.0
		for id in pool:
			var r: int = int(get_def(id).get("rarity", 1))
			var wgt: float = float(RARITY_WEIGHT.get(r, 10.0)) * maxf(0.05, 1.0 + rarity_bias * float(r - 1))
			weights.append(wgt)
			total += wgt
		var pick: float = rng.randf() * total
		var idx := pool.size() - 1
		for i in pool.size():
			pick -= weights[i]
			if pick < 0.0:
				idx = i
				break
		out.append(pool[idx])
		pool.remove_at(idx)
	return out
