# Copyright 2026 amarbaro.org. Licensed under the Apache License, Version 2.0.
"""Property tests: seeded generators that shrink, and `check`, which raises with the seed and the minimal case."""
from std.math import inf, nan

struct Rng(Copyable):   # SplitMix64; case i of a seed always starts from the same state
    var s: UInt64
    def __init__(out self, seed: Int, idx: Int = 0):
        self.s = UInt64(seed) ^ (UInt64(idx + 1) * 0x9E3779B97F4A7C15)
    def next(mut self) -> UInt64:
        self.s += 0x9E3779B97F4A7C15
        var z = (self.s ^ (self.s >> 30)) * 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) * 0x94D049BB133111EB
        return z ^ (z >> 31)
    def below(mut self, n: Int) -> Int:
        return Int(self.next() % UInt64(n))

trait Gen(Movable, Deinitable):
    comptime T: Copyable & Deinitable & Writable
    def gen(self, mut r: Rng) -> Self.T: ...
    def shrink(self, v: Self.T) -> List[Self.T]: ...   # simpler candidates, simplest first
    def show(self, v: Self.T) -> String:
        return String(v)

@fieldwise_init
struct Ints(Gen):   # in [lo, hi]; shrinks toward 0 (or the nearest bound) by halving the distance
    comptime T = Int
    var lo: Int
    var hi: Int
    def gen(self, mut r: Rng) -> Int:
        var span = UInt64(self.hi) - UInt64(self.lo)
        var x = r.next()
        return Int(UInt64(self.lo) + (x if span == UInt64.MAX else x % (span + 1)))
    def shrink(self, v: Int) -> List[Int]:
        var t = min(max(0, self.lo), self.hi)
        var o = List[Int]()
        var d = Int((UInt64(v) - UInt64(t) if v > t else UInt64(t) - UInt64(v)) // 2)   # unsigned: no overflow, ends at 0
        var s = 1 if v > t else -1
        if v != t:
            o.append(t)
        while d != 0:
            o.append(v - s * d)
            d //= 2
        return o^

@fieldwise_init
struct Byte(Gen):
    comptime T = UInt8
    def gen(self, mut r: Rng) -> UInt8:
        return UInt8(r.below(256))
    def shrink(self, v: UInt8) -> List[UInt8]:
        return [UInt8(0)] if v > 0 else List[UInt8]()

@fieldwise_init
struct Floats(Gen):   # a quarter special (0.0, -0.0, ±1, ±inf, nan), the rest finite over 20 decades
    comptime T = Float64
    def gen(self, mut r: Rng) -> Float64:
        var sp: List[Float64] = [0.0, -0.0, 1.0, -1.0, inf[DType.float64](), -inf[DType.float64](), nan[DType.float64]()]
        if r.below(4) == 0:
            return sp[r.below(len(sp))]
        return Float64(r.below(2_000_001) - 1_000_000) / 1e6 * 10.0 ** Float64(r.below(21) - 10)
    def shrink(self, v: Float64) -> List[Float64]:
        return [0.0, v / 2] if v - v == 0 and v != 0 else ([0.0] if v != 0 else List[Float64]())

@fieldwise_init
struct OneOf[V: Copyable & Deinitable & Equatable & Writable](Gen):   # shrinks toward the first item
    comptime T = Self.V
    var items: List[Self.V]
    def gen(self, mut r: Rng) -> Self.V:
        return self.items[r.below(len(self.items))].copy()
    def shrink(self, v: Self.V) -> List[Self.V]:
        var o = List[Self.V]()
        for x in self.items:
            if x == v:
                break
            o.append(x.copy())
        return o^

struct Lists[G: Gen](Gen):   # up to max_len elements; shrinks by dropping elements, then shrinking each
    comptime T = List[Self.G.T]
    var elem: Self.G
    var max_len: Int
    def __init__(out self, var elem: Self.G, max_len: Int = 16):
        self.elem = elem^
        self.max_len = max_len
    def gen(self, mut r: Rng) -> List[Self.G.T]:
        var o = List[Self.G.T]()
        for _ in range(r.below(self.max_len + 1)):
            o.append(self.elem.gen(r))
        return o^
    def shrink(self, v: List[Self.G.T]) -> List[List[Self.G.T]]:
        var o = List[List[Self.G.T]]()
        if len(v) > 0:
            o.append(List[Self.G.T]())
        if len(v) > 3:
            o.append(List(v[: len(v) // 2]))
        for i in range(len(v)):
            var c = List(v[:i])
            c.extend(v[i + 1 :])
            o.append(c^)
        for i in range(len(v)):
            for s in self.elem.shrink(v[i]):
                var c = v.copy()
                c[i] = s.copy()
                o.append(c^)
        return o^

struct Strings(Gen):   # characters from `pool` (ASCII, 2, 3 and 4 byte UTF-8); shrinks like Lists, then to earlier pool entries
    comptime T = String
    var chars: Lists[OneOf[String]]
    def __init__(out self, max_len: Int = 8, var pool: List[String] = ["a", "é", "日", "😀"]):
        self.chars = Lists(OneOf(pool^), max_len)
    def gen(self, mut r: Rng) -> String:
        return String("").join(self.chars.gen(r))
    def shrink(self, v: String) -> List[String]:
        var cs = List[String]()
        for c in v.codepoint_slices():
            cs.append(String(c))
        var o = List[String]()
        for c in self.chars.shrink(cs):
            o.append(String("").join(c))
        return o^
    def show(self, v: String) -> String:
        return '"' + v + '"'

def _holds[G: Gen](prop: def(G.T) thin raises -> Bool, v: G.T) -> Bool:
    try:
        return prop(v)
    except:
        return False   # a raise fails too

def check[G: Gen](g: G, prop: def(G.T) thin raises -> Bool, n: Int = 500, seed: Int = 1) raises:
    """Run `prop` on `n` generated values; on a failure (False or a raise) shrink it and raise an Error that
    names the seed, the case number and the minimal value. Same seed, same cases."""
    for i in range(n):
        var r = Rng(seed, i)
        var v = g.gen(r)
        if _holds(prop, v):
            continue
        var steps = 0
        var moved = True
        while moved and steps < 10_000:
            moved = False
            for c in g.shrink(v):
                steps += 1
                if not _holds(prop, c):
                    v = c.copy()
                    moved = True
                    break
        raise Error("proptest: falsified at case ", i, " (seed=", seed, "); minimal: ", g.show(v))
