const std = @import("std");
const fx = @import("zigeffect");

fn noOpNendbWrite(_: ?*anyopaque, _: fx.CausalNendbWrite) anyerror!void {}

fn noOpWriter() fx.CausalNendbGraphWriter {
    return .{ .write = noOpNendbWrite };
}

fn opsPolicy() fx.CausalOpsPolicy {
    return .{
        .deployment = .{
            .service = "zigeffect",
            .environment = "test",
            .region = "local",
            .cluster_id = "cluster-a",
        },
        .access = .{
            .actor_id = "agent-1",
            .allowed_scope_id = 10,
        },
        .retention = .{
            .max_events = 1,
            .alert_threshold = 1,
        },
    };
}

test "ops storage adapter denies unauthorized artifact reads" {
    var storage = fx.CausalNendbStorageBackendState.init(std.testing.allocator, noOpWriter(), .{});
    defer storage.deinit();

    var result = try fx.readCausalOpsArtifact(std.testing.allocator, &storage, opsPolicy(), .{
        .actor_id = "other-agent",
        .scope_id = 10,
    });
    defer result.deinit();

    try std.testing.expect(!result.allowed);
    try std.testing.expect(result.snapshot == null);
    try std.testing.expectEqualStrings("access denied", result.reason);
}

test "ops storage adapter returns scoped artifact snapshots for authorized actors" {
    var storage = fx.CausalNendbStorageBackendState.init(std.testing.allocator, noOpWriter(), .{});
    defer storage.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(storage.backend());
    defer store.deinit();

    _ = try store.record(.{
        .kind = .resource_acquired,
        .scope_id = 10,
        .label = "allowed resource",
        .type_name = "Db",
        .status = "success",
    });
    _ = try store.record(.{
        .kind = .resource_acquired,
        .scope_id = 11,
        .label = "other resource",
        .type_name = "Cache",
        .status = "success",
    });

    var result = try fx.readCausalOpsArtifact(std.testing.allocator, &storage, opsPolicy(), .{
        .actor_id = "agent-1",
        .scope_id = 10,
    });
    defer result.deinit();

    try std.testing.expect(result.allowed);
    try std.testing.expect(result.snapshot != null);
    try std.testing.expectEqual(@as(usize, 1), result.snapshot.?.events.len);
    try std.testing.expectEqual(@as(?u64, 10), result.snapshot.?.events[0].scope_id);
    try std.testing.expectEqualStrings("access granted", result.reason);
}

test "ops storage adapter emits retention alerts from durable storage state" {
    var storage = fx.CausalNendbStorageBackendState.init(std.testing.allocator, noOpWriter(), .{});
    defer storage.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(storage.backend());
    defer store.deinit();

    _ = try store.record(.{ .kind = .run_started, .run_id = 1, .label = "one" });
    _ = try store.record(.{ .kind = .run_completed, .run_id = 1, .label = "two" });

    var alerts = fx.CausalStore.init(std.testing.allocator);
    defer alerts.deinit();

    const decision = try fx.checkCausalOpsStorageRetention(opsPolicy(), &alerts, &storage, 1);

    try std.testing.expectEqual(fx.CausalOpsRetentionAction.trim, decision.action);
    try std.testing.expect(decision.alert_emitted);

    var snapshot = try alerts.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 1), snapshot.events.len);
    try std.testing.expectEqual(fx.CausalEventKind.alert_emitted, snapshot.events[0].kind);
}

test "ops artifact endpoint response gates and redacts event evidence" {
    var storage = fx.CausalNendbStorageBackendState.init(std.testing.allocator, noOpWriter(), .{});
    defer storage.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(storage.backend());
    defer store.deinit();

    _ = try store.record(.{
        .kind = .resource_acquired,
        .scope_id = 10,
        .label = "open password=sentinel-secret resource",
        .type_name = "Db",
        .status = "success",
    });

    const denied = try fx.formatCausalOpsArtifactResponseJson(std.testing.allocator, &storage, opsPolicy(), .{
        .actor_id = "other-agent",
        .scope_id = 10,
    });
    defer std.testing.allocator.free(denied);
    try std.testing.expect(std.mem.indexOf(u8, denied, "\"allowed\":false") != null);
    try std.testing.expect(std.mem.indexOf(u8, denied, "\"events\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, denied, "sentinel-secret") == null);

    const allowed = try fx.formatCausalOpsArtifactResponseJson(std.testing.allocator, &storage, opsPolicy(), .{
        .actor_id = "agent-1",
        .scope_id = 10,
    });
    defer std.testing.allocator.free(allowed);
    try std.testing.expect(std.mem.indexOf(u8, allowed, "\"schema\":\"zigeffect.causal.ops-artifact-response.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, allowed, "\"allowed\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, allowed, "\"event_count\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, allowed, fx.causal_redaction_marker) != null);
    try std.testing.expect(std.mem.indexOf(u8, allowed, "sentinel-secret") == null);
}
