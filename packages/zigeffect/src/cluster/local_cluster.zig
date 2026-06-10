const std = @import("std");
const envelope = @import("envelope.zig");
const identity = @import("identity.zig");
const message_storage = @import("message_storage.zig");
const routing = @import("routing.zig");

pub const Allocator = std.mem.Allocator;
pub const EntityAddress = identity.EntityAddress;
pub const MessageCorrelationId = envelope.MessageCorrelationId;
pub const MessageEnvelope = envelope.MessageEnvelope;
pub const MessageEnvelopeKind = envelope.MessageEnvelopeKind;
pub const MessageStorage = message_storage.MessageStorage;
pub const MessageSubmitResult = envelope.MessageSubmitResult;
pub const ShardCount = routing.ShardCount;
pub const ShardId = routing.ShardId;

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

pub const LocalClusterRunnerOptions = struct {};

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

pub const LocalClusterRunner = struct {};

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
