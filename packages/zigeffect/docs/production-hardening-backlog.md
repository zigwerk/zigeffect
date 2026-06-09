# zigeffect Causal Production Hardening Backlog

`causal-production-hardening-backlog` is the deterministic branch queue for
production hardening after the M9 local/CI operating model. It converts the M9
production-gap register into ordered backlog items with dependencies,
constraints, non-goals, evidence sources, verification commands, and the next
recommended branch.

## Command

```sh
cd packages/zigeffect
zig build causal-production-hardening-backlog
zig build causal-production-hardening-backlog -- --format json
```

The text report is for maintainers. The JSON report uses schema
`zigeffect.causal.production-hardening-backlog.v1` for agents and automated
roadmap checks.

## What The Report Means

The report is a planning and governance artifact. It does not ingest production
telemetry, write durable production state, deploy services, page humans,
enforce RBAC, encrypt data, open a production dashboard, or mutate source and
config.

The recommendation `start-durable-production-retention` means the aggregation
bundle and source-provenance contract now exists, and the next branch should be
`codex/zigeffect-causal-durable-production-retention`. Durable retention must
consume the aggregation contract before writing retained records. That durable
work remains NenDB adapter work only.

## Dependency Order

The backlog currently orders future production-hardening branches as:

1. `production-artifact-aggregation` delivered
2. `durable-production-retention`
3. `production-deployment-runbooks`
4. `artifact-access-control`
5. `encryption-at-rest-policy`
6. `alerting-integrations`
7. `live-dashboard-streaming-workbench`
8. `rollout-automation-guardrails`
9. `wall-clock-benchmark-baselines`
10. `production-capacity-planning`

The ordering is intentionally conservative. It keeps contracts and review
boundaries ahead of production behavior.

## Authority Boundaries

Durable database work is NenDB adapter work only. Do not use this backlog to add
Cockroach adapter scope to zigeffect causal production hardening.

Workbench work remains SolidJS inside `webui-dev/zig-webui`. React remains a
non-goal unless a later adapter proves a concrete need.

Mutation authority remains `none`. Backlog items can describe review gates and
future evidence records, but this report does not grant source, config,
deployment, rollout, app, registry, or production mutation authority.

## Verification Suite

Run the backlog report with the operating-model suite before using it to choose
the next branch:

```sh
cd packages/zigeffect
zig build causal-production-artifact-aggregation
zig build causal-production-artifact-aggregation -- --format json
zig build causal-production-hardening-backlog
zig build causal-production-hardening-backlog -- --format json
zig build causal-schema-governance
zig build causal-m9-completion-audit
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
