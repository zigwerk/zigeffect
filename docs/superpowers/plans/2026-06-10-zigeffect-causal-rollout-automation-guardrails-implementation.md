# zigeffect Causal Rollout Automation Guardrails Implementation Plan

Date: 2026-06-10

Spec:
`docs/superpowers/specs/2026-06-10-zigeffect-causal-rollout-automation-guardrails-design.md`

Branch:
`codex/zigeffect-causal-rollout-automation-guardrails`

## Objective

Deliver a deterministic, record-only rollout automation guardrails contract for
zigeffect production hardening.

The branch should describe canary evidence, rollout progression gates,
circuit-breaker decisions, rollback readiness gates, and negative automation
fixtures without executing deployment, rollback, traffic, feature-flag, alert,
ticket, page, source, config, app, registry, or durable mutation.

## Success Criteria

- `zig build causal-rollout-automation-guardrails` prints a human-readable
  report.
- `zig build causal-rollout-automation-guardrails -- --format json` prints
  `zigeffect.causal.rollout-automation-guardrails.v1`.
- The report includes:
  - `applied=false`;
  - `mutation_authority=none`;
  - deployment runbooks as a source contract;
  - alerting integrations as a source contract;
  - human-agent feedback loop as a source contract;
  - canary evidence records;
  - progression gates;
  - circuit-breaker decisions;
  - rollback readiness gates;
  - negative automation fixtures.
- Schema governance includes the new schema.
- Production hardening backlog marks `rollout-automation-guardrails` delivered
  and recommends `codex/zigeffect-causal-wall-clock-benchmark-baselines`.
- Docs teach how to use the record without granting rollout authority.
- Full verification passes.

## Non-Goals

- No automated deploy execution.
- No automated rollback execution.
- No traffic-shift mutation.
- No feature-flag mutation.
- No source, config, app, registry, alert, ticket, page, SIEM, or durable
  mutation.
- No live production telemetry ingestion.
- No non-NenDB durable adapter work.
- No React workbench support.

## Test-Driven Implementation

### Red Phase

Create `packages/zigeffect/tools/causal_rollout_automation_guardrails.zig` with
tests that fail until the parser and report builders exist.

Required tests:

1. Constants preserve the branch boundary:
   - schema is `zigeffect.causal.rollout-automation-guardrails.v1`;
   - schema version is `1`;
   - source branch is
     `codex/zigeffect-causal-rollout-automation-guardrails`;
   - next branch is `codex/zigeffect-causal-wall-clock-benchmark-baselines`.

2. Usage and parser:
   - usage names `causal-rollout-automation-guardrails`;
   - default format is text;
   - `--format text` works;
   - `--format json` works;
   - unknown format fails closed;
   - missing format fails closed;
   - unknown flag fails closed.

3. Text report:
   - includes schema;
   - includes `applied: false`;
   - includes `mutation authority: none`;
   - includes source contracts;
   - includes canary evidence, progression gates, circuit breakers, rollback
     readiness, and negative automation fixtures;
   - includes next branch.

4. JSON report:
   - includes schema and schema version;
   - includes `mode=local-record`;
   - includes `applied=false`;
   - includes `mutation_authority=none`;
   - includes source contracts;
   - includes all record-family arrays;
   - includes negative fixtures that block unreviewed automation attempts;
   - includes next branch.

Expected early failing command:

```sh
zig test tools/causal_rollout_automation_guardrails.zig
```

### Green Phase

Implement the smallest deterministic tool that satisfies the tests:

1. Add static structs:
   - `RolloutControl`;
   - `CanaryEvidenceRecord`;
   - `ProgressionGate`;
   - `CircuitBreakerDecision`;
   - `RollbackReadinessGate`;
   - `NegativeAutomationFixture`.
2. Implement `--format text|json`.
3. Emit top-level `applied=false` and `mutation_authority=none`.
4. Include source schemas:
   - `zigeffect.causal.production-deployment-runbooks.v1`;
   - `zigeffect.causal.alerting-integrations.v1`;
   - `zigeffect.causal.human-agent-feedback-loop.v1`.
5. Add build module, executable, build step, and tests in
   `packages/zigeffect/build.zig`.
6. Register schema governance entry.
7. Update production hardening backlog recommendation and status.

### Refactor Phase

After focused tests pass:

- simplify repeated JSON helpers only if the file becomes noisy;
- keep dynamic input parsing out of this branch;
- keep the report deterministic and clock/network-free;
- keep names aligned across tests, docs, schema governance, and backlog.

## File Plan

Create:

- `packages/zigeffect/tools/causal_rollout_automation_guardrails.zig`;
- `packages/zigeffect/docs/rollout-automation-guardrails.md`.

Modify:

- `packages/zigeffect/build.zig`;
- `packages/zigeffect/tools/causal_schema_governance.zig`;
- `packages/zigeffect/tools/causal_production_hardening_backlog.zig`;
- `packages/zigeffect/docs/schema-governance.md`;
- `packages/zigeffect/docs/operations.md`;
- `packages/zigeffect/docs/production-hardening-backlog.md`;
- `packages/zigeffect/docs/roadmap.md`;
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`.

Optional cleanup if already touching cited lines:

- replace stale `packages/zigeffect/tools/causal_app_application.zig` evidence
  references with the existing app readiness/app application tools;
- replace stale non-NenDB durable adapter wording in older production-hardening
  docs when it is directly adjacent to rollout text.

## Report Records

### Source Contracts

```zig
const source_contracts: []const []const u8 = &.{
    "zigeffect.causal.production-deployment-runbooks.v1",
    "zigeffect.causal.alerting-integrations.v1",
    "zigeffect.causal.human-agent-feedback-loop.v1",
};
```

### Rollout Controls

Initial controls:

- `external-rollout-only`;
- `human-progression-review`;
- `bounded-canary-exposure`;
- `causal-baseline-required`;
- `alert-preview-required`;
- `rollback-owner-required`.

### Canary Evidence Records

Initial records:

- `candidate-canary-evidence`;
- `app-boundary-canary-evidence`.

These should require candidate artifact refs, baseline refs, owner/reviewer,
exposure ceiling, alert preview, rollback owner, and verification commands.

### Progression Gates

Initial gates:

- `progression-blocked`;
- `hold-for-review`;
- `ready-for-external-progression`;
- `rollback-review-required`;
- `escalation-review-required`.

### Circuit-Breaker Decisions

Initial decisions:

- `observe`;
- `hold`;
- `rollback-review`;
- `escalate`;
- `blocked`.

Triggers should include finding deltas, critical finding kinds, failed runbook
gates, critical alert previews, missing rollback owners, and redaction/access
denials.

### Rollback Readiness Gates

Initial gates:

- `not-ready`;
- `ready-for-external-rollback`;
- `external-rollback-recorded`;
- `blocked`.

### Negative Automation Fixtures

Initial fixtures:

- `unreviewed-canary-progression`;
- `missing-baseline-artifact`;
- `missing-rollback-owner`;
- `critical-alert-without-human-approval`;
- `redaction-not-reviewed`;
- `traffic-mutation-attempt`;
- `rollback-applied-without-external-record`.

## Documentation Tasks

`rollout-automation-guardrails.md` should include:

- command quick start;
- what the schema means;
- source contracts;
- canary evidence workflow;
- progression gate workflow;
- circuit-breaker workflow;
- rollback readiness workflow;
- negative fixture explanation;
- agent rules;
- non-goals;
- verification commands.

`schema-governance.md`

- Add the rollout guardrails schema to the production-hardening schema list.

`operations.md`

- Add the command near the production-hardening hardening contracts.

`production-hardening-backlog.md`

- Mark rollout guardrails delivered and hand off to wall-clock benchmark
  baselines.

`roadmap.md`

- Add the delivered milestone summary.

Master roadmap

- Mark rollout guardrails delivered and set wall-clock benchmark baselines as
  the current next branch.

## Verification Sequence

Focused:

```sh
zig test tools/causal_rollout_automation_guardrails.zig
zig build causal-rollout-automation-guardrails
zig build causal-rollout-automation-guardrails -- --format json
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

Full:

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

## Commit Plan

Commit 1:

```text
docs(zigeffect): plan rollout automation guardrails
```

Commit 2:

```text
feat(zigeffect): add rollout automation guardrails contract
```

Commit 3, only if docs need a separate review slice:

```text
docs(zigeffect): document rollout automation guardrails
```
