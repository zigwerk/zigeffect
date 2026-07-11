const std = @import("std");
const redis = @import("zigeffect_redis");
const options = @import("live_options");

const LiveClient = struct {
    password: []u8,
    client: redis.Client,

    fn init(namespace: []const u8) !LiveClient {
        const password = try std.process.Environ.getAlloc(std.testing.environ, std.testing.allocator, "ZIGEFFECT_TEST_REDIS_PASSWORD");
        return .{ .password = password, .client = try redis.Client.init(std.testing.allocator, std.testing.io, .{ .host = options.host, .port = options.port, .namespace = namespace, .password = password }) };
    }

    fn deinit(self: *LiveClient) void {
        std.crypto.secureZero(u8, self.password);
        std.testing.allocator.free(self.password);
    }
};

test "live password-authenticated Redis cache contract" {
    var live = try LiveClient.init("zigeffect-conformance");
    defer live.deinit();
    const client = &live.client;
    _ = client.delete("key") catch {};
    _ = client.delete("ttl") catch {};
    try redis.zstd.Cache.conform(client.asCache(), std.testing.allocator);
    _ = try client.set("ttl", "value", .{ .ttl_ms = 5 });
    try (std.Io.Clock.Duration{ .raw = .fromMilliseconds(10), .clock = .awake }).sleep(std.testing.io);
    try std.testing.expect((try client.getAlloc(std.testing.allocator, "ttl")) == null);
}

test "live password-authenticated Redis Streams broker contract" {
    var live = try LiveClient.init("zigeffect-broker-conformance");
    defer live.deinit();
    try redis.zstd.Broker.conform(live.client.asBroker(), std.testing.allocator);
}

test "live Redis delayed nack returns immediately and redelivers after server deadline" {
    var live = try LiveClient.init("zigeffect-delayed-conformance");
    defer live.deinit();
    const client = &live.client;
    _ = try client.publish(.{ .subject = "orders", .payload = "delayed", .idempotency_key = "delayed-one" });
    var first = (try client.pollAlloc(std.testing.allocator, "orders", "worker-a", 1000)).?;
    defer first.deinit();
    const started = std.Io.Clock.awake.now(std.testing.io);
    try client.nack(first.id, "worker-a", 80);
    const elapsed_ns = started.durationTo(std.Io.Clock.awake.now(std.testing.io)).nanoseconds;
    try std.testing.expect(elapsed_ns < 60 * std.time.ns_per_ms);
    try std.testing.expect((try client.pollAlloc(std.testing.allocator, "orders", "worker-b", 1000)) == null);
    try (std.Io.Clock.Duration{ .raw = .fromMilliseconds(100), .clock = .awake }).sleep(std.testing.io);
    var redelivered = (try client.pollAlloc(std.testing.allocator, "orders", "worker-b", 1000)).?;
    defer redelivered.deinit();
    try std.testing.expectEqual(@as(u32, 2), redelivered.attempt);
    try std.testing.expectEqualStrings("delayed", redelivered.payload);
    try client.ack(redelivered.id, "worker-b");
}

test "live password-authenticated Redis rate limit and pubsub" {
    var live = try LiveClient.init("zigeffect-extra-conformance");
    defer live.deinit();
    const client = &live.client;
    try std.testing.expect(try client.allowRate("api", 1, 1000));
    try std.testing.expect(!try client.allowRate("api", 1, 1000));
    const Context = struct {
        client: *redis.Client,
        message: ?[]u8 = null,
        failure: ?anyerror = null,
        fn run(self: *@This()) void { self.message = self.client.receiveChannelAlloc(std.testing.allocator, "events") catch |err| { self.failure = err; return; }; }
    };
    var context = Context{ .client = client };
    const thread = try std.Thread.spawn(.{}, Context.run, .{&context});
    var subscribers: usize = 0;
    for (0..100) |_| {
        subscribers = try client.publishChannel("events", "ready");
        if (subscribers == 1) break;
        try (std.Io.Clock.Duration{ .raw = .fromMilliseconds(2), .clock = .awake }).sleep(std.testing.io);
    }
    try std.testing.expectEqual(@as(usize, 1), subscribers);
    thread.join();
    if (context.failure) |err| return err;
    defer std.testing.allocator.free(context.message.?);
    try std.testing.expectEqualStrings("ready", context.message.?);
}

test "live Redis rejects an invalid password" {
    var invalid = try redis.Client.init(std.testing.allocator, std.testing.io, .{ .host = options.host, .port = options.port, .namespace = "zigeffect-invalid-auth", .password = "not-the-runtime-credential" });
    try std.testing.expectError(error.RedisCommandFailed, invalid.getAlloc(std.testing.allocator, "key"));
}
