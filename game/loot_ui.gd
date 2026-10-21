class_name LootUI
extends Control
## Three item altars. show_offers(ids) -> signal chosen(id).

signal chosen(id: String)

const CELL := 44.0
var ids: Array = []
var _hover := -1
var _picked := -1
var _t := 0.0
var _appear := 0.0
var _flash := 0.0
var _rects: Array[Rect2] = []


func _ready() -> void:
	UiKit.fit_control(self)
	mouse_filter = Control.MOUSE_FILTER_STOP


func show_offers(offer_ids: Array) -> void:
	ids = offer_ids.duplicate()
	_picked = -1
	_hover = -1
	_appear = 0.0
	_flash = 0.0
	_rects.clear()
	var n := maxi(ids.size(), 1)
	var w := 250.0
	var gap := 28.0
	var x0 := (size.x - (w * n + gap * (n - 1))) * 0.5
	for i in ids.size():
		_rects.append(Rect2(x0 + i * (w + gap), 112, w, 400))
	visible = true
	set_process(true)


func pick(i: int) -> void:   # also the test hook
	if _picked >= 0 or i < 0 or i >= ids.size():
		return
	_picked = i
	_flash = 0.0
	Hub.sfx("ui_click")
	var id: String = ids[i]
	get_tree().create_timer(0.7).timeout.connect(func(): chosen.emit(id))


func _process(dt: float) -> void:
	_t += dt
	_appear = minf(_appear + dt * 1.6, 3.0)
	if _picked >= 0:
		_flash += dt
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		_hover = -1
		for i in _rects.size():
			if _rects[i].has_point(e.position):
				_hover = i
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for i in _rects.size():
			if _rects[i].has_point(e.position):
				pick(i)


func _effect_line(d: Dictionary) -> String:
	var ef: Dictionary = d.get("effect", {})
	var a := int(ef.get("amount", 0))
	match str(ef.get("type", "")):
		"damage": return "Deal %d damage" % a
		"multi_damage": return "Deal %d damage x%d" % [a, int(ef.get("hits", 2))]
		"block": return "Gain %d block" % a
		"heal": return "Heal %d" % a
		"energy": return "Gain %d energy" % a
		"damage_per_adjacent": return "%d damage per neighbour" % a
		"turn_start_block_per_adjacent": return "%d block per neighbour each turn" % a
		"identify": return "Reveals hidden things"
	return "Passive"


func _draw() -> void:
	UiKit.text(self, "Take one.", Vector2(0, 74), 34, Color(UiKit.CREAM, 0.95 * minf(_appear, 1.0)), size.x, HORIZONTAL_ALIGNMENT_CENTER)
	for i in ids.size():
		var def: Dictionary = ItemDB.get_def(ids[i])
		var e := UiKit.ease_out(clampf(_appear - i * 0.25, 0.0, 1.0))
		var r := _rects[i]
		r.position.y += (1.0 - e) * 50.0
		if _picked >= 0 and _picked != i:
			e *= maxf(0.0, 1.0 - _flash * 2.5)
		var hot := 1.0 if (_hover == i or _picked == i) else 0.0
		var col: Color = UiKit.RARITY.get(int(def.get("rarity", 1)), UiKit.TEAL)
		UiKit.panel(self, r, col, hot, e)
		var c := r.get_center()
		var ic := Vector2(c.x, r.position.y + 150)
		UiKit.glow(self, ic, 120.0 + 12.0 * sin(_t * 2.0 + i), Color(col, 0.5 * e))
		var sz := Vector2(ItemDB.shape_size(ids[i], 0))
		var px := minf(CELL, minf(170.0 / maxf(sz.x, 1.0), 170.0 / maxf(sz.y, 1.0))) * 1.3
		var ir := Rect2(ic - sz * px * 0.5, sz * px)
		ir.position.y += sin(_t * 1.6 + i * 1.7) * 3.0
		if e > 0.05:
			UiKit.icon(self, ids[i], ir, _t, hot)
		var key := "item:" + str(ids[i])
		var nm := Lexicon.display_name(key)
		UiKit.word(self, key, Vector2(c.x, r.position.y + 268), 30.0, Color(UiKit.CREAM, e), 2.0)
		if nm != "":
			UiKit.text(self, nm, Vector2(r.position.x, r.position.y + 318), 19, Color(UiKit.GOLD, e), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		UiKit.text(self, _effect_line(def), Vector2(r.position.x, r.position.y + 348), 17, Color(UiKit.CREAM, 0.85 * e), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		UiKit.text(self, "Cost %d" % int(def.get("cost", 0)), Vector2(r.position.x, r.position.y + 372), 16, Color(UiKit.CYAN, 0.8 * e), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		if hot > 0.0 and _picked < 0:
			var tip := str(def.get("desc", ""))
			if ItemDB.has_undiscovered_secrets(ids[i]):
				tip += "\n...there is more."
			var tr := Rect2(r.position.x - 10, r.end.y + 12, r.size.x + 20, 62)
			UiKit.panel(self, tr, col, 0.0, 0.95, 10)
			UiKit.wrapped(self, tip, tr.position + Vector2(14, 26), 16, Color(UiKit.CREAM, 0.9), tr.size.x - 28)
		if _picked == i:
			for k in 3:
				var f := clampf(_flash * 1.6 - k * 0.15, 0.0, 1.0)
				draw_arc(ic, 40.0 + f * 260.0, 0, TAU, 64, Color(col, (1.0 - f) * 0.8), 3.0)
