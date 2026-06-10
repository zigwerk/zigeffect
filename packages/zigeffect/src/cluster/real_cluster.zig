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

pub const ClusterSplitBrainFinding = struct {
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
};

pub fn formatClusterInspectionText(allocator: Allocator, report: ClusterInspectionReport) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "cluster inspection members={d} active={d} leases={d} lag={d} actions={d} failures={d}",
        .{
            report.members.members.len,
            report.members.active,
            report.leases.leases.len,
            report.metrics.mailbox_lag,
            report.recent_rebalance_actions,
            report.recent_failures,
        },
    );
}

pub fn formatClusterInspectionJson(allocator: Allocator, report: ClusterInspectionReport) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{{\"schema\":\"{s}\",\"schema_version\":{d},\"generated_at_ms\":{d},\"members\":{d},\"active\":{d},\"leases\":{d},\"lag\":{d},\"actions\":{d},\"failures\":{d}}}",
        .{
            cluster_inspection_schema,
            cluster_inspection_schema_version,
            report.generated_at_ms,
            report.members.members.len,
            report.members.active,
            report.leases.leases.len,
            report.metrics.mailbox_lag,
            report.recent_rebalance_actions,
            report.recent_failures,
        },
    );
}
