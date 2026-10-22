extends Control

# Limbo: ash-grey void, drifting ash, fade in from the white flash. A little black angel in a red
# hat rises out of the ground, greets the player in gibberish, asks where they come from, and offers
# three answers written in pictograms nobody can read.

const GREETING := "Hello traveler"
const QUESTION := "Where do you come from?"
# glyph strings for the three answers (indices into glyphs.gd); unreadable on purpose
const ANSWERS: Array = [[1, 5, 0, 10, 3], [6, 2, 12, 7, 4, 9], [8, 13, 11, 0, 5]]

var sky: ColorRect
var mat: ShaderMaterial
var angel: Node2D
var stage: Control            # clips the angel at ground level so it can rise out of the floor
var bubble: Control
var choices: Array[Control] = []
var blips: Array[AudioStreamWAV] = []
var voice: Array[AudioStreamPlayer] = []
var voice_i := 0
var ground_y := 0.0
var picked := false
var shake := 0.0
var tscale := 1.0   # "-- --fast" shortens the collapse waits


func _ready() -> void:
	get_viewport().use_hdr_2d = false
	if "--fast" in OS.get_cmdline_user_args():
		tscale = 0.25
	Hub.boot()
	Hub.audio(get_tree())
	Hub.theme("shrine")   # mysterious: odd 5/4 meter, glass shimmer, unresolved harmony, no drums
	var sz := get_viewport_rect().size
	ground_y = sz.y * 0.80

	sky = ColorRect.new()
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = load("res://limbo.gdshader")
	sky.material = mat
	add_child(sky)

	add_child(_make_ash(60, 14.0, Vector2(0.6, 1.0), 1.0, 0.35, 0.0))

	_make_angel(sz)
	_make_bubble(sz)
	_make_choices(sz)
	_make_voice()

	add_child(_make_ash(26, 8.0, Vector2(0.9, 1.0), 2.4, 0.55, 40.0))

	# fade in from the white flash
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 1)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.0, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(flash.queue_free)

	_intro(sz)


func _process(_delta: float) -> void:
	mat.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake if shake > 0.01 else Vector2.ZERO


# ---------- the angel ----------

func _make_angel(sz: Vector2) -> void:
	# cold shadow on the ground that grows as the angel emerges
	var shadow := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(Vector2(cos(a) * 44.0, sin(a) * 9.0))
	shadow.polygon = pts
	shadow.color = Color(0, 0, 0, 0.0)
	shadow.name = "Shadow"
	shadow.position = Vector2(sz.x * 0.40, ground_y + 2.0)
	add_child(shadow)

	stage = Control.new()
	stage.clip_contents = true
	stage.position = Vector2.ZERO
	stage.size = Vector2(sz.x, ground_y + 4.0)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)

	angel = Node2D.new()
	angel.set_script(load("res://angel_npc.gd"))
	angel.position = Vector2(sz.x * 0.40, ground_y + 250.0)   # buried below the floor
	angel.visible = false
	stage.add_child(angel)


func _make_bubble(sz: Vector2) -> void:
	var mouth := Vector2(sz.x * 0.40, ground_y) + Vector2(0, -125)
	bubble = Control.new()
	bubble.set_script(load("res://bubble.gd"))
	bubble.position = mouth + Vector2(50, -108)
	bubble.tail_tip = mouth - bubble.position          # the wisp points at the angel's mouth
	bubble.pivot_offset = bubble.tail_tip              # pops out of the mouth
	bubble.scale = Vector2.ZERO
	add_child(bubble)


func _make_choices(sz: Vector2) -> void:
	var x := sz.x * 0.60
	var y0 := ground_y - 150.0
	for i in ANSWERS.size():
		var c := Control.new()
		c.set_script(load("res://choice.gd"))
		c.index = i
		c.glyph_ids = ANSWERS[i]
		c.position = Vector2(x, y0 + i * 70.0)
		c.modulate.a = 0.0
		c.chosen.connect(_on_chosen)
		add_child(c)
		choices.append(c)


# ---------- the scene ----------

func _say(text: String) -> void:
	bubble.fit(text)
	bubble.shown = ""
	create_tween().tween_property(bubble, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.4).timeout
	# the angel speaks, but all that comes out is gibberish
	for i in text.length():
		bubble.shown = text.substr(0, i + 1)
		var ch := text[i]
		if ch != " ":
			angel.talk = 1.0
			_blip()
		await get_tree().create_timer(0.12 if ch == " " else 0.075).timeout


func _unsay() -> void:
	var tw := create_tween()
	tw.tween_property(bubble, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tw.finished


func _intro(sz: Vector2) -> void:
	await get_tree().create_timer(2.7).timeout

	# mist bursts where the angel will break through the floor
	var puff := _make_mist(Vector2(sz.x * 0.40, ground_y))
	add_child(puff)
	puff.emitting = true
	var sh := get_node("Shadow") as Polygon2D
	create_tween().tween_property(sh, "color:a", 0.45, 2.0)

	angel.visible = true
	var rise := create_tween()
	rise.tween_property(angel, "position:y", ground_y, 2.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await rise.finished

	angel.waving = true
	await get_tree().create_timer(0.7).timeout

	await _say(GREETING)
	await get_tree().create_timer(1.0).timeout
	await _unsay()
	await get_tree().create_timer(0.25).timeout
	await _say(QUESTION)
	angel.waving = false
	await get_tree().create_timer(0.6).timeout

	# three answers surface, one after another
	for c in choices:
		_blip(0.7)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(c, "modulate:a", 1.0, 0.35)
		var home := c.position
		c.position = home + Vector2(36, 0)
		tw.tween_property(c, "position", home, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(0.3).timeout
	for c in choices:
		c.enabled = true
	if "--pick" in OS.get_cmdline_user_args():   # test hook: answer automatically
		await get_tree().create_timer(1.0).timeout
		_on_chosen(0)


func _on_chosen(index: int) -> void:
	if picked:
		return
	picked = true
	Hub.origin_hint = ["eclipse", "mirror", "cathedral"][clampi(index, 0, 2)]
	Hub.sfx("ui_click")
	for c in choices:
		c.enabled = false
	_blip(1.2)
	# the chosen tablet flares, the others sink away
	for c in choices:
		var tw := create_tween().set_parallel(true)
		if c.index == index:
			tw.tween_property(c, "hover", 1.0, 0.15)
			tw.tween_property(c, "scale", Vector2.ONE * 1.1, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			tw.tween_property(c, "modulate:a", 0.0, 0.4)
	await get_tree().create_timer(0.9).timeout
	create_tween().tween_property(choices[index], "modulate:a", 0.0, 0.5)
	await _unsay()
	await _say("...")
	await _collapse()


# After the "...": silence, the angel lowers his gaze, the floor of Limbo cracks and gives way.
func _collapse() -> void:
	await get_tree().create_timer(1.6 * tscale).timeout
	await _unsay()
	angel.waving = false
	# the angel lowers his gaze (a slow bow about his feet) and his shadow thickens
	var bow := create_tween().set_parallel(true)
	bow.tween_property(angel, "rotation", 0.06, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bow.tween_property(get_node("Shadow"), "color:a", 0.7, 1.4)
	await get_tree().create_timer(1.8 * tscale).timeout

	var sz := get_viewport_rect().size
	var origin := Vector2(sz.x * 0.5, ground_y + sz.y * 0.05)

	# low rumble + screen tremor
	var rum := AudioStreamPlayer.new()
	rum.stream = _make_rumble(4.5)
	rum.volume_db = -3.0
	add_child(rum)
	rum.play()
	shake = 0.0
	create_tween().tween_property(self, "shake", 7.0, 3.4 * tscale).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# fissures spread from beneath the traveler, glowing from within
	var cr := _Cracks.new()
	cr.origin = origin
	cr.setup(sz, ground_y)
	add_child(cr)
	var spread := create_tween()
	spread.tween_property(cr, "prog", 1.0, 3.2 * tscale).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# ash lifts off the floor along the cracks
	var lift := _make_specks(origin, Vector2(sz.x * 0.22, 6), 70, Color(0.55, 0.50, 0.46), 1.2, 3.0)
	add_child(lift)
	lift.emitting = true
	var emb := _make_specks(origin, Vector2(sz.x * 0.16, 6), 40, Color(1.0, 0.38, 0.1), 0.8, 3.2)
	add_child(emb)
	emb.emitting = true
	await get_tree().create_timer(2.6 * tscale).timeout
	lift.emitting = true
	emb.emitting = true
	await spread.finished

	# the floor gives way: the crack-light floods up, then the world goes dark and we drop
	var gl := ColorRect.new()
	gl.color = Color(0.9, 0.22, 0.04, 0.0)
	gl.set_anchors_preset(Control.PRESET_FULL_RECT)
	gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gl)
	var g1 := create_tween()
	g1.tween_property(gl, "color:a", 0.55, 0.5 * tscale).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	g1.tween_property(gl, "color", Color(0.02, 0.0, 0.0, 1.0), 0.7 * tscale)
	create_tween().tween_property(self, "shake", 0.0, 1.2 * tscale)
	await g1.finished
	position = Vector2.ZERO

	await FallCinematic.play(self)
	get_tree().change_scene_to_file("res://descent/obsidian_scene.tscn")


func _make_rumble(dur: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in n:
		var t := float(i) / rate
		var env := clampf(t / 3.0, 0.0, 1.0) * clampf((dur - t) / 0.8, 0.0, 1.0)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.02
		var v := (lp * 5.0 + sin(TAU * 38.0 * t) * 0.35 + sin(TAU * 23.0 * t) * 0.3) * env * 0.5
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w



# Jagged glowing fissures radiating from `origin`; `prog` (0..1) is how far they have crept.
class _Cracks extends Node2D:
	var origin := Vector2.ZERO
	var prog := 0.0
	var paths: Array = []   # each: PackedVector2Array from origin outward
	var widths: Array = []

	func setup(sz: Vector2, gy: float) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1311
		for k in 13:
			var ang := lerpf(-PI * 0.97, -PI * 0.03, float(k) / 12.0) + rng.randf_range(-0.12, 0.12)
			# fissures also run along the floor, so squash the vertical reach
			var reach_len := rng.randf_range(0.28, 0.62) * sz.x
			var pts := PackedVector2Array([origin])
			var p := origin
			var a := ang
			var steps := 14
			for s in steps:
				a += rng.randf_range(-0.45, 0.45)
				p += Vector2(cos(a), sin(a) * 0.38) * (reach_len / steps)
				pts.append(p)
			paths.append(pts)
			widths.append(rng.randf_range(2.0, 5.0))

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var t := Time.get_ticks_msec() * 0.001
		for i in paths.size():
			var pts: PackedVector2Array = paths[i]
			var n := pts.size()
			var reach := prog * float(n - 1) * (0.7 + 0.3 * float(i % 3) / 2.0)
			var upto := clampi(int(ceil(reach)) + 1, 2, n)
			var seg := PackedVector2Array()
			for j in upto:
				seg.append(pts[j])
			if upto >= 2 and reach < float(n - 1):
				var f := reach - floorf(reach)
				seg[upto - 1] = pts[upto - 2].lerp(pts[upto - 1], f if f > 0.0 else 1.0)
			var w: float = widths[i] * (0.5 + prog)
			var pulse := 0.8 + 0.2 * sin(t * 6.0 + float(i))
			draw_polyline(seg, Color(1.0, 0.25, 0.04, 0.10 * pulse * prog), w * 7.0, true)
			draw_polyline(seg, Color(1.0, 0.35, 0.06, 0.35 * pulse), w * 2.6, true)
			draw_polyline(seg, Color(0.02, 0.0, 0.0, 0.95), w * 1.2, true)
			draw_polyline(seg, Color(1.0, 0.72, 0.3, 0.8 * prog), maxf(1.0, w * 0.35), true)


func _make_specks(at: Vector2, extent: Vector2, count: int, col: Color, sz: float, life: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = _soft_dot()
	p.position = at
	p.one_shot = true
	p.emitting = false
	p.amount = count
	p.lifetime = life
	p.explosiveness = 0.12
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = extent
	p.direction = Vector2(0, -1)
	p.spread = 28.0
	p.gravity = Vector2(0, -6)
	p.initial_velocity_min = 12.0
	p.initial_velocity_max = 42.0
	p.scale_amount_min = 0.05 * sz
	p.scale_amount_max = 0.12 * sz
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(col, 0.0), Color(col, 0.95), Color(col, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	p.color_ramp = ramp
	return p

# ---------- gibberish voice ----------

func _make_voice() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in 12:
		blips.append(_make_blip(rng.randf_range(130.0, 380.0), rng.randf_range(0.05, 0.095)))
	for i in 3:
		var p := AudioStreamPlayer.new()
		p.volume_db = -9.0
		add_child(p)
		voice.append(p)


func _blip(pitch_mul := 1.0) -> void:
	var p := voice[voice_i % voice.size()]
	voice_i += 1
	p.stream = blips[randi() % blips.size()]
	p.pitch_scale = randf_range(0.82, 1.3) * pitch_mul
	p.play()


func _make_blip(freq: float, dur: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := 0.0
	for i in n:
		var tt := float(i) / rate
		var f := freq * (1.0 + 0.035 * sin(TAU * 27.0 * tt)) * (1.0 + 0.12 * (1.0 - tt / dur))
		ph += TAU * f / rate
		# a buzzy, nasal "vowel": fundamental plus a few strong harmonics
		var v := sin(ph) + 0.6 * sin(2.0 * ph) + 0.4 * sin(3.0 * ph + 0.5) + 0.2 * sin(5.0 * ph)
		var env := minf(tt / 0.006, 1.0) * exp(-tt * (1.6 / dur))
		data.encode_s16(i * 2, int(clampf(v * env * 0.2, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


# ---------- particles ----------

func _soft_dot() -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


func _make_mist(at: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = _soft_dot()
	p.position = at
	p.one_shot = true
	p.emitting = false
	p.amount = 34
	p.lifetime = 3.2
	p.explosiveness = 0.35
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(46, 4)
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.gravity = Vector2(0, -4)
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 38.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.7
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(0.7, 0.68, 0.68, 0.0), Color(0.72, 0.7, 0.7, 0.42), Color(0.6, 0.58, 0.6, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	p.color_ramp = ramp
	return p


func _make_ash(count: int, life: float, dir: Vector2, sz: float, alpha: float, vel: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = count
	p.lifetime = life
	p.preprocess = life
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(620, 10)
	p.position = Vector2(480, -20)
	p.direction = dir
	p.spread = 35.0
	p.gravity = Vector2(6, 10)
	p.initial_velocity_min = 4.0 + vel * 0.2
	p.initial_velocity_max = 14.0 + vel
	p.scale_amount_min = sz * 0.6
	p.scale_amount_max = sz * 1.4
	p.angular_velocity_min = -90.0
	p.angular_velocity_max = 90.0
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(0.85, 0.82, 0.8, 0.0), Color(0.85, 0.82, 0.8, alpha), Color(0.7, 0.68, 0.68, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	p.color_ramp = ramp
	return p
