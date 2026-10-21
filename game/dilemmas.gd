class_name DilemmaDB
extends RefCounted
## Moral Dilemmas: the ONLY readable story text in the game. Short, moody, never explaining the world.
##
## Dilemma  = {id, title, text, choices: Array[{label, flavor, effects: Array[Dictionary]}]}
## Effect   = {"type": String, "amount": int, "id": String, ...}. Types the run layer must handle:
##   max_hp        amount (+/-)           change max HP (hp is clamped; a positive gain also heals that much)
##   hp            amount (+/-)           change current HP (never kills below 1 unless the run layer decides)
##   heal_all      (none)                 restore HP to full
##   gold          amount (+/-)           change gold (clamp at 0)
##   item          id ("" = random loot)  gain an item (place into pack; "rarity": int optional minimum rarity)
##   curse_item    id ("" = random owned) the item becomes cursed (run layer decides the malus; shown as a dark mark)
##   remove_item   id ("" = random owned) lose an owned item
##   shrink_pack   amount (cells/rows)    backpack loses `amount` rows/columns (run layer picks the edge)
##   grow_pack     amount                 backpack gains `amount` rows/columns
##   reveal_glyph  amount (words)         reveal `amount` unknown Lexicon words (Meta.mark_known on random unknown keys)
##   change_path   "mode": String         mutate the route map. modes: "wither" (remove a branch), "sprout" (add a fork),
##                                        "swap" (change a branch type), "reveal" (show hidden branch types),
##                                        "hide" (hide the types of the next branches). Optional "kind": branch type.
## A choice may carry several effects (the trade-off). Effects are plain data, applied by the run layer.

const DILEMMAS: Array[Dictionary] = [
	{
		"id": "rubicon_pool", "title": "The Crossing",
		"text": "A shallow river separates you from what you want. Something under it remembers the last crossing.",
		"choices": [
			{"label": "Wade across, uninvited.", "flavor": "The water takes a little. It keeps its receipt.",
				"effects": [{"type": "hp", "amount": -7}, {"type": "gold", "amount": 30}]},
			{"label": "Wait for the river to decide.", "flavor": "It does, eventually, and not in your favour.",
				"effects": [{"type": "change_path", "mode": "wither"}, {"type": "max_hp", "amount": 4}]},
		],
	},
	{
		"id": "ides_dagger", "title": "The Kindest Knife",
		"text": "A friend offers you a dagger, handle first. They are smiling the way a door smiles.",
		"choices": [
			{"label": "Take it.", "flavor": "Trust is also a weapon. It cuts the one who holds it.",
				"effects": [{"type": "item", "id": "thorn_dagger"}, {"type": "max_hp", "amount": -5}]},
			{"label": "Refuse, and watch their face.", "flavor": "Some answers you only get by declining the question.",
				"effects": [{"type": "reveal_glyph", "amount": 1}]},
			{"label": "Turn the blade on them.", "flavor": "A short, quiet argument. You win it.",
				"effects": [{"type": "gold", "amount": 45}, {"type": "curse_item", "id": ""}]},
		],
	},
	{
		"id": "crown_of_moss", "title": "The Weight of Crowns",
		"text": "A crown of living moss is sitting on a stone, being patient. It fits everyone.",
		"choices": [
			{"label": "Wear it.", "flavor": "You feel taller. The pack feels smaller.",
				"effects": [{"type": "max_hp", "amount": 12}, {"type": "shrink_pack", "amount": 1}]},
			{"label": "Leave it for someone who needs it more.", "flavor": "Nobody will. That is the joke.",
				"effects": [{"type": "hp", "amount": 6}]},
		],
	},
	{
		"id": "mercy_sprout", "title": "Clemency",
		"text": "A wounded thing begs in a language you almost understand. It has your face, a little.",
		"choices": [
			{"label": "Spare it.", "flavor": "It leaves a word behind, like a coin on a table.",
				"effects": [{"type": "reveal_glyph", "amount": 1}, {"type": "hp", "amount": -4}]},
			{"label": "End it.", "flavor": "Efficient. The garden notes the efficiency.",
				"effects": [{"type": "gold", "amount": 35}, {"type": "change_path", "mode": "hide"}]},
		],
	},
	{
		"id": "senate_of_one", "title": "The Many and the One",
		"text": "Nine small voices in a hollow argue for your gold. A tenth, very quiet, argues for your silence.",
		"choices": [
			{"label": "Feed the nine.", "flavor": "They thank you in unison. It sounds rehearsed.",
				"effects": [{"type": "gold", "amount": -40}, {"type": "heal_all"}]},
			{"label": "Listen to the tenth.", "flavor": "It says nothing, expensively.",
				"effects": [{"type": "reveal_glyph", "amount": 2}, {"type": "hp", "amount": -5}]},
			{"label": "Walk on, deaf.", "flavor": "Deafness is a choice too. It is cheap and it lasts.",
				"effects": []},
		],
	},
	{
		"id": "memory_tithe", "title": "A Tithe of Memory",
		"text": "The altar asks for something you have carried so long you forgot it was heavy.",
		"choices": [
			{"label": "Give it an item.", "flavor": "You will not remember what you gave. That is the mercy.",
				"effects": [{"type": "remove_item", "id": ""}, {"type": "max_hp", "amount": 10}]},
			{"label": "Give it a word.", "flavor": "You forget one thing you had learned. You feel lighter and stupider.",
				"effects": [{"type": "grow_pack", "amount": 1}, {"type": "hp", "amount": -6}]},
			{"label": "Give it nothing.", "flavor": "The altar writes your name down. Politely.",
				"effects": [{"type": "curse_item", "id": ""}]},
		],
	},
	{
		"id": "triumph_road", "title": "Triumph",
		"text": "A road of cheering shadows leads to a gate with your name freshly carved. The carving is still bleeding.",
		"choices": [
			{"label": "March through to applause.", "flavor": "Applause is a loan.",
				"effects": [{"type": "gold", "amount": 60}, {"type": "max_hp", "amount": -8}]},
			{"label": "Take the muddy path beside it.", "flavor": "Nobody cheers for mud. Mud is honest.",
				"effects": [{"type": "change_path", "mode": "reveal"}, {"type": "hp", "amount": -3}]},
		],
	},
	{
		"id": "lamp_of_brutus", "title": "The Honest Lamp",
		"text": "A lamp that only lights true things offers to light you. You have been avoiding this.",
		"choices": [
			{"label": "Stand in the light.", "flavor": "It finds something and keeps quiet about it.",
				"effects": [{"type": "reveal_glyph", "amount": 2}, {"type": "max_hp", "amount": -4}]},
			{"label": "Take the lamp, leave the light.", "flavor": "A lamp without its honesty is only a nice shape.",
				"effects": [{"type": "item", "id": "sun_shard"}, {"type": "curse_item", "id": ""}]},
		],
	},
	{
		"id": "bridge_of_seeds", "title": "Fertile Ground",
		"text": "Seeds in your palm, a patch of bare soil, an hour of daylight. One of these is a debt.",
		"choices": [
			{"label": "Plant them here.", "flavor": "The garden accepts your offer and adjusts its map.",
				"effects": [{"type": "change_path", "mode": "sprout"}, {"type": "gold", "amount": -20}]},
			{"label": "Keep them.", "flavor": "Seeds in a pocket are only a long way of saying maybe.",
				"effects": [{"type": "item", "id": "fractal_seed"}, {"type": "hp", "amount": -6}]},
		],
	},
	{
		"id": "mirror_toll", "title": "The Second Self",
		"text": "A pool shows you, slightly better dressed. It offers to swap, and does not say with whom.",
		"choices": [
			{"label": "Swap places.", "flavor": "Everything fits a little differently now.",
				"effects": [{"type": "change_path", "mode": "swap"}, {"type": "max_hp", "amount": 8}]},
			{"label": "Break the surface.", "flavor": "Seven years of something. Not luck.",
				"effects": [{"type": "hp", "amount": -8}, {"type": "reveal_glyph", "amount": 1}]},
		],
	},
	{
		"id": "feast_of_ash", "title": "Bread and Circuses",
		"text": "A long table is laid for guests who are all you. Only one chair is warm.",
		"choices": [
			{"label": "Eat well.", "flavor": "The feast was real. So is the bill.",
				"effects": [{"type": "heal_all"}, {"type": "gold", "amount": -30}]},
			{"label": "Pocket the silverware.", "flavor": "The silverware was also you.",
				"effects": [{"type": "gold", "amount": 40}, {"type": "hp", "amount": -6}]},
			{"label": "Sit in the empty chair.", "flavor": "It was not empty. It is now.",
				"effects": [{"type": "item", "id": ""}, {"type": "max_hp", "amount": -6}]},
		],
	},
	{
		"id": "stone_that_counts", "title": "Arithmetic",
		"text": "A stone counts your steps aloud and is always slightly wrong. It says it has a better number for you.",
		"choices": [
			{"label": "Buy the number.", "flavor": "Seven. It was always going to be seven.",
				"effects": [{"type": "gold", "amount": -35}, {"type": "grow_pack", "amount": 1}]},
			{"label": "Correct the stone.", "flavor": "It is pleased to be wrong at you.",
				"effects": [{"type": "reveal_glyph", "amount": 1}, {"type": "hp", "amount": -3}]},
		],
	},
	{
		"id": "fallen_standard", "title": "The Fallen Standard",
		"text": "A banner, still upright, stuck into a fight that ended long ago. Whoever it was for is no longer a question.",
		"choices": [
			{"label": "Carry it onward.", "flavor": "It is heavier than the cause was.",
				"effects": [{"type": "max_hp", "amount": 6}, {"type": "shrink_pack", "amount": 1}]},
			{"label": "Bury it properly.", "flavor": "A small silence follows you for a while.",
				"effects": [{"type": "heal_all"}, {"type": "gold", "amount": -15}]},
			{"label": "Take the cloth only.", "flavor": "Even flags have lining.",
				"effects": [{"type": "gold", "amount": 25}]},
		],
	},
	{
		"id": "vow_in_the_roots", "title": "Roots Remember",
		"text": "The roots have a ledger of every promise made above them. Yours is on the first page, in a handwriting you refuse.",
		"choices": [
			{"label": "Honour it.", "flavor": "The ledger closes, almost gently.",
				"effects": [{"type": "hp", "amount": -9}, {"type": "reveal_glyph", "amount": 1}, {"type": "max_hp", "amount": 5}]},
			{"label": "Tear the page.", "flavor": "The page was load-bearing.",
				"effects": [{"type": "change_path", "mode": "wither"}, {"type": "gold", "amount": 40}]},
		],
	},
	{
		"id": "waterfall_echo", "title": "What the Falls Say",
		"text": "Far ahead, water is speaking your name backwards. You could ask it to say it forwards.",
		"choices": [
			{"label": "Ask.", "flavor": "The map shifts toward the sound.",
				"effects": [{"type": "change_path", "mode": "reveal"}, {"type": "max_hp", "amount": -5}]},
			{"label": "Do not ask.", "flavor": "Ignorance is a kind of armour. It is not a good one.",
				"effects": [{"type": "hp", "amount": 5}]},
		],
	},
]

static func get_def(id: String) -> Dictionary:
	for d: Dictionary in DILEMMAS:
		if d["id"] == id:
			return d
	return {}

static func all_ids() -> Array[String]:
	var out: Array[String] = []
	for d: Dictionary in DILEMMAS:
		out.append(d["id"])
	return out

## Picks a dilemma not yet in context["seen"] (an Array the caller keeps for the run; roll() appends to it).
## context keys (all optional): "seen": Array[String]; "hp_ratio": float (0..1) - when low, trade-offs that
## cost HP are down-weighted; "pack_full": bool - when true, grow_pack/item dilemmas are favoured.
## When every dilemma was seen, the seen list is cleared and the pool restarts.
static func roll(rng: RandomNumberGenerator, context: Dictionary = {}) -> Dictionary:
	var seen: Array = context.get("seen", [])
	var pool: Array[Dictionary] = []
	for d: Dictionary in DILEMMAS:
		if not seen.has(d["id"]):
			pool.append(d)
	if pool.is_empty():
		seen.clear()
		pool = DILEMMAS.duplicate()
	var weights: Array[float] = []
	var total: float = 0.0
	for d: Dictionary in pool:
		var wt: float = _weight(d, context)
		weights.append(wt)
		total += wt
	var pick: float = rng.randf() * total
	var chosen: Dictionary = pool[pool.size() - 1]
	for i: int in pool.size():
		pick -= weights[i]
		if pick <= 0.0:
			chosen = pool[i]
			break
	seen.append(chosen["id"])
	if context.has("seen"):
		context["seen"] = seen
	return chosen.duplicate(true)

static func _weight(d: Dictionary, context: Dictionary) -> float:
	var wt: float = 1.0
	var hp_ratio: float = float(context.get("hp_ratio", 1.0))
	var pack_full: bool = bool(context.get("pack_full", false))
	for c: Dictionary in d["choices"]:
		for e: Dictionary in c["effects"]:
			var t: String = e["type"]
			if hp_ratio < 0.4 and (t == "hp" or t == "max_hp") and int(e.get("amount", 0)) < 0:
				wt -= 0.1
			if pack_full and (t == "grow_pack" or t == "remove_item"):
				wt += 0.15
	return maxf(wt, 0.2)
