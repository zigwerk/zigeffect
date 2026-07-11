const std = @import("std");
const fx = @import("zigeffect");

test "source map assigns stable ids deduplicates and resolves source references" {
    var map = fx.SourceMap.init(std.testing.allocator, .{});
    defer map.deinit();

    const input = fx.SourceRefInput{
        .component = "api",
        .file = "src/main.zig",
        .declaration = "run",
        .line = 12,
        .column = 7,
        .fingerprint = "sha256:0123456789abcdef",
        .source_digest = "sha256:abcdef0123456789",
    };
    const first = try map.register(input);
    const duplicate = try map.register(input);
    const second = try map.register(.{
        .component = "api",
        .file = "src/main.zig",
        .declaration = "run",
        .line = 13,
        .column = 7,
        .fingerprint = "sha256:1111111111111111",
        .source_digest = "sha256:abcdef0123456789",
    });

    try std.testing.expectEqual(first, duplicate);
    try std.testing.expect(first != second);
    try std.testing.expectEqual(@as(usize, 2), map.entries.items.len);
    const resolved = map.resolve(first).?;
    try std.testing.expectEqualStrings("api", resolved.component);
    try std.testing.expectEqualStrings("src/main.zig", resolved.file);
    try std.testing.expectEqualStrings("run", resolved.declaration);
    try std.testing.expectEqual(@as(u32, 12), resolved.line);
}

test "source map is bounded redacts sensitive fields and formats deterministic JSON" {
    var map = fx.SourceMap.init(std.testing.allocator, .{ .max_entries = 1, .max_field_bytes = 96 });
    defer map.deinit();

    const id = try map.register(.{
        .component = "api",
        .file = "src/token=sentinel-secret-for-tests.zig",
        .declaration = "authorization: Bearer sentinel-secret-for-tests",
        .line = 2,
        .column = 1,
        .fingerprint = "sha256:0123456789abcdef",
        .source_digest = "sha256:abcdef0123456789",
    });
    try std.testing.expectError(error.SourceMapFull, map.register(.{
        .component = "api",
        .file = "src/other.zig",
        .declaration = "run",
        .line = 1,
        .column = 1,
        .fingerprint = "sha256:1111111111111111",
        .source_digest = "sha256:2222222222222222",
    }));

    const resolved = map.resolve(id).?;
    try std.testing.expect(std.mem.indexOf(u8, resolved.file, "sentinel-secret") == null);
    try std.testing.expect(std.mem.indexOf(u8, resolved.declaration, "sentinel-secret") == null);

    const first = try fx.formatSourceMapJson(std.testing.allocator, &map);
    defer std.testing.allocator.free(first);
    const second = try fx.formatSourceMapJson(std.testing.allocator, &map);
    defer std.testing.allocator.free(second);
    try std.testing.expectEqualStrings(first, second);
    try std.testing.expect(std.mem.indexOf(u8, first, fx.source_map_schema) != null);
    try std.testing.expect(std.mem.indexOf(u8, first, "sentinel-secret") == null);
    try std.testing.expect(std.mem.indexOf(u8, first, "<redacted>") != null);
}

test "causal events preserve source reference ids in snapshots and JSON" {
    var map = fx.SourceMap.init(std.testing.allocator, .{});
    defer map.deinit();
    const source_ref_id = try map.registerBuiltin("api", "sha256:revision", @src());

    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    _ = try store.record(.{
        .kind = .resource_acquired,
        .resource_id = 1,
        .type_name = "database",
        .source_ref_id = source_ref_id,
    });

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(?u64, source_ref_id), snapshot.events[0].source_ref_id);
    try std.testing.expectEqualStrings("api", fx.resolveEventSource(&map, snapshot.events[0]).?.component);

    const json = try fx.formatCausalJson(std.testing.allocator, &store);
    defer std.testing.allocator.free(json);
    const expected = try std.fmt.allocPrint(std.testing.allocator, "\"source_ref_id\": {d}", .{source_ref_id});
    defer std.testing.allocator.free(expected);
    try std.testing.expect(std.mem.indexOf(u8, json, expected) != null);

    const line = try fx.formatCausalJsonLine(std.testing.allocator, snapshot.events[0]);
    defer std.testing.allocator.free(line);
    const compact_expected = try std.fmt.allocPrint(std.testing.allocator, "\"source_ref_id\":{d}", .{source_ref_id});
    defer std.testing.allocator.free(compact_expected);
    try std.testing.expect(std.mem.indexOf(u8, line, compact_expected) != null);
}

test "source map releases every partial entry and JSON allocation" {
    const Harness = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var map = fx.SourceMap.init(allocator, .{});
            defer map.deinit();
            _ = try map.register(.{
                .component = "api",
                .file = "src/main.zig",
                .declaration = "run",
                .line = 1,
                .column = 1,
                .fingerprint = "sha256:0123456789abcdef",
                .source_digest = "sha256:abcdef0123456789",
            });
            const json = try fx.formatSourceMapJson(allocator, &map);
            defer allocator.free(json);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Harness.run, .{});
}
