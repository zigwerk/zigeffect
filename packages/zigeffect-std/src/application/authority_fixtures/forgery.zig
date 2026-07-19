const std = @import("std");
const zstd = @import("zigeffect_std");

// Shared producer for the resource-factory authority mutation matrix. Each
// sibling fixture declares one forbidden acquisition-result shape and drives it
// through `reject`. The supervisor accepts only the exact
// `CommandResources(LayerType)` payload, so every forbidden shape fails closed
// at compile time with the same stable diagnostic:
//
//   resource factory acquire must return CommandResources(LayerType)
//
// These fixtures are compiled in isolation by the supervisor test; they are not
// part of the normal `zig build test` graph.

pub const EmptyLayer = @TypeOf(zstd.fx.kernel.Layer.empty());
pub const Ownership = enum { borrowed, close_directory };

/// Instantiate `runOneShot` with a factory whose `acquire` returns `Forged`.
/// When `Forged` is anything other than the exact accepted result type, the
/// framework's compile-time `validateResourceFactory` rejects it. The `acquire`
/// body never executes, so returning `undefined` is sufficient to resolve the
/// signature the guard inspects.
pub fn reject(comptime Forged: type) !void {
    const Factory = struct {
        const Self = @This();
        pub const LayerType = EmptyLayer;

        root: std.Io.Dir,
        layer: EmptyLayer,

        pub fn acquire(
            self: Self,
            allocator: std.mem.Allocator,
            io: std.Io,
            parsed: zstd.Cli.ParsedCommand,
        ) anyerror!Forged {
            _ = self;
            _ = allocator;
            _ = io;
            _ = parsed;
            return undefined;
        }
    };

    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    const layer = zstd.fx.kernel.Layer.empty();
    const factory = Factory{ .root = tmp.dir, .layer = layer };
    const command_specs = [_]zstd.Cli.CommandSpec{.{ .name = "status" }};
    const application = zstd.Cli.ServiceApplication(.{}, error{}){
        .spec = .{ .name = "test", .subcommands = &command_specs },
        .handlers = &.{},
    };
    _ = try zstd.Application.runOneShot(
        @TypeOf(factory),
        @TypeOf(application),
        std.testing.allocator,
        std.testing.io,
        factory,
        application,
        &.{"status"},
        .{ .runtime = .{ .graph = .{ .path = "causal" } } },
    );
}
