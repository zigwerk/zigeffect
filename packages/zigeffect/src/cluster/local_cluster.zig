const std = @import("std");
const cluster_runtime = @import("runtime.zig");
const entity = @import("entity.zig");
const envelope = @import("envelope.zig");
const identity = @import("identity.zig");
const message_storage = @import("message_storage.zig");
const runner = @import("runner.zig");
const runner_storage = @import("runner_storage.zig");
const routing = @import("routing.zig");
const shard_lease = @import("shard_lease.zig");

pub const Allocator = std.mem.Allocator;
pub const ClusterRuntime = cluster_runtime.ClusterRuntime;
pub const ClusterRuntimeOptions = cluster_runtime.ClusterRuntimeOptions;
pub const EntityRegistration = entity.EntityRegistration;
pub const EntityRuntimeError = entity.EntityRuntimeError;
pub const EntityScope = entity.EntityScope;
pub const EntityAddress = identity.EntityAddress;
pub const LocalEntityRuntimeOptions = entity.LocalEntityRuntimeOptions;
pub const MessageCorrelationId = envelope.MessageCorrelationId;
pub const MessageEnvelope = envelope.MessageEnvelope;
pub const MessageEnvelopeKind = envelope.MessageEnvelopeKind;
pub const MessageStorage = message_storage.MessageStorage;
pub const MessageSubmitResult = envelope.MessageSubmitResult;
pub const RunnerAddress = runner.RunnerAddress;
pub const RunnerStorage = runner_storage.RunnerStorage;
pub const ShardCount = routing.ShardCount;
pub const ShardId = routing.ShardId;
pub const ShardLeaseManagerOptions = shard_lease.ShardLeaseManagerOptions;

pub const LocalClusterError = error{
    InvalidShardCount,
    InvalidRunnerCount,
    InvalidRunnerIndex,
};

pub const ShardBalancePlan = struct {
    allocator: Allocator,
    shards: []ShardId,

    pub fn deinit(self: *ShardBalancePlan) void {
        self.allocator.free(self.shards);
    }
};

pub const LocalClusterRouteResult = struct {
    shard_id: ShardId,
    envelope: MessageEnvelope,
    correlation_id: ?MessageCorrelationId = null,
    duplicate: bool = false,

    pub fn deinit(self: *LocalClusterRouteResult, allocator: Allocator) void {
        envelope.deinitMessageEnvelope(allocator, self.envelope);
    }
};

pub const LocalClusterRouterOptions = struct {
    shard_count: ShardCount,
};

pub const LocalClusterRouter = struct {
    allocator: Allocator,
    message_storage: MessageStorage,
    shard_count: ShardCount,
    next_message_sequence: u64 = 1,

    pub fn init(allocator: Allocator, storage: MessageStorage, options: LocalClusterRouterOptions) LocalClusterRouter {
        return .{
            .allocator = allocator,
            .message_storage = storage,
            .shard_count = options.shard_count,
        };
    }

    pub fn routeTell(self: *LocalClusterRouter, address: EntityAddress, payload_type_name: []const u8, payload: []const u8, redacted_detail: []const u8) !LocalClusterRouteResult {
        return self.routeMessage(.tell, address, payload_type_name, payload, redacted_detail);
    }

    pub fn routeAsk(self: *LocalClusterRouter, address: EntityAddress, payload_type_name: []const u8, payload: []const u8, redacted_detail: []const u8) !LocalClusterRouteResult {
        return self.routeMessage(.request, address, payload_type_name, payload, redacted_detail);
    }

    pub fn routeInterrupt(self: *LocalClusterRouter, address: EntityAddress, reason: []const u8) !LocalClusterRouteResult {
        return self.routeMessage(.interrupt, address, "interrupt", reason, reason);
    }

    fn routeMessage(
        self: *LocalClusterRouter,
        kind: MessageEnvelopeKind,
        address: EntityAddress,
        payload_type_name: []const u8,
        payload: []const u8,
        redacted_detail: []const u8,
    ) !LocalClusterRouteResult {
        const shard_id = try routing.shardIdForAddress(address, self.shard_count);
        var idempotency_buf: [40]u8 = undefined;
        const idempotency_key = std.fmt.bufPrint(&idempotency_buf, "local-router:{d}", .{self.next_message_sequence}) catch unreachable;
        self.next_message_sequence += 1;

        var submitted = try self.message_storage.submit(.{
            .shard_id = shard_id,
            .envelope = .{
                .kind = kind,
                .address = address,
                .idempotency_key = idempotency_key,
                .payload_type_name = payload_type_name,
                .payload = payload,
                .redacted_detail = redacted_detail,
            },
        });
        errdefer submitted.deinit(self.allocator);

        return .{
            .shard_id = shard_id,
            .envelope = submitted.envelope,
            .correlation_id = submitted.envelope.correlation_id,
            .duplicate = submitted.duplicate,
        };
    }
};

pub const LocalClusterRunnerOptions = struct {
    runner: RunnerAddress,
    runner_storage: RunnerStorage,
    message_storage: MessageStorage,
    shard_count: ShardCount,
    runner_index: usize,
    runner_count: usize,
    lease_options: ShardLeaseManagerOptions,
    entity_runtime_options: LocalEntityRuntimeOptions = .{},
};

pub const LocalClusterRunnerReport = struct {
    refreshed: usize = 0,
    reacquired: usize = 0,
    expired: usize = 0,
    conflicts: usize = 0,
    scanned: usize = 0,
    claimed: usize = 0,
    dispatched: usize = 0,
    replied: usize = 0,
    acked: usize = 0,
    failed: usize = 0,
    skipped: usize = 0,
};

pub const LocalClusterRunner = struct {
    allocator: Allocator,
    runner: RunnerAddress,
    lease_manager: *shard_lease.LocalShardLeaseManager,
    runtime: ClusterRuntime,
    router: LocalClusterRouter,
    shard_count: ShardCount,
    runner_index: usize,
    runner_count: usize,

    pub fn init(allocator: Allocator, options: LocalClusterRunnerOptions) !LocalClusterRunner {
        const lease_manager = try allocator.create(shard_lease.LocalShardLeaseManager);
        errdefer allocator.destroy(lease_manager);
        lease_manager.* = try shard_lease.LocalShardLeaseManager.init(
            allocator,
            options.runner_storage,
            options.runner,
            options.lease_options,
        );
        errdefer lease_manager.deinit();

        var runtime = try ClusterRuntime.init(
            allocator,
            options.message_storage,
            lease_manager,
            .{
                .shard_count = options.shard_count,
                .entity_runtime_options = options.entity_runtime_options,
            },
        );
        errdefer runtime.deinit();

        return .{
            .allocator = allocator,
            .runner = options.runner,
            .lease_manager = lease_manager,
            .runtime = runtime,
            .router = LocalClusterRouter.init(allocator, options.message_storage, .{ .shard_count = options.shard_count }),
            .shard_count = options.shard_count,
            .runner_index = options.runner_index,
            .runner_count = options.runner_count,
        };
    }

    pub fn deinit(self: *LocalClusterRunner) void {
        self.runtime.deinit();
        self.lease_manager.deinit();
        self.allocator.destroy(self.lease_manager);
    }

    pub fn acquireBalancedShards(self: *LocalClusterRunner, now_ms: u64) !ShardBalancePlan {
        var plan = try balancedShardPlan(self.allocator, self.shard_count, self.runner_index, self.runner_count);
        errdefer plan.deinit();
        for (plan.shards) |shard_id| {
            _ = try self.runtime.acquireShard(shard_id, now_ms);
        }
        _ = try self.runtime.loadOwnedShards();
        return plan;
    }

    pub fn loadOwnedShards(self: *LocalClusterRunner) !usize {
        return self.runtime.loadOwnedShards();
    }

    pub fn registerEntity(self: *LocalClusterRunner, registration: EntityRegistration, now_ms: u64) !cluster_runtime.ClusterEntityRef {
        return self.runtime.registerEntity(registration, now_ms);
    }

    pub fn entityScope(self: *LocalClusterRunner, address: EntityAddress) EntityRuntimeError!*EntityScope {
        return self.runtime.entityScope(address);
    }

    pub fn tick(self: *LocalClusterRunner, handler: anytype, now_ms: u64) !LocalClusterRunnerReport {
        const refresh = try self.lease_manager.refreshOwnedLeases(now_ms);
        _ = try self.runtime.loadOwnedShards();
        const processed = try self.runtime.processOwnedShards(handler, now_ms);
        return .{
            .refreshed = refresh.refreshed,
            .reacquired = refresh.reacquired,
            .expired = refresh.expired,
            .conflicts = refresh.conflicts,
            .scanned = processed.scanned,
            .claimed = processed.claimed,
            .dispatched = processed.dispatched,
            .replied = processed.replied,
            .acked = processed.acked,
            .failed = processed.failed,
            .skipped = processed.skipped,
        };
    }

    pub fn shutdown(self: *LocalClusterRunner, now_ms: u64) !cluster_runtime.ClusterShutdownReport {
        return self.runtime.shutdown(now_ms);
    }
};

pub const ShardRecoveryPlan = struct {
    allocator: Allocator,
    shards: []ShardId,
    released: usize = 0,
    acquired: usize = 0,

    pub fn deinit(self: *ShardRecoveryPlan) void {
        self.allocator.free(self.shards);
    }
};

pub fn balancedShardPlan(
    allocator: Allocator,
    shard_count: ShardCount,
    runner_index: usize,
    runner_count: usize,
) (Allocator.Error || LocalClusterError)!ShardBalancePlan {
    if (shard_count == 0) return error.InvalidShardCount;
    if (runner_count == 0) return error.InvalidRunnerCount;
    if (runner_index >= runner_count) return error.InvalidRunnerIndex;

    var shards = std.ArrayList(ShardId).empty;
    errdefer shards.deinit(allocator);

    var shard_id: ShardId = 0;
    while (shard_id < @as(ShardId, shard_count)) : (shard_id += 1) {
        if (shard_id % @as(ShardId, @intCast(runner_count)) != @as(ShardId, @intCast(runner_index))) continue;
        try shards.append(allocator, shard_id);
    }

    return .{
        .allocator = allocator,
        .shards = try shards.toOwnedSlice(allocator),
    };
}
