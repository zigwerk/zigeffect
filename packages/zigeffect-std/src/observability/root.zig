const std = @import("std");
const Json = @import("../json/root.zig");
const Secrets = @import("../secrets/root.zig");
const StdService = @import("../service/root.zig");
const fx = @import("zigeffect");

pub const Level = fx.services.logger.LogLevel;
pub const Field = fx.services.logger.LogField;
pub const LogContext = fx.services.logger.LogContext;
pub const Attribute = fx.services.tracing.TraceAttribute;
pub const SpanId = fx.services.tracing.SpanId;

pub const Recorder = struct {
    allocator: std.mem.Allocator,
    logger: fx.services.logger.Logger,
    metrics: fx.services.metrics.Metrics,
    tracing: fx.services.tracing.Tracing,

    pub fn init(allocator: std.mem.Allocator) Recorder {
        return .{
            .allocator = allocator,
            .logger = fx.services.logger.Logger.init(allocator),
            .metrics = fx.services.metrics.Metrics.init(allocator),
            .tracing = fx.services.tracing.Tracing.init(allocator),
        };
    }

    pub fn deinit(self: *Recorder) void {
        self.tracing.deinit();
        self.metrics.deinit();
        self.logger.deinit();
    }

    pub fn log(self: *Recorder, level: Level, message: []const u8, fields: []const Field) std.mem.Allocator.Error!void {
        try self.logger.logFields(level, message, fields);
    }

    pub fn logWithContext(
        self: *Recorder,
        level: Level,
        message: []const u8,
        fields: []const Field,
        context: LogContext,
    ) std.mem.Allocator.Error!void {
        try self.logger.logWithContext(level, message, fields, context);
    }

    pub fn increment(self: *Recorder, name: []const u8, amount: i64) std.mem.Allocator.Error!void {
        try self.metrics.increment(name, amount);
    }

    pub fn gauge(self: *Recorder, name: []const u8, value: i64) std.mem.Allocator.Error!void {
        try self.metrics.gauge(name, value);
    }

    pub fn observe(self: *Recorder, name: []const u8, value: i64) std.mem.Allocator.Error!void {
        try self.metrics.observe(name, value);
    }

    pub fn startSpan(
        self: *Recorder,
        name: []const u8,
        parent_id: ?SpanId,
        attributes: []const Attribute,
    ) std.mem.Allocator.Error!SpanId {
        return self.tracing.startSpanWithAttributes(name, parent_id, attributes);
    }

    pub fn endSpan(self: *Recorder, id: SpanId) std.mem.Allocator.Error!void {
        try self.tracing.endSpan(id);
    }

    pub fn workbenchJsonAlloc(self: *Recorder, allocator: std.mem.Allocator, label: []const u8) std.mem.Allocator.Error![]const u8 {
        var output = std.ArrayList(u8).empty;
        errdefer output.deinit(allocator);

        try output.append(allocator, '{');
        try appendJsonFieldName(&output, allocator, "schema");
        try output.append(allocator, ':');
        try appendJsonString(&output, allocator, "zigeffect.std.observability.v1");
        try output.append(allocator, ',');
        try appendJsonFieldName(&output, allocator, "label");
        try output.append(allocator, ':');
        try appendRedactedJsonString(&output, allocator, label);
        try output.append(allocator, ',');
        try appendJsonFieldName(&output, allocator, "logs");
        try output.append(allocator, ':');
        try self.appendLogsJson(&output, allocator);
        try output.append(allocator, ',');
        try appendJsonFieldName(&output, allocator, "metrics");
        try output.append(allocator, ':');
        try self.appendMetricsJson(&output, allocator);
        try output.append(allocator, ',');
        try appendJsonFieldName(&output, allocator, "spans");
        try output.append(allocator, ':');
        try self.appendSpansJson(&output, allocator);
        try output.append(allocator, '}');

        return output.toOwnedSlice(allocator);
    }

    pub fn otlpJsonAlloc(self: *Recorder, allocator: std.mem.Allocator, service_name: []const u8) std.mem.Allocator.Error![]const u8 {
        var output = std.ArrayList(u8).empty;
        errdefer output.deinit(allocator);

        try output.append(allocator, '{');
        try appendJsonFieldName(&output, allocator, "resourceLogs");
        try output.appendSlice(allocator, ":[{\"resource\":{\"attributes\":[{\"key\":\"service.name\",\"value\":");
        try appendRedactedJsonString(&output, allocator, service_name);
        try output.appendSlice(allocator, "}]},\"scopeLogs\":[{\"logRecords\":");
        try self.appendLogsJson(&output, allocator);
        try output.appendSlice(allocator, "}]}],");
        try appendJsonFieldName(&output, allocator, "resourceMetrics");
        try output.appendSlice(allocator, ":[{\"resource\":{\"attributes\":[{\"key\":\"service.name\",\"value\":");
        try appendRedactedJsonString(&output, allocator, service_name);
        try output.appendSlice(allocator, "}]},\"scopeMetrics\":[{\"metrics\":");
        try self.appendOtlpMetricsJson(&output, allocator);
        try output.appendSlice(allocator, "}]}],");
        try appendJsonFieldName(&output, allocator, "resourceSpans");
        try output.appendSlice(allocator, ":[{\"resource\":{\"attributes\":[{\"key\":\"service.name\",\"value\":");
        try appendRedactedJsonString(&output, allocator, service_name);
        try output.appendSlice(allocator, "}]},\"scopeSpans\":[{\"spans\":");
        try self.appendSpansJson(&output, allocator);
        try output.appendSlice(allocator, "}]}]}");

        return output.toOwnedSlice(allocator);
    }

    fn appendLogsJson(self: *const Recorder, output: *std.ArrayList(u8), allocator: std.mem.Allocator) std.mem.Allocator.Error!void {
        try output.append(allocator, '[');
        for (self.logger.structured_entries.items, 0..) |entry, index| {
            if (index != 0) try output.append(allocator, ',');
            try output.append(allocator, '{');
            try appendJsonFieldName(output, allocator, "level");
            try output.append(allocator, ':');
            try appendJsonString(output, allocator, @tagName(entry.level));
            try output.append(allocator, ',');
            try appendJsonFieldName(output, allocator, "message");
            try output.append(allocator, ':');
            try appendRedactedJsonString(output, allocator, entry.message);
            if (entry.timestamp_ms) |timestamp| {
                try output.append(allocator, ',');
                try appendJsonFieldName(output, allocator, "timestamp_ms");
                try output.print(allocator, ":{}", .{timestamp});
            }
            if (entry.trace_id) |trace_id| {
                try output.append(allocator, ',');
                try appendJsonFieldName(output, allocator, "trace_id");
                try output.print(allocator, ":{}", .{trace_id});
            }
            if (entry.span_id) |span_id| {
                try output.append(allocator, ',');
                try appendJsonFieldName(output, allocator, "span_id");
                try output.print(allocator, ":{}", .{span_id});
            }
            try output.append(allocator, ',');
            try appendJsonFieldName(output, allocator, "fields");
            try output.append(allocator, ':');
            try appendFieldsJson(output, allocator, entry.fields);
            try output.append(allocator, '}');
        }
        try output.append(allocator, ']');
    }

    fn appendMetricsJson(self: *Recorder, output: *std.ArrayList(u8), allocator: std.mem.Allocator) std.mem.Allocator.Error!void {
        var snapshot = try self.metrics.snapshot(allocator);
        defer snapshot.deinit();

        try sortCounters(snapshot.counters);
        try sortHistograms(snapshot.histograms);

        try output.append(allocator, '{');
        try appendJsonFieldName(output, allocator, "counters");
        try output.append(allocator, ':');
        try appendCountersJson(output, allocator, snapshot.counters);
        try output.append(allocator, ',');
        try appendJsonFieldName(output, allocator, "histograms");
        try output.append(allocator, ':');
        try appendHistogramsJson(output, allocator, snapshot.histograms);
        try output.append(allocator, '}');
    }

    fn appendOtlpMetricsJson(self: *Recorder, output: *std.ArrayList(u8), allocator: std.mem.Allocator) std.mem.Allocator.Error!void {
        var snapshot = try self.metrics.snapshot(allocator);
        defer snapshot.deinit();

        try sortCounters(snapshot.counters);
        try sortHistograms(snapshot.histograms);

        try output.append(allocator, '[');
        var first = true;
        for (snapshot.counters) |counter| {
            if (!first) try output.append(allocator, ',');
            first = false;
            try output.append(allocator, '{');
            try appendJsonFieldName(output, allocator, "name");
            try output.append(allocator, ':');
            try appendRedactedJsonString(output, allocator, counter.name);
            try output.appendSlice(allocator, ",\"kind\":\"counter\",\"value\":");
            try output.print(allocator, "{}", .{counter.value});
            try output.append(allocator, '}');
        }
        for (snapshot.histograms) |histogram| {
            if (!first) try output.append(allocator, ',');
            first = false;
            try output.append(allocator, '{');
            try appendJsonFieldName(output, allocator, "name");
            try output.append(allocator, ':');
            try appendRedactedJsonString(output, allocator, histogram.name);
            try output.appendSlice(allocator, ",\"kind\":\"histogram\",\"count\":");
            try output.print(allocator, "{}", .{histogram.value.count});
            try output.appendSlice(allocator, ",\"sum\":");
            try output.print(allocator, "{}", .{histogram.value.sum});
            try output.append(allocator, '}');
        }
        try output.append(allocator, ']');
    }

    fn appendSpansJson(self: *const Recorder, output: *std.ArrayList(u8), allocator: std.mem.Allocator) std.mem.Allocator.Error!void {
        try output.append(allocator, '[');
        for (self.tracing.spans.items, 0..) |span, index| {
            if (index != 0) try output.append(allocator, ',');
            try output.append(allocator, '{');
            try appendJsonFieldName(output, allocator, "id");
            try output.print(allocator, ":{}", .{span.id});
            try output.append(allocator, ',');
            try appendJsonFieldName(output, allocator, "trace_id");
            try output.print(allocator, ":{}", .{span.trace_id});
            try output.append(allocator, ',');
            try appendJsonFieldName(output, allocator, "parent_id");
            if (span.parent_id) |parent_id| {
                try output.print(allocator, ":{}", .{parent_id});
            } else {
                try output.appendSlice(allocator, ":null");
            }
            try output.append(allocator, ',');
            try appendJsonFieldName(output, allocator, "name");
            try output.append(allocator, ':');
            try appendRedactedJsonString(output, allocator, span.name);
            try output.append(allocator, ',');
            try appendJsonFieldName(output, allocator, "ended");
            try output.appendSlice(allocator, if (span.ended) ":true" else ":false");
            try output.append(allocator, ',');
            try appendJsonFieldName(output, allocator, "attributes");
            try output.append(allocator, ':');
            try appendAttributesJson(output, allocator, span.attributes);
            try output.append(allocator, '}');
        }
        try output.append(allocator, ']');
    }
};

pub fn LogEffect(comptime EffectEnv: type) type {
    return struct {
        pub const SuccessType = void;
        pub const FailureType = std.mem.Allocator.Error;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{Recorder};

        level: Level,
        message: []const u8,
        fields: []const Field,

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(self: @This(), ctx: *fx.Context(EffectEnv)) FailureType!void {
            const recorder = ctx.service(Recorder);
            recorder.log(self.level, self.message, self.fields) catch |err| {
                _ = StdService.recordOperation(ctx, Recorder, "log", "failure", self.message);
                return err;
            };
            _ = StdService.recordOperation(ctx, Recorder, "log", @tagName(self.level), self.message);
        }
    };
}

pub fn IncrementEffect(comptime EffectEnv: type) type {
    return struct {
        pub const SuccessType = void;
        pub const FailureType = std.mem.Allocator.Error;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{Recorder};

        name: []const u8,
        amount: i64,

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(self: @This(), ctx: *fx.Context(EffectEnv)) FailureType!void {
            const recorder = ctx.service(Recorder);
            recorder.increment(self.name, self.amount) catch |err| {
                _ = StdService.recordOperation(ctx, Recorder, "increment", "failure", self.name);
                return err;
            };
            _ = StdService.recordOperation(ctx, Recorder, "increment", "success", self.name);
        }
    };
}

pub fn GaugeEffect(comptime EffectEnv: type) type {
    return struct {
        pub const SuccessType = void;
        pub const FailureType = std.mem.Allocator.Error;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{Recorder};

        name: []const u8,
        value: i64,

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(self: @This(), ctx: *fx.Context(EffectEnv)) FailureType!void {
            const recorder = ctx.service(Recorder);
            recorder.gauge(self.name, self.value) catch |err| {
                _ = StdService.recordOperation(ctx, Recorder, "gauge", "failure", self.name);
                return err;
            };
            _ = StdService.recordOperation(ctx, Recorder, "gauge", "success", self.name);
        }
    };
}

pub fn ObserveEffect(comptime EffectEnv: type) type {
    return struct {
        pub const SuccessType = void;
        pub const FailureType = std.mem.Allocator.Error;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{Recorder};

        name: []const u8,
        value: i64,

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(self: @This(), ctx: *fx.Context(EffectEnv)) FailureType!void {
            const recorder = ctx.service(Recorder);
            recorder.observe(self.name, self.value) catch |err| {
                _ = StdService.recordOperation(ctx, Recorder, "observe", "failure", self.name);
                return err;
            };
            _ = StdService.recordOperation(ctx, Recorder, "observe", "success", self.name);
        }
    };
}

pub fn StartSpanEffect(comptime EffectEnv: type) type {
    return struct {
        pub const SuccessType = SpanId;
        pub const FailureType = std.mem.Allocator.Error;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{Recorder};

        name: []const u8,
        parent_id: ?SpanId,
        attributes: []const Attribute,

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(self: @This(), ctx: *fx.Context(EffectEnv)) FailureType!SpanId {
            const recorder = ctx.service(Recorder);
            const span_id = recorder.startSpan(self.name, self.parent_id, self.attributes) catch |err| {
                _ = StdService.recordOperation(ctx, Recorder, "span.start", "failure", self.name);
                return err;
            };
            _ = StdService.recordOperation(ctx, Recorder, "span.start", "success", self.name);
            return span_id;
        }
    };
}

pub fn EndSpanEffect(comptime EffectEnv: type) type {
    return struct {
        pub const SuccessType = void;
        pub const FailureType = std.mem.Allocator.Error;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{Recorder};

        id: SpanId,

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(self: @This(), ctx: *fx.Context(EffectEnv)) FailureType!void {
            const recorder = ctx.service(Recorder);
            recorder.endSpan(self.id) catch |err| {
                _ = StdService.recordOperation(ctx, Recorder, "span.end", "failure", "span");
                return err;
            };
            _ = StdService.recordOperation(ctx, Recorder, "span.end", "success", "span");
        }
    };
}

pub fn WorkbenchJsonEffect(comptime EffectEnv: type) type {
    return struct {
        pub const SuccessType = []const u8;
        pub const FailureType = std.mem.Allocator.Error;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{Recorder};

        label: []const u8,

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(self: @This(), ctx: *fx.Context(EffectEnv)) FailureType![]const u8 {
            const recorder = ctx.service(Recorder);
            const artifact = recorder.workbenchJsonAlloc(ctx.allocator, self.label) catch |err| {
                _ = StdService.recordOperation(ctx, Recorder, "workbench.json", "failure", self.label);
                return err;
            };
            _ = StdService.recordOperation(ctx, Recorder, "workbench.json", "success", self.label);
            return artifact;
        }
    };
}

pub fn OtlpJsonEffect(comptime EffectEnv: type) type {
    return struct {
        pub const SuccessType = []const u8;
        pub const FailureType = std.mem.Allocator.Error;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{Recorder};

        service_name: []const u8,

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(self: @This(), ctx: *fx.Context(EffectEnv)) FailureType![]const u8 {
            const recorder = ctx.service(Recorder);
            const artifact = recorder.otlpJsonAlloc(ctx.allocator, self.service_name) catch |err| {
                _ = StdService.recordOperation(ctx, Recorder, "otlp.json", "failure", self.service_name);
                return err;
            };
            _ = StdService.recordOperation(ctx, Recorder, "otlp.json", "success", self.service_name);
            return artifact;
        }
    };
}

pub fn logEffect(comptime EffectEnv: type, level: Level, message: []const u8, fields: []const Field) LogEffect(EffectEnv) {
    return .{ .level = level, .message = message, .fields = fields };
}

pub fn incrementEffect(comptime EffectEnv: type, name: []const u8, amount: i64) IncrementEffect(EffectEnv) {
    return .{ .name = name, .amount = amount };
}

pub fn gaugeEffect(comptime EffectEnv: type, name: []const u8, value: i64) GaugeEffect(EffectEnv) {
    return .{ .name = name, .value = value };
}

pub fn observeEffect(comptime EffectEnv: type, name: []const u8, value: i64) ObserveEffect(EffectEnv) {
    return .{ .name = name, .value = value };
}

pub fn startSpanEffect(
    comptime EffectEnv: type,
    name: []const u8,
    parent_id: ?SpanId,
    attributes: []const Attribute,
) StartSpanEffect(EffectEnv) {
    return .{ .name = name, .parent_id = parent_id, .attributes = attributes };
}

pub fn endSpanEffect(comptime EffectEnv: type, id: SpanId) EndSpanEffect(EffectEnv) {
    return .{ .id = id };
}

pub fn workbenchJsonEffect(comptime EffectEnv: type, label: []const u8) WorkbenchJsonEffect(EffectEnv) {
    return .{ .label = label };
}

pub fn otlpJsonEffect(comptime EffectEnv: type, service_name: []const u8) OtlpJsonEffect(EffectEnv) {
    return .{ .service_name = service_name };
}

fn appendJsonFieldName(output: *std.ArrayList(u8), allocator: std.mem.Allocator, name: []const u8) std.mem.Allocator.Error!void {
    try appendJsonString(output, allocator, name);
}

fn appendJsonString(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: []const u8) std.mem.Allocator.Error!void {
    const escaped = try Json.escapeStringAlloc(allocator, value);
    defer allocator.free(escaped);

    try output.print(allocator, "\"{s}\"", .{escaped});
}

fn appendRedactedJsonString(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: []const u8) std.mem.Allocator.Error!void {
    const redacted = try Secrets.redactAlloc(allocator, value);
    defer allocator.free(redacted);
    try appendJsonString(output, allocator, redacted);
}

fn appendFieldsJson(output: *std.ArrayList(u8), allocator: std.mem.Allocator, fields: []const Field) std.mem.Allocator.Error!void {
    try output.append(allocator, '[');
    for (fields, 0..) |field, index| {
        if (index != 0) try output.append(allocator, ',');
        try output.append(allocator, '{');
        try appendJsonFieldName(output, allocator, "key");
        try output.append(allocator, ':');
        try appendRedactedJsonString(output, allocator, field.key);
        try output.append(allocator, ',');
        try appendJsonFieldName(output, allocator, "value");
        try output.append(allocator, ':');
        try appendRedactedJsonString(output, allocator, field.value);
        try output.append(allocator, '}');
    }
    try output.append(allocator, ']');
}

fn appendAttributesJson(output: *std.ArrayList(u8), allocator: std.mem.Allocator, attributes: []const Attribute) std.mem.Allocator.Error!void {
    try output.append(allocator, '[');
    for (attributes, 0..) |attribute, index| {
        if (index != 0) try output.append(allocator, ',');
        try output.append(allocator, '{');
        try appendJsonFieldName(output, allocator, "key");
        try output.append(allocator, ':');
        try appendRedactedJsonString(output, allocator, attribute.key);
        try output.append(allocator, ',');
        try appendJsonFieldName(output, allocator, "value");
        try output.append(allocator, ':');
        try appendRedactedJsonString(output, allocator, attribute.value);
        try output.append(allocator, '}');
    }
    try output.append(allocator, ']');
}

fn appendCountersJson(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    counters: []const fx.services.metrics.CounterSnapshot,
) std.mem.Allocator.Error!void {
    try output.append(allocator, '[');
    for (counters, 0..) |counter, index| {
        if (index != 0) try output.append(allocator, ',');
        try output.append(allocator, '{');
        try appendJsonFieldName(output, allocator, "name");
        try output.append(allocator, ':');
        try appendRedactedJsonString(output, allocator, counter.name);
        try output.append(allocator, ',');
        try appendJsonFieldName(output, allocator, "value");
        try output.print(allocator, ":{}", .{counter.value});
        try output.append(allocator, '}');
    }
    try output.append(allocator, ']');
}

fn appendHistogramsJson(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    histograms: []const fx.services.metrics.HistogramSnapshot,
) std.mem.Allocator.Error!void {
    try output.append(allocator, '[');
    for (histograms, 0..) |histogram, index| {
        if (index != 0) try output.append(allocator, ',');
        try output.append(allocator, '{');
        try appendJsonFieldName(output, allocator, "name");
        try output.append(allocator, ':');
        try appendRedactedJsonString(output, allocator, histogram.name);
        try output.appendSlice(allocator, ",\"count\":");
        try output.print(allocator, "{}", .{histogram.value.count});
        try output.appendSlice(allocator, ",\"sum\":");
        try output.print(allocator, "{}", .{histogram.value.sum});
        try output.appendSlice(allocator, ",\"min\":");
        try output.print(allocator, "{}", .{histogram.value.min});
        try output.appendSlice(allocator, ",\"max\":");
        try output.print(allocator, "{}", .{histogram.value.max});
        try output.append(allocator, '}');
    }
    try output.append(allocator, ']');
}

fn sortCounters(counters: []fx.services.metrics.CounterSnapshot) std.mem.Allocator.Error!void {
    std.mem.sort(fx.services.metrics.CounterSnapshot, counters, {}, struct {
        fn lessThan(_: void, left: fx.services.metrics.CounterSnapshot, right: fx.services.metrics.CounterSnapshot) bool {
            return std.mem.lessThan(u8, left.name, right.name);
        }
    }.lessThan);
}

fn sortHistograms(histograms: []fx.services.metrics.HistogramSnapshot) std.mem.Allocator.Error!void {
    std.mem.sort(fx.services.metrics.HistogramSnapshot, histograms, {}, struct {
        fn lessThan(_: void, left: fx.services.metrics.HistogramSnapshot, right: fx.services.metrics.HistogramSnapshot) bool {
            return std.mem.lessThan(u8, left.name, right.name);
        }
    }.lessThan);
}

test "Observability effects log metrics spans and causal facts" {
    const zstd = @import("../root.zig");

    var recorder = Recorder.init(std.testing.allocator);
    defer recorder.deinit();

    var provider = zstd.Service.Provider(.{Recorder}).init(.{&recorder});
    var store = zstd.fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var runtime = zstd.fx.Runtime(@TypeOf(provider)).init(std.testing.allocator, &provider)
        .provides(.{Recorder})
        .withCausalStore(&store);

    try runtime.run(logEffect(@TypeOf(provider), .info, "local compile token=abc123", &.{}));
    try runtime.run(incrementEffect(@TypeOf(provider), "agent.runs", 1));
    try runtime.run(gaugeEffect(@TypeOf(provider), "queue.depth", 2));
    try runtime.run(observeEffect(@TypeOf(provider), "build.ms", 42));
    const span_id = try runtime.run(startSpanEffect(@TypeOf(provider), "codex build span", null, &.{}));
    try runtime.run(endSpanEffect(@TypeOf(provider), span_id));

    try std.testing.expectEqual(@as(usize, 1), recorder.logger.structured_entries.items.len);
    try std.testing.expectEqual(@as(i64, 1), recorder.metrics.get("agent.runs"));
    try std.testing.expectEqual(@as(i64, 2), recorder.metrics.get("queue.depth"));
    try std.testing.expect(recorder.metrics.histogram("build.ms") != null);
    try std.testing.expectEqual(true, recorder.tracing.spanEnded(span_id).?);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    const log_event_index = StdService.findOperation(snapshot, Recorder, "log", "info");
    try std.testing.expect(log_event_index != null);
    try std.testing.expect(StdService.hasOperation(snapshot, Recorder, "increment", "success"));
    try std.testing.expect(StdService.hasOperation(snapshot, Recorder, "gauge", "success"));
    try std.testing.expect(StdService.hasOperation(snapshot, Recorder, "observe", "success"));
    try std.testing.expect(StdService.hasOperation(snapshot, Recorder, "span.start", "success"));
    try std.testing.expect(StdService.hasOperation(snapshot, Recorder, "span.end", "success"));
    try std.testing.expect(std.mem.indexOf(u8, snapshot.events[log_event_index.?].redacted_detail, "abc123") == null);
}

test "Observability exports redacted workbench and otlp json artifacts" {
    var recorder = Recorder.init(std.testing.allocator);
    defer recorder.deinit();

    try recorder.log(.warn, "authorization: Bearer local-token", &.{});
    _ = try recorder.startSpan("postgres://user:pass@localhost/db", null, &.{});
    try recorder.increment("agent.sessions", 3);
    try recorder.observe("agent.latency_ms", 99);

    const workbench = try recorder.workbenchJsonAlloc(std.testing.allocator, "dev-session token=abc123");
    defer std.testing.allocator.free(workbench);
    try std.testing.expect(std.mem.indexOf(u8, workbench, "\"schema\":\"zigeffect.std.observability.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, workbench, "abc123") == null);
    try std.testing.expect(std.mem.indexOf(u8, workbench, "local-token") == null);
    try std.testing.expect(std.mem.indexOf(u8, workbench, "[REDACTED]") != null);

    const otlp = try recorder.otlpJsonAlloc(std.testing.allocator, "zigeffect-local");
    defer std.testing.allocator.free(otlp);
    try std.testing.expect(std.mem.indexOf(u8, otlp, "\"resourceLogs\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, otlp, "\"resourceMetrics\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, otlp, "\"resourceSpans\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, otlp, "pass@localhost") == null);
}
