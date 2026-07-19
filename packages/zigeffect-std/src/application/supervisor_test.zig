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

const GuardIdentityHandoff = struct {
    bytes: [128]u8,
    len: u8,
};

const GuardPayloadWrapper = struct {
    payload: ?*const union(enum) {
        none: void,
        value: GuardIdentityHandoff,
    },
};

const GuardNestedFieldWrapper = struct {
    payload: union(enum) {
        none: void,
        value: struct { preflight: usize },
    },
};

const GuardSafeWrapper = struct {
    payload: ?*const union(enum) {
        none: void,
        value: usize,
    },
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
    const factory = Supervisor.fixedResources(tmp.dir, layer);
    const result = try Supervisor.runOneShot(
        @TypeOf(factory),
        @TypeOf(success_application),
        std.testing.allocator,
        std.testing.io,
        factory,
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

test "runOneShot public parameters expose no command identity, root, or preflight forgery surface" {
    const function = @typeInfo(@TypeOf(Supervisor.runOneShot)).@"fn";
    try std.testing.expectEqual(@as(usize, 8), function.params.len);
    try std.testing.expect(function.params[0].type.? == type); // comptime ResourceFactory
    try std.testing.expect(function.params[1].type.? == type); // comptime ServiceApp
    try std.testing.expect(function.params[2].type.? == std.mem.Allocator);
    try std.testing.expect(function.params[3].type.? == std.Io);
    try std.testing.expect(function.params[4].type == null); // resource_factory: ResourceFactory
    try std.testing.expect(function.params[5].type == null); // application: ServiceApp
    try std.testing.expect(function.params[6].type.? == []const []const u8);
    try std.testing.expect(function.params[7].type.? == Supervisor.OneShotOptions);

    // No parameter is a raw root directory or eager application layer any more.
    // Root and layer authority is derived solely from the factory result.
    inline for (function.params) |param| {
        if (param.type) |ParamType| try std.testing.expect(ParamType != std.Io.Dir);
    }

    // The only accepted acquisition result carries exactly root, layer, and
    // ownership — no identity, handler, effect, outcome, or runtime authority.
    const Resources = Supervisor.CommandResources(@TypeOf(fx.kernel.Layer.empty()));
    const resources_info = @typeInfo(Resources).@"struct";
    try std.testing.expectEqual(@as(usize, 3), resources_info.fields.len);
    try std.testing.expectEqualStrings("root", resources_info.fields[0].name);
    try std.testing.expectEqualStrings("layer", resources_info.fields[1].name);
    try std.testing.expectEqualStrings("ownership", resources_info.fields[2].name);
    try std.testing.expect(resources_info.fields[0].type == std.Io.Dir);
    const ownership_info = @typeInfo(resources_info.fields[2].type).@"enum";
    try std.testing.expectEqual(@as(usize, 2), ownership_info.fields.len);
    try std.testing.expectEqualStrings("borrowed", ownership_info.fields[0].name);
    try std.testing.expectEqualStrings("close_directory", ownership_info.fields[1].name);

    // Mutation matrix: identity/handoff/preflight shaped payloads are detected,
    // ordinary payloads are not. A forged resource result that injects command
    // identity is rejected at compile time by the negative compile test below.
    try std.testing.expect(carriesCommandIdentityState(GuardPayloadWrapper));
    try std.testing.expect(carriesCommandIdentityState(GuardNestedFieldWrapper));
    try std.testing.expect(!carriesCommandIdentityState(GuardSafeWrapper));
}

test "runOneShot supervisor has one checked shutdown and no deferred deinitialization" {
    const source = try readSupervisorSource();
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
        const factory = Supervisor.fixedResources(tmp.dir, layer);
        const result = try Supervisor.runOneShot(
            @TypeOf(factory),
            @TypeOf(success_application),
            std.testing.allocator,
            std.testing.io,
            factory,
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
    const factory = Supervisor.fixedResources(tmp.dir, layer);
    const result = try Supervisor.runOneShot(
        @TypeOf(factory),
        @TypeOf(application),
        std.testing.allocator,
        std.testing.io,
        factory,
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
    const factory = Supervisor.fixedResources(tmp.dir, layer);
    try std.testing.expectError(error.CausalNendbStorageBackendFull, Supervisor.runOneShot(
        @TypeOf(factory),
        @TypeOf(failure_application),
        std.testing.allocator,
        std.testing.io,
        factory,
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
    // Even on the shutdown-flush failure path the resources are released once.
    try std.testing.expectEqual(@as(usize, 1), probe.acquire);
    try std.testing.expectEqual(@as(usize, 1), probe.release);
}

test "runOneShot acquires once and releases once after a runtime construction failure" {
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    var invocations: usize = 0;
    var probe = Supervisor.OneShotOptions.TestProbe{};
    const layer = fx.kernel.Layer.succeed(Probe, ProbeApi{ .invocations = &invocations });
    const factory = Supervisor.fixedResources(tmp.dir, layer);
    try std.testing.expectError(error.InjectedRuntimeMakeFailure, Supervisor.runOneShot(
        @TypeOf(factory),
        @TypeOf(success_application),
        std.testing.allocator,
        std.testing.io,
        factory,
        success_application,
        &.{"status"},
        .{
            .runtime = .{ .graph = .{ .path = "causal", .max_records = 256 } },
            .testing = .{
                .probe = &probe,
                .faults = .{ .make = error.InjectedRuntimeMakeFailure },
            },
        },
    ));
    // Acquired once, released once, and no runtime lifecycle work ran: the
    // runtime-construction failure outranks command work that never started.
    try std.testing.expectEqual(@as(usize, 1), probe.acquire);
    try std.testing.expectEqual(@as(usize, 1), probe.release);
    try std.testing.expectEqual(@as(usize, 0), probe.start);
    try std.testing.expectEqual(@as(usize, 0), probe.command);
    try std.testing.expectEqual(@as(usize, 0), probe.shutdown);
    try std.testing.expectEqual(@as(usize, 0), invocations);
}

test "runOneShot lets a factory self-clean a partial acquisition without a framework release" {
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    var invocations: usize = 0;
    var probe = Supervisor.OneShotOptions.TestProbe{};
    const layer = fx.kernel.Layer.succeed(Probe, ProbeApi{ .invocations = &invocations });

    var cleaned = false;
    // A factory that opens a real directory, then fails acquisition. It must
    // close its own partial resource before returning the error.
    const PartialFactory = struct {
        const Self = @This();
        pub const LayerType = @TypeOf(layer);
        root: std.Io.Dir,
        layer: @TypeOf(layer),
        cleaned: *bool,

        pub fn acquire(
            self: Self,
            allocator: std.mem.Allocator,
            io: std.Io,
            parsed: Cli.ParsedCommand,
        ) anyerror!Supervisor.CommandResources(@TypeOf(layer)) {
            _ = allocator;
            _ = parsed;
            var partial = try self.root.openDir(io, ".", .{ .iterate = true, .follow_symlinks = false });
            partial.close(io);
            self.cleaned.* = true;
            return error.InjectedAcquireFailure;
        }
    };
    const factory = PartialFactory{ .root = tmp.dir, .layer = layer, .cleaned = &cleaned };

    try std.testing.expectError(error.InjectedAcquireFailure, Supervisor.runOneShot(
        @TypeOf(factory),
        @TypeOf(success_application),
        std.testing.allocator,
        std.testing.io,
        factory,
        success_application,
        &.{"status"},
        .{
            .runtime = .{ .graph = .{ .path = "causal", .max_records = 256 } },
            .testing = .{ .probe = &probe },
        },
    ));
    try std.testing.expect(cleaned);
    // The framework counted the acquire attempt but performed no release: the
    // factory owns partial-failure cleanup.
    try std.testing.expectEqual(@as(usize, 1), probe.acquire);
    try std.testing.expectEqual(@as(usize, 0), probe.release);
    try std.testing.expectEqual(@as(usize, 0), probe.start);
    try std.testing.expectEqual(@as(usize, 0), invocations);
}

test "runOneShot closes an owned directory only after checked shutdown returns" {
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    try tmp.dir.createDirPath(std.testing.io, "owned-root");
    var causal = fx.CausalStore.init(std.testing.allocator);
    defer causal.deinit();
    var invocations: usize = 0;
    var probe = Supervisor.OneShotOptions.TestProbe{};
    const layer = fx.kernel.Layer.succeed(Probe, ProbeApi{ .invocations = &invocations });

    // A factory that owns the selected directory and asks the framework to close
    // it. The framework must close it only after checked shutdown flushes the
    // runtime graph into that same directory.
    const OwnedFactory = struct {
        const Self = @This();
        pub const LayerType = @TypeOf(layer);
        parent: std.Io.Dir,
        layer: @TypeOf(layer),

        pub fn acquire(
            self: Self,
            allocator: std.mem.Allocator,
            io: std.Io,
            parsed: Cli.ParsedCommand,
        ) anyerror!Supervisor.CommandResources(@TypeOf(layer)) {
            _ = allocator;
            _ = parsed;
            const owned = try self.parent.openDir(io, "owned-root", .{ .iterate = true, .follow_symlinks = false });
            return .{ .root = owned, .layer = self.layer, .ownership = .close_directory };
        }
    };
    const factory = OwnedFactory{ .parent = tmp.dir, .layer = layer };

    const result = try Supervisor.runOneShot(
        @TypeOf(factory),
        @TypeOf(success_application),
        std.testing.allocator,
        std.testing.io,
        factory,
        success_application,
        &.{"status"},
        .{
            .runtime = .{
                .graph = .{ .path = "graph/causal", .max_records = 256 },
                .causal_store = &causal,
            },
            .testing = .{ .probe = &probe },
        },
    );
    _ = result.value.?;
    try std.testing.expectEqual(@as(usize, 1), invocations);
    try expectCompleteProbe(probe, 1);
    // The runtime flushed its graph into the owned directory before it closed:
    // the directory still exists and holds the graph the runtime persisted.
    try tmp.dir.access(std.testing.io, "owned-root", .{});
    try tmp.dir.access(std.testing.io, "owned-root/graph", .{});
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

test "runOneShot rejects an application-shaped identity handoff wrapper at compile time" {
    const result = try std.process.run(std.testing.allocator, std.testing.io, .{
        .argv = &.{
            "zig",
            "test",
            "-ODebug",
            "--dep",
            "zigeffect_std",
            "-Mroot=src/application/identity_handoff_compile_test.zig",
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
        "runOneShot requires the canonical parsed ServiceApplication type",
    ) != null);
}

test "runOneShot rejects a forged resource result that injects command identity at compile time" {
    const result = try std.process.run(std.testing.allocator, std.testing.io, .{
        .argv = &.{
            "zig",
            "test",
            "-ODebug",
            "--dep",
            "zigeffect_std",
            "-Mroot=src/application/resource_factory_authority_compile_test.zig",
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
        "resource factory acquire must return CommandResources(LayerType)",
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
    const factory = Supervisor.fixedResources(tmp.dir, layer);
    if (Supervisor.runOneShot(
        @TypeOf(factory),
        @TypeOf(failure_application),
        std.testing.allocator,
        std.testing.io,
        factory,
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
    return carriesCommandIdentityStateInner(Candidate, .{});
}

fn carriesCommandIdentityStateInner(comptime Candidate: type, comptime ancestors: anytype) bool {
    if (commandIdentityName(@typeName(Candidate))) return true;
    inline for (ancestors) |Ancestor| {
        if (Candidate == Ancestor) return false;
    }
    const next_ancestors = ancestors ++ .{Candidate};

    switch (@typeInfo(Candidate)) {
        .@"struct" => |info| {
            inline for (info.fields) |field| {
                if (commandIdentityName(field.name) or
                    carriesCommandIdentityStateInner(field.type, next_ancestors)) return true;
            }
        },
        .@"union" => |info| {
            inline for (info.fields) |field| {
                if (commandIdentityName(field.name) or
                    carriesCommandIdentityStateInner(field.type, next_ancestors)) return true;
            }
        },
        .optional => |info| return carriesCommandIdentityStateInner(info.child, next_ancestors),
        .pointer => |info| return carriesCommandIdentityStateInner(info.child, next_ancestors),
        .array => |info| return carriesCommandIdentityStateInner(info.child, next_ancestors),
        .vector => |info| return carriesCommandIdentityStateInner(info.child, next_ancestors),
        .error_union => |info| return carriesCommandIdentityStateInner(info.payload, next_ancestors),
        else => {},
    }
    return false;
}

fn commandIdentityName(name: []const u8) bool {
    inline for (command_identity_name_vocabulary) |token| {
        if (std.ascii.indexOfIgnoreCase(name, token) != null) return true;
    }
    return false;
}

const command_identity_name_vocabulary = .{
    "identity",
    "handoff",
    "command_identity",
    "command_path",
    "matched_path",
    "path",
    "segment_count",
    "preflight",
    "sealed_command",
    "parsed",
    "decoded",
    "command_effect",
};

fn readSupervisorSource() ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(
        std.testing.io,
        "src/application/supervisor.zig",
        std.testing.allocator,
        .limited(256 * 1024),
    );
}

fn expectEmptyProbe(probe: Supervisor.OneShotOptions.TestProbe) !void {
    try std.testing.expectEqual(@as(usize, 0), probe.acquire);
    try std.testing.expectEqual(@as(usize, 0), probe.start);
    try std.testing.expectEqual(@as(usize, 0), probe.ready);
    try std.testing.expectEqual(@as(usize, 0), probe.command);
    try std.testing.expectEqual(@as(usize, 0), probe.drain);
    try std.testing.expectEqual(@as(usize, 0), probe.stop);
    try std.testing.expectEqual(@as(usize, 0), probe.inspect);
    try std.testing.expectEqual(@as(usize, 0), probe.health);
    try std.testing.expectEqual(@as(usize, 0), probe.shutdown);
    try std.testing.expectEqual(@as(usize, 0), probe.release);
}

fn expectCompleteProbe(probe: Supervisor.OneShotOptions.TestProbe, expected_commands: usize) !void {
    try std.testing.expectEqual(@as(usize, 1), probe.acquire);
    try std.testing.expectEqual(@as(usize, 1), probe.start);
    try std.testing.expectEqual(@as(usize, 1), probe.ready);
    try std.testing.expectEqual(expected_commands, probe.command);
    try std.testing.expectEqual(@as(usize, 1), probe.drain);
    try std.testing.expectEqual(@as(usize, 1), probe.stop);
    try std.testing.expectEqual(@as(usize, 1), probe.inspect);
    try std.testing.expectEqual(@as(usize, 1), probe.health);
    try std.testing.expectEqual(@as(usize, 1), probe.shutdown);
    try std.testing.expectEqual(@as(usize, 1), probe.release);
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
