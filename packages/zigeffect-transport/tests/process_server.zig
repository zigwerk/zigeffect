const std = @import("std");
const transport = @import("zigeffect_transport");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const port = try std.fmt.parseUnsigned(u16, args.next() orelse return error.MissingPort, 10);
    const certificate = try init.gpa.dupeZ(u8, args.next() orelse return error.MissingCertificate);
    defer init.gpa.free(certificate);
    const key = try init.gpa.dupeZ(u8, args.next() orelse return error.MissingKey);
    defer init.gpa.free(key);
    const credential = init.environ_map.get("ZIGEFFECT_TEST_TRANSPORT_CREDENTIAL") orelse return error.MissingTransportCredential;
    var memory = transport.fx.InMemoryMessageStorage.init(init.gpa);
    defer memory.deinit();
    var handler = try transport.StorageHandler.init(init.gpa, memory.asMessageStorage(), 32);
    defer handler.deinit();
    var server = try transport.Server.init(init.gpa, init.io, .{
        .port = port,
        .limits = .{ .max_requests_per_connection = 1 },
        .auth = .{ .mode = .shared_secret, .credential = credential },
        .tls = .{ .certificate_chain_path = certificate, .private_key_path = key },
    }, transport.Handler.from(transport.StorageHandler, &handler));
    defer server.deinit();
    const handled = try server.serveOne(init.gpa);
    if (handled == 0) return error.NoRequestsHandled;
}
