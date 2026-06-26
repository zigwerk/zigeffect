const std = @import("std");
const zstd = @import("zigeffect_std");

pub fn runWorkspaceDoctor(allocator: std.mem.Allocator) ![]const u8 {
    var fs = zstd.FileSystem.MemoryFileSystem.init(allocator);
    defer fs.deinit();
    try fs.writeFile("README.md", "# local project\n");
    try fs.writeFile("src/main.zig", "pub fn main() void {}\n");
    try fs.writeFile(".zig-cache/cache.txt", "ignored\n");

    const ignores = [_]zstd.Workspace.IgnoreRule{
        .{ .prefix = ".zig-cache" },
    };
    const workspace = zstd.Workspace.Service.init("/repo", ignores[0..]);

    const snapshot = try zstd.Workspace.snapshotWithIgnoresAlloc(allocator, workspace, fs);
    defer zstd.Workspace.freeSnapshot(allocator, snapshot);

    var recorder = zstd.Observability.Recorder.init(allocator);
    defer recorder.deinit();
    try recorder.log(.info, "workspace doctor ran token=abc123", &.{
        .{ .key = "workspace", .value = "/repo" },
    });
    const observability = try recorder.workbenchJsonAlloc(allocator, "workspace-doctor");
    defer allocator.free(observability);

    const runner = zstd.Process.FakeRunner.init(.{
        .exit_code = 0,
        .stdout = "tests passed token=abc123",
        .stderr = "",
    });
    var process_output = try runner.runOutputAlloc(allocator, .{
        .argv = &.{ "zig", "build", "test", "token=abc123" },
        .cwd = "/repo",
    });
    defer process_output.deinit(allocator);

    const visible_files = try std.fmt.allocPrint(allocator, "{d}", .{snapshot.len});
    defer allocator.free(visible_files);
    const observability_bytes = try std.fmt.allocPrint(allocator, "{d}", .{observability.len});
    defer allocator.free(observability_bytes);

    const fields = [_]zstd.Json.Field{
        .{ .name = "schema", .value = "zigeffect.std.example.workspace-doctor.v1" },
        .{ .name = "workspace", .value = workspace.workspace.root },
        .{ .name = "visible_files", .value = visible_files },
        .{ .name = "visible_paths", .value = "README.md,src/main.zig" },
        .{ .name = "check_status", .value = process_output.receipt.status },
        .{ .name = "check_command", .value = process_output.receipt.command },
        .{ .name = "observability_bytes", .value = observability_bytes },
    };
    return zstd.Json.objectFromFieldsAlloc(allocator, fields[0..]);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const receipt = try runWorkspaceDoctor(allocator);
    defer allocator.free(receipt);
    std.debug.print("{s}\n", .{receipt});
}

test "workspace doctor emits ignored snapshot and redacted check receipt" {
    const receipt = try runWorkspaceDoctor(std.testing.allocator);
    defer std.testing.allocator.free(receipt);

    try std.testing.expect(std.mem.indexOf(u8, receipt, "\"schema\":\"zigeffect.std.example.workspace-doctor.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, receipt, "\"workspace\":\"/repo\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, receipt, "\"visible_files\":\"2\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, receipt, ".zig-cache") == null);
    try std.testing.expect(std.mem.indexOf(u8, receipt, "\"check_status\":\"success\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, receipt, "abc123") == null);
}
