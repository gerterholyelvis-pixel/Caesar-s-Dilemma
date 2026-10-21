extends Node2D

# GARDEN FX: living ambience over the garden background: light shafts, pollen/dust motes in three
# depths, water glints, drifting petals, dandelion seeds, butterflies, near bokeh.
# 960x640 design space, NOT scaled. All textures pre-generated; ~150-200 draw commands per frame.

const W := 960.0
const H := 640.0
const SUN := Vector2(300.0, 170.0)

var glow_tex: ImageTexture
var petal_tex: ImageTexture
var wing_tex: ImageTexture
var shaft_tex: ImageTexture
var glint_tex: ImageTexture
var seed_tex: ImageTexture

var add_layer: Node2D
var t := 0.0
var rng := RandomNumberGenerator.new()

var motes := []     # far / mid / near : {p, v, ph, s, d, c}
var petals := []
var seeds := []
var glints := []
var flies := []
var shafts := []


func _ready() -> void:
	rng.seed = 20261021
	glow_tex = _make_glow(64, 1.6)
	petal_tex = _make_petal(32)
	wing_tex = _make_wing(48)
	shaft_tex = _make_shaft()
	glint_tex = _make_glint(32)
	seed_tex = _make_seed(32)

	add_layer = Node2D.new()
	var cm := CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add_layer.material = cm
	add_layer.draw.connect(_draw_add)
	add_child(add_layer)

	# motes: depth d 0 far, 1 mid, 2 near bokeh
	for i in 90:
		motes.append(_mk_mote(0))
	for i in 40:
		motes.append(_mk_mote(1))
	for i in 9:
		motes.append(_mk_mote(2))
	for i in 20:
		var d: float = rng.randf()
		petals.append({
			"p": Vector2(rng.randf_range(-40, W), rng.randf_range(-40, H * 0.85)),
			"d": d, "ph": rng.randf() * TAU, "sp": rng.randf_range(0.6, 1.4),
			"c": [Color(1.0, 0.66, 0.78), Color(1.0, 0.93, 0.95), Color(0.86, 0.68, 0.96)][rng.randi() % 3],
		})
	for i in 6:
		seeds.append({
			"p": Vector2(rng.randf_range(0, W), rng.randf_range(80, H * 0.7)),
			"ph": rng.randf() * TAU, "s": rng.randf_range(0.7, 1.2),
		})
	for i in 40:
		glints.append({
			"p": Vector2(rng.randf_range(230, 760), rng.randf_range(255, 335)),
			"ph": rng.randf() * TAU, "f": rng.randf_range(0.5, 1.6), "s": rng.randf_range(0.5, 1.2),
		})
	for i in 5:
		shafts.append({
			"x": rng.randf_range(-100, 520), "w": rng.randf_range(40, 110),
			"a": rng.randf_range(0.5, 1.0), "ph": rng.randf() * TAU, "f": rng.randf_range(0.15, 0.4),
		})
	# butterflies: 2 depths, kept off the lower-center band
	var cols := [Color(1.0, 0.72, 0.25), Color(0.95, 0.95, 1.0), Color(0.45, 0.7, 1.0), Color(1.0, 0.55, 0.35)]
	for i in 6:
		var far := i >= 3
		flies.append({
			"c": Vector2(rng.randf_range(120, 840), rng.randf_range(210, 440)),
			"rx": rng.randf_range(90, 220), "ry": rng.randf_range(30, 80),
			"f1": rng.randf_range(0.08, 0.17), "f2": rng.randf_range(0.11, 0.23),
			"ph": rng.randf() * TAU, "flap": rng.randf_range(9.0, 13.0),
			"sc": 0.55 if far else 1.0, "col": cols[i % cols.size()],
			"p": Vector2.ZERO, "ang": 0.0,
		})


func _mk_mote(d: int) -> Dictionary:
	var sz: float = [2.6, 5.5, 30.0][d]
	return {
		"p": Vector2(rng.randf_range(0, W), rng.randf_range(0, H)),
		"d": d, "ph": rng.randf() * TAU, "s": sz * rng.randf_range(0.7, 1.3),
		"v": Vector2(rng.randf_range(2, 7), rng.randf_range(-4, 1)) * (1.0 + d * 1.6),
		"tw": rng.randf_range(0.4, 1.4),
	}


func _process(delta: float) -> void:
	t += delta
	for m in motes:
		m.p += m.v * delta + Vector2(0, sin(t * 0.4 + m.ph) * 3.0 * delta)
		if m.p.x > W + 30: m.p.x = -30
		if m.p.y < -30: m.p.y = H + 30
		if m.p.y > H + 30: m.p.y = -30
	for p in petals:
		var k: float = 0.5 + p.d
		p.p += Vector2(14.0 + sin(t * 0.7 + p.ph) * 12.0, 9.0 + cos(t * 0.9 + p.ph) * 4.0) * k * p.sp * delta
		if p.p.x > W + 40 or p.p.y > H + 40:
			p.p = Vector2(rng.randf_range(-120, W * 0.6), rng.randf_range(-60, -10))
	for s in seeds:
		s.p += Vector2(8.0, -2.5 + sin(t * 0.5 + s.ph) * 5.0) * delta
		if s.p.x > W + 20:
			s.p = Vector2(-20, rng.randf_range(80, H * 0.7))
	for f in flies:
		var q: float = t + f.ph
		var np: Vector2 = f.c + Vector2(sin(q * f.f1 * TAU) * f.rx + sin(q * 0.9) * 14.0,
			sin(q * f.f2 * TAU) * f.ry + sin(q * 2.3) * 8.0)
		f.ang = lerp_angle(f.ang, (np - f.p).angle() if f.p != Vector2.ZERO else 0.0, 0.05)
		f.p = np
	add_layer.queue_redraw()
	queue_redraw()


func _draw_add() -> void:
	# sun side light shafts (very subtle, long, slanted from the sun)
	for s in shafts:
		var a: float = (0.5 + 0.5 * sin(t * s.f + s.ph)) * 0.05 * s.a + 0.012
		var top := Vector2(SUN.x + s.x * 0.4, 0)
		add_layer.draw_set_transform(top, 0.55 + s.x * 0.0004, Vector2.ONE)
		add_layer.draw_texture_rect(shaft_tex, Rect2(-s.w * 0.5, 0, s.w, 900.0), false, Color(1.0, 0.82, 0.5, a))
	add_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# motes catch the sun: brighter nearer the sun
	for m in motes:
		var ds: float = m.p.distance_to(SUN)
		var sunk: float = clampf(1.2 - ds / 700.0, 0.2, 1.0)
		var tw: float = 0.55 + 0.45 * sin(t * m.tw * 2.0 + m.ph)
		var col := Color(1.0, 0.84, 0.5, 1.0)
		var a := 0.0
		match m.d:
			0: a = 0.7 * sunk * tw
			1: a = 0.95 * sunk * tw
			2: a = 0.09 + 0.09 * sunk * tw
		# keep the path calm
		if m.p.x > 288 and m.p.x < 672 and m.p.y > 397:
			a *= 0.25
		col.a = a
		var r: float = m.s
		add_layer.draw_texture_rect(glow_tex, Rect2(m.p - Vector2(r, r), Vector2(r, r) * 2.0), false, col)

	# water glints, far river
	for g in glints:
		var v: float = pow(maxf(sin(t * g.f * 2.0 + g.ph), 0.0), 6.0)
		if v < 0.02: continue
		var sz: float = 8.0 * g.s * (0.6 + v * 0.6)
		add_layer.draw_texture_rect(glint_tex, Rect2(g.p - Vector2(sz, sz * 0.5), Vector2(sz * 2, sz)), false, Color(1.0, 0.92, 0.7, v * 0.7))

	# butterfly glints
	for f in flies:
		var pulse: float = 0.5 + 0.5 * sin(t * 3.0 + f.ph)
		var r: float = 11.0 * f.sc
		add_layer.draw_texture_rect(glow_tex, Rect2(f.p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(f.col.r, f.col.g, f.col.b, 0.12 + 0.1 * pulse))

	# dandelion seed halos
	for s in seeds:
		var r: float = 9.0 * s.s
		add_layer.draw_texture_rect(glow_tex, Rect2(s.p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1.0, 0.95, 0.8, 0.12))


func _draw() -> void:
	# petals (alpha), tumbling
	for p in petals:
		var k: float = 0.55 + p.d * 0.9
		var rot: float = t * 1.4 * p.sp + p.ph
		var flip: float = cos(t * 2.1 * p.sp + p.ph)
		var sz: Vector2 = Vector2(13.0, 13.0) * k
		draw_set_transform(p.p, rot, Vector2(1.0, 0.35 + 0.65 * absf(flip)))
		var c: Color = p.c
		c.a = 0.55 + 0.35 * p.d
		draw_texture_rect(petal_tex, Rect2(-sz * 0.5, sz), false, c)

	# dandelion seeds
	for s in seeds:
		var rot: float = sin(t * 0.8 + s.ph) * 0.4 - 0.3
		draw_set_transform(s.p, rot, Vector2.ONE * s.s)
		draw_texture_rect(seed_tex, Rect2(-12, -12, 24, 24), false, Color(1, 0.98, 0.9, 0.85))

	# butterflies
	for f in flies:
		var flap: float = absf(sin(t * f.flap + f.ph))
		var sx: float = 0.15 + 0.85 * flap
		var base: float = f.sc * 17.0
		var c: Color = f.col
		var dark := Color(c.r * 0.45, c.g * 0.4, c.b * 0.4, 0.95)
		var face: float = 1.0 if cos(f.ang) >= 0.0 else -1.0
		var tilt: float = sin(t * 1.7 + f.ph) * 0.15
		for side in [-1.0, 1.0]:
			var sc := Vector2(sx * side * face, 1.0)
			draw_set_transform(f.p, tilt, sc)
			draw_texture_rect(wing_tex, Rect2(base * 0.05, -base * 1.25, base * 1.5, base * 1.0), false, Color(c.r, c.g, c.b, 0.96))
			draw_texture_rect(wing_tex, Rect2(base * 0.1, -base * 1.0, base * 0.7, base * 0.5), false, Color(dark.r, dark.g, dark.b, 0.55))
			draw_texture_rect(wing_tex, Rect2(base * 0.05, -base * 0.1, base * 1.0, base * 0.95), false, Color(c.r * 0.88, c.g * 0.8, c.b * 0.86, 0.94))
			draw_texture_rect(wing_tex, Rect2(base * 0.55, -base * 0.95, base * 0.45, base * 0.4), false, Color(1.0, 1.0, 0.95, 0.5))
		draw_set_transform(f.p, tilt, Vector2.ONE)
		draw_line(Vector2(0, -base * 0.55), Vector2(0, base * 0.6), dark, 2.2 * f.sc)
		draw_line(Vector2(0, -base * 0.55), Vector2(-3 * f.sc, -base * 0.95), dark, 1.0)
		draw_line(Vector2(0, -base * 0.55), Vector2(3 * f.sc, -base * 0.95), dark, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- textures
func _tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


func _make_glow(n: int, power: float) -> ImageTexture:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
			var a := pow(clampf(1.0 - d, 0.0, 1.0), power * 1.5)
			var core := pow(clampf(1.0 - d * 2.2, 0.0, 1.0), 2.0)
			a = clampf(a * 0.8 + core * 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return _tex(img)


func _make_petal(n: int) -> ImageTexture:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n * 2.0 - 1.0
			var v := (y + 0.5) / n * 2.0 - 1.0
			# teardrop: narrower at the top
			var wdt := 0.35 + 0.65 * (v * 0.5 + 0.5)
			var e := (u * u) / (wdt * wdt * 0.8) + v * v
			var a := clampf((1.0 - e) * 6.0, 0.0, 1.0)
			var shade := 0.82 + 0.18 * (v * 0.5 + 0.5)
			img.set_pixel(x, y, Color(shade, shade, shade, a))
	return _tex(img)


func _make_wing(n: int) -> ImageTexture:
	# wing for the +x side: attached at left edge, round tip at right; vein-ish darker rim
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n
			var v := (y + 0.5) / n * 2.0 - 1.0
			var e := pow(u * 1.0 - 0.0, 1.0)
			var rr := Vector2((u - 0.45) / 0.55, v).length()
			var a := clampf((1.0 - rr) * 8.0, 0.0, 1.0) * clampf(u * 12.0, 0.0, 1.0)
			var rim := 1.0 - smoothstep(0.65, 0.97, rr) * 0.55
			var spot := 1.0 - 0.25 * clampf(1.0 - Vector2((u - 0.62) / 0.12, (v + 0.15) / 0.18).length(), 0.0, 1.0)
			var s := rim * spot * (0.85 + 0.15 * u)
			img.set_pixel(x, y, Color(s, s, s, a))
	return _tex(img)


func _make_shaft() -> ImageTexture:
	var wd := 32
	var ht := 64
	var img := Image.create(wd, ht, false, Image.FORMAT_RGBA8)
	for y in ht:
		for x in wd:
			var u := (x + 0.5) / wd * 2.0 - 1.0
			var a := pow(clampf(1.0 - absf(u), 0.0, 1.0), 1.5)
			var f := 1.0 - float(y) / ht
			a *= pow(clampf(f, 0.0, 1.0), 1.4) * smoothstep(0.0, 0.08, 1.0 - f)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return _tex(img)


func _make_glint(n: int) -> ImageTexture:
	# 4-point star, wide horizontally (water glints stretch)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := absf((x + 0.5) / n * 2.0 - 1.0)
			var v := absf((y + 0.5) / n * 2.0 - 1.0)
			var h := pow(clampf(1.0 - u, 0.0, 1.0), 3.0) * clampf(1.0 - v * 7.0, 0.0, 1.0)
			var vt := pow(clampf(1.0 - v, 0.0, 1.0), 3.0) * clampf(1.0 - u * 7.0, 0.0, 1.0)
			var c := pow(clampf(1.0 - Vector2(u, v).length() * 1.6, 0.0, 1.0), 2.0)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(h + vt * 0.7 + c, 0.0, 1.0)))
	return _tex(img)


func _make_seed(n: int) -> ImageTexture:
	# fluffy pappus on a thin stem
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n * 0.5, n * 0.38)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			var a := 0.0
			# radial filaments
			var d := p - c
			var r := d.length()
			if r < n * 0.34 and r > 1.0:
				var ang := atan2(d.y, d.x)
				var fil := pow(absf(sin(ang * 8.0)), 6.0)
				a = maxf(a, fil * (1.0 - r / (n * 0.34)) * 0.9)
			a = maxf(a, clampf(1.0 - r / 2.5, 0.0, 1.0))
			# stem
			if p.y > c.y and p.y < n * 0.92:
				a = maxf(a, clampf(1.0 - absf(p.x - c.x) * 1.8, 0.0, 1.0) * 0.8)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	return _tex(img)
