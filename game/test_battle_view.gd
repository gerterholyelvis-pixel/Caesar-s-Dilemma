extends Control
## Off-screen render scene for Battle.

func _ready() -> void:
	size = Vector2(960, 640)
	Meta.reset_for_tests("user://test_battle_view_meta.cfg")
	Lexicon.init(4242)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.14, 0.15)
	bg.size = size
	add_child(bg)
	var b := Battle.new()
	b.size = size
	add_child(b)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	b.start(load("res://game/test_battle.gd").make_pack(), ["spore_sprout", "thorn_crawler", "glass_golem"], {"hp": 33, "max_hp": 40}, "seshat", rng)
	await get_tree().create_timer(0.6).timeout
	b.auto_step()
	b.auto_step()
