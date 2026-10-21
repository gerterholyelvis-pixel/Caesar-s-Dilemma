extends Node
## Contact sheet: four screens at half scale in a 960x640 window.

func _ready() -> void:
	Lexicon.init(77)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var kit := [LootUI.new(), DilemmaUI.new(), ShrineUI.new(), HeroSelectUI.new()]
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.1)
	bg.size = Vector2(960, 640)
	add_child(bg)
	for i in 4:
		var c: Control = kit[i]
		c.size = Vector2(960, 640)
		c.scale = Vector2(0.5, 0.5)
		c.position = Vector2((i % 2) * 480, (i / 2) * 320)
		add_child(c)
	kit[0].show_offers(["bone_blade", "healing_bloom", "fractal_seed"])
	kit[1].show_dilemma(DilemmaDB.roll(rng))
	kit[2].open(rng)
	kit[2].reveal()
	kit[3].open()
	kit[3].choose("seshat", "cathedral")
	await get_tree().create_timer(0.1).timeout
	kit[1].skip_text()
