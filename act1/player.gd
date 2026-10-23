extends CharacterBody3D
## First-person controller: mouse look (click to capture, Esc to release), WASD, head-bob, breathing sway, footsteps.
## Convention: yaw 0 looks toward +Z (the door); positive pitch looks up.

var cam: Camera3D
var eye_height := 1.65
var yaw := 0.0            # radians
var pitch := 0.0          # radians
var enabled := true
var sway_enabled := true
var walk_speed := 2.5
var sensitivity := 0.0022
var steps: Array = []     # AudioStreamWAV variations (set by the chamber once baked)
var _step_player: AudioStreamPlayer
var _bob := 0.0
var _last_half := 0
var _t := 0.0
var _shake := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	cs.shape = cap
	cs.position = Vector3(0, 0.88, 0)
	add_child(cs)
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.05
	cam.far = 60.0
	cam.position = Vector3(0, eye_height, 0)
	cam.current = true
	add_child(cam)
	_step_player = AudioStreamPlayer.new()
	_step_player.volume_db = -9.0
	add_child(_step_player)
	_rng.randomize()
	_apply_look()

func place(p: Vector3, yaw_deg: float, pitch_deg: float) -> void:
	position = Vector3(p.x, 0.0, p.z)
	eye_height = p.y
	if cam != null:
		cam.position.y = eye_height
	yaw = deg_to_rad(yaw_deg)
	pitch = deg_to_rad(pitch_deg)
	_apply_look()

func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

func _apply_look() -> void:
	rotation.y = PI + yaw
	if cam != null:
		cam.rotation.x = pitch

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
	elif ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif ev is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and enabled:
		yaw -= ev.relative.x * sensitivity
		pitch = clampf(pitch - ev.relative.y * sensitivity, deg_to_rad(-85.0), deg_to_rad(85.0))
		_apply_look()

func _physics_process(delta: float) -> void:
	var dir := Vector2.ZERO
	if enabled:
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): dir.y += 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): dir.y -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): dir.x += 1.0
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): dir.x -= 1.0
	dir = dir.normalized()
	var fwd := Vector3(sin(yaw), 0.0, cos(yaw))        # yaw 0 -> +Z
	var right := Vector3(-cos(yaw), 0.0, sin(yaw))     # yaw 0 -> -X ... mirrored below
	right = fwd.cross(Vector3.UP)                       # screen-right
	var target := (fwd * dir.y + right * dir.x) * walk_speed
	velocity = velocity.lerp(Vector3(target.x, 0.0, target.z), clampf(delta * 9.0, 0.0, 1.0))
	move_and_slide()
	position.y = 0.0
	var sp := Vector2(velocity.x, velocity.z).length()
	# head bob + footsteps
	if sp > 0.3:
		_bob += delta * sp * 2.9
	var half: int = int(floor(_bob / PI))
	if half != _last_half:
		_last_half = half
		if sp > 0.3 and steps.size() > 0:
			_step_player.stream = steps[_rng.randi() % steps.size()]
			_step_player.pitch_scale = _rng.randf_range(0.88, 1.1)
			_step_player.play()

func _process(delta: float) -> void:
	_t += delta
	if cam == null:
		return
	var sp := Vector2(velocity.x, velocity.z).length()
	var k := clampf(sp / walk_speed, 0.0, 1.0)
	var bob_y := 0.0
	var bob_x := 0.0
	var sw_p := 0.0
	var sw_r := 0.0
	if sway_enabled:
		bob_y = absf(sin(_bob)) * 0.045 * k - 0.02 * k
		bob_x = sin(_bob) * 0.02 * k
		sw_p = sin(_t * 1.15) * 0.0022 + sin(_t * 0.37) * 0.0015
		sw_r = sin(_t * 0.8) * 0.0018 + sin(_bob) * 0.004 * k
	_shake = maxf(0.0, _shake - delta * 1.4)
	var sh := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0) * _shake * 0.02
	cam.position = Vector3(bob_x + sh.x, eye_height + bob_y + sh.y + sin(_t * 1.15) * 0.004 * (1.0 if sway_enabled else 0.0), 0)
	cam.rotation.x = pitch + sw_p + _shake * 0.02 * sin(_t * 40.0)
	cam.rotation.z = sw_r
