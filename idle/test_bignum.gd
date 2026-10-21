extends SceneTree

var fails := 0

func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		print("FAIL: ", msg)

func _init() -> void:
	var a := BigNum.of(1500.0)
	check(a.e == 3 and is_equal_approx(a.m, 1.5), "normalise")
	check(BigNum.of(999.0).add(BigNum.of(1.0)).cmp(BigNum.of(1000.0)) == 0, "add carry")
	check(BigNum.of(5.0).add(BigNum.make(1.0, 40)).e == 40, "add dominated")
	check(is_equal_approx(BigNum.of(12.0).mul(BigNum.of(10.0)).to_float(), 120.0), "mul")
	check(BigNum.make(2.0, 30).mul(BigNum.make(3.0, 20)).cmp(BigNum.make(6.0, 50)) == 0, "mul big")
	check(BigNum.of(2.0).pow_i(10).cmp(BigNum.of(1024.0)) == 0, "pow")
	check(is_equal_approx(BigNum.of(1.15).pow_i(10).to_float(), pow(1.15, 10)), "pow frac")
	check(BigNum.of(3.0).cmp(BigNum.of(4.0)) == -1 and BigNum.make(1.0, 9).cmp(BigNum.of(5.0)) == 1 and BigNum.new().cmp(BigNum.new()) == 0, "cmp")
	check(BigNum.of(10.0).sub(BigNum.of(4.0)).cmp(BigNum.of(6.0)) == 0 and BigNum.of(1.0).sub(BigNum.of(2.0)).is_zero(), "sub")
	check(BigNum.of(0.0).fmt() == "0", "zero str")
	check(BigNum.of(999.0).fmt() == "999", "999")
	check(BigNum.of(12345.0).fmt() == "12,345", "commas")
	check(BigNum.of(1234567.0).fmt() == "1.23M", "M: " + BigNum.of(1234567.0).fmt())
	check(BigNum.make(4.5, 9).fmt() == "4.50B", "B")
	check(BigNum.make(1.0, 12).fmt() == "1.00T", "T")
	check(BigNum.make(1.234, 45).fmt() == "1.23e45", "sci: " + BigNum.make(1.234, 45).fmt())
	check(BigNum.of(0.4).fmt(1) == "0.4", "decimals")
	check(BigNum.from_array(BigNum.make(7.5, 22).to_array()).cmp(BigNum.make(7.5, 22)) == 0, "array roundtrip")
	check(is_equal_approx(BigNum.of(5.0).ratio(BigNum.of(10.0)), 0.5), "ratio")
	print("test_bignum fails=", fails)
	quit(1 if fails > 0 else 0)
