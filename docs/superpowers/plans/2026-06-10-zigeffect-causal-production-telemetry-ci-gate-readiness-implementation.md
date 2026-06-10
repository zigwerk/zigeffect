# zigeffect Causal Production Telemetry CI Gate Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a record-only CI gate readiness report that consumes archive evidence policy artifacts and hands off to a later gate application boundary without enabling gates.

**Architecture:** Follow the existing production telemetry tool pattern: a single deterministic Zig CLI emits paired JSON/text artifacts, build.zig wires the executable and tests, schema governance/backlog register the schema, and docs carry the handoff. The readiness tool validates source policy evidence, gate semantics, release-gate verification, negative fixtures, and disabled authority.

**Tech Stack:** Zig 0.16 build tools, `std.json`, `std.Io`, repo-local causal artifact conventions, Bun only for repo-level checks.

---

### Task 1: Create The Gate Readiness Tool With Failing Tests

**Files:**
- Create: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_readiness.zig`

- [ ] **Step 1: Add constants, CLI option parser, source artifact structs, static catalogs, and tests first**

Create the file with tests that expect:

```zig
pub const production_telemetry_ci_gate_readiness_schema = "zigeffect.causal.production-telemetry-ci-gate-readiness.v1";
pub const production_telemetry_ci_gate_readiness_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-readiness";
pub const recommendation = "start-production-telemetry-ci-gate-application-boundary";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-ci-gate-application-boundary";
```

The parser must accept:

```text
--from-archive-evidence-policy <archive-evidence-policy.json>
approve|reject
--reason <reason>
--by <actor>
--policy <policy>
--verified-command <command>
--out-prefix <path-prefix>
```

Required verification commands:

```zig
const required_verification_commands: []const []const u8 = &.{
    "zig build causal-production-telemetry-ci-archive-evidence-policy",
    "zig build causal-artifacts",
    "zig build release-gate --summary none",
    "zig build release-gate-report",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
};
```

- [ ] **Step 2: Run the failing test**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_readiness.zig
```

Expected: fails until the full implementation exists.

### Task 2: Implement Readiness Evaluation And Formatting

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_readiness.zig`

- [ ] **Step 1: Implement source validation**

Validate source fields from
`zigeffect.causal.production-telemetry-ci-archive-evidence-policy.v1`:

```zig
fn sourcePolicyReady(source: ArchiveEvidencePolicyArtifact) bool {
    return std.mem.eql(u8, source.archive_evidence_policy_status, "ready") and
        source.ready_for_next_branch and
        !source.applied and
        std.mem.eql(u8, source.mutation_authority, "none") and
        !source.ci_gate_enabled and
        !source.ci_upload_execution_enabled and
        !source.ci_workflow_mutation_enabled and
        !source.production_telemetry_ingestion and
        !source.live_exporter_enabled and
        !source.network_send_enabled and
        !source.collector_endpoint_configured and
        !source.otlp_serialization_enabled and
        !source.runtime_pipeline_enabled and
        !source.durable_write_enabled and
        !source.nendb_write_enabled;
}
```

- [ ] **Step 2: Implement catalogs**

Add readiness dimensions:

```text
source-policy-ready
archive-evidence-bounded
release-gate-contract-present
cluster-workflow-aligned
gate-semantics-limited
redaction-retention-reviewed
human-review-before-application
```

Add candidate gate signals with `enforcement_enabled=false`:

```text
release-gate-artifact-present
causal-artifact-schema-parse
archive-policy-conformance
redaction-retention-conformance
ci-handoff-present
```

Add negative fixtures from the design.

- [ ] **Step 3: Implement output paths**

Default output should replace the terminal
`-ci-archive-evidence-policy.json` suffix with
`-ci-gate-readiness.json`. If a source path does not have that suffix, append
`-ci-gate-readiness` to the base path.

- [ ] **Step 4: Implement text and JSON report formatting**

JSON must include all fields from the design, including disabled authority
fields, checks, catalogs, required and verified commands, blocked claims,
recommendation, and output paths.

Text output must include:

```text
schema:
source archive evidence policy:
gate_readiness_status:
ready_for_next_branch:
ci gate enabled:
ci gate enforcement enabled:
recommendation:
next branch if ready:
checks:
readiness dimensions:
candidate gate signals:
negative fixtures:
```

- [ ] **Step 5: Run unit tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_readiness.zig
```

Expected: all tests pass.

### Task 3: Wire Build Step And Verify Real Artifacts

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add build wiring after the archive evidence policy tool**

Add module, executable, run step, test artifact, and test dependency:

```zig
const causal_production_telemetry_ci_gate_readiness_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_production_telemetry_ci_gate_readiness.zig"),
    .target = target,
    .optimize = optimize,
});
```

Use executable name:

```text
zigeffect-causal-production-telemetry-ci-gate-readiness
```

Use build step:

```text
causal-production-telemetry-ci-gate-readiness
```

- [ ] **Step 2: Run help command**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-readiness -- --help
```

Expected: usage text prints and command exits 0.

- [ ] **Step 3: Generate ready artifact from the real source policy**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-readiness -- \
  --from-archive-evidence-policy ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-archive-evidence-policy.json \
  approve \
  --reason "CI gate readiness reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-archive-evidence-policy" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Expected: `gate_readiness_status: ready`, `ready_for_next_branch: true`, and
next branch `codex/zigeffect-causal-production-telemetry-ci-gate-application-boundary`.

- [ ] **Step 4: Generate blocked artifact**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-readiness -- \
  --from-archive-evidence-policy ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-archive-evidence-policy.json \
  reject \
  --reason "negative CI gate readiness path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-readiness-negative
```

Expected: `gate_readiness_status: blocked`.

### Task 4: Register Schema And Backlog Handoff

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`

- [ ] **Step 1: Add schema governance entry**

Add schema:

```text
zigeffect.causal.production-telemetry-ci-gate-readiness.v1
```

Category: `production-hardening`.

Compatibility:

```text
strict-v1
record-only
ci-gate-readiness
gate-semantics
cluster-release-gate-aware
no-live-ingestion
no-network
no-durable-write
no-nendb-write
no-ci-gate-enforcement
no-workflow-mutation
```

Increment schema count from 62 to 63 and add text/JSON assertions.

- [ ] **Step 2: Add backlog item**

Add delivered backlog item:

```text
production-telemetry-ci-gate-readiness
```

Recommended next branch:

```text
codex/zigeffect-causal-production-telemetry-ci-gate-application-boundary
```

Recommendation:

```text
start-production-telemetry-ci-gate-application-boundary
```

Dependency order should place gate readiness after archive evidence policy.

- [ ] **Step 3: Run focused governance tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog.zig
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

Expected: all commands exit 0, schema count is 63, backlog recommends gate
application boundary.

### Task 5: Update Docs And Roadmaps

**Files:**
- Create: `packages/zigeffect/docs/production-telemetry-ci-gate-readiness.md`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/production-hardening-completion-audit.md`
- Modify: `packages/zigeffect/docs/production-telemetry-ci-archive-evidence-policy.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Add gate readiness doc**

Document command, source evidence, readiness dimensions, candidate gate
signals, negative fixtures, status values, output paths, agent guidance, and
verification.

- [ ] **Step 2: Update handoffs**

All “current next branch” references should point to:

```text
codex/zigeffect-causal-production-telemetry-ci-gate-application-boundary
```

Historical references may continue to describe prior branches.

- [ ] **Step 3: Run stale-reference search**

Run:

```sh
rg -n 'start-production-telemetry-ci-gate-readiness|recommended next branch: codex/zigeffect-causal-production-telemetry-ci-gate-readiness|"recommended_next_branch": "codex/zigeffect-causal-production-telemetry-ci-gate-readiness"' packages/zigeffect docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
```

Expected: no stale current-next references except source constants in the
archive evidence policy tool.

### Task 6: Full Verification And Commit

**Files:**
- All files touched above

- [ ] **Step 1: Format Zig files**

Run:

```sh
zig fmt packages/zigeffect/build.zig packages/zigeffect/tools/causal_schema_governance.zig packages/zigeffect/tools/causal_production_hardening_backlog.zig packages/zigeffect/tools/causal_production_telemetry_ci_gate_readiness.zig
```

- [ ] **Step 2: Run focused verification**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_readiness.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-production-telemetry-ci-gate-readiness -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

- [ ] **Step 3: Run real artifact paths**

Run the approved and rejected commands from Task 3.

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

Expected: all commands exit 0. `bun run check` may report the existing live
Cockroach skips only.

- [ ] **Step 5: Commit**

Run:

```sh
git add docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-readiness-design.md docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-readiness-implementation.md packages/zigeffect
git commit -m "feat(zigeffect): add production telemetry ci gate readiness"
```
