# Zigeffect Causal App-Facing Advisory Remediation Report Consumption Report Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a record-only policy producer for applied app-facing advisory remediation report consumption-report application-boundary artifacts.

**Architecture:** Add one Zig CLI producer under `packages/zigeffect/tools`, wire it into `packages/zigeffect/build.zig`, then register the schema and roadmap/backlog handoff. The producer parses an applied application-boundary JSON artifact, evaluates source and policy gates, and writes local JSON/text evidence without granting mutation authority.

**Tech Stack:** Zig toolchain, `std.json`, `std.Build`, Bun repo checks, existing zigeffect causal schema governance and hardening backlog tools.

---

### Task 1: Policy Producer Tests And CLI Contract

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_policy.zig`

- [ ] **Step 1: Add constants, option parsing, fixtures, and tests**

Add a new tool with these stable constants:

```zig
pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy.v1";
pub const schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy";
pub const recommendation = "start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator";
```

The parser accepts:

```bash
tool --from-application source-consumption-report-application-boundary.json approve --reason "reviewed policy"
tool --from-application source-consumption-report-application-boundary.json reject --reason "blocked policy"
```

Add tests for:

- constants and next branch,
- `approve` and `reject` parsing,
- default output path suffix replacement,
- approved output readiness,
- rejected output blocked state,
- parseable JSON,
- missing verification blocking approval,
- blocked or unsafe source blocking approval,
- negative fixture coverage.

- [ ] **Step 2: Run the focused test and confirm the expected initial failure**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_policy.zig
```

Expected before implementation is a compile/test failure while the producer is incomplete. After implementation, the command must pass.

### Task 2: Policy Evaluation And Artifact Formatting

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_policy.zig`

- [ ] **Step 1: Implement source validation**

Validate:

```zig
source.schema == source_application_schema
source.schema_version == 1
source.mode == "record-applied"
source.report_application_status == "applied"
source.applied == true
source.ready_for_next_branch == true
source.mutation_authority == "record-only"
```

Also require source refs, source application evidence, no failed checks, disabled authority, SolidJS/WebUI read-only identity, local-only publication, and source verification evidence.

- [ ] **Step 2: Implement decision semantics**

For `approve`, set ready only when every check passes and every required verification command is recorded. For `reject`, emit blocked evidence and `ready_for_next_branch = false`.

All outputs use:

```zig
const mutation_authority = "none";
```

- [ ] **Step 3: Implement JSON/text reports**

Include the source boundary fields, policy checks, interpretation rules, consumption scopes, denied inference rules, negative fixtures, required/verified commands, and agent guidance.

### Task 3: Build Integration

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Register module, executable, build step, and tests**

Add a sibling block after the consumption-report-application-boundary tool:

```zig
const causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_policy_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_policy.zig"),
    .target = target,
    .optimize = optimize,
});
```

Create the executable, forward `b.args`, add the build step named:

```text
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy
```

and add its tests to `test_step`.

- [ ] **Step 2: Verify help output**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy -- --help
```

Expected: usage text for `--from-application`.

### Task 4: Governance, Backlog, And Docs

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Create: `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy.md`
- Regenerate: `packages/zigeffect/docs/schema-governance.md`
- Regenerate: `packages/zigeffect/docs/production-hardening-backlog.md`

- [ ] **Step 1: Add schema governance entry**

Add the new schema immediately after the application-boundary schema with compatibility tags:

```text
strict-v1, record-only, advisory-only, consumption-report-policy, applied-consumption-report-application-boundary-source, read-only-consumption, bounded-agent-context, app-facing, solid-webui, webui-dev/zig-webui, no-cockroach, no-ci-enforcement, no-required-status-check, no-workflow-mutation, no-github-api-mutation, no-app-mutation, no-app-runtime-integration, no-live-agent-projection, no-raw-payload-capture, no-deployment-mutation, no-production-mutation, no-nendb-write, no-nendb-adapter-execution, no-public-artifact-upload, no-mutation-authority
```

Update schema count tests from `99` to `100`.

- [ ] **Step 2: Add backlog delivered item and move recommendation**

Change:

```zig
pub const recommendation = "start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator";
pub const recommended_next_branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator";
```

Append a delivered backlog item for the report policy, add it to `dependency_order`, and include verification commands for approve/reject/blocked artifact generation.

- [ ] **Step 3: Write package docs and regenerate generated docs**

Document CLI examples, gate semantics, denied claims, next branch, and verification commands. Regenerate schema governance and hardening backlog docs with their Zig tools.

### Task 5: Artifact Generation, Verification, Commit, And Next Branch

**Files:**
- Generated under: `.zig-cache/causal-artifacts/`

- [ ] **Step 1: Generate policy artifacts**

Run the approval command against the applied application-boundary artifact:

```bash
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy -- \
  --from-application ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-report-application-boundary.json \
  approve \
  --reason "reviewed app-facing advisory remediation report consumption report policy" \
  --verified-command "bun run zigeffect:workbench:typecheck" \
  --verified-command "bun run zigeffect:workbench:test" \
  --verified-command "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary -- --help" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Also generate reject and blocked-source fixtures with `--out-prefix`.

- [ ] **Step 2: Run verification**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_policy.zig
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_application_boundary.zig
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build test
zig build examples
cd ../..
bun run check
bun run zig:test
git diff --check
```

- [ ] **Step 3: Commit and create the next branch**

Run:

```bash
git add docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy-design.md \
  docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy-implementation.md \
  packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_policy.zig \
  packages/zigeffect/build.zig \
  packages/zigeffect/tools/causal_schema_governance.zig \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/docs/production-hardening-backlog.md
git commit -m "feat(zigeffect): add app-facing advisory report consumption report policy"
git switch -c codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator
```

Expected: clean working tree on the evaluator branch.
