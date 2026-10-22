class_name FarmerScene
extends Control
## The Sap Farmer's visit: he rises out of the garden floor on the player's 10th Sprout, explains where sap
## comes from and what it is for, then sinks back leaving a warm lantern glow near the seed.
## Usage: `await FarmerScene.play(self)`; plays once (IdleFlags "farmer_seen") unless `force`.
## Click / any key: finish the typing, then go to the next line. Esc (or right click): skip the whole visit.

signal finished
signal seed_granted(seed_id: String)

const FLAG := "farmer_seen"
const WORD_KEY := "item:sap"
const AMBER := Color(1.0, 0.72, 0.25)
const GOLD := Color(1.0, 0.88, 0.55)

# text, pose, word (a glyph word that resolves into English at the start of the line)
const LINES: Array = [
	["Ten Sprouts now. The little garden has noticed you.", "idle", "", ""],
	["I am the Sap Farmer. I keep what the roots give up.", "jar", "", ""],
	["SAP is the garden's memory, made liquid.", "jar", "SAP", "item:sap"],
	["When the first Fractal Tree saw the world fall silent, it wept.", "idle", "", ""],
	["Those tears are sap. Every drop holds the whole tree.", "jar", "", ""],
	["Look closely: inside a drop, a smaller garden.", "jar", "", ""],
	["It still seeps up from the roots beneath everything.", "idle", "", ""],
	["A drop becomes a Sprout. Sprouts weep more sap.", "point", "", ""],
	["It feeds ferns and trees, and pays for tools.", "point", "", ""],
	["Later: insight, essences, and the angel's price to begin again.", "idle", "", ""],
	["Amber Seed: older than the garden, and quite alive. Take it.", "gift", "Amber Seed", "item:amber_seed"],
	["Tend it in the Upgrades, and every touch draws more sap.", "gift", "", "merge"],
	["Keep planting: ferns and tools will open as you grow.", "point", "", ""],
]

static var time_scale := 1.0
static var start_line := 0   # debug: begin at this line
static var _voice_cache: Array[AudioStreamWAV] = []

var farmer: SapFarmer
var clip: Control
var bubble: Control
var voice: Array[AudioStreamPlayer] = []
var voice_i := 0
var done := false
var lines_shown := 0

var _dim := 0.0
var _hole := 0.0
var _seed_lit := 0.0
var _lantern_a := 0.0
var _rise := 0.0            # 0 = fully below the floor, 1 = standing
var _t := 0.0
var _adv := false
var _fast := false
var _typing := false
var _skip := false
var on_grant: Callable = Callable()
var _granted := false
var _gift := 0.0        # 0 = no seed, 0..1 appears above his hand
var _fly := 0.0         # 0..1 the amber seed flies to the central seed
var _bloom := 0.0       # 0..1 merge bloom + ring pulse
var _ground_pose := "idle"


static func seen() -> bool:
	return bool(IdleFlags.get_flag(FLAG, false))


static func play(parent: Node, on_grant: Callable = Callable(), force := false) -> void:
	if parent == null or (seen() and not force):
		return
	var sc := FarmerScene.new()
	sc.on_grant = on_grant
	parent.add_child(sc)
	await sc.finished


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	IdleFlags.set_flag(FLAG, true)
	# his floor-clip: he only exists above the ground line, so he rises out of the earth
	clip = Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.position = Vector2.ZERO
	clip.size = Vector2(size.x, _ground() + 3.0)
	add_child(clip)
	farmer = SapFarmer.new()
	farmer.scale = Vector2.ONE * (size.y / 640.0)
	farmer.position = Vector2(_stage_x(), _ground() + 340.0 * farmer.scale.y)
	farmer.fade = 0.0
	clip.add_child(farmer)
	bubble = Control.new()
	bubble.set_script(load("res://idle/farmer_bubble.gd"))
	bubble.font_size = 25
	bubble.scale = Vector2.ZERO
	bubble.z_index = 5
	add_child(bubble)
	_make_voice()
	_run()


func _ground() -> float:
	return size.y * 0.80


func _stage_x() -> float:
	return size.x * 0.27


func _seed_c() -> Vector2:
	return Vector2(size.x * 0.5, _ground() - 118.0)


func _mouth() -> Vector2:
	return farmer.position + SapFarmer.MOUTH * farmer.scale


func _process(delta: float) -> void:
	_t += delta
	farmer.position.y = _ground() + (1.0 - _rise) * 345.0 * farmer.scale.y
	if size.x > 10.0:
		clip.size = Vector2(size.x, _ground() + 3.0)
	queue_redraw()


# ---------- input ----------

func _input(ev: InputEvent) -> void:
	if done:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		get_viewport().set_input_as_handled()
		if ev.keycode == KEY_ESCAPE:
			skip_all()
		else:
			advance()
	elif ev is InputEventMouseButton and ev.pressed:
		get_viewport().set_input_as_handled()
		if ev.button_index == MOUSE_BUTTON_RIGHT:
			skip_all()
		else:
			advance()


func advance() -> void:
	_adv = true
	if _typing:
		_fast = true


func skip_all() -> void:
	_skip = true


# ---------- timing helpers ----------

func _wait(sec: float) -> void:
	var el := 0.0
	while el < sec and not _skip and is_inside_tree():
		await get_tree().process_frame
		el += get_process_delta_time() * time_scale


# waits until the player advances, or `sec` passes
func _wait_adv(sec: float) -> void:
	_adv = false
	var el := 0.0
	while el < sec and not _skip and not _adv and is_inside_tree():
		await get_tree().process_frame
		el += get_process_delta_time() * time_scale
	_adv = false


func _tw(obj: Object, prop: String, to: Variant, dur: float, trans := Tween.TRANS_SINE, ease := Tween.EASE_IN_OUT) -> Tween:
	var tw := create_tween()
	tw.set_speed_scale(time_scale)
	tw.tween_property(obj, prop, to, dur).set_trans(trans).set_ease(ease)
	return tw


# ---------- the visit ----------

func _run() -> void:
	_tw(self, "_dim", 1.0, 1.0)
	await _wait(0.9)
	# mist where he breaks through the floor, and a dark hole in the garden floor
	var puff := _make_mist(Vector2(_stage_x(), _ground()))
	add_child(puff)
	puff.emitting = true
	_tw(self, "_hole", 1.0, 0.8)
	_blip(0.5)
	var up := _tw(self, "_rise", 1.0, 2.6, Tween.TRANS_QUAD, Tween.EASE_OUT)
	_tw(farmer, "fade", 1.0, 2.4)
	await _wait(2.3)
	if not _skip:
		# a courteous bow of greeting
		await _tw(farmer, "bow", 1.0, 0.7).finished if not _skip else null
		await _wait(0.25)
		_tw(farmer, "bow", 0.0, 0.6)
		await _wait(0.5)

	for i in range(start_line, LINES.size()):
		if _skip:
			break
		await _say(i)
		lines_shown += 1
		await _unsay()
		if LINES[i][3] == "merge":
			await _merge()
		if i < LINES.size() - 1:
			await _wait(0.15)

	# farewell
	if not _granted:
		_do_grant()
	bubble.scale = Vector2.ZERO
	farmer.pose = "idle"
	if not _skip:
		_tw(self, "_seed_lit", 1.0, 0.8)
		await _tw(farmer, "bow", 1.0, 0.6).finished
		await _wait(0.2)
		_tw(farmer, "bow", 0.0, 0.5)
		await _wait(0.5)
	else:
		_tw(self, "_seed_lit", 0.8, 0.3)
	# leaves a warm lantern glow by the seed and sinks into the earth
	_tw(self, "_lantern_a", 1.0, 0.6)
	var puff2 := _make_mist(Vector2(_stage_x(), _ground()))
	add_child(puff2)
	puff2.emitting = true
	var sink_t := 0.5 if _skip else 2.0
	var dn := _tw(self, "_rise", 0.0, sink_t, Tween.TRANS_QUAD, Tween.EASE_IN)
	_tw(farmer, "fade", 0.0, sink_t)
	await dn.finished
	_tw(self, "_hole", 0.0, 0.8)
	_tw(self, "_dim", 0.0, 1.2)
	await _wait(0.5 if _skip else 1.6)
	_tw(self, "_lantern_a", 0.0, 1.4 if not _skip else 0.4)
	await _wait(1.4 if not _skip else 0.4)
	done = true
	finished.emit()
	queue_free()


func _say(i: int) -> void:
	var line: Array = LINES[i]
	var text: String = line[0]
	var word: String = line[2]
	var wkey: String = line[3] if word != "" else ""
	var full := _wrap(text, word)
	var f: Font = bubble.font
	var fs: int = bubble.font_size
	bubble.word_key = ""
	bubble.word_on = 0.0
	bubble.word_a = 0.0
	bubble.hint_a = 0.0
	var holes := 0
	if word != "":
		_ensure_word(wkey, word)
		var sw := f.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		holes = int(ceil((f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 14.0) / sw))
		bubble.word_text = word
		bubble.word_w = holes * sw
		bubble.word_key = wkey
		full = " ".repeat(holes) + full.substr(word.length())
	farmer.pose = line[1]
	if line[1] == "gift" and _gift < 0.5:
		_tw(self, "_gift", 1.0, 1.1)
	bubble.fit(full)
	# place the bubble to the right of his head, tail pointing at his mouth
	var m := _mouth()
	var bx := minf(m.x + 105.0 * farmer.scale.x, size.x - 14.0 - bubble.size.x)
	bubble.position = Vector2(bx, maxf(m.y - 62.0 * farmer.scale.y - bubble.size.y, 14.0))
	bubble.tail_tip = m + Vector2(16.0, 6.0) * farmer.scale.x - bubble.position
	bubble.pivot_offset = bubble.tail_tip
	bubble.shown = ""
	_tw(bubble, "scale", Vector2.ONE, 0.3, Tween.TRANS_BACK, Tween.EASE_OUT)
	await _wait(0.35)
	_typing = true
	_fast = false
	_adv = false
	for k in full.length():
		if _skip:
			break
		if _fast:
			bubble.shown = full
			break
		bubble.shown = full.substr(0, k + 1)
		var ch := full[k]
		if holes > 0 and k >= holes - 1:
			bubble.word_on = 1.0
		if ch != " " and k % 2 == 0:
			farmer.talk = 1.0
			_blip()
		elif ch != " ":
			farmer.talk = maxf(farmer.talk, 0.7)
		var d := 0.05 if ch == " " else 0.027
		if ch in ",:;":
			d = 0.15
		elif ch in ".?!":
			d = 0.2
		await _wait(d)
	bubble.shown = full
	if holes > 0:
		bubble.word_on = 1.0
	_typing = false
	if not _skip:
		_tw(bubble, "hint_a", 1.0, 0.4)
		if holes > 0:
			# the glyph word resolves into English
			_blip(0.7)
			_tw(bubble, "word_a", 1.0, 1.1)
		await _wait_adv(0.4 + 0.015 * text.length() + (0.8 if holes > 0 else 0.0))
	farmer.pose = "idle"


func _unsay() -> void:
	bubble.hint_a = 0.0
	await _tw(bubble, "scale", Vector2.ZERO, 0.18, Tween.TRANS_BACK, Tween.EASE_IN).finished


func _ensure_word(key: String, word: String) -> void:
	if not Lexicon.has_concept(key):
		Lexicon.register(key, word.capitalize() if word != word.to_upper() else "Sap")


# ---------- drawing the world's reaction ----------

func _draw() -> void:
	var g := _ground()
	var w := size.x
	draw_rect(Rect2(0, 0, w, size.y), Color(0.01, 0.035, 0.03, 0.5 * _dim))
	# the opened earth
	if _hole > 0.01:
		for i in 5:
			var k := float(i) / 5.0
			draw_colored_polygon(_ellipse(Vector2(_stage_x(), g + 2.0), 80.0 * (1.0 - k * 0.5) * size.y / 640.0, 11.0 * (1.0 - k * 0.5), 28),
				Color(0.01, 0.025, 0.02, 0.35 * _hole))
		var ring := _ellipse(Vector2(_stage_x(), g + 2.0), 78.0 * size.y / 640.0, 11.0, 40)
		ring.append(ring[0])
		draw_polyline(ring, Color(AMBER, 0.3 * _hole), 1.5, true)
	# warm light of his lantern on the floor around him
	var lit := _rise * farmer.fade
	if lit > 0.01:
		var lc := Vector2(_stage_x() - 40.0 * farmer.scale.x, g)
		for i in 7:
			var k := float(i) / 7.0
			draw_colored_polygon(_ellipse(lc, 220.0 * (1.0 - k * 0.8) * size.y / 640.0, 26.0 * (1.0 - k * 0.8), 28), Color(1.0, 0.75, 0.3, 0.04 * lit * (1.0 + k)))
	# the seed gets lit when he gestures at it
	var sc := _seed_c()
	var pointing := 1.0 if farmer.pose == "point" else 0.0
	var seed_a := maxf(_seed_lit * 0.5, pointing * 0.9)
	if seed_a > 0.01:
		var pulse := 0.8 + 0.2 * sin(_t * 3.0)
		for i in 8:
			var k := float(i) / 8.0
			draw_circle(sc, 130.0 * (1.0 - k * 0.8), Color(1.0, 0.82, 0.4, 0.035 * seed_a * pulse * (1.0 + k)))
		if pointing > 0.5:
			# motes drifting from his fingertip to the seed
			var from := farmer.position + Vector2(165.0, -214.0) * farmer.scale.x
			for n in 7:
				var u := fposmod(_t * 0.5 + n / 7.0, 1.0)
				var p := from.lerp(sc, u) + Vector2(0, -sin(u * PI) * 26.0)
				draw_circle(p, 5.0, Color(GOLD, 0.12 * sin(u * PI)))
				draw_circle(p, 1.8, Color(1.0, 0.95, 0.7, 0.8 * sin(u * PI)))
	# the lantern he leaves beside the seed
	if _lantern_a > 0.01:
		var lp := Vector2(sc.x - 120.0 * size.y / 640.0, g - 12.0)
		var fl := 0.85 + 0.15 * sin(_t * 8.0) * sin(_t * 2.3)
		for i in 8:
			var k := float(i) / 8.0
			draw_circle(lp + Vector2(0, -10), 90.0 * (1.0 - k * 0.8), Color(1.0, 0.75, 0.3, 0.035 * _lantern_a * fl * (1.0 + k)))
		draw_colored_polygon(_ellipse(lp + Vector2(0, 4), 70.0, 9.0, 24), Color(1.0, 0.75, 0.3, 0.12 * _lantern_a))
		draw_rect(Rect2(lp + Vector2(-6, -22), Vector2(12, 22)), Color(0.26, 0.19, 0.11, _lantern_a))
		draw_colored_polygon(_ellipse(lp + Vector2(0, -11), 3.6, 6.5 * fl, 12), Color(1.0, 0.95, 0.7, _lantern_a))
	_draw_gift()


func _draw_tail() -> void:
	_draw_gift()


func _ellipse(c: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


# ---------- voice: a deep, warm, slow gibberish ----------

func _make_voice() -> void:
	if _voice_cache.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 777
		for i in 10:
			_voice_cache.append(_make_blip(rng.randf_range(78.0, 128.0), rng.randf_range(430.0, 780.0), rng.randf_range(0.11, 0.16)))
	for i in 3:
		var p := AudioStreamPlayer.new()
		p.volume_db = -7.0
		add_child(p)
		voice.append(p)


func _blip(pitch_mul := 1.0) -> void:
	var p := voice[voice_i % voice.size()]
	voice_i += 1
	p.stream = _voice_cache[randi() % _voice_cache.size()]
	p.pitch_scale = randf_range(0.9, 1.12) * pitch_mul
	p.play()


# additive voice: harmonics of a low fundamental shaped by one wide, round formant (an "oh/ah" vowel)
static func _make_blip(f0: float, formant: float, dur: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var amps: Array[float] = []
	for k in range(1, 26):
		var fk := f0 * k
		amps.append(exp(-pow((fk - formant) / 260.0, 2.0)) + 0.35 * exp(-pow((fk - 2.4 * formant) / 400.0, 2.0)) + 0.5 / k)
	for i in n:
		var tt := float(i) / rate
		var f := f0 * (1.0 + 0.03 * sin(TAU * 5.0 * tt)) * (1.0 - 0.10 * tt / dur)
		var ph := TAU * f * tt
		var v := 0.0
		for k in amps.size():
			v += amps[k] * sin(ph * (k + 1))
		var env := minf(tt / 0.02, 1.0) * pow(1.0 - tt / dur, 0.9)
		data.encode_s16(i * 2, int(clampf(v * env * 0.13, -1.0, 1.0) * 32767.0))
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
	p.amount = 40
	p.lifetime = 3.2
	p.explosiveness = 0.4
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(56, 4)
	p.direction = Vector2(0, -1)
	p.spread = 75.0
	p.gravity = Vector2(0, -5)
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 40.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.8
	p.z_index = 2
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(0.55, 0.85, 0.65, 0.0), Color(0.62, 0.9, 0.7, 0.34), Color(1.0, 0.85, 0.5, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	p.color_ramp = ramp
	return p


# ---------- the gift: the Amber Seed floats over and merges into the central seed ----------

func _do_grant() -> void:
	if _granted:
		return
	_granted = true
	if on_grant.is_valid():
		on_grant.call("amber_seed")
	seed_granted.emit("amber_seed")


func _hold_pos() -> Vector2:
	return farmer.position + Vector2(112.0, -276.0) * farmer.scale.x + Vector2(0, sin(_t * 2.2) * 3.0)


func _merge() -> void:
	farmer.pose = "idle"
	if _skip:
		_gift = 0.0
		_do_grant()
		return
	await _tw(self, "_fly", 1.0, 1.5, Tween.TRANS_SINE, Tween.EASE_IN_OUT).finished
	_gift = 0.0
	_chime()
	_do_grant()
	_tw(self, "_bloom", 1.0, 1.4, Tween.TRANS_QUAD, Tween.EASE_OUT)
	_fly = 0.0
	await _wait(1.0)
	_seed_lit = 1.0


func _amber_seed(c: Vector2, r: float, a: float) -> void:
	for i in 8:
		var k := float(i) / 8.0
		draw_circle(c, r * 3.4 * (1.0 - k * 0.8), Color(1.0, 0.72, 0.25, 0.05 * a * (1.0 + k)))
	# body: warm gradient built from stacked circles
	for i in 10:
		var k := float(i) / 10.0
		draw_circle(c + Vector2(-r * 0.12, -r * 0.14) * k, r * (1.0 - k * 0.8), Color(Color(0.95, 0.55, 0.12).lerp(Color(1.0, 0.95, 0.65), k), a))
	# a fractal sprig inside: the whole tree in one seed
	var col := Color(0.45, 0.2, 0.03, 0.85 * a)
	_sprig(c + Vector2(0, r * 0.55), -PI * 0.5, r * 0.62, 3, col)
	draw_arc(c, r, PI * 1.05, PI * 1.75, 16, Color(1.0, 0.98, 0.85, 0.9 * a), 1.6, true)
	draw_arc(c, r, -0.4, 0.9, 12, Color(0.4, 0.95, 0.8, 0.5 * a), 1.2, true)
	draw_circle(c + Vector2(-r * 0.35, -r * 0.4), r * 0.14, Color(1, 1, 1, 0.8 * a))
	for k in 4:
		var ang := _t * 0.9 + k * TAU / 4.0
		draw_circle(c + Vector2.from_angle(ang) * r * 1.7, 1.8, Color(1.0, 0.95, 0.7, 0.7 * a))


func _sprig(p: Vector2, ang: float, len: float, depth: int, col: Color) -> void:
	var q := p + Vector2.from_angle(ang) * len
	draw_line(p, q, col, 1.2 + depth * 0.3, true)
	if depth > 0:
		_sprig(q, ang - 0.55, len * 0.62, depth - 1, col)
		_sprig(q, ang + 0.55, len * 0.62, depth - 1, col)


func _draw_gift() -> void:
	var sc := _seed_c()
	var r := 20.0 * size.y / 640.0
	if _fly > 0.001:
		var a := _hold_pos()
		var u: float = Tween.interpolate_value(0.0, 1.0, _fly, 1.0, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
		var p := a.lerp(sc, u) + Vector2(0, -sin(u * PI) * 70.0)
		for n in 6:
			var uu := maxf(u - n * 0.035, 0.0)
			draw_circle(a.lerp(sc, uu) + Vector2(0, -sin(uu * PI) * 70.0), r * (0.5 - n * 0.06), Color(1.0, 0.8, 0.35, 0.25 * (1.0 - n / 6.0)))
		_amber_seed(p, r * (1.0 - 0.25 * u), 1.0)
	elif _gift > 0.001:
		var rise: float = Tween.interpolate_value(0.0, 1.0, _gift, 1.0, Tween.TRANS_QUAD, Tween.EASE_OUT)
		var jar_p := farmer.position + Vector2(96.0, -158.0) * farmer.scale.x
		_amber_seed(jar_p.lerp(_hold_pos(), rise), r * (0.4 + 0.6 * rise), minf(rise * 2.0, 1.0))
	if _bloom > 0.001:
		var b := _bloom
		for i in 8:
			var k := float(i) / 8.0
			draw_circle(sc, 220.0 * (1.0 - k * 0.7) * (0.4 + b * 0.6), Color(1.0, 0.85, 0.5, 0.07 * (1.0 - b) * (1.0 + k)))
		for ring in 2:
			var rb := clampf(b * 1.3 - ring * 0.25, 0.0, 1.0)
			draw_arc(sc, 20.0 + 190.0 * rb, 0, TAU, 48, Color(1.0, 0.9, 0.6, 0.8 * (1.0 - rb)), 3.0 - 2.0 * rb, true)
		for n in 12:
			var ang := n * TAU / 12.0 + 0.3
			var d := 30.0 + 120.0 * b
			draw_circle(sc + Vector2.from_angle(ang) * d, 2.6 * (1.0 - b), Color(1.0, 0.95, 0.7, 1.0 - b))


static var _chime_stream: AudioStreamWAV


func _chime() -> void:
	if _chime_stream == null:
		var rate := 22050
		var dur := 1.6
		var n := int(rate * dur)
		var data := PackedByteArray()
		data.resize(n * 2)
		for i in n:
			var tt := float(i) / rate
			var v := sin(TAU * 784.0 * tt) * exp(-tt * 3.0) + 0.6 * sin(TAU * 1175.0 * tt) * exp(-tt * 4.0) \
				+ 0.35 * sin(TAU * 1568.0 * tt) * exp(-tt * 5.5) + 0.25 * sin(TAU * 2349.0 * tt) * exp(-tt * 8.0)
			data.encode_s16(i * 2, int(clampf(v * minf(tt / 0.004, 1.0) * 0.28, -1.0, 1.0) * 32767.0))
		var w := AudioStreamWAV.new()
		w.format = AudioStreamWAV.FORMAT_16_BITS
		w.mix_rate = rate
		w.data = data
		_chime_stream = w
	var p := AudioStreamPlayer.new()
	p.stream = _chime_stream
	p.volume_db = -6.0
	add_child(p)
	p.play()
	_blip(0.6)


# breaks long lines in two at the space nearest the middle
func _wrap(text: String, _word: String) -> String:
	if text.length() <= 36:
		return text
	var mid := text.length() / 2
	var best := -1
	for i in text.length():
		if text[i] == " " and (best < 0 or absi(i - mid) < absi(best - mid)):
			best = i
	return text.substr(0, best) + "\n" + text.substr(best + 1)
