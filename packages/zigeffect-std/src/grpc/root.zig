const std = @import("std");
const Capability = @import("../capability/root.zig");
const Secrets = @import("../secrets/root.zig");
const StdService = @import("../service/root.zig");
const External = @import("../external/root.zig");
const fx = @import("zigeffect");

/// Protocol and service concepts were derived from ziglana/gRPC-zig at
/// ab34a7778193a309fc61117230643d2cbb5c2aaf (Unlicense), then rewritten for
/// Zig 0.16, the published gRPC-over-HTTP/2 protocol, and ZigEffect ownership.
pub const protocol_version = "grpc-http2-v1";
pub const content_type = "application/grpc+proto";

pub const Limits = struct {
    max_message_bytes: usize = 4 * 1024 * 1024,
    max_metadata_bytes: usize = 8 * 1024,
    max_metadata_entries: usize = 128,
    max_stream_messages: usize = 1024,
    max_buffered_message_bytes: usize = 16 * 1024 * 1024,

    pub fn validate(self: Limits) !void {
        if (self.max_message_bytes == 0 or self.max_message_bytes > std.math.maxInt(u32)) return error.InvalidLimits;
        if (self.max_metadata_bytes == 0 or self.max_metadata_entries == 0 or self.max_stream_messages == 0 or
            self.max_buffered_message_bytes < self.max_message_bytes + 5)
        {
            return error.InvalidLimits;
        }
    }
};

pub const Compression = enum {
    identity,
    gzip,
    deflate,

    pub fn headerValue(self: Compression) []const u8 {
        return switch (self) {
            .identity => "identity",
            .gzip => "gzip",
            .deflate => "deflate",
        };
    }

    pub fn parse(value: []const u8) ?Compression {
        inline for (std.meta.tags(Compression)) |candidate| {
            if (std.ascii.eqlIgnoreCase(value, candidate.headerValue())) return candidate;
        }
        return null;
    }
};

pub const FrameOptions = struct {
    limits: Limits = .{},
    compressed: bool = false,
};

pub const CodecError = std.mem.Allocator.Error || error{
    InvalidLimits,
    InvalidFrame,
    InvalidCompressedFlag,
    MessageTooLarge,
    UnsupportedCompression,
    TrailingBytes,
};

pub fn frameMessageAlloc(allocator: std.mem.Allocator, message: []const u8, options: FrameOptions) CodecError![]u8 {
    try options.limits.validate();
    if (message.len > options.limits.max_message_bytes or message.len > std.math.maxInt(u32)) return error.MessageTooLarge;
    const frame = try allocator.alloc(u8, message.len + 5);
    frame[0] = @intFromBool(options.compressed);
    std.mem.writeInt(u32, frame[1..5], @intCast(message.len), .big);
    @memcpy(frame[5..], message);
    return frame;
}

pub fn unframeMessage(frame: []const u8, options: FrameOptions) CodecError![]const u8 {
    try options.limits.validate();
    if (frame.len < 5) return error.InvalidFrame;
    if (frame[0] > 1) return error.InvalidCompressedFlag;
    if (frame[0] == 1 and !options.compressed) return error.UnsupportedCompression;
    const length: usize = std.mem.readInt(u32, frame[1..5], .big);
    if (length > options.limits.max_message_bytes) return error.MessageTooLarge;
    if (length > frame.len - 5) return error.InvalidFrame;
    if (length != frame.len - 5) return error.TrailingBytes;
    return frame[5..];
}

pub fn frameUnaryAlloc(allocator: std.mem.Allocator, message: []const u8, limits: Limits) CodecError![]u8 {
    return frameMessageAlloc(allocator, message, .{ .limits = limits });
}

pub fn unframeUnary(frame: []const u8, limits: Limits) CodecError![]const u8 {
    return unframeMessage(frame, .{ .limits = limits });
}

pub const OwnedMessage = struct {
    bytes: []u8,
    compressed: bool,

    pub fn deinit(self: *OwnedMessage, allocator: std.mem.Allocator) void {
        allocator.free(self.bytes);
        self.* = undefined;
    }
};

pub const MessageDecoder = struct {
    allocator: std.mem.Allocator,
    limits: Limits,
    pending: std.ArrayList(u8) = .empty,
    ready: std.ArrayList(OwnedMessage) = .empty,

    pub fn init(allocator: std.mem.Allocator, limits: Limits) !MessageDecoder {
        try limits.validate();
        return .{ .allocator = allocator, .limits = limits };
    }

    pub fn deinit(self: *MessageDecoder) void {
        self.pending.deinit(self.allocator);
        for (self.ready.items) |*message| message.deinit(self.allocator);
        self.ready.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn push(self: *MessageDecoder, chunk: []const u8) CodecError!void {
        const buffered = std.math.add(usize, self.pending.items.len, chunk.len) catch return error.MessageTooLarge;
        if (buffered > self.limits.max_buffered_message_bytes) return error.MessageTooLarge;
        try self.pending.appendSlice(self.allocator, chunk);
        try self.decodeAvailable();
    }

    pub fn pop(self: *MessageDecoder) ?OwnedMessage {
        if (self.ready.items.len == 0) return null;
        return self.ready.orderedRemove(0);
    }

    pub fn finish(self: *const MessageDecoder) CodecError!void {
        if (self.pending.items.len != 0) return error.InvalidFrame;
    }

    fn decodeAvailable(self: *MessageDecoder) CodecError!void {
        while (self.pending.items.len >= 5) {
            const compressed_flag = self.pending.items[0];
            if (compressed_flag > 1) return error.InvalidCompressedFlag;
            const length: usize = std.mem.readInt(u32, self.pending.items[1..5], .big);
            if (length > self.limits.max_message_bytes) return error.MessageTooLarge;
            const total = length + 5;
            if (self.pending.items.len < total) return;
            if (self.ready.items.len >= self.limits.max_stream_messages) return error.MessageTooLarge;
            const bytes = try self.allocator.dupe(u8, self.pending.items[5..total]);
            errdefer self.allocator.free(bytes);
            try self.ready.append(self.allocator, .{ .bytes = bytes, .compressed = compressed_flag == 1 });
            const remaining = self.pending.items.len - total;
            std.mem.copyForwards(u8, self.pending.items[0..remaining], self.pending.items[total..]);
            self.pending.shrinkRetainingCapacity(remaining);
        }
    }
};

pub const Code = enum(u8) {
    ok = 0,
    cancelled = 1,
    unknown = 2,
    invalid_argument = 3,
    deadline_exceeded = 4,
    not_found = 5,
    already_exists = 6,
    permission_denied = 7,
    resource_exhausted = 8,
    failed_precondition = 9,
    aborted = 10,
    out_of_range = 11,
    unimplemented = 12,
    internal = 13,
    unavailable = 14,
    data_loss = 15,
    unauthenticated = 16,

    pub fn fromInt(value: u8) ?Code {
        if (value > 16) return null;
        return @enumFromInt(value);
    }

    pub fn retryable(self: Code) bool {
        return switch (self) {
            .unavailable, .resource_exhausted, .aborted => true,
            else => false,
        };
    }
};

pub const Status = struct {
    code: Code,
    message: []const u8 = "",
    details_bin: []const u8 = "",

    pub fn ok() Status {
        return .{ .code = .ok };
    }

    pub fn isOk(self: Status) bool {
        return self.code == .ok;
    }
};

pub const MetadataKind = enum { ascii, binary };

pub const Metadata = struct {
    name: []const u8,
    value: []const u8,
    kind: MetadataKind = .ascii,
    sensitive: bool = false,

    pub fn validate(self: Metadata) !void {
        if (self.name.len == 0) return error.InvalidMetadataName;
        for (self.name) |byte| {
            if (std.ascii.isLower(byte) or std.ascii.isDigit(byte) or byte == '_' or byte == '-' or byte == '.') continue;
            return error.InvalidMetadataName;
        }
        if (std.mem.startsWith(u8, self.name, "grpc-")) return error.ReservedMetadataName;
        const binary_name = std.mem.endsWith(u8, self.name, "-bin");
        if (binary_name != (self.kind == .binary)) return error.MetadataKindMismatch;
        if (self.kind == .ascii) {
            for (self.value) |byte| if (byte < 0x20 or byte > 0x7e) return error.InvalidMetadataValue;
        }
    }

    pub fn isSensitive(self: Metadata) bool {
        return self.sensitive or
            std.mem.eql(u8, self.name, "authorization") or
            std.mem.eql(u8, self.name, "proxy-authorization") or
            std.mem.indexOf(u8, self.name, "token") != null or
            std.mem.indexOf(u8, self.name, "secret") != null;
    }
};

pub fn validateMetadata(entries: []const Metadata, limits: Limits) !void {
    try limits.validate();
    if (entries.len > limits.max_metadata_entries) return error.MetadataTooLarge;
    var total: usize = 0;
    for (entries) |entry| {
        try entry.validate();
        total = std.math.add(usize, total, entry.name.len + entry.value.len + 32) catch return error.MetadataTooLarge;
        if (total > limits.max_metadata_bytes) return error.MetadataTooLarge;
    }
}

pub fn encodeBinaryMetadataAlloc(allocator: std.mem.Allocator, value: []const u8) std.mem.Allocator.Error![]u8 {
    const size = std.base64.standard_no_pad.Encoder.calcSize(value.len);
    const encoded = try allocator.alloc(u8, size);
    _ = std.base64.standard_no_pad.Encoder.encode(encoded, value);
    return encoded;
}

pub fn decodeBinaryMetadataAlloc(allocator: std.mem.Allocator, value: []const u8, max_bytes: usize) ![]u8 {
    const Decoder = if (std.mem.endsWith(u8, value, "=")) std.base64.standard.Decoder else std.base64.standard_no_pad.Decoder;
    const size = Decoder.calcSizeForSlice(value) catch return error.InvalidBinaryMetadata;
    if (size > max_bytes) return error.MetadataTooLarge;
    const decoded = try allocator.alloc(u8, size);
    errdefer allocator.free(decoded);
    Decoder.decode(decoded, value) catch return error.InvalidBinaryMetadata;
    return decoded;
}

pub fn encodeGrpcMessageAlloc(allocator: std.mem.Allocator, message: []const u8) std.mem.Allocator.Error![]u8 {
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(allocator);
    const hexadecimal = "0123456789ABCDEF";
    for (message) |byte| {
        if (byte >= 0x20 and byte <= 0x7e and byte != '%') {
            try encoded.append(allocator, byte);
        } else {
            try encoded.appendSlice(allocator, &.{ '%', hexadecimal[byte >> 4], hexadecimal[byte & 0x0f] });
        }
    }
    return encoded.toOwnedSlice(allocator);
}

pub fn decodeGrpcMessageAlloc(allocator: std.mem.Allocator, message: []const u8, max_bytes: usize) ![]u8 {
    if (message.len > max_bytes *| 3) return error.MetadataTooLarge;
    var decoded: std.ArrayList(u8) = .empty;
    errdefer decoded.deinit(allocator);
    var index: usize = 0;
    while (index < message.len) {
        if (message[index] != '%') {
            if (decoded.items.len >= max_bytes) return error.MetadataTooLarge;
            try decoded.append(allocator, message[index]);
            index += 1;
            continue;
        }
        if (index + 2 >= message.len) return error.InvalidGrpcMessage;
        const high = std.fmt.charToDigit(message[index + 1], 16) catch return error.InvalidGrpcMessage;
        const low = std.fmt.charToDigit(message[index + 2], 16) catch return error.InvalidGrpcMessage;
        if (decoded.items.len >= max_bytes) return error.MetadataTooLarge;
        try decoded.append(allocator, @intCast((high << 4) | low));
        index += 3;
    }
    return decoded.toOwnedSlice(allocator);
}

pub const TimeoutUnit = enum { hours, minutes, seconds, milliseconds, microseconds, nanoseconds };

pub const Timeout = struct {
    value: u32,
    unit: TimeoutUnit,

    pub fn encodeAlloc(self: Timeout, allocator: std.mem.Allocator) ![]u8 {
        if (self.value == 0 or self.value > 99_999_999) return error.InvalidTimeout;
        return std.fmt.allocPrint(allocator, "{d}{c}", .{ self.value, timeoutSuffix(self.unit) });
    }

    pub fn parse(value: []const u8) !Timeout {
        if (value.len < 2 or value.len > 9) return error.InvalidTimeout;
        const unit = timeoutUnit(value[value.len - 1]) orelse return error.InvalidTimeout;
        const amount = std.fmt.parseInt(u32, value[0 .. value.len - 1], 10) catch return error.InvalidTimeout;
        if (amount == 0 or amount > 99_999_999) return error.InvalidTimeout;
        return .{ .value = amount, .unit = unit };
    }

    pub fn fromMilliseconds(millis: u64) Timeout {
        if (millis <= 99_999_999) return .{ .value = @intCast(@max(millis, 1)), .unit = .milliseconds };
        const seconds = @min((millis + 999) / 1000, 99_999_999);
        return .{ .value = @intCast(seconds), .unit = .seconds };
    }

    pub fn toMillisecondsCeil(self: Timeout) !u64 {
        if (self.value == 0) return error.InvalidTimeout;
        const value: u64 = self.value;
        return switch (self.unit) {
            .hours => std.math.mul(u64, value, 60 * 60 * 1000) catch error.InvalidTimeout,
            .minutes => std.math.mul(u64, value, 60 * 1000) catch error.InvalidTimeout,
            .seconds => std.math.mul(u64, value, 1000) catch error.InvalidTimeout,
            .milliseconds => value,
            .microseconds => @max(@as(u64, 1), (value + 999) / 1000),
            .nanoseconds => @max(@as(u64, 1), (value + 999_999) / 1_000_000),
        };
    }
};

fn timeoutSuffix(unit: TimeoutUnit) u8 {
    return switch (unit) {
        .hours => 'H',
        .minutes => 'M',
        .seconds => 'S',
        .milliseconds => 'm',
        .microseconds => 'u',
        .nanoseconds => 'n',
    };
}

fn timeoutUnit(suffix: u8) ?TimeoutUnit {
    return switch (suffix) {
        'H' => .hours,
        'M' => .minutes,
        'S' => .seconds,
        'm' => .milliseconds,
        'u' => .microseconds,
        'n' => .nanoseconds,
        else => null,
    };
}

pub const Header = struct {
    name: []const u8,
    value: []const u8,
};

pub fn parseTrailers(trailers: []const Header) !Status {
    var raw_code: ?u8 = null;
    var message: []const u8 = "";
    var details_bin: []const u8 = "";
    for (trailers) |trailer| {
        if (std.ascii.eqlIgnoreCase(trailer.name, "grpc-status")) {
            if (raw_code != null) return error.DuplicateGrpcStatus;
            raw_code = std.fmt.parseInt(u8, trailer.value, 10) catch return error.InvalidGrpcStatus;
        } else if (std.ascii.eqlIgnoreCase(trailer.name, "grpc-message")) {
            message = trailer.value;
        } else if (std.ascii.eqlIgnoreCase(trailer.name, "grpc-status-details-bin")) {
            details_bin = trailer.value;
        }
    }
    const value = raw_code orelse return error.MissingGrpcStatus;
    const code = Code.fromInt(value) orelse return error.UnknownGrpcStatus;
    if (code == .ok and details_bin.len != 0) return error.InvalidStatusDetails;
    return .{ .code = code, .message = message, .details_bin = details_bin };
}

pub const OwnedStatus = struct {
    allocator: std.mem.Allocator,
    status: Status,
    message_storage: []u8,
    details_storage: []u8,

    pub fn deinit(self: *OwnedStatus) void {
        self.allocator.free(self.message_storage);
        self.allocator.free(self.details_storage);
        self.* = undefined;
    }
};

pub fn parseTrailersAlloc(allocator: std.mem.Allocator, trailers: []const Header, limits: Limits) !OwnedStatus {
    try limits.validate();
    const borrowed = try parseTrailers(trailers);
    const message = try decodeGrpcMessageAlloc(allocator, borrowed.message, limits.max_metadata_bytes);
    errdefer allocator.free(message);
    const details = if (borrowed.details_bin.len == 0)
        try allocator.dupe(u8, "")
    else
        try decodeBinaryMetadataAlloc(allocator, borrowed.details_bin, limits.max_metadata_bytes);
    return .{
        .allocator = allocator,
        .status = .{ .code = borrowed.code, .message = message, .details_bin = details },
        .message_storage = message,
        .details_storage = details,
    };
}

pub fn validateResponseHeaders(status: u16, headers: []const Header) !void {
    if (status != 200) return error.InvalidHttpStatus;
    var found_content_type = false;
    for (headers) |header| {
        if (std.ascii.eqlIgnoreCase(header.name, "content-type")) {
            found_content_type = std.mem.startsWith(u8, header.value, "application/grpc");
        }
    }
    if (!found_content_type) return error.InvalidContentType;
}

/// Maps an HTTP status to the fallback gRPC code used only when the peer did
/// not provide `grpc-status`. Applications must never use this in the reverse
/// direction when constructing a gRPC response.
pub fn codeFromHttpStatus(status: u16) Code {
    return switch (status) {
        400 => .internal,
        401 => .unauthenticated,
        403 => .permission_denied,
        404 => .unimplemented,
        429, 502, 503, 504 => .unavailable,
        else => .unknown,
    };
}

pub const HeaderBlock = struct {
    allocator: std.mem.Allocator,
    headers: []Header,

    pub fn deinit(self: *HeaderBlock) void {
        for (self.headers) |header| {
            self.allocator.free(header.name);
            self.allocator.free(header.value);
        }
        self.allocator.free(self.headers);
        self.* = undefined;
    }
};

pub const MetadataBlock = struct {
    allocator: std.mem.Allocator,
    entries: []Metadata,

    pub fn deinit(self: *MetadataBlock) void {
        freeMetadata(self.allocator, self.entries);
        self.* = undefined;
    }
};

pub fn isApplicationMetadataName(name: []const u8) bool {
    if (name.len == 0 or name[0] == ':' or std.mem.startsWith(u8, name, "grpc-")) return false;
    const reserved = [_][]const u8{
        "content-type",
        "te",
        "user-agent",
        "host",
        "origin",
        "connect-protocol-version",
        "connect-timeout-ms",
        "connect-content-encoding",
        "connect-accept-encoding",
    };
    for (reserved) |candidate| if (std.ascii.eqlIgnoreCase(name, candidate)) return false;
    return true;
}

pub fn metadataFromHeadersAlloc(allocator: std.mem.Allocator, headers: []const Header, limits: Limits) !MetadataBlock {
    try limits.validate();
    var entries: std.ArrayList(Metadata) = .empty;
    errdefer {
        for (entries.items) |entry| {
            allocator.free(entry.name);
            allocator.free(entry.value);
        }
        entries.deinit(allocator);
    }
    for (headers) |header| {
        if (!isApplicationMetadataName(header.name)) continue;
        if (entries.items.len >= limits.max_metadata_entries) return error.MetadataTooLarge;
        const name = try allocator.dupe(u8, header.name);
        errdefer allocator.free(name);
        const binary = std.mem.endsWith(u8, name, "-bin");
        const value = if (binary)
            try decodeBinaryMetadataAlloc(allocator, header.value, limits.max_metadata_bytes)
        else
            try allocator.dupe(u8, header.value);
        errdefer allocator.free(value);
        var entry = Metadata{
            .name = name,
            .value = value,
            .kind = if (binary) .binary else .ascii,
        };
        entry.sensitive = entry.isSensitive();
        try entry.validate();
        try entries.append(allocator, entry);
    }
    try validateMetadata(entries.items, limits);
    return .{ .allocator = allocator, .entries = try entries.toOwnedSlice(allocator) };
}

pub fn metadataHeadersAlloc(allocator: std.mem.Allocator, metadata: []const Metadata, limits: Limits) !HeaderBlock {
    try validateMetadata(metadata, limits);
    var headers: std.ArrayList(Header) = .empty;
    errdefer freeHeaderList(allocator, &headers);
    for (metadata) |entry| {
        if (entry.kind == .binary) {
            const encoded = try encodeBinaryMetadataAlloc(allocator, entry.value);
            defer allocator.free(encoded);
            try appendOwnedHeader(allocator, &headers, entry.name, encoded);
        } else try appendOwnedHeader(allocator, &headers, entry.name, entry.value);
    }
    return .{ .allocator = allocator, .headers = try headers.toOwnedSlice(allocator) };
}

pub fn statusTrailersAlloc(allocator: std.mem.Allocator, status: Status, metadata: []const Metadata, limits: Limits) !HeaderBlock {
    return statusTrailersWithPushbackAlloc(allocator, status, metadata, null, limits);
}

pub fn statusTrailersWithPushbackAlloc(allocator: std.mem.Allocator, status: Status, metadata: []const Metadata, retry_pushback_millis: ?i64, limits: Limits) !HeaderBlock {
    if (status.code == .ok and status.details_bin.len != 0) return error.InvalidStatusDetails;
    try validateMetadata(metadata, limits);
    var headers: std.ArrayList(Header) = .empty;
    errdefer freeHeaderList(allocator, &headers);
    for (metadata) |entry| {
        if (entry.kind == .binary) {
            const encoded = try encodeBinaryMetadataAlloc(allocator, entry.value);
            defer allocator.free(encoded);
            try appendOwnedHeader(allocator, &headers, entry.name, encoded);
        } else try appendOwnedHeader(allocator, &headers, entry.name, entry.value);
    }
    var code_buffer: [3]u8 = undefined;
    const code = try std.fmt.bufPrint(&code_buffer, "{d}", .{@intFromEnum(status.code)});
    try appendOwnedHeader(allocator, &headers, "grpc-status", code);
    if (status.message.len != 0) {
        const message = try encodeGrpcMessageAlloc(allocator, status.message);
        defer allocator.free(message);
        try appendOwnedHeader(allocator, &headers, "grpc-message", message);
    }
    if (status.details_bin.len != 0) {
        const details = try encodeBinaryMetadataAlloc(allocator, status.details_bin);
        defer allocator.free(details);
        try appendOwnedHeader(allocator, &headers, "grpc-status-details-bin", details);
    }
    if (retry_pushback_millis) |pushback| {
        var pushback_buffer: [21]u8 = undefined;
        const value = try std.fmt.bufPrint(&pushback_buffer, "{d}", .{pushback});
        try appendOwnedHeader(allocator, &headers, "grpc-retry-pushback-ms", value);
    }
    return .{ .allocator = allocator, .headers = try headers.toOwnedSlice(allocator) };
}

pub fn requestHeadersAlloc(allocator: std.mem.Allocator, request: UnaryRequest, limits: Limits) !HeaderBlock {
    try request.validate(limits);
    var headers: std.ArrayList(Header) = .empty;
    errdefer freeHeaderList(allocator, &headers);

    try appendOwnedHeader(allocator, &headers, ":method", "POST");
    try appendOwnedHeader(allocator, &headers, ":scheme", request.scheme);
    const path = try (Method{ .service = request.service, .method = request.method }).pathAlloc(allocator);
    defer allocator.free(path);
    try appendOwnedHeader(allocator, &headers, ":path", path);
    try appendOwnedHeader(allocator, &headers, ":authority", request.authority);
    const timeout = try Timeout.fromMilliseconds(request.timeout_millis).encodeAlloc(allocator);
    defer allocator.free(timeout);
    try appendOwnedHeader(allocator, &headers, "grpc-timeout", timeout);
    try appendOwnedHeader(allocator, &headers, "content-type", content_type);
    try appendOwnedHeader(allocator, &headers, "te", "trailers");
    try appendOwnedHeader(allocator, &headers, "user-agent", "grpc-zig-zigeffect/0.1.0");
    try appendOwnedHeader(allocator, &headers, "grpc-encoding", request.compression.headerValue());
    try appendOwnedHeader(allocator, &headers, "grpc-accept-encoding", "identity,gzip,deflate");
    for (request.metadata) |entry| {
        if (entry.kind == .binary) {
            const encoded = try encodeBinaryMetadataAlloc(allocator, entry.value);
            defer allocator.free(encoded);
            try appendOwnedHeader(allocator, &headers, entry.name, encoded);
        } else {
            try appendOwnedHeader(allocator, &headers, entry.name, entry.value);
        }
    }
    return .{ .allocator = allocator, .headers = try headers.toOwnedSlice(allocator) };
}

fn appendOwnedHeader(allocator: std.mem.Allocator, headers: *std.ArrayList(Header), name_value: []const u8, value_value: []const u8) !void {
    const name = try allocator.dupe(u8, name_value);
    errdefer allocator.free(name);
    const value = try allocator.dupe(u8, value_value);
    errdefer allocator.free(value);
    try headers.append(allocator, .{ .name = name, .value = value });
}

fn freeHeaderList(allocator: std.mem.Allocator, headers: *std.ArrayList(Header)) void {
    for (headers.items) |header| {
        allocator.free(header.name);
        allocator.free(header.value);
    }
    headers.deinit(allocator);
}

pub const TransportCapabilities = struct {
    http2: bool = false,
    tls: bool = false,
    trailers: bool = false,
    deadlines: bool = false,
    cancellation: bool = false,
    multiplexing: bool = false,
    connection_reuse: bool = false,
    flow_control: bool = false,
    bounded_messages: bool = false,
    redacted_diagnostics: bool = false,
};

pub const Capabilities = TransportCapabilities;

pub fn requireQualified(capabilities: TransportCapabilities) error{TransportNotQualified}!void {
    inline for (@typeInfo(TransportCapabilities).@"struct".fields) |field| {
        if (!@field(capabilities, field.name)) return error.TransportNotQualified;
    }
}

pub const Transport = struct {
    ptr: *anyopaque,
    capabilities: TransportCapabilities,
    invoke_fn: *const fn (*anyopaque, std.mem.Allocator, UnaryRequest, CallOptions) anyerror!UnaryResponse,

    pub fn invokeAlloc(self: Transport, allocator: std.mem.Allocator, request: UnaryRequest, options: CallOptions) anyerror!UnaryResponse {
        try requireQualified(self.capabilities);
        try options.checkActive();
        try request.validate(options.limits);
        return self.invoke_fn(self.ptr, allocator, request, options);
    }
};

pub const QualifiedTransport = struct {
    context: *anyopaque,
    capabilities: Capabilities,
    invoke_fn: *const fn (*anyopaque, std.mem.Allocator, UnaryRequest, Limits) anyerror![]u8,

    pub fn invoke(self: QualifiedTransport, allocator: std.mem.Allocator, request: UnaryRequest, limits: Limits) anyerror![]u8 {
        try requireQualified(self.capabilities);
        try request.validate(limits);
        return self.invoke_fn(self.context, allocator, request, limits);
    }
};

pub const ParityObservation = struct {
    rest_canonical_json: []const u8,
    grpc_canonical_json: []const u8,
    rest_operation: ?[]const u8 = null,
    grpc_operation: ?[]const u8 = null,
};

pub fn requireParity(observation: ParityObservation) error{TransportParityMismatch}!void {
    if (!std.mem.eql(u8, observation.rest_canonical_json, observation.grpc_canonical_json)) return error.TransportParityMismatch;
    if ((observation.rest_operation == null) != (observation.grpc_operation == null)) return error.TransportParityMismatch;
    if (observation.rest_operation) |rest| {
        if (!std.mem.eql(u8, rest, observation.grpc_operation.?)) return error.TransportParityMismatch;
    }
}

pub const CallShape = enum { unary, client_streaming, server_streaming, bidirectional_streaming };
pub const Idempotency = enum { unknown, no_side_effects, idempotent };

pub const Method = struct {
    service: []const u8,
    method: []const u8,
    shape: CallShape = .unary,
    idempotency: Idempotency = .unknown,

    pub fn validate(self: Method) !void {
        try validateServiceName(self.service);
        try validateMethodName(self.method);
    }

    pub fn pathAlloc(self: Method, allocator: std.mem.Allocator) ![]u8 {
        try self.validate();
        return std.fmt.allocPrint(allocator, "/{s}/{s}", .{ self.service, self.method });
    }
};

fn validateServiceName(value: []const u8) !void {
    if (value.len == 0 or value.len > 512 or value[0] == '.' or value[value.len - 1] == '.') return error.InvalidServiceName;
    for (value) |byte| {
        if (std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '.') continue;
        return error.InvalidServiceName;
    }
}

fn validateMethodName(value: []const u8) !void {
    if (value.len == 0 or value.len > 256) return error.InvalidMethodName;
    for (value) |byte| {
        if (std.ascii.isAlphanumeric(byte) or byte == '_') continue;
        return error.InvalidMethodName;
    }
}

pub const Cancellation = struct {
    ptr: *const anyopaque,
    is_cancelled_fn: *const fn (*const anyopaque) bool,

    pub fn isCancelled(self: Cancellation) bool {
        return self.is_cancelled_fn(self.ptr);
    }

    pub fn fromBool(value: *const bool) Cancellation {
        return .{ .ptr = value, .is_cancelled_fn = struct {
            fn check(raw: *const anyopaque) bool {
                const flag: *const bool = @ptrCast(@alignCast(raw));
                return flag.*;
            }
        }.check };
    }
};

pub const CallOptions = struct {
    limits: Limits = .{},
    cancellation: ?Cancellation = null,
    timeout_millis: u64 = 30_000,

    pub fn checkActive(self: CallOptions) !void {
        try self.limits.validate();
        if (self.timeout_millis == 0) return error.InvalidDeadline;
        if (self.cancellation) |cancellation| if (cancellation.isCancelled()) return error.CallCancelled;
    }
};

pub const UnaryRequest = struct {
    authority: []const u8,
    service: []const u8,
    method: []const u8,
    payload: []const u8,
    scheme: []const u8 = "https",
    metadata: []const Metadata = &.{},
    timeout_millis: u64,
    compression: Compression = .identity,
    idempotency: Idempotency = .unknown,

    pub fn validate(self: UnaryRequest, limits: Limits) !void {
        if (self.authority.len == 0 or self.authority.len > 512) return error.InvalidAuthority;
        if (!std.mem.eql(u8, self.scheme, "http") and !std.mem.eql(u8, self.scheme, "https")) return error.InvalidScheme;
        try (Method{ .service = self.service, .method = self.method, .idempotency = self.idempotency }).validate();
        if (self.timeout_millis == 0) return error.InvalidDeadline;
        if (self.payload.len > limits.max_message_bytes) return error.MessageTooLarge;
        try validateMetadata(self.metadata, limits);
    }
};

pub const ResponseTemplate = struct {
    payload: []const u8 = "",
    initial_metadata: []const Metadata = &.{},
    trailing_metadata: []const Metadata = &.{},
    status: Status,
    /// Parsed value of the reserved grpc-retry-pushback-ms response header.
    /// Negative values disable retries; non-negative values replace backoff.
    retry_pushback_millis: ?i64 = null,
};

pub const UnaryResponse = struct {
    allocator: std.mem.Allocator,
    payload: []u8,
    initial_metadata: []Metadata,
    trailing_metadata: []Metadata,
    status: Status,
    retry_pushback_millis: ?i64,
    owned_status_message: []u8,
    owned_status_details: []u8,

    pub fn initAlloc(allocator: std.mem.Allocator, payload: []const u8, status: Status) !UnaryResponse {
        return cloneResponseAlloc(allocator, .{ .payload = payload, .status = status });
    }

    pub fn initFullAlloc(allocator: std.mem.Allocator, template: ResponseTemplate) !UnaryResponse {
        return cloneResponseAlloc(allocator, template);
    }

    pub fn deinit(self: *UnaryResponse) void {
        self.allocator.free(self.payload);
        freeMetadata(self.allocator, self.initial_metadata);
        freeMetadata(self.allocator, self.trailing_metadata);
        self.allocator.free(self.owned_status_message);
        self.allocator.free(self.owned_status_details);
        self.* = undefined;
    }
};

fn cloneResponseAlloc(allocator: std.mem.Allocator, template: ResponseTemplate) !UnaryResponse {
    const payload = try allocator.dupe(u8, template.payload);
    errdefer allocator.free(payload);
    const initial_metadata = try cloneMetadataAlloc(allocator, template.initial_metadata);
    errdefer freeMetadata(allocator, initial_metadata);
    const trailing_metadata = try cloneMetadataAlloc(allocator, template.trailing_metadata);
    errdefer freeMetadata(allocator, trailing_metadata);
    const status_message = try allocator.dupe(u8, template.status.message);
    errdefer allocator.free(status_message);
    const status_details = try allocator.dupe(u8, template.status.details_bin);
    errdefer allocator.free(status_details);
    return .{
        .allocator = allocator,
        .payload = payload,
        .initial_metadata = initial_metadata,
        .trailing_metadata = trailing_metadata,
        .status = .{ .code = template.status.code, .message = status_message, .details_bin = status_details },
        .retry_pushback_millis = template.retry_pushback_millis,
        .owned_status_message = status_message,
        .owned_status_details = status_details,
    };
}

fn cloneMetadataAlloc(allocator: std.mem.Allocator, entries: []const Metadata) ![]Metadata {
    const output = try allocator.alloc(Metadata, entries.len);
    errdefer allocator.free(output);
    var initialized: usize = 0;
    errdefer freeMetadata(allocator, output[0..initialized]);
    for (entries, 0..) |entry, index| {
        const name = try allocator.dupe(u8, entry.name);
        errdefer allocator.free(name);
        const value = try allocator.dupe(u8, entry.value);
        output[index] = .{ .name = name, .value = value, .kind = entry.kind, .sensitive = entry.sensitive };
        initialized += 1;
    }
    return output;
}

fn freeMetadata(allocator: std.mem.Allocator, entries: []Metadata) void {
    for (entries) |entry| {
        allocator.free(entry.name);
        allocator.free(entry.value);
    }
    allocator.free(entries);
}

pub const Client = struct {
    ptr: *anyopaque,
    invoke_fn: *const fn (*anyopaque, std.mem.Allocator, UnaryRequest, CallOptions) anyerror!UnaryResponse,

    pub fn invokeAlloc(self: Client, allocator: std.mem.Allocator, request: UnaryRequest, options: CallOptions) anyerror!UnaryResponse {
        try options.checkActive();
        try request.validate(options.limits);
        return self.invoke_fn(self.ptr, allocator, request, options);
    }
};

pub const FakeClient = struct {
    pub const capability = Capability.Builtin.fake_grpc_client;

    allocator: std.mem.Allocator,
    response: UnaryResponse,

    pub fn initOwned(allocator: std.mem.Allocator, response: ResponseTemplate) !FakeClient {
        return .{ .allocator = allocator, .response = try cloneResponseAlloc(allocator, response) };
    }

    pub fn deinit(self: *FakeClient) void {
        self.response.deinit();
        self.* = undefined;
    }

    pub fn invokeAlloc(self: *FakeClient, allocator: std.mem.Allocator, request: UnaryRequest, options: CallOptions) anyerror!UnaryResponse {
        try options.checkActive();
        try request.validate(options.limits);
        return cloneResponseAlloc(allocator, .{
            .payload = self.response.payload,
            .initial_metadata = self.response.initial_metadata,
            .trailing_metadata = self.response.trailing_metadata,
            .status = self.response.status,
        });
    }

    pub fn client(self: *FakeClient) Client {
        return .{ .ptr = self, .invoke_fn = struct {
            fn invoke(raw: *anyopaque, allocator: std.mem.Allocator, request: UnaryRequest, options: CallOptions) anyerror!UnaryResponse {
                const fake: *FakeClient = @ptrCast(@alignCast(raw));
                return fake.invokeAlloc(allocator, request, options);
            }
        }.invoke };
    }

    pub fn invokeClassifiedAlloc(self: *FakeClient, allocator: std.mem.Allocator, request: UnaryRequest, options: CallOptions) External.Result(UnaryResponse) {
        const response = self.invokeAlloc(allocator, request, options) catch |err| {
            return .{ .failure = External.Failure.fromError("grpc", "call", err) };
        };
        return .{ .success = response };
    }
};

pub const ScriptedClient = struct {
    const Step = union(enum) { response: UnaryResponse, failure: anyerror };

    allocator: std.mem.Allocator,
    steps: std.ArrayList(Step) = .empty,
    cursor: usize = 0,

    pub fn init(allocator: std.mem.Allocator) ScriptedClient {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *ScriptedClient) void {
        for (self.steps.items) |*step| switch (step.*) {
            .response => |*response| response.deinit(),
            .failure => {},
        };
        self.steps.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn addResponse(self: *ScriptedClient, response: ResponseTemplate) !void {
        var owned = try cloneResponseAlloc(self.allocator, response);
        errdefer owned.deinit();
        try self.steps.append(self.allocator, .{ .response = owned });
    }

    pub fn addError(self: *ScriptedClient, failure: anyerror) !void {
        try self.steps.append(self.allocator, .{ .failure = failure });
    }

    pub fn invokeAlloc(self: *ScriptedClient, allocator: std.mem.Allocator, request: UnaryRequest, options: CallOptions) anyerror!UnaryResponse {
        try options.checkActive();
        try request.validate(options.limits);
        if (self.cursor >= self.steps.items.len) return error.ScriptExhausted;
        const step = self.steps.items[self.cursor];
        self.cursor += 1;
        return switch (step) {
            .failure => |failure| failure,
            .response => |response| cloneResponseAlloc(allocator, .{
                .payload = response.payload,
                .initial_metadata = response.initial_metadata,
                .trailing_metadata = response.trailing_metadata,
                .status = response.status,
            }),
        };
    }
};

pub const UnaryHandler = struct {
    ptr: *anyopaque,
    invoke_fn: *const fn (*anyopaque, std.mem.Allocator, UnaryRequest) anyerror!UnaryResponse,

    pub fn from(comptime HandlerType: type, handler: *HandlerType) UnaryHandler {
        return .{ .ptr = handler, .invoke_fn = struct {
            fn invoke(raw: *anyopaque, allocator: std.mem.Allocator, request: UnaryRequest) anyerror!UnaryResponse {
                const typed: *HandlerType = @ptrCast(@alignCast(raw));
                return typed.invoke(allocator, request);
            }
        }.invoke };
    }

    pub fn invokeAlloc(self: UnaryHandler, allocator: std.mem.Allocator, request: UnaryRequest) anyerror!UnaryResponse {
        return self.invoke_fn(self.ptr, allocator, request);
    }
};

pub const RegistryEntry = struct {
    service: []const u8,
    method: []const u8,
    handler: UnaryHandler,
};

pub const Registry = struct {
    pub const capability = Capability.Builtin.in_process_grpc_server;

    allocator: std.mem.Allocator,
    entries: std.ArrayList(RegistryEntry) = .empty,

    pub fn init(allocator: std.mem.Allocator) Registry {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Registry) void {
        for (self.entries.items) |entry| {
            self.allocator.free(entry.service);
            self.allocator.free(entry.method);
        }
        self.entries.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn register(self: *Registry, entry: RegistryEntry) !void {
        try (Method{ .service = entry.service, .method = entry.method }).validate();
        for (self.entries.items) |existing| {
            if (std.mem.eql(u8, existing.service, entry.service) and std.mem.eql(u8, existing.method, entry.method)) return error.DuplicateMethod;
        }
        const service = try self.allocator.dupe(u8, entry.service);
        errdefer self.allocator.free(service);
        const method = try self.allocator.dupe(u8, entry.method);
        errdefer self.allocator.free(method);
        try self.entries.append(self.allocator, .{ .service = service, .method = method, .handler = entry.handler });
    }

    pub fn invokeAlloc(self: *Registry, allocator: std.mem.Allocator, request: UnaryRequest, options: CallOptions) anyerror!UnaryResponse {
        try options.checkActive();
        try request.validate(options.limits);
        for (self.entries.items) |entry| {
            if (std.mem.eql(u8, entry.service, request.service) and std.mem.eql(u8, entry.method, request.method)) {
                return entry.handler.invokeAlloc(allocator, request);
            }
        }
        return error.MethodNotFound;
    }
};

pub const InProcessClient = struct {
    registry: *Registry,

    pub fn init(registry: *Registry) InProcessClient {
        return .{ .registry = registry };
    }

    pub fn invokeAlloc(self: *InProcessClient, allocator: std.mem.Allocator, request: UnaryRequest, options: CallOptions) anyerror!UnaryResponse {
        return self.registry.invokeAlloc(allocator, request, options);
    }

    pub fn client(self: *InProcessClient) Client {
        return .{ .ptr = self, .invoke_fn = struct {
            fn invoke(raw: *anyopaque, allocator: std.mem.Allocator, request: UnaryRequest, options: CallOptions) anyerror!UnaryResponse {
                const client_value: *InProcessClient = @ptrCast(@alignCast(raw));
                return client_value.invokeAlloc(allocator, request, options);
            }
        }.invoke };
    }
};

pub const CallReceipt = struct {
    schema: []const u8 = "zigeffect.grpc-call.v1",
    authority: []const u8,
    service: []const u8,
    method: []const u8,
    shape: CallShape,
    code: Code,
    request_bytes: usize,
    response_bytes: usize,
    compression: Compression,
    retryable: bool,

    pub fn jsonAlloc(self: CallReceipt, allocator: std.mem.Allocator) ![]u8 {
        return Secrets.safeJsonAlloc(allocator, self, .{});
    }
};

pub fn receipt(request: UnaryRequest, response: UnaryResponse) CallReceipt {
    return .{
        .authority = if (Secrets.containsSecret(request.authority)) Secrets.redacted else request.authority,
        .service = if (Secrets.containsSecret(request.service)) Secrets.redacted else request.service,
        .method = if (Secrets.containsSecret(request.method)) Secrets.redacted else request.method,
        .shape = .unary,
        .code = response.status.code,
        .request_bytes = request.payload.len,
        .response_bytes = response.payload.len,
        .compression = request.compression,
        .retryable = response.status.code.retryable() and request.idempotency != .unknown,
    };
}

pub fn InvokeEffect(comptime EffectEnv: type, comptime ClientService: type) type {
    return struct {
        request: UnaryRequest,
        options: CallOptions,

        pub const SuccessType = UnaryResponse;
        pub const FailureType = anyerror;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{ClientService};

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(self: @This(), ctx: *fx.Context(EffectEnv)) anyerror!UnaryResponse {
            const client = ctx.service(ClientService);
            const response = client.invokeAlloc(ctx.allocator, self.request, self.options) catch |err| {
                _ = StdService.recordOperation(ctx, ClientService, "grpc.call", "failure", "bounded gRPC call failed; payload and metadata omitted");
                return err;
            };
            _ = StdService.recordOperation(ctx, ClientService, "grpc.call", "success", "bounded gRPC call succeeded; payload and metadata omitted");
            return response;
        }
    };
}

pub fn invokeEffect(comptime EffectEnv: type, comptime ClientService: type, request: UnaryRequest, options: CallOptions) InvokeEffect(EffectEnv, ClientService) {
    return .{ .request = request, .options = options };
}

pub const StreamingRequest = struct {
    authority: []const u8,
    service: []const u8,
    method: []const u8,
    messages: []const []const u8,
    scheme: []const u8 = "https",
    metadata: []const Metadata = &.{},
    timeout_millis: u64,
    shape: CallShape,

    pub fn validate(self: StreamingRequest, limits: Limits) !void {
        if (self.shape == .unary) return error.InvalidCallShape;
        if (self.messages.len > limits.max_stream_messages) return error.StreamBufferFull;
        try (UnaryRequest{
            .authority = self.authority,
            .service = self.service,
            .method = self.method,
            .payload = "",
            .scheme = self.scheme,
            .metadata = self.metadata,
            .timeout_millis = self.timeout_millis,
        }).validate(limits);
        for (self.messages) |message| if (message.len > limits.max_message_bytes) return error.MessageTooLarge;
    }
};

pub const StreamingResponse = struct {
    allocator: std.mem.Allocator,
    messages: [][]u8,
    initial_metadata: []Metadata,
    trailing_metadata: []Metadata,
    status: Status,
    status_message: []u8,
    status_details: []u8,

    pub fn initAlloc(allocator: std.mem.Allocator, messages: []const []const u8, status: Status) !StreamingResponse {
        return initFullAlloc(allocator, messages, .{ .status = status });
    }

    pub fn initFullAlloc(allocator: std.mem.Allocator, messages: []const []const u8, template: ResponseTemplate) !StreamingResponse {
        const owned = try allocator.alloc([]u8, messages.len);
        errdefer allocator.free(owned);
        var initialized: usize = 0;
        errdefer for (owned[0..initialized]) |message| allocator.free(message);
        for (messages, 0..) |message, index| {
            owned[index] = try allocator.dupe(u8, message);
            initialized += 1;
        }
        const initial_metadata = try cloneMetadataAlloc(allocator, template.initial_metadata);
        errdefer freeMetadata(allocator, initial_metadata);
        const trailing_metadata = try cloneMetadataAlloc(allocator, template.trailing_metadata);
        errdefer freeMetadata(allocator, trailing_metadata);
        const status_message = try allocator.dupe(u8, template.status.message);
        errdefer allocator.free(status_message);
        const status_details = try allocator.dupe(u8, template.status.details_bin);
        errdefer allocator.free(status_details);
        return .{
            .allocator = allocator,
            .messages = owned,
            .initial_metadata = initial_metadata,
            .trailing_metadata = trailing_metadata,
            .status = .{ .code = template.status.code, .message = status_message, .details_bin = status_details },
            .status_message = status_message,
            .status_details = status_details,
        };
    }

    pub fn deinit(self: *StreamingResponse) void {
        for (self.messages) |message| self.allocator.free(message);
        self.allocator.free(self.messages);
        freeMetadata(self.allocator, self.initial_metadata);
        freeMetadata(self.allocator, self.trailing_metadata);
        self.allocator.free(self.status_message);
        self.allocator.free(self.status_details);
        self.* = undefined;
    }
};

pub const StreamingHandler = struct {
    ptr: *anyopaque,
    invoke_fn: *const fn (*anyopaque, std.mem.Allocator, StreamingRequest) anyerror!StreamingResponse,

    pub fn from(comptime HandlerType: type, handler: *HandlerType) StreamingHandler {
        return .{ .ptr = handler, .invoke_fn = struct {
            fn invoke(raw: *anyopaque, allocator: std.mem.Allocator, request: StreamingRequest) anyerror!StreamingResponse {
                return (@as(*HandlerType, @ptrCast(@alignCast(raw)))).invokeStreaming(allocator, request);
            }
        }.invoke };
    }
};

pub const StreamingRegistry = struct {
    const Entry = struct { service: []u8, method: []u8, shape: CallShape, handler: StreamingHandler };
    allocator: std.mem.Allocator,
    entries: std.ArrayList(Entry) = .empty,

    pub fn init(allocator: std.mem.Allocator) StreamingRegistry {
        return .{ .allocator = allocator };
    }
    pub fn deinit(self: *StreamingRegistry) void {
        for (self.entries.items) |entry| {
            self.allocator.free(entry.service);
            self.allocator.free(entry.method);
        }
        self.entries.deinit(self.allocator);
    }
    pub fn register(self: *StreamingRegistry, service: []const u8, method: []const u8, shape: CallShape, handler: StreamingHandler) !void {
        if (shape == .unary) return error.InvalidCallShape;
        try (Method{ .service = service, .method = method, .shape = shape }).validate();
        for (self.entries.items) |entry| if (std.mem.eql(u8, entry.service, service) and std.mem.eql(u8, entry.method, method)) return error.DuplicateMethod;
        const owned_service = try self.allocator.dupe(u8, service);
        errdefer self.allocator.free(owned_service);
        const owned_method = try self.allocator.dupe(u8, method);
        errdefer self.allocator.free(owned_method);
        try self.entries.append(self.allocator, .{ .service = owned_service, .method = owned_method, .shape = shape, .handler = handler });
    }
    pub fn invokeAlloc(self: *StreamingRegistry, allocator: std.mem.Allocator, request: StreamingRequest, limits: Limits) !StreamingResponse {
        try request.validate(limits);
        for (self.entries.items) |entry| if (entry.shape == request.shape and std.mem.eql(u8, entry.service, request.service) and std.mem.eql(u8, entry.method, request.method)) return entry.handler.invoke_fn(entry.handler.ptr, allocator, request);
        return error.MethodNotFound;
    }
    pub fn shapeFor(self: *const StreamingRegistry, service: []const u8, method: []const u8) ?CallShape {
        for (self.entries.items) |entry| if (std.mem.eql(u8, entry.service, service) and std.mem.eql(u8, entry.method, method)) return entry.shape;
        return null;
    }
};

pub fn MessageStream(comptime Message: type) type {
    return struct {
        const Self = @This();
        allocator: std.mem.Allocator,
        max_messages: usize,
        items: std.ArrayList(Message) = .empty,
        closed: bool = false,

        pub fn init(allocator: std.mem.Allocator, max_messages: usize) !Self {
            if (max_messages == 0) return error.InvalidLimits;
            return .{ .allocator = allocator, .max_messages = max_messages };
        }

        pub fn deinit(self: *Self) void {
            self.items.deinit(self.allocator);
            self.* = undefined;
        }

        pub fn push(self: *Self, message: Message) !void {
            if (self.closed) return error.StreamClosed;
            if (self.items.items.len >= self.max_messages) return error.StreamBufferFull;
            try self.items.append(self.allocator, message);
        }

        pub fn pop(self: *Self) ?Message {
            if (self.items.items.len == 0) return null;
            return self.items.orderedRemove(0);
        }

        pub fn close(self: *Self) void {
            self.closed = true;
        }
    };
}

pub const HealthStatus = enum(i32) { unknown = 0, serving = 1, not_serving = 2, service_unknown = 3 };

pub const HealthRegistry = struct {
    allocator: std.mem.Allocator,
    statuses: std.StringHashMap(HealthStatus),
    subscribers: std.ArrayList(*HealthSubscription) = .empty,
    mutex: std.atomic.Mutex = .unlocked,
    revision: std.atomic.Value(u64) = .init(0),

    pub fn init(allocator: std.mem.Allocator) HealthRegistry {
        return .{ .allocator = allocator, .statuses = std.StringHashMap(HealthStatus).init(allocator) };
    }

    pub fn deinit(self: *HealthRegistry) void {
        self.lock();
        for (self.subscribers.items) |subscription| {
            subscription.registry = null;
            subscription.queue.close(subscription.io);
        }
        self.subscribers.deinit(self.allocator);
        var iterator = self.statuses.iterator();
        while (iterator.next()) |entry| self.allocator.free(entry.key_ptr.*);
        self.statuses.deinit();
        self.mutex.unlock();
        self.* = undefined;
    }

    pub fn set(self: *HealthRegistry, service: []const u8, status: HealthStatus) !void {
        self.lock();
        defer self.mutex.unlock();
        if (self.statuses.getPtr(service)) |existing| {
            if (existing.* == status) return;
            existing.* = status;
            const revision = self.revision.fetchAdd(1, .release) + 1;
            self.publish(service, revision);
            return;
        }
        const owned = try self.allocator.dupe(u8, service);
        errdefer self.allocator.free(owned);
        try self.statuses.put(owned, status);
        const revision = self.revision.fetchAdd(1, .release) + 1;
        self.publish(service, revision);
    }

    pub fn check(self: *const HealthRegistry, service: []const u8) HealthStatus {
        const mutable: *HealthRegistry = @constCast(self);
        mutable.lock();
        defer mutable.mutex.unlock();
        return mutable.statuses.get(service) orelse .service_unknown;
    }

    pub fn currentRevision(self: *const HealthRegistry) u64 {
        return self.revision.load(.acquire);
    }

    pub fn subscribe(self: *HealthRegistry, io: std.Io, service: []const u8) !*HealthSubscription {
        const subscription = try self.allocator.create(HealthSubscription);
        errdefer self.allocator.destroy(subscription);
        const owned_service = try self.allocator.dupe(u8, service);
        errdefer self.allocator.free(owned_service);
        const storage = try self.allocator.alloc(u64, 1);
        errdefer self.allocator.free(storage);
        subscription.* = .{
            .allocator = self.allocator,
            .registry = self,
            .io = io,
            .service = owned_service,
            .storage = storage,
            .queue = std.Io.Queue(u64).init(storage),
        };
        self.lock();
        defer self.mutex.unlock();
        try self.subscribers.append(self.allocator, subscription);
        return subscription;
    }

    fn unsubscribe(self: *HealthRegistry, subscription: *HealthSubscription) void {
        self.lock();
        defer self.mutex.unlock();
        for (self.subscribers.items, 0..) |candidate, index| {
            if (candidate != subscription) continue;
            _ = self.subscribers.swapRemove(index);
            return;
        }
    }

    fn publish(self: *HealthRegistry, service: []const u8, revision: u64) void {
        for (self.subscribers.items) |subscription| {
            if (subscription.service.len != 0 and !std.mem.eql(u8, subscription.service, service)) continue;
            _ = subscription.queue.put(subscription.io, &.{revision}, 0) catch {};
        }
    }

    fn lock(self: *HealthRegistry) void {
        while (!self.mutex.tryLock()) std.Thread.yield() catch {};
    }
};

pub const HealthSubscription = struct {
    allocator: std.mem.Allocator,
    registry: ?*HealthRegistry,
    io: std.Io,
    service: []u8,
    storage: []u64,
    queue: std.Io.Queue(u64),

    pub fn receive(self: *HealthSubscription) !u64 {
        return self.queue.getOne(self.io);
    }

    pub fn deinit(self: *HealthSubscription) void {
        if (self.registry) |registry| registry.unsubscribe(self);
        self.queue.close(self.io);
        self.allocator.free(self.service);
        self.allocator.free(self.storage);
        const allocator = self.allocator;
        allocator.destroy(self);
    }
};

test "health registry broadcasts bounded service-specific revisions" {
    var health = HealthRegistry.init(std.testing.allocator);
    defer health.deinit();
    var orders = try health.subscribe(std.testing.io, "orders.v1.Orders");
    defer orders.deinit();
    try health.set("billing.v1.Billing", .serving);
    var empty: [1]u64 = undefined;
    try std.testing.expectEqual(@as(usize, 0), try orders.queue.get(std.testing.io, &empty, 0));
    try health.set("orders.v1.Orders", .serving);
    try std.testing.expectEqual(@as(u64, 2), try orders.receive());
    try health.set("orders.v1.Orders", .not_serving);
    try health.set("orders.v1.Orders", .serving);
    const coalesced = try orders.receive();
    try std.testing.expect(coalesced == 3 or coalesced == 4);
}

test "gRPC unary codec uses the canonical five-byte network-order prefix" {
    const frame = try frameMessageAlloc(std.testing.allocator, "hello", .{});
    defer std.testing.allocator.free(frame);

    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0, 5 }, frame[0..5]);
    try std.testing.expectEqualStrings("hello", try unframeMessage(frame, .{}));
    try std.testing.expectError(error.MessageTooLarge, unframeMessage(frame, .{ .limits = .{ .max_message_bytes = 4 } }));

    var compressed = frame;
    compressed[0] = 1;
    try std.testing.expectError(error.UnsupportedCompression, unframeMessage(compressed, .{}));
}

test "gRPC message decoder accepts fragmented and coalesced stream data" {
    const first = try frameMessageAlloc(std.testing.allocator, "one", .{});
    defer std.testing.allocator.free(first);
    const second = try frameMessageAlloc(std.testing.allocator, "two", .{});
    defer std.testing.allocator.free(second);

    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(std.testing.allocator);
    try wire.appendSlice(std.testing.allocator, first);
    try wire.appendSlice(std.testing.allocator, second);

    var decoder = try MessageDecoder.init(std.testing.allocator, .{ .max_message_bytes = 16 });
    defer decoder.deinit();
    try decoder.push(wire.items[0..2]);
    try decoder.push(wire.items[2..7]);
    try decoder.push(wire.items[7..]);
    try decoder.finish();

    var decoded_first = decoder.pop().?;
    defer decoded_first.deinit(std.testing.allocator);
    var decoded_second = decoder.pop().?;
    defer decoded_second.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("one", decoded_first.bytes);
    try std.testing.expectEqualStrings("two", decoded_second.bytes);
    try std.testing.expect(decoder.pop() == null);
}

test "gRPC metadata validates binary values and timeouts" {
    const entries = [_]Metadata{
        .{ .name = "x-request-id", .value = "req-1" },
        .{ .name = "trace-bin", .value = "raw\x00bytes", .kind = .binary },
    };
    try validateMetadata(&entries, .{});

    const encoded = try encodeBinaryMetadataAlloc(std.testing.allocator, entries[1].value);
    defer std.testing.allocator.free(encoded);
    const decoded = try decodeBinaryMetadataAlloc(std.testing.allocator, encoded, 64);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualStrings(entries[1].value, decoded);
    try std.testing.expectError(error.ReservedMetadataName, (Metadata{ .name = "grpc-status", .value = "0" }).validate());

    const timeout = try Timeout.parse("250m");
    const timeout_text = try timeout.encodeAlloc(std.testing.allocator);
    defer std.testing.allocator.free(timeout_text);
    try std.testing.expectEqualStrings("250m", timeout_text);
}

test "gRPC trailers require a canonical status and retain unknown wire failures" {
    const status = try parseTrailers(&.{
        .{ .name = "grpc-status", .value = "8" },
        .{ .name = "grpc-message", .value = "quota%20exceeded" },
    });
    try std.testing.expectEqual(Code.resource_exhausted, status.code);
    try std.testing.expectEqualStrings("quota%20exceeded", status.message);
    try std.testing.expect(status.code.retryable());
    try std.testing.expectError(error.MissingGrpcStatus, parseTrailers(&.{}));
    try std.testing.expectError(error.UnknownGrpcStatus, parseTrailers(&.{.{ .name = "grpc-status", .value = "99" }}));
}

test "owned trailer status decodes percent messages and binary details" {
    const encoded_message = try encodeGrpcMessageAlloc(std.testing.allocator, "bad request: 100% invalid\n");
    defer std.testing.allocator.free(encoded_message);
    const encoded_details = try encodeBinaryMetadataAlloc(std.testing.allocator, &.{ 0x08, 0x03, 0xff });
    defer std.testing.allocator.free(encoded_details);

    var parsed = try parseTrailersAlloc(std.testing.allocator, &.{
        .{ .name = "grpc-status", .value = "3" },
        .{ .name = "grpc-message", .value = encoded_message },
        .{ .name = "grpc-status-details-bin", .value = encoded_details },
    }, .{});
    defer parsed.deinit();

    try std.testing.expectEqual(Code.invalid_argument, parsed.status.code);
    try std.testing.expectEqualStrings("bad request: 100% invalid\n", parsed.status.message);
    try std.testing.expectEqualSlices(u8, &.{ 0x08, 0x03, 0xff }, parsed.status.details_bin);
}

test "status trailer generation preserves repeated and binary application metadata" {
    const metadata = [_]Metadata{
        .{ .name = "request-id", .value = "req-1" },
        .{ .name = "trace-bin", .value = &.{ 0x00, 0xff }, .kind = .binary },
        .{ .name = "request-id", .value = "req-2" },
    };
    var trailers = try statusTrailersAlloc(std.testing.allocator, .{
        .code = .resource_exhausted,
        .message = "slow down",
        .details_bin = &.{ 0x08, 0x08 },
    }, &metadata, .{});
    defer trailers.deinit();

    try std.testing.expectEqual(@as(usize, 6), trailers.headers.len);
    var decoded = try metadataFromHeadersAlloc(std.testing.allocator, trailers.headers, .{});
    defer decoded.deinit();
    try std.testing.expectEqual(@as(usize, 3), decoded.entries.len);
    try std.testing.expectEqualStrings("req-1", decoded.entries[0].value);
    try std.testing.expectEqualSlices(u8, &.{ 0x00, 0xff }, decoded.entries[1].value);
    try std.testing.expectEqualStrings("req-2", decoded.entries[2].value);
}

test "grpc timeout converts every unit with a nonzero ceiling" {
    try std.testing.expectEqual(@as(u64, 3_600_000), try (Timeout{ .value = 1, .unit = .hours }).toMillisecondsCeil());
    try std.testing.expectEqual(@as(u64, 60_000), try (Timeout{ .value = 1, .unit = .minutes }).toMillisecondsCeil());
    try std.testing.expectEqual(@as(u64, 1_000), try (Timeout{ .value = 1, .unit = .seconds }).toMillisecondsCeil());
    try std.testing.expectEqual(@as(u64, 1), try (Timeout{ .value = 1, .unit = .milliseconds }).toMillisecondsCeil());
    try std.testing.expectEqual(@as(u64, 1), try (Timeout{ .value = 1, .unit = .microseconds }).toMillisecondsCeil());
    try std.testing.expectEqual(@as(u64, 1), try (Timeout{ .value = 1, .unit = .nanoseconds }).toMillisecondsCeil());
}

test "owned unary and streaming responses preserve both metadata phases" {
    const initial = [_]Metadata{.{ .name = "server", .value = "zigeffect" }};
    const trailing = [_]Metadata{.{ .name = "quota", .value = "remaining" }};
    var unary = try UnaryResponse.initFullAlloc(std.testing.allocator, .{
        .payload = "ok",
        .initial_metadata = &initial,
        .trailing_metadata = &trailing,
        .status = .ok(),
    });
    defer unary.deinit();
    try std.testing.expectEqualStrings("zigeffect", unary.initial_metadata[0].value);
    try std.testing.expectEqualStrings("remaining", unary.trailing_metadata[0].value);

    var streaming = try StreamingResponse.initFullAlloc(std.testing.allocator, &.{"one"}, .{
        .initial_metadata = &initial,
        .trailing_metadata = &trailing,
        .status = .{ .code = .data_loss, .message = "truncated" },
    });
    defer streaming.deinit();
    try std.testing.expectEqualStrings("zigeffect", streaming.initial_metadata[0].value);
    try std.testing.expectEqualStrings("remaining", streaming.trailing_metadata[0].value);
    try std.testing.expectEqualStrings("truncated", streaming.status.message);
}

test "HTTP fallback status mapping follows the gRPC protocol table" {
    try std.testing.expectEqual(Code.internal, codeFromHttpStatus(400));
    try std.testing.expectEqual(Code.unauthenticated, codeFromHttpStatus(401));
    try std.testing.expectEqual(Code.permission_denied, codeFromHttpStatus(403));
    try std.testing.expectEqual(Code.unimplemented, codeFromHttpStatus(404));
    try std.testing.expectEqual(Code.unavailable, codeFromHttpStatus(429));
    try std.testing.expectEqual(Code.unavailable, codeFromHttpStatus(502));
    try std.testing.expectEqual(Code.unavailable, codeFromHttpStatus(503));
    try std.testing.expectEqual(Code.unavailable, codeFromHttpStatus(504));
    try std.testing.expectEqual(Code.unknown, codeFromHttpStatus(418));
    try std.testing.expectEqual(Code.unknown, codeFromHttpStatus(200));
}

test "gRPC transport qualification fails closed" {
    try std.testing.expectError(error.TransportNotQualified, requireQualified(.{
        .http2 = true,
        .tls = true,
        .trailers = true,
        .deadlines = true,
        .cancellation = true,
        .multiplexing = true,
        .connection_reuse = true,
        .flow_control = false,
        .bounded_messages = true,
        .redacted_diagnostics = true,
    }));
    try requireQualified(.{
        .http2 = true,
        .tls = true,
        .trailers = true,
        .deadlines = true,
        .cancellation = true,
        .multiplexing = true,
        .connection_reuse = true,
        .flow_control = true,
        .bounded_messages = true,
        .redacted_diagnostics = true,
    });
}

test "gRPC exact registry routing and in-process client preserve status" {
    const Echo = struct {
        fn invoke(_: *@This(), allocator: std.mem.Allocator, request: UnaryRequest) anyerror!UnaryResponse {
            return UnaryResponse.initAlloc(allocator, request.payload, .ok());
        }
    };
    var echo = Echo{};
    var registry = Registry.init(std.testing.allocator);
    defer registry.deinit();
    try registry.register(.{
        .service = "example.v1.Echo",
        .method = "Say",
        .handler = UnaryHandler.from(Echo, &echo),
    });

    var client = InProcessClient.init(&registry);
    var response = try client.invokeAlloc(std.testing.allocator, .{
        .authority = "local",
        .service = "example.v1.Echo",
        .method = "Say",
        .payload = "hello",
        .timeout_millis = 1000,
    }, .{});
    defer response.deinit();
    try std.testing.expectEqualStrings("hello", response.payload);
    try std.testing.expect(response.status.isOk());

    try std.testing.expectError(error.MethodNotFound, client.invokeAlloc(std.testing.allocator, .{
        .authority = "local",
        .service = "example.v1.Echo",
        .method = "Missing",
        .payload = "hello",
        .timeout_millis = 1000,
    }, .{}));
}

test "gRPC invokeEffect resolves a client service and records a redacted causal fact" {
    var fake = try FakeClient.initOwned(std.testing.allocator, .{
        .payload = "accepted",
        .status = .ok(),
    });
    defer fake.deinit();
    var provider = StdService.Provider(.{FakeClient}).init(.{&fake});
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    var runtime = fx.Runtime(@TypeOf(provider)).init(std.testing.allocator, &provider).provides(.{FakeClient}).withCausalStore(&store);

    var response = try runtime.run(invokeEffect(@TypeOf(provider), FakeClient, .{
        .authority = "api.example.test",
        .service = "orders.v1.Orders",
        .method = "Create",
        .payload = "token=sentinel-secret-for-tests",
        .timeout_millis = 1000,
    }, .{}));
    defer response.deinit();
    try std.testing.expectEqualStrings("accepted", response.payload);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    const index = StdService.findOperation(snapshot, FakeClient, "grpc.call", "success").?;
    try std.testing.expect(std.mem.indexOf(u8, snapshot.events[index].redacted_detail, "sentinel-secret") == null);
}

test "gRPC request headers preserve canonical pseudo-header order and hide binary bytes" {
    var headers = try requestHeadersAlloc(std.testing.allocator, .{
        .authority = "api.example.test",
        .service = "example.v1.Echo",
        .method = "Say",
        .payload = "hello",
        .metadata = &.{
            .{ .name = "authorization", .value = "Bearer sentinel-secret-for-tests", .sensitive = true },
            .{ .name = "trace-bin", .value = "\x00\xff", .kind = .binary },
        },
        .timeout_millis = 250,
    }, .{});
    defer headers.deinit();

    try std.testing.expectEqualStrings(":method", headers.headers[0].name);
    try std.testing.expectEqualStrings(":scheme", headers.headers[1].name);
    try std.testing.expectEqualStrings(":path", headers.headers[2].name);
    try std.testing.expectEqualStrings("/example.v1.Echo/Say", headers.headers[2].value);
    try std.testing.expectEqualStrings(":authority", headers.headers[3].name);
    try std.testing.expectEqualStrings("grpc-timeout", headers.headers[4].name);
    try std.testing.expectEqualStrings("250m", headers.headers[4].value);
    try std.testing.expect(!std.mem.eql(u8, headers.headers[headers.headers.len - 1].value, "\x00\xff"));
}

test "gRPC deterministic streams, health, cancellation, and receipts are bounded" {
    var stream = try MessageStream(u32).init(std.testing.allocator, 2);
    defer stream.deinit();
    try stream.push(1);
    try stream.push(2);
    try std.testing.expectError(error.StreamBufferFull, stream.push(3));
    try std.testing.expectEqual(@as(u32, 1), stream.pop().?);
    stream.close();
    try std.testing.expectError(error.StreamClosed, stream.push(4));

    var health = HealthRegistry.init(std.testing.allocator);
    defer health.deinit();
    try health.set("example.v1.Echo", .serving);
    try std.testing.expectEqual(HealthStatus.serving, health.check("example.v1.Echo"));
    try std.testing.expectEqual(HealthStatus.service_unknown, health.check("missing.v1.Service"));

    var cancelled = true;
    var fake = try FakeClient.initOwned(std.testing.allocator, .{ .status = .ok() });
    defer fake.deinit();
    try std.testing.expectError(error.CallCancelled, fake.invokeAlloc(std.testing.allocator, .{
        .authority = "api.example.test",
        .service = "example.v1.Echo",
        .method = "Say",
        .payload = "",
        .timeout_millis = 1,
    }, .{ .cancellation = Cancellation.fromBool(&cancelled) }));

    var response = try UnaryResponse.initAlloc(std.testing.allocator, "ok", .{ .code = .unavailable });
    defer response.deinit();
    const call_receipt = receipt(.{
        .authority = "token=sentinel-secret-for-tests",
        .service = "example.v1.Echo",
        .method = "Say",
        .payload = "private payload",
        .timeout_millis = 100,
        .idempotency = .idempotent,
    }, response);
    const json = try call_receipt.jsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "sentinel-secret") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "private payload") == null);
    try std.testing.expect(call_receipt.retryable);
}

test "gRPC owned protocol boundaries release every partial allocation" {
    const Harness = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var headers = try requestHeadersAlloc(allocator, .{
                .authority = "api.example.test",
                .service = "example.v1.Echo",
                .method = "Say",
                .payload = "hello",
                .metadata = &.{
                    .{ .name = "request-id", .value = "req-1" },
                    .{ .name = "trace-bin", .value = "raw", .kind = .binary },
                },
                .timeout_millis = 100,
            }, .{});
            defer headers.deinit();

            var response = try UnaryResponse.initAlloc(allocator, "accepted", .{
                .code = .ok,
                .message = "safe",
            });
            defer response.deinit();
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Harness.run, .{});
}

test "fuzz gRPC framing metadata and status parsing remain bounded" {
    return std.testing.fuzz({}, fuzzProtocolBoundaries, .{ .corpus = &.{
        &.{},
        &.{ 0, 0, 0, 0, 0 },
        "grpc-status:0",
        &.{ 1, 0xff, 0xff, 0xff, 0xff },
    } });
}

fn fuzzProtocolBoundaries(_: void, smith: *std.testing.Smith) !void {
    var input: [4096]u8 = undefined;
    const bytes = input[0..smith.slice(&input)];
    var decoder = try MessageDecoder.init(std.testing.allocator, .{
        .max_message_bytes = 1024,
        .max_buffered_message_bytes = 4096,
        .max_stream_messages = 32,
    });
    defer decoder.deinit();
    decoder.push(bytes) catch return;
    _ = decoder.finish() catch {};
    while (decoder.pop()) |message_value| {
        var message = message_value;
        message.deinit(std.testing.allocator);
    }

    const headers = [_]Header{.{ .name = "fuzz-bin", .value = bytes }};
    if (metadataFromHeadersAlloc(std.testing.allocator, &headers, .{
        .max_metadata_bytes = 4096,
        .max_metadata_entries = 4,
    })) |block_value| {
        var block = block_value;
        block.deinit();
    } else |_| {}
}
