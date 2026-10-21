extends Node2D

# LAYER: ambient_fx. Depth-layered additive ambience in 960x640 design space:
# far motes (tiny, dim, slow), mid fireflies, near bokeh (big, soft, fast, ringed),
# faint drifting mist wisps and occasional shooting stars. One draw script, additive.

const W := 960.0
const H := 640.0
const HORIZON := 256.0

var _glow: ImageTexture
var _bokeh: ImageTexture
var _wisp: ImageTexture
var _streak: ImageTexture
var _t := 0.0
var _rng := RandomNumberGenerator.new()

# each: x,y,vx,vy,size,phase,twfreq,drift_amp,drift_freq,hue(0..1),bright
var _far: Array = []
var _mid: Array = []
var _near: Array = []
var _wisps: Array = []
var _stars: Array = []
var _next_star := 3.0

const COLS := [
	Color(0.55, 0.78, 1.0), Color(0.7, 0.85, 1.0), Color(0.5, 0.95, 0.9),
	Color(1.0, 0.78, 0.5), Color(0.8, 0.7, 1.0)
]


func _ready() -> void:
	_rng.seed = 7741
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m
	_glow = _make_glow(64, 2.2)
	_bokeh = _make_bokeh(96)
	_wisp = _make_wisp(128, 64)
	_streak = _make_streak(128, 8)
	for i in 70:
		_far.append(_spawn(0))
	for i in 30:
		_mid.append(_spawn(1))
	for i in 9:
		_near.append(_spawn(2))
	for i in 9:
		_wisps.append({
			"x": _rng.randf_range(-200, W + 200), "y": _rng.randf_range(HORIZON - 10, H - 40),
			"s": _rng.randf_range(300, 560), "v": _rng.randf_range(4, 12) * (1 if _rng.randf() > 0.3 else -1),
			"a": _rng.randf_range(0.5, 1.0), "ph": _rng.randf() * 6.28, "k": _rng.randf_range(0.4, 0.8)})


func _spawn(layer: int) -> Dictionary:
	var y: float
	# bias toward cloud area but keep some in the sky
	if _rng.randf() < 0.7:
		y = _rng.randf_range(HORIZON + 10, H)
	else:
		y = _rng.randf_range(30, HORIZON)
	var d := {
		"x": _rng.randf_range(-20, W + 20), "y": y,
		"ph": _rng.randf() * 6.283, "tw": _rng.randf_range(0.6, 2.4),
		"da": _rng.randf_range(6, 22), "df": _rng.randf_range(0.2, 0.7),
		"c": _rng.randi() % COLS.size(),
	}
	match layer:
		0:
			d["vx"] = _rng.randf_range(-3, 5); d["vy"] = _rng.randf_range(-4, -0.5)
			d["sz"] = _rng.randf_range(3.0, 6.0); d["b"] = _rng.randf_range(0.25, 0.55)
			d["c"] = _rng.randi() % 3
		1:
			d["vx"] = _rng.randf_range(-6, 9); d["vy"] = _rng.randf_range(-9, -1.5)
			d["sz"] = _rng.randf_range(7.0, 14.0); d["b"] = _rng.randf_range(0.5, 0.95)
		2:
			d["vx"] = _rng.randf_range(-14, 18); d["vy"] = _rng.randf_range(-16, -3)
			d["sz"] = _rng.randf_range(26.0, 60.0); d["b"] = _rng.randf_range(0.10, 0.22)
			d["da"] = _rng.randf_range(15, 40)
			if _rng.randf() < 0.5:
				d["y"] = _rng.randf_range(HORIZON + 80, H + 40)
	return d


func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	_t += delta
	for arr in [_far, _mid, _near]:
		for p in arr:
			p["x"] += p["vx"] * delta
			p["y"] += p["vy"] * delta
			if p["y"] < -40.0 or p["x"] > W + 70.0 or p["x"] < -70.0:
				p["y"] = H + _rng.randf_range(10, 40)
				p["x"] = _rng.randf_range(-20, W + 20)
	for w in _wisps:
		w["x"] += w["v"] * delta
		if w["x"] > W + 400.0:
			w["x"] = -400.0
		elif w["x"] < -400.0:
			w["x"] = W + 400.0
	_next_star -= delta
	if _next_star <= 0.0:
		_next_star = _rng.randf_range(5.0, 11.0)
		var dir := Vector2(_rng.randf_range(0.7, 1.0) * (1 if _rng.randf() > 0.4 else -1), _rng.randf_range(0.25, 0.5)).normalized()
		_stars.append({
			"p": Vector2(_rng.randf_range(120, 840) - dir.x * 120.0, _rng.randf_range(30, 150)),
			"d": dir, "t": 0.0, "life": _rng.randf_range(0.7, 1.1), "sp": _rng.randf_range(520, 780)})
	for s in _stars:
		s["t"] += delta
		s["p"] += s["d"] * s["sp"] * delta
	_stars = _stars.filter(func(s): return s["t"] < s["life"])
	if Engine.get_process_frames() % 3 == 2:
		queue_redraw()


func _horizon_fade(y: float) -> float:
	# subtle: slightly dimmer in the dark upper sky
	return lerpf(0.75, 1.0, clampf(y / H, 0.0, 1.0))


func _draw_layer(arr: Array, tex: Texture2D, tw_depth: float, kind: int) -> void:
	var half := tex.get_size() * 0.5
	for p in arr:
		var x: float = p["x"] + sin(_t * p["df"] + p["ph"]) * p["da"]
		var y: float = p["y"] + sin(_t * p["df"] * 1.3 + p["ph"] * 2.0) * p["da"] * 0.5
		var tw: float = 1.0 - tw_depth + tw_depth * (0.5 + 0.5 * sin(_t * p["tw"] + p["ph"]))
		if kind == 1:
			# firefly blink: occasionally pulse bright
			tw = pow(0.5 + 0.5 * sin(_t * p["tw"] * 0.9 + p["ph"]), 2.0) * 0.85 + 0.15
		# fade near screen edges
		var edge := clampf(minf(x, W - x) / 40.0, 0.0, 1.0) * clampf((H + 20.0 - y) / 40.0, 0.0, 1.0)
		var c: Color = COLS[p["c"]]
		var br: float = p["b"] * tw * edge * _horizon_fade(y)
		var s: float = p["sz"]
		if kind == 2:
			br *= 0.8 + 0.2 * sin(_t * 0.4 + p["ph"])
		var col := Color(c.r * br, c.g * br, c.b * br, 1.0)
		draw_texture_rect(tex, Rect2(Vector2(x, y) - Vector2(s, s) * 0.5, Vector2(s, s)), false, col)
		if kind == 1 and br > 0.4:
			# hot white-ish core
			var cs := s * 0.35
			var cc := Color(1.1, 1.05, 0.95, 1.0) * (br * 0.9)
			cc.a = 1.0
			draw_texture_rect(_glow, Rect2(Vector2(x, y) - Vector2(cs, cs) * 0.5, Vector2(cs, cs)), false, cc)


func _draw() -> void:
	if _glow == null:
		return
	# mist wisps (behind particles)
	for w in _wisps:
		var s: float = w["s"]
		var a: float = w["a"] * (0.6 + 0.4 * sin(_t * 0.15 + w["ph"])) * 0.07
		var col := Color(0.55 * a * 2.0, 0.65 * a * 2.0, 0.9 * a * 2.0, 1.0)
		var y: float = w["y"] + sin(_t * 0.1 + w["ph"]) * 8.0
		draw_texture_rect(_wisp, Rect2(Vector2(w["x"] - s * 0.5, y - s * w["k"] * 0.25), Vector2(s, s * w["k"] * 0.5)), false, col)
	_draw_layer(_far, _glow, 0.5, 0)
	_draw_layer(_mid, _glow, 0.9, 1)
	# shooting stars
	for s in _stars:
		var f: float = s["t"] / s["life"]
		var env := sin(f * PI)
		env = env * env
		var len := 110.0 + 60.0 * env
		var dir: Vector2 = s["d"]
		var head: Vector2 = s["p"]
		draw_set_transform(head, dir.angle(), Vector2.ONE)
		# streak texture: bright at right end (head)
		draw_texture_rect(_streak, Rect2(Vector2(-len, -3.0), Vector2(len, 6.0)), false, Color(0.9, 1.05, 1.3, 1.0) * (env * 0.95))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_texture_rect(_glow, Rect2(head - Vector2(14, 14), Vector2(28, 28)), false, Color(1.2, 1.3, 1.5, 1.0) * (env * 0.8))
	_draw_layer(_near, _bokeh, 0.35, 2)


# ---------- procedural textures ----------

func _make_glow(n: int, power: float) -> ImageTexture:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) * 0.5
	for y in n:
		for x in n:
			var r := Vector2(x - c, y - c).length() / c
			var v := 0.0
			if r < 1.0:
				var g := exp(-r * r * 5.0)
				v = g * (1.0 - r * r * r)  # soft gaussian with hard zero at the edge
				v = pow(v, 1.0) + 0.0
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	return ImageTexture.create_from_image(img)


func _make_bokeh(n: int) -> ImageTexture:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) * 0.5
	for y in n:
		for x in n:
			var r := Vector2(x - c, y - c).length() / c
			# soft disc with slightly brighter rim, feathered edge
			var disc := 1.0 - smoothstep(0.72, 1.0, r)
			var rim := exp(-pow((r - 0.86) / 0.09, 2.0)) * 0.55
			var v := (disc * 0.55 + rim * disc) * (1.0 - smoothstep(0.9, 1.0, r))
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	return ImageTexture.create_from_image(img)


func _make_wisp(w: int, h: int) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 31
	noise.frequency = 0.035
	noise.fractal_octaves = 3
	for y in h:
		for x in w:
			var u := (x + 0.5) / w * 2.0 - 1.0
			var v := (y + 0.5) / h * 2.0 - 1.0
			var r := sqrt(u * u + v * v * 1.6)
			var env := clampf(1.0 - r, 0.0, 1.0)
			env = env * env * (3.0 - 2.0 * env)
			var n := noise.get_noise_2d(x * 1.0, y * 2.0) * 0.5 + 0.5
			var a := env * clampf(n * 1.5 - 0.1, 0.0, 1.0)
			img.set_pixel(x, y, Color(a, a, a, 1.0))
	return ImageTexture.create_from_image(img)


func _make_streak(w: int, h: int) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var u := (x + 0.5) / w           # 0 tail -> 1 head
			var v := ((y + 0.5) / h) * 2.0 - 1.0
			var a := pow(u, 3.0) * exp(-v * v * 6.0)
			img.set_pixel(x, y, Color(a, a, a, 1.0))
	return ImageTexture.create_from_image(img)
