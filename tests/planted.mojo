# The gate's oracle: five planted bugs, each with a known minimal input, plus a correct property and determinism.
from std.testing import assert_equal, assert_true
from std.math import nan
from mproptest import check, Rng, Gen, Ints, Floats, Lists, Strings, Byte, OneOf


def found[G: Gen](g: G, prop: def(G.T) thin raises -> Bool, want: String, seed: Int = 1) raises -> String:
    """Run `check` expecting a failure; return its message after asserting it names the minimal case `want`."""
    var msg = String()
    try:
        check(g, prop, seed=seed)
    except e:
        msg = String(e)
    assert_true(msg != "", "planted bug not found: want " + want)
    assert_true(msg.endswith("minimal: " + want), msg + " | want " + want)
    assert_true("(seed=" + String(seed) + ")" in msg, msg)
    return msg


# 1. off-by-one in a bound: `<=` where `<` was meant
def in_bounds(x: Int) -> Bool:
    return x >= 0 and x <= 10


def p_bound(x: Int) raises -> Bool:
    return in_bounds(x) == (x >= 0 and x < 10)


# 2. Int overflow on add: doubling a non-negative Int wraps negative
def p_overflow(x: Int) raises -> Bool:
    return x + x >= 0


# 3. UTF-8 cut mid-codepoint: the first byte of a string is not always a character
def cut1(s: String) -> List[UInt8]:
    var b = s.as_bytes()
    return [x for x in b[: min(1, len(b))]]


def valid_utf8(b: List[UInt8]) -> Bool:
    var i = 0
    while i < len(b):
        var c = Int(b[i])
        var n = 1 if c < 0x80 else (2 if 0xC0 <= c < 0xE0 else (3 if 0xE0 <= c < 0xF0 else (4 if 0xF0 <= c < 0xF8 else 0)))
        if n == 0 or i + n > len(b):
            return False
        for k in range(1, n):
            if b[i + k] & 0xC0 != 0x80:
                return False
        i += n
    return True


def p_utf8(s: String) raises -> Bool:
    return valid_utf8(cut1(s))


# 4. indexing an empty list: the peak of [] reads element 0
def get(xs: List[Int], i: Int) raises -> Int:
    if i < 0 or i >= len(xs):
        raise Error("index ", i, " out of range for length ", len(xs))
    return xs[i]


def peak(xs: List[Int]) raises -> Int:
    var best = get(xs, 0)
    for x in xs:
        best = max(best, x)
    return best


def p_peak(xs: List[Int]) raises -> Bool:
    var p = peak(xs)
    for x in xs:
        if x > p:
            return False
    return True


# 5. NaN compare: a float that is neither < 0 nor > 0 is taken for zero
def sign(x: Float64) -> Int:
    return -1 if x < 0 else (1 if x > 0 else 0)


def p_sign(x: Float64) raises -> Bool:
    return sign(x) != 0 or x == 0


# correct properties
def p_reverse(xs: List[Int]) raises -> Bool:
    var r = List[Int]()
    var rr = List[Int]()
    for i in range(len(xs)):
        r.append(xs[len(xs) - 1 - i])
    for i in range(len(r)):
        rr.append(r[len(r) - 1 - i])
    return rr == xs


def p_str_len(s: String) raises -> Bool:
    return (s + s).byte_length() == 2 * s.byte_length() and valid_utf8([b for b in s.as_bytes()])


def p_never(b: UInt8) raises -> Bool:
    return Int(b) < 256


def p_neg(x: Int) raises -> Bool:
    return x > -101


def p_low(x: Int) raises -> Bool:
    return x >= -5


def p_pick(s: String) raises -> Bool:
    return s != "c"


def main() raises:
    _ = found(Ints(-20, 20), p_bound, "10")
    _ = found(Ints(0, Int.MAX), p_overflow, "4611686018427387904")
    _ = found(Strings(), p_utf8, '"é"')
    _ = found(Lists(Ints(-9, 9)), p_peak, "[]")
    _ = found(Floats(), p_sign, "nan")
    _ = found(Ints(Int.MIN, Int.MAX), p_low, "-6")   # the whole Int range, abs(Int.MIN) overflows
    _ = found(Ints(-1000, 1000), p_neg, "-101")   # negatives shrink toward 0 too
    # shrinking: a list drops to the one element that matters, a pick shrinks to the first failing item
    _ = found(Lists(Ints(0, 1000)), fn_big, "[500]")
    _ = found(OneOf(["a", "b", "c", "d"]), p_pick, "c")
    assert_true(len(Ints(Int.MIN, Int.MAX).shrink(Int.MIN)) < 70, "shrinking Int.MIN must end")
    assert_true(len(Ints(Int.MIN, Int.MAX).shrink(Int.MAX)) < 70, "shrinking Int.MAX must end")
    # a correct property passes 10k cases
    check(Lists(Ints(-100, 100)), p_reverse, n=10_000, seed=3)
    check(Strings(), p_str_len, n=10_000, seed=3)
    check(Lists(Byte(), 32), fn_bytes, n=10_000)
    # same seed, same case: identical messages and identical generated values
    var a = found(Ints(0, Int.MAX), p_overflow, "4611686018427387904", seed=7)
    var b = found(Ints(0, Int.MAX), p_overflow, "4611686018427387904", seed=7)
    assert_equal(a, b)
    var g = Lists(Strings())
    var r1 = Rng(7, 3)
    var r2 = Rng(7, 3)
    assert_equal(g.show(g.gen(r1)), g.show(g.gen(r2)))
    var r3 = Rng(7, 3)
    var r4 = Rng(7, 4)
    assert_true(g.show(g.gen(r3)) != g.show(g.gen(r4)), "different cases must differ")
    print("planted: ok")


def fn_big(xs: List[Int]) raises -> Bool:
    for x in xs:
        if x >= 500:
            return False
    return True


def fn_bytes(xs: List[UInt8]) raises -> Bool:
    return len(xs) <= 32
