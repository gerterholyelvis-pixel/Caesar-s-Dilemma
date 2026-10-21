class_name Economy
extends RefCounted
## Tier 0 idle economy: Sap, tapping the Seed, and the first generator (Sprout). Pure logic, fixed-step, deterministic.

const STEP := 0.1                  # fixed simulation step in seconds
const SPROUT_BASE_COST := 10.0
const SPROUT_GROWTH := 1.15
const SPROUT_RATE := 0.4           # Sap per second per Sprout
const TAP_BASE := 1.0
const PANEL_UNLOCK_TAPS := 5       # the Sprout offer appears after this many taps
const OFFLINE_CAP := 7200.0        # seconds of offline time that count
const OFFLINE_EFFICIENCY := 0.5
const SAVE_VERSION := 1

var sap := BigNum.new()
var total_earned := BigNum.new()
var taps := 0
var sprouts := 0
var panel_unlocked := false
var _acc := 0.0


func tap_value() -> BigNum:
	return BigNum.of(TAP_BASE)


func sap_per_sec() -> BigNum:
	return BigNum.of(SPROUT_RATE * sprouts)


func sprout_cost(n := -1) -> BigNum:
	var k := sprouts if n < 0 else n
	var c := BigNum.of(SPROUT_BASE_COST).mul(BigNum.of(SPROUT_GROWTH).pow_i(k))
	return BigNum.of(ceilf(c.to_float())) if c.e < 15 else c


func can_buy_sprout() -> bool:
	return sap.gte(sprout_cost())


func tap() -> BigNum:
	var v := tap_value()
	_gain(v)
	taps += 1
	if taps >= PANEL_UNLOCK_TAPS:
		panel_unlocked = true
	return v


func buy_sprout() -> bool:
	if not can_buy_sprout():
		return false
	sap = sap.sub(sprout_cost())
	sprouts += 1
	return true


## Advances the simulation in fixed steps; returns Sap produced.
func advance(dt: float) -> void:
	_acc += dt
	while _acc >= STEP:
		_acc -= STEP
		if sprouts > 0:
			_gain(sap_per_sec().mul_f(STEP))


## Capped, reduced-efficiency catch-up. Returns the Sap gained.
func apply_offline(seconds: float) -> BigNum:
	var gained := sap_per_sec().mul_f(minf(maxf(seconds, 0.0), OFFLINE_CAP) * OFFLINE_EFFICIENCY)
	_gain(gained)
	return gained


func _gain(v: BigNum) -> void:
	sap = sap.add(v)
	total_earned = total_earned.add(v)


func to_dict() -> Dictionary:
	return {"v": SAVE_VERSION, "sap": sap.to_array(), "total": total_earned.to_array(), "taps": taps,
		"sprouts": sprouts, "panel": panel_unlocked, "saved_at": Time.get_unix_time_from_system()}


func from_dict(d: Dictionary) -> void:
	sap = BigNum.from_array(d.get("sap"))
	total_earned = BigNum.from_array(d.get("total"))
	taps = int(d.get("taps", 0))
	sprouts = maxi(0, int(d.get("sprouts", 0)))
	panel_unlocked = bool(d.get("panel", false)) or taps >= PANEL_UNLOCK_TAPS
