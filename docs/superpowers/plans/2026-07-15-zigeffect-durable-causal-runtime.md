# ZigEffect Durable Causal Application Runtime Implementation Plan

Date: 2026-07-15
Design: `docs/superpowers/specs/2026-07-15-zigeffect-durable-causal-runtime-design.md`
Status: completed and verified

1. Add failing standard-library tests proving that a canonical application
   runtime persists runtime, layer, service, named-effect, and domain events
   without manual causal objects.
2. Add failing tests for the single agent map, durable record and child queries,
   checked shutdown, restart persistence, and concurrent live reads.
3. Make `CausalGraph.LocalDatabase` serialize live query methods with writes
   while preserving its restart-safe WAL and snapshot contract.
4. Implement heap-stable `zstd.ManagedRuntime` ownership of the local graph,
   NenDB backend, bounded store, and kernel managed runtime.
5. Add checked shutdown, causal health, application inspection, agent-map, and
   durable graph query methods.
6. Update the guarded HTTP application-map adapter to prefer the richer agent
   map when the supplied runtime supports it while retaining kernel-runtime
   support.
7. Migrate generated application/service roots away from manual graph/store
   attachment and update scaffold snapshots and documentation.
8. Update canonical guides and architecture documentation to distinguish the
   application runtime from the low-level kernel interpreter.
9. Run ZigEffect, standard-library, HTTP, CLI, generated-project, public API,
   Testing v2 migration, tool hygiene, and documentation validation gates.
10. Inspect every Testing v2 receipt and require complete execution, equal
    discovered/executed counts, zero pending tests, failures, leaks, and logged
    errors.

## Verification evidence

- `packages/zigeffect`: `zig build test --summary all` passed; the main
  Testing v2 receipt reports 979/979 and the NenDB backend receipt 11/11.
- `packages/zigeffect-std`: `zig build test --summary all` passed 285/285,
  including 280/280 main tests and 3/3 durable-runtime tests; `zig build
  examples --summary all` passed all 34 steps and 13/13 tests.
- `packages/zigeffect-http`: 30/30 passed with a complete receipt.
- `packages/zigeffect-grpc`: 100/100 passed with a complete receipt.
- `packages/zigeffect-cli`: 41/41 passed; `zig build integration-test
  --summary all` passed the complete generated-project matrix.
- Testing v2 migration, tool hygiene, diff whitespace, and changed-Markdown
  local-link checks passed.
