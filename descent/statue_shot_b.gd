extends Control

const Horror := preload("res://descent/statue_horror.gd")
const Man := preload("res://descent/statue_man.gd")


func _ready() -> void:
	size = Vector2(960, 640)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 960, 640), Color(0.012, 0.012, 0.018))
	draw_rect(Rect2(0, 512, 960, 128), Color(0.02, 0.02, 0.028))
	draw_line(Vector2(0, 512), Vector2(960, 512), Color(0.08, 0.05, 0.05), 1.0)
	Horror.draw(self, Vector2(300, 520), 384.0, 2.0, 0.0)
	Man.draw(self, Vector2(640, 520), 218.0, 2.0, 0.0)
	Horror.draw(self, Vector2(880, 520), 200.0, 2.0, 1.0)
