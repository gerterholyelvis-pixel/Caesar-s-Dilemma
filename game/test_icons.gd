extends Node2D
## Contact sheet of all item icons at their real shapes. Run with
## --write-movie ... --quit-after N, or open normally.

var _t := 0.0

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var vs := Vector2(960, 640)
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.09, 0.11))
	for i in 6:
		draw_circle(vs * Vector2(0.2 + 0.12 * i, 0.5), 220.0, Color(0.1, 0.4, 0.4, 0.04))
	var ids: Array[String] = ItemDB.all_ids()
	var cell := 44.0
	var x := 24.0
	var y := 20.0
	var row_h := 0.0
	var font: Font = ThemeDB.fallback_font
	for i in ids.size():
		var id: String = ids[i]
		var sz: Vector2i = ItemDB.shape_size(id, 0)
		var r := Vector2(sz.x, sz.y) * cell
		if x + r.x > vs.x - 20.0:
			x = 24.0
			y += row_h + 30.0
			row_h = 0.0
		ItemIcons.draw(self, id, Rect2(Vector2(x, y), r), _t, 1.0 if i == 3 or i == 9 else 0.0)
		draw_string(font, Vector2(x, y + r.y + 14.0), id, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ItemIcons.cell_color(id))
		x += r.x + 26.0
		row_h = maxf(row_h, r.y)
