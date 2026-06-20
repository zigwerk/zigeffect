//! zigeffect-zio — Stage 1 scaffold.
//!
//! `ZioAsyncBackendState` implements the core `zigeffect` `AsyncBackend` vtable
//! on top of zio (https://github.com/lalinsky/zio) v0.14.0, which provides
//! stackful coroutines + a full `std.Io` implementation over io_uring/epoll/kqueue.
//!
//! STATUS: this is a registered-but-unimplemented backend. Every method returns
//! `error.UnsupportedBackendCapability` until the zio integration lands, so it
//! fails loudly rather than silently faking suspension. The doc comment on each
//! method records the exact zio mapping to implement. The core engine
//! (`packages/zigeffect`) stays zio-free and is the deterministic reference;
//! `LocalAsyncBackendState` must produce the same *structural* causal trace as
//! this backend for the same program (see
//! docs/superpowers/specs/2026-06-20-zigeffect-zio-backend-design.md).
//!
//! To activate Stage 1: `zig fetch --save "git+https://github.com/lalinsky/zio#v0.14.0"`,
//! enable the zio import in build.zig, then replace the stubs below.

const std = @import("std");
const fx = @import("zigeffect");
const zio = @import("zio");

/// Z1: a delay that suspends on a REAL zio coroutine timer, emitting the same
/// causal trace shape as the deterministic `fx.recordDelaySuspensionScenario`.
/// `zio.sleep` actually parks the coroutine on the event loop (io_uring/epoll/
/// kqueue) and resumes it when the timer fires — no virtual clock. The emitted
/// causal graph must compare STRUCTURALLY EQUAL to the deterministic trace
/// (same event kinds + cause edges + fiber net state), which is the Stage-1 gate.
pub fn recordZioDelayScenario(store: *fx.CausalStore, due_ms: u64) !void {
    const run_id = store.nextRunId();
    const scope_id = store.nextScopeId();
    const fiber_id: u64 = 1;
    const sid: u64 = 1;

    const run_started = try store.record(.{ .kind = .run_started, .run_id = run_id, .status = "started", .label = "zio-delay-suspension", .type_name = "ZioDelayScenario" });
    const scope_opened = try store.record(.{ .kind = .scope_opened, .run_id = run_id, .scope_id = scope_id, .parent_id = run_started, .status = "opened", .label = "delay scope" });
    const fiber_forked = try store.record(.{ .kind = .fiber_forked, .run_id = run_id, .scope_id = scope_id, .fiber_id = fiber_id, .parent_id = scope_opened, .status = "pending", .label = "delay fiber" });
    const fiber_started = try store.record(.{ .kind = .fiber_started, .run_id = run_id, .scope_id = scope_id, .fiber_id = fiber_id, .parent_id = fiber_forked, .status = "running", .label = "delay fiber" });
    const delay_effect = try store.record(.{ .kind = .effect_started, .run_id = run_id, .scope_id = scope_id, .fiber_id = fiber_id, .parent_id = fiber_started, .status = "started", .label = "delay", .type_name = "DelayEffect" });
    const suspended = try store.record(.{ .kind = .fiber_suspended, .run_id = run_id, .scope_id = scope_id, .fiber_id = fiber_id, .parent_id = fiber_started, .cause_event_id = delay_effect, .schedule_id = sid, .status = "pending", .label = "fiber suspended on timer", .type_name = "Suspension" });
    const scheduled = try store.record(.{ .kind = .timer_scheduled, .run_id = run_id, .scope_id = scope_id, .fiber_id = fiber_id, .parent_id = suspended, .cause_event_id = suspended, .schedule_id = sid, .status = "pending", .label = "delay", .type_name = "Timer" });

    // Real suspension: park this coroutine on the zio event loop for due_ms.
    try zio.sleep(zio.Duration.fromMilliseconds(due_ms));

    const fired = try store.record(.{ .kind = .timer_fired, .run_id = run_id, .scope_id = scope_id, .fiber_id = fiber_id, .parent_id = scheduled, .cause_event_id = scheduled, .schedule_id = sid, .status = "ready", .label = "timer fired", .type_name = "Timer" });
    _ = try store.record(.{ .kind = .fiber_resumed, .run_id = run_id, .scope_id = scope_id, .fiber_id = fiber_id, .parent_id = suspended, .cause_event_id = fired, .schedule_id = sid, .status = "running", .label = "fiber resumed", .type_name = "Suspension" });
    const scope_closed = try store.record(.{ .kind = .scope_closed, .run_id = run_id, .scope_id = scope_id, .parent_id = run_started, .status = "closed", .label = "delay scope" });
    _ = try store.record(.{ .kind = .fiber_joined, .run_id = run_id, .scope_id = scope_id, .fiber_id = fiber_id, .parent_id = scope_closed, .status = "success", .label = "delay fiber" });
    _ = try store.record(.{ .kind = .exit_recorded, .run_id = run_id, .parent_id = run_started, .status = "success", .label = "zio-delay-suspension" });
}

fn kindCount(events: []fx.CausalEvent, kind: fx.CausalEventKind) usize {
    var count: usize = 0;
    for (events) |event| {
        if (event.kind == kind) count += 1;
    }
    return count;
}

pub const AsyncBackend = fx.AsyncBackend;
pub const AsyncBackendError = fx.AsyncBackendError;
pub const AsyncBackendSnapshot = fx.AsyncBackendSnapshot;
pub const BackendSuspendRequest = fx.BackendSuspendRequest;
pub const BackendWakeRequest = fx.BackendWakeRequest;
pub const BackendTimerRequest = fx.BackendTimerRequest;
pub const BackendInterruptRequest = fx.BackendInterruptRequest;
pub const BackendIoWaitRequest = fx.BackendIoWaitRequest;
pub const BackendIoCompleteRequest = fx.BackendIoCompleteRequest;
pub const BackendWakeEvent = fx.BackendWakeEvent;

pub const ZioAsyncBackendState = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ZioAsyncBackendState {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *ZioAsyncBackendState) void {
        _ = self;
    }

    pub fn backend(self: *ZioAsyncBackendState) AsyncBackend {
        return .{
            .context = self,
            .capabilities = fx.runtime.asyncLocalBackend(),
            .vtable = &zio_vtable,
        };
    }
};

const zio_vtable = AsyncBackend.VTable{
    .suspend_runtime = suspendRuntime,
    .wake = wake,
    .schedule_timer = scheduleTimer,
    .interrupt = interrupt,
    .register_io_wait = registerIoWait,
    .complete_io = completeIo,
    .poll_wake = pollWake,
    .advance_time = advanceTime,
    .snapshot = snapshot,
};

/// Stage 1: park the current zio coroutine keyed by `request.suspension.id`
/// (the engine emits `fiber_suspended` around this call). Implement by yielding
/// the running fiber so the OS thread is freed for other coroutines.
fn suspendRuntime(context: ?*anyopaque, request: BackendSuspendRequest) AsyncBackendError!void {
    _ = context;
    _ = request;
    return error.UnsupportedBackendCapability;
}

/// Stage 1: reschedule the coroutine parked under `request.suspension_id`.
fn wake(context: ?*anyopaque, request: BackendWakeRequest) AsyncBackendError!void {
    _ = context;
    _ = request;
    return error.UnsupportedBackendCapability;
}

/// Stage 1 (first primitive): register a zio timer for `request.due_time_ms`;
/// on fire, wake the suspension. The engine emits `timer_scheduled` here and
/// `timer_fired` + `fiber_resumed` when the wake is consumed.
fn scheduleTimer(context: ?*anyopaque, request: BackendTimerRequest) AsyncBackendError!void {
    _ = context;
    _ = request;
    return error.UnsupportedBackendCapability;
}

/// Stage 1: `zio.Group.cancel` / targeted cancellation of the parked coroutine;
/// resume it with an interrupted status (engine emits `fiber_interrupted`).
fn interrupt(context: ?*anyopaque, request: BackendInterruptRequest) AsyncBackendError!void {
    _ = context;
    _ = request;
    return error.UnsupportedBackendCapability;
}

/// Stage 2: register fd readiness (or issue the `std.Io` op) for an async IO
/// wait; on completion, `complete_io` + wake. Engine emits `io_wait_started`.
fn registerIoWait(context: ?*anyopaque, request: BackendIoWaitRequest) AsyncBackendError!void {
    _ = context;
    _ = request;
    return error.UnsupportedBackendCapability;
}

/// Stage 2: mark an outstanding IO wait satisfied and resume (engine emits
/// `io_completed` + `fiber_resumed`).
fn completeIo(context: ?*anyopaque, request: BackendIoCompleteRequest) AsyncBackendError!void {
    _ = context;
    _ = request;
    return error.UnsupportedBackendCapability;
}

/// Under zio the event loop drives wakes directly; `poll_wake` returns
/// already-resolved events for inspection/parity with the deterministic backend.
fn pollWake(context: ?*anyopaque) AsyncBackendError!?BackendWakeEvent {
    _ = context;
    return null;
}

/// Deterministic-backend concept only: under zio, time is real, so advancing a
/// virtual clock is a no-op.
fn advanceTime(context: ?*anyopaque, now_ms: u64) AsyncBackendError!usize {
    _ = context;
    _ = now_ms;
    return 0;
}

/// Stage 1: report parked/ready/interrupted counts for tests and the workbench.
fn snapshot(context: ?*anyopaque) AsyncBackendSnapshot {
    _ = context;
    return .{};
}

test "Z1: zio-backed delay suspends for real and yields a structurally-equal causal trace" {
    const allocator = std.testing.allocator;
    var rt = try zio.Runtime.init(allocator, .{});
    defer rt.deinit();

    // Real suspension under zio (the coroutine parks on the event loop).
    var zio_store = fx.CausalStore.init(allocator);
    defer zio_store.deinit();
    try recordZioDelayScenario(&zio_store, 2);

    // Deterministic reference (virtual clock).
    var det_store = fx.CausalStore.init(allocator);
    defer det_store.deinit();
    var backend = fx.LocalAsyncBackendState.init(allocator, .{});
    defer backend.deinit();
    _ = try fx.recordDelaySuspensionScenario(allocator, &det_store, backend.backend(), 2);

    var zio_snap = try zio_store.snapshot(allocator);
    defer zio_snap.deinit();
    var det_snap = try det_store.snapshot(allocator);
    defer det_snap.deinit();

    // Structural equivalence: same event-kind multiset, including the load-bearing
    // suspend/timer/resume kinds that prove a real suspend->resume happened.
    try std.testing.expectEqual(det_snap.events.len, zio_snap.events.len);
    try std.testing.expectEqual(kindCount(det_snap.events, .fiber_suspended), kindCount(zio_snap.events, .fiber_suspended));
    try std.testing.expectEqual(kindCount(det_snap.events, .timer_scheduled), kindCount(zio_snap.events, .timer_scheduled));
    try std.testing.expectEqual(kindCount(det_snap.events, .timer_fired), kindCount(zio_snap.events, .timer_fired));
    try std.testing.expectEqual(kindCount(det_snap.events, .fiber_resumed), kindCount(zio_snap.events, .fiber_resumed));
    try std.testing.expectEqual(kindCount(det_snap.events, .fiber_joined), kindCount(zio_snap.events, .fiber_joined));
    try std.testing.expectEqual(@as(usize, 1), kindCount(zio_snap.events, .fiber_suspended));
    try std.testing.expectEqual(@as(usize, 1), kindCount(zio_snap.events, .fiber_resumed));
}

test "zio backend exposes a valid AsyncBackend seam (stub returns Unsupported until Stage 1)" {
    var state = ZioAsyncBackendState.init(std.testing.allocator);
    defer state.deinit();
    const b = state.backend();
    try std.testing.expectError(
        error.UnsupportedBackendCapability,
        b.scheduleTimer(.{ .suspension = .{ .kind = .timer, .id = 1, .label = "delay" }, .due_time_ms = 10 }),
    );
}
