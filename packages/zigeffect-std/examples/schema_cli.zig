const std = @import("std");
const zstd = @import("zigeffect_std");

const Args = struct {
    workspace: []const u8,
    port: i64,
    watch: bool,
    mode: ?[]const u8,
};

pub fn runSchemaCli(
    allocator: std.mem.Allocator,
    args: []const []const u8,
    env: ?*const zstd.Env.EnvMap,
    config: ?*const zstd.Config.LayeredConfig,
) ![]const u8 {
    const command = zstd.Cli.typedCommand(Args, .{
        .name = "schema-cli",
        .description = "decode local tool options",
        .version = "0.1.0",
    }, .{
        zstd.Cli.option("workspace", zstd.Schema.string().nonEmpty(), .{
            .long = "workspace",
            .env = "ZG_WORKSPACE",
            .config_key = "workspace",
            .required = true,
            .help = "workspace root",
        }),
        zstd.Cli.option("port", zstd.Schema.integer().min(1).max(65535), .{
            .long = "port",
            .default_value = "5178",
            .help = "local port",
        }),
        zstd.Cli.flag("watch", .{
            .long = "watch",
            .help = "watch files",
        }),
        zstd.Cli.option("mode", zstd.Schema.optional(zstd.Schema.stringEnum(&.{ "local", "ci" })), .{
            .long = "mode",
            .config_key = "mode",
            .help = "run mode",
        }),
    });

    var parsed = try zstd.Cli.parse(allocator, command.toCommandSpec(), args);
    defer parsed.deinit(allocator);

    var decoded = try zstd.Cli.decodeTypedCommandAlloc(allocator, command, parsed, env, config);
    defer decoded.deinit();

    if (!decoded.ok()) {
        return decoded.issues.jsonAlloc(allocator);
    }

    const value = decoded.value.?;
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.print(allocator, "workspace={s}\n", .{value.workspace});
    try output.print(allocator, "port={d}\n", .{value.port});
    try output.print(allocator, "watch={s}\n", .{if (value.watch) "true" else "false"});
    try output.print(allocator, "mode={s}\n", .{value.mode orelse "none"});
    try output.print(allocator, "source.workspace={s}\n", .{sourceName(decoded, "workspace")});
    try output.print(allocator, "source.port={s}\n", .{sourceName(decoded, "port")});
    try output.print(allocator, "source.watch={s}\n", .{sourceName(decoded, "watch")});
    try output.print(allocator, "source.mode={s}\n", .{sourceName(decoded, "mode")});

    return output.toOwnedSlice(allocator);
}

pub fn runSchemaCliIssuesJson(
    allocator: std.mem.Allocator,
    args: []const []const u8,
) ![]const u8 {
    const command = zstd.Cli.typedCommand(Args, .{
        .name = "schema-cli",
    }, .{
        zstd.Cli.option("workspace", zstd.Schema.string().nonEmpty(), .{
            .long = "workspace",
            .required = true,
            .secret = true,
        }),
        zstd.Cli.option("port", zstd.Schema.integer().min(1).max(10), .{
            .long = "port",
        }),
        zstd.Cli.flag("watch", .{
            .long = "watch",
        }),
        zstd.Cli.option("mode", zstd.Schema.optional(zstd.Schema.stringEnum(&.{ "local", "ci" })), .{
            .long = "mode",
        }),
    });

    var parsed = try zstd.Cli.parse(allocator, command.toCommandSpec(), args);
    defer parsed.deinit(allocator);

    var decoded = try zstd.Cli.decodeTypedCommandAlloc(allocator, command, parsed, null, null);
    defer decoded.deinit();

    return decoded.issues.jsonAlloc(allocator);
}

fn sourceName(decoded: anytype, name: []const u8) []const u8 {
    for (decoded.sources) |source| {
        if (std.mem.eql(u8, source.name, name)) return @tagName(source.source);
    }
    return "missing";
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var env = zstd.Env.EnvMap.init(allocator);
    defer env.deinit();
    var config = zstd.Config.LayeredConfig.init(allocator);
    defer config.deinit();
    try config.put("mode", "local", false);

    const output = try runSchemaCli(allocator, &.{ "--workspace", ".", "--watch" }, &env, &config);
    defer allocator.free(output);
    std.debug.print("{s}", .{output});
}

test "schema CLI decodes source precedence into deterministic output" {
    var env = zstd.Env.EnvMap.init(std.testing.allocator);
    defer env.deinit();
    try env.put("ZG_WORKSPACE", "/env/workspace");

    var config = zstd.Config.LayeredConfig.init(std.testing.allocator);
    defer config.deinit();
    try config.put("workspace", "/config/workspace", false);
    try config.put("mode", "ci", false);

    const output = try runSchemaCli(
        std.testing.allocator,
        &.{ "--workspace", "/cli/workspace", "--watch" },
        &env,
        &config,
    );
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "workspace=/cli/workspace") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "port=5178") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "watch=true") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "mode=ci") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "source.workspace=cli") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "source.port=default") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "source.mode=config") != null);
}

test "schema CLI returns redacted issue JSON for invalid input" {
    const issues = try runSchemaCliIssuesJson(
        std.testing.allocator,
        &.{ "--workspace", "token=abc123", "--port", "999999", "--mode", "prod" },
    );
    defer std.testing.allocator.free(issues);

    try std.testing.expect(std.mem.indexOf(u8, issues, "--port") != null);
    try std.testing.expect(std.mem.indexOf(u8, issues, "--mode") != null);
    try zstd.Testing.assertNoSentinelSecrets(issues);
    try std.testing.expect(std.mem.indexOf(u8, issues, "abc123") == null);
}
