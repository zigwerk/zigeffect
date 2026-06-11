# Production Hardening Backlog Refresh

Schema:
`zigeffect.causal.production-hardening-backlog-refresh.v1`

Build step:
`causal-production-hardening-backlog-refresh`

This tool consumes a production-hardening backlog JSON report, validates that
the required-status-check enforcement report policy chain has reached its
terminal delivered item, records unresolved roadmap candidates, and selects the
next branch:

`codex/zigeffect-causal-nendb-durable-history-hardening`

## Command

```sh
cd packages/zigeffect
mkdir -p ../../.zig-cache/causal-artifacts
zig build causal-production-hardening-backlog -- --format json 2> ../../.zig-cache/causal-artifacts/production-hardening-backlog.json
zig build causal-production-hardening-backlog-refresh -- \
  --from-backlog ../../.zig-cache/causal-artifacts/production-hardening-backlog.json \
  refresh \
  --reason "production hardening backlog refreshed after report policy" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

## Candidate Order

The selected candidate is `nendb-durable-history-hardening`. It comes before
cross-run agent queries, arbitrary audit-chain snapshot comparison, and
production app-facing integration fixtures because persisted causal history is
the evidence substrate those branches need.

Follow-up candidates:

- `agent-query-cross-run-comparison`
- `audit-chain-snapshot-compare`
- `app-facing-production-integration-fixtures`

## Authority Boundary

The refresh is a handoff artifact only. It does not mutate source, config,
registry, workflow, branch protection, deployment, rollout, app, or production
state. It does not call GitHub APIs, create checks, create required status
checks, upload artifacts, write step summaries, post pull request comments,
ingest live telemetry, send OTLP, execute a runtime pipeline, write durable
state, or write NenDB.

Durable database work remains NenDB adapter work only. Cockroach and non-NenDB
adapter scope stay out of this sequence.

`mutation_authority` is always `none`.

## Verification

```sh
zig test tools/causal_production_hardening_backlog_refresh.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-production-hardening-backlog-refresh -- --help
zig build causal-schema-governance -- --format json
zig build examples
zig build test
```
