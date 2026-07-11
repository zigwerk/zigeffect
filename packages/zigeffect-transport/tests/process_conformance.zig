const std = @import("std");
const transport = @import("zigeffect_transport");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const server_path = args.next() orelse return error.MissingServerPath;
    const certificate_arg = args.next() orelse return error.MissingCertificatePath;
    const key = args.next() orelse return error.MissingKeyPath;
    const certificate = try init.gpa.dupeZ(u8, certificate_arg);
    defer init.gpa.free(certificate);
    var random_bytes: [16]u8 = undefined;
    try std.Io.randomSecure(init.io, &random_bytes);
    var credential = std.fmt.bytesToHex(random_bytes, .lower);
    defer {
        std.crypto.secureZero(u8, &random_bytes);
        std.crypto.secureZero(u8, &credential);
    }
    try init.environ_map.put("ZIGEFFECT_TEST_TRANSPORT_CREDENTIAL", &credential);
    const first_port = try availablePort(init.io, 26_500, 26_600);
    const second_port = try availablePort(init.io, first_port + 1, 26_700);
    var first_port_buffer: [5]u8 = undefined;
    var second_port_buffer: [5]u8 = undefined;
    const first_port_text = try std.fmt.bufPrint(&first_port_buffer, "{d}", .{first_port});
    const second_port_text = try std.fmt.bufPrint(&second_port_buffer, "{d}", .{second_port});
    var first_server = try std.process.spawn(init.io, .{
        .argv = &.{ server_path, first_port_text, certificate, key }, .environ_map = init.environ_map, .stdin = .ignore, .stdout = .ignore, .stderr = .inherit,
    });
    defer first_server.kill(init.io);
    var second_server = try std.process.spawn(init.io, .{
        .argv = &.{ server_path, second_port_text, certificate, key }, .environ_map = init.environ_map, .stdin = .ignore, .stdout = .ignore, .stderr = .inherit,
    });
    defer second_server.kill(init.io);

    var first_client = try processClient(init, first_port, certificate, &credential);
    var clients_closed = false;
    defer if (!clients_closed) first_client.deinit();
    var second_client = try processClient(init, second_port, certificate, &credential);
    defer if (!clients_closed) second_client.deinit();
    const first_origin: u64 = 1001;
    const second_origin: u64 = 2002;
    var first_response = try first_client.sendAlloc(init.gpa, .{
        .kind = .request, .address = transport.fx.entityAddress("process-runner", "first"),
        .payload = "ask-first", .idempotency_key = "process-first", .origin_causal_event_id = first_origin,
        .policy = .{ .timeout_ms = 10_000, .max_retries = 2_500 },
    });
    defer first_response.deinit(init.gpa);
    try requireSuccess(try first_server.wait(init.io));
    var restarted_server = try std.process.spawn(init.io, .{
        .argv = &.{ server_path, first_port_text, certificate, key }, .environ_map = init.environ_map, .stdin = .ignore, .stdout = .ignore, .stderr = .inherit,
    });
    defer restarted_server.kill(init.io);
    var recovered_response = try first_client.sendAlloc(init.gpa, .{
        .kind = .request, .address = transport.fx.entityAddress("process-runner", "recovered"),
        .payload = "after-partition", .idempotency_key = "process-recovered", .origin_causal_event_id = first_origin + 1,
        .policy = .{ .timeout_ms = 10_000, .max_retries = 2_500 },
    });
    defer recovered_response.deinit(init.gpa);
    var second_response = try second_client.sendAlloc(init.gpa, .{
        .kind = .tell, .address = transport.fx.entityAddress("process-runner", "second"),
        .payload = "tell-second", .idempotency_key = "process-second", .origin_causal_event_id = second_origin,
        .policy = .{ .timeout_ms = 10_000, .max_retries = 2_500 },
    });
    defer second_response.deinit(init.gpa);
    if (first_response.origin_causal_event_id != first_origin or recovered_response.origin_causal_event_id != first_origin + 1 or second_response.origin_causal_event_id != second_origin) return error.CausalLineageLost;
    if (!std.mem.eql(u8, first_response.envelope.payload, "ask-first") or !std.mem.eql(u8, second_response.envelope.payload, "tell-second")) return error.PayloadMismatch;
    if (first_client.snapshot().reconnects == 0) return error.PartitionRecoveryNotObserved;
    first_client.deinit();
    second_client.deinit();
    clients_closed = true;
    try requireSuccess(try restarted_server.wait(init.io));
    try requireSuccess(try second_server.wait(init.io));
}

fn processClient(init: std.process.Init, port: u16, certificate: [:0]const u8, credential: []const u8) !transport.Client {
    return transport.Client.initAlloc(init.gpa, init.io, .{
        .port = port,
        .auth = .{ .mode = .shared_secret, .credential = credential },
        .tls = .{ .ca_path = certificate, .server_name = "localhost" },
        .reconnect_attempts = 2_500,
    });
}

fn availablePort(io: std.Io, start: u16, end: u16) !u16 {
    var port = start;
    while (port < end) : (port += 1) {
        const address = try std.Io.net.IpAddress.parseIp4("127.0.0.1", port);
        var listener = address.listen(io, .{ .reuse_address = true }) catch |err| switch (err) { error.AddressInUse => continue, else => return err };
        listener.deinit(io);
        return port;
    }
    return error.NoProcessConformancePort;
}

fn requireSuccess(term: std.process.Child.Term) !void {
    switch (term) { .exited => |code| if (code != 0) return error.ServerFailed, else => return error.ServerFailed }
}
