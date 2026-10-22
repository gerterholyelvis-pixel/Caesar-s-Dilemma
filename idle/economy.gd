class_name Economy
extends RefCounted
## Idle economy: Sap, tapping the Seed, the generator ladder (Content.GENS), one-time upgrades, unlock rules, the Gardener
## auto-buyer. Pure logic, fixed-step, deterministic. Piece-1 API (sprouts, buy_sprout...) is kept as thin wrappers.

const STEP := 0.1                  # fixed simulation step in seconds
const SPROUT_BASE_COST := 10.0
const SPROUT_GROWTH := 1.15
const SPROUT_RATE := 0.4           # Sap per second per Sprout (base)
const TAP_BASE := 1.0
const PANEL_UNLOCK_TAPS := 5       # the Sprout offer appears after this many taps
const OFFLINE_CAP := 7200.0        # seconds of offline time that count
const OFFLINE_EFFICIENCY := 0.5
const SAVE_VERSION := 2
const MODES: Array[int] = [1, 10, 100, -1]   # buy modes; -1 = Max

var sap := BigNum.new()
var total_earned := BigNum.new()
var taps := 0
var owned := {}                    # gen id -> count
var upgrades := {}                 # upgrade id -> true
var unlocked := {}                 # unlock id -> true
var play_time := 0.0               # seconds the game has been advanced
var panel_unlocked := false
var seed_type := "plain"           # the central seed (Content.SEEDS); granted e.g. by the Sap Farmer
var seed_level := 0
var fired := {}                    # one-shot milestone ids ("first_sprout", "sprouts_10"): persisted, never repeat
var sprouts: int:
	get: return int(owned.get("sprout", 0))
var events: Array = []             # {"t": "unlock"|"auto", "id": String}; the UI drains this
var _acc := 0.0
var _gard_t := 0.0


# ------------------------------------------------------------------------------------------ generators

func count(id: String) -> int:
	return int(owned.get(id, 0))


func gen_visible(id: String) -> bool:
	var g := Content.gen(id)
	if g.is_empty():
		return false
	var u: String = g["unlock"]
	return panel_unlocked if u == "" else bool(unlocked.get(u, false))


## Cost of ONE generator when `k` are already owned (rounded up while small).
func cost_at(id: String, k: int) -> BigNum:
	var g := Content.gen(id)
	var c := BigNum.of(g["cost"]).mul(BigNum.of(g["growth"]).pow_i(k))
	return BigNum.of(ceilf(c.to_float())) if c.e < 15 else c


## Closed form for buying n more with k owned: base * r^k * (r^n - 1) / (r - 1).
func bulk_cost(id: String, n: int, k := -1) -> BigNum:
	var g := Content.gen(id)
	var kk := count(id) if k < 0 else k
	if n <= 1:
		return cost_at(id, kk)
	var r: float = g["growth"]
	var c := BigNum.of(g["cost"]).mul(BigNum.of(r).pow_i(kk)).mul(BigNum.of(r).pow_i(n).sub(BigNum.of(1.0))).mul_f(1.0 / (r - 1.0))
	return BigNum.of(ceilf(c.to_float())) if c.e < 15 else c


## Largest n with bulk_cost(n) <= sap (0 when even one is unaffordable).
func max_affordable(id: String) -> int:
	var g := Content.gen(id)
	var k := count(id)
	var r: float = g["growth"]
	var first := cost_at(id, k)
	if not sap.gte(first):
		return 0
	var x := sap.mul_f(r - 1.0)
	var base := BigNum.of(g["cost"]).mul(BigNum.of(r).pow_i(k))
	var q := minf(x.to_float() / maxf(base.to_float(), 1.0e-300), 1.0e15) if x.e < 290 and base.e < 290 else 1.0e15
	var n := maxi(1, int(floor(log(1.0 + q) / log(r))))
	while n > 1 and not sap.gte(bulk_cost(id, n, k)):
		n -= 1
	while n < 100000 and sap.gte(bulk_cost(id, n + 1, k)):
		n += 1
	return n


## How many a purchase in `mode` would buy right now (Max: all affordable, at least 1 for display).
func mode_count(id: String, mode: int) -> int:
	return maxi(1, max_affordable(id)) if mode < 0 else mode


func can_buy(id: String, n: int) -> bool:
	return gen_visible(id) and n >= 1 and sap.gte(bulk_cost(id, n))


func buy(id: String, n: int) -> bool:
	if not can_buy(id, n):
		return false
	sap = sap.sub(bulk_cost(id, n))
	owned[id] = count(id) + n
	if id == "sprout":
		_fire("first_sprout")
		if count(id) >= 10:
			_fire("sprouts_10")
	return true


func _fire(id: String) -> void:
	if not fired.has(id):
		fired[id] = true
		events.append({"t": "milestone", "id": id})


func milestones_reached(id: String) -> int:
	var c := count(id)
	var m := 0
	for t in Content.MILESTONES:
		if c >= t:
			m += 1
	return m


## Next milestone threshold for `id`, or -1 when all are reached.
func next_milestone(id: String) -> int:
	var m := milestones_reached(id)
	return Content.MILESTONES[m] if m < Content.MILESTONES.size() else -1


## Progress 0..1 from the previous milestone (or 0) to the next one.
func milestone_progress(id: String) -> float:
	var nx := next_milestone(id)
	if nx < 0:
		return 1.0
	var m := milestones_reached(id)
	var prev := Content.MILESTONES[m - 1] if m > 0 else 0
	return clampf(float(count(id) - prev) / float(nx - prev), 0.0, 1.0)


## {base, ms, up, all, each}: the factors of one generator's Sap/s.
func rate_parts(id: String) -> Dictionary:
	var g := Content.gen(id)
	var up := 1.0
	var al := 1.0
	for uid in upgrades:
		var u := Content.upgrade(uid)
		if u.is_empty():
			continue
		if u["kind"] == "gen_mul" and u["target"] == id:
			up *= float(u["value"])
		elif u["kind"] == "all_mul":
			al *= float(u["value"])
	var ms := pow(2.0, milestones_reached(id))
	var base: float = g["rate"]
	return {"base": base, "ms": ms, "up": up, "all": al, "each": base * ms * up * al}


func rate_each(id: String) -> float:
	return float(rate_parts(id)["each"])


func sap_per_sec() -> BigNum:
	var s := 0.0
	for g in Content.GENS:
		var c := count(g["id"])
		if c > 0:
			s += c * rate_each(g["id"])
	return BigNum.of(s)


# ------------------------------------------------------------------------------------------ tapping

func tap_value() -> BigNum:
	return tap_value_at(seed_type, seed_level)


## Tap value for a hypothetical seed type / level (tooltips, tests); the maths is in tap_parts().
func tap_value_at(stype: String, level: int) -> BigNum:
	var p := tap_parts(stype, level)
	var out := BigNum.of(float(p["flat"]) * float(p["mul"]))
	if float(p["pct"]) > 0.0:
		out = out.add(sap_per_sec().mul_f(float(p["pct"])))
	return out


## {flat, mul, seed_mul, up, pct}: (1 + level_add x L) x (seed tap_mul x level_mul^L x upgrade multipliers) + pct x Sap/s.
func tap_parts(stype: String, level: int) -> Dictionary:
	var sd := Content.seed_def(stype)
	var flat := TAP_BASE + float(sd.get("level_add", 0.0)) * level
	var smul: float = float(sd["tap_mul"]) * pow(float(sd.get("level_mul", 1.0)), level)
	var pct: float = float(sd["pct"])
	var up := 1.0
	for uid in upgrades:
		var u := Content.upgrade(uid)
		if u.is_empty():
			continue
		if u["kind"] == "tap_mul":
			up *= float(u["value"])
		elif u["kind"] == "tap_pct":
			pct += float(u["value"])
	return {"flat": flat, "mul": smul * up, "seed_mul": smul, "up": up, "pct": pct}


func grant_seed(id: String) -> bool:
	if Content.seed_def(id)["id"] != id or id == seed_type:
		return false
	seed_type = id
	seed_level = 0
	events.append({"t": "seed", "id": id})
	return true


func seed_has_levels() -> bool:
	return Content.seed_def(seed_type).has("level_cost")


func seed_level_cost(level := -1) -> BigNum:
	var sd := Content.seed_def(seed_type)
	var l := seed_level if level < 0 else level
	return BigNum.of(ceilf(float(sd["level_cost"]) * pow(float(sd["level_growth"]), l)))


func can_buy_seed_level() -> bool:
	return seed_has_levels() and seed_level < int(Content.seed_def(seed_type)["max_level"]) and sap.gte(seed_level_cost())


func buy_seed_level() -> bool:
	if not can_buy_seed_level():
		return false
	sap = sap.sub(seed_level_cost())
	seed_level += 1
	return true


func seed_effect() -> String:
	return "Tap %s Sap now, %s at the next level" % [tap_value().fmt(2), tap_value_at(seed_type, seed_level + 1).fmt(2)]


func seed_tooltip() -> String:
	var sd := Content.seed_def(seed_type)
	var p := tap_parts(seed_type, seed_level)
	var q := tap_parts(seed_type, seed_level + 1)
	var s := "%s, level %d\n" % [sd["name"], seed_level]
	s += "Tap now: (1 + %s x %d) x %s seed x %s upgrades = %s, plus %s%% of Sap/s = %s Sap\n" % [
		_num(float(sd["level_add"])), seed_level, _num(float(p["seed_mul"])), _num(float(p["up"])),
		BigNum.of(float(p["flat"]) * float(p["mul"])).fmt(2), _num(float(p["pct"]) * 100.0), tap_value().fmt(2)]
	s += "Next level: (1 + %s x %d) x %s seed x %s upgrades = %s, plus %s%% of Sap/s = %s Sap\n" % [
		_num(float(sd["level_add"])), seed_level + 1, _num(float(q["seed_mul"])), _num(float(q["up"])),
		BigNum.of(float(q["flat"]) * float(q["mul"])).fmt(2), _num(float(q["pct"]) * 100.0), tap_value_at(seed_type, seed_level + 1).fmt(2)]
	s += "Cost: %s x %s^%d = %s Sap" % [BigNum.of(sd["level_cost"]).fmt(), _num(float(sd["level_growth"])), seed_level, seed_level_cost().fmt()]
	return s


func tap() -> BigNum:
	var v := tap_value()
	_gain(v)
	taps += 1
	if taps >= PANEL_UNLOCK_TAPS:
		panel_unlocked = true
	return v


# ------------------------------------------------------------------------------------------ upgrades

func has_upgrade(id: String) -> bool:
	return bool(upgrades.get(id, false))


func upgrade_visible(id: String) -> bool:
	if not bool(unlocked.get("tab_upgrades", false)):
		return false
	var u := Content.upgrade(id)
	return not u.is_empty() and (has_upgrade(id) or _clause_ok(u["show"]) or sap.gte(BigNum.of(u["cost"])))


func can_buy_upgrade(id: String) -> bool:
	var u := Content.upgrade(id)
	return not u.is_empty() and not has_upgrade(id) and upgrade_visible(id) and sap.gte(BigNum.of(u["cost"]))


func buy_upgrade(id: String) -> bool:
	if not can_buy_upgrade(id):
		return false
	sap = sap.sub(BigNum.of(Content.upgrade(id)["cost"]))
	upgrades[id] = true
	return true


func affordable_upgrades() -> int:
	var n := 0
	for u in Content.UPGRADES:
		if can_buy_upgrade(u["id"]):
			n += 1
	return n


func upgrade_effect(id: String) -> String:
	var u := Content.upgrade(id)
	var v: float = u["value"]
	match u["kind"]:
		"tap_mul": return "Tap power x%s" % _num(v)
		"tap_pct": return "Each tap also gives %d%% of your Sap per second" % int(round(v * 100.0))
		"gen_mul": return "%s Sap x%s" % [Content.gen(u["target"])["name"], _num(v)]
		"all_mul": return "All plants x%s Sap" % _num(v)
		"auto": return "Buys the cheapest plant you can afford every %ds" % int(Content.GARDENER_INTERVAL)
		"auto_speed": return "The Gardener works %s as fast" % ("twice" if is_equal_approx(v, 0.5) else "faster")
	return ""


static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, round(v)) else String.num(v, 2)


# ------------------------------------------------------------------------------------------ unlocks

func _clause_ok(c: Dictionary) -> bool:
	if c.has("time") and play_time < float(c["time"]):
		return false
	if c.has("total") and total_earned.to_float() < float(c["total"]):
		return false
	if c.has("owned"):
		for k in c["owned"]:
			if count(k) < int(c["owned"][k]):
				return false
	if c.has("unlocked"):
		for k in c["unlocked"]:
			if not bool(unlocked.get(k, false)):
				return false
	if c.has("upgrades"):
		for k in c["upgrades"]:
			if not has_upgrade(k):
				return false
	return true


## Fires every rule whose clauses now hold; returns the newly unlocked ids (also queued in `events`).
func check_unlocks() -> Array[String]:
	var fresh: Array[String] = []
	var again := true
	while again:
		again = false
		for u in Content.UNLOCKS:
			if bool(unlocked.get(u["id"], false)):
				continue
			for c in u["any"]:
				if _clause_ok(c):
					unlocked[u["id"]] = true
					fresh.append(u["id"])
					events.append({"t": "unlock", "id": u["id"]})
					again = true
					break
	return fresh


func gardener_interval() -> float:
	return Content.GARDENER_INTERVAL * (float(Content.upgrade("gardener_2")["value"]) if has_upgrade("gardener_2") else 1.0)


## The Gardener's pick: the cheapest generator (x1) that is visible and affordable; "" when none.
func gardener_pick() -> String:
	var best := ""
	var bc: BigNum = null
	for g in Content.GENS:
		var id: String = g["id"]
		if not gen_visible(id) or not can_buy(id, 1):
			continue
		var c := cost_at(id, count(id))
		if bc == null or c.cmp(bc) < 0:
			best = id
			bc = c
	return best


# ------------------------------------------------------------------------------------------ time

## Advances the simulation in fixed steps.
func advance(dt: float) -> void:
	_acc += dt
	while _acc >= STEP:
		_acc -= STEP
		play_time += STEP
		if panel_unlocked:
			_gain(sap_per_sec().mul_f(STEP))
		if has_upgrade("gardener"):
			_gard_t += STEP
			if _gard_t >= gardener_interval():
				_gard_t = 0.0
				var pick := gardener_pick()
				if pick != "" and buy(pick, 1):
					events.append({"t": "auto", "id": pick})
		check_unlocks()


## Capped, reduced-efficiency catch-up. Returns the Sap gained.
func apply_offline(seconds: float) -> BigNum:
	var gained := sap_per_sec().mul_f(minf(maxf(seconds, 0.0), OFFLINE_CAP) * OFFLINE_EFFICIENCY)
	_gain(gained)
	return gained


func _gain(v: BigNum) -> void:
	sap = sap.add(v)
	total_earned = total_earned.add(v)


# ------------------------------------------------------------------------------------------ piece-1 wrappers

func sprout_cost(n := -1) -> BigNum:
	return cost_at("sprout", sprouts if n < 0 else n)


func can_buy_sprout() -> bool:
	return sap.gte(sprout_cost())


func buy_sprout() -> bool:
	return buy("sprout", 1)


# ------------------------------------------------------------------------------------------ tooltips (exact maths)

func gen_tooltip(id: String, n: int) -> String:
	var g := Content.gen(id)
	var k := count(id)
	var r: float = g["growth"]
	var p := rate_parts(id)
	var cost := bulk_cost(id, n)
	var s := "Buy %d %s\n" % [n, g["name"]]
	if n == 1:
		s += "Cost: %s x %s^%d = %s Sap\n" % [BigNum.of(g["cost"]).fmt(), _num(r), k, cost.fmt()]
	else:
		s += "Cost: %s x %s^%d x (%s^%d - 1) / (%s - 1) = %s Sap\n" % [BigNum.of(g["cost"]).fmt(), _num(r), k, _num(r), n, _num(r), cost.fmt()]
	s += "Rate each: %s base x %s milestone x %s upgrades x %s all = %s Sap/s\n" % [
		_num(p["base"]), _num(p["ms"]), _num(p["up"]), _num(p["all"]), BigNum.of(p["each"]).fmt(2)]
	s += "Total now: %d x %s = %s Sap/s\n" % [k, BigNum.of(p["each"]).fmt(2), BigNum.of(k * float(p["each"])).fmt(1)]
	var nx := next_milestone(id)
	if nx < 0:
		s += "Milestones: all reached (x%s)" % _num(p["ms"])
	else:
		s += "Milestone bonus: x2 %s Sap at %d owned (you have %d, %d to go). Reached so far: x%s" % [g["name"], nx, k, nx - k, _num(p["ms"])]
	return s


func upgrade_tooltip(id: String) -> String:
	var u := Content.upgrade(id)
	return "%s\n%s\nCost: %s Sap%s" % [u["name"], upgrade_effect(id), BigNum.of(u["cost"]).fmt(), "\nOwned" if has_upgrade(id) else ""]


# ------------------------------------------------------------------------------------------ save

func to_dict() -> Dictionary:
	return {"v": SAVE_VERSION, "sap": sap.to_array(), "total": total_earned.to_array(), "taps": taps,
		"owned": owned.duplicate(), "upgrades": upgrades.keys(), "unlocked": unlocked.keys(), "time": play_time,
		"panel": panel_unlocked, "seed": seed_type, "seed_level": seed_level, "fired": fired.keys(), "saved_at": Time.get_unix_time_from_system()}


## Reads v1 (piece 1: sprouts, panel) and v2 saves; tolerant of missing, odd or newer data.
func from_dict(d: Dictionary) -> void:
	sap = BigNum.from_array(d.get("sap"))
	total_earned = BigNum.from_array(d.get("total"))
	taps = maxi(0, int(d.get("taps", 0)))
	owned = {}
	upgrades = {}
	unlocked = {}
	var v := int(d.get("v", 1))
	if v < 2 or not d.has("owned"):
		var sp := maxi(0, int(d.get("sprouts", 0)))
		if sp > 0:
			owned["sprout"] = sp
		play_time = float(taps) / 3.0 + sp * 8.0     # v1 had no clock: a plausible estimate
	else:
		var o: Variant = d.get("owned")
		if o is Dictionary:
			for k in o:
				if not Content.gen(String(k)).is_empty():
					owned[String(k)] = maxi(0, int(o[k]))
		var ul: Variant = d.get("upgrades", [])
		if ul is Array:
			for k in ul:
				if not Content.upgrade(String(k)).is_empty():
					upgrades[String(k)] = true
		var uk: Variant = d.get("unlocked", [])
		if uk is Array:
			for k in uk:
				if not Content.unlock_def(String(k)).is_empty() or String(k).begins_with("tab_"):
					unlocked[String(k)] = true
		play_time = maxf(0.0, float(d.get("time", 0.0)))
	seed_type = String(d.get("seed", "plain"))
	if Content.seed_def(seed_type)["id"] != seed_type:
		seed_type = "plain"
	seed_level = clampi(int(d.get("seed_level", 0)), 0, 1000) if seed_type != "plain" else 0
	fired = {}
	var fl: Variant = d.get("fired", [])
	if fl is Array:
		for k in fl:
			fired[String(k)] = true
	if int(owned.get("sprout", 0)) > 0:        # migrated / restored saves never replay these moments
		fired["first_sprout"] = true
	if int(owned.get("sprout", 0)) >= 10:
		fired["sprouts_10"] = true
	panel_unlocked = bool(d.get("panel", false)) or taps >= PANEL_UNLOCK_TAPS or sprouts > 0
	events.clear()
	check_unlocks()
	events.clear()      # restored unlocks are not new: no flourishes on load
