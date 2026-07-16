# Proof-carrying development plane

ZigEffect treats software development as an observable, effectful program. A
test process, application runtime, CLI, coding agent, and workspace coordinator
do not maintain separate versions of the truth. They exchange bounded,
versioned artifacts whose identities can be checked against the current source,
manifest, command, runtime graph, and native test execution.

The canonical first query is:

```sh
zigeffect agent context --task <requirement-or-task-id> \
  --budget 65536 --changed src/orders.zig --json
```

The result is `zigeffect.agent.development-context.v1`. It is a deterministic context
bundle, not a prose summary. It includes the current content-addressed source
identity, manifest digest, selected requirement and check state, affected
scenarios, exact native test filters, matching proof references, application
topology, graph cursor and health, explicit authority, and bounded follow-up
queries. When a byte budget excludes optional data, the bundle reports that
omission instead of silently truncating JSON.

## Evidence is the source of status

`zigeffect.project.json` declares intent. It does not prove that intent has
been satisfied. The development reconciler derives check and requirement state
only from the stable native process receipt for each scenario:

```text
.zigeffect/tests/process-receipts/<scenario-id>.json
```

Ordinary package-native suites publish their latest semantic payload under
`.zigeffect/tests/raw-receipts/`. They cannot replace stable process evidence.
The CLI removes its one-shot control document after the selected native process
returns, then enriches and publishes the authoritative receipt. A later full
unit suite therefore cannot reopen a satisfied requirement by overwriting proof
with an uncontrolled `working-tree` receipt.

A receipt counts only when all of these identities and outcomes agree:

- project, scenario, requirement, acceptance check, component, and command;
- current content-addressed source revision and canonical manifest digest;
- command digest, tool version, target, optimization mode, and adapter profile;
- native execution, complete capture, no truncation, and a passing verdict.

Missing, stale, skipped, canceled, unsupported, incomplete, or mismatched proof
leaves a check pending. A matching failure makes it failed. A requirement is
satisfied only when every declared acceptance check is derived passed. The
reconciler never edits the manifest to manufacture a green status.

The source identity has this shape:

```text
git:<head>:sha256:<project-subtree-content>
```

It includes tracked changes and bounded untracked project files while excluding
generated `.zigeffect` evidence. Publishing a receipt therefore does not make
that same receipt stale.

## Focused native execution and proof handoff

Each scenario may declare `native_test_filter`. The CLI appends the fixed Zig
build option itself; a manifest cannot inject arbitrary arguments. Testing v2
then runs the selected native test through the server runner and requires a
complete suite receipt with equal discovered and executed counts, zero pending
tests, zero leaks, and zero logged errors.

During a run, bounded progress is atomically appended to:

```text
.zigeffect/tests/progress.jsonl
```

The events are `run_started`, `scenario_started`, `scenario_completed`, and
`run_completed`. On success the CLI publishes content-addressed proof handoffs
at:

```text
.zigeffect/handoffs/tests/latest.json
.zigeffect/handoffs/tests/<scenario-id>.json
```

A handoff binds the manifest, run, process receipt, source revision, native
assertions, graph session, replay command, and authority. It is safe to pass to
another agent; it is not a replacement for validating the referenced receipt.

## One causal identity across runtimes and telemetry

`CausalContextV2` is carried by managed-runtime handles and fibers. It contains
bounded identities for the runtime, graph session, workspace, project,
component, requirement, check, scenario, agent, attempt, durable task, work
packet, change set, source revision, and W3C trace/span context. Events may also
carry bounded typed links: `parent`, `cause`, `proof`, `lease`, `change`, and
`federated`.

The same context object is projected into:

- the in-memory causal recorder;
- the embedded NenDB event and property graph;
- JSONL diagnostic artifacts;
- OTLP spans, logs, metrics, and links.

NenDB remains the semantic source of truth. OTLP exporter failure cannot erase
the local causal record. Incoming gRPC and HTTP `traceparent` values are parsed
as exact W3C 128-bit trace identities rather than being collapsed into a local
hash.

Every canonical `zstd.ManagedRuntime` owns the bounded recorder and embedded
graph unless a caller injects a test store. Libraries export effects, service
tags, and layers; they do not create hidden runtimes or private causal stores.

## Executable causal paths and counterfactuals

Agents can query a bounded causal path directly:

```sh
zigeffect graph path <from-durable-event> <to-durable-event> \
  --limit 128 --json
```

`zstd.Testing.AssertionRecorder.eventPath` and `counterfactual` use the same
path contract. A counterfactual proves that an expected causal path exists from
a before event, through an action, to an after event. Its assertion records all
path IDs; after runtime-to-durable mapping those IDs can be queried without
manually scanning an event array.

Independent applications keep independent single-writer WALs. A
`Development.FederatedGraph` mounts read-only graph snapshots and resolves
typed foreign references without copying events into a shared database.
Integration joins record explicit multi-parent proof links.

## Durable coordination contracts

The public `zstd.Development` module also supplies the foundation for an
effectful development swarm:

- a journal-backed task statechart with optimistic sequence/revision checks,
  idempotent transitions, and replay;
- expiring leases with fencing tokens;
- bounded work packets with allowed and excluded paths, dependencies, and
  verification commands;
- proof bundles bound to packet, lease, source, receipt, command, diff, changed
  paths, causal events, and invariants;
- integration checks that reject stale leases, conflicting paths, missing
  dependencies, undeclared changes, or mismatched proof;
- bounded, redacted structural repair memory with revision invalidation.

These contracts are exposed as replaceable services and layers. They do not
grant filesystem, process, cloud, or deployment authority. MCP Tasks, A2A, and
agent harnesses are adapters over this internal truth, not alternative task
stores.

## Ziac

Ziac exposes a read-only `ziac_context` MCP tool backed by the same context
compiler. It is intentionally the first diagnostic call: one response maps the
Ziac project contract, effect/layer topology, exact native acceptance evidence,
causal graph cursor, and next bounded queries. Plan, verification, and apply
retain their separate capability gates.

Ziac's development-context acceptance scenario is itself a focused native
Testing v2 scenario. This makes the endpoint dogfood the source revision,
manifest digest, receipt, graph, and handoff contracts it reports.

## Required agent loop

1. Query `agent context` and capture the graph cursor.
2. Select or create the manifest requirement, check, component, and scenario.
3. State the expected causal counterfactual and unchanged slice.
4. Add the failing deterministic native test.
5. Run the affected scenario using its manifest-owned filter.
6. Read the stable process receipt and proof handoff before terminal output.
7. Query the assertion's causal path or the graph delta.
8. Integrate only when source, lease, work packet, and proof still agree.
9. Run the project gates and hand off the bounded evidence bundle.

For the executable API, use `zstd.Development`. For testing details, read
[Agent-first testing](agent-first-testing.md). For runtime architecture, read
[Agent-observable causal runtime](agent-observable-runtime.md).
