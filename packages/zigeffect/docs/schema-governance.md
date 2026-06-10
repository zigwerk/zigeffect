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
- `spine-contract`: defines shared identity and relationship vocabulary without
  changing source event emission.
- `agent-query`: compact bounded graph slices for agents; read-only and
  policy-aware.

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

- `zigeffect.causal.production-deployment-runbooks.v1`

The production-deployment-runbooks report is a record-only production
hardening contract. It consumes production artifact aggregation and durable
retention contracts, then defines manual deployment, rollback, causal
verification, and incident-response gates. It does not deploy services, roll
back services, page humans, automate rollouts, or grant production mutation
authority.

- `zigeffect.causal.artifact-access-control.v1`

The artifact-access-control report is a record-only production hardening
contract. It consumes aggregation, durable-retention, and deployment-runbook
contracts, then defines visibility classes, role labels, permissions, access
decisions, denied-view fixtures, and access audit record fields. It does not
authenticate users, enforce live RBAC, modify the workbench, or grant mutation
authority.

- `zigeffect.causal.unified-spine-contract.v1`

The unified-spine-contract report is a record-only production hardening
contract. It defines the canonical runtime ids, app semantic ids, relationship
taxonomy, policy boundary, derived index families, and projection rules shared
by deep runtime internals, app semantic traces, agent queries, the SolidJS
`zig-webui` workbench, and NenDB adapter projections. It does not change live
runtime emission, implement app trace APIs, write durable storage, or grant
mutation authority.

- `zigeffect.causal.encryption-at-rest-policy.v1`

The encryption-at-rest-policy report is a record-only production hardening
contract. It consumes aggregation, durable-retention, and artifact
access-control contracts, then defines encryption domains, key owner labels,
rotation evidence, encrypted artifact fixture metadata, redaction ordering,
denied fixtures, and authority boundaries. It does not encrypt bytes, decrypt
bytes, generate keys, call a KMS, enforce live RBAC, or grant mutation
authority.

- `zigeffect.causal.alerting-integrations.v1`

The alerting-integrations report is a record-only production hardening
contract. It consumes aggregation, deployment-runbook, access-control,
encryption-policy, and agent-query contracts, then defines channel contracts,
severity/routing/escalation policy, payload fields, preview fixtures, negative
fixtures, and authority boundaries. It does not send notifications, create
tickets, forward SIEM events, page humans, read secrets, call networks, or
mutate external systems.

### Agent Query

- `zigeffect.causal.agent-query.v1`

The agent-query response is emitted by `causal-query --agent`. It is a compact
bounded graph slice for agents, with query name, arguments, selected events,
derived relationships, policy metadata, compatibility warnings, limitations,
and next-query hints. It is read-only evidence over the unified runtime spine.
Version `1` covers runtime queries and app semantic `trace_data` slices.
Cross-artifact run comparison remains a future schema-compatible extension.

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
