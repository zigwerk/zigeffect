# ZigEffect Agent-First Testing Platform Implementation Plan

Date: 2026-07-10
Design: `docs/superpowers/specs/2026-07-10-zigeffect-agent-first-testing-platform-design.md`

**Goal:** Deliver M112–M120 end to end as one public, requirement-aware,
causal, deterministic, replayable testing platform for agent-built ZigEffect
applications.

**Method:** Red test first for every behavior. Runtime and standard-library
capability belongs under `src`; extend the existing CLI and Workbench rather
than creating new core report tools. Preserve unrelated statechart and Court
Series work. Every milestone ends with focused verification and no completion
claim without passing evidence.

## M112 — Testing contracts and receipts

- [x] Add red tests for Scenario validation, duplicate/secret/unsafe values,
  status truth, completeness, source references, assertions, limitations,
  minimal cases, replay commands, and JSON round trips.
- [x] Add `contract.zig` with `Scenario`, `FaultProfile`, `TestStatus`,
  `AssertionStatus`, `AssertionResult`, `Completeness`, `MinimalCase`,
  `MemorySummary`, `CausalSummary`, `TestReceipt`, and `TestRunReceipt`.
- [x] Add bounded/redacted JSON formatting and owned parsing for receipt v1.
- [x] Add all-allocation-failure coverage for receipt builders/parsers.
- [x] Export contracts through `zstd.Testing` and the std public API test.
- [x] Verify `cd packages/zigeffect-std && zig build test`.

## M113 — Scoped TestContext and fixtures

- [x] Add red tests for init/deinit, deterministic time, causal attachment,
  assertion/artifact ownership, limitations, receipt assembly, and partial OOM.
- [x] Add `context.zig` wrapping `fx.TestEnv` and `fx.CausalStore` without
  duplicating core fake services.
- [x] Add typed `FixtureRegistry(T)` with replacement, lookup, cleanup, and
  duplicate policy.
- [x] Expose core service/layer access, application-owned provider composition,
  and bounded artifact links.
- [x] Add `finish`/`finishAlloc` that derive truthful status and completeness.
- [x] Verify std tests/examples and Debug/ReleaseSafe context tests.

## M114 — Assertion and causal matcher library

- [x] Add red tests for boolean/equality/string/semantic JSON/secret assertions.
- [x] Add Exit/Cause success/failure/interruption/defect/finalizer assertions.
- [x] Add event/sequence/finding/service/resource/fiber/application fact matchers.
- [x] Add schedule/retry/workflow/replay/memory assertions.
- [x] Record every assertion with stable ID, source reference, causal IDs,
  expected/actual summaries, and bounded repair hint before returning failure.
- [x] Add human text and agent JSON assertion reports.
- [x] Port/reuse private core assertion behavior without cross-package test
  imports.
- [x] Verify focused std assertions plus full core public API tests.

## M115 — Deterministic fault matrix

- [x] Add red tests for stable case IDs/order, positive bounds, truncation,
  first-failure versus exhaustive behavior, and deterministic replay.
- [x] Add fault cases for none, OOM, schedule, timeout, cancellation,
  interruption, spawn, retry, process, HTTP, SQL, crash, corruption, executor.
- [x] Add generic bounded `runMatrix` callback contract and collection receipt.
- [x] Bridge tracked allocator/all-allocation failures and schedule explorer.
- [x] Add deterministic built-in fake adapter helpers for process/HTTP/SQL.
- [x] Add crash/corruption plan structures reusable by workflow/statechart tests.
- [x] Record unsupported platform cases explicitly.
- [x] Verify std fault tests and core schedule/tracked allocator tests in Debug
  and ReleaseSafe.

## M116 — Schema generators and shrinking

- [x] Add red tests for deterministic seeds, booleans, bounded integers,
  strings, enums, optionals, arrays, structs, unions, and custom generators.
- [x] Add Schema-derived valid generation respecting constraints.
- [x] Add named invalid generation with expected issue path.
- [x] Add deterministic shrinkers and bounds for scalar, string, collection,
  struct, and sequence values.
- [x] Add property runner with minimal counterexample, shrink history, replay,
  and receipt integration.
- [x] Fail explicitly for transforms without a supplied lawful generator.
- [x] Add all-allocation-failure coverage for owned generated/shrunk values.
- [x] Verify std generator/property tests and examples.

## M117 — Semantic snapshots and fixture registry

- [x] Add red tests for text, semantic JSON, JSONL sets, causal shapes,
  application facts, workflow/statechart/test receipts, and ignored fields.
- [x] Add snapshot schema/version/digest, safe fixture path validation, bounded
  normalization, redaction, comparison, and diff summary.
- [x] Add explicit plan/apply update contract; normal compare never writes.
- [x] Add parser compatibility fixtures for current/legacy/future schemas.
- [x] Add test fixture root policy and secret/corrupt/truncated rejection.
- [x] Add allocation-failure coverage.
- [x] Verify std snapshots plus workflow/statechart artifact compatibility.

## M118 — Agent testing protocol and CLI

- [x] Add red project tests for `test_scenarios` validation and coverage.
- [x] Add optional manifest test scenarios and additive v1 JSON compatibility.
- [x] Add CLI parser tests for test list/run/affected/explain/replay/snapshot and
  `project test --agent` selection.
- [x] Implement list filtering by requirement/component/tag.
- [x] Implement run/replay using only manifest-owned command IDs and bounded
  seed/fault metadata.
- [x] Implement affected selection from source roots plus dependent components,
  with honest limitations.
- [x] Persist atomic latest/per-scenario test receipts and bounded raw output.
- [x] Implement explain with source/causal citations and copyable next commands.
- [x] Implement snapshot plan/apply with explicit conflict behavior.
- [x] Extend agent status/evidence/next/handoff with stale/failed/incomplete test
  evidence and requirement coverage.
- [x] Add integration tests using real generated projects.
- [x] Verify CLI unit and integration tests.

## M119 — Workbench Tests UX

- [x] Add parser/model red tests for receipt/run schemas, assertions, matrices,
  counterexamples, replay, completeness, baselines, and malformed/future data.
- [x] Add checked-in real generated sample receipts.
- [x] Add Tests navigation and panel with requirement/component/scenario filters.
- [x] Render status counters, assertion/source/causal links, fault matrix,
  minimal case, replay, memory, completeness, and introduced/resolved failures.
- [x] Connect causal event selection to the existing graph.
- [x] Handle empty, running, unsupported, incomplete, truncated, malformed,
  desktop, and narrow-screen states.
- [x] Verify typecheck, Bun tests, production build, and local browser proof.

## M120 — Scaffolds, distribution, and release

- [x] Add generated Scenario/TestContext examples for all five project kinds.
- [x] Add executable project boundary/causal/OOM scenario and library/package
  generator/property scenario.
- [x] Add system API/worker/shared/cross-component scenarios.
- [x] Update generated project manifest scenarios, skills, README, commands,
  acceptance evidence, and Workbench attachment.
- [x] Compile and test every generated root/child in Debug and ReleaseSafe.
- [x] Bump CLI to 0.3.0 and template to 3; update compatibility, completions,
  scaffold digests, snapshots, migration behavior, docs, and release script.
- [x] Add public API stability and schema governance coverage.
- [x] Update root/package/agent/testing docs and roadmap status honestly.
- [x] Run tool hygiene and `git diff --check`.
- [x] Run `bun run zigeffect:local-release` and capture exact final results.
- [x] Generate a real project, run validate/status/next/test/check/handoff, and
  attach the test and safety receipt evidence.

## Final handoff acceptance

- [x] All M112–M120 checklist items are implemented or explicitly recorded as
  unsupported non-required platform capabilities.
- [x] No unrelated user changes are overwritten or committed.
- [x] No new core `tools/` file is added.
- [x] Required tests and release gates pass from the final source tree.
- [x] The Workbench browser proof shows real test evidence with no console errors.
- [x] Final summary distinguishes delivered guarantees from bounded exploration
  and unrun platform-specific sanitizers/fuzz/network integration.
