const Middleware = @import("middleware.zig");
const otel = @import("zigeffect_otel");
const std = @import("std");

pub fn exporterSink(exporter: *otel.Exporter) Middleware.TelemetrySink {
    return .{
        .pointer = exporter,
        .emit_fn = struct {
            fn emit(pointer: *anyopaque, record: Middleware.TelemetryRecord) !void {
                const target: *otel.Exporter = @ptrCast(@alignCast(pointer));
                switch (record) {
                    .metric => |metric| {
                        const attributes = try mapAttributesAlloc(target.allocator, metric.attributes);
                        defer target.allocator.free(attributes);
                        try target.enqueueMetric(.{
                            .service_name = metric.service_name,
                            .scope = "zigeffect-grpc",
                            .name = metric.name,
                            .unit = metric.unit,
                            .value = metric.value,
                            .time_unix_nanos = metric.time_unix_nanos,
                            .attributes = attributes,
                        });
                    },
                    .histogram => |histogram| {
                        const attributes = try mapAttributesAlloc(target.allocator, histogram.attributes);
                        defer target.allocator.free(attributes);
                        const exemplars = try target.allocator.alloc(otel.Exemplar, histogram.exemplars.len);
                        defer target.allocator.free(exemplars);
                        var initialized_exemplars: usize = 0;
                        errdefer for (exemplars[0..initialized_exemplars]) |exemplar| target.allocator.free(exemplar.filtered_attributes);
                        for (histogram.exemplars, exemplars) |source, *destination| {
                            const filtered = try mapAttributesAlloc(target.allocator, source.filtered_attributes);
                            errdefer target.allocator.free(filtered);
                            destination.* = .{
                                .time_unix_nanos = source.time_unix_nanos,
                                .value = source.value,
                                .trace_id = source.trace_id,
                                .span_id = source.span_id,
                                .filtered_attributes = filtered,
                            };
                            initialized_exemplars += 1;
                        }
                        defer for (exemplars) |exemplar| target.allocator.free(exemplar.filtered_attributes);
                        try target.enqueueHistogram(.{
                            .service_name = histogram.service_name,
                            .scope = "zigeffect-grpc",
                            .name = histogram.name,
                            .unit = histogram.unit,
                            .count = histogram.count,
                            .sum = histogram.sum,
                            .bucket_counts = histogram.bucket_counts,
                            .explicit_bounds = histogram.explicit_bounds,
                            .min = histogram.min,
                            .max = histogram.max,
                            .time_unix_nanos = histogram.time_unix_nanos,
                            .attributes = attributes,
                            .exemplars = exemplars,
                        });
                    },
                    .span => |span| {
                        const attributes = try mapAttributesAlloc(target.allocator, span.attributes);
                        defer target.allocator.free(attributes);
                        const links = try target.allocator.alloc(otel.SpanLink, span.links.len);
                        defer target.allocator.free(links);
                        var initialized_links: usize = 0;
                        errdefer for (links[0..initialized_links]) |link| target.allocator.free(link.attributes);
                        for (span.links, links) |source, *destination| {
                            const link_attributes = try mapAttributesAlloc(target.allocator, source.attributes);
                            errdefer target.allocator.free(link_attributes);
                            destination.* = .{
                                .trace_id = source.trace_id,
                                .span_id = source.span_id,
                                .tracestate = source.tracestate,
                                .attributes = link_attributes,
                            };
                            initialized_links += 1;
                        }
                        defer for (links) |link| target.allocator.free(link.attributes);
                        try target.enqueueSpan(.{
                            .service_name = span.service_name,
                            .scope = "zigeffect-grpc",
                            .trace_id = span.trace_id,
                            .span_id = span.span_id,
                            .parent_span_id = span.parent_span_id,
                            .name = span.name,
                            .start_time_unix_nanos = span.start_time_unix_nanos,
                            .end_time_unix_nanos = span.end_time_unix_nanos,
                            .status_error = span.status_error,
                            .attributes = attributes,
                            .links = links,
                        });
                    },
                    .log => |log| {
                        const attributes = try mapAttributesAlloc(target.allocator, log.attributes);
                        defer target.allocator.free(attributes);
                        try target.enqueueLog(.{
                            .service_name = log.service_name,
                            .scope = "zigeffect-grpc",
                            .time_unix_nanos = log.time_unix_nanos,
                            .severity_number = log.severity_number,
                            .severity_text = log.severity_text,
                            .body = log.body,
                            .attributes = attributes,
                        });
                    },
                }
            }
        }.emit,
    };
}

fn mapAttributesAlloc(allocator: std.mem.Allocator, source: []const Middleware.TelemetryAttribute) ![]otel.Attribute {
    const attributes = try allocator.alloc(otel.Attribute, source.len);
    for (source, attributes) |input, *output| output.* = .{
        .key = input.key,
        .value = switch (input.value) {
            .string => |value| .{ .string = value },
            .int => |value| .{ .int = value },
        },
    };
    return attributes;
}

test "gRPC OTLP interceptor enqueues redacted metrics traces and error events through zigeffect-otel" {
    var exporter = try otel.Exporter.init(std.testing.allocator, std.testing.io, .{ .max_queue_items = 4 });
    defer exporter.deinit();
    var telemetry = Middleware.OtlpTelemetry{
        .allocator = std.testing.allocator,
        .service_name = "orders-api",
        .sink = exporterSink(&exporter),
    };
    const context = Middleware.CallContext{
        .protocol = .grpc,
        .authority = "orders.run.app",
        .service = "orders.v1.Orders",
        .method = "List",
        .shape = .unary,
        .authorization = "Bearer must-not-appear",
        .traceparent = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
    };
    telemetry.after(&context, .{ .code = .unavailable, .duration_millis = 12 });
    const snapshot = exporter.snapshot();
    try std.testing.expectEqual(@as(usize, 4), snapshot.queued);
    try std.testing.expectEqual(@as(usize, 0), telemetry.export_failures.load(.acquire));
}
