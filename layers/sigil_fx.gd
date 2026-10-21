extends Node2D

# LAYER: sigil_fx. Orbiting motes with trails, rune fragments, rising light shafts,
# energy arcs, and the sigil's reflection on the cloud deck. Origin = sigil center (r=190).

const GLOW := Color(0.35, 0.65, 1.0)
const CORE := Color(0.8, 0.97, 1.0)
const NMOTE := 46
const NRUNE := 9
const NSHAFT := 11
const TRAIL := 14

var t := 0.0
var soft: GradientTexture2D
var streak: GradientTexture2D
var motes: Array = []
var runes: Array = []
var shafts: Array = []
var arcs: Array = []
var arc_timer := 0.0
var rng := RandomNumberGenerator.new()
var _glyph_cache := {}


func _ready() -> void:
	rng.seed = 7
	var cm := CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = cm
	soft = _radial(128, 2.2)
	streak = _radial(128, 1.4)
	for i in NMOTE:
		motes.append({
			"r": rng.randf_range(215.0, 330.0), "w": rng.randf_range(0.18, 0.5) * (1.0 if rng.randf() > 0.3 else -1.0),
			"ph": rng.randf() * TAU, "tilt": rng.randf_range(0.18, 0.42), "rot": rng.randf_range(-0.5, 0.5),
			"sz": rng.randf_range(0.5, 1.6), "tw": rng.randf() * TAU})
	for i in NRUNE:
		runes.append({
			"r": rng.randf_range(228.0, 292.0), "w": rng.randf_range(0.08, 0.16) * (1.0 if i % 2 == 0 else -1.0),
			"ph": TAU * float(i) / NRUNE + rng.randf() * 0.4, "tilt": 0.3, "rot": 0.0, "seed": rng.randi(),
			"spin": rng.randf_range(-1.0, 1.0), "sz": 1.0, "tw": 0.0})
	for i in NSHAFT:
		shafts.append({"x": rng.randf_range(-150.0, 150.0), "w": rng.randf_range(5.0, 24.0),
			"h": rng.randf_range(160.0, 330.0), "ph": rng.randf() * TAU, "sp": rng.randf_range(0.3, 0.8)})


func _radial(sz: int, power: float) -> GradientTexture2D:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in 9:
		var f := float(i) / 8.0
		offs.append(f)
		cols.append(Color(1, 1, 1, pow(maxf(1.0 - f, 0.0), power) if f < 1.0 else 0.0))
	g.offsets = offs
	g.colors = cols
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = sz
	tex.height = sz
	return tex


func _process(delta: float) -> void:
	t += delta
	arc_timer -= delta
	if arc_timer <= 0.0:
		arc_timer = rng.randf_range(0.07, 0.14)
		_regen_arcs()
	if Engine.get_process_frames() % 3 == 2:
		queue_redraw()


func _orbit(m: Dictionary, tt: float) -> Vector2:
	var a: float = m.ph + m.w * tt
	var p := Vector2(cos(a) * m.r, sin(a) * m.r * m.tilt)
	return p.rotated(m.rot * 0.3)


func _depth(m: Dictionary, tt: float) -> float:
	return sin(m.ph + m.w * tt)


func _regen_arcs() -> void:
	arcs.clear()
	for k in 3:
		var i := rng.randi() % NRUNE
		var j := (i + 1 + rng.randi() % 2) % NRUNE
		if rng.randf() < 0.35:
			continue
		arcs.append({"pts": _bolt(_orbit(runes[i], t), _orbit(runes[j], t), 9, 14.0), "a": rng.randf_range(0.5, 1.0)})
	if rng.randf() < 0.5:
		var p := Vector2.from_angle(rng.randf() * TAU) * 192.0
		arcs.append({"pts": _bolt(p, _orbit(runes[rng.randi() % NRUNE], t), 12, 18.0), "a": 0.8})


func _bolt(p: Vector2, q: Vector2, n: int, amp: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var d := q - p
	var nrm := d.normalized().orthogonal()
	for k in n + 1:
		var f := float(k) / n
		var off := 0.0 if (k == 0 or k == n) else rng.randf_range(-1.0, 1.0) * amp * sin(f * PI)
		pts.append(p + d * f + nrm * off)
	return pts


func _blob(c: Vector2, r: float, col: Color, tex: Texture2D = null) -> void:
	if tex == null:
		tex = soft
	draw_texture_rect(tex, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, col)


func _draw() -> void:
	var pulse := 0.85 + 0.15 * sin(t * 1.6)
	_draw_reflection(pulse)
	_draw_shafts(pulse)
	_draw_motes()
	_draw_runes()
	_draw_arcs()


func _draw_reflection(pulse: float) -> void:
	draw_set_transform(Vector2(0, 62), 0.0, Vector2(1.0, 0.2))
	_blob(Vector2.ZERO, 330.0, Color(0.25, 0.5, 1.0, 0.2 * pulse))
	_blob(Vector2.ZERO, 200.0, Color(0.45, 0.7, 1.0, 0.22 * pulse))
	draw_set_transform(Vector2(0, 38), 0.0, Vector2(1.0, 0.1))
	_blob(Vector2.ZERO, 150.0, Color(0.7, 0.9, 1.0, 0.3 * pulse))
	for i in 26:
		var f := float(i) / 25.0
		var y := 30.0 + f * f * 210.0
		var seg := 0.5 + 0.5 * sin(t * 0.9 + float(i) * 2.37 + sin(float(i) * 1.7) * 3.0)
		var mask := smoothstep(0.15, 0.9, seg)
		var wx := (46.0 + f * 80.0) * (0.7 + 0.5 * sin(float(i) * 5.1))
		var fade := pow(1.0 - f, 1.4)
		var sway := sin(t * 0.6 + float(i) * 0.9) * (3.0 + f * 12.0)
		draw_set_transform(Vector2(sway, y), 0.0, Vector2(1.0, 0.09 + f * 0.05))
		_blob(Vector2.ZERO, wx, Color(0.55, 0.8, 1.0, 0.33 * fade * mask * pulse))
	for m in motes:
		var p := _orbit(m, t)
		if _depth(m, t) > -0.2 and absf(p.x) < 360.0:
			draw_set_transform(Vector2(p.x * 0.9, 55.0 + absf(p.y) * 0.3 + p.y * 0.2), 0.0, Vector2(1.0, 0.25))
			_blob(Vector2.ZERO, 9.0 * m.sz, Color(0.5, 0.78, 1.0, 0.1))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_shafts(pulse: float) -> void:
	for s in shafts:
		var a: float = 0.5 + 0.5 * sin(t * s.sp + s.ph)
		a = a * a
		var w: float = s.w * (0.8 + 0.4 * a)
		var h: float = s.h * (0.85 + 0.3 * a)
		var x: float = s.x + sin(t * 0.2 + s.ph) * 10.0
		var base := Color(0.5, 0.78, 1.0, 0.085 * a * pulse)
		var clear := Color(base, 0.0)
		var y0 := 6.0
		var y1 := -h
		var ym := -h * 0.35
		var core := Color(base, base.a * 1.7)
		draw_polygon(PackedVector2Array([
			Vector2(x - w, y0), Vector2(x - w * 0.5, ym), Vector2(x - w * 0.15, y1),
			Vector2(x + w * 0.15, y1), Vector2(x + w * 0.5, ym), Vector2(x + w, y0)]),
			PackedColorArray([clear, base, clear, clear, base, clear]))
		draw_polygon(PackedVector2Array([
			Vector2(x - w * 0.4, y0), Vector2(x - w * 0.2, ym), Vector2(x, y1 * 0.9),
			Vector2(x + w * 0.2, ym), Vector2(x + w * 0.4, y0)]),
			PackedColorArray([clear, core, clear, core, clear]))
	draw_set_transform(Vector2(0, -60), 0.0, Vector2(0.55, 1.5))
	_blob(Vector2.ZERO, 200.0, Color(0.4, 0.65, 1.0, 0.07 * pulse))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_motes() -> void:
	for m in motes:
		var depth := _depth(m, t)
		var scl := 0.75 + 0.25 * depth
		var tw := 0.65 + 0.35 * sin(t * 2.3 + m.tw)
		var p := _orbit(m, t)
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for k in TRAIL:
			var f := float(k) / (TRAIL - 1)
			pts.append(_orbit(m, t - f * 0.9))
			cols.append(Color(0.55, 0.82, 1.0, 0.45 * pow(1.0 - f, 1.8) * scl * tw))
		draw_polyline_colors(pts, cols, 1.2 * m.sz * scl, true)
		_blob(p, 11.0 * m.sz * scl, Color(0.4, 0.7, 1.0, 0.35 * tw))
		_blob(p, 3.2 * m.sz * scl, Color(0.9, 1.0, 1.0, 0.95 * tw), streak)
		if m.sz > 1.3 and tw > 0.9:
			_blob(p, 4.0, Color(1.6, 1.7, 1.9, 0.9), streak)


func _glyph(seed_v: int) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var segs: Array = []
	var n := 3 + r.randi() % 3
	var prev := Vector2(r.randf_range(-1, 1), r.randf_range(-1, 1))
	for i in n:
		var nx := Vector2(r.randf_range(-1, 1), r.randf_range(-1, 1))
		if r.randf() < 0.3:
			prev = Vector2(r.randf_range(-1, 1), r.randf_range(-1, 1))
		segs.append([prev, nx])
		prev = nx
	return segs


func _draw_runes() -> void:
	for i in NRUNE:
		var m: Dictionary = runes[i]
		var p := _orbit(m, t)
		var scl := 0.8 + 0.2 * _depth(m, t)
		var flick := 0.8 + 0.2 * sin(t * 3.1 + float(i) * 1.9)
		var sd: int = m.seed
		if not _glyph_cache.has(sd):
			_glyph_cache[sd] = _glyph(sd)
		var segs: Array = _glyph_cache[sd]
		var ang: float = t * m.spin * 0.6
		var sz := 9.0 * scl
		_blob(p, 26.0 * scl, Color(0.35, 0.62, 1.0, 0.16 * flick))
		draw_set_transform(p, ang * 0.2, Vector2(1.0, 0.6 + 0.4 * absf(cos(ang))))
		for s in segs:
			draw_line(s[0] * sz, s[1] * sz, Color(GLOW, 0.22 * flick), 4.0, true)
			draw_line(s[0] * sz, s[1] * sz, Color(0.85, 0.98, 1.0, 0.9 * flick), 1.3, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_arc(p, sz * 1.5, 0.0, TAU, 20, Color(GLOW, 0.18 * flick), 1.0, true)


func _draw_arcs() -> void:
	for a in arcs:
		var pts: PackedVector2Array = a.pts
		var k: float = a.a * (0.7 + 0.3 * sin(t * 40.0))
		draw_polyline(pts, Color(0.3, 0.55, 1.0, 0.1 * k), 9.0, true)
		draw_polyline(pts, Color(0.5, 0.75, 1.0, 0.3 * k), 3.5, true)
		draw_polyline(pts, Color(1.3, 1.4, 1.6, 0.95 * k), 1.2, true)
		_blob(pts[0], 10.0, Color(0.6, 0.85, 1.0, 0.35 * k))
		_blob(pts[pts.size() - 1], 10.0, Color(0.6, 0.85, 1.0, 0.35 * k))
