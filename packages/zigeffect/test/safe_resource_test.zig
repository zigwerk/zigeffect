const std = @import("std");
const fx = @import("zigeffect");

const Resource = struct {
    value: u32,
    releases: *usize,
};

fn releaseResource(resource: *Resource) void {
    resource.releases.* += 1;
}

fn readResource(resource: *Resource) u32 {
    return resource.value;
}

fn incrementResource(resource: *Resource) error{TooLarge}!u32 {
    if (resource.value == std.math.maxInt(u32)) return error.TooLarge;
    resource.value += 1;
    return resource.value;
}

test "ResourceTable detects foreign stale and double-close handles" {
    var releases: usize = 0;
    var table = fx.ResourceTable(Resource).init(std.testing.allocator, releaseResource);
    defer table.deinit();
    var other = fx.ResourceTable(Resource).init(std.testing.allocator, releaseResource);
    defer other.deinit();

    const first = try table.open(.{ .value = 41, .releases = &releases }, null);
    try std.testing.expectEqual(@as(u32, 41), try table.with(first, readResource));
    try std.testing.expectEqual(@as(u32, 42), try table.with(first, incrementResource));
    try std.testing.expectError(error.ForeignHandle, other.with(first, readResource));
    try table.close(first, null);
    try std.testing.expectEqual(@as(usize, 1), releases);
    try std.testing.expectError(error.StaleHandle, table.with(first, readResource));
    try std.testing.expectError(error.StaleHandle, table.close(first, null));

    const second = try table.open(.{ .value = 7, .releases = &releases }, null);
    try std.testing.expectEqual(first.slot, second.slot);
    try std.testing.expect(first.generation != second.generation);
    try std.testing.expectEqual(@as(u32, 7), try table.with(second, readResource));
}

test "ResourceTable closes live resources on deinit and records source-linked causal lifecycle" {
    var releases: usize = 0;
    var source_map = fx.SourceMap.init(std.testing.allocator, .{});
    defer source_map.deinit();
    const acquired_source = try source_map.registerBuiltin("app", "sha256:revision", @src());
    const finalized_source = try source_map.register(.{
        .component = "app",
        .file = "src/main.zig",
        .declaration = "shutdown",
        .line = 20,
        .column = 4,
        .fingerprint = "sha256:finalizer",
        .source_digest = "sha256:revision",
    });

    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    var table = fx.ResourceTable(Resource).init(std.testing.allocator, releaseResource);
    table.attachCausal(&store, 11, 22);
    const handle = try table.open(.{ .value = 9, .releases = &releases }, acquired_source);
    try table.close(handle, finalized_source);
    table.deinit();

    try std.testing.expectEqual(@as(usize, 1), releases);
    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 2), snapshot.events.len);
    try std.testing.expectEqual(fx.CausalEventKind.resource_acquired, snapshot.events[0].kind);
    try std.testing.expectEqual(fx.CausalEventKind.resource_finalized, snapshot.events[1].kind);
    try std.testing.expectEqual(@as(?u64, acquired_source), snapshot.events[0].source_ref_id);
    try std.testing.expectEqual(@as(?u64, finalized_source), snapshot.events[1].source_ref_id);
    try std.testing.expectEqual(snapshot.events[0].resource_id, snapshot.events[1].resource_id);
}

test "agent sendable accepts value messages and generational handles" {
    const Message = struct {
        id: u64,
        status: enum { ready, done },
        values: [3]u16,
        handle: fx.ResourceHandle(u32),
    };
    comptime fx.assertAgentSendable(Message);
    try std.testing.expect(fx.isAgentSendable(Message));
    try std.testing.expect(!fx.isAgentSendable([]const u8));
    try std.testing.expect(!fx.isAgentSendable(struct { allocator: std.mem.Allocator }));
}
