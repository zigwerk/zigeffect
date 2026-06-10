const std = @import("std");
const context_mod = @import("../core/context.zig");
const scope_mod = @import("../core/scope.zig");
const result = @import("../core/result.zig");
const dep_services = @import("../dependency/services.zig");
const dep_report = @import("../dependency/report.zig");
const schedule_mod = @import("../effect/schedule.zig");
const layer_mod = @import("../layer/layer.zig");
const runtime_mod = @import("../runtime/runtime.zig");
const fiber_mod = @import("../runtime/fiber.zig");
const clock_mod = @import("../services/clock.zig");
const logger_mod = @import("../services/logger.zig");
const config_mod = @import("../services/config.zig");
const metrics_mod = @import("../services/metrics.zig");
const tracing_mod = @import("../services/tracing.zig");
const fs_mod = @import("../services/memory_file_system.zig");
const id_generator_mod = @import("../services/id_generator.zig");

pub const Allocator = dep_services.Allocator;
pub const DependencyError = dep_services.DependencyError;
pub const Context = context_mod.Context;
pub const serviceNotFound = context_mod.serviceNotFound;
pub const Scope = scope_mod.Scope;
pub const Exit = result.Exit;
pub const DependencyReport = dep_report.DependencyReport;
pub const Schedule = schedule_mod.Schedule;
pub const Layer = layer_mod.Layer;
pub const ProvidedLayer = layer_mod.ProvidedLayer;
pub const Runtime = runtime_mod.Runtime;
pub const FiberStatus = fiber_mod.FiberStatus;
pub const Clock = clock_mod.Clock;
pub const FakeClock = clock_mod.FakeClock;
pub const Logger = logger_mod.Logger;
pub const LogLevel = logger_mod.LogLevel;
pub const Config = config_mod.Config;
pub const Metrics = metrics_mod.Metrics;
pub const Tracing = tracing_mod.Tracing;
pub const TraceId = tracing_mod.TraceId;
pub const SpanId = tracing_mod.SpanId;
pub const MemoryFileSystem = fs_mod.MemoryFileSystem;
pub const IdGenerator = id_generator_mod.IdGenerator;

fn appendOptionalU64(output: *std.ArrayList(u8), allocator: Allocator, value: ?u64) Allocator.Error!void {
    if (value) |number| {
        try output.print(allocator, "{d}", .{number});
    } else {
        try output.appendSlice(allocator, "null");
    }
}

fn appendAssertionHeader(output: *std.ArrayList(u8), allocator: Allocator, assertion: []const u8) Allocator.Error!void {
    try output.print(
        allocator,
        "zigeffect test assertion failed\nassertion: {s}\n",
        .{assertion},
    );
}

pub const TestFixtureRegistry = struct {
    allocator: Allocator,
    values: std.StringHashMap([]const u8),

    pub fn init(allocator: Allocator) TestFixtureRegistry {
        return .{
            .allocator = allocator,
            .values = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *TestFixtureRegistry) void {
        var iterator = self.values.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.values.deinit();
    }

    pub fn put(self: *TestFixtureRegistry, name: []const u8, value: []const u8) Allocator.Error!void {
        if (self.values.fetchRemove(name)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }

        try self.values.put(
            try self.allocator.dupe(u8, name),
            try self.allocator.dupe(u8, value),
        );
    }

    pub fn get(self: *TestFixtureRegistry, name: []const u8) ?[]const u8 {
        return self.values.get(name);
    }

    pub fn expect(self: *TestFixtureRegistry, name: []const u8, actual: []const u8) !void {
        const expected = self.get(name) orelse return error.ExpectedFixtureNotFound;
        try std.testing.expectEqualStrings(expected, actual);
    }
};

pub const TestServices = struct {
    logger: Logger,
    config: Config,
    metrics: Metrics,
    tracing: Tracing,
    fs: MemoryFileSystem,
    clock: FakeClock,
    id_generator: IdGenerator,

    pub fn init(allocator: Allocator) TestServices {
        return .{
            .logger = Logger.init(allocator),
            .config = Config.init(allocator),
            .metrics = Metrics.init(allocator),
            .tracing = Tracing.init(allocator),
            .fs = MemoryFileSystem.init(allocator),
            .clock = .{},
            .id_generator = IdGenerator.init(1),
        };
    }

    pub fn deinit(self: *TestServices) void {
        self.fs.deinit();
        self.tracing.deinit();
        self.metrics.deinit();
        self.config.deinit();
        self.logger.deinit();
    }

    pub fn service(self: *TestServices, comptime Service: type) *Service {
        if (Service == Logger) return &self.logger;
        if (Service == Config) return &self.config;
        if (Service == Metrics) return &self.metrics;
        if (Service == Tracing) return &self.tracing;
        if (Service == MemoryFileSystem) return &self.fs;
        if (Service == FakeClock) return &self.clock;
        if (Service == IdGenerator) return &self.id_generator;
        return serviceNotFound(TestServices, Service);
    }
};

pub const TestEnv = struct {
    allocator: Allocator,
    scope: Scope,
    services: TestServices,
    fixtures: TestFixtureRegistry,

    pub fn init(allocator: Allocator) Allocator.Error!TestEnv {
        return .{
            .allocator = allocator,
            .scope = Scope.init(allocator),
            .services = TestServices.init(allocator),
            .fixtures = TestFixtureRegistry.init(allocator),
        };
    }

    pub fn deinit(self: *TestEnv) void {
        self.scope.close();
        self.scope.deinit();
        self.fixtures.deinit();
        self.services.deinit();
    }

    pub fn layer(self: *TestEnv) ProvidedLayer(Layer(TestServices), .{ Logger, Config, Metrics, Tracing, MemoryFileSystem, Clock }) {
        return Layer(TestServices)
            .fromEnv(&self.services)
            .provides(.{ Logger, Config, Metrics, Tracing, MemoryFileSystem, Clock });
    }

    pub fn serviceLayer(self: *TestEnv, comptime services: anytype) ProvidedLayer(Layer(TestServices), services) {
        return Layer(TestServices)
            .fromEnv(&self.services)
            .provides(services);
    }

    pub fn loggerLayer(self: *TestEnv) ProvidedLayer(Layer(TestServices), .{Logger}) {
        return self.serviceLayer(.{Logger});
    }

    pub fn configLayer(self: *TestEnv) ProvidedLayer(Layer(TestServices), .{Config}) {
        return self.serviceLayer(.{Config});
    }

    pub fn metricsLayer(self: *TestEnv) ProvidedLayer(Layer(TestServices), .{Metrics}) {
        return self.serviceLayer(.{Metrics});
    }

    pub fn tracingLayer(self: *TestEnv) ProvidedLayer(Layer(TestServices), .{Tracing}) {
        return self.serviceLayer(.{Tracing});
    }

    pub fn fileSystemLayer(self: *TestEnv) ProvidedLayer(Layer(TestServices), .{MemoryFileSystem}) {
        return self.serviceLayer(.{MemoryFileSystem});
    }

    pub fn clockLayer(self: *TestEnv) ProvidedLayer(Layer(TestServices), .{Clock}) {
        return self.serviceLayer(.{Clock});
    }

    pub fn context(self: *TestEnv) Context(TestServices) {
        var ctx = Context(TestServices).init(self.allocator, &self.services, &self.scope);
        ctx.clock = &self.services.clock;
        return ctx;
    }

    pub fn runtime(self: *TestEnv) Runtime(TestServices) {
        return Runtime(TestServices)
            .init(self.allocator, &self.services)
            .withClock(&self.services.clock)
            .provides(.{ Logger, Config, Metrics, Tracing, MemoryFileSystem, Clock });
    }

    pub fn run(self: *TestEnv, effect: anytype) (Allocator.Error || DependencyError || @TypeOf(effect).FailureType)!@TypeOf(effect).SuccessType {
        var runner = self.runtime();
        return runner.run(effect);
    }

    pub fn exit(self: *TestEnv, effect: anytype) Exit(@TypeOf(effect).SuccessType, @TypeOf(effect).FailureType) {
        var runner = self.runtime();
        return runner.exit(effect);
    }

    pub fn expectLog(self: *TestEnv, expected: []const u8) !void {
        for (self.services.logger.entries.items) |entry| {
            if (std.mem.eql(u8, entry, expected)) return;
        }
        return error.ExpectedLogNotFound;
    }

    pub fn formatLogAssertionReport(self: *TestEnv, expected: []const u8) Allocator.Error![]const u8 {
        var output = std.ArrayList(u8).empty;
        errdefer output.deinit(self.allocator);

        try appendAssertionHeader(&output, self.allocator, "log contains");
        try output.print(
            self.allocator,
            "expected: {s}\nactual logs: {d}\ndetails:\n",
            .{ expected, self.services.logger.entries.items.len },
        );

        if (self.services.logger.entries.items.len == 0) {
            try output.appendSlice(self.allocator, "- <none>\n");
        } else {
            for (self.services.logger.entries.items) |entry| {
                try output.print(self.allocator, "- {s}\n", .{entry});
            }
        }

        return output.toOwnedSlice(self.allocator);
    }

    pub fn expectStructuredLog(self: *TestEnv, level: LogLevel, expected: []const u8) !void {
        for (self.services.logger.structured_entries.items) |entry| {
            if (entry.level == level and std.mem.eql(u8, entry.message, expected)) return;
        }
        return error.ExpectedLogNotFound;
    }

    pub fn expectTrace(self: *TestEnv, expected: []const u8) !void {
        for (self.services.tracing.events.items) |entry| {
            if (std.mem.eql(u8, entry, expected)) return;
        }
        return error.ExpectedTraceNotFound;
    }

    pub fn expectSpanEnded(self: *TestEnv, id: SpanId) !void {
        try std.testing.expectEqual(true, self.services.tracing.spanEnded(id) orelse return error.ExpectedTraceNotFound);
    }

    pub fn expectSpanParent(self: *TestEnv, child: SpanId, parent: SpanId) !void {
        try std.testing.expectEqual(parent, self.services.tracing.spanParent(child) orelse return error.ExpectedTraceNotFound);
    }

    pub fn expectSpanTrace(self: *TestEnv, id: SpanId, trace_id: TraceId) !void {
        try std.testing.expectEqual(trace_id, self.services.tracing.spanTrace(id) orelse return error.ExpectedTraceNotFound);
    }

    pub fn expectMetric(self: *TestEnv, name: []const u8, expected: i64) !void {
        try std.testing.expectEqual(expected, self.services.metrics.get(name));
    }

    pub fn expectHistogram(self: *TestEnv, name: []const u8, count: usize, sum: i64, min: i64, max: i64) !void {
        const histogram = self.services.metrics.histogram(name) orelse return error.ExpectedMetricNotFound;
        try std.testing.expectEqual(count, histogram.count);
        try std.testing.expectEqual(sum, histogram.sum);
        try std.testing.expectEqual(min, histogram.min);
        try std.testing.expectEqual(max, histogram.max);
    }

    pub fn expectFile(self: *TestEnv, path: []const u8, expected: []const u8) !void {
        try std.testing.expectEqualStrings(expected, self.services.fs.readFile(path) orelse return error.ExpectedFileNotFound);
    }

    pub fn putFixture(self: *TestEnv, name: []const u8, value: []const u8) Allocator.Error!void {
        try self.fixtures.put(name, value);
    }

    pub fn expectGolden(self: *TestEnv, name: []const u8, actual: []const u8) !void {
        try self.fixtures.expect(name, actual);
    }
};

pub fn expectDependencyReportMissing(report: *const DependencyReport, service: []const u8) !void {
    try std.testing.expect(report.hasMissing(service));
}

pub fn expectDependencyReportDuplicate(report: *const DependencyReport, service: []const u8) !void {
    try std.testing.expect(report.hasDuplicate(service));
}

pub fn expectCauseFinalizerFailure(cause: anytype, expected: []const u8) !void {
    try std.testing.expect(result.causeHasFinalizerFailure(cause, expected));
}

pub fn expectCauseDefect(cause: anytype, expected: []const u8) !void {
    try std.testing.expect(result.causeHasDefect(cause, expected));
}

pub fn expectCauseInterruption(cause: anytype, fiber_id: u64) !void {
    try std.testing.expect(result.causeHasInterruption(cause, fiber_id));
}

pub fn formatScheduleDelayAssertionReport(
    allocator: Allocator,
    attempt: usize,
    expected: ?u64,
    actual: ?u64,
) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try appendAssertionHeader(&output, allocator, "schedule delay");
    try output.print(allocator, "attempt: {d}\nexpected: ", .{attempt});
    try appendOptionalU64(&output, allocator, expected);
    try output.appendSlice(allocator, "\nactual: ");
    try appendOptionalU64(&output, allocator, actual);
    try output.appendSlice(allocator, "\ndetails:\n- schedule decision did not match the expected delay\n");

    return output.toOwnedSlice(allocator);
}

pub fn formatFiberStatusAssertionReport(
    allocator: Allocator,
    expected: FiberStatus,
    actual: FiberStatus,
) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try appendAssertionHeader(&output, allocator, "fiber status");
    try output.print(
        allocator,
        "expected: {s}\nactual: {s}\ndetails:\n- fiber lifecycle state did not match the expected status\n",
        .{ @tagName(expected), @tagName(actual) },
    );

    return output.toOwnedSlice(allocator);
}

pub fn formatQueueStateAssertionReport(
    allocator: Allocator,
    expected_len: usize,
    actual_len: usize,
    expected_shutdown: bool,
    actual_shutdown: bool,
) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try appendAssertionHeader(&output, allocator, "queue state");
    try output.print(
        allocator,
        "expected len: {d}\nactual len: {d}\nexpected shutdown: {}\nactual shutdown: {}\ndetails:\n- queue length or shutdown state did not match\n",
        .{ expected_len, actual_len, expected_shutdown, actual_shutdown },
    );

    return output.toOwnedSlice(allocator);
}

pub fn expectScheduleDelay(schedule: *Schedule, attempt: usize, expected: ?u64) !void {
    try std.testing.expectEqual(expected, schedule.nextDelay(attempt));
}

pub fn expectFiberStatus(fiber: anytype, expected: FiberStatus) !void {
    try std.testing.expectEqual(expected, fiber.status());
}

pub fn expectQueueLen(queue: anytype, expected: usize) !void {
    try std.testing.expectEqual(expected, queue.len());
}

pub fn expectQueueShutdown(queue: anytype, expected: bool) !void {
    try std.testing.expectEqual(expected, queue.isShutdown());
}
