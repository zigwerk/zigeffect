# zigeffect Roadmap M60-M63 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the next deployability seams for live engine host wiring, HTTP-shaped discovery, patch-proposal eval artifacts, and provider alert secret injection.

**Architecture:** Keep TypeScript host helpers around web `Request`/daemon APIs. Keep Zig core deterministic by formatting/parsing request/response shapes and using caller-owned sinks for file writes, HTTP sends, and secret lookup.

**Tech Stack:** Zig 0.16, Bun tests, Solid workbench TypeScript, existing zigeffect causal services and tools.

---

## Tasks

### Task 1: M60 live engine host runner bundle

**Files:**
- Modify: `packages/zigeffect/workbench/src/liveAttach.ts`
- Modify: `packages/zigeffect/workbench/src/liveAttach.test.ts`

- [x] Add a failing Bun test named `createLiveEngineHost wires apply requests and collector command daemon`.
- [x] The test should call `host.handleApplyRequest(request)` and prove it delegates to the bridge, then call `host.runCommandDaemon(url, options, fetcher)` and prove daemon counters plus emitted frames are returned.
- [x] Run `bun test packages/zigeffect/workbench/src/liveAttach.test.ts` and confirm `createLiveEngineHost` is missing.
- [x] Implement `LiveEngineHost`, `createLiveEngineHost`, and methods that delegate to `serveLiveEngineCommandApplyRequest` and `runLiveEngineCommandDaemon`.
- [x] Re-run `bun test packages/zigeffect/workbench/src/liveAttach.test.ts`.

### Task 2: M61 HTTP-shaped discovery snapshot provider

**Files:**
- Modify: `packages/zigeffect/src/cluster/transport.zig`
- Modify: `packages/zigeffect/src/cluster/root.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/cluster_transport_test.zig`

- [x] Add a failing Zig test named `service discovery parses governed snapshot http response`.
- [x] The test should format a `GET` request shape, parse a `200` JSON snapshot body, refresh the in-memory registry, and reject a non-200 response.
- [x] Run `cd packages/zigeffect && zig build test-raw` and confirm the HTTP provider APIs are missing.
- [x] Add `ClusterTransportServiceDiscoveryHttpRequest`, `ClusterTransportServiceDiscoveryHttpResponse`, `formatClusterTransportServiceDiscoveryHttpRequest`, and `parseClusterTransportServiceDiscoveryHttpResponse`.
- [x] Export the new APIs through `cluster/root.zig` and `src/zigeffect.zig`.
- [x] Run `zig fmt` and re-run `cd packages/zigeffect && zig build test-raw`.

### Task 3: M62 patch-proposal eval artifact persistence

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/tools/causal_patch_proposal.zig`

- [x] Add a failing tool test named `approved patch proposal writes linked eval manifest artifacts`.
- [x] The test should exercise a new sink-based helper and assert one diff, one link, and one manifest artifact are written with schema/path evidence.
- [x] Run `cd packages/zigeffect && zig build examples` and confirm the helper is missing.
- [x] Import `zigeffect` into the patch-proposal tool module.
- [x] Add stable patch-proposal eval diff/link/manifest path helpers.
- [x] Add `writePatchProposalEvalArtifacts` using `runAgentEvalAndWriteLinkedDiffManifest`.
- [x] Call the writer only for approved proposals after proposal JSON/text artifacts are written.
- [x] Re-run `cd packages/zigeffect && zig build examples`.

### Task 4: M63 provider alert secret injection

**Files:**
- Modify: `packages/zigeffect/src/services/causal_ops_alert.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/causal_ops_alert_test.zig`

- [x] Add a failing Zig test named `ops alert provider delivery injects pagerduty secret through caller-owned resolver`.
- [x] The test should prove the resolver is called with the secret ref, the outbound PagerDuty body contains the resolved routing key, fixed headers are preserved, and sentinel alert evidence remains redacted.
- [x] Run `cd packages/zigeffect && zig build test-raw` and confirm the secret resolver API is missing.
- [x] Add `CausalOpsAlertProviderSecretResolver` and `deliverCausalOpsAlertProviderWithSecret`.
- [x] Keep secret injection limited to the transient outbound request body passed to the HTTP sink.
- [x] Export the new resolver/delivery API.
- [x] Run `zig fmt` and re-run `cd packages/zigeffect && zig build test-raw`.

### Task 5: Docs, gates, and commit

**Files:**
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/2026-06-24-future-agent-briefing.md`
- Modify: this plan file

- [x] Update roadmap status and add M60-M63 milestone cards.
- [x] Update the future-agent briefing from M59 to M63.
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
- [x] Commit M60-M63.

## Verification Log

- RED M60: `bun test packages/zigeffect/workbench/src/liveAttach.test.ts` failed because `createLiveEngineHost` was not exported.
- GREEN M60: the same focused Bun command passed with 23 tests after adding the host bundle.
- RED M61: `cd packages/zigeffect && zig build test-raw` failed because `formatClusterTransportServiceDiscoveryHttpRequest` was not exported.
- GREEN M61: `cd packages/zigeffect && zig build test-raw` exited 0 after adding HTTP-shaped discovery request/response helpers.
- RED M62: `cd packages/zigeffect && zig build examples` failed because `writePatchProposalEvalArtifacts` was missing from `causal_patch_proposal`.
- GREEN M62: `cd packages/zigeffect && zig build examples` exited 0 after wiring approved patch-proposal eval artifact persistence.
- RED M63: `cd packages/zigeffect && zig build test-raw` failed because `deliverCausalOpsAlertProviderWithSecret` was not exported.
- GREEN M63: `cd packages/zigeffect && zig build test-raw` exited 0 after adding caller-owned PagerDuty secret injection.
- Final gates: focused liveAttach test, workbench test/typecheck/build,
  `zig build test-raw`, `zig build examples`, `bun run zigeffect:test`,
  zigeffect-zio `zig build test`, tool hygiene, `git diff --check`, and
  `bun run zigeffect:release` all exited 0.
