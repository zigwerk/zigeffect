const std = @import("std");
const zstd = @import("zigeffect_std");

pub const Grpc = zstd.Grpc;

pub const Context = struct {
    authority: []const u8,
    service: []const u8,
    method: []const u8,
    shape: Grpc.CallShape,
};

pub const Provider = struct {
    pointer: *anyopaque,
    metadata_fn: *const fn (*anyopaque, std.mem.Allocator, Context) anyerror!Grpc.MetadataBlock,

    pub fn from(comptime Target: type, target: *Target) Provider {
        return .{
            .pointer = target,
            .metadata_fn = struct {
                fn acquire(pointer: *anyopaque, allocator: std.mem.Allocator, context: Context) anyerror!Grpc.MetadataBlock {
                    return (@as(*Target, @ptrCast(@alignCast(pointer)))).metadataAlloc(allocator, context);
                }
            }.acquire,
        };
    }

    pub fn metadataAlloc(self: Provider, allocator: std.mem.Allocator, context: Context) anyerror!Grpc.MetadataBlock {
        return self.metadata_fn(self.pointer, allocator, context);
    }
};

pub const ClockSource = struct {
    pointer: *anyopaque,
    now_fn: *const fn (*anyopaque) u64,

    pub fn from(comptime Target: type, target: *Target) ClockSource {
        return .{ .pointer = target, .now_fn = struct {
            fn now(pointer: *anyopaque) u64 {
                return (@as(*Target, @ptrCast(@alignCast(pointer)))).nowMillis();
            }
        }.now };
    }
};

pub const Token = struct {
    allocator: std.mem.Allocator,
    value: []u8,
    expires_at_millis: u64,

    pub fn deinit(self: *Token) void {
        self.allocator.free(self.value);
        self.* = undefined;
    }
};

pub const TokenSource = struct {
    pointer: *anyopaque,
    fetch_fn: *const fn (*anyopaque, std.mem.Allocator, []const u8) anyerror!Token,

    pub fn from(comptime Target: type, target: *Target) TokenSource {
        return .{ .pointer = target, .fetch_fn = struct {
            fn fetch(pointer: *anyopaque, allocator: std.mem.Allocator, audience: []const u8) anyerror!Token {
                return (@as(*Target, @ptrCast(@alignCast(pointer)))).fetchTokenAlloc(allocator, audience);
            }
        }.fetch };
    }
};

/// A single-flight, pre-expiry refreshing bearer credential. Returned metadata
/// is independently owned by the call, so concurrent refresh never invalidates
/// an in-flight HTTP/2 stream.
pub const CachedBearer = struct {
    allocator: std.mem.Allocator,
    audience: []u8,
    source: TokenSource,
    clock: ClockSource,
    refresh_skew_millis: u64 = 5 * 60 * 1000,
    cached: ?Token = null,
    mutex: std.atomic.Mutex = .unlocked,
    refreshes: std.atomic.Value(usize) = .init(0),

    pub fn initAlloc(allocator: std.mem.Allocator, audience: []const u8, source: TokenSource, clock: ClockSource) !CachedBearer {
        if (audience.len == 0 or audience.len > 2048) return error.InvalidAudience;
        return .{
            .allocator = allocator,
            .audience = try allocator.dupe(u8, audience),
            .source = source,
            .clock = clock,
        };
    }

    pub fn deinit(self: *CachedBearer) void {
        self.lock();
        if (self.cached) |*token| token.deinit();
        self.allocator.free(self.audience);
        self.mutex.unlock();
        self.* = undefined;
    }

    pub fn provider(self: *CachedBearer) Provider {
        return Provider.from(CachedBearer, self);
    }

    pub fn metadataAlloc(self: *CachedBearer, allocator: std.mem.Allocator, _: Context) !Grpc.MetadataBlock {
        self.lock();
        defer self.mutex.unlock();
        const now = self.clock.now_fn(self.clock.pointer);
        if (self.cached == null or now +| self.refresh_skew_millis >= self.cached.?.expires_at_millis) {
            var replacement = try self.source.fetch_fn(self.source.pointer, self.allocator, self.audience);
            errdefer replacement.deinit();
            if (replacement.value.len == 0 or replacement.value.len > 64 * 1024 or replacement.expires_at_millis <= now) return error.InvalidIdentityToken;
            if (self.cached) |*previous| previous.deinit();
            self.cached = replacement;
            _ = self.refreshes.fetchAdd(1, .monotonic);
        }
        const name = try allocator.dupe(u8, "authorization");
        errdefer allocator.free(name);
        const value = try std.fmt.allocPrint(allocator, "Bearer {s}", .{self.cached.?.value});
        errdefer allocator.free(value);
        const entries = try allocator.alloc(Grpc.Metadata, 1);
        entries[0] = .{ .name = name, .value = value, .sensitive = true };
        return .{ .allocator = allocator, .entries = entries };
    }

    fn lock(self: *CachedBearer) void {
        while (!self.mutex.tryLock()) std.Thread.yield() catch {};
    }
};

/// Cloud Run/Compute metadata-server ID token source. The endpoint is fixed,
/// requests carry the required Metadata-Flavor header, redirects are disabled,
/// and responses are bounded before the JWT expiry is decoded for caching.
pub const MetadataServer = struct {
    allocator: std.mem.Allocator,
    client: std.http.Client,
    response_limit: usize = 64 * 1024,

    pub fn init(allocator: std.mem.Allocator, io: std.Io) MetadataServer {
        return .{ .allocator = allocator, .client = .{ .allocator = allocator, .io = io } };
    }

    pub fn deinit(self: *MetadataServer) void {
        self.client.deinit();
        self.* = undefined;
    }

    pub fn source(self: *MetadataServer) TokenSource {
        return TokenSource.from(MetadataServer, self);
    }

    pub fn fetchTokenAlloc(self: *MetadataServer, allocator: std.mem.Allocator, audience: []const u8) !Token {
        if (audience.len == 0 or audience.len > 2048) return error.InvalidAudience;
        const encoded = try percentEncodeAlloc(allocator, audience);
        defer allocator.free(encoded);
        const url = try std.fmt.allocPrint(allocator, "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity?audience={s}", .{encoded});
        defer allocator.free(url);
        const response_buffer = try allocator.alloc(u8, self.response_limit);
        defer allocator.free(response_buffer);
        var writer = std.Io.Writer.fixed(response_buffer);
        const headers = [_]std.http.Header{.{ .name = "Metadata-Flavor", .value = "Google" }};
        const result = try self.client.fetch(.{
            .location = .{ .url = url },
            .response_writer = &writer,
            .extra_headers = &headers,
            .redirect_behavior = .unhandled,
            .keep_alive = true,
        });
        if (result.status != .ok) return error.MetadataIdentityRejected;
        const token_bytes = std.mem.trim(u8, writer.buffered(), " \t\r\n");
        if (token_bytes.len == 0 or token_bytes.len > 64 * 1024) return error.InvalidIdentityToken;
        return .{
            .allocator = allocator,
            .value = try allocator.dupe(u8, token_bytes),
            .expires_at_millis = try jwtExpiryMillisAlloc(allocator, token_bytes),
        };
    }
};

fn percentEncodeAlloc(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    const hex = "0123456789ABCDEF";
    for (value) |byte| {
        if (std.ascii.isAlphanumeric(byte) or byte == '-' or byte == '.' or byte == '_' or byte == '~') {
            try output.writer.writeByte(byte);
        } else {
            try output.writer.writeAll(&.{ '%', hex[byte >> 4], hex[byte & 0x0f] });
        }
    }
    return output.toOwnedSlice();
}

fn jwtExpiryMillisAlloc(allocator: std.mem.Allocator, token: []const u8) !u64 {
    const first = std.mem.indexOfScalar(u8, token, '.') orelse return error.InvalidIdentityToken;
    const second = std.mem.indexOfScalarPos(u8, token, first + 1, '.') orelse return error.InvalidIdentityToken;
    const payload = token[first + 1 .. second];
    const length = std.base64.url_safe_no_pad.Decoder.calcSizeForSlice(payload) catch return error.InvalidIdentityToken;
    if (length == 0 or length > 32 * 1024) return error.InvalidIdentityToken;
    const decoded = try allocator.alloc(u8, length);
    defer allocator.free(decoded);
    std.base64.url_safe_no_pad.Decoder.decode(decoded, payload) catch return error.InvalidIdentityToken;
    const Claims = struct { exp: u64 };
    var parsed = std.json.parseFromSlice(Claims, allocator, decoded, .{ .ignore_unknown_fields = true }) catch return error.InvalidIdentityToken;
    defer parsed.deinit();
    return std.math.mul(u64, parsed.value.exp, 1000) catch error.InvalidIdentityToken;
}

test "cached bearer refresh is single-flight and returns call-owned sensitive metadata" {
    const Clock = struct {
        now: u64 = 1_000,
        fn nowMillis(self: *@This()) u64 {
            return self.now;
        }
    };
    const Source = struct {
        calls: usize = 0,
        fn fetchTokenAlloc(self: *@This(), allocator: std.mem.Allocator, audience: []const u8) !Token {
            try std.testing.expectEqualStrings("https://orders.run.app/", audience);
            self.calls += 1;
            return .{
                .allocator = allocator,
                .value = try std.fmt.allocPrint(allocator, "token-{d}", .{self.calls}),
                .expires_at_millis = if (self.calls == 1) 400_000 else 800_000,
            };
        }
    };
    var clock = Clock{};
    var source = Source{};
    var bearer = try CachedBearer.initAlloc(std.testing.allocator, "https://orders.run.app/", TokenSource.from(Source, &source), ClockSource.from(Clock, &clock));
    defer bearer.deinit();
    const context = Context{ .authority = "orders.run.app", .service = "orders.v1.Orders", .method = "Get", .shape = .unary };
    var first = try bearer.metadataAlloc(std.testing.allocator, context);
    defer first.deinit();
    var second = try bearer.metadataAlloc(std.testing.allocator, context);
    defer second.deinit();
    try std.testing.expectEqualStrings("Bearer token-1", first.entries[0].value);
    try std.testing.expect(first.entries[0].sensitive);
    try std.testing.expectEqual(@as(usize, 1), source.calls);
    clock.now = 150_000;
    var refreshed = try bearer.metadataAlloc(std.testing.allocator, context);
    defer refreshed.deinit();
    try std.testing.expectEqualStrings("Bearer token-2", refreshed.entries[0].value);
    try std.testing.expectEqual(@as(usize, 2), source.calls);
}
