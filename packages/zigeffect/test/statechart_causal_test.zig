const std = @import("std");
const fx = @import("zigeffect");

const State = enum { idle, done };
const Event = union(enum) { finish: struct { secret: []const u8 }, ignore };
const Context = struct { secret: [13]u8 };
const Command = enum { none };
const Def = fx.statechart.Definition(State, Event, Context, Command);
const Runtime = fx.statechart.Machine(Def);

const definition = Def.init(.{
    .id = "agent.causal",
    .version = 1,
    .initial = .idle,
    .states = &.{
        .{ .id = .idle },
        .{ .id = .done, .kind = .final },
    },
    .transitions = &.{
        .{ .id = "finish", .source = .idle, .event = .finish, .target = .done },
    },
});

test "statechart decisions map to correlated redacted causal events" {
    const allocator = std.testing.allocator;
    const secret = "must-not-leak";
    const snapshot = Runtime.initial(&definition, .{ .secret = secret.* }, 91);
    const decision = try Runtime.step(&definition, snapshot, .{ .finish = .{ .secret = secret } });

    var mapped = try fx.statechart.mapDecisionToCausal(Def, allocator, &definition, &decision, 7);
    defer fx.statechart.deinitMappedCausalEvent(allocator, &mapped);

    try std.testing.expectEqual(fx.CausalEventKind.statechart_event_recorded, mapped.kind);
    try std.testing.expectEqual(@as(?u64, 7), mapped.parent_id);
    try std.testing.expectEqual(@as(?u64, 91), mapped.scope_id);
    try std.testing.expectEqual(@as(?u64, 1), mapped.span_id);
    try std.testing.expectEqualStrings("finish", mapped.label);
    try std.testing.expectEqualStrings("statechart.transition_committed", mapped.type_name);
    try std.testing.expectEqualStrings("committed", mapped.status);
    try std.testing.expectEqualStrings("zigeffect.statechart.execution.v2", mapped.schema_ref);
    try std.testing.expect(mapped.artifact_id.len != 0);
    try std.testing.expect(mapped.domain_entity_ref.len != 0);
    try std.testing.expect(std.mem.indexOf(u8, mapped.redacted_detail, secret) == null);
}

test "statechart causal events are structural finding evidence and non-sampleable" {
    const taxonomy = fx.causalEventTaxonomy(.statechart_event_recorded);
    try std.testing.expect(taxonomy.structural);
    try std.testing.expect(taxonomy.finding_evidence);
    try std.testing.expect(!taxonomy.sampleable);
    try std.testing.expectEqualStrings("statechart", fx.causalExtensionDomainName(.statechart));
}

test "statechart decisions record through existing causal stores and renderers" {
    const allocator = std.testing.allocator;
    const snapshot = Runtime.initial(&definition, .{ .secret = "must-not-leak".* }, 12);
    const decision = try Runtime.step(&definition, snapshot, .{ .finish = .{ .secret = "redacted" } });

    var store = fx.CausalStore.init(allocator);
    defer store.deinit();
    const event_id = try fx.statechart.recordDecisionCausal(Def, &store, allocator, &definition, &decision, null);
    try std.testing.expect(event_id != 0);

    const json = try fx.formatCausalJson(allocator, &store);
    defer allocator.free(json);
    const dot = try fx.formatCausalDot(allocator, &store);
    defer allocator.free(dot);
    try std.testing.expect(std.mem.indexOf(u8, json, "statechart_event_recorded") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "finish") != null);
}
