const std = @import("std");
const fx = @import("zigeffect");
const Cli = @import("../cli/root.zig");
const CausalRuntime = @import("../runtime/root.zig");
const Lifecycle = @import("lifecycle.zig");

pub fn runOneShot(
    comptime ApplicationLayer: type,
    comptime Preflight: type,
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    application_layer: ApplicationLayer,
    preflight: *const Preflight,
    options: OneShotOptions,
) anyerror!OneShotResult(Preflight.CommandEffect.SuccessType) {
    if (comptime !Cli.isFrameworkServicePreflight(Preflight)) {
        @compileError("runOneShot requires a framework-produced service CLI preflight artifact");
    }
    const prepared = try preflight.prepare();
    const CommandEffect = @TypeOf(prepared.effect);
    const root_layer = fx.kernel.Layer.mergeAll(.{
        application_layer,
        Lifecycle.managerLayer(),
        Lifecycle.signalLayer(),
    });
    var runtime = CausalRuntime.ManagedRuntime(@TypeOf(root_layer)).make(
        allocator,
        io,
        root,
        root_layer,
        options.runtime,
    ) catch |failure| return failure;

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
        if (runtime.run(prepared.effect.named(prepared.identity.slice()))) |value| {
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

    if (shutdown_failure) |failure| return failure;
    if (infrastructure_failure) |failure| return failure;
    if (command_failure) |failure| return failure;
    return .{ .value = command_value.? };
}

pub const OneShotOptions = struct {
    runtime: CausalRuntime.Options = .{},
    inspect: fx.kernel.InspectOptions = .{ .max_recent_events = 128 },
    testing: Testing = .{},

    pub const TestFaults = struct {
        start: ?anyerror = null,
        ready: ?anyerror = null,
        drain: ?anyerror = null,
        stop: ?anyerror = null,
        inspect: ?anyerror = null,
        health: ?anyerror = null,
        shutdown: ?anyerror = null,
    };

    pub const TestProbe = struct {
        start: usize = 0,
        ready: usize = 0,
        command: usize = 0,
        drain: usize = 0,
        stop: usize = 0,
        inspect: usize = 0,
        health: usize = 0,
        shutdown: usize = 0,
    };

    pub const Testing = struct {
        faults: TestFaults = .{},
        probe: ?*TestProbe = null,
    };
};

pub fn OneShotResult(comptime Success: type) type {
    return struct {
        value: Success,
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
    start,
    ready,
    command,
    drain,
    stop,
    inspect,
    health,
    shutdown,
};

fn bump(probe: ?*OneShotOptions.TestProbe, comptime field: ProbeField) void {
    if (probe) |value| @field(value, @tagName(field)) += 1;
}
