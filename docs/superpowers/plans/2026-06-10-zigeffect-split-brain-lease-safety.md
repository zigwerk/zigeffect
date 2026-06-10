# zigeffect Split-Brain And Lease Safety Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Add shard lease epochs and fence validation so stale runners cannot mutate cluster mailboxes or workflow journals after ownership moves.

**Architecture:** Add `cluster/fencing.zig` with fence derivation, validation, and diagnostics. Extend `ShardLease` with stable acquisition `epoch`, validate fences in `ClusterRuntime.processShard`, and validate captured workflow entity fences before journal mutation.

**Tech Stack:** Zig, runner storage, cluster runtime, workflow entity commands, in-memory and file-backed stores.

---

Date: 2026-06-10

Milestone: 38 - Split-Brain And Lease Safety

Spec: `docs/superpowers/specs/2026-06-10-zigeffect-split-brain-lease-safety-design.md`

## Files

Create:

- `packages/zigeffect/src/cluster/fencing.zig`
- `packages/zigeffect/test/cluster_fencing_test.zig`

Modify:

- `packages/zigeffect/src/cluster/runner_storage.zig`
- `packages/zigeffect/src/cluster/shard_lease.zig`
- `packages/zigeffect/src/cluster/runtime.zig`
- `packages/zigeffect/src/cluster/workflow_engine.zig`
- `packages/zigeffect/src/cluster/root.zig`
- `packages/zigeffect/src/zigeffect.zig`
- `packages/zigeffect/test/all_test.zig`
- `packages/zigeffect/docs/architecture.md`
- `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`

## Task 1: Lease Epoch And Fence Surface

- [x] **Step 1: Write failing public and epoch tests**

Add tests for public fence exports and for acquire/refresh/reacquire epoch
behavior.

- [x] **Step 2: Verify red**

Run:

```bash
zig build test-raw --summary all
```

- [x] **Step 3: Implement epoch and fence module**

Add `ShardLeaseEpoch`, `ShardLeaseFence`, `fenceFromLease`,
`validateShardFence`, and lease `epoch` in memory/file runner storage JSON.
Refresh preserves epoch; acquire after expiry increments it.

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/fencing.zig packages/zigeffect/src/cluster/runner_storage.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/cluster_fencing_test.zig packages/zigeffect/test/all_test.zig
```

- [x] **Step 5: Commit**

```bash
git add packages/zigeffect/src/cluster/fencing.zig packages/zigeffect/src/cluster/runner_storage.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/cluster_fencing_test.zig packages/zigeffect/test/all_test.zig
git commit -m "feat(zigeffect): add shard lease fencing"
```

## Task 2: Runtime Fence Guard

- [x] **Step 1: Write failing runtime stale-owner test**

Add a test where runner A owns a shard, runner B acquires a newer epoch after
expiry, and runner A rejects `processShard` before claiming or acknowledging a
message.

- [x] **Step 2: Verify red**

Run:

```bash
zig build test-raw --summary all
```

- [x] **Step 3: Guard runtime processing**

Add `fenceForShard` to `LocalShardLeaseManager`, validate before
`ClusterRuntime.processShard`, remove stale local ownership, set
`accepting_messages = false`, and return `error.StaleShardFence`.

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/shard_lease.zig packages/zigeffect/src/cluster/runtime.zig packages/zigeffect/test/cluster_fencing_test.zig
```

- [x] **Step 5: Commit**

```bash
git add packages/zigeffect/src/cluster/shard_lease.zig packages/zigeffect/src/cluster/runtime.zig packages/zigeffect/test/cluster_fencing_test.zig
git commit -m "feat(zigeffect): reject stale runtime shard fences"
```

## Task 3: Workflow Entity Journal Fence Guard

- [x] **Step 1: Write failing stale journal write test**

Add a test where a stale workflow entity handler attempts a command after a
newer lease epoch exists and the journal remains unchanged.

- [x] **Step 2: Verify red**

Run:

```bash
zig build test-raw --summary all
```

- [x] **Step 3: Capture and validate entity fences**

Store runner storage and current shard fence in
`ClusterWorkflowEntityServices`. Validate before `applyClusterWorkflowCommand`.

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/workflow_engine.zig packages/zigeffect/test/cluster_fencing_test.zig
```

- [x] **Step 5: Commit**

```bash
git add packages/zigeffect/src/cluster/workflow_engine.zig packages/zigeffect/test/cluster_fencing_test.zig
git commit -m "feat(zigeffect): fence workflow entity journal writes"
```

## Task 4: Diagnostics And Closeout

- [x] **Step 1: Write failing diagnostic test**

Assert diagnostics include shard id, fenced owner/epoch, and current owner/epoch
or current none.

- [x] **Step 2: Implement diagnostics**

Add `formatShardFenceDiagnostic`.

- [x] **Step 3: Update docs and roadmap**

Document `cluster/fencing.zig`, mark M38 complete, and mark this plan complete.

- [x] **Step 4: Run full verification gate**

Run:

```bash
bun run zigeffect:test
(cd packages/zigeffect && zig build examples)
(cd packages/zigeffect && zig build cluster-runner -- --help)
bun run zig:test
zig fmt --check packages/zigeffect/src/cluster/fencing.zig packages/zigeffect/src/cluster/runner_storage.zig packages/zigeffect/src/cluster/shard_lease.zig packages/zigeffect/src/cluster/runtime.zig packages/zigeffect/src/cluster/workflow_engine.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/cluster_fencing_test.zig packages/zigeffect/test/all_test.zig
git diff --check
rg "TO""DO|FIX""ME|st""ub|place""holder|not imple""mented|unimple""mented" packages/zigeffect/src packages/zigeffect/test packages/zigeffect/docs docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md docs/superpowers/specs/2026-06-10-zigeffect-split-brain-lease-safety-design.md docs/superpowers/plans/2026-06-10-zigeffect-split-brain-lease-safety.md
```

- [x] **Step 5: Commit docs**

```bash
git add packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md docs/superpowers/plans/2026-06-10-zigeffect-split-brain-lease-safety.md
git commit -m "docs(zigeffect): mark split brain lease safety complete"
```

## Self-Review

- Spec coverage: lease epoch, stale writes, fences, stale shutdown, diagnostics,
  and corruption-prevention tests each map to tasks.
- Marker scan: marker words are split in the verification command.
- Type consistency: `ShardLeaseFence`, `validateShardFence`, `StaleShardFence`,
  and `epoch` are used consistently.
