# zigeffect Causal Artifact Access Control Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the deterministic artifact access-control contract for causal artifact bundles and workbench/agent consumers.

**Architecture:** Add one record-only Zig report tool that emits text/JSON policy fixtures, wire it into `build.zig`, register its schema, and update docs/backlog state. The tool defines visibility, roles, permissions, access decisions, negative fixtures, and audit fields without enforcing live RBAC.

**Tech Stack:** Zig 0.16 report tool and inline tests, existing zigeffect production-hardening report patterns, Bun verification.

---

## File Structure

- Create `packages/zigeffect/tools/causal_artifact_access_control.zig`.
  This owns schema constants, policy fixtures, formatting, option parsing, and
  inline tests.
- Create `packages/zigeffect/docs/artifact-access-control.md`.
  This documents visibility, roles, permissions, audit records, and boundaries.
- Modify `packages/zigeffect/build.zig` to add
  `causal-artifact-access-control`.
- Modify `packages/zigeffect/tools/causal_schema_governance.zig` to add
  `zigeffect.causal.artifact-access-control.v1`.
- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig` to
  mark `artifact-access-control` delivered and advance the next branch.
- Modify README, operations, schema governance, roadmap, and master roadmap docs
  to mention the access-control contract.

## Task 1: Add The Failing Access-Control Tool Test

**Files:**
- Create: `packages/zigeffect/tools/causal_artifact_access_control.zig`

- [ ] **Step 1: Write the failing test and minimal declarations**

Create the file with constants, placeholder formatters, placeholder parser, and
tests that describe the required contract:

```zig
const std = @import("std");

pub const artifact_access_control_schema = "zigeffect.causal.artifact-access-control.v1";
pub const artifact_access_control_schema_version: u32 = 1;
pub const aggregation_contract_schema = "zigeffect.causal.production-artifact-aggregation.v1";
pub const durable_retention_contract_schema = "zigeffect.causal.durable-production-retention.v1";
pub const deployment_runbooks_contract_schema = "zigeffect.causal.production-deployment-runbooks.v1";
pub const recommendation = "start-unified-causal-spine-contract";
pub const recommended_next_branch = "codex/zigeffect-causal-unified-spine-contract";

const OutputFormat = enum { text, json };

pub fn formatArtifactAccessControlText(allocator: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
    _ = allocator;
    return error.OutOfMemory;
}

pub fn formatArtifactAccessControlJson(allocator: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
    _ = allocator;
    return error.OutOfMemory;
}

fn parseOptions(args: []const []const u8) !OutputFormat {
    _ = args;
    return error.UnknownFlag;
}

test "artifact access control metadata names schema source contracts and next branch" {
    try std.testing.expectEqualStrings("zigeffect.causal.artifact-access-control.v1", artifact_access_control_schema);
    try std.testing.expectEqual(@as(u32, 1), artifact_access_control_schema_version);
    try std.testing.expectEqualStrings("zigeffect.causal.production-artifact-aggregation.v1", aggregation_contract_schema);
    try std.testing.expectEqualStrings("zigeffect.causal.durable-production-retention.v1", durable_retention_contract_schema);
    try std.testing.expectEqualStrings("zigeffect.causal.production-deployment-runbooks.v1", deployment_runbooks_contract_schema);
    try std.testing.expectEqualStrings("start-unified-causal-spine-contract", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-unified-spine-contract", recommended_next_branch);
}

test "artifact access control text includes roles permissions and negative fixtures" {
    const report = try formatArtifactAccessControlText(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "schema: zigeffect.causal.artifact-access-control.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "visibility classes:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "agent-readonly") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "view-redacted-artifact") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "external-reviewer-production-json-denied") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production mutation authority") != null);
}

test "artifact access control json includes audit record fields" {
    const report = try formatArtifactAccessControlJson(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.artifact-access-control.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"audit_record_fields\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "actor_role") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "requested_permission") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "mutation_authority") != null);
}

test "artifact access control parses text json and errors" {
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{"zigeffect-causal-artifact-access-control"}));
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{ "zigeffect-causal-artifact-access-control", "--format", "text" }));
    try std.testing.expectEqual(OutputFormat.json, try parseOptions(&.{ "zigeffect-causal-artifact-access-control", "--format", "json" }));
    try std.testing.expectError(error.UnknownFormat, parseOptions(&.{ "zigeffect-causal-artifact-access-control", "--format", "yaml" }));
    try std.testing.expectError(error.MissingFormat, parseOptions(&.{ "zigeffect-causal-artifact-access-control", "--format" }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(&.{ "zigeffect-causal-artifact-access-control", "--json" }));
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_artifact_access_control.zig
```

Expected: FAIL because the placeholder formatters and parser do not implement
the contract.

## Task 2: Implement The Access-Control Tool

**Files:**
- Modify: `packages/zigeffect/tools/causal_artifact_access_control.zig`

- [ ] **Step 1: Add policy fixtures and formatters**

Implement:

- visibility classes: `local-private`, `ci-internal`, `reviewed-shared`,
  `incident-restricted`, `production-retained`, `external-summary`;
- roles: `maintainer`, `release-owner`, `incident-owner`, `auditor`,
  `agent-readonly`, `external-reviewer`;
- permissions: `view-metadata`, `view-redacted-artifact`,
  `view-incident-artifact`, `view-retained-bundle`,
  `share-internal-summary`, `share-external-summary`, `request-review`,
  `record-access-audit`;
- decisions: `allow`, `deny`, `review-required`, `redacted-only`;
- negative fixtures with denied or review-required outcomes;
- audit record fields from the design;
- text and JSON formatting helpers;
- `main()` using `std.process.Init`.

- [ ] **Step 2: Run the focused test**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_artifact_access_control.zig
```

Expected: PASS.

## Task 3: Wire Build And Schema Governance

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`

- [ ] **Step 1: Add build step**

Add executable/test wiring for `causal-artifact-access-control` beside the
other production-hardening tools.

- [ ] **Step 2: Add schema governance entry**

Register `zigeffect.causal.artifact-access-control.v1` as a
production-hardening, record-only schema emitted by
`causal-artifact-access-control` and consumed by the SolidJS workbench,
agent query interface, live dashboard, integrations, and future production
hosts.

- [ ] **Step 3: Run focused build/governance commands**

Run:

```sh
cd packages/zigeffect
zig build causal-artifact-access-control
zig build causal-artifact-access-control -- --format json
zig build causal-schema-governance
zig build causal-schema-governance -- --format json
```

Expected: all commands exit 0 and schema governance includes
`zigeffect.causal.artifact-access-control.v1`.

## Task 4: Update Backlog And Docs

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Create: `packages/zigeffect/docs/artifact-access-control.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Update backlog state**

Mark `artifact-access-control` delivered, add the new tool/doc evidence, and
advance recommendation to `start-unified-causal-spine-contract` with next
branch `codex/zigeffect-causal-unified-spine-contract` when that backlog item
is present.

- [ ] **Step 2: Write docs**

Document command usage, visibility classes, roles, permissions, access
decisions, audit record fields, negative fixtures, and non-goals. Keep the
boundary explicit: policy-only, no live RBAC, no production mutation authority.

- [ ] **Step 3: Run report checks**

Run:

```sh
cd packages/zigeffect
zig build causal-artifact-access-control
zig build causal-production-hardening-backlog
zig build causal-schema-governance
```

Expected: access control is delivered and the next branch is the unified causal
spine contract.

## Task 5: Full Verification And Commit

**Files:**
- All files modified by this plan.

- [ ] **Step 1: Run full verification**

Run:

```sh
cd packages/zigeffect
zig build causal-artifact-access-control
zig build causal-artifact-access-control -- --format json
zig build causal-production-deployment-runbooks
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

Expected: all commands exit 0. Existing live-Cockroach skips remain skips.

- [ ] **Step 2: Review scope and commit**

Run:

```sh
git status --short
git diff --cached --stat
git commit -m "feat(zigeffect): add causal artifact access control"
```

Expected: only access-control implementation and intentionally incorporated
roadmap/backlog files are committed.

## Self-Review

- Spec coverage: every design requirement maps to a task.
- Placeholder scan: no placeholder task remains.
- Type consistency: schema, command, recommendation, and branch names match
  across tasks.
