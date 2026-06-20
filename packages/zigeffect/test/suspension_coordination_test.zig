//! M1.2 — `SuspensionCoordinator.suspendOn{Deferred,Queue,Signal}` /
//! `resumeFrom{Deferred,Queue,Signal}`.
//!
//! Proves coordination-suspension causal edges: `fiber_suspended` →
//! (wakeup: `deferred_completed` | `queue_item_available` | `signal_raised`)
//! → `fiber_resumed{cause_event_id = wakeup}`. This is the symmetric extension
//! of the timer pattern (`fiber_suspended` → `timer_scheduled` → `timer_fired`
//! → `fiber_resumed`) to the three non-timer suspension kinds the engine
//! declared but had not yet wired into the causal graph — the highest-frequency
//! blind spot identified by the 2026-06-20 vision-vs-reality audit.

const std = @import("std");
const fx = @import("zigeffect");

fn deterministicBackend(state: *fx.LocalAsyncBackendState) fx.AsyncBackend {
    return state.backend();
}

fn buildRun(store: *fx.CausalStore) !struct { run_id: u64, scope_id: u64, fiber_id: u64, started: u64 } {
    const run_id = store.nextRunId();
    const scope_id = store.nextScopeId();
    const run_started = try store.record(.{ .kind = .run_started, .run_id = run_id, .status = "started", .label = "coord-scenario" });
    const scope_opened = try store.record(.{ .kind = .scope_opened, .run_id = run_id, .scope_id = scope_id, .parent_id = run_started, .status = "opened" });
    const forked = try store.record(.{ .kind = .fiber_forked, .run_id = run_id, .scope_id = scope_id, .fiber_id = 1, .parent_id = scope_opened, .status = "pending", .label = "coord fiber" });
    const started = try store.record(.{ .kind = .fiber_started, .run_id = run_id, .scope_id = scope_id, .fiber_id = 1, .parent_id = forked, .status = "running" });
    return .{ .run_id = run_id, .scope_id = scope_id, .fiber_id = 1, .started = started };
}

fn kindCount(snap: *fx.CausalSnapshot, kind: fx.CausalEventKind) usize {
    var n: usize = 0;
    for (snap.events) |event| if (event.kind == kind) {
        n += 1;
    };
    return n;
}

fn findFirst(snap: *fx.CausalSnapshot, kind: fx.CausalEventKind) ?fx.CausalEvent {
    for (snap.events) |event| if (event.kind == kind) return event;
    return null;
}

test "suspendOnDeferred + resumeFromDeferred emit fiber_suspended → deferred_completed → fiber_resumed" {
    const allocator = std.testing.allocator;
    var store = fx.CausalStore.init(allocator);
    defer store.deinit();
    var backend_state = fx.LocalAsyncBackendState.init(allocator, .{});
    defer backend_state.deinit();

    var coord = fx.SuspensionCoordinator.init(allocator, &store, deterministicBackend(&backend_state));
    defer coord.deinit();

    const run = try buildRun(&store);
    const sid = try coord.suspendOnDeferred(.{
        .fiber_id = run.fiber_id,
        .scope_id = run.scope_id,
        .run_id = run.run_id,
        .started_event_id = run.started,
        .caused_by_event_id = run.started,
        .label = "await one-shot value",
    });
    try coord.resumeFromDeferred(sid, "fiber resumed from deferred");

    var snap = try store.snapshot(allocator);
    defer snap.deinit();

    try std.testing.expectEqual(@as(usize, 1), kindCount(&snap, .fiber_suspended));
    try std.testing.expectEqual(@as(usize, 1), kindCount(&snap, .deferred_completed));
    try std.testing.expectEqual(@as(usize, 1), kindCount(&snap, .fiber_resumed));

    // The load-bearing cause edge.
    const wakeup = findFirst(&snap, .deferred_completed).?;
    const resumed = findFirst(&snap, .fiber_resumed).?;
    try std.testing.expectEqual(wakeup.id, resumed.cause_event_id.?);

    // No hang finding (suspend WAS paired with resume).
    var findings = try store.findings(allocator);
    defer findings.deinit();
    for (findings.items) |f| try std.testing.expect(f.kind != .fiber_suspended_without_resume);
}

test "suspendOnQueue + resumeFromQueue emit fiber_suspended → queue_item_available → fiber_resumed" {
    const allocator = std.testing.allocator;
    var store = fx.CausalStore.init(allocator);
    defer store.deinit();
    var backend_state = fx.LocalAsyncBackendState.init(allocator, .{});
    defer backend_state.deinit();

    var coord = fx.SuspensionCoordinator.init(allocator, &store, deterministicBackend(&backend_state));
    defer coord.deinit();

    const run = try buildRun(&store);
    const sid = try coord.suspendOnQueue(.{
        .fiber_id = run.fiber_id,
        .scope_id = run.scope_id,
        .run_id = run.run_id,
        .started_event_id = run.started,
        .caused_by_event_id = run.started,
        .label = "queue.take empty",
    });
    try coord.resumeFromQueue(sid, "fiber resumed from queue");

    var snap = try store.snapshot(allocator);
    defer snap.deinit();

    try std.testing.expectEqual(@as(usize, 1), kindCount(&snap, .queue_item_available));
    const wakeup = findFirst(&snap, .queue_item_available).?;
    const resumed = findFirst(&snap, .fiber_resumed).?;
    try std.testing.expectEqual(wakeup.id, resumed.cause_event_id.?);
}

test "suspendOnSignal + resumeFromSignal emit fiber_suspended → signal_raised → fiber_resumed" {
    const allocator = std.testing.allocator;
    var store = fx.CausalStore.init(allocator);
    defer store.deinit();
    var backend_state = fx.LocalAsyncBackendState.init(allocator, .{});
    defer backend_state.deinit();

    var coord = fx.SuspensionCoordinator.init(allocator, &store, deterministicBackend(&backend_state));
    defer coord.deinit();

    const run = try buildRun(&store);
    const sid = try coord.suspendOnSignal(.{
        .fiber_id = run.fiber_id,
        .scope_id = run.scope_id,
        .run_id = run.run_id,
        .started_event_id = run.started,
        .caused_by_event_id = run.started,
        .label = "semaphore acquire",
    });
    try coord.resumeFromSignal(sid, "fiber resumed from signal");

    var snap = try store.snapshot(allocator);
    defer snap.deinit();

    try std.testing.expectEqual(@as(usize, 1), kindCount(&snap, .signal_raised));
    const wakeup = findFirst(&snap, .signal_raised).?;
    const resumed = findFirst(&snap, .fiber_resumed).?;
    try std.testing.expectEqual(wakeup.id, resumed.cause_event_id.?);
}

test "suspendOnActivity + resumeFromActivity emit fiber_suspended → activity_completed → fiber_resumed" {
    const allocator = std.testing.allocator;
    var store = fx.CausalStore.init(allocator);
    defer store.deinit();
    var backend_state = fx.LocalAsyncBackendState.init(allocator, .{});
    defer backend_state.deinit();

    var coord = fx.SuspensionCoordinator.init(allocator, &store, deterministicBackend(&backend_state));
    defer coord.deinit();

    const run = try buildRun(&store);
    const sid = try coord.suspendOnActivity(.{
        .fiber_id = run.fiber_id,
        .scope_id = run.scope_id,
        .run_id = run.run_id,
        .started_event_id = run.started,
        .caused_by_event_id = run.started,
        .label = "await activity result",
    });
    try coord.resumeFromActivity(sid, "fiber resumed from activity");

    var snap = try store.snapshot(allocator);
    defer snap.deinit();

    try std.testing.expectEqual(@as(usize, 1), kindCount(&snap, .activity_completed));
    const wakeup = findFirst(&snap, .activity_completed).?;
    const resumed = findFirst(&snap, .fiber_resumed).?;
    try std.testing.expectEqual(wakeup.id, resumed.cause_event_id.?);
}

test "suspendOnExternal + resumeFromExternal emit fiber_suspended → external_signal_received → fiber_resumed" {
    const allocator = std.testing.allocator;
    var store = fx.CausalStore.init(allocator);
    defer store.deinit();
    var backend_state = fx.LocalAsyncBackendState.init(allocator, .{});
    defer backend_state.deinit();

    var coord = fx.SuspensionCoordinator.init(allocator, &store, deterministicBackend(&backend_state));
    defer coord.deinit();

    const run = try buildRun(&store);
    const sid = try coord.suspendOnExternal(.{
        .fiber_id = run.fiber_id,
        .scope_id = run.scope_id,
        .run_id = run.run_id,
        .started_event_id = run.started,
        .caused_by_event_id = run.started,
        .label = "await human approval",
    });
    try coord.resumeFromExternal(sid, "fiber resumed from external signal");

    var snap = try store.snapshot(allocator);
    defer snap.deinit();

    try std.testing.expectEqual(@as(usize, 1), kindCount(&snap, .external_signal_received));
    const wakeup = findFirst(&snap, .external_signal_received).?;
    const resumed = findFirst(&snap, .fiber_resumed).?;
    try std.testing.expectEqual(wakeup.id, resumed.cause_event_id.?);
}

test "coordination suspend with no resume fires the fiber_suspended_without_resume finding (hang detector)" {
    const allocator = std.testing.allocator;
    var store = fx.CausalStore.init(allocator);
    defer store.deinit();
    var backend_state = fx.LocalAsyncBackendState.init(allocator, .{});
    defer backend_state.deinit();

    var coord = fx.SuspensionCoordinator.init(allocator, &store, deterministicBackend(&backend_state));
    defer coord.deinit();

    const run = try buildRun(&store);
    _ = try coord.suspendOnDeferred(.{
        .fiber_id = run.fiber_id,
        .scope_id = run.scope_id,
        .run_id = run.run_id,
        .started_event_id = run.started,
        .caused_by_event_id = run.started,
    });
    // Intentionally NO resume — the H4 hang detector should catch this.

    var findings = try store.findings(allocator);
    defer findings.deinit();

    var saw_hang = false;
    for (findings.items) |f| {
        if (f.kind == .fiber_suspended_without_resume) saw_hang = true;
    }
    try std.testing.expect(saw_hang);
}

test "structural-equivalence: coordination suspend/resume is structurally identical regardless of resume label" {
    const allocator = std.testing.allocator;

    // Run A — descriptive label
    var store_a = fx.CausalStore.init(allocator);
    defer store_a.deinit();
    var backend_a = fx.LocalAsyncBackendState.init(allocator, .{});
    defer backend_a.deinit();
    var coord_a = fx.SuspensionCoordinator.init(allocator, &store_a, backend_a.backend());
    defer coord_a.deinit();
    const ra = try buildRun(&store_a);
    const sid_a = try coord_a.suspendOnDeferred(.{ .fiber_id = ra.fiber_id, .scope_id = ra.scope_id, .run_id = ra.run_id, .started_event_id = ra.started, .caused_by_event_id = ra.started });
    try coord_a.resumeFromDeferred(sid_a, "fiber resumed (label A)");

    // Run B — different label, identical shape
    var store_b = fx.CausalStore.init(allocator);
    defer store_b.deinit();
    var backend_b = fx.LocalAsyncBackendState.init(allocator, .{});
    defer backend_b.deinit();
    var coord_b = fx.SuspensionCoordinator.init(allocator, &store_b, backend_b.backend());
    defer coord_b.deinit();
    const rb = try buildRun(&store_b);
    const sid_b = try coord_b.suspendOnDeferred(.{ .fiber_id = rb.fiber_id, .scope_id = rb.scope_id, .run_id = rb.run_id, .started_event_id = rb.started, .caused_by_event_id = rb.started });
    try coord_b.resumeFromDeferred(sid_b, "fiber resumed (label B)");

    var snap_a = try store_a.snapshot(allocator);
    defer snap_a.deinit();
    var snap_b = try store_b.snapshot(allocator);
    defer snap_b.deinit();

    try std.testing.expect(try fx.causalStructurallyEquivalent(allocator, snap_a.events, snap_b.events));
}
