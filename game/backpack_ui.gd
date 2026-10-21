class_name BackpackUI
extends Control
## The backpack grid: one custom Control, custom input, baked item icons.
## Modes: "arrange" (drag/rotate/place), "combat" (click affordable actives), "view" (hover only).
## Pure presentation over Backpack; every mutation goes through bp.place/bp.move.

signal item_clicked(uid: int)
signal item_hovered(uid: int)
signal placed(uid: int)
signal hold_finished(placed: bool)
signal sfx_event(name: String)   ## "pick" | "place" | "invalid" | "rotate" | "link" | "click" (caller may route to Sfx)

const PAD := 14.0
const MAX_CELL := 64.0
const GOLD := Color(0.95, 0.8, 0.4)
const TEAL := Color(0.3, 0.95, 0.85)
const VIOLET := Color(0.72, 0.45, 1.0)
const MAGENTA := Color(1.0, 0.38, 0.8)
const OK_COL := Color(0.35, 1.0, 0.55)
const BAD_COL := Color(1.0, 0.3, 0.32)
const TIP_DELAY := 0.35

var bp: Backpack
var mode := "arrange"
var energy := 3:
	set(v):
		energy = v
		queue_redraw()
var used: Array = []:
	set(v):
		used = v
		queue_redraw()

var _cell := 60.0
var _origin := Vector2.ZERO
var _time := 0.0
var _hover := -1
var _hover_t := 0.0
var pin_hover := false   # test hook: keep hover without a real pointer
var _held: Dictionary = {}          # {id, rot, uid(-1 new), pos, from_rot, drag, press_pos, press_t, new}
var _gpos := Vector2.ZERO           # eased ghost top-left (px)
var _gvalid := false
var _ganchor := Vector2i.ZERO
var _gsnapped := false
var _pop: Dictionary = {}           # uid -> start time
var _shk: Dictionary = {}           # uid (-1 ghost) -> start time
var _shim: Dictionary = {}          # "a-b" -> start time
var _prev_sig: Dictionary = {}      # uid -> "x,y,r"
var _links: Dictionary = {}         # "a-b" -> strength
var _first := true
var _icons: Script = null
var _baked: Dictionary = {}         # key -> Texture2D
var _pending: Dictionary = {}
var _tip: _Tip
var _box := StyleBoxFlat.new()

# ------------------------------------------------------------------ setup

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	clip_contents = false
	sfx_event.connect(func(n: String) -> void:
		Hub.sfx({"pick": "ui_click", "place": "place_item", "invalid": "invalid", "rotate": "rotate_item", "link": "ui_hover", "click": "ui_click"}.get(n, "ui_click")))
	_box.set_corner_radius_all(6)
	_box.anti_aliasing = true
	if ResourceLoader.exists("res://game/item_icons.gd"):
		_icons = load("res://game/item_icons.gd")
	_tip = _Tip.new()
	_tip.top_level = true
	_tip.visible = false
	add_child(_tip)

func setup(p_bp: Backpack, p_mode: String = "arrange") -> void:
	if bp != null and bp.changed.is_connected(refresh):
		bp.changed.disconnect(refresh)
	bp = p_bp
	mode = p_mode
	bp.changed.connect(refresh)
	custom_minimum_size = Vector2(bp.w * 60.0 + PAD * 2.0, bp.h * 60.0 + PAD * 2.0)
	_first = true
	_held = {}
	refresh()

func refresh() -> void:
	if bp == null:
		return
	_layout()
	var sigs: Dictionary = {}
	for e in bp.placed:
		var uid: int = int(e.uid)
		var sig := "%d,%d,%d" % [e.pos.x, e.pos.y, int(e.rot)]
		sigs[uid] = sig
		if not _first and _prev_sig.get(uid, "") != sig:
			_pop[uid] = _time
	_prev_sig = sigs
	var nl := _compute_links()
	for k in nl:
		if not _first and not _links.has(k):
			_shim[k] = _time
			sfx_event.emit("link")
	_links = nl
	_first = false
	if _hover != -1 and bp.entry(_hover).is_empty():
		_set_hover(-1)
	queue_redraw()

func hold(item_id: String) -> void:
	if ItemDB.get_def(item_id).is_empty():
		return
	_held = {"id": item_id, "rot": 0, "uid": -1, "new": true, "drag": false}
	_gpos = get_local_mouse_position() - Vector2(ItemDB.shape_size(item_id, 0)) * _cell * 0.5
	_hide_tip()
	sfx_event.emit("pick")
	_update_ghost()

func is_holding() -> bool:
	return not _held.is_empty()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()
		queue_redraw()

func _layout() -> void:
	if bp == null:
		return
	var avail := size - Vector2(PAD * 2.0, PAD * 2.0)
	if avail.x < 8.0 or avail.y < 8.0:
		avail = Vector2(bp.w * 60.0, bp.h * 60.0)
	_cell = clampf(floorf(minf(avail.x / bp.w, avail.y / bp.h)), 24.0, MAX_CELL)
	var gs := Vector2(bp.w, bp.h) * _cell
	_origin = ((size - gs) * 0.5).floor()
	if size.x < 8.0:
		_origin = Vector2(PAD, PAD)

# ------------------------------------------------------------------ logic helpers (also used by tests)

func cell_size() -> float:
	return _cell

func held_rot() -> int:
	return int(_held.get("rot", 0))

func rotate_held() -> bool:
	if _held.is_empty():
		return false
	_held.rot = (int(_held.rot) + 1) % 4
	_pop[-1] = _time
	sfx_event.emit("rotate")
	_update_ghost()
	if not _gvalid and _gsnapped:
		_shk[-1] = _time   # re-validated: shake when the rotated shape no longer fits
		sfx_event.emit("invalid")
	return true

func can_drop(anchor: Vector2i) -> bool:
	if _held.is_empty() or bp == null:
		return false
	return bp.can_place(String(_held.id), anchor, int(_held.rot), int(_held.uid))

func drop_at(anchor: Vector2i) -> bool:
	if not can_drop(anchor):
		_shk[-1] = _time
		sfx_event.emit("invalid")
		return false
	var h := _held
	var uid: int = int(h.uid)
	if uid == -1:
		uid = bp.place(String(h.id), anchor, int(h.rot))
	else:
		bp.move(uid, anchor, int(h.rot))
	_held = {}
	_pop[uid] = _time
	sfx_event.emit("place")
	placed.emit(uid)
	if bool(h.get("new", false)):
		hold_finished.emit(true)
	_update_hover()
	queue_redraw()
	return true

func cancel_hold() -> void:
	if _held.is_empty():
		return
	var h := _held
	_held = {}
	if int(h.uid) != -1:
		_pop[int(h.uid)] = _time
	if bool(h.get("new", false)):
		hold_finished.emit(false)
	queue_redraw()

## Best anchor for a pointer position (snaps to a nearby valid spot if one exists).
func anchor_for(local_pos: Vector2) -> Dictionary:
	var id: String = _held.id
	var rot: int = _held.rot
	var sz := Vector2(ItemDB.shape_size(id, rot))
	var f := (local_pos - _origin) / _cell - sz * 0.5
	var base := Vector2i(roundi(f.x), roundi(f.y))
	var gs := Vector2(bp.w, bp.h) * _cell
	var area := Rect2(_origin, gs).grow(_cell * 0.6)
	var inside := area.has_point(local_pos) or area.intersects(Rect2(_origin + f * _cell, sz * _cell).grow(-_cell * 0.25))
	var best := base
	var best_d := 1e9
	var ok := false
	if inside:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var c := base + Vector2i(dx, dy)
				if can_drop_at(id, c, rot):
					var d := Vector2(c).distance_to(f)
					if d < best_d:
						best_d = d
						best = c
						ok = true
	return {"anchor": best, "valid": ok, "inside": inside}

func can_drop_at(id: String, anchor: Vector2i, rot: int) -> bool:
	return bp.can_place(id, anchor, rot, int(_held.get("uid", -1)))

func _update_ghost() -> void:
	if _held.is_empty() or bp == null:
		return
	var r := anchor_for(get_local_mouse_position())
	_ganchor = r.anchor
	_gvalid = r.valid
	_gsnapped = r.inside

# ------------------------------------------------------------------ synergy links

func _rule_hits(rule: Dictionary, other_id: String) -> bool:
	if rule.has("with_id"):
		return other_id == String(rule.with_id)
	if rule.has("with_tag"):
		return ItemDB.has_tag(other_id, String(rule.with_tag))
	return false

func pair_strength(a_id: String, b_id: String) -> int:
	var n := 0
	for pair in [[a_id, b_id], [b_id, a_id]]:
		var def := ItemDB.get_def(pair[0])
		for r in def.get("synergies", []):
			if _rule_hits(r, pair[1]):
				n += 1
		for s in def.get("secrets", []):
			if ItemDB.is_discovered(pair[0], String(s.get("id", ""))) and _rule_hits(s, pair[1]):
				n += 1
	return n

func _compute_links() -> Dictionary:
	var out: Dictionary = {}
	for uid in bp.uids():
		for nb in bp.neighbors(uid):
			if nb > uid:
				var s := pair_strength(bp.id_of(uid), bp.id_of(nb))
				if s > 0:
					out["%d-%d" % [uid, nb]] = s
	return out

## Strength of the link between two uids (0 if none); for tests.
func link_strength(a: int, b: int) -> int:
	return int(_links.get("%d-%d" % [mini(a, b), maxi(a, b)], 0))

# ------------------------------------------------------------------ input

func _gui_input(event: InputEvent) -> void:
	if bp == null:
		return
	if event is InputEventMouseMotion:
		_update_hover()
		_update_ghost()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_on_left_press(mb.position)
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_on_left_release(mb.position)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if not _held.is_empty():
				rotate_held()
			elif mode == "arrange" and _hover != -1:
				_rotate_in_place(_hover)
			accept_event()

func _input(event: InputEvent) -> void:
	if bp == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: InputEventKey = event
		if not _held.is_empty():
			if k.keycode == KEY_R:
				rotate_held()
				get_viewport().set_input_as_handled()
			elif k.keycode == KEY_ESCAPE:
				cancel_hold()
				get_viewport().set_input_as_handled()
		elif k.keycode == KEY_R and mode == "arrange" and _hover != -1 and is_visible_in_tree():
			_rotate_in_place(_hover)
			get_viewport().set_input_as_handled()

func _rotate_in_place(uid: int) -> void:
	var e := bp.entry(uid)
	if e.is_empty():
		return
	var id: String = e.id
	var rot := (int(e.rot) + 1) % 4
	var sz_old := Vector2(ItemDB.shape_size(id, int(e.rot)))
	var sz_new := Vector2(ItemDB.shape_size(id, rot))
	var c0 := Vector2(e.pos) + sz_old * 0.5
	var base := Vector2i(roundi(c0.x - sz_new.x * 0.5), roundi(c0.y - sz_new.y * 0.5))
	for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if bp.can_place(id, base + d, rot, uid):
			bp.move(uid, base + d, rot)
			sfx_event.emit("rotate")
			return
	_shk[uid] = _time
	sfx_event.emit("invalid")

func _on_left_press(p: Vector2) -> void:
	if not _held.is_empty():
		if not _held.get("drag", false):
			_update_ghost()
			drop_at(_ganchor)
		return
	var uid := bp.uid_at(_cell_at(p))
	if uid == -1:
		return
	if _clickable(uid):
		item_clicked.emit(uid)
	else:
		_shk[uid] = _time
	if mode == "arrange":
		var e := bp.entry(uid)
		_held = {"id": e.id, "rot": int(e.rot), "uid": uid, "new": false, "drag": true,
				"pos": e.pos, "press_pos": p, "press_t": _time}
		_gpos = _origin + Vector2(e.pos) * _cell
		_hide_tip()
		sfx_event.emit("pick")
		_update_ghost()
	elif mode == "combat" and not _clickable(uid):
		sfx_event.emit("invalid")
	else:
		sfx_event.emit("click")

func _on_left_release(p: Vector2) -> void:
	if _held.is_empty() or not _held.get("drag", false):
		return
	if p.distance_to(_held.press_pos) < 6.0 and _time - float(_held.press_t) < 0.3:
		_held.drag = false          # a click: keep carrying until the next click
		return
	_update_ghost()
	if not drop_at(_ganchor):
		var uid: int = int(_held.uid)
		_held = {}
		_shk[uid] = _time
		_pop[uid] = _time

func _clickable(uid: int) -> bool:
	if mode == "view":
		return true
	if mode != "combat":
		return true
	var def := ItemDB.get_def(bp.id_of(uid))
	return String(def.get("kind", "")) == "active" and not used.has(uid) and int(def.get("cost", 0)) <= energy

func _cell_at(p: Vector2) -> Vector2i:
	var q := (p - _origin) / _cell
	return Vector2i(floori(q.x), floori(q.y))

func _update_hover() -> void:
	if not _held.is_empty():
		_set_hover(-1)
		return
	_set_hover(bp.uid_at(_cell_at(get_local_mouse_position())))

func _set_hover(uid: int) -> void:
	if uid == _hover:
		return
	_hover = uid
	_hover_t = 0.0
	_hide_tip()
	item_hovered.emit(uid)
	if uid != -1 and (mode == "arrange" or _clickable(uid)) and mode != "view":
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		mouse_default_cursor_shape = Control.CURSOR_ARROW
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	if bp == null or not is_visible_in_tree():
		return
	if not _held.is_empty():
		_update_ghost()
		var target := get_local_mouse_position() - Vector2(ItemDB.shape_size(String(_held.id), int(_held.rot))) * _cell * 0.5
		if _gsnapped and _gvalid:
			target = _origin + Vector2(_ganchor) * _cell
		_gpos = _gpos.lerp(target, 1.0 - exp(-delta * 24.0))
	var mouse_in := Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position())
	if _hover != -1 and not mouse_in and not pin_hover:
		_set_hover(-1)
	elif _hover == -1 and _held.is_empty() and mouse_in:
		_update_hover()
	if _hover != -1:
		_hover_t += delta
		if _hover_t > TIP_DELAY and not _tip.visible:
			_show_tip(_hover)
		if _tip.visible:
			_tip.modulate.a = minf(1.0, (_hover_t - TIP_DELAY) * 6.0)
			_tip.follow(get_global_mouse_position())
	queue_redraw()

# ------------------------------------------------------------------ tooltip

func _show_tip(uid: int) -> void:
	var id := bp.id_of(uid)
	var lines: PackedStringArray = bp.describe(uid).split("\n")
	var key := "item:" + id
	var nm := ""
	if Lexicon.has_concept(key) and Lexicon.is_known(key):
		nm = Lexicon.readable_name(key)
	if lines.size() > 0:
		lines.remove_at(0)   # English name is only shown once learned
	_tip.set_content(key, nm, lines)
	_tip.modulate.a = 0.0
	_tip.visible = true
	_tip.follow(get_global_mouse_position())

func _hide_tip() -> void:
	if _tip != null:
		_tip.visible = false

func _exit_tree() -> void:
	_hide_tip()

# ------------------------------------------------------------------ drawing

static func item_color(id: String, icons: Script) -> Color:
	if icons != null:
		var v: Variant = icons.call("cell_color", id)
		if v is Color:
			return v
	var h := absi(id.hash())
	return Color.from_hsv(float(h % 360) / 360.0, 0.55, 0.9)

## Draws an item icon (rot 0 art rotated by rot quarter-turns) into rect (the ROTATED bounding rect).
static func draw_icon(ci: CanvasItem, icons: Script, id: String, rot: int, rect: Rect2, t: float, glow: float, base := Transform2D.IDENTITY) -> void:
	var nat := rect.size if rot % 2 == 0 else Vector2(rect.size.y, rect.size.x)
	var tr := base * Transform2D(rot * PI * 0.5, rect.get_center())
	ci.draw_set_transform_matrix(tr)
	var r := Rect2(-nat * 0.5, nat)
	if icons != null:
		icons.call("draw", ci, id, r, t, glow)
	else:
		var c := item_color(id, null)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(c, 0.35)
		sb.border_color = c
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(10)
		ci.draw_style_box(sb, r.grow(-4))
	ci.draw_set_transform_matrix(base)

## Glyph word for a lexicon key: determinative frame + root glyphs, left-aligned at 'left_center'. Returns width.
static func draw_word(ci: CanvasItem, key: String, left_center: Vector2, sz: float, col: Color) -> float:
	var w: Array[int] = Lexicon.word_for(key)
	if w.is_empty():
		return 0.0
	GlyphGen.draw_frame(ci, w[0], Rect2(left_center + Vector2(0, -sz * 0.5), Vector2(sz, sz)), Color(VIOLET, col.a))
	var x := sz * 1.05
	for i in range(1, w.size()):
		GlyphGen.draw(ci, w[i], left_center + Vector2(x + sz * 0.5, 0.0), sz * 0.9, col, maxf(1.5, sz * 0.07))
		x += sz * 0.95
	return x

func _icon_tex(id: String, rot: int, px: Vector2) -> Texture2D:
	var key := "%s|%d|%d" % [id, rot, int(px.x)]
	if _baked.has(key):
		return _baked[key]
	if not _pending.has(key) and DisplayServer.get_name() != "headless" and is_inside_tree():
		_pending[key] = true
		_bake(key, id, rot, px)
	return null

func _bake(key: String, id: String, rot: int, px: Vector2) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(px.ceil())
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.msaa_2d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var node := _Baker.new()
	node.id = id
	node.rot = rot
	node.px = px
	node.icons = _icons
	vp.add_child(node)
	add_child(vp)
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(vp):
		var img := vp.get_texture().get_image()
		if img != null and not img.is_empty():
			_baked[key] = ImageTexture.create_from_image(img)
		vp.queue_free()
	_pending.erase(key)

func _pop_scale(uid: int) -> float:
	if not _pop.has(uid):
		return 1.0
	var u := (_time - float(_pop[uid])) / 0.42
	if u >= 1.0:
		_pop.erase(uid)
		return 1.0
	return 1.0 + 0.13 * exp(-5.0 * u) * sin(u * PI * 2.2 + 0.6) * (1.0 - u * 0.3) + 0.0

func _shake_off(uid: int) -> Vector2:
	if not _shk.has(uid):
		return Vector2.ZERO
	var u := (_time - float(_shk[uid])) / 0.32
	if u >= 1.0:
		_shk.erase(uid)
		return Vector2.ZERO
	return Vector2(sin(u * 40.0) * 6.0 * (1.0 - u), 0.0)

func _slot_rect(c: Vector2i) -> Rect2:
	return Rect2(_origin + Vector2(c) * _cell, Vector2(_cell, _cell))

func _draw() -> void:
	if bp == null:
		return
	var t := _time
	# panel
	var gs := Vector2(bp.w, bp.h) * _cell
	var panel := Rect2(_origin, gs).grow(10.0)
	_box.bg_color = Color(0.02, 0.025, 0.04, 0.82)
	_box.border_color = Color(GOLD, 0.7)
	_box.set_border_width_all(2)
	_box.set_corner_radius_all(10)
	_box.shadow_color = Color(GOLD, 0.12)
	_box.shadow_size = 10
	draw_style_box(_box, panel)
	_box.shadow_size = 0
	_box.border_color = Color(TEAL, 0.14)
	_box.set_border_width_all(1)
	draw_style_box(_box, panel.grow(-4.0))
	# slots
	_box.set_corner_radius_all(5)
	for y in bp.h:
		for x in bp.w:
			var r := _slot_rect(Vector2i(x, y)).grow(-2.0)
			_box.bg_color = Color(0.035, 0.06, 0.07, 0.9)
			_box.border_color = Color(0.45, 0.36, 0.16, 0.38)
			_box.set_border_width_all(1)
			draw_style_box(_box, r)
			var tick := Color(GOLD, 0.22)
			var q := r.grow(-3.0)
			draw_line(q.position, q.position + Vector2(5, 0), tick, 1.0)
			draw_line(q.position, q.position + Vector2(0, 5), tick, 1.0)
			draw_line(q.end, q.end - Vector2(5, 0), tick, 1.0)
			draw_line(q.end, q.end - Vector2(0, 5), tick, 1.0)
	# items
	for e in bp.placed:
		var uid: int = int(e.uid)
		if not _held.is_empty() and int(_held.uid) == uid:
			continue
		_draw_item(uid, e, t)
	_draw_links(t)
	if not _held.is_empty():
		_draw_ghost(t)

func _draw_item(uid: int, e: Dictionary, t: float) -> void:
	var id: String = e.id
	var rot: int = int(e.rot)
	var sz := Vector2(ItemDB.shape_size(id, rot))
	var full := Rect2(_origin + Vector2(e.pos) * _cell, sz * _cell)
	var sc := _pop_scale(uid)
	var c := full.get_center()
	var base := Transform2D(0.0, Vector2(sc, sc), 0.0, c + _shake_off(uid) - c * sc)
	draw_set_transform_matrix(base)
	var col := item_color(id, _icons)
	var hov := uid == _hover and _held.is_empty()
	var def := ItemDB.get_def(id)
	var active: bool = String(def.get("kind", "")) == "active"
	var dim := 0.0
	var ready := false
	if mode == "combat" and active:
		if used.has(uid):
			dim = 0.6
		elif int(def.cost) > energy:
			dim = 0.42
		else:
			ready = true
	var cells := bp.cells_of(uid)
	var occ: Dictionary = {}
	for cc in cells:
		occ[cc] = true
	var fill := Color(col.r * 0.2 + 0.015, col.g * 0.2 + 0.02, col.b * 0.2 + 0.03, 0.95)
	if hov:
		fill = fill.lightened(0.18)
	var rim := Color(col.lerp(GOLD, 0.35), 0.85)
	if ready:
		rim = rim.lerp(Color.WHITE, 0.25 + 0.2 * sin(t * 3.0 + uid))
	_box.set_border_width_all(0)
	_box.set_corner_radius_all(0)
	for cc in cells:
		var r := _slot_rect(cc).grow(-2.0)
		var l := occ.has(cc + Vector2i(-1, 0))
		var rr := occ.has(cc + Vector2i(1, 0))
		var u := occ.has(cc + Vector2i(0, -1))
		var d := occ.has(cc + Vector2i(0, 1))
		if l: r.position.x -= 2.0; r.size.x += 2.0
		if rr: r.size.x += 2.0
		if u: r.position.y -= 2.0; r.size.y += 2.0
		if d: r.size.y += 2.0
		draw_rect(r, fill)
		var w := 2.0 if hov else 1.5
		if not l: draw_line(r.position, Vector2(r.position.x, r.end.y), rim, w)
		if not rr: draw_line(Vector2(r.end.x, r.position.y), r.end, rim, w)
		if not u: draw_line(r.position, Vector2(r.end.x, r.position.y), rim, w)
		if not d: draw_line(Vector2(r.position.x, r.end.y), r.end, rim, w)
	# icon
	var ir := full.grow(-5.0)
	var tex: Texture2D = null
	if not hov:
		tex = _icon_tex(id, rot, ir.size)
	if tex != null:
		draw_texture_rect(tex, ir, false)
	else:
		draw_icon(self, _icons, id, rot, ir, t, 0.75 if hov else 0.0, base)
	draw_set_transform_matrix(base)
	if dim > 0.0:
		for cc in cells:
			draw_rect(_slot_rect(cc).grow(-2.0), Color(0.01, 0.01, 0.02, dim))
		if used.has(uid):
			draw_circle(c, 5.0, Color(0.01, 0.01, 0.02, 0.8))
			draw_arc(c, 5.0, 0, TAU, 16, Color(GOLD, 0.6), 1.5)
	# cost badge (plain number)
	if active:
		var first := cells[0]
		var br := _slot_rect(first)
		var bc := Vector2(br.position.x + 12.0, br.position.y + 12.0)
		draw_circle(bc, 9.0, Color(0.02, 0.02, 0.04, 0.9))
		draw_arc(bc, 9.0, 0, TAU, 20, Color(GOLD, 0.9 if (ready or mode != "combat") else 0.4), 1.5)
		var f := ThemeDB.fallback_font
		draw_string(f, bc + Vector2(-4, 5), str(int(def.cost)), HORIZONTAL_ALIGNMENT_CENTER, 8, 13, Color(1, 0.95, 0.8))
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _item_edge_point(a: int, b: int) -> Array:
	# returns [[pa, pb], ...] centre pairs of adjacent cells between items a and b
	var out: Array = []
	for ca in bp.cells_of(a):
		for d in Backpack.DIRS:
			if bp.uid_at(ca + d) == b:
				out.append([_slot_rect(ca).get_center(), _slot_rect(ca + d).get_center()])
	return out

func _link_color(s: int) -> Color:
	return TEAL if s <= 1 else (GOLD if s == 2 else MAGENTA)

func _draw_links(t: float) -> void:
	for k in _links:
		var ids: PackedStringArray = String(k).split("-")
		var a := int(ids[0])
		var b := int(ids[1])
		if not _held.is_empty() and (int(_held.uid) == a or int(_held.uid) == b):
			continue
		var s: int = _links[k]
		var boost := 1.0
		if _hover != -1 and (_hover == a or _hover == b):
			boost = 1.8
		var sh := 0.0
		if _shim.has(k):
			var u := (t - float(_shim[k])) / 0.9
			if u >= 1.0:
				_shim.erase(k)
			else:
				sh = 1.0 - u
		for pr in _item_edge_point(a, b):
			_draw_link(pr[0], pr[1], s, boost, sh, t, 1.0)

func _draw_link(pa: Vector2, pb: Vector2, s: int, boost: float, sh: float, t: float, alpha: float) -> void:
	var col := _link_color(s)
	var wd := 3.0 + 2.5 * float(s)
	var pulse := 0.75 + 0.25 * sin(t * 2.6 + pa.x * 0.05)
	draw_line(pa, pb, Color(col, 0.10 * boost * alpha * pulse), wd * 3.0)
	draw_line(pa, pb, Color(col, 0.28 * boost * alpha), wd)
	draw_line(pa, pb, Color(col.lightened(0.5), 0.8 * alpha * minf(boost, 1.2)), 1.5)
	var mid := (pa + pb) * 0.5
	draw_circle(mid, wd * 1.4, Color(col, 0.25 * boost * alpha * pulse))
	for i in (1 + s):
		var u := fposmod(t * 0.7 + float(i) / float(1 + s), 1.0)
		draw_circle(pa.lerp(pb, u), 1.8 + 0.4 * s, Color(col.lightened(0.6), 0.9 * alpha * sin(u * PI)))
	if sh > 0.0:
		var ease_u := 1.0 - sh
		draw_circle(mid, 8.0 + 34.0 * ease_u, Color(col, 0.0))
		draw_arc(mid, 6.0 + 40.0 * ease_u, 0, TAU, 28, Color(col.lightened(0.5), 0.8 * sh), 2.0)
		draw_line(pa, pb, Color(1, 1, 1, 0.75 * sh), wd * 1.4)

func _draw_ghost(t: float) -> void:
	var id: String = _held.id
	var rot: int = int(_held.rot)
	var cells := ItemDB.shape_rotated(id, rot)
	var sz := Vector2(ItemDB.shape_size(id, rot))
	var valid := _gvalid and _gsnapped
	var col := OK_COL if valid else BAD_COL
	var gp := _gpos
	var sk := _shake_off(-1)
	var sc := 1.0 + 0.03 * sin(t * 6.0)
	if _pop.has(-1):
		var u := (t - float(_pop[-1])) / 0.25
		if u >= 1.0:
			_pop.erase(-1)
		else:
			sc += 0.12 * (1.0 - u) * (1.0 - u)
	var full := Rect2(gp, sz * _cell)
	var c := full.get_center()
	var base := Transform2D(0.0, Vector2(sc, sc), 0.0, c + sk - c * sc)
	draw_set_transform_matrix(base)
	# snap target marker
	if valid:
		for cc in cells:
			var tr := _slot_rect(cc + _ganchor).grow(-2.0)
			draw_rect(tr, Color(col, 0.10 + 0.05 * sin(t * 5.0)))
	for cc in cells:
		var r := Rect2(gp + Vector2(cc) * _cell, Vector2(_cell, _cell)).grow(-2.0)
		_box.bg_color = Color(col, 0.22)
		_box.border_color = Color(col, 0.95)
		_box.set_border_width_all(2)
		_box.set_corner_radius_all(5)
		draw_style_box(_box, r)
	var ir := full.grow(-5.0)
	var tex := _icon_tex(id, rot, ir.size)
	if tex != null:
		draw_texture_rect(tex, ir, false, Color(1, 1, 1, 0.9))
	else:
		draw_icon(self, _icons, id, rot, ir, t, 0.4, base)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	# preview of the synergies the placement would make
	if valid:
		var seen: Dictionary = {}
		for cc in cells:
			var ac := cc + _ganchor
			for d in Backpack.DIRS:
				var nu := bp.uid_at(ac + d)
				if nu != -1 and nu != int(_held.uid) and not seen.has(nu):
					var s := pair_strength(id, bp.id_of(nu))
					if s > 0:
						seen[nu] = true
						_draw_link(_slot_rect(ac).get_center(), _slot_rect(ac + d).get_center(), s, 1.0, 0.0, t, 0.65)

# ------------------------------------------------------------------ inner classes

class _Baker extends Node2D:
	var id := ""
	var rot := 0
	var px := Vector2(60, 60)
	var icons: Script = null
	func _draw() -> void:
		BackpackUI.draw_icon(self, icons, id, rot, Rect2(Vector2.ZERO, px), 0.0, 0.0)

class _Tip extends Control:
	var key := ""
	var nm := ""
	var lines: PackedStringArray = []
	var _h := 0.0
	const W := 250.0
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 200
	func set_content(p_key: String, p_nm: String, p_lines: PackedStringArray) -> void:
		key = p_key
		nm = p_nm
		lines = p_lines
		var f := ThemeDB.fallback_font
		var h := 12.0 + 34.0 + 6.0
		for l in lines:
			h += f.get_multiline_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, W - 24.0, 13).y + 3.0
		_h = h + 8.0
		size = Vector2(W, _h)
		queue_redraw()
	func follow(gmouse: Vector2) -> void:
		var vr := get_viewport_rect().size
		var p := gmouse + Vector2(18, 20)
		if p.x + W > vr.x - 6.0:
			p.x = gmouse.x - W - 14.0
		if p.y + _h > vr.y - 6.0:
			p.y = gmouse.y - _h - 14.0
		position = Vector2(clampf(p.x, 6.0, maxf(6.0, vr.x - W - 6.0)), clampf(p.y, 6.0, maxf(6.0, vr.y - _h - 6.0)))
	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.015, 0.02, 0.035, 0.95)
		sb.border_color = Color(BackpackUI.GOLD, 0.85)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(8)
		sb.shadow_color = Color(BackpackUI.TEAL, 0.14)
		sb.shadow_size = 8
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var f := ThemeDB.fallback_font
		var wx := BackpackUI.draw_word(self, key, Vector2(14, 28), 26.0, Color(BackpackUI.GOLD))
		if nm != "":
			draw_string(f, Vector2(14 + wx + 8, 34), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.95, 0.8))
		draw_line(Vector2(12, 48), Vector2(W - 12, 48), Color(BackpackUI.GOLD, 0.3), 1.0)
		var y := 58.0
		for l in lines:
			var col := Color(0.86, 0.9, 0.92)
			if l.begins_with("…") or l.begins_with("..."):
				col = Color(BackpackUI.VIOLET.lightened(0.2))
			elif l.begins_with("Secret"):
				col = Color(BackpackUI.MAGENTA.lightened(0.3))
			elif l.begins_with("Passive") or l.begins_with("Active"):
				col = Color(BackpackUI.TEAL)
			var sz := f.get_multiline_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, W - 24.0, 13)
			draw_multiline_string(f, Vector2(12, y + 11), l, HORIZONTAL_ALIGNMENT_LEFT, W - 24.0, 13, -1, col)
			y += sz.y + 3.0
