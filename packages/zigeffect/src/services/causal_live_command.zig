const std = @import("std");
const causal = @import("causal.zig");
const agent_intervention = @import("agent_intervention.zig");

pub const CausalStore = causal.CausalStore;
pub const AgentInterventionPolicy = agent_intervention.AgentInterventionPolicy;
pub const AgentInterventionRequest = agent_intervention.AgentInterventionRequest;
pub const AgentInterventionResult = agent_intervention.AgentInterventionResult;
pub const AgentInterventionKind = agent_intervention.AgentInterventionKind;
pub const AgentInterventionDecisionKind = agent_intervention.AgentInterventionDecisionKind;

pub const CausalLiveCommandRequest = struct {
    command_id: []const u8,
    command_kind: []const u8,
    actor: []const u8 = "",
    run_id: ?u64 = null,
    scope_id: ?u64 = null,
    fiber_id: ?u64 = null,
    schedule_id: ?u64 = null,
    resource_id: ?u64 = null,
    reason: []const u8 = "",
    redacted_detail: []const u8 = "",
};

pub const CausalLiveCommandResult = struct {
    command_id: []const u8,
    command_kind: []const u8,
    actor: []const u8 = "",
    known_kind: bool,
    decision: AgentInterventionDecisionKind,
    applied: bool,
    intervention: ?AgentInterventionResult = null,
    alert_event_id: ?u64 = null,
};

pub const CausalLiveCommandEnvelope = struct {
    sequence: u64,
    request: CausalLiveCommandRequest,
};

pub const CausalLiveCommandTapResult = struct {
    processed: usize = 0,
    applied: usize = 0,
    rejected: usize = 0,
    needs_human_review: usize = 0,
    last_sequence: ?u64 = null,
};

pub fn applyCausalLiveCommand(
    store: *CausalStore,
    policy: AgentInterventionPolicy,
    request: CausalLiveCommandRequest,
) std.mem.Allocator.Error!CausalLiveCommandResult {
    const kind = liveCommandKind(request.command_kind) orelse {
        const alert = try store.record(.{
            .kind = .alert_emitted,
            .run_id = request.run_id,
            .scope_id = request.scope_id,
            .fiber_id = request.fiber_id,
            .schedule_id = request.schedule_id,
            .resource_id = request.resource_id,
            .status = "rejected",
            .label = request.reason,
            .type_name = "unknown-live-command",
            .redacted_detail = request.redacted_detail,
        });
        return .{
            .command_id = request.command_id,
            .command_kind = request.command_kind,
            .actor = request.actor,
            .known_kind = false,
            .decision = .reject,
            .applied = false,
            .alert_event_id = alert,
        };
    };

    const intervention = try agent_intervention.applyAgentIntervention(store, policy, .{
        .kind = kind,
        .run_id = request.run_id,
        .scope_id = request.scope_id,
        .fiber_id = request.fiber_id,
        .schedule_id = request.schedule_id,
        .resource_id = request.resource_id,
        .reason = request.reason,
        .redacted_detail = request.redacted_detail,
    });

    return .{
        .command_id = request.command_id,
        .command_kind = request.command_kind,
        .actor = request.actor,
        .known_kind = true,
        .decision = intervention.decision,
        .applied = intervention.applied,
        .intervention = intervention,
    };
}

pub fn runCausalLiveCommandTapBatch(
    store: *CausalStore,
    policy: AgentInterventionPolicy,
    envelopes: []const CausalLiveCommandEnvelope,
) std.mem.Allocator.Error!CausalLiveCommandTapResult {
    var output = CausalLiveCommandTapResult{};
    for (envelopes) |envelope| {
        const result = try applyCausalLiveCommand(store, policy, envelope.request);
        output.processed += 1;
        output.last_sequence = envelope.sequence;
        if (result.applied) {
            output.applied += 1;
        }
        switch (result.decision) {
            .approve => {},
            .reject => output.rejected += 1,
            .needs_human_review => output.needs_human_review += 1,
        }
    }
    return output;
}

fn liveCommandKind(command_kind: []const u8) ?AgentInterventionKind {
    inline for (std.meta.fields(AgentInterventionKind)) |field| {
        if (std.mem.eql(u8, command_kind, field.name)) {
            return @field(AgentInterventionKind, field.name);
        }
    }
    return null;
}
