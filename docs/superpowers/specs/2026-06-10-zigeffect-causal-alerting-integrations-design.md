# zigeffect Causal Alerting Integrations Design

Date: 2026-06-10
Branch: `codex/zigeffect-causal-alerting-integrations`

## Context

The production-hardening backlog now recommends
`codex/zigeffect-causal-alerting-integrations` after the encryption-at-rest
policy branch. The delivered hardening contracts already define aggregation
bundles, NenDB-only durable retention, manual deployment runbooks, artifact
access-control policy, unified causal ids, deeper runtime facts, app semantic
traces, bounded agent queries, and encryption-at-rest policy.

This branch should make alerting and external integrations understandable to
agents without sending real notifications. The right artifact is a
deterministic, record-only contract that says what zigeffect would emit to
integration systems, how severity and escalation are selected, which evidence
ids are cited, which payload fields are safe, and which paths are explicitly
blocked.

## Problem

Production causal failures eventually need to reach humans and external
systems such as Slack, Linear, Jira, SIEM tools, and paging systems. Jumping
directly to live integrations would create the wrong authority boundary:
deterministic local and CI tests would need secrets, networks, production
tenant ids, and notification side effects.

Agents need a stable schema before live adapters exist. They should be able to
inspect an alert contract, reason about evidence ids, severity, routing,
redaction state, access-control gates, integration payload shape, and negative
fixtures without being able to page a human or mutate external systems.

## Goals

- Add a deterministic `causal-alerting-integrations` report tool.
- Publish schema `zigeffect.causal.alerting-integrations.v1`.
- Define an integration event contract for alert-worthy causal findings.
- Define channel fixtures for Slack, Linear, Jira, SIEM, and paging handoff.
- Define severity, routing, escalation, dedupe, suppression, and audit fields.
- Define redaction and access-control interactions before any payload leaves
  zigeffect.
- Define negative fixtures for unsafe or unauthorized alert attempts.
- Register the schema in schema governance.
- Mark the backlog item delivered and advance the next branch.
- Update operations, roadmap, README, M9 audit, and backlog docs.

## Non-Goals

- No live Slack, Linear, Jira, SIEM, PagerDuty, Opsgenie, email, webhook, or
  HTTP integration.
- No network calls, token loading, credential storage, or secret management.
- No paging humans from deterministic tests.
- No production telemetry ingestion.
- No mutation of issues, tickets, incidents, source, config, deployments,
  rollbacks, registries, apps, or production systems.
- No Cockroach adapter work; durable direction remains NenDB adapter only.
- No React workbench support; workbench direction remains SolidJS inside
  `webui-dev/zig-webui`.
- No live RBAC enforcement, identity provider integration, or encrypted storage
  implementation.

## Explored Approaches

### Recommended: Record-Only Alert Contract Tool

Create one Zig report tool that emits text and JSON with deterministic channel
contracts, routing policy, escalation policy, fixtures, negative fixtures, and
verification commands.

This follows the existing production-hardening pattern, gives agents stable
schema immediately, and keeps live integration side effects out of scope.

### Alternative: Add Live Adapter Interfaces Now

Introduce adapter structs for Slack, Linear, Jira, SIEM, and paging with fake
implementations for tests.

This would be premature. The integration event shape is not yet a stable
contract, and live adapter interfaces would force decisions about credentials,
network retries, external ids, and error semantics before the policy boundary is
documented.

### Alternative: Documentation Only

Write operations docs describing future integrations without adding a schema or
report tool.

This is too weak for the agentic roadmap. Agents need machine-readable
contracts and negative fixtures, not only prose.

## Design

### Tool

Add `packages/zigeffect/tools/causal_alerting_integrations.zig`.

The tool should mirror the production-hardening tools:

- constants for schema, schema version, recommendation, and next branch;
- deterministic arrays for source contracts, channels, severity policy,
  routing policy, escalation policy, dedupe rules, payload fields, fixtures,
  negative fixtures, authority boundaries, non-goals, and verification
  commands;
- `formatAlertingIntegrationsText`;
- `formatAlertingIntegrationsJson`;
- `parseOptions`;
- `main`;
- module tests for metadata, policy coverage, text output, JSON output, JSON
  parseability, and CLI parsing.

The build step should be:

```sh
zig build causal-alerting-integrations
zig build causal-alerting-integrations -- --format json
```

### Schema

Register `zigeffect.causal.alerting-integrations.v1` in
`causal_schema_governance.zig`.

The schema category is `production-hardening`, compatibility is `record-only`,
producer is `causal-alerting-integrations`, and consumers include deployment
runbooks, rollout guardrails, human-agent feedback loop, production dashboard
planning, and agents.

### Source Contracts

The alerting contract consumes:

- `zigeffect.causal.production-artifact-aggregation.v1`
- `zigeffect.causal.production-deployment-runbooks.v1`
- `zigeffect.causal.artifact-access-control.v1`
- `zigeffect.causal.encryption-at-rest-policy.v1`
- `zigeffect.causal.agent-query.v1`

Aggregation provides provenance, deployment runbooks provide operational gates,
access control defines visibility, encryption policy defines retained bundle
safety, and agent queries define the bounded evidence slices agents can cite.

### Channels

The report should define channel contracts for:

- `slack`
- `linear`
- `jira`
- `siem`
- `paging`

Each channel records allowed payload class, required evidence, redaction
posture, delivery mode, and mutation posture. Slack, Linear, Jira, and SIEM are
record-only preview payloads. Paging is an escalation handoff record only; it
must never page a human from deterministic tests.

### Severity And Routing

Severity levels:

- `info`
- `warning`
- `error`
- `critical`

Routing classes:

- `dev-loop`
- `ci-failure`
- `release-gate`
- `production-incident`
- `security-review`

The report should define when each class may map to Slack, Linear, Jira, SIEM,
or paging. Paging requires `critical` severity, reviewed incident context,
redacted evidence, and human approval evidence before any future live adapter
could act.

### Payload Fields

Required integration payload fields:

- `alert_record_id`
- `source_contract_schema`
- `run_id`
- `event_id`
- `finding_id`
- `severity`
- `routing_class`
- `channel`
- `payload_class`
- `redaction_state`
- `visibility_class`
- `evidence_refs`
- `dedupe_key`
- `suppression_state`
- `escalation_state`
- `verification_command`
- `mutation_authority`

Payloads cite ids and summaries, not raw event payloads, prompts, request
bodies, headers, credentials, tokens, key material, or PII.

### Fixtures

Include deterministic fixtures for:

- Slack CI failure preview;
- Linear release-gate work item preview;
- Jira production incident ticket preview;
- SIEM security-review forwarding preview;
- paging critical incident handoff record.

Fixtures are preview records. They must say `delivery_state=not-sent` and
`mutation_authority=none`.

### Negative Fixtures

Include denied or blocked fixtures for:

- unredacted payload blocked;
- missing evidence refs blocked;
- external mutation attempt denied;
- paging without human approval denied;
- secret-shaped content denied;
- agent attempts live delivery denied.

### Backlog Handoff

When delivered, update the production-hardening backlog:

- mark `alerting-integrations` delivered;
- evidence sources include the new tool and docs;
- verification commands include the new build step;
- recommendation advances to `start-live-dashboard-streaming-workbench`;
- recommended next branch becomes
  `codex/zigeffect-causal-live-dashboard-streaming-workbench`.

This keeps the roadmap moving toward the SolidJS `zig-webui` dashboard branch.

## Documentation

Create `packages/zigeffect/docs/alerting-integrations.md` and update:

- `packages/zigeffect/docs/schema-governance.md`
- `packages/zigeffect/docs/production-hardening-backlog.md`
- `packages/zigeffect/docs/operations.md`
- `packages/zigeffect/docs/roadmap.md`
- `packages/zigeffect/docs/m9-completion-audit.md`
- `packages/zigeffect/docs/performance-budget.md`
- `packages/zigeffect/README.md`

The docs must clearly state that this branch does not send alerts, page humans,
create tickets, mutate external systems, use secrets, use networks, add
Cockroach, or switch the workbench to React.

## Testing

Use TDD:

1. Write failing tests in `causal_alerting_integrations.zig` for the schema,
   channels, routing, negative fixtures, text report, JSON report, JSON parse,
   and CLI options.
2. Run `zig test tools/causal_alerting_integrations.zig` and confirm red
   failures from missing implementation.
3. Implement the report.
4. Run the direct test and build step.
5. Add `build.zig` step and aggregate test wiring.
6. Update schema governance tests to expect the new schema count and schema
   entry, then implement the schema entry.
7. Update backlog tests to expect the new next branch, then implement backlog
   advancement.
8. Run the focused and aggregate verification suite.

## Verification

Focused:

```sh
cd packages/zigeffect
zig test tools/causal_alerting_integrations.zig
zig build causal-alerting-integrations
zig build causal-alerting-integrations -- --format json
zig build causal-schema-governance
zig build causal-production-hardening-backlog
```

Full:

```sh
cd packages/zigeffect
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

## Self-Review Notes

- No placeholders remain.
- The design is one branch-sized artifact: policy/report/docs, not live
  integration adapters.
- The next branch is explicit and aligns with the current backlog order.
- The constraints preserve NenDB-only durable direction, SolidJS webui
  direction, no Cockroach, no React, and no mutation authority.
