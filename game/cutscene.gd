class_name Cutscene
extends Node
## Code-built cinematic timeline. One parallel master Tween drives everything.
## Times: at() is ABSOLUTE from start. tween/shader/letterbox/shake/sound delays are
## relative to a cursor that wait(dur) advances (cursor is 0 until you call wait).
## play() is awaitable; 'finished' fires exactly once (end, skip, or owner freed).
## skip() fast-forwards via custom_step (never kill() while awaiting) and is idempotent.

signal finished
signal step(index: int)                 ## emitted once per at() call, in fire order
signal shake_changed(offset: Vector2)

var skippable := true
var owner_node: Node = null             ## optional; if freed mid-play the cutscene aborts cleanly
var shake_target: Node = null           ## optional Control/Node2D nudged by shake()
var letterbox_amount := 0.0: set = _set_letterbox
var shake_offset := Vector2.ZERO
var playing := false
var done := false

var _entries: Array = []                ## {t, dur, fn(Callable), kind, state}
var _cursor := 0.0
var _at_count := 0
var _tw: Tween
var _layer: CanvasLayer
var _bars: Array[ColorRect] = []
var _shake_base = null

func bind(node: Node) -> Cutscene:
	owner_node = node
	return self

## Total timeline length in seconds.
func duration() -> float:
	var d := _cursor
	for e in _entries:
		d = maxf(d, e.t + e.dur)
	return d

func at(t: float, c: Callable) -> Cutscene:
	var idx := _at_count
	_at_count += 1
	_entries.append({t = t, dur = 0.0, kind = "cb", state = {}, fn = func():
		step.emit(idx)
		if c.is_valid():
			c.call()})
	return self

func wait(dur: float) -> Cutscene:
	_cursor += dur
	return self

## Tween obj.prop (NodePath-style "modulate:a" allowed) to `to`. Start value is read when it begins.
func tween(obj: Object, prop: String, to: Variant, dur: float, delay := 0.0,
		trans := Tween.TRANS_SINE, ease_type := Tween.EASE_IN_OUT) -> Cutscene:
	return _track(delay, dur, trans, ease_type, to, obj, prop)

func shader(mat: ShaderMaterial, param: String, to: Variant, dur: float, delay := 0.0,
		trans := Tween.TRANS_SINE, ease_type := Tween.EASE_IN_OUT) -> Cutscene:
	return _track(delay, dur, trans, ease_type, to, mat, param)

func letterbox(show: bool, dur := 0.8, delay := 0.0) -> Cutscene:
	return tween(self, "letterbox_amount", 1.0 if show else 0.0, dur, delay)

func shake(amount: float, dur: float, delay := 0.0) -> Cutscene:
	_entries.append({t = _cursor + delay, dur = dur, kind = "m", state = {}, fn = func(w: float):
		if shake_target != null and not is_instance_valid(shake_target):
			shake_target = null
		if shake_target != null and _shake_base == null:
			_shake_base = shake_target.get("position")
		var k := (1.0 - w) * amount
		shake_offset = Vector2(randf_range(-k, k), randf_range(-k, k)) if w < 1.0 else Vector2.ZERO
		if shake_target != null and _shake_base != null:
			shake_target.set("position", _shake_base + shake_offset)
		if w >= 1.0:
			_shake_base = null
		shake_changed.emit(shake_offset)})
	return self

## Sound cue: calls Sfx.play(name) if a root node named Sfx with that method exists.
func sound(sfx_name: String, delay := 0.0) -> Cutscene:
	return at(_cursor + delay, func():
		var tree := get_tree()
		var sfx = tree.root.get_node_or_null("Sfx") if tree else null
		if sfx and sfx.has_method("play"):
			sfx.play(sfx_name))

func play() -> void:
	if playing or done:
		return
	playing = true
	var parent: Node = owner_node if is_instance_valid(owner_node) and owner_node.is_inside_tree() \
		else (Engine.get_main_loop() as SceneTree).root
	if not is_inside_tree():
		parent.add_child(self)
	tree_exiting.connect(_finish)
	if is_instance_valid(owner_node) and owner_node != self:
		owner_node.tree_exiting.connect(_finish, CONNECT_ONE_SHOT)
	_ensure_bars()
	_tw = create_tween().set_parallel(true)
	# chronological creation order so a skip (custom_step) fires cues in time order
	for i in _entries.size():
		_entries[i].i = i
	_entries.sort_custom(func(a, b): return a.t < b.t or (a.t == b.t and a.i < b.i))
	for e in _entries:
		e.state.clear()
		if e.kind == "cb":
			_tw.tween_callback(e.fn).set_delay(e.t)
		else:
			_tw.tween_method(e.fn, 0.0, 1.0, maxf(e.dur, 0.0001)).set_delay(e.t)
	_tw.tween_interval(maxf(duration(), 0.0001))
	_tw.finished.connect(_finish)
	set_process_unhandled_input(skippable)
	await finished

## Jump to the end state, exactly once.
func skip() -> void:
	if not playing or done:
		return
	if _tw and _tw.is_valid():
		_tw.custom_step(99999.0)
	_finish()

func _finish() -> void:
	if done:
		return
	done = true
	playing = false
	set_process_unhandled_input(false)
	if _tw and _tw.is_valid():
		_tw.kill()
	finished.emit()

func _unhandled_input(ev: InputEvent) -> void:
	if skippable and playing and ((ev is InputEventKey and ev.pressed and not ev.echo) \
			or (ev is InputEventMouseButton and ev.pressed)):
		skip()
		get_viewport().set_input_as_handled()

# --- internals -------------------------------------------------------------
func _track(delay: float, dur: float, trans: int, ease_type: int, to: Variant,
		obj: Object, prop: String) -> Cutscene:
	var st := {}
	var wr: WeakRef = weakref(obj)   # weakref: a freed target must not error or hang the timeline
	var is_mat := obj is ShaderMaterial
	_entries.append({t = _cursor + delay, dur = dur, kind = "m", state = st, fn = func(w: float):
		var o = wr.get_ref()
		if o == null:
			return
		if not st.has("from"):
			st.from = o.get_shader_parameter(prop) if is_mat else o.get_indexed(prop)
		var v: Variant = to if w >= 1.0 else Tween.interpolate_value(st.from, to - st.from, w, 1.0, trans, ease_type)
		if is_mat:
			o.set_shader_parameter(prop, v)
		else:
			o.set_indexed(prop, v)})
	return self

func _ensure_bars() -> void:
	if _layer:
		return
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	for i in 2:
		var r := ColorRect.new()
		r.color = Color.BLACK
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.visible = false
		_layer.add_child(r)
		_bars.append(r)

func _set_letterbox(v: float) -> void:
	letterbox_amount = v
	if _bars.is_empty() or not is_inside_tree():
		return
	var vs := get_viewport().get_visible_rect().size
	var h := vs.y * 0.12 * v
	_bars[0].position = Vector2.ZERO
	_bars[0].size = Vector2(vs.x, h)
	_bars[1].position = Vector2(0, vs.y - h)
	_bars[1].size = Vector2(vs.x, h)
	_bars[0].visible = h > 0.5
	_bars[1].visible = h > 0.5
