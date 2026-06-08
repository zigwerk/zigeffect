# Causal Scenarios

The causal scenario registry is the local map that tells agents what zigeffect
development checks exist, which subsystem owns each one, what invariant the
scenario protects, and where failure artifacts will be written.

## Commands

Print the scenario and invariant catalog:

```sh
zig build causal-catalog
```

Print the scenario coverage matrix:

```sh
zig build causal-test-matrix
```

Run a registered scenario:

```sh
zig build causal-run -- <scenario>
```

Run the current package-test development gate:

```sh
zig build test
```

Capture the expected missing-service compile-fail scenario:

```sh
zig build causal-capture-missing-service
```

Capture the expected package-test failure fixture:

```sh
zig build causal-package-failure-fixture
```

Compare two saved causal JSON artifacts:

```sh
zig build causal-compare -- <before.json> <after.json>
```

Name an existing causal JSON artifact with a snapshot manifest:

```sh
zig build causal-snapshot -- capture <name> [scenario]
zig build causal-snapshot -- manifest <name> <artifact.json> --format text
zig build causal-snapshot -- compare <left> <right>
zig build causal-snapshot -- replay-feasibility <snapshot>
```

Snapshot compare reads existing snapshot manifests and their referenced causal
JSON artifacts. It does not rerun scenarios or make replay feasible; use it to
summarize named-state deltas before querying event-level evidence.

Replay feasibility also reads existing artifacts only. It does not rerun
scenarios, replay effects, or fork runtime state; it explains why the current
snapshot remains `feasible: false` and which event categories block replay.

Run the two-phase causal development loop:

```sh
zig build causal-dev-loop -- baseline
zig build causal-dev-loop -- after
```

Run the coordinated local development session:

```sh
zig build causal-dev-session -- start [scenario]
zig build causal-dev-session -- assess [scenario]
zig build causal-dev-session -- status [scenario]
```

Print the next local agent inspection plan from a saved dev-loop verdict:

```sh
zig build causal-dev-agent -- local [scenario]
```

Write a patch-ready local diagnosis from saved dev-loop artifacts:

```sh
zig build causal-diagnosis -- local [scenario]
```

Write a reviewable remediation plan from saved dev-loop artifacts:

```sh
zig build causal-remediation-plan -- local [scenario]
```

Record a pending remediation proposal audit from saved dev-loop artifacts:

```sh
zig build causal-remediation-audit -- local [scenario]
```

Record an approved or rejected review decision for the audit:

```sh
zig build causal-remediation-decision -- local approve|reject [scenario] [--reason <reason>]
```

Record a non-mutating patch proposal from audit or approved decision evidence:

```sh
zig build causal-patch-proposal -- local draft [scenario] --summary <summary> --file <path> --change <description>
zig build causal-patch-proposal -- local approved [scenario] --summary <summary> --file <path> --change <description>
```

Compare the current session, audit, decision, proposal, before/after artifacts,
and compare report:

```sh
zig build causal-audit-chain -- local [scenario]
```

Propose whether the resulting evidence should become reviewed scenario or
invariant coverage:

```sh
zig build causal-scenario-proposal -- local [scenario]
```

Generate review-only registry patch artifacts from a scenario proposal:

```sh
zig build causal-scenario-registry-patch -- --from-proposal <scenario-proposal.json>
```

This writes schema `zigeffect.causal.registry-patch.v1` as JSON plus text and
Zig review drafts. The generated Zig snippet never changes
`tools/causal_run.zig`; replace its placeholder argv with the smallest
reproducing command before applying a registry entry manually.

Check whether a reviewed registry patch is ready to apply manually:

```sh
zig build causal-registry-application-readiness -- --from-registry-patch <registry-patch.json> approve --reason "reviewed registry patch draft" --verified-command "zig build examples"
```

This writes schema `zigeffect.causal.registry-application-readiness.v1` as JSON
plus text. The report records the reviewer decision, readiness status,
per-check pass/fail/skipped details, verified commands, and guardrails. It
never edits `tools/causal_run.zig` and always records `applied=false`.

Record the registry application boundary:

```sh
zig build causal-registry-apply -- --from-readiness <registry-application-readiness.json> plan --reason "prepare manual registry application"
zig build causal-registry-apply -- --from-readiness <registry-application-readiness.json> record-applied --reason "registry and docs updated" --verified-command "zig build examples"
```

This writes schema `zigeffect.causal.registry-application.v1` as JSON plus
text. `plan` records manual application steps with `applied=false`.
`record-applied` records `applied=true` only after current source state and
verification command evidence pass. The command records state; it does not
silently edit source.

Record the advisory policy decision:

```sh
zig build causal-policy-decision -- local [scenario]
```

This writes schema `zigeffect.causal.policy-decision.v1` as JSON plus text.
The default local policy can recommend `approve`, `reject`, or
`needs-human-review`, but it always records `mutation_authority=none` and
`applied=false`.

Generate deterministic advice from a saved causal JSON artifact:

```sh
zig build causal-advice -- --file <artifact.json>
zig build causal-advice -- --before <before.json> --file <after.json>
```

Print the causal artifact retention manifest:

```sh
zig build causal-artifacts
```

The repository CI workflow `.github/workflows/zigeffect-causal.yml` runs the
manifest, dogfood harness, examples, and causal package-test gate, then uploads
causal artifacts on failure. On pull requests it first captures exact
base-commit dogfood and package-test baseline JSON artifacts so the failure
handoff can compare head evidence against the PR base. It also runs `zig build
causal-ci-handoff` on failure so the uploaded bundle contains
`.zig-cache/causal-artifacts/zigeffect-causal-ci-verdict.json` and
`.zig-cache/causal-artifacts/zigeffect-causal-ci-handoff.txt`.

## Registered Scenarios

- `missing-service-compile-fail`
  Owner: `service_resolution`
  Purpose: prove missing service diagnostics become causal command evidence.
- `package-tests`
  Owner: `package`
  Purpose: run the broad zigeffect test suite with causal failure capture.
- `package-tests-failure-fixture`
  Owner: `package`
  Purpose: prove package-shaped test failures write causal command artifacts
  without breaking the real package gate.
- `causal-scoped-fiber`
  Owner: `fiber_runtime`
  Purpose: verify scoped fiber interruption causal examples stay healthy.
- `causal-retry-exhaustion`
  Owner: `schedule_retry`
  Purpose: verify retry exhaustion causal examples stay healthy.
- `causal-cleanup-failure`
  Owner: `scope_lifecycle`
  Purpose: verify cleanup failure causal examples stay healthy.
- `causal-missing-config`
  Owner: `service_resolution`
  Purpose: verify missing config causal examples stay healthy.
- `causal-readiness`
  Owner: `observability`
  Purpose: verify app-shaped readiness, graph startup, and observability causal
  examples stay healthy.

Each scenario has stable artifact paths under `.zig-cache/causal-artifacts/`.
Passing scenarios may write no runner failure artifact; failing scenarios write
text, JSON, and DOT artifacts before the command exits.

## Coverage Matrix

`zig build causal-test-matrix` reports causal scenario coverage by runtime
domain. The matrix is a deterministic view over `tools/causal_run.zig`, so it
does not become a second scenario registry.

Statuses mean:

- `covered`: at least one scenario and invariant or structural assertion gives
  direct evidence for the domain.
- `partial`: the domain has useful evidence but still needs a named invariant,
  dedicated scenario, or tighter assertion before it is complete.
- `missing`: no scenario declares the domain yet.

Current domains:

| Domain | Status | Primary Evidence |
| --- | --- | --- |
| service | covered | `missing-service-compile-fail`, `causal-missing-config`, `causal-readiness` |
| layer | covered | `causal-missing-config`, `causal-readiness`, layer graph causal tests |
| scope | covered | `causal-cleanup-failure`, `causal-scoped-fiber` |
| fiber | covered | `causal-scoped-fiber`, fiber runtime causal tests |
| schedule | covered | `causal-retry-exhaustion`, schedule decision tests |
| config | partial | `causal-missing-config`, `causal-readiness`; needs a named config invariant |
| resource | covered | `causal-cleanup-failure`, `causal-readiness`, runtime resource tests |
| retry | covered | `causal-retry-exhaustion`, retry decision tests |
| cause | partial | cleanup/runtime tests; needs a dedicated cause invariant |
| observability | covered | `causal-readiness`, `observability-events-are-sampleable` |

Run the matrix before proposing a new scenario. If the failing behavior belongs
to a partial domain, prefer tightening the existing scenario or invariant before
adding a duplicate fixture.

Use `zig build causal-artifacts` when configuring CI or handing work to another
agent. It lists the upload globs, dogfood artifacts, scenario artifacts, and
scenario dev-loop paths. Retain `.txt` for human triage, `.json` for
`causal-query`, compare, and advice tooling, and `.dot` for graph visualization.
Do not upload the rest of `.zig-cache`.

CI uses the same boundary: only `.txt`, `.json`, and `.dot` files under
`packages/zigeffect/.zig-cache/causal-artifacts/` are uploaded.
Read `zigeffect-causal-ci-verdict.json` first for aggregate action counts and
the next recommended inspection step. Then read
`zigeffect-causal-ci-handoff.txt`; it points at the JSON artifacts and exact
local commands for advice and query follow-up. On pull requests, paired
artifacts also include a base JSON path, generated compare report, and
baseline-aware advice that marks actions as `status=persisting` or `status=new`.

## Invariants

- `resource-finalized-after-acquire`
  Every `resource_acquired` event must have a matching `resource_finalized`
  event in the same scope.
- `scoped-fiber-must-finish-before-scope-close`
  Scoped fibers must complete, join, or interrupt before their owning scope
  closes.
- `finalizer-failures-are-causal-evidence`
  Finalizer failures must be preserved in the causal graph.
- `retry-exhaustion-is-recorded`
  Retry schedules must record exhaustion decisions.
- `service-requirement-has-provider`
  Required services must have matching providers or explicit missing-service
  diagnostics.
- `command-failure-is-causal-evidence`
  Development command failures must emit assertion findings with scenario
  context.
- `package-tests-are-development-gate`
  The package test suite remains the broad local regression gate.
- `observability-events-are-sampleable`
  Log, metric, and span causal events are sampleable observability evidence, not
  finding evidence.

## Adding A Scenario From A Bug

When a zigeffect bug reveals a new runtime rule:

1. Add or identify the smallest command that reproduces the behavior.
2. Add a scenario entry in `tools/causal_run.zig` with owner, purpose, expected
   finding policy, invariant ids, and argv.
3. Add an invariant entry if the bug teaches a new rule.
4. Run `zig build causal-catalog` and confirm the scenario appears.
5. Run `zig build causal-run -- <scenario>` before and after the fix.
6. Query any failure artifact with `zig build causal-query -- --file <path>
   <query>`.
7. Compare before and after artifacts with `zig build causal-compare --
   <before.json> <after.json>`.

The scenario should describe the runtime invariant, not merely the symptom that
happened to fail first.

### Failure Graduation Guide

Keep a failure as an ordinary unit test when the behavior is local,
deterministic, and does not teach a reusable runtime causality rule.

Add a causal assertion to an existing test when the behavior already has a
`CausalStore` and the invariant is local to that test, such as an event
sequence, event parent id, scope id, fiber id, trace id, or finding count.

Add a scenario when the bug crosses a service, layer, scope, fiber, schedule,
resource, config, cause, retry, or observability boundary and should produce
artifacts that agents can inspect in CI.

Add a new invariant when the rule should be named, queried, and reused across
multiple scenarios or findings.

## Comparing Before And After

Use comparison after a fix when the claim is about runtime behavior, not just
source code shape. Capture a before artifact from the smallest relevant
scenario, apply the fix, capture the after artifact, then run:

```sh
zig build causal-compare -- <before.json> <after.json>
```

The report is intentionally text-first for agents. It shows event count deltas,
finding count deltas, added events, removed events, and changed events. A good
patch summary should cite the comparison and the event ids that explain the
behavior change.

## Development Loop

Use the development loop for ordinary runtime patches. Run the baseline phase
before editing, then run the after phase once the patch is in place:

```sh
zig build causal-dev-loop -- baseline
zig build causal-dev-loop -- after
```

For targeted runtime work, pass a registered scenario slug:

```sh
zig build causal-dev-loop -- baseline causal-scoped-fiber
zig build causal-dev-loop -- after causal-scoped-fiber
```

The no-scenario loop compares the deterministic dogfood causal artifact and
runs the `package-tests` scenario as the package gate. The loop writes the
first six artifacts; `causal-diagnosis` writes the diagnosis artifact from that
saved bundle; `causal-remediation-plan` writes the remediation-plan artifact;
`causal-remediation-audit` writes pending proposal audit artifacts;
`causal-remediation-decision` writes approved or rejected decision artifacts.
`causal-patch-proposal` writes non-mutating proposal artifacts.
`causal-audit-chain` writes chain comparison artifacts.
`causal-scenario-proposal` writes read-only scenario learning proposal
artifacts.
`causal-scenario-registry-patch` writes review-only registry patch artifacts.
`causal-registry-application-readiness` writes review readiness artifacts for
registry patch drafts.
`causal-registry-apply` writes registry application boundary artifacts.
`causal-policy-decision` writes advisory policy decision artifacts.
`causal-dev-session` writes the session wrapper artifacts:

- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-plan.md`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-decision.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-decision.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-patch-proposal.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-patch-proposal.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-audit-chain.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-audit-chain.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-scenario-proposal.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-scenario-proposal.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-patch.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-patch.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-patch.zig`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-application-readiness.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-application-readiness.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-application.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-application.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-policy-decision.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-policy-decision.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-session.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-session.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-snapshot-baseline.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-snapshot-baseline.txt`

Scenario loops compare command-level artifacts for the selected scenario and
write slug-specific loop artifacts. `causal-diagnosis` and
`causal-remediation-plan` add matching follow-up artifacts;
`causal-remediation-audit` adds matching pending audit artifacts;
`causal-remediation-decision` adds matching decision artifacts.
`causal-patch-proposal` adds matching proposal artifacts.
`causal-audit-chain` adds matching chain comparison artifacts.
`causal-scenario-proposal` adds matching scenario learning proposal artifacts.
`causal-scenario-registry-patch` adds matching registry patch artifacts.
`causal-registry-application-readiness` adds matching review readiness
artifacts.
`causal-registry-apply` adds matching registry application boundary artifacts.
`causal-policy-decision` adds matching advisory policy decision artifacts.
`causal-dev-session` adds matching session wrapper artifacts:

- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-before.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-after.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-compare.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-queries.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-advice.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-verdict.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-diagnosis.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-remediation-plan.md`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-remediation-audit.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-remediation-audit.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-remediation-decision.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-remediation-decision.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-patch-proposal.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-patch-proposal.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-audit-chain.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-audit-chain.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-scenario-proposal.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-scenario-proposal.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-registry-patch.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-registry-patch.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-registry-patch.zig`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-registry-application-readiness.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-registry-application-readiness.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-registry-application.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-registry-application.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-policy-decision.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-policy-decision.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-session-<scenario>.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-session-<scenario>.txt`

The `*-queries.txt` artifact contains executed `causal-query` output selected
from the after artifact's evidence events. The `*-advice.txt` artifact contains
deterministic next actions derived from those same events. Advice is
non-mutating: it prints exact follow-up commands instead of applying fixes. Loop
after-phase advice is before-aware, so unchanged evidence is marked
`status=persisting` and after-only evidence is marked `status=new`.
The `*-verdict.json` artifact is the first file agents should read after an
after-phase run. It summarizes aggregate action counts, baseline pairing, and
the recommended next inspection step.
After an after-phase run, `zig build causal-dev-agent -- local [scenario]`
reads the matching verdict and prints the deterministic local inspection plan.
Use it before manually opening advice, query, or compare artifacts.
For ordinary development, `zig build causal-dev-session -- start [scenario]`
captures the baseline and `zig build causal-dev-session -- assess [scenario]`
runs the after phase plus local agent handoff, diagnosis, remediation plan, and
remediation audit. `status` reprints the latest session text. The session
coordinator never approves, applies, or edits source.
Then run `zig build causal-diagnosis -- local [scenario]` when the agent needs a
patch-ready, non-mutating diagnosis that cites advice event ids, query output,
and compare posture.
Then run `zig build causal-remediation-plan -- local [scenario]` when the agent
needs an implementation plan with evidence ids, verification commands, and claim
guardrails. The plan is non-mutating and should be reviewed before source edits.
Then run `zig build causal-remediation-audit -- local [scenario]` to record the
proposal bundle with pending approval status and `applied=false` before source
edits or future policy-controlled remediation.
Then run `zig build causal-remediation-decision -- local approve|reject
[scenario] ...` to record the review outcome while keeping `applied=false`.
Then run `zig build causal-patch-proposal -- local draft|approved [scenario]
--summary <summary> --file <path> --change <description>` to record the
intended source change without applying it. Draft proposals are unapproved and
read pending audits. Approved proposals require an approved decision. Both modes
keep `applied=false` and never edit source.
Then run `zig build causal-audit-chain -- local [scenario]` after the
before/after evidence and proposal exist. The command writes an audit-chain
JSON/text report that classifies proposal evidence ids as disappeared,
persisting, appeared, or missing and assigns an overall assessment of
`improved`, `unchanged`, `regressed`, or `inconclusive`. Treat it as evidence
for patch claims, not permission to edit source.
Then run `zig build causal-scenario-proposal -- local [scenario]` when the
audit chain shows persisting, new, or regressed evidence. The command writes a
JSON/text proposal that recommends `add-scenario`, `refine-scenario`, or
`none`, carries event ids and guardrails forward, and remains read-only.
Then run `zig build causal-scenario-registry-patch -- --from-proposal <path>`
to produce JSON/text/Zig registry patch drafts. The generated `.zig` snippet is
for review only. Run the readiness gate before treating the draft as ready:

```sh
zig build causal-registry-application-readiness -- --from-registry-patch <registry-patch.json> approve|reject --reason <reason>
```

Then record the application boundary:

```sh
zig build causal-registry-apply -- --from-readiness <registry-application-readiness.json> plan|record-applied --reason <reason>
```

Then record the advisory policy decision:

```sh
zig build causal-policy-decision -- local [scenario]
```

The draft remains unapplied until a reviewer updates `tools/causal_run.zig`,
runs verification, and records a passing `record-applied` report.

Expected-failure scenarios are valid loop targets. For example,
`missing-service-compile-fail` reports `expected_failure_observed` when the
compile failure occurs as intended.

If package tests fail, the loop writes the same `package-tests` failure
artifacts as the default `zig build test` causal wrapper and exits nonzero.
Use `zig build test-raw` only when debugging the unwrapped package-test binary;
`zig build causal-dev-test` remains an explicit alias for the causal wrapper.

Use `zig build causal-package-failure-fixture` when an agent needs to prove the
package failure capture lane itself. It writes:

- `.zig-cache/causal-artifacts/zigeffect-causal-package-tests-failure-fixture.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-package-tests-failure-fixture.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-package-tests-failure-fixture.dot`
