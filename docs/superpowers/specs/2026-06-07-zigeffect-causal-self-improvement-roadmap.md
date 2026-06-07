# zigeffect Causal Self-Improvement Roadmap

## Purpose

`zigeffect` should use its own causal runtime while `zigeffect` is being built.
The system starts as a local development harness, then becomes a development
agent feedback loop, then becomes the same agent-observable substrate for apps
built on top of `zigeffect`.

This roadmap turns the causal runtime branch into a sequence of concrete,
reviewable milestones. Each milestone should leave behind stable artifacts that
agents and humans can inspect before the next milestone begins.

## Current Baseline

The causal runtime branch and its local self-improvement slices have been
merged into `master`. The repository now contains:

- `CausalStore`, event ids, run ids, scope ids, and finding extraction.
- Text, JSON, and DOT formatters.
- `zig build causal-test`, which emits deterministic dogfood artifacts.
- `zig build causal-query -- <query> [argument]`, which lets agents inspect a
  saved causal JSON artifact without rerunning the scenario.
- `zig build causal-check`, which turns dogfood findings into an intentional
  nonzero local gate while preserving artifacts.
- `zig build causal-capture-missing-service`, which proves real command failure
  capture against the missing-service compile-fail fixture.
- `zig build causal-dev-test`, which runs package tests through the causal
  development wrapper and emits artifacts on failure.
- `zig build causal-catalog`, which exposes scenario ownership and invariant
  rules.
- `zig build causal-compare -- <before.json> <after.json>`, which compares
  saved causal artifacts.
- `zig build causal-advice -- --file <artifact>`, which turns saved causal
  evidence into deterministic, non-mutating next actions.
- `zig build causal-artifacts`, which prints deterministic upload globs and
  artifact retention guidance for agents and CI.
- `.github/workflows/zigeffect-causal.yml`, which runs the causal zigeffect
  harness in CI and uploads causal artifacts when the job fails.
- `zig build causal-ci-handoff`, which writes a first-read CI failure report
  with exact advice and query commands for uploaded JSON artifacts.
- generated CI `*-advice.txt` reports, produced from existing causal JSON
  artifacts by the same `causal_advice` engine used locally.
- CI baseline comparison, where pull request jobs capture exact base-commit
  dogfood and package-test JSON artifacts and use them to mark head advice as
  new or persisting evidence.
- local dev-loop verdict JSON artifacts, so after-phase runs have the same
  first-read structured status and action-count surface as CI failures.
- local development-agent, diagnosis, and remediation-plan commands, so agents
  can move from verdict to inspection order to patch-ready evidence without
  mutating source.
- `zig build causal-remediation-audit -- local [scenario]`, which adds the
  first durable proposal/audit artifact before any application command exists.
- `zig build causal-remediation-decision -- local approve|reject [scenario]`,
  which records approved or rejected review decisions while keeping
  `applied=false`.

The baseline proves that agents can cite causal evidence from `zigeffect`
itself in both local and CI workflows. The next step is to make that chain
ergonomic enough to use while building core `zigeffect`: a local
`causal-dev-session` coordinator should run the baseline/assessment sequence,
assemble the existing reports, and stop before review decisions or source
mutation.

## North Star

A development agent working on `zigeffect` should be able to:

1. Run a small causal check before and after changing runtime behavior.
2. Receive a failure report that names the scenario, event ids, findings, and
   suggested follow-up queries.
3. Query the saved artifact to inspect causes, children, resource state, fiber
   state, requirements, and retry decisions.
4. Compare before and after traces to justify whether a fix improved behavior.
5. Add new scenarios and invariants when a discovered issue teaches the runtime
   a new rule.
6. Reuse the same causal vocabulary later for applications built with
   `zigeffect`.

## Milestone Roadmap

### Milestone 0: Causal Runtime Foundation

Status: done.

Deliverables:

- deterministic in-memory causal event store;
- causal event taxonomy;
- finding extraction;
- text, JSON, and DOT artifact formatters;
- sample reports and scenario examples.

Exit criteria:

- core tests pass;
- examples compile and test;
- causal reports cite stable event ids.

### Milestone 1: Dogfood Artifact Lane

Status: done.

Deliverables:

- `zig build causal-test`;
- deterministic dogfood fixture with meaningful findings;
- `.zig-cache/causal-artifacts/zigeffect-causal-dogfood.{txt,json,dot}`;
- docs explaining how agents inspect artifacts.

Exit criteria:

- `zig build causal-test` exits zero and writes all artifacts;
- artifacts contain four intentional findings;
- package tests and examples remain green.

### Milestone 2: Artifact Query Lane

Status: done.

Deliverables:

- `zig build causal-query -- snapshot`;
- `zig build causal-query -- cause <event_id>`;
- `zig build causal-query -- lineage <event_id>`;
- `zig build causal-query -- resources <scope_id>`;
- `zig build causal-query -- fibers <status>`;
- `zig build causal-query -- requirements <run_id>`;
- `zig build causal-query -- retries <run_id>`;
- optional `--file <path>` for CI or non-default artifacts.

Exit criteria:

- agents can follow report next-query suggestions against saved JSON;
- query output preserves event ids and redacted details;
- bad arguments fail cleanly without Zig stack traces.

### Milestone 3: Failure-Gated Dogfood Check

Status: done.

Deliverables:

- `zig build causal-check`;
- `--fail-on-findings` mode for the dogfood harness executable;
- finding count carried alongside generated artifacts;
- concise output that makes failure intentional and artifact paths obvious.

Exit criteria:

- `zig build causal-test` still exits zero and writes artifacts;
- `zig build causal-check` writes the same artifacts and exits nonzero because
  the dogfood fixture has findings;
- unit tests prove the fail-on-findings exit decision;
- aggregate `zig build examples` does not depend on the intentionally failing
  check.

Why this comes before full test wrapping:

- It validates build-step failure semantics using stable artifacts.
- It gives agents a real nonzero causal check immediately.
- It avoids conflating fixture findings with real test failures before the
  scenario registry and artifact naming rules exist.

Delivered:

- `zig build causal-check` writes the dogfood artifacts and exits nonzero when
  findings are present;
- `causal-test` remains the non-failing evidence command;
- the intentionally failing check is excluded from aggregate examples.

### Milestone 4: Real Test Failure Capture

Status: first real command-capture slice delivered.

Deliverables:

- a wrapper for selected `zig build test` scenarios;
- artifact names that include the owning scenario or suite;
- failure reports that distinguish fixture findings from failing-test findings;
- nonzero exits only when configured checks fail.

Exit criteria:

- a selected failing core scenario leaves causal artifacts automatically;
- agents can answer "which scenario failed and why" from the report alone;
- query helper can inspect both fixture artifacts and real failure artifacts.

Delivered slices:

- `zig build causal-capture-missing-service` captures artifacts for the existing
  `missing_service.zig` compile-fail fixture;
- `zig build causal-dev-test` runs package tests through a causal wrapper and
  emits `package-tests` artifacts if the command fails;
- failed `assertion_recorded` events now surface as causal findings.

### Milestone 5: Scenario Registry And Invariant Catalog

Status: first registry/catalog slice delivered.

Deliverables:

- named causal scenarios for runtime subsystems;
- an invariant catalog that maps finding types to runtime rules;
- docs for adding a scenario when a bug teaches a new causal invariant;
- stable artifact naming by scenario.

Exit criteria:

- each scenario has an owner, purpose, expected findings policy, and artifact
  path;
- new runtime bugs can become regression scenarios without duplicating harness
  logic.

Delivered first slice:

- `zig build causal-catalog` prints registered scenarios and invariant rules;
- `causal_run.zig` stores scenario owner, purpose, finding policy, artifact
  paths, and invariant ids;
- existing causal examples are registered as quiet-on-success scenarios.

### Milestone 6: Before/After Trace Comparison

Status: first compare slice delivered.

Deliverables:

- `causal-compare` or equivalent helper for two JSON artifacts;
- added, removed, and changed event summaries;
- finding count deltas;
- concise "fix improved behavior" report.

Exit criteria:

- a development agent can cite before and after event ids;
- changes that only rewrite formatting do not masquerade as runtime fixes;
- comparison output is stable enough for CI artifacts.

Delivered first slice:

- `zig build causal-compare -- <before.json> <after.json>`;
- finding deltas recomputed from saved JSON artifacts;
- added, removed, and changed event summaries.

Remaining:

- automated capture of before and after artifacts around selected scenarios;
- optional persisted compare reports under `.zig-cache/causal-artifacts/`;
- scenario-aware labels so reports can say which invariant improved.

### Milestone 7: Development Agent Loop And Remediation Control

Status: dev-loop, local agent handoff, diagnosis, remediation planning, and
remediation audit delivered.

Deliverables:

- a local command that runs causal checks, package tests, and selected queries;
- an agent-readable summary with next actions;
- optional before/after trace capture around a patch;
- docs for how an agent should use causal evidence before proposing a fix.
- non-mutating remediation-control artifacts that show proposal, approval
  status, evidence ids, verification commands, and claim guardrails.

Exit criteria:

- an agent can run one development loop and produce a grounded patch summary;
- failed checks always point at artifacts, event ids, and suggested queries;
- the loop does not require network or external services.

Delivered slices:

- `zig build causal-dev-loop -- baseline`;
- `zig build causal-dev-loop -- after`;
- stable before, after, and compare artifact paths;
- package-test gate execution in both phases;
- after-phase summary with compare output and report paths;
- scenario-specific before/after command artifacts for registered scenarios;
- expected-failure scenario handling with `expected_failure_observed` status.
- automatic `causal-query` report artifacts selected from after-artifact
  evidence.
- deterministic `causal-advice` reports that name event ids, explain bounded
  next actions, and print exact follow-up query commands.
- before-aware advice statuses for `observed`, `persisting`, and `new`
  evidence in after-phase development loop reports.
- local `zigeffect-causal-dev-loop-verdict.json` and scenario-specific
  `zigeffect-causal-dev-loop-<scenario>-verdict.json` reports that summarize
  action counts, baseline pairing, and the next inspection step.
- `zig build causal-dev-agent -- local [scenario]`, which reads local verdicts
  and prints the deterministic next inspection plan for development agents.
- `zig build causal-diagnosis -- local [scenario]`, which summarizes verdict,
  advice, query, and compare artifacts into a patch-ready non-mutating
  diagnosis report.
- `zig build causal-remediation-plan -- local [scenario]`, which turns local
  diagnosis artifacts into non-mutating remediation plans with evidence ids,
  verification commands, and claim guardrails.
- `zig build causal-remediation-audit -- local [scenario]`, which writes
  pending-approval JSON and text audit records citing the local verdict,
  diagnosis, remediation plan, advice, query, compare artifacts, evidence event
  ids, verification commands, and claim guardrails.
- `zig build causal-remediation-decision -- local approve|reject [scenario]`,
  which writes append-only approved or rejected decision records while keeping
  source edits and patch application out of scope.
- `zig build causal-dev-session -- start|assess|status [scenario]`, which
  coordinates baseline capture, after assessment, local agent handoff,
  diagnosis, remediation planning, and remediation audit into one repeatable
  local development harness without approval or source mutation.

Remaining:

- add an optional patch-proposal artifact that can describe a source edit diff
  while still requiring human or policy approval;
- add a policy engine that can produce policy-backed decision records;
- compare before/after audit chains so a development agent can show whether a
  proposed remediation reduced, preserved, or introduced causal findings;
- app-facing development loops once applications emit causal runtime artifacts.

Active next slice:

- `zig build causal-patch-proposal -- local draft|approved [scenario] ...`
  creates the first patch-intent artifact without applying source changes;
- draft proposals are explicitly unapproved and read pending audits;
- approved proposals read approved decisions and still record `applied=false`;
- detailed design:
  `docs/superpowers/specs/2026-06-07-zigeffect-causal-patch-proposal-design.md`;
- implementation plan:
  `docs/superpowers/plans/2026-06-07-zigeffect-causal-patch-proposal.md`.

#### Remediation-Control Roadmap

This sub-roadmap is the concrete path from "agent can inspect evidence" to
"agent can safely participate in improving zigeffect":

1. **Audit record.** Use `causal-remediation-audit` to create deterministic
   pending proposal artifacts. No source edits, no approvals, no timestamps.
2. **Approval boundary.** Use `causal-remediation-decision` to append an audit
   decision with reviewer, policy id, and rationale. Still no patch application.
3. **Patch proposal artifact.** Add `causal-patch-proposal` so agents can write
   draft or approved patch-intent artifacts linked to audit evidence, decision
   evidence, event ids, guardrails, and required verification commands.
4. **Remediation workbench loop.** Let agents compare audit/proposal outcomes
   before and after a patch, including which event ids disappeared, persisted,
   or appeared.
5. **App-facing reuse.** Reuse the same verdict, diagnosis, plan, audit,
   approval, and proposal vocabulary for apps built with `zigeffect`.

Safety invariant: each step must produce a reviewable artifact before the next
step is allowed to mutate anything. The causal runtime can propose and explain;
authorization and edits remain separate until the policy layer exists.

### Milestone 8: Hardening And CI Readiness

Status: schema-versioning, bounded-store, redaction, sampling, taxonomy, and
artifact-retention slices delivered.

Deliverables:

- bounded store or ring-buffer policy; first opt-in bounded retention slice
  delivered through `CausalStore.initBounded`;
- stronger secret redaction tests; first defensive store-time redaction slice
  delivered;
- event sampling rules;
- stable schema versioning for JSON artifacts; delivered for
  `zigeffect.causal.v1` root metadata;
- compatibility tests for event taxonomy changes;
- artifact retention and upload guidance.

Exit criteria:

- artifacts are safe to emit by default in CI;
- schema changes are explicit and tested;
- memory growth is bounded under long-running traces.

Delivered first slice:

- generated causal JSON artifacts include
  `"schema": "zigeffect.causal.v1"` and `"schema_version": 1`;
- query, compare, and development-loop tools continue to parse legacy
  event-only artifacts.
- `CausalStore.initBounded` retains at most the configured event count while
  preserving monotonic event ids;
- reports and JSON artifacts disclose `max_events`, `dropped_events`, and
  `oldest_retained_event_id`.
- causal store redacts common secret-shaped key/value details, bearer token
  values, and URL credentials before storage and backend emission.
- event sampling rules are explicit for logs, metrics, and spans, while
  structural and finding-evidence events remain unsampled.
- event taxonomy metadata and warnings make compatibility changes explicit.
- `zig build causal-artifacts` prints upload globs and dogfood, scenario, and
  dev-loop artifact paths so CI can retain causal evidence without uploading
  the rest of `.zig-cache`.
- `.github/workflows/zigeffect-causal.yml` runs the manifest, dogfood harness,
  examples, and causal package-test gate in CI, then uploads causal `.txt`,
  `.json`, and `.dot` artifacts on failure.
- `zig build causal-ci-handoff` writes
  `.zig-cache/causal-artifacts/zigeffect-causal-ci-handoff.txt`, and CI runs it
  on failure before upload so agents have a first-read report.
- CI handoff generates `*-advice.txt` reports for existing JSON artifacts, so
  the uploaded bundle contains deterministic advice before local reruns.
- pull request CI captures base-commit dogfood and package-test baseline JSON
  artifacts, and handoff uses matching baselines to write compare reports plus
  `status=persisting` or `status=new` advice.
- CI handoff writes `zigeffect-causal-ci-verdict.json`, a structured first-read
  verdict with aggregate action counts and the recommended next inspection
  step.

Remaining:

- physical ring-buffer optimization if ordered drop-oldest retention becomes a
  bottleneck;
- broader PII/payload redaction policy beyond deterministic secret-shaped
  strings;
- deeper compatibility fixtures for future taxonomy changes.

### Milestone 9: App-Facing Agent Runtime

Status: planned after core development loop proves itself.

Deliverables:

- app request/job trace adapters;
- app-level incident mapping for service, layer, scope, resource, fiber, and
  retry findings;
- durable history and OpenTelemetry adapters after deterministic semantics are
  stable;
- human/policy gates for remediation proposals.

Exit criteria:

- agents can reason about apps built with `zigeffect` using the same causal
  vocabulary used to build the runtime;
- app-facing traces remain redacted, bounded, and queryable.

## Planning Sessions

### Session 1: Failure-Gated Dogfood Review

Run before merging Milestone 3.

Review:

- command naming: `causal-test` versus `causal-check`;
- whether finding count belongs in `ArtifactSet`;
- failure output wording;
- whether examples should continue building the executable but not the failing
  step.

### Session 2: Real Failure Capture Review

Run before Milestone 4.

Review:

- which test scenarios should be wrapped first;
- artifact naming for real failing scenarios;
- whether wrapper logic belongs in Zig, Bun scripts, or both;
- how to prevent fixture findings from being mistaken for regression findings.

### Session 3: Scenario Registry Review

Run before Milestone 5.

Review:

- scenario naming conventions;
- invariant naming and severity;
- ownership boundaries between runtime modules and tools;
- how new bug reports become causal regression scenarios.

### Session 4: Hardening Review

Run before Milestone 8.

Review:

- bounded memory policy;
- redaction policy and tests;
- JSON schema versioning;
- CI artifact retention;
- sampling rules.

### Session 5: Remediation-Control Review

Run before implementing patch proposal commands.

Review:

- audit schema ergonomics and whether fields are enough for policy review;
- whether proposal records should be append-only or regenerated locally;
- how to represent human approval, local policy approval, and rejection;
- how to cite source diffs without letting causal tools mutate source;
- how the same audit vocabulary will work for app-facing incident remediation.

### Session 6: Dev Session Coordinator Review

Run before implementing `causal-dev-session`.

Review:

- command names and whether `start`, `assess`, and `status` are enough;
- which commands the coordinator may run automatically;
- missing-baseline and command-failure semantics;
- session schema fields and artifact names;
- confirming that `assess` should create a remediation audit automatically
  after the remediation plan.

## Delivered Slice Decisions

The Milestone 7 remediation-control chain has two delivered non-mutating
review slices:

```sh
zig build causal-remediation-audit -- local [scenario]
zig build causal-remediation-decision -- local approve|reject [scenario]
```

The audit command creates a durable, schema-versioned, pending proposal record.
The decision command records the human or local-review outcome while preserving
`applied=false`. Together they give zigeffect a safe self-improvement control
point: agents can cite event ids, source artifacts, verification commands,
claim guardrails, and review state before any source-editing workflow is added.

The next branch should not jump straight to patch application. It should build
the `causal-dev-session` coordinator so agents can run the whole evidence chain
reliably during ordinary core runtime development.
