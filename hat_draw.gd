extends Node2D

# The angel's red hat, drawn around its brim centre so it can be lifted off and carried to the chest.

const RED := Color(0.86, 0.07, 0.09)
const RED_DARK := Color(0.45, 0.03, 0.05)


func _ellipse(c: Vector2, rx: float, ry: float, n := 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _draw() -> void:
	draw_colored_polygon(_ellipse(Vector2(0, 1.5), 28.0, 6.0), RED_DARK)
	draw_colored_polygon(_ellipse(Vector2.ZERO, 28.0, 5.5), RED)
	var crown := PackedVector2Array([
		Vector2(-15, 0), Vector2(-13.5, -19), Vector2(-5, -22), Vector2(0, -18),
		Vector2(5, -22), Vector2(13.5, -19), Vector2(15, 0)])
	draw_colored_polygon(crown, RED)
	draw_rect(Rect2(-15, -6, 30, 5), Color(0.12, 0.01, 0.02))
	draw_polyline(PackedVector2Array([Vector2(-26, -1), Vector2(-14, -5), Vector2(14, -5), Vector2(26, -1)]), Color(1.0, 0.45, 0.4, 0.55), 1.3, true)
	draw_line(Vector2(-10, -18), Vector2(-11, -8), Color(1.0, 0.4, 0.35, 0.5), 1.4, true)
