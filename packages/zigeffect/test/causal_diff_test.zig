const std = @import("std");
const fx = @import("zigeffect");

test "semantic causal graph diff reports resolved findings and added lifecycle facts" {
    const before = [_]fx.CausalEvent{
        .{ .kind = .run_started, .run_id = 1, .status = "started" },
        .{ .kind = .scope_opened, .run_id = 1, .scope_id = 2, .parent_id = 1, .status = "opened" },
        .{ .kind = .resource_acquired, .run_id = 1, .scope_id = 2, .resource_id = 3, .status = "acquired", .type_name = "db" },
        .{ .kind = .fiber_suspended, .run_id = 1, .scope_id = 2, .fiber_id = 4, .status = "suspended" },
        .{ .kind = .scope_closed, .run_id = 1, .scope_id = 2, .status = "closed" },
    };
    const after = [_]fx.CausalEvent{
        .{ .kind = .run_started, .run_id = 1, .status = "started" },
        .{ .kind = .scope_opened, .run_id = 1, .scope_id = 2, .parent_id = 1, .status = "opened" },
        .{ .kind = .resource_acquired, .run_id = 1, .scope_id = 2, .resource_id = 3, .status = "acquired", .type_name = "db" },
        .{ .kind = .fiber_suspended, .run_id = 1, .scope_id = 2, .fiber_id = 4, .status = "suspended" },
        .{ .kind = .fiber_interrupted, .run_id = 1, .scope_id = 2, .fiber_id = 4, .parent_id = 4, .cause_event_id = 4, .status = "interrupted" },
        .{ .kind = .resource_finalized, .run_id = 1, .scope_id = 2, .resource_id = 3, .parent_id = 3, .cause_event_id = 3, .status = "success", .type_name = "db" },
        .{ .kind = .scope_closed, .run_id = 1, .scope_id = 2, .status = "closed" },
    };

    var diff = try fx.diffCausalGraphs(std.testing.allocator, &before, &after);
    defer diff.deinit();

    try std.testing.expectEqual(@as(usize, 2), diff.resolved_findings.len);
    try std.testing.expectEqual(fx.CausalFindingKind.resource_acquired_without_finalization, diff.resolved_findings[0].kind);
    try std.testing.expectEqual(@as(usize, 1), diff.added_fiber_terminals.len);
    try std.testing.expectEqual(@as(?u64, 4), diff.added_fiber_terminals[0].fiber_id);
    try std.testing.expectEqual(@as(usize, 1), diff.added_resource_finalizations.len);
    try std.testing.expectEqual(@as(?u64, 3), diff.added_resource_finalizations[0].resource_id);
    try std.testing.expect(diff.added_lineage_edges.len >= 2);
    try std.testing.expect(diff.summary().improved());
}

test "semantic causal graph diff formats workbench artifact json" {
    const before = [_]fx.CausalEvent{
        .{ .kind = .run_started, .run_id = 1, .status = "started" },
        .{ .kind = .resource_acquired, .run_id = 1, .scope_id = 2, .resource_id = 3, .status = "acquired", .type_name = "db" },
    };
    const after = [_]fx.CausalEvent{
        .{ .kind = .run_started, .run_id = 1, .status = "started" },
        .{ .kind = .resource_acquired, .run_id = 1, .scope_id = 2, .resource_id = 3, .status = "acquired", .type_name = "db" },
        .{ .kind = .resource_finalized, .run_id = 1, .scope_id = 2, .resource_id = 3, .parent_id = 2, .cause_event_id = 2, .status = "success", .type_name = "db" },
    };

    var diff = try fx.diffCausalGraphs(std.testing.allocator, &before, &after);
    defer diff.deinit();

    const json = try fx.formatCausalGraphDiffJson(std.testing.allocator, diff, "before.json", "after.json");
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema\":\"zigeffect.causal.semantic-diff.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"before\":\"before.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"after\":\"after.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"resolved_findings\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"added_resource_finalizations\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"type_name\":\"db\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"added_lineage_edges\"") != null);
}
