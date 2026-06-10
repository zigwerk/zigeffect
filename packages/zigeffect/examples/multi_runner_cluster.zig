const std = @import("std");
const fx = @import("zigeffect");

const MultiRunnerReport = struct {
    runner_a_shards: usize,
    runner_b_shards: usize,
    runner_a_dispatched: usize,
    runner_b_dispatched: usize,
    runner_a_reply: []const u8,
    runner_b_reply: []const u8,
};

fn runMultiRunnerExample(allocator: std.mem.Allocator, io: std.Io, dir: *std.Io.Dir) !MultiRunnerReport {
    var runner_storage_a = try fx.FileRunnerStorage.open(allocator, io, dir, .{});
    defer runner_storage_a.deinit();
    var runner_storage_b = try fx.FileRunnerStorage.open(allocator, io, dir, .{});
    defer runner_storage_b.deinit();
    var message_storage_a = try fx.FileMessageStorage.open(allocator, io, dir, .{});
    defer message_storage_a.deinit();
    var message_storage_b = try fx.FileMessageStorage.open(allocator, io, dir, .{});
    defer message_storage_b.deinit();
    const shared_messages = message_storage_a.asMessageStorage();

    var runner_a = try fx.LocalClusterRunner.init(allocator, .{
        .runner = fx.runnerAddress("machine-local", "runner-a"),
        .runner_storage = runner_storage_a.asRunnerStorage(),
        .message_storage = message_storage_a.asMessageStorage(),
        .shard_count = 8,
        .runner_index = 0,
        .runner_count = 2,
        .lease_options = .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    });
    defer runner_a.deinit();
    var runner_b = try fx.LocalClusterRunner.init(allocator, .{
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

    const even_address = try addressForShard(0, 8);
    const odd_address = try addressForShard(1, 8);
    _ = try runner_a.registerEntity(.{ .address = even_address, .name = "even-counter" }, 1_000);
    _ = try runner_b.registerEntity(.{ .address = odd_address, .name = "odd-counter" }, 1_000);

    var even_ask = try runner_a.router.routeAsk(even_address, "text", "even-get", "read even");
    defer even_ask.deinit(allocator);
    var odd_ask = try runner_a.router.routeAsk(odd_address, "text", "odd-get", "read odd");
    defer odd_ask.deinit(allocator);

    const Handler = struct {
        pub fn handle(_: *fx.EntityScope, envelope: fx.EntityEnvelope) !fx.EntityHandlerResult {
            if (envelope.kind == .ask) return .{ .reply = "value=ok" };
            return .noreply;
        }
    };

    const report_a = try runner_a.tick(Handler, 1_100);
    const report_b = try runner_b.tick(Handler, 1_100);

    const even_reply = (try shared_messages.reply(even_ask.correlation_id.?, allocator)) orelse return error.ExpectedEvenReply;
    defer fx.deinitMessageEnvelope(allocator, even_reply);
    const odd_reply = (try shared_messages.reply(odd_ask.correlation_id.?, allocator)) orelse return error.ExpectedOddReply;
    defer fx.deinitMessageEnvelope(allocator, odd_reply);

    if (!std.mem.eql(u8, even_reply.payload, "value=ok")) return error.ExpectedEvenReply;
    if (!std.mem.eql(u8, odd_reply.payload, "value=ok")) return error.ExpectedOddReply;

    return .{
        .runner_a_shards = plan_a.shards.len,
        .runner_b_shards = plan_b.shards.len,
        .runner_a_dispatched = report_a.dispatched,
        .runner_b_dispatched = report_b.dispatched,
        .runner_a_reply = "value=ok",
        .runner_b_reply = "value=ok",
    };
}

fn addressForShard(shard_id: fx.ShardId, shard_count: fx.ShardCount) !fx.EntityAddress {
    var index: usize = 0;
    while (index < 10_000) : (index += 1) {
        var key_buf: [32]u8 = undefined;
        const key = try std.fmt.bufPrint(&key_buf, "entity-{d}-{d}", .{ shard_id, index });
        const address = fx.entityAddress("counter", key);
        if (try fx.shardIdForAddress(address, shard_count) == shard_id) return address;
    }
    return error.ShardAddressMissing;
}

pub fn main(init: std.process.Init) !void {
    var cwd = std.Io.Dir.cwd();
    const path = ".zig-cache/zigeffect-examples/multi-runner-cluster";
    try cwd.createDirPath(init.io, path);
    var dir = try cwd.openDir(init.io, path, .{});
    defer dir.close(init.io);

    const report = try runMultiRunnerExample(init.gpa, init.io, &dir);
    std.debug.print(
        "multi-runner cluster: shards={d}/{d} dispatched={d}/{d} replies={s},{s}\n",
        .{
            report.runner_a_shards,
            report.runner_b_shards,
            report.runner_a_dispatched,
            report.runner_b_dispatched,
            report.runner_a_reply,
            report.runner_b_reply,
        },
    );
}

test "multi runner cluster routes messages through shared storage" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const report = try runMultiRunnerExample(std.testing.allocator, std.testing.io, &tmp.dir);
    try std.testing.expectEqual(@as(usize, 4), report.runner_a_shards);
    try std.testing.expectEqual(@as(usize, 4), report.runner_b_shards);
    try std.testing.expectEqual(@as(usize, 1), report.runner_a_dispatched);
    try std.testing.expectEqual(@as(usize, 1), report.runner_b_dispatched);
    try std.testing.expectEqualStrings("value=ok", report.runner_a_reply);
    try std.testing.expectEqualStrings("value=ok", report.runner_b_reply);
}
