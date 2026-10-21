class_name ShrineUI
extends Control
## A glyph altar that reveals one unknown word, plus a notebook to pencil a guess. open() -> signal done.

signal done

var rng := RandomNumberGenerator.new()
var key := ""           # the word being revealed
var _state := "idle"    # idle | reveal | shown | empty
var _rt := 0.0
var _t := 0.0
var _appear := 0.0
var _hover := ""
var _book := false
var _unknown: Array[String] = []
var _sel := ""
var _msg := ""
var _edit: LineEdit
var _btn := {"altar": Rect2(330, 120, 300, 300), "book": Rect2(36, 548, 150, 44), "leave": Rect2(774, 548, 150, 44)}
var _rows: Array[Rect2] = []


func _ready() -> void:
	UiKit.fit_control(self)
	_edit = LineEdit.new()
	_edit.position = Vector2(300, 470)
	_edit.size = Vector2(360, 36)
	_edit.placeholder_text = "pencil a guess..."
	_edit.visible = false
	_edit.add_theme_font_override("font", UiKit.font())
	_edit.text_submitted.connect(_submit)
	add_child(_edit)
	rng.randomize()


func open(p_rng: RandomNumberGenerator = null) -> void:
	if p_rng != null:
		rng = p_rng
	key = ""
	_state = "idle"
	_appear = 0.0
	_book = false
	_msg = ""
	visible = true
	set_process(true)


func reveal() -> String:   # also the test hook
	if _state != "idle":
		return key
	key = Lexicon.learn_random(-1, rng)
	_state = "reveal" if key != "" else "empty"
	_rt = 0.0
	Hub.sfx("glyph_learn" if key != "" else "invalid")
	return key


func leave() -> void:
	done.emit()


func _unknown_words() -> void:
	_unknown.clear()
	for k in Lexicon.all_keys():
		if not Lexicon.is_known(k):
			_unknown.append(k)
	_unknown = _unknown.slice(0, 6)
	if _sel == "" or _sel not in _unknown:
		_sel = _unknown[0] if not _unknown.is_empty() else ""


func guess_word(k: String, text: String) -> bool:   # also the test hook
	Lexicon.guess(k, text)
	if Lexicon.confirm_guess_if_correct(k):
		_msg = "The word yields. It was true."
		return true
	_msg = "The pencil mark stays. Nothing answers."
	return false


func _submit(s: String) -> void:
	if _sel == "":
		return
	if guess_word(_sel, s):
		_edit.clear()
		_unknown_words()


func _process(dt: float) -> void:
	_t += dt
	_appear = minf(_appear + dt * 1.3, 1.0)
	if _state == "reveal":
		_rt += dt
		if _rt > 2.6:
			_state = "shown"
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		_hover = ""
		for k in _btn:
			if (_btn[k] as Rect2).has_point(e.position):
				_hover = k
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if _book:
			for i in _rows.size():
				if _rows[i].has_point(e.position):
					_sel = _unknown[i]
					_edit.text = Lexicon.guess_of(_sel)
					return
		if _btn["leave"].has_point(e.position):
			leave()
		elif _btn["book"].has_point(e.position):
			_book = not _book
			_edit.visible = _book
			_unknown_words()
		elif _btn["altar"].has_point(e.position) and not _book:
			reveal()


func _button(name: String, label: String, col: Color) -> void:
	var hot := 1.0 if _hover == name else 0.0
	UiKit.panel(self, _btn[name], col, hot, _appear, 12)
	UiKit.text(self, label, Vector2(_btn[name].position.x, _btn[name].position.y + 29), 18, UiKit.CREAM, _btn[name].size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _draw() -> void:
	var c := Vector2(480, 270)
	var a := UiKit.ease_out(_appear)
	UiKit.text(self, "The stone remembers a word.", Vector2(0, 80), 28, Color(UiKit.CREAM, a), size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var pulse := 0.5 + 0.5 * sin(_t * 1.8)
	UiKit.glow(self, c, 150.0 + 20.0 * pulse + (_rt * 60.0 if _state == "reveal" else 0.0), Color(UiKit.VIOLET, 0.6 * a))
	UiKit.glow(self, c, 90.0, Color(UiKit.TEAL, 0.5 * a))
	for k in 3:
		var rr := 110.0 + k * 22.0
		draw_arc(c, rr, _t * (0.3 + k * 0.1), _t * (0.3 + k * 0.1) + TAU * 0.7, 48, Color(UiKit.GOLD, (0.5 - k * 0.12) * a), 1.5)
	_button("leave", "Walk on", UiKit.GOLD)
	_button("book", "Notebook", UiKit.CYAN)
	match _state:
		"idle":
			GlyphGen.draw(self, 11 + int(_t * 0.4) % 20, c, 130.0, Color(UiKit.GOLD, 0.35 + 0.3 * pulse), 3.0)
			UiKit.text(self, "Touch the altar.", Vector2(0, 480), 20, Color(UiKit.GOLD, 0.6 + 0.4 * pulse), size.x, HORIZONTAL_ALIGNMENT_CENTER)
		"empty":
			UiKit.text(self, "The stone is silent. You know all it can say.", Vector2(0, 280), 20, UiKit.CREAM, size.x, HORIZONTAL_ALIGNMENT_CENTER)
		_:
			var f := 1.0 if _state == "shown" else clampf(_rt / 2.6, 0.0, 1.0)
			var res := clampf((f - 0.55) / 0.45, 0.0, 1.0)   # glyphs resolve into English
			UiKit.word(self, key, c + Vector2(0, -20), 64.0, Color(UiKit.GOLD, 1.0 - res), 3.0)
			if res > 0.0:
				var nm := Lexicon.readable_name(key)
				UiKit.text(self, nm, Vector2(0, c.y + 20 - (1.0 - res) * 10.0), 44, Color(UiKit.CREAM, res), size.x, HORIZONTAL_ALIGNMENT_CENTER)
				UiKit.text(self, key.get_slice(":", 0), Vector2(0, c.y + 58), 16, Color(UiKit.CYAN, 0.7 * res), size.x, HORIZONTAL_ALIGNMENT_CENTER)
			for i in 14:
				var an := TAU * i / 14.0 + _t
				var rr := 40.0 + f * 160.0
				draw_circle(c + Vector2.from_angle(an) * rr, 3.0 * (1.0 - f) + 1.0, Color(UiKit.TEAL, (1.0 - f) * 0.9))
	if _book:
		var p := Rect2(230, 112, 500, 400)
		UiKit.panel(self, p, UiKit.CYAN, 0.0, 0.98, 14)
		UiKit.text(self, "Notebook", Vector2(p.position.x, p.position.y + 38), 24, UiKit.GOLD, p.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		_rows.clear()
		for i in _unknown.size():
			var r := Rect2(p.position.x + 24, p.position.y + 56 + i * 50, p.size.x - 48, 44)
			_rows.append(r)
			var hot := 1.0 if _unknown[i] == _sel else 0.0
			UiKit.panel(self, r, UiKit.VIOLET, hot, 0.9, 8)
			UiKit.word(self, _unknown[i], Vector2(r.position.x + 70, r.get_center().y), 24.0, UiKit.CREAM, 2.0)
			var g := Lexicon.guess_of(_unknown[i])
			UiKit.text(self, g if g != "" else "?", Vector2(r.position.x + 190, r.get_center().y + 7), 19, Color(UiKit.GOLD, 0.8))
		if _unknown.is_empty():
			UiKit.text(self, "Nothing left unwritten.", Vector2(p.position.x, p.position.y + 200), 20, UiKit.CREAM, p.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		UiKit.text(self, _msg, Vector2(p.position.x, p.end.y - 14), 16, Color(UiKit.TEAL, 0.9), p.size.x, HORIZONTAL_ALIGNMENT_CENTER)
