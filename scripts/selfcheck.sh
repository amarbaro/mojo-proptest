#!/usr/bin/env bash
# Proves the gate rejects wrong code: each mutant is applied to a copy of the tree and scripts/check.sh must FAIL on it.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD
L=src/mproptest/__init__.mojo; T=tests/planted.mojo
mutants=(
  "$L|        while d != 0:|        while False:|Ints shrinks only to its target"
  "$L|        self.s = UInt64(seed) ^ (UInt64(idx + 1) * 0x9E3779B97F4A7C15)|        self.s = UInt64(seed)|every case starts from the same state"
  "$L|        return False   # a raise fails too|        return True|a raise passes"
  "$L|            o.append(c^)|            pass|Lists never drops one element"
  "$L|nan[DType.float64]()]|1.0]|Floats never yields nan"
  "$L|            for c in g.shrink(v):|            for c in List[G.T]():|check never shrinks"
  "$T|return x >= 0 and x <= 10|return x >= 0 and x < 10|planted off-by-one fixed"
  "$T|    return x + x >= 0|    return True|planted overflow fixed"
  "$T|    var best = get(xs, 0)|    var best = get(xs, 0) if len(xs) > 0 else 0|planted empty-list index fixed"
  "$T|    return -1 if x < 0 else (1 if x > 0 else 0)|    return -1 if x < 0 else (1 if x > 0 else (0 if x == 0 else 2))|planted NaN compare fixed"
)
for m in "${mutants[@]}"; do
  IFS='|' read -r file from to why <<< "$m"
  d=$ROOT/.work/mutant; rm -rf "$d"; mkdir -p "$d/.work"
  cp -r src tests scripts "$d"; ln -s "$ROOT/.venv" "$d/.venv"
  .venv/bin/python -I -c 'import sys; p,a,b=sys.argv[1:]; s=open(p).read(); assert a in s, "mutant does not apply: "+a; open(p,"w").write(s.replace(a,b,1))' "$d/$file" "$from" "$to" \
    || { echo "FAIL selfcheck: mutant does not apply ($why)"; exit 1; }
  if "$d/scripts/check.sh" > "$d.log" 2>&1; then echo "FAIL selfcheck: gate passed a mutant ($why)"; exit 1; fi
  echo "selfcheck: rejected ($why): $(grep -m1 FAIL "$d.log" | cut -c1-110)"
done
echo "PASS selfcheck"
