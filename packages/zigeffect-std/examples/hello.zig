const std = @import("std");
const zstd = @import("zigeffect_std");

pub fn runHello(
    allocator: std.mem.Allocator,
    args: []const []const u8,
    console: *zstd.Console.CapturedConsole,
) !void {
    const command = zstd.Cli.CommandSpec{
        .name = "hello",
        .description = "print a greeting",
        .options = &.{
            .{
                .name = "name",
                .kind = .string,
                .required = true,
                .help = "name to greet",
            },
        },
    };

    var parsed = try zstd.Cli.parse(allocator, command, args);
    defer parsed.deinit(allocator);

    const name = parsed.optionValue("name").?;
    const message = try std.fmt.allocPrint(allocator, "Hello, {s}\n", .{name});
    defer allocator.free(message);

    try console.writeOut(message);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var console = zstd.Console.CapturedConsole.init(allocator);
    defer console.deinit();

    try runHello(allocator, &.{ "--name", "world" }, &console);
}

test "hello example writes a deterministic greeting" {
    var console = zstd.Console.CapturedConsole.init(std.testing.allocator);
    defer console.deinit();

    try runHello(std.testing.allocator, &.{ "--name", "Sean" }, &console);

    try std.testing.expectEqualStrings("Hello, Sean\n", console.stdoutText());
}
