const std = @import("std");
const Secrets = @import("../secrets/root.zig");
const StdService = @import("../service/root.zig");
const fx = @import("zigeffect");

pub const Value = union(enum) {
    null_value,
    text: []const u8,
    integer: i64,
    boolean: bool,

    pub fn cloneAlloc(self: Value, allocator: std.mem.Allocator) std.mem.Allocator.Error!Value {
        return switch (self) {
            .null_value => .null_value,
            .text => |value| .{ .text = try allocator.dupe(u8, value) },
            .integer => |value| .{ .integer = value },
            .boolean => |value| .{ .boolean = value },
        };
    }

    pub fn deinit(self: *Value, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .text => |value| allocator.free(value),
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

pub const Statement = struct {
    sql: []const u8,
    binds: []const Value = &.{},
};

pub const Migration = struct {
    id: []const u8,
    sql: []const u8,
};

pub const FakeDatabase = struct {
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
    return std.fmt.allocPrint(allocator, "{s} binds={d}", .{ sql, statement.binds.len });
}

pub fn Pool(comptime Database: type) type {
    return struct {
        const Self = @This();

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

        pub fn release(self: *Self) error{PoolReleaseWithoutCheckout}!void {
            if (self.checked_out == 0) return error.PoolReleaseWithoutCheckout;
            self.checked_out -= 1;
        }
    };
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
