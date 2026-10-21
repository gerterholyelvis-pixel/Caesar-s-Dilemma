class_name DilemmaUI
extends Control
## The one place with readable story text. show(d) -> signal chosen(index).

signal chosen(index: int)

var d: Dictionary = {}
var _shown := 0.0
var _hover := -1
var _picked := -1
var _t := 0.0
var _tready := -1.0
var _appear := 0.0
var _rects: Array[Rect2] = []


func _ready() -> void:
	UiKit.fit_control(self)


func show_dilemma(dilemma: Dictionary) -> void:
	d = dilemma
	_shown = 0.0
	_appear = 0.0
	_picked = -1
	_hover = -1
	_tready = -1.0
	_rects.clear()
	var n: int = (d.get("choices", []) as Array).size()
	var w := (880.0 - 24.0 * (n - 1)) / maxf(n, 1)
	for i in n:
		_rects.append(Rect2(40 + i * (w + 24), 340, w, 250))
	visible = true
	set_process(true)


func choose(i: int) -> void:   # also the test hook
	if _picked >= 0 or i < 0 or i >= _rects.size():
		return
	_picked = i
	Hub.sfx("ui_click")
	get_tree().create_timer(0.6).timeout.connect(func(): chosen.emit(i))


func skip_text() -> void:
	_shown = 9999.0


func _process(dt: float) -> void:
	_t += dt
	_appear = minf(_appear + dt * 1.5, 1.0)
	_shown += dt * 38.0
	if _tready < 0.0 and _shown >= str(d.get("text", "")).length():
		_tready = 0.0
	elif _tready >= 0.0:
		_tready += dt
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		_hover = -1
		for i in _rects.size():
			if _rects[i].has_point(e.position):
				_hover = i
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if _tready < 0.0:
			skip_text()
			return
		for i in _rects.size():
			if _rects[i].has_point(e.position):
				choose(i)


static func effect_line(e: Dictionary) -> Array:   # [text, good(1)/bad(-1)/neutral(0)]
	var a := int(e.get("amount", 0))
	var sgn := 1 if a > 0 else -1
	match str(e.get("type", "")):
		"max_hp": return ["%+d max HP" % a, sgn]
		"hp": return ["%+d HP" % a, sgn]
		"heal_all": return ["Heal fully", 1]
		"gold": return ["%+d gold" % a, sgn]
		"item": return ["Gain an item", 1]
		"curse_item": return ["An item is cursed", -1]
		"remove_item": return ["Lose an item", -1]
		"shrink_pack": return ["Pack shrinks by %d" % a, -1]
		"grow_pack": return ["Pack grows by %d" % a, 1]
		"reveal_glyph": return ["Learn %d hidden word%s" % [a, "" if a == 1 else "s"], 1]
		"change_path":
			var m := str(e.get("mode", ""))
			var tx := {"wither": "A branch withers", "sprout": "A new fork grows", "swap": "A branch changes",
				"reveal": "Hidden paths revealed", "hide": "The way ahead blurs"}
			return [tx.get(m, "The path shifts"), 1 if m in ["sprout", "reveal"] else (-1 if m in ["wither", "hide"] else 0)]
	return ["???", 0]


func _draw() -> void:
	var e := UiKit.ease_out(_appear)
	var txt := str(d.get("text", ""))
	var box := Rect2(60, 30 - (1.0 - e) * 20, 840, 280)
	UiKit.panel(self, box, UiKit.VIOLET, 0.0, e, 20)
	draw_circle(Vector2(480, 30), 5, Color(UiKit.GOLD, e))
	UiKit.text(self, str(d.get("title", "")), Vector2(box.position.x, 78), 30, Color(UiKit.GOLD, e), box.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	draw_line(Vector2(380, 94), Vector2(580, 94), Color(UiKit.GOLD, 0.4 * e), 1.0)
	var n := mini(int(_shown), txt.length())
	UiKit.wrapped(self, txt.substr(0, n), Vector2(box.position.x + 50, 140), 25, Color(UiKit.CREAM, e), box.size.x - 100, HORIZONTAL_ALIGNMENT_CENTER)
	if n < txt.length():
		draw_circle(Vector2(480, 290), 3, Color(UiKit.GOLD, 0.5 + 0.5 * sin(_t * 8.0)))
	if _tready < 0.0:
		return
	var choices: Array = d.get("choices", [])
	for i in choices.size():
		var local := UiKit.ease_out(clampf((_tready - i * 0.2) * 2.0, 0.0, 1.0))
		if local <= 0.0:
			continue
		var r := _rects[i]
		r.position.y += (1.0 - local) * 30.0
		var hot := 1.0 if (_hover == i or _picked == i) else 0.0
		if _picked >= 0 and _picked != i:
			local *= 0.25
		UiKit.panel(self, r, UiKit.TEAL if i % 2 == 0 else UiKit.MAGENTA, hot, local)
		UiKit.wrapped(self, str(choices[i].get("label", "")), r.position + Vector2(20, 40), 21, Color(UiKit.CREAM, local), r.size.x - 40)
		var y := r.position.y + 100.0
		for ef in choices[i].get("effects", []):
			var l := effect_line(ef)
			var col: Color = UiKit.TEAL if l[1] > 0 else (Color(1, 0.45, 0.4) if l[1] < 0 else UiKit.GOLD)
			draw_circle(Vector2(r.position.x + 28, y - 6), 3.5, Color(col, local))
			UiKit.text(self, l[0], Vector2(r.position.x + 42, y), 18, Color(col, local), r.size.x - 56)
			y += 26.0
		UiKit.wrapped(self, str(choices[i].get("flavor", "")), Vector2(r.position.x + 20, r.end.y - 52), 15,
			Color(UiKit.GOLD, (0.45 + 0.45 * hot) * local), r.size.x - 40)
