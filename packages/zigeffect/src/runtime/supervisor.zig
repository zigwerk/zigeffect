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
