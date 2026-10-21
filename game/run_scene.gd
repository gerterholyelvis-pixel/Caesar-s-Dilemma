extends Control
## The playable game scene: garden fly-through + title -> hero select -> Run on the locked garden -> end card -> Limbo.
## Debug entry (straight into a run on the locked world):
##   godot --path . res://run_scene.tscn -- --cam=1 [--hero=thoth --origin=mirror] [--seed=7] [--stay]
## --stay keeps the scene after the run ends instead of returning to Limbo.

signal run_ended(won: bool, depth: int)

var garden: Control = null
var run: Run = null
var _seed := -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Hub.boot()
	Hub.audio(get_tree())
	Hub.theme("garden")
	garden = (load("res://garden.tscn") as PackedScene).instantiate()
	add_child(garden)
	_seed = int(_arg("seed", "-1"))
	var locked := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cam="):
			locked = true
	if locked:
		_start.call_deferred()
	else:
		garden.connect("intro_finished", _start)


func _arg(arg_name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % arg_name):
			return a.substr(arg_name.length() + 3)
	return fallback


func _start() -> void:
	var hero := _arg("hero", "")
	var origin := _arg("origin", Hub.origin_hint if Hub.origin_hint != "" else "eclipse")
	if hero == "":
		var ui := HeroSelectUI.new()
		add_child(ui)
		ui.open()
		ui.choose("seshat", origin)
		ui.picked.connect(func(h: String, o: String) -> void:
			ui.queue_free()
			_begin(h, o))
		return
	_begin(hero, origin)


func _begin(hero: String, origin: String) -> void:
	run = Run.new()
	add_child(run)
	run.run_ended.connect(_finish)
	run.begin(hero, origin, _seed)


func _finish(won: bool, depth: int) -> void:
	run_ended.emit(won, depth)
	Hub.sfx("win" if won else "lose")
	Hub.theme("limbo")
	run.hide()
	var card := _EndCard.new()
	card.won = won
	card.depth = depth
	card.fresh = run.fresh_heroes.duplicate()
	card.hero = run.hero_id
	add_child(card)
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await card.dismissed
	if "--stay" in OS.get_cmdline_user_args():
		return
	get_tree().change_scene_to_file("res://limbo.tscn")


class _EndCard extends Control:
	signal dismissed
	var won := false
	var depth := 0
	var hero := "seshat"
	var fresh: Array = []
	var _t := 0.0
	var _out := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _process(dt: float) -> void:
		_t += dt
		if _t > 7.0 and not _out:
			_out = true
			dismissed.emit()
		queue_redraw()

	func _gui_input(ev: InputEvent) -> void:
		if _t > 1.6 and not _out and ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			_out = true
			dismissed.emit()

	func _draw() -> void:
		var s: Vector2 = size
		var k: float = UiKit.ease_out(_t / 1.6)
		var col: Color = UiKit.GOLD if won else UiKit.MAGENTA
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.01, 0.01, 0.03, 0.82 * k))
		var f: Font = UiKit.font()
		var cy: float = s.y * 0.42
		for i in 6:
			draw_circle(Vector2(s.x * 0.5, cy - 6.0), 120.0 - i * 18.0, Color(col.r, col.g, col.b, 0.025 * k))
		var line: String = "the garden exhales" if won else "the pack grows light"
		draw_string(f, Vector2(0, cy), line, HORIZONTAL_ALIGNMENT_CENTER, s.x, 40, Color(col, k))
		draw_string(f, Vector2(0, cy + 40.0), "%s  -  depth %d" % [hero.capitalize(), depth], HORIZONTAL_ALIGNMENT_CENTER, s.x, 18, Color(UiKit.TEAL, k))
		for i in fresh.size():
			draw_string(f, Vector2(0, cy + 76.0 + 26.0 * i), "%s wakes" % String(fresh[i]).capitalize(), HORIZONTAL_ALIGNMENT_CENTER, s.x, 20,
					Color(UiKit.CYAN, k * clampf(_t - 1.4, 0.0, 1.0)))
		if _t > 1.6:
			draw_string(f, Vector2(0, s.y - 40.0), "click to return to Limbo", HORIZONTAL_ALIGNMENT_CENTER, s.x, 14,
					Color(1, 1, 1, 0.35 + 0.2 * sin(_t * 3.0)))
