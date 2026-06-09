# zigeffect Causal Unified Spine Contract Design

Date: 2026-06-09
Branch: `codex/zigeffect-causal-unified-spine-contract`
Status: Approved for implementation

## Goal

Define one stable causal truth model that can be consumed by zigeffect runtime
internals, app semantic tracing, the SolidJS `zig-webui` workbench, the agent
query interface, and durable NenDB graph projections.

This branch is a contract milestone. It does not change live runtime emission
yet. It gives the next branches a precise vocabulary, relationship taxonomy,
projection boundary, and verification artifact.

## Problem

The current causal system has strong local primitives:

- `CausalEvent` records `id`, `kind`, `run_id`, `parent_id`, `fiber_id`,
  `scope_id`, trace ids, labels, type names, status, and redacted detail.
- Query tools already reason about causes, lineage, resources, fibers,
  requirements, retries, findings, and before/after artifacts.
- App-facing remediation tools can reason about incidents and proposals.
- NenDB, workbench, schema governance, access control, retention, and production
  hardening docs already exist as separate artifacts.

The missing piece is a single contract that says how all those surfaces align.
Without it, future runtime internals, app semantic events, graph visualization,
agent queries, and durable records can drift into similar but incompatible
schemas.

## Design Principles

- The append-only causal store is the source of truth for emitted runtime/app
  facts.
- Policy sits between source events and every projection.
- Derived indexes are disposable views, not mutation authorities.
- Human and agent surfaces use the same event spine but expose different
  ergonomics.
- Durable NenDB records are downstream projections, not the source of truth.
- Agents receive bounded, redacted, loss-aware graph slices with evidence ids and
  recommended next queries.
- The SolidJS workbench remains read-only until a later reviewed authority branch
  grants more.
- No raw request bodies, headers, prompts, credentials, payloads, secrets, or PII
  belong in the spine.

## Canonical Runtime IDs

The contract names these runtime identifiers. Existing fields remain valid and
are mapped into the contract instead of renamed in this branch.

- `run_id`: stable execution or artifact run scope.
- `event_id`: stable event id. Current artifacts store this as `id`.
- `parent_event_id`: direct structural parent event. Current artifacts store this
  as `parent_id`.
- `cause_id`: typed cause, finding, or cause-tree node reference derived from
  event evidence.
- `fiber_id`: runtime fiber identifier.
- `scope_id`: resource/lifetime scope identifier.
- `layer_id`: layer graph node identifier for future runtime internals.
- `service_key`: stable service requirement/provider key.
- `resource_id`: stable resource acquisition/finalizer identifier.

## Canonical App Semantic IDs

App semantic tracing adds references, not raw application data.

- `artifact_id`: generated report, response, file, bundle, or app artifact.
- `domain_entity_ref`: redacted stable reference to an app domain entity.
- `data_subject_ref`: redacted stable reference to a user, account, tenant, or
  other regulated subject.
- `schema_ref`: stable schema or version reference for data read/write/transform
  events.

## Relationship Taxonomy

Relationship types are stable labels used by runtime indexes, agent query output,
workbench graph views, and NenDB edge projections.

- `caused_by`: event or finding was caused by another event.
- `parent_of`: structural parent/child relationship.
- `requires`: effect/layer/action requires a service, config, resource, schema,
  or app precondition.
- `provides`: layer/service/action provides a dependency or capability.
- `reads`: event reads a redacted domain entity, data subject, resource, or
  schema.
- `writes`: event writes a redacted domain entity, data subject, resource, or
  schema.
- `transforms`: event transforms data from one schema/entity reference to
  another.
- `emits`: event emits an artifact, metric, log, response, report, or app
  semantic artifact.
- `owns`: scope, fiber, layer, or app operation owns a resource or subgraph.
- `finalizes`: finalizer/event closes or releases a resource or scope.

## Projection Boundary

The contract defines this order:

1. Runtime internals and app semantic APIs emit append-only facts.
2. The unified spine normalizes canonical ids and relationship records.
3. Redaction, sampling, truncation, and retention policies are applied.
4. Derived indexes are built for cause chains, fibers, scopes, resources, layers,
   services, app data lineage, artifacts, and findings.
5. Projections serve read-only human views, bounded agent queries, backend export,
   and durable NenDB graph records.

No downstream projection may become the mutation source for the causal store.

## Derived Index Contract

Derived indexes must be rebuildable from source events and policy metadata. The
first planned index families are:

- `cause_index`: event/finding cause chains.
- `parent_index`: event tree and structural lineage.
- `fiber_index`: fork/start/join/interrupt lifecycle lanes.
- `scope_index`: scope/resource/finalizer ownership.
- `layer_service_index`: layer, service requirement, provider, and replacement
  graph.
- `data_lineage_index`: app data read/write/transform relationships.
- `artifact_index`: emitted artifacts, bundles, reports, access decisions, and
  app response artifacts.
- `finding_index`: findings, confidence, policy gates, and recommended next
  queries.

Indexes may be incomplete because of sampling, truncation, or retention. They
must expose limitation metadata rather than implying completeness.

## Consumer Contracts

### Runtime Internals

The next runtime branch should add typed facts for layers, services, scopes,
fibers, resources, finalizers, retries, interruptions, defects, and cause chains
using the canonical ids above.

### App Semantic Trace API

The app API should emit semantic events for function boundaries, service calls,
domain actions, data reads/writes/transforms, policy decisions, artifact
emission, and responses using app semantic refs only.

### Agent Query Interface

The agent interface should return bounded graph slices with:

- schema and schema version
- query name and arguments
- event ids and relationship ids
- redaction, sampling, truncation, and retention state
- confidence or limitation notes
- recommended next queries
- verification commands

### SolidJS `zig-webui` Workbench

The workbench should consume the same spine through read-only projections. It
can render richer graph views, timelines, filters, and remediation chains, but
it must cite the same event and relationship ids an agent query would return.

### NenDB Adapter Projection

NenDB remains the durable graph adapter direction. The adapter should persist
nodes and edges derived from the unified spine after redaction and retention
policy. It must not introduce Cockroach or become the authoritative source event
store in this roadmap stage.

## Fixture Requirements

The implementation report should include a deterministic fixture showing:

- one runtime event mapped from current `id`/`parent_id` into
  `event_id`/`parent_event_id`
- one app semantic event with `artifact_id`, `domain_entity_ref`,
  `data_subject_ref`, and `schema_ref`
- relationships that cover parent/cause/service/resource/data/artifact cases
- projection policies for human, agent, workbench, backend, and NenDB consumers
- a next branch recommendation for deep runtime internals

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

## Success Criteria

- A schema-governed `causal-unified-spine-contract` tool emits text and JSON.
- The tool tests validate canonical ids, relationship taxonomy, projection
  boundaries, derived index families, non-goals, and next branch recommendation.
- Schema governance lists `zigeffect.causal.unified-spine-contract.v1`.
- Production hardening backlog marks the milestone delivered and recommends the
  deep runtime internals branch next.
- Docs explain how future runtime, app, agent, workbench, and NenDB work should
  consume the contract.
- Full local verification passes without staging unrelated existing worktree
  files.
