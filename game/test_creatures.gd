extends Node2D
## Contact sheet: enemies (row 1), Seshat & Thoth with empty / 3-item / full pack (rows 2-3).

var t := 0.0
var packs: Array = []

func _ready() -> void:
	scale = Vector2(0.64, 0.64)
	var e := Backpack.new()
	var three := Backpack.new()
	for id in ["bone_blade", "lapis_shield", "healing_bloom"]:
		var sp: Dictionary = three.find_spot(id)
		if not sp.is_empty():
			three.place(id, sp.pos, sp.get("rot", 0))
	var full := Backpack.new()
	for id in ItemDB.all_ids():
		var sp2: Dictionary = full.find_spot(id)
		if not sp2.is_empty():
			full.place(id, sp2.pos, sp2.get("rot", 0))
	packs = [e, three, full]
	print("sigs ", CreatureArt.pack_signature(e), " ", CreatureArt.pack_signature(three), " ", CreatureArt.pack_signature(full))

func _process(d: float) -> void:
	t += d
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1500, 900), Color(0.02, 0.04, 0.07))
	var kinds := ["spore_sprout", "thorn_crawler", "crystal_moth", "glass_golem", "cascade_warden", "mire_leech", "ember_wisp", "mirror_wraith", "shard_hound", "prism_sentinel", "root_tyrant"]
	for i in kinds.size():
		CreatureArt.draw(self, kinds[i], Vector2(130 + (i % 6) * 250, 120 + (i / 6) * 260), 200 * [1.0, 1.0, 1.0, 1.0, 1.0, 0.8, 0.75, 1.05, 1.0, 1.4, 1.5][i] / 1.0 * 0.8, t, 0.5 if (i == 2 and fmod(t, 1.0) < 0.2) else 0.0, 1.0)
	for h in 2:
		for p in 3:
			CreatureArt.draw_player(self, packs[p], ["seshat", "thoth"][h], Vector2(250 + p * 500, 680 + h * 190), 110, t, 0.0, 1.0)
