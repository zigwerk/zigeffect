# Zigeffect App-Facing Twelve-Level Application Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Build the alias-named twelve-level app-facing application boundary that consumes twelve-level report artifacts and hands applied evidence to the twelve-level policy branch.

**Architecture:** Promote the proven eleven-level application-boundary implementation into a twelve-level alias file while adding direct twelve-level source report fields and preserving eleven-level, ten-level, nine-level, and inherited lower lineage. The tool remains local, record-only, and read-only; only `record-applied` can set `applied=true`, and only after reviewed evidence, safe after-report content, and verification command gates pass.

**Tech Stack:** Zig build tools and `zig test`, Bun root checks, existing zigeffect causal schema governance and production-hardening backlog generators.

---

### Task 1: Boundary Tool RED Test

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_twelve_level_application_boundary.zig`

- [x] **Step 1: Write the failing constants test**

```zig
const std = @import("std");

test "app-facing twelve-level application boundary constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1", schema);
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-twelve-level-application-boundary", source_branch);
    try std.testing.expectEqualStrings("start-app-facing-twelve-level-policy", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-twelve-level-policy", next_branch_if_applied);
}
```

- [x] **Step 2: Run the focused RED test**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_twelve_level_application_boundary.zig
```

Expected: FAIL with undeclared identifiers for `schema`, `schema_version`, `source_branch`, `recommendation`, and `next_branch_if_applied`.

### Task 2: Promote The Boundary Tool

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_twelve_level_application_boundary.zig`

- [x] **Step 1: Copy the eleven-level application-boundary implementation**

Run:

```bash
cp packages/zigeffect/tools/causal_app_facing_eleven_level_application_boundary.zig packages/zigeffect/tools/causal_app_facing_twelve_level_application_boundary.zig
```

- [x] **Step 2: Mechanically promote naming**

Run:

```bash
perl -0pi -e 's/eleven-level/twelve-level/g; s/eleven level/twelve level/g; s/eleven_level/twelve_level/g; s/ElevenLevel/TwelveLevel/g' packages/zigeffect/tools/causal_app_facing_twelve_level_application_boundary.zig
```

- [x] **Step 3: Retarget top-level constants**

Ensure these values:

```zig
pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1";
pub const schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-twelve-level-application-boundary";
pub const recommendation = "start-app-facing-twelve-level-policy";
pub const next_branch_if_applied = "codex/zigeffect-causal-app-facing-twelve-level-policy";

const source_report_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1";
const generated_by = "causal-app-facing-twelve-level-application-boundary";
const source_report_suffix = "-ci-twelve-level-report.json";
const output_prefix_suffix = "-ci-twelve-level-application-boundary";
const compact_output_prefix_name = "app-facing-ci-twelve-level-application-boundary";
```

- [x] **Step 4: Promote status and application output fields**

The source report status field is:

```text
consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status
```

The application output fields are:

```text
evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status
evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_path
evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest
evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_present
evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes
```

- [x] **Step 5: Preserve direct twelve-level and inherited lineage**

Add or verify emitted JSON/text fields for:

```text
source_twelve_level_report
source_twelve_level_report_schema
source_twelve_level_report_status
source_eleven_level_policy
source_eleven_level_policy_schema
source_eleven_level_policy_status
source_eleven_level_application_boundary
source_eleven_level_application_boundary_schema
source_eleven_level_report
source_eleven_level_report_schema
source_eleven_level_report_status
source_eleven_level_after_digest
source_eleven_level_after_present
source_eleven_level_application_changes
source_ten_level_policy
source_ten_level_application_boundary
source_ten_level_report
source_nine_level_policy
source_nine_level_application_boundary
source_nine_level_report
```

- [x] **Step 6: Run the focused GREEN test**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_twelve_level_application_boundary.zig
```

Expected: PASS.

### Task 3: Build, Docs, And Fixture

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Create: `packages/zigeffect/docs/app-facing-twelve-level-application-boundary.md`
- Create: `packages/zigeffect/test/fixtures/app-facing-twelve-level-application-boundary-after-safe.txt`

- [x] **Step 1: Add build wiring**

Add module, executable, run step, and test target named:

```text
causal-app-facing-twelve-level-application-boundary
zigeffect-causal-app-facing-twelve-level-application-boundary
```

- [x] **Step 2: Add the safe after-report fixture**

Create:

```text
zigeffect causal read-only consumption evaluation-report application evidence.
This local evaluation report records reviewed twelve-level application boundary evidence for agents reviewers advisory CI readers and the SolidJS webui.
Denied claims remain listed by id in the artifact; this text grants no extra authority.
```

- [x] **Step 3: Add user-facing docs**

Document consumed schema, emitted schema, aliases, plan usage, record-applied usage, gates, non-authority, and handoff to `codex/zigeffect-causal-app-facing-twelve-level-policy`.

- [x] **Step 4: Verify help**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-twelve-level-application-boundary -- --help
```

Expected: usage text for the alias step.

### Task 4: Governance, Backlog, And Roadmap

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [x] **Step 1: Register schema governance**

Add the twelve-level application-boundary schema after the twelve-level report
entry, increment schema count expectations by one, and add an `expectSchema`
assertion for:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1
```

- [x] **Step 2: Update production backlog next recommendation**

Set:

```zig
pub const recommendation = "start-app-facing-twelve-level-policy";
pub const recommended_next_branch = "codex/zigeffect-causal-app-facing-twelve-level-policy";
```

Add delivered item id `app-facing-twelve-level-application-boundary`, branch
`codex/zigeffect-causal-app-facing-twelve-level-application-boundary`,
dependency `app-facing-twelve-level-report`, and verification commands for help,
plan, record-applied, and blocked source generation.

- [x] **Step 3: Update the roadmap**

Mark item 111 delivered and add item 112:

```text
codex/zigeffect-causal-app-facing-twelve-level-policy
```

- [x] **Step 4: Run focused tests**

Run:

```bash
cd packages/zigeffect
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
```

Expected: both commands exit 0.

### Task 5: Artifact Generation And Verification

**Files:**
- Read generated artifacts under `.zig-cache/causal-artifacts/`

- [x] **Step 1: Generate plan, applied, and blocked application-boundary artifacts**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-twelve-level-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-report.json plan --reason "planned app-facing twelve-level application boundary" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-application-boundary-plan
zig build causal-app-facing-twelve-level-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-report.json record-applied --reason "reviewed app-facing twelve-level application boundary" --after-report test/fixtures/app-facing-twelve-level-application-boundary-after-safe.txt --application-change "reviewed local twelve-level application boundary for agents reviewers CI advisory readers and SolidJS webui" --before "before local twelve-level application boundary evidence" --after "after local twelve-level application boundary evidence" --verified-command "bun run zigeffect:workbench:typecheck" --verified-command "bun run zigeffect:workbench:test" --verified-command "zig build causal-app-facing-twelve-level-report -- --help" --verified-command "zig build causal-schema-governance -- --format json" --verified-command "zig build causal-production-hardening-backlog -- --format json" --verified-command "zig build examples" --verified-command "zig build test" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-application-boundary
zig build causal-app-facing-twelve-level-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-report-blocked.json record-applied --reason "blocked app-facing twelve-level application boundary source" --after-report test/fixtures/app-facing-twelve-level-application-boundary-after-safe.txt --application-change "reviewed local twelve-level blocked source boundary probe" --before "before local twelve-level blocked source evidence" --after "after local twelve-level blocked source evidence" --verified-command "bun run zigeffect:workbench:typecheck" --verified-command "bun run zigeffect:workbench:test" --verified-command "zig build causal-app-facing-twelve-level-report -- --help" --verified-command "zig build causal-schema-governance -- --format json" --verified-command "zig build causal-production-hardening-backlog -- --format json" --verified-command "zig build examples" --verified-command "zig build test" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-application-boundary-blocked
```

Expected: plan has `applied=false`, applied has `applied=true`, blocked has
`applied=false`.

- [x] **Step 2: Run full verification**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_twelve_level_application_boundary.zig
zig build causal-app-facing-twelve-level-application-boundary -- --help
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

Expected: every command exits 0.

### Task 6: Commit, Merge, And Continue

**Files:**
- Commit all touched docs and zigeffect files.

- [x] **Step 1: Commit the milestone**

Run:

```bash
git add docs/superpowers packages/zigeffect
git commit -m "feat(zigeffect): add app-facing twelve-level application boundary"
```

- [x] **Step 2: Fast-forward local master**

Run:

```bash
git -C /Users/seanknowles/.config/superpowers/worktrees/yachdee/master-local-merge merge --ff-only codex/zigeffect-causal-app-facing-twelve-level-application-boundary
```

- [x] **Step 3: Create the next branch**

Run:

```bash
git switch -c codex/zigeffect-causal-app-facing-twelve-level-policy
```

Expected: current branch is `codex/zigeffect-causal-app-facing-twelve-level-policy` and clean.
