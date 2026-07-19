const std = @import("std");
const fx = @import("zigeffect");
const Cli = @import("../cli/root.zig");
const CausalRuntime = @import("../runtime/root.zig");
const Lifecycle = @import("lifecycle.zig");

/// The framework-owned successful acquisition result. It carries only a root
/// directory, an application layer, and how the framework must release the
/// directory. There is no callback, identity, handler, effect, label, outcome,
/// or runtime field: handler resolution, private identity derivation, and effect
/// construction stay framework-owned and cannot be supplied by a caller.
pub fn CommandResources(comptime Layer: type) type {
    return struct {
        root: std.Io.Dir,
        layer: Layer,
        ownership: enum { borrowed, close_directory },
    };
}

/// Fixed-resource adapter: borrows an already-open root and an already-built
/// application layer. Acquisition is infallible and release is a no-op. This is
/// the temporary adapter used while selected-root ownership has not yet moved
/// into a factory (that cutover is a later ticket).
pub fn FixedResources(comptime Layer: type) type {
    return struct {
        const Self = @This();
        pub const LayerType = Layer;

        root: std.Io.Dir,
        layer: Layer,

        pub fn acquire(
            self: Self,
            allocator: std.mem.Allocator,
            io: std.Io,
            parsed: Cli.ParsedCommand,
        ) anyerror!CommandResources(Layer) {
            _ = allocator;
            _ = io;
            _ = parsed;
            return .{ .root = self.root, .layer = self.layer, .ownership = .borrowed };
        }
    };
}

/// Construct a fixed-resource factory that borrows `root` and `layer`.
pub fn fixedResources(root: std.Io.Dir, layer: anytype) FixedResources(@TypeOf(layer)) {
    return .{ .root = root, .layer = layer };
}

pub fn runOneShot(
    comptime ResourceFactory: type,
    comptime ServiceApp: type,
    allocator: std.mem.Allocator,
    io: std.Io,
    resource_factory: ResourceFactory,
    application: ServiceApp,
    argv: []const []const u8,
    options: OneShotOptions,
) anyerror!OneShotResult(ServiceApp.SuccessType) {
    validateServiceApplication(ServiceApp);
    validateResourceFactory(ResourceFactory);
    if (comptime ServiceApp.service_application_kind == .parsed) {
        return runParsedServiceApplication(
            ResourceFactory,
            ServiceApp,
            allocator,
            io,
            resource_factory,
            application,
            argv,
            options,
        );
    }
    return runTypedServiceApplication(
        ResourceFactory,
        ServiceApp,
        allocator,
        io,
        resource_factory,
        application,
        argv,
        options,
    );
}

fn runParsedServiceApplication(
    comptime ResourceFactory: type,
    comptime ServiceApp: type,
    allocator: std.mem.Allocator,
    io: std.Io,
    resource_factory: ResourceFactory,
    application: ServiceApp,
    argv: []const []const u8,
    options: OneShotOptions,
) anyerror!OneShotResult(ServiceApp.SuccessType) {
    // Fail closed on a malformed specification before resolving any user token:
    // a bad spec must never emit help, completions, or a parsed command.
    Cli.validateCommandTree(application.spec) catch |failure| {
        const output = try usageOutputForActive(allocator, &.{application.spec.name}, application.spec, failure);
        return emitShortCircuit(ServiceApp.SuccessType, allocator, io, usageShortCircuit(output), options.testing.write_short_circuit);
    };

    // One owned, validated resolver result serves help, completions, usage, and
    // execution. Help/completion operands and option values are validated here.
    // Ownership is released explicitly (no deferred deinitialization).
    var request = try Cli.resolve(allocator, application.spec, argv);

    if (request.kind != .execute) {
        const short_circuit = buildRequestShortCircuit(allocator, application, &request) catch |failure| {
            request.deinit();
            return failure;
        };
        request.deinit();
        return emitShortCircuit(ServiceApp.SuccessType, allocator, io, short_circuit, options.testing.write_short_circuit);
    }

    var parsed = request.finalizeExecute() catch |failure| {
        const output = usageOutputForActive(allocator, request.commandPath(), request.active(), failure) catch |render_failure| {
            request.deinit();
            return render_failure;
        };
        request.deinit();
        return emitShortCircuit(ServiceApp.SuccessType, allocator, io, usageShortCircuit(output), options.testing.write_short_circuit);
    };
    // The resolved slices are now owned by `parsed`; release the resolver's
    // remaining containers, retaining the leaf spec value for usage context.
    const leaf_active = request.active();
    request.deinit();

    const handler = application.findHandler(parsed) orelse {
        const output = usageOutputForActive(allocator, parsed.path, leaf_active, Cli.CliError.UnknownSubcommand) catch |failure| {
            parsed.deinit(allocator);
            return failure;
        };
        parsed.deinit(allocator);
        return emitShortCircuit(ServiceApp.SuccessType, allocator, io, usageShortCircuit(output), options.testing.write_short_circuit);
    };
    const identity = commandIdentityFromMatchedPath(parsed.path[1..]) catch |failure| {
        parsed.deinit(allocator);
        return failure;
    };
    const effect = parsedCommandEffect(ServiceApp, handler, parsed);
    // The resolved, immutable parsed command is the only input handed to the
    // resource factory; identity and effect are already framework-owned above.
    const result = runResolvedCommand(
        ResourceFactory,
        @TypeOf(effect),
        allocator,
        io,
        resource_factory,
        parsed,
        effect,
        identity,
        options,
    );
    parsed.deinit(allocator);
    return result;
}

/// Build the short circuit for a resolved help, version, or completions
/// request. A captured operand failure renders contextual usage at the deepest
/// valid prefix; otherwise help/completions render from the resolved spec.
fn buildRequestShortCircuit(
    allocator: std.mem.Allocator,
    application: anytype,
    request: *Cli.ResolvedRequest,
) !Cli.ShortCircuit {
    switch (request.kind) {
        .help => {
            if (request.failure()) |failure| {
                return usageShortCircuit(try usageOutputForActive(allocator, request.commandPath(), request.active(), failure));
            }
            const output = if (request.root_context) root_help: {
                if (application.help) |custom| break :root_help try allocator.dupe(u8, custom);
                break :root_help try Cli.formatHelp(allocator, application.spec);
            } else try Cli.formatHelpForPath(allocator, request.commandPath(), request.active());
            return .{ .kind = .help, .exit_code = .success, .stream = .stdout, .output = output };
        },
        .version => {
            const output = try std.fmt.allocPrint(allocator, "{s} {s}\n", .{ application.spec.name, application.version });
            return .{ .kind = .version, .exit_code = .success, .stream = .stdout, .output = output };
        },
        .completions => {
            if (request.failure()) |failure| {
                return usageShortCircuit(try usageOutputForActive(allocator, request.commandPath(), request.active(), failure));
            }
            const output = try Cli.formatCompletions(allocator, request.active());
            return .{ .kind = .completions, .exit_code = .success, .stream = .stdout, .output = output };
        },
        .execute => unreachable,
    }
}

fn runTypedServiceApplication(
    comptime ResourceFactory: type,
    comptime ServiceApp: type,
    allocator: std.mem.Allocator,
    io: std.Io,
    resource_factory: ResourceFactory,
    application: ServiceApp,
    argv: []const []const u8,
    options: OneShotOptions,
) anyerror!OneShotResult(ServiceApp.SuccessType) {
    if (Cli.detectBuiltin(application.command, argv)) |builtin| {
        const output = switch (builtin) {
            .help => try Cli.formatTypedHelp(allocator, application.command),
            .version => try Cli.formatTypedVersion(allocator, application.command),
            .completions => try Cli.formatTypedCompletions(allocator, application.command),
        };
        return emitShortCircuit(ServiceApp.SuccessType, allocator, io, .{
            .kind = switch (builtin) {
                .help => .help,
                .version => .version,
                .completions => .completions,
            },
            .exit_code = .success,
            .stream = .stdout,
            .output = output,
        }, options.testing.write_short_circuit);
    }

    var parsed = Cli.parse(allocator, application.command.toCommandSpec(), argv) catch |failure| {
        const output = try typedUsageOutputAlloc(allocator, application.command, failure);
        return emitShortCircuit(ServiceApp.SuccessType, allocator, io, usageShortCircuit(output), options.testing.write_short_circuit);
    };

    var decoded = Cli.decodeTypedCommandAlloc(allocator, application.command, parsed, null, null) catch |failure| {
        parsed.deinit(allocator);
        return failure;
    };
    if (!decoded.ok()) {
        const output = decoded.issues.jsonAlloc(allocator) catch |failure| {
            decoded.deinit();
            parsed.deinit(allocator);
            return failure;
        };
        decoded.deinit();
        parsed.deinit(allocator);
        return emitShortCircuit(ServiceApp.SuccessType, allocator, io, usageShortCircuit(output), options.testing.write_short_circuit);
    }

    const identity = commandIdentityFromMatchedPath(&.{ServiceApp.CommandType.Meta.name}) catch |failure| {
        decoded.deinit();
        parsed.deinit(allocator);
        return failure;
    };
    const effect = typedCommandEffect(ServiceApp, application.handler, decoded.value.?);
    // The parsed command (pre-decode) is the immutable data handed to the
    // factory; the decoded typed args feed only the framework-owned effect.
    const result = runResolvedCommand(
        ResourceFactory,
        @TypeOf(effect),
        allocator,
        io,
        resource_factory,
        parsed,
        effect,
        identity,
        options,
    );
    decoded.deinit();
    parsed.deinit(allocator);
    return result;
}

fn runResolvedCommand(
    comptime ResourceFactory: type,
    comptime CommandEffect: type,
    allocator: std.mem.Allocator,
    io: std.Io,
    resource_factory: ResourceFactory,
    parsed: Cli.ParsedCommand,
    command_effect: CommandEffect,
    identity: CommandIdentity,
    options: OneShotOptions,
) anyerror!OneShotResult(CommandEffect.SuccessType) {
    // Acquire exactly once, only after parse, arity, and handler resolution have
    // committed to executing a command. The factory owns partial-failure
    // cleanup: an acquisition error returns here without a framework release.
    bump(options.testing.probe, .acquire);
    const resources: CommandResources(ResourceFactory.LayerType) =
        try resource_factory.acquire(allocator, io, parsed);

    // Injected runtime-construction failure: the acquired resources are released
    // before the failure is surfaced, ahead of any lifecycle work.
    if (options.testing.faults.make) |failure| {
        releaseResources(io, resources, options.testing.probe);
        return failure;
    }

    const root_layer = fx.kernel.Layer.mergeAll(.{
        resources.layer,
        Lifecycle.managerLayer(),
        Lifecycle.signalLayer(),
    });
    var runtime = CausalRuntime.ManagedRuntime(@TypeOf(root_layer)).make(
        allocator,
        io,
        resources.root,
        root_layer,
        options.runtime,
    ) catch |failure| {
        // Runtime construction failed before any command ran; release the
        // acquired resources and surface the failure. Release cannot fail, so it
        // never alters `shutdown > first infrastructure > command` precedence.
        releaseResources(io, resources, options.testing.probe);
        return failure;
    };

    var command_value: ?CommandEffect.SuccessType = null;
    var command_failure: ?anyerror = null;
    var infrastructure_failure: ?anyerror = null;

    bump(options.testing.probe, .start);
    attemptEffect(&runtime, Lifecycle.start(), options.testing.faults.start, &infrastructure_failure);

    if (infrastructure_failure == null) {
        bump(options.testing.probe, .ready);
        attemptEffect(&runtime, Lifecycle.ready(), options.testing.faults.ready, &infrastructure_failure);
    }

    if (infrastructure_failure == null) {
        bump(options.testing.probe, .command);
        if (runtime.run(command_effect.named(identity.slice()))) |value| {
            command_value = value;
        } else |failure| {
            command_failure = failure;
        }
    }

    bump(options.testing.probe, .drain);
    attemptEffect(&runtime, Lifecycle.drain(), options.testing.faults.drain, &infrastructure_failure);

    bump(options.testing.probe, .stop);
    attemptEffect(&runtime, Lifecycle.stop(), options.testing.faults.stop, &infrastructure_failure);

    bump(options.testing.probe, .inspect);
    if (runtime.inspect(allocator, options.inspect)) |snapshot_value| {
        var snapshot = snapshot_value;
        validateStrictSnapshot(&snapshot) catch |failure| retainFirst(&infrastructure_failure, failure);
        snapshot.deinit();
    } else |failure| {
        retainFirst(&infrastructure_failure, failure);
    }
    if (options.testing.faults.inspect) |failure| retainFirst(&infrastructure_failure, failure);

    bump(options.testing.probe, .health);
    if (runtime.causalHealth().status != .healthy) {
        retainFirst(&infrastructure_failure, error.CausalRuntimeUnhealthy);
    }
    if (options.testing.faults.health) |failure| retainFirst(&infrastructure_failure, failure);

    bump(options.testing.probe, .shutdown);
    var shutdown_failure: ?anyerror = null;
    runtime.shutdown() catch |failure| {
        shutdown_failure = failure;
    };
    if (shutdown_failure == null) {
        if (options.testing.faults.shutdown) |failure| shutdown_failure = failure;
    }

    // Release exactly once, after checked shutdown returns. An owned directory is
    // closed only here; a borrowed directory is a no-op. Release is infallible.
    releaseResources(io, resources, options.testing.probe);

    if (shutdown_failure) |failure| return failure;
    if (infrastructure_failure) |failure| return failure;
    if (command_failure) |failure| return failure;
    return .{ .value = command_value.? };
}

/// Release framework-owned command resources. This is infallible: a borrowed
/// directory is a no-op and an owned directory is closed. It never returns an
/// error, so it cannot alter failure precedence.
fn releaseResources(io: std.Io, resources: anytype, probe: ?*OneShotOptions.TestProbe) void {
    bump(probe, .release);
    switch (resources.ownership) {
        .borrowed => {},
        .close_directory => resources.root.close(io),
    }
}

/// A resource factory declares `LayerType` and an `acquire` method returning
/// exactly `CommandResources(LayerType)`. Any result shape that adds identity,
/// effect, handler, outcome, or runtime authority is a different type and fails
/// closed here at compile time.
fn validateResourceFactory(comptime ResourceFactory: type) void {
    if (!@hasDecl(ResourceFactory, "LayerType")) {
        @compileError("runOneShot requires a resource factory that declares LayerType");
    }
    if (!@hasDecl(ResourceFactory, "acquire")) {
        @compileError("runOneShot requires a resource factory with an acquire method");
    }
    const acquire_info = @typeInfo(@TypeOf(ResourceFactory.acquire));
    if (acquire_info != .@"fn") {
        @compileError("runOneShot resource factory acquire must be a function");
    }
    const return_type = acquire_info.@"fn".return_type orelse {
        @compileError("runOneShot resource factory acquire must return CommandResources(LayerType)");
    };
    const payload = switch (@typeInfo(return_type)) {
        .error_union => |error_union| error_union.payload,
        else => return_type,
    };
    if (payload != CommandResources(ResourceFactory.LayerType)) {
        @compileError("runOneShot resource factory acquire must return CommandResources(LayerType)");
    }
}

const command_identity_max_bytes: usize = 128;
// The executable identity depth bound is the same documented limit the CLI
// resolver validates against, so declaration, builtin, and executable paths
// share one maximum depth.
const command_identity_max_segments: usize = Cli.max_command_depth;
const command_identity_max_segment_bytes: usize = 48;

const CommandIdentityError = error{
    EmptyCommandIdentity,
    EmptyCommandSegment,
    TooManyCommandSegments,
    CommandSegmentTooLong,
    CommandIdentityTooLong,
};

const CommandIdentity = struct {
    bytes: [command_identity_max_bytes]u8 = undefined,
    len: u8 = 0,
    segment_count: u8 = 0,

    fn slice(self: *const CommandIdentity) []const u8 {
        return self.bytes[0..self.len];
    }

    fn segmentCount(self: CommandIdentity) usize {
        return self.segment_count;
    }
};

fn commandIdentityFromMatchedPath(path: []const []const u8) CommandIdentityError!CommandIdentity {
    if (path.len == 0) return error.EmptyCommandIdentity;
    if (path.len > command_identity_max_segments) return error.TooManyCommandSegments;

    var identity = CommandIdentity{};
    for (path, 0..) |segment, segment_index| {
        if (segment.len == 0) return error.EmptyCommandSegment;
        if (segment.len > command_identity_max_segment_bytes) return error.CommandSegmentTooLong;
        const separator_bytes: usize = if (segment_index == 0) 0 else 1;
        const next_len = @as(usize, identity.len) + separator_bytes + segment.len;
        if (next_len > command_identity_max_bytes) return error.CommandIdentityTooLong;
        if (separator_bytes != 0) {
            identity.bytes[identity.len] = '.';
            identity.len += 1;
        }
        @memcpy(identity.bytes[identity.len..][0..segment.len], segment);
        identity.len = @intCast(next_len);
    }
    identity.segment_count = @intCast(path.len);
    return identity;
}

fn validateServiceApplication(comptime ServiceApp: type) void {
    if (!@hasDecl(ServiceApp, "service_application_kind") or
        !@hasDecl(ServiceApp, "RequiredServices") or
        !@hasDecl(ServiceApp, "FailureType") or
        !@hasDecl(ServiceApp, "SuccessType"))
    {
        @compileError("runOneShot requires a declarative service-aware CLI application");
    }
    switch (ServiceApp.service_application_kind) {
        .parsed => if (ServiceApp != Cli.ServiceApplication(ServiceApp.RequiredServices, ServiceApp.FailureType)) {
            @compileError("runOneShot requires the canonical parsed ServiceApplication type");
        },
        .typed => {
            if (!@hasDecl(ServiceApp, "ArgsType") or !@hasDecl(ServiceApp, "CommandType")) {
                @compileError("runOneShot typed applications must declare their argument and command types");
            }
            if (ServiceApp != Cli.ServiceTypedApplication(
                ServiceApp.RequiredServices,
                ServiceApp.ArgsType,
                ServiceApp.FailureType,
                ServiceApp.CommandType,
            )) {
                @compileError("runOneShot requires the canonical typed ServiceApplication type");
            }
        },
    }
}

fn ParsedCommandInput(comptime ServiceApp: type) type {
    return struct {
        handler: Cli.ServiceHandler(ServiceApp.RequiredServices, ServiceApp.FailureType),
        parsed: Cli.ParsedCommand,
    };
}

fn ParsedCommandEffect(comptime ServiceApp: type) type {
    const Program = fx.kernel.Effect(void, ServiceApp.FailureType, ServiceApp.RequiredServices);
    return Program.Stateful(ParsedCommandInput(ServiceApp));
}

fn parsedCommandEffect(
    comptime ServiceApp: type,
    handler: Cli.ServiceHandler(ServiceApp.RequiredServices, ServiceApp.FailureType),
    parsed: Cli.ParsedCommand,
) ParsedCommandEffect(ServiceApp) {
    const Program = fx.kernel.Effect(void, ServiceApp.FailureType, ServiceApp.RequiredServices);
    const Input = ParsedCommandInput(ServiceApp);
    return Program.fromState(Input, .{ .handler = handler, .parsed = parsed }, struct {
        fn execute(input: Input, ctx: *Program.Context) ServiceApp.FailureType!void {
            return input.handler.run(ctx, input.parsed);
        }
    }.execute);
}

fn TypedCommandInput(comptime ServiceApp: type) type {
    return struct {
        handler: Cli.ServiceTypedHandler(ServiceApp.RequiredServices, ServiceApp.ArgsType, ServiceApp.FailureType),
        args: ServiceApp.ArgsType,
    };
}

fn TypedCommandEffect(comptime ServiceApp: type) type {
    const Program = fx.kernel.Effect(void, ServiceApp.FailureType, ServiceApp.RequiredServices);
    return Program.Stateful(TypedCommandInput(ServiceApp));
}

fn typedCommandEffect(
    comptime ServiceApp: type,
    handler: Cli.ServiceTypedHandler(ServiceApp.RequiredServices, ServiceApp.ArgsType, ServiceApp.FailureType),
    args: ServiceApp.ArgsType,
) TypedCommandEffect(ServiceApp) {
    const Program = fx.kernel.Effect(void, ServiceApp.FailureType, ServiceApp.RequiredServices);
    const Input = TypedCommandInput(ServiceApp);
    return Program.fromState(Input, .{ .handler = handler, .args = args }, struct {
        fn execute(input: Input, ctx: *Program.Context) ServiceApp.FailureType!void {
            return input.handler(ctx, input.args);
        }
    }.execute);
}

/// Render contextual usage from a resolved active spec and its full path — the
/// deepest valid prefix at the point a failure occurred.
fn usageOutputForActive(
    allocator: std.mem.Allocator,
    full_path: []const []const u8,
    active: Cli.CommandSpec,
    failure: anyerror,
) ![]const u8 {
    const help = try Cli.formatHelpForPath(allocator, full_path, active);
    const output = std.fmt.allocPrint(allocator, "usage: {s}\n{s}", .{ @errorName(failure), help }) catch |allocation_failure| {
        allocator.free(help);
        return allocation_failure;
    };
    allocator.free(help);
    return output;
}

fn typedUsageOutputAlloc(allocator: std.mem.Allocator, command: anytype, failure: anyerror) ![]const u8 {
    const help = try Cli.formatTypedHelp(allocator, command);
    const output = std.fmt.allocPrint(allocator, "usage: {s}\n{s}", .{ @errorName(failure), help }) catch |allocation_failure| {
        allocator.free(help);
        return allocation_failure;
    };
    allocator.free(help);
    return output;
}

fn usageShortCircuit(output: []const u8) Cli.ShortCircuit {
    return .{
        .kind = .usage,
        .exit_code = .usage,
        .stream = .stderr,
        .output = output,
    };
}

fn emitShortCircuit(
    comptime Success: type,
    allocator: std.mem.Allocator,
    io: std.Io,
    short_circuit: Cli.ShortCircuit,
    write_output: bool,
) !OneShotResult(Success) {
    var owned = short_circuit;
    if (write_output) owned.write(io) catch |failure| {
        owned.deinit(allocator);
        return failure;
    };
    const result: OneShotResult(Success) = .{
        .exit_code = owned.exit_code,
        .short_circuit = owned.kind,
    };
    owned.deinit(allocator);
    return result;
}

pub const OneShotOptions = struct {
    runtime: CausalRuntime.Options = .{},
    inspect: fx.kernel.InspectOptions = .{ .max_recent_events = 128 },
    testing: Testing = .{},

    pub const TestFaults = struct {
        make: ?anyerror = null,
        start: ?anyerror = null,
        ready: ?anyerror = null,
        drain: ?anyerror = null,
        stop: ?anyerror = null,
        inspect: ?anyerror = null,
        health: ?anyerror = null,
        shutdown: ?anyerror = null,
    };

    pub const TestProbe = struct {
        acquire: usize = 0,
        start: usize = 0,
        ready: usize = 0,
        command: usize = 0,
        drain: usize = 0,
        stop: usize = 0,
        inspect: usize = 0,
        health: usize = 0,
        shutdown: usize = 0,
        release: usize = 0,
    };

    pub const Testing = struct {
        faults: TestFaults = .{},
        probe: ?*TestProbe = null,
        write_short_circuit: bool = true,
    };
};

pub fn OneShotResult(comptime Success: type) type {
    return struct {
        value: ?Success = null,
        exit_code: Cli.ExitCode = .success,
        short_circuit: ?Cli.ShortCircuitKind = null,
    };
}

fn attemptEffect(runtime: anytype, effect: anytype, injected_failure: ?anyerror, first_failure: *?anyerror) void {
    runtime.run(effect) catch |failure| retainFirst(first_failure, failure);
    if (injected_failure) |failure| retainFirst(first_failure, failure);
}

fn validateStrictSnapshot(snapshot: *const fx.kernel.ApplicationSnapshot) !void {
    if (snapshot.status != .ready) return error.ApplicationSnapshotNotReady;

    var has_lifecycle = false;
    var has_signals = false;
    for (snapshot.services) |service| {
        if (std.mem.eql(u8, service.key, Lifecycle.Lifecycle.service_key)) has_lifecycle = true;
        if (std.mem.eql(u8, service.key, Lifecycle.ProcessSignals.service_key)) has_signals = true;
    }
    if (!has_lifecycle) return error.MissingLifecycleService;
    if (!has_signals) return error.MissingProcessSignalsService;

    for (snapshot.layers) |layer| switch (layer.status) {
        .building => return error.ApplicationLayerBuilding,
        .failed => return error.ApplicationLayerFailed,
        .declared, .ready => {},
    };
    for (snapshot.causal.fiber_states) |fiber| {
        if (!fiber.resolved) return error.UnresolvedRuntimeFiber;
    }
    if (snapshot.causal.findings.len != 0) return error.CausalRuntimeFindings;
}

fn retainFirst(current: *?anyerror, failure: anyerror) void {
    if (current.* == null) current.* = failure;
}

const ProbeField = enum {
    acquire,
    start,
    ready,
    command,
    drain,
    stop,
    inspect,
    health,
    shutdown,
    release,
};

fn bump(probe: ?*OneShotOptions.TestProbe, comptime field: ProbeField) void {
    if (probe) |value| @field(value, @tagName(field)) += 1;
}

test "private one-shot command identity enforces matched-path bounds" {
    const identity = try commandIdentityFromMatchedPath(&.{ "benchmark", "corpus" });
    try std.testing.expectEqualStrings("benchmark.corpus", identity.slice());
    try std.testing.expectEqual(@as(usize, 2), identity.segmentCount());

    const too_long_segment = "1234567890123456789012345678901234567890123456789";
    const full_segment = "123456789012345678901234567890123456789012345678";
    try std.testing.expectError(error.EmptyCommandIdentity, commandIdentityFromMatchedPath(&.{}));
    try std.testing.expectError(error.EmptyCommandSegment, commandIdentityFromMatchedPath(&.{""}));
    try std.testing.expectError(error.CommandSegmentTooLong, commandIdentityFromMatchedPath(&.{too_long_segment}));
    try std.testing.expectError(error.CommandIdentityTooLong, commandIdentityFromMatchedPath(&.{ full_segment, full_segment, full_segment }));
    try std.testing.expectError(error.TooManyCommandSegments, commandIdentityFromMatchedPath(&.{ "a", "b", "c", "d", "e", "f", "g", "h", "i" }));
}
