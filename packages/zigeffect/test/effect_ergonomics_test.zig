//! Track 3 (M3.1–M3.4, M3.8–M3.9) — Effect ergonomics M1.
//!
//! Proves the small daily-use combinators (`as`, `replace`, `asVoid`,
//! `andThen`, `when`, `unless`) compose into the existing pipeline and produce
//! the documented semantics. Each combinator gets its own test.

const std = @import("std");
const fx = @import("zigeffect");
const fixtures = @import("support/fixtures.zig");

const E = fx.Effect(u32, fixtures.TestError, fx.TestServices);

fn runtime(env: *fx.TestEnv) fx.Runtime(fx.TestServices) {
    return fx.Runtime(fx.TestServices)
        .init(std.testing.allocator, &env.services)
        .withClock(&env.services.clock)
        .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });
}

test "M3.1 — as replaces success with the stored constant" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();
    var rt = runtime(&env);

    const program = E.succeed(7).as([]const u8, "replaced");
    const value = try rt.run(program);
    try std.testing.expectEqualStrings("replaced", value);
}

test "M3.2 — replace is an alias of as" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();
    var rt = runtime(&env);

    const program = E.succeed(7).replace(u32, 99);
    const value = try rt.run(program);
    try std.testing.expectEqual(@as(u32, 99), value);
}

test "M3.3 — asVoid discards the success" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();
    var rt = runtime(&env);

    const program = E.succeed(7).asVoid();
    try rt.run(program);
}

const Plus3 = struct {
    fn run(value: u32, ctx: *fx.Context(fx.TestServices)) fixtures.TestError!u32 {
        _ = ctx;
        return value + 3;
    }
};

test "M3.4 — andThen is an alias of flatMap" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();
    var rt = runtime(&env);

    const program = E.succeed(7).andThen(u32, Plus3.run);
    const value = try rt.run(program);
    try std.testing.expectEqual(@as(u32, 10), value);
}

test "M3.8 — when(true) runs the effect and yields ?Success = some" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();
    var rt = runtime(&env);

    const program = E.succeed(7).when(true);
    const value = try rt.run(program);
    try std.testing.expect(value != null);
    try std.testing.expectEqual(@as(u32, 7), value.?);
}

test "M3.8 — when(false) skips the effect and yields null" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();
    var rt = runtime(&env);

    const program = E.succeed(7).when(false);
    const value = try rt.run(program);
    try std.testing.expect(value == null);
}

test "M3.9 — unless(false) runs the effect, unless(true) skips it" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();
    var rt = runtime(&env);

    const ran = try rt.run(E.succeed(7).unless(false));
    try std.testing.expectEqual(@as(u32, 7), ran.?);

    const skipped = try rt.run(E.succeed(7).unless(true));
    try std.testing.expect(skipped == null);
}

test "M3.5 — zip pairs two successes into a ZipPair struct" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();
    var rt = runtime(&env);

    const program = E.succeed(7).zip(E.succeed(11));
    const value = try rt.run(program);
    try std.testing.expectEqual(@as(u32, 7), value.left);
    try std.testing.expectEqual(@as(u32, 11), value.right);
}

const Sum = struct {
    fn add(a: u32, b: u32) u32 {
        return a + b;
    }
};

test "M3.6 — zipWith applies the combiner" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();
    var rt = runtime(&env);

    const program = E.succeed(7).zipWith(E.succeed(11), u32, Sum.add);
    const value = try rt.run(program);
    try std.testing.expectEqual(@as(u32, 18), value);
}

test "M3.7 — all gathers a homogeneous slice of effects sequentially" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();
    var rt = runtime(&env);

    const items = [_]E{ E.succeed(1), E.succeed(2), E.succeed(3) };
    const program = fx.all(E, fixtures.TestError, fx.TestServices, &items);
    const results = try rt.run(program);
    defer std.testing.allocator.free(results);

    try std.testing.expectEqualSlices(u32, &.{ 1, 2, 3 }, results);
}

test "M3.7 — all short-circuits on first failure" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();
    var rt = runtime(&env);

    const items = [_]E{ E.succeed(1), E.fail(error.Boom), E.succeed(3) };
    const program = fx.all(E, fixtures.TestError, fx.TestServices, &items);
    const result = rt.run(program);
    try std.testing.expectError(error.Boom, result);
}

test "ergonomics compose with the existing pipeline (e.g. .map after .as)" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();
    var rt = runtime(&env);

    const Triple = struct {
        fn run(value: u32) u32 {
            return value * 3;
        }
    };
    const program = E.succeed(7).replace(u32, 5).map(u32, Triple.run);
    const value = try rt.run(program);
    try std.testing.expectEqual(@as(u32, 15), value);
}
