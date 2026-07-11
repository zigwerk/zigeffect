const std = @import("std");
const artifact_mod = @import("artifact.zig");
const machine_mod = @import("machine.zig");
const causal_mod = @import("../services/causal.zig");

pub const Allocator = std.mem.Allocator;
pub const CausalEvent = causal_mod.CausalEvent;
pub const CausalStore = causal_mod.CausalStore;

pub fn mapDecisionToCausal(
    comptime DefinitionType: type,
    allocator: Allocator,
    definition: *const DefinitionType,
    decision: *const machine_mod.Machine(DefinitionType).Decision,
    parent_id: ?u64,
) Allocator.Error!CausalEvent {
    const transitioned = decision.outcome == .transitioned;
    const label_source = if (transitioned) decision.selected_transition_id else "ignored-event";
    const type_source = if (transitioned) "statechart.transition_committed" else "statechart.event_ignored";
    const status_source = if (transitioned) "committed" else "ignored";

    var event = CausalEvent{
        .kind = .statechart_event_recorded,
        .run_id = definition.fingerprint(),
        .parent_id = parent_id,
        .scope_id = decision.previous.instance_id,
        .trace_id = definition.fingerprint(),
        .span_id = decision.next.revision,
    };
    errdefer deinitMappedCausalEvent(allocator, &event);

    event.artifact_id = try std.fmt.allocPrint(allocator, "statechart:{x}", .{definition.fingerprint()});
    event.domain_entity_ref = try std.fmt.allocPrint(allocator, "statechart-instance:{d}", .{decision.previous.instance_id});
    event.schema_ref = try allocator.dupe(u8, artifact_mod.statechart_execution_schema);
    event.label = try allocator.dupe(u8, label_source);
    event.type_name = try allocator.dupe(u8, type_source);
    event.status = try allocator.dupe(u8, status_source);
    event.redacted_detail = try std.fmt.allocPrint(
        allocator,
        "from={s} to={s} revision={d} actions={d} commands={d} internal_events={d}",
        .{
            @tagName(decision.previous.state),
            @tagName(decision.next.state),
            decision.next.revision,
            decision.actions().len,
            decision.commands().len,
            decision.internalEvents().len,
        },
    );
    return event;
}

pub fn recordDecisionCausal(
    comptime DefinitionType: type,
    store: *CausalStore,
    allocator: Allocator,
    definition: *const DefinitionType,
    decision: *const machine_mod.Machine(DefinitionType).Decision,
    parent_id: ?u64,
) Allocator.Error!u64 {
    var event = try mapDecisionToCausal(DefinitionType, allocator, definition, decision, parent_id);
    defer deinitMappedCausalEvent(allocator, &event);
    return store.record(event);
}

pub fn deinitMappedCausalEvent(allocator: Allocator, event: *CausalEvent) void {
    freeText(allocator, event.artifact_id);
    freeText(allocator, event.domain_entity_ref);
    freeText(allocator, event.schema_ref);
    freeText(allocator, event.label);
    freeText(allocator, event.type_name);
    freeText(allocator, event.status);
    freeText(allocator, event.redacted_detail);
    event.artifact_id = "";
    event.domain_entity_ref = "";
    event.schema_ref = "";
    event.label = "";
    event.type_name = "";
    event.status = "";
    event.redacted_detail = "";
}

fn freeText(allocator: Allocator, text: []const u8) void {
    if (text.len != 0) allocator.free(text);
}
