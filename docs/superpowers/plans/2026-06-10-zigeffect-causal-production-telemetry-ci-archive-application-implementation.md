# Production Telemetry CI Archive Application Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a guarded production telemetry CI archive application artifact that consumes a ready CI harness boundary and only records `applied=true` after reviewed workflow-change, before/after, and post-verification evidence exist.

**Architecture:** Create one deterministic Zig tool, wire it into `packages/zigeffect/build.zig`, and update schema/backlog/docs. The tool validates `zigeffect.causal.production-telemetry-ci-harness-boundary.v1`, supports `plan` and `record-applied`, keeps local mutation authority disabled, and emits `zigeffect.causal.production-telemetry-ci-archive-application.v1`.

**Tech Stack:** Zig 0.16 build tools, existing zigeffect artifact-tool patterns, GitHub Actions workflow text inspection, Markdown docs.

---

## Files

- Add: `packages/zigeffect/tools/causal_production_telemetry_ci_archive_application.zig`
- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Add: `packages/zigeffect/docs/production-telemetry-ci-archive-application.md`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/production-hardening-completion-audit.md`
- Modify: `packages/zigeffect/docs/production-telemetry-ci-harness-boundary.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

Do not modify `.github/workflows/zigeffect-causal.yml` in this branch.

## Task 1: Red Tests For The Archive Application Tool

**Files:**
- Add: `packages/zigeffect/tools/causal_production_telemetry_ci_archive_application.zig`

- [ ] **Step 1: Add the new tool file with constants, option parser tests, and report tests**

Create the tool with tests for:

```zig
pub const production_telemetry_ci_archive_application_schema =
    "zigeffect.causal.production-telemetry-ci-archive-application.v1";
pub const source_branch =
    "codex/zigeffect-causal-production-telemetry-ci-archive-application";
pub const recommendation =
    "start-production-telemetry-ci-archive-evidence-policy";
pub const next_branch_if_applied =
    "codex/zigeffect-causal-production-telemetry-ci-archive-evidence-policy";
```

Required behavior:

- `plan` mode parses `--from-harness`, `plan`, `--reason`, optional
  `--workflow-after`, `--by`, `--policy`, and `--out-prefix`.
- `record-applied` mode parses multiple `--workflow-change`, `--before`,
  `--after`, and `--verified-command` flags.
- Plan output contains `"application_status": "planned"`,
  `"applied": false`, `"mutation_authority": "none"`, and
  `"ci_upload_execution_enabled": false`.
- Record-applied output contains `"application_status": "applied"` and
  `"applied": true` only when all source, workflow, evidence, and verification
  checks pass.
- Prohibited after-workflow features such as `secrets.` or `contents: write`
  block record-applied output.

- [ ] **Step 2: Run the direct tool test and verify the red failure**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_archive_application.zig
```

Expected: fail because parser/evaluator/formatter functions are not yet
implemented.

## Task 2: Implement The Tool

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_archive_application.zig`

- [ ] **Step 1: Implement parsing and source schema validation**

Implement:

- `Mode = enum { plan, record_applied }`
- `ApplicationStatus = enum { planned, applied, blocked }`
- `Options`
- `parseOptions`
- `validateHarness`
- `outputPathsForOptions`

Fail closed on unsupported source schema, source status other than `ready`,
unapproved source decision, missing `ready_for_next_branch`, enabled source
authority, missing required source verification, unknown mode, missing reason,
and missing record-applied evidence.

- [ ] **Step 2: Implement evaluation**

Evaluation checks:

- source schema supported;
- source harness ready;
- source decision approved;
- source next branch ready;
- source authority disabled;
- source workflow checks passed;
- source verification recorded;
- source blocked claims carried;
- `plan` skips change/before/after/post-verification checks;
- `record-applied` requires workflow changes, before evidence, after evidence,
  required verification commands, and safe after-workflow text.

- [ ] **Step 3: Implement JSON/text formatting**

Emit all fields listed in the design, including:

- source paths and workflow digests;
- mode and application status;
- authority booleans;
- evidence arrays;
- source checks and application checks;
- required and verified commands;
- application steps, guardrails, blocked claims, recommendation, next branch,
  and agent guidance.

- [ ] **Step 4: Run direct tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_archive_application.zig
```

Expected: all tool tests pass.

## Task 3: Wire Build Step

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Verify red build step**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-archive-application -- --help
```

Expected before wiring: unknown build step.

- [ ] **Step 2: Add module, executable, run step, and tests**

Add the new tool after the CI harness boundary tool:

```zig
const causal_production_telemetry_ci_archive_application_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_production_telemetry_ci_archive_application.zig"),
    .target = target,
    .optimize = optimize,
});
```

Add executable name
`zigeffect-causal-production-telemetry-ci-archive-application`, build step
`causal-production-telemetry-ci-archive-application`, and test dependency on
`test_step`.

- [ ] **Step 3: Verify help and build test**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-archive-application -- --help
zig build test
```

Expected: help prints usage; build test includes the new tool tests.

## Task 4: Governance And Backlog

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`

- [ ] **Step 1: Add schema governance entry**

Add `zigeffect.causal.production-telemetry-ci-archive-application.v1` as
`production-hardening`, emitted by
`causal-production-telemetry-ci-archive-application`, consumed by agents,
reviewers, production-hardening backlog, and future archive evidence policy.

- [ ] **Step 2: Update governance tests**

Increment expected schema count from 60 to 61 and assert the new schema appears
in text and JSON reports.

- [ ] **Step 3: Update production hardening backlog**

Mark `production-telemetry-ci-archive-application` delivered, add it after
`production-telemetry-ci-harness-boundary` in dependency order, add validation
commands, and change recommendation/branch to the archive evidence policy.

- [ ] **Step 4: Verify governance/backlog**

Run:

```sh
cd packages/zigeffect
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

Expected: new schema and new delivered backlog item are present; recommendation
points to `start-production-telemetry-ci-archive-evidence-policy`.

## Task 5: Documentation

**Files:**
- Add: `packages/zigeffect/docs/production-telemetry-ci-archive-application.md`
- Modify docs listed in the file map.

- [ ] **Step 1: Add user-facing docs**

Document command examples, modes, evidence requirements, status semantics,
output paths, and agent guidance.

- [ ] **Step 2: Update index docs**

Update README, operations, roadmap, schema governance, backlog, completion
audit, CI harness boundary docs, and master roadmap to point from harness
boundary to archive application and then to archive evidence policy.

- [ ] **Step 3: Commit docs**

Run:

```sh
git add docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-ci-archive-application-design.md docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-ci-archive-application-implementation.md packages/zigeffect/docs packages/zigeffect/README.md docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "docs(zigeffect): design production telemetry ci archive application"
```

Expected: documentation commit succeeds.

## Task 6: End-To-End Verification

**Files:**
- All branch files.

- [ ] **Step 1: Generate or reuse the ready source harness artifact**

Run the previous harness boundary command if the ready artifact is missing or
blocked.

- [ ] **Step 2: Run ready plan path**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-archive-application -- \
  --from-harness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary.json \
  plan \
  --reason "CI archive application planned from reviewed harness boundary"
```

Expected: `application_status: planned`, `applied: false`.

- [ ] **Step 3: Run negative path**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-archive-application -- \
  --from-harness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary.json \
  record-applied \
  --reason "negative archive application path" \
  --workflow-after ../../.github/workflows/zigeffect-causal.yml \
  --workflow-change ".github/workflows/zigeffect-causal.yml" \
  --before "source harness workflow digest"
```

Expected: blocked because after evidence and required verification commands are
missing.

- [ ] **Step 4: Run full verification**

Run:

```sh
cd packages/zigeffect
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
git status --short --branch
```

Expected: all commands pass and worktree is clean after final commits.

