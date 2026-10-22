extends Control
const G = preload("res://descent/statue_goblin.gd")
const D = preload("res://descent/statue_devil.gd")
const A = preload("res://descent/statue_angel.gd")
const HOT_G := 0.0
func _ready() -> void:
	size = Vector2(960, 640)
func _draw() -> void:
	draw_rect(Rect2(0, 0, 960, 640), Color(0.012, 0.012, 0.018))
	draw_rect(Rect2(0, 512, 960, 128), Color(0.022, 0.022, 0.03))
	draw_line(Vector2(0, 512), Vector2(960, 512), Color(0.05, 0.05, 0.07), 1.0)
	D.draw(self, Vector2(480, 512), 544.0, 0.5, 0.0)
	A.draw(self, Vector2(790, 512), 448.0, 0.5, 0.0)
	G.draw(self, Vector2(170, 512), 141.0, 0.5, HOT_G)
	G.draw(self, Vector2(300, 600), 141.0, 0.5, 1.0)
