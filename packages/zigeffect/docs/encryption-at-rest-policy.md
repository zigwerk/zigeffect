# zigeffect Causal Encryption At Rest Policy

`causal-encryption-at-rest-policy` is the deterministic, record-only policy
contract for protecting retained causal artifacts after redaction, durable
retention, and access-control review. It defines encryption domains, key owner
labels, rotation evidence, encrypted artifact fixture metadata, redaction
ordering, negative fixtures, and authority boundaries before any live
encryption implementation exists.

## Command

```sh
cd packages/zigeffect
zig build causal-encryption-at-rest-policy
zig build causal-encryption-at-rest-policy -- --format json
```

The text report is for maintainers. The JSON report uses schema
`zigeffect.causal.encryption-at-rest-policy.v1` for agents, roadmap checks, and
future storage adapter work.

## Source Contracts

The contract consumes:

- `zigeffect.causal.production-artifact-aggregation.v1`
- `zigeffect.causal.durable-production-retention.v1`
- `zigeffect.causal.artifact-access-control.v1`

Encryption eligibility depends on aggregation provenance, NenDB retention
state, redaction state, trust boundary, visibility class, access decision, and
review evidence. Encryption is not treated as a substitute for any earlier
gate.

## Policy Boundary

This report defines the policy records future encrypted stores must satisfy. It
does not encrypt bytes, decrypt bytes, generate keys, rotate keys, call a KMS,
enforce live RBAC, modify the workbench, upload artifacts, download artifacts,
write durable storage, or grant mutation authority.

Key ids and key owner labels are references only. They must never contain key
material, secrets, credentials, recovery phrases, tokens, or raw KMS responses.

## Encryption Domains

The policy names five encryption domains:

- `local-private-cache`: local developer artifacts that should remain private
  and short-lived.
- `ci-retained-bundle`: reviewed CI artifacts retained under CI retention
  rules.
- `production-retained-bundle`: production causal bundles retained through the
  NenDB adapter path after review.
- `incident-restricted-bundle`: incident evidence requiring incident owner or
  auditor context.
- `external-summary`: redacted summaries safe for external review without raw
  JSON, DOT, or event payload access.

Each domain declares whether encryption, redaction review, rotation evidence,
and agent raw access are required or denied. Agents may cite encrypted artifact
metadata, but raw encrypted bundle access is denied for agent-readonly flows.

## Key Ownership

Key owners are policy labels:

- `maintainer`
- `release-owner`
- `incident-owner`
- `auditor`
- `agent-readonly`

Only human review roles can own encryption key evidence. `agent-readonly` can
cite policy records and redacted metadata, but it cannot own, unwrap, rotate,
or request raw encryption keys.

## Rotation Evidence

Rotation records must cite:

- encryption domain;
- key id reference;
- key owner label;
- rotation reason;
- rotation evidence id;
- last rotation reference;
- next review reference;
- verification command;
- mutation authority.

Supported rotation reasons are `scheduled`, `incident`, `key-compromise`, and
`policy-change`. `mutation_authority` remains `none`.

## Encrypted Artifact Fixture

The deterministic fixture records encrypted metadata for a reviewed retained
bundle. It proves that future storage adapters have a stable shape to emit and
that agents have stable fields to inspect:

- artifact id;
- encryption domain;
- source schema;
- access decision id;
- redaction state;
- key id reference;
- key owner label;
- rotation evidence id;
- plaintext denied flag;
- encrypted bytes stored flag;
- verification command.

The fixture intentionally stores no plaintext, ciphertext, keys, key material,
or live storage references.

## Redaction Interaction

Redaction review always precedes encryption-at-rest eligibility. Encryption
does not make unsafe plaintext safe to retain, share, or expose. A bundle with
secret-shaped content must be blocked or redacted before encryption policy can
approve retention.

Decryption review fails closed. If future decrypt or unwrap evidence is
missing, stale, or unauthorized, the artifact remains inaccessible even when an
encrypted bundle exists.

Access control still applies after encryption. Encryption approval is not a
permission grant and never becomes source, config, app, registry, deployment,
rollback, storage, or production mutation authority.

## Negative Fixtures

The report includes blocked fixtures for:

- encryption before redaction review;
- missing key owner evidence;
- stale rotation evidence;
- agent key access;
- external reviewer raw bundle access;
- treating encryption approval as mutation authority.

These fixtures are deliberately boring: they let agents test the policy
boundary without touching live secrets or storage.

## Authority Boundaries

Durable evidence remains NenDB adapter work only. This policy does not add
Cockroach, D1, R2, SQL, RoachGraph, or a direct upstream NenDB dependency.

Workbench follow-up remains SolidJS inside `webui-dev/zig-webui`. React is not
part of this path.

Encryption implementation, KMS integration, key generation, live key rotation,
live RBAC, live dashboards, alerting, paging, deployment automation, rollout
automation, and production mutation authority all remain future work.

## Verification Suite

Run:

```sh
cd packages/zigeffect
zig build causal-encryption-at-rest-policy
zig build causal-encryption-at-rest-policy -- --format json
zig build causal-artifact-access-control
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

This contract hands off to `codex/zigeffect-causal-alerting-integrations`. Use
`causal-production-hardening-backlog` for the current branch queue.
