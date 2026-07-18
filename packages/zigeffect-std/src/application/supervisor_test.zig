const std = @import("std");
const fx = @import("zigeffect");
const Cli = @import("../cli/root.zig");
const Schema = @import("../schema/root.zig");
const Supervisor = @import("supervisor.zig");

const ProbeApi = struct {
    pub const operations: []const []const u8 = &.{"OneShotProbe.invoke"};
    invocations: *usize,
};

const Probe = fx.kernel.Service("zigeffect/std/test/OneShotProbe", ProbeApi);
const Requirements = .{Probe};

const Handlers = struct {
    fn succeed(ctx: *fx.kernel.ContextView(Requirements), _: Cli.ParsedCommand) anyerror!void {
        ctx.service(Probe).invocations.* += 1;
    }

    fn fail(ctx: *fx.kernel.ContextView(Requirements), _: Cli.ParsedCommand) anyerror!void {
        ctx.service(Probe).invocations.* += 1;
        return error.InjectedCommandFailure;
    }
};

const commands = [_]Cli.CommandSpec{.{
    .name = "status",
    .options = &.{.{ .name = "token", .kind = .string, .env = "COMMAND_TOKEN" }},
}};
const status_path = [_][]const u8{ "zgraphy", "status" };
const success_handlers = [_]Cli.ServiceHandler(Requirements, anyerror){
    .{ .path = status_path[0..], .run = Handlers.succeed },
};
const failure_handlers = [_]Cli.ServiceHandler(Requirements, anyerror){
    .{ .path = status_path[0..], .run = Handlers.fail },
};
const success_application = Cli.ServiceApplication(Requirements, anyerror){
    .spec = .{ .name = "zgraphy", .subcommands = commands[0..] },
    .help = "zgraphy custom help\n",
    .handlers = success_handlers[0..],
};
const failure_application = Cli.ServiceApplication(Requirements, anyerror){
    .spec = .{ .name = "zgraphy", .subcommands = commands[0..] },
    .handlers = failure_handlers[0..],
};

test "runOneShot executes one framework-named service command and checks every lifecycle stage" {
    try std.testing.expect(!@hasDecl(Cli, "CommandIdentity"));
    try std.testing.expect(!@hasDecl(Cli, "ServicePreflight"));
    try std.testing.expect(!@hasDecl(Cli, "ServiceTypedPreflight"));
    try std.testing.expect(!@hasDecl(Cli, "preflightServiceApplication"));
    try std.testing.expect(!@hasDecl(Cli, "preflightServiceTyped"));
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    var causal = fx.CausalStore.init(std.testing.allocator);
    defer causal.deinit();
    var invocations: usize = 0;
    var probe = Supervisor.OneShotOptions.TestProbe{};
    const layer = fx.kernel.Layer.succeed(Probe, ProbeApi{ .invocations = &invocations });
    const result = try Supervisor.runOneShot(
        @TypeOf(layer),
        @TypeOf(success_application),
        std.testing.allocator,
        std.testing.io,
        tmp.dir,
        layer,
        success_application,
        &.{ "status", "--token", "raw-secret-command-name" },
        .{
            .runtime = .{
                .graph = .{ .path = "causal", .max_records = 256 },
                .causal_store = &causal,
            },
            .testing = .{ .probe = &probe },
        },
    );
    _ = result.value.?;

    try std.testing.expectEqual(@as(usize, 1), invocations);
    try expectCompleteProbe(probe, 1);
    var snapshot = try causal.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 1), countEvent(snapshot.events, .effect_started, "status", "running"));
    try std.testing.expectEqual(@as(usize, 1), countEvent(snapshot.events, .effect_completed, "status", "success"));
    try std.testing.expectEqual(@as(usize, 0), countLabelContaining(snapshot.events, "zgraphy status"));
    try std.testing.expectEqual(@as(usize, 0), countLabelContaining(snapshot.events, "raw-secret-command-name"));
}

test "runOneShot public parameters expose no command identity or preflight forgery surface" {
    const function = @typeInfo(@TypeOf(Supervisor.runOneShot)).@"fn";
    try std.testing.expectEqual(@as(usize, 9), function.params.len);
    try std.testing.expect(function.params[0].type.? == type);
    try std.testing.expect(function.params[1].type.? == type);
    try std.testing.expect(function.params[2].type.? == std.mem.Allocator);
    try std.testing.expect(function.params[3].type.? == std.Io);
    try std.testing.expect(function.params[4].type.? == std.Io.Dir);
    try std.testing.expect(function.params[5].type == null);
    try std.testing.expect(function.params[6].type == null);
    try std.testing.expect(function.params[7].type.? == []const []const u8);
    try std.testing.expect(function.params[8].type.? == Supervisor.OneShotOptions);
    inline for (function.params) |parameter| {
        if (parameter.type) |Parameter| {
            try std.testing.expect(!carriesCommandIdentityState(Parameter));
        }
    }
    try std.testing.expect(!carriesCommandIdentityState(@TypeOf(success_application)));
}

test "runOneShot supervisor has one checked shutdown and no deferred deinitialization" {
    const source = try std.Io.Dir.cwd().readFileAlloc(
        std.testing.io,
        "src/application/supervisor.zig",
        std.testing.allocator,
        .limited(256 * 1024),
    );
    defer std.testing.allocator.free(source);
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, source, "runtime.shutdown()"));

    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |line| {
        try std.testing.expect(!(std.mem.indexOf(u8, line, "defer ") != null and std.mem.indexOf(u8, line, ".deinit") != null));
    }
}

test "runOneShot short circuits before runtime construction and repository state" {
    const Case = struct {
        argv: []const []const u8,
        kind: Cli.ShortCircuitKind,
        exit_code: Cli.ExitCode,
    };
    const cases = [_]Case{
        .{ .argv = &.{"--help"}, .kind = .help, .exit_code = .success },
        .{ .argv = &.{"--version"}, .kind = .version, .exit_code = .success },
        .{ .argv = &.{"completions"}, .kind = .completions, .exit_code = .success },
        .{ .argv = &.{"missing"}, .kind = .usage, .exit_code = .usage },
    };

    for (cases) |case| {
        var tmp = std.testing.tmpDir(.{ .iterate = true });
        defer tmp.cleanup();
        var invocations: usize = 0;
        var probe = Supervisor.OneShotOptions.TestProbe{};
        const layer = fx.kernel.Layer.succeed(Probe, ProbeApi{ .invocations = &invocations });
        const result = try Supervisor.runOneShot(
            @TypeOf(layer),
            @TypeOf(success_application),
            std.testing.allocator,
            std.testing.io,
            tmp.dir,
            layer,
            success_application,
            case.argv,
            .{
                .runtime = .{ .graph = .{ .path = ".zgraphy/runtime/causal" } },
                .testing = .{ .probe = &probe, .write_short_circuit = false },
            },
        );

        try std.testing.expectEqual(case.kind, result.short_circuit.?);
        try std.testing.expectEqual(case.exit_code, result.exit_code);
        try std.testing.expect(result.value == null);
        try std.testing.expectEqual(@as(usize, 0), invocations);
        try expectEmptyProbe(probe);
        try std.testing.expectError(error.FileNotFound, tmp.dir.access(std.testing.io, ".zgraphy", .{}));
    }
}

test "runOneShot typed service handler resolves dependencies through ContextView" {
    const Args = struct { workspace: []const u8 };
    const TypedHandler = struct {
        fn run(ctx: *fx.kernel.ContextView(Requirements), args: Args) anyerror!void {
            if (!std.mem.eql(u8, args.workspace, "/repo")) return error.UnexpectedWorkspace;
            ctx.service(Probe).invocations.* += 1;
        }
    };
    const command = Cli.typedCommand(Args, .{ .name = "serve", .version = "0.1.0" }, .{
        Cli.option("workspace", Schema.string().nonEmpty(), .{ .long = "workspace", .required = true }),
    });
    const application = Cli.ServiceTypedApplication(Requirements, Args, anyerror, @TypeOf(command)){
        .command = command,
        .handler = TypedHandler.run,
    };

    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    var invocations: usize = 0;
    var probe = Supervisor.OneShotOptions.TestProbe{};
    const layer = fx.kernel.Layer.succeed(Probe, ProbeApi{ .invocations = &invocations });
    const result = try Supervisor.runOneShot(
        @TypeOf(layer),
        @TypeOf(application),
        std.testing.allocator,
        std.testing.io,
        tmp.dir,
        layer,
        application,
        &.{ "--workspace", "/repo" },
        .{
            .runtime = .{ .graph = .{ .path = "causal", .max_records = 256 } },
            .testing = .{ .probe = &probe },
        },
    );
    _ = result.value.?;
    try std.testing.expectEqual(@as(usize, 1), invocations);
    try expectCompleteProbe(probe, 1);
}

test "runOneShot fault injection preserves shutdown then first-infrastructure then command precedence" {
    const Case = struct {
        faults: Supervisor.OneShotOptions.TestFaults,
        expected: anyerror,
    };
    const cases = [_]Case{
        .{
            .faults = .{
                .drain = error.InjectedDrainFailure,
                .stop = error.InjectedStopFailure,
                .health = error.InjectedHealthFailure,
                .shutdown = error.InjectedShutdownFailure,
            },
            .expected = error.InjectedShutdownFailure,
        },
        .{
            .faults = .{
                .drain = error.InjectedDrainFailure,
                .stop = error.InjectedStopFailure,
                .health = error.InjectedHealthFailure,
            },
            .expected = error.InjectedDrainFailure,
        },
        .{
            .faults = .{
                .stop = error.InjectedStopFailure,
                .health = error.InjectedHealthFailure,
            },
            .expected = error.InjectedStopFailure,
        },
        .{
            .faults = .{
                .inspect = error.InjectedInspectFailure,
                .health = error.InjectedHealthFailure,
            },
            .expected = error.InjectedInspectFailure,
        },
        .{
            .faults = .{ .health = error.InjectedHealthFailure },
            .expected = error.InjectedHealthFailure,
        },
        .{
            .faults = .{},
            .expected = error.InjectedCommandFailure,
        },
    };

    for (cases) |case| try runFailureCase(case.faults, case.expected);
}

test "runOneShot returns a real shutdown flush failure instead of swallowing it" {
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    var causal = fx.CausalStore.init(std.testing.allocator);
    defer causal.deinit();
    var invocations: usize = 0;
    var probe = Supervisor.OneShotOptions.TestProbe{};
    const layer = fx.kernel.Layer.succeed(Probe, ProbeApi{ .invocations = &invocations });
    try std.testing.expectError(error.CausalNendbStorageBackendFull, Supervisor.runOneShot(
        @TypeOf(layer),
        @TypeOf(failure_application),
        std.testing.allocator,
        std.testing.io,
        tmp.dir,
        layer,
        failure_application,
        &.{"status"},
        .{
            .runtime = .{
                .graph = .{ .path = "causal", .max_records = 1 },
                .causal_store = &causal,
            },
            .testing = .{ .probe = &probe },
        },
    ));
    try std.testing.expectEqual(@as(usize, 1), probe.shutdown);
}

test "runOneShot missing required service is a negative compile test" {
    const result = try std.process.run(std.testing.allocator, std.testing.io, .{
        .argv = &.{
            "zig",
            "test",
            "-ODebug",
            "--dep",
            "zigeffect_std",
            "-Mroot=src/application/missing_service_compile_test.zig",
            "--dep",
            "zigeffect",
            "-Mzigeffect_std=src/root.zig",
            "-Mzigeffect=../zigeffect/src/zigeffect.zig",
        },
        .cwd = .inherit,
        .stdout_limit = .limited(64 * 1024),
        .stderr_limit = .limited(64 * 1024),
    });
    defer std.testing.allocator.free(result.stdout);
    defer std.testing.allocator.free(result.stderr);

    switch (result.term) {
        .exited => |code| try std.testing.expect(code != 0),
        else => return error.UnexpectedCompilerTermination,
    }
    try std.testing.expect(std.mem.indexOf(
        u8,
        result.stderr,
        "the handle does not contain every required service",
    ) != null);
}

fn runFailureCase(faults: Supervisor.OneShotOptions.TestFaults, expected: anyerror) !void {
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    var causal = fx.CausalStore.init(std.testing.allocator);
    defer causal.deinit();
    var invocations: usize = 0;
    var probe = Supervisor.OneShotOptions.TestProbe{};
    const layer = fx.kernel.Layer.succeed(Probe, ProbeApi{ .invocations = &invocations });
    if (Supervisor.runOneShot(
        @TypeOf(layer),
        @TypeOf(failure_application),
        std.testing.allocator,
        std.testing.io,
        tmp.dir,
        layer,
        failure_application,
        &.{"status"},
        .{
            .runtime = .{
                .graph = .{ .path = "causal", .max_records = 256 },
                .causal_store = &causal,
            },
            .testing = .{ .faults = faults, .probe = &probe },
        },
    )) |_| {
        return error.ExpectedOneShotFailure;
    } else |failure| {
        try std.testing.expectEqual(expected, failure);
    }
    try expectCompleteProbe(probe, 1);
}

fn carriesCommandIdentityState(comptime Candidate: type) bool {
    switch (@typeInfo(Candidate)) {
        .@"struct" => |info| {
            inline for (info.fields) |field| {
                if (std.mem.eql(u8, field.name, "identity") or
                    std.mem.eql(u8, field.name, "command_identity") or
                    std.mem.eql(u8, field.name, "command_path") or
                    std.mem.eql(u8, field.name, "matched_path") or
                    std.mem.eql(u8, field.name, "path") or
                    std.mem.eql(u8, field.name, "segment_count") or
                    std.mem.eql(u8, field.name, "preflight") or
                    std.mem.eql(u8, field.name, "sealed_command") or
                    std.mem.eql(u8, field.name, "parsed") or
                    std.mem.eql(u8, field.name, "decoded")) return true;
            }
        },
        else => {},
    }
    return false;
}

fn expectEmptyProbe(probe: Supervisor.OneShotOptions.TestProbe) !void {
    try std.testing.expectEqual(@as(usize, 0), probe.start);
    try std.testing.expectEqual(@as(usize, 0), probe.ready);
    try std.testing.expectEqual(@as(usize, 0), probe.command);
    try std.testing.expectEqual(@as(usize, 0), probe.drain);
    try std.testing.expectEqual(@as(usize, 0), probe.stop);
    try std.testing.expectEqual(@as(usize, 0), probe.inspect);
    try std.testing.expectEqual(@as(usize, 0), probe.health);
    try std.testing.expectEqual(@as(usize, 0), probe.shutdown);
}

fn expectCompleteProbe(probe: Supervisor.OneShotOptions.TestProbe, expected_commands: usize) !void {
    try std.testing.expectEqual(@as(usize, 1), probe.start);
    try std.testing.expectEqual(@as(usize, 1), probe.ready);
    try std.testing.expectEqual(expected_commands, probe.command);
    try std.testing.expectEqual(@as(usize, 1), probe.drain);
    try std.testing.expectEqual(@as(usize, 1), probe.stop);
    try std.testing.expectEqual(@as(usize, 1), probe.inspect);
    try std.testing.expectEqual(@as(usize, 1), probe.health);
    try std.testing.expectEqual(@as(usize, 1), probe.shutdown);
}

fn countEvent(
    events: []const fx.CausalEvent,
    kind: fx.CausalEventKind,
    label: []const u8,
    status: []const u8,
) usize {
    var count: usize = 0;
    for (events) |event| {
        if (event.kind == kind and std.mem.eql(u8, event.label, label) and std.mem.eql(u8, event.status, status)) count += 1;
    }
    return count;
}

fn countLabelContaining(events: []const fx.CausalEvent, needle: []const u8) usize {
    var count: usize = 0;
    for (events) |event| {
        if (std.mem.indexOf(u8, event.label, needle) != null) count += 1;
    }
    return count;
}
