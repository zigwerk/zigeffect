const std = @import("std");
const fx = @import("zigeffect");

test "local cluster public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "local_cluster"));
    try std.testing.expect(@hasDecl(fx.cluster, "LocalClusterError"));
    try std.testing.expect(@hasDecl(fx.cluster, "ShardBalancePlan"));
    try std.testing.expect(@hasDecl(fx.cluster, "LocalClusterRouter"));
    try std.testing.expect(@hasDecl(fx.cluster, "LocalClusterRouteResult"));
    try std.testing.expect(@hasDecl(fx.cluster, "LocalClusterRunnerOptions"));
    try std.testing.expect(@hasDecl(fx.cluster, "LocalClusterRunner"));
    try std.testing.expect(@hasDecl(fx.cluster, "LocalClusterRunnerReport"));
    try std.testing.expect(@hasDecl(fx.cluster, "ShardRecoveryPlan"));
    try std.testing.expect(@hasDecl(fx.cluster, "balancedShardPlan"));
    try std.testing.expect(@hasDecl(fx, "LocalClusterRunner"));
}

test "balanced shard plan splits shards by runner index" {
    var even = try fx.balancedShardPlan(std.testing.allocator, 8, 0, 2);
    defer even.deinit();
    var odd = try fx.balancedShardPlan(std.testing.allocator, 8, 1, 2);
    defer odd.deinit();

    try std.testing.expectEqualSlices(fx.ShardId, &.{ 0, 2, 4, 6 }, even.shards);
    try std.testing.expectEqualSlices(fx.ShardId, &.{ 1, 3, 5, 7 }, odd.shards);
}

test "balanced shard plan validates shard and runner counts" {
    try std.testing.expectError(error.InvalidShardCount, fx.balancedShardPlan(std.testing.allocator, 0, 0, 2));
    try std.testing.expectError(error.InvalidRunnerCount, fx.balancedShardPlan(std.testing.allocator, 8, 0, 0));
    try std.testing.expectError(error.InvalidRunnerIndex, fx.balancedShardPlan(std.testing.allocator, 8, 2, 2));
}

test "local cluster router writes tell and ask messages to shared file storage" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var message_storage_state = try fx.FileMessageStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer message_storage_state.deinit();
    const message_storage = message_storage_state.asMessageStorage();

    var router = fx.LocalClusterRouter.init(std.testing.allocator, message_storage, .{ .shard_count = 16 });
    const address = fx.entityAddress("counter", "router-shared");
    const shard_id = try fx.shardIdForAddress(address, 16);

    var tell = try router.routeTell(address, "text", "inc", "first command");
    defer tell.deinit(std.testing.allocator);
    try std.testing.expectEqual(shard_id, tell.shard_id);
    try std.testing.expectEqual(fx.MessageEnvelopeKind.tell, tell.envelope.kind);
    try std.testing.expect(!tell.duplicate);

    var ask = try router.routeAsk(address, "text", "get", "read current value");
    defer ask.deinit(std.testing.allocator);
    try std.testing.expectEqual(shard_id, ask.shard_id);
    try std.testing.expectEqual(fx.MessageEnvelopeKind.request, ask.envelope.kind);
    try std.testing.expect(ask.correlation_id != null);

    var by_shard = try message_storage.unprocessedByShard(shard_id, std.testing.allocator);
    defer by_shard.deinit();
    try std.testing.expectEqual(@as(usize, 2), by_shard.records.len);
    var saw_tell = false;
    var saw_request = false;
    for (by_shard.records) |record| {
        if (record.envelope.kind == .tell) saw_tell = true;
        if (record.envelope.kind == .request) saw_request = true;
    }
    try std.testing.expect(saw_tell);
    try std.testing.expect(saw_request);
}

test "two local cluster runners split shards and process routed file-backed messages" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var runner_storage_a = try fx.FileRunnerStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer runner_storage_a.deinit();
    var runner_storage_b = try fx.FileRunnerStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer runner_storage_b.deinit();
    var message_storage_a = try fx.FileMessageStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer message_storage_a.deinit();
    var message_storage_b = try fx.FileMessageStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer message_storage_b.deinit();
    const shared_messages = message_storage_a.asMessageStorage();

    var runner_a = try fx.LocalClusterRunner.init(std.testing.allocator, .{
        .runner = fx.runnerAddress("machine-local", "runner-a"),
        .runner_storage = runner_storage_a.asRunnerStorage(),
        .message_storage = message_storage_a.asMessageStorage(),
        .shard_count = 8,
        .runner_index = 0,
        .runner_count = 2,
        .lease_options = .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    });
    defer runner_a.deinit();
    var runner_b = try fx.LocalClusterRunner.init(std.testing.allocator, .{
        .runner = fx.runnerAddress("machine-local", "runner-b"),
        .runner_storage = runner_storage_b.asRunnerStorage(),
        .message_storage = message_storage_b.asMessageStorage(),
        .shard_count = 8,
        .runner_index = 1,
        .runner_count = 2,
        .lease_options = .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    });
    defer runner_b.deinit();

    var plan_a = try runner_a.acquireBalancedShards(1_000);
    defer plan_a.deinit();
    var plan_b = try runner_b.acquireBalancedShards(1_000);
    defer plan_b.deinit();
    try std.testing.expectEqualSlices(fx.ShardId, &.{ 0, 2, 4, 6 }, plan_a.shards);
    try std.testing.expectEqualSlices(fx.ShardId, &.{ 1, 3, 5, 7 }, plan_b.shards);

    const even_address = try addressForShard(0, 8);
    const odd_address = try addressForShard(1, 8);
    _ = try runner_a.registerEntity(.{ .address = even_address, .name = "even" }, 1_000);
    _ = try runner_b.registerEntity(.{ .address = odd_address, .name = "odd" }, 1_000);

    var seen_a = std.ArrayList([]u8).empty;
    defer {
        for (seen_a.items) |item| std.testing.allocator.free(item);
        seen_a.deinit(std.testing.allocator);
    }
    var seen_b = std.ArrayList([]u8).empty;
    defer {
        for (seen_b.items) |item| std.testing.allocator.free(item);
        seen_b.deinit(std.testing.allocator);
    }
    try (try runner_a.entityScope(even_address)).provideService("seen", &seen_a);
    try (try runner_b.entityScope(odd_address)).provideService("seen", &seen_b);

    var even_ask = try runner_a.router.routeAsk(even_address, "text", "even-get", "read even");
    defer even_ask.deinit(std.testing.allocator);
    var odd_ask = try runner_a.router.routeAsk(odd_address, "text", "odd-get", "read odd");
    defer odd_ask.deinit(std.testing.allocator);

    const Handler = struct {
        pub fn handle(entity_scope: *fx.EntityScope, envelope: fx.EntityEnvelope) !fx.EntityHandlerResult {
            const raw = (try entity_scope.service("seen")).?;
            const seen_messages: *std.ArrayList([]u8) = @ptrCast(@alignCast(raw));
            const owned_payload = try std.testing.allocator.dupe(u8, envelope.payload);
            errdefer std.testing.allocator.free(owned_payload);
            try seen_messages.append(std.testing.allocator, owned_payload);
            if (envelope.kind == .ask) return .{ .reply = "value=ok" };
            return .noreply;
        }
    };

    const report_a = try runner_a.tick(Handler, 1_100);
    const report_b = try runner_b.tick(Handler, 1_100);
    try std.testing.expectEqual(@as(usize, 1), report_a.dispatched);
    try std.testing.expectEqual(@as(usize, 1), report_b.dispatched);
    try std.testing.expectEqualStrings("even-get", seen_a.items[0]);
    try std.testing.expectEqualStrings("odd-get", seen_b.items[0]);

    const even_reply = (try shared_messages.reply(even_ask.correlation_id.?, std.testing.allocator)).?;
    defer fx.deinitMessageEnvelope(std.testing.allocator, even_reply);
    const odd_reply = (try shared_messages.reply(odd_ask.correlation_id.?, std.testing.allocator)).?;
    defer fx.deinitMessageEnvelope(std.testing.allocator, odd_reply);
    try std.testing.expectEqualStrings("value=ok", even_reply.payload);
    try std.testing.expectEqualStrings("value=ok", odd_reply.payload);
}

test "survivor runner recovers dead runner shards and processes pre-death messages" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var runner_storage_a = try fx.FileRunnerStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer runner_storage_a.deinit();
    var runner_storage_b = try fx.FileRunnerStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer runner_storage_b.deinit();
    var message_storage_a = try fx.FileMessageStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer message_storage_a.deinit();
    var message_storage_b = try fx.FileMessageStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer message_storage_b.deinit();
    const shared_messages = message_storage_a.asMessageStorage();

    const dead_runner = fx.runnerAddress("machine-local", "runner-a");
    const survivor_runner = fx.runnerAddress("machine-local", "runner-b");
    var registry = fx.LocalRunnerRegistry.init(std.testing.allocator);
    defer registry.deinit();
    _ = try registry.registerRunner(.{ .address = dead_runner, .name = "runner-a", .started_at_ms = 1_000 });
    _ = try registry.registerRunner(.{ .address = survivor_runner, .name = "runner-b", .started_at_ms = 1_000 });
    _ = try registry.recordHeartbeat(.{ .address = dead_runner, .sequence = 1, .observed_at_ms = 1_050 });
    _ = try registry.recordHeartbeat(.{ .address = survivor_runner, .sequence = 1, .observed_at_ms = 1_050 });
    const inspector = try fx.LocalRunnerHealthInspector.init(.{ .degraded_after_ms = 100, .unhealthy_after_ms = 300 });

    var runner_a = try fx.LocalClusterRunner.init(std.testing.allocator, .{
        .runner = dead_runner,
        .runner_storage = runner_storage_a.asRunnerStorage(),
        .message_storage = message_storage_a.asMessageStorage(),
        .shard_count = 8,
        .runner_index = 0,
        .runner_count = 2,
        .lease_options = .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    });
    defer runner_a.deinit();
    var runner_b = try fx.LocalClusterRunner.init(std.testing.allocator, .{
        .runner = survivor_runner,
        .runner_storage = runner_storage_b.asRunnerStorage(),
        .message_storage = message_storage_b.asMessageStorage(),
        .shard_count = 8,
        .runner_index = 1,
        .runner_count = 2,
        .lease_options = .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    });
    defer runner_b.deinit();

    var plan_a = try runner_a.acquireBalancedShards(1_000);
    defer plan_a.deinit();
    var plan_b = try runner_b.acquireBalancedShards(1_000);
    defer plan_b.deinit();

    const recovered_address = try addressForShard(0, 8);
    var routed = try runner_b.router.routeAsk(recovered_address, "text", "recover-get", "read after recovery");
    defer routed.deinit(std.testing.allocator);
    _ = try runner_b.registerEntity(.{ .address = recovered_address, .name = "recovered" }, 1_000);
    var seen = std.ArrayList([]u8).empty;
    defer {
        for (seen.items) |item| std.testing.allocator.free(item);
        seen.deinit(std.testing.allocator);
    }
    try (try runner_b.entityScope(recovered_address)).provideService("seen", &seen);

    var recovery = try runner_b.recoverDeadRunner(&registry, &inspector, dead_runner, 1_400);
    defer recovery.deinit();
    try std.testing.expectEqualSlices(fx.ShardId, &.{ 0, 2, 4, 6 }, recovery.shards);
    try std.testing.expectEqual(@as(usize, 4), recovery.released);
    try std.testing.expectEqual(@as(usize, 4), recovery.acquired);

    const Handler = struct {
        pub fn handle(entity_scope: *fx.EntityScope, envelope: fx.EntityEnvelope) !fx.EntityHandlerResult {
            const raw = (try entity_scope.service("seen")).?;
            const seen_messages: *std.ArrayList([]u8) = @ptrCast(@alignCast(raw));
            const owned_payload = try std.testing.allocator.dupe(u8, envelope.payload);
            errdefer std.testing.allocator.free(owned_payload);
            try seen_messages.append(std.testing.allocator, owned_payload);
            if (envelope.kind == .ask) return .{ .reply = "value=recovered" };
            return .noreply;
        }
    };

    const report = try runner_b.tick(Handler, 1_401);
    try std.testing.expectEqual(@as(usize, 1), report.dispatched);
    try std.testing.expectEqualStrings("recover-get", seen.items[0]);

    const reply = (try shared_messages.reply(routed.correlation_id.?, std.testing.allocator)).?;
    defer fx.deinitMessageEnvelope(std.testing.allocator, reply);
    try std.testing.expectEqualStrings("value=recovered", reply.payload);
}

fn addressForShard(shard_id: fx.ShardId, shard_count: fx.ShardCount) !fx.EntityAddress {
    var index: usize = 0;
    while (index < 10_000) : (index += 1) {
        var key_buf: [32]u8 = undefined;
        const key = try std.fmt.bufPrint(&key_buf, "entity-{d}-{d}", .{ shard_id, index });
        const address = fx.entityAddress("counter", key);
        if (try fx.shardIdForAddress(address, shard_count) == shard_id) return address;
    }
    return error.ShardAddressNotFound;
}
