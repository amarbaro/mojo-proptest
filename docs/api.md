# API

Everything is in `mproptest` (`src/mproptest/__init__.mojo`).

## `check`

`check[G: Gen](g: G, prop: def(G.T) thin raises -> Bool, n: Int = 500, seed: Int = 1) raises`

Runs `prop` on `n` values from `g`. Case `i` of a seed always gets the same value. A case fails
when `prop` returns `False` or raises. The first failing case is shrunk (at most 10,000 shrink
candidates tried), then `check` raises
`mproptest: falsified at case <i> (seed=<seed>); minimal: <value>`. All cases passing returns.

`prop` takes one argument. For several, use `Lists` or write a generator that builds a struct.

## Generators

| type | values | shrinks toward |
|---|---|---|
| `Ints(lo: Int, hi: Int)` | uniform in `[lo, hi]`; the full Int64 range works | 0, or the bound nearest 0, halving the distance |
| `Byte()` | `UInt8` in `[0, 255]` | `0` |
| `Floats()` | a quarter from `0.0, -0.0, 1, -1, inf, -inf, nan`; the rest finite over 20 decades | `0.0`, then `v / 2` |
| `OneOf[V](items: List[V])` | an item of the list | earlier items, the first is simplest |
| `Lists[G](elem: G, max_len: Int = 16)` | `List[G.T]` of up to `max_len` elements | drop elements, then shrink each element |
| `Strings(max_len: Int = 8, pool: List[String] = ["a", "é", "日", "😀"])` | strings from `pool` (1 to 4 byte UTF-8 by default) | drop characters, then earlier pool entries |

`Lists(Byte())` generates bytes.

## Your own generator: `trait Gen`

```
comptime T: Copyable & Deinitable & Writable
def gen(self, mut r: Rng) -> Self.T
def shrink(self, v: Self.T) -> List[Self.T]     # simpler candidates, simplest first
def show(self, v: Self.T) -> String             # optional; default String(v)
```

## `Rng`

SplitMix64. `Rng(seed: Int, idx: Int = 0)`, `next() -> UInt64`, `below(n: Int) -> Int` (in `[0, n)`).
`check` builds `Rng(seed, i)` for case `i`.
