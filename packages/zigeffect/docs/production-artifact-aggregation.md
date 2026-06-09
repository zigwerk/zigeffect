# zigeffect Causal Production Artifact Aggregation

`causal-production-artifact-aggregation` is the deterministic contract report
for future production artifact bundles. It defines how multiple local, CI,
governance, and app remediation artifacts should be described before durable
retention, access control, dashboards, integrations, rollout evidence,
benchmarks, or capacity planning consume them.

## Command

```sh
cd packages/zigeffect
zig build causal-production-artifact-aggregation
zig build causal-production-artifact-aggregation -- --format json
```

The JSON report uses schema
`zigeffect.causal.production-artifact-aggregation.v1`.

## What The Contract Means

The report is a contract fixture. It does not inspect `.zig-cache`, read live CI
artifacts, ingest production telemetry, write durable records, open dashboards,
page humans, enforce access control, encrypt data, deploy changes, or grant
mutation authority.

Use the report before durable production retention. The
`causal-durable-production-retention` report consumes this bundle contract
instead of inventing its own source shape.

## Bundle Contract

The bundle contract defines:

- stable bundle id format;
- required provenance fields for every source;
- supported source kinds such as `ci-baseline`, `ci-head`, `ci-handoff`,
  `local-dev`, `registered-scenario`, `governance-chain`, and
  `app-remediation`;
- supported artifact classes such as `core-runtime`, `handoff`, `governance`,
  `app-remediation`, `snapshot`, and `workbench-session`;
- downstream consumers such as durable retention, access control, the SolidJS
  `zig-webui` workbench, integrations, rollout evidence, benchmarks, and
  capacity planning.

## Source Provenance Fields

Every aggregated source must include:

- `id`;
- `path`;
- `schema`;
- `producer`;
- `source_kind`;
- `artifact_class`;
- `capture_context`;
- `trust_boundary`;
- `redaction_state`;
- `retention_state`;
- `query_hint`.

The contract records a path as provenance, not proof that a file exists.

## Privacy Review Gates

The report defines required gates for:

- redaction review;
- truncation review;
- unsupported schema review;
- sharing-boundary review;
- production-sensitive source review.

If a gate fails, the bundle should be blocked, trimmed, or treated as
incomplete before sharing or durable retention. Redaction remains a
deterministic backstop, not complete PII classification.

## Sample Bundle

The deterministic sample bundle references these local/CI-style sources:

- CI baseline dogfood artifact;
- CI head dogfood artifact;
- CI verdict artifact;
- dev-loop audit-chain artifact;
- app application artifact.

The sample is useful for agents and future tests because it shows the required
shape without depending on generated files.

## Authority Boundaries

Durable follow-up work remains NenDB adapter work only. This contract does not
add a Cockroach adapter.

Durable retention is documented in
[durable-production-retention.md](durable-production-retention.md). It defines
the NenDB-only TTL, compaction, backup, recovery, and retained-bundle fixture
contract that consumes this aggregation shape.

Workbench follow-up work remains SolidJS inside `webui-dev/zig-webui`. This
contract does not add React workbench support.

Mutation authority remains `none`. This report does not grant source, config,
registry, app, deployment, rollout, or production mutation authority.

## Verification Suite

Run:

```sh
cd packages/zigeffect
zig build causal-production-artifact-aggregation
zig build causal-production-artifact-aggregation -- --format json
zig build causal-durable-production-retention
zig build causal-production-hardening-backlog
zig build causal-schema-governance
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
