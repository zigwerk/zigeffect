const std = @import("std");
const fx = @import("zigeffect");
const fixtures = @import("support/fixtures.zig");

fn expectCausalKinds(snapshot: fx.CausalSnapshot, expected: []const fx.CausalEventKind) !void {
    try std.testing.expectEqual(expected.len, snapshot.events.len);
    for (expected, 0..) |kind, index| {
        try std.testing.expectEqual(kind, snapshot.events[index].kind);
    }
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

    try expectCausalKinds(snapshot, &.{
        .run_started,
        .scope_opened,
        .scope_closed,
        .exit_recorded,
        .run_completed,
    });
    try std.testing.expectEqualStrings("Runtime.run", snapshot.events[0].label);
    try std.testing.expectEqualStrings("success", snapshot.events[3].status);
    try std.testing.expectEqual(snapshot.events[0].run_id.?, snapshot.events[3].run_id.?);
    try std.testing.expectEqual(snapshot.events[0].id, snapshot.events[1].parent_id.?);
    try std.testing.expectEqual(snapshot.events[1].id, snapshot.events[2].parent_id.?);
    try std.testing.expectEqual(snapshot.events[0].id, snapshot.events[3].parent_id.?);
    try std.testing.expectEqual(snapshot.events[0].id, snapshot.events[4].parent_id.?);
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

    try expectCausalKinds(snapshot, &.{
        .run_started,
        .scope_opened,
        .scope_closed,
        .exit_recorded,
        .run_completed,
    });
    try std.testing.expectEqualStrings("failure", snapshot.events[3].status);
    try std.testing.expectEqualStrings("Boom", snapshot.events[3].type_name);
    try std.testing.expectEqual(@as(?u64, 101), snapshot.events[0].trace_id);
    try std.testing.expectEqual(@as(?u64, 202), snapshot.events[0].span_id);
    try std.testing.expectEqual(@as(?u64, 101), snapshot.events[3].trace_id);
    try std.testing.expectEqual(@as(?u64, 202), snapshot.events[3].span_id);
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

    try expectCausalKinds(snapshot, &.{
        .run_started,
        .scope_opened,
        .scope_closed,
        .exit_recorded,
        .run_completed,
    });
    try std.testing.expectEqualStrings("failure", snapshot.events[3].status);
    try std.testing.expectEqualStrings("Boom", snapshot.events[3].type_name);
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

    try std.testing.expectEqual(@as(usize, 3), snapshot.events.len);
    try std.testing.expectEqual(fx.CausalEventKind.run_started, snapshot.events[0].kind);
    try std.testing.expectEqual(fx.CausalEventKind.exit_recorded, snapshot.events[1].kind);
    try std.testing.expectEqual(fx.CausalEventKind.run_completed, snapshot.events[2].kind);
    try std.testing.expectEqualStrings("Runtime.run", snapshot.events[0].label);
    try std.testing.expectEqualStrings("success", snapshot.events[1].status);
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

    try std.testing.expectEqual(@as(usize, 3), snapshot.events.len);
    try std.testing.expectEqual(fx.CausalEventKind.run_started, snapshot.events[0].kind);
    try std.testing.expectEqual(fx.CausalEventKind.exit_recorded, snapshot.events[1].kind);
    try std.testing.expectEqual(fx.CausalEventKind.run_completed, snapshot.events[2].kind);
    try std.testing.expectEqualStrings("Runtime.exit", snapshot.events[0].label);
    try std.testing.expectEqualStrings("failure", snapshot.events[1].status);
    try std.testing.expectEqualStrings("Boom", snapshot.events[1].type_name);
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

    try expectCausalKinds(snapshot, &.{
        .run_started,
        .scope_opened,
        .resource_acquired,
        .resource_finalized,
        .scope_closed,
        .exit_recorded,
        .run_completed,
    });
    try std.testing.expectEqualStrings(@typeName(fixtures.TrackedResource), snapshot.events[2].type_name);
    try std.testing.expectEqualStrings(@typeName(fixtures.TrackedResource), snapshot.events[3].type_name);
    try std.testing.expectEqualStrings("success", snapshot.events[3].status);
    try std.testing.expectEqual(snapshot.events[1].scope_id.?, snapshot.events[2].scope_id.?);
    try std.testing.expectEqual(snapshot.events[1].scope_id.?, snapshot.events[3].scope_id.?);
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

    try expectCausalKinds(snapshot, &.{
        .run_started,
        .scope_opened,
        .resource_acquired,
        .resource_finalized,
        .scope_closed,
        .exit_recorded,
        .run_completed,
    });
    try std.testing.expectEqualStrings(@typeName(fixtures.TrackedResource), snapshot.events[2].type_name);
    try std.testing.expectEqualStrings(@typeName(fixtures.TrackedResource), snapshot.events[3].type_name);
    try std.testing.expectEqualStrings("failure", snapshot.events[3].status);
    try std.testing.expectEqualStrings("CloseFailed", snapshot.events[3].redacted_detail);
    try std.testing.expectEqualStrings("cause", snapshot.events[5].status);
}
