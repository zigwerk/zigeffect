const std = @import("std");

pub const issuer = "https://cloud.google.com/iap";
pub const jwks_url = "https://www.gstatic.com/iap/verify/public_key-jwk";

const Scheme = std.crypto.sign.ecdsa.EcdsaP256Sha256;

const Key = struct {
    const Material = union(enum) {
        es256: struct { x: [32]u8, y: [32]u8 },
        rs256: struct { modulus: []u8, exponent: []u8 },
    };

    kid: []u8,
    material: Material,
};

const JwkDocument = struct {
    keys: []const struct {
        kty: []const u8,
        crv: ?[]const u8 = null,
        alg: []const u8,
        use: ?[]const u8 = null,
        kid: []const u8,
        x: ?[]const u8 = null,
        y: ?[]const u8 = null,
        n: ?[]const u8 = null,
        e: ?[]const u8 = null,
    },
};

const JwtHeader = struct {
    alg: []const u8,
    kid: []const u8,
    typ: ?[]const u8 = null,
};

const JwtClaims = struct {
    iss: []const u8,
    aud: []const u8,
    sub: []const u8,
    email: ?[]const u8 = null,
    iat: u64,
    exp: u64,
    hd: ?[]const u8 = null,
};

pub const Identity = struct {
    allocator: std.mem.Allocator,
    subject: []u8,
    email: []u8,
    hosted_domain: ?[]u8,

    pub fn deinit(self: *Identity) void {
        self.allocator.free(self.subject);
        self.allocator.free(self.email);
        if (self.hosted_domain) |value| self.allocator.free(value);
        self.* = undefined;
    }
};

pub const JwksSource = struct {
    pointer: *anyopaque,
    fetch_fn: *const fn (*anyopaque, std.mem.Allocator) anyerror![]u8,

    pub fn from(comptime Target: type, target: *Target) JwksSource {
        return .{
            .pointer = target,
            .fetch_fn = struct {
                fn fetch(pointer: *anyopaque, allocator: std.mem.Allocator) anyerror![]u8 {
                    return (@as(*Target, @ptrCast(@alignCast(pointer)))).fetchJwksAlloc(allocator);
                }
            }.fetch,
        };
    }
};

pub const Options = struct {
    audience: []const u8,
    expected_issuer: []const u8 = issuer,
    algorithm: Algorithm = .es256,
    require_email: bool = true,
    clock_skew_seconds: u64 = 60,
    maximum_lifetime_seconds: u64 = 3600,
    refresh_interval_millis: u64 = 15 * 60 * 1000,
    source: ?JwksSource = null,

    pub fn validate(self: Options) !void {
        if (self.audience.len == 0 or self.audience.len > 2048 or self.expected_issuer.len == 0 or self.expected_issuer.len > 2048 or self.maximum_lifetime_seconds == 0 or self.refresh_interval_millis == 0) return error.InvalidIapConfiguration;
    }
};

pub const Algorithm = enum {
    es256,
    rs256,

    pub fn jwtName(self: Algorithm) []const u8 {
        return switch (self) {
            .es256 => "ES256",
            .rs256 => "RS256",
        };
    }
};

/// Strict ES256/RS256 OIDC verifier. IAP uses the ES256 profile; generic OIDC
/// deployments can select either allowlisted algorithm. Key documents can be
/// replaced atomically, and an optional source refreshes the cache before
/// verification when its bounded TTL expires.
pub const Verifier = struct {
    allocator: std.mem.Allocator,
    audience: []u8,
    expected_issuer: []u8,
    options: Options,
    keys: []Key,
    mutex: std.atomic.Mutex = .unlocked,
    generation: std.atomic.Value(u64) = .init(1),
    refreshed_at_millis: std.atomic.Value(u64),

    pub fn initAlloc(allocator: std.mem.Allocator, jwks_json: []const u8, options: Options, now_millis: u64) !Verifier {
        try options.validate();
        const audience = try allocator.dupe(u8, options.audience);
        errdefer allocator.free(audience);
        const expected_issuer = try allocator.dupe(u8, options.expected_issuer);
        errdefer allocator.free(expected_issuer);
        const keys = try parseKeysAlloc(allocator, jwks_json, options.algorithm);
        return .{
            .allocator = allocator,
            .audience = audience,
            .expected_issuer = expected_issuer,
            .options = options,
            .keys = keys,
            .refreshed_at_millis = .init(now_millis),
        };
    }

    pub fn deinit(self: *Verifier) void {
        self.lock();
        freeKeys(self.allocator, self.keys);
        self.allocator.free(self.audience);
        self.allocator.free(self.expected_issuer);
        self.mutex.unlock();
        self.* = undefined;
    }

    pub fn replaceJwksAlloc(self: *Verifier, jwks_json: []const u8, now_millis: u64) !u64 {
        const replacement = try parseKeysAlloc(self.allocator, jwks_json, self.options.algorithm);
        self.lock();
        const previous = self.keys;
        self.keys = replacement;
        self.refreshed_at_millis.store(now_millis, .release);
        const next = self.generation.fetchAdd(1, .acq_rel) + 1;
        self.mutex.unlock();
        freeKeys(self.allocator, previous);
        return next;
    }

    pub fn keyGeneration(self: *const Verifier) u64 {
        return self.generation.load(.acquire);
    }

    pub fn verifyAlloc(self: *Verifier, allocator: std.mem.Allocator, token: []const u8, now_millis: u64) !Identity {
        if (token.len == 0 or token.len > 64 * 1024) return error.InvalidIapJwt;
        try self.refreshIfStale(now_millis);
        const first = std.mem.indexOfScalar(u8, token, '.') orelse return error.InvalidIapJwt;
        const second = std.mem.indexOfScalarPos(u8, token, first + 1, '.') orelse return error.InvalidIapJwt;
        if (first == 0 or second == first + 1 or second + 1 == token.len or std.mem.indexOfScalarPos(u8, token, second + 1, '.') != null) return error.InvalidIapJwt;

        var header = try decodeJsonAlloc(JwtHeader, allocator, token[0..first]);
        defer header.deinit();
        if (!std.mem.eql(u8, header.value.alg, self.options.algorithm.jwtName())) return error.UnsupportedIapAlgorithm;
        if (header.value.typ) |typ| if (!std.ascii.eqlIgnoreCase(typ, "JWT")) return error.InvalidIapJwt;
        var claims = try decodeJsonAlloc(JwtClaims, allocator, token[first + 1 .. second]);
        defer claims.deinit();

        self.lock();
        defer self.mutex.unlock();
        const key = self.findKey(header.value.kid) orelse return error.IapKeyUnavailable;
        switch (key.material) {
            .es256 => |material| {
                var signature_bytes: [64]u8 = undefined;
                try decodeExact(token[second + 1 ..], &signature_bytes);
                var sec1: [65]u8 = undefined;
                sec1[0] = 4;
                @memcpy(sec1[1..33], &material.x);
                @memcpy(sec1[33..65], &material.y);
                const public_key = Scheme.PublicKey.fromSec1(&sec1) catch return error.InvalidIapKey;
                const signature = Scheme.Signature.fromBytes(signature_bytes);
                signature.verify(token[0..second], public_key) catch return error.InvalidIapSignature;
            },
            .rs256 => |material| try verifyRs256(token[0..second], token[second + 1 ..], material.modulus, material.exponent),
        }

        const now_seconds = now_millis / 1000;
        if (!std.mem.eql(u8, claims.value.iss, self.expected_issuer) or !std.mem.eql(u8, claims.value.aud, self.audience)) return error.InvalidIapClaims;
        if (claims.value.sub.len == 0 or claims.value.sub.len > 256) return error.InvalidIapClaims;
        if (claims.value.email) |email_value| {
            if (email_value.len == 0 or email_value.len > 512) return error.InvalidIapClaims;
        } else if (self.options.require_email) return error.InvalidIapClaims;
        if (claims.value.exp <= claims.value.iat or claims.value.exp - claims.value.iat > self.options.maximum_lifetime_seconds) return error.InvalidIapLifetime;
        if (now_seconds +| self.options.clock_skew_seconds < claims.value.iat or now_seconds >= claims.value.exp +| self.options.clock_skew_seconds) return error.IapJwtExpired;

        const subject = try allocator.dupe(u8, claims.value.sub);
        errdefer allocator.free(subject);
        const email = try allocator.dupe(u8, claims.value.email orelse "");
        errdefer allocator.free(email);
        const hosted_domain = if (claims.value.hd) |value| try allocator.dupe(u8, value) else null;
        return .{ .allocator = allocator, .subject = subject, .email = email, .hosted_domain = hosted_domain };
    }

    fn refreshIfStale(self: *Verifier, now_millis: u64) !void {
        const source = self.options.source orelse return;
        const refreshed = self.refreshed_at_millis.load(.acquire);
        if (now_millis < refreshed or now_millis - refreshed < self.options.refresh_interval_millis) return;
        const json = try source.fetch_fn(source.pointer, self.allocator);
        defer self.allocator.free(json);
        _ = try self.replaceJwksAlloc(json, now_millis);
    }

    fn findKey(self: *const Verifier, kid: []const u8) ?*const Key {
        for (self.keys) |*key| if (std.mem.eql(u8, key.kid, kid)) return key;
        return null;
    }

    fn lock(self: *Verifier) void {
        while (!self.mutex.tryLock()) std.Thread.yield() catch {};
    }
};

fn parseKeysAlloc(allocator: std.mem.Allocator, json: []const u8, algorithm: Algorithm) ![]Key {
    var document = std.json.parseFromSlice(JwkDocument, allocator, json, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch return error.InvalidIapJwks;
    defer document.deinit();
    if (document.value.keys.len == 0 or document.value.keys.len > 32) return error.InvalidIapJwks;
    var output = try allocator.alloc(Key, document.value.keys.len);
    errdefer allocator.free(output);
    var initialized: usize = 0;
    errdefer for (output[0..initialized]) |*key| freeKey(allocator, key);
    for (document.value.keys) |source| {
        // OIDC providers commonly publish keys for several algorithms in one
        // document. Ignore keys outside the configured allowlist rather than
        // making safe rotation through a mixed JWKS impossible.
        if (!std.mem.eql(u8, source.alg, algorithm.jwtName())) continue;
        if (source.use) |use| if (!std.mem.eql(u8, use, "sig")) return error.InvalidIapJwks;
        if (source.kid.len == 0 or source.kid.len > 256) return error.InvalidIapJwks;
        for (output[0..initialized]) |previous| if (std.mem.eql(u8, previous.kid, source.kid)) return error.DuplicateIapKey;
        const kid = try allocator.dupe(u8, source.kid);
        errdefer allocator.free(kid);
        const material: Key.Material = switch (algorithm) {
            .es256 => blk: {
                if (!std.mem.eql(u8, source.kty, "EC") or !std.mem.eql(u8, source.crv orelse "", "P-256")) return error.InvalidIapJwks;
                var value: Key.Material = .{ .es256 = .{ .x = undefined, .y = undefined } };
                try decodeExact(source.x orelse return error.InvalidIapJwks, &value.es256.x);
                try decodeExact(source.y orelse return error.InvalidIapJwks, &value.es256.y);
                break :blk value;
            },
            .rs256 => blk: {
                if (!std.mem.eql(u8, source.kty, "RSA")) return error.InvalidIapJwks;
                const modulus = try decodeBase64UrlAlloc(allocator, source.n orelse return error.InvalidIapJwks, 256, 512);
                errdefer allocator.free(modulus);
                const exponent = try decodeBase64UrlAlloc(allocator, source.e orelse return error.InvalidIapJwks, 1, 4);
                errdefer allocator.free(exponent);
                break :blk .{ .rs256 = .{ .modulus = modulus, .exponent = exponent } };
            },
        };
        output[initialized] = .{ .kid = kid, .material = material };
        initialized += 1;
    }
    if (initialized == 0) return error.InvalidIapJwks;
    output = try allocator.realloc(output, initialized);
    return output;
}

fn freeKeys(allocator: std.mem.Allocator, keys: []Key) void {
    for (keys) |*key| freeKey(allocator, key);
    allocator.free(keys);
}

fn freeKey(allocator: std.mem.Allocator, key: *Key) void {
    allocator.free(key.kid);
    switch (key.material) {
        .es256 => {},
        .rs256 => |material| {
            allocator.free(material.modulus);
            allocator.free(material.exponent);
        },
    }
}

fn verifyRs256(signing_input: []const u8, encoded_signature: []const u8, modulus: []const u8, exponent: []const u8) !void {
    const signature = try decodeBase64UrlAlloc(std.heap.page_allocator, encoded_signature, modulus.len, modulus.len);
    defer std.heap.page_allocator.free(signature);
    if (signature.len != modulus.len) return error.InvalidIapSignature;
    const public_key = std.crypto.Certificate.rsa.PublicKey.fromBytes(exponent, modulus) catch return error.InvalidIapKey;
    const Signature = std.crypto.Certificate.rsa.PKCS1v1_5Signature;
    const Sha256 = std.crypto.hash.sha2.Sha256;
    switch (modulus.len) {
        256 => Signature.verify(256, Signature.fromBytes(256, signature), signing_input, public_key, Sha256) catch return error.InvalidIapSignature,
        384 => Signature.verify(384, Signature.fromBytes(384, signature), signing_input, public_key, Sha256) catch return error.InvalidIapSignature,
        512 => Signature.verify(512, Signature.fromBytes(512, signature), signing_input, public_key, Sha256) catch return error.InvalidIapSignature,
        else => return error.InvalidIapKey,
    }
}

fn decodeBase64UrlAlloc(allocator: std.mem.Allocator, encoded: []const u8, minimum: usize, maximum: usize) ![]u8 {
    const Decoder = if (std.mem.endsWith(u8, encoded, "=")) std.base64.url_safe.Decoder else std.base64.url_safe_no_pad.Decoder;
    const length = Decoder.calcSizeForSlice(encoded) catch return error.InvalidIapBase64;
    if (length < minimum or length > maximum) return error.InvalidIapBase64;
    const output = try allocator.alloc(u8, length);
    errdefer allocator.free(output);
    Decoder.decode(output, encoded) catch return error.InvalidIapBase64;
    return output;
}

fn decodeExact(encoded: []const u8, output: []u8) !void {
    const Decoder = if (std.mem.endsWith(u8, encoded, "=")) std.base64.url_safe.Decoder else std.base64.url_safe_no_pad.Decoder;
    const length = Decoder.calcSizeForSlice(encoded) catch return error.InvalidIapBase64;
    if (length != output.len) return error.InvalidIapBase64;
    Decoder.decode(output, encoded) catch return error.InvalidIapBase64;
}

fn decodeJsonAlloc(comptime T: type, allocator: std.mem.Allocator, encoded: []const u8) !std.json.Parsed(T) {
    const length = std.base64.url_safe_no_pad.Decoder.calcSizeForSlice(encoded) catch return error.InvalidIapJwt;
    if (length == 0 or length > 32 * 1024) return error.InvalidIapJwt;
    const decoded = try allocator.alloc(u8, length);
    defer allocator.free(decoded);
    std.base64.url_safe_no_pad.Decoder.decode(decoded, encoded) catch return error.InvalidIapJwt;
    return std.json.parseFromSlice(T, allocator, decoded, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch error.InvalidIapJwt;
}

test "IAP ES256 verifier validates claims and rotates cached JWKs" {
    const first_key = Scheme.KeyPair.generate(std.testing.io);
    const second_key = Scheme.KeyPair.generate(std.testing.io);
    const first_jwks = try jwksForTestAlloc(std.testing.allocator, "first", first_key.public_key);
    defer std.testing.allocator.free(first_jwks);
    var verifier = try Verifier.initAlloc(std.testing.allocator, first_jwks, .{ .audience = "/projects/123/global/backendServices/456" }, 100_000);
    defer verifier.deinit();
    const token = try tokenForTestAlloc(std.testing.allocator, "first", first_key, 100, 160);
    defer std.testing.allocator.free(token);
    var identity = try verifier.verifyAlloc(std.testing.allocator, token, 110_000);
    defer identity.deinit();
    try std.testing.expectEqualStrings("user-1", identity.subject);
    try std.testing.expectEqualStrings("user@example.com", identity.email);

    const second_jwks = try jwksForTestAlloc(std.testing.allocator, "second", second_key.public_key);
    defer std.testing.allocator.free(second_jwks);
    try std.testing.expectEqual(@as(u64, 2), try verifier.replaceJwksAlloc(second_jwks, 120_000));
    try std.testing.expectError(error.IapKeyUnavailable, verifier.verifyAlloc(std.testing.allocator, token, 121_000));
    const rotated = try tokenForTestAlloc(std.testing.allocator, "second", second_key, 120, 180);
    defer std.testing.allocator.free(rotated);
    var rotated_identity = try verifier.verifyAlloc(std.testing.allocator, rotated, 130_000);
    rotated_identity.deinit();
}

test "generic OIDC ES256 profile validates configurable issuer audience and optional email" {
    const key = Scheme.KeyPair.generate(std.testing.io);
    const jwks = try jwksForTestAlloc(std.testing.allocator, "oidc", key.public_key);
    defer std.testing.allocator.free(jwks);
    var verifier = try Verifier.initAlloc(std.testing.allocator, jwks, .{
        .audience = "orders-api",
        .expected_issuer = "https://issuer.example",
        .require_email = false,
    }, 100_000);
    defer verifier.deinit();
    const token = try tokenForClaimsTestAlloc(std.testing.allocator, "oidc", key, .{
        .issuer = "https://issuer.example",
        .audience = "orders-api",
        .subject = "service-account-1",
        .issued_at = 100,
        .expires_at = 160,
    });
    defer std.testing.allocator.free(token);
    var identity = try verifier.verifyAlloc(std.testing.allocator, token, 110_000);
    defer identity.deinit();
    try std.testing.expectEqualStrings("service-account-1", identity.subject);
    try std.testing.expectEqualStrings("", identity.email);
}

test "generic OIDC RS256 profile verifies a bounded 2048-bit JWK" {
    const jwks =
        \\{"keys":[{"kty":"RSA","alg":"RS256","use":"sig","kid":"rsa-test","n":"obzJALUATS0W7qgifINMmmMF2xc6bSI7mvog3dpSRWqEUjUuac3MAWsMWg6W-7XurmvpDRg87kXZvrVLUcU5f9TNsomQIQg9mrShnpGgGI75MpcsThocoJMtbl4r3Cs-VHabUhUsIQcK8oHurek1_KbbJr1D2_e1XmkVLahcKKh_6-NFm65P_MB7YN6p6j01TZCItiQfhwzMdg0hYllh9Uus9rJMGZ2Qh1D6up6-FVnPAACHtPUdD4CknmuS7eD-C8R-r-kUxBu2oLscks5u84yYqjxHLd44n1NyfAZEaHFwHyiAnKb13VBsaNXORP55uA2FgtO_OPYU9q7jhDjmQQ","e":"AQAB"}]}
    ;
    const token = "eyJhbGciOiJSUzI1NiIsImtpZCI6InJzYS10ZXN0IiwidHlwIjoiSldUIn0.eyJpc3MiOiJodHRwczovL2lzc3Vlci5leGFtcGxlIiwiYXVkIjoib3JkZXJzLWFwaSIsInN1YiI6InNlcnZpY2UtcnNhIiwiaWF0IjoxMDAsImV4cCI6MTYwfQ.n_wCYX-waYwCkgfr8tHVI8NFDeMgQJlYWMG673dQnAh7FeIit0bZsGp6rn22KZwEorv6uj8WZU5MZDtDWUFZe_cM8Va6DKOK2nCqxN0yQx8Vwn-kcSNnSjzfi55hst7rk28tSs7B67p4n7Oq4ZcA7nvpw2CU2ojkiHtWXpBKibZgYt9iopC14oIJRR-LN6TxRhpxOpiVsaJDDSD9gtYutRJczBcDbkILJch8rwI5sDYip4Nell-agsXmK2AAU6d-uFXdkGLzq3ldKTjFnVFGVSWAAwEgFhzShGyiqPQyAS3Z22tXB38xrzS2dfljQFyd3DLzmFRBtGKSkkXNKD_xNw";
    var verifier = try Verifier.initAlloc(std.testing.allocator, jwks, .{
        .audience = "orders-api",
        .expected_issuer = "https://issuer.example",
        .algorithm = .rs256,
        .require_email = false,
    }, 100_000);
    defer verifier.deinit();
    var identity = try verifier.verifyAlloc(std.testing.allocator, token, 110_000);
    defer identity.deinit();
    try std.testing.expectEqualStrings("service-rsa", identity.subject);

    var tampered = try std.testing.allocator.dupe(u8, token);
    defer std.testing.allocator.free(tampered);
    tampered[tampered.len - 1] = if (tampered[tampered.len - 1] == 'A') 'B' else 'A';
    try std.testing.expectError(error.InvalidIapSignature, verifier.verifyAlloc(std.testing.allocator, tampered, 110_000));
}

fn jwksForTestAlloc(allocator: std.mem.Allocator, kid: []const u8, public_key: Scheme.PublicKey) ![]u8 {
    const sec1 = public_key.toUncompressedSec1();
    var x: [std.base64.url_safe_no_pad.Encoder.calcSize(32)]u8 = undefined;
    var y: [std.base64.url_safe_no_pad.Encoder.calcSize(32)]u8 = undefined;
    _ = std.base64.url_safe_no_pad.Encoder.encode(&x, sec1[1..33]);
    _ = std.base64.url_safe_no_pad.Encoder.encode(&y, sec1[33..65]);
    return std.fmt.allocPrint(allocator, "{{\"keys\":[{{\"kty\":\"EC\",\"crv\":\"P-256\",\"alg\":\"ES256\",\"use\":\"sig\",\"kid\":\"{s}\",\"x\":\"{s}\",\"y\":\"{s}\"}}]}}", .{ kid, &x, &y });
}

fn tokenForTestAlloc(allocator: std.mem.Allocator, kid: []const u8, key_pair: Scheme.KeyPair, issued_at: u64, expires_at: u64) ![]u8 {
    return tokenForClaimsTestAlloc(allocator, kid, key_pair, .{
        .issuer = issuer,
        .audience = "/projects/123/global/backendServices/456",
        .subject = "user-1",
        .email = "user@example.com",
        .issued_at = issued_at,
        .expires_at = expires_at,
    });
}

const TestTokenClaims = struct {
    issuer: []const u8,
    audience: []const u8,
    subject: []const u8,
    email: ?[]const u8 = null,
    issued_at: u64,
    expires_at: u64,
};

fn tokenForClaimsTestAlloc(allocator: std.mem.Allocator, kid: []const u8, key_pair: Scheme.KeyPair, options: TestTokenClaims) ![]u8 {
    const header = try std.fmt.allocPrint(allocator, "{{\"alg\":\"ES256\",\"kid\":\"{s}\",\"typ\":\"JWT\"}}", .{kid});
    defer allocator.free(header);
    const claims = try std.json.Stringify.valueAlloc(allocator, .{
        .iss = options.issuer,
        .aud = options.audience,
        .sub = options.subject,
        .email = options.email,
        .iat = options.issued_at,
        .exp = options.expires_at,
    }, .{ .emit_null_optional_fields = false });
    defer allocator.free(claims);
    const encoded_header = try encodeBase64UrlAlloc(allocator, header);
    defer allocator.free(encoded_header);
    const encoded_claims = try encodeBase64UrlAlloc(allocator, claims);
    defer allocator.free(encoded_claims);
    const signing_input = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ encoded_header, encoded_claims });
    defer allocator.free(signing_input);
    const signature = try key_pair.sign(signing_input, null);
    const signature_bytes = signature.toBytes();
    const encoded_signature = try encodeBase64UrlAlloc(allocator, &signature_bytes);
    defer allocator.free(encoded_signature);
    return std.fmt.allocPrint(allocator, "{s}.{s}", .{ signing_input, encoded_signature });
}

fn encodeBase64UrlAlloc(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    const output = try allocator.alloc(u8, std.base64.url_safe_no_pad.Encoder.calcSize(bytes.len));
    _ = std.base64.url_safe_no_pad.Encoder.encode(output, bytes);
    return output;
}
