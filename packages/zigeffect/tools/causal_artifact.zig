const std = @import("std");

pub const supported_causal_schema = "zigeffect.causal.v1";
pub const supported_causal_schema_version: u32 = 1;
pub const supported_event_taxonomy_version: u32 = 1;

pub const ArtifactMetadata = struct {
    schema: ?[]const u8 = null,
    schema_version: ?u32 = null,
    event_taxonomy_version: ?u32 = null,
};

pub fn appendArtifactCompatibilityWarnings(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    artifact_label: []const u8,
    metadata: ArtifactMetadata,
) std.mem.Allocator.Error!void {
    if (metadata.schema) |schema| {
        if (!std.mem.eql(u8, schema, supported_causal_schema)) {
            try output.print(
                allocator,
                "warning: {s} schema={s} unsupported; expected {s}\n",
                .{ artifact_label, schema, supported_causal_schema },
            );
        }
    }

    if (metadata.schema_version) |version| {
        if (version > supported_causal_schema_version) {
            try output.print(
                allocator,
                "warning: {s} schema_version={d} newer than supported={d}; artifact shape may be incomplete\n",
                .{ artifact_label, version, supported_causal_schema_version },
            );
        }
    }

    try appendTaxonomyVersionWarning(output, allocator, artifact_label, metadata.event_taxonomy_version);
}

pub fn appendTaxonomyVersionWarning(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    artifact_label: []const u8,
    event_taxonomy_version: ?u32,
) std.mem.Allocator.Error!void {
    const version = event_taxonomy_version orelse return;
    if (version <= supported_event_taxonomy_version) return;
    try output.print(
        allocator,
        "warning: {s} event_taxonomy_version={d} newer than supported={d}; event-kind role semantics may be incomplete\n",
        .{ artifact_label, version, supported_event_taxonomy_version },
    );
}

const known_causal_event_kinds = [_][]const u8{
    "run_started",
    "run_completed",
    "effect_started",
    "effect_completed",
    "layer_started",
    "layer_completed",
    "service_required",
    "service_provided",
    "service_replaced",
    "scope_opened",
    "scope_closed",
    "resource_acquired",
    "resource_finalized",
    "fiber_forked",
    "fiber_started",
    "fiber_joined",
    "fiber_interrupted",
    "schedule_decision",
    "exit_recorded",
    "log_recorded",
    "metric_recorded",
    "span_recorded",
    "assertion_recorded",
    "workflow_event_recorded",
};

pub fn isKnownCausalEventKind(kind: []const u8) bool {
    for (known_causal_event_kinds) |candidate| {
        if (std.mem.eql(u8, kind, candidate)) return true;
    }
    return false;
}

pub fn appendUnknownEventKindWarning(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    artifact_label: []const u8,
    kind: []const u8,
) std.mem.Allocator.Error!void {
    try output.print(
        allocator,
        "warning: {s} event kind {s} unknown to supported taxonomy={d}; query/advice role semantics may be incomplete\n",
        .{ artifact_label, kind, supported_event_taxonomy_version },
    );
}

pub fn appendUnknownEventKindWarnings(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    artifact_label: []const u8,
    events: anytype,
) std.mem.Allocator.Error!void {
    var seen = std.ArrayList([]const u8).empty;
    defer seen.deinit(allocator);

    for (events) |event| {
        if (isKnownCausalEventKind(event.kind)) continue;
        var already_seen = false;
        for (seen.items) |kind| {
            if (std.mem.eql(u8, kind, event.kind)) {
                already_seen = true;
                break;
            }
        }
        if (already_seen) continue;
        try seen.append(allocator, event.kind);
        try appendUnknownEventKindWarning(output, allocator, artifact_label, event.kind);
    }
}

test "artifact compatibility warnings cover future schema and taxonomy versions" {
    var output = std.ArrayList(u8).empty;
    defer output.deinit(std.testing.allocator);

    try appendArtifactCompatibilityWarnings(&output, std.testing.allocator, "artifact", .{
        .schema = supported_causal_schema,
        .schema_version = 2,
        .event_taxonomy_version = 3,
    });

    try std.testing.expect(std.mem.indexOf(u8, output.items, "warning: artifact schema_version=2 newer than supported=1") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.items, "warning: artifact event_taxonomy_version=3 newer than supported=1") != null);
}

test "artifact compatibility warnings accept legacy and current metadata quietly" {
    var legacy = std.ArrayList(u8).empty;
    defer legacy.deinit(std.testing.allocator);
    try appendArtifactCompatibilityWarnings(&legacy, std.testing.allocator, "legacy", .{});
    try std.testing.expectEqual(@as(usize, 0), legacy.items.len);

    var current = std.ArrayList(u8).empty;
    defer current.deinit(std.testing.allocator);
    try appendArtifactCompatibilityWarnings(&current, std.testing.allocator, "current", .{
        .schema = supported_causal_schema,
        .schema_version = supported_causal_schema_version,
        .event_taxonomy_version = supported_event_taxonomy_version,
    });
    try std.testing.expectEqual(@as(usize, 0), current.items.len);
}

test "artifact compatibility warnings flag unsupported schema names" {
    var output = std.ArrayList(u8).empty;
    defer output.deinit(std.testing.allocator);

    try appendArtifactCompatibilityWarnings(&output, std.testing.allocator, "artifact", .{
        .schema = "zigeffect.causal.v2",
        .schema_version = 1,
        .event_taxonomy_version = 1,
    });

    try std.testing.expect(std.mem.indexOf(u8, output.items, "warning: artifact schema=zigeffect.causal.v2 unsupported; expected zigeffect.causal.v1") != null);
}

test "known causal event kind helper covers current taxonomy strings" {
    try std.testing.expect(isKnownCausalEventKind("run_started"));
    try std.testing.expect(isKnownCausalEventKind("service_required"));
    try std.testing.expect(isKnownCausalEventKind("span_recorded"));
    try std.testing.expect(isKnownCausalEventKind("workflow_event_recorded"));
    try std.testing.expect(!isKnownCausalEventKind("effect_suspended"));
}

test "unknown event kind warning names the unsupported kind" {
    var output = std.ArrayList(u8).empty;
    defer output.deinit(std.testing.allocator);

    try appendUnknownEventKindWarning(&output, std.testing.allocator, "artifact", "effect_suspended");

    try std.testing.expect(std.mem.indexOf(u8, output.items, "warning: artifact event kind effect_suspended unknown to supported taxonomy=1") != null);
}
