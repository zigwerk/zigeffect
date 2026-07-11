# ZigEffect Testing v2 Implementation Plan

Date: 2026-07-10
Design: `docs/superpowers/specs/2026-07-10-zigeffect-testing-v2-design.md`

**Goal:** Deliver the full Testing v2 design through the public stdlib, CLI,
Workbench, generated projects, skills, documentation, and release gates.

**Method:** Use test-driven development for every runtime behavior. Extend
existing runtime modules and the single CLI; do not add report tools. Preserve
all unrelated dirty-worktree changes. A milestone is complete only after its
focused tests pass.

## M121 — Receipt protocol and execution identity

**Status:** delivered.

- [ ] Add red tests for control validation, fixed paths, atomic publication,
  stale/missing/mismatched receipts, secret rejection, and allocation failure.
- [ ] Add `testing/protocol.zig` with control parsing, matching, and publication.
- [ ] Extend `TestContext` with control-selected seed/fault/executor and publish.
- [ ] Add additive execution identity and evidence summaries to receipt v1.
- [ ] Add CLI source revision, dirty marker, command digest, and real duration.
- [ ] Replace synthetic-only CLI success with validated process-receipt ingestion.
- [ ] Verify std and CLI focused tests.

## M122 — Semantic coverage and agent gap queries

**Status:** delivered.

- [ ] Add red tests for target/hit validation, deduplication, required/advisory
  gaps, receipt-derived coverage, truncation, and JSON.
- [ ] Add `testing/coverage.zig` and TestContext coverage recording.
- [ ] Derive default targets from scenario requirements, assertions, fault
  profile, causal cleanup, performance, and sandbox evidence.
- [ ] Add `test coverage` and `test gaps` parsers, JSON schemas, filtering, and
  human output.
- [ ] Add agent next/evidence integration.
- [ ] Verify std/CLI coverage tests.

## M123 — Model and schedule exploration

**Status:** delivered.

- [ ] Add red generic model tests for shortest failure, deadlock, replay,
  deduplication, bounds, and allocation failure.
- [ ] Add typed enum-statechart exploration and union-event factory tests.
- [ ] Record state/transition/event/guard/final coverage and source-linked traces.
- [ ] Add `testing/models.zig`.
- [ ] Add `testing/schedules.zig` over `fx.exploreSchedules`/`replaySchedule`.
- [ ] Add TestContext assertion/evidence integration.
- [ ] Verify std tests plus existing core statechart/schedule suites.

## M124 — Structural generation, shrinking, and differential execution

**Status:** delivered.

- [ ] Add failing property tests for string, optional, array, enum, struct,
  derived-struct, sequence, and custom shrinking.
- [ ] Implement bounded structural shrinking and shrink-path receipts.
- [ ] Add boundary-biased valid/invalid Schema generation.
- [ ] Add red differential tests for equal normalized outputs, mismatch, ignored
  fields, unsupported variants, truncation, and replay.
- [ ] Add `testing/differential.zig` and TestContext integration.
- [ ] Verify std property/differential tests and allocation-failure coverage.

## M125 — Deterministic virtual world and side-effect firewall

**Status:** delivered.

- [ ] Add red virtual-world tests for time/skew, delay, drop, duplicate, reorder,
  partition, queue redelivery, stale/conflicting/partial store operations, crash,
  recovery, replay, bounds, and allocation failure.
- [ ] Add `testing/virtual_world.zig`.
- [ ] Add red firewall tests for default deny, fake allow, explicit real allow,
  source/causal evidence, duplicate decisions, and receipt failure.
- [ ] Add `testing/sandbox.zig` and TestContext ownership.
- [ ] Integrate guards with public local/fake adapter entry points where
  compatible without breaking existing APIs.
- [ ] Verify std tests and direct-OS limitation disclosure.

## M126 — Mutation analysis and performance contracts

**Status:** delivered.

- [ ] Add red mutation tests for stable point/operator IDs, killed/surviving/
  unsupported status, bounds, requirement linkage, replay, and no source writes.
- [ ] Add `testing/mutation.zig` and coverage-gap conversion.
- [ ] Add red performance tests for absolute/relative budgets, deterministic
  metrics, wall-clock noise rules, overflow, baseline plan/apply, and receipt
  verdict integration.
- [ ] Add `testing/budgets.zig` and TestContext metric recording.
- [ ] Verify std tests and release-safe behavior.

## M127 — Stress, history, and complete CLI orchestration

**Status:** delivered.

- [ ] Add bounded multi-seed stress execution through control and process
  receipts.
- [ ] Add atomic run history, regression fingerprints, introduced/resolved
  failures, and history queries.
- [ ] Ensure replay preserves source revision, command digest, seed, fault,
  schedule, executor, model trace, and virtual-world plan.
- [ ] Extend help, completions, parser tests, protocol tests, and CLI integration.
- [ ] Verify all CLI tests.

## M128 — Workbench Testing v2

**Status:** delivered.

- [ ] Add parser/model tests for every additive receipt summary and report.
- [ ] Update real sample evidence.
- [ ] Render protocol health, coverage gaps, model/schedule traces, shrink path,
  differential mismatches, virtual faults, mutants, budgets, firewall, and
  history.
- [ ] Add causal/source/replay interactions and responsive states.
- [ ] Run Bun tests, typecheck, build, and browser verification.

## M129 — Scaffolds, agent skills, and documentation

**Status:** delivered.

- [ ] Update all generated tests to initialize from control and publish receipts.
- [ ] Add representative v2 evidence across application, service, library,
  package, and system scaffolds.
- [ ] Update generated manifests, README, skills, gitignore, compatibility,
  upgrade behavior, and scaffold hashes.
- [ ] Update repository Codex/Claude skills and agent instructions.
- [ ] Update root/package README, testing guide, application guide, and roadmap.
- [ ] Validate every emitted skill.
- [ ] Compile every scaffold kind in Debug and ReleaseSafe.

## M130 — Governance and release proof

**Status:** delivered. The complete `zigeffect:local-release` gate passed on
2026-07-10, including a real generated application proof for native run,
coverage, gaps, replay, stress, history, safety check, and agent handoff.

- [ ] Extend public API stability and schema governance tests.
- [ ] Run std, CLI, core, Workbench, tool-hygiene, formatting, and diff checks.
- [ ] Run the complete local release gate.
- [ ] Generate a real application and prove validate/list/run/coverage/gaps/
  replay/stress/history/check/handoff from its published receipts.
- [ ] Record exact guarantees, bounds, unsupported capabilities, and final test
  counts without overclaiming.
