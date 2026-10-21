class_name Backpack
extends RefCounted
## Grid backpack: placement, adjacency, synergy math and tooltips. No UI code.

signal changed

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var w := 5
var h := 4
var placed: Array[Dictionary] = []
## Hero hook (e.g. Seshat): extra bonus per matching adjacency (synergies and secrets).
var adjacency_bonus := 0
var _next_uid := 1
var _occ: Dictionary = {}  # Vector2i -> uid

# --- placement -----------------------------------------------------------

func _abs_cells(id: String, pos: Vector2i, rot: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in ItemDB.shape_rotated(id, rot):
		out.append(c + pos)
	return out

func can_place(id: String, pos: Vector2i, rot: int, ignore_uid := -1) -> bool:
	if ItemDB.get_def(id).is_empty():
		return false
	for c in _abs_cells(id, pos, rot):
		if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
			return false
		var u: int = int(_occ.get(c, -1))
		if u != -1 and u != ignore_uid:
			return false
	return true

func place(id: String, pos: Vector2i, rot: int) -> int:
	if not can_place(id, pos, rot):
		return -1
	var uid := _next_uid
	_next_uid += 1
	placed.append({"uid": uid, "id": id, "pos": pos, "rot": posmod(rot, 4)})
	_rebuild()
	changed.emit()
	return uid

func remove(uid: int) -> Dictionary:
	for i in placed.size():
		if int(placed[i].uid) == uid:
			var e: Dictionary = placed[i]
			placed.remove_at(i)
			_rebuild()
			changed.emit()
			return e
	return {}

## Move/rotate an existing item; returns false (and changes nothing) if invalid.
func move(uid: int, pos: Vector2i, rot: int) -> bool:
	var e := entry(uid)
	if e.is_empty() or not can_place(String(e.id), pos, rot, uid):
		return false
	e.pos = pos
	e.rot = posmod(rot, 4)
	_rebuild()
	changed.emit()
	return true

func find_spot(id: String) -> Dictionary:
	for rot in 4:
		for y in h:
			for x in w:
				if can_place(id, Vector2i(x, y), rot):
					return {"pos": Vector2i(x, y), "rot": rot}
	return {}

## Change grid size; refuses (false) if an item would fall outside.
func resize(new_w: int, new_h: int) -> bool:
	if new_w < 1 or new_h < 1:
		return false
	for e in placed:
		for c in _abs_cells(String(e.id), e.pos, int(e.rot)):
			if c.x >= new_w or c.y >= new_h:
				return false
	w = new_w
	h = new_h
	changed.emit()
	return true

func _rebuild() -> void:
	_occ.clear()
	for e in placed:
		for c in _abs_cells(String(e.id), e.pos, int(e.rot)):
			_occ[c] = int(e.uid)

# --- queries -------------------------------------------------------------

func entry(uid: int) -> Dictionary:
	for e in placed:
		if int(e.uid) == uid:
			return e
	return {}

func cells_of(uid: int) -> Array[Vector2i]:
	var e := entry(uid)
	if e.is_empty():
		return []
	return _abs_cells(String(e.id), e.pos, int(e.rot))

func uid_at(cell: Vector2i) -> int:
	return int(_occ.get(cell, -1))

func id_of(uid: int) -> String:
	return String(entry(uid).get("id", ""))

func uids() -> Array[int]:
	var out: Array[int] = []
	for e in placed:
		out.append(int(e.uid))
	return out

## Uids sharing an edge with the item (never diagonal, never itself), sorted.
func neighbors(uid: int) -> Array[int]:
	var out: Array[int] = []
	for c in cells_of(uid):
		for d in DIRS:
			var u := uid_at(c + d)
			if u != -1 and u != uid and not out.has(u):
				out.append(u)
	out.sort()
	return out

# --- synergy math --------------------------------------------------------

func _matches(rule: Dictionary, nbr_ids: Array[String]) -> int:
	if rule.has("when_alone"):
		return 1 if nbr_ids.is_empty() else 0
	var n := 0
	for nid in nbr_ids:
		if rule.has("with_id"):
			n += 1 if nid == String(rule.with_id) else 0
		elif rule.has("with_tag") and ItemDB.has_tag(nid, String(rule.with_tag)):
			n += 1
	return n

## Item effect with every bonus applied. Secrets are ACTIVE whether or not
## discovered. Extra keys: adjacent_count, total (damage/block/etc. actually
## dealt by one use), secrets_triggered: [{item_id, secret_id}] for Combat.
func effective_effect(uid: int) -> Dictionary:
	return _compute(uid, true)

func _compute(uid: int, include_hidden: bool) -> Dictionary:
	var e := entry(uid)
	if e.is_empty():
		return {}
	var id: String = e.id
	var def := ItemDB.get_def(id)
	var eff: Dictionary = (def.effect as Dictionary).duplicate()
	var nbrs := neighbors(uid)
	var nbr_ids: Array[String] = []
	for n in nbrs:
		nbr_ids.append(id_of(n))
	var amount: int = int(eff.get("amount", 0))
	var hits: int = int(eff.get("hits", 1))
	var triggered: Array[Dictionary] = []
	var inert: bool = String(eff.type) in ["none", "identify"]

	var rules: Array[Dictionary] = []
	var rule_secret: Array[String] = []
	for s in def.get("synergies", []):
		rules.append(s)
		rule_secret.append("")
	for s in def.get("secrets", []):
		var sd: Dictionary = s
		if include_hidden or ItemDB.is_discovered(id, String(sd.id)):
			rules.append(sd)
			rule_secret.append(String(sd.id))
	for i in rules.size():
		var cnt := _matches(rules[i], nbr_ids)
		if cnt == 0:
			continue
		var bonus: Dictionary = rules[i].bonus
		var extra := adjacency_bonus if not rules[i].has("when_alone") else 0
		amount += (int(bonus.get("amount", 0)) + (extra if bonus.has("amount") else 0)) * cnt
		hits += int(bonus.get("hits", 0)) * cnt
		if rule_secret[i] != "":
			triggered.append({"item_id": id, "secret_id": rule_secret[i]})
	# Passive neighbours that boost this item's tags.
	for nid in nbr_ids:
		var nd := ItemDB.get_def(nid)
		if nd.has("boost_tag") and ItemDB.has_tag(id, String(nd.boost_tag)):
			amount += int(nd.get("boost_amount", 0))

	if inert:
		amount = int(eff.get("amount", 0))
		triggered.clear()
	eff["amount"] = amount
	if eff.has("hits") or hits != 1:
		eff["hits"] = hits
	eff["adjacent_count"] = nbrs.size()
	eff["total"] = _total(eff, nbrs.size())
	eff["secrets_triggered"] = triggered
	return eff

func _total(eff: Dictionary, adj: int) -> int:
	var amount: int = int(eff.get("amount", 0))
	match String(eff.type):
		"multi_damage": return amount * int(eff.get("hits", 1))
		"damage_per_adjacent", "turn_start_block_per_adjacent": return amount * adj
	return amount

# --- tooltip -------------------------------------------------------------

func _effect_text(eff: Dictionary) -> String:
	var a: int = int(eff.get("amount", 0))
	match String(eff.type):
		"damage": return "Deal %d damage." % a
		"multi_damage": return "Deal %d damage x %d." % [a, int(eff.get("hits", 1))]
		"block": return "Gain %d block." % a
		"heal": return "Heal %d." % a
		"energy": return "Gain %d energy." % a
		"damage_per_adjacent":
			return "Deal %d damage per adjacent item (now %d)." % [a, int(eff.total)]
		"turn_start_block_per_adjacent":
			return "Turn start: %d block per adjacent item (now %d)." % [a, int(eff.total)]
		"identify": return "Reveals the true names of adjacent items."
	return ""

## Tooltip with real numbers. Undiscovered secrets are neither listed nor
## included in the shown numbers (their effect still happens in play).
func describe(uid: int) -> String:
	var e := entry(uid)
	if e.is_empty():
		return ""
	var id: String = e.id
	var def := ItemDB.get_def(id)
	var eff := _compute(uid, false)
	var lines: Array[String] = [String(def.name)]
	var meta := "Passive" if String(def.kind) == "passive" else "Active, costs %d energy" % int(def.cost)
	if bool(def.get("consumable", false)):
		meta += ", once per battle"
	lines.append(meta)
	var et := _effect_text(eff)
	if et != "":
		lines.append(et)
	lines.append(String(def.desc))
	for s in def.get("synergies", []):
		lines.append("Adjacent %s: +%d" % [_rule_target(s), int(s.bonus.get("amount", 0))])
	for s in def.get("secrets", []):
		var sd: Dictionary = s
		if ItemDB.is_discovered(id, String(sd.id)):
			lines.append("Secret: " + String(sd.text))
	if ItemDB.has_undiscovered_secrets(id):
		lines.append("…there is more.")
	return "\n".join(lines)

func _rule_target(rule: Dictionary) -> String:
	if rule.has("with_id"):
		return String(ItemDB.get_def(String(rule.with_id)).get("name", rule.with_id))
	return String(rule.get("with_tag", "item"))

# --- save / load ---------------------------------------------------------

## Entries as plain data: [{uid, id, pos:[x,y], rot}]. Grid size is in to_dict().
func to_array() -> Array:
	var out: Array = []
	for e in placed:
		out.append({"uid": int(e.uid), "id": String(e.id), "pos": [e.pos.x, e.pos.y], "rot": int(e.rot)})
	return out

static func from_array(a: Array, grid_w := 5, grid_h := 4) -> Backpack:
	var bp := Backpack.new()
	bp.w = grid_w
	bp.h = grid_h
	for item in a:
		var d: Dictionary = item
		var p = d.get("pos", [0, 0])
		var pos: Vector2i = p if p is Vector2i else Vector2i(int(p[0]), int(p[1]))
		var id := String(d.get("id", ""))
		var rot := int(d.get("rot", 0))
		if not bp.can_place(id, pos, rot):
			continue  # drop invalid or overlapping entries silently
		var uid := int(d.get("uid", bp._next_uid))
		if bp.entry(uid).is_empty() == false:
			uid = bp._next_uid
		bp.placed.append({"uid": uid, "id": id, "pos": pos, "rot": posmod(rot, 4)})
		bp._next_uid = maxi(bp._next_uid, uid + 1)
		bp._rebuild()
	return bp

func to_dict() -> Dictionary:
	return {"w": w, "h": h, "items": to_array()}

static func from_dict(d: Dictionary) -> Backpack:
	return from_array(d.get("items", []), int(d.get("w", 5)), int(d.get("h", 4)))
