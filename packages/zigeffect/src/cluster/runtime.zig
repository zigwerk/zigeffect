const std = @import("std");
const entity = @import("entity.zig");
const envelope = @import("envelope.zig");
const identity = @import("identity.zig");
const mailbox = @import("mailbox.zig");
const message_storage = @import("message_storage.zig");
const routing = @import("routing.zig");
const shard_lease = @import("shard_lease.zig");
const fencing = @import("fencing.zig");
const lease_guard = @import("lease_guard.zig");
const supervision = @import("supervision.zig");
const observability = @import("observability.zig");

pub const Allocator = std.mem.Allocator;
pub const EntityAddress = identity.EntityAddress;
pub const EntityEnvelope = mailbox.EntityEnvelope;
pub const EntityScope = entity.EntityScope;
pub const MessageCorrelationId = envelope.MessageCorrelationId;
pub const MessageEnvelope = envelope.MessageEnvelope;
pub const MessageEnvelopeKind = envelope.MessageEnvelopeKind;
pub const MessageSubmitResult = envelope.MessageSubmitResult;
pub const MessageStorage = message_storage.MessageStorage;
pub const MessageStorageSubmit = message_storage.MessageStorageSubmit;
pub const ShardCount = routing.ShardCount;
pub const ShardId = routing.ShardId;
pub const ShardLease = shard_lease.ShardLease;
pub const LocalShardLeaseManager = shard_lease.LocalShardLeaseManager;
pub const EntityRegistration = entity.EntityRegistration;
pub const EntityRuntimeError = entity.EntityRuntimeError;
pub const LocalEntityRuntimeOptions = entity.LocalEntityRuntimeOptions;
pub const ClusterSupervisionPolicy = supervision.ClusterSupervisionPolicy;
pub const ClusterSupervisionReport = supervision.ClusterSupervisionReport;
pub const ClusterTraceContext = observability.ClusterTraceContext;
pub const ClusterCausalRecorder = observability.ClusterCausalRecorder;
pub const CausalStore = observability.CausalStore;

pub const ClusterRuntimeError = error{
    RuntimeShuttingDown,
    ShardNotOwned,
    StaleShardFence,
    UnsupportedMessageKind,
    MissingReply,
};

pub const ClusterRuntimeOptions = struct {
    shard_count: ShardCount,
    entity_runtime_options: LocalEntityRuntimeOptions = .{},
    supervision_policy: ClusterSupervisionPolicy = .{},
};

pub const ClusterProcessReport = struct {
    scanned: usize = 0,
    claimed: usize = 0,
    dispatched: usize = 0,
    replied: usize = 0,
    acked: usize = 0,
    failed: usize = 0,
    skipped: usize = 0,
};

pub const ClusterShutdownReport = struct {
    released_shards: usize = 0,
};

pub const ClusterAsk = struct {
    envelope: MessageEnvelope,
    correlation_id: MessageCorrelationId,
    duplicate: bool = false,

    pub fn deinit(self: *ClusterAsk, allocator: Allocator) void {
        envelope.deinitMessageEnvelope(allocator, self.envelope);
    }
};

pub const ClusterEntityRef = struct {
    address: EntityAddress,
    runtime: *ClusterRuntime,

    pub fn tell(self: ClusterEntityRef, payload_type_name: []const u8, payload: []const u8, redacted_detail: []const u8) !MessageSubmitResult {
        return self.runtime.submitEntityMessage(.tell, self.address, payload_type_name, payload, redacted_detail);
    }

    pub fn tellWithTrace(self: ClusterEntityRef, payload_type_name: []const u8, payload: []const u8, redacted_detail: []const u8, trace: ClusterTraceContext) !MessageSubmitResult {
        return self.runtime.submitEntityMessageWithTrace(.tell, self.address, payload_type_name, payload, redacted_detail, trace);
    }

    pub fn ask(self: ClusterEntityRef, payload_type_name: []const u8, payload: []const u8, redacted_detail: []const u8) !ClusterAsk {
        var submitted = try self.runtime.submitEntityMessage(.request, self.address, payload_type_name, payload, redacted_detail);
        errdefer submitted.deinit(self.runtime.allocator);
        return .{
            .envelope = submitted.envelope,
            .correlation_id = submitted.envelope.correlation_id.?,
            .duplicate = submitted.duplicate,
        };
    }

    pub fn askWithTrace(self: ClusterEntityRef, payload_type_name: []const u8, payload: []const u8, redacted_detail: []const u8, trace: ClusterTraceContext) !ClusterAsk {
        var submitted = try self.runtime.submitEntityMessageWithTrace(.request, self.address, payload_type_name, payload, redacted_detail, trace);
        errdefer submitted.deinit(self.runtime.allocator);
        return .{
            .envelope = submitted.envelope,
            .correlation_id = submitted.envelope.correlation_id.?,
            .duplicate = submitted.duplicate,
        };
    }

    pub fn interrupt(self: ClusterEntityRef, reason: []const u8) !MessageSubmitResult {
        return self.runtime.submitEntityMessage(.interrupt, self.address, "interrupt", reason, reason);
    }
};

pub const ClusterRuntime = struct {
    allocator: Allocator,
    message_storage: MessageStorage,
    lease_manager: *LocalShardLeaseManager,
    local_runtime: entity.LocalEntityRuntime,
    shard_count: ShardCount,
    supervision_policy: ClusterSupervisionPolicy = .{},
    causal_recorder: ?ClusterCausalRecorder = null,
    owned_shards: std.ArrayList(ShardId) = .empty,
    accepting_messages: bool = true,
    next_message_sequence: u64 = 1,

    pub fn init(
        allocator: Allocator,
        storage: MessageStorage,
        lease_manager: *LocalShardLeaseManager,
        options: ClusterRuntimeOptions,
    ) routing.ShardRoutingError!ClusterRuntime {
        if (options.shard_count == 0) return error.InvalidShardCount;
        return .{
            .allocator = allocator,
            .message_storage = storage,
            .lease_manager = lease_manager,
            .local_runtime = entity.LocalEntityRuntime.init(allocator, options.entity_runtime_options),
            .shard_count = options.shard_count,
            .supervision_policy = options.supervision_policy,
        };
    }

    pub fn deinit(self: *ClusterRuntime) void {
        self.owned_shards.deinit(self.allocator);
        self.local_runtime.deinit();
    }

    pub fn attachCausalStore(self: *ClusterRuntime, store: *CausalStore, run_id: u64) void {
        self.causal_recorder = ClusterCausalRecorder.init(store, run_id);
    }

    pub fn loadOwnedShards(self: *ClusterRuntime) Allocator.Error!usize {
        self.owned_shards.clearRetainingCapacity();
        var leases = try self.lease_manager.ownedLeases(self.allocator);
        defer leases.deinit();
        try self.owned_shards.ensureTotalCapacity(self.allocator, leases.leases.len);
        for (leases.leases) |lease| {
            self.owned_shards.appendAssumeCapacity(lease.shard_id);
        }
        return self.owned_shards.items.len;
    }

    pub fn acquireShard(self: *ClusterRuntime, shard_id: ShardId, now_ms: u64) !ShardLease {
        const lease = try self.lease_manager.acquireShard(shard_id, now_ms);
        errdefer self.lease_manager.releaseShard(shard_id, now_ms) catch {};
        try self.recordOwnedShard(shard_id);
        return lease;
    }

    pub fn releaseShard(self: *ClusterRuntime, shard_id: ShardId, now_ms: u64) !void {
        try self.lease_manager.releaseShard(shard_id, now_ms);
        self.removeOwnedShard(shard_id);
    }

    pub fn ownsShard(self: *const ClusterRuntime, shard_id: ShardId) bool {
        return self.findOwnedShardIndex(shard_id) != null;
    }

    pub fn ownedShardCount(self: *const ClusterRuntime) usize {
        return self.owned_shards.items.len;
    }

    pub fn entityScope(self: *ClusterRuntime, address: EntityAddress) EntityRuntimeError!*EntityScope {
        return self.local_runtime.entityScope(address);
    }

    pub fn registerEntity(
        self: *ClusterRuntime,
        registration: EntityRegistration,
        now_ms: u64,
    ) !ClusterEntityRef {
        const local_ref = try self.local_runtime.registerEntity(registration, now_ms);
        try self.recordEntityCausal(.cluster_entity_registered, local_ref.address, "registered", registration.name, null);
        return .{
            .address = local_ref.address,
            .runtime = self,
        };
    }

    pub fn ref(self: *ClusterRuntime, address: EntityAddress) EntityRuntimeError!ClusterEntityRef {
        const local_ref = try self.local_runtime.ref(address);
        return .{
            .address = local_ref.address,
            .runtime = self,
        };
    }

    pub fn processOwnedShards(self: *ClusterRuntime, handler: anytype, now_ms: u64) !ClusterProcessReport {
        var total = ClusterProcessReport{};
        for (self.owned_shards.items) |shard_id| {
            const report = try self.processShard(shard_id, handler, now_ms);
            total.scanned += report.scanned;
            total.claimed += report.claimed;
            total.dispatched += report.dispatched;
            total.replied += report.replied;
            total.acked += report.acked;
            total.failed += report.failed;
            total.skipped += report.skipped;
        }
        return total;
    }

    pub fn processOwnedShardsSupervised(self: *ClusterRuntime, handler: anytype, now_ms: u64) !ClusterSupervisionReport {
        var total = ClusterSupervisionReport{};
        var index: usize = 0;
        while (index < self.owned_shards.items.len) {
            const shard_id = self.owned_shards.items[index];
            const report = try self.processShardSupervised(shard_id, handler, now_ms);
            total.add(report);
            if (self.ownsShard(shard_id)) {
                index += 1;
            }
        }
        return total;
    }

    pub fn processShard(self: *ClusterRuntime, shard_id: ShardId, handler: anytype, now_ms: u64) !ClusterProcessReport {
        if (!self.ownsShard(shard_id)) return error.ShardNotOwned;
        self.validateShardFence(shard_id) catch |err| switch (err) {
            error.StaleShardFence => {
                self.removeOwnedShard(shard_id);
                self.accepting_messages = false;
                return err;
            },
            else => return err,
        };

        var report = ClusterProcessReport{};
        var batch = try self.message_storage.unprocessedByShard(shard_id, self.allocator);
        defer batch.deinit();

        for (batch.records) |record| {
            report.scanned += 1;
            const claimed = lease_guard.guardMessageClaim(self.message_storage, .{
                .guard = try self.messageWriteGuard(shard_id, .message_claim),
                .request = .{
                    .shard_id = shard_id,
                    .message_id = record.envelope.id,
                    .now_ms = now_ms,
                },
            }) catch |err| switch (err) {
                error.StaleShardFence => {
                    self.handleStaleShardFence(shard_id);
                    return err;
                },
                else => return err,
            };
            defer envelope.deinitMessageEnvelope(self.allocator, claimed);
            report.claimed += 1;
            try self.recordMessageCausal(.cluster_message_claimed, shard_id, claimed, "claimed", record.envelope.redacted_detail);

            const entity_envelope = try messageToEntityEnvelope(self.allocator, claimed);
            var result = self.local_runtime.processEnvelope(entity_envelope, handler, now_ms) catch |err| {
                report.failed += 1;
                try self.recordEntityCausal(.cluster_entity_failed, claimed.address, "failed", @errorName(err), traceContextFromMessage(claimed));
                return err;
            };
            defer result.deinit(self.allocator);
            report.dispatched += 1;
            try self.recordEntityCausal(.cluster_entity_processed, claimed.address, "processed", claimed.redacted_detail, traceContextFromMessage(claimed));

            if (result.replied) {
                const correlation_id = result.envelope.correlation_id orelse return error.MissingReply;
                const local_reply = try self.local_runtime.takeReply(correlation_id);
                defer mailbox.deinitEntityEnvelope(self.allocator, local_reply);
                var durable_reply = try entityReplyToMessageEnvelope(self.allocator, local_reply);
                defer envelope.deinitMessageEnvelope(self.allocator, durable_reply);
                durable_reply.trace_id = claimed.trace_id;
                durable_reply.span_id = claimed.span_id;
                durable_reply.chunk_index = claimed.chunk_index;
                durable_reply.chunk_count = claimed.chunk_count;
                const stored_reply = lease_guard.guardMessageReply(self.message_storage, .{
                    .guard = try self.messageWriteGuard(shard_id, .message_reply),
                    .request = .{
                        .shard_id = shard_id,
                        .envelope = durable_reply,
                        .now_ms = now_ms,
                    },
                }) catch |err| switch (err) {
                    error.StaleShardFence => {
                        self.handleStaleShardFence(shard_id);
                        return err;
                    },
                    else => return err,
                };
                defer envelope.deinitMessageEnvelope(self.allocator, stored_reply);
                report.replied += 1;
                try self.recordMessageCausal(.cluster_message_replied, shard_id, claimed, "replied", stored_reply.redacted_detail);
            }

            lease_guard.guardMessageAck(self.message_storage, .{
                .guard = try self.messageWriteGuard(shard_id, .message_ack),
                .request = .{
                    .message_id = claimed.id,
                    .now_ms = now_ms,
                },
            }) catch |err| switch (err) {
                error.StaleShardFence => {
                    self.handleStaleShardFence(shard_id);
                    return err;
                },
                else => return err,
            };
            report.acked += 1;
            try self.recordMessageCausal(.cluster_message_acked, shard_id, claimed, "acked", claimed.redacted_detail);
        }

        return report;
    }

    pub fn processShardSupervised(self: *ClusterRuntime, shard_id: ShardId, handler: anytype, now_ms: u64) !ClusterSupervisionReport {
        if (!self.ownsShard(shard_id)) return error.ShardNotOwned;
        self.validateShardFence(shard_id) catch |err| switch (err) {
            error.StaleShardFence => {
                self.removeOwnedShard(shard_id);
                self.accepting_messages = false;
                return err;
            },
            else => return err,
        };

        var report = ClusterSupervisionReport{};
        var batch = try self.message_storage.unprocessedByShard(shard_id, self.allocator);
        defer batch.deinit();

        for (batch.records) |record| {
            report.scanned += 1;
            const claimed = lease_guard.guardMessageClaim(self.message_storage, .{
                .guard = try self.messageWriteGuard(shard_id, .message_claim),
                .request = .{
                    .shard_id = shard_id,
                    .message_id = record.envelope.id,
                    .now_ms = now_ms,
                },
            }) catch |err| switch (err) {
                error.StaleShardFence => {
                    self.handleStaleShardFence(shard_id);
                    return err;
                },
                else => return err,
            };
            defer envelope.deinitMessageEnvelope(self.allocator, claimed);
            report.claimed += 1;
            try self.recordMessageCausal(.cluster_message_claimed, shard_id, claimed, "claimed", record.envelope.redacted_detail);

            const entity_envelope = try messageToEntityEnvelope(self.allocator, claimed);
            var result = self.local_runtime.processEnvelope(entity_envelope, handler, now_ms) catch |err| {
                report.failed += 1;
                report.entity_failures += 1;
                try self.recordEntityCausal(.cluster_entity_failed, claimed.address, "failed", @errorName(err), traceContextFromMessage(claimed));
                const decision = (try self.local_runtime.lastSupervisorDecision(record.envelope.address)) orelse return err;
                const is_workflow_worker = std.mem.eql(
                    u8,
                    record.envelope.address.entity_type.name,
                    self.supervision_policy.workflow_entity_type_name,
                );
                if (is_workflow_worker) {
                    report.workflow_worker_failures += 1;
                }
                if (decision.restarted_children > 0) {
                    report.entity_restarts += 1;
                    if (is_workflow_worker) {
                        report.workflow_worker_restarts += 1;
                    }
                }
                if (decision.escalated) {
                    report.entity_escalations += 1;
                    if (self.supervision_policy.release_shard_on_escalation) {
                        try self.releaseShard(shard_id, now_ms);
                        report.shard_releases += 1;
                        return report;
                    }
                }
                continue;
            };
            defer result.deinit(self.allocator);
            report.dispatched += 1;
            try self.recordEntityCausal(.cluster_entity_processed, claimed.address, "processed", claimed.redacted_detail, traceContextFromMessage(claimed));

            if (result.replied) {
                const correlation_id = result.envelope.correlation_id orelse return error.MissingReply;
                const local_reply = try self.local_runtime.takeReply(correlation_id);
                defer mailbox.deinitEntityEnvelope(self.allocator, local_reply);
                var durable_reply = try entityReplyToMessageEnvelope(self.allocator, local_reply);
                defer envelope.deinitMessageEnvelope(self.allocator, durable_reply);
                durable_reply.trace_id = claimed.trace_id;
                durable_reply.span_id = claimed.span_id;
                durable_reply.chunk_index = claimed.chunk_index;
                durable_reply.chunk_count = claimed.chunk_count;
                const stored_reply = lease_guard.guardMessageReply(self.message_storage, .{
                    .guard = try self.messageWriteGuard(shard_id, .message_reply),
                    .request = .{
                        .shard_id = shard_id,
                        .envelope = durable_reply,
                        .now_ms = now_ms,
                    },
                }) catch |err| switch (err) {
                    error.StaleShardFence => {
                        self.handleStaleShardFence(shard_id);
                        return err;
                    },
                    else => return err,
                };
                defer envelope.deinitMessageEnvelope(self.allocator, stored_reply);
                report.replied += 1;
                try self.recordMessageCausal(.cluster_message_replied, shard_id, claimed, "replied", stored_reply.redacted_detail);
            }

            lease_guard.guardMessageAck(self.message_storage, .{
                .guard = try self.messageWriteGuard(shard_id, .message_ack),
                .request = .{
                    .message_id = claimed.id,
                    .now_ms = now_ms,
                },
            }) catch |err| switch (err) {
                error.StaleShardFence => {
                    self.handleStaleShardFence(shard_id);
                    return err;
                },
                else => return err,
            };
            report.acked += 1;
            try self.recordMessageCausal(.cluster_message_acked, shard_id, claimed, "acked", claimed.redacted_detail);
        }

        return report;
    }

    pub fn shutdown(self: *ClusterRuntime, now_ms: u64) !ClusterShutdownReport {
        self.accepting_messages = false;
        var report = ClusterShutdownReport{};
        while (self.owned_shards.items.len > 0) {
            const index = self.owned_shards.items.len - 1;
            const shard_id = self.owned_shards.items[index];
            try self.lease_manager.releaseShard(shard_id, now_ms);
            _ = self.owned_shards.orderedRemove(index);
            report.released_shards += 1;
        }
        return report;
    }

    fn submitEntityMessage(
        self: *ClusterRuntime,
        kind: MessageEnvelopeKind,
        address: EntityAddress,
        payload_type_name: []const u8,
        payload: []const u8,
        redacted_detail: []const u8,
    ) !MessageSubmitResult {
        return self.submitEntityMessageWithOptionalTrace(kind, address, payload_type_name, payload, redacted_detail, null);
    }

    fn submitEntityMessageWithTrace(
        self: *ClusterRuntime,
        kind: MessageEnvelopeKind,
        address: EntityAddress,
        payload_type_name: []const u8,
        payload: []const u8,
        redacted_detail: []const u8,
        trace: ClusterTraceContext,
    ) !MessageSubmitResult {
        return self.submitEntityMessageWithOptionalTrace(kind, address, payload_type_name, payload, redacted_detail, trace);
    }

    fn submitEntityMessageWithOptionalTrace(
        self: *ClusterRuntime,
        kind: MessageEnvelopeKind,
        address: EntityAddress,
        payload_type_name: []const u8,
        payload: []const u8,
        redacted_detail: []const u8,
        trace: ?ClusterTraceContext,
    ) !MessageSubmitResult {
        if (!self.accepting_messages) return error.RuntimeShuttingDown;
        const shard_id = try routing.shardIdForAddress(address, self.shard_count);
        if (!self.ownsShard(shard_id)) return error.ShardNotOwned;
        self.validateShardFence(shard_id) catch |err| switch (err) {
            error.StaleShardFence => {
                self.removeOwnedShard(shard_id);
                self.accepting_messages = false;
                return err;
            },
            else => return err,
        };

        var idempotency_buf: [32]u8 = undefined;
        const idempotency_key = std.fmt.bufPrint(&idempotency_buf, "cluster:{d}", .{self.next_message_sequence}) catch unreachable;
        self.next_message_sequence += 1;

        var submitted = lease_guard.guardMessageSubmit(self.message_storage, .{
            .guard = try self.messageWriteGuard(shard_id, .message_submit),
            .request = .{
                .shard_id = shard_id,
                .envelope = .{
                    .kind = kind,
                    .address = address,
                    .idempotency_key = idempotency_key,
                    .trace_id = if (trace) |value| value.trace_id else null,
                    .span_id = if (trace) |value| value.span_id else null,
                    .payload_type_name = payload_type_name,
                    .payload = payload,
                    .redacted_detail = redacted_detail,
                },
            },
        }) catch |err| switch (err) {
            error.StaleShardFence => {
                self.handleStaleShardFence(shard_id);
                return err;
            },
            else => return err,
        };
        errdefer submitted.deinit(self.allocator);

        try self.recordMessageCausal(
            .cluster_message_submitted,
            shard_id,
            submitted.envelope,
            if (submitted.duplicate) "duplicate" else "submitted",
            redacted_detail,
        );
        if (trace != null) {
            try self.recordTracePropagationCausal(shard_id, submitted.envelope);
        }
        return submitted;
    }

    fn validateShardFence(self: *ClusterRuntime, shard_id: ShardId) !void {
        const fence = try self.lease_manager.fenceForShard(shard_id);
        try fencing.validateShardFence(self.lease_manager.storage, fence);
    }

    fn messageWriteGuard(self: *ClusterRuntime, shard_id: ShardId, kind: lease_guard.ShardLeaseWriteKind) !lease_guard.ShardLeaseWriteGuard {
        const fence = try self.lease_manager.fenceForShard(shard_id);
        return lease_guard.ShardLeaseWriteGuard.init(self.lease_manager.storage, fence, kind);
    }

    fn handleStaleShardFence(self: *ClusterRuntime, shard_id: ShardId) void {
        self.removeOwnedShard(shard_id);
        self.accepting_messages = false;
    }

    fn recordOwnedShard(self: *ClusterRuntime, shard_id: ShardId) Allocator.Error!void {
        if (self.ownsShard(shard_id)) return;
        try self.owned_shards.append(self.allocator, shard_id);
    }

    fn removeOwnedShard(self: *ClusterRuntime, shard_id: ShardId) void {
        const index = self.findOwnedShardIndex(shard_id) orelse return;
        _ = self.owned_shards.orderedRemove(index);
    }

    fn findOwnedShardIndex(self: *const ClusterRuntime, shard_id: ShardId) ?usize {
        for (self.owned_shards.items, 0..) |owned, index| {
            if (owned == shard_id) return index;
        }
        return null;
    }

    fn recordMessageCausal(
        self: *ClusterRuntime,
        kind: observability.CausalEventKind,
        shard_id: ShardId,
        message: MessageEnvelope,
        status: []const u8,
        detail: []const u8,
    ) Allocator.Error!void {
        const recorder = self.causal_recorder orelse return;
        try recorder.recordMessage(kind, shard_id, message, status, detail);
    }

    fn recordEntityCausal(
        self: *ClusterRuntime,
        kind: observability.CausalEventKind,
        address: EntityAddress,
        status: []const u8,
        detail: []const u8,
        trace: ?ClusterTraceContext,
    ) Allocator.Error!void {
        const recorder = self.causal_recorder orelse return;
        try recorder.recordEntity(kind, address, status, detail, trace);
    }

    fn recordTracePropagationCausal(self: *ClusterRuntime, shard_id: ShardId, message: MessageEnvelope) Allocator.Error!void {
        const recorder = self.causal_recorder orelse return;
        try recorder.recordTracePropagation(shard_id, message);
    }
};

fn traceContextFromMessage(message: MessageEnvelope) ?ClusterTraceContext {
    const trace_id = message.trace_id orelse return null;
    return .{
        .trace_id = trace_id,
        .span_id = message.span_id,
    };
}

fn messageToEntityEnvelope(allocator: Allocator, message: MessageEnvelope) !EntityEnvelope {
    const kind: mailbox.EntityEnvelopeKind = switch (message.kind) {
        .tell => .tell,
        .request => .ask,
        .interrupt => .interrupt,
        else => return error.UnsupportedMessageKind,
    };

    return mailbox.cloneEntityEnvelope(allocator, .{
        .id = message.id,
        .sequence = message.id,
        .kind = kind,
        .address = message.address,
        .correlation_id = message.correlation_id,
        .lease_epoch = message.lease_epoch,
        .payload_type_name = message.payload_type_name,
        .payload = message.payload,
        .redacted_detail = message.redacted_detail,
    });
}

fn entityReplyToMessageEnvelope(allocator: Allocator, reply: EntityEnvelope) !MessageEnvelope {
    if (reply.kind != .reply) return error.UnsupportedMessageKind;
    return envelope.cloneMessageEnvelope(allocator, .{
        .kind = .reply,
        .address = reply.address,
        .correlation_id = reply.correlation_id,
        .payload_type_name = reply.payload_type_name,
        .payload = reply.payload,
        .redacted_detail = reply.redacted_detail,
    });
}
