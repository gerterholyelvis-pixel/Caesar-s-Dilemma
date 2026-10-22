class_name IdleFlags
extends RefCounted
## Tiny persistent flag store shared by the idle game's one-time moments (cinematics, NPC visits).
## Stored as JSON in user://idle_flags.json; tests may point `path` somewhere else.

static var path := "user://idle_flags.json"
static var _cache: Dictionary = {}
static var _loaded_path := ""


static func _load() -> void:
	if _loaded_path == path:
		return
	_loaded_path = path
	_cache = {}
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_cache = d


static func get_flag(key: String, default = false):
	_load()
	return _cache.get(key, default)


static func set_flag(key: String, value = true) -> void:
	_load()
	_cache[key] = value
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_cache))
