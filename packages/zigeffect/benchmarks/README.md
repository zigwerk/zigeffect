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
unexecuted receipt.
