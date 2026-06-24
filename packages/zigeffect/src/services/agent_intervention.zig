const std = @import("std");
const causal = @import("causal.zig");

pub const CausalStore = causal.CausalStore;

pub const AgentInterventionKind = enum {
    interrupt_fiber,
    fire_timer,
    pause_runner,
    replace_provider,
    replay_scenario,
    inject_failure,
};

pub const AgentInterventionKindPolicy = enum {
    needs_human_review,
    auto_approve,
    always_reject,
};

pub const AgentInterventionDecisionKind = enum {
    approve,
    reject,
    needs_human_review,
};

pub const AgentInterventionRequest = struct {
    kind: AgentInterventionKind,
    run_id: ?u64 = null,
    scope_id: ?u64 = null,
    fiber_id: ?u64 = null,
    schedule_id: ?u64 = null,
    resource_id: ?u64 = null,
    reason: []const u8 = "",
    redacted_detail: []const u8 = "",
};

pub const AgentInterventionDecision = struct {
    decision: AgentInterventionDecisionKind,
    reason: []const u8,
};

pub const AgentInterventionResult = struct {
    decision: AgentInterventionDecisionKind,
    applied: bool,
    requested_event_id: ?u64 = null,
    decided_event_id: ?u64 = null,
    applied_event_id: ?u64 = null,
    effect_event_id: ?u64 = null,
};

pub const AgentInterventionPolicy = struct {
    apply_enabled: bool = false,
    interrupt_fiber_policy: AgentInterventionKindPolicy = .needs_human_review,
    fire_timer_policy: AgentInterventionKindPolicy = .needs_human_review,
    pause_runner_policy: AgentInterventionKindPolicy = .needs_human_review,
    replace_provider_policy: AgentInterventionKindPolicy = .needs_human_review,
    replay_scenario_policy: AgentInterventionKindPolicy = .needs_human_review,
    inject_failure_policy: AgentInterventionKindPolicy = .needs_human_review,

    pub fn withApplyEnabled(self: AgentInterventionPolicy, enabled: bool) AgentInterventionPolicy {
        var next = self;
        next.apply_enabled = enabled;
        return next;
    }

    pub fn withKindPolicy(
        self: AgentInterventionPolicy,
        kind: AgentInterventionKind,
        policy: AgentInterventionKindPolicy,
    ) AgentInterventionPolicy {
        var next = self;
        switch (kind) {
            .interrupt_fiber => next.interrupt_fiber_policy = policy,
            .fire_timer => next.fire_timer_policy = policy,
            .pause_runner => next.pause_runner_policy = policy,
            .replace_provider => next.replace_provider_policy = policy,
            .replay_scenario => next.replay_scenario_policy = policy,
            .inject_failure => next.inject_failure_policy = policy,
        }
        return next;
    }

    fn policyFor(self: AgentInterventionPolicy, kind: AgentInterventionKind) AgentInterventionKindPolicy {
        return switch (kind) {
            .interrupt_fiber => self.interrupt_fiber_policy,
            .fire_timer => self.fire_timer_policy,
            .pause_runner => self.pause_runner_policy,
            .replace_provider => self.replace_provider_policy,
            .replay_scenario => self.replay_scenario_policy,
            .inject_failure => self.inject_failure_policy,
        };
    }

    pub fn decide(self: AgentInterventionPolicy, request: AgentInterventionRequest) AgentInterventionDecision {
        const kind_policy = self.policyFor(request.kind);
        if (kind_policy == .always_reject) {
            return .{ .decision = .reject, .reason = "intervention kind explicitly rejected by policy" };
        }
        if (!self.apply_enabled) {
            return .{ .decision = .needs_human_review, .reason = "agent intervention apply boundary disabled" };
        }
        return switch (kind_policy) {
            .auto_approve => .{ .decision = .approve, .reason = "intervention kind auto-approved by policy" },
            .needs_human_review => .{ .decision = .needs_human_review, .reason = "intervention kind requires human review" },
            .always_reject => unreachable,
        };
    }
};

fn effectKindForIntervention(kind: AgentInterventionKind) causal.CausalEventKind {
    return switch (kind) {
        .interrupt_fiber => .fiber_interrupted,
        .fire_timer => .timer_fired,
        .pause_runner => .cluster_runner_heartbeat,
        .replace_provider => .service_replaced,
        .replay_scenario => .workflow_event_recorded,
        .inject_failure => .assertion_recorded,
    };
}

fn effectStatusForIntervention(kind: AgentInterventionKind) []const u8 {
    return switch (kind) {
        .interrupt_fiber => "interrupted",
        .fire_timer => "fired",
        .pause_runner => "paused",
        .replace_provider => "replaced",
        .replay_scenario => "replayed",
        .inject_failure => "failure",
    };
}

pub fn applyAgentIntervention(
    store: *CausalStore,
    policy: AgentInterventionPolicy,
    request: AgentInterventionRequest,
) std.mem.Allocator.Error!AgentInterventionResult {
    const requested = try store.record(.{
        .kind = .remediation_requested,
        .run_id = request.run_id,
        .scope_id = request.scope_id,
        .fiber_id = request.fiber_id,
        .schedule_id = request.schedule_id,
        .resource_id = request.resource_id,
        .status = "proposed",
        .label = request.reason,
        .type_name = @tagName(request.kind),
        .redacted_detail = request.redacted_detail,
    });

    const decision = policy.decide(request);
    const decided = try store.record(.{
        .kind = .remediation_decided,
        .run_id = request.run_id,
        .scope_id = request.scope_id,
        .fiber_id = request.fiber_id,
        .schedule_id = request.schedule_id,
        .resource_id = request.resource_id,
        .parent_id = requested,
        .cause_event_id = requested,
        .status = @tagName(decision.decision),
        .label = decision.reason,
        .type_name = @tagName(request.kind),
    });

    if (decision.decision != .approve) {
        return .{
            .decision = decision.decision,
            .applied = false,
            .requested_event_id = requested,
            .decided_event_id = decided,
        };
    }

    const applied = try store.record(.{
        .kind = .remediation_applied,
        .run_id = request.run_id,
        .scope_id = request.scope_id,
        .fiber_id = request.fiber_id,
        .schedule_id = request.schedule_id,
        .resource_id = request.resource_id,
        .parent_id = decided,
        .cause_event_id = decided,
        .status = "applied",
        .label = request.reason,
        .type_name = @tagName(request.kind),
    });

    const effect = try store.record(.{
        .kind = effectKindForIntervention(request.kind),
        .run_id = request.run_id,
        .scope_id = request.scope_id,
        .fiber_id = request.fiber_id,
        .schedule_id = request.schedule_id,
        .resource_id = request.resource_id,
        .parent_id = applied,
        .cause_event_id = applied,
        .status = effectStatusForIntervention(request.kind),
        .label = request.reason,
        .type_name = @tagName(request.kind),
        .redacted_detail = request.redacted_detail,
    });

    return .{
        .decision = decision.decision,
        .applied = true,
        .requested_event_id = requested,
        .decided_event_id = decided,
        .applied_event_id = applied,
        .effect_event_id = effect,
    };
}
