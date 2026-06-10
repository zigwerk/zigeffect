# Production Telemetry CI Gate Dry-Run Evaluator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `causal-production-telemetry-ci-gate-dry-run-evaluator`, a bounded advisory evaluator for ready CI gate dry-run policy artifacts and explicit local/CI evidence files.

**Architecture:** Add one Zig tool that follows the existing production telemetry artifact-chain pattern: parse a source artifact, parse options, classify bounded evidence files, evaluate fixed advisory signals, render deterministic JSON/text reports, and write artifacts. Wire it into `packages/zigeffect/build.zig`, register its schema, update backlog/docs/roadmaps, and keep all enforcement/mutation/live/durable flags disabled.

**Tech Stack:** Zig 0.16.0, `std.json`, `std.crypto.hash.sha2.Sha256`, existing zigeffect build steps, Bun root verification.

---

## File Structure

- Create `packages/zigeffect/tools/causal_production_telemetry_ci_gate_dry_run_evaluator.zig`
  - CLI parsing, policy parsing, evidence classification, signal evaluation,
    report rendering, file IO, and tests.
- Modify `packages/zigeffect/build.zig`
  - Add executable, build step, and test integration after the dry-run policy
    tool.
- Modify `packages/zigeffect/tools/causal_schema_governance.zig`
  - Add schema entry and update schema count from 65 to 66.
- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
  - Mark evaluator delivered and recommend the advisory CI report branch.
- Create `packages/zigeffect/docs/production-telemetry-ci-gate-dry-run-evaluator.md`
  - Document command, evidence boundaries, signal semantics, output fields,
    and verification.
- Modify these docs:
  - `packages/zigeffect/README.md`
  - `packages/zigeffect/docs/schema-governance.md`
  - `packages/zigeffect/docs/operations.md`
  - `packages/zigeffect/docs/production-hardening-backlog.md`
  - `packages/zigeffect/docs/production-hardening-completion-audit.md`
  - `packages/zigeffect/docs/m9-completion-audit.md`
  - `packages/zigeffect/docs/load-test-observation-harness.md`
  - `packages/zigeffect/docs/production-telemetry-capture-design.md`
  - `packages/zigeffect/docs/production-telemetry-capture-fixtures.md`
  - `packages/zigeffect/docs/production-telemetry-ci-gate-dry-run-policy.md`
  - `packages/zigeffect/docs/roadmap.md`
  - `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

## Task 1: Create the Red Test

**Files:**
- Create: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_dry_run_evaluator.zig`

- [ ] **Step 1: Add the failing constants test**

Create the file with only this test and import:

```zig
const std = @import("std");

test "ci gate dry-run evaluator schema and branch constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-ci-gate-dry-run-evaluator.v1", production_telemetry_ci_gate_dry_run_evaluator_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_ci_gate_dry_run_evaluator_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-dry-run-evaluator", source_branch);
    try std.testing.expectEqualStrings("start-production-telemetry-ci-gate-advisory-ci-report", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report", next_branch_if_ready);
}
```

- [ ] **Step 2: Run the test and confirm RED**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_dry_run_evaluator.zig
```

Expected: fail with `use of undeclared identifier 'production_telemetry_ci_gate_dry_run_evaluator_schema'`.

## Task 2: Implement Constants, CLI, Source Types, and Output Paths

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_dry_run_evaluator.zig`

- [ ] **Step 1: Add constants and disabled authority flags**

Add:

```zig
pub const production_telemetry_ci_gate_dry_run_evaluator_schema = "zigeffect.causal.production-telemetry-ci-gate-dry-run-evaluator.v1";
pub const production_telemetry_ci_gate_dry_run_evaluator_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-dry-run-evaluator";
pub const recommendation = "start-production-telemetry-ci-gate-advisory-ci-report";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report";

const dry_run_policy_schema = "zigeffect.causal.production-telemetry-ci-gate-dry-run-policy.v1";
const generated_by = "causal-production-telemetry-ci-gate-dry-run-evaluator";

const ci_gate_enabled = false;
const ci_gate_enforcement_enabled = false;
const ci_required_status_check_enabled = false;
const ci_workflow_mutation_enabled = false;
const ci_upload_execution_enabled = false;
const production_telemetry_ingestion = false;
const live_exporter_enabled = false;
const network_send_enabled = false;
const collector_endpoint_configured = false;
const otlp_serialization_enabled = false;
const runtime_pipeline_enabled = false;
const durable_write_enabled = false;
const nendb_write_enabled = false;
```

- [ ] **Step 2: Add option parsing types**

Add:

```zig
const Action = enum { evaluate };
const EvaluationStatus = enum { ready, advisory_findings, blocked };
const SignalStatus = enum { observed, missing, blocked };
const Severity = enum { info, advisory, blocked };
const CheckStatus = enum { pass, fail };

const Options = struct {
    dry_run_policy_path: []const u8,
    action: Action,
    reviewed_by: []const u8 = "ci-gate-dry-run-evaluator",
    policy: []const u8 = "manual-production-telemetry-ci-gate-dry-run-evaluator",
    reason: []const u8,
    evidence_paths: []const []const u8 = &.{},
    out_prefix: ?[]const u8 = null,

    fn deinit(self: Options, allocator: std.mem.Allocator) void {
        if (self.evidence_paths.len > 0) allocator.free(self.evidence_paths);
    }
};
```

Implement `parseOptions` for:

```text
--from-dry-run-policy <dry-run-policy.json> evaluate --reason <reason> --evidence <path>... [--by <actor>] [--policy <policy>] [--out-prefix <path-prefix>]
```

Return `error.MissingEvidence` when no `--evidence` values are supplied.

- [ ] **Step 3: Add source policy structs**

Add structs that parse these fields from the policy artifact:

```zig
const SourceCheck = struct {
    name: []const u8 = "",
    id: []const u8 = "",
    status: []const u8,
    detail: []const u8 = "",
};

const CandidateSignalPolicy = struct {
    id: []const u8 = "",
    evaluation_mode: []const u8 = "",
    enforcement_enabled: bool = true,
    required_status_check_enabled: bool = true,
    failure_effect: []const u8 = "",
    evidence: []const u8 = "",
    blocked_claim: []const u8 = "",
};

const EvidenceRequirement = struct {
    id: []const u8 = "",
    allowed: bool = false,
    detail: []const u8 = "",
};

const DryRunPolicyArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_boundary_status: []const u8 = "",
    source_boundary_mode: []const u8 = "",
    source_boundary_mutation_authority: []const u8 = "",
    decision: []const u8,
    dry_run_policy_status: []const u8,
    ready_for_next_branch: bool,
    ci_gate_enabled: bool,
    ci_gate_enforcement_enabled: bool,
    ci_required_status_check_enabled: bool,
    ci_workflow_mutation_enabled: bool,
    ci_upload_execution_enabled: bool,
    production_telemetry_ingestion: bool,
    live_exporter_enabled: bool,
    network_send_enabled: bool,
    collector_endpoint_configured: bool,
    otlp_serialization_enabled: bool,
    runtime_pipeline_enabled: bool,
    durable_write_enabled: bool,
    nendb_write_enabled: bool,
    candidate_signal_policies: []const CandidateSignalPolicy = &.{},
    evidence_requirements: []const EvidenceRequirement = &.{},
    checks: []const SourceCheck = &.{},
    blocked_claims: []const []const u8 = &.{},
};
```

- [ ] **Step 4: Add output path replacement**

Implement `outputPathsForOptions` so:

```zig
../../.zig-cache/causal-artifacts/example-ci-gate-dry-run-policy.json
```

produces:

```zig
../../.zig-cache/causal-artifacts/example-ci-gate-dry-run-evaluator.json
../../.zig-cache/causal-artifacts/example-ci-gate-dry-run-evaluator.txt
```

- [ ] **Step 5: Run the focused test**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_dry_run_evaluator.zig
```

Expected: the constants test passes.

## Task 3: Implement Evidence Classification and Boundary Checks

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_dry_run_evaluator.zig`

- [ ] **Step 1: Add evidence types**

Add:

```zig
const EvidenceClass = enum {
    causal_json,
    causal_text,
    release_gate_json,
    release_gate_text,
    ci_handoff,
    source_policy,
    denied,
};

const EvidenceFile = struct {
    path: []const u8,
    class: EvidenceClass,
    bytes: usize,
    sha256: []const u8,
    parse_status: []const u8,
    allowed: bool,
    detail: []const u8,
};
```

- [ ] **Step 2: Add path classification helpers**

Implement:

```zig
fn pathAllowed(path: []const u8) bool
fn classifyEvidencePath(path: []const u8, contents: []const u8) EvidenceClass
fn evidenceClassText(class: EvidenceClass) []const u8
```

`pathAllowed` returns true when the path contains `.zig-cache/causal-artifacts/`
or `.zig-cache/release-gate/` and ends in `.json` or `.txt`.

- [ ] **Step 3: Add denied marker helpers**

Implement:

```zig
fn hasDeniedEvidenceMarker(contents: []const u8) bool
fn deniedEvidenceReason(contents: []const u8) []const u8
```

Denied markers are the exact markers from the design:
`secrets.`, `PRODUCTION_`, `BEGIN PRIVATE KEY`, `Authorization:`, `sk-`,
`ghp_`, `xoxb-`, `required_status_check`,
`"ci_required_status_check_enabled": true`,
`"ci_gate_enforcement_enabled": true`,
`"ci_workflow_mutation_enabled": true`,
`"ci_upload_execution_enabled": true`,
`"live_exporter_enabled": true`, `"network_send_enabled": true`,
`"collector_endpoint_configured": true`,
`"otlp_serialization_enabled": true`,
`"runtime_pipeline_enabled": true`, `"durable_write_enabled": true`,
`"nendb_write_enabled": true`, `durable_adapter=non-nendb`,
`"durable_adapter": "non-nendb"`, `retention-days: 15`,
`"retention_days": 15`, `renderer=react`, and `"renderer": "react"`.

- [ ] **Step 4: Add evidence loading**

Implement:

```zig
fn readEvidenceFiles(io: std.Io, allocator: std.mem.Allocator, paths: []const []const u8) ![]const EvidenceFile
```

Each file uses `readFileAlloc` with `.limited(1024 * 1024)`. Reject more than
32 paths with `error.TooManyEvidenceFiles`. Store SHA-256 as `sha256:<hex>`.

- [ ] **Step 5: Add tests**

Add tests named:

```zig
test "parses evaluator options with multiple evidence files"
test "default output path replaces dry-run policy suffix"
test "classifies bounded release-gate causal and handoff evidence"
test "denied markers block evidence classification"
```

- [ ] **Step 6: Run focused tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_dry_run_evaluator.zig
```

Expected: all tests pass.

## Task 4: Implement Signal Evaluation and Report Rendering

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_dry_run_evaluator.zig`

- [ ] **Step 1: Add result structs**

Add:

```zig
const EvaluatorCheck = struct {
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
};

const SignalEvaluation = struct {
    id: []const u8,
    status: SignalStatus,
    severity: Severity,
    evidence_path: []const u8,
    finding_id: []const u8,
    detail: []const u8,
    next_queries: []const []const u8,
};

const Finding = struct {
    id: []const u8,
    signal_id: []const u8,
    severity: Severity,
    summary: []const u8,
    evidence_path: []const u8,
    blocked_claim: []const u8,
    next_queries: []const []const u8,
};

const EvaluationResult = struct {
    status: EvaluationStatus,
    ready_for_next_branch: bool,
    advisory_findings_count: usize,
    blocked_findings_count: usize,
    checks: []const EvaluatorCheck,
    signals: []const SignalEvaluation,
    findings: []const Finding,
};
```

- [ ] **Step 2: Add source policy validation**

Implement:

```zig
fn sourcePolicyValid(source: DryRunPolicyArtifact) bool
fn sourceAuthorityDisabled(source: DryRunPolicyArtifact) bool
fn sourceChecksPassed(checks: []const SourceCheck) bool
```

Validation follows the design source policy contract.

- [ ] **Step 3: Add signal evaluation**

Implement:

```zig
fn evaluateSignals(allocator: std.mem.Allocator, source: DryRunPolicyArtifact, evidence: []const EvidenceFile) !EvaluationResult
```

Rules:

- Block if source policy invalid.
- Block if any evidence file has `allowed=false`.
- `release-gate-artifact-present` observed when any evidence class is
  `release_gate_json` or `release_gate_text`.
- `causal-artifact-schema-parse` observed when any evidence class is
  `causal_json`.
- `archive-policy-conformance` observed when every evidence file is allowed.
- `redaction-retention-conformance` observed when every evidence file is
  allowed and no denied marker exists.
- `ci-handoff-present` observed when any evidence class is `ci_handoff`.
  Missing handoff evidence is advisory.
- `boundary-source-valid` observed when the source policy is valid.

Missing evidence creates an advisory finding with id
`advisory-<signal-id>`. Blocked evidence creates a blocked finding with id
`blocked-<signal-id>`.

- [ ] **Step 4: Add JSON and text renderers**

Render the output schema from the design. Include:

- source policy fields
- disabled authority flags
- evidence files
- signal evaluations
- findings
- next queries
- checks
- blocked claims
- recommendation and next branch

- [ ] **Step 5: Add ready/advisory/blocked report tests**

Add tests named:

```zig
test "ready evaluator report observes release gate causal schema handoff and boundary signals"
test "missing handoff evidence produces advisory findings without blocking next branch"
test "invalid source policy blocks evaluator readiness"
test "denied evidence marker blocks evaluator readiness"
```

- [ ] **Step 6: Run focused tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_dry_run_evaluator.zig
```

Expected: all evaluator tests pass.

## Task 5: Wire Build Step

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add the tool module after dry-run policy**

Add a module/executable/run step/test step following the exact pattern used
for `causal_production_telemetry_ci_gate_dry_run_policy_tool_module`:

```zig
const causal_production_telemetry_ci_gate_dry_run_evaluator_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_production_telemetry_ci_gate_dry_run_evaluator.zig"),
    .target = target,
    .optimize = optimize,
});

const causal_production_telemetry_ci_gate_dry_run_evaluator_tool = b.addExecutable(.{
    .name = "zigeffect-causal-production-telemetry-ci-gate-dry-run-evaluator",
    .root_module = causal_production_telemetry_ci_gate_dry_run_evaluator_tool_module,
});
const run_causal_production_telemetry_ci_gate_dry_run_evaluator_tool = b.addRunArtifact(causal_production_telemetry_ci_gate_dry_run_evaluator_tool);
if (b.args) |args| run_causal_production_telemetry_ci_gate_dry_run_evaluator_tool.addArgs(args);
const causal_production_telemetry_ci_gate_dry_run_evaluator_step = b.step("causal-production-telemetry-ci-gate-dry-run-evaluator", "Evaluate production telemetry CI gate dry-run signals");
causal_production_telemetry_ci_gate_dry_run_evaluator_step.dependOn(&run_causal_production_telemetry_ci_gate_dry_run_evaluator_tool.step);

const causal_production_telemetry_ci_gate_dry_run_evaluator_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-production-telemetry-ci-gate-dry-run-evaluator-tests",
    .root_module = causal_production_telemetry_ci_gate_dry_run_evaluator_tool_module,
});
const run_causal_production_telemetry_ci_gate_dry_run_evaluator_tool_tests = b.addRunArtifact(causal_production_telemetry_ci_gate_dry_run_evaluator_tool_tests);
test_step.dependOn(&run_causal_production_telemetry_ci_gate_dry_run_evaluator_tool_tests.step);
```

- [ ] **Step 2: Verify help**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-dry-run-evaluator -- --help
```

Expected: usage text for `--from-dry-run-policy`, `evaluate`, `--reason`,
and repeated `--evidence`.

## Task 6: Register Schema and Backlog

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`

- [ ] **Step 1: Add schema governance entry**

Add:

```zig
.{
    .schema = "zigeffect.causal.production-telemetry-ci-gate-dry-run-evaluator.v1",
    .version = 1,
    .category = "production-hardening",
    .status = "current",
    .emitted_by = &.{"causal-production-telemetry-ci-gate-dry-run-evaluator"},
    .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry CI advisory report" },
    .compatibility = &.{ "strict-v1", "record-only", "dry-run-evaluator", "advisory-findings", "bounded-ci-artifacts", "no-live-ingestion", "no-network", "no-durable-write", "no-nendb-write", "no-ci-gate-enforcement", "no-required-status-check", "no-tool-workflow-mutation" },
    .governance_requirements = &.{ "source dry-run policy checks", "bounded evidence classification tests", "signal evaluation tests", "negative evidence fixtures", "next-branch advisory report handoff" },
},
```

Update schema count tests from 65 to 66 and add text/JSON assertions for the
new schema.

- [ ] **Step 2: Add backlog item**

In `causal_production_hardening_backlog.zig`:

- Set recommendation to `start-production-telemetry-ci-gate-advisory-ci-report`.
- Set recommended branch to
  `codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report`.
- Add delivered item `production-telemetry-ci-gate-dry-run-evaluator`.
- Append it to `dependency_order`.
- Add ready and negative evaluator commands to `verification_commands`.
- Update tests to assert the new item and branch.

- [ ] **Step 3: Run focused tests/builds**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog.zig
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

Expected: schema count is 66 and backlog recommends advisory CI report branch.

## Task 7: Documentation and Roadmap Updates

**Files:**
- Create: `packages/zigeffect/docs/production-telemetry-ci-gate-dry-run-evaluator.md`
- Modify: docs listed in File Structure.

- [ ] **Step 1: Create evaluator docs**

Document:

- purpose and non-goals
- CLI
- source policy contract
- explicit evidence contract
- signal semantics
- output schema
- verification commands
- handoff to advisory CI report branch

- [ ] **Step 2: Update schema governance docs**

Add `zigeffect.causal.production-telemetry-ci-gate-dry-run-evaluator.v1`
section after dry-run policy.

- [ ] **Step 3: Update operations, README, backlog, roadmap, and master roadmap**

Each doc should state:

- evaluator is delivered
- dry-run policy is source
- evaluator emits advisory findings and next queries
- current next branch is
  `codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report`
- no enforcement, required status checks, workflow mutation, live telemetry,
  durable writes, NenDB writes, production cluster claims, or mutation
  authority

## Task 8: Real Artifact Generation and Verification

**Files:**
- Generated only in `.zig-cache`, not committed.

- [ ] **Step 1: Generate ready evaluator artifact**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-dry-run-evaluator -- \
  --from-dry-run-policy ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-dry-run-policy.json \
  evaluate \
  --reason "CI gate dry-run evaluator reviewed" \
  --evidence .zig-cache/release-gate/zigeffect-release-gate.json \
  --evidence .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json \
  --evidence .zig-cache/causal-artifacts/zigeffect-causal-ci-handoff.txt
```

Expected: exits 0 and prints `evaluation_status: ready` or
`evaluation_status: advisory-findings` depending on whether the handoff file is
present in the current cache. If the handoff file is absent, use an existing
bounded causal text artifact for the advisory path and verify
`ready_for_next_branch: true`.

- [ ] **Step 2: Generate negative evaluator artifact**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-dry-run-evaluator -- \
  --from-dry-run-policy ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-dry-run-policy.json \
  evaluate \
  --reason "negative CI gate dry-run evaluator path" \
  --evidence ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-dry-run-policy-negative.json \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-dry-run-evaluator-negative
```

Expected: exits 0 and prints `evaluation_status: blocked`.

- [ ] **Step 3: Run full verification**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_dry_run_evaluator.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-production-telemetry-ci-gate-dry-run-evaluator -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

Expected: every command exits 0.

## Task 9: Commit Feature Milestone

**Files:**
- All implementation and documentation files from this plan.

- [ ] **Step 1: Review worktree**

Run:

```sh
git status --short --branch
git diff --stat
git diff --check
```

Expected: only evaluator milestone files are changed; diff check exits 0.

- [ ] **Step 2: Commit**

Run:

```sh
git add docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md \
  packages/zigeffect/README.md \
  packages/zigeffect/build.zig \
  packages/zigeffect/docs \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  packages/zigeffect/tools/causal_production_telemetry_ci_gate_dry_run_evaluator.zig \
  packages/zigeffect/tools/causal_schema_governance.zig
git commit -m "feat(zigeffect): add production telemetry ci gate dry-run evaluator"
```

Expected: commit succeeds on
`codex/zigeffect-causal-production-telemetry-ci-gate-dry-run-evaluator`.
