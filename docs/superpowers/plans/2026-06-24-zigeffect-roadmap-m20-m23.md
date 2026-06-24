# zigeffect Roadmap M20-M23 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement command-tap batching, Zig semantic diff artifacts, clickable workbench diff entries, and ops alert/runbook evidence.

**Architecture:** Extend existing M16-M19 modules instead of creating parallel systems: command taps delegate to `applyCausalLiveCommand`, diff artifacts format `CausalGraphDiff`, workbench rows select existing event ids, and ops alert sinks read alert facts from `CausalStore`.

**Tech Stack:** Zig 0.16, Bun/Solid tests, existing causal services and workbench model.

---

## File Structure

- Modify: `packages/zigeffect/src/services/causal_live_command.zig`
- Modify: `packages/zigeffect/src/services/causal_diff.zig`
- Create: `packages/zigeffect/src/services/causal_ops_alert.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/causal_live_command_test.zig`
- Modify: `packages/zigeffect/test/causal_diff_test.zig`
- Create: `packages/zigeffect/test/causal_ops_alert_test.zig`
- Modify: `packages/zigeffect/test/all_test.zig`
- Modify: `packages/zigeffect/workbench/src/App.tsx`
- Modify: `packages/zigeffect/workbench/src/App.test.tsx`
- Modify: `packages/zigeffect/workbench/src/causalArtifact.test.ts`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/2026-06-24-future-agent-briefing.md`

## Task 1: M20 Live Engine Command Tap

- [x] Add command tap tests to `causal_live_command_test.zig`.
- [x] Run `cd packages/zigeffect && zig build test-raw`; expect missing tap APIs.
- [x] Implement command envelope, tap result, and batch runner.
- [x] Export tap types/functions.
- [x] Run `cd packages/zigeffect && zig build test-raw`.

## Task 2: M21 Zig Semantic Diff Artifact Emission

- [x] Add `formatCausalGraphDiffJson` tests to `causal_diff_test.zig`.
- [x] Run `cd packages/zigeffect && zig build test-raw`; expect missing formatter.
- [x] Implement JSON formatter in `causal_diff.zig`.
- [x] Export formatter.
- [x] Run `cd packages/zigeffect && zig build test-raw`.

## Task 3: M22 Graph-Linked Diff UX

- [x] Add workbench tests proving Diff tab exists and exposes selectable diff entries.
- [x] Run `bun run zigeffect:workbench:test`; expect missing selectable entries.
- [x] Wire Diff rows to `onSelectEvent`.
- [x] Run `bun run zigeffect:workbench:test` and `bun run zigeffect:workbench:typecheck`.

## Task 4: M23 Ops Alert Sink And Runbook

- [x] Add `causal_ops_alert_test.zig`.
- [x] Run `cd packages/zigeffect && zig build test-raw`; expect missing alert APIs.
- [x] Implement `services/causal_ops_alert.zig`.
- [x] Export alert sink/runbook types/functions.
- [x] Import the new test from `test/all_test.zig`.
- [x] Run `cd packages/zigeffect && zig build test-raw`.

## Task 5: Docs and Verification

- [x] Update roadmap and future-agent briefing with M20-M23.
- [x] Run `zig fmt --check` on touched Zig files.
- [x] Run `cd packages/zigeffect && zig build test-raw`.
- [x] Run `cd packages/zigeffect-zio && zig build test`.
- [x] Run `bun run zigeffect:workbench:test`.
- [x] Run `bun run zigeffect:workbench:typecheck`.
- [x] Run `bun run zigeffect:workbench:build`.
- [x] Run `packages/zigeffect/tools/check_tool_hygiene.sh`.
- [x] Run `git diff --check`.
- [x] Run `bun run zigeffect:test`.
- [x] Run `bun run zigeffect:release`.

## Verification Results

- `zig fmt --check ...touched Zig files`: passed.
- `cd packages/zigeffect && zig build test-raw`: passed.
- `cd packages/zigeffect-zio && zig build test`: passed.
- `bun run zigeffect:workbench:test`: passed, 72 tests.
- `bun run zigeffect:workbench:typecheck`: passed.
- `bun run zigeffect:workbench:build`: passed.
- `packages/zigeffect/tools/check_tool_hygiene.sh`: passed, 46 tool files within limits.
- `git diff --check`: passed.
- `bun run zigeffect:test`: passed.
- `bun run zigeffect:release`: passed and wrote release gate plus causal dogfood artifacts.
