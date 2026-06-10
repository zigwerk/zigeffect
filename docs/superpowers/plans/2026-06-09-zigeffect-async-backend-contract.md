# zigeffect Async Backend Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add async backend operation contracts, deterministic unsupported behavior, backend capability diagnostics, workflow engine requirement checks, and Milestone 22 verification.

**Architecture:** Keep `BackendCapabilities` as the public runtime capability record and add operation-specific async flags. Add a synchronous Zig vtable contract for future async backends, diagnostic helpers for missing capabilities, and workflow engine helpers that can enforce those requirements before later scheduler milestones call async-only features.

**Tech Stack:** Zig 0.16, existing `packages/zigeffect` runtime/workflow modules, `bun run zigeffect:test`, `bun run zig:test`.

---

## File Structure

- Modify: `packages/zigeffect/src/runtime/backend.zig`
  - Add `can_wake`, `can_schedule_timers`, `can_interrupt`, and `can_durable_suspend`.
- Create: `packages/zigeffect/src/runtime/async_backend.zig`
  - Define async backend request structs, `AsyncBackend`, and unsupported deterministic backend.
- Create: `packages/zigeffect/src/runtime/backend_diagnostics.zig`
  - Define `BackendFeature`, requirement helpers, support checks, and diagnostic formatter.
- Modify: `packages/zigeffect/src/workflow/engine.zig`
  - Store backend capabilities and expose requirement checks.
- Modify: `packages/zigeffect/src/workflow/root.zig`
  - Re-export workflow backend requirement aliases.
- Modify: `packages/zigeffect/src/zigeffect.zig`
  - Add runtime module imports and root facade aliases.
- Create: `packages/zigeffect/test/backend_conformance_test.zig`
  - Conformance and diagnostics tests for the backend contract.
- Modify: `packages/zigeffect/test/all_test.zig`
  - Import the new backend conformance test file.
- Modify: `packages/zigeffect/test/workflow_test.zig`
  - Add workflow engine backend requirement tests.
- Modify: `packages/zigeffect/docs/architecture.md`
  - Document the async backend trait and diagnostics boundary.
- Modify: `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
  - Mark Milestone 22 complete after verification.

## Task 1: Backend Operation Capabilities

**Files:**
- Create: `packages/zigeffect/test/backend_conformance_test.zig`
- Modify: `packages/zigeffect/test/all_test.zig`
- Modify: `packages/zigeffect/src/runtime/backend.zig`

- [ ] **Step 1: Write failing capability tests**

Create `packages/zigeffect/test/backend_conformance_test.zig`:

```zig
const std = @import("std");
const fx = @import("zigeffect");

test "backend constructors expose async operation capabilities" {
    const deterministic = fx.deterministicBackend();
    try std.testing.expectEqual(fx.BackendKind.deterministic, deterministic.kind);
    try std.testing.expect(!deterministic.can_suspend);
    try std.testing.expect(!deterministic.can_wake);
    try std.testing.expect(!deterministic.can_schedule_timers);
    try std.testing.expect(!deterministic.can_interrupt);
    try std.testing.expect(!deterministic.can_durable_suspend);

    const durable = fx.durableLocalBackend();
    try std.testing.expectEqual(fx.BackendKind.durable_local, durable.kind);
    try std.testing.expect(durable.can_suspend);
    try std.testing.expect(durable.can_wake);
    try std.testing.expect(durable.can_schedule_timers);
    try std.testing.expect(durable.can_interrupt);
    try std.testing.expect(durable.can_durable_suspend);
    try std.testing.expect(!durable.can_interrupt_blocking_io);

    const async_backend = fx.asyncLocalBackend();
    try std.testing.expectEqual(fx.BackendKind.async_local, async_backend.kind);
    try std.testing.expect(async_backend.can_suspend);
    try std.testing.expect(async_backend.can_wake);
    try std.testing.expect(async_backend.can_schedule_timers);
    try std.testing.expect(async_backend.can_interrupt);
    try std.testing.expect(!async_backend.can_durable_suspend);

    const clustered = fx.clusteredBackend();
    try std.testing.expectEqual(fx.BackendKind.clustered, clustered.kind);
    try std.testing.expect(clustered.can_wake);
    try std.testing.expect(clustered.can_schedule_timers);
    try std.testing.expect(clustered.can_interrupt);
    try std.testing.expect(clustered.can_durable_suspend);
}
```

Add this import to `packages/zigeffect/test/all_test.zig`:

```zig
    _ = @import("backend_conformance_test.zig");
```

- [ ] **Step 2: Run the red test**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: compile failure because `BackendCapabilities` has no `can_wake`,
`can_schedule_timers`, `can_interrupt`, or `can_durable_suspend` fields.

- [ ] **Step 3: Add operation-specific backend flags**

In `packages/zigeffect/src/runtime/backend.zig`, extend `BackendCapabilities`:

```zig
can_wake: bool,
can_schedule_timers: bool,
can_interrupt: bool,
can_durable_suspend: bool,
```

Set constructor values:

```zig
// deterministicBackend
.can_wake = false,
.can_schedule_timers = false,
.can_interrupt = false,
.can_durable_suspend = false,

// durableLocalBackend
.can_wake = true,
.can_schedule_timers = true,
.can_interrupt = true,
.can_durable_suspend = true,

// asyncLocalBackend
.can_wake = true,
.can_schedule_timers = true,
.can_interrupt = true,
.can_durable_suspend = false,

// clusteredBackend
.can_wake = true,
.can_schedule_timers = true,
.can_interrupt = true,
.can_durable_suspend = true,
```

- [ ] **Step 4: Run the green test**

Run:

```bash
bun run zigeffect:test
```

Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/zigeffect/src/runtime/backend.zig packages/zigeffect/test/backend_conformance_test.zig packages/zigeffect/test/all_test.zig
git commit -m "feat(zigeffect): expand backend operation capabilities"
```

## Task 2: Async Backend Trait Shape

**Files:**
- Modify: `packages/zigeffect/test/backend_conformance_test.zig`
- Create: `packages/zigeffect/src/runtime/async_backend.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`

- [ ] **Step 1: Write failing unsupported async backend tests**

Append to `packages/zigeffect/test/backend_conformance_test.zig`:

```zig
test "deterministic unsupported async backend rejects suspend wake timer and interrupt" {
    var state = fx.UnsupportedAsyncBackendState.init(fx.deterministicBackend());
    const backend = state.backend();

    try std.testing.expectEqual(fx.BackendKind.deterministic, backend.capabilities.kind);
    try std.testing.expectError(error.UnsupportedBackendCapability, backend.suspendRuntime(.{
        .suspension = .{ .kind = .timer, .id = 1, .label = "wake" },
        .workflow_id = 7,
        .execution_id = 8,
        .reason = "sleep",
    }));
    try std.testing.expectError(error.UnsupportedBackendCapability, backend.wake(.{
        .suspension_id = 1,
        .reason = "timer fired",
    }));
    try std.testing.expectError(error.UnsupportedBackendCapability, backend.scheduleTimer(.{
        .suspension = .{ .kind = .timer, .id = 1, .label = "wake" },
        .due_time_ms = 250,
        .now_ms = 100,
    }));
    try std.testing.expectError(error.UnsupportedBackendCapability, backend.interrupt(.{
        .target_id = 99,
        .reason = "operator",
    }));
}
```

- [ ] **Step 2: Run the red test**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: compile failure because `UnsupportedAsyncBackendState` and async
backend request types do not exist.

- [ ] **Step 3: Implement async backend trait**

Create `packages/zigeffect/src/runtime/async_backend.zig`:

```zig
const backend_mod = @import("backend.zig");
const control = @import("control.zig");

pub const BackendCapabilities = backend_mod.BackendCapabilities;
pub const Suspension = control.Suspension;

pub const AsyncBackendError = error{
    UnsupportedBackendCapability,
};

pub const BackendSuspendRequest = struct {
    suspension: Suspension,
    workflow_id: ?u64 = null,
    execution_id: ?u64 = null,
    reason: []const u8 = "",
};

pub const BackendWakeRequest = struct {
    suspension_id: u64,
    reason: []const u8 = "",
};

pub const BackendTimerRequest = struct {
    suspension: Suspension,
    due_time_ms: u64,
    now_ms: u64 = 0,
};

pub const BackendInterruptRequest = struct {
    target_id: u64,
    reason: []const u8 = "",
};

pub const AsyncBackend = struct {
    context: ?*anyopaque = null,
    capabilities: BackendCapabilities,
    vtable: *const VTable,

    pub const VTable = struct {
        suspend_runtime: *const fn (?*anyopaque, BackendSuspendRequest) AsyncBackendError!void,
        wake: *const fn (?*anyopaque, BackendWakeRequest) AsyncBackendError!void,
        schedule_timer: *const fn (?*anyopaque, BackendTimerRequest) AsyncBackendError!void,
        interrupt: *const fn (?*anyopaque, BackendInterruptRequest) AsyncBackendError!void,
    };

    pub fn suspendRuntime(self: AsyncBackend, request: BackendSuspendRequest) AsyncBackendError!void {
        return self.vtable.suspend_runtime(self.context, request);
    }

    pub fn wake(self: AsyncBackend, request: BackendWakeRequest) AsyncBackendError!void {
        return self.vtable.wake(self.context, request);
    }

    pub fn scheduleTimer(self: AsyncBackend, request: BackendTimerRequest) AsyncBackendError!void {
        return self.vtable.schedule_timer(self.context, request);
    }

    pub fn interrupt(self: AsyncBackend, request: BackendInterruptRequest) AsyncBackendError!void {
        return self.vtable.interrupt(self.context, request);
    }
};

pub const UnsupportedAsyncBackendState = struct {
    capabilities: BackendCapabilities,

    pub fn init(capabilities: BackendCapabilities) UnsupportedAsyncBackendState {
        return .{ .capabilities = capabilities };
    }

    pub fn backend(self: *UnsupportedAsyncBackendState) AsyncBackend {
        return .{ .context = self, .capabilities = self.capabilities, .vtable = &unsupported_vtable };
    }
};

fn unsupportedSuspend(context: ?*anyopaque, request: BackendSuspendRequest) AsyncBackendError!void {
    _ = context;
    _ = request;
    return error.UnsupportedBackendCapability;
}

fn unsupportedWake(context: ?*anyopaque, request: BackendWakeRequest) AsyncBackendError!void {
    _ = context;
    _ = request;
    return error.UnsupportedBackendCapability;
}

fn unsupportedScheduleTimer(context: ?*anyopaque, request: BackendTimerRequest) AsyncBackendError!void {
    _ = context;
    _ = request;
    return error.UnsupportedBackendCapability;
}

fn unsupportedInterrupt(context: ?*anyopaque, request: BackendInterruptRequest) AsyncBackendError!void {
    _ = context;
    _ = request;
    return error.UnsupportedBackendCapability;
}

const unsupported_vtable: AsyncBackend.VTable = .{
    .suspend_runtime = unsupportedSuspend,
    .wake = unsupportedWake,
    .schedule_timer = unsupportedScheduleTimer,
    .interrupt = unsupportedInterrupt,
};
```

Update `packages/zigeffect/src/zigeffect.zig` runtime namespace and root aliases
to expose the module and types.

- [ ] **Step 4: Run the green test**

Run:

```bash
bun run zigeffect:test
```

Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/zigeffect/src/runtime/async_backend.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/backend_conformance_test.zig
git commit -m "feat(zigeffect): add async backend trait shape"
```

## Task 3: Backend Capability Diagnostics

**Files:**
- Modify: `packages/zigeffect/test/backend_conformance_test.zig`
- Create: `packages/zigeffect/src/runtime/backend_diagnostics.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`

- [ ] **Step 1: Write failing diagnostics tests**

Append:

```zig
test "backend diagnostics explain unsupported async feature" {
    const requirement = fx.BackendCapabilityRequirement{
        .feature = .timer,
        .operation = "workflow.sleep",
        .workflow_name = "approval",
    };

    try std.testing.expect(!fx.backendSupportsFeature(fx.deterministicBackend(), .timer));
    try std.testing.expect(fx.backendSupportsFeature(fx.durableLocalBackend(), .timer));
    try std.testing.expectError(error.UnsupportedBackendCapability, fx.requireBackendFeature(fx.deterministicBackend(), requirement));

    const diagnostic = try fx.formatBackendCapabilityDiagnostic(std.testing.allocator, fx.deterministicBackend(), requirement);
    defer std.testing.allocator.free(diagnostic);
    try std.testing.expect(std.mem.indexOf(u8, diagnostic, "backend=deterministic") != null);
    try std.testing.expect(std.mem.indexOf(u8, diagnostic, "operation=workflow.sleep") != null);
    try std.testing.expect(std.mem.indexOf(u8, diagnostic, "feature=timer") != null);
    try std.testing.expect(std.mem.indexOf(u8, diagnostic, "workflow=approval") != null);
    try std.testing.expect(std.mem.indexOf(u8, diagnostic, "use durableLocalBackend, asyncLocalBackend, or clusteredBackend") != null);
}
```

- [ ] **Step 2: Run the red test**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: compile failure because diagnostic types/functions do not exist.

- [ ] **Step 3: Implement diagnostics**

Create `packages/zigeffect/src/runtime/backend_diagnostics.zig` with
`BackendFeature`, `BackendCapabilityRequirement`, `BackendCapabilityError`,
`backendSupportsFeature`, `requireBackendFeature`, and
`formatBackendCapabilityDiagnostic`. Map features to capability fields:

```zig
.suspension => backend.can_suspend,
.wake => backend.can_wake,
.timer => backend.can_schedule_timers,
.interrupt => backend.can_interrupt,
.durable_suspend => backend.can_durable_suspend,
.persistence => backend.can_persist,
.distribution => backend.can_distribute,
.supervision => backend.can_supervise,
.parallelism => backend.can_parallel,
```

Format diagnostics with `std.fmt.allocPrint`.

- [ ] **Step 4: Run the green test**

Run:

```bash
bun run zigeffect:test
```

Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/zigeffect/src/runtime/backend_diagnostics.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/backend_conformance_test.zig
git commit -m "feat(zigeffect): add backend capability diagnostics"
```

## Task 4: Workflow Engine Backend Requirements

**Files:**
- Modify: `packages/zigeffect/test/workflow_test.zig`
- Modify: `packages/zigeffect/src/workflow/engine.zig`
- Modify: `packages/zigeffect/src/workflow/root.zig`

- [ ] **Step 1: Write failing workflow engine requirement tests**

Add near existing workflow engine tests:

```zig
test "workflow engine stores backend capabilities and checks requirements" {
    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();

    var engine = fx.workflow.WorkflowEngine.initWithBackend(
        std.testing.allocator,
        journal_memory.asJournalStore(),
        fx.durableLocalBackend(),
    );
    defer engine.deinit();

    try std.testing.expectEqual(fx.BackendKind.durable_local, engine.backendCapabilities().kind);
    try engine.requireBackendFeature(.{
        .feature = .timer,
        .operation = "workflow.sleep",
        .workflow_name = "approval",
    });
}

test "workflow engine formats backend requirement diagnostics" {
    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();

    var engine = fx.workflow.WorkflowEngine.init(std.testing.allocator, journal_memory.asJournalStore());
    defer engine.deinit();

    const requirement = fx.workflow.WorkflowBackendRequirement{
        .feature = .timer,
        .operation = "workflow.sleep",
        .workflow_name = "approval",
    };

    try std.testing.expectError(error.UnsupportedBackendCapability, engine.requireBackendFeature(requirement));
    const diagnostic = try engine.formatBackendRequirementDiagnostic(std.testing.allocator, requirement);
    defer std.testing.allocator.free(diagnostic);
    try std.testing.expect(std.mem.indexOf(u8, diagnostic, "backend=deterministic") != null);
    try std.testing.expect(std.mem.indexOf(u8, diagnostic, "workflow=approval") != null);
}
```

- [ ] **Step 2: Run the red test**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: compile failure because `WorkflowEngine.initWithBackend`,
`WorkflowBackendRequirement`, and requirement methods do not exist.

- [ ] **Step 3: Implement workflow engine backend checks**

In `packages/zigeffect/src/workflow/engine.zig`, import runtime backend and
diagnostics modules. Add:

```zig
pub const BackendCapabilities = backend_mod.BackendCapabilities;
pub const deterministicBackend = backend_mod.deterministicBackend;
pub const WorkflowBackendRequirement = backend_diagnostics.BackendCapabilityRequirement;
```

Add `UnsupportedBackendCapability` to `WorkflowEngineError`, add
`backend: BackendCapabilities = deterministicBackend()` to `WorkflowEngine`,
and implement:

```zig
pub fn initWithBackend(allocator: Allocator, journal_store: JournalStore, backend: BackendCapabilities) WorkflowEngine
pub fn backendCapabilities(self: *const WorkflowEngine) BackendCapabilities
pub fn requireBackendFeature(self: *const WorkflowEngine, requirement: WorkflowBackendRequirement) WorkflowEngineError!void
pub fn formatBackendRequirementDiagnostic(self: *const WorkflowEngine, allocator: Allocator, requirement: WorkflowBackendRequirement) Allocator.Error![]const u8
```

Re-export `WorkflowBackendRequirement` from `workflow/root.zig`.

- [ ] **Step 4: Run the green test**

Run:

```bash
bun run zigeffect:test
```

Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/zigeffect/src/workflow/engine.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/test/workflow_test.zig
git commit -m "feat(zigeffect): add workflow backend requirements"
```

## Task 5: Documentation, Roadmap, And Verification

**Files:**
- Modify: `packages/zigeffect/docs/architecture.md`
- Modify: `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`

- [ ] **Step 1: Update architecture docs**

Add this paragraph near the runtime backend boundary:

```markdown
Runtime backend capabilities include operation-specific async workflow flags for
wake, timer scheduling, interruption, and durable suspension. The
`runtime/async_backend.zig` vtable names the future suspend, wake, timer, and
interrupt operations without implementing real async I/O yet. Backend
diagnostics format missing capability errors so workflow code can fail clearly
before a deterministic backend attempts async-only behavior.
```

- [ ] **Step 2: Mark Milestone 22 complete**

In the roadmap, mark all Milestone 22 deliverables and acceptance checks `[x]`.

- [ ] **Step 3: Run full verification gate**

Run:

```bash
bun run zigeffect:test
cd packages/zigeffect && zig build examples
bun run zig:test
zig fmt --check packages/zigeffect/src/runtime/backend.zig packages/zigeffect/src/runtime/async_backend.zig packages/zigeffect/src/runtime/backend_diagnostics.zig packages/zigeffect/src/workflow/engine.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/backend_conformance_test.zig packages/zigeffect/test/workflow_test.zig packages/zigeffect/test/all_test.zig
git diff --check
rg -n 'TO''DO|TB''D|implement'' later|fill'' in' packages/zigeffect/src/runtime packages/zigeffect/src/workflow packages/zigeffect/test/backend_conformance_test.zig packages/zigeffect/test/workflow_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
```

Expected:

- all build and test commands pass;
- formatting and whitespace checks pass;
- placeholder scan exits with no matches.

- [ ] **Step 4: Commit docs and roadmap**

```bash
git add packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
git commit -m "docs(zigeffect): mark async backend contract complete"
```

## Self-Review

- Spec coverage: capabilities, async trait shape, deterministic conformance,
  workflow engine requirements, diagnostics, and acceptance checks each have a
  task.
- Placeholder scan: no open placeholders remain in this plan.
- Type consistency: backend feature names, request names, and workflow
  requirement aliases are consistent across tests, implementation, and exports.
