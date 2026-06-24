# zigeffect Roadmap M64-M67 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the next host/operator seams for supervised live engine polling,
continuous NDJSON fact tapping, HTTP discovery refresh, and provider alert retry
reporting.

**Architecture:** Keep network/process ownership outside deterministic core.
TypeScript local tooling owns stream/host helpers; Zig core composes request/
response shapes with caller-owned fetchers and sinks.

**Tech Stack:** Zig 0.16, Bun tests, Solid workbench TypeScript, existing
zigeffect causal services and transport modules.

---

## Tasks

### Task 1: M64 supervised live engine host loop

**Files:**
- Modify: `packages/zigeffect/workbench/src/liveAttach.ts`
- Modify: `packages/zigeffect/workbench/src/liveAttach.test.ts`

- [x] Add a failing Bun test named `runLiveEngineHostSupervisor restarts failed daemon runs and aggregates counters`.
- [x] The test should prove one failed daemon run is reported, the second run succeeds, restart limits are honored, lifecycle events are emitted, and counters are aggregated.
- [x] Run `bun test packages/zigeffect/workbench/src/liveAttach.test.ts` and confirm the supervisor API is missing.
- [x] Add `LiveEngineHostSupervisorOptions`, `LiveEngineHostSupervisorResult`, lifecycle event types, and `runLiveEngineHostSupervisor`.
- [x] Re-run `bun test packages/zigeffect/workbench/src/liveAttach.test.ts`.

### Task 2: M65 continuous NDJSON fact tap

**Files:**
- Modify: `packages/zigeffect/workbench/src/liveAttach.ts`
- Modify: `packages/zigeffect/workbench/src/liveAttach.test.ts`

- [x] Add a failing Bun test named `runLiveEngineNdjsonTap posts complete engine lines and flushes trailing partials`.
- [x] The test should feed chunked NDJSON with a trailing partial line, prove POST bodies contain complete lines only, and prove counts/errors are returned.
- [x] Run `bun test packages/zigeffect/workbench/src/liveAttach.test.ts` and confirm the tap API is missing.
- [x] Add `LiveEngineNdjsonTapOptions`, `LiveEngineNdjsonTapResult`, and `runLiveEngineNdjsonTap`.
- [x] Re-run `bun test packages/zigeffect/workbench/src/liveAttach.test.ts`.

### Task 3: M66 HTTP discovery refresh with caller-owned fetcher

**Files:**
- Modify: `packages/zigeffect/src/cluster/transport.zig`
- Modify: `packages/zigeffect/src/cluster/root.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/cluster_transport_test.zig`

- [x] Add a failing Zig test named `service discovery refreshes registry through caller-owned http fetcher`.
- [x] The test should prove the helper formats a GET request, calls the fetcher with accept metadata, refreshes the registry from a 200 governed body, and rejects a non-200 response.
- [x] Run `cd packages/zigeffect && zig build test-raw` and confirm the refresh helper is missing.
- [x] Add `ClusterTransportServiceDiscoveryHttpFetcher` and `refreshClusterTransportServiceDiscoveryFromHttp`.
- [x] Export the new APIs through `cluster/root.zig` and `src/zigeffect.zig`.
- [x] Run `zig fmt` and re-run `cd packages/zigeffect && zig build test-raw`.

### Task 4: M67 provider alert retry reporting

**Files:**
- Modify: `packages/zigeffect/src/services/causal_ops_alert.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/causal_ops_alert_test.zig`

- [x] Add a failing Zig test named `ops alert provider secret delivery retries transient sink failures`.
- [x] The test should prove a first sink failure is retried, the resolver is called per transient attempt, the final request contains the resolved key, and sentinel alert evidence remains redacted.
- [x] Run `cd packages/zigeffect && zig build test-raw` and confirm the retry API is missing.
- [x] Add `CausalOpsAlertProviderDeliveryPolicy`, `CausalOpsAlertProviderDeliveryReport`, and `deliverCausalOpsAlertProviderWithSecretRetrying`.
- [x] Export the new retry/report API.
- [x] Run `zig fmt` and re-run `cd packages/zigeffect && zig build test-raw`.

### Task 5: Docs, gates, and commit

**Files:**
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/2026-06-24-future-agent-briefing.md`
- Modify: this plan file

- [x] Update roadmap status and add M64-M67 milestone cards.
- [x] Update the future-agent briefing from M63 to M67.
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
- [x] Commit M64-M67.

## Verification Log

- RED M64: `bun test packages/zigeffect/workbench/src/liveAttach.test.ts`
  failed because `runLiveEngineHostSupervisor` was not exported.
- GREEN M64: the same focused Bun command passed with 24 tests after adding the
  bounded supervisor.
- RED M65: `bun test packages/zigeffect/workbench/src/liveAttach.test.ts`
  failed because `runLiveEngineNdjsonTap` was not exported.
- GREEN M65: the same focused Bun command passed with 25 tests after adding the
  stream tap helper.
- RED M66: `cd packages/zigeffect && zig build test-raw` failed because
  `refreshClusterTransportServiceDiscoveryFromHttp` was not exported.
- GREEN M66: `cd packages/zigeffect && zig build test-raw` exited 0 after adding
  the caller-owned HTTP fetcher refresh helper and making registry refresh
  reports own stable source metadata through the registry.
- RED M67: `cd packages/zigeffect && zig build test-raw` failed because
  `deliverCausalOpsAlertProviderWithSecretRetrying` was not exported.
- GREEN M67: `cd packages/zigeffect && zig build test-raw` exited 0 after adding
  provider alert retry reporting.
- Gate fix: `bun run zigeffect:workbench:typecheck` initially failed on an
  `unknown` narrowing in `liveEngineIngestedCount`; explicit `typeof` narrowing
  fixed it and typecheck then exited 0.
- Final gates: focused liveAttach test, workbench test/typecheck/build,
  `zig build test-raw`, `zig build examples`, `bun run zigeffect:test`,
  zigeffect-zio `zig build test`, tool hygiene, `git diff --check`, and
  `bun run zigeffect:release` all exited 0.
