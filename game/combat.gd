class_name Combat
extends RefCounted
## Turn-based battle logic. No UI. The UI listens to the signals and reads the public state.
## Mystery hooks: secret_found / enemy_trait_revealed fire once per Combat instance, the first
## time a hidden thing happens. The caller persists them (Meta) and decides what to show.

signal log_line(text: String)
signal changed
signal item_used(uid: int)
signal damage_dealt(target: String, amount: int, index: int)  # target = enemy id or "player" (index -1)
signal ended(won: bool)
signal secret_found(item_id: String, secret_id: String)
signal enemy_trait_revealed(enemy_id: String, trait_name: String)

const DEFAULT_MAX_ENERGY := 3
const SPLIT_SCALE := 0.7

var backpack  # a Backpack (duck-typed so tests can pass a fake)
var player: Dictionary = {}
var enemies: Array[Dictionary] = []
var turn := 1
var used: Array[int] = []
var used_consumables: Array[int] = []
var won := false
## Overridable item-definition lookup (id -> Dictionary). Defaults to ItemDB.get_def.
var def_provider: Callable = Callable()

var _rng: RandomNumberGenerator
var _over := false
var _power := 1.0
var _found_secrets: Dictionary = {}
var _revealed_traits: Dictionary = {}


func start(bp, enemy_ids: Array, player_state: Dictionary, rng: RandomNumberGenerator) -> void:
	backpack = bp
	_rng = rng
	var max_hp: int = int(player_state.get("max_hp", 40))
	player = {
		"hp": int(player_state.get("hp", max_hp)),
		"max_hp": max_hp,
		"block": 0,
		"max_energy": int(player_state.get("max_energy", DEFAULT_MAX_ENERGY)),
		"energy": 0,
	}
	player["energy"] = player["max_energy"]
	var floor_n: int = int(player_state.get("floor", 1))
	_power = 1.0 + 0.08 * float(maxi(floor_n - 1, 0))
	enemies.clear()
	for id in enemy_ids:
		if enemies.size() < EnemyDB.MAX_ENEMIES:
			enemies.append(_make_enemy(String(id), 1.0, 1.0))
	turn = 1
	used.clear()
	used_consumables.clear()
	won = false
	_over = false
	_found_secrets.clear()
	_revealed_traits.clear()
	_trigger_passives()
	log_line.emit("Something stirs.")
	changed.emit()


func is_over() -> bool:
	return _over


func can_use(uid: int) -> bool:
	if _over or backpack == null:
		return false
	var def: Dictionary = _def_of(uid)
	if def.is_empty() or String(def.get("kind", "")) != "active":
		return false
	if uid in used:
		return false
	if bool(def.get("consumable", false)) and uid in used_consumables:
		return false
	return int(player["energy"]) >= int(def.get("cost", 0))


func use(uid: int, target := 0) -> void:
	if not can_use(uid):
		return
	var def: Dictionary = _def_of(uid)
	player["energy"] = int(player["energy"]) - int(def.get("cost", 0))
	used.append(uid)
	if bool(def.get("consumable", false)):
		used_consumables.append(uid)
	var eff: Dictionary = backpack.effective_effect(uid)
	_check_secrets(uid)
	_apply_effect(uid, eff, target)
	item_used.emit(uid)
	_check_end()
	changed.emit()


func end_turn() -> void:
	if _over:
		return
	var count := enemies.size()  # enemies spawned this turn wait for the next one
	for i in range(count):
		if _over:
			break
		if bool(enemies[i]["alive"]):
			_enemy_act(i)
	if _over:
		changed.emit()
		return
	_check_end()
	if _over:
		changed.emit()
		return
	turn += 1
	used.clear()
	player["block"] = 0
	player["energy"] = player["max_energy"]
	_trigger_passives()
	log_line.emit("Turn %d." % turn)
	changed.emit()


# ---------------------------------------------------------------- items

func _def_of(uid: int) -> Dictionary:
	var e: Dictionary = backpack.entry(uid)
	if e.is_empty():
		return {}
	return _def(String(e["id"]))


func _def(id: String) -> Dictionary:
	if not def_provider.is_valid():
		var script: Variant = load("res://game/items.gd")
		def_provider = Callable(script, "get_def")
	return def_provider.call(id)


func _apply_effect(uid: int, eff: Dictionary, target: int) -> void:
	var amount: int = int(eff.get("amount", 0))
	var name := String(_def_of(uid).get("name", "item"))
	match String(eff.get("type", "")):
		"damage":
			_hit_target(target, amount, 0)
		"multi_damage":
			for h in range(maxi(int(eff.get("hits", 1)), 1)):
				_hit_target(target, amount, h)
		"damage_per_adjacent":
			_hit_target(target, amount * backpack.neighbors(uid).size(), 0)
		"block":
			player["block"] = int(player["block"]) + amount
			log_line.emit("%s: +%d block." % [name, amount])
		"heal":
			player["hp"] = mini(int(player["hp"]) + amount, int(player["max_hp"]))
			log_line.emit("%s mends %d." % [name, amount])
		"energy":
			player["energy"] = int(player["energy"]) + amount
			log_line.emit("%s hums: +%d energy." % [name, amount])
		"identify":
			log_line.emit("The glyphs lean closer.")
		_:
			pass


func _trigger_passives() -> void:
	for entry in backpack.placed:
		var uid: int = int(entry["uid"])
		var def: Dictionary = _def(String(entry["id"]))
		if String(def.get("kind", "")) != "passive":
			continue
		var eff: Dictionary = backpack.effective_effect(uid)
		if String(eff.get("type", "")) != "turn_start_block_per_adjacent":
			continue
		var gain: int = int(eff.get("amount", 0)) * backpack.neighbors(uid).size()
		if gain <= 0:
			continue
		player["block"] = int(player["block"]) + gain
		_check_secrets(uid)
		item_used.emit(uid)
		log_line.emit("%s gathers %d block." % [String(def.get("name", "item")), gain])


## A secret contributes when an adjacent item carries its tag.
func _check_secrets(uid: int) -> void:
	var def: Dictionary = _def_of(uid)
	var secrets: Array = def.get("secrets", [])
	if secrets.is_empty():
		return
	# Real Backpack reports every secret that is currently contributing (with_tag, with_id, when_alone).
	var eff: Dictionary = backpack.effective_effect(uid)
	if eff.has("secrets_triggered"):
		for t in eff["secrets_triggered"]:
			var sid2 := String(t.get("secret_id", ""))
			var key2 := "%s:%s" % [def.get("id", ""), sid2]
			if sid2 == "" or _found_secrets.has(key2):
				continue
			_found_secrets[key2] = true
			secret_found.emit(String(def["id"]), sid2)
			log_line.emit("Something answers.")
		return
	for s in secrets:
		var sid := String(s.get("id", ""))
		var key := "%s:%s" % [def.get("id", ""), sid]
		if sid == "" or _found_secrets.has(key):
			continue
		if _adjacent_with_tag(uid, String(s.get("with_tag", ""))) > 0:
			_found_secrets[key] = true
			secret_found.emit(String(def["id"]), sid)
			log_line.emit("Something answers.")


func _adjacent_with_tag(uid: int, tag: String) -> int:
	var n := 0
	for other in backpack.neighbors(uid):
		var tags: Array = _def_of(other).get("tags", [])
		if tag in tags:
			n += 1
	return n


# ---------------------------------------------------------------- damage

func _resolve_target(target: int) -> int:
	if target >= 0 and target < enemies.size() and bool(enemies[target]["alive"]):
		return target
	for i in range(enemies.size()):
		if bool(enemies[i]["alive"]):
			return i
	return -1


func _hit_target(target: int, amount: int, hit_index: int) -> void:
	var i := _resolve_target(target)
	if i >= 0:
		_damage_enemy(i, amount, hit_index)


func _damage_enemy(i: int, amount: int, hit_index: int) -> void:
	var e: Dictionary = enemies[i]
	var absorbed: int = mini(int(e["block"]), amount)
	e["block"] = int(e["block"]) - absorbed
	var dealt: int = amount - absorbed
	e["hp"] = int(e["hp"]) - dealt
	damage_dealt.emit(String(e["id"]), dealt, i)
	if absorbed > 0 and int(e["block"]) == 0 and "brittle" in e["traits"]:
		e["stunned"] = true
		_reveal(String(e["id"]), "brittle")
		log_line.emit("%s cracks. It falters." % e["name"])
	if "thorns" in e["traits"]:
		_reveal(String(e["id"]), "thorns")
		_damage_player(1)
	if int(e["hp"]) <= 0:
		e["hp"] = 0
		e["alive"] = false
		e["intent"] = {"type": "none", "amount": 0, "glyphs": []}
		log_line.emit("%s goes quiet." % e["name"])
		return
	_after_hurt(e)


func _after_hurt(e: Dictionary) -> void:
	if "splits" in e["traits"] and not bool(e["split_done"]) and int(e["hp"]) * 2 < int(e["max_hp"]):
		e["split_done"] = true
		if _alive_count() < EnemyDB.MAX_ENEMIES:
			_reveal(String(e["id"]), "splits")
			log_line.emit("%s tears in two." % e["name"])
			_spawn(String(e["id"]), 0.5, SPLIT_SCALE, true)
	var phase := EnemyDB.phase_for(String(e["id"]), float(e["hp"]) / float(e["max_hp"]))
	if phase > int(e["phase"]):
		e["phase"] = phase
		e["step"] = 0
		_set_intent(e)
		var phases: Array = EnemyDB.get_def(String(e["id"])).get("phases", [])
		var omen := String(phases[phase].get("omen", ""))
		if omen != "":
			log_line.emit(omen)


func _damage_player(amount: int) -> int:
	var absorbed: int = mini(int(player["block"]), amount)
	player["block"] = int(player["block"]) - absorbed
	var dealt: int = amount - absorbed
	player["hp"] = int(player["hp"]) - dealt
	damage_dealt.emit("player", dealt, -1)
	if int(player["hp"]) <= 0:
		player["hp"] = 0
	return dealt


# ---------------------------------------------------------------- enemies

func _make_enemy(id: String, hp_frac: float, scale_mult: float) -> Dictionary:
	var d: Dictionary = EnemyDB.get_def(id)
	var max_hp: int = maxi(int(round(float(d.get("max_hp", 10)) * _power)), 1)
	var e: Dictionary = {
		"id": id, "name": String(d.get("name", id)), "max_hp": max_hp,
		"hp": maxi(int(ceil(float(max_hp) * hp_frac)), 1),
		"block": 0, "alive": true,
		"scale": float(d.get("scale", 1.0)) * scale_mult,
		"traits": d.get("traits", []).duplicate(),
		"phase": 0, "step": 0, "stunned": false, "split_done": false, "bonus": 0,
		"intent": {},
	}
	_set_intent(e)
	return e


func _spawn(id: String, hp_frac: float, scale_mult: float, no_split: bool) -> void:
	var e := _make_enemy(id, hp_frac, scale_mult)
	if no_split:
		e["split_done"] = true
	enemies.append(e)


func _alive_count() -> int:
	var n := 0
	for e in enemies:
		if bool(e["alive"]):
			n += 1
	return n


func _set_intent(e: Dictionary) -> void:
	var list: Array = EnemyDB.intents_for(String(e["id"]), int(e["phase"]))
	if list.is_empty():
		e["intent"] = {"type": "block", "amount": 0, "glyphs": []}
		return
	var base: Dictionary = list[int(e["step"]) % list.size()]
	var amount: int = int(base.get("amount", 0))
	if String(base["type"]) == "attack":
		amount = int(round(float(amount) * _power)) + int(e["bonus"])
	elif amount > 0:
		amount = int(round(float(amount) * _power))
	var intent: Dictionary = {"type": String(base["type"]), "amount": amount, "glyphs": base.get("glyphs", [])}
	if base.has("hits"):
		intent["hits"] = int(base["hits"])
	if base.has("spawn"):
		intent["spawn"] = String(base["spawn"])
	e["intent"] = intent


func _enemy_act(i: int) -> void:
	var e: Dictionary = enemies[i]
	e["block"] = 0
	if bool(e["stunned"]):
		e["stunned"] = false
		log_line.emit("%s stands frozen." % e["name"])
		return
	var intent: Dictionary = e["intent"]
	var amount: int = int(intent.get("amount", 0))
	match String(intent.get("type", "")):
		"attack":
			_enemy_attack(e, amount, int(intent.get("hits", 1)))
		"block":
			e["block"] = amount
			log_line.emit("%s hardens." % e["name"])
		"heal":
			e["hp"] = mini(int(e["hp"]) + amount, int(e["max_hp"]))
			log_line.emit("%s knits itself." % e["name"])
		"split":
			_enemy_split(e, intent)
	e["step"] = int(e["step"]) + 1
	if bool(e["alive"]):
		_set_intent(e)


func _enemy_attack(e: Dictionary, amount: int, hits: int) -> void:
	var total := 0
	for h in range(hits):
		total += _damage_player(amount)
		if int(player["hp"]) <= 0:
			break
	log_line.emit("%s strikes for %d." % [e["name"], total])
	if "siphon" in e["traits"] and total > 0:
		e["hp"] = mini(int(e["hp"]) + total / 2, int(e["max_hp"]))
		_reveal(String(e["id"]), "siphon")
	if "cascade" in e["traits"]:
		e["bonus"] = int(e["bonus"]) + 1
		_reveal(String(e["id"]), "cascade")


func _enemy_split(e: Dictionary, intent: Dictionary) -> void:
	if _alive_count() >= EnemyDB.MAX_ENEMIES:
		return
	var id := String(intent.get("spawn", e["id"]))
	_reveal(String(e["id"]), "summons")
	log_line.emit("The water remembers a shape.")
	_spawn(id, 0.5, SPLIT_SCALE, true)


func _reveal(enemy_id: String, trait_name: String) -> void:
	var key := "%s:%s" % [enemy_id, trait_name]
	if _revealed_traits.has(key):
		return
	_revealed_traits[key] = true
	enemy_trait_revealed.emit(enemy_id, trait_name)


# ---------------------------------------------------------------- end

func _check_end() -> void:
	if _over:
		return
	if int(player["hp"]) <= 0:
		_finish(false)
	elif _alive_count() == 0:
		_finish(true)


func _finish(victory: bool) -> void:
	_over = true
	won = victory
	log_line.emit("Silence." if victory else "The pack grows heavy, then light.")
	ended.emit(victory)
