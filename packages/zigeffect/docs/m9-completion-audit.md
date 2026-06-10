# zigeffect Causal M9 Completion Audit

`causal-m9-completion-audit` is the deterministic completion report for the
zigeffect causal operating-model milestone. It records the evidence that M9 has
schema governance, operations docs, performance budgets, release guidance, CI
artifact ownership, and an explicit production-gap register.

## Command

```sh
cd packages/zigeffect
zig build causal-m9-completion-audit
zig build causal-m9-completion-audit -- --format json
```

The default text report is for human review. The JSON report uses schema
`zigeffect.causal.m9-completion-audit.v1` for agent-readable roadmap and
release checks.

## Deliverable Checks

The audit records deliverables for:

- schema governance tool and docs;
- operations manual;
- performance budget tool and docs;
- release guidance;
- causal CI workflow;
- artifact manifest;
- causal test matrix;
- SolidJS inside `webui-dev/zig-webui` workbench direction;
- production-gap register.

Use `status=passed` for command-backed evidence and `status=documented` for
documentation-backed evidence. The audit does not execute all listed commands;
the verification suite below still needs to run before a maintainer trusts the
roadmap update.

## Recommendation

`deliver-m9-with-deferred-production-hardening` means the M0-M9 causal
self-improvement roadmap is complete for local/CI operating-model purposes, and
the listed production gaps move to future production hardening instead of
blocking M9.

It does not mean the runtime has production dashboards, durable production
retention, access control, or mutation authority.

## Deferred Production Gaps At M9

The audit originally kept these as explicit future hardening:

- distributed artifact aggregation;
- durable production retention beyond local files and CI uploads;
- alerting, paging, Slack, Linear, Jira, or SIEM integrations, with
  record-only alerting now delivered and live delivery still future;
- RBAC or access control over artifact bundles;
- encryption-at-rest policy, implementation, and key rotation;
- live dashboards or streaming workbench at M9 time, with the local
  live-dashboard stream and workbench slice now delivered and production
  ingestion still future;
- automated source/config mutation authority;
- gradual rollout, canary, or circuit-breaker automation;
- wall-clock benchmark baselines or gates;
- production capacity planning at M9 time, with the record-only planning
  contract now delivered and telemetry, load-test execution, and reviewed
  production sizing still future.

No Cockroach adapter work is part of this audit. The current durable database
direction remains NenDB adapter work only.

## Production-Hardening Handoff

After the M9 audit passes, run the production-hardening backlog report to
choose the next branch:

```sh
cd packages/zigeffect
zig build causal-production-hardening-backlog
zig build causal-production-hardening-backlog -- --format json
```

That report uses schema
`zigeffect.causal.production-hardening-backlog.v1`, keeps durable work on the
NenDB adapter path, keeps workbench work on SolidJS inside
`webui-dev/zig-webui`, and now recommends
`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy`
after the production artifact aggregation, durable production retention, production
deployment runbook, artifact access-control contract, unified causal spine
contract, deep runtime internals, app semantic tracing, bounded agent query,
record-only encryption-at-rest policy, record-only alerting integration, live
dashboard streaming workbench, graph visual debugging, human-agent feedback
loop, rollout guardrails, wall-clock benchmark baselines, capacity planning,
completion audit, load-test observation, production telemetry evidence, CI
artifact preview, CI harness boundary, CI archive application, CI archive
evidence policy, and CI gate readiness branches.

## Verification Suite

Run the full suite before using the audit to mark M9 delivered:

```sh
cd packages/zigeffect
zig build causal-m9-completion-audit
zig build causal-m9-completion-audit -- --format json
zig build causal-schema-governance
zig build causal-performance-budget
zig build causal-unified-spine-contract
zig build causal-artifacts
zig build causal-test-matrix
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

## Roadmap Rule

The master roadmap may mark M9 as `delivered` only after the audit command,
schema governance, performance budget, artifact manifest, test matrix, examples,
package tests, repository checks, and whitespace checks all pass on the current
branch or merged target.
