# Design

proptest is 149 lines because it does two things only: generate a value from a seed and case
number, and shrink a failing value greedily. Everything a larger property-testing library adds
(integrated shrinking, a test database, stateful testing) is left out, and a failure still replays
from the seed it prints.

## Every case has its own seed

`check` builds `Rng(seed, i)` for case `i`: SplitMix64 started from `seed ^ (i + 1) * golden`.
A case does not depend on the ones before it, so changing `n` or a generator earlier in a run
does not change case `i`, and the message `falsified at case i (seed=s)` is enough to replay it.

## Shrinking is greedy and bounded

Each generator returns simpler candidates, simplest first. `check` takes the first candidate that
still fails and repeats until none fails. Total candidates tried are capped at 10,000: a shrink
that does not converge (a bug in a custom `Gen`, or a value that never gets simpler) ends with
the best value found instead of looping, so memory and time stay bounded.

- `Ints` halve the distance to 0 (or the nearest bound) in unsigned arithmetic, so the full
  Int64 range shrinks without overflow.
- `Lists` drop elements before shrinking them; `Strings` reuse that over codepoints, so a
  shrunk string is never cut inside a UTF-8 sequence.

## Generators are types, the property is a thin function

`check[G: Gen]` is monomorphised per generator: no boxing, no dynamic dispatch. The generator
comes first because Mojo cannot infer `G.T` from the property alone. A property is a `thin`
function, so it captures nothing. That keeps cases independent.

## A raise is a failure

`_holds` turns any raise from the property into `False`. Code that raises on bad input (a parser,
an index) fails the property without the test wrapping it in `try`.

## How to prove it wrong

`scripts/check.sh` runs five planted bugs; each must be found and shrunk to its known minimal input
(`10`, `4611686018427387904`, `"é"`, `[]`, `nan`). `scripts/selfcheck.sh` applies 10 mutants, 6 to the
library and 4 that fix a planted bug, and the gate must fail on every one.
