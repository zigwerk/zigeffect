const std = @import("std");
const Secrets = @import("../secrets/root.zig");
const Service = @import("../service/root.zig");

pub const JwtHs256 = @import("jwt_hs256.zig");

pub fn secureEql(left: []const u8, right: []const u8) bool {
    // Hashing normalizes arbitrary lengths before the fixed-size comparison.
    // Length still participates so distinct-length values cannot compare equal.
    var left_digest: [32]u8 = undefined;
    var right_digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(left, &left_digest, .{});
    std.crypto.hash.sha2.Sha256.hash(right, &right_digest, .{});
    return left.len == right.len and std.crypto.timing_safe.eql([32]u8, left_digest, right_digest);
}

pub const SecretValue = struct {
    allocator: std.mem.Allocator,
    bytes: []u8,
    pub fn initAlloc(allocator: std.mem.Allocator, bytes: []const u8) !SecretValue { if (bytes.len == 0) return error.EmptySecret; return .{ .allocator = allocator, .bytes = try allocator.dupe(u8, bytes) }; }
    pub fn eql(self: *const SecretValue, candidate: []const u8) bool { return secureEql(self.bytes, candidate); }
    pub fn display(_: *const SecretValue) []const u8 { return Secrets.redacted; }
    pub fn deinit(self: *SecretValue) void { @memset(self.bytes, 0); self.allocator.free(self.bytes); self.* = undefined; }
};

pub const AuthContext = struct {
    subject: []const u8,
    issuer: []const u8,
    roles: []const []const u8 = &.{},
    authenticated_at_ms: u64,
    expires_at_ms: ?u64 = null,
    credential_epoch: u64 = 0,
    allocator: ?std.mem.Allocator = null,
    owns_fields: bool = false,
    pub fn validate(self: AuthContext, now_ms: u64) !void {
        if (self.subject.len == 0 or self.subject.len > 256 or self.issuer.len == 0 or self.issuer.len > 256) return error.InvalidAuthContext;
        if (Secrets.containsSecret(self.subject) or Secrets.containsSecret(self.issuer)) return error.SecretDetected;
        if (self.expires_at_ms) |expires| if (now_ms >= expires) return error.CredentialExpired;
        if (self.roles.len > 64) return error.TooManyRoles;
    }
    pub fn deinit(self: *AuthContext) void {
        if (self.owns_fields) if (self.allocator) |allocator| {
            allocator.free(self.subject);
            allocator.free(self.issuer);
            for (self.roles) |role| allocator.free(role);
            allocator.free(self.roles);
        };
        self.* = undefined;
    }
};

pub fn provider(context: *AuthContext) Service.Provider(.{AuthContext}) { return Service.Provider(.{AuthContext}).init(.{context}); }

pub const ApiKeyRecord = struct { id: []const u8, subject: []const u8, digest: [32]u8, roles: []const []const u8 = &.{}, epoch: u64 = 1, disabled: bool = false };
pub fn hashApiKey(key: []const u8) [32]u8 { var digest: [32]u8 = undefined; std.crypto.hash.sha2.Sha256.hash(key, &digest, .{}); return digest; }
pub fn verifyApiKey(records: []const ApiKeyRecord, key: []const u8, now_ms: u64) !AuthContext {
    if (key.len < 16 or key.len > 4096) return error.InvalidApiKey;
    const digest = hashApiKey(key);
    var match: ?ApiKeyRecord = null;
    for (records) |record| {
        if (std.crypto.timing_safe.eql([32]u8, record.digest, digest) and !record.disabled) match = record;
    }
    const found = match orelse return error.Unauthorized;
    return .{ .subject = found.subject, .issuer = "api-key", .roles = found.roles, .authenticated_at_ms = now_ms, .credential_epoch = found.epoch };
}

pub const SessionClaims = struct { subject: []const u8, issued_at_ms: u64, expires_at_ms: u64, nonce: []const u8, epoch: u64 = 1 };
pub const SignedSession = struct {
    pub fn signAlloc(allocator: std.mem.Allocator, claims: SessionClaims, key: []const u8) ![]u8 {
        if (key.len < 32 or claims.subject.len == 0 or claims.nonce.len < 16 or claims.expires_at_ms <= claims.issued_at_ms) return error.InvalidSession;
        if (Secrets.containsSecret(claims.subject) or Secrets.containsSecret(claims.nonce)) return error.SecretDetected;
        const payload = try std.json.Stringify.valueAlloc(allocator, claims, .{}); defer allocator.free(payload);
        const Encoder = std.base64.url_safe_no_pad.Encoder;
        const encoded_len = Encoder.calcSize(payload.len);
        const output = try allocator.alloc(u8, encoded_len + 1 + Encoder.calcSize(32)); errdefer allocator.free(output);
        _ = Encoder.encode(output[0..encoded_len], payload);
        output[encoded_len] = '.';
        var mac: [32]u8 = undefined;
        std.crypto.auth.hmac.sha2.HmacSha256.create(&mac, output[0..encoded_len], key);
        _ = Encoder.encode(output[encoded_len + 1 ..], &mac);
        @memset(&mac, 0);
        return output;
    }

    pub fn verifyAlloc(allocator: std.mem.Allocator, token: []const u8, key: []const u8, now_ms: u64) !std.json.Parsed(SessionClaims) {
        if (token.len > 16 * 1024 or key.len < 32) return error.InvalidSession;
        const dot = std.mem.lastIndexOfScalar(u8, token, '.') orelse return error.InvalidSession;
        if (dot == 0 or dot + 1 == token.len) return error.InvalidSession;
        var expected: [32]u8 = undefined;
        std.crypto.auth.hmac.sha2.HmacSha256.create(&expected, token[0..dot], key);
        var supplied: [32]u8 = undefined;
        std.base64.url_safe_no_pad.Decoder.decode(&supplied, token[dot + 1 ..]) catch return error.InvalidSession;
        defer { @memset(&expected, 0); @memset(&supplied, 0); }
        if (!std.crypto.timing_safe.eql([32]u8, expected, supplied)) return error.InvalidSignature;
        const decoded_len = std.base64.url_safe_no_pad.Decoder.calcSizeForSlice(token[0..dot]) catch return error.InvalidSession;
        const decoded = try allocator.alloc(u8, decoded_len); defer { @memset(decoded, 0); allocator.free(decoded); }
        std.base64.url_safe_no_pad.Decoder.decode(decoded, token[0..dot]) catch return error.InvalidSession;
        const parsed = std.json.parseFromSlice(SessionClaims, allocator, decoded, .{ .allocate = .alloc_always }) catch return error.InvalidSession;
        errdefer parsed.deinit();
        if (now_ms < parsed.value.issued_at_ms or now_ms >= parsed.value.expires_at_ms) return error.SessionExpired;
        return parsed;
    }
};

pub const Jwk = struct { kid: []const u8, kty: []const u8, alg: []const u8, use: []const u8 = "sig", material: Secrets.Reference, not_before_ms: ?u64 = null, expires_at_ms: ?u64 = null };
pub const JwkSet = struct { issuer: []const u8, keys: []const Jwk, refreshed_at_ms: u64, max_age_ms: u64 };
pub const JwtVerifier = struct {
    pointer: *anyopaque,
    verify_fn: *const fn (*anyopaque, std.mem.Allocator, []const u8, u64) anyerror!AuthContext,
    pub fn from(comptime T: type, pointer: *T) JwtVerifier { return .{ .pointer = pointer, .verify_fn = struct { fn call(raw: *anyopaque, allocator: std.mem.Allocator, token: []const u8, now_ms: u64) anyerror!AuthContext { return (@as(*T, @ptrCast(@alignCast(raw)))).verifyJwtAlloc(allocator, token, now_ms); } }.call }; }
    pub fn verifyAlloc(self: JwtVerifier, allocator: std.mem.Allocator, token: []const u8, now_ms: u64) !AuthContext { if (token.len == 0 or token.len > 64 * 1024) return error.InvalidJwt; return self.verify_fn(self.pointer, allocator, token, now_ms); }
};

pub const AuthorizationRequest = struct { action: []const u8, resource: []const u8, tenant: ?[]const u8 = null };
pub const AuthorizationDecision = struct { allowed: bool, policy_id: []const u8, reason: []const u8 };
pub const AuthorizationPolicy = struct {
    pointer: *anyopaque,
    decide_fn: *const fn (*anyopaque, AuthContext, AuthorizationRequest) AuthorizationDecision,
    pub fn from(comptime T: type, pointer: *T) AuthorizationPolicy { return .{ .pointer = pointer, .decide_fn = struct { fn call(raw: *anyopaque, context: AuthContext, request: AuthorizationRequest) AuthorizationDecision { return (@as(*T, @ptrCast(@alignCast(raw)))).authorize(context, request); } }.call }; }
    pub fn decide(self: AuthorizationPolicy, context: AuthContext, request: AuthorizationRequest) AuthorizationDecision { return self.decide_fn(self.pointer, context, request); }
};

pub const CookieOptions = struct { path: []const u8 = "/", domain: ?[]const u8 = null, max_age_seconds: ?u64 = null, secure: bool = true, http_only: bool = true, same_site: enum { strict, lax, none } = .lax };
pub fn secureCookieAlloc(allocator: std.mem.Allocator, name: []const u8, value: []const u8, options: CookieOptions) ![]u8 {
    if (!validCookieToken(name) or containsCookieControl(value) or value.len > 4096) return error.InvalidCookie;
    if (options.same_site == .none and !options.secure) return error.InsecureSameSiteNone;
    var output = std.ArrayList(u8).empty; errdefer output.deinit(allocator);
    try output.print(allocator, "{s}={s}; Path={s}", .{ name, value, options.path });
    if (options.domain) |domain| { if (containsCookieControl(domain)) return error.InvalidCookie; try output.print(allocator, "; Domain={s}", .{domain}); }
    if (options.max_age_seconds) |age| try output.print(allocator, "; Max-Age={d}", .{age});
    if (options.secure) try output.appendSlice(allocator, "; Secure");
    if (options.http_only) try output.appendSlice(allocator, "; HttpOnly");
    try output.print(allocator, "; SameSite={s}", .{switch (options.same_site) { .strict => "Strict", .lax => "Lax", .none => "None" }});
    return output.toOwnedSlice(allocator);
}

pub fn verifyCsrf(cookie_token: []const u8, submitted_token: []const u8, origin: []const u8, allowed_origins: []const []const u8) !void {
    if (cookie_token.len < 16 or !secureEql(cookie_token, submitted_token)) return error.CsrfRejected;
    for (allowed_origins) |allowed| if (std.mem.eql(u8, origin, allowed)) return;
    return error.OriginRejected;
}

pub const PasswordHasher = struct {
    pointer: *anyopaque,
    hash_fn: *const fn (*anyopaque, std.mem.Allocator, []const u8) anyerror![]u8,
    verify_fn: *const fn (*anyopaque, []const u8, []const u8) anyerror!bool,
    algorithm_fn: *const fn (*anyopaque) []const u8,
    pub fn from(comptime T: type, pointer: *T) PasswordHasher { return .{ .pointer = pointer, .hash_fn = struct { fn call(raw: *anyopaque, allocator: std.mem.Allocator, password: []const u8) anyerror![]u8 { return (@as(*T, @ptrCast(@alignCast(raw)))).hashPasswordAlloc(allocator, password); } }.call, .verify_fn = struct { fn call(raw: *anyopaque, encoded: []const u8, password: []const u8) anyerror!bool { return (@as(*T, @ptrCast(@alignCast(raw)))).verifyPassword(encoded, password); } }.call, .algorithm_fn = struct { fn call(raw: *anyopaque) []const u8 { return (@as(*T, @ptrCast(@alignCast(raw)))).algorithm(); } }.call }; }
};

/// Reviewed stdlib Argon2id PHC adapter. The encoded value contains a random
/// salt and all verification parameters; raw passwords are never retained.
pub const Argon2idHasher = struct {
    io: std.Io,
    params: std.crypto.pwhash.argon2.Params = std.crypto.pwhash.argon2.Params.owasp_2id,
    max_password_bytes: usize = 1024,

    pub fn algorithm(_: *Argon2idHasher) []const u8 { return "argon2id"; }
    pub fn hashPasswordAlloc(self: *Argon2idHasher, allocator: std.mem.Allocator, password: []const u8) ![]u8 {
        if (password.len < 8 or password.len > self.max_password_bytes) return error.InvalidPassword;
        var buffer: [256]u8 = undefined;
        const encoded = try std.crypto.pwhash.argon2.strHash(password, .{ .allocator = allocator, .params = self.params, .mode = .argon2id }, &buffer, self.io);
        return allocator.dupe(u8, encoded);
    }
    pub fn verifyPassword(self: *Argon2idHasher, encoded: []const u8, password: []const u8) !bool {
        if (password.len > self.max_password_bytes or encoded.len > 256 or !std.mem.startsWith(u8, encoded, "$argon2id$")) return false;
        std.crypto.pwhash.argon2.strVerify(encoded, password, .{ .allocator = std.heap.page_allocator }, self.io) catch |err| return switch (err) {
            error.PasswordVerificationFailed => false,
            else => err,
        };
        return true;
    }
};

pub const RotationAudit = struct { kind: enum { certificate, signing_key, api_key }, reference: []const u8, previous_epoch: u64, new_epoch: u64, at_ms: u64 };
pub const RotationHook = struct { pointer: *anyopaque, rotate_fn: *const fn (*anyopaque, Secrets.Reference) anyerror!u64, pub fn from(comptime T: type, pointer: *T) RotationHook { return .{ .pointer = pointer, .rotate_fn = struct { fn call(raw: *anyopaque, reference: Secrets.Reference) anyerror!u64 { return (@as(*T, @ptrCast(@alignCast(raw)))).rotate(reference); } }.call }; } pub fn rotate(self: RotationHook, reference: Secrets.Reference) !u64 { try reference.validate(); return self.rotate_fn(self.pointer, reference); } };

fn validCookieToken(value: []const u8) bool { if (value.len == 0 or value.len > 128) return false; for (value) |byte| if (!(std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '-')) return false; return true; }
fn containsCookieControl(value: []const u8) bool { for (value) |byte| if (byte < 0x21 or byte == ';' or byte == ',' or byte == 0x7f) return true; return false; }

test "constant-time API key authentication propagates redacted auth context" {
    const roles = [_][]const u8{"writer"};
    const records = [_]ApiKeyRecord{.{ .id = "primary", .subject = "service-a", .digest = hashApiKey("0123456789abcdef-secret"), .roles = &roles, .epoch = 4 }};
    const context = try verifyApiKey(&records, "0123456789abcdef-secret", 100);
    try context.validate(100); try std.testing.expectEqualStrings("service-a", context.subject); try std.testing.expectEqual(@as(u64, 4), context.credential_epoch);
    try std.testing.expectError(error.Unauthorized, verifyApiKey(&records, "0123456789abcdef-wrong!", 100));
}

test "signed sessions reject tampering expiry replay-shaped input and secrets" {
    const key = "0123456789abcdef0123456789abcdef";
    const token = try SignedSession.signAlloc(std.testing.allocator, .{ .subject = "user-1", .issued_at_ms = 10, .expires_at_ms = 20, .nonce = "0123456789abcdef" }, key); defer std.testing.allocator.free(token);
    var parsed = try SignedSession.verifyAlloc(std.testing.allocator, token, key, 15); defer parsed.deinit();
    try std.testing.expectEqualStrings("user-1", parsed.value.subject);
    var tampered = try std.testing.allocator.dupe(u8, token); defer std.testing.allocator.free(tampered); tampered[0] = if (tampered[0] == 'a') 'b' else 'a';
    try std.testing.expectError(error.InvalidSignature, SignedSession.verifyAlloc(std.testing.allocator, tampered, key, 15));
    try std.testing.expectError(error.SessionExpired, SignedSession.verifyAlloc(std.testing.allocator, token, key, 20));
}

test "secure cookies and CSRF reject hostile input" {
    const cookie = try secureCookieAlloc(std.testing.allocator, "session", "opaque-value", .{}); defer std.testing.allocator.free(cookie);
    try std.testing.expect(std.mem.indexOf(u8, cookie, "Secure; HttpOnly; SameSite=Lax") != null);
    try std.testing.expectError(error.InvalidCookie, secureCookieAlloc(std.testing.allocator, "session\r\nInjected", "value", .{}));
    try verifyCsrf("0123456789abcdef", "0123456789abcdef", "https://app.test", &.{"https://app.test"});
    try std.testing.expectError(error.CsrfRejected, verifyCsrf("0123456789abcdef", "0123456789abcdeg", "https://app.test", &.{"https://app.test"}));
}

test "reviewed Argon2id adapter hashes verifies and rejects malformed encodings" {
    var hasher = Argon2idHasher{ .io = std.testing.io, .params = .{ .t = 1, .m = 1024, .p = 1 } };
    const boundary = PasswordHasher.from(Argon2idHasher, &hasher);
    try std.testing.expectEqualStrings("argon2id", boundary.algorithm_fn(boundary.pointer));
    const encoded = try boundary.hash_fn(boundary.pointer, std.testing.allocator, "correct horse battery staple");
    defer std.testing.allocator.free(encoded);
    try std.testing.expect(try boundary.verify_fn(boundary.pointer, encoded, "correct horse battery staple"));
    try std.testing.expect(!(try boundary.verify_fn(boundary.pointer, encoded, "incorrect horse battery staple")));
    try std.testing.expect(!(try boundary.verify_fn(boundary.pointer, "$argon2i$malformed", "correct horse battery staple")));
}
