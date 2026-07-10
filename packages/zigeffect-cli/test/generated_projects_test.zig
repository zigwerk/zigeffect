const std = @import("std");
const cli = @import("zigeffect_cli");

test "every scaffold builds in Debug and ReleaseSafe and system children build independently" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var std_dir = try std.Io.Dir.cwd().openDir(std.testing.io, "../zigeffect-std", .{});
    defer std_dir.close(std.testing.io);
    const std_path = try dirRealPathAlloc(std.testing.allocator, std_dir);
    defer std.testing.allocator.free(std_path);
    var core_dir = try std.Io.Dir.cwd().openDir(std.testing.io, "../zigeffect", .{});
    defer core_dir.close(std.testing.io);
    const core_path = try dirRealPathAlloc(std.testing.allocator, core_dir);
    defer std.testing.allocator.free(core_path);

    const cases = [_]struct {
        kind: cli.zstd.Project.ProjectKind,
        name: []const u8,
    }{
        .{ .kind = .application, .name = "generated-application" },
        .{ .kind = .service, .name = "generated-service" },
        .{ .kind = .library, .name = "generated-library" },
        .{ .kind = .package, .name = "generated-package" },
        .{ .kind = .system, .name = "generated-system" },
    };

    for (cases) |case| {
        try tmp.dir.createDirPath(std.testing.io, case.name);
        var target_dir = try tmp.dir.openDir(std.testing.io, case.name, .{});
        defer target_dir.close(std.testing.io);
        const target_path = try dirRealPathAlloc(std.testing.allocator, target_dir);
        defer std.testing.allocator.free(target_path);
        const std_relative = try std.fs.path.relative(std.testing.allocator, "/", null, target_path, std_path);
        defer std.testing.allocator.free(std_relative);
        const core_relative = try std.fs.path.relative(std.testing.allocator, "/", null, target_path, core_path);
        defer std.testing.allocator.free(core_relative);

        var plan = try cli.generatePlan(std.testing.allocator, .{
            .kind = case.kind,
            .name = case.name,
            .target = case.name,
            .zigeffect_path = core_relative,
            .zigeffect_std_path = std_relative,
        });
        defer plan.deinit();
        _ = try cli.writePlan(std.testing.io, tmp.dir, case.name, plan, .{});

        var compatible = try cli.runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{ "compatibility", "--root", target_path, "--json" });
        defer compatible.deinit();
        try std.testing.expectEqual(@as(u8, 0), compatible.exit_code);
        try std.testing.expect(std.mem.indexOf(u8, compatible.output, "\"compatible\":true") != null);

        var upgrade = try cli.runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{ "upgrade", "--root", target_path, "--dry-run", "--json" });
        defer upgrade.deinit();
        try std.testing.expectEqual(@as(u8, 0), upgrade.exit_code);
        try std.testing.expect(std.mem.indexOf(u8, upgrade.output, "\"status\":\"current\"") != null);

        if (case.kind == .system) {
            var added = try cli.runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{
                "add", "library", "analytics", "--root", target_path, "--json",
            });
            defer added.deinit();
            try std.testing.expectEqual(@as(u8, 0), added.exit_code);
            try std.testing.expect(std.mem.indexOf(u8, added.output, "libraries/analytics/build.zig") != null);

            var generated = try cli.runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{
                "generate", "schema", "invoice", "--component", "api-service", "--root", target_path, "--json",
            });
            defer generated.deinit();
            try std.testing.expectEqual(@as(u8, 0), generated.exit_code);
            try target_dir.access(std.testing.io, "services/api/src/schema/invoice.zig", .{});

            var validated = try cli.runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{
                "project", "validate", "--root", target_path, "--json",
            });
            defer validated.deinit();
            try std.testing.expectEqual(@as(u8, 0), validated.exit_code);
        }

        try runBuild(target_path, "Debug");
        try runBuild(target_path, "ReleaseSafe");
        if (case.kind == .system) {
            for ([_][]const u8{ "services/api", "services/worker", "packages/shared" }) |child| {
                const child_path = try std.fs.path.join(std.testing.allocator, &.{ target_path, child });
                defer std.testing.allocator.free(child_path);
                try runBuild(child_path, "Debug");
            }
            const added_path = try std.fs.path.join(std.testing.allocator, &.{ target_path, "libraries/analytics" });
            defer std.testing.allocator.free(added_path);
            try runBuild(added_path, "Debug");

            var checked = try cli.runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{
                "project", "check", "--root", target_path, "--json",
            });
            defer checked.deinit();
            try std.testing.expectEqual(@as(u8, 0), checked.exit_code);
            try target_dir.access(std.testing.io, ".zigeffect/receipts/check.json", .{});

            var handoff = try cli.runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{
                "agent", "handoff", "--provider", "codex", "--session", "integration-session", "--root", target_path,
            });
            defer handoff.deinit();
            try std.testing.expectEqual(@as(u8, 0), handoff.exit_code);
            try std.testing.expect(std.mem.indexOf(u8, handoff.output, "zigeffect.agent-handoff.v1") != null);
            try target_dir.access(std.testing.io, ".zigeffect/handoffs/latest.json", .{});
        }
    }
}

fn dirRealPathAlloc(allocator: std.mem.Allocator, dir: std.Io.Dir) ![]u8 {
    var buffer: [std.fs.max_path_bytes]u8 = undefined;
    const length = try dir.realPath(std.testing.io, &buffer);
    return allocator.dupe(u8, buffer[0..length]);
}

fn runBuild(cwd: []const u8, optimize: []const u8) !void {
    const optimize_arg = try std.fmt.allocPrint(std.testing.allocator, "-Doptimize={s}", .{optimize});
    defer std.testing.allocator.free(optimize_arg);
    const result = try std.process.run(std.testing.allocator, std.testing.io, .{
        .argv = &.{ "zig", "build", "test", optimize_arg, "--summary", "all" },
        .cwd = .{ .path = cwd },
        .stdout_limit = .limited(4 * 1024 * 1024),
        .stderr_limit = .limited(4 * 1024 * 1024),
    });
    defer std.testing.allocator.free(result.stdout);
    defer std.testing.allocator.free(result.stderr);
    const passed = switch (result.term) {
        .exited => |code| code == 0,
        else => false,
    };
    if (!passed) {
        std.debug.print("generated project failed in {s} ({s})\nstdout:\n{s}\nstderr:\n{s}\n", .{ cwd, optimize, result.stdout, result.stderr });
        return error.GeneratedProjectBuildFailed;
    }
}
