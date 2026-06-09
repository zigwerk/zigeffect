const std = @import("std");

pub const artifact_access_control_schema = "zigeffect.causal.artifact-access-control.v1";
pub const artifact_access_control_schema_version: u32 = 1;
pub const aggregation_contract_schema = "zigeffect.causal.production-artifact-aggregation.v1";
pub const durable_retention_contract_schema = "zigeffect.causal.durable-production-retention.v1";
pub const deployment_runbooks_contract_schema = "zigeffect.causal.production-deployment-runbooks.v1";
pub const recommendation = "start-unified-causal-spine-contract";
pub const recommended_next_branch = "codex/zigeffect-causal-unified-spine-contract";

const OutputFormat = enum { text, json };

const generated_by = "causal-artifact-access-control";

const VisibilityClass = struct {
    id: []const u8,
    description: []const u8,
    default_decision: []const u8,
};

const Role = struct {
    id: []const u8,
    description: []const u8,
};

const Permission = struct {
    id: []const u8,
    description: []const u8,
};

const RolePermission = struct {
    role: []const u8,
    permission: []const u8,
    visibility_class: []const u8,
    decision: []const u8,
    reason: []const u8,
};

const AccessDecision = struct {
    id: []const u8,
    description: []const u8,
};

const NegativeFixture = struct {
    id: []const u8,
    actor_role: []const u8,
    requested_permission: []const u8,
    artifact_state: []const u8,
    decision: []const u8,
    failed_gate: []const u8,
    reason: []const u8,
};

const AuditRecordField = struct {
    name: []const u8,
    required: bool,
    description: []const u8,
};

const source_contracts: []const []const u8 = &.{
    aggregation_contract_schema,
    durable_retention_contract_schema,
    deployment_runbooks_contract_schema,
};

const visibility_classes: []const VisibilityClass = &.{
    .{
        .id = "local-private",
        .description = "Local-only evidence that must not be shared by default.",
        .default_decision = "deny",
    },
    .{
        .id = "ci-internal",
        .description = "CI artifact evidence retained under current CI retention.",
        .default_decision = "redacted-only",
    },
    .{
        .id = "reviewed-shared",
        .description = "Redacted and reviewed evidence safe for project-internal sharing.",
        .default_decision = "allow",
    },
    .{
        .id = "incident-restricted",
        .description = "Incident evidence requiring incident owner or auditor context.",
        .default_decision = "review-required",
    },
    .{
        .id = "production-retained",
        .description = "Durable retained bundle evidence requiring policy review before production sharing.",
        .default_decision = "review-required",
    },
    .{
        .id = "external-summary",
        .description = "Redacted summary only; no source JSON, DOT, or raw event details.",
        .default_decision = "redacted-only",
    },
};

const roles: []const Role = &.{
    .{ .id = "maintainer", .description = "Project maintainer reviewing zigeffect runtime or policy evidence." },
    .{ .id = "release-owner", .description = "Human owner for deploy, rollback, or release verification records." },
    .{ .id = "incident-owner", .description = "Human owner for incident-restricted evidence and follow-up artifacts." },
    .{ .id = "auditor", .description = "Read-only reviewer for retained bundles, gates, and access records." },
    .{ .id = "agent-readonly", .description = "Agent process consuming bounded redacted evidence and next-query hints." },
    .{ .id = "external-reviewer", .description = "Reviewer outside the default project trust boundary." },
};

const permissions: []const Permission = &.{
    .{ .id = "view-metadata", .description = "View schema, ids, producer, source kind, artifact class, and limitation metadata." },
    .{ .id = "view-redacted-artifact", .description = "View redacted text, JSON, DOT, or workbench artifact content." },
    .{ .id = "view-incident-artifact", .description = "View incident-restricted causal evidence after owner or auditor review." },
    .{ .id = "view-retained-bundle", .description = "View retained bundle evidence when retention and redaction gates pass." },
    .{ .id = "share-internal-summary", .description = "Share reviewed project-internal summary without raw artifact expansion." },
    .{ .id = "share-external-summary", .description = "Share external summary with redacted evidence only." },
    .{ .id = "request-review", .description = "Request human review for denied or review-required evidence." },
    .{ .id = "record-access-audit", .description = "Record the access decision, reason, gate, and verification command." },
};

const role_permission_matrix: []const RolePermission = &.{
    .{
        .role = "maintainer",
        .permission = "view-redacted-artifact",
        .visibility_class = "reviewed-shared",
        .decision = "allow",
        .reason = "maintainer may inspect reviewed redacted project evidence",
    },
    .{
        .role = "release-owner",
        .permission = "view-retained-bundle",
        .visibility_class = "production-retained",
        .decision = "review-required",
        .reason = "release owner needs retained bundle review before production sharing",
    },
    .{
        .role = "incident-owner",
        .permission = "view-incident-artifact",
        .visibility_class = "incident-restricted",
        .decision = "allow",
        .reason = "incident owner may inspect incident evidence for triage",
    },
    .{
        .role = "auditor",
        .permission = "view-retained-bundle",
        .visibility_class = "production-retained",
        .decision = "redacted-only",
        .reason = "auditor receives retained evidence through redacted review surfaces",
    },
    .{
        .role = "agent-readonly",
        .permission = "view-metadata",
        .visibility_class = "ci-internal",
        .decision = "allow",
        .reason = "agent may inspect bounded metadata and query hints",
    },
    .{
        .role = "agent-readonly",
        .permission = "view-redacted-artifact",
        .visibility_class = "reviewed-shared",
        .decision = "redacted-only",
        .reason = "agent evidence stays redacted and bounded",
    },
    .{
        .role = "external-reviewer",
        .permission = "share-external-summary",
        .visibility_class = "external-summary",
        .decision = "redacted-only",
        .reason = "external reviewers receive summaries only",
    },
};

const access_decisions: []const AccessDecision = &.{
    .{ .id = "allow", .description = "Role, visibility, and artifact state satisfy policy." },
    .{ .id = "deny", .description = "Request fails closed and must not reveal the requested artifact." },
    .{ .id = "review-required", .description = "Human review must approve before access is allowed." },
    .{ .id = "redacted-only", .description = "Only redacted metadata or summary may be shown." },
};

const negative_fixtures: []const NegativeFixture = &.{
    .{
        .id = "external-reviewer-production-json-denied",
        .actor_role = "external-reviewer",
        .requested_permission = "view-retained-bundle",
        .artifact_state = "production-retained source JSON",
        .decision = "deny",
        .failed_gate = "external-summary-only",
        .reason = "external reviewer may receive redacted summary only",
    },
    .{
        .id = "agent-unreviewed-redaction-denied",
        .actor_role = "agent-readonly",
        .requested_permission = "view-redacted-artifact",
        .artifact_state = "redaction_state=redaction-required-before-sharing",
        .decision = "deny",
        .failed_gate = "redaction-reviewed",
        .reason = "agent views require reviewed redaction state",
    },
    .{
        .id = "release-owner-incident-context-review-required",
        .actor_role = "release-owner",
        .requested_permission = "view-incident-artifact",
        .artifact_state = "incident-restricted without incident-owner context",
        .decision = "review-required",
        .failed_gate = "incident-owner-present",
        .reason = "incident evidence requires incident owner or auditor context",
    },
    .{
        .id = "unsupported-schema-denied",
        .actor_role = "maintainer",
        .requested_permission = "view-redacted-artifact",
        .artifact_state = "schema=unsupported",
        .decision = "deny",
        .failed_gate = "schema-governance-current",
        .reason = "unsupported strict schema fails closed",
    },
    .{
        .id = "raw-secret-shaped-content-denied",
        .actor_role = "maintainer",
        .requested_permission = "view-redacted-artifact",
        .artifact_state = "artifact contains visible secret-shaped value",
        .decision = "deny",
        .failed_gate = "secret-redaction",
        .reason = "visible secret-shaped values must not be shared",
    },
    .{
        .id = "access-approval-is-not-mutation-authority",
        .actor_role = "maintainer",
        .requested_permission = "record-access-audit",
        .artifact_state = "request treats access approval as production mutation authority",
        .decision = "deny",
        .failed_gate = "mutation-authority-none",
        .reason = "access approval never grants source, config, deployment, rollback, app, registry, or production mutation authority",
    },
};

const audit_record_fields: []const AuditRecordField = &.{
    .{ .name = "audit_record_id", .required = true, .description = "Stable id for this access decision record." },
    .{ .name = "artifact_id", .required = true, .description = "Artifact id from the aggregation source or workbench session." },
    .{ .name = "bundle_id", .required = true, .description = "Aggregation or retained bundle id." },
    .{ .name = "actor_role", .required = true, .description = "Policy role label; not an authenticated identity in this branch." },
    .{ .name = "requested_permission", .required = true, .description = "Permission requested for the artifact or bundle." },
    .{ .name = "decision", .required = true, .description = "allow, deny, review-required, or redacted-only." },
    .{ .name = "reason", .required = true, .description = "Human-readable reason for the decision." },
    .{ .name = "source_contract_schema", .required = true, .description = "Source contract that shaped the evidence." },
    .{ .name = "redaction_state", .required = true, .description = "Redaction state from aggregation or access review." },
    .{ .name = "trust_boundary", .required = true, .description = "Trust boundary from the source artifact." },
    .{ .name = "retention_state", .required = true, .description = "Retention state from aggregation or durable retention." },
    .{ .name = "cited_gate", .required = true, .description = "Gate that allowed, denied, or required review." },
    .{ .name = "verification_command", .required = true, .description = "Command that produced or verified the access decision." },
    .{ .name = "mutation_authority", .required = true, .description = "Always none for this contract." },
};

const authority_boundaries: []const []const u8 = &.{
    "access decisions are policy records, not live RBAC enforcement",
    "role labels are not authenticated identities",
    "access approval is not production mutation authority",
    "SolidJS workbench consumption remains read-only until a reviewed UI branch implements it",
    "durable evidence direction remains NenDB adapter only",
};

const non_goals: []const []const u8 = &.{
    "live RBAC enforcement",
    "identity provider integration",
    "artifact encryption implementation",
    "artifact decryption",
    "live production telemetry ingestion",
    "Cockroach adapter work",
    "direct upstream NenDB dependency",
    "deployment or rollback automation",
    "production mutation authority",
    "React workbench support",
};

const verification_commands: []const []const u8 = &.{
    "cd packages/zigeffect",
    "zig build causal-artifact-access-control",
    "zig build causal-artifact-access-control -- --format json",
    "zig build causal-production-deployment-runbooks",
    "zig build causal-durable-production-retention",
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
    \\  zig build causal-artifact-access-control
    \\  zig build causal-artifact-access-control -- --format text
    \\  zig build causal-artifact-access-control -- --format json
    \\
    ;
}

fn parseOptions(args: []const []const u8) !OutputFormat {
    if (args.len == 1) return .text;
    if (args.len == 2 and std.mem.eql(u8, args[1], "--format")) return error.MissingFormat;
    if (args.len != 3) return error.UnknownFlag;
    if (!std.mem.eql(u8, args[1], "--format")) return error.UnknownFlag;
    if (args[2].len == 0) return error.MissingFormat;
    if (std.mem.eql(u8, args[2], "text")) return .text;
    if (std.mem.eql(u8, args[2], "json")) return .json;
    return error.UnknownFormat;
}

pub fn formatArtifactAccessControlText(allocator: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal artifact access control\n");
    try output.print(allocator, "schema: {s}\n", .{artifact_access_control_schema});
    try output.print(allocator, "schema_version: {d}\n", .{artifact_access_control_schema_version});
    try output.appendSlice(allocator, "status: current\n");
    try output.print(allocator, "generated by: {s}\n", .{generated_by});
    try output.print(allocator, "aggregation contract: {s}\n", .{aggregation_contract_schema});
    try output.print(allocator, "durable retention contract: {s}\n", .{durable_retention_contract_schema});
    try output.print(allocator, "deployment runbooks contract: {s}\n", .{deployment_runbooks_contract_schema});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "recommended next branch: {s}\n", .{recommended_next_branch});

    try output.appendSlice(allocator, "\nvisibility classes:\n");
    for (visibility_classes) |item| {
        try output.print(allocator, "- {s}\n", .{item.id});
        try output.print(allocator, "  description: {s}\n", .{item.description});
        try output.print(allocator, "  default decision: {s}\n", .{item.default_decision});
    }

    try output.appendSlice(allocator, "\nroles:\n");
    for (roles) |role| {
        try output.print(allocator, "- {s}: {s}\n", .{ role.id, role.description });
    }

    try output.appendSlice(allocator, "\npermissions:\n");
    for (permissions) |permission| {
        try output.print(allocator, "- {s}: {s}\n", .{ permission.id, permission.description });
    }

    try output.appendSlice(allocator, "\nrole permission matrix:\n");
    for (role_permission_matrix) |entry| {
        try output.print(allocator, "- role: {s}\n", .{entry.role});
        try output.print(allocator, "  permission: {s}\n", .{entry.permission});
        try output.print(allocator, "  visibility class: {s}\n", .{entry.visibility_class});
        try output.print(allocator, "  decision: {s}\n", .{entry.decision});
        try output.print(allocator, "  reason: {s}\n", .{entry.reason});
    }

    try output.appendSlice(allocator, "\naccess decisions:\n");
    for (access_decisions) |decision| {
        try output.print(allocator, "- {s}: {s}\n", .{ decision.id, decision.description });
    }

    try output.appendSlice(allocator, "\nnegative fixtures:\n");
    for (negative_fixtures) |fixture| {
        try output.print(allocator, "- {s}\n", .{fixture.id});
        try output.print(allocator, "  actor role: {s}\n", .{fixture.actor_role});
        try output.print(allocator, "  requested permission: {s}\n", .{fixture.requested_permission});
        try output.print(allocator, "  artifact state: {s}\n", .{fixture.artifact_state});
        try output.print(allocator, "  decision: {s}\n", .{fixture.decision});
        try output.print(allocator, "  failed gate: {s}\n", .{fixture.failed_gate});
        try output.print(allocator, "  reason: {s}\n", .{fixture.reason});
    }

    try output.appendSlice(allocator, "\naudit_record_fields:\n");
    for (audit_record_fields) |field| {
        try output.print(allocator, "- {s}\n", .{field.name});
        try output.print(allocator, "  required: {}\n", .{field.required});
        try output.print(allocator, "  description: {s}\n", .{field.description});
    }

    try output.appendSlice(allocator, "\nauthority boundaries:\n");
    for (authority_boundaries) |boundary| {
        try output.print(allocator, "- {s}\n", .{boundary});
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

pub fn formatArtifactAccessControlJson(allocator: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendJsonStringProperty(allocator, &output, "schema", artifact_access_control_schema, true);
    try appendJsonU32Property(allocator, &output, "schema_version", artifact_access_control_schema_version, true);
    try appendJsonStringProperty(allocator, &output, "status", "current", true);
    try appendJsonStringProperty(allocator, &output, "generated_by", generated_by, true);
    try appendJsonStringArrayProperty(allocator, &output, "source_contracts", source_contracts, true);
    try appendJsonStringProperty(allocator, &output, "recommendation", recommendation, true);
    try appendJsonStringProperty(allocator, &output, "recommended_next_branch", recommended_next_branch, true);

    try output.appendSlice(allocator, "  \"visibility_classes\": [\n");
    for (visibility_classes, 0..) |item, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", item.id, true);
        try appendJsonStringProperty(allocator, &output, "description", item.description, true);
        try appendJsonStringProperty(allocator, &output, "default_decision", item.default_decision, false);
        try output.appendSlice(allocator, if (index + 1 == visibility_classes.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"roles\": [\n");
    for (roles, 0..) |role, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", role.id, true);
        try appendJsonStringProperty(allocator, &output, "description", role.description, false);
        try output.appendSlice(allocator, if (index + 1 == roles.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"permissions\": [\n");
    for (permissions, 0..) |permission, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", permission.id, true);
        try appendJsonStringProperty(allocator, &output, "description", permission.description, false);
        try output.appendSlice(allocator, if (index + 1 == permissions.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"role_permission_matrix\": [\n");
    for (role_permission_matrix, 0..) |entry, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "role", entry.role, true);
        try appendJsonStringProperty(allocator, &output, "permission", entry.permission, true);
        try appendJsonStringProperty(allocator, &output, "visibility_class", entry.visibility_class, true);
        try appendJsonStringProperty(allocator, &output, "decision", entry.decision, true);
        try appendJsonStringProperty(allocator, &output, "reason", entry.reason, false);
        try output.appendSlice(allocator, if (index + 1 == role_permission_matrix.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"access_decisions\": [\n");
    for (access_decisions, 0..) |decision, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", decision.id, true);
        try appendJsonStringProperty(allocator, &output, "description", decision.description, false);
        try output.appendSlice(allocator, if (index + 1 == access_decisions.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"negative_fixtures\": [\n");
    for (negative_fixtures, 0..) |fixture, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", fixture.id, true);
        try appendJsonStringProperty(allocator, &output, "actor_role", fixture.actor_role, true);
        try appendJsonStringProperty(allocator, &output, "requested_permission", fixture.requested_permission, true);
        try appendJsonStringProperty(allocator, &output, "artifact_state", fixture.artifact_state, true);
        try appendJsonStringProperty(allocator, &output, "decision", fixture.decision, true);
        try appendJsonStringProperty(allocator, &output, "failed_gate", fixture.failed_gate, true);
        try appendJsonStringProperty(allocator, &output, "reason", fixture.reason, false);
        try output.appendSlice(allocator, if (index + 1 == negative_fixtures.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"audit_record_fields\": [\n");
    for (audit_record_fields, 0..) |field, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "name", field.name, true);
        try appendJsonBoolProperty(allocator, &output, "required", field.required, true);
        try appendJsonStringProperty(allocator, &output, "description", field.description, false);
        try output.appendSlice(allocator, if (index + 1 == audit_record_fields.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try appendJsonStringArrayProperty(allocator, &output, "authority_boundaries", authority_boundaries, true);
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
    std.debug.print("causal-artifact-access-control error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(1);
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const format = parseOptions(args) catch |err| failUsage(err);
    const report = switch (format) {
        .text => try formatArtifactAccessControlText(init.gpa),
        .json => try formatArtifactAccessControlJson(init.gpa),
    };
    defer init.gpa.free(report);

    std.debug.print("{s}", .{report});
}

fn expectVisibility(id: []const u8) !void {
    for (visibility_classes) |item| {
        if (std.mem.eql(u8, item.id, id)) return;
    }
    return error.MissingVisibility;
}

fn expectRole(id: []const u8) !void {
    for (roles) |role| {
        if (std.mem.eql(u8, role.id, id)) return;
    }
    return error.MissingRole;
}

fn expectPermission(id: []const u8) !void {
    for (permissions) |permission| {
        if (std.mem.eql(u8, permission.id, id)) return;
    }
    return error.MissingPermission;
}

fn expectNegativeFixture(id: []const u8) !void {
    for (negative_fixtures) |fixture| {
        if (std.mem.eql(u8, fixture.id, id)) {
            try std.testing.expect(std.mem.eql(u8, fixture.decision, "deny") or std.mem.eql(u8, fixture.decision, "review-required"));
            return;
        }
    }
    return error.MissingNegativeFixture;
}

fn expectAuditField(name: []const u8) !void {
    for (audit_record_fields) |field| {
        if (std.mem.eql(u8, field.name, name)) {
            try std.testing.expect(field.required);
            return;
        }
    }
    return error.MissingAuditField;
}

fn expectNonGoal(value: []const u8) !void {
    for (non_goals) |goal| {
        if (std.mem.eql(u8, goal, value)) return;
    }
    return error.MissingNonGoal;
}

test "artifact access control metadata names schema source contracts and next branch" {
    try std.testing.expectEqualStrings("zigeffect.causal.artifact-access-control.v1", artifact_access_control_schema);
    try std.testing.expectEqual(@as(u32, 1), artifact_access_control_schema_version);
    try std.testing.expectEqualStrings("zigeffect.causal.production-artifact-aggregation.v1", aggregation_contract_schema);
    try std.testing.expectEqualStrings("zigeffect.causal.durable-production-retention.v1", durable_retention_contract_schema);
    try std.testing.expectEqualStrings("zigeffect.causal.production-deployment-runbooks.v1", deployment_runbooks_contract_schema);
    try std.testing.expectEqualStrings("start-unified-causal-spine-contract", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-unified-spine-contract", recommended_next_branch);
}

test "artifact access control preserves roles permissions decisions and negative fixtures" {
    try expectVisibility("local-private");
    try expectVisibility("production-retained");
    try expectVisibility("external-summary");
    try expectRole("maintainer");
    try expectRole("agent-readonly");
    try expectRole("external-reviewer");
    try expectPermission("view-metadata");
    try expectPermission("view-redacted-artifact");
    try expectPermission("record-access-audit");
    try expectNegativeFixture("external-reviewer-production-json-denied");
    try expectNegativeFixture("agent-unreviewed-redaction-denied");
    try expectNegativeFixture("access-approval-is-not-mutation-authority");
    try expectAuditField("artifact_id");
    try expectAuditField("bundle_id");
    try expectAuditField("actor_role");
    try expectAuditField("requested_permission");
    try expectAuditField("decision");
    try expectAuditField("mutation_authority");
    try expectNonGoal("live RBAC enforcement");
    try expectNonGoal("Cockroach adapter work");
    try expectNonGoal("React workbench support");
    try expectNonGoal("production mutation authority");
}

test "artifact access control text includes roles permissions and negative fixtures" {
    const report = try formatArtifactAccessControlText(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "schema: zigeffect.causal.artifact-access-control.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "visibility classes:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "agent-readonly") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "view-redacted-artifact") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "external-reviewer-production-json-denied") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production mutation authority") != null);
}

test "artifact access control json includes audit record fields" {
    const report = try formatArtifactAccessControlJson(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.artifact-access-control.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"source_contracts\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"audit_record_fields\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "actor_role") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "requested_permission") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "mutation_authority") != null);
}

test "artifact access control parses text json and errors" {
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{"zigeffect-causal-artifact-access-control"}));
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{ "zigeffect-causal-artifact-access-control", "--format", "text" }));
    try std.testing.expectEqual(OutputFormat.json, try parseOptions(&.{ "zigeffect-causal-artifact-access-control", "--format", "json" }));
    try std.testing.expectError(error.UnknownFormat, parseOptions(&.{ "zigeffect-causal-artifact-access-control", "--format", "yaml" }));
    try std.testing.expectError(error.MissingFormat, parseOptions(&.{ "zigeffect-causal-artifact-access-control", "--format", "" }));
    try std.testing.expectError(error.MissingFormat, parseOptions(&.{ "zigeffect-causal-artifact-access-control", "--format" }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(&.{ "zigeffect-causal-artifact-access-control", "--json" }));
}
