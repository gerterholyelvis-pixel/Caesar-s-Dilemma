extends Node2D

# GARDEN FX: subtle realistic atmosphere over the world. 960x640 design space.
# Soft additive motes (bokeh by depth), drifting seeds, low ground mist wisps, a few fireflies.
# One cached radial-falloff texture, ~90 draw commands, mostly clear of the gameplay band.

const W := 960.0
const H := 640.0

var tex: ImageTexture
var t := 0.0
var motes: Array = []
var seeds: Array = []
var wisps: Array = []
var flies: Array = []


func _ready() -> void:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5).length() / (n * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	tex = ImageTexture.create_from_image(img)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	var rng := RandomNumberGenerator.new()
	rng.seed = 7741
	for i in 60:
		var depth := rng.randf()
		motes.append({"p": Vector2(rng.randf() * W, rng.randf() * H), "d": depth, "ph": rng.randf() * TAU,
			"v": Vector2(rng.randf_range(2.0, 8.0), rng.randf_range(-3.0, 2.0)) * (0.4 + depth)})
	for i in 7:
		seeds.append({"p": Vector2(rng.randf() * W, rng.randf() * H * 0.7), "ph": rng.randf() * TAU, "s": rng.randf_range(0.6, 1.2)})
	for i in 9:
		wisps.append({"x": rng.randf() * W, "y": H * rng.randf_range(0.80, 0.97), "w": rng.randf_range(150.0, 300.0), "ph": rng.randf() * TAU, "v": rng.randf_range(3.0, 9.0)})
	for i in 7:
		flies.append({"c": Vector2(rng.randf_range(0.05, 0.95) * W, rng.randf_range(0.18, 0.5) * H), "ph": rng.randf() * TAU, "r": rng.randf_range(14.0, 34.0), "f": rng.randf_range(0.3, 0.7)})


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _blob(c: Vector2, r: float, col: Color, squash := 1.0) -> void:
	draw_texture_rect(tex, Rect2(c.x - r, c.y - r * squash, r * 2.0, r * 2.0 * squash), false, col)


func _draw() -> void:
	var band := Rect2(W * 0.25, H * 0.55, W * 0.5, H * 0.26)
	for w in wisps:
		var x := fposmod(w.x + t * w.v, W + 600.0) - 300.0
		var y: float = w.y + sin(t * 0.2 + w.ph) * 5.0
		var a := 0.030 + 0.012 * sin(t * 0.25 + w.ph)
		_blob(Vector2(x, y), w.w, Color(0.62, 0.78, 0.80, a), 0.14)
	for m in motes:
		var p: Vector2 = m.p + m.v * t + Vector2(sin(t * 0.4 + m.ph) * 10.0, cos(t * 0.33 + m.ph) * 7.0)
		p.x = fposmod(p.x, W)
		p.y = fposmod(p.y, H)
		var fade := 0.15 if band.has_point(p) else 1.0
		var d: float = m.d
		var r := lerpf(1.1, 7.5, d * d)
		var sparkle := 0.65 + 0.35 * sin(t * (0.8 + d) + m.ph * 3.0)
		var lit := clampf(0.5 + 0.5 * (1.0 - (p.x / W + p.y / H)), 0.25, 1.0)
		var a := lerpf(0.55, 0.07, d) * sparkle * lit * fade
		_blob(p, r, Color(1.0, 0.90, 0.68, a))
	for s in seeds:
		var p := Vector2(fposmod(s.p.x + t * 11.0 * s.s, W + 40.0) - 20.0, s.p.y + sin(t * 0.5 * s.s + s.ph) * 26.0 + t * 3.0 * s.s)
		p.y = fposmod(p.y, H * 0.7)
		_blob(p, 1.6, Color(1.0, 0.95, 0.82, 0.55))
		draw_line(p, p + Vector2(-7.0, -5.0), Color(1.0, 0.95, 0.85, 0.14), 1.0)
	for f in flies:
		var p: Vector2 = f.c + Vector2(sin(t * f.f + f.ph) * f.r, cos(t * f.f * 1.3 + f.ph * 2.0) * f.r * 0.6)
		var pulse := pow(0.5 + 0.5 * sin(t * 0.9 + f.ph * 5.0), 2.0)
		var a := 0.12 + 0.55 * pulse
		_blob(p, 9.0, Color(0.35, 1.0, 0.8, a * 0.22))
		_blob(p, 2.6, Color(0.75, 1.0, 0.9, a))
