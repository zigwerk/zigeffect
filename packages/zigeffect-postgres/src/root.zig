const std = @import("std");
const zstd = @import("zigeffect_std");

pub const Sql = zstd.Sql;
pub const Native = @import("native.zig");

pub const PostgresError = error{
    InvalidJsonRows,
    InvalidMigrationTable,
    MissingCliCommand,
    MissingCliValue,
    PsqlFailed,
    UnsupportedBindings,
    UnknownCliCommand,
};

pub const ConnectionConfig = struct {
    url: []const u8,
    psql_path: []const u8 = "psql",
};

pub const Outcome = enum {
    definite,
    ambiguous,
    connection,
};

pub const Diagnostic = struct {
    sqlstate: ?[5]u8 = null,
    outcome: Outcome = .connection,

    pub fn reset(self: *Diagnostic) void {
        self.* = .{};
    }

    pub fn sqlstateSlice(self: *const Diagnostic) ?[]const u8 {
        return if (self.sqlstate) |*sqlstate| sqlstate else null;
    }

    pub fn captureStderr(self: *Diagnostic, stderr: []const u8) void {
        self.reset();
        var index: usize = 0;
        while (index + 5 < stderr.len) : (index += 1) {
            const candidate = stderr[index .. index + 5];
            if (index == 0 or !std.ascii.isWhitespace(stderr[index - 1]) or
                stderr[index + 5] != ':' or !isSqlstate(candidate)) continue;
            var sqlstate: [5]u8 = undefined;
            @memcpy(&sqlstate, candidate);
            self.sqlstate = sqlstate;
            self.outcome = if (std.mem.eql(u8, candidate, "40003")) .ambiguous else .definite;
            return;
        }
    }
};

pub const PsqlClient = struct {
    pub const capability = zstd.Capability.Descriptor{
        .id = "zigeffect-postgres.psql-client",
        .kind = .sql_database,
        .maturity = .local_development,
        .package = "zigeffect-postgres",
        .version = "0.1.0",
        .features = &.{ "queries", "migrations" },
        .side_effects = .local_process,
        .limitations = &.{
            "executes the psql subprocess for each operation",
            "does not provide native parameter binding pooling or transaction leases",
        },
    };

    config: ConnectionConfig,
    io: std.Io,
    stdout_limit: std.Io.Limit = .limited(1024 * 1024),
    stderr_limit: std.Io.Limit = .limited(256 * 1024),
    reserve_amount: usize = 256,

    pub fn init(config: ConnectionConfig, io: std.Io) PsqlClient {
        return .{ .config = config, .io = io };
    }

    pub fn queryAlloc(self: *PsqlClient, allocator: std.mem.Allocator, statement: Sql.Statement) anyerror!Sql.QueryResult {
        var diagnostic = Diagnostic{};
        return self.queryDetailedAlloc(allocator, statement, &diagnostic);
    }

    pub fn queryDetailedAlloc(
        self: *PsqlClient,
        allocator: std.mem.Allocator,
        statement: Sql.Statement,
        diagnostic: *Diagnostic,
    ) anyerror!Sql.QueryResult {
        diagnostic.reset();
        if (statement.binds.len != 0) return PostgresError.UnsupportedBindings;
        const argv = try buildPsqlJsonArgv(allocator, self.config, statement.sql);
        defer freeArgv(allocator, argv);
        var environ = try connectionEnviron(allocator, self.config.url);
        defer deinitSecretEnviron(&environ);

        const run_result = try std.process.run(allocator, self.io, .{
            .argv = argv,
            .environ_map = &environ,
            .stdout_limit = self.stdout_limit,
            .stderr_limit = self.stderr_limit,
            .reserve_amount = self.reserve_amount,
        });
        defer allocator.free(run_result.stdout);
        defer allocator.free(run_result.stderr);
        diagnostic.captureStderr(run_result.stderr);

        switch (run_result.term) {
            .exited => |code| if (code != 0) return PostgresError.PsqlFailed,
            else => return PostgresError.PsqlFailed,
        }
        diagnostic.outcome = .definite;

        return parseJsonRowsAlloc(allocator, run_result.stdout);
    }

    pub fn queryClassifiedAlloc(self: *PsqlClient, allocator: std.mem.Allocator, statement: Sql.Statement) zstd.External.Result(Sql.QueryResult) {
        const result = self.queryAlloc(allocator, statement) catch |err| {
            return .{ .failure = zstd.External.Failure.fromError("postgres-psql", "query", err) };
        };
        return .{ .success = result };
    }

    pub fn executeRawAlloc(self: *PsqlClient, allocator: std.mem.Allocator, sql: []const u8) anyerror![]const u8 {
        var diagnostic = Diagnostic{};
        return self.executeRawDetailedAlloc(allocator, sql, &diagnostic);
    }

    pub fn executeRawDetailedAlloc(
        self: *PsqlClient,
        allocator: std.mem.Allocator,
        sql: []const u8,
        diagnostic: *Diagnostic,
    ) anyerror![]const u8 {
        diagnostic.reset();
        const argv = try buildPsqlArgv(allocator, self.config, sql);
        defer freeArgv(allocator, argv);
        var environ = try connectionEnviron(allocator, self.config.url);
        defer deinitSecretEnviron(&environ);

        const run_result = try std.process.run(allocator, self.io, .{
            .argv = argv,
            .environ_map = &environ,
            .stdout_limit = self.stdout_limit,
            .stderr_limit = self.stderr_limit,
            .reserve_amount = self.reserve_amount,
        });
        defer allocator.free(run_result.stderr);
        diagnostic.captureStderr(run_result.stderr);

        switch (run_result.term) {
            .exited => |code| if (code != 0) {
                allocator.free(run_result.stdout);
                return PostgresError.PsqlFailed;
            },
            else => {
                allocator.free(run_result.stdout);
                return PostgresError.PsqlFailed;
            },
        }
        diagnostic.outcome = .definite;

        return run_result.stdout;
    }
};

pub const MigrationPlanOptions = struct {
    table: []const u8 = "zigeffect_migrations",
    connection_url: ?[]const u8 = null,
};

pub const MigrationPlan = struct {
    allocator: std.mem.Allocator,
    table: []const u8,
    connection_url: ?[]const u8,
    pending: []Sql.Migration,
    skipped_ids: []const []const u8,
    apply_sql: []const u8,
    receipt_json: []const u8,

    pub fn deinit(self: *MigrationPlan) void {
        self.allocator.free(self.table);
        if (self.connection_url) |url| self.allocator.free(url);
        for (self.pending) |migration| {
            self.allocator.free(migration.id);
            self.allocator.free(migration.sql);
        }
        self.allocator.free(self.pending);
        for (self.skipped_ids) |id| self.allocator.free(id);
        self.allocator.free(self.skipped_ids);
        self.allocator.free(self.apply_sql);
        self.allocator.free(self.receipt_json);
        self.* = undefined;
    }
};

pub fn buildPsqlArgv(
    allocator: std.mem.Allocator,
    config: ConnectionConfig,
    sql: []const u8,
) std.mem.Allocator.Error![]const []const u8 {
    const argv = try allocator.alloc([]const u8, 8);
    errdefer allocator.free(argv);

    var initialized: usize = 0;
    errdefer {
        for (argv[0..initialized]) |arg| allocator.free(arg);
    }

    argv[0] = try allocator.dupe(u8, config.psql_path);
    initialized += 1;
    argv[1] = try allocator.dupe(u8, "-X");
    initialized += 1;
    argv[2] = try allocator.dupe(u8, "-A");
    initialized += 1;
    argv[3] = try allocator.dupe(u8, "-t");
    initialized += 1;
    argv[4] = try allocator.dupe(u8, "--set=ON_ERROR_STOP=1");
    initialized += 1;
    argv[5] = try allocator.dupe(u8, "--set=VERBOSITY=verbose");
    initialized += 1;
    argv[6] = try allocator.dupe(u8, "-c");
    initialized += 1;
    argv[7] = try allocator.dupe(u8, sql);
    initialized += 1;

    return argv;
}

fn connectionEnviron(allocator: std.mem.Allocator, url: []const u8) std.mem.Allocator.Error!std.process.Environ.Map {
    var environ = std.process.Environ.Map.init(allocator);
    errdefer environ.deinit();
    try environ.put("PGDATABASE", url);
    return environ;
}

fn deinitSecretEnviron(environ: *std.process.Environ.Map) void {
    for (environ.values()) |entry| std.crypto.secureZero(u8, @constCast(entry));
    environ.deinit();
}

fn isSqlstate(candidate: []const u8) bool {
    if (candidate.len != 5) return false;
    var has_digit = false;
    for (candidate) |byte| {
        if (std.ascii.isDigit(byte)) {
            has_digit = true;
        } else if (!std.ascii.isUpper(byte)) return false;
    }
    return has_digit;
}

pub fn freeArgv(allocator: std.mem.Allocator, argv: []const []const u8) void {
    for (argv) |arg| allocator.free(arg);
    allocator.free(argv);
}

pub fn jsonRowsSqlAlloc(allocator: std.mem.Allocator, sql: []const u8) std.mem.Allocator.Error![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "select coalesce(json_agg(row_to_json(zigeffect_query_rows)), '[]'::json) from ({s}) as zigeffect_query_rows",
        .{sql},
    );
}

pub fn buildPsqlJsonArgv(
    allocator: std.mem.Allocator,
    config: ConnectionConfig,
    sql: []const u8,
) std.mem.Allocator.Error![]const []const u8 {
    const wrapped_sql = try jsonRowsSqlAlloc(allocator, sql);
    defer allocator.free(wrapped_sql);
    return buildPsqlArgv(allocator, config, wrapped_sql);
}

pub fn queryReceiptAlloc(
    allocator: std.mem.Allocator,
    config: ConnectionConfig,
    sql: []const u8,
) std.mem.Allocator.Error![]const u8 {
    const connection = try zstd.Secrets.redactAlloc(allocator, config.url);
    defer allocator.free(connection);
    const query = try zstd.Secrets.redactAlloc(allocator, sql);
    defer allocator.free(query);

    return std.fmt.allocPrint(allocator, "{s} {s} -c {s}", .{ config.psql_path, connection, query });
}

pub fn planMigrationsAlloc(
    allocator: std.mem.Allocator,
    options: MigrationPlanOptions,
    migrations: []const Sql.Migration,
    applied_ids: []const []const u8,
) (std.mem.Allocator.Error || PostgresError)!MigrationPlan {
    try validateIdentifier(options.table);

    var pending: std.ArrayList(Sql.Migration) = .empty;
    errdefer {
        for (pending.items) |migration| {
            allocator.free(migration.id);
            allocator.free(migration.sql);
        }
        pending.deinit(allocator);
    }

    var skipped: std.ArrayList([]const u8) = .empty;
    errdefer {
        for (skipped.items) |id| allocator.free(id);
        skipped.deinit(allocator);
    }

    for (migrations) |migration| {
        if (hasApplied(applied_ids, migration.id)) {
            try skipped.append(allocator, try allocator.dupe(u8, migration.id));
            continue;
        }
        const owned_id = try allocator.dupe(u8, migration.id);
        errdefer allocator.free(owned_id);
        const owned_sql = try allocator.dupe(u8, migration.sql);
        errdefer allocator.free(owned_sql);
        try pending.append(allocator, .{ .id = owned_id, .sql = owned_sql });
    }

    const owned_table = try allocator.dupe(u8, options.table);
    errdefer allocator.free(owned_table);
    const owned_url = if (options.connection_url) |url| try allocator.dupe(u8, url) else null;
    errdefer if (owned_url) |url| allocator.free(url);

    const pending_slice = try pending.toOwnedSlice(allocator);
    errdefer {
        for (pending_slice) |migration| {
            allocator.free(migration.id);
            allocator.free(migration.sql);
        }
        allocator.free(pending_slice);
    }
    const skipped_slice = try skipped.toOwnedSlice(allocator);
    errdefer {
        for (skipped_slice) |id| allocator.free(id);
        allocator.free(skipped_slice);
    }

    const apply_sql = try migrationApplySqlAlloc(allocator, owned_table, pending_slice);
    errdefer allocator.free(apply_sql);
    const receipt_json = try migrationPlanReceiptJsonAlloc(allocator, .{
        .table = owned_table,
        .connection_url = owned_url,
    }, pending_slice, skipped_slice, apply_sql);
    errdefer allocator.free(receipt_json);

    return .{
        .allocator = allocator,
        .table = owned_table,
        .connection_url = owned_url,
        .pending = pending_slice,
        .skipped_ids = skipped_slice,
        .apply_sql = apply_sql,
        .receipt_json = receipt_json,
    };
}

pub fn migrationApplySqlAlloc(
    allocator: std.mem.Allocator,
    table: []const u8,
    migrations: []const Sql.Migration,
) (std.mem.Allocator.Error || PostgresError)![]const u8 {
    try validateIdentifier(table);

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);

    try output.print(
        allocator,
        "create table if not exists {s} (id text primary key, applied_at timestamptz not null default now());\n",
        .{table},
    );
    try output.appendSlice(allocator, "begin;\n");
    if (migrations.len == 0) {
        try output.appendSlice(allocator, "-- no pending zigeffect migrations\n");
    }
    for (migrations) |migration| {
        const escaped_id = try sqlStringLiteralAlloc(allocator, migration.id);
        defer allocator.free(escaped_id);

        try output.print(allocator, "-- zigeffect migration: {s}\n", .{migration.id});
        try output.appendSlice(allocator, migration.sql);
        if (!std.mem.endsWith(u8, std.mem.trim(u8, migration.sql, " \n\r\t"), ";")) {
            try output.append(allocator, ';');
        }
        try output.print(
            allocator,
            "\ninsert into {s}(id) values ('{s}') on conflict (id) do nothing;\n",
            .{ table, escaped_id },
        );
    }
    try output.appendSlice(allocator, "commit;\n");
    return output.toOwnedSlice(allocator);
}

pub fn migrationPlanReceiptJsonAlloc(
    allocator: std.mem.Allocator,
    options: MigrationPlanOptions,
    pending: []const Sql.Migration,
    skipped_ids: []const []const u8,
    apply_sql: []const u8,
) std.mem.Allocator.Error![]const u8 {
    const pending_count = try std.fmt.allocPrint(allocator, "{d}", .{pending.len});
    defer allocator.free(pending_count);
    const skipped_count = try std.fmt.allocPrint(allocator, "{d}", .{skipped_ids.len});
    defer allocator.free(skipped_count);
    const connection = if (options.connection_url) |url| try zstd.Secrets.redactAlloc(allocator, url) else try allocator.dupe(u8, "");
    defer allocator.free(connection);

    return zstd.Json.objectFromFieldsAlloc(allocator, &.{
        .{ .name = "kind", .value = "postgres.migration_plan" },
        .{ .name = "table", .value = options.table },
        .{ .name = "connection", .value = connection },
        .{ .name = "pending_count", .value = pending_count },
        .{ .name = "skipped_count", .value = skipped_count },
        .{ .name = "apply_sql", .value = apply_sql },
    });
}

pub fn runMigrationCliAlloc(
    allocator: std.mem.Allocator,
    argv: []const []const u8,
    migrations: []const Sql.Migration,
    applied_ids: []const []const u8,
) (std.mem.Allocator.Error || PostgresError)![]const u8 {
    if (argv.len < 2) return PostgresError.MissingCliCommand;

    const command = argv[1];
    var table: []const u8 = "zigeffect_migrations";
    var connection_url: ?[]const u8 = null;

    var index: usize = 2;
    while (index < argv.len) : (index += 1) {
        if (std.mem.eql(u8, argv[index], "--url")) {
            index += 1;
            if (index >= argv.len) return PostgresError.MissingCliValue;
            connection_url = argv[index];
        } else if (std.mem.eql(u8, argv[index], "--table")) {
            index += 1;
            if (index >= argv.len) return PostgresError.MissingCliValue;
            table = argv[index];
        } else {
            return PostgresError.UnknownCliCommand;
        }
    }

    var plan = try planMigrationsAlloc(allocator, .{
        .table = table,
        .connection_url = connection_url,
    }, migrations, applied_ids);
    defer plan.deinit();

    if (std.mem.eql(u8, command, "plan")) {
        return allocator.dupe(u8, plan.receipt_json);
    }
    if (std.mem.eql(u8, command, "apply-sql")) {
        return allocator.dupe(u8, plan.apply_sql);
    }
    return PostgresError.UnknownCliCommand;
}

fn hasApplied(applied_ids: []const []const u8, id: []const u8) bool {
    for (applied_ids) |applied_id| {
        if (std.mem.eql(u8, applied_id, id)) return true;
    }
    return false;
}

fn validateIdentifier(identifier: []const u8) PostgresError!void {
    if (identifier.len == 0) return PostgresError.InvalidMigrationTable;
    for (identifier) |byte| {
        if (std.ascii.isAlphanumeric(byte) or byte == '_') continue;
        return PostgresError.InvalidMigrationTable;
    }
}

fn sqlStringLiteralAlloc(allocator: std.mem.Allocator, value: []const u8) std.mem.Allocator.Error![]const u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);

    for (value) |byte| {
        if (byte == '\'') try output.append(allocator, '\'');
        try output.append(allocator, byte);
    }

    return output.toOwnedSlice(allocator);
}

pub fn parseJsonRowsAlloc(allocator: std.mem.Allocator, input: []const u8) (std.mem.Allocator.Error || PostgresError)!Sql.QueryResult {
    var parsed = std.json.parseFromSlice(std.json.Value, allocator, input, .{}) catch return PostgresError.InvalidJsonRows;
    defer parsed.deinit();

    const items = switch (parsed.value) {
        .array => |array| array.items,
        else => return PostgresError.InvalidJsonRows,
    };

    const rows = try allocator.alloc(Sql.Row, items.len);
    errdefer allocator.free(rows);

    var initialized: usize = 0;
    errdefer {
        for (rows[0..initialized]) |*row| row.deinit(allocator);
    }

    for (items, 0..) |item, row_index| {
        const object = switch (item) {
            .object => |object| object,
            else => return PostgresError.InvalidJsonRows,
        };

        const fields = try allocator.alloc(Sql.Field, object.count());
        errdefer allocator.free(fields);

        var field_index: usize = 0;
        errdefer {
            for (fields[0..field_index]) |*field| field.deinit(allocator);
        }

        var iterator = object.iterator();
        while (iterator.next()) |entry| {
            const field_name = try allocator.dupe(u8, entry.key_ptr.*);
            errdefer allocator.free(field_name);
            const field_value = try sqlValueFromJsonAlloc(allocator, entry.value_ptr.*);
            fields[field_index] = .{
                .name = field_name,
                .value = field_value,
            };
            field_index += 1;
        }
        sortFields(fields);

        rows[row_index] = .{ .fields = fields };
        initialized += 1;
    }

    return .{ .rows = rows };
}

fn sqlValueFromJsonAlloc(allocator: std.mem.Allocator, value: std.json.Value) std.mem.Allocator.Error!Sql.Value {
    return switch (value) {
        .null => .null_value,
        .bool => |inner| .{ .boolean = inner },
        .integer => |inner| .{ .integer = inner },
        .float => |inner| blk: {
            const text = try std.fmt.allocPrint(allocator, "{d}", .{inner});
            break :blk .{ .text = text };
        },
        .number_string => |inner| .{ .text = try allocator.dupe(u8, inner) },
        .string => |inner| .{ .text = try allocator.dupe(u8, inner) },
        .array, .object => .{ .text = try std.json.Stringify.valueAlloc(allocator, value, .{}) },
    };
}

fn sortFields(fields: []Sql.Field) void {
    std.mem.sort(Sql.Field, fields, {}, struct {
        fn lessThan(_: void, left: Sql.Field, right: Sql.Field) bool {
            return std.mem.lessThan(u8, left.name, right.name);
        }
    }.lessThan);
}

test "Postgres adapter redacts connections and builds psql argv" {
    const config = ConnectionConfig{
        .url = "postgres://user:pass@localhost/db",
        .psql_path = "psql",
    };
    const argv = try buildPsqlArgv(std.testing.allocator, config, "select 1");
    defer freeArgv(std.testing.allocator, argv);

    try std.testing.expectEqualStrings("psql", argv[0]);
    try std.testing.expectEqualStrings("-X", argv[1]);
    try std.testing.expectEqualStrings("-A", argv[2]);
    try std.testing.expectEqualStrings("-t", argv[3]);
    try std.testing.expectEqualStrings("--set=ON_ERROR_STOP=1", argv[4]);
    try std.testing.expectEqualStrings("--set=VERBOSITY=verbose", argv[5]);
    try std.testing.expectEqualStrings("-c", argv[6]);
    try std.testing.expectEqualStrings("select 1", argv[7]);
    for (argv) |argument| try std.testing.expect(std.mem.indexOf(u8, argument, "pass@localhost") == null);

    const receipt = try queryReceiptAlloc(std.testing.allocator, config, "select token=abc123");
    defer std.testing.allocator.free(receipt);
    try std.testing.expect(std.mem.indexOf(u8, receipt, "pass@localhost") == null);
    try std.testing.expect(std.mem.indexOf(u8, receipt, "abc123") == null);
}

test "Postgres adapter parses SQLSTATE without retaining server diagnostics" {
    var diagnostic = Diagnostic{};
    diagnostic.captureStderr("ERROR:  40001: restart transaction: TransactionRetryWithProtoRefreshError\nLOCATION:  file.go:42");
    try std.testing.expectEqualStrings("40001", diagnostic.sqlstateSlice().?);
    try std.testing.expectEqual(Outcome.definite, diagnostic.outcome);

    diagnostic.captureStderr("ERROR:  40003: result is ambiguous\n");
    try std.testing.expectEqualStrings("40003", diagnostic.sqlstateSlice().?);
    try std.testing.expectEqual(Outcome.ambiguous, diagnostic.outcome);

    diagnostic.captureStderr("psql: error: connection to server was lost\n");
    try std.testing.expect(diagnostic.sqlstateSlice() == null);
    try std.testing.expectEqual(Outcome.connection, diagnostic.outcome);
}

test "Postgres adapter parses psql JSON rows into zstd SQL results" {
    var result = try parseJsonRowsAlloc(std.testing.allocator,
        \\[
        \\  {"id": 42, "name": "local", "active": true, "missing": null}
        \\]
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), result.rows.len);
    try std.testing.expectEqualStrings("active", result.rows[0].fields[0].name);
    try std.testing.expectEqual(true, result.rows[0].fields[0].value.boolean);
    try std.testing.expectEqualStrings("id", result.rows[0].fields[1].name);
    try std.testing.expectEqual(@as(i64, 42), result.rows[0].fields[1].value.integer);
    try std.testing.expectEqualStrings("missing", result.rows[0].fields[2].name);
    try std.testing.expectEqual(Sql.Value.null_value, result.rows[0].fields[2].value);
    try std.testing.expectEqualStrings("name", result.rows[0].fields[3].name);
    try std.testing.expectEqualStrings("local", result.rows[0].fields[3].value.text);
}

test "Postgres adapter wraps local queries as deterministic JSON row SQL" {
    const wrapped = try jsonRowsSqlAlloc(std.testing.allocator, "select id, name from projects");
    defer std.testing.allocator.free(wrapped);

    try std.testing.expect(std.mem.indexOf(u8, wrapped, "row_to_json(zigeffect_query_rows)") != null);
    try std.testing.expect(std.mem.indexOf(u8, wrapped, "select id, name from projects") != null);

    const config = ConnectionConfig{
        .url = "postgres://user:pass@localhost/db",
        .psql_path = "psql",
    };
    const argv = try buildPsqlJsonArgv(std.testing.allocator, config, "select 1");
    defer freeArgv(std.testing.allocator, argv);
    try std.testing.expect(std.mem.indexOf(u8, argv[7], "json_agg") != null);
}

test "Postgres psql adapter is local only and rejects ignored binds" {
    try PsqlClient.capability.validate();
    try std.testing.expectEqual(zstd.Capability.Maturity.local_development, PsqlClient.capability.maturity);
    try std.testing.expectEqual(
        zstd.Capability.Match.insufficient_maturity,
        zstd.Capability.match(PsqlClient.capability, .{
            .kind = .sql_database,
            .minimum_maturity = .production_candidate,
            .requires_live_conformance = true,
        }),
    );

    var client = PsqlClient.init(.{ .url = "postgres://localhost/test" }, std.testing.io);
    try std.testing.expectError(
        PostgresError.UnsupportedBindings,
        client.queryAlloc(std.testing.allocator, .{
            .sql = "select $1",
            .binds = &.{.{ .integer = 42 }},
        }),
    );

    const classified = client.queryClassifiedAlloc(std.testing.allocator, .{
        .sql = "select $1",
        .binds = &.{.{ .integer = 42 }},
    });
    switch (classified) {
        .success => return error.TestExpectedFailure,
        .failure => |failure| try std.testing.expectEqual(zstd.External.Class.unsupported, failure.class),
    }
}

test "Postgres migration planner generates apply SQL and redacted receipts" {
    const migrations = [_]Sql.Migration{
        .{ .id = "001_init", .sql = "create table projects(id int primary key)" },
        .{ .id = "002_add_name", .sql = "alter table projects add column name text" },
    };
    const applied = [_][]const u8{"001_init"};

    var plan = try planMigrationsAlloc(std.testing.allocator, .{
        .table = "zigeffect_migrations",
        .connection_url = "postgres://user:pass@localhost/db",
    }, migrations[0..], applied[0..]);
    defer plan.deinit();

    try std.testing.expectEqual(@as(usize, 1), plan.pending.len);
    try std.testing.expectEqualStrings("002_add_name", plan.pending[0].id);
    try std.testing.expectEqual(@as(usize, 1), plan.skipped_ids.len);
    try std.testing.expect(std.mem.indexOf(u8, plan.apply_sql, "create table if not exists zigeffect_migrations") != null);
    try std.testing.expect(std.mem.indexOf(u8, plan.apply_sql, "insert into zigeffect_migrations") != null);

    try std.testing.expect(std.mem.indexOf(u8, plan.receipt_json, "pass@localhost") == null);
    try std.testing.expect(std.mem.indexOf(u8, plan.receipt_json, "\"pending_count\":\"1\"") != null);
}

test "native adapter declarations and tests are part of the package gate" {
    std.testing.refAllDecls(Native);
}

test "Postgres migration CLI emits a local plan without leaking connection secrets" {
    const migrations = [_]Sql.Migration{
        .{ .id = "001_init", .sql = "create table projects(id int primary key)" },
    };
    const applied = [_][]const u8{};
    const argv = [_][]const u8{
        "zigeffect-postgres-migrate",
        "plan",
        "--url",
        "postgres://user:pass@localhost/db",
        "--table",
        "local_migrations",
    };

    const output = try runMigrationCliAlloc(std.testing.allocator, argv[0..], migrations[0..], applied[0..]);
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "\"table\":\"local_migrations\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"pending_count\":\"1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "pass@localhost") == null);
}
