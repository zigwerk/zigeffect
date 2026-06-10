# Production Telemetry CI Archive Evidence Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a record-only CI archive evidence policy artifact that consumes archive application evidence and defines safe interpretation rules before any CI gate readiness work.

**Architecture:** Create one deterministic Zig tool, wire it into `packages/zigeffect/build.zig`, and update schema/backlog/docs. The tool validates `zigeffect.causal.production-telemetry-ci-archive-application.v1`, emits `zigeffect.causal.production-telemetry-ci-archive-evidence-policy.v1`, and keeps workflow mutation, CI gates, live telemetry, durable writes, and NenDB writes disabled.

**Tech Stack:** Zig 0.16 build tools, existing zigeffect artifact-tool patterns, deterministic JSON/text reports, Markdown docs.

---

## Files

- Add: `packages/zigeffect/tools/causal_production_telemetry_ci_archive_evidence_policy.zig`
- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Add: `packages/zigeffect/docs/production-telemetry-ci-archive-evidence-policy.md`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/production-hardening-completion-audit.md`
- Modify: `packages/zigeffect/docs/production-telemetry-ci-archive-application.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

Do not modify `.github/workflows/zigeffect-causal.yml` in this branch.

## Task 1: Red Tests For The Policy Tool

**Files:**
- Add: `packages/zigeffect/tools/causal_production_telemetry_ci_archive_evidence_policy.zig`

- [ ] **Step 1: Add tests first**

Write tests that require:

```zig
pub const production_telemetry_ci_archive_evidence_policy_schema =
    "zigeffect.causal.production-telemetry-ci-archive-evidence-policy.v1";
pub const source_branch =
    "codex/zigeffect-causal-production-telemetry-ci-archive-evidence-policy";
pub const recommendation =
    "start-production-telemetry-ci-gate-readiness";
pub const next_branch_if_ready =
    "codex/zigeffect-causal-production-telemetry-ci-gate-readiness";
```

Test behavior:

- Parser accepts `--from-archive-application`, `approve|reject`, `--reason`,
  optional `--by`, `--policy`, repeated `--verified-command`, and
  `--out-prefix`.
- Ready output contains `"archive_evidence_policy_status": "ready"`,
  `"ready_for_next_branch": true`, `"ci_gate_enabled": false`, and evidence
  class ids for causal JSON, causal text, causal DOT, release-gate JSON,
  release-gate text, CI handoff text, and source preview JSON.
- Rejected output is blocked and keeps all authority disabled.
- A source archive application with failing checks or unsupported schema blocks
  policy readiness.

- [ ] **Step 2: Run direct test and verify red failure**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_archive_evidence_policy.zig
```

Expected: fail because parser/evaluator/formatter functions do not exist.

## Task 2: Implement The Tool

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_archive_evidence_policy.zig`

- [ ] **Step 1: Implement parser and source model**

Implement `Decision`, `PolicyStatus`, `CheckStatus`, `Options`,
`ArchiveApplicationArtifact`, and `parseOptions`.

- [ ] **Step 2: Implement evaluation**

Checks:

- source schema is supported;
- source status is `planned` or `applied`;
- source checks contain no `fail`;
- source authority is disabled;
- source blocked claims are carried;
- reviewer decision is `approve`;
- required verification commands are recorded;
- evidence classes are internally valid;
- negative fixtures are present.

- [ ] **Step 3: Implement report formatting**

Emit JSON and text fields:

- source archive application path/status/applied flag;
- decision, reviewer, policy, reason;
- authority booleans;
- evidence classes;
- metadata fields;
- interpretation rules;
- negative fixtures;
- checks;
- required and verified commands;
- blocked claims;
- recommendation and next branch;
- agent guidance.

- [ ] **Step 4: Run direct tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_archive_evidence_policy.zig
```

Expected: all tests pass.

## Task 3: Wire Build Step

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Verify red build step**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-archive-evidence-policy -- --help
```

Expected before wiring: unknown build step.

- [ ] **Step 2: Add module, executable, run step, and tests**

Add the new tool after the archive application tool with executable name
`zigeffect-causal-production-telemetry-ci-archive-evidence-policy`, build step
`causal-production-telemetry-ci-archive-evidence-policy`, and a test
dependency on `test_step`.

- [ ] **Step 3: Verify help**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-archive-evidence-policy -- --help
```

Expected: usage text prints.

## Task 4: Governance And Backlog

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`

- [ ] **Step 1: Add schema governance entry**

Add `zigeffect.causal.production-telemetry-ci-archive-evidence-policy.v1` as
current production-hardening schema emitted by
`causal-production-telemetry-ci-archive-evidence-policy`.

- [ ] **Step 2: Update governance tests**

Increment expected schema count from 61 to 62 and assert the new schema appears
in text and JSON reports.

- [ ] **Step 3: Update backlog**

Mark `production-telemetry-ci-archive-evidence-policy` delivered, add it after
archive application in dependency order, add ready/reject validation commands,
and change recommendation/branch to CI gate readiness.

- [ ] **Step 4: Verify governance/backlog**

Run:

```sh
cd packages/zigeffect
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

Expected: new schema and delivered backlog item are present; recommendation
points to `start-production-telemetry-ci-gate-readiness`.

## Task 5: Docs And Verification

**Files:**
- Add: `packages/zigeffect/docs/production-telemetry-ci-archive-evidence-policy.md`
- Modify docs listed in the file map.

- [ ] **Step 1: Add user-facing docs**

Document command, source evidence, evidence classes, interpretation rules,
negative fixtures, status semantics, and agent guidance.

- [ ] **Step 2: Update index docs**

Update README, operations, roadmap, schema governance, backlog, completion
audit, archive application docs, and master roadmap.

- [ ] **Step 3: Run full verification**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-archive-evidence-policy -- --help
zig build causal-production-telemetry-ci-archive-evidence-policy -- \
  --from-archive-application ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-archive-application.json \
  approve \
  --reason "CI archive evidence policy reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-archive-application" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-production-telemetry-ci-archive-evidence-policy -- \
  --from-archive-application ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-archive-application.json \
  reject \
  --reason "negative CI archive evidence policy path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-archive-evidence-policy-negative
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

Expected: all commands pass and final worktree is clean after commits.

