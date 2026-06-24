# zigeffect Agentic Engine M11-M15 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement semantic graph diffs, live commands, concurrency annotations, remote transport policy hardening, and ops guardrails.

**Architecture:** Add focused service modules for causal diffs, concurrency annotations, and ops policies; extend the existing counterfactual/eval and remote transport APIs; add a command lane to the existing Bun collector and frontend live source. Each milestone is covered by tests before implementation and remains bounded to local, verifiable behavior.

**Tech Stack:** Zig 0.16, Bun test, Solid workbench live transport, existing `CausalStore`, `ClusterTransport`, and `AgentInterventionPolicy`.

---

## File Structure

- Create: `packages/zigeffect/src/services/causal_diff.zig`
- Create: `packages/zigeffect/src/services/causal_concurrency.zig`
- Create: `packages/zigeffect/src/services/causal_ops.zig`
- Modify: `packages/zigeffect/src/services/counterfactual.zig`
- Modify: `packages/zigeffect/src/services/agent_eval.zig`
- Modify: `packages/zigeffect/src/services/causal.zig`
- Modify: `packages/zigeffect/src/cluster/transport.zig`
- Modify: `packages/zigeffect/src/cluster/root.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/workbench/src/liveAttach.ts`
- Modify: `packages/zigeffect/workbench/src/collector/collector.ts`
- Create: `packages/zigeffect/test/causal_diff_test.zig`
- Create: `packages/zigeffect/test/causal_concurrency_test.zig`
- Create: `packages/zigeffect/test/causal_ops_test.zig`
- Modify: `packages/zigeffect/test/counterfactual_test.zig`
- Modify: `packages/zigeffect/test/agent_eval_test.zig`
- Modify: `packages/zigeffect/test/cluster_transport_test.zig`
- Modify: `packages/zigeffect/test/all_test.zig`
- Modify: `packages/zigeffect/workbench/src/liveAttach.test.ts`
- Modify: `packages/zigeffect/workbench/src/collector/collector.test.ts`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/2026-06-24-future-agent-briefing.md`

## Task 1: M11 Semantic Causal Graph Diffs

- [x] Write `causal_diff_test.zig` proving resolved findings, added terminal fiber facts, finalized resources, and added lineage edges are reported.
- [x] Add counterfactual/eval assertions that diff counts are present.
- [x] Run `cd packages/zigeffect && zig build test-raw`; expect missing `CausalGraphDiff`.
- [x] Implement `services/causal_diff.zig`.
- [x] Wire `CounterfactualResult` and `AgentEvalResult` to carry diff summaries.
- [x] Export public diff types/functions from `src/zigeffect.zig`.
- [x] Run `cd packages/zigeffect && zig build test-raw`.

## Task 2: M12 Bidirectional Live Debugging Command Path

- [x] Add workbench tests for command frame parsing, `sendLiveCommand`, and collector `POST /command`.
- [x] Run `bun run zigeffect:workbench:test`; expect missing command APIs.
- [x] Implement `LiveCommandFrame`, parser, sender, and collector command handling.
- [x] Ensure command labels/details are redacted before broadcast.
- [x] Run `bun run zigeffect:workbench:test` and `bun run zigeffect:workbench:typecheck`.

## Task 3: M13 Race/Both and STM Causal Annotations

- [x] Write `causal_concurrency_test.zig` proving race loser interruption, both completion, and STM conflict retry annotations.
- [x] Run `cd packages/zigeffect && zig build test-raw`; expect missing `CausalConcurrencyRecorder`.
- [x] Add causal event kinds for race/both/STM annotations.
- [x] Implement `services/causal_concurrency.zig`.
- [x] Export public types/functions from `src/zigeffect.zig`.
- [x] Run `cd packages/zigeffect && zig build test-raw`.

## Task 4: M14 Remote Transport Policy Hardening

- [x] Add cluster transport tests for TLS policy validation, backpressure rejection, and origin causal event propagation.
- [x] Run `cd packages/zigeffect && zig build test-raw`; expect missing policy fields/types.
- [x] Extend `ClusterTransportRequest` and `RemoteSocketClusterTransportOptions`.
- [x] Implement init/preflight policy validation and metrics.
- [x] Export policy types from `cluster/root.zig` and `src/zigeffect.zig`.
- [x] Run `cd packages/zigeffect && zig build test-raw`.

## Task 5: M15 Durable Retention and Ops Hardening

- [x] Write `causal_ops_test.zig` for access control, retention alert decisions, and alert causal event emission.
- [x] Run `cd packages/zigeffect && zig build test-raw`; expect missing `CausalOpsPolicy`.
- [x] Implement `services/causal_ops.zig`.
- [x] Export public ops types/functions from `src/zigeffect.zig`.
- [x] Run `cd packages/zigeffect && zig build test-raw`.

## Task 6: Docs and Verification

- [x] Update `packages/zigeffect/docs/roadmap.md` with M11-M15 delivered status and remaining frontier.
- [x] Update `docs/superpowers/2026-06-24-future-agent-briefing.md`.
- [x] Run `zig fmt --check` on touched Zig files.
- [x] Run `cd packages/zigeffect && zig build test-raw`.
- [x] Run `cd packages/zigeffect-zio && zig build test`.
- [x] Run `bun run zigeffect:workbench:test`.
- [x] Run `bun run zigeffect:workbench:typecheck`.
- [x] Run `packages/zigeffect/tools/check_tool_hygiene.sh`.
- [x] Run `git diff --check`.
- [x] Run `bun run zigeffect:test`.
- [x] Run `bun run zigeffect:release`.
- [x] Run `bun run zigeffect:workbench:build`.

## Verification Results

- `zig fmt --check ...touched Zig files`: passed.
- `cd packages/zigeffect && zig build test-raw`: passed.
- `cd packages/zigeffect-zio && zig build test`: passed.
- `bun run zigeffect:workbench:test`: passed, 70 tests.
- `bun run zigeffect:workbench:typecheck`: passed.
- `packages/zigeffect/tools/check_tool_hygiene.sh`: passed, 46 tool files within limits.
- `git diff --check`: passed.
- `bun run zigeffect:test`: passed.
- `bun run zigeffect:release`: passed and wrote release gate plus causal dogfood artifacts.
- `bun run zigeffect:workbench:build`: passed.
