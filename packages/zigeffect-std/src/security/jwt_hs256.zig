const std = @import("std");
const Security = @import("root.zig");

pub const Header = struct { alg: []const u8 = "HS256", kid: []const u8, typ: []const u8 = "JWT" };
pub const Claims = struct {
    sub: []const u8,
    iss: []const u8,
    aud: ?[]const u8 = null,
    iat: u64,
    exp: u64,
    nbf: ?u64 = null,
    jti: ?[]const u8 = null,
    roles: []const []const u8 = &.{},
};

pub const Key = struct {
    kid: []const u8,
    material: *const Security.SecretValue,
    epoch: u64,
    active_from_seconds: u64 = 0,
    expires_at_seconds: ?u64 = null,
};

const Replay = struct { expires_at_seconds: u64 };

/// Strict HS256 verifier for symmetric `oct` JWK deployments. Algorithm and
/// key id are pinned before signature verification, and accepted `jti` values
/// are retained until expiry to reject replay.
pub const Verifier = struct {
    allocator: std.mem.Allocator,
    issuer: []const u8,
    audience: ?[]const u8,
    keys: []const Key,
    maximum_lifetime_seconds: u64 = 24 * 60 * 60,
    clock_skew_seconds: u64 = 30,
    require_jti: bool = true,
    replay: std.StringHashMap(Replay),

    pub fn init(allocator: std.mem.Allocator, issuer: []const u8, audience: ?[]const u8, keys: []const Key) !Verifier {
        if (issuer.len == 0 or keys.len == 0) return error.InvalidJwtConfiguration;
        for (keys, 0..) |key, index| {
            if (key.kid.len == 0 or key.material.bytes.len < 32 or key.epoch == 0) return error.InvalidJwtConfiguration;
            for (keys[0..index]) |prior| if (std.mem.eql(u8, prior.kid, key.kid)) return error.DuplicateJwtKeyId;
        }
        return .{ .allocator = allocator, .issuer = issuer, .audience = audience, .keys = keys, .replay = .init(allocator) };
    }

    pub fn deinit(self: *Verifier) void {
        var iterator = self.replay.keyIterator();
        while (iterator.next()) |key| self.allocator.free(key.*);
        self.replay.deinit();
    }

    pub fn verifyJwtAlloc(self: *Verifier, allocator: std.mem.Allocator, token: []const u8, now_ms: u64) !Security.AuthContext {
        if (token.len == 0 or token.len > 64 * 1024) return error.InvalidJwt;
        const first = std.mem.indexOfScalar(u8, token, '.') orelse return error.InvalidJwt;
        const second = std.mem.indexOfScalarPos(u8, token, first + 1, '.') orelse return error.InvalidJwt;
        if (first == 0 or second == first + 1 or second + 1 == token.len or std.mem.indexOfScalarPos(u8, token, second + 1, '.') != null) return error.InvalidJwt;

        var header = try decodeJsonAlloc(Header, allocator, token[0..first]);
        defer header.deinit();
        if (!std.mem.eql(u8, header.value.alg, "HS256") or !std.mem.eql(u8, header.value.typ, "JWT")) return error.UnsupportedJwtAlgorithm;
        const now_seconds = now_ms / 1000;
        const key = self.findKey(header.value.kid, now_seconds) orelse return error.JwtKeyUnavailable;

        var supplied: [32]u8 = undefined;
        if (token.len - second - 1 != std.base64.url_safe_no_pad.Encoder.calcSize(supplied.len)) return error.InvalidJwt;
        std.base64.url_safe_no_pad.Decoder.decode(&supplied, token[second + 1 ..]) catch return error.InvalidJwt;
        defer @memset(&supplied, 0);
        var expected: [32]u8 = undefined;
        std.crypto.auth.hmac.sha2.HmacSha256.create(&expected, token[0..second], key.material.bytes);
        defer @memset(&expected, 0);
        if (!std.crypto.timing_safe.eql([32]u8, supplied, expected)) return error.InvalidJwtSignature;

        var claims = try decodeJsonAlloc(Claims, allocator, token[first + 1 .. second]);
        defer claims.deinit();
        try self.validateClaims(claims.value, now_seconds);
        try self.acceptReplay(claims.value, now_seconds);
        return cloneContext(allocator, claims.value, key.epoch, now_ms);
    }

    fn findKey(self: *const Verifier, kid: []const u8, now: u64) ?Key {
        for (self.keys) |key| if (std.mem.eql(u8, key.kid, kid) and now >= key.active_from_seconds and (key.expires_at_seconds == null or now < key.expires_at_seconds.?)) return key;
        return null;
    }

    fn validateClaims(self: *const Verifier, claims: Claims, now: u64) !void {
        if (claims.sub.len == 0 or claims.sub.len > 256 or !std.mem.eql(u8, claims.iss, self.issuer)) return error.InvalidJwtClaims;
        if (self.audience) |expected| if (claims.aud == null or !std.mem.eql(u8, claims.aud.?, expected)) return error.InvalidJwtAudience;
        if (claims.exp <= claims.iat or claims.exp - claims.iat > self.maximum_lifetime_seconds) return error.InvalidJwtLifetime;
        if (now +| self.clock_skew_seconds < claims.iat or now >= claims.exp +| self.clock_skew_seconds) return error.JwtExpired;
        if (claims.nbf) |not_before| if (now +| self.clock_skew_seconds < not_before) return error.JwtNotYetValid;
        if (claims.roles.len > 64) return error.TooManyRoles;
        if (self.require_jti and (claims.jti == null or claims.jti.?.len < 8 or claims.jti.?.len > 256)) return error.JwtIdRequired;
    }

    fn acceptReplay(self: *Verifier, claims: Claims, now: u64) !void {
        var iterator = self.replay.iterator();
        while (iterator.next()) |entry| if (entry.value_ptr.expires_at_seconds <= now) {
            const removed = self.replay.fetchRemove(entry.key_ptr.*).?;
            self.allocator.free(removed.key);
            iterator = self.replay.iterator();
        };
        const jti = claims.jti orelse return;
        if (self.replay.contains(jti)) return error.JwtReplayDetected;
        const owned = try self.allocator.dupe(u8, jti);
        errdefer self.allocator.free(owned);
        try self.replay.put(owned, .{ .expires_at_seconds = claims.exp +| self.clock_skew_seconds });
    }
};

pub fn signAlloc(allocator: std.mem.Allocator, header: Header, claims: Claims, key: []const u8) ![]u8 {
    if (key.len < 32 or !std.mem.eql(u8, header.alg, "HS256") or !std.mem.eql(u8, header.typ, "JWT")) return error.InvalidJwtConfiguration;
    const header_json = try std.json.Stringify.valueAlloc(allocator, header, .{});
    defer allocator.free(header_json);
    const claims_json = try std.json.Stringify.valueAlloc(allocator, claims, .{});
    defer allocator.free(claims_json);
    const Encoder = std.base64.url_safe_no_pad.Encoder;
    const header_len = Encoder.calcSize(header_json.len);
    const claims_len = Encoder.calcSize(claims_json.len);
    const signature_len = Encoder.calcSize(32);
    const token = try allocator.alloc(u8, header_len + 1 + claims_len + 1 + signature_len);
    errdefer allocator.free(token);
    _ = Encoder.encode(token[0..header_len], header_json);
    token[header_len] = '.';
    _ = Encoder.encode(token[header_len + 1 .. header_len + 1 + claims_len], claims_json);
    const second = header_len + 1 + claims_len;
    token[second] = '.';
    var signature: [32]u8 = undefined;
    std.crypto.auth.hmac.sha2.HmacSha256.create(&signature, token[0..second], key);
    defer @memset(&signature, 0);
    _ = Encoder.encode(token[second + 1 ..], &signature);
    return token;
}

fn decodeJsonAlloc(comptime T: type, allocator: std.mem.Allocator, encoded: []const u8) !std.json.Parsed(T) {
    const length = std.base64.url_safe_no_pad.Decoder.calcSizeForSlice(encoded) catch return error.InvalidJwt;
    if (length > 32 * 1024) return error.InvalidJwt;
    const decoded = try allocator.alloc(u8, length);
    defer {
        @memset(decoded, 0);
        allocator.free(decoded);
    }
    std.base64.url_safe_no_pad.Decoder.decode(decoded, encoded) catch return error.InvalidJwt;
    return std.json.parseFromSlice(T, allocator, decoded, .{ .allocate = .alloc_always, .ignore_unknown_fields = false }) catch error.InvalidJwt;
}

fn cloneContext(allocator: std.mem.Allocator, claims: Claims, epoch: u64, now_ms: u64) !Security.AuthContext {
    const subject = try allocator.dupe(u8, claims.sub);
    errdefer allocator.free(subject);
    const issuer = try allocator.dupe(u8, claims.iss);
    errdefer allocator.free(issuer);
    const roles = try allocator.alloc([]const u8, claims.roles.len);
    errdefer allocator.free(roles);
    var initialized: usize = 0;
    errdefer for (roles[0..initialized]) |role| allocator.free(role);
    for (claims.roles, 0..) |role, index| {
        roles[index] = try allocator.dupe(u8, role);
        initialized += 1;
    }
    return .{ .subject = subject, .issuer = issuer, .roles = roles, .authenticated_at_ms = now_ms, .expires_at_ms = claims.exp *| 1000, .credential_epoch = epoch, .allocator = allocator, .owns_fields = true };
}

test "strict HS256 JWK verifier handles replay expiry algorithm confusion and rotation" {
    var old_secret = try Security.SecretValue.initAlloc(std.testing.allocator, "0123456789abcdef0123456789abcdef");
    defer old_secret.deinit();
    var new_secret = try Security.SecretValue.initAlloc(std.testing.allocator, "abcdef0123456789abcdef0123456789");
    defer new_secret.deinit();
    const keys = [_]Key{
        .{ .kid = "old", .material = &old_secret, .epoch = 1, .expires_at_seconds = 120 },
        .{ .kid = "new", .material = &new_secret, .epoch = 2, .active_from_seconds = 100 },
    };
    var verifier = try Verifier.init(std.testing.allocator, "https://issuer.test", "orders", &keys);
    defer verifier.deinit();
    const claims = Claims{ .sub = "user-1", .iss = "https://issuer.test", .aud = "orders", .iat = 100, .exp = 160, .jti = "jwt-id-0001", .roles = &.{"writer"} };
    const token = try signAlloc(std.testing.allocator, .{ .kid = "new" }, claims, new_secret.bytes);
    defer std.testing.allocator.free(token);
    var context = try verifier.verifyJwtAlloc(std.testing.allocator, token, 110_000);
    defer context.deinit();
    try std.testing.expectEqual(@as(u64, 2), context.credential_epoch);
    try std.testing.expectError(error.JwtReplayDetected, verifier.verifyJwtAlloc(std.testing.allocator, token, 111_000));
    const wrong_alg = try signAlloc(std.testing.allocator, .{ .alg = "HS256", .kid = "new", .typ = "JWT" }, .{ .sub = "user-1", .iss = "https://issuer.test", .aud = "orders", .iat = 100, .exp = 160, .jti = "jwt-id-0002" }, new_secret.bytes);
    defer std.testing.allocator.free(wrong_alg);
    var tampered = try std.testing.allocator.dupe(u8, wrong_alg);
    defer std.testing.allocator.free(tampered);
    tampered[0] = if (tampered[0] == 'e') 'f' else 'e';
    try std.testing.expectError(error.InvalidJwt, verifier.verifyJwtAlloc(std.testing.allocator, tampered, 110_000));
    const expired_key_token = try signAlloc(std.testing.allocator, .{ .kid = "old" }, .{ .sub = "user-1", .iss = "https://issuer.test", .aud = "orders", .iat = 100, .exp = 160, .jti = "jwt-id-0003" }, old_secret.bytes);
    defer std.testing.allocator.free(expired_key_token);
    try std.testing.expectError(error.JwtKeyUnavailable, verifier.verifyJwtAlloc(std.testing.allocator, expired_key_token, 130_000));
}
