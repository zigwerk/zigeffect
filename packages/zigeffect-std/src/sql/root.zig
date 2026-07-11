const std = @import("std");
const Json = @import("../json/root.zig");
const Schema = @import("../schema/root.zig");
const Secrets = @import("../secrets/root.zig");
const Capability = @import("../capability/root.zig");
const External = @import("../external/root.zig");
const StdService = @import("../service/root.zig");
const fx = @import("zigeffect");
const Stream = @import("../stream/root.zig");

pub const Value = union(enum) {
    null_value,
    text: []const u8,
    integer: i64,
    float: f64,
    boolean: bool,
    bytes: []const u8,
    timestamp: []const u8,
    decimal: []const u8,
    text_array: []const []const u8,

    pub fn cloneAlloc(self: Value, allocator: std.mem.Allocator) std.mem.Allocator.Error!Value {
        return switch (self) {
            .null_value => .null_value,
            .text => |value| .{ .text = try allocator.dupe(u8, value) },
            .integer => |value| .{ .integer = value },
            .float => |value| .{ .float = value },
            .boolean => |value| .{ .boolean = value },
            .bytes => |value| .{ .bytes = try allocator.dupe(u8, value) },
            .timestamp => |value| .{ .timestamp = try allocator.dupe(u8, value) },
            .decimal => |value| .{ .decimal = try allocator.dupe(u8, value) },
            .text_array => |values| blk: {
                const copied = try allocator.alloc([]const u8, values.len);
                errdefer allocator.free(copied);
                var initialized: usize = 0;
                errdefer for (copied[0..initialized]) |item| allocator.free(item);
                for (values, 0..) |item, index| {
                    copied[index] = try allocator.dupe(u8, item);
                    initialized += 1;
                }
                break :blk .{ .text_array = copied };
            },
        };
    }

    pub fn deinit(self: *Value, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .text, .bytes, .timestamp, .decimal => |value| allocator.free(value),
            .text_array => |values| {
                for (values) |value| allocator.free(value);
                allocator.free(values);
            },
            else => {},
        }
        self.* = .null_value;
    }
};

pub const Field = struct {
    name: []const u8,
    value: Value,

    pub fn cloneAlloc(self: Field, allocator: std.mem.Allocator) std.mem.Allocator.Error!Field {
        const name = try allocator.dupe(u8, self.name);
        errdefer allocator.free(name);
        const value = try self.value.cloneAlloc(allocator);
        return .{ .name = name, .value = value };
    }

    pub fn deinit(self: *Field, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        self.value.deinit(allocator);
        self.* = undefined;
    }
};

pub const Row = struct {
    fields: []const Field,

    pub fn cloneAlloc(self: Row, allocator: std.mem.Allocator) std.mem.Allocator.Error!Row {
        const fields = try allocator.alloc(Field, self.fields.len);
        errdefer allocator.free(fields);

        var initialized: usize = 0;
        errdefer {
            for (fields[0..initialized]) |*field| field.deinit(allocator);
        }

        for (self.fields, 0..) |field, index| {
            fields[index] = try field.cloneAlloc(allocator);
            initialized += 1;
        }

        return .{ .fields = fields };
    }

    pub fn deinit(self: *Row, allocator: std.mem.Allocator) void {
        for (self.fields) |field| {
            var owned_field = field;
            owned_field.deinit(allocator);
        }
        allocator.free(self.fields);
        self.* = undefined;
    }
};

pub const QueryResult = struct {
    rows: []const Row,

    pub fn cloneAlloc(self: QueryResult, allocator: std.mem.Allocator) std.mem.Allocator.Error!QueryResult {
        const rows = try allocator.alloc(Row, self.rows.len);
        errdefer allocator.free(rows);

        var initialized: usize = 0;
        errdefer {
            for (rows[0..initialized]) |*row| row.deinit(allocator);
        }

        for (self.rows, 0..) |row, index| {
            rows[index] = try row.cloneAlloc(allocator);
            initialized += 1;
        }

        return .{ .rows = rows };
    }

    pub fn deinit(self: *QueryResult, allocator: std.mem.Allocator) void {
        for (self.rows) |row| {
            var owned_row = row;
            owned_row.deinit(allocator);
        }
        allocator.free(self.rows);
        self.* = undefined;
    }
};

pub fn rowStreamAlloc(allocator: std.mem.Allocator, result_value: QueryResult) !fx.EffectStream(Row, anyerror, Stream.EmptyEnv) {
    var result = result_value;
    errdefer result.deinit(allocator);
    const Puller = struct {
        allocator: std.mem.Allocator,
        result: QueryResult,
        offset: usize = 0,
        closed: bool = false,
        pub fn pull(self: *@This(), _: *fx.Context(Stream.EmptyEnv), output_allocator: std.mem.Allocator, max: usize) anyerror!fx.EffectStream(Row, anyerror, Stream.EmptyEnv).Chunk { const count = @min(max, self.result.rows.len - self.offset); const rows = try output_allocator.alloc(Row, count); @memcpy(rows, self.result.rows[self.offset .. self.offset + count]); self.offset += count; return .{ .allocator = output_allocator, .items = rows, .end = self.offset == self.result.rows.len }; }
        pub fn close(self: *@This(), _: fx.StreamCloseReason) void { self.closed = true; }
        pub fn deinit(self: *@This()) void { self.result.deinit(self.allocator); }
    };
    return fx.effectStreamFromOwnedPullerAlloc(Row, anyerror, Stream.EmptyEnv, Puller, allocator, .{ .allocator = allocator, .result = result });
}

pub const Statement = struct {
    sql: []const u8,
    binds: []const Value = &.{},
};

pub const Migration = struct {
    id: []const u8,
    sql: []const u8,
};

pub const FakeDatabase = struct {
    pub const capability = Capability.Builtin.fake_sql_database;

    result: QueryResult,
    allocator: ?std.mem.Allocator = null,
    in_transaction: bool = false,
    applied_migrations: std.ArrayList([]const u8) = .empty,

    pub fn init(result: QueryResult) FakeDatabase {
        return .{ .result = result };
    }

    pub fn initOwned(allocator: std.mem.Allocator, result: QueryResult) std.mem.Allocator.Error!FakeDatabase {
        return .{
            .result = try result.cloneAlloc(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *FakeDatabase) void {
        const allocator = self.allocator orelse return;
        self.result.deinit(allocator);
        for (self.applied_migrations.items) |migration_id| allocator.free(migration_id);
        self.applied_migrations.deinit(allocator);
    }

    pub fn query(self: FakeDatabase, sql: []const u8, binds: []const Value) QueryResult {
        _ = sql;
        _ = binds;
        return self.result;
    }

    pub fn queryAlloc(self: *FakeDatabase, allocator: std.mem.Allocator, statement: Statement) std.mem.Allocator.Error!QueryResult {
        _ = statement;
        return self.result.cloneAlloc(allocator);
    }

    pub fn queryClassifiedAlloc(self: *FakeDatabase, allocator: std.mem.Allocator, statement: Statement) External.Result(QueryResult) {
        const result = self.queryAlloc(allocator, statement) catch |err| {
            return .{ .failure = External.Failure.fromError("fake-sql", "query", err) };
        };
        return .{ .success = result };
    }

    pub fn begin(self: *FakeDatabase) error{TransactionAlreadyActive}!void {
        if (self.in_transaction) return error.TransactionAlreadyActive;
        self.in_transaction = true;
    }

    pub fn commit(self: *FakeDatabase) error{NoActiveTransaction}!void {
        if (!self.in_transaction) return error.NoActiveTransaction;
        self.in_transaction = false;
    }

    pub fn rollback(self: *FakeDatabase) error{NoActiveTransaction}!void {
        if (!self.in_transaction) return error.NoActiveTransaction;
        self.in_transaction = false;
    }

    pub fn migrateAlloc(self: *FakeDatabase, allocator: std.mem.Allocator, migrations: []const Migration) std.mem.Allocator.Error!void {
        _ = allocator;
        const owned_allocator = self.allocator orelse return;
        for (migrations) |migration| {
            if (self.hasMigration(migration.id)) continue;
            const owned_id = try owned_allocator.dupe(u8, migration.id);
            errdefer owned_allocator.free(owned_id);
            try self.applied_migrations.append(owned_allocator, owned_id);
        }
    }

    pub fn hasMigration(self: *const FakeDatabase, id: []const u8) bool {
        for (self.applied_migrations.items) |migration_id| {
            if (std.mem.eql(u8, migration_id, id)) return true;
        }
        return false;
    }
};

pub fn redactConnectionAlloc(allocator: std.mem.Allocator, connection: []const u8) ![]const u8 {
    return Secrets.redactAlloc(allocator, connection);
}

pub fn redactStatementAlloc(allocator: std.mem.Allocator, statement: Statement) std.mem.Allocator.Error![]const u8 {
    const sql = try Secrets.redactAlloc(allocator, statement.sql);
    defer allocator.free(sql);

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.print(allocator, "sql={s} binds=[", .{sql});
    for (statement.binds, 0..) |bind, index| {
        if (index != 0) try output.appendSlice(allocator, ",");
        try appendBindSummary(&output, allocator, bind);
    }
    try output.append(allocator, ']');
    return output.toOwnedSlice(allocator);
}

pub fn rowJsonAlloc(allocator: std.mem.Allocator, row: Row) std.mem.Allocator.Error![]const u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);

    try output.append(allocator, '{');
    for (row.fields, 0..) |field, index| {
        if (index != 0) try output.append(allocator, ',');
        const field_name = if (Secrets.containsSecret(field.name)) Secrets.redacted else field.name;
        try appendJsonString(&output, allocator, field_name);
        try output.append(allocator, ':');
        try appendSqlValueJson(&output, allocator, field.value);
    }
    try output.append(allocator, '}');
    return output.toOwnedSlice(allocator);
}

pub fn resultJsonArrayAlloc(allocator: std.mem.Allocator, result: QueryResult) std.mem.Allocator.Error![]const u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);

    try output.append(allocator, '[');
    for (result.rows, 0..) |row, index| {
        if (index != 0) try output.append(allocator, ',');
        const row_json = try rowJsonAlloc(allocator, row);
        defer allocator.free(row_json);
        try output.appendSlice(allocator, row_json);
    }
    try output.append(allocator, ']');
    return output.toOwnedSlice(allocator);
}

pub fn RowDecodeResult(comptime Output: type) type {
    return struct {
        allocator: std.mem.Allocator,
        row_index: usize,
        source_json: []const u8,
        decoded: Schema.DecodeResult(Output),

        pub fn deinit(self: *@This()) void {
            self.decoded.deinit();
            self.allocator.free(self.source_json);
            self.* = undefined;
        }
    };
}

pub fn TypedRows(comptime Output: type) type {
    return struct {
        allocator: std.mem.Allocator,
        rows: []RowDecodeResult(Output),
        issues: Schema.IssueList,

        pub fn ok(self: *const @This()) bool {
            if (self.issues.len() != 0) return false;
            for (self.rows) |row| {
                if (!row.decoded.ok()) return false;
            }
            return true;
        }

        pub fn deinit(self: *@This()) void {
            for (self.rows) |*row| row.deinit();
            self.allocator.free(self.rows);
            self.issues.deinit();
            self.* = undefined;
        }
    };
}

pub fn TypedQuery(comptime RowSchema: type) type {
    return struct {
        const Self = @This();
        pub const Output = RowSchema.Output;

        statement: Statement,
        row_schema: RowSchema,

        pub fn decodeRowsDetailedAlloc(self: Self, allocator: std.mem.Allocator, result: QueryResult) !TypedRows(Output) {
            const rows = try allocator.alloc(RowDecodeResult(Output), result.rows.len);
            errdefer allocator.free(rows);

            var issues = Schema.IssueList.init(allocator);
            errdefer issues.deinit();

            var initialized: usize = 0;
            errdefer {
                for (rows[0..initialized]) |*row| row.deinit();
            }

            for (result.rows, 0..) |row, index| {
                const source_json = try rowJsonAlloc(allocator, row);
                errdefer allocator.free(source_json);
                var decoded = try Schema.decodeDetailedJsonAlloc(allocator, self.row_schema, source_json);
                errdefer decoded.deinit();

                if (!decoded.ok()) {
                    try appendIndexedIssues(allocator, &issues, index, decoded.issues);
                }

                rows[index] = .{
                    .allocator = allocator,
                    .row_index = index,
                    .source_json = source_json,
                    .decoded = decoded,
                };
                initialized += 1;
            }

            return .{
                .allocator = allocator,
                .rows = rows,
                .issues = issues,
            };
        }
    };
}

pub fn typedQuery(statement: Statement, row_schema: anytype) TypedQuery(@TypeOf(row_schema)) {
    return .{
        .statement = statement,
        .row_schema = row_schema,
    };
}

fn appendIndexedIssues(
    allocator: std.mem.Allocator,
    target: *Schema.IssueList,
    row_index: usize,
    issues: Schema.IssueList,
) std.mem.Allocator.Error!void {
    for (issues.items.items) |issue| {
        var path: std.ArrayList(u8) = .empty;
        defer path.deinit(allocator);
        try path.print(allocator, "$[{d}]", .{row_index});
        if (issue.path.len > 1 and issue.path[0] == '$') {
            try path.appendSlice(allocator, issue.path[1..]);
        } else if (issue.path.len != 0 and !std.mem.eql(u8, issue.path, "$")) {
            try path.append(allocator, '.');
            try path.appendSlice(allocator, issue.path);
        }

        try target.add(.{
            .path = path.items,
            .kind = issue.kind,
            .expected = issue.expected,
            .actual = issue.actual,
            .message = issue.message,
        });
    }
}

fn appendSqlValueJson(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: Value) std.mem.Allocator.Error!void {
    switch (value) {
        .null_value => try output.appendSlice(allocator, "null"),
        .integer => |inner| try output.print(allocator, "{d}", .{inner}),
        .float => |inner| try output.print(allocator, "{d}", .{inner}),
        .boolean => |inner| try output.appendSlice(allocator, if (inner) "true" else "false"),
        .text => |inner| {
            const redacted = try Secrets.redactAlloc(allocator, inner);
            defer allocator.free(redacted);
            try appendJsonString(output, allocator, redacted);
        },
        .bytes => |inner| {
            try output.appendSlice(allocator, "\"");
            try output.print(allocator, "{x}", .{inner});
            try output.appendSlice(allocator, "\"");
        },
        .timestamp, .decimal => |inner| try appendJsonString(output, allocator, inner),
        .text_array => |items| {
            try output.append(allocator, '[');
            for (items, 0..) |item, index| {
                if (index != 0) try output.append(allocator, ',');
                const redacted = try Secrets.redactAlloc(allocator, item);
                defer allocator.free(redacted);
                try appendJsonString(output, allocator, redacted);
            }
            try output.append(allocator, ']');
        },
    }
}

fn appendJsonString(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: []const u8) std.mem.Allocator.Error!void {
    const escaped = try Json.escapeStringAlloc(allocator, value);
    defer allocator.free(escaped);
    try output.print(allocator, "\"{s}\"", .{escaped});
}

fn appendBindSummary(output: *std.ArrayList(u8), allocator: std.mem.Allocator, bind: Value) std.mem.Allocator.Error!void {
    switch (bind) {
        .null_value => try output.appendSlice(allocator, "null"),
        .integer => try output.appendSlice(allocator, "integer"),
        .float => try output.appendSlice(allocator, "float"),
        .boolean => try output.appendSlice(allocator, "boolean"),
        .text => |inner| {
            const redacted = try Secrets.redactAlloc(allocator, inner);
            defer allocator.free(redacted);
            if (std.mem.eql(u8, redacted, Secrets.redacted)) {
                try output.appendSlice(allocator, "text:[REDACTED]");
            } else {
                try output.appendSlice(allocator, "text");
            }
        },
        .bytes => try output.appendSlice(allocator, "bytes"),
        .timestamp => try output.appendSlice(allocator, "timestamp"),
        .decimal => try output.appendSlice(allocator, "decimal"),
        .text_array => try output.appendSlice(allocator, "text_array"),
    }
}

pub const PoolStats = struct {
    capacity: usize,
    checked_out: usize,
    available: usize,
};

pub fn poolStatsJsonAlloc(allocator: std.mem.Allocator, stats: PoolStats) std.mem.Allocator.Error![]const u8 {
    const capacity = try std.fmt.allocPrint(allocator, "{d}", .{stats.capacity});
    defer allocator.free(capacity);
    const checked_out = try std.fmt.allocPrint(allocator, "{d}", .{stats.checked_out});
    defer allocator.free(checked_out);
    const available = try std.fmt.allocPrint(allocator, "{d}", .{stats.available});
    defer allocator.free(available);

    return Json.objectFromFieldsAlloc(allocator, &.{
        .{ .name = "capacity", .value = capacity },
        .{ .name = "checked_out", .value = checked_out },
        .{ .name = "available", .value = available },
    });
}

pub fn Pool(comptime Database: type) type {
    return struct {
        const Self = @This();

        pub const Lease = struct {
            pool: *Self,
            database: *Database,
            released: bool = false,

            pub fn release(self: *@This()) error{PoolReleaseWithoutCheckout}!void {
                if (self.released) return;
                try self.pool.release();
                self.released = true;
            }

            pub fn deinit(self: *@This()) void {
                if (!self.released) self.release() catch {};
            }
        };

        database: *Database,
        capacity: usize,
        checked_out: usize = 0,

        pub fn init(database: *Database, capacity: usize) Self {
            return .{ .database = database, .capacity = capacity };
        }

        pub fn checkout(self: *Self) error{PoolExhausted}!*Database {
            if (self.checked_out >= self.capacity) return error.PoolExhausted;
            self.checked_out += 1;
            return self.database;
        }

        pub fn checkoutLease(self: *Self) error{PoolExhausted}!Lease {
            return .{
                .pool = self,
                .database = try self.checkout(),
            };
        }

        pub fn release(self: *Self) error{PoolReleaseWithoutCheckout}!void {
            if (self.checked_out == 0) return error.PoolReleaseWithoutCheckout;
            self.checked_out -= 1;
        }

        pub fn stats(self: *const Self) PoolStats {
            return .{
                .capacity = self.capacity,
                .checked_out = self.checked_out,
                .available = self.capacity - self.checked_out,
            };
        }
    };
}

pub fn TransactionRun(comptime Result: type) type {
    return struct {
        allocator: std.mem.Allocator,
        result: ?Result,
        status: []const u8,
        failure: ?[]const u8,
        receipt_json: []const u8,

        pub fn deinit(self: *@This()) void {
            self.allocator.free(self.status);
            if (self.failure) |failure| self.allocator.free(failure);
            self.allocator.free(self.receipt_json);
            self.* = undefined;
        }
    };
}

pub fn runTransactionAlloc(
    allocator: std.mem.Allocator,
    comptime Result: type,
    database: anytype,
    operation: []const u8,
    handler: anytype,
) std.mem.Allocator.Error!TransactionRun(Result) {
    database.begin() catch |err| {
        return transactionRunAlloc(allocator, Result, null, "begin_failed", @errorName(err), operation);
    };

    const value = handler.run(database) catch |err| {
        database.rollback() catch |rollback_err| {
            return transactionRunAlloc(allocator, Result, null, "rollback_failed", @errorName(rollback_err), operation);
        };
        return transactionRunAlloc(allocator, Result, null, "rolled_back", @errorName(err), operation);
    };

    database.commit() catch |err| {
        database.rollback() catch {};
        return transactionRunAlloc(allocator, Result, null, "commit_failed", @errorName(err), operation);
    };

    return transactionRunAlloc(allocator, Result, value, "committed", null, operation);
}

fn transactionRunAlloc(
    allocator: std.mem.Allocator,
    comptime Result: type,
    result: ?Result,
    status: []const u8,
    failure: ?[]const u8,
    operation: []const u8,
) std.mem.Allocator.Error!TransactionRun(Result) {
    const owned_status = try allocator.dupe(u8, status);
    errdefer allocator.free(owned_status);
    const owned_failure = if (failure) |value| try allocator.dupe(u8, value) else null;
    errdefer if (owned_failure) |value| allocator.free(value);
    const receipt_json = try transactionReceiptJsonAlloc(allocator, operation, status, failure);
    return .{
        .allocator = allocator,
        .result = result,
        .status = owned_status,
        .failure = owned_failure,
        .receipt_json = receipt_json,
    };
}

fn transactionReceiptJsonAlloc(
    allocator: std.mem.Allocator,
    operation: []const u8,
    status: []const u8,
    failure: ?[]const u8,
) std.mem.Allocator.Error![]const u8 {
    return Json.objectFromFieldsAlloc(allocator, &.{
        .{ .name = "kind", .value = "sql.transaction" },
        .{ .name = "operation", .value = operation },
        .{ .name = "status", .value = status },
        .{ .name = "failure", .value = failure orelse "" },
    });
}

pub fn QueryEffect(comptime EffectEnv: type, comptime Database: type) type {
    return struct {
        pub const SuccessType = QueryResult;
        pub const FailureType = anyerror;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{Database};

        statement: Statement,

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(self: @This(), ctx: *fx.Context(EffectEnv)) FailureType!QueryResult {
            const database = ctx.service(Database);
            const detail = redactStatementAlloc(ctx.allocator, self.statement) catch |err| {
                _ = StdService.recordOperation(ctx, Database, "sql.query", "failure", @errorName(err));
                return err;
            };
            defer ctx.allocator.free(detail);

            const result = database.queryAlloc(ctx.allocator, self.statement) catch |err| {
                _ = StdService.recordOperation(ctx, Database, "sql.query", "failure", detail);
                return err;
            };
            _ = StdService.recordOperation(ctx, Database, "sql.query", "success", detail);
            return result;
        }
    };
}

pub fn QueryClassifiedEffect(comptime EffectEnv: type, comptime Database: type) type {
    return struct {
        pub const SuccessType = External.Result(QueryResult);
        pub const FailureType = error{};
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{Database};

        statement: Statement,

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(self: @This(), ctx: *fx.Context(EffectEnv)) FailureType!SuccessType {
            const database = ctx.service(Database);
            const result = database.queryClassifiedAlloc(ctx.allocator, self.statement);
            switch (result) {
                .success => {
                    _ = StdService.recordOperation(ctx, Database, "sql.query", "success", "classified");
                },
                .failure => |failure| {
                    _ = StdService.recordOperation(ctx, Database, "sql.query", @tagName(failure.class), failure.detail);
                },
            }
            return result;
        }
    };
}

pub fn queryClassifiedEffect(comptime EffectEnv: type, comptime Database: type, statement: Statement) QueryClassifiedEffect(EffectEnv, Database) {
    return .{ .statement = statement };
}

pub fn CheckoutEffect(comptime EffectEnv: type, comptime Database: type) type {
    const SqlPool = Pool(Database);
    return struct {
        pub const SuccessType = *Database;
        pub const FailureType = error{PoolExhausted};
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{SqlPool};

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(_: @This(), ctx: *fx.Context(EffectEnv)) FailureType!*Database {
            const pool = ctx.service(SqlPool);
            const database = pool.checkout() catch |err| {
                _ = StdService.recordOperation(ctx, SqlPool, "sql.checkout", "failure", @errorName(err));
                return err;
            };
            _ = StdService.recordOperation(ctx, SqlPool, "sql.checkout", "success", @typeName(Database));
            return database;
        }
    };
}

pub fn ReleaseEffect(comptime EffectEnv: type, comptime Database: type) type {
    const SqlPool = Pool(Database);
    return struct {
        pub const SuccessType = void;
        pub const FailureType = error{PoolReleaseWithoutCheckout};
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{SqlPool};

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(_: @This(), ctx: *fx.Context(EffectEnv)) FailureType!void {
            const pool = ctx.service(SqlPool);
            pool.release() catch |err| {
                _ = StdService.recordOperation(ctx, SqlPool, "sql.release", "failure", @errorName(err));
                return err;
            };
            _ = StdService.recordOperation(ctx, SqlPool, "sql.release", "success", @typeName(Database));
        }
    };
}

pub fn BeginEffect(comptime EffectEnv: type, comptime Database: type) type {
    const SqlPool = Pool(Database);
    return struct {
        pub const SuccessType = void;
        pub const FailureType = anyerror;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{SqlPool};

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(_: @This(), ctx: *fx.Context(EffectEnv)) FailureType!void {
            const pool = ctx.service(SqlPool);
            pool.database.begin() catch |err| {
                _ = StdService.recordOperation(ctx, SqlPool, "sql.begin", "failure", @errorName(err));
                return err;
            };
            _ = StdService.recordOperation(ctx, SqlPool, "sql.begin", "success", @typeName(Database));
        }
    };
}

pub fn CommitEffect(comptime EffectEnv: type, comptime Database: type) type {
    const SqlPool = Pool(Database);
    return struct {
        pub const SuccessType = void;
        pub const FailureType = anyerror;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{SqlPool};

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(_: @This(), ctx: *fx.Context(EffectEnv)) FailureType!void {
            const pool = ctx.service(SqlPool);
            pool.database.commit() catch |err| {
                _ = StdService.recordOperation(ctx, SqlPool, "sql.commit", "failure", @errorName(err));
                return err;
            };
            _ = StdService.recordOperation(ctx, SqlPool, "sql.commit", "success", @typeName(Database));
        }
    };
}

pub fn RollbackEffect(comptime EffectEnv: type, comptime Database: type) type {
    const SqlPool = Pool(Database);
    return struct {
        pub const SuccessType = void;
        pub const FailureType = anyerror;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{SqlPool};

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(_: @This(), ctx: *fx.Context(EffectEnv)) FailureType!void {
            const pool = ctx.service(SqlPool);
            pool.database.rollback() catch |err| {
                _ = StdService.recordOperation(ctx, SqlPool, "sql.rollback", "failure", @errorName(err));
                return err;
            };
            _ = StdService.recordOperation(ctx, SqlPool, "sql.rollback", "success", @typeName(Database));
        }
    };
}

pub fn MigrateEffect(comptime EffectEnv: type, comptime Database: type) type {
    const SqlPool = Pool(Database);
    return struct {
        pub const SuccessType = void;
        pub const FailureType = anyerror;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{SqlPool};

        migrations: []const Migration,

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(self: @This(), ctx: *fx.Context(EffectEnv)) FailureType!void {
            const pool = ctx.service(SqlPool);
            pool.database.migrateAlloc(ctx.allocator, self.migrations) catch |err| {
                _ = StdService.recordOperation(ctx, SqlPool, "sql.migrate", "failure", @errorName(err));
                return err;
            };
            _ = StdService.recordOperation(ctx, SqlPool, "sql.migrate", "success", @typeName(Database));
        }
    };
}

pub fn queryEffect(comptime EffectEnv: type, comptime Database: type, statement: Statement) QueryEffect(EffectEnv, Database) {
    return .{ .statement = statement };
}

pub fn checkoutEffect(comptime EffectEnv: type, comptime Database: type) CheckoutEffect(EffectEnv, Database) {
    return .{};
}

pub fn releaseEffect(comptime EffectEnv: type, comptime Database: type) ReleaseEffect(EffectEnv, Database) {
    return .{};
}

pub fn beginEffect(comptime EffectEnv: type, comptime Database: type) BeginEffect(EffectEnv, Database) {
    return .{};
}

pub fn commitEffect(comptime EffectEnv: type, comptime Database: type) CommitEffect(EffectEnv, Database) {
    return .{};
}

pub fn rollbackEffect(comptime EffectEnv: type, comptime Database: type) RollbackEffect(EffectEnv, Database) {
    return .{};
}

pub fn migrateEffect(comptime EffectEnv: type, comptime Database: type, migrations: []const Migration) MigrateEffect(EffectEnv, Database) {
    return .{ .migrations = migrations };
}

test "Sql fake database returns deterministic rows" {
    const fields = [_]Field{
        .{ .name = "id", .value = .{ .integer = 42 } },
        .{ .name = "name", .value = .{ .text = "local" } },
    };
    const rows = [_]Row{
        .{ .fields = fields[0..] },
    };
    const database = FakeDatabase.init(.{ .rows = rows[0..] });

    const result = database.query("select * from projects", &.{});

    try std.testing.expectEqual(@as(usize, 1), result.rows.len);
    try std.testing.expectEqual(@as(i64, 42), result.rows[0].fields[0].value.integer);
    try std.testing.expectEqualStrings("local", result.rows[0].fields[1].value.text);
}

test "Sql fake database cannot satisfy a production database requirement" {
    try FakeDatabase.capability.validate();
    try std.testing.expectEqual(
        Capability.Match.insufficient_maturity,
        Capability.match(FakeDatabase.capability, .{
            .kind = .sql_database,
            .minimum_maturity = .production_candidate,
            .requires_live_conformance = true,
        }),
    );
}

test "Sql fake database supports the classified query contract" {
    var database = FakeDatabase.init(.{ .rows = &.{} });
    var result = database.queryClassifiedAlloc(std.testing.allocator, .{ .sql = "select 1" });
    switch (result) {
        .success => |*rows| rows.deinit(std.testing.allocator),
        .failure => return error.TestUnexpectedFailure,
    }
}

test "Sql classified effect keeps failures in the success channel" {
    var database = FakeDatabase.init(.{ .rows = &.{} });
    const zstd = @import("../root.zig");
    var services = zstd.Service.Provider(.{FakeDatabase}).init(.{&database});
    var runtime = zstd.fx.Runtime(@TypeOf(services)).init(std.testing.allocator, &services).provides(.{FakeDatabase});
    var result = try runtime.run(queryClassifiedEffect(@TypeOf(services), FakeDatabase, .{ .sql = "select 1" }));
    switch (result) {
        .success => |*rows| rows.deinit(std.testing.allocator),
        .failure => return error.TestUnexpectedFailure,
    }
}

test "Sql redacts connection metadata" {
    const display = try redactConnectionAlloc(std.testing.allocator, "postgres://user:pass@localhost/db");
    defer std.testing.allocator.free(display);

    try std.testing.expectEqualStrings("[REDACTED]", display);
}

test "Sql queryEffect uses database services and records redacted causal facts" {
    const zstd = @import("../root.zig");

    const fields = [_]Field{
        .{ .name = "id", .value = .{ .integer = 42 } },
    };
    const rows = [_]Row{.{ .fields = fields[0..] }};
    var database = try FakeDatabase.initOwned(std.testing.allocator, .{ .rows = rows[0..] });
    defer database.deinit();

    var provider = zstd.Service.Provider(.{FakeDatabase}).init(.{&database});
    var store = zstd.fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var runtime = zstd.fx.Runtime(@TypeOf(provider)).init(std.testing.allocator, &provider)
        .provides(.{FakeDatabase})
        .withCausalStore(&store);

    var result = try runtime.run(queryEffect(@TypeOf(provider), FakeDatabase, .{
        .sql = "select * from projects where token = $1",
        .binds = &.{.{ .text = "token=abc123" }},
    }));
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), result.rows.len);
    try std.testing.expectEqual(@as(i64, 42), result.rows[0].fields[0].value.integer);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    const event_index = zstd.Service.findOperation(snapshot, FakeDatabase, "sql.query", "success");
    try std.testing.expect(event_index != null);
    try std.testing.expect(std.mem.indexOf(u8, snapshot.events[event_index.?].redacted_detail, "abc123") == null);
}

test "Sql transactions migrations and pool service record lifecycle facts" {
    const zstd = @import("../root.zig");

    var database = try FakeDatabase.initOwned(std.testing.allocator, .{ .rows = &.{} });
    defer database.deinit();
    var pool = Pool(FakeDatabase).init(&database, 2);

    var provider = zstd.Service.Provider(.{Pool(FakeDatabase)}).init(.{&pool});
    var store = zstd.fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var runtime = zstd.fx.Runtime(@TypeOf(provider)).init(std.testing.allocator, &provider)
        .provides(.{Pool(FakeDatabase)})
        .withCausalStore(&store);

    const checkout = try runtime.run(checkoutEffect(@TypeOf(provider), FakeDatabase));
    try std.testing.expect(checkout == &database);
    try runtime.run(releaseEffect(@TypeOf(provider), FakeDatabase));
    try runtime.run(beginEffect(@TypeOf(provider), FakeDatabase));
    try runtime.run(commitEffect(@TypeOf(provider), FakeDatabase));

    const migrations = [_]Migration{
        .{ .id = "001", .sql = "create table projects(id int)" },
    };
    try runtime.run(migrateEffect(@TypeOf(provider), FakeDatabase, migrations[0..]));

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expect(zstd.Service.hasOperation(snapshot, Pool(FakeDatabase), "sql.checkout", "success"));
    try std.testing.expect(zstd.Service.hasOperation(snapshot, Pool(FakeDatabase), "sql.release", "success"));
    try std.testing.expect(zstd.Service.hasOperation(snapshot, Pool(FakeDatabase), "sql.begin", "success"));
    try std.testing.expect(zstd.Service.hasOperation(snapshot, Pool(FakeDatabase), "sql.commit", "success"));
    try std.testing.expect(zstd.Service.hasOperation(snapshot, Pool(FakeDatabase), "sql.migrate", "success"));
}

test "Sql typed query decodes rows through Schema and redacts row JSON" {
    const zstd = @import("../root.zig");
    const ProjectRow = struct {
        id: i64,
        name: []const u8,
        active: bool,
    };

    const fields = [_]Field{
        .{ .name = "id", .value = .{ .integer = 42 } },
        .{ .name = "name", .value = .{ .text = "local-project" } },
        .{ .name = "active", .value = .{ .boolean = true } },
        .{ .name = "secret", .value = .{ .text = "token=abc123" } },
    };
    const rows = [_]Row{.{ .fields = fields[0..] }};
    const result = QueryResult{ .rows = rows[0..] };

    const row_json = try rowJsonAlloc(std.testing.allocator, rows[0]);
    defer std.testing.allocator.free(row_json);
    try std.testing.expect(std.mem.indexOf(u8, row_json, "\"id\":42") != null);
    try std.testing.expect(std.mem.indexOf(u8, row_json, "abc123") == null);
    try std.testing.expect(std.mem.indexOf(u8, row_json, "[REDACTED]") != null);

    const schema = zstd.Schema.derive(ProjectRow, .{
        .id = zstd.Schema.integer().min(1),
        .name = zstd.Schema.string().nonEmpty(),
        .active = zstd.Schema.boolean(),
    });
    const query = typedQuery(.{
        .sql = "select id, name, active from projects where token = $1",
        .binds = &.{.{ .text = "token=abc123" }},
    }, schema);

    var decoded = try query.decodeRowsDetailedAlloc(std.testing.allocator, result);
    defer decoded.deinit();

    try std.testing.expect(decoded.ok());
    try std.testing.expectEqual(@as(usize, 1), decoded.rows.len);
    try std.testing.expectEqual(@as(i64, 42), decoded.rows[0].decoded.value.?.id);
    try std.testing.expectEqualStrings("local-project", decoded.rows[0].decoded.value.?.name);
}

test "Sql typed query reports indexed Schema errors without leaking row secrets" {
    const zstd = @import("../root.zig");
    const ProjectRow = struct {
        id: i64,
        name: []const u8,
    };

    const fields = [_]Field{
        .{ .name = "id", .value = .{ .text = "not-an-int" } },
        .{ .name = "name", .value = .{ .text = "token=abc123" } },
    };
    const rows = [_]Row{.{ .fields = fields[0..] }};
    const result = QueryResult{ .rows = rows[0..] };
    const schema = zstd.Schema.derive(ProjectRow, .{
        .id = zstd.Schema.integer(),
        .name = zstd.Schema.string().nonEmpty(),
    });

    var decoded = try typedQuery(.{ .sql = "select id, name from projects", .binds = &.{} }, schema)
        .decodeRowsDetailedAlloc(std.testing.allocator, result);
    defer decoded.deinit();

    try std.testing.expect(!decoded.ok());
    try std.testing.expectEqual(@as(usize, 1), decoded.issues.len());
    try std.testing.expectEqualStrings("$[0].id", decoded.issues.items.items[0].path);

    const issues_json = try decoded.issues.jsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(issues_json);
    try std.testing.expect(std.mem.indexOf(u8, issues_json, "abc123") == null);
}

test "Sql pool leases expose deterministic lifecycle stats" {
    var database = try FakeDatabase.initOwned(std.testing.allocator, .{ .rows = &.{} });
    defer database.deinit();
    var pool = Pool(FakeDatabase).init(&database, 1);

    var lease = try pool.checkoutLease();
    try std.testing.expect(lease.database == &database);
    try std.testing.expectEqual(@as(usize, 1), pool.stats().checked_out);
    try std.testing.expectEqual(@as(usize, 0), pool.stats().available);
    try std.testing.expectError(error.PoolExhausted, pool.checkoutLease());

    const stats_json = try poolStatsJsonAlloc(std.testing.allocator, pool.stats());
    defer std.testing.allocator.free(stats_json);
    try std.testing.expect(std.mem.indexOf(u8, stats_json, "\"capacity\":\"1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, stats_json, "\"checked_out\":\"1\"") != null);

    try lease.release();
    try std.testing.expectEqual(@as(usize, 0), pool.stats().checked_out);
    lease.deinit();
}

test "Sql transaction helper returns committed and rolled back receipts" {
    const Success = struct {
        pub fn run(_: @This(), _: *FakeDatabase) anyerror!usize {
            return 7;
        }
    };
    const Failure = struct {
        pub fn run(_: @This(), _: *FakeDatabase) anyerror!void {
            return error.IntentionalFailure;
        }
    };

    var database = try FakeDatabase.initOwned(std.testing.allocator, .{ .rows = &.{} });
    defer database.deinit();

    var committed = try runTransactionAlloc(
        std.testing.allocator,
        usize,
        &database,
        "create-project token=abc123",
        Success{},
    );
    defer committed.deinit();
    try std.testing.expectEqual(@as(?usize, 7), committed.result);
    try std.testing.expectEqualStrings("committed", committed.status);
    try std.testing.expect(std.mem.indexOf(u8, committed.receipt_json, "abc123") == null);

    var rolled_back = try runTransactionAlloc(
        std.testing.allocator,
        void,
        &database,
        "drop-project password=hunter2",
        Failure{},
    );
    defer rolled_back.deinit();
    try std.testing.expect(rolled_back.result == null);
    try std.testing.expectEqualStrings("rolled_back", rolled_back.status);
    try std.testing.expectEqualStrings("IntentionalFailure", rolled_back.failure.?);
    try std.testing.expect(!database.in_transaction);
    try std.testing.expect(std.mem.indexOf(u8, rolled_back.receipt_json, "hunter2") == null);
}
