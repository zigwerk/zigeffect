//! M2.6 / H7a — live `cause_event_id` edges in arbitrary runtime transitions.
//!
//! Before this milestone, only the scenario harness (SuspensionCoordinator)
//! carried real cause edges; arbitrary live transitions propagated only
//! `parent_id`. `fiber_interrupted` events emitted from inside a finalizer-
//! triggered scope cancellation used the fiber's `fiber_forked` event as the
//! cause — accurate-but-useless ("the fiber was caused by being forked"). For
//! agent queries that ask "what cancelled this fiber?", the answer should be
//! the parent scope's `scope_closed`.
//!
//! This proves the fix: a parent scope that cancels a forked-in-scope child
//! produces a `fiber_interrupted` whose `cause_event_id` points at the
//! parent's `scope_closed`.

const std = @import("std");
const fx = @import("zigeffect");
const fixtures = @import("support/fixtures.zig");

test "H7a: fiber_interrupted.cause_event_id points at the parent scope's scope_closed" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var runtime = fx.FiberRuntime(fx.TestServices)
        .init(std.testing.allocator, &env.services)
        .withClock(&env.services.clock)
        .withCausalStore(&store)
        .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });
    defer runtime.deinit();

    // Open a parent scope so the child fiber can be forked into it (the
    // forkInScope path is the one that registers the LeaseFinalizer.interrupt).
    var parent_scope = fx.Scope.init(std.testing.allocator);
    defer parent_scope.deinit();
    const run_id = store.nextRunId();
    parent_scope.attachCausal(&store, run_id, null, null, null);

    const program = fx.Effect(u32, fixtures.TestError, fx.TestServices).succeed(7);
    const fiber = try runtime.forkInScope(&parent_scope, program);
    // Cancel the parent: scope_closed fires, then the LeaseFinalizer interrupts
    // the child. The interrupt's cause_event_id must point at scope_closed.
    parent_scope.close();
    _ = runtime.join(fiber);

    var snap = try store.snapshot(std.testing.allocator);
    defer snap.deinit();

    var scope_closed_id: ?u64 = null;
    var interrupt_cause: ?u64 = null;
    for (snap.events) |event| {
        if (event.kind == .scope_closed and event.scope_id == parent_scope.causal_scope_id) {
            scope_closed_id = event.id;
        }
        if (event.kind == .fiber_interrupted and event.fiber_id == fiber.id) {
            interrupt_cause = event.cause_event_id;
        }
    }

    try std.testing.expect(scope_closed_id != null);
    try std.testing.expect(interrupt_cause != null);
    // The load-bearing assertion: the live runtime now points the interrupt
    // cause at the actual scope_closed, not at the fiber_forked fallback.
    try std.testing.expectEqual(scope_closed_id.?, interrupt_cause.?);
}

test "H7a: a top-level (scope-less) interrupt still falls back to fiber_forked as the cause" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var runtime = fx.FiberRuntime(fx.TestServices)
        .init(std.testing.allocator, &env.services)
        .withClock(&env.services.clock)
        .withCausalStore(&store)
        .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });
    defer runtime.deinit();

    const program = fx.Effect(u32, fixtures.TestError, fx.TestServices).succeed(7);
    const fiber = try runtime.fork(program);
    runtime.interrupt(fiber);

    var snap = try store.snapshot(std.testing.allocator);
    defer snap.deinit();

    var forked_id: ?u64 = null;
    var interrupt_cause: ?u64 = null;
    for (snap.events) |event| {
        if (event.kind == .fiber_forked and event.fiber_id == fiber.id) forked_id = event.id;
        if (event.kind == .fiber_interrupted and event.fiber_id == fiber.id) interrupt_cause = event.cause_event_id;
    }
    try std.testing.expect(forked_id != null);
    try std.testing.expect(interrupt_cause != null);
    // No parent scope → fall back to the forked event id.
    try std.testing.expectEqual(forked_id.?, interrupt_cause.?);
}
