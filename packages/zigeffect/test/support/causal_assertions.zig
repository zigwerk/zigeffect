const std = @import("std");
const fx = @import("zigeffect");

pub const EventPattern = struct {
    kind: fx.CausalEventKind,
    label: ?[]const u8 = null,
    type_name: ?[]const u8 = null,
    status: ?[]const u8 = null,
    detail_contains: ?[]const u8 = null,
};

fn matchesOptional(actual: []const u8, expected: ?[]const u8) bool {
    if (expected) |value| return std.mem.eql(u8, actual, value);
    return true;
}

fn containsOptional(actual: []const u8, expected: ?[]const u8) bool {
    if (expected) |value| return std.mem.indexOf(u8, actual, value) != null;
    return true;
}

pub fn expectEvent(snapshot: fx.CausalSnapshot, pattern: EventPattern) !fx.CausalEvent {
    for (snapshot.events) |event| {
        if (event.kind != pattern.kind) continue;
        if (!matchesOptional(event.label, pattern.label)) continue;
        if (!matchesOptional(event.type_name, pattern.type_name)) continue;
        if (!matchesOptional(event.status, pattern.status)) continue;
        if (!containsOptional(event.redacted_detail, pattern.detail_contains)) continue;
        return event;
    }
    return error.ExpectedCausalEventMissing;
}

pub fn expectEventSequence(snapshot: fx.CausalSnapshot, expected: []const fx.CausalEventKind) !void {
    try std.testing.expectEqual(expected.len, snapshot.events.len);
    for (expected, 0..) |kind, index| {
        try std.testing.expectEqual(kind, snapshot.events[index].kind);
    }
}

pub fn expectFinding(store: *const fx.CausalStore, kind: fx.CausalFindingKind) !fx.CausalFinding {
    var findings = try store.findings(std.testing.allocator);
    defer findings.deinit();

    for (findings.items) |finding| {
        if (finding.kind == kind) {
            return .{
                .kind = finding.kind,
                .event_id = finding.event_id,
                .run_id = finding.run_id,
                .scope_id = finding.scope_id,
                .fiber_id = finding.fiber_id,
            };
        }
    }
    return error.ExpectedCausalFindingMissing;
}

pub fn expectNoFindings(store: *const fx.CausalStore) !void {
    var findings = try store.findings(std.testing.allocator);
    defer findings.deinit();
    if (findings.items.len != 0) return error.UnexpectedCausalFinding;
}

test "causal assertions match event patterns and sequences" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    const run_id = store.nextRunId();
    const started = try store.record(.{ .kind = .run_started, .run_id = run_id, .label = "test-run" });
    _ = try store.record(.{
        .kind = .schedule_decision,
        .run_id = run_id,
        .parent_id = started,
        .label = "retry",
        .status = "exhausted",
        .redacted_detail = "attempt=2 delay_ms=null decision=exhausted",
    });

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    try expectEventSequence(snapshot, &.{ .run_started, .schedule_decision });
    const event = try expectEvent(snapshot, .{
        .kind = .schedule_decision,
        .label = "retry",
        .status = "exhausted",
        .detail_contains = "decision=exhausted",
    });
    try std.testing.expectEqual(started, event.parent_id.?);
}

test "causal assertions match findings and quiet stores" {
    var quiet = fx.CausalStore.init(std.testing.allocator);
    defer quiet.deinit();
    _ = try quiet.record(.{ .kind = .run_started, .label = "quiet" });
    try expectNoFindings(&quiet);

    var failing = fx.CausalStore.init(std.testing.allocator);
    defer failing.deinit();
    _ = try failing.record(.{
        .kind = .service_required,
        .type_name = @typeName(fx.Config),
        .status = "missing",
    });

    const finding = try expectFinding(&failing, .service_requirement_without_provider);
    try std.testing.expectEqual(fx.CausalFindingKind.service_requirement_without_provider, finding.kind);
    try std.testing.expect(finding.event_id > 0);
}
