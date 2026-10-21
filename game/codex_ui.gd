class_name CodexUI
extends Control
## The player's notebook of the secret glyph language. Tabs per Lexicon category, plus Bestiary and Secrets.
## Opened/closed by Hub (C key / book icon). While open it swallows mouse and key input so a Battle underneath
## never sees it; game logic keeps running. Unknown words take a pencilled guess (Lexicon.guess); a right guess
## resolves the card with a glow burst and Sfx 'glyph_learn'.

signal closed
signal learned(key: String)

const TAB_NAMES: Array[String] = ["Items", "Bonuses", "Places", "Beasts", "Heroes", "Origins", "Acts", "Qualities", "Bestiary", "Secrets"]
const TAB_BESTIARY := 8
const TAB_SECRETS := 9
const CARD := Vector2(158, 104)
const GAP := 12.0

var is_open := false
var tab := 0
var selected := ""
var scroll := 0.0
var wrong_tries: Dictionary = {}     # key -> int (this sitting only; drives the hints)
var _t := 0.0
var _appear := 0.0
var _flash: Dictionary = {}          # key -> seconds since it resolved
var _msg := ""
var _msg_t := 0.0
var _msg_col := Color.WHITE
var _hits: Array = []                # [Rect2, kind, payload]
var _edit: LineEdit
var _entries: Array = []             # [{key,kind,...}]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	_edit = LineEdit.new()
	_edit.placeholder_text = "write your guess in ink..."
	_edit.max_length = 28
	_edit.add_theme_font_override("font", UiKit.font())
	_edit.add_theme_font_size_override("font_size", 20)
	_edit.add_theme_color_override("font_color", UiKit.CREAM)
	_edit.add_theme_color_override("font_placeholder_color", Color(UiKit.GOLD, 0.35))
	_edit.add_theme_color_override("caret_color", UiKit.CYAN)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.03, 0.9)
	sb.set_border_width_all(0)
	sb.border_width_bottom = 2
	sb.border_color = Color(UiKit.GOLD, 0.6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	_edit.add_theme_stylebox_override("normal", sb)
	_edit.add_theme_stylebox_override("focus", sb)
	_edit.text_submitted.connect(func(s: String) -> void: submit_guess(s))
	_edit.visible = false
	add_child(_edit)


func open(at_tab := -1) -> void:
	if at_tab >= 0:
		tab = clampi(at_tab, 0, TAB_NAMES.size() - 1)
	for k: String in Meta.guesses:           # re-pencil saved guesses into the live lexicon
		if Lexicon.guess_of(k) == "":
			Lexicon.guess(k, str(Meta.guesses[k]))
	is_open = true
	visible = true
	_appear = 0.0
	scroll = 0.0
	selected = ""
	_rebuild()
	Hub.sfx("ui_click")
	queue_redraw()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	_edit.visible = false
	_edit.release_focus()
	closed.emit()


func select_tab(i: int) -> void:
	tab = clampi(i, 0, TAB_NAMES.size() - 1)
	scroll = 0.0
	selected = ""
	_rebuild()
	queue_redraw()


func select_key(key: String) -> void:
	selected = key
	_edit.text = Lexicon.guess_of(key)
	queue_redraw()


## Writes the guess in ink. Returns true when it was right (the card resolves).
func submit_guess(text: String) -> bool:
	var key := selected
	if key == "" or not Lexicon.has_concept(key) or Lexicon.is_known(key):
		return false
	Lexicon.guess(key, text)
	Meta.set_guess(key, text)
	if text.strip_edges() == "":
		return false
	if Lexicon.confirm_guess_if_correct(key):
		Meta.mark_known(key)
		_flash[key] = 0.0
		_say("The glyphs yield. It is read.", UiKit.GOLD)
		Hub.sfx("glyph_learn")
		learned.emit(key)
		_edit.visible = false
		_rebuild()
		return true
	wrong_tries[key] = int(wrong_tries.get(key, 0)) + 1
	_say("The ink sinks in. The glyphs do not answer.", UiKit.VIOLET)
	Hub.sfx("ui_click")
	return false


func _say(s: String, c: Color) -> void:
	_msg = s
	_msg_col = c
	_msg_t = 4.0


func _rebuild() -> void:
	_entries.clear()
	if tab == TAB_BESTIARY:
		for id: String in Meta.bestiary:
			_entries.append({"key": "enemy:" + id, "kind": "beast", "id": id})
	elif tab == TAB_SECRETS:
		for k: String in Meta.discovered_secrets:
			var p: PackedStringArray = k.split("/")
			if p.size() == 2:
				_entries.append({"key": "secret:" + k, "kind": "secret", "item": p[0], "sid": p[1]})
	else:
		for k in Lexicon.all_keys(tab):
			_entries.append({"key": k, "kind": "word"})


# ------------------------------------------------------------ layout

func _panel() -> Rect2:
	var s := size if size.x > 10.0 else Vector2(960, 640)
	var w := minf(s.x - 40.0, 1060.0)
	var h := minf(s.y - 40.0, 680.0)
	return Rect2((s - Vector2(w, h)) * 0.5, Vector2(w, h))


func _grid_rect() -> Rect2:
	var p := _panel()
	return Rect2(p.position + Vector2(206, 92), Vector2(p.size.x - 206 - 26, p.size.y - 92 - 150))


func _detail_rect() -> Rect2:
	var p := _panel()
	return Rect2(p.position + Vector2(206, p.size.y - 140), Vector2(p.size.x - 206 - 26, 118))


func _cols() -> int:
	return maxi(1, int((_grid_rect().size.x + GAP) / (CARD.x + GAP)))


func _max_scroll() -> float:
	var rows := ceili(float(_entries.size()) / float(_cols()))
	return maxf(0.0, rows * (CARD.y + GAP) - _grid_rect().size.y)


func _process(dt: float) -> void:
	if not is_open:
		return
	_t += dt
	_appear = minf(1.0, _appear + dt * 3.0)
	_msg_t = maxf(0.0, _msg_t - dt)
	for k: String in _flash.keys():
		_flash[k] = float(_flash[k]) + dt
		if float(_flash[k]) > 3.0:
			_flash.erase(k)
	var d := _detail_rect()
	var show_edit := selected != "" and tab < TAB_BESTIARY and not Lexicon.is_known(selected)
	_edit.visible = show_edit
	if show_edit:
		_edit.position = d.position + Vector2(240, d.size.y - 46)
		_edit.size = Vector2(d.size.x - 270, 34)
	queue_redraw()


# ------------------------------------------------------------ input

func _gui_input(ev: InputEvent) -> void:
	if not is_open:
		return
	if ev is InputEventMouseButton and ev.pressed:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll = clampf(scroll + 54.0, 0.0, _max_scroll())
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll = clampf(scroll - 54.0, 0.0, _max_scroll())
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			for h: Array in _hits:
				if (h[0] as Rect2).has_point(mb.position):
					match h[1]:
						"tab":
							select_tab(int(h[2]))
							Hub.sfx("ui_click")
						"card":
							select_key(str(h[2]))
							Hub.sfx("ui_click")
						"close":
							close()
					break
	accept_event()


func _input(ev: InputEvent) -> void:
	if not is_open:
		return
	if ev is InputEventKey and ev.pressed:
		var k := (ev as InputEventKey).keycode
		if k == KEY_ESCAPE or (k == KEY_C and not _edit.has_focus()):
			if not ev.echo:
				close()
			get_viewport().set_input_as_handled()
		elif k == KEY_TAB and not _edit.has_focus():
			select_tab((tab + 1) % TAB_NAMES.size())
			get_viewport().set_input_as_handled()
		elif not _edit.has_focus():
			get_viewport().set_input_as_handled()      # nothing leaks into the Battle


# ------------------------------------------------------------ drawing

func _draw() -> void:
	if not is_open:
		return
	var s := size if size.x > 10.0 else Vector2(960, 640)
	var a: float = UiKit.ease_out(_appear)
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.01, 0.01, 0.03, 0.72 * a))
	var p := _panel()
	UiKit.panel(self, p, UiKit.VIOLET, 0.25 + 0.1 * sin(_t * 1.3), a, 22)
	_hits.clear()
	var ga := a
	# title + fractal progress bloom
	UiKit.text(self, "CODEX", p.position + Vector2(206, 56), 34, Color(UiKit.GOLD, ga))
	var sub := "the book of the unspoken tongue"
	UiKit.text(self, sub, p.position + Vector2(206, 78), 15, Color(UiKit.CYAN, 0.55 * ga))
	var frac := Lexicon.known_fraction(tab if tab < TAB_BESTIARY else -1)
	var bc := p.position + Vector2(p.size.x - 110, 56)
	_bloom(bc, 24.0, 3, frac, ga)
	UiKit.text(self, "%d%%" % int(round(frac * 100.0)), bc + Vector2(-30, 52), 14, Color(UiKit.GOLD, 0.8 * ga), 60.0, HORIZONTAL_ALIGNMENT_CENTER)
	# close
	var cr := Rect2(p.position + Vector2(p.size.x - 40, 8), Vector2(30, 28))
	_hits.append([cr, "close"])
	UiKit.text(self, "x", cr.position + Vector2(8, 22), 22, Color(UiKit.GOLD, 0.7 * ga))
	# tabs
	for i in TAB_NAMES.size():
		var r := Rect2(p.position + Vector2(18, 24 + i * 50), Vector2(172, 44))
		_hits.append([r, "tab", i])
		var on := i == tab
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.03, 0.03, 0.05, 0.9) if not on else Color(0.12, 0.07, 0.2, 0.95)
		sb.set_corner_radius_all(10)
		sb.set_border_width_all(2 if on else 1)
		sb.border_color = Color(UiKit.GOLD if on else UiKit.VIOLET, (0.9 if on else 0.35) * ga)
		if on:
			sb.shadow_color = Color(UiKit.VIOLET, 0.4)
			sb.shadow_size = 12
		draw_style_box(sb, r)
		var ic := r.position + Vector2(24, 22)
		if i < TAB_BESTIARY:
			var det := _determinative(i)
			if det >= 0:
				GlyphGen.draw(self, det, ic, 26.0, Color(UiKit.GOLD if on else UiKit.CYAN, (1.0 if on else 0.65) * ga), 2.0)
		elif i == TAB_BESTIARY:
			draw_circle(ic, 7, Color(UiKit.TEAL, 0.7 * ga))
			draw_circle(ic + Vector2(2, 0), 3, Color(0, 0, 0, 0.9))
		else:
			_star(ic, 9.0, Color(UiKit.MAGENTA, 0.8 * ga))
		UiKit.text(self, TAB_NAMES[i], r.position + Vector2(50, 28), 19, Color(UiKit.CREAM if on else Color(0.75, 0.7, 0.62), ga))
	_draw_grid(a)
	_draw_detail(a)


func _determinative(cat: int) -> int:
	var keys: Array[String] = Lexicon.all_keys(cat)
	if keys.is_empty():
		return -1
	var w: Array[int] = Lexicon.word_for(keys[0])
	return w[0] if not w.is_empty() else -1


func _draw_grid(a: float) -> void:
	var g := _grid_rect()
	if _entries.is_empty():
		_empty_state(g, a)
		return
	scroll = clampf(scroll, 0.0, _max_scroll())
	var cols := _cols()
	for i in _entries.size():
		var cr := Rect2(g.position + Vector2((i % cols) * (CARD.x + GAP), (i / cols) * (CARD.y + GAP) - scroll), CARD)
		if cr.end.y < g.position.y or cr.position.y > g.end.y:
			continue
		var vis := cr.intersection(g)
		if vis.size.y < CARD.y * 0.5:
			continue
		var e: Dictionary = _entries[i]
		_hits.append([vis, "card", e["key"]])
		_draw_card(cr, e, a)


func _draw_card(r: Rect2, e: Dictionary, a: float) -> void:
	var key: String = e["key"]
	var kind: String = e["kind"]
	var sel := key == selected
	var known := kind == "word" and Lexicon.is_known(key)
	var fl := float(_flash.get(key, 99.0))
	var tint := UiKit.GOLD if known else (UiKit.VIOLET if Lexicon.guess_of(key) == "" else UiKit.CYAN)
	if kind == "beast":
		tint = UiKit.TEAL
	elif kind == "secret":
		tint = UiKit.MAGENTA
	UiKit.panel(self, r, tint, (0.9 if sel else 0.0) + (maxf(0.0, 1.0 - fl) if fl < 1.0 else 0.0), a, 12)
	var c := r.position + Vector2(r.size.x * 0.5, 38)
	match kind:
		"word":
			var col := Color(UiKit.GOLD if known else UiKit.CYAN, a * (0.95 if known else 0.7 + 0.15 * sin(_t * 2.0 + r.position.x)))
			UiKit.word(self, key, c, 26.0, col, 2.0)
			var line := ""
			var lc := UiKit.CREAM
			if known:
				line = Lexicon.readable_name(key)
			elif Lexicon.guess_of(key) != "":
				line = Lexicon.guess_of(key) + " ?"
				lc = Color(UiKit.CYAN, 0.55)
			else:
				line = ". . ."
				lc = Color(UiKit.VIOLET, 0.5)
			UiKit.text(self, line, r.position + Vector2(8, 88), 17, Color(lc, a * (clampf(fl, 0.0, 1.0) if fl < 1.0 else 1.0)), r.size.x - 16, HORIZONTAL_ALIGNMENT_CENTER)
		"beast":
			var id: String = e["id"]
			CreatureArt.draw(self, id, r.position + Vector2(r.size.x * 0.5, 44), 62.0, _t)
			var nm := Lexicon.display_name("enemy:" + id)
			if nm == "":
				UiKit.word(self, "enemy:" + id, r.position + Vector2(r.size.x * 0.5, 88), 14.0, Color(UiKit.CYAN, 0.7 * a), 1.5)
			else:
				UiKit.text(self, nm, r.position + Vector2(8, 94), 16, Color(UiKit.CREAM, a), r.size.x - 16, HORIZONTAL_ALIGNMENT_CENTER)
		"secret":
			var item: String = e["item"]
			UiKit.icon(self, item, Rect2(r.position + Vector2(r.size.x * 0.5 - 24, 8), Vector2(48, 48)), _t, 0.3)
			var nm2 := Lexicon.display_name("item:" + item) if Meta.is_item_known(item) or Lexicon.is_known("item:" + item) else ""
			if nm2 == "":
				UiKit.word(self, "item:" + item, r.position + Vector2(r.size.x * 0.5, 82), 14.0, Color(UiKit.CYAN, 0.7 * a), 1.5)
			else:
				UiKit.text(self, nm2, r.position + Vector2(8, 90), 16, Color(UiKit.CREAM, a), r.size.x - 16, HORIZONTAL_ALIGNMENT_CENTER)
	if fl < 2.0:                              # resolution burst
		var k := fl / 2.0
		for i in 3:
			draw_arc(c, 20.0 + 70.0 * UiKit.ease_out(k) + i * 8.0, 0, TAU, 40, Color(UiKit.GOLD, (1.0 - k) * 0.7), 2.0)
		UiKit.glow(self, c, 60.0 * (1.0 - k * 0.5), Color(UiKit.GOLD, 1.0 - k))


func _empty_state(g: Rect2, a: float) -> void:
	var c := g.get_center() + Vector2(0, -20)
	_bloom(c, 70.0, 4, 0.0, a * 0.8)
	var s1 := "Nothing is written here yet."
	var s2 := "Go below. Look. The pages remember what you survive."
	if tab == TAB_SECRETS:
		s2 = "Some things are only found when they are placed beside one another."
	elif tab == TAB_BESTIARY:
		s2 = "Meet a creature and its page begins to fill."
	UiKit.text(self, s1, c + Vector2(-300, 120), 24, Color(UiKit.GOLD, 0.8 * a), 600.0, HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.text(self, s2, c + Vector2(-300, 148), 16, Color(UiKit.CYAN, 0.55 * a), 600.0, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_detail(a: float) -> void:
	var d := _detail_rect()
	UiKit.panel(self, d, UiKit.VIOLET, 0.0, a * 0.8, 14)
	if selected == "":
		var hint := "Choose a word. Not every word wants to be read."
		UiKit.text(self, hint, d.position + Vector2(20, 66), 18, Color(UiKit.GOLD, 0.5 * a), d.size.x - 40, HORIZONTAL_ALIGNMENT_CENTER)
		return
	var lx := d.position + Vector2(20, 0)
	if tab == TAB_SECRETS:
		_secret_detail(d, a)
		return
	if tab == TAB_BESTIARY:
		_beast_detail(d, a)
		return
	UiKit.word(self, selected, d.position + Vector2(110, 52), 34.0, Color(UiKit.GOLD, a), 2.5)
	var known := Lexicon.is_known(selected)
	if known:
		UiKit.text(self, Lexicon.readable_name(selected), lx + Vector2(220, 46), 30, Color(UiKit.CREAM, a))
		var where := "Learned %s." % _where(selected)
		UiKit.text(self, where, lx + Vector2(220, 78), 16, Color(UiKit.CYAN, 0.6 * a), d.size.x - 260)
	else:
		UiKit.text(self, "unread", lx + Vector2(220, 40), 24, Color(UiKit.VIOLET, 0.8 * a))
		UiKit.text(self, _hint(selected), lx + Vector2(220, 64), 15, Color(UiKit.CYAN, 0.6 * a), d.size.x - 260)
	if _msg_t > 0.0:
		UiKit.text(self, _msg, d.position + Vector2(20, d.size.y - 12), 15, Color(_msg_col, minf(1.0, _msg_t) * a), d.size.x - 40, HORIZONTAL_ALIGNMENT_RIGHT)


func _beast_detail(d: Rect2, a: float) -> void:
	var id := selected.trim_prefix("enemy:")
	var info: Dictionary = Meta.bestiary.get(id, {})
	var traits: Array = info.get("traits", [])
	var def: Dictionary = EnemyDB.get_def(id)
	var total: int = (def.get("traits", []) as Array).size()
	var nm := Lexicon.display_name(selected)
	UiKit.text(self, nm if nm != "" else "a creature of the unread tongue", d.position + Vector2(24, 40), 26, Color(UiKit.CREAM, a))
	UiKit.text(self, "Met %d times." % int(info.get("seen", 0)), d.position + Vector2(24, 68), 16, Color(UiKit.CYAN, 0.6 * a))
	var line := ""
	for t in traits:
		line += str(t).capitalize() + "   "
	for i in maxi(0, total - traits.size()):
		line += "?   "
	UiKit.text(self, "Habits: " + (line if line != "" else "unwatched"), d.position + Vector2(24, 96), 17, Color(UiKit.GOLD, 0.85 * a), d.size.x - 48)


func _secret_detail(d: Rect2, a: float) -> void:
	var p: PackedStringArray = selected.trim_prefix("secret:").split("/")
	if p.size() < 2:
		return
	var known: bool = Meta.is_item_known(p[0]) or Lexicon.is_known("item:" + p[0])
	var text := "A thing it does only in the right company. The word for it is still unread."
	if known:
		for s: Dictionary in ItemDB.secrets_of(p[0]):
			if str(s.get("id", "")) == p[1]:
				text = str(s.get("text", text))
	UiKit.text(self, Lexicon.readable_name("item:" + p[0]) if known else "an unread thing", d.position + Vector2(24, 40), 26, Color(UiKit.CREAM, a))
	UiKit.wrapped(self, text, d.position + Vector2(24, 70), 17, Color(UiKit.MAGENTA.lerp(UiKit.CREAM, 0.5), a), d.size.x - 48)


func _where(key: String) -> String:
	match Lexicon.category_of(key):
		Lexicon.CAT_ITEM: return "by handling it"
		Lexicon.CAT_BONUS: return "by watching its effect"
		Lexicon.CAT_LOC: return "on the road"
		Lexicon.CAT_ENEMY: return "in battle"
		Lexicon.CAT_HERO, Lexicon.CAT_ORIGIN: return "from the first dream"
		Lexicon.CAT_ACT: return "from a choice made"
		_: return "in the grain of things"


## Cryptic by design: never the answer, only the shape of the question.
func _hint(key: String) -> String:
	var tries: int = int(wrong_tries.get(key, 0))
	var out := "Its first mark belongs to " + str(Lexicon.PREFIXES[Lexicon.category_of(key)]) + "s."
	var root := Lexicon.root_of(key)
	for k in Lexicon.all_keys():
		if k != key and Lexicon.is_known(k) and root >= 0 and GlyphGen.similarity_hint(root, Lexicon.root_of(k)) > 0.6:
			out = "Its heart rhymes with something you can already read."
			break
	if tries >= 2:
		out += " It is %s." % ("one word" if Lexicon.readable_name(key).find(" ") < 0 else "more than one word")
	if tries >= 4:
		out += " Your tongue begins it with a '%s'." % Lexicon.readable_name(key).substr(0, 1).to_upper()
	return out


## Fractal bloom: nested petals, lit in order as `frac` of the lexicon is known.
func _bloom(c: Vector2, r: float, depth: int, frac: float, a: float) -> void:
	var total := 0
	for d in depth:
		total += int(pow(5.0, d + 1))
	var idx := [0]
	UiKit.glow(self, c, r * 1.3, Color(UiKit.TEAL, 0.25 * a * (0.3 + frac)))
	_petals(c, r, depth, -PI / 2, frac, total, idx, a)
	draw_circle(c, 3.0 + 3.0 * frac, Color(UiKit.GOLD, a))


func _petals(c: Vector2, r: float, depth: int, base: float, frac: float, total: int, idx: Array, a: float) -> void:
	if depth <= 0 or r < 3.0:
		return
	for i in 5:
		var ang := base + TAU * float(i) / 5.0
		var tip := c + Vector2.from_angle(ang) * r
		var lit := float(idx[0]) / float(total) < frac
		idx[0] += 1
		var col := Color(UiKit.GOLD if lit else UiKit.VIOLET, a * (0.9 if lit else 0.3))
		draw_line(c, tip, col, maxf(1.0, r * 0.05))
		draw_circle(tip, maxf(1.5, r * 0.09), col)
		_petals(tip, r * 0.42, depth - 1, ang, frac, total, idx, a)


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		pts.append(c + Vector2.from_angle(PI * 0.25 * i - PI / 2) * (r if i % 2 == 0 else r * 0.38))
	draw_colored_polygon(pts, col)
