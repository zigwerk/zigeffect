# zigeffect Causal Production Hardening Completion Audit

`causal-production-hardening-completion-audit` is the deterministic,
record-only audit that closes the static production-hardening contract sweep.
It verifies the delivered reports, preserves the authority boundaries, records
remaining evidence gaps, and hands off to the first evidence-producing branch,
which is now delivered as
`codex/zigeffect-causal-load-test-observation-harness`.

## Command

```sh
cd packages/zigeffect
zig build causal-production-hardening-completion-audit
zig build causal-production-hardening-completion-audit -- --format json
```

The text report is for maintainers. The JSON report uses schema
`zigeffect.causal.production-hardening-completion-audit.v1` for agents,
reviewers, and automated roadmap checks.

## Authority Boundary

This audit is `record-only` and has `mutation_authority=none`. It does not
ingest live production telemetry, execute load tests, size production capacity,
estimate production cost, provision infrastructure, host dashboards, send
alerts, create tickets, shift traffic, edit source/config/app/registry,
deployment, rollout, alert, durable-store, or production state, enforce RBAC,
encrypt bytes, decrypt bytes, or grant mutation authority.

Durable work remains NenDB adapter work only. Workbench work remains SolidJS
inside `webui-dev/zig-webui`. The audit explicitly blocks Cockroach or other
durable adapter claims and React or alternate renderer claims for this path.

## Milestone Checks

The audit records one check for each delivered production-hardening dependency:

1. `production-artifact-aggregation`
2. `durable-production-retention`
3. `production-deployment-runbooks`
4. `artifact-access-control`
5. `unified-causal-spine-contract`
6. `deep-runtime-internals`
7. `app-semantic-trace-api`
8. `agent-query-interface` partial
9. `encryption-at-rest-policy`
10. `alerting-integrations`
11. `live-dashboard-streaming-workbench`
12. `workbench-graph-visual-debugging`
13. `human-agent-feedback-loop`
14. `rollout-automation-guardrails`
15. `wall-clock-benchmark-baselines`
16. `production-capacity-planning`

Each record cites the schema, command, doc, completion evidence, completion
boundary, and agent guidance. `agent-query-interface` remains partial because
runtime query JSON and app semantic `trace_data` are delivered, while arbitrary
cross-run comparison remains future work.

## Boundary Checks

The audit verifies these boundaries before any next branch can cite the
hardening sweep:

- record-only authority;
- mutation authority remains none;
- durable direction is NenDB-only;
- workbench direction is SolidJS inside `webui-dev/zig-webui`;
- capacity planning is not a capacity claim;
- wall-clock benchmark baselines remain advisory;
- alerting and rollout records are preview/guardrail records only;
- access control and encryption are policy records only;
- agent queries are bounded and read-only;
- live production telemetry is absent.

## Remaining Evidence Gaps

The audit deliberately separates delivered contracts from missing evidence:

- `load-test-observation-harness`: delivered local observation branch;
- `production-telemetry-capture-design`: recommended next branch;
- `reviewed-production-capacity-sizing`: future;
- `live-alert-delivery`: future;
- `live-rollout-automation`: future;
- `live-rbac-enforcement`: future;
- `encryption-implementation`: future;
- `production-dashboard-hosting`: future;
- `agent-query-cross-run-comparison`: future;
- `nendb-durable-history-hardening`: future.

Agents should cite these as remaining gaps instead of upgrading planning
records into production-readiness claims.

## Negative Audit Fixtures

The audit blocks common over-claims:

- treating contract reports as production-ready runtime behavior;
- treating capacity planning as observed capacity;
- adding Cockroach or non-NenDB adapter scope;
- adding React or another renderer to this workbench path;
- treating alert previews as sent alerts;
- treating rollout guardrails as traffic shifts;
- treating access policy as live RBAC;
- treating encryption policy as encrypted bytes;
- treating wall-clock baselines as CI gates;
- treating the audit as mutation authority.

## Handoff

The load-test observation harness handoff is delivered. It consumes the
capacity-planning fixture plan and wall-clock baseline assumptions, then
produces local observation records without live production telemetry,
production load execution, or capacity claims.

The telemetry capture design and fixture branches are now delivered after this
handoff. The current next branch is
`codex/zigeffect-causal-production-telemetry-readiness-review`. Reviewed
production capacity sizing remains future until compatible observations,
telemetry design, fixtures, readiness review, and human review exist.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_production_hardening_completion_audit.zig
zig build causal-production-hardening-completion-audit
zig build causal-production-hardening-completion-audit -- --format json
zig build causal-load-test-observation-harness
zig build causal-load-test-observation-harness -- --format json
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
bun run check
bun run zig:test
git diff --check
```
