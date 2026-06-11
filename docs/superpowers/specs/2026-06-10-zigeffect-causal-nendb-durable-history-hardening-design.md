# zigeffect Causal NenDB Durable History Hardening Design

## Summary

This branch turns the existing NenDB-shaped causal storage backend from a useful
adapter fixture into a hardened durable-history boundary that agents can reason
about. It keeps the work deliberately narrow: zigeffect gains stronger runtime
evidence about what has been retained, written, flushed, redacted, bounded, and
queryable through the NenDB adapter path, but it does not add Cockroach,
non-NenDB adapters, live production ingestion, upstream NenDB package coupling,
or production mutation authority.

The selected branch is
`codex/zigeffect-causal-nendb-durable-history-hardening`, as chosen by
`zigeffect.causal.production-hardening-backlog-refresh.v1`.

## Goals

- Add an agent-readable `zigeffect.causal.nendb-durable-history.v1` report that
  summarizes durable-history posture for `CausalNendbStorageBackendState`.
- Prove that written NenDB-shaped node and edge records remain queryable through
  local retained history after the core causal store has applied its own
  retention window.
- Harden the adapter against misleading claims by exposing explicit counters,
  bounds, redaction posture, flush posture, compaction posture, and denied
  authority fields.
- Provide a deterministic build step,
  `causal-nendb-durable-history-hardening`, that emits a local fixture report for
  agents and reviewers.
- Update schema governance, operations docs, roadmap, README, and the production
  hardening backlog so the next milestone can depend on durable history evidence.

## Non-Goals

- No Cockroach adapter, SQL adapter, D1, R2, RoachGraph, or non-NenDB durable
  backend work.
- No direct import of `webui-dev/zig-webui` or upstream NenDB package APIs.
  `CausalNendbGraphWriter` remains the dependency boundary that future wrappers
  can target.
- No live telemetry ingestion, runtime production pipeline, network send, OTLP
  export, dashboard hosting, deployment, rollout, or CI enforcement.
- No source/config/registry/app/workflow/branch-protection/deployment mutation.
- No actual compaction, backup, restore, TTL deletion, or production health
  claim. Those remain evidence contracts until a reviewed authority branch
  grants more power.

## Current Context

`packages/zigeffect/src/services/causal_nendb_storage_backend.zig` already:

- maps `CausalEvent` values to NenDB-shaped `CausalNendbNode` and
  `CausalNendbEdge` records;
- writes through a caller-provided `CausalNendbGraphWriter`;
- keeps cloned, sanitized local history for immediate `snapshot`, `cause`,
  `lineage`, `eventsByKind`, `eventsByRun`, `eventsByScope`, and
  `eventsByFiber` queries;
- fails closed on writer failure or `max_events` overflow;
- exposes a `CausalNendbRetentionReport` for retained event counts, bounds, and
  policy posture.

`packages/zigeffect/docs/durable-production-retention.md` already defines the
production-hardening policy: NenDB adapter only, 14-day fixture TTL, 4096 max
events per bundle, compaction trigger at 2048 events, compact target 1024
events, backup required, recovery required, and record-only authority.

This branch builds on those facts rather than replacing them.

## Chosen Approach

### Approach A: Runtime Report Plus Deterministic Fixture Tool

Add a small durable-history report type and formatter to the existing NenDB
storage backend. The report is generated directly from runtime state, so agents
can inspect the same boundary the adapter uses in tests. Add a separate Zig tool
that creates a deterministic local fixture, exercises the backend through a fake
writer, and emits text/JSON reports.

This is the chosen approach because it hardens the runtime API while preserving
the local, dependency-free test harness that has made the causal system easy to
verify.

### Approach B: Policy-Only Artifact

Add only a standalone tool that describes NenDB durable history requirements.
This would be fast, but it would not improve the actual runtime boundary, and it
would leave agents reading policy without counters from the backend state.

### Approach C: Direct Upstream NenDB Integration

Wrap real upstream NenDB APIs immediately. This would move toward real
persistence sooner, but it would introduce package integration, live write
semantics, and operational uncertainty before the local adapter contract is
hardened. It also conflicts with the current no-new-durable-adapter constraint.

## Runtime Design

Add these public constants and types to
`packages/zigeffect/src/services/causal_nendb_storage_backend.zig`:

- `causal_nendb_durable_history_schema =
  "zigeffect.causal.nendb-durable-history.v1"`;
- `causal_nendb_durable_history_schema_version = 1`;
- `CausalNendbDurableHistoryPolicy`;
- `CausalNendbDurableHistoryReport`.

The policy should mirror the existing retention policy while adding the
durable-history assertions that agents care about:

- `max_events`;
- `ttl_days`;
- `compaction_trigger_events`;
- `compact_to_events`;
- `backup_required`;
- `recovery_required`;
- `flush_required`;
- `redaction_required`;
- `lineage_query_required`.

The report should include:

- schema and schema version;
- `backend_kind = "nendb_graph"`;
- `storage_adapter = "NenDB adapter"`;
- retained event count and max events;
- written event count, failed event count, flushed count;
- oldest and newest retained event id;
- `node_schema` and `edge_schema`;
- booleans for `writer_attached`, `flush_required`, `flush_observed`,
  `redaction_required`, `redaction_observed`, `lineage_query_required`,
  `lineage_query_supported`, `compaction_required`, `backup_required`,
  `recovery_required`;
- denied authority booleans: `live_telemetry_enabled=false`,
  `network_send_enabled=false`, `durable_write_authority=false`,
  `nendb_write_authority=false`, `cockroach_adapter_enabled=false`,
  `mutation_authority="none"`.

`CausalNendbStorageBackendState.durableHistoryReport(policy)` should be
deterministic and allocation-free, like `retentionReport`. It should not read
the clock, inspect the filesystem, call a network, or call the writer.

## Query And Recovery Evidence

The existing query methods are the recovery evidence surface for this branch:

- `snapshot` proves retained history can be copied out;
- `cause` proves a causal path can be reconstructed;
- `lineage` proves immediate descendants can be found;
- `eventsByRun`, `eventsByScope`, `eventsByFiber`, and `eventsByKind` prove
  agent-oriented filtering remains available.

The new tests should exercise these methods after writing through the fake
writer, including after the core store has dropped earlier events from its own
retention window. The durable-history report should claim
`lineage_query_supported=true` only because those scan-based methods exist on
the adapter state, not because a production restore has happened.

## Redaction And Bounds

The report should not claim perfect redaction. It should report
`redaction_required=true` and `redaction_observed=true` when retained history or
NenDB-shaped writes contain the causal redaction marker and do not contain known
test secrets from the fixture. Negative tests should prove the report/tool does
not convert missing redaction evidence into a ready status.

Bounded memory remains explicit. If `max_events` is reached, the backend keeps
its current fail-closed behavior. This branch should not silently evict history;
eviction and compaction semantics require a separate reviewed branch because
they change query results.

## Fixture Tool

Add `packages/zigeffect/tools/causal_nendb_durable_history_hardening.zig` with
build step `causal-nendb-durable-history-hardening`.

The tool should:

- create a fake `CausalNendbGraphWriter`;
- record a deterministic trace through `CausalStore` with a small store
  retention window;
- write through `CausalNendbStorageBackendState`;
- flush the writer;
- verify retained history queries;
- produce text and JSON reports with schema
  `zigeffect.causal.nendb-durable-history.v1`;
- emit local artifacts under
  `../../.zig-cache/causal-artifacts/nendb-durable-history-hardening.json` and
  `.txt` unless an `--out-prefix` is provided;
- expose `--help`, `--format text|json`, and `--out-prefix`.

Ready status requires:

- writer attached;
- at least one node write;
- parent edge write present;
- flush observed when flush is required;
- retained history count exceeds the source store retention window in the
  fixture;
- cause and lineage queries return expected event ids;
- redaction marker observed and raw secret absent;
- no Cockroach/non-NenDB/live/network/mutation authority flags enabled.

Blocked status is allowed for negative fixtures, but the default tool path
should create a ready local fixture.

## Schema Governance

Add schema governance entry:

- schema: `zigeffect.causal.nendb-durable-history.v1`;
- category: `backend-export`;
- emitted by: `CausalNendbStorageBackendState.durableHistoryReport` and
  `causal-nendb-durable-history-hardening`;
- consumed by: agents, reviewers, future cross-run query comparison, future
  audit-chain snapshot comparison, and app-facing production fixtures;
- compatibility: `strict-v1`, `nendb-only`, `local-fixture`, `record-only`,
  `no-cockroach`, `no-live-telemetry`, `no-network`, `no-production-mutation`.

The governance schema count should increment from 80 to 81.

## Documentation Updates

Update:

- `packages/zigeffect/docs/nendb-durable-history-hardening.md` with command,
  runtime API, ready checks, denied claims, and verification commands.
- `packages/zigeffect/docs/durable-production-retention.md` to mention this
  runtime hardening report as the adapter evidence layer.
- `packages/zigeffect/docs/production-hardening-backlog.md` and
  `packages/zigeffect/tools/causal_production_hardening_backlog.zig` to mark the
  branch delivered and recommend the next branch
  `codex/zigeffect-causal-agent-query-compare-runs`.
- `packages/zigeffect/docs/roadmap.md`, `packages/zigeffect/docs/operations.md`,
  `packages/zigeffect/docs/schema-governance.md`, and
  `packages/zigeffect/README.md` to expose the new command.
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  to record this milestone and the next handoff.

## Testing Strategy

Use TDD:

1. Add failing tests in `packages/zigeffect/test/causal_nendb_storage_backend_test.zig`
   for durable-history report fields and redaction/query evidence.
2. Add failing tests in the new tool for schema constants, ready JSON, blocked
   negative evidence, and denied claims.
3. Implement the runtime report.
4. Implement the fixture tool and build step.
5. Update schema governance tests.
6. Run focused checks:
   - `zig build causal-nendb-storage-backend`;
   - `zig test tools/causal_nendb_durable_history_hardening.zig`;
   - `zig build causal-nendb-durable-history-hardening`;
   - `zig build causal-schema-governance -- --format json`.
7. Run full checks:
   - `zig build examples`;
   - `zig build test`;
   - `bun run check`;
   - `bun run zig:test`;
   - `git diff --check`.

## Risks And Mitigations

- **Risk:** Agents could over-read local fixture readiness as production durable
  storage proof.
  **Mitigation:** Every report includes denied claims and
  `mutation_authority="none"`.

- **Risk:** Runtime report duplicates retention report semantics.
  **Mitigation:** Treat retention report as policy/bounds and durable-history
  report as agent evidence that combines retention, writer, flush, redaction,
  and query posture.

- **Risk:** The backend file grows too large.
  **Mitigation:** Keep the report allocation-free and colocated with the state
  it summarizes for this branch. Split formatting/tool logic into the new tool
  instead of bloating the service file.

- **Risk:** Future real NenDB wrapper expectations leak into this branch.
  **Mitigation:** Keep `CausalNendbGraphWriter` as the only writer boundary and
  document upstream NenDB calls as future wrapper work.

## Success Criteria

- The runtime exposes `CausalNendbDurableHistoryReport` and schema constants.
- The default fixture tool emits a ready
  `zigeffect.causal.nendb-durable-history.v1` report.
- Tests prove queryable history, redaction evidence, flush evidence, fail-closed
  bounds, and denied Cockroach/mutation/live-production claims.
- Schema governance count is 81 and includes the new schema.
- The production hardening backlog advances to
  `codex/zigeffect-causal-agent-query-compare-runs`.
