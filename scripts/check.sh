#!/usr/bin/env bash
# The gate: tests/planted.mojo. Five planted bugs (off-by-one in a bound, Int overflow on add, UTF-8 cut
# mid-codepoint, empty-list index, NaN compare) must each be found and shrunk to the known minimal input;
# correct properties pass 10,000 cases; the same seed gives the same case. scripts/selfcheck.sh proves the
# gate fails on wrong code. Every run is capped at 4 GB.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .work
M=${MOJO:-.venv/bin/mojo}
if systemd-run --user --scope -q true 2>/dev/null; then
  cap() { systemd-run --user --scope -q -p MemoryMax=4G -p MemorySwapMax=0 timeout 120 "$@"; }
else
  cap() { (ulimit -v 4194304; timeout 120 "$@"); }
fi
cap $M build -I src tests/planted.mojo -o .work/planted 2>.work/build.err || { echo "FAIL build: tests/planted.mojo"; cat .work/build.err; exit 1; }
cap .work/planted > .work/planted.log 2>&1 || { echo "FAIL planted: $(grep -m1 -oE 'Assert Error: .*|Error: .*' .work/planted.log | cut -c1-200)"; exit 1; }
tail -1 .work/planted.log
for t in examples/quickstart tests/docs; do
  [[ -f $t.mojo ]] && { cap $M run -I src $t.mojo > /dev/null || { echo "FAIL example: $t.mojo"; exit 1; }; }
done
echo "PASS all"
