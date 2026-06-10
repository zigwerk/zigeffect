# Production Telemetry CI Artifact Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a record-only production telemetry CI artifact preview contract that consumes ready workbench-preview evidence and emits agent-readable archive candidate policy before any CI harness or gate work.

**Architecture:** Create one deterministic Zig tool, wire it into `build.zig`, and update schema/backlog/docs. The tool parses `zigeffect.causal.production-telemetry-workbench-readonly-preview.v1`, validates ready read-only evidence, emits `zigeffect.causal.production-telemetry-ci-artifact-preview.v1`, and keeps CI upload, workflow mutation, CI gates, telemetry ingestion, durable writes, and NenDB writes disabled.

**Tech Stack:** Zig 0.16 build tools, existing zigeffect artifact-tool patterns, Markdown docs.

---

## Files

- Add: `packages/zigeffect/tools/causal_production_telemetry_ci_artifact_preview.zig`
- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Add: `packages/zigeffect/docs/production-telemetry-ci-artifact-preview.md`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/production-hardening-completion-audit.md`
- Modify: `packages/zigeffect/docs/production-telemetry-workbench-readonly-preview.md`
- Modify: `packages/zigeffect/docs/production-telemetry-nendb-retention-fixtures.md`
- Modify: `packages/zigeffect/docs/production-telemetry-capture-design.md`
- Modify: `packages/zigeffect/docs/production-telemetry-capture-fixtures.md`
- Modify: `packages/zigeffect/docs/production-telemetry-exporter-boundary.md`
- Modify: `packages/zigeffect/docs/load-test-observation-harness.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

Do not modify `.github/workflows/zigeffect-causal.yml` in this branch.

## Task 1: Red Tests For The CI Artifact Preview Tool

**Files:**
- Add: `packages/zigeffect/tools/causal_production_telemetry_ci_artifact_preview.zig`

- [ ] **Step 1: Create the new tool file with failing tests**

Create `packages/zigeffect/tools/causal_production_telemetry_ci_artifact_preview.zig` with tests first. The file may contain only constants, type stubs, and failing references at this point:

```zig
const std = @import("std");

pub const production_telemetry_ci_artifact_preview_schema = "zigeffect.causal.production-telemetry-ci-artifact-preview.v1";
pub const production_telemetry_ci_artifact_preview_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-artifact-preview";
pub const recommendation = "start-production-telemetry-ci-harness-boundary";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-ci-harness-boundary";

const required_verification_commands: []const []const u8 = &.{
    "zig build causal-production-telemetry-workbench-readonly-preview",
    "zig build causal-artifacts",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
};

test "ci artifact preview schema and branch constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-ci-artifact-preview.v1", production_telemetry_ci_artifact_preview_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_ci_artifact_preview_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-artifact-preview", source_branch);
    try std.testing.expectEqualStrings("start-production-telemetry-ci-harness-boundary", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-harness-boundary", next_branch_if_ready);
    try std.testing.expect(containsString(required_verification_commands, "zig build causal-production-telemetry-workbench-readonly-preview"));
    try std.testing.expect(containsString(required_verification_commands, "zig build causal-artifacts"));
    try std.testing.expect(containsString(required_verification_commands, "zig build examples"));
    try std.testing.expect(containsString(required_verification_commands, "zig build test"));
}

test "parses ci artifact preview options with verified commands" {
    var options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-production-telemetry-ci-artifact-preview",
        "--from-workbench",
        ".zig-cache/causal-artifacts/workbench-preview.json",
        "approve",
        "--reason",
        "CI artifact preview reviewed",
        "--by",
        "codex",
        "--policy",
        "manual-production-telemetry-ci-artifact-preview",
        "--verified-command",
        "zig build causal-artifacts",
        "--out-prefix",
        ".zig-cache/causal-artifacts/custom-ci-preview",
    });
    defer options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Decision.approve, options.decision);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/workbench-preview.json", options.workbench_path);
    try std.testing.expectEqualStrings("CI artifact preview reviewed", options.reason);
    try std.testing.expectEqualStrings("codex", options.reviewed_by);
    try std.testing.expectEqualStrings("manual-production-telemetry-ci-artifact-preview", options.policy);
    try std.testing.expectEqual(@as(usize, 1), options.verified_commands.len);
    try std.testing.expectEqualStrings("zig build causal-artifacts", options.verified_commands[0]);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-ci-preview", options.out_prefix.?);
}

test "ready and blocked ci artifact preview reports preserve preview-only authority" {
    const ready = try formatReports(std.testing.allocator, .{
        .options = .{
            .workbench_path = ".zig-cache/causal-artifacts/workbench-preview.json",
            .decision = .approve,
            .reason = "CI artifact preview reviewed",
            .verified_commands = required_verification_commands,
        },
        .source_workbench_json = sample_workbench_preview_json,
    });
    defer ready.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"schema\": \"zigeffect.causal.production-telemetry-ci-artifact-preview.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ci_artifact_preview_status\": \"ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ready_for_next_branch\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ci_artifact_preview_enabled\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ci_upload_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ci_workflow_mutation_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ci_gate_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"allowed_extensions\": [\".txt\", \".json\", \".dot\"]") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"id\": \"source-workbench-preview-json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"id\": \"future-ci-preview-json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"mapping_fixture_ids\": [\"nendb-runtime-event-node-fixture\", \"nendb-correlation-edge-fixture\"]") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"next_branch_if_ready\": \"codex/zigeffect-causal-production-telemetry-ci-harness-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.text, "ci_artifact_preview_status: ready") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.text, "ci upload enabled: false") != null);

    const blocked = try formatReports(std.testing.allocator, .{
        .options = .{
            .workbench_path = ".zig-cache/causal-artifacts/workbench-preview.json",
            .decision = .reject,
            .reason = "negative review path",
        },
        .source_workbench_json = sample_workbench_preview_json,
    });
    defer blocked.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"ci_artifact_preview_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"ready_for_next_branch\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"ci_upload_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.text, "ci_artifact_preview_status: blocked") != null);
}
```

Add this sample JSON at the bottom of the test file:

```zig
const sample_workbench_preview_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-workbench-readonly-preview.v1",
    \\  "schema_version": 1,
    \\  "source_retention": ".zig-cache/causal-artifacts/nendb-retention.json",
    \\  "source_local_pipeline": ".zig-cache/causal-artifacts/local-pipeline.json",
    \\  "source_boundary": ".zig-cache/causal-artifacts/exporter-boundary.json",
    \\  "source_proposal": ".zig-cache/causal-artifacts/implementation-proposal.json",
    \\  "source_readiness": ".zig-cache/causal-artifacts/readiness-review.json",
    \\  "source_fixtures": ".zig-cache/causal-artifacts/capture-fixtures.json",
    \\  "decision": "approve",
    \\  "preview_status": "ready",
    \\  "ready_for_next_branch": true,
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "read_only_preview": true,
    \\  "solid_webui_enabled": true,
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "network_send_enabled": false,
    \\  "collector_endpoint_configured": false,
    \\  "otlp_serialization_enabled": false,
    \\  "runtime_pipeline_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "nendb_write_enabled": false,
    \\  "ci_gate_enabled": false,
    \\  "checks": [
    \\    { "name": "decision-approved", "status": "pass", "detail": "review approved" },
    \\    { "name": "solid-webui-readonly", "status": "pass", "detail": "read-only workbench" }
    \\  ],
    \\  "nendb_mapping_fixtures": [
    \\    { "id": "nendb-runtime-event-node-fixture", "source_envelope": "runtime-span-normalized-envelope", "target_schema": "zigeffect.causal.nendb_node.v1", "label": "causal.telemetry.runtime_span", "retained_fields": ["event_id_ref"], "blocked_fields": ["raw_payload"] },
    \\    { "id": "nendb-correlation-edge-fixture", "source_envelope": "correlation-link-envelope", "target_schema": "zigeffect.causal.nendb_edge.v1", "label": "causal.telemetry.correlates", "retained_fields": ["from_event_ref"], "blocked_fields": ["raw_payload_joins"] }
    \\  ],
    \\  "retention_validation_checks": [
    \\    "nendb-write-disabled",
    \\    "durable-write-disabled",
    \\    "workbench-preview-next-only"
    \\  ],
    \\  "required_verification_commands": [
    \\    "bun run zigeffect:workbench:typecheck",
    \\    "bun run zigeffect:workbench:test"
    \\  ],
    \\  "verified_commands": [
    \\    "bun run zigeffect:workbench:typecheck",
    \\    "bun run zigeffect:workbench:test"
    \\  ],
    \\  "blocked_claims": [
    \\    "runtime-pipeline-enabled",
    \\    "ci-telemetry-gate",
    \\    "nendb-write-enabled"
    \\  ]
    \\}
;
```

- [ ] **Step 2: Verify the tests fail for missing implementation**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_artifact_preview.zig
```

Expected: fail with undeclared identifiers such as `containsString`, `parseOptions`, `Decision`, and `formatReports`.

- [ ] **Step 3: Verify the build step fails before wiring**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-artifact-preview
```

Expected: fail because the build step does not exist.

## Task 2: Implement The Zig CI Artifact Preview Contract

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_artifact_preview.zig`

- [ ] **Step 1: Add option, report, input, and source artifact types**

Implement these types near the top of the file:

```zig
const workbench_schema = "zigeffect.causal.production-telemetry-workbench-readonly-preview.v1";
const generated_by = "causal-production-telemetry-ci-artifact-preview";
const applied = false;
const mutation_authority = "none";
const production_telemetry_ingestion = false;
const live_exporter_enabled = false;
const network_send_enabled = false;
const collector_endpoint_configured = false;
const otlp_serialization_enabled = false;
const runtime_pipeline_enabled = false;
const durable_write_enabled = false;
const nendb_write_enabled = false;
const ci_gate_enabled = false;
const ci_upload_enabled = false;
const ci_workflow_mutation_enabled = false;
const ci_artifact_preview_enabled = true;

const Decision = enum { approve, reject };
const PreviewStatus = enum { ready, blocked };
const CheckStatus = enum { pass, fail };

const Options = struct {
    workbench_path: []const u8,
    decision: Decision,
    reviewed_by: []const u8 = "ci-artifact-preview-reviewer",
    policy: []const u8 = "manual-production-telemetry-ci-artifact-preview",
    reason: []const u8,
    verified_commands: []const []const u8 = &.{},
    out_prefix: ?[]const u8 = null,

    fn deinit(self: Options, allocator: std.mem.Allocator) void {
        if (self.verified_commands.len > 0) allocator.free(self.verified_commands);
    }
};

const OutputPaths = struct {
    json_path: []const u8,
    text_path: []const u8,

    fn deinit(self: OutputPaths, allocator: std.mem.Allocator) void {
        allocator.free(self.json_path);
        allocator.free(self.text_path);
    }
};

const PreviewInput = struct {
    options: Options,
    source_workbench_json: []const u8,
};

const PreviewReports = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: PreviewReports, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
    }
};

const SourceCheck = struct {
    name: []const u8,
    status: []const u8,
    detail: []const u8 = "",
};

const NendbMappingFixture = struct {
    id: []const u8,
    source_envelope: []const u8 = "",
    target_schema: []const u8 = "",
    label: []const u8 = "",
    retained_fields: []const []const u8 = &.{},
    blocked_fields: []const []const u8 = &.{},
};

const WorkbenchPreviewArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_retention: []const u8 = "",
    source_local_pipeline: []const u8 = "",
    source_boundary: []const u8 = "",
    source_proposal: []const u8 = "",
    source_readiness: []const u8 = "",
    source_fixtures: []const u8 = "",
    decision: []const u8,
    preview_status: []const u8,
    ready_for_next_branch: bool,
    applied: bool,
    mutation_authority: []const u8,
    read_only_preview: bool,
    solid_webui_enabled: bool,
    production_telemetry_ingestion: bool,
    live_exporter_enabled: bool,
    network_send_enabled: bool,
    collector_endpoint_configured: bool,
    otlp_serialization_enabled: bool,
    runtime_pipeline_enabled: bool,
    durable_write_enabled: bool,
    nendb_write_enabled: bool,
    ci_gate_enabled: bool,
    checks: []const SourceCheck = &.{},
    nendb_mapping_fixtures: []const NendbMappingFixture = &.{},
    retention_validation_checks: []const []const u8 = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
    blocked_claims: []const []const u8 = &.{},
};
```

- [ ] **Step 2: Add CLI parsing and output path helpers**

Implement `parseOptions`, `parseDecision`, `outputPathsForOptions`, and text helpers:

```zig
fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingWorkbenchPath;
    if (!std.mem.eql(u8, args[1], "--from-workbench")) return error.UnknownFlag;
    if (args.len < 3) return error.MissingWorkbenchPath;
    const workbench_path = args[2];
    if (!std.mem.endsWith(u8, workbench_path, ".json")) return error.InvalidWorkbenchPath;
    if (args.len < 4) return error.MissingDecision;
    const decision = try parseDecision(args[3]);

    var reviewed_by: []const u8 = "ci-artifact-preview-reviewer";
    var policy: []const u8 = "manual-production-telemetry-ci-artifact-preview";
    var reason: ?[]const u8 = null;
    var out_prefix: ?[]const u8 = null;
    var verified_commands = std.ArrayList([]const u8).empty;
    errdefer verified_commands.deinit(allocator);

    var index: usize = 4;
    while (index < args.len) {
        const arg = args[index];
        if (!std.mem.startsWith(u8, arg, "--")) return error.UnknownArgument;
        if (index + 1 >= args.len) return error.MissingFlagValue;
        const value = args[index + 1];

        if (std.mem.eql(u8, arg, "--reason")) {
            reason = value;
        } else if (std.mem.eql(u8, arg, "--by")) {
            reviewed_by = value;
        } else if (std.mem.eql(u8, arg, "--policy")) {
            policy = value;
        } else if (std.mem.eql(u8, arg, "--verified-command")) {
            try verified_commands.append(allocator, value);
        } else if (std.mem.eql(u8, arg, "--out-prefix")) {
            out_prefix = value;
        } else {
            return error.UnknownFlag;
        }
        index += 2;
    }

    const final_reason = reason orelse return error.MissingReason;
    if (final_reason.len == 0) return error.MissingReason;

    return .{
        .workbench_path = workbench_path,
        .decision = decision,
        .reviewed_by = reviewed_by,
        .policy = policy,
        .reason = final_reason,
        .verified_commands = try verified_commands.toOwnedSlice(allocator),
        .out_prefix = out_prefix,
    };
}

fn outputPathsForOptions(allocator: std.mem.Allocator, options: Options) !OutputPaths {
    const prefix = if (options.out_prefix) |out_prefix|
        try allocator.dupe(u8, out_prefix)
    else blk: {
        if (!std.mem.endsWith(u8, options.workbench_path, ".json")) return error.InvalidWorkbenchPath;
        const base = options.workbench_path[0 .. options.workbench_path.len - ".json".len];
        break :blk try std.fmt.allocPrint(allocator, "{s}-ci-artifact-preview", .{base});
    };
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}.txt", .{prefix}),
    };
}
```

- [ ] **Step 3: Add evaluation checks**

Implement `evaluatePreview` with these check names and rules:

```zig
fn evaluatePreview(
    allocator: std.mem.Allocator,
    options: Options,
    workbench: WorkbenchPreviewArtifact,
    paths: OutputPaths,
) !PreviewResult {
    var checks = std.ArrayList(PreviewCheck).empty;
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "workbench-schema", if (std.mem.eql(u8, workbench.schema, workbench_schema) and workbench.schema_version == 1) .pass else .fail, "source workbench preview schema is supported");
    try appendCheck(allocator, &checks, "workbench-ready", if (std.mem.eql(u8, workbench.preview_status, "ready")) .pass else .fail, "source workbench preview is ready");
    try appendCheck(allocator, &checks, "decision-approved", if (options.decision == .approve) .pass else .fail, "CI artifact preview decision approved the handoff");
    try appendCheck(allocator, &checks, "workbench-review-approved", if (std.mem.eql(u8, workbench.decision, "approve")) .pass else .fail, "source workbench reviewer approved the handoff");
    try appendCheck(allocator, &checks, "workbench-next-branch-ready", if (workbench.ready_for_next_branch) .pass else .fail, "source workbench preview marked the next branch ready");
    try appendCheck(allocator, &checks, "authority-disabled", if (authorityDisabled(workbench)) .pass else .fail, "live telemetry network runtime durable NenDB and CI gate authority remain disabled");
    try appendCheck(allocator, &checks, "workbench-verification-recorded", if (sourceVerificationRecorded(workbench)) .pass else .fail, "source workbench artifact recorded required verification command evidence");
    try appendCheck(allocator, &checks, "mapping-fixtures-carried", if (mappingFixturesPresent(workbench.nendb_mapping_fixtures)) .pass else .fail, "required NenDB mapping fixture ids are carried forward");
    try appendCheck(allocator, &checks, "artifact-candidates-present", if (artifactCandidatesPresent(paths)) .pass else .fail, "required CI artifact preview candidates are present");
    try appendCheck(allocator, &checks, "artifact-extensions-allowlisted", if (artifactExtensionsAllowlisted(paths, options.workbench_path, workbench.source_retention)) .pass else .fail, "artifact candidates use txt json or dot extensions only");
    try appendCheck(allocator, &checks, "artifact-roots-allowlisted", if (artifactRootsAllowlisted(options.workbench_path, workbench.source_retention, paths)) .pass else .fail, "artifact candidates remain in the causal artifact root or explicit source paths");
    try appendCheck(allocator, &checks, "upload-preview-only", if (!ci_upload_enabled and !ci_workflow_mutation_enabled and !ci_gate_enabled and ci_artifact_preview_enabled) .pass else .fail, "CI upload workflow mutation and gates remain disabled");
    try appendCheck(allocator, &checks, "preview-verification-recorded", if (verifiedCommandsContainAll(options.verified_commands, required_verification_commands)) .pass else .fail, "CI artifact preview recorded every required verification command");

    const check_slice = try checks.toOwnedSlice(allocator);
    errdefer allocator.free(check_slice);
    const ready = allChecksPassed(check_slice);
    return .{ .status = if (ready) .ready else .blocked, .ready_for_next_branch = ready, .checks = check_slice };
}
```

Add helper functions:

```zig
fn authorityDisabled(workbench: WorkbenchPreviewArtifact) bool {
    return !workbench.applied and
        std.mem.eql(u8, workbench.mutation_authority, "none") and
        workbench.read_only_preview and
        workbench.solid_webui_enabled and
        !workbench.production_telemetry_ingestion and
        !workbench.live_exporter_enabled and
        !workbench.network_send_enabled and
        !workbench.collector_endpoint_configured and
        !workbench.otlp_serialization_enabled and
        !workbench.runtime_pipeline_enabled and
        !workbench.durable_write_enabled and
        !workbench.nendb_write_enabled and
        !workbench.ci_gate_enabled and
        !production_telemetry_ingestion and
        !live_exporter_enabled and
        !network_send_enabled and
        !collector_endpoint_configured and
        !otlp_serialization_enabled and
        !runtime_pipeline_enabled and
        !durable_write_enabled and
        !nendb_write_enabled and
        !ci_gate_enabled and
        !ci_upload_enabled and
        !ci_workflow_mutation_enabled and
        ci_artifact_preview_enabled;
}

fn mappingFixturesPresent(fixtures: []const NendbMappingFixture) bool {
    return hasMappingFixture(fixtures, "nendb-runtime-event-node-fixture") and
        hasMappingFixture(fixtures, "nendb-correlation-edge-fixture");
}

fn sourceVerificationRecorded(workbench: WorkbenchPreviewArtifact) bool {
    return workbench.required_verification_commands.len > 0 and
        verifiedCommandsContainAll(workbench.verified_commands, workbench.required_verification_commands);
}
```

- [ ] **Step 4: Add JSON and text formatting**

Implement `formatPreviewJson` and `formatPreviewText` so they emit:

```json
{
  "schema": "zigeffect.causal.production-telemetry-ci-artifact-preview.v1",
  "schema_version": 1,
  "source_workbench_preview": ".zig-cache/causal-artifacts/workbench-preview.json",
  "decision": "approve",
  "ci_artifact_preview_status": "ready",
  "ready_for_next_branch": true,
  "ci_artifact_preview_enabled": true,
  "ci_upload_enabled": false,
  "ci_workflow_mutation_enabled": false,
  "ci_gate_enabled": false,
  "artifact_upload_policy": {
    "mode": "preview-only",
    "failure_only": true,
    "retention_days": 14,
    "allowed_extensions": [".txt", ".json", ".dot"],
    "allowed_roots": ["packages/zigeffect/.zig-cache/causal-artifacts"],
    "disallowed_roots": [".zig-cache", "packages/zigeffect/.zig-cache"],
    "ignore_missing_files": true,
    "public_upload_claim": false,
    "ci_gate_claim": false
  },
  "artifact_candidates": [
    {
      "id": "source-workbench-preview-json",
      "path": ".zig-cache/causal-artifacts/workbench-preview.json",
      "extension": ".json",
      "artifact_kind": "source-evidence",
      "purpose": "reviewed UI and evidence handoff",
      "retention_days": 14,
      "failure_only": true,
      "allowed_root": "packages/zigeffect/.zig-cache/causal-artifacts",
      "produced_by": "causal-production-telemetry-workbench-readonly-preview",
      "consumer": "agents and reviewers",
      "redaction_required": true,
      "public_upload_allowed": false
    }
  ]
}
```

Also emit `mapping_fixture_ids`, `checks`, `required_verification_commands`, `verified_commands`, `implementation_gates`, `non_goals`, `blocked_claims`, and `agent_guidance`.

- [ ] **Step 5: Add run/main IO**

Implement the same IO boundary used by the workbench preview tool:

```zig
fn usage() []const u8 {
    return "usage: zig build causal-production-telemetry-ci-artifact-preview -- --from-workbench <workbench-preview.json> approve|reject --reason <reason> [--by <actor>] [--policy <policy>] [--verified-command <command>]... [--out-prefix <path-prefix>]\n";
}

fn readRequiredArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => error.MissingWorkbenchInput,
        else => return err,
    };
}

fn writeArtifact(io: std.Io, path: []const u8, contents: []const u8) !void {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return error.InvalidArtifactPath;
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, path[0..slash]);
    try cwd.writeFile(io, .{ .sub_path = path, .data = contents });
}
```

- [ ] **Step 6: Run the tool tests**

Run:

```sh
cd packages/zigeffect
zig fmt tools/causal_production_telemetry_ci_artifact_preview.zig
zig test tools/causal_production_telemetry_ci_artifact_preview.zig
```

Expected: all tests pass.

- [ ] **Step 7: Commit the implemented tool**

Run:

```sh
git add packages/zigeffect/tools/causal_production_telemetry_ci_artifact_preview.zig
git commit -m "feat(zigeffect): add production telemetry ci artifact preview tool"
```

## Task 3: Wire The Build Step

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add the build module, executable, run step, and tests**

Insert after the workbench read-only preview tool block:

```zig
const causal_production_telemetry_ci_artifact_preview_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_production_telemetry_ci_artifact_preview.zig"),
    .target = target,
    .optimize = optimize,
});

const causal_production_telemetry_ci_artifact_preview_tool = b.addExecutable(.{
    .name = "zigeffect-causal-production-telemetry-ci-artifact-preview",
    .root_module = causal_production_telemetry_ci_artifact_preview_tool_module,
});
const run_causal_production_telemetry_ci_artifact_preview_tool = b.addRunArtifact(causal_production_telemetry_ci_artifact_preview_tool);
if (b.args) |args| run_causal_production_telemetry_ci_artifact_preview_tool.addArgs(args);
const causal_production_telemetry_ci_artifact_preview_step = b.step("causal-production-telemetry-ci-artifact-preview", "Review production telemetry CI artifact preview");
causal_production_telemetry_ci_artifact_preview_step.dependOn(&run_causal_production_telemetry_ci_artifact_preview_tool.step);

const causal_production_telemetry_ci_artifact_preview_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-production-telemetry-ci-artifact-preview-tests",
    .root_module = causal_production_telemetry_ci_artifact_preview_tool_module,
});
const run_causal_production_telemetry_ci_artifact_preview_tool_tests = b.addRunArtifact(causal_production_telemetry_ci_artifact_preview_tool_tests);
test_step.dependOn(&run_causal_production_telemetry_ci_artifact_preview_tool_tests.step);
```

Add both dependencies near the existing production telemetry example dependencies:

```zig
examples_step.dependOn(&causal_production_telemetry_ci_artifact_preview_tool.step);
examples_step.dependOn(&run_causal_production_telemetry_ci_artifact_preview_tool_tests.step);
```

- [ ] **Step 2: Verify build wiring**

Run:

```sh
cd packages/zigeffect
zig fmt build.zig
zig build causal-production-telemetry-ci-artifact-preview -- \
  --from-workbench ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview.json \
  approve \
  --reason "CI artifact preview reviewed" \
  --verified-command "zig build causal-production-telemetry-workbench-readonly-preview" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Expected: emits ready text and writes `*-ci-artifact-preview.json` and `*-ci-artifact-preview.txt`.

- [ ] **Step 3: Check ready artifact fields**

Run:

```sh
rg '"ci_artifact_preview_status": "ready"|"ci_artifact_preview_enabled": true|"ci_upload_enabled": false|"ci_workflow_mutation_enabled": false|"ci_gate_enabled": false|"next_branch_if_ready": "codex/zigeffect-causal-production-telemetry-ci-harness-boundary"' ../../.zig-cache/causal-artifacts/*-ci-artifact-preview.json
```

Expected: every pattern is found.

- [ ] **Step 4: Run build-level tests**

Run:

```sh
cd packages/zigeffect
zig build test
zig build examples
```

Expected: both pass.

- [ ] **Step 5: Commit build wiring**

Run:

```sh
git add packages/zigeffect/build.zig
git commit -m "build(zigeffect): wire production telemetry ci artifact preview"
```

## Task 4: Governance And Documentation

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Add: `packages/zigeffect/docs/production-telemetry-ci-artifact-preview.md`
- Modify docs listed in the file map

- [ ] **Step 1: Write failing governance assertions**

In `causal_schema_governance.zig`, update tests to expect:

```zig
try std.testing.expectEqual(@as(usize, 59), entries.len);
try expectSchema(entries, "zigeffect.causal.production-telemetry-ci-artifact-preview.v1");
try std.testing.expect(std.mem.indexOf(u8, report, "schema count: 59") != null);
try std.testing.expect(std.mem.indexOf(u8, report, "ci-artifact-preview") != null);
try std.testing.expect(std.mem.indexOf(u8, report, "\"schema_count\": 59") != null);
try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-telemetry-ci-artifact-preview.v1\"") != null);
```

In `causal_production_hardening_backlog.zig`, update tests to expect:

```zig
try std.testing.expectEqualStrings("start-production-telemetry-ci-harness-boundary", recommendation);
try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-harness-boundary", recommended_next_branch);
try expectBacklogItem("production-telemetry-ci-artifact-preview");
try expectBacklogItemStatus("production-telemetry-ci-artifact-preview", "delivered");
try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-telemetry-ci-artifact-preview") != null);
```

- [ ] **Step 2: Verify governance tests fail before implementation**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog.zig
zig build causal-schema-governance -- --format json
```

Expected: fail or emit stale values because the new schema/backlog item is not registered yet.

- [ ] **Step 3: Register the schema**

In `causal_schema_governance.zig`, add this entry after the workbench preview schema:

```zig
.{
    .schema = "zigeffect.causal.production-telemetry-ci-artifact-preview.v1",
    .version = 1,
    .category = "production-hardening",
    .status = "current",
    .emitted_by = &.{"causal-production-telemetry-ci-artifact-preview"},
    .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry CI harness boundary" },
    .compatibility = &.{ "strict-v1", "record-only", "mutation-authority-none", "ci-artifact-preview", "preview-only", "failure-attachment-catalog", "no-live-ingestion", "no-network", "no-durable-write", "no-nendb-write", "no-ci-gate" },
    .governance_requirements = &.{ "source workbench preview evidence checks", "artifact candidate allowlist checks", "preview-only CI authority checks", "next-branch handoff" },
},
```

- [ ] **Step 4: Advance the backlog**

In `causal_production_hardening_backlog.zig`, update constants:

```zig
pub const recommendation = "start-production-telemetry-ci-harness-boundary";
pub const recommended_next_branch = "codex/zigeffect-causal-production-telemetry-ci-harness-boundary";
```

Add delivered item:

```zig
.{
    .id = "production-telemetry-ci-artifact-preview",
    .title = "Production Telemetry CI Artifact Preview",
    .gap_id = "production-telemetry-ci-artifact-preview",
    .priority = "P5",
    .status = "delivered",
    .summary = "Consumes ready workbench preview artifacts and emits record-only CI archive candidate and upload policy preview evidence before any CI harness or gate work.",
    .depends_on = &.{ "production-telemetry-workbench-readonly-preview", "artifact-access-control", "production-telemetry-nendb-retention-fixtures" },
    .deliverables = &.{
        "approved and blocked CI artifact preview artifacts",
        "failure-only archive candidate catalog",
        "preview-only upload retention policy",
        "CI harness boundary handoff",
    },
    .evidence_sources = &.{
        "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-ci-artifact-preview-design.md",
        "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-ci-artifact-preview-implementation.md",
        "packages/zigeffect/tools/causal_production_telemetry_ci_artifact_preview.zig",
        "packages/zigeffect/docs/production-telemetry-ci-artifact-preview.md",
    },
    .branch = "codex/zigeffect-causal-production-telemetry-ci-artifact-preview",
    .agent_guidance = "Use approved CI artifact preview artifacts to start CI harness boundary work only; do not infer artifact upload execution, CI gates, runtime ingestion, network transport, OTLP serialization, NenDB writes, durable writes, hosted dashboard readiness, alternate renderers, or mutation authority.",
},
```

Append `production-telemetry-ci-artifact-preview` to `dependency_order` and add approve/reject verification commands for `causal-production-telemetry-ci-artifact-preview`.

- [ ] **Step 5: Add and update docs**

Create `packages/zigeffect/docs/production-telemetry-ci-artifact-preview.md` covering:

- command usage;
- source workbench preview input;
- artifact upload policy preview;
- artifact candidate catalog;
- authority boundary;
- ready/blocked status;
- output paths;
- agent guidance;
- verification commands.

Update README, operations, roadmap, schema governance docs, production backlog docs, completion audit docs, production telemetry source docs, and master roadmap so:

- CI artifact preview is delivered;
- current next branch is `codex/zigeffect-causal-production-telemetry-ci-harness-boundary`;
- claims remain blocked for CI upload execution, CI gates, live telemetry, durable writes, NenDB writes, hosted dashboard readiness, alternate renderers, and mutation authority.

- [ ] **Step 6: Run governance verification**

Run:

```sh
cd packages/zigeffect
zig fmt tools/causal_schema_governance.zig tools/causal_production_hardening_backlog.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-schema-governance -- --format json 2> ../../.zig-cache/causal-artifacts/schema-governance.json
rg '"schema_count": 59|production-telemetry-ci-artifact-preview|ci-artifact-preview' ../../.zig-cache/causal-artifacts/schema-governance.json
zig build causal-production-hardening-backlog -- --format json 2> ../../.zig-cache/causal-artifacts/production-hardening-backlog.json
rg 'start-production-telemetry-ci-harness-boundary|codex/zigeffect-causal-production-telemetry-ci-harness-boundary|production-telemetry-ci-artifact-preview' ../../.zig-cache/causal-artifacts/production-hardening-backlog.json
rg 'start-production-telemetry-ci-artifact-preview|schema count: 58|"schema_count": 58' packages/zigeffect/docs packages/zigeffect/tools docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
```

Expected: tests pass; first two `rg` checks find current values; final stale-value `rg` has no active-current references except historical delivered text.

- [ ] **Step 7: Commit governance and docs**

Run:

```sh
git add docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md \
  packages/zigeffect/README.md \
  packages/zigeffect/docs/load-test-observation-harness.md \
  packages/zigeffect/docs/operations.md \
  packages/zigeffect/docs/production-hardening-backlog.md \
  packages/zigeffect/docs/production-hardening-completion-audit.md \
  packages/zigeffect/docs/production-telemetry-capture-design.md \
  packages/zigeffect/docs/production-telemetry-capture-fixtures.md \
  packages/zigeffect/docs/production-telemetry-exporter-boundary.md \
  packages/zigeffect/docs/production-telemetry-nendb-retention-fixtures.md \
  packages/zigeffect/docs/production-telemetry-workbench-readonly-preview.md \
  packages/zigeffect/docs/production-telemetry-ci-artifact-preview.md \
  packages/zigeffect/docs/roadmap.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  packages/zigeffect/tools/causal_schema_governance.zig
git commit -m "docs(zigeffect): document production telemetry ci artifact preview"
```

## Task 5: Full Verification

**Files:**
- All touched files

- [ ] **Step 1: Run targeted preview commands**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_artifact_preview.zig
zig build causal-production-telemetry-ci-artifact-preview -- \
  --from-workbench ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview.json \
  approve \
  --reason "CI artifact preview reviewed" \
  --verified-command "zig build causal-production-telemetry-workbench-readonly-preview" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-production-telemetry-ci-artifact-preview -- \
  --from-workbench ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview.json \
  reject \
  --reason "negative CI artifact preview path"
```

Expected: approve emits ready; reject emits blocked; both keep upload/gate/workflow mutation disabled.

- [ ] **Step 2: Run full branch verification**

Run:

```sh
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:test
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build test
bun run check
bun run zig:test
git diff --check
git status --short
```

Expected: all commands pass and status is clean after commits.

- [ ] **Step 3: Report next branch**

Report:

- current branch: `codex/zigeffect-causal-production-telemetry-ci-artifact-preview`;
- delivered schema: `zigeffect.causal.production-telemetry-ci-artifact-preview.v1`;
- current next branch:
  `codex/zigeffect-causal-production-telemetry-ci-harness-boundary`;
- no CI workflow, upload, gate, live telemetry, durable write, NenDB write, hosted dashboard, or mutation authority was enabled.

## Self-Review

- Spec coverage: the tool, build wiring, governance, docs, verification, and no-workflow boundary are covered.
- Placeholder scan: no placeholder-only task remains.
- Type consistency: schema, command, status, option names, and next branch match the design spec.
- Scope check: this is one record-only artifact-preview branch, not CI harness implementation.
