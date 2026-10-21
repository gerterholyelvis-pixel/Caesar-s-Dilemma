class_name ItemIcons
extends RefCounted
## Procedural glowing artefact icons for all items.
## ItemIcons.draw(ci, id, rect, t, glow) draws the item (unrotated shape from
## ItemDB) filling `rect` (its bounding rect). For rotated items the caller
## should draw_set_transform around the rect. Every icon: <60 draw calls.
## Shared language: ink-glass cell tint, gradient body, gold-white rim light with
## a soft wide under-glow, a scaled inner "echo" of the silhouette (self-similar),
## drifting glints driven by t.

const GOLD := Color(1.0, 0.82, 0.38)
const CYAN := Color(0.40, 0.95, 1.0)
const TEAL := Color(0.10, 0.62, 0.58)
const EMERALD := Color(0.25, 0.90, 0.52)
const VIOLET := Color(0.62, 0.34, 0.98)
const MAGENTA := Color(1.0, 0.32, 0.80)
const LAPIS := Color(0.22, 0.42, 1.0)
const BONE := Color(0.95, 0.91, 0.80)
const INK := Color(0.03, 0.06, 0.09)

const COLORS := {
	"bone_blade": Color(0.96, 0.90, 0.72),
	"shard_axe": Color(0.35, 0.90, 1.0),
	"thorn_dagger": Color(0.35, 0.95, 0.45),
	"crystal_bow": Color(0.55, 0.85, 1.0),
	"lapis_shield": Color(0.28, 0.48, 1.0),
	"reed_buckler": Color(0.20, 0.82, 0.62),
	"whetstone": Color(0.95, 0.78, 0.45),
	"quiver": Color(0.92, 0.62, 0.28),
	"spore_flask": Color(0.85, 0.45, 0.95),
	"healing_bloom": Color(1.0, 0.45, 0.72),
	"sun_shard": Color(1.0, 0.86, 0.35),
	"moss_charm": Color(0.50, 0.85, 0.30),
	"fractal_seed": Color(0.70, 0.40, 1.0),
	"glyph_lens": Color(0.60, 1.0, 0.95),
	"prism_lattice": Color(0.55, 0.95, 1.0),
	"mirror_shard": Color(0.65, 0.88, 0.92),
	"ember_censer": Color(0.95, 0.62, 0.30),
	"void_lantern": Color(0.35, 0.85, 1.0),
	"tide_flute": Color(0.80, 0.90, 0.85),
	"oath_stone": Color(1.0, 0.82, 0.38),
	"cursed_crown": Color(0.60, 0.38, 0.95),
	"hungry_maw": Color(0.78, 0.45, 0.95),
	"echo_bell": Color(0.50, 0.90, 1.0),
	"spiral_shell": Color(0.30, 0.85, 0.75),
	"hollow_idol": Color(0.95, 0.78, 0.40),
	"grafted_heart": Color(0.70, 0.35, 0.95),
}

static var _t := 0.0
static var _g := 0.0
static var _u := 1.0


static func cell_color(id: String) -> Color:
	var v: Variant = COLORS.get(id, Color(0.5, 0.9, 0.8))
	return v


static func draw(ci: CanvasItem, id: String, rect: Rect2, t := 0.0, glow := 0.0) -> void:
	if not COLORS.has(id):
		return
	_t = t
	_g = clampf(glow, 0.0, 1.0)
	var col: Color = cell_color(id)
	var sz: Vector2i = ItemDB.shape_size(id, 0)
	var cell := Vector2(rect.size.x / float(sz.x), rect.size.y / float(sz.y))
	var shape: Array = ItemDB.get_def(id).get("shape", [])
	var pulse: float = 0.5 + 0.5 * sin(t * 1.7 + float(id.length()))
	for cc in shape:
		var v: Vector2i = cc
		var cr := Rect2(rect.position + Vector2(v.x * cell.x, v.y * cell.y), cell).grow(-1.5)
		ci.draw_rect(cr, Color(col.r * 0.12, col.g * 0.16, col.b * 0.2, 0.55))
		var hc: Vector2 = cr.get_center()
		var hr: float = minf(cell.x, cell.y) * 0.5
		ci.draw_circle(hc, hr, Color(col.r, col.g, col.b, 0.05 + 0.05 * pulse + 0.10 * _g))
		ci.draw_circle(hc, hr * 0.55, Color(col.r, col.g, col.b, 0.06 + 0.05 * pulse + 0.10 * _g))
	var q: Rect2 = rect.grow(-minf(rect.size.x, rect.size.y) * 0.05)
	_u = minf(q.size.x, q.size.y)
	match id:
		"bone_blade": _bone_blade(ci, q, col)
		"shard_axe": _shard_axe(ci, q, col)
		"thorn_dagger": _thorn_dagger(ci, q, col)
		"crystal_bow": _crystal_bow(ci, q, col)
		"lapis_shield": _lapis_shield(ci, q, col)
		"reed_buckler": _reed_buckler(ci, q, col)
		"whetstone": _whetstone(ci, q, col)
		"quiver": _quiver(ci, q, col)
		"spore_flask": _spore_flask(ci, q, col)
		"healing_bloom": _healing_bloom(ci, q, col)
		"sun_shard": _sun_shard(ci, q, col)
		"moss_charm": _moss_charm(ci, q, col)
		"fractal_seed": _fractal_seed(ci, q, col)
		"glyph_lens": _glyph_lens(ci, q, col)
		"prism_lattice": _prism_lattice(ci, q, col)
		"mirror_shard": _mirror_shard(ci, q, col)
		"ember_censer": _ember_censer(ci, q, col)
		"void_lantern": _void_lantern(ci, q, col)
		"tide_flute": _tide_flute(ci, q, col)
		"oath_stone": _oath_stone(ci, q, col)
		"cursed_crown": _cursed_crown(ci, q, col)
		"hungry_maw": _hungry_maw(ci, q, col)
		"echo_bell": _echo_bell(ci, q, col)
		"spiral_shell": _spiral_shell(ci, q, col)
		"hollow_idol": _hollow_idol(ci, q, col)
		"grafted_heart": _grafted_heart(ci, q, col)
	# cell rim (glass edge), brighter on hover
	for cc2 in shape:
		var v2: Vector2i = cc2
		var cr2 := Rect2(rect.position + Vector2(v2.x * cell.x, v2.y * cell.y), cell).grow(-1.5)
		ci.draw_rect(cr2, Color(col.r, col.g, col.b, 0.10 + 0.35 * _g), false, 1.0)


# --- helpers -----------------------------------------------------------------

static func _p(q: Rect2, x: float, y: float) -> Vector2:
	return q.position + Vector2(x * q.size.x, y * q.size.y)


static func _pp(q: Rect2, a: Array) -> PackedVector2Array:
	var o := PackedVector2Array()
	for i in range(0, a.size(), 2):
		o.append(q.position + Vector2(float(a[i]) * q.size.x, float(a[i + 1]) * q.size.y))
	return o


static func _vgrad(pts: PackedVector2Array, q: Rect2, top: Color, bot: Color) -> PackedColorArray:
	var o := PackedColorArray()
	for p in pts:
		o.append(top.lerp(bot, clampf((p.y - q.position.y) / maxf(q.size.y, 1.0), 0.0, 1.0)))
	return o


static func _rgrad(pts: PackedVector2Array, c: Vector2, r: float, inner: Color, outer: Color) -> PackedColorArray:
	var o := PackedColorArray()
	for p in pts:
		o.append(inner.lerp(outer, clampf(p.distance_to(c) / maxf(r, 1.0), 0.0, 1.0)))
	return o


static func _rim(c: Color) -> Color:
	return c.lerp(Color(1, 1, 0.9), 0.45 + 0.3 * _g)


static func _line(ci: CanvasItem, a: Vector2, b: Vector2, c: Color, w: float) -> void:
	ci.draw_line(a, b, Color(c.r, c.g, c.b, 0.16 + 0.22 * _g), w * 3.0, true)
	ci.draw_line(a, b, _rim(c), w * (1.0 + 0.3 * _g), true)


static func _loop(ci: CanvasItem, pts: PackedVector2Array, c: Color, w: float) -> void:
	var lp := pts.duplicate()
	lp.append(pts[0])
	ci.draw_polyline(lp, Color(c.r, c.g, c.b, 0.16 + 0.22 * _g), w * 3.0, true)
	ci.draw_polyline(lp, _rim(c), w * (1.0 + 0.3 * _g), true)


## filled gradient polygon + glowing rim + inner echo of the silhouette
static func _body(ci: CanvasItem, pts: PackedVector2Array, cols: PackedColorArray, rim: Color, w: float, echo := 0.62) -> void:
	ci.draw_polygon(pts, cols)
	_loop(ci, pts, rim, w)
	if echo > 0.0:
		var cen := Vector2.ZERO
		for p in pts:
			cen += p
		cen /= float(pts.size())
		var e := PackedVector2Array()
		for p in pts:
			e.append(cen + (p - cen) * echo)
		e.append(e[0])
		ci.draw_polyline(e, Color(rim.r, rim.g, rim.b, 0.30 + 0.2 * _g), 1.0, true)


static func _star(ci: CanvasItem, c: Vector2, r: float, col: Color, a: float) -> void:
	var cc := Color(col.r, col.g, col.b, a)
	ci.draw_line(c - Vector2(r, 0), c + Vector2(r, 0), cc, 1.5, true)
	ci.draw_line(c - Vector2(0, r), c + Vector2(0, r), cc, 1.5, true)
	ci.draw_circle(c, r * 0.28, Color(1, 1, 1, a))


static func _glint(ci: CanvasItem, a: Vector2, b: Vector2, ph: float) -> void:
	var f: float = fposmod(_t * 0.30 + ph, 1.7)
	if f > 1.0:
		return
	_star(ci, a.lerp(b, f), _u * (0.07 + 0.04 * _g), Color(1, 0.97, 0.85), sin(PI * f) * (0.7 + 0.3 * _g))


static func _tri(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([a, b, c]), col)


static func _petals(ci: CanvasItem, c: Vector2, R: float, n: int, rot: float, cin: Color, cout: Color, vein: bool) -> void:
	for i in n:
		var a: float = rot + TAU * float(i) / float(n)
		var d := Vector2(cos(a), sin(a))
		var s := Vector2(-d.y, d.x)
		var pts := PackedVector2Array([c + d * R * 0.15, c + d * R * 0.55 + s * R * 0.30, c + d * R, c + d * R * 0.55 - s * R * 0.30])
		var mid: Color = cin.lerp(cout, 0.5)
		ci.draw_polygon(pts, PackedColorArray([cin, mid, cout, mid]))
		if vein:
			ci.draw_line(c + d * R * 0.22, c + d * R * 0.94, Color(1, 0.9, 0.95, 0.5), 1.0, true)


# --- items -------------------------------------------------------------------

static func _bone_blade(ci: CanvasItem, q: Rect2, c: Color) -> void:
	var pts := _pp(q, [0.52, 0.02, 0.70, 0.18, 0.76, 0.42, 0.70, 0.64, 0.60, 0.70, 0.40, 0.70, 0.30, 0.64, 0.26, 0.42, 0.32, 0.20])
	_body(ci, pts, _vgrad(pts, q, Color(1, 0.97, 0.88), Color(0.30, 0.42, 0.46)), c, 1.6, 0.0)
	# spine of self-similar vertebrae (each smaller toward the tip)
	_line(ci, _p(q, 0.5, 0.06), _p(q, 0.5, 0.68), GOLD, 1.0)
	for i in 5:
		var y: float = 0.16 + float(i) * 0.105
		var r: float = q.size.x * (0.095 - float(i) * 0.012)
		var vp := _p(q, 0.5, y)
		ci.draw_circle(vp, r, Color(0.05, 0.12, 0.15, 0.9))
		ci.draw_arc(vp, r, 0.0, TAU, 14, _rim(c), 1.2, true)
		ci.draw_line(vp - Vector2(r * 1.9, 0), vp + Vector2(r * 1.9, 0), Color(c.r, c.g, c.b, 0.45), 1.0, true)
	# guard with curled ends
	_line(ci, _p(q, 0.14, 0.75), _p(q, 0.86, 0.75), GOLD, 2.0)
	ci.draw_arc(_p(q, 0.14, 0.78), q.size.x * 0.07, -PI * 0.5, PI, 8, _rim(GOLD), 1.4, true)
	ci.draw_arc(_p(q, 0.86, 0.78), q.size.x * 0.07, 0.0, PI * 1.5, 8, _rim(GOLD), 1.4, true)
	# grip with gold wrap, violet pommel
	_line(ci, _p(q, 0.5, 0.76), _p(q, 0.5, 0.91), TEAL, 3.0)
	for i in 3:
		var y2: float = 0.79 + float(i) * 0.045
		ci.draw_line(_p(q, 0.43, y2), _p(q, 0.57, y2 + 0.025), _rim(GOLD), 1.2, true)
	var pc := _p(q, 0.5, 0.955)
	ci.draw_circle(pc, q.size.x * 0.20, Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.25 + 0.2 * _g))
	ci.draw_circle(pc, q.size.x * 0.11, VIOLET.lightened(0.2))
	ci.draw_circle(pc, q.size.x * 0.05, Color(1, 0.9, 1))
	_glint(ci, _p(q, 0.5, 0.08), _p(q, 0.5, 0.66), 0.0)


static func _shard_axe(ci: CanvasItem, q: Rect2, c: Color) -> void:
	# handle through the left column
	_line(ci, _p(q, 0.22, 0.10), _p(q, 0.27, 0.97), Color(0.3, 0.8, 0.75), 5.0)
	_line(ci, _p(q, 0.22, 0.10), _p(q, 0.27, 0.97), GOLD, 1.0)
	# crystal head (lower right)
	var pts := _pp(q, [0.30, 0.44, 0.68, 0.48, 0.97, 0.68, 0.92, 0.94, 0.62, 0.98, 0.30, 0.90])
	var cen := _p(q, 0.60, 0.72)
	_body(ci, pts, _rgrad(pts, cen, q.size.x * 0.42, Color(0.9, 1.0, 1.0), Color(0.10, 0.45, 0.65)), c, 1.6, 0.55)
	for i in pts.size():
		ci.draw_line(cen, pts[i], Color(1, 1, 1, 0.28), 1.0, true)
	# wedge facet shading
	_tri(ci, pts[1], pts[2], cen, Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.35))
	_tri(ci, pts[4], pts[5], cen, Color(0, 0.1, 0.25, 0.35))
	# cap crystal on the handle top
	var cap := _pp(q, [0.22, 0.01, 0.34, 0.12, 0.22, 0.22, 0.10, 0.12])
	_body(ci, cap, _vgrad(cap, q, Color(1, 1, 1), c), c, 1.2, 0.0)
	# drifting shards of the wall it was cut from
	for i in 2:
		var bob: float = sin(_t * 1.4 + float(i) * 2.0) * q.size.y * 0.02
		var sc := _p(q, 0.80 - float(i) * 0.12, 0.16 + float(i) * 0.12) + Vector2(0, bob)
		var sr: float = q.size.x * (0.075 - float(i) * 0.02)
		ci.draw_colored_polygon(PackedVector2Array([sc + Vector2(0, -sr * 1.5), sc + Vector2(sr, 0), sc + Vector2(0, sr * 1.5), sc + Vector2(-sr, 0)]), Color(c.r, c.g, c.b, 0.75))
	_glint(ci, _p(q, 0.35, 0.55), _p(q, 0.94, 0.9), 0.35)


static func _thorn_dagger(ci: CanvasItem, q: Rect2, c: Color) -> void:
	var pts := _pp(q, [0.50, 0.02, 0.66, 0.26, 0.64, 0.55, 0.50, 0.60, 0.36, 0.55, 0.38, 0.26])
	_body(ci, pts, _vgrad(pts, q, Color(0.85, 1.0, 0.7), Color(0.05, 0.40, 0.22)), c, 1.5, 0.0)
	_line(ci, _p(q, 0.50, 0.08), _p(q, 0.50, 0.58), Color(0.9, 1, 0.7), 0.9)
	# thorns, each a miniature of the blade
	_tri(ci, _p(q, 0.65, 0.30), _p(q, 0.86, 0.26), _p(q, 0.64, 0.38), c.lightened(0.2))
	_tri(ci, _p(q, 0.64, 0.46), _p(q, 0.82, 0.46), _p(q, 0.63, 0.53), c.lightened(0.2))
	_tri(ci, _p(q, 0.37, 0.36), _p(q, 0.16, 0.34), _p(q, 0.38, 0.45), c.lightened(0.2))
	# leaf guard
	_tri(ci, _p(q, 0.50, 0.64), _p(q, 0.14, 0.60), _p(q, 0.36, 0.70), EMERALD)
	_tri(ci, _p(q, 0.50, 0.64), _p(q, 0.86, 0.60), _p(q, 0.64, 0.70), EMERALD)
	_line(ci, _p(q, 0.50, 0.66), _p(q, 0.50, 0.90), Color(0.2, 0.55, 0.35), 3.0)
	for i in 3:
		ci.draw_line(_p(q, 0.43, 0.72 + float(i) * 0.06), _p(q, 0.57, 0.75 + float(i) * 0.06), _rim(GOLD), 1.1, true)
	# bud pommel
	var bc := _p(q, 0.5, 0.94)
	ci.draw_circle(bc, q.size.x * 0.12, MAGENTA.darkened(0.2))
	ci.draw_arc(bc, q.size.x * 0.16, PI, TAU, 8, _rim(MAGENTA), 1.2, true)
	# venom drop at the tip
	var dp: float = 0.5 + 0.5 * sin(_t * 2.6)
	ci.draw_circle(_p(q, 0.5, 0.02), q.size.x * (0.07 + 0.04 * dp), Color(MAGENTA.r, MAGENTA.g, MAGENTA.b, 0.35 + 0.3 * dp))
	_glint(ci, _p(q, 0.5, 0.10), _p(q, 0.5, 0.55), 0.5)


static func _crystal_bow(ci: CanvasItem, q: Rect2, c: Color) -> void:
	var arc := PackedVector2Array()
	for i in 17:
		var s: float = float(i) / 16.0
		arc.append(_p(q, 0.28 + 0.52 * sin(PI * s) - 0.0 * s, 0.03 + 0.94 * s))
	ci.draw_polyline(arc, Color(c.r, c.g, c.b, 0.2 + 0.2 * _g), 11.0, true)
	ci.draw_polyline(arc, Color(0.12, 0.35, 0.55), 5.0, true)
	ci.draw_polyline(arc, _rim(c), 1.6, true)
	# faceted crystal beads along the limb, shrinking toward the tips (self-similar)
	for k in [0.5, 0.33, 0.67, 0.18, 0.82]:
		var s2: float = k
		var pc := _p(q, 0.28 + 0.52 * sin(PI * s2), 0.03 + 0.94 * s2)
		var r: float = q.size.x * (0.17 - absf(s2 - 0.5) * 0.18)
		ci.draw_polygon(PackedVector2Array([pc + Vector2(0, -r * 1.3), pc + Vector2(r, 0), pc + Vector2(0, r * 1.3), pc + Vector2(-r, 0)]),
			PackedColorArray([Color(1, 1, 1), c, c.darkened(0.45), c]))
	# the string is a held note
	var strg := PackedVector2Array()
	var amp: float = q.size.x * 0.018 * sin(_t * 9.0)
	for i in 7:
		var s3: float = float(i) / 6.0
		strg.append(_p(q, 0.28, 0.03 + 0.94 * s3) + Vector2(sin(PI * s3) * amp, 0))
	ci.draw_polyline(strg, Color(1.0, 0.95, 0.75, 0.9), 1.2, true)
	# nocked light arrow
	_line(ci, _p(q, 0.30, 0.5), _p(q, 0.95, 0.5), CYAN, 1.1)
	_tri(ci, _p(q, 0.98, 0.5), _p(q, 0.84, 0.46), _p(q, 0.84, 0.54), Color(1, 1, 1))
	_glint(ci, _p(q, 0.3, 0.05), _p(q, 0.3, 0.95), 0.2)


static func _lapis_shield(ci: CanvasItem, q: Rect2, c: Color) -> void:
	var pts := _pp(q, [0.12, 0.10, 0.50, 0.04, 0.88, 0.10, 0.90, 0.48, 0.78, 0.72, 0.50, 0.97, 0.22, 0.72, 0.10, 0.48])
	var cen := _p(q, 0.5, 0.45)
	_body(ci, pts, _rgrad(pts, cen, q.size.x * 0.5, Color(0.28, 0.45, 0.95), Color(0.04, 0.08, 0.35)), GOLD, 2.0, 0.0)
	# nested echoes: the shield contains a smaller shield
	for k in [0.76, 0.52]:
		var e := PackedVector2Array()
		for p in pts:
			e.append(cen + (p - cen) * float(k))
		e.append(e[0])
		ci.draw_polyline(e, Color(GOLD.r, GOLD.g, GOLD.b, 0.65 * float(k) + 0.2), 1.4, true)
	# lapis flecks of pyrite
	for i in 9:
		var a: float = float(i) * 2.399
		var rr: float = 0.12 + 0.34 * fposmod(float(i) * 0.371, 1.0)
		var fp := cen + Vector2(cos(a) * rr * q.size.x * 0.9, sin(a) * rr * q.size.y * 0.8)
		ci.draw_circle(fp, 1.2 + 0.6 * float(i % 3), Color(1, 0.88, 0.5, 0.55 + 0.25 * sin(_t * 2.0 + float(i))))
	# central eye of the shield
	var eye := PackedVector2Array([_p(q, 0.5, 0.26), _p(q, 0.64, 0.45), _p(q, 0.5, 0.64), _p(q, 0.36, 0.45)])
	ci.draw_colored_polygon(eye, Color(0.02, 0.05, 0.2, 0.85))
	_loop(ci, eye, GOLD, 1.4)
	ci.draw_circle(cen, q.size.x * 0.075, Color(CYAN.r, CYAN.g, CYAN.b, 0.5 + 0.3 * sin(_t * 2.2)))
	ci.draw_circle(cen, q.size.x * 0.035, Color(1, 1, 1))
	_glint(ci, _p(q, 0.16, 0.16), _p(q, 0.84, 0.8), 0.1)


static func _ellipse(q: Rect2, cx: float, cy: float, rx: float, ry: float, n: int, k: float) -> PackedVector2Array:
	var o := PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		o.append(_p(q, cx + cos(a) * rx * k, cy + sin(a) * ry * k))
	return o


static func _reed_buckler(ci: CanvasItem, q: Rect2, c: Color) -> void:
	var outer := _ellipse(q, 0.5, 0.5, 0.46, 0.46, 28, 1.0)
	var cen := _p(q, 0.5, 0.5)
	ci.draw_polygon(outer, _rgrad(outer, cen, q.size.y * 0.5, Color(0.55, 0.85, 0.55), Color(0.06, 0.25, 0.22)))
	_loop(ci, outer, c, 1.8)
	# woven rings and spokes (reeds)
	for k in [0.72, 0.46]:
		var rg := _ellipse(q, 0.5, 0.5, 0.46, 0.46, 24, float(k))
		rg.append(rg[0])
		ci.draw_polyline(rg, Color(GOLD.r, GOLD.g, GOLD.b, 0.55), 1.3, true)
	for i in 10:
		var a: float = TAU * float(i) / 10.0 + 0.2
		var d := Vector2(cos(a) * q.size.x * 0.46, sin(a) * q.size.y * 0.46)
		ci.draw_line(cen + d * 0.2, cen + d * 0.98, Color(0.85, 1.0, 0.7, 0.55), 1.0, true)
	# reeds curling past the rim, left and right
	for sgn in [-1.0, 1.0]:
		var bx: float = 0.5 + float(sgn) * 0.46
		ci.draw_polyline(PackedVector2Array([_p(q, bx, 0.62), _p(q, bx + float(sgn) * 0.03, 0.40), _p(q, bx - float(sgn) * 0.01, 0.20)]), _rim(c), 1.6, true)
	# water ripple spreading from the boss
	var f: float = fposmod(_t * 0.5, 1.0)
	var rp := _ellipse(q, 0.5, 0.5, 0.46, 0.46, 20, 0.15 + 0.8 * f)
	rp.append(rp[0])
	ci.draw_polyline(rp, Color(CYAN.r, CYAN.g, CYAN.b, 0.7 * (1.0 - f)), 1.4, true)
	ci.draw_circle(cen, q.size.y * 0.13, Color(0.05, 0.3, 0.28))
	ci.draw_arc(cen, q.size.y * 0.13, 0, TAU, 14, _rim(GOLD), 1.6, true)
	ci.draw_circle(cen, q.size.y * 0.045, CYAN)
	_glint(ci, _p(q, 0.2, 0.25), _p(q, 0.75, 0.8), 0.6)


static func _whetstone(ci: CanvasItem, q: Rect2, c: Color) -> void:
	var side := _pp(q, [0.40, 0.84, 0.84, 0.42, 0.84, 0.52, 0.40, 0.94])
	ci.draw_colored_polygon(side, Color(0.14, 0.12, 0.16))
	var pts := _pp(q, [0.16, 0.62, 0.60, 0.18, 0.86, 0.42, 0.40, 0.84])
	_body(ci, pts, PackedColorArray([Color(0.75, 0.70, 0.78), Color(1, 0.95, 0.85), Color(0.55, 0.50, 0.6), Color(0.35, 0.32, 0.42)]), c, 1.5, 0.0)
	for i in 3:
		var o: float = 0.18 + float(i) * 0.2
		ci.draw_line(pts[0].lerp(pts[1], o), pts[3].lerp(pts[2], o), Color(1, 0.9, 0.7, 0.35), 1.0, true)
	# sparks leap from the honed edge
	var tip := pts[1].lerp(pts[2], 0.5)
	for i in 5:
		var ph: float = fposmod(_t * 1.3 + float(i) * 0.21, 1.0)
		var d := Vector2(0.5 + 0.35 * float(i % 3), -0.7 - 0.12 * float(i)).normalized() * _u * (0.1 + 0.3 * ph)
		var base := tip + Vector2(float(i) * 3.0 - 6.0, 0)
		ci.draw_line(base + d * 0.6, base + d, Color(1.0, 0.85, 0.4, 1.0 - ph), 1.5, true)
	_line(ci, pts[1], pts[2], Color(1, 0.95, 0.7), 1.3)
	_glint(ci, pts[0], pts[2], 0.0)


static func _quiver(ci: CanvasItem, q: Rect2, c: Color) -> void:
	var body := _pp(q, [0.30, 0.40, 0.56, 0.32, 0.78, 0.86, 0.52, 0.95])
	_body(ci, body, PackedColorArray([Color(0.55, 0.30, 0.15), Color(0.7, 0.42, 0.2), Color(0.18, 0.1, 0.14), Color(0.14, 0.08, 0.12)]), c, 1.5, 0.0)
	for t2 in [0.35, 0.7]:
		var f: float = float(t2)
		ci.draw_line(body[0].lerp(body[3], f), body[1].lerp(body[2], f), _rim(GOLD), 1.4, true)
	# three arrows with glowing fletching
	var cols: Array[Color] = [CYAN, MAGENTA, GOLD]
	for i in 3:
		var f2: float = 0.25 + float(i) * 0.25
		var base := body[0].lerp(body[1], f2)
		var tipp := base + Vector2(-0.12 + 0.06 * float(i), -0.34) * q.size.y
		var sw: float = sin(_t * 1.6 + float(i)) * 1.5
		tipp.x += sw
		ci.draw_line(base, tipp, _rim(BONE), 1.4, true)
		var dir := (tipp - base).normalized()
		var nr := Vector2(-dir.y, dir.x) * _u * 0.07
		_tri(ci, tipp, tipp - dir * _u * 0.17 + nr, tipp - dir * _u * 0.17 - nr, cols[i])
		_tri(ci, tipp - dir * _u * 0.1, tipp - dir * _u * 0.27 + nr, tipp - dir * _u * 0.27 - nr, cols[i].darkened(0.25))
	_glint(ci, body[3], body[1], 0.7)


static func _spore_flask(ci: CanvasItem, q: Rect2, c: Color) -> void:
	var bc := _p(q, 0.5, 0.66)
	var br: float = _u * 0.30
	var neck := _pp(q, [0.40, 0.24, 0.60, 0.24, 0.62, 0.42, 0.38, 0.42])
	ci.draw_colored_polygon(neck, Color(0.15, 0.35, 0.4, 0.7))
	ci.draw_circle(bc, br, Color(0.06, 0.12, 0.2, 0.95))
	ci.draw_circle(bc, br * 0.86, Color(0.5, 0.15, 0.6, 0.55))
	ci.draw_circle(bc + Vector2(0, br * 0.25), br * 0.6, Color(EMERALD.r, EMERALD.g, EMERALD.b, 0.35))
	ci.draw_arc(bc, br, 0, TAU, 24, _rim(c), 1.8, true)
	ci.draw_arc(bc, br * 0.6, 0, TAU, 16, Color(c.r, c.g, c.b, 0.4), 1.0, true)  # echo
	ci.draw_line(neck[0], neck[3], _rim(c), 1.5, true)
	ci.draw_line(neck[1], neck[2], _rim(c), 1.5, true)
	# cork
	ci.draw_rect(Rect2(_p(q, 0.38, 0.14), Vector2(q.size.x * 0.24, q.size.y * 0.10)), Color(0.75, 0.55, 0.2))
	ci.draw_rect(Rect2(_p(q, 0.38, 0.14), Vector2(q.size.x * 0.24, q.size.y * 0.10)), _rim(GOLD), false, 1.2)
	# spores orbiting inside, each a tiny copy of the flask glow
	for i in 5:
		var a: float = _t * (0.7 + 0.15 * float(i)) + float(i) * 1.3
		var rr: float = br * (0.2 + 0.1 * float(i % 3) + 0.2)
		var sp := bc + Vector2(cos(a) * rr, sin(a) * rr * 0.8)
		ci.draw_circle(sp, 3.0, Color(0.8, 1.0, 0.6, 0.25))
		ci.draw_circle(sp, 1.4, Color(1, 1, 0.8))
	# a spore slips out of the neck
	var f: float = fposmod(_t * 0.4, 1.0)
	ci.draw_circle(_p(q, 0.5, 0.12) + Vector2(sin(_t * 2.0) * 4.0, -f * _u * 0.12), 2.0, Color(0.8, 1, 0.7, 1.0 - f))
	_glint(ci, bc + Vector2(-br * 0.6, -br * 0.4), bc + Vector2(br * 0.5, br * 0.5), 0.3)


static func _healing_bloom(ci: CanvasItem, q: Rect2, c: Color) -> void:
	var sway: float = sin(_t * 1.1) * q.size.x * 0.03
	var stem := PackedVector2Array()
	for i in 7:
		var s: float = float(i) / 6.0
		stem.append(_p(q, 0.5, 0.98 - s * 0.52) + Vector2(sway * s * s + sin(s * 3.0) * q.size.x * 0.05, 0))
	ci.draw_polyline(stem, Color(EMERALD.r, EMERALD.g, EMERALD.b, 0.25), 9.0, true)
	ci.draw_polyline(stem, Color(0.12, 0.55, 0.3), 3.5, true)
	ci.draw_polyline(stem, _rim(EMERALD), 1.0, true)
	# leaves
	var lb := stem[2]
	ci.draw_colored_polygon(PackedVector2Array([lb, lb + Vector2(-q.size.x * 0.42, -q.size.y * 0.06), lb + Vector2(-q.size.x * 0.12, q.size.y * 0.06)]), Color(0.15, 0.7, 0.4))
	var rb := stem[1]
	ci.draw_colored_polygon(PackedVector2Array([rb, rb + Vector2(q.size.x * 0.42, -q.size.y * 0.06), rb + Vector2(q.size.x * 0.12, q.size.y * 0.06)]), Color(0.15, 0.7, 0.4))
	# bloom: three layers of petals, each layer a smaller rotated copy
	var bc: Vector2 = stem[6] + Vector2(0, -q.size.y * 0.05)
	var R: float = q.size.x * 0.52 * (1.0 + 0.05 * sin(_t * 1.5))
	ci.draw_circle(bc, R * 1.15, Color(c.r, c.g, c.b, 0.12 + 0.12 * _g))
	_petals(ci, bc, R, 8, 0.2 + _t * 0.05, Color(1, 0.8, 0.9), Color(0.95, 0.2, 0.6), true)
	_petals(ci, bc, R * 0.66, 8, 0.2 + PI / 8.0 - _t * 0.07, Color(1, 0.95, 0.8), Color(1.0, 0.45, 0.75), false)
	_petals(ci, bc, R * 0.36, 5, _t * 0.2, Color(1, 1, 0.9), GOLD, false)
	ci.draw_circle(bc, R * 0.12, Color(1, 0.95, 0.7))
	_glint(ci, bc + Vector2(-R, -R * 0.5), bc + Vector2(R, R * 0.5), 0.4)


static func _sun_shard(ci: CanvasItem, q: Rect2, c: Color) -> void:
	var cen := q.get_center()
	var R: float = _u * 0.48
	var pulse: float = 0.5 + 0.5 * sin(_t * 2.4)
	ci.draw_circle(cen, R * 0.95, Color(1, 0.75, 0.2, 0.12 + 0.12 * pulse + 0.15 * _g))
	# slow-turning rays
	for i in 8:
		var a: float = TAU * float(i) / 8.0 + _t * 0.25
		var d := Vector2(cos(a), sin(a))
		ci.draw_line(cen + d * R * 0.5, cen + d * R * (0.95 + 0.1 * pulse), Color(1, 0.9, 0.5, 0.35 + 0.3 * pulse), 1.3, true)
	# faceted star body
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for i in 16:
		var a2: float = TAU * float(i) / 16.0 - PI * 0.5 + 0.0
		var rr: float = R * (0.78 if i % 2 == 0 else 0.34)
		pts.append(cen + Vector2(cos(a2), sin(a2)) * rr)
		cols.append(GOLD.lerp(Color(1, 1, 0.95), 0.1) if i % 2 == 0 else Color(1, 0.97, 0.8))
	ci.draw_polygon(pts, cols)
	_loop(ci, pts, Color(1, 0.9, 0.5), 1.5)
	# inner facets: the shard contains a smaller shard
	var inner := PackedVector2Array()
	for i in 8:
		var a3: float = TAU * float(i) / 8.0 - PI * 0.5 + PI / 8.0 + _t * 0.15
		inner.append(cen + Vector2(cos(a3), sin(a3)) * R * (0.30 if i % 2 == 0 else 0.14))
	ci.draw_colored_polygon(inner, Color(1, 0.65, 0.2, 0.8))
	ci.draw_circle(cen, R * 0.07, Color(1, 1, 1))
	_glint(ci, cen + Vector2(-R, -R) * 0.6, cen + Vector2(R, R) * 0.6, 0.0)


static func _moss_charm(ci: CanvasItem, q: Rect2, c: Color) -> void:
	var cen := _p(q, 0.5, 0.58)
	var R: float = _u * 0.34
	# cord
	ci.draw_polyline(PackedVector2Array([_p(q, 0.28, 0.04), _p(q, 0.5, 0.26), _p(q, 0.72, 0.04)]), Color(0.7, 0.55, 0.3), 1.6, true)
	ci.draw_circle(cen, R * 1.25, Color(c.r, c.g, c.b, 0.10 + 0.12 * _g))
	ci.draw_circle(cen, R, Color(0.05, 0.14, 0.12))
	ci.draw_arc(cen, R, 0, TAU, 28, _rim(GOLD), 2.0, true)
	ci.draw_arc(cen, R * 0.78, 0, TAU, 24, Color(GOLD.r, GOLD.g, GOLD.b, 0.4), 1.0, true)
	# moss spiral growing inward (golden-ratio-like turns)
	var sp := PackedVector2Array()
	for i in 30:
		var f: float = float(i) / 29.0
		var a: float = f * TAU * 2.6 + _t * 0.15
		sp.append(cen + Vector2(cos(a), sin(a)) * R * 0.7 * (1.0 - f * 0.92))
	ci.draw_polyline(sp, Color(c.r, c.g, c.b, 0.25), 6.0, true)
	ci.draw_polyline(sp, c.lightened(0.1), 2.2, true)
	# tufts on the rim
	for i in 6:
		var a2: float = TAU * float(i) / 6.0 + 0.4
		var tp := cen + Vector2(cos(a2), sin(a2)) * R
		ci.draw_circle(tp, 3.2 - float(i % 2), Color(0.35, 0.8, 0.3))
		ci.draw_circle(tp + Vector2(0, -1), 1.2, Color(0.8, 1, 0.6, 0.6 + 0.3 * sin(_t * 2.0 + float(i))))
	ci.draw_circle(cen, R * 0.09, Color(CYAN.r, CYAN.g, CYAN.b, 0.9))
	_glint(ci, cen + Vector2(-R, -R) * 0.6, cen + Vector2(R, R) * 0.6, 0.55)


static func _branch(ci: CanvasItem, p: Vector2, ang: float, ln: float, depth: int, maxd: int, spread: float, sd: float) -> void:
	var a: float = ang + sin(_t * 1.1 + float(depth) * 1.7 + sd) * 0.035
	var e := p + Vector2(sin(a), -cos(a)) * ln
	var f: float = float(depth) / float(maxd)
	var col: Color = VIOLET.lerp(GOLD, f)
	if depth < 2:
		ci.draw_line(p, e, Color(col.r, col.g, col.b, 0.18 + 0.2 * _g), (maxd - depth) * 3.0 + 3.0, true)
	ci.draw_line(p, e, _rim(col), maxf(1.0, float(maxd - depth) * 1.6 + (0.5 if depth == 0 else 0.0)), true)
	if depth + 1 >= maxd:
		ci.draw_circle(e, 3.2, Color(1, 0.95, 0.7))
		ci.draw_circle(e, 5.5, Color(GOLD.r, GOLD.g, GOLD.b, 0.25 + 0.2 * _g))
		return
	_branch(ci, e, a - spread, ln * 0.80, depth + 1, maxd, spread, sd + 1.0)
	_branch(ci, e, a + spread, ln * 0.80, depth + 1, maxd, spread, sd + 2.5)


static func _fractal_seed(ci: CanvasItem, q: Rect2, c: Color) -> void:
	# the tree grows from the seed pod in the stem cell, reaching across the top row
	var base := _p(q, 0.5, 0.86)
	var h: float = q.size.y
	_branch(ci, base, 0.0, h * 0.34, 0, 4, 0.8, 0.0)
	# seed pod
	ci.draw_circle(base, h * 0.22, Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.22 + 0.2 * _g))
	var pod := _ellipse(q, 0.5, 0.88, 0.07, 0.11, 12, 1.0)
	ci.draw_polygon(pod, _rgrad(pod, base, h * 0.2, Color(1, 0.85, 1), Color(0.35, 0.1, 0.6)))
	_loop(ci, pod, MAGENTA, 1.4)
	# pod contains a smaller pod
	ci.draw_arc(base + Vector2(0, h * 0.01), h * 0.05, 0, TAU, 10, Color(1, 0.9, 1, 0.6), 1.0, true)
	_glint(ci, _p(q, 0.12, 0.2), _p(q, 0.88, 0.5), 0.15)


static func _glyph_lens(ci: CanvasItem, q: Rect2, c: Color) -> void:
	var cen := q.get_center()
	var R: float = _u * 0.44
	ci.draw_circle(cen, R * 1.1, Color(c.r, c.g, c.b, 0.10 + 0.1 * _g))
	ci.draw_circle(cen, R, Color(0.04, 0.16, 0.20, 0.95))
	ci.draw_circle(cen + Vector2(-R * 0.15, -R * 0.15), R * 0.8, Color(0.1, 0.42, 0.5, 0.45))
	# concentric self-similar rings
	for i in 3:
		var rr: float = R * (1.0 - float(i) * 0.26)
		ci.draw_arc(cen, rr, 0, TAU, 28 - i * 6, _rim(GOLD if i == 0 else c) if i < 2 else Color(c.r, c.g, c.b, 0.6), 2.2 - float(i) * 0.5, true)
	# 8-point iris, slowly turning
	for i in 8:
		var a: float = TAU * float(i) / 8.0 + _t * 0.2
		var d := Vector2(cos(a), sin(a))
		ci.draw_line(cen + d * R * 0.28, cen + d * R * 0.72, Color(c.r, c.g, c.b, 0.55), 1.0, true)
	# the eye of the lens
	var pr: float = R * (0.17 + 0.03 * sin(_t * 1.8))
	ci.draw_circle(cen, pr * 1.8, Color(CYAN.r, CYAN.g, CYAN.b, 0.25 + 0.2 * _g))
	ci.draw_circle(cen, pr, Color(1, 1, 0.95))
	ci.draw_circle(cen, pr * 0.45, Color(0.05, 0.1, 0.2))
	# glass highlight arcs
	ci.draw_arc(cen, R * 0.86, PI * 1.05, PI * 1.45, 8, Color(1, 1, 1, 0.75), 2.0, true)
	_glint(ci, cen + Vector2(-R, R) * 0.6, cen + Vector2(R, -R) * 0.6, 0.3)


# --- new items (v2 content) --------------------------------------------------

static func _cross(ci: CanvasItem, c: Vector2, r: float, col: Color, depth: int) -> void:
	var a := r * 0.34
	var pts := PackedVector2Array([Vector2(-a, -r), Vector2(a, -r), Vector2(a, -a), Vector2(r, -a), Vector2(r, a), Vector2(a, a), Vector2(a, r), Vector2(-a, r), Vector2(-a, a), Vector2(-r, a), Vector2(-r, -a), Vector2(-a, -a)])
	var cols := PackedColorArray()
	for i in pts.size():
		pts[i] = c + pts[i]
		cols.append(col.lerp(GOLD, 0.5 * float(i % 3) / 2.0).lightened(0.1))
	ci.draw_polygon(pts, cols)
	_loop(ci, pts, col, 1.2)
	if depth > 0:
		for k in 4:
			var d := Vector2.from_angle(k * PI * 0.5)
			_cross(ci, c + d * r * 0.68, r * 0.26, col.lerp(GOLD, 0.4), depth - 1)


static func _prism_lattice(ci: CanvasItem, q: Rect2, c: Color) -> void:
	var cen := q.get_center()
	ci.draw_circle(cen, _u * 0.3, Color(c.r, c.g, c.b, 0.12 + 0.1 * _g))
	_cross(ci, cen, _u * 0.46, c, 1)
	_cross(ci, cen, _u * 0.2, Color(0.2, 0.3, 0.5), 0)
	var ph: float = 0.5 + 0.5 * sin(_t * 2.0)
	ci.draw_circle(cen, _u * 0.05, Color(1, 1, 0.9, 0.6 + 0.4 * ph))
	_glint(ci, _p(q, 0.2, 0.2), _p(q, 0.8, 0.8), 0.3)


static func _mirror_shard(ci: CanvasItem, q: Rect2, c: Color) -> void:
	var pts := _pp(q, [0.5, 0.06, 0.78, 0.38, 0.66, 0.94, 0.34, 0.8, 0.22, 0.34])
	_body(ci, pts, _vgrad(pts, q, Color(0.85, 1.0, 1.0), Color(0.25, 0.5, 0.55)), c, 1.4, 0.0)
	var crack: Color = INK.lightened(0.2)
	_line(ci, _p(q, 0.5, 0.06), _p(q, 0.46, 0.4), crack, 0.8)
	_line(ci, _p(q, 0.46, 0.4), _p(q, 0.62, 0.62), crack, 0.8)
	_line(ci, _p(q, 0.46, 0.4), _p(q, 0.30, 0.58), crack, 0.8)
	var e := _p(q, 0.5, 0.6)
	ci.draw_circle(e, _u * 0.07, Color(INK.r, INK.g, INK.b, 0.8))
	ci.draw_circle(e + Vector2(sin(_t) * _u * 0.015, 0), _u * 0.035, GOLD)
	_glint(ci, _p(q, 0.3, 0.2), _p(q, 0.7, 0.8), 0.0)


static func _ember_censer(ci: CanvasItem, q: Rect2, c: Color) -> void:
	# horizontal 2x1: bowl on the left half, violet-gold smoke glyphs drifting right
	_line(ci, _p(q, 0.25, 0.0), _p(q, 0.25, 0.22), c, 0.9)
	_line(ci, _p(q, 0.25, 0.22), _p(q, 0.12, 0.42), c, 0.7)
	_line(ci, _p(q, 0.25, 0.22), _p(q, 0.38, 0.42), c, 0.7)
	var bowl := PackedVector2Array()
	for i in 13:
		var a: float = PI * float(i) / 12.0
		bowl.append(_p(q, 0.25 + cos(a) * 0.16, 0.42 + sin(a) * 0.38))
	ci.draw_polygon(bowl, _vgrad(bowl, q, Color(0.85, 0.52, 0.2), Color(0.3, 0.15, 0.08)))
	_loop(ci, bowl, GOLD, 1.2)
	ci.draw_circle(_p(q, 0.25, 0.44), _u * 0.07, Color(1, 0.7, 0.3, 0.85))
	var pl := PackedVector2Array()
	for i in 16:
		var f: float = float(i) / 15.0
		pl.append(_p(q, 0.3 + f * 0.62, 0.4 + sin(f * 8.0 - _t * 2.0) * 0.16 * f - f * 0.2))
	ci.draw_polyline(pl, Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.6 + 0.2 * _g), 2.0, true)
	for i in 3:
		var gp := _p(q, 0.5 + 0.17 * float(i), 0.22 + 0.12 * sin(float(i) * 2.0 + _t))
		ci.draw_arc(gp, _u * 0.05, 0, TAU * 0.75, 8, GOLD, 1.0, true)


static func _void_lantern(ci: CanvasItem, q: Rect2, c: Color) -> void:
	var cen := _p(q, 0.25, 0.5)
	ci.draw_circle(cen, _u * 0.3, Color(0, 0, 0, 0.55))
	var body := _pp(q, [0.12, 0.2, 0.38, 0.2, 0.44, 0.5, 0.38, 0.82, 0.12, 0.82, 0.06, 0.5])
	ci.draw_polygon(body, _rgrad(body, cen, _u * 0.3, Color(0.4, 0.9, 1.0), Color(0.02, 0.03, 0.06)))
	_loop(ci, body, c, 1.3)
	_line(ci, _p(q, 0.25, 0.2), _p(q, 0.25, 0.06), c, 0.9)
	ci.draw_arc(_p(q, 0.25, 0.06), _u * 0.05, PI, TAU, 8, GOLD, 1.2, true)
	var pulse: float = 0.5 + 0.5 * sin(_t * 2.6)
	ci.draw_circle(cen, _u * (0.07 + 0.02 * pulse), Color(1, 1, 1, 0.95))
	for i in 6:
		var a: float = TAU * float(i) / 6.0 + _t * 0.3
		ci.draw_line(cen + Vector2.from_angle(a) * _u * 0.2, cen + Vector2.from_angle(a) * _u * 0.1, Color(c.r, c.g, c.b, 0.8), 1.2, true)
	var fp := _p(q, 0.75, 0.84)
	ci.draw_arc(fp, _u * 0.2, 0, TAU, 20, Color(c.r, c.g, c.b, 0.3), 1.5, true)
	ci.draw_arc(fp, _u * 0.12, 0, TAU, 14, Color(c.r, c.g, c.b, 0.5), 1.0, true)
	ci.draw_circle(fp, _u * 0.05, Color(0, 0, 0, 0.9))


static func _tide_flute(ci: CanvasItem, q: Rect2, c: Color) -> void:
	var pts := _pp(q, [0.04, 0.38, 0.96, 0.34, 0.98, 0.5, 0.96, 0.66, 0.04, 0.62, 0.0, 0.5])
	ci.draw_polygon(pts, _vgrad(pts, q, Color(1, 0.97, 0.88), Color(0.7, 0.68, 0.58)))
	_loop(ci, pts, c, 1.2)
	for i in 4:
		var hp := _p(q, 0.30 + 0.17 * float(i), 0.5)
		ci.draw_circle(hp, _u * 0.06, INK)
		for k in 2:
			var ph: float = fposmod(_t * 0.5 + float(i) * 0.25 + float(k) * 0.5, 1.0)
			ci.draw_arc(hp + Vector2(0, -_u * 0.05), _u * (0.08 + 0.22 * ph), PI * 1.15, PI * 1.85, 10, Color(TEAL.r, TEAL.g, TEAL.b, 0.9 * (1.0 - ph)), 1.3, true)
	ci.draw_circle(_p(q, 0.12, 0.5), _u * 0.07, Color(CYAN.r, CYAN.g, CYAN.b, 0.9))
	_glint(ci, _p(q, 0.1, 0.4), _p(q, 0.9, 0.6), 0.2)


static func _oath_stone(ci: CanvasItem, q: Rect2, c: Color) -> void:
	var pts := _pp(q, [0.3, 0.05, 0.7, 0.1, 0.8, 0.45, 0.74, 0.95, 0.26, 0.95, 0.2, 0.5])
	ci.draw_polygon(pts, _vgrad(pts, q, Color(0.2, 0.2, 0.28), Color(0.04, 0.04, 0.08)))
	_loop(ci, pts, Color(0.5, 0.45, 0.6), 1.2)
	var pulse: float = 0.5 + 0.5 * sin(_t * 1.8)
	var seam := PackedVector2Array([_p(q, 0.5, 0.14), _p(q, 0.44, 0.34), _p(q, 0.56, 0.5), _p(q, 0.46, 0.7), _p(q, 0.52, 0.86)])
	ci.draw_polyline(seam, Color(c.r, c.g, c.b, 0.25 + 0.25 * pulse), _u * 0.1, true)
	ci.draw_polyline(seam, Color(1, 0.95, 0.7), 1.6, true)
	ci.draw_circle(_p(q, 0.5, 0.5), _u * 0.2, Color(c.r, c.g, c.b, 0.08 + 0.1 * pulse))
	_glint(ci, _p(q, 0.3, 0.2), _p(q, 0.7, 0.9), 0.5)


static func _cursed_crown(ci: CanvasItem, q: Rect2, c: Color) -> void:
	var pts := _pp(q, [0.04, 0.62, 0.06, 0.14, 0.24, 0.4, 0.38, 0.04, 0.5, 0.36, 0.62, 0.04, 0.76, 0.4, 0.94, 0.14, 0.96, 0.62, 0.86, 0.7, 0.14, 0.7])
	ci.draw_polygon(pts, _vgrad(pts, q, Color(0.16, 0.1, 0.28), Color(0.02, 0.02, 0.05)))
	_loop(ci, pts, c, 1.4)
	_line(ci, _p(q, 0.12, 0.64), _p(q, 0.88, 0.64), GOLD, 1.0)
	for i in 3:
		ci.draw_circle(_p(q, 0.3 + 0.2 * float(i), 0.57), _u * 0.035, CYAN if i == 1 else VIOLET)
	for pp in [Vector2(0.06, 0.12), Vector2(0.94, 0.12), Vector2(0.38, 0.03), Vector2(0.62, 0.03)]:
		ci.draw_circle(_p(q, pp.x, pp.y), _u * 0.03, GOLD)
	for i in 4:
		var ph: float = fposmod(_t * 0.4 + float(i) * 0.27, 1.0)
		var x: float = 0.2 + 0.2 * float(i)
		var dp := _p(q, x, 0.7 + ph * 0.28)
		ci.draw_line(_p(q, x, 0.7), dp, Color(0.02, 0.0, 0.06, 0.8), _u * 0.035, true)
		ci.draw_circle(dp, _u * 0.025, Color(c.r, c.g, c.b, 0.9 * (1.0 - ph)))


static func _hungry_maw(ci: CanvasItem, q: Rect2, c: Color) -> void:
	var gul := _p(q, 0.25, 0.5)
	ci.draw_circle(gul, _u * 0.35, Color(c.r * 0.5, c.g * 0.2, c.b * 0.6, 0.55))
	var up := _pp(q, [0.06, 0.45, 0.1, 0.1, 0.5, 0.02, 0.95, 0.12, 0.9, 0.3, 0.5, 0.28])
	var lo := _pp(q, [0.06, 0.55, 0.1, 0.9, 0.5, 0.98, 0.95, 0.88, 0.9, 0.7, 0.5, 0.72])
	var mouth: float = 0.02 * sin(_t * 2.0)
	for j in 2:
		var pp: PackedVector2Array = up if j == 0 else lo
		ci.draw_polygon(pp, _vgrad(pp, q, Color(0.95, 0.9, 0.78), Color(0.55, 0.5, 0.42)))
		_loop(ci, pp, c, 1.2)
		var sg: float = 1.0 if j == 0 else -1.0
		var ty: float = 0.29 if j == 0 else 0.71
		for i in 4:
			var tx: float = 0.32 + 0.16 * float(i)
			_tri(ci, _p(q, tx - 0.05, ty - sg * 0.02 + mouth), _p(q, tx + 0.05, ty - sg * 0.02 + mouth), _p(q, tx, ty + sg * 0.14 + mouth), Color(1, 0.98, 0.9))
	ci.draw_circle(gul, _u * 0.09, Color(0.2, 0.05, 0.35))
	ci.draw_arc(gul, _u * 0.14, 0, TAU, 12, Color(c.r, c.g, c.b, 0.6), 1.2, true)
	_glint(ci, _p(q, 0.2, 0.1), _p(q, 0.9, 0.9), 0.4)


static func _echo_bell(ci: CanvasItem, q: Rect2, c: Color) -> void:
	for i in 3:
		var ph: float = fposmod(_t * 0.4 + float(i) / 3.0, 1.0)
		var rc := _p(q, 0.3 + 0.5 * ph, 0.3 + 0.5 * ph)
		ci.draw_arc(rc, _u * (0.14 + 0.1 * ph), 0, TAU, 18, Color(c.r, c.g, c.b, 0.55 * (1.0 - ph)), 1.3, true)
	var pts := _pp(q, [0.3, 0.06, 0.4, 0.1, 0.44, 0.3, 0.52, 0.42, 0.56, 0.46, 0.04, 0.46, 0.08, 0.42, 0.16, 0.3, 0.2, 0.1])
	ci.draw_polygon(pts, _vgrad(pts, q, Color(0.85, 1.0, 1.0, 0.9), Color(0.2, 0.55, 0.7, 0.8)))
	_loop(ci, pts, c, 1.3)
	_line(ci, _p(q, 0.3, 0.46), _p(q, 0.3, 0.52), GOLD, 1.2)
	ci.draw_circle(_p(q, 0.3 + sin(_t * 3.0) * 0.02, 0.54), _u * 0.04, GOLD)
	ci.draw_circle(_p(q, 0.3, 0.05), _u * 0.03, GOLD)
	_glint(ci, _p(q, 0.15, 0.1), _p(q, 0.5, 0.45), 0.3)


static func _spiral_shell(ci: CanvasItem, q: Rect2, c: Color) -> void:
	var cen := _p(q, 0.5, 0.52)
	var pl := PackedVector2Array()
	var n := 36
	for i in n + 1:
		var f: float = float(i) / float(n)
		var a: float = f * TAU * 2.4 + 0.5
		var r: float = _u * (0.46 * (1.0 - 0.9 * f) + 0.02)
		pl.append(cen + Vector2(cos(a) * r * 1.25, sin(a) * r * 0.9))
	ci.draw_circle(cen, _u * 0.42, Color(TEAL.r, TEAL.g, TEAL.b, 0.2))
	ci.draw_polyline(pl, Color(c.r, c.g, c.b, 0.25 + 0.2 * _g), _u * 0.16, true)
	ci.draw_polyline(pl, Color(0.1, 0.45, 0.45), _u * 0.07, true)
	ci.draw_polyline(pl, _rim(GOLD), 1.3, true)
	for i in 4:
		ci.draw_line(cen, pl[6 + i * 7], Color(GOLD.r, GOLD.g, GOLD.b, 0.4), 1.0, true)
	ci.draw_circle(pl[n], _u * 0.05, Color(1, 1, 0.9))
	_glint(ci, _p(q, 0.2, 0.2), _p(q, 0.8, 0.8), 0.1)


static func _hollow_idol(ci: CanvasItem, q: Rect2, c: Color) -> void:
	var head := _p(q, 0.5, 0.2)
	var body := _pp(q, [0.5, 0.36, 0.76, 0.46, 0.7, 0.94, 0.3, 0.94, 0.24, 0.46])
	ci.draw_polygon(body, _vgrad(body, q, Color(1, 0.88, 0.5), Color(0.55, 0.38, 0.12)))
	_loop(ci, body, GOLD, 1.3)
	ci.draw_circle(head, _u * 0.15, Color(0.95, 0.78, 0.38))
	ci.draw_arc(head, _u * 0.15, 0, TAU, 14, _rim(GOLD), 1.3, true)
	ci.draw_circle(head + Vector2(-_u * 0.055, 0), _u * 0.035, INK)
	ci.draw_circle(head + Vector2(_u * 0.055, 0), _u * 0.035, INK)
	var hol := _pp(q, [0.5, 0.52, 0.62, 0.62, 0.56, 0.8, 0.44, 0.8, 0.38, 0.62])
	ci.draw_colored_polygon(hol, Color(0.0, 0.0, 0.03))
	_loop(ci, hol, Color(0.45, 0.25, 0.8), 0.9)
	var pulse: float = 0.5 + 0.5 * sin(_t * 1.6)
	ci.draw_circle(_p(q, 0.5, 0.68), _u * 0.03, Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.3 + 0.5 * pulse))
	_glint(ci, _p(q, 0.3, 0.1), _p(q, 0.7, 0.9), 0.6)


static func _grafted_heart(ci: CanvasItem, q: Rect2, c: Color) -> void:
	var cen := _p(q, 0.5, 0.5)
	var pulse: float = 1.0 + 0.05 * sin(_t * 3.0)
	var pts := PackedVector2Array()
	for i in 28:
		var a: float = TAU * float(i) / 28.0
		var hx: float = 16.0 * pow(sin(a), 3.0)
		var hy: float = -(13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a))
		pts.append(cen + Vector2(hx, hy) * _u * 0.027 * pulse)
	ci.draw_circle(cen, _u * 0.4, Color(c.r, c.g, c.b, 0.14 + 0.1 * _g))
	ci.draw_polygon(pts, _rgrad(pts, cen, _u * 0.45, Color(0.85, 0.4, 0.9), Color(0.25, 0.1, 0.45)))
	_loop(ci, pts, c, 1.4)
	for i in 5:
		var sp: Vector2 = cen + Vector2(-0.2 + 0.1 * float(i), -0.12 + 0.06 * float(i)) * _u
		ci.draw_line(sp + Vector2(-3, -3), sp + Vector2(3, 3), Color(1, 0.9, 0.6, 0.9), 1.0, true)
		ci.draw_line(sp + Vector2(3, -3), sp + Vector2(-3, 3), Color(1, 0.9, 0.6, 0.9), 1.0, true)
	_line(ci, _p(q, 0.5, 0.1), _p(q, 0.4, 0.0), EMERALD, 1.0)
	_line(ci, _p(q, 0.6, 0.12), _p(q, 0.74, 0.02), EMERALD, 1.0)
	_line(ci, _p(q, 0.45, 0.9), _p(q, 0.3, 1.0), EMERALD, 1.0)
	_line(ci, _p(q, 0.62, 0.88), _p(q, 0.8, 0.98), EMERALD, 1.0)
	ci.draw_circle(cen + Vector2(-_u * 0.08, -_u * 0.08), _u * 0.05, Color(1, 1, 1, 0.3))
