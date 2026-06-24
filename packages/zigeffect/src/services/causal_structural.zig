const std = @import("std");
const causal = @import("causal.zig");

pub const Allocator = std.mem.Allocator;
pub const CausalEvent = causal.CausalEvent;
pub const CausalEventKind = causal.CausalEventKind;

const Fact = struct { key: []const u8, count: usize };

fn bumpFact(allocator: Allocator, facts: *std.ArrayList(Fact), key: []const u8) Allocator.Error!void {
    for (facts.items) |*fact| {
        if (std.mem.eql(u8, fact.key, key)) {
            fact.count += 1;
            return;
        }
    }
    try facts.append(allocator, .{ .key = try allocator.dupe(u8, key), .count = 1 });
}

fn freeFacts(allocator: Allocator, facts: *std.ArrayList(Fact)) void {
    for (facts.items) |fact| allocator.free(fact.key);
    facts.deinit(allocator);
}

fn factCountFor(facts: []const Fact, key: []const u8) usize {
    for (facts) |fact| {
        if (std.mem.eql(u8, fact.key, key)) return fact.count;
    }
    return 0;
}

fn kindOfEvent(events: []const CausalEvent, id: u64) ?CausalEventKind {
    for (events) |event| {
        if (event.id == id) return event.kind;
    }
    return null;
}

fn isResourceLifecycleKind(kind: CausalEventKind) bool {
    return kind == .resource_acquired or kind == .resource_finalized;
}

fn sortedKindNames(a: CausalEventKind, b: CausalEventKind) struct { first: []const u8, second: []const u8 } {
    const a_name = @tagName(a);
    const b_name = @tagName(b);
    if (std.mem.lessThan(u8, b_name, a_name)) {
        return .{ .first = b_name, .second = a_name };
    }
    return .{ .first = a_name, .second = b_name };
}

fn appendOrderedKindPairFact(
    allocator: Allocator,
    facts: *std.ArrayList(Fact),
    prefix: []const u8,
    parent_kind: CausalEventKind,
    child_kind: CausalEventKind,
) Allocator.Error!void {
    const key = try std.fmt.allocPrint(allocator, "{s}:{s}->{s}", .{
        prefix,
        @tagName(parent_kind),
        @tagName(child_kind),
    });
    defer allocator.free(key);
    try bumpFact(allocator, facts, key);
}

fn appendUnorderedKindPairFact(
    allocator: Allocator,
    facts: *std.ArrayList(Fact),
    prefix: []const u8,
    left_kind: CausalEventKind,
    right_kind: CausalEventKind,
) Allocator.Error!void {
    const names = sortedKindNames(left_kind, right_kind);
    const key = try std.fmt.allocPrint(allocator, "{s}:{s}|{s}", .{ prefix, names.first, names.second });
    defer allocator.free(key);
    try bumpFact(allocator, facts, key);
}

fn fiberScopeRelation(left: CausalEvent, right: CausalEvent) []const u8 {
    if (left.scope_id == null and right.scope_id == null) return "none";
    if (left.scope_id == null or right.scope_id == null) return "partial";
    if (left.scope_id.? == right.scope_id.?) return "same";
    return "different";
}

const OwnerState = enum { absent, known, unknown };

fn ownerStateName(state: OwnerState) []const u8 {
    return switch (state) {
        .absent => "absent",
        .known => "known",
        .unknown => "unknown",
    };
}

fn scopeOwnerState(events: []const CausalEvent, scope_id: ?u64) OwnerState {
    const expected = scope_id orelse return .absent;
    for (events) |event| {
        if (event.scope_id != expected) continue;
        if (event.kind == .scope_opened or event.kind == .scope_closed) return .known;
    }
    return .unknown;
}

fn resourceOwnerState(events: []const CausalEvent, resource_id: ?u64) OwnerState {
    const expected = resource_id orelse return .absent;
    for (events) |event| {
        if (event.resource_id != expected) continue;
        if (isResourceLifecycleKind(event.kind)) return .known;
    }
    return .unknown;
}

fn fiberOwnerState(events: []const CausalEvent, fiber_id: ?u64) OwnerState {
    const expected = fiber_id orelse return .absent;
    for (events) |event| {
        if (event.fiber_id != expected) continue;
        if (causal.isFiberLifecycleKind(event.kind)) return .known;
    }
    return .unknown;
}

/// Build the structural facts of a causal trace, ignoring event ids and ordering:
///   - the multiset of event kinds
///   - the multiset of cause-edge kind pairs (cause.kind -> effect.kind)
///   - the multiset of parent-edge kind pairs (parent.kind -> child.kind)
///   - same-scope, same-resource, and same-fiber ownership relationships
///   - diagnostic ownership for finding-evidence events
///   - the multiset of per-fiber net (latest) lifecycle kinds
/// These hold across backends (deterministic vs zio) for the same program.
fn buildFacts(allocator: Allocator, events: []const CausalEvent) Allocator.Error!std.ArrayList(Fact) {
    var facts = std.ArrayList(Fact).empty;
    errdefer freeFacts(allocator, &facts);

    for (events) |event| {
        const key = try std.fmt.allocPrint(allocator, "kind:{s}", .{@tagName(event.kind)});
        defer allocator.free(key);
        try bumpFact(allocator, &facts, key);
    }
    for (events) |event| {
        const cause_id = event.cause_event_id orelse continue;
        const cause_kind = kindOfEvent(events, cause_id) orelse continue;
        try appendOrderedKindPairFact(allocator, &facts, "cause", cause_kind, event.kind);
    }
    for (events) |event| {
        const parent_id = event.parent_id orelse continue;
        const parent_kind = kindOfEvent(events, parent_id) orelse continue;
        try appendOrderedKindPairFact(allocator, &facts, "parent", parent_kind, event.kind);
    }
    var scope_i: usize = 0;
    while (scope_i < events.len) : (scope_i += 1) {
        const event = events[scope_i];
        const scope_id = event.scope_id orelse continue;
        var scope_j = scope_i + 1;
        while (scope_j < events.len) : (scope_j += 1) {
            const other = events[scope_j];
            if (other.scope_id == null or other.scope_id.? != scope_id) continue;
            try appendUnorderedKindPairFact(allocator, &facts, "scope-pair", event.kind, other.kind);
        }
    }
    var resource_i: usize = 0;
    while (resource_i < events.len) : (resource_i += 1) {
        const event = events[resource_i];
        if (!isResourceLifecycleKind(event.kind)) continue;
        const resource_id = event.resource_id orelse continue;
        var resource_j = resource_i + 1;
        while (resource_j < events.len) : (resource_j += 1) {
            const other = events[resource_j];
            if (!isResourceLifecycleKind(other.kind)) continue;
            if (other.resource_id == null or other.resource_id.? != resource_id) continue;
            try appendUnorderedKindPairFact(allocator, &facts, "resource-pair", event.kind, other.kind);
        }
    }
    var fiber_i: usize = 0;
    while (fiber_i < events.len) : (fiber_i += 1) {
        const event = events[fiber_i];
        if (!causal.isFiberLifecycleKind(event.kind)) continue;
        const fiber_id = event.fiber_id orelse continue;
        var fiber_j = fiber_i + 1;
        while (fiber_j < events.len) : (fiber_j += 1) {
            const other = events[fiber_j];
            if (!causal.isFiberLifecycleKind(other.kind)) continue;
            if (other.fiber_id == null or other.fiber_id.? != fiber_id) continue;
            const names = sortedKindNames(event.kind, other.kind);
            const key = try std.fmt.allocPrint(allocator, "fiber-pair:{s}|{s}:scope={s}", .{
                names.first,
                names.second,
                fiberScopeRelation(event, other),
            });
            defer allocator.free(key);
            try bumpFact(allocator, &facts, key);
        }
    }
    for (events) |event| {
        if (!causal.isCausalFindingEvidenceEvent(event.kind)) continue;
        const key = try std.fmt.allocPrint(allocator, "finding-owner:{s}:scope={s}:fiber={s}:resource={s}", .{
            @tagName(event.kind),
            ownerStateName(scopeOwnerState(events, event.scope_id)),
            ownerStateName(fiberOwnerState(events, event.fiber_id)),
            ownerStateName(resourceOwnerState(events, event.resource_id)),
        });
        defer allocator.free(key);
        try bumpFact(allocator, &facts, key);
    }
    for (events) |event| {
        if (!causal.isFiberLifecycleKind(event.kind)) continue;
        const fiber_id = event.fiber_id orelse continue;
        var is_latest = true;
        for (events) |other| {
            if (other.id <= event.id) continue;
            if (!causal.isFiberLifecycleKind(other.kind)) continue;
            const other_fiber = other.fiber_id orelse continue;
            if (other_fiber == fiber_id) {
                is_latest = false;
                break;
            }
        }
        if (!is_latest) continue;
        const key = try std.fmt.allocPrint(allocator, "fiber-net:{s}", .{@tagName(event.kind)});
        defer allocator.free(key);
        try bumpFact(allocator, &facts, key);
    }
    return facts;
}

/// True iff two causal traces are structurally equivalent — same program shape
/// regardless of event ids or ordering. This is the in-engine counterpart of
/// `causal-compare --structural`, usable directly on `CausalStore` snapshots: it
/// is how a deterministic run and a real (zio) run of the same program are
/// proven equivalent even though real scheduling reorders the events.
pub fn structurallyEquivalent(allocator: Allocator, left: []const CausalEvent, right: []const CausalEvent) Allocator.Error!bool {
    var left_facts = try buildFacts(allocator, left);
    defer freeFacts(allocator, &left_facts);
    var right_facts = try buildFacts(allocator, right);
    defer freeFacts(allocator, &right_facts);

    if (left_facts.items.len != right_facts.items.len) return false;
    for (left_facts.items) |fact| {
        if (factCountFor(right_facts.items, fact.key) != fact.count) return false;
    }
    return true;
}
