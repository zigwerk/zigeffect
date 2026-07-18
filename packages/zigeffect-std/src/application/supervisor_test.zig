const std = @import("std");
const fx = @import("zigeffect");
const Cli = @import("../cli/root.zig");
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
    .handlers = success_handlers[0..],
};
const failure_application = Cli.ServiceApplication(Requirements, anyerror){
    .spec = .{ .name = "zgraphy", .subcommands = commands[0..] },
    .handlers = failure_handlers[0..],
};

test "runOneShot executes one framework-named service command and checks every lifecycle stage" {
    try std.testing.expect(!@hasDecl(Cli, "CommandIdentity"));
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    var causal = fx.CausalStore.init(std.testing.allocator);
    defer causal.deinit();
    var invocations: usize = 0;
    var probe = Supervisor.OneShotOptions.TestProbe{};
    const layer = fx.kernel.Layer.succeed(Probe, ProbeApi{ .invocations = &invocations });
    var preflight = try Cli.preflightServiceApplication(
        Requirements,
        anyerror,
        std.testing.allocator,
        success_application,
        &.{ "status", "--token", "raw-secret-command-name" },
    );
    defer preflight.deinit();
    try std.testing.expect(Cli.isFrameworkServicePreflight(@TypeOf(preflight)));
    try std.testing.expect(!Cli.isFrameworkServicePreflight(struct {
        pub const FrameworkPreflightKind = @TypeOf(preflight).FrameworkPreflightKind;
        pub const RequiredServices = Requirements;
        pub const FailureType = anyerror;
    }));

    const result = try Supervisor.runOneShot(
        @TypeOf(layer),
        @TypeOf(preflight),
        std.testing.allocator,
        std.testing.io,
        tmp.dir,
        layer,
        &preflight,
        .{
            .runtime = .{
                .graph = .{ .path = "causal", .max_records = 256 },
                .causal_store = &causal,
            },
            .testing = .{ .probe = &probe },
        },
    );
    _ = result.value;

    try std.testing.expectEqual(@as(usize, 1), invocations);
    try expectCompleteProbe(probe, 1);
    var snapshot = try causal.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 1), countEvent(snapshot.events, .effect_started, "status", "running"));
    try std.testing.expectEqual(@as(usize, 1), countEvent(snapshot.events, .effect_completed, "status", "success"));
    try std.testing.expectEqual(@as(usize, 0), countLabelContaining(snapshot.events, "zgraphy status"));
    try std.testing.expectEqual(@as(usize, 0), countLabelContaining(snapshot.events, "raw-secret-command-name"));
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
    var preflight = try Cli.preflightServiceApplication(
        Requirements,
        anyerror,
        std.testing.allocator,
        failure_application,
        &.{"status"},
    );
    defer preflight.deinit();

    try std.testing.expectError(error.CausalNendbStorageBackendFull, Supervisor.runOneShot(
        @TypeOf(layer),
        @TypeOf(preflight),
        std.testing.allocator,
        std.testing.io,
        tmp.dir,
        layer,
        &preflight,
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

test "runOneShot exact preflight type cannot forge sealed runnable state" {
    const result = try std.process.run(std.testing.allocator, std.testing.io, .{
        .argv = &.{
            "zig",
            "test",
            "-ODebug",
            "--dep",
            "zigeffect_std",
            "-Mroot=src/application/forged_preflight_compile_test.zig",
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
    try std.testing.expect(std.mem.indexOf(u8, result.stderr, "does not support array initialization syntax") != null);
}

test "an exact hand-constructed preflight without the opaque seal is not runnable" {
    const Preflight = Cli.ServicePreflight(Requirements, anyerror);
    var forged = Preflight{
        .allocator = std.testing.allocator,
        .application = success_application,
    };
    defer forged.deinit();

    try std.testing.expect(!forged.shouldRun());
    try std.testing.expectError(error.InvalidCommandPreflight, forged.prepare());
}

fn runFailureCase(faults: Supervisor.OneShotOptions.TestFaults, expected: anyerror) !void {
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    var causal = fx.CausalStore.init(std.testing.allocator);
    defer causal.deinit();
    var invocations: usize = 0;
    var probe = Supervisor.OneShotOptions.TestProbe{};
    const layer = fx.kernel.Layer.succeed(Probe, ProbeApi{ .invocations = &invocations });
    var preflight = try Cli.preflightServiceApplication(
        Requirements,
        anyerror,
        std.testing.allocator,
        failure_application,
        &.{"status"},
    );
    defer preflight.deinit();

    if (Supervisor.runOneShot(
        @TypeOf(layer),
        @TypeOf(preflight),
        std.testing.allocator,
        std.testing.io,
        tmp.dir,
        layer,
        &preflight,
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
