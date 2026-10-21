extends Node2D

# A little anonymous black angel in a red hat. Origin = feet, about 190 px tall.
# Pure silhouette (charcoal-black) with a faint cold rim light so it reads against the fog.
# `talk` (0..1) opens the mouth; set it to 1 on each spoken character and it decays by itself.
# `waving` raises the right arm and waves.

const BLACK := Color(0.022, 0.022, 0.028)
const RIM := Color(0.62, 0.63, 0.68, 0.38)
const RED := Color(0.86, 0.07, 0.09)
const RED_DARK := Color(0.45, 0.03, 0.05)
const MOUTH := Vector2(0, -125)

var t := 0.0
var talk := 0.0
var waving := false
var wave_blend := 0.0
var hat_e := 0.0    # 0 = hat on head, 1 = hat held against the chest (tween me)
var fade := 0.0     # 0..1 dissolve; the red hat is the last thing to go
var hat: Node2D


func _ready() -> void:
	hat = Node2D.new()
	hat.set_script(load("res://hat_draw.gd"))
	add_child(hat)


func _bow() -> float:
	return sin(clampf(hat_e, 0.0, 1.0) * PI) * 0.8 + hat_e * 0.7


func _bez(a: Vector2, c: Vector2, b: Vector2, u: float) -> Vector2:
	var v := 1.0 - u
	return a * v * v + c * 2.0 * v * u + b * u * u


func _process(delta: float) -> void:
	t += delta
	talk = maxf(talk - delta * 9.0, 0.0)
	wave_blend = move_toward(wave_blend, 1.0 if waving else 0.0, delta * 3.0)
	# the hat rides an arc from the head, out and up, then in to rest against the chest
	var bob := sin(t * 2.0) * 2.0
	var on_head := Vector2(0, -146.0 + _bow() * 4.0)
	var on_chest := Vector2(-2, -88)
	hat.position = _bez(on_head, Vector2(38, -200), on_chest, hat_e) + Vector2(0, bob)
	hat.rotation = sin(hat_e * PI) * 0.6 - hat_e * 0.3
	hat.scale = Vector2.ONE * lerpf(1.0, 0.88, hat_e)
	self_modulate.a = 1.0 - smoothstep(0.0, 0.85, fade)
	hat.modulate.a = 1.0 - smoothstep(0.55, 1.0, fade)
	queue_redraw()


func _ellipse(c: Vector2, rx: float, ry: float, n := 24) -> PackedVector2Array:
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
		draw_polyline(closed, RIM, 1.1, true)


func _limb(a: Vector2, b: Vector2, w: float) -> void:
	draw_line(a, b, RIM, w + 2.0, true)
	draw_line(a, b, BLACK, w, true)
	draw_circle(b, w * 0.5, BLACK)


func _draw() -> void:
	var bob := sin(t * 2.0) * 2.0
	var sway := sin(t * 1.3) * 2.0
	draw_set_transform(Vector2(0, bob), 0.0, Vector2.ONE)

	# folded-then-fluttering wings, behind everything
	for side in [1.0, -1.0]:
		for i in 8:
			var ang := -0.80 + i * 0.17 + sin(t * 2.0 + i * 0.35) * 0.035
			var a: float = ang if side > 0.0 else PI - ang
			var d := Vector2.from_angle(a)
			var n := Vector2(-d.y, d.x)
			var base := Vector2(side * 9.0, -102.0)
			var len := 78.0 - absf(float(i) - 3.0) * 4.0 + (3.0 if i < 4 else 0.0)
			var pts := PackedVector2Array([
				base + n * 5.0, base + d * len * 0.55 + n * 8.0, base + d * len,
				base + d * len * 0.55 - n * 8.0, base - n * 5.0])
			_shape(pts, BLACK.lerp(Color(0.07, 0.07, 0.09), float(i) / 8.0))

	# robe
	var robe := PackedVector2Array([
		Vector2(-14, -113), Vector2(14, -113), Vector2(24 + sway * 0.4, -64),
		Vector2(33 + sway, 0), Vector2(-33 + sway, 0), Vector2(-24 + sway * 0.4, -64)])
	_shape(robe, BLACK)
	# hem folds
	draw_line(Vector2(-10 + sway, -4), Vector2(-7, -50), Color(0.2, 0.2, 0.24, 0.35), 1.0, true)
	draw_line(Vector2(11 + sway, -4), Vector2(8, -50), Color(0.2, 0.2, 0.24, 0.35), 1.0, true)

	# left arm hangs, right arm waves
	_limb(Vector2(-14, -108), Vector2(-24, -62), 9.0)
	var hang := Vector2(25, -62)
	var raised := Vector2(46, -120) + Vector2(sin(t * 7.5) * 9.0, -absf(sin(t * 7.5)) * 3.0)
	var hand := hang.lerp(raised, wave_blend).lerp(Vector2(5, -88), hat_e)
	var arm_k := maxf(wave_blend, hat_e)
	var elbow := Vector2(14, -108).lerp(hand, 0.5) + Vector2(8.0 * arm_k, 10.0 * arm_k)
	_limb(Vector2(14, -108), elbow, 9.0)
	_limb(elbow, hand, 8.0)

	# head: faceless
	var hy := -132.0 + _bow() * 4.0
	draw_circle(Vector2(0, hy), 17.5, BLACK)
	draw_arc(Vector2(0, hy), 17.5, PI * 1.05, PI * 1.75, 16, RIM, 1.2, true)

	# a barely-there mouth that opens when it speaks
	var open := 0.7 + 3.4 * talk
	draw_colored_polygon(_ellipse(MOUTH + Vector2(0, _bow() * 4.0), 4.2, open * 0.5, 14), Color(0.30, 0.30, 0.34, 0.9))

	# faint, dying halo
	var flick := 0.25 + 0.1 * sin(t * 3.0)
	draw_arc(Vector2(0, -184), 14.0, 0, TAU, 32, Color(0.72, 0.72, 0.76, flick), 1.6, true)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
