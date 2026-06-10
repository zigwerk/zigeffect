const std = @import("std");
const routing = @import("routing.zig");

pub const Allocator = std.mem.Allocator;
pub const ShardId = routing.ShardId;

pub const ClusterSupervisionPolicy = struct {
    release_shard_on_escalation: bool = true,
    workflow_entity_type_name: []const u8 = "workflow.execution",
};

pub const ClusterRunnerRestartPolicy = struct {
    max_restarts: usize = 3,
    within_ms: u64 = 60_000,
};

pub const ClusterRunnerRestartDecision = struct {
    restart_allowed: bool = false,
    escalated: bool = false,
    restart_count: usize = 0,
};

pub const ClusterRunnerRestartState = struct {
    allocator: Allocator,
    policy: ClusterRunnerRestartPolicy,
    failures: std.ArrayList(u64) = .empty,

    pub fn init(allocator: Allocator, policy: ClusterRunnerRestartPolicy) ClusterRunnerRestartState {
        return .{ .allocator = allocator, .policy = policy };
    }

    pub fn deinit(self: *ClusterRunnerRestartState) void {
        self.failures.deinit(self.allocator);
    }

    pub fn recordFailure(self: *ClusterRunnerRestartState, now_ms: u64) Allocator.Error!ClusterRunnerRestartDecision {
        self.prune(now_ms);
        if (self.failures.items.len >= self.policy.max_restarts) {
            return .{
                .restart_allowed = false,
                .escalated = true,
                .restart_count = self.failures.items.len,
            };
        }
        try self.failures.append(self.allocator, now_ms);
        return .{
            .restart_allowed = true,
            .restart_count = self.failures.items.len,
        };
    }

    fn prune(self: *ClusterRunnerRestartState, now_ms: u64) void {
        const window_start = now_ms -| self.policy.within_ms;
        while (self.failures.items.len > 0 and self.failures.items[0] < window_start) {
            _ = self.failures.orderedRemove(0);
        }
    }
};

pub const ClusterSupervisionReport = struct {
    scanned: usize = 0,
    claimed: usize = 0,
    dispatched: usize = 0,
    replied: usize = 0,
    acked: usize = 0,
    failed: usize = 0,
    skipped: usize = 0,
    entity_failures: usize = 0,
    entity_restarts: usize = 0,
    entity_escalations: usize = 0,
    workflow_worker_failures: usize = 0,
    workflow_worker_restarts: usize = 0,
    shard_releases: usize = 0,
    runner_restarts: usize = 0,
    runner_escalations: usize = 0,

    pub fn add(self: *ClusterSupervisionReport, other: ClusterSupervisionReport) void {
        self.scanned += other.scanned;
        self.claimed += other.claimed;
        self.dispatched += other.dispatched;
        self.replied += other.replied;
        self.acked += other.acked;
        self.failed += other.failed;
        self.skipped += other.skipped;
        self.entity_failures += other.entity_failures;
        self.entity_restarts += other.entity_restarts;
        self.entity_escalations += other.entity_escalations;
        self.workflow_worker_failures += other.workflow_worker_failures;
        self.workflow_worker_restarts += other.workflow_worker_restarts;
        self.shard_releases += other.shard_releases;
        self.runner_restarts += other.runner_restarts;
        self.runner_escalations += other.runner_escalations;
    }
};
