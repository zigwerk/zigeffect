# zigeffect Causal Rollout Automation Guardrails Design

Date: 2026-06-10

## Purpose

This branch defines the first record-only rollout guardrails contract for
zigeffect production hardening. The previous branch delivered the human-agent
feedback loop. The next useful production slice is to describe canary,
progressive rollout, circuit-breaker, and rollback readiness evidence without
granting automated rollout authority.

The branch should make rollout advice inspectable by humans and agents while
keeping all execution outside zigeffect authority. It should answer:

- what evidence is required before canary exposure is considered;
- what evidence allows a canary to progress, hold, rollback, or escalate;
- what circuit-breaker triggers must be reviewed;
- what rollback readiness evidence must exist before a rollout is called safe;
- what attempts must be rejected because they imply unreviewed automation.

Mutation authority remains `none`.

## Existing Evidence

The handoff comes from:

- `packages/zigeffect/tools/causal_production_hardening_backlog.zig`, which
  names `codex/zigeffect-causal-rollout-automation-guardrails` as the current
  recommended branch;
- `packages/zigeffect/docs/production-hardening-backlog.md`, which says this
  branch should define canary, gradual rollout, circuit-breaker, and rollback
  evidence records without granting automated mutation authority;
- `packages/zigeffect/tools/causal_production_deployment_runbooks.zig`, which
  already defines manual deploy, rollback, verification, and incident runbooks;
- `packages/zigeffect/tools/causal_alerting_integrations.zig`, which already
  defines record-only alert, ticket, SIEM, and paging preview contracts;
- `packages/zigeffect/tools/causal_human_agent_feedback_loop.zig`, which links
  failures, bounded agent queries, before/after comparison, guarded handoffs,
  and future NenDB history handoff;
- existing app application readiness and application records, which define how
  app changes can be planned or recorded after external reviewed application.

## Design Brief

- Product: deterministic rollout evidence contract for zigeffect production
  hardening.
- Command: `zig build causal-rollout-automation-guardrails`.
- Schema: `zigeffect.causal.rollout-automation-guardrails.v1`.
- Work mode: local, deterministic, record-only.
- Consumes:
  - `zigeffect.causal.production-deployment-runbooks.v1`;
  - `zigeffect.causal.alerting-integrations.v1`;
  - `zigeffect.causal.human-agent-feedback-loop.v1`;
  - app or registry application records when they already exist.
- Produces:
  - canary evidence record contract;
  - rollout progression gate contract;
  - circuit-breaker decision contract;
  - rollback readiness gate contract;
  - negative automation fixtures.
- Mutation authority: `none`.

## In Scope

- Add a deterministic report tool:

  ```sh
  zig build causal-rollout-automation-guardrails
  zig build causal-rollout-automation-guardrails -- --format json
  ```

- Emit text and JSON reports.
- Model the following record families:
  - canary evidence;
  - rollout progression gate;
  - circuit-breaker decision;
  - rollback readiness gate;
  - negative automation fixture.
- Register the schema in schema governance.
- Mark the production-hardening backlog item delivered.
- Hand off to `codex/zigeffect-causal-wall-clock-benchmark-baselines`.
- Add docs and operations guidance.

## Out Of Scope

- Automated deploy execution.
- Automated rollback execution.
- Feature-flag mutation.
- Traffic-shift mutation.
- Config mutation.
- Source mutation.
- App mutation.
- Registry mutation.
- Alert, ticket, SIEM, or page delivery.
- Durable writes.
- Non-NenDB durable adapter work.
- React workbench support.
- Live production telemetry ingestion.

## Architecture

This branch follows the same static-report pattern as the production hardening
contracts:

```text
deployment runbooks
  + alerting integrations
  + human-agent feedback loop
  + optional app or registry application record
  -> rollout automation guardrails report
```

The report is a policy and evidence contract. Later branches can add dynamic
input parsing, live integrations, or production host support behind separate
reviewed boundaries. This branch should not inspect clocks, networks, live
traffic, deployment systems, feature flag providers, queues, dashboards, or
databases.

## Output Schema

Schema:

```text
zigeffect.causal.rollout-automation-guardrails.v1
```

Top-level fields:

```json
{
  "schema": "zigeffect.causal.rollout-automation-guardrails.v1",
  "schema_version": 1,
  "producer": "causal-rollout-automation-guardrails",
  "mode": "local-record",
  "applied": false,
  "mutation_authority": "none",
  "source_branch": "codex/zigeffect-causal-rollout-automation-guardrails",
  "source_contracts": [],
  "rollout_controls": [],
  "canary_evidence_records": [],
  "progression_gates": [],
  "circuit_breaker_decisions": [],
  "rollback_readiness_gates": [],
  "negative_automation_fixtures": [],
  "guardrails": [],
  "verification_commands": [],
  "next_branch": "codex/zigeffect-causal-wall-clock-benchmark-baselines"
}
```

## Record Families

### Canary Evidence Record

Purpose: describe the minimum evidence needed before a candidate receives
limited exposure.

Required fields:

- candidate artifact or app application ref;
- rollout owner;
- human approval ref;
- target service or app boundary;
- baseline causal artifact;
- canary scope and exposure ceiling;
- redaction review state;
- alert routing preview;
- rollback owner;
- rollback readiness ref;
- verification command refs.

The canary record cannot shift traffic. It only says which evidence would be
required before an external rollout system is allowed to proceed.

### Rollout Progression Gate

Purpose: describe how humans and agents evaluate whether to progress, hold,
rollback, or escalate.

Gate decisions:

- `progression-blocked`: default when evidence is missing;
- `hold-for-review`: evidence is partial or concerning;
- `ready-for-external-progression`: evidence is complete, but execution remains
  external;
- `rollback-review-required`: circuit-breaker or verification evidence requires
  rollback review;
- `escalation-review-required`: alerting policy requires human escalation.

Required evidence:

- baseline and canary comparison refs;
- causal-query event ids;
- alert preview refs;
- human reviewer;
- rollout owner;
- rollback owner;
- policy reason.

### Circuit-Breaker Decision

Purpose: model a reviewed decision to hold, rollback, or escalate based on
causal and alert evidence.

Trigger inputs:

- increased finding count;
- new critical finding kind;
- failed deployment runbook gate;
- failed app verification command;
- critical alert preview;
- missing rollback owner;
- redaction or access-control denial.

Decision outputs:

- `observe`;
- `hold`;
- `rollback-review`;
- `escalate`;
- `blocked`.

The decision is advisory. It cannot stop traffic, rollback a release, send a
page, or mutate a feature flag.

### Rollback Readiness Gate

Purpose: require rollback evidence before a rollout can be considered safe.

Required fields:

- last-good artifact or external release record;
- rollback owner;
- human rollback reviewer;
- rollback reason template;
- rollback verification commands;
- after-rollback causal verification refs;
- external rollback record ref, when rollback actually happened.

The gate should distinguish:

- `not-ready`;
- `ready-for-external-rollback`;
- `external-rollback-recorded`;
- `blocked`.

### Negative Automation Fixtures

Purpose: make forbidden automation attempts testable.

Initial fixtures:

- unreviewed canary progression;
- missing baseline artifact;
- missing rollback owner;
- critical alert without human approval;
- redaction not reviewed;
- attempt to mutate traffic or feature flags;
- attempt to claim rollback applied without an external rollback record.

Each fixture should record a blocked decision, failed gate, and reason.

## Human And Agent Workflow

Humans use the report to review the rollout posture:

```sh
zig build causal-rollout-automation-guardrails
```

Agents use JSON to decide what evidence is missing:

```sh
zig build causal-rollout-automation-guardrails -- --format json
```

The next commands are advisory examples:

```sh
zig build causal-production-deployment-runbooks -- --format json
zig build causal-alerting-integrations -- --format json
zig build causal-human-agent-feedback-loop -- --format json
zig build causal-compare -- <baseline.json> <canary.json>
```

The report should never be used as direct approval to roll out. Progression,
traffic shifts, deploys, and rollback execution stay in external reviewed
systems.

## Documentation Changes

Add:

- `packages/zigeffect/docs/rollout-automation-guardrails.md`.

Update:

- `packages/zigeffect/docs/operations.md`;
- `packages/zigeffect/docs/production-hardening-backlog.md`;
- `packages/zigeffect/docs/roadmap.md`;
- `packages/zigeffect/docs/schema-governance.md`;
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`.

## Tests And Verification

New tests:

- usage names `causal-rollout-automation-guardrails`;
- format parser accepts text and JSON;
- unknown format fails closed;
- text report includes schema, applied=false, mutation authority none, canary,
  progression, circuit breaker, rollback readiness, and negative fixtures;
- JSON report includes the schema and all record families;
- report consumes deployment runbooks and alerting integrations;
- report references the human-agent feedback-loop schema;
- report includes `next_branch` set to
  `codex/zigeffect-causal-wall-clock-benchmark-baselines`;
- negative fixtures block unreviewed automation attempts;
- report contains no live delivery or mutation authority.

Focused verification:

```sh
zig test tools/causal_rollout_automation_guardrails.zig
zig build causal-rollout-automation-guardrails
zig build causal-rollout-automation-guardrails -- --format json
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

Full branch verification:

```sh
zig build examples
zig build test
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
bun run check
bun run zig:test
git diff --check
```

## Acceptance Criteria

- The new command emits stable text and JSON reports.
- Schema governance registers
  `zigeffect.causal.rollout-automation-guardrails.v1`.
- The production hardening backlog marks `rollout-automation-guardrails`
  delivered and recommends
  `codex/zigeffect-causal-wall-clock-benchmark-baselines`.
- Docs explain canary evidence, progression gates, circuit-breaker decisions,
  rollback readiness, and negative automation fixtures.
- Mutation authority remains `none`.
- No rollout, deploy, rollback, feature flag, alert, ticket, page, source,
  config, app, registry, or durable mutation is introduced.
