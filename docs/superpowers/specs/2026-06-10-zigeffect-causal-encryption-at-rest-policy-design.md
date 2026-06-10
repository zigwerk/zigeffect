# zigeffect Causal Encryption At Rest Policy Design

Date: 2026-06-10
Branch: `codex/zigeffect-causal-encryption-at-rest-policy`
Status: Approved for implementation by long-running roadmap goal

## Goal

Define the first encryption-at-rest policy contract for retained zigeffect
causal artifacts. This branch must give humans and agents a deterministic,
machine-readable answer to: which retained causal evidence requires encryption,
who owns the keys, how rotation is evidenced, what an encrypted artifact fixture
must prove, and how encryption interacts with redaction.

This is a policy and test milestone, not an encryption implementation.

## Context

The current causal production-hardening stack already has:

- `zigeffect.causal.production-artifact-aggregation.v1` for bundle provenance;
- `zigeffect.causal.durable-production-retention.v1` for NenDB-only durable
  retention policy, TTL, compaction, backup, and recovery expectations;
- `zigeffect.causal.production-deployment-runbooks.v1` for manual deployment,
  rollback, causal verification, and incident response gates;
- `zigeffect.causal.artifact-access-control.v1` for visibility classes,
  permissions, denied-view fixtures, and access audit fields;
- `zigeffect.causal.production-hardening-backlog.v1`, which now recommends this
  branch as the next hardening milestone.

Durable evidence remains NenDB adapter work only. Cockroach, D1, R2, live KMS,
identity-provider integration, and production mutation authority are out of
scope.

## Alternatives Considered

### Option A: Implement Encryption Now

This would add actual encryption/decryption functions or key-provider adapters
before the policy contract exists. It is too early. The codebase still needs to
define key ownership, rotation evidence, redaction ordering, and fixture
requirements before any implementation can be reviewed.

### Option B: Only Add Documentation

This would be quick, but agents need schema-stable evidence. Plain docs would
not give CI or future branch workers a deterministic JSON contract to inspect,
test, or compare.

### Option C: Add A Deterministic Policy Report

This matches the existing production-hardening pattern. A new Zig report tool
emits text and JSON, includes embedded tests, registers a schema, updates
operations docs, and marks the backlog item delivered. It records policy and
fixture expectations without changing artifact bytes.

Decision: use Option C.

## Policy Shape

Add a new schema:

```text
zigeffect.causal.encryption-at-rest-policy.v1
```

The report should expose:

- source contracts consumed by the policy;
- encryption domains for retained artifact classes;
- key ownership model;
- rotation policy;
- encrypted artifact fixture contract;
- redaction/encryption ordering rules;
- audit record fields;
- negative fixtures;
- authority boundaries;
- non-goals;
- verification commands;
- next recommended branch.

## Encryption Domains

The initial domains should be policy labels, not live storage namespaces:

- `local-private-cache`: local developer artifacts that stay unshared by
  default.
- `ci-retained-bundle`: CI-retained bundles that may become durable after
  redaction review.
- `production-retained-bundle`: future durable NenDB-retained bundles.
- `incident-restricted-bundle`: incident evidence that requires incident owner
  or auditor context.
- `external-summary`: redacted summary evidence only; raw source artifacts are
  not shareable.

Each domain records:

- artifact class;
- required encryption state;
- key owner;
- rotation cadence;
- sharing posture;
- retention dependency.

## Key Ownership

The policy should use role labels, not authenticated identities:

- `maintainer`: owns local and CI policy review, not production keys.
- `release-owner`: owns future production-retained bundle key approval.
- `incident-owner`: owns incident-restricted evidence approval.
- `auditor`: can review retained-bundle encryption evidence.
- `agent-readonly`: can inspect redacted metadata only; it never owns keys.

The report must make two boundaries explicit:

- role labels are governance labels, not identity-provider users;
- no role grants production mutation authority or key material access in this
  branch.

## Rotation Policy

The first policy should require:

- planned rotation cadence for each encrypted domain;
- rotation reason labels such as scheduled, incident, key-compromise, and
  policy-change;
- before/after evidence links for future rotation artifacts;
- recovery verification after rotation;
- failure action when rotation evidence is missing.

Rotation is recorded, not executed.

## Encrypted Artifact Fixture Contract

The report should define an example retained-bundle fixture that future
encrypted storage branches must satisfy. It should not contain ciphertext.
Instead, it records required metadata:

- bundle id;
- source contract schema;
- encryption domain;
- key owner role;
- key id reference;
- algorithm family label;
- nonce/iv reference;
- encrypted payload reference;
- plaintext hash reference;
- redaction state;
- rotation state;
- recovery verification command.

The fixture uses references, not raw key material, plaintext, ciphertext, or
live file paths. Paths remain provenance when present, not proof that a file
exists.

## Redaction Interaction

Redaction must happen before encryption for exported retained artifacts. The
policy should say:

1. source causal events are redacted and bounded before they become retained
   artifact evidence;
2. redaction review must pass before durable retention and encryption-at-rest
   are considered satisfied;
3. encrypted bytes do not make unsafe plaintext acceptable;
4. decrypt/review paths must still fail closed if secret-shaped values appear;
5. access-control policy still applies after encryption.

## Negative Fixtures

Include deterministic denied or blocked scenarios:

- encrypted-before-redaction is blocked;
- missing key owner is blocked;
- stale rotation evidence is blocked;
- agent-readonly key access is denied;
- external reviewer raw encrypted bundle access is denied;
- treating encryption approval as mutation authority is denied.

## Backlog Handoff

After implementation, mark `encryption-at-rest-policy` as delivered in
`causal-production-hardening-backlog`. The next recommended branch should move
to:

```text
codex/zigeffect-causal-alerting-integrations
```

The next branch remains record-only alerting and integration policy, not live
paging.

## Files

- Create `packages/zigeffect/tools/causal_encryption_at_rest_policy.zig`.
- Create `packages/zigeffect/docs/encryption-at-rest-policy.md`.
- Modify `packages/zigeffect/build.zig` to add build and test steps.
- Modify `packages/zigeffect/tools/causal_schema_governance.zig` to register
  `zigeffect.causal.encryption-at-rest-policy.v1`.
- Modify `packages/zigeffect/docs/schema-governance.md`.
- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`.
- Modify `packages/zigeffect/docs/production-hardening-backlog.md`.
- Modify `packages/zigeffect/docs/operations.md`.
- Modify `packages/zigeffect/docs/roadmap.md`.
- Modify `packages/zigeffect/docs/m9-completion-audit.md` if it names the
  current backlog recommendation.

## Testing

Focused verification:

```sh
cd packages/zigeffect
zig build causal-encryption-at-rest-policy
zig build causal-encryption-at-rest-policy -- --format json
zig build causal-schema-governance
zig build causal-production-hardening-backlog
```

Full verification:

```sh
cd packages/zigeffect
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

## Non-Goals

- No encryption or decryption implementation.
- No key generation, key wrapping, KMS, HSM, cloud provider, or identity
  provider integration.
- No live production telemetry ingestion.
- No live RBAC enforcement.
- No source, config, app, registry, deployment, rollback, or production
  mutation authority.
- No direct upstream NenDB dependency changes.
- No Cockroach, D1, R2, SQL, or RoachGraph adapter work.
- No React workbench support.

## Self-Review

- Scope check: this is one production-hardening policy slice, not a storage
  implementation branch.
- Contract consistency: it consumes existing aggregation, durable retention,
  deployment runbook, access-control, and schema-governance contracts.
- User constraints preserved: NenDB adapter direction only, no Cockroach, no
  React, no mutation authority.
- Agent utility: the report gives future workers deterministic JSON for key
  ownership, rotation evidence, encrypted fixture metadata, negative fixtures,
  and next-branch guidance.
