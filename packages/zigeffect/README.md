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
  bounded async stream adapters.
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
- `Option`, `Either`, `Duration`, `DateTime`, `BigDecimal`, `Chunk`,
  `HashSet`, `Redacted`, and `Data`: Effect-style data helpers with explicit
  Zig ownership.
- `match` / `pattern`: exhaustive tagged-union matching, partial matching,
  structural patterns, typed captures, and payload-filtered union arms.
- `formatExit` / `formatCause` / `formatObservabilityReport`: readable runtime
  and observability reports for CLIs, tests, and agent workflows.
- `Schedule` / `ScheduleProgram`: retry/repeat timing with `once`, `recurs`,
  `spaced`, `duration`, fixed, exponential, fibonacci, linear, backoff,
  deterministic jitter, and owned recursive schedule composition.
- `CausalStore` / `CausalBackend`: deterministic causal event storage, query
  helpers, report/JSON/DOT/CI formatters, and optional adapter sinks for JSON
  Lines, DOT, OpenTelemetry, embedded graph, and bounded async streams.
- `PerformanceBenchmarkReport`: deterministic journal append/replay and mailbox
  dispatch benchmark reports with threshold verdicts, text output, and JSON
  output.
- `TestEnv`: fake clock, memory filesystem, logger, config, metrics, tracing,
  runtime helpers, assertion helpers, and readable assertion report formatters.
- `Clock`: fake/system time service used by schedules and tests.
- `LocalAsyncBackendState`: local async wait registry for runtime suspension,
  timer wakeups, typed network/file waits, cancellation, and wake polling.
- `serviceNotFound`: rich compile-time diagnostics for missing environment
  services.

The core fiber runtime is semantic-first and deterministic by default. Attach
`LocalAsyncBackendState.backend()` to `Runtime`, `FiberRuntime`, workflow
schedulers, or cluster transport waits when code needs backend-owned
suspension, timer wakeups, typed network/file waits, or cancellation wakeups.
Direct-style effects stay synchronous unless they explicitly return
`RuntimeDecision.suspended` or call an async backend helper from context.

`zigeffect` now includes the first deterministic agent-observable causal
runtime surface: attach a `CausalStore` to a runtime, fiber runtime, layer
graph, or context, then inspect snapshots, lineage, causes, resources, fibers,
requirements, retries, findings, and reports instead of reconstructing runtime
behavior from logs.

Docs:

- [Usage](docs/usage.md)
- [Architecture](docs/architecture.md)
- [Public API Review](docs/public-api-review.md)
- [Migration To Durable Runtime](docs/migration-to-durable-runtime.md)
- [Errors](docs/errors.md)
- [Resource Ownership](docs/resource-ownership.md)
- [Data](docs/data.md)
- [Pattern Matching](docs/pattern-matching.md)
- [EffectTS Parity](docs/effectts-parity.md)
- [Module Pattern](docs/module-pattern.md)
- [Agent-Observable Causal Runtime](docs/agent-observable-runtime.md)
- [Causal Scenario Registry](docs/causal-scenarios.md)
- [Causal Operations](docs/operations.md)
- [Readiness Example](examples/readiness.zig)
- [Causal Readiness Example](examples/causal_readiness.zig)
- [Causal App Request Example](examples/causal_app_request.zig)
- [Causal Missing Config Scenario](examples/causal_missing_config.zig)
- [Causal Cleanup Failure Scenario](examples/causal_cleanup_failure.zig)
- [Causal Scoped Fiber Scenario](examples/causal_scoped_fiber.zig)
- [Causal Retry Exhaustion Scenario](examples/causal_retry_exhaustion.zig)
- [Data And Matching Example](examples/data_and_matching.zig)
- [Workflow Approval Example](examples/workflow_approval.zig)
- [Workflow Queue Worker Example](examples/workflow_queue_worker.zig)
- [Workflow Timer Signal Example](examples/workflow_timer_signal.zig)
- [Workflow Crash Recovery Example](examples/workflow_crash_recovery.zig)
- [Local Actor Example](examples/local_actor.zig)
- [Multi-Runner Cluster Example](examples/multi_runner_cluster.zig)
- [Cluster Workflow Migration Example](examples/cluster_workflow_migration.zig)
- [Agent Guide](docs/agent-guide.md)
- [Devex Review](docs/devex-review.md)
- [Roadmap](docs/roadmap.md)

Run tests:

```bash
bun run zigeffect:test
```

Run the durable workflow and cluster release gate:

```bash
bun run zigeffect:release
```

The release gate runs package tests, storage conformance, property crash tests,
bounded-resource checks, public API review, causal artifact generation, and all
examples. It writes release reports under
`packages/zigeffect/.zig-cache/release-gate/`.

Compile and test the package examples:

```bash
cd packages/zigeffect
zig build examples
```

Run the performance and bounded-resource gate:

```bash
cd packages/zigeffect
zig build performance-bounds
```

Print the deterministic performance benchmark report:

```bash
cd packages/zigeffect
zig build performance-bench
zig build performance-bench -- --json
```

Default benchmark thresholds are 1,024 journal events, 1,000,000 serialized
journal bytes, 4,096 offered mailbox messages, and 4,096 peak pending mailbox
messages.

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

Print the causal schema governance report:

```bash
cd packages/zigeffect
zig build causal-schema-governance
zig build causal-schema-governance -- --format json
```

The report lists every official causal artifact schema, current version,
producer, consumer, compatibility posture, and schema-change checklist. Treat it
as the first stop before adding or changing causal artifact fields. The full
policy is in [docs/schema-governance.md](docs/schema-governance.md).

Print the deterministic causal performance budget and release-review checklist:

```bash
cd packages/zigeffect
zig build causal-performance-budget
zig build causal-performance-budget -- --format json
```

The report uses schema `zigeffect.causal.performance-budget.v1` and lists the
current retention, string-bound, sampling, workbench, artifact-retention,
backend-sink, and release-note budgets. The full policy is in
[docs/performance-budget.md](docs/performance-budget.md).

Print the causal wall-clock benchmark baseline contract:

```bash
cd packages/zigeffect
zig build causal-wall-clock-benchmark-baselines
zig build causal-wall-clock-benchmark-baselines -- --format json
```

The report uses schema
`zigeffect.causal.wall-clock-benchmark-baselines.v1` and defines the local and
CI timing scenario families, baseline record fields, environment metadata,
calibration policy, advisory review gates, and capacity-planning handoff. It is
record-only and does not collect timings or fail CI. The full policy is in
[docs/wall-clock-benchmark-baselines.md](docs/wall-clock-benchmark-baselines.md).

Print the causal production capacity planning contract:

```bash
cd packages/zigeffect
zig build causal-production-capacity-planning
zig build causal-production-capacity-planning -- --format json
```

The report uses schema `zigeffect.causal.production-capacity-planning.v1` and
defines source evidence, capacity domains, storage assumptions, load-test
fixture plans, workbench and graph concurrency assumptions, readiness gates,
and negative capacity fixtures. It is record-only, planning-only, NenDB-only,
and does not run load tests or claim production capacity. The full policy is in
[docs/production-capacity-planning.md](docs/production-capacity-planning.md).

Print the causal production-hardening completion audit:

```bash
cd packages/zigeffect
zig build causal-production-hardening-completion-audit
zig build causal-production-hardening-completion-audit -- --format json
```

The audit uses schema
`zigeffect.causal.production-hardening-completion-audit.v1`, verifies the
delivered production-hardening milestones, preserves record-only/NenDB/SolidJS
boundaries, records remaining evidence gaps, and hands off to the delivered
local observation harness. The full policy is in
[docs/production-hardening-completion-audit.md](docs/production-hardening-completion-audit.md).

Print the causal load-test observation harness catalog or run a bounded local
observation:

```bash
cd packages/zigeffect
zig build causal-load-test-observation-harness
zig build causal-load-test-observation-harness -- --format json
zig build causal-load-test-observation-harness -- observe app-request-trace --iterations 1 --format json
```

The harness uses schema
`zigeffect.causal.load-test-observation-harness.v1`, catalogs approved scenario
families, and can emit local observation records with median/p95 timings,
bounded snippets, and advisory review gates. It is record-only,
`mutation_authority=none`, and does not run production load, ingest production
telemetry, fail CI, or claim production capacity. The full policy is in
[docs/load-test-observation-harness.md](docs/load-test-observation-harness.md).

Print the causal production telemetry capture design report:

```bash
cd packages/zigeffect
zig build causal-production-telemetry-capture-design
zig build causal-production-telemetry-capture-design -- --format json
```

The report uses schema
`zigeffect.causal.production-telemetry-capture-design.v1` and defines future
telemetry capture surfaces, field contracts, redaction, sampling, retention,
access, encryption, and OTel bridge review gates. It is design-only,
`mutation_authority=none`, and does not enable live telemetry ingestion,
exporters, durable production writes, CI gates, or production capacity claims.
The full policy is in
[docs/production-telemetry-capture-design.md](docs/production-telemetry-capture-design.md).

Print the causal production telemetry capture fixture catalog, selected
fixture, or validation report:

```bash
cd packages/zigeffect
zig build causal-production-telemetry-capture-fixtures
zig build causal-production-telemetry-capture-fixtures -- --format json
zig build causal-production-telemetry-capture-fixtures -- emit runtime-trace-span-event --format json
zig build causal-production-telemetry-capture-fixtures -- validate --format json
```

The report uses schema
`zigeffect.causal.production-telemetry-capture-fixtures.v1` and defines safe
example records plus negative fixtures for blocked production telemetry claims.
It is fixtures-only, `mutation_authority=none`, and does not enable live
telemetry ingestion, exporters, durable production writes, CI gates, production
capacity claims, non-NenDB adapters, alternate renderers, or mutation
authority. The full policy is in
[docs/production-telemetry-capture-fixtures.md](docs/production-telemetry-capture-fixtures.md).

Review production telemetry fixture readiness:

```bash
cd packages/zigeffect
mkdir -p ../../.zig-cache/causal-artifacts
zig build causal-production-telemetry-capture-fixtures -- --format json \
  2> ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json
zig build causal-production-telemetry-readiness-review -- \
  --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json \
  approve \
  --reason "fixtures reviewed for implementation proposal" \
  --verified-command "zig build causal-production-telemetry-capture-fixtures -- validate --format json" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The report uses schema
`zigeffect.causal.production-telemetry-readiness-review.v1` and emits a
reviewer-owned `ready` or `blocked` artifact before any implementation proposal
work. It keeps `applied=false`, `mutation_authority=none`, live telemetry,
exporters, durable writes, and CI gates disabled. The full policy is in
[docs/production-telemetry-readiness-review.md](docs/production-telemetry-readiness-review.md).

Draft the production telemetry implementation proposal:

```bash
cd packages/zigeffect
zig build causal-production-telemetry-implementation-proposal -- \
  --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json \
  approve \
  --reason "ready evidence reviewed for exporter boundary planning" \
  --verified-command "zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \"fixtures reviewed for implementation proposal\" --verified-command \"zig build causal-production-telemetry-capture-fixtures -- validate --format json\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The report uses schema
`zigeffect.causal.production-telemetry-implementation-proposal.v1` and emits an
`approved` or `blocked` proposal before any exporter-boundary branch starts. It
keeps `applied=false`, `mutation_authority=none`, live telemetry, exporters,
durable writes, and CI gates disabled. The full policy is in
[docs/production-telemetry-implementation-proposal.md](docs/production-telemetry-implementation-proposal.md).

Review the production telemetry exporter boundary:

```bash
cd packages/zigeffect
zig build causal-production-telemetry-exporter-boundary -- \
  --from-proposal ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.json \
  approve \
  --reason "proposal evidence reviewed for local pipeline fixtures" \
  --verified-command "zig build causal-production-telemetry-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json approve --reason \"ready evidence reviewed for exporter boundary planning\" --verified-command \"zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \\\"fixtures reviewed for implementation proposal\\\" --verified-command \\\"zig build causal-production-telemetry-capture-fixtures -- validate --format json\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The report uses schema
`zigeffect.causal.production-telemetry-exporter-boundary.v1` and emits an
`approved` or `blocked` boundary before any local pipeline fixture branch
starts. It keeps `applied=false`, `mutation_authority=none`, live telemetry,
network send, collector endpoints, OTLP serialization, durable writes, and CI
gates disabled. The full policy is in
[docs/production-telemetry-exporter-boundary.md](docs/production-telemetry-exporter-boundary.md).

Review the production telemetry local pipeline fixtures:

```bash
cd packages/zigeffect
zig build causal-production-telemetry-local-pipeline-fixtures -- \
  --from-boundary ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary.json \
  approve \
  --reason "approved boundary reviewed for local pipeline fixtures" \
  --verified-command "zig build causal-production-telemetry-exporter-boundary -- --from-proposal ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.json approve --reason \"proposal evidence reviewed for local pipeline fixtures\" --verified-command \"zig build causal-production-telemetry-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json approve --reason \\\"ready evidence reviewed for exporter boundary planning\\\" --verified-command \\\"zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \\\\\\\"fixtures reviewed for implementation proposal\\\\\\\" --verified-command \\\\\\\"zig build causal-production-telemetry-capture-fixtures -- validate --format json\\\\\\\" --verified-command \\\\\\\"zig build causal-schema-governance -- --format json\\\\\\\" --verified-command \\\\\\\"zig build causal-production-hardening-backlog -- --format json\\\\\\\" --verified-command \\\\\\\"zig build examples\\\\\\\" --verified-command \\\\\\\"zig build test\\\\\\\"\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The report uses schema
`zigeffect.causal.production-telemetry-local-pipeline-fixtures.v1` and emits a
`ready` or `blocked` fixture artifact before any NenDB retention fixture branch
starts. It keeps `applied=false`, `mutation_authority=none`, live telemetry,
network send, collector endpoints, OTLP serialization, runtime pipeline
execution, durable writes, and CI gates disabled. The full policy is in
[docs/production-telemetry-local-pipeline-fixtures.md](docs/production-telemetry-local-pipeline-fixtures.md).

Review the production telemetry NenDB retention fixtures:

```bash
cd packages/zigeffect
zig build causal-production-telemetry-nendb-retention-fixtures -- \
  --from-local-pipeline ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures.json \
  approve \
  --reason "approved local pipeline reviewed for NenDB retention fixtures" \
  --verified-command "zig build causal-production-telemetry-local-pipeline-fixtures" \
  --verified-command "zig build causal-nendb-storage-backend" \
  --verified-command "zig build causal-durable-production-retention -- --format json" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The report uses schema
`zigeffect.causal.production-telemetry-nendb-retention-fixtures.v1` and emits a
`ready` or `blocked` fixture artifact before the read-only workbench preview
branch starts. It keeps `applied=false`, `mutation_authority=none`, live
telemetry, network send, collector endpoints, OTLP serialization, runtime
pipeline execution, durable writes, NenDB writes, and CI gates disabled. The
full policy is in
[docs/production-telemetry-nendb-retention-fixtures.md](docs/production-telemetry-nendb-retention-fixtures.md).

Review the production telemetry workbench read-only preview:

```bash
cd packages/zigeffect
zig build causal-production-telemetry-workbench-readonly-preview -- \
  --from-retention ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures.json \
  approve \
  --reason "read-only SolidJS webui preview reviewed" \
  --verified-command "bun run zigeffect:workbench:typecheck" \
  --verified-command "bun run zigeffect:workbench:test" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The report uses schema
`zigeffect.causal.production-telemetry-workbench-readonly-preview.v1`, backs the
read-only `Telemetry` workbench tab, and emits a `ready` or `blocked` preview
artifact before CI artifact preview work starts. It keeps `applied=false`,
`mutation_authority=none`, read-only SolidJS/webui mode enabled, live
telemetry, network send, collector endpoints, OTLP serialization, runtime
pipeline execution, durable writes, NenDB writes, and CI gates disabled. The
full policy is in
[docs/production-telemetry-workbench-readonly-preview.md](docs/production-telemetry-workbench-readonly-preview.md).

Review the production telemetry CI artifact preview:

```bash
cd packages/zigeffect
zig build causal-production-telemetry-ci-artifact-preview -- \
  --from-workbench ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview.json \
  approve \
  --reason "CI artifact preview reviewed" \
  --verified-command "zig build causal-production-telemetry-workbench-readonly-preview" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The report uses schema
`zigeffect.causal.production-telemetry-ci-artifact-preview.v1`, records a
preview-only CI archive candidate catalog and upload policy, and emits a
`ready` or `blocked` CI artifact preview before CI harness boundary work
starts. It keeps `applied=false`, `mutation_authority=none`, CI upload,
workflow mutation, CI gates, live telemetry, network send, collector endpoints,
OTLP serialization, runtime pipeline execution, durable writes, and NenDB
writes disabled. The full policy is in
[docs/production-telemetry-ci-artifact-preview.md](docs/production-telemetry-ci-artifact-preview.md).

Review the production telemetry CI harness boundary:

```bash
cd packages/zigeffect
zig build causal-production-telemetry-ci-harness-boundary -- \
  --from-ci-preview ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview.json \
  --workflow ../../.github/workflows/zigeffect-causal.yml \
  approve \
  --reason "CI harness boundary reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-artifact-preview" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The report uses schema
`zigeffect.causal.production-telemetry-ci-harness-boundary.v1`, inspects the
existing causal GitHub Actions workflow, records workflow required and
prohibited feature checks, records clustering release-gate assumptions, and
emits a `ready` or `blocked` CI harness boundary before archive application
work starts. It keeps `applied=false`, `mutation_authority=none`, CI upload
execution, workflow mutation, CI gates, live telemetry, network send,
collector endpoints, OTLP serialization, runtime pipeline execution, durable
writes, NenDB writes, hosted dashboard claims, and production cluster claims
disabled. The full policy is in
[docs/production-telemetry-ci-harness-boundary.md](docs/production-telemetry-ci-harness-boundary.md).

Record the production telemetry CI archive application plan:

```bash
cd packages/zigeffect
zig build causal-production-telemetry-ci-archive-application -- \
  --from-harness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary.json \
  plan \
  --reason "CI archive application planned from reviewed harness boundary"
```

The report uses schema
`zigeffect.causal.production-telemetry-ci-archive-application.v1`, consumes a
ready CI harness boundary, emits `planned`, `applied`, or `blocked` archive
application artifacts, and only records `applied=true` in `record-applied`
mode when workflow-change, before, after, safe after-workflow, and
post-verification evidence are present. The tool does not modify GitHub
Actions, execute artifact uploads, enable CI gates, ingest live telemetry,
write NenDB, write durable production storage, or grant mutation authority.
The full policy is in
[docs/production-telemetry-ci-archive-application.md](docs/production-telemetry-ci-archive-application.md).

Record the production telemetry CI archive evidence policy:

```bash
cd packages/zigeffect
zig build causal-production-telemetry-ci-archive-evidence-policy -- \
  --from-archive-application ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-archive-application.json \
  approve \
  --reason "CI archive evidence policy reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-archive-application" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The report uses schema
`zigeffect.causal.production-telemetry-ci-archive-evidence-policy.v1`,
consumes planned or applied CI archive application artifacts, defines allowed
archive evidence classes, required metadata, interpretation rules, denied
claims, and negative fixtures, and hands off to CI gate readiness without
enabling workflow mutation, artifact upload execution, CI gates, live
telemetry, NenDB writes, durable writes, or mutation authority. The full policy
is in
[docs/production-telemetry-ci-archive-evidence-policy.md](docs/production-telemetry-ci-archive-evidence-policy.md).

Record the production telemetry CI gate readiness:

```bash
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-readiness -- \
  --from-archive-evidence-policy ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-archive-evidence-policy.json \
  approve \
  --reason "CI gate readiness reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-archive-evidence-policy" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The report uses schema
`zigeffect.causal.production-telemetry-ci-gate-readiness.v1`, consumes ready
archive evidence policy artifacts, records readiness dimensions, advisory
candidate gate signals, limited gate semantics, release-gate verification
evidence, and negative fixtures, and hands off to the gate application boundary
without enabling CI gates, required status checks, workflow mutation, artifact
upload execution, live telemetry, NenDB writes, durable writes, or mutation
authority. The full policy is in
[docs/production-telemetry-ci-gate-readiness.md](docs/production-telemetry-ci-gate-readiness.md).

Record the production telemetry CI gate application boundary:

```bash
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-application-boundary -- \
  --from-gate-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-readiness.json \
  plan \
  --reason "CI gate application boundary planned"
```

The report uses schema
`zigeffect.causal.production-telemetry-ci-gate-application-boundary.v1`,
consumes ready CI gate readiness artifacts, records planned, applied, or
blocked application boundary evidence, and only records `applied=true` when
reviewed workflow-change evidence, before evidence, after evidence,
after-workflow content, safe after-workflow checks, and post-application
verification exist. It does not enable CI gates, required status checks,
workflow mutation by the tool, artifact upload execution, live telemetry,
NenDB writes, durable writes, or mutation authority. The full policy is in
[docs/production-telemetry-ci-gate-application-boundary.md](docs/production-telemetry-ci-gate-application-boundary.md).

Record the production telemetry CI gate dry-run policy:

```bash
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-dry-run-policy -- \
  --from-gate-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-application-boundary.json \
  approve \
  --reason "CI gate dry-run policy reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-gate-application-boundary" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The report uses schema
`zigeffect.causal.production-telemetry-ci-gate-dry-run-policy.v1`, consumes
planned or applied CI gate application boundary artifacts, records advisory
candidate signal policies, bounded evidence requirements, negative fixtures,
and ready or blocked dry-run policy evidence, and hands off to the dry-run
evaluator branch. It does not enable CI gates, required status checks,
workflow mutation by the tool, artifact upload execution, live telemetry,
NenDB writes, durable writes, or mutation authority. The full policy is in
[docs/production-telemetry-ci-gate-dry-run-policy.md](docs/production-telemetry-ci-gate-dry-run-policy.md).

Evaluate dry-run policy evidence before advisory CI report work:

```bash
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-dry-run-evaluator -- \
  --from-dry-run-policy ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-dry-run-policy.json \
  evaluate \
  --reason "CI gate dry-run evidence evaluated" \
  --evidence .zig-cache/release-gate/zigeffect-release-gate.json \
  --evidence .zig-cache/causal-artifacts/zigeffect-causal-causal-scoped-fiber.json
```

The evaluator uses schema
`zigeffect.causal.production-telemetry-ci-gate-dry-run-evaluator.v1`, consumes
ready dry-run policy artifacts and explicit bounded local or CI evidence,
records ready, advisory, or blocked findings, and hands off to advisory CI
report rendering. The full policy is in
[docs/production-telemetry-ci-gate-dry-run-evaluator.md](docs/production-telemetry-ci-gate-dry-run-evaluator.md).

Render the production telemetry CI gate advisory CI report:

```bash
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-advisory-ci-report -- \
  --from-evaluator ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-dry-run-evaluator.json \
  summarize \
  --reason "CI advisory report reviewed"
```

The report uses schema
`zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report.v1`,
consumes ready or advisory dry-run evaluator artifacts, renders local JSON and
text reviewer guidance, records publication channels, and hands off to the
advisory CI report application boundary without writing GitHub summaries,
posting PR comments, uploading artifacts, creating required checks, enabling
live telemetry, writing NenDB, writing durable storage, or granting mutation
authority. The full policy is in
[docs/production-telemetry-ci-gate-advisory-ci-report.md](docs/production-telemetry-ci-gate-advisory-ci-report.md).

Record the production telemetry CI gate advisory CI report application
boundary:

```bash
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary -- \
  --from-report ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-advisory-ci-report.json \
  plan \
  --reason "CI advisory report application boundary planned"
```

The boundary uses schema
`zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-application-boundary.v1`,
consumes ready or advisory CI report artifacts, records planned, applied, or
blocked report publication boundary evidence, and only records `applied=true`
when reviewed publication-change evidence, before evidence, after evidence,
safe report-after content, and post-application verification exist. It does
not publish CI reports, upload artifacts, write GitHub summaries, post PR
comments, create required checks, enable live telemetry, write NenDB, write
durable storage, or grant mutation authority. The full policy is in
[docs/production-telemetry-ci-gate-advisory-ci-report-application-boundary.md](docs/production-telemetry-ci-gate-advisory-ci-report-application-boundary.md).

Review the production telemetry CI gate advisory CI report publication policy:

```bash
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy -- \
  --from-application ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-advisory-ci-report-application-boundary-applied.json \
  approve \
  --reason "CI advisory report publication policy reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The publication policy uses schema
`zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-publication-policy.v1`,
consumes applied application-boundary artifacts, and defines allowed and
denied interpretations for externally published advisory CI reports. It keeps
advisory reports useful for reviewer and agent triage while denying required
checks, merge blocking, workflow mutation, artifact upload proof, GitHub
summary proof by this tool, PR comment proof by this tool, production health,
cluster readiness, live telemetry coverage, durable writes, NenDB writes, and
mutation authority. The full policy is in
[docs/production-telemetry-ci-gate-advisory-ci-report-publication-policy.md](docs/production-telemetry-ci-gate-advisory-ci-report-publication-policy.md).

Review the production telemetry CI gate required status check readiness:

```bash
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-required-status-check-readiness -- \
  --from-publication-policy ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-advisory-ci-report-publication-policy.json \
  approve \
  --reason "required status check readiness reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The readiness artifact uses schema
`zigeffect.causal.production-telemetry-ci-gate-required-status-check-readiness.v1`,
consumes ready publication-policy artifacts, defines candidate required-check
profiles with activation disabled, records activation guardrails, and hands
off to the guarded required-status-check policy branch after the application
boundary milestone. It does
not create required checks, mutate branch protection, call GitHub APIs, mutate
workflows, enable CI gate enforcement, write NenDB, write durable storage, or
grant mutation authority. The full policy is in
[docs/production-telemetry-ci-gate-required-status-check-readiness.md](docs/production-telemetry-ci-gate-required-status-check-readiness.md).

Plan the production telemetry CI gate required status check application
boundary:

```bash
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary -- \
  --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-readiness.json \
  plan \
  --reason "required status check application boundary planned"
```

The application-boundary artifact uses schema
`zigeffect.causal.production-telemetry-ci-gate-required-status-check-application-boundary.v1`,
consumes ready required-status-check readiness artifacts, records planned or
externally applied required-status-check boundary evidence, and hands off to
the required-status-check policy branch. It does not mutate GitHub branch
protection, create check runs, call GitHub APIs, mutate workflows, enable CI
gate enforcement, write NenDB, write durable storage, or grant mutation
authority. The full policy is in
[docs/production-telemetry-ci-gate-required-status-check-application-boundary.md](docs/production-telemetry-ci-gate-required-status-check-application-boundary.md).

Review the production telemetry CI gate required status check policy:

```bash
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-required-status-check-policy -- \
  --from-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-application-boundary.json \
  approve \
  --reason "required status check policy reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The policy artifact uses schema
`zigeffect.causal.production-telemetry-ci-gate-required-status-check-policy.v1`,
consumes planned or externally applied required-status-check application
boundary artifacts, records planned versus applied interpretation, and hands
off to the enforcement-readiness branch. It does not mutate GitHub branch
protection, create check runs, call GitHub APIs, mutate workflows, enable CI
gate enforcement, write NenDB, write durable storage, or grant mutation
authority. The full policy is in
[docs/production-telemetry-ci-gate-required-status-check-policy.md](docs/production-telemetry-ci-gate-required-status-check-policy.md).

Review the production telemetry CI gate required status check enforcement
readiness evidence:

```bash
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness -- \
  --from-policy ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-policy.json \
  approve \
  --reason "required status check enforcement readiness reviewed" \
  --required-check-name "zigeffect causal release gate" \
  --branch-protection-evidence "reviewed branch protection required status check evidence" \
  --workflow-evidence "reviewed release gate workflow evidence" \
  --failure-mode-evidence "reviewed failing release gate blocks future required check" \
  --owner-approval "reviewed owner approval for future required check enforcement" \
  --rollback-evidence "reviewed rollback removes required status check from branch protection" \
  --verified-command "zig build causal-production-telemetry-ci-gate-required-status-check-policy" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The enforcement-readiness artifact uses schema
`zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-readiness.v1`,
requires an applied source policy plus explicit branch-protection, workflow or
check-run, failure-mode, owner approval, rollback, and verification evidence,
and hands off to the enforcement application-boundary branch. It does not
claim an active required status check, active merge blocking, GitHub mutation,
workflow mutation, CI upload execution, live telemetry, NenDB writes, durable
writes, production health, or mutation authority. The full policy is in
[docs/production-telemetry-ci-gate-required-status-check-enforcement-readiness.md](docs/production-telemetry-ci-gate-required-status-check-enforcement-readiness.md).

Record the production telemetry CI gate required status check enforcement
application boundary:

```bash
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary -- \
  --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-readiness.json \
  plan \
  --reason "required status check enforcement application boundary planned"
```

The enforcement application-boundary artifact uses schema
`zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.v1`,
consumes ready enforcement-readiness artifacts, records planned or externally
applied active required-status-check enforcement evidence, and hands off to
the enforcement policy branch. `record-applied` can set `applied=true` only
with reviewed branch-protection before/after evidence, workflow or check-run
evidence, failure-mode evidence, owner approval, rollback evidence,
verification, and merge-blocking evidence when that claim is made. It still
does not prove GitHub mutation by the tool, workflow mutation by the tool, CI
upload execution, live telemetry, NenDB writes, durable writes, production
health, or mutation authority. The full policy is in
[docs/production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.md](docs/production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.md).

Review the production telemetry CI gate required status check enforcement
policy:

```bash
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-policy -- \
  --from-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.json \
  approve \
  --reason "required status check enforcement policy reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The enforcement policy artifact uses schema
`zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-policy.v1`,
consumes planned or externally applied enforcement application-boundary
artifacts, defines how agents may interpret active enforcement and
merge-blocking evidence, and hands off to the enforcement evaluator branch.
It does not mutate GitHub, branch protection, workflows, check runs, CI
uploads, step summaries, pull-request comments, live telemetry, NenDB,
durable stores, non-NenDB adapters, alternate renderers, production systems,
or mutation authority. The full policy is in
[docs/production-telemetry-ci-gate-required-status-check-enforcement-policy.md](docs/production-telemetry-ci-gate-required-status-check-enforcement-policy.md).

Evaluate production telemetry CI gate required status check enforcement
evidence:

```bash
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator -- \
  --from-policy ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-policy.json \
  evaluate \
  --reason "required status check enforcement evidence evaluated" \
  --evidence ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-policy.json \
  --evidence ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.json \
  --evidence .zig-cache/release-gate/zigeffect-release-gate.json
```

The enforcement evaluator artifact uses schema
`zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-evaluator.v1`,
consumes ready enforcement-policy artifacts plus explicit bounded `.json` or
`.txt` evidence files, reports `ready`, `advisory-findings`, or `blocked`,
and hands off to the enforcement report branch. It does not mutate GitHub,
branch protection, workflows, check runs, CI uploads, step summaries,
pull-request comments, live telemetry, NenDB, durable stores, non-NenDB
adapters, alternate renderers, production systems, or mutation authority. The
full policy is in
[docs/production-telemetry-ci-gate-required-status-check-enforcement-evaluator.md](docs/production-telemetry-ci-gate-required-status-check-enforcement-evaluator.md).

Render the CI gate required status check enforcement report after an
enforcement evaluator artifact exists:

```bash
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report -- \
  --from-evaluator ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-evaluator.json \
  summarize \
  --reason "required status check enforcement report reviewed"
```

The enforcement report artifact uses schema
`zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report.v1`,
summarizes ready, advisory, and blocked evaluator artifacts, writes local
JSON/text reports only, preserves blocked findings, and hands off to the
enforcement report application-boundary branch. It does not mutate GitHub,
branch protection, workflows, check runs, CI uploads, step summaries,
pull-request comments, required status checks, live telemetry, NenDB, durable
stores, non-NenDB adapters, alternate renderers, production systems, or
mutation authority. The full policy is in
[docs/production-telemetry-ci-gate-required-status-check-enforcement-report.md](docs/production-telemetry-ci-gate-required-status-check-enforcement-report.md).

Record the CI gate required status check enforcement report application
boundary after an enforcement report artifact exists:

```bash
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary -- \
  --from-report ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report.json \
  plan \
  --reason "required status check enforcement report application boundary planned"
```

The enforcement report application-boundary artifact uses schema
`zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary.v1`,
records planned or externally applied report application evidence, keeps
`applied=false` unless reviewed before/after evidence and verification commands
exist, and hands off to the enforcement report policy branch. It does not
mutate GitHub, branch protection, workflows, check runs, CI uploads, step
summaries, pull-request comments, required status checks, live telemetry,
NenDB, durable stores, non-NenDB adapters, alternate renderers, production
systems, or mutation authority. The full policy is in
[docs/production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary.md](docs/production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary.md).

Print the M9 operating-model completion audit:

```bash
cd packages/zigeffect
zig build causal-m9-completion-audit
zig build causal-m9-completion-audit -- --format json
```

The audit uses schema `zigeffect.causal.m9-completion-audit.v1`, records the
evidence for M9 deliverables, lists deferred production-hardening gaps, and
recommends `deliver-m9-with-deferred-production-hardening` only after the full
verification suite passes. The full policy is in
[docs/m9-completion-audit.md](docs/m9-completion-audit.md).

Print the causal production-hardening backlog:

```bash
cd packages/zigeffect
zig build causal-production-hardening-backlog
zig build causal-production-hardening-backlog -- --format json
```

The backlog uses schema
`zigeffect.causal.production-hardening-backlog.v1`, turns the M9 production
gaps into ordered future hardening branches, and recommends
`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy`
after the delivered production telemetry CI gate required status check
enforcement report application-boundary milestone.
It keeps durable work on the NenDB adapter path, keeps the workbench direction
as SolidJS inside `webui-dev/zig-webui`, and does not grant production mutation
authority. The full policy is in
[docs/production-hardening-backlog.md](docs/production-hardening-backlog.md).

Print the causal live dashboard streaming workbench contract:

```bash
cd packages/zigeffect
zig build causal-live-dashboard-streaming-workbench
zig build causal-live-dashboard-streaming-workbench -- --format json
```

The contract uses schema
`zigeffect.causal.live-dashboard-streaming-workbench.v1`, registers
`zigeffect.causal.live-dashboard-stream.v1`, and backs the read-only Live and
Visual Graph workbench tabs. The full policy is in
[docs/live-dashboard-streaming-workbench.md](docs/live-dashboard-streaming-workbench.md).

Print the causal production artifact aggregation contract:

```bash
cd packages/zigeffect
zig build causal-production-artifact-aggregation
zig build causal-production-artifact-aggregation -- --format json
```

The contract uses schema
`zigeffect.causal.production-artifact-aggregation.v1`, defines aggregation
bundle semantics, source provenance fields, privacy review gates, and a
deterministic multi-source fixture for future durable retention. It does not
ingest production telemetry, write durable storage, open dashboards, or grant
mutation authority. The full policy is in
[docs/production-artifact-aggregation.md](docs/production-artifact-aggregation.md).

Print the causal durable production retention contract:

```bash
cd packages/zigeffect
zig build causal-durable-production-retention
zig build causal-durable-production-retention -- --format json
```

The contract uses schema
`zigeffect.causal.durable-production-retention.v1`, consumes the artifact
aggregation contract, and defines the NenDB-only TTL, compaction, backup,
recovery, and retained-bundle fixture policy before deployment runbooks. It
does not ingest live telemetry, restore production data, add non-NenDB durable
scope, or grant mutation authority. The full policy is in
[docs/durable-production-retention.md](docs/durable-production-retention.md).

Print the causal production deployment runbooks contract:

```bash
cd packages/zigeffect
zig build causal-production-deployment-runbooks
zig build causal-production-deployment-runbooks -- --format json
```

The contract uses schema
`zigeffect.causal.production-deployment-runbooks.v1`, consumes the production
artifact aggregation and durable retention contracts, and defines manual deploy,
rollback, causal verification, and incident-response gates without deployment
automation or production mutation authority. Its immediate consumer is artifact
access control. The full policy is in
[docs/production-deployment-runbooks.md](docs/production-deployment-runbooks.md).

Print the causal artifact access-control contract:

```bash
cd packages/zigeffect
zig build causal-artifact-access-control
zig build causal-artifact-access-control -- --format json
```

The contract uses schema `zigeffect.causal.artifact-access-control.v1`,
consumes the aggregation, durable-retention, and deployment-runbook contracts,
and defines visibility classes, roles, permissions, access decisions, denied
fixtures, and audit record fields without live RBAC enforcement or production
mutation authority. This contract handed off to
`codex/zigeffect-causal-unified-spine-contract`; use the production-hardening
backlog for the current next branch. The full policy is in
[docs/artifact-access-control.md](docs/artifact-access-control.md).

Print the causal unified spine contract:

```bash
cd packages/zigeffect
zig build causal-unified-spine-contract
zig build causal-unified-spine-contract -- --format json
```

The contract uses schema `zigeffect.causal.unified-spine-contract.v1` and
defines the canonical runtime ids, app semantic ids, relationship taxonomy,
policy boundary, derived index families, and projection contracts shared by
deep runtime internals, app semantic tracing, agent queries, the SolidJS
`zig-webui` workbench, and NenDB adapter projection. It hands off to
`codex/zigeffect-causal-deep-runtime-internals` without changing live runtime
emission or granting mutation authority. The full policy is in
[docs/unified-spine-contract.md](docs/unified-spine-contract.md).

Open the read-only SolidJS causal workbench for a saved artifact:

```bash
cd packages/zigeffect
zig build causal-test
zig build causal-workbench -- .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json
zig build causal-workbench -- --server-only .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json
```

`causal-workbench` builds the SolidJS renderer with Bun/Vite, opens it through
`zig-webui`, and exposes the selected artifact through a bounded read-only Zig
bridge. The workbench has timeline, findings, relationship, query, metadata,
and inspector views. The Graph tab derives cause paths, parent edges, and
runtime lanes for runs, scopes, fibers, resources, and retries from the selected
artifact. The Chain tab also recognizes remediation/governance artifacts such as
`zigeffect.causal.audit-chain.v1`, showing source artifact paths, evidence id
classifications, verification commands, and guardrails while remaining
read-only. It also renders app remediation audit, app policy decision, app
human review, app patch proposal, app application readiness, and app
application artifacts with app incident rows, policy gate results, proposal
citations, readiness/application checks, change evidence, before/after
evidence, verification commands, guardrails, and copyable source workbench
commands. It does not edit source, update the scenario registry, make policy
decisions, or write remediation artifacts. When a native browser or WebView
cannot be opened, the launcher falls back to a local WebUI server URL;
`--server-only` starts that local read-only server directly for agent/browser
inspection.

Record app-facing request or background-job incidents with the same causal
runtime vocabulary:

```zig
var store = fx.CausalStore.initWithOptions(
    allocator,
    fx.defaultRequestCausalStoreOptions(),
);
defer store.deinit();

var trace = try fx.CausalAppTrace.startRequest(&store, .{
    .method = "GET",
    .route = "/api/projects/:id",
    .runtime = "worker",
});
try trace.recordServiceResolution("ProjectService", "satisfied");
try trace.complete(.success);

const json = try fx.formatCausalJson(allocator, &store);
defer allocator.free(json);
```

`defaultRequestCausalStoreOptions` keeps request traces bounded at 256 events
and 256 bytes per event string; `defaultJobCausalStoreOptions` uses a 1024-event
budget for background jobs. The adapter emits normal `zigeffect.causal.v1`
events, so app artifacts can be opened in the same SolidJS `zig-webui`
workbench and queried with the existing causal tools.

Compile and test the Worker-shaped app request example:

```bash
cd packages/zigeffect
zig build causal-app-request-example
```

`examples/causal_app_request.zig` keeps the request path pure: it returns a
response plus owned causal JSON and leaves persistence to the caller. Use that
shape when a Worker app wants to put app incidents into R2, Durable Objects,
D1, logs, or another app-owned sink before opening the artifact in the
workbench.

Classify app incidents before drafting app fixes:

```zig
var incidents = try fx.deriveCausalAppIncidents(allocator, &store);
defer incidents.deinit();
```

The classifier maps app config, requirement, failed response, retry, resource,
and fiber evidence to `CausalAppIncidentKind` values without changing the core
event taxonomy. `causal-advice` and `causal-diagnosis` also prefer app-specific
actions such as `fix-app-config`, `wire-app-requirement`, and
`inspect-app-response-failure` for clearly app-owned evidence.

Record a non-mutating app remediation audit from a saved app artifact:

```bash
cd packages/zigeffect
zig build causal-app-remediation-audit -- local --artifact <causal-json> --target <app-target>
```

The audit uses schema `zigeffect.causal.app-remediation-audit.v1`, preserves
`approval_status=pending`, `applied=false`, and `mutation_authority=none`, and
names advisory app policy gates such as `config-only` and `source-only`.

Evaluate those app gates before drafting a proposal:

```bash
cd packages/zigeffect
zig build causal-app-policy-decision -- local --audit <app-remediation-audit-json>
```

The policy report uses schema `zigeffect.causal.app-policy-decision.v1`. It
distinguishes `source-only`, `config-only`, `migration-required`,
`operational-human-required`, and `rollback-required`, but remains advisory:
every report keeps `mutation_authority=none` and `applied=false`.

Record human review evidence when policy says `needs-human-review`:

```bash
cd packages/zigeffect
zig build causal-app-human-review -- local --policy <app-policy-decision-json> --reviewer <actor> --decision approve --reason <reason> --migration <path> --runbook <path> --rollback <path>
```

The review uses schema `zigeffect.causal.app-human-review.v1` and writes
`*-app-human-review.json` plus `*-app-human-review.txt`. It can approve draft
proposal creation for migration, operational, or rollback-required app work,
but still records `applied=false` and `mutation_authority=none`.

Draft a non-mutating app patch proposal after an approved source/config policy
decision, or after a matching approved human-review artifact for high-risk
gates:

```bash
cd packages/zigeffect
zig build causal-app-patch-proposal -- local --policy <app-policy-decision-json> --review <app-human-review-json> --summary <summary> --change <description> --file <path> --config <key>
```

The proposal uses schema `zigeffect.causal.app-patch-proposal.v1` and writes
`*-app-patch-proposal.json` plus `*-app-patch-proposal.txt`. It cites app source
files, config keys or bindings, migration files, runbooks, and rollback plans
without applying any of them. It always records `proposal_status=draft`,
`approval_status=pending`, `approved=false`, `applied=false`, and
`mutation_authority=none`; config citations name keys only and must not include
secret values.

Review app application readiness before attempting the real change:

```bash
cd packages/zigeffect
zig build causal-app-application-readiness -- local --proposal <app-patch-proposal-json> approve --reason <reason> --verified <command>
```

The readiness report uses schema
`zigeffect.causal.app-application-readiness.v1` and writes
`*-app-application-readiness.json` plus
`*-app-application-readiness.txt`. It re-checks draft proposal state, source
links, policy gates, citations, high-risk human-review links, and recorded
verification commands. `readiness_status=ready` means the proposal is ready to
attempt, not that it was applied. Every readiness report preserves
`applied=false` and `mutation_authority=none`.

Record guarded app application after the real reviewed change has been made:

```bash
cd packages/zigeffect
zig build causal-app-apply -- --from-readiness <app-application-readiness-json> plan --reason <reason>
zig build causal-app-apply -- --from-readiness <app-application-readiness-json> record-applied --reason <reason> --verified-command <command> --source-change <path> --before <evidence> --after <evidence>
```

The application report uses schema `zigeffect.causal.app-application.v1` and
writes `*-app-application.json` plus `*-app-application.txt`. Plan mode keeps
`applied=false`. Record-applied mode writes `applied=true` only when readiness
is ready, the decision is approved, required change evidence exists,
before/after evidence exists, and required post-application verification is
recorded. The command records application state; it does not edit source,
config, migrations, operations, rollback plans, deployments, queues,
databases, or external systems.

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

For the full local/CI operating contract, use
[docs/operations.md](docs/operations.md). It defines artifact retention,
failure handoff order, redaction review, review gates, guarded application
records, workbench operation, backend adapter expectations, and production
gaps.

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
  "truncation": {
    "max_event_string_bytes": null,
    "truncated_fields": 0
  },
  "backend": {
    "kind": null,
    "failed_writes": 0
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

For long-running probes with potentially large labels, statuses, type names, or
details, configure `max_event_string_bytes` as well as `max_events`:

```zig
var store = fx.CausalStore.initWithOptions(allocator, .{
    .max_events = 256,
    .max_event_string_bytes = 512,
});
defer store.deinit();
```

Truncation is opt-in. Redaction runs before truncation, and attached backends
receive the bounded strings. If `truncated_fields` is nonzero, cite the
truncation metadata and avoid claims that depend on complete event payload
text.

Backend adapters are sinks, not the source of truth. If `failed_writes` is
nonzero, the deterministic in-memory causal trace is still usable, but backend
durability or export evidence may be incomplete. Future backend adapter branches
must run `zig build causal-backend-conformance` before claiming adapter
compatibility.

Use `fx.CausalJsonLinesBackendState` when a local or CI harness needs one
schema-tagged causal event per line while the run is being recorded:

```zig
var lines = std.ArrayList(u8).empty;
defer lines.deinit(allocator);

var jsonl_backend = fx.CausalJsonLinesBackendState.init(allocator, &lines, .{
    .max_bytes = 64 * 1024,
});

var store = fx.CausalStore.init(allocator);
store.attachBackend(jsonl_backend.backend());
defer store.deinit();
```

The JSONL backend receives the same stored events as every backend: assigned,
redacted, bounded, and not sampled out. A full row is formatted before it is
appended; when `max_bytes` would be exceeded, no partial row is written and
`backendFailureCount()` reports the failed sink write. Pair JSONL files with the
full causal JSON artifact when agents need retention, sampling, truncation, or
backend metadata. Run `zig build causal-jsonl-backend` for the focused adapter
gate.

Use `fx.CausalDotBackendState` when a local or CI harness wants graph output as
events are recorded. DOT backend output is an artifact builder: call
`finish()` before writing the buffer to a `.dot` file. Treat DOT as visual
evidence for humans and graph tools; use the full causal JSON artifact for
agent queries, schema metadata, retention, sampling, and truncation summaries.
Run `zig build causal-dot-backend` for the focused adapter gate.

Use `fx.CausalOtelBackendState` when a harness wants OpenTelemetry-shaped
records while events are recorded. The first OTel bridge is dependency-free and
exporter-neutral: complete local `trace_id` plus `span_id` context maps to a
`span_event`, and missing or incomplete span context maps to a `log_record`.
Records preserve `zigeffect.causal.*` typed attributes so later SDK or OTLP
exporters can forward effect-native runtime facts without reparsing artifacts.
Run `zig build causal-otel-backend` for the focused adapter gate.

Use `fx.CausalGraphHistoryBackendState` when a local harness or agent session
needs queryable event history beyond the core store's retention window. The
first graph-history bridge is dependency-free and scan-based: it returns
`CausalBackendKind.nendb_graph` and establishes the NenDB adapter contract
before package-backed storage is wired in. Query the backend with `snapshot`,
`cause`, `lineage`, `eventsByKind`, `eventsByRun`, `eventsByScope`, and
`eventsByFiber`. Run `zig build causal-graph-history-backend` for the focused
adapter gate.

Use `fx.CausalNendbStorageBackendState` when a harness needs to verify the
event-to-NenDB graph storage contract. It maps stored causal events into
NenDB-shaped node writes and parent-edge writes through a caller-provided
`CausalNendbGraphWriter`, then keeps scan-based local history for immediate
agent queries. This branch intentionally avoids a direct upstream NenDB package
dependency because the current Zig package shape is not stable enough for this
build; a future wrapper can target `nendb.EmbeddedDB.addNode`, `addEdge`, and
`flush`. Run `zig build causal-nendb-storage-backend` for the focused adapter
gate.

Use `fx.CausalAsyncStreamBackendState` when a local agent, watch-mode tool, or
app runtime wants to observe stored causal events incrementally without claiming
durable history. The adapter keeps a bounded queue of cloned, sanitized events,
optionally forwards accepted events to a caller-provided `CausalAsyncStreamSink`,
and exposes `peekSnapshot`, `drain`, `clear`, and `flush`. If
`failedEventCount()` or `backendFailureCount()` is nonzero, treat the stream as
incomplete and fall back to retained store, graph-history, NenDB storage, JSONL,
or full JSON evidence. Run `zig build causal-async-stream-backend` for the
focused adapter gate.

Causal artifacts also include `event_taxonomy_version`. Version `1` classifies
logs, metrics, and spans as sampleable observability; runtime lifecycle events
as structural evidence; and service, scope, resource, fiber, schedule, and
assertion events as finding evidence. Finding evidence is never sampleable.
The local query, compare, development-loop query, and advice reports warn when
an artifact uses a newer schema version, unsupported schema name, newer
taxonomy version, or unknown event kind. These warnings do not make event ids
unusable; they tell agents where shape or role semantics may be incomplete for
the local tool.

Causal event strings are defensively redacted before storage and backend
emission for common secret, header, cookie, URL credential, query-parameter,
JSON-ish, config-ish, SQL-ish, and key-bound personal-data forms. Callers
should still avoid putting secrets, prompts, request bodies, credentials, or
personal data in labels, statuses, type names, or details; the redactor is a
deterministic safety backstop, not a full PII classifier.

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

Print the causal coverage matrix for service, layer, scope, fiber, schedule,
config, resource, retry, cause, and observability domains:

```bash
cd packages/zigeffect
zig build causal-test-matrix
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

Name an existing causal JSON artifact with a snapshot manifest:

```bash
zig build causal-run -- missing-service-compile-fail
zig build causal-snapshot -- capture missing-service-baseline missing-service-compile-fail
zig build causal-snapshot -- fork-proposal missing-service-baseline missing-service-compile-fail missing-service-fork
zig build causal-snapshot -- replay-scenario missing-service-baseline missing-service-compile-fail
zig build causal-snapshot -- capture baseline
zig build causal-snapshot -- manifest baseline .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json --format text
zig build causal-snapshot -- compare baseline baseline
zig build causal-snapshot -- replay-feasibility baseline
```

`causal-snapshot` writes or prints `zigeffect.causal.snapshot-manifest.v1`
metadata for an existing causal JSON artifact. The manifest records the
snapshot name, artifact path, event count, event id range, finding count, replay
feasibility, warnings, and next query commands. It does not embed events.
`causal-snapshot replay-scenario` is the execution step: it reruns a registered
scenario command, writes replay-specific `.txt`, `.json`, and `.dot` artifacts,
compares the baseline artifact with the replay artifact, and prints
`zigeffect.causal.deterministic-replay.v1`. It does not execute arbitrary
causal event logs or reconstruct services, closures, resources, fibers, clocks,
scheduler state, external IO, or runtime memory.

`causal-snapshot fork-proposal` writes
`zigeffect.causal.scenario-fork-proposal.v1` JSON/text artifacts for a named
snapshot, registered scenario, and proposed fork name. The artifact is a draft:
`approved=false`, `executed=false`, and it lists allowed replay/feasibility
commands plus blocked operations such as runtime memory forking, arbitrary
event-log replay, source mutation, and scenario registry mutation.

`causal-snapshot compare` accepts snapshot names or manifest JSON paths. It
reads each manifest's referenced causal JSON artifact, prints snapshot-level
event and finding deltas, and embeds the existing `causal-compare` event diff.

`causal-snapshot replay-feasibility` reads a snapshot manifest and its causal
JSON artifact, keeps `feasible: false`, and lists the blockers that must be
resolved before arbitrary event-log replay can exist.

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

When event evidence needs a visual pass, open the same JSON artifact in the
local workbench:

```bash
zig build causal-workbench -- .zig-cache/causal-artifacts/zigeffect-causal-missing-service-compile-fail.json
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
zig build causal-registry-application-readiness -- --from-registry-patch .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-patch.json approve --reason "reviewed registry patch draft" --verified-command "zig build causal-run learned-dogfood-service-resolution" --verified-command "zig build examples"
zig build causal-registry-apply -- --from-readiness .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-application-readiness.json plan --reason "prepare manual registry application"
zig build causal-policy-decision -- local
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
zig build causal-registry-application-readiness -- --from-registry-patch .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-patch.json approve --reason "no registry patch applies"
zig build causal-registry-apply -- --from-readiness .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-application-readiness.json plan --reason "no registry patch applies"
zig build causal-policy-decision -- local causal-scoped-fiber
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
draft argv must be replaced with the smallest reproducing command before
any manual registry change is treated as coverage.
`causal-registry-application-readiness` reads that registry patch draft, records
an explicit `approve` or `reject` review decision, and writes
`*-registry-application-readiness.json` plus
`*-registry-application-readiness.txt` with schema
`zigeffect.causal.registry-application-readiness.v1`. Its status is
`applicable`, `blocked`, or `not-applicable`; it verifies reviewer intent,
registry state, draft argv replacement, invariant catalog consistency,
scenario docs, and required verification commands. The gate remains
non-mutating and always reports `applied=false`.
`causal-registry-apply` reads the readiness report and writes
`*-registry-application.json` plus `*-registry-application.txt` with schema
`zigeffect.causal.registry-application.v1`. `plan` mode records the manual
application steps with `applied=false`. `record-applied` mode records
`applied=true` only when current source state and supplied verification
commands prove the reviewed registry/docs update has already happened. The
command records application state; it does not silently edit source.
`causal-policy-decision` reads the audit, optional manual decision, patch
proposal, audit chain, and any scenario-registry readiness/application
artifacts, then writes `*-policy-decision.json` plus
`*-policy-decision.txt` with schema
`zigeffect.causal.policy-decision.v1`. The default policy is
`local-causal-self-improvement-v1`; it can recommend `approve`, `reject`, or
`needs-human-review`, but every report keeps `applied=false` and
`mutation_authority=none`.

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
