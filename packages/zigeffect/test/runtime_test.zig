const std = @import("std");
const fx = @import("zigeffect");
const causal = @import("support/causal_assertions.zig");
const fixtures = @import("support/fixtures.zig");

fn resolveLogger(ctx: *fx.Context(fx.TestServices)) fixtures.TestError!void {
    _ = ctx.service(fx.Logger);
}

fn runNestedLoggerEffect(ctx: *fx.Context(fx.TestServices)) fixtures.TestError!void {
    const child = fx.Effect(void, fixtures.TestError, fx.TestServices)
        .fromFn(resolveLogger)
        .requires(.{fx.Logger});
    try ctx.runEffect(child);
}

fn hasAncestor(snapshot: fx.CausalSnapshot, event_id: u64, ancestor_id: u64) bool {
    var current = event_id;
    var remaining = snapshot.events.len;
    while (remaining > 0) : (remaining -= 1) {
        var parent: ?u64 = null;
        for (snapshot.events) |event| {
            if (event.id == current) {
                parent = event.parent_id;
                break;
            }
        }
        current = parent orelse return false;
        if (current == ancestor_id) return true;
    }
    return false;
}

test "runtime suspension names durable wait boundary" {
    const suspension = fx.Suspension{
        .kind = .timer,
        .id = 42,
        .label = "wake-up",
    };
    const decision = fx.RuntimeDecision{ .suspended = suspension };

    switch (decision) {
        .suspended => |value| {
            try std.testing.expectEqual(fx.SuspensionKind.timer, value.kind);
            try std.testing.expectEqual(@as(u64, 42), value.id);
            try std.testing.expectEqualStrings("wake-up", value.label);
        },
        else => return error.Empty,
    }
}

test "cancellation is cooperative and reason preserving" {
    var cancellation = fx.Cancellation.init();
    try std.testing.expect(!cancellation.isRequested());
    try std.testing.expect(cancellation.reason() == null);

    cancellation.request("workflow interrupted");

    try std.testing.expect(cancellation.isRequested());
    try std.testing.expectEqualStrings("workflow interrupted", cancellation.reason().?);
}

test "runtime automatically closes scoped resources after success" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    const program = fx.acquireRelease(
        fixtures.TrackedResource,
        fixtures.TestError,
        fx.TestServices,
        fixtures.acquireTracked,
        fixtures.releaseTracked,
    ).map(u32, fixtures.trackedId);

    try std.testing.expectEqual(@as(u32, 9), try env.run(program));
    try std.testing.expect(fixtures.tracked_resource_released);
}
test "runtime shared scope keeps resources until caller closes scope" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var app_scope = fx.Scope.init(std.testing.allocator);
    defer app_scope.deinit();

    var runtime = env.runtime().withScope(&app_scope);
    const program = fx.acquireRelease(
        fixtures.TrackedResource,
        fixtures.TestError,
        fx.TestServices,
        fixtures.acquireTracked,
        fixtures.releaseTracked,
    ).map(u32, fixtures.trackedId);

    try std.testing.expectEqual(@as(u32, 9), try runtime.run(program));
    try std.testing.expect(!fixtures.tracked_resource_released);

    app_scope.close();

    try std.testing.expect(fixtures.tracked_resource_released);
}
test "runtime shared scope releases immediately when scope is already closed" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var app_scope = fx.Scope.init(std.testing.allocator);
    defer app_scope.deinit();
    app_scope.close();

    var runtime = env.runtime().withScope(&app_scope);
    const program = fx.acquireRelease(
        fixtures.TrackedResource,
        fixtures.TestError,
        fx.TestServices,
        fixtures.acquireTracked,
        fixtures.releaseTracked,
    );

    try std.testing.expectError(error.MissingScope, runtime.run(program));
    try std.testing.expect(fixtures.tracked_resource_released);
}
test "runtime propagates trace context into effect context" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var runtime = env.runtime().withTraceContext(101, 202);
    const program = fx.Effect(void, fixtures.TestError, fx.TestServices)
        .fromFn(fixtures.logTraceContext)
        .requires(.{fx.Logger});

    try runtime.run(program);

    const entry = env.services.logger.structured_entries.items[0];
    try std.testing.expectEqual(@as(?u64, 101), entry.trace_id);
    try std.testing.expectEqual(@as(?u64, 202), entry.span_id);
}
test "runtime automatically closes scoped value resources after success" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var state = fixtures.FinalizerState{
        .allocator = std.testing.allocator,
        .order = .empty,
    };
    defer state.order.deinit(std.testing.allocator);
    fixtures.value_resource_state = &state;
    defer fixtures.value_resource_state = null;

    const program = fx.acquireReleaseValue(
        fixtures.ValueResource,
        fixtures.TestError,
        fx.TestServices,
        fixtures.acquireValueResourceA,
        fixtures.releaseValueResourceA,
    ).map(u32, fixtures.valueResourceId);

    try std.testing.expectEqual(@as(u32, 1), try env.run(program));
    try std.testing.expect(fixtures.value_resource_released);
    try std.testing.expectEqualStrings("a", state.order.items);
}
test "runtime automatically closes scoped resources after failure" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    const program = fx.acquireRelease(
        fixtures.TrackedResource,
        fixtures.TestError,
        fx.TestServices,
        fixtures.acquireTracked,
        fixtures.releaseTracked,
    ).flatMap(u32, fixtures.failAfterTracked);

    try std.testing.expectError(error.Boom, env.run(program));
    try std.testing.expect(fixtures.tracked_resource_released);
    try env.expectLog("failing after acquire");
}
test "runtime closes nested value resources in reverse acquisition order" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var state = fixtures.FinalizerState{
        .allocator = std.testing.allocator,
        .order = .empty,
    };
    defer state.order.deinit(std.testing.allocator);
    fixtures.value_resource_state = &state;
    defer fixtures.value_resource_state = null;

    const program = fx.Effect(u32, fixtures.TestError, fx.TestServices)
        .fromFn(fixtures.acquireNestedValueResources);

    try std.testing.expectEqual(@as(u32, 3), try env.run(program));
    try std.testing.expectEqualStrings("ba", state.order.items);
}
test "runtime exit reports finalizer failures as causes" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    const program = fx.Effect(*fixtures.TrackedResource, fixtures.TestError, fx.TestServices)
        .fromFn(fixtures.acquireTrackedWithFailingCleanup)
        .map(u32, fixtures.trackedId);

    const exit = env.exit(program);
    switch (exit) {
        .cause => |cause| switch (cause) {
            .finalizer_failure => |name| try std.testing.expectEqualStrings("CloseFailed", name),
            else => return error.Empty,
        },
        else => return error.Empty,
    }

    try std.testing.expect(fixtures.tracked_resource_released);
}
test "runtime exit preserves program failure plus cleanup failure" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    const program = fx.Effect(u32, fixtures.TestError, fx.TestServices)
        .fromFn(fixtures.acquireTrackedThenFailWithFailingCleanup);

    const exit = env.exit(program);
    switch (exit) {
        .cause => |cause| switch (cause) {
            .failure_then_finalizer_failure => |both| {
                try std.testing.expectEqual(error.Boom, both.failure);
                try std.testing.expectEqualStrings("CloseFailed", both.finalizer_failure);
            },
            else => return error.Empty,
        },
        else => return error.Empty,
    }

    try std.testing.expect(fixtures.tracked_resource_released);
}

test "runtime automatically parents nested effects and resolved services" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var runtime = env.runtime().withCausalStore(&store);
    const program = fx.Effect(void, fixtures.TestError, fx.TestServices)
        .fromFn(runNestedLoggerEffect)
        .requires(.{fx.Logger});

    try runtime.run(program);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    const run_started = try causal.expectEvent(snapshot, .{
        .kind = .run_started,
        .label = "Runtime.run",
    });
    const root_effect = blk: {
        for (snapshot.events) |event| {
            if (event.kind == .effect_started) break :blk event;
        }
        return error.ExpectedRootEffectMissing;
    };
    try std.testing.expect(root_effect.type_name.len <= 160);
    const child_effect = blk: {
        var seen_root = false;
        for (snapshot.events) |event| {
            if (event.kind != .effect_started) continue;
            if (!seen_root) {
                seen_root = true;
                continue;
            }
            break :blk event;
        }
        return error.ExpectedNestedEffectMissing;
    };
    const service = try causal.expectEvent(snapshot, .{
        .kind = .service_required,
        .type_name = @typeName(fx.Logger),
        .status = "resolved",
    });

    try std.testing.expectEqual(run_started.id, root_effect.parent_id.?);
    try std.testing.expectEqual(root_effect.id, child_effect.parent_id.?);
    try std.testing.expect(service.parent_id.? != root_effect.id);
    try std.testing.expect(hasAncestor(snapshot, service.id, child_effect.id));
}

test "caller-owned runtime scope keeps causal lineage until transport closes it" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    var request_scope = fx.Scope.init(std.testing.allocator);
    defer request_scope.deinit();

    var runtime = env.runtime()
        .withScope(&request_scope)
        .withCausalStore(&store);
    const program = fx.acquireRelease(
        fixtures.TrackedResource,
        fixtures.TestError,
        fx.TestServices,
        fixtures.acquireTracked,
        fixtures.releaseTracked,
    );

    _ = try runtime.run(program);
    try std.testing.expect(!fixtures.tracked_resource_released);
    request_scope.closeWithExit(.success);
    try std.testing.expect(fixtures.tracked_resource_released);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    const started = try causal.expectEvent(snapshot, .{ .kind = .run_started });
    const opened = try causal.expectEvent(snapshot, .{ .kind = .scope_opened });
    const acquired = try causal.expectEvent(snapshot, .{ .kind = .resource_acquired });
    const released = try causal.expectEvent(snapshot, .{ .kind = .resource_finalized });
    const closed = try causal.expectEvent(snapshot, .{ .kind = .scope_closed });

    try std.testing.expectEqual(started.id, opened.parent_id.?);
    try std.testing.expectEqual(opened.id, acquired.parent_id.?);
    try std.testing.expectEqual(acquired.id, released.parent_id.?);
    try std.testing.expectEqual(opened.id, closed.parent_id.?);
}

test "runtime emits causal run and exit events when store is attached" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var runtime = env.runtime().withCausalStore(&store);
    const program = fx.Effect([]const u8, fixtures.TestError, fx.TestServices).succeed("ok");

    try std.testing.expectEqualStrings("ok", try runtime.run(program));

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    try causal.expectEventSequence(snapshot, &.{
        .run_started,
        .scope_opened,
        .effect_started,
        .effect_completed,
        .scope_closed,
        .exit_recorded,
        .run_completed,
    });
    try std.testing.expectEqualStrings("Runtime.run", snapshot.events[0].label);
    try std.testing.expectEqualStrings("success", snapshot.events[5].status);
    try std.testing.expectEqual(snapshot.events[0].run_id.?, snapshot.events[5].run_id.?);
    try std.testing.expectEqual(snapshot.events[0].id, snapshot.events[1].parent_id.?);
    try std.testing.expectEqual(snapshot.events[0].id, snapshot.events[2].parent_id.?);
    try std.testing.expectEqual(snapshot.events[2].id, snapshot.events[3].parent_id.?);
    try std.testing.expectEqual(snapshot.events[1].id, snapshot.events[4].parent_id.?);
    try std.testing.expectEqual(snapshot.events[0].id, snapshot.events[5].parent_id.?);
    try std.testing.expectEqual(snapshot.events[0].id, snapshot.events[6].parent_id.?);
}

test "runtime causal events preserve failure and trace context" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var runtime = env.runtime()
        .withTraceContext(101, 202)
        .withCausalStore(&store);
    const program = fx.Effect(u32, fixtures.TestError, fx.TestServices).fromFn(fixtures.fails);

    try std.testing.expectError(error.Boom, runtime.run(program));

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    try causal.expectEventSequence(snapshot, &.{
        .run_started,
        .scope_opened,
        .effect_started,
        .effect_completed,
        .scope_closed,
        .exit_recorded,
        .run_completed,
    });
    try std.testing.expectEqualStrings("failure", snapshot.events[5].status);
    try std.testing.expectEqualStrings("Boom", snapshot.events[5].type_name);
    try std.testing.expectEqual(@as(?u64, 101), snapshot.events[0].trace_id);
    try std.testing.expectEqual(@as(?u64, 202), snapshot.events[0].span_id);
    try std.testing.expectEqual(@as(?u64, 101), snapshot.events[5].trace_id);
    try std.testing.expectEqual(@as(?u64, 202), snapshot.events[5].span_id);
}

test "runtime exit emits causal cause event when store is attached" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var runtime = env.runtime().withCausalStore(&store);
    const program = fx.Effect(u32, fixtures.TestError, fx.TestServices).fromFn(fixtures.fails);

    const exit = runtime.exit(program);
    switch (exit) {
        .failure => |err| try std.testing.expectEqual(error.Boom, err),
        else => return error.Empty,
    }

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    try causal.expectEventSequence(snapshot, &.{
        .run_started,
        .scope_opened,
        .effect_started,
        .effect_completed,
        .scope_closed,
        .exit_recorded,
        .run_completed,
    });
    try std.testing.expectEqualStrings("failure", snapshot.events[5].status);
    try std.testing.expectEqualStrings("Boom", snapshot.events[5].type_name);
}

test "shared scope runtime emits causal run events without closing caller scope" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var app_scope = fx.Scope.init(std.testing.allocator);
    defer app_scope.deinit();

    var runtime = env.runtime()
        .withScope(&app_scope)
        .withCausalStore(&store);
    const program = fx.Effect([]const u8, fixtures.TestError, fx.TestServices).succeed("ok");

    try std.testing.expectEqualStrings("ok", try runtime.run(program));
    try std.testing.expect(!app_scope.closed);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    try causal.expectEventSequence(snapshot, &.{
        .run_started,
        .scope_opened,
        .effect_started,
        .effect_completed,
        .exit_recorded,
        .run_completed,
    });
    try std.testing.expectEqualStrings("Runtime.run", snapshot.events[0].label);
    try std.testing.expectEqualStrings("success", snapshot.events[4].status);
}

test "shared scope runtime exit emits causal events without closing caller scope" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var app_scope = fx.Scope.init(std.testing.allocator);
    defer app_scope.deinit();

    var runtime = env.runtime()
        .withScope(&app_scope)
        .withCausalStore(&store);
    const program = fx.Effect(u32, fixtures.TestError, fx.TestServices).fromFn(fixtures.fails);

    const exit = runtime.exit(program);
    switch (exit) {
        .failure => |err| try std.testing.expectEqual(error.Boom, err),
        else => return error.Empty,
    }
    try std.testing.expect(!app_scope.closed);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    try causal.expectEventSequence(snapshot, &.{
        .run_started,
        .scope_opened,
        .effect_started,
        .effect_completed,
        .exit_recorded,
        .run_completed,
    });
    try std.testing.expectEqualStrings("Runtime.exit", snapshot.events[0].label);
    try std.testing.expectEqualStrings("failure", snapshot.events[4].status);
    try std.testing.expectEqualStrings("Boom", snapshot.events[4].type_name);
}

test "runtime causal events show resource acquisition and finalization" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var runtime = env.runtime().withCausalStore(&store);
    const program = fx.acquireRelease(
        fixtures.TrackedResource,
        fixtures.TestError,
        fx.TestServices,
        fixtures.acquireTracked,
        fixtures.releaseTracked,
    ).map(u32, fixtures.trackedId);

    try std.testing.expectEqual(@as(u32, 9), try runtime.run(program));

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    try causal.expectEventSequence(snapshot, &.{
        .run_started,
        .scope_opened,
        .effect_started,
        .effect_started,
        .resource_acquired,
        .effect_completed,
        .effect_completed,
        // H7a — scope_closed is now recorded BEFORE finalizers run so the
        // close event id is available when finalizer-triggered events
        // (e.g. a child fiber's interrupt) need it as their cause.
        .scope_closed,
        .resource_finalized,
        .exit_recorded,
        .run_completed,
    });
    try std.testing.expectEqualStrings(@typeName(fixtures.TrackedResource), snapshot.events[4].type_name);
    try std.testing.expectEqualStrings(@typeName(fixtures.TrackedResource), snapshot.events[8].type_name);
    try std.testing.expectEqualStrings("success", snapshot.events[8].status);
    try std.testing.expect(snapshot.events[4].resource_id != null);
    try std.testing.expectEqual(snapshot.events[4].resource_id, snapshot.events[8].resource_id);
    try std.testing.expectEqual(snapshot.events[4].id, snapshot.events[8].parent_id.?);
    try std.testing.expectEqual(snapshot.events[1].scope_id.?, snapshot.events[4].scope_id.?);
    try std.testing.expectEqual(snapshot.events[1].scope_id.?, snapshot.events[8].scope_id.?);
}

test "runtime causal events record finalizer failure evidence" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var runtime = env.runtime().withCausalStore(&store);
    const program = fx.Effect(*fixtures.TrackedResource, fixtures.TestError, fx.TestServices)
        .fromFn(fixtures.acquireTrackedWithFailingCleanup)
        .map(u32, fixtures.trackedId);

    const exit = runtime.exit(program);
    switch (exit) {
        .cause => |cause| switch (cause) {
            .finalizer_failure => |name| try std.testing.expectEqualStrings("CloseFailed", name),
            else => return error.Empty,
        },
        else => return error.Empty,
    }

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    try causal.expectEventSequence(snapshot, &.{
        .run_started,
        .scope_opened,
        .effect_started,
        .effect_started,
        .resource_acquired,
        .effect_completed,
        .effect_completed,
        // H7a — scope_closed is now recorded BEFORE finalizers run.
        .scope_closed,
        .resource_finalized,
        .exit_recorded,
        .run_completed,
    });
    try std.testing.expectEqualStrings(@typeName(fixtures.TrackedResource), snapshot.events[4].type_name);
    try std.testing.expectEqualStrings(@typeName(fixtures.TrackedResource), snapshot.events[8].type_name);
    try std.testing.expectEqualStrings("failure", snapshot.events[8].status);
    try std.testing.expectEqualStrings("CloseFailed", snapshot.events[8].redacted_detail);
    try std.testing.expect(snapshot.events[4].resource_id != null);
    try std.testing.expectEqual(snapshot.events[4].resource_id, snapshot.events[8].resource_id);
    try std.testing.expectEqual(snapshot.events[4].id, snapshot.events[8].parent_id.?);
    try std.testing.expectEqual(snapshot.events[4].id, snapshot.events[8].cause_event_id.?);
    try std.testing.expectEqualStrings("cause", snapshot.events[9].status);
}
