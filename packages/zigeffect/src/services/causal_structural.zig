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

/// Build the structural facts of a causal trace, ignoring event ids and ordering:
///   - the multiset of event kinds
///   - the multiset of cause-edge kind pairs (cause.kind -> effect.kind)
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
        const key = try std.fmt.allocPrint(allocator, "cause:{s}->{s}", .{ @tagName(cause_kind), @tagName(event.kind) });
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
