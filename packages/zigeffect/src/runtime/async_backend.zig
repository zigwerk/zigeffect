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
        return .{
            .context = self,
            .capabilities = self.capabilities,
            .vtable = &unsupported_vtable,
        };
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
