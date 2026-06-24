# zigeffect Roadmap M52-M55 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add concrete host-process/provider seams for the remaining roadmap bullets without embedding network IO in the Zig core.

**Architecture:** TypeScript local tooling owns HTTP bridge clients and collector endpoints. Zig core/tooling owns deterministic parsing, sink-based artifact persistence, and runbook metadata formatting.

**Tech Stack:** Zig 0.16, Bun tests, Solid workbench TypeScript, existing zigeffect causal services and tools.

---

## Tasks

### Task 1: M52 HTTP live-engine bridge and frame ingest

**Files:**
- Modify: `packages/zigeffect/workbench/src/liveAttach.ts`
- Modify: `packages/zigeffect/workbench/src/liveAttach.test.ts`
- Modify: `packages/zigeffect/workbench/src/collector/collector.ts`
- Modify: `packages/zigeffect/workbench/src/collector/collector.test.ts`

- [x] Add failing Bun tests for `createHttpLiveEngineCommandBridge` and collector `POST /frames`.
- [x] The bridge test should prove command batches are posted to the engine apply URL, the response is validated, and emitted frames are posted to the collector frames URL.
- [x] The collector test should prove a connected WebSocket client receives a frame posted to `/frames`.
- [x] Run `bun test packages/zigeffect/workbench/src/liveAttach.test.ts packages/zigeffect/workbench/src/collector/collector.test.ts` and confirm missing API/path failures.
- [x] Implement `isLiveCommandEngineBatchResult` and `createHttpLiveEngineCommandBridge`.
- [x] Implement collector frame validation plus `POST /frames`.
- [x] Re-run the focused Bun tests.

### Task 2: M53 service-discovery snapshot JSON adapter

**Files:**
- Modify: `packages/zigeffect/src/cluster/transport.zig`
- Modify: `packages/zigeffect/src/cluster/root.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/cluster_transport_test.zig`

- [x] Add a failing Zig test named `service discovery parses provider snapshot json and refreshes registry`.
- [x] The test should parse a `zigeffect.cluster.service-discovery-snapshot.v1` JSON document, refresh an `InMemoryClusterTransportServiceDiscovery`, and select `runner-json-safe.internal`.
- [x] Run `cd packages/zigeffect && zig build test-raw` and confirm the parse API is missing.
- [x] Add schema constants, `ClusterTransportOwnedServiceDiscoverySnapshot`, JSON structs, and `parseClusterTransportServiceDiscoverySnapshotJson`.
- [x] Export the owned snapshot type, schema constants, and parser through `cluster/root.zig` and `src/zigeffect.zig`.
- [x] Run `zig fmt` and re-run `cd packages/zigeffect && zig build test-raw`.

### Task 3: M54 dev-loop linked eval artifact persistence

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/tools/causal_loop.zig`

- [x] Add a failing tool test proving the dev-loop eval artifact writer emits diff, link, and manifest files with the expected schema/path evidence.
- [x] Run `cd packages/zigeffect && zig build test-raw` or `cd packages/zigeffect && zig build causal-dev-loop-tests` and confirm the helper is missing.
- [x] Import `zigeffect` into the `causal_loop` tool module.
- [x] Add eval diff/link/manifest paths to `LoopPaths`.
- [x] Add `writeDevLoopEvalArtifacts` that calls `runAgentEvalAndWriteLinkedDiffManifest` with a built-in suspended-fiber eval and file sinks.
- [x] Call the writer during `runAfter` after the verdict artifact is written.
- [x] Re-run the focused tool test and `cd packages/zigeffect && zig build test-raw`.

### Task 4: M55 operator runbook endpoint metadata

**Files:**
- Modify: `packages/zigeffect/src/services/causal_ops_alert.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/causal_ops_alert_test.zig`

- [x] Add a failing Zig test named `ops runbook json includes operator endpoint metadata`.
- [x] The test should pass endpoint metadata and expect `artifact_endpoint_path`, `alert_delivery_kind`, and `alert_endpoint_id` in the runbook JSON.
- [x] Run `cd packages/zigeffect && zig build test-raw` and confirm the endpoint metadata API is missing.
- [x] Add `CausalOpsRunbookEndpointMetadata` and an optional `endpoints` field to `CausalOpsRunbookOptions`.
- [x] Render endpoint metadata when present and export the new type.
- [x] Run `zig fmt` and re-run `cd packages/zigeffect && zig build test-raw`.

### Task 5: Docs, gates, and commit

**Files:**
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/2026-06-24-future-agent-briefing.md`
- Modify: this plan file

- [x] Update roadmap status and add M52-M55 milestone cards.
- [x] Update the future-agent briefing from M51 to M55.
- [x] Run `bun test packages/zigeffect/workbench/src/liveAttach.test.ts packages/zigeffect/workbench/src/collector/collector.test.ts`.
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
- [x] Commit M52-M55.

## Verification Log

- RED M52: `bun test packages/zigeffect/workbench/src/liveAttach.test.ts packages/zigeffect/workbench/src/collector/collector.test.ts` failed because `isLiveCommandEngineBatchResult` was not exported and `/frames` returned non-JSON `not found`.
- GREEN M52: the same focused Bun command passed with 29 tests after adding the HTTP bridge client and collector frame ingest.
- RED M53: `cd packages/zigeffect && zig build test-raw` failed because `parseClusterTransportServiceDiscoverySnapshotJson` was missing.
- GREEN M53: `cd packages/zigeffect && zig build test-raw` exited 0 after adding the owned snapshot JSON parser and exports.
- RED M54: `cd packages/zigeffect && zig build examples` failed in `zigeffect-causal-loop` and `zigeffect-causal-loop-tests` because `writeDevLoopEvalArtifacts` was missing.
- GREEN M54: `cd packages/zigeffect && zig build examples` exited 0 after wiring the dev-loop eval artifacts.
- RED M55: `cd packages/zigeffect && zig build test-raw` failed because `CausalOpsRunbookOptions` had no `endpoints` field.
- GREEN M55: `cd packages/zigeffect && zig build test-raw` exited 0 after adding endpoint metadata to runbook JSON.
- FULL M52-M55: `bun test packages/zigeffect/workbench/src/liveAttach.test.ts packages/zigeffect/workbench/src/collector/collector.test.ts` passed with 29 tests.
- FULL M52-M55: `bun run zigeffect:workbench:test` passed with 81 tests.
- FULL M52-M55: `bun run zigeffect:workbench:typecheck` exited 0.
- FULL M52-M55: `bun run zigeffect:workbench:build` exited 0.
- FULL M52-M55: `cd packages/zigeffect && zig build test-raw` exited 0.
- FULL M52-M55: `cd packages/zigeffect && zig build examples` exited 0.
- FULL M52-M55: `bun run zigeffect:test` exited 0.
- FULL M52-M55: `cd packages/zigeffect-zio && zig build test` exited 0.
- FULL M52-M55: `packages/zigeffect/tools/check_tool_hygiene.sh` passed with 46 tool files.
- FULL M52-M55: `git diff --check` exited 0.
- FULL M52-M55: `bun run zigeffect:release` exited 0 and wrote release gate reports.
