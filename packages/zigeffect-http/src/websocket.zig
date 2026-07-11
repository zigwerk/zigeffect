const std = @import("std");
const zstd = @import("zigeffect_std");

pub const Http = zstd.Http;

pub const FrameLimits = struct {
    max_payload_bytes: usize = 1024 * 1024,
};

pub const Opcode = enum(u4) {
    continuation = 0x0,
    text = 0x1,
    binary = 0x2,
    close = 0x8,
    ping = 0x9,
    pong = 0xA,
};

pub const Frame = struct {
    fin: bool,
    opcode: Opcode,
    payload: []u8,
    consumed: usize,

    pub fn deinit(self: *Frame, allocator: std.mem.Allocator) void {
        allocator.free(self.payload);
        self.* = undefined;
    }
};

pub const Message = struct {
    opcode: Opcode,
    payload: []u8,

    pub fn deinit(self: *Message, allocator: std.mem.Allocator) void {
        allocator.free(self.payload);
        self.* = undefined;
    }
};

pub const Handler = struct {
    pointer: *anyopaque,
    accepts_fn: *const fn (*anyopaque, Http.Request) bool,
    handle_fn: *const fn (*anyopaque, std.mem.Allocator, Http.Request, Frame) anyerror!?Message,

    pub fn from(comptime HandlerType: type, value: *HandlerType) Handler {
        return .{
            .pointer = value,
            .accepts_fn = struct {
                fn accepts(pointer: *anyopaque, request: Http.Request) bool {
                    const handler: *HandlerType = @ptrCast(@alignCast(pointer));
                    return handler.accepts(request);
                }
            }.accepts,
            .handle_fn = struct {
                fn handle(pointer: *anyopaque, allocator: std.mem.Allocator, request: Http.Request, frame: Frame) anyerror!?Message {
                    const handler: *HandlerType = @ptrCast(@alignCast(pointer));
                    return handler.handleAlloc(allocator, request, frame);
                }
            }.handle,
        };
    }

    pub fn accepts(self: Handler, request: Http.Request) bool {
        return self.accepts_fn(self.pointer, request);
    }

    pub fn handleAlloc(self: Handler, allocator: std.mem.Allocator, request: Http.Request, frame: Frame) !?Message {
        return self.handle_fn(self.pointer, allocator, request, frame);
    }
};

pub fn acceptKey(key: []const u8) ![28]u8 {
    const decoded_len = std.base64.standard.Decoder.calcSizeForSlice(key) catch return error.InvalidWebSocketKey;
    if (decoded_len != 16) return error.InvalidWebSocketKey;
    var decoded: [16]u8 = undefined;
    std.base64.standard.Decoder.decode(&decoded, key) catch return error.InvalidWebSocketKey;

    var digest: [std.crypto.hash.Sha1.digest_length]u8 = undefined;
    var sha1 = std.crypto.hash.Sha1.init(.{});
    sha1.update(key);
    sha1.update("258EAFA5-E914-47DA-95CA-C5AB0DC85B11");
    sha1.final(&digest);
    var encoded: [28]u8 = undefined;
    _ = std.base64.standard.Encoder.encode(&encoded, &digest);
    return encoded;
}

pub fn validateUpgrade(request: Http.Request, version: []const u8) ![28]u8 {
    if (!std.mem.eql(u8, request.method, "GET")) return error.InvalidWebSocketMethod;
    if (!std.mem.eql(u8, version, "HTTP/1.1")) return error.InvalidWebSocketHttpVersion;
    const upgrade = requestHeader(request, "upgrade") orelse return error.MissingWebSocketUpgrade;
    if (!std.ascii.eqlIgnoreCase(std.mem.trim(u8, upgrade, " \t"), "websocket")) return error.InvalidWebSocketUpgrade;
    const connection = requestHeader(request, "connection") orelse return error.MissingWebSocketConnection;
    if (!containsToken(connection, "upgrade")) return error.InvalidWebSocketConnection;
    const websocket_version = requestHeader(request, "sec-websocket-version") orelse return error.MissingWebSocketVersion;
    if (!std.mem.eql(u8, std.mem.trim(u8, websocket_version, " \t"), "13")) return error.UnsupportedWebSocketVersion;
    return acceptKey(requestHeader(request, "sec-websocket-key") orelse return error.MissingWebSocketKey);
}

pub fn isUpgradeRequest(request: Http.Request) bool {
    const upgrade = requestHeader(request, "upgrade") orelse return false;
    const connection = requestHeader(request, "connection") orelse return false;
    return std.ascii.eqlIgnoreCase(std.mem.trim(u8, upgrade, " \t"), "websocket") and containsToken(connection, "upgrade");
}

pub fn handshakeResponseAlloc(allocator: std.mem.Allocator, request: Http.Request, version: []const u8) ![]u8 {
    const accepted = try validateUpgrade(request, version);
    return std.fmt.allocPrint(
        allocator,
        "HTTP/1.1 101 Switching Protocols\r\n" ++
            "Upgrade: websocket\r\n" ++
            "Connection: Upgrade\r\n" ++
            "Sec-WebSocket-Accept: {s}\r\n\r\n",
        .{&accepted},
    );
}

pub fn parseClientFrameAlloc(allocator: std.mem.Allocator, input: []const u8, limits: FrameLimits) !Frame {
    if (limits.max_payload_bytes == 0) return error.InvalidFrameLimits;
    if (input.len < 2) return error.IncompleteFrame;
    const first = input[0];
    const second = input[1];
    if (first & 0x70 != 0) return error.ReservedBitsSet;
    const fin = first & 0x80 != 0;
    const opcode = std.enums.fromInt(Opcode, first & 0x0f) orelse return error.InvalidOpcode;
    const control = @intFromEnum(opcode) >= 0x8;
    if (control and !fin) return error.FragmentedControlFrame;
    if (second & 0x80 == 0) return error.UnmaskedClientFrame;

    var cursor: usize = 2;
    var payload_length: u64 = second & 0x7f;
    if (payload_length == 126) {
        if (input.len - cursor < 2) return error.IncompleteFrame;
        payload_length = std.mem.readInt(u16, input[cursor..][0..2], .big);
        cursor += 2;
        if (payload_length < 126) return error.NonCanonicalFrameLength;
    } else if (payload_length == 127) {
        if (input.len - cursor < 8) return error.IncompleteFrame;
        payload_length = std.mem.readInt(u64, input[cursor..][0..8], .big);
        cursor += 8;
        if (payload_length < 65_536 or payload_length & (@as(u64, 1) << 63) != 0) return error.NonCanonicalFrameLength;
    }
    if (control and payload_length > 125) return error.ControlFrameTooLarge;
    if (payload_length > limits.max_payload_bytes or payload_length > std.math.maxInt(usize)) return error.FrameTooLarge;
    if (opcode == .close and payload_length == 1) return error.InvalidClosePayload;
    if (input.len - cursor < 4) return error.IncompleteFrame;
    const mask = input[cursor..][0..4].*;
    cursor += 4;
    const length: usize = @intCast(payload_length);
    if (input.len - cursor < length) return error.IncompleteFrame;

    const payload = try allocator.alloc(u8, length);
    errdefer allocator.free(payload);
    for (payload, 0..) |*byte, index| byte.* = input[cursor + index] ^ mask[index % 4];
    if (opcode == .text and !std.unicode.utf8ValidateSlice(payload)) return error.InvalidTextEncoding;
    return .{ .fin = fin, .opcode = opcode, .payload = payload, .consumed = cursor + length };
}

pub fn encodeServerFrameAlloc(allocator: std.mem.Allocator, opcode: Opcode, payload: []const u8, fin: bool) ![]u8 {
    const control = @intFromEnum(opcode) >= 0x8;
    if (control and !fin) return error.FragmentedControlFrame;
    if (control and payload.len > 125) return error.ControlFrameTooLarge;
    if (opcode == .close and payload.len == 1) return error.InvalidClosePayload;
    if (opcode == .text and !std.unicode.utf8ValidateSlice(payload)) return error.InvalidTextEncoding;

    const length_bytes: usize = if (payload.len <= 125) 0 else if (payload.len <= std.math.maxInt(u16)) 2 else 8;
    const output = try allocator.alloc(u8, 2 + length_bytes + payload.len);
    output[0] = (if (fin) @as(u8, 0x80) else 0) | @as(u8, @intFromEnum(opcode));
    var cursor: usize = 2;
    switch (length_bytes) {
        0 => output[1] = @intCast(payload.len),
        2 => {
            output[1] = 126;
            std.mem.writeInt(u16, output[2..4], @intCast(payload.len), .big);
            cursor = 4;
        },
        8 => {
            output[1] = 127;
            std.mem.writeInt(u64, output[2..10], @intCast(payload.len), .big);
            cursor = 10;
        },
        else => unreachable,
    }
    @memcpy(output[cursor..], payload);
    return output;
}

fn requestHeader(request: Http.Request, name: []const u8) ?[]const u8 {
    for (request.headers) |header| if (std.ascii.eqlIgnoreCase(header.name, name)) return header.value;
    return null;
}

fn containsToken(value: []const u8, wanted: []const u8) bool {
    var tokens = std.mem.splitScalar(u8, value, ',');
    while (tokens.next()) |token| {
        if (std.ascii.eqlIgnoreCase(std.mem.trim(u8, token, " \t"), wanted)) return true;
    }
    return false;
}

test "WebSocket validates the RFC upgrade handshake" {
    const accepted = try acceptKey("dGhlIHNhbXBsZSBub25jZQ==");
    try std.testing.expectEqualStrings("s3pPLMBiTxaQ9kYGzzhZRbK+xOo=", &accepted);
    const validated = try validateUpgrade(.{
        .method = "GET",
        .url = "/chat",
        .headers = &.{
            .{ .name = "Host", .value = "server.example.com" },
            .{ .name = "Upgrade", .value = "websocket" },
            .{ .name = "Connection", .value = "keep-alive, Upgrade" },
            .{ .name = "Sec-WebSocket-Key", .value = "dGhlIHNhbXBsZSBub25jZQ==" },
            .{ .name = "Sec-WebSocket-Version", .value = "13" },
        },
    }, "HTTP/1.1");
    try std.testing.expectEqualSlices(u8, &accepted, &validated);
    try std.testing.expectError(error.InvalidWebSocketMethod, validateUpgrade(.{ .method = "POST", .url = "/" }, "HTTP/1.1"));
    const response = try handshakeResponseAlloc(std.testing.allocator, .{
        .method = "GET",
        .url = "/chat",
        .headers = &.{
            .{ .name = "Upgrade", .value = "websocket" },
            .{ .name = "Connection", .value = "Upgrade" },
            .{ .name = "Sec-WebSocket-Key", .value = "dGhlIHNhbXBsZSBub25jZQ==" },
            .{ .name = "Sec-WebSocket-Version", .value = "13" },
        },
    }, "HTTP/1.1");
    defer std.testing.allocator.free(response);
    try std.testing.expect(std.mem.indexOf(u8, response, "101 Switching Protocols") != null);
}

test "WebSocket decodes masked client frames and enforces protocol bounds" {
    const encoded = [_]u8{ 0x81, 0x85, 0x37, 0xfa, 0x21, 0x3d, 0x7f, 0x9f, 0x4d, 0x51, 0x58 };
    var frame = try parseClientFrameAlloc(std.testing.allocator, &encoded, .{});
    defer frame.deinit(std.testing.allocator);
    try std.testing.expect(frame.fin);
    try std.testing.expectEqual(Opcode.text, frame.opcode);
    try std.testing.expectEqualStrings("Hello", frame.payload);
    try std.testing.expectEqual(encoded.len, frame.consumed);
    try std.testing.expectError(error.UnmaskedClientFrame, parseClientFrameAlloc(std.testing.allocator, &.{ 0x81, 0x01, 'x' }, .{}));
    try std.testing.expectError(error.FragmentedControlFrame, parseClientFrameAlloc(std.testing.allocator, &.{ 0x09, 0x80, 0, 0, 0, 0 }, .{}));
}

test "WebSocket encodes bounded unmasked server frames" {
    const short = try encodeServerFrameAlloc(std.testing.allocator, .text, "Hello", true);
    defer std.testing.allocator.free(short);
    try std.testing.expectEqualSlices(u8, &.{ 0x81, 0x05, 'H', 'e', 'l', 'l', 'o' }, short);
    const payload = [_]u8{'a'} ** 126;
    const extended = try encodeServerFrameAlloc(std.testing.allocator, .binary, &payload, true);
    defer std.testing.allocator.free(extended);
    try std.testing.expectEqualSlices(u8, &.{ 0x82, 126, 0, 126 }, extended[0..4]);
    try std.testing.expectError(error.ControlFrameTooLarge, encodeServerFrameAlloc(std.testing.allocator, .ping, &payload, true));
}

test "WebSocket frame codecs survive every allocation failure" {
    const Harness = struct {
        fn decode(allocator: std.mem.Allocator) !void {
            const encoded = [_]u8{ 0x81, 0x85, 0x37, 0xfa, 0x21, 0x3d, 0x7f, 0x9f, 0x4d, 0x51, 0x58 };
            var frame = try parseClientFrameAlloc(allocator, &encoded, .{});
            defer frame.deinit(allocator);
        }
        fn encode(allocator: std.mem.Allocator) !void {
            const frame = try encodeServerFrameAlloc(allocator, .text, "bounded", true);
            defer allocator.free(frame);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Harness.decode, .{});
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Harness.encode, .{});
}
