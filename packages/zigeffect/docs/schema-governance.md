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
- `bounded-stream`: ordered dashboard frame records with declared truncation
  and redaction state.
- `spine-contract`: defines shared identity and relationship vocabulary without
  changing source event emission.
- `agent-query`: compact bounded graph slices for agents; read-only and
  policy-aware.
- `advisory-wall-clock`: observed timing evidence is comparable only when
  environment metadata is compatible and cannot fail CI or claim capacity
  without human review.
- `planning-only`: deterministic planning assumptions and missing-evidence
  gates only; not production sizing, telemetry, load testing, or mutation
  authority.
- `completion-audit`: deterministic milestone closure evidence with explicit
  remaining gaps and no production mutation authority.
- `exporter-boundary`: no-network exporter boundary evidence only; not OTLP
  serialization, collector configuration, live transport, or durable writes.
- `no-network`: confirms an artifact cannot send to a collector or configure a
  network transport.
- `local-pipeline-fixtures`: fixture-only local envelope shaping, redaction,
  sampling, and correlation evidence; not runtime pipeline execution.
- `workbench-readonly-preview`: human workbench evidence only; not live
  telemetry, durable writes, CI gates, hosted dashboard readiness, or mutation
  authority.
- `solid-webui`: SolidJS inside `webui-dev/zig-webui` is the reviewed workbench
  direction for this artifact family.

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
- `zigeffect.causal.live-dashboard-stream.v1`

Workbench sessions are `viewer-session` artifacts. They are local read-only
operating state, not remediation authority. The preferred UI path is SolidJS
with `webui-dev/zig-webui`; alternate renderers should be introduced only for a
specific future integration that cannot fit that path.

Live dashboard stream artifacts are `record-only`, `bounded-stream`,
`viewer-session` artifacts. They feed the Live tab and Visual Graph tab in the
SolidJS workbench. The first visual graph adapter is `@dschz/solid-g6` over
`@antv/g6`, with direct engine API usage reserved for future gaps.

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

- `zigeffect.causal.rollout-automation-guardrails.v1`

The rollout-automation-guardrails report is a record-only production hardening
contract. It consumes deployment runbooks, alerting integrations, and the
human-agent feedback loop, then defines canary evidence, rollout progression
gates, circuit-breaker decisions, rollback readiness gates, and negative
automation fixtures. It does not shift traffic, mutate feature flags, execute
rollbacks, send alerts, create tickets, page humans, or grant mutation
authority.

- `zigeffect.causal.wall-clock-benchmark-baselines.v1`

The wall-clock-benchmark-baselines report is a record-only production
hardening contract. It consumes the deterministic performance budget,
production artifact aggregation direction, and production-hardening backlog,
then defines local and CI benchmark scenario families, baseline record fields,
environment metadata, calibration policy, advisory review gates, and agent
guidance for future observation harnesses and capacity planning. It does not
collect live timings, fail CI from timing, run load tests, size production
capacity, write durable stores, or grant mutation authority.

- `zigeffect.causal.production-capacity-planning.v1`

The production-capacity-planning report is a record-only, `planning-only`
production hardening contract. It consumes aggregation, NenDB retention,
wall-clock benchmark baseline, live dashboard stream, visual graph, agent
query, human-agent feedback, alerting, and rollout guardrail evidence, then
records source contracts, capacity domains, storage assumptions, load-test
fixture plans, concurrency assumptions, readiness gates, and negative capacity
fixtures. It does not ingest telemetry, run load tests, size production
capacity, provision infrastructure, write durable storage, introduce non-NenDB
adapter work, add alternate workbench renderers, or grant mutation authority.

- `zigeffect.causal.production-hardening-completion-audit.v1`

The production-hardening-completion-audit report is a record-only,
`completion-audit` production hardening contract. It verifies delivered
hardening milestones, confirms record-only, `mutation_authority=none`,
NenDB-only, and SolidJS `zig-webui` boundaries, records remaining evidence
gaps, blocks over-claims, and hands off to the local load-test observation
harness. It does not ingest telemetry, execute load tests, size production
capacity, write durable storage, add non-NenDB adapter work, add alternate
workbench renderers, or grant mutation authority.

- `zigeffect.causal.load-test-observation-harness.v1`

The load-test-observation-harness report is a record-only,
`local-observation` production hardening contract. It catalogs approved local
scenario families and can opt in to bounded local observations with curated
argv arrays, warmup and measured iteration counts, median and p95 timings,
bounded stdout/stderr snippets, and advisory review gates. It does not run
production load, ingest production telemetry, fail CI, size production
capacity, execute shell strings, write durable storage, add non-NenDB adapter
work, add alternate workbench renderers, or grant mutation authority.

- `zigeffect.causal.production-telemetry-capture-design.v1`

The production-telemetry-capture-design report is a record-only,
`design-only`, `no-live-ingestion` production hardening contract. It defines
future capture surfaces, telemetry field requirements, redaction, sampling,
retention, access, encryption, OTel bridge, local-observation separation, and
fixture handoff gates. It does not ingest live production telemetry, configure
exporters, send OTLP, write durable production storage, size capacity, fail CI,
add non-NenDB adapter work, add alternate renderers, or grant mutation
authority.

- `zigeffect.causal.production-telemetry-capture-fixtures.v1`

The production-telemetry-capture-fixtures report is a record-only,
`fixtures-only`, `no-live-ingestion` production hardening contract. It emits
safe example records, selected fixture output, negative telemetry fixtures, and
validation checks for the production telemetry readiness review. It does not
ingest live production telemetry, configure exporters, send OTLP, write durable
production storage, size capacity, fail CI, add non-NenDB adapter work, add
alternate renderers, or grant mutation authority.

- `zigeffect.causal.production-telemetry-readiness-review.v1`

The production-telemetry-readiness-review report is a record-only,
`readiness-review`, `no-live-ingestion` production hardening contract. It
consumes capture fixture JSON, records reviewer decision and reason, verifies
coverage and authority boundaries, requires explicit verification command
evidence, and emits `ready` or `blocked` artifacts before a future
implementation proposal. It does not ingest live production telemetry,
configure exporters, send OTLP, write durable production storage, size
capacity, fail CI, add non-NenDB adapter work, add alternate renderers, or grant
mutation authority.

- `zigeffect.causal.production-telemetry-implementation-proposal.v1`

The production-telemetry-implementation-proposal report is a record-only,
`implementation-proposal`, `no-live-ingestion` production hardening contract.
It consumes a ready readiness-review artifact, records proposer decision and
reason, verifies readiness evidence and proposal command evidence, emits
`approved` or `blocked` artifacts, and hands off to the exporter-boundary
branch. It does not ingest live production telemetry, configure exporters, send
OTLP, write durable production storage, size capacity, fail CI, add non-NenDB
adapter work, add alternate renderers, or grant mutation authority.

- `zigeffect.causal.production-telemetry-exporter-boundary.v1`

The production-telemetry-exporter-boundary report is a record-only,
`exporter-boundary`, `no-network`, `no-live-ingestion` production hardening
contract. It consumes an approved implementation-proposal artifact, verifies
proposal evidence and verification commands, records an exporter-neutral
no-network boundary, records local envelope fixture names, and emits
`approved` or `blocked` artifacts before future local pipeline fixtures. It
does not ingest live production telemetry, configure exporters, send OTLP,
configure collector endpoints, write durable production storage, size
capacity, fail CI, add non-NenDB adapter work, add alternate renderers, or
grant mutation authority.

- `zigeffect.causal.production-telemetry-local-pipeline-fixtures.v1`

The production-telemetry-local-pipeline-fixtures report is a record-only,
`local-pipeline-fixtures`, `fixtures-only`, `no-network`, `no-live-ingestion`
production hardening contract. It consumes an approved exporter-boundary
artifact, verifies no-network evidence, records local envelope fixture records,
redaction and access fixture checks, sampling fixture checks, and emits
`ready` or `blocked` artifacts before future NenDB retention fixtures. It does
not run a telemetry pipeline, ingest live telemetry, configure exporters, send
OTLP, configure collector endpoints, write NenDB records, write durable
production storage, fail CI, add non-NenDB adapter work, add alternate
renderers, or grant mutation authority.

- `zigeffect.causal.production-telemetry-nendb-retention-fixtures.v1`

The production-telemetry-nendb-retention-fixtures report is a record-only,
`nendb-retention-fixtures`, `fixtures-only`, `no-network`,
`no-live-ingestion`, `no-durable-write` production hardening contract. It
consumes a ready local-pipeline-fixtures artifact, verifies source local
pipeline evidence, records NenDB node and edge mapping fixtures, retention
policy constants, compaction markers, backup markers, and recovery markers,
and emits `ready` or `blocked` artifacts before the future read-only workbench
preview. It does not ingest live telemetry, run a telemetry pipeline, configure
exporters, send OTLP, configure collector endpoints, write NenDB records, write
durable production storage, compact records, run backup or recovery, fail CI,
add non-NenDB adapter work, add alternate renderers, or grant mutation
authority.

- `zigeffect.causal.production-telemetry-workbench-readonly-preview.v1`

The production-telemetry-workbench-readonly-preview report is a record-only,
`workbench-readonly-preview`, `solid-webui`, `no-network`,
`no-live-ingestion`, `no-durable-write`, and `no-nendb-write` production
hardening contract. It consumes a ready NenDB-retention-fixtures artifact,
backs the read-only SolidJS `Telemetry` workbench tab and development sample,
records source checks, authority boundary evidence, mapping fixtures,
validation checks, blocked claims, and required verification commands, and
emits `ready` or `blocked` artifacts before future CI artifact preview work. It
does not ingest live telemetry, run a telemetry pipeline, configure exporters,
send OTLP, configure collector endpoints, write NenDB records, write durable
production storage, fail CI, host a production dashboard, add non-NenDB adapter
work, add alternate renderers, or grant mutation authority.

- `zigeffect.causal.production-telemetry-ci-artifact-preview.v1`

The production-telemetry-ci-artifact-preview report is a record-only,
`ci-artifact-preview`, `preview-only`, `failure-attachment-catalog`,
`no-network`, `no-live-ingestion`, `no-durable-write`, `no-nendb-write`, and
`no-ci-gate` production hardening contract. It consumes a ready workbench
read-only preview artifact, records source checks, authority boundary evidence,
mapping fixture ids, upload policy preview, artifact candidates, blocked
claims, and required verification commands, and emits `ready` or `blocked`
artifacts before future CI harness boundary work. It does not mutate GitHub
Actions, upload artifacts, configure CI retention, fail CI, ingest live
telemetry, run a telemetry pipeline, configure exporters, send OTLP, configure
collector endpoints, write NenDB records, write durable production storage,
host a production dashboard, add non-NenDB adapter work, add alternate
renderers, or grant mutation authority.

- `zigeffect.causal.production-telemetry-ci-harness-boundary.v1`

The production-telemetry-ci-harness-boundary report is a record-only,
`ci-harness-boundary`, `workflow-inspection`,
`cluster-release-gate-aware`, `no-workflow-mutation`,
`mutation-authority-none`, `no-live-ingestion`, `no-network`,
`no-durable-write`, `no-nendb-write`, and `no-ci-gate` production hardening
contract. It consumes a ready CI artifact preview, inspects the existing
causal GitHub Actions workflow, records workflow required-feature checks,
workflow prohibited-feature checks, clustering release-gate assumptions,
blocked claims, and required verification commands, and emits `ready` or
`blocked` artifacts before future CI archive application work. It does not
modify GitHub Actions, execute artifact upload changes, fail CI, ingest live
telemetry, run a telemetry pipeline, configure exporters, send OTLP, configure
collector endpoints, write NenDB records, write durable production storage,
host a production dashboard, orchestrate production clusters, add non-NenDB
adapter work, add alternate renderers, or grant mutation authority.

- `zigeffect.causal.production-telemetry-ci-archive-application.v1`

The production-telemetry-ci-archive-application report is a record-only,
guarded application, workflow-evidence, before/after-verification,
`cluster-release-gate-aware`, `no-tool-workflow-mutation`,
`mutation-authority-none`, `no-live-ingestion`, `no-network`,
`no-durable-write`, `no-nendb-write`, and `no-ci-gate` production hardening
contract. It consumes a ready CI harness boundary artifact and emits `planned`,
`applied`, or `blocked` archive application artifacts. It only records
`applied=true` when a separately reviewed workflow/archive change, before
evidence, after evidence, safe after-workflow checks, and required
post-application verification commands are present. It does not modify GitHub
Actions, execute artifact uploads, enable CI gates, ingest live telemetry, run
a telemetry pipeline, configure exporters, send OTLP, configure collector
endpoints, write NenDB records, write durable production storage, host a
production dashboard, orchestrate production clusters, add non-NenDB adapter
work, add alternate renderers, or grant mutation authority.

- `zigeffect.causal.production-telemetry-ci-archive-evidence-policy.v1`

The production-telemetry-ci-archive-evidence-policy report is a record-only,
archive-evidence-policy, interpretation-policy,
`cluster-release-gate-aware`, `mutation-authority-none`,
`no-live-ingestion`, `no-network`, `no-durable-write`, `no-nendb-write`,
`no-workflow-mutation`, and `no-ci-gate` production hardening contract. It
consumes planned or applied CI archive application artifacts and emits `ready`
or `blocked` policy artifacts that define allowed archive evidence classes,
required provenance metadata, interpretation rules, denied claims, negative
fixtures, blocked claims, and required verification commands before future CI
gate readiness work. It does not modify GitHub Actions, execute artifact
uploads, enable CI gates, ingest live telemetry, run a telemetry pipeline,
configure exporters, send OTLP, configure collector endpoints, write NenDB
records, write durable production storage, host a production dashboard,
orchestrate production clusters, add non-NenDB adapter work, add alternate
renderers, or grant mutation authority.

- `zigeffect.causal.production-telemetry-ci-gate-readiness.v1`

The production-telemetry-ci-gate-readiness report is a record-only,
ci-gate-readiness, gate-semantics, `cluster-release-gate-aware`,
`mutation-authority-none`, `no-live-ingestion`, `no-network`,
`no-durable-write`, `no-nendb-write`, `no-ci-gate-enforcement`, and
`no-workflow-mutation` production hardening contract. It consumes ready archive
evidence policy artifacts and emits `ready` or `blocked` readiness artifacts
with readiness dimensions, advisory candidate gate signals, limited gate
semantics, release-gate verification evidence, negative fixtures, blocked
claims, and required verification commands before future gate application
boundary work. It does not modify GitHub Actions, execute artifact uploads,
enable CI gates, create required status checks, ingest live telemetry, run a
telemetry pipeline, configure exporters, send OTLP, configure collector
endpoints, write NenDB records, write durable production storage, host a
production dashboard, orchestrate production clusters, add non-NenDB adapter
work, add alternate renderers, or grant mutation authority.

- `zigeffect.causal.production-telemetry-ci-gate-application-boundary.v1`

The production-telemetry-ci-gate-application-boundary report is a record-only,
gate-application-boundary, plan-or-record-applied,
before-after-verification, `cluster-release-gate-aware`,
`mutation-authority-none`, `no-live-ingestion`, `no-network`,
`no-durable-write`, `no-nendb-write`, `no-ci-gate-enforcement`, and
`no-tool-workflow-mutation` production hardening contract. It consumes ready CI
gate readiness artifacts and emits `planned`, `applied`, or `blocked`
application boundary artifacts. It only records `applied=true` when reviewed
workflow-change evidence, before evidence, after evidence, after-workflow
content, safe after-workflow checks, and all post-application verification
commands are present. It does not mutate workflows, enable CI gate
enforcement, create required status checks, execute artifact uploads, ingest
live telemetry, write NenDB, write durable production storage, host a
production dashboard, orchestrate production clusters, add non-NenDB adapter
work, add alternate renderers, or grant production mutation authority.

### Human-Agent Feedback

- `zigeffect.causal.human-agent-feedback-loop.v1`

The human-agent-feedback-loop report is a record-only bridge between the
SolidJS `zig-webui` workbench and bounded agent query reports. It records the
failure-to-query, before/after comparison, regression clustering, guarded
handoff, and future NenDB history-handoff stages. It does not execute queries,
apply remediation, write durable history, or grant mutation authority.

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
