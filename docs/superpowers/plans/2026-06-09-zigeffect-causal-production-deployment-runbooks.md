# zigeffect Causal Production Deployment Runbooks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the deterministic production deployment runbooks contract for causal-instrumented services.

**Architecture:** Follow the existing production-hardening report pattern: one Zig tool emits text/JSON, `build.zig` exposes a build step, schema governance records the schema, and docs/roadmaps consume the result. The tool is record-only and deterministic; deployment, rollback, paging, and production mutation remain outside zigeffect authority.

**Tech Stack:** Zig 0.16 report tool and tests, Bun project verification, existing zigeffect docs and Superpowers roadmap files.

---

## File Structure

- Create `packages/zigeffect/tools/causal_production_deployment_runbooks.zig`.
  This owns schema constants, runbook/gate/template fixtures, text/JSON
  formatting, CLI option parsing, and inline Zig tests.
- Create `packages/zigeffect/docs/production-deployment-runbooks.md`.
  This is the human-facing runbook contract.
- Modify `packages/zigeffect/build.zig` to add the executable and build step
  `causal-production-deployment-runbooks`.
- Modify `packages/zigeffect/tools/causal_schema_governance.zig` to register
  `zigeffect.causal.production-deployment-runbooks.v1`.
- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig` to
  mark deployment runbooks delivered and advance the next branch to artifact
  access control.
- Modify these docs to mention the new contract and next branch:
  `packages/zigeffect/README.md`,
  `packages/zigeffect/docs/agent-observable-runtime.md`,
  `packages/zigeffect/docs/operations.md`,
  `packages/zigeffect/docs/production-hardening-backlog.md`,
  `packages/zigeffect/docs/durable-production-retention.md`,
  `packages/zigeffect/docs/roadmap.md`,
  `packages/zigeffect/docs/schema-governance.md`, and
  `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`.

## Task 1: Add The Failing Deployment Runbooks Tool Test

**Files:**
- Create: `packages/zigeffect/tools/causal_production_deployment_runbooks.zig`

- [ ] **Step 1: Write the failing test and minimal declarations**

Create the file with metadata, placeholder format functions, and tests that
expect the final schema and runbook ids:

```zig
const std = @import("std");

pub const production_deployment_runbooks_schema = "zigeffect.causal.production-deployment-runbooks.v1";
pub const production_deployment_runbooks_schema_version: u32 = 1;
pub const aggregation_contract_schema = "zigeffect.causal.production-artifact-aggregation.v1";
pub const durable_retention_contract_schema = "zigeffect.causal.durable-production-retention.v1";
pub const recommendation = "start-artifact-access-control";
pub const recommended_next_branch = "codex/zigeffect-causal-artifact-access-control";

const OutputFormat = enum { text, json };

pub fn formatProductionDeploymentRunbooksText(allocator: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
    _ = allocator;
    return error.OutOfMemory;
}

pub fn formatProductionDeploymentRunbooksJson(allocator: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
    _ = allocator;
    return error.OutOfMemory;
}

fn parseOptions(args: []const []const u8) !OutputFormat {
    _ = args;
    return error.UnknownFlag;
}

test "production deployment runbooks metadata names schema contracts and next branch" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-deployment-runbooks.v1", production_deployment_runbooks_schema);
    try std.testing.expectEqual(@as(u32, 1), production_deployment_runbooks_schema_version);
    try std.testing.expectEqualStrings("zigeffect.causal.production-artifact-aggregation.v1", aggregation_contract_schema);
    try std.testing.expectEqualStrings("zigeffect.causal.durable-production-retention.v1", durable_retention_contract_schema);
    try std.testing.expectEqualStrings("start-artifact-access-control", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-artifact-access-control", recommended_next_branch);
}

test "production deployment runbooks text includes required runbooks and gates" {
    const report = try formatProductionDeploymentRunbooksText(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "schema: zigeffect.causal.production-deployment-runbooks.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "deployment") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "rollback") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-verification") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "incident-response") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "failure action: block deployment readiness") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production mutation authority") != null);
}

test "production deployment runbooks json includes schema contracts and incident template" {
    const report = try formatProductionDeploymentRunbooksJson(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-deployment-runbooks.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"aggregation_contract_schema\": \"zigeffect.causal.production-artifact-aggregation.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"durable_retention_contract_schema\": \"zigeffect.causal.durable-production-retention.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"incident_template\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "triggering_event_ids") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "verification_commands") != null);
}

test "production deployment runbooks options parse text json and errors" {
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{"zigeffect-causal-production-deployment-runbooks"}));
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{ "zigeffect-causal-production-deployment-runbooks", "--format", "text" }));
    try std.testing.expectEqual(OutputFormat.json, try parseOptions(&.{ "zigeffect-causal-production-deployment-runbooks", "--format", "json" }));
    try std.testing.expectError(error.UnknownFormat, parseOptions(&.{ "zigeffect-causal-production-deployment-runbooks", "--format", "yaml" }));
    try std.testing.expectError(error.MissingFormat, parseOptions(&.{ "zigeffect-causal-production-deployment-runbooks", "--format" }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(&.{ "zigeffect-causal-production-deployment-runbooks", "--json" }));
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_deployment_runbooks.zig
```

Expected: FAIL because the placeholder format functions return
`error.OutOfMemory` and `parseOptions` returns `error.UnknownFlag`.

## Task 2: Implement The Deployment Runbooks Tool

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_deployment_runbooks.zig`

- [ ] **Step 1: Replace placeholders with the implementation**

Implement:

- struct arrays for `Runbook`, `RunbookStep`, `ReadinessGate`, and
  `IncidentTemplateField`;
- four runbooks with ids `deployment`, `rollback`, `causal-verification`, and
  `incident-response`;
- gates for aggregation, durable retention, redaction, pre-deploy baseline,
  human approval, rollback readiness, post-action verification, and incident
  owner;
- non-goals that include Cockroach adapter work, deployment automation,
  production mutation authority, alerting or paging, and React workbench
  support;
- text and JSON formatting helpers similar to
  `causal_durable_production_retention.zig`;
- `main()` that prints text or JSON based on `--format`.

- [ ] **Step 2: Run the focused test to verify it passes**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_deployment_runbooks.zig
```

Expected: PASS, all tests in the file pass.

## Task 3: Wire The Build Step

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add the build executable and step**

Add a module, executable, run artifact, argument forwarding, and build step
named `causal-production-deployment-runbooks` beside the existing production
hardening tools:

```zig
const causal_production_deployment_runbooks_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_production_deployment_runbooks.zig"),
    .target = target,
    .optimize = optimize,
});

const causal_production_deployment_runbooks_tool = b.addExecutable(.{
    .name = "zigeffect-causal-production-deployment-runbooks",
    .root_module = causal_production_deployment_runbooks_tool_module,
});
const run_causal_production_deployment_runbooks_tool = b.addRunArtifact(causal_production_deployment_runbooks_tool);
if (b.args) |args| run_causal_production_deployment_runbooks_tool.addArgs(args);
const causal_production_deployment_runbooks_step = b.step("causal-production-deployment-runbooks", "Print causal production deployment runbooks report");
causal_production_deployment_runbooks_step.dependOn(&run_causal_production_deployment_runbooks_tool.step);
```

- [ ] **Step 2: Run the new build command**

Run:

```sh
cd packages/zigeffect
zig build causal-production-deployment-runbooks
zig build causal-production-deployment-runbooks -- --format json
```

Expected: both commands exit 0 and print the deployment runbooks schema.

## Task 4: Register Schema Governance And Backlog Status

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`

- [ ] **Step 1: Add schema governance record**

Add `zigeffect.causal.production-deployment-runbooks.v1` as a
production-hardening, record-only schema with owner
`causal-production-deployment-runbooks`.

- [ ] **Step 2: Update production backlog recommendation**

Change the backlog constants:

```zig
pub const recommendation = "start-artifact-access-control";
pub const recommended_next_branch = "codex/zigeffect-causal-artifact-access-control";
```

Mark the `production-deployment-runbooks` backlog item as `delivered`, add the
new docs/tool as evidence sources, and include
`zig build causal-production-deployment-runbooks` and
`zig build causal-production-deployment-runbooks -- --format json` in the
verification command list.

- [ ] **Step 3: Run governance and backlog checks**

Run:

```sh
cd packages/zigeffect
zig build causal-schema-governance
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog
zig build causal-production-hardening-backlog -- --format json
```

Expected: schema governance includes the deployment-runbooks schema, and the
backlog recommends `codex/zigeffect-causal-artifact-access-control`.

## Task 5: Write User-Facing Documentation

**Files:**
- Create: `packages/zigeffect/docs/production-deployment-runbooks.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/durable-production-retention.md`

- [ ] **Step 1: Create the deployment runbooks doc**

Document command usage, source contracts, deployment runbook, rollback runbook,
causal verification runbook, incident-response template, authority boundaries,
and verification suite.

- [ ] **Step 2: Update operations and backlog docs**

Add the command to the production operating command map. Explain that the
runbooks are manual and record-only. Mark the production backlog item delivered
and set the next branch to artifact access control.

- [ ] **Step 3: Run the docs-related report commands**

Run:

```sh
cd packages/zigeffect
zig build causal-production-deployment-runbooks
zig build causal-production-hardening-backlog
```

Expected: both reports print the new runbook/backlog state.

## Task 6: Update Roadmaps And Package Index Docs

**Files:**
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Add deployment runbooks to indexes and roadmap**

Mention `causal-production-deployment-runbooks`, schema
`zigeffect.causal.production-deployment-runbooks.v1`, delivered status, manual
authority boundary, and next branch
`codex/zigeffect-causal-artifact-access-control`.

- [ ] **Step 2: Run roadmap/report checks**

Run:

```sh
cd packages/zigeffect
zig build causal-production-deployment-runbooks
zig build causal-production-hardening-backlog
zig build causal-schema-governance
```

Expected: reports agree that deployment runbooks are delivered and artifact
access control is next.

## Task 7: Full Verification And Commit

**Files:**
- All files modified by this plan.

- [ ] **Step 1: Run full verification**

Run:

```sh
cd packages/zigeffect
zig build causal-production-deployment-runbooks
zig build causal-production-deployment-runbooks -- --format json
zig build causal-durable-production-retention
zig build causal-production-artifact-aggregation
zig build causal-production-hardening-backlog
zig build causal-schema-governance
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
git diff --cached --check
```

Expected: all commands exit 0. Existing live-service skips in `bun run check`
remain skips, not failures.

- [ ] **Step 2: Review changed files and avoid unrelated work**

Run:

```sh
git status --short
git diff -- packages/zigeffect docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
```

Expected: only files belonging to this plan are staged for the implementation
commit. Pre-existing unrelated docs changes remain unstaged.

- [ ] **Step 3: Commit**

Run:

```sh
git add packages/zigeffect docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md docs/superpowers/specs/2026-06-09-zigeffect-causal-production-deployment-runbooks-design.md docs/superpowers/plans/2026-06-09-zigeffect-causal-production-deployment-runbooks.md
git commit -m "feat(zigeffect): add causal production deployment runbooks"
```

Expected: commit succeeds on branch
`codex/zigeffect-causal-production-deployment-runbooks`.

## Self-Review

- Spec coverage: every requirement in the design maps to a task above.
- Placeholder scan: no placeholder task remains; every command has expected
  output.
- Type consistency: schema, recommendation, branch, and function names are
  consistent across tasks.
