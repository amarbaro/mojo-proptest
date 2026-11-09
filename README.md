# mojo-proptest

<!-- badges -->
[![ci](https://github.com/amarbaro/mojo-proptest/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/amarbaro/mojo-proptest/actions/workflows/ci.yml) [![latest release](https://img.shields.io/github/v/release/amarbaro/mojo-proptest)](https://github.com/amarbaro/mojo-proptest/releases/latest) [![license](https://img.shields.io/github/license/amarbaro/mojo-proptest)](https://github.com/amarbaro/mojo-proptest/blob/main/LICENSE) [![checks](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/amarbaro/mojo-proptest/badges/checks.json)](https://github.com/amarbaro/mojo-proptest/actions/workflows/ci.yml)
<!-- /badges -->

<!-- install -->
Install: `pixi workspace channel add https://conda.modular.com/max https://prefix.dev/amarbaro/amarbaro`, then `pixi add mojo-proptest` (import `mproptest`, so it can be installed beside [bpr/proptest](https://github.com/bpr/proptest), whose import is `proptest`). From source: `git clone https://github.com/amarbaro/mojo-proptest`, then `mojo run -I mojo-proptest/src app.mojo`.
Toolchains: Mojo 1.2 stable, and the nightly 1.3.0.dev2026110805 in the weekly [mojo-libs](https://github.com/amarbaro/mojo-libs) matrix (36 libraries on stable, 35 on nightly).

```mojo
from mproptest import check, Ints, Lists


def clamp(x: Int) -> Int:
    return min(x, 100)   # bug: forgot the lower bound


def in_range(x: Int) raises -> Bool:
    return -100 <= clamp(x) <= 100


def main() raises:
    check(Ints(-1000, 1000), in_range)
    # mproptest: falsified at case 0 (seed=1); minimal: -101
```

| Call | Does |
|---|---|
| `check[G: Gen](g, prop, n=500, seed=1)` | Runs `prop` on `n` generated values; raises `mproptest: falsified at case <i> (seed=<seed>); minimal: <value>`. |
| `Ints(lo, hi)`, `Byte()`, `Floats()` | Integers, bytes, floats (special values a quarter of the time). |
| `OneOf[V](items)`, `Lists[G](elem, max_len=16)`, `Strings(max_len=8, pool=...)` | An item of a list, lists of a generator, UTF-8 strings. |
| `trait Gen` | Your own generator: generate from an `Rng`, list simpler candidates. |
<!-- /install -->

Property tests for Mojo in 149 lines: seeded generators, shrinking, and a failure that names the seed and the
smallest case. `check(gen, prop, n=500, seed=1)` runs `prop` on `n` values; `prop` returns `False` or raises to fail.
The same seed gives the same cases, so a failure replays.

Requires Mojo 1.2.

## What you get

- Generators (each also shrinks): `Ints(lo, hi)` (full Int64 range works), `Floats()` (a quarter are 0.0, -0.0, ±1, ±inf, nan),
  `Byte()`, `Strings(max_len, pool)` (ASCII, 2, 3 and 4 byte UTF-8 by default), `Lists(elem, max_len)` (`Lists(Byte())` is bytes),
  `OneOf(items)`.
- Shrinking: numbers halve toward 0, lists drop elements then shrink each, strings drop characters then take earlier pool
  entries, `OneOf` goes toward its first item.
- Your own generator: conform to `Gen` (`T`, `gen`, `shrink`; `show` is optional).
- `check` takes the generator first: Mojo cannot infer the property's argument type from the property alone.
- One argument per property. Several: build a `Lists` or write a generator that makes a struct.

**Limits:** No integrated shrinking, test database or stateful testing. Shrinking is greedy and stops after 10,000 candidates with the best value found. A property is a `thin` function, so it captures nothing.

## Checked

`scripts/check.sh` runs five planted bugs, each found and shrunk to its known minimal input: off-by-one in a bound (`10`),
`Int` overflow on add (`4611686018427387904`), UTF-8 cut mid-codepoint (`"é"`), index of an empty list (`[]`), NaN compare (`nan`).
Also: negatives shrink (`-101`), a correct property passes 10,000 cases (about 55 ms for 30,000 cases in all), the same seed gives
the same case. `scripts/selfcheck.sh` applies 10 mutants (6 to the library, 4 that fix a planted bug) and the gate must fail on each.

API: [docs/api.md](docs/api.md). Design: [docs/design.md](docs/design.md).
