extends Control
## Tiny hero-reveal example. Attach to a Control in a scene; press any key to skip.

var mat := ShaderMaterial.new()

func _ready() -> void:
	mat.shader = Shader.new()
	mat.shader.code = "shader_type canvas_item; uniform float glow = 0.0; void fragment() { COLOR = vec4(vec3(0.1, 0.8, 0.7) * glow, 1.0); }"
	var hero := ColorRect.new()
	hero.material = mat
	hero.size = Vector2(200, 200)
	hero.pivot_offset = Vector2(100, 100)
	hero.position = size * 0.5 - hero.size * 0.5
	add_child(hero)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	var cs := Cutscene.new().bind(self)
	cs.shake_target = hero
	cs.letterbox(true, 1.0) \
		.tween(black, "color:a", 0.0, 2.0) \
		.tween(hero, "scale", Vector2(1.4, 1.4), 5.0) \
		.shader(mat, "glow", 1.0, 3.0, 1.0) \
		.sound("reveal", 1.5).shake(8.0, 0.6, 2.0) \
		.at(4.0, func(): print("name revealed")) \
		.letterbox(false, 1.0, 5.0)
	await cs.play()
	print("hero reveal finished")
