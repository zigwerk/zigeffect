const std = @import("std");
const zgrpc = @import("zigeffect_grpc");

pub fn main(init: std.process.Init) !void {
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();
    const port_text = args.next() orelse return error.MissingPort;
    const port = try std.fmt.parseInt(u16, port_text, 10);
    const mode = args.next() orelse "plaintext";
    const certificate = args.next();

    var options = zgrpc.ClientOptions{ .port = port };
    if (std.mem.eql(u8, mode, "tls")) {
        options.tls = .{
            .ca_path = certificate orelse return error.MissingCertificate,
            .server_name = "localhost",
        };
    }
    var client = try zgrpc.NativeClient.init(init.gpa, init.io, options);
    var response = try client.invokeAlloc(init.gpa, .{
        .authority = "localhost",
        .service = "example.v1.Echo",
        .method = "Say",
        .payload = "zig-client-interoperability",
        .timeout_millis = 10_000,
    }, .{});
    defer response.deinit();
    if (!response.status.isOk()) return error.GrpcStatusFailure;
    if (!std.mem.eql(u8, response.payload, "zig-client-interoperability")) return error.ResponseMismatch;
    var upload = try client.invokeStreamingAlloc(init.gpa, .{
        .authority = "localhost",
        .service = "example.v1.Stream",
        .method = "Upload",
        .messages = &.{ "one", "two" },
        .timeout_millis = 10_000,
        .shape = .client_streaming,
    }, .{});
    defer upload.deinit();
    if (!std.mem.eql(u8, upload.messages[0], "received-two")) return error.ResponseMismatch;
    var download = try client.invokeStreamingAlloc(init.gpa, .{
        .authority = "localhost",
        .service = "example.v1.Stream",
        .method = "Download",
        .messages = &.{"request"},
        .timeout_millis = 10_000,
        .shape = .server_streaming,
    }, .{});
    defer download.deinit();
    if (download.messages.len != 2) return error.ResponseMismatch;
    var chat = try client.invokeStreamingAlloc(init.gpa, .{
        .authority = "localhost",
        .service = "example.v1.Stream",
        .method = "Chat",
        .messages = &.{ "hello", "world" },
        .timeout_millis = 10_000,
        .shape = .bidirectional_streaming,
    }, .{});
    defer chat.deinit();
    if (chat.messages.len != 2 or !std.mem.eql(u8, chat.messages[1], "world")) return error.ResponseMismatch;
}
