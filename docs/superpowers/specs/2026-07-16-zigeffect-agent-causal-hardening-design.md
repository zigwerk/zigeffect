# ZigEffect Agent-Causal Development Hardening

## Problem

ZigEffect now has the right major nouns—typed effects, service tags, layers,
one managed runtime, runtime aspects, a bounded causal store, embedded NenDB,
Testing v2, and agent-oriented CLI queries—but the generated developer journey
does not yet prove that those nouns form one closed system.

The most important defect is evidentiary. A generated application currently
publishes its requirement receipt from a synthetic `TestContext` test, while a
separate ordinary test runs the real application against a temporary graph.
Consequently the requirement receipt can omit the runtime events for the
behavior it claims to verify, and the manifest-owned graph queried by
`zigeffect graph since` does not contain the test run. A successful package
test is therefore weaker than the promised agent workflow.

The application map has a related gap. It describes the live service and layer
topology, but not the manifest-owned requirements, acceptance checks, scenarios,
or exact development commands. An agent can inspect how the runtime is wired or
what the project intends, but not both from the same discovery document.

Finally, a fresh scaffold has no graph artifact, so the required pre-change
`graph status` command fails instead of producing an empty cursor. The workflow
cannot be followed literally on the first change.

## Official Effect reference model

The checked-in Effect core and examples establish the conceptual baseline:

- a service module owns an abstract tag/API and may colocate its canonical live
  and test layers;
- operations are effect descriptions whose required services remain visible;
- dependencies are assembled with `Layer.provide`, `provideMerge`, and merges at
  a composition root;
- the same layer value is shared and memoized, while calling a layer factory
  twice intentionally creates two instances;
- libraries export effects, tags, schemas, and layers; an application edge
  launches one root layer or derives one `ManagedRuntime` from it;
- tests replace implementations by providing layers at the composition
  boundary; and
- logging, metrics, tracing, supervision, scopes, and runtime configuration are
  properties of effect execution, not unrelated utility calls.

The official monorepo example reinforces package boundaries: the domain package
owns protocol/schema, the server package owns repositories and API layers, and
the executable file is a small root composition. ZigEffect should preserve that
shape without copying TypeScript class/accessor machinery that exists only for
JavaScript ergonomics.

## Design

### One causal store for the test and the application runtime

The canonical `zstd.ManagedRuntime` will accept an optional caller-supplied
`CausalStore`. When omitted, behavior remains runtime-owned. When supplied, the
runtime will:

1. leave store allocation and destruction to the caller;
2. temporarily attach its embedded NenDB backend;
3. restore the caller's previous backend before destroying runtime-owned graph
   state; and
4. retain the same bounded, redacted semantic and structural event stream.

`CausalStore` therefore needs a safe backend swap primitive. This is preferable
to exposing backend fields or silently leaving a dangling backend pointer in a
caller-owned store.

`TestContext` will expose a narrow `causalStore()` pointer and construct its
store with the canonical event and string bounds. A deterministic acceptance
test can then build the real application runtime with that store. Assertions,
the process receipt, the runtime inspection, and the durable NenDB graph all
refer to the same execution.

Recorder IDs restart for each runtime session, while graph IDs remain durable
across sessions. Before publishing, the test maps assertion references through
the live runtime and declares both `causal_event_id_space: graph_durable` and
the graph session. Runtime-local receipts remain explicit and must never be
treated as graph cursors. Historical failures on a caller-owned backend are
excluded from the new runtime's health baseline; failures introduced during
the runtime remain fatal at checked shutdown.

### Generated application as an Effect application

Generated executable code will expose a stable composition surface:

- `rootLayer()` constructs the root layer once;
- `program(...)` returns the application effect description;
- `runWithOptions(...)` is the process-edge interpreter hook used by tests and
  embedders; and
- `run(...)` remains the minimal executable convenience using default runtime
  options.

The requirement-linked acceptance test will create one `TestContext`, construct
one canonical managed runtime over `std.Io.Dir.cwd()`, run `program`, inspect the
topology and causal stream, assert semantic events with causal IDs, shut down the
runtime, and only then publish the receipt. The old synthetic receipt test and
detached temporary-graph test will be replaced by this single test.

This follows Effect's application shape: libraries describe; the composition
root provides; a runtime interprets; tests provide alternative runtime services
without creating hidden runtimes inside libraries.

### A discovery document that joins runtime truth and executable intent

At startup the canonical runtime will read and validate
`zigeffect.project.json` when present. Missing manifests remain valid for
framework tests and embedded use. Invalid manifests at an application root are
startup failures.

The bounded agent map will move to schema v2 and include:

- the existing live application topology and recent causal state;
- durable graph summary and causal backend health;
- the validated project manifest, including requirements, components,
  acceptance checks, commands, and scenarios; and
- a small versioned workflow object containing exact read-only/query and test
  command templates.

This makes one guarded endpoint sufficient to discover both what is running and
how the repository declares it should be verified. It does not expose raw
terminal output, secrets, unrestricted file access, or mutation authority.

### Empty graph is a valid baseline

`zigeffect graph status --json` will return a versioned zero-record summary when
the configured graph WAL does not exist. It remains read-only and will not
create the graph. Event and child queries for absent evidence continue to fail.
`graph since 0` may return an empty, complete delta so agents can use cursor zero
uniformly on a brand-new project.

### End-to-end conformance

The generated-project integration lane will exercise the real agent loop for a
canonical generated application:

1. compatibility, validation, agent status/next, and scenario discovery;
2. empty graph baseline;
3. affected-test selection;
4. requirement-linked `test run` through the native receipt protocol;
5. receipt validation with non-zero causal evidence and causal assertion IDs;
6. durable `graph since` inspection of the same semantic execution;
7. coverage/gap queries; and
8. an evidence-backed handoff.

Generated systems run their real child applications with the same test-owned
recorder, while each child continues to own its independent graph. Until the
receipt schema carries component-qualified graph references, system-level
assertion IDs remain explicitly `runtime_local`; agents use the declared
component graph deltas rather than guessing which graph an unqualified number
belongs to.

This conformance test is the proof that an agent can actually use the workflow,
not merely that CLI subcommands exist independently.

### Package and transport hardening boundary

The canonical gRPC route/client/server composition remains the reference
transport shape: generated bindings export effects and route layers, transport
layers acquire scoped resources, and request handlers run through a reusable
runtime handle. This pass will add regression assertions that gRPC continues to
share the runtime recorder and will not introduce a second runtime or a manual
causal backend.

Legacy adapter packages and the current production scaffold bridge are not
allowed to masquerade as the canonical architecture. The architecture policy
will report them as explicit migration debt. If the production profile cannot
be composed entirely through kernel services and layers during this pass, the
documentation and conformance output must state that limitation rather than
claiming full Effect-native composition.

## Ownership and failure semantics

- Runtime-owned stores and graphs are destroyed by the runtime.
- Supplied stores are never destroyed by the runtime.
- A supplied store's previous backend is restored before the runtime graph is
  destroyed.
- Invalid application manifests fail managed-runtime startup; missing manifests
  produce `manifest: null` for framework/embedded roots.
- Durable backend failures make causal health degraded and checked shutdown
  fail.
- Missing, empty, dropped, truncated, mismatched, or unsupported required test
  evidence is not a pass.

## Acceptance criteria

- A test proves supplied store ownership and backend restoration.
- A test proves one canonical runtime writes the same events to `TestContext`
  and embedded NenDB.
- A fresh generated app returns an empty graph baseline without creating files.
- A generated acceptance receipt contains real runtime events and at least one
  assertion with causal event IDs from the application behavior.
- `graph since` sees the semantic events emitted by that requirement test.
- Agent map v2 contains runtime topology, graph health, validated manifest
  intent, scenarios, and workflow commands in one bounded JSON response.
- Layer memoization behavior remains instance-based and is covered explicitly.
- All changed package tests use Testing v2 and their structured receipts are
  complete with equal discovered/executed counts and no leaks or logged errors.
