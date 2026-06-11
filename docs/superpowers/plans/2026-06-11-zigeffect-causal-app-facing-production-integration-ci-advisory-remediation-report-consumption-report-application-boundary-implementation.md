# Zigeffect App-Facing Advisory Report Consumption Report Application Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a guarded, record-only application-boundary producer that consumes app-facing advisory remediation report consumption-report artifacts and emits planned, applied, or blocked local evidence.

**Architecture:** Add one standalone Zig tool following the existing application-boundary producer pattern. The tool validates the source consumption report, gates applied records on reviewed change evidence, before/after evidence, safe after-report content, and verification command evidence, then emits JSON and text artifacts.

**Tech Stack:** Zig tool under `packages/zigeffect/tools`, Zig build integration in `packages/zigeffect/build.zig`, schema governance and production-hardening backlog producers, markdown docs.

---

## File Map

- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_application_boundary.zig`
  - Implements CLI parsing, source JSON parsing, source checks, application checks, JSON/text rendering, negative fixtures, tests, and artifact writing.
- Modify: `packages/zigeffect/build.zig`
  - Adds executable, build step, and test integration.
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
  - Adds schema entry and increments schema-count assertions to `99`.
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
  - Marks this milestone delivered and changes recommendation to the next policy branch.
- Create: `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary.md`
  - Documents command, modes, gates, authority model, and next handoff.
- Modify generated docs:
  - `packages/zigeffect/docs/schema-governance.md`
  - `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify roadmap:
  - `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

## Task 1: Red Tests For New Producer

- [ ] **Step 1: Add a new Zig tool file with constants, fixture JSON, and tests only**

Create `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_application_boundary.zig` with tests that call the intended API:

```zig
test "app-facing consumption report application boundary constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary.v1", schema);
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary", source_branch);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy", next_branch_if_applied);
}

test "plan mode records planned state without applied authority" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = .{
            .report_path = "source-ci-advisory-remediation-report-consumption-report.json",
            .mode = .plan,
            .reason = "plan local report application",
        },
        .source_report_json = ready_source_report_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"report_application_status\": \"planned\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"mutation_authority\": \"none\"") != null);
}
```

Add additional tests for option parsing, default output suffix, successful `record-applied`, missing evidence blocking, unsafe after-report blocking, blocked source report blocking, source authority drift blocking, and parseable JSON output.

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_application_boundary.zig
```

Expected: FAIL because the new tests reference functions and constants that are not implemented yet.

## Task 2: Implement Producer

- [ ] **Step 1: Implement constants and option parsing**

Add:

```zig
pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary.v1";
pub const schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary";
pub const recommendation = "start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy";
pub const next_branch_if_applied = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy";
```

The parser accepts `--from-report <json> plan|record-applied --reason <reason>` plus `--report-after`, `--report-application-change`, `--before`, `--after`, `--verified-command`, `--by`, `--policy`, and `--out-prefix`.

- [ ] **Step 2: Implement source model and source validation**

Parse the source report with `std.json.parseFromSlice(..., .{ .ignore_unknown_fields = true })`. Check schema/version, status, ready handoff, blocked finding count, mutation authority, source references, local-only publication channels, check pass state, denied claims, next queries, source summaries, and verification command evidence.

- [ ] **Step 3: Implement application checks**

For `plan`, skip change/evidence/verification checks and set `applied=false`, `ready_for_next_branch=false`, `mutation_authority="none"`.

For `record-applied`, require report application change evidence, before evidence, after evidence, full verification commands, after-report content, and after-report safety. Set `applied=true`, `ready_for_next_branch=true`, and `mutation_authority="record-only"` only when all checks pass.

- [ ] **Step 4: Implement JSON and text rendering**

Render source refs, status fields, authority booleans, evidence arrays, application checks, source checks, findings, denied claims, publication channels, next queries, negative fixtures, verification commands, and agent guidance. Use local JSON escaping helpers from nearby tools.

- [ ] **Step 5: Run focused test and verify GREEN**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_application_boundary.zig
```

Expected: PASS.

## Task 3: Wire Build Step

- [ ] **Step 1: Modify `packages/zigeffect/build.zig`**

Add a module and executable named:

```zig
zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary
```

Add build step:

```zig
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary
```

Depend the root `test` step on the tool tests.

- [ ] **Step 2: Verify build help**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary -- --help
```

Expected: usage text for the new command.

## Task 4: Generate Local Artifacts

- [ ] **Step 1: Create safe after-report evidence**

Write `.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-application-after.txt` with text containing the required markers: `zigeffect causal read-only consumption report application`.

- [ ] **Step 2: Generate plan, applied, and blocked artifacts**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-report.json plan --reason "app-facing advisory remediation report consumption report application boundary planned" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-application-boundary-plan
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-report.json record-applied --reason "reviewed app-facing advisory remediation report consumption report application boundary" --report-after ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-application-after.txt --report-application-change "reviewed local consumption report application boundary for agents reviewers CI advisory readers and SolidJS webui" --before "before local consumption report application boundary evidence" --after "after local consumption report application boundary evidence" --verified-command "bun run zigeffect:workbench:typecheck" --verified-command "bun run zigeffect:workbench:test" --verified-command "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report -- --help" --verified-command "zig build causal-schema-governance -- --format json" --verified-command "zig build causal-production-hardening-backlog -- --format json" --verified-command "zig build examples" --verified-command "zig build test"
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-blocked.json record-applied --reason "blocked app-facing consumption report application boundary source" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-application-boundary-blocked
```

Expected: plan output has `applied=false`, applied output has `applied=true`, blocked output has `applied=false`.

## Task 5: Governance, Backlog, Docs, Roadmap

- [ ] **Step 1: Update schema governance**

Add the new schema entry after the consumption-report schema. Update tests to expect schema count `99`, the new schema, and JSON rendering.

- [ ] **Step 2: Update production hardening backlog**

Change the current recommendation to:

```zig
pub const recommendation = "start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy";
pub const recommended_next_branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy";
```

Add a delivered backlog item for this branch and add required command examples.

- [ ] **Step 3: Add user docs**

Create `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary.md` documenting command syntax, modes, source gates, after-report safety, authority denial, and next branch.

- [ ] **Step 4: Update roadmap**

Mark item 63 delivered and add item 64 for the next policy branch.

- [ ] **Step 5: Regenerate governance docs**

Run:

```bash
cd packages/zigeffect
zig build causal-schema-governance > docs/schema-governance.md 2>&1
zig build causal-production-hardening-backlog > docs/production-hardening-backlog.md 2>&1
```

Expected: generated markdown includes the new schema and recommended next branch.

## Task 6: Full Verification And Commit

- [ ] **Step 1: Run focused verification**

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_application_boundary.zig
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report.zig
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary -- --help
```

Expected: all commands pass.

- [ ] **Step 2: Run schema/backlog JSON checks**

```bash
cd packages/zigeffect
zig build causal-schema-governance -- --format json > /tmp/zigeffect-schema.json
rg '"schema_count": 99' /tmp/zigeffect-schema.json
zig build causal-production-hardening-backlog -- --format json > /tmp/zigeffect-backlog.json
rg 'codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy' /tmp/zigeffect-backlog.json
```

Expected: both `rg` commands match.

- [ ] **Step 3: Run full project verification**

```bash
cd packages/zigeffect
zig build test
zig build examples
cd ../..
bun run check
bun run zig:test
git diff --check
```

Expected: all commands pass.

- [ ] **Step 4: Commit and branch forward**

```bash
git add docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md \
  docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary-design.md \
  docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary-implementation.md \
  packages/zigeffect/build.zig \
  packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary.md \
  packages/zigeffect/docs/production-hardening-backlog.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_application_boundary.zig \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  packages/zigeffect/tools/causal_schema_governance.zig
git commit -m "feat(zigeffect): add app-facing advisory report consumption report application boundary"
git switch -c codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy
```

Expected: commit succeeds and the next branch is ready for the following milestone.
