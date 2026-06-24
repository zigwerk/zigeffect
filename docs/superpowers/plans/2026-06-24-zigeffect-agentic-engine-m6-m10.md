# zigeffect Agentic Engine M6-M10 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the next agentic engine layer: interventions, counterfactuals, invariants, remote transport hardening, and eval scoring.

**Architecture:** Add four small service modules under `packages/zigeffect/src/services/` and one transport wrapper under `packages/zigeffect/src/cluster/transport.zig`. Each milestone records or checks causal facts rather than introducing broad platform surface. Public exports are added through `src/zigeffect.zig` and aggregate tests through `test/all_test.zig`.

**Tech Stack:** Zig 0.16, existing `CausalStore`, existing `PolicyEngine` posture, `ClusterTransport` vtable, `zig build test-raw`.

---

## File Structure

- Create: `packages/zigeffect/src/services/agent_intervention.zig`
- Create: `packages/zigeffect/src/services/counterfactual.zig`
- Create: `packages/zigeffect/src/services/causal_invariant.zig`
- Create: `packages/zigeffect/src/services/agent_eval.zig`
- Modify: `packages/zigeffect/src/cluster/transport.zig`
- Modify: `packages/zigeffect/src/cluster/root.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Create: `packages/zigeffect/test/agent_intervention_test.zig`
- Create: `packages/zigeffect/test/counterfactual_test.zig`
- Create: `packages/zigeffect/test/causal_invariant_test.zig`
- Create: `packages/zigeffect/test/agent_eval_test.zig`
- Modify: `packages/zigeffect/test/cluster_transport_test.zig`
- Modify: `packages/zigeffect/test/all_test.zig`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/2026-06-24-future-agent-briefing.md`

## Task 1: M6 Agent Intervention Protocol

- [x] Write `agent_intervention_test.zig` proving default-denied decisions record request/decision but no apply event.
- [x] Write a second test proving an enabled `interrupt_fiber` intervention records `remediation_applied` and `fiber_interrupted`.
- [x] Run `cd packages/zigeffect && zig build test-raw`; expect missing `AgentInterventionPolicy`.
- [x] Implement `services/agent_intervention.zig`.
- [x] Export the module and public types/functions from `src/zigeffect.zig`.
- [x] Add the test import to `test/all_test.zig`.
- [x] Run `cd packages/zigeffect && zig build test-raw`; expect green for the new tests.

## Task 2: M7 Counterfactual Re-executor

- [x] Write `counterfactual_test.zig` with a suspended fiber baseline and an approved interrupt intervention.
- [x] Assert the counterfactual result reduces findings and reports `improved = true`.
- [x] Run `cd packages/zigeffect && zig build test-raw`; expect missing `runCounterfactual`.
- [x] Implement `services/counterfactual.zig`.
- [x] Export public types/functions from `src/zigeffect.zig`.
- [x] Add the test import to `test/all_test.zig`.
- [x] Run `cd packages/zigeffect && zig build test-raw`; expect green for the new tests.

## Task 3: M8 Runtime Invariant DSL

- [x] Write `causal_invariant_test.zig` proving the builder detects an unfinalized resource and a suspended fiber.
- [x] Write a passing invariant test for finalized resource and interrupted fiber.
- [x] Run `cd packages/zigeffect && zig build test-raw`; expect missing `CausalInvariantBuilder`.
- [x] Implement `services/causal_invariant.zig`.
- [x] Export public types/functions from `src/zigeffect.zig`.
- [x] Add the test import to `test/all_test.zig`.
- [x] Run `cd packages/zigeffect && zig build test-raw`; expect green for the new tests.

## Task 4: M9 Remote Socket Transport

- [x] Extend `cluster_transport_test.zig` with public export checks for `RemoteSocketClusterTransport`.
- [x] Add a test proving wrong auth is rejected before durable submission.
- [x] Add a test proving matching auth sends over the socket path and updates metrics.
- [x] Run `cd packages/zigeffect && zig build test-raw`; expect missing remote transport type.
- [x] Implement `RemoteSocketClusterTransport` in `cluster/transport.zig`.
- [x] Export from `cluster/root.zig` and `src/zigeffect.zig`.
- [x] Run `cd packages/zigeffect && zig build test-raw`; expect green.

## Task 5: M10 Agent Eval Harness

- [x] Write `agent_eval_test.zig` using the suspended-fiber scenario, approved interrupt intervention, and invariant builder.
- [x] Assert the eval passes when the intervention improves the graph and invariants are clean.
- [x] Add a denied-policy test asserting the eval does not pass.
- [x] Run `cd packages/zigeffect && zig build test-raw`; expect missing `runAgentEval`.
- [x] Implement `services/agent_eval.zig`.
- [x] Export public types/functions from `src/zigeffect.zig`.
- [x] Add the test import to `test/all_test.zig`.
- [x] Run `cd packages/zigeffect && zig build test-raw`; expect green.

## Task 6: Docs and Verification

- [x] Update `packages/zigeffect/docs/roadmap.md` with M6-M10 delivered status and new frontier.
- [x] Update `docs/superpowers/2026-06-24-future-agent-briefing.md` with the new agentic layer.
- [x] Run `zig fmt --check` on touched Zig files.
- [x] Run `cd packages/zigeffect && zig build test-raw`.
- [x] Run `cd packages/zigeffect-zio && zig build test`.
- [x] Run `packages/zigeffect/tools/check_tool_hygiene.sh`.
- [x] Run `git diff --check`.

## Verification Result

Completed on 2026-06-24:

- `zig fmt --check` on touched Zig files
- `cd packages/zigeffect && zig build test-raw`
- `bun run zigeffect:test`
- `bun run zigeffect:release`
- `cd packages/zigeffect-zio && zig build test`
- `bun run zigeffect:workbench:test`
- `bun run zigeffect:workbench:typecheck`
- `bun run zigeffect:workbench:build`
- `packages/zigeffect/tools/check_tool_hygiene.sh`
- `bash packages/zigeffect/tools/check_tool_hygiene_test.sh`
- `git diff --check`
