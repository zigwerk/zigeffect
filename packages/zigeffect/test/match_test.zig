const std = @import("std");
const fx = @import("zigeffect");

const Event = union(enum) {
    started,
    progress: u8,
    failed: []const u8,
};

fn onStarted() []const u8 {
    return "started";
}

fn onProgress(value: u8) []const u8 {
    if (value == 7) return "seven";
    return "progress";
}

fn onFailed(message: []const u8) []const u8 {
    return message;
}

fn onNone() []const u8 {
    return "none";
}

fn onSome(value: u8) []const u8 {
    if (value == 2) return "two";
    return "some";
}

fn onLeft(message: []const u8) []const u8 {
    return message;
}

fn onRight(value: u8) []const u8 {
    if (value == 5) return "five";
    return "right";
}

fn onCauseFailure(message: []const u8) []const u8 {
    return message;
}

fn onCauseDefect(_: []const u8) []const u8 {
    return "defect";
}

fn onCauseInterrupted(_: u64) []const u8 {
    return "interrupted";
}

fn onCauseFinalizerFailure(_: []const u8) []const u8 {
    return "finalizer";
}

fn onCauseFailureThenFinalizerFailure(_: fx.Cause([]const u8).FailureThenFinalizerFailure) []const u8 {
    return "failure+finalizer";
}

fn onCauseDefectThenFinalizerFailure(_: fx.Cause([]const u8).DefectThenFinalizerFailure) []const u8 {
    return "defect+finalizer";
}

fn onCauseInterruptedThenFinalizerFailure(_: fx.Cause([]const u8).InterruptedThenFinalizerFailure) []const u8 {
    return "interrupted+finalizer";
}

fn onCauseSequential(_: fx.Cause([]const u8).Sequential) []const u8 {
    return "sequential";
}

fn onCauseParallel(_: fx.Cause([]const u8).Parallel) []const u8 {
    return "parallel";
}

fn onCauseAnnotated(_: fx.Cause([]const u8).Annotated) []const u8 {
    return "annotated";
}

fn onExitSuccess(value: u8) []const u8 {
    if (value == 9) return "nine";
    return "success";
}

fn onExitFailure(message: []const u8) []const u8 {
    return message;
}

fn onExitDefect(_: []const u8) []const u8 {
    return "defect";
}

fn onExitInterrupted(_: u64) []const u8 {
    return "interrupted";
}

fn onExitCause(_: fx.Cause([]const u8)) []const u8 {
    return "cause";
}

test "match namespace exposes tagged union matcher entry points" {
    try std.testing.expect(@hasDecl(fx.match, "exhaustive"));
    try std.testing.expect(@hasDecl(fx.match, "partial"));
    try std.testing.expect(@hasDecl(fx.match, "orElse"));
    try std.testing.expect(@hasDecl(fx.match, "option"));
    try std.testing.expect(@hasDecl(fx.match, "either"));
}

test "tagged exhaustive dispatches by union tag" {
    try std.testing.expectEqualStrings("started", fx.match.exhaustive([]const u8, @as(Event, .started), .{
        .started = onStarted,
        .progress = onProgress,
        .failed = onFailed,
    }));
    try std.testing.expectEqualStrings("seven", fx.match.exhaustive([]const u8, Event{ .progress = 7 }, .{
        .started = onStarted,
        .progress = onProgress,
        .failed = onFailed,
    }));
}

test "tagged partial and orElse handle missing tags deliberately" {
    try std.testing.expect(fx.match.partial([]const u8, @as(Event, .started), .{
        .failed = onFailed,
    }) == null);
    try std.testing.expectEqualStrings("fallback", fx.match.orElse([]const u8, @as(Event, .started), .{
        .failed = onFailed,
    }, "fallback"));
}

test "Option and Either match through ergonomic methods" {
    try std.testing.expectEqualStrings("two", fx.Option(u8).some(2).match([]const u8, .{
        .none = onNone,
        .some = onSome,
    }));
    try std.testing.expectEqualStrings("none", fx.Option(u8).none().match([]const u8, .{
        .none = onNone,
        .some = onSome,
    }));
    try std.testing.expectEqualStrings("five", fx.Either(u8, []const u8).right(5).match([]const u8, .{
        .left = onLeft,
        .right = onRight,
    }));
    try std.testing.expectEqualStrings("bad", fx.Either(u8, []const u8).left("bad").match([]const u8, .{
        .left = onLeft,
        .right = onRight,
    }));
}

test "Cause and Exit expose match methods backed by tagged unions" {
    const cause: fx.Cause([]const u8) = .{ .failure = "failed" };
    try std.testing.expectEqualStrings("failed", cause.match([]const u8, .{
        .failure = onCauseFailure,
        .defect = onCauseDefect,
        .interrupted = onCauseInterrupted,
        .finalizer_failure = onCauseFinalizerFailure,
        .failure_then_finalizer_failure = onCauseFailureThenFinalizerFailure,
        .defect_then_finalizer_failure = onCauseDefectThenFinalizerFailure,
        .interrupted_then_finalizer_failure = onCauseInterruptedThenFinalizerFailure,
        .sequential = onCauseSequential,
        .parallel = onCauseParallel,
        .annotated = onCauseAnnotated,
    }));

    const exit: fx.Exit(u8, []const u8) = .{ .success = 9 };
    try std.testing.expectEqualStrings("nine", exit.match([]const u8, .{
        .success = onExitSuccess,
        .failure = onExitFailure,
        .defect = onExitDefect,
        .interrupted = onExitInterrupted,
        .cause = onExitCause,
    }));
}
