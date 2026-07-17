# Production Statecharts for Agentic Programs

ZigEffect statecharts are the control-logic layer for long-lived agents and
workflows. The native Zig runtime is authoritative. XState is an executable
interoperability and visualization oracle, not a production runtime dependency.

## Architecture and boundary

Use one independently addressable actor per workflow instance. Give it a stable
instance id, typed context, mailbox, journal correlation, causal trace, and
workbench representation. Do not create a network service per state machine by
default. Promote an actor to a service only when deployment, scaling, security,
fault isolation, ownership, or data-residency requirements demand it. The same
artifact and trace contracts cross either boundary.

The runtime layers are deliberately separate:

1. `Definition` is immutable, typed, validated logic and metadata.
2. `Machine` and `ConfigurationMachine` are deterministic reducers.
3. `Macrostep` and `ConfigurationMacrostep` drain internal and eventless work
   within explicit bounds.
4. `Actor` and `ActorSystem` add ownership, mailboxes, supervision, invocation,
   inspection, and cluster fencing.
5. `DurableStatechart` and `DurableConfigurationStatechart` make the workflow
   journal authoritative for decisions, snapshots, commands, and recovery.
6. Causal artifacts, the CLI, and the SolidJS workbench explain the same run.

The Agent Workflow Studio adds a governed authoring lifecycle around those
runtime layers. A portable `WorkflowPlan v1` is validated and compiled into
typed Zig; it is never dynamically interpreted in production. The resulting
definition is proposed as an immutable version, verified, reviewed, approved,
and only then applied through a separately authorized control boundary.

Prefer `ConfigurationMachine` for application logic. `Machine` is the smaller
flat-state specialization. Both support transactional typed initialization.

## Initialization and completion

If an initial state has entry actions or invocations, start it with
`initialize(..., init_event)` or `Actor.initWithEvent`. Calling flat
`Actor.init` in that case fails with `MissingInitializationEvent`; durable flat
handling also refuses to skip initialization. The explicit event makes payload
access deterministic and keeps emitted commands and internal events inside the
initial transaction.

Hierarchical entry runs shallow-to-deep. Exit runs deep-to-shallow. Within a
state, declared action order is preserved. Invocation starts follow that
state's entry actions; invocation stops follow its exit actions. Parallel
transition conflicts are resolved by active-state document order, with
descendant transitions taking precedence over ancestors.

A completion event is raised only when a compound or parallel boundary becomes
complete. It is enqueued after the microstep that entered the completed
configuration. Nested completion events are queued inner-to-outer in definition
order and consumed FIFO after eventless transitions. A boundary may complete
again after it is exited and re-entered; it emits one new completion event for
that new entry. It does not emit duplicates while continuously complete.

These are documented ZigEffect semantics derived from the relevant SCXML model.
The library does not claim support for every SCXML element or executable-content
feature.

## Determinism and the reducer trust boundary

Context is recursively restricted to owned value data. Pointers, slices,
allocators, functions, untagged unions, and resource handles are rejected.
Actions receive only a staged context copy, the typed event, and bounded command
and internal-event sinks. A failed action rolls back the entire decision.

Native action functions remain trusted code: Zig cannot prove that a function
does not reach mutable global state. Keep actions pure and express external work
as commands. Run `FlatDeterminismAudit` or `ConfigurationDeterminismAudit` in
model tests; it executes identical inputs twice and rejects divergent outputs.
Code review and the audit together define this trust boundary.

## Effects, invocations, and child workflows

Commands are typed descriptions, not effects. Adapters may map them to Effect
services, workflow activities, durable timers, signals, queues, or child
workflows. Command completion and failure can return typed events to the same
machine. Stable command ids and journal receipts prevent a recovered dispatcher
from re-running a receipted command.

When a workflow activity produces the next statechart event, create the
execution adapter with `zstd.Workflow.execution(ctx, allocator, journal)` and
record the decision through its `decision` method. The adapter derives the
runtime recorder, causal journal and latest parent automatically. The resulting
activity-to-decision edge is directly traversable and both records share the
workflow execution and statechart instance scope. Application code never
constructs `CausalJournalStore` or calls `recordDecisionCausal`.

State invocations declare typed start and optional stop reducers. Those reducers
emit commands, so actor creation and remote service calls remain outside the
transaction. Child workflows started with `WorkflowEngine.executeChild` record
parent workflow id, parent execution id, and parent journal sequence; repeating
the same child start returns the existing child execution.

## Durable and clustered execution

The workflow journal is the source of truth. Every accepted initialization or
transition records the definition fingerprint, event identity, resulting flat
or hierarchical snapshot, chosen transition ids, commands, and fence epoch.
Recovery folds the latest compatible snapshots without executing actions.
Checkpoints compact old payloads while retaining event identities needed for
deduplication.

The guarantee is exactly-once decision acceptance plus idempotent command
receipt and recovery. External systems must still honor the supplied command or
activity idempotency key. Do not describe arbitrary external effects as
exactly-once.

Cluster owners validate their lease immediately before journal append and
compaction. The accepted epoch is stored in the record. Stale owners cannot
mutate history. Actor envelopes carry correlation, trace, boundary, and expected
fence ids. Actor-tree checkpoints preserve topology, snapshots, pending
envelopes, supervision, and leases; restore requires explicit rebinding of
process-local executors.

Operational recovery sequence:

1. Acquire a newer shard/entity lease epoch.
2. Restore the actor tree and each durable statechart from its journal.
3. Rebind Effect command executors and transport clients.
4. Recover receipted typed outcome events before dispatching unreceipted work.
5. Resume owned mailbox processing with the new fence epoch.

## Artifacts and compatibility

All public u64 ids, fingerprints, revisions, and counts in v2 statechart JSON are
decimal strings, preserving the full range in JavaScript.

| Artifact | Reader support | Writer | Migration policy |
|---|---|---|---|
| Definition v1 | supported legacy input | no | safe numeric ids only; normalize to strings |
| Definition v2 | supported | yes | current |
| Snapshot/execution/coverage v1 | supported legacy input | no | reject unsafe JS numbers |
| Snapshot/execution/coverage v2 | supported | yes | current |
| Durable statechart record v1 | supported | yes | older versions require an explicit registered migrator; future versions fail closed |
| Actor-tree checkpoint v1 | supported | yes | exact schema/version match; service handles are rebound |
| Catalog v1 | supported | yes | atomic temp/write/backup rotation and backup recovery |
| Workflow plan v1 | supported | yes | deterministic typed-Zig generation; guards fail closed until implemented |
| Proposal/proof/review/approval/application v1 | supported | yes | SHA-256 bound immutable governance chain |

Never silently reinterpret a future schema. Preserve old fixtures in tests and
add a migration before changing any durable shape.

## XState and workbench support

The exporter covers atomic, final, compound, parallel, shallow/deep history,
event and eventless transitions, guards, action symbols, invocations, and
relative nesting used by ZigEffect definitions. The workbench builds an
independent XState v5 machine for supported path fixtures and reports
equivalence or the first divergence. Features with no lossless projection must
produce an explicit projection-loss diagnostic rather than altered behavior.

The SolidJS workbench provides definition and instance selectors, nested state
graphs, actor topology, active configuration, replay scrub, transition counts,
rejected guards, failed commands, coverage, source references, definition diff,
and XState equivalence. Its Statechart Studio surface also exposes the exact
agent-authored states and transitions, proof matrix, mutation score, immutable
proposal-to-application chain, version fingerprint and runtime release contract.
Artifact text remains inert data. The native deterministic SVG renderer is the
declared graph renderer.

## Agent authoring and governance

Agents should author portable plans when logic is being created or assembled,
then compile them into normal Zig modules:

```text
zigeffect statechart patterns --json
zigeffect statechart pattern human_approval --namespace review.approval --json
zigeffect statechart compile workflows/review.json
zigeffect statechart compile workflows/review.json --output src/statecharts/review.zig --apply
zigeffect statechart propose proposal-input.json --output .zigeffect/statecharts/proposals/review-v2.json --apply
zigeffect statechart verify proof-input.json --output .zigeffect/statecharts/proofs/review-v2.json --apply
zigeffect statechart review review-input.json --output .zigeffect/statecharts/reviews/review-v2.json --apply
zigeffect statechart approve approval-input.json --output .zigeffect/statecharts/approvals/review-v2.json --apply
zigeffect statechart studio agent.review --json
zigeffect statechart versions agent.review --json
zigeffect statechart fleet --json
zigeffect statechart controls --json
```

Compilation and governance artifact commands without `--apply` write no files.
Generated guards return `false`
until implemented, generated commands remain typed values, and all identifiers
are deterministically escaped. The reusable catalog includes human approval,
retry/escalation, tool execution, parallel research, consensus review, saga
compensation, timeout fallback, budget enforcement, child delegation, circuit
breaker, long-running job and incident remediation patterns. Expansions use
namespaced stable ids and explicit temporal invariants; they are source material,
not opaque runtime plugins.

Approval is not mutation authority. A control request must additionally pass an
explicit policy and match the live definition fingerprint and lease/fence epoch.
The shared control plane is default-deny, idempotent and dry-run capable. Native
adapters connect it to `ActorSystem` typed signals/stops and durable workflow
suspend/resume/cancel operations. Unsupported operations fail closed. The fleet
registry provides bounded instance, health and pending-work summaries without
granting control privileges.

Snapshot migrations are registered by exact source and target fingerprints.
Dry-run validates that instance identity and revision do not change, and a
declared reverse migration must reproduce the original snapshot byte-for-byte
before the migration is described as reversible.

## Bounds, security, and performance

Definitions bound microsteps, commands, internal events, active regions,
history, mailbox size, inspection records, artifact bytes, and graph nodes and
edges. Exhaustion returns a typed error; it never silently truncates execution.
Artifacts redact context, event payloads, and command payloads by default.
Metadata is JSON escaped, malformed references fail closed, and catalog paths
remain manifest-owned.

The regression budgets exercised by tests are:

- 10,000 flat transitions within 2 seconds in Debug tests;
- 10,000 actor mailbox transitions within 4 seconds;
- 2,000 durable commits plus replay within 4 seconds;
- workbench render-model construction capped at 256 nodes and 1,024 edges.

These are regression ceilings, not universal capacity promises. Benchmark the
target hardware and storage backend before setting production SLOs.

## Production checklist

- Validate the definition and run static analysis in CI.
- Use typed initialization whenever initial entry behavior exists.
- Keep reducers pure; run the determinism audit and model/path tests.
- Use hierarchical durable statecharts for long-lived agent workflows.
- Require idempotency at every external command adapter.
- Configure mailbox, macrostep, artifact, and replay bounds deliberately.
- Persist causal correlation and expose the catalog to the CLI/workbench.
- Require complete proof, exact human review and an unexpired approval before
  applying a new definition; keep application authority separate.
- Dry-run snapshot migrations and control requests against the current
  fingerprint and fence epoch.
- Exercise checkpoint, migration, lease-loss, command-receipt, and shard-recovery
  paths for the chosen storage and transport implementations.
- Run Debug, ReleaseSafe, public API, hygiene, std, CLI, workbench, scaffold, and
  repository release gates before publishing.
