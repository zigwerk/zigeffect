# zigeffect Live Workflow Causal Mirroring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make attached workflow causal stores receive live workflow journal events.

**Architecture:** Add a `CausalJournalStore` decorator around `JournalStore`, wrap workflow contexts and cluster workflow entity handling when a causal store is attached, and keep the journal as the source of truth. Causal record failures are best-effort and do not roll back durable appends.

**Tech Stack:** Zig, zigeffect workflow journal APIs, zigeffect `CausalStore`, `bun run zigeffect:test`.

---

### Task 1: Workflow Context Live Mirroring

**Files:**
- Modify: `packages/zigeffect/src/workflow/causal.zig`
- Modify: `packages/zigeffect/src/workflow/store.zig`
- Modify: `packages/zigeffect/src/workflow/context.zig`
- Modify: `packages/zigeffect/src/workflow/root.zig`
- Test: `packages/zigeffect/test/workflow_test.zig`

- [x] Write a failing test showing `WorkflowContext` live-mirrors appended workflow events to `CausalStore`.
- [x] Run the focused workflow test and confirm it fails because live mirroring is missing.
- [x] Add `CausalJournalStore` and use it from `WorkflowContext.init` when `causal_store` is attached.
- [x] Run the focused workflow test and confirm it passes.

### Task 2: Duplicate Append Guard

**Files:**
- Modify: `packages/zigeffect/test/workflow_test.zig`

- [x] Write a failing test showing a duplicate workflow append does not record a second causal event.
- [x] Run the focused workflow test and confirm it fails before the decorator handles success-only mirroring.
- [x] Ensure the decorator records only after inner append success.
- [x] Run the focused workflow test and confirm it passes.

### Task 3: Cluster Workflow Entity Mirroring

**Files:**
- Modify: `packages/zigeffect/src/cluster/workflow_engine.zig`
- Test: `packages/zigeffect/test/cluster_workflow_engine_test.zig`

- [x] Write a failing cluster workflow test that attaches a causal store to registered workflow entity services and expects a live `workflow_event_recorded` event.
- [x] Run the focused cluster workflow test and confirm it fails because cluster workflow services do not carry workflow causal attachment.
- [x] Add optional causal store/run id to `ClusterWorkflowEntityServices` and wrap the entity handler journal store after lease guarding.
- [x] Run the focused cluster workflow test and confirm it passes.

### Task 4: Parent Edge Correctness

**Files:**
- Modify: `packages/zigeffect/src/workflow/store.zig`
- Test: `packages/zigeffect/test/workflow_test.zig`

- [x] Write a failing test showing workflow `parent_sequence` must map to the actual recorded causal event id when the causal store already has earlier events.
- [x] Run `bun run zigeffect:test` and confirm it fails with `expected 2, found 1`.
- [x] Add a journal-sequence to causal-id map in `CausalJournalStore`.
- [x] Ensure `WorkflowContext`, cluster handlers, and direct tests deinit the sequence map.
- [x] Rerun `bun run zigeffect:test` and confirm it passes.

### Task 5: Verification

**Files:**
- All modified files

- [x] Run `zig fmt --check` on modified Zig files.
- [x] Run `bun run zigeffect:test`.
- [x] Review `git diff` for unintended changes.

## Verification Evidence

- Red regression: `bun run zigeffect:test` failed on
  `workflow_test.test.causal journal store maps workflow parent sequences to causal event ids`
  with `expected 2, found 1`.
- Green regression: `bun run zigeffect:test` passed after sequence-id mapping.
