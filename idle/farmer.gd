class_name SapFarmer
extends Node2D
## The Sap Farmer: a tall, patient alien gardener. Origin = feet, about 300 px tall (antlers reach ~-340).
## Layered hooded cloak of woven fronds, a yoke with glowing sap jars, a lantern staff, fractal antlers
## whose tips glow. No red anywhere: earthy greens, amber and soft gold, with a teal rim on the shadow side.
## `talk` (0..1) opens the mouth (set to 1 per spoken letter, decays by itself).
## `pose`: "idle", "point" (at the seed, to the right) or "jar" (holds a jar up). `bow` 0..1 bows.

const DEEP := Color(0.045, 0.10, 0.075)
const MOSS := Color(0.10, 0.22, 0.13)
const FERN := Color(0.20, 0.37, 0.17)
const LEAF := Color(0.34, 0.52, 0.22)
const BARK := Color(0.26, 0.19, 0.11)
const BARK_LIT := Color(0.46, 0.34, 0.18)
const AMBER := Color(1.0, 0.72, 0.25)
const GOLD := Color(1.0, 0.88, 0.55)
const SKIN := Color(0.60, 0.66, 0.42)
const HOOD_IN := Color(0.015, 0.03, 0.025)
const RIM_W := Color(1.0, 0.82, 0.45, 0.42)
const RIM_T := Color(0.30, 0.90, 0.75, 0.22)
const MOUTH := Vector2(11, -246)

var t := 0.0
var talk := 0.0
var pose := "idle"
var bow := 0.0
var fade := 1.0          # lantern/eyes brightness multiplier
var _point := 0.0
var _jar := 0.0
var _giftp := 0.0
var _blink := 0.0
var _next_blink := 2.5
var _xp := Vector2.ZERO
var _xr := 0.0
var _xs := Vector2.ONE


func _ready() -> void:
	t = randf() * 10.0


func _process(delta: float) -> void:
	t += delta
	talk = maxf(talk - delta * 7.0, 0.0)
	_point = move_toward(_point, 1.0 if pose == "point" else 0.0, delta * 2.6)
	_giftp = move_toward(_giftp, 1.0 if pose == "gift" else 0.0, delta * 2.6)
	_jar = move_toward(_jar, 1.0 if pose == "jar" else 0.0, delta * 2.6)
	_next_blink -= delta
	if _next_blink < 0.0:
		_blink = 0.16
		_next_blink = randf_range(2.2, 5.0)
	_blink = maxf(_blink - delta, 0.0)
	queue_redraw()


# ---------- helpers ----------

func _bez(a: Vector2, c: Vector2, b: Vector2, u: float) -> Vector2:
	var v := 1.0 - u
	return a * v * v + c * 2.0 * v * u + b * u * u


func _ell(c: Vector2, rx: float, ry: float, n := 22) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _shape(pts: PackedVector2Array, fill: Color, rim := true) -> void:
	draw_colored_polygon(pts, fill)
	if rim:
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, RIM_T, 1.2, true)
		# warm light from the lantern side (right)
		for i in pts.size():
			var a := pts[i]
			var b := pts[(i + 1) % pts.size()]
			var nrm := (b - a).orthogonal().normalized()
			if nrm.x > 0.35 and absf(b.y - a.y) > 0.5:
				draw_line(a, b, RIM_W, 1.4, true)


func _glow(c: Vector2, r: float, col: Color) -> void:
	for i in 7:
		var k := float(i) / 7.0
		draw_circle(c, r * (1.0 - k * 0.85), Color(col, col.a * (0.04 + 0.09 * k)))


func _limb(a: Vector2, b: Vector2, w: float, col: Color) -> void:
	draw_line(a, b, Color(0, 0, 0, 0.35), w + 2.0, true)
	draw_line(a, b, col, w, true)
	draw_circle(b, w * 0.5, col)


func _leaf(base: Vector2, ang: float, len: float, wd: float, col: Color) -> void:
	var d := Vector2.from_angle(ang)
	var n := Vector2(-d.y, d.x)
	var pts := PackedVector2Array([base, base + d * len * 0.35 + n * wd, base + d * len, base + d * len * 0.35 - n * wd])
	draw_colored_polygon(pts, col)
	draw_line(base, base + d * len * 0.92, Color(GOLD, 0.16), 1.0, true)


# a fringe of fronds along a horizontal hem
func _fringe(x0: float, x1: float, y: float, count: int, len: float, col: Color, seed_off: float, sway: float) -> void:
	for i in count:
		var u := (float(i) + 0.5) / count
		var x := lerpf(x0, x1, u)
		var a := PI * 0.5 + sin(t * 1.4 + i * 0.9 + seed_off) * 0.10 + (u - 0.5) * -0.45
		var ll := len * (0.85 + 0.3 * sin(i * 2.7 + seed_off))
		_leaf(Vector2(x + sway, y - 4.0), a, ll, 5.5, col.lerp(LEAF, 0.25 * (0.5 + 0.5 * sin(i * 1.7 + seed_off))))


func _vine(a: Vector2, c: Vector2, b: Vector2, col: Color, buds: int) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		pts.append(_bez(a, c, b, i / 12.0))
	draw_polyline(pts, col, 2.0, true)
	for k in buds:
		var u := (k + 0.7) / (buds + 0.4)
		var p := _bez(a, c, b, u)
		var pulse := 0.65 + 0.35 * sin(t * 2.0 + k * 1.9)
		_glow(p, 7.0, Color(AMBER, 0.7 * pulse * fade))
		draw_circle(p, 1.8, Color(GOLD, 0.9))


# ---------- fractal antlers ----------

func _branch(p: Vector2, ang: float, len: float, depth: int, wd: float, seed_v: float) -> void:
	var a := ang + sin(t * 0.8 + seed_v + depth * 0.9) * 0.028 * float(5 - depth)
	var q := p + Vector2.from_angle(a) * len
	draw_line(p, q, BARK, wd + 1.6, true)
	draw_line(p, q, BARK_LIT, maxf(wd - 0.4, 0.8), true)
	if depth <= 0:
		var pulse := 0.6 + 0.4 * sin(t * 2.3 + seed_v * 3.1 + q.x * 0.05)
		_glow(q, 11.0, Color(GOLD.lerp(Color(0.6, 1.0, 0.9), 0.3 * sin(seed_v * 7.0) * 0.5 + 0.2), 0.85 * pulse * fade))
		draw_circle(q, 2.4, Color(1.0, 0.97, 0.8, 0.95))
		return
	var nl := len * 0.70
	_branch(q, a - 0.52, nl, depth - 1, wd * 0.72, seed_v * 1.31 + 1.0)
	_branch(q, a + 0.46, nl, depth - 1, wd * 0.72, seed_v * 1.17 + 2.0)
	if depth > 2:
		_branch(q, a + 0.04, nl * 0.9, depth - 1, wd * 0.72, seed_v + 3.0)


# ---------- jars ----------

func _jar_draw(c: Vector2, size: float, glow_amt: float, ang := 0.0) -> void:
	draw_set_transform(_xp + Transform2D(_xr, Vector2.ZERO).basis_xform(c * _xs), ang + _xr, _xs)
	var w := size
	var h := size * 1.25
	var body := PackedVector2Array([
		Vector2(-w * 0.45, -h * 0.35), Vector2(-w * 0.62, 0.0), Vector2(-w * 0.5, h * 0.45), Vector2(0, h * 0.55),
		Vector2(w * 0.5, h * 0.45), Vector2(w * 0.62, 0.0), Vector2(w * 0.45, -h * 0.35)])
	_glow(Vector2.ZERO, size * 1.9, Color(AMBER, (0.9 + glow_amt) * fade))
	draw_colored_polygon(body, Color(0.05, 0.09, 0.07, 0.9))
	# sap with a bright core
	var fill := PackedVector2Array([
		Vector2(-w * 0.52, -h * 0.05), Vector2(-w * 0.46, h * 0.40), Vector2(0, h * 0.48),
		Vector2(w * 0.46, h * 0.40), Vector2(w * 0.52, -h * 0.05)])
	draw_colored_polygon(fill, Color(AMBER, 0.85))
	draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.25, 0.0), Vector2(-w * 0.2, h * 0.34), Vector2(w * 0.2, h * 0.34), Vector2(w * 0.25, 0.0)]),
		Color(1.0, 0.95, 0.7, 0.8))
	# tiny garden inside the drop: a little fractal sprig
	var sp := Vector2(0, h * 0.28)
	draw_line(sp, sp + Vector2(0, -h * 0.32), Color(0.35, 0.18, 0.04, 0.8), 1.2, true)
	draw_line(sp + Vector2(0, -h * 0.16), sp + Vector2(-w * 0.2, -h * 0.30), Color(0.35, 0.18, 0.04, 0.8), 1.0, true)
	draw_line(sp + Vector2(0, -h * 0.16), sp + Vector2(w * 0.2, -h * 0.30), Color(0.35, 0.18, 0.04, 0.8), 1.0, true)
	var closed := body.duplicate()
	closed.append(body[0])
	draw_polyline(closed, Color(GOLD, 0.7), 1.3, true)
	draw_rect(Rect2(-w * 0.28, -h * 0.50, w * 0.56, h * 0.17), BARK_LIT)
	draw_line(Vector2(-w * 0.3, -h * 0.30), Vector2(-w * 0.34, h * 0.2), Color(1, 1, 1, 0.35), 1.4, true)
	draw_set_transform(_xp, _xr, _xs)


# ---------- the whole figure ----------

func _draw() -> void:
	var br := sin(t * 1.5)
	var sway := sin(t * 1.1) * 1.8
	var bow_a := bow * 0.20
	# the bow tips the whole upper body forward (right) about the hips
	var hip := Vector2(0, -60.0)
	# the transform used for everything above the hips
	var xf := Transform2D(bow_a, Vector2.ZERO)
	var org := hip - xf.basis_xform(hip)
	_xp = org + Vector2(bow * 6.0, 0)
	_xr = bow_a
	_xs = Vector2(1.0, 1.0 + br * 0.006)
	draw_set_transform(_xp, _xr, _xs)

	var neck := Vector2(2, -230)
	var head_dy := bow * 5.0 + br * 0.8

	# --- antlers, behind the hood ---
	var hood_top := Vector2(0, -296 + head_dy)
	_branch(hood_top + Vector2(-8, 4), -2.0, 50.0, 4, 4.6, 1.3)
	_branch(hood_top + Vector2(10, 2), -1.15, 56.0, 4, 4.8, 2.1)
	_branch(hood_top + Vector2(-2, 6), -1.62, 38.0, 3, 3.6, 0.4)

	# --- the lantern staff (his left hand, viewer's left) ---
	var staff_x := -66.0 + sway * 0.4
	draw_line(Vector2(staff_x, 0), Vector2(staff_x + 2, -268), Color(0, 0, 0, 0.4), 6.0, true)
	draw_line(Vector2(staff_x, 0), Vector2(staff_x + 2, -268), BARK, 4.6, true)
	draw_line(Vector2(staff_x + 1, 0), Vector2(staff_x + 3, -268), Color(BARK_LIT, 0.8), 1.4, true)
	# a tapping spike at the foot, with a clinging drop of sap
	draw_colored_polygon(PackedVector2Array([Vector2(staff_x - 4, -4), Vector2(staff_x + 4, -4), Vector2(staff_x, 7)]), Color(0.55, 0.5, 0.4))
	draw_circle(Vector2(staff_x + 5, -14), 2.4, Color(AMBER, 0.9))
	# hook + lantern
	var hook_c := Vector2(staff_x + 2, -268)
	draw_arc(hook_c + Vector2(8, 0), 8.0, PI, TAU * 0.98, 12, BARK_LIT, 2.4, true)
	var lan := Vector2(staff_x + 18, -250) + Vector2(sin(t * 1.7) * 1.4, 0)
	var flick := 0.85 + 0.15 * sin(t * 9.0) * sin(t * 3.1)
	_glow(lan, 120.0, Color(1.0, 0.78, 0.35, 0.8 * flick * fade))
	draw_line(lan + Vector2(-8, -17), lan + Vector2(-4, -26), BARK_LIT, 1.5, true)
	draw_line(lan + Vector2(8, -17), lan + Vector2(4, -26), BARK_LIT, 1.5, true)
	draw_colored_polygon(PackedVector2Array([lan + Vector2(-9, -16), lan + Vector2(9, -16), lan + Vector2(11, 12), lan + Vector2(-11, 12)]),
		Color(1.0, 0.8, 0.4, 0.35 + 0.25 * flick * fade))
	draw_colored_polygon(_ell(lan + Vector2(0, -1), 5.5 * flick, 8.0 * flick, 14), Color(1.0, 0.95, 0.7, 0.95))
	draw_polyline(PackedVector2Array([lan + Vector2(-9, -16), lan + Vector2(-11, 12), lan + Vector2(11, 12), lan + Vector2(9, -16), lan + Vector2(-9, -16)]),
		BARK_LIT, 1.6, true)
	draw_rect(Rect2(lan + Vector2(-12, 11), Vector2(24, 3.5)), BARK)
	draw_rect(Rect2(lan + Vector2(-8, -19), Vector2(16, 3.5)), BARK)

	# --- layered cloak ---
	# back layer: long, dark
	var back := PackedVector2Array([
		Vector2(-26, -232), Vector2(26, -232), Vector2(40, -150), Vector2(54 + sway, -40), Vector2(58 + sway, 0),
		Vector2(-58 + sway, 0), Vector2(-54 + sway, -40), Vector2(-40, -150)])
	_shape(back, DEEP)
	_fringe(-58, 58, -2.0, 11, 30.0, Color(0.06, 0.15, 0.09), 0.3, sway)
	# woven vertical strands
	for i in 7:
		var x := -44.0 + i * 14.7
		draw_line(Vector2(x * 0.45, -200), Vector2(x * 1.15 + sway, -6), Color(FERN, 0.16), 1.2, true)

	# mid layer: moss cape to the knee
	var mid := PackedVector2Array([
		Vector2(-34, -228), Vector2(34, -228), Vector2(46, -160), Vector2(50 + sway * 0.6, -92),
		Vector2(-50 + sway * 0.6, -92), Vector2(-46, -160)])
	_shape(mid, MOSS)
	_fringe(-50, 50, -92.0, 9, 34.0, MOSS.lerp(FERN, 0.3), 1.7, sway * 0.6)
	_fringe(-48, 48, -96.0, 8, 24.0, FERN.lerp(LEAF, 0.2), 4.1, sway * 0.6)

	# mantle: short leafy shoulder cape
	var mantle := PackedVector2Array([
		Vector2(-24, -236), Vector2(26, -236), Vector2(46, -206), Vector2(52, -168), Vector2(-52, -168), Vector2(-46, -206)])
	_shape(mantle, FERN)
	_fringe(-52, 52, -170.0, 9, 30.0, FERN.lerp(LEAF, 0.35), 2.9, 0.0)
	for r in 3:
		var yy := -216.0 + r * 17.0
		for i in 6:
			var xx := -34.0 + i * 13.6 + (8.0 if r % 2 == 1 else 0.0)
			_leaf(Vector2(xx, yy), PI * 0.5 + (i - 2.5) * 0.12 + sin(t * 1.3 + i + r) * 0.05, 18.0, 4.5, Color(LEAF, 0.55))

	# vines draped over the cloak with glowing buds
	_vine(Vector2(-30, -226), Vector2(-4, -150), Vector2(38, -118), Color(0.30, 0.22, 0.10, 0.9), 3)
	_vine(Vector2(26, -228), Vector2(40, -150), Vector2(6, -80), Color(0.30, 0.22, 0.10, 0.9), 3)

	# belt with a small tapping mallet and pouch
	draw_line(Vector2(-40, -122), Vector2(40, -118), BARK, 4.0, true)
	draw_circle(Vector2(0, -120), 4.5, BARK_LIT)
	draw_line(Vector2(24, -118), Vector2(30, -92), BARK_LIT, 3.0, true)
	draw_circle(Vector2(30, -90), 4.5, BARK)

	# --- left arm (viewer's left) holds the staff ---
	var shL := Vector2(-26, -226)
	var handL := Vector2(staff_x + 2, -150)
	var elbL := Vector2(-52, -170)
	_limb(shL, elbL, 11.0, MOSS)
	_limb(elbL, handL, 8.5, SKIN.darkened(0.15))
	for f in 3:
		draw_line(handL, handL + Vector2(6 + f, -3 + f * 3), SKIN.darkened(0.2), 2.0, true)

	# --- the carrying yoke with two jars ---
	var yoke_l := Vector2(-96, -226 + sway * 0.4)
	var yoke_r := Vector2(96, -226 + sway * 0.4)
	draw_line(yoke_l, yoke_r, Color(0, 0, 0, 0.35), 7.0, true)
	draw_line(yoke_l, yoke_r, BARK, 5.0, true)
	draw_line(yoke_l + Vector2(0, -1.4), yoke_r + Vector2(0, -1.4), Color(BARK_LIT, 0.8), 1.4, true)
	for e in [yoke_l, yoke_r]:
		draw_circle(e, 4.2, BARK_LIT)
	var swing := sin(t * 1.25) * 0.05
	var jl := Vector2(-96, -158) + Vector2(sin(t * 1.25 + 1.0) * 2.5, 0)
	draw_line(yoke_l, jl + Vector2(0, -16), Color(0.45, 0.33, 0.16), 1.4, true)
	_jar_draw(jl, 24.0, 0.1 * sin(t * 1.7), swing)
	# the right jar rises to the hand when "jar" is active
	var jr_rest := Vector2(96, -158) + Vector2(sin(t * 1.25) * 2.5, 0)
	var jr := jr_rest
	if _jar > 0.01:
		jr = jr_rest.lerp(Vector2(76, -262), _jar)
	draw_line(yoke_r, jr + Vector2(0, -16), Color(0.45, 0.33, 0.16), 1.4, true)
	_jar_draw(jr, 24.0 + 6.0 * _jar, 0.15 * sin(t * 1.7) + 0.5 * _jar, -swing)
	# droplets
	if _jar > 0.4:
		var dp := fposmod(t * 0.9, 1.0)
		draw_circle(jr + Vector2(0, 18 + dp * 36), 2.6 * (1.0 - dp), Color(AMBER, 0.9 * (1.0 - dp)))

	# --- head and hood ---
	var hc := Vector2(2, -262 + head_dy)
	var hood := PackedVector2Array([
		Vector2(-30, -224), Vector2(-27, -262 + head_dy * 0.8), Vector2(-14, -293 + head_dy), Vector2(6, -308 + head_dy),
		Vector2(22, -286 + head_dy), Vector2(32, -258 + head_dy * 0.8), Vector2(30, -224)])
	_shape(hood, MOSS.lerp(DEEP, 0.4))
	# hood fringe of tiny leaves along the opening
	var face_c := hc + Vector2(7, 4)
	draw_colored_polygon(_ell(face_c, 21, 27, 28), HOOD_IN)
	var opening := _ell(face_c, 21, 27, 28)
	var oc := opening.duplicate()
	oc.append(opening[0])
	draw_polyline(oc, Color(LEAF, 0.55), 2.4, true)
	for i in 9:
		var a := lerpf(-2.6, 0.9, i / 8.0) - 0.0
		var pb := face_c + Vector2(cos(a) * 21, sin(a) * 27)
		_leaf(pb, a + sin(t * 1.5 + i) * 0.08, 10.0, 3.2, Color(LEAF, 0.8))

	# eyes: kind, glowing, slightly tilted toward the listener (right)
	var look := Vector2(2.5, 1.0)
	var blink_k := absf(_blink / 0.16 * 2.0 - 1.0) if _blink > 0.0 else 1.0
	for ex in [Vector2(-3, -6), Vector2(17, -6)]:
		var ec: Vector2 = face_c + ex + look
		_glow(ec, 17.0, Color(AMBER, 0.75 * fade))
		var ey := 5.0 * maxf(blink_k, 0.08)
		# happy, upturned eye: a lit half-ellipse
		draw_colored_polygon(_ell(ec, 5.2, ey, 14), Color(1.0, 0.92, 0.6, 0.97))
		draw_colored_polygon(_ell(ec + Vector2(0.6, 0), 2.4, ey * 0.55, 10), Color(1.0, 1.0, 0.9))
	# gentle smile / mouth
	var mo := face_c + Vector2(7, 16) + Vector2(0, bow * 2.0)
	var open := 0.8 + 5.5 * talk
	draw_arc(mo + Vector2(0, -3), 8.0, 0.35, PI - 0.35, 10, Color(AMBER, 0.45), 1.3, true)
	draw_colored_polygon(_ell(mo + Vector2(0, open * 0.25), 4.0 + talk * 1.5, open * 0.5, 12), Color(1.0, 0.78, 0.4, 0.85))

	# --- antlers, front part: bases overlap the hood ---
	draw_line(hood_top + Vector2(-8, 4), hood_top + Vector2(-9, 12), BARK, 6.0, true)
	draw_line(hood_top + Vector2(10, 2), hood_top + Vector2(11, 12), BARK, 6.0, true)
	# a few leaf sprigs growing out of the hood
	for i in 5:
		_leaf(hood_top + Vector2(-12 + i * 6.5, 14), -PI * 0.5 + (i - 2) * 0.55 + sin(t * 1.4 + i) * 0.06, 15.0, 4.0, Color(LEAF, 0.95))

	# --- right arm (toward the seed) ---
	var shR := Vector2(26, -224)
	var rest_h := Vector2(44, -124)
	var point_h := Vector2(138, -214)
	var jar_h := Vector2(80, -246)
	var hand := rest_h + Vector2(sin(t * 1.5) * 1.5, br * 1.2)
	hand = hand.lerp(point_h, _point).lerp(jar_h, _jar).lerp(Vector2(104, -238), _giftp)
	var elb := (shR + hand) * 0.5 + Vector2(14.0, 18.0)
	elb = elb.lerp((shR + hand) * 0.5 + Vector2(2.0, 14.0), maxf(maxf(_point, _jar), _giftp) * 0.6)
	_limb(shR, elb, 11.0, MOSS)
	_limb(elb, hand, 8.5, SKIN)
	# long, thin fingers
	for f in 4:
		var fd := (hand - elb).normalized().rotated((f - 1.5) * (0.15 + 0.25 * (1.0 - _point)))
		draw_line(hand, hand + fd * (11.0 + (4.0 if f == 1 else 0.0) * _point), SKIN, 2.0, true)
	if _point > 0.5:
		var pa := _point
		_glow(hand + Vector2(18, 0), 20.0, Color(AMBER, 0.3 * pa))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
