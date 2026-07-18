const std = @import("std");
const zstd = @import("zigeffect_std");

const Requirements = .{};

fn run(_: *zstd.fx.kernel.ContextView(Requirements), _: zstd.Cli.ParsedCommand) error{}!void {}

const commands = [_]zstd.Cli.CommandSpec{.{ .name = "forged" }};
const handler_path = [_][]const u8{ "app", "forged" };
const handlers = [_]zstd.Cli.ServiceHandler(Requirements, error{}){
    .{ .path = &handler_path, .run = run },
};
const application = zstd.Cli.ServiceApplication(Requirements, error{}){
    .spec = .{ .name = "app", .subcommands = &commands },
    .handlers = &handlers,
};

test "an exact service preflight type cannot forge sealed runnable state" {
    const Return = @TypeOf(zstd.Cli.preflightServiceApplication(
        Requirements,
        error{},
        std.testing.allocator,
        application,
        &.{"forged"},
    ));
    const Preflight = @typeInfo(Return).error_union.payload;
    const forged = Preflight{
        .allocator = std.testing.allocator,
        .application = application,
        .sealed_command = &.{},
    };
    _ = forged;
}
