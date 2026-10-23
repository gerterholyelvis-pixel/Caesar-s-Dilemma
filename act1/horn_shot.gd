extends Node3D
# Dev helper: off-screen render of the Oracle Horn. Args after --: --out=<abs path>.png --noaudio
var _cam: Camera3D
var _out := "res://shots/horn_shot.png"
var _frame := 0
var _cp := Vector3(1.5, 1.45, 3.1)
var _ct := Vector3(0, 1.0, 0.1)
func _v3(s: String) -> Vector3:
	var p := s.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))
var _horn: Node3D

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): _out = a.substr(6)
		elif a.begins_with("--cp="): _cp = _v3(a.substr(5))
		elif a.begins_with("--ct="): _ct = _v3(a.substr(5))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.008, 0.012)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.10, 0.11, 0.16)
	env.ambient_light_energy = 0.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.05, 0.07)
	env.fog_density = 0.06
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.1
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(14, 14)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.1, 0.09, 0.09)
	fm.roughness = 0.8
	floor_mi.material_override = fm
	add_child(floor_mi)
	var torch := OmniLight3D.new()
	torch.light_color = Color(1.0, 0.65, 0.35)
	torch.light_energy = 2.2
	torch.omni_range = 7.0
	torch.position = Vector3(-2.0, 2.2, 1.6)
	add_child(torch)
	var rim := SpotLight3D.new()
	rim.light_color = Color(0.5, 0.65, 1.0)
	rim.light_energy = 4.0
	rim.spot_range = 8.0
	rim.spot_angle = 35.0
	rim.position = Vector3(1.8, 2.8, -2.2)
	add_child(rim)
	rim.look_at(Vector3(0, 1.0, 0.1), Vector3.UP)
	_horn = load("res://act1/oracle_horn.gd").new()
	_horn.set("debug_time_scale", 6.0)
	add_child(_horn)
	_cam = Camera3D.new()
	_cam.fov = 52
	add_child(_cam)
	_cam.position = _cp
	_cam.look_at(_ct, Vector3.UP)
	for c in _horn.get_children():
		if c is MeshInstance3D: print(c.mesh.get_aabb().size, " ", c.position)
	for a in OS.get_cmdline_user_args():
		if a == "--hide=particles": _horn.get("_particles").visible = false
		if a == "--noemi": _horn.get("_glyph_mat").emission_enabled = false
		if a == "--nonorm": _horn.get("_glyph_mat").normal_enabled = false
		if a == "--hide=light": _horn.get("_light").visible = false
	_horn.call("say", ["Another one falls, and the old stone shivers at the weight."])

func _process(_d: float) -> void:
	_frame += 1
	if _frame == 28:
		await _save(_out)
		_cam.position = Vector3(0.5, 1.5, 1.4)
		_cam.look_at(Vector3(0, 1.38, 0.35), Vector3.UP)
	if _frame == 40:
		_save(_out.replace(".png", "_close.png"))

func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
