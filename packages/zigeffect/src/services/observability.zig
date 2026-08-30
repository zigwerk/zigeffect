const std = @import("std");
const logger_mod = @import("logger.zig");
const metrics_mod = @import("metrics.zig");
const tracing_mod = @import("tracing.zig");

pub const Allocator = std.mem.Allocator;
pub const Logger = logger_mod.Logger;
pub const Metrics = metrics_mod.Metrics;
pub const Tracing = tracing_mod.Tracing;

fn appendOptionalU64(output: *std.ArrayList(u8), allocator: Allocator, value: ?u64) Allocator.Error!void {
    if (value) |number| {
        try output.print(allocator, "{d}", .{number});
    } else {
        try output.appendSlice(allocator, "null");
    }
}

pub fn formatObservabilityReport(
    allocator: Allocator,
    label: []const u8,
    logger: *const Logger,
    metrics: *Metrics,
    tracing: *const Tracing,
) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.print(
        allocator,
        "zigeffect observability report\nprogram: {s}\n",
        .{label},
    );

    try output.print(allocator, "logs: {d}\n", .{logger.structured_entries.items.len});
    for (logger.structured_entries.items) |entry| {
        try output.print(
            allocator,
            "log: {s} {s}",
            .{ @tagName(entry.level), entry.message },
        );
        if (entry.timestamp_ms) |timestamp| try output.print(allocator, " timestamp={d}", .{timestamp});
        if (entry.trace_id) |trace_id| try output.print(allocator, " trace={d}", .{trace_id});
        if (entry.span_id) |span_id| try output.print(allocator, " span={d}", .{span_id});
        for (entry.fields) |field| {
            try output.print(allocator, " {s}={s}", .{ field.key, field.value });
        }
        try output.appendSlice(allocator, "\n");
    }

    var snapshot = try metrics.snapshot(allocator);
    defer snapshot.deinit();

    try output.print(allocator, "counters: {d}\n", .{snapshot.counters.len});
    for (snapshot.counters) |counter| {
        try output.print(allocator, "counter: {s}={d}\n", .{ counter.name, counter.value });
    }

    try output.print(allocator, "histograms: {d}\n", .{snapshot.histograms.len});
    for (snapshot.histograms) |histogram| {
        try output.print(
            allocator,
            "histogram: {s} count={d} sum={d} min={d} max={d}\n",
            .{
                histogram.name,
                histogram.value.count,
                histogram.value.sum,
                histogram.value.min,
                histogram.value.max,
            },
        );
    }

    try output.print(allocator, "trace events: {d}\n", .{tracing.events.items.len});
    for (tracing.events.items) |event| {
        try output.print(allocator, "event: {s}\n", .{event});
    }

    try output.print(allocator, "spans: {d}\n", .{tracing.spans.items.len});
    for (tracing.spans.items) |span| {
        try output.print(
            allocator,
            "span: id={d} trace={d} parent=",
            .{ span.id, span.trace_id },
        );
        try appendOptionalU64(&output, allocator, span.parent_id);
        try output.print(
            allocator,
            " ended={} name={s}",
            .{ span.ended, span.name },
        );
        for (span.attributes) |attribute| {
            try output.print(allocator, " {s}={s}", .{ attribute.key, attribute.value });
        }
        try output.appendSlice(allocator, "\n");
    }

    return output.toOwnedSlice(allocator);
}
