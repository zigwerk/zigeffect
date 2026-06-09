const std = @import("std");
const fx = @import("zigeffect");

fn hasEvent(
    snapshot: fx.CausalSnapshot,
    kind: fx.CausalEventKind,
    label_substring: []const u8,
    status: []const u8,
) bool {
    for (snapshot.events) |event| {
        if (event.kind == kind and
            std.mem.indexOf(u8, event.label, label_substring) != null and
            std.mem.eql(u8, event.status, status))
        {
            return true;
        }
    }
    return false;
}

test "app request trace records bounded workbench-compatible lifecycle events" {
    const options = fx.defaultRequestCausalStoreOptions();
    try std.testing.expectEqual(@as(?usize, fx.default_request_max_events), options.max_events);
    try std.testing.expectEqual(@as(?usize, fx.default_app_max_event_string_bytes), options.max_event_string_bytes);

    var store = fx.CausalStore.initWithOptions(std.testing.allocator, options);
    defer store.deinit();

    var trace = try fx.CausalAppTrace.startRequest(&store, .{
        .method = "GET",
        .route = "/api/projects/:id",
        .runtime = "worker",
        .trace_id = 42,
    });
    try trace.recordServiceResolution("ProjectService", "satisfied");
    const scope_id = try trace.openScope("request scope");
    try trace.recordResourceAcquired("hyperdrive connection", scope_id);
    try trace.recordRetryAttempt("load project", 2, 3, "retrying");
    try trace.recordResourceFinalized("hyperdrive connection", scope_id, "success");
    try trace.closeScope(scope_id, "success");
    try trace.complete(.success);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    try std.testing.expect(hasEvent(snapshot, .run_started, "app.request GET /api/projects/:id", "started"));
    try std.testing.expect(hasEvent(snapshot, .service_required, "ProjectService", "satisfied"));
    try std.testing.expect(hasEvent(snapshot, .scope_opened, "request scope", "opened"));
    try std.testing.expect(hasEvent(snapshot, .resource_acquired, "hyperdrive connection", "success"));
    try std.testing.expect(hasEvent(snapshot, .schedule_decision, "load project", "retrying"));
    try std.testing.expect(hasEvent(snapshot, .resource_finalized, "hyperdrive connection", "success"));
    try std.testing.expect(hasEvent(snapshot, .scope_closed, "request scope", "success"));
    try std.testing.expect(hasEvent(snapshot, .run_completed, "app.request GET /api/projects/:id", "success"));

    const json = try fx.formatCausalJson(std.testing.allocator, &store);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema\": \"zigeffect.causal.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "ProjectService") != null);
}

test "app request trace records config and requirement failures as causal findings" {
    var store = fx.CausalStore.initWithOptions(std.testing.allocator, fx.defaultRequestCausalStoreOptions());
    defer store.deinit();

    var trace = try fx.CausalAppTrace.startRequest(&store, .{
        .method = "POST",
        .route = "/api/projects",
        .runtime = "worker",
    });
    try trace.recordConfigFailure("database.password", "MissingConfig");
    try trace.recordRequirementFailure("ProjectRepository", "MissingService");
    try trace.complete(.failure);

    var findings = try store.findings(std.testing.allocator);
    defer findings.deinit();

    try std.testing.expectEqual(@as(usize, 2), findings.items.len);
    try std.testing.expectEqual(fx.CausalFindingKind.assertion_failure, findings.items[0].kind);
    try std.testing.expectEqual(fx.CausalFindingKind.assertion_failure, findings.items[1].kind);

    const json = try fx.formatCausalJson(std.testing.allocator, &store);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "database.password") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "ProjectRepository") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "MissingConfig") != null);
}

test "app trace redacts accidental sensitive values before JSON export" {
    var store = fx.CausalStore.initWithOptions(std.testing.allocator, fx.defaultRequestCausalStoreOptions());
    defer store.deinit();

    var trace = try fx.CausalAppTrace.startRequest(&store, .{
        .method = "GET",
        .route = "/api/private",
        .runtime = "worker",
    });
    try trace.recordRequirementFailure("Authorization token=raw-secret", "Rejected");
    try trace.complete(.failure);

    const json = try fx.formatCausalJson(std.testing.allocator, &store);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "raw-secret") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, fx.causal_redaction_marker) != null);
}

test "app background job trace uses job defaults and distinct lifecycle labels" {
    const options = fx.defaultJobCausalStoreOptions();
    try std.testing.expectEqual(@as(?usize, fx.default_job_max_events), options.max_events);

    var store = fx.CausalStore.initWithOptions(std.testing.allocator, options);
    defer store.deinit();

    var trace = try fx.CausalAppTrace.startJob(&store, .{
        .job_name = "daily-rollup",
        .runtime = "worker-cron",
        .trace_id = 99,
    });
    try trace.recordLayerConstruction("RollupLayer", "success");
    try trace.recordFiberStatus("rollup fiber", 7, .started);
    try trace.recordFiberStatus("rollup fiber", 7, .success);
    try trace.complete(.success);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    try std.testing.expect(hasEvent(snapshot, .run_started, "app.job daily-rollup", "started"));
    try std.testing.expect(hasEvent(snapshot, .layer_completed, "RollupLayer", "success"));
    try std.testing.expect(hasEvent(snapshot, .fiber_started, "rollup fiber", "started"));
    try std.testing.expect(hasEvent(snapshot, .fiber_joined, "rollup fiber", "success"));
    try std.testing.expect(hasEvent(snapshot, .run_completed, "app.job daily-rollup", "success"));
}
