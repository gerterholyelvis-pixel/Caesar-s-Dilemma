extends Control
## The idle game, piece 2: the fractal Seed + Sap, the generator ladder (Sprout, Fern, Fractal Tree, Crystal Bloom), upgrades,
## the Clicker-Heroes-style tab rail and an evolving garden. Left side: slim tab rail + vertical glass panel; the right/centre stays open.
## Hosted by garden.gd (after the title) or standalone (idle_game.tscn builds its own garden behind itself).
## Test hook (after `--`): --autotap  taps ~6x/s and buys greedily; uses a throwaway save file and starts fresh.
##                         --timescale=N  speeds the simulation N times (later game states appear quickly).

const SAVE_PATH := "user://idle_save.json"
const TEST_SAVE_PATH := "user://idle_save_test.json"
const GOLD := Color(0.93, 0.80, 0.52)
const CREAM := Color(0.97, 0.93, 0.84)
const TEAL := Color(0.15, 0.85, 0.75)
const VIOLET := Color(0.66, 0.38, 1.0)
const CYAN := Color(0.45, 0.95, 1.0)
const SLOTS: Array[float] = [-118, 124, -178, 184, -68, 72, -236, 240, -146, 152, -292, 296]
const FERN_OFF: Array[float] = [-175, 190, -245, 255, -120, 128, -300, 310]
const TREE_OFF: Array[float] = [-262, 276, -340, 352, -205]
const CRYS_OFF: Array[float] = [-34, 44, -212, 222, 4]
const RAIL_X := 8.0
const PX := 64.0                     # left panel x
const PW := 300.0
const TOP := 176.0
const ROW_W := PW - 28.0
const GEN_H := 124.0
const UP_H := 86.0

var econ := Economy.new()
var garden: Control
var autotap := false
var save_path := SAVE_PATH
var t := 0.0
var kick := 0.0
var light := 0.0
var pg := {}                         # gen id -> Array[float] grow-in per visible plant
var rings: Array = []
var parts: Array = []
var floaters: Array = []
var mode := 1                        # buy mode: 1 | 10 | 100 | -1 (Max)
var view := "garden"
var pshow := 0.0                     # left panel slide-in 0..1
var _auto_t := 0.0
var _hover := false
var _tip_t := 0.0
var _ph := 96.0                      # smoothed panel height
var _toasts: Array[String] = []
var _toast_busy := false
var _sig := ""
var amber := 0.0                     # smoothed 0..1 amber-seed look

## Hook points for the lead: 'first_sprout' (first Sprout bought) and 'sprouts_10' fire once each (persisted).
signal milestone(id: String)

var back: Control
var front: Control
var font: Font
var caps_font: Font
var cap_label: Label
var sap_label: Label
var rate_label: Label
var hint_label: Label
var panel: Panel
var head_label: Label
var pills: Array[Button] = []
var gen_scroll: ScrollContainer
var gen_box: VBoxContainer
var up_scroll: ScrollContainer
var up_box: VBoxContainer
var gen_rows := {}                   # id -> Dictionary of nodes
var up_rows := {}
var tabs: TabRail
var flourish: TabRail.Flourish
var toast: Panel
var toast_label: Label


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	autotap = "--autotap" in args
	var want_amber := "--amber" in args
	for a in args:
		if a.begins_with("--timescale="):
			Engine.time_scale = float(a.substr(12))
	_hook_story()
	if autotap:
		save_path = TEST_SAVE_PATH
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var p := get_parent()
	if p != null and p.has_signal("intro_finished"):
		garden = p as Control
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 1.0)
	else:
		garden = load("res://garden.tscn").instantiate()
		add_child(garden)
		move_child(garden, 0)
	Hub.boot()
	Hub.audio(get_tree())
	Content.register_words()
	_build()
	_load()
	if want_amber:
		grant_seed("amber_seed")
	resized.connect(_layout)
	_layout()
	if econ.panel_unlocked:
		_show_panel(false)
	var tm := Timer.new()
	tm.wait_time = 10.0
	tm.autostart = true
	tm.timeout.connect(_save)
	add_child(tm)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	_save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()


# ---------------------------------------------------------------------------------------- building

func _build() -> void:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Segoe UI Variable Display", "Segoe UI", "Inter", "Helvetica Neue", "Arial"])
	sf.font_weight = 600
	font = sf
	var fv := FontVariation.new()
	fv.base_font = sf
	fv.spacing_glyph = 7
	caps_font = fv

	back = _layer(true)
	front = _layer(false)
	back.draw.connect(_draw_back)
	front.draw.connect(_draw_front)

	cap_label = _label("SAP", 15, GOLD, caps_font)
	sap_label = _label("0", 76, CREAM, font)
	rate_label = _label("", 22, CYAN, font)
	rate_label.modulate.a = 0.0
	hint_label = _label("tap the seed", 18, Color(CREAM, 0.7), font)

	panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.05, 0.84)
	sb.border_color = Color(GOLD, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(20)
	sb.shadow_color = Color(TEAL, 0.22)
	sb.shadow_size = 26
	panel.add_theme_stylebox_override("panel", sb)
	panel.size = Vector2(PW, 96)
	panel.visible = false
	add_child(panel)

	head_label = _label("PLANTS", 14, GOLD, caps_font, panel)
	head_label.position = Vector2(16, 12)
	head_label.size = Vector2(150, 24)
	head_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	for m in Economy.MODES:
		var b := Button.new()
		b.text = "Max" if m < 0 else "x%d" % m
		b.size = Vector2(36, 24)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", font)
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_color_override("font_color", CREAM)
		b.visible = false
		b.set_meta("m", m)
		b.pressed.connect(func() -> void: mode = m)
		panel.add_child(b)
		pills.append(b)

	gen_scroll = _scroll(panel)
	gen_box = gen_scroll.get_child(0)
	up_scroll = _scroll(panel)
	up_box = up_scroll.get_child(0)
	up_scroll.visible = false
	for g in Content.GENS:
		_make_gen_row(g)
	_make_up_row({"id": "seed", "name": "Amber Seed", "cost": 0.0})
	for u in Content.UPGRADES:
		_make_up_row(u)

	tabs = TabRail.new()
	tabs.position = Vector2(RAIL_X, TOP)
	tabs.modulate.a = 0.0
	tabs.tab_selected.connect(_on_tab)
	add_child(tabs)

	flourish = TabRail.Flourish.new()
	flourish.font = font
	add_child(flourish)

	toast = Panel.new()
	var tb := StyleBoxFlat.new()
	tb.bg_color = Color(0.03, 0.03, 0.05, 0.85)
	tb.border_color = Color(GOLD, 0.7)
	tb.set_border_width_all(1)
	tb.set_corner_radius_all(18)
	toast.add_theme_stylebox_override("panel", tb)
	toast.modulate.a = 0.0
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast)
	toast_label = _label("", 16, CREAM, font, toast)
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _scroll(parent: Control) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.position = Vector2(8, 44)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	sc.add_child(vb)
	var bar := sc.get_v_scroll_bar()
	bar.custom_minimum_size.x = 5
	bar.modulate = Color(GOLD, 0.55)
	parent.add_child(sc)
	return sc


func _row_panel(h: float, tint: Color) -> Panel:
	var p := Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.05, 0.05, 0.075, 0.9)
	s.border_color = Color(GOLD, 0.35)
	s.set_border_width_all(1)
	s.set_corner_radius_all(14)
	s.shadow_color = Color(tint, 0.10)
	s.shadow_size = 8
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(ROW_W, h)
	return p


func _make_gen_row(g: Dictionary) -> void:
	var row := _row_panel(GEN_H, TEAL)
	row.visible = false
	var r := {"row": row, "bv": 0.0, "mv": 0.0}
	var icon := Control.new()
	icon.position = Vector2(8, 10)
	icon.size = Vector2(64, 64)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void: Flora.medallion(icon, Vector2(32, 32), 28.0, String(g["visual"]), t))
	row.add_child(icon)
	var nm := _label(g["name"], 24, CREAM, font, row)
	nm.position = Vector2(80, 6)
	nm.size = Vector2(ROW_W - 88, 30)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var sub := _label("", 13, Color(CYAN, 0.85), font, row)
	sub.position = Vector2(80, 38)
	sub.size = Vector2(ROW_W - 88, 18)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var bar := Control.new()
	bar.position = Vector2(80, 62)
	bar.size = Vector2(ROW_W - 92, 8)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func() -> void:
		var rc := Rect2(Vector2.ZERO, bar.size)
		bar.draw_rect(rc, Color(1, 1, 1, 0.08))
		var fw: float = rc.size.x * float(r["bv"])
		if fw > 1.0:
			bar.draw_rect(Rect2(0, 0, fw, rc.size.y), TEAL.lerp(GOLD, float(r["bv"]) * float(r["bv"])))
			bar.draw_circle(Vector2(fw, 4), 5.0, Color(1, 0.95, 0.8, 0.5)))
	row.add_child(bar)
	var mbar := Control.new()
	mbar.position = Vector2(80, 73)
	mbar.size = Vector2(ROW_W - 92, 4)
	mbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mbar.visible = false
	mbar.draw.connect(func() -> void:
		mbar.draw_rect(Rect2(Vector2.ZERO, mbar.size), Color(VIOLET, 0.18))
		mbar.draw_rect(Rect2(0, 0, mbar.size.x * float(r["mv"]), mbar.size.y), Color(VIOLET.lerp(CYAN, 0.4), 0.95)))
	row.add_child(mbar)
	var btn := Button.new()
	btn.position = Vector2(10, 82)
	btn.size = Vector2(ROW_W - 20, 34)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_color_override("font_color", CREAM)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(CREAM, 0.38))
	btn.add_theme_stylebox_override("normal", _btn_box(Color(0.30, 0.22, 0.07, 0.95), Color(GOLD, 1.0), 14))
	btn.add_theme_stylebox_override("hover", _btn_box(Color(0.42, 0.31, 0.09, 1.0), Color(1.0, 0.9, 0.6), 18))
	btn.add_theme_stylebox_override("pressed", _btn_box(Color(0.22, 0.16, 0.05, 1.0), GOLD, 4))
	btn.add_theme_stylebox_override("disabled", _btn_box(Color(0.07, 0.07, 0.09, 0.9), Color(GOLD, 0.25), 0))
	btn.pressed.connect(func() -> void: _buy_gen(String(g["id"])))
	row.add_child(btn)
	r["icon"] = icon
	r["sub"] = sub
	r["bar"] = bar
	r["mbar"] = mbar
	r["btn"] = btn
	gen_box.add_child(row)
	gen_rows[g["id"]] = r


func _make_up_row(u: Dictionary) -> void:
	var row := _row_panel(UP_H, VIOLET)
	row.visible = false
	var r := {"row": row}
	var nm := _label(u["name"], 18, CREAM, font, row)
	nm.position = Vector2(12, 6)
	nm.size = Vector2(ROW_W - 100, 24)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var ef := _label("", 13, Color(CYAN, 0.9), font, row)
	ef.position = Vector2(12, 32)
	ef.size = Vector2(ROW_W - 104, 46)
	ef.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	ef.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var btn := Button.new()
	btn.position = Vector2(ROW_W - 88, 12)
	btn.size = Vector2(78, 62)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", CREAM)
	btn.add_theme_color_override("font_disabled_color", Color(CREAM, 0.38))
	btn.add_theme_stylebox_override("normal", _btn_box(Color(0.30, 0.22, 0.07, 0.95), Color(GOLD, 1.0), 12))
	btn.add_theme_stylebox_override("hover", _btn_box(Color(0.42, 0.31, 0.09, 1.0), Color(1.0, 0.9, 0.6), 16))
	btn.add_theme_stylebox_override("pressed", _btn_box(Color(0.22, 0.16, 0.05, 1.0), GOLD, 4))
	btn.add_theme_stylebox_override("disabled", _btn_box(Color(0.07, 0.07, 0.09, 0.9), Color(GOLD, 0.25), 0))
	btn.pressed.connect(func() -> void: _buy_upgrade(String(u["id"])))
	row.add_child(btn)
	r["ef"] = ef
	r["btn"] = btn
	up_box.add_child(row)
	up_rows[u["id"]] = r


func _layer(additive: bool) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if additive:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		c.material = m
	add_child(c)
	return c


func _label(s: String, sz: int, col: Color, f: Font, parent: Node = null) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05, 0.85))
	l.add_theme_constant_override("outline_size", 5 if sz > 40 else 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else self).add_child(l)
	return l


func _btn_box(bg: Color, rim: Color, glow: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = rim
	s.set_border_width_all(2)
	s.set_corner_radius_all(12)
	s.shadow_color = Color(rim, 0.35)
	s.shadow_size = glow
	return s


## Centre x of the open world area (right of the left panel once it is shown).
func _wx() -> float:
	var open := lerpf(size.x * 0.5, (PX + PW + size.x) * 0.5, UiKit.ease_out(pshow))
	return open


func _ss() -> float:
	var fit := clampf((size.x - (PX + PW) - 70.0) / 640.0, 0.55, 1.0)
	return lerpf(1.0, fit, UiKit.ease_out(pshow))


func _layout() -> void:
	var w := _wx()
	var sw := size.x
	cap_label.position = Vector2(w - sw * 0.5, 30)
	cap_label.size = Vector2(sw, 22)
	sap_label.position = Vector2(w - sw * 0.5, 46)
	sap_label.size = Vector2(sw, 90)
	sap_label.pivot_offset = Vector2(sw * 0.5, 45)
	rate_label.position = Vector2(w - sw * 0.5, 136)
	rate_label.size = Vector2(sw, 30)
	hint_label.position = Vector2(w - sw * 0.5, _ground() - 62)
	hint_label.size = Vector2(sw, 26)
	panel.position = Vector2(lerpf(-PW - 10.0, PX, UiKit.ease_out(pshow)), TOP)
	tabs.position = Vector2(lerpf(-60.0, RAIL_X, UiKit.ease_out(pshow)), TOP)
	var tw := minf(sw - 40, 560)
	toast.size = Vector2(tw, 38)
	toast.position = Vector2(w - tw * 0.5, 178)
	toast_label.size = toast.size
	flourish.set_anchors_preset(Control.PRESET_FULL_RECT)


func _ground() -> float:
	return size.y * 0.80


func _seed_c() -> Vector2:
	return Vector2(_wx(), _ground() - 118.0 + sin(t * 1.3) * 6.0)


# ---------------------------------------------------------------------------------------- game flow

func _process(dt: float) -> void:
	dt = minf(dt, 0.25 * maxf(Engine.time_scale, 1.0))
	t += dt
	econ.advance(dt)
	if autotap:
		_auto_t += dt
		while _auto_t >= 0.16:
			_auto_t -= 0.16
			_tap(_seed_c())
			_bot_buy()
	if econ.panel_unlocked and not panel.visible:
		_show_panel(true)
	_drain_events()
	kick = maxf(0.0, kick - dt * 3.0)
	var lt := maxf(minf(float(econ.sprouts) / 12.0, 1.0), clampf(log(econ.total_earned.to_float() + 1.0) / log(10.0) / 7.0, 0.0, 1.0))
	light = lerpf(light, lt, 1.0 - exp(-2.0 * dt))
	amber = lerpf(amber, 1.0 if econ.seed_type == "amber_seed" else 0.0, 1.0 - exp(-3.0 * dt))
	_grow(dt)
	_step_fx(dt)
	_refresh_ui(dt)
	_layout()
	var h := (get_local_mouse_position() - _seed_c()).length() < 78.0
	if h != _hover:
		_hover = h
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if h else Control.CURSOR_ARROW
	back.queue_redraw()
	front.queue_redraw()


func _bot_buy() -> void:
	if not econ.panel_unlocked:
		return
	for u in Content.UPGRADES:
		if econ.can_buy_upgrade(u["id"]):
			_buy_upgrade(u["id"])
	var best := ""
	var bp := INF
	for g in Content.GENS:
		var id: String = g["id"]
		if econ.gen_visible(id) and econ.can_buy(id, 1):
			var pb := econ.cost_at(id, econ.count(id)).to_float() / econ.rate_each(id)
			if pb < bp:
				bp = pb
				best = id
	if best != "":
		var m := mode
		mode = 1
		_buy_gen(best)
		mode = m


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if (ev.position - _seed_c()).length() < 90.0:
			_tap(ev.position)
			accept_event()


func _unhandled_key_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and (ev.keycode == KEY_SPACE or ev.keycode == KEY_ENTER):
		_tap(_seed_c())


func _tap(_at: Vector2) -> void:
	var v := econ.tap()
	kick = 1.0
	var c := _seed_c()
	rings.append({"r": 40.0, "a": 0.9, "w": 3.0})
	rings.append({"r": 30.0, "a": 0.5, "w": 6.0})
	var cols: Array[Color] = [GOLD, CYAN, TEAL, Color(1, 0.95, 0.75)]
	for i in 14:
		var ang := randf() * TAU
		var sp := randf_range(70.0, 230.0)
		parts.append({"p": c + Vector2.from_angle(ang) * 30.0, "v": Vector2.from_angle(ang) * sp, "life": 0.0,
			"max": randf_range(0.6, 1.1), "col": cols[randi() % 4], "r": randf_range(1.5, 3.5)})
	floaters.append({"p": c + Vector2(randf_range(-34, 34), -48), "text": "+" + _tapfmt(v), "life": 0.0})
	sap_label.scale = Vector2(1.07, 1.07)
	Hub.sfx("ui_click")


func _buy_gen(id: String) -> void:
	var n := econ.mode_count(id, mode)
	if not econ.buy(id, n):
		return
	_plant_fx(id)
	Hub.sfx("place_item")


func _tapfmt(v: BigNum) -> String:
	var f := v.to_float()
	return v.fmt(2 if f < 100.0 and absf(f - roundf(f)) > 0.004 else 0)


## Lead hook (e.g. the Sap Farmer scene's grant callback): switches the central seed, e.g. grant_seed("amber_seed").
func grant_seed(id: String) -> void:
	econ.grant_seed(id)


func _buy_upgrade(id: String) -> void:
	if id == "seed":
		if econ.buy_seed_level():
			rings.append({"r": 30.0, "a": 0.9, "w": 4.0})
			Hub.sfx("glyph_learn")
		return
	if econ.buy_upgrade(id):
		var c := _seed_c()
		rings.append({"r": 20.0, "a": 0.9, "w": 4.0})
		for i in 20:
			var ang := randf() * TAU
			parts.append({"p": c, "v": Vector2.from_angle(ang) * randf_range(60.0, 200.0), "life": 0.0,
				"max": randf_range(0.6, 1.2), "col": VIOLET.lerp(GOLD, randf()), "r": randf_range(1.5, 3.0)})
		Hub.sfx("glyph_learn")


func _plant_fx(id: String) -> void:
	var n := mini(econ.count(id), int(Content.gen(id)["cap"]))
	var pp := _plant_pos(id, maxi(n - 1, 0))
	var cols: Array[Color] = [TEAL, Color(0.5, 1.0, 0.6), GOLD]
	for i in 16:
		var ang := -PI * 0.5 + randf_range(-1.1, 1.1)
		parts.append({"p": Vector2(pp.x, pp.y), "v": Vector2.from_angle(ang) * randf_range(40.0, 150.0), "life": 0.0,
			"max": randf_range(0.7, 1.3), "col": cols[randi() % 3], "r": randf_range(1.5, 3.0)})
	rings.append({"r": 8.0, "a": 0.8, "w": 3.0, "at": Vector2(pp.x, pp.y)})


func _show_panel(animate: bool) -> void:
	panel.visible = true
	if animate:
		pshow = 0.0
		var tw := create_tween()
		tw.tween_property(self, "pshow", 1.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(tabs, "modulate:a", 1.0, 0.9)
		tabs.refresh(econ.unlocked, false)
		Hub.sfx("glyph_learn")
	else:
		pshow = 1.0
		tabs.modulate.a = 1.0
		tabs.refresh(econ.unlocked, false)


func _on_tab(id: String) -> void:
	view = id
	gen_scroll.visible = id == "garden"
	up_scroll.visible = id == "upgrades"
	_sig = ""


func _drain_events() -> void:
	while not econ.events.is_empty():
		var e: Dictionary = econ.events.pop_front()
		if e["t"] == "auto":
			_plant_fx(e["id"])
			continue
		if e["t"] == "milestone":
			milestone.emit(e["id"])
			continue
		if e["t"] == "seed":
			var sd := Content.seed_def(e["id"])
			if sd["key"] != "":
				flourish.play(sd["key"], sd["name"], Vector2(_wx(), 232.0))
			_toast("%s: +%s per tap" % [sd["name"], _tapfmt(econ.tap_value())])
			rings.append({"r": 20.0, "a": 1.0, "w": 6.0})
			rings.append({"r": 50.0, "a": 0.8, "w": 3.0})
			var c := _seed_c()
			for i in 30:
				var ang := randf() * TAU
				parts.append({"p": c, "v": Vector2.from_angle(ang) * randf_range(80.0, 260.0), "life": 0.0,
					"max": randf_range(0.7, 1.4), "col": Color(1.0, 0.75, 0.25).lerp(GOLD, randf()), "r": randf_range(1.5, 3.5)})
			floaters.append({"p": c + Vector2(0, -60), "text": "+%s per tap" % _tapfmt(econ.tap_value()), "life": 0.0})
			Hub.sfx("glyph_learn")
			continue
		var d := Content.unlock_def(e["id"])
		if d.is_empty():
			continue
		var added := tabs.refresh(econ.unlocked, true)
		if d.get("quiet", false):
			_toast(d["msg"])
			continue
		flourish.play(d["word"], d["title"], Vector2(_wx(), 232.0))
		_toast(d["msg"])
		Hub.sfx("glyph_learn")
		if not added.is_empty():
			tabs.fresh[added[0]] = true


func _toast(s: String) -> void:
	_toasts.append(s)


func _next_toast() -> void:
	_toast_busy = true
	toast_label.text = _toasts.pop_front()
	var tw := create_tween()
	tw.tween_property(toast, "modulate:a", 1.0, 0.5)
	tw.tween_interval(4.2)
	tw.tween_property(toast, "modulate:a", 0.0, 1.0)
	tw.tween_callback(func() -> void: _toast_busy = false)


func _grow(dt: float) -> void:
	for g in Content.GENS:
		var id: String = g["id"]
		var n := mini(econ.count(id), int(g["cap"]))
		if not pg.has(id):
			pg[id] = []
		var a: Array = pg[id]
		while a.size() < n:
			a.append(0.0)
		for i in a.size():
			a[i] = minf(1.0, a[i] + dt / 1.5)


func _refresh_ui(dt: float) -> void:
	if not _toast_busy and not _toasts.is_empty():
		_next_toast()
	sap_label.text = econ.sap.fmt()
	sap_label.scale = sap_label.scale.lerp(Vector2.ONE, 1.0 - exp(-14.0 * dt))
	if econ.sprouts > 0:
		rate_label.text = "+%s per second" % econ.sap_per_sec().fmt(1)
		rate_label.modulate.a = minf(1.0, rate_label.modulate.a + dt * 2.0)
	hint_label.modulate.a = (1.0 if econ.taps == 0 else 0.0) * (0.55 + 0.45 * sin(t * 3.0))
	if not panel.visible:
		return
	tabs.badges["upgrades"] = econ.affordable_upgrades()
	_tip_t -= dt
	var tip := _tip_t <= 0.0
	if tip:
		_tip_t = 0.25
	var shown_any: bool = econ.unlocked.get("buy_x10", false)
	for pb in pills:
		var m: int = pb.get_meta("m")
		pb.visible = view == "garden" and shown_any and (m <= 10 or econ.unlocked.get("buy_bulk", false))
		pb.position = Vector2(PW - 12 - (Economy.MODES.size() - Economy.MODES.find(m)) * 40.0 + 4.0, 10)
		var on := m == mode
		var s := _btn_box(Color(0.30, 0.22, 0.07, 0.95) if on else Color(0.06, 0.06, 0.09, 0.9), Color(GOLD, 1.0 if on else 0.3), 8 if on else 0)
		s.set_corner_radius_all(8)
		s.set_border_width_all(1)
		for k in ["normal", "hover", "pressed"]:
			pb.add_theme_stylebox_override(k, s)
	var want := 0.0
	if view == "garden":
		head_label.text = "PLANTS"
		var vis := 0
		for g in Content.GENS:
			var id: String = g["id"]
			var r: Dictionary = gen_rows[id]
			var row: Panel = r["row"]
			var v := econ.gen_visible(id)
			row.visible = v
			if not v:
				continue
			vis += 1
			(r["icon"] as Control).queue_redraw()
			var cost := econ.bulk_cost(id, econ.mode_count(id, mode))
			var n := econ.mode_count(id, mode)
			var ok := econ.can_buy(id, n)
			var btn: Button = r["btn"]
			btn.text = "Buy x%d  ·  %s Sap" % [n, cost.fmt()]
			btn.disabled = not ok
			btn.modulate = Color.WHITE.lerp(Color(1.25, 1.15, 0.9), 0.5 + 0.5 * sin(t * 5.0)) if ok else Color.WHITE
			var c := econ.count(id)
			var sub: Label = r["sub"]
			var nx := econ.next_milestone(id)
			var showm: bool = econ.unlocked.get("buy_bulk", false)
			sub.text = "+%s Sap/s each · owned %d" % [BigNum.of(econ.rate_each(id)).fmt(1), c]
			if showm and nx > 0:
				sub.text += "/%d" % nx
			r["bv"] = lerpf(r["bv"], econ.sap.ratio(cost), 1.0 - exp(-10.0 * dt))
			r["mv"] = lerpf(r["mv"], econ.milestone_progress(id), 1.0 - exp(-8.0 * dt))
			(r["mbar"] as Control).visible = showm
			(r["bar"] as Control).queue_redraw()
			(r["mbar"] as Control).queue_redraw()
			if tip:
				btn.tooltip_text = econ.gen_tooltip(id, n)
		want = vis * (GEN_H + 8.0) + 4.0
	else:
		head_label.text = "UPGRADES"
		var sig := ""
		var order: Array[Dictionary] = []
		for u in Content.UPGRADES:
			if econ.upgrade_visible(u["id"]):
				order.append(u)
		order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var ao := econ.has_upgrade(a["id"])
			var bo := econ.has_upgrade(b["id"])
			return (not ao and bo) or (ao == bo and float(a["cost"]) < float(b["cost"])))
		for k in up_rows:
			(up_rows[k]["row"] as Control).visible = false
		var i := 0
		if econ.seed_has_levels() and econ.unlocked.get("tab_upgrades", false):     # the seed's own level line, always first
			var sr: Dictionary = up_rows["seed"]
			var srow: Panel = sr["row"]
			srow.visible = true
			srow.modulate.a = 1.0
			up_box.move_child(srow, 0)
			i = 1
			(sr["ef"] as Label).text = econ.seed_effect()
			var sbtn: Button = sr["btn"]
			var smax := econ.seed_level >= int(Content.seed_def(econ.seed_type)["max_level"])
			sbtn.text = "Max" if smax else "Lv %d\n%s" % [econ.seed_level + 1, econ.seed_level_cost().fmt()]
			sbtn.disabled = not econ.can_buy_seed_level()
			sbtn.modulate = Color.WHITE.lerp(Color(1.25, 1.15, 0.9), 0.5 + 0.5 * sin(t * 5.0)) if not sbtn.disabled else Color.WHITE
			(srow.get_child(0) as Label).text = "%s  ·  level %d" % [Content.seed_def(econ.seed_type)["name"], econ.seed_level]
			if tip:
				sbtn.tooltip_text = econ.seed_tooltip()
		for u in order:
			var id: String = u["id"]
			var r: Dictionary = up_rows[id]
			var row: Panel = r["row"]
			row.visible = true
			sig += id + ","
			up_box.move_child(row, i)
			i += 1
			sig += "|"
			var own := econ.has_upgrade(id)
			(r["ef"] as Label).text = econ.upgrade_effect(id)
			var btn: Button = r["btn"]
			btn.text = "Owned" if own else "%s\nSap" % BigNum.of(u["cost"]).fmt()
			btn.disabled = own or not econ.can_buy_upgrade(id)
			row.modulate.a = 0.6 if own else 1.0
			btn.modulate = Color.WHITE.lerp(Color(1.25, 1.15, 0.9), 0.5 + 0.5 * sin(t * 5.0)) if (not own and not btn.disabled) else Color.WHITE
			if tip:
				btn.tooltip_text = econ.upgrade_tooltip(id)
		want = maxf(i, 1) * (UP_H + 8.0) + 4.0
		if i == 0:
			head_label.text = "UPGRADES   ·   none yet"
	var avail := size.y - TOP - 16.0
	var target := minf(want + 52.0, avail)
	target = maxf(target, 96.0)
	if view == "garden" and not econ.unlocked.get("tab_upgrades", false) and econ.unlocked.size() == 0:
		target = maxf(target, 96.0)
	_ph = lerpf(_ph, target, 1.0 - exp(-12.0 * dt))
	panel.size = Vector2(PW, _ph)
	gen_scroll.size = Vector2(PW - 16, _ph - 52)
	up_scroll.size = gen_scroll.size


func _step_fx(dt: float) -> void:
	for r in rings:
		r["r"] += dt * 220.0
		r["a"] -= dt * 1.6
	rings = rings.filter(func(r: Dictionary) -> bool: return r["a"] > 0.0)
	for q in parts:
		q["life"] += dt
		q["v"] = q["v"] * (1.0 - 1.6 * dt) + Vector2(0, 40.0) * dt
		q["p"] += q["v"] * dt
	parts = parts.filter(func(q: Dictionary) -> bool: return q["life"] < q["max"])
	for f in floaters:
		f["life"] += dt
		f["p"] += Vector2(0, -46.0) * dt
	floaters = floaters.filter(func(f: Dictionary) -> bool: return f["life"] < 1.1)


# ---------------------------------------------------------------------------------------- garden layout

## Ground position (x, y) and scale (z) of plant `i` of generator `id`; deterministic.
func _plant_pos(id: String, i: int) -> Vector3:
	var wx := _wx()
	var ss := _ss()
	var g := _ground()
	var minx := (PX + PW + 36.0) * clampf(pshow, 0.0, 1.0)
	var x := wx
	var y := g
	var s := 1.0
	match id:
		"sprout":
			x = wx + SLOTS[i % SLOTS.size()] * ss
			s = 0.92 + 0.16 * float((i * 5) % 7) / 6.0
		"fern":
			x = wx + FERN_OFF[i % FERN_OFF.size()] * ss
			y = g + 8.0 + float(i % 3) * 4.0
			s = 0.9 + 0.12 * float(i % 3)
		"tree":
			x = wx + TREE_OFF[i % TREE_OFF.size()] * ss
			y = g - 2.0
			s = 1.25 + 0.12 * float(i % 3)
		"bloom":
			x = wx + CRYS_OFF[i % CRYS_OFF.size()] * ss
			y = g + 4.0
			s = 0.95 + 0.1 * float(i % 2)
	return Vector3(clampf(x, minx + 10.0, size.x - 30.0), y, s)


# ---------------------------------------------------------------------------------------- drawing

func _draw_back() -> void:
	var c := _seed_c()
	var g := _ground()
	var pulse := 1.0 + 0.04 * sin(t * 2.0) + 0.06 * kick
	back.draw_set_transform(Vector2(c.x, g), 0.0, Vector2(1.0, 0.16))
	for i in 10:
		var f := 1.0 - float(i) / 10.0
		back.draw_circle(Vector2.ZERO, (230.0 + 260.0 * light) * f, Color(TEAL.lerp(GOLD, light), 0.018 + 0.012 * light))
	back.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in 14:
		var f := 1.0 - float(i) / 14.0
		back.draw_circle(c, (150.0 + 130.0 * light) * f * pulse, Color(VIOLET.lerp(TEAL, f), 0.016 + 0.01 * light + 0.01 * kick))
	if amber > 0.01:                                # amber bloom, golden rings and orbiting droplets (grow with the seed level)
		var lv := econ.seed_level
		for i in 12:
			var f := 1.0 - float(i) / 12.0
			back.draw_circle(c, (110.0 + 40.0 * minf(lv, 20) / 20.0) * f * pulse, Color(1.0, 0.62, 0.16, (0.03 + 0.012 * minf(lv, 20) / 10.0) * amber))
		for k in 1 + mini(lv / 3, 4):
			back.draw_arc(c, 50.0 + 11.0 * k + 2.0 * sin(t * 1.5 + k), 0, TAU, 56, Color(1.0, 0.8, 0.35, (0.55 - 0.08 * k) * amber), 2.0, true)
		var nd := 2 + mini(lv / 2, 7)
		for k in nd:
			var a := t * (0.9 + 0.12 * (k % 3)) + k * TAU / nd
			var rr := 58.0 + 13.0 * (k % 3)
			var dp := c + Vector2(cos(a), sin(a) * 0.55) * rr
			back.draw_circle(dp, 3.6, Color(1.0, 0.8, 0.35, 0.9 * amber))
			back.draw_circle(dp, 10.0, Color(1.0, 0.65, 0.2, 0.14 * amber))
	_ring_fractal(back, c, 62.0 * pulse, 2, t * 0.25, 1.0)
	_ring_fractal(back, c, 92.0 * pulse, 1, -t * 0.18, 0.5)
	for i in 6:
		var a := t * 0.5 + i * TAU / 6.0
		back.draw_circle(c + Vector2.from_angle(a) * 78.0 * pulse, 2.2, Color(GOLD, 0.7))
	for r in rings:
		var at: Vector2 = r.get("at", c)
		back.draw_arc(at, r["r"], 0, TAU, 64, Color(CYAN.lerp(GOLD, 0.4), r["a"]), r["w"], true)
	for q in parts:
		var k: float = 1.0 - q["life"] / q["max"]
		back.draw_circle(q["p"], q["r"] * (0.6 + k), Color(q["col"], 0.85 * k))
		back.draw_circle(q["p"], q["r"] * 3.0 * k, Color(q["col"], 0.12 * k))
	# fireflies: more as the garden brightens
	var motes := int(6.0 + 34.0 * light)
	for i in motes:
		var fx := c.x + sin(t * (0.08 + 0.02 * (i % 3)) + i * 1.7) * size.x * 0.34
		var fy := g - 30.0 - float((i * 37) % 230) + sin(t * 0.6 + i) * 14.0
		var tw := 0.5 + 0.5 * sin(t * 1.4 + i * 2.3)
		back.draw_circle(Vector2(fx, fy), 2.0, Color(GOLD.lerp(CYAN, float(i % 2)), 0.5 * tw))
		back.draw_circle(Vector2(fx, fy), 6.0, Color(GOLD.lerp(CYAN, float(i % 2)), 0.08 * tw))
	_draw_flora(null, back)


func _ring_fractal(ci: CanvasItem, c: Vector2, r: float, depth: int, rot: float, a: float) -> void:
	ci.draw_arc(c, r, 0, TAU, 48, Color(TEAL.lerp(CYAN, 0.4), 0.30 * a), 1.5, true)
	if depth <= 0:
		return
	for i in 3:
		var ang := rot + i * TAU / 3.0
		_ring_fractal(ci, c + Vector2.from_angle(ang) * r, r * 0.42, depth - 1, rot * -1.3 + 0.7, a * 0.8)


## One pass over all visible plants; `solid` = the front layer (null on the additive glow pass), `glow` = the back layer.
func _draw_flora(solid: CanvasItem, glow: CanvasItem) -> void:
	var order := ["tree", "fern", "bloom", "sprout"]
	for id in order:
		var a: Array = pg.get(id, [])
		for i in a.size():
			var p := _plant_pos(id, i)
			var gp := _ease_back(a[i])
			var pos := Vector2(p.x, p.y)
			var flip := -1.0 if (i * 3 + id.length()) % 2 == 1 else 1.0
			var ph := float(i) * 1.7 + float(id.length())
			match id:
				"sprout":
					var v := Flora.sprout(i)
					if solid != null:
						Flora.draw_sprout(solid, null, pos, v, gp, p.z, flip, t, ph, light)
					else:
						_sprout_glow(glow, pos, v, gp, p.z, flip, ph)
				"fern":
					var v := Flora.fern(i)
					if solid != null:
						Flora.draw_fern(solid, null, pos, v, gp, p.z, flip, t, ph, 1.0)
					else:
						_glow_only_fern(glow, pos, v, gp, p.z, flip, ph)
				"tree":
					var v := Flora.tree(i)
					if solid != null:
						Flora.draw_tree(solid, null, pos, v, gp, p.z, flip, t, ph, 0.85)
					else:
						_glow_only_tree(glow, pos, v, gp, p.z, flip, ph)
				"bloom":
					if solid != null:
						Flora.draw_crystal(solid, null, pos, gp, p.z, t, ph)
					else:
						glow.draw_circle(pos + Vector2(0, -22.0 * p.z * gp), 24.0 * p.z * gp, Color(VIOLET, 0.07))


func _sprout_glow(glow: CanvasItem, pos: Vector2, v: Dictionary, gp: float, sc: float, flip: float, ph: float) -> void:
	var sway := sin(t * 1.15 + ph) * 0.045 + sin(t * 0.37 + ph * 2.0) * 0.03
	var s := sc * maxf(gp, 0.01)
	glow.draw_set_transform(pos, sway, Vector2(s * flip, s))
	var lv: Array = v["leaves"]
	for li in [0, 2, 4]:
		glow.draw_circle(lv[li]["center"], 15.0, Color(0.4, 1.0, 0.6, 0.045 + 0.03 * light))
	glow.draw_circle(v["top"], 5.0, Color(GOLD, 0.35))
	glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _glow_only_fern(glow: CanvasItem, pos: Vector2, v: Dictionary, gp: float, sc: float, flip: float, ph: float) -> void:
	var sway := sin(t * 0.9 + ph) * 0.035
	var s := sc * maxf(gp, 0.01)
	glow.draw_set_transform(pos, sway, Vector2(s * flip, s))
	var pulse := 0.6 + 0.4 * sin(t * 2.0 + ph)
	for f in v["fronds"]:
		glow.draw_circle(f["tip"], 6.5, Color(GOLD, 0.16 * pulse))
		glow.draw_circle(f["tip"], 2.4, Color(1.0, 0.92, 0.6, 0.85))
	glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _glow_only_tree(glow: CanvasItem, pos: Vector2, v: Dictionary, gp: float, sc: float, flip: float, ph: float) -> void:
	var sway := sin(t * 0.6 + ph) * 0.02
	var s := sc * maxf(gp, 0.01)
	glow.draw_set_transform(pos, sway, Vector2(s * flip, s))
	var tips: PackedVector2Array = v["tips"]
	for k in range(0, tips.size(), 3):
		var pulse := 0.6 + 0.4 * sin(t * 1.7 + ph + k)
		glow.draw_circle(tips[k], 5.0, Color(GOLD, 0.12 * pulse))
		glow.draw_circle(tips[k], 2.0, Color(1.0, 0.9, 0.6, 0.8))
	glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_front() -> void:
	var c := _seed_c()
	for id in ["tree", "fern", "bloom", "sprout"]:
		var a: Array = pg.get(id, [])
		for i in a.size():
			var p := _plant_pos(id, i)
			Flora.draw_shadow(front, Vector2(p.x, p.y), (30.0 if id == "tree" else 18.0) * p.z, _ease_back(a[i]))
	_draw_flora(front, null)
	var s := (1.0 + 0.03 * sin(t * 2.0) - 0.07 * kick + (0.05 if _hover else 0.0))
	var r := 38.0 * s
	for i in 12:
		var f := float(i) / 11.0
		var col := Color(0.16, 0.05, 0.34).lerp(Color(0.1, 0.6, 0.6), f * 0.9).lerp(Color(1.0, 0.86, 0.5), pow(f, 3.0))
		col = col.lerp(Color(0.45, 0.16, 0.02).lerp(Color(0.95, 0.55, 0.1), f * 0.9).lerp(Color(1.0, 0.92, 0.55), pow(f, 2.5)), amber)
		front.draw_circle(c + Vector2(-5, -6) * f, r * (1.0 - f * 0.86), col)
	var pts := PackedVector2Array()
	for i in 60:
		var a := i * 0.21 + t * 0.6
		pts.append(c + Vector2(-5, -6) * 0.5 + Vector2.from_angle(a) * (3.0 + i * 0.45) * s)
	front.draw_polyline(pts, Color(1, 0.95, 0.8, 0.55), 1.4, true)
	front.draw_arc(c, r, 0, TAU, 48, Color(GOLD, 0.9), 2.0, true)
	if amber > 0.01:
		front.draw_arc(c, r + 7.0, 0, TAU, 56, Color(1.0, 0.82, 0.38, 0.85 * amber), 2.5, true)
	front.draw_circle(c + Vector2(-13, -16) * s, 5.0, Color(1, 1, 1, 0.45))
	for f in floaters:
		var k: float = f["life"] / 1.1
		var a := 1.0 - k * k
		var pp: Vector2 = f["p"]
		front.draw_string_outline(font, pp, f["text"], HORIZONTAL_ALIGNMENT_CENTER, 90.0, 28, 5, Color(0.02, 0.02, 0.05, a * 0.8))
		front.draw_string(font, pp, f["text"], HORIZONTAL_ALIGNMENT_CENTER, 90.0, 28, Color(1.0, 0.92, 0.65, a))


func _ease_back(x: float) -> float:
	var c1 := 1.70158
	return 1.0 + (c1 + 1.0) * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


# ---------------------------------------------------------------------------------------- save / load

func _save() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f != null:
		var d := econ.to_dict()
		d["mode"] = mode
		f.store_string(JSON.stringify(d))


func _load() -> void:
	if autotap or not FileAccess.file_exists(save_path):
		return
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary):
		return
	econ.from_dict(d)
	mode = int(d.get("mode", 1)) if int(d.get("mode", 1)) in Economy.MODES else 1
	for g in Content.GENS:
		var a: Array = []
		for i in mini(econ.count(g["id"]), int(g["cap"])):
			a.append(1.0)
		pg[g["id"]] = a
	light = maxf(minf(float(econ.sprouts) / 12.0, 1.0), clampf(log(econ.total_earned.to_float() + 1.0) / log(10.0) / 7.0, 0.0, 1.0))
	var away := Time.get_unix_time_from_system() - float(d.get("saved_at", Time.get_unix_time_from_system()))
	if away >= 60.0 and econ.sprouts > 0:
		var gained := econ.apply_offline(away)
		_toast("Welcome back. The garden grew %s Sap while you were away." % gained.fmt())


# ---------- story hooks: planting cinematic, the Sap Farmer, calm background music ----------

func _hook_story() -> void:
	if autotap or DisplayServer.get_name() == "headless":
		return
	milestone.connect(_on_milestone)
	var cin = load("res://idle/cin_first_sprout.gd")
	if cin:
		cin.prebake()
	_music_level()
	var tm := Timer.new()
	tm.wait_time = 8.0
	tm.autostart = true
	tm.timeout.connect(_music_level)
	add_child(tm)


func _music_level() -> void:
	var hub = load("res://game/hub.gd")
	if hub == null or not hub.has_method("idle_music"):
		return
	var kinds := 0
	for k in econ.owned:
		if int(econ.owned[k]) > 0:
			kinds += 1
	var lvl := kinds + (1 if econ.upgrades.size() > 3 else 0) + (1 if econ.seed_type != "plain" else 0)
	hub.idle_music(clampi(lvl, 0, 5))


func _on_milestone(id: String) -> void:
	var flags = load("res://idle/flags.gd")
	if id == "first_sprout" and not flags.get_flag("cin_first_sprout"):
		flags.set_flag("cin_first_sprout", true)
		var cin = load("res://idle/cin_first_sprout.gd")
		await cin.play(self)
	elif id == "sprouts_10":
		var farmer = load("res://idle/farmer_scene.gd")
		if not farmer.seen():
			await farmer.play(self, Callable(self, "grant_seed"))