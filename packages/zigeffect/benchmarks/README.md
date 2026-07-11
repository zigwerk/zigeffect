# Agent development benchmark

The v1 fixture schema compares bounded, reproducible task runs across provider
and language combinations. It records delivery effort, escaped seeded defects,
failure survival, deterministic reproduction, handoff evidence, and runtime
measurements. Score weights are defined in
`zigeffect-std/src/safety/benchmark.zig` and sum to 100 points.

Run the offline comparison from the repository root:

```sh
bun run zigeffect:cli -- benchmark score \
  packages/zigeffect/benchmarks/fixtures/agent-service-repair.v1.json \
  --json --root ../..
```

The checked-in values are illustrative fixtures for schema and scorer
reproducibility, not results from a controlled provider study. They must not be
used to claim general superiority over Zig, Rust, or C. A publishable claim
requires the same frozen task, hardware, toolchains, provider/model versions,
prompt, retry policy, raw transcripts, receipts, and repeated measurements.

The provider conformance suite is a separate protocol/lifecycle gate. Its
checked-in matrix contains the same seven bounded scenarios for Codex and
Claude Code: success, repair, failure, cancellation, approval, large output,
and recovery. The command fails unless both providers cover every scenario and
every case satisfies its lifecycle contract:

```sh
bun run zigeffect:cli -- benchmark conformance \
  packages/zigeffect/benchmarks/fixtures/provider-conformance.v1.json \
  --json --root ../..
```

The report scores compile/test results, acceptance coverage, bounded repair
iterations, causal-query use, secret posture, and handoff completeness. Fixture
text and artifacts are rejected when they contain secret-shaped values;
sequence regressions, duplicate case ids, unsupported schemas, and unbounded
fields fail closed. This is deterministic protocol evidence, not evidence that
one model is smarter or that either provider will solve an arbitrary project.

Real provider execution is intentionally opt-in and outside CI. CI parses and
scores stored fixtures only; it never needs credentials or network access. To
run a real provider adapter, add a fixed command id such as `benchmark-codex` to
`zigeffect.project.json`, create `.zigeffect/provider-benchmarks.enabled`, then
run:

```sh
zigeffect benchmark run --provider codex --command benchmark-codex --json
```

The runner accepts no passthrough argv and can execute only that validated
manifest-owned command. Without the local marker it returns an unavailable,
unexecuted receipt. Only `codex` and `claude` provider ids are accepted, the
command id must use the matching `benchmark-<provider>` prefix, output is
bounded and redacted, and an executed run persists its receipt under
`.zigeffect/receipts/provider-benchmark-<provider>.json`. A missing local
provider executable is reported as unavailable rather than misreported as a
provider failure.
