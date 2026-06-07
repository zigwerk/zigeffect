const std = @import("std");

const Artifact = struct {
    schema: ?[]const u8 = null,
    schema_version: ?u32 = null,
    events: []Event,
};

const Event = struct {
    id: u64,
    kind: []const u8,
    run_id: ?u64,
    parent_id: ?u64,
    fiber_id: ?u64,
    scope_id: ?u64,
    trace_id: ?u64,
    span_id: ?u64,
    label: []const u8,
    type_name: []const u8,
    status: []const u8,
    redacted_detail: []const u8,
};

const before_json =
    \\{
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"scenario","type_name":"Command","status":"started","redacted_detail":""},
    \\    {"id":2,"kind":"service_required","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"Config","type_name":"Config","status":"missing","redacted_detail":"missing provider"}
    \\  ]
    \\}
;

const after_json =
    \\{
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"scenario","type_name":"Command","status":"started","redacted_detail":""},
    \\    {"id":2,"kind":"service_required","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"Config","type_name":"Config","status":"provided","redacted_detail":"provider added"},
    \\    {"id":3,"kind":"exit_recorded","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"scenario","type_name":"Command","status":"success","redacted_detail":""}
    \\  ]
    \\}
;

const versioned_before_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 1,
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"scenario","type_name":"Command","status":"started","redacted_detail":""},
    \\    {"id":2,"kind":"service_required","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"Config","type_name":"Config","status":"missing","redacted_detail":"missing provider"}
    \\  ]
    \\}
;

const versioned_after_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 1,
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"scenario","type_name":"Command","status":"started","redacted_detail":""},
    \\    {"id":2,"kind":"service_required","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"Config","type_name":"Config","status":"provided","redacted_detail":"provider added"},
    \\    {"id":3,"kind":"exit_recorded","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"scenario","type_name":"Command","status":"success","redacted_detail":""}
    \\  ]
    \\}
;

const removed_json =
    \\{
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"scenario","type_name":"Command","status":"started","redacted_detail":""}
    \\  ]
    \\}
;

pub fn runCompare(allocator: std.mem.Allocator, before_json_input: []const u8, after_json_input: []const u8) ![]const u8 {
    var before_parsed = try std.json.parseFromSlice(Artifact, allocator, before_json_input, .{ .ignore_unknown_fields = true });
    defer before_parsed.deinit();
    var after_parsed = try std.json.parseFromSlice(Artifact, allocator, after_json_input, .{ .ignore_unknown_fields = true });
    defer after_parsed.deinit();

    const before_events = before_parsed.value.events;
    const after_events = after_parsed.value.events;
    const before_findings = findingCount(before_events);
    const after_findings = findingCount(after_events);

    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal compare report\n");
    try output.print(allocator, "before events: {d}\n", .{before_events.len});
    try output.print(allocator, "after events: {d}\n", .{after_events.len});
    try appendSignedDelta(&output, allocator, "event delta", @as(isize, @intCast(after_events.len)) - @as(isize, @intCast(before_events.len)));
    try output.print(allocator, "before findings: {d}\n", .{before_findings});
    try output.print(allocator, "after findings: {d}\n", .{after_findings});
    try appendSignedDelta(&output, allocator, "finding delta", @as(isize, @intCast(after_findings)) - @as(isize, @intCast(before_findings)));

    try output.appendSlice(allocator, "added events:\n");
    var added: usize = 0;
    for (after_events) |event| {
        if (findEvent(before_events, event.id) == null) {
            try appendEventLine(&output, allocator, "- event", event);
            added += 1;
        }
    }
    if (added == 0) try output.appendSlice(allocator, "- none\n");

    try output.appendSlice(allocator, "removed events:\n");
    var removed: usize = 0;
    for (before_events) |event| {
        if (findEvent(after_events, event.id) == null) {
            try appendEventLine(&output, allocator, "- event", event);
            removed += 1;
        }
    }
    if (removed == 0) try output.appendSlice(allocator, "- none\n");

    try output.appendSlice(allocator, "changed events:\n");
    var changed: usize = 0;
    for (before_events) |before_event| {
        if (findEvent(after_events, before_event.id)) |after_event| {
            if (!eventsEqual(before_event, after_event)) {
                try appendEventLine(&output, allocator, "- before event", before_event);
                try appendEventLine(&output, allocator, "- after event", after_event);
                changed += 1;
            }
        }
    }
    if (changed == 0) try output.appendSlice(allocator, "- none\n");

    return output.toOwnedSlice(allocator);
}

fn findEvent(events: []const Event, event_id: u64) ?Event {
    for (events) |event| {
        if (event.id == event_id) return event;
    }
    return null;
}

fn eventsEqual(left: Event, right: Event) bool {
    return left.id == right.id and
        std.mem.eql(u8, left.kind, right.kind) and
        left.run_id == right.run_id and
        left.parent_id == right.parent_id and
        left.fiber_id == right.fiber_id and
        left.scope_id == right.scope_id and
        left.trace_id == right.trace_id and
        left.span_id == right.span_id and
        std.mem.eql(u8, left.label, right.label) and
        std.mem.eql(u8, left.type_name, right.type_name) and
        std.mem.eql(u8, left.status, right.status) and
        std.mem.eql(u8, left.redacted_detail, right.redacted_detail);
}

fn findingCount(events: []const Event) usize {
    var count: usize = 0;
    for (events) |event| {
        if (std.mem.eql(u8, event.kind, "resource_acquired") and !hasFinalizedResource(events, event)) {
            count += 1;
        } else if (std.mem.eql(u8, event.kind, "scope_closed")) {
            count += pendingFiberCountAfterScopeClose(events, event);
        } else if (std.mem.eql(u8, event.kind, "resource_finalized") and std.mem.eql(u8, event.status, "failure")) {
            count += 1;
        } else if (std.mem.eql(u8, event.kind, "schedule_decision") and std.mem.eql(u8, event.status, "exhausted")) {
            count += 1;
        } else if (std.mem.eql(u8, event.kind, "service_required") and std.mem.eql(u8, event.status, "missing")) {
            count += 1;
        } else if (std.mem.eql(u8, event.kind, "assertion_recorded") and std.mem.eql(u8, event.status, "failure")) {
            count += 1;
        }
    }
    return count;
}

fn hasFinalizedResource(events: []const Event, acquired: Event) bool {
    for (events) |event| {
        if (!std.mem.eql(u8, event.kind, "resource_finalized")) continue;
        if (event.scope_id != acquired.scope_id) continue;
        if (!std.mem.eql(u8, event.type_name, acquired.type_name)) continue;
        return true;
    }
    return false;
}

fn pendingFiberCountAfterScopeClose(events: []const Event, closed: Event) usize {
    const scope_id = closed.scope_id orelse return 0;
    var count: usize = 0;
    for (events) |event| {
        if (event.scope_id != scope_id) continue;
        const fiber_id = event.fiber_id orelse continue;
        if (!std.mem.eql(u8, event.kind, "fiber_forked") and !std.mem.eql(u8, event.kind, "fiber_started")) continue;
        if (!std.mem.eql(u8, event.status, "pending") and !std.mem.eql(u8, event.status, "running")) continue;
        if (fiberCompletedAfter(events, fiber_id, closed.id)) continue;
        count += 1;
    }
    return count;
}

fn fiberCompletedAfter(events: []const Event, fiber_id: u64, closed_event_id: u64) bool {
    for (events) |event| {
        if (event.id < closed_event_id) continue;
        if (event.fiber_id != fiber_id) continue;
        if (std.mem.eql(u8, event.kind, "fiber_joined") or std.mem.eql(u8, event.kind, "fiber_interrupted")) return true;
    }
    return false;
}

fn appendSignedDelta(output: *std.ArrayList(u8), allocator: std.mem.Allocator, label: []const u8, delta: isize) std.mem.Allocator.Error!void {
    if (delta >= 0) {
        try output.print(allocator, "{s}: +{d}\n", .{ label, delta });
    } else {
        try output.print(allocator, "{s}: {d}\n", .{ label, delta });
    }
}

fn appendEventLine(output: *std.ArrayList(u8), allocator: std.mem.Allocator, prefix: []const u8, event: Event) std.mem.Allocator.Error!void {
    try output.print(allocator, "{s} id={d} kind={s}", .{ prefix, event.id, event.kind });
    if (event.run_id) |run_id| try output.print(allocator, " run={d}", .{run_id});
    if (event.scope_id) |scope_id| try output.print(allocator, " scope={d}", .{scope_id});
    if (event.fiber_id) |fiber_id| try output.print(allocator, " fiber={d}", .{fiber_id});
    if (event.label.len > 0) try output.print(allocator, " label={s}", .{event.label});
    if (event.type_name.len > 0) try output.print(allocator, " type={s}", .{event.type_name});
    if (event.status.len > 0) try output.print(allocator, " status={s}", .{event.status});
    try output.append(allocator, '\n');
}

fn usage() []const u8 {
    return "usage: zig build causal-compare -- <before.json> <after.json>\n";
}

fn failUsage() noreturn {
    std.debug.print("{s}", .{usage()});
    std.process.exit(1);
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) failUsage();

    const before = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], allocator, .limited(1024 * 1024));
    defer allocator.free(before);
    const after = try std.Io.Dir.cwd().readFileAlloc(init.io, args[2], allocator, .limited(1024 * 1024));
    defer allocator.free(after);

    const report = try runCompare(allocator, before, after);
    defer allocator.free(report);
    std.debug.print("{s}", .{report});
}

test "compare report includes event and finding deltas" {
    const report = try runCompare(std.testing.allocator, before_json, after_json);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal compare report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "before events: 2") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "after events: 3") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "event delta: +1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "before findings: 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "after findings: 0") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "finding delta: -1") != null);
}

test "compare accepts versioned causal artifacts" {
    const report = try runCompare(std.testing.allocator, versioned_before_json, versioned_after_json);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "before events: 2") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "after events: 3") != null);
}

test "compare report lists added removed and changed events" {
    const report = try runCompare(std.testing.allocator, before_json, after_json);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "added events:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "- event id=3 kind=exit_recorded") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "removed events:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "- none") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "changed events:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "- before event id=2 kind=service_required") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "- after event id=2 kind=service_required") != null);
}

test "compare report lists removed events" {
    const report = try runCompare(std.testing.allocator, before_json, removed_json);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "removed events:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "- event id=2 kind=service_required") != null);
}
