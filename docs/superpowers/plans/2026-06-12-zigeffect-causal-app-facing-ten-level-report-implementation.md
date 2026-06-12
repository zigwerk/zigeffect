# Zigeffect App-Facing Ten-Level Report Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the alias-named ten-level report producer that consumes ready or advisory nine-level evaluator evidence and advances the backlog to the ten-level application-boundary branch.

**Architecture:** Reuse the existing nine-level report producer, preserve its ready/advisory/blocked report classifier, and retarget source parsing to the short nine-level evaluator aliases. The physical tool, build step, docs, and branch use short names while emitted schemas keep the full expanded lineage.

**Tech Stack:** Zig build tool, Zig unit tests, deterministic JSON/text artifacts, Bun project verification.

---

### Task 1: Add Failing Report Test

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_ten_level_report.zig`

- [ ] **Step 1: Write the constants test first**

```zig
const std = @import("std");

test "app-facing ten-level report constants are stable" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1",
        schema,
    );
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-ten-level-report", source_branch);
    try std.testing.expectEqualStrings("start-app-facing-ten-level-application-boundary", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-ten-level-application-boundary", next_branch_if_ready);
}
```

- [ ] **Step 2: Run the focused RED test**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_ten_level_report.zig
```

Expected: FAIL with undeclared `schema`.

### Task 2: Promote The Report Tool

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_ten_level_report.zig`

- [ ] **Step 1: Copy the existing nine-level report into the alias file**

Copy from:

```text
packages/zigeffect/tools/causal_app_facing_nine_level_report.zig
```

- [ ] **Step 2: Replace top-level constants**

Use these values:

```zig
pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1";
pub const schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-ten-level-report";
pub const recommendation = "start-app-facing-ten-level-application-boundary";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-ten-level-application-boundary";

const source_evaluator_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1";
const generated_by = "causal-app-facing-ten-level-report";
const evaluator_suffix = "-ci-nine-level-evaluator.json";
const output_suffix = "-ci-ten-level-report";
const compact_output_prefix_name = "app-facing-ci-ten-level-report";
```

- [ ] **Step 3: Replace primary source gates**

The consumed evaluator artifact should prefer these aliases:

```text
source_nine_level_policy
source_nine_level_policy_schema
source_nine_level_policy_status
source_nine_level_application_boundary
source_nine_level_application_boundary_schema
source_nine_level_report
source_nine_level_report_schema
source_nine_level_report_status
source_eight_level_policy
source_eight_level_policy_schema
source_eight_level_policy_status
source_eight_level_application_boundary
source_eight_level_application_boundary_schema
source_eight_level_application_status
source_inherited_policy
source_inherited_policy_schema
source_inherited_policy_status
source_inherited_application_boundary
source_inherited_application_boundary_schema
source_inherited_report
source_inherited_report_status
```

Keep fallback support for older fully expanded source keys already present in
the copied implementation. Do not require empty inherited eight-level after
digest aliases when the source nine-level evaluator has valid local
before/after evidence and after-report digests.

- [ ] **Step 4: Keep alias usage text**

Usage should begin:

```text
usage: zig build causal-app-facing-ten-level-report -- --from-evaluator <nine-level-evaluator.json> summarize
```

- [ ] **Step 5: Run the focused GREEN test**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_ten_level_report.zig
```

Expected: PASS.

### Task 3: Build Wiring

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] Add module, executable, run step, and test target for:

```text
causal-app-facing-ten-level-report
zigeffect-causal-app-facing-ten-level-report
tools/causal_app_facing_ten_level_report.zig
```

- [ ] Verify:

```bash
cd packages/zigeffect
zig build causal-app-facing-ten-level-report -- --help
```

Expected: usage text names `--from-evaluator`, `summarize`, `--reason`, and
`--out-prefix`.

### Task 4: Schema Governance RED And GREEN

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`

- [ ] Update tests first to expect schema count plus one and the ten-level report schema:

```zig
try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1");
```

- [ ] Run the governance RED test:

```bash
cd packages/zigeffect
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
```

Expected: FAIL until the schema is registered.

- [ ] Register the schema after the nine-level evaluator entry with:

```text
emitted_by = causal-app-facing-ten-level-report
consumed_by = agents, reviewers, non-blocking CI advisory readers, local SolidJS workbench, production-hardening backlog, future app-facing ten-level application-boundary
compatibility = strict-v1, record-only, advisory-only, source-nine-level-evaluator, local-report-only, read-only-consumption, bounded-agent-context, app-facing, solid-webui, webui-dev/zig-webui, no-authority tags
```

- [ ] Run the governance GREEN test.

### Task 5: Production Backlog RED And GREEN

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`

- [ ] Update tests first to expect:

```text
recommendation = start-app-facing-ten-level-application-boundary
recommended_next_branch = codex/zigeffect-causal-app-facing-ten-level-application-boundary
delivered item id = app-facing-ten-level-report
branch = codex/zigeffect-causal-app-facing-ten-level-report
verification = zig build causal-app-facing-ten-level-report -- --help
```

- [ ] Run the backlog RED test:

```bash
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog.zig
```

Expected: FAIL until the backlog item and recommendation are updated.

- [ ] Add the delivered backlog item, dependency-order entry, and verification commands for ready, advisory, and blocked report artifacts.

- [ ] Run the backlog GREEN test.

### Task 6: Docs And Roadmap

**Files:**
- Create: `packages/zigeffect/docs/app-facing-ten-level-report.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] Document consumed schema, emitted schema, alias naming policy, ready/advisory/blocked outcomes, denied authority, and next branch.
- [ ] Mark roadmap item 102 delivered and add item 103:

```text
103. `codex/zigeffect-causal-app-facing-ten-level-application-boundary`
   - Next: consume ready or advisory ten-level report artifacts, record planned or reviewed local application-boundary evidence, preserve local-only no-mutation authority, and hand off to the ten-level policy branch.
```

### Task 7: Generate Artifacts And Full Verification

- [ ] Regenerate generated docs:

```bash
cd packages/zigeffect
zig build causal-schema-governance -- --format json > /tmp/zigeffect-schema-governance.out 2> docs/schema-governance.md
zig build causal-production-hardening-backlog -- --format json > /tmp/zigeffect-production-hardening-backlog.out 2> docs/production-hardening-backlog.md
```

- [ ] Generate ready report artifact:

```bash
cd packages/zigeffect
zig build causal-app-facing-ten-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-nine-level-evaluator.json summarize --reason "reviewed app-facing ten-level report" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-report
```

- [ ] Generate advisory report artifact:

```bash
cd packages/zigeffect
zig build causal-app-facing-ten-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-nine-level-evaluator-advisory.json summarize --reason "advisory app-facing ten-level report source" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-report-advisory
```

- [ ] Generate blocked report artifact:

```bash
cd packages/zigeffect
zig build causal-app-facing-ten-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-nine-level-evaluator-blocked.json summarize --reason "blocked app-facing ten-level report source" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-report-blocked
```

- [ ] Run full verification:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_ten_level_report.zig
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-app-facing-ten-level-report -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
