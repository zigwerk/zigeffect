# zigeffect Causal Artifact Access Control

`causal-artifact-access-control` is the deterministic, record-only access
policy contract for causal artifacts and retained bundles. It defines
visibility classes, role labels, permissions, access decisions, denied-view
fixtures, and access audit record fields before production sharing or future
workbench enforcement exists.

## Command

```sh
cd packages/zigeffect
zig build causal-artifact-access-control
zig build causal-artifact-access-control -- --format json
```

The JSON report uses schema `zigeffect.causal.artifact-access-control.v1`.

## Source Contracts

The contract consumes:

- `zigeffect.causal.production-artifact-aggregation.v1`
- `zigeffect.causal.durable-production-retention.v1`
- `zigeffect.causal.production-deployment-runbooks.v1`

Access decisions rely on artifact provenance, redaction state, trust boundary,
retention state, and deployment or incident runbook gates.

## Visibility Classes

- `local-private`: local-only evidence that must not be shared by default.
- `ci-internal`: CI artifact evidence retained under current CI retention.
- `reviewed-shared`: redacted and reviewed evidence safe for project-internal
  sharing.
- `incident-restricted`: incident evidence requiring incident owner or auditor
  context.
- `production-retained`: durable retained bundle evidence requiring policy
  review before production sharing.
- `external-summary`: redacted summary only; no source JSON, DOT, or raw event
  details.

## Roles And Permissions

Roles are policy labels, not authenticated identities:

- `maintainer`
- `release-owner`
- `incident-owner`
- `auditor`
- `agent-readonly`
- `external-reviewer`

Permissions are advisory:

- `view-metadata`
- `view-redacted-artifact`
- `view-incident-artifact`
- `view-retained-bundle`
- `share-internal-summary`
- `share-external-summary`
- `request-review`
- `record-access-audit`

No permission grants source, config, deployment, rollback, registry, app, or
production mutation authority.

## Decisions

Access decisions are:

- `allow`
- `deny`
- `review-required`
- `redacted-only`

Denied and review-required records must include the failed gate and reason.

## Audit Record Fields

Access audit records require:

- `audit_record_id`
- `artifact_id`
- `bundle_id`
- `actor_role`
- `requested_permission`
- `decision`
- `reason`
- `source_contract_schema`
- `redaction_state`
- `trust_boundary`
- `retention_state`
- `cited_gate`
- `verification_command`
- `mutation_authority`

`mutation_authority` is always `none` for this contract.

## Negative Fixtures

The report includes denied or review-required fixtures for external reviewer
production JSON access, unreviewed redaction, incident evidence without incident
owner context, unsupported schemas, visible secret-shaped content, and attempts
to treat access approval as mutation authority.

## Authority Boundaries

This branch does not authenticate users, enforce live RBAC, call identity
providers, encrypt or decrypt artifacts, modify the SolidJS workbench, upload
or download artifacts, page humans, deploy services, roll back services, or
grant mutation authority.

Durable evidence direction remains NenDB adapter only. Workbench consumption
remains SolidJS inside `webui-dev/zig-webui`; React is not part of this path.

## Verification Suite

Run:

```sh
cd packages/zigeffect
zig build causal-artifact-access-control
zig build causal-artifact-access-control -- --format json
zig build causal-production-deployment-runbooks
zig build causal-durable-production-retention
zig build causal-production-artifact-aggregation
zig build causal-production-hardening-backlog
zig build causal-schema-governance
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

The next branch is `codex/zigeffect-causal-unified-spine-contract`.
