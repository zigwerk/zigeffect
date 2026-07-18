const std = @import("std");
const zstd = @import("zigeffect_std");

const Services = .{};
const Failure = error{};
const CanonicalApplication = zstd.Cli.ServiceApplication(Services, Failure);

const IdentityHandoff = struct {
    bytes: [128]u8 = [_]u8{0} ** 128,
    len: u8 = 0,
};

const WrappedApplication = struct {
    pub const service_application_kind = CanonicalApplication.service_application_kind;
    pub const RequiredServices = CanonicalApplication.RequiredServices;
    pub const FailureType = CanonicalApplication.FailureType;
    pub const SuccessType = CanonicalApplication.SuccessType;

    spec: zstd.Cli.CommandSpec,
    version: []const u8 = "",
    help: ?[]const u8 = null,
    handlers: []const zstd.Cli.ServiceHandler(Services, Failure),
    payload: ?*const IdentityHandoff = null,

    pub fn findHandler(_: WrappedApplication, _: zstd.Cli.ParsedCommand) ?zstd.Cli.ServiceHandler(Services, Failure) {
        return null;
    }
};

test "one-shot rejects an application-shaped identity handoff wrapper" {
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    const layer = zstd.fx.kernel.Layer.empty();
    const application = WrappedApplication{
        .spec = .{ .name = "test" },
        .handlers = &.{},
    };
    _ = try zstd.Application.runOneShot(
        @TypeOf(layer),
        WrappedApplication,
        std.testing.allocator,
        std.testing.io,
        tmp.dir,
        layer,
        application,
        &.{"status"},
        .{ .runtime = .{ .graph = .{ .path = "causal" } } },
    );
}
