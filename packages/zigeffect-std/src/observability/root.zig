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

pub const API = struct {
    pub const operations: []const []const u8 = &.{
        "Observability.log",
        "Observability.increment",
        "Observability.gauge",
        "Observability.observe",
        "Observability.startSpan",
        "Observability.endSpan",
        "Observability.workbenchJson",
        "Observability.otlpJson",
    };
    recorder: *Recorder,
};

pub const Observability = fx.kernel.Service("zigeffect/std/Observability", API);

pub fn layer(recorder: *Recorder) @TypeOf(fx.kernel.Layer.succeed(Observability, API{ .recorder = recorder })) {
    return fx.kernel.Layer.succeed(Observability, .{ .recorder = recorder });
}

const LogInput = struct { level: Level, message: []const u8, fields: []const Field };
pub fn log(level: Level, message: []const u8, fields: []const Field) fx.kernel.Effect(void, std.mem.Allocator.Error, .{Observability}).Stateful(LogInput) {
    const Log = fx.kernel.Effect(void, std.mem.Allocator.Error, .{Observability});
    return Log.fromState(LogInput, .{ .level = level, .message = message, .fields = fields }, struct {
        fn run(input: LogInput, ctx: *Log.Context) std.mem.Allocator.Error!void {
            ctx.service(Observability).recorder.log(input.level, input.message, input.fields) catch |failure| {
                _ = StdService.recordSemantic(ctx, .log_recorded, Observability.service_key, "Observability.log", "failure", @errorName(failure));
                return failure;
            };
            _ = StdService.recordSemantic(ctx, .log_recorded, Observability.service_key, "Observability.log", @tagName(input.level), input.message);
        }
    }.run);
}

const MetricInput = struct { name: []const u8, value: i64 };
fn metric(comptime kind: enum { increment, gauge, observe }, input: MetricInput) fx.kernel.Effect(void, std.mem.Allocator.Error, .{Observability}).Stateful(MetricInput) {
    const Metric = fx.kernel.Effect(void, std.mem.Allocator.Error, .{Observability});
    return Metric.fromState(MetricInput, input, struct {
        fn run(value: MetricInput, ctx: *Metric.Context) std.mem.Allocator.Error!void {
            const recorder = ctx.service(Observability).recorder;
            const result = switch (kind) {
                .increment => recorder.increment(value.name, value.value),
                .gauge => recorder.gauge(value.name, value.value),
                .observe => recorder.observe(value.name, value.value),
            };
            result catch |failure| {
                _ = StdService.recordSemantic(ctx, .metric_recorded, Observability.service_key, "Observability." ++ @tagName(kind), "failure", @errorName(failure));
                return failure;
            };
            _ = StdService.recordSemantic(ctx, .metric_recorded, Observability.service_key, "Observability." ++ @tagName(kind), "success", value.name);
        }
    }.run);
}

pub fn increment(name: []const u8, amount: i64) @TypeOf(metric(.increment, .{ .name = name, .value = amount })) {
    return metric(.increment, .{ .name = name, .value = amount });
}
pub fn gauge(name: []const u8, value: i64) @TypeOf(metric(.gauge, .{ .name = name, .value = value })) {
    return metric(.gauge, .{ .name = name, .value = value });
}
pub fn observe(name: []const u8, value: i64) @TypeOf(metric(.observe, .{ .name = name, .value = value })) {
    return metric(.observe, .{ .name = name, .value = value });
}

const SpanInput = struct { name: []const u8, parent_id: ?SpanId, attributes: []const Attribute };
pub fn startSpan(name: []const u8, parent_id: ?SpanId, attributes: []const Attribute) fx.kernel.Effect(SpanId, std.mem.Allocator.Error, .{Observability}).Stateful(SpanInput) {
    const Start = fx.kernel.Effect(SpanId, std.mem.Allocator.Error, .{Observability});
    return Start.fromState(SpanInput, .{ .name = name, .parent_id = parent_id, .attributes = attributes }, struct {
        fn run(input: SpanInput, ctx: *Start.Context) std.mem.Allocator.Error!SpanId {
            const id = ctx.service(Observability).recorder.startSpan(input.name, input.parent_id, input.attributes) catch |failure| {
                _ = StdService.recordSemantic(ctx, .span_recorded, Observability.service_key, "Observability.startSpan", "failure", @errorName(failure));
                return failure;
            };
            _ = StdService.recordSemantic(ctx, .span_recorded, Observability.service_key, "Observability.startSpan", "success", input.name);
            return id;
        }
    }.run);
}

pub fn endSpan(id: SpanId) fx.kernel.Effect(void, std.mem.Allocator.Error, .{Observability}).Stateful(SpanId) {
    const End = fx.kernel.Effect(void, std.mem.Allocator.Error, .{Observability});
    return End.fromState(SpanId, id, struct {
        fn run(value: SpanId, ctx: *End.Context) std.mem.Allocator.Error!void {
            ctx.service(Observability).recorder.endSpan(value) catch |failure| {
                _ = StdService.recordSemantic(ctx, .span_recorded, Observability.service_key, "Observability.endSpan", "failure", @errorName(failure));
                return failure;
            };
            _ = StdService.recordSemantic(ctx, .span_recorded, Observability.service_key, "Observability.endSpan", "success", "span ended");
        }
    }.run);
}

fn artifact(comptime otlp: bool, label: []const u8) fx.kernel.Effect([]const u8, std.mem.Allocator.Error, .{Observability}).Stateful([]const u8) {
    const Artifact = fx.kernel.Effect([]const u8, std.mem.Allocator.Error, .{Observability});
    return Artifact.fromState([]const u8, label, struct {
        fn run(value: []const u8, ctx: *Artifact.Context) std.mem.Allocator.Error![]const u8 {
            const recorder = ctx.service(Observability).recorder;
            const output = if (otlp)
                recorder.otlpJsonAlloc(ctx.allocator(), value)
            else
                recorder.workbenchJsonAlloc(ctx.allocator(), value);
            const result = output catch |failure| {
                _ = StdService.recordSemantic(ctx, .span_recorded, Observability.service_key, if (otlp) "Observability.otlpJson" else "Observability.workbenchJson", "failure", @errorName(failure));
                return failure;
            };
            _ = StdService.recordSemantic(ctx, .span_recorded, Observability.service_key, if (otlp) "Observability.otlpJson" else "Observability.workbenchJson", "success", value);
            return result;
        }
    }.run);
}

pub fn workbenchJson(label: []const u8) @TypeOf(artifact(false, label)) {
    return artifact(false, label);
}
pub fn otlpJson(service_name: []const u8) @TypeOf(artifact(true, service_name)) {
    return artifact(true, service_name);
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
    var recorder = Recorder.init(std.testing.allocator);
    defer recorder.deinit();
    const root = layer(&recorder);
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    var runtime = try fx.kernel.ManagedRuntime(@TypeOf(root)).make(std.testing.allocator, root, .{ .causal_store = &store });
    defer runtime.deinit();

    try runtime.run(log(.info, "local compile token=abc123", &.{}));
    try runtime.run(increment("agent.runs", 1));
    try runtime.run(gauge("queue.depth", 2));
    try runtime.run(observe("build.ms", 42));
    const span_id = try runtime.run(startSpan("codex build span", null, &.{}));
    try runtime.run(endSpan(span_id));

    try std.testing.expectEqual(@as(usize, 1), recorder.logger.structured_entries.items.len);
    try std.testing.expectEqual(@as(i64, 1), recorder.metrics.get("agent.runs"));
    try std.testing.expectEqual(@as(i64, 2), recorder.metrics.get("queue.depth"));
    try std.testing.expect(recorder.metrics.histogram("build.ms") != null);
    try std.testing.expectEqual(true, recorder.tracing.spanEnded(span_id).?);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    const log_event_index = StdService.findOperation(snapshot, Observability, "Observability.log", "info");
    try std.testing.expect(log_event_index != null);
    try std.testing.expect(StdService.hasOperation(snapshot, Observability, "Observability.increment", "success"));
    try std.testing.expect(StdService.hasOperation(snapshot, Observability, "Observability.gauge", "success"));
    try std.testing.expect(StdService.hasOperation(snapshot, Observability, "Observability.observe", "success"));
    try std.testing.expect(StdService.hasOperation(snapshot, Observability, "Observability.startSpan", "success"));
    try std.testing.expect(StdService.hasOperation(snapshot, Observability, "Observability.endSpan", "success"));
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
