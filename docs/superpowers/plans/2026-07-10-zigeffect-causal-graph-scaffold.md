# zigeffect Embedded Causal Graph Scaffold Plan

## M108 - Durable Graph Runtime

- [x] Add red tests for graph persistence, parent traversal, restart-safe ids,
  partial-tail recovery, corruption, limits, secrets, and allocation failures.
- [x] Implement and export `zstd.CausalGraph.LocalDatabase` and bounded
  read-only snapshots over the existing NenDB-compatible writer contract.
- [x] Add a compile-tested stdlib example.

## M109 - Agent Query CLI

- [x] Add parser tests for `graph status|event|children`.
- [x] Resolve graph storage only through a validated project manifest.
- [x] Emit stable bounded JSON receipts for summary, event, and child queries.
- [x] Add real filesystem integration tests.

## M110 - Scaffold Integration

- [x] Add `causal_graph` project capability and graph artifact path.
- [x] Generate `src/causal_graph.zig` for applications and services.
- [x] Attach storage before the first fact, record graph artifact evidence,
  flush, and fail honestly on backend errors.
- [x] Update generated tests, README, Git ignore, Workbench attachment, and
  Codex/Claude skills.
- [x] Prove system services use independent graph roots.

## M111 - Compatibility And Release

- [x] Bump CLI/template compatibility versions and shell completions.
- [x] Update all five versioned scaffold snapshots.
- [x] Reconcile roadmap, compatibility, runtime, and operations docs without
  claiming the upstream NenDB package is installed.
- [x] Run focused tests, generated Debug/ReleaseSafe integration, and
  `bun run zigeffect:local-release`.
- [x] Commit the complete capability.

## Verification Evidence

- `zigeffect-std`: 64/64 tests; 11/11 example tests and 28/28 example build
  steps.
- `zigeffect-cli`: 25/25 unit tests; generated-project integration passed all
  five scaffold kinds, real executable graph writes, and system component
  queries in Debug and ReleaseSafe.
- `zigeffect` core: 855/855 Debug and 855/855 ReleaseSafe raw tests; 194/194
  causal package tests; 7/7 public API tests.
- Adapters/UI: Postgres 5/5, QUIC 5/5, zio 21/21, Workbench 269/269 plus
  typecheck and production build.
- `bun run zigeffect:local-release`: passed with Zig 0.16.0 and CLI 0.3.0,
  including redaction, docs honesty, 46-file tool hygiene, and diff checks.
