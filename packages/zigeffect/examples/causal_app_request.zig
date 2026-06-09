const std = @import("std");
const fx = @import("zigeffect");

pub const AppRequest = struct {
    method: []const u8,
    route: []const u8,
};

pub const AppEnv = struct {
    environment: ?[]const u8 = null,
};

pub const AppResponse = struct {
    status: u16,
    body: []const u8,
};

pub const AppIncident = struct {
    allocator: std.mem.Allocator,
    response: AppResponse,
    causal_json: []const u8,

    pub fn deinit(self: *AppIncident) void {
        self.allocator.free(self.causal_json);
    }
};

pub fn handleRequest(
    allocator: std.mem.Allocator,
    request: AppRequest,
    env: AppEnv,
) !AppIncident {
    var store = fx.CausalStore.initWithOptions(allocator, fx.defaultRequestCausalStoreOptions());
    defer store.deinit();

    var trace = try fx.CausalAppTrace.startRequest(&store, .{
        .method = request.method,
        .route = request.route,
        .runtime = "worker",
    });

    try trace.recordLayerConstruction("HealthLayer", "success");
    const scope_id = try trace.openScope("app request scope");

    if (env.environment) |environment| {
        try trace.recordServiceResolution("HealthService", "satisfied");
        _ = try trace.recordDataRead("app.environment", .{
            .data_subject_ref = environment,
            .schema_ref = "AppEnv.v1",
        }, "observed");
        _ = try trace.recordResponseSent("app.response", .{
            .artifact_id = "response:health",
            .schema_ref = "HealthResponse.v1",
        }, "200");
        _ = try trace.recordArtifactEmitted("causal app health response", .{
            .artifact_id = "response:health",
            .schema_ref = "HealthResponse.v1",
        }, "success");
        try trace.closeScope(scope_id, "success");
        try trace.complete(.success);

        return .{
            .allocator = allocator,
            .response = .{ .status = 200, .body = "ok" },
            .causal_json = try fx.formatCausalJson(allocator, &store),
        };
    }

    try trace.recordConfigFailure("YACHDEE_ENV", "MissingConfig");
    try trace.recordRequirementFailure("HealthService", "MissingService");
    _ = try trace.recordResponseSent("app.response", .{
        .artifact_id = "response:health-error",
        .schema_ref = "ErrorResponse.v1",
    }, "500");
    try trace.closeScope(scope_id, "failure");
    try trace.complete(.failure);

    return .{
        .allocator = allocator,
        .response = .{ .status = 500, .body = "missing_environment" },
        .causal_json = try fx.formatCausalJson(allocator, &store),
    };
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var incident = try handleRequest(allocator, .{
        .method = "GET",
        .route = "/health",
    }, .{
        .environment = "local",
    });
    defer incident.deinit();
    std.debug.print("status={d} body={s}\n{s}", .{
        incident.response.status,
        incident.response.body,
        incident.causal_json,
    });
}

fn jsonContains(json: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, json, needle) != null;
}

test "causal app request example returns health response and standard causal JSON" {
    var incident = try handleRequest(std.testing.allocator, .{
        .method = "GET",
        .route = "/health",
    }, .{
        .environment = "test",
    });
    defer incident.deinit();

    try std.testing.expectEqual(@as(u16, 200), incident.response.status);
    try std.testing.expectEqualStrings("ok", incident.response.body);
    try std.testing.expect(jsonContains(incident.causal_json, "\"schema\": \"zigeffect.causal.v1\""));
    try std.testing.expect(jsonContains(incident.causal_json, "app.request GET /health"));
    try std.testing.expect(jsonContains(incident.causal_json, "HealthService"));
    try std.testing.expect(jsonContains(incident.causal_json, "\"kind\": \"run_completed\""));
    try std.testing.expect(jsonContains(incident.causal_json, "\"status\": \"success\""));
}

test "causal app request example records missing environment as app incident finding" {
    var incident = try handleRequest(std.testing.allocator, .{
        .method = "GET",
        .route = "/health",
    }, .{});
    defer incident.deinit();

    try std.testing.expectEqual(@as(u16, 500), incident.response.status);
    try std.testing.expectEqualStrings("missing_environment", incident.response.body);
    try std.testing.expect(jsonContains(incident.causal_json, "YACHDEE_ENV"));
    try std.testing.expect(jsonContains(incident.causal_json, "MissingConfig"));
    try std.testing.expect(jsonContains(incident.causal_json, "HealthService"));
    try std.testing.expect(jsonContains(incident.causal_json, "\"kind\": \"assertion_recorded\""));
    try std.testing.expect(jsonContains(incident.causal_json, "\"status\": \"failure\""));
}

test "causal app request example redacts accidental sensitive environment values" {
    var incident = try handleRequest(std.testing.allocator, .{
        .method = "GET",
        .route = "/health",
    }, .{
        .environment = "token=raw-secret",
    });
    defer incident.deinit();

    try std.testing.expect(std.mem.indexOf(u8, incident.causal_json, "raw-secret") == null);
    try std.testing.expect(jsonContains(incident.causal_json, fx.causal_redaction_marker));
}
