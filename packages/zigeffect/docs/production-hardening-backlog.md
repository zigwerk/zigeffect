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

The recommendation `start-production-deployment-runbooks` means both the
aggregation bundle contract and the NenDB-only durable-retention contract now
exist. The next branch should be
`codex/zigeffect-causal-production-deployment-runbooks`.

## Dependency Order

The backlog currently orders future production-hardening branches as:

1. `production-artifact-aggregation` delivered
2. `durable-production-retention` delivered
3. `production-deployment-runbooks`
4. `artifact-access-control`
5. `encryption-at-rest-policy`
6. `alerting-integrations`
7. `live-dashboard-streaming-workbench`
8. `workbench-graph-visual-debugging`
9. `rollout-automation-guardrails`
10. `wall-clock-benchmark-baselines`
11. `production-capacity-planning`

The ordering is intentionally conservative. It keeps contracts and review
boundaries ahead of production behavior.

## Authority Boundaries

Durable database work is NenDB adapter work only. Do not use this backlog to add
Cockroach adapter scope to zigeffect causal production hardening.

Durable retention is documented in
[durable-production-retention.md](durable-production-retention.md). It defines
TTL, compaction, backup, recovery, and verification fixture contracts without
adding live ingestion or production mutation authority.

Workbench work remains SolidJS inside `webui-dev/zig-webui`. React remains a
non-goal unless a later adapter proves a concrete need.

After the live dashboard and streaming workbench branch, add a dedicated
read-only graph visual debugging branch. That branch should evaluate
`@dschz/solid-g6` with `@antv/g6` as the primary SolidJS graph layer for causal
trace, scope, fiber, cause, retry, and resource-ownership views. Treat
`solid-flow` as optional later editor research for editable remediation planning,
not as a default dashboard dependency.

Mutation authority remains `none`. Backlog items can describe review gates and
future evidence records, but this report does not grant source, config,
deployment, rollout, app, registry, or production mutation authority.

## Verification Suite

Run the backlog report with the operating-model suite before using it to choose
the next branch:

```sh
cd packages/zigeffect
zig build causal-durable-production-retention
zig build causal-durable-production-retention -- --format json
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
