class_name Run
extends Control
## The flow brain of Caesar's Dilemma: owns hero/HP/gold/pack state, walks the RouteMap, and resolves each node by
## hosting the other screens (loaded at runtime from res://game/*.gd; a missing screen is skipped with a warning).
## Screens: RouteMap (map), Battle, LootUI, DilemmaUI, ShrineUI, BackpackUI. Shop / rest / "continue" menus are built in here.
##
##   var run := Run.new(); add_child(run); run.run_ended.connect(...); run.begin("seshat", "eclipse")
##
## Tests/hosts may set `screen_factory` (Callable: kind:String -> Node, kinds map/battle/loot/dilemma/shrine/backpack),
## `instant` (no tweens) and `autoplay` (built-in menus pick a random enabled option).

signal run_ended(won: bool, depth: int)
signal state_changed

const GOLD := Color(0.93, 0.80, 0.52)
const INK := Color(0.03, 0.04, 0.07, 0.94)
const TEAL := Color(0.25, 0.9, 0.75)
const VIOLET := Color(0.7, 0.4, 0.95)
const SCREEN_FILES := {"map": "route_map", "battle": "battle", "loot": "loot_ui", "dilemma": "dilemma_ui",
		"shrine": "shrine_ui", "backpack": "backpack_ui"}

const HEROES := {
	"seshat": {"hp": 40, "items": ["bone_blade", "whetstone", "reed_buckler", "moss_charm", "spore_flask"], "adjacency_bonus": 1},
	"thoth": {"hp": 36, "items": ["glyph_lens", "crystal_bow", "quiver", "lapis_shield", "fractal_seed"], "adjacency_bonus": 0},
}
## size = starting backpack grid; item = starting item ("@weapon" = a mirror copy of the hero's first weapon)
const ORIGINS := {
	"eclipse": {"w": 4, "h": 4, "item": "sun_shard", "gold": 0},
	"mirror": {"w": 5, "h": 4, "item": "@weapon", "gold": 10},
	"cathedral": {"w": 6, "h": 4, "item": "healing_bloom", "gold": 25},
}
const MAX_W := 7
const MAX_H := 6

var hero_id := "seshat"
var origin_id := "eclipse"
var hp := 40
var max_hp := 40
var gold := 0
var depth := 0                       # deepest route depth reached (1-based)
var bp: Backpack = null
var rng := RandomNumberGenerator.new()
var map: Control = null
var cursed: Dictionary = {}          # uid -> true (a cursed item costs max HP when it lands; UIs may draw a dark mark)
var ended := false
var won := false
var fresh_heroes: Array[String] = []
var visited: Dictionary = {}         # node type -> times resolved (stats / tests)
var screen_factory: Callable = Callable()
var screen_hook: Callable = Callable()   # (kind, node) called once a screen is open; tests drive it
var instant := false
var autoplay := false
var music: Node = null               # optional: Music node (set_theme); installed lazily when empty and not instant
var sfx: Node = null

var _hud: Control = null
var _veil_rect: ColorRect = null
var _steps := 0


class _Waiter extends RefCounted:
	signal fired
	var done := false
	var args: Array = []
	func fire(a = null, b = null, c = null) -> void:
		args = [a, b, c]
		done = true
		fired.emit()


# --- starting kit ---------------------------------------------------------------------------------

## Builds the starting pack for hero + origin (static so previews / tests can use it).
static func make_pack(p_hero: String, p_origin: String) -> Backpack:
	var h: Dictionary = HEROES.get(p_hero, HEROES["seshat"])
	var o: Dictionary = ORIGINS.get(p_origin, ORIGINS["eclipse"])
	var pack := Backpack.new()
	pack.w = int(o["w"])
	pack.h = int(o["h"])
	pack.adjacency_bonus = int(h.get("adjacency_bonus", 0))
	var ids: Array = (h["items"] as Array).duplicate()
	var extra: String = String(o["item"])
	if extra == "@weapon":
		extra = "bone_blade"
		for id in ids:
			if ItemDB.has_tag(String(id), "weapon"):
				extra = String(id)
				break
	ids.append(extra)
	for id in ids:
		var spot: Dictionary = pack.find_spot(String(id))
		var tries := 0
		while spot.is_empty() and tries < 4:    # the origin's pack is a little too small for the kit: it stretches
			if pack.w <= pack.h:
				pack.w += 1
			else:
				pack.h += 1
			spot = pack.find_spot(String(id))
			tries += 1
		if not spot.is_empty():
			pack.place(String(id), spot["pos"], int(spot["rot"]))
	return pack


static func start_gold(p_origin: String) -> int:
	return int((ORIGINS.get(p_origin, ORIGINS["eclipse"]) as Dictionary).get("gold", 0))


# --- begin / end ----------------------------------------------------------------------------------

func begin(p_hero: String, p_origin: String, p_seed := -1) -> void:
	hero_id = p_hero if HEROES.has(p_hero) else "seshat"
	origin_id = p_origin if ORIGINS.has(p_origin) else "eclipse"
	if p_seed >= 0:
		rng.seed = p_seed
	else:
		rng.randomize()
	if Meta.lexicon_seed == 0:
		Meta.load()
	Lexicon.init(Meta.lexicon_seed, Meta.known_words)
	Meta.on_secret_discovered = ItemDB.mark_discovered
	ItemDB.discovered_check = Meta.is_secret_discovered
	max_hp = int((HEROES[hero_id] as Dictionary)["hp"])
	hp = max_hp
	gold = start_gold(origin_id)
	depth = 0
	ended = false
	won = false
	cursed.clear()
	visited.clear()
	_steps = 0
	bp = make_pack(hero_id, origin_id)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_chrome()
	_ensure_audio()
	map = _screen("map")
	if map == null:
		push_warning("Run: RouteMap missing, run cannot continue")
		_end(false)
		return
	map.call("generate", rng.randi(), origin_id, hero_id)
	_theme("map")
	state_changed.emit()
	_loop()


func _end(p_won: bool) -> void:
	if ended:
		return
	ended = true
	won = p_won
	fresh_heroes = Meta.record_run(hero_id, p_won, depth)
	Meta.save()
	_theme("garden")
	run_ended.emit(p_won, depth)


## Snapshot for UIs / saves.
func state() -> Dictionary:
	return {"hero": hero_id, "origin": origin_id, "hp": hp, "max_hp": max_hp, "gold": gold, "depth": depth,
			"pack": bp.to_array() if bp else [], "w": bp.w if bp else 0, "h": bp.h if bp else 0, "cursed": cursed.keys()}


# --- main loop ------------------------------------------------------------------------------------

func _loop() -> void:
	while not ended:
		_steps += 1
		if _steps > 400 or map == null or not is_instance_valid(map):
			_end(false)
			return
		map.visible = true
		_hud.visible = true
		var w := _sig(map, "node_chosen")
		map.call("reveal_choices")
		_hook("map", map)
		await _wait(w)
		if ended:
			return
		var node: Dictionary = w.args[0] if w.args[0] is Dictionary else {}
		if node.is_empty():
			continue
		node["state"] = "current"
		await _resolve(node)
		if ended:
			return
		if String(node.get("state", "")) == "current":
			node["state"] = "done"
		if hp <= 0:
			_end(false)
			return


func _resolve(node: Dictionary) -> void:
	var t: String = String(node.get("type", "fight"))
	var d: int = int(node.get("depth", 0))
	depth = maxi(depth, d + 1)
	Meta.record_progress(depth)
	_learn("loc:" + t)
	if t == "mystery":
		var rt: String = String(node.get("resolved", ""))
		if rt == "" and map.has_method("resolve_mystery"):
			rt = String(map.call("resolve_mystery", int(node.get("id", -1))))
		t = rt if rt in ["fight", "elite", "treasure", "shop", "rest", "shrine", "dilemma"] else _roll_mystery()
	visited[t] = int(visited.get(t, 0)) + 1
	var floor_n: int = 1 + (d * 2) / 3
	map.visible = false
	match t:
		"fight":
			await _fight(EnemyDB.floor_enemies(floor_n, rng), floor_n, 0.0, false)
		"elite":
			await _fight(EnemyDB.floor_enemies(floor_n + 2, rng), floor_n + 1, 0.8, true)
		"boss":
			var ok: bool = await _fight([EnemyDB.BOSS_ID], floor_n + 2, 0.0, false, true)
			if ok and not ended:
				_end(true)
		"treasure":
			gold += rng.randi_range(8, 16) + floor_n * 2
			await _loot(ItemDB.roll_loot(rng, 3, 0.6))
		"shop":
			await _shop()
		"rest":
			await _rest()
		"shrine":
			await _shrine()
		"dilemma":
			await _dilemma()
		_:
			push_warning("Run: unknown node type '%s'" % t)
	if not ended:
		map.visible = true
		_theme("map")
	state_changed.emit()


func _roll_mystery() -> String:
	var table := [["fight", 40], ["treasure", 20], ["shop", 12], ["rest", 12], ["shrine", 8], ["dilemma", 8]]
	var total := 0
	for r in table:
		total += int(r[1])
	var pick: int = rng.randi_range(0, total - 1)
	for r in table:
		pick -= int(r[1])
		if pick < 0:
			return String(r[0])
	return "fight"


# --- fight / loot ---------------------------------------------------------------------------------

## Returns true when the player survived. A lost fight ends the run.
func _fight(enemy_ids: Array, floor_n: int, loot_bias: float, elite: bool, boss := false) -> bool:
	var b: Control = _screen("battle")
	if b == null:
		push_warning("Run: Battle missing, fight skipped")
		return true
	for id in enemy_ids:
		Meta.see_enemy(String(id))
	_hud.visible = false
	_theme("boss" if boss else "battle")
	await _veil(1.0, 0.25)
	var w := _sig(b, "finished")
	b.call("start", bp, enemy_ids, {"hp": hp, "max_hp": max_hp, "floor": floor_n, "gold": gold}, hero_id, rng)
	_hook("battle", b)
	if not instant:
		Hub.tension(0.85 if boss else (0.6 if elite else 0.35))
	await _veil(0.0, 0.35)
	await _wait(w)
	var ps: Dictionary = w.args[1] if w.args[1] is Dictionary else {}
	var victory: bool = bool(w.args[0])
	if b.has_method("used_item_ids"):
		for id in b.call("used_item_ids"):
			_learn("item:" + String(id))
	hp = clampi(int(ps.get("hp", hp)), 0, maxi(max_hp, 1))
	max_hp = maxi(int(ps.get("max_hp", max_hp)), 1)
	b.queue_free()
	if not instant:
		Hub.tension(0.0)
	_hud.visible = true
	if not victory or hp <= 0:
		_end(false)
		return false
	_lens_identify()
	if not boss:
		gold += rng.randi_range(5, 10) + floor_n * 2 + (10 if elite else 0)
		await _loot(ItemDB.roll_loot(rng, 3, loot_bias))
	state_changed.emit()
	return true


func _loot(ids: Array) -> void:
	var ui: Control = _screen("loot")
	if ui == null:
		push_warning("Run: LootUI missing, loot skipped")
		return
	_theme("map")
	var w := _sig(ui, "chosen")
	_call_first(ui, ["show_offers"], [ids])
	_hook("loot", ui)
	await _wait(w)
	var id: String = String(w.args[0]) if w.args[0] != null else ""
	ui.queue_free()
	if id != "" and not ItemDB.get_def(id).is_empty():
		await _acquire(id)


## Carries a new item into the pack (BackpackUI.hold). Returns true when it was placed;
## otherwise the item is forfeited for a little gold.
func _acquire(id: String, compensate := true) -> bool:
	var placed := false
	var ui: Control = _screen("backpack")
	if ui != null:
		ui.call("setup", bp, "arrange")
		var w := _sig(ui, "hold_finished")
		ui.call("hold", id)
		_hook("hold", ui)
		await _wait(w)
		placed = bool(w.args[0])
		ui.queue_free()
	else:
		var spot: Dictionary = bp.find_spot(id)
		if not spot.is_empty():
			placed = bp.place(id, spot["pos"], int(spot["rot"])) != -1
	if not placed and compensate:
		gold += 6 + 4 * int(ItemDB.get_def(id).get("rarity", 1))
	state_changed.emit()
	return placed


func _lens_identify() -> void:
	var has_lens := false
	var unknown: Array[String] = []
	for uid in bp.uids():
		var id: String = bp.id_of(uid)
		if id == "glyph_lens":
			has_lens = true
		elif not Meta.is_item_known(id):
			unknown.append(id)
	if has_lens and not unknown.is_empty():
		_learn("item:" + unknown[rng.randi() % unknown.size()])


# --- shop / rest ----------------------------------------------------------------------------------

func _price(id: String) -> int:
	return 16 + 14 * int(ItemDB.get_def(id).get("rarity", 1))


func _shop() -> void:
	var stock: Array = ItemDB.roll_loot(rng, 3, 0.3)
	var sold: Dictionary = {}
	while not ended:
		var opts: Array = []
		for id in stock:
			var price: int = _price(String(id))
			opts.append({"item": id, "label": "", "sub": "%d gold" % price,
					"enabled": not sold.has(id) and gold >= price})
			if sold.has(id):
				opts[opts.size() - 1]["sub"] = "sold"
		opts.append({"item": "", "label": "Leave", "sub": "", "enabled": true})
		var pick: int = await _menu("Wares", "%d gold" % gold, opts)
		if pick >= stock.size():
			return
		var sid: String = String(stock[pick])
		gold -= _price(sid)
		sold[sid] = true
		var placed: bool = await _acquire(sid, false)
		if not placed:
			gold += _price(sid)   # no room / cancelled: full refund
		if sold.size() >= stock.size():
			return


func _rest() -> void:
	_theme("shrine")
	var heal: int = ceili(float(max_hp) * 0.3)
	var pick: int = await _menu("Stillness", "", [
		{"item": "", "label": "Mend", "sub": "+%d HP" % heal, "enabled": true},
		{"item": "", "label": "Rearrange", "sub": "the pack", "enabled": true}])
	if pick == 0:
		hp = mini(max_hp, hp + heal)
	else:
		var ui: Control = _screen("backpack")
		if ui != null:
			ui.call("setup", bp, "arrange")
			await _menu("", "", [{"item": "", "label": "Done", "sub": "", "enabled": true}], true)
			ui.queue_free()
		else:
			hp = mini(max_hp, hp + heal)
	state_changed.emit()


# --- shrine / dilemma -----------------------------------------------------------------------------

func _shrine() -> void:
	_theme("shrine")
	var ui: Control = _screen("shrine")
	if ui == null:
		push_warning("Run: ShrineUI missing, shrine gives a blessing instead")
		max_hp += 2
		hp = mini(max_hp, hp + 6)
		return
	var w := _sig(ui, "done")
	_call_first(ui, ["open"], [rng])
	_hook("shrine", ui)
	await _wait(w)
	var key: String = String(ui.get("key")) if ui.get("key") != null else ""
	ui.queue_free()
	if key != "":
		_learn(key)
	else:
		max_hp += 2
		hp = mini(max_hp, hp + 6)
	state_changed.emit()


func _pick_unknown_key() -> String:
	var pool: Array[String] = []
	for uid in bp.uids():
		var k: String = "item:" + bp.id_of(uid)
		if not Meta.is_known(k) and not Lexicon.is_known(k):
			pool.append(k)
	if pool.is_empty() or rng.randf() < 0.4:
		for cat in [Lexicon.CAT_LOC, Lexicon.CAT_BONUS, Lexicon.CAT_ENEMY, Lexicon.CAT_ITEM, Lexicon.CAT_ACT, Lexicon.CAT_QUAL]:
			for k in Lexicon.all_keys(cat):
				if not Meta.is_known(k) and not Lexicon.is_known(k):
					pool.append(k)
	if pool.is_empty():
		return ""
	return pool[rng.randi() % pool.size()]


func _dilemma() -> void:
	var d: Dictionary = DilemmaDB.roll(rng, {"hp": hp, "max_hp": max_hp, "gold": gold, "depth": depth})
	if d.is_empty():
		return
	var ui: Control = _screen("dilemma")
	if ui == null:
		push_warning("Run: DilemmaUI missing, dilemma skipped")
		return
	_theme("shrine")
	var w := _sig(ui, "chosen")
	_call_first(ui, ["show_dilemma"], [d])
	_hook("dilemma", ui)
	await _wait(w)
	ui.queue_free()
	var choices: Array = d.get("choices", [])
	if choices.is_empty():
		return
	var idx: int = clampi(int(w.args[0]), 0, choices.size() - 1)
	await apply_effects((choices[idx] as Dictionary).get("effects", []))


## Applies the effect list of a dilemma choice (all types documented at the top of dilemmas.gd).
func apply_effects(effects: Array) -> void:
	for e in effects:
		var ed: Dictionary = e
		var amt: int = int(ed.get("amount", 0))
		match String(ed.get("type", "")):
			"max_hp":
				max_hp = maxi(5, max_hp + amt)
				if amt > 0:
					hp += amt
				hp = clampi(hp, 1, max_hp)
			"hp":
				hp = clampi(hp + amt, 1, max_hp)
			"heal_all":
				hp = max_hp
			"gold":
				gold = maxi(0, gold + amt)
			"item":
				var id: String = String(ed.get("id", ""))
				if id == "" or ItemDB.get_def(id).is_empty():
					id = _random_item(int(ed.get("rarity", 1)))
				await _acquire(id)
			"curse_item":
				var cid: String = String(ed.get("id", ""))
				var cands: Array[int] = []
				for uid in bp.uids():
					if not cursed.has(uid) and (cid == "" or bp.id_of(uid) == cid):
						cands.append(uid)
				if not cands.is_empty():
					cursed[cands[rng.randi() % cands.size()]] = true
					max_hp = maxi(5, max_hp - 3)
					hp = clampi(hp, 1, max_hp)
			"remove_item":
				var rid: String = String(ed.get("id", ""))
				var owned: Array[int] = []
				for uid in bp.uids():
					if rid == "" or bp.id_of(uid) == rid:
						owned.append(uid)
				if not owned.is_empty() and bp.placed.size() > 1:
					var gone: int = owned[rng.randi() % owned.size()]
					bp.remove(gone)
					cursed.erase(gone)
			"shrink_pack":
				for i in maxi(1, amt):
					_resize_pack(-1)
			"grow_pack":
				for i in maxi(1, amt):
					_resize_pack(1)
			"reveal_glyph":
				for i in maxi(1, amt):
					_reveal_random()
			"change_path":
				if map != null and is_instance_valid(map):
					map.call("mutate", String(ed.get("mode", "reveal")))
		state_changed.emit()


func _random_item(min_rarity: int) -> String:
	var id := "bone_blade"
	for i in 12:
		var r: Array[String] = ItemDB.roll_loot(rng, 1)
		if r.is_empty():
			break
		id = r[0]
		if int(ItemDB.get_def(id).get("rarity", 1)) >= min_rarity:
			break
	return id


func _resize_pack(delta: int) -> void:
	if delta > 0:
		if bp.w <= bp.h and bp.w < MAX_W:
			bp.resize(bp.w + 1, bp.h)
		elif bp.h < MAX_H:
			bp.resize(bp.w, bp.h + 1)
		elif bp.w < MAX_W:
			bp.resize(bp.w + 1, bp.h)
		return
	if bp.w * bp.h <= 9:
		return
	for attempt in 8:
		var cols: bool = bp.w >= bp.h
		if cols and bp.w <= 3:
			cols = false
		if not cols and bp.h <= 3:
			cols = true
		if bp.resize(bp.w - 1, bp.h) if cols else bp.resize(bp.w, bp.h - 1):
			return
		# an item sits on the edge that is closing: it falls out of the pack
		var edge: Array[int] = []
		for uid in bp.uids():
			for c in bp.cells_of(uid):
				if (cols and c.x == bp.w - 1) or (not cols and c.y == bp.h - 1):
					edge.append(uid)
					break
		if edge.is_empty() or bp.placed.size() <= 1:
			return
		var gone: int = edge[rng.randi() % edge.size()]
		bp.remove(gone)
		cursed.erase(gone)


func _reveal_random() -> void:
	var cats: Array = [Lexicon.CAT_LOC, Lexicon.CAT_ITEM, Lexicon.CAT_BONUS, Lexicon.CAT_ENEMY, Lexicon.CAT_ACT, Lexicon.CAT_QUAL]
	cats.shuffle()
	for cat in cats:
		var pool: Array[String] = []
		for k in Lexicon.all_keys(int(cat)):
			if not Meta.is_known(k) and not Lexicon.is_known(k):
				pool.append(k)
		if not pool.is_empty():
			_learn(pool[rng.randi() % pool.size()])
			return


## Learns a glyph word everywhere (Lexicon + saved Meta). Thoth's passive: each new word is a small blessing.
func _learn(key: String) -> bool:
	if Meta.is_known(key) and Lexicon.is_known(key):
		return false
	Lexicon.learn(key)
	var fresh: bool = Meta.mark_known(key)
	if fresh and hero_id == "thoth" and not key.begins_with("loc:"):
		max_hp += 1
		hp = mini(max_hp, hp + 2)
	return fresh


# --- screens & helpers ----------------------------------------------------------------------------

func _make(kind: String) -> Node:
	if screen_factory.is_valid():
		var n: Variant = screen_factory.call(kind)
		if n is Node:
			return n
	var path := "res://game/%s.gd" % String(SCREEN_FILES.get(kind, kind))
	if not ResourceLoader.exists(path):
		push_warning("Run: %s not found" % path)
		return null
	var s: Variant = load(path)
	if s == null or not (s is GDScript) or not (s as GDScript).can_instantiate():
		push_warning("Run: %s cannot be instantiated" % path)
		return null
	return (s as GDScript).new()


func _screen(kind: String) -> Control:
	var n: Node = _make(kind)
	if n == null or not (n is Control):
		if n != null:
			n.queue_free()
		return null
	var c: Control = n
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	if _hud != null:
		move_child(_hud, -1)
	if _veil_rect != null:
		move_child(_veil_rect, -1)
	return c


func _hook(kind: String, node: Node) -> void:
	if screen_hook.is_valid():
		screen_hook.call(kind, node)


func _sig(obj: Object, sig_name: String) -> _Waiter:
	var w := _Waiter.new()
	if obj.has_signal(sig_name):
		obj.connect(sig_name, w.fire)
	else:
		push_warning("Run: %s has no signal %s" % [obj, sig_name])
		w.done = true
	return w


func _wait(w: _Waiter) -> void:
	if not w.done:
		await w.fired


func _call_first(obj: Object, names: Array, args: Array) -> Variant:
	for n in names:
		if obj.has_method(String(n)):
			return obj.callv(String(n), args)
	push_warning("Run: %s has none of %s" % [obj, str(names)])
	return null


## Built-in menu (shop, rest...). Returns the picked option index.
func _menu(title: String, sub: String, opts: Array, compact := false) -> int:
	var m := _Menu.new()
	m.setup(title, sub, opts, compact, instant)
	if autoplay:
		m.autopick = rng
	add_child(m)
	move_child(_hud, -1)
	var w := _Waiter.new()
	m.picked.connect(w.fire)
	await _wait(w)
	var idx: int = int(w.args[0])
	m.queue_free()
	return idx


func _build_chrome() -> void:
	if _hud != null:
		return
	_hud = _Hud.new()
	_hud.set("run", self)
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)
	_veil_rect = ColorRect.new()
	_veil_rect.color = Color(0.01, 0.01, 0.03, 0.0)
	_veil_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil_rect)
	state_changed.connect(_hud.queue_redraw)


func _veil(a: float, dur: float) -> void:
	if instant or _veil_rect == null or not is_inside_tree():
		return
	var tw := create_tween()
	tw.tween_property(_veil_rect, "color:a", a, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


func _ensure_audio() -> void:
	if instant or not is_inside_tree():
		return
	Hub.audio(get_tree())


func _theme(theme_name: String) -> void:
	if not instant:
		Hub.theme(theme_name)


## Draws a glyph word (determinative + roots) for a Lexicon key, left-aligned at `pos` (centre-left of the row).
static func draw_word(ci: CanvasItem, key: String, pos: Vector2, size: float, col: Color) -> float:
	var ids: Array[int] = Lexicon.word_for(key)
	var x: float = pos.x + size * 0.5
	for g in ids:
		GlyphGen.draw(ci, int(g), Vector2(x, pos.y), size, col, 2.0)
		x += size * 1.05
	return x - pos.x


## Draws an item icon through ItemIcons when it exists; otherwise a tasteful glowing rounded rect.
static func draw_icon(ci: CanvasItem, id: String, rect: Rect2, t: float, glow: float) -> void:
	if ResourceLoader.exists("res://game/item_icons.gd"):
		var s: Variant = load("res://game/item_icons.gd")
		if s is GDScript and (s as GDScript).has_method("draw"):
			(s as GDScript).call("draw", ci, id, rect, t, glow)
			return
	var tags: Array = ItemDB.get_def(id).get("tags", [])
	var col: Color = TEAL if tags.has("armor") else (Color(1.0, 0.55, 0.4) if tags.has("weapon") else VIOLET)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r * 0.2, col.g * 0.2, col.b * 0.2, 0.95)
	sb.border_color = col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.shadow_color = Color(col.r, col.g, col.b, 0.25 + 0.4 * glow)
	sb.shadow_size = 6
	ci.draw_style_box(sb, rect.grow(-4))


# --- HUD ------------------------------------------------------------------------------------------

class _Hud extends Control:
	var run: Run = null
	func _draw() -> void:
		if run == null or run.ended:
			return
		var f: Font = ThemeDB.fallback_font
		var box := StyleBoxFlat.new()
		box.bg_color = Run.INK
		box.border_color = Run.GOLD
		box.set_border_width_all(2)
		box.set_corner_radius_all(10)
		box.shadow_color = Color(Run.GOLD.r, Run.GOLD.g, Run.GOLD.b, 0.18)
		box.shadow_size = 8
		draw_style_box(box, Rect2(12, 10, 292, 34))
		draw_circle(Vector2(30, 27), 6.0, Color(0.9, 0.3, 0.4))
		draw_string(f, Vector2(42, 33), "%d / %d" % [run.hp, run.max_hp], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.88, 0.9))
		draw_circle(Vector2(130, 27), 6.0, Run.GOLD)
		draw_string(f, Vector2(142, 33), "%d" % run.gold, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Run.GOLD)
		draw_arc(Vector2(200, 27), 6.0, 0.0, TAU, 12, Run.TEAL, 2.0)
		draw_string(f, Vector2(212, 33), "depth %d" % run.depth, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Run.TEAL)


# --- built-in menu --------------------------------------------------------------------------------

class _Menu extends Control:
	signal picked(index: int)
	var title := ""
	var sub := ""
	var opts: Array = []
	var compact := false
	var autopick: RandomNumberGenerator = null
	var _appear := 1.0
	var _hov: Array[float] = []
	var _hover := -1
	var _t := 0.0
	var _done := false

	func setup(p_title: String, p_sub: String, p_opts: Array, p_compact: bool, instant: bool) -> void:
		title = p_title
		sub = p_sub
		opts = p_opts
		compact = p_compact
		_appear = 1.0 if instant else 0.0
		for o in opts:
			_hov.append(0.0)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		var vp: Vector2 = get_viewport_rect().size
		if compact:
			size = Vector2(300, 64)
			position = Vector2((vp.x - 300.0) * 0.5, vp.y - 92.0)
		else:
			set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if _appear < 1.0 and is_inside_tree():
			create_tween().tween_property(self, "_appear", 1.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if autopick != null:
			_auto.call_deferred()

	func _auto() -> void:
		var ok: Array[int] = []
		for i in opts.size():
			if bool((opts[i] as Dictionary).get("enabled", true)):
				ok.append(i)
		if ok.is_empty():
			ok.append(opts.size() - 1)
		_pick(ok[autopick.randi() % ok.size()])

	func _pick(i: int) -> void:
		if _done:
			return
		_done = true
		picked.emit(i)

	func _rect(i: int) -> Rect2:
		if compact:
			return Rect2(Vector2.ZERO, size)
		var n: int = opts.size()
		var cw := 200.0
		var gap := 18.0
		var total: float = n * cw + (n - 1) * gap
		var vp: Vector2 = size
		return Rect2((vp.x - total) * 0.5 + i * (cw + gap), vp.y * 0.5 - 70.0 + 14.0 * (1.0 - _appear), cw, 190.0)

	func _process(delta: float) -> void:
		_t += delta
		for i in _hov.size():
			_hov[i] = lerpf(_hov[i], 1.0 if i == _hover else 0.0, 1.0 - exp(-12.0 * delta))
		queue_redraw()

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseMotion:
			_hover = -1
			for i in opts.size():
				if _rect(i).has_point((ev as InputEventMouseMotion).position):
					_hover = i
		elif ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			for i in opts.size():
				if _rect(i).has_point((ev as InputEventMouseButton).position) and bool((opts[i] as Dictionary).get("enabled", true)):
					_pick(i)

	func _draw() -> void:
		var f: Font = ThemeDB.fallback_font
		if not compact:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.01, 0.03, 0.6 * _appear))
			if title != "":
				draw_string(f, Vector2(0, size.y * 0.5 - 100.0), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, Color(Run.GOLD, _appear))
			if sub != "":
				draw_string(f, Vector2(0, size.y * 0.5 - 74.0), sub, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color(Run.TEAL, _appear))
		for i in opts.size():
			var o: Dictionary = opts[i]
			var r: Rect2 = _rect(i)
			var enabled: bool = bool(o.get("enabled", true))
			var hv: float = _hov[i]
			var a: float = _appear * (1.0 if enabled else 0.45)
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(Run.INK.r, Run.INK.g, Run.INK.b, 0.95 * a)
			sb.border_color = Run.GOLD.lerp(Color(1, 1, 1), hv * 0.5)
			sb.border_color.a = a
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(14)
			sb.shadow_color = Color(Run.TEAL.r, Run.TEAL.g, Run.TEAL.b, (0.12 + 0.4 * hv) * a)
			sb.shadow_size = int(8.0 + 10.0 * hv)
			draw_style_box(sb, r)
			var id: String = String(o.get("item", ""))
			var y: float = r.position.y + 14.0
			if id != "":
				Run.draw_icon(self, id, Rect2(r.position.x + r.size.x * 0.5 - 36.0, y, 72.0, 72.0), _t, hv)
				y += 96.0
				var nw: int = Lexicon.word_for("item:" + id).size()
				Run.draw_word(self, "item:" + id, Vector2(r.position.x + (r.size.x - nw * 21.0) * 0.5, y + 4.0), 20.0, Color(Run.GOLD, a))
				if Lexicon.is_known("item:" + id) or Meta.is_item_known(id):
					draw_string(f, Vector2(r.position.x, y + 30.0), Lexicon.readable_name("item:" + id), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, Color(1, 1, 1, a))
				y += 34.0
			else:
				y += 40.0
			var lab: String = String(o.get("label", ""))
			if lab != "":
				draw_string(f, Vector2(r.position.x, (r.position.y + r.size.y * 0.5) if (compact or id == "") else y + 4.0), lab,
						HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, Color(Run.GOLD, a))
			var s: String = String(o.get("sub", ""))
			if s != "":
				draw_string(f, Vector2(r.position.x, r.position.y + r.size.y - 16.0 if not compact else r.position.y + r.size.y * 0.5 + 20.0),
						s, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15, Color(Run.TEAL, a))
