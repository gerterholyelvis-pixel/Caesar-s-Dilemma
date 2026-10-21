class_name BigNum
extends RefCounted
## Non-negative big number: mantissa in [1,10) times 10^exponent (zero is mantissa 0). Small and immutable-by-convention:
## every operation returns a new BigNum.

const NAMES: Array[String] = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]

var m := 0.0
var e := 0


static func of(x: float) -> BigNum:
	return make(x, 0)


static func make(mant: float, exp: int) -> BigNum:
	var b := BigNum.new()
	if mant <= 0.0 or is_nan(mant):
		return b
	var shift := int(floor(log(mant) / log(10.0)))
	b.m = mant / pow(10.0, shift)
	b.e = exp + shift
	if b.m >= 10.0:          # float rounding at the boundary
		b.m /= 10.0
		b.e += 1
	elif b.m < 1.0:
		b.m *= 10.0
		b.e -= 1
	return b


func is_zero() -> bool:
	return m == 0.0


func add(o: BigNum) -> BigNum:
	if is_zero():
		return o
	if o.is_zero():
		return self
	var d := e - o.e
	if d > 17:
		return self
	if d < -17:
		return o
	if d >= 0:
		return make(m + o.m / pow(10.0, d), e)
	return make(o.m + m / pow(10.0, -d), o.e)


func mul(o: BigNum) -> BigNum:
	if is_zero() or o.is_zero():
		return BigNum.new()
	return make(m * o.m, e + o.e)


func mul_f(f: float) -> BigNum:
	return make(m * f, e)


## Saturating subtraction (never below zero).
func sub(o: BigNum) -> BigNum:
	if cmp(o) <= 0:
		return BigNum.new()
	var d := e - o.e
	if d > 17:
		return self
	return make(m - o.m / pow(10.0, d), e)


func pow_i(n: int) -> BigNum:
	if is_zero():
		return BigNum.new() if n > 0 else BigNum.of(1.0)
	var lg := (log(m) / log(10.0) + e) * n
	var ex := int(floor(lg))
	return make(pow(10.0, lg - ex), ex)


func cmp(o: BigNum) -> int:
	if is_zero() or o.is_zero():
		return 0 if (is_zero() and o.is_zero()) else (-1 if is_zero() else 1)
	if e != o.e:
		return -1 if e < o.e else 1
	if is_equal_approx(m, o.m):
		return 0
	return -1 if m < o.m else 1


func gte(o: BigNum) -> bool:
	return cmp(o) >= 0


func to_float() -> float:
	return 0.0 if is_zero() else m * pow(10.0, e) if e < 300 else INF


## Ratio self/o clamped to [0,1] (progress bars).
func ratio(o: BigNum) -> float:
	if o.is_zero():
		return 1.0
	if is_zero():
		return 0.0
	var d := e - o.e
	if d < -6:
		return 0.0
	if d > 6:
		return 1.0
	return clampf(m * pow(10.0, d) / o.m, 0.0, 1.0)


func to_array() -> Array:
	return [m, e]


static func from_array(a: Variant) -> BigNum:
	if a is Array and (a as Array).size() == 2:
		return make(float(a[0]), int(a[1]))
	return BigNum.new()


## 1,234 below one million; 1.23M ... 999Dc; then 1.23e39. `dec` decimals for values under 1000 (rates).
func fmt(dec := 0) -> String:
	if is_zero():
		return "0"
	if e < 3:
		var v := to_float()
		return String.num(v, dec) if dec > 0 else commas(int(floor(v + 0.0000001)))
	if e < 6:
		return commas(int(floor(to_float())))
	var tier := e / 3
	if tier < NAMES.size():
		var scaled := m * pow(10.0, e - tier * 3)
		return ("%.2f" % scaled if scaled < 10.0 else "%.1f" % scaled if scaled < 100.0 else "%.0f" % scaled) + NAMES[tier]
	return "%.2fe%d" % [m, e]


static func commas(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
