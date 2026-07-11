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

test "runner lineage artifact includes deployment metadata and cross-runner edges" {
    const runner_a_events = [_]fx.CausalEvent{
        .{
            .id = 1,
            .kind = .cluster_message_submitted,
            .run_id = 100,
            .label = "submit from runner a",
            .status = "submitted",
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

    const deployments = [_]fx.CausalRunnerDeploymentMetadata{
        .{
            .runner_id = "runner-a",
            .service = "zigeffect",
            .environment = "prod",
            .region = "lhr",
            .address = "tcp://runner-a.internal:7001",
            .health = "healthy",
            .tls_enabled = true,
            .auth_epoch = 41,
        },
        .{
            .runner_id = "runner-b",
            .service = "zigeffect",
            .environment = "prod",
            .region = "ams",
            .address = "tcp://runner-b.internal:7001",
            .health = "healthy",
            .tls_enabled = true,
            .auth_epoch = 42,
        },
    };

    const json = try fx.formatCausalRunnerLineageJson(std.testing.allocator, stitched, .{
        .deployment_id = "deploy-2026-06-24",
        .deployments = &deployments,
    });
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema\":\"zigeffect.causal.runner-lineage.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"deployment_id\":\"deploy-2026-06-24\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"runner_id\":\"runner-a\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"auth_epoch\":42") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"tls_enabled\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"from_runner_id\":\"runner-a\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"to_runner_id\":\"runner-b\"") != null);
}

test "runner lineage artifact escapes control bytes into parseable json" {
    const runner_a_events = [_]fx.CausalEvent{
        .{
            .id = 1,
            .kind = .cluster_message_submitted,
            .run_id = 100,
            .label = "submit from runner a",
            .status = "submitted",
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
        .{ .runner_id = "runner\x1ba", .events = &runner_a_events },
        .{ .runner_id = "runner\x1bb", .events = &runner_b_events },
    });
    defer stitched.deinit();

    const json = try fx.formatCausalRunnerLineageJson(std.testing.allocator, stitched, .{
        .deployment_id = "deploy\x082026",
    });
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\\u001b") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\\u0008") != null);
    try std.testing.expect(std.mem.indexOfScalar(u8, json, 0x1b) == null);
    try std.testing.expect(std.mem.indexOfScalar(u8, json, 0x08) == null);

    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{});
    defer parsed.deinit();
    const edge = parsed.value.object.get("cross_runner_edges").?.array.items[0];
    try std.testing.expectEqualStrings("runner\x1ba", edge.object.get("from_runner_id").?.string);
    try std.testing.expectEqualStrings("runner\x1bb", edge.object.get("to_runner_id").?.string);
}

test "runner deployment metadata validation reports unsafe deployment evidence" {
    const deployments = [_]fx.CausalRunnerDeploymentMetadata{
        .{
            .runner_id = "runner-a",
            .service = "zigeffect",
            .environment = "prod",
            .region = "lhr",
            .address = "",
            .health = "degraded",
            .tls_enabled = false,
            .auth_epoch = 3,
        },
        .{
            .runner_id = "runner-b",
            .service = "zigeffect",
            .environment = "prod",
            .region = "ams",
            .address = "tcp://runner-b.internal:7001",
            .health = "healthy",
            .tls_enabled = true,
            .auth_epoch = 12,
        },
    };

    const report = fx.validateCausalRunnerDeployments(&deployments, .{
        .require_tls = true,
        .require_address = true,
        .require_healthy = true,
        .min_auth_epoch = 10,
    });

    try std.testing.expect(!report.ok());
    try std.testing.expectEqual(@as(usize, 2), report.checked);
    try std.testing.expectEqual(@as(usize, 1), report.missing_tls);
    try std.testing.expectEqual(@as(usize, 1), report.missing_address);
    try std.testing.expectEqual(@as(usize, 1), report.unhealthy);
    try std.testing.expectEqual(@as(usize, 1), report.stale_auth_epoch);
}
