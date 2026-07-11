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
        profile: cli.ScaffoldProfile = .@"local-fake",
    }{
        .{ .kind = .application, .name = "generated-application" },
        .{ .kind = .service, .name = "generated-service" },
        .{ .kind = .library, .name = "generated-library" },
        .{ .kind = .package, .name = "generated-package" },
        .{ .kind = .system, .name = "generated-system" },
        .{ .kind = .application, .name = "gen-int-app", .profile = .@"integration-real" },
        .{ .kind = .application, .name = "gen-prod-app", .profile = .production },
        .{ .kind = .service, .name = "gen-int-svc", .profile = .@"integration-real" },
        .{ .kind = .service, .name = "gen-prod-svc", .profile = .production },
        .{ .kind = .system, .name = "gen-int-system", .profile = .@"integration-real" },
        .{ .kind = .system, .name = "gen-prod-system", .profile = .production },
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
            .profile = case.profile,
        });
        defer plan.deinit();
        _ = try cli.writePlan(std.testing.io, tmp.dir, case.name, plan, .{});
        if (case.kind == .application and case.profile == .@"local-fake") try installGeneratedPatternMatrix(target_dir);

        var compatible = try cli.runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{ "compatibility", "--root", target_path, "--json" });
        defer compatible.deinit();
        try std.testing.expectEqual(@as(u8, 0), compatible.exit_code);
        try std.testing.expect(std.mem.indexOf(u8, compatible.output, "\"compatible\":true") != null);

        var upgrade = try cli.runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{ "upgrade", "--root", target_path, "--dry-run", "--json" });
        defer upgrade.deinit();
        try std.testing.expectEqual(@as(u8, 0), upgrade.exit_code);
        try std.testing.expect(std.mem.indexOf(u8, upgrade.output, "\"status\":\"current\"") != null);

        if (case.kind == .system and case.profile == .@"local-fake") {
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
        if ((case.kind == .application or case.kind == .service) and case.profile == .@"local-fake") {
            try runProject(target_path);
            var graph = try cli.runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{
                "graph", "status", "--root", target_path, "--json",
            });
            defer graph.deinit();
            try std.testing.expectEqual(@as(u8, 0), graph.exit_code);
            try std.testing.expect(std.mem.indexOf(u8, graph.output, "\"records\":") != null);
            try target_dir.access(std.testing.io, ".zigeffect/graph/causal-graph.jsonl", .{});
        }
        if (case.kind == .system) {
            for ([_][]const u8{ "services/api", "services/worker", "packages/shared" }) |child| {
                const child_path = try std.fs.path.join(std.testing.allocator, &.{ target_path, child });
                defer std.testing.allocator.free(child_path);
                try runBuild(child_path, "Debug");
                try runBuild(child_path, "ReleaseSafe");
            }
            if (case.profile == .@"local-fake") {
                for ([_]struct { path: []const u8, id: []const u8 }{
                .{ .path = "services/api", .id = "api-service" },
                .{ .path = "services/worker", .id = "worker-service" },
                }) |service| {
                const service_path = try std.fs.path.join(std.testing.allocator, &.{ target_path, service.path });
                defer std.testing.allocator.free(service_path);
                try runProject(service_path);
                var graph = try cli.runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{
                    "graph", "status", "--root", target_path, "--component", service.id, "--json",
                });
                defer graph.deinit();
                try std.testing.expectEqual(@as(u8, 0), graph.exit_code);
                try std.testing.expect(std.mem.indexOf(u8, graph.output, "\"records\":") != null);
                const wal_path = try std.fmt.allocPrint(std.testing.allocator, "{s}/.zigeffect/graph/causal-graph.jsonl", .{service.path});
                defer std.testing.allocator.free(wal_path);
                try target_dir.access(std.testing.io, wal_path, .{});
                }
            }
            if (case.profile == .@"local-fake") {
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
}

fn installGeneratedPatternMatrix(target_dir: std.Io.Dir) !void {
    try target_dir.createDirPath(std.testing.io, "src/statecharts");
    var imports = std.ArrayList(u8).empty;
    defer imports.deinit(std.testing.allocator);
    inline for (std.meta.tags(cli.zstd.Statechart.Plan.PatternKind)) |kind| {
        const namespace = try std.fmt.allocPrint(std.testing.allocator, "pattern.{s}", .{@tagName(kind)});
        defer std.testing.allocator.free(namespace);
        var expansion = try cli.zstd.Statechart.Plan.expandPattern(std.testing.allocator, kind, namespace);
        defer expansion.deinit();
        const workflow_plan = cli.zstd.Statechart.Plan.WorkflowPlan{
            .schema = cli.zstd.Statechart.Plan.workflow_plan_schema,
            .schema_version = cli.zstd.Statechart.Plan.workflow_plan_schema_version,
            .id = namespace,
            .version = 1,
            .initial = expansion.states[0].id,
            .states = expansion.states,
            .transitions = expansion.transitions,
            .invariants = expansion.invariants,
        };
        const source = try cli.zstd.Statechart.Plan.generateZig(std.testing.allocator, workflow_plan);
        defer std.testing.allocator.free(source);
        const path = try std.fmt.allocPrint(std.testing.allocator, "src/statecharts/{s}.zig", .{@tagName(kind)});
        defer std.testing.allocator.free(path);
        try target_dir.writeFile(std.testing.io, .{ .sub_path = path, .data = source });
        try imports.print(std.testing.allocator, "const pattern_{s} = @import(\"statecharts/{s}.zig\");\ncomptime {{ @setEvalBranchQuota(10_000); _ = pattern_{s}.definition.fingerprint(); }}\n", .{ @tagName(kind), @tagName(kind), @tagName(kind) });
    }
    var authored_states = [_]cli.zstd.Statechart.Plan.PlanState{
        .{ .id = "idle" }, .{ .id = "reviewing" }, .{ .id = "done", .kind = .final },
    };
    var authored_transitions = [_]cli.zstd.Statechart.Plan.PlanTransition{
        .{ .id = "begin", .source = "idle", .event = "begin", .target = "reviewing", .guard = "has-input", .actions = &.{"begin-review"} },
        .{ .id = "finish", .source = "reviewing", .event = "finish", .target = "done" },
    };
    const authored_plan = cli.zstd.Statechart.Plan.WorkflowPlan{
        .schema = cli.zstd.Statechart.Plan.workflow_plan_schema,
        .schema_version = cli.zstd.Statechart.Plan.workflow_plan_schema_version,
        .id = "agent.authored-review",
        .version = 1,
        .initial = "idle",
        .states = &authored_states,
        .transitions = &authored_transitions,
    };
    const authored_source = try cli.zstd.Statechart.Plan.generateZig(std.testing.allocator, authored_plan);
    defer std.testing.allocator.free(authored_source);
    try target_dir.writeFile(std.testing.io, .{ .sub_path = "src/statecharts/authored_review.zig", .data = authored_source });
    try imports.appendSlice(std.testing.allocator, "const authored_review = @import(\"statecharts/authored_review.zig\");\ncomptime { @setEvalBranchQuota(10_000); _ = authored_review.definition.fingerprint(); }\n");
    const root = try target_dir.readFileAlloc(std.testing.io, "src/app.zig", std.testing.allocator, .limited(4 * 1024 * 1024));
    defer std.testing.allocator.free(root);
    const updated = try std.fmt.allocPrint(std.testing.allocator, "{s}\n{s}", .{ root, imports.items });
    defer std.testing.allocator.free(updated);
    try target_dir.writeFile(std.testing.io, .{ .sub_path = "src/app.zig", .data = updated });
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
    try expectV2Receipt(cwd, optimize);
    const compile = try std.process.run(std.testing.allocator, std.testing.io, .{
        .argv = &.{ "zig", "build", optimize_arg, "--summary", "all" },
        .cwd = .{ .path = cwd },
        .stdout_limit = .limited(4 * 1024 * 1024),
        .stderr_limit = .limited(4 * 1024 * 1024),
    });
    defer std.testing.allocator.free(compile.stdout);
    defer std.testing.allocator.free(compile.stderr);
    const compiled = switch (compile.term) { .exited => |code| code == 0, else => false };
    if (!compiled) {
        std.debug.print("generated executable failed in {s} ({s})\nstdout:\n{s}\nstderr:\n{s}\n", .{ cwd, optimize, compile.stdout, compile.stderr });
        return error.GeneratedProjectBuildFailed;
    }
}

fn expectV2Receipt(cwd: []const u8, optimize: []const u8) !void {
    const suites_path = try std.fs.path.join(std.testing.allocator, &.{ cwd, ".zigeffect/tests/suites" });
    defer std.testing.allocator.free(suites_path);
    var suites = try std.Io.Dir.cwd().openDir(std.testing.io, suites_path, .{ .iterate = true });
    defer suites.close(std.testing.io);
    var iterator = suites.iterate();
    var receipt_count: usize = 0;
    while (try iterator.next(std.testing.io)) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".json")) continue;
        const bytes = try suites.readFileAlloc(std.testing.io, entry.name, std.testing.allocator, .limited(16 * 1024 * 1024));
        defer std.testing.allocator.free(bytes);
        var receipt = try cli.zstd.Testing.SuiteReceipt.parse(std.testing.allocator, bytes);
        defer receipt.deinit();
        try std.testing.expect(receipt.value.complete);
        try std.testing.expectEqual(cli.zstd.Testing.SuiteReceipt.Status.passed, receipt.value.status);
        try std.testing.expectEqualStrings(optimize, receipt.value.execution.optimize);
        receipt_count += 1;
    }
    try std.testing.expect(receipt_count > 0);
}

fn runProject(cwd: []const u8) !void {
    const result = try std.process.run(std.testing.allocator, std.testing.io, .{
        .argv = &.{ "zig", "build", "run", "--summary", "all" },
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
        std.debug.print("generated project run failed in {s}\nstdout:\n{s}\nstderr:\n{s}\n", .{ cwd, result.stdout, result.stderr });
        return error.GeneratedProjectRunFailed;
    }
}
