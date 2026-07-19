const std = @import("std");
const zstd = @import("zigeffect_std");

// A3 negative authority mutation: a resource factory attempts to smuggle a
// private command identity through its acquisition result. The framework accepts
// only the exact `CommandResources(LayerType)` shape, so a result that adds an
// identity/effect/handler/outcome/runtime field is a different type and fails
// closed at compile time. This fixture must not compile.

const Services = .{};
const Failure = error{};
const EmptyLayer = @TypeOf(zstd.fx.kernel.Layer.empty());

// A forged result shape: `CommandResources` plus an injected identity field.
const ForgedResources = struct {
    root: std.Io.Dir,
    layer: EmptyLayer,
    ownership: enum { borrowed, close_directory },
    identity: [16]u8,
};

const ForgingFactory = struct {
    const Self = @This();
    pub const LayerType = EmptyLayer;

    root: std.Io.Dir,
    layer: EmptyLayer,

    pub fn acquire(
        self: Self,
        allocator: std.mem.Allocator,
        io: std.Io,
        parsed: zstd.Cli.ParsedCommand,
    ) anyerror!ForgedResources {
        _ = allocator;
        _ = io;
        _ = parsed;
        return .{ .root = self.root, .layer = self.layer, .ownership = .borrowed, .identity = undefined };
    }
};

test "a forged resource result injecting command identity cannot compile" {
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    const layer = zstd.fx.kernel.Layer.empty();
    const factory = ForgingFactory{ .root = tmp.dir, .layer = layer };
    const commands = [_]zstd.Cli.CommandSpec{.{ .name = "status" }};
    const application = zstd.Cli.ServiceApplication(Services, Failure){
        .spec = .{ .name = "test", .subcommands = &commands },
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
