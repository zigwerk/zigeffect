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
        pub fn pull(self: *@This(), _: *fx.Context(Stream.EmptyEnv), output_allocator: std.mem.Allocator, max: usize) anyerror!fx.EffectStream(Row, anyerror, Stream.EmptyEnv).Chunk {
            const count = @min(max, self.result.rows.len - self.offset);
            const rows = try output_allocator.alloc(Row, count);
            @memcpy(rows, self.result.rows[self.offset .. self.offset + count]);
            self.offset += count;
            return .{ .allocator = output_allocator, .items = rows, .end = self.offset == self.result.rows.len };
        }
        pub fn close(self: *@This(), _: fx.StreamCloseReason) void {
            self.closed = true;
        }
        pub fn deinit(self: *@This()) void {
            self.result.deinit(self.allocator);
        }
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

pub fn Pool(comptime DatabaseImplementation: type) type {
    return struct {
        const Self = @This();

        pub const Lease = struct {
            pool: *Self,
            database: *DatabaseImplementation,
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

        database: *DatabaseImplementation,
        capacity: usize,
        checked_out: usize = 0,

        pub fn init(database: *DatabaseImplementation, capacity: usize) Self {
            return .{ .database = database, .capacity = capacity };
        }

        pub fn checkout(self: *Self) error{PoolExhausted}!*DatabaseImplementation {
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

pub const DatabaseApi = struct {
    pub const operations: []const []const u8 = &.{
        "Sql.query",
        "Sql.queryClassified",
        "Sql.begin",
        "Sql.commit",
        "Sql.rollback",
        "Sql.migrate",
    };

    state: *anyopaque,
    query_alloc_fn: *const fn (*anyopaque, std.mem.Allocator, Statement) anyerror!QueryResult,
    query_classified_fn: *const fn (*anyopaque, std.mem.Allocator, Statement) External.Result(QueryResult),
    begin_fn: *const fn (*anyopaque) anyerror!void,
    commit_fn: *const fn (*anyopaque) anyerror!void,
    rollback_fn: *const fn (*anyopaque) anyerror!void,
    migrate_fn: *const fn (*anyopaque, std.mem.Allocator, []const Migration) anyerror!void,

    pub fn from(comptime Implementation: type, implementation: *Implementation) DatabaseApi {
        return .{
            .state = implementation,
            .query_alloc_fn = struct {
                fn call(raw: *anyopaque, allocator: std.mem.Allocator, statement: Statement) anyerror!QueryResult {
                    return (@as(*Implementation, @ptrCast(@alignCast(raw)))).queryAlloc(allocator, statement);
                }
            }.call,
            .query_classified_fn = struct {
                fn call(raw: *anyopaque, allocator: std.mem.Allocator, statement: Statement) External.Result(QueryResult) {
                    const typed: *Implementation = @ptrCast(@alignCast(raw));
                    if (comptime @hasDecl(Implementation, "queryClassifiedAlloc")) return typed.queryClassifiedAlloc(allocator, statement);
                    const result = typed.queryAlloc(allocator, statement) catch |failure| {
                        return .{ .failure = External.Failure.fromError("sql", "query", failure) };
                    };
                    return .{ .success = result };
                }
            }.call,
            .begin_fn = operationFn(Implementation, "begin"),
            .commit_fn = operationFn(Implementation, "commit"),
            .rollback_fn = operationFn(Implementation, "rollback"),
            .migrate_fn = struct {
                fn call(raw: *anyopaque, allocator: std.mem.Allocator, migrations: []const Migration) anyerror!void {
                    const typed: *Implementation = @ptrCast(@alignCast(raw));
                    if (comptime @hasDecl(Implementation, "migrateAlloc")) return typed.migrateAlloc(allocator, migrations);
                    return error.UnsupportedSqlOperation;
                }
            }.call,
        };
    }

    fn operationFn(comptime Implementation: type, comptime name: []const u8) *const fn (*anyopaque) anyerror!void {
        return struct {
            fn call(raw: *anyopaque) anyerror!void {
                const typed: *Implementation = @ptrCast(@alignCast(raw));
                if (comptime @hasDecl(Implementation, name)) return @call(.auto, @field(Implementation, name), .{typed});
                return error.UnsupportedSqlOperation;
            }
        }.call;
    }

    pub fn queryAlloc(self: DatabaseApi, allocator: std.mem.Allocator, statement: Statement) anyerror!QueryResult {
        return self.query_alloc_fn(self.state, allocator, statement);
    }
    pub fn queryClassifiedAlloc(self: DatabaseApi, allocator: std.mem.Allocator, statement: Statement) External.Result(QueryResult) {
        return self.query_classified_fn(self.state, allocator, statement);
    }
    pub fn begin(self: DatabaseApi) anyerror!void {
        return self.begin_fn(self.state);
    }
    pub fn commit(self: DatabaseApi) anyerror!void {
        return self.commit_fn(self.state);
    }
    pub fn rollback(self: DatabaseApi) anyerror!void {
        return self.rollback_fn(self.state);
    }
    pub fn migrate(self: DatabaseApi, allocator: std.mem.Allocator, migrations: []const Migration) anyerror!void {
        return self.migrate_fn(self.state, allocator, migrations);
    }
};

pub const Database = fx.kernel.Service("zigeffect/std/SqlDatabase", DatabaseApi);

pub fn databaseLayer(comptime Implementation: type, implementation: *Implementation) @TypeOf(
    fx.kernel.Layer.succeed(Database, DatabaseApi.from(Implementation, implementation)),
) {
    return fx.kernel.Layer.succeed(Database, DatabaseApi.from(Implementation, implementation));
}

pub const PoolApi = struct {
    pub const operations: []const []const u8 = &.{ "SqlPool.checkout", "SqlPool.release", "SqlPool.stats" };
    state: *anyopaque,
    checkout_fn: *const fn (*anyopaque) anyerror!DatabaseApi,
    release_fn: *const fn (*anyopaque) anyerror!void,
    stats_fn: *const fn (*anyopaque) PoolStats,

    pub fn from(comptime Implementation: type, pool: *Pool(Implementation)) PoolApi {
        return .{
            .state = pool,
            .checkout_fn = struct {
                fn call(raw: *anyopaque) anyerror!DatabaseApi {
                    const typed: *Pool(Implementation) = @ptrCast(@alignCast(raw));
                    return DatabaseApi.from(Implementation, try typed.checkout());
                }
            }.call,
            .release_fn = struct {
                fn call(raw: *anyopaque) anyerror!void {
                    return (@as(*Pool(Implementation), @ptrCast(@alignCast(raw)))).release();
                }
            }.call,
            .stats_fn = struct {
                fn call(raw: *anyopaque) PoolStats {
                    return (@as(*Pool(Implementation), @ptrCast(@alignCast(raw)))).stats();
                }
            }.call,
        };
    }

    pub fn checkout(self: PoolApi) anyerror!DatabaseApi {
        return self.checkout_fn(self.state);
    }
    pub fn release(self: PoolApi) anyerror!void {
        return self.release_fn(self.state);
    }
    pub fn stats(self: PoolApi) PoolStats {
        return self.stats_fn(self.state);
    }
};

pub const DatabasePool = fx.kernel.Service("zigeffect/std/SqlDatabasePool", PoolApi);

pub fn poolLayer(comptime Implementation: type, pool: *Pool(Implementation)) @TypeOf(
    fx.kernel.Layer.succeed(DatabasePool, PoolApi.from(Implementation, pool)),
) {
    return fx.kernel.Layer.succeed(DatabasePool, PoolApi.from(Implementation, pool));
}

pub fn query(statement: Statement) fx.kernel.Effect(QueryResult, anyerror, .{Database}).Stateful(Statement) {
    const Query = fx.kernel.Effect(QueryResult, anyerror, .{Database});
    return Query.fromState(Statement, statement, struct {
        fn run(value: Statement, ctx: *Query.Context) anyerror!QueryResult {
            const detail = try redactStatementAlloc(ctx.allocator(), value);
            defer ctx.allocator().free(detail);
            const operation = StdService.beginOperation(ctx, Database.service_key, "Sql.query", detail);
            const result = ctx.service(Database).queryAlloc(ctx.allocator(), value) catch |failure| {
                _ = StdService.completeOperation(ctx, operation, "failure", @errorName(failure));
                return failure;
            };
            _ = StdService.completeOperation(ctx, operation, "success", detail);
            return result;
        }
    }.run);
}

pub fn queryClassified(statement: Statement) fx.kernel.Effect(External.Result(QueryResult), error{}, .{Database}).Stateful(Statement) {
    const Query = fx.kernel.Effect(External.Result(QueryResult), error{}, .{Database});
    return Query.fromState(Statement, statement, struct {
        fn run(value: Statement, ctx: *Query.Context) error{}!External.Result(QueryResult) {
            const result = ctx.service(Database).queryClassifiedAlloc(ctx.allocator(), value);
            switch (result) {
                .success => _ = StdService.recordSemantic(ctx, .span_recorded, Database.service_key, "Sql.queryClassified", "success", "classified result"),
                .failure => |failure| _ = StdService.recordSemantic(ctx, .span_recorded, Database.service_key, "Sql.queryClassified", @tagName(failure.class), failure.detail),
            }
            return result;
        }
    }.run);
}

pub fn checkout() fx.kernel.Effect(DatabaseApi, anyerror, .{DatabasePool}) {
    return fx.kernel.Effect(DatabaseApi, anyerror, .{DatabasePool}).fromFn(struct {
        fn run(ctx: *fx.kernel.ContextView(.{DatabasePool})) anyerror!DatabaseApi {
            const database = ctx.service(DatabasePool).checkout() catch |failure| {
                _ = StdService.recordSemantic(ctx, .span_recorded, DatabasePool.service_key, "SqlPool.checkout", "failure", @errorName(failure));
                return failure;
            };
            _ = StdService.recordSemantic(ctx, .span_recorded, DatabasePool.service_key, "SqlPool.checkout", "success", "bounded lease");
            return database;
        }
    }.run);
}

pub fn release() fx.kernel.Effect(void, anyerror, .{DatabasePool}) {
    return fx.kernel.Effect(void, anyerror, .{DatabasePool}).fromFn(struct {
        fn run(ctx: *fx.kernel.ContextView(.{DatabasePool})) anyerror!void {
            ctx.service(DatabasePool).release() catch |failure| {
                _ = StdService.recordSemantic(ctx, .span_recorded, DatabasePool.service_key, "SqlPool.release", "failure", @errorName(failure));
                return failure;
            };
            _ = StdService.recordSemantic(ctx, .span_recorded, DatabasePool.service_key, "SqlPool.release", "success", "lease returned");
        }
    }.run);
}

const DatabaseOperation = enum { begin, commit, rollback };
fn databaseOperation(comptime operation: DatabaseOperation) fx.kernel.Effect(void, anyerror, .{Database}) {
    return fx.kernel.Effect(void, anyerror, .{Database}).fromFn(struct {
        fn run(ctx: *fx.kernel.ContextView(.{Database})) anyerror!void {
            const database = ctx.service(Database).*;
            const result = switch (operation) {
                .begin => database.begin(),
                .commit => database.commit(),
                .rollback => database.rollback(),
            };
            result catch |failure| {
                _ = StdService.recordSemantic(ctx, .span_recorded, Database.service_key, "Sql." ++ @tagName(operation), "failure", @errorName(failure));
                return failure;
            };
            _ = StdService.recordSemantic(ctx, .span_recorded, Database.service_key, "Sql." ++ @tagName(operation), "success", "transaction transition");
        }
    }.run);
}

pub fn begin() fx.kernel.Effect(void, anyerror, .{Database}) {
    return databaseOperation(.begin);
}
pub fn commit() fx.kernel.Effect(void, anyerror, .{Database}) {
    return databaseOperation(.commit);
}
pub fn rollback() fx.kernel.Effect(void, anyerror, .{Database}) {
    return databaseOperation(.rollback);
}

pub fn migrate(migrations: []const Migration) fx.kernel.Effect(void, anyerror, .{Database}).Stateful([]const Migration) {
    const Migrate = fx.kernel.Effect(void, anyerror, .{Database});
    return Migrate.fromState([]const Migration, migrations, struct {
        fn run(value: []const Migration, ctx: *Migrate.Context) anyerror!void {
            ctx.service(Database).migrate(ctx.allocator(), value) catch |failure| {
                _ = StdService.recordSemantic(ctx, .span_recorded, Database.service_key, "Sql.migrate", "failure", @errorName(failure));
                return failure;
            };
            _ = StdService.recordSemantic(ctx, .span_recorded, Database.service_key, "Sql.migrate", "success", "migrations applied");
        }
    }.run);
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
    const root = databaseLayer(FakeDatabase, &database);
    var runtime = try fx.kernel.ManagedRuntime(@TypeOf(root)).make(std.testing.allocator, root, .{});
    defer runtime.deinit();
    var result = try runtime.run(queryClassified(.{ .sql = "select 1" }));
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

test "Sql.query uses the database service and records redacted causal facts" {
    const fields = [_]Field{
        .{ .name = "id", .value = .{ .integer = 42 } },
    };
    const rows = [_]Row{.{ .fields = fields[0..] }};
    var database = try FakeDatabase.initOwned(std.testing.allocator, .{ .rows = rows[0..] });
    defer database.deinit();

    const root = databaseLayer(FakeDatabase, &database);
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    var runtime = try fx.kernel.ManagedRuntime(@TypeOf(root)).make(std.testing.allocator, root, .{ .causal_store = &store });
    defer runtime.deinit();

    var result = try runtime.run(query(.{
        .sql = "select * from projects where token = $1",
        .binds = &.{.{ .text = "token=abc123" }},
    }));
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), result.rows.len);
    try std.testing.expectEqual(@as(i64, 42), result.rows[0].fields[0].value.integer);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    var saw = false;
    for (snapshot.events) |event| {
        if (event.kind == .io_completed and std.mem.eql(u8, event.service_key, Database.service_key)) {
            saw = true;
            try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "abc123") == null);
        }
    }
    try std.testing.expect(saw);
}

test "Sql transactions migrations and pool service record lifecycle facts" {
    var database = try FakeDatabase.initOwned(std.testing.allocator, .{ .rows = &.{} });
    defer database.deinit();
    var pool = Pool(FakeDatabase).init(&database, 2);

    const root = fx.kernel.Layer.mergeAll(.{
        databaseLayer(FakeDatabase, &database),
        poolLayer(FakeDatabase, &pool),
    });
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    var runtime = try fx.kernel.ManagedRuntime(@TypeOf(root)).make(std.testing.allocator, root, .{ .causal_store = &store });
    defer runtime.deinit();

    _ = try runtime.run(checkout());
    try runtime.run(release());
    try runtime.run(begin());
    try runtime.run(commit());

    const migrations = [_]Migration{
        .{ .id = "001", .sql = "create table projects(id int)" },
    };
    try runtime.run(migrate(migrations[0..]));

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expect(StdService.hasOperation(snapshot, DatabasePool, "SqlPool.checkout", "success"));
    try std.testing.expect(StdService.hasOperation(snapshot, DatabasePool, "SqlPool.release", "success"));
    try std.testing.expect(StdService.hasOperation(snapshot, Database, "Sql.begin", "success"));
    try std.testing.expect(StdService.hasOperation(snapshot, Database, "Sql.commit", "success"));
    try std.testing.expect(StdService.hasOperation(snapshot, Database, "Sql.migrate", "success"));
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
    const typed_query = typedQuery(.{
        .sql = "select id, name, active from projects where token = $1",
        .binds = &.{.{ .text = "token=abc123" }},
    }, schema);

    var decoded = try typed_query.decodeRowsDetailedAlloc(std.testing.allocator, result);
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
