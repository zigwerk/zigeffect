# App-Facing Production Integration Fixtures

`causal-app-facing-production-integration-fixtures` emits
`zigeffect.causal.app-facing-production-integration-fixtures.v1` as a
deterministic fixture-only catalog for app production evidence.

The catalog connects app runtime traces, app semantic refs, agent query output,
retained audit-chain comparison, app remediation governance, production
telemetry fixture boundaries, and NenDB durable-history handoff. It is meant
for agents and reviewers that need to reason about app-facing production
integration before any live integration exists.

## Command

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-fixtures
zig build causal-app-facing-production-integration-fixtures -- --format json
zig build causal-app-facing-production-integration-fixtures -- emit worker-request-redacted-lineage --format json
zig build causal-app-facing-production-integration-fixtures -- validate --format json
```

The command is local and deterministic. It does not read production systems,
use clocks, open networks, inspect generated production artifacts, or mutate
source files.

## Fixture Ids

- `worker-request-redacted-lineage`: Worker request lineage with method, route,
  runtime, schema refs, and data refs.
- `background-job-nendb-history-handoff`: background-job evidence that points
  at NenDB durable-history refs without writing production storage.
- `agent-query-app-trace-data`: bounded `causal-query --agent trace_data`
  evidence for app semantic refs.
- `audit-chain-before-after-app-review`: retained before/after governance
  posture from audit-chain snapshot comparison.
- `app-remediation-governance-bridge`: app incident evidence through audit,
  policy, human review, proposal, readiness, and guarded application records.
- `production-telemetry-fixture-boundary`: source-contract link to production
  telemetry capture fixtures without enabling live transport.

## Source Contracts

The fixture catalog names source contracts for:

- `zigeffect.causal.app-runtime.v1`;
- `zigeffect.causal.agent-query.v1`;
- `zigeffect.causal.audit-chain-snapshot-compare.v1`;
- `zigeffect.causal.nendb-durable-history.v1`;
- `zigeffect.causal.production-telemetry-capture-fixtures.v1`;
- the app remediation chain from app audit through app application evidence.

Each contract is record-only or fixture-only. None grants production mutation
authority.

## Boundaries

Every report keeps:

- `applied=false`;
- `mutation_authority="none"`;
- `production_telemetry_ingestion=false`;
- `live_exporter_enabled=false`;
- `durable_write_enabled=false`;
- `app_mutation_enabled=false`;
- `ci_gate_enabled=false`.

Durable scope is NenDB adapter scope only. Cockroach and non-NenDB adapter work
remain out of scope.

## Negative Claims

Agents should reject claims that these fixtures authorize:

- raw request body, header, prompt, credential, token, tenant id, raw user id,
  or PII capture;
- live production telemetry ingestion;
- live exporter or collector endpoint configuration;
- production durable writes;
- non-NenDB durable adapters or Cockroach work;
- app source, config, migration, data, deployment, rollout, rollback, or
  operational mutation;
- treating audit-chain comparison as proof of app mutation;
- scraping raw app payloads from agent-query output;
- CI gate enforcement;
- React or alternate renderer work.

The safe alternative is to cite fixture ids, source contracts, event ids,
query ids, redacted refs, validation checks, and the next reviewed branch.

## Next Branch

The catalog hands off to:

`codex/zigeffect-causal-app-facing-production-integration-readiness-review`

That branch should consume this fixture report and decide whether app-facing
production integration is ready for implementation proposal work. It should
not grant live telemetry, durable production writes, app mutation, CI gates,
Cockroach scope, or alternate renderer scope.
