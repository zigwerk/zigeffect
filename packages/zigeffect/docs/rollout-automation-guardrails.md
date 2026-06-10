# Rollout Automation Guardrails

`causal-rollout-automation-guardrails` is the deterministic, record-only
contract for canary, gradual rollout, circuit-breaker, and rollback readiness
evidence.

It emits `zigeffect.causal.rollout-automation-guardrails.v1`.

```sh
zig build causal-rollout-automation-guardrails
zig build causal-rollout-automation-guardrails -- --format json
```

The report does not deploy, roll back, shift traffic, mutate feature flags,
send alerts, create tickets, page humans, edit source, update registries, change
apps, or write durable history. It always keeps:

```text
applied=false
mutation_authority=none
```

## Source Contracts

The rollout guardrails report consumes the existing record-only contracts:

- `zigeffect.causal.production-deployment-runbooks.v1`;
- `zigeffect.causal.alerting-integrations.v1`;
- `zigeffect.causal.human-agent-feedback-loop.v1`.

It can cite app readiness or application records when they already exist, but
it cannot apply app changes or infer external rollout state.

## Canary Evidence

A canary record describes the minimum evidence required before limited external
exposure is considered:

- candidate artifact or app application ref;
- baseline causal artifact;
- canary causal artifact;
- rollout owner;
- human reviewer;
- target service or app boundary;
- exposure ceiling;
- alert preview;
- rollback owner;
- rollback readiness ref;
- verification commands.

The canary record does not shift traffic. It only tells humans and agents which
evidence must exist before an external rollout system can proceed.

## Progression Gates

Progression gates separate advice from execution:

- `progression-blocked`: required evidence is missing;
- `hold-for-review`: evidence is partial or concerning;
- `ready-for-external-progression`: evidence is complete, but execution remains
  external;
- `rollback-review-required`: verification or circuit-breaker evidence requires
  rollback review;
- `escalation-review-required`: alerting policy requires human escalation.

Agents should cite the gate id, missing evidence, reviewer, and reason. They
must not claim traffic progressed unless an external reviewed rollout record
exists.

## Circuit Breakers

Circuit-breaker decisions are advisory records over causal and alert evidence.
Initial triggers include:

- new critical finding kind;
- finding count increase against baseline;
- failed deployment runbook gate;
- failed app verification command;
- critical alert preview;
- missing rollback owner;
- redaction or access-control denial.

Decisions include `observe`, `hold`, `rollback-review`, `escalate`, and
`blocked`. None of them stops traffic or rolls back a release by itself.

## Rollback Readiness

Rollback readiness must exist before a rollout is called safe:

- last-good artifact or external release record;
- rollback owner;
- human rollback reviewer;
- rollback reason template;
- rollback verification commands;
- after-rollback causal verification refs;
- external rollback record ref, when rollback actually happened.

The report distinguishes `not-ready`, `ready-for-external-rollback`,
`external-rollback-recorded`, and `blocked`.

## Negative Fixtures

The report includes blocked fixtures for forbidden automation attempts:

- unreviewed canary progression;
- missing baseline artifact;
- missing rollback owner;
- critical alert without human approval;
- redaction not reviewed;
- traffic mutation attempt;
- rollback applied without an external rollback record.

These fixtures keep the contract honest: the tool proves what must be blocked,
not only what a happy path would look like.

## Agent Rules

Agents consuming the JSON report should:

- treat it as an evidence checklist;
- cite the deployment runbook, alerting, and feedback-loop source contracts;
- run `causal-compare` on baseline and canary artifacts before recommending
  progression;
- preserve human reviewer, rollout owner, rollback owner, and reason fields;
- block progression when any required evidence is missing;
- require external reviewed rollout or rollback records before claiming applied
  state.

Agents must not:

- shift traffic;
- mutate feature flags;
- deploy or roll back services;
- send alerts, create tickets, forward SIEM events, or page humans;
- edit source, config, app code, registry entries, or durable state;
- treat this report as rollout approval.

## Verification

Focused checks:

```sh
zig test tools/causal_rollout_automation_guardrails.zig
zig build causal-rollout-automation-guardrails
zig build causal-rollout-automation-guardrails -- --format json
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

Full branch checks:

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
