# ZigEffect Statechart Agentic Runtime Design

Date: 2026-07-10
Status: accepted direction, staged implementation

## Purpose

Make statecharts a star ZigEffect capability for agentic application development.
Agents should be able to author robust control logic as typed, inspectable machines;
the runtime should execute that logic deterministically; and humans should be able
to see the complete definition and the path actually taken in the existing SolidJS
workbench.

This is a ZigEffect-owned runtime. Existing FSM libraries inform implementation
techniques, SCXML informs statechart semantics, and XState is an interoperability
and visualization target. None of those external systems owns ZigEffect execution,
durability, or evidence semantics.

## Product Outcomes

The production offering must provide:

- typed states, events with payloads, value-semantic context, and typed commands;
- deterministic transition selection with ordered guards;
- targetless, self, internal, and external transitions;
- entry, exit, and transition actions with transactional context updates;
- eventless transitions and bounded macrostep stabilization;
- compound states, parallel regions, final states, and shallow/deep history;
- actor-like machine instances with mailboxes, scopes, supervision, and children;
- durable workflow execution using journals, timers, signals, queues, and activities;
- versioned definitions, snapshots, event records, migrations, and replay;
- causal evidence for decisions, guards, commands, actor communication, and failures;
- static analysis for reachability, dead states, ambiguous transitions, unhandled
  events, final-state violations, and eventless cycles;
- definition and execution coverage plus model-based path generation;
- XState v5 configuration and Mermaid export;
- one synchronized workbench graph that can display causal, statechart, and actor
  system views without creating a parallel observability product;
- agent-oriented CLI queries with stable JSON output and source references.

## Architectural Boundary

```text
typed machine definition
        |
        v
pure statechart kernel -----> definition artifact -----> XState / Mermaid
        |
        v
machine actor service ------> inspection stream
        |                            |
        +----> workflow journal -----+----> causal adapter ----> causal graph
        |                                                   |
        +----> Effect command executor                       v
                                                    SolidJS workbench
```

The pure kernel is authoritative for transition semantics. It performs no I/O,
does not access Effect services, and does not write evidence. Adapters consume its
typed decisions.

## Package Ownership

Core semantics live in `packages/zigeffect/src/statechart/` because workflow,
runtime, and causal integration cannot depend upward on `zigeffect-std`.

```text
statechart/
  root.zig          public facade
  definition.zig    typed immutable definitions and validation
  machine.zig       snapshots, transition kernel, macrosteps
  analysis.zig      reachability, coverage, cycles, path generation
  artifact.zig      versioned definition/snapshot/execution JSON
  causal.zig        statechart event to causal event adapter
  actor.zig         scoped mailbox-driven instances
  inspect.zig       bounded inspection records and subscribers
```

Durable integration belongs in `workflow/statechart.zig`. Standard-library I/O,
schema, project, and filesystem conveniences belong in
`packages/zigeffect-std/src/statechart/`. Workbench parsing and presentation stay
under `packages/zigeffect/workbench/src/statechart/`.

## Semantic Model

### Definition

A definition is immutable and versioned. It includes:

- stable machine id and semantic version;
- typed `State`, `Event`, `Context`, and `Command` declarations;
- state nodes with stable ids, descriptions, source references, kind, parent,
  initial child, history policy, entry actions, and exit actions;
- ordered transitions with stable ids, source, optional trigger, targets, guard,
  actions, re-entry policy, description, and source reference;
- bounded runtime options;
- a deterministic definition fingerprint.

Definitions are data-first. Function implementations are registered under stable
symbolic ids so artifacts never attempt to serialize function pointers.

### Snapshot

A snapshot contains only replayable application state:

- definition fingerprint;
- machine instance id;
- active atomic state configuration;
- value-semantic context;
- shallow/deep history values;
- status (`active`, `done`, `failed`, `stopped`);
- monotonic revision and last accepted event sequence.

Services, allocators, clocks, file handles, tokens, and other capabilities never
belong in machine context. They are provided to command execution through Effect.

### Decision

The kernel contract is conceptually:

```text
step(definition, snapshot, event) -> decision
```

A decision contains:

- previous and next snapshots;
- selected transition ids and guard outcomes;
- ordered exit, transition, and entry action records;
- typed commands to execute outside the kernel;
- raised internal events;
- ignored/unhandled-event status;
- bounded microstep evidence;
- deterministic decision fingerprint.

Context and command changes are staged. If a guard/action or bound fails, the
previous snapshot remains authoritative and no command is released.

### Actions And Effects

Guards are pure predicates. Actions may update the staged value-semantic context,
raise internal events, and append typed commands to a bounded buffer. They may not
perform I/O or reach into Effect services.

The command executor maps commands to typed Effects after the transition decision
has been accepted or durably journaled. Completion and failure return to the
machine as typed events. This is the statechart equivalent of invoked actors and
prevents replay from duplicating external work.

### Macrosteps

One external event starts a macrostep:

1. select enabled transitions in deterministic definition order;
2. compute conflict-free transitions for active regions;
3. exit states deepest-first;
4. execute transition actions;
5. enter states outermost-first and resolve initial descendants;
6. process raised internal events;
7. take enabled eventless transitions;
8. repeat until stable or a configured bound fails.

Parallel regions are logical concurrency, not implicit threads. Their transitions
are selected together and committed as one deterministic snapshot revision.

Default bounds prevent hostile or accidental machines from consuming unbounded
time or memory:

- maximum active atomic states;
- maximum transitions per macrostep;
- maximum internal events;
- maximum commands;
- maximum hierarchy depth;
- maximum definition states and transitions;
- maximum artifact and inspection payload bytes.

## Actor Runtime

A definition describes logic; an actor is a running instance. Actors provide:

- stable instance and parent ids;
- bounded mailbox with explicit overflow policy;
- ordered single-consumer event processing;
- subscription to snapshots and inspection records;
- scoped child actor ownership;
- supervision and interruption behavior;
- optional durable journal and causal store attachments.

Not every machine becomes a deployed service. Deployment is an ownership and
scaling decision. Local actors, workflow-bound actors, and clustered entity actors
share the same definition and kernel semantics.

## Workflow Durability

The workflow journal remains the source of truth. Statechart integration adds
versioned records for instance creation, event acceptance, transition decision,
snapshot commit, command scheduling/completion/failure, suspension, and terminal
completion.

The durable order is:

1. read/replay the current snapshot;
2. compute a pure decision;
3. append the accepted decision and resulting snapshot atomically;
4. expose typed commands to the existing activity/timer/signal/queue machinery;
5. mirror the successful append into causal evidence;
6. feed command outcomes back as events.

Causal recording remains weaker than durability: a causal failure after a
successful append cannot invalidate or duplicate the workflow decision.

## Causal Evidence

Add one structural, non-sampleable core kind:

```text
statechart_event_recorded
```

Detailed semantics remain in a versioned statechart execution record and map into
the causal envelope using:

- `artifact_id`: definition fingerprint;
- `domain_entity_ref`: machine instance id;
- `schema_ref`: statechart execution schema;
- `run_id`: actor system or workflow id;
- `scope_id`: machine instance or workflow execution scope;
- `parent_id`: triggering causal event;
- `type_name`: semantic event name;
- `status`: decision/command/actor outcome;
- `redacted_detail`: bounded human explanation.

Required semantic records include definition registration, actor start/stop,
event accepted/ignored, transition selected/rejected/committed, guard failure,
macrostep-bound failure, command scheduled/completed/failed, child spawn/stop,
snapshot restored, and replay divergence.

Agents query statechart behavior through normal CLI/runtime implementation, not a
new family of report-about-report tools:

```text
zigeffect statechart list
zigeffect statechart show <definition-id>
zigeffect statechart instances <definition-id>
zigeffect statechart trace <instance-id>
zigeffect statechart explain <event-id>
zigeffect statechart coverage <definition-id>
zigeffect statechart paths <definition-id>
zigeffect statechart export <definition-id> --format xstate|mermaid|json
```

## Artifacts And Interoperability

Versioned schemas:

```text
zigeffect.statechart.definition.v1
zigeffect.statechart.snapshot.v1
zigeffect.statechart.execution.v1
zigeffect.statechart.coverage.v1
```

The native artifact is authoritative. XState and Mermaid are projections. The
XState exporter emits named guards/actions/actors rather than serialized code and
records unsupported projection features as explicit diagnostics.

Workbench tests may load the XState projection and use XState graph traversal to
compare reachable paths for the supported semantic subset. XState is not linked
into Zig runtime code.

## Workbench Experience

Preserve the existing single evidence surface and persistent inspector. The graph
surface gains modes rather than another top-level tab:

- causal: why execution happened;
- statechart: all possible behavior plus the active/visited path;
- actors: machine ownership and message communication.

Statechart mode shows definitions, active states, visited/unvisited transitions,
transition counts, guard outcomes, failed commands, current replay position,
coverage gaps, source references, descriptions, and version changes. Selection is
shared with the trace and inspector so a definition edge can reveal the causal
events that traversed it.

## Static Analysis And Agent Guardrails

Validation must report stable finding ids and source references for:

- missing or invalid initial states;
- duplicate state/transition ids;
- missing targets and illegal parent graphs;
- unreachable states;
- non-final dead ends;
- outgoing transitions from final states;
- ambiguous unguarded transitions;
- shadowed guarded transitions;
- immediate eventless cycles;
- unbounded internal-event loops;
- commands without registered executors;
- events never handled or states with no accepted events;
- projection loss in XState or Mermaid export;
- definition/snapshot version incompatibility.

Agents receive actionable diagnostics and exact query commands. Validation never
silently rewrites machine behavior.

## Testing Strategy

Development is test-driven and layered:

1. table tests for transition selection and action ordering;
2. property tests for determinism and rollback;
3. generated definition tests for reachability and cycle analysis;
4. macrostep bounds and allocation-failure tests;
5. actor mailbox, supervision, cancellation, and concurrency tests;
6. workflow crash-point and idempotency tests;
7. journal replay and snapshot migration tests;
8. causal mapping/redaction/backend conformance tests;
9. XState path-equivalence tests in the workbench;
10. browser verification for statechart, causal, and actor modes.

Every production feature requires a deterministic fake for external boundaries
and evidence proving the same history yields the same snapshot.

## Delivery Stages

### Stage 1: Native Kernel And Artifact

Deliver typed flat machines, ordered guards, transactional actions, typed commands,
final states, eventless stabilization, validation, analysis, JSON/XState/Mermaid
export, and public API stability tests.

### Stage 2: Actor And Causal Runtime

Deliver mailbox-driven instances, inspection records, child ownership,
supervision, causal mapping, agent queries, and embedded graph evidence.

### Stage 3: Durable Workflow Statecharts

Deliver versioned journal records, snapshot/replay, activities, durable timers,
signals, queues, crash recovery, migrations, and cluster entity ownership.

### Stage 4: Full Statechart Semantics

Deliver compound states, parallel regions, shallow/deep history, internal events,
invoked/spawned actors, and SCXML-derived conflict resolution.

### Stage 5: Agentic Workbench And Model Analysis

Deliver synchronized definition/runtime visualization, coverage, path generation,
definition diffs, replay scrubbing, XState conformance, and agent authoring feedback.

## Initial Acceptance

The first implementation slice is accepted only when:

- the new public facade exposes a typed machine definition and pure transition API;
- invalid definitions fail deterministically;
- guards and actions are ordered and context/commands roll back on failure;
- eventless processing is bounded;
- the same snapshot/event pair produces the same decision fingerprint;
- artifacts export native JSON, XState-compatible JSON, and Mermaid;
- analysis reports unreachable states and eventless cycles;
- statechart decisions map into redacted causal events;
- focused Zig tests, public API review, workbench tests/typecheck/build, tool hygiene,
  and repository checks pass or are reported unpassed.

## Explicit Non-Decisions

- Do not depend on another Zig FSM package in the runtime.
- Do not claim full SCXML conformance before the conformance suite exists.
- Do not make XState the runtime source of truth.
- Do not serialize function pointers, services, or arbitrary context resources.
- Do not create one deployed service per machine by default.
- Do not create new `causal_*` report tools for statechart behavior.
- Do not merge static definition graphs into causal history as if they were the
  same graph; link them through stable artifact and instance ids.
