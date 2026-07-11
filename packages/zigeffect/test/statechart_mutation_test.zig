const std = @import("std");
const fx = @import("zigeffect");

const State = enum { idle, running, done };
const Event = enum { start, finish };
const Def = fx.statechart.Definition(State, Event, void, void);
const Catalog = fx.statechart.MutationCatalog(Def);

fn allowed(_: *const void, _: *const Event) bool {
    return true;
}

const definition = Def.init(.{
    .id = "agent.mutation",
    .version = 1,
    .initial = .idle,
    .states = &.{ .{ .id = .idle }, .{ .id = .running }, .{ .id = .done, .kind = .final } },
    .transitions = &.{
        .{ .id = "start", .source = .idle, .event = .start, .target = .running, .guard = .{ .id = "allowed", .evaluate = allowed } },
        .{ .id = "finish", .source = .running, .event = .finish, .target = .done },
    },
});

test "statechart mutation catalog enumerates stable deletion guard and target models" {
    const left = Catalog.enumerate(&definition);
    const right = Catalog.enumerate(&definition);
    try std.testing.expectEqual(left.fingerprint, right.fingerprint);
    try std.testing.expectEqualSlices(Catalog.Point, left.points(), right.points());
    var removed = false;
    var inverted = false;
    var redirected = false;
    for (left.points()) |point| switch (point.kind) {
        .transition_removed => removed = true,
        .guard_inverted => inverted = true,
        .target_redirected => redirected = true,
    };
    try std.testing.expect(removed and inverted and redirected);
    try std.testing.expect(!left.truncated);
}
