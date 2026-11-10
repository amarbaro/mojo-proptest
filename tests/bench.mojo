# Generation and shrinking cost: N passing cases of Lists(Ints(-1000, 1000)), then one planted failure shrunk to minimal.
# Same work as tools/bench_oracle.py (Hypothesis).
from std.time import perf_counter_ns
from mproptest import check, Ints, Lists


def always(xs: List[Int]) raises -> Bool:
    return len(xs) <= 16


def no_big_sums(xs: List[Int]) raises -> Bool:
    var s = 0
    for x in xs:
        s += x
    return s < 1000


def main() raises:
    comptime N = 20000
    var t0 = perf_counter_ns()
    check(Lists(Ints(-1000, 1000)), always, n=N)
    var t1 = perf_counter_ns()
    var msg = String()
    try:
        check(Lists(Ints(-1000, 1000)), no_big_sums, seed=5)
    except e:
        msg = String(e)
    var t2 = perf_counter_ns()
    print("gen_us_per_case", Float64(t1 - t0) / 1000.0 / Float64(N), "shrink_ms", Float64(t2 - t1) / 1e6, "|", msg)
