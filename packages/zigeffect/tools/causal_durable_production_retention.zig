const std = @import("std");

pub const durable_production_retention_schema = "zigeffect.causal.durable-production-retention.v1";
pub const durable_production_retention_schema_version: u32 = 1;
pub const source_contract_schema = "zigeffect.causal.production-artifact-aggregation.v1";
pub const recommendation = "start-production-deployment-runbooks";
pub const recommended_next_branch = "codex/zigeffect-causal-production-deployment-runbooks";

const OutputFormat = enum { text, json };

const generated_by = "causal-durable-production-retention";

const RetentionPolicy = struct {
    id: []const u8,
    storage_adapter: []const u8,
    ttl_days: u32,
    max_events_per_bundle: usize,
    compaction_trigger_events: usize,
    compact_to_events: usize,
    backup_required: bool,
    recovery_required: bool,
    guidance: []const u8,
};

const RetentionGate = struct {
    id: []const u8,
    required: bool,
    description: []const u8,
    failure_action: []const u8,
};

const RetainedSource = struct {
    id: []const u8,
    source_kind: []const u8,
    artifact_class: []const u8,
    schema: []const u8,
    retention_state: []const u8,
    durable_state: []const u8,
    redaction_state: []const u8,
    recovery_hint: []const u8,
};

const retention_policy = RetentionPolicy{
    .id = "nendb-production-bundle-retention",
    .storage_adapter = "NenDB adapter",
    .ttl_days = 14,
    .max_events_per_bundle = 4096,
    .compaction_trigger_events = 2048,
    .compact_to_events = 1024,
    .backup_required = true,
    .recovery_required = true,
    .guidance = "Retain reviewed aggregation bundles through NenDB-shaped records; TTL remains policy-only until retained bundles carry capture timestamps.",
};

const retention_gates: []const RetentionGate = &.{
    .{
        .id = "aggregation-contract-present",
        .required = true,
        .description = "Every retained bundle uses production artifact aggregation provenance fields.",
        .failure_action = "block durable retention",
    },
    .{
        .id = "redaction-reviewed",
        .required = true,
        .description = "Source artifacts pass redaction review before durable retention.",
        .failure_action = "retain locally only",
    },
    .{
        .id = "ttl-metadata-present",
        .required = true,
        .description = "Future production records must carry capture metadata before age-based TTL is enforced.",
        .failure_action = "mark TTL policy-only and recovery evidence incomplete",
    },
    .{
        .id = "backup-recovery-fixture",
        .required = true,
        .description = "Backup and recovery evidence must prove causal lineage is queryable after restore.",
        .failure_action = "do not mark bundle recoverable",
    },
};

const retained_sources: []const RetainedSource = &.{
    .{
        .id = "ci-head-dogfood",
        .source_kind = "ci-head",
        .artifact_class = "core-runtime",
        .schema = "zigeffect.causal.v1",
        .retention_state = "ci-artifact-retention-14-days",
        .durable_state = "eligible-after-redaction-review",
        .redaction_state = "redaction-required-before-sharing",
        .recovery_hint = "restore event graph then verify cause path for failed event ids",
    },
    .{
        .id = "ci-verdict",
        .source_kind = "ci-handoff",
        .artifact_class = "handoff",
        .schema = "zigeffect.causal.ci-verdict.v1",
        .retention_state = "ci-artifact-retention-14-days",
        .durable_state = "eligible-after-redaction-review",
        .redaction_state = "redaction-required-before-sharing",
        .recovery_hint = "restore verdict before linked source artifacts",
    },
    .{
        .id = "dev-loop-audit-chain",
        .source_kind = "governance-chain",
        .artifact_class = "governance",
        .schema = "zigeffect.causal.audit-chain.v1",
        .retention_state = "local-manual-retention",
        .durable_state = "manual-review-required",
        .redaction_state = "redaction-required-before-sharing",
        .recovery_hint = "verify before-after evidence remains linked",
    },
};

const backup_expectations: []const []const u8 = &.{
    "backup records include bundle id, source count, schema, oldest event id, newest event id, redaction state, and gate result",
    "recovery proves causal lineage queries after restore, not only byte presence",
    "restore remains record-only until a reviewed authority branch grants mutation authority",
};

const non_goals: []const []const u8 = &.{
    "Cockroach adapter work",
    "D1 or R2 adapter work",
    "direct upstream NenDB dependency",
    "live production ingestion",
    "production dashboards",
    "production mutation authority",
    "deployment or rollout automation",
    "RBAC enforcement",
    "encryption implementation",
    "alerting or paging",
    "React workbench support",
};

const verification_commands: []const []const u8 = &.{
    "cd packages/zigeffect",
    "zig build causal-durable-production-retention",
    "zig build causal-durable-production-retention -- --format json",
    "zig build causal-nendb-storage-backend",
    "zig build causal-production-artifact-aggregation",
    "zig build causal-production-hardening-backlog",
    "zig build causal-schema-governance",
    "zig build examples",
    "zig build test",
    "cd ../..",
    "bun run check",
    "bun run zig:test",
    "git diff --check",
};

fn usage() []const u8 {
    return
    \\Usage:
    \\  zig build causal-durable-production-retention
    \\  zig build causal-durable-production-retention -- --format text
    \\  zig build causal-durable-production-retention -- --format json
    \\
    ;
}

fn parseOptions(args: []const []const u8) !OutputFormat {
    if (args.len == 1) return .text;
    if (args.len == 2 and std.mem.eql(u8, args[1], "--format")) return error.MissingFormat;
    if (args.len != 3) return error.UnknownFlag;
    if (!std.mem.eql(u8, args[1], "--format")) return error.UnknownFlag;
    if (std.mem.eql(u8, args[2], "text")) return .text;
    if (std.mem.eql(u8, args[2], "json")) return .json;
    if (args[2].len == 0) return error.MissingFormat;
    return error.UnknownFormat;
}

pub fn formatDurableProductionRetentionText(allocator: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal durable production retention\n");
    try output.print(allocator, "schema: {s}\n", .{durable_production_retention_schema});
    try output.print(allocator, "schema_version: {d}\n", .{durable_production_retention_schema_version});
    try output.appendSlice(allocator, "status: current\n");
    try output.print(allocator, "generated by: {s}\n", .{generated_by});
    try output.print(allocator, "source contract: {s}\n", .{source_contract_schema});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "recommended next branch: {s}\n", .{recommended_next_branch});

    try output.appendSlice(allocator, "\nretention policy:\n");
    try output.print(allocator, "- id: {s}\n", .{retention_policy.id});
    try output.print(allocator, "  storage adapter: {s}\n", .{retention_policy.storage_adapter});
    try output.print(allocator, "  ttl days: {d}\n", .{retention_policy.ttl_days});
    try output.print(allocator, "  max events per bundle: {d}\n", .{retention_policy.max_events_per_bundle});
    try output.print(allocator, "  compaction trigger events: {d}\n", .{retention_policy.compaction_trigger_events});
    try output.print(allocator, "  compact to events: {d}\n", .{retention_policy.compact_to_events});
    try output.print(allocator, "  backup required: {}\n", .{retention_policy.backup_required});
    try output.print(allocator, "  recovery required: {}\n", .{retention_policy.recovery_required});
    try output.print(allocator, "  guidance: {s}\n", .{retention_policy.guidance});

    try output.appendSlice(allocator, "\nretention gates:\n");
    for (retention_gates) |gate| {
        try output.print(allocator, "- {s}\n", .{gate.id});
        try output.print(allocator, "  required: {}\n", .{gate.required});
        try output.print(allocator, "  description: {s}\n", .{gate.description});
        try output.print(allocator, "  failure action: {s}\n", .{gate.failure_action});
    }

    try output.appendSlice(allocator, "\nretained bundle fixture:\n");
    try output.appendSlice(allocator, "- bundle id: durable-retention-bundle:local-ci:zigeffect:sample\n");
    try output.print(allocator, "  source contract: {s}\n", .{source_contract_schema});
    for (retained_sources) |source| {
        try output.print(allocator, "  - source: {s}\n", .{source.id});
        try output.print(allocator, "    source kind: {s}\n", .{source.source_kind});
        try output.print(allocator, "    artifact class: {s}\n", .{source.artifact_class});
        try output.print(allocator, "    schema: {s}\n", .{source.schema});
        try output.print(allocator, "    retention state: {s}\n", .{source.retention_state});
        try output.print(allocator, "    durable state: {s}\n", .{source.durable_state});
        try output.print(allocator, "    redaction state: {s}\n", .{source.redaction_state});
        try output.print(allocator, "    recovery hint: {s}\n", .{source.recovery_hint});
    }

    try output.appendSlice(allocator, "\nbackup and recovery expectations:\n");
    for (backup_expectations) |expectation| {
        try output.print(allocator, "- {s}\n", .{expectation});
    }

    try output.appendSlice(allocator, "\nnon-goals:\n");
    for (non_goals) |goal| {
        try output.print(allocator, "- {s}\n", .{goal});
    }

    try output.appendSlice(allocator, "\nverification commands:\n");
    for (verification_commands) |command| {
        try output.print(allocator, "- {s}\n", .{command});
    }

    return output.toOwnedSlice(allocator);
}

pub fn formatDurableProductionRetentionJson(allocator: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendJsonStringProperty(allocator, &output, "schema", durable_production_retention_schema, true);
    try appendJsonU32Property(allocator, &output, "schema_version", durable_production_retention_schema_version, true);
    try appendJsonStringProperty(allocator, &output, "status", "current", true);
    try appendJsonStringProperty(allocator, &output, "generated_by", generated_by, true);
    try appendJsonStringProperty(allocator, &output, "source_contract_schema", source_contract_schema, true);
    try appendJsonStringProperty(allocator, &output, "recommendation", recommendation, true);
    try appendJsonStringProperty(allocator, &output, "recommended_next_branch", recommended_next_branch, true);

    try output.appendSlice(allocator, "  \"retention_policy\": {\n");
    try appendJsonStringProperty(allocator, &output, "id", retention_policy.id, true);
    try appendJsonStringProperty(allocator, &output, "storage_adapter", retention_policy.storage_adapter, true);
    try appendJsonU32Property(allocator, &output, "ttl_days", retention_policy.ttl_days, true);
    try appendJsonUsizeProperty(allocator, &output, "max_events_per_bundle", retention_policy.max_events_per_bundle, true);
    try appendJsonUsizeProperty(allocator, &output, "compaction_trigger_events", retention_policy.compaction_trigger_events, true);
    try appendJsonUsizeProperty(allocator, &output, "compact_to_events", retention_policy.compact_to_events, true);
    try appendJsonBoolProperty(allocator, &output, "backup_required", retention_policy.backup_required, true);
    try appendJsonBoolProperty(allocator, &output, "recovery_required", retention_policy.recovery_required, true);
    try appendJsonStringProperty(allocator, &output, "guidance", retention_policy.guidance, false);
    try output.appendSlice(allocator, "  },\n");

    try output.appendSlice(allocator, "  \"retention_gates\": [\n");
    for (retention_gates, 0..) |gate, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", gate.id, true);
        try appendJsonBoolProperty(allocator, &output, "required", gate.required, true);
        try appendJsonStringProperty(allocator, &output, "description", gate.description, true);
        try appendJsonStringProperty(allocator, &output, "failure_action", gate.failure_action, false);
        try output.appendSlice(allocator, if (index + 1 == retention_gates.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"retained_bundle_fixture\": {\n");
    try appendJsonStringProperty(allocator, &output, "bundle_id", "durable-retention-bundle:local-ci:zigeffect:sample", true);
    try appendJsonStringProperty(allocator, &output, "source_contract_schema", source_contract_schema, true);
    try output.appendSlice(allocator, "  \"sources\": [\n");
    for (retained_sources, 0..) |source, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", source.id, true);
        try appendJsonStringProperty(allocator, &output, "source_kind", source.source_kind, true);
        try appendJsonStringProperty(allocator, &output, "artifact_class", source.artifact_class, true);
        try appendJsonStringProperty(allocator, &output, "schema", source.schema, true);
        try appendJsonStringProperty(allocator, &output, "retention_state", source.retention_state, true);
        try appendJsonStringProperty(allocator, &output, "durable_state", source.durable_state, true);
        try appendJsonStringProperty(allocator, &output, "redaction_state", source.redaction_state, true);
        try appendJsonStringProperty(allocator, &output, "recovery_hint", source.recovery_hint, false);
        try output.appendSlice(allocator, if (index + 1 == retained_sources.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ]\n");
    try output.appendSlice(allocator, "  },\n");

    try appendJsonStringArrayProperty(allocator, &output, "backup_and_recovery_expectations", backup_expectations, true);
    try appendJsonStringArrayProperty(allocator, &output, "non_goals", non_goals, true);
    try appendJsonStringArrayProperty(allocator, &output, "verification_commands", verification_commands, false);
    try output.appendSlice(allocator, "}\n");

    return output.toOwnedSlice(allocator);
}

fn appendJsonStringProperty(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    value: []const u8,
    trailing: bool,
) std.mem.Allocator.Error!void {
    try output.appendSlice(allocator, "  \"");
    try output.appendSlice(allocator, name);
    try output.appendSlice(allocator, "\": ");
    try appendJsonString(allocator, output, value);
    try output.appendSlice(allocator, if (trailing) ",\n" else "\n");
}

fn appendJsonBoolProperty(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    value: bool,
    trailing: bool,
) std.mem.Allocator.Error!void {
    try output.appendSlice(allocator, "  \"");
    try output.appendSlice(allocator, name);
    try output.appendSlice(allocator, "\": ");
    try output.appendSlice(allocator, if (value) "true" else "false");
    try output.appendSlice(allocator, if (trailing) ",\n" else "\n");
}

fn appendJsonU32Property(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    value: u32,
    trailing: bool,
) std.mem.Allocator.Error!void {
    try output.print(allocator, "  \"{s}\": {d}", .{ name, value });
    try output.appendSlice(allocator, if (trailing) ",\n" else "\n");
}

fn appendJsonUsizeProperty(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    value: usize,
    trailing: bool,
) std.mem.Allocator.Error!void {
    try output.print(allocator, "  \"{s}\": {d}", .{ name, value });
    try output.appendSlice(allocator, if (trailing) ",\n" else "\n");
}

fn appendJsonStringArrayProperty(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    values: []const []const u8,
    trailing: bool,
) std.mem.Allocator.Error!void {
    try output.print(allocator, "  \"{s}\": [", .{name});
    for (values, 0..) |value, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try appendJsonString(allocator, output, value);
    }
    try output.appendSlice(allocator, if (trailing) "],\n" else "]\n");
}

fn appendJsonString(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
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
            else => try output.append(allocator, byte),
        }
    }
    try output.append(allocator, '"');
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-durable-production-retention error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(1);
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const format = parseOptions(args) catch |err| failUsage(err);
    const report = switch (format) {
        .text => try formatDurableProductionRetentionText(init.gpa),
        .json => try formatDurableProductionRetentionJson(init.gpa),
    };
    defer init.gpa.free(report);

    std.debug.print("{s}", .{report});
}

fn expectGate(id: []const u8) !void {
    for (retention_gates) |gate| {
        if (std.mem.eql(u8, gate.id, id)) return;
    }
    return error.MissingGate;
}

fn expectSource(id: []const u8) !void {
    for (retained_sources) |source| {
        if (std.mem.eql(u8, source.id, id)) return;
    }
    return error.MissingSource;
}

fn expectNonGoal(id: []const u8) !void {
    for (non_goals) |goal| {
        if (std.mem.eql(u8, goal, id)) return;
    }
    return error.MissingNonGoal;
}

test "durable production retention metadata names schema next branch and source contract" {
    try std.testing.expectEqualStrings("zigeffect.causal.durable-production-retention.v1", durable_production_retention_schema);
    try std.testing.expectEqual(@as(u32, 1), durable_production_retention_schema_version);
    try std.testing.expectEqualStrings("zigeffect.causal.production-artifact-aggregation.v1", source_contract_schema);
    try std.testing.expectEqualStrings("start-production-deployment-runbooks", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-deployment-runbooks", recommended_next_branch);
}

test "durable production retention contract preserves constraints and fixture" {
    try std.testing.expectEqualStrings("NenDB adapter", retention_policy.storage_adapter);
    try std.testing.expectEqual(@as(u32, 14), retention_policy.ttl_days);
    try std.testing.expectEqual(@as(usize, 4096), retention_policy.max_events_per_bundle);
    try std.testing.expectEqual(@as(usize, 2048), retention_policy.compaction_trigger_events);
    try std.testing.expectEqual(@as(usize, 1024), retention_policy.compact_to_events);
    try std.testing.expect(retention_policy.backup_required);
    try std.testing.expect(retention_policy.recovery_required);
    try expectGate("aggregation-contract-present");
    try expectGate("redaction-reviewed");
    try expectGate("ttl-metadata-present");
    try expectGate("backup-recovery-fixture");
    try expectSource("ci-head-dogfood");
    try expectSource("ci-verdict");
    try expectSource("dev-loop-audit-chain");
    try expectNonGoal("Cockroach adapter work");
    try expectNonGoal("React workbench support");
    try expectNonGoal("production mutation authority");
}

test "durable production retention text report includes policy and boundaries" {
    const report = try formatDurableProductionRetentionText(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal durable production retention") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "schema: zigeffect.causal.durable-production-retention.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "source contract: zigeffect.causal.production-artifact-aggregation.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "recommended next branch: codex/zigeffect-causal-production-deployment-runbooks") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "storage adapter: NenDB adapter") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "ttl days: 14") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "compaction trigger events: 2048") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "backup-recovery-fixture") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "Cockroach adapter work") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "React workbench support") != null);
}

test "durable production retention json report is machine readable" {
    const report = try formatDurableProductionRetentionJson(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.durable-production-retention.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema_version\": 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"source_contract_schema\": \"zigeffect.causal.production-artifact-aggregation.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"recommendation\": \"start-production-deployment-runbooks\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"recommended_next_branch\": \"codex/zigeffect-causal-production-deployment-runbooks\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"storage_adapter\": \"NenDB adapter\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"ttl_days\": 14") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"max_events_per_bundle\": 4096") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"retained_bundle_fixture\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"non_goals\"") != null);
}

test "durable production retention parses format options" {
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{"zigeffect-causal-durable-production-retention"}));
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{ "zigeffect-causal-durable-production-retention", "--format", "text" }));
    try std.testing.expectEqual(OutputFormat.json, try parseOptions(&.{ "zigeffect-causal-durable-production-retention", "--format", "json" }));
    try std.testing.expectError(error.UnknownFormat, parseOptions(&.{ "zigeffect-causal-durable-production-retention", "--format", "yaml" }));
    try std.testing.expectError(error.MissingFormat, parseOptions(&.{ "zigeffect-causal-durable-production-retention", "--format", "" }));
    try std.testing.expectError(error.MissingFormat, parseOptions(&.{ "zigeffect-causal-durable-production-retention", "--format" }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(&.{ "zigeffect-causal-durable-production-retention", "--json" }));
}
