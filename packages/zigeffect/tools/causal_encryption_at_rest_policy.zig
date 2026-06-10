const std = @import("std");

pub const encryption_at_rest_policy_schema = "zigeffect.causal.encryption-at-rest-policy.v1";
pub const encryption_at_rest_policy_schema_version: u32 = 1;
pub const recommendation = "start-alerting-integrations";
pub const recommended_next_branch = "codex/zigeffect-causal-alerting-integrations";

const OutputFormat = enum { text, json };
const generated_by = "causal-encryption-at-rest-policy";

const EncryptionDomain = struct {
    id: []const u8,
    artifact_class: []const u8,
    required_state: []const u8,
    key_owner: []const u8,
    rotation_cadence: []const u8,
    sharing_posture: []const u8,
    retention_dependency: []const u8,
};

const KeyOwner = struct {
    role: []const u8,
    owns: []const u8,
    key_material_access: []const u8,
    approval_scope: []const u8,
};

const RotationPolicy = struct {
    domain: []const u8,
    cadence: []const u8,
    required_evidence: []const u8,
    failure_action: []const u8,
};

const FixtureField = struct {
    name: []const u8,
    required: bool,
    description: []const u8,
};

const RedactionRule = struct {
    id: []const u8,
    order: []const u8,
    required: bool,
    failure_action: []const u8,
};

const NegativeFixture = struct {
    id: []const u8,
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
    "zigeffect.causal.production-artifact-aggregation.v1",
    "zigeffect.causal.durable-production-retention.v1",
    "zigeffect.causal.artifact-access-control.v1",
};

const encryption_domains: []const EncryptionDomain = &.{
    .{
        .id = "local-private-cache",
        .artifact_class = "local causal artifact",
        .required_state = "local-only unshared; encryption optional until durable retention",
        .key_owner = "maintainer",
        .rotation_cadence = "policy-review",
        .sharing_posture = "deny by default",
        .retention_dependency = "none",
    },
    .{
        .id = "ci-retained-bundle",
        .artifact_class = "ci retained bundle",
        .required_state = "encrypted before durable retention after redaction review",
        .key_owner = "maintainer",
        .rotation_cadence = "90 days or policy change",
        .sharing_posture = "project internal redacted evidence",
        .retention_dependency = "zigeffect.causal.production-artifact-aggregation.v1",
    },
    .{
        .id = "production-retained-bundle",
        .artifact_class = "future production retained bundle",
        .required_state = "encrypted before durable NenDB retention",
        .key_owner = "release-owner",
        .rotation_cadence = "90 days scheduled plus incident rotation",
        .sharing_posture = "review-required",
        .retention_dependency = "zigeffect.causal.durable-production-retention.v1",
    },
    .{
        .id = "incident-restricted-bundle",
        .artifact_class = "incident evidence",
        .required_state = "encrypted and incident-owner reviewed before durable sharing",
        .key_owner = "incident-owner",
        .rotation_cadence = "after incident closure or key-risk event",
        .sharing_posture = "incident owner or auditor context required",
        .retention_dependency = "zigeffect.causal.artifact-access-control.v1",
    },
    .{
        .id = "external-summary",
        .artifact_class = "redacted summary",
        .required_state = "summary only; raw encrypted bundle is not shareable",
        .key_owner = "auditor",
        .rotation_cadence = "not applicable to summary-only evidence",
        .sharing_posture = "redacted-only",
        .retention_dependency = "zigeffect.causal.artifact-access-control.v1",
    },
};

const key_owners: []const KeyOwner = &.{
    .{
        .role = "maintainer",
        .owns = "local and CI policy review",
        .key_material_access = "none in this branch",
        .approval_scope = "local and CI retained evidence only",
    },
    .{
        .role = "release-owner",
        .owns = "future production-retained bundle key approval",
        .key_material_access = "none in this branch",
        .approval_scope = "production-retained bundle policy records",
    },
    .{
        .role = "incident-owner",
        .owns = "incident-restricted evidence approval",
        .key_material_access = "none in this branch",
        .approval_scope = "incident-restricted bundle policy records",
    },
    .{
        .role = "auditor",
        .owns = "retained-bundle encryption evidence review",
        .key_material_access = "none in this branch",
        .approval_scope = "read-only retained evidence review",
    },
    .{
        .role = "agent-readonly",
        .owns = "bounded redacted metadata inspection",
        .key_material_access = "denied",
        .approval_scope = "no key ownership",
    },
};

const rotation_reasons: []const []const u8 = &.{
    "scheduled",
    "incident",
    "key-compromise",
    "policy-change",
};

const rotation_policies: []const RotationPolicy = &.{
    .{
        .domain = "local-private-cache",
        .cadence = "policy-review",
        .required_evidence = "maintainer review when local evidence is promoted to retained bundle",
        .failure_action = "keep local and unshared",
    },
    .{
        .domain = "ci-retained-bundle",
        .cadence = "90 days or policy-change",
        .required_evidence = "before and after key_id_ref plus recovery verification command",
        .failure_action = "block durable promotion",
    },
    .{
        .domain = "production-retained-bundle",
        .cadence = "90 days scheduled plus incident rotation",
        .required_evidence = "release-owner approval, before/after evidence, and recovery verification",
        .failure_action = "do not mark production retained evidence encrypted",
    },
    .{
        .domain = "incident-restricted-bundle",
        .cadence = "after incident closure or key-risk event",
        .required_evidence = "incident-owner approval and auditor-readable rotation record",
        .failure_action = "keep incident evidence review-required",
    },
};

const encrypted_artifact_fixture_fields: []const FixtureField = &.{
    .{ .name = "bundle_id", .required = true, .description = "Retained bundle id from aggregation or durable retention." },
    .{ .name = "source_contract_schema", .required = true, .description = "Schema that shaped the source evidence." },
    .{ .name = "encryption_domain", .required = true, .description = "Policy domain for the retained artifact class." },
    .{ .name = "key_owner_role", .required = true, .description = "Governance role that owns approval for the key reference." },
    .{ .name = "key_id_ref", .required = true, .description = "Stable key identifier reference; never key material." },
    .{ .name = "algorithm_family", .required = true, .description = "Algorithm family label for future encrypted storage adapters." },
    .{ .name = "nonce_ref", .required = true, .description = "Nonce or IV reference; not raw cryptographic material." },
    .{ .name = "encrypted_payload_ref", .required = true, .description = "Reference to encrypted bytes in a future storage adapter." },
    .{ .name = "plaintext_hash_ref", .required = true, .description = "Reference to a reviewed plaintext digest, not plaintext." },
    .{ .name = "redaction_state", .required = true, .description = "Redaction review state before encryption." },
    .{ .name = "rotation_state", .required = true, .description = "Current key rotation evidence state." },
    .{ .name = "recovery_verification_command", .required = true, .description = "Command proving queryable recovery after decrypt/restore." },
    .{ .name = "mutation_authority", .required = true, .description = "Always none for this policy branch." },
};

const redaction_rules: []const RedactionRule = &.{
    .{
        .id = "redact-before-encrypt",
        .order = "redaction review precedes encryption-at-rest eligibility",
        .required = true,
        .failure_action = "block encryption satisfied state",
    },
    .{
        .id = "encrypted-bytes-not-proof",
        .order = "ciphertext presence does not prove plaintext safety",
        .required = true,
        .failure_action = "require redaction evidence before sharing",
    },
    .{
        .id = "decrypt-review-fails-closed",
        .order = "decrypt or review paths fail closed on visible secret-shaped content",
        .required = true,
        .failure_action = "deny review and require redaction fix",
    },
    .{
        .id = "access-control-after-encryption",
        .order = "artifact access control still applies after encryption",
        .required = true,
        .failure_action = "deny access request",
    },
};

const negative_fixtures: []const NegativeFixture = &.{
    .{
        .id = "encrypted-before-redaction-blocked",
        .artifact_state = "encrypted=true redaction_state=required-before-sharing",
        .decision = "block",
        .failed_gate = "redact-before-encrypt",
        .reason = "encryption cannot substitute for redaction review",
    },
    .{
        .id = "missing-key-owner-blocked",
        .artifact_state = "key_owner_role=missing",
        .decision = "block",
        .failed_gate = "key-owner-present",
        .reason = "retained encrypted evidence needs an accountable owner role",
    },
    .{
        .id = "stale-rotation-evidence-blocked",
        .artifact_state = "rotation_state=stale",
        .decision = "block",
        .failed_gate = "rotation-current",
        .reason = "stale rotation evidence cannot mark a retained bundle encrypted",
    },
    .{
        .id = "agent-key-access-denied",
        .artifact_state = "actor_role=agent-readonly requested_permission=view-key-material",
        .decision = "deny",
        .failed_gate = "key-material-never-exposed",
        .reason = "agents may inspect redacted metadata only",
    },
    .{
        .id = "external-reviewer-raw-bundle-denied",
        .artifact_state = "actor_role=external-reviewer requested_permission=view-encrypted-bundle",
        .decision = "deny",
        .failed_gate = "external-summary-only",
        .reason = "external reviewers receive redacted summaries, not raw retained bundles",
    },
    .{
        .id = "encryption-approval-is-not-mutation-authority",
        .artifact_state = "approval attempts to mutate source config deployment or registry",
        .decision = "deny",
        .failed_gate = "mutation-authority-none",
        .reason = "encryption policy approval is record-only",
    },
};

const audit_record_fields: []const AuditRecordField = &.{
    .{ .name = "audit_record_id", .required = true, .description = "Stable id for this encryption policy record." },
    .{ .name = "bundle_id", .required = true, .description = "Retained bundle or aggregation id." },
    .{ .name = "encryption_domain", .required = true, .description = "Encryption domain label." },
    .{ .name = "key_owner_role", .required = true, .description = "Role label that owns key approval." },
    .{ .name = "key_id_ref", .required = true, .description = "Key id reference, never key material." },
    .{ .name = "rotation_state", .required = true, .description = "Rotation evidence state." },
    .{ .name = "redaction_state", .required = true, .description = "Redaction review state before encryption." },
    .{ .name = "source_contract_schema", .required = true, .description = "Source schema for retained evidence." },
    .{ .name = "verification_command", .required = true, .description = "Command that produced or verified this record." },
    .{ .name = "mutation_authority", .required = true, .description = "Always none for this policy." },
};

const authority_boundaries: []const []const u8 = &.{
    "role labels are governance labels, not authenticated identities",
    "key ids are references and must never include key material",
    "encryption policy approval does not grant source config app registry deployment rollback or production mutation authority",
    "durable evidence direction remains NenDB adapter only",
};

const non_goals: []const []const u8 = &.{
    "encryption implementation",
    "artifact decryption",
    "key generation",
    "KMS integration",
    "identity provider integration",
    "live RBAC enforcement",
    "Cockroach adapter work",
    "React workbench support",
    "production mutation authority",
};

const verification_commands: []const []const u8 = &.{
    "cd packages/zigeffect",
    "zig build causal-encryption-at-rest-policy",
    "zig build causal-encryption-at-rest-policy -- --format json",
    "zig build causal-schema-governance",
    "zig build causal-production-hardening-backlog",
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
    \\  zig build causal-encryption-at-rest-policy
    \\  zig build causal-encryption-at-rest-policy -- --format text
    \\  zig build causal-encryption-at-rest-policy -- --format json
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

pub fn formatEncryptionAtRestPolicyText(allocator: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal encryption at rest policy\n");
    try output.print(allocator, "schema: {s}\n", .{encryption_at_rest_policy_schema});
    try output.print(allocator, "schema_version: {d}\n", .{encryption_at_rest_policy_schema_version});
    try output.appendSlice(allocator, "status: current\n");
    try output.print(allocator, "generated by: {s}\n", .{generated_by});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "recommended next branch: {s}\n", .{recommended_next_branch});

    try output.appendSlice(allocator, "\nsource contracts:\n");
    for (source_contracts) |contract| {
        try output.print(allocator, "- {s}\n", .{contract});
    }

    try output.appendSlice(allocator, "\nencryption domains:\n");
    for (encryption_domains) |domain| {
        try output.print(allocator, "- {s}\n", .{domain.id});
        try output.print(allocator, "  artifact class: {s}\n", .{domain.artifact_class});
        try output.print(allocator, "  required state: {s}\n", .{domain.required_state});
        try output.print(allocator, "  key owner: {s}\n", .{domain.key_owner});
        try output.print(allocator, "  rotation cadence: {s}\n", .{domain.rotation_cadence});
        try output.print(allocator, "  sharing posture: {s}\n", .{domain.sharing_posture});
        try output.print(allocator, "  retention dependency: {s}\n", .{domain.retention_dependency});
    }

    try output.appendSlice(allocator, "\nkey ownership:\n");
    for (key_owners) |owner| {
        try output.print(allocator, "- {s}\n", .{owner.role});
        try output.print(allocator, "  owns: {s}\n", .{owner.owns});
        try output.print(allocator, "  key material access: {s}\n", .{owner.key_material_access});
        try output.print(allocator, "  approval scope: {s}\n", .{owner.approval_scope});
    }

    try output.appendSlice(allocator, "\nrotation reasons:\n");
    for (rotation_reasons) |reason| {
        try output.print(allocator, "- {s}\n", .{reason});
    }

    try output.appendSlice(allocator, "\nrotation policy:\n");
    for (rotation_policies) |policy| {
        try output.print(allocator, "- {s}\n", .{policy.domain});
        try output.print(allocator, "  cadence: {s}\n", .{policy.cadence});
        try output.print(allocator, "  required evidence: {s}\n", .{policy.required_evidence});
        try output.print(allocator, "  failure action: {s}\n", .{policy.failure_action});
    }

    try output.appendSlice(allocator, "\nencrypted artifact fixture:\n");
    for (encrypted_artifact_fixture_fields) |field| {
        try output.print(allocator, "- {s}\n", .{field.name});
        try output.print(allocator, "  required: {}\n", .{field.required});
        try output.print(allocator, "  description: {s}\n", .{field.description});
    }

    try output.appendSlice(allocator, "\nredaction rules:\n");
    for (redaction_rules) |rule| {
        try output.print(allocator, "- {s}\n", .{rule.id});
        try output.print(allocator, "  order: {s}\n", .{rule.order});
        try output.print(allocator, "  required: {}\n", .{rule.required});
        try output.print(allocator, "  failure action: {s}\n", .{rule.failure_action});
    }

    try output.appendSlice(allocator, "\nnegative fixtures:\n");
    for (negative_fixtures) |fixture| {
        try output.print(allocator, "- {s}\n", .{fixture.id});
        try output.print(allocator, "  artifact state: {s}\n", .{fixture.artifact_state});
        try output.print(allocator, "  decision: {s}\n", .{fixture.decision});
        try output.print(allocator, "  failed gate: {s}\n", .{fixture.failed_gate});
        try output.print(allocator, "  reason: {s}\n", .{fixture.reason});
    }

    try output.appendSlice(allocator, "\naudit record fields:\n");
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

pub fn formatEncryptionAtRestPolicyJson(allocator: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendJsonStringProperty(allocator, &output, "schema", encryption_at_rest_policy_schema, true);
    try appendJsonU32Property(allocator, &output, "schema_version", encryption_at_rest_policy_schema_version, true);
    try appendJsonStringProperty(allocator, &output, "status", "current", true);
    try appendJsonStringProperty(allocator, &output, "generated_by", generated_by, true);
    try appendJsonStringArrayProperty(allocator, &output, "source_contracts", source_contracts, true);
    try appendJsonStringProperty(allocator, &output, "recommendation", recommendation, true);
    try appendJsonStringProperty(allocator, &output, "recommended_next_branch", recommended_next_branch, true);

    try output.appendSlice(allocator, "  \"encryption_domains\": [\n");
    for (encryption_domains, 0..) |domain, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", domain.id, true);
        try appendJsonStringProperty(allocator, &output, "artifact_class", domain.artifact_class, true);
        try appendJsonStringProperty(allocator, &output, "required_state", domain.required_state, true);
        try appendJsonStringProperty(allocator, &output, "key_owner", domain.key_owner, true);
        try appendJsonStringProperty(allocator, &output, "rotation_cadence", domain.rotation_cadence, true);
        try appendJsonStringProperty(allocator, &output, "sharing_posture", domain.sharing_posture, true);
        try appendJsonStringProperty(allocator, &output, "retention_dependency", domain.retention_dependency, false);
        try output.appendSlice(allocator, if (index + 1 == encryption_domains.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"key_ownership\": [\n");
    for (key_owners, 0..) |owner, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "role", owner.role, true);
        try appendJsonStringProperty(allocator, &output, "owns", owner.owns, true);
        try appendJsonStringProperty(allocator, &output, "key_material_access", owner.key_material_access, true);
        try appendJsonStringProperty(allocator, &output, "approval_scope", owner.approval_scope, false);
        try output.appendSlice(allocator, if (index + 1 == key_owners.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try appendJsonStringArrayProperty(allocator, &output, "rotation_reasons", rotation_reasons, true);

    try output.appendSlice(allocator, "  \"rotation_policies\": [\n");
    for (rotation_policies, 0..) |policy, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "domain", policy.domain, true);
        try appendJsonStringProperty(allocator, &output, "cadence", policy.cadence, true);
        try appendJsonStringProperty(allocator, &output, "required_evidence", policy.required_evidence, true);
        try appendJsonStringProperty(allocator, &output, "failure_action", policy.failure_action, false);
        try output.appendSlice(allocator, if (index + 1 == rotation_policies.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"encrypted_artifact_fixture\": [\n");
    for (encrypted_artifact_fixture_fields, 0..) |field, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "name", field.name, true);
        try appendJsonBoolProperty(allocator, &output, "required", field.required, true);
        try appendJsonStringProperty(allocator, &output, "description", field.description, false);
        try output.appendSlice(allocator, if (index + 1 == encrypted_artifact_fixture_fields.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"redaction_rules\": [\n");
    for (redaction_rules, 0..) |rule, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", rule.id, true);
        try appendJsonStringProperty(allocator, &output, "order", rule.order, true);
        try appendJsonBoolProperty(allocator, &output, "required", rule.required, true);
        try appendJsonStringProperty(allocator, &output, "failure_action", rule.failure_action, false);
        try output.appendSlice(allocator, if (index + 1 == redaction_rules.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"negative_fixtures\": [\n");
    for (negative_fixtures, 0..) |fixture, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", fixture.id, true);
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

    try appendJsonStringProperty(allocator, &output, "mutation_authority", "none", true);
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
    std.debug.print("causal-encryption-at-rest-policy error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(1);
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const format = parseOptions(args) catch |err| failUsage(err);
    const report = switch (format) {
        .text => try formatEncryptionAtRestPolicyText(init.gpa),
        .json => try formatEncryptionAtRestPolicyJson(init.gpa),
    };
    defer init.gpa.free(report);

    std.debug.print("{s}", .{report});
}

fn expectSourceContract(schema: []const u8) !void {
    for (source_contracts) |contract| {
        if (std.mem.eql(u8, contract, schema)) return;
    }
    return error.MissingSourceContract;
}

fn expectDomain(id: []const u8) !void {
    for (encryption_domains) |domain| {
        if (std.mem.eql(u8, domain.id, id)) return;
    }
    return error.MissingDomain;
}

fn expectKeyOwner(role: []const u8) !void {
    for (key_owners) |owner| {
        if (std.mem.eql(u8, owner.role, role)) return;
    }
    return error.MissingKeyOwner;
}

fn expectRotationReason(reason: []const u8) !void {
    for (rotation_reasons) |item| {
        if (std.mem.eql(u8, item, reason)) return;
    }
    return error.MissingRotationReason;
}

fn expectFixtureField(name: []const u8) !void {
    for (encrypted_artifact_fixture_fields) |field| {
        if (std.mem.eql(u8, field.name, name)) {
            try std.testing.expect(field.required);
            return;
        }
    }
    return error.MissingFixtureField;
}

fn expectRedactionRule(id: []const u8) !void {
    for (redaction_rules) |rule| {
        if (std.mem.eql(u8, rule.id, id)) {
            try std.testing.expect(rule.required);
            return;
        }
    }
    return error.MissingRedactionRule;
}

fn expectNegativeFixture(id: []const u8) !void {
    for (negative_fixtures) |fixture| {
        if (std.mem.eql(u8, fixture.id, id)) {
            try std.testing.expect(std.mem.eql(u8, fixture.decision, "block") or std.mem.eql(u8, fixture.decision, "deny"));
            return;
        }
    }
    return error.MissingNegativeFixture;
}

fn expectNonGoal(value: []const u8) !void {
    for (non_goals) |goal| {
        if (std.mem.eql(u8, goal, value)) return;
    }
    return error.MissingNonGoal;
}

test "encryption at rest policy metadata names schema source contracts and next branch" {
    try std.testing.expectEqualStrings("zigeffect.causal.encryption-at-rest-policy.v1", encryption_at_rest_policy_schema);
    try std.testing.expectEqual(@as(u32, 1), encryption_at_rest_policy_schema_version);
    try expectSourceContract("zigeffect.causal.production-artifact-aggregation.v1");
    try expectSourceContract("zigeffect.causal.durable-production-retention.v1");
    try expectSourceContract("zigeffect.causal.artifact-access-control.v1");
    try std.testing.expectEqualStrings("start-alerting-integrations", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-alerting-integrations", recommended_next_branch);
}

test "encryption at rest policy preserves domains key owners rotation and negative fixtures" {
    try expectDomain("production-retained-bundle");
    try expectDomain("incident-restricted-bundle");
    try expectDomain("external-summary");
    try expectKeyOwner("release-owner");
    try expectKeyOwner("incident-owner");
    try expectKeyOwner("agent-readonly");
    try expectRotationReason("scheduled");
    try expectRotationReason("incident");
    try expectRotationReason("key-compromise");
    try expectFixtureField("key_id_ref");
    try expectFixtureField("encrypted_payload_ref");
    try expectFixtureField("plaintext_hash_ref");
    try expectRedactionRule("redact-before-encrypt");
    try expectNegativeFixture("encrypted-before-redaction-blocked");
    try expectNegativeFixture("agent-key-access-denied");
    try expectNonGoal("encryption implementation");
    try expectNonGoal("Cockroach adapter work");
    try expectNonGoal("production mutation authority");
}

test "encryption at rest policy text report includes boundaries" {
    const report = try formatEncryptionAtRestPolicyText(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "schema: zigeffect.causal.encryption-at-rest-policy.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "encryption domains:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-retained-bundle") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "redact-before-encrypt") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "encryption implementation") != null);
}

test "encryption at rest policy json report is machine readable" {
    const report = try formatEncryptionAtRestPolicyJson(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.encryption-at-rest-policy.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"source_contracts\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"encryption_domains\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"encrypted_artifact_fixture\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"redaction_rules\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"mutation_authority\"") != null);
}

test "encryption at rest policy json report parses" {
    const ReportEnvelope = struct {
        schema: []const u8,
        schema_version: u32,
        mutation_authority: []const u8,
        recommended_next_branch: []const u8,
    };

    const report = try formatEncryptionAtRestPolicyJson(std.testing.allocator);
    defer std.testing.allocator.free(report);

    var parsed = try std.json.parseFromSlice(ReportEnvelope, std.testing.allocator, report, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    try std.testing.expectEqualStrings(encryption_at_rest_policy_schema, parsed.value.schema);
    try std.testing.expectEqual(encryption_at_rest_policy_schema_version, parsed.value.schema_version);
    try std.testing.expectEqualStrings("none", parsed.value.mutation_authority);
    try std.testing.expectEqualStrings(recommended_next_branch, parsed.value.recommended_next_branch);
}

test "encryption at rest policy parses text json and errors" {
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{"zigeffect-causal-encryption-at-rest-policy"}));
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{ "zigeffect-causal-encryption-at-rest-policy", "--format", "text" }));
    try std.testing.expectEqual(OutputFormat.json, try parseOptions(&.{ "zigeffect-causal-encryption-at-rest-policy", "--format", "json" }));
    try std.testing.expectError(error.UnknownFormat, parseOptions(&.{ "zigeffect-causal-encryption-at-rest-policy", "--format", "yaml" }));
    try std.testing.expectError(error.MissingFormat, parseOptions(&.{ "zigeffect-causal-encryption-at-rest-policy", "--format", "" }));
    try std.testing.expectError(error.MissingFormat, parseOptions(&.{ "zigeffect-causal-encryption-at-rest-policy", "--format" }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(&.{ "zigeffect-causal-encryption-at-rest-policy", "--json" }));
}
