//! Low-level causal graph backend fixture; not application scaffolding.
//! Canonical applications receive embedded NenDB automatically from
//! `zstd.ManagedRuntime` and never attach this backend themselves.

const std = @import("std");
const zstd = @import("zigeffect_std");

fn recordExample(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    path: []const u8,
) !void {
    var database = try zstd.CausalGraph.LocalDatabase.init(allocator, io, root, .{ .path = path });
    defer database.deinit();
    var backend = database.storageBackend(allocator, 32);
    defer backend.deinit();
    var store = zstd.fx.CausalStore.init(allocator);
    defer store.deinit();
    store.attachBackend(backend.backend());

    const started = try store.record(.{
        .kind = .effect_started,
        .label = "causal-graph-example",
        .status = "running",
    });
    _ = try store.record(.{
        .kind = .effect_completed,
        .parent_id = started,
        .label = "causal-graph-example",
        .status = "success",
    });
    try backend.flush();
    if (store.backendFailureCount() != 0) return error.GraphWriteFailed;
}

pub fn main(init: std.process.Init) !void {
    const path = ".zig-cache/zigeffect-causal-graph-example";
    try recordExample(init.gpa, init.io, std.Io.Dir.cwd(), path);
    var snapshot = try zstd.CausalGraph.Snapshot.open(init.gpa, init.io, std.Io.Dir.cwd(), .{ .path = path });
    defer snapshot.deinit();
    const json = try snapshot.summaryJsonAlloc(init.gpa);
    defer init.gpa.free(json);
    try std.Io.File.stdout().writeStreamingAll(init.io, json);
    try std.Io.File.stdout().writeStreamingAll(init.io, "\n");
}

test "example persists a queryable causal graph" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try recordExample(std.testing.allocator, std.testing.io, tmp.dir, "graph");
    var snapshot = try zstd.CausalGraph.Snapshot.open(std.testing.allocator, std.testing.io, tmp.dir, .{ .path = "graph" });
    defer snapshot.deinit();
    const summary = snapshot.summary();
    try std.testing.expectEqual(@as(usize, 2), summary.records);
    try std.testing.expectEqual(@as(usize, 1), summary.edges);
    const children = try snapshot.childrenAlloc(std.testing.allocator, 1);
    defer std.testing.allocator.free(children);
    try std.testing.expectEqualSlices(u64, &.{2}, children);
}
