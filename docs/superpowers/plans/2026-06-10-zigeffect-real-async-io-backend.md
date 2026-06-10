# zigeffect Real Async IO Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Milestone 47 by adding a local async backend with backend-owned suspension, timer, network, file, and cancellation waits, then wire it into runtime contexts, workflow scheduler wakeups, durable queues, and cluster transport wait boundaries.

**Architecture:** Extend the existing async backend vtable instead of introducing a parallel runtime. `LocalAsyncBackendState` owns pending waits and ready wake events, while deterministic backends continue to reject async operations through the unsupported backend. `Runtime`, `FiberRuntime`, workflow scheduler, and cluster transport APIs receive optional async backend handles and keep their current deterministic APIs unchanged.

**Tech Stack:** Zig, existing zigeffect runtime/workflow/cluster modules, `bun run zigeffect:test`, `bun run zig:test`, `zig build examples`.

---

## File Responsibilities

Create:

- `packages/zigeffect/test/async_backend_test.zig`: red-green tests for local async backend, runtime/context propagation, scope interruption, workflow scheduler async wakeups, durable activity replay dedupe, and cluster transport async waits.
- `docs/superpowers/reports/2026-06-10-zigeffect-milestone-47-completion.md`: completion evidence after verification.

Modify:

- `packages/zigeffect/src/runtime/async_backend.zig`: extend the backend vtable and implement `LocalAsyncBackendState`.
- `packages/zigeffect/src/core/context.zig`: store optional async backend and expose helper methods.
- `packages/zigeffect/src/runtime/runtime.zig`: add `withAsyncBackend` and context propagation.
- `packages/zigeffect/src/runtime/fiber.zig`: add `withAsyncBackend` and context propagation.
- `packages/zigeffect/src/workflow/clock.zig`: expose pending timers for async scheduling.
- `packages/zigeffect/src/workflow/scheduler.zig`: add async backend field, init helpers, `tickAsync`, timer wake handling, and queue wake handling.
- `packages/zigeffect/src/cluster/transport.zig`: add async transport wait registration/completion helpers while preserving existing schemas.
- `packages/zigeffect/src/zigeffect.zig`: export new async backend and transport wait APIs.
- `packages/zigeffect/src/workflow/root.zig`: export pending timer list if needed by tests.
- `packages/zigeffect/src/cluster/root.zig`: export async transport wait helpers.
- `packages/zigeffect/test/all_test.zig`: import `async_backend_test.zig`.
- `packages/zigeffect/docs/architecture.md`: describe the implemented local async backend.
- `packages/zigeffect/docs/usage.md`: add user-facing backend usage notes.
- `packages/zigeffect/docs/effectts-parity.md`: update fiber/backend parity language.
- `packages/zigeffect/docs/public-api-review.md`: update backend compatibility notes.
- `packages/zigeffect/README.md`: mention the real local async backend and test gate.
- `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`: mark Milestone 47 complete after verification.
- `docs/superpowers/plans/2026-06-10-zigeffect-real-async-io-backend.md`: track this plan.

## Task 1: Red Tests For Async Backend Contract

- [x] Add `packages/zigeffect/test/async_backend_test.zig` with tests that reference these new declarations:

```zig
const std = @import("std");
const fx = @import("zigeffect");

test "local async backend exposes snapshot and idempotent wake lifecycle" {
    var state = fx.LocalAsyncBackendState.init(std.testing.allocator, .{ .now_ms = 100 });
    defer state.deinit();
    const backend = state.backend();

    const suspension = fx.Suspension{ .kind = .external, .id = 11, .label = "io" };
    try backend.suspendRuntime(.{ .suspension = suspension, .reason = "runtime wait" });
    try backend.wake(.{ .suspension_id = 11, .reason = "ready" });
    try backend.wake(.{ .suspension_id = 11, .reason = "duplicate" });

    const snapshot = backend.snapshot();
    try std.testing.expectEqual(@as(usize, 0), snapshot.pending_count);
    try std.testing.expectEqual(@as(usize, 1), snapshot.ready_count);
    try std.testing.expectEqual(@as(usize, 1), snapshot.duplicate_wake_count);

    const wake = (try backend.pollWake()).?;
    try std.testing.expectEqual(@as(u64, 11), wake.suspension.id);
    try std.testing.expectEqual(fx.AsyncWaitStatus.ready, wake.status);
    try std.testing.expectEqual(@as(?fx.BackendWakeEvent, null), try backend.pollWake());
}
```

- [x] Add tests for timer due behavior, typed network/file IO waits, interruption, async scope finalization, runtime/fiber context propagation, workflow scheduler `tickAsync`, queue wake, durable activity replay dedupe, and cluster transport async wait helpers.
- [x] Import the new test file from `packages/zigeffect/test/all_test.zig`.
- [x] Run `cd packages/zigeffect && zig build test-raw`.
- [x] Confirm the command fails because the new M47 declarations do not exist.
- [x] Commit the red tests with `test(zigeffect): specify real async backend`.

## Task 2: Implement Local Async Backend

- [x] Extend `AsyncBackendError` with concrete local backend errors:

```zig
pub const AsyncBackendError = error{
    UnsupportedBackendCapability,
    UnknownSuspension,
    InvalidIoWaitKind,
};
```

- [x] Add `AsyncWaitKind`, `AsyncWaitStatus`, `AsyncIoWaitKind`, `AsyncIoInterest`, `BackendIoWaitRequest`, `BackendIoCompleteRequest`, `BackendWakeEvent`, and `AsyncBackendSnapshot`.
- [x] Extend `AsyncBackend.VTable` with `register_io_wait`, `complete_io`, `poll_wake`, and `snapshot`.
- [x] Update `UnsupportedAsyncBackendState` so unsupported operations reject all async behavior and `snapshot()` returns zero counts.
- [x] Implement `LocalAsyncBackendState` with owned wait records:

```zig
pub const LocalAsyncBackendOptions = struct {
    now_ms: u64 = 0,
};

pub const LocalAsyncBackendState = struct {
    allocator: Allocator,
    capabilities: BackendCapabilities,
    now_ms: u64,
    waits: std.ArrayList(LocalAsyncWait) = .empty,
    ready: std.ArrayList(BackendWakeEvent) = .empty,
    completed_ids: std.ArrayList(u64) = .empty,
    duplicate_suspend_count: usize = 0,
    duplicate_wake_count: usize = 0,
    interrupt_count: usize = 0,

    pub fn init(allocator: Allocator, options: LocalAsyncBackendOptions) LocalAsyncBackendState;
    pub fn deinit(self: *LocalAsyncBackendState) void;
    pub fn backend(self: *LocalAsyncBackendState) AsyncBackend;
    pub fn advanceTo(self: *LocalAsyncBackendState, now_ms: u64) AsyncBackendError!usize;
};
```

- [x] Make duplicate suspend, timer, IO wait, wake, and interrupt calls idempotent by suspension id.
- [x] Run `cd packages/zigeffect && zig build test-raw`.
- [x] Confirm backend-only declarations compile while runtime/workflow/cluster red tests still fail.
- [x] Commit with `feat(zigeffect): add local async backend`.

## Task 3: Wire Runtime, Fiber Runtime, Context, And Scope Cleanup

- [x] Add `async_backend: ?AsyncBackend = null` to `Context`.
- [x] Add `Context.requireAsyncBackend`, `Context.suspendRuntime`, and `Context.registerIoWait`.
- [x] Add `async_backend: ?AsyncBackend = null` to `Runtime` and `FiberRuntime`.
- [x] Add `withAsyncBackend` to both runtime types and set `backend` from `backend.capabilities`.
- [x] Propagate `async_backend` in `Runtime.context` and `FiberRuntime.context`.
- [x] Add `attachAsyncInterruptFinalizer(scope, backend, suspension_id, reason)` in `runtime/async_backend.zig`.
- [x] Run `cd packages/zigeffect && zig build test-raw`.
- [x] Confirm runtime/context/scope tests pass while workflow/cluster red tests still fail.
- [x] Commit with `feat(zigeffect): propagate async backend through runtime contexts`.

## Task 4: Integrate Workflow Scheduler, Durable Timers, And Durable Queues

- [x] Add `PendingTimerList` and `DurableClock.pendingTimers()` that returns scheduled non-terminal timers regardless of due time.
- [x] Add optional `async_backend: ?AsyncBackend` to `WorkflowScheduler`.
- [x] Add `WorkflowScheduler.initWithAsyncBackend` and `WorkflowScheduler.withAsyncBackend`.
- [x] Add `WorkflowScheduler.tickAsync` that registers pending timers, advances local backend time through the backend facade, polls wake events, fires due timers, cancels interrupted timers, processes queues, and wakes queue item suspensions after terminal queue writes.
- [x] Keep `WorkflowScheduler.tick` byte-for-byte behavior compatible except for shared helper extraction required by `tickAsync`.
- [x] Add a test that calls `WorkflowContext.sleep`, then `scheduler.tickAsync` before and after `LocalAsyncBackendState.advanceTo`, and asserts one `timer_fired` and one `workflow_resumed`.
- [x] Add a test that queue worker completion wakes the backend queue suspension after the journal terminal event.
- [x] Add a test that duplicate wakes after durable activity completion do not run the activity twice.
- [x] Run `cd packages/zigeffect && zig build test-raw`.
- [x] Confirm workflow tests compile while cluster wait red tests still fail.
- [x] Commit with `feat(zigeffect): wake durable workflows from async backend`.

## Task 5: Integrate Cluster Transport Async Waits

- [x] Add `ClusterTransportAsyncWait` in `cluster/transport.zig` with request, suspension id, and submitted state.
- [x] Add `registerClusterTransportWait(allocator, backend, request, suspension_id)` that registers a network IO wait using request timeout and idempotency detail.
- [x] Add `completeClusterTransportWait(allocator, backend, transport, wait)` that completes IO, polls the wake, sends through existing `ClusterTransport.send`, and returns the response.
- [x] Preserve existing request/response JSON schemas and in-process/loopback behavior.
- [x] Export the helpers from `cluster/root.zig` and `zigeffect.zig`.
- [x] Run `cd packages/zigeffect && zig build test-raw`.
- [x] Confirm all raw package tests pass.
- [x] Commit with `feat(zigeffect): add async cluster transport waits`.

## Task 6: Documentation And Roadmap Closeout

- [ ] Update architecture, usage, Effect parity, public API review, and README docs to describe the implemented local async backend.
- [ ] Add `docs/superpowers/reports/2026-06-10-zigeffect-milestone-47-completion.md` after full verification.
- [ ] Mark Milestone 47 deliverables and acceptance boxes complete in the durable workflows and clustering roadmap.
- [ ] Update this plan's checkboxes as tasks finish.
- [ ] Run a scoped marker scan over all M47 files.
- [ ] Commit docs and roadmap closeout with `docs(zigeffect): mark real async io backend complete`.

## Task 7: Final Verification

- [ ] Run:

```bash
cd packages/zigeffect
zig build test-raw
zig build release-gate
zig build examples
cd ../..
bun run zigeffect:test
bun run zig:test
zig fmt --check \
  packages/zigeffect/src/runtime/async_backend.zig \
  packages/zigeffect/src/core/context.zig \
  packages/zigeffect/src/runtime/runtime.zig \
  packages/zigeffect/src/runtime/fiber.zig \
  packages/zigeffect/src/workflow/clock.zig \
  packages/zigeffect/src/workflow/scheduler.zig \
  packages/zigeffect/src/cluster/transport.zig \
  packages/zigeffect/src/zigeffect.zig \
  packages/zigeffect/src/workflow/root.zig \
  packages/zigeffect/src/cluster/root.zig \
  packages/zigeffect/test/async_backend_test.zig \
  packages/zigeffect/test/all_test.zig
git diff --check
```

- [ ] Run the scoped marker scan over code, docs, spec, plan, report, and roadmap files.
- [ ] Check `git status --short` and confirm only intended files are committed.
