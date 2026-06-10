# Production Telemetry CI Harness Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a record-only production telemetry CI harness boundary contract that consumes ready CI artifact preview evidence, inspects the existing causal GitHub Actions workflow, and emits agent-readable workflow-boundary evidence before any CI mutation or gate work.

**Architecture:** Create one deterministic Zig tool, wire it into `packages/zigeffect/build.zig`, and update schema/backlog/docs. The tool parses `zigeffect.causal.production-telemetry-ci-artifact-preview.v1`, verifies preview-only authority, inspects `.github/workflows/zigeffect-causal.yml` for required and prohibited features, records clustering release-gate assumptions, and emits `zigeffect.causal.production-telemetry-ci-harness-boundary.v1` with all mutation/upload/gate authority disabled.

**Tech Stack:** Zig 0.16 build tools, existing zigeffect artifact-tool patterns, GitHub Actions workflow text inspection, Markdown docs.

---

## Files

- Add: `packages/zigeffect/tools/causal_production_telemetry_ci_harness_boundary.zig`
- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Add: `packages/zigeffect/docs/production-telemetry-ci-harness-boundary.md`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/production-hardening-completion-audit.md`
- Modify: `packages/zigeffect/docs/production-telemetry-ci-artifact-preview.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

Do not modify `.github/workflows/zigeffect-causal.yml` in this branch.

## Task 1: Red Tests For The CI Harness Boundary Tool

**Files:**
- Add: `packages/zigeffect/tools/causal_production_telemetry_ci_harness_boundary.zig`

- [ ] **Step 1: Create the new tool file with failing tests**

Create `packages/zigeffect/tools/causal_production_telemetry_ci_harness_boundary.zig` with constants, type stubs, sample evidence, and tests first:

```zig
const std = @import("std");

pub const production_telemetry_ci_harness_boundary_schema = "zigeffect.causal.production-telemetry-ci-harness-boundary.v1";
pub const production_telemetry_ci_harness_boundary_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-harness-boundary";
pub const recommendation = "start-production-telemetry-ci-archive-application";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-ci-archive-application";

const default_workflow_path = "../../.github/workflows/zigeffect-causal.yml";

const required_verification_commands: []const []const u8 = &.{
    "zig build causal-production-telemetry-ci-artifact-preview",
    "zig build causal-artifacts",
    "zig build release-gate --summary none",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
};

test "ci harness boundary schema and branch constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-ci-harness-boundary.v1", production_telemetry_ci_harness_boundary_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_ci_harness_boundary_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-harness-boundary", source_branch);
    try std.testing.expectEqualStrings("start-production-telemetry-ci-archive-application", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-archive-application", next_branch_if_ready);
    try std.testing.expect(containsString(required_verification_commands, "zig build causal-production-telemetry-ci-artifact-preview"));
    try std.testing.expect(containsString(required_verification_commands, "zig build release-gate --summary none"));
}

test "parses ci harness boundary options with optional workflow and verified commands" {
    var options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-production-telemetry-ci-harness-boundary",
        "--from-ci-preview",
        ".zig-cache/causal-artifacts/ci-preview.json",
        "--workflow",
        "../../.github/workflows/zigeffect-causal.yml",
        "approve",
        "--reason",
        "CI harness boundary reviewed",
        "--by",
        "codex",
        "--policy",
        "manual-production-telemetry-ci-harness-boundary",
        "--verified-command",
        "zig build release-gate --summary none",
        "--out-prefix",
        ".zig-cache/causal-artifacts/custom-ci-harness-boundary",
    });
    defer options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Decision.approve, options.decision);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/ci-preview.json", options.ci_preview_path);
    try std.testing.expectEqualStrings("../../.github/workflows/zigeffect-causal.yml", options.workflow_path);
    try std.testing.expectEqualStrings("CI harness boundary reviewed", options.reason);
    try std.testing.expectEqualStrings("codex", options.reviewed_by);
    try std.testing.expectEqualStrings("manual-production-telemetry-ci-harness-boundary", options.policy);
    try std.testing.expectEqual(@as(usize, 1), options.verified_commands.len);
    try std.testing.expectEqualStrings("zig build release-gate --summary none", options.verified_commands[0]);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-ci-harness-boundary", options.out_prefix.?);
}

test "ready and blocked ci harness boundary reports preserve record-only authority" {
    const ready = try formatReports(std.testing.allocator, .{
        .options = .{
            .ci_preview_path = ".zig-cache/causal-artifacts/ci-preview.json",
            .workflow_path = ".github/workflows/zigeffect-causal.yml",
            .decision = .approve,
            .reason = "CI harness boundary reviewed",
            .verified_commands = required_verification_commands,
        },
        .source_ci_preview_json = sample_ci_artifact_preview_json,
        .workflow_yml = sample_workflow_yml,
    });
    defer ready.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"schema\": \"zigeffect.causal.production-telemetry-ci-harness-boundary.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ci_harness_boundary_status\": \"ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ready_for_next_branch\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ci_harness_boundary_enabled\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ci_upload_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ci_upload_execution_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ci_workflow_mutation_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ci_gate_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"workflow_digest\": \"sha256:") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"id\": \"release-gate-runs\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"id\": \"no-secrets-usage\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"cluster_release_gate_assumptions\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"next_branch_if_ready\": \"codex/zigeffect-causal-production-telemetry-ci-archive-application\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.text, "ci_harness_boundary_status: ready") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.text, "ci workflow mutation enabled: false") != null);

    const blocked = try formatReports(std.testing.allocator, .{
        .options = .{
            .ci_preview_path = ".zig-cache/causal-artifacts/ci-preview.json",
            .workflow_path = ".github/workflows/zigeffect-causal.yml",
            .decision = .reject,
            .reason = "negative CI harness boundary path",
        },
        .source_ci_preview_json = sample_ci_artifact_preview_json,
        .workflow_yml = sample_workflow_yml,
    });
    defer blocked.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"ci_harness_boundary_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"ready_for_next_branch\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"ci_upload_execution_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.text, "ci_harness_boundary_status: blocked") != null);
}

test "workflow prohibited features block the harness boundary" {
    const blocked = try formatReports(std.testing.allocator, .{
        .options = .{
            .ci_preview_path = ".zig-cache/causal-artifacts/ci-preview.json",
            .workflow_path = ".github/workflows/zigeffect-causal.yml",
            .decision = .approve,
            .reason = "CI harness boundary reviewed",
            .verified_commands = required_verification_commands,
        },
        .source_ci_preview_json = sample_ci_artifact_preview_json,
        .workflow_yml = sample_workflow_yml ++ "\n      - run: echo ${{ secrets.PRODUCTION_TELEMETRY_TOKEN }}\n",
    });
    defer blocked.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"ci_harness_boundary_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"id\": \"no-secrets-usage\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"status\": \"fail\"") != null);
}
```

Add sample JSON and workflow strings at the bottom of the file:

```zig
const sample_ci_artifact_preview_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-artifact-preview.v1",
    \\  "schema_version": 1,
    \\  "source_workbench_preview": ".zig-cache/causal-artifacts/workbench-preview.json",
    \\  "source_retention": ".zig-cache/causal-artifacts/nendb-retention.json",
    \\  "source_local_pipeline": ".zig-cache/causal-artifacts/local-pipeline.json",
    \\  "source_boundary": ".zig-cache/causal-artifacts/exporter-boundary.json",
    \\  "source_proposal": ".zig-cache/causal-artifacts/implementation-proposal.json",
    \\  "source_readiness": ".zig-cache/causal-artifacts/readiness-review.json",
    \\  "source_fixtures": ".zig-cache/causal-artifacts/capture-fixtures.json",
    \\  "decision": "approve",
    \\  "ci_artifact_preview_status": "ready",
    \\  "ready_for_next_branch": true,
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "network_send_enabled": false,
    \\  "collector_endpoint_configured": false,
    \\  "otlp_serialization_enabled": false,
    \\  "runtime_pipeline_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "nendb_write_enabled": false,
    \\  "ci_gate_enabled": false,
    \\  "ci_upload_enabled": false,
    \\  "ci_workflow_mutation_enabled": false,
    \\  "ci_artifact_preview_enabled": true,
    \\  "artifact_upload_policy": {
    \\    "mode": "preview-only",
    \\    "failure_only": true,
    \\    "retention_days": 14,
    \\    "allowed_extensions": [".txt", ".json", ".dot"],
    \\    "public_upload_claim": false,
    \\    "ci_gate_claim": false
    \\  },
    \\  "artifact_candidates": [
    \\    { "id": "source-workbench-preview-json", "path": ".zig-cache/causal-artifacts/workbench-preview.json", "extension": ".json", "failure_only": true, "redaction_required": true, "public_upload_allowed": false },
    \\    { "id": "source-retention-fixtures-json", "path": ".zig-cache/causal-artifacts/nendb-retention.json", "extension": ".json", "failure_only": true, "redaction_required": true, "public_upload_allowed": false },
    \\    { "id": "future-ci-preview-json", "path": ".zig-cache/causal-artifacts/ci-preview.json", "extension": ".json", "failure_only": true, "redaction_required": true, "public_upload_allowed": false }
    \\  ],
    \\  "checks": [
    \\    { "name": "decision-approved", "status": "pass", "detail": "review approved" },
    \\    { "name": "upload-preview-only", "status": "pass", "detail": "CI upload workflow mutation and gates remain disabled" }
    \\  ],
    \\  "required_verification_commands": [
    \\    "zig build causal-production-telemetry-workbench-readonly-preview",
    \\    "zig build causal-artifacts"
    \\  ],
    \\  "verified_commands": [
    \\    "zig build causal-production-telemetry-workbench-readonly-preview",
    \\    "zig build causal-artifacts"
    \\  ],
    \\  "blocked_claims": [
    \\    "ci-artifact-upload-enabled",
    \\    "ci-workflow-mutated",
    \\    "ci-telemetry-gate"
    \\  ]
    \\}
;

const sample_workflow_yml =
    \\name: zigeffect causal
    \\
    \\on:
    \\  pull_request:
    \\    paths:
    \\      - ".github/workflows/zigeffect-causal.yml"
    \\      - "packages/zigeffect/**"
    \\      - "package.json"
    \\      - "bun.lock"
    \\  push:
    \\    branches:
    \\      - master
    \\  workflow_dispatch:
    \\
    \\permissions:
    \\  contents: read
    \\
    \\jobs:
    \\  zigeffect-causal:
    \\    steps:
    \\      - name: Checkout
    \\        uses: actions/checkout@v4
    \\      - name: Set up Zig
    \\        uses: mlugg/setup-zig@v2.2.1
    \\        with:
    \\          version: 0.16.0
    \\      - name: Capture PR base causal baselines
    \\        if: ${{ github.event_name == 'pull_request' }}
    \\        run: |
    \\          zig build causal-test
    \\          zig build causal-dev-loop -- baseline package-tests
    \\      - name: Print causal artifact manifest
    \\        run: zig build causal-artifacts
    \\      - name: Run release gate
    \\        run: zig build release-gate --summary none
    \\      - name: Write causal CI handoff
    \\        if: ${{ failure() }}
    \\        run: zig build causal-ci-handoff
    \\      - name: Upload causal artifacts on failure
    \\        if: ${{ failure() }}
    \\        uses: actions/upload-artifact@v4
    \\        with:
    \\          if-no-files-found: ignore
    \\          retention-days: 14
    \\          path: |
    \\            packages/zigeffect/.zig-cache/causal-artifacts/*.txt
    \\            packages/zigeffect/.zig-cache/causal-artifacts/*.json
    \\            packages/zigeffect/.zig-cache/causal-artifacts/*.dot
    \\            packages/zigeffect/.zig-cache/release-gate/*.txt
    \\            packages/zigeffect/.zig-cache/release-gate/*.json
;
```

- [ ] **Step 2: Verify the tests fail for missing implementation**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_harness_boundary.zig
```

Expected: fail with undeclared identifiers such as `containsString`, `parseOptions`, `Decision`, and `formatReports`.

- [ ] **Step 3: Verify the build step is not wired yet**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-harness-boundary
```

Expected: fail with an unknown build step.

## Task 2: Implement The CI Harness Boundary Tool

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_harness_boundary.zig`

- [ ] **Step 1: Add parser and core data types**

Add:

- `Decision = enum { approve, reject }`
- `BoundaryStatus = enum { ready, blocked }`
- `CheckStatus = enum { pass, fail }`
- `Options` with `ci_preview_path`, `workflow_path`, `decision`, `reviewed_by`, `policy`, `reason`, `verified_commands`, and `out_prefix`
- `parseOptions`
- `parseDecision`
- `outputPathsForOptions`
- `deinit` methods for owned slices

Parser behavior:

- `--from-ci-preview <path>` is required.
- `--workflow <path>` is optional before the decision and defaults to `../../.github/workflows/zigeffect-causal.yml`.
- The first non-flag token after `--from-ci-preview` and optional `--workflow` is the decision.
- Decision must be `approve` or `reject`.
- `--reason <reason>` is required and non-empty.
- `--by`, `--policy`, `--verified-command`, and `--out-prefix` are optional after the decision.
- Unknown flags fail with `error.UnknownFlag`.
- Missing flag values fail with `error.MissingFlagValue`.
- Non-JSON CI preview paths fail with `error.InvalidCiPreviewPath`.
- Non-YAML workflow paths fail with `error.InvalidWorkflowPath`.

- [ ] **Step 2: Add source preview parsing and source checks**

Add JSON structs:

- `CiArtifactPreviewArtifact`
- `ArtifactUploadPolicy`
- `ArtifactCandidate`
- `SourceCheck`

Parse with:

```zig
std.json.parseFromSlice(CiArtifactPreviewArtifact, allocator, input.source_ci_preview_json, .{ .ignore_unknown_fields = true })
```

Add checks:

- `source-preview-schema`
- `source-preview-ready`
- `decision-approved`
- `source-preview-review-approved`
- `source-preview-next-branch-ready`
- `source-preview-authority-disabled`
- `source-preview-checks-passed`
- `source-preview-verification-recorded`
- `source-preview-upload-policy`
- `source-preview-candidates`
- `source-preview-blocked-claims-carried`

The source authority check must require:

```zig
!preview.applied
std.mem.eql(u8, preview.mutation_authority, "none")
!preview.production_telemetry_ingestion
!preview.live_exporter_enabled
!preview.network_send_enabled
!preview.collector_endpoint_configured
!preview.otlp_serialization_enabled
!preview.runtime_pipeline_enabled
!preview.durable_write_enabled
!preview.nendb_write_enabled
!preview.ci_gate_enabled
!preview.ci_upload_enabled
!preview.ci_workflow_mutation_enabled
preview.ci_artifact_preview_enabled
```

- [ ] **Step 3: Add workflow text checks**

Add exact required-feature checks:

```zig
const required_workflow_features: []const WorkflowTextCheck = &.{
    .{ .id = "workflow-name", .needle = "name: zigeffect causal", .detail = "causal workflow is named" },
    .{ .id = "pull-request-trigger", .needle = "pull_request:", .detail = "pull request trigger exists" },
    .{ .id = "push-master-trigger", .needle = "- master", .detail = "push trigger targets master" },
    .{ .id = "workflow-dispatch-trigger", .needle = "workflow_dispatch:", .detail = "manual dispatch trigger exists" },
    .{ .id = "permissions-read", .needle = "contents: read", .detail = "workflow permissions are read-only" },
    .{ .id = "checkout-v4", .needle = "actions/checkout@v4", .detail = "workflow checks out source" },
    .{ .id = "setup-zig", .needle = "mlugg/setup-zig@v2.2.1", .detail = "workflow installs Zig" },
    .{ .id = "zig-016", .needle = "version: 0.16.0", .detail = "workflow uses Zig 0.16.0" },
    .{ .id = "base-causal-test", .needle = "zig build causal-test", .detail = "PR baseline runs causal-test" },
    .{ .id = "base-dev-loop-baseline", .needle = "zig build causal-dev-loop -- baseline package-tests", .detail = "PR baseline writes package-test baseline" },
    .{ .id = "causal-artifacts-manifest", .needle = "zig build causal-artifacts", .detail = "workflow prints causal artifact manifest" },
    .{ .id = "release-gate-runs", .needle = "zig build release-gate --summary none", .detail = "workflow runs durable workflow and cluster release gate" },
    .{ .id = "failure-handoff", .needle = "zig build causal-ci-handoff", .detail = "workflow writes failure handoff" },
    .{ .id = "failure-only-upload", .needle = "if: ${{ failure() }}", .detail = "upload and handoff are failure-only" },
    .{ .id = "upload-artifact-v4", .needle = "actions/upload-artifact@v4", .detail = "workflow uses GitHub artifact upload action" },
    .{ .id = "ignore-missing-files", .needle = "if-no-files-found: ignore", .detail = "missing preview files remain non-fatal" },
    .{ .id = "retention-fourteen-days", .needle = "retention-days: 14", .detail = "artifact retention is bounded" },
    .{ .id = "causal-txt-glob", .needle = "packages/zigeffect/.zig-cache/causal-artifacts/*.txt", .detail = "causal text artifacts are archived" },
    .{ .id = "causal-json-glob", .needle = "packages/zigeffect/.zig-cache/causal-artifacts/*.json", .detail = "causal JSON artifacts are archived" },
    .{ .id = "causal-dot-glob", .needle = "packages/zigeffect/.zig-cache/causal-artifacts/*.dot", .detail = "causal graph artifacts are archived" },
    .{ .id = "release-gate-txt-glob", .needle = "packages/zigeffect/.zig-cache/release-gate/*.txt", .detail = "release-gate text artifacts are archived" },
    .{ .id = "release-gate-json-glob", .needle = "packages/zigeffect/.zig-cache/release-gate/*.json", .detail = "release-gate JSON artifacts are archived" },
};
```

Add prohibited-feature checks:

```zig
const prohibited_workflow_features: []const WorkflowTextCheck = &.{
    .{ .id = "no-secrets-usage", .needle = "secrets.", .detail = "workflow does not reference secrets" },
    .{ .id = "no-write-all-permissions", .needle = "write-all", .detail = "workflow does not request write-all permissions" },
    .{ .id = "no-contents-write", .needle = "contents: write", .detail = "workflow does not request content writes" },
    .{ .id = "no-id-token-write", .needle = "id-token: write", .detail = "workflow does not request OIDC token writes" },
    .{ .id = "no-schedule-trigger", .needle = "schedule:", .detail = "workflow does not poll on a schedule" },
    .{ .id = "no-collector-endpoint", .needle = "OTEL_EXPORTER_OTLP_ENDPOINT", .detail = "workflow does not configure OTLP endpoint" },
    .{ .id = "no-production-token", .needle = "PRODUCTION_TELEMETRY_TOKEN", .detail = "workflow does not configure production telemetry token" },
    .{ .id = "no-deploy-action", .needle = "cloudflare/wrangler-action", .detail = "workflow does not deploy production surfaces" },
    .{ .id = "no-telemetry-gate-step", .needle = "production telemetry gate", .detail = "workflow does not enforce telemetry gates" },
};
```

Required checks pass when the workflow contains the needle. Prohibited checks pass when the workflow does not contain the needle.

- [ ] **Step 4: Add report formatting**

Add:

- `formatReports`
- `evaluateBoundary`
- `formatBoundaryJson`
- `formatBoundaryText`
- `appendJsonString`
- `appendStringArray`
- `appendChecksJson`
- `workflowDigestHex`
- `agentGuidance`
- `implementation_gates`
- `non_goals`
- `blocked_claims`
- `cluster_release_gate_assumptions`
- `allowed_future_workflow_patch_scope`
- `disallowed_future_workflow_patch_scope`

The JSON report must include these authority fields and values:

```json
"applied": false,
"mutation_authority": "none",
"production_telemetry_ingestion": false,
"live_exporter_enabled": false,
"network_send_enabled": false,
"collector_endpoint_configured": false,
"otlp_serialization_enabled": false,
"runtime_pipeline_enabled": false,
"durable_write_enabled": false,
"nendb_write_enabled": false,
"ci_upload_enabled": false,
"ci_upload_execution_enabled": false,
"ci_workflow_mutation_enabled": false,
"ci_gate_enabled": false,
"ci_harness_boundary_enabled": true
```

`workflow_digest` must be a SHA-256 digest formatted as `sha256:<lowercase-hex>`.

- [ ] **Step 5: Add file IO and CLI entry point**

Add:

- `main`
- `usage`
- `failUsage`
- `readRequiredArtifact`
- `writeArtifact`
- `run`

`run` must read the source preview and workflow, format reports, write the JSON and text artifacts, and print the text report.

- [ ] **Step 6: Verify the tool tests pass**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_harness_boundary.zig
```

Expected: pass.

## Task 3: Wire The Build Step

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add the tool module, executable, step, and test wiring**

Insert after the CI artifact preview build block:

```zig
const causal_production_telemetry_ci_harness_boundary_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_production_telemetry_ci_harness_boundary.zig"),
    .target = target,
    .optimize = optimize,
});

const causal_production_telemetry_ci_harness_boundary_tool = b.addExecutable(.{
    .name = "zigeffect-causal-production-telemetry-ci-harness-boundary",
    .root_module = causal_production_telemetry_ci_harness_boundary_tool_module,
});
const run_causal_production_telemetry_ci_harness_boundary_tool = b.addRunArtifact(causal_production_telemetry_ci_harness_boundary_tool);
if (b.args) |args| run_causal_production_telemetry_ci_harness_boundary_tool.addArgs(args);
const causal_production_telemetry_ci_harness_boundary_step = b.step("causal-production-telemetry-ci-harness-boundary", "Review production telemetry CI harness boundary");
causal_production_telemetry_ci_harness_boundary_step.dependOn(&run_causal_production_telemetry_ci_harness_boundary_tool.step);

const causal_production_telemetry_ci_harness_boundary_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-production-telemetry-ci-harness-boundary-tests",
    .root_module = causal_production_telemetry_ci_harness_boundary_tool_module,
});
const run_causal_production_telemetry_ci_harness_boundary_tool_tests = b.addRunArtifact(causal_production_telemetry_ci_harness_boundary_tool_tests);
test_step.dependOn(&run_causal_production_telemetry_ci_harness_boundary_tool_tests.step);
```

Add to the examples/release tooling dependency area:

```zig
examples_step.dependOn(&causal_production_telemetry_ci_harness_boundary_tool.step);
examples_step.dependOn(&run_causal_production_telemetry_ci_harness_boundary_tool_tests.step);
```

- [ ] **Step 2: Verify build wiring**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-harness-boundary -- --help
```

Expected: the tool prints usage or fails with a usage error, proving the build step exists.

- [ ] **Step 3: Generate the source CI artifact preview if needed**

If the source CI preview artifact is missing, run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-workbench-readonly-preview -- \
  --from-retention ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures.json \
  approve \
  --reason "read-only SolidJS webui preview reviewed" \
  --verified-command "bun run zigeffect:workbench:typecheck" \
  --verified-command "bun run zigeffect:workbench:test" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"

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

- [ ] **Step 4: Verify ready and blocked CLI paths**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-harness-boundary -- \
  --from-ci-preview ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview.json \
  --workflow ../../.github/workflows/zigeffect-causal.yml \
  approve \
  --reason "CI harness boundary reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-artifact-preview" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"

zig build causal-production-telemetry-ci-harness-boundary -- \
  --from-ci-preview ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview.json \
  --workflow ../../.github/workflows/zigeffect-causal.yml \
  reject \
  --reason "negative CI harness boundary path"
```

Expected: first report is `ready`, second report is `blocked`, and both keep upload execution, workflow mutation, CI gates, telemetry, durable writes, and NenDB writes disabled.

- [ ] **Step 5: Commit the tool and build wiring**

Run:

```sh
git add packages/zigeffect/tools/causal_production_telemetry_ci_harness_boundary.zig packages/zigeffect/build.zig
git commit -m "feat(zigeffect): add production telemetry ci harness boundary"
```

## Task 4: Add Schema Governance And Backlog Entries

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`

- [ ] **Step 1: Add schema governance entry**

Insert after `zigeffect.causal.production-telemetry-ci-artifact-preview.v1`:

```zig
.{
    .schema = "zigeffect.causal.production-telemetry-ci-harness-boundary.v1",
    .version = 1,
    .category = "production-hardening",
    .status = "current",
    .emitted_by = &.{"causal-production-telemetry-ci-harness-boundary"},
    .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry CI archive application" },
    .compatibility = &.{ "strict-v1", "record-only", "mutation-authority-none", "ci-harness-boundary", "workflow-inspection", "cluster-release-gate-aware", "no-live-ingestion", "no-network", "no-durable-write", "no-nendb-write", "no-ci-gate", "no-workflow-mutation" },
    .governance_requirements = &.{ "source CI preview evidence checks", "workflow required-feature checks", "workflow prohibited-feature checks", "cluster release-gate assumptions", "next-branch handoff" },
},
```

Add a test expectation:

```zig
try expectSchema(entries, "zigeffect.causal.production-telemetry-ci-harness-boundary.v1");
```

- [ ] **Step 2: Update production hardening backlog recommendation**

Change:

```zig
pub const recommendation = "start-production-telemetry-ci-harness-boundary";
pub const recommended_next_branch = "codex/zigeffect-causal-production-telemetry-ci-harness-boundary";
```

to:

```zig
pub const recommendation = "start-production-telemetry-ci-archive-application";
pub const recommended_next_branch = "codex/zigeffect-causal-production-telemetry-ci-archive-application";
```

- [ ] **Step 3: Add backlog item**

Append to `backlog_items`:

```zig
.{
    .id = "production-telemetry-ci-harness-boundary",
    .title = "Production Telemetry CI Harness Boundary",
    .gap_id = "production-telemetry-ci-harness-boundary",
    .priority = "P5",
    .status = "delivered",
    .summary = "Consumes ready CI artifact preview evidence, inspects the existing causal GitHub Actions workflow, records clustering release-gate assumptions, and emits a record-only CI harness boundary before workflow mutation or gate work.",
    .depends_on = &.{ "production-telemetry-ci-artifact-preview", "artifact-access-control", "production-telemetry-nendb-retention-fixtures" },
    .deliverables = &.{
        "approved and blocked CI harness boundary artifacts",
        "existing causal workflow required-feature checks",
        "workflow prohibited-feature checks",
        "cluster release-gate assumptions",
        "archive application handoff",
    },
    .evidence_sources = &.{
        "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-ci-harness-boundary-design.md",
        "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-ci-harness-boundary-implementation.md",
        "packages/zigeffect/tools/causal_production_telemetry_ci_harness_boundary.zig",
        "packages/zigeffect/docs/production-telemetry-ci-harness-boundary.md",
    },
    .branch = "codex/zigeffect-causal-production-telemetry-ci-harness-boundary",
    .agent_guidance = "Use approved CI harness boundary artifacts to start CI archive application work only; do not infer workflow mutation, artifact upload execution, CI gates, runtime ingestion, network transport, OTLP serialization, NenDB writes, durable writes, hosted dashboard readiness, alternate renderers, production cluster readiness, or mutation authority.",
},
```

- [ ] **Step 4: Update dependency order and validation commands**

Add `"production-telemetry-ci-harness-boundary"` after `"production-telemetry-ci-artifact-preview"` in `dependency_order`.

Add validation commands:

```zig
"zig build causal-production-telemetry-ci-harness-boundary -- --from-ci-preview ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview.json --workflow ../../.github/workflows/zigeffect-causal.yml approve --reason \"CI harness boundary reviewed\" --verified-command \"zig build causal-production-telemetry-ci-artifact-preview\" --verified-command \"zig build causal-artifacts\" --verified-command \"zig build release-gate --summary none\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
"zig build causal-production-telemetry-ci-harness-boundary -- --from-ci-preview ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview.json --workflow ../../.github/workflows/zigeffect-causal.yml reject --reason \"negative CI harness boundary path\"",
```

Update tests to expect:

```zig
try expectBacklogItem("production-telemetry-ci-harness-boundary");
try expectBacklogItemStatus("production-telemetry-ci-harness-boundary", "delivered");
try std.testing.expect(std.mem.indexOf(u8, report, "recommended next branch: codex/zigeffect-causal-production-telemetry-ci-archive-application") != null);
try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"production-telemetry-ci-harness-boundary\"") != null);
```

- [ ] **Step 5: Verify governance/backlog tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_schema_governance.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

Expected: all pass and JSON output includes the new schema/backlog item.

- [ ] **Step 6: Commit governance/backlog updates**

Run:

```sh
git add packages/zigeffect/tools/causal_schema_governance.zig packages/zigeffect/tools/causal_production_hardening_backlog.zig
git commit -m "build(zigeffect): register production telemetry ci harness boundary"
```

## Task 5: Add User-Facing Docs

**Files:**
- Add: `packages/zigeffect/docs/production-telemetry-ci-harness-boundary.md`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/production-hardening-completion-audit.md`
- Modify: `packages/zigeffect/docs/production-telemetry-ci-artifact-preview.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Add the CI harness boundary docs page**

Create `packages/zigeffect/docs/production-telemetry-ci-harness-boundary.md` with sections:

- Overview
- Command
- Source evidence
- Workflow checks
- Clustering release-gate assumptions
- Status
- Output paths
- Agent guidance
- Verification
- Non-goals

The overview must say the tool consumes CI artifact preview evidence, inspects the existing workflow, and does not mutate `.github/workflows/zigeffect-causal.yml`.

- [ ] **Step 2: Update schema governance docs**

Add `zigeffect.causal.production-telemetry-ci-harness-boundary.v1` after the CI artifact preview entry, with `strict-v1`, `record-only`, `workflow-inspection`, `cluster-release-gate-aware`, `no-workflow-mutation`, and `mutation-authority-none` compatibility notes.

- [ ] **Step 3: Update backlog docs**

Regenerate or manually update the production hardening backlog docs to show:

- recommended next branch:
  `codex/zigeffect-causal-production-telemetry-ci-archive-application`;
- delivered `production-telemetry-ci-harness-boundary`;
- verification commands for approve and reject paths.

- [ ] **Step 4: Update operations, README, roadmap, and completion audit**

Add the command example and the interpretation rules:

- `ready` starts only the CI archive application branch.
- `ready` does not approve workflow mutation, artifact upload execution, CI gates, live telemetry, NenDB writes, durable writes, hosted dashboard claims, production cluster claims, or mutation authority.
- The boundary records that `zig build release-gate --summary none` is the clustering-aware CI execution body.

- [ ] **Step 5: Update master roadmap**

In `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`, mark item 23 delivered and add item 24:

```markdown
24. `codex/zigeffect-causal-production-telemetry-ci-archive-application`
   - Current next branch: use ready CI harness boundary evidence to propose
     and verify the smallest archive-only workflow application while keeping
     CI gates, live telemetry, durable writes, NenDB writes, hosted dashboard
     claims, production cluster claims, alternate renderers, and mutation
     authority disabled.
```

- [ ] **Step 6: Verify docs formatting**

Run:

```sh
git diff --check
```

Expected: no whitespace errors.

- [ ] **Step 7: Commit docs updates**

Run:

```sh
git add packages/zigeffect/docs/production-telemetry-ci-harness-boundary.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/docs/production-hardening-backlog.md \
  packages/zigeffect/docs/production-hardening-completion-audit.md \
  packages/zigeffect/docs/production-telemetry-ci-artifact-preview.md \
  packages/zigeffect/docs/operations.md \
  packages/zigeffect/docs/roadmap.md \
  packages/zigeffect/README.md \
  docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "docs(zigeffect): document production telemetry ci harness boundary"
```

## Task 6: Full Verification

**Files:**
- All modified files

- [ ] **Step 1: Run focused Zig tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_harness_boundary.zig
zig test tools/causal_schema_governance.zig
zig test tools/causal_production_hardening_backlog.zig
```

Expected: all pass.

- [ ] **Step 2: Run ready and blocked boundary generation**

Run the approve and reject commands from Task 3 Step 4.

Expected:

- approve output contains `ci_harness_boundary_status: ready`;
- reject output contains `ci_harness_boundary_status: blocked`;
- both outputs contain `ci upload execution enabled: false`, `ci workflow mutation enabled: false`, and `ci gate enabled: false`.

- [ ] **Step 3: Run governance and backlog commands**

Run:

```sh
cd packages/zigeffect
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

Expected:

- schema governance JSON includes `zigeffect.causal.production-telemetry-ci-harness-boundary.v1`;
- backlog JSON includes `"id": "production-telemetry-ci-harness-boundary"`;
- backlog JSON recommends `codex/zigeffect-causal-production-telemetry-ci-archive-application`.

- [ ] **Step 4: Run broad zigeffect checks**

Run:

```sh
cd packages/zigeffect
zig build examples
zig build test
```

Expected: both pass.

- [ ] **Step 5: Run repository checks**

Run:

```sh
bun run check
bun run zig:test
git diff --check
git status --short --branch
git merge-base --is-ancestor master HEAD
```

Expected:

- Bun checks pass.
- Zig aggregate test command passes.
- No whitespace errors.
- Worktree is clean except generated ignored artifacts.
- `git merge-base --is-ancestor master HEAD` exits `0`.

## Self-Review Checklist

- [ ] The implementation does not modify `.github/workflows/zigeffect-causal.yml`.
- [ ] The tool consumes `production-telemetry-ci-artifact-preview.v1`.
- [ ] The tool emits `production-telemetry-ci-harness-boundary.v1`.
- [ ] Ready output requires source preview readiness and workflow checks.
- [ ] Reject output is blocked.
- [ ] Prohibited workflow features block readiness.
- [ ] Upload execution, workflow mutation, CI gates, telemetry ingestion, durable writes, and NenDB writes remain disabled.
- [ ] Clustering release-gate assumptions are present in JSON and text reports.
- [ ] Schema governance includes the new schema.
- [ ] Production hardening backlog points to the archive application branch.
- [ ] Docs explain that `ready` starts only archive application work.
- [ ] All verification commands have fresh passing output before completion is claimed.
