class_name TabRail
extends Control
## Clicker-Heroes-style slim icon rail (far left). Tabs come from Content.TABS; a tab is shown once its unlock id is set
## (Garden is always there). New tabs glow in. Later tabs (Research, Heroes, ...) need only a rule in Content.UNLOCKS.

signal tab_selected(id: String)

const GOLD := Color(0.93, 0.80, 0.52)
const TEAL := Color(0.15, 0.85, 0.75)
const VIOLET := Color(0.66, 0.38, 1.0)
const CYAN := Color(0.45, 0.95, 1.0)
const CELL := 46.0
const GAP := 10.0

var current := "garden"
var shown: Array[String] = []              # tab ids in rail order
var appear := {}                           # id -> 0..1 glow-in progress
var fresh := {}                            # id -> true until visited
var badges := {}                           # id -> count
var t := 0.0
var _hover := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(CELL, CELL)


## Shows every tab whose unlock id is set; returns the ids that appeared now. `animate` false = silent (load).
func refresh(unlocked: Dictionary, animate: bool) -> Array[String]:
	var added: Array[String] = []
	for d in Content.TABS:
		var id: String = d["id"]
		if id in shown:
			continue
		if d["unlock"] == "" or bool(unlocked.get(d["unlock"], false)):
			shown.append(id)
			appear[id] = 0.0 if animate and id != "garden" else 1.0
			if animate and id != "garden":
				fresh[id] = true
				added.append(id)
	size = Vector2(CELL, shown.size() * (CELL + GAP))
	return added


func slot_center(id: String) -> Vector2:
	var i := shown.find(id)
	return position + Vector2(CELL * 0.5, i * (CELL + GAP) + CELL * 0.5)


func select(id: String) -> void:
	if id == current or not (id in shown):
		return
	current = id
	fresh.erase(id)
	tab_selected.emit(id)


func _process(dt: float) -> void:
	t += dt
	for id in appear:
		appear[id] = minf(1.0, appear[id] + dt / 1.3)
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	var i := -1
	var hit := false
	if ev is InputEventMouse:
		i = int((ev as InputEventMouse).position.y / (CELL + GAP))
		hit = i >= 0 and i < shown.size() and fmod((ev as InputEventMouse).position.y, CELL + GAP) < CELL
	if ev is InputEventMouseMotion:
		_hover = shown[i] if hit else ""
		tooltip_text = String(Content.TABS[_tab_index(shown[i])]["name"]) if hit else ""
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and hit:
		select(shown[i])
		accept_event()


func _tab_index(id: String) -> int:
	for k in Content.TABS.size():
		if Content.TABS[k]["id"] == id:
			return k
	return 0


func _draw() -> void:
	for i in shown.size():
		var id := shown[i]
		var a: float = ease_out(appear[id])
		var c := Vector2(CELL * 0.5, i * (CELL + GAP) + CELL * 0.5)
		var sel := id == current
		var hot := id == _hover
		var pulse := 0.5 + 0.5 * sin(t * 3.0)
		var glow := (1.0 - a) * 1.5 + (0.5 * pulse if fresh.has(id) else 0.0) + (0.35 if sel else 0.0) + (0.2 if hot else 0.0)
		var sc := 0.6 + 0.4 * a
		for k in 6:
			var f := float(k) / 6.0
			draw_circle(c, CELL * 0.85 * (1.0 - f * 0.7) * sc, Color(TEAL.lerp(VIOLET, f), (0.03 + 0.03 * f) * glow))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.03, 0.03, 0.05, 0.88 * a)
		sb.border_color = Color(GOLD, (0.95 if sel else 0.5) * a)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(14)
		sb.shadow_color = Color(TEAL if sel else VIOLET, 0.3 * a * (1.0 if sel or fresh.has(id) else 0.4))
		sb.shadow_size = 10 if sel else 4
		var h := CELL * sc
		draw_style_box(sb, Rect2(c - Vector2(h, h) * 0.5, Vector2(h, h)))
		_icon(id, c, CELL * 0.30 * sc, Color(GOLD, a * (1.0 if sel or hot else 0.8)))
		var b: int = badges.get(id, 0)
		if b > 0 and not sel:
			draw_circle(c + Vector2(15, -15), 7.0, Color(0.1, 0.07, 0.02, 0.95))
			draw_circle(c + Vector2(15, -15), 5.5, Color(GOLD, 0.7 + 0.3 * pulse))


static func ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)


func _icon(id: String, c: Vector2, r: float, col: Color) -> void:
	match id:
		"garden":
			draw_polyline(PackedVector2Array([c + Vector2(0, r), c + Vector2(0, -r * 0.2)]), col, 2.0, true)
			draw_polyline(PackedVector2Array([c + Vector2(0, -r * 0.1), c + Vector2(-r * 0.9, -r * 0.7), c + Vector2(-r * 0.2, -r * 0.1)]), Color(TEAL, col.a), 2.0, true)
			draw_polyline(PackedVector2Array([c + Vector2(0, -r * 0.3), c + Vector2(r * 0.9, -r * 0.9), c + Vector2(r * 0.2, -r * 0.2)]), Color(CYAN, col.a), 2.0, true)
		"upgrades":
			for k in 2:
				var y := r * 0.5 - k * r * 0.8
				draw_polyline(PackedVector2Array([c + Vector2(-r * 0.8, y), c + Vector2(0, y - r * 0.7), c + Vector2(r * 0.8, y)]), col, 2.2, true)
		_:
			draw_arc(c, r * 0.8, 0, TAU, 20, col, 2.0, true)
			draw_circle(c, r * 0.25, Color(CYAN, col.a))


## One flourish at a time: a glyph word fades in over the new tab / feature, then resolves into its readable name.
class Flourish extends Control:
	const GOLD := Color(0.93, 0.80, 0.52)
	const CYAN := Color(0.45, 0.95, 1.0)
	const TEAL := Color(0.15, 0.85, 0.75)
	var queue: Array = []
	var cur: Dictionary = {}
	var age := 0.0
	var font: Font

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func play(key: String, title: String, at: Vector2) -> void:
		queue.append({"key": key, "title": title, "at": at})

	func _process(dt: float) -> void:
		if cur.is_empty():
			if queue.is_empty():
				return
			cur = queue.pop_front()
			age = 0.0
		age += dt
		if age > 1.7 and cur.get("learned", false) == false:
			cur["learned"] = true
			Lexicon.learn(cur["key"])
		if age > 4.0:
			cur = {}
		queue_redraw()

	func _draw() -> void:
		if cur.is_empty():
			return
		var word: Array[int] = Lexicon.word_for(cur["key"])
		var at: Vector2 = cur["at"]
		var a_in := clampf(age / 0.7, 0.0, 1.0)
		var a_out := clampf((4.0 - age) / 0.8, 0.0, 1.0)
		var res := clampf((age - 1.5) / 0.9, 0.0, 1.0)                 # 0 glyphs ... 1 name
		var gl := a_in * (1.0 - res) * a_out
		var sz := 54.0
		var n := word.size()
		var x0 := at.x - (n - 1) * sz * 0.55
		for i in n:
			var p := Vector2(x0 + i * sz * 1.1, at.y)
			for k in 5:
				draw_circle(p, sz * (0.9 - k * 0.13), Color(TEAL, 0.03 * gl * (1.0 + k * 0.5)))
			GlyphGen.draw(self, word[i], p, sz * (0.8 + 0.2 * a_in), Color(1.0, 0.92, 0.65, gl), 2.4)
		if res > 0.0 and font != null:
			var al := res * a_out
			draw_string_outline(font, at + Vector2(-200, 8), cur["title"], HORIZONTAL_ALIGNMENT_CENTER, 400.0, 34, 6, Color(0.02, 0.02, 0.05, al * 0.8))
			draw_string(font, at + Vector2(-200, 8), cur["title"], HORIZONTAL_ALIGNMENT_CENTER, 400.0, 34, Color(GOLD, al))
