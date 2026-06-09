# zigeffect Causal Production Deployment Runbooks Design

Date: 2026-06-09

## Purpose

This slice turns the next production-hardening backlog item,
`production-deployment-runbooks`, into a deterministic contract that agents can
query before a causal-instrumented service is deployed, rolled back, verified,
or triaged during an incident.

The output is not a deployment system. It is a reviewed runbook report with
stable schema, explicit gates, ordered procedures, verification commands, and
incident templates. The goal is to make production operation safer and more
agent-readable without granting production mutation authority.

## Context

The previous production-hardening slices delivered:

- `zigeffect.causal.production-artifact-aggregation.v1`, which defines source
  provenance and privacy review for causal artifact bundles.
- `zigeffect.causal.durable-production-retention.v1`, which defines NenDB
  adapter retention, TTL, compaction, backup, and recovery expectations.
- `zigeffect.causal.production-hardening-backlog.v1`, which names
  `codex/zigeffect-causal-production-deployment-runbooks` as the next branch.

This branch consumes those contracts and defines the human-reviewed operating
steps that must exist before production deployment, rollback, or incident
handling can be called ready.

## Requirements

1. Add a deterministic Zig report command:
   `zig build causal-production-deployment-runbooks`.
2. Emit text and JSON output using schema
   `zigeffect.causal.production-deployment-runbooks.v1`.
3. Name the consumed contracts:
   `zigeffect.causal.production-artifact-aggregation.v1` and
   `zigeffect.causal.durable-production-retention.v1`.
4. Define runbooks for deployment, rollback, causal verification, and incident
   response.
5. Include manual gate records that fail closed when causal evidence,
   redaction review, durable retention, rollback readiness, or human review is
   missing.
6. Include an incident-response template with severity, impact, owner,
   triggering event ids, suspected cause ids, evidence bundle, mitigation,
   rollback decision, follow-up artifacts, and verification commands.
7. Update schema governance, operations docs, roadmap docs, and production
   hardening backlog docs so the next branch becomes
   `codex/zigeffect-causal-artifact-access-control`.
8. Preserve the user's constraints:
   - durable database direction is NenDB adapter only;
   - no Cockroach adapter work;
   - workbench direction remains SolidJS inside `webui-dev/zig-webui`;
   - no React workbench support;
   - no deployment or rollback automation;
   - no production mutation authority.

## Proposed Shape

### Option A: Documentation Only

Write manual deploy and incident prose into `operations.md`. This is quick, but
agents cannot reliably query it as a versioned contract and the production
hardening backlog would still lack a testable artifact.

### Option B: Runtime Tool With Real Deployment Hooks

Add a runbook tool that can also run deploys, rollbacks, or incident actions.
This would be premature. The current authority model is record-only, and
deployment mutation belongs behind later reviewed rollout guardrails.

### Option C: Deterministic Record-Only Contract

Add a deterministic tool, docs, schema governance entry, and backlog status
update. This gives agents stable evidence and procedures while keeping all
source, config, deploy, rollback, paging, and external-system mutation outside
the slice.

Chosen path: Option C.

## Artifact Model

The new command produces a report with these top-level fields:

- `schema`: `zigeffect.causal.production-deployment-runbooks.v1`
- `schema_version`: `1`
- `status`: `current`
- `generated_by`: `causal-production-deployment-runbooks`
- `source_contracts`: aggregation and durable retention schema names
- `recommendation`: `start-artifact-access-control`
- `recommended_next_branch`: `codex/zigeffect-causal-artifact-access-control`
- `runbooks`: ordered manual procedures
- `gates`: required readiness gates and failure actions
- `incident_template`: required incident record fields
- `authority_boundaries`: explicit non-goals and mutation restrictions
- `verification_commands`: commands proving the contract and surrounding docs
  remain coherent

## Runbooks

### Deployment

The deployment runbook must require:

1. A reviewed artifact aggregation bundle for the candidate build.
2. Durable retention readiness through the NenDB adapter contract.
3. Redaction review for all shareable artifacts.
4. Human deployment approval with owner and reason.
5. Pre-deploy causal baseline capture.
6. Deploy execution outside zigeffect's authority boundary.
7. Post-deploy causal verification and linked artifact capture.
8. A final decision record that references event ids and verification commands.

### Rollback

The rollback runbook must require:

1. Current incident or failed verification evidence.
2. Known last-good build or configuration reference.
3. Rollback owner approval.
4. Rollback execution outside zigeffect's authority boundary.
5. After-rollback causal verification.
6. Durable retention of before, failed, rollback, and after evidence.

### Causal Verification

The verification runbook must require:

1. `causal-production-artifact-aggregation` output.
2. `causal-durable-production-retention` output.
3. `causal-schema-governance` output.
4. Relevant app or service causal artifacts.
5. Queryable event ids for root causes, terminal failures, and remediation
   evidence.
6. Explicit limitation notes when artifacts are sampled, truncated, stale, or
   missing.

### Incident Response

The incident runbook must require:

1. Severity and impact classification.
2. Owner and reviewer names.
3. Triggering event ids and suspected cause ids.
4. Linked artifact bundle id.
5. Decision to mitigate, rollback, observe, or escalate.
6. Verification commands and next artifacts.
7. Follow-up branch or issue recommendation.

## Authority And Safety

This branch grants no new authority. The tool must not deploy, roll back,
mutate registries, page humans, contact live systems, upload artifacts, delete
retained data, or inspect clocks/networks. It is deterministic and record-only.

The contract must continue to name NenDB adapter retention as the durable
direction. It must not add Cockroach, D1, R2, SQL, RoachGraph, or a direct
upstream NenDB dependency. Workbench follow-up stays on SolidJS plus
`webui-dev/zig-webui`.

## Testing Strategy

Tests live in the new Zig tool file, following existing report-tool patterns.
They must prove:

- metadata names schema, source contracts, recommendation, and next branch;
- all required runbook ids exist;
- all required gates fail closed;
- incident template fields include event ids, artifact bundle, owner, and
  verification commands;
- non-goals include deployment automation, production mutation authority,
  Cockroach adapter work, and React workbench support;
- text and JSON output include the schema and key runbook/gate fields;
- option parsing handles text, JSON, unknown formats, missing formats, and
  unknown flags.

Broader verification must run the new command, existing production-hardening
commands, schema governance, examples, Zig tests, Bun checks, and diff checks.

## Completion Criteria

The branch is complete when:

- `zig build causal-production-deployment-runbooks` prints the text report;
- `zig build causal-production-deployment-runbooks -- --format json` prints the
  JSON report;
- schema governance includes
  `zigeffect.causal.production-deployment-runbooks.v1`;
- production hardening backlog marks `production-deployment-runbooks` as
  delivered and recommends `codex/zigeffect-causal-artifact-access-control`;
- operations and roadmap docs describe the manual runbook boundary;
- verification commands pass from the current worktree;
- unrelated dirty files remain unstaged unless they belong to this branch.

## Self-Review

- Placeholder scan: no placeholders remain.
- Internal consistency: the chosen design is record-only, deterministic, and
  follows the established production-hardening report pattern.
- Scope check: this is one production-hardening slice, not rollout automation,
  alerting, access control, encryption, or live dashboards.
- Ambiguity check: deployment and rollback execution are explicitly outside
  zigeffect authority in this branch.
