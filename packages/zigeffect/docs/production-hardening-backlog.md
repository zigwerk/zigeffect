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

The recommendation `start-live-dashboard-streaming-workbench` means the
aggregation bundle contract, NenDB-only durable-retention contract, manual
production deployment runbooks, record-only artifact access-control contract,
unified causal spine contract, deep runtime internals, app semantic trace API,
bounded agent query surface, record-only encryption-at-rest policy, and
record-only alerting integrations now exist. The next branch should be
`codex/zigeffect-causal-live-dashboard-streaming-workbench`.

## Dependency Order

The backlog currently orders future production-hardening branches as:

1. `production-artifact-aggregation` delivered
2. `durable-production-retention` delivered
3. `production-deployment-runbooks` delivered
4. `artifact-access-control` delivered
5. `unified-causal-spine-contract` delivered
6. `deep-runtime-internals` delivered
7. `app-semantic-trace-api` delivered
8. `agent-query-interface` partial
9. `encryption-at-rest-policy` delivered
10. `alerting-integrations` delivered
11. `live-dashboard-streaming-workbench`
12. `workbench-graph-visual-debugging`
13. `human-agent-feedback-loop`
14. `rollout-automation-guardrails`
15. `wall-clock-benchmark-baselines`
16. `production-capacity-planning`

The ordering is intentionally conservative. It keeps contracts and review
boundaries ahead of production behavior. The `agent-query-interface` item is
split: runtime bounded JSON queries and app semantic `trace_data` are
delivered, while cross-run comparison remains future work.

## Authority Boundaries

Durable database work is NenDB adapter work only. Do not use this backlog to add
Cockroach adapter scope to zigeffect causal production hardening.

Durable retention is documented in
[durable-production-retention.md](durable-production-retention.md). It defines
TTL, compaction, backup, recovery, and verification fixture contracts without
adding live ingestion or production mutation authority.

Deployment runbooks are documented in
[production-deployment-runbooks.md](production-deployment-runbooks.md). They
define manual deploy, rollback, causal verification, and incident-response
gates without adding deployment automation, rollback automation, alerting, or
production mutation authority.

Artifact access control is documented in
[artifact-access-control.md](artifact-access-control.md). It defines visibility
classes, role labels, permissions, decisions, denied-view fixtures, and audit
record fields without live RBAC enforcement, identity providers, workbench
mutation, or production mutation authority.

Encryption-at-rest policy is documented in
[encryption-at-rest-policy.md](encryption-at-rest-policy.md). It defines
encryption domains, key owner labels, rotation evidence, encrypted artifact
fixture metadata, redaction ordering, denied fixtures, and authority boundaries
without encrypting bytes, decrypting bytes, generating keys, calling a KMS,
enforcing live RBAC, or granting production mutation authority.

Alerting integrations are documented in
[alerting-integrations.md](alerting-integrations.md). They define record-only
channel contracts, severity and routing policy, escalation gates, payload
fields, preview fixtures, denied fixtures, and authority boundaries without
sending alerts, creating tickets, forwarding SIEM events, paging humans,
calling networks, reading secrets, or granting production mutation authority.

Workbench work remains SolidJS inside `webui-dev/zig-webui`. React remains a
non-goal unless a later adapter proves a concrete need.

The unified causal spine is documented in
[unified-spine-contract.md](unified-spine-contract.md). It defines stable
runtime ids (`run_id`, `event_id`, `parent_event_id`, `cause_id`, `fiber_id`,
`scope_id`, `layer_id`, `service_key`, and `resource_id`), app semantic ids
(`artifact_id`, `domain_entity_ref`, `data_subject_ref`, and `schema_ref`), and
relationship types (`caused_by`, `parent_of`, `requires`, `provides`, `reads`,
`writes`, `transforms`, `emits`, `owns`, and `finalizes`). Runtime internals and
app semantics should emit into that spine before UI, agent, and durable-store
projections consume it.

Humans and agents consume the same evidence model, but they need different
surfaces. The SolidJS `zig-webui` workbench is the human control room for
reading, viewing, managing, and understanding what happened. The agent
interface is a compact query surface for bounded graph slices, evidence ids,
diffs, redaction state, truncation state, confidence, and recommended next
queries.

The live dashboard and streaming workbench branch should add the first graph
adapter boundary. Start with `@dschz/solid-g6` as the SolidJS integration layer.
Keep the zigeffect causal graph model as the source of truth. Add direct
`@antv/g6` usage only when the Solid adapter does not expose the required
engine API cleanly. The first UI should be a read-only upgraded `Graph` tab or
new `Visual Graph` tab.

The dedicated graph visual debugging branch should deepen that adapter with
layout modes: dagre or hierarchical for cause chains, force for runtime
topology, and radial for scope, fiber, and resource ownership. Treat
`solid-flow` as optional later editor research for editable remediation
planning, not as a default dashboard dependency.

Mutation authority remains `none`. Backlog items can describe review gates and
future evidence records, but this report does not grant source, config,
deployment, rollout, app, registry, or production mutation authority.

## Verification Suite

Run the backlog report with the operating-model suite before using it to choose
the next branch:

```sh
cd packages/zigeffect
zig build causal-artifact-access-control
zig build causal-artifact-access-control -- --format json
zig build causal-unified-spine-contract
zig build causal-unified-spine-contract -- --format json
zig build causal-production-deployment-runbooks
zig build causal-production-deployment-runbooks -- --format json
zig build causal-durable-production-retention
zig build causal-durable-production-retention -- --format json
zig build causal-production-artifact-aggregation
zig build causal-production-artifact-aggregation -- --format json
zig build causal-encryption-at-rest-policy
zig build causal-encryption-at-rest-policy -- --format json
zig build causal-alerting-integrations
zig build causal-alerting-integrations -- --format json
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
