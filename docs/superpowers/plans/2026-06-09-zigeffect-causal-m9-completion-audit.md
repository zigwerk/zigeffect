# zigeffect Causal M9 Completion Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a deterministic M9 completion audit artifact that proves the causal operating model deliverables and records deferred production hardening gaps.

**Architecture:** Add a Zig report tool with text and JSON output, register its schema, document interpretation, and update roadmaps from active M9 work to delivered M9 plus future production-hardening backlog. The report is record-only and does not execute production checks, mutate source, or replace the full verification suite.

**Tech Stack:** Zig 0.16 build steps and tests, existing zigeffect causal report patterns, Bun verification commands, SolidJS plus `webui-dev/zig-webui` documentation.

---

## Files And Responsibilities

- Create `packages/zigeffect/tools/causal_m9_completion_audit.zig`
  - Owns `zigeffect.causal.m9-completion-audit.v1`.
  - Exposes deliverable checks, verification commands, production gaps, and the final recommendation.
  - Provides text and JSON output plus unit tests.

- Modify `packages/zigeffect/build.zig`
  - Adds `zig build causal-m9-completion-audit`.
  - Runs audit tool tests under `zig build test`.

- Modify `packages/zigeffect/tools/causal_schema_governance.zig`
  - Adds the M9 completion audit schema.
  - Updates schema count expectations from 32 to 33.

- Create `packages/zigeffect/docs/m9-completion-audit.md`
  - Explains command usage, deliverable interpretation, deferred production gaps, and the verification suite.

- Modify `packages/zigeffect/README.md`
  - Links the M9 audit command near operations, schema governance, and performance budget.

- Modify `packages/zigeffect/docs/operations.md`
  - Adds the command to the command map and explains how to interpret the completion audit.

- Modify `packages/zigeffect/docs/schema-governance.md`
  - Adds `zigeffect.causal.m9-completion-audit.v1` under Operating Model.

- Modify `packages/zigeffect/docs/roadmap.md`
  - Adds a delivered note for the completion audit.

- Modify `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Marks M9 as delivered after verification.
  - Replaces the immediate M9 branch queue with future production-hardening backlog triage.

## Task 1: Add The Failing M9 Audit Tool Tests

**Files:**
- Create: `packages/zigeffect/tools/causal_m9_completion_audit.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Create the tool file with failing target behavior**

Create `packages/zigeffect/tools/causal_m9_completion_audit.zig` with tests for:

```zig
pub const m9_completion_audit_schema = "zigeffect.causal.m9-completion-audit.v1";
pub const m9_completion_audit_schema_version: u32 = 1;
pub const recommendation = "deliver-m9-with-deferred-production-hardening";
```

The initial tests should expect:

```zig
try std.testing.expectEqual(@as(usize, 11), deliverableChecks().len);
try std.testing.expectEqual(@as(usize, 13), verificationCommands().len);
try std.testing.expectEqual(@as(usize, 11), productionGaps().len);
try expectDeliverable("schema-governance-tool");
try expectDeliverable("performance-budget-tool");
try expectDeliverable("production-gap-register");
try expectProductionGap("durable-production-retention");
try expectProductionGap("wall-clock-benchmark-gates");
```

Add text and JSON tests requiring these strings:

```text
zigeffect causal M9 completion audit
schema: zigeffect.causal.m9-completion-audit.v1
recommendation: deliver-m9-with-deferred-production-hardening
schema-governance-tool
SolidJS inside webui-dev/zig-webui
production gaps:
```

```json
"schema": "zigeffect.causal.m9-completion-audit.v1"
"recommendation": "deliver-m9-with-deferred-production-hardening"
"deliverable_checks"
"production_gaps"
"verification_commands"
```

Add parse option tests for default text, `--format text`, `--format json`, bad format, bare `--format`, and unknown flag.

- [ ] **Step 2: Wire the new module into `build.zig`**

After the performance-budget tool block in `packages/zigeffect/build.zig`, add:

```zig
    const causal_m9_completion_audit_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_m9_completion_audit.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_m9_completion_audit_tool = b.addExecutable(.{
        .name = "zigeffect-causal-m9-completion-audit",
        .root_module = causal_m9_completion_audit_tool_module,
    });
    const run_causal_m9_completion_audit_tool = b.addRunArtifact(causal_m9_completion_audit_tool);
    if (b.args) |args| run_causal_m9_completion_audit_tool.addArgs(args);
    const causal_m9_completion_audit_step = b.step("causal-m9-completion-audit", "Print causal M9 operating-model completion audit");
    causal_m9_completion_audit_step.dependOn(&run_causal_m9_completion_audit_tool.step);

    const causal_m9_completion_audit_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-m9-completion-audit-tests",
        .root_module = causal_m9_completion_audit_tool_module,
    });
    const run_causal_m9_completion_audit_tool_tests = b.addRunArtifact(causal_m9_completion_audit_tool_tests);
    test_step.dependOn(&run_causal_m9_completion_audit_tool_tests.step);
```

- [ ] **Step 3: Verify RED**

Run:

```sh
cd packages/zigeffect
zig build test
```

Expected: the new M9 audit tests fail because the report arrays and formatters are not implemented.

## Task 2: Implement The M9 Audit Report

**Files:**
- Modify: `packages/zigeffect/tools/causal_m9_completion_audit.zig`

- [ ] **Step 1: Implement deliverable checks**

Use a `DeliverableCheck` struct with fields:

```zig
id: []const u8,
status: []const u8,
evidence: []const u8,
source: []const u8,
agent_guidance: []const u8,
```

Define exactly these deliverables:

```text
schema-governance-tool
schema-governance-doc
operations-manual
performance-budget-tool
performance-budget-doc
release-guidance
ci-workflow
artifact-manifest
test-matrix
workbench-direction
production-gap-register
```

Use status `passed` for command-backed entries and `documented` for doc-backed entries.

- [ ] **Step 2: Implement verification commands and production gaps**

`verificationCommands()` should return:

```text
cd packages/zigeffect
zig build causal-m9-completion-audit
zig build causal-m9-completion-audit -- --format json
zig build causal-schema-governance
zig build causal-performance-budget
zig build causal-artifacts
zig build causal-test-matrix
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

`productionGaps()` should return:

```text
distributed-artifact-aggregation
durable-production-retention
production-deployment-runbooks
alerting-paging-integrations
rbac-access-control
encryption-at-rest-policy
live-dashboards-streaming-workbench
automated-mutation-authority
gradual-rollout-automation
wall-clock-benchmark-gates
production-capacity-planning
```

The verification command count is 13 because it includes both directory changes.

- [ ] **Step 3: Implement text and JSON output**

The text report should contain:

```text
zigeffect causal M9 completion audit
schema: zigeffect.causal.m9-completion-audit.v1
schema_version: 1
status: current
recommendation: deliver-m9-with-deferred-production-hardening
```

Then print `deliverable checks`, `verification commands`, and `production gaps`.

The JSON report should contain:

```json
{
  "schema": "zigeffect.causal.m9-completion-audit.v1",
  "schema_version": 1,
  "status": "current",
  "recommendation": "deliver-m9-with-deferred-production-hardening",
  "deliverable_checks": [],
  "verification_commands": [],
  "production_gaps": [],
  "non_goals": []
}
```

Use local JSON string escaping helpers matching `causal_schema_governance.zig`.

- [ ] **Step 4: Verify GREEN**

Run:

```sh
cd packages/zigeffect
zig build test
zig build causal-m9-completion-audit
zig build causal-m9-completion-audit -- --format json
```

Expected: all commands pass and the outputs include the schema and recommendation.

## Task 3: Register The Audit Schema

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/docs/schema-governance.md`

- [ ] **Step 1: Add schema governance entry**

Add this entry near `zigeffect.causal.performance-budget.v1`:

```zig
    .{
        .schema = "zigeffect.causal.m9-completion-audit.v1",
        .version = 1,
        .category = "operating-model",
        .status = "current",
        .emitted_by = &.{"causal-m9-completion-audit"},
        .consumed_by = &.{ "agents", "reviewers", "roadmap audit" },
        .compatibility = &.{"record-only"},
        .governance_requirements = &.{ "completion audit tests", "operations docs", "roadmap update" },
    },
```

Update schema count tests from 32 to 33 and expect the new schema in text and JSON tests.

- [ ] **Step 2: Update schema governance docs**

Under Operating Model in `packages/zigeffect/docs/schema-governance.md`, add:

```md
- `zigeffect.causal.m9-completion-audit.v1`

The M9 completion audit is a record-only operating-model artifact. It proves the
local/CI causal operating-model deliverables, records deferred production gaps,
and gives agents a stable recommendation before the roadmap marks M9 delivered.
```

- [ ] **Step 3: Verify schema governance**

Run:

```sh
cd packages/zigeffect
zig build causal-schema-governance
zig build causal-schema-governance -- --format json
zig build test
```

Expected: schema count is 33 and all tests pass.

## Task 4: Add Audit Documentation And Roadmap Updates

**Files:**
- Create: `packages/zigeffect/docs/m9-completion-audit.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Create the audit guide**

Create `packages/zigeffect/docs/m9-completion-audit.md` with:

```md
# zigeffect Causal M9 Completion Audit

## Command

## Deliverable Checks

## Recommendation

## Deferred Production Gaps

## Verification Suite

## Roadmap Rule
```

Include this interpretation rule:

```md
`deliver-m9-with-deferred-production-hardening` means the M0-M9 causal
self-improvement roadmap is complete for local/CI operating-model purposes, and
the listed production gaps move to future production hardening instead of
blocking M9.
```

- [ ] **Step 2: Link README and operations**

In README, add the command block after the performance budget section:

```sh
cd packages/zigeffect
zig build causal-m9-completion-audit
zig build causal-m9-completion-audit -- --format json
```

In operations, add the same command to the schema/workbench/backend check group and add a short section explaining the recommendation.

- [ ] **Step 3: Update roadmaps**

In `packages/zigeffect/docs/roadmap.md`, add:

```md
- Delivered: `causal-m9-completion-audit` publishes
  `zigeffect.causal.m9-completion-audit.v1` with deliverable checks,
  production-gap acknowledgement, verification commands, and the recommendation
  to deliver M9 with deferred production hardening.
```

In the master roadmap:

- set `M9 Operating model` status to `delivered`;
- set current evidence to `completion audit, schema governance, operations docs, performance budget report, and release guidance exist`;
- set next action to `future production-hardening backlog triage`;
- replace the immediate branch queue with future production-hardening backlog triage.

## Task 5: Final Verification And Commit

**Files:**
- All files from Tasks 1 through 4

- [ ] **Step 1: Run focused M9 commands**

Run:

```sh
cd packages/zigeffect
zig build causal-m9-completion-audit
zig build causal-m9-completion-audit -- --format json
zig build causal-schema-governance
zig build causal-performance-budget
zig build causal-artifacts
zig build causal-test-matrix
```

Expected: all commands pass.

- [ ] **Step 2: Run package verification**

Run:

```sh
cd packages/zigeffect
zig build examples
zig build test
```

Expected: both commands pass.

- [ ] **Step 3: Run repository verification**

Run:

```sh
cd /Users/seanknowles/Desktop/Projects/yachdee
bun run check
bun run zig:test
git diff --check
```

Expected: all commands pass.

- [ ] **Step 4: Commit implementation**

Stage only the M9 audit files and commit:

```sh
git add packages/zigeffect/tools/causal_m9_completion_audit.zig \
  packages/zigeffect/build.zig \
  packages/zigeffect/tools/causal_schema_governance.zig \
  packages/zigeffect/docs/m9-completion-audit.md \
  packages/zigeffect/README.md \
  packages/zigeffect/docs/operations.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/docs/roadmap.md \
  docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "feat(zigeffect): add causal M9 completion audit"
```

Do not stage the unrelated untracked durable roadmap file.
