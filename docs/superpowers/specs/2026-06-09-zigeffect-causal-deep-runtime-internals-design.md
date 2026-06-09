# zigeffect Causal Deep Runtime Internals Design

Date: 2026-06-09
Branch: `codex/zigeffect-causal-deep-runtime-internals`
Status: Approved for implementation

## Goal

Make zigeffect runtime execution more agent-readable by enriching existing
causal events with stable runtime identities and direct relationship hints.

This branch is the first implementation branch after the unified causal spine
contract. It should keep the existing `zigeffect.causal.v1` artifact compatible
while adding deeper facts for layers, services, scopes, resources, finalizers,
fibers, retries, defects, interruptions, and cause chains.

## Context

The current runtime already emits a useful causal skeleton:

- runs and exits in `runtime/runner.zig`;
- layer/service validation and startup in `layer/graph.zig`;
- scope open/close and resource lifecycle in `core/scope.zig`;
- fiber fork/start/join/interrupt events in `runtime/fiber.zig`;
- retry/repeat decisions in `effect/effect.zig`;
- JSON, JSONL, DOT, OTEL, graph-history, async-stream, and NenDB projections.

The unified spine contract names canonical runtime identifiers that current
events only partially carry. Existing fields cover `run_id`, `id`, `parent_id`,
`fiber_id`, and `scope_id`. Missing direct fields are `layer_id`,
`service_key`, `resource_id`, and a typed relationship pointer for non-parent
cause/evidence links.

## Design Principles

- Preserve append-only source events as the source of truth.
- Keep this an additive v1-compatible event extension; do not bump the causal
  JSON schema or event taxonomy for optional fields.
- IDs must be runtime-issued, not inferred from labels or type names.
- Every projection that serializes or clones `CausalEvent` must preserve the new
  fields.
- Agent-facing facts should be explicit enough to avoid fuzzy matching between
  event labels.
- Redaction and string bounding must apply to new string fields.
- NenDB remains a post-policy projection adapter, not the source event store.
- No Cockroach adapter work belongs in this milestone.
- The future workbench direction remains SolidJS inside `webui-dev/zig-webui`.

## Event Shape Extension

Add optional fields to `CausalEvent`:

- `layer_id: ?u64 = null`
- `service_key: []const u8 = ""`
- `resource_id: ?u64 = null`
- `cause_event_id: ?u64 = null`
- `schedule_id: ?u64 = null`

`cause_event_id` is a typed relationship hint for evidence that is not the
structural parent. `parent_id` remains the tree/structural parent.

`schedule_id` is included in the source shape so projections can preserve it,
but this branch does not need to invent schedule identity if the current retry
runtime does not have durable schedule instances. It can remain null until a
later schedule internals pass.

## Runtime Emission Rules

### Layers

Each layer graph node receives a deterministic `layer_id` during graph startup.
Layer startup and completion events must include it.

Service events emitted while validating a layer should include:

- `layer_id` for the layer that requires, provides, or replaces the service;
- `service_key` equal to the stable service key currently stored in
  `type_name`;
- existing `type_name` for compatibility with current tools and tests.

Startup failure `exit_recorded` events should inherit the layer id from the
failed layer startup event.

### Scopes And Resources

Each registered resource finalizer should receive one `resource_id`.

`resource_acquired` and the matching `resource_finalized` event must share that
resource id. Finalization should use the acquisition event as the direct parent
when available so cause queries can show the lifecycle pair without matching
only on type name.

Finalizer failure evidence must preserve:

- `resource_id`;
- `scope_id`;
- `status = "failure"`;
- redacted failure detail;
- a relationship back to the acquisition event through `parent_id` and, when
  useful, `cause_event_id`.

Resource leak detection should prefer `resource_id` when present and fall back
to the current `scope_id + type_name` matching for compatibility.

### Fibers

Fiber lifecycle evidence should remain:

- `fiber_forked`;
- `fiber_started`;
- `fiber_interrupted`;
- `fiber_joined`.

`fiber_joined` should be idempotent for repeated joins. The first join records
the exit status and type name; subsequent joins return the same exit without
adding duplicate causal evidence.

Interruption evidence should keep the fork event as the structural parent and
may also set `cause_event_id` to the fork event so agents can explain which
fiber was interrupted.

### Schedules

Retry and repeat events should keep their current agent-readable detail:

- attempt;
- delay;
- decision.

This branch should preserve the new `schedule_id` field through clone/export
paths, but it should not manufacture unstable ids from pointers or labels.

### Exits, Defects, And Causes

Existing exit events should remain compatible. When an event has both a
structural parent and a distinct causal evidence event, use `cause_event_id` for
the evidence edge and leave `parent_id` as the structural edge.

## Projection Requirements

The new fields must be preserved in:

- in-memory store snapshots and lineage;
- backend forwarding;
- JSON artifact export;
- JSONL event rows;
- DOT tooltips and cause edges;
- OTEL attributes;
- graph-history backend snapshots;
- async-stream backend snapshots;
- NenDB node properties.

NenDB edge projection can continue to emit the existing parent edge in this
branch. A later relationship-index branch can split typed `caused_by`,
`owns`, `finalizes`, `requires`, and `provides` edges.

## Tests

Add focused tests proving:

- `CausalEvent` clone/export surfaces preserve `layer_id`, `service_key`,
  `resource_id`, `cause_event_id`, and `schedule_id`;
- redaction and string bounds apply to `service_key`;
- JSON and JSONL include the new fields without changing schema version;
- OTEL and NenDB projections include the new fields;
- layer graph service and startup events carry `layer_id` and `service_key`;
- resource acquisition and finalization share a `resource_id`;
- finalizer failures retain resource id and acquisition linkage;
- repeated fiber joins do not duplicate `fiber_joined`.

## Non-Goals

- Event taxonomy version bump.
- Renaming `id` to `event_id` or `parent_id` to `parent_event_id` in the v1 JSON
  artifact.
- App semantic trace API.
- Relationship index/query API.
- Workbench UI changes.
- Direct upstream NenDB dependency changes.
- Cockroach adapter work.
- React workbench support.
- Production mutation authority.

## Success Criteria

- The runtime emits stable layer, service, resource, finalizer, and fiber facts.
- Existing tools remain compatible with the v1 artifact.
- All clone/export/backend paths preserve the additive fields.
- Tests catch missing preservation in the store and major projections.
- The branch leaves a clear next step toward a relationship index/query branch.
