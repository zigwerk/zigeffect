# zigeffect Causal Artifact Access Control Design

Date: 2026-06-09

## Purpose

This slice turns `artifact-access-control` into a deterministic, record-only
contract for causal artifact visibility, role permissions, access decisions,
and access audit records. It protects production causal evidence before
sharing, workbench views, integrations, dashboards, or agent query surfaces
consume retained bundles.

The branch does not implement live RBAC. It defines the policy vocabulary,
negative fixtures, and audit record shape that a future production host can
enforce.

## Context

The access-control branch consumes three delivered production-hardening
contracts:

- `zigeffect.causal.production-artifact-aggregation.v1` for source provenance,
  trust boundary, redaction state, retention state, artifact class, and query
  hints.
- `zigeffect.causal.durable-production-retention.v1` for NenDB adapter
  retention, TTL, compaction, backup, recovery, and retained-bundle readiness.
- `zigeffect.causal.production-deployment-runbooks.v1` for manual deployment,
  rollback, causal verification, and incident-response gates.

Access control must preserve the same project constraints:

- durable database direction is NenDB adapter only;
- no Cockroach adapter work;
- no direct upstream NenDB dependency;
- workbench direction is SolidJS inside `webui-dev/zig-webui`;
- no React workbench support;
- no production mutation authority;
- no live identity provider, RBAC enforcement, or production host.

## Requirements

1. Add a deterministic Zig report command:
   `zig build causal-artifact-access-control`.
2. Emit text and JSON using schema
   `zigeffect.causal.artifact-access-control.v1`.
3. Name the consumed aggregation, durable-retention, and deployment-runbook
   schemas.
4. Define a visibility model for causal artifacts and retained bundles.
5. Define a role and permission matrix for maintainers, release owners,
   incident owners, auditors, read-only agents, and external reviewers.
6. Define access decisions:
   - `allow`;
   - `deny`;
   - `review-required`;
   - `redacted-only`.
7. Define an access audit record schema with artifact/bundle id, actor role,
   requested permission, decision, reason, source contract, redaction state,
   trust boundary, retention state, cited gate, verification command, and
   mutation authority.
8. Include negative fixtures for denied or review-required views.
9. Update schema governance, operations docs, README, roadmap docs, and the
   production-hardening backlog.
10. Preserve the current roadmap direction that the next branch after access
    control is `codex/zigeffect-causal-unified-spine-contract` if that item is
    present in the active backlog.

## Proposed Shape

### Option A: Live RBAC Enforcement

Build real user auth, role assignment, and enforcement around artifact views.
This is premature because no reviewed production host or identity boundary
exists. It would also risk granting authority before the policy vocabulary is
stable.

### Option B: Workbench-Only Visibility Flags

Add access flags to the SolidJS workbench and hide panels locally. This would
help humans, but it would not give agents, future dashboards, integrations, or
durable stores a stable policy contract.

### Option C: Deterministic Record-Only Contract

Add a report tool, schema entry, docs, and negative fixtures that define how
access decisions must be recorded. Future UI and production hosts can consume
the same contract. This keeps the branch useful immediately while preserving
authority boundaries.

Chosen path: Option C.

## Artifact Model

The new command produces a report with:

- `schema`: `zigeffect.causal.artifact-access-control.v1`
- `schema_version`: `1`
- `status`: `current`
- `generated_by`: `causal-artifact-access-control`
- `source_contracts`: aggregation, durable retention, deployment runbooks
- `recommendation`: `start-unified-causal-spine-contract`
- `recommended_next_branch`:
  `codex/zigeffect-causal-unified-spine-contract`
- `visibility_classes`
- `roles`
- `permissions`
- `role_permission_matrix`
- `access_decisions`
- `negative_fixtures`
- `audit_record_fields`
- `authority_boundaries`
- `non_goals`
- `verification_commands`

## Visibility Classes

The first visibility classes are:

- `local-private`: local-only evidence; never shared by default.
- `ci-internal`: CI artifact evidence retained under current CI retention.
- `reviewed-shared`: redacted and reviewed evidence safe for project-internal
  sharing.
- `incident-restricted`: incident evidence requiring incident owner or auditor
  context.
- `production-retained`: durable retained bundle evidence requiring policy
  review before any external view.
- `external-summary`: redacted summary only; no source JSON, DOT, or raw event
  details.

## Roles

The first roles are:

- `maintainer`;
- `release-owner`;
- `incident-owner`;
- `auditor`;
- `agent-readonly`;
- `external-reviewer`.

Roles are policy labels, not authenticated identities. Future production hosts
must map identities to these roles outside this branch.

## Permissions

The first permissions are:

- `view-metadata`;
- `view-redacted-artifact`;
- `view-incident-artifact`;
- `view-retained-bundle`;
- `share-internal-summary`;
- `share-external-summary`;
- `request-review`;
- `record-access-audit`.

No permission grants source, config, deployment, rollback, registry, app, or
production mutation authority.

## Decision Semantics

Access decisions are deterministic records:

- `allow`: the role and artifact state satisfy the policy.
- `deny`: the request fails closed.
- `review-required`: a human review record is required before access.
- `redacted-only`: only metadata or redacted summary may be shown.

Denied views must record why they were denied and which gate failed.

## Negative Fixtures

The report must include negative fixtures for:

- external reviewer requesting source JSON from a production retained bundle;
- agent requesting an artifact with `redaction_state` not reviewed;
- release owner requesting incident-restricted evidence without incident owner
  context;
- any role requesting an unsupported schema;
- any role requesting raw secret-shaped artifact content;
- any role treating access approval as mutation authority.

## Authority Boundaries

This contract does not authenticate users, enforce live RBAC, call identity
providers, modify the SolidJS workbench, upload or download artifacts, decrypt
artifacts, page humans, deploy services, roll back services, or grant mutation
authority.

The access policy is advisory until a reviewed production host or workbench
branch consumes it. Agents must cite the access decision and limitations rather
than claiming enforcement happened.

## Testing Strategy

Inline Zig tests in the new tool must prove:

- metadata names schema, source contracts, recommendation, and next branch;
- visibility classes, roles, permissions, decisions, and negative fixtures
  exist;
- every negative fixture has decision `deny` or `review-required`;
- audit record fields include artifact id, bundle id, actor role, permission,
  decision, reason, redaction state, trust boundary, retention state, cited
  gate, verification command, and mutation authority;
- text and JSON output include the schema and core policy fields;
- option parsing handles text, JSON, unknown format, missing format, and
  unknown flag.

Broader verification must run the new command, previous production-hardening
commands, schema governance, examples, Zig tests, Bun checks, and diff checks.

## Completion Criteria

The branch is complete when:

- `zig build causal-artifact-access-control` prints the text report;
- `zig build causal-artifact-access-control -- --format json` prints parseable
  JSON;
- schema governance includes `zigeffect.causal.artifact-access-control.v1`;
- production hardening backlog marks `artifact-access-control` delivered;
- operations, README, schema governance docs, and roadmap docs describe the
  policy-only boundary;
- verification commands pass from the current worktree;
- unrelated dirty files are not staged unless deliberately incorporated into
  this branch after review.

## Self-Review

- Placeholder scan: no placeholders remain.
- Internal consistency: the branch defines policy and audit records, not live
  enforcement.
- Scope check: this is one production-hardening slice, not encryption, alerting,
  dashboarding, identity management, or workbench UI implementation.
- Ambiguity check: role labels are not authenticated users, and access
  decisions are not mutation authority.
