extends Node2D
## Visual: renders a populated BackpackUI plus a held ghost. Headless (-s style) logic checks run via --headless on this scene
## with "-- logic" (prints PASS/FAIL then quits).

var ui: BackpackUI
var bp: Backpack
var fails := 0

func check(c: bool, label: String) -> void:
	print("PASS " if c else "FAIL ", label)
	if not c:
		fails += 1

func _ready() -> void:
	Lexicon.init(4242, {"item:bone_blade": true})
	bp = Backpack.new()
	ui = BackpackUI.new()
	add_child(ui)
	ui.position = Vector2(150, 150)
	ui.size = Vector2(440, 340)
	ui.setup(bp, "arrange")
	ui.size = Vector2(440, 340)
	var ids := ["bone_blade", "whetstone", "reed_buckler", "lapis_shield", "spore_flask", "healing_bloom"]
	for id in ids:
		var s := bp.find_spot(id)
		if not s.is_empty():
			bp.place(id, s.pos, s.rot)
	if "--logic" in OS.get_cmdline_user_args():
		_logic()
		return
	ui.mode = "combat"
	ui.energy = 1
	ui.used = [bp.uids()[2]]
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.12, 0.13)
	bg.size = Vector2(960, 640)
	add_child(bg)
	move_child(bg, 0)
	ui.pin_hover = true
	ui._hover = bp.uids()[0]
	ui._hover_t = 1.0
	ui._show_tip(ui._hover)

func _logic() -> void:
	var n0 := bp.placed.size()
	check(n0 >= 4, "items auto-placed (%d)" % n0)
	ui.hold("thorn_dagger")
	check(ui.is_holding(), "hold begins")
	var r0 := ui.held_rot()
	ui.rotate_held()
	check(ui.held_rot() == (r0 + 1) % 4, "rotate advances")
	for i in 3:
		ui.rotate_held()
	check(ui.held_rot() == 0, "4 rotations wrap")
	# find an invalid and a valid anchor
	var bad := Vector2i(-3, -3)
	check(not ui.can_drop(bad), "off-grid invalid")
	var got := false
	for y in bp.h:
		for x in bp.w:
			if ui.can_drop(Vector2i(x, y)) and not got:
				got = true
				var placed_uid := [-1]
				ui.placed.connect(func(u: int) -> void: placed_uid[0] = u)
				var fin := [false]
				ui.hold_finished.connect(func(p: bool) -> void: fin[0] = p)
				check(ui.drop_at(Vector2i(x, y)), "drop at valid anchor")
				check(placed_uid[0] != -1 and fin[0], "placed + hold_finished emitted")
				check(bp.placed.size() == n0 + 1, "backpack grew")
	check(not ui.is_holding(), "no longer holding")
	ui.hold("quiver")
	var cancelled := [true]
	ui.hold_finished.connect(func(p: bool) -> void: cancelled[0] = p)
	ui.cancel_hold()
	check(cancelled[0] == false and not ui.is_holding(), "cancel emits hold_finished(false)")
	# synergy link strength: whetstone is adjacent to something bladed?
	var any := 0
	for u in bp.uids():
		for nb in bp.neighbors(u):
			any += ui.link_strength(u, nb)
	print("INFO total link strength ", any)
	print("RESULT ", "ALL PASS" if fails == 0 else "%d FAILED" % fails)
	get_tree().quit(0 if fails == 0 else 1)
