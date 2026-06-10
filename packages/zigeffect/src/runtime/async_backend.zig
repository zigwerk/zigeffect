const std = @import("std");
const scope_mod = @import("../core/scope.zig");
const backend_mod = @import("backend.zig");
const control = @import("control.zig");

pub const Allocator = std.mem.Allocator;
pub const Scope = scope_mod.Scope;
pub const ScopeError = scope_mod.ScopeError;
pub const FinalizerExit = scope_mod.FinalizerExit;
pub const BackendCapabilities = backend_mod.BackendCapabilities;
pub const asyncLocalBackend = backend_mod.asyncLocalBackend;
pub const Suspension = control.Suspension;

pub const AsyncBackendError = error{
    UnsupportedBackendCapability,
    UnknownSuspension,
    InvalidIoWaitKind,
    OutOfMemory,
};

pub const AsyncWaitKind = enum {
    runtime,
    timer,
    network,
    file,
    cancellation,
};

pub const AsyncWaitStatus = enum {
    pending,
    ready,
    interrupted,
};

pub const AsyncIoWaitKind = enum {
    network,
    file,
};

pub const AsyncIoInterest = enum {
    readable,
    writable,
    completion,
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
    workflow_id: ?u64 = null,
    execution_id: ?u64 = null,
};

pub const BackendInterruptRequest = struct {
    target_id: u64,
    reason: []const u8 = "",
};

pub const BackendIoWaitRequest = struct {
    suspension: Suspension,
    io_kind: AsyncIoWaitKind,
    interest: AsyncIoInterest,
    descriptor: ?i64 = null,
    workflow_id: ?u64 = null,
    execution_id: ?u64 = null,
    reason: []const u8 = "",
};

pub const BackendIoCompleteRequest = struct {
    suspension_id: u64,
    io_kind: AsyncIoWaitKind,
    reason: []const u8 = "",
};

pub const BackendWakeEvent = struct {
    suspension: Suspension,
    wait_kind: AsyncWaitKind,
    status: AsyncWaitStatus,
    reason: []const u8 = "",
    workflow_id: ?u64 = null,
    execution_id: ?u64 = null,
    due_time_ms: ?u64 = null,
    io_kind: ?AsyncIoWaitKind = null,
    interest: ?AsyncIoInterest = null,
    descriptor: ?i64 = null,
};

pub const AsyncBackendSnapshot = struct {
    pending_count: usize = 0,
    ready_count: usize = 0,
    completed_count: usize = 0,
    interrupted_count: usize = 0,
    duplicate_suspend_count: usize = 0,
    duplicate_wake_count: usize = 0,
    interrupt_count: usize = 0,
    next_due_time_ms: ?u64 = null,
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
        register_io_wait: *const fn (?*anyopaque, BackendIoWaitRequest) AsyncBackendError!void,
        complete_io: *const fn (?*anyopaque, BackendIoCompleteRequest) AsyncBackendError!void,
        poll_wake: *const fn (?*anyopaque) AsyncBackendError!?BackendWakeEvent,
        advance_time: *const fn (?*anyopaque, u64) AsyncBackendError!usize,
        snapshot: *const fn (?*anyopaque) AsyncBackendSnapshot,
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

    pub fn registerIoWait(self: AsyncBackend, request: BackendIoWaitRequest) AsyncBackendError!void {
        return self.vtable.register_io_wait(self.context, request);
    }

    pub fn completeIo(self: AsyncBackend, request: BackendIoCompleteRequest) AsyncBackendError!void {
        return self.vtable.complete_io(self.context, request);
    }

    pub fn pollWake(self: AsyncBackend) AsyncBackendError!?BackendWakeEvent {
        return self.vtable.poll_wake(self.context);
    }

    pub fn advanceTime(self: AsyncBackend, now_ms: u64) AsyncBackendError!usize {
        return self.vtable.advance_time(self.context, now_ms);
    }

    pub fn snapshot(self: AsyncBackend) AsyncBackendSnapshot {
        return self.vtable.snapshot(self.context);
    }
};

pub const UnsupportedAsyncBackendState = struct {
    capabilities: BackendCapabilities,

    pub fn init(capabilities: BackendCapabilities) UnsupportedAsyncBackendState {
        return .{ .capabilities = capabilities };
    }

    pub fn backend(self: *UnsupportedAsyncBackendState) AsyncBackend {
        return .{
            .context = self,
            .capabilities = self.capabilities,
            .vtable = &unsupported_vtable,
        };
    }
};

pub const LocalAsyncBackendOptions = struct {
    now_ms: u64 = 0,
};

const LocalAsyncWait = struct {
    suspension: Suspension,
    wait_kind: AsyncWaitKind,
    status: AsyncWaitStatus = .pending,
    reason: []const u8 = "",
    workflow_id: ?u64 = null,
    execution_id: ?u64 = null,
    due_time_ms: ?u64 = null,
    io_kind: ?AsyncIoWaitKind = null,
    interest: ?AsyncIoInterest = null,
    descriptor: ?i64 = null,

    fn deinit(self: *LocalAsyncWait, allocator: Allocator) void {
        if (self.suspension.label.len != 0) allocator.free(self.suspension.label);
        if (self.reason.len != 0) allocator.free(self.reason);
    }
};

pub const LocalAsyncBackendState = struct {
    allocator: Allocator,
    capabilities: BackendCapabilities,
    now_ms: u64,
    waits: std.ArrayList(LocalAsyncWait) = .empty,
    ready_indexes: std.ArrayList(usize) = .empty,
    duplicate_suspend_count: usize = 0,
    duplicate_wake_count: usize = 0,
    interrupt_count: usize = 0,

    pub fn init(allocator: Allocator, options: LocalAsyncBackendOptions) LocalAsyncBackendState {
        return .{
            .allocator = allocator,
            .capabilities = asyncLocalBackend(),
            .now_ms = options.now_ms,
        };
    }

    pub fn deinit(self: *LocalAsyncBackendState) void {
        for (self.waits.items) |*wait| wait.deinit(self.allocator);
        self.ready_indexes.deinit(self.allocator);
        self.waits.deinit(self.allocator);
    }

    pub fn backend(self: *LocalAsyncBackendState) AsyncBackend {
        return .{
            .context = self,
            .capabilities = self.capabilities,
            .vtable = &local_vtable,
        };
    }

    pub fn advanceTo(self: *LocalAsyncBackendState, now_ms: u64) AsyncBackendError!usize {
        if (now_ms > self.now_ms) self.now_ms = now_ms;
        var released: usize = 0;
        for (self.waits.items, 0..) |wait, index| {
            if (wait.status != .pending or wait.wait_kind != .timer) continue;
            const due_time_ms = wait.due_time_ms orelse continue;
            if (due_time_ms > self.now_ms) continue;
            try self.markReady(index, .ready, "timer due");
            released += 1;
        }
        return released;
    }

    fn suspendRuntime(self: *LocalAsyncBackendState, request: BackendSuspendRequest) AsyncBackendError!void {
        return self.registerWait(.{
            .suspension = request.suspension,
            .wait_kind = .runtime,
            .reason = request.reason,
            .workflow_id = request.workflow_id,
            .execution_id = request.execution_id,
        });
    }

    fn scheduleTimer(self: *LocalAsyncBackendState, request: BackendTimerRequest) AsyncBackendError!void {
        if (request.now_ms > self.now_ms) self.now_ms = request.now_ms;
        try self.registerWait(.{
            .suspension = request.suspension,
            .wait_kind = .timer,
            .reason = "timer scheduled",
            .workflow_id = request.workflow_id,
            .execution_id = request.execution_id,
            .due_time_ms = request.due_time_ms,
        });
        if (request.due_time_ms <= self.now_ms) {
            const index = self.findWaitIndex(request.suspension.id) orelse return error.UnknownSuspension;
            try self.markReady(index, .ready, "timer due");
        }
    }

    fn registerIoWait(self: *LocalAsyncBackendState, request: BackendIoWaitRequest) AsyncBackendError!void {
        try self.registerWait(.{
            .suspension = request.suspension,
            .wait_kind = waitKindFromIo(request.io_kind),
            .reason = request.reason,
            .workflow_id = request.workflow_id,
            .execution_id = request.execution_id,
            .io_kind = request.io_kind,
            .interest = request.interest,
            .descriptor = request.descriptor,
        });
    }

    fn completeIo(self: *LocalAsyncBackendState, request: BackendIoCompleteRequest) AsyncBackendError!void {
        const index = self.findWaitIndex(request.suspension_id) orelse return error.UnknownSuspension;
        const wait = &self.waits.items[index];
        if (wait.io_kind == null or wait.io_kind.? != request.io_kind) return error.InvalidIoWaitKind;
        try self.markReady(index, .ready, request.reason);
    }

    fn wake(self: *LocalAsyncBackendState, request: BackendWakeRequest) AsyncBackendError!void {
        const index = self.findWaitIndex(request.suspension_id) orelse return error.UnknownSuspension;
        try self.markReady(index, .ready, request.reason);
    }

    fn interrupt(self: *LocalAsyncBackendState, request: BackendInterruptRequest) AsyncBackendError!void {
        const index = self.findWaitIndex(request.target_id) orelse return error.UnknownSuspension;
        const wait = &self.waits.items[index];
        if (wait.status != .pending) {
            self.duplicate_wake_count += 1;
            return;
        }
        self.interrupt_count += 1;
        try self.markReady(index, .interrupted, request.reason);
    }

    fn pollWake(self: *LocalAsyncBackendState) AsyncBackendError!?BackendWakeEvent {
        if (self.ready_indexes.items.len == 0) return null;
        const index = self.ready_indexes.orderedRemove(0);
        return self.eventFromWait(self.waits.items[index]);
    }

    fn snapshot(self: *const LocalAsyncBackendState) AsyncBackendSnapshot {
        var output = AsyncBackendSnapshot{
            .ready_count = self.ready_indexes.items.len,
            .duplicate_suspend_count = self.duplicate_suspend_count,
            .duplicate_wake_count = self.duplicate_wake_count,
            .interrupt_count = self.interrupt_count,
        };
        for (self.waits.items) |wait| {
            switch (wait.status) {
                .pending => {
                    output.pending_count += 1;
                    if (wait.wait_kind == .timer) {
                        if (wait.due_time_ms) |due| {
                            if (output.next_due_time_ms == null or due < output.next_due_time_ms.?) {
                                output.next_due_time_ms = due;
                            }
                        }
                    }
                },
                .ready => output.completed_count += 1,
                .interrupted => {
                    output.completed_count += 1;
                    output.interrupted_count += 1;
                },
            }
        }
        return output;
    }

    fn registerWait(self: *LocalAsyncBackendState, wait: LocalAsyncWait) AsyncBackendError!void {
        if (self.findWaitIndex(wait.suspension.id)) |_| {
            self.duplicate_suspend_count += 1;
            return;
        }

        var owned = wait;
        owned.suspension.label = cloneOrEmpty(self.allocator, wait.suspension.label) catch return error.OutOfMemory;
        errdefer if (owned.suspension.label.len != 0) self.allocator.free(owned.suspension.label);
        owned.reason = cloneOrEmpty(self.allocator, wait.reason) catch return error.OutOfMemory;
        errdefer if (owned.reason.len != 0) self.allocator.free(owned.reason);
        self.waits.append(self.allocator, owned) catch return error.OutOfMemory;
    }

    fn markReady(
        self: *LocalAsyncBackendState,
        index: usize,
        status: AsyncWaitStatus,
        reason: []const u8,
    ) AsyncBackendError!void {
        const wait = &self.waits.items[index];
        if (wait.status != .pending) {
            self.duplicate_wake_count += 1;
            return;
        }
        if (wait.reason.len != 0) self.allocator.free(wait.reason);
        wait.reason = cloneOrEmpty(self.allocator, reason) catch return error.OutOfMemory;
        wait.status = status;
        self.ready_indexes.append(self.allocator, index) catch return error.OutOfMemory;
    }

    fn findWaitIndex(self: *const LocalAsyncBackendState, suspension_id: u64) ?usize {
        for (self.waits.items, 0..) |wait, index| {
            if (wait.suspension.id == suspension_id) return index;
        }
        return null;
    }

    fn eventFromWait(self: *const LocalAsyncBackendState, wait: LocalAsyncWait) BackendWakeEvent {
        _ = self;
        return .{
            .suspension = wait.suspension,
            .wait_kind = wait.wait_kind,
            .status = wait.status,
            .reason = wait.reason,
            .workflow_id = wait.workflow_id,
            .execution_id = wait.execution_id,
            .due_time_ms = wait.due_time_ms,
            .io_kind = wait.io_kind,
            .interest = wait.interest,
            .descriptor = wait.descriptor,
        };
    }
};

pub fn attachAsyncInterruptFinalizer(
    scope: *Scope,
    backend: AsyncBackend,
    suspension_id: u64,
    reason: []const u8,
) (Allocator.Error || ScopeError)!void {
    if (scope.closed) return error.MissingScope;
    const State = struct {
        allocator: Allocator,
        backend: AsyncBackend,
        suspension_id: u64,
        reason: []const u8,
    };
    const Runner = struct {
        fn run(raw: ?*anyopaque, exit: FinalizerExit) AsyncBackendError!void {
            _ = exit;
            const state: *State = @ptrCast(@alignCast(raw.?));
            defer {
                if (state.reason.len != 0) state.allocator.free(state.reason);
                state.allocator.destroy(state);
            }
            try state.backend.interrupt(.{
                .target_id = state.suspension_id,
                .reason = state.reason,
            });
        }
    };

    const state = try scope.allocator.create(State);
    errdefer scope.allocator.destroy(state);
    state.* = .{
        .allocator = scope.allocator,
        .backend = backend,
        .suspension_id = suspension_id,
        .reason = try cloneOrEmpty(scope.allocator, reason),
    };
    errdefer {
        if (state.reason.len != 0) scope.allocator.free(state.reason);
    }
    try scope.addFinalizerExitFallible(state, Runner.run);
}

fn waitKindFromIo(kind: AsyncIoWaitKind) AsyncWaitKind {
    return switch (kind) {
        .network => .network,
        .file => .file,
    };
}

fn cloneOrEmpty(allocator: Allocator, value: []const u8) Allocator.Error![]const u8 {
    if (value.len == 0) return "";
    return allocator.dupe(u8, value);
}

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

fn unsupportedRegisterIoWait(context: ?*anyopaque, request: BackendIoWaitRequest) AsyncBackendError!void {
    _ = context;
    _ = request;
    return error.UnsupportedBackendCapability;
}

fn unsupportedCompleteIo(context: ?*anyopaque, request: BackendIoCompleteRequest) AsyncBackendError!void {
    _ = context;
    _ = request;
    return error.UnsupportedBackendCapability;
}

fn unsupportedPollWake(context: ?*anyopaque) AsyncBackendError!?BackendWakeEvent {
    _ = context;
    return error.UnsupportedBackendCapability;
}

fn unsupportedAdvanceTime(context: ?*anyopaque, now_ms: u64) AsyncBackendError!usize {
    _ = context;
    _ = now_ms;
    return error.UnsupportedBackendCapability;
}

fn unsupportedSnapshot(context: ?*anyopaque) AsyncBackendSnapshot {
    _ = context;
    return .{};
}

fn localSuspend(context: ?*anyopaque, request: BackendSuspendRequest) AsyncBackendError!void {
    const state: *LocalAsyncBackendState = @ptrCast(@alignCast(context.?));
    return state.suspendRuntime(request);
}

fn localWake(context: ?*anyopaque, request: BackendWakeRequest) AsyncBackendError!void {
    const state: *LocalAsyncBackendState = @ptrCast(@alignCast(context.?));
    return state.wake(request);
}

fn localScheduleTimer(context: ?*anyopaque, request: BackendTimerRequest) AsyncBackendError!void {
    const state: *LocalAsyncBackendState = @ptrCast(@alignCast(context.?));
    return state.scheduleTimer(request);
}

fn localInterrupt(context: ?*anyopaque, request: BackendInterruptRequest) AsyncBackendError!void {
    const state: *LocalAsyncBackendState = @ptrCast(@alignCast(context.?));
    return state.interrupt(request);
}

fn localRegisterIoWait(context: ?*anyopaque, request: BackendIoWaitRequest) AsyncBackendError!void {
    const state: *LocalAsyncBackendState = @ptrCast(@alignCast(context.?));
    return state.registerIoWait(request);
}

fn localCompleteIo(context: ?*anyopaque, request: BackendIoCompleteRequest) AsyncBackendError!void {
    const state: *LocalAsyncBackendState = @ptrCast(@alignCast(context.?));
    return state.completeIo(request);
}

fn localPollWake(context: ?*anyopaque) AsyncBackendError!?BackendWakeEvent {
    const state: *LocalAsyncBackendState = @ptrCast(@alignCast(context.?));
    return state.pollWake();
}

fn localAdvanceTime(context: ?*anyopaque, now_ms: u64) AsyncBackendError!usize {
    const state: *LocalAsyncBackendState = @ptrCast(@alignCast(context.?));
    return state.advanceTo(now_ms);
}

fn localSnapshot(context: ?*anyopaque) AsyncBackendSnapshot {
    const state: *LocalAsyncBackendState = @ptrCast(@alignCast(context.?));
    return state.snapshot();
}

const unsupported_vtable: AsyncBackend.VTable = .{
    .suspend_runtime = unsupportedSuspend,
    .wake = unsupportedWake,
    .schedule_timer = unsupportedScheduleTimer,
    .interrupt = unsupportedInterrupt,
    .register_io_wait = unsupportedRegisterIoWait,
    .complete_io = unsupportedCompleteIo,
    .poll_wake = unsupportedPollWake,
    .advance_time = unsupportedAdvanceTime,
    .snapshot = unsupportedSnapshot,
};

const local_vtable: AsyncBackend.VTable = .{
    .suspend_runtime = localSuspend,
    .wake = localWake,
    .schedule_timer = localScheduleTimer,
    .interrupt = localInterrupt,
    .register_io_wait = localRegisterIoWait,
    .complete_io = localCompleteIo,
    .poll_wake = localPollWake,
    .advance_time = localAdvanceTime,
    .snapshot = localSnapshot,
};
