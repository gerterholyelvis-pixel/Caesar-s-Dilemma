class_name OracleHorn
extends Node3D
# The Horn of the Antechamber: a verdigris bronze speaking-horn on a glyph-carved pedestal.
# Origin at floor level, mouth faces +Z. Speaks via subtitles (CanvasLayer 20) + synthesised voice.
#   interact()            player pressed E (idle -> speaks next group; speaking -> nothing)
#   say(lines)            awaitable; items are String or {text, hold, id}
#   speak_group(i)        awaitable; speak HornScript group i (4 = rebuke, does not advance)
#   speaking              true while a queue is running
#   get_focus_point()     global point on the mouth
#   signal spoke(line_id) after each line is finished

const Voice := preload("res://act1/horn_voice.gd")
const Script_ := preload("res://act1/horn_script.gd")

signal spoke(line_id: String)
signal _batch_done

var speaking: bool = false
var auto_intro: bool = true
var audio_enabled: bool = true
var debug_time_scale: float = 1.0
var prompt_text: String = "Listen"

const GOLD := Color(0.93, 0.80, 0.52)
const IVORY := Color(0.95, 0.90, 0.78)
const MOUTH_T := 1.0

var _spine: PackedVector3Array = PackedVector3Array()
var _mouth_pos := Vector3.ZERO
var _mouth_dir := Vector3.FORWARD

var _inner_mat: StandardMaterial3D
var _core_mat: StandardMaterial3D
var _glyph_mat: StandardMaterial3D
var _light: OmniLight3D
var _particles: GPUParticles3D
var _players: Array = []
var _player_i := 0
var _clock := 0.0
var _level := 0.0
var _env: PackedFloat32Array = PackedFloat32Array()
var _line_active := false
var _line_t := 0.0
var _plan: Dictionary = {}
var _text_len := 0

# queue
var _queue: Array = []
var _runner_on := false
var _batch_counter := 0
var _batches_done := 0
var _next_group := 0
var _intro_started := false

# subtitles
var _layer: CanvasLayer
var _panel: PanelContainer
var _label: Label
var _ui_alpha := 0.0
var _ui_target := 0.0

# voice thread
var _thread: Thread
var _sem := Semaphore.new()
var _mutex := Mutex.new()
var _pending: Array = []
var _cache: Dictionary = {}
var _quit := false

# ---------------------------------------------------------------------------------------------
func _ready() -> void:
	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	if args.has("--noaudio"):
		audio_enabled = false
	add_to_group("oracle_horn")
	_build_all()
	_build_ui()
	if audio_enabled:
		_thread = Thread.new()
		_thread.start(_worker)
		for g in Script_.GROUPS:
			for line in g:
				_request(line, false)
		_auto_intro()

func _exit_tree() -> void:
	_quit = true
	if _thread:
		_sem.post()
		_thread.wait_to_finish()
		_thread = null

# ---------------------------------------------------------------------------------------------
# Public API
func interact() -> void:
	if speaking:
		return
	speak_group(_next_group)

func speak_group(group: int) -> void:
	if group == 0:
		_intro_started = true
	if group != 4:
		_next_group = group + 1
		if _next_group > 3:
			_next_group = 1
	await say(Script_.lines_for(group))

func say(lines: Array) -> void:
	_batch_counter += 1
	var my_id := _batch_counter
	var n := 0
	for it in lines:
		var e: Dictionary
		if it is Dictionary:
			e = (it as Dictionary).duplicate()
		else:
			e = {"text": str(it)}
		if not e.has("hold"):
			e["hold"] = 0.7
		if not e.has("id"):
			e["id"] = "say_%d_%d" % [my_id, n]
		e["batch"] = my_id
		e["last"] = false
		_queue.append(e)
		n += 1
	if n == 0:
		return
	_queue[_queue.size() - 1]["last"] = true
	speaking = true
	if not _runner_on:
		_run_queue()
	while _batches_done < my_id:
		await _batch_done

func get_focus_point() -> Vector3:
	return to_global(_mouth_pos + _mouth_dir * 0.04)

# ---------------------------------------------------------------------------------------------
func _auto_intro() -> void:
	await get_tree().create_timer(6.0).timeout
	while is_inside_tree() and not _intro_started:
		var cam := get_viewport().get_camera_3d()
		if cam and cam.global_position.distance_to(global_position) <= 6.0:
			speak_group(0)
			return
		await get_tree().create_timer(1.0).timeout

func _run_queue() -> void:
	_runner_on = true
	while _queue.size() > 0:
		var e: Dictionary = _queue.pop_front()
		await _speak_line(e)
		if e["last"]:
			_batches_done = e["batch"]
			_batch_done.emit()
	_runner_on = false
	speaking = false
	_ui_target = 0.0

func _speak_line(e: Dictionary) -> void:
	var text: String = e["text"]
	var baked: Dictionary = {}
	if audio_enabled:
		baked = await _get_baked(text)
	if not is_inside_tree():
		return
	if baked.is_empty():
		_plan = Voice.plan(text)
		_env = Voice.envelope(_plan)
	else:
		_plan = baked["plan"]
		_env = baked["env"]
		var pl: AudioStreamPlayer3D = _players[_player_i]
		_player_i = (_player_i + 1) % _players.size()
		pl.stream = baked["stream"]
		pl.play()
	_label.text = text
	_text_len = text.length()
	_label.visible_characters = 0
	_line_t = 0.0
	_line_active = true
	_ui_target = 1.0
	var dur: float = _plan["dur"]
	while _line_t < dur and is_inside_tree():
		await get_tree().process_frame
	_line_active = false
	_label.visible_characters = -1
	spoke.emit(e["id"])
	var hold: float = e["hold"]
	var waited := 0.0
	while waited < hold and is_inside_tree():
		await get_tree().process_frame
		waited += get_process_delta_time() * debug_time_scale

# ---------------------------------------------------------------------------------------------
# voice cache / thread
func _cache_get(text: String) -> Dictionary:
	_mutex.lock()
	var d: Dictionary = _cache.get(text, {})
	_mutex.unlock()
	return d

func _request(text: String, urgent: bool) -> void:
	_mutex.lock()
	if not _cache.has(text):
		var i := _pending.find(text)
		if i >= 0:
			if urgent and i > 0:
				_pending.remove_at(i)
				_pending.push_front(text)
		else:
			if urgent:
				_pending.push_front(text)
			else:
				_pending.push_back(text)
			_sem.post()
	_mutex.unlock()

func _get_baked(text: String) -> Dictionary:
	var d := _cache_get(text)
	if not d.is_empty():
		return d
	_request(text, true)
	var waited := 0.0
	while d.is_empty() and waited < 25.0 and is_inside_tree():
		await get_tree().process_frame
		waited += get_process_delta_time()
		d = _cache_get(text)
	return d

func _worker() -> void:
	while true:
		_sem.wait()
		if _quit:
			return
		var text := ""
		_mutex.lock()
		if _pending.size() > 0:
			text = _pending[0]
		_mutex.unlock()
		if text == "":
			continue
		var d: Dictionary = Voice.bake(text)
		_mutex.lock()
		_cache[text] = d
		_pending.erase(text)
		_mutex.unlock()

# ---------------------------------------------------------------------------------------------
func _process(delta: float) -> void:
	delta *= debug_time_scale
	_clock += delta
	var target := 0.0
	if _line_active:
		_line_t += delta
		_label.visible_characters = Voice.chars_at(_plan, _line_t, _text_len)
		var i := int(_line_t * Voice.ENV_RATE)
		if i >= 0 and i < _env.size():
			target = _env[i]
	_level = lerpf(_level, target, clampf(delta * (22.0 if target > _level else 8.0), 0.0, 1.0))
	# visuals
	var breath := 0.5 + 0.5 * sin(_clock * 1.1)
	var flick := sin(_clock * 7.3) * sin(_clock * 3.1) * 0.5 + randf() * 0.25
	_inner_mat.emission_energy_multiplier = 0.7 + 0.3 * breath + _level * 2.2
	_core_mat.emission_energy_multiplier = 0.9 + 0.5 * breath + _level * 2.2
	_glyph_mat.emission_energy_multiplier = 0.6 + 0.3 * breath + _level * 2.0
	_light.light_energy = 0.28 + 0.07 * flick + 0.06 * breath + _level * (0.8 + randf() * 0.4)
	_particles.amount_ratio = 0.3 + 0.7 * clampf(_level * 1.6 + (0.5 if speaking else 0.0), 0.0, 1.0)
	# subtitle fade
	_ui_alpha = move_toward(_ui_alpha, _ui_target, delta * 3.5)
	_panel.modulate.a = _ui_alpha
	_layer.visible = _ui_alpha > 0.005

# ---------------------------------------------------------------------------------------------
# Subtitles
func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 20
	_layer.visible = false
	add_child(_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.anchor_left = 0.14
	_panel.anchor_right = 0.86
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_top = -136
	_panel.offset_bottom = -28
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.022, 0.035, 0.80)
	sb.border_color = Color(GOLD, 0.62)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 14
	_panel.add_theme_stylebox_override("panel", sb)
	root.add_child(_panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)
	var tag := Label.new()
	tag.text = "T H E   H O R N"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", Color(GOLD, 0.65))
	box.add_child(tag)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label.add_theme_font_size_override("font_size", 23)
	_label.add_theme_color_override("font_color", IVORY)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("outline_size", 3)
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Palatino Linotype", "Book Antiqua", "Georgia", "Garamond", "Times New Roman", "serif"])
	f.font_italic = true
	_label.add_theme_font_override("font", f)
	box.add_child(_label)
	_panel.modulate.a = 0.0

# ---------------------------------------------------------------------------------------------
# Geometry helpers
func _bez(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return p0 * (u * u * u) + p1 * (3.0 * u * u * t) + p2 * (3.0 * u * t * t) + p3 * (t * t * t)

func _ring(c: Vector3, n: Vector3, b: Vector3, rad: float, segs: int) -> PackedVector3Array:
	var r := PackedVector3Array()
	r.resize(segs)
	for i in segs:
		var a := TAU * float(i) / float(segs)
		r[i] = c + (n * cos(a) + b * sin(a)) * rad
	return r

# rows: Array[PackedVector3Array] all same size (ring, wraps). flip picks the normal handedness.
func _grid_mesh(rows: Array, uv_scale: Vector2, flip: bool, v_bias := 0.0) -> ArrayMesh:
	var R := rows.size()
	var C: int = rows[0].size()
	var vcum: Array = [0.0]
	for r in range(1, R):
		var d := 0.0
		for c in C:
			d += (rows[r][c] - rows[r - 1][c]).length()
		vcum.append(vcum[r - 1] + d / float(C))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var norms: Array = []
	for r in R:
		for c in C + 1:
			var cc := c % C
			var p: Vector3 = rows[r][cc]
			var du: Vector3 = rows[r][(cc + 1) % C] - rows[r][(cc - 1 + C) % C]
			var dv: Vector3 = rows[mini(r + 1, R - 1)][cc] - rows[maxi(r - 1, 0)][cc]
			var n := du.cross(dv) if flip else dv.cross(du)
			if n.length() < 1e-9:
				n = Vector3.UP
			n = n.normalized()
			norms.append(n)
			st.set_normal(n)
			st.set_uv(Vector2(float(c) / float(C) * uv_scale.x, (vcum[r] + v_bias) * uv_scale.y))
			st.add_vertex(p)
	var W := C + 1
	for r in R - 1:
		for c in C:
			var a := r * W + c
			var b := (r + 1) * W + c
			var cI := r * W + c + 1
			var d2 := (r + 1) * W + c + 1
			_tri(st, norms, rows, a, b, cI, W, C)
			_tri(st, norms, rows, cI, b, d2, W, C)
	st.generate_tangents()
	return st.commit()

func _vpos(rows: Array, i: int, W: int, C: int) -> Vector3:
	return rows[i / W][(i % W) % C]

func _tri(st: SurfaceTool, norms: Array, rows: Array, i0: int, i1: int, i2: int, W: int, C: int) -> void:
	var p0 := _vpos(rows, i0, W, C)
	var p1 := _vpos(rows, i1, W, C)
	var p2 := _vpos(rows, i2, W, C)
	var g := (p1 - p0).cross(p2 - p0)
	var n: Vector3 = norms[i0] + norms[i1] + norms[i2]
	if g.dot(n) < 0.0:
		st.add_index(i0)
		st.add_index(i1)
		st.add_index(i2)
	else:
		st.add_index(i0)
		st.add_index(i2)
		st.add_index(i1)

func _lathe(profile: Array, segs: int, uv_scale: Vector2) -> ArrayMesh:
	var rows: Array = []
	for pt in profile:
		var v: Vector2 = pt
		var row := PackedVector3Array()
		row.resize(segs)
		for i in segs:
			var a := TAU * float(i) / float(segs)
			row[i] = Vector3(cos(a) * maxf(v.x, 0.0005), v.y, sin(a) * maxf(v.x, 0.0005))
		rows.append(row)
	return _grid_mesh(rows, uv_scale, false)

# tube along a point list with frames (parallel transport); returns rows
func _tube_rows(pts: PackedVector3Array, radii: PackedFloat32Array, segs: int) -> Array:
	var rows: Array = []
	var n_prev := Vector3.ZERO
	for i in pts.size():
		var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		if i == 0:
			n_prev = (Vector3.RIGHT - t * Vector3.RIGHT.dot(t))
			if n_prev.length() < 0.1:
				n_prev = Vector3.UP - t * Vector3.UP.dot(t)
		var n := (n_prev - t * n_prev.dot(t)).normalized()
		n_prev = n
		var b := t.cross(n)
		rows.append(_ring(pts[i], n, b, radii[i], segs))
	return rows

func _torus(center: Vector3, axis: Vector3, major: float, minor: float, segs := 28, rsegs := 8) -> ArrayMesh:
	var n := (Vector3.RIGHT - axis * Vector3.RIGHT.dot(axis))
	if n.length() < 0.1:
		n = Vector3.UP - axis * Vector3.UP.dot(axis)
	n = n.normalized()
	var b := axis.cross(n)
	var rows: Array = []
	for k in rsegs + 1:
		var ph := TAU * float(k) / float(rsegs)
		rows.append(_ring(center + axis * (sin(ph) * minor), n, b, major + cos(ph) * minor, segs))
	return _grid_mesh(rows, Vector2(1, 1), true)

func _mi(mesh: Mesh, mat: Material, parent: Node3D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	parent.add_child(m)
	return m

# ---------------------------------------------------------------------------------------------
# Textures
func _line_px(img: Image, x0: float, y0: float, x1: float, y1: float, col: Color, rad: int) -> void:
	var W := img.get_width()
	var H := img.get_height()
	var d := maxf(absf(x1 - x0), absf(y1 - y0))
	var steps := maxi(int(d), 1)
	for s in steps + 1:
		var t := float(s) / float(steps)
		var cx := int(lerpf(x0, x1, t))
		var cy := int(lerpf(y0, y1, t))
		for ox in range(-rad, rad + 1):
			for oy in range(-rad, rad + 1):
				if ox * ox + oy * oy <= rad * rad:
					img.set_pixel(posmod(cx + ox, W), clampi(cy + oy, 0, H - 1), col)

func _noise(seed_v: int, freq: float, oct: int) -> Image:
	var nz := FastNoiseLite.new()
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.seed = seed_v
	nz.frequency = freq
	nz.fractal_type = FastNoiseLite.FRACTAL_FBM
	nz.fractal_octaves = oct
	return nz.get_seamless_image(256, 256)

func _finish(img: Image) -> ImageTexture:
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _bronze_material() -> StandardMaterial3D:
	const S := 256
	var hn := _noise(11, 0.025, 4)
	var pn := _noise(23, 0.012, 3)
	var sn := _noise(37, 0.05, 2)
	var alb := Image.create(S, S, false, Image.FORMAT_RGB8)
	var rgh := Image.create(S, S, false, Image.FORMAT_RGB8)
	var met := Image.create(S, S, false, Image.FORMAT_RGB8)
	var hgt := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for y in S:
		for x in S:
			var h := hn.get_pixel(x, y).r
			var pa := pn.get_pixel(x, y).r
			var st := sn.get_pixel(x, (y / 7) % S).r
			var pv := pa + (st - 0.5) * 0.7 + (h - 0.5) * 0.3
			var patina := smoothstep(0.57, 0.72, pv)
			var base := Color(0.26, 0.16, 0.07).lerp(Color(0.66, 0.46, 0.2), smoothstep(0.3, 0.75, h))
			var verd := Color(0.09, 0.30, 0.26).lerp(Color(0.26, 0.62, 0.52), smoothstep(0.3, 0.8, h))
			alb.set_pixel(x, y, base.lerp(verd, patina))
			var rv := lerpf(0.30 + 0.35 * (1.0 - h), 0.82, patina)
			rgh.set_pixel(x, y, Color(rv, rv, rv))
			var mv := lerpf(0.95, 0.3, patina)
			met.set_pixel(x, y, Color(mv, mv, mv))
			var hv := h * 0.5 + patina * 0.45
			hgt.set_pixel(x, y, Color(hv, hv, hv))
	for k in 90:
		var x0 := rng.randf() * S
		var y0 := rng.randf() * S
		var a := rng.randf() * TAU
		var l := 8.0 + rng.randf() * 36.0
		_line_px(alb, x0, y0, x0 + cos(a) * l, y0 + sin(a) * l, Color(0.75, 0.55, 0.3), 0)
		_line_px(rgh, x0, y0, x0 + cos(a) * l, y0 + sin(a) * l, Color(0.18, 0.18, 0.18), 0)
		_line_px(hgt, x0, y0, x0 + cos(a) * l, y0 + sin(a) * l, Color(0.0, 0.0, 0.0), 0)
	hgt.bump_map_to_normal_map(5.0)
	var m := StandardMaterial3D.new()
	m.albedo_texture = _finish(alb)
	m.roughness_texture = _finish(rgh)
	m.metallic_texture = _finish(met)
	m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.metallic = 1.0
	m.roughness = 1.0
	m.normal_enabled = true
	m.normal_texture = _finish(hgt)
	m.normal_scale = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _stone_material(tri: bool) -> StandardMaterial3D:
	const S := 256
	var hn := _noise(71, 0.03, 5)
	var cn := _noise(83, 0.02, 3)
	var alb := Image.create(S, S, false, Image.FORMAT_RGB8)
	var hgt := Image.create(S, S, false, Image.FORMAT_RGBA8)
	for y in S:
		for x in S:
			var h := hn.get_pixel(x, y).r
			var c := absf(cn.get_pixel(x, y).r - 0.5)
			var crack := 1.0 - smoothstep(0.0, 0.025, c)
			var col := Color(0.14, 0.14, 0.145).lerp(Color(0.33, 0.32, 0.31), smoothstep(0.25, 0.8, h))
			col = col.lerp(Color(0.04, 0.035, 0.035), crack * 0.8)
			alb.set_pixel(x, y, col)
			var hv := h * 0.7 - crack * 0.5 + 0.3
			hgt.set_pixel(x, y, Color(hv, hv, hv))
	hgt.bump_map_to_normal_map(7.0)
	var m := StandardMaterial3D.new()
	m.albedo_texture = _finish(alb)
	m.normal_enabled = true
	m.normal_texture = _finish(hgt)
	m.roughness = 0.9
	m.metallic_specular = 0.3
	if tri:
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(1.6, 1.6, 1.6)
	return m

func _glyph_material() -> StandardMaterial3D:
	var W := 1280
	var H := 128
	var hgt := Image.create(W, H, false, Image.FORMAT_RGBA8)
	hgt.fill(Color(0.8, 0.8, 0.8))
	var emi := Image.create(W, H, false, Image.FORMAT_RGB8)
	emi.fill(Color.BLACK)
	var dark := Color(0.0, 0.0, 0.0)
	var gold := Color(0.95, 0.68, 0.28)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	# frame bands
	for yb in [10, 118]:
		_line_px(hgt, 0, yb, W, yb, dark, 2)
		_line_px(emi, 0, yb, W, yb, gold * 0.5, 1)
	var cells := 16
	var cw := float(W) / cells
	for ci in cells:
		var cx := cw * (ci + 0.5)
		var cy := H * 0.5
		var kind := rng.randi() % 6
		var s := 30.0
		var strokes: Array = []
		match kind:
			0: strokes = [[cx, cy - s, cx, cy + s], [cx - s * 0.6, cy - s * 0.3, cx + s * 0.6, cy - s * 0.3]]
			1: strokes = [[cx - s * 0.7, cy + s, cx, cy - s], [cx, cy - s, cx + s * 0.7, cy + s], [cx - s * 0.35, cy + s * 0.2, cx + s * 0.35, cy + s * 0.2]]
			2: strokes = [[cx - s * 0.6, cy - s, cx + s * 0.6, cy + s], [cx + s * 0.6, cy - s, cx - s * 0.6, cy + s]]
			3: strokes = [[cx - s * 0.6, cy - s, cx - s * 0.6, cy + s], [cx - s * 0.6, cy, cx + s * 0.6, cy - s * 0.6], [cx - s * 0.6, cy, cx + s * 0.6, cy + s * 0.6]]
			4: strokes = [[cx, cy - s, cx + s * 0.7, cy], [cx + s * 0.7, cy, cx, cy + s], [cx, cy + s, cx - s * 0.7, cy], [cx - s * 0.7, cy, cx, cy - s]]
			_: strokes = [[cx - s * 0.7, cy - s, cx + s * 0.7, cy - s], [cx, cy - s, cx, cy + s], [cx - s * 0.7, cy + s, cx + s * 0.7, cy + s]]
		for sk in strokes:
			_line_px(hgt, sk[0], sk[1], sk[2], sk[3], dark, 3)
			_line_px(emi, sk[0], sk[1], sk[2], sk[3], gold, 1)
		if kind % 2 == 0:
			for a in 24:
				var a0 := TAU * a / 24.0
				var a1 := TAU * (a + 1) / 24.0
				_line_px(hgt, cx + cos(a0) * 44, cy + sin(a0) * 44, cx + cos(a1) * 44, cy + sin(a1) * 44, dark, 2)
				_line_px(emi, cx + cos(a0) * 44, cy + sin(a0) * 44, cx + cos(a1) * 44, cy + sin(a1) * 44, gold * 0.8, 1)
		# divider tick
		_line_px(hgt, cw * ci, 30, cw * ci, 98, dark, 1)
	var alb := Image.create(W, H, false, Image.FORMAT_RGB8)
	for y in H:
		for x in W:
			var h := hgt.get_pixel(x, y).r
			var v := 0.18 * (0.35 + 0.65 * h / 0.8)
			alb.set_pixel(x, y, Color(v * 1.05, v, v * 0.95))
	hgt.bump_map_to_normal_map(6.0)
	var m := StandardMaterial3D.new()
	m.albedo_texture = _finish(alb)
	m.normal_enabled = true
	m.normal_texture = _finish(hgt)
	m.roughness = 0.85
	m.emission_enabled = true
	m.emission_texture = _finish(emi)
	m.emission = Color.WHITE
	m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	m.emission_energy_multiplier = 0.3
	_glyph_mat = m
	return m

# ---------------------------------------------------------------------------------------------
func _build_all() -> void:
	var bronze := _bronze_material()
	var copper := bronze.duplicate() as StandardMaterial3D
	copper.albedo_color = Color(1.0, 0.7, 0.55)
	var stone := _stone_material(true)
	var glyph := _glyph_material()

	# --- pedestal ---
	var steps := [[0.86, 0.10, 0.0], [0.68, 0.09, 0.10]]
	for s in steps:
		var bm := BoxMesh.new()
		bm.size = Vector3(s[0], s[1], s[0])
		var mi := _mi(bm, stone, self)
		mi.position = Vector3(0, float(s[2]) + float(s[1]) * 0.5, 0)
	var col_prof: Array = []
	for i in 13:
		var t := float(i) / 12.0
		var r := 0.235 + 0.05 * pow(1.0 - t, 3.0) + 0.04 * pow(t, 4.0) - 0.035 * sin(t * PI)
		col_prof.append(Vector2(r, 0.19 + t * 0.58))
	_mi(_lathe(col_prof, 28, Vector2(1, 1)), stone, self)
	var cap := BoxMesh.new()
	cap.size = Vector3(0.64, 0.07, 0.64)
	_mi(cap, stone, self).position = Vector3(0, 0.805, 0)
	var cap2 := BoxMesh.new()
	cap2.size = Vector3(0.5, 0.025, 0.5)
	_mi(cap2, stone, self).position = Vector3(0, 0.8425, 0)
	# glyph band
	var band_rows: Array = []
	for k in 2:
		var row := PackedVector3Array()
		row.resize(64)
		for i in 64:
			var a := TAU * float(i) / 64.0
			row[i] = Vector3(cos(a) * 0.262, 0.43 + k * 0.17, sin(a) * 0.262)
		band_rows.append(row)
	var gm := _grid_mesh(band_rows, Vector2(1, 1.0 / 0.17), false)
	_mi(gm, glyph, self)
	# bronze trim rings on the pedestal
	for ty in [0.405, 0.615]:
		_mi(_torus(Vector3(0, ty, 0), Vector3.UP, 0.262, 0.017), bronze, self)

	# --- horn ---
	var p0 := Vector3(0, 0.84, -0.10)
	var p1 := Vector3(0, 1.33, -0.10)
	var p2 := Vector3(0, 1.22, 0.06)
	var p3 := Vector3(0, 1.40, 0.46)
	var N := 56
	var pts := PackedVector3Array()
	var rad := PackedFloat32Array()
	for i in N:
		var t := float(i) / float(N - 1)
		pts.append(_bez(p0, p1, p2, p3, t))
		rad.append(0.03 * pow(9.0, t) + 0.03 * pow(maxf(0.0, (t - 0.86) / 0.14), 2.0))
	_spine = pts
	_mouth_pos = pts[N - 1]
	_mouth_dir = (pts[N - 1] - pts[N - 2]).normalized()
	var thick := 0.016
	var outer_rows: Array = _tube_rows(pts, rad, 48)
	# rim: half-torus from outer to inner wall
	var frames_n: Vector3 = (outer_rows[N - 1][0] - pts[N - 1]).normalized()
	var frames_b: Vector3 = _mouth_dir.cross(frames_n)
	var rim_rows: Array = []
	for k in range(1, 9):
		var ph := PI * float(k) / 8.0
		var rr: float = rad[N - 1] - thick * 0.5 + cos(ph) * thick * 0.5
		rim_rows.append(_ring(pts[N - 1] + _mouth_dir * (sin(ph) * thick * 0.7), frames_n, frames_b, rr, 48))
	var rows_a: Array = outer_rows + rim_rows
	_mi(_grid_mesh(rows_a, Vector2(3, 2.4), true), bronze, self)
	# inner wall (separate surface/material: ember-lit)
	var inner_rows: Array = []
	var inner_pts := PackedVector3Array()
	var i_start := 18
	for i in range(N - 1, i_start - 1, -1):
		var tt2 := (pts[mini(i + 1, N - 1)] - pts[maxi(i - 1, 0)]).normalized()
		inner_pts.append(pts[i])
		inner_rows.append(_ring(pts[i], Vector3.RIGHT, tt2.cross(Vector3.RIGHT), maxf(rad[i] - thick, 0.012), 48))
	var inner_mesh := _grid_mesh(inner_rows, Vector2(1, 1), true)
	var inner := StandardMaterial3D.new()
	inner.albedo_color = Color(0.12, 0.07, 0.04)
	inner.metallic = 0.9
	inner.roughness = 0.5
	inner.cull_mode = BaseMaterial3D.CULL_DISABLED
	inner.emission_enabled = true
	var gt := GradientTexture2D.new()
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.3, 0.6])
	grad.colors = PackedColorArray([Color(1, 0.2, 0.02), Color(0.5, 0.1, 0.02), Color(0, 0, 0)])
	gt.gradient = grad
	gt.width = 8
	gt.height = 128
	gt.fill_from = Vector2(0, 1)
	gt.fill_to = Vector2(0, 0)
	inner.emission_texture = gt
	inner.emission = Color(1, 0.75, 0.5)
	inner.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	inner.emission_energy_multiplier = 1.0
	inner.uv1_scale = Vector3(1, 1.0 / maxf(0.01, _path_len(inner_pts)), 1)
	_inner_mat = inner
	_mi(inner_mesh, inner, self)
	# ember core
	var core := SphereMesh.new()
	core.radius = 0.05
	core.height = 0.1
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.1, 0.03, 0.01)
	cm.emission_enabled = true
	cm.emission = Color(1.0, 0.42, 0.1)
	cm.emission_energy_multiplier = 1.0
	_core_mat = cm
	_mi(core, cm, self).position = pts[i_start + 2] + _mouth_dir * 0.01
	# ribs
	for rt in [0.2, 0.42, 0.62, 0.8]:
		var ri := int(rt * (N - 1))
		var tt := (pts[ri + 1] - pts[ri - 1]).normalized()
		_mi(_torus(pts[ri], tt, rad[ri] + 0.004, 0.011, 40, 8), bronze, self)
	# collar at the throat + cap on the pedestal
	_mi(_torus(pts[0] + Vector3(0, 0.02, 0), Vector3.UP, 0.075, 0.022, 28, 8), bronze, self)
	_mi(_torus(pts[0] + Vector3(0, 0.0, 0), Vector3.UP, 0.1, 0.02, 28, 8), bronze, self)
	# stay arm from pedestal cap to the horn's belly
	var s_a := Vector3(0, 0.855, 0.16)
	var s_b := pts[int(0.8 * (N - 1))] + Vector3(0, -rad[int(0.8 * (N - 1))] * 0.9, 0)
	var arm_pts := PackedVector3Array()
	var arm_rad := PackedFloat32Array()
	for i in 20:
		var t := float(i) / 19.0
		arm_pts.append(_bez(s_a, s_a + Vector3(0, 0.25, 0.02), s_b + Vector3(0, -0.2, -0.05), s_b, t))
		arm_rad.append(0.02 - 0.006 * t)
	_mi(_grid_mesh(_tube_rows(arm_pts, arm_rad, 10), Vector2(2, 1), true), bronze, self)
	_mi(_torus(Vector3.ZERO, Vector3.UP, 0.04, 0.012, 20, 6), bronze, self).position = s_a

	# --- ear reflector plates ---
	for side in [-1.0, 1.0]:
		var prof: Array = []
		for i in 9:
			var a := PI * 0.5 * float(i) / 8.0
			prof.append(Vector2(0.11 * sin(a), 0.07 * (1.0 - cos(a))))
		for i in 3:
			prof.append(Vector2(0.11 + 0.004 * (i + 1), 0.07 + 0.004 * i))
		for i in range(8, -1, -1):
			var a2 := PI * 0.5 * float(i) / 8.0
			prof.append(Vector2(0.104 * sin(a2), 0.07 * (1.0 - cos(a2)) + 0.006))
		var em := _lathe(prof, 28, Vector2(1, 1))
		var mi2 := _mi(em, bronze, self)
		var dirv := Vector3(-side * 0.55, 0.12, 0.82).normalized()
		var bx := Vector3.UP.cross(dirv).normalized()
		var bz := bx.cross(dirv)
		mi2.transform = Transform3D(Basis(bx * 0.62, dirv, bz * 1.7), _mouth_pos + Vector3(side * 0.37, 0.02, -0.09))
		# strut from rim to plate
		var strut_pts := PackedVector3Array()
		var strut_rad := PackedFloat32Array()
		var sa := _mouth_pos + Vector3(side * rad[N - 1] * 0.98, 0.0, -0.01)
		var sb := _mouth_pos + Vector3(side * 0.36, 0.0, -0.1)
		for i in 8:
			strut_pts.append(sa.lerp(sb, float(i) / 7.0))
			strut_rad.append(0.012)
		_mi(_grid_mesh(_tube_rows(strut_pts, strut_rad, 8), Vector2(1, 1), true), bronze, self)

	# --- copper speaking tube into the floor ---
	var tpts := PackedVector3Array()
	var trad := PackedFloat32Array()
	var tA := [Vector3(0, 0.70, -0.20), Vector3(0, 0.70, -0.55), Vector3(0.10, 0.46, -0.62), Vector3(0.30, 0.30, -0.64)]
	var tB := [Vector3(0.30, 0.30, -0.64), Vector3(0.50, 0.14, -0.66), Vector3(0.62, 0.20, -0.92), Vector3(0.88, -0.06, -0.98)]
	for i in 30:
		tpts.append(_bez(tA[0], tA[1], tA[2], tA[3], float(i) / 29.0))
		trad.append(0.03)
	for i in range(1, 30):
		tpts.append(_bez(tB[0], tB[1], tB[2], tB[3], float(i) / 29.0))
		trad.append(0.03)
	_mi(_grid_mesh(_tube_rows(tpts, trad, 14), Vector2(2, 3), true), copper, self)
	for ci in [6, 20, 34, 48]:
		var tg := (tpts[ci + 1] - tpts[ci - 1]).normalized()
		_mi(_torus(tpts[ci], tg, 0.034, 0.012, 20, 6), bronze, self)
	var fl := (tpts[1] - tpts[0]).normalized()
	_mi(_torus(tpts[0] + fl * 0.01, fl, 0.045, 0.014, 20, 6), bronze, self)
	_mi(_torus(Vector3(0.88, 0.0, -0.98), Vector3.UP, 0.06, 0.014, 20, 6), bronze, self)

	# --- light ---
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.58, 0.26)
	_light.omni_range = 5.5
	_light.omni_attenuation = 1.4
	_light.light_energy = 0.6
	_light.shadow_enabled = false
	_light.position = _mouth_pos + _mouth_dir * 0.12
	add_child(_light)

	# --- particles ---
	_particles = GPUParticles3D.new()
	_particles.amount = 40
	_particles.lifetime = 5.0
	_particles.local_coords = false
	_particles.visibility_aabb = AABB(Vector3(-2, -1, -1), Vector3(4, 4, 5))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 28.0
	pm.initial_velocity_min = 0.08
	pm.initial_velocity_max = 0.3
	pm.gravity = Vector3(0, 0.035, 0)
	pm.damping_min = 0.05
	pm.damping_max = 0.2
	pm.scale_min = 0.012
	pm.scale_max = 0.03
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.16
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.25
	pm.turbulence_noise_scale = 1.5
	var cg := Gradient.new()
	cg.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
	cg.colors = PackedColorArray([Color(1, 0.6, 0.2, 0.0), Color(1, 0.62, 0.22, 0.95), Color(0.9, 0.4, 0.12, 0.5), Color(0.5, 0.2, 0.08, 0.0)])
	var cgt := GradientTexture1D.new()
	cgt.gradient = cg
	pm.color_ramp = cgt
	_particles.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.vertex_color_use_as_albedo = true
	qm.billboard_keep_scale = true
	var dot := GradientTexture2D.new()
	var dg := Gradient.new()
	dg.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	dot.gradient = dg
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.width = 32
	dot.height = 32
	qm.albedo_texture = dot
	q.material = qm
	_particles.draw_pass_1 = q
	var bz2 := _mouth_dir
	var bx2 := Vector3.UP.cross(bz2).normalized()
	_particles.transform = Transform3D(Basis(bx2, bz2.cross(bx2), bz2), _mouth_pos + _mouth_dir * 0.05)
	add_child(_particles)

	# --- audio ---
	for i in 2:
		var ap := AudioStreamPlayer3D.new()
		ap.unit_size = 7.0
		ap.max_distance = 45.0
		ap.volume_db = 4.0
		ap.attenuation_filter_cutoff_hz = 20500.0
		ap.position = _mouth_pos + _mouth_dir * 0.05
		add_child(ap)
		_players.append(ap)

	# --- collision ---
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.42
	cyl.height = 0.9
	cs.shape = cyl
	cs.position = Vector3(0, 0.45, 0)
	body.add_child(cs)
	var cs2 := CollisionShape3D.new()
	var cyl2 := CylinderShape3D.new()
	cyl2.radius = 0.3
	cyl2.height = 0.7
	cs2.shape = cyl2
	cs2.position = Vector3(0, 1.3, 0.2)
	body.add_child(cs2)
	add_child(body)

func _path_len(pts: PackedVector3Array) -> float:
	var d := 0.0
	for i in range(1, pts.size()):
		d += (pts[i] - pts[i - 1]).length()
	return d
