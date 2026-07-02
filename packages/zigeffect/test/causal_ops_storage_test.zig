const std = @import("std");
const fx = @import("zigeffect");

fn noOpNendbWrite(_: ?*anyopaque, _: fx.CausalNendbWrite) anyerror!void {}

fn noOpWriter() fx.CausalNendbGraphWriter {
    return .{ .write = noOpNendbWrite };
}

fn hasHttpHeader(
    headers: []const fx.CausalOpsArtifactHttpHeader,
    name: []const u8,
    value: []const u8,
) bool {
    for (headers) |header| {
        if (std.mem.eql(u8, header.name, name) and std.mem.eql(u8, header.value, value)) return true;
    }
    return false;
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

test "ops artifact endpoint response escapes control bytes in event evidence" {
    var storage = fx.CausalNendbStorageBackendState.init(std.testing.allocator, noOpWriter(), .{});
    defer storage.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(storage.backend());
    defer store.deinit();

    _ = try store.record(.{
        .kind = .resource_acquired,
        .scope_id = 10,
        .label = "ansi \x1b[31mred\x1b[0m resource",
        .type_name = "Db",
        .status = "success",
    });

    const json = try fx.formatCausalOpsArtifactResponseJson(std.testing.allocator, &storage, opsPolicy(), .{
        .actor_id = "agent-1",
        .scope_id = 10,
    });
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\\u001b") != null);
    try std.testing.expect(std.mem.indexOfScalar(u8, json, 0x1b) == null);

    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{});
    defer parsed.deinit();
    const label = parsed.value.object.get("events").?.array.items[0].object.get("label").?.string;
    try std.testing.expectEqualStrings("ansi \x1b[31mred\x1b[0m resource", label);
}

test "ops artifact http response wraps policy result with status code" {
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

    var denied = try fx.formatCausalOpsArtifactHttpResponse(std.testing.allocator, &storage, opsPolicy(), .{
        .actor_id = "other-agent",
        .scope_id = 10,
    });
    defer denied.deinit();
    try std.testing.expectEqual(@as(u16, 403), denied.status);
    try std.testing.expect(std.mem.indexOf(u8, denied.body, "\"allowed\":false") != null);
    try std.testing.expect(std.mem.indexOf(u8, denied.body, "\"events\"") == null);

    var allowed = try fx.formatCausalOpsArtifactHttpResponse(std.testing.allocator, &storage, opsPolicy(), .{
        .actor_id = "agent-1",
        .scope_id = 10,
    });
    defer allowed.deinit();
    try std.testing.expectEqual(@as(u16, 200), allowed.status);
    try std.testing.expect(std.mem.indexOf(u8, allowed.body, "\"allowed\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, allowed.body, "\"event_count\":1") != null);
}

test "ops artifact http request adapter gates method path and policy" {
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

    var wrong_method = try fx.serveCausalOpsArtifactHttpRequest(std.testing.allocator, &storage, opsPolicy(), .{
        .method = "POST",
        .path = "/causal-artifacts",
        .actor_id = "agent-1",
        .scope_id = 10,
    });
    defer wrong_method.deinit();
    try std.testing.expectEqual(@as(u16, 405), wrong_method.status);
    try std.testing.expect(hasHttpHeader(wrong_method.headers, "cache-control", "no-store"));

    var wrong_path = try fx.serveCausalOpsArtifactHttpRequest(std.testing.allocator, &storage, opsPolicy(), .{
        .method = "GET",
        .path = "/not-causal-artifacts",
        .actor_id = "agent-1",
        .scope_id = 10,
    });
    defer wrong_path.deinit();
    try std.testing.expectEqual(@as(u16, 404), wrong_path.status);
    try std.testing.expect(hasHttpHeader(wrong_path.headers, "content-type", "application/json"));

    var denied = try fx.serveCausalOpsArtifactHttpRequest(std.testing.allocator, &storage, opsPolicy(), .{
        .method = "GET",
        .path = "/causal-artifacts",
        .actor_id = "other-agent",
        .scope_id = 10,
    });
    defer denied.deinit();
    try std.testing.expectEqual(@as(u16, 403), denied.status);
    try std.testing.expect(hasHttpHeader(denied.headers, "x-content-type-options", "nosniff"));
    try std.testing.expect(std.mem.indexOf(u8, denied.body, "\"events\"") == null);

    var allowed = try fx.serveCausalOpsArtifactHttpRequest(std.testing.allocator, &storage, opsPolicy(), .{
        .method = "GET",
        .path = "/causal-artifacts",
        .actor_id = "agent-1",
        .scope_id = 10,
    });
    defer allowed.deinit();
    try std.testing.expectEqual(@as(u16, 200), allowed.status);
    try std.testing.expect(hasHttpHeader(allowed.headers, "cache-control", "no-store"));
    try std.testing.expect(std.mem.indexOf(u8, allowed.body, "\"event_count\":1") != null);
}
