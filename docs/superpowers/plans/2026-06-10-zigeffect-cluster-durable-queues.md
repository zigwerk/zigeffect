# zigeffect Cluster Durable Queues Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Add cluster-owned durable queue indexing, claim leases, claim/retry workflow commands, and crash-return tests so queue work can move safely between runners.

**Architecture:** Create `cluster/queue.zig` as a journal-backed queue work index filtered by workflow execution shard ownership. Extend `cluster/workflow_engine.zig` with queue claim and retry-expiration commands so queue claims and retry rows are appended by the owning workflow entity, while completions and failures continue through existing queue command paths.

**Tech Stack:** Zig, zigeffect workflow journal, local cluster runner, file-backed runner/message/journal storage, Bun wrapper commands.

---

Date: 2026-06-10

Milestone: 37 - Cluster Durable Queues

Spec: `docs/superpowers/specs/2026-06-10-zigeffect-cluster-durable-queues-design.md`

## Files

Create:

- `packages/zigeffect/src/cluster/queue.zig`
- `packages/zigeffect/test/cluster_queue_test.zig`

Modify:

- `packages/zigeffect/src/cluster/root.zig`
- `packages/zigeffect/src/zigeffect.zig`
- `packages/zigeffect/src/cluster/workflow_engine.zig`
- `packages/zigeffect/test/all_test.zig`
- `packages/zigeffect/docs/architecture.md`
- `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`

## Task 1: Public Queue Index Surface

**Files:**

- Create: `packages/zigeffect/src/cluster/queue.zig`
- Create: `packages/zigeffect/test/cluster_queue_test.zig`
- Modify: `packages/zigeffect/src/cluster/root.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/all_test.zig`

- [ ] **Step 1: Write failing public export test**

Add:

```zig
test "cluster queue public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "queue"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterQueueStatus"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterQueueItem"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterQueueBatch"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterQueueRebuildReport"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterQueueClaimLimits"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterQueueIndex"));
    try std.testing.expect(@hasDecl(fx, "ClusterQueueIndex"));
}
```

- [ ] **Step 2: Verify red**

Run:

```bash
zig build test-raw --summary all
```

Expected: compile failure for missing cluster queue declarations.

- [ ] **Step 3: Add minimal module and exports**

Implement status, item, batch, report, limits, and index types with `init` and
`deinit`.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/queue.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/cluster_queue_test.zig packages/zigeffect/test/all_test.zig
```

- [ ] **Step 5: Commit**

```bash
git add packages/zigeffect/src/cluster/queue.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/cluster_queue_test.zig packages/zigeffect/test/all_test.zig
git commit -m "feat(zigeffect): add cluster queue index surface"
```

## Task 2: Rebuild Owned Queue Work

**Files:**

- Modify: `packages/zigeffect/src/cluster/queue.zig`
- Modify: `packages/zigeffect/test/cluster_queue_test.zig`

- [ ] **Step 1: Write failing rebuild tests**

Add tests:

- `cluster queue rebuild indexes owned offered work`
- `cluster queue rebuild skips unowned work`
- `cluster queue rebuild tracks latest status by sequence`
- `cluster queue rebuild parses claim metadata`

Seed journal rows directly with `queue_offered`, `queue_claimed`,
`queue_retry_scheduled`, `queue_completed`, `queue_failed`, and `queue_acked`.

- [ ] **Step 2: Verify red**

Run:

```bash
zig build test-raw --summary all
```

Expected: compile or assertion failure for missing rebuild behavior.

- [ ] **Step 3: Implement rebuild**

Add:

```zig
pub fn rebuildOwned(
    self: *ClusterQueueIndex,
    runner: *LocalClusterRunner,
    journal_store: JournalStore,
) !ClusterQueueRebuildReport
```

The method clears prior items, scans sequence order, computes shard ownership
from workflow execution address, clones queue name and offered payload, updates
status and claim metadata, skips unowned items, and counts scanned/indexed rows.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/queue.zig packages/zigeffect/test/cluster_queue_test.zig
```

- [ ] **Step 5: Commit**

```bash
git add packages/zigeffect/src/cluster/queue.zig packages/zigeffect/test/cluster_queue_test.zig
git commit -m "feat(zigeffect): rebuild owned cluster queue work"
```

## Task 3: Claimable And Expired Batches

**Files:**

- Modify: `packages/zigeffect/src/cluster/queue.zig`
- Modify: `packages/zigeffect/test/cluster_queue_test.zig`

- [ ] **Step 1: Write failing selection tests**

Add tests:

- `cluster queue claimable respects runner and queue limits`
- `cluster queue expired claims require passed deadlines`

Use `ClusterQueueClaimLimits{ .max_per_runner = 2, .max_per_queue = 1 }` and
claimed rows with deadlines before and after `now_ms`.

- [ ] **Step 2: Verify red**

Run:

```bash
zig build test-raw --summary all
```

- [ ] **Step 3: Implement selection**

Add:

```zig
pub fn claimable(self: *const ClusterQueueIndex, allocator: Allocator, limits: ClusterQueueClaimLimits) Allocator.Error!ClusterQueueBatch
pub fn expiredClaims(self: *const ClusterQueueIndex, allocator: Allocator, now_ms: u64) Allocator.Error!ClusterQueueBatch
```

Both methods clone returned item strings and return owned batches.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/queue.zig packages/zigeffect/test/cluster_queue_test.zig
```

- [ ] **Step 5: Commit**

```bash
git add packages/zigeffect/src/cluster/queue.zig packages/zigeffect/test/cluster_queue_test.zig
git commit -m "feat(zigeffect): select cluster queue work by limits"
```

## Task 4: Queue Claim And Retry Workflow Commands

**Files:**

- Modify: `packages/zigeffect/src/cluster/workflow_engine.zig`
- Modify: `packages/zigeffect/test/cluster_queue_test.zig`
- Modify: `packages/zigeffect/test/cluster_workflow_engine_test.zig`

- [ ] **Step 1: Write failing command tests**

Add tests:

- `cluster workflow claim queue appends durable claim through owning entity`
- `cluster workflow claim queue respects max concurrency`
- `cluster workflow retry expired queues appends retry rows through owning entity`

Submit commands through `ClusterWorkflowEngine`, process the runner with
`ClusterWorkflowEntityHandler`, parse replies, and inspect journal events.

- [ ] **Step 2: Verify red**

Run:

```bash
zig build test-raw --summary all
```

- [ ] **Step 3: Extend command protocol**

Add command kinds `claim_queue` and `retry_expired_queues`, JSON fields
`worker_id`, `claim_timeout_ms`, and `max_concurrency`, result fields
`queue_id`, `queue_attempt`, `queue_claimed`, and `queue_retried`, plus engine
methods `claimQueue` and `retryExpiredQueues`.

- [ ] **Step 4: Implement entity command application**

For `claim_queue`, append `queue_claimed` only when the item status is
`offered` or `retry_ready` and queue active claims are below `max_concurrency`.
For `retry_expired_queues`, append `queue_retry_scheduled` for expired claimed
items in the named queue.

- [ ] **Step 5: Verify green**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/workflow_engine.zig packages/zigeffect/test/cluster_queue_test.zig packages/zigeffect/test/cluster_workflow_engine_test.zig
```

- [ ] **Step 6: Commit**

```bash
git add packages/zigeffect/src/cluster/workflow_engine.zig packages/zigeffect/test/cluster_queue_test.zig packages/zigeffect/test/cluster_workflow_engine_test.zig
git commit -m "feat(zigeffect): route cluster queue claims through workflow entities"
```

## Task 5: Crash Return Acceptance

**Files:**

- Modify: `packages/zigeffect/test/cluster_queue_test.zig`

- [ ] **Step 1: Write failing migration acceptance test**

Add:

```zig
test "queue worker crash returns claimed work to the cluster" {
    // Runner A starts workflow, offers queue item, suspends, and claims with a deadline.
    // Runner A shuts down before completion.
    // Runner B acquires shard, recovers entity, rebuilds queue index, retries expired claim,
    // reclaims as attempt 2, completes, and resumes workflow.
}
```

- [ ] **Step 2: Verify red**

Run:

```bash
zig build test-raw --summary all
```

- [ ] **Step 3: Complete helper flow**

Use file-backed runner storage, message storage, and journal storage in one temp
directory. Route all workflow mutation after registration through
`ClusterWorkflowEngine`.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/test/cluster_queue_test.zig
```

- [ ] **Step 5: Commit**

```bash
git add packages/zigeffect/test/cluster_queue_test.zig
git commit -m "test(zigeffect): prove cluster queue crash recovery"
```

## Task 6: Docs, Roadmap, And Full Gate

**Files:**

- Modify: `packages/zigeffect/docs/architecture.md`
- Modify: `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
- Modify: `docs/superpowers/plans/2026-06-10-zigeffect-cluster-durable-queues.md`

- [ ] **Step 1: Update architecture docs**

Document `cluster/queue.zig` as the rebuilt shard-owned durable queue index.

- [ ] **Step 2: Mark roadmap milestone complete**

Mark Milestone 37 checklist items complete after the verification gate passes.

- [ ] **Step 3: Run full verification gate**

Run:

```bash
bun run zigeffect:test
(cd packages/zigeffect && zig build examples)
(cd packages/zigeffect && zig build cluster-runner -- --help)
bun run zig:test
zig fmt --check packages/zigeffect/src/cluster/queue.zig packages/zigeffect/src/cluster/workflow_engine.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/cluster_queue_test.zig packages/zigeffect/test/cluster_workflow_engine_test.zig packages/zigeffect/test/all_test.zig
git diff --check
rg "TO""DO|FIX""ME|st""ub|place""holder|not imple""mented|unimple""mented" packages/zigeffect/src packages/zigeffect/test packages/zigeffect/docs docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md docs/superpowers/specs/2026-06-10-zigeffect-cluster-durable-queues-design.md docs/superpowers/plans/2026-06-10-zigeffect-cluster-durable-queues.md
```

- [ ] **Step 4: Commit docs**

```bash
git add packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md docs/superpowers/plans/2026-06-10-zigeffect-cluster-durable-queues.md
git commit -m "docs(zigeffect): mark cluster durable queues complete"
```

## Self-Review

- Spec coverage: shard ownership, durable claims, claim expiration, completion
  routing, concurrency limits, and crash-return acceptance each map to tasks.
- Marker scan: marker words are split in the verification command.
- Type consistency: queue index, batch, limits, command fields, and result
  fields are named consistently across the plan.
