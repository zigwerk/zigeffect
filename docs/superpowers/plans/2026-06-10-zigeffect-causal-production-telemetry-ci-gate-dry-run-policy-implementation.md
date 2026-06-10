# zigeffect Causal Production Telemetry CI Gate Dry-Run Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a record-only dry-run policy report that consumes CI gate application boundary artifacts and defines advisory candidate-signal policy before any CI gate enforcement.

**Architecture:** Follow the existing production telemetry tool pattern: a deterministic Zig CLI consumes a source JSON artifact, validates source authority and evidence, emits paired JSON/text artifacts, and updates build wiring, schema governance, backlog, and docs. The policy is advisory only and hands off to a future dry-run evaluator.

**Tech Stack:** Zig 0.16 build tools, `std.json`, repo-local causal artifact conventions, Bun for repo-level verification.

---

### Task 1: Create The Dry-Run Policy Tool With A Failing Test

**Files:**
- Create: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_dry_run_policy.zig`

- [ ] **Step 1: Add test-only constants**

Create the file with tests that expect:

```zig
pub const production_telemetry_ci_gate_dry_run_policy_schema = "zigeffect.causal.production-telemetry-ci-gate-dry-run-policy.v1";
pub const production_telemetry_ci_gate_dry_run_policy_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-dry-run-policy";
pub const recommendation = "start-production-telemetry-ci-gate-dry-run-evaluator";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-ci-gate-dry-run-evaluator";
```

- [ ] **Step 2: Run the failing test**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_dry_run_policy.zig
```

Expected: fails with an undeclared schema constant until implementation exists.

### Task 2: Implement Source Validation And Policy Evaluation

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_dry_run_policy.zig`

- [ ] **Step 1: Add parser and required commands**

The parser must accept:

```text
--from-gate-application-boundary <gate-application-boundary.json>
approve|reject
--reason <reason>
--by <actor>
--policy <policy>
--verified-command <command>
--out-prefix <path-prefix>
```

Use this exact command list:

```zig
const required_verification_commands: []const []const u8 = &.{
    "zig build causal-production-telemetry-ci-gate-application-boundary",
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

Parse `zigeffect.causal.production-telemetry-ci-gate-application-boundary.v1`
with ignored unknown fields. Include source fields for:

```zig
schema, schema_version, source_ci_gate_readiness, source_workflow_digest,
mode, gate_application_status, applied, mutation_authority,
ci_gate_enabled, ci_gate_enforcement_enabled,
ci_required_status_check_enabled, ci_workflow_mutation_enabled,
ci_upload_execution_enabled, production_telemetry_ingestion,
live_exporter_enabled, network_send_enabled, collector_endpoint_configured,
otlp_serialization_enabled, runtime_pipeline_enabled,
durable_write_enabled, nendb_write_enabled, boundary_checks,
application_boundary_rules, denied_application_claims, negative_fixtures,
blocked_claims, required_verification_commands, verified_commands
```

- [ ] **Step 3: Implement source validation**

Validation passes only when:

```zig
source.schema == "zigeffect.causal.production-telemetry-ci-gate-application-boundary.v1"
source.schema_version == 1
source.gate_application_status == "planned" or "applied"
source.mode == "plan" or "record-applied"
source.applied == false implies source.mutation_authority == "none"
source.applied == true implies source.mutation_authority == "record-only"
all CI gate/enforcement/status-check/workflow/upload/live/runtime/durable/NenDB booleans are false
source boundary checks contain no fail statuses
source application boundary rules are non-empty
source denied application claims are non-empty
source negative fixtures are non-empty
source blocked claims are non-empty
```

- [ ] **Step 4: Implement policy decision**

`approve` plus valid source plus every required verification command produces:

```text
dry_run_policy_status="ready"
ready_for_next_branch=true
```

`reject`, invalid source, or incomplete verification produces:

```text
dry_run_policy_status="blocked"
ready_for_next_branch=false
```

### Task 3: Implement Output Formatting

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_dry_run_policy.zig`

- [ ] **Step 1: Implement output paths**

Default output should replace terminal
`-ci-gate-application-boundary.json` with `-ci-gate-dry-run-policy.json`.

- [ ] **Step 2: Implement JSON and text output**

JSON must include:

```text
schema, schema_version, source_ci_gate_application_boundary,
source_gate_application_status, decision, dry_run_policy_status,
ready_for_next_branch, reviewed_by, policy, reason, applied,
mutation_authority, disabled authority fields, dry_run_policy_rules,
candidate_signal_policies, evidence_requirements, negative_fixtures, checks,
required_verification_commands, verified_commands, blocked_claims,
recommendation, next_branch_if_ready, output_paths, agent_guidance
```

Text output must include:

```text
schema:
source CI gate application boundary:
dry_run_policy_status:
ready_for_next_branch:
ci gate enabled:
ci gate enforcement enabled:
ci required status check enabled:
recommendation:
next branch if ready:
checks:
dry-run policy rules:
candidate signal policies:
evidence requirements:
negative fixtures:
```

- [ ] **Step 3: Run unit tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_dry_run_policy.zig
```

Expected: all tests pass.

### Task 4: Wire Build Step And Generate Real Artifacts

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add build wiring after the gate application boundary tool**

Add module, executable, run step, test artifact, and test dependency for:

```text
zigeffect-causal-production-telemetry-ci-gate-dry-run-policy
causal-production-telemetry-ci-gate-dry-run-policy
zigeffect-causal-production-telemetry-ci-gate-dry-run-policy-tests
```

- [ ] **Step 2: Run help command**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-dry-run-policy -- --help
```

Expected: usage text prints and exits 0.

- [ ] **Step 3: Generate ready artifact**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-dry-run-policy -- \
  --from-gate-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-application-boundary.json \
  approve \
  --reason "CI gate dry-run policy reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-gate-application-boundary" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Expected: `dry_run_policy_status: ready` and `ready_for_next_branch: true`.

- [ ] **Step 4: Generate blocked artifact**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-dry-run-policy -- \
  --from-gate-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-application-boundary.json \
  reject \
  --reason "negative CI gate dry-run policy path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-dry-run-policy-negative
```

Expected: `dry_run_policy_status: blocked`.

### Task 5: Register Schema, Backlog, And Docs

**Files:**
- Create: `packages/zigeffect/docs/production-telemetry-ci-gate-dry-run-policy.md`
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Add schema governance entry**

Add schema:

```text
zigeffect.causal.production-telemetry-ci-gate-dry-run-policy.v1
```

Compatibility:

```text
strict-v1
record-only
ci-gate-dry-run-policy
advisory-policy
candidate-signal-policy
cluster-release-gate-aware
no-live-ingestion
no-network
no-durable-write
no-nendb-write
no-ci-gate-enforcement
no-required-status-check
no-workflow-mutation
```

Increment schema count from 64 to 65.

- [ ] **Step 2: Add backlog item**

Add delivered backlog item:

```text
production-telemetry-ci-gate-dry-run-policy
```

Update current recommendation to:

```text
start-production-telemetry-ci-gate-dry-run-evaluator
```

Update current next branch to:

```text
codex/zigeffect-causal-production-telemetry-ci-gate-dry-run-evaluator
```

- [ ] **Step 3: Add documentation and stale-reference scan**

Document command, source validation, dry-run policy rules, candidate signal
policies, evidence requirements, negative fixtures, output paths, agent
guidance, and verification.

Run:

```sh
rg -n 'start-production-telemetry-ci-gate-dry-run-policy|recommended next branch: codex/zigeffect-causal-production-telemetry-ci-gate-dry-run-policy|"recommended_next_branch": "codex/zigeffect-causal-production-telemetry-ci-gate-dry-run-policy"' packages/zigeffect docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
```

Expected: no stale current-next references except historical source constants
and previous milestone docs.

### Task 6: Full Verification And Commit

**Files:**
- All files touched above

- [ ] **Step 1: Format Zig files**

Run:

```sh
zig fmt packages/zigeffect/build.zig packages/zigeffect/tools/causal_schema_governance.zig packages/zigeffect/tools/causal_production_hardening_backlog.zig packages/zigeffect/tools/causal_production_telemetry_ci_gate_dry_run_policy.zig
```

- [ ] **Step 2: Run focused verification**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_dry_run_policy.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-production-telemetry-ci-gate-dry-run-policy -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

- [ ] **Step 3: Run real artifact paths**

Run the ready and blocked commands from Task 4.

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
git add docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-dry-run-policy-design.md docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-dry-run-policy-implementation.md packages/zigeffect docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "feat(zigeffect): add production telemetry ci gate dry-run policy"
```
