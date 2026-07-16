const std = @import("std");
const fx = @import("zigeffect");

const kernel = fx.kernel;

fn expectCompileFailDiagnostic(fixture: []const u8, expected: []const u8) !void {
    var io_instance = std.Io.Threaded.init(std.testing.allocator, .{});
    defer io_instance.deinit();
    const io = io_instance.io();

    const root_arg = try std.fmt.allocPrint(
        std.testing.allocator,
        "-Mroot=test/compile_fail/{s}",
        .{fixture},
    );
    defer std.testing.allocator.free(root_arg);

    const result = try std.process.run(std.testing.allocator, io, .{
        .argv = &.{
            "/opt/homebrew/bin/zig",
            "build-exe",
            "--dep",
            "zigeffect",
            root_arg,
            "-Mzigeffect=src/zigeffect.zig",
            "-fno-emit-bin",
            "--cache-dir",
            ".zig-cache/compile-fail-cache",
            "--global-cache-dir",
            ".zig-cache/compile-fail-global-cache",
        },
    });
    defer std.testing.allocator.free(result.stdout);
    defer std.testing.allocator.free(result.stderr);

    switch (result.term) {
        .exited => |code| try std.testing.expect(code != 0),
        else => return error.UnexpectedCompilerTermination,
    }
    try std.testing.expect(
        std.mem.indexOf(u8, result.stdout, expected) != null or
            std.mem.indexOf(u8, result.stderr, expected) != null,
    );
}

const Number = kernel.Service("test/Number", struct {
    value: u32,
});

const ReadNumber = kernel.Effect(u32, error{}, .{Number});
const read_number = ReadNumber.fromFn(struct {
    fn run(ctx: *ReadNumber.Context) error{}!u32 {
        return ctx.service(Number).value;
    }
}.run);

test "canonical effects depend on service tags and run unchanged against live and fake layers" {
    try std.testing.expect(ReadNumber.RequiredServices[0] == Number);
    try std.testing.expect(!@hasDecl(ReadNumber, "EnvType"));

    const live = kernel.Layer.succeed(Number, .{ .value = 42 });
    var live_runtime = try kernel.ManagedRuntime(@TypeOf(live)).make(
        std.testing.allocator,
        live,
        .{},
    );
    defer live_runtime.deinit();
    try std.testing.expectEqual(@as(u32, 42), try live_runtime.run(read_number));

    const fake = kernel.Layer.succeed(Number, .{ .value = 7 });
    var fake_runtime = try kernel.ManagedRuntime(@TypeOf(fake)).make(
        std.testing.allocator,
        fake,
        .{},
    );
    defer fake_runtime.deinit();
    try std.testing.expectEqual(@as(u32, 7), try fake_runtime.run(read_number));
}

const ScopedAllocationCounter = kernel.Service("test/ScopedAllocationCounter", struct {
    releases: *usize,
});

const ScopedAllocation = kernel.Service("test/ScopedAllocation", struct {
    allocator: std.mem.Allocator,
    bytes: []u8,
    releases: *usize,
});

fn acquireScopedAllocation(
    ctx: *kernel.ContextView(.{ScopedAllocationCounter}),
) error{OutOfMemory}!ScopedAllocation.API {
    return .{
        .allocator = ctx.allocator(),
        .bytes = try ctx.allocator().alloc(u8, 64),
        .releases = ctx.service(ScopedAllocationCounter).releases,
    };
}

fn releaseScopedAllocation(value: *ScopedAllocation.API) void {
    value.allocator.free(value.bytes);
    value.releases.* += 1;
}

test "scoped layers release an acquisition when registry publication fails" {
    const Harness = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var releases: usize = 0;
            const dependency = kernel.Layer.succeed(ScopedAllocationCounter, .{ .releases = &releases });
            const root = kernel.Layer.scoped(
                ScopedAllocation,
                error{OutOfMemory},
                .{ScopedAllocationCounter},
                acquireScopedAllocation,
                releaseScopedAllocation,
            ).provide(dependency);

            // Runtime causal recording is intentionally best-effort. Its
            // allocator stays stable so the injected failures target kernel
            // layer construction and registry publication.
            var causal = fx.CausalStore.init(std.testing.allocator);
            defer causal.deinit();
            var runtime = try kernel.ManagedRuntime(@TypeOf(root)).make(
                allocator,
                root,
                .{ .causal_store = &causal },
            );
            runtime.deinit();
            if (releases != 1) return error.ScopedAcquisitionNotReleased;
        }
    };

    try std.testing.checkAllAllocationFailures(std.testing.allocator, Harness.run, .{});
}

const LeftNumber = kernel.Service("test/LeftNumber", struct {
    value: u32,
});

const RightNumber = kernel.Service("test/RightNumber", struct {
    value: u32,
});

const Audit = kernel.Service("test/Audit", struct {
    observed: *u32,
});

const ReadLeftNumber = kernel.Effect(u32, error{LeftUnavailable}, .{LeftNumber});
const read_left_number = ReadLeftNumber.fromFn(struct {
    fn run(ctx: *ReadLeftNumber.Context) error{LeftUnavailable}!u32 {
        return ctx.service(LeftNumber).value;
    }
}.run);

const AddRightNumber = kernel.Effect(u32, error{RightUnavailable}, .{RightNumber});

fn addRightNumber(left: u32) AddRightNumber.Stateful(u32) {
    return AddRightNumber.fromState(u32, left, struct {
        fn run(value: u32, ctx: *AddRightNumber.Context) error{RightUnavailable}!u32 {
            return value + ctx.service(RightNumber).value;
        }
    }.run);
}

const AuditNumber = kernel.Effect(void, error{AuditRejected}, .{Audit});

fn auditNumber(value: u32) AuditNumber.Stateful(u32) {
    return AuditNumber.fromState(u32, value, struct {
        fn run(observed: u32, ctx: *AuditNumber.Context) error{AuditRejected}!void {
            ctx.service(Audit).observed.* = observed;
        }
    }.run);
}

fn doubleNumber(value: u32) u64 {
    return @as(u64, value) * 2;
}

fn preserveNumber(value: u64) u64 {
    return value;
}

fn recoverLeft(_: error{LeftUnavailable}) kernel.Effect(u32, error{}, .{}) {
    return kernel.Effect(u32, error{}, .{}).succeed(99);
}

fn normalizeLeftFailure(_: error{LeftUnavailable}) error{ProgramFailed} {
    return error.ProgramFailed;
}

test "canonical effects compose fluently with inferred services failures recovery and semantic causal names" {
    var audited: u32 = 0;
    const root = kernel.Layer.mergeAll(.{
        kernel.Layer.succeed(LeftNumber, .{ .value = 20 }),
        kernel.Layer.succeed(RightNumber, .{ .value = 22 }),
        kernel.Layer.succeed(Audit, .{ .observed = &audited }),
    });
    var runtime = try kernel.ManagedRuntime(@TypeOf(root)).make(std.testing.allocator, root, .{});
    defer runtime.deinit();

    const program = read_left_number
        .flatMap(addRightNumber)
        .tap(auditNumber)
        .map(doubleNumber)
        .named("application.answer");

    try std.testing.expect(kernel.contains(@TypeOf(program).RequiredServices, LeftNumber));
    try std.testing.expect(kernel.contains(@TypeOf(program).RequiredServices, RightNumber));
    try std.testing.expect(kernel.contains(@TypeOf(program).RequiredServices, Audit));
    try std.testing.expectEqual(@as(u64, 84), try runtime.run(program));
    try std.testing.expectEqual(@as(u32, 42), audited);

    const zipped = try runtime.run(read_left_number.zip(addRightNumber(1)));
    try std.testing.expectEqual(@as(u32, 20), zipped.left);
    try std.testing.expectEqual(@as(u32, 23), zipped.right);

    const sequenced = kernel.Effect(void, error{}, .{}).succeed({}).andThen(read_left_number);
    try std.testing.expectEqual(@as(u32, 20), try runtime.run(sequenced));

    const failed = kernel.Effect(u32, error{LeftUnavailable}, .{}).fail(error.LeftUnavailable);
    try std.testing.expectEqual(@as(u32, 99), try runtime.run(failed.catchAll(recoverLeft)));
    const mapped_failure = runtime.exit(failed.mapError(normalizeLeftFailure));
    switch (mapped_failure) {
        .failure => |failure| try std.testing.expectEqual(error.ProgramFailed, failure),
        .success => return error.ExpectedMappedFailure,
        else => return error.ExpectedTypedFailure,
    }

    var inspection = try runtime.inspect(std.testing.allocator, .{ .max_recent_events = 128 });
    defer inspection.deinit();
    var named_event_id: ?u64 = null;
    for (inspection.causal.recent_events) |event| {
        if (event.kind == .effect_started and std.mem.eql(u8, event.label, "application.answer")) {
            named_event_id = event.id;
            break;
        }
    }
    try std.testing.expect(named_event_id != null);
    var saw_nested_operation = false;
    for (inspection.causal.recent_events) |event| {
        if (event.kind == .effect_started and event.parent_id == named_event_id) {
            saw_nested_operation = true;
            break;
        }
    }
    try std.testing.expect(saw_nested_operation);
}

test "deeply composed named effects retain semantic identity without truncating structural evidence" {
    var causal = fx.CausalStore.initWithOptions(std.testing.allocator, .{
        .max_events = 256,
        .max_event_string_bytes = 512,
    });
    defer causal.deinit();

    const root = kernel.Layer.empty();
    var runtime = try kernel.ManagedRuntime(@TypeOf(root)).make(std.testing.allocator, root, .{
        .causal_store = &causal,
    });
    defer runtime.deinit();

    const program = kernel.Effect(u64, error{}, .{}).succeed(42)
        .map(preserveNumber)
        .map(preserveNumber)
        .map(preserveNumber)
        .map(preserveNumber)
        .map(preserveNumber)
        .map(preserveNumber)
        .map(preserveNumber)
        .map(preserveNumber)
        .map(preserveNumber)
        .map(preserveNumber)
        .map(preserveNumber)
        .map(preserveNumber)
        .named("application.deep-composition");

    try std.testing.expect(@typeName(@TypeOf(program)).len > 512);
    try std.testing.expectEqual(@as(u64, 42), try runtime.run(program));
    try std.testing.expectEqual(@as(u64, 0), causal.truncatedFieldCount());

    var snapshot = try causal.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    var saw_semantic_name = false;
    for (snapshot.events) |event| {
        try std.testing.expect(event.type_name.len <= 160);
        if (std.mem.eql(u8, event.label, "application.deep-composition")) saw_semantic_name = true;
    }
    try std.testing.expect(saw_semantic_name);
}

test "an effect context rejects access to a service absent from its requirements" {
    try expectCompileFailDiagnostic(
        "kernel_undeclared_service.zig",
        "zigeffect undeclared service requirement",
    );
}

const Config = kernel.Service("test/Config", struct {
    prefix: u32,
});

const Repository = kernel.Service("test/Repository", struct {
    pub const operations: []const []const u8 = &.{"Repository.read"};
    value: u32,
});

const Health = kernel.Service("test/Health", struct {
    ready: bool,
});

var config_acquisitions: usize = 0;
var config_finalizations: usize = 0;

fn acquireConfig(ctx: *kernel.ContextView(.{})) error{}!Config.API {
    _ = ctx;
    config_acquisitions += 1;
    return .{ .prefix = 40 };
}

fn releaseConfig(config: *Config.API) void {
    _ = config;
    config_finalizations += 1;
}

fn makeRepository(ctx: *kernel.ContextView(.{Config})) Repository.API {
    return .{ .value = ctx.service(Config).prefix + 2 };
}

fn makeHealth(ctx: *kernel.ContextView(.{Config})) Health.API {
    return .{ .ready = ctx.service(Config).prefix > 0 };
}

const ReadRepository = kernel.Effect(u32, error{}, .{Repository});
const read_repository = ReadRepository.fromFn(struct {
    fn run(ctx: *ReadRepository.Context) error{}!u32 {
        return ctx.service(Repository).value;
    }
}.run);

const DispatchRepository = kernel.Effect(u32, error{}, .{Repository});
const dispatch_repository = DispatchRepository.fromFn(struct {
    fn run(ctx: *DispatchRepository.Context) error{}!u32 {
        var endpoint_runtime = ctx.runtime();
        return endpoint_runtime.run(read_repository);
    }
}.run);

const ReadHealth = kernel.Effect(bool, error{}, .{Health});
const read_health = ReadHealth.fromFn(struct {
    fn run(ctx: *ReadHealth.Context) error{}!bool {
        return ctx.service(Health).ready;
    }
}.run);

fn hasCausalEvent(snapshot: fx.CausalSnapshot, kind: fx.CausalEventKind, status: []const u8) bool {
    for (snapshot.events) |event| {
        if (event.kind == kind and std.mem.eql(u8, event.status, status)) return true;
    }
    return false;
}

var observed_events: usize = 0;

fn observeRuntimeEvent(state: ?*anyopaque, event: kernel.RuntimeEvent) ?u64 {
    _ = event;
    const count: *usize = @ptrCast(@alignCast(state.?));
    count.* += 1;
    return null;
}

test "explicit layer provision memoizes a shared layer across runtime branches and endpoint runs" {
    config_acquisitions = 0;
    config_finalizations = 0;
    observed_events = 0;

    const config_live = kernel.Layer.scoped(
        Config,
        error{},
        .{},
        acquireConfig,
        releaseConfig,
    );
    const repository_live = kernel.Layer.sync(Repository, .{Config}, makeRepository);
    const health_live = kernel.Layer.sync(Health, .{Config}, makeHealth);
    const unwired = kernel.Layer.mergeAll(.{ repository_live, config_live });
    try std.testing.expect(kernel.contains(@TypeOf(unwired).OutputServices, Repository));
    try std.testing.expect(kernel.contains(@TypeOf(unwired).OutputServices, Config));
    try std.testing.expect(kernel.contains(@TypeOf(unwired).InputServices, Config));

    const repository_ready = kernel.Layer.provide(repository_live, config_live);
    const health_ready = kernel.Layer.provide(health_live, config_live);
    const main_layer = kernel.Layer.mergeAll(.{ repository_ready, health_ready });

    try std.testing.expect(kernel.contains(@TypeOf(main_layer).OutputServices, Repository));
    try std.testing.expect(kernel.contains(@TypeOf(main_layer).OutputServices, Health));
    try std.testing.expect(!kernel.contains(@TypeOf(main_layer).OutputServices, Config));
    try std.testing.expectEqual(@as(usize, 0), @TypeOf(main_layer).InputServices.len);

    var causal_store = fx.CausalStore.init(std.testing.allocator);
    defer causal_store.deinit();
    const aspects = [_]kernel.RuntimeAspect{.{
        .state = &observed_events,
        .on_event = observeRuntimeEvent,
    }};

    var runtime = try kernel.ManagedRuntime(@TypeOf(main_layer)).make(
        std.testing.allocator,
        main_layer,
        .{
            .causal_store = &causal_store,
            .aspects = aspects[0..],
        },
    );

    try std.testing.expectEqual(@as(usize, 1), config_acquisitions);
    try std.testing.expectEqual(@as(u32, 42), try runtime.run(read_repository));
    try std.testing.expect(try runtime.run(read_health));
    try std.testing.expectEqual(@as(u32, 42), try runtime.run(dispatch_repository));
    try std.testing.expectEqual(@as(u32, 42), try runtime.run(read_repository));
    try std.testing.expectEqual(@as(usize, 1), config_acquisitions);
    try std.testing.expect(observed_events > 0);

    var snapshot = try causal_store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expect(hasCausalEvent(snapshot, .layer_completed, "memoized"));
    try std.testing.expect(hasCausalEvent(snapshot, .service_required, "resolved"));
    try std.testing.expect(hasCausalEvent(snapshot, .effect_started, "running"));

    runtime.deinit();
    try std.testing.expectEqual(@as(usize, 1), config_finalizations);
    runtime.deinit();
    try std.testing.expectEqual(@as(usize, 1), config_finalizations);
}

test "layers compose fluently while preserving dependency hiding and memoization" {
    config_acquisitions = 0;
    config_finalizations = 0;
    const config_live = kernel.Layer.scoped(Config, error{}, .{}, acquireConfig, releaseConfig);
    const root = kernel.Layer.sync(Repository, .{Config}, makeRepository)
        .provide(config_live)
        .merge(kernel.Layer.sync(Health, .{Config}, makeHealth).provide(config_live));

    try std.testing.expect(kernel.contains(@TypeOf(root).OutputServices, Repository));
    try std.testing.expect(kernel.contains(@TypeOf(root).OutputServices, Health));
    try std.testing.expect(!kernel.contains(@TypeOf(root).OutputServices, Config));
    try std.testing.expectEqual(@as(usize, 0), @TypeOf(root).InputServices.len);

    var runtime = try kernel.ManagedRuntime(@TypeOf(root)).make(std.testing.allocator, root, .{});
    try std.testing.expectEqual(@as(usize, 1), config_acquisitions);
    try std.testing.expectEqual(@as(u32, 42), try runtime.run(read_repository));
    try std.testing.expect(try runtime.run(read_health));
    runtime.deinit();
    try std.testing.expectEqual(@as(usize, 1), config_finalizations);
}

const Now = kernel.Effect(u64, error{}, .{});
const now = Now.fromFn(struct {
    fn run(ctx: *Now.Context) error{}!u64 {
        return ctx.clock().nowMs();
    }
}.run);

test "Clock is a runtime default and lexical override does not become an effect requirement" {
    const empty = kernel.Layer.empty();
    var runtime = try kernel.ManagedRuntime(@TypeOf(empty)).make(
        std.testing.allocator,
        empty,
        .{},
    );
    defer runtime.deinit();

    var fake = fx.FakeClock.fake(1234);
    try std.testing.expectEqual(@as(usize, 0), Now.RequiredServices.len);
    try std.testing.expectEqual(@as(u64, 1234), try runtime.run(now.withClock(&fake)));
    try std.testing.expectEqual(@as(u64, 1234), fake.nowMs());
}

const TestConfigProvider = struct {
    value: []const u8,

    pub fn getAlloc(self: *TestConfigProvider, allocator: std.mem.Allocator, key: []const u8) anyerror![]u8 {
        if (!std.mem.eql(u8, key, "mode")) return error.MissingConfig;
        return allocator.dupe(u8, self.value);
    }
};

const TestConsole = struct {
    allocator: std.mem.Allocator,
    output: std.ArrayList(u8) = .empty,

    fn deinit(self: *TestConsole) void {
        self.output.deinit(self.allocator);
    }

    pub fn writeOut(self: *TestConsole, text: []const u8) anyerror!void {
        try self.output.appendSlice(self.allocator, text);
    }

    pub fn writeErr(self: *TestConsole, text: []const u8) anyerror!void {
        try self.output.appendSlice(self.allocator, text);
    }
};

const TestRandom = struct {
    byte: u8,

    pub fn fill(self: *TestRandom, output: []u8) void {
        @memset(output, self.byte);
    }
};

const DefaultObservation = struct {
    now_ms: u64,
    config_marker: u8,
    random_marker: u8,
};

const ReadDefaults = kernel.Effect(DefaultObservation, anyerror, .{});
const read_defaults = ReadDefaults.fromFn(struct {
    fn run(ctx: *ReadDefaults.Context) anyerror!DefaultObservation {
        const value = try ctx.configProvider().getAlloc(ctx.allocator(), "mode");
        defer ctx.allocator().free(value);

        try ctx.console().writeOut("observed");
        var random_bytes: [1]u8 = undefined;
        ctx.random().fill(&random_bytes);
        const span_id = try ctx.tracer().startSpan("read-defaults", null);
        try ctx.tracer().endSpan(span_id);

        return .{
            .now_ms = ctx.clock().nowMs(),
            .config_marker = value[0],
            .random_marker = random_bytes[0],
        };
    }
}.run);

const DispatchDefaults = kernel.Effect(DefaultObservation, anyerror, .{});
const dispatch_defaults = DispatchDefaults.fromFn(struct {
    fn run(ctx: *DispatchDefaults.Context) anyerror!DefaultObservation {
        var child_runtime = ctx.runtime();
        return child_runtime.run(read_defaults);
    }
}.run);

test "all default references stay out of requirements and lexical overrides are inherited by child runs" {
    var root_clock = fx.FakeClock.fake(10);
    var child_clock = fx.FakeClock.fake(20);
    var root_config = TestConfigProvider{ .value = "root" };
    var child_config = TestConfigProvider{ .value = "child" };
    var root_console = TestConsole{ .allocator = std.testing.allocator };
    defer root_console.deinit();
    var child_console = TestConsole{ .allocator = std.testing.allocator };
    defer child_console.deinit();
    var root_random = TestRandom{ .byte = 1 };
    var child_random = TestRandom{ .byte = 2 };
    var root_tracing = fx.Tracing.init(std.testing.allocator);
    defer root_tracing.deinit();
    var child_tracing = fx.Tracing.init(std.testing.allocator);
    defer child_tracing.deinit();

    const root_defaults = kernel.DefaultServices{
        .clock = &root_clock,
        .config_provider = kernel.ConfigProvider.from(TestConfigProvider, &root_config),
        .console = kernel.Console.from(TestConsole, &root_console),
        .random = kernel.Random.from(TestRandom, &root_random),
        .tracer = kernel.Tracer.from(fx.Tracing, &root_tracing),
    };
    const child_overrides = kernel.DefaultOverrides{
        .clock = &child_clock,
        .config_provider = kernel.ConfigProvider.from(TestConfigProvider, &child_config),
        .console = kernel.Console.from(TestConsole, &child_console),
        .random = kernel.Random.from(TestRandom, &child_random),
        .tracer = kernel.Tracer.from(fx.Tracing, &child_tracing),
    };

    const empty = kernel.Layer.empty();
    var runtime = try kernel.ManagedRuntime(@TypeOf(empty)).make(
        std.testing.allocator,
        empty,
        .{ .defaults = root_defaults },
    );
    defer runtime.deinit();

    try std.testing.expectEqual(@as(usize, 0), ReadDefaults.RequiredServices.len);
    const child = try runtime.run(dispatch_defaults.withDefaults(child_overrides));
    try std.testing.expectEqual(@as(u64, 20), child.now_ms);
    try std.testing.expectEqual(@as(u8, 'c'), child.config_marker);
    try std.testing.expectEqual(@as(u8, 2), child.random_marker);
    try std.testing.expectEqualStrings("observed", child_console.output.items);
    try std.testing.expectEqual(@as(usize, 1), child_tracing.spans.items.len);

    const root = try runtime.run(read_defaults);
    try std.testing.expectEqual(@as(u64, 10), root.now_ms);
    try std.testing.expectEqual(@as(u8, 'r'), root.config_marker);
    try std.testing.expectEqual(@as(u8, 1), root.random_marker);
    try std.testing.expectEqualStrings("observed", root_console.output.items);
    try std.testing.expectEqual(@as(usize, 1), root_tracing.spans.items.len);
}

test "runtime-installed observability records every layer and endpoint run without program dependencies" {
    var logger = fx.Logger.init(std.testing.allocator);
    defer logger.deinit();
    var metrics = fx.Metrics.init(std.testing.allocator);
    defer metrics.deinit();
    var tracing = fx.Tracing.init(std.testing.allocator);
    defer tracing.deinit();

    const empty = kernel.Layer.empty();
    var runtime = try kernel.ManagedRuntime(@TypeOf(empty)).make(
        std.testing.allocator,
        empty,
        .{ .observability = .{
            .logger = &logger,
            .metrics = &metrics,
            .tracer = &tracing,
        } },
    );
    defer runtime.deinit();

    _ = try runtime.run(now);
    _ = try runtime.run(now);

    try std.testing.expect(logger.structured_entries.items.len > 0);
    try std.testing.expect(metrics.get("zigeffect.runtime.events.total") > 0);
    try std.testing.expect(metrics.get("zigeffect.runtime.runs.started") >= 2);
    try std.testing.expect(tracing.events.items.len > 0);
}

const RecordingSupervisor = struct {
    started: usize = 0,
    completed: usize = 0,
    failed: usize = 0,
    active: usize = 0,

    pub fn onStart(self: *RecordingSupervisor, fiber_id: u64, label: []const u8) void {
        _ = fiber_id;
        _ = label;
        self.started += 1;
        self.active += 1;
    }

    pub fn onEnd(self: *RecordingSupervisor, fiber_id: u64, status: []const u8) void {
        _ = fiber_id;
        self.completed += 1;
        self.active -= 1;
        if (std.mem.eql(u8, status, "failure")) self.failed += 1;
    }
};

test "every RuntimeHandle run is a supervised child fiber with automatic causal lifecycle" {
    var supervisor = RecordingSupervisor{};
    var causal_store = fx.CausalStore.init(std.testing.allocator);
    defer causal_store.deinit();

    const empty = kernel.Layer.empty();
    var runtime = try kernel.ManagedRuntime(@TypeOf(empty)).make(
        std.testing.allocator,
        empty,
        .{
            .causal_store = &causal_store,
            .observability = .{
                .supervisor = kernel.FiberSupervisor.from(RecordingSupervisor, &supervisor),
            },
        },
    );
    defer runtime.deinit();

    _ = try runtime.run(now);
    _ = try runtime.run(now);

    try std.testing.expectEqual(@as(usize, 2), supervisor.started);
    try std.testing.expectEqual(@as(usize, 2), supervisor.completed);
    try std.testing.expectEqual(@as(usize, 0), supervisor.failed);
    try std.testing.expectEqual(@as(usize, 0), supervisor.active);

    var snapshot = try causal_store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expect(hasCausalEvent(snapshot, .fiber_started, "running"));
    try std.testing.expect(hasCausalEvent(snapshot, .fiber_joined, "success"));
}

const DefinedConfigApi = struct { value: u32 };

const DefinedConfig = kernel.defineService(.{
    .key = "test/DefinedConfig",
    .API = DefinedConfigApi,
    .Failure = error{},
    .Requirements = .{},
    .acquire = struct {
        fn acquire(_: *kernel.ContextView(.{})) error{}!DefinedConfigApi {
            return .{ .value = 41 };
        }
    }.acquire,
});

fn definedConfigLayer() @TypeOf(DefinedConfig.Default()) {
    return DefinedConfig.Default();
}

const DefinedRepositoryApi = struct { value: u32 };

const DefinedRepository = kernel.defineService(.{
    .key = "test/DefinedRepository",
    .API = DefinedRepositoryApi,
    .Failure = error{},
    .Requirements = .{DefinedConfig},
    .acquire = struct {
        fn acquire(ctx: *kernel.ContextView(.{DefinedConfig})) error{}!DefinedRepositoryApi {
            return .{ .value = ctx.service(DefinedConfig).value + 1 };
        }
    }.acquire,
    .default_dependencies = definedConfigLayer,
});

const ReadDefinedRepository = kernel.Effect(u32, error{}, .{DefinedRepository});
const read_defined_repository = ReadDefinedRepository.fromFn(struct {
    fn run(ctx: *ReadDefinedRepository.Context) error{}!u32 {
        return ctx.service(DefinedRepository).value;
    }
}.run);

test "defineService keeps the tag and canonical default layers in one declaration" {
    const unwired = DefinedRepository.DefaultWithoutDependencies();
    try std.testing.expect(kernel.contains(@TypeOf(unwired).InputServices, DefinedConfig));

    const root = DefinedRepository.Default();
    try std.testing.expectEqual(@as(usize, 0), @TypeOf(root).InputServices.len);
    try std.testing.expect(kernel.contains(@TypeOf(root).OutputServices, DefinedRepository));
    try std.testing.expect(!kernel.contains(@TypeOf(root).OutputServices, DefinedConfig));

    var runtime = try kernel.ManagedRuntime(@TypeOf(root)).make(std.testing.allocator, root, .{});
    defer runtime.deinit();
    try std.testing.expectEqual(@as(u32, 42), try runtime.run(read_defined_repository));
}

fn snapshotHasService(
    snapshot: *const kernel.ApplicationSnapshot,
    key: []const u8,
    exposed: bool,
) bool {
    for (snapshot.services) |service| {
        if (std.mem.eql(u8, service.key, key) and service.exposed == exposed) return true;
    }
    return false;
}

fn snapshotHasOperation(
    snapshot: *const kernel.ApplicationSnapshot,
    service_key: []const u8,
    operation: []const u8,
) bool {
    for (snapshot.services) |service| {
        if (!std.mem.eql(u8, service.key, service_key)) continue;
        for (service.operations) |candidate| {
            if (std.mem.eql(u8, candidate, operation)) return true;
        }
    }
    return false;
}

fn snapshotHasDependency(
    snapshot: *const kernel.ApplicationSnapshot,
    service_key: []const u8,
    provider_key: []const u8,
    consumer_key: []const u8,
) bool {
    for (snapshot.edges) |edge| {
        if (!std.mem.eql(u8, edge.service_key, service_key)) continue;

        var provider_matches = false;
        var consumer_matches = false;
        for (snapshot.layers) |layer| {
            if (layer.id == edge.provider_layer_id and std.mem.eql(u8, layer.provided_service_key, provider_key)) {
                provider_matches = true;
            }
            if (layer.id == edge.consumer_layer_id and std.mem.eql(u8, layer.provided_service_key, consumer_key)) {
                consumer_matches = true;
            }
        }
        if (provider_matches and consumer_matches) return true;
    }
    return false;
}

test "managed runtime owns causal recording and exposes the whole application through one bounded snapshot" {
    config_acquisitions = 0;
    config_finalizations = 0;

    const config_live = kernel.Layer.scoped(Config, error{}, .{}, acquireConfig, releaseConfig);
    const repository_live = kernel.Layer.sync(Repository, .{Config}, makeRepository);
    const health_live = kernel.Layer.sync(Health, .{Config}, makeHealth);
    const root = kernel.Layer.mergeAll(.{
        kernel.Layer.provide(repository_live, config_live),
        kernel.Layer.provide(health_live, config_live),
    });

    // No causal store is supplied: semantic runtime recording is a managed
    // runtime invariant, not an application opt-in.
    var runtime = try kernel.ManagedRuntime(@TypeOf(root)).make(std.testing.allocator, root, .{});
    defer runtime.deinit();

    try std.testing.expectEqual(@as(u32, 42), try runtime.run(read_repository));
    try std.testing.expect(try runtime.run(read_health));

    var snapshot = try runtime.inspect(std.testing.allocator, .{ .max_recent_events = 8 });
    defer snapshot.deinit();

    try std.testing.expectEqualStrings("zigeffect.application_snapshot.v1", snapshot.schema);
    try std.testing.expectEqual(kernel.ApplicationStatus.ready, snapshot.status);
    try std.testing.expectEqual(@as(usize, 3), snapshot.layers.len);
    try std.testing.expectEqual(@as(usize, 3), snapshot.services.len);
    try std.testing.expect(snapshotHasService(&snapshot, Config.service_key, false));
    try std.testing.expect(snapshotHasService(&snapshot, Repository.service_key, true));
    try std.testing.expect(snapshotHasOperation(&snapshot, Repository.service_key, "Repository.read"));
    try std.testing.expect(snapshotHasService(&snapshot, Health.service_key, true));
    try std.testing.expect(snapshotHasDependency(&snapshot, Config.service_key, Config.service_key, Repository.service_key));
    try std.testing.expect(snapshotHasDependency(&snapshot, Config.service_key, Config.service_key, Health.service_key));

    var saw_memoized_reuse = false;
    for (snapshot.layers) |layer| {
        if (std.mem.eql(u8, layer.provided_service_key, Config.service_key)) {
            saw_memoized_reuse = layer.memoized_reuses == 1;
        }
    }
    try std.testing.expect(saw_memoized_reuse);
    try std.testing.expect(snapshot.causal.retained_events > snapshot.causal.recent_events.len);
    try std.testing.expect(snapshot.causal.recent_events.len <= 8);
    try std.testing.expectEqual(@as(usize, 0), snapshot.causal.findings.len);
    try std.testing.expectEqual(@as(usize, 0), snapshot.causal.unresolvedFiberCount());

    const json = try snapshot.jsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema\":\"zigeffect.application_snapshot.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"services\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, Repository.service_key) != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"operations\":[\"Repository.read\"]") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"causal\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"recent_events\"") != null);
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{});
    defer parsed.deinit();
}

const ScopeLifecycleObservation = struct {
    opened: usize = 0,
    closed: usize = 0,
    acquired: usize = 0,
    finalized: usize = 0,
};

fn observeScopeLifecycle(state: ?*anyopaque, event: kernel.RuntimeEvent) ?u64 {
    const observation: *ScopeLifecycleObservation = @ptrCast(@alignCast(state.?));
    switch (event.kind) {
        .scope_opened => observation.opened += 1,
        .scope_closed => observation.closed += 1,
        .resource_acquired => observation.acquired += 1,
        .resource_finalized => observation.finalized += 1,
        else => {},
    }
    return null;
}

test "canonical scopes and resources emit through the shared runtime aspect pipeline" {
    config_acquisitions = 0;
    config_finalizations = 0;
    var observation = ScopeLifecycleObservation{};
    var metrics = fx.Metrics.init(std.testing.allocator);
    defer metrics.deinit();
    const aspects = [_]kernel.RuntimeAspect{.{
        .state = &observation,
        .on_event = observeScopeLifecycle,
    }};

    const root = kernel.Layer.scoped(Config, error{}, .{}, acquireConfig, releaseConfig);
    var runtime = try kernel.ManagedRuntime(@TypeOf(root)).make(std.testing.allocator, root, .{
        .aspects = &aspects,
        .observability = .{ .metrics = &metrics },
    });

    try std.testing.expect(observation.opened >= 1);
    try std.testing.expectEqual(@as(usize, 1), observation.acquired);
    try std.testing.expect(metrics.get("zigeffect.runtime.scopes.opened") >= 1);
    try std.testing.expectEqual(@as(i64, 1), metrics.get("zigeffect.runtime.resources.acquired"));

    runtime.deinit();
    try std.testing.expect(observation.closed >= 1);
    try std.testing.expectEqual(@as(usize, 1), observation.finalized);
    try std.testing.expect(metrics.get("zigeffect.runtime.scopes.closed") >= 1);
    try std.testing.expectEqual(@as(i64, 1), metrics.get("zigeffect.runtime.resources.finalized"));
}

const SemanticObservation = struct {
    count: usize = 0,
    latest: ?fx.CausalEvent = null,
};

fn ignoreRuntimeEvent(_: ?*anyopaque, _: kernel.RuntimeEvent) ?u64 {
    return null;
}

fn observeSemanticEvent(state: ?*anyopaque, event: fx.CausalEvent) ?u64 {
    const observation: *SemanticObservation = @ptrCast(@alignCast(state.?));
    observation.count += 1;
    observation.latest = event;
    return null;
}

test "semantic causal facts inherit run fiber and scope lineage through runtime aspects" {
    var observation = SemanticObservation{};
    const aspects = [_]kernel.RuntimeAspect{.{
        .state = &observation,
        .on_event = ignoreRuntimeEvent,
        .on_causal_event = observeSemanticEvent,
    }};
    const root = kernel.Layer.empty();
    var runtime = try kernel.ManagedRuntime(@TypeOf(root)).make(std.testing.allocator, root, .{
        .aspects = &aspects,
    });
    defer runtime.deinit();

    const Emit = kernel.Effect(void, error{}, .{});
    const emit = Emit.fromFn(struct {
        fn run(ctx: *Emit.Context) error{}!void {
            _ = ctx.recordCausal(.{
                .kind = .span_recorded,
                .service_key = "test/SemanticBoundary",
                .label = "semantic.operation",
                .status = "success",
            });
        }
    }.run);
    try runtime.run(emit);

    try std.testing.expectEqual(@as(usize, 1), observation.count);
    const event = observation.latest.?;
    try std.testing.expect(event.run_id != null);
    try std.testing.expect(event.parent_id != null);
    try std.testing.expect(event.fiber_id != null);
    try std.testing.expect(event.scope_id != null);
    try std.testing.expectEqualStrings("test/SemanticBoundary", event.service_key);
}

const ProbeExecutor = struct {
    spawned: usize = 0,
    joined: usize = 0,
    destroyed: usize = 0,

    fn spawn(raw: ?*anyopaque, job: fx.FiberJob) ?*anyopaque {
        const self: *ProbeExecutor = @ptrCast(@alignCast(raw.?));
        self.spawned += 1;
        job.run(job.context);
        return @ptrCast(self);
    }

    fn join(raw: ?*anyopaque, _: *anyopaque) void {
        const self: *ProbeExecutor = @ptrCast(@alignCast(raw.?));
        self.joined += 1;
    }

    fn destroy(raw: ?*anyopaque, _: *anyopaque) void {
        const self: *ProbeExecutor = @ptrCast(@alignCast(raw.?));
        self.destroyed += 1;
    }

    const vtable = fx.FiberExecutor.VTable{
        .spawn = spawn,
        .join = join,
        .destroy = destroy,
    };

    fn executor(self: *ProbeExecutor) fx.FiberExecutor {
        return .{ .context = self, .vtable = &vtable };
    }
};

test "canonical ManagedRuntime owns and uses its configured executor" {
    var probe = ProbeExecutor{};
    const root = kernel.Layer.empty();
    var runtime = try kernel.ManagedRuntime(@TypeOf(root)).make(
        std.testing.allocator,
        root,
        .{ .executor = probe.executor() },
    );
    defer runtime.deinit();

    const Probe = kernel.Effect(bool, error{}, .{});
    const effect = Probe.fromFn(struct {
        fn run(ctx: *Probe.Context) error{}!bool {
            return ctx.executor() != null;
        }
    }.run);

    try std.testing.expect(try runtime.run(effect));
    try std.testing.expectEqual(@as(usize, 1), probe.spawned);
    try std.testing.expectEqual(@as(usize, 1), probe.joined);
    try std.testing.expectEqual(@as(usize, 1), probe.destroyed);
}
