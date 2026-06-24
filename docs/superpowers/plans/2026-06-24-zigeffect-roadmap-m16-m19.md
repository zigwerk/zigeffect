# zigeffect Roadmap M16-M19 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the remaining roadmap frontier as bounded, tested M16-M19 capabilities.

**Architecture:** Add focused Zig service modules for live command execution, ops storage reads, and runner lineage stitching; extend the workbench artifact model and UI for semantic diffs. Keep policy authority in the engine and keep deployed-system claims bounded to verified data paths.

**Tech Stack:** Zig 0.16 services/tests, Bun/Solid workbench tests, existing `CausalStore`, `AgentInterventionPolicy`, `CausalOpsPolicy`, and `CausalNendbStorageBackendState`.

---

## File Structure

- Create: `packages/zigeffect/src/services/causal_live_command.zig`
- Create: `packages/zigeffect/src/services/causal_ops_storage.zig`
- Create: `packages/zigeffect/src/services/causal_runner_lineage.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/all_test.zig`
- Create: `packages/zigeffect/test/causal_live_command_test.zig`
- Create: `packages/zigeffect/test/causal_ops_storage_test.zig`
- Create: `packages/zigeffect/test/causal_runner_lineage_test.zig`
- Modify: `packages/zigeffect/workbench/src/causalArtifact.ts`
- Modify: `packages/zigeffect/workbench/src/causalArtifact.test.ts`
- Modify: `packages/zigeffect/workbench/src/App.tsx`
- Modify: `packages/zigeffect/workbench/src/App.test.tsx`
- Modify: `packages/zigeffect/workbench/src/styles.css`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/2026-06-24-future-agent-briefing.md`

## Task 1: M16 Engine-Applied Live Commands

- [x] Add `causal_live_command_test.zig` for approved command application and unknown command rejection.
- [x] Run `cd packages/zigeffect && zig build test-raw`; expect missing live-command API.
- [x] Implement `services/causal_live_command.zig`.
- [x] Export live-command types/functions from `src/zigeffect.zig`.
- [x] Import the new test from `test/all_test.zig`.
- [x] Run `cd packages/zigeffect && zig build test-raw`.

## Task 2: M17 Visual Semantic Diff UX

- [x] Add workbench tests for `deriveSemanticDiffModel` and `Diff` tab exposure.
- [x] Run `bun run zigeffect:workbench:test`; expect missing diff model/tab.
- [x] Extend `causalArtifact.ts` with semantic diff model derivation.
- [x] Add `Diff` tab and read-only summary/entry panels in `App.tsx`.
- [x] Add compact diff styles in `styles.css`.
- [x] Run `bun run zigeffect:workbench:test`.
- [x] Run `bun run zigeffect:workbench:typecheck`.

## Task 3: M18 Durable Ops Adapters

- [x] Add `causal_ops_storage_test.zig` for denied reads, allowed scoped reads, and retention alerts from storage state.
- [x] Run `cd packages/zigeffect && zig build test-raw`; expect missing ops-storage API.
- [x] Implement `services/causal_ops_storage.zig`.
- [x] Export ops-storage types/functions from `src/zigeffect.zig`.
- [x] Import the new test from `test/all_test.zig`.
- [x] Run `cd packages/zigeffect && zig build test-raw`.

## Task 4: M19 Multi-Runner Causal Lineage Stitching

- [x] Add `causal_runner_lineage_test.zig` for cross-runner `cause_event_id` edge detection.
- [x] Run `cd packages/zigeffect && zig build test-raw`; expect missing runner-lineage API.
- [x] Implement `services/causal_runner_lineage.zig`.
- [x] Export runner-lineage types/functions from `src/zigeffect.zig`.
- [x] Import the new test from `test/all_test.zig`.
- [x] Run `cd packages/zigeffect && zig build test-raw`.

## Task 5: Docs and Verification

- [x] Update `packages/zigeffect/docs/roadmap.md` with M16-M19 delivered status.
- [x] Update `docs/superpowers/2026-06-24-future-agent-briefing.md`.
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
- `bun run zigeffect:workbench:test`: passed, 71 tests.
- `bun run zigeffect:workbench:typecheck`: passed.
- `bun run zigeffect:workbench:build`: passed.
- `packages/zigeffect/tools/check_tool_hygiene.sh`: passed, 46 tool files within limits.
- `git diff --check`: passed.
- `bun run zigeffect:test`: passed.
- `bun run zigeffect:release`: passed and wrote release gate plus causal dogfood artifacts.
