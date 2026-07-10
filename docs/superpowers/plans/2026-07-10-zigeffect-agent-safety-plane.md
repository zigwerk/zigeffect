# zigeffect Agent Safety Plane Implementation Plan

**Goal:** Deliver the complete `agent_safe_v1` safety plane described in
`docs/superpowers/specs/2026-07-10-zigeffect-agent-safety-plane-design.md`.

**Method:** Test-driven, milestone-by-milestone. Runtime capability belongs
under `src`; expose one CLI workflow instead of adding `causal_*` report tools.
Every milestone ends with focused verification and no completion claim without
passing evidence.

**Delivery result (2026-07-10):** Implemented end to end. The final
`bun run zigeffect:local-release` gate passes stdlib/examples, the installed
CLI and every generated project kind, provider conformance, core Debug and
ReleaseSafe, the 241-step causal release gate, public API review, Postgres,
QUIC, zio, 269 workbench tests/typecheck/build, redaction/honesty checks, and
tool hygiene. A real generated `project check --agent` receipt and browser proof
also pass. ThreadSanitizer, C sanitizer, stack protection, and fuzz are detected
but remain explicit optional `unsupported` gates until a project supplies a
platform-specific manifest-owned target. This is not a claim that arbitrary Zig
or the existing trusted runtime internals are Rust-equivalent memory-safe code.

## M96 - Safety Project Contract

- [ ] Add red tests for profiles, safe/audited roots, gate policies, limits,
  allowance identity, duplicate/stale/unsafe values, JSON round trips, and
  sentinel-secret rejection.
- [ ] Add `SafetyProfile`, `SafetyPolicy`, `SafetyGatePolicy`, `SafetyLimits`,
  `UnsafeAllowance`, and manifest validation to `zstd.Project`.
- [ ] Default generated projects to `agent_safe_v1` without invalidating
  explicitly unmanaged legacy manifests.
- [ ] Document compatibility and fail-closed schema behavior.
- [ ] Run `cd packages/zigeffect-std && zig build test && zig build examples`.

## M97 - Static Safety Analyzer

- [ ] Add red tests covering comments/strings, every governed construct,
  source locations, deterministic ids/fingerprints, zones, allowance matches,
  stale allowances, limits, and redacted JSON.
- [ ] Add `packages/zigeffect-std/src/safety/root.zig` with Zig AST/token-based
  analysis and bounded `StaticSafetyReport` ownership.
- [ ] Export `zstd.Safety` and public compatibility tests.
- [ ] Add fixture corpus containing safe, audited, forbidden, and malformed Zig.
- [ ] Run stdlib focused/full tests and examples.

## M98 - Source References And Causal Correlation

- [ ] Add red core tests for stable `SourceRef`, optional event source ids,
  clone/deinit, redaction, JSON round trip, bounded source-map artifacts, and
  backward-compatible artifacts without source fields.
- [ ] Implement `SourceRef`/`SourceMap` and optional `source_ref_id` on causal
  events without expanding the event-kind taxonomy.
- [ ] Capture source refs in scope/resource/fiber/assertion public helpers.
- [ ] Add causal queries that resolve a finding to a source-map entry.
- [ ] Run core raw tests, causal tests, schema governance, and compatibility.

## M99 - Safe Ownership And Concurrency Kernel

- [ ] Add compile-fail tests for pointer-bearing callback returns and
  non-sendable task messages.
- [ ] Add runtime tests for foreign/stale handles, double close, generation
  reuse, source-linked acquire/use/finalize evidence, and leak-free ownership.
- [ ] Implement `ResourceTable(T)`, `ResourceHandle(T)`, scoped `with`, and
  recursive `assertAgentSendable(T)`.
- [ ] Add pointer-free message entry points for public concurrent task APIs.
- [ ] Inventory existing runtime `*anyopaque` boundaries and require nearby
  `// SAFETY:` contracts in the audited zone.
- [ ] Run compile-fail, resource, structured-concurrency, thread, and full tests.

## M100 - Allocation Safety Evidence

- [ ] Add red tests for allocation/free/remap accounting, OOM, invalid/double
  free suppression, live/peak bytes, concurrency, source capture, limits, and
  causal summary/violation facts.
- [ ] Implement synchronized `TrackedAllocator` and typed source-aware helpers.
- [ ] Add `MemorySafetySnapshot` and receipt conversion.
- [ ] Add `std.testing.checkAllAllocationFailures` coverage for ownership,
  source-map, analyzer, and receipt builders.
- [ ] Verify under Debug and ReleaseSafe.

## M101 - Deterministic Schedule And Fault Explorer

- [ ] Add red model tests for complete exploration, deduplication, smallest
  counterexample, bounds/truncation, cancellation, timeout, spawn failure, OOM,
  and deterministic replay.
- [ ] Implement generic bounded `ScheduleExplorer(Model)` in core runtime.
- [ ] Add stable choice ids at selected queue/STM/timer/fiber boundaries and an
  adapter for effect test programs.
- [ ] Correlate failing schedules with causal events and source refs.
- [ ] Run property/history, race, scheduler fairness, structured concurrency,
  executor equivalence, and full core tests.

## M102 - Safety Receipts And Compiler Capture

- [ ] Add red stdlib tests for receipt verdict logic, required/optional gates,
  unsupported/not-run/truncated handling, baseline diffs, limits, redaction,
  replay commands, and JSON compatibility.
- [ ] Implement `SafetyReceipt`, compiler diagnostic contracts, gate evidence,
  completeness, diff, and score types under `src`.
- [ ] Add CLI tests for manifest discovery, component source discovery, Zig
  compiler version/diagnostic capture, AST/static import, allowed commands,
  atomic receipt writes, and exit status.
- [ ] Implement `zigeffect project check --agent --json`, `safety explain`,
  `safety replay`, and `safety baseline`.
- [ ] Preserve bounded raw compiler output as a redacted artifact and parse
  source spans/reference traces with toolchain version recorded.
- [ ] Run CLI unit/integration tests and real temp-project checks.

## M103 - Compiler And Runtime Gate Matrix

- [ ] Generate and test manifest-owned Debug, ReleaseSafe,
  all-allocation-failure, causal invariant, structural-equivalence, and fuzz
  gates.
- [ ] Add platform capability detection and receipts for ThreadSanitizer,
  C UB sanitizer, stack protection, and fuzz instrumentation.
- [ ] Required unsupported gates must produce `incomplete`.
- [ ] Add seeded defects proving every gate discriminates a real mutation.
- [ ] Add focused root commands and a combined safety gate.

## M104 - Safe Scaffolds And Agent Protocol

- [ ] Add/extend scaffold snapshots for all project kinds with safety policy,
  safe roots, audited adapters, gates, skills, and deterministic examples.
- [ ] Compile/test every generated project in a real temporary directory.
- [ ] Update Codex and Claude skills to require source-linked safety receipts,
  explain incomplete evidence, and prohibit unmanaged escape hatches.
- [ ] Add requirement/acceptance/handoff safety evidence ids.
- [ ] Run CLI, generated-project, stdlib, and local-agent gates.

## M105 - Workbench Safety UX

- [ ] Add model/parser tests for receipts, findings, gates, allowances, source
  maps, memory summaries, schedules, fuzz inputs, and baseline diffs.
- [ ] Add Safety navigation/panel with verdict, completeness, gate matrix,
  source links, unsafe inventory, ownership chains, replay commands, and
  before/after state.
- [ ] Handle empty, malformed, unsupported, truncated, live, desktop, and
  mobile states.
- [ ] Run workbench tests/build and capture a real browser proof using a
  generated project receipt.

## M106 - Provider And Language Benchmarks

- [ ] Add stable benchmark task/score schemas and offline fixtures for Codex,
  Claude, zigeffect/Zig, Rust/Tokio, and C.
- [ ] Score compile/acceptance time, tokens, repair iterations, unsafe changes,
  seeded-defect escapes, failure survival, replay quality, evidence completeness,
  and performance.
- [ ] Add opt-in real provider runner with explicit availability and no network
  dependency in CI.
- [ ] Implement `zigeffect benchmark score <fixture> --json` and comparison
  output with explicit non-claims.
- [ ] Publish reproducible benchmark interpretation.

## M107 - Distribution And Release Gate

- [ ] Add schema migrations/compatibility fixtures for manifest, source map,
  static report, receipt, and benchmark formats.
- [ ] Add public API stability, docs honesty, unsafe inventory, redaction,
  tool-hygiene, generated-project, workbench, and benchmark gates.
- [ ] Run Debug, ReleaseSafe, sanitizer/fuzz capability matrix, full core/std/
  CLI/Postgres/QUIC/zio/workbench tests, and `git diff --check`.
- [ ] Record exact unrun/unsupported gates; resolve all required failures.
- [ ] Deliver a final source-linked safety receipt and evidence-backed handoff.
