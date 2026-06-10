# Required Status Check Enforcement Report Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a record-only report tool that consumes required-status-check enforcement evaluator artifacts and emits local JSON/text reports for reviewer and agent handoff.

**Architecture:** Follow the delivered advisory CI report pattern: parse one source evaluator artifact, evaluate schema/status/authority/section checks, then render JSON and text reports with local-only publication channels. Wire the tool into `build.zig`, register a governed schema, update the production-hardening backlog, and document the next handoff to a report application-boundary branch.

**Tech Stack:** Zig stdlib JSON parsing/string formatting/file IO, zigeffect package build steps, existing causal schema governance and production hardening backlog tools, Bun root verification.

---

## File Structure

- Create `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report.zig`: executable, CLI parser, source evaluator model, report evaluator, JSON/text formatters, fixtures, and tests.
- Modify `packages/zigeffect/build.zig`: add executable step `causal-production-telemetry-ci-gate-required-status-check-enforcement-report` and include its tests in `zig build test`.
- Modify `packages/zigeffect/tools/causal_schema_governance.zig`: register schema `zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report.v1` and update schema count/tests from 76 to 77.
- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`: add delivered report item, move recommendation to the report application-boundary branch, and add positive/negative verification commands.
- Create `packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-enforcement-report.md`: command, source contract, statuses, publication boundary, handoff, and verification.
- Modify `packages/zigeffect/README.md`, `packages/zigeffect/docs/operations.md`, `packages/zigeffect/docs/production-hardening-backlog.md`, `packages/zigeffect/docs/schema-governance.md`, `packages/zigeffect/docs/roadmap.md`, and `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`: mark the report delivered and move active next work to the report application-boundary branch.

## Task 1: Red Constants Test

**Files:**
- Create: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report.zig`

- [ ] **Step 1: Write the failing constants test**

Create the file with imports and this test only:

```zig
const std = @import("std");

test "required status check enforcement report constants are stable" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report.v1",
        production_telemetry_ci_gate_required_status_check_enforcement_report_schema,
    );
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_ci_gate_required_status_check_enforcement_report_schema_version);
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report",
        source_branch,
    );
    try std.testing.expectEqualStrings(
        "start-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary",
        recommendation,
    );
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary",
        next_branch_if_ready,
    );
}
```

- [ ] **Step 2: Run the red test**

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report.zig
```

Expected: FAIL with undeclared identifier errors for the constants.

## Task 2: CLI Parser and Output Paths

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report.zig`

- [ ] **Step 1: Add constants and parser tests**

Add constants:

```zig
pub const production_telemetry_ci_gate_required_status_check_enforcement_report_schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report.v1";
pub const production_telemetry_ci_gate_required_status_check_enforcement_report_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report";
pub const recommendation = "start-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary";
```

Add tests:

```zig
test "parses required status check enforcement report options" {
    const options = try parseOptions(&.{
        "zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report",
        "--from-evaluator",
        ".zig-cache/causal-artifacts/example-ci-gate-required-status-check-enforcement-evaluator.json",
        "summarize",
        "--reason",
        "required status check enforcement report reviewed",
        "--by",
        "codex",
        "--policy",
        "manual-production-telemetry-ci-gate-required-status-check-enforcement-report",
        "--out-prefix",
        ".zig-cache/causal-artifacts/custom-required-status-check-enforcement-report",
    });

    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/example-ci-gate-required-status-check-enforcement-evaluator.json", options.evaluator_path);
    try std.testing.expectEqualStrings("required status check enforcement report reviewed", options.reason);
    try std.testing.expectEqualStrings("codex", options.reviewed_by);
    try std.testing.expectEqualStrings("manual-production-telemetry-ci-gate-required-status-check-enforcement-report", options.policy);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-required-status-check-enforcement-report", options.out_prefix.?);
}

test "required status check enforcement report rejects invalid options" {
    try std.testing.expectError(error.InvalidEvaluatorPath, parseOptions(&.{ "tool", "--from-evaluator", "source.txt", "summarize", "--reason", "reviewed" }));
    try std.testing.expectError(error.UnknownCommand, parseOptions(&.{ "tool", "--from-evaluator", "source.json", "evaluate", "--reason", "reviewed" }));
    try std.testing.expectError(error.MissingReason, parseOptions(&.{ "tool", "--from-evaluator", "source.json", "summarize" }));
}

test "default output path replaces enforcement evaluator suffix" {
    const options = Options{
        .evaluator_path = "../../.zig-cache/causal-artifacts/example-ci-gate-required-status-check-enforcement-evaluator.json",
        .reason = "planned",
    };
    const paths = try outputPathsForOptions(std.testing.allocator, options);
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("../../.zig-cache/causal-artifacts/example-ci-gate-required-status-check-enforcement-report.json", paths.json_path);
    try std.testing.expectEqualStrings("../../.zig-cache/causal-artifacts/example-ci-gate-required-status-check-enforcement-report.txt", paths.text_path);
}
```

- [ ] **Step 2: Implement parser and path helpers**

Implement `Options`, `OutputPaths`, `parseOptions`, `outputPathsForOptions`,
`usage`, and `failUsage`. The parser must accept:

```sh
--from-evaluator source.json summarize --reason "reviewed" [--by codex] [--policy policy-id] [--out-prefix out/report]
```

The default `reviewed_by` is
`ci-gate-required-status-check-enforcement-report`. The default `policy` is
`manual-production-telemetry-ci-gate-required-status-check-enforcement-report`.

- [ ] **Step 3: Verify parser tests**

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report.zig
```

Expected: constants, parser, and output-path tests pass.

## Task 3: Report Evaluation and Formatting

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report.zig`

- [ ] **Step 1: Add source model, statuses, and report tests**

Define:

```zig
const source_evaluator_schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-evaluator.v1";
const generated_by = "causal-production-telemetry-ci-gate-required-status-check-enforcement-report";
const max_source_bytes = 1024 * 1024;
const mutation_authority = "none";

const ReportStatus = enum { ready, advisory, blocked };
const CheckStatus = enum { pass, fail };
```

Add tests for:

- ready evaluator -> `required_status_check_enforcement_report_status="ready"` and `ready_for_next_branch=true`;
- advisory evaluator -> report status `advisory`;
- blocked evaluator -> report status `blocked`, `ready_for_next_branch=false`, and blocked findings preserved;
- source authority violation -> report status `blocked`;
- publication channels remain local-only and record-only.

- [ ] **Step 2: Implement source evaluator structs**

Use these structs:

```zig
const SourceEvidenceFile = struct {
    path: []const u8 = "",
    class: []const u8 = "",
    size_bytes: usize = 0,
    sha256: []const u8 = "",
    detected_schema: []const u8 = "",
    denied_reason: []const u8 = "",
};

const SourceSignal = struct {
    id: []const u8,
    status: []const u8,
    detail: []const u8 = "",
    evidence_path: []const u8 = "",
};

const SourceFinding = struct {
    id: []const u8,
    severity: []const u8,
    signal: []const u8 = "",
    detail: []const u8 = "",
    evidence_path: []const u8 = "",
};

const SourceCheck = struct {
    name: []const u8,
    status: []const u8,
    detail: []const u8 = "",
};

const EvaluatorArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_enforcement_policy: []const u8 = "",
    source_policy_status: []const u8 = "",
    source_policy_ready_for_next_branch: bool = false,
    source_active_enforcement_policy_ready: bool = false,
    source_merge_blocker_policy_ready: bool = false,
    required_status_check_enforcement_evaluator_status: []const u8,
    ready_for_next_branch: bool,
    blocked_findings_count: usize = 0,
    advisory_findings_count: usize = 0,
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
    evidence_files: []const SourceEvidenceFile = &.{},
    checks: []const SourceCheck = &.{},
    signal_evaluations: []const SourceSignal = &.{},
    findings: []const SourceFinding = &.{},
    blocked_claims: []const []const u8 = &.{},
    required_verification_commands: []const []const u8 = &.{},
    generated_by: []const u8 = "",
};
```

- [ ] **Step 3: Implement evaluation checks**

`evaluateReport` must append these checks:

- `source-evaluator-schema`
- `source-evaluator-reportable`
- `source-ready-for-next-branch`
- `source-no-blocked-findings`
- `source-disabled-authority`
- `source-report-sections-present`
- `report-publication-record-only`

Status rules:

```zig
const status: ReportStatus = if (!allChecksPassed(check_slice))
    .blocked
else if (std.mem.eql(u8, source.required_status_check_enforcement_evaluator_status, "advisory-findings") or source.advisory_findings_count > 0 or countFindings(source.findings, "advisory") > 0)
    .advisory
else
    .ready;
```

- [ ] **Step 4: Implement JSON and text formatting**

JSON must include the fields listed in the design spec. Text must include:

- schema;
- headline;
- source evaluator path and status;
- report status and readiness;
- mutation authority;
- disabled local publication/mutation booleans;
- signals;
- blocked findings;
- advisory findings;
- evidence summary;
- checks;
- blocked claims;
- publication channels;
- required verification commands;
- agent guidance.

- [ ] **Step 5: Implement file IO and main**

Read the source evaluator with `std.Io.Dir.cwd().readFileAlloc(... .limited(max_source_bytes))`, write reports with `writeArtifact`, and print the text report.

- [ ] **Step 6: Verify report tests**

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report.zig
```

Expected: all report tool tests pass.

## Task 4: Build Wiring

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add build target**

After the enforcement evaluator build block, add module, executable, run step,
and test wiring for:

```zig
tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report.zig
```

Build step name:

```text
causal-production-telemetry-ci-gate-required-status-check-enforcement-report
```

Executable name:

```text
zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report
```

- [ ] **Step 2: Verify build help and test wiring**

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report -- --help
zig build test
```

Expected: help prints usage and `zig build test` includes the report tests.

## Task 5: Schema Governance and Backlog

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`

- [ ] **Step 1: Register report schema**

Add schema entry:

```zig
.{
    .schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report.v1",
    .version = 1,
    .category = "production-hardening",
    .status = "current",
    .emitted_by = &.{"causal-production-telemetry-ci-gate-required-status-check-enforcement-report"},
    .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry CI gate required status check enforcement report application boundary" },
    .compatibility = &.{ "strict-v1", "record-only", "required-status-check-enforcement-report", "reviewer-guidance", "local-artifact-only", "blocked-finding-preserving", "no-tool-github-api-mutation", "no-tool-branch-protection-mutation", "no-tool-workflow-mutation", "no-tool-check-run-creation", "no-tool-ci-upload", "no-github-step-summary-write", "no-pr-comment", "no-live-ingestion", "no-durable-write", "no-nendb-write" },
    .governance_requirements = &.{ "source enforcement evaluator checks", "blocked finding preservation tests", "publication boundary tests", "denied authority tests", "next-branch report application-boundary handoff" },
},
```

Update schema count tests from `76` to `77` and add text/JSON expectations for
the new schema.

- [ ] **Step 2: Update backlog recommendation and item**

Set:

```zig
pub const recommendation = "start-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary";
pub const recommended_next_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary";
```

Add delivered item `production-telemetry-ci-gate-required-status-check-enforcement-report` after the evaluator item, depending on the evaluator, artifact access control, and NenDB retention fixtures.

Add report positive/negative CLI commands to `verification_commands`.

- [ ] **Step 3: Verify governance and backlog**

```sh
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog.zig
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

Expected: schema count is `77`; backlog recommends the report application-boundary branch.

## Task 6: Documentation Updates

**Files:**
- Create: `packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-enforcement-report.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Add report doc**

Create a doc with sections:

- schema;
- purpose;
- command;
- source evaluator contract;
- statuses;
- publication boundary;
- handoff;
- verification.

State explicitly that it does not mutate GitHub, branch protection, workflows,
check runs, CI uploads, step summaries, PR comments, live telemetry, durable
stores, NenDB, non-NenDB adapters, renderers, production systems, or mutation
authority.

- [ ] **Step 2: Update existing docs**

Add report command examples and move active next branch references from
`...enforcement-report` to `...enforcement-report-application-boundary` in
active backlog/operations/roadmap docs. Historical design and implementation
plans may keep previous handoff references.

- [ ] **Step 3: Stale-reference scan**

```sh
rg -n 'recommended next branch: codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report|recommended_next_branch.*enforcement-report"' packages/zigeffect docs/superpowers
```

Expected: active generated docs/backlog point to
`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary`; historical plans/specs may still mention the report branch as the previous next branch.

## Task 7: Focused and Full Verification

**Files:**
- All modified files

- [ ] **Step 1: Run focused verification**

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report -- --help
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report -- \
  --from-evaluator ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-evaluator.json \
  summarize \
  --reason "required status check enforcement report reviewed"
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report -- \
  --from-evaluator ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-evaluator-negative.json \
  summarize \
  --reason "negative required status check enforcement report path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report-negative
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

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
  tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report.zig \
  tools/causal_schema_governance.zig \
  tools/causal_production_hardening_backlog.zig
cd ../..
git diff --check
```

- [ ] **Step 3: Commit implementation**

```sh
git add \
  docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md \
  packages/zigeffect/README.md \
  packages/zigeffect/build.zig \
  packages/zigeffect/docs/operations.md \
  packages/zigeffect/docs/production-hardening-backlog.md \
  packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-enforcement-report.md \
  packages/zigeffect/docs/roadmap.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report.zig \
  packages/zigeffect/tools/causal_schema_governance.zig
git diff --cached --check
git commit -m "feat(zigeffect): add required status check enforcement report"
```

Expected: one implementation commit on
`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report`.
