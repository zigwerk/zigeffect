# zigeffect Durable Domain Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add empty-but-owned `workflow` and `cluster` domains to the public zigeffect facade.

**Architecture:** Create one focused root module per future subsystem and export the namespaces from `src/zigeffect.zig`. Architecture docs define ownership; tests verify only namespace wiring and stable domain names.

**Tech Stack:** Zig 0.16, existing zigeffect architecture tests, Bun verification scripts.

---

## File Structure

- Create `packages/zigeffect/src/workflow/root.zig`
  - Owns the initial workflow namespace marker.
- Create `packages/zigeffect/src/cluster/root.zig`
  - Owns the initial cluster namespace marker.
- Modify `packages/zigeffect/src/zigeffect.zig`
  - Exposes `fx.workflow` and `fx.cluster`.
- Modify `packages/zigeffect/test/architecture_test.zig`
  - Adds namespace wiring tests.
- Modify `packages/zigeffect/docs/architecture.md`
  - Documents the new source domains.
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
  - Marks Milestone 1 complete after verification.

## Task 1: Namespace Wiring

**Files:**
- Create: `packages/zigeffect/src/workflow/root.zig`
- Create: `packages/zigeffect/src/cluster/root.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/architecture_test.zig`

- [ ] **Step 1: Write failing architecture tests**

Add:

```zig
test "root facade exposes durable workflow and cluster namespaces" {
    try std.testing.expect(@hasDecl(fx, "workflow"));
    try std.testing.expect(@hasDecl(fx, "cluster"));
    try std.testing.expectEqualStrings("workflow", fx.workflow.domain);
    try std.testing.expectEqualStrings("cluster", fx.cluster.domain);
}
```

- [ ] **Step 2: Verify red**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL because `fx.workflow` and `fx.cluster` do not exist.

- [ ] **Step 3: Implement root modules and facade imports**

Create `workflow/root.zig`:

```zig
pub const domain = "workflow";
```

Create `cluster/root.zig`:

```zig
pub const domain = "cluster";
```

Add to `src/zigeffect.zig` near the other domain imports:

```zig
pub const workflow = @import("workflow/root.zig");
pub const cluster = @import("cluster/root.zig");
```

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 2: Documentation And Roadmap Completion

**Files:**
- Modify: `packages/zigeffect/docs/architecture.md`
- Modify: `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
- Add: `docs/superpowers/specs/2026-06-09-zigeffect-durable-domain-layout-design.md`
- Add: `docs/superpowers/plans/2026-06-09-zigeffect-durable-domain-layout.md`

- [ ] **Step 1: Update architecture docs**

Add source-domain sections for `src/workflow/` and `src/cluster/` that define
ownership and state that implementation modules should import sibling domain
files rather than the facade.

- [ ] **Step 2: Mark Milestone 1 complete**

Mark all Milestone 1 deliverables and acceptance boxes in the durable workflows
and clustering roadmap after verification.

- [ ] **Step 3: Run full verification**

Run:

```bash
bun run zigeffect:test
cd packages/zigeffect && zig build examples
bun run zig:test
```

Expected: all commands PASS.

- [ ] **Step 4: Commit**

```bash
git add packages/zigeffect/src/workflow/root.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/architecture_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/specs/2026-06-09-zigeffect-durable-domain-layout-design.md docs/superpowers/plans/2026-06-09-zigeffect-durable-domain-layout.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
git commit -m "feat(zigeffect): add durable workflow and cluster domains"
```

## Self-Review Checklist

- [ ] The plan adds no journal, workflow engine, actor, shard, runner, or transport behavior.
- [ ] The public surface is limited to `fx.workflow` and `fx.cluster`.
- [ ] Architecture docs define ownership clearly enough for Milestone 2 and later.
- [ ] Full verification passes before marking Milestone 1 complete.
