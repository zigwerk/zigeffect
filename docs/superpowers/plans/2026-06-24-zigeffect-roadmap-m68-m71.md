# zigeffect Roadmap M68-M71 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add host request/runtime composition and make discovery refresh more
deployable/rotation-aware without pretending the core owns process or network
infrastructure.

**Architecture:** TypeScript local tooling owns host `Request` routing and
runtime composition. Zig core owns deterministic discovery refresh/selection
logic through caller-owned fetchers.

**Tech Stack:** Zig 0.16, Bun tests, Solid workbench TypeScript.

---

## Tasks

### Task 1: M68 live engine host request router

**Files:**
- Modify: `packages/zigeffect/workbench/src/liveAttach.ts`
- Modify: `packages/zigeffect/workbench/src/liveAttach.test.ts`

- [x] Add a failing Bun test named `serveLiveEngineHostRequest routes apply and health requests`.
- [x] The test should prove the configured apply path delegates to `host.handleApplyRequest`, `/health` returns fixed JSON headers, unknown paths return JSON 404, and wrong methods return JSON 405.
- [x] Run `bun test packages/zigeffect/workbench/src/liveAttach.test.ts` and confirm the router API is missing.
- [x] Add `LiveEngineHostRequestRouterOptions` and `serveLiveEngineHostRequest`.
- [x] Re-run `bun test packages/zigeffect/workbench/src/liveAttach.test.ts`.

### Task 2: M69 live engine host runtime runner

**Files:**
- Modify: `packages/zigeffect/workbench/src/liveAttach.ts`
- Modify: `packages/zigeffect/workbench/src/liveAttach.test.ts`

- [x] Add a failing Bun test named `runLiveEngineHostRuntime composes supervisor and ndjson tap reports`.
- [x] The test should prove the helper runs the supervised command loop, optionally runs the NDJSON fact tap, and returns both reports.
- [x] Run `bun test packages/zigeffect/workbench/src/liveAttach.test.ts` and confirm the runtime API is missing.
- [x] Add `LiveEngineHostRuntimeOptions`, `LiveEngineHostRuntimeResult`, and `runLiveEngineHostRuntime`.
- [x] Re-run `bun test packages/zigeffect/workbench/src/liveAttach.test.ts`.

### Task 3: M70 bounded HTTP discovery refresh loop

**Files:**
- Modify: `packages/zigeffect/src/cluster/transport.zig`
- Modify: `packages/zigeffect/src/cluster/root.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/cluster_transport_test.zig`

- [x] Add a failing Zig test named `service discovery http refresh loop records transient failures and stops on selection`.
- [x] The test should prove a failed fetch increments failure metadata, a later governed response refreshes the registry, and the loop stops once a selected endpoint exists.
- [x] Run `cd packages/zigeffect && zig build test-raw` and confirm the refresh loop API is missing.
- [x] Add `ClusterTransportServiceDiscoveryRefreshLoopOptions`, `ClusterTransportServiceDiscoveryRefreshLoopReport`, and `runClusterTransportServiceDiscoveryHttpRefreshLoop`.
- [x] Export the new APIs.
- [x] Run `zig fmt` and re-run `cd packages/zigeffect && zig build test-raw`.

### Task 4: M71 freshest auth-epoch discovery selection

**Files:**
- Modify: `packages/zigeffect/src/cluster/transport.zig`
- Modify: `packages/zigeffect/src/cluster/root.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/cluster_transport_test.zig`

- [x] Add a failing Zig test named `service discovery can select freshest safe auth epoch`.
- [x] The test should prove the existing first-safe selector remains available while the new selector chooses the safe endpoint with the highest auth epoch.
- [x] Run `cd packages/zigeffect && zig build test-raw` and confirm the freshest selector API is missing.
- [x] Add and export `selectFreshestClusterTransportServiceDiscoveryEndpoint`.
- [x] Run `zig fmt` and re-run `cd packages/zigeffect && zig build test-raw`.

### Task 5: Docs, gates, and commit

**Files:**
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/2026-06-24-future-agent-briefing.md`
- Modify: this plan file

- [x] Update roadmap status and add M68-M71 milestone cards.
- [x] Update the future-agent briefing from M67 to M71.
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
- [x] Commit M68-M71.

## Verification Log

- RED M68: `bun test packages/zigeffect/workbench/src/liveAttach.test.ts`
  failed because `serveLiveEngineHostRequest` was not exported.
- GREEN M68: the same focused Bun command passed with 26 tests after adding the
  host request router.
- RED M69: `bun test packages/zigeffect/workbench/src/liveAttach.test.ts`
  failed because `runLiveEngineHostRuntime` was not exported.
- GREEN M69: the same focused Bun command passed with 27 tests after adding the
  runtime runner.
- RED M70: `cd packages/zigeffect && zig build test-raw` failed because
  `runClusterTransportServiceDiscoveryHttpRefreshLoop` was not exported.
- GREEN M70: `cd packages/zigeffect && zig build test-raw` exited 0 after adding
  the bounded HTTP discovery refresh loop.
- RED M71: `cd packages/zigeffect && zig build test-raw` failed because
  `selectFreshestClusterTransportServiceDiscoveryEndpoint` was not exported.
- GREEN M71: `cd packages/zigeffect && zig build test-raw` exited 0 after adding
  freshest safe auth-epoch selection.
- Final gates: focused liveAttach test, workbench test/typecheck/build,
  `zig build test-raw`, `zig build examples`, `bun run zigeffect:test`,
  zigeffect-zio `zig build test`, tool hygiene, `git diff --check`, and
  `bun run zigeffect:release` all exited 0.
