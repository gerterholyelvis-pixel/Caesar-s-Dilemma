extends Node3D
## ACT 1 - the stone chamber. Closed box 8 x 10 x 4.5 m. Door in the far wall (+Z), the Oracle horn against the back
## wall (-Z). Yaw 0 looks toward +Z (the door). Textures/audio are baked on worker threads; `built` is true once ready.

const Env = preload("res://act1/chamber_env.gd")
const PlayerScript = preload("res://act1/player.gd")

const HW := 4.0     # half width  (x)
const HD := 5.0     # half depth  (z)
const H := 4.5

var built := false
var no_audio := false
var player: CharacterBody3D
var horn: Node3D
var horn_spot: Marker3D
var door_body: StaticBody3D
var door_opened := false

var _tex_thread: Thread
var _aud_thread: Thread
var _tex: Dictionary = {}
var _audio: Dictionary = {}
var _audio_started := false
var _flick: Array = []
var _noise := FastNoiseLite.new()
var _t := 0.0
var _fade_t := -1.0
var _fade_dur := 2.5
var _overlay_mat: ShaderMaterial
var _prompt: Label
var _msg: Label
var _msg_t := 0.0
var _sfx: AudioStreamPlayer
var _amb: AudioStreamPlayer
var _leaf_l: Node3D
var _leaf_r: Node3D
var _door_cs: CollisionShape3D
var _seam: Node3D
var _beyond_light: OmniLight3D
var _burst: GPUParticles3D
var _chains: Array = []
var _door_busy := false

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--noaudio":
			no_audio = true
	preload("res://game/hub.gd").theme("")
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_make_overlay()
	_tex_thread = Thread.new()
	_tex_thread.start(Callable(Env, "bake_textures"))
	if not no_audio:
		_aud_thread = Thread.new()
		_aud_thread.start(Callable(Env, "bake_audio"))

func _exit_tree() -> void:
	if _tex_thread != null and _tex_thread.is_started():
		_tex_thread.wait_to_finish()
	if _aud_thread != null and _aud_thread.is_started():
		_aud_thread.wait_to_finish()

# ------------------------------------------------------------------ public API
func open_door() -> void:
	if door_opened or _door_busy:
		return
	_door_busy = true
	door_opened = true
	if _door_cs != null:
		_door_cs.set_deferred("disabled", true)
	_play(_audio.get("open"), -4.0)
	if player != null:
		player.shake(0.35)
	_burst.restart()
	_burst.emitting = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_leaf_l, "rotation:y", deg_to_rad(88.0), 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_leaf_r, "rotation:y", deg_to_rad(-88.0), 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_beyond_light.shadow_enabled = true
	tw.tween_property(_beyond_light, "light_energy", 2.4, 3.0)
	tw.chain().tween_callback(func(): _door_busy = false)

func place_player(x: float, y: float, z: float, yaw_deg: float, pitch_deg: float) -> void:
	if player != null:
		player.place(Vector3(x, y, z), yaw_deg, pitch_deg)

func skip_fade() -> void:
	_fade_dur = 0.0

# ------------------------------------------------------------------ overlay (grain / vignette / fade)
func _make_overlay() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 20
	add_child(cl)
	var cr := ColorRect.new()
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_mat = ShaderMaterial.new()
	_overlay_mat.shader = Env.overlay_shader()
	_overlay_mat.set_shader_parameter("fade", 1.0)
	cr.material = _overlay_mat
	cl.add_child(cr)
	var hud := CanvasLayer.new()
	hud.layer = 15
	add_child(hud)
	var dot := ColorRect.new()
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.offset_left = -1.5; dot.offset_right = 1.5; dot.offset_top = -1.5; dot.offset_bottom = 1.5
	dot.color = Color(1, 0.85, 0.65, 0.3)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(dot)
	_prompt = _hud_label(hud, 96, 20, Color(1.0, 0.82, 0.55, 0.95))
	_msg = _hud_label(hud, 150, 22, Color(0.9, 0.78, 0.65, 0.0))

func _hud_label(parent: Node, top: float, size: int, col: Color) -> Label:
	var l := Label.new()
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.offset_top = top
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.visible_ratio = 1.0
	l.text = ""
	parent.add_child(l)
	return l

# ------------------------------------------------------------------ frame loop
func _process(delta: float) -> void:
	_t += delta
	if not built:
		if _tex_thread != null and not _tex_thread.is_alive():
			_tex = _tex_thread.wait_to_finish()
			_build()
		return
	if not _audio_started and _aud_thread != null and not _aud_thread.is_alive():
		_audio = _aud_thread.wait_to_finish()
		_start_audio()
	# fade in
	if _fade_t >= 0.0:
		_fade_t += delta
		var f: float = 1.0
		if _fade_dur > 0.0:
			f = 1.0 - smoothstep(0.0, 1.0, clampf((_fade_t - 0.25) / _fade_dur, 0.0, 1.0))
		else:
			f = 0.0
		_overlay_mat.set_shader_parameter("fade", f)
	# flicker
	for e in _flick:
		var l: Light3D = e[0]
		var n: float = _noise.get_noise_1d(_t * float(e[3]) + float(e[2]) * 37.0)
		var n2: float = _noise.get_noise_1d(_t * float(e[3]) * 2.7 + float(e[2]) * 11.0)
		l.light_energy = float(e[1]) * (1.0 + float(e[4]) * (n * 0.8 + n2 * 0.5))
	for c in _chains:
		var node: Node3D = c[0]
		node.rotation.z = sin(_t * 0.6 + float(c[1])) * 0.03
		node.rotation.x = cos(_t * 0.47 + float(c[1])) * 0.025
	# sigil pulse
	if _seam != null and not door_opened:
		_seam.scale.x = 1.0 + 0.15 * sin(_t * 1.7)
	_update_interaction(delta)

func _update_interaction(delta: float) -> void:
	if player == null:
		return
	var cam: Camera3D = player.cam
	var origin: Vector3 = cam.global_position
	var fwd: Vector3 = -cam.global_transform.basis.z
	var text := ""
	if _looking_at_horn(origin, fwd):
		text = "[E] speak"
	elif _looking_at_door(origin, fwd) and not door_opened:
		text = "[E] push"
	_prompt.text = text
	if _msg_t > 0.0:
		_msg_t -= delta
		_msg.add_theme_color_override("font_color", Color(0.9, 0.78, 0.65, clampf(_msg_t, 0.0, 1.0)))

func _looking_at_horn(origin: Vector3, fwd: Vector3) -> bool:
	if horn == null or horn_spot == null:
		return false
	var target: Vector3 = horn_spot.global_position + Vector3(0, 1.1, 0)
	var to: Vector3 = target - origin
	var dist: float = to.length()
	return dist <= 2.5 and fwd.dot(to / maxf(dist, 0.001)) > 0.92

func _looking_at_door(origin: Vector3, fwd: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(origin, origin + fwd * 2.5)
	q.exclude = [player.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and hit["collider"] == door_body

func _unhandled_input(ev: InputEvent) -> void:
	if not built or player == null:
		return
	var press := false
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_E:
		press = true
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		press = true
	if not press:
		return
	var cam: Camera3D = player.cam
	var origin: Vector3 = cam.global_position
	var fwd: Vector3 = -cam.global_transform.basis.z
	if _looking_at_horn(origin, fwd):
		if horn.has_method("interact"):
			horn.call("interact")
	elif _looking_at_door(origin, fwd) and not door_opened:
		_rattle_door()

func _rattle_door() -> void:
	_play(_audio.get("thud"), -3.0)
	get_tree().create_timer(0.35).timeout.connect(func(): _play(_audio.get("rattle"), -6.0))
	player.shake(0.6)
	_burst.restart()
	_burst.emitting = true
	var tw := create_tween()
	for i in 6:
		var a: float = 0.014 * (1.0 - float(i) / 6.0) * (1.0 if i % 2 == 0 else -1.0)
		tw.tween_property(_leaf_l, "rotation:y", a, 0.05)
	tw.tween_property(_leaf_l, "rotation:y", 0.0, 0.05)
	_msg.text = "The door will not yield."
	_msg_t = 2.6

func _play(stream: Variant, db: float) -> void:
	if no_audio or stream == null or _sfx == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

func _start_audio() -> void:
	_audio_started = true
	if _audio.is_empty():
		return
	_amb = AudioStreamPlayer.new()
	_amb.stream = _audio["ambient"]
	_amb.volume_db = -6.0
	add_child(_amb)
	_amb.play()
	player.steps = _audio["steps"]

# ------------------------------------------------------------------ build
func _build() -> void:
	var vp := get_viewport()
	vp.positional_shadow_atlas_size = 2048
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	var we := WorldEnvironment.new()
	we.environment = Env.make_environment()
	add_child(we)

	var wall: StandardMaterial3D = Env.stone_mat(_tex["wall"], 0.5)
	var wall_dk: StandardMaterial3D = Env.stone_mat(_tex["wall"], 0.5, Color(0.7, 0.68, 0.7))
	var wall_lt: StandardMaterial3D = Env.stone_mat(_tex["wall"], 0.5, Color(1.25, 1.2, 1.15), 1.0)
	var floor_m: StandardMaterial3D = Env.stone_mat(_tex["floor"], 0.25, Color(1, 1, 1), 0.8, 1.1)
	var wood: StandardMaterial3D = Env.stone_mat(_tex["wood"], 0.9, Color(0.9, 0.85, 0.8), 0.0, 1.0)
	var beam_m: StandardMaterial3D = Env.stone_mat(_tex["wood"], 0.7, Color(0.6, 0.55, 0.5), 0.0, 1.0)
	var iron: StandardMaterial3D = Env.metal_mat(Color(0.1, 0.1, 0.11), 0.55, 0.85)
	var bronze: StandardMaterial3D = Env.metal_mat(Color(0.5, 0.32, 0.14), 0.4, 0.9)

	_build_shell(wall, floor_m, wall_dk)
	_build_ceiling(wall_dk, beam_m, iron)
	_build_pillars(wall, wall_lt)
	_build_friezes(wall_lt)
	_build_door(wood, iron, bronze, wall_lt)
	_build_props(wall, iron, wood)
	_build_lights(iron, wood)
	_build_horn(wall, bronze)

	# floor sigil
	var sg: Texture2D = ImageTexture.create_from_image(_tex["sigil"])
	var sig := MeshInstance3D.new()
	var sq := QuadMesh.new()
	sq.size = Vector2(3.4, 3.4)
	sq.material = Env.additive_mat(sg, Color(0.04, 0.14, 0.2, 1.0))
	sig.mesh = sq
	sig.rotation_degrees = Vector3(-90, 0, 0)
	sig.position = Vector3(0, 0.014, 0.3)
	sig.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sig)
	# lintel glyph
	var lg := MeshInstance3D.new()
	var lq := QuadMesh.new()
	lq.size = Vector2(0.62, 0.62)
	lq.material = Env.additive_mat(sg, Color(1.4, 0.5, 0.12, 1.0))
	lg.mesh = lq
	lg.position = Vector3(0, 3.95, HD - 0.02)
	lg.rotation_degrees = Vector3(0, 180, 0)
	lg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lg)

	# dust motes + moonlit ash
	var d := Env.dust(Vector3(3.8, 2.2, 4.8), 160)
	d.position = Vector3(0, 2.3, 0)
	add_child(d)
	var ash := Env.ash_fall(Vector3(0.3, 0.1, 1.2))
	ash.position = Vector3(0.45, 4.4, 0.1)
	add_child(ash)

	# reflection probe for metals / wet floor fallback
	var rp := ReflectionProbe.new()
	rp.size = Vector3(8.0, 4.5, 10.0)
	rp.position = Vector3(0, 2.25, 0)
	rp.interior = true
	rp.box_projection = true
	rp.intensity = 0.7
	rp.update_mode = ReflectionProbe.UPDATE_ONCE
	rp.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	add_child(rp)

	# player
	player = CharacterBody3D.new()
	player.set_script(PlayerScript)
	add_child(player)
	player.position = Vector3(0.2, 0, -1.6)
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)
	built = true
	_fade_t = 0.0
	if _fade_dur <= 0.0:
		_overlay_mat.set_shader_parameter("fade", 0.0)

# ---- geometry helpers
func _box(parent: Node, pos: Vector3, size: Vector3, mat: Material, collide: bool = false, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		sb.add_child(cs)
		mi.add_child(sb)
	return mi

func _cyl_between(parent: Node, a: Vector3, b: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	var len: float = a.distance_to(b)
	cm.height = len
	cm.top_radius = r
	cm.bottom_radius = r
	cm.radial_segments = 8
	cm.rings = 1
	cm.material = mat
	mi.mesh = cm
	var dir: Vector3 = (b - a).normalized()
	var q := Quaternion(Vector3.UP, dir)
	mi.transform = Transform3D(Basis(q), (a + b) * 0.5)
	parent.add_child(mi)
	return mi

func _build_shell(wall: Material, floor_m: Material, wall_dk: Material) -> void:
	var root := Node3D.new()
	root.name = "Shell"
	add_child(root)
	_box(root, Vector3(0, -0.5, 0), Vector3(10, 1, 12), floor_m, true)
	_box(root, Vector3(-4.5, 2.25, 0), Vector3(1, H, 12), wall, true)
	_box(root, Vector3(4.5, 2.25, 0), Vector3(1, H, 12), wall, true)
	_box(root, Vector3(0, 2.25, -5.5), Vector3(10, H, 1), wall, true)
	# front wall with door opening x in [-1.2,1.2], y < 3.0
	_box(root, Vector3(-3.1, 2.25, 5.5), Vector3(3.8, H, 1), wall, true)
	_box(root, Vector3(3.1, 2.25, 5.5), Vector3(3.8, H, 1), wall, true)
	_box(root, Vector3(0, 3.75, 5.5), Vector3(2.4, 1.5, 1), wall, true)
	# baseboard plinth + cornice ledge
	for s in [-1.0, 1.0]:
		_box(root, Vector3(s * 3.93, 0.15, 0), Vector3(0.14, 0.3, 10), wall_dk, false)
		_box(root, Vector3(s * 3.92, 3.42, 0), Vector3(0.16, 0.08, 10), wall_dk, false)
	_box(root, Vector3(0, 0.15, -4.93), Vector3(8, 0.3, 0.14), wall_dk, false)
	_box(root, Vector3(0, 3.42, -4.92), Vector3(8, 0.08, 0.16), wall_dk, false)
	# corridor beyond the door (hidden until opened)
	var cor_floor: StandardMaterial3D = Env.stone_mat(_tex["floor"], 0.3, Color(0.7, 0.6, 0.6), 0.0)
	_box(root, Vector3(0, -0.5, 8.0), Vector3(4.4, 1, 4.0), cor_floor, true)
	_box(root, Vector3(-1.7, 1.5, 8.0), Vector3(1, 3.0, 4.0), wall_dk, true)
	_box(root, Vector3(1.7, 1.5, 8.0), Vector3(1, 3.0, 4.0), wall_dk, true)
	_box(root, Vector3(0, 3.5, 8.0), Vector3(4.4, 1, 4.0), wall_dk, true)
	_box(root, Vector3(0, 1.5, 10.5), Vector3(4.4, 3.0, 1), wall_dk, true)
	var glow := MeshInstance3D.new()
	var gq := QuadMesh.new()
	gq.size = Vector2(2.2, 3.0)
	gq.material = Env.additive_mat(Env.glow_tex(), Color(1.2, 0.28, 0.06, 0.7))
	glow.mesh = gq
	glow.position = Vector3(0, 1.4, 9.97)
	glow.rotation_degrees = Vector3(0, 180, 0)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)
	_beyond_light = OmniLight3D.new()
	_beyond_light.position = Vector3(0, 1.6, 7.6)
	_beyond_light.light_color = Color(1.0, 0.32, 0.1)
	_beyond_light.light_energy = 0.0
	_beyond_light.omni_range = 9.0
	add_child(_beyond_light)

func _build_ceiling(wall_dk: Material, beam_m: Material, iron: Material) -> void:
	var root := Node3D.new()
	root.name = "Ceiling"
	add_child(root)
	var sx0: float = -0.6
	var sx1: float = 0.9
	var sz0: float = -1.8
	var sz1: float = 1.6
	_box(root, Vector3((-5.0 + sx0) * 0.5, 4.8, 0), Vector3(sx0 + 5.0, 0.6, 12), wall_dk, true)
	_box(root, Vector3((5.0 + sx1) * 0.5, 4.8, 0), Vector3(5.0 - sx1, 0.6, 12), wall_dk, true)
	_box(root, Vector3((sx0 + sx1) * 0.5, 4.8, (-6.0 + sz0) * 0.5), Vector3(sx1 - sx0, 0.6, sz0 + 6.0), wall_dk, true)
	_box(root, Vector3((sx0 + sx1) * 0.5, 4.8, (6.0 + sz1) * 0.5), Vector3(sx1 - sx0, 0.6, 6.0 - sz1), wall_dk, true)
	# sky glimpse through the crack
	var sky := MeshInstance3D.new()
	var skq := QuadMesh.new()
	skq.size = Vector2(3.0, 4.0)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(0.35, 0.55, 0.95)
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	skq.material = sm
	sky.mesh = skq
	sky.rotation_degrees = Vector3(90, 0, 0)
	sky.position = Vector3(0.45, 6.4, 0.1)
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sky)
	# beams + braces
	for z in [-4.55, -2.5, -0.1, 2.0, 4.4]:
		_box(root, Vector3(0, 4.22, z), Vector3(8, 0.56, 0.46), beam_m, false)
		_box(root, Vector3(0, 3.93, z), Vector3(8, 0.08, 0.6), iron, false)
		for s in [-1.0, 1.0]:
			_box(root, Vector3(s * 3.2, 3.8, z), Vector3(1.5, 0.3, 0.38), beam_m, false, Vector3(0, 0, s * -42.0))
	# moonlight
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.75, 1.0)
	moon.light_energy = 3.0
	moon.light_volumetric_fog_energy = 2.0
	moon.shadow_enabled = true
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	moon.directional_shadow_max_distance = 16.0
	moon.shadow_bias = 0.03
	moon.shadow_blur = 1.2
	moon.transform = Transform3D(Basis.looking_at(Vector3(0.2, -1.0, 0.12).normalized(), Vector3(0, 0, 1)), Vector3(0, 8, 0))
	add_child(moon)

func _build_pillars(wall: Material, wall_lt: Material) -> void:
	var root := Node3D.new()
	root.name = "Pillars"
	add_child(root)
	# corner buttresses
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := Vector3(sx * 3.55, 0, sz * 4.55)
			_box(root, p + Vector3(0, 2.25, 0), Vector3(0.9, H, 0.9), wall, true)
			_box(root, p + Vector3(0, 0.2, 0), Vector3(1.06, 0.4, 1.06), wall_lt, false)
			_box(root, p + Vector3(0, 3.9, 0), Vector3(1.0, 0.25, 1.0), wall_lt, false)
	# wall pilasters
	for sx in [-1.0, 1.0]:
		for z in [-2.5, 2.0]:
			var p2 := Vector3(sx * 3.77, 0, z)
			_box(root, p2 + Vector3(0, 2.25, 0), Vector3(0.46, H, 0.7), wall, true)
			_box(root, p2 + Vector3(-sx * 0.0, 0.18, 0), Vector3(0.58, 0.36, 0.86), wall_lt, true)
			_box(root, p2 + Vector3(0, 3.95, 0), Vector3(0.56, 0.22, 0.84), wall_lt, false)

func _build_friezes(wall_lt: Material) -> void:
	var fm: StandardMaterial3D = Env.stone_mat(_tex["frieze"], 1.0, Color(1, 1, 1), 0.3, 1.5)
	fm.uv1_triplanar = false
	fm.uv1_world_triplanar = false
	fm.uv1_scale = Vector3(1.25, 1, 1)
	var fm2: StandardMaterial3D = fm.duplicate()
	fm2.uv1_scale = Vector3(1.0, 1, 1)
	var root := Node3D.new()
	root.name = "Friezes"
	add_child(root)
	var defs := [
		[Vector3(-3.985, 3.72, 0), Vector3(0, 90, 0), Vector2(10, 0.5), fm],
		[Vector3(3.985, 3.72, 0), Vector3(0, -90, 0), Vector2(10, 0.5), fm],
		[Vector3(0, 3.72, -4.985), Vector3(0, 0, 0), Vector2(8, 0.5), fm2],
	]
	for d in defs:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = d[2]
		q.material = d[3]
		mi.mesh = q
		mi.position = d[0]
		mi.rotation_degrees = d[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)

func _build_door(wood: Material, iron: Material, bronze: Material, wall_lt: Material) -> void:
	var root := Node3D.new()
	root.name = "Door"
	add_child(root)
	# stone frame
	for s in [-1.0, 1.0]:
		_box(root, Vector3(s * 1.5, 1.5, 4.88), Vector3(0.5, 3.0, 0.24), wall_lt, true)
		_box(root, Vector3(s * 1.5, 0.12, 4.86), Vector3(0.66, 0.24, 0.3), wall_lt, false)
	_box(root, Vector3(0, 3.25, 4.86), Vector3(3.5, 0.5, 0.28), wall_lt, true)
	_box(root, Vector3(0, 3.6, 4.9), Vector3(2.9, 0.2, 0.2), wall_lt, false)
	_box(root, Vector3(0, 0.02, 5.4), Vector3(2.5, 0.05, 1.2), wall_lt, false)
	# collider blocking the opening
	door_body = StaticBody3D.new()
	door_body.position = Vector3(0, 1.5, 5.55)
	_door_cs = CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.4, 3.0, 0.3)
	_door_cs.shape = bs
	door_body.add_child(_door_cs)
	root.add_child(door_body)
	# light behind the seam
	var seam_bar := MeshInstance3D.new()
	var sbm := QuadMesh.new()
	sbm.size = Vector2(0.06, 2.9)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(4.0, 1.4, 0.35)
	sbm.material = sm
	seam_bar.mesh = sbm
	seam_bar.position = Vector3(0, 1.5, 5.75)
	seam_bar.rotation_degrees = Vector3(0, 180, 0)
	seam_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(seam_bar)
	_seam = seam_bar
	# floor spill under the door
	var spill := MeshInstance3D.new()
	var spq := QuadMesh.new()
	spq.size = Vector2(0.9, 1.8)
	spq.material = Env.additive_mat(Env.glow_tex(), Color(1.0, 0.36, 0.08, 0.28))
	spill.mesh = spq
	spill.rotation_degrees = Vector3(-90, 0, 0)
	spill.position = Vector3(0, 0.03, 4.55)
	spill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(spill)
	_leaf_l = _make_leaf(root, -1.0, wood, iron, bronze)
	_leaf_r = _make_leaf(root, 1.0, wood, iron, bronze)
	# keyhole plate on the right leaf
	var kp := _box(_leaf_r, Vector3(-0.2, 1.25, -0.1), Vector3(0.12, 0.2, 0.03), iron)
	var kh := MeshInstance3D.new()
	var khm := BoxMesh.new()
	khm.size = Vector3(0.018, 0.06, 0.02)
	var km := StandardMaterial3D.new()
	km.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	km.albedo_color = Color(4.0, 1.4, 0.3)
	khm.material = km
	kh.mesh = khm
	kh.position = Vector3(0, 0, -0.02)
	kp.add_child(kh)
	# dust that shakes loose from the lintel
	_burst = Env.dust_burst(1.4)
	_burst.position = Vector3(0, 3.0, 4.7)
	add_child(_burst)

func _make_leaf(root: Node, side: float, wood: Material, iron: Material, bronze: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(side * 1.1, 0, 5.55)
	root.add_child(pivot)
	var dirx: float = -side            # leaf extends from hinge toward the centre
	_box(pivot, Vector3(dirx * 0.54, 1.475, 0), Vector3(1.08, 2.95, 0.16), wood)
	for y in [0.45, 1.5, 2.5]:
		for zf in [-1.0, 1.0]:
			_box(pivot, Vector3(dirx * 0.54, y, zf * 0.09), Vector3(1.08, 0.15, 0.04), iron)
		for k in 5:
			var st := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.034
			sm.height = 0.068
			sm.radial_segments = 8
			sm.rings = 4
			sm.material = iron
			st.mesh = sm
			st.position = Vector3(dirx * (0.12 + 0.2 * k), y, -0.115)
			st.scale = Vector3(1, 1, 0.6)
			pivot.add_child(st)
	# vertical stiles
	_box(pivot, Vector3(dirx * 0.04, 1.475, -0.09), Vector3(0.08, 2.95, 0.04), iron)
	# ring handle
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.035
	tm.outer_radius = 0.065
	tm.rings = 14
	tm.ring_segments = 6
	tm.material = bronze
	ring.mesh = tm
	ring.rotation_degrees = Vector3(90, 0, 0)
	ring.position = Vector3(dirx * 0.82, 1.25, -0.14)
	pivot.add_child(ring)
	var boss := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.06
	cm.bottom_radius = 0.07
	cm.height = 0.05
	cm.material = bronze
	boss.mesh = cm
	boss.rotation_degrees = Vector3(90, 0, 0)
	boss.position = Vector3(dirx * 0.82, 1.32, -0.12)
	pivot.add_child(boss)
	return pivot

func _build_props(wall: Material, iron: Material, wood: Material) -> void:
	var root := Node3D.new()
	root.name = "Props"
	add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	# rubble along walls and below the ceiling crack
	var rock_mat: Material = Env.stone_mat(_tex["wall"], 1.4, Color(1.0, 0.98, 1.0), 0.0, 1.6)
	for i in 26:
		var p := Vector3.ZERO
		var pick: int = rng.randi() % 4
		if pick == 0:
			p = Vector3(rng.randf_range(-3.8, -2.9), 0, rng.randf_range(-4.8, 4.0))
		elif pick == 1:
			p = Vector3(rng.randf_range(2.9, 3.8), 0, rng.randf_range(-4.8, 4.0))
		elif pick == 2:
			p = Vector3(rng.randf_range(-3.0, 3.0), 0, rng.randf_range(-4.8, -4.2))
		else:
			p = Vector3(1.2 + rng.randf_range(-0.8, 0.8), 0, 0.5 + rng.randf_range(-1.0, 1.0))
		var s: float = rng.randf_range(0.07, 0.3) * (1.4 if pick == 3 and i % 3 == 0 else 1.0)
		var mi := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.5
		sp.height = 1.0
		sp.radial_segments = 7
		sp.rings = 4
		sp.material = rock_mat
		mi.mesh = sp
		mi.scale = Vector3(s * rng.randf_range(0.9, 1.6), s * rng.randf_range(0.5, 0.9), s * rng.randf_range(0.9, 1.5))
		mi.position = p + Vector3(0, mi.scale.y * 0.3, 0)
		mi.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		root.add_child(mi)
	# a fallen slab and broken column drum under the crack
	_box(root, Vector3(1.9, 0.12, -0.6), Vector3(0.9, 0.24, 0.55), rock_mat, true, Vector3(4, 25, -6))
	var drum := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 0.32
	dm.bottom_radius = 0.34
	dm.height = 0.7
	dm.radial_segments = 12
	dm.material = rock_mat
	drum.mesh = dm
	drum.position = Vector3(-2.2, 0.3, 3.2)
	drum.rotation_degrees = Vector3(82, 20, 0)
	root.add_child(drum)
	var dbody := StaticBody3D.new()
	var dcs := CollisionShape3D.new()
	var dsh := CylinderShape3D.new()
	dsh.radius = 0.33; dsh.height = 0.7
	dcs.shape = dsh
	dbody.add_child(dcs)
	drum.add_child(dbody)
	# chains
	for def in [[Vector3(-2.0, 4.0, -0.1), 15], [Vector3(2.6, 4.0, 2.0), 11], [Vector3(-1.6, 4.0, -4.55), 9], [Vector3(2.9, 4.0, -2.5), 13]]:
		var ch := _chain(def[0], def[1], iron)
		root.add_child(ch)
		_chains.append([ch, rng.randf() * 6.0])

func _chain(top: Vector3, links: int, mat: Material) -> Node3D:
	var n := Node3D.new()
	n.position = top
	for i in links:
		var l := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.016
		tm.outer_radius = 0.042
		tm.rings = 10
		tm.ring_segments = 5
		tm.material = mat
		l.mesh = tm
		l.scale = Vector3(1, 1, 1.6)
		l.position = Vector3(0, -0.07 * i - 0.05, 0)
		l.rotation_degrees = Vector3(90, 0 if i % 2 == 0 else 90, 0)
		n.add_child(l)
	var hook := _box(n, Vector3(0, -0.07 * links - 0.12, 0), Vector3(0.05, 0.2, 0.05), mat)
	hook.rotation_degrees = Vector3(0, 0, 8)
	return n

func _flicker(l: Light3D, amp: float, speed: float) -> void:
	_flick.append([l, l.light_energy, randf() * 50.0, speed, amp])

func _brazier(pos: Vector3, shadow: bool, iron: Material) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	for a in 3:
		var ang: float = TAU * a / 3.0 + 0.5
		_cyl_between(root, Vector3(cos(ang) * 0.34, 0, sin(ang) * 0.34), Vector3(cos(ang) * 0.17, 0.78, sin(ang) * 0.17), 0.026, iron)
	var bowl := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.4
	bm.bottom_radius = 0.2
	bm.height = 0.3
	bm.radial_segments = 16
	bm.material = iron
	bowl.mesh = bm
	bowl.position = Vector3(0, 0.88, 0)
	root.add_child(bowl)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.385
	tm.outer_radius = 0.42
	tm.rings = 20
	tm.ring_segments = 5
	tm.material = iron
	rim.mesh = tm
	rim.position = Vector3(0, 1.03, 0)
	root.add_child(rim)
	var coal := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.34
	cm.height = 0.3
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.1, 0.03, 0.01)
	cmat.emission_enabled = true
	cmat.emission = Color(1.0, 0.28, 0.05)
	cmat.emission_energy_multiplier = 2.6
	cm.material = cmat
	coal.mesh = cm
	coal.position = Vector3(0, 0.98, 0)
	root.add_child(coal)
	var f := Env.fire(1.5)
	f.position = Vector3(0, 1.05, 0)
	root.add_child(f)
	var e := Env.embers(1.2)
	e.position = Vector3(0, 1.15, 0)
	root.add_child(e)
	var li := OmniLight3D.new()
	li.position = Vector3(0, 1.45, 0)
	li.light_color = Color(1.0, 0.55, 0.22)
	li.light_energy = 4.5
	li.omni_range = 9.0
	li.omni_attenuation = 1.3
	li.shadow_enabled = shadow
	li.shadow_bias = 0.05
	li.light_volumetric_fog_energy = 1.5
	root.add_child(li)
	_flicker(li, 0.22, 1.7)

func _torch(pos: Vector3, n: Vector3, shadow: bool, iron: Material, wood: Material) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var tip: Vector3 = n * 0.3 + Vector3(0, 0.38, 0)
	_cyl_between(root, n * 0.05, tip, 0.032, wood)
	var cup := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.07
	cm.bottom_radius = 0.04
	cm.height = 0.12
	cm.material = iron
	cup.mesh = cm
	cup.position = tip
	root.add_child(cup)
	_box(root, n * 0.02 + Vector3(0, -0.04, 0), Vector3(0.14, 0.14, 0.06) if absf(n.x) < 0.5 else Vector3(0.06, 0.14, 0.14), iron)
	var f := Env.fire(0.75)
	f.position = tip + Vector3(0, 0.07, 0)
	root.add_child(f)
	var e := Env.embers(0.6)
	e.amount = 8
	e.position = tip + Vector3(0, 0.1, 0)
	root.add_child(e)
	var li := OmniLight3D.new()
	li.position = tip + Vector3(0, 0.15, 0) + n * 0.12
	li.light_color = Color(1.0, 0.5, 0.2)
	li.light_energy = 3.0
	li.omni_range = 6.5
	li.omni_attenuation = 1.3
	li.shadow_enabled = shadow
	li.shadow_bias = 0.05
	root.add_child(li)
	_flicker(li, 0.3, 2.3)

func _build_lights(iron: Material, wood: Material) -> void:
	_brazier(Vector3(-2.7, 0, 3.9), true, iron)
	_brazier(Vector3(2.7, 0, 3.9), true, iron)
	_torch(Vector3(-3.97, 2.35, 0.1), Vector3(1, 0, 0), false, iron, wood)
	_torch(Vector3(3.97, 2.35, -1.0), Vector3(-1, 0, 0), false, iron, wood)
	_torch(Vector3(-3.4, 2.35, -4.97), Vector3(0, 0, 1), true, iron, wood)

func _build_horn(wall: Material, bronze: Material) -> void:
	horn_spot = Marker3D.new()
	horn_spot.name = "HornSpot"
	horn_spot.position = Vector3(-1.9, 0, -4.4)
	add_child(horn_spot)
	if ResourceLoader.exists("res://act1/oracle_horn.gd"):
		var scr: Script = load("res://act1/oracle_horn.gd")
		horn = scr.new()
		horn.position = horn_spot.position
		add_child(horn)
	else:
		horn = Node3D.new()
		horn.position = horn_spot.position
		add_child(horn)
		var ped := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.28
		cm.bottom_radius = 0.34
		cm.height = 1.1
		cm.material = wall
		ped.mesh = cm
		ped.position = Vector3(0, 0.55, 0)
		horn.add_child(ped)
		var cone := MeshInstance3D.new()
		var cn := CylinderMesh.new()
		cn.top_radius = 0.3
		cn.bottom_radius = 0.04
		cn.height = 0.6
		cn.material = bronze
		cone.mesh = cn
		cone.position = Vector3(0, 1.4, 0.15)
		cone.rotation_degrees = Vector3(-70, 0, 0)
		horn.add_child(cone)
	# pedestal collider so the player cannot walk through it
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.42
	sh.height = 1.6
	cs.shape = sh
	cs.position = Vector3(0, 0.8, 0)
	sb.add_child(cs)
	horn_spot.add_child(sb)
	# candles at the horn's feet
	var cand := Node3D.new()
	cand.position = horn_spot.position + Vector3(0.85, 0, 0.55)
	add_child(cand)
	var wax := StandardMaterial3D.new()
	wax.albedo_color = Color(0.7, 0.64, 0.5)
	wax.roughness = 0.6
	var fl := StandardMaterial3D.new()
	fl.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fl.albedo_color = Color(4.0, 2.2, 0.8)
	for c in [[Vector3(0, 0, 0), 0.16], [Vector3(0.16, 0, 0.1), 0.1], [Vector3(-0.1, 0, 0.17), 0.2]]:
		var cm2 := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 0.02
		cy.bottom_radius = 0.026
		cy.height = c[1]
		cy.material = wax
		cm2.mesh = cy
		cm2.position = c[0] + Vector3(0, c[1] * 0.5, 0)
		cand.add_child(cm2)
		var fm := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.012
		sp.height = 0.04
		sp.material = fl
		fm.mesh = sp
		fm.position = c[0] + Vector3(0, c[1] + 0.025, 0)
		cand.add_child(fm)
		var gl := MeshInstance3D.new()
		var gq := QuadMesh.new()
		gq.size = Vector2(0.14, 0.14)
		var gm := Env.additive_mat(Env.glow_tex(), Color(1.0, 0.55, 0.2, 0.5))
		gm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		gq.material = gm
		gl.mesh = gq
		gl.position = fm.position
		gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cand.add_child(gl)
	var li := OmniLight3D.new()
	li.position = Vector3(0, 0.45, 0)
	li.light_color = Color(1.0, 0.62, 0.3)
	li.light_energy = 0.9
	li.omni_range = 4.0
	cand.add_child(li)
	_flicker(li, 0.3, 3.1)
