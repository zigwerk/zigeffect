# Required Status Check Enforcement Report Application Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a record-only application-boundary tool that consumes required-status-check enforcement report artifacts and emits guarded plan or record-applied artifacts.

**Architecture:** Mirror `causal_production_telemetry_ci_gate_advisory_ci_report_application_boundary.zig`, adapted to the stricter required-status-check enforcement report schema and publication channels. The tool parses one source report artifact, validates source authority and publication boundaries, applies mode-specific evidence gates, and writes deterministic local JSON/text artifacts. Build, schema governance, backlog, operations docs, and roadmaps advance to the future report policy branch.

**Tech Stack:** Zig stdlib JSON parsing, Zig build steps, existing zigeffect causal report conventions, Bun root verification.

---

## File Structure

- Create `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary.zig`: CLI parser, source report model, application-boundary evaluator, JSON/text formatters, fixtures, and tests.
- Modify `packages/zigeffect/build.zig`: add executable step `causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary` and include tests in `zig build test`.
- Modify `packages/zigeffect/tools/causal_schema_governance.zig`: register schema `zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary.v1` and update schema count/tests from 77 to 78.
- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`: add delivered backlog item, move recommendation to report policy, and add positive/negative verification commands.
- Create `packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary.md`: command, modes, source contract, evidence gates, denied inferences, handoff, and verification.
- Modify `packages/zigeffect/README.md`, `packages/zigeffect/docs/operations.md`, `packages/zigeffect/docs/production-hardening-backlog.md`, `packages/zigeffect/docs/schema-governance.md`, `packages/zigeffect/docs/roadmap.md`, and `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`: mark the application boundary delivered and move active next work to the report policy branch.

## Task 1: Red Constants Test

**Files:**
- Create: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary.zig`

- [ ] **Step 1: Write the failing constants test**

Create the file with imports and this test only:

```zig
const std = @import("std");

test "required status check enforcement report application boundary constants are stable" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary.v1",
        production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary_schema,
    );
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary_schema_version);
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary",
        source_branch,
    );
    try std.testing.expectEqualStrings(
        "start-production-telemetry-ci-gate-required-status-check-enforcement-report-policy",
        recommendation,
    );
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy",
        next_branch_if_applied,
    );
}
```

- [ ] **Step 2: Run the red test**

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary.zig
```

Expected: FAIL with undeclared identifier errors for the constants.

## Task 2: Parser And Output Paths

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary.zig`

- [ ] **Step 1: Add constants and parser tests**

Add constants:

```zig
pub const production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary_schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary.v1";
pub const production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary";
pub const recommendation = "start-production-telemetry-ci-gate-required-status-check-enforcement-report-policy";
pub const next_branch_if_applied = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy";
```

Add tests:

```zig
test "parses required status check enforcement report application boundary plan options" {
    const options = try parseOptions(std.testing.allocator, &.{
        "tool",
        "--from-report",
        ".zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report.json",
        "plan",
        "--reason",
        "required status check enforcement report application boundary planned",
        "--by",
        "codex",
        "--policy",
        "manual-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary",
        "--out-prefix",
        ".zig-cache/causal-artifacts/custom-report-application-boundary",
    });
    defer options.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report.json", options.report_path);
    try std.testing.expectEqual(Mode.plan, options.mode);
    try std.testing.expectEqualStrings("required status check enforcement report application boundary planned", options.reason);
    try std.testing.expectEqualStrings("codex", options.reviewed_by);
    try std.testing.expectEqualStrings("manual-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary", options.policy);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-report-application-boundary", options.out_prefix.?);
}

test "parses required status check enforcement report application boundary record applied evidence" {
    const options = try parseOptions(std.testing.allocator, &.{
        "tool",
        "--from-report",
        "source.json",
        "record-applied",
        "--reason",
        "recorded",
        "--report-after",
        "after.txt",
        "--application-change",
        "reviewed application change",
        "--before",
        "before evidence",
        "--after",
        "after evidence",
        "--verified-command",
        "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report",
    });
    defer options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Mode.record_applied, options.mode);
    try std.testing.expectEqualStrings("after.txt", options.report_after_path.?);
    try std.testing.expectEqual(@as(usize, 1), options.application_changes.len);
    try std.testing.expectEqual(@as(usize, 1), options.before_evidence.len);
    try std.testing.expectEqual(@as(usize, 1), options.after_evidence.len);
    try std.testing.expectEqual(@as(usize, 1), options.verified_commands.len);
}

test "required status check enforcement report application boundary rejects invalid options" {
    try std.testing.expectError(error.InvalidReportPath, parseOptions(std.testing.allocator, &.{ "tool", "--from-report", "source.txt", "plan", "--reason", "planned" }));
    try std.testing.expectError(error.UnknownMode, parseOptions(std.testing.allocator, &.{ "tool", "--from-report", "source.json", "apply", "--reason", "planned" }));
    try std.testing.expectError(error.MissingReason, parseOptions(std.testing.allocator, &.{ "tool", "--from-report", "source.json", "plan" }));
    try std.testing.expectError(error.InvalidReportAfterPath, parseOptions(std.testing.allocator, &.{ "tool", "--from-report", "source.json", "record-applied", "--reason", "recorded", "--report-after", "after.html" }));
}

test "default output path replaces enforcement report suffix" {
    const options = Options{
        .report_path = "../../.zig-cache/causal-artifacts/example-ci-gate-required-status-check-enforcement-report.json",
        .mode = .plan,
        .reason = "planned",
    };
    const paths = try outputPathsForOptions(std.testing.allocator, options);
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("../../.zig-cache/causal-artifacts/example-ci-gate-required-status-check-enforcement-report-application-boundary.json", paths.json_path);
    try std.testing.expectEqualStrings("../../.zig-cache/causal-artifacts/example-ci-gate-required-status-check-enforcement-report-application-boundary.txt", paths.text_path);
}
```

- [ ] **Step 2: Implement parser and output paths**

Implement:

```zig
const Mode = enum { plan, record_applied };
const ReportApplicationBoundaryStatus = enum { planned, applied, blocked };
const CheckStatus = enum { pass, fail, skipped };

const Options = struct {
    report_path: []const u8,
    mode: Mode,
    reviewed_by: []const u8 = "ci-gate-required-status-check-enforcement-report-application-boundary-reviewer",
    policy: []const u8 = "manual-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary",
    reason: []const u8,
    report_after_path: ?[]const u8 = null,
    application_changes: []const []const u8 = &.{},
    before_evidence: []const []const u8 = &.{},
    after_evidence: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
    out_prefix: ?[]const u8 = null,
};
```

Parser command:

```sh
--from-report <required-status-check-enforcement-report.json> plan|record-applied --reason <reason> [--report-after <report.txt|report.md|report.json>] [--by <actor>] [--policy <policy>] [--application-change <evidence>] [--before <evidence>] [--after <evidence>] [--verified-command <command>]... [--out-prefix <path-prefix>]
```

Use output suffix `-ci-gate-required-status-check-enforcement-report-application-boundary`.

- [ ] **Step 3: Verify parser tests**

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary.zig
```

Expected: constants, parser, and output-path tests pass.

## Task 3: Evaluation And Formatting

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary.zig`

- [ ] **Step 1: Add source model and behavior tests**

Add structs matching the source report JSON:

```zig
const SourceCheck = struct {
    name: []const u8 = "",
    status: []const u8,
    detail: []const u8 = "",
};

const SourcePublicationChannel = struct {
    id: []const u8,
    allowed: bool = false,
    executed_by_tool: bool = false,
    detail: []const u8 = "",
};

const SourceReportArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_evaluator: []const u8 = "",
    source_evaluator_status: []const u8 = "",
    required_status_check_enforcement_report_status: []const u8,
    ready_for_next_branch: bool,
    ci_gate_enabled: bool = false,
    ci_gate_enforcement_enabled: bool = false,
    ci_required_status_check_enabled: bool = false,
    ci_workflow_mutation_enabled: bool = false,
    ci_upload_execution_enabled: bool = false,
    ci_report_publication_enabled: bool = false,
    github_api_mutation_enabled: bool = false,
    github_check_run_creation_enabled: bool = false,
    branch_protection_mutation_by_tool_enabled: bool = false,
    github_step_summary_write_enabled: bool = false,
    pull_request_comment_enabled: bool = false,
    production_telemetry_ingestion: bool = false,
    live_exporter_enabled: bool = false,
    network_send_enabled: bool = false,
    collector_endpoint_configured: bool = false,
    otlp_serialization_enabled: bool = false,
    runtime_pipeline_enabled: bool = false,
    durable_write_enabled: bool = false,
    nendb_write_enabled: bool = false,
    mutation_authority: []const u8 = "",
    publication_channels: []const SourcePublicationChannel = &.{},
    checks: []const SourceCheck = &.{},
    blocked_claims: []const []const u8 = &.{},
    required_verification_commands: []const []const u8 = &.{},
    generated_by: []const u8 = "",
    source_branch: []const u8 = "",
    recommendation: []const u8 = "",
    next_branch_if_ready: []const u8 = "",
    agent_guidance: []const []const u8 = &.{},
};
```

Add tests for:

- plan mode with ready/advisory source emits `planned`, `applied=false`, and `mutation_authority="none"`;
- record-applied with full evidence emits `applied`, `applied=true`, and `mutation_authority="record-only"`;
- blocked source report emits `blocked` and preserves `applied=false`;
- record-applied without after report/evidence stays blocked;
- unsafe after report markers stay blocked;
- source authority or publication channel violation stays blocked.

- [ ] **Step 2: Implement evaluation checks**

Implement checks:

- `source-report-schema`
- `source-report-status`
- `source-application-disabled`
- `source-authority-disabled`
- `source-publication-channels-carried`
- `source-checks-passed`
- `source-blocked-claims-carried`
- `source-verification-recorded`
- `plan-is-not-applied`
- `application-change-present`
- `before-evidence-present`
- `after-evidence-present`
- `post-verification-recorded`
- `after-report-present`
- `after-report-safe`

Plan mode returns `planned` when no source check fails. Record-applied returns
`applied` only when every check is `pass`; otherwise it returns `blocked`.

- [ ] **Step 3: Implement JSON/text formatters**

JSON must include:

```json
{
  "schema": "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary.v1",
  "schema_version": 1,
  "source_enforcement_report": "...",
  "source_report_status": "ready",
  "mode": "plan",
  "report_application_boundary_status": "planned",
  "applied": false,
  "mutation_authority": "none",
  "application_checks": [],
  "application_boundary_rules": [],
  "denied_application_claims": [],
  "negative_fixtures": [],
  "required_verification_commands": [],
  "verified_commands": [],
  "recommendation": "start-production-telemetry-ci-gate-required-status-check-enforcement-report-policy",
  "next_branch_if_applied": "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy"
}
```

Text must include the schema, source report path, mode, status, applied flag,
mutation authority, checks, evidence lists, denied claims, required commands,
verified commands, and agent guidance.

- [ ] **Step 4: Verify behavior tests**

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary.zig
```

Expected: all tool tests pass.

## Task 4: Build, Schema, Backlog, And Docs Wiring

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Create: `packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Add build step and tests**

Add a module/executable/test block in `build.zig` after the enforcement report tool:

```zig
const causal_production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary.zig"),
    .target = target,
    .optimize = optimize,
});
```

Use executable name
`zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary`
and step name
`causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary`.

- [ ] **Step 2: Register schema governance**

Add schema entry:

```zig
.{
    .schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary.v1",
    .version = 1,
    .category = "production-hardening",
    .status = "current",
    .emitted_by = &.{"causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary"},
    .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry CI gate required status check enforcement report policy" },
    .compatibility = &.{ "strict-v1", "record-only", "report-application-boundary", "plan-or-record-applied", "before-after-verification", "local-artifact-only", "required-status-check-evidence", "branch-protection-evidence", "no-tool-github-api-mutation", "no-tool-branch-protection-mutation", "no-tool-workflow-mutation", "no-tool-check-run-creation", "no-tool-ci-upload", "no-tool-github-step-summary-write", "no-tool-pr-comment", "no-live-ingestion", "no-durable-write", "no-nendb-write" },
    .governance_requirements = &.{ "source report checks", "plan mode tests", "record-applied evidence tests", "after-report safety tests", "denied authority tests", "next-branch report policy handoff" },
},
```

Update schema count expectations from 77 to 78 and add text/JSON tests for the
new schema.

- [ ] **Step 3: Update production hardening backlog**

Update constants:

```zig
pub const recommendation = "start-production-telemetry-ci-gate-required-status-check-enforcement-report-policy";
pub const recommended_next_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy";
```

Add delivered item
`production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary`
after the enforcement report item. Add verification commands for plan and
negative record-applied. Update tests for text/JSON recommendation and item
presence.

- [ ] **Step 4: Update docs and roadmaps**

Create the application-boundary doc with command examples, modes, source
contract, record-applied evidence requirements, denied inferences, handoff, and
verification. Update README, operations, production-hardening-backlog,
schema-governance, roadmap, and master roadmap to mark this branch delivered
and make report policy the current next branch.

- [ ] **Step 5: Format Zig files**

```sh
cd packages/zigeffect
zig fmt build.zig \
  tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary.zig \
  tools/causal_schema_governance.zig \
  tools/causal_production_hardening_backlog.zig
```

## Task 5: Verification And Commit

**Files:**
- All modified files from Tasks 1-4.

- [ ] **Step 1: Run focused verification**

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary -- --help
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary -- \
  --from-report ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report.json \
  plan \
  --reason "required status check enforcement report application boundary planned"
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary -- \
  --from-report ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report-negative.json \
  record-applied \
  --reason "negative required status check enforcement report application boundary path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary-negative
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

Expected: all commands exit 0. The plan command may emit `blocked` if the
current source report artifact is blocked; the important behavior is that it
writes a local blocked artifact and keeps `applied=false`.

- [ ] **Step 2: Run full verification**

```sh
cd packages/zigeffect
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
cd packages/zigeffect
zig fmt --check build.zig \
  tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary.zig \
  tools/causal_schema_governance.zig \
  tools/causal_production_hardening_backlog.zig
cd ../..
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 3: Commit**

```sh
git add docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md \
  packages/zigeffect/README.md \
  packages/zigeffect/build.zig \
  packages/zigeffect/docs/operations.md \
  packages/zigeffect/docs/production-hardening-backlog.md \
  packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary.md \
  packages/zigeffect/docs/roadmap.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary.zig \
  packages/zigeffect/tools/causal_schema_governance.zig
git commit -m "feat(zigeffect): add required status check enforcement report application boundary"
```
