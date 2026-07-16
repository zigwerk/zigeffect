const std = @import("std");
const zstd = @import("zigeffect_std");
const fx = zstd.fx;

const Probe = struct {
    attempts: usize = 0,
    acquired: usize = 0,
    released: usize = 0,
    fail_next: bool = false,
    fail_attempt: ?usize = null,
};

const ProbeApi = struct {
    state: *Probe,
};

const ProbeService = fx.kernel.Service("test/effect-reference/Probe", ProbeApi);

const Item = struct {
    id: usize,
    probe: *Probe,
};

const AcquireError = error{AcquireFailed};

fn acquireItem(ctx: *fx.kernel.ContextView(.{ProbeService})) AcquireError!Item {
    const probe = ctx.service(ProbeService).state;
    probe.attempts += 1;
    if (probe.fail_next or probe.fail_attempt == probe.attempts) {
        probe.fail_next = false;
        return error.AcquireFailed;
    }
    probe.acquired += 1;
    return .{ .id = probe.acquired, .probe = probe };
}

fn releaseItem(item: *Item) void {
    item.probe.released += 1;
}

const Refreshable = zstd.Resource.Service(
    "test/effect-reference/Refreshable",
    Item,
    AcquireError,
    .{ProbeService},
    acquireItem,
    releaseItem,
);

const ItemPool = zstd.Pool.Service(
    "test/effect-reference/Pool",
    Item,
    AcquireError,
    .{ProbeService},
    acquireItem,
    releaseItem,
    .{
        .min_size = 1,
        .max_size = 2,
        .concurrency_per_item = 1,
        .time_to_live_ms = 10,
        .time_to_live_strategy = .idle,
    },
);

const FailingPreallocatedPool = zstd.Pool.Service(
    "test/effect-reference/FailingPreallocatedPool",
    Item,
    AcquireError,
    .{ProbeService},
    acquireItem,
    releaseItem,
    .{
        .min_size = 2,
        .max_size = 2,
    },
);

fn itemId(item: *Item) usize {
    return item.id;
}

fn ignorePair(_: anytype) void {}

fn hasEvent(snapshot: anytype, kind: fx.CausalEventKind, service_key: []const u8, label: []const u8) bool {
    for (snapshot.events) |event| {
        if (event.kind != kind) continue;
        if (!std.mem.eql(u8, event.service_key, service_key)) continue;
        if (!std.mem.eql(u8, event.label, label)) continue;
        return true;
    }
    return false;
}

fn hasServiceOperation(snapshot: anytype, service_key: []const u8, operation: []const u8) bool {
    for (snapshot.services) |service| {
        if (!std.mem.eql(u8, service.key, service_key)) continue;
        for (service.operations) |candidate| {
            if (std.mem.eql(u8, candidate, operation)) return true;
        }
    }
    return false;
}

test "refreshable Resource swaps successful acquisitions and preserves the last value on failure" {
    var probe = Probe{};
    const root = Refreshable.DefaultWithoutDependencies().provide(
        fx.kernel.Layer.succeed(ProbeService, .{ .state = &probe }),
    );
    var causal = fx.CausalStore.init(std.testing.allocator);
    defer causal.deinit();
    var runtime = try fx.kernel.ManagedRuntime(@TypeOf(root)).make(
        std.testing.allocator,
        root,
        .{ .causal_store = &causal },
    );

    try std.testing.expectEqual(@as(usize, 1), probe.acquired);
    try std.testing.expectEqual(@as(usize, 1), (try runtime.run(zstd.Resource.get(Refreshable))).id);

    try runtime.run(zstd.Resource.refresh(Refreshable));
    try std.testing.expectEqual(@as(usize, 2), (try runtime.run(zstd.Resource.get(Refreshable))).id);
    try std.testing.expectEqual(@as(usize, 1), probe.released);

    probe.fail_next = true;
    try std.testing.expectError(error.AcquireFailed, runtime.run(zstd.Resource.refresh(Refreshable)));
    try std.testing.expectEqual(@as(usize, 2), (try runtime.run(zstd.Resource.get(Refreshable))).id);
    try std.testing.expectEqual(@as(usize, 1), probe.released);

    var snapshot = try causal.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expect(hasEvent(snapshot, .io_wait_started, Refreshable.service_key, "Resource.refresh"));
    try std.testing.expect(hasEvent(snapshot, .resource_finalized, "", ""));

    var application = try runtime.inspect(std.testing.allocator, .{ .max_recent_events = 16 });
    defer application.deinit();
    try std.testing.expect(hasServiceOperation(application, Refreshable.service_key, "Resource.get"));
    try std.testing.expect(hasServiceOperation(application, Refreshable.service_key, "Resource.refresh"));

    runtime.deinit();
    try std.testing.expectEqual(@as(usize, 2), probe.released);
    runtime.deinit();
    try std.testing.expectEqual(@as(usize, 2), probe.released);
}

test "Pool bounds scoped reuse invalidation TTL and failed acquisition recovery" {
    var probe = Probe{};
    const root = ItemPool.DefaultWithoutDependencies().provide(
        fx.kernel.Layer.succeed(ProbeService, .{ .state = &probe }),
    );
    var causal = fx.CausalStore.init(std.testing.allocator);
    defer causal.deinit();
    var runtime = try fx.kernel.ManagedRuntime(@TypeOf(root)).make(
        std.testing.allocator,
        root,
        .{ .causal_store = &causal },
    );

    try std.testing.expectEqual(@as(usize, 1), probe.acquired);
    const first = try runtime.run(zstd.Pool.get(ItemPool));
    const first_id = first.id;
    try std.testing.expectEqual(first_id, try runtime.run(zstd.Pool.get(ItemPool).map(itemId)));

    try runtime.run(zstd.Pool.invalidate(ItemPool, first));
    const replacement_id = try runtime.run(zstd.Pool.get(ItemPool).map(itemId));
    try std.testing.expect(replacement_id != first_id);
    try std.testing.expectEqual(@as(usize, 1), probe.released);

    var clock = fx.kernel.Clock.fake(100);
    const pair = zstd.Pool.get(ItemPool).zip(zstd.Pool.get(ItemPool)).map(ignorePair).withClock(&clock);
    try runtime.run(pair);
    var stats = try runtime.run(zstd.Pool.stats(ItemPool));
    try std.testing.expectEqual(@as(usize, 2), stats.size);
    try std.testing.expectEqual(@as(usize, 0), stats.borrowed);

    clock.sleep(11);
    try runtime.run(zstd.Pool.prune(ItemPool).withClock(&clock));
    stats = try runtime.run(zstd.Pool.stats(ItemPool));
    try std.testing.expectEqual(@as(usize, 1), stats.size);

    probe.fail_next = true;
    const failing_pair = zstd.Pool.get(ItemPool).zip(zstd.Pool.get(ItemPool)).map(ignorePair);
    try std.testing.expectError(error.AcquireFailed, runtime.run(failing_pair));
    stats = try runtime.run(zstd.Pool.stats(ItemPool));
    try std.testing.expectEqual(@as(usize, 1), stats.size);
    try std.testing.expectEqual(@as(usize, 0), stats.pending_creations);

    try runtime.run(zstd.Pool.get(ItemPool).zip(zstd.Pool.get(ItemPool)).map(ignorePair));
    stats = try runtime.run(zstd.Pool.stats(ItemPool));
    try std.testing.expectEqual(@as(usize, 2), stats.size);
    try std.testing.expectEqual(@as(usize, 0), stats.borrowed);

    const exhausted = zstd.Pool.get(ItemPool)
        .zip(zstd.Pool.get(ItemPool))
        .zip(zstd.Pool.get(ItemPool));
    try std.testing.expectError(error.PoolExhausted, runtime.run(exhausted));
    stats = try runtime.run(zstd.Pool.stats(ItemPool));
    try std.testing.expectEqual(@as(usize, 2), stats.size);
    try std.testing.expectEqual(@as(usize, 0), stats.borrowed);

    var snapshot = try causal.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expect(hasEvent(snapshot, .io_wait_started, ItemPool.service_key, "Pool.get"));

    var application = try runtime.inspect(std.testing.allocator, .{ .max_recent_events = 16 });
    defer application.deinit();
    try std.testing.expect(hasServiceOperation(application, ItemPool.service_key, "Pool.get"));
    try std.testing.expect(hasServiceOperation(application, ItemPool.service_key, "Pool.invalidate"));

    runtime.deinit();
    try std.testing.expectEqual(probe.acquired, probe.released);
}

test "Pool unwinds partial preallocation when a later acquisition fails" {
    var probe = Probe{ .fail_attempt = 2 };
    const root = FailingPreallocatedPool.DefaultWithoutDependencies().provide(
        fx.kernel.Layer.succeed(ProbeService, .{ .state = &probe }),
    );
    try std.testing.expectError(
        error.AcquireFailed,
        fx.kernel.ManagedRuntime(@TypeOf(root)).make(std.testing.allocator, root, .{}),
    );
    try std.testing.expectEqual(@as(usize, 1), probe.acquired);
    try std.testing.expectEqual(@as(usize, 1), probe.released);
}

test "Resource and Pool release every partial allocation" {
    const Harness = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var probe = Probe{};
            const probe_layer = fx.kernel.Layer.succeed(ProbeService, .{ .state = &probe });
            const resource_layer = Refreshable.DefaultWithoutDependencies().provide(probe_layer);
            const pool_layer = ItemPool.DefaultWithoutDependencies().provide(probe_layer);
            const root = resource_layer.merge(pool_layer);

            // Causal recording deliberately degrades rather than propagating
            // allocation failures. Keep its allocator stable so this harness
            // targets the Resource/Pool ownership paths, whose OOM channel is
            // required to propagate.
            var causal = fx.CausalStore.init(std.testing.allocator);
            defer causal.deinit();
            var runtime = try fx.kernel.ManagedRuntime(@TypeOf(root)).make(
                allocator,
                root,
                .{ .causal_store = &causal },
            );
            defer runtime.deinit();
            try runtime.run(zstd.Resource.refresh(Refreshable));
            _ = try runtime.run(zstd.Pool.get(ItemPool).map(itemId));
            runtime.deinit();
            if (probe.acquired != probe.released) return error.UnbalancedResourceLifecycle;
        }
    };

    try std.testing.checkAllAllocationFailures(std.testing.allocator, Harness.run, .{});
}
