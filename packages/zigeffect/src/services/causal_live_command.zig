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

pub const CausalLiveCommandPollBatch = struct {
    next_after: u64,
    envelopes: []const CausalLiveCommandEnvelope,
};

pub const CausalLiveCommandPollResult = struct {
    next_after: u64,
    tap: CausalLiveCommandTapResult,
};

pub const CausalLiveCommandPoller = struct {
    state: ?*anyopaque = null,
    poll: *const fn (?*anyopaque, after: u64) anyerror!CausalLiveCommandPollBatch,
};

pub const CausalLiveCommandPollLoopOptions = struct {
    start_after: u64 = 0,
    max_polls: usize = 1,
};

pub const CausalLiveCommandPollLoopResult = struct {
    polls: usize = 0,
    next_after: u64 = 0,
    tap: CausalLiveCommandTapResult = .{},
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

pub fn runCausalLiveCommandPolledBatch(
    store: *CausalStore,
    policy: AgentInterventionPolicy,
    batch: CausalLiveCommandPollBatch,
) std.mem.Allocator.Error!CausalLiveCommandPollResult {
    const tap = try runCausalLiveCommandTapBatch(store, policy, batch.envelopes);
    const cursor = if (tap.last_sequence) |last| @max(batch.next_after, last) else batch.next_after;
    return .{
        .next_after = cursor,
        .tap = tap,
    };
}

pub fn runCausalLiveCommandPollLoop(
    store: *CausalStore,
    policy: AgentInterventionPolicy,
    poller: CausalLiveCommandPoller,
    options: CausalLiveCommandPollLoopOptions,
) anyerror!CausalLiveCommandPollLoopResult {
    var output = CausalLiveCommandPollLoopResult{
        .next_after = options.start_after,
    };

    var cursor = options.start_after;
    var polls: usize = 0;
    while (polls < options.max_polls) : (polls += 1) {
        const batch = try poller.poll(poller.state, cursor);
        output.polls += 1;

        const result = try runCausalLiveCommandPolledBatch(store, policy, batch);
        cursor = result.next_after;
        output.next_after = cursor;
        addTapResult(&output.tap, result.tap);

        if (batch.envelopes.len == 0) break;
    }

    return output;
}

fn addTapResult(output: *CausalLiveCommandTapResult, next: CausalLiveCommandTapResult) void {
    output.processed += next.processed;
    output.applied += next.applied;
    output.rejected += next.rejected;
    output.needs_human_review += next.needs_human_review;
    if (next.last_sequence) |sequence| output.last_sequence = sequence;
}

fn liveCommandKind(command_kind: []const u8) ?AgentInterventionKind {
    inline for (std.meta.fields(AgentInterventionKind)) |field| {
        if (std.mem.eql(u8, command_kind, field.name)) {
            return @field(AgentInterventionKind, field.name);
        }
    }
    return null;
}
