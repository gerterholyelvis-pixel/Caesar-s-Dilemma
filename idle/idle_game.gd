extends Control
## Tier 0 of the idle game: the fractal Seed, the Sap counter and the first generator (Sprout), over the locked garden.
## Hosted by garden.gd (after the title) or standalone (idle_game.tscn builds its own garden behind itself).
## Test hook (after `--`): --autotap  taps ~6x/s and buys whenever affordable; uses a throwaway save file and starts fresh.

const SAVE_PATH := "user://idle_save.json"
const TEST_SAVE_PATH := "user://idle_save_test.json"
const GOLD := Color(0.93, 0.80, 0.52)
const CREAM := Color(0.97, 0.93, 0.84)
const TEAL := Color(0.15, 0.85, 0.75)
const VIOLET := Color(0.66, 0.38, 1.0)
const CYAN := Color(0.45, 0.95, 1.0)
const MAX_VISIBLE := 12
const SLOTS: Array[float] = [-118, 124, -178, 184, -68, 72, -236, 240, -146, 152, -292, 296]
const PANEL_W := 560.0
const PANEL_H := 96.0

var econ := Economy.new()
var garden: Control
var autotap := false
var save_path := SAVE_PATH
var t := 0.0
var kick := 0.0                      # seed squash after a tap
var light := 0.0                     # smoothed world brightness 0..1
var grow: Array[float] = []          # per visible sprout growth 0..1
var rings: Array = []                # {r, a, w}
var parts: Array = []                # {p, v, life, max, col, r}
var floaters: Array = []             # {p, text, life}
var _auto_t := 0.0
var _hover := false

var back: Control                    # additive glow layer
var front: Control                   # solid layer
var font: Font
var caps_font: Font
var cap_label: Label
var sap_label: Label
var rate_label: Label
var hint_label: Label
var panel: Panel
var panel_shown := false
var name_label: Label
var sub_label: Label
var bar: Control
var buy_btn: Button
var toast: Panel
var toast_label: Label
var _bar_v := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	autotap = "--autotap" in args
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
	_build()
	_load()
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
	panel.size = Vector2(PANEL_W, PANEL_H)
	panel.visible = false
	add_child(panel)

	var icon := Control.new()
	icon.position = Vector2(16, 16)
	icon.size = Vector2(64, 64)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void:
		var c := Vector2(32, 34)
		icon.draw_circle(c, 29, Color(TEAL, 0.12))
		icon.draw_arc(c, 29, 0, TAU, 40, Color(GOLD, 0.5), 1.5, true)
		_draw_tree(icon, Vector2(32, 52), 0.0, 15.0, 3, 1.0, 0.0, 2.2))
	panel.add_child(icon)
	name_label = _label("Sprout", 26, CREAM, font, panel)
	name_label.position = Vector2(94, 8)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sub_label = _label("", 15, Color(CYAN, 0.85), font, panel)
	sub_label.position = Vector2(94, 43)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	bar = Control.new()
	bar.position = Vector2(94, 74)
	bar.size = Vector2(240, 8)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(_draw_bar)
	panel.add_child(bar)

	buy_btn = Button.new()
	buy_btn.position = Vector2(PANEL_W - 170, 14)
	buy_btn.size = Vector2(154, 68)
	buy_btn.focus_mode = Control.FOCUS_NONE
	buy_btn.add_theme_font_override("font", font)
	buy_btn.add_theme_font_size_override("font_size", 19)
	buy_btn.add_theme_color_override("font_color", CREAM)
	buy_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	buy_btn.add_theme_color_override("font_disabled_color", Color(CREAM, 0.38))
	buy_btn.add_theme_stylebox_override("normal", _btn_box(Color(0.30, 0.22, 0.07, 0.95), Color(GOLD, 1.0), 14))
	buy_btn.add_theme_stylebox_override("hover", _btn_box(Color(0.42, 0.31, 0.09, 1.0), Color(1.0, 0.9, 0.6), 18))
	buy_btn.add_theme_stylebox_override("pressed", _btn_box(Color(0.22, 0.16, 0.05, 1.0), GOLD, 4))
	buy_btn.add_theme_stylebox_override("disabled", _btn_box(Color(0.07, 0.07, 0.09, 0.9), Color(GOLD, 0.25), 0))
	buy_btn.pressed.connect(_buy)
	panel.add_child(buy_btn)

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
	toast_label = _label("", 17, CREAM, font, toast)
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


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
	s.set_corner_radius_all(14)
	s.shadow_color = Color(rim, 0.35)
	s.shadow_size = glow
	return s


func _layout() -> void:
	var w := size.x
	cap_label.position = Vector2(0, 30)
	cap_label.size = Vector2(w, 22)
	sap_label.position = Vector2(0, 46)
	sap_label.size = Vector2(w, 90)
	sap_label.pivot_offset = Vector2(w * 0.5, 45)
	rate_label.position = Vector2(0, 136)
	rate_label.size = Vector2(w, 30)
	hint_label.position = Vector2(0, _ground() - 62)
	hint_label.size = Vector2(w, 26)
	panel.position = _panel_pos(panel_shown)
	toast.size = Vector2(minf(w - 40, 560), 38)
	toast.position = Vector2((w - toast.size.x) * 0.5, 178)
	toast_label.size = toast.size


func _panel_pos(shown: bool) -> Vector2:
	return Vector2((size.x - PANEL_W) * 0.5, size.y - PANEL_H - 16 + (0.0 if shown else 160.0))


func _ground() -> float:
	return size.y * 0.80


func _seed_c() -> Vector2:
	return Vector2(size.x * 0.5, _ground() - 118.0 + sin(t * 1.3) * 6.0)


# ---------------------------------------------------------------------------------------- game flow

func _process(dt: float) -> void:
	dt = minf(dt, 0.25)
	t += dt
	econ.advance(dt)
	if autotap:
		_auto_t += dt
		while _auto_t >= 0.16:
			_auto_t -= 0.16
			_tap(_seed_c())
			while econ.can_buy_sprout() and econ.panel_unlocked:
				_buy()
	if econ.panel_unlocked and not panel_shown:
		_show_panel(true)
	kick = maxf(0.0, kick - dt * 3.0)
	light = lerpf(light, minf(float(econ.sprouts) / MAX_VISIBLE, 1.0), 1.0 - exp(-2.0 * dt))
	for i in grow.size():
		grow[i] = minf(1.0, grow[i] + dt / 1.3)
	_step_fx(dt)
	_refresh_ui(dt)
	var h := (get_local_mouse_position() - _seed_c()).length() < 78.0
	if h != _hover:
		_hover = h
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if h else Control.CURSOR_ARROW
	back.queue_redraw()
	front.queue_redraw()


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
	floaters.append({"p": c + Vector2(randf_range(-34, 34), -48), "text": "+" + v.fmt(), "life": 0.0})
	sap_label.scale = Vector2(1.07, 1.07)
	Hub.sfx("ui_click")


func _buy() -> void:
	if not econ.buy_sprout():
		return
	if econ.sprouts <= MAX_VISIBLE:
		grow.append(0.0)
	var x := _sprout_x(mini(econ.sprouts, MAX_VISIBLE) - 1)
	var base := Vector2(x, _ground())
	var cols: Array[Color] = [TEAL, Color(0.5, 1.0, 0.6), GOLD]
	for i in 16:
		var ang := -PI * 0.5 + randf_range(-1.1, 1.1)
		parts.append({"p": base, "v": Vector2.from_angle(ang) * randf_range(40.0, 150.0), "life": 0.0,
			"max": randf_range(0.7, 1.3), "col": cols[randi() % 3], "r": randf_range(1.5, 3.0)})
	rings.append({"r": 8.0, "a": 0.8, "w": 3.0, "at": base})
	Hub.sfx("place_item")


func _sprout_x(i: int) -> float:
	return size.x * 0.5 + SLOTS[i]


func _show_panel(animate: bool) -> void:
	panel_shown = true
	panel.visible = true
	if animate:
		panel.position = _panel_pos(false)
		var tw := create_tween()
		tw.tween_property(panel, "position", _panel_pos(true), 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Hub.sfx("glyph_learn")
	else:
		panel.position = _panel_pos(true)


func _refresh_ui(dt: float) -> void:
	sap_label.text = econ.sap.fmt()
	sap_label.scale = sap_label.scale.lerp(Vector2.ONE, 1.0 - exp(-14.0 * dt))
	if econ.sprouts > 0:
		rate_label.text = "+%s per second" % econ.sap_per_sec().fmt(1)
		rate_label.modulate.a = minf(1.0, rate_label.modulate.a + dt * 2.0)
	hint_label.modulate.a = (1.0 if econ.taps == 0 else 0.0) * (0.55 + 0.45 * sin(t * 3.0))
	if not panel_shown:
		return
	var cost := econ.sprout_cost()
	var ok := econ.can_buy_sprout()
	sub_label.text = "+%s Sap/s each   ·   owned %d" % [BigNum.of(Economy.SPROUT_RATE).fmt(1), econ.sprouts]
	buy_btn.text = "Buy x1\n%s Sap" % cost.fmt()
	buy_btn.disabled = not ok
	buy_btn.modulate = Color.WHITE.lerp(Color(1.25, 1.15, 0.9), 0.5 + 0.5 * sin(t * 5.0)) if ok else Color.WHITE
	_bar_v = lerpf(_bar_v, econ.sap.ratio(cost), 1.0 - exp(-10.0 * dt))
	bar.queue_redraw()


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


# ---------------------------------------------------------------------------------------- drawing

func _draw_bar() -> void:
	var r := Rect2(Vector2.ZERO, bar.size)
	bar.draw_rect(r, Color(1, 1, 1, 0.08))
	var fw := r.size.x * _bar_v
	if fw > 1.0:
		bar.draw_rect(Rect2(0, 0, fw, r.size.y), TEAL.lerp(GOLD, _bar_v * _bar_v))
		bar.draw_circle(Vector2(fw, 4), 5.0, Color(1, 0.95, 0.8, 0.5))


func _draw_back() -> void:
	var c := _seed_c()
	var g := _ground()
	var pulse := 1.0 + 0.04 * sin(t * 2.0) + 0.06 * kick
	# ground pool of light (flattened circles)
	back.draw_set_transform(Vector2(c.x, g), 0.0, Vector2(1.0, 0.16))
	for i in 10:
		var f := 1.0 - float(i) / 10.0
		back.draw_circle(Vector2.ZERO, (230.0 + 260.0 * light) * f, Color(TEAL.lerp(GOLD, light), 0.018 + 0.012 * light))
	back.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# halo
	for i in 14:
		var f := 1.0 - float(i) / 14.0
		back.draw_circle(c, (150.0 + 130.0 * light) * f * pulse, Color(VIOLET.lerp(TEAL, f), 0.016 + 0.01 * light + 0.01 * kick))
	# fractal rings: arcs spawning smaller arcs, slowly turning
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
	for i in grow.size():
		var gp := _ease_back(grow[i])
		back.draw_circle(Vector2(_sprout_x(i), g - 56.0 * gp), 34.0 * gp, Color(TEAL, 0.07))


func _ring_fractal(ci: CanvasItem, c: Vector2, r: float, depth: int, rot: float, a: float) -> void:
	ci.draw_arc(c, r, 0, TAU, 48, Color(TEAL.lerp(CYAN, 0.4), 0.30 * a), 1.5, true)
	if depth <= 0:
		return
	for i in 3:
		var ang := rot + i * TAU / 3.0
		_ring_fractal(ci, c + Vector2.from_angle(ang) * r, r * 0.42, depth - 1, rot * -1.3 + 0.7, a * 0.8)


func _draw_front() -> void:
	var c := _seed_c()
	var g := _ground()
	for i in grow.size():
		var gp := _ease_back(grow[i])
		var x := _sprout_x(i)
		var ln := (34.0 + 10.0 * float((i * 7) % 5) / 4.0) * gp
		_draw_tree(front, Vector2(x, g), 0.0, ln, 4, gp, float(i) * 1.7, 3.0)
	# seed body
	var s := (1.0 + 0.03 * sin(t * 2.0) - 0.07 * kick + (0.05 if _hover else 0.0))
	var r := 38.0 * s
	for i in 12:
		var f := float(i) / 11.0
		var col := Color(0.16, 0.05, 0.34).lerp(Color(0.1, 0.6, 0.6), f * 0.9).lerp(Color(1.0, 0.86, 0.5), pow(f, 3.0))
		front.draw_circle(c + Vector2(-5, -6) * f, r * (1.0 - f * 0.86), col)
	var pts := PackedVector2Array()
	for i in 60:
		var a := i * 0.21 + t * 0.6
		pts.append(c + Vector2(-5, -6) * 0.5 + Vector2.from_angle(a) * (3.0 + i * 0.45) * s)
	front.draw_polyline(pts, Color(1, 0.95, 0.8, 0.55), 1.4, true)
	front.draw_arc(c, r, 0, TAU, 48, Color(GOLD, 0.9), 2.0, true)
	front.draw_circle(c + Vector2(-13, -16) * s, 5.0, Color(1, 1, 1, 0.45))
	for f in floaters:
		var k: float = f["life"] / 1.1
		var a := 1.0 - k * k
		var pp: Vector2 = f["p"]
		front.draw_string_outline(font, pp, f["text"], HORIZONTAL_ALIGNMENT_CENTER, 90.0, 28, 5, Color(0.02, 0.02, 0.05, a * 0.8))
		front.draw_string(font, pp, f["text"], HORIZONTAL_ALIGNMENT_CENTER, 90.0, 28, Color(1.0, 0.92, 0.65, a))


## Recursive fractal sprout: each branch forks in two, shorter and brighter towards the tips.
func _draw_tree(ci: CanvasItem, p: Vector2, ang: float, ln: float, depth: int, gp: float, phase: float, w: float) -> void:
	var sway := sin(t * 1.1 + phase + depth * 0.8) * 0.05 * (5 - depth)
	var a := ang + sway
	var q := p + Vector2(sin(a), -cos(a)) * ln
	var k := 1.0 - float(depth) / 4.0
	ci.draw_line(p, q, Color(0.16, 0.55, 0.45).lerp(Color(0.55, 1.0, 0.8), k), maxf(w, 1.0), true)
	if depth <= 0:
		ci.draw_circle(q, 2.6 * maxf(gp, 0.3), Color(GOLD, 0.95))
		return
	_draw_tree(ci, q, a - 0.52, ln * 0.74, depth - 1, gp, phase, w * 0.68)
	_draw_tree(ci, q, a + 0.52, ln * 0.74, depth - 1, gp, phase + 1.3, w * 0.68)


func _ease_back(x: float) -> float:
	var c1 := 1.70158
	return 1.0 + (c1 + 1.0) * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


# ---------------------------------------------------------------------------------------- save / load

func _save() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(econ.to_dict()))


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
	grow.clear()
	for i in mini(econ.sprouts, MAX_VISIBLE):
		grow.append(1.0)
	light = minf(float(econ.sprouts) / MAX_VISIBLE, 1.0)
	var away := Time.get_unix_time_from_system() - float(d.get("saved_at", Time.get_unix_time_from_system()))
	if away >= 60.0 and econ.sprouts > 0:
		var gained := econ.apply_offline(away)
		_toast("Welcome back. The garden grew %s Sap while you were away." % gained.fmt())


func _toast(s: String) -> void:
	toast_label.text = s
	var tw := create_tween()
	tw.tween_property(toast, "modulate:a", 1.0, 0.5)
	tw.tween_interval(4.0)
	tw.tween_property(toast, "modulate:a", 0.0, 1.0)
