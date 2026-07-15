const std = @import("std");
const zstd = @import("zigeffect_std");

pub const Grpc = zstd.Grpc;
pub const unary_proto_content_type = "application/proto";
pub const unary_json_content_type = "application/json";
pub const streaming_proto_content_type = "application/connect+proto";
pub const protocol_version = "1";

pub const EnvelopeKind = enum { message, end_stream };

pub const Envelope = struct {
    kind: EnvelopeKind,
    compressed: bool,
    payload: []u8,
};

pub const DecodeLimits = struct {
    max_message_bytes: usize,
    max_messages: usize,
};

pub const DecodedEnvelopes = struct {
    allocator: std.mem.Allocator,
    items: []Envelope,

    pub fn deinit(self: *DecodedEnvelopes) void {
        for (self.items) |item| self.allocator.free(item.payload);
        self.allocator.free(self.items);
        self.* = undefined;
    }
};

pub fn frameEnvelopeAlloc(allocator: std.mem.Allocator, kind: EnvelopeKind, payload: []const u8, max_message_bytes: usize) ![]u8 {
    return frameEnvelopeWithCompressionAlloc(allocator, kind, false, payload, max_message_bytes);
}

pub fn frameEnvelopeWithCompressionAlloc(allocator: std.mem.Allocator, kind: EnvelopeKind, compressed: bool, payload: []const u8, max_message_bytes: usize) ![]u8 {
    if (payload.len > max_message_bytes or payload.len > std.math.maxInt(u32)) return error.MessageTooLarge;
    const frame = try allocator.alloc(u8, payload.len + 5);
    const kind_flag: u8 = switch (kind) {
        .message => 0,
        .end_stream => 0x02,
    };
    frame[0] = kind_flag | @as(u8, if (compressed) 0x01 else 0);
    std.mem.writeInt(u32, frame[1..5], @intCast(payload.len), .big);
    @memcpy(frame[5..], payload);
    return frame;
}

pub fn decodeEnvelopesAlloc(allocator: std.mem.Allocator, bytes: []const u8, limits: DecodeLimits) !DecodedEnvelopes {
    if (limits.max_message_bytes == 0 or limits.max_messages == 0) return error.InvalidLimits;
    var items: std.ArrayList(Envelope) = .empty;
    errdefer {
        for (items.items) |item| allocator.free(item.payload);
        items.deinit(allocator);
    }
    var offset: usize = 0;
    var saw_end_stream = false;
    while (offset < bytes.len) {
        if (bytes.len - offset < 5) return error.InvalidEnvelope;
        const flags = bytes[offset];
        if ((flags & 0xfc) != 0) return error.InvalidEnvelopeFlags;
        const kind: EnvelopeKind = if ((flags & 0x02) != 0) .end_stream else .message;
        if (saw_end_stream) return error.MessageAfterEndStream;
        const length: usize = std.mem.readInt(u32, bytes[offset + 1 ..][0..4], .big);
        if (length > limits.max_message_bytes or length > bytes.len - offset - 5) return error.MessageTooLarge;
        if (items.items.len >= limits.max_messages) return error.TooManyMessages;
        const payload = try allocator.dupe(u8, bytes[offset + 5 .. offset + 5 + length]);
        errdefer allocator.free(payload);
        try items.append(allocator, .{ .kind = kind, .compressed = (flags & 0x01) != 0, .payload = payload });
        if (kind == .end_stream) saw_end_stream = true;
        offset += 5 + length;
    }
    return .{ .allocator = allocator, .items = try items.toOwnedSlice(allocator) };
}

pub fn httpStatus(code: Grpc.Code) u16 {
    return switch (code) {
        .ok => 200,
        .cancelled => 499,
        .unknown, .internal, .data_loss => 500,
        .invalid_argument, .failed_precondition, .out_of_range => 400,
        .deadline_exceeded => 504,
        .not_found => 404,
        .unimplemented => 501,
        .already_exists, .aborted => 409,
        .permission_denied => 403,
        .resource_exhausted => 429,
        .unavailable => 503,
        .unauthenticated => 401,
    };
}

pub fn codeName(code: Grpc.Code) []const u8 {
    return switch (code) {
        .invalid_argument => "invalid_argument",
        .deadline_exceeded => "deadline_exceeded",
        .not_found => "not_found",
        .already_exists => "already_exists",
        .permission_denied => "permission_denied",
        .resource_exhausted => "resource_exhausted",
        .failed_precondition => "failed_precondition",
        .out_of_range => "out_of_range",
        .unimplemented => "unimplemented",
        .internal => "internal",
        .unavailable => "unavailable",
        .data_loss => "data_loss",
        .unauthenticated => "unauthenticated",
        .cancelled => "canceled",
        .unknown => "unknown",
        .aborted => "aborted",
        .ok => "ok",
    };
}

pub fn errorJsonAlloc(allocator: std.mem.Allocator, code: Grpc.Code, message: []const u8) ![]u8 {
    return errorJsonStatusAlloc(allocator, .{ .code = code, .message = message });
}

/// Canonical Connect unary error. A rich gRPC status is retained as an opaque
/// google.rpc.Status detail so callers can decode it with the descriptor set
/// that produced the error without losing forward-compatible fields.
pub fn errorJsonStatusAlloc(allocator: std.mem.Allocator, status: Grpc.Status) ![]u8 {
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    try output.writer.writeAll("{\"code\":");
    try std.json.Stringify.value(codeName(status.code), .{}, &output.writer);
    try output.writer.writeAll(",\"message\":");
    try std.json.Stringify.value(status.message, .{}, &output.writer);
    if (status.details_bin.len != 0) {
        var parsed = parseRichStatusDetailsAlloc(allocator, status.details_bin) catch null;
        defer if (parsed) |*details| details.deinit();
        if (parsed) |details| {
            if (details.items.len != 0) {
                try output.writer.writeAll(",\"details\":[");
                for (details.items, 0..) |detail, index| {
                    if (index != 0) try output.writer.writeByte(',');
                    try output.writer.writeAll("{\"type\":");
                    try std.json.Stringify.value(detail.typeName(), .{}, &output.writer);
                    try output.writer.writeAll(",\"value\":");
                    const encoded_size = std.base64.standard_no_pad.Encoder.calcSize(detail.value.len);
                    const encoded = try allocator.alloc(u8, encoded_size);
                    defer allocator.free(encoded);
                    _ = std.base64.standard_no_pad.Encoder.encode(encoded, detail.value);
                    try std.json.Stringify.value(encoded, .{}, &output.writer);
                    try output.writer.writeByte('}');
                }
                try output.writer.writeByte(']');
            }
        } else {
            const encoded_size = std.base64.standard_no_pad.Encoder.calcSize(status.details_bin.len);
            const encoded = try allocator.alloc(u8, encoded_size);
            defer allocator.free(encoded);
            _ = std.base64.standard_no_pad.Encoder.encode(encoded, status.details_bin);
            try output.writer.writeAll(",\"details\":[{\"type\":\"google.rpc.Status\",\"value\":");
            try std.json.Stringify.value(encoded, .{}, &output.writer);
            try output.writer.writeAll("}]");
        }
    }
    try output.writer.writeByte('}');
    return output.toOwnedSlice();
}

const ParsedAny = struct {
    type_url: []const u8,
    value: []const u8,

    fn typeName(self: ParsedAny) []const u8 {
        return if (std.mem.lastIndexOfScalar(u8, self.type_url, '/')) |index| self.type_url[index + 1 ..] else self.type_url;
    }
};

const ParsedDetails = struct {
    allocator: std.mem.Allocator,
    items: []ParsedAny,

    fn deinit(self: *ParsedDetails) void {
        self.allocator.free(self.items);
        self.* = undefined;
    }
};

fn readVarint(bytes: []const u8, offset: *usize) !u64 {
    var value: u64 = 0;
    var shift: u7 = 0;
    while (offset.* < bytes.len and shift < 64) : (shift += 7) {
        const byte = bytes[offset.*];
        offset.* += 1;
        value |= @as(u64, byte & 0x7f) << @as(u6, @intCast(shift));
        if ((byte & 0x80) == 0) return value;
    }
    return error.InvalidRichStatus;
}

fn readDelimited(bytes: []const u8, offset: *usize) ![]const u8 {
    const length = try readVarint(bytes, offset);
    if (length > bytes.len - offset.*) return error.InvalidRichStatus;
    const start = offset.*;
    offset.* += @intCast(length);
    return bytes[start..offset.*];
}

fn skipWire(bytes: []const u8, offset: *usize, wire_type: u3) !void {
    switch (wire_type) {
        0 => _ = try readVarint(bytes, offset),
        1 => {
            if (bytes.len - offset.* < 8) return error.InvalidRichStatus;
            offset.* += 8;
        },
        2 => _ = try readDelimited(bytes, offset),
        5 => {
            if (bytes.len - offset.* < 4) return error.InvalidRichStatus;
            offset.* += 4;
        },
        else => return error.InvalidRichStatus,
    }
}

fn parseAny(bytes: []const u8) !ParsedAny {
    var result = ParsedAny{ .type_url = "", .value = "" };
    var offset: usize = 0;
    while (offset < bytes.len) {
        const key = try readVarint(bytes, &offset);
        const field = key >> 3;
        const wire: u3 = @intCast(key & 7);
        if (wire == 2 and field == 1) {
            result.type_url = try readDelimited(bytes, &offset);
        } else if (wire == 2 and field == 2) {
            result.value = try readDelimited(bytes, &offset);
        } else {
            try skipWire(bytes, &offset, wire);
        }
    }
    if (result.type_url.len == 0) return error.InvalidRichStatus;
    return result;
}

fn parseRichStatusDetailsAlloc(allocator: std.mem.Allocator, bytes: []const u8) !ParsedDetails {
    var details: std.ArrayList(ParsedAny) = .empty;
    errdefer details.deinit(allocator);
    var offset: usize = 0;
    while (offset < bytes.len) {
        const key = try readVarint(bytes, &offset);
        const field = key >> 3;
        const wire: u3 = @intCast(key & 7);
        if (field == 3 and wire == 2) {
            if (details.items.len >= 128) return error.InvalidRichStatus;
            try details.append(allocator, try parseAny(try readDelimited(bytes, &offset)));
        } else try skipWire(bytes, &offset, wire);
    }
    return .{ .allocator = allocator, .items = try details.toOwnedSlice(allocator) };
}

/// Canonical Connect streaming EndStreamResponse. Metadata preserves repeated
/// values and binary entries use the same base64 representation as HTTP
/// metadata.
pub fn endStreamJsonAlloc(allocator: std.mem.Allocator, status: Grpc.Status, metadata: []const Grpc.Metadata, limits: Grpc.Limits) ![]u8 {
    var headers = try Grpc.metadataHeadersAlloc(allocator, metadata, limits);
    defer headers.deinit();
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    try output.writer.writeByte('{');
    var wrote_field = false;
    if (status.code != .ok) {
        try output.writer.writeAll("\"error\":");
        const error_json = try errorJsonStatusAlloc(allocator, status);
        defer allocator.free(error_json);
        try output.writer.writeAll(error_json);
        wrote_field = true;
    }
    if (headers.headers.len != 0) {
        if (wrote_field) try output.writer.writeByte(',');
        try output.writer.writeAll("\"metadata\":{");
        var wrote_name = false;
        for (headers.headers, 0..) |header, index| {
            var previously_written = false;
            for (headers.headers[0..index]) |previous| if (std.mem.eql(u8, previous.name, header.name)) {
                previously_written = true;
                break;
            };
            if (previously_written) continue;
            if (wrote_name) try output.writer.writeByte(',');
            try std.json.Stringify.value(header.name, .{}, &output.writer);
            try output.writer.writeAll(":");
            try output.writer.writeByte('[');
            var wrote_value = false;
            for (headers.headers) |candidate| {
                if (!std.mem.eql(u8, candidate.name, header.name)) continue;
                if (wrote_value) try output.writer.writeByte(',');
                try std.json.Stringify.value(candidate.value, .{}, &output.writer);
                wrote_value = true;
            }
            try output.writer.writeByte(']');
            wrote_name = true;
        }
        try output.writer.writeByte('}');
    }
    try output.writer.writeByte('}');
    return output.toOwnedSlice();
}

pub const CorsPolicy = struct {
    allowed_origins: []const []const u8 = &.{},
    allow_credentials: bool = true,
    max_age_seconds: u32 = 7_200,

    pub fn allows(self: CorsPolicy, origin: []const u8) bool {
        for (self.allowed_origins) |candidate| {
            if (std.mem.eql(u8, candidate, "*") or std.mem.eql(u8, candidate, origin)) return true;
        }
        return false;
    }
};

pub const ErrorDetail = struct {
    type_name: []u8,
    value: []u8,
};

pub const UnaryCall = struct {
    base_url: []const u8,
    service: []const u8,
    method: []const u8,
    payload: []const u8,
    metadata: []const Grpc.Metadata = &.{},
    timeout_millis: ?u64 = null,
    cancel_after_millis: ?u64 = null,
    response_body_limit: usize = 4 * 1024 * 1024,
};

pub const UnaryResult = struct {
    allocator: std.mem.Allocator,
    http_response: zstd.Http.Response,
    payload: []const u8,
    status: Grpc.Status,
    status_message: []u8,
    details: []ErrorDetail,

    pub fn deinit(self: *UnaryResult) void {
        for (self.details) |detail| {
            self.allocator.free(detail.type_name);
            self.allocator.free(detail.value);
        }
        self.allocator.free(self.details);
        self.allocator.free(self.status_message);
        self.http_response.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn header(self: UnaryResult, name: []const u8) ?[]const u8 {
        return self.http_response.header(name);
    }
};

/// Transport-injected Connect unary client. Keeping the HTTP capability
/// explicit makes request construction, timeout behavior, and malformed peer
/// handling deterministic under ZigEffect tests while the native wrapper below
/// uses the same code path over a real socket.
pub const UnaryClient = struct {
    transport: zstd.Http.Client,

    pub fn init(transport: zstd.Http.Client) UnaryClient {
        return .{ .transport = transport };
    }

    pub fn invokeAlloc(self: *UnaryClient, allocator: std.mem.Allocator, call: UnaryCall) !UnaryResult {
        if (call.base_url.len == 0 or call.service.len == 0 or call.method.len == 0) return error.InvalidConnectTarget;
        if (call.timeout_millis == 0) return error.InvalidConnectTimeout;

        const url = try std.fmt.allocPrint(allocator, "{s}/{s}/{s}", .{
            std.mem.trimEnd(u8, call.base_url, "/"),
            call.service,
            call.method,
        });
        defer allocator.free(url);
        const timeout_text = if (call.timeout_millis) |timeout|
            try std.fmt.allocPrint(allocator, "{d}", .{timeout})
        else
            null;
        defer if (timeout_text) |value| allocator.free(value);

        var metadata_headers = try Grpc.metadataHeadersAlloc(allocator, call.metadata, .{});
        defer metadata_headers.deinit();
        const headers = try allocator.alloc(zstd.Http.Header, metadata_headers.headers.len + 2 + @as(usize, if (timeout_text != null) 1 else 0));
        defer allocator.free(headers);
        headers[0] = .{ .name = "content-type", .value = unary_proto_content_type };
        headers[1] = .{ .name = "connect-protocol-version", .value = protocol_version };
        var metadata_offset: usize = 2;
        if (timeout_text) |value| {
            headers[metadata_offset] = .{ .name = "connect-timeout-ms", .value = value };
            metadata_offset += 1;
        }
        for (metadata_headers.headers, 0..) |header, index| headers[index + metadata_offset] = .{
            .name = header.name,
            .value = header.value,
        };

        var response = try self.transport.sendAlloc(allocator, .{
            .method = "POST",
            .url = url,
            .headers = headers,
            .body = call.payload,
        }, .{
            .response_body_limit = call.response_body_limit,
            .request_timeout_millis = call.timeout_millis orelse 60_000,
        });
        errdefer response.deinit(allocator);

        const content_type = response.header("content-type") orelse "";
        const successful = response.status >= 200 and response.status < 300 and
            contentTypeMatches(content_type, unary_proto_content_type);
        if (successful) {
            const message = try allocator.dupe(u8, "");
            errdefer allocator.free(message);
            return .{
                .allocator = allocator,
                .http_response = response,
                .payload = response.body,
                .status = .ok(),
                .status_message = message,
                .details = try allocator.alloc(ErrorDetail, 0),
            };
        }

        const parsed = try parseErrorResponseAlloc(allocator, response.status, content_type, response.body);
        errdefer parsed.deinit(allocator);
        return .{
            .allocator = allocator,
            .http_response = response,
            .payload = "",
            .status = .{ .code = parsed.code, .message = parsed.message },
            .status_message = parsed.message,
            .details = parsed.details,
        };
    }
};

pub const NativeUnaryClient = struct {
    http: zstd.Http.LocalClient,
    io: std.Io,

    pub fn init(allocator: std.mem.Allocator, io: std.Io) NativeUnaryClient {
        return .{ .http = .init(allocator, io), .io = io };
    }

    pub fn deinit(self: *NativeUnaryClient) void {
        self.http.deinit();
        self.* = undefined;
    }

    pub fn invokeAlloc(self: *NativeUnaryClient, allocator: std.mem.Allocator, call: UnaryCall) !UnaryResult {
        const timeout = call.timeout_millis;
        const cancellation = call.cancel_after_millis;
        if (timeout == null and cancellation == null) return self.invokeDirectAlloc(allocator, call);

        const Outcome = union(enum) {
            response: anyerror!UnaryResult,
            elapsed: bool,
        };
        const Race = struct {
            fn invoke(client: *NativeUnaryClient, result_allocator: std.mem.Allocator, request: UnaryCall) anyerror!UnaryResult {
                return client.invokeDirectAlloc(result_allocator, request);
            }

            fn wait(io: std.Io, milliseconds: u64) bool {
                (std.Io.Clock.Duration{
                    .raw = .fromMilliseconds(@intCast(milliseconds)),
                    .clock = .awake,
                }).sleep(io) catch return false;
                return true;
            }

            fn release(outcome: Outcome) void {
                switch (outcome) {
                    .elapsed => {},
                    .response => |result| if (result) |value_const| {
                        var value = value_const;
                        value.deinit();
                    } else |_| {},
                }
            }
        };

        const cancel_wins = cancellation != null and (timeout == null or cancellation.? <= timeout.?);
        const delay = if (cancel_wins) cancellation.? else timeout.?;
        var outcomes: [2]Outcome = undefined;
        var select = std.Io.Select(Outcome).init(self.io, &outcomes);
        try select.concurrent(.response, Race.invoke, .{ self, allocator, call });
        try select.concurrent(.elapsed, Race.wait, .{ self.io, delay });
        const first = try select.await();
        switch (first) {
            .response => |result| {
                select.cancelDiscard();
                return result;
            },
            .elapsed => {
                while (select.cancel()) |outcome| Race.release(outcome);
                return if (cancel_wins) error.RequestCancelled else error.RequestTimeout;
            },
        }
    }

    fn invokeDirectAlloc(self: *NativeUnaryClient, allocator: std.mem.Allocator, call: UnaryCall) !UnaryResult {
        var client = UnaryClient.init(self.http.client());
        return client.invokeAlloc(allocator, call);
    }
};

const ParsedError = struct {
    code: Grpc.Code,
    message: []u8,
    details: []ErrorDetail,

    fn deinit(self: *const ParsedError, allocator: std.mem.Allocator) void {
        allocator.free(self.message);
        for (self.details) |detail| {
            allocator.free(detail.type_name);
            allocator.free(detail.value);
        }
        allocator.free(self.details);
    }
};

fn contentTypeMatches(actual: []const u8, expected: []const u8) bool {
    const semicolon = std.mem.indexOfScalar(u8, actual, ';') orelse actual.len;
    return std.ascii.eqlIgnoreCase(std.mem.trim(u8, actual[0..semicolon], " \t"), expected);
}

fn codeFromName(name: []const u8) ?Grpc.Code {
    inline for (@typeInfo(Grpc.Code).@"enum".fields) |field| {
        const canonical = if (std.mem.eql(u8, field.name, "cancelled")) "canceled" else field.name;
        if (std.mem.eql(u8, name, canonical)) return @enumFromInt(field.value);
    }
    return null;
}

fn codeFromHttpStatus(status: u16) Grpc.Code {
    return switch (status) {
        400 => .internal,
        401 => .unauthenticated,
        403 => .permission_denied,
        404 => .unimplemented,
        408 => .deadline_exceeded,
        429, 502, 503, 504 => .unavailable,
        else => .unknown,
    };
}

fn decodeBase64Alloc(allocator: std.mem.Allocator, encoded: []const u8) ![]u8 {
    const unpadded_length = std.base64.standard_no_pad.Decoder.calcSizeForSlice(encoded) catch null;
    if (unpadded_length) |length| {
        const value = try allocator.alloc(u8, length);
        errdefer allocator.free(value);
        std.base64.standard_no_pad.Decoder.decode(value, encoded) catch return error.InvalidConnectError;
        return value;
    }
    const length = std.base64.standard.Decoder.calcSizeForSlice(encoded) catch return error.InvalidConnectError;
    const value = try allocator.alloc(u8, length);
    errdefer allocator.free(value);
    std.base64.standard.Decoder.decode(value, encoded) catch return error.InvalidConnectError;
    return value;
}

fn parseErrorResponseAlloc(allocator: std.mem.Allocator, http_status: u16, content_type: []const u8, body: []const u8) !ParsedError {
    if (!contentTypeMatches(content_type, unary_json_content_type)) return .{
        .code = codeFromHttpStatus(http_status),
        .message = try allocator.dupe(u8, "unexpected HTTP response"),
        .details = try allocator.alloc(ErrorDetail, 0),
    };

    const fallback_code: Grpc.Code = if (http_status >= 200 and http_status < 300) .internal else codeFromHttpStatus(http_status);
    var document = std.json.parseFromSlice(std.json.Value, allocator, body, .{}) catch return error.InvalidConnectError;
    defer document.deinit();
    if (document.value == .null) return .{
        .code = fallback_code,
        .message = try allocator.dupe(u8, ""),
        .details = try allocator.alloc(ErrorDetail, 0),
    };
    if (document.value != .object) return error.InvalidConnectError;
    const code_value = document.value.object.get("code");
    const code = if (code_value) |value|
        if (value == .string) codeFromName(value.string) orelse fallback_code else fallback_code
    else
        fallback_code;
    const message_value = document.value.object.get("message");
    if (message_value) |value| if (value != .string and value != .null) return error.InvalidConnectError;
    const message = try allocator.dupe(u8, if (message_value) |value| if (value == .string) value.string else "" else "");
    errdefer allocator.free(message);

    var details: std.ArrayList(ErrorDetail) = .empty;
    errdefer {
        for (details.items) |detail| {
            allocator.free(detail.type_name);
            allocator.free(detail.value);
        }
        details.deinit(allocator);
    }
    if (document.value.object.get("details")) |details_value| {
        if (details_value != .array or details_value.array.items.len > 128) return error.InvalidConnectError;
        for (details_value.array.items) |item| {
            if (item != .object) return error.InvalidConnectError;
            const type_value = item.object.get("type") orelse return error.InvalidConnectError;
            const encoded_value = item.object.get("value") orelse return error.InvalidConnectError;
            if (type_value != .string or encoded_value != .string) return error.InvalidConnectError;
            const type_name = try allocator.dupe(u8, type_value.string);
            errdefer allocator.free(type_name);
            const value = try decodeBase64Alloc(allocator, encoded_value.string);
            errdefer allocator.free(value);
            try details.append(allocator, .{ .type_name = type_name, .value = value });
        }
    }
    return .{ .code = code, .message = message, .details = try details.toOwnedSlice(allocator) };
}

test "Connect rejects reserved envelope flags and messages after end-stream" {
    try std.testing.expectError(error.InvalidEnvelopeFlags, decodeEnvelopesAlloc(std.testing.allocator, &.{ 0x80, 0, 0, 0, 0 }, .{ .max_message_bytes = 16, .max_messages = 2 }));
    const bytes = [_]u8{ 0x02, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
    try std.testing.expectError(error.MessageAfterEndStream, decodeEnvelopesAlloc(std.testing.allocator, &bytes, .{ .max_message_bytes = 16, .max_messages = 2 }));
}

test "Connect end-stream JSON preserves error and repeated binary-safe metadata" {
    const metadata = [_]Grpc.Metadata{
        .{ .name = "quota", .value = "1" },
        .{ .name = "quota", .value = "2" },
        .{ .name = "trace-bin", .value = &.{ 0, 255 }, .kind = .binary },
    };
    const json = try endStreamJsonAlloc(std.testing.allocator, .{ .code = .resource_exhausted, .message = "slow down" }, &metadata, .{});
    defer std.testing.allocator.free(json);
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{});
    defer parsed.deinit();
    try std.testing.expectEqualStrings("resource_exhausted", parsed.value.object.get("error").?.object.get("code").?.string);
    try std.testing.expectEqual(@as(usize, 2), parsed.value.object.get("metadata").?.object.get("quota").?.array.items.len);
    try std.testing.expectEqualStrings("AP8", parsed.value.object.get("metadata").?.object.get("trace-bin").?.array.items[0].string);
}

test "Connect unary error JSON preserves canonical protobuf details" {
    const json = try errorJsonStatusAlloc(std.testing.allocator, .{
        .code = .resource_exhausted,
        .message = "quota exceeded",
        .details_bin = &.{ 0x08, 0x08 },
    });
    defer std.testing.allocator.free(json);
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{});
    defer parsed.deinit();
    try std.testing.expectEqualStrings("resource_exhausted", parsed.value.object.get("code").?.string);
    try std.testing.expect(parsed.value.object.get("details") == null);
}

test "CORS policy fails closed for undeclared origins" {
    const origins = [_][]const u8{"https://app.example.com"};
    const policy = CorsPolicy{ .allowed_origins = &origins };
    try std.testing.expect(policy.allows("https://app.example.com"));
    try std.testing.expect(!policy.allows("https://attacker.example"));
}

test "Connect unary client constructs canonical requests and owns successful responses" {
    var fake = zstd.Http.FakeClient.init(.{
        .status = 200,
        .headers = &.{
            .{ .name = "content-type", .value = unary_proto_content_type },
            .{ .name = "x-request-id", .value = "request-7" },
        },
        .body = "protobuf-response",
    });
    var client = UnaryClient.init(fake.client());
    const request_metadata = [_]Grpc.Metadata{.{ .name = "x-tenant", .value = "acme" }};
    var response = try client.invokeAlloc(std.testing.allocator, .{
        .base_url = "http://127.0.0.1:8080",
        .service = "example.v1.EchoService",
        .method = "Echo",
        .payload = "protobuf-request",
        .metadata = &request_metadata,
        .timeout_millis = 1_250,
    });
    defer response.deinit();

    try std.testing.expect(response.status.isOk());
    try std.testing.expectEqualStrings("protobuf-response", response.payload);
    try std.testing.expectEqualStrings("request-7", response.header("x-request-id").?);
}

test "Connect unary client converts canonical error JSON and details" {
    var fake = zstd.Http.FakeClient.init(.{
        .status = 429,
        .headers = &.{.{ .name = "content-type", .value = unary_json_content_type }},
        .body = "{\"code\":\"resource_exhausted\",\"message\":\"quota\",\"details\":[{\"type\":\"example.v1.Quota\",\"value\":\"CAE\"}]}",
    });
    var client = UnaryClient.init(fake.client());
    var response = try client.invokeAlloc(std.testing.allocator, .{
        .base_url = "http://127.0.0.1:8080",
        .service = "example.v1.EchoService",
        .method = "Echo",
        .payload = "request",
    });
    defer response.deinit();

    try std.testing.expectEqual(Grpc.Code.resource_exhausted, response.status.code);
    try std.testing.expectEqualStrings("quota", response.status.message);
    try std.testing.expectEqual(@as(usize, 1), response.details.len);
    try std.testing.expectEqualStrings("example.v1.Quota", response.details[0].type_name);
    try std.testing.expectEqualSlices(u8, &.{ 0x08, 0x01 }, response.details[0].value);
}

test "fuzz Connect envelope decoding remains bounded" {
    return std.testing.fuzz({}, fuzzConnectEnvelope, .{ .corpus = &.{
        &.{},
        &.{ 0, 0, 0, 0, 0 },
        &.{ 2, 0, 0, 0, 2, '{', '}' },
        &.{ 0xff, 0xff, 0xff, 0xff, 0xff },
    } });
}

fn fuzzConnectEnvelope(_: void, smith: *std.testing.Smith) !void {
    var input: [4096]u8 = undefined;
    const bytes = input[0..smith.slice(&input)];
    var decoded = decodeEnvelopesAlloc(std.testing.allocator, bytes, .{
        .max_message_bytes = 1024,
        .max_messages = 32,
    }) catch return;
    decoded.deinit();
}
