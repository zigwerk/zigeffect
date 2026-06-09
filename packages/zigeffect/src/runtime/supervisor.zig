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

const ChildState = struct {
    spec: SupervisorChildSpec,
    status: SupervisorChildStatus = .idle,
    restart_count: usize = 0,
    registration_index: usize = 0,

    fn snapshot(self: ChildState) SupervisorChildSnapshot {
        return .{
            .spec = self.spec,
            .status = self.status,
            .restart_count = self.restart_count,
        };
    }
};

pub const Supervisor = struct {
    allocator: Allocator,
    options: SupervisorOptions,
    children: std.ArrayList(ChildState) = .empty,
    restart_history: std.ArrayList(u64) = .empty,

    pub fn init(allocator: Allocator, options: SupervisorOptions) Supervisor {
        return .{ .allocator = allocator, .options = options };
    }

    pub fn deinit(self: *Supervisor) void {
        self.children.deinit(self.allocator);
        self.restart_history.deinit(self.allocator);
    }

    pub fn addChild(self: *Supervisor, spec: SupervisorChildSpec) (Allocator.Error || SupervisorError)!void {
        if (self.findChildIndex(spec.id) != null) return error.DuplicateChild;
        try self.children.append(self.allocator, .{
            .spec = spec,
            .registration_index = self.children.items.len,
        });
    }

    pub fn startAll(self: *Supervisor, now_ms: u64) Allocator.Error!void {
        _ = now_ms;
        for (self.children.items) |*child| {
            child.status = .running;
        }
    }

    pub fn childStatus(self: *const Supervisor, child_id: SupervisorChildId) SupervisorError!SupervisorChildStatus {
        const index = self.findChildIndex(child_id) orelse return error.ChildNotFound;
        return self.children.items[index].status;
    }

    pub fn childRestartCount(self: *const Supervisor, child_id: SupervisorChildId) SupervisorError!usize {
        const index = self.findChildIndex(child_id) orelse return error.ChildNotFound;
        return self.children.items[index].restart_count;
    }

    pub fn shutdownPlan(self: *Supervisor, allocator: Allocator) Allocator.Error!SupervisorShutdownPlan {
        const ordered = try allocator.alloc(ChildState, self.children.items.len);
        defer allocator.free(ordered);
        @memcpy(ordered, self.children.items);
        std.mem.sort(ChildState, ordered, {}, shutdownBefore);

        const snapshots = try allocator.alloc(SupervisorChildSnapshot, ordered.len);
        errdefer allocator.free(snapshots);
        for (ordered, 0..) |child, index| {
            snapshots[index] = child.snapshot();
        }
        return .{
            .allocator = allocator,
            .children = snapshots,
        };
    }

    pub fn reportChildExit(
        self: *Supervisor,
        child_id: SupervisorChildId,
        exit: SupervisorChildExit,
        now_ms: u64,
    ) (Allocator.Error || SupervisorError)!SupervisorDecision {
        const failed_index = self.findChildIndex(child_id) orelse return error.ChildNotFound;
        var decision = SupervisorDecision{
            .supervisor_id = self.options.id,
            .child_id = child_id,
            .strategy = self.options.strategy,
            .exit = exit,
        };

        if (!restartAllowed(self.children.items[failed_index].spec.restart_mode, exit)) {
            markStoppedOrFailed(&self.children.items[failed_index], exit);
            decision.stopped_children = 1;
            return decision;
        }

        const planned_restarts = self.countRestartableAffected(failed_index, exit);
        if (planned_restarts > 0 and !self.canRestartWithinIntensity(now_ms, planned_restarts)) {
            decision.escalated = true;
            decision.stopped_children = self.markAffectedEscalated(failed_index);
            return decision;
        }

        for (self.children.items, 0..) |*child, candidate_index| {
            if (!strategyAffects(self.options.strategy, failed_index, candidate_index)) continue;

            if (restartAllowed(child.spec.restart_mode, exit)) {
                child.status = .running;
                child.restart_count += 1;
                try self.recordRestart(now_ms);
                decision.restarted_children += 1;
            } else {
                markStoppedOrFailed(child, exit);
                decision.stopped_children += 1;
            }
        }

        return decision;
    }

    fn countRestartableAffected(self: *const Supervisor, failed_index: usize, exit: SupervisorChildExit) usize {
        var count: usize = 0;
        for (self.children.items, 0..) |child, candidate_index| {
            if (!strategyAffects(self.options.strategy, failed_index, candidate_index)) continue;
            if (restartAllowed(child.spec.restart_mode, exit)) count += 1;
        }
        return count;
    }

    fn pruneRestartHistory(self: *Supervisor, now_ms: u64) void {
        const window_start = now_ms -| self.options.intensity.within_ms;
        while (self.restart_history.items.len > 0 and self.restart_history.items[0] < window_start) {
            _ = self.restart_history.orderedRemove(0);
        }
    }

    fn canRestartWithinIntensity(self: *Supervisor, now_ms: u64, planned_restarts: usize) bool {
        self.pruneRestartHistory(now_ms);
        return self.restart_history.items.len + planned_restarts <= self.options.intensity.max_restarts;
    }

    fn recordRestart(self: *Supervisor, now_ms: u64) Allocator.Error!void {
        try self.restart_history.append(self.allocator, now_ms);
    }

    fn markAffectedEscalated(self: *Supervisor, failed_index: usize) usize {
        var count: usize = 0;
        for (self.children.items, 0..) |*child, candidate_index| {
            if (!strategyAffects(self.options.strategy, failed_index, candidate_index)) continue;
            child.status = .escalated;
            count += 1;
        }
        return count;
    }

    fn findChildIndex(self: *const Supervisor, child_id: SupervisorChildId) ?usize {
        for (self.children.items, 0..) |child, index| {
            if (child.spec.id == child_id) return index;
        }
        return null;
    }
};

fn shutdownBefore(_: void, left: ChildState, right: ChildState) bool {
    if (left.spec.shutdown_order != right.spec.shutdown_order) {
        return left.spec.shutdown_order > right.spec.shutdown_order;
    }
    return left.registration_index > right.registration_index;
}

fn exitIsSuccess(exit: SupervisorChildExit) bool {
    return switch (exit) {
        .success => true,
        .failure, .defect, .interrupted => false,
    };
}

fn restartAllowed(mode: SupervisorRestartMode, exit: SupervisorChildExit) bool {
    return switch (mode) {
        .permanent => true,
        .transient => !exitIsSuccess(exit),
        .temporary => false,
    };
}

fn strategyAffects(strategy: SupervisorStrategy, failed_index: usize, candidate_index: usize) bool {
    return switch (strategy) {
        .one_for_one => candidate_index == failed_index,
        .one_for_all => true,
        .rest_for_one => candidate_index >= failed_index,
    };
}

fn markStoppedOrFailed(child: *ChildState, exit: SupervisorChildExit) void {
    child.status = switch (exit) {
        .success, .interrupted => .stopped,
        .failure, .defect => .failed,
    };
}
