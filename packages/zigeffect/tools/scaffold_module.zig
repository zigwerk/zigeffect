const std = @import("std");

pub fn renderModuleTemplate(
    allocator: std.mem.Allocator,
    module_name: []const u8,
    service_name: []const u8,
) std.mem.Allocator.Error![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        \\# zigeffect module scaffold: {s}
        \\
        \\{s}/
        \\  service.zig
        \\  layer.zig
        \\  effects.zig
        \\  fixtures.zig
        \\  {s}_test.zig
        \\  README.md
        \\
        \\service.zig
        \\  pub const {s} = struct {{ ... }};
        \\  pub const Env = fx.ServiceEnv(.{{ {s} }});
        \\
        \\layer.zig
        \\  pub const layer = fx.Layer(Env).fromEnv(...).provides(.{{ {s} }});
        \\
        \\effects.zig
        \\  pub const Program = fx.Effect(Result, AppError, Env)
        \\      .fromFn(run)
        \\      .requires(.{{ {s} }});
        \\
        \\fixtures.zig
        \\  pub fn fakeLayer(env: *FakeEnv) return fx.Layer(FakeEnv).fromEnv(env).provides(.{{ {s} }});
        \\
        \\README.md
        \\  Document ownership, startup requirements, provided services, and test fixtures.
        \\
        ,
        .{
            module_name,
            module_name,
            module_name,
            service_name,
            service_name,
            service_name,
            service_name,
            service_name,
        },
    );
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, allocator);
    defer args.deinit();
    _ = args.skip();

    const module_name = if (args.next()) |value| value else "feature";
    const service_name = if (args.next()) |value| value else "FeatureService";

    const template = try renderModuleTemplate(allocator, module_name, service_name);
    defer allocator.free(template);
    std.debug.print("{s}", .{template});
}

test "module scaffold template includes expected files and contracts" {
    const rendered = try renderModuleTemplate(std.testing.allocator, "billing", "Ledger");
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "billing/") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "service.zig") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "layer.zig") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "effects.zig") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "fixtures.zig") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "billing_test.zig") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Ledger") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "fx.ServiceEnv") != null);
}
