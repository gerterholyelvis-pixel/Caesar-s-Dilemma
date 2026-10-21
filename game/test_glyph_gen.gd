extends SceneTree
## Headless: godot --headless --path . -s game/test_glyph_gen.gd

var fails := 0

func check(ok: bool, msg: String) -> void:
	print(("PASS " if ok else "FAIL ") + msg)
	if not ok:
		fails += 1

func _init() -> void:
	check(GlyphGen.radical_count() >= 40, "at least 40 radicals")
	var all_sigs := {}
	var bad_bounds := 0
	var bad_parts := 0
	var empty := 0
	for id in GlyphGen.POOL:
		var strokes := GlyphGen.strokes(id)
		var parts: int = GlyphGen.spec(id).parts.size()
		if parts < 2 or parts > 4:
			bad_parts += 1
		if strokes.is_empty():
			empty += 1
		for st: PackedVector2Array in strokes:
			if st.is_empty():
				empty += 1
			for p in st:
				if absf(p.x) > 1.25 or absf(p.y) > 1.25:
					bad_bounds += 1
		all_sigs[GlyphGen.signature(id)] = id
	check(empty == 0, "no empty strokes")
	check(bad_parts == 0, "every glyph has 2-4 parts")
	check(bad_bounds == 0, "all points inside the unit box (+margin): %d outside" % bad_bounds)
	check(all_sigs.size() == GlyphGen.POOL, "all %d ids unique: %d distinct" % [GlyphGen.POOL, all_sigs.size()])

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var ids := {}
	while ids.size() < 2000:
		ids[rng.randi() % GlyphGen.POOL] = true
	var sigs := {}
	for id in ids:
		sigs[GlyphGen.signature(id)] = true
	check(sigs.size() == 2000, "2000 random ids give 2000 unique signatures")

	GlyphGen._cache.clear()
	var s1 := GlyphGen.signature(777)
	GlyphGen._cache.clear()
	check(s1 == GlyphGen.signature(777), "signature deterministic")
	check(GlyphGen.similarity_hint(5, 5) > 0.99, "self similarity = 1")
	var total := 0.0
	var high := 0
	for i in 2000:
		var a := rng.randi() % GlyphGen.POOL
		var b := rng.randi() % GlyphGen.POOL
		if a == b:
			continue
		var h := GlyphGen.similarity_hint(a, b)
		total += h
		if h > 0.7:
			high += 1
	print("mean similarity %.3f, pairs >0.7: %d / 2000" % [total / 2000.0, high])
	check(total / 2000.0 < 0.2 and high < 20, "random pairs are mostly dissimilar")
	for kind in 8:
		check(GlyphGen._frame(kind).size() > 0, "determinative %d has strokes" % kind)
	quit(1 if fails > 0 else 0)
