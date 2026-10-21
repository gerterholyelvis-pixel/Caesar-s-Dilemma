extends Node2D
## Contact sheet for the movie writer (960x640). User arg "p2" shows the second page
## (determinatives, small and large glyphs); a numeric arg sets the first glyph id.

var start := 0
var page2 := false
var page3 := false

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "p2":
			page2 = true
		elif a == "p3":
			page3 = true
		elif a.is_valid_int():
			start = int(a)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 960, 640), Color(0.03, 0.12, 0.13))
	if page3:
		_page3()
	elif page2:
		_page2()
	else:
		_page1()

func _page1() -> void:
	var gold := Color(0.95, 0.82, 0.45)
	var cyan := Color(0.55, 0.95, 0.9)
	for i in 200:
		var c := Vector2(30 + (i % 20) * 46, 30 + (i / 20) * 46)
		GlyphGen.draw(self, start + i * 25, c, 40.0, gold if (i / 20) % 2 == 0 else cyan, 2.0)
	for k in 8:
		GlyphGen.draw_frame(self, k, Rect2(30 + k * 70, 500, 50, 50), Color(0.85, 0.55, 0.95))
	for i in 20:
		GlyphGen.draw(self, start + 3000 + i * 7, Vector2(30 + i * 46, 600), 24.0, gold, 1.5)

func _page2() -> void:
	var gold := Color(0.95, 0.82, 0.45)
	var cyan := Color(0.55, 0.95, 0.9)
	for k in 8:
		GlyphGen.draw_frame(self, k, Rect2(20 + k * 115, 20, 96, 96), Color(0.85, 0.55, 0.95))
	for i in 24:
		GlyphGen.draw(self, start + 1111 + i * 131, Vector2(50 + (i % 8) * 115, 190 + (i / 8) * 110), 90.0, gold if i % 2 == 0 else cyan, 3.0)
	for i in 14:
		GlyphGen.draw(self, start + 2222 + i * 17, Vector2(40 + i * 66, 560), 56.0, cyan, 2.5)

func _page3() -> void:
	for i in GlyphGen.radical_count() * 4:
		var k := i / 4
		var c := Vector2(30 + (i % 16) * 58, 30 + (i / 16) * 52)
		GlyphGen._draw_strokes(self, GlyphGen._rad(k, i % 4), c, 21.0, Color(0.95, 0.82, 0.45) if k % 2 == 0 else Color(0.55, 0.95, 0.9), 2.0)
