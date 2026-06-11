# zigeffect Causal NenDB Durable History Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden the NenDB causal storage adapter with a runtime durable-history report, deterministic fixture tool, schema governance, and roadmap/backlog handoff to cross-run agent queries.

**Architecture:** Extend `CausalNendbStorageBackendState` with an allocation-free durable-history report derived from retained local history, writer/flush counters, and policy inputs. Add a local Zig fixture tool that imports the zigeffect module, exercises the backend with a fake writer, verifies query/redaction/flush evidence, and emits `zigeffect.causal.nendb-durable-history.v1` text/JSON artifacts. Register schema/docs/backlog updates without adding Cockroach, live telemetry, upstream NenDB dependency, or production mutation authority.

**Tech Stack:** Zig build tooling, zigeffect causal runtime, `std.json`, local `.zig-cache/causal-artifacts`, Bun for repo-level checks.

---

## File Map

- Modify: `packages/zigeffect/src/services/causal_nendb_storage_backend.zig`
  - Add durable-history schema constants, policy/report structs, report helper, and redaction-evidence scan.
- Modify: `packages/zigeffect/src/zigeffect.zig`
  - Re-export new policy/report types and schema constants in both service and top-level export blocks.
- Modify: `packages/zigeffect/test/causal_nendb_storage_backend_test.zig`
  - Add runtime tests for report fields, query evidence, redaction posture, flush posture, and fail-closed bounds.
- Create: `packages/zigeffect/tools/causal_nendb_durable_history_hardening.zig`
  - Deterministic fixture CLI, fake writer, ready/blocked checks, text/JSON rendering, and tool tests.
- Modify: `packages/zigeffect/build.zig`
  - Register `causal-nendb-durable-history-hardening` executable/test step and import `zigeffect` into the tool module.
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
  - Add schema entry and bump schema count from 80 to 81.
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
  - Add delivered backlog item, verification command, dependency order, and next recommendation.
- Create: `packages/zigeffect/docs/nendb-durable-history-hardening.md`
  - Operator and agent documentation for the new runtime report/tool.
- Modify: `packages/zigeffect/docs/durable-production-retention.md`
  - Link durable-retention policy to runtime durable-history evidence.
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
  - Record delivered branch and next handoff.
- Modify: `packages/zigeffect/docs/operations.md`
  - Add command and interpretation boundary.
- Modify: `packages/zigeffect/docs/roadmap.md`
  - Add delivered milestone and next branch.
- Modify: `packages/zigeffect/docs/schema-governance.md`
  - Add schema line and count 81.
- Modify: `packages/zigeffect/README.md`
  - Add command and short description.
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Mark NenDB durable-history hardening delivered and hand off to cross-run agent comparison.

## Task 1: Add Failing Runtime Tests

**Files:**
- Modify: `packages/zigeffect/test/causal_nendb_storage_backend_test.zig`

- [x] **Step 1: Add durable-history report test**

Append this test near the existing retention report test:

```zig
test "nendb durable history report exposes bounded queryable evidence" {
    var fake = FakeNendbWriter.init(std.testing.allocator);
    defer fake.deinit();
    var backend_state = fx.CausalNendbStorageBackendState.init(std.testing.allocator, fake.writer(), .{ .max_events = 16 });
    defer backend_state.deinit();

    var store = fx.CausalStore.initWithOptions(std.testing.allocator, .{
        .max_events = 1,
    });
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    const root = try store.record(.{
        .kind = .run_started,
        .run_id = 77,
        .label = "durable-history-root",
        .redacted_detail = fx.causal_redaction_marker,
    });
    const child = try store.record(.{
        .kind = .log_recorded,
        .run_id = 77,
        .parent_id = root,
        .label = "durable-history-child",
        .redacted_detail = "safe retained detail",
    });
    _ = try store.record(.{
        .kind = .effect_completed,
        .run_id = 77,
        .parent_id = root,
        .label = "durable-history-terminal",
        .redacted_detail = "complete",
    });
    try backend_state.flush();

    var store_cause = try store.cause(std.testing.allocator, child);
    defer store_cause.deinit();
    try std.testing.expectEqual(@as(usize, 0), store_cause.events.len);

    var history_cause = try backend_state.cause(std.testing.allocator, child);
    defer history_cause.deinit();
    try std.testing.expectEqual(@as(usize, 2), history_cause.events.len);
    try std.testing.expectEqual(root, history_cause.events[0].id);
    try std.testing.expectEqual(child, history_cause.events[1].id);

    const report = backend_state.durableHistoryReport(.{
        .max_events = 16,
        .ttl_days = 14,
        .compaction_trigger_events = 2,
        .compact_to_events = 1,
        .backup_required = true,
        .recovery_required = true,
        .flush_required = true,
        .redaction_required = true,
        .lineage_query_required = true,
    });

    try std.testing.expectEqualStrings(fx.causal_nendb_durable_history_schema, report.schema);
    try std.testing.expectEqual(@as(u32, 1), report.schema_version);
    try std.testing.expectEqualStrings("nendb_graph", report.backend_kind);
    try std.testing.expectEqualStrings("NenDB adapter", report.storage_adapter);
    try std.testing.expectEqual(@as(usize, 3), report.retained_events);
    try std.testing.expectEqual(@as(?usize, 16), report.max_events);
    try std.testing.expectEqual(@as(u64, 3), report.written_events);
    try std.testing.expectEqual(@as(u64, 0), report.failed_events);
    try std.testing.expectEqual(@as(u64, 1), report.flushed_count);
    try std.testing.expectEqual(@as(?u64, root), report.oldest_retained_event_id);
    try std.testing.expectEqual(@as(?u64, 3), report.newest_retained_event_id);
    try std.testing.expect(report.writer_attached);
    try std.testing.expect(report.flush_required);
    try std.testing.expect(report.flush_observed);
    try std.testing.expect(report.redaction_required);
    try std.testing.expect(report.redaction_observed);
    try std.testing.expect(report.lineage_query_required);
    try std.testing.expect(report.lineage_query_supported);
    try std.testing.expect(report.compaction_required);
    try std.testing.expect(report.backup_required);
    try std.testing.expect(report.recovery_required);
    try std.testing.expect(!report.live_telemetry_enabled);
    try std.testing.expect(!report.network_send_enabled);
    try std.testing.expect(!report.durable_write_authority);
    try std.testing.expect(!report.nendb_write_authority);
    try std.testing.expect(!report.cockroach_adapter_enabled);
    try std.testing.expectEqualStrings("none", report.mutation_authority);
}
```

- [x] **Step 2: Add no-redaction-evidence test**

Append:

```zig
test "nendb durable history report keeps redaction evidence explicit" {
    var fake = FakeNendbWriter.init(std.testing.allocator);
    defer fake.deinit();
    var backend_state = fx.CausalNendbStorageBackendState.init(std.testing.allocator, fake.writer(), .{});
    defer backend_state.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    _ = try store.record(.{
        .kind = .run_started,
        .label = "no-redaction-marker",
        .redacted_detail = "safe but unmarked",
    });

    const report = backend_state.durableHistoryReport(.{
        .redaction_required = true,
        .lineage_query_required = true,
    });

    try std.testing.expect(report.redaction_required);
    try std.testing.expect(!report.redaction_observed);
    try std.testing.expect(report.lineage_query_supported);
}
```

- [x] **Step 3: Run red runtime tests**

Run:

```sh
cd packages/zigeffect
zig build causal-nendb-storage-backend
```

Expected: fails because `durableHistoryReport`, `CausalNendbDurableHistoryPolicy`,
`CausalNendbDurableHistoryReport`, and
`causal_nendb_durable_history_schema` are not defined yet.

## Task 2: Implement Runtime Durable-History Report

**Files:**
- Modify: `packages/zigeffect/src/services/causal_nendb_storage_backend.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`

- [x] **Step 1: Add schema constants and report types**

In `causal_nendb_storage_backend.zig`, near the existing NenDB schema constants,
add:

```zig
pub const causal_nendb_durable_history_schema = "zigeffect.causal.nendb-durable-history.v1";
pub const causal_nendb_durable_history_schema_version: u32 = 1;
```

After `CausalNendbRetentionReport`, add:

```zig
pub const CausalNendbDurableHistoryPolicy = struct {
    max_events: ?usize = null,
    ttl_days: ?u32 = null,
    compaction_trigger_events: ?usize = null,
    compact_to_events: ?usize = null,
    backup_required: bool = false,
    recovery_required: bool = false,
    flush_required: bool = false,
    redaction_required: bool = false,
    lineage_query_required: bool = false,
};

pub const CausalNendbDurableHistoryReport = struct {
    schema: []const u8 = causal_nendb_durable_history_schema,
    schema_version: u32 = causal_nendb_durable_history_schema_version,
    backend_kind: []const u8 = "nendb_graph",
    storage_adapter: []const u8 = "NenDB adapter",
    node_schema: []const u8 = causal_nendb_node_schema,
    edge_schema: []const u8 = causal_nendb_edge_schema,
    retained_events: usize = 0,
    max_events: ?usize = null,
    ttl_days: ?u32 = null,
    compaction_trigger_events: ?usize = null,
    compact_to_events: ?usize = null,
    written_events: u64 = 0,
    failed_events: u64 = 0,
    flushed_count: u64 = 0,
    oldest_retained_event_id: ?u64 = null,
    newest_retained_event_id: ?u64 = null,
    writer_attached: bool = false,
    flush_required: bool = false,
    flush_observed: bool = false,
    redaction_required: bool = false,
    redaction_observed: bool = false,
    lineage_query_required: bool = false,
    lineage_query_supported: bool = true,
    compaction_required: bool = false,
    backup_required: bool = false,
    recovery_required: bool = false,
    live_telemetry_enabled: bool = false,
    network_send_enabled: bool = false,
    durable_write_authority: bool = false,
    nendb_write_authority: bool = false,
    cockroach_adapter_enabled: bool = false,
    mutation_authority: []const u8 = "none",
};
```

- [x] **Step 2: Add report method**

Inside `CausalNendbStorageBackendState`, after `retentionReport`, add:

```zig
    pub fn durableHistoryReport(
        self: *const CausalNendbStorageBackendState,
        policy: CausalNendbDurableHistoryPolicy,
    ) CausalNendbDurableHistoryReport {
        const retained_events = self.events.items.len;
        return .{
            .retained_events = retained_events,
            .max_events = policy.max_events,
            .ttl_days = policy.ttl_days,
            .compaction_trigger_events = policy.compaction_trigger_events,
            .compact_to_events = policy.compact_to_events,
            .written_events = self.written_event_count,
            .failed_events = self.failed_event_count,
            .flushed_count = self.flushed_count,
            .oldest_retained_event_id = self.oldestRetainedEventId(),
            .newest_retained_event_id = self.newestRetainedEventId(),
            .writer_attached = true,
            .flush_required = policy.flush_required,
            .flush_observed = !policy.flush_required or self.flushed_count > 0,
            .redaction_required = policy.redaction_required,
            .redaction_observed = !policy.redaction_required or self.hasRedactionEvidence(),
            .lineage_query_required = policy.lineage_query_required,
            .lineage_query_supported = true,
            .compaction_required = isCompactionRequired(retained_events, policy.compaction_trigger_events),
            .backup_required = policy.backup_required,
            .recovery_required = policy.recovery_required,
        };
    }
```

- [x] **Step 3: Add redaction helper**

Inside `CausalNendbStorageBackendState`, near the retained-id helpers, add:

```zig
    fn hasRedactionEvidence(self: *const CausalNendbStorageBackendState) bool {
        for (self.events.items) |event| {
            if (std.mem.indexOf(u8, event.redacted_detail, causal.causal_redaction_marker) != null) {
                return true;
            }
        }
        return false;
    }
```

- [x] **Step 4: Re-export runtime API**

In `packages/zigeffect/src/zigeffect.zig`, add exports in both the nested
`services` block and top-level export block:

```zig
pub const CausalNendbDurableHistoryPolicy = causal_nendb_storage_backend.CausalNendbDurableHistoryPolicy;
pub const CausalNendbDurableHistoryReport = causal_nendb_storage_backend.CausalNendbDurableHistoryReport;
pub const causal_nendb_durable_history_schema = causal_nendb_storage_backend.causal_nendb_durable_history_schema;
pub const causal_nendb_durable_history_schema_version = causal_nendb_storage_backend.causal_nendb_durable_history_schema_version;
```

For the top-level block, use `services.causal_nendb_storage_backend` as the
qualifier, matching the existing exports.

- [x] **Step 5: Run green runtime tests**

Run:

```sh
cd packages/zigeffect
zig build causal-nendb-storage-backend
```

Expected: passes.

## Task 3: Add Failing Fixture Tool Tests

**Files:**
- Create: `packages/zigeffect/tools/causal_nendb_durable_history_hardening.zig`

- [x] **Step 1: Create tool test skeleton**

Create the file with schema constants and failing formatter:

```zig
const std = @import("std");
const fx = @import("zigeffect");

pub const nendb_durable_history_schema = fx.causal_nendb_durable_history_schema;
pub const nendb_durable_history_schema_version = fx.causal_nendb_durable_history_schema_version;
pub const source_branch = "codex/zigeffect-causal-nendb-durable-history-hardening";
pub const recommendation = "start-agent-query-cross-run-comparison";
pub const next_branch_if_ready = "codex/zigeffect-causal-agent-query-compare-runs";

test "nendb durable history constants preserve next handoff" {
    try std.testing.expectEqualStrings("zigeffect.causal.nendb-durable-history.v1", nendb_durable_history_schema);
    try std.testing.expectEqual(@as(u32, 1), nendb_durable_history_schema_version);
    try std.testing.expectEqualStrings("start-agent-query-cross-run-comparison", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-agent-query-compare-runs", next_branch_if_ready);
}

test "nendb durable history default fixture is ready and denies production authority" {
    const report = try formatTextReport(std.testing.allocator, .text);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "status: ready") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "selected next branch: codex/zigeffect-causal-agent-query-compare-runs") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "mutation authority: none") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "Cockroach adapter enabled: false") != null);
}

fn formatTextReport(_: std.mem.Allocator, _: OutputFormat) ![]const u8 {
    return error.NotImplemented;
}

const OutputFormat = enum { text, json };
```

- [x] **Step 2: Run red tool test**

Run:

```sh
cd packages/zigeffect
zig test --dep zigeffect -Mroot=tools/causal_nendb_durable_history_hardening.zig -Mzigeffect=src/zigeffect.zig
```

Expected: fails with `error.NotImplemented`.

## Task 4: Implement Fixture Tool

**Files:**
- Modify: `packages/zigeffect/tools/causal_nendb_durable_history_hardening.zig`

- [x] **Step 1: Add CLI model and fake writer**

Implement these public behaviors:

- `--help` prints usage and exits 0;
- no args generates text and JSON artifacts using default output prefix;
- `--format text|json` controls console format;
- `--out-prefix <prefix>` controls artifact paths;
- unknown flags and missing values fail closed.

Use a fake writer equivalent to `FakeNendbWriter` from the runtime tests, with
owned cloned writes and flush count.

- [x] **Step 2: Add deterministic fixture generation**

The default fixture should:

- create `CausalNendbStorageBackendState` with `max_events=16`;
- create `CausalStore` with `max_events=1`;
- attach the backend;
- record three events under the same run id;
- include `fx.causal_redaction_marker` in one `redacted_detail`;
- avoid any raw-secret string in retained details;
- call `backend_state.flush()`;
- verify `store.cause(child)` is empty while `backend_state.cause(child)` has
  root and child.

- [x] **Step 3: Add check model**

Ready status requires these checks:

```zig
const required_check_names = &.{
    "writer-attached",
    "node-write-present",
    "parent-edge-present",
    "flush-observed",
    "history-exceeds-store-retention",
    "cause-query-restores-path",
    "lineage-query-supported",
    "redaction-marker-observed",
    "raw-secret-absent",
    "nendb-only-authority",
};
```

The default fixture must pass all checks. Add a negative test helper that can
evaluate a fixture without redaction marker and returns blocked.

- [x] **Step 4: Render text and JSON**

Text output must include:

```text
zigeffect causal NenDB durable history hardening
schema: zigeffect.causal.nendb-durable-history.v1
status: ready
ready for next branch: true
selected next branch: codex/zigeffect-causal-agent-query-compare-runs
storage adapter: NenDB adapter
backend kind: nendb_graph
mutation authority: none
Cockroach adapter enabled: false
```

JSON output must include at least:

```json
{
  "schema": "zigeffect.causal.nendb-durable-history.v1",
  "schema_version": 1,
  "generated_by": "causal-nendb-durable-history-hardening",
  "status": "ready",
  "ready_for_next_branch": true,
  "recommendation": "start-agent-query-cross-run-comparison",
  "selected_next_branch": "codex/zigeffect-causal-agent-query-compare-runs",
  "storage_adapter": "NenDB adapter",
  "backend_kind": "nendb_graph",
  "mutation_authority": "none",
  "cockroach_adapter_enabled": false
}
```

- [x] **Step 5: Add tool tests**

Tests must cover:

- constants and handoff;
- default text ready report;
- JSON includes schema and ready status;
- missing redaction evidence blocks readiness;
- denied authority fields stay false;
- CLI help succeeds.

- [x] **Step 6: Run green direct tool tests**

Run:

```sh
cd packages/zigeffect
zig test --dep zigeffect -Mroot=tools/causal_nendb_durable_history_hardening.zig -Mzigeffect=src/zigeffect.zig
```

Expected: all tests pass.

## Task 5: Register Build Step And Schema

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/docs/schema-governance.md`

- [x] **Step 1: Register tool build step**

Add near adjacent causal production hardening tools:

```zig
const causal_nendb_durable_history_hardening_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_nendb_durable_history_hardening.zig"),
    .target = target,
    .optimize = optimize,
});
causal_nendb_durable_history_hardening_tool_module.addImport("zigeffect", zigeffect);

const causal_nendb_durable_history_hardening_tool = b.addExecutable(.{
    .name = "zigeffect-causal-nendb-durable-history-hardening",
    .root_module = causal_nendb_durable_history_hardening_tool_module,
});
const run_causal_nendb_durable_history_hardening_tool = b.addRunArtifact(causal_nendb_durable_history_hardening_tool);
if (b.args) |args| run_causal_nendb_durable_history_hardening_tool.addArgs(args);
const causal_nendb_durable_history_hardening_step = b.step("causal-nendb-durable-history-hardening", "Emit NenDB durable-history hardening fixture");
causal_nendb_durable_history_hardening_step.dependOn(&run_causal_nendb_durable_history_hardening_tool.step);

const causal_nendb_durable_history_hardening_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-nendb-durable-history-hardening-tests",
    .root_module = causal_nendb_durable_history_hardening_tool_module,
});
const run_causal_nendb_durable_history_hardening_tool_tests = b.addRunArtifact(causal_nendb_durable_history_hardening_tool_tests);
test_step.dependOn(&run_causal_nendb_durable_history_hardening_tool_tests.step);
```

- [x] **Step 2: Add schema governance entry**

Add to `causal_schema_governance.zig`:

```zig
.{
    .schema = "zigeffect.causal.nendb-durable-history.v1",
    .version = 1,
    .category = "backend-export",
    .status = "current",
    .emitted_by = &.{ "CausalNendbStorageBackendState.durableHistoryReport", "causal-nendb-durable-history-hardening" },
    .consumed_by = &.{ "agents", "reviewers", "future cross-run query comparison", "future audit-chain snapshot comparison", "future app-facing production fixtures" },
    .compatibility = &.{ "strict-v1", "nendb-only", "local-fixture", "record-only", "no-cockroach", "no-live-telemetry", "no-network", "no-production-mutation" },
    .governance_requirements = &.{ "runtime report tests", "fixture tool tests", "redaction evidence checks", "query evidence checks", "next branch handoff" },
},
```

Update tests and docs from `schema_count: 80` to `schema_count: 81`.

- [x] **Step 3: Verify build step and schema**

Run:

```sh
cd packages/zigeffect
zig build causal-nendb-durable-history-hardening -- --help
zig build causal-schema-governance -- --format json
```

Expected: help exits 0; schema governance exits 0 and prints
`"schema_count": 81`.

## Task 6: Update Backlog, Docs, And Roadmap

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Create: `packages/zigeffect/docs/nendb-durable-history-hardening.md`
- Modify: `packages/zigeffect/docs/durable-production-retention.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [x] **Step 1: Advance production hardening backlog**

Change constants:

```zig
pub const recommendation = "start-agent-query-cross-run-comparison";
pub const recommended_next_branch = "codex/zigeffect-causal-agent-query-compare-runs";
```

Add delivered item:

```zig
.{
    .id = "nendb-durable-history-hardening",
    .title = "NenDB Durable History Hardening",
    .gap_id = "nendb-durable-history-hardening",
    .priority = "P0",
    .status = "delivered",
    .summary = "Hardens the NenDB causal storage adapter with runtime durable-history posture, deterministic local fixture evidence, and agent-readable schema governance.",
    .depends_on = &.{ "production-hardening-backlog-refresh", "causal-nendb-storage-backend", "production-telemetry-nendb-retention-fixtures" },
    .deliverables = &.{ "runtime durable-history report", "local fixture tool", "query evidence checks", "redaction evidence checks", "NenDB-only authority boundary" },
    .evidence_sources = &.{ "packages/zigeffect/src/services/causal_nendb_storage_backend.zig", "packages/zigeffect/tools/causal_nendb_durable_history_hardening.zig", "packages/zigeffect/docs/nendb-durable-history-hardening.md" },
    .branch = "codex/zigeffect-causal-nendb-durable-history-hardening",
    .agent_guidance = "Use this as the durable-history evidence substrate for cross-run comparison. Do not infer production health, live telemetry, Cockroach scope, durable production writes, NenDB production write authority, or mutation authority.",
},
```

Append `nendb-durable-history-hardening` to `dependency_order` and add
`zig build causal-nendb-durable-history-hardening` to `verification_commands`.

- [x] **Step 2: Update docs**

Document:

- command and artifact paths;
- runtime API and schema;
- ready checks;
- denied claims;
- next branch `codex/zigeffect-causal-agent-query-compare-runs`;
- no Cockroach/non-NenDB/live telemetry/production mutation authority.

- [x] **Step 3: Run backlog tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog.zig
zig build causal-production-hardening-backlog -- --format json
```

Expected: tests pass; report recommends
`codex/zigeffect-causal-agent-query-compare-runs`.

## Task 7: Full Verification And Commit

**Files:**
- All modified files from Tasks 1 through 6.

- [x] **Step 1: Run focused verification**

Run:

```sh
cd packages/zigeffect
zig build causal-nendb-storage-backend
zig test --dep zigeffect -Mroot=tools/causal_nendb_durable_history_hardening.zig -Mzigeffect=src/zigeffect.zig
zig build causal-nendb-durable-history-hardening
zig build causal-schema-governance -- --format json
zig test tools/causal_production_hardening_backlog.zig
zig build causal-production-hardening-backlog -- --format json
zig fmt --check build.zig \
  src/services/causal_nendb_storage_backend.zig \
  src/zigeffect.zig \
  test/causal_nendb_storage_backend_test.zig \
  tools/causal_nendb_durable_history_hardening.zig \
  tools/causal_schema_governance.zig \
  tools/causal_production_hardening_backlog.zig
```

Expected: every command exits 0.

- [x] **Step 2: Run integration verification**

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

Expected: every command exits 0.

- [x] **Step 3: Stage and commit**

Run:

```sh
git add docs/superpowers/plans/2026-06-10-zigeffect-causal-nendb-durable-history-hardening-implementation.md \
  docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md \
  packages/zigeffect/README.md \
  packages/zigeffect/build.zig \
  packages/zigeffect/docs/durable-production-retention.md \
  packages/zigeffect/docs/nendb-durable-history-hardening.md \
  packages/zigeffect/docs/operations.md \
  packages/zigeffect/docs/production-hardening-backlog.md \
  packages/zigeffect/docs/roadmap.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/src/services/causal_nendb_storage_backend.zig \
  packages/zigeffect/src/zigeffect.zig \
  packages/zigeffect/test/causal_nendb_storage_backend_test.zig \
  packages/zigeffect/tools/causal_nendb_durable_history_hardening.zig \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  packages/zigeffect/tools/causal_schema_governance.zig
git diff --cached --check
git commit -m "feat(zigeffect): harden nendb durable history"
```

Expected: commit succeeds on branch
`codex/zigeffect-causal-nendb-durable-history-hardening`.
