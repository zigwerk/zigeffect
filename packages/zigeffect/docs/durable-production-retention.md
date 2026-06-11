# zigeffect Causal Durable Production Retention

`causal-durable-production-retention` is the deterministic retention contract
for production-hardening work after artifact aggregation. It defines how
reviewed aggregation bundles should become durable, recoverable causal
evidence through the NenDB adapter path.

## Command

```sh
cd packages/zigeffect
zig build causal-durable-production-retention
zig build causal-durable-production-retention -- --format json
```

The JSON report uses schema
`zigeffect.causal.durable-production-retention.v1`.

## Relationship To Artifact Aggregation

Durable retention consumes the source contract from
`zigeffect.causal.production-artifact-aggregation.v1`. It does not invent a new
source shape. Every retained source keeps aggregation provenance such as source
kind, artifact class, schema, retention state, redaction state, trust boundary,
and recovery hint.

Paths in aggregation artifacts remain provenance, not proof that a file exists.
This branch does not scan `.zig-cache`, pull CI artifacts, or ingest production
telemetry.

## NenDB-Only Retention Policy

The retention policy is NenDB adapter work only:

- storage adapter: NenDB adapter;
- TTL: 14 days for the current local/CI fixture policy;
- max events per retained bundle: 4096;
- compaction trigger: 2048 events;
- compaction target: 1024 events;
- backup required: yes;
- recovery verification required: yes.

The zigeffect adapter also exposes `CausalNendbRetentionPolicy` and
`CausalNendbRetentionReport` so tests and future agents can evaluate retained
NenDB history without granting production mutation authority. The adapter
report uses schema `zigeffect.causal.nendb-retention-report.v1`.

The follow-up NenDB durable-history hardening branch adds
`CausalNendbDurableHistoryReport` and
`zigeffect.causal.nendb-durable-history.v1` as the runtime evidence layer for
writer, flush, redaction, bounded-history, and query posture. That report is
still record-only local evidence; it does not perform durable production writes,
compaction, backup, restore, TTL deletion, or production health validation.

## TTL Policy

TTL is policy-only in this branch. `CausalEvent` does not currently carry a
wall-clock timestamp, and deterministic tools must not read clocks or live
systems. Future durable records must carry capture metadata before age-based
deletion can be enforced.

When timestamp metadata is missing, agents should treat TTL evidence as
incomplete rather than silently satisfied.

## Compaction Policy

Compaction is reported, not executed. The contract says a retained bundle is
eligible for compaction after the trigger threshold, and future compaction must
preserve run roots, terminal failures, finding evidence, governance artifacts,
and recovery lineage.

## Backup And Recovery

Backup records must include:

- retained bundle id;
- source count;
- schema;
- oldest retained event id;
- newest retained event id;
- redaction state;
- privacy gate result.

Recovery evidence must prove queryable causal lineage after restore, not only
the presence of raw bytes. Restore remains record-only until a reviewed
authority branch grants mutation power.

## Retention Gates

Durable retention requires:

- aggregation contract present;
- redaction review complete;
- TTL metadata present for future age enforcement;
- backup/recovery fixture evidence.

If a gate fails, the retained bundle should remain local, blocked, or marked
incomplete.

## Authority Boundaries

This contract does not add Cockroach, D1, R2, SQL, RoachGraph, or a direct
upstream NenDB dependency.

It does not ingest production telemetry, open production dashboards, enforce
RBAC, encrypt data, page humans, deploy services, run rollouts, or grant
source/config/app/registry/production mutation authority.

Workbench follow-up remains SolidJS inside `webui-dev/zig-webui`. React remains
a non-goal for this path.

## Deployment Runbooks Handoff

Durable retention now hands off to
[production-deployment-runbooks.md](production-deployment-runbooks.md). That
contract consumes this schema plus the aggregation schema and defines manual
deploy, rollback, causal verification, and incident-response gates. It does
not automate deployment or rollback and does not grant production mutation
authority.

## Verification Suite

Run:

```sh
cd packages/zigeffect
zig build causal-durable-production-retention
zig build causal-durable-production-retention -- --format json
zig build causal-production-deployment-runbooks
zig build causal-production-deployment-runbooks -- --format json
zig build causal-nendb-storage-backend
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
