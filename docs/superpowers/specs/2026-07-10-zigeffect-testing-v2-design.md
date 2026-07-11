# ZigEffect Testing v2 Design

Date: 2026-07-10
Status: accepted for implementation
Extends: `2026-07-10-zigeffect-agent-first-testing-platform-design.md`

## Goal

Make ZigEffect the testing substrate an autonomous coding agent can use to build
high-performance applications without guessing what passed, what remains
untested, or how to reproduce a failure.

Testing v2 closes the gap between the rich evidence produced inside
`zstd.Testing.TestContext` and the command-level receipt currently synthesized by
the CLI. It then adds semantic coverage, model and schedule exploration,
structural shrinking, cross-executor comparison, deterministic distributed-system
faults, requirement-aware mutation analysis, performance contracts, and a
side-effect firewall.

## Success criteria

A required scenario can pass only when:

1. the manifest-owned command exits successfully;
2. the test process publishes a valid receipt for the selected scenario;
3. the receipt matches the selected requirement, acceptance check, component,
   seed, fault, executor, and source revision;
4. assertion, causal, memory, coverage, mutation, performance, differential, and
   sandbox summaries contain no required failure;
5. no required evidence was dropped, truncated, sampled, stale, unsupported, or
   silently skipped.

An agent can query the same evidence through the public Zig API, CLI JSON,
Workbench, generated project skill, and handoff receipt.

## Non-goals

- Intercept arbitrary direct libc, assembly, or operating-system calls made
  outside ZigEffect adapters.
- Claim exhaustive proof beyond recorded bounds, platforms, executors, inputs,
  schedules, mutations, or fault cases.
- Automatically accept snapshots, performance baselines, or surviving mutants.
- Add one-off report tools under `packages/zigeffect/tools`.
- Replace Zig's compiler, test runner, allocator checks, or platform sanitizers.
- Execute caller-supplied shell fragments.

## Architecture

### Public standard-library modules

`packages/zigeffect-std/src/testing/` gains:

- `protocol.zig` — control-file and process-receipt publication protocol;
- `coverage.zig` — semantic targets, hits, gaps, and receipt analysis;
- `models.zig` — bounded generic and typed-statechart model exploration;
- `schedules.zig` — public integration with the core schedule explorer;
- `differential.zig` — semantic comparison across executors/adapters;
- `virtual_world.zig` — deterministic network, queue, store, clock, crash faults;
- `mutation.zig` — bounded runtime mutation plans and surviving-mutant evidence;
- `budgets.zig` — allocation, memory, event, step, size, and duration contracts;
- `sandbox.zig` — default-deny capability recording for ZigEffect adapters.

Existing `contract.zig`, `context.zig`, `assertions.zig`, `faults.zig`,
`generators.zig`, and `snapshots.zig` remain the primary contracts rather than
being replaced.

### Engine reuse

The stdlib composes existing engine primitives:

- `fx.exploreSchedules` and `fx.replaySchedule`;
- deterministic, zio, and thread-pool executors;
- typed statechart definitions, machines, analysis, and coverage;
- `CausalStore`, application facts, workflows, and statechart artifacts;
- tracked allocation and deterministic test services.

New engine code is allowed only when the public testing layer cannot express the
runtime behavior through an existing primitive.

### CLI and Workbench

The existing `zigeffect` executable gains orchestration and queries. No new core
tool executable is added. Workbench extends the existing Tests view and receipt
parser.

## Process receipt protocol

### Paths

- control: `.zigeffect/tests/control.json`
- process inbox: `.zigeffect/tests/process-receipts/<scenario>.json`
- validated receipt: `.zigeffect/tests/receipts/<scenario>.json`
- aggregate: `.zigeffect/tests/latest.json`
- history: `.zigeffect/tests/history/<run-id>.json`
- raw terminal artifacts remain policy-controlled.

### Control schema

`zigeffect.test-control.v1` contains:

- scenario, requirement, acceptance check, component;
- seed, fault kind/index, schedule choices, executor;
- source revision and command digest;
- required evidence flags and exploration bounds.

The CLI atomically writes control before executing the manifest-owned command.
`TestContext.initFromProject` reads the control if it matches its scenario and
uses the selected seed/fault/executor. A non-matching scenario keeps its declared
defaults so one Zig test command can contain several scenarios.

### Publication

`TestContext.publish` finishes the context, validates and redacts the receipt,
then atomically writes the scenario receipt. Test code never chooses an
unrestricted output path.

The CLI removes the selected scenario's stale inbox receipt before execution,
runs the manifest command, and validates the newly published receipt. Missing,
stale, duplicate, mismatched, corrupt, or secret-bearing receipts become an
`incomplete` or `failed` command receipt. A successful process exit alone cannot
pass a required scenario.

### Execution identity

Each validated receipt records:

- Git commit plus dirty-worktree marker when Git is available;
- stable manifest-command digest;
- Zig version, target, optimization mode, executor, and tool version;
- real start/end/duration;
- selected seed/fault/schedule bounds;
- explicit limitations when identity cannot be collected.

## Additive receipt evidence

The v1 receipt schema gains optional, defaulted nested summaries. Existing v1
receipts remain parseable.

### Semantic coverage

Coverage dimensions:

- requirement and acceptance;
- assertions and source references;
- typed failure/cancellation paths;
- causal boundaries and cleanup;
- fault classes;
- statechart states/transitions/events;
- schema partitions;
- mutation operators;
- executor/adaptor variants;
- performance and sandbox enforcement.

A target can be required or advisory. A hit names its evidence ID. Gaps include a
repair hint and exact next command when one is available.

`zigeffect test coverage` reports all targets and hits.
`zigeffect test gaps` reports only missing required/advisory evidence.

### Model testing

`ModelExplorer` performs bounded breadth-first exploration over a value model
contract and therefore retains the shortest discovered failing trace.

`StatechartExplorer(Definition)`:

- enumerates enum events directly;
- accepts an event factory for tagged-union payloads;
- runs the typed machine from its initial snapshot;
- records state, transition, event, guard, and final-state coverage;
- checks a caller-provided invariant after every transition;
- reports shortest failing/dead-end traces and truthful truncation.

Model receipts include replayable event names, transition IDs, source
references, bounds, and coverage.

### Schedule testing

`Schedules.explore` wraps the engine schedule explorer and converts its report
into the common testing evidence:

- explored and deduplicated states/schedules;
- deadlock, invariant, or step failure;
- smallest schedule and source reference;
- replay token;
- incomplete status on bounded truncation.

### Structural property shrinking

Schema generation remains deterministic. Shrinking expands from integers to:

- booleans and enums;
- strings, Unicode byte sequences, and constraint boundaries;
- optionals;
- arrays and sequence prefixes/elements;
- explicit and derived structs through field-wise shrinking;
- statechart event sequences;
- custom lawful shrinkers for transforms and application types.

The property receipt keeps the minimal encoded input, shrink path, seed, case
index, and exact replay metadata. Unsupported transforms remain explicit.

### Differential execution

A differential suite runs the same caller-defined scenario across named variants
such as deterministic, zio, thread pool, fake adapter, and real adapter. Results
are normalized semantically before comparison. Timing and incidental IDs may be
ignored only through an explicit normalization policy.

A mismatch records the baseline, variant, semantic digest, bounded diff, and
replay metadata.

### Deterministic virtual world

`VirtualWorld` is a value-owned deterministic laboratory with:

- fake clock and per-node clock skew;
- network latency, drop, duplicate, reorder, and partitions;
- queues with at-least-once delivery and redelivery;
- key/value store stale reads, conflicts, partial writes, and recovery;
- object corruption and crash points;
- bounded event history and truthful truncation.

It never opens a real socket or database. Fault plans are seeded, replayable, and
usable inside property/model tests.

### Requirement-aware mutation analysis

Mutation testing is explicit runtime instrumentation rather than unsafe automatic
source rewriting. Applications expose stable mutation points at typed boundaries.
The runner evaluates operators such as:

- negate decision;
- skip validation;
- remove retry;
- alter error mapping;
- omit finalization;
- duplicate/drop delivery;
- stale read;
- bypass idempotency.

A mutation is killed when the scenario fails for the intended acceptance reason.
Survivors are requirement-linked coverage gaps with source and repair hints.
Bounds and unsupported operators are disclosed.

### Performance contracts

Performance budgets support:

- allocations, frees, live/peak bytes;
- causal events and effect operations;
- schedule/model steps;
- artifact/binary bytes;
- deterministic duration and optional observed wall-clock duration.

Budgets are absolute or baseline-relative. Wall-clock regressions require an
explicit noise tolerance and minimum sample count. Baseline updates use the same
plan/apply conflict discipline as snapshots.

### Side-effect firewall

The firewall is default-deny for real ZigEffect capabilities:

- filesystem, network, process, environment, clock;
- SQL, queue, object store, external service.

Fake/in-memory capabilities are recorded separately and allowed by default.
Every access records capability, adapter, source, decision, and causal ID.
A denied attempt fails the receipt. Direct OS calls outside ZigEffect adapters
cannot be intercepted and are disclosed as a limitation.

## CLI surface

The stable CLI gains:

    zigeffect test coverage [--requirement <id>] [--component <id>] [--json]
    zigeffect test gaps [--requirement <id>] [--component <id>] [--json]
    zigeffect test stress <scenario> --seeds <n> [--json]
    zigeffect test history [--scenario <id>] [--json]

Existing `test run` and `test replay` ingest real process receipts. Model,
schedule, differential, mutation, virtual-world, performance, and sandbox
details are emitted by the public library into those receipts rather than
creating arbitrary CLI execution hooks.

## Workbench

The Tests view adds:

- execution identity and receipt-protocol health;
- semantic coverage map and actionable gaps;
- shortest model and schedule replay traces;
- property shrink path;
- differential mismatches;
- virtual-world fault timeline;
- killed/surviving mutants;
- performance budget table and baseline delta;
- side-effect capability decisions;
- history and regression fingerprints.

All sections have malformed, incomplete, unsupported, truncated, empty, and
narrow-screen states.

## Generated applications

Every scaffold:

- uses `TestContext.initFromProject` and `publish`;
- declares semantic coverage targets;
- demonstrates one structural property, schedule/model check, performance
  budget, and sandbox policy appropriate to its kind;
- teaches agents the receipt protocol and new queries;
- pins the managed contract through template compatibility snapshots.

## Security and hygiene

- All paths are fixed or validated under `.zigeffect/tests`.
- All process receipts are bounded, redacted, version-checked, and atomically
  moved only after validation.
- The CLI never trusts receipt status without recomputing `verdict()`.
- Source mutation is opt-in runtime instrumentation, never automatic file edits.
- No new `tools/*.zig` file is created.
- New runtime capability lives under `src` with direct tests.
