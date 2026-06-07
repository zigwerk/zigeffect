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

The causal runtime branch has been merged into `master`, and the current
development branch contains:

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

The baseline proves that agents can cite causal evidence from `zigeffect`
itself. The next step is to automate before/after capture around the scenario
registry and package-test development loop.

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

### Milestone 7: Development Agent Loop

Status: first dev-loop slice delivered.

Deliverables:

- a local command that runs causal checks, package tests, and selected queries;
- an agent-readable summary with next actions;
- optional before/after trace capture around a patch;
- docs for how an agent should use causal evidence before proposing a fix.

Exit criteria:

- an agent can run one development loop and produce a grounded patch summary;
- failed checks always point at artifacts, event ids, and suggested queries;
- the loop does not require network or external services.

Delivered first slice:

- `zig build causal-dev-loop -- baseline`;
- `zig build causal-dev-loop -- after`;
- stable before, after, and compare artifact paths;
- package-test gate execution in both phases;
- after-phase summary with compare output and next-query commands.
- scenario-specific before/after command artifacts for registered scenarios;
- expected-failure scenario handling with `expected_failure_observed` status.

Remaining:

- automatic execution of selected query helpers based on changed findings;
- app-facing development loops once applications emit causal runtime artifacts.

### Milestone 8: Hardening And CI Readiness

Status: planned.

Deliverables:

- bounded store or ring-buffer policy;
- stronger secret redaction tests;
- event sampling rules;
- stable schema versioning for JSON artifacts;
- compatibility tests for event taxonomy changes;
- artifact retention and upload guidance.

Exit criteria:

- artifacts are safe to emit by default in CI;
- schema changes are explicit and tested;
- memory growth is bounded under long-running traces.

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

## First Slice Decision

The first implementation slice is Milestone 3: failure-gated dogfood check.

It intentionally does not wrap real tests yet. The goal is to prove the local
failure semantics, artifact writing guarantees, and agent workflow using the
existing deterministic dogfood scenario. Once that is stable, real failing-test
capture can reuse the same exit policy and documentation shape.
