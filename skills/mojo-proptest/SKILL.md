---
name: mojo-proptest
description: "Property tests for Mojo: seeded generators, shrinking, and a failure that names the seed and the smallest case. Use when a Mojo function should hold for all inputs, not for a few hand-picked ones."
metadata:
  short-description: "Property testing for Mojo in 149 lines: seeded generators, shrinking, replayable failures"
---

# mojo-proptest

One file, `src/mproptest/__init__.mojo`, Mojo 1.2, no dependencies.

## When to use

A property (an invariant, a round trip, agreement with a reference) should hold for generated inputs.
The same seed gives the same cases, so a failure replays.

## Install

`mojo run -I src app.mojo` from a clone, or copy `src/mproptest/`.

## The calls

```mojo
from mproptest import check, Ints, Lists, Strings, Floats, Byte, OneOf

def clamp(x: Int) -> Int:
    return min(x, 100)   # bug: no lower bound

def in_range(x: Int) raises -> Bool:
    return -100 <= clamp(x) <= 100

def no_big_sums(xs: List[Int]) raises -> Bool:
    var s = 0
    for x in xs:
        s += x
    return s < 1000

def main() raises:
    try:
        check(Ints(-1000, 1000), in_range)                 # check(gen, prop, n=500, seed=1)
    except e:
        print(e)   # mproptest: falsified at case 0 (seed=1); minimal: -101
    try:
        check(Lists(Ints(-1000, 1000)), no_big_sums, seed=5)
    except e:
        print(e)   # minimal: a short list that still fails
```

## Gotchas

- `check` takes the generator **first**: Mojo cannot infer the property's argument type from the property alone.
- A property returns `False` or raises to fail; `check` then shrinks and raises `mproptest: falsified at case N (seed=S); minimal: ...`.
  Let it propagate in a test, or catch it as above.
- One argument per property. For several, use `Lists` or a generator of your own that builds a struct.
- Generators: `Ints(lo, hi)`, `Floats()` (a quarter are 0.0, -0.0, ±1, ±inf, nan), `Byte()`, `Strings(max_len, pool)`,
  `Lists(elem, max_len)` (`Lists(Byte())` is bytes), `OneOf(items)`. Each also shrinks.
- Your own generator conforms to `Gen`: `T`, `gen(mut Rng)`, `shrink(v)` (simplest first); `show` is optional.
- To replay a failure, pass the seed it printed.

## Gate

`scripts/check.sh` from the repo: five planted bugs, each found and shrunk to its known minimal input.
`scripts/selfcheck.sh` applies 10 mutants and the gate must fail on each.
