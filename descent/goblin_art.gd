extends RefCounted

## Procedural art for the goblin cinematic: a detailed obsidian close-up bust of GRIK (lit by a flickering ember
## from below), the crack network that glows from within, and four ink-and-gold memory vignettes.
## World units: y down, head centre ~ (0,0), skull ~420 wide. The caller sets the draw transform.

const EMBER := Color(1.0, 0.40, 0.10)
const COLD := Color(0.30, 0.38, 0.55)
const BASE := Color(0.018, 0.018, 0.026)
const GOLD := Color(0.96, 0.78, 0.38)
const INK := Color(0.012, 0.010, 0.014)

var t := 0.0
var lit := 1.0                  # ember intensity (flicker)
var lpos := Vector2(-300, 420)  # ember source in world units
var hot := 0.0                  # whole-statue inner heat
var crack_heat := 0.0
var eye := 0.0                  # 0 closed .. 1 open
var smirk := 0.0
var mouth_glow := 0.0
var cracks: Array = []          # {pts, t0, dur, w, ph}
var facets: Array = []          # {pts, ang, ph}

const BAKE_ORG := Vector2(-640.0, -360.0)
const BAKE_SPAN := Vector2(1280.0, 1160.0)
const BAKE_SCALE := 1.25
const SH_BAKE := "res://descent/goblin_bake.gdshader"
const SH_BUST := "res://descent/goblin_bust.gdshader"

var _root: Node2D               # bust + dynamic face parts, carries the caller's camera transform
var _bust: ColorRect
var _dyn: Node2D
var _vps: Array = []
var _bake_mats: Array = []
var _bust_mat: ShaderMaterial
var _seg_tex: ImageTexture
var _crack_dirty := true
var _creating := false


func build(crack_times: Array) -> void:
	_crack_dirty = true
	cracks.clear()
	facets.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	# [origin, heading] - later cracks reach the eyes and mouth
	var origins: Array = [
		[Vector2(20, -215), 1.75], [Vector2(0, 350), -2.0], [Vector2(150, -120), 1.2], [Vector2(-165, 60), 2.4],
		[Vector2(-250, 330), -1.3], [Vector2(20, 255), -1.5], [Vector2(260, 350), -2.0], [Vector2(-10, -60), 1.4],
		[Vector2(-175, -110), 2.8], [Vector2(150, 80), 0.5], [Vector2(-195, -60), 3.1], [Vector2(195, -50), 0.1],
		[Vector2(30, 262), 1.7], [Vector2(-60, -195), 1.3], [Vector2(130, 150), -0.7], [Vector2(-92, -46), 3.6],
		[Vector2(92, -46), -0.4]]
	for k in origins.size():
		var t0: float = crack_times[k % crack_times.size()]
		var o: Vector2 = origins[k][0]
		var ang: float = origins[k][1]
		var pts := PackedVector2Array([o])
		var nseg := rng.randi_range(11, 20)
		var p := o
		var a := ang
		var branches: Array = []
		for i in nseg:
			a += rng.randfn(0.0, 0.34)
			p += Vector2.from_angle(a) * rng.randf_range(14.0, 26.0)
			if not _inside(p):
				break
			pts.append(p)
			if i > 2 and rng.randf() < 0.26:
				branches.append([i, p, a + (rng.randf_range(0.5, 1.0) * (1.0 if rng.randf() < 0.5 else -1.0))])
		if pts.size() < 3:
			continue
		var dur := 0.45 + pts.size() * 0.03
		cracks.append({"pts": pts, "t0": t0, "dur": dur, "w": 2.5, "ph": rng.randf() * 6.28})
		for b in branches:
			var bp := PackedVector2Array([b[1]])
			var q: Vector2 = b[1]
			var ba: float = b[2]
			for j in rng.randi_range(3, 8):
				ba += rng.randfn(0.0, 0.4)
				q += Vector2.from_angle(ba) * rng.randf_range(10.0, 20.0)
				if not _inside(q):
					break
				bp.append(q)
			if bp.size() >= 2:
				var bt0: float = t0 + dur * float(b[0]) / float(pts.size())
				var bdur: float = 0.3 + bp.size() * 0.04
				cracks.append({"pts": bp, "t0": bt0, "dur": bdur, "w": 1.4, "ph": rng.randf() * 6.28})
				# hairline twigs off the branches
				for j in range(1, bp.size() - 1):
					if rng.randf() < 0.45:
						var tq: Vector2 = bp[j]
						var ta: float = rng.randf() * TAU
						var tp := PackedVector2Array([tq])
						for _qq in rng.randi_range(2, 4):
							ta += rng.randfn(0.0, 0.5)
							tq += Vector2.from_angle(ta) * rng.randf_range(6.0, 12.0)
							if not _inside(tq):
								break
							tp.append(tq)
						if tp.size() >= 2:
							cracks.append({"pts": tp, "t0": bt0 + bdur * float(j) / float(bp.size()), "dur": 0.25, "w": 0.9, "ph": rng.randf() * 6.28})
	# glassy facets
	var tries := 0
	while facets.size() < 110 and tries < 3000:
		tries += 1
		var c := Vector2(rng.randf_range(-220, 220), rng.randf_range(-260, 620))
		if not _inside(c):
			continue
		var sz := rng.randf_range(26.0, 66.0)
		var a0 := rng.randf() * TAU
		var tri := PackedVector2Array()
		for i in 3:
			tri.append(c + Vector2.from_angle(a0 + i * 2.1 + rng.randf_range(-0.4, 0.4)) * sz * rng.randf_range(0.6, 1.1))
		facets.append({"pts": tri, "ang": rng.randf() * TAU, "ph": rng.randf() * 6.28})


func _inside(p: Vector2) -> bool:
	var e := Vector2(p.x / 200.0, (p.y + 20.0) / 255.0)
	if e.length_squared() < 1.0:
		return true
	if absf(p.x) < 380.0 and p.y > 250.0 and p.y < 620.0:
		return true
	return absf(p.x) < 120.0 and p.y > 200.0


# --- lighting helpers --------------------------------------------------------------------------
func _shade(pos: Vector2, nrm: Vector2, base: Color, k: float) -> Color:
	var c := base
	var top := clampf(-nrm.y, 0.0, 1.0)
	# two embers: the main one low-left, a fainter one low-right
	for li in 2:
		var lp := lpos if li == 0 else Vector2(-lpos.x * 1.1 + 40.0, lpos.y * 0.9)
		var gain := 1.0 if li == 0 else 0.55
		var ld := (lp - pos).normalized()
		var fall := clampf(1.3 - pos.distance_to(lp) / 1500.0, 0.25, 1.2)
		var f := clampf(nrm.dot(ld), 0.0, 1.0)
		var e := minf(lit, 1.0) * fall * k * gain
		c += EMBER * (pow(f, 2.5) * 0.85 * e)
		c += EMBER * (pow(f, 8.0) * 2.6 * e)
	c += COLD * (top * 0.06 * (0.4 + 0.6 * lit))
	c += Color(0.5, 0.15, 0.03) * (hot * 0.05)
	c.a = 1.0
	return c


## rim-lit solid: dark glassy core, ember catching only the edges that face the light
func _ring(ci: CanvasItem, pts: PackedVector2Array, nrm: PackedVector2Array, base: Color, k: float) -> void:
	var n := pts.size()
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= n
	var inner := PackedVector2Array()
	var icol := PackedColorArray()
	var ocol := PackedColorArray()
	for i in n:
		var oc := _shade(pts[i], nrm[i], base, k)
		ocol.append(oc)
		inner.append(c + (pts[i] - c) * 0.5)
		var ic := base.lerp(oc, 0.22)
		ic.a = 1.0
		icol.append(ic)
	ci.draw_polygon(inner, icol)
	for i in n:
		var j := (i + 1) % n
		ci.draw_polygon(PackedVector2Array([pts[i], pts[j], inner[j], inner[i]]),
			PackedColorArray([ocol[i], ocol[j], icol[j], icol[i]]))
		# glassy edge highlight where the rim faces the ember
		var ld := (lpos - pts[i]).normalized()
		var fc := nrm[i].dot(ld)
		if fc > 0.5 and lit > 0.05:
			var hc := EMBER * ((fc - 0.5) * 2.2 * minf(lit, 1.0) * k)
			hc.r *= 1.6
			hc.g *= 1.4
			hc.a = 0.9
			ci.draw_line(pts[i], pts[j], hc, 2.2)


func _lit_poly(ci: CanvasItem, pts: PackedVector2Array, base: Color, k: float = 1.0) -> void:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	var nr := PackedVector2Array()
	for p in pts:
		var n := (p - c)
		nr.append(n.normalized() if n.length() > 0.01 else Vector2.UP)
	_ring(ci, pts, nr, base, k)


func _blob(ci: CanvasItem, c: Vector2, r: Vector2, base: Color, k: float = 1.0, rot: float = 0.0, segs: int = 20) -> void:
	var pts := PackedVector2Array()
	var nr := PackedVector2Array()
	for i in segs:
		var a := TAU * i / segs
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot))
		nr.append(Vector2(cos(a) / r.x, sin(a) / r.y).normalized().rotated(rot))
	_ring(ci, pts, nr, base, k)


func _tri(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, base: Color, k: float = 1.0) -> void:
	_lit_poly(ci, PackedVector2Array([a, b, c]), base, k)

# --- backdrop: the other statues, almost swallowed by the dark -----------------------------------
func _halo(ci: CanvasItem, c: Vector2, r: Vector2, col: Color, a: float, n: int = 16) -> void:
	for i in n:
		var f := float(i) / float(n)
		var k := 1.0 - f
		_ellipse(ci, c, r * (0.12 + 0.88 * k * k), Color(col.r, col.g, col.b, a / float(n) * (0.6 + 0.8 * f)))


func draw_backdrop(ci: CanvasItem) -> void:
	# a faint cold halo behind the skull separates black glass from the black void; warm floor-glow far below
	_halo(ci, Vector2(40, -90), Vector2(640, 560), Color(0.07, 0.20, 0.32), 0.30)
	_halo(ci, Vector2(0, -150), Vector2(260, 300), Color(0.10, 0.30, 0.42), 0.13)
	_halo(ci, Vector2(-240, 640), Vector2(980, 340), Color(0.95, 0.24, 0.04), 0.16 * lit)
	for s: float in [-1.0, 1.0]:
		var x: float = s * 1250.0
		var pts := PackedVector2Array([Vector2(x - 150, 900), Vector2(x - 120, 100), Vector2(x - 60, -140), Vector2(x, -230),
			Vector2(x + 60, -140), Vector2(x + 120, 100), Vector2(x + 150, 900)])
		var cols := PackedColorArray()
		for p in pts:
			var side := -s * clampf((p.x - x) / 150.0, -1.0, 1.0)     # inner edge catches the glow
			var c := Color(0.006, 0.006, 0.009)
			c += EMBER * (clampf(side, 0.0, 1.0) * 0.06 * lit)
			c += Color(0.10, 0.22, 0.32) * (clampf(-side, 0.0, 1.0) * 0.012)
			c.a = 1.0
			cols.append(c)
		ci.draw_polygon(pts, cols)
		ci.draw_polyline(PackedVector2Array([pts[1], pts[2], pts[3], pts[4], pts[5]]), Color(0.10, 0.22, 0.32, 0.10), 2.0)
	# far pillars
	for i in 6:
		var x := -2400.0 + i * 960.0 + 120.0 * sin(i * 2.7)
		var w := 70.0 + 20.0 * (i % 3)
		ci.draw_rect(Rect2(x, -900, w, 2200), Color(0.008, 0.008, 0.012))
		ci.draw_rect(Rect2(x + w - 3.0, -900, 3.0, 2200), Color(0.04, 0.10, 0.15, 0.7))


# --- the bust: a baked sculpt (goblin_bake.gdshader) lit every frame (goblin_bust.gdshader) -------------
func _find_xf(ci: Node) -> Transform2D:
	var n := ci
	while n != null:
		var v: Variant = n.get("_xf")
		if v is Transform2D:
			return v
		n = n.get_parent()
	return Transform2D.IDENTITY


func _ensure(ci: CanvasItem) -> bool:
	if _root != null and is_instance_valid(_root) and _root.get_parent() == ci:
		return true
	if _creating:
		return false
	_creating = true
	_create.call_deferred(ci)
	return false


func _create(ci: CanvasItem) -> void:
	_creating = false
	if not is_instance_valid(ci) or not ci.is_inside_tree():
		return
	_root = Node2D.new()
	_root.name = "GoblinBust"
	ci.add_child(_root)
	var sz := Vector2i((BAKE_SPAN * BAKE_SCALE).round())
	var bake_shader: Shader = load(SH_BAKE)
	_vps.clear()
	_bake_mats.clear()
	for i in 4:
		var vp := SubViewport.new()
		vp.size = sz
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.msaa_2d = Viewport.MSAA_DISABLED
		var cr := ColorRect.new()
		cr.set_anchors_preset(Control.PRESET_FULL_RECT)
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := ShaderMaterial.new()
		m.shader = bake_shader
		m.set_shader_parameter("pass_id", i)
		m.set_shader_parameter("org", BAKE_ORG)
		m.set_shader_parameter("span", BAKE_SPAN)
		cr.material = m
		vp.add_child(cr)
		_root.add_child(vp)
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		_vps.append(vp)
		_bake_mats.append(m)
	_bust = ColorRect.new()
	_bust.position = BAKE_ORG
	_bust.size = BAKE_SPAN
	_bust.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bust_mat = ShaderMaterial.new()
	_bust_mat.shader = load(SH_BUST)
	_bust_mat.set_shader_parameter("tex_a", _vps[0].get_texture())
	_bust_mat.set_shader_parameter("tex_b", _vps[1].get_texture())
	_bust_mat.set_shader_parameter("tex_c", _vps[2].get_texture())
	_bust_mat.set_shader_parameter("tex_d", _vps[3].get_texture())
	_bust_mat.set_shader_parameter("tex_n", _make_noise())
	_bust_mat.set_shader_parameter("org", BAKE_ORG)
	_bust_mat.set_shader_parameter("span", BAKE_SPAN)
	_bust.material = _bust_mat
	_root.add_child(_bust)
	_dyn = Node2D.new()
	_dyn.draw.connect(_draw_dyn)
	_root.add_child(_dyn)
	_crack_dirty = true
	_upload_cracks()


## crack polylines -> a float segment texture the bake shader turns into a distance + arrival-time field
func _upload_cracks() -> void:
	_crack_dirty = false
	if _vps.size() < 3:
		return
	var segs: Array = []
	for c in cracks:
		var pts: PackedVector2Array = c.pts
		var n := pts.size() - 1
		var cls := clampf((float(c.w) - 1.0) / 1.6, 0.0, 1.0)
		for k in n:
			segs.append([pts[k], pts[k + 1], float(c.t0) + float(c.dur) * float(k) / float(n), float(c.t0) + float(c.dur) * float(k + 1) / float(n), cls])
	var ns := maxi(segs.size(), 1)
	var img := Image.create(ns * 2, 1, false, Image.FORMAT_RGBAF)
	for i in segs.size():
		var s: Array = segs[i]
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		img.set_pixel(i * 2, 0, Color(a.x, a.y, b.x, b.y))
		img.set_pixel(i * 2 + 1, 0, Color(s[2], s[3], s[4], 0.0))
	_seg_tex = ImageTexture.create_from_image(img)
	var m: ShaderMaterial = _bake_mats[2]
	m.set_shader_parameter("seg_tex", _seg_tex)
	m.set_shader_parameter("nseg", segs.size())
	var vp: SubViewport = _vps[2]
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func draw_bust(ci: CanvasItem) -> void:
	if not _ensure(ci):
		return
	if _crack_dirty:
		_upload_cracks()
	var xf := _find_xf(ci)
	_root.transform = xf
	var px := 1.0 / maxf(xf.get_scale().x, 0.01)
	var m := _bust_mat
	m.set_shader_parameter("T", t)
	m.set_shader_parameter("lit", lit)
	m.set_shader_parameter("lpos", lpos)
	m.set_shader_parameter("hot", hot)
	m.set_shader_parameter("crack_heat", crack_heat)
	m.set_shader_parameter("eye", eye)
	m.set_shader_parameter("smirk", smirk)
	m.set_shader_parameter("mouth_glow", mouth_glow)
	m.set_shader_parameter("px", px)
	_dyn.queue_redraw()


func _fill_v(n: int, v: Vector2) -> Array:
	var a := []
	for i in n:
		a.append(v)
	return a


func _hc(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)


# --- eyes ------------------------------------------------------------------------------------
func _almond(E: Vector2, s: float, w: float, up: float, dn: float, n: int = 13) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var u := lerpf(-1.0, 1.0, float(i) / float(n - 1))
		pts.append(E + Vector2(u * w, -u * s * 10.0 - up * pow(maxf(1.0 - u * u, 0.0), 0.8)))
	for i in n:
		var u := lerpf(1.0, -1.0, float(i) / float(n - 1))
		pts.append(E + Vector2(u * w, -u * s * 10.0 + dn * pow(maxf(1.0 - u * u, 0.0), 0.8)))
	return pts


func _draw_eye(ci: CanvasItem, s: float) -> void:
	var E := Vector2(s * 92.0, -46.0)
	var ember := minf(lit, 1.2)
	if eye < 0.03:
		# closed: a carved slit with a chipped lip, a thread of ember leaking through
		var slit := _almond(E, s, 50.0, 2.6, 2.6, 11)
		ci.draw_colored_polygon(slit, Color(0.0, 0.0, 0.0, 0.97))
		var lo := PackedVector2Array()
		var hi := PackedVector2Array()
		for i in 11:
			var u := lerpf(-1.0, 1.0, float(i) / 10.0)
			lo.append(E + Vector2(u * 51.0, -u * s * 10.0 + 4.5 * pow(maxf(1.0 - u * u, 0.0), 0.8)))
			hi.append(E + Vector2(u * 51.0, -u * s * 10.0 - 4.5 * pow(maxf(1.0 - u * u, 0.0), 0.8)))
		var rc := _shade(E + Vector2(0, 6), Vector2(0, 1), Color(0.03, 0.03, 0.04), 1.6)
		rc.a = 0.9
		ci.draw_polyline(lo, rc, 1.6)
		ci.draw_polyline(hi, Color(0.0, 0.0, 0.0, 0.8), 2.4)
		var leak := clampf(hot * 1.2 + crack_heat * 0.2, 0.0, 1.0) * (0.55 + 0.45 * sin(t * 2.3 + s))
		if leak > 0.02:
			var core := PackedVector2Array()
			for i in 9:
				var u := lerpf(-0.7, 0.7, float(i) / 8.0)
				core.append(E + Vector2(u * 50.0, -u * s * 10.0))
			ci.draw_polyline(core, Color(2.4, 0.9, 0.2, 0.45 * leak), 1.2)
		return
	# --- open ---
	var W := 56.0
	var up := 24.0 * eye
	var dn := 15.0 * eye
	# socket shadow so the eyeball reads as inset
	ci.draw_colored_polygon(_almond(E, s, W + 7.0, up + 7.0, dn + 5.0), Color(0.0, 0.0, 0.0, 0.85))
	# eyeball: concentric rings, dark rim to white-hot core
	var ring_cols := [Color(0.75, 0.10, 0.02), Color(1.6, 0.26, 0.04), Color(2.6, 0.8, 0.14), Color(3.4, 1.7, 0.45), Color(4.2, 3.0, 1.4)]
	var ring_sc := [1.0, 0.86, 0.66, 0.44, 0.22]
	for k in 5:
		var sc: float = ring_sc[k]
		ci.draw_colored_polygon(_almond(E, s, W * sc, up * sc, dn * sc), ring_cols[k])
	# radial iris striations
	for i in 16:
		var a := TAU * (float(i) + 0.5) / 16.0
		var d0 := Vector2(cos(a) * 9.0, sin(a) * 8.0 * eye)
		var d1 := Vector2(cos(a) * W * 0.78, sin(a) * 17.0 * eye)
		ci.draw_line(E + d0, E + d1, Color(0.35, 0.04, 0.0, 0.33), 1.1)
	# slit pupil
	var pr := Vector2(2.6 + 3.2 * eye, 19.0 * eye)
	var pp := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pp.append(E + Vector2(cos(a) * pr.x, sin(a) * pr.y))
	ci.draw_colored_polygon(pp, Color(0.012, 0.0, 0.0))
	# lids: heavy brow-side lid with a shadow cast on the eye, thin wet lower lid
	var lid := PackedVector2Array()
	var lidc := PackedColorArray()
	for i in 13:
		var u := lerpf(-1.0, 1.0, float(i) / 12.0)
		var p0 := E + Vector2(u * (W + 7.0), -u * s * 10.0 - (up + 2.0) * pow(maxf(1.0 - u * u, 0.0), 0.8))
		lid.append(p0)
		lidc.append(Color(0.0, 0.0, 0.0, 0.0))
	for i in 13:
		var u := lerpf(1.0, -1.0, float(i) / 12.0)
		var p1 := E + Vector2(u * (W + 7.0), -u * s * 10.0 - (up + 16.0) * pow(maxf(1.0 - u * u, 0.0), 0.8) - 6.0)
		lid.append(p1)
		lidc.append(Color(0.0, 0.0, 0.0, 1.0))
	# the lid polygon is drawn as two strips for a soft inner edge
	for i in 12:
		var j := 25 - i
		var q := PackedVector2Array([lid[i], lid[i + 1], lid[j - 1], lid[j]])
		var qc := PackedColorArray([Color(0, 0, 0, 0.9), Color(0, 0, 0, 0.9), Color(0, 0, 0, 1.0), Color(0, 0, 0, 1.0)])
		ci.draw_polygon(q, qc)
	var shade := PackedVector2Array()
	var shc := PackedColorArray()
	for i in 13:
		var u := lerpf(-1.0, 1.0, float(i) / 12.0)
		shade.append(E + Vector2(u * W * 0.98, -u * s * 10.0 - up * pow(maxf(1.0 - u * u, 0.0), 0.8)))
		shc.append(Color(0, 0, 0, 0.80))
	for i in 13:
		var u := lerpf(1.0, -1.0, float(i) / 12.0)
		shade.append(E + Vector2(u * W * 0.9, -u * s * 10.0 - up * 0.2 * pow(maxf(1.0 - u * u, 0.0), 0.8) + 1.0))
		shc.append(Color(0, 0, 0, 0.0))
	for i in 12:
		var j := 25 - i
		ci.draw_polygon(PackedVector2Array([shade[i], shade[i + 1], shade[j - 1], shade[j]]), PackedColorArray([shc[i], shc[i + 1], shc[j - 1], shc[j]]))
	# rim highlights on the lids
	var rl := _shade(E + Vector2(0, 12), Vector2(0, 1), Color(0.03, 0.03, 0.04), 1.8)
	var lw := PackedVector2Array()
	var uw := PackedVector2Array()
	for i in 13:
		var u := lerpf(-1.0, 1.0, float(i) / 12.0)
		lw.append(E + Vector2(u * W, -u * s * 10.0 + dn * pow(maxf(1.0 - u * u, 0.0), 0.8) + 1.5))
		uw.append(E + Vector2(u * (W + 1.0), -u * s * 10.0 - (up + 1.0) * pow(maxf(1.0 - u * u, 0.0), 0.8)))
	ci.draw_polyline(lw, Color(rl.r, rl.g, rl.b, 0.9), 2.0)
	ci.draw_polyline(uw, Color(0.25, 0.45, 0.65, 0.35 * eye), 1.4)
	# wet catch-lights: cold softbox, warm ember
	ci.draw_circle(E + Vector2(s * -15.0 + 12.0, -8.0 * eye - 3.0), 3.6, Color(2.2, 2.6, 3.0, 0.95 * eye))
	ci.draw_circle(E + Vector2(s * 9.0, 6.0 * eye), 2.0, Color(3.0, 1.6, 0.6, 0.8 * eye * ember))


# --- mouth -----------------------------------------------------------------------------------
func _mouth_y(u: float, my: float, sm: float) -> float:
	var c := lerpf(0.55, -0.9, sm)
	return my + c * u * u * 28.0 - sm * 18.0 * u


## one modelled tooth: two lit halves with a ridge between, dark at the gum, ember / cold rim light, optional chipped tip
func _tooth(ci: CanvasItem, root: Vector2, dir: Vector2, ln: float, wd: float, bend: float, chip: float = 0.0) -> void:
	var perp := Vector2(-dir.y, dir.x)
	var b0 := root - perp * wd * 0.5
	var b1 := root + perp * wd * 0.5
	var tip := root + dir * ln + perp * bend
	if chip > 0.0:
		tip = root + dir * ln * (1.0 - chip) + perp * bend * 0.6
	var m0 := root - perp * wd * 0.44 + dir * ln * 0.46 + perp * bend * 0.45
	var m1 := root + perp * wd * 0.44 + dir * ln * 0.46 + perp * bend * 0.45
	var ld := (lpos - root).normalized()
	var fl := clampf(ld.dot(-perp) * 0.5 + 0.5, 0.0, 1.0)
	var fr := clampf(ld.dot(perp) * 0.5 + 0.5, 0.0, 1.0)
	var li := minf(lit, 1.2)
	var bone := Color(0.62, 0.56, 0.46)
	var glow := EMBER * (mouth_glow * 0.10)
	var cl := _hc(bone, 0.16 + 1.0 * fl * fl) + EMBER * (pow(fl, 3.0) * 0.30 * li) + glow
	var cr := _hc(bone, 0.16 + 1.0 * fr * fr) + EMBER * (pow(fr, 3.0) * 0.30 * li) + glow
	cl.a = 1.0
	cr.a = 1.0
	var root_c := Color(0.025, 0.014, 0.012) + glow * 0.6
	root_c.a = 1.0
	var mid_c := _hc(bone, 0.10) + glow * 0.5
	mid_c.a = 1.0
	var tipcol_l := cl * 1.12
	var tipcol_r := cr * 1.12
	tipcol_l.a = 1.0
	tipcol_r.a = 1.0
	var rc := root
	if chip > 0.0:
		var t0 := tip - perp * wd * 0.12
		var t1 := tip + perp * wd * 0.12
		ci.draw_polygon(PackedVector2Array([b0, m0, t0, rc]), PackedColorArray([root_c, cl, tipcol_l, mid_c]))
		ci.draw_polygon(PackedVector2Array([rc, t0, t1, b1]), PackedColorArray([mid_c, tipcol_r, tipcol_r, root_c]))
		ci.draw_polygon(PackedVector2Array([rc, t0, t1, m1, b1]), PackedColorArray([mid_c, tipcol_r, tipcol_r, cr, root_c]))
	else:
		ci.draw_polygon(PackedVector2Array([b0, m0, tip, rc]), PackedColorArray([root_c, cl, tipcol_l, mid_c]))
		ci.draw_polygon(PackedVector2Array([rc, tip, m1, b1]), PackedColorArray([mid_c, tipcol_r, cr, root_c]))
	# outline, ember rim on the ember side, cold rim on the other
	ci.draw_polyline(PackedVector2Array([b0, m0, tip, m1, b1]), Color(0.0, 0.0, 0.0, 0.85), 1.3)
	var warm := Color(1.9, 0.6, 0.15, 0.75 * li * pow(maxf(fl, fr), 2.0))
	if fl >= fr:
		ci.draw_polyline(PackedVector2Array([b0 + dir * 2.0, m0, tip]), warm, 1.2)
		ci.draw_polyline(PackedVector2Array([m1, tip]), Color(0.35, 0.65, 0.95, 0.14), 1.0)
	else:
		ci.draw_polyline(PackedVector2Array([b1 + dir * 2.0, m1, tip]), warm, 1.2)
		ci.draw_polyline(PackedVector2Array([m0, tip]), Color(0.35, 0.65, 0.95, 0.14), 1.0)
	# centre ridge and a hairline crack on some teeth
	ci.draw_line(rc + dir * ln * 0.15, tip - dir * ln * 0.08, Color(0.0, 0.0, 0.0, 0.35), 1.0)


func _hf(k: int, salt: float = 0.0) -> float:
	return fposmod(sin(float(k) * 12.9898 + salt * 78.233) * 43758.5453, 1.0)


func _draw_mouth(ci: CanvasItem) -> void:
	var my := 170.0
	var W := 142.0 + smirk * 18.0
	var N := 25
	var up := PackedVector2Array()
	var lo := PackedVector2Array()
	var gap := 8.0 + smirk * 50.0
	for i in N:
		var u := lerpf(-1.0, 1.0, float(i) / float(N - 1))
		var y := _mouth_y(u, my, smirk)
		up.append(Vector2(u * W, y))
		lo.append(Vector2(u * W, y + gap * pow(maxf(1.0 - u * u, 0.0), 0.6)))
	var li := minf(lit, 1.2)
	# shadow of the lower jaw below the cut, and the pulled-back cheeks around the corners
	var cav := clampf(0.25 + smirk * 0.75, 0.0, 1.0)
	_halo(ci, Vector2(0, my + 6.0 - smirk * 8.0), Vector2(W * 1.12, 62.0 + smirk * 26.0), Color(0, 0, 0), 0.62 * cav, 10)
	_halo(ci, Vector2(0, my + 30.0), Vector2(W * 0.8, 40.0), Color(0, 0, 0), 0.3 * cav, 6)
	# interior: black throat, ember glow rising from within
	var inside := PackedVector2Array()
	var icols := PackedColorArray()
	var gl := mouth_glow
	for i in N:
		inside.append(up[i])
		icols.append(Color(0.004, 0.0, 0.0, 1.0))
	for i in range(N - 1, -1, -1):
		inside.append(lo[i])
		var u := lerpf(-1.0, 1.0, float(i) / float(N - 1))
		var c := Color(0.004, 0.0, 0.0, 1.0) + Color(1.5, 0.22, 0.03) * (gl * 0.38 * (1.0 - u * u * 0.7))
		c.a = 1.0
		icols.append(c)
	# strips so the gradient follows the mouth curve
	for i in N - 1:
		var j := 2 * N - 1 - i
		ci.draw_polygon(PackedVector2Array([inside[i], inside[i + 1], inside[j - 1], inside[j]]),
			PackedColorArray([icols[i], icols[i + 1], icols[j - 1], icols[j]]))
	# tongue
	if smirk > 0.15:
		var tg := PackedVector2Array()
		for i in 9:
			var u := lerpf(-0.45, 0.45, float(i) / 8.0)
			var yl := _mouth_y(u, my, smirk) + gap * pow(1.0 - u * u, 0.6)
			tg.append(Vector2(u * W, yl + 1.0))
		for i in range(8, -1, -1):
			var u := lerpf(-0.45, 0.45, float(i) / 8.0)
			var yl := _mouth_y(u, my, smirk) + gap * pow(1.0 - u * u, 0.6)
			tg.append(Vector2(u * W * 0.9, yl - gap * 0.38 * (1.0 - u * u) * smoothstep(0.15, 0.7, smirk)))
		ci.draw_colored_polygon(tg, Color(0.10, 0.012, 0.012) + Color(1.0, 0.16, 0.03) * (gl * 0.35))
	# lower teeth (rising), then upper (hanging), tusks last. [u, length, width, bend, chip]
	var fit := 0.55 + 0.45 * clampf(gap / 40.0, 0.0, 1.0)
	var lower_t := [[-0.82, 11.0, 15.0, 2.0, 0.0], [-0.68, 16.0, 18.0, -2.0, 0.0], [-0.36, 14.0, 19.0, 3.0, 0.0], [-0.20, 20.0, 20.0, 0.0, 0.4],
		[-0.04, 13.0, 21.0, -2.0, 0.0], [0.12, 18.0, 20.0, 2.0, 0.0], [0.28, 11.0, 18.0, 4.0, 0.0], [0.70, 15.0, 17.0, -2.0, 0.0], [0.84, 10.0, 13.0, 2.0, 0.0]]
	for tt in lower_t:
		var u: float = tt[0]
		var yl := _mouth_y(u, my, smirk) + gap * pow(1.0 - u * u, 0.6)
		var sl := (_mouth_y(u + 0.02, my, smirk) + gap * pow(1.0 - (u + 0.02) * (u + 0.02), 0.6) - _mouth_y(u - 0.02, my, smirk) - gap * pow(1.0 - (u - 0.02) * (u - 0.02), 0.6)) / (0.04 * W)
		_tooth(ci, Vector2(u * W, yl + 2.0), Vector2(sl, -1.0).normalized(), float(tt[1]) * fit, tt[2], tt[3], tt[4])
	var upper_t := [[-0.88, 12.0, 15.0, 3.0, 0.0], [-0.74, 19.0, 20.0, -3.0, 0.0], [-0.60, 31.0, 20.0, -5.0, 0.0], [-0.44, 16.0, 21.0, 2.0, 0.45],
		[-0.28, 21.0, 23.0, 0.0, 0.0], [-0.10, 17.0, 22.0, 3.0, 0.0], [0.08, 24.0, 23.0, -2.0, 0.0], [0.40, 17.0, 21.0, 2.0, 0.0],
		[0.56, 36.0, 21.0, 5.0, 0.0], [0.72, 19.0, 19.0, -2.0, 0.0], [0.87, 12.0, 14.0, 3.0, 0.0]]
	for tt in upper_t:
		var u: float = tt[0]
		var yu := _mouth_y(u, my, smirk)
		var su := (_mouth_y(u + 0.02, my, smirk) - _mouth_y(u - 0.02, my, smirk)) / (0.04 * W)
		_tooth(ci, Vector2(u * W, yu - 2.0), Vector2(-su, 1.0).normalized(), float(tt[1]) * fit, tt[2], tt[3], tt[4])
	for s: float in [-1.0, 1.0]:
		var ux := s * 0.50
		var yl := _mouth_y(ux, my, smirk) + gap * pow(1.0 - ux * ux, 0.6)
		var h := 56.0 + smirk * 20.0
		_tooth(ci, Vector2(ux * W, yl + 3.0), Vector2(s * 0.12, -1.0).normalized(), h, 24.0, s * 9.0, 0.0)
	# gum shadow along the upper edge, then the cut itself: no lips, a raw beveled slit
	ci.draw_polyline(up, Color(0.12, 0.01, 0.01, 0.55), 5.0)
	ci.draw_polyline(up, Color(0, 0, 0, 0.92), 3.5)
	var hl := _shade(Vector2(0, my - 10), Vector2(0, -1), Color(0.03, 0.03, 0.04), 1.2)
	hl.a = 0.55
	var upl := PackedVector2Array()
	for p in up:
		upl.append(p + Vector2(0, -3.0))
	ci.draw_polyline(upl, hl, 1.4)
	ci.draw_polyline(lo, Color(0, 0, 0, 0.85), 3.0)
	var lol := PackedVector2Array()
	for p in lo:
		lol.append(p + Vector2(0, 3.4))
	var lc := Color(1.0, 0.36, 0.08, 0.20 * li)
	ci.draw_polyline(lol, lc, 1.2)
	# corner creases dig in as the grin grows
	for s: float in [-1.0, 1.0]:
		var c := up[N - 1] if s > 0.0 else up[0]
		var d := (0.6 + 0.8 * smirk)
		for k in 3:
			var o := Vector2(s * (3.0 + k * 6.0), -2.0 - k * 7.0 * d)
			var cr := PackedVector2Array([c + Vector2(s * 4.0, 2.0) + o, c + Vector2(s * 16.0, -10.0 * d) + o, c + Vector2(s * 22.0, -28.0 * d) + o * 0.5])
			ci.draw_polyline(cr, Color(0, 0, 0, 0.75), 2.6 - k * 0.5)
			var cr2 := PackedVector2Array()
			for p in cr:
				cr2.append(p + Vector2(s * 1.5, 2.0))
			ci.draw_polyline(cr2, Color(hl.r, hl.g, hl.b, 0.35), 1.0)


func _draw_dyn() -> void:
	# draws in the camera's world space (the caller's transform lives on the parent node)
	for s: float in [-1.0, 1.0]:
		_draw_eye(_dyn, s)
	_draw_mouth(_dyn)


# --- cracks: the dark side is baked into the shader (goblin_bust.gdshader) --------------------------
func _partial(pts: PackedVector2Array, p: float) -> PackedVector2Array:
	var n := pts.size() - 1
	var f := p * n
	var k := int(floor(f))
	var out := PackedVector2Array()
	for i in mini(k, n) + 1:
		out.append(pts[i])
	if k < n:
		out.append(pts[k].lerp(pts[k + 1], f - k))
	return out


func draw_cracks_dark(_ci: CanvasItem) -> void:
	pass


func draw_glow(ci: CanvasItem) -> void:
	# thin hot cores and burning tips (the soft subsurface glow comes from the shader)
	if hot > 0.01:
		for i in 5:
			var f := 1.0 - float(i) / 5.0
			_ellipse(ci, Vector2(0, 420), Vector2(380, 230) * (0.3 + 0.7 * f), Color(1.0, 0.25, 0.04, hot * 0.003))
	for c in cracks:
		var age := t - float(c.t0)
		var p := clampf(age / c.dur, 0.0, 1.0)
		if p <= 0.0:
			continue
		var pp := _partial(c.pts, p)
		if pp.size() < 2:
			continue
		var b := (0.30 + 0.70 * smoothstep(0.0, 2.5, age)) * (0.30 + 0.70 * crack_heat) * (0.85 + 0.15 * sin(t * 2.1 + c.ph))
		b += exp(-age * 2.2) * 1.6
		var w: float = c.w
		if smirk > 0.02 or eye > 0.02:
			for i in pp.size() - 1:
				var k := _calm((pp[i] + pp[i + 1]) * 0.5)
				ci.draw_line(pp[i], pp[i + 1], Color(1.0, 0.28, 0.04, 0.010 * b * k), w * 6.0)
				ci.draw_line(pp[i], pp[i + 1], Color(3.0, 1.7, 0.5, 0.12 * minf(b, 1.5) * k), w * 0.4)
		else:
			ci.draw_polyline(pp, Color(1.0, 0.28, 0.04, 0.010 * b), w * 6.0)
			ci.draw_polyline(pp, Color(3.0, 1.7, 0.5, 0.12 * minf(b, 1.5)), w * 0.4)
		if p < 1.0:
			var tip := pp[pp.size() - 1]
			ci.draw_circle(tip, 9.0, Color(1.5, 0.7, 0.2, 0.30))
			ci.draw_circle(tip, 3.5, Color(3.0, 2.2, 1.0, 0.9))
	# eye halos and a flare streak
	if eye > 0.02:
		for s: float in [-1.0, 1.0]:
			var E := Vector2(s * 92.0, -46.0)
			for hk in 10:
				var hf := float(hk) / 9.0
				ci.draw_circle(E, lerpf(150.0, 40.0, hf), Color(1.2, 0.45, 0.08, (0.005 + 0.009 * hf) * eye))
			ci.draw_line(E + Vector2(-190, 0), E + Vector2(190, 0), Color(1.0, 0.35, 0.08, 0.05 * eye), 5.0)
			ci.draw_line(E + Vector2(-110, 0), E + Vector2(110, 0), Color(2.0, 0.9, 0.35, 0.10 * eye), 2.0)
	if mouth_glow > 0.01:
		var mc := Vector2(0, 176)
		_ellipse(ci, mc, Vector2(190, 90), Color(1.0, 0.25, 0.04, 0.004 * mouth_glow))
		_ellipse(ci, mc, Vector2(120, 45), Color(1.2, 0.35, 0.05, 0.006 * mouth_glow))
	# the coin pendant and ear ring glow with the gold in the glass
	var gl := smoothstep(0.02, 0.6, hot) * (0.7 + 0.3 * sin(t * 1.7))
	if gl > 0.01:
		ci.draw_circle(Vector2(0, 396), 80.0, Color(1.0, 0.55, 0.12, 0.05 * gl))
		ci.draw_arc(Vector2(0, 396), 38.0, 0.0, TAU, 28, Color(2.6, 1.5, 0.4, 0.8 * gl), 2.5)
		ci.draw_polyline(PackedVector2Array([Vector2(-16, 410), Vector2(-16, 384), Vector2(0, 396), Vector2(16, 384), Vector2(16, 410)]), Color(2.6, 1.5, 0.4, 0.8 * gl), 2.5)
		ci.draw_arc(Vector2(-240, 98), 21.0, 0.0, TAU, 24, Color(2.6, 1.5, 0.4, 0.7 * gl), 2.5)
		ci.draw_circle(Vector2(-240, 98), 40.0, Color(1.0, 0.55, 0.12, 0.04 * gl))


func _ellipse(ci: CanvasItem, c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	ci.draw_colored_polygon(pts, col)


# --- memory vignettes (ink and gold) -------------------------------------------------------------
## kind 0 grave & shovel, 1 the offer (red hat), 2 the fall. p = 0..1 progress, a = alpha, sc = pixel scale (disc r = 300).
func draw_memory(ci: CanvasItem, kind: int, p: float, a: float, center: Vector2, sc: float) -> void:
	if a <= 0.001:
		return
	ci.draw_set_transform(center, 0.0, Vector2(sc, sc))
	# parchment-gold glow disc (radial by stacked circles)
	for i in 40:
		var f := float(i) / 39.0
		ci.draw_circle(Vector2.ZERO, 330.0 * (1.0 - f * 0.94), Color(0.95, 0.62, 0.22, a * 0.022))
	var gold := Color(GOLD.r, GOLD.g, GOLD.b, a)
	var ink := Color(INK.r, INK.g, INK.b, a)
	match kind:
		0: _mem_grave(ci, p, a, gold, ink)
		1: _mem_offer(ci, p, a, gold, ink)
		2: _mem_fall(ci, p, a, gold, ink)
	# ink frame ring
	ci.draw_arc(Vector2.ZERO, 318.0, 0.0, TAU, 80, Color(gold.r, gold.g, gold.b, a * 0.5), 2.0)
	ci.draw_arc(Vector2.ZERO, 326.0, 0.0, TAU, 80, Color(gold.r, gold.g, gold.b, a * 0.25), 1.0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _coin(ci: CanvasItem, c: Vector2, r: float, spin: float, a: float, bright: float = 1.0) -> void:
	var w := maxf(absf(cos(spin)), 0.08)
	var pts := PackedVector2Array()
	for i in 20:
		var an := TAU * i / 20.0
		pts.append(c + Vector2(cos(an) * r * w, sin(an) * r))
	var face := Color(1.5, 1.0, 0.35, a) * bright
	face.a = a
	ci.draw_colored_polygon(pts, face)
	var edge := Color(0.55, 0.32, 0.06, a)
	var cl := pts.duplicate()
	cl.append(pts[0])
	ci.draw_polyline(cl, edge, maxf(r * 0.12, 1.5))
	if w > 0.4:
		var sm := PackedVector2Array()
		for i in 15:
			var an := TAU * i / 14.0
			sm.append(c + Vector2(cos(an) * r * 0.62 * w, sin(an) * r * 0.62))
		ci.draw_polyline(sm, Color(0.6, 0.35, 0.07, a * 0.8), 1.4)
		# stamped glyph: a little crown
		ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.28 * w, r * 0.2), c + Vector2(-r * 0.28 * w, -r * 0.18), c + Vector2(-r * 0.1 * w, 0.0),
			c + Vector2(0, -r * 0.25), c + Vector2(r * 0.1 * w, 0.0), c + Vector2(r * 0.28 * w, -r * 0.18), c + Vector2(r * 0.28 * w, r * 0.2)]), Color(0.5, 0.28, 0.05, a * 0.9), 1.4)
	# glint
	var g := 0.5 + 0.5 * sin(spin * 2.0)
	ci.draw_line(c + Vector2(-r * 0.5, -r * 0.5) * w, c + Vector2(r * 0.3, r * 0.3) * w, Color(2.5, 2.2, 1.6, a * 0.5 * g), 1.5)


func _star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), col, 1.5)
	ci.draw_line(c + Vector2(0, -r), c + Vector2(0, r), col, 1.5)
	ci.draw_line(c + Vector2(-r, -r) * 0.5, c + Vector2(r, r) * 0.5, Color(col.r, col.g, col.b, col.a * 0.6), 1.0)
	ci.draw_line(c + Vector2(r, -r) * 0.5, c + Vector2(-r, r) * 0.5, Color(col.r, col.g, col.b, col.a * 0.6), 1.0)


func _mem_grave(ci: CanvasItem, p: float, a: float, gold: Color, ink: Color) -> void:
	# moon
	ci.draw_circle(Vector2(150, -150), 52.0, Color(1.3, 0.95, 0.5, a * 0.85))
	ci.draw_circle(Vector2(168, -158), 46.0, Color(0.42, 0.27, 0.09, a * 0.9))
	# far hills
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-320, 60), Vector2(-200, 20), Vector2(-60, 50), Vector2(100, 10), Vector2(320, 55), Vector2(320, 140), Vector2(-320, 140)]), Color(0.10, 0.065, 0.03, a))
	# ground
	var ground := PackedVector2Array([Vector2(-320, 124), Vector2(-150, 108), Vector2(0, 118), Vector2(150, 104), Vector2(320, 122), Vector2(320, 320), Vector2(-320, 320)])
	ci.draw_colored_polygon(ground, ink)
	ci.draw_polyline(PackedVector2Array([Vector2(-320, 124), Vector2(-150, 108), Vector2(0, 118), Vector2(150, 104), Vector2(320, 122)]), gold, 2.0)
	# tombstones
	for tb in [[-215.0, 74.0, -0.10], [-95.0, 96.0, 0.06], [215.0, 84.0, 0.12], [150.0, 62.0, -0.05]]:
		var x: float = tb[0]
		var h: float = tb[1]
		var tl: float = tb[2]
		var base := Vector2(x, 116.0)
		var top := base + Vector2(0, -h).rotated(tl)
		var pts := PackedVector2Array([base + Vector2(-26, 0), base + Vector2(-26, 0) + Vector2(0, -h * 0.8).rotated(tl)])
		for i in 9:
			var an := lerpf(PI, TAU, float(i) / 8.0)
			pts.append(top + Vector2(cos(an) * 26.0, sin(an) * 22.0).rotated(tl))
		pts.append(base + Vector2(26, 0))
		ci.draw_colored_polygon(pts, ink)
		var ol := pts.duplicate()
		ci.draw_polyline(ol, gold, 1.6)
		ci.draw_line(top + Vector2(0, 2).rotated(tl), top + Vector2(0, 26).rotated(tl), Color(gold.r, gold.g, gold.b, a * 0.6), 1.4)
		ci.draw_line(top + Vector2(-8, 12).rotated(tl), top + Vector2(8, 12).rotated(tl), Color(gold.r, gold.g, gold.b, a * 0.6), 1.4)
	# open grave
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-40, 116), Vector2(30, 112), Vector2(46, 150), Vector2(-60, 156)]), Color(0, 0, 0, a))
	# dirt mound beside the grave
	var mound := PackedVector2Array()
	for i in 13:
		var u := float(i) / 12.0
		mound.append(Vector2(lerpf(60, 190, u), 114.0 - 46.0 * sin(u * PI) * (0.9 + 0.1 * sin(u * 9.0))))
	ci.draw_colored_polygon(mound, ink)
	ci.draw_polyline(mound, Color(gold.r, gold.g, gold.b, a * 0.8), 1.6)
	# the digger: hooded mortal bent over with a lantern
	var bob := sin(p * 22.0) * 4.0 * smoothstep(0.1, 0.3, p)
	var dg := Vector2(-150, 122)
	ci.draw_colored_polygon(PackedVector2Array([dg + Vector2(-26, 0), dg + Vector2(-30, -50), dg + Vector2(-12, -86 + bob), dg + Vector2(14, -84 + bob), dg + Vector2(26, -44), dg + Vector2(30, 0)]), ink)
	ci.draw_polyline(PackedVector2Array([dg + Vector2(-26, 0), dg + Vector2(-30, -50), dg + Vector2(-12, -86 + bob), dg + Vector2(14, -84 + bob), dg + Vector2(26, -44), dg + Vector2(30, 0)]), Color(gold.r, gold.g, gold.b, a * 0.75), 1.6)
	ci.draw_circle(dg + Vector2(2, -92 + bob), 17.0, ink)
	ci.draw_arc(dg + Vector2(2, -92 + bob), 18.0, PI * 1.05, PI * 1.9, 10, Color(gold.r, gold.g, gold.b, a * 0.8), 1.5)
	# shovel in his hands: handle up, blade in the earth, dirt arcs flying
	var sh := dg + Vector2(34, -40 + bob)
	ci.draw_line(sh + Vector2(26, 160), sh + Vector2(-10, -78), Color(gold.r, gold.g, gold.b, a * 0.9), 9.0)
	ci.draw_line(sh + Vector2(26, 160), sh + Vector2(-10, -78), ink, 6.0)
	ci.draw_arc(sh + Vector2(-16, -86), 14.0, PI, TAU + 0.8, 10, Color(gold.r, gold.g, gold.b, a * 0.9), 3.0)
	ci.draw_colored_polygon(PackedVector2Array([sh + Vector2(16, 118), sh + Vector2(46, 118), sh + Vector2(52, 152), sh + Vector2(32, 176), sh + Vector2(12, 152)]), Color(0.45, 0.28, 0.07, a))
	for i in 7:
		var ph := fmod(p * 1.6 + i * 0.141, 1.0)
		var d0 := sh + Vector2(40, 110)
		var v := Vector2(60 + i * 12.0, -230.0)
		var pos := d0 + v * ph + Vector2(0, 560.0 * ph * ph)
		ci.draw_circle(pos, 3.0, Color(0.7, 0.45, 0.15, a * (1.0 - ph) * 0.9))
	# lantern light
	var lp := dg + Vector2(-48, -10)
	ci.draw_line(dg + Vector2(-22, -40), lp + Vector2(0, -14), Color(gold.r, gold.g, gold.b, a * 0.7), 1.5)
	ci.draw_circle(lp, 60.0, Color(1.4, 0.8, 0.2, a * 0.05))
	ci.draw_circle(lp, 28.0, Color(1.6, 1.0, 0.3, a * 0.10))
	ci.draw_circle(lp, 9.0, Color(3.0, 2.0, 0.7, a))
	# coins gather on the earth one by one: the keeper's tally
	for i in 8:
		var on := smoothstep(0.18 + i * 0.07, 0.24 + i * 0.07, p)
		if on <= 0.0:
			continue
		var cx := lerpf(-10.0, 170.0, float(i) / 7.0)
		var cy := 126.0 + 14.0 * sin(i * 1.7)
		_coin(ci, Vector2(cx, cy - 24.0 * (1.0 - on)), 10.0, 0.0, a * on)
		_star(ci, Vector2(cx + 6, cy - 8), 8.0 * (1.0 - smoothstep(0.0, 0.5, fmod(p * 3.0 + i * 0.3, 1.0))), Color(2.5, 2.0, 1.2, a * on))


func _mem_offer(ci: CanvasItem, p: float, a: float, gold: Color, ink: Color) -> void:
	# drifting dust
	for i in 30:
		var x := -280.0 + fmod(i * 97.3 + p * 25.0 * (1 + i % 3), 560.0)
		var y := -260.0 + fmod(i * 53.1 - p * 18.0 * (1 + i % 2) + 560.0, 520.0)
		ci.draw_circle(Vector2(x, y), 1.4 + (i % 3) * 0.6, Color(1.4, 0.9, 0.4, a * 0.35))
	# the little black angel in his red hat, faceless; breathes and leans in
	var lean := smoothstep(0.1, 0.7, p) * 24.0
	var bx := 60.0 - lean
	var base := Vector2(bx, 190.0)
	var k := 1.4
	var black := Color(0.006, 0.006, 0.01, a)
	var body := PackedVector2Array([Vector2(-14, -2), Vector2(-20, -62), Vector2(-9, -105), Vector2(9, -105), Vector2(20, -62), Vector2(14, -2)])
	var wl := PackedVector2Array([Vector2(-14, -80), Vector2(-62, -120), Vector2(-48, -40)])
	var wr := PackedVector2Array([Vector2(14, -80), Vector2(62, -120), Vector2(48, -40)])
	var flap := 1.0 + 0.04 * sin(p * 14.0)
	for poly in [body, wl, wr]:
		var q := PackedVector2Array()
		for v in poly:
			q.append(base + Vector2(v.x * flap, v.y) * k)
		ci.draw_colored_polygon(q, black)
		var qc := q.duplicate()
		qc.append(q[0])
		ci.draw_polyline(qc, Color(gold.r, gold.g, gold.b, a * 0.55), 1.4)
	var head := base + Vector2(0, -122) * k
	ci.draw_circle(head, 25.0 * k, black)
	ci.draw_arc(head, 25.0 * k, 0.0, TAU, 28, Color(gold.r, gold.g, gold.b, a * 0.6), 1.4)
	# the hat: the only red in the whole memory
	var hp := PackedVector2Array([Vector2(-30, -138), Vector2(-17, -168), Vector2(0, -158), Vector2(17, -168), Vector2(30, -138)])
	var hq := PackedVector2Array()
	for v in hp:
		hq.append(base + v * k)
	var pulse := 0.85 + 0.15 * sin(p * 9.0)
	ci.draw_circle(base + Vector2(0, -152) * k, 66.0, Color(1.5, 0.08, 0.06, a * 0.07 * pulse))
	ci.draw_circle(base + Vector2(0, -152) * k, 34.0, Color(1.6, 0.10, 0.07, a * 0.12 * pulse))
	ci.draw_colored_polygon(hq, Color(1.9, 0.10, 0.10, a))
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-34, -138) * k, base + Vector2(34, -138) * k, base + Vector2(30, -130) * k, base + Vector2(-30, -130) * k]), Color(0.75, 0.04, 0.05, a))
	# the offer: his small hand reaches in from the left, the angel's hand from the right; a coin between
	var reach := smoothstep(0.05, 0.6, p)
	var hx := lerpf(-230.0, -70.0, reach)
	var arm := PackedVector2Array([Vector2(-330, 80), Vector2(-200, 70), Vector2(hx, 40 + 6 * sin(p * 5.0))])
	ci.draw_polyline(arm, black, 18.0)
	ci.draw_polyline(arm, Color(gold.r, gold.g, gold.b, a * 0.3), 1.2)
	var h := Vector2(hx, 40.0)
	for f in 4:
		var fa := -0.5 + f * 0.30
		ci.draw_line(h, h + Vector2(cos(fa), sin(fa)) * 24.0 * (0.8 + 0.2 * float(f % 2)), black, 6.0)
	var ax := lerpf(bx - 18.0, bx - 90.0, reach)
	ci.draw_polyline(PackedVector2Array([base + Vector2(-10, -60) * k, Vector2(ax + 40, 60), Vector2(ax, 50)]), black, 10.0)
	var cp := Vector2((hx + ax) * 0.5 + 6.0, 32.0 + 10.0 * sin(p * 7.0))
	ci.draw_circle(cp, 40.0, Color(1.6, 0.8, 0.2, a * 0.06))
	_coin(ci, cp, 21.0, p * 9.0, a)
	_star(ci, cp + Vector2(10, -12), 14.0 * (0.5 + 0.5 * sin(p * 12.0)), Color(2.8, 2.3, 1.5, a * 0.8))
	# ground line
	ci.draw_line(Vector2(-320, 195), Vector2(320, 195), Color(gold.r, gold.g, gold.b, a * 0.4), 1.5)


func _mem_fall(ci: CanvasItem, p: float, a: float, gold: Color, ink: Color) -> void:
	var glass := smoothstep(0.55, 0.92, p)
	# speed lines streaking upward
	for i in 40:
		var x := -300.0 + fmod(i * 61.7, 600.0)
		var spd := 220.0 + (i % 5) * 90.0
		var y0 := -320.0 + fmod(i * 131.3 + p * spd * 3.0, 700.0)
		var ln := 22.0 + (i % 4) * 14.0
		var ph := 1.0 - 0.6 * glass
		ci.draw_line(Vector2(x, 320.0 - (y0 + 320.0)), Vector2(x, 320.0 - (y0 + 320.0) - ln), Color(gold.r, gold.g, gold.b, a * 0.35 * ph), 1.3)
	# coins streaming upward from his pockets as he drops
	for i in 11:
		var ph := fmod(p * 1.1 + i * 0.093, 1.0)
		var cx := -60.0 + 130.0 * sin(i * 2.3) * (0.4 + ph)
		var cy := 40.0 - 420.0 * ph
		_coin(ci, Vector2(cx, cy), 12.0 + (i % 3) * 3.0, p * 14.0 + i, a * (1.0 - ph) * (1.0 - 0.7 * glass))
	# the red dot of the hat, far above, shrinking
	var hy := -250.0 - 40.0 * p
	ci.draw_circle(Vector2(30, hy), 22.0, Color(1.5, 0.08, 0.06, a * 0.10))
	ci.draw_circle(Vector2(30, hy), 6.0 * (1.0 - 0.4 * p), Color(1.9, 0.12, 0.10, a))
	# the tumbling goblin-to-be
	var c := Vector2(0, 20.0)
	var rot := p * 5.4 + 0.6
	var tr := Transform2D(rot, c) * Transform2D.IDENTITY.scaled(Vector2(1.5, 1.5))
	var ink2 := Color(INK.r, INK.g, INK.b, a)
	var line_col: Color = ink2.lerp(Color(1.8, 2.2, 2.6, a), glass)
	var limbs := [[Vector2(0, -34), Vector2(0, 40)], [Vector2(0, -20), Vector2(-44, -52)], [Vector2(0, -20), Vector2(46, -6)],
		[Vector2(0, 40), Vector2(-30, 86)], [Vector2(0, 40), Vector2(34, 80)]]
	var body := PackedVector2Array([Vector2(-18, -30), Vector2(-24, 10), Vector2(0, 46), Vector2(24, 10), Vector2(18, -30)])
	var bq := PackedVector2Array()
	for v in body:
		bq.append(tr * v)
	ci.draw_colored_polygon(bq, ink2.lerp(Color(0.2, 0.3, 0.4, a * 0.5), glass))
	for l in limbs:
		ci.draw_line(tr * l[0], tr * l[1], Color(gold.r, gold.g, gold.b, a * 0.5), 12.0)
		ci.draw_line(tr * l[0], tr * l[1], ink2.lerp(Color(0.15, 0.25, 0.35, a), glass), 9.0)
	ci.draw_circle(tr * Vector2(0, -50), 20.0, ink2.lerp(Color(0.2, 0.3, 0.4, a * 0.6), glass))
	# pointed ears: the change has begun
	var ears := smoothstep(0.25, 0.6, p)
	ci.draw_colored_polygon(PackedVector2Array([tr * Vector2(-16, -56), tr * Vector2(-16 - 34 * ears, -78 - 6 * ears), tr * Vector2(-10, -42)]), ink2.lerp(line_col, glass))
	ci.draw_colored_polygon(PackedVector2Array([tr * Vector2(16, -56), tr * Vector2(16 + 34 * ears, -78 - 6 * ears), tr * Vector2(10, -42)]), ink2.lerp(line_col, glass))
	# glass: faceted shards and cracking light across the body
	if glass > 0.01:
		var ga := a * glass
		for i in 9:
			var an := TAU * i / 9.0 + rot
			var r0 := 30.0 + 14.0 * sin(i * 3.1)
			var q0 := c + Vector2.from_angle(an) * r0
			var q1 := c + Vector2.from_angle(an + 0.6) * (r0 + 30.0)
			var q2 := c + Vector2.from_angle(an + 1.2) * (r0 + 8.0)
			ci.draw_colored_polygon(PackedVector2Array([q0, q1, q2]), Color(0.5, 0.8, 1.2, ga * 0.22))
			ci.draw_polyline(PackedVector2Array([q0, q1, q2, q0]), Color(2.2, 2.4, 2.6, ga * 0.7), 1.2)
		for i in 6:
			var an := i * 1.05 + rot * 0.5
			ci.draw_line(c, c + Vector2.from_angle(an) * (50.0 + 20.0 * sin(i * 2.0)), Color(3.0, 1.8, 0.6, ga * 0.9), 1.6)
		_star(ci, c + Vector2(12, -50), 22.0 * ga, Color(3.0, 2.8, 2.4, ga))


## 1 = crack light at full, falling to ~0.15 where the smirk / the open eyes need to read
func _calm(p: Vector2) -> float:
	var dm := ((p - Vector2(0.0, 176.0)) / Vector2(200.0, 86.0)).length()
	var de := ((Vector2(absf(p.x), p.y) - Vector2(92.0, -46.0)) / Vector2(78.0, 44.0)).length()
	return (1.0 - smirk * 0.85 * smoothstep(1.0, 0.45, dm)) * (1.0 - eye * 0.8 * smoothstep(1.0, 0.5, de))


## tileable noise, r = fine, g = mid, b = low frequency
func _make_noise() -> ImageTexture:
	var n := 256
	var chans: Array = []
	var freqs := [0.12, 0.05, 0.02]
	for k in 3:
		var nz := FastNoiseLite.new()
		nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		nz.fractal_type = FastNoiseLite.FRACTAL_FBM
		nz.fractal_octaves = 3
		nz.frequency = freqs[k]
		nz.seed = 777 + k * 31
		chans.append(nz.get_seamless_image(n, n, false, false, 0.15, true).get_data())
	var data := PackedByteArray()
	data.resize(n * n * 3)
	for i in n * n:
		data[i * 3] = chans[0][i]
		data[i * 3 + 1] = chans[1][i]
		data[i * 3 + 2] = chans[2][i]
	var img := Image.create_from_data(n, n, false, Image.FORMAT_RGB8, data)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
