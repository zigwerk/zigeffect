const std = @import("std");
const Secrets = @import("../secrets/root.zig");

pub const Value = union(enum) {
    null_value,
    text: []const u8,
    integer: i64,
    boolean: bool,
};

pub const Field = struct {
    name: []const u8,
    value: Value,
};

pub const Row = struct {
    fields: []const Field,
};

pub const QueryResult = struct {
    rows: []const Row,
};

pub const FakeDatabase = struct {
    result: QueryResult,

    pub fn init(result: QueryResult) FakeDatabase {
        return .{ .result = result };
    }

    pub fn query(self: FakeDatabase, sql: []const u8, binds: []const Value) QueryResult {
        _ = sql;
        _ = binds;
        return self.result;
    }
};

pub fn redactConnectionAlloc(allocator: std.mem.Allocator, connection: []const u8) ![]const u8 {
    return Secrets.redactAlloc(allocator, connection);
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
