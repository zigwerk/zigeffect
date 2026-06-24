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

pub const CausalOpsAlertSink = struct {
    state: ?*anyopaque = null,
    emit: *const fn (?*anyopaque, CausalEvent) anyerror!void,
};

pub const CausalOpsAlertReport = struct {
    scanned_events: usize = 0,
    emitted_alerts: usize = 0,
};

pub const CausalOpsRunbookOptions = struct {
    deployment: CausalDeploymentMetadata,
    retention: CausalOpsRetentionPolicy,
    retained_events: usize = 0,
    alert_count: usize = 0,
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
    try output.appendSlice(allocator, "}}");
    return output.toOwnedSlice(allocator);
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
