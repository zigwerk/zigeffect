# zigeffect Causal Production Artifact Aggregation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a deterministic production artifact aggregation contract report that defines bundle, source provenance, privacy review, and sample multi-source fixture semantics for future production hardening.

**Architecture:** Add one Zig tool with embedded contract records, text/JSON renderers, CLI parsing, and focused tests. Register its schema, update the production-hardening backlog to hand off to durable production retention, and document the contract boundaries across README, operations, schema governance, roadmap, and the master roadmap.

**Tech Stack:** Zig 0.16, existing zigeffect build tooling, Bun repo checks, markdown docs.

---

## File Structure

- Create: `packages/zigeffect/tools/causal_production_artifact_aggregation.zig`
  - Owns schema constants, bundle contract, provenance fields, privacy gates, sample bundle records, text/JSON renderers, CLI option parsing, and tests.
- Create: `packages/zigeffect/docs/production-artifact-aggregation.md`
  - Explains the aggregation contract, source provenance fields, privacy gates, sample bundle, and non-goals.
- Modify: `packages/zigeffect/build.zig`
  - Adds the executable, build step, and test registration.
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
  - Registers `zigeffect.causal.production-artifact-aggregation.v1` and updates schema-count tests.
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
  - Marks `production-artifact-aggregation` delivered and advances the recommendation to durable production retention.
- Modify: `packages/zigeffect/docs/schema-governance.md`
  - Documents the new schema family.
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
  - Records the new handoff to durable retention after aggregation.
- Modify: `packages/zigeffect/docs/operations.md`
  - Adds the aggregation command and authority boundary.
- Modify: `packages/zigeffect/docs/roadmap.md`
  - Records the delivered aggregation contract.
- Modify: `packages/zigeffect/README.md`
  - Adds command docs near the production-hardening backlog section.
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Updates the immediate branch queue to `codex/zigeffect-causal-durable-production-retention`.

## Task 1: Add Test-First Aggregation Tool Skeleton

**Files:**
- Create: `packages/zigeffect/tools/causal_production_artifact_aggregation.zig`

- [ ] **Step 1: Write failing tests**

Create `packages/zigeffect/tools/causal_production_artifact_aggregation.zig` with this test skeleton:

```zig
const std = @import("std");

pub const production_artifact_aggregation_schema = "zigeffect.causal.production-artifact-aggregation.v1";
pub const production_artifact_aggregation_schema_version: u32 = 1;
pub const recommendation = "use-contract-for-durable-retention";
pub const recommended_next_branch = "codex/zigeffect-causal-durable-production-retention";

const OutputFormat = enum { text, json };

test "production artifact aggregation constants preserve contract boundary" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-artifact-aggregation.v1", production_artifact_aggregation_schema);
    try std.testing.expectEqualStrings("use-contract-for-durable-retention", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-durable-production-retention", recommended_next_branch);
}

test "production artifact aggregation exposes contract sections" {
    try expectArtifactClass("core-runtime");
    try expectArtifactClass("app-remediation");
    try expectSourceKind("ci-baseline");
    try expectSourceKind("governance-chain");
    try expectPrivacyGate("redaction-review");
    try expectSampleSource("ci-baseline-dogfood");
}

test "production artifact aggregation preserves non-goals" {
    try expectNonGoal("live production ingestion");
    try expectNonGoal("durable production storage");
    try expectNonGoal("production mutation authority");
    try expectNonGoal("Cockroach adapter work");
    try expectNonGoal("React workbench support");
}

test "production artifact aggregation text includes bundle provenance and gates" {
    const allocator = std.testing.allocator;
    const report = try formatProductionArtifactAggregationText(allocator);
    defer allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "schema: zigeffect.causal.production-artifact-aggregation.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "bundle contract:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "source provenance fields:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "privacy review gates:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "sample bundle:") != null);
}

test "production artifact aggregation JSON is agent-readable" {
    const allocator = std.testing.allocator;
    const report = try formatProductionArtifactAggregationJson(allocator);
    defer allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-artifact-aggregation.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"bundle_contract\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"source_provenance_fields\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"privacy_review_gates\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"sample_bundle\"") != null);
}

test "production artifact aggregation parses supported formats" {
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{"zigeffect-causal-production-artifact-aggregation"}));
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{ "zigeffect-causal-production-artifact-aggregation", "--format", "text" }));
    try std.testing.expectEqual(OutputFormat.json, try parseOptions(&.{ "zigeffect-causal-production-artifact-aggregation", "--format", "json" }));
    try std.testing.expectError(error.UnknownFormat, parseOptions(&.{ "zigeffect-causal-production-artifact-aggregation", "--format", "yaml" }));
    try std.testing.expectError(error.MissingFormat, parseOptions(&.{ "zigeffect-causal-production-artifact-aggregation", "--format" }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(&.{ "zigeffect-causal-production-artifact-aggregation", "--json" }));
}
```

- [ ] **Step 2: Verify RED**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_artifact_aggregation.zig
```

Expected: compile failure for missing helper and formatter functions.

## Task 2: Implement Aggregation Contract Tool

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_artifact_aggregation.zig`

- [ ] **Step 1: Add deterministic records**

Add records for:

- `BundleContract` with `bundle_id_format`, `required_provenance_fields`, `supported_source_kinds`, `supported_artifact_classes`, `downstream_consumers`;
- `ProvenanceField` with `name`, `required`, `description`;
- `PrivacyGate` with `id`, `status`, `description`, `failure_action`;
- `SampleSource` with `id`, `path`, `schema`, `producer`, `source_kind`, `capture_context`, `trust_boundary`, `redaction_state`, `retention_state`, `query_hint`.

Use deterministic sample ids:

```zig
"ci-baseline-dogfood"
"ci-head-dogfood"
"ci-verdict"
"dev-loop-audit-chain"
"app-application"
```

- [ ] **Step 2: Add text and JSON renderers**

Implement:

```zig
fn formatProductionArtifactAggregationText(allocator: std.mem.Allocator) ![]const u8
fn formatProductionArtifactAggregationJson(allocator: std.mem.Allocator) ![]const u8
fn appendJsonString(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: []const u8) !void
fn appendStringArray(allocator: std.mem.Allocator, output: *std.ArrayList(u8), values: []const []const u8) !void
```

The JSON report must include `bundle_contract`, `source_provenance_fields`, `privacy_review_gates`, `sample_bundle`, `non_goals`, and `verification_commands`.

- [ ] **Step 3: Add CLI parsing and main**

Support:

```sh
zig build causal-production-artifact-aggregation
zig build causal-production-artifact-aggregation -- --format text
zig build causal-production-artifact-aggregation -- --format json
```

- [ ] **Step 4: Verify GREEN directly**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_artifact_aggregation.zig
```

Expected: all direct tool tests pass.

## Task 3: Wire Build And Schema Governance

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/docs/schema-governance.md`

- [ ] **Step 1: Add build step and tests**

Add a module, executable, build step, and test registration after
`causal-production-hardening-backlog`:

```zig
const causal_production_artifact_aggregation_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_production_artifact_aggregation.zig"),
    .target = target,
    .optimize = optimize,
});
```

Use executable name `zigeffect-causal-production-artifact-aggregation` and step
name `causal-production-artifact-aggregation`.

- [ ] **Step 2: Register schema governance**

Add schema entry:

```zig
.{
    .schema = "zigeffect.causal.production-artifact-aggregation.v1",
    .version = 1,
    .category = "production-hardening",
    .status = "current",
    .emitted_by = &.{"causal-production-artifact-aggregation"},
    .consumed_by = &.{ "durable retention", "access control", "workbench", "integrations", "agents" },
    .compatibility = &.{"record-only"},
    .governance_requirements = &.{ "aggregation contract tests", "operations docs", "roadmap update" },
},
```

Increase expected schema count from `34` to `35` and add text/JSON assertions.

- [ ] **Step 3: Update schema docs**

Document the schema as a production-hardening record-only contract consumed by
future durable retention and workbench branches.

- [ ] **Step 4: Run focused commands**

Run:

```sh
cd packages/zigeffect
zig build causal-production-artifact-aggregation
zig build causal-production-artifact-aggregation -- --format json
zig build causal-schema-governance
zig build causal-schema-governance -- --format json
```

Expected: every command exits 0 and schema governance reports count `35`.

## Task 4: Update Backlog Handoff

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Update backlog constants**

Change:

```zig
pub const recommendation = "start-durable-production-retention";
pub const recommended_next_branch = "codex/zigeffect-causal-durable-production-retention";
```

Change the `production-artifact-aggregation` backlog item status to
`delivered`, and update tests to expect the new recommendation and branch.

- [ ] **Step 2: Update docs and master roadmap**

Update the immediate branch queue to:

```text
codex/zigeffect-causal-durable-production-retention
```

Explain that durable retention consumes the aggregation bundle contract and
remains NenDB adapter work only.

- [ ] **Step 3: Run backlog command**

Run:

```sh
cd packages/zigeffect
zig build causal-production-hardening-backlog
zig build causal-production-hardening-backlog -- --format json
```

Expected: reports `start-durable-production-retention` and the durable
retention branch.

## Task 5: Add User-Facing Docs

**Files:**
- Create: `packages/zigeffect/docs/production-artifact-aggregation.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `packages/zigeffect/README.md`

- [ ] **Step 1: Write aggregation docs**

Create docs with sections:

```markdown
# zigeffect Causal Production Artifact Aggregation

## Command

## What The Contract Means

## Bundle Contract

## Source Provenance Fields

## Privacy Review Gates

## Sample Bundle

## Authority Boundaries

## Verification Suite
```

- [ ] **Step 2: Link command from README and operations**

Add command block:

```sh
cd packages/zigeffect
zig build causal-production-artifact-aggregation
zig build causal-production-artifact-aggregation -- --format json
```

State that it does not add ingestion, storage, dashboards, or mutation
authority.

- [ ] **Step 3: Update package roadmap**

Record the aggregation contract as delivered and set durable production
retention as the next production-hardening branch.

## Task 6: Verify And Commit

**Files:**
- All files changed by Tasks 1-5

- [ ] **Step 1: Run targeted Zig commands**

Run:

```sh
cd packages/zigeffect
zig build causal-production-artifact-aggregation
zig build causal-production-artifact-aggregation -- --format json
zig build causal-production-hardening-backlog
zig build causal-production-hardening-backlog -- --format json
zig build causal-schema-governance
zig build causal-schema-governance -- --format json
zig build examples
zig build test
```

Expected: every command exits 0.

- [ ] **Step 2: Run repo checks**

Run:

```sh
bun run check
bun run zig:test
git diff --check
```

Expected: every command exits 0.

- [ ] **Step 3: Stage intentional files only**

Run:

```sh
git add docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git add packages/zigeffect/README.md
git add packages/zigeffect/build.zig
git add packages/zigeffect/docs/operations.md
git add packages/zigeffect/docs/production-artifact-aggregation.md
git add packages/zigeffect/docs/production-hardening-backlog.md
git add packages/zigeffect/docs/roadmap.md
git add packages/zigeffect/docs/schema-governance.md
git add packages/zigeffect/tools/causal_production_artifact_aggregation.zig
git add packages/zigeffect/tools/causal_production_hardening_backlog.zig
git add packages/zigeffect/tools/causal_schema_governance.zig
```

Do not stage `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`; it is unrelated existing work.

- [ ] **Step 4: Commit implementation**

Run:

```sh
git commit -m "feat(zigeffect): add causal production artifact aggregation contract"
```

Expected: commit succeeds on `codex/zigeffect-causal-production-artifact-aggregation`.

## Plan Self-Review

- Every design requirement maps to a task.
- No unresolved placeholders remain.
- Names match the selected schema, command, branch, and docs.
- The plan preserves record-only behavior, NenDB-only durable direction,
  SolidJS plus `zig-webui`, and no production mutation authority.
