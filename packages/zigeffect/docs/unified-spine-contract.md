# zigeffect Unified Causal Spine Contract

`causal-unified-spine-contract` defines the shared causal truth model for the
next generation of zigeffect runtime intelligence.

It is a deterministic contract report. It does not change runtime emission,
add app trace APIs, modify the workbench, implement agent queries, write NenDB,
or grant mutation authority.

## Command

```sh
cd packages/zigeffect
zig build causal-unified-spine-contract
zig build causal-unified-spine-contract -- --format json
```

The text report is for maintainers. The JSON report uses schema
`zigeffect.causal.unified-spine-contract.v1` for agents, workbench planning, and
future backend adapters.

## What The Contract Means

The current `CausalEvent` artifact stays compatible. Existing `id` and
`parent_id` fields are mapped into the unified vocabulary as `event_id` and
`parent_event_id`; this branch does not rename the current v1 JSON artifact.

The contract exists so future branches can add deeper runtime facts and app
semantic facts without inventing incompatible names for the same graph.

## Canonical Runtime IDs

- `run_id`: stable execution or artifact run scope.
- `event_id`: stable append-only event id, mapped from current `CausalEvent.id`.
- `parent_event_id`: structural parent id, mapped from current
  `CausalEvent.parent_id`.
- `cause_id`: typed cause, finding, or cause-tree node reference.
- `fiber_id`: runtime fiber identifier.
- `scope_id`: resource lifetime scope identifier.
- `layer_id`: future layer graph node identifier.
- `service_key`: future service requirement/provider key.
- `resource_id`: future resource acquisition/finalizer identifier.

## App Semantic IDs

App semantic tracing should use stable references instead of raw app data:

- `artifact_id`
- `domain_entity_ref`
- `data_subject_ref`
- `schema_ref`

These references must not contain raw request bodies, headers, prompts,
credentials, payloads, secrets, or PII.

## Relationship Taxonomy

The shared relationship vocabulary is:

- `caused_by`
- `parent_of`
- `requires`
- `provides`
- `reads`
- `writes`
- `transforms`
- `emits`
- `owns`
- `finalizes`

These labels are used by future runtime indexes, agent query output, workbench
graphs, and NenDB edge projections.

## Projection Boundary

The spine is policy-first:

1. Runtime internals and app semantic APIs emit append-only source facts.
2. The unified spine normalizes ids and relationship records.
3. Redaction, sampling, truncation, access-control, and retention policy run
   before any consumer sees the data.
4. Derived indexes are built for cause, parent, fiber, scope, layer/service,
   data lineage, artifact, and findings views.
5. Human workbench views, agent queries, backend export, and NenDB projections
   consume read-only bounded projections.

Derived indexes are rebuildable and disposable. NenDB records are durable
projections, not source-of-truth events.

## Derived Index Families

- `cause_index`
- `parent_index`
- `fiber_index`
- `scope_index`
- `layer_service_index`
- `data_lineage_index`
- `artifact_index`
- `finding_index`

Indexes must expose limitation metadata when sampling, truncation, redaction, or
retention makes a slice incomplete.

## Consumers

- Deep runtime internals should emit layer, service, scope, fiber, resource,
  finalizer, retry, interruption, defect, and cause-chain facts through the
  canonical runtime ids.
- App semantic tracing should emit data reads/writes/transforms, service calls,
  domain actions, policy decisions, artifact emission, and responses using
  redacted refs.
- Agent queries should return bounded graph slices with event ids, relationship
  ids, policy state, confidence or limitation notes, verification commands, and
  next-query hints.
- The SolidJS `zig-webui` workbench should render read-only graph, timeline,
  findings, artifact, and remediation views that cite the same ids an agent
  receives.
- The NenDB adapter should persist post-policy nodes and edges without becoming
  the source event store.

## Non-Goals

- Live runtime emission changes.
- New app semantic API implementation.
- Workbench UI changes.
- Agent query implementation.
- Direct upstream NenDB dependency changes.
- Cockroach adapter work.
- React workbench support.
- Production mutation authority.
- Live telemetry ingestion.
- RBAC enforcement.

## Next Branch

The next branch is `codex/zigeffect-causal-deep-runtime-internals`.

That branch should start emitting the deeper runtime facts named here while
preserving the append-only source event boundary and existing v1 artifact
compatibility.
