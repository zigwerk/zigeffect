# zigeffect

`zigeffect` is a Zig-native Effect-inspired core for composing direct-style Zig
programs.

The center of the API is still normal Zig:

```zig
fn program(ctx: *fx.Context(fx.TestServices)) AppError!Result {
    const logger = ctx.service(fx.Logger);
    try logger.info("running");
    return .{};
}
```

Wrap direct-style functions when you want composition, retry, scoped resources,
or test environments:

```zig
const Program = fx.Effect(Result, AppError, fx.TestServices).fromFn(program);
const result = try Program
    .map(Other, mapResult)
    .tap(recordTelemetry)
    .retry(&ctx, &schedule);
```

Included in this package:

- `Effect`: `fromFn`, `succeed`, `fail`, `sync`, `run`, `exit`, `retry`,
  `repeat`, `map`, `flatMap`, `tap`, `onExit`, `ensuring`, and recovery
  helpers.
- `Runtime`: runs effects with engine-managed scopes and automatic cleanup on
  success or failure, with optional service requirement gates.
- `FiberRuntime` / `Fiber`: deterministic fork, join, interrupt, scoped
  leases, and direct scope-attached forks for Effect-style fiber lifecycle
  semantics.
- `Deferred`, `Queue`, and `Semaphore`: deterministic coordination primitives
  with explicit wait-state/backpressure inspection for tests, tooling, and
  future async backends.
- `Context`: typed service access and scoped finalizer registration.
- `acquireRelease` / `acquireReleaseValue`: typed resource acquisition with
  automatic scope cleanup.
- `Layer`: dependency environment wrapper, scoped dependency builder, provider,
  context-aware dependency builder, provider, and merge helper.
- `LayerWithError`: layer builders with typed startup errors.
- `ServiceSet`, `DependencyReport`, and `LayerGraph`: production DI metadata,
  graph validation, and readable dependency diagnostics.
- `validateRequirements` / `requirementsSatisfiedBy`: compare declared
  requirements against declared providers.
- `layerGraph`: executable heterogeneous layer graph startup with generated
  composite environments, dependency ordering, dependency reports, and memoized
  layer builds, plus regular and fiber runtime adapters for graph-started
  environments.
- `Scope`: reverse-order finalizers, including exit-aware cleanup.
- `Exit` / `Cause`: structured result shapes, plus `CauseTree` for
  allocator-owned recursive cause reports.
- `formatExit` / `formatCause` / `formatObservabilityReport`: readable runtime
  and observability reports for CLIs, tests, and agent workflows.
- `Schedule` / `ScheduleProgram`: retry/repeat timing with `once`, `recurs`,
  `spaced`, `duration`, fixed, exponential, fibonacci, linear, backoff,
  deterministic jitter, and owned recursive schedule composition.
- `CausalStore` / `CausalBackend`: deterministic causal event storage, query
  helpers, report/JSON/DOT/CI formatters, and optional adapter sinks for JSON
  Lines, DOT, OpenTelemetry, embedded graph, durable history, and future async
  streams.
- `TestEnv`: fake clock, memory filesystem, logger, config, metrics, tracing,
  runtime helpers, assertion helpers, and readable assertion report formatters.
- `Clock`: fake/system time service used by schedules and tests.
- `serviceNotFound`: rich compile-time diagnostics for missing environment
  services.

The core fiber runtime is semantic-first and deterministic. It does not claim
real green-thread suspension; a future optional zio adapter will provide the
stackful coroutine and `std.Io` backend.

`zigeffect` now includes the first deterministic agent-observable causal
runtime surface: attach a `CausalStore` to a runtime, fiber runtime, layer
graph, or context, then inspect snapshots, lineage, causes, resources, fibers,
requirements, retries, findings, and reports instead of reconstructing runtime
behavior from logs.

Docs:

- [Usage](docs/usage.md)
- [Architecture](docs/architecture.md)
- [Errors](docs/errors.md)
- [Resource Ownership](docs/resource-ownership.md)
- [EffectTS Parity](docs/effectts-parity.md)
- [Module Pattern](docs/module-pattern.md)
- [Agent-Observable Causal Runtime](docs/agent-observable-runtime.md)
- [Causal Scenario Registry](docs/causal-scenarios.md)
- [Readiness Example](examples/readiness.zig)
- [Causal Readiness Example](examples/causal_readiness.zig)
- [Causal Missing Config Scenario](examples/causal_missing_config.zig)
- [Causal Cleanup Failure Scenario](examples/causal_cleanup_failure.zig)
- [Causal Scoped Fiber Scenario](examples/causal_scoped_fiber.zig)
- [Causal Retry Exhaustion Scenario](examples/causal_retry_exhaustion.zig)
- [Agent Guide](docs/agent-guide.md)
- [Devex Review](docs/devex-review.md)
- [Roadmap](docs/roadmap.md)

Run tests:

```bash
bun run zigeffect:test
```

Compile and test the package examples:

```bash
cd packages/zigeffect
zig build examples
```

Print a sample causal CI report:

```bash
cd packages/zigeffect
zig build causal-report
```

Run the local causal dogfood harness and write agent-readable artifacts:

```bash
cd packages/zigeffect
zig build causal-test
```

The harness writes a text report, JSON event snapshot, and DOT graph under
`.zig-cache/causal-artifacts/`.

Print the causal artifact retention manifest for agents and CI:

```bash
cd packages/zigeffect
zig build causal-artifacts
```

The manifest lists stable upload globs for
`.zig-cache/causal-artifacts/*.txt`, `.json`, and `.dot`, plus dogfood,
scenario, and dev-loop artifact paths. Use text artifacts for quick human
triage, JSON artifacts for `causal-query`, compare, and advice tooling, and DOT
artifacts for graph visualization. Do not upload the rest of `.zig-cache`.

Repository CI uses `.github/workflows/zigeffect-causal.yml` to print this
manifest, generate dogfood artifacts, run examples, run the causal package-test
gate, and upload only causal artifacts when the job fails.

Write the compact CI failure handoff report locally:

```bash
cd packages/zigeffect
zig build causal-ci-handoff
```

The report is written to
`.zig-cache/causal-artifacts/zigeffect-causal-ci-handoff.txt`. CI runs this on
failure before artifact upload, so agents should read that file first and then
inspect the generated `*-advice.txt` reports or run the exact `causal-query`
commands it lists.

Causal JSON artifacts use this root header:

```json
{
  "schema": "zigeffect.causal.v1",
  "schema_version": 1,
  "event_taxonomy_version": 1,
  "retention": {
    "max_events": null,
    "dropped_events": 0,
    "oldest_retained_event_id": null
  },
  "sampling": {
    "log_every_n": null,
    "metric_every_n": null,
    "span_every_n": null,
    "sampled_events": 0
  },
  "events": []
}
```

Older event-only artifacts remain readable by the local query, compare, and
development-loop tools.

Use `fx.CausalStore.initBounded(allocator, max_events)` when a development or
CI harness needs capped retained memory. Queries operate on retained events;
reports and JSON artifacts disclose `max_events`, `dropped_events`, and
`oldest_retained_event_id` so agents know when evidence is truncated.

Use `fx.CausalStore.initWithOptions(allocator, .{ .sampling = ... })` when a
development or CI harness needs to reduce high-volume observability events.
Sampling is opt-in and currently applies only to `log_recorded`,
`metric_recorded`, and `span_recorded`; structural runtime events remain
unsampled. Sampled-out events consume IDs but do not enter the retained store or
attached backends. Reports and JSON artifacts disclose `sampled_events` so
agents know observability evidence may be incomplete without treating the causal
runtime trace as retention-truncated.

Causal artifacts also include `event_taxonomy_version`. Version `1` classifies
logs, metrics, and spans as sampleable observability; runtime lifecycle events
as structural evidence; and service, scope, resource, fiber, schedule, and
assertion events as finding evidence. Finding evidence is never sampleable.
The local query, compare, and development-loop query reports warn when an
artifact uses a newer taxonomy version than the tool supports.

Causal event strings are defensively redacted before storage and backend
emission for common secret-shaped key/value details, bearer values, and URL
credentials. Callers should still avoid putting secrets in labels, statuses,
type names, or details; the redactor is a safety backstop, not a full PII
classifier.

Run the failure-gated causal dogfood check:

```bash
cd packages/zigeffect
zig build causal-check
```

`causal-check` writes the same artifacts as `causal-test`, then exits nonzero
when the dogfood fixture contains findings. Use it when a development or CI
agent should treat causal findings as actionable failures.

Print the registered causal scenarios and invariants:

```bash
cd packages/zigeffect
zig build causal-catalog
```

Capture artifacts for a real expected compile-fail scenario:

```bash
cd packages/zigeffect
zig build causal-capture-missing-service
```

Prove the package-test failure lane without breaking real package tests:

```bash
cd packages/zigeffect
zig build causal-package-failure-fixture
```

This runs one intentionally failing Zig test through the causal command
harness. The outer build step exits zero because the failure is expected, and it
writes `package-tests-failure-fixture` artifacts that agents can query before
trusting the real package-test failure lane.

Run package tests through the causal development harness:

```bash
cd packages/zigeffect
zig build test
```

`test` exits zero while package tests pass. If package tests fail during
development, it writes scenario-specific `package-tests` artifacts under
`.zig-cache/causal-artifacts/` before exiting nonzero. Use
`zig build test-raw` only when debugging the underlying Zig test binary without
the causal wrapper. `zig build causal-dev-test` remains an explicit alias for
the same causal package-test harness.

Run the two-phase causal development loop around a runtime patch:

```bash
cd packages/zigeffect
zig build causal-dev-loop -- baseline
# make the patch
zig build causal-dev-loop -- after
```

Target a registered scenario when the patch touches a specific subsystem:

```bash
zig build causal-dev-loop -- baseline causal-scoped-fiber
# make the patch
zig build causal-dev-loop -- after causal-scoped-fiber
```

The baseline phase writes
`.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json` and runs the
package-test gate. The after phase writes
`.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json`, writes
`.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt`, writes
`.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt`, writes
`.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt`, writes
`.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json`, reruns the
package-test gate, and prints the report paths. Scenario targets use
slug-specific before, after, compare, query-report, advice-report, and verdict
paths under `.zig-cache/causal-artifacts/`.

Run a named scenario from the catalog:

```bash
cd packages/zigeffect
zig build causal-run -- causal-scoped-fiber
```

Query the default dogfood JSON artifact:

```bash
cd packages/zigeffect
zig build causal-query -- cause 3
zig build causal-query -- lineage 2
zig build causal-query -- resources 1
zig build causal-query -- fibers pending
zig build causal-query -- requirements 1
zig build causal-query -- retries 1
```

Use `zig build causal-query -- --file <path> <query> [argument]` to inspect a
non-default artifact.

For example:

```bash
zig build causal-query -- --file .zig-cache/causal-artifacts/zigeffect-causal-missing-service-compile-fail.json cause 3
```

Generate deterministic next-action advice from a saved causal JSON artifact:

```bash
zig build causal-advice -- --file .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json
zig build causal-advice -- --before .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json --file .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json
```

Advice reports are rule-based and non-mutating. They point at event ids and
exact `causal-query` commands, but they do not generate patches or apply
remediation. Single-artifact advice marks actions as `status=observed`;
before-aware advice marks unchanged evidence as `status=persisting` and
after-only evidence as `status=new`.

Run the coordinated local self-improvement session while changing `zigeffect`:

```bash
zig build causal-dev-session -- start
# edit source
zig build causal-dev-session -- assess
zig build causal-dev-session -- status
```

For scenario targets, pass the same scenario slug:

```bash
zig build causal-dev-session -- start causal-scoped-fiber
# edit source
zig build causal-dev-session -- assess causal-scoped-fiber
zig build causal-dev-session -- status causal-scoped-fiber
```

`causal-dev-session` writes `zigeffect-causal-dev-session.{json,txt}` or
scenario-specific `zigeffect-causal-dev-session-<scenario>.{json,txt}`
artifacts. `start` captures the baseline half of the dev loop. `assess` runs
the after phase, local agent handoff, diagnosis, remediation plan, and
remediation audit. It does not approve, apply, or edit source; review remains
explicit through `causal-remediation-decision`.

To run the same chain manually, read the local verdict and generate
agent-facing follow-up artifacts:

```bash
zig build causal-dev-agent -- local
zig build causal-diagnosis -- local
zig build causal-remediation-plan -- local
zig build causal-remediation-audit -- local
zig build causal-patch-proposal -- local draft --summary "scope cleanup ordering" --file packages/zigeffect/src/core/scope.zig --change "tighten finalizer ordering evidence"
zig build causal-remediation-decision -- local approve --by local-reviewer --policy manual-review
zig build causal-patch-proposal -- local approved --summary "scope cleanup ordering" --file packages/zigeffect/src/core/scope.zig --change "tighten finalizer ordering evidence"
zig build causal-audit-chain -- local
zig build causal-scenario-proposal -- local
zig build causal-scenario-registry-patch -- --from-proposal .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-scenario-proposal.json
```

For scenario targets, pass the same scenario slug:

```bash
zig build causal-dev-agent -- local causal-scoped-fiber
zig build causal-diagnosis -- local causal-scoped-fiber
zig build causal-remediation-plan -- local causal-scoped-fiber
zig build causal-remediation-audit -- local causal-scoped-fiber
zig build causal-remediation-decision -- local reject causal-scoped-fiber --reason "clear verdict"
zig build causal-patch-proposal -- local draft causal-scoped-fiber --summary "scoped fiber evidence" --file packages/zigeffect/src/runtime/fiber.zig --change "record scoped fiber interruption evidence"
zig build causal-audit-chain -- local causal-scoped-fiber
zig build causal-scenario-proposal -- local causal-scoped-fiber
zig build causal-scenario-registry-patch -- --from-proposal .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-scenario-proposal.json
```

`causal-dev-agent` prints the inspection order, `causal-diagnosis` writes
`*-diagnosis.txt`, and `causal-remediation-plan` writes
`*-remediation-plan.md`. `causal-remediation-audit` writes
`*-remediation-audit.json` and `*-remediation-audit.txt` with pending approval
status, source artifact paths, evidence event ids, verification commands, and
claim guardrails. `causal-remediation-decision` writes
`*-remediation-decision.json` and `*-remediation-decision.txt` with an approved
or rejected review result while keeping `applied=false`.
`causal-patch-proposal` writes `*-patch-proposal.json` and
`*-patch-proposal.txt`. Draft proposals read pending audits and remain
unapproved; approved proposals require an approved remediation decision. Both
proposal modes keep `applied=false` and never edit source.
`causal-audit-chain` writes `*-audit-chain.json` and `*-audit-chain.txt` by
comparing the current session, audit, optional decision, proposal, before/after
causal artifacts, and compare report. It classifies proposal event ids as
disappeared, persisting, appeared, or missing, then reports `assessment` as
`improved`, `unchanged`, `regressed`, or `inconclusive`. The command is
deterministic and non-mutating; use it to constrain patch claims, not as proof
that source edits were authorized.
`causal-scenario-proposal` writes `*-scenario-proposal.json` and
`*-scenario-proposal.txt` after the audit chain exists. It recommends
`add-scenario`, `refine-scenario`, or `none`, cites verdict and audit-chain
evidence, proposes reviewable scenario/invariant coverage, and never edits the
scenario registry.
`causal-scenario-registry-patch` reads a scenario proposal and writes
`*-registry-patch.json`, `*-registry-patch.txt`, and `*-registry-patch.zig`.
The JSON schema is `zigeffect.causal.registry-patch.v1`. The Zig file is a
review draft only; the command never edits `tools/causal_run.zig`, and its
placeholder argv must be replaced with the smallest reproducing command before
any manual registry change is treated as coverage.

Compare two saved causal JSON artifacts:

```bash
cd packages/zigeffect
zig build causal-compare -- .zig-cache/causal-artifacts/before.json .zig-cache/causal-artifacts/after.json
```

The compare report summarizes event count deltas, finding count deltas, added
events, removed events, and changed events. Use it when a fix needs evidence
that the causal trace improved instead of just changed.

Print an agent-friendly module scaffold:

```bash
cd packages/zigeffect
zig build-exe tools/scaffold_module.zig
./scaffold_module billing Ledger
```
