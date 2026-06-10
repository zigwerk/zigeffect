const std = @import("std");
const message_storage = @import("message_storage.zig");
const observability = @import("observability.zig");
const routing = @import("routing.zig");
const runner = @import("runner.zig");
const runner_storage = @import("runner_storage.zig");

pub const Allocator = std.mem.Allocator;
pub const MessageStorage = message_storage.MessageStorage;
pub const ClusterMetricsSnapshot = observability.ClusterMetricsSnapshot;
pub const ShardCount = routing.ShardCount;
pub const ShardId = routing.ShardId;
pub const LocalRunnerHealthInspector = runner.LocalRunnerHealthInspector;
pub const LocalRunnerRegistry = runner.LocalRunnerRegistry;
pub const RunnerAddress = runner.RunnerAddress;
pub const RunnerHealthInspectorOptions = runner.RunnerHealthInspectorOptions;
pub const RunnerLeaseBatch = runner_storage.RunnerLeaseBatch;
pub const RunnerLeaseTtlMs = runner_storage.RunnerLeaseTtlMs;
pub const RunnerStorage = runner_storage.RunnerStorage;
pub const ShardLeaseEpoch = runner_storage.ShardLeaseEpoch;

pub const cluster_inspection_schema = "zigeffect.cluster.inspection.v1";
pub const cluster_inspection_schema_version: u32 = 1;

pub const RealClusterError = error{
    InvalidShardCount,
    InvalidLeaseTtl,
    NoActiveClusterMembers,
    RunnerStillAlive,
};

pub const ClusterMembershipState = enum {
    joining,
    active,
    draining,
    leaving,
    down,
    rejected,
};

pub const ClusterAdmissionDecision = enum {
    admitted,
    already_member,
    rejected,
};

pub const ClusterMember = struct {
    address: RunnerAddress,
    name: []const u8,
    state: ClusterMembershipState,
    started_at_ms: u64,
    last_seen_at_ms: ?u64 = null,
};

pub const ClusterMembershipReport = struct {
    allocator: Allocator,
    generated_at_ms: u64,
    members: []ClusterMember,
    active: usize = 0,
    draining: usize = 0,
    down: usize = 0,

    pub fn deinit(self: *ClusterMembershipReport) void {
        for (self.members) |member| {
            if (member.name.len > 0) self.allocator.free(member.name);
        }
        self.allocator.free(self.members);
    }
};

pub const ClusterPlacementStrategy = enum {
    balanced,
};

pub const ClusterShardPlacement = struct {
    shard_id: ShardId,
    owner: RunnerAddress,
};

pub const ClusterPlacementPlan = struct {
    allocator: Allocator,
    strategy: ClusterPlacementStrategy,
    placements: []ClusterShardPlacement,

    pub fn deinit(self: *ClusterPlacementPlan) void {
        self.allocator.free(self.placements);
    }
};

pub const ClusterRebalanceActionKind = enum {
    acquire,
    release,
    handoff,
};

pub const ClusterRebalanceAction = struct {
    kind: ClusterRebalanceActionKind,
    shard_id: ShardId,
    from: ?RunnerAddress = null,
    to: ?RunnerAddress = null,
};

pub const ClusterRebalancePlan = struct {
    allocator: Allocator,
    actions: []ClusterRebalanceAction,
    current_placements: usize = 0,
    desired_placements: usize = 0,

    pub fn deinit(self: *ClusterRebalancePlan) void {
        self.allocator.free(self.actions);
    }
};

pub const ClusterDrainPlan = struct {
    runner: RunnerAddress,
    released: usize,
    reassigned: usize,
};

pub const ClusterNodeDownRecoveryPlan = struct {
    dead_runner: RunnerAddress,
    recovered_by: RunnerAddress,
    released: usize,
    reassigned: usize,
};

pub const ClusterSplitBrainFindingKind = enum {
    missing_storage_lease,
    owner_mismatch,
    epoch_mismatch,
};

pub const ClusterSplitBrainFinding = struct {
    kind: ClusterSplitBrainFindingKind,
    shard_id: ShardId,
    local_owner: RunnerAddress,
    storage_owner: ?RunnerAddress = null,
    local_epoch: ShardLeaseEpoch,
    storage_epoch: ?ShardLeaseEpoch = null,
};

pub const ClusterSplitBrainReport = struct {
    allocator: Allocator,
    findings: []ClusterSplitBrainFinding,

    pub fn deinit(self: *ClusterSplitBrainReport) void {
        self.allocator.free(self.findings);
    }
};

pub const ClusterInspectionReport = struct {
    allocator: Allocator,
    generated_at_ms: u64,
    members: ClusterMembershipReport,
    leases: RunnerLeaseBatch,
    metrics: ClusterMetricsSnapshot,
    recent_rebalance_actions: usize = 0,
    recent_failures: usize = 0,

    pub fn deinit(self: *ClusterInspectionReport) void {
        self.members.deinit();
        self.leases.deinit();
    }
};

pub const RealClusterControllerOptions = struct {
    shard_count: ShardCount,
    lease_ttl_ms: RunnerLeaseTtlMs,
    placement_strategy: ClusterPlacementStrategy = .balanced,
    health_options: RunnerHealthInspectorOptions = .{},
};

pub const RealClusterControllerInit = struct {
    runner_storage: RunnerStorage,
    message_storage: MessageStorage,
    registry: *LocalRunnerRegistry,
    options: RealClusterControllerOptions,
};

pub const RealClusterController = struct {
    allocator: Allocator,
    runner_storage: RunnerStorage,
    message_storage: MessageStorage,
    registry: *LocalRunnerRegistry,
    inspector: LocalRunnerHealthInspector,
    options: RealClusterControllerOptions,
    recent_rebalance_actions: usize = 0,
    recent_failures: usize = 0,

    pub fn init(allocator: Allocator, init_options: RealClusterControllerInit) (RealClusterError || runner.RunnerRegistryError)!RealClusterController {
        if (init_options.options.shard_count == 0) return error.InvalidShardCount;
        if (init_options.options.lease_ttl_ms == 0) return error.InvalidLeaseTtl;
        return .{
            .allocator = allocator,
            .runner_storage = init_options.runner_storage,
            .message_storage = init_options.message_storage,
            .registry = init_options.registry,
            .inspector = try LocalRunnerHealthInspector.init(init_options.options.health_options),
            .options = init_options.options,
        };
    }

    pub fn admitRunner(self: *RealClusterController, registration: runner.RunnerRegistration) (Allocator.Error || runner.RunnerRegistryError)!ClusterAdmissionDecision {
        _ = self.registry.registerRunner(registration) catch |err| switch (err) {
            error.DuplicateRunner => return .already_member,
            else => return err,
        };
        return .admitted;
    }

    pub fn recordHeartbeat(self: *RealClusterController, heartbeat: runner.RunnerHeartbeat) (Allocator.Error || runner.RunnerRegistryError)!runner.RunnerHealthSnapshot {
        return self.registry.recordHeartbeat(heartbeat);
    }

    pub fn discoverRunners(self: *RealClusterController, allocator: Allocator, now_ms: u64) (Allocator.Error || runner.RunnerRegistryError)!ClusterMembershipReport {
        var health = try self.inspector.inspectAll(allocator, self.registry, now_ms);
        defer health.deinit();

        var members = try allocator.alloc(ClusterMember, health.snapshots.len);
        errdefer allocator.free(members);
        var initialized: usize = 0;
        errdefer {
            for (members[0..initialized]) |member| {
                if (member.name.len > 0) allocator.free(member.name);
            }
        }

        var report = ClusterMembershipReport{
            .allocator = allocator,
            .generated_at_ms = now_ms,
            .members = members,
        };

        for (health.snapshots, 0..) |snapshot, index| {
            const state = clusterMembershipStateFromHealth(snapshot.state);
            members[index] = .{
                .address = snapshot.address,
                .name = try allocator.dupe(u8, snapshot.name),
                .state = state,
                .started_at_ms = snapshot.started_at_ms,
                .last_seen_at_ms = snapshot.last_heartbeat_at_ms,
            };
            initialized += 1;
            switch (state) {
                .active => report.active += 1,
                .draining => report.draining += 1,
                .down => report.down += 1,
                else => {},
            }
        }

        std.mem.sort(ClusterMember, report.members, {}, clusterMemberLessThan);
        return report;
    }

    pub fn placementPlan(self: *RealClusterController, allocator: Allocator, now_ms: u64) !ClusterPlacementPlan {
        var report = try self.discoverRunners(allocator, now_ms);
        defer report.deinit();

        if (report.active == 0) return error.NoActiveClusterMembers;
        const active = try allocator.alloc(RunnerAddress, report.active);
        defer allocator.free(active);

        var active_index: usize = 0;
        for (report.members) |member| {
            if (member.state != .active) continue;
            active[active_index] = member.address;
            active_index += 1;
        }

        const placements = try allocator.alloc(ClusterShardPlacement, self.options.shard_count);
        errdefer allocator.free(placements);
        var shard_id: ShardId = 0;
        while (shard_id < @as(ShardId, self.options.shard_count)) : (shard_id += 1) {
            placements[@intCast(shard_id)] = .{
                .shard_id = shard_id,
                .owner = active[@intCast(shard_id % active.len)],
            };
        }

        return .{
            .allocator = allocator,
            .strategy = self.options.placement_strategy,
            .placements = placements,
        };
    }

    pub fn rebalancePlan(self: *RealClusterController, allocator: Allocator, placement: ClusterPlacementPlan) !ClusterRebalancePlan {
        var leases = try self.runner_storage.leases(allocator);
        defer leases.deinit();

        var actions = std.ArrayList(ClusterRebalanceAction).empty;
        errdefer actions.deinit(allocator);

        for (placement.placements) |desired| {
            const current = try self.runner_storage.lease(desired.shard_id);
            if (current) |lease| {
                if (!lease.owner.eql(desired.owner)) {
                    try actions.append(allocator, .{
                        .kind = .handoff,
                        .shard_id = desired.shard_id,
                        .from = lease.owner,
                        .to = desired.owner,
                    });
                }
            } else {
                try actions.append(allocator, .{
                    .kind = .acquire,
                    .shard_id = desired.shard_id,
                    .to = desired.owner,
                });
            }
        }

        for (leases.leases) |lease| {
            if (lease.shard_id < @as(ShardId, self.options.shard_count)) continue;
            try actions.append(allocator, .{
                .kind = .release,
                .shard_id = lease.shard_id,
                .from = lease.owner,
            });
        }

        return .{
            .allocator = allocator,
            .actions = try actions.toOwnedSlice(allocator),
            .current_placements = leases.leases.len,
            .desired_placements = placement.placements.len,
        };
    }

    pub fn applyRebalancePlan(self: *RealClusterController, plan: ClusterRebalancePlan, now_ms: u64) !usize {
        var applied: usize = 0;
        for (plan.actions) |action| {
            switch (action.kind) {
                .acquire => {
                    const owner = action.to orelse continue;
                    _ = try self.runner_storage.acquire(.{
                        .shard_id = action.shard_id,
                        .owner = owner,
                        .now_ms = now_ms,
                        .ttl_ms = self.options.lease_ttl_ms,
                    });
                    applied += 1;
                },
                .release => {
                    const owner = action.from orelse continue;
                    try self.runner_storage.release(.{
                        .shard_id = action.shard_id,
                        .owner = owner,
                    });
                    applied += 1;
                },
                .handoff => {
                    const from = action.from orelse continue;
                    const to = action.to orelse continue;
                    try self.runner_storage.release(.{
                        .shard_id = action.shard_id,
                        .owner = from,
                    });
                    _ = try self.runner_storage.acquire(.{
                        .shard_id = action.shard_id,
                        .owner = to,
                        .now_ms = now_ms,
                        .ttl_ms = self.options.lease_ttl_ms,
                    });
                    applied += 1;
                },
            }
        }
        self.recent_rebalance_actions += applied;
        return applied;
    }

    pub fn drainRunner(self: *RealClusterController, address: RunnerAddress, now_ms: u64) !ClusterDrainPlan {
        var leases = try self.runner_storage.leases(self.allocator);
        defer leases.deinit();

        var drained_shards = std.ArrayList(ShardId).empty;
        defer drained_shards.deinit(self.allocator);
        for (leases.leases) |lease| {
            if (!lease.owner.eql(address)) continue;
            try drained_shards.append(self.allocator, lease.shard_id);
        }

        try self.registry.markStopped(address, now_ms);
        var placement = try self.placementPlan(self.allocator, now_ms);
        defer placement.deinit();

        var released: usize = 0;
        var reassigned: usize = 0;
        for (drained_shards.items) |shard_id| {
            try self.runner_storage.release(.{
                .shard_id = shard_id,
                .owner = address,
            });
            released += 1;

            const owner = findPlacementOwner(placement, shard_id) orelse continue;
            _ = try self.runner_storage.acquire(.{
                .shard_id = shard_id,
                .owner = owner,
                .now_ms = now_ms,
                .ttl_ms = self.options.lease_ttl_ms,
            });
            reassigned += 1;
        }

        self.recent_rebalance_actions += released + reassigned;
        return .{
            .runner = address,
            .released = released,
            .reassigned = reassigned,
        };
    }

    pub fn recoverNodeDown(self: *RealClusterController, dead_runner: RunnerAddress, recovered_by: RunnerAddress, now_ms: u64) !ClusterNodeDownRecoveryPlan {
        const snapshot = try self.inspector.inspectRunner(self.registry, dead_runner, now_ms);
        switch (snapshot.state) {
            .unhealthy, .stopped => {},
            .starting, .healthy, .degraded => return error.RunnerStillAlive,
        }

        var leases = try self.runner_storage.leases(self.allocator);
        defer leases.deinit();

        var dead_shards = std.ArrayList(ShardId).empty;
        defer dead_shards.deinit(self.allocator);
        for (leases.leases) |lease| {
            if (!lease.owner.eql(dead_runner)) continue;
            try dead_shards.append(self.allocator, lease.shard_id);
        }

        var placement = try self.placementPlan(self.allocator, now_ms);
        defer placement.deinit();

        var released: usize = 0;
        var reassigned: usize = 0;
        for (dead_shards.items) |shard_id| {
            try self.runner_storage.release(.{
                .shard_id = shard_id,
                .owner = dead_runner,
            });
            released += 1;

            const owner = findPlacementOwner(placement, shard_id) orelse continue;
            _ = try self.runner_storage.acquire(.{
                .shard_id = shard_id,
                .owner = owner,
                .now_ms = now_ms,
                .ttl_ms = self.options.lease_ttl_ms,
            });
            reassigned += 1;
        }

        self.recent_rebalance_actions += released + reassigned;
        return .{
            .dead_runner = dead_runner,
            .recovered_by = recovered_by,
            .released = released,
            .reassigned = reassigned,
        };
    }

    pub fn detectSplitBrain(self: *RealClusterController, allocator: Allocator, local_snapshots: []const RunnerLeaseBatch) !ClusterSplitBrainReport {
        var findings = std.ArrayList(ClusterSplitBrainFinding).empty;
        errdefer findings.deinit(allocator);

        for (local_snapshots) |snapshot| {
            for (snapshot.leases) |local| {
                const storage = try self.runner_storage.lease(local.shard_id);
                if (storage) |current| {
                    if (!current.owner.eql(local.owner)) {
                        try findings.append(allocator, .{
                            .kind = .owner_mismatch,
                            .shard_id = local.shard_id,
                            .local_owner = local.owner,
                            .storage_owner = current.owner,
                            .local_epoch = local.epoch,
                            .storage_epoch = current.epoch,
                        });
                    } else if (current.epoch != local.epoch) {
                        try findings.append(allocator, .{
                            .kind = .epoch_mismatch,
                            .shard_id = local.shard_id,
                            .local_owner = local.owner,
                            .storage_owner = current.owner,
                            .local_epoch = local.epoch,
                            .storage_epoch = current.epoch,
                        });
                    }
                } else {
                    try findings.append(allocator, .{
                        .kind = .missing_storage_lease,
                        .shard_id = local.shard_id,
                        .local_owner = local.owner,
                        .storage_owner = null,
                        .local_epoch = local.epoch,
                        .storage_epoch = null,
                    });
                }
            }
        }

        return .{
            .allocator = allocator,
            .findings = try findings.toOwnedSlice(allocator),
        };
    }

    pub fn inspectCluster(self: *RealClusterController, allocator: Allocator, now_ms: u64) !ClusterInspectionReport {
        var members = try self.discoverRunners(allocator, now_ms);
        errdefer members.deinit();

        var leases = try self.runner_storage.leases(allocator);
        errdefer leases.deinit();

        const metrics = try observability.collectClusterMetrics(
            allocator,
            self.runner_storage,
            self.message_storage,
            self.options.shard_count,
            null,
        );

        return .{
            .allocator = allocator,
            .generated_at_ms = now_ms,
            .members = members,
            .leases = leases,
            .metrics = metrics,
            .recent_rebalance_actions = self.recent_rebalance_actions,
            .recent_failures = self.recent_failures,
        };
    }
};

fn clusterMembershipStateFromHealth(state: runner.RunnerHealthState) ClusterMembershipState {
    return switch (state) {
        .starting => .joining,
        .healthy, .degraded => .active,
        .unhealthy => .down,
        .stopped => .leaving,
    };
}

fn clusterMemberLessThan(_: void, left: ClusterMember, right: ClusterMember) bool {
    if (left.address.machine_id != right.address.machine_id) return left.address.machine_id < right.address.machine_id;
    return left.address.runner_id < right.address.runner_id;
}

fn findPlacementOwner(plan: ClusterPlacementPlan, shard_id: ShardId) ?RunnerAddress {
    for (plan.placements) |placement| {
        if (placement.shard_id == shard_id) return placement.owner;
    }
    return null;
}

pub fn formatClusterInspectionText(allocator: Allocator, report: ClusterInspectionReport) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "schema: {s}\nschema_version: {d}\ngenerated_at_ms: {d}\nmembers.total: {d}\nmembers.active: {d}\nmembers.draining: {d}\nmembers.down: {d}\nleases.active: {d}\nmetrics.active_leases: {d}\nmetrics.mailbox_lag: {d}\nmetrics.max_shard_mailbox_lag: {d}\nmetrics.message_backpressure: {d}\nmetrics.message_retries: {d}\nmetrics.migrations: {d}\nmetrics.failures: {d}\nrebalance.actions.recent: {d}\nfailures.recent: {d}\n",
        .{
            cluster_inspection_schema,
            cluster_inspection_schema_version,
            report.generated_at_ms,
            report.members.members.len,
            report.members.active,
            report.members.draining,
            report.members.down,
            report.leases.leases.len,
            report.metrics.active_leases,
            report.metrics.mailbox_lag,
            report.metrics.max_shard_mailbox_lag,
            report.metrics.message_backpressure,
            report.metrics.message_retries,
            report.metrics.migrations,
            report.metrics.failures,
            report.recent_rebalance_actions,
            report.recent_failures,
        },
    );
}

pub fn formatClusterInspectionJson(allocator: Allocator, report: ClusterInspectionReport) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{{\"schema\":\"{s}\",\"schema_version\":{d},\"generated_at_ms\":{d},\"members_total\":{d},\"members_active\":{d},\"members_draining\":{d},\"members_down\":{d},\"leases_active\":{d},\"active_leases\":{d},\"mailbox_lag\":{d},\"max_shard_mailbox_lag\":{d},\"message_backpressure\":{d},\"message_retries\":{d},\"migrations\":{d},\"metric_failures\":{d},\"recent_rebalance_actions\":{d},\"recent_failures\":{d}}}",
        .{
            cluster_inspection_schema,
            cluster_inspection_schema_version,
            report.generated_at_ms,
            report.members.members.len,
            report.members.active,
            report.members.draining,
            report.members.down,
            report.leases.leases.len,
            report.metrics.active_leases,
            report.metrics.mailbox_lag,
            report.metrics.max_shard_mailbox_lag,
            report.metrics.message_backpressure,
            report.metrics.message_retries,
            report.metrics.migrations,
            report.metrics.failures,
            report.recent_rebalance_actions,
            report.recent_failures,
        },
    );
}
