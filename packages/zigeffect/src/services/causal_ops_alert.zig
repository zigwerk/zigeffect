const std = @import("std");
const causal = @import("causal.zig");
const causal_ops = @import("causal_ops.zig");

pub const Allocator = std.mem.Allocator;
pub const CausalEvent = causal.CausalEvent;
pub const CausalStore = causal.CausalStore;
pub const CausalDeploymentMetadata = causal_ops.CausalDeploymentMetadata;
pub const CausalOpsRetentionPolicy = causal_ops.CausalOpsRetentionPolicy;

pub const causal_ops_runbook_schema = "zigeffect.causal.ops-runbook.v1";
pub const causal_ops_runbook_schema_version: u32 = 1;
pub const causal_ops_alert_delivery_schema = "zigeffect.causal.ops-alert-delivery.v1";
pub const causal_ops_alert_delivery_schema_version: u32 = 1;

pub const CausalOpsAlertSink = struct {
    state: ?*anyopaque = null,
    emit: *const fn (?*anyopaque, CausalEvent) anyerror!void,
};

pub const CausalOpsAlertReport = struct {
    scanned_events: usize = 0,
    emitted_alerts: usize = 0,
};

pub const CausalOpsRunbookEndpointMetadata = struct {
    artifact_endpoint_path: []const u8,
    alert_delivery_kind: []const u8,
    alert_endpoint_id: []const u8,
};

pub const CausalOpsRunbookOptions = struct {
    deployment: CausalDeploymentMetadata,
    retention: CausalOpsRetentionPolicy,
    retained_events: usize = 0,
    alert_count: usize = 0,
    endpoints: ?CausalOpsRunbookEndpointMetadata = null,
};

pub const CausalOpsAlertDeliveryOptions = struct {
    deployment: CausalDeploymentMetadata,
    delivery_kind: []const u8,
    endpoint_id: []const u8,
    event: CausalEvent,
};

pub const CausalOpsAlertDeliverySink = struct {
    state: ?*anyopaque = null,
    deliver: *const fn (?*anyopaque, json: []const u8) anyerror!void,
};

pub const CausalOpsAlertHttpHeader = struct {
    name: []const u8,
    value: []const u8,
};

pub const causal_ops_alert_http_headers: []const CausalOpsAlertHttpHeader = &.{
    .{ .name = "content-type", .value = "application/json" },
    .{ .name = "cache-control", .value = "no-store" },
    .{ .name = "x-content-type-options", .value = "nosniff" },
};

pub const CausalOpsAlertHttpRequest = struct {
    allocator: Allocator,
    method: []const u8,
    url: []const u8,
    headers: []const CausalOpsAlertHttpHeader = causal_ops_alert_http_headers,
    body: []const u8,

    pub fn deinit(self: *CausalOpsAlertHttpRequest) void {
        if (self.body.len > 0) self.allocator.free(self.body);
        self.body = "";
    }
};

pub const CausalOpsAlertWebhookOptions = struct {
    endpoint_url: []const u8,
    delivery: CausalOpsAlertDeliveryOptions,
};

pub const CausalOpsAlertHttpSink = struct {
    state: ?*anyopaque = null,
    send: *const fn (?*anyopaque, CausalOpsAlertHttpRequest) anyerror!void,
};

pub fn emitCausalOpsAlerts(
    store: *const CausalStore,
    sink: CausalOpsAlertSink,
) anyerror!CausalOpsAlertReport {
    var report = CausalOpsAlertReport{};
    for (store.events.items) |event| {
        report.scanned_events += 1;
        if (event.kind != .alert_emitted) continue;
        try sink.emit(sink.state, event);
        report.emitted_alerts += 1;
    }
    return report;
}

pub fn formatCausalOpsRunbookJson(
    allocator: Allocator,
    options: CausalOpsRunbookOptions,
) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\"schema\":");
    try appendJsonString(&output, allocator, causal_ops_runbook_schema);
    try output.print(allocator, ",\"schema_version\":{d}", .{causal_ops_runbook_schema_version});
    try output.appendSlice(allocator, ",\"deployment\":{\"service\":");
    try appendJsonString(&output, allocator, options.deployment.service);
    try output.appendSlice(allocator, ",\"environment\":");
    try appendJsonString(&output, allocator, options.deployment.environment);
    try output.appendSlice(allocator, ",\"region\":");
    try appendJsonString(&output, allocator, options.deployment.region);
    try output.appendSlice(allocator, ",\"cluster_id\":");
    try appendRedactedJsonString(&output, allocator, options.deployment.cluster_id);
    try output.appendSlice(allocator, "},\"retention\":{");
    try output.print(allocator, "\"max_events\":{d}", .{options.retention.max_events});
    try output.print(allocator, ",\"alert_threshold\":{d}", .{options.retention.alert_threshold});
    try output.print(allocator, ",\"retained_events\":{d}", .{options.retained_events});
    try output.print(allocator, ",\"alert_count\":{d}", .{options.alert_count});
    try output.print(
        allocator,
        ",\"trim_required\":{s}",
        .{if (options.retention.max_events > 0 and options.retained_events > options.retention.max_events) "true" else "false"},
    );
    try output.appendSlice(allocator, "}");
    if (options.endpoints) |endpoints| {
        try output.appendSlice(allocator, ",\"operator_endpoints\":{\"artifact_endpoint_path\":");
        try appendRedactedJsonString(&output, allocator, endpoints.artifact_endpoint_path);
        try output.appendSlice(allocator, ",\"alert_delivery_kind\":");
        try appendRedactedJsonString(&output, allocator, endpoints.alert_delivery_kind);
        try output.appendSlice(allocator, ",\"alert_endpoint_id\":");
        try appendRedactedJsonString(&output, allocator, endpoints.alert_endpoint_id);
        try output.appendSlice(allocator, "}");
    }
    try output.appendSlice(allocator, "}");
    return output.toOwnedSlice(allocator);
}

pub fn formatCausalOpsAlertDeliveryJson(
    allocator: Allocator,
    options: CausalOpsAlertDeliveryOptions,
) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\"schema\":");
    try appendJsonString(&output, allocator, causal_ops_alert_delivery_schema);
    try output.print(allocator, ",\"schema_version\":{d}", .{causal_ops_alert_delivery_schema_version});
    try output.appendSlice(allocator, ",\"delivery\":{\"delivery_kind\":");
    try appendJsonString(&output, allocator, options.delivery_kind);
    try output.appendSlice(allocator, ",\"endpoint_id\":");
    try appendJsonString(&output, allocator, options.endpoint_id);
    try output.appendSlice(allocator, "},\"deployment\":{\"service\":");
    try appendJsonString(&output, allocator, options.deployment.service);
    try output.appendSlice(allocator, ",\"environment\":");
    try appendJsonString(&output, allocator, options.deployment.environment);
    try output.appendSlice(allocator, ",\"region\":");
    try appendJsonString(&output, allocator, options.deployment.region);
    try output.appendSlice(allocator, ",\"cluster_id\":");
    try appendRedactedJsonString(&output, allocator, options.deployment.cluster_id);
    try output.appendSlice(allocator, "},\"alert_event\":{\"event_id\":");
    try output.print(allocator, "{d}", .{options.event.id});
    try output.appendSlice(allocator, ",\"kind\":");
    try appendJsonString(&output, allocator, @tagName(options.event.kind));
    try output.appendSlice(allocator, ",\"status\":");
    try appendRedactedJsonString(&output, allocator, options.event.status);
    try output.appendSlice(allocator, ",\"label\":");
    try appendRedactedJsonString(&output, allocator, options.event.label);
    try output.appendSlice(allocator, ",\"type_name\":");
    try appendRedactedJsonString(&output, allocator, options.event.type_name);
    try output.appendSlice(allocator, ",\"redacted_detail\":");
    try appendRedactedJsonString(&output, allocator, options.event.redacted_detail);
    try output.appendSlice(allocator, "}}");
    return output.toOwnedSlice(allocator);
}

pub fn deliverCausalOpsAlert(
    allocator: Allocator,
    options: CausalOpsAlertDeliveryOptions,
    sink: CausalOpsAlertDeliverySink,
) anyerror!void {
    const json = try formatCausalOpsAlertDeliveryJson(allocator, options);
    defer allocator.free(json);
    try sink.deliver(sink.state, json);
}

pub fn formatCausalOpsAlertWebhookRequest(
    allocator: Allocator,
    options: CausalOpsAlertWebhookOptions,
) Allocator.Error!CausalOpsAlertHttpRequest {
    const body = try formatCausalOpsAlertDeliveryJson(allocator, options.delivery);
    return .{
        .allocator = allocator,
        .method = "POST",
        .url = options.endpoint_url,
        .body = body,
    };
}

pub fn deliverCausalOpsAlertWebhook(
    allocator: Allocator,
    options: CausalOpsAlertWebhookOptions,
    sink: CausalOpsAlertHttpSink,
) anyerror!void {
    var request = try formatCausalOpsAlertWebhookRequest(allocator, options);
    defer request.deinit();
    try sink.send(sink.state, request);
}

fn appendRedactedJsonString(output: *std.ArrayList(u8), allocator: Allocator, value: []const u8) Allocator.Error!void {
    if (containsSensitiveText(value)) {
        try appendJsonString(output, allocator, causal.causal_redaction_marker);
    } else {
        try appendJsonString(output, allocator, value);
    }
}

fn containsSensitiveText(value: []const u8) bool {
    const needles = [_][]const u8{
        "password=",
        "token=",
        "secret=",
        "api_key=",
        "apikey=",
        "bearer ",
    };
    var lower_buf: [256]u8 = undefined;
    const len = @min(value.len, lower_buf.len);
    for (value[0..len], 0..) |byte, index| {
        lower_buf[index] = std.ascii.toLower(byte);
    }
    const lower = lower_buf[0..len];
    for (needles) |needle| {
        if (std.mem.indexOf(u8, lower, needle) != null) return true;
    }
    return false;
}

fn appendJsonString(output: *std.ArrayList(u8), allocator: Allocator, value: []const u8) Allocator.Error!void {
    try output.append(allocator, '"');
    for (value) |byte| {
        switch (byte) {
            '"' => try output.appendSlice(allocator, "\\\""),
            '\\' => try output.appendSlice(allocator, "\\\\"),
            '\n' => try output.appendSlice(allocator, "\\n"),
            '\r' => try output.appendSlice(allocator, "\\r"),
            '\t' => try output.appendSlice(allocator, "\\t"),
            else => try output.append(allocator, byte),
        }
    }
    try output.append(allocator, '"');
}
