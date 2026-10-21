class_name Hub
extends RefCounted
## Cross-scene glue: profile boot (Meta + Lexicon + secret hook) and guarded audio (Sfx / Music are loaded by path,
## installed once under the SceneTree root so they survive scene changes, and silently absent when unavailable
## or when running headless). Every audio call is safe to make at any time.

static var booted := false
static var origin_hint := ""          # the answer given to the angel in Limbo (eclipse | mirror | cathedral)
static var enabled := true            # tests switch audio off
static var sfx_node: Node = null
static var music_node: Node = null
static var _pending_theme := ""
static var _installing := false
static var codex_layer: CanvasLayer = null


## Loads the profile once and wires Lexicon + secret discovery. Safe to call from every scene.
static func boot() -> void:
	if booted:
		return
	booted = true
	if Meta.lexicon_seed == 0:
		Meta.load()
	Lexicon.init(Meta.lexicon_seed, Meta.known_words)
	Meta.on_secret_discovered = ItemDB.mark_discovered
	ItemDB.discovered_check = Meta.is_secret_discovered


## Installs Sfx + Music under the tree root on the next frame (never inside a busy _ready).
static func audio(tree: SceneTree) -> void:
	install_codex(tree)
	if not enabled or _installing or tree == null:
		return
	if DisplayServer.get_name() == "headless":
		enabled = false
		return
	if sfx_node != null and is_instance_valid(sfx_node) and music_node != null and is_instance_valid(music_node):
		return
	_installing = true
	tree.process_frame.connect(func() -> void: _install(tree), CONNECT_ONE_SHOT)


static func _install(tree: SceneTree) -> void:
	_installing = false
	boot()
	if sfx_node == null or not is_instance_valid(sfx_node):
		sfx_node = _make("res://game/sfx.gd", tree)
	if music_node == null or not is_instance_valid(music_node):
		music_node = _make("res://game/music.gd", tree)
		if music_node != null and _pending_theme != "":
			music_node.call("set_theme", _pending_theme)


static func _make(path: String, tree: SceneTree) -> Node:
	if not ResourceLoader.exists(path):
		return null
	var s: Variant = load(path)
	if s == null or not (s is GDScript) or not (s as GDScript).can_instantiate() or not (s as GDScript).has_method("install"):
		return null
	var n: Variant = (s as GDScript).call("install", tree.root, Meta.lexicon_seed)
	return n if n is Node else null


static func theme(theme_name: String) -> void:
	_pending_theme = theme_name
	if music_node != null and is_instance_valid(music_node) and music_node.has_method("set_theme"):
		music_node.call("set_theme", theme_name)


static func tension(v: float) -> void:
	if music_node != null and is_instance_valid(music_node) and music_node.has_method("set_tension"):
		music_node.call("set_tension", v)


static func sfx(sfx_name: String) -> void:
	if sfx_node != null and is_instance_valid(sfx_node) and sfx_node.has_method("play"):
		sfx_node.call("play", sfx_name)


static func item(item_id: String) -> void:
	if sfx_node != null and is_instance_valid(sfx_node) and sfx_node.has_method("play_item"):
		sfx_node.call("play_item", item_id)


static func synergy(count: int) -> void:
	if sfx_node != null and is_instance_valid(sfx_node) and sfx_node.has_method("play_synergy"):
		sfx_node.call("play_synergy", count)


## The notebook: a CanvasLayer under the root with a small glowing book icon (top-right) and the C hotkey.
static func install_codex(tree: SceneTree) -> void:
	if tree == null or (codex_layer != null and is_instance_valid(codex_layer)):
		return
	codex_layer = _CodexLayer.new()
	codex_layer.name = "CodexLayer"
	tree.root.add_child.call_deferred(codex_layer)


static func toggle_codex() -> void:
	if codex_layer != null and is_instance_valid(codex_layer):
		(codex_layer as _CodexLayer).toggle()


static func codex_open() -> bool:
	return codex_layer != null and is_instance_valid(codex_layer) and (codex_layer as _CodexLayer).ui != null and (codex_layer as _CodexLayer).ui.is_open


class _CodexLayer extends CanvasLayer:
	var ui: CodexUI
	var book: _Book

	func _ready() -> void:
		layer = 90
		process_mode = Node.PROCESS_MODE_ALWAYS
		ui = CodexUI.new()
		add_child(ui)
		book = _Book.new()
		book.pressed_cb = toggle
		add_child(book)

	func toggle() -> void:
		if ui.is_open:
			ui.close()
		else:
			ui.open()

	func _input(ev: InputEvent) -> void:
		if ev is InputEventKey and ev.pressed and not ev.echo and (ev as InputEventKey).keycode == KEY_C and not ui.is_open:
			var f: Control = get_viewport().gui_get_focus_owner()
			if f is LineEdit or f is TextEdit:
				return
			toggle()
			get_viewport().set_input_as_handled()


class _Book extends Control:
	var pressed_cb: Callable
	var t := 0.0
	var hot := false

	func _ready() -> void:
		size = Vector2(46, 46)
		position = Vector2(get_viewport_rect().size.x - 60, 12)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func() -> void: hot = true)
		mouse_exited.connect(func() -> void: hot = false)
		tooltip_text = "Codex (C)"

	func _process(dt: float) -> void:
		t += dt
		position.x = get_viewport_rect().size.x - 60
		queue_redraw()

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if pressed_cb.is_valid():
				pressed_cb.call()
			accept_event()

	func _draw() -> void:
		var c := size * 0.5
		var pulse := 0.5 + 0.5 * sin(t * 1.7)
		UiKit.glow(self, c, 30.0 + 6.0 * pulse + (8.0 if hot else 0.0), Color(UiKit.VIOLET, 0.45))
		draw_circle(c, 20.0, Color(0.03, 0.03, 0.05, 0.9))
		draw_arc(c, 20.0, 0, TAU, 32, Color(UiKit.GOLD, 0.6 + 0.3 * pulse), 2.0)
		var col := Color(UiKit.GOLD, 0.95)
		draw_polyline(PackedVector2Array([c + Vector2(0, -9), c + Vector2(-11, -6), c + Vector2(-11, 9), c + Vector2(0, 12)]), col, 1.8)
		draw_polyline(PackedVector2Array([c + Vector2(0, -9), c + Vector2(11, -6), c + Vector2(11, 9), c + Vector2(0, 12)]), col, 1.8)
		draw_line(c + Vector2(0, -9), c + Vector2(0, 12), col, 1.5)
		draw_circle(c + Vector2(-5.5, 0), 2.0, Color(UiKit.CYAN, 0.6 + 0.4 * pulse))
		draw_circle(c + Vector2(5.5, 0), 2.0, Color(UiKit.CYAN, 1.0 - 0.4 * pulse))
