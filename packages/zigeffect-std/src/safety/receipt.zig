const std = @import("std");
const Project = @import("../project/root.zig");
const Secrets = @import("../secrets/root.zig");

pub const safety_receipt_schema = "zigeffect.safety-receipt.v1";
pub const safety_receipt_schema_version: u32 = 1;

pub const SafetyVerdict = enum {
    passed,
    failed,
    incomplete,
    unmanaged,
};

pub const GateStatus = enum {
    passed,
    failed,
    unsupported,
    not_run,
    truncated,
};

pub const GateEvidence = struct {
    kind: Project.SafetyGateKind,
    required: bool,
    status: GateStatus,
    command_id: []const u8 = "",
    detail: []const u8 = "",
    artifact_id: []const u8 = "",
    replay_command: []const u8 = "",
};

pub const EvidenceCompleteness = struct {
    dropped_diagnostics: usize = 0,
    dropped_findings: usize = 0,
    dropped_runtime_events: usize = 0,
    stale_source_refs: usize = 0,
    truncated_artifacts: usize = 0,

    pub fn complete(self: EvidenceCompleteness) bool {
        return self.dropped_diagnostics == 0 and
            self.dropped_findings == 0 and
            self.dropped_runtime_events == 0 and
            self.stale_source_refs == 0 and
            self.truncated_artifacts == 0;
    }
};

pub const StaticEvidenceSummary = struct {
    files: usize = 0,
    source_bytes: usize = 0,
    forbidden: usize = 0,
    allowed: usize = 0,
    stale: usize = 0,
    introduced: usize = 0,
    resolved: usize = 0,
};

pub const MemoryEvidence = struct {
    allocations: usize = 0,
    frees: usize = 0,
    live_allocations: usize = 0,
    live_bytes: usize = 0,
    peak_bytes: usize = 0,
    invalid_frees: usize = 0,
    out_of_memory: usize = 0,
};

pub fn memoryEvidenceFromSnapshot(snapshot: anytype) MemoryEvidence {
    return .{
        .allocations = snapshot.allocations,
        .frees = snapshot.frees,
        .live_allocations = snapshot.live_allocations,
        .live_bytes = snapshot.live_bytes,
        .peak_bytes = snapshot.peak_bytes,
        .invalid_frees = snapshot.invalid_frees,
        .out_of_memory = snapshot.out_of_memory,
    };
}

pub const CompilerDiagnosticSeverity = enum {
    @"error",
    warning,
    note,
    info,
};

pub const CompilerDiagnostic = struct {
    severity: CompilerDiagnosticSeverity,
    file: []const u8,
    line: u32,
    column: u32,
    message: []const u8,
};

pub const CompilerDiagnosticSet = struct {
    allocator: std.mem.Allocator,
    items: std.ArrayList(CompilerDiagnostic) = .empty,
    truncated: bool = false,

    pub fn deinit(self: *CompilerDiagnosticSet) void {
        for (self.items.items) |item| {
            self.allocator.free(item.file);
            self.allocator.free(item.message);
        }
        self.items.deinit(self.allocator);
        self.* = undefined;
    }
};

pub const SafetyReceipt = struct {
    schema: []const u8 = safety_receipt_schema,
    schema_version: u32 = safety_receipt_schema_version,
    project: []const u8,
    component: []const u8 = "",
    source_revision: []const u8,
    profile: Project.SafetyProfile,
    zig_version: []const u8,
    target: []const u8,
    optimize: []const u8 = "Debug",
    gates: []const GateEvidence = &.{},
    static: StaticEvidenceSummary = .{},
    memory: MemoryEvidence = .{},
    completeness: EvidenceCompleteness = .{},
    diagnostics: []const CompilerDiagnostic = &.{},
    finding_ids: []const []const u8 = &.{},
    causal_artifact_ids: []const []const u8 = &.{},

    pub fn verdict(self: SafetyReceipt) SafetyVerdict {
        if (self.profile == .unmanaged) return .unmanaged;
        if (self.static.forbidden > 0 or self.static.stale > 0 or
            self.memory.invalid_frees > 0 or self.memory.live_allocations > 0)
        {
            return .failed;
        }
        for (self.gates) |gate| {
            if (gate.status == .failed) return .failed;
        }
        if (!self.completeness.complete() or self.gates.len == 0) return .incomplete;
        for (self.gates) |gate| {
            if (!gate.required) continue;
            if (gate.status != .passed) return .incomplete;
        }
        return .passed;
    }

    pub fn jsonAlloc(self: SafetyReceipt, allocator: std.mem.Allocator) std.mem.Allocator.Error![]u8 {
        var output = std.ArrayList(u8).empty;
        errdefer output.deinit(allocator);

        try output.appendSlice(allocator, "{\"schema\":");
        try appendRedactedJsonString(&output, allocator, self.schema);
        try output.print(allocator, ",\"schema_version\":{d},\"verdict\":", .{self.schema_version});
        try appendJsonString(&output, allocator, @tagName(self.verdict()));
        try output.appendSlice(allocator, ",\"project\":");
        try appendRedactedJsonString(&output, allocator, self.project);
        try output.appendSlice(allocator, ",\"component\":");
        try appendRedactedJsonString(&output, allocator, self.component);
        try output.appendSlice(allocator, ",\"source_revision\":");
        try appendRedactedJsonString(&output, allocator, self.source_revision);
        try output.appendSlice(allocator, ",\"profile\":");
        try appendJsonString(&output, allocator, @tagName(self.profile));
        try output.appendSlice(allocator, ",\"toolchain\":{\"zig_version\":");
        try appendRedactedJsonString(&output, allocator, self.zig_version);
        try output.appendSlice(allocator, ",\"target\":");
        try appendRedactedJsonString(&output, allocator, self.target);
        try output.appendSlice(allocator, ",\"optimize\":");
        try appendRedactedJsonString(&output, allocator, self.optimize);
        try output.appendSlice(allocator, "},\"static\":");
        const static_json = try std.json.Stringify.valueAlloc(allocator, self.static, .{});
        defer allocator.free(static_json);
        try output.appendSlice(allocator, static_json);
        try output.appendSlice(allocator, ",\"memory\":");
        const memory_json = try std.json.Stringify.valueAlloc(allocator, self.memory, .{});
        defer allocator.free(memory_json);
        try output.appendSlice(allocator, memory_json);
        try output.appendSlice(allocator, ",\"completeness\":");
        const completeness_json = try std.json.Stringify.valueAlloc(allocator, self.completeness, .{});
        defer allocator.free(completeness_json);
        try output.appendSlice(allocator, completeness_json);
        try output.appendSlice(allocator, ",\"gates\":[");
        for (self.gates, 0..) |gate, index| {
            if (index > 0) try output.append(allocator, ',');
            try output.appendSlice(allocator, "{\"kind\":");
            try appendJsonString(&output, allocator, @tagName(gate.kind));
            try output.print(allocator, ",\"required\":{s},\"status\":", .{if (gate.required) "true" else "false"});
            try appendJsonString(&output, allocator, @tagName(gate.status));
            try output.appendSlice(allocator, ",\"command_id\":");
            try appendRedactedJsonString(&output, allocator, gate.command_id);
            try output.appendSlice(allocator, ",\"detail\":");
            try appendRedactedJsonString(&output, allocator, gate.detail);
            try output.appendSlice(allocator, ",\"artifact_id\":");
            try appendRedactedJsonString(&output, allocator, gate.artifact_id);
            try output.appendSlice(allocator, ",\"replay_command\":");
            try appendRedactedJsonString(&output, allocator, gate.replay_command);
            try output.append(allocator, '}');
        }
        try output.appendSlice(allocator, "],\"diagnostics\":[");
        for (self.diagnostics, 0..) |diagnostic, index| {
            if (index > 0) try output.append(allocator, ',');
            try output.appendSlice(allocator, "{\"severity\":");
            try appendJsonString(&output, allocator, @tagName(diagnostic.severity));
            try output.appendSlice(allocator, ",\"file\":");
            try appendRedactedJsonString(&output, allocator, diagnostic.file);
            try output.print(allocator, ",\"line\":{d},\"column\":{d},\"message\":", .{ diagnostic.line, diagnostic.column });
            try appendRedactedJsonString(&output, allocator, diagnostic.message);
            try output.append(allocator, '}');
        }
        try output.appendSlice(allocator, "],\"finding_ids\":");
        try appendRedactedStringArray(&output, allocator, self.finding_ids);
        try output.appendSlice(allocator, ",\"causal_artifact_ids\":");
        try appendRedactedStringArray(&output, allocator, self.causal_artifact_ids);
        try output.append(allocator, '}');
        return output.toOwnedSlice(allocator);
    }
};

pub fn parseZigDiagnostics(
    allocator: std.mem.Allocator,
    raw: []const u8,
    max_diagnostics: usize,
) std.mem.Allocator.Error!CompilerDiagnosticSet {
    var output = CompilerDiagnosticSet{ .allocator = allocator };
    errdefer output.deinit();

    var lines = std.mem.splitScalar(u8, raw, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        const parsed = parseDiagnosticLine(line) orelse continue;
        if (output.items.items.len >= max_diagnostics) {
            output.truncated = true;
            continue;
        }
        const safe_file = try Secrets.redactAlloc(allocator, parsed.file);
        errdefer allocator.free(safe_file);
        const safe_message = try Secrets.redactAlloc(allocator, parsed.message);
        errdefer allocator.free(safe_message);
        try output.items.append(allocator, .{
            .severity = parsed.severity,
            .file = safe_file,
            .line = parsed.line,
            .column = parsed.column,
            .message = safe_message,
        });
    }
    return output;
}

const ParsedDiagnostic = struct {
    severity: CompilerDiagnosticSeverity,
    file: []const u8,
    line: u32,
    column: u32,
    message: []const u8,
};

fn parseDiagnosticLine(line: []const u8) ?ParsedDiagnostic {
    const first = std.mem.indexOfScalar(u8, line, ':') orelse return null;
    const second = std.mem.indexOfScalarPos(u8, line, first + 1, ':') orelse return null;
    const third = std.mem.indexOfScalarPos(u8, line, second + 1, ':') orelse return null;
    const fourth = std.mem.indexOfScalarPos(u8, line, third + 1, ':') orelse return null;
    const line_number = std.fmt.parseInt(u32, line[first + 1 .. second], 10) catch return null;
    const column = std.fmt.parseInt(u32, line[second + 1 .. third], 10) catch return null;
    const severity_text = std.mem.trim(u8, line[third + 1 .. fourth], " \t");
    const severity: CompilerDiagnosticSeverity =
        if (std.mem.eql(u8, severity_text, "error")) .@"error" else if (std.mem.eql(u8, severity_text, "warning")) .warning else if (std.mem.eql(u8, severity_text, "note")) .note else .info;
    return .{
        .severity = severity,
        .file = line[0..first],
        .line = line_number,
        .column = column,
        .message = std.mem.trim(u8, line[fourth + 1 ..], " \t\r"),
    };
}

fn appendRedactedStringArray(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    values: []const []const u8,
) std.mem.Allocator.Error!void {
    try output.append(allocator, '[');
    for (values, 0..) |value, index| {
        if (index > 0) try output.append(allocator, ',');
        try appendRedactedJsonString(output, allocator, value);
    }
    try output.append(allocator, ']');
}

fn appendRedactedJsonString(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    value: []const u8,
) std.mem.Allocator.Error!void {
    const safe = try Secrets.redactAlloc(allocator, value);
    defer allocator.free(safe);
    try appendJsonString(output, allocator, safe);
}

fn appendJsonString(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    value: []const u8,
) std.mem.Allocator.Error!void {
    try output.append(allocator, '"');
    for (value) |byte| {
        switch (byte) {
            '"' => try output.appendSlice(allocator, "\\\""),
            '\\' => try output.appendSlice(allocator, "\\\\"),
            '\n' => try output.appendSlice(allocator, "\\n"),
            '\r' => try output.appendSlice(allocator, "\\r"),
            '\t' => try output.appendSlice(allocator, "\\t"),
            0x00...0x08, 0x0b, 0x0c, 0x0e...0x1f => try output.print(allocator, "\\u{x:0>4}", .{byte}),
            else => try output.append(allocator, byte),
        }
    }
    try output.append(allocator, '"');
}

test "SafetyReceipt verdict fails incomplete evidence and passes complete required gates" {
    const gates = [_]GateEvidence{
        .{ .kind = .source_policy, .required = true, .status = .passed },
        .{ .kind = .compile_debug, .required = true, .status = .passed, .command_id = "check-debug" },
        .{ .kind = .thread_sanitizer, .required = false, .status = .unsupported },
    };
    var receipt_value = SafetyReceipt{
        .project = "safe-app",
        .source_revision = "sha256:revision",
        .profile = .agent_safe_v1,
        .zig_version = "0.16.0",
        .target = "aarch64-macos",
        .gates = &gates,
        .static = .{},
        .completeness = .{},
    };
    try std.testing.expectEqual(SafetyVerdict.passed, receipt_value.verdict());

    var required_unsupported = gates;
    required_unsupported[2].required = true;
    receipt_value.gates = &required_unsupported;
    try std.testing.expectEqual(SafetyVerdict.incomplete, receipt_value.verdict());

    var failed = gates;
    failed[1].status = .failed;
    receipt_value.gates = &failed;
    try std.testing.expectEqual(SafetyVerdict.failed, receipt_value.verdict());

    receipt_value.gates = &gates;
    receipt_value.static.forbidden = 1;
    try std.testing.expectEqual(SafetyVerdict.failed, receipt_value.verdict());
    receipt_value.static.forbidden = 0;
    receipt_value.completeness.stale_source_refs = 1;
    try std.testing.expectEqual(SafetyVerdict.incomplete, receipt_value.verdict());
}

test "SafetyReceipt is unmanaged when project opts out" {
    const value = SafetyReceipt{
        .project = "legacy",
        .source_revision = "sha256:legacy",
        .profile = .unmanaged,
        .zig_version = "0.16.0",
        .target = "native",
    };
    try std.testing.expectEqual(SafetyVerdict.unmanaged, value.verdict());
}

test "SafetyReceipt JSON redacts individual sensitive fields and preserves evidence" {
    const gates = [_]GateEvidence{.{
        .kind = .compile_debug,
        .required = true,
        .status = .failed,
        .command_id = "check-debug",
        .detail = "authorization: Bearer sentinel-secret-for-tests",
        .artifact_id = "compiler-output",
        .replay_command = "zigeffect safety replay receipt finding",
    }};
    const value = SafetyReceipt{
        .project = "safe-app",
        .source_revision = "sha256:revision",
        .profile = .agent_safe_v1,
        .zig_version = "0.16.0",
        .target = "native",
        .gates = &gates,
        .static = .{ .forbidden = 1 },
        .causal_artifact_ids = &.{"causal-run"},
    };
    const json = try value.jsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, safety_receipt_schema) != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "sentinel-secret") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "[REDACTED]") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "compiler-output") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"verdict\":\"failed\"") != null);
}

test "Zig compiler diagnostic parser captures spans notes truncation and redacts messages" {
    const raw =
        \\src/main.zig:12:7: error: expected type 'u32', found '[]const u8'
        \\src/main.zig:9:3: note: called from here
        \\src/secret.zig:2:1: error: token=sentinel-secret-for-tests
    ;
    var diagnostics = try parseZigDiagnostics(std.testing.allocator, raw, 2);
    defer diagnostics.deinit();
    try std.testing.expectEqual(@as(usize, 2), diagnostics.items.items.len);
    try std.testing.expect(diagnostics.truncated);
    try std.testing.expectEqual(CompilerDiagnosticSeverity.@"error", diagnostics.items.items[0].severity);
    try std.testing.expectEqualStrings("src/main.zig", diagnostics.items.items[0].file);
    try std.testing.expectEqual(@as(u32, 12), diagnostics.items.items[0].line);
    try std.testing.expectEqual(@as(u32, 7), diagnostics.items.items[0].column);
    try std.testing.expectEqual(CompilerDiagnosticSeverity.note, diagnostics.items.items[1].severity);

    var redacted = try parseZigDiagnostics(std.testing.allocator, raw, 4);
    defer redacted.deinit();
    try std.testing.expectEqualStrings("[REDACTED]", redacted.items.items[2].message);
}

test "Safety receipt builder releases every partial JSON allocation" {
    const Harness = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const gates = [_]GateEvidence{.{ .kind = .source_policy, .required = true, .status = .passed }};
            const value = SafetyReceipt{
                .project = "safe-app",
                .source_revision = "sha256:revision",
                .profile = .agent_safe_v1,
                .zig_version = "0.16.0",
                .target = "native",
                .gates = &gates,
            };
            const json = try value.jsonAlloc(allocator);
            defer allocator.free(json);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Harness.run, .{});
}

test "runtime memory snapshots join receipt evidence without a package dependency" {
    const evidence = memoryEvidenceFromSnapshot(.{
        .allocations = @as(usize, 4),
        .frees = @as(usize, 3),
        .live_allocations = @as(usize, 1),
        .live_bytes = @as(usize, 64),
        .peak_bytes = @as(usize, 128),
        .invalid_frees = @as(usize, 0),
        .out_of_memory = @as(usize, 2),
    });
    try std.testing.expectEqual(@as(usize, 64), evidence.live_bytes);
    try std.testing.expectEqual(@as(usize, 2), evidence.out_of_memory);
}
