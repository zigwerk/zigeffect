# zigeffect Roadmap M56-M59 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the next deployability seams for live command hosting, remediation eval artifacts, file-backed discovery ingestion, and provider-shaped ops alerts.

**Architecture:** Keep host-process HTTP helpers in TypeScript workbench tooling. Keep Zig core deterministic by parsing files, formatting request shapes, and writing artifacts through caller-owned sinks instead of owning network IO.

**Tech Stack:** Zig 0.16, Bun tests, Solid workbench TypeScript, existing zigeffect causal services and tools.

---

## Tasks

### Task 1: M56 live engine apply request adapter

**Files:**
- Modify: `packages/zigeffect/workbench/src/liveAttach.ts`
- Modify: `packages/zigeffect/workbench/src/liveAttach.test.ts`

- [x] Add a failing Bun test named `serveLiveEngineCommandApplyRequest validates inboxes and formats engine results`.
- [x] The test should send a `POST` request containing a valid `LiveCommandInboxResponse`, assert the bridge sees the command batch, and assert the JSON response contains `processed`, `applied`, `rejected`, `needs_human_review`, and fixed security/cache headers.
- [x] Add failing checks for non-POST and invalid inbox payload responses.
- [x] Run `bun test packages/zigeffect/workbench/src/liveAttach.test.ts` and confirm `serveLiveEngineCommandApplyRequest` is missing.
- [x] Implement `liveEngineCommandApplyHeaders`, `jsonLiveEngineResponse`, and `serveLiveEngineCommandApplyRequest`.
- [x] Re-run `bun test packages/zigeffect/workbench/src/liveAttach.test.ts`.

### Task 2: M57 remediation decision eval artifact persistence

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/tools/causal_remediation_decision.zig`

- [x] Add a failing tool test named `approved remediation decision writes linked eval manifest artifacts`.
- [x] The test should exercise a new helper with an in-memory artifact sink and assert one diff artifact, one link artifact, and one manifest artifact are written with the expected schemas and remediation decision path.
- [x] Run `cd packages/zigeffect && zig build examples` and confirm the core eval writer is not imported/called by the remediation decision tool.
- [x] Import `zigeffect` into the `causal_remediation_decision` tool module.
- [x] Add stable remediation eval diff/link/manifest path helpers for default and scenario decisions.
- [x] Add `writeDecisionEvalArtifacts` using `runAgentEvalAndWriteLinkedDiffManifest` with the existing bounded suspended-fiber eval.
- [x] Call the writer only for approved local decisions after the decision JSON/text artifacts are written.
- [x] Re-run `cd packages/zigeffect && zig build examples`.

### Task 3: M58 file-backed service-discovery snapshot loader

**Files:**
- Modify: `packages/zigeffect/src/cluster/transport.zig`
- Modify: `packages/zigeffect/src/cluster/root.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/cluster_transport_test.zig`

- [x] Add a failing Zig test named `service discovery loads provider snapshot json from file`.
- [x] The test should write a governed snapshot JSON file into a temporary directory, load it through the new API, refresh an `InMemoryClusterTransportServiceDiscovery`, and select `runner-file-safe.internal`.
- [x] Run `cd packages/zigeffect && zig build test-raw` and confirm the file loader API is missing.
- [x] Implement `loadClusterTransportServiceDiscoverySnapshotJsonFile(allocator, io, dir, path)`.
- [x] Export the loader through `cluster/root.zig` and `src/zigeffect.zig`.
- [x] Run `zig fmt` and re-run `cd packages/zigeffect && zig build test-raw`.

### Task 4: M59 provider-shaped ops alert request adapter

**Files:**
- Modify: `packages/zigeffect/src/services/causal_ops_alert.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/causal_ops_alert_test.zig`

- [x] Add a failing Zig test named `ops alert provider adapter formats slack and pagerduty request shapes`.
- [x] The test should assert Slack and PagerDuty request bodies are provider-shaped, use fixed JSON/no-store/nosniff headers, and redact sentinel labels/details.
- [x] Run `cd packages/zigeffect && zig build test-raw` and confirm the provider adapter API is missing.
- [x] Add `CausalOpsAlertProviderKind`, `CausalOpsAlertProviderOptions`, and `formatCausalOpsAlertProviderRequest`.
- [x] Add `deliverCausalOpsAlertProvider` to send the provider request through the existing HTTP sink.
- [x] Export the new types/functions.
- [x] Run `zig fmt` and re-run `cd packages/zigeffect && zig build test-raw`.

### Task 5: Docs, gates, and commit

**Files:**
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/2026-06-24-future-agent-briefing.md`
- Modify: this plan file

- [x] Update roadmap status and add M56-M59 milestone cards.
- [x] Update the future-agent briefing from M55 to M59.
- [x] Run `bun test packages/zigeffect/workbench/src/liveAttach.test.ts`.
- [x] Run `bun run zigeffect:workbench:test`.
- [x] Run `bun run zigeffect:workbench:typecheck`.
- [x] Run `bun run zigeffect:workbench:build`.
- [x] Run `cd packages/zigeffect && zig build test-raw`.
- [x] Run `cd packages/zigeffect && zig build examples`.
- [x] Run `bun run zigeffect:test`.
- [x] Run `cd packages/zigeffect-zio && zig build test`.
- [x] Run `packages/zigeffect/tools/check_tool_hygiene.sh`.
- [x] Run `git diff --check`.
- [x] Run `bun run zigeffect:release`.
- [x] Commit M56-M59.

## Verification Log

- RED M56: `bun test packages/zigeffect/workbench/src/liveAttach.test.ts` failed because `serveLiveEngineCommandApplyRequest` was not exported.
- GREEN M56: the same focused Bun command passed with 22 tests after adding the apply request adapter.
- RED M57: `cd packages/zigeffect && zig build examples` failed because `writeDecisionEvalArtifacts` was missing from `causal_remediation_decision`.
- GREEN M57: `cd packages/zigeffect && zig build examples` exited 0 after wiring the remediation decision eval artifact writer.
- RED M58: `cd packages/zigeffect && zig build test-raw` failed because `loadClusterTransportServiceDiscoverySnapshotJsonFile` was not exported.
- GREEN M58: `cd packages/zigeffect && zig build test-raw` exited 0 after adding the file-backed snapshot loader and facade exports.
- RED M59: `cd packages/zigeffect && zig build test-raw` failed because `formatCausalOpsAlertProviderRequest` was not exported.
- GREEN M59: `cd packages/zigeffect && zig build test-raw` exited 0 after adding provider-shaped alert request formatting and exports.
- FULL M56-M59: `bun test packages/zigeffect/workbench/src/liveAttach.test.ts` passed with 22 tests.
- FULL M56-M59: `bun run zigeffect:workbench:test` passed with 82 tests.
- FULL M56-M59: `bun run zigeffect:workbench:typecheck` exited 0 after fixing the nullable test capture.
- FULL M56-M59: `bun run zigeffect:workbench:build` exited 0.
- FULL M56-M59: `cd packages/zigeffect && zig build test-raw` exited 0.
- FULL M56-M59: `cd packages/zigeffect && zig build examples` exited 0.
- FULL M56-M59: `bun run zigeffect:test` exited 0.
- FULL M56-M59: `cd packages/zigeffect-zio && zig build test` exited 0.
- FULL M56-M59: `packages/zigeffect/tools/check_tool_hygiene.sh` passed with 46 tool files.
- FULL M56-M59: `git diff --check` exited 0.
- FULL M56-M59: `bun run zigeffect:release` exited 0 and wrote release gate reports.
