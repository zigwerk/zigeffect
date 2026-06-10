# Production Telemetry CI Gate Advisory CI Report Publication Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy`, a record-only policy artifact that defines allowed and denied interpretation of externally published advisory CI reports.

**Architecture:** Add one Zig tool following the existing production telemetry policy pattern. The tool parses one applied advisory CI report application-boundary artifact, validates source evidence and disabled authority, supports `approve` and `reject`, renders deterministic JSON/text artifacts, and updates schema governance, backlog, roadmap, README, and operations docs.

**Tech Stack:** Zig 0.16.0, `std.json`, `std.crypto.hash.sha2.Sha256`, existing zigeffect build steps, Bun root verification.

---

## File Structure

- Create `packages/zigeffect/tools/causal_production_telemetry_ci_gate_advisory_ci_report_publication_policy.zig`
  - CLI parsing, source artifact parsing, source checks, interpretation
    catalogs, policy checks, artifact rendering, file IO, and focused tests.
- Modify `packages/zigeffect/build.zig`
  - Add executable, build step, and test integration after the application
    boundary tool.
- Modify `packages/zigeffect/tools/causal_schema_governance.zig`
  - Add schema entry and update schema count from 68 to 69.
- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
  - Mark publication policy delivered and recommend the required-status-check
    readiness branch.
- Create `packages/zigeffect/docs/production-telemetry-ci-gate-advisory-ci-report-publication-policy.md`
  - Document command, source contract, interpretation rules, denied
    inferences, handoff, and verification.
- Modify `packages/zigeffect/README.md`
  - Add command example after the application boundary.
- Modify `packages/zigeffect/docs/operations.md`
  - Add operations guidance and update current next branch.
- Modify `packages/zigeffect/docs/production-hardening-backlog.md`
  - Add delivered backlog item, dependency order item, and verification
    commands.
- Modify `packages/zigeffect/docs/schema-governance.md`
  - Add schema matrix prose.
- Modify `packages/zigeffect/docs/roadmap.md` and
  `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Mark the publication policy delivered and add the next branch.
- Update predecessor docs that currently point at this branch as current next.

## Task 1: Create Red Constants Test

**Files:**
- Create: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_advisory_ci_report_publication_policy.zig`

- [ ] **Step 1: Add the failing constants test**

Create the file with only this test:

```zig
const std = @import("std");

test "ci gate advisory CI report publication policy schema and branch constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-publication-policy.v1", production_telemetry_ci_gate_advisory_ci_report_publication_policy_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_ci_gate_advisory_ci_report_publication_policy_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy", source_branch);
    try std.testing.expectEqualStrings("start-production-telemetry-ci-gate-required-status-check-readiness", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-readiness", next_branch_if_ready);
}
```

- [ ] **Step 2: Run the test and confirm RED**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_advisory_ci_report_publication_policy.zig
```

Expected: fail with an undeclared identifier for
`production_telemetry_ci_gate_advisory_ci_report_publication_policy_schema`.

## Task 2: Implement Constants And CLI Parsing

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_advisory_ci_report_publication_policy.zig`

- [ ] **Step 1: Add constants and enums**

Add constants:

```zig
pub const production_telemetry_ci_gate_advisory_ci_report_publication_policy_schema = "zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-publication-policy.v1";
pub const production_telemetry_ci_gate_advisory_ci_report_publication_policy_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy";
pub const recommendation = "start-production-telemetry-ci-gate-required-status-check-readiness";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-readiness";

const source_application_boundary_schema = "zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-application-boundary.v1";
const generated_by = "causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy";
```

Define `Decision = enum { approve, reject }`,
`PolicyStatus = enum { ready, blocked }`, and
`CheckStatus = enum { pass, fail }`.

- [ ] **Step 2: Add `Options` and parser**

Parse:

```sh
--from-application <advisory-ci-report-application-boundary.json> approve|reject --reason <reason>
```

Also parse `--by`, `--policy`, `--verified-command`, and `--out-prefix`.

Validate:

- source path ends with `.json`
- decision is `approve` or `reject`
- `--reason` is present and non-empty

- [ ] **Step 3: Add CLI parsing tests**

Add tests for:

- approve mode default actor and policy
- reject mode
- custom actor, policy, verified command, and output prefix
- unknown decision returns `error.UnknownDecision`
- missing reason returns `error.MissingReason`

- [ ] **Step 4: Run focused tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_advisory_ci_report_publication_policy.zig
```

Expected: constants and CLI parsing tests pass.

## Task 3: Evaluate Source Application Boundary Artifacts

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_advisory_ci_report_publication_policy.zig`

- [ ] **Step 1: Add source artifact structs**

Define structs for:

- `SourceCheck` with `name`, `status`, `detail`
- `SourceNegativeFixture` with `id`, `artifact_state`, `decision`,
  `failed_gate`, `reason`
- `ApplicationBoundaryArtifact` with source schema, mode, status, authority
  flags, `after_report_digest`, `publication_changes`, `before_evidence`,
  `after_evidence`, checks, blocked claims, negative fixtures, and required
  verification commands
- `PolicyCheck`
- `PolicyResult`

- [ ] **Step 2: Add source checks**

Implement checks named exactly:

- `source-schema`
- `source-applied`
- `source-record-only-authority`
- `source-publication-execution-disabled`
- `source-ci-enforcement-disabled`
- `source-runtime-and-storage-disabled`
- `source-application-evidence-present`
- `source-checks-passed`
- `source-catalogs-present`

- [ ] **Step 3: Add source evaluation tests**

Add sample JSON strings for:

- applied source application boundary
- planned source application boundary
- blocked source application boundary
- source with `github_step_summary_write_enabled=true`
- source with `ci_required_status_check_enabled=true`

Assert approve mode returns ready only for the applied source with complete
verification commands. Assert all other samples return blocked.

## Task 4: Add Interpretation Policy Catalogs

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_advisory_ci_report_publication_policy.zig`

- [ ] **Step 1: Add catalog structs**

Add:

```zig
const InterpretationRule = struct {
    id: []const u8,
    consumer_role: []const u8,
    allowed_use: []const u8,
    failure_effect: []const u8,
    denied_claim: []const u8,
};

const PublicationSurface = struct {
    id: []const u8,
    visibility_class: []const u8,
    executed_by_tool: bool,
    interpretation_scope: []const u8,
};
```

- [ ] **Step 2: Add required interpretation rules**

Create rules with ids:

- `reviewer-triage-summary`
- `agent-readonly-context`
- `non-blocking-ci-advisory`
- `before-after-review-evidence`
- `future-readiness-input`

Every rule must have `failure_effect="informational"` or
`failure_effect="readiness-input"` and must deny enforcement or production
health claims.

- [ ] **Step 3: Add denied inference rules and negative fixtures**

Include denied claims for:

- required status checks
- merge blockers
- branch protection
- workflow mutation proof
- artifact upload proof
- GitHub step-summary proof by this tool
- pull request comment proof by this tool
- production health
- deployment success
- capacity proof
- customer impact
- production cluster readiness
- live telemetry coverage
- durable write proof
- NenDB write proof
- mutation authority
- non-NenDB durable adapters
- alternate renderers

Add negative fixture ids:

- `planned-source-denied`
- `blocked-source-denied`
- `required-status-check-claim-denied`
- `merge-blocking-claim-denied`
- `publication-execution-claim-denied`
- `github-step-summary-claim-denied`
- `pull-request-comment-claim-denied`
- `production-health-claim-denied`
- `cluster-readiness-claim-denied`
- `mutation-authority-claim-denied`
- `non-nendb-durable-scope-denied`
- `alternate-renderer-scope-denied`

- [ ] **Step 4: Add catalog tests**

Assert the rendered JSON contains the five interpretation rule ids, the denied
required-status-check claim, the denied production-health claim, and the
negative mutation-authority fixture.

## Task 5: Render Artifacts And File IO

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_advisory_ci_report_publication_policy.zig`

- [ ] **Step 1: Add output path replacement**

Implement default output replacement:

```text
*-ci-gate-advisory-ci-report-application-boundary.json
*-ci-gate-advisory-ci-report-publication-policy.json
```

Add a long-path compaction helper like the application-boundary tool so
implicit filenames remain filesystem-safe.

- [ ] **Step 2: Add JSON and text rendering**

JSON must include:

- `schema`
- `schema_version`
- `generated_by`
- `source_application_boundary`
- `source_report_application_status`
- `decision`
- `advisory_ci_report_publication_policy_status`
- `ready_for_next_branch`
- `reviewed_by`
- `policy`
- `reason`
- disabled authority booleans
- `mutation_authority`
- `policy_checks`
- `interpretation_rules`
- `publication_surfaces`
- `denied_inference_rules`
- `negative_fixtures`
- `required_verification_commands`
- `verified_commands`
- `recommendation`
- `next_branch_if_ready`
- `agent_guidance`

Text output must expose the same key status, handoff, checks, catalogs, and
guidance in deterministic order.

- [ ] **Step 3: Add render tests**

Assert:

- approved source emits
  `"advisory_ci_report_publication_policy_status": "ready"`
- rejected source emits blocked status
- approved source emits `"ready_for_next_branch": true`
- text output includes `next branch if ready`
- output paths end with `-ci-gate-advisory-ci-report-publication-policy.json`

## Task 6: Wire Build Step And Schema Governance

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`

- [ ] **Step 1: Add build wiring**

In `packages/zigeffect/build.zig`, add a module, executable, run step, and test
step for `causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy`
immediately after the advisory CI report application-boundary wiring.

- [ ] **Step 2: Add schema governance entry**

Add schema:

```text
zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-publication-policy.v1
```

Use category `production-hardening`, emitted by
`causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy`,
and consumed by agents, reviewers, production-hardening backlog, and future
required-status-check readiness.

Compatibility tags must include:

- `strict-v1`
- `record-only`
- `publication-policy`
- `interpretation-policy`
- `non-blocking-advisory`
- `cluster-release-gate-aware`
- `no-live-ingestion`
- `no-network`
- `no-durable-write`
- `no-nendb-write`
- `no-ci-gate-enforcement`
- `no-required-status-check`
- `no-tool-workflow-mutation`
- `no-tool-ci-upload`
- `no-tool-github-step-summary-write`
- `no-tool-pr-comment`

- [ ] **Step 3: Update schema count tests**

Update schema count expectations from 68 to 69 and assert the new schema entry
is present.

## Task 7: Update Backlog And Documentation

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Create: `packages/zigeffect/docs/production-telemetry-ci-gate-advisory-ci-report-publication-policy.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Update backlog constants**

Set:

```zig
pub const recommendation = "start-production-telemetry-ci-gate-required-status-check-readiness";
pub const recommended_next_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-readiness";
```

Add delivered backlog item id:

```text
production-telemetry-ci-gate-advisory-ci-report-publication-policy
```

- [ ] **Step 2: Add verification command strings**

Add commands:

```sh
zig build causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy -- --from-application ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-advisory-ci-report-application-boundary-applied.json approve --reason "CI advisory report publication policy reviewed" --verified-command "zig build causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary" --verified-command "zig build causal-artifacts" --verified-command "zig build release-gate --summary none" --verified-command "zig build release-gate-report" --verified-command "zig build causal-schema-governance -- --format json" --verified-command "zig build causal-production-hardening-backlog -- --format json" --verified-command "zig build examples" --verified-command "zig build test"
zig build causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy -- --from-application ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-advisory-ci-report-application-boundary-negative.json reject --reason "negative CI advisory report publication policy path" --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-advisory-ci-report-publication-policy-negative
```

- [ ] **Step 3: Update docs**

Document:

- source application-boundary contract
- allowed interpretations
- denied inferences
- no publication execution by this tool
- no CI enforcement or required checks
- next branch:
  `codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-readiness`

## Task 8: Generate Artifacts, Verify, And Commit

**Files:**
- All files modified above.

- [ ] **Step 1: Run focused verification**

Run:

```sh
cd packages/zigeffect
zig fmt build.zig tools/causal_production_telemetry_ci_gate_advisory_ci_report_publication_policy.zig tools/causal_production_hardening_backlog.zig tools/causal_schema_governance.zig
zig test tools/causal_production_telemetry_ci_gate_advisory_ci_report_publication_policy.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

Expected:

- publication-policy tests pass
- backlog tests pass
- schema governance reports `schema_count: 69`
- backlog recommends
  `codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-readiness`

- [ ] **Step 2: Generate positive and negative policy artifacts**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy -- \
  --from-application ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-advisory-ci-report-application-boundary-applied.json \
  approve \
  --reason "CI advisory report publication policy reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"

zig build causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy -- \
  --from-application ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-advisory-ci-report-application-boundary-negative.json \
  reject \
  --reason "negative CI advisory report publication policy path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-advisory-ci-report-publication-policy-negative
```

Expected:

- positive output has `advisory_ci_report_publication_policy_status: ready`
- positive output has `ready_for_next_branch: true`
- negative output has `advisory_ci_report_publication_policy_status: blocked`

- [ ] **Step 3: Run full verification**

Run:

```sh
cd packages/zigeffect
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 4: Commit**

Run:

```sh
git status --short --branch
git add docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md packages/zigeffect/README.md packages/zigeffect/build.zig packages/zigeffect/docs packages/zigeffect/tools/causal_production_hardening_backlog.zig packages/zigeffect/tools/causal_production_telemetry_ci_gate_advisory_ci_report_publication_policy.zig packages/zigeffect/tools/causal_schema_governance.zig
git commit -m "feat(zigeffect): add advisory ci report publication policy"
```

Expected: commit succeeds on
`codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy`.
