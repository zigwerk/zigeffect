const std = @import("std");
const causal = @import("causal.zig");
const agent_intervention = @import("agent_intervention.zig");
const counterfactual = @import("counterfactual.zig");
const causal_diff = @import("causal_diff.zig");
const causal_invariant = @import("causal_invariant.zig");

pub const AgentEvalOptions = struct {
    name: []const u8,
    baseline: []const causal.CausalEvent,
    policy: agent_intervention.AgentInterventionPolicy,
    request: agent_intervention.AgentInterventionRequest,
    invariants: causal_invariant.CausalInvariantBuilder = .{},
    expect_improvement: bool = true,
};

pub const AgentEvalResult = struct {
    passed: bool,
    counterfactual: counterfactual.CounterfactualResult,
    diff_summary: causal_diff.CausalGraphDiffSummary,
    invariant_violations: usize,
};

fn replayEvents(store: *causal.CausalStore, events: []const causal.CausalEvent) std.mem.Allocator.Error!void {
    for (events) |event| {
        _ = try store.record(event);
    }
}

pub fn runAgentEval(allocator: std.mem.Allocator, options: AgentEvalOptions) std.mem.Allocator.Error!AgentEvalResult {
    _ = options.name;
    const cf = try counterfactual.runCounterfactual(allocator, options.baseline, options.policy, options.request);

    var after = causal.CausalStore.init(allocator);
    defer after.deinit();
    try replayEvents(&after, options.baseline);
    _ = try agent_intervention.applyAgentIntervention(&after, options.policy, options.request);

    var after_snapshot = try after.snapshot(allocator);
    defer after_snapshot.deinit();
    var invariant_check = try options.invariants.check(allocator, after_snapshot.events);
    defer invariant_check.deinit();

    const improvement_ok = if (options.expect_improvement) cf.improved else cf.finding_delta <= 0;
    return .{
        .passed = cf.intervention.applied and improvement_ok and invariant_check.violations.len == 0,
        .counterfactual = cf,
        .diff_summary = cf.diff_summary,
        .invariant_violations = invariant_check.violations.len,
    };
}
