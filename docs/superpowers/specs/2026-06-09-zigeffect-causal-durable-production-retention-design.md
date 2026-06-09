# zigeffect Causal Durable Production Retention Design

Date: 2026-06-09
Branch: codex/zigeffect-causal-durable-production-retention
Milestone: Production hardening P1

## Purpose

Add the first durable production retention contract for causal artifacts after
`causal-production-artifact-aggregation`.

This branch should make the retained-evidence path concrete enough for agents
to reason about future production artifacts without adding live ingestion,
production dashboards, mutation authority, or a second database direction.
Durable storage remains NenDB adapter work only.

The practical outcome is:

- a deterministic `causal-durable-production-retention` report;
- a governed schema,
  `zigeffect.causal.durable-production-retention.v1`;
- small NenDB retention helpers that can evaluate current adapter history
  against declared retention policy;
- a local fixture for retained artifact bundles, TTL, compaction, backup, and
  recovery expectations;
- docs that make the next branch
  `codex/zigeffect-causal-production-deployment-runbooks`.

## Current Context

The prior branch delivered `causal-production-artifact-aggregation`, which
defines bundle ids, source provenance fields, privacy review gates, sample
sources, and supported downstream consumers. Durable retention must consume
that shape instead of inventing its own artifact source model.

The existing NenDB adapter is dependency-free. It exposes
`CausalNendbStorageBackendState`, `CausalNendbGraphWriter`,
`CausalNendbWrite`, deterministic node/edge schemas, fail-closed writer
semantics, bounded `max_events`, flush hooks, and local query history.

`CausalEvent` currently has no wall-clock timestamp. TTL enforcement therefore
cannot be implemented honestly against raw runtime events in this branch. TTL
must be represented as policy and future durable metadata expectations. Any
real age-based deletion must wait until retained bundle records carry captured
time metadata from the durable adapter.

## Constraints

- NenDB adapter only. No Cockroach, D1, R2, SQL, or RoachGraph storage adapter.
- No direct upstream `nen-db` package dependency yet.
- No live production telemetry ingestion.
- No production mutation authority.
- No deployment, rollout, alerting, RBAC, or encryption implementation.
- No React workbench support.
- Deterministic tools must not inspect clocks, networks, live systems, or
  generated artifacts.
- Redaction and privacy gates remain mandatory before durable sharing or
  retention.

## Considered Approaches

### Option A: Direct Upstream NenDB Retention

Wire the current branch to upstream NenDB and implement real persisted TTL,
compaction, backup, and restore operations.

This is too early. The existing adapter intentionally avoided a direct upstream
dependency because the package surface and Zig compatibility are not stable
enough for the core zigeffect package. It would also make deterministic tests
depend on external package layout and possibly clocks or filesystem state.

### Option B: Production Artifact Ingestion Service

Create a local service that reads `.zig-cache`, CI artifacts, or future
production telemetry and writes retained records.

This violates the current production hardening boundary. The aggregation
contract says paths are provenance, not proof that files exist. Access control,
privacy review, and runbooks are not ready yet, so ingesting real artifacts now
would create authority without governance.

### Option C: Deterministic NenDB Retention Contract

Add a retention contract report and small adapter-side policy helpers. The
report specifies TTL, compaction, backup, recovery, bundle retention states,
and verification fixtures. The adapter helpers evaluate in-memory NenDB history
against explicit policy without reading clocks or mutating production state.

This is the recommended design. It advances durable retention in the codebase,
gives future agents a stable schema to consume, and keeps real production
storage behind a reviewed future adapter.

## Architecture

### Deterministic Tool

Add:

```text
packages/zigeffect/tools/causal_durable_production_retention.zig
```

Build step:

```sh
cd packages/zigeffect
zig build causal-durable-production-retention
zig build causal-durable-production-retention -- --format json
```

The tool emits:

- schema metadata;
- source contract dependency on
  `zigeffect.causal.production-artifact-aggregation.v1`;
- recommended next branch,
  `codex/zigeffect-causal-production-deployment-runbooks`;
- NenDB retention policy;
- TTL policy as explicit day counts and future timestamp requirements;
- compaction policy;
- backup and recovery expectations;
- retained bundle fixture with source retention states;
- privacy gates inherited from artifact aggregation;
- non-goals and verification commands.

The tool is static and deterministic. It does not read artifact files or
inspect real NenDB state.

### NenDB Retention Helpers

Extend `packages/zigeffect/src/services/causal_nendb_storage_backend.zig` with
small public structs and functions:

```zig
pub const causal_nendb_retention_report_schema =
    "zigeffect.causal.nendb-retention-report.v1";

pub const CausalNendbRetentionPolicy = struct {
    max_events: ?usize = null,
    ttl_days: ?u32 = null,
    compaction_trigger_events: ?usize = null,
    compact_to_events: ?usize = null,
    backup_required: bool = false,
    recovery_required: bool = false,
};

pub const CausalNendbRetentionReport = struct {
    schema: []const u8,
    schema_version: u32,
    retained_events: usize,
    max_events: ?usize,
    ttl_days: ?u32,
    compaction_required: bool,
    backup_required: bool,
    recovery_required: bool,
    oldest_retained_event_id: ?u64,
    newest_retained_event_id: ?u64,
};
```

Add:

- `retentionReport(policy)` on `CausalNendbStorageBackendState`;
- a pure helper for report formatting or report derivation;
- tests that prove report values from a fake NenDB writer and retained events.

The report must be evaluative only. It does not delete, compact, upload,
restore, or mutate external storage.

### TTL Policy

TTL is a declared durable policy, not a clock read:

- local/CI contract fixtures use 14-day retention to match existing CI
  artifact guidance;
- future production bundles must carry capture metadata before TTL can be
  enforced;
- if timestamp metadata is missing, the report marks TTL as policy-only and
  recovery evidence incomplete, not silently satisfied.

### Compaction Policy

Compaction is a reviewable threshold:

- `compaction_trigger_events` says when a durable bundle should be compacted;
- `compact_to_events` says the target retained event count;
- compaction must preserve run roots, terminal failures, finding evidence, and
  policy/audit artifacts in a future implementation;
- this branch reports when compaction would be required, but does not compact
  stored history.

### Backup And Recovery

The contract defines backup and recovery expectations:

- backups must reference the retained bundle id, schema, source count, oldest
  and newest retained event ids, redaction state, and privacy gate result;
- recovery fixtures must prove the bundle can recover queryable causal
  lineage, not just raw bytes;
- restore mutation is not granted in this branch.

### Governance

Register `zigeffect.causal.durable-production-retention.v1` in schema
governance with compatibility `record-only`.

Update the production hardening backlog:

- mark `durable-production-retention` delivered;
- recommendation becomes `start-production-deployment-runbooks`;
- next branch becomes
  `codex/zigeffect-causal-production-deployment-runbooks`.

## Testing

Use test-driven implementation:

- direct tool tests for schema, next branch, NenDB-only constraints, fixture
  shape, privacy gates, text output, JSON output, and CLI parsing;
- `causal_nendb_storage_backend_test.zig` tests for retention report derivation;
- schema governance tests update the schema count and representative asserts;
- backlog tests update recommendation and delivered status.

Verification suite:

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
cd ../..
bun run check
bun run zig:test
git diff --check
```

## Success Criteria

- Agents can read one deterministic report to learn how durable production
  causal retention should work.
- The report explicitly depends on the artifact aggregation contract.
- NenDB retention helpers expose a stable policy/report API without live
  storage mutation.
- TTL, compaction, backup, and recovery are named with enough precision for the
  next implementation branch.
- Backlog handoff moves to production deployment runbooks.
- No Cockroach, React, live ingestion, dashboard, rollout, alerting, RBAC,
  encryption, or mutation authority is added.
- The full verification suite passes.
