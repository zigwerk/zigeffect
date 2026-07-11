const std = @import("std");
pub const zstd = @import("zigeffect_std");

pub const Sql = zstd.Sql;
pub const External = zstd.External;

const PGconn = opaque {};
const PGresult = opaque {};
const PGcancel = opaque {};
const Oid = c_uint;

extern fn PQconnectdb(connection: [*:0]const u8) ?*PGconn;
extern fn PQfinish(connection: *PGconn) void;
extern fn PQstatus(connection: *const PGconn) c_int;
extern fn PQreset(connection: *PGconn) void;
extern fn PQserverVersion(connection: *const PGconn) c_int;
extern fn PQprotocolVersion(connection: *const PGconn) c_int;
extern fn PQexec(connection: *PGconn, query: [*:0]const u8) ?*PGresult;
extern fn PQexecParams(
    connection: *PGconn,
    command: [*:0]const u8,
    parameter_count: c_int,
    parameter_types: ?[*]const Oid,
    parameter_values: ?[*]const ?[*:0]const u8,
    parameter_lengths: ?[*]const c_int,
    parameter_formats: ?[*]const c_int,
    result_format: c_int,
) ?*PGresult;
extern fn PQprepare(connection: *PGconn, name: [*:0]const u8, query: [*:0]const u8, parameter_count: c_int, parameter_types: ?[*]const Oid) ?*PGresult;
extern fn PQexecPrepared(
    connection: *PGconn,
    name: [*:0]const u8,
    parameter_count: c_int,
    parameter_values: ?[*]const ?[*:0]const u8,
    parameter_lengths: ?[*]const c_int,
    parameter_formats: ?[*]const c_int,
    result_format: c_int,
) ?*PGresult;
extern fn PQclear(result: *PGresult) void;
extern fn PQresultStatus(result: *const PGresult) c_int;
extern fn PQntuples(result: *const PGresult) c_int;
extern fn PQnfields(result: *const PGresult) c_int;
extern fn PQfname(result: *const PGresult, column: c_int) ?[*:0]const u8;
extern fn PQftype(result: *const PGresult, column: c_int) Oid;
extern fn PQgetisnull(result: *const PGresult, row: c_int, column: c_int) c_int;
extern fn PQgetvalue(result: *const PGresult, row: c_int, column: c_int) [*]const u8;
extern fn PQgetlength(result: *const PGresult, row: c_int, column: c_int) c_int;
extern fn PQresultErrorField(result: *const PGresult, field_code: c_int) ?[*:0]const u8;
extern fn PQgetCancel(connection: *PGconn) ?*PGcancel;
extern fn PQcancel(cancel: *PGcancel, error_buffer: [*]u8, error_buffer_size: c_int) c_int;
extern fn PQfreeCancel(cancel: *PGcancel) void;
extern fn PQtransactionStatus(connection: *const PGconn) c_int;
const NoticeProcessor = *const fn (?*anyopaque, [*:0]const u8) callconv(.c) void;
extern fn PQsetNoticeProcessor(connection: *PGconn, processor: NoticeProcessor, argument: ?*anyopaque) ?NoticeProcessor;

const connection_ok = 0;
const result_command_ok = 1;
const result_tuples_ok = 2;
const transaction_idle = 0;
const transaction_intrans = 2;
const diagnostic_sqlstate = 'C';

pub const capability = zstd.Capability.Descriptor{
    .id = "zigeffect-postgres.libpq",
    .kind = .sql_database,
    .maturity = .production_candidate,
    .package = "zigeffect-postgres-libpq",
    .version = "0.1.0",
    .features = &.{ "native-protocol", "persistent-session", "safe-bindings", "prepared-statements", "cancellation", "transactions" },
    .side_effects = .real,
    .conformance = .{ .schema = "zigeffect.postgres-live-conformance", .version = 1, .receipt = "conformance/postgres-cockroach-live.v1.json", .authority = .live_external, .observed_at_ms = 1783777336000, .valid_until_ms = 1791553336000, .content_sha256 = "sha256:afc72df4c305d9911b20a8baf28d62f255308627f2d833054a7dcb34a67d81fa" },
    .limitations = &.{
        "requires a compatible system libpq installation",
        "libpq and a compatible PostgreSQL wire endpoint are required",
    },
};

pub const Config = struct {
    connection_url: []const u8,
    prepared_cache_capacity: usize = 64,

    pub fn validate(self: Config) !void {
        if (self.connection_url.len == 0) return error.MissingConnectionUrl;
        if (self.prepared_cache_capacity == 0) return error.InvalidPreparedCacheCapacity;
    }
};

pub const BoundParameters = struct {
    allocator: std.mem.Allocator,
    values: []?[*:0]const u8,
    lengths: []c_int,
    formats: []c_int,
    owned: []?[:0]u8,

    pub fn initAlloc(allocator: std.mem.Allocator, binds: []const Sql.Value) !BoundParameters {
        if (binds.len > std.math.maxInt(c_int)) return error.TooManyParameters;
        const values = try allocator.alloc(?[*:0]const u8, binds.len);
        errdefer allocator.free(values);
        const lengths = try allocator.alloc(c_int, binds.len);
        errdefer allocator.free(lengths);
        const formats = try allocator.alloc(c_int, binds.len);
        errdefer allocator.free(formats);
        const owned = try allocator.alloc(?[:0]u8, binds.len);
        errdefer allocator.free(owned);
        @memset(owned, null);
        var initialized: usize = 0;
        errdefer for (owned[0..initialized]) |item| if (item) |bytes| allocator.free(bytes);
        for (binds, 0..) |bind, index| {
            const encoded: ?[:0]u8 = switch (bind) {
                .null_value => null,
                .text => |value| try allocator.dupeZ(u8, value),
                .integer => |value| try std.fmt.allocPrintSentinel(allocator, "{d}", .{value}, 0),
                .float => |value| try std.fmt.allocPrintSentinel(allocator, "{d}", .{value}, 0),
                .boolean => |value| try allocator.dupeZ(u8, if (value) "true" else "false"),
                .bytes => |value| try allocator.dupeZ(u8, value),
                .timestamp => |value| try allocator.dupeZ(u8, value),
                .decimal => |value| try allocator.dupeZ(u8, value),
                .text_array => |value| try encodeTextArrayAlloc(allocator, value),
            };
            owned[index] = encoded;
            initialized += 1;
            values[index] = if (encoded) |bytes| bytes.ptr else null;
            lengths[index] = if (encoded) |bytes| @intCast(bytes.len) else 0;
            formats[index] = switch (bind) { .bytes => 1, else => 0 };
        }
        return .{ .allocator = allocator, .values = values, .lengths = lengths, .formats = formats, .owned = owned };
    }

    pub fn deinit(self: *BoundParameters) void {
        for (self.owned) |item| if (item) |bytes| self.allocator.free(bytes);
        self.allocator.free(self.values);
        self.allocator.free(self.lengths);
        self.allocator.free(self.formats);
        self.allocator.free(self.owned);
        self.* = undefined;
    }
};

pub const DatabaseFailure = struct {
    external: zstd.External.Failure,
    sqlstate: [5]u8 = .{ 0, 0, 0, 0, 0 },
    has_sqlstate: bool = false,

    pub fn class(self: DatabaseFailure) zstd.External.Class {
        return self.external.class;
    }
};

pub const Cancellation = struct {
    handle: *PGcancel,
    released: bool = false,

    pub fn cancel(self: *Cancellation) !void {
        if (self.released) return error.CancellationReleased;
        var error_buffer: [256]u8 = undefined;
        if (PQcancel(self.handle, &error_buffer, error_buffer.len) != 1) return error.CancellationFailed;
    }

    pub fn deinit(self: *Cancellation) void {
        if (!self.released) PQfreeCancel(self.handle);
        self.released = true;
    }
};

pub fn QueryOutcome(comptime Success: type) type {
    return union(enum) { success: Success, failure: DatabaseFailure };
}

const PreparedEntry = struct {
    sql: []u8,
    name: [:0]u8,
};

const NoticeState = struct {
    count: std.atomic.Value(u64) = .init(0),
};

fn recordNotice(argument: ?*anyopaque, _: [*:0]const u8) callconv(.c) void {
    const state: *NoticeState = @ptrCast(@alignCast(argument.?));
    _ = state.count.fetchAdd(1, .monotonic);
}

pub const Session = struct {
    allocator: std.mem.Allocator,
    connection: *PGconn,
    prepared_capacity: usize,
    prepared: std.ArrayList(PreparedEntry) = .empty,
    notices: *NoticeState,

    pub fn init(allocator: std.mem.Allocator, config: Config) !Session {
        try config.validate();
        const url = try allocator.dupeZ(u8, config.connection_url);
        defer allocator.free(url);
        const connection = PQconnectdb(url.ptr) orelse return error.ConnectionAllocationFailed;
        errdefer PQfinish(connection);
        if (PQstatus(connection) != connection_ok) return error.ConnectionFailed;
        const notices = try allocator.create(NoticeState);
        errdefer allocator.destroy(notices);
        notices.* = .{};
        _ = PQsetNoticeProcessor(connection, recordNotice, notices);
        return .{ .allocator = allocator, .connection = connection, .prepared_capacity = config.prepared_cache_capacity, .notices = notices };
    }

    pub fn deinit(self: *Session) void {
        for (self.prepared.items) |entry| {
            self.allocator.free(entry.sql);
            self.allocator.free(entry.name);
        }
        self.prepared.deinit(self.allocator);
        PQfinish(self.connection);
        self.allocator.destroy(self.notices);
        self.* = undefined;
    }

    pub fn healthy(self: *const Session) bool {
        return PQstatus(self.connection) == connection_ok;
    }

    pub fn serverVersion(self: *const Session) u32 {
        return @intCast(@max(PQserverVersion(self.connection), 0));
    }

    pub fn protocolVersion(self: *const Session) u32 {
        return @intCast(@max(PQprotocolVersion(self.connection), 0));
    }

    pub fn noticeCount(self: *const Session) u64 {
        return self.notices.count.load(.monotonic);
    }

    pub fn reset(self: *Session) !void {
        PQreset(self.connection);
        if (!self.healthy()) return error.ConnectionFailed;
        for (self.prepared.items) |entry| {
            self.allocator.free(entry.sql);
            self.allocator.free(entry.name);
        }
        self.prepared.clearRetainingCapacity();
    }

    pub fn queryAlloc(self: *Session, allocator: std.mem.Allocator, statement: Sql.Statement) !Sql.QueryResult {
        var parameters = try BoundParameters.initAlloc(allocator, statement.binds);
        defer parameters.deinit();
        const sql = try allocator.dupeZ(u8, statement.sql);
        defer allocator.free(sql);
        const result = PQexecParams(
            self.connection,
            sql.ptr,
            @intCast(statement.binds.len),
            null,
            if (parameters.values.len == 0) null else parameters.values.ptr,
            if (parameters.lengths.len == 0) null else parameters.lengths.ptr,
            if (parameters.formats.len == 0) null else parameters.formats.ptr,
            0,
        ) orelse return error.QuerySubmissionFailed;
        defer PQclear(result);
        if (!resultSucceeded(result)) return error.PostgresQueryFailed;
        return rowsFromResultAlloc(allocator, result);
    }

    /// Runs a safely-bound query and transfers the owned result into the
    /// resource-safe row stream. Closing or destroying the stream releases all
    /// row storage exactly once.
    pub fn queryStreamAlloc(self: *Session, allocator: std.mem.Allocator, statement: Sql.Statement) !zstd.fx.EffectStream(Sql.Row, anyerror, zstd.Stream.EmptyEnv) {
        const result = try self.queryAlloc(allocator, statement);
        return Sql.rowStreamAlloc(allocator, result);
    }

    /// Runs a typed query and decodes every row through its Schema, preserving
    /// indexed issue paths and redaction on decode failure.
    pub fn queryTypedAlloc(self: *Session, allocator: std.mem.Allocator, query: anytype) !Sql.TypedRows(@TypeOf(query).Output) {
        var result = try self.queryAlloc(allocator, query.statement);
        defer result.deinit(allocator);
        return query.decodeRowsDetailedAlloc(allocator, result);
    }

    pub fn queryClassifiedAlloc(self: *Session, allocator: std.mem.Allocator, statement: Sql.Statement) QueryOutcome(Sql.QueryResult) {
        var parameters = BoundParameters.initAlloc(allocator, statement.binds) catch |err| {
            return .{ .failure = failureFromError("bind", err) };
        };
        defer parameters.deinit();
        const sql = allocator.dupeZ(u8, statement.sql) catch |err| return .{ .failure = failureFromError("query", err) };
        defer allocator.free(sql);
        const result = PQexecParams(
            self.connection,
            sql.ptr,
            @intCast(statement.binds.len),
            null,
            if (parameters.values.len == 0) null else parameters.values.ptr,
            if (parameters.lengths.len == 0) null else parameters.lengths.ptr,
            if (parameters.formats.len == 0) null else parameters.formats.ptr,
            0,
        ) orelse return .{ .failure = failureFromError("query", error.QuerySubmissionFailed) };
        defer PQclear(result);
        if (!resultSucceeded(result)) return .{ .failure = failureFromResult(result, "query") };
        const rows = rowsFromResultAlloc(allocator, result) catch |err| return .{ .failure = failureFromError("decode", err) };
        return .{ .success = rows };
    }

    pub fn prepare(self: *Session, name: []const u8, sql_text: []const u8, parameter_count: usize) !void {
        if (parameter_count > std.math.maxInt(c_int)) return error.TooManyParameters;
        if (!validPreparedName(name)) return error.InvalidPreparedName;
        const name_z = try self.allocator.dupeZ(u8, name);
        defer self.allocator.free(name_z);
        const sql_z = try self.allocator.dupeZ(u8, sql_text);
        defer self.allocator.free(sql_z);
        const result = PQprepare(self.connection, name_z.ptr, sql_z.ptr, @intCast(parameter_count), null) orelse return error.QuerySubmissionFailed;
        defer PQclear(result);
        if (!resultSucceeded(result)) return error.PostgresQueryFailed;
    }

    pub fn queryPreparedAlloc(self: *Session, allocator: std.mem.Allocator, name: []const u8, binds: []const Sql.Value) !Sql.QueryResult {
        if (!validPreparedName(name)) return error.InvalidPreparedName;
        var parameters = try BoundParameters.initAlloc(allocator, binds);
        defer parameters.deinit();
        const name_z = try allocator.dupeZ(u8, name);
        defer allocator.free(name_z);
        const result = PQexecPrepared(
            self.connection,
            name_z.ptr,
            @intCast(binds.len),
            if (parameters.values.len == 0) null else parameters.values.ptr,
            if (parameters.lengths.len == 0) null else parameters.lengths.ptr,
            if (parameters.formats.len == 0) null else parameters.formats.ptr,
            0,
        ) orelse return error.QuerySubmissionFailed;
        defer PQclear(result);
        if (!resultSucceeded(result)) return error.PostgresQueryFailed;
        return rowsFromResultAlloc(allocator, result);
    }

    pub fn queryCachedAlloc(self: *Session, allocator: std.mem.Allocator, statement: Sql.Statement) !Sql.QueryResult {
        for (self.prepared.items) |entry| {
            if (std.mem.eql(u8, entry.sql, statement.sql)) return self.queryPreparedAlloc(allocator, entry.name, statement.binds);
        }
        if (self.prepared.items.len >= self.prepared_capacity) return error.PreparedCacheFull;
        const hash = std.hash.Wyhash.hash(0, statement.sql);
        const name = try std.fmt.allocPrintSentinel(self.allocator, "zigeffect_{x}", .{hash}, 0);
        errdefer self.allocator.free(name);
        try self.prepare(name, statement.sql, statement.binds.len);
        const sql_copy = try self.allocator.dupe(u8, statement.sql);
        errdefer self.allocator.free(sql_copy);
        try self.prepared.append(self.allocator, .{ .sql = sql_copy, .name = name });
        return self.queryPreparedAlloc(allocator, name, statement.binds);
    }

    pub fn executeTrustedAlloc(self: *Session, allocator: std.mem.Allocator, trusted_sql: []const u8) !Sql.QueryResult {
        if (trusted_sql.len == 0) return error.EmptyTrustedSql;
        const sql = try allocator.dupeZ(u8, trusted_sql);
        defer allocator.free(sql);
        const result = PQexec(self.connection, sql.ptr) orelse return error.QuerySubmissionFailed;
        defer PQclear(result);
        if (!resultSucceeded(result)) return error.PostgresQueryFailed;
        return rowsFromResultAlloc(allocator, result);
    }

    pub fn begin(self: *Session) !void {
        if (PQtransactionStatus(self.connection) != transaction_idle) return error.TransactionAlreadyActive;
        try self.executeCommand("BEGIN");
    }

    pub fn commit(self: *Session) !void {
        if (PQtransactionStatus(self.connection) != transaction_intrans) return error.NoActiveTransaction;
        try self.executeCommand("COMMIT");
    }

    pub fn commitClassified(self: *Session) ?DatabaseFailure {
        if (PQtransactionStatus(self.connection) != transaction_intrans) return failureFromError("commit", error.NoActiveTransaction);
        const result = PQexec(self.connection, "COMMIT") orelse return failureFromError("commit", error.QuerySubmissionFailed);
        defer PQclear(result);
        if (!resultSucceeded(result)) return failureFromResult(result, "commit");
        return null;
    }

    pub fn rollback(self: *Session) !void {
        if (PQtransactionStatus(self.connection) == transaction_idle) return error.NoActiveTransaction;
        try self.executeCommand("ROLLBACK");
    }

    pub fn cancel(self: *Session) !void {
        var token = try self.cancellation();
        defer token.deinit();
        try token.cancel();
    }

    pub fn cancellation(self: *Session) !Cancellation {
        return .{ .handle = PQgetCancel(self.connection) orelse return error.CancellationUnavailable };
    }

    fn executeCommand(self: *Session, command: [:0]const u8) !void {
        const result = PQexec(self.connection, command.ptr) orelse return error.QuerySubmissionFailed;
        defer PQclear(result);
        if (PQresultStatus(result) != result_command_ok) return error.PostgresQueryFailed;
    }
};

pub const PoolConfig = struct {
    session: Config,
    size: usize = 8,
    acquisition_timeout_ms: u64 = 5_000,
    poll_interval_ms: u64 = 2,
    idle_timeout_ms: u64 = 300_000,
    max_lifetime_ms: u64 = 3_600_000,

    pub fn validate(self: PoolConfig) !void {
        try self.session.validate();
        if (self.size == 0 or self.acquisition_timeout_ms == 0 or self.poll_interval_ms == 0 or
            self.idle_timeout_ms == 0 or self.max_lifetime_ms == 0)
        {
            return error.InvalidPoolConfig;
        }
        if (self.idle_timeout_ms > self.max_lifetime_ms) return error.InvalidPoolConfig;
    }
};

pub const PoolStats = struct {
    capacity: usize,
    checked_out: usize,
    available: usize,
};

const Slot = struct {
    session: Session,
    leased: bool = false,
    created_ms: i64,
    last_used_ms: i64,
    generation: u64 = 1,
};

pub const Pool = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    config: PoolConfig,
    slots: []Slot,
    mutex: std.atomic.Mutex = .unlocked,
    closing: std.atomic.Value(bool) = .init(false),

    pub fn initAlloc(allocator: std.mem.Allocator, io: std.Io, config: PoolConfig) !Pool {
        try config.validate();
        const slots = try allocator.alloc(Slot, config.size);
        errdefer allocator.free(slots);
        var initialized: usize = 0;
        errdefer for (slots[0..initialized]) |*slot| slot.session.deinit();
        const now = nowMilliseconds(io);
        for (slots) |*slot| {
            slot.* = .{
                .session = try Session.init(allocator, config.session),
                .created_ms = now,
                .last_used_ms = now,
            };
            initialized += 1;
        }
        return .{ .allocator = allocator, .io = io, .config = config, .slots = slots };
    }

    pub fn close(self: *Pool) !void {
        self.closing.store(true, .release);
        self.lock();
        defer self.mutex.unlock();
        for (self.slots) |slot| if (slot.leased) return error.PoolBusy;
    }

    pub fn deinit(self: *Pool) void {
        self.closing.store(true, .release);
        self.lock();
        for (self.slots) |slot| std.debug.assert(!slot.leased);
        for (self.slots) |*slot| slot.session.deinit();
        self.mutex.unlock();
        self.allocator.free(self.slots);
        self.* = undefined;
    }

    pub fn checkout(self: *Pool) !Lease {
        if (self.closing.load(.acquire)) return error.PoolClosed;
        const deadline = std.Io.Clock.Timestamp.fromNow(self.io, .{
            .raw = .fromMilliseconds(@intCast(self.config.acquisition_timeout_ms)),
            .clock = .awake,
        });
        while (true) {
            self.lock();
            if (self.closing.load(.acquire)) {
                self.mutex.unlock();
                return error.PoolClosed;
            }
            for (self.slots, 0..) |*slot, index| {
                if (slot.leased) continue;
                slot.leased = true;
                const now = nowMilliseconds(self.io);
                const expired = elapsedAtLeast(now, slot.created_ms, self.config.max_lifetime_ms) or
                    elapsedAtLeast(now, slot.last_used_ms, self.config.idle_timeout_ms) or
                    !slot.session.healthy();
                if (expired) {
                    self.mutex.unlock();
                    slot.session.reset() catch {
                        self.lock();
                        slot.leased = false;
                        self.mutex.unlock();
                        return error.ConnectionRecoveryFailed;
                    };
                    self.lock();
                    slot.created_ms = now;
                    slot.generation +%= 1;
                    if (slot.generation == 0) slot.generation = 1;
                }
                const generation = slot.generation;
                self.mutex.unlock();
                return .{ .pool = self, .index = index, .generation = generation };
            }
            self.mutex.unlock();
            const now = std.Io.Clock.Timestamp.now(self.io, .awake);
            if (std.Io.Clock.Timestamp.compare(now, .gte, deadline)) return error.PoolAcquisitionTimeout;
            try (std.Io.Clock.Duration{
                .raw = .fromMilliseconds(@intCast(self.config.poll_interval_ms)),
                .clock = .awake,
            }).sleep(self.io);
        }
    }

    pub fn checkoutTransaction(self: *Pool) !Transaction {
        var lease = try self.checkout();
        errdefer lease.deinit();
        try lease.session().begin();
        return .{ .lease = lease };
    }

    pub fn stats(self: *Pool) PoolStats {
        self.lock();
        defer self.mutex.unlock();
        var checked_out: usize = 0;
        for (self.slots) |slot| if (slot.leased) {
            checked_out += 1;
        };
        return .{ .capacity = self.slots.len, .checked_out = checked_out, .available = self.slots.len - checked_out };
    }

    fn release(self: *Pool, index: usize, generation: u64) !void {
        self.lock();
        defer self.mutex.unlock();
        if (index >= self.slots.len) return error.InvalidLease;
        const slot = &self.slots[index];
        if (!slot.leased or slot.generation != generation) return error.StaleLease;
        if (PQtransactionStatus(slot.session.connection) != transaction_idle) return error.TransactionStillActive;
        slot.last_used_ms = nowMilliseconds(self.io);
        slot.leased = false;
    }

    fn lock(self: *Pool) void {
        while (!self.mutex.tryLock()) std.Thread.yield() catch {};
    }
};

pub const Lease = struct {
    pool: *Pool,
    index: usize,
    generation: u64,
    released: bool = false,

    pub fn session(self: *Lease) *Session {
        std.debug.assert(!self.released);
        return &self.pool.slots[self.index].session;
    }

    pub fn queryAlloc(self: *Lease, allocator: std.mem.Allocator, statement: Sql.Statement) !Sql.QueryResult {
        return self.session().queryAlloc(allocator, statement);
    }

    pub fn queryCachedAlloc(self: *Lease, allocator: std.mem.Allocator, statement: Sql.Statement) !Sql.QueryResult {
        return self.session().queryCachedAlloc(allocator, statement);
    }

    pub fn release(self: *Lease) !void {
        if (self.released) return;
        try self.pool.release(self.index, self.generation);
        self.released = true;
    }

    pub fn deinit(self: *Lease) void {
        if (!self.released) self.release() catch {};
    }
};

pub const Transaction = struct {
    lease: Lease,
    finished: bool = false,

    pub fn session(self: *Transaction) *Session {
        return self.lease.session();
    }

    pub fn queryAlloc(self: *Transaction, allocator: std.mem.Allocator, statement: Sql.Statement) !Sql.QueryResult {
        if (self.finished) return error.TransactionFinished;
        return self.session().queryAlloc(allocator, statement);
    }

    pub fn commit(self: *Transaction) !void {
        if (self.finished) return;
        try self.session().commit();
        self.finished = true;
        try self.lease.release();
    }

    pub fn rollback(self: *Transaction) !void {
        if (self.finished) return;
        try self.session().rollback();
        self.finished = true;
        try self.lease.release();
    }

    pub fn deinit(self: *Transaction) void {
        if (!self.finished) {
            self.session().rollback() catch {};
            self.finished = true;
        }
        self.lease.deinit();
    }
};

pub const SerializableOutcome = union(enum) {
    success: u32,
    failure: struct { attempts: u32, cause: DatabaseFailure },
};

pub fn runSerializable(session: *Session, max_attempts: u32, handler: anytype) !SerializableOutcome {
    if (max_attempts == 0) return error.InvalidRetryAttempts;
    var attempt: u32 = 0;
    while (attempt < max_attempts) {
        attempt += 1;
        try session.begin();
        const result: QueryOutcome(void) = handler.run(session, attempt);
        switch (result) {
            .failure => |failure| {
                session.rollback() catch {};
                if (failure.class() == .conflict and attempt < max_attempts) continue;
                return .{ .failure = .{ .attempts = attempt, .cause = failure } };
            },
            .success => {},
        }
        if (session.commitClassified()) |failure| {
            session.rollback() catch {};
            if (failure.class() == .conflict and attempt < max_attempts) continue;
            return .{ .failure = .{ .attempts = attempt, .cause = failure } };
        }
        return .{ .success = attempt };
    }
    unreachable;
}

pub const MigrationReport = struct {
    allocator: std.mem.Allocator,
    applied: usize,
    skipped: usize,
    receipt_json: []const u8,

    pub fn deinit(self: *MigrationReport) void {
        self.allocator.free(self.receipt_json);
        self.* = undefined;
    }
};

pub const MigrationOptions = struct {
    pub const Dialect = enum { postgresql, cockroachdb };

    table: []const u8 = "zigeffect_migrations",
    lock_id: i64 = 1,
    dialect: Dialect = .postgresql,

    pub fn validate(self: MigrationOptions) !void {
        if (!validIdentifier(self.table) or self.table.len > 48) return error.InvalidMigrationTable;
    }
};

var migration_holder_sequence: std.atomic.Value(u64) = .init(1);

pub fn migrationChecksum(migration: Sql.Migration) [64]u8 {
    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update(migration.id);
    hash.update(&.{0});
    hash.update(migration.sql);
    hash.final(&digest);
    return std.fmt.bytesToHex(digest, .lower);
}

pub fn applyMigrationsAlloc(
    allocator: std.mem.Allocator,
    session: *Session,
    options: MigrationOptions,
    migrations: []const Sql.Migration,
) !MigrationReport {
    try options.validate();
    for (migrations) |migration| {
        if (migration.id.len == 0 or migration.id.len > 128 or migration.sql.len == 0) return error.InvalidMigration;
    }

    const setup = try std.fmt.allocPrint(
        allocator,
        "create table if not exists {s} (id text primary key, checksum text not null, applied_at timestamptz not null default now());" ++
            "create table if not exists {s}_lock (id bigint primary key, holder text not null, expires_at timestamptz not null);",
        .{ options.table, options.table },
    );
    defer allocator.free(setup);
    var setup_result = try session.executeTrustedAlloc(allocator, setup);
    setup_result.deinit(allocator);

    const holder = try std.fmt.allocPrint(allocator, "zigeffect-{x}", .{migration_holder_sequence.fetchAdd(1, .monotonic)});
    defer allocator.free(holder);
    const acquire_sql = try std.fmt.allocPrint(
        allocator,
        "insert into {s}_lock(id, holder, expires_at) values ($1, $2, now() + interval '5 minutes') " ++
            "on conflict (id) do update set holder = excluded.holder, expires_at = excluded.expires_at " ++
            "where {s}_lock.expires_at < now() returning holder",
        .{ options.table, options.table },
    );
    defer allocator.free(acquire_sql);
    var acquired = try session.queryAlloc(allocator, .{
        .sql = acquire_sql,
        .binds = &.{ .{ .integer = options.lock_id }, .{ .text = holder } },
    });
    defer acquired.deinit(allocator);
    if (acquired.rows.len != 1 or !std.mem.eql(u8, acquired.rows[0].fields[0].value.text, holder)) return error.MigrationLockUnavailable;
    const release_sql = try std.fmt.allocPrint(allocator, "delete from {s}_lock where id = $1 and holder = $2", .{options.table});
    defer allocator.free(release_sql);
    defer {
        if (session.queryAlloc(allocator, .{ .sql = release_sql, .binds = &.{ .{ .integer = options.lock_id }, .{ .text = holder } } })) |release_value| {
            var released = release_value;
            released.deinit(allocator);
        } else |_| {}
    }

    var applied: usize = 0;
    var skipped: usize = 0;
    const status_sql = try std.fmt.allocPrint(allocator, "select checksum from {s} where id = $1", .{options.table});
    defer allocator.free(status_sql);
    const insert_sql = try std.fmt.allocPrint(allocator, "insert into {s}(id, checksum) values ($1, $2)", .{options.table});
    defer allocator.free(insert_sql);
    for (migrations) |migration| {
        const checksum = migrationChecksum(migration);
        var status = try session.queryAlloc(allocator, .{ .sql = status_sql, .binds = &.{.{ .text = migration.id }} });
        if (status.rows.len != 0) {
            const recorded = status.rows[0].fields[0].value.text;
            const matches = std.mem.eql(u8, recorded, &checksum);
            status.deinit(allocator);
            if (!matches) return error.MigrationChecksumMismatch;
            skipped += 1;
            continue;
        }
        status.deinit(allocator);
        try applyOneMigration(allocator, session, options.dialect, migration, &checksum, insert_sql);
        applied += 1;
    }

    const applied_text = try std.fmt.allocPrint(allocator, "{d}", .{applied});
    defer allocator.free(applied_text);
    const skipped_text = try std.fmt.allocPrint(allocator, "{d}", .{skipped});
    defer allocator.free(skipped_text);
    const receipt = try zstd.Json.objectFromFieldsAlloc(allocator, &.{
        .{ .name = "kind", .value = "postgres.migration_apply" },
        .{ .name = "table", .value = options.table },
        .{ .name = "applied", .value = applied_text },
        .{ .name = "skipped", .value = skipped_text },
        .{ .name = "locking", .value = "expiring-database-lease" },
        .{ .name = "rollback_posture", .value = if (options.dialect == .postgresql) "atomic-per-migration-no-down-migrations" else "cockroach-online-ddl-non-atomic-no-down-migrations" },
    });
    return .{ .allocator = allocator, .applied = applied, .skipped = skipped, .receipt_json = receipt };
}

fn applyOneMigration(
    allocator: std.mem.Allocator,
    session: *Session,
    dialect: MigrationOptions.Dialect,
    migration: Sql.Migration,
    checksum: *const [64]u8,
    insert_sql: []const u8,
) !void {
    if (dialect == .postgresql) try session.begin();
    errdefer if (dialect == .postgresql) session.rollback() catch {};
    var migration_result = try session.executeTrustedAlloc(allocator, migration.sql);
    migration_result.deinit(allocator);
    var recorded = try session.queryAlloc(allocator, .{
        .sql = insert_sql,
        .binds = &.{ .{ .text = migration.id }, .{ .text = checksum } },
    });
    recorded.deinit(allocator);
    if (dialect == .postgresql) try session.commit();
}

fn nowMilliseconds(io: std.Io) i64 {
    const nanoseconds = std.Io.Clock.awake.now(io).nanoseconds;
    return @intCast(@divTrunc(nanoseconds, std.time.ns_per_ms));
}

fn elapsedAtLeast(now: i64, then: i64, duration_ms: u64) bool {
    if (now < then) return false;
    return @as(u64, @intCast(now - then)) >= duration_ms;
}

fn resultSucceeded(result: *const PGresult) bool {
    const status = PQresultStatus(result);
    return status == result_command_ok or status == result_tuples_ok;
}

fn rowsFromResultAlloc(allocator: std.mem.Allocator, result: *const PGresult) !Sql.QueryResult {
    const row_count: usize = @intCast(@max(PQntuples(result), 0));
    const field_count: usize = @intCast(@max(PQnfields(result), 0));
    const rows = try allocator.alloc(Sql.Row, row_count);
    errdefer allocator.free(rows);
    var initialized_rows: usize = 0;
    errdefer for (rows[0..initialized_rows]) |*row| row.deinit(allocator);
    for (rows, 0..) |*row, row_index| {
        const fields = try allocator.alloc(Sql.Field, field_count);
        errdefer allocator.free(fields);
        var initialized_fields: usize = 0;
        errdefer for (fields[0..initialized_fields]) |*field| field.deinit(allocator);
        for (fields, 0..) |*field, field_index| {
            const name_ptr = PQfname(result, @intCast(field_index)) orelse return error.MissingColumnName;
            const name = try allocator.dupe(u8, std.mem.span(name_ptr));
            errdefer allocator.free(name);
            const value: Sql.Value = if (PQgetisnull(result, @intCast(row_index), @intCast(field_index)) == 1)
                .null_value
            else value: {
                const length: usize = @intCast(@max(PQgetlength(result, @intCast(row_index), @intCast(field_index)), 0));
                const bytes = PQgetvalue(result, @intCast(row_index), @intCast(field_index))[0..length];
                break :value try decodeValueAlloc(allocator, PQftype(result, @intCast(field_index)), bytes);
            };
            field.* = .{ .name = name, .value = value };
            initialized_fields += 1;
        }
        row.* = .{ .fields = fields };
        initialized_rows += 1;
    }
    return .{ .rows = rows };
}

fn decodeValueAlloc(allocator: std.mem.Allocator, oid: Oid, bytes: []const u8) !Sql.Value {
    return switch (oid) {
        16 => if (std.mem.eql(u8, bytes, "t")) .{ .boolean = true } else if (std.mem.eql(u8, bytes, "f")) .{ .boolean = false } else error.InvalidBoolean,
        20, 21, 23 => .{ .integer = std.fmt.parseInt(i64, bytes, 10) catch return error.InvalidInteger },
        700, 701 => .{ .float = std.fmt.parseFloat(f64, bytes) catch return error.InvalidFloat },
        17 => .{ .bytes = try decodeByteaHexAlloc(allocator, bytes) },
        1700 => .{ .decimal = try allocator.dupe(u8, bytes) },
        1082, 1083, 1114, 1184, 1266 => .{ .timestamp = try allocator.dupe(u8, bytes) },
        1009, 1015 => .{ .text_array = try decodeTextArrayAlloc(allocator, bytes) },
        else => .{ .text = try allocator.dupe(u8, bytes) },
    };
}

fn encodeTextArrayAlloc(allocator: std.mem.Allocator, values: []const []const u8) ![:0]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.append(allocator, '{');
    for (values, 0..) |value, index| {
        if (index != 0) try output.append(allocator, ',');
        try output.append(allocator, '"');
        for (value) |byte| {
            if (byte == '"' or byte == '\\') try output.append(allocator, '\\');
            try output.append(allocator, byte);
        }
        try output.append(allocator, '"');
    }
    try output.append(allocator, '}');
    return output.toOwnedSliceSentinel(allocator, 0);
}

fn decodeByteaHexAlloc(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
    if (!std.mem.startsWith(u8, value, "\\x") or value.len % 2 != 0) return error.UnsupportedByteaEncoding;
    const output = try allocator.alloc(u8, (value.len - 2) / 2);
    errdefer allocator.free(output);
    _ = std.fmt.hexToBytes(output, value[2..]) catch return error.InvalidBytea;
    return output;
}

fn decodeTextArrayAlloc(allocator: std.mem.Allocator, value: []const u8) ![]const []const u8 {
    if (value.len < 2 or value[0] != '{' or value[value.len - 1] != '}') return error.InvalidTextArray;
    var items: std.ArrayList([]const u8) = .empty;
    errdefer {
        for (items.items) |item| allocator.free(item);
        items.deinit(allocator);
    }
    var index: usize = 1;
    while (index < value.len - 1) {
        var item: std.ArrayList(u8) = .empty;
        errdefer item.deinit(allocator);
        if (value[index] == '"') {
            index += 1;
            while (index < value.len - 1 and value[index] != '"') : (index += 1) {
                if (value[index] == '\\') {
                    index += 1;
                    if (index >= value.len - 1) return error.InvalidTextArray;
                }
                try item.append(allocator, value[index]);
            }
            if (index >= value.len - 1 or value[index] != '"') return error.InvalidTextArray;
            index += 1;
        } else {
            const start = index;
            while (index < value.len - 1 and value[index] != ',') : (index += 1) {}
            try item.appendSlice(allocator, value[start..index]);
        }
        const owned = try item.toOwnedSlice(allocator);
        errdefer allocator.free(owned);
        try items.append(allocator, owned);
        if (index < value.len - 1) {
            if (value[index] != ',') return error.InvalidTextArray;
            index += 1;
        }
    }
    return items.toOwnedSlice(allocator);
}

fn failureFromResult(result: *const PGresult, operation: []const u8) DatabaseFailure {
    var failure = DatabaseFailure{ .external = .init("postgres-libpq", operation, .internal, "database operation failed", "PostgresQueryFailed") };
    if (PQresultErrorField(result, diagnostic_sqlstate)) |state_ptr| {
        const state = std.mem.span(state_ptr);
        if (state.len == 5) {
            @memcpy(&failure.sqlstate, state);
            failure.has_sqlstate = true;
            failure.external.class = classForSqlstate(state);
        }
    }
    return failure;
}

fn failureFromError(operation: []const u8, err: anyerror) DatabaseFailure {
    return .{ .external = zstd.External.Failure.fromError("postgres-libpq", operation, err) };
}

fn classForSqlstate(state: []const u8) zstd.External.Class {
    if (std.mem.eql(u8, state, "40001") or std.mem.eql(u8, state, "40P01") or std.mem.eql(u8, state, "23505")) return .conflict;
    if (std.mem.startsWith(u8, state, "28")) return .unauthorized;
    if (std.mem.startsWith(u8, state, "53")) return .capacity;
    if (std.mem.eql(u8, state, "57014")) return .canceled;
    if (std.mem.eql(u8, state, "57P01") or std.mem.startsWith(u8, state, "08")) return .unavailable;
    return .internal;
}

fn validPreparedName(name: []const u8) bool {
    if (name.len == 0 or name.len > 63) return false;
    for (name) |byte| if (!std.ascii.isAlphanumeric(byte) and byte != '_') return false;
    return true;
}

fn validIdentifier(name: []const u8) bool {
    if (name.len == 0) return false;
    for (name) |byte| if (!std.ascii.isAlphanumeric(byte) and byte != '_') return false;
    return true;
}

test "libpq adapter safely encodes every standard SQL bind without interpolation" {
    var parameters = try BoundParameters.initAlloc(std.testing.allocator, &.{
        .null_value,
        .{ .text = "Robert'); DROP TABLE users;--" },
        .{ .integer = -42 },
        .{ .boolean = true },
        .{ .float = 3.25 },
        .{ .bytes = &.{ 0, 255 } },
        .{ .timestamp = "2026-07-11T12:34:56Z" },
        .{ .decimal = "12345678901234567890.12345" },
        .{ .text_array = &.{ "alpha", "b,c", "quoted\"value", "back\\slash" } },
    });
    defer parameters.deinit();
    try std.testing.expect(parameters.values[0] == null);
    try std.testing.expectEqualStrings("Robert'); DROP TABLE users;--", std.mem.span(parameters.values[1].?));
    try std.testing.expectEqualStrings("-42", std.mem.span(parameters.values[2].?));
    try std.testing.expectEqualStrings("true", std.mem.span(parameters.values[3].?));
    try std.testing.expectEqualStrings("3.25", std.mem.span(parameters.values[4].?));
    try std.testing.expectEqual(@as(c_int, 2), parameters.lengths[5]);
    try std.testing.expectEqual(@as(c_int, 1), parameters.formats[5]);
    try std.testing.expectEqualStrings("2026-07-11T12:34:56Z", std.mem.span(parameters.values[6].?));
    try std.testing.expectEqualStrings("12345678901234567890.12345", std.mem.span(parameters.values[7].?));
    try std.testing.expectEqualStrings("{\"alpha\",\"b,c\",\"quoted\\\"value\",\"back\\\\slash\"}", std.mem.span(parameters.values[8].?));
    try std.testing.expectEqual(@as(c_int, 0), parameters.formats[8]);
}

test "libpq bind encoding survives every allocation failure" {
    const Harness = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var parameters = try BoundParameters.initAlloc(allocator, &.{
                .{ .text = "hello" }, .{ .integer = 42 }, .{ .boolean = false }, .{ .float = 1.5 },
                .{ .bytes = &.{ 0, 1 } }, .{ .timestamp = "2026-01-01T00:00:00Z" }, .{ .decimal = "1.25" },
                .{ .text_array = &.{ "a", "b" } },
            });
            defer parameters.deinit();
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Harness.run, .{});
}

test "libpq classifies stable PostgreSQL SQLSTATE families" {
    try std.testing.expectEqual(zstd.External.Class.conflict, classForSqlstate("40001"));
    try std.testing.expectEqual(zstd.External.Class.conflict, classForSqlstate("23505"));
    try std.testing.expectEqual(zstd.External.Class.unauthorized, classForSqlstate("28P01"));
    try std.testing.expectEqual(zstd.External.Class.capacity, classForSqlstate("53300"));
    try std.testing.expectEqual(zstd.External.Class.canceled, classForSqlstate("57014"));
    try std.testing.expectEqual(zstd.External.Class.unavailable, classForSqlstate("08006"));
}

test "libpq capability carries dual-database live conformance" {
    try capability.validate();
    try std.testing.expectEqual(zstd.Capability.Maturity.production_candidate, capability.maturity);
    try std.testing.expect(capability.conformance != null);
}

test "libpq pool configuration rejects unbounded and inverted lifetimes" {
    const session = Config{ .connection_url = "postgresql://localhost/test" };
    try std.testing.expectError(error.InvalidPoolConfig, (PoolConfig{ .session = session, .size = 0 }).validate());
    try std.testing.expectError(error.InvalidPoolConfig, (PoolConfig{ .session = session, .idle_timeout_ms = 20, .max_lifetime_ms = 10 }).validate());
    try (PoolConfig{ .session = session, .size = 2 }).validate();
}

test "libpq migrations have deterministic content checksums and strict identifiers" {
    const migration = Sql.Migration{ .id = "001_init", .sql = "create table example(id bigint primary key)" };
    const first = migrationChecksum(migration);
    const second = migrationChecksum(migration);
    try std.testing.expectEqualSlices(u8, &first, &second);
    try std.testing.expect(!std.mem.eql(u8, &first, &migrationChecksum(.{ .id = migration.id, .sql = "select 1" })));
    try std.testing.expectError(error.InvalidMigrationTable, (MigrationOptions{ .table = "bad;drop" }).validate());
}
