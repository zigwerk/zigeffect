const std = @import("std");
const fx = @import("zigeffect");

pub const MessageRequestPlan = struct {
    shard_id: fx.ShardId,
    address_key: []const u8,
    idempotency_key: []const u8,
    payload: []const u8,
    submit_duplicate: bool,
    claim: bool,
    store_reply: bool,
    ack: bool,

    fn deinit(self: *MessageRequestPlan, allocator: std.mem.Allocator) void {
        allocator.free(self.address_key);
        allocator.free(self.idempotency_key);
        allocator.free(self.payload);
    }
};

pub const GeneratedMessageHistory = struct {
    allocator: std.mem.Allocator,
    seed: u64,
    case_index: usize,
    requests: []MessageRequestPlan,

    pub fn deinit(self: *GeneratedMessageHistory) void {
        for (self.requests) |*request| {
            request.deinit(self.allocator);
        }
        self.allocator.free(self.requests);
    }
};

pub const ObservedMessageRecord = struct {
    shard_id: fx.ShardId,
    message_id: fx.MessageId,
    status: fx.MessageDeliveryStatus,
    attempt: fx.MessageAttempt,
    payload: []const u8,

    fn deinit(self: *ObservedMessageRecord, allocator: std.mem.Allocator) void {
        if (self.payload.len > 0) allocator.free(self.payload);
    }
};

pub const ObservedMessageLookup = struct {
    message_id: fx.MessageId,
    found: bool,
    status: fx.MessageDeliveryStatus = .pending,
    attempt: fx.MessageAttempt = 0,
    payload: []const u8 = "",

    fn deinit(self: *ObservedMessageLookup, allocator: std.mem.Allocator) void {
        if (self.payload.len > 0) allocator.free(self.payload);
    }
};

pub const ObservedReply = struct {
    correlation_id: fx.MessageCorrelationId,
    found: bool,
    payload: []const u8 = "",

    fn deinit(self: *ObservedReply, allocator: std.mem.Allocator) void {
        if (self.payload.len > 0) allocator.free(self.payload);
    }
};

pub const MessageObservation = struct {
    allocator: std.mem.Allocator,
    message_ids: []fx.MessageId,
    reply_correlation_ids: []fx.MessageCorrelationId,
    unprocessed: []ObservedMessageRecord,
    lookups: []ObservedMessageLookup,
    replies: []ObservedReply,

    pub fn deinit(self: *MessageObservation) void {
        for (self.replies) |*reply| {
            reply.deinit(self.allocator);
        }
        self.allocator.free(self.replies);

        for (self.lookups) |*lookup| {
            lookup.deinit(self.allocator);
        }
        self.allocator.free(self.lookups);

        for (self.unprocessed) |*record| {
            record.deinit(self.allocator);
        }
        self.allocator.free(self.unprocessed);

        self.allocator.free(self.reply_correlation_ids);
        self.allocator.free(self.message_ids);
    }
};

pub fn generateMessageHistory(
    allocator: std.mem.Allocator,
    seed: u64,
    case_index: usize,
) !GeneratedMessageHistory {
    var requests = std.ArrayList(MessageRequestPlan).empty;
    errdefer {
        for (requests.items) |*request| {
            request.deinit(allocator);
        }
        requests.deinit(allocator);
    }

    const request_count: usize = @intCast(3 + choice(seed, case_index, 1, 4));
    var index: usize = 0;
    while (index < request_count) : (index += 1) {
        var request = MessageRequestPlan{
            .shard_id = @intCast(1 + choice(seed, case_index, 10 + index, 4)),
            .address_key = try std.fmt.allocPrint(allocator, "property-message-{d}-{d}-{d}", .{ seed, case_index, index }),
            .idempotency_key = try std.fmt.allocPrint(allocator, "message:{d}:{d}:{d}", .{ seed, case_index, index }),
            .payload = try std.fmt.allocPrint(allocator, "payload:{d}:{d}:{d}", .{ seed, case_index, index }),
            .submit_duplicate = choice(seed, case_index, 20 + index, 2) == 0,
            .claim = choice(seed, case_index, 30 + index, 3) != 0,
            .store_reply = choice(seed, case_index, 40 + index, 4) == 0,
            .ack = false,
        };
        errdefer request.deinit(allocator);
        request.ack = !request.store_reply and choice(seed, case_index, 50 + index, 3) == 0;
        try requests.append(allocator, request);
    }

    return .{
        .allocator = allocator,
        .seed = seed,
        .case_index = case_index,
        .requests = try requests.toOwnedSlice(allocator),
    };
}

pub fn applyMessageHistory(
    allocator: std.mem.Allocator,
    storage: fx.MessageStorage,
    history: GeneratedMessageHistory,
) !MessageObservation {
    var message_ids = std.ArrayList(fx.MessageId).empty;
    defer message_ids.deinit(allocator);
    var reply_correlation_ids = std.ArrayList(fx.MessageCorrelationId).empty;
    defer reply_correlation_ids.deinit(allocator);

    for (history.requests) |request| {
        const address = fx.entityAddress("property-message", request.address_key);
        var submitted = try storage.submit(.{
            .shard_id = request.shard_id,
            .now_ms = 10_000 + message_ids.items.len,
            .envelope = .{
                .kind = .request,
                .address = address,
                .idempotency_key = request.idempotency_key,
                .payload_type_name = "text",
                .payload = request.payload,
            },
        });
        defer submitted.deinit(allocator);
        try message_ids.append(allocator, submitted.envelope.id);

        if (request.submit_duplicate) {
            var duplicate = try storage.submit(.{
                .shard_id = request.shard_id,
                .now_ms = 20_000 + message_ids.items.len,
                .envelope = .{
                    .kind = .request,
                    .address = address,
                    .idempotency_key = request.idempotency_key,
                    .payload_type_name = "text",
                    .payload = request.payload,
                },
            });
            defer duplicate.deinit(allocator);
            try std.testing.expect(duplicate.duplicate);
            try std.testing.expectEqual(submitted.envelope.id, duplicate.envelope.id);
        }

        if (request.claim) {
            const claimed = try storage.claim(.{
                .shard_id = request.shard_id,
                .message_id = submitted.envelope.id,
                .now_ms = 30_000 + message_ids.items.len,
            });
            defer fx.deinitMessageEnvelope(allocator, claimed);
            try std.testing.expectEqual(submitted.envelope.id, claimed.id);
        }

        if (request.store_reply) {
            const correlation_id = submitted.envelope.correlation_id.?;
            const stored_reply = try storage.storeReply(.{
                .shard_id = request.shard_id,
                .now_ms = 40_000 + message_ids.items.len,
                .envelope = .{
                    .kind = .reply,
                    .address = address,
                    .correlation_id = correlation_id,
                    .payload_type_name = "text",
                    .payload = request.payload,
                },
            });
            defer fx.deinitMessageEnvelope(allocator, stored_reply);
            try reply_correlation_ids.append(allocator, correlation_id);
        } else if (request.ack) {
            try storage.ack(.{
                .message_id = submitted.envelope.id,
                .now_ms = 50_000 + message_ids.items.len,
            });
        }
    }

    return observeMessageStorage(allocator, storage, message_ids.items, reply_correlation_ids.items);
}

pub fn observeMessageStorage(
    allocator: std.mem.Allocator,
    storage: fx.MessageStorage,
    message_ids: []const fx.MessageId,
    reply_correlation_ids: []const fx.MessageCorrelationId,
) !MessageObservation {
    var unprocessed = std.ArrayList(ObservedMessageRecord).empty;
    errdefer {
        for (unprocessed.items) |*record| {
            record.deinit(allocator);
        }
        unprocessed.deinit(allocator);
    }

    var shard_id: fx.ShardId = 1;
    while (shard_id <= 4) : (shard_id += 1) {
        var by_shard = try storage.unprocessedByShard(shard_id, allocator);
        defer by_shard.deinit();
        for (by_shard.records) |record| {
            try appendObservedRecord(allocator, &unprocessed, record);
        }
    }
    std.mem.sort(ObservedMessageRecord, unprocessed.items, {}, observedRecordLessThan);

    var lookups = std.ArrayList(ObservedMessageLookup).empty;
    errdefer {
        for (lookups.items) |*lookup| {
            lookup.deinit(allocator);
        }
        lookups.deinit(allocator);
    }
    for (message_ids) |message_id| {
        if (try storage.unprocessedById(message_id, allocator)) |record| {
            var owned_record = record;
            defer owned_record.deinit(allocator);
            try lookups.append(allocator, .{
                .message_id = message_id,
                .found = true,
                .status = owned_record.status,
                .attempt = owned_record.envelope.attempt,
                .payload = try copyText(allocator, owned_record.envelope.payload),
            });
        } else {
            try lookups.append(allocator, .{ .message_id = message_id, .found = false });
        }
    }

    var replies = std.ArrayList(ObservedReply).empty;
    errdefer {
        for (replies.items) |*reply| {
            reply.deinit(allocator);
        }
        replies.deinit(allocator);
    }
    for (reply_correlation_ids) |correlation_id| {
        if (try storage.reply(correlation_id, allocator)) |reply| {
            defer fx.deinitMessageEnvelope(allocator, reply);
            try replies.append(allocator, .{
                .correlation_id = correlation_id,
                .found = true,
                .payload = try copyText(allocator, reply.payload),
            });
        } else {
            try replies.append(allocator, .{ .correlation_id = correlation_id, .found = false });
        }
    }

    return .{
        .allocator = allocator,
        .message_ids = try copyIds(fx.MessageId, allocator, message_ids),
        .reply_correlation_ids = try copyIds(fx.MessageCorrelationId, allocator, reply_correlation_ids),
        .unprocessed = try unprocessed.toOwnedSlice(allocator),
        .lookups = try lookups.toOwnedSlice(allocator),
        .replies = try replies.toOwnedSlice(allocator),
    };
}

pub fn expectMessageObservationsEqual(
    expected: *const MessageObservation,
    actual: *const MessageObservation,
) !void {
    try expectIdsEqual(fx.MessageId, expected.message_ids, actual.message_ids);
    try expectIdsEqual(fx.MessageCorrelationId, expected.reply_correlation_ids, actual.reply_correlation_ids);
    try expectRecordsEqual(expected.unprocessed, actual.unprocessed);
    try expectLookupsEqual(expected.lookups, actual.lookups);
    try expectRepliesEqual(expected.replies, actual.replies);
}

fn appendObservedRecord(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(ObservedMessageRecord),
    record: fx.StoredMessageRecord,
) !void {
    try output.append(allocator, .{
        .shard_id = record.shard_id,
        .message_id = record.envelope.id,
        .status = record.status,
        .attempt = record.envelope.attempt,
        .payload = try copyText(allocator, record.envelope.payload),
    });
}

fn observedRecordLessThan(_: void, left: ObservedMessageRecord, right: ObservedMessageRecord) bool {
    if (left.shard_id != right.shard_id) return left.shard_id < right.shard_id;
    return left.message_id < right.message_id;
}

fn expectRecordsEqual(
    expected: []const ObservedMessageRecord,
    actual: []const ObservedMessageRecord,
) !void {
    try std.testing.expectEqual(expected.len, actual.len);
    for (expected, actual) |expected_record, actual_record| {
        try std.testing.expectEqual(expected_record.shard_id, actual_record.shard_id);
        try std.testing.expectEqual(expected_record.message_id, actual_record.message_id);
        try std.testing.expectEqual(expected_record.status, actual_record.status);
        try std.testing.expectEqual(expected_record.attempt, actual_record.attempt);
        try std.testing.expectEqualStrings(expected_record.payload, actual_record.payload);
    }
}

fn expectLookupsEqual(
    expected: []const ObservedMessageLookup,
    actual: []const ObservedMessageLookup,
) !void {
    try std.testing.expectEqual(expected.len, actual.len);
    for (expected, actual) |expected_lookup, actual_lookup| {
        try std.testing.expectEqual(expected_lookup.message_id, actual_lookup.message_id);
        try std.testing.expectEqual(expected_lookup.found, actual_lookup.found);
        if (expected_lookup.found) {
            try std.testing.expectEqual(expected_lookup.status, actual_lookup.status);
            try std.testing.expectEqual(expected_lookup.attempt, actual_lookup.attempt);
            try std.testing.expectEqualStrings(expected_lookup.payload, actual_lookup.payload);
        }
    }
}

fn expectRepliesEqual(
    expected: []const ObservedReply,
    actual: []const ObservedReply,
) !void {
    try std.testing.expectEqual(expected.len, actual.len);
    for (expected, actual) |expected_reply, actual_reply| {
        try std.testing.expectEqual(expected_reply.correlation_id, actual_reply.correlation_id);
        try std.testing.expectEqual(expected_reply.found, actual_reply.found);
        if (expected_reply.found) {
            try std.testing.expectEqualStrings(expected_reply.payload, actual_reply.payload);
        }
    }
}

fn expectIdsEqual(comptime Id: type, expected: []const Id, actual: []const Id) !void {
    try std.testing.expectEqual(expected.len, actual.len);
    for (expected, actual) |expected_id, actual_id| {
        try std.testing.expectEqual(expected_id, actual_id);
    }
}

fn copyText(allocator: std.mem.Allocator, value: []const u8) ![]const u8 {
    if (value.len == 0) return "";
    return allocator.dupe(u8, value);
}

fn copyIds(comptime Id: type, allocator: std.mem.Allocator, values: []const Id) ![]Id {
    const copied = try allocator.alloc(Id, values.len);
    @memcpy(copied, values);
    return copied;
}

fn choice(seed: u64, case_index: usize, salt: usize, modulo: u64) u64 {
    return mix(seed, @as(u64, @intCast(case_index)), @as(u64, @intCast(salt))) % modulo;
}

fn mix(seed: u64, case_index: u64, salt: u64) u64 {
    var value = seed ^ (case_index *% 0x9e3779b97f4a7c15) ^ (salt *% 0xbf58476d1ce4e5b9);
    value = (value ^ (value >> 30)) *% 0xbf58476d1ce4e5b9;
    value = (value ^ (value >> 27)) *% 0x94d049bb133111eb;
    return value ^ (value >> 31);
}
