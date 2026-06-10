# zigeffect Causal Production Telemetry CI Gate Application Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a guarded CI gate application boundary report that consumes CI gate readiness artifacts and records planned, applied, or blocked boundary evidence without enabling CI gate enforcement.

**Architecture:** Follow the existing `causal_production_telemetry_ci_archive_application.zig` pattern: a deterministic Zig CLI consumes a source JSON artifact, evaluates source readiness and boundary evidence, emits paired JSON/text artifacts, and writes no workflow files. Build wiring, schema governance, backlog, and docs register the new schema and handoff.

**Tech Stack:** Zig 0.16 build tools, `std.json`, repo-local causal artifact conventions, Bun for repo-level verification.

---

### Task 1: Create The Gate Application Boundary Tool With A Failing Test

**Files:**
- Create: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_application_boundary.zig`

- [ ] **Step 1: Add test-only constants and parser expectations**

Create the file with tests that expect these constants:

```zig
pub const production_telemetry_ci_gate_application_boundary_schema = "zigeffect.causal.production-telemetry-ci-gate-application-boundary.v1";
pub const production_telemetry_ci_gate_application_boundary_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-application-boundary";
pub const recommendation = "start-production-telemetry-ci-gate-dry-run-policy";
pub const next_branch_if_applied = "codex/zigeffect-causal-production-telemetry-ci-gate-dry-run-policy";
```

The parser must accept:

```text
--from-gate-readiness <ci-gate-readiness.json>
plan|record-applied
--reason <reason>
--by <actor>
--policy <policy>
--workflow-after <workflow.yml>
--workflow-change <path-or-change-id>
--before <evidence>
--after <evidence>
--verified-command <command>
--out-prefix <path-prefix>
```

- [ ] **Step 2: Run the failing test**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_application_boundary.zig
```

Expected: fails until the implementation defines the constants and parser.

### Task 2: Implement Source Validation And Boundary Evaluation

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_application_boundary.zig`

- [ ] **Step 1: Add required verification commands**

Use this exact command list:

```zig
const required_verification_commands: []const []const u8 = &.{
    "zig build causal-production-telemetry-ci-gate-readiness",
    "zig build causal-artifacts",
    "zig build release-gate --summary none",
    "zig build release-gate-report",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
};
```

- [ ] **Step 2: Add source artifact structs**

Parse `zigeffect.causal.production-telemetry-ci-gate-readiness.v1` with ignored
unknown fields. Include source fields for:

```zig
schema, schema_version, source_archive_evidence_policy,
source_workflow_digest, decision, gate_readiness_status,
ready_for_next_branch, applied, mutation_authority,
ci_gate_enabled, ci_gate_enforcement_enabled,
ci_required_status_check_enabled, ci_workflow_mutation_enabled,
ci_upload_execution_enabled, production_telemetry_ingestion,
live_exporter_enabled, network_send_enabled,
collector_endpoint_configured, otlp_serialization_enabled,
runtime_pipeline_enabled, durable_write_enabled, nendb_write_enabled,
readiness_dimensions, candidate_gate_signals, gate_semantics,
negative_fixtures, checks, required_verification_commands,
verified_commands, blocked_claims
```

- [ ] **Step 3: Implement source validation**

Source validation passes only when:

```zig
schema == "zigeffect.causal.production-telemetry-ci-gate-readiness.v1"
schema_version == 1
decision == "approve"
gate_readiness_status == "ready"
ready_for_next_branch == true
applied == false
mutation_authority == "none"
all gate/enforcement/workflow/upload/live/runtime/durable/NenDB booleans are false
readiness_dimensions.len > 0
candidate_gate_signals.len > 0
gate_semantics.len > 0
negative_fixtures.len > 0
blocked_claims.len > 0
source checks are all pass
source required verification commands are all in source verified commands
```

- [ ] **Step 4: Implement modes**

`plan` mode:

- returns `gate_application_status="planned"` if source validation passes;
- always sets `applied=false`;
- always sets `mutation_authority="none"`;
- records workflow, before, after, and post-verification checks as skipped;
- never enables gate enforcement or required status checks.

`record-applied` mode:

- requires at least one `--workflow-change`;
- requires at least one `--before`;
- requires at least one `--after`;
- requires `--workflow-after <workflow.yml>`;
- requires every command in `required_verification_commands`;
- requires after-workflow safety checks to pass;
- returns `applied=true` and `mutation_authority="record-only"` only when every
  check passes.

### Task 3: Implement Output Formatting

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_application_boundary.zig`

- [ ] **Step 1: Implement output paths**

Default output should replace terminal `-ci-gate-readiness.json` with
`-ci-gate-application-boundary.json`. If the source path has another JSON
suffix, append `-ci-gate-application-boundary` to its base path.

- [ ] **Step 2: Implement JSON output**

JSON must include:

```text
schema, schema_version, source_ci_gate_readiness, source_workflow_digest,
mode, gate_application_status, applied, mutation_authority,
ci_gate_enabled, ci_gate_enforcement_enabled,
ci_required_status_check_enabled, ci_workflow_mutation_enabled,
ci_upload_execution_enabled, production_telemetry_ingestion,
runtime_pipeline_enabled, durable_write_enabled, nendb_write_enabled,
reviewed_by, policy, reason, workflow_after_path, after_workflow_digest,
workflow_changes, before_evidence, after_evidence, source_checks,
boundary_checks, after_workflow_required_features,
after_workflow_prohibited_features, application_boundary_rules,
denied_application_claims, negative_fixtures, blocked_claims,
required_verification_commands, verified_commands, recommendation,
next_branch_if_applied, json_output, text_output, agent_guidance
```

- [ ] **Step 3: Implement text output**

Text output must include:

```text
schema:
source CI gate readiness:
mode:
gate_application_status:
applied:
mutation_authority:
ci gate enabled:
ci gate enforcement enabled:
ci required status check enabled:
recommendation:
next branch if applied:
checks:
application boundary rules:
denied application claims:
negative fixtures:
```

- [ ] **Step 4: Run unit tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_application_boundary.zig
```

Expected: all tests pass.

### Task 4: Wire The Build Step And Generate Real Artifacts

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add build wiring after the gate readiness tool**

Add module, executable, run step, test artifact, and test dependency for:

```text
zigeffect-causal-production-telemetry-ci-gate-application-boundary
causal-production-telemetry-ci-gate-application-boundary
zigeffect-causal-production-telemetry-ci-gate-application-boundary-tests
```

- [ ] **Step 2: Run help command**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-application-boundary -- --help
```

Expected: usage text prints and exits 0.

- [ ] **Step 3: Generate planned artifact**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-application-boundary -- \
  --from-gate-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-readiness.json \
  plan \
  --reason "CI gate application boundary planned"
```

Expected: `gate_application_status: planned`, `applied: false`, and
`ci gate enforcement enabled: false`.

- [ ] **Step 4: Generate blocked negative artifact**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-application-boundary -- \
  --from-gate-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-readiness.json \
  record-applied \
  --reason "negative CI gate application boundary path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-application-boundary-negative
```

Expected: `gate_application_status: blocked`, `applied: false`.

### Task 5: Register Schema, Backlog, And Docs

**Files:**
- Create: `packages/zigeffect/docs/production-telemetry-ci-gate-application-boundary.md`
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/production-hardening-completion-audit.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Add schema governance entry**

Add schema:

```text
zigeffect.causal.production-telemetry-ci-gate-application-boundary.v1
```

Compatibility:

```text
strict-v1
record-only
gate-application-boundary
plan-or-record-applied
before-after-verification
cluster-release-gate-aware
no-live-ingestion
no-network
no-durable-write
no-nendb-write
no-ci-gate-enforcement
no-tool-workflow-mutation
```

Increment schema count from 63 to 64 and update text/JSON tests.

- [ ] **Step 2: Add backlog item**

Add delivered backlog item:

```text
production-telemetry-ci-gate-application-boundary
```

Update current recommendation to:

```text
start-production-telemetry-ci-gate-dry-run-policy
```

Update current next branch to:

```text
codex/zigeffect-causal-production-telemetry-ci-gate-dry-run-policy
```

- [ ] **Step 3: Add documentation**

Document command, modes, source validation, application boundary rules, safety
checks, negative fixtures, output paths, agent guidance, and verification.

- [ ] **Step 4: Run stale reference search**

Run:

```sh
rg -n 'start-production-telemetry-ci-gate-application-boundary|recommended next branch: codex/zigeffect-causal-production-telemetry-ci-gate-application-boundary|"recommended_next_branch": "codex/zigeffect-causal-production-telemetry-ci-gate-application-boundary"' packages/zigeffect docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
```

Expected: no stale current-next references except historical source constants
and previous milestone docs.

### Task 6: Full Verification And Commit

**Files:**
- All files touched above

- [ ] **Step 1: Format Zig files**

Run:

```sh
zig fmt packages/zigeffect/build.zig packages/zigeffect/tools/causal_schema_governance.zig packages/zigeffect/tools/causal_production_hardening_backlog.zig packages/zigeffect/tools/causal_production_telemetry_ci_gate_application_boundary.zig
```

- [ ] **Step 2: Run focused verification**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_application_boundary.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-production-telemetry-ci-gate-application-boundary -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

- [ ] **Step 3: Run real artifact paths**

Run the planned and blocked commands from Task 4.

- [ ] **Step 4: Run full verification**

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

Expected: all commands exit 0. `bun run check` may report existing live
Cockroach skips only.

- [ ] **Step 5: Commit**

Run:

```sh
git add docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-application-boundary-design.md docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-application-boundary-implementation.md packages/zigeffect docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "feat(zigeffect): add production telemetry ci gate application boundary"
```
