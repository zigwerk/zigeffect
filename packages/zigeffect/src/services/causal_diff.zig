const std = @import("std");
const causal = @import("causal.zig");

pub const CausalFindingDelta = struct {
    kind: causal.CausalFindingKind,
    run_id: ?u64 = null,
    scope_id: ?u64 = null,
    fiber_id: ?u64 = null,
};

pub const CausalFiberTerminalFact = struct {
    kind: causal.CausalEventKind,
    run_id: ?u64 = null,
    scope_id: ?u64 = null,
    fiber_id: ?u64 = null,
    status: []const u8 = "",
};

pub const CausalResourceFinalizationFact = struct {
    run_id: ?u64 = null,
    scope_id: ?u64 = null,
    resource_id: ?u64 = null,
    type_name: []const u8 = "",
    status: []const u8 = "",
};

pub const CausalLineageEdgeFact = struct {
    kind: causal.CausalEventKind,
    run_id: ?u64 = null,
    parent_kind: ?causal.CausalEventKind = null,
    cause_kind: ?causal.CausalEventKind = null,
};

pub const CausalGraphDiffSummary = struct {
    resolved_findings: usize = 0,
    introduced_findings: usize = 0,
    added_fiber_terminals: usize = 0,
    removed_fiber_terminals: usize = 0,
    added_resource_finalizations: usize = 0,
    removed_resource_finalizations: usize = 0,
    added_lineage_edges: usize = 0,
    removed_lineage_edges: usize = 0,

    pub fn improved(self: CausalGraphDiffSummary) bool {
        return self.resolved_findings > self.introduced_findings;
    }
};

pub const CausalGraphDiff = struct {
    allocator: std.mem.Allocator,
    resolved_findings: []CausalFindingDelta,
    introduced_findings: []CausalFindingDelta,
    added_fiber_terminals: []CausalFiberTerminalFact,
    removed_fiber_terminals: []CausalFiberTerminalFact,
    added_resource_finalizations: []CausalResourceFinalizationFact,
    removed_resource_finalizations: []CausalResourceFinalizationFact,
    added_lineage_edges: []CausalLineageEdgeFact,
    removed_lineage_edges: []CausalLineageEdgeFact,

    pub fn deinit(self: *CausalGraphDiff) void {
        self.allocator.free(self.resolved_findings);
        self.allocator.free(self.introduced_findings);
        self.allocator.free(self.added_fiber_terminals);
        self.allocator.free(self.removed_fiber_terminals);
        self.allocator.free(self.added_resource_finalizations);
        self.allocator.free(self.removed_resource_finalizations);
        self.allocator.free(self.added_lineage_edges);
        self.allocator.free(self.removed_lineage_edges);
    }

    pub fn summary(self: *const CausalGraphDiff) CausalGraphDiffSummary {
        return .{
            .resolved_findings = self.resolved_findings.len,
            .introduced_findings = self.introduced_findings.len,
            .added_fiber_terminals = self.added_fiber_terminals.len,
            .removed_fiber_terminals = self.removed_fiber_terminals.len,
            .added_resource_finalizations = self.added_resource_finalizations.len,
            .removed_resource_finalizations = self.removed_resource_finalizations.len,
            .added_lineage_edges = self.added_lineage_edges.len,
            .removed_lineage_edges = self.removed_lineage_edges.len,
        };
    }
};

fn replayEvents(store: *causal.CausalStore, events: []const causal.CausalEvent) std.mem.Allocator.Error!void {
    for (events) |event| {
        _ = try store.record(event);
    }
}

fn findingDelta(finding: causal.CausalFinding) CausalFindingDelta {
    return .{
        .kind = finding.kind,
        .run_id = finding.run_id,
        .scope_id = finding.scope_id,
        .fiber_id = finding.fiber_id,
    };
}

fn sameFinding(left: CausalFindingDelta, right: CausalFindingDelta) bool {
    return left.kind == right.kind and
        left.run_id == right.run_id and
        left.scope_id == right.scope_id and
        left.fiber_id == right.fiber_id;
}

fn containsFinding(items: []const CausalFindingDelta, needle: CausalFindingDelta) bool {
    for (items) |item| {
        if (sameFinding(item, needle)) return true;
    }
    return false;
}

fn fiberFact(event: causal.CausalEvent) CausalFiberTerminalFact {
    return .{
        .kind = event.kind,
        .run_id = event.run_id,
        .scope_id = event.scope_id,
        .fiber_id = event.fiber_id,
        .status = event.status,
    };
}

fn sameFiberFact(left: CausalFiberTerminalFact, right: CausalFiberTerminalFact) bool {
    return left.kind == right.kind and
        left.run_id == right.run_id and
        left.scope_id == right.scope_id and
        left.fiber_id == right.fiber_id and
        std.mem.eql(u8, left.status, right.status);
}

fn containsFiberFact(items: []const CausalFiberTerminalFact, needle: CausalFiberTerminalFact) bool {
    for (items) |item| {
        if (sameFiberFact(item, needle)) return true;
    }
    return false;
}

fn resourceFact(event: causal.CausalEvent) CausalResourceFinalizationFact {
    return .{
        .run_id = event.run_id,
        .scope_id = event.scope_id,
        .resource_id = event.resource_id,
        .type_name = event.type_name,
        .status = event.status,
    };
}

fn sameResourceFact(left: CausalResourceFinalizationFact, right: CausalResourceFinalizationFact) bool {
    return left.run_id == right.run_id and
        left.scope_id == right.scope_id and
        left.resource_id == right.resource_id and
        std.mem.eql(u8, left.type_name, right.type_name) and
        std.mem.eql(u8, left.status, right.status);
}

fn containsResourceFact(items: []const CausalResourceFinalizationFact, needle: CausalResourceFinalizationFact) bool {
    for (items) |item| {
        if (sameResourceFact(item, needle)) return true;
    }
    return false;
}

fn kindForId(events: []const causal.CausalEvent, id: ?u64) ?causal.CausalEventKind {
    const wanted = id orelse return null;
    for (events) |event| {
        if (event.id == wanted) return event.kind;
    }
    return null;
}

fn lineageFact(events: []const causal.CausalEvent, event: causal.CausalEvent) ?CausalLineageEdgeFact {
    if (event.parent_id == null and event.cause_event_id == null) return null;
    return .{
        .kind = event.kind,
        .run_id = event.run_id,
        .parent_kind = kindForId(events, event.parent_id),
        .cause_kind = kindForId(events, event.cause_event_id),
    };
}

fn sameLineageFact(left: CausalLineageEdgeFact, right: CausalLineageEdgeFact) bool {
    return left.kind == right.kind and
        left.run_id == right.run_id and
        left.parent_kind == right.parent_kind and
        left.cause_kind == right.cause_kind;
}

fn containsLineageFact(items: []const CausalLineageEdgeFact, needle: CausalLineageEdgeFact) bool {
    for (items) |item| {
        if (sameLineageFact(item, needle)) return true;
    }
    return false;
}

fn collectFindings(
    allocator: std.mem.Allocator,
    events: []const causal.CausalEvent,
) std.mem.Allocator.Error![]CausalFindingDelta {
    var store = causal.CausalStore.init(allocator);
    defer store.deinit();
    try replayEvents(&store, events);
    var findings = try store.findings(allocator);
    defer findings.deinit();

    var output = std.ArrayList(CausalFindingDelta).empty;
    errdefer output.deinit(allocator);
    for (findings.items) |finding| {
        try output.append(allocator, findingDelta(finding));
    }
    return output.toOwnedSlice(allocator);
}

fn collectFiberTerminals(
    allocator: std.mem.Allocator,
    events: []const causal.CausalEvent,
) std.mem.Allocator.Error![]CausalFiberTerminalFact {
    var output = std.ArrayList(CausalFiberTerminalFact).empty;
    errdefer output.deinit(allocator);
    for (events) |event| {
        if (event.kind != .fiber_joined and event.kind != .fiber_interrupted) continue;
        try output.append(allocator, fiberFact(event));
    }
    return output.toOwnedSlice(allocator);
}

fn collectResourceFinalizations(
    allocator: std.mem.Allocator,
    events: []const causal.CausalEvent,
) std.mem.Allocator.Error![]CausalResourceFinalizationFact {
    var output = std.ArrayList(CausalResourceFinalizationFact).empty;
    errdefer output.deinit(allocator);
    for (events) |event| {
        if (event.kind != .resource_finalized) continue;
        try output.append(allocator, resourceFact(event));
    }
    return output.toOwnedSlice(allocator);
}

fn collectLineageEdges(
    allocator: std.mem.Allocator,
    events: []const causal.CausalEvent,
) std.mem.Allocator.Error![]CausalLineageEdgeFact {
    var output = std.ArrayList(CausalLineageEdgeFact).empty;
    errdefer output.deinit(allocator);
    for (events) |event| {
        if (lineageFact(events, event)) |fact| {
            try output.append(allocator, fact);
        }
    }
    return output.toOwnedSlice(allocator);
}

fn appendMissing(comptime T: type, allocator: std.mem.Allocator, output: *std.ArrayList(T), left: []const T, right: []const T, contains: fn ([]const T, T) bool) std.mem.Allocator.Error!void {
    for (left) |item| {
        if (!contains(right, item)) try output.append(allocator, item);
    }
}

pub fn diffCausalGraphs(
    allocator: std.mem.Allocator,
    before: []const causal.CausalEvent,
    after: []const causal.CausalEvent,
) std.mem.Allocator.Error!CausalGraphDiff {
    const before_findings = try collectFindings(allocator, before);
    defer allocator.free(before_findings);
    const after_findings = try collectFindings(allocator, after);
    defer allocator.free(after_findings);
    const before_fibers = try collectFiberTerminals(allocator, before);
    defer allocator.free(before_fibers);
    const after_fibers = try collectFiberTerminals(allocator, after);
    defer allocator.free(after_fibers);
    const before_resources = try collectResourceFinalizations(allocator, before);
    defer allocator.free(before_resources);
    const after_resources = try collectResourceFinalizations(allocator, after);
    defer allocator.free(after_resources);
    const before_lineage = try collectLineageEdges(allocator, before);
    defer allocator.free(before_lineage);
    const after_lineage = try collectLineageEdges(allocator, after);
    defer allocator.free(after_lineage);

    var resolved_findings = std.ArrayList(CausalFindingDelta).empty;
    errdefer resolved_findings.deinit(allocator);
    var introduced_findings = std.ArrayList(CausalFindingDelta).empty;
    errdefer introduced_findings.deinit(allocator);
    var added_fibers = std.ArrayList(CausalFiberTerminalFact).empty;
    errdefer added_fibers.deinit(allocator);
    var removed_fibers = std.ArrayList(CausalFiberTerminalFact).empty;
    errdefer removed_fibers.deinit(allocator);
    var added_resources = std.ArrayList(CausalResourceFinalizationFact).empty;
    errdefer added_resources.deinit(allocator);
    var removed_resources = std.ArrayList(CausalResourceFinalizationFact).empty;
    errdefer removed_resources.deinit(allocator);
    var added_lineage = std.ArrayList(CausalLineageEdgeFact).empty;
    errdefer added_lineage.deinit(allocator);
    var removed_lineage = std.ArrayList(CausalLineageEdgeFact).empty;
    errdefer removed_lineage.deinit(allocator);

    try appendMissing(CausalFindingDelta, allocator, &resolved_findings, before_findings, after_findings, containsFinding);
    try appendMissing(CausalFindingDelta, allocator, &introduced_findings, after_findings, before_findings, containsFinding);
    try appendMissing(CausalFiberTerminalFact, allocator, &added_fibers, after_fibers, before_fibers, containsFiberFact);
    try appendMissing(CausalFiberTerminalFact, allocator, &removed_fibers, before_fibers, after_fibers, containsFiberFact);
    try appendMissing(CausalResourceFinalizationFact, allocator, &added_resources, after_resources, before_resources, containsResourceFact);
    try appendMissing(CausalResourceFinalizationFact, allocator, &removed_resources, before_resources, after_resources, containsResourceFact);
    try appendMissing(CausalLineageEdgeFact, allocator, &added_lineage, after_lineage, before_lineage, containsLineageFact);
    try appendMissing(CausalLineageEdgeFact, allocator, &removed_lineage, before_lineage, after_lineage, containsLineageFact);

    return .{
        .allocator = allocator,
        .resolved_findings = try resolved_findings.toOwnedSlice(allocator),
        .introduced_findings = try introduced_findings.toOwnedSlice(allocator),
        .added_fiber_terminals = try added_fibers.toOwnedSlice(allocator),
        .removed_fiber_terminals = try removed_fibers.toOwnedSlice(allocator),
        .added_resource_finalizations = try added_resources.toOwnedSlice(allocator),
        .removed_resource_finalizations = try removed_resources.toOwnedSlice(allocator),
        .added_lineage_edges = try added_lineage.toOwnedSlice(allocator),
        .removed_lineage_edges = try removed_lineage.toOwnedSlice(allocator),
    };
}
