const std = @import("std");
const fx = @import("zigeffect");

test "causal ops policy enforces actor scope access" {
    const policy = fx.CausalOpsPolicy{
        .deployment = .{ .service = "zigeffect", .environment = "test", .region = "local", .cluster_id = "cluster-a" },
        .access = .{
            .actor_id = "agent-1",
            .allowed_scope_id = 42,
        },
    };

    try std.testing.expect(policy.canRead(.{ .actor_id = "agent-1", .scope_id = 42 }));
    try std.testing.expect(!policy.canRead(.{ .actor_id = "agent-2", .scope_id = 42 }));
    try std.testing.expect(!policy.canRead(.{ .actor_id = "agent-1", .scope_id = 99 }));
}

test "causal ops emits retention alert as causal fact" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    const policy = fx.CausalOpsPolicy{
        .deployment = .{ .service = "zigeffect", .environment = "test", .region = "local", .cluster_id = "cluster-a" },
        .retention = .{ .max_events = 2, .alert_threshold = 1 },
    };

    const decision = try policy.checkRetentionAndAlert(&store, .{ .current_events = 4, .dropped_events = 2 });
    try std.testing.expect(decision.alert_emitted);
    try std.testing.expectEqual(fx.CausalOpsRetentionAction.trim, decision.action);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 1), snapshot.events.len);
    try std.testing.expectEqual(fx.CausalEventKind.alert_emitted, snapshot.events[0].kind);
    try std.testing.expectEqualStrings("retention.threshold", snapshot.events[0].type_name);
}
