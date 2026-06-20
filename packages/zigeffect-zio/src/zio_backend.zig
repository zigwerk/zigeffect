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

test "zio backend exposes a valid AsyncBackend seam (stub returns Unsupported until Stage 1)" {
    var state = ZioAsyncBackendState.init(std.testing.allocator);
    defer state.deinit();
    const b = state.backend();
    try std.testing.expectError(
        error.UnsupportedBackendCapability,
        b.scheduleTimer(.{ .suspension = .{ .kind = .timer, .id = 1, .label = "delay" }, .due_time_ms = 10 }),
    );
}
