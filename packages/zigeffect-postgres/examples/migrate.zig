const std = @import("std");
const pg = @import("zigeffect_postgres");

const migrations = [_]pg.Sql.Migration{
    .{
        .id = "001_create_projects",
        .sql = "create table if not exists projects(id bigint primary key, name text not null)",
    },
    .{
        .id = "002_project_status",
        .sql = "alter table projects add column if not exists status text not null default 'local'",
    },
};

pub fn runExampleAlloc(
    allocator: std.mem.Allocator,
    argv: []const []const u8,
    applied_ids: []const []const u8,
) ![]const u8 {
    return pg.runMigrationCliAlloc(allocator, argv, migrations[0..], applied_ids);
}

pub fn main(init: std.process.Init.Minimal) !void {
    const allocator = std.heap.page_allocator;
    const raw_argv = init.args.vector;
    const argv = try allocator.alloc([]const u8, raw_argv.len);
    defer allocator.free(argv);
    for (raw_argv, 0..) |arg, index| {
        argv[index] = std.mem.span(arg);
    }

    const output = try runExampleAlloc(allocator, argv, &.{});
    defer allocator.free(output);

    std.debug.print("{s}\n", .{output});
}

test "postgres migration example emits a redacted plan" {
    const argv = [_][]const u8{
        "zigeffect-postgres-migrate",
        "plan",
        "--url",
        "postgres://user:pass@localhost/db",
        "--table",
        "local_migrations",
    };
    const output = try runExampleAlloc(std.testing.allocator, argv[0..], &.{});
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "\"pending_count\":\"2\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "pass@localhost") == null);
}
