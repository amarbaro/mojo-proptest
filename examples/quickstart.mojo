from proptest import check, Ints, Lists


def clamp(x: Int) -> Int:
    return min(x, 100)   # bug: forgot the lower bound


def in_range(x: Int) raises -> Bool:
    return -100 <= clamp(x) <= 100


def main() raises:
    try:
        check(Lists(Ints(-1000, 1000)), no_big_sums, seed=5)
    except e:
        print(e)   # proptest: falsified at case 1 (seed=5); minimal: [206, 794]
    try:
        check(Ints(-1000, 1000), in_range)
    except e:
        print(e)   # minimal: -101


def no_big_sums(xs: List[Int]) raises -> Bool:
    var s = 0
    for x in xs:
        s += x
    return s < 1000
