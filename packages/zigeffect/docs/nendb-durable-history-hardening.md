# zigeffect Causal NenDB Durable History Hardening

`causal-nendb-durable-history-hardening` emits deterministic local evidence for
the NenDB causal storage adapter. It proves that the adapter can retain
queryable history beyond the core store retention window, expose writer and
flush posture, report redaction evidence, and hand agents a stable
durable-history artifact.

Schema:
`zigeffect.causal.nendb-durable-history.v1`.

## Command

```sh
cd packages/zigeffect
zig build causal-nendb-durable-history-hardening
zig build causal-nendb-durable-history-hardening -- --format json
zig build causal-nendb-durable-history-hardening -- --out-prefix ../../.zig-cache/causal-artifacts/nendb-durable-history-hardening
```

Default artifact paths:

- `.zig-cache/causal-artifacts/nendb-durable-history-hardening.json`
- `.zig-cache/causal-artifacts/nendb-durable-history-hardening.txt`

## Runtime API

The runtime API is exposed from
`CausalNendbStorageBackendState.durableHistoryReport`.

It returns `CausalNendbDurableHistoryReport` with:

- retained event count and event id bounds;
- written, failed, and flushed counters;
- node, edge, and durable-history schemas;
- flush, redaction, lineage, compaction, backup, and recovery posture;
- denied authority flags for live telemetry, network send, durable production
  writes, NenDB production write authority, Cockroach, and mutation authority.

`CausalNendbGraphWriter` remains the only writer boundary. This branch does not
import the upstream NenDB package directly.

## Ready Checks

The default local fixture is ready when:

- a `CausalNendbGraphWriter` is attached;
- at least one node write is recorded;
- at least one `causal_parent` edge is recorded;
- a flush is observed when flush is required;
- adapter history outlives the bounded core store retention window;
- cause queries restore expected root and child event ids;
- lineage queries find retained descendants;
- redaction marker evidence is present;
- raw test secrets are absent;
- all authority flags stay NenDB-only and record-only.

Blocked artifacts are stop signs for follow-up agent-query work.

## Authority Boundary

This artifact is local fixture and runtime posture evidence only. It does not
ingest production telemetry, send network data, serialize OTLP, write durable
production storage, grant NenDB production write authority, run compaction,
backup, restore, or TTL deletion, add Cockroach or non-NenDB adapters, open a
production dashboard, mutate source/config/registry/app/workflow/deployment
state, or grant mutation authority.

`mutation_authority` is always `none`.

## Handoff

Ready evidence hands off to:

`codex/zigeffect-causal-agent-query-compare-runs`

That follow-up can use durable-history evidence for cross-run comparison, but
must still keep query responses bounded, redacted, and read-only.

## Verification

```sh
cd packages/zigeffect
zig build causal-nendb-storage-backend
zig test --dep zigeffect -Mroot=tools/causal_nendb_durable_history_hardening.zig -Mzigeffect=src/zigeffect.zig
zig build causal-nendb-durable-history-hardening
zig build causal-schema-governance -- --format json
zig build examples
zig build test
```
