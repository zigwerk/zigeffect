const std = @import("std");
const causal = @import("causal.zig");
const causal_nendb_storage_backend = @import("causal_nendb_storage_backend.zig");
const causal_ops = @import("causal_ops.zig");

pub const Allocator = std.mem.Allocator;
pub const CausalSnapshot = causal.CausalSnapshot;
pub const CausalStore = causal.CausalStore;
pub const CausalNendbStorageBackendState = causal_nendb_storage_backend.CausalNendbStorageBackendState;
pub const CausalOpsPolicy = causal_ops.CausalOpsPolicy;
pub const CausalOpsReadRequest = causal_ops.CausalOpsReadRequest;
pub const CausalOpsRetentionDecision = causal_ops.CausalOpsRetentionDecision;

pub const causal_ops_artifact_response_schema = "zigeffect.causal.ops-artifact-response.v1";
pub const causal_ops_artifact_response_schema_version: u32 = 1;

pub const CausalOpsArtifactReadResult = struct {
    allowed: bool,
    reason: []const u8,
    snapshot: ?CausalSnapshot = null,

    pub fn deinit(self: *CausalOpsArtifactReadResult) void {
        if (self.snapshot) |*snapshot| {
            snapshot.deinit();
        }
        self.* = .{
            .allowed = false,
            .reason = "",
        };
    }
};

pub const CausalOpsArtifactHttpResponse = struct {
    allocator: Allocator,
    status: u16,
    body: []const u8,

    pub fn deinit(self: *CausalOpsArtifactHttpResponse) void {
        if (self.body.len > 0) self.allocator.free(self.body);
        self.body = "";
    }
};

pub fn readCausalOpsArtifact(
    allocator: Allocator,
    storage: *const CausalNendbStorageBackendState,
    policy: CausalOpsPolicy,
    request: CausalOpsReadRequest,
) Allocator.Error!CausalOpsArtifactReadResult {
    if (!policy.canRead(request)) {
        return .{
            .allowed = false,
            .reason = "access denied",
        };
    }

    const snapshot = if (request.scope_id) |scope_id|
        try storage.eventsByScope(allocator, scope_id)
    else
        try storage.snapshot(allocator);

    return .{
        .allowed = true,
        .reason = "access granted",
        .snapshot = snapshot,
    };
}

pub fn checkCausalOpsStorageRetention(
    policy: CausalOpsPolicy,
    alert_store: *CausalStore,
    storage: *const CausalNendbStorageBackendState,
    dropped_events: usize,
) Allocator.Error!CausalOpsRetentionDecision {
    return policy.checkRetentionAndAlert(alert_store, .{
        .current_events = storage.eventCount(),
        .dropped_events = dropped_events,
    });
}

pub fn formatCausalOpsArtifactResponseJson(
    allocator: Allocator,
    storage: *const CausalNendbStorageBackendState,
    policy: CausalOpsPolicy,
    request: CausalOpsReadRequest,
) Allocator.Error![]const u8 {
    var result = try readCausalOpsArtifact(allocator, storage, policy, request);
    defer result.deinit();

    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\"schema\":");
    try appendJsonString(&output, allocator, causal_ops_artifact_response_schema);
    try output.print(allocator, ",\"schema_version\":{d}", .{causal_ops_artifact_response_schema_version});
    try output.print(allocator, ",\"allowed\":{s}", .{if (result.allowed) "true" else "false"});
    try output.appendSlice(allocator, ",\"reason\":");
    try appendJsonString(&output, allocator, result.reason);

    if (!result.allowed) {
        try output.appendSlice(allocator, ",\"event_count\":0}");
        return output.toOwnedSlice(allocator);
    }

    const snapshot = result.snapshot.?;
    try output.print(allocator, ",\"event_count\":{d},\"events\":[", .{snapshot.events.len});
    for (snapshot.events, 0..) |event, index| {
        if (index > 0) try output.appendSlice(allocator, ",");
        try output.print(allocator, "{{\"id\":{d},\"kind\":", .{event.id});
        try appendJsonString(&output, allocator, @tagName(event.kind));
        try output.appendSlice(allocator, ",\"run_id\":");
        try appendOptionalU64(&output, allocator, event.run_id);
        try output.appendSlice(allocator, ",\"scope_id\":");
        try appendOptionalU64(&output, allocator, event.scope_id);
        try output.appendSlice(allocator, ",\"fiber_id\":");
        try appendOptionalU64(&output, allocator, event.fiber_id);
        try output.appendSlice(allocator, ",\"status\":");
        try appendRedactedJsonString(&output, allocator, event.status);
        try output.appendSlice(allocator, ",\"label\":");
        try appendRedactedJsonString(&output, allocator, event.label);
        try output.appendSlice(allocator, ",\"type_name\":");
        try appendRedactedJsonString(&output, allocator, event.type_name);
        try output.appendSlice(allocator, "}");
    }
    try output.appendSlice(allocator, "]}");
    return output.toOwnedSlice(allocator);
}

pub fn formatCausalOpsArtifactHttpResponse(
    allocator: Allocator,
    storage: *const CausalNendbStorageBackendState,
    policy: CausalOpsPolicy,
    request: CausalOpsReadRequest,
) Allocator.Error!CausalOpsArtifactHttpResponse {
    const allowed = policy.canRead(request);
    const body = try formatCausalOpsArtifactResponseJson(allocator, storage, policy, request);
    return .{
        .allocator = allocator,
        .status = if (allowed) 200 else 403,
        .body = body,
    };
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
        "authorization:",
        "cookie:",
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

fn appendOptionalU64(output: *std.ArrayList(u8), allocator: Allocator, value: ?u64) Allocator.Error!void {
    if (value) |number| {
        try output.print(allocator, "{d}", .{number});
    } else {
        try output.appendSlice(allocator, "null");
    }
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
