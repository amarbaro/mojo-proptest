"""Same work as tests/bench.mojo with Hypothesis: N passing cases of lists(integers(-1000, 1000), max_size=16),
then one planted failure (sum >= 1000) shrunk to minimal. No database, no deadline, no health checks."""
import time
from hypothesis import given, settings, strategies as st, HealthCheck
N = 20000
S = settings(max_examples=N, database=None, deadline=None, suppress_health_check=list(HealthCheck), derandomize=True)
L = st.lists(st.integers(-1000, 1000), max_size=16)
@S
@given(L)
def always(xs): assert len(xs) <= 16
@settings(S, max_examples=500)
@given(L)
def no_big_sums(xs): assert sum(xs) < 1000
t0 = time.perf_counter_ns(); always(); t1 = time.perf_counter_ns(); msg = ""
try: no_big_sums()
except AssertionError as e: msg = "falsified"
t2 = time.perf_counter_ns()
print("gen_us_per_case", (t1 - t0) / 1000 / N, "shrink_ms", (t2 - t1) / 1e6, "|", msg)
