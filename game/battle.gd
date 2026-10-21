class_name Battle
extends Control
## Battle screen. Transparent root (Run composites the garden behind it). Drives Combat via its API.
## Layout (design 960x640): player left on the ground line, enemies right, BackpackUI bottom-centre.

signal finished(won: bool, player_state: Dictionary)

const GROUND := 0.80
const GOLD := Color(1.0, 0.82, 0.38)
const TEAL := Color(0.10, 0.80, 0.62)
const VIOLET := Color(0.55, 0.30, 0.95)
const MAGENTA := Color(0.95, 0.30, 0.75)
const CYAN := Color(0.45, 0.95, 1.0)
const INK := Color(0.03, 0.03, 0.07)
const RED := Color(1.0, 0.38, 0.42)
const GREEN := Color(0.45, 1.0, 0.6)

var combat: Combat
var bp
var hero_id := "seshat"
var ui: Control = null
var fallback_row: HBoxContainer = null

var _state_in: Dictionary = {}
var _t := 0.0
var _stop := 0.0
var _shake := 0.0
var _busy := 0.0
var _target := 0
var _floaters: Array = []
var _sparks: Array = []
var _es: Array = []            # per-enemy visual state
var _p_hurt := 0.0
var _p_lunge := 0.0
var _toast := ""
var _toast_t := 0.0
var _banner_t := -1.0
var _done := false
var _hover_end := false
var _prev: Dictionary = {}
var _sfx_node: Node = null
var _box_cache: Dictionary = {}
var _intro := 0.0
var _creature = null
var _icons = null


func start(p_bp, enemy_ids: Array, player_state: Dictionary, p_hero_id: String, rng: RandomNumberGenerator) -> void:
	bp = p_bp
	hero_id = p_hero_id
	_state_in = player_state.duplicate(true)
	combat = Combat.new()
	combat.secret_found.connect(_on_secret)
	combat.enemy_trait_revealed.connect(_on_trait)
	combat.damage_dealt.connect(_on_damage)
	combat.changed.connect(_on_changed)
	combat.ended.connect(_on_ended)
	combat.start(bp, enemy_ids, player_state, rng)
	for e in combat.enemies:
		Meta.see_enemy(String(e["id"]))
	_creature = load("res://game/creature_art.gd")
	_icons = load("res://game/item_icons.gd")
	_es.clear()
	_sync_es()
	_snapshot()
	_build_ui()
	_intro = 0.0
	set_process(true)
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_process(true)


# ------------------------------------------------------------ layout helpers

func _sz() -> Vector2:
	return size if size.x > 10.0 else Vector2(960, 640)


func _ground_y() -> float:
	return _sz().y * GROUND


func _player_center() -> Vector2:
	var s := _sz()
	return Vector2(s.x * 0.135 + _p_lunge * 90.0, _ground_y() - 70.0)


func _enemy_slot(i: int) -> Dictionary:
	var s := _sz()
	var n := maxi(combat.enemies.size(), 1)
	var sp := minf(160.0, (s.x * 0.36) / float(n))
	var sc: float = float(combat.enemies[i]["scale"])
	var sz := minf(115.0, sp * 0.95) * clampf(sc, 0.5, 1.4)
	var x := s.x * 0.94 - sz * 0.5 - float(i) * sp
	var lunge: float = _es[i]["lunge"] if i < _es.size() else 0.0
	return {"c": Vector2(x - lunge * 100.0, _ground_y() - sz * 0.55), "size": sz}


func _end_rect() -> Rect2:
	var s := _sz()
	return Rect2(s.x * 0.80, s.y * 0.895, s.x * 0.16, s.y * 0.075)


func _build_ui() -> void:
	if ui != null:
		ui.queue_free()
		ui = null
	if fallback_row != null:
		fallback_row.queue_free()
		fallback_row = null
	var s := _sz()
	var rect := Rect2(s.x * 0.25, s.y * 0.51, s.x * 0.36, s.y * 0.475)
	var scr = load("res://game/backpack_ui.gd") if ResourceLoader.exists("res://game/backpack_ui.gd") else null
	if scr != null:
		ui = scr.new()
		add_child(ui)
		ui.position = rect.position
		ui.size = rect.size
		if ui.has_method("setup"):
			ui.setup(bp, "combat")
		ui.custom_minimum_size = Vector2.ZERO   # the pack scales its cells to fit the battle strip
		ui.size = rect.size
		if ui.has_signal("item_clicked"):
			ui.item_clicked.connect(_on_item_clicked)
		_push_ui()
	else:
		fallback_row = HBoxContainer.new()
		add_child(fallback_row)
		fallback_row.position = Vector2(s.x * 0.2, s.y * 0.9)
		for uid in bp.uids():
			var def: Dictionary = combat._def_of(uid)
			if String(def.get("kind", "")) != "active":
				continue
			var b := Button.new()
			b.text = "%s (%d)" % [String(def.get("name", "?")), int(def.get("cost", 0))]
			b.pressed.connect(_on_item_clicked.bind(uid))
			fallback_row.add_child(b)


func _push_ui() -> void:
	if ui == null:
		return
	ui.set("energy", int(combat.player["energy"]))
	var u: Array = []
	u.append_array(combat.used)
	for x in combat.used_consumables:
		if not u.has(x):
			u.append(x)
	ui.set("used", u)
	if ui.has_method("refresh"):
		ui.refresh()


# ------------------------------------------------------------ juice + feedback

func _sfx(n: String) -> void:
	Hub.sfx(n)


func _sync_es() -> void:
	while _es.size() < combat.enemies.size():
		_es.append({"hurt": 0.0, "lunge": 0.0, "lunge_delay": 0.0, "appear": 0.0, "fade": 1.0, "was_alive": true})


func _snapshot() -> void:
	_prev = {"php": int(combat.player["hp"]), "pb": int(combat.player["block"]), "pe": int(combat.player["energy"]), "e": []}
	for e in combat.enemies:
		_prev["e"].append([int(e["hp"]), int(e["block"])])


func _float(pos: Vector2, text: String, col: Color, big := 1.0) -> void:
	_floaters.append({"p": pos, "t": text, "c": col, "age": 0.0, "big": big, "dx": randf_range(-14.0, 14.0)})


func _burst(pos: Vector2, col: Color, n: int, spd := 160.0) -> void:
	for i in n:
		var a := randf() * TAU
		_sparks.append({"p": pos, "v": Vector2(cos(a), sin(a)) * randf_range(0.3, 1.0) * spd, "age": 0.0, "life": randf_range(0.4, 0.9), "c": col})


func _on_damage(target: String, amount: int, index: int) -> void:
	if target == "player" or index < 0:
		var pc := _player_center()
		_p_hurt = 1.0
		_shake = maxf(_shake, 4.0 + minf(float(amount), 20.0) * 0.5)
		_stop = 0.07
		if amount > 0:
			_float(pc + Vector2(0, -70), str(amount), RED, 1.0 + minf(float(amount), 20.0) * 0.02)
			_sfx("hit_player")
			_burst(pc, RED, 8)
		else:
			_float(pc + Vector2(0, -70), "0", CYAN, 0.9)
			_sfx("block")
	else:
		_sync_es()
		if index < _es.size():
			_es[index]["hurt"] = 1.0
			var sl := _enemy_slot(index)
			var c: Vector2 = sl["c"]
			if amount > 0:
				_float(c + Vector2(0, -sl["size"] * 0.5), str(amount), GOLD, 1.0 + minf(float(amount), 20.0) * 0.02)
				_shake = maxf(_shake, 3.0 + minf(float(amount), 20.0) * 0.4)
				_stop = 0.06
				_burst(c, MAGENTA, 8)
				_sfx("hit_enemy")
			else:
				_float(c + Vector2(0, -sl["size"] * 0.5), "0", CYAN, 0.9)
				_sfx("block")


func _on_changed() -> void:
	_sync_es()
	var pb: int = int(combat.player["block"])
	var php: int = int(combat.player["hp"])
	var pc := _player_center()
	if not _prev.is_empty():
		if pb > int(_prev["pb"]):
			_float(pc + Vector2(30, -40), "+%d" % (pb - int(_prev["pb"])), CYAN, 0.9)
			_sfx("block")
		if php > int(_prev["php"]):
			_float(pc + Vector2(-30, -60), "+%d" % (php - int(_prev["php"])), GREEN, 1.0)
			_sfx("heal")
		var pe: Array = _prev["e"]
		for i in mini(pe.size(), combat.enemies.size()):
			var e: Dictionary = combat.enemies[i]
			var sl := _enemy_slot(i)
			if int(e["block"]) > int(pe[i][1]):
				_float(sl["c"] + Vector2(20, -sl["size"] * 0.4), "+%d" % (int(e["block"]) - int(pe[i][1])), CYAN, 0.85)
			if int(e["hp"]) > int(pe[i][0]):
				_float(sl["c"] + Vector2(-20, -sl["size"] * 0.5), "+%d" % (int(e["hp"]) - int(pe[i][0])), GREEN, 0.9)
	for i in combat.enemies.size():
		var alive: bool = bool(combat.enemies[i]["alive"])
		if _es[i]["was_alive"] and not alive:
			_es[i]["was_alive"] = false
			var sl := _enemy_slot(i)
			_burst(sl["c"], VIOLET, 22, 220.0)
			_burst(sl["c"], TEAL, 14, 120.0)
			_shake = maxf(_shake, 7.0)
	if _target >= combat.enemies.size() or not bool(combat.enemies[_target]["alive"]):
		_target = 0
		for i in combat.enemies.size():
			if bool(combat.enemies[i]["alive"]):
				_target = i
				break
	_snapshot()
	_push_ui()


func _on_secret(item_id: String, secret_id: String) -> void:
	Meta.discover_secret(item_id, secret_id)
	_say("something stirred...")
	_sfx("secret_found")


func _on_trait(enemy_id: String, trait_name: String) -> void:
	Meta.discover_trait(enemy_id, trait_name)
	_say("something stirred...")
	_sfx("secret_found")


func _say(txt: String) -> void:
	_toast = txt
	_toast_t = 2.6


func _on_ended(victory: bool) -> void:
	_banner_t = 0.0
	_sfx("win" if victory else "lose")


# ------------------------------------------------------------ input / actions

func _on_item_clicked(uid: int) -> void:
	if _busy > 0.0 or combat.is_over() or not combat.can_use(uid):
		return
	Hub.item(String(bp.id_of(uid)))
	var links: int = bp.neighbors(uid).size()
	if links > 0:
		Hub.synergy(links)
	combat.use(uid, _target)


func do_end_turn() -> void:
	if _busy > 0.0 or combat.is_over():
		return
	_sfx("end_turn")
	var k := 0
	for i in combat.enemies.size():
		var e: Dictionary = combat.enemies[i]
		if bool(e["alive"]) and String(e["intent"].get("type", "")) == "attack":
			_es[i]["lunge_delay"] = 0.15 + 0.3 * k
			k += 1
	combat.end_turn()
	_busy = 0.5 + 0.3 * k


func _gui_input(ev: InputEvent) -> void:
	if combat == null:
		return
	if ev is InputEventMouseMotion:
		_hover_end = _end_rect().has_point(ev.position)
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if _end_rect().has_point(ev.position):
			do_end_turn()
			accept_event()
			return
		for i in combat.enemies.size():
			if bool(combat.enemies[i]["alive"]):
				var sl := _enemy_slot(i)
				if Rect2(sl["c"] - Vector2(sl["size"], sl["size"]) * 0.5, Vector2(sl["size"], sl["size"])).has_point(ev.position):
					_target = i
					_sfx("ui_click")
					accept_event()
					return


func _unhandled_key_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and (ev.keycode == KEY_SPACE or ev.keycode == KEY_ENTER):
		do_end_turn()


## Test hook: one automatic action (use first affordable item, else end turn). Returns false when over.
func auto_step() -> bool:
	if combat == null or combat.is_over():
		return false
	_busy = 0.0
	for uid in bp.uids():
		if combat.can_use(uid):
			_on_item_clicked(uid)
			return true
	do_end_turn()
	_busy = 0.0
	return true


# ------------------------------------------------------------ frame

func _process(delta: float) -> void:
	if combat == null:
		return
	if _stop > 0.0:
		_stop -= delta
		return
	_t += delta
	_intro = minf(_intro + delta * 2.0, 1.0)
	_busy = maxf(_busy - delta, 0.0)
	_shake = maxf(_shake - delta * 28.0, 0.0)
	_p_hurt = maxf(_p_hurt - delta * 3.0, 0.0)
	_toast_t = maxf(_toast_t - delta, 0.0)
	if _p_lunge > 0.0:
		_p_lunge = maxf(_p_lunge - delta * 4.0, 0.0)
	for i in _es.size():
		var s: Dictionary = _es[i]
		s["hurt"] = maxf(s["hurt"] - delta * 3.0, 0.0)
		s["appear"] = minf(s["appear"] + delta * 2.5, 1.0)
		if s["lunge_delay"] > 0.0:
			s["lunge_delay"] -= delta
			if s["lunge_delay"] <= 0.0:
				s["lunge"] = 1.0
		elif s["lunge"] > 0.0:
			s["lunge"] = maxf(s["lunge"] - delta * 3.5, 0.0)
		if not bool(combat.enemies[i]["alive"]):
			s["fade"] = maxf(s["fade"] - delta * 2.0, 0.0)
	for f in _floaters:
		f["age"] += delta
	_floaters = _floaters.filter(func(f): return f["age"] < 1.1)
	for sp in _sparks:
		sp["age"] += delta
		sp["p"] += sp["v"] * delta
		sp["v"] *= 0.94
	_sparks = _sparks.filter(func(sp): return sp["age"] < sp["life"])
	if _banner_t >= 0.0 and not _done:
		_banner_t += delta
		if _banner_t > 1.8:
			_done = true
			var out := _state_in.duplicate(true)
			out["hp"] = maxi(int(combat.player["hp"]), 0)
			out["max_hp"] = int(combat.player["max_hp"])
			finished.emit(combat.won, out)
	queue_redraw()


# ------------------------------------------------------------ drawing

func _box(fill: Color, rim: Color, r := 10, w := 2) -> StyleBoxFlat:
	var key := "%s%s%d%d" % [fill, rim, r, w]
	if _box_cache.has(key):
		return _box_cache[key]
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = rim
	b.set_border_width_all(w)
	b.set_corner_radius_all(r)
	b.shadow_color = Color(rim.r, rim.g, rim.b, 0.25)
	b.shadow_size = 6
	_box_cache[key] = b
	return b


func _text(p: Vector2, txt: String, sz: int, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER, w := -1.0) -> void:
	var f := ThemeDB.fallback_font
	var ww := w if w > 0.0 else 200.0
	var x := p.x - ww * 0.5 if align == HORIZONTAL_ALIGNMENT_CENTER else p.x
	draw_string_outline(f, Vector2(x, p.y), txt, align, ww, sz, 4, Color(0, 0, 0, col.a * 0.8))
	draw_string(f, Vector2(x, p.y), txt, align, ww, sz, col)


func _glow(p: Vector2, r: float, col: Color, a := 0.5) -> void:
	for k in 4:
		var f := float(4 - k) / 4.0
		draw_circle(p, r * (0.5 + f * 0.9), Color(col.r, col.g, col.b, a * 0.2 * (1.0 - f * 0.6)))


func _bar(rect: Rect2, frac: float, col: Color, block: int) -> void:
	draw_style_box(_box(Color(0.02, 0.03, 0.06, 0.88), Color(GOLD.r, GOLD.g, GOLD.b, 0.7), 6, 1), rect.grow(2))
	var fr := rect.grow(-1)
	fr.size.x *= clampf(frac, 0.0, 1.0)
	if fr.size.x > 1.0:
		draw_rect(fr, col)
		draw_rect(Rect2(fr.position, Vector2(fr.size.x, fr.size.y * 0.4)), Color(1, 1, 1, 0.12))
	if block > 0:
		var c := Vector2(rect.position.x - 12.0, rect.get_center().y)
		_shield(c, 11.0)
		_text(c + Vector2(0, 4), str(block), 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 30.0)


func _shield(c: Vector2, r: float) -> void:
	var pts := PackedVector2Array([c + Vector2(-r, -r * 0.8), c + Vector2(r, -r * 0.8), c + Vector2(r * 0.9, r * 0.2), c + Vector2(0, r), c + Vector2(-r * 0.9, r * 0.2)])
	draw_colored_polygon(pts, Color(0.1, 0.35, 0.5, 0.95))
	var ring := pts.duplicate()
	ring.append(pts[0])
	draw_polyline(ring, CYAN, 1.5, true)


func _word(key: String, p: Vector2, sz: float, col: Color) -> float:
	var word: Array = Lexicon.word_for(key) if Lexicon.has_concept(key) else []
	var x := p.x - float(word.size()) * sz * 0.5
	for g in word:
		GlyphGen.draw(self, int(g), Vector2(x + sz * 0.5, p.y), sz * 0.9, col, 1.5)
		x += sz
	return float(word.size()) * sz


func _draw_intent(p: Vector2, intent: Dictionary) -> void:
	var typ := String(intent.get("type", "none"))
	if typ == "none":
		return
	var amt: int = int(intent.get("amount", 0))
	var col := RED
	match typ:
		"block": col = CYAN
		"heal": col = GREEN
		"split": col = VIOLET
	var pulse := 0.5 + 0.5 * sin(_t * 4.0 + p.x)
	_glow(p, 20.0, col, 0.5 + 0.3 * pulse)
	draw_circle(p, 15.0, Color(0.03, 0.04, 0.08, 0.92))
	draw_arc(p, 15.0, 0, TAU, 28, col, 1.6, true)
	match typ:
		"attack":
			draw_line(p + Vector2(-7, 7), p + Vector2(7, -7), col, 2.5, true)
			draw_line(p + Vector2(-8, 3), p + Vector2(-3, 8), col, 2.0, true)
			draw_line(p + Vector2(4, -7), p + Vector2(7, -7), col, 1.5)
			draw_line(p + Vector2(7, -7), p + Vector2(7, -4), col, 1.5)
		"block":
			_shield(p, 8.0)
		"heal":
			draw_line(p + Vector2(-7, 0), p + Vector2(7, 0), col, 3.0)
			draw_line(p + Vector2(0, -7), p + Vector2(0, 7), col, 3.0)
		"split":
			draw_line(p + Vector2(0, 8), p + Vector2(0, 0), col, 2.0)
			draw_line(p, p + Vector2(-7, -8), col, 2.0)
			draw_line(p, p + Vector2(7, -8), col, 2.0)
			draw_circle(p + Vector2(-7, -8), 2.0, col)
			draw_circle(p + Vector2(7, -8), 2.0, col)
	var txt := ""
	if typ != "split" and amt > 0:
		txt = str(amt)
		if int(intent.get("hits", 1)) > 1:
			txt += "x%d" % int(intent["hits"])
	if txt != "":
		_text(p + Vector2(18, 6), txt, 17, col, HORIZONTAL_ALIGNMENT_LEFT, 60.0)


func _draw() -> void:
	if combat == null:
		return
	var s := _sz()
	var gy := _ground_y()
	var sh := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	draw_set_transform(sh, 0.0, Vector2.ONE)
	# ground glow line
	for k in 5:
		draw_line(Vector2(0, gy + k * 2), Vector2(s.x, gy + k * 2), Color(TEAL.r, TEAL.g, TEAL.b, 0.10 - k * 0.018), 2.0)
	# player
	var pc := _player_center()
	draw_circle(Vector2(pc.x, gy + 4), 0.0, Color.TRANSPARENT)
	draw_set_transform(sh + Vector2(pc.x, gy + 2), 0.0, Vector2(1.0, 0.18))
	draw_circle(Vector2.ZERO, 60.0, Color(0, 0, 0, 0.35))
	draw_set_transform(sh, 0.0, Vector2.ONE)
	var grow := ease(_intro, 0.4)
	if _creature != null and _creature.has_method("draw_player"):
		_creature.draw_player(self, bp, hero_id, pc, 120.0, _t, _p_hurt, grow)
	else:
		_glow(pc, 60.0, TEAL, 0.8)
		draw_circle(pc, 28.0, Color(0.1, 0.6, 0.5))
	# player bars + energy
	var hpf := float(combat.player["hp"]) / float(maxi(int(combat.player["max_hp"]), 1))
	var bar := Rect2(pc.x - 64.0, gy - 235.0, 128.0, 12.0)
	_bar(bar, hpf, Color(0.2, 0.85, 0.55), int(combat.player["block"]))
	_text(Vector2(pc.x, bar.position.y - 6.0), "%d / %d" % [combat.player["hp"], combat.player["max_hp"]], 13, Color(1, 1, 1, 0.85))
	var me: int = int(combat.player["max_energy"])
	var en: int = int(combat.player["energy"])
	for i in me:
		var p := Vector2(pc.x - float(me - 1) * 12.0 + float(i) * 24.0, bar.position.y + 30.0)
		if i < en:
			_glow(p, 14.0, GOLD, 0.8 + 0.2 * sin(_t * 3.0 + i))
			draw_circle(p, 7.0, GOLD)
			draw_circle(p, 3.0, Color(1, 1, 0.9))
		else:
			draw_arc(p, 7.0, 0, TAU, 20, Color(GOLD.r, GOLD.g, GOLD.b, 0.35), 1.5, true)
	# enemies
	for i in combat.enemies.size():
		var e: Dictionary = combat.enemies[i]
		var st: Dictionary = _es[i]
		if st["fade"] <= 0.0:
			continue
		var sl := _enemy_slot(i)
		var c: Vector2 = sl["c"]
		var sz: float = sl["size"]
		var a: float = st["fade"] * ease(st["appear"], 0.5)
		var alive: bool = bool(e["alive"])
		draw_set_transform(sh + Vector2(c.x, gy + 2), 0.0, Vector2(1.0, 0.18))
		draw_circle(Vector2.ZERO, sz * 0.42, Color(0, 0, 0, 0.3 * a))
		draw_set_transform(sh, 0.0, Vector2.ONE)
		var def: Dictionary = EnemyDB.get_def(String(e["id"]))
		var art := String(def.get("art", e["id"]))
		if _creature != null and _creature.has_method("draw"):
			_creature.draw(self, art, c, sz, _t + float(i), st["hurt"], 1.0)
		else:
			_glow(c, sz * 0.4, VIOLET, 0.7)
			draw_circle(c, sz * 0.25, Color(0.4, 0.2, 0.7))
		if not alive:
			draw_circle(c, sz * 0.6 * (2.0 - st["fade"]), Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.15 * st["fade"]))
			continue
		if i == _target and combat.enemies.size() > 1:
			var rr := sz * 0.55 + 3.0 * sin(_t * 4.0)
			draw_arc(Vector2(c.x, gy - 4), rr * 0.55, 0, TAU, 32, Color(GOLD.r, GOLD.g, GOLD.b, 0.55), 1.5, true)
		var top := c.y - sz * 0.62
		var bw := maxf(sz * 0.8, 70.0)
		var br := Rect2(c.x - bw * 0.5, top, bw, 9.0)
		_bar(br, float(e["hp"]) / float(maxi(int(e["max_hp"]), 1)), Color(0.85, 0.3, 0.55), int(e["block"]))
		_text(Vector2(c.x + bw * 0.5 + 2, top + 9), "%d" % int(e["hp"]), 11, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_LEFT, 40.0)
		_draw_intent(Vector2(c.x - 10.0, top - 28.0), e["intent"])
		var key := "enemy:" + String(e["id"])
		var wy := top - 62.0
		_word(key, Vector2(c.x, wy), 16.0, Color(GOLD.r, GOLD.g, GOLD.b, 0.85))
		var nm := Lexicon.display_name(key)
		if nm != "":
			_text(Vector2(c.x, wy - 14.0), nm, 11, Color(1, 0.95, 0.8, 0.8))
	# sparks
	for sp in _sparks:
		var al: float = 1.0 - float(sp["age"]) / float(sp["life"])
		var cc: Color = sp["c"]
		draw_circle(sp["p"], 2.5 * al + 0.5, Color(cc.r, cc.g, cc.b, al))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# turn badge
	_text(Vector2(s.x * 0.5, 30.0), "turn %d" % combat.turn, 14, Color(GOLD.r, GOLD.g, GOLD.b, 0.6))
	# end turn button
	var er := _end_rect()
	var can := _busy <= 0.0 and not combat.is_over()
	var rim := GOLD if (_hover_end and can) else Color(GOLD.r, GOLD.g, GOLD.b, 0.65 if can else 0.25)
	draw_style_box(_box(Color(0.04, 0.04, 0.09, 0.92), rim, 12, 2), er)
	_text(er.get_center() + Vector2(0, 6), "end turn", 18, Color(GOLD.r, GOLD.g, GOLD.b, 1.0 if can else 0.4), HORIZONTAL_ALIGNMENT_CENTER, er.size.x)
	# floaters
	for f in _floaters:
		var k: float = f["age"] / 1.1
		var p: Vector2 = f["p"] + Vector2(f["dx"] * k, -60.0 * ease(k, 0.4))
		var col: Color = f["c"]
		col.a = 1.0 - ease(k, 3.0)
		_text(p, String(f["t"]), int(24.0 * float(f["big"]) * (1.0 + 0.4 * maxf(0.0, 1.0 - k * 6.0))), col, HORIZONTAL_ALIGNMENT_CENTER, 120.0)
	# toast
	if _toast_t > 0.0:
		var ta := clampf(minf(_toast_t, 2.6 - _toast_t) * 3.0, 0.0, 1.0)
		var tr := Rect2(s.x * 0.5 - 120.0, 54.0 - 6.0 * (1.0 - ta), 240.0, 30.0)
		draw_style_box(_box(Color(0.04, 0.03, 0.1, 0.7 * ta), Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.6 * ta), 15, 1), tr)
		_text(tr.get_center() + Vector2(0, 5), _toast, 14, Color(0.85, 0.75, 1.0, ta), HORIZONTAL_ALIGNMENT_CENTER, tr.size.x)
	# banner
	if _banner_t >= 0.0:
		var k2 := ease(clampf(_banner_t / 0.6, 0.0, 1.0), 0.4)
		var won := combat.won
		var bc := GOLD if won else MAGENTA
		draw_rect(Rect2(0, 0, s.x, s.y), Color(0, 0, 0.02, 0.45 * k2))
		var hh := 110.0 * k2
		var br2 := Rect2(0, s.y * 0.38 - hh * 0.5, s.x, hh)
		draw_rect(br2, Color(0.02, 0.02, 0.06, 0.9))
		draw_line(br2.position, br2.position + Vector2(s.x, 0), Color(bc.r, bc.g, bc.b, 0.8), 2.0)
		draw_line(br2.end - Vector2(s.x, 0), br2.end, Color(bc.r, bc.g, bc.b, 0.8), 2.0)
		if k2 > 0.7:
			_glow(Vector2(s.x * 0.5, s.y * 0.38), 90.0, bc, 0.4)
			_text(Vector2(s.x * 0.5, s.y * 0.38 + 6.0), "the garden exhales" if won else "the pack grows light", 34, Color(bc.r, bc.g, bc.b, k2), HORIZONTAL_ALIGNMENT_CENTER, s.x)
