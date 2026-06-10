const std = @import("std");
const causal_artifact = @import("causal_artifact");

pub const schema_governance_schema = "zigeffect.causal.schema-governance.v1";
pub const current_core_schema = causal_artifact.supported_causal_schema;
pub const current_core_schema_version: u32 = causal_artifact.supported_causal_schema_version;
pub const current_event_taxonomy_version: u32 = causal_artifact.supported_event_taxonomy_version;

const OutputFormat = enum { text, json };

const SchemaEntry = struct {
    schema: []const u8,
    version: u32,
    category: []const u8,
    status: []const u8,
    emitted_by: []const []const u8,
    consumed_by: []const []const u8,
    compatibility: []const []const u8,
    governance_requirements: []const []const u8,
};

const schema_entries: []const SchemaEntry = &.{
    .{
        .schema = "zigeffect.causal.v1",
        .version = 1,
        .category = "core-runtime",
        .status = "current",
        .emitted_by = &.{"formatCausalJson"},
        .consumed_by = &.{ "causal-query", "causal-compare", "causal-loop", "causal-advice", "causal-workbench" },
        .compatibility = &.{ "legacy-tolerant", "warn-forward" },
        .governance_requirements = &.{ "compatibility tests", "taxonomy warning tests", "docs" },
    },
    .{
        .schema = "zigeffect.causal.event.v1",
        .version = 1,
        .category = "backend-export",
        .status = "current",
        .emitted_by = &.{"CausalJsonlBackend"},
        .consumed_by = &.{ "jsonl readers", "agents", "external log processors" },
        .compatibility = &.{"sink-contract"},
        .governance_requirements = &.{ "backend conformance tests", "adapter docs", "redaction tests" },
    },
    .{
        .schema = "zigeffect.causal.otel_record.v1",
        .version = 1,
        .category = "backend-export",
        .status = "current",
        .emitted_by = &.{"CausalOtelBackend"},
        .consumed_by = &.{ "OpenTelemetry exporters", "agents" },
        .compatibility = &.{"sink-contract"},
        .governance_requirements = &.{ "backend conformance tests", "adapter docs", "redaction tests" },
    },
    .{
        .schema = "zigeffect.causal.nendb_node.v1",
        .version = 1,
        .category = "backend-export",
        .status = "current",
        .emitted_by = &.{"CausalNenDbStorageBackend"},
        .consumed_by = &.{ "NenDB adapter", "graph history queries", "agents" },
        .compatibility = &.{"sink-contract"},
        .governance_requirements = &.{ "NenDB adapter tests", "bounded history tests", "docs" },
    },
    .{
        .schema = "zigeffect.causal.nendb_edge.v1",
        .version = 1,
        .category = "backend-export",
        .status = "current",
        .emitted_by = &.{"CausalNenDbStorageBackend"},
        .consumed_by = &.{ "NenDB adapter", "graph history queries", "agents" },
        .compatibility = &.{"sink-contract"},
        .governance_requirements = &.{ "NenDB adapter tests", "causal edge tests", "docs" },
    },
    .{
        .schema = "zigeffect.causal.nendb-retention-report.v1",
        .version = 1,
        .category = "backend-export",
        .status = "current",
        .emitted_by = &.{"CausalNenDbStorageBackend.retentionReport"},
        .consumed_by = &.{ "causal-durable-production-retention", "NenDB adapter tests", "agents" },
        .compatibility = &.{"record-only"},
        .governance_requirements = &.{ "NenDB retention tests", "durable retention docs", "schema governance entry" },
    },
    .{
        .schema = "zigeffect.causal.app-runtime.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"CausalAppRuntime"},
        .consumed_by = &.{ "app remediation tools", "causal-workbench", "agents" },
        .compatibility = &.{ "warn-forward", "record-only" },
        .governance_requirements = &.{ "app runtime tests", "redaction tests", "workbench mapping", "docs" },
    },
    .{
        .schema = "zigeffect.causal.dev-loop-verdict.v1",
        .version = 1,
        .category = "dev-loop",
        .status = "current",
        .emitted_by = &.{ "causal-loop", "causal-verdict" },
        .consumed_by = &.{ "causal-dev-agent", "causal-diagnosis", "agents" },
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "verdict tests", "agent handoff docs", "artifact manifest entry" },
    },
    .{
        .schema = "zigeffect.causal.dev-session.v1",
        .version = 1,
        .category = "dev-loop",
        .status = "current",
        .emitted_by = &.{"causal-dev-session"},
        .consumed_by = &.{ "agents", "causal-workbench" },
        .compatibility = &.{"record-only"},
        .governance_requirements = &.{ "session tests", "bounded memory tests", "artifact manifest entry" },
    },
    .{
        .schema = "zigeffect.causal.ci-verdict.v1",
        .version = 1,
        .category = "dev-loop",
        .status = "current",
        .emitted_by = &.{ "causal-verdict", "causal-handoff" },
        .consumed_by = &.{ "CI agents", "causal-dev-agent" },
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "CI verdict tests", "artifact manifest entry", "docs" },
    },
    .{
        .schema = "zigeffect.causal.workbench-session.v1",
        .version = 1,
        .category = "workbench",
        .status = "current",
        .emitted_by = &.{"causal-workbench"},
        .consumed_by = &.{ "SolidJS workbench", "zig-webui bridge" },
        .compatibility = &.{"viewer-session"},
        .governance_requirements = &.{ "launcher tests", "read-only bridge tests", "UI build verification" },
    },
    .{
        .schema = "zigeffect.causal.performance-budget.v1",
        .version = 1,
        .category = "operating-model",
        .status = "current",
        .emitted_by = &.{"causal-performance-budget"},
        .consumed_by = &.{ "agents", "reviewers", "CI docs" },
        .compatibility = &.{"record-only"},
        .governance_requirements = &.{ "budget report tests", "operations docs", "release guidance" },
    },
    .{
        .schema = "zigeffect.causal.m9-completion-audit.v1",
        .version = 1,
        .category = "operating-model",
        .status = "current",
        .emitted_by = &.{"causal-m9-completion-audit"},
        .consumed_by = &.{ "agents", "reviewers", "roadmap audit" },
        .compatibility = &.{"record-only"},
        .governance_requirements = &.{ "completion audit tests", "operations docs", "roadmap update" },
    },
    .{
        .schema = "zigeffect.causal.production-hardening-backlog.v1",
        .version = 1,
        .category = "operating-model",
        .status = "current",
        .emitted_by = &.{"causal-production-hardening-backlog"},
        .consumed_by = &.{ "agents", "reviewers", "future hardening branch workers" },
        .compatibility = &.{"record-only"},
        .governance_requirements = &.{ "backlog report tests", "operations docs", "roadmap update" },
    },
    .{
        .schema = "zigeffect.causal.production-artifact-aggregation.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-artifact-aggregation"},
        .consumed_by = &.{ "durable retention", "access control", "workbench", "integrations", "agents" },
        .compatibility = &.{"record-only"},
        .governance_requirements = &.{ "aggregation contract tests", "operations docs", "roadmap update" },
    },
    .{
        .schema = "zigeffect.causal.durable-production-retention.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-durable-production-retention"},
        .consumed_by = &.{ "deployment runbooks", "artifact access control", "workbench", "agents" },
        .compatibility = &.{"record-only"},
        .governance_requirements = &.{ "durable retention tests", "NenDB retention fixture", "operations docs", "roadmap update" },
    },
    .{
        .schema = "zigeffect.causal.production-deployment-runbooks.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-deployment-runbooks"},
        .consumed_by = &.{ "artifact access control", "alerting integrations", "rollout guardrails", "agents" },
        .compatibility = &.{"record-only"},
        .governance_requirements = &.{ "deployment runbook tests", "operations docs", "roadmap update" },
    },
    .{
        .schema = "zigeffect.causal.artifact-access-control.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-artifact-access-control"},
        .consumed_by = &.{ "SolidJS workbench", "agent query interface", "live dashboard", "integrations", "future production hosts" },
        .compatibility = &.{"record-only"},
        .governance_requirements = &.{ "access-control tests", "negative fixtures", "operations docs", "roadmap update" },
    },
    .{
        .schema = "zigeffect.causal.encryption-at-rest-policy.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-encryption-at-rest-policy"},
        .consumed_by = &.{ "durable retention", "artifact access control", "future encrypted storage adapters", "agents" },
        .compatibility = &.{"record-only"},
        .governance_requirements = &.{ "encryption policy tests", "redaction interaction fixtures", "operations docs", "roadmap update" },
    },
    .{
        .schema = "zigeffect.causal.unified-spine-contract.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-unified-spine-contract"},
        .consumed_by = &.{ "deep runtime internals", "app semantic trace API", "agent query interface", "SolidJS workbench", "NenDB adapter projection" },
        .compatibility = &.{ "record-only", "spine-contract" },
        .governance_requirements = &.{ "contract tests", "projection boundary docs", "roadmap update" },
    },
    .{
        .schema = "zigeffect.causal.agent-query.v1",
        .version = 1,
        .category = "agent-query",
        .status = "current",
        .emitted_by = &.{"causal-query --agent"},
        .consumed_by = &.{ "agents", "causal-dev-agent", "future workbench graph slices" },
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "agent query tests", "bounded response tests", "policy metadata docs" },
    },
    .{
        .schema = "zigeffect.causal.test-matrix.v1",
        .version = 1,
        .category = "test-coverage",
        .status = "current",
        .emitted_by = &.{"causal-test-matrix"},
        .consumed_by = &.{ "agents", "docs" },
        .compatibility = &.{"record-only"},
        .governance_requirements = &.{ "matrix tests", "scenario coverage docs", "artifact manifest entry" },
    },
    .{
        .schema = "zigeffect.causal.remediation-audit.v1",
        .version = 1,
        .category = "governance",
        .status = "current",
        .emitted_by = &.{"causal-remediation-audit"},
        .consumed_by = &.{ "causal-remediation-decision", "causal-patch-proposal", "causal-audit-chain" },
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "schema validation tests", "guardrail tests", "docs" },
    },
    .{
        .schema = "zigeffect.causal.remediation-decision.v1",
        .version = 1,
        .category = "governance",
        .status = "current",
        .emitted_by = &.{"causal-remediation-decision"},
        .consumed_by = &.{ "causal-patch-proposal", "causal-audit-chain" },
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "schema validation tests", "decision gate tests", "docs" },
    },
    .{
        .schema = "zigeffect.causal.patch-proposal.v1",
        .version = 1,
        .category = "governance",
        .status = "current",
        .emitted_by = &.{"causal-patch-proposal"},
        .consumed_by = &.{ "causal-audit-chain", "agents" },
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "proposal guardrail tests", "schema validation tests", "docs" },
    },
    .{
        .schema = "zigeffect.causal.audit-chain.v1",
        .version = 1,
        .category = "governance",
        .status = "current",
        .emitted_by = &.{"causal-audit-chain"},
        .consumed_by = &.{ "causal-scenario-proposal", "causal-policy-decision", "agents" },
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "chain validation tests", "before-after evidence tests", "docs" },
    },
    .{
        .schema = "zigeffect.causal.scenario-proposal.v1",
        .version = 1,
        .category = "registry",
        .status = "current",
        .emitted_by = &.{"causal-scenario-proposal"},
        .consumed_by = &.{ "causal-scenario-registry-patch", "causal-policy-decision", "agents" },
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "scenario proposal tests", "registry guardrail tests", "docs" },
    },
    .{
        .schema = "zigeffect.causal.registry-patch.v1",
        .version = 1,
        .category = "registry",
        .status = "current",
        .emitted_by = &.{"causal-scenario-registry-patch"},
        .consumed_by = &.{ "causal-policy-decision", "causal-registry-application-readiness" },
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "patch validation tests", "policy gate tests", "docs" },
    },
    .{
        .schema = "zigeffect.causal.registry-application-readiness.v1",
        .version = 1,
        .category = "registry",
        .status = "current",
        .emitted_by = &.{"causal-registry-application-readiness"},
        .consumed_by = &.{"causal-registry-apply"},
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "readiness gate tests", "policy citation tests", "docs" },
    },
    .{
        .schema = "zigeffect.causal.registry-application.v1",
        .version = 1,
        .category = "registry",
        .status = "current",
        .emitted_by = &.{"causal-registry-apply"},
        .consumed_by = &.{ "causal-workbench", "agents" },
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "applied-state tests", "before-after verification tests", "docs" },
    },
    .{
        .schema = "zigeffect.causal.policy-decision.v1",
        .version = 1,
        .category = "governance",
        .status = "current",
        .emitted_by = &.{"causal-policy-decision"},
        .consumed_by = &.{ "registry gates", "agents", "causal-workbench" },
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "policy gate tests", "scenario ownership tests", "docs" },
    },
    .{
        .schema = "zigeffect.causal.snapshot-manifest.v1",
        .version = 1,
        .category = "snapshot-replay",
        .status = "current",
        .emitted_by = &.{"causal-snapshot"},
        .consumed_by = &.{ "causal-snapshot compare", "causal-snapshot replay-feasibility", "agents" },
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "snapshot tests", "manifest validation tests", "docs" },
    },
    .{
        .schema = "zigeffect.causal.snapshot-compare.v1",
        .version = 1,
        .category = "snapshot-replay",
        .status = "current",
        .emitted_by = &.{"causal-snapshot"},
        .consumed_by = &.{ "agents", "causal-workbench" },
        .compatibility = &.{"record-only"},
        .governance_requirements = &.{ "compare tests", "before-after query tests", "docs" },
    },
    .{
        .schema = "zigeffect.causal.replay-feasibility.v1",
        .version = 1,
        .category = "snapshot-replay",
        .status = "current",
        .emitted_by = &.{"causal-snapshot"},
        .consumed_by = &.{ "agents", "reviewers" },
        .compatibility = &.{"record-only"},
        .governance_requirements = &.{ "feasibility tests", "non-goal tests", "docs" },
    },
    .{
        .schema = "zigeffect.causal.deterministic-replay.v1",
        .version = 1,
        .category = "snapshot-replay",
        .status = "current",
        .emitted_by = &.{"causal-snapshot"},
        .consumed_by = &.{ "agents", "reviewers" },
        .compatibility = &.{"record-only"},
        .governance_requirements = &.{ "registered scenario replay tests", "determinism tests", "docs" },
    },
    .{
        .schema = "zigeffect.causal.scenario-fork-proposal.v1",
        .version = 1,
        .category = "snapshot-replay",
        .status = "current",
        .emitted_by = &.{"causal-snapshot"},
        .consumed_by = &.{ "reviewers", "agents" },
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "proposal tests", "non-mutating guardrail tests", "docs" },
    },
    .{
        .schema = "zigeffect.causal.app-remediation-audit.v1",
        .version = 1,
        .category = "app-remediation",
        .status = "current",
        .emitted_by = &.{"causal-app-remediation-audit"},
        .consumed_by = &.{"causal-app-policy-decision"},
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "schema validation tests", "app guardrail tests", "docs", "workbench mapping" },
    },
    .{
        .schema = "zigeffect.causal.app-policy-decision.v1",
        .version = 1,
        .category = "app-remediation",
        .status = "current",
        .emitted_by = &.{"causal-app-policy-decision"},
        .consumed_by = &.{ "causal-app-human-review", "causal-app-patch-proposal" },
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "policy gate tests", "human-review gate tests", "docs", "workbench mapping" },
    },
    .{
        .schema = "zigeffect.causal.app-human-review.v1",
        .version = 1,
        .category = "app-remediation",
        .status = "current",
        .emitted_by = &.{"causal-app-human-review"},
        .consumed_by = &.{ "causal-app-patch-proposal", "causal-app-application-readiness" },
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "review evidence tests", "approval gate tests", "docs", "workbench mapping" },
    },
    .{
        .schema = "zigeffect.causal.app-patch-proposal.v1",
        .version = 1,
        .category = "app-remediation",
        .status = "current",
        .emitted_by = &.{"causal-app-patch-proposal"},
        .consumed_by = &.{"causal-app-application-readiness"},
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "proposal tests", "mutation-authority tests", "docs", "workbench mapping" },
    },
    .{
        .schema = "zigeffect.causal.app-application-readiness.v1",
        .version = 1,
        .category = "app-remediation",
        .status = "current",
        .emitted_by = &.{"causal-app-application-readiness"},
        .consumed_by = &.{"causal-app-apply"},
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "readiness tests", "verification command tests", "docs", "workbench mapping" },
    },
    .{
        .schema = "zigeffect.causal.app-application.v1",
        .version = 1,
        .category = "app-remediation",
        .status = "current",
        .emitted_by = &.{"causal-app-apply"},
        .consumed_by = &.{ "causal-workbench", "agents" },
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "schema validation tests", "applied-state tests", "docs", "workbench mapping" },
    },
};

fn usage() []const u8 {
    return
    \\usage:
    \\  zig build causal-schema-governance
    \\  zig build causal-schema-governance -- --format text
    \\  zig build causal-schema-governance -- --format json
    \\
    \\formats:
    \\  --format text|json
    \\
    ;
}

fn schemaEntries() []const SchemaEntry {
    return schema_entries;
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

fn hasSchema(entries: []const SchemaEntry, schema: []const u8) bool {
    for (entries) |entry| {
        if (std.mem.eql(u8, entry.schema, schema)) return true;
    }
    return false;
}

fn expectSchema(entries: []const SchemaEntry, schema: []const u8) !void {
    try std.testing.expect(hasSchema(entries, schema));
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

fn appendStringArray(allocator: std.mem.Allocator, output: *std.ArrayList(u8), values: []const []const u8) !void {
    try output.append(allocator, '[');
    for (values, 0..) |value, index| {
        if (index != 0) try output.appendSlice(allocator, ", ");
        try appendJsonString(allocator, output, value);
    }
    try output.append(allocator, ']');
}

fn appendTextList(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    label: []const u8,
    values: []const []const u8,
) !void {
    try output.print(allocator, "  {s}: ", .{label});
    for (values, 0..) |value, index| {
        if (index != 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, value);
    }
    try output.append(allocator, '\n');
}

fn formatSchemaGovernanceText(allocator: std.mem.Allocator) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal schema governance\n");
    try output.print(allocator, "schema: {s}\n", .{schema_governance_schema});
    try output.appendSlice(allocator, "schema_version: 1\n");
    try output.print(allocator, "core schema: {s} version {d}\n", .{ current_core_schema, current_core_schema_version });
    try output.print(allocator, "event taxonomy version: {d}\n", .{current_event_taxonomy_version});
    try output.print(allocator, "schema count: {d}\n", .{schema_entries.len});

    try output.appendSlice(allocator,
        \\
        \\versioning policy:
        \\- schema names the artifact family
        \\- schema_version tracks the current shape inside that family
        \\- event_taxonomy_version tracks event-kind role semantics
        \\
        \\migration policy:
        \\- legacy core artifacts without schema metadata remain readable
        \\- strict governance artifacts fail closed on unsupported schema/version
        \\- artifact rewrite tooling is deferred until a real v2 exists
        \\
        \\compatibility postures:
        \\- legacy-tolerant: accepts missing metadata and keeps event ids usable
        \\- warn-forward: warns on newer schema/taxonomy while preserving known fields
        \\- strict-v1: requires exact schema family and version 1
        \\- sink-contract: emitted for downstream backend/export systems
        \\- record-only: records review/application state without mutating source
        \\- viewer-session: read-only local workbench/session operating state
        \\- spine-contract: defines shared identity and relationship vocabulary without changing source event emission
        \\
        \\schemas:
        \\
    );

    for (schema_entries) |entry| {
        try output.print(allocator, "- {s}\n", .{entry.schema});
        try output.print(allocator, "  version: {d}\n", .{entry.version});
        try output.print(allocator, "  category: {s}\n", .{entry.category});
        try output.print(allocator, "  status: {s}\n", .{entry.status});
        try appendTextList(allocator, &output, "compatibility", entry.compatibility);
        try appendTextList(allocator, &output, "emitted by", entry.emitted_by);
        try appendTextList(allocator, &output, "consumed by", entry.consumed_by);
        try appendTextList(allocator, &output, "governance requirements", entry.governance_requirements);
    }

    return output.toOwnedSlice(allocator);
}

fn formatSchemaGovernanceJson(allocator: std.mem.Allocator) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "  \"schema\": ");
    try appendJsonString(allocator, &output, schema_governance_schema);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"schema_version\": 1,\n");
    try output.appendSlice(allocator, "  \"current_core_schema\": ");
    try appendJsonString(allocator, &output, current_core_schema);
    try output.appendSlice(allocator, ",\n");
    try output.print(allocator, "  \"current_core_schema_version\": {d},\n", .{current_core_schema_version});
    try output.print(allocator, "  \"current_event_taxonomy_version\": {d},\n", .{current_event_taxonomy_version});
    try output.print(allocator, "  \"schema_count\": {d},\n", .{schema_entries.len});
    try output.appendSlice(allocator,
        \\  "policy": {
        \\    "versioning": "schema names artifact family; schema_version tracks family shape; event_taxonomy_version tracks event-kind role semantics",
        \\    "migration": "legacy core artifacts remain readable; strict governance artifacts fail closed; rewrite tooling is deferred until a real v2 exists",
        \\    "new_schema_requirements": ["schema name", "schema_version", "producer", "consumer", "compatibility posture", "tests", "docs"]
        \\  },
        \\  "schemas": [
        \\
    );

    for (schema_entries, 0..) |entry, index| {
        try output.appendSlice(allocator, "    {\n");
        try output.appendSlice(allocator, "      \"schema\": ");
        try appendJsonString(allocator, &output, entry.schema);
        try output.appendSlice(allocator, ",\n");
        try output.print(allocator, "      \"version\": {d},\n", .{entry.version});
        try output.appendSlice(allocator, "      \"category\": ");
        try appendJsonString(allocator, &output, entry.category);
        try output.appendSlice(allocator, ",\n");
        try output.appendSlice(allocator, "      \"status\": ");
        try appendJsonString(allocator, &output, entry.status);
        try output.appendSlice(allocator, ",\n");
        try output.appendSlice(allocator, "      \"emitted_by\": ");
        try appendStringArray(allocator, &output, entry.emitted_by);
        try output.appendSlice(allocator, ",\n");
        try output.appendSlice(allocator, "      \"consumed_by\": ");
        try appendStringArray(allocator, &output, entry.consumed_by);
        try output.appendSlice(allocator, ",\n");
        try output.appendSlice(allocator, "      \"compatibility\": ");
        try appendStringArray(allocator, &output, entry.compatibility);
        try output.appendSlice(allocator, ",\n");
        try output.appendSlice(allocator, "      \"governance_requirements\": ");
        try appendStringArray(allocator, &output, entry.governance_requirements);
        try output.appendSlice(allocator, "\n    }");
        if (index + 1 < schema_entries.len) try output.append(allocator, ',');
        try output.append(allocator, '\n');
    }

    try output.appendSlice(allocator, "  ]\n}\n");
    return output.toOwnedSlice(allocator);
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-schema-governance error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const format = parseOptions(args) catch |err| failUsage(err);
    const report = switch (format) {
        .text => try formatSchemaGovernanceText(init.gpa),
        .json => try formatSchemaGovernanceJson(init.gpa),
    };
    defer init.gpa.free(report);

    std.debug.print("{s}", .{report});
}

test "schema governance usage names command and formats" {
    try std.testing.expect(std.mem.indexOf(u8, usage(), "causal-schema-governance") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage(), "--format text|json") != null);
    try std.testing.expectEqualStrings("zigeffect.causal.schema-governance.v1", schema_governance_schema);
}

test "schema governance inventory includes official schemas and excludes fake fixtures" {
    const entries = schemaEntries();
    try std.testing.expectEqual(@as(usize, 42), entries.len);
    try expectSchema(entries, "zigeffect.causal.v1");
    try expectSchema(entries, "zigeffect.causal.event.v1");
    try expectSchema(entries, "zigeffect.causal.app-application.v1");
    try expectSchema(entries, "zigeffect.causal.registry-application.v1");
    try expectSchema(entries, "zigeffect.causal.snapshot-manifest.v1");
    try expectSchema(entries, "zigeffect.causal.workbench-session.v1");
    try expectSchema(entries, "zigeffect.causal.performance-budget.v1");
    try expectSchema(entries, "zigeffect.causal.m9-completion-audit.v1");
    try expectSchema(entries, "zigeffect.causal.production-hardening-backlog.v1");
    try expectSchema(entries, "zigeffect.causal.production-artifact-aggregation.v1");
    try expectSchema(entries, "zigeffect.causal.durable-production-retention.v1");
    try expectSchema(entries, "zigeffect.causal.production-deployment-runbooks.v1");
    try expectSchema(entries, "zigeffect.causal.artifact-access-control.v1");
    try expectSchema(entries, "zigeffect.causal.encryption-at-rest-policy.v1");
    try expectSchema(entries, "zigeffect.causal.unified-spine-contract.v1");
    try expectSchema(entries, "zigeffect.causal.agent-query.v1");
    try expectSchema(entries, "zigeffect.causal.nendb-retention-report.v1");
    try std.testing.expect(!hasSchema(entries, "zigeffect.causal.other.v1"));
    try std.testing.expect(!hasSchema(entries, "zigeffect.causal.unknown.v1"));
}

test "schema governance entries have required metadata" {
    for (schemaEntries()) |entry| {
        try std.testing.expect(entry.schema.len > 0);
        try std.testing.expectEqual(@as(u32, 1), entry.version);
        try std.testing.expect(entry.category.len > 0);
        try std.testing.expect(entry.status.len > 0);
        try std.testing.expect(entry.emitted_by.len > 0);
        try std.testing.expect(entry.consumed_by.len > 0);
        try std.testing.expect(entry.compatibility.len > 0);
        try std.testing.expect(entry.governance_requirements.len > 0);
    }
}

test "schema governance text report includes policy and representative schemas" {
    const report = try formatSchemaGovernanceText(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal schema governance") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "schema: zigeffect.causal.schema-governance.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "schema count: 42") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "event taxonomy version: 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "versioning policy:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "migration policy:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-application.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.registry-application.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.snapshot-manifest.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.performance-budget.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.m9-completion-audit.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-hardening-backlog.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-artifact-aggregation.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.durable-production-retention.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-deployment-runbooks.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.artifact-access-control.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.encryption-at-rest-policy.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.unified-spine-contract.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.agent-query.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.nendb-retention-report.v1") != null);
}

test "schema governance json report is machine readable" {
    const report = try formatSchemaGovernanceJson(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.schema-governance.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema_version\": 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"current_core_schema\": \"zigeffect.causal.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"current_event_taxonomy_version\": 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema_count\": 42") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schemas\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"compatibility\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.performance-budget.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.m9-completion-audit.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-hardening-backlog.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-artifact-aggregation.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.durable-production-retention.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-deployment-runbooks.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.artifact-access-control.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.encryption-at-rest-policy.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.unified-spine-contract.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.agent-query.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.nendb-retention-report.v1\"") != null);
}

test "schema governance parses format options" {
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{"zigeffect-causal-schema-governance"}));
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{ "zigeffect-causal-schema-governance", "--format", "text" }));
    try std.testing.expectEqual(OutputFormat.json, try parseOptions(&.{ "zigeffect-causal-schema-governance", "--format", "json" }));
    try std.testing.expectError(error.UnknownFormat, parseOptions(&.{ "zigeffect-causal-schema-governance", "--format", "yaml" }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(&.{ "zigeffect-causal-schema-governance", "--json" }));
}
