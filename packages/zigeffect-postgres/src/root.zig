const std = @import("std");
const zstd = @import("zigeffect_std");

pub const Sql = zstd.Sql;

pub const PostgresError = error{
    InvalidJsonRows,
    PsqlFailed,
};

pub const ConnectionConfig = struct {
    url: []const u8,
    psql_path: []const u8 = "psql",
};

pub const PsqlClient = struct {
    config: ConnectionConfig,
    io: std.Io,
    stdout_limit: std.Io.Limit = .limited(1024 * 1024),
    stderr_limit: std.Io.Limit = .limited(256 * 1024),
    reserve_amount: usize = 256,

    pub fn init(config: ConnectionConfig, io: std.Io) PsqlClient {
        return .{ .config = config, .io = io };
    }

    pub fn queryAlloc(self: *PsqlClient, allocator: std.mem.Allocator, statement: Sql.Statement) anyerror!Sql.QueryResult {
        const argv = try buildPsqlArgv(allocator, self.config, statement.sql);
        defer freeArgv(allocator, argv);

        const run_result = try std.process.run(allocator, self.io, .{
            .argv = argv,
            .stdout_limit = self.stdout_limit,
            .stderr_limit = self.stderr_limit,
            .reserve_amount = self.reserve_amount,
        });
        defer allocator.free(run_result.stdout);
        defer allocator.free(run_result.stderr);

        switch (run_result.term) {
            .exited => |code| if (code != 0) return PostgresError.PsqlFailed,
            else => return PostgresError.PsqlFailed,
        }

        return parseJsonRowsAlloc(allocator, run_result.stdout);
    }
};

pub fn buildPsqlArgv(
    allocator: std.mem.Allocator,
    config: ConnectionConfig,
    sql: []const u8,
) std.mem.Allocator.Error![]const []const u8 {
    const argv = try allocator.alloc([]const u8, 7);
    errdefer allocator.free(argv);

    var initialized: usize = 0;
    errdefer {
        for (argv[0..initialized]) |arg| allocator.free(arg);
    }

    argv[0] = try allocator.dupe(u8, config.psql_path);
    initialized += 1;
    argv[1] = try allocator.dupe(u8, config.url);
    initialized += 1;
    argv[2] = try allocator.dupe(u8, "-X");
    initialized += 1;
    argv[3] = try allocator.dupe(u8, "-A");
    initialized += 1;
    argv[4] = try allocator.dupe(u8, "-t");
    initialized += 1;
    argv[5] = try allocator.dupe(u8, "-c");
    initialized += 1;
    argv[6] = try allocator.dupe(u8, sql);
    initialized += 1;

    return argv;
}

pub fn freeArgv(allocator: std.mem.Allocator, argv: []const []const u8) void {
    for (argv) |arg| allocator.free(arg);
    allocator.free(argv);
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
    try std.testing.expectEqualStrings("postgres://user:pass@localhost/db", argv[1]);
    try std.testing.expectEqualStrings("-X", argv[2]);
    try std.testing.expectEqualStrings("-A", argv[3]);
    try std.testing.expectEqualStrings("-t", argv[4]);
    try std.testing.expectEqualStrings("-c", argv[5]);
    try std.testing.expectEqualStrings("select 1", argv[6]);

    const receipt = try queryReceiptAlloc(std.testing.allocator, config, "select token=abc123");
    defer std.testing.allocator.free(receipt);
    try std.testing.expect(std.mem.indexOf(u8, receipt, "pass@localhost") == null);
    try std.testing.expect(std.mem.indexOf(u8, receipt, "abc123") == null);
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
