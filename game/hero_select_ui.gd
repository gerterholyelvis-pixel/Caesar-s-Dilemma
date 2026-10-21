class_name HeroSelectUI
extends Control
## Choose hero + origin by glyph names. signal picked(hero_id, origin_id).

signal picked(hero_id: String, origin_id: String)

const HEROES := ["seshat", "thoth"]
const ORIGINS := ["eclipse", "mirror", "cathedral"]
const MOOD := {"eclipse": Color(0.55, 0.2, 0.9), "mirror": Color(0.4, 0.9, 1.0), "cathedral": Color(1.0, 0.8, 0.4)}

var hero := "seshat"
var origin := "eclipse"
var _t := 0.0
var _appear := 0.0
var _mood := Color(0.55, 0.2, 0.9)
var _hover := ""
var _go := 0.0
var _confirmed := false


func _ready() -> void:
	UiKit.fit_control(self)


func open() -> void:
	_appear = 0.0
	_confirmed = false
	_go = 0.0
	visible = true
	set_process(true)


func _hero_rect(i: int) -> Rect2:
	return Rect2(150 + i * 340, 90, 320, 250)


func _origin_rect(i: int) -> Rect2:
	return Rect2(150 + i * 220, 384, 200, 120)


func _begin_rect() -> Rect2:
	return Rect2(380, 546, 200, 50)


func choose(h: String, o: String) -> void:   # also the test hook
	if Meta.is_hero_unlocked(h):
		hero = h
	if Meta.is_origin_unlocked(o):
		origin = o


func confirm() -> void:
	if _confirmed:
		return
	_confirmed = true
	_go = 0.0
	Hub.sfx("ui_click")
	var h := hero
	var o := origin
	get_tree().create_timer(0.7).timeout.connect(func(): picked.emit(h, o))


func _process(dt: float) -> void:
	_t += dt
	_appear = minf(_appear + dt * 1.3, 1.0)
	_mood = _mood.lerp(MOOD.get(origin, _mood), minf(dt * 4.0, 1.0))
	if _confirmed:
		_go += dt
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		_hover = ""
		for i in 2:
			if _hero_rect(i).has_point(e.position):
				_hover = "h" + HEROES[i]
		for i in 3:
			if _origin_rect(i).has_point(e.position):
				_hover = "o" + ORIGINS[i]
		if _begin_rect().has_point(e.position):
			_hover = "go"
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for i in 2:
			if _hero_rect(i).has_point(e.position):
				choose(HEROES[i], origin)
		for i in 3:
			if _origin_rect(i).has_point(e.position):
				choose(hero, ORIGINS[i])
		if _begin_rect().has_point(e.position):
			confirm()


func _silhouette(h: String, c: Vector2, col: Color, locked: bool) -> void:
	var body := PackedVector2Array([c + Vector2(-46, 70), c + Vector2(-26, -10), c + Vector2(26, -10), c + Vector2(46, 70)])
	draw_colored_polygon(body, col)
	draw_circle(c + Vector2(0, -34), 24, col)
	if h == "thoth":   # ibis beak
		draw_colored_polygon(PackedVector2Array([c + Vector2(14, -42), c + Vector2(62, -28), c + Vector2(16, -26)]), col)
	else:              # seshat's star crown
		for k in 7:
			var an := -PI / 2 + (k - 3) * 0.32
			draw_line(c + Vector2(0, -50) + Vector2.from_angle(an) * 8, c + Vector2(0, -50) + Vector2.from_angle(an) * 24, col, 3.0)
	if locked:
		for k in 3:
			draw_arc(c + Vector2(0, 10), 70 + k * 10 + sin(_t + k) * 3, 0, TAU, 40, Color(UiKit.GOLD, 0.12), 1.0)


func _draw() -> void:
	var a := UiKit.ease_out(_appear)
	# mood-tinted backdrop preview
	draw_rect(Rect2(Vector2.ZERO, size), Color(_mood.r * 0.12, _mood.g * 0.12, _mood.b * 0.15, 0.78 * a))
	UiKit.glow(self, Vector2(480, 520), 420.0, Color(_mood, 0.35 * a))
	match origin:
		"eclipse":
			draw_circle(Vector2(480, 80), 60, Color(0, 0, 0, a))
			draw_arc(Vector2(480, 80), 62, 0, TAU, 64, Color(_mood, a), 3.0)
		"mirror":
			for k in 8:
				draw_line(Vector2(120 + k * 100, 0), Vector2(60 + k * 100, size.y), Color(_mood, 0.07 * a), 2.0)
		"cathedral":
			for k in 7:
				draw_rect(Rect2(60 + k * 130, 0, 6, size.y), Color(_mood, 0.08 * a))
	UiKit.text(self, "Who walks?", Vector2(0, 52), 30, Color(UiKit.CREAM, a), size.x, HORIZONTAL_ALIGNMENT_CENTER)
	for i in 2:
		var h: String = HEROES[i]
		var open_h := Meta.is_hero_unlocked(h)
		var r := _hero_rect(i)
		var sel := h == hero
		var hot := 1.0 if (sel or _hover == "h" + h) and open_h else 0.0
		UiKit.panel(self, r, _mood, hot, a)
		var c := r.get_center() + Vector2(0, -20 + sin(_t * 1.5 + i) * 3.0)
		if open_h:
			UiKit.glow(self, c, 100, Color(_mood, 0.4 * a * (0.5 + hot)))
			_silhouette(h, c, Color(0.02, 0.02, 0.04, 0.95).lerp(_mood, 0.18 + 0.2 * hot), false)
			UiKit.word(self, "hero:" + h, Vector2(r.get_center().x, r.end.y - 52), 30.0, Color(UiKit.CREAM, a), 2.0)
			var nm := Lexicon.display_name("hero:" + h)
			if nm != "":
				UiKit.text(self, nm, Vector2(r.position.x, r.end.y - 14), 18, Color(UiKit.GOLD, a), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			_silhouette(h, c, Color(0.07, 0.07, 0.1, 0.9), true)
			draw_rect(r.grow(-8), Color(0, 0, 0, 0.35))
			UiKit.text(self, "?", Vector2(r.position.x, r.end.y - 30), 40, Color(UiKit.GOLD, 0.5), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	for i in 3:
		var o: String = ORIGINS[i]
		var r := _origin_rect(i)
		var open_o := Meta.is_origin_unlocked(o)
		var hot := 1.0 if (o == origin or _hover == "o" + o) and open_o else 0.0
		UiKit.panel(self, r, MOOD[o], hot, a * (1.0 if open_o else 0.4), 12)
		UiKit.glow(self, r.get_center() + Vector2(0, -12), 46, Color(MOOD[o], 0.45 * a))
		UiKit.word(self, "origin:" + o, r.get_center() + Vector2(0, -8), 26.0, Color(UiKit.CREAM, a), 2.0)
		var nm := Lexicon.display_name("origin:" + o)
		if nm != "":
			UiKit.text(self, nm, Vector2(r.position.x, r.end.y - 14), 16, Color(UiKit.GOLD, a), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var br := _begin_rect()
	UiKit.panel(self, br, UiKit.GOLD, 1.0 if _hover == "go" else 0.0, a, 12)
	UiKit.text(self, "Descend", Vector2(br.position.x, br.position.y + 33), 22, UiKit.CREAM, br.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	if _confirmed:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, clampf(_go * 1.6, 0.0, 1.0)))
