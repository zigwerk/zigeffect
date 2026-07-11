# ZigEffect Agent-First Testing Platform Design

Date: 2026-07-10
Status: accepted for implementation

## Goal

Build a public testing platform for ZigEffect applications whose primary
consumer is a coding agent. A failed test must identify the smallest
reproducible behavioral reason, relate it to a requirement and source location,
disclose evidence completeness, and provide a bounded replay or next query.

The platform extends Zig's `std.testing`; it does not replace Zig's test runner.
It productizes the strong deterministic, causal, fault, and conformance
capabilities already used internally by ZigEffect.

## Problem

ZigEffect already has:

- `fx.TestEnv` with scoped logger, config, metrics, tracing, memory filesystem,
  fake clock, IDs, fixture registry, golden assertions, and structured reports;
- deterministic and real executor tests;
- private causal assertions and replay assertions;
- tracked allocation and all-allocation-failure tests;
- bounded schedule exploration and minimal schedules;
- generated workflow/message histories and crash injection;
- backend/storage conformance suites;
- application facts, project requirements, acceptance checks, safety receipts,
  and a Workbench.

The public `zstd.Testing` module exposes only JSON equality and sentinel-secret
assertions. Application agents cannot consume the internal strengths through one
stable API or one requirement-linked receipt. They must compose bespoke fakes,
assertions, fault loops, text output, and handoff evidence per project.

## Product principles

1. **Requirements first.** Every application scenario can name its project
   requirement, acceptance check, component, and source roots.
2. **Deterministic by default.** Time, IDs, filesystem, processes, HTTP, SQL,
   schedules, and failure injection must be fakeable and seeded.
3. **Relationships over logs.** Assertions can target typed exits, causal
   events, ownership, services, fibers, resources, workflows, and application
   facts.
4. **Minimal reproduction.** Property, schedule, and fault failures retain the
   smallest known input/case plus an exact replay command.
5. **Truthful completeness.** Dropped, sampled, truncated, stale, unsupported,
   skipped, or unrun required evidence cannot become a pass.
6. **Scoped ownership.** Fixtures and artifacts have explicit allocation and
   cleanup; tests must not introduce global mutable mock registries.
7. **Redacted artifacts.** Secret-shaped values are rejected or redacted before
   receipts, snapshots, compiler output, or Workbench payloads.
8. **No arbitrary execution.** The CLI runs manifest-owned test commands and
   recorded scenario IDs, never caller-supplied shell fragments.
9. **No report-tool sprawl.** Runtime capability lives under `src`; CLI
   orchestration extends the existing executable rather than adding core tools.
10. **One evidence protocol.** Humans, Codex, Claude Code, CI, and the Workbench
    consume the same schemas.

## Non-goals

- Replacing `std.testing` or the Zig test binary protocol.
- Claiming exhaustive concurrency, memory, or input-space proof.
- Automatically approving snapshot updates.
- Running paid providers, external networks, production migrations, or
  deployments in CI.
- Hiding platform-specific sanitizers or unsupported gates behind a generic
  success status.
- Making arbitrary unmanaged Zig memory-safe.

## Public package ownership

```text
packages/zigeffect-std/src/testing/
├── root.zig          # public facade and backwards-compatible helpers
├── contract.zig      # scenario, assertion, result, receipt, completeness
├── context.zig       # scoped TestContext over fx.TestEnv and CausalStore
├── assertions.zig    # value, Exit/Cause, causal, service, resource, fiber
├── faults.zig        # deterministic fault case/matrix planning and runners
├── generators.zig    # seeded values, Schema generation, property shrinking
├── snapshots.zig     # semantic, redacted, versioned fixture snapshots
└── registry.zig      # suite/scenario registry and requirement coverage
```

Engine-level primitives remain in `packages/zigeffect/src`. Standard-library
testing composes those primitives but does not move application concerns into
the core runtime.

CLI orchestration remains in `packages/zigeffect-cli`. Workbench parsing and UI
remain under `packages/zigeffect/workbench/src/testing`.

## Versioned contracts

### Test scenario

`zigeffect.test-scenario.v1` fields:

- `id`
- `label`
- `requirement`
- `acceptance_check`
- `component`
- `command`
- `source_roots`
- `tags`
- `default_seed`
- `fault_profile`
- `required`

The project manifest gains an optional `test_scenarios` array. Validation fails
closed on duplicate IDs, broken requirement/check/component/command references,
unsafe paths, unknown fault profiles, zero seeds where prohibited, and
secret-shaped values.

### Test result

Statuses:

- `passed`
- `failed`
- `incomplete`
- `unsupported`
- `skipped`
- `canceled`

Only `passed` with complete required evidence can satisfy an acceptance check.

### Test receipt

`zigeffect.test-receipt.v1` contains:

- project, suite, scenario, requirement, acceptance check, component;
- source revision and Zig/tool versions;
- status, required flag, start/end/duration;
- seed, executor, fault kind, fault index, schedule choices;
- assertion results with source references and causal event IDs;
- minimal counterexample and shrink count;
- memory and causal summaries;
- completeness counters and limitations;
- bounded stdout/stderr artifact links;
- exact manifest-owned replay command;
- redacted detail.

### Test collection receipt

`zigeffect.test-run.v1` joins scenario receipts for one invocation and reports:

- selected versus discovered scenarios;
- requirement and component coverage;
- passed/failed/incomplete/unsupported/skipped/canceled counts;
- introduced/resolved failures against an optional baseline;
- total duration and evidence bounds;
- source revision and selection reason (`all`, `requirement`, `component`,
  `tag`, `affected`, or `replay`).

## Public API

### Scenario

```zig
const scenario = zstd.Testing.Scenario{
    .id = "create-order",
    .label = "duplicate keys create one order",
    .requirement = "req-create-order",
    .acceptance_check = "check-create-order",
    .component = "api-service",
    .default_seed = 42,
};
```

Scenario validation is available independently of the project manifest so
library tests can use it.

### TestContext

`TestContext` owns:

- an `fx.TestEnv`;
- an optional/attached `fx.CausalStore`;
- the current Scenario and FaultCase;
- assertion results;
- source references;
- artifacts and limitations;
- start/end deterministic timestamps;
- receipt formatting.

It exposes the existing core fake services and layers rather than duplicating
them. Applications add their own typed fake providers using normal
`zstd.Service.Provider` and `Layer` composition.

### Assertions

Initial public matchers:

- boolean/equality/string/semantic JSON;
- secret-free text;
- successful/failed/interrupted/defect/finalizer `Exit`/`Cause` states;
- causal event and event sequence;
- no causal findings or a specific finding;
- service provided/resolved/missing;
- resource finalized/leaked;
- fiber terminal/pending;
- application fact;
- schedule delay and retry exhaustion;
- workflow state and replay equivalence;
- memory has no live allocations/invalid frees.

Assertions append a structured result before returning an error. Source
locations default from `@src()` at the call site. Assertion reports remain
human-readable but JSON is authoritative for agents.

## Typed fixtures

The platform reuses:

- `fx.TestEnv` core services and layers;
- `zstd.Console.CapturedConsole`;
- `zstd.Env` and `zstd.Config`;
- `zstd.FileSystem.MemoryFileSystem`;
- `zstd.Process.FakeRunner`;
- `zstd.Http` fake client and memory server/router;
- `zstd.Sql.FakeDatabase` and pools;
- engine queues, pub/sub, streams, clock, workflow journals, and cluster stores.

`FixtureRegistry(T)` provides typed named values for homogeneous fixture
families. Heterogeneous service fixtures continue to use compile-time
`Service.Provider`/Layer environments, preserving type safety and scoped
ownership.

## Fault matrix

`FaultMatrix` is a bounded deterministic plan, not an implicit infinite search.

Fault kinds:

- none;
- allocation failure;
- schedule choice;
- timeout;
- cancellation;
- interruption;
- spawn failure;
- retry exhaustion;
- process failure;
- HTTP failure;
- SQL failure/rollback;
- journal crash point;
- corrupt/truncated artifact;
- executor selection.

The matrix expands a scenario into stable `FaultCase` IDs. Limits are mandatory
and recorded. Generic callbacks receive the case and decide how to install the
application-specific failure. Built-in adapters bridge:

- `std.testing.checkAllAllocationFailures`;
- `fx.TrackedAllocator`;
- `fx.exploreSchedules`;
- workflow journal crash injection patterns;
- deterministic executor equivalence.

The first failing case stops by default; exhaustive-within-bounds is opt-in.

## Generators and shrinking

### Seeded generator

`Generator(T)` is comptime-generic and owns deterministic seed/case state. It
supports bool, integers, enums, optionals, arrays/slices with explicit bounds,
structs, tagged unions, and custom generators.

### Schema generation

`fromSchema(schema)` derives values from the existing Schema type:

- strings respect min/max length and enum constraints;
- integers respect min/max;
- booleans, optionals, arrays, structs, and enums compose recursively;
- transforms require an explicit generator if a lawful inverse cannot generate;
- invalid-input generation deliberately violates one named constraint and
  records the expected issue path.

### Property runner

`checkProperty` records seed, case index, generated value, result, and shrink
history. On failure it shrinks deterministically and stores the smallest known
counterexample. Bounds cover cases, shrink steps, bytes, collection lengths, and
artifact size.

## Semantic snapshots

Snapshot kinds:

- text;
- semantic JSON;
- JSONL record set;
- causal graph shape;
- application facts;
- workflow replay state;
- statechart definition/coverage artifact;
- test receipt.

Snapshots declare ignored/normalized fields explicitly. Secret-shaped values
fail before write. Unknown schema versions fail closed. Update is a separate
explicit CLI mode requiring `--apply`; normal tests never rewrite snapshots.

Snapshot files live under `test/fixtures` or a manifest-declared fixture root.
Receipts record the snapshot digest and comparison result, not the entire
unbounded payload.

## CLI

Existing `project test` gains `--agent` and scenario selection. A new top-level
`test` family provides inspection without creating a core runtime tool:

```text
zigeffect test list [--requirement <id>|--component <id>|--tag <tag>] --json
zigeffect test run <scenario-id> [--seed <n>] --json
zigeffect test affected --changed <path> --json
zigeffect test explain <failure-id> [--receipt <path>]
zigeffect test replay <failure-id> [--receipt <path>]
zigeffect test snapshot <scenario-id> --apply
```

`run` and `replay` resolve only manifest-owned command IDs. `replay` adds only
validated, bounded environment metadata/arguments supported by the generated
test harness; it never evaluates a shell string from a receipt.

`affected` selects scenarios whose source roots include a changed path, then
adds downstream dependent components using the manifest graph. It reports why
each scenario was selected and does not claim unselected tests are unnecessary
when dependency metadata is incomplete.

## Agent protocol

Agent status adds:

- scenarios total/passed/failed/incomplete;
- uncovered active requirements;
- latest test-run artifact;
- replayable failures.

Agent evidence includes `test_result` records linked to requirement and
acceptance IDs. Next actions prioritize failed required scenarios, then
incomplete evidence, then uncovered active requirements.

Handoff validation rejects a satisfied requirement when its required scenario
receipt is missing, stale, incomplete, or failed.

## Workbench

The Tests view contains:

- requirement/component/scenario navigation;
- pass/fail/incomplete/unsupported counters;
- assertion list with source links;
- fault/executor matrix;
- seed, minimal counterexample, and replay command;
- causal event/path selection in the existing graph;
- memory and evidence completeness;
- introduced/resolved baseline failures;
- empty, malformed, unknown-schema, truncated, desktop, and narrow-screen
  states.

Workbench parsing is fail-closed and read-only. Snapshot apply and test replay
remain CLI/policy actions.

## Generated projects

Every scaffold includes:

- a manifest test scenario linked to `req-bootstrap` and `check-bootstrap`;
- a standard-library Scenario/TestContext example;
- a deterministic service/boundary test;
- an application-fact/causal assertion;
- one bounded fault example (allocation for executable projects, generator for
  libraries/packages);
- a test receipt fixture for Workbench development;
- generated skills that require `project test --agent --json` and explain/replay
  before handoff.

System scaffolds include scenarios for API, worker, shared package, and one
cross-component workflow/contract acceptance path.

## Compatibility and versioning

- CLI version becomes `0.3.0`.
- scaffold template version becomes `3`.
- project schema remains `zigeffect.project.v1` with additive optional
  `test_scenarios`; unknown future schemas still fail closed.
- existing v1 projects without test scenarios remain valid but test coverage is
  explicitly `unmanaged`/empty until adopted.
- scaffold upgrades add CLI-owned skill/compatibility metadata only; they do not
  overwrite user tests or manifests with inferred requirements.
- scaffold contract digests and compatibility documentation are updated.

## Security and bounds

- no credentials, credential URLs, raw PTY input, or unbounded output in tests;
- stdout/stderr and counterexamples are bounded and redacted;
- fixture and snapshot paths are safe relative paths;
- generator, shrink, schedule, fault, event, diagnostic, and artifact limits are
  mandatory positive values;
- processes and network remain fake by default;
- real integration tests require manifest policy and explicit commands;
- test receipt parsing owns all strings and validates before exposure;
- allocation-failure tests cover every owned builder/parser/formatter.

## Acceptance criteria

The roadmap is complete only when:

1. public testing contracts and JSON schemas round-trip and fail closed;
2. TestContext and assertions exercise real effects and causal stores;
3. fixture ownership is leak-free under all allocation failures;
4. fault matrices deterministically replay OOM, schedule, timeout/cancel,
   retry, process/HTTP/SQL, crash, corruption, and executor cases;
5. generators reproduce and shrink a Schema-derived failure;
6. semantic snapshots normalize, redact, compare, and refuse implicit updates;
7. CLI list/run/affected/explain/replay/snapshot use only manifest-owned state;
8. agent status/evidence/next/handoff incorporate test receipts truthfully;
9. every scaffold compiles and runs its generated testing scenarios in Debug
   and ReleaseSafe;
10. the Workbench Tests view renders a real generated receipt and malformed
    evidence fails closed;
11. public API stability, compatibility, docs, redaction, tool hygiene, core,
    stdlib, CLI, adapters, and Workbench gates pass;
12. `bun run zigeffect:local-release` passes with testing-platform coverage.

## Roadmap

### M112 — Testing contracts and receipts

Public Scenario, assertion, result, completeness, receipt, collection receipt,
manifest scenario validation, JSON compatibility, redaction, and allocation
failure coverage.

### M113 — Scoped TestContext and fixtures

Productize `fx.TestEnv`, causal attachment, typed fixture registry/layers,
artifacts, deterministic timestamps, and receipt assembly.

### M114 — Assertion and causal matcher library

Value/JSON/secret, Exit/Cause, service/resource/fiber, causal/app fact,
workflow/replay, schedule, and memory assertions with source-linked results.

### M115 — Deterministic fault matrix

Bounded fault planning and adapters for OOM, schedules, timeout, cancellation,
spawn/retry/process/HTTP/SQL, crash/corruption, and executor equivalence.

### M116 — Schema generators and shrinking

Seeded generic generation, Schema derivation, invalid generation, property
runner, bounded deterministic shrinking, minimal counterexample receipts.

### M117 — Semantic snapshots and fixture registry

Versioned semantic snapshot formats, normalizers, redaction, explicit update,
digests, fixture roots, and compatibility tests.

### M118 — Agent testing protocol and CLI

Manifest scenarios, project test agent mode, list/run/affected/explain/replay/
snapshot, receipt persistence, requirement coverage, agent status/evidence/next/
handoff integration.

### M119 — Workbench Tests UX

Fail-closed parser/model, Tests navigation/panel, matrices, assertion/source/
causal links, counterexample/replay, completeness, baseline, responsive states,
and browser proof.

### M120 — Scaffolds, distribution, and release

Generated test examples for every project kind, template/CLI compatibility
bump, snapshots, docs/skills, public API and release-gate integration, full local
release proof, and evidence-backed handoff.
