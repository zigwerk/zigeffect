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
    log_path: ?[:0]const u8 = null,
    estate_scan_executable: ?[:0]const u8 = null,
    estate_connection_id: ?[:0]const u8 = null,
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
    \\  zig build causal-workbench -- --server-only --logs <events.jsonl> <artifact.json>
    \\  zig build causal-workbench -- --server-only --estate-scan <ziac-executable> <connection-id> <artifact.json>
    \\
    ;
}

pub fn parseLaunchArgs(args: []const [:0]const u8) ?LaunchOptions {
    if (args.len < 2) return null;
    var index: usize = 1;
    var mode: LaunchMode = .window;
    if (index < args.len and std.mem.eql(u8, args[index], "--server-only")) {
        mode = .server_only;
        index += 1;
    }
    var log_path: ?[:0]const u8 = null;
    var estate_scan_executable: ?[:0]const u8 = null;
    var estate_connection_id: ?[:0]const u8 = null;
    while (index < args.len and std.mem.startsWith(u8, args[index], "--")) {
        if (std.mem.eql(u8, args[index], "--logs")) {
            if (log_path != null or index + 1 >= args.len) return null;
            log_path = args[index + 1];
            index += 2;
            continue;
        }
        if (std.mem.eql(u8, args[index], "--estate-scan")) {
            if (estate_scan_executable != null or index + 2 >= args.len) return null;
            estate_scan_executable = args[index + 1];
            estate_connection_id = args[index + 2];
            index += 3;
            continue;
        }
        return null;
    }
    if (index + 1 != args.len) return null;
    return .{
        .mode = mode,
        .artifact_path = args[index],
        .log_path = log_path,
        .estate_scan_executable = estate_scan_executable,
        .estate_connection_id = estate_connection_id,
    };
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

test "launch args accept an optional live log snapshot" {
    const args = [_][:0]const u8{
        "zigeffect-causal-workbench",
        "--server-only",
        "--logs",
        ".ziac/logs/global-api/dev/events.jsonl",
        "artifact.json",
    };
    const options = parseLaunchArgs(&args).?;

    try std.testing.expectEqualStrings("artifact.json", options.artifact_path);
    try std.testing.expectEqualStrings(".ziac/logs/global-api/dev/events.jsonl", options.log_path.?);
}

test "launch args accept a fixed Ziac estate scanner command" {
    const args = [_][:0]const u8{
        "zigeffect-causal-workbench",
        "--server-only",
        "--estate-scan",
        "./zig-out/bin/ziac",
        "gcp-connection-17",
        "estate.json",
    };
    const options = parseLaunchArgs(&args).?;

    try std.testing.expectEqualStrings("./zig-out/bin/ziac", options.estate_scan_executable.?);
    try std.testing.expectEqualStrings("gcp-connection-17", options.estate_connection_id.?);
    try std.testing.expectEqualStrings("estate.json", options.artifact_path);
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
