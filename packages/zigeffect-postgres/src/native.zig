const std = @import("std");
const pg = @import("pg");
const zstd = @import("zigeffect_std");

pub const Error = error{
    InvalidPoolSize,
    InvalidTimeout,
    InvalidLifetime,
    InvalidJitter,
    InvalidUri,
    VerifiedTlsRequired,
};

pub const Outcome = enum { definite, ambiguous, connection };

pub const Diagnostic = struct {
    sqlstate: ?[5]u8 = null,
    outcome: Outcome = .connection,

    pub fn reset(self: *Diagnostic) void {
        self.* = .{};
    }

    pub fn sqlstateSlice(self: *const Diagnostic) ?[]const u8 {
        return if (self.sqlstate) |*sqlstate| sqlstate else null;
    }

    fn capture(self: *Diagnostic, conn: *pg.Conn) void {
        self.reset();
        const pg_error = conn.err orelse return;
        if (pg_error.code.len != 5) return;
        var sqlstate: [5]u8 = undefined;
        @memcpy(&sqlstate, pg_error.code);
        self.sqlstate = sqlstate;
        self.outcome = if (std.mem.eql(u8, pg_error.code, "40003")) .ambiguous else .definite;
    }
};

pub const Options = struct {
    pub const max_supported_lifetime_millis: u64 = 365 * 24 * 60 * 60 * 1_000;

    size: usize = 5,
    checkout_timeout_millis: u32 = 5_000,
    max_lifetime_millis: u64 = 30 * 60 * 1_000,
    lifetime_jitter_basis_points: u16 = 1_000,
    jitter_sample_basis_points: u16 = 5_000,
    idle_validation_millis: u64 = 60_000,

    pub fn validate(self: Options) Error!void {
        if (self.size == 0 or self.size > 256) return error.InvalidPoolSize;
        if (self.checkout_timeout_millis == 0) return error.InvalidTimeout;
        if (self.max_lifetime_millis == 0 or self.max_lifetime_millis > max_supported_lifetime_millis or
            self.idle_validation_millis == 0 or self.idle_validation_millis > max_supported_lifetime_millis)
        {
            return error.InvalidLifetime;
        }
        if (self.lifetime_jitter_basis_points > 10_000 or self.jitter_sample_basis_points > 10_000) return error.InvalidJitter;
    }

    pub fn validateUri(connection_uri: []const u8) Error!void {
        const uri = std.Uri.parse(connection_uri) catch return error.InvalidUri;
        if (!std.mem.eql(u8, uri.scheme, "postgresql") and !std.mem.eql(u8, uri.scheme, "postgres")) return error.InvalidUri;
        if (uri.host == null or uri.user == null or uri.password == null) return error.InvalidUri;
        if (uri.user.?.percent_encoded.len == 0 or uri.password.?.percent_encoded.len == 0) return error.InvalidUri;
        if (std.mem.trim(u8, uri.path.percent_encoded, "/").len == 0) return error.InvalidUri;
        const query = uri.query orelse return error.VerifiedTlsRequired;
        if (std.mem.eql(u8, query.percent_encoded, "sslmode=verify-full")) return;
        if (std.mem.indexOfScalar(u8, query.percent_encoded, '&') == null and
            std.mem.startsWith(u8, query.percent_encoded, "sslmode="))
        {
            return error.VerifiedTlsRequired;
        }
        return error.InvalidUri;
    }

    pub fn effectiveLifetimeMillis(self: Options, sample_basis_points: u16) u64 {
        const sample = @min(sample_basis_points, 10_000);
        const lifetime: u128 = self.max_lifetime_millis;
        const spread = lifetime * self.lifetime_jitter_basis_points / 10_000;
        const lower = lifetime - spread;
        return @intCast(lower + (spread * 2 * sample / 10_000));
    }
};

pub fn shouldRotate(options: Options, created_at_millis: u64, now_millis: u64, active_operations: usize) bool {
    if (active_operations != 0 or now_millis < created_at_millis) return false;
    return now_millis - created_at_millis >= options.effectiveLifetimeMillis(options.jitter_sample_basis_points);
}

pub const Pool = struct {
    allocator: std.mem.Allocator,
    secure_allocator: *ZeroingAllocator,
    io: std.Io,
    options: Options,
    connection_uri: []u8,
    inner: *pg.Pool,
    created_at_millis: u64,
    last_used_millis: u64,
    effective_lifetime_millis: u64,
    active_operations: usize = 0,
    mutex: std.Io.Mutex = .init,

    pub fn init(
        allocator: std.mem.Allocator,
        io: std.Io,
        connection_uri: []const u8,
        options: Options,
        now_millis: u64,
    ) !Pool {
        try options.validate();
        try Options.validateUri(connection_uri);
        const owned_uri = try allocator.dupe(u8, connection_uri);
        errdefer {
            std.crypto.secureZero(u8, owned_uri);
            allocator.free(owned_uri);
        }
        const secure_allocator = try allocator.create(ZeroingAllocator);
        errdefer allocator.destroy(secure_allocator);
        secure_allocator.* = .{ .backing = allocator };
        const inner = try initInner(secure_allocator.allocator(), io, owned_uri, options);
        return .{
            .allocator = allocator,
            .secure_allocator = secure_allocator,
            .io = io,
            .options = options,
            .connection_uri = owned_uri,
            .inner = inner,
            .created_at_millis = now_millis,
            .last_used_millis = now_millis,
            .effective_lifetime_millis = options.effectiveLifetimeMillis(options.jitter_sample_basis_points),
        };
    }

    pub fn deinit(self: *Pool) void {
        self.mutex.lockUncancelable(self.io);
        std.debug.assert(self.active_operations == 0);
        secureDeinitInner(self.inner);
        self.allocator.destroy(self.secure_allocator);
        std.crypto.secureZero(u8, self.connection_uri);
        self.allocator.free(self.connection_uri);
        self.mutex.unlock(self.io);
        self.* = undefined;
    }

    pub fn queryDetailedAlloc(
        self: *Pool,
        allocator: std.mem.Allocator,
        statement: []const u8,
        diagnostic: *Diagnostic,
        now_millis: u64,
    ) !zstd.Sql.QueryResult {
        const validate_idle = try self.beginOperation(now_millis);
        defer self.endOperation(now_millis);
        if (validate_idle) try self.validateConnection(diagnostic);
        return self.queryInnerAlloc(allocator, statement, diagnostic);
    }

    pub fn executeDetailed(
        self: *Pool,
        statement: []const u8,
        diagnostic: *Diagnostic,
        now_millis: u64,
    ) !?i64 {
        const validate_idle = try self.beginOperation(now_millis);
        defer self.endOperation(now_millis);
        if (validate_idle) try self.validateConnection(diagnostic);
        return self.executeInner(statement, diagnostic);
    }

    pub fn stats(self: *Pool) pg.Pool.Stats {
        return self.inner.stats();
    }

    fn beginOperation(self: *Pool, now_millis: u64) !bool {
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        if (self.active_operations == 0 and now_millis >= self.created_at_millis and
            now_millis - self.created_at_millis >= self.effective_lifetime_millis)
        {
            try self.rotateLocked(now_millis);
        }
        const validate_idle = self.active_operations == 0 and now_millis >= self.last_used_millis and
            now_millis - self.last_used_millis >= self.options.idle_validation_millis;
        self.active_operations += 1;
        return validate_idle;
    }

    fn endOperation(self: *Pool, now_millis: u64) void {
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        std.debug.assert(self.active_operations > 0);
        self.active_operations -= 1;
        self.last_used_millis = now_millis;
    }

    fn rotateLocked(self: *Pool, now_millis: u64) !void {
        const replacement = try initInner(self.secure_allocator.allocator(), self.io, self.connection_uri, self.options);
        const previous = self.inner;
        self.inner = replacement;
        self.created_at_millis = now_millis;
        self.last_used_millis = now_millis;
        secureDeinitInner(previous);
    }

    fn validateConnection(self: *Pool, diagnostic: *Diagnostic) !void {
        _ = try self.executeInner("SELECT 1", diagnostic);
    }

    fn executeInner(self: *Pool, statement: []const u8, diagnostic: *Diagnostic) !?i64 {
        diagnostic.reset();
        const conn = try self.inner.acquire();
        defer self.inner.release(conn);
        const affected = conn.exec(statement, .{}) catch |err| {
            diagnostic.capture(conn);
            return err;
        };
        diagnostic.outcome = .definite;
        return affected;
    }

    fn queryInnerAlloc(
        self: *Pool,
        allocator: std.mem.Allocator,
        statement: []const u8,
        diagnostic: *Diagnostic,
    ) !zstd.Sql.QueryResult {
        diagnostic.reset();
        const conn = try self.inner.acquire();
        defer self.inner.release(conn);
        const result = conn.queryOpts(statement, .{}, .{ .column_names = true, .allocator = allocator }) catch |err| {
            diagnostic.capture(conn);
            return err;
        };
        defer result.deinit();
        var rows: std.ArrayList(zstd.Sql.Row) = .empty;
        errdefer {
            deinitRows(allocator, rows.items);
            rows.deinit(allocator);
        }
        while (result.next() catch |err| {
            diagnostic.capture(conn);
            return err;
        }) |next_row| {
            var row = next_row;
            const fields = try allocator.alloc(zstd.Sql.Field, result.number_of_columns);
            var initialized: usize = 0;
            errdefer {
                for (fields[0..initialized]) |*field| field.deinit(allocator);
                allocator.free(fields);
            }
            for (0..result.number_of_columns) |index| {
                const name = try allocator.dupe(u8, result.column_names[index]);
                errdefer allocator.free(name);
                const raw = row.values[index];
                fields[index] = .{
                    .name = name,
                    .value = if (raw.is_null) .null_value else .{ .text = try columnTextAlloc(allocator, &row, index) },
                };
                initialized += 1;
            }
            try rows.append(allocator, .{ .fields = fields });
        }
        diagnostic.outcome = .definite;
        return .{ .rows = try rows.toOwnedSlice(allocator) };
    }
};

fn initInner(allocator: std.mem.Allocator, io: std.Io, connection_uri: []const u8, options: Options) !*pg.Pool {
    var parsed = try ParsedConnection.init(allocator, connection_uri);
    defer parsed.deinit();
    return pg.Pool.init(io, allocator, .{
        .size = @intCast(options.size),
        .timeout = options.checkout_timeout_millis,
        .connect_on_init_count = @intCast(options.size),
        .auth = .{
            .username = parsed.username,
            .password = parsed.password,
            .database = parsed.database,
        },
        .connect = .{
            .host = parsed.host,
            .port = parsed.port,
            .tls = .{ .verify_full = null },
        },
    });
}

const ZeroingAllocator = struct {
    backing: std.mem.Allocator,

    fn allocator(self: *ZeroingAllocator) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable: std.mem.Allocator.VTable = .{
        .alloc = allocate,
        .resize = resize,
        .remap = remap,
        .free = free,
    };

    fn allocate(
        raw: *anyopaque,
        len: usize,
        alignment: std.mem.Alignment,
        return_address: usize,
    ) ?[*]u8 {
        const self: *ZeroingAllocator = @ptrCast(@alignCast(raw));
        return self.backing.rawAlloc(len, alignment, return_address);
    }

    fn resize(
        _: *anyopaque,
        _: []u8,
        _: std.mem.Alignment,
        _: usize,
        _: usize,
    ) bool {
        return false;
    }

    fn remap(
        _: *anyopaque,
        _: []u8,
        _: std.mem.Alignment,
        _: usize,
        _: usize,
    ) ?[*]u8 {
        return null;
    }

    fn free(
        raw: *anyopaque,
        memory: []u8,
        alignment: std.mem.Alignment,
        return_address: usize,
    ) void {
        const self: *ZeroingAllocator = @ptrCast(@alignCast(raw));
        std.crypto.secureZero(u8, memory);
        self.backing.rawFree(memory, alignment, return_address);
    }
};

const ParsedConnection = struct {
    allocator: std.mem.Allocator,
    username: []u8,
    password: []u8,
    host: []u8,
    database: []u8,
    port: u16,

    fn init(allocator: std.mem.Allocator, connection_uri: []const u8) !ParsedConnection {
        try Options.validateUri(connection_uri);
        const uri = std.Uri.parse(connection_uri) catch return error.InvalidUri;
        const username = try percentDecodeAlloc(allocator, uri.user.?.percent_encoded);
        errdefer allocator.free(username);
        const password = try percentDecodeAlloc(allocator, uri.password.?.percent_encoded);
        errdefer {
            std.crypto.secureZero(u8, password);
            allocator.free(password);
        }
        const host = try percentDecodeAlloc(allocator, uri.host.?.percent_encoded);
        errdefer allocator.free(host);
        const encoded_database = std.mem.trimStart(u8, uri.path.percent_encoded, "/");
        const database = try percentDecodeAlloc(allocator, encoded_database);
        errdefer allocator.free(database);
        return .{
            .allocator = allocator,
            .username = username,
            .password = password,
            .host = host,
            .database = database,
            .port = uri.port orelse 5432,
        };
    }

    fn deinit(self: *ParsedConnection) void {
        self.allocator.free(self.username);
        std.crypto.secureZero(u8, self.password);
        self.allocator.free(self.password);
        self.allocator.free(self.host);
        self.allocator.free(self.database);
        self.* = undefined;
    }
};

fn percentDecodeAlloc(allocator: std.mem.Allocator, encoded: []const u8) ![]u8 {
    var decoded: std.ArrayList(u8) = .empty;
    errdefer decoded.deinit(allocator);
    var index: usize = 0;
    while (index < encoded.len) {
        const byte = if (encoded[index] == '%') block: {
            if (index + 2 >= encoded.len) return error.InvalidUri;
            const high = std.fmt.charToDigit(encoded[index + 1], 16) catch return error.InvalidUri;
            const low = std.fmt.charToDigit(encoded[index + 2], 16) catch return error.InvalidUri;
            index += 3;
            break :block @as(u8, @intCast(high * 16 + low));
        } else block: {
            const value = encoded[index];
            index += 1;
            break :block value;
        };
        if (byte == 0) return error.InvalidUri;
        try decoded.append(allocator, byte);
    }
    if (decoded.items.len == 0) return error.InvalidUri;
    return decoded.toOwnedSlice(allocator);
}

fn secureDeinitInner(inner: *pg.Pool) void {
    if (inner._opts.auth.password) |password| {
        std.crypto.secureZero(u8, @constCast(password));
    }
    inner.deinit();
}

fn columnTextAlloc(allocator: std.mem.Allocator, row: *const pg.Row, index: usize) ![]u8 {
    return switch (row.oids[index]) {
        16 => allocator.dupe(u8, if (try row.get(bool, index)) "true" else "false"),
        20 => std.fmt.allocPrint(allocator, "{d}", .{try row.get(i64, index)}),
        21 => std.fmt.allocPrint(allocator, "{d}", .{try row.get(i16, index)}),
        23 => std.fmt.allocPrint(allocator, "{d}", .{try row.get(i32, index)}),
        700 => std.fmt.allocPrint(allocator, "{d}", .{try row.get(f32, index)}),
        701 => std.fmt.allocPrint(allocator, "{d}", .{try row.get(f64, index)}),
        19, 25, 1042, 1043, 114, 3802 => allocator.dupe(u8, try row.get([]const u8, index)),
        2950 => block: {
            const encoded = try pg.uuidToHex(try row.get([]const u8, index));
            break :block allocator.dupe(u8, &encoded);
        },
        else => error.UnsupportedColumnType,
    };
}

fn deinitRows(allocator: std.mem.Allocator, rows: []const zstd.Sql.Row) void {
    for (rows) |row| {
        var owned = row;
        owned.deinit(allocator);
    }
}

test "native pool policy requires verified TLS and bounded capacity" {
    try std.testing.expectError(error.VerifiedTlsRequired, Options.validateUri(
        "postgresql://user:password@db.example:26257/app?sslmode=require",
    ));
    try Options.validateUri("postgresql://user:password@db.example:26257/app?sslmode=verify-full");
    try std.testing.expectError(error.InvalidUri, Options.validateUri(
        "postgresql://db.example:26257/app?sslmode=verify-full",
    ));
    try std.testing.expectError(error.InvalidUri, Options.validateUri(
        "postgresql://user:password@db.example:26257/?sslmode=verify-full",
    ));
    try std.testing.expectError(error.InvalidUri, Options.validateUri(
        "postgresql://user:password@db.example:26257/app?sslmode=verify-full&application_name=ziac",
    ));
    try std.testing.expectError(error.InvalidPoolSize, (Options{ .size = 0 }).validate());
    try std.testing.expectError(error.InvalidPoolSize, (Options{ .size = 257 }).validate());
    try std.testing.expectError(error.InvalidLifetime, (Options{ .max_lifetime_millis = 0 }).validate());
    try std.testing.expectError(error.InvalidLifetime, (Options{
        .max_lifetime_millis = Options.max_supported_lifetime_millis + 1,
    }).validate());
}

test "native connection parser owns and decodes authentication fields" {
    var parsed = try ParsedConnection.init(
        std.testing.allocator,
        "postgresql://app%20user:p%40ss%3Aword@db.example:26257/app%2Ddata?sslmode=verify-full",
    );
    defer parsed.deinit();

    try std.testing.expectEqualStrings("app user", parsed.username);
    try std.testing.expectEqualStrings("p@ss:word", parsed.password);
    try std.testing.expectEqualStrings("db.example", parsed.host);
    try std.testing.expectEqualStrings("app-data", parsed.database);
    try std.testing.expectEqual(@as(u16, 26257), parsed.port);
}

test "native driver allocator zeroes memory before returning it" {
    var storage: [128]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    var zeroing = ZeroingAllocator{ .backing = fixed.allocator() };
    const allocator = zeroing.allocator();
    const secret = try allocator.alloc(u8, 32);
    @memset(secret, 0xa5);
    const start = @intFromPtr(secret.ptr) - @intFromPtr(&storage);
    allocator.free(secret);

    for (storage[start .. start + 32]) |byte| try std.testing.expectEqual(@as(u8, 0), byte);
}

test "native pool lifetime jitter is deterministic and bounded" {
    const policy = Options{
        .max_lifetime_millis = 1_000,
        .lifetime_jitter_basis_points = 1_000,
    };
    try std.testing.expectEqual(@as(u64, 900), policy.effectiveLifetimeMillis(0));
    try std.testing.expectEqual(@as(u64, 1_000), policy.effectiveLifetimeMillis(5_000));
    try std.testing.expectEqual(@as(u64, 1_100), policy.effectiveLifetimeMillis(10_000));
    try std.testing.expectEqual(@as(u64, 1_100), policy.effectiveLifetimeMillis(65_535));
}

test "native pool rotates only when idle and its generation expired" {
    const policy = Options{ .max_lifetime_millis = 1_000, .lifetime_jitter_basis_points = 0 };
    try std.testing.expect(!shouldRotate(policy, 100, 1_099, 0));
    try std.testing.expect(shouldRotate(policy, 100, 1_100, 0));
    try std.testing.expect(!shouldRotate(policy, 100, 2_000, 1));
}

test "native pool runs a verified TLS query when explicitly configured" {
    var environment = try std.testing.environ.createMap(std.testing.allocator);
    defer environment.deinit();
    const connection_uri = environment.get("ZIGEFFECT_POSTGRES_LIVE_URL") orelse return error.SkipZigTest;
    var pool = try Pool.init(std.testing.allocator, std.testing.io, connection_uri, .{
        .size = 2,
        .idle_validation_millis = 1,
    }, 1_000);
    defer pool.deinit();
    var diagnostic = Diagnostic{};
    var result = try pool.queryDetailedAlloc(
        std.testing.allocator,
        "SELECT 1 AS value, true AS active, 'ziac'::STRING AS name, NULL::STRING AS missing",
        &diagnostic,
        2_000,
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), result.rows.len);
    try std.testing.expectEqualStrings("value", result.rows[0].fields[0].name);
    try std.testing.expectEqualStrings("1", result.rows[0].fields[0].value.text);
    try std.testing.expectEqualStrings("true", result.rows[0].fields[1].value.text);
    try std.testing.expectEqualStrings("ziac", result.rows[0].fields[2].value.text);
    try std.testing.expect(result.rows[0].fields[3].value == .null_value);
    try std.testing.expectEqual(Outcome.definite, diagnostic.outcome);
    const stats = pool.stats();
    try std.testing.expectEqual(@as(usize, 2), stats.size);
    try std.testing.expectEqual(@as(usize, 0), stats.in_use);
}
