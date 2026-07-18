const std = @import("std");
const zstd = @import("zigeffect_std");

const MissingApi = struct {};
const Missing = zstd.fx.kernel.Service("zigeffect/std/test/MissingOneShotService", MissingApi);
const MissingServices = .{Missing};

test "one-shot command cannot compile without its required service" {
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    const layer = zstd.fx.kernel.Layer.empty();
    const Handler = struct {
        fn run(ctx: *zstd.fx.kernel.ContextView(MissingServices), _: zstd.Cli.ParsedCommand) error{}!void {
            _ = ctx.service(Missing);
        }
    };
    const commands = [_]zstd.Cli.CommandSpec{.{ .name = "status" }};
    const path = [_][]const u8{ "test", "status" };
    const handlers = [_]zstd.Cli.ServiceHandler(MissingServices, error{}){
        .{ .path = &path, .run = Handler.run },
    };
    const application = zstd.Cli.ServiceApplication(MissingServices, error{}){
        .spec = .{ .name = "test", .subcommands = &commands },
        .handlers = &handlers,
    };
    _ = try zstd.Application.runOneShot(
        @TypeOf(layer),
        @TypeOf(application),
        std.testing.allocator,
        std.testing.io,
        tmp.dir,
        layer,
        application,
        &.{"status"},
        .{ .runtime = .{ .graph = .{ .path = "causal" } } },
    );
}
