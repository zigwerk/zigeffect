const std = @import("std");
const fx = @import("zigeffect");

test "runner lineage stitcher reports cross-runner cause edges" {
    const runner_a_events = [_]fx.CausalEvent{
        .{
            .id = 1,
            .kind = .cluster_message_submitted,
            .run_id = 100,
            .label = "submit from runner a",
            .status = "submitted",
        },
        .{
            .id = 3,
            .kind = .cluster_runner_heartbeat,
            .run_id = 100,
            .label = "same runner event",
            .cause_event_id = 1,
            .status = "ok",
        },
    };
    const runner_b_events = [_]fx.CausalEvent{
        .{
            .id = 2,
            .kind = .cluster_message_replied,
            .run_id = 200,
            .cause_event_id = 1,
            .label = "reply from runner b",
            .status = "replied",
        },
    };

    var stitched = try fx.stitchCausalRunnerLineage(std.testing.allocator, &.{
        .{ .runner_id = "runner-a", .events = &runner_a_events },
        .{ .runner_id = "runner-b", .events = &runner_b_events },
    });
    defer stitched.deinit();

    try std.testing.expectEqual(@as(usize, 3), stitched.events.len);
    try std.testing.expectEqual(@as(usize, 1), stitched.cross_runner_edges.len);
    try std.testing.expectEqual(@as(u64, 1), stitched.cross_runner_edges[0].from_event_id);
    try std.testing.expectEqual(@as(u64, 2), stitched.cross_runner_edges[0].to_event_id);
    try std.testing.expectEqualStrings("runner-a", stitched.cross_runner_edges[0].from_runner_id);
    try std.testing.expectEqualStrings("runner-b", stitched.cross_runner_edges[0].to_runner_id);
    try std.testing.expectEqualStrings("cause_event_id", stitched.cross_runner_edges[0].edge_kind);
}
