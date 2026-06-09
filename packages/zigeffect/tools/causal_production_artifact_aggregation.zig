const std = @import("std");

pub const production_artifact_aggregation_schema = "zigeffect.causal.production-artifact-aggregation.v1";
pub const production_artifact_aggregation_schema_version: u32 = 1;
pub const recommendation = "use-contract-for-durable-retention";
pub const recommended_next_branch = "codex/zigeffect-causal-durable-production-retention";

const OutputFormat = enum { text, json };

const generated_by = "causal-production-artifact-aggregation";

const BundleContract = struct {
    bundle_id_format: []const u8,
    required_provenance_fields: []const []const u8,
    supported_source_kinds: []const []const u8,
    supported_artifact_classes: []const []const u8,
    downstream_consumers: []const []const u8,
};

const ProvenanceField = struct {
    name: []const u8,
    required: bool,
    description: []const u8,
};

const PrivacyGate = struct {
    id: []const u8,
    status: []const u8,
    description: []const u8,
    failure_action: []const u8,
};

const SampleSource = struct {
    id: []const u8,
    path: []const u8,
    schema: []const u8,
    producer: []const u8,
    source_kind: []const u8,
    artifact_class: []const u8,
    capture_context: []const u8,
    trust_boundary: []const u8,
    redaction_state: []const u8,
    retention_state: []const u8,
    query_hint: []const u8,
};

const bundle_contract = BundleContract{
    .bundle_id_format = "production-artifact-bundle:<environment>:<service-or-workflow>:<stable-run-id>",
    .required_provenance_fields = &.{
        "id",
        "path",
        "schema",
        "producer",
        "source_kind",
        "artifact_class",
        "capture_context",
        "trust_boundary",
        "redaction_state",
        "retention_state",
        "query_hint",
    },
    .supported_source_kinds = &.{
        "ci-baseline",
        "ci-head",
        "ci-handoff",
        "local-dev",
        "registered-scenario",
        "governance-chain",
        "app-remediation",
    },
    .supported_artifact_classes = &.{
        "core-runtime",
        "handoff",
        "advice",
        "compare",
        "governance",
        "app-remediation",
        "snapshot",
        "workbench-session",
    },
    .downstream_consumers = &.{
        "durable retention",
        "artifact access control",
        "SolidJS zig-webui workbench",
        "alerting integrations",
        "rollout evidence",
        "wall-clock benchmarks",
        "capacity planning",
    },
};

const provenance_fields: []const ProvenanceField = &.{
    .{
        .name = "id",
        .required = true,
        .description = "Stable source id inside one aggregation bundle.",
    },
    .{
        .name = "path",
        .required = true,
        .description = "Local, CI, or future durable artifact path; this contract does not verify file existence.",
    },
    .{
        .name = "schema",
        .required = true,
        .description = "Artifact schema family such as zigeffect.causal.v1 or zigeffect.causal.audit-chain.v1.",
    },
    .{
        .name = "producer",
        .required = true,
        .description = "Tool, workflow, or adapter that produced the artifact.",
    },
    .{
        .name = "source_kind",
        .required = true,
        .description = "One supported source kind from the bundle contract.",
    },
    .{
        .name = "artifact_class",
        .required = true,
        .description = "One supported artifact class from the bundle contract.",
    },
    .{
        .name = "capture_context",
        .required = true,
        .description = "Context such as local-dev, ci-base, ci-head, or app-runtime.",
    },
    .{
        .name = "trust_boundary",
        .required = true,
        .description = "Boundary label such as local-ci-record-only or future-production-reviewed.",
    },
    .{
        .name = "redaction_state",
        .required = true,
        .description = "Review state for secret-shaped redaction before sharing or durable retention.",
    },
    .{
        .name = "retention_state",
        .required = true,
        .description = "Retention state from local/CI artifacts or future durable retention policy.",
    },
    .{
        .name = "query_hint",
        .required = true,
        .description = "Command or instruction agents can use to inspect the source artifact.",
    },
};

const privacy_gates: []const PrivacyGate = &.{
    .{
        .id = "redaction-review",
        .status = "required",
        .description = "Inspect txt, json, and dot artifacts for credentials, bearer values, cookies, secret query parameters, and obvious PII before sharing or retaining.",
        .failure_action = "mark bundle blocked and do not share or retain beyond local evidence",
    },
    .{
        .id = "truncation-review",
        .status = "required",
        .description = "Check truncation metadata before treating a bundle as complete evidence.",
        .failure_action = "mark evidence incomplete and request source rerun when required",
    },
    .{
        .id = "unsupported-schema-review",
        .status = "required",
        .description = "Reject strict governance artifacts with unsupported schema family or version.",
        .failure_action = "fail closed until schema governance is updated",
    },
    .{
        .id = "sharing-boundary-review",
        .status = "required",
        .description = "Confirm upload globs and artifact paths exclude the rest of .zig-cache and unrelated build outputs.",
        .failure_action = "remove unsafe sources from the bundle",
    },
    .{
        .id = "production-sensitive-source-review",
        .status = "required-before-production",
        .description = "Require human review before sources from production systems enter a retained bundle.",
        .failure_action = "keep source local and record production aggregation as blocked",
    },
};

const sample_sources: []const SampleSource = &.{
    .{
        .id = "ci-baseline-dogfood",
        .path = ".zig-cache/causal-artifacts/zigeffect-causal-ci-baseline-dogfood.json",
        .schema = "zigeffect.causal.v1",
        .producer = "zigeffect-causal-ci baseline capture",
        .source_kind = "ci-baseline",
        .artifact_class = "core-runtime",
        .capture_context = "ci-base",
        .trust_boundary = "local-ci-record-only",
        .redaction_state = "redaction-required-before-sharing",
        .retention_state = "ci-artifact-retention-14-days",
        .query_hint = "zig build causal-query -- --file <path> summary",
    },
    .{
        .id = "ci-head-dogfood",
        .path = ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.json",
        .schema = "zigeffect.causal.v1",
        .producer = "causal-run",
        .source_kind = "ci-head",
        .artifact_class = "core-runtime",
        .capture_context = "ci-head",
        .trust_boundary = "local-ci-record-only",
        .redaction_state = "redaction-required-before-sharing",
        .retention_state = "ci-artifact-retention-14-days",
        .query_hint = "zig build causal-query -- --file <path> summary",
    },
    .{
        .id = "ci-verdict",
        .path = ".zig-cache/causal-artifacts/zigeffect-causal-ci-verdict.json",
        .schema = "zigeffect.causal.ci-verdict.v1",
        .producer = "causal-ci-handoff",
        .source_kind = "ci-handoff",
        .artifact_class = "handoff",
        .capture_context = "ci-failure-handoff",
        .trust_boundary = "local-ci-record-only",
        .redaction_state = "redaction-required-before-sharing",
        .retention_state = "ci-artifact-retention-14-days",
        .query_hint = "read verdict first, then handoff text and source json artifacts",
    },
    .{
        .id = "dev-loop-audit-chain",
        .path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-audit-chain.json",
        .schema = "zigeffect.causal.audit-chain.v1",
        .producer = "causal-audit-chain",
        .source_kind = "governance-chain",
        .artifact_class = "governance",
        .capture_context = "local-dev",
        .trust_boundary = "local-ci-record-only",
        .redaction_state = "redaction-required-before-sharing",
        .retention_state = "local-manual-retention",
        .query_hint = "open in SolidJS zig-webui workbench chain tab",
    },
    .{
        .id = "app-application",
        .path = ".zig-cache/causal-artifacts/zigeffect-causal-app-application.json",
        .schema = "zigeffect.causal.app-application.v1",
        .producer = "causal-app-apply",
        .source_kind = "app-remediation",
        .artifact_class = "app-remediation",
        .capture_context = "app-runtime",
        .trust_boundary = "local-ci-record-only",
        .redaction_state = "redaction-required-before-sharing",
        .retention_state = "local-manual-retention",
        .query_hint = "open in SolidJS zig-webui workbench app remediation view",
    },
};

const non_goals: []const []const u8 = &.{
    "live production ingestion",
    "durable production storage",
    "production dashboards",
    "production mutation authority",
    "RBAC enforcement",
    "encryption implementation",
    "alerting or paging",
    "rollout automation",
    "Cockroach adapter work",
    "React workbench support",
};

const verification_commands: []const []const u8 = &.{
    "cd packages/zigeffect",
    "zig build causal-production-artifact-aggregation",
    "zig build causal-production-artifact-aggregation -- --format json",
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
    \\usage:
    \\  zig build causal-production-artifact-aggregation
    \\  zig build causal-production-artifact-aggregation -- --format text
    \\  zig build causal-production-artifact-aggregation -- --format json
    \\
    \\formats:
    \\  --format text|json
    \\
    ;
}

fn parseOptions(args: []const []const u8) !OutputFormat {
    if (args.len == 1) return .text;
    if (args.len == 3 and std.mem.eql(u8, args[1], "--format")) {
        if (std.mem.eql(u8, args[2], "text")) return .text;
        if (std.mem.eql(u8, args[2], "json")) return .json;
        return error.UnknownFormat;
    }
    if (args.len == 2 and std.mem.eql(u8, args[1], "--format")) return error.MissingFormat;
    return error.UnknownFlag;
}

fn formatProductionArtifactAggregationText(allocator: std.mem.Allocator) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal production artifact aggregation\n");
    try output.print(allocator, "schema: {s}\n", .{production_artifact_aggregation_schema});
    try output.print(allocator, "schema_version: {d}\n", .{production_artifact_aggregation_schema_version});
    try output.appendSlice(allocator, "status: current\n");
    try output.print(allocator, "generated by: {s}\n", .{generated_by});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "recommended next branch: {s}\n\n", .{recommended_next_branch});

    try output.appendSlice(allocator, "bundle contract:\n");
    try output.print(allocator, "- bundle id format: {s}\n", .{bundle_contract.bundle_id_format});
    try output.appendSlice(allocator, "- required provenance fields:");
    for (bundle_contract.required_provenance_fields) |field| try output.print(allocator, " {s}", .{field});
    try output.append(allocator, '\n');
    try output.appendSlice(allocator, "- supported source kinds:");
    for (bundle_contract.supported_source_kinds) |kind| try output.print(allocator, " {s}", .{kind});
    try output.append(allocator, '\n');
    try output.appendSlice(allocator, "- supported artifact classes:");
    for (bundle_contract.supported_artifact_classes) |class| try output.print(allocator, " {s}", .{class});
    try output.append(allocator, '\n');
    try output.appendSlice(allocator, "- downstream consumers:");
    for (bundle_contract.downstream_consumers) |consumer| try output.print(allocator, " {s};", .{consumer});
    try output.append(allocator, '\n');

    try output.appendSlice(allocator, "\nsource provenance fields:\n");
    for (provenance_fields) |field| {
        try output.print(allocator, "- {s} required={any}: {s}\n", .{ field.name, field.required, field.description });
    }

    try output.appendSlice(allocator, "\nprivacy review gates:\n");
    for (privacy_gates) |gate| {
        try output.print(allocator, "- {s}\n", .{gate.id});
        try output.print(allocator, "  status: {s}\n", .{gate.status});
        try output.print(allocator, "  description: {s}\n", .{gate.description});
        try output.print(allocator, "  failure action: {s}\n", .{gate.failure_action});
    }

    try output.appendSlice(allocator, "\nsample bundle:\n");
    for (sample_sources) |source| {
        try output.print(allocator, "- {s}\n", .{source.id});
        try output.print(allocator, "  path: {s}\n", .{source.path});
        try output.print(allocator, "  schema: {s}\n", .{source.schema});
        try output.print(allocator, "  producer: {s}\n", .{source.producer});
        try output.print(allocator, "  source kind: {s}\n", .{source.source_kind});
        try output.print(allocator, "  artifact class: {s}\n", .{source.artifact_class});
        try output.print(allocator, "  capture context: {s}\n", .{source.capture_context});
        try output.print(allocator, "  trust boundary: {s}\n", .{source.trust_boundary});
        try output.print(allocator, "  redaction state: {s}\n", .{source.redaction_state});
        try output.print(allocator, "  retention state: {s}\n", .{source.retention_state});
        try output.print(allocator, "  query hint: {s}\n", .{source.query_hint});
    }

    try output.appendSlice(allocator, "\nnon-goals:\n");
    for (non_goals) |item| {
        try output.print(allocator, "- {s}\n", .{item});
    }

    try output.appendSlice(allocator, "\nverification commands:\n");
    for (verification_commands) |command| {
        try output.print(allocator, "- {s}\n", .{command});
    }

    return output.toOwnedSlice(allocator);
}

fn formatProductionArtifactAggregationJson(allocator: std.mem.Allocator) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "  \"schema\": ");
    try appendJsonString(allocator, &output, production_artifact_aggregation_schema);
    try output.appendSlice(allocator, ",\n");
    try output.print(allocator, "  \"schema_version\": {d},\n", .{production_artifact_aggregation_schema_version});
    try output.appendSlice(allocator, "  \"status\": \"current\",\n");
    try output.appendSlice(allocator, "  \"generated_by\": ");
    try appendJsonString(allocator, &output, generated_by);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"recommendation\": ");
    try appendJsonString(allocator, &output, recommendation);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"recommended_next_branch\": ");
    try appendJsonString(allocator, &output, recommended_next_branch);
    try output.appendSlice(allocator, ",\n");

    try output.appendSlice(allocator, "  \"bundle_contract\": {\n");
    try output.appendSlice(allocator, "    \"bundle_id_format\": ");
    try appendJsonString(allocator, &output, bundle_contract.bundle_id_format);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"required_provenance_fields\": ");
    try appendStringArray(allocator, &output, bundle_contract.required_provenance_fields);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"supported_source_kinds\": ");
    try appendStringArray(allocator, &output, bundle_contract.supported_source_kinds);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"supported_artifact_classes\": ");
    try appendStringArray(allocator, &output, bundle_contract.supported_artifact_classes);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"downstream_consumers\": ");
    try appendStringArray(allocator, &output, bundle_contract.downstream_consumers);
    try output.appendSlice(allocator, "\n  },\n");

    try output.appendSlice(allocator, "  \"source_provenance_fields\": [\n");
    for (provenance_fields, 0..) |field, index| {
        try output.appendSlice(allocator, "    {\n");
        try output.appendSlice(allocator, "      \"name\": ");
        try appendJsonString(allocator, &output, field.name);
        try output.appendSlice(allocator, ",\n");
        try output.print(allocator, "      \"required\": {s},\n", .{if (field.required) "true" else "false"});
        try output.appendSlice(allocator, "      \"description\": ");
        try appendJsonString(allocator, &output, field.description);
        try output.appendSlice(allocator, "\n    }");
        if (index + 1 < provenance_fields.len) try output.append(allocator, ',');
        try output.append(allocator, '\n');
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"privacy_review_gates\": [\n");
    for (privacy_gates, 0..) |gate, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonIndentedProperty(allocator, &output, "id", gate.id, true);
        try appendJsonIndentedProperty(allocator, &output, "status", gate.status, true);
        try appendJsonIndentedProperty(allocator, &output, "description", gate.description, true);
        try appendJsonIndentedProperty(allocator, &output, "failure_action", gate.failure_action, false);
        try output.appendSlice(allocator, "    }");
        if (index + 1 < privacy_gates.len) try output.append(allocator, ',');
        try output.append(allocator, '\n');
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"sample_bundle\": {\n");
    try output.appendSlice(allocator, "    \"bundle_id\": \"production-artifact-bundle:local-ci:zigeffect:sample\",\n");
    try output.appendSlice(allocator, "    \"mode\": \"contract-fixture\",\n");
    try output.appendSlice(allocator, "    \"sources\": [\n");
    for (sample_sources, 0..) |source, index| {
        try output.appendSlice(allocator, "      {\n");
        try appendJsonDeepProperty(allocator, &output, "id", source.id, true);
        try appendJsonDeepProperty(allocator, &output, "path", source.path, true);
        try appendJsonDeepProperty(allocator, &output, "schema", source.schema, true);
        try appendJsonDeepProperty(allocator, &output, "producer", source.producer, true);
        try appendJsonDeepProperty(allocator, &output, "source_kind", source.source_kind, true);
        try appendJsonDeepProperty(allocator, &output, "artifact_class", source.artifact_class, true);
        try appendJsonDeepProperty(allocator, &output, "capture_context", source.capture_context, true);
        try appendJsonDeepProperty(allocator, &output, "trust_boundary", source.trust_boundary, true);
        try appendJsonDeepProperty(allocator, &output, "redaction_state", source.redaction_state, true);
        try appendJsonDeepProperty(allocator, &output, "retention_state", source.retention_state, true);
        try appendJsonDeepProperty(allocator, &output, "query_hint", source.query_hint, false);
        try output.appendSlice(allocator, "      }");
        if (index + 1 < sample_sources.len) try output.append(allocator, ',');
        try output.append(allocator, '\n');
    }
    try output.appendSlice(allocator, "    ]\n  },\n");

    try output.appendSlice(allocator, "  \"non_goals\": ");
    try appendStringArray(allocator, &output, non_goals);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"verification_commands\": ");
    try appendStringArray(allocator, &output, verification_commands);
    try output.appendSlice(allocator, "\n}\n");

    return output.toOwnedSlice(allocator);
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const format = parseOptions(args) catch |err| failUsage(err);
    const report = switch (format) {
        .text => try formatProductionArtifactAggregationText(init.gpa),
        .json => try formatProductionArtifactAggregationJson(init.gpa),
    };
    defer init.gpa.free(report);

    std.debug.print("{s}", .{report});
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-production-artifact-aggregation error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn appendJsonIndentedProperty(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    value: []const u8,
    comma: bool,
) !void {
    try output.appendSlice(allocator, "      ");
    try appendJsonString(allocator, output, name);
    try output.appendSlice(allocator, ": ");
    try appendJsonString(allocator, output, value);
    if (comma) try output.append(allocator, ',');
    try output.append(allocator, '\n');
}

fn appendJsonDeepProperty(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    value: []const u8,
    comma: bool,
) !void {
    try output.appendSlice(allocator, "        ");
    try appendJsonString(allocator, output, name);
    try output.appendSlice(allocator, ": ");
    try appendJsonString(allocator, output, value);
    if (comma) try output.append(allocator, ',');
    try output.append(allocator, '\n');
}

fn appendStringArray(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    values: []const []const u8,
) !void {
    try output.append(allocator, '[');
    for (values, 0..) |value, index| {
        if (index != 0) try output.appendSlice(allocator, ", ");
        try appendJsonString(allocator, output, value);
    }
    try output.append(allocator, ']');
}

fn appendJsonString(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: []const u8) !void {
    try output.append(allocator, '"');
    for (value) |byte| switch (byte) {
        '"' => try output.appendSlice(allocator, "\\\""),
        '\\' => try output.appendSlice(allocator, "\\\\"),
        '\n' => try output.appendSlice(allocator, "\\n"),
        '\r' => try output.appendSlice(allocator, "\\r"),
        '\t' => try output.appendSlice(allocator, "\\t"),
        else => try output.append(allocator, byte),
    };
    try output.append(allocator, '"');
}

fn expectArtifactClass(value: []const u8) !void {
    for (bundle_contract.supported_artifact_classes) |class| {
        if (std.mem.eql(u8, class, value)) return;
    }
    return error.MissingArtifactClass;
}

fn expectSourceKind(value: []const u8) !void {
    for (bundle_contract.supported_source_kinds) |kind| {
        if (std.mem.eql(u8, kind, value)) return;
    }
    return error.MissingSourceKind;
}

fn expectPrivacyGate(value: []const u8) !void {
    for (privacy_gates) |gate| {
        if (std.mem.eql(u8, gate.id, value)) return;
    }
    return error.MissingPrivacyGate;
}

fn expectSampleSource(value: []const u8) !void {
    for (sample_sources) |source| {
        if (std.mem.eql(u8, source.id, value)) return;
    }
    return error.MissingSampleSource;
}

fn expectNonGoal(value: []const u8) !void {
    for (non_goals) |item| {
        if (std.mem.eql(u8, item, value)) return;
    }
    return error.MissingNonGoal;
}

test "production artifact aggregation constants preserve contract boundary" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-artifact-aggregation.v1", production_artifact_aggregation_schema);
    try std.testing.expectEqualStrings("use-contract-for-durable-retention", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-durable-production-retention", recommended_next_branch);
}

test "production artifact aggregation exposes contract sections" {
    try expectArtifactClass("core-runtime");
    try expectArtifactClass("app-remediation");
    try expectSourceKind("ci-baseline");
    try expectSourceKind("governance-chain");
    try expectPrivacyGate("redaction-review");
    try expectSampleSource("ci-baseline-dogfood");
}

test "production artifact aggregation preserves non-goals" {
    try expectNonGoal("live production ingestion");
    try expectNonGoal("durable production storage");
    try expectNonGoal("production mutation authority");
    try expectNonGoal("Cockroach adapter work");
    try expectNonGoal("React workbench support");
}

test "production artifact aggregation text includes bundle provenance and gates" {
    const allocator = std.testing.allocator;
    const report = try formatProductionArtifactAggregationText(allocator);
    defer allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "schema: zigeffect.causal.production-artifact-aggregation.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "bundle contract:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "source provenance fields:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "privacy review gates:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "sample bundle:") != null);
}

test "production artifact aggregation JSON is agent-readable" {
    const allocator = std.testing.allocator;
    const report = try formatProductionArtifactAggregationJson(allocator);
    defer allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-artifact-aggregation.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"bundle_contract\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"source_provenance_fields\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"privacy_review_gates\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"sample_bundle\"") != null);
}

test "production artifact aggregation parses supported formats" {
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{"zigeffect-causal-production-artifact-aggregation"}));
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{ "zigeffect-causal-production-artifact-aggregation", "--format", "text" }));
    try std.testing.expectEqual(OutputFormat.json, try parseOptions(&.{ "zigeffect-causal-production-artifact-aggregation", "--format", "json" }));
    try std.testing.expectError(error.UnknownFormat, parseOptions(&.{ "zigeffect-causal-production-artifact-aggregation", "--format", "yaml" }));
    try std.testing.expectError(error.MissingFormat, parseOptions(&.{ "zigeffect-causal-production-artifact-aggregation", "--format" }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(&.{ "zigeffect-causal-production-artifact-aggregation", "--json" }));
}
