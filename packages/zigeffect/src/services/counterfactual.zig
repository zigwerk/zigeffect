const std = @import("std");
const causal = @import("causal.zig");
const causal_structural = @import("causal_structural.zig");
const agent_intervention = @import("agent_intervention.zig");

pub const CounterfactualResult = struct {
    before_findings: usize,
    after_findings: usize,
    finding_delta: isize,
    structurally_equivalent: bool,
    improved: bool,
    intervention: agent_intervention.AgentInterventionResult,
};

fn replayEvents(store: *causal.CausalStore, events: []const causal.CausalEvent) std.mem.Allocator.Error!void {
    for (events) |event| {
        _ = try store.record(event);
    }
}

fn findingCount(store: *const causal.CausalStore, allocator: std.mem.Allocator) std.mem.Allocator.Error!usize {
    var findings = try store.findings(allocator);
    defer findings.deinit();
    return findings.items.len;
}

pub fn runCounterfactual(
    allocator: std.mem.Allocator,
    baseline: []const causal.CausalEvent,
    policy: agent_intervention.AgentInterventionPolicy,
    request: agent_intervention.AgentInterventionRequest,
) std.mem.Allocator.Error!CounterfactualResult {
    var before = causal.CausalStore.init(allocator);
    defer before.deinit();
    try replayEvents(&before, baseline);

    var after = causal.CausalStore.init(allocator);
    defer after.deinit();
    try replayEvents(&after, baseline);
    const intervention = try agent_intervention.applyAgentIntervention(&after, policy, request);

    const before_findings = try findingCount(&before, allocator);
    const after_findings = try findingCount(&after, allocator);
    var before_snapshot = try before.snapshot(allocator);
    defer before_snapshot.deinit();
    var after_snapshot = try after.snapshot(allocator);
    defer after_snapshot.deinit();

    const delta: isize = @as(isize, @intCast(after_findings)) - @as(isize, @intCast(before_findings));
    return .{
        .before_findings = before_findings,
        .after_findings = after_findings,
        .finding_delta = delta,
        .structurally_equivalent = try causal_structural.structurallyEquivalent(allocator, before_snapshot.events, after_snapshot.events),
        .improved = intervention.applied and delta < 0,
        .intervention = intervention,
    };
}
