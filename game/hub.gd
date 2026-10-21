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
