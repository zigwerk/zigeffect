# zigeffect Causal Production Deployment Runbooks

`causal-production-deployment-runbooks` is the deterministic, record-only
runbook contract for production services that use zigeffect causal evidence.
It defines the manual gates for deployment, rollback, causal verification, and
incident response after artifact aggregation and durable retention exist.

## Command

```sh
cd packages/zigeffect
zig build causal-production-deployment-runbooks
zig build causal-production-deployment-runbooks -- --format json
```

The JSON report uses schema
`zigeffect.causal.production-deployment-runbooks.v1`.

## Source Contracts

The runbooks consume:

- `zigeffect.causal.production-artifact-aggregation.v1`
- `zigeffect.causal.durable-production-retention.v1`

They do not invent a new production evidence source shape. Deployment,
rollback, verification, and incident records must cite aggregation bundles and
durable-retention readiness rather than loose logs or unreviewed artifact
paths.

## Deployment Runbook

Deployment readiness requires:

1. Reviewed production artifact aggregation bundle for the candidate build.
2. NenDB adapter retention and recovery readiness through durable production
   retention.
3. Redaction review for shareable text, JSON, and DOT artifacts.
4. Pre-deploy baseline or last-good causal reference with queryable event ids.
5. Human deployment approval with owner, reviewer, reason, and rollback owner.
6. External deployment record id from the actual deploy system.
7. Post-deploy causal verification with root, terminal, and remediation event
   ids.

If any required evidence is missing, agents must block deployment readiness.

## Rollback Runbook

Rollback readiness requires:

1. Triggering incident or failed verification evidence.
2. Last-good build, config, or runtime state reference.
3. Human rollback approval with owner and reason.
4. External rollback record id from the actual deployment system.
5. After-rollback causal verification.
6. Retention of before, failed, rollback, and after evidence.

If after-rollback verification is missing, keep the incident or release review
open.

## Causal Verification Runbook

Production causal verification requires:

```sh
zig build causal-production-artifact-aggregation
zig build causal-durable-production-retention
zig build causal-schema-governance
```

For service-specific evidence, agents must also verify cited event ids with the
relevant causal artifact query commands. If evidence is sampled, truncated,
stale, or missing, record the limitation and avoid claiming the trace is
complete.

## Incident Response Template

Incident records require:

- severity;
- impact;
- owner;
- reviewer;
- triggering event ids;
- suspected cause ids;
- artifact bundle id;
- response decision;
- mitigation;
- rollback decision;
- follow-up artifacts;
- verification commands.

The response decision is advisory and reviewed: mitigate, rollback, observe,
or escalate. This contract does not page humans or call external incident
systems.

## Authority Boundaries

Deployment and rollback execution stay outside zigeffect authority. zigeffect
records reviewed evidence, event ids, commands, and external record ids only.

This branch does not add Cockroach, D1, R2, SQL, RoachGraph, or a direct
upstream NenDB dependency. Durable evidence direction remains NenDB adapter
only.

It does not ingest live production telemetry, deploy services, roll back
services, enforce RBAC, encrypt artifacts, page humans, automate rollouts, or
grant source/config/app/registry/production mutation authority.

Workbench follow-up remains SolidJS inside `webui-dev/zig-webui`. React remains
a non-goal for this path.

## Verification Suite

Run:

```sh
cd packages/zigeffect
zig build causal-production-deployment-runbooks
zig build causal-production-deployment-runbooks -- --format json
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

The immediate production-hardening consumer after this contract is artifact
access control. Use `zig build causal-production-hardening-backlog` for the
current next branch.
