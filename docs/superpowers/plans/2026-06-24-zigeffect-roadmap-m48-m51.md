# zigeffect Roadmap M48-M51 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build M48-M51 as small adapter primitives that connect live commands, service discovery, eval artifacts, and ops alerts to external host processes without claiming a hosted platform.

**Architecture:** Keep Zig core deterministic and sink/vtable-driven. Keep TypeScript local tooling responsible for collector polling and browser-facing frame emission, with actual engine application supplied by the host process.

**Tech Stack:** Zig 0.16, Bun tests, Solid workbench TypeScript, existing zigeffect causal services.

---

## Tasks

### Task 1: M48 live engine command daemon bridge

**Files:**
- Modify: `packages/zigeffect/workbench/src/liveAttach.ts`
- Modify: `packages/zigeffect/workbench/src/liveAttach.test.ts`

- [x] Write a failing Bun test named `runLiveEngineCommandDaemon bridges command batches to engine frames` that imports `runLiveEngineCommandDaemon`, provides two command inbox batches and one empty batch, uses a fake engine bridge returning one `LiveFrame` per command batch, and expects:
  - fetched URLs advance by cursor;
  - bridge `applyBatch` sees both command batches;
  - `emitFrame` sees returned frames;
  - result includes daemon counts plus `processed`, `applied`, `rejected`, `needs_human_review`, and `emitted_frames`.
- [x] Run `bun test packages/zigeffect/workbench/src/liveAttach.test.ts` and confirm it fails because `runLiveEngineCommandDaemon` is not exported.
- [x] Add `LiveCommandEngineBatchResult`, `LiveCommandEngineBridge`, `LiveEngineCommandDaemonResult`, and `runLiveEngineCommandDaemon` to `liveAttach.ts`.
- [x] Update the stale live-attach file comment to say browser proof exists and the remaining gap is wiring a real running engine process.
- [x] Re-run `bun test packages/zigeffect/workbench/src/liveAttach.test.ts`.

### Task 2: M49 service-discovery snapshot refresh

**Files:**
- Modify: `packages/zigeffect/src/cluster/transport.zig`
- Modify: `packages/zigeffect/src/cluster/root.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/cluster_transport_test.zig`

- [x] Write a failing Zig test named `service discovery refresh imports external snapshots and selects safe endpoint`.
- [x] The test should create an `InMemoryClusterTransportServiceDiscovery`, refresh it from a `ClusterTransportServiceDiscoverySnapshot` with source `"consul-dev"` and two endpoints, and expect `imported == 2`, `registry_size == 2`, `source == "consul-dev"`, and selected host `"runner-safe.internal"`.
- [x] Run `cd packages/zigeffect && zig build test-raw` and confirm it fails because the snapshot/refresh API does not exist.
- [x] Add `ClusterTransportServiceDiscoverySnapshot`, `ClusterTransportServiceDiscoveryRefreshReport`, and `refreshFromSnapshot` on `InMemoryClusterTransportServiceDiscovery`.
- [x] Export the new types through `cluster/root.zig` and `src/zigeffect.zig`.
- [x] Run `zig fmt` on changed Zig files and re-run `cd packages/zigeffect && zig build test-raw`.

### Task 3: M50 linked eval diff manifest writer

**Files:**
- Modify: `packages/zigeffect/src/services/agent_eval.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/agent_eval_test.zig`

- [x] Write a failing Zig test named `agent eval writes diff artifact link and manifest to caller sinks`.
- [x] The test should call `runAgentEvalAndWriteLinkedDiffManifest` with three capture sinks and expect exactly one diff write, one link write, and one manifest write.
- [x] The test should assert the manifest contains `zigeffect.causal.agent-eval-linked-manifest.v1`, the diff path, and the link path.
- [x] Run `cd packages/zigeffect && zig build test-raw` and confirm it fails because the writer helper is missing.
- [x] Add `AgentEvalLinkedDiffArtifactWriteOptions` and `runAgentEvalAndWriteLinkedDiffManifest`.
- [x] Export both names through `src/zigeffect.zig`.
- [x] Run `zig fmt` on changed Zig files and re-run `cd packages/zigeffect && zig build test-raw`.

### Task 4: M51 ops alert webhook request adapter

**Files:**
- Modify: `packages/zigeffect/src/services/causal_ops_alert.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/causal_ops_alert_test.zig`

- [x] Write a failing Zig test named `ops alert webhook adapter sends redacted http request shape`.
- [x] The test should call `deliverCausalOpsAlertWebhook` with an alert containing `sentinel-secret`, capture the request in a fake sink, and expect:
  - `method == "POST"`;
  - `url == "https://alerts.internal/hook"`;
  - fixed `content-type`, `cache-control`, and `x-content-type-options` headers;
  - body contains `zigeffect.causal.ops-alert-delivery.v1`;
  - body does not contain `sentinel-secret`.
- [x] Run `cd packages/zigeffect && zig build test-raw` and confirm it fails because the webhook request API is missing.
- [x] Add `CausalOpsAlertHttpHeader`, fixed alert HTTP headers, `CausalOpsAlertHttpRequest`, `CausalOpsAlertWebhookOptions`, `CausalOpsAlertHttpSink`, `formatCausalOpsAlertWebhookRequest`, and `deliverCausalOpsAlertWebhook`.
- [x] Export the new names through `src/zigeffect.zig`.
- [x] Run `zig fmt` on changed Zig files and re-run `cd packages/zigeffect && zig build test-raw`.

### Task 5: Docs, gates, and commit

**Files:**
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/2026-06-24-future-agent-briefing.md`
- Modify: this plan file

- [x] Update roadmap status and add M48-M51 milestone cards.
- [x] Update the future-agent briefing from M47 to M51 and add the new done items.
- [x] Run `bun test packages/zigeffect/workbench/src/liveAttach.test.ts`.
- [x] Run `bun run zigeffect:workbench:test`.
- [x] Run `bun run zigeffect:workbench:typecheck`.
- [x] Run `bun run zigeffect:workbench:build`.
- [x] Run `cd packages/zigeffect && zig build test-raw`.
- [x] Run `bun run zigeffect:test`.
- [x] Run `cd packages/zigeffect-zio && zig build test`.
- [x] Run `packages/zigeffect/tools/check_tool_hygiene.sh`.
- [x] Run `git diff --check`.
- [x] Run `bun run zigeffect:release`.
- [x] Commit M48-M51.

## Verification Log

- RED M48: `bun test packages/zigeffect/workbench/src/liveAttach.test.ts` failed because `runLiveEngineCommandDaemon` was not exported.
- GREEN M48: `bun test packages/zigeffect/workbench/src/liveAttach.test.ts` passed with 20 tests.
- RED M49: `cd packages/zigeffect && zig build test-raw` failed because `InMemoryClusterTransportServiceDiscovery.refreshFromSnapshot` did not exist.
- GREEN M49: `cd packages/zigeffect && zig build test-raw` exited 0 after adding snapshot refresh and exports.
- RED M50: `cd packages/zigeffect && zig build test-raw` failed because `runAgentEvalAndWriteLinkedDiffManifest` was not exported.
- GREEN M50: `cd packages/zigeffect && zig build test-raw` exited 0 after adding the three-sink writer and exports.
- RED M51: `cd packages/zigeffect && zig build test-raw` failed because `deliverCausalOpsAlertWebhook` did not exist.
- GREEN M51: `cd packages/zigeffect && zig build test-raw` exited 0 after adding the redacted webhook request adapter and exports.
- Focused workbench: `bun test packages/zigeffect/workbench/src/liveAttach.test.ts` passed with 20 tests.
- Workbench: `bun run zigeffect:workbench:test` passed with 79 tests.
- Workbench: `bun run zigeffect:workbench:typecheck` exited 0.
- Workbench: `bun run zigeffect:workbench:build` exited 0.
- Core raw: `cd packages/zigeffect && zig build test-raw` exited 0.
- Package gate: `bun run zigeffect:test` exited 0.
- ZIO adapter: `cd packages/zigeffect-zio && zig build test` exited 0.
- Hygiene: `packages/zigeffect/tools/check_tool_hygiene.sh` passed with 46 tool files.
- Whitespace: `git diff --check` exited 0.
- Release gate: `bun run zigeffect:release` exited 0 and wrote `.zig-cache/release-gate/zigeffect-release-gate.{txt,json}`.
