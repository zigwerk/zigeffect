# zigeffect Causal Durable Production Retention Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the NenDB-only durable production retention contract and local verification surface that consumes the production artifact aggregation contract.

**Architecture:** Add small evaluative retention helpers to the existing NenDB storage adapter, then add a deterministic `causal-durable-production-retention` tool that publishes the production retention policy, fixture, and next branch handoff. Update schema governance, backlog handoff, and documentation without adding live ingestion, mutation authority, or another database adapter.

**Tech Stack:** Zig 0.16, zigeffect service modules, zigeffect deterministic tools, Bun repo verification.

---

## File Structure

- Modify `packages/zigeffect/src/services/causal_nendb_storage_backend.zig`
  - Adds `CausalNendbRetentionPolicy`, `CausalNendbRetentionReport`, schema
    constants, and `retentionReport`.
- Modify `packages/zigeffect/src/zigeffect.zig`
  - Re-exports the new NenDB retention structs and schema constants.
- Modify `packages/zigeffect/test/causal_nendb_storage_backend_test.zig`
  - Adds direct retention report tests against the fake writer.
- Create `packages/zigeffect/tools/causal_durable_production_retention.zig`
  - Emits text and JSON contract reports.
- Modify `packages/zigeffect/build.zig`
  - Wires `zig build causal-durable-production-retention` and tool tests.
- Modify `packages/zigeffect/tools/causal_schema_governance.zig`
  - Registers `zigeffect.causal.nendb-retention-report.v1` and
    `zigeffect.causal.durable-production-retention.v1`.
- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
  - Marks durable production retention delivered and points to deployment
    runbooks.
- Modify docs:
  - `packages/zigeffect/docs/durable-production-retention.md`
  - `packages/zigeffect/docs/production-hardening-backlog.md`
  - `packages/zigeffect/docs/production-artifact-aggregation.md`
  - `packages/zigeffect/docs/schema-governance.md`
  - `packages/zigeffect/docs/operations.md`
  - `packages/zigeffect/docs/roadmap.md`
  - `packages/zigeffect/README.md`
  - `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

## Task 1: Add Red NenDB Retention Report Tests

**Files:**
- Modify: `packages/zigeffect/test/causal_nendb_storage_backend_test.zig`

- [ ] **Step 1: Add failing retention report test**

Append this test after the flush test:

```zig
test "nendb storage retention report derives policy and event bounds" {
    var fake = FakeNendbWriter.init(std.testing.allocator);
    defer fake.deinit();
    var backend_state = fx.CausalNendbStorageBackendState.init(std.testing.allocator, fake.writer(), .{});
    defer backend_state.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    const root = try store.record(.{
        .kind = .run_started,
        .run_id = 7,
        .label = "retained-root",
    });
    const child = try store.record(.{
        .kind = .effect_completed,
        .run_id = 7,
        .parent_id = root,
        .label = "retained-child",
    });

    const report = backend_state.retentionReport(.{
        .max_events = 16,
        .ttl_days = 14,
        .compaction_trigger_events = 1,
        .compact_to_events = 1,
        .backup_required = true,
        .recovery_required = true,
    });

    try std.testing.expectEqualStrings(fx.causal_nendb_retention_report_schema, report.schema);
    try std.testing.expectEqual(@as(u32, 1), report.schema_version);
    try std.testing.expectEqual(@as(usize, 2), report.retained_events);
    try std.testing.expectEqual(@as(?usize, 16), report.max_events);
    try std.testing.expectEqual(@as(?u32, 14), report.ttl_days);
    try std.testing.expectEqual(@as(?usize, 1), report.compaction_trigger_events);
    try std.testing.expectEqual(@as(?usize, 1), report.compact_to_events);
    try std.testing.expectEqual(true, report.compaction_required);
    try std.testing.expectEqual(true, report.backup_required);
    try std.testing.expectEqual(true, report.recovery_required);
    try std.testing.expectEqual(@as(?u64, root), report.oldest_retained_event_id);
    try std.testing.expectEqual(@as(?u64, child), report.newest_retained_event_id);
}
```

- [ ] **Step 2: Run focused test and verify red**

Run:

```sh
cd packages/zigeffect
zig build causal-nendb-storage-backend
```

Expected: fail with missing `CausalNendbRetentionPolicy`,
`causal_nendb_retention_report_schema`, or `retentionReport`.

## Task 2: Implement NenDB Retention Report Helpers

**Files:**
- Modify: `packages/zigeffect/src/services/causal_nendb_storage_backend.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`

- [ ] **Step 1: Add schema constants and structs**

Near the existing NenDB node/edge schema constants, add:

```zig
pub const causal_nendb_retention_report_schema = "zigeffect.causal.nendb-retention-report.v1";
pub const causal_nendb_retention_report_schema_version: u32 = 1;

pub const CausalNendbRetentionPolicy = struct {
    max_events: ?usize = null,
    ttl_days: ?u32 = null,
    compaction_trigger_events: ?usize = null,
    compact_to_events: ?usize = null,
    backup_required: bool = false,
    recovery_required: bool = false,
};

pub const CausalNendbRetentionReport = struct {
    schema: []const u8 = causal_nendb_retention_report_schema,
    schema_version: u32 = causal_nendb_retention_report_schema_version,
    retained_events: usize = 0,
    max_events: ?usize = null,
    ttl_days: ?u32 = null,
    compaction_trigger_events: ?usize = null,
    compact_to_events: ?usize = null,
    compaction_required: bool = false,
    backup_required: bool = false,
    recovery_required: bool = false,
    oldest_retained_event_id: ?u64 = null,
    newest_retained_event_id: ?u64 = null,
};
```

- [ ] **Step 2: Add report methods**

Inside `CausalNendbStorageBackendState`, after `flushedCount`, add:

```zig
    pub fn retentionReport(
        self: *const CausalNendbStorageBackendState,
        policy: CausalNendbRetentionPolicy,
    ) CausalNendbRetentionReport {
        const retained_events = self.events.items.len;
        return .{
            .retained_events = retained_events,
            .max_events = policy.max_events,
            .ttl_days = policy.ttl_days,
            .compaction_trigger_events = policy.compaction_trigger_events,
            .compact_to_events = policy.compact_to_events,
            .compaction_required = isCompactionRequired(retained_events, policy.compaction_trigger_events),
            .backup_required = policy.backup_required,
            .recovery_required = policy.recovery_required,
            .oldest_retained_event_id = self.oldestRetainedEventId(),
            .newest_retained_event_id = self.newestRetainedEventId(),
        };
    }

    fn oldestRetainedEventId(self: *const CausalNendbStorageBackendState) ?u64 {
        if (self.events.items.len == 0) return null;
        return self.events.items[0].id;
    }

    fn newestRetainedEventId(self: *const CausalNendbStorageBackendState) ?u64 {
        if (self.events.items.len == 0) return null;
        return self.events.items[self.events.items.len - 1].id;
    }
```

Add this private helper outside the struct:

```zig
fn isCompactionRequired(retained_events: usize, trigger: ?usize) bool {
    const threshold = trigger orelse return false;
    return retained_events > threshold;
}
```

- [ ] **Step 3: Re-export from root module**

In `packages/zigeffect/src/zigeffect.zig`, re-export:

```zig
    pub const CausalNendbRetentionPolicy = causal_nendb_storage_backend.CausalNendbRetentionPolicy;
    pub const CausalNendbRetentionReport = causal_nendb_storage_backend.CausalNendbRetentionReport;
    pub const causal_nendb_retention_report_schema = causal_nendb_storage_backend.causal_nendb_retention_report_schema;
    pub const causal_nendb_retention_report_schema_version = causal_nendb_storage_backend.causal_nendb_retention_report_schema_version;
```

- [ ] **Step 4: Run focused test and verify green**

Run:

```sh
cd packages/zigeffect
zig build causal-nendb-storage-backend
```

Expected: pass.

## Task 3: Add Red Durable Retention Tool Contract

**Files:**
- Create: `packages/zigeffect/tools/causal_durable_production_retention.zig`

- [ ] **Step 1: Create tool with constants, report data, CLI, renderers, and tests**

Create the file with:

```zig
const std = @import("std");
const fx = @import("zigeffect");

pub const durable_production_retention_schema = "zigeffect.causal.durable-production-retention.v1";
pub const durable_production_retention_schema_version: u32 = 1;
pub const source_contract_schema = "zigeffect.causal.production-artifact-aggregation.v1";
pub const recommendation = "start-production-deployment-runbooks";
pub const recommended_next_branch = "codex/zigeffect-causal-production-deployment-runbooks";

const OutputFormat = enum { text, json };
const generated_by = "causal-durable-production-retention";

const RetentionPolicy = struct {
    id: []const u8,
    storage_adapter: []const u8,
    ttl_days: u32,
    max_events_per_bundle: usize,
    compaction_trigger_events: usize,
    compact_to_events: usize,
    backup_required: bool,
    recovery_required: bool,
    guidance: []const u8,
};

const RetentionGate = struct {
    id: []const u8,
    required: bool,
    description: []const u8,
    failure_action: []const u8,
};

const RetainedSource = struct {
    id: []const u8,
    source_kind: []const u8,
    artifact_class: []const u8,
    schema: []const u8,
    retention_state: []const u8,
    durable_state: []const u8,
    redaction_state: []const u8,
    recovery_hint: []const u8,
};

const retention_policy = RetentionPolicy{
    .id = "nendb-production-bundle-retention",
    .storage_adapter = "NenDB adapter",
    .ttl_days = 14,
    .max_events_per_bundle = 4096,
    .compaction_trigger_events = 2048,
    .compact_to_events = 1024,
    .backup_required = true,
    .recovery_required = true,
    .guidance = "Retain reviewed aggregation bundles through NenDB-shaped records; TTL remains policy-only until retained bundles carry capture timestamps.",
};

const gates: []const RetentionGate = &.{
    .{
        .id = "aggregation-contract-present",
        .required = true,
        .description = "Every retained bundle uses production artifact aggregation provenance fields.",
        .failure_action = "block durable retention",
    },
    .{
        .id = "redaction-reviewed",
        .required = true,
        .description = "Source artifacts pass redaction review before durable retention.",
        .failure_action = "retain locally only",
    },
    .{
        .id = "ttl-metadata-present",
        .required = true,
        .description = "Future production records must carry capture metadata before age-based TTL is enforced.",
        .failure_action = "mark TTL policy-only and recovery evidence incomplete",
    },
    .{
        .id = "backup-recovery-fixture",
        .required = true,
        .description = "Backup and recovery evidence must prove causal lineage is queryable after restore.",
        .failure_action = "do not mark bundle recoverable",
    },
};

const retained_sources: []const RetainedSource = &.{
    .{
        .id = "ci-head-dogfood",
        .source_kind = "ci-head",
        .artifact_class = "core-runtime",
        .schema = "zigeffect.causal.v1",
        .retention_state = "ci-artifact-retention-14-days",
        .durable_state = "eligible-after-redaction-review",
        .redaction_state = "redaction-required-before-sharing",
        .recovery_hint = "restore event graph then verify cause path for failed event ids",
    },
    .{
        .id = "ci-verdict",
        .source_kind = "ci-handoff",
        .artifact_class = "handoff",
        .schema = "zigeffect.causal.ci-verdict.v1",
        .retention_state = "ci-artifact-retention-14-days",
        .durable_state = "eligible-after-redaction-review",
        .redaction_state = "redaction-required-before-sharing",
        .recovery_hint = "restore verdict before linked source artifacts",
    },
    .{
        .id = "dev-loop-audit-chain",
        .source_kind = "governance-chain",
        .artifact_class = "governance",
        .schema = "zigeffect.causal.audit-chain.v1",
        .retention_state = "local-manual-retention",
        .durable_state = "manual-review-required",
        .redaction_state = "redaction-required-before-sharing",
        .recovery_hint = "verify before-after evidence remains linked",
    },
};
```

Then implement `usage`, `parseOptions`, `formatText`, `formatJson`, `main`,
and tests following the pattern in
`packages/zigeffect/tools/causal_production_artifact_aggregation.zig`.

- [ ] **Step 2: Run direct Zig test and verify red/green**

Run before build wiring:

```sh
cd packages/zigeffect
zig test tools/causal_durable_production_retention.zig
```

Expected before all helpers are implemented: fail on missing renderer/parser
symbols.

Run again after completing helpers.

Expected after helpers are implemented: pass.

## Task 4: Wire Durable Retention Tool Into Build

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add module, executable, build step, and test step**

Near `causal-production-artifact-aggregation`, add a parallel block:

```zig
    const causal_durable_production_retention_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_durable_production_retention.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_durable_production_retention_module.addImport("zigeffect", zigeffect_mod);
    const causal_durable_production_retention_exe = b.addExecutable(.{
        .name = "zigeffect-causal-durable-production-retention",
        .root_module = causal_durable_production_retention_module,
    });
    const causal_durable_production_retention_run = b.addRunArtifact(causal_durable_production_retention_exe);
    if (b.args) |args| causal_durable_production_retention_run.addArgs(args);
    const causal_durable_production_retention_step = b.step("causal-durable-production-retention", "Print causal durable production retention contract");
    causal_durable_production_retention_step.dependOn(&causal_durable_production_retention_run.step);

    const causal_durable_production_retention_test_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_durable_production_retention.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_durable_production_retention_test_module.addImport("zigeffect", zigeffect_mod);
    const causal_durable_production_retention_tests = b.addTest(.{
        .name = "zigeffect-causal-durable-production-retention-tests",
        .root_module = causal_durable_production_retention_test_module,
    });
    test_step.dependOn(&causal_durable_production_retention_tests.step);
```

- [ ] **Step 2: Run build step**

Run:

```sh
cd packages/zigeffect
zig build causal-durable-production-retention
zig build causal-durable-production-retention -- --format json
```

Expected: both commands exit 0 and include
`zigeffect.causal.durable-production-retention.v1`.

## Task 5: Register Governance And Backlog Handoff

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`

- [ ] **Step 1: Add schema governance entry**

Add entry:

```zig
.{
    .schema = "zigeffect.causal.nendb-retention-report.v1",
    .version = 1,
    .category = "backend-export",
    .status = "current",
    .emitted_by = &.{"CausalNenDbStorageBackend.retentionReport"},
    .consumed_by = &.{ "causal-durable-production-retention", "NenDB adapter tests", "agents" },
    .compatibility = &.{"record-only"},
    .governance_requirements = &.{ "NenDB retention tests", "durable retention docs", "schema governance entry" },
},
.{
    .schema = "zigeffect.causal.durable-production-retention.v1",
    .version = 1,
    .category = "production-hardening",
    .status = "current",
    .emitted_by = &.{"causal-durable-production-retention"},
    .consumed_by = &.{ "deployment runbooks", "artifact access control", "workbench", "agents" },
    .compatibility = &.{ "record-only" },
    .governance_requirements = &.{ "durable retention tests", "NenDB retention fixture", "operations docs", "roadmap update" },
},
```

Update schema count from 35 to 37 and add text/JSON assertions for both new
schemas.

- [ ] **Step 2: Update production backlog constants and item state**

Change:

```zig
pub const recommendation = "start-production-deployment-runbooks";
pub const recommended_next_branch = "codex/zigeffect-causal-production-deployment-runbooks";
```

For the `durable-production-retention` item:

```zig
.status = "delivered",
.summary = "Defines NenDB-backed durable retention policy, TTL, compaction, backup, recovery, and verification fixture contracts for aggregated causal artifacts.",
.agent_guidance = "Use causal-durable-production-retention before deployment runbooks; durable writes remain NenDB adapter work only.",
```

Add the new command to `verification_commands`.

- [ ] **Step 3: Run governance/backlog commands**

Run:

```sh
cd packages/zigeffect
zig build causal-schema-governance
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog
zig build causal-production-hardening-backlog -- --format json
```

Expected: governance reports schema count 37 and backlog reports next branch
`codex/zigeffect-causal-production-deployment-runbooks`.

## Task 6: Write Durable Retention Docs

**Files:**
- Create: `packages/zigeffect/docs/durable-production-retention.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/production-artifact-aggregation.md`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Create durable retention docs page**

Write a page that documents:

- command;
- schema;
- relationship to production artifact aggregation;
- NenDB-only policy;
- TTL as policy-only until capture timestamps exist;
- compaction threshold;
- backup/recovery expectations;
- privacy gates;
- authority boundaries;
- verification suite.

- [ ] **Step 2: Update related docs**

Add concise links/sections that:

- point durable retention readers to the new page;
- mark durable retention delivered in roadmap/backlog docs;
- set the next branch to production deployment runbooks;
- preserve no Cockroach, no React, no mutation authority constraints.

- [ ] **Step 3: Run doc searches**

Run:

```sh
rg -n "causal-durable-production-retention|durable-production-retention|codex/zigeffect-causal-production-deployment-runbooks|NenDB|Cockroach|React" packages/zigeffect docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
```

Expected: results show new command/docs and only non-goal mentions for
Cockroach/React in this branch context.

## Task 7: Final Verification And Commit

**Files:**
- All intentional files from previous tasks.

- [ ] **Step 1: Run targeted verification**

Run:

```sh
cd packages/zigeffect
zig build causal-durable-production-retention
zig build causal-durable-production-retention -- --format json
zig build causal-nendb-storage-backend
zig build causal-production-artifact-aggregation
zig build causal-production-hardening-backlog
zig build causal-schema-governance
zig build examples
zig build test
```

Expected: all commands exit 0.

- [ ] **Step 2: Run repo verification**

Run:

```sh
cd /Users/seanknowles/Desktop/Projects/yachdee
bun run check
bun run zig:test
git diff --check
git diff --cached --check
```

Expected: all commands exit 0. Existing live Cockroach tests may remain skipped
under `bun run check`.

- [ ] **Step 3: Stage only durable retention files**

Run:

```sh
git add docs/superpowers/plans/2026-06-09-zigeffect-causal-durable-production-retention.md \
  docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md \
  packages/zigeffect/README.md \
  packages/zigeffect/build.zig \
  packages/zigeffect/docs/durable-production-retention.md \
  packages/zigeffect/docs/operations.md \
  packages/zigeffect/docs/production-artifact-aggregation.md \
  packages/zigeffect/docs/production-hardening-backlog.md \
  packages/zigeffect/docs/roadmap.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/src/services/causal_nendb_storage_backend.zig \
  packages/zigeffect/src/zigeffect.zig \
  packages/zigeffect/test/causal_nendb_storage_backend_test.zig \
  packages/zigeffect/tools/causal_durable_production_retention.zig \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  packages/zigeffect/tools/causal_schema_governance.zig
```

Do not stage
`docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`.

- [ ] **Step 4: Commit implementation**

Run:

```sh
git commit -m "feat(zigeffect): add causal durable production retention contract"
```

Expected: commit succeeds on
`codex/zigeffect-causal-durable-production-retention`.

## Self-Review Checklist

- Spec coverage: tasks cover deterministic report, NenDB retention helpers,
  TTL, compaction, backup/recovery, governance, backlog handoff, docs, and
  verification.
- Scope: no task adds live ingestion, production dashboards, mutation
  authority, Cockroach, D1, R2, RoachGraph, React, RBAC, encryption, alerting,
  deployment, or rollout automation.
- Type consistency: `CausalNendbRetentionPolicy`,
  `CausalNendbRetentionReport`, `retentionReport`, and
  `zigeffect.causal.durable-production-retention.v1` are used consistently.
- Verification: focused Zig commands and repo-wide Bun/Zig commands are listed
  before the implementation commit.
