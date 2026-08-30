const std = @import("std");
const fx = @import("zigeffect");
const zgroach = @import("zgroach");

test "validating non-empty source succeeds and records telemetry" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var ctx = env.context();
    const result = try zgroach.validateSource(&ctx, "database yachdee {}");

    try std.testing.expectEqual(@as(usize, 19), result.bytes);
    try std.testing.expectEqualStrings("valid", result.status);
    try std.testing.expectEqualStrings("zgroach.validate.start", env.services.tracing.events.items[0]);
    try std.testing.expectEqualStrings("zgroach.validate.ok", env.services.logger.entries.items[0]);
    try std.testing.expectEqual(@as(i64, 1), env.services.metrics.get("zgroach.validate.count"));
}

test "validating empty source fails with a compiler error" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var ctx = env.context();

    try std.testing.expectError(error.EmptySource, zgroach.validateSource(&ctx, " \n\t "));
    try std.testing.expectEqualStrings("zgroach.validate.start", env.services.tracing.events.items[0]);
    try std.testing.expectEqualStrings("zgroach.validate.empty", env.services.logger.entries.items[0]);
}

test "configured validation runs as a zigeffect program" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var ctx = env.context();
    try env.services.config.set("schema.path", "schema.rg");
    try env.services.fs.writeFile("schema.rg", "database yachdee {}");

    const result = try zgroach.validateCurrentSource().run(&ctx);

    try std.testing.expectEqual(@as(usize, 19), result.bytes);
    try env.expectLog("zgroach.validate.ok");
    try env.expectTrace("zgroach.validate.start");
}
