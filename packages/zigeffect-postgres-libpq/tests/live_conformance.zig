const std = @import("std");
const postgres = @import("zigeffect_postgres_libpq");
const options = @import("live_options");

const LiveDatabase = struct {
    url: []u8,

    fn init() !LiveDatabase {
        return .{ .url = try std.process.Environ.getAlloc(std.testing.environ, std.testing.allocator, "ZIGEFFECT_TEST_DATABASE_URL") };
    }

    fn deinit(self: *LiveDatabase) void {
        std.testing.allocator.free(self.url);
    }

    fn config(self: *const LiveDatabase) postgres.Config {
        return .{ .connection_url = self.url, .prepared_cache_capacity = 4 };
    }
};

test "live SQL binds null bool integer text bytes time and decimal without interpolation" {
    var live = try LiveDatabase.init();
    defer live.deinit();
    if (!std.mem.eql(u8, options.database, "postgresql") and !std.mem.eql(u8, options.database, "cockroachdb")) return error.InvalidLiveDatabaseIdentity;
    var session = try postgres.Session.init(std.testing.allocator, live.config());
    defer session.deinit();
    var result = try session.queryAlloc(std.testing.allocator, .{
        .sql = "select $1::bigint as integer_value, $2::boolean as bool_value, $3::text as text_value, $4::text as null_value, " ++
            "$5::bytea as bytes_value, $6::timestamptz as time_value, $7::decimal as decimal_value, $8::float8 as float_value, $9::text[] as array_value",
        .binds = &.{
            .{ .integer = -42 }, .{ .boolean = true }, .{ .text = "Robert'); drop table users;--" }, .null_value,
            .{ .bytes = &.{ 0, 255 } }, .{ .timestamp = "2026-07-11T12:34:56Z" }, .{ .decimal = "12345678901234567890.12345" },
            .{ .float = 3.25 }, .{ .text_array = &.{ "alpha", "b,c", "quoted\"value", "back\\slash" } },
        },
    });
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), result.rows.len);
    const fields = result.rows[0].fields;
    try std.testing.expectEqual(@as(i64, -42), fields[0].value.integer);
    try std.testing.expect(fields[1].value.boolean);
    try std.testing.expectEqualStrings("Robert'); drop table users;--", fields[2].value.text);
    try std.testing.expectEqual(postgres.Sql.Value.null_value, fields[3].value);
    try std.testing.expectEqualSlices(u8, &.{ 0, 255 }, fields[4].value.bytes);
    try std.testing.expect(std.mem.indexOf(u8, fields[5].value.timestamp, "2026-07-11 12:34:56") != null);
    try std.testing.expectEqualStrings("12345678901234567890.12345", fields[6].value.decimal);
    try std.testing.expectEqual(@as(f64, 3.25), fields[7].value.float);
    try std.testing.expectEqual(@as(usize, 4), fields[8].value.text_array.len);
    try std.testing.expectEqualStrings("b,c", fields[8].value.text_array[1]);
    try std.testing.expectEqualStrings("quoted\"value", fields[8].value.text_array[2]);
    try std.testing.expectEqualStrings("back\\slash", fields[8].value.text_array[3]);
    try std.testing.expect(session.serverVersion() > 0);
    try std.testing.expectEqual(@as(u32, 3), session.protocolVersion());
}

test "live SQL prepared cache and pinned transactions commit and rollback" {
    var live = try LiveDatabase.init();
    defer live.deinit();
    var session = try postgres.Session.init(std.testing.allocator, live.config());
    defer session.deinit();
    var dropped = try session.queryAlloc(std.testing.allocator, .{ .sql = "drop table if exists zigeffect_tx_test" });
    dropped.deinit(std.testing.allocator);
    defer {
        if (session.queryAlloc(std.testing.allocator, .{ .sql = "drop table if exists zigeffect_tx_test" })) |cleanup_value| {
            var cleanup = cleanup_value;
            cleanup.deinit(std.testing.allocator);
        } else |_| {}
    }
    var created = try session.queryAlloc(std.testing.allocator, .{ .sql = "create table zigeffect_tx_test(value bigint not null)" });
    created.deinit(std.testing.allocator);

    try session.begin();
    var inserted = try session.queryCachedAlloc(std.testing.allocator, .{ .sql = "insert into zigeffect_tx_test(value) values ($1)", .binds = &.{.{ .integer = 1 }} });
    inserted.deinit(std.testing.allocator);
    try session.rollback();
    var after_rollback = try session.queryAlloc(std.testing.allocator, .{ .sql = "select count(*)::bigint as count from zigeffect_tx_test" });
    defer after_rollback.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(i64, 0), after_rollback.rows[0].fields[0].value.integer);

    try session.begin();
    var committed_insert = try session.queryCachedAlloc(std.testing.allocator, .{ .sql = "insert into zigeffect_tx_test(value) values ($1)", .binds = &.{.{ .integer = 2 }} });
    committed_insert.deinit(std.testing.allocator);
    try session.commit();
    var after_commit = try session.queryAlloc(std.testing.allocator, .{ .sql = "select count(*)::bigint as count from zigeffect_tx_test" });
    defer after_commit.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(i64, 1), after_commit.rows[0].fields[0].value.integer);
}

test "live SQL exposes owned row streams and Schema-decoded typed queries" {
    var live = try LiveDatabase.init();
    defer live.deinit();
    var session = try postgres.Session.init(std.testing.allocator, live.config());
    defer session.deinit();

    var stream = try session.queryStreamAlloc(std.testing.allocator, .{
        .sql = "select 7::bigint as id union all select 9::bigint as id order by id",
    });
    defer stream.deinit();
    var env = postgres.zstd.Stream.EmptyEnv{};
    var context = postgres.zstd.fx.Context(postgres.zstd.Stream.EmptyEnv).init(std.testing.allocator, &env, null);
    const rows = try stream.runCollectAlloc(&context, std.testing.allocator, 1);
    defer std.testing.allocator.free(rows);
    try std.testing.expectEqual(@as(usize, 2), rows.len);
    try std.testing.expectEqual(@as(i64, 7), rows[0].fields[0].value.integer);
    try std.testing.expectEqual(@as(i64, 9), rows[1].fields[0].value.integer);

    const TypedRow = struct { id: i64, label: []const u8 };
    const row_schema = postgres.zstd.Schema.structSchema(TypedRow, .{
        postgres.zstd.Schema.field("id", postgres.zstd.Schema.integer()),
        postgres.zstd.Schema.field("label", postgres.zstd.Schema.string()),
    });
    const typed_query = postgres.Sql.typedQuery(.{
        .sql = "select 11::bigint as id, 'typed'::text as label",
    }, row_schema);
    var typed = try session.queryTypedAlloc(std.testing.allocator, typed_query);
    defer typed.deinit();
    try std.testing.expect(typed.ok());
    try std.testing.expectEqual(@as(i64, 11), typed.rows[0].decoded.value.?.id);
    try std.testing.expectEqualStrings("typed", typed.rows[0].decoded.value.?.label);
}

test "live SQL pool leases are exclusive bounded and transaction-pinned" {
    var live = try LiveDatabase.init();
    defer live.deinit();
    var pool = try postgres.Pool.initAlloc(std.testing.allocator, std.testing.io, .{
        .session = live.config(),
        .size = 2,
        .acquisition_timeout_ms = 10,
        .poll_interval_ms = 1,
    });
    defer pool.deinit();
    var first = try pool.checkout();
    defer first.deinit();
    var second = try pool.checkout();
    defer second.deinit();
    try std.testing.expectError(error.PoolAcquisitionTimeout, pool.checkout());
    try std.testing.expectEqual(@as(usize, 2), pool.stats().checked_out);
    try second.release();
    var transaction = try pool.checkoutTransaction();
    defer transaction.deinit();
    const pinned = transaction.session().connection;
    var value = try transaction.queryAlloc(std.testing.allocator, .{ .sql = "select 1::bigint as value" });
    value.deinit(std.testing.allocator);
    try std.testing.expectEqual(pinned, transaction.session().connection);
    try transaction.rollback();
}

test "live SQL cancellation is causally classified" {
    var live = try LiveDatabase.init();
    defer live.deinit();
    var session = try postgres.Session.init(std.testing.allocator, live.config());
    defer session.deinit();
    var cancellation = try session.cancellation();
    defer cancellation.deinit();
    const Context = struct {
        session: *postgres.Session,
        class: ?postgres.External.Class = null,
        fn run(self: *@This()) void {
            const outcome = self.session.queryClassifiedAlloc(std.testing.allocator, .{ .sql = "select pg_sleep(10)" });
            switch (outcome) {
                .success => |success_value| {
                    var success = success_value;
                    success.deinit(std.testing.allocator);
                },
                .failure => |failure| self.class = failure.class(),
            }
        }
    };
    var context = Context{ .session = &session };
    const thread = try std.Thread.spawn(.{}, Context.run, .{&context});
    try (std.Io.Clock.Duration{ .raw = .fromMilliseconds(100), .clock = .awake }).sleep(std.testing.io);
    try cancellation.cancel();
    thread.join();
    try std.testing.expectEqual(postgres.External.Class.canceled, context.class.?);
}

test "live SQL migrations lock checksum reapply and roll back atomically" {
    var live = try LiveDatabase.init();
    defer live.deinit();
    var session = try postgres.Session.init(std.testing.allocator, live.config());
    defer session.deinit();
    var cleanup_before = try session.executeTrustedAlloc(std.testing.allocator, "drop table if exists zigeffect_live_migrations;" ++
        "drop table if exists zigeffect_live_migrations_lock;" ++
        "drop table if exists zigeffect_migration_target;");
    cleanup_before.deinit(std.testing.allocator);
    defer {
        if (session.executeTrustedAlloc(std.testing.allocator, "drop table if exists zigeffect_live_migrations;" ++
            "drop table if exists zigeffect_live_migrations_lock;" ++
            "drop table if exists zigeffect_migration_target;")) |cleanup_value|
        {
            var cleanup = cleanup_value;
            cleanup.deinit(std.testing.allocator);
        } else |_| {}
    }
    const migrations = [_]postgres.Sql.Migration{
        .{ .id = "001_create", .sql = "create table zigeffect_migration_target(id bigint primary key)" },
        .{ .id = "002_add_name", .sql = "alter table zigeffect_migration_target add column name text" },
    };
    const dialect: postgres.MigrationOptions.Dialect = if (std.mem.eql(u8, options.database, "cockroachdb")) .cockroachdb else .postgresql;
    var applied = try postgres.applyMigrationsAlloc(std.testing.allocator, &session, .{ .table = "zigeffect_live_migrations", .dialect = dialect }, &migrations);
    defer applied.deinit();
    try std.testing.expectEqual(@as(usize, 2), applied.applied);
    try std.testing.expect(std.mem.indexOf(u8, applied.receipt_json, if (dialect == .postgresql) "atomic-per-migration" else "cockroach-online-ddl-non-atomic") != null);
    var reapplied = try postgres.applyMigrationsAlloc(std.testing.allocator, &session, .{ .table = "zigeffect_live_migrations", .dialect = dialect }, &migrations);
    defer reapplied.deinit();
    try std.testing.expectEqual(@as(usize, 0), reapplied.applied);
    try std.testing.expectEqual(@as(usize, 2), reapplied.skipped);
    const changed = [_]postgres.Sql.Migration{
        .{ .id = "001_create", .sql = "create table zigeffect_migration_target(id text primary key)" },
    };
    try std.testing.expectError(error.MigrationChecksumMismatch, postgres.applyMigrationsAlloc(std.testing.allocator, &session, .{ .table = "zigeffect_live_migrations", .dialect = dialect }, &changed));
}

test "live SQL serializable conflicts retry the whole pinned transaction" {
    var live = try LiveDatabase.init();
    defer live.deinit();
    var admin = try postgres.Session.init(std.testing.allocator, live.config());
    defer admin.deinit();
    var setup = try admin.executeTrustedAlloc(std.testing.allocator, "drop table if exists zigeffect_serializable_test;" ++
        "create table zigeffect_serializable_test(id bigint primary key, value bigint not null);" ++
        "insert into zigeffect_serializable_test(id, value) values (1, 0);");
    setup.deinit(std.testing.allocator);
    defer {
        if (admin.executeTrustedAlloc(std.testing.allocator, "drop table if exists zigeffect_serializable_test")) |cleanup_value| {
            var cleanup = cleanup_value;
            cleanup.deinit(std.testing.allocator);
        } else |_| {}
    }

    var first_session = try postgres.Session.init(std.testing.allocator, live.config());
    defer first_session.deinit();
    var second_session = try postgres.Session.init(std.testing.allocator, live.config());
    defer second_session.deinit();
    var barrier = std.atomic.Value(u32).init(0);
    const Handler = struct {
        barrier: *std.atomic.Value(u32),

        pub fn run(self: *@This(), session: *postgres.Session, attempt: u32) postgres.QueryOutcome(void) {
            const isolation = session.queryClassifiedAlloc(std.testing.allocator, .{ .sql = "set transaction isolation level serializable" });
            switch (isolation) {
                .failure => |failure| return .{ .failure = failure },
                .success => |success_value| {
                    var success = success_value;
                    success.deinit(std.testing.allocator);
                },
            }
            const read = session.queryClassifiedAlloc(std.testing.allocator, .{ .sql = "select value from zigeffect_serializable_test where id = 1" });
            switch (read) {
                .failure => |failure| return .{ .failure = failure },
                .success => |success_value| {
                    var success = success_value;
                    success.deinit(std.testing.allocator);
                },
            }
            if (attempt == 1) {
                _ = self.barrier.fetchAdd(1, .acq_rel);
                while (self.barrier.load(.acquire) < 2) std.Thread.yield() catch {};
            }
            const updated = session.queryClassifiedAlloc(std.testing.allocator, .{ .sql = "update zigeffect_serializable_test set value = value + 1 where id = 1" });
            return switch (updated) {
                .failure => |failure| .{ .failure = failure },
                .success => |success_value| success: {
                    var value = success_value;
                    value.deinit(std.testing.allocator);
                    break :success .{ .success = {} };
                },
            };
        }
    };
    const Context = struct {
        session: *postgres.Session,
        handler: *Handler,
        attempts: u32 = 0,
        failure: ?postgres.External.Class = null,

        fn run(self: *@This()) void {
            const outcome = postgres.runSerializable(self.session, 3, self.handler) catch {
                self.failure = .internal;
                return;
            };
            switch (outcome) {
                .success => |attempts| self.attempts = attempts,
                .failure => |failed| self.failure = failed.cause.class(),
            }
        }
    };
    var first_handler = Handler{ .barrier = &barrier };
    var second_handler = Handler{ .barrier = &barrier };
    var first = Context{ .session = &first_session, .handler = &first_handler };
    var second = Context{ .session = &second_session, .handler = &second_handler };
    const first_thread = try std.Thread.spawn(.{}, Context.run, .{&first});
    const second_thread = try std.Thread.spawn(.{}, Context.run, .{&second});
    first_thread.join();
    second_thread.join();
    try std.testing.expect(first.failure == null and second.failure == null);
    try std.testing.expect(first.attempts > 1 or second.attempts > 1);
    var final = try admin.queryAlloc(std.testing.allocator, .{ .sql = "select value from zigeffect_serializable_test where id = 1" });
    defer final.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(i64, 2), final.rows[0].fields[0].value.integer);
}
