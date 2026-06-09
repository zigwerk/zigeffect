const std = @import("std");

pub const workbench_schema = "zigeffect.causal.workbench-session.v1";
pub const default_workbench_root = "workbench/dist";
pub const default_index_path = "workbench/dist/index.html";
pub const max_artifact_bytes: usize = 4 * 1024 * 1024;
pub const supported_causal_schema = "zigeffect.causal.v1";
pub const supported_causal_schema_version: u32 = 1;
pub const supported_event_taxonomy_version: u32 = 1;

pub const LaunchMode = enum {
    window,
    server_only,
};

pub const LaunchOptions = struct {
    mode: LaunchMode,
    artifact_path: [:0]const u8,
};

pub const SessionOptions = struct {
    artifact_path: []const u8,
    artifact_bytes: usize,
};

pub fn usage() []const u8 {
    return
        \\usage:
        \\  zig build causal-workbench -- <artifact.json>
        \\  zig build causal-workbench -- --server-only <artifact.json>
        \\
    ;
}

pub fn parseLaunchArgs(args: []const [:0]const u8) ?LaunchOptions {
    if (args.len == 2) {
        return .{
            .mode = .window,
            .artifact_path = args[1],
        };
    }

    if (args.len == 3 and std.mem.eql(u8, args[1], "--server-only")) {
        return .{
            .mode = .server_only,
            .artifact_path = args[2],
        };
    }

    return null;
}

pub fn formatSessionJson(allocator: std.mem.Allocator, options: SessionOptions) ![]u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\"schema\":");
    try appendJsonString(allocator, &output, workbench_schema);
    try output.appendSlice(allocator, ",\"read_only\":true");
    try output.appendSlice(allocator, ",\"artifact_path\":");
    try appendJsonString(allocator, &output, options.artifact_path);
    try output.print(allocator, ",\"artifact_bytes\":{d}", .{options.artifact_bytes});
    try output.appendSlice(allocator, ",\"workbench_root\":");
    try appendJsonString(allocator, &output, default_workbench_root);
    try output.appendSlice(allocator, ",\"index_path\":");
    try appendJsonString(allocator, &output, default_index_path);
    try output.appendSlice(allocator, ",\"max_artifact_bytes\":");
    try output.print(allocator, "{d}", .{max_artifact_bytes});
    try output.appendSlice(allocator, ",\"supported\":{\"causal_schema\":");
    try appendJsonString(allocator, &output, supported_causal_schema);
    try output.print(
        allocator,
        ",\"causal_schema_version\":{d},\"event_taxonomy_version\":{d}",
        .{ supported_causal_schema_version, supported_event_taxonomy_version },
    );
    try output.appendSlice(allocator, "},\"warnings\":[]}");

    return output.toOwnedSlice(allocator);
}

pub fn readArtifactBounded(
    io: std.Io,
    allocator: std.mem.Allocator,
    dir: std.Io.Dir,
    path: []const u8,
) ![]u8 {
    const stat = try dir.statFile(io, path, .{});
    if (stat.size > max_artifact_bytes) return error.CausalWorkbenchArtifactTooLarge;

    return dir.readFileAlloc(io, path, allocator, .limited(max_artifact_bytes + 1)) catch |err| switch (err) {
        error.StreamTooLong => error.CausalWorkbenchArtifactTooLarge,
        else => err,
    };
}

fn appendJsonString(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: []const u8) !void {
    try output.append(allocator, '"');
    for (value) |byte| switch (byte) {
        '"' => try output.appendSlice(allocator, "\\\""),
        '\\' => try output.appendSlice(allocator, "\\\\"),
        '\n' => try output.appendSlice(allocator, "\\n"),
        '\r' => try output.appendSlice(allocator, "\\r"),
        '\t' => try output.appendSlice(allocator, "\\t"),
        else => try output.append(allocator, byte),
    };
    try output.append(allocator, '"');
}

test "workbench usage names the launcher command" {
    try std.testing.expect(std.mem.indexOf(u8, usage(), "zig build causal-workbench -- <artifact.json>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage(), "--server-only") != null);
}

test "launch args default to window mode" {
    const args = [_][:0]const u8{ "zigeffect-causal-workbench", "artifact.json" };
    const options = parseLaunchArgs(&args).?;

    try std.testing.expectEqual(LaunchMode.window, options.mode);
    try std.testing.expectEqualStrings("artifact.json", options.artifact_path);
}

test "launch args accept explicit server-only mode" {
    const args = [_][:0]const u8{ "zigeffect-causal-workbench", "--server-only", "artifact.json" };
    const options = parseLaunchArgs(&args).?;

    try std.testing.expectEqual(LaunchMode.server_only, options.mode);
    try std.testing.expectEqualStrings("artifact.json", options.artifact_path);
}

test "launch args reject unknown shapes" {
    const missing = [_][:0]const u8{"zigeffect-causal-workbench"};
    const unknown_flag = [_][:0]const u8{ "zigeffect-causal-workbench", "--browser", "artifact.json" };
    const too_many = [_][:0]const u8{ "zigeffect-causal-workbench", "--server-only", "artifact.json", "extra.json" };

    try std.testing.expect(parseLaunchArgs(&missing) == null);
    try std.testing.expect(parseLaunchArgs(&unknown_flag) == null);
    try std.testing.expect(parseLaunchArgs(&too_many) == null);
}

test "workbench constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.workbench-session.v1", workbench_schema);
    try std.testing.expectEqualStrings("workbench/dist", default_workbench_root);
    try std.testing.expectEqualStrings("workbench/dist/index.html", default_index_path);
    try std.testing.expectEqual(@as(usize, 4 * 1024 * 1024), max_artifact_bytes);
}

test "session json records read-only artifact metadata" {
    const session = try formatSessionJson(std.testing.allocator, .{
        .artifact_path = ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.json",
        .artifact_bytes = 128,
    });
    defer std.testing.allocator.free(session);

    try std.testing.expect(std.mem.indexOf(u8, session, "\"schema\":\"zigeffect.causal.workbench-session.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, session, "\"read_only\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, session, "\"artifact_path\":\".zig-cache/causal-artifacts/zigeffect-causal-dogfood.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, session, "\"artifact_bytes\":128") != null);
    try std.testing.expect(std.mem.indexOf(u8, session, "\"workbench_root\":\"workbench/dist\"") != null);
}

test "session json escapes artifact path" {
    const session = try formatSessionJson(std.testing.allocator, .{
        .artifact_path = "artifact\"with\\quotes.json",
        .artifact_bytes = 10,
    });
    defer std.testing.allocator.free(session);

    try std.testing.expect(std.mem.indexOf(u8, session, "artifact\\\"with\\\\quotes.json") != null);
}

test "bounded artifact read rejects oversized files before full read" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = "oversized.json";
    {
        const file = try tmp.dir.createFile(std.testing.io, path, .{});
        defer file.close(std.testing.io);
        try file.writePositionalAll(std.testing.io, "x", max_artifact_bytes);
    }

    try std.testing.expectError(
        error.CausalWorkbenchArtifactTooLarge,
        readArtifactBounded(std.testing.io, std.testing.allocator, tmp.dir, path),
    );
}
