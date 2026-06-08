# zigeffect Guide For Agents

Use this guide when building with `zigeffect`.

## Rules

- Keep app logic as normal Zig functions: `fn run(ctx) Error!A`.
- Use `Effect.fromFn` to make direct-style functions composable.
- Use `Effect.requires(.{ ... })` for production effects that depend on
  services.
- Use `Effect.succeed`, `Effect.fail`, and `Effect.sync` for small reusable
  helpers instead of writing tiny wrapper functions.
- Use `mapError`, `catchAll`, `orElse`, and `tapError` for recovery boundaries.
- Use `onExit` when logic needs the structured `Exit`; use `ensuring` when an
  effect-local finalizer must run on success and failure.
- Use `Layer.fromBuilder` for dependencies that need allocation, startup, or
  teardown.
- Use `LayerWithError` when dependency startup can fail with app-specific
  errors.
- Use `Layer.provides(.{ ... })`, `Layer.requires(.{ ... })`, and `LayerGraph`
  to validate production dependency boundaries before startup.
- Use `fx.layerGraph` when production startup should build heterogeneous
  declared layers automatically and reuse the started dependencies across runs.
- Use `Layer.provide` for tests or tools that should run a program directly from
  a layer. Use `Layer.merge` when a module needs multiple dependency groups.
- Use Zig error sets for typed errors. Do not hide failures in strings or status
  booleans.
- Include `OutOfMemory` when code allocates or registers scoped resources.
- Include `MissingScope` when code registers scoped resources or uses
  `acquireRelease`.
- Use `acquireRelease` for any resource that must be closed, destroyed, or
  returned to a pool.
- Use fallible finalizers when cleanup can fail, then inspect `Runtime.exit` or
  `Scope.firstFinalizerFailure`.
- Use exit-aware finalizers when cleanup behavior depends on success versus
  typed failure.
- Prefer `Runtime.run` or `TestEnv.run` so cleanup is engine-managed.
- Only close scopes manually in low-level scope tests or special runtime code.
- Use `fx.serviceNotFound(Env, Service)` as the final branch of every custom
  environment `service` method.
- Use `fx.formatExit` or `fx.formatCause` for CLI/test reports instead of
  inventing one-off error strings.
- Use `fx.validateLayerRequirements` and `fx.formatDependencyReport` before
  running large application graphs.
- Use `Schedule.repeat` for successful polling/repetition and `Schedule.backoff`
  or `Schedule.jitteredBackoff` for retry loops.
- Use `Schedule.once`, `recurs`, `spaced`, `duration`, and `fibonacci` when
  those names make the retry/repeat policy easier to scan.
- Use `fx.Clock` as the clock service; do not reach directly for OS time inside
  effectful code.
- Add tests before implementation.
- Update usage docs when adding public API.
- Prefer small service structs over global state.

## App Shape

```zig
const AppError = error{ MissingScope, OutOfMemory, MissingConfig, InvalidInput };

fn app(ctx: *fx.Context(AppEnv)) AppError!AppResult {
    const logger = ctx.service(fx.Logger);
    try logger.info("running");
    return .{};
}

const App = fx.Effect(AppResult, AppError, AppEnv).fromFn(app);
```

## Recovery Shape

```zig
fn recover(err: AppError, ctx: *fx.Context(AppEnv)) AppError!AppResult {
    _ = err;
    const logger = ctx.service(fx.Logger);
    try logger.warn("recovering");
    return .{};
}

const Program = App
    .tapError(logFailure)
    .catchAll(AppError, recover);
```

For production modules, attach requirements:

```zig
const Program = App
    .requires(.{ fx.Logger, fx.Config });
```

Custom environments should make missing services obvious:

```zig
const AppEnv = struct {
    logger: fx.Logger,

    pub fn service(self: *AppEnv, comptime Service: type) *Service {
        if (Service == fx.Logger) return &self.logger;
        return fx.serviceNotFound(AppEnv, Service);
    }
};
```

## Layer Shape

```zig
fn buildEnv(allocator: std.mem.Allocator, scope: *fx.Scope) std.mem.Allocator.Error!*AppEnv {
    const env = try allocator.create(AppEnv);
    env.* = .{ .logger = fx.Logger.init(allocator) };

    scope.addFinalizerFor(AppEnv, env, releaseEnv) catch |err| {
        releaseEnv(env);
        return err;
    };

    return env;
}

fn releaseEnv(env: *AppEnv) void {
    const allocator = env.logger.allocator;
    env.logger.deinit();
    allocator.destroy(env);
}

const AppLayer = fx.Layer(AppEnv).fromBuilder(buildEnv);
```

Use `Layer.fromEnv` only when the caller already owns the environment lifetime.

Use `Layer.provide` to run from a layer:

```zig
const result = try AppLayer
    .provides(.{fx.Logger})
    .provide(allocator, App);
```

Use metadata validation before app startup:

```zig
var graph = fx.LayerGraph.init(allocator);
defer graph.deinit();

try graph.addLayer("app", AppLayer.provides(.{fx.Logger}));
try graph.addLayer("program", AppLayer.requires(.{fx.Logger}));

var report = try graph.validate(allocator);
defer report.deinit();

if (!report.isValid()) return error.InvalidDependencyGraph;
```

Use executable graph startup when callers should not hand-write a merged
environment:

```zig
var graph = fx.layerGraph(allocator, .{
    AppLayer.requires(.{ fx.Logger }).provides(.{AppService}),
    LoggerLayer.provides(.{fx.Logger}),
});
defer graph.deinit();

const GraphEnv = @TypeOf(graph).EnvType;
const Program = fx.Effect(AppResult, AppError, GraphEnv)
    .fromFn(app)
    .requires(.{ AppService, fx.Logger });

const result = try graph.run(Program);
```

## Resource Shape

```zig
const ResourceError = error{ MissingScope, OutOfMemory };

fn acquire(ctx: *fx.Context(AppEnv)) ResourceError!*Resource {
    const resource = try ctx.allocator.create(Resource);
    resource.* = .{ .allocator = ctx.allocator };
    return resource;
}

fn release(resource: *Resource) void {
    resource.allocator.destroy(resource);
}

const OpenResource = fx.acquireRelease(Resource, ResourceError, AppEnv, acquire, release);
```

Run `OpenResource` through the runtime. The runtime opens a scope and closes it
in reverse registration order even when the program fails.

```zig
_ = try env.run(OpenResource);
```

If a resource effect returns `error.MissingScope`, the program was run against a
context without an active `Scope`. Run it through `Runtime.run`, `TestEnv.run`,
or construct a context with a scope.

For fallible cleanup:

```zig
try scope.addFinalizerFallibleFor(Resource, resource, releaseMayFail);
```

For exit-aware cleanup:

```zig
fn releaseWithExit(resource: *Resource, exit: fx.FinalizerExit) void {
    switch (exit) {
        .success => resource.releaseCleanly(),
        .failure => resource.releaseAfterFailure(),
        else => resource.releaseCleanly(),
    }
}

try ctx.addFinalizerExitFor(Resource, resource, releaseWithExit);
```

Prefer `Runtime.exit` when a caller needs to inspect cleanup failures as
structured causes.

## Diagnostic Reports

```zig
const exit = env.exit(Program);
const report = try fx.formatExit(std.testing.allocator, "program name", exit);
defer std.testing.allocator.free(report);
```

Use stable program labels like `"compile schema"` or `"load config"` so humans
and agents can connect the report back to the failing workflow.

## Causal Runtime Direction

The long-term agent workflow is documented in
`docs/agent-observable-runtime.md`. The first causal runtime APIs are now
available through `fx.CausalStore`, graph/runtime `.withCausalStore`, query
helpers, and causal report/JSON/DOT formatters. Agents should use them with
this discipline:

- Prefer structured `Exit`, `Cause`, dependency, observability, and test reports
  over ad hoc log scraping.
- Preserve stable labels for effects, layers, resources, schedules, and test
  workflows.
- Keep typed Zig errors visible instead of converting them into strings.
- Add service requirements and provider declarations so future causal queries
  can explain where dependencies came from.
- Use scopes and `acquireRelease` for owned resources so resource lineage can be
  observed later.
- Use tracing spans and trace context where a workflow crosses service or fiber
  boundaries.
- Attach a `CausalStore` to runtime, fiber runtime, or layer graph paths when a
  test or example needs agent-readable evidence.
- Record app-level log, metric, span, config, or assertion facts with
  `ctx.recordCausal` until those services have automatic adapters.

The shortest useful query loop is:

```text
run effect -> inspect causal snapshot -> query lineage -> inspect cause
-> propose test or code fix
```

Attach and report with the public API:

```zig
var store = fx.CausalStore.init(allocator);
defer store.deinit();

var runtime = env.runtime().withCausalStore(&store);
const exit = runtime.exit(Program);
_ = exit;

const report = try fx.formatCausalCiReport(allocator, "program name", &store);
defer allocator.free(report);
```

For broader diagnosis, use:

```text
inspect failing run -> query cause -> query lineage -> inspect requirements
-> inspect resources -> inspect fibers -> inspect retries -> propose fix
```

The runnable example is
[`../examples/causal_readiness.zig`](../examples/causal_readiness.zig). It
starts a graph with config, logger, metrics, tracing, and a database-like
service, runs a readiness effect through a causal store, preserves
`error.MissingConfig` as a typed app failure, and prints `formatCausalReport`
plus `formatCausalJson`.

Use `formatCausalCiReport` when an agent or CI job needs a compact artifact:
it includes event counts, finding counts, citation ids, and recommended next
queries while avoiding raw `redacted_detail` payloads.

## Causal Dogfood Harness

Run the local dogfood harness before changing causal runtime behavior:

```sh
cd packages/zigeffect
zig build causal-test
```

The harness writes:

- `.zig-cache/causal-artifacts/zigeffect-causal-dogfood.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dogfood.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dogfood.dot`

Use the text report for finding summaries and next-query suggestions. Use the
JSON artifact when citing event ids in a fix proposal. Use the DOT artifact
when checking graph shape.

Before configuring local or CI retention, print the manifest:

```sh
zig build causal-artifacts
```

It lists the upload globs and known dogfood, scenario, and dev-loop artifacts.
Retain `.zig-cache/causal-artifacts/*.txt`, `.json`, and `.dot`; do not upload
the rest of `.zig-cache`. Treat JSON artifacts as the agent-readable source for
`causal-query`, compare, and advice tooling.

The first CI harness for this lane is
`.github/workflows/zigeffect-causal.yml`. On pull requests it captures exact
base-commit dogfood and package-test baseline JSON files, then prints the
manifest, runs `causal-test`, runs examples, runs `zig build test --summary
none`, and uploads only causal artifacts if the job fails. On failure it also
runs `zig build causal-ci-handoff`, which writes
`.zig-cache/causal-artifacts/zigeffect-causal-ci-verdict.json`,
`.zig-cache/causal-artifacts/zigeffect-causal-ci-handoff.txt`, and generated
`*-advice.txt` reports for existing JSON artifacts. Read the verdict JSON first
for aggregate action counts and the next recommended inspection step. When a
head artifact has a matching baseline, handoff also writes a `*-ci-compare.txt`
report and the advice report marks actions as `status=persisting` or
`status=new`.

Causal JSON artifacts are self-identifying:

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

The query, compare, and development-loop tools still accept older artifacts
that only contain `events`.

For longer-running local or CI probes, use a bounded store:

```zig
var store = fx.CausalStore.initBounded(allocator, 256);
defer store.deinit();
```

Queries only see retained events. If `dropped_events` is nonzero, cite the
retention metadata in the fix summary and avoid claiming the trace is complete.

For noisy probes, a causal store may also use opt-in deterministic sampling for
logs, metrics, and spans. If `sampled_events` is nonzero, cite that
observability evidence may be incomplete. Structural runtime evidence remains
unsampled unless it is later truncated by retention.

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

For incremental analysis, prefer JSONL rows from
`CausalJsonLinesBackendState` when you need to tail or split events. Treat each
row as an event fact, not as a complete store report. If sink failures are
nonzero, use the in-memory or full JSON artifact as the authoritative trace and
describe the JSONL stream as incomplete. Run `zig build causal-jsonl-backend`
for the focused adapter gate.

Use `CausalDotBackendState` when a local or CI harness wants graph output as
events are recorded. DOT backend output is an artifact builder: call `finish()`
before writing the buffer to a `.dot` file. Treat DOT as visual evidence for
humans and graph tools; use the full causal JSON artifact for agent queries,
schema metadata, retention, sampling, and truncation summaries. Run
`zig build causal-dot-backend` for the focused adapter gate.

Use `CausalOtelBackendState` when you need to inspect the runtime-to-OTel
mapping directly. Treat records as best-effort adapter sink output, not as the
source of truth. A record with complete `trace_id` and `span_id` is a
`span_event`; missing or incomplete context is a `log_record`. Cite the full
causal JSON artifact for retention, sampling, truncation, and backend-failure
metadata. Run `zig build causal-otel-backend` for the focused adapter gate.

Use `CausalGraphHistoryBackendState` when store retention may have dropped
ancestor or child events that an agent still needs for local cause and lineage
queries. Treat it as adapter sink history, not durable truth. If
`failedEventCount()` or `backendFailureCount()` is nonzero, cite the graph
history as incomplete and fall back to retained store or JSON artifact
evidence.

Use `CausalNendbStorageBackendState` when the work is specifically about the
NenDB storage adapter contract. It translates stored events into deterministic
NenDB-shaped event nodes and parent edges through `CausalNendbGraphWriter`.
Treat the writer output as sink evidence: if `failedEventCount()` or
`backendFailureCount()` is nonzero, cite the storage graph as incomplete and
fall back to retained store, graph-history, JSONL, or full JSON evidence. Run
`zig build causal-nendb-storage-backend` for the focused adapter gate.

Use `CausalAsyncStreamBackendState` when an agent needs incremental events from
a running local command but does not need durable history. `peekSnapshot`
returns a copy of the queued stream without mutating it; `drain` returns queued
events in order and clears the stream; `clear` discards queued events; `flush`
calls the optional sink flush hook. Treat the async stream as incomplete if
backend failures or dropped stream events are nonzero. Run
`zig build causal-async-stream-backend` for the focused adapter gate.

`event_taxonomy_version` identifies the event-kind role semantics. Version `1`
keeps sampleable observability disjoint from finding evidence: logs, metrics,
and spans may be sampled; service, scope, resource, fiber, schedule, and
assertion evidence must not be sampled.

If a query, compare, development-loop query report, or advice report warns that
the artifact schema is newer than supported, keep using event citations but
assume future root or event fields may have been ignored. If it warns that the
taxonomy is newer than supported, avoid strong claims about event-kind role
semantics until the tool is updated. If it warns about an unknown event kind,
the event id and raw fields are still usable, but query/advice/finding
interpretation may be incomplete for that kind.

Causal events also redact common secret and key-bound personal-data text before
storage: password-like fields, API keys, token keys, authorization and proxy
authorization headers, cookies, URL credentials, secret query parameters,
JSON-ish quoted keys, config-ish maps, SQL-ish key/value diagnostics, and
personal-data keys such as email, phone, IP address, SSN, address, and date of
birth become `<redacted>`. Treat this as a deterministic safety backstop. Do not
intentionally put secrets, prompts, request bodies, credentials, or personal
data into labels, statuses, type names, or details; app-facing adapters should
emit compact semantic diagnostics instead of raw payloads.

Use the non-failing probe when you want evidence:

```sh
zig build causal-test
```

Use the failure-gated check when causal findings should fail the development
loop:

```sh
zig build causal-check
```

The check still writes artifacts before failing, so inspect the JSON with
`causal-query` instead of rerunning blindly.

Inspect the registered scenario and invariant catalog before changing runtime
behavior:

```sh
zig build causal-catalog
```

Inspect the causal coverage matrix before proposing a new scenario or invariant:

```sh
zig build causal-test-matrix
```

If a failure belongs to a partial domain, first decide whether an existing
scenario or invariant should be tightened. Add a new scenario only when the
failure teaches a reusable runtime rule that should produce CI artifacts for
agents.

Use the real command capture fixture to prove that non-fixture command failures
leave scenario-specific artifacts:

```sh
zig build causal-capture-missing-service
```

Use the controlled package-test failure fixture to prove the package failure
artifact lane while keeping the real package gate green:

```sh
zig build causal-package-failure-fixture
```

This command runs an intentionally failing Zig test through the causal command
harness. It exits zero because the failure is expected and writes
`package-tests-failure-fixture` artifacts for query-based inspection.

Use the normal package-test gate while changing `zigeffect` internals:

```sh
zig build test
```

When package tests are green, the command exits zero. When they fail, it writes
`package-tests` causal artifacts before exiting nonzero. Use `zig build
test-raw` only when you need the unwrapped Zig test binary. `zig build
causal-dev-test` is an explicit alias for the same causal package-test harness.

Use the causal development loop when making runtime changes:

```sh
zig build causal-dev-loop -- baseline
```

Make the patch, then run:

```sh
zig build causal-dev-loop -- after
```

When the change touches a known subsystem, target its scenario:

```sh
zig build causal-dev-loop -- baseline causal-scoped-fiber
zig build causal-dev-loop -- after causal-scoped-fiber
```

The baseline phase stores the before artifact and runs package tests. The after
phase stores the after artifact, writes the compare report, writes an executed
query report, writes deterministic advice, writes a local verdict JSON, reruns
package tests, and prints the report paths. Expected failure scenarios, such as
`missing-service-compile-fail`, are treated as successful evidence when the
expected failure is observed. Read the `*-verdict.json` artifact first for
aggregate action counts and `next_action`, then inspect `*-advice.txt`,
`*-queries.txt`, and `*-compare.txt` for detailed event evidence before
proposing the next fix.

For normal core-runtime development, prefer the coordinated session command:

```sh
zig build causal-dev-session -- start
# edit source
zig build causal-dev-session -- assess
zig build causal-dev-session -- status
```

When the change touches a known subsystem, pass the scenario slug through the
whole session:

```sh
zig build causal-dev-session -- start causal-scoped-fiber
# edit source
zig build causal-dev-session -- assess causal-scoped-fiber
zig build causal-dev-session -- status causal-scoped-fiber
```

The session coordinator writes `*-dev-session.json` and `*-dev-session.txt`.
`start` captures the baseline. `assess` runs the after phase, local agent
handoff, diagnosis, remediation plan, and remediation audit, then stops before
review. It does not approve, apply, or edit source. Use
`causal-remediation-decision` only after review.

To turn the verdict into a deterministic local agent handoff, run:

```sh
zig build causal-dev-agent -- local
zig build causal-dev-agent -- local causal-scoped-fiber
```

The command reads the existing verdict artifact, prints the recommended
inspection order, and gives exact advice, query, and compare commands. It does
not rerun the loop or apply fixes.

To synthesize the verdict, advice, query, and compare reports into a patch-ready
local diagnosis, run:

```sh
zig build causal-diagnosis -- local
zig build causal-diagnosis -- local causal-scoped-fiber
```

The command writes `*-diagnosis.txt`, cites event ids from advice, summarizes
compare posture, and suggests patch categories without editing source.

To convert the diagnosis into a bounded, reviewable engineering plan, run:

```sh
zig build causal-remediation-plan -- local
zig build causal-remediation-plan -- local causal-scoped-fiber
```

The command writes `*-remediation-plan.md` with evidence ids, remediation
posture, proposed patch strategy, verification commands, and claim guardrails.
It does not edit source or execute remediation.

To record the remediation proposal before any approval or patch application,
run:

```sh
zig build causal-remediation-audit -- local
zig build causal-remediation-audit -- local causal-scoped-fiber
```

The command writes `*-remediation-audit.json` and `*-remediation-audit.txt`
with `approval_status=pending`, `applied=false`, source artifact paths, evidence
event ids, verification commands, and claim guardrails. Treat this audit record
as the review boundary before source edits or future policy-controlled
remediation.

To record a review decision for that audit without applying source changes, run:

```sh
zig build causal-remediation-decision -- local approve --by local-reviewer --policy manual-review
zig build causal-remediation-decision -- local reject causal-scoped-fiber --reason "clear verdict"
```

The command writes `*-remediation-decision.json` and
`*-remediation-decision.txt` with `approval_status=approved` or
`approval_status=rejected`, `applied=false`, the source audit path, copied event
ids, verification commands, claim guardrails, and decision guardrails. Approval
is permission for a future patch workflow only; it does not edit source or mark
anything applied.

To record the intended file-level patch without applying it, run:

```sh
zig build causal-patch-proposal -- local draft --summary "scope cleanup ordering" --file packages/zigeffect/src/core/scope.zig --change "tighten finalizer ordering evidence"
zig build causal-patch-proposal -- local approved causal-scoped-fiber --summary "scoped fiber evidence" --file packages/zigeffect/src/runtime/fiber.zig --change "record scoped fiber interruption evidence"
```

Draft proposals read pending audits and write `proposal_status=draft`,
`approval_status=pending`, `approved=false`, and `applied=false`. Approved
proposals require an approved remediation decision and write
`proposal_status=approved`, `approval_status=approved`, `approved=true`, and
`applied=false`. The command writes `*-patch-proposal.json` and
`*-patch-proposal.txt`; it never edits source or runs verification.

After a patch attempt and after-phase evidence exist, compare the full local
audit chain:

```sh
zig build causal-audit-chain -- local
zig build causal-audit-chain -- local causal-scoped-fiber
```

The command writes `*-audit-chain.json` and `*-audit-chain.txt` with schema
`zigeffect.causal.audit-chain.v1`. It reads the session, audit, optional
decision, patch proposal, before/after causal artifacts, and compare report. It
classifies proposal evidence ids as `disappeared`, `persisting`, `appeared`, or
`missing`, then assigns `assessment=improved|unchanged|regressed|inconclusive`.
Use this report before claiming a remediation worked. Persisting or missing
event ids mean the cited evidence is not resolved; appeared ids mean the patch
may have introduced new evidence. The command does not approve, apply, edit
source, or run verification.

After the audit chain exists, ask whether the evidence should become scenario
coverage:

```sh
zig build causal-scenario-proposal -- local
zig build causal-scenario-proposal -- local causal-scoped-fiber
```

The command writes `*-scenario-proposal.json` and
`*-scenario-proposal.txt` with schema
`zigeffect.causal.scenario-proposal.v1`. It reads the verdict, diagnosis,
remediation plan, and audit chain, then recommends `add-scenario`,
`refine-scenario`, or `none`. Treat it as a review prompt for scenario or
invariant coverage. It is read-only and does not edit `tools/causal_run.zig`.

To turn that proposal into a reviewable registry patch draft, run:

```sh
zig build causal-scenario-registry-patch -- --from-proposal .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-scenario-proposal.json
zig build causal-scenario-registry-patch -- --from-proposal .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-scenario-proposal.json
```

The command writes `*-registry-patch.json`, `*-registry-patch.txt`, and
`*-registry-patch.zig` with schema `zigeffect.causal.registry-patch.v1`. Review
the `.zig` snippet before manually applying anything to `tools/causal_run.zig`.
The generated argv is a placeholder until the reviewer replaces it with the
smallest reproducing command.

Before treating a registry patch as applicable, run the readiness gate:

```sh
zig build causal-registry-application-readiness -- --from-registry-patch .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-patch.json approve --reason "reviewed registry patch draft" --verified-command "zig build causal-run learned-dogfood-service-resolution" --verified-command "zig build examples"
zig build causal-registry-application-readiness -- --from-registry-patch .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-patch.json approve --reason "no registry patch applies"
```

The command writes `*-registry-application-readiness.json` and
`*-registry-application-readiness.txt` with schema
`zigeffect.causal.registry-application-readiness.v1`. It records the reviewer,
policy, decision, reason, verified commands, readiness checks, and
`readiness_status=applicable|blocked|not-applicable`. It verifies reviewer
approval, current registry state, placeholder argv replacement, invariant
catalog consistency, scenario docs, and required verification commands. It
never edits source or the scenario registry, and every report keeps
`applied=false`.

After readiness, record the application boundary:

```sh
zig build causal-registry-apply -- --from-readiness .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-application-readiness.json plan --reason "prepare manual registry application"
zig build causal-registry-apply -- --from-readiness .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-application-readiness.json record-applied --reason "registry and docs updated" --verified-command "zig build causal-run learned-dogfood-service-resolution" --verified-command "zig build examples" --verified-command "zig build test --summary none"
```

The command writes `*-registry-application.json` and
`*-registry-application.txt` with schema
`zigeffect.causal.registry-application.v1`. Use `plan` before manual source
application; it keeps `applied=false`. Use `record-applied` only after the
reviewed registry/docs update exists in source and after the verification
commands have been run; it sets `applied=true` only when source-state and
verification checks pass. The command records application state but does not
silently mutate source.

After the audit, proposal, audit-chain, and optional registry application
artifacts exist, record the advisory policy decision:

```sh
zig build causal-policy-decision -- local
zig build causal-policy-decision -- local causal-scoped-fiber
```

The command writes `*-policy-decision.json` and `*-policy-decision.txt` with
schema `zigeffect.causal.policy-decision.v1`. The default
`local-causal-self-improvement-v1` policy evaluates deterministic local
evidence and emits `approve`, `reject`, or `needs-human-review`. It never
applies source changes; every report keeps `applied=false` and
`mutation_authority=none`.

Generate advice directly from any saved causal JSON artifact:

```sh
zig build causal-advice -- --file .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json
zig build causal-advice -- --before .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json --file .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json
```

Advice is deterministic and non-mutating. It names event ids, why the event is
actionable, and exact `causal-query` commands. Single-artifact advice uses
`status=observed`. Before-aware advice uses `status=persisting` for evidence
that existed in the baseline and `status=new` for after-only evidence.

Run a specific scenario from the catalog when your change touches its owner:

```sh
zig build causal-run -- causal-scoped-fiber
```

Follow the report's next-query hints with:

```sh
zig build causal-query -- cause 3
zig build causal-query -- lineage 2
zig build causal-query -- resources 1
zig build causal-query -- fibers pending
zig build causal-query -- requirements 1
zig build causal-query -- retries 1
```

Use `zig build causal-query -- --file <path> <query> [argument]` when querying
an artifact from CI or a non-default harness run.

For the real missing-service compile-fail artifact:

```sh
zig build causal-query -- --file .zig-cache/causal-artifacts/zigeffect-causal-missing-service-compile-fail.json cause 3
```

Compare before and after artifacts after a runtime fix:

```sh
zig build causal-compare -- .zig-cache/causal-artifacts/before.json .zig-cache/causal-artifacts/after.json
```

Use the compare report to cite event deltas, finding deltas, added events,
removed events, and changed events in the patch summary.

This is the Phase 0 self-improving feedback lane: agents use `zigeffect`'s own
causal runtime as evidence while improving `zigeffect`, then rerun the harness
and package tests to compare behavior.

Use `zig build causal-artifacts` at the start of CI wiring or branch handoff to
make the artifact retention contract explicit before uploading or attaching
causal evidence.

When debugging a CI failure, start with the uploaded
`zigeffect-causal-ci-verdict.json` report. It gives the aggregate status, action
counts, and `next_action`. Then read `zigeffect-causal-ci-handoff.txt`; it names
the JSON artifacts that were present, points at generated `*-advice.txt`
reports, and prints exact `causal-query` commands for each one. On pull
requests it also names any base-commit baseline JSON artifact and generated
`*-ci-compare.txt` report, so new evidence can be separated from findings that
already existed on the base commit.

When a bug teaches a new runtime rule, run
`zig build causal-scenario-proposal -- local [scenario]` after the audit chain.
Then run `zig build causal-scenario-registry-patch -- --from-proposal <path>`
to generate review-only JSON/text/Zig patch drafts. Then run the readiness gate
and inspect the report before claiming the draft is applicable:

```sh
zig build causal-registry-application-readiness -- --from-registry-patch <registry-patch.json> approve|reject --reason <reason>
```

Then preserve the application boundary:

```sh
zig build causal-registry-apply -- --from-readiness <readiness.json> plan|record-applied --reason <reason>
```

Use these artifacts to review whether a catalog entry in `tools/causal_run.zig`
and documentation in `docs/causal-scenarios.md` should be added before claiming
the invariant is covered.

Backend adapters are sinks, not the source of truth. Keep tests and local agent
queries against the in-memory `CausalStore`; use `store.attachBackend` for
JSONL, DOT, OpenTelemetry, embedded graph, NenDB storage, or bounded async
adapters. Do not put NenDB or OpenTelemetry inside the deterministic core.

Future causal findings should be treated as evidence pointers, not conclusions.
An agent should cite event ids, explain whether an edge is causal or merely
correlated by trace context, and then propose a source, config, test, or runtime
policy change.

When a report contains findings, use this workflow:

```text
start with finding -> cite event id -> query lineage -> query cause
-> inspect scope/resource/fiber/retry evidence -> propose code or config fix
```

The most useful first scenario fixtures are:

- `../examples/causal_missing_config.zig`: missing config during layer startup
- `../examples/causal_cleanup_failure.zig`: cleanup failure after a typed
  program failure
- `../examples/causal_scoped_fiber.zig`: parent scope interrupting a child fiber
- `../examples/causal_retry_exhaustion.zig`: retry exhaustion masking the first
  typed failure
- app incident with trace context linking domain effect, service provider,
  resource scope, and schedule decisions

The intended result is that agents can improve `zigeffect` itself and apps built
with `zigeffect` from typed runtime evidence, not from guesses assembled from
stdout.

## Schedule Shape

```zig
var retry = fx.Schedule.jitteredBackoff(.{
    .max_retries = 5,
    .base_delay_ms = 25,
    .factor = 2,
    .max_delay_ms = 1_000,
    .jitter_ms = 50,
    .seed = 1,
});

const result = try Program.retry(&ctx, &retry);
```

For successful repetition:

```zig
var repeat = fx.Schedule.repeat(.{ .max_repeats = 2, .delay_ms = 10 });
const final = try Program.repeat(&ctx, &repeat);
```

For common retry names:

```zig
var once = fx.Schedule.once();
var recurs = fx.Schedule.recurs(3);
var spaced = fx.Schedule.spaced(.{ .max_retries = 3, .delay_ms = 25 });
var fibonacci = fx.Schedule.fibonacci(.{
    .max_retries = 5,
    .base_delay_ms = 25,
    .max_delay_ms = 1_000,
});
```

## Testing Pattern

```zig
test "program records telemetry" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    _ = try env.run(Program);

    try env.expectLog("running");
    try env.expectMetric("program.count", 1);
}
```

## Design Review Checklist

Before adding a public API, check:

- Does this still read like Zig?
- Can a user write the body with `try` instead of a combinator chain?
- Are errors statically typed?
- Does cleanup happen through `Runtime`/`Scope` instead of manual calls?
- If cleanup can fail, is it registered as a fallible finalizer?
- Does dependency startup happen through a `Layer` when ownership is not already
  clear?
- Do production effects declare service requirements?
- Do production layers/runtimes declare provided services?
- Is the layer graph validated before app startup?
- Can recovery be expressed with `catchAll`/`orElse` instead of scattered
  conditionals?
- Does cleanup that needs the program outcome use `onExit`, `ensuring`, or
  exit-aware scope finalizers?
- Does repeated/retried work use `Schedule` instead of a hand-rolled loop?
- Do missing services use `fx.serviceNotFound`?
- Do runtime reports use `formatExit`/`formatCause` when shown to users?
- Can `TestEnv` make the behavior deterministic?
- Can an LLM infer the correct usage from the README and tests?

If any answer is no, improve the API or docs before moving on.
