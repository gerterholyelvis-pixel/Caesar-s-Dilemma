class_name RouteMap
extends Control
## Seeded FRACTAL TREE route map. Nodes are Dictionaries
## {id:int, type:String, depth:int, children:Array[int], parents:Array[int], revealed:bool,
##  state:"open"|"withered"|"done"|"current", path:String, [resolved:String for '?' nodes]}.
## nodes[id] == node (id == index). Node 0 is the start (type "start", state "current").
## Every depth D-1 node (a "rest") links to the boss at depth D, so the whole tree is a crown.

signal node_chosen(node: Dictionary)

const MAX_WIDTH := 7
const FREE_TYPES := ["fight", "mystery", "elite", "shop", "rest", "shrine", "treasure"]
const MYSTERY_BASE := {"fight": 34.0, "treasure": 20.0, "shop": 14.0, "rest": 14.0, "shrine": 10.0, "dilemma": 3.0}
const BIAS_ORIGIN := {
	"eclipse": {"elite": 1.5, "shrine": 1.4},
	"mirror": {"mystery": 1.5, "shop": 1.3},
	"cathedral": {"rest": 1.4, "shrine": 1.5}}
const BIAS_HERO := {
	"seshat": {"shrine": 1.3, "mystery": 1.2},
	"thoth": {"shop": 1.3, "treasure": 1.3}}
const COLS := {
	"start": Color(0.7, 0.9, 0.9), "fight": Color(0.95, 0.42, 0.46), "elite": Color(0.95, 0.3, 0.75),
	"treasure": Color(1.0, 0.8, 0.35), "shop": Color(0.35, 0.9, 1.0), "rest": Color(0.4, 0.95, 0.65),
	"shrine": Color(0.72, 0.6, 1.0), "dilemma": Color(1.0, 0.95, 0.75), "mystery": Color(0.62, 0.45, 0.95),
	"boss": Color(1.0, 0.5, 0.25)}

var map_seed := 0
var origin_id := ""
var hero_id := ""
var nodes: Array = []
var depth_max := 9
var current_id := 0
var boss_id := -1
var mut_count := 0
var mystery_rolls := 0
var since_dilemma := 0
var mystery_hist: Dictionary = {}
var backdrop := true
var leaf_budget := 0
const SPREAD := 0.95

var _grow := 0.0
var _time := 0.0
var _tx: Dictionary = {}      # id -> target x (0..1)
var _pc: Dictionary = {}      # id -> current animated x
var _al: Dictionary = {}      # id -> visual alpha (withering fade)
var _hov: Dictionary = {}     # id -> hover amount
var _flash: Dictionary = {}   # id -> mutation flash
var _hover_id := -1


# ------------------------------------------------------------------ generation
func _rng_for(path: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d:%s" % [map_seed, path])
	return r


func _new_node(type: String, depth: int, path: String) -> int:
	var id := nodes.size()
	nodes.append({"id": id, "type": type, "depth": depth, "children": [], "parents": [],
		"revealed": false, "state": "open", "path": path})
	return id


func _link(a: int, b: int) -> void:
	nodes[a].children.append(b)
	nodes[b].parents.append(a)


func generate(p_seed: int, p_origin: String = "", p_hero: String = "") -> void:
	if not Lexicon.has_concept("loc:boss"):
		Lexicon.register("loc:boss", "Boss", true)
	map_seed = p_seed
	origin_id = p_origin
	hero_id = p_hero
	nodes.clear()
	mut_count = 0
	mystery_rolls = 0
	since_dilemma = 0
	mystery_hist = {}
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d:shape" % p_seed)
	depth_max = 9 + (r.randi() % 2)
	_new_node("start", 0, "0")
	leaf_budget = 8 + (r.randi() % 4)
	_branch(0, leaf_budget)
	boss_id = _new_node("boss", depth_max, "B")
	for n in nodes:
		if n.depth == depth_max - 1:
			_link(n.id, boss_id)
	_assign_types()
	current_id = 0
	nodes[0].state = "current"
	nodes[0].revealed = true
	reveal_choices()
	_layout()
	_pc = _tx.duplicate()
	_al.clear()
	_grow = 0.0
	queue_redraw()


## Recursive self-similar growth: a branch runs a stem (a fraction of the height it still has to climb),
## forks into 2-3 sub-branches that each get a share of the leaf budget and repeat at smaller scale.
func _branch(id: int, budget: int) -> void:
	var rem: int = depth_max - 1 - int(nodes[id].depth)
	var rng := _rng_for(nodes[id].path)
	var cur := id
	var s := 0
	if budget <= 1:
		s = rem
	elif rem > 0 and nodes[id].depth > 0:
		s = clampi(roundi(rem * (0.17 + 0.2 * rng.randf())), 1 if rem >= 3 else 0, rem - 1)
	for i in s:
		var cid := _new_node("fight", nodes[cur].depth + 1, nodes[cur].path + ".0")
		_link(cur, cid)
		cur = cid
	if budget <= 1 or rem <= 0:
		return
	var k := 2 if rng.randf() < 0.62 else 3
	if nodes[id].depth == 0:
		k = 2 + (rng.randi() % 2)
	k = mini(k, budget)
	var wts: Array = []
	var tot := 0.0
	for i in k:
		wts.append(0.7 + rng.randf())
		tot += wts[i]
	var shares: Array = []
	var left := budget - k
	for i in k:
		var extra: int = left if i == k - 1 else mini(left, roundi((budget - k) * wts[i] / tot))
		shares.append(1 + extra)
		left -= extra
	for i in k:
		var cid := _new_node("fight", nodes[cur].depth + 1, nodes[cur].path + "." + str(i + 1))
		_link(cur, cid)
		_branch(cid, shares[i])


func _mid() -> int:
	return depth_max / 2


func _bias(t: String) -> float:
	var m := 1.0
	if BIAS_ORIGIN.has(origin_id):
		m *= BIAS_ORIGIN[origin_id].get(t, 1.0)
	if BIAS_HERO.has(hero_id):
		m *= BIAS_HERO[hero_id].get(t, 1.0)
	return m


func _pick_type(rng: RandomNumberGenerator, depth: int, ptype: String, gtype: String) -> String:
	var w := {"fight": 30.0, "mystery": 22.0}
	if depth >= 3:
		w["shop"] = 10.0
		w["rest"] = 9.0
		w["shrine"] = 8.0
		w["treasure"] = 7.0
	if depth > _mid():
		w["elite"] = 9.0
	var total := 0.0
	for t in w:
		var x: float = w[t] * _bias(t)
		if t == ptype:
			x *= 0.3
		if t == gtype:
			x *= 0.6
		w[t] = x
		total += x
	var pick := rng.randf() * total
	for t in w:
		pick -= w[t]
		if pick <= 0.0:
			return t
	return "fight"


func _fixed_type(depth: int) -> String:
	if depth <= 2:
		return "fight"
	if depth == _mid():
		return "treasure"
	if depth == depth_max - 1:
		return "rest"
	return ""


func _assign_types() -> void:
	for id in range(1, nodes.size()):
		var n: Dictionary = nodes[id]
		if n.type == "boss":
			continue
		var f := _fixed_type(n.depth)
		if f != "":
			n.type = f
			continue
		var par: Dictionary = nodes[n.parents[0]]
		var gp := ""
		if par.parents.size() > 0:
			gp = nodes[par.parents[0]].type
		n.type = _pick_type(_rng_for(n.path + "t"), n.depth, par.type, gp)
	# guarantee a few staples exist in the free range
	var r := _rng_for("staples")
	for t in ["shop", "shrine", "elite", "mystery"]:
		var has := false
		var cands: Array = []
		for n in nodes:
			if n.type == t:
				has = true
			var lo: int = _mid() + 1 if t == "elite" else 3
			if n.depth >= lo and n.depth <= depth_max - 2 and _fixed_type(n.depth) == "" and n.type in ["fight", "mystery"]:
				cands.append(n)
		if not has and cands.size() > 0:
			cands[r.randi() % cands.size()].type = t


# ------------------------------------------------------------------ queries
func reveal_choices() -> Array:
	var out: Array = []
	for c in nodes[current_id].children:
		nodes[c].revealed = true
		out.append(nodes[c])
	queue_redraw()
	return out


func reachable_ids() -> Array:
	var out: Array = []
	for c in nodes[current_id].children:
		if nodes[c].state == "open":
			out.append(c)
	return out


func can_reach_boss() -> bool:
	var seen := {current_id: true}
	var stack: Array = [current_id]
	while stack.size() > 0:
		var id: int = stack.pop_back()
		if id == boss_id:
			return true
		for c in nodes[id].children:
			if not seen.has(c) and nodes[c].state != "withered":
				seen[c] = true
				stack.append(c)
	return false


func _reach_set() -> Dictionary:
	var seen := {current_id: true}
	var stack: Array = [current_id]
	while stack.size() > 0:
		var id: int = stack.pop_back()
		for c in nodes[id].children:
			if not seen.has(c) and nodes[c].state != "withered":
				seen[c] = true
				stack.append(c)
	return seen


## True when every node still reachable from the current one can itself reach the boss (no dead ends).
func _all_alive() -> bool:
	var live := {boss_id: true}
	var stack: Array = [boss_id]
	while stack.size() > 0:
		var id: int = stack.pop_back()
		for p in nodes[id].parents:
			if not live.has(p) and nodes[p].state != "withered":
				live[p] = true
				stack.append(p)
	for r in _reach_set():
		if not live.has(r):
			return false
	return true


func _descendants(id: int) -> Array:
	var out: Array = []
	var seen := {id: true}
	var stack: Array = [id]
	while stack.size() > 0:
		var x: int = stack.pop_back()
		out.append(x)
		for c in nodes[x].children:
			if c != boss_id and not seen.has(c):
				seen[c] = true
				stack.append(c)
	return out


# ------------------------------------------------------------------ choosing & mystery
func choose(id: int) -> bool:
	if id < 0 or id >= nodes.size() or not reachable_ids().has(id):
		return false
	nodes[current_id].state = "done"
	current_id = id
	var n: Dictionary = nodes[id]
	n.state = "current"
	n.revealed = true
	if n.type == "mystery" and not n.has("resolved"):
		resolve_mystery(id)
	reveal_choices()
	_flash[id] = 1.0
	node_chosen.emit(n)
	return true


## Deterministic, self-balancing outcome of a '?' node (recent outcomes get rarer, Dilemma rare but due).
func resolve_mystery(id: int) -> String:
	var n: Dictionary = nodes[id]
	if n.has("resolved"):
		return n.resolved
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:myst:%d" % [map_seed, mystery_rolls])
	mystery_rolls += 1
	var w := {}
	var total := 0.0
	for t in MYSTERY_BASE:
		var x: float = MYSTERY_BASE[t] * pow(0.55, mystery_hist.get(t, 0.0)) * _bias(t)
		if t == "dilemma":
			x = minf(1.5 + 0.35 * since_dilemma, 5.0) * _bias(t)
		w[t] = x
		total += x
	var pick := rng.randf() * total
	var res := "fight"
	for t in w:
		pick -= w[t]
		if pick <= 0.0:
			res = t
			break
	for k in mystery_hist.keys():
		mystery_hist[k] = mystery_hist[k] * 0.85
	mystery_hist[res] = mystery_hist.get(res, 0.0) + 1.0
	since_dilemma = 0 if res == "dilemma" else since_dilemma + 1
	n["resolved"] = res
	return res


## Test/auto-play helper: walk one step along a random open child.
func autoplay_step(rng: RandomNumberGenerator) -> bool:
	var r := reachable_ids()
	if r.is_empty():
		return false
	return choose(r[rng.randi() % r.size()])


# ------------------------------------------------------------------ mutations
## modes: wither|sprout|swap|reveal|hide. Only unseen (unrevealed, non-current-path) nodes change.
## Returns the ids that changed (empty when nothing could be done safely).
func mutate(mode: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:mut:%d" % [map_seed, mut_count])
	mut_count += 1
	var cur_depth: int = nodes[current_id].depth
	var cands: Array = []
	for n in nodes:
		if not n.revealed and n.state == "open" and n.type != "boss" and n.depth > cur_depth:
			cands.append(n.id)
	_shuffle(cands, rng)
	var changed: Array = []
	match mode:
		"wither":
			for cid in cands.slice(0, 14):
				var desc := _descendants(cid).filter(func(x): return nodes[x].state == "open")
				for d in desc:
					nodes[d].state = "withered"
				if not _any_revealed(desc) and _all_alive():
					changed = desc.duplicate()
					break
				for d in desc:
					nodes[d].state = "open"
		"sprout":
			for cid in cands:
				var p: Dictionary = nodes[cid]
				if p.depth > depth_max - 2 or p.children.size() >= 3:
					continue
				changed = [cid]
				var par: int = cid
				var gtype: String = nodes[p.parents[0]].type if p.parents.size() > 0 else ""
				var ptype: String = p.type
				for d in range(p.depth + 1, depth_max):
					var t := "rest" if d == depth_max - 1 else _pick_type(rng, d, ptype, gtype)
					if d == _mid():
						t = "treasure"
					var nid := _new_node(t, d, "%s.s%d" % [nodes[par].path, mut_count])
					_link(par, nid)
					changed.append(nid)
					gtype = ptype
					ptype = t
					par = nid
				_link(par, boss_id)
				break
		"swap":
			var free: Array = cands.filter(func(x): return _fixed_type(nodes[x].depth) == "" and nodes[x].type != "start")
			for i in free.size():
				var found := false
				for j in range(i + 1, free.size()):
					var a: Dictionary = nodes[free[i]]
					var b: Dictionary = nodes[free[j]]
					if a.type == b.type:
						continue
					if (a.type == "elite" and b.depth <= _mid()) or (b.type == "elite" and a.depth <= _mid()):
						continue
					var tmp: String = a.type
					a.type = b.type
					b.type = tmp
					changed = [a.id, b.id]
					found = true
					break
				if found:
					break
		"reveal":
			if cands.size() > 0:
				cands.sort_custom(func(x, y): return nodes[x].depth < nodes[y].depth)
				nodes[cands[0]].revealed = true
				changed = [cands[0]]
		"hide":
			var kids: Array = nodes[current_id].children
			var rev: Array = []
			for n in nodes:
				if n.revealed and n.state == "open" and n.id != current_id and not kids.has(n.id) and n.type != "boss":
					rev.append(n.id)
			if rev.size() > 0:
				var pick: int = rev[rng.randi() % rev.size()]
				nodes[pick].revealed = false
				changed = [pick]
	if changed.size() > 0:
		_layout()
		for id in changed:
			_flash[id] = 1.0
			if mode == "sprout" and not _pc.has(id):
				var base: int = nodes[id].parents[0]
				_pc[id] = _pc.get(base, 0.5)
		if mode == "sprout":
			_grow = minf(_grow, 0.82)
		queue_redraw()
	return changed


func _any_revealed(ids: Array) -> bool:
	for i in ids:
		if nodes[i].revealed:
			return true
	return false


func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


# ------------------------------------------------------------------ saving
func export_state() -> Dictionary:
	var ns: Array = []
	for n in nodes:
		ns.append(n.duplicate(true))
	return {"seed": map_seed, "origin": origin_id, "hero": hero_id, "depth_max": depth_max,
		"current": current_id, "boss": boss_id, "mut": mut_count, "mrolls": mystery_rolls,
		"since_dilemma": since_dilemma, "mhist": mystery_hist.duplicate(), "nodes": ns}


func import_state(d: Dictionary) -> void:
	map_seed = int(d.get("seed", 0))
	origin_id = str(d.get("origin", ""))
	hero_id = str(d.get("hero", ""))
	depth_max = int(d.get("depth_max", 9))
	current_id = int(d.get("current", 0))
	boss_id = int(d.get("boss", -1))
	mut_count = int(d.get("mut", 0))
	mystery_rolls = int(d.get("mrolls", 0))
	since_dilemma = int(d.get("since_dilemma", 0))
	mystery_hist = d.get("mhist", {}).duplicate()
	nodes.clear()
	for n in d.get("nodes", []):
		var m: Dictionary = {"id": int(n.id), "type": str(n.type), "depth": int(n.depth), "children": [], "parents": [],
			"revealed": bool(n.revealed), "state": str(n.state), "path": str(n.path)}
		for c in n.children:
			m.children.append(int(c))
		for p in n.parents:
			m.parents.append(int(p))
		if n.has("resolved"):
			m["resolved"] = str(n.resolved)
		nodes.append(m)
	_layout()
	_pc = _tx.duplicate()
	_al.clear()
	_grow = 1.0
	queue_redraw()


# ------------------------------------------------------------------ layout
func _layout() -> void:
	_tx.clear()
	var st := {"u": 0.0}
	var raw: Dictionary = {}
	_lay(0, st, raw)
	var umax: float = maxf(float(st.u) - 1.0, 0.001)
	for id in raw:
		_tx[id] = (raw[id] / umax - 0.5) * 2.0
	_tx[boss_id] = 0.0


## Leaves get slots (wider gaps between branches that split near the root); parents sit between first/last child.
func _lay(id: int, st: Dictionary, raw: Dictionary) -> float:
	var n: Dictionary = nodes[id]
	var u := 0.0
	if n.depth >= depth_max - 1 or n.children.is_empty():
		u = st.u
		st.u += 1.0
	else:
		var first := 0.0
		var last := 0.0
		for i in n.children.size():
			if i > 0:
				st.u += 0.25 + 0.9 * pow(1.0 - float(n.depth) / depth_max, 1.5)
			var cu := _lay(n.children[i], st, raw)
			if i == 0:
				first = cu
			last = cu
		u = (first + last) * 0.5
	raw[id] = u
	return u


# ------------------------------------------------------------------ view
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)


func restart_growth() -> void:
	_grow = 0.0


func _ease(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


func _process(dt: float) -> void:
	_time += dt
	_grow = minf(_grow + dt / 3.0, 1.0)
	var k := minf(1.0, dt * 5.0)
	for id in _tx:
		_pc[id] = _pc.get(id, _tx[id]) + (_tx[id] - _pc.get(id, _tx[id])) * k
	for n in nodes:
		var tgt := 0.16 if n.state == "withered" else 1.0
		_al[n.id] = _al.get(n.id, 1.0) + (tgt - _al.get(n.id, 1.0)) * minf(1.0, dt * 2.2)
		_hov[n.id] = _hov.get(n.id, 0.0) + ((1.0 if n.id == _hover_id else 0.0) - _hov.get(n.id, 0.0)) * minf(1.0, dt * 12.0)
		if _flash.has(n.id):
			_flash[n.id] -= dt * 0.8
			if _flash[n.id] <= 0.0:
				_flash.erase(n.id)
	queue_redraw()


func _f(d: int) -> float:
	if d <= 0:
		return 0.0
	if d >= depth_max:
		return 1.0
	return 0.18 + 0.58 * float(d - 1) / float(maxi(depth_max - 2, 1))


## Upward canopy: start at the bottom, boss at the crown, angle = branch direction.
func point_for(id: int, ang: float, area: Vector2) -> Vector2:
	var o := Vector2(area.x * 0.5, area.y - 58.0)
	var ry := area.y - 58.0 - 62.0
	var rx := (area.x * 0.5 - 62.0) / (0.76 * sin(SPREAD))
	var d: int = nodes[id].depth
	if d >= depth_max:
		return o + Vector2(0, -ry)
	return point_for_polar(ang * SPREAD, d, area)


func point_for_polar(th: float, d: int, area: Vector2) -> Vector2:
	var o := Vector2(area.x * 0.5, area.y - 58.0)
	var ry := area.y - 58.0 - 62.0
	var rx := (area.x * 0.5 - 62.0) / (0.76 * sin(SPREAD))
	var f := _f(d)
	return o + Vector2(sin(th) * rx * f, -cos(th) * ry * f)


func target_point(id: int, area: Vector2 = Vector2(960, 640)) -> Vector2:
	return point_for(id, _tx.get(id, 0.0), area)


func _area() -> Vector2:
	return size if size.x > 10.0 else Vector2(960, 640)


func _pt(id: int) -> Vector2:
	return point_for(id, _pc.get(id, _tx.get(id, 0.0)), _area())


func _appear(depth: int) -> float:
	return _ease(_grow * float(depth_max + 1) - float(depth) + 0.3)


func _node_at(p: Vector2) -> int:
	for id in reachable_ids():
		if _pt(id).distance_to(p) < 26.0:
			return id
	return -1


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var h := _node_at(ev.position)
		if h != _hover_id:
			_hover_id = h
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if h >= 0 else Control.CURSOR_ARROW
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var h := _node_at(ev.position)
		if h >= 0:
			choose(h)
			accept_event()


func _col(t: String) -> Color:
	return COLS.get(t, Color(0.8, 0.8, 0.9))


func _word(key: String) -> Array:
	if Lexicon.has_concept(key):
		return Lexicon.word_for(key)
	return []


func _draw() -> void:
	if nodes.is_empty():
		return
	if backdrop:
		_draw_backdrop()
	for n in nodes:
		for c in n.children:
			_draw_edge(n, nodes[c])
	for n in nodes:
		_draw_node(n)
	if _hover_id >= 0:
		var n: Dictionary = nodes[_hover_id]
		var nm := Lexicon.display_name("loc:" + n.type) if n.revealed else ""
		if nm != "":
			var p := _pt(_hover_id) + Vector2(-30, -34)
			draw_string(ThemeDB.fallback_font, p, nm, HORIZONTAL_ALIGNMENT_CENTER, 60, 13, Color(1, 0.92, 0.7))


func _draw_backdrop() -> void:
	var w := size.x
	var h := size.y
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([Color(0.02, 0.02, 0.05), Color(0.03, 0.02, 0.07), Color(0.01, 0.05, 0.06), Color(0.01, 0.03, 0.04)]))
	for i in 5:
		var c := Vector2(w * (0.1 + 0.2 * i), h * (0.3 + 0.35 * fmod(i * 0.61, 1.0)))
		var col := Color(0.1, 0.6, 0.55) if i % 2 == 0 else Color(0.5, 0.2, 0.7)
		for r in 6:
			draw_circle(c, 150.0 - r * 22.0, Color(col.r, col.g, col.b, 0.014))
	if not nodes.is_empty():
		var o := Vector2(w * 0.5, h - 58.0)
		for d in range(1, depth_max):
			var pr := PackedVector2Array()
			for i in 41:
				var th := (float(i) / 40.0 * 2.0 - 1.0) * SPREAD
				pr.append(point_for_polar(th, d, Vector2(w, h)))
			draw_polyline(pr, Color(0.3, 0.8, 0.75, 0.05), 1.0, true)
		draw_circle(o, 12.0, Color(0.4, 0.9, 0.8, 0.05))
	var dr := RandomNumberGenerator.new()
	dr.seed = 77
	for i in 60:
		var bx := dr.randf() * w
		var by := dr.randf() * h
		var sp := 6.0 + dr.randf() * 10.0
		var y := fposmod(by - _time * sp, h)
		var a := 0.15 + 0.2 * (0.5 + 0.5 * sin(_time * 1.3 + i))
		draw_circle(Vector2(bx + sin(_time * 0.4 + i) * 8.0, y), 1.1, Color(0.7, 0.95, 0.9, a))
	draw_rect(Rect2(3, 3, w - 6, h - 6), Color(0.95, 0.75, 0.35, 0.55), false, 1.6, true)
	draw_rect(Rect2(8, 8, w - 16, h - 16), Color(0.95, 0.75, 0.35, 0.18), false, 1.0, true)


func _ctrl(pa: Vector2, pb: Vector2, sv: int) -> Array:
	var ar := _area()
	var o := Vector2(ar.x * 0.5, ar.y - 58.0)
	var ta := (pa - o).normalized() if pa.distance_to(o) > 1.0 else Vector2.UP
	var tb := (pb - o).normalized()
	var ln := pa.distance_to(pb)
	if pb.x == o.x and pb.y < 100.0 and pa.y > pb.y + 40.0:   # crown: leaves gather up into the boss
		ta = ta.lerp((pb - pa).normalized(), 0.55).normalized()
		tb = Vector2.UP.lerp((pb - pa).normalized(), 0.5).normalized()
	var perp := (pb - pa).orthogonal().normalized() * sin(sv * 1.7) * ln * 0.12
	return [pa + ta * ln * 0.42 + perp, pb - tb * ln * 0.42 + perp]


func _bez(a: Vector2, b: Vector2, t: float, cc: Array) -> Vector2:
	var u := 1.0 - t
	return a * u * u * u + cc[0] * 3.0 * u * u * t + cc[1] * 3.0 * u * t * t + b * t * t * t


func _bw(d: int) -> float:
	return 1.5 + 7.0 * pow(1.0 - float(d) / depth_max, 1.7)


func _draw_edge(a: Dictionary, b: Dictionary) -> void:
	var pa := _pt(a.id)
	var pb := _pt(b.id)
	var p := _ease(_grow * float(depth_max + 1) - float(a.depth))
	if p <= 0.01:
		return
	var al: float = _al.get(b.id, 1.0)
	var col := Color(0.22, 0.72, 0.66, 0.46)
	var boost := 1.0
	var live := false
	var onpath: bool = (a.state == "done" or a.state == "current") and (b.state == "done" or b.state == "current")
	if onpath:
		col = Color(1.0, 0.82, 0.4, 0.95)
	elif a.id == current_id and b.state == "open":
		var pl := 0.5 + 0.5 * sin(_time * 3.0)
		col = Color(0.4, 0.95, 1.0, 0.6 + 0.4 * pl)
		boost = 1.4
		live = true
	elif b.state == "withered" or a.state == "withered":
		col = Color(0.5, 0.35, 0.42, 0.6)
	elif not b.revealed:
		col = Color(0.55, 0.4, 0.9, 0.32)
	col.a *= al
	var sv: int = a.id * 7 + b.id * 13
	var cc := _ctrl(pa, pb, sv)
	var steps := 16
	var pts := PackedVector2Array()
	for i in steps + 1:
		pts.append(_bez(pa, pb, p * float(i) / steps, cc))
	var wa := _bw(a.depth) * boost
	var wb := _bw(b.depth) * boost
	draw_polyline(pts, Color(col.r, col.g, col.b, col.a * 0.13), (wa + wb) * 1.6, true)
	for i in steps:
		draw_line(pts[i], pts[i + 1], col, lerpf(wa, wb, float(i) / steps), true)
	if live and p > 0.9:
		for k in 2:
			var t := fposmod(_time * 0.5 + k * 0.5, 1.0)
			draw_circle(_bez(pa, pb, t, cc), 2.6, Color(0.9, 1.0, 1.0, 0.9 * sin(t * PI)))
	if p > 0.5 and al > 0.3 and b.type != "boss" and pa.distance_to(pb) > 34.0:
		var mid := _bez(pa, pb, 0.5, cc)
		var ang := (_bez(pa, pb, 0.56, cc) - _bez(pa, pb, 0.44, cc)).angle()
		for s in [-1.0, 1.0]:
			_twig(mid, ang + s * (0.8 + 0.2 * sin(sv)), 8.0 + (sv % 4), 3, Color(col.r, col.g, col.b, col.a * 0.45), sv)


func _twig(p: Vector2, ang: float, ln: float, d: int, col: Color, sv: int) -> void:
	if d <= 0:
		return
	var q := p + Vector2.from_angle(ang) * ln
	draw_line(p, q, col, 0.9 + d * 0.3, true)
	_twig(q, ang - 0.55 + 0.1 * sin(sv + d), ln * 0.68, d - 1, col, sv)
	_twig(q, ang + 0.55 + 0.1 * cos(sv + d), ln * 0.68, d - 1, col, sv)


func _draw_node(n: Dictionary) -> void:
	var ap := _appear(n.depth)
	if ap <= 0.02:
		return
	var id: int = n.id
	var p := _pt(id)
	var al: float = _al.get(id, 1.0) * ap
	var is_boss: bool = n.type == "boss"
	var rad := (25.0 if is_boss else 16.0) * (0.6 + 0.4 * ap)
	var reach: bool = reachable_ids().has(id)
	var hov: float = _hov.get(id, 0.0)
	rad *= 1.0 + 0.16 * hov
	var shown: String = "mystery" if (not n.revealed and n.type != "start") else n.type
	var col := _col(shown if n.revealed or n.type == "start" else "mystery")
	if n.state == "withered":
		col = col.lerp(Color(0.5, 0.45, 0.5), 0.7)
	var pulse := 0.5 + 0.5 * sin(_time * 3.2)
	# glow
	var gl: float = 0.07 + (0.12 * pulse if (reach or n.state == "current") else 0.0) + 0.3 * _flash.get(id, 0.0)
	for r in 5:
		draw_circle(p, rad + 5.0 + r * 5.0, Color(col.r, col.g, col.b, gl * al * (1.0 - r * 0.18)))
	if n.state != "withered":
		var pn := 6 if not is_boss else 10
		var pl: float = (0.55 if (reach or n.state == "current") else 0.28) * al
		for i in pn:
			var a := TAU * i / pn + _time * 0.25 + id
			var q := p + Vector2.from_angle(a) * (rad + 3.0)
			draw_line(q, q + Vector2.from_angle(a) * (4.0 + 3.0 * pulse), Color(col.r, col.g, col.b, pl), 1.6, true)
	draw_circle(p, rad, Color(0.025, 0.03, 0.06, 0.96 * al))
	var ring := col
	ring.a = al
	if n.state == "done":
		ring = Color(1.0, 0.82, 0.4, al * 0.9)
	var wd := 2.4 if n.state != "done" else 3.0
	draw_arc(p, rad, 0.0, TAU, 36, ring, wd, true)
	if is_boss:
		draw_arc(p, rad + 6.0, 0.0, TAU, 40, Color(col.r, col.g, col.b, al * 0.6), 1.4, true)
		for i in 8:
			var a := TAU * i / 8.0 + _time * 0.3
			draw_line(p + Vector2.from_angle(a) * (rad + 8.0), p + Vector2.from_angle(a) * (rad + 15.0), Color(col.r, col.g, col.b, al * 0.7), 1.6, true)
	if n.state == "current":
		var e := fposmod(_time * 0.8, 1.0)
		draw_arc(p, rad + 4.0 + e * 22.0, 0.0, TAU, 40, Color(1.0, 0.85, 0.45, (1.0 - e) * al), 2.0, true)
	elif reach:
		draw_arc(p, rad + 5.0 + pulse * 4.0, 0.0, TAU, 36, Color(0.4, 0.95, 1.0, 0.5 * al), 1.6, true)
	# contents
	if not n.revealed and n.type != "start":
		_draw_veil(p, rad, al)
		return
	var key: String = "loc:" + n.type
	if n.type == "start":
		key = ""
	var word := _word(key)
	if word.size() > 0:
		GlyphGen.draw(self, word[0], p, rad * 1.55, Color(col.r, col.g, col.b, al), 1.8)
		var roots := word.slice(1)
		var sz := 11.0 if not is_boss else 17.0
		var below: bool = is_boss or n.type == "start"
		var side := 1.0 if p.x >= _area().x * 0.5 else -1.0
		var rc := p + Vector2(0, rad + sz * 0.8 + 2.0)
		var nm := p + Vector2(-34, rad + sz * 1.9 + 4.0)
		if not below:
			rc = p + Vector2(side * (rad + 12.0 + (roots.size() - 1) * sz * 0.55), 0)
			nm = p + Vector2(side * (rad + 12.0 + (roots.size() - 1) * sz * 0.55) - 34.0, sz + 7.0)
		var sx := rc.x - (roots.size() - 1) * sz * 0.55
		for i in roots.size():
			GlyphGen.draw(self, roots[i], Vector2(sx + i * sz * 1.1, rc.y), sz, Color(col.r, col.g, col.b, al * 0.85), 1.2)
		if Lexicon.is_known(key):
			draw_string(ThemeDB.fallback_font, nm, Lexicon.readable_name(key), HORIZONTAL_ALIGNMENT_CENTER, 68, 11, Color(1, 0.92, 0.75, al * 0.85))
	else:
		draw_circle(p, rad * 0.3, Color(col.r, col.g, col.b, al))
	if n.type == "mystery" or (n.has("resolved") and n.state == "current"):
		draw_string(ThemeDB.fallback_font, p + Vector2(rad * 0.55, -rad * 0.5), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.85, 0.5, al))


func _draw_veil(p: Vector2, rad: float, al: float) -> void:
	var c := Color(0.62, 0.45, 0.95)
	for i in 3:
		var a0 := _time * (0.6 + i * 0.25) + i * 2.1
		draw_arc(p, rad * (0.35 + i * 0.22), a0, a0 + 2.3, 14, Color(c.r, c.g, c.b, al * (0.5 - i * 0.1)), 1.6, true)
	var w := _word("loc:mystery")
	if w.size() > 0:
		GlyphGen.draw(self, w[0], p, rad * 1.2, Color(c.r, c.g, c.b, al * 0.35), 1.2)
	draw_string(ThemeDB.fallback_font, p + Vector2(-5, 5), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.8, 1.0, al * 0.7))
