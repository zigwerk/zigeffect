const std = @import("std");
const otel = @import("zigeffect_otel");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const collector_path = args.next() orelse return error.MissingCollectorPath;
    const port = try availablePort(init.io, 27_100, 27_200);
    var port_buffer: [5]u8 = undefined;
    const port_text = try std.fmt.bufPrint(&port_buffer, "{d}", .{port});
    var exporter = try otel.Exporter.init(init.gpa, init.io, .{ .port = port, .retry_attempts = 0, .retry_base_ms = 2, .request_deadline_ms = 50 });
    defer exporter.deinit();
    try exporter.enqueue(.logs, "{\"resourceLogs\":[{\"resource\":{\"attributes\":[{\"key\":\"service.name\",\"value\":{\"stringValue\":\"reference-process-collector\"}}]}}]}");
    exporter.flush() catch |err| if (err != error.CollectorUnavailable) return err;
    if (exporter.snapshot().queued != 1) return error.OutageDroppedTelemetry;
    var collector = try std.process.spawn(init.io, .{ .argv = &.{ collector_path, port_text }, .stdin = .ignore, .stdout = .ignore, .stderr = .inherit });
    defer collector.kill(init.io);
    exporter.options.retry_attempts = 500;
    try exporter.enqueue(.metrics, "{\"resourceMetrics\":[{\"resource\":{\"attributes\":[{\"key\":\"service.name\",\"value\":{\"stringValue\":\"reference-process-collector\"}}]}}]}");
    try exporter.enqueue(.traces, "{\"resourceSpans\":[{\"resource\":{\"attributes\":[{\"key\":\"service.name\",\"value\":{\"stringValue\":\"reference-process-collector\"}}]}}]}");
    try exporter.flush();
    try exporter.shutdown();
    switch (try collector.wait(init.io)) { .exited => |code| if (code != 0) return error.CollectorFailed, else => return error.CollectorFailed }
}

fn availablePort(io: std.Io, start: u16, end: u16) !u16 {
    var port = start;
    while (port < end) : (port += 1) {
        const address = try std.Io.net.IpAddress.parseIp4("127.0.0.1", port);
        var listener = address.listen(io, .{ .reuse_address = true }) catch |err| switch (err) { error.AddressInUse => continue, else => return err };
        listener.deinit(io);
        return port;
    }
    return error.NoConformancePort;
}
