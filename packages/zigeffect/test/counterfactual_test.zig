const std = @import("std");
const fx = @import("zigeffect");

test "counterfactual interrupt reduces hung fiber findings" {
    const baseline = [_]fx.CausalEvent{
        .{ .id = 1, .kind = .run_started, .run_id = 1, .status = "started" },
        .{ .id = 2, .kind = .fiber_suspended, .run_id = 1, .fiber_id = 9, .status = "suspended", .label = "await io" },
    };

    const policy = (fx.AgentInterventionPolicy{})
        .withApplyEnabled(true)
        .withKindPolicy(.interrupt_fiber, .auto_approve);

    const result = try fx.runCounterfactual(std.testing.allocator, &baseline, policy, .{
        .kind = .interrupt_fiber,
        .run_id = 1,
        .fiber_id = 9,
        .reason = "counterfactual interrupt",
    });

    try std.testing.expectEqual(@as(usize, 1), result.before_findings);
    try std.testing.expectEqual(@as(usize, 0), result.after_findings);
    try std.testing.expectEqual(@as(isize, -1), result.finding_delta);
    try std.testing.expect(result.improved);
    try std.testing.expect(result.intervention.applied);
    try std.testing.expectEqual(@as(usize, 1), result.diff_summary.resolved_findings);
    try std.testing.expectEqual(@as(usize, 1), result.diff_summary.added_fiber_terminals);
}
