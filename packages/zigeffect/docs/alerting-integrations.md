# zigeffect Causal Alerting Integrations

`causal-alerting-integrations` is the deterministic, record-only contract for
alerting and external integration handoffs. It defines channel contracts,
severity, routing, escalation, dedupe, payload fields, preview fixtures,
negative fixtures, and authority boundaries before any live Slack, Linear,
Jira, SIEM, or paging adapter exists.

## Command

```sh
cd packages/zigeffect
zig build causal-alerting-integrations
zig build causal-alerting-integrations -- --format json
```

The JSON report uses schema
`zigeffect.causal.alerting-integrations.v1`.

## Source Contracts

The contract consumes:

- `zigeffect.causal.production-artifact-aggregation.v1`
- `zigeffect.causal.production-deployment-runbooks.v1`
- `zigeffect.causal.artifact-access-control.v1`
- `zigeffect.causal.encryption-at-rest-policy.v1`
- `zigeffect.causal.agent-query.v1`

Aggregation provides provenance, deployment runbooks provide operational gates,
access control provides visibility, encryption policy provides retained-bundle
safety, and agent queries provide bounded evidence ids that agents can cite.

## Policy Boundary

This branch does not send alerts, page humans, create tickets, forward SIEM
events, call networks, read secrets, load credentials, mutate external systems,
ingest production telemetry, add Cockroach scope, add React support, or grant
production mutation authority.

Every fixture is a preview or handoff record with `delivery_state` set to a
not-sent or not-created state and `mutation_authority=none`.

## Integration Channels

The report defines five channel contracts:

- `slack`: chat summary previews for redacted local, CI, or release evidence.
- `linear`: work item previews for release gates and incident follow-up.
- `jira`: ticket previews for production incident evidence.
- `siem`: security event previews for security-review routing.
- `paging`: critical incident handoff records that do not page humans.

Payloads cite ids and summaries. They must not include raw request bodies,
headers, prompts, credentials, tokens, key material, secret-shaped content, or
PII.

## Severity And Routing

Severity levels are `info`, `warning`, `error`, and `critical`.

Routing classes are `dev-loop`, `ci-failure`, `release-gate`,
`production-incident`, and `security-review`.

Paging requires `critical` severity, production incident or security-review
routing, redacted evidence, and human approval evidence before a future live
adapter could act. The deterministic contract never pages.

## Escalation Policy

The escalation policy records the gates future live integrations must satisfy:

- critical severity;
- incident or security-review routing;
- redaction review;
- human approval evidence;
- explicit evidence refs;
- no secret-shaped content.

If a gate is missing, the preview remains blocked or denied.

## Payload Fields

Required payload fields are:

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

`mutation_authority` is always `none`.

## Preview Fixtures

The deterministic fixtures are:

- `slack-ci-failure-preview`
- `linear-release-gate-preview`
- `jira-production-incident-preview`
- `siem-security-review-preview`
- `paging-critical-incident-handoff`

These fixtures let agents reason about external handoff shape without sending
messages, creating issues, forwarding SIEM events, or paging anyone.

## Negative Fixtures

The report blocks or denies:

- unredacted payloads;
- missing evidence refs;
- external mutation attempts;
- paging without human approval;
- secret-shaped content;
- agent live-delivery attempts.

Agents may inspect preview records, but they cannot use this contract to send
notifications or mutate external tools.

## Authority Boundaries

Durable evidence remains NenDB adapter work only. Workbench follow-up remains
SolidJS inside `webui-dev/zig-webui`. React, Cockroach, live RBAC, live
notification delivery, live ticket creation, live SIEM forwarding, paging
execution, and production mutation authority remain out of scope.

## Verification Suite

Run:

```sh
cd packages/zigeffect
zig build causal-alerting-integrations
zig build causal-alerting-integrations -- --format json
zig build causal-schema-governance
zig build causal-production-hardening-backlog
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

This contract hands off to
`codex/zigeffect-causal-live-dashboard-streaming-workbench`. Use
`causal-production-hardening-backlog` for the current branch queue.
