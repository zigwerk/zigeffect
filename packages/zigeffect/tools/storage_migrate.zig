const std = @import("std");
const fx = @import("zigeffect");

const OutputFormat = enum { text, json };

const PlanArgs = struct {
    dialect: fx.SqlStorageDialect = .postgresql,
    format: OutputFormat = .text,
};

pub const StorageMigrateError = error{
    UnknownCommand,
    UnknownFlag,
    MissingFlagValue,
    UnknownFormat,
    UnknownDialect,
};

pub fn runStorageMigrate(allocator: std.mem.Allocator, args: []const []const u8) ![]const u8 {
    if (args.len == 0) return usage(allocator);
    if (std.mem.eql(u8, args[0], "schemas")) {
        const format = try parseFormat(args[1..]);
        return switch (format) {
            .text => fx.formatStorageSchemaCatalogText(allocator, fx.storageSchemaCatalog()),
            .json => fx.formatStorageSchemaCatalogJson(allocator, fx.storageSchemaCatalog()),
        };
    }
    if (std.mem.eql(u8, args[0], "plan")) {
        const parsed = try parsePlanArgs(args[1..]);
        const plan = fx.sqlStorageMigrationPlan(parsed.dialect);
        return switch (parsed.format) {
            .text => fx.formatSqlStorageMigrationPlanText(allocator, plan),
            .json => fx.formatSqlStorageMigrationPlanJson(allocator, plan),
        };
    }
    return error.UnknownCommand;
}

fn usage(allocator: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
    return allocator.dupe(u8,
        \\zigeffect-storage-migrate
        \\
        \\commands:
        \\  schemas [--format text|json]
        \\  plan [--dialect postgresql|cockroachdb] [--format text|json]
        \\
    );
}

fn parseFormat(args: []const []const u8) StorageMigrateError!OutputFormat {
    var format: OutputFormat = .text;
    var index: usize = 0;
    while (index < args.len) {
        const flag = args[index];
        if (std.mem.eql(u8, flag, "--format")) {
            index += 1;
            if (index >= args.len) return error.MissingFlagValue;
            format = try parseOutputFormat(args[index]);
        } else {
            return error.UnknownFlag;
        }
        index += 1;
    }
    return format;
}

fn parsePlanArgs(args: []const []const u8) StorageMigrateError!PlanArgs {
    var parsed: PlanArgs = .{};
    var index: usize = 0;
    while (index < args.len) {
        const flag = args[index];
        if (std.mem.eql(u8, flag, "--format")) {
            index += 1;
            if (index >= args.len) return error.MissingFlagValue;
            parsed.format = try parseOutputFormat(args[index]);
        } else if (std.mem.eql(u8, flag, "--dialect")) {
            index += 1;
            if (index >= args.len) return error.MissingFlagValue;
            parsed.dialect = try parseDialect(args[index]);
        } else {
            return error.UnknownFlag;
        }
        index += 1;
    }
    return parsed;
}

fn parseOutputFormat(value: []const u8) StorageMigrateError!OutputFormat {
    if (std.mem.eql(u8, value, "text")) return .text;
    if (std.mem.eql(u8, value, "json")) return .json;
    return error.UnknownFormat;
}

fn parseDialect(value: []const u8) StorageMigrateError!fx.SqlStorageDialect {
    if (std.mem.eql(u8, value, "postgresql")) return .postgresql;
    if (std.mem.eql(u8, value, "cockroachdb")) return .cockroachdb;
    return error.UnknownDialect;
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const output = try runStorageMigrate(init.gpa, args[1..]);
    defer init.gpa.free(output);
    std.debug.print("{s}", .{output});
}

test "storage migrate schemas command formats text and json" {
    const text_args = [_][]const u8{"schemas"};
    const text = try runStorageMigrate(std.testing.allocator, &text_args);
    defer std.testing.allocator.free(text);
    try std.testing.expect(std.mem.indexOf(u8, text, "zigeffect storage schema catalog") != null);

    const json_args = [_][]const u8{ "schemas", "--format", "json" };
    const json = try runStorageMigrate(std.testing.allocator, &json_args);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema\":\"zigeffect.storage.catalog.v1\"") != null);
}

test "storage migrate plan command formats selected dialect" {
    const args = [_][]const u8{ "plan", "--dialect", "cockroachdb" };
    const text = try runStorageMigrate(std.testing.allocator, &args);
    defer std.testing.allocator.free(text);
    try std.testing.expect(std.mem.indexOf(u8, text, "cockroachdb") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "create_cluster_messages") != null);
}
