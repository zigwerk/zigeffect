# ZigEffect Proof-Carrying Development Plane

Date: 2026-07-16
Status: implemented and verified

## Intent

Make development itself a ZigEffect application. A human or agent should be
able to enter any generated ZigEffect project, ask one bounded question, and
receive the smallest complete context needed to plan, change, test, inspect,
and hand work to another agent. The answer must be derived from executable
manifests, complete Testing v2 receipts, and the causal graph rather than from
terminal prose or manually maintained status fields.

The application runtime remains the source of semantic execution facts. A
workspace development runtime coordinates application graphs, development
tasks, leases, proof bundles, and repair memory without making every process a
writer to one WAL.

## Reference model

The design follows the useful parts of Effect's package architecture:

- services expose small typed APIs;
- live, test, and fake implementations are layers;
- layers declare dependencies and are memoized per runtime;
- a managed runtime is built once and interprets many programs;
- platform packages adapt external boundaries and do not own domain logic.

ZigEffect extends that model where Zig and agentic development permit a better
result: every managed runtime records causal facts into embedded NenDB,
requirements are reconciled from proof, and the development coordinator is
itself a typed, observable, durable program.

## Non-goals

- Do not emulate TypeScript class decorators, structural typing, or JS-specific
  dependency-injection machinery.
- Do not merge every application's NenDB WAL into one file.
- Do not treat OTLP as the canonical causal store.
- Do not persist raw prompts, unredacted terminal output, credentials, or chat
  transcripts as repair memory.
- Do not infer completion from the presence of a file or from a manifest's
  manually written status alone.

## Architecture

### 1. Canonical causal context v2

Every runtime event carries a bounded, allocation-free causal context:

- graph session and runtime instance identities;
- development task, work packet, and change-set identities;
- W3C-compatible trace and span identity slots;
- a bounded set of typed links such as `parent`, `cause`, `proof`, `lease`,
  `change`, and `federated`.

Legacy `parent_id`, `cause_event_id`, and trace fields remain projections used
by current query/storage code while v2 becomes the canonical correlation model.
Runtime handles can derive a child handle with a task context; every event
recorded through that handle inherits the context automatically.

### 2. Evidence reconciliation

Requirement and check state is derived from receipts using these rules:

1. The receipt must parse and validate against its versioned contract.
2. The receipt project, scenario, requirement, acceptance check, component, and
   command must match the manifest.
3. The receipt source revision must match the current source identity.
4. A required receipt must be native, complete, non-truncated, and passed.
5. Every required scenario for a check must have a matching passing receipt.
6. A failed matching receipt makes the check failed; missing, stale,
   unsupported, skipped, canceled, or incomplete proof leaves it pending.
7. A requirement is satisfied only when all its acceptance checks are derived
   passed. A manifest `blocked` state remains blocked until explicitly changed.

The reconciler returns reasons and evidence references. It never mutates the
manifest to make status appear green.

### 3. Development context compiler

`zigeffect agent context --task <id> --budget <bytes> --changed <path> --json`
is the canonical development entry point. It returns one schema-versioned
bundle containing:

- project and source identity;
- the selected task/requirement and derived check state;
- matching evidence and exact replay/verification commands;
- affected scenarios for changed paths;
- graph summary, cursor, health, and supported follow-up queries;
- durable task/lease/proof coordination state;
- explicit omissions when the byte budget excludes optional sections.

The compiler applies deterministic priority and byte budgets. It never emits
partial JSON, silently truncates strings, or claims omitted evidence is absent.

### 4. Durable proof-carrying tasks

Development work is modeled as a state machine:

`proposed -> scoped -> claimed -> running -> reviewing -> integrating -> verifying -> completed`

`running` may move to `input_required`, `authority_required`, `failed`, or
`canceled`; resumable states return to `running`. Invalid transitions fail.

A `WorkPacket` contains bounded intent: task, requirement/check, component,
source baseline, changed paths, allowed capabilities, graph cursor, acceptance
commands, and dependency task IDs. A `ProofBundle` contains the resulting
change-set identity, matching receipts, causal evidence IDs, graph session,
source revision, limitations, and terminal verdict. Completion requires a
valid proof bundle whose identities match the packet.

Leases are semantic and scoped to task/change/resource keys. A lease has one
owner, an expiry, and a fencing token; stale owners cannot integrate.

### 5. Graph proofs and federation

Graph path queries and Testing v2 graph-path assertions replace manual event
inspection. A passed assertion records the full bounded causal path and, after
runtime-to-durable mapping, gives agents directly queryable graph IDs.

Each application keeps its own embedded graph and single writer. The workspace
development runtime stores graph addresses and federated links of the form
`{project, component, graph_session, durable_event}`. A logical query can walk
coordinator edges and delegate to application snapshots; it does not copy
foreign WAL records.

### 6. Observability projection

NenDB events are the semantic source of truth. OTLP logs and spans are derived
from the same event/context object, including task, work packet, change set,
graph session, requirement, and proof correlation attributes. OTLP exporter
failure is observable but cannot erase the local causal record.

### 7. Repair memory

Resolved failures may be summarized into bounded, redacted repair episodes:

- structural failure fingerprint;
- relevant service/layer/statechart/graph motif;
- accepted change-set and proof IDs;
- before/after verdicts;
- applicability constraints and invalidation revision.

Retrieval is by structural fingerprint and context, not natural-language chat
similarity alone. An episode is advice, never authority or proof.

### 8. Ziac and boundary adapters

Ziac composes the same development services and exposes a read-only
`ziac_context` MCP tool backed by the canonical compiler. MCP Tasks and A2A can
adapt the internal task state machine at process boundaries, but neither owns
task truth. Process or infrastructure mutation still requires explicit
capability authority.

## Ownership and failure model

- One managed runtime owns one writable application graph unless injected.
- Injected stores remain caller-owned.
- One workspace coordinator owns the writable development graph.
- Readers use immutable snapshots and cursors.
- Context, receipts, packets, proofs, leases, and episodes are bounded and
  validate secrets before persistence or serialization.
- A graph or receipt parse failure is reported as degraded/incomplete evidence;
  it is never interpreted as success.
- Runtime shutdown flushes the graph and reports write/export failures.

## Developer experience

Generated projects start with a root layer, managed runtime, project manifest,
Testing v2 scenario, and causal graph enabled. Application code imports public
facades (`zigeffect_std`, generated gRPC bindings, and package roots), defines
service signatures first, wires implementations in layers, and interprets at a
small number of runtime boundaries.

The normal agent loop becomes:

1. Query one bounded context bundle.
2. Claim a proof-carrying task and scoped lease.
3. Add a deterministic failing scenario/assertion.
4. Run only affected evidence while recording the task context.
5. Query the causal path or graph delta.
6. Produce a proof bundle.
7. Integrate only if leases and proofs still match the baseline.
8. Run project gates and publish a redacted repair episode when useful.

## Acceptance criteria

- Passing matching receipts close the correct check and requirement without
  editing manifest status; stale or incomplete receipts do not.
- A context bundle is valid JSON, deterministic, budget bounded, and explicit
  about omissions.
- Invalid task transitions, conflicting leases, and mismatched proof bundles
  are rejected.
- Runtime events inherit v2 development context and export the same correlation
  values to NenDB and OTLP.
- Graph path assertions return durable evidence IDs after receipt mapping.
- Ziac exposes one read-only context endpoint without widening capability
  authority.
- Scaffolded projects document and exercise the same workflow.
- Testing v2 receipts are complete: discovered equals executed, no pending
  tests, leaks, logged errors, or unreported truncation.
