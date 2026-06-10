# zigeffect Local Supervision Trees Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add deterministic local supervision trees with child specs, restart strategies, restart intensity escalation, shutdown ordering, Cause evidence, and causal supervisor events.

**Architecture:** Add `src/runtime/supervisor.zig` as a standalone local supervision policy engine over the existing runtime, scope, Cause, and causal primitives. The module stores child specs and state, computes restart decisions deterministically, and records causal events without starting real async work.

**Tech Stack:** Zig, `std.ArrayList`, existing `core.result.Cause`, existing `services.causal.CausalStore`, and `bun`/Zig test commands.

---

## File Structure

- Create `packages/zigeffect/src/runtime/supervisor.zig`
  - Owns supervisor ids, child specs, restart modes, strategies, restart intensity, child state, decisions, shutdown plans, Cause helpers, and causal recording hooks.
- Create `packages/zigeffect/test/supervisor_test.zig`
  - Owns local supervision tests.
- Modify `packages/zigeffect/src/services/causal.zig`
  - Adds supervisor causal event kinds and taxonomy classification.
- Modify `packages/zigeffect/src/zigeffect.zig`
  - Exports `runtime.supervisor` namespace and top-level supervisor aliases.
- Modify `packages/zigeffect/test/all_test.zig`
  - Imports `supervisor_test.zig`.
- Modify `packages/zigeffect/docs/architecture.md`
  - Documents the runtime supervision module and local milestone boundary.
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
  - Marks Milestone 24 complete after the full gate passes.

## Task 1: Supervisor Public Surface

**Files:**
- Create: `packages/zigeffect/src/runtime/supervisor.zig`
- Create: `packages/zigeffect/test/supervisor_test.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/all_test.zig`

- [ ] **Step 1: Write the failing export and type test**

Add `packages/zigeffect/test/supervisor_test.zig`:

```zig
const std = @import("std");
const fx = @import("zigeffect");

test "supervisor public exports are available" {
    try std.testing.expect(@hasDecl(fx.runtime, "supervisor"));
    try std.testing.expect(@hasDecl(fx.runtime, "Supervisor"));
    try std.testing.expect(@hasDecl(fx.runtime, "SupervisorStrategy"));
    try std.testing.expect(@hasDecl(fx.runtime, "SupervisorRestartMode"));
    try std.testing.expect(@hasDecl(fx.runtime, "SupervisorChildKind"));
    try std.testing.expect(@hasDecl(fx.runtime, "SupervisorChildStatus"));
    try std.testing.expect(@hasDecl(fx.runtime, "SupervisorChildSpec"));
    try std.testing.expect(@hasDecl(fx.runtime, "SupervisorChildExit"));
    try std.testing.expect(@hasDecl(fx.runtime, "RestartIntensity"));
    try std.testing.expect(@hasDecl(fx.runtime, "SupervisorOptions"));
    try std.testing.expect(@hasDecl(fx.runtime, "SupervisorDecision"));
    try std.testing.expect(@hasDecl(fx.runtime, "SupervisorShutdownPlan"));
    try std.testing.expect(@hasDecl(fx, "Supervisor"));
    try std.testing.expect(@hasDecl(fx, "SupervisorError"));
}

test "supervisor child specs cover local runtime domains" {
    const specs = [_]fx.SupervisorChildSpec{
        .{ .id = 1, .name = "fiber-child", .kind = .fiber },
        .{ .id = 2, .name = "workflow-worker", .kind = .workflow_worker },
        .{ .id = 3, .name = "queue-worker", .kind = .queue_worker },
        .{ .id = 4, .name = "entity", .kind = .entity },
    };
    try std.testing.expectEqual(fx.SupervisorChildKind.fiber, specs[0].kind);
    try std.testing.expectEqual(fx.SupervisorRestartMode.permanent, specs[0].restart_mode);
    try std.testing.expectEqual(@as(u32, 0), specs[0].shutdown_order);
}
```

Add to `packages/zigeffect/test/all_test.zig` near runtime tests:

```zig
    _ = @import("supervisor_test.zig");
```

- [ ] **Step 2: Run the red test**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: failure because `fx.runtime.supervisor` and supervisor aliases do not
exist.

- [ ] **Step 3: Add minimal supervisor module and exports**

Create `packages/zigeffect/src/runtime/supervisor.zig`:

```zig
const std = @import("std");
const result_mod = @import("../core/result.zig");
const causal_mod = @import("../services/causal.zig");

pub const Allocator = std.mem.Allocator;
pub const CausalStore = causal_mod.CausalStore;
pub const Cause = result_mod.Cause;

pub const SupervisorId = u64;
pub const SupervisorChildId = u64;

pub const SupervisorStrategy = enum { one_for_one, one_for_all, rest_for_one };
pub const SupervisorRestartMode = enum { permanent, transient, temporary };
pub const SupervisorChildKind = enum { fiber, workflow_worker, queue_worker, entity };
pub const SupervisorChildStatus = enum { idle, running, restarting, stopped, failed, escalated };

pub const SupervisorError = error{
    ChildNotFound,
    DuplicateChild,
    ChildFailed,
    RestartIntensityExceeded,
};

pub const SupervisorCause = Cause(SupervisorError);

pub const SupervisorChildSpec = struct {
    id: SupervisorChildId,
    name: []const u8,
    kind: SupervisorChildKind,
    restart_mode: SupervisorRestartMode = .permanent,
    shutdown_order: u32 = 0,
};

pub const SupervisorChildExit = union(enum) {
    success,
    failure: []const u8,
    defect: []const u8,
    interrupted: u64,
};

pub const RestartIntensity = struct {
    max_restarts: usize = 3,
    within_ms: u64 = 60_000,
};

pub const SupervisorOptions = struct {
    id: SupervisorId,
    name: []const u8,
    strategy: SupervisorStrategy = .one_for_one,
    intensity: RestartIntensity = .{},
};

pub const SupervisorChildSnapshot = struct {
    spec: SupervisorChildSpec,
    status: SupervisorChildStatus,
    restart_count: usize = 0,
};

pub const SupervisorDecision = struct {
    supervisor_id: SupervisorId,
    child_id: SupervisorChildId,
    strategy: SupervisorStrategy,
    exit: SupervisorChildExit,
    restarted_children: usize = 0,
    stopped_children: usize = 0,
    escalated: bool = false,

    pub fn cause(self: SupervisorDecision) ?SupervisorCause {
        if (self.escalated) return SupervisorCause{ .failure = error.RestartIntensityExceeded };
        return switch (self.exit) {
            .success => null,
            .failure, .defect, .interrupted => SupervisorCause{ .failure = error.ChildFailed },
        };
    }
};

pub const SupervisorShutdownPlan = struct {
    allocator: Allocator,
    children: []SupervisorChildSnapshot,

    pub fn deinit(self: *SupervisorShutdownPlan) void {
        self.allocator.free(self.children);
    }
};

pub const Supervisor = struct {
    allocator: Allocator,
    options: SupervisorOptions,

    pub fn init(allocator: Allocator, options: SupervisorOptions) Supervisor {
        return .{ .allocator = allocator, .options = options };
    }

    pub fn deinit(self: *Supervisor) void {
        _ = self;
    }
};
```

Modify `packages/zigeffect/src/zigeffect.zig` runtime namespace:

```zig
    pub const supervisor = @import("runtime/supervisor.zig");
    pub const Supervisor = supervisor.Supervisor;
    pub const SupervisorId = supervisor.SupervisorId;
    pub const SupervisorChildId = supervisor.SupervisorChildId;
    pub const SupervisorStrategy = supervisor.SupervisorStrategy;
    pub const SupervisorRestartMode = supervisor.SupervisorRestartMode;
    pub const SupervisorChildKind = supervisor.SupervisorChildKind;
    pub const SupervisorChildStatus = supervisor.SupervisorChildStatus;
    pub const SupervisorError = supervisor.SupervisorError;
    pub const SupervisorCause = supervisor.SupervisorCause;
    pub const SupervisorChildSpec = supervisor.SupervisorChildSpec;
    pub const SupervisorChildExit = supervisor.SupervisorChildExit;
    pub const RestartIntensity = supervisor.RestartIntensity;
    pub const SupervisorOptions = supervisor.SupervisorOptions;
    pub const SupervisorChildSnapshot = supervisor.SupervisorChildSnapshot;
    pub const SupervisorDecision = supervisor.SupervisorDecision;
    pub const SupervisorShutdownPlan = supervisor.SupervisorShutdownPlan;
```

Add the same top-level aliases near the other runtime aliases.

- [ ] **Step 4: Run the green test**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: all tests pass.

- [ ] **Step 5: Format and commit**

Run:

```bash
zig fmt --check packages/zigeffect/src/runtime/supervisor.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/supervisor_test.zig packages/zigeffect/test/all_test.zig
git add packages/zigeffect/src/runtime/supervisor.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/supervisor_test.zig packages/zigeffect/test/all_test.zig
git commit -m "feat(zigeffect): add supervisor runtime surface"
```

## Task 2: Child Registry And Shutdown Ordering

**Files:**
- Modify: `packages/zigeffect/src/runtime/supervisor.zig`
- Modify: `packages/zigeffect/test/supervisor_test.zig`

- [ ] **Step 1: Write failing child registry and shutdown-order tests**

Append to `packages/zigeffect/test/supervisor_test.zig`:

```zig
test "supervisor registers children and rejects duplicate ids" {
    var supervisor = fx.Supervisor.init(std.testing.allocator, .{ .id = 10, .name = "root" });
    defer supervisor.deinit();

    try supervisor.addChild(.{ .id = 1, .name = "first", .kind = .fiber });
    try supervisor.addChild(.{ .id = 2, .name = "second", .kind = .queue_worker });
    try std.testing.expectError(error.DuplicateChild, supervisor.addChild(.{ .id = 1, .name = "dupe", .kind = .fiber }));

    try supervisor.startAll(1_000);
    try std.testing.expectEqual(fx.SupervisorChildStatus.running, try supervisor.childStatus(1));
    try std.testing.expectEqual(fx.SupervisorChildStatus.running, try supervisor.childStatus(2));
}

test "supervisor shutdown plan uses order and reverse registration tie break" {
    var supervisor = fx.Supervisor.init(std.testing.allocator, .{ .id = 10, .name = "root" });
    defer supervisor.deinit();

    try supervisor.addChild(.{ .id = 1, .name = "first", .kind = .fiber, .shutdown_order = 10 });
    try supervisor.addChild(.{ .id = 2, .name = "second", .kind = .workflow_worker, .shutdown_order = 20 });
    try supervisor.addChild(.{ .id = 3, .name = "third", .kind = .queue_worker, .shutdown_order = 20 });
    try supervisor.addChild(.{ .id = 4, .name = "fourth", .kind = .entity, .shutdown_order = 5 });

    var plan = try supervisor.shutdownPlan(std.testing.allocator);
    defer plan.deinit();
    try std.testing.expectEqual(@as(usize, 4), plan.children.len);
    try std.testing.expectEqual(@as(u64, 3), plan.children[0].spec.id);
    try std.testing.expectEqual(@as(u64, 2), plan.children[1].spec.id);
    try std.testing.expectEqual(@as(u64, 1), plan.children[2].spec.id);
    try std.testing.expectEqual(@as(u64, 4), plan.children[3].spec.id);
}
```

- [ ] **Step 2: Run the red test**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: failure because `addChild`, `startAll`, `childStatus`, and
`shutdownPlan` do not exist.

- [ ] **Step 3: Implement registry, snapshots, and shutdown plan**

In `supervisor.zig`, add internal state:

```zig
const ChildState = struct {
    spec: SupervisorChildSpec,
    status: SupervisorChildStatus = .idle,
    restart_count: usize = 0,
    registration_index: usize = 0,
};
```

Add fields to `Supervisor`:

```zig
    children: std.ArrayList(ChildState) = .empty,
```

Update `deinit`:

```zig
        self.children.deinit(self.allocator);
```

Add `addChild`, `startAll`, `childStatus`, `childRestartCount`,
`shutdownPlan`, and private `findChildIndex`.

`addChild` must return `(Allocator.Error || SupervisorError)!void` because it
can fail with `error.DuplicateChild` as well as allocation errors.

Shutdown sorting comparator:

```zig
fn shutdownBefore(_: void, left: ChildState, right: ChildState) bool {
    if (left.spec.shutdown_order != right.spec.shutdown_order) {
        return left.spec.shutdown_order > right.spec.shutdown_order;
    }
    return left.registration_index > right.registration_index;
}
```

- [ ] **Step 4: Run the green test**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

Run:

```bash
zig fmt --check packages/zigeffect/src/runtime/supervisor.zig packages/zigeffect/test/supervisor_test.zig
git add packages/zigeffect/src/runtime/supervisor.zig packages/zigeffect/test/supervisor_test.zig
git commit -m "feat(zigeffect): add supervisor child registry"
```

## Task 3: Restart Strategies

**Files:**
- Modify: `packages/zigeffect/src/runtime/supervisor.zig`
- Modify: `packages/zigeffect/test/supervisor_test.zig`

- [ ] **Step 1: Write failing strategy tests**

Append three tests named:

- `supervisor one-for-one restarts only failed child`
- `supervisor one-for-all restarts every restartable child`
- `supervisor rest-for-one restarts failed child and later children`

Each test should register three permanent children, call `startAll`, then call
`reportChildExit` with `.{ .failure = "boom" }`. Assert
`restarted_children`, child statuses, and restart counts:

- one-for-one: failed child count is 1, siblings are 0.
- one-for-all: all three restart counts are 1.
- rest-for-one on middle child: first is 0, middle and last are 1.

- [ ] **Step 2: Run the red test**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: failure because `reportChildExit` does not exist.

- [ ] **Step 3: Implement `reportChildExit` for strategies**

Add helpers:

```zig
fn exitIsSuccess(exit: SupervisorChildExit) bool;
fn restartAllowed(mode: SupervisorRestartMode, exit: SupervisorChildExit) bool;
fn strategyAffects(strategy: SupervisorStrategy, failed_index: usize, candidate_index: usize) bool;
fn markStoppedOrFailed(child: *ChildState, exit: SupervisorChildExit) void;
```

`reportChildExit` should:

- locate the child or return `error.ChildNotFound`.
- decide whether the failed child restart mode allows restart.
- if not restartable, mark stopped or failed and return a decision with
  `stopped_children = 1`.
- if restartable, visit children affected by the strategy and restart those
  whose own restart mode allows restart for the same exit.
- set affected child status to `running`, increment restart counts, and return
  `restarted_children`.

- [ ] **Step 4: Run green tests**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

Run:

```bash
zig fmt --check packages/zigeffect/src/runtime/supervisor.zig packages/zigeffect/test/supervisor_test.zig
git add packages/zigeffect/src/runtime/supervisor.zig packages/zigeffect/test/supervisor_test.zig
git commit -m "feat(zigeffect): add supervisor restart strategies"
```

## Task 4: Restart Modes, Intensity, And Cause Evidence

**Files:**
- Modify: `packages/zigeffect/src/runtime/supervisor.zig`
- Modify: `packages/zigeffect/test/supervisor_test.zig`

- [ ] **Step 1: Write failing restart-mode and intensity tests**

Append two tests named:

- `supervisor restart modes handle success and failure differently`
- `supervisor escalates when restart intensity is exceeded`

Assertions:

- permanent child restarts after success.
- transient child stops after success but restarts after failure.
- temporary child fails/stops and never increments restart count.
- intensity `{ .max_restarts = 2, .within_ms = 1_000 }` escalates on the
  third failure inside the window.
- escalation decision has `escalated = true`.
- `decision.cause().?` formats with `RestartIntensityExceeded`.

- [ ] **Step 2: Run the red test**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: failure if intensity tracking is not implemented.

- [ ] **Step 3: Implement restart history and escalation**

Add field:

```zig
    restart_history: std.ArrayList(u64) = .empty,
```

Update `deinit` to free it.

Add:

```zig
fn pruneRestartHistory(self: *Supervisor, now_ms: u64) void;
fn canRestartWithinIntensity(self: *Supervisor, now_ms: u64) bool;
fn recordRestart(self: *Supervisor, now_ms: u64) Allocator.Error!void;
fn markAffectedEscalated(self: *Supervisor, failed_index: usize, exit: SupervisorChildExit) usize;
```

`canRestartWithinIntensity` returns false when the current restart would make
the number of restarts in the window exceed `max_restarts`.

- [ ] **Step 4: Run green tests**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

Run:

```bash
zig fmt --check packages/zigeffect/src/runtime/supervisor.zig packages/zigeffect/test/supervisor_test.zig
git add packages/zigeffect/src/runtime/supervisor.zig packages/zigeffect/test/supervisor_test.zig
git commit -m "feat(zigeffect): add supervisor restart intensity"
```

## Task 5: Causal Supervisor Events

**Files:**
- Modify: `packages/zigeffect/src/services/causal.zig`
- Modify: `packages/zigeffect/src/runtime/supervisor.zig`
- Modify: `packages/zigeffect/test/supervisor_test.zig`

- [ ] **Step 1: Write failing causal tests**

Append a test that:

- creates a `CausalStore`.
- attaches it to a supervisor with run id 777.
- adds two children and calls `startAll`.
- reports one child failure that restarts.
- triggers an intensity escalation.
- calls `shutdownPlan`.
- snapshots the store and asserts event kinds include:
  `supervisor_child_started`, `supervisor_restart_decided`,
  `supervisor_escalated`, and `supervisor_shutdown_ordered`.

- [ ] **Step 2: Run the red test**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: failure because causal supervisor event kinds do not exist or are not
recorded.

- [ ] **Step 3: Add causal event kinds and supervisor recording**

Add to `CausalEventKind`:

```zig
    supervisor_child_started,
    supervisor_restart_decided,
    supervisor_escalated,
    supervisor_shutdown_ordered,
```

Classify them in `causalEventTaxonomy` as:

```zig
        .supervisor_child_started,
        .supervisor_restart_decided,
        .supervisor_escalated,
        .supervisor_shutdown_ordered,
        => .{
            .structural = true,
            .finding_evidence = true,
            .sampleable = false,
        },
```

In `Supervisor`, add:

```zig
    causal_store: ?*CausalStore = null,
    causal_run_id: ?u64 = null,
```

Implement `attachCausalStore`, `recordCausal`, and recording calls from
`startAll`, `reportChildExit`, escalation branch, and `shutdownPlan`.

- [ ] **Step 4: Run green tests**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

Run:

```bash
zig fmt --check packages/zigeffect/src/services/causal.zig packages/zigeffect/src/runtime/supervisor.zig packages/zigeffect/test/supervisor_test.zig
git add packages/zigeffect/src/services/causal.zig packages/zigeffect/src/runtime/supervisor.zig packages/zigeffect/test/supervisor_test.zig
git commit -m "feat(zigeffect): record supervisor causal events"
```

## Task 6: Architecture Docs, Roadmap Checklist, And Full Verification

**Files:**
- Modify: `packages/zigeffect/docs/architecture.md`
- Modify: `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`

- [ ] **Step 1: Update architecture docs**

In `packages/zigeffect/docs/architecture.md`, add `supervisor.zig` to
`src/runtime/`:

```markdown
- `supervisor.zig`: local supervision definitions, child specs, restart modes,
  one-for-one/one-for-all/rest-for-one strategies, restart intensity, shutdown
  ordering, Cause evidence, and causal supervisor events.
```

Add a short paragraph to the runtime section:

```markdown
Local supervision is a deterministic policy layer. It records child specs and
restart decisions, preserves failure evidence through `Cause`, and emits causal
events, but real async execution and distributed supervision remain separate
backend and cluster milestones.
```

- [ ] **Step 2: Mark Milestone 24 complete**

In the roadmap, mark Milestone 24 deliverables and acceptance checked.

- [ ] **Step 3: Run full Milestone 24 gate**

Run:

```bash
bun run zigeffect:test
cd packages/zigeffect && zig build examples
bun run zig:test
zig fmt --check packages/zigeffect/src/runtime/supervisor.zig packages/zigeffect/src/services/causal.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/supervisor_test.zig packages/zigeffect/test/all_test.zig
git diff --check
rg -n 'TO''DO|TB''D|implement'' later|fill'' in' packages/zigeffect/src/runtime packages/zigeffect/src/services/causal.zig packages/zigeffect/test/supervisor_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
```

Expected:

- The first five commands exit 0.
- The placeholder scan exits 1 with no matches.

- [ ] **Step 4: Commit closeout docs**

Run:

```bash
git add packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
git commit -m "docs(zigeffect): mark local supervision complete"
```

## Milestone 24 Completion Checklist

- [ ] Supervisor public surface committed.
- [ ] Child registry and shutdown ordering committed.
- [ ] Restart strategies committed.
- [ ] Restart modes, intensity, and Cause evidence committed.
- [ ] Causal supervisor events committed.
- [ ] Architecture and roadmap complete.
- [ ] Full verification gate passed.
