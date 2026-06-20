const std = @import("std");
const fx = @import("zigeffect");

fn findOne(events: []fx.CausalEvent, kind: fx.CausalEventKind) ?fx.CausalEvent {
    for (events) |event| {
        if (event.kind == kind) return event;
    }
    return null;
}

// Builds the canonical deterministic delay scenario and returns an owned store +
// backend the caller must deinit. Virtual clock only — no real sleeping.
const Harness = struct {
    store: fx.CausalStore,
    backend_state: fx.LocalAsyncBackendState,
    anchors: fx.DelayScenarioAnchors,

    fn init(allocator: std.mem.Allocator) !Harness {
        var store = fx.CausalStore.init(allocator);
        errdefer store.deinit();
        var backend_state = fx.LocalAsyncBackendState.init(allocator, .{});
        errdefer backend_state.deinit();
        const anchors = try fx.recordDelaySuspensionScenario(allocator, &store, backend_state.backend(), 10);
        return .{ .store = store, .backend_state = backend_state, .anchors = anchors };
    }

    fn deinit(self: *Harness) void {
        self.store.deinit();
        self.backend_state.deinit();
    }
};

test "AC-1: a delayed fiber emits fiber_suspended before fiber_resumed for the same fiber" {
    const allocator = std.testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    var snap = try h.store.snapshot(allocator);
    defer snap.deinit();

    const suspended = findOne(snap.events, .fiber_suspended) orelse return error.MissingSuspended;
    const resumed = findOne(snap.events, .fiber_resumed) orelse return error.MissingResumed;
    try std.testing.expect(suspended.id < resumed.id);
    try std.testing.expectEqual(suspended.fiber_id, resumed.fiber_id);
    try std.testing.expectEqual(@as(?u64, h.anchors.fiber_id), suspended.fiber_id);
}

test "AC-2: the resume is caused by the timer firing (cause edge to timer_fired)" {
    const allocator = std.testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    var snap = try h.store.snapshot(allocator);
    defer snap.deinit();
    const resumed = findOne(snap.events, .fiber_resumed) orelse return error.MissingResumed;

    var chain = try h.store.cause(allocator, resumed.id);
    defer chain.deinit();
    try std.testing.expect(findOne(chain.events, .timer_fired) != null);
}

test "AC-3: timer_fired correlates to timer_scheduled by schedule_id, caused by the suspend" {
    const allocator = std.testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    var snap = try h.store.snapshot(allocator);
    defer snap.deinit();
    const scheduled = findOne(snap.events, .timer_scheduled) orelse return error.MissingScheduled;
    const fired = findOne(snap.events, .timer_fired) orelse return error.MissingFired;

    try std.testing.expect(scheduled.schedule_id != null);
    try std.testing.expectEqual(scheduled.schedule_id, fired.schedule_id);

    var chain = try h.store.cause(allocator, fired.id);
    defer chain.deinit();
    try std.testing.expect(findOne(chain.events, .timer_scheduled) != null);
    try std.testing.expect(findOne(chain.events, .fiber_suspended) != null);
}

test "AC-4: no fiber is left pending at run completion (no pending-fiber finding, fiber joined)" {
    const allocator = std.testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    var snap = try h.store.snapshot(allocator);
    defer snap.deinit();
    try std.testing.expect(findOne(snap.events, .fiber_joined) != null);

    var findings = try h.store.findings(allocator);
    defer findings.deinit();
    for (findings.items) |finding| {
        try std.testing.expect(finding.kind != .fiber_pending_after_scope_close);
    }
}

test "AC-5: suspension respects scope nesting (events fall between scope open and close)" {
    const allocator = std.testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    var snap = try h.store.snapshot(allocator);
    defer snap.deinit();
    const suspended = findOne(snap.events, .fiber_suspended).?;
    const fired = findOne(snap.events, .timer_fired).?;
    const resumed = findOne(snap.events, .fiber_resumed).?;

    try std.testing.expect(h.anchors.scope_opened_id < suspended.id);
    try std.testing.expect(suspended.id < fired.id);
    try std.testing.expect(fired.id < resumed.id);
    try std.testing.expect(resumed.id < h.anchors.scope_closed_id);
    try std.testing.expectEqual(@as(?u64, h.anchors.scope_id), suspended.scope_id);
    try std.testing.expectEqual(@as(?u64, h.anchors.scope_id), resumed.scope_id);
}

test "AC-6: deterministic virtual time only (no double-suspend, timer due <= advanced clock)" {
    const allocator = std.testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    const backend_snapshot = h.backend_state.backend().snapshot();
    try std.testing.expectEqual(@as(usize, 0), backend_snapshot.duplicate_suspend_count);
    // every scheduled timer was consumed: nothing left pending or ready
    try std.testing.expectEqual(@as(usize, 0), backend_snapshot.pending_count);
}

test "H4: a fiber suspended without resume produces a hang finding" {
    const allocator = std.testing.allocator;
    var store = fx.CausalStore.init(allocator);
    defer store.deinit();
    var backend_state = fx.LocalAsyncBackendState.init(allocator, .{});
    defer backend_state.deinit();

    _ = try fx.recordHangSuspensionScenario(allocator, &store, backend_state.backend(), 100);

    var findings = try store.findings(allocator);
    defer findings.deinit();

    var hang_findings: usize = 0;
    for (findings.items) |finding| {
        if (finding.kind == .fiber_suspended_without_resume) hang_findings += 1;
    }
    try std.testing.expectEqual(@as(usize, 1), hang_findings);
}

test "H4: the resolved delay scenario produces no hang finding" {
    const allocator = std.testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    var findings = try h.store.findings(allocator);
    defer findings.deinit();
    for (findings.items) |finding| {
        try std.testing.expect(finding.kind != .fiber_suspended_without_resume);
    }
}

test "H2: fiberStates reports net state — resolved for delay, parked for hang" {
    const allocator = std.testing.allocator;

    var h = try Harness.init(allocator);
    defer h.deinit();
    var delay_states = try h.store.fiberStates(allocator);
    defer delay_states.deinit();
    try std.testing.expectEqual(@as(usize, 1), delay_states.items.len);
    try std.testing.expect(delay_states.items[0].resolved);
    try std.testing.expect(!delay_states.items[0].parked);
    try std.testing.expectEqual(@as(usize, 0), delay_states.unresolvedCount());

    var store = fx.CausalStore.init(allocator);
    defer store.deinit();
    var backend_state = fx.LocalAsyncBackendState.init(allocator, .{});
    defer backend_state.deinit();
    _ = try fx.recordHangSuspensionScenario(allocator, &store, backend_state.backend(), 100);
    var hang_states = try store.fiberStates(allocator);
    defer hang_states.deinit();
    try std.testing.expectEqual(@as(usize, 1), hang_states.items.len);
    try std.testing.expect(!hang_states.items[0].resolved);
    try std.testing.expect(hang_states.items[0].parked);
    try std.testing.expectEqual(@as(usize, 1), hang_states.unresolvedCount());
}

test "suspension coordinator can be driven directly and reports pending count" {
    const allocator = std.testing.allocator;
    var store = fx.CausalStore.init(allocator);
    defer store.deinit();
    var backend_state = fx.LocalAsyncBackendState.init(allocator, .{});
    defer backend_state.deinit();

    var coordinator = fx.SuspensionCoordinator.init(allocator, &store, backend_state.backend());
    defer coordinator.deinit();

    _ = try coordinator.suspendOnTimer(.{ .fiber_id = 7, .run_id = 1, .due_time_ms = 25 });
    try std.testing.expectEqual(@as(usize, 1), coordinator.pendingCount());

    // advancing short of the due time resumes nothing
    try std.testing.expectEqual(@as(usize, 0), try coordinator.advanceAndResume(10));
    try std.testing.expectEqual(@as(usize, 1), coordinator.pendingCount());

    // advancing past the due time resumes the fiber exactly once
    try std.testing.expectEqual(@as(usize, 1), try coordinator.advanceAndResume(25));
    try std.testing.expectEqual(@as(usize, 0), coordinator.pendingCount());
    try std.testing.expectEqual(@as(usize, 0), try coordinator.advanceAndResume(100));
}
