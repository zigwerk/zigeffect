# zigeffect Schema Governance

`causal-schema-governance` is the authoritative registry for current causal
artifact schemas. Use it before adding a new artifact family, changing an
artifact shape, or teaching an agent to consume a causal report.

## Command

```sh
cd packages/zigeffect
zig build causal-schema-governance
zig build causal-schema-governance -- --format json
```

The default text report is for humans. The JSON report uses schema
`zigeffect.causal.schema-governance.v1` and is the machine-readable matrix for
agents and CI checks.

When a schema change affects retained artifacts, CI upload behavior, workbench
mapping, or agent handoff, also update [operations.md](operations.md).

## Versioning Policy

- `schema` names the artifact family.
- `schema_version` tracks the current shape inside that family.
- `event_taxonomy_version` tracks event-kind role semantics.
- Additive optional fields may keep the current version only when current
  consumers ignore unknown fields and tests cover graceful behavior.
- Required, renamed, removed, or semantically changed fields require a version
  bump and compatibility tests.
- New event kinds or role/sampleability changes require an event taxonomy
  version bump.

## Migration Policy

- Legacy core causal artifacts without root schema metadata remain readable.
- Current core tools warn, not crash, when future schema or taxonomy versions
  can still provide event ids.
- Strict governance artifacts fail closed on unsupported schema or version.
- Rewrite tooling is deferred until a real v2 artifact exists.

## Compatibility Postures

- `legacy-tolerant`: accepts missing metadata and keeps event ids usable.
- `warn-forward`: warns on newer schema/taxonomy while preserving known fields.
- `strict-v1`: requires exact schema family and version `1`.
- `sink-contract`: emitted for downstream backend/export systems.
- `record-only`: records review/application state without mutating source.
- `viewer-session`: read-only local workbench/session operating state.

## New Schema Checklist

- Add schema name and version.
- Add producer tests.
- Add consumer or compatibility tests.
- Add a schema governance registry entry.
- Add README or guide docs.
- Add workbench mapping when user-facing.
- Add artifact manifest entries when retained in `.zig-cache/causal-artifacts`.

## Official Schema Matrix

### Core Runtime

- `zigeffect.causal.v1`
  - Current version: `1`
  - Producers: `formatCausalJson`
  - Consumers: `causal-query`, `causal-compare`, `causal-loop`,
    `causal-advice`, `causal-workbench`
  - Compatibility: `legacy-tolerant`, `warn-forward`

### Backend Export

- `zigeffect.causal.event.v1`
- `zigeffect.causal.otel_record.v1`
- `zigeffect.causal.nendb_node.v1`
- `zigeffect.causal.nendb_edge.v1`
- `zigeffect.causal.nendb-retention-report.v1`

Backend export schemas are sink contracts. They are guarded by backend
conformance, adapter, bounded-history, and redaction tests rather than by core
causal query compatibility. The NenDB retention report is record-only evidence
derived from adapter-owned history and policy, not a durable mutation command.

### App Runtime

- `zigeffect.causal.app-runtime.v1`

App runtime artifacts remain record-only app evidence. User-facing mappings
belong in the SolidJS workbench launched through `zig-webui`.

### Dev Loop

- `zigeffect.causal.dev-loop-verdict.v1`
- `zigeffect.causal.dev-session.v1`
- `zigeffect.causal.ci-verdict.v1`

Dev-loop artifacts are agent handoff records. They should keep exact next
query/advice commands and remain safe to attach to failed CI jobs after
redaction review.

### Workbench

- `zigeffect.causal.workbench-session.v1`

Workbench sessions are `viewer-session` artifacts. They are local read-only
operating state, not remediation authority. The preferred UI path is SolidJS
with `webui-dev/zig-webui`; React should be introduced only for a specific
future integration that cannot fit that path.

### Operating Model

- `zigeffect.causal.performance-budget.v1`

The performance-budget report is a record-only operating-model artifact. It
names deterministic overhead budgets, release-review checks, and verification
commands for causal runtime changes. It is not a wall-clock benchmark, mutation
surface, production dashboard, or capacity plan.

- `zigeffect.causal.m9-completion-audit.v1`

The M9 completion audit is a record-only operating-model artifact. It proves
the local/CI causal operating-model deliverables, records deferred production
gaps, and gives agents a stable recommendation before the roadmap marks M9
delivered.

- `zigeffect.causal.production-hardening-backlog.v1`

The production-hardening backlog is a record-only operating-model artifact. It
turns the M9 deferred production gaps into an ordered future branch queue with
dependencies, constraints, non-goals, verification commands, and the next
recommended production-hardening branch. It does not grant production mutation
authority, add production telemetry, or change the NenDB-only durable adapter
direction.

### Production Hardening

- `zigeffect.causal.production-artifact-aggregation.v1`

The production-artifact-aggregation report is a record-only production
hardening contract. It defines aggregation bundle semantics, source provenance
fields, privacy review gates, and a deterministic local/CI sample bundle for
future durable retention, access control, workbench, integration, benchmark,
and capacity planning branches. It does not ingest live production telemetry or
write durable storage.

- `zigeffect.causal.durable-production-retention.v1`

The durable-production-retention report is a record-only production hardening
contract. It consumes the production artifact aggregation schema and defines
the NenDB-only TTL, compaction, backup, recovery, retained-bundle fixture, and
verification expectations. It does not ingest live telemetry, enforce TTL from
wall-clock time, restore production data, or grant mutation authority.

### Test Coverage

- `zigeffect.causal.test-matrix.v1`

The matrix records causal scenario and invariant coverage. It is advisory
coverage evidence for agents and docs.

### Governance

- `zigeffect.causal.remediation-audit.v1`
- `zigeffect.causal.remediation-decision.v1`
- `zigeffect.causal.patch-proposal.v1`
- `zigeffect.causal.audit-chain.v1`
- `zigeffect.causal.policy-decision.v1`

Governance artifacts use strict v1 validation and record-only semantics. They
can approve, reject, explain, or chain evidence, but they do not mutate source
or external systems.

### Registry

- `zigeffect.causal.scenario-proposal.v1`
- `zigeffect.causal.registry-patch.v1`
- `zigeffect.causal.registry-application-readiness.v1`
- `zigeffect.causal.registry-application.v1`

Registry artifacts stay inside the reviewed scenario-registry boundary.
`applied=true` may appear only after readiness, reviewed registry changes, and
before/after verification evidence are recorded.

### Snapshot Replay

- `zigeffect.causal.snapshot-manifest.v1`
- `zigeffect.causal.snapshot-compare.v1`
- `zigeffect.causal.replay-feasibility.v1`
- `zigeffect.causal.deterministic-replay.v1`
- `zigeffect.causal.scenario-fork-proposal.v1`

Snapshot and replay artifacts summarize named causal evidence. They may compare
or replay registered scenarios, but arbitrary runtime memory forking remains
out of scope.

### App Remediation

- `zigeffect.causal.app-remediation-audit.v1`
- `zigeffect.causal.app-policy-decision.v1`
- `zigeffect.causal.app-human-review.v1`
- `zigeffect.causal.app-patch-proposal.v1`
- `zigeffect.causal.app-application-readiness.v1`
- `zigeffect.causal.app-application.v1`

App remediation artifacts are strict v1, record-only evidence until the guarded
application record says otherwise. Workbench mappings should make the policy
gates, human review, readiness checks, change evidence, and before/after
verification easy to inspect without making the workbench a mutation surface.
