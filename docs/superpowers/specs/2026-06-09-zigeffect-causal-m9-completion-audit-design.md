# zigeffect Causal M9 Completion Audit Design

Date: 2026-06-09

## Purpose

This branch formally audits the M9 production operating-model milestone for the
zigeffect causal self-improvement runtime. M9 now has schema governance,
operations documentation, performance budgets, release guidance, CI handoff
ownership, artifact retention rules, and explicit production gaps. The missing
piece is a deterministic completion artifact that proves those surfaces exist,
names the verification commands, and records which remaining items are
intentional future production hardening rather than unfinished M9 work.

The audit should let a development agent answer:

- Is M9 ready to move from `active` to `delivered` in the roadmap?
- Which files and commands prove each M9 deliverable?
- Which production gaps remain intentionally deferred?
- What verification must pass before a maintainer trusts the completion claim?

## Current Evidence

The current branch stack provides these M9 operating-model surfaces:

- `zig build causal-schema-governance`
  - Emits `zigeffect.causal.schema-governance.v1`.
  - Lists 32 current schema families after the performance-budget branch.
  - Documents versioning, migration, compatibility, producers, consumers, and
    schema-change requirements.
- `packages/zigeffect/docs/schema-governance.md`
  - Human-readable schema governance manual.
- `packages/zigeffect/docs/operations.md`
  - Local/CI operations manual.
  - Defines authority boundaries, command map, CI failure handoff, artifact
    retention, redaction review, guarded application, workbench operation,
    backend operations, scenario governance, schema governance, performance
    budget, release review, and production gaps.
- `zig build causal-performance-budget`
  - Emits `zigeffect.causal.performance-budget.v1`.
  - Checks app request/job retention, app string bounds, workbench artifact
    size, and documents sampling, CI artifact retention, backend sink posture,
    and SolidJS inside `webui-dev/zig-webui`.
- `packages/zigeffect/docs/performance-budget.md`
  - Defines release-note criteria and verification commands.
- `.github/workflows/zigeffect-causal.yml`
  - Owns package CI for causal artifacts.
  - Runs causal manifest, dogfood artifacts, examples, package tests, and
    failure handoff.
  - Uploads only causal `.txt`, `.json`, and `.dot` artifacts for 14 days.
  - Uses read-only contents permissions.
- `zig build causal-artifacts`
  - Prints artifact upload/retention manifest.
- `zig build causal-test-matrix`
  - Prints causal scenario/invariant coverage.

## Chosen Approach

Add a deterministic `zig build causal-m9-completion-audit` report.

The report will be a local operating-model audit artifact, not a production
monitor. It should follow the current tool pattern:

- default text output for humans;
- `--format json` output for agents;
- tests for option parsing, deliverable inventory, gap inventory, text output,
  and JSON output;
- build wiring so the tool tests run under `zig build test`;
- schema-governance registration;
- docs and roadmap updates.

The new schema family should be:

```text
zigeffect.causal.m9-completion-audit.v1
```

The report should recommend that M9 can be marked `delivered` only when the
listed verification suite has passed in the current branch or merged target.

## Audit Model

The report should contain these groups.

### Deliverable Checks

Each deliverable check should include:

- `id`
- `status`
- `evidence`
- `command` or `file`
- `agent_guidance`

Initial deliverables:

- `schema-governance-tool`
- `schema-governance-doc`
- `operations-manual`
- `performance-budget-tool`
- `performance-budget-doc`
- `release-guidance`
- `ci-workflow`
- `artifact-manifest`
- `test-matrix`
- `workbench-direction`
- `production-gap-register`

Statuses should be plain strings such as `passed`, `documented`, and
`deferred-intentional`.

### Verification Commands

The report should list the commands required before M9 is trusted:

```sh
cd packages/zigeffect
zig build causal-m9-completion-audit
zig build causal-m9-completion-audit -- --format json
zig build causal-schema-governance
zig build causal-performance-budget
zig build causal-artifacts
zig build causal-test-matrix
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

### Production Gaps

The report should list production gaps as intentional future hardening:

- distributed artifact aggregation;
- durable production retention beyond local files and CI uploads;
- production deployment runbooks;
- alerting, paging, Slack, Linear, Jira, or SIEM integrations;
- RBAC or access control over artifact bundles;
- encryption-at-rest policy;
- live dashboards or streaming workbench;
- automated source/config mutation authority;
- gradual rollout, canary, or circuit-breaker automation;
- wall-clock benchmark baselines or gates;
- production capacity planning.

The recommendation should be:

```text
deliver-m9-with-deferred-production-hardening
```

This means the original M0-M9 roadmap can move forward, while future production
operating integrations remain explicit backlog rather than silent scope creep.

## Documentation Changes

Add `packages/zigeffect/docs/m9-completion-audit.md` with:

- command usage;
- deliverable inventory;
- interpretation rules;
- production gap register;
- verification suite;
- roadmap update rule.

Update:

- `packages/zigeffect/README.md`
- `packages/zigeffect/docs/operations.md`
- `packages/zigeffect/docs/schema-governance.md`
- `packages/zigeffect/docs/roadmap.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

The master roadmap should move M9 to `delivered` only after the audit command
and full verification suite pass on this branch.

## Non-Goals

This branch does not add:

- production artifact aggregation;
- durable production retention;
- deployment runbook automation;
- alerting or paging integrations;
- RBAC or encryption-at-rest;
- live dashboarding;
- streaming workbench;
- mutation authority;
- rollout automation;
- wall-clock benchmark gates;
- production capacity planning;
- React workbench support;
- Cockroach adapter work.

## Success Criteria

The branch is successful when:

- `zig build causal-m9-completion-audit` prints the text audit.
- `zig build causal-m9-completion-audit -- --format json` prints
  `zigeffect.causal.m9-completion-audit.v1`.
- `zig build test` runs the audit tool tests.
- schema governance lists the new audit schema.
- docs explain how to interpret `deliver-m9-with-deferred-production-hardening`.
- the master roadmap marks M9 as delivered after verification passes.
- the immediate branch queue moves from completion audit to future production
  hardening/backlog triage.
