//! Low-level engine schedule fixture; not application scaffolding.
//! Direct stores are used here only to prove framework causal behavior.

const std = @import("std");
const fx = @import("zigeffect");

const AppError = error{UpstreamUnavailable};

var attempts: u8 = 0;

fn unstableDependency(ctx: *fx.Context(fx.TestServices)) AppError!u32 {
    attempts += 1;
    if (attempts == 1) {
        _ = ctx.recordCausal(.{
            .kind = .exit_recorded,
            .label = "http dependency",
            .status = "failure",
            .type_name = "UpstreamUnavailable",
        });
    }
    return error.UpstreamUnavailable;
}

const Program = fx.Effect(u32, AppError, fx.TestServices)
    .fromFn(unstableDependency);

fn hasEvent(store: *const fx.CausalStore, kind: fx.CausalEventKind, status: []const u8) bool {
    for (store.events.items) |event| {
        if (event.kind == kind and std.mem.eql(u8, event.status, status)) return true;
    }
    return false;
}

fn runScenario(allocator: std.mem.Allocator, store: *fx.CausalStore) !void {
    attempts = 0;
    var env = try fx.TestEnv.init(allocator);
    defer env.deinit();

    var ctx = env.context().withCausalStore(store);
    var schedule = fx.Schedule.spaced(.{ .max_retries = 2, .delay_ms = 5 })
        .withLabel("retry-http-dependency");

    const value = Program.retry(&ctx, &schedule) catch |err| switch (err) {
        error.UpstreamUnavailable => return,
    };
    _ = value;
    return error.ExpectedRetryExhaustion;
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var store = fx.CausalStore.init(allocator);
    defer store.deinit();

    try runScenario(allocator, &store);

    const report = try fx.formatCausalReport(allocator, "retry exhaustion scenario", &store);
    defer allocator.free(report);
    std.debug.print("{s}", .{report});
}

test "retry exhaustion scenario records schedule decisions and first typed failure" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    try runScenario(std.testing.allocator, &store);

    try std.testing.expectEqual(@as(u8, 3), attempts);
    try std.testing.expect(hasEvent(&store, .exit_recorded, "failure"));
    try std.testing.expect(hasEvent(&store, .schedule_decision, "retry"));
    try std.testing.expect(hasEvent(&store, .schedule_decision, "exhausted"));
}
