# zigeffect Causal Production Artifact Aggregation Design

Date: 2026-06-09

## Purpose

This branch defines the first production-hardening contract after the M9
operating model: a deterministic production artifact aggregation report. The
report gives future durable retention, access control, dashboards,
integrations, rollout evidence, benchmark baselines, and capacity planning a
stable bundle and provenance contract to consume.

This branch must not implement live production ingestion, durable storage,
dashboards, alerting, RBAC, encryption, rollout automation, or mutation
authority. It should define the contract those later systems must satisfy.

## Source Evidence

The immediate branch queue points here from:

- `packages/zigeffect/tools/causal_production_hardening_backlog.zig`;
- `packages/zigeffect/docs/production-hardening-backlog.md`;
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`.

Existing local/CI artifact evidence comes from:

- `packages/zigeffect/tools/causal_artifacts.zig`;
- `.github/workflows/zigeffect-causal.yml`;
- `packages/zigeffect/tools/causal_handoff.zig`;
- `packages/zigeffect/docs/operations.md`;
- `packages/zigeffect/docs/causal-scenarios.md`;
- `packages/zigeffect/workbench/src/causalArtifact.ts`.

## Constraints

- The report is deterministic and must not read live files, clocks, networks,
  CI APIs, production telemetry, or local `.zig-cache` contents.
- It is record-only. It cannot ingest, upload, store, encrypt, route, alert,
  deploy, roll back, mutate source, mutate config, or grant runtime authority.
- Durable follow-up work remains NenDB adapter work only.
- Workbench follow-up work remains SolidJS inside `webui-dev/zig-webui`.
- Privacy review is modeled as an explicit gate. This branch must not claim
  automatic PII classification or complete production privacy compliance.

## Selected Approach

Add a deterministic Zig report tool:

```sh
zig build causal-production-artifact-aggregation
zig build causal-production-artifact-aggregation -- --format json
```

The report uses schema
`zigeffect.causal.production-artifact-aggregation.v1`.

It emits four contract sections:

- `bundle_contract`: stable bundle identity, artifact classes, required
  metadata fields, and consumer expectations;
- `source_provenance_fields`: source-kind, path, schema, producer, capture
  context, trust boundary, redaction state, retention state, and query hints;
- `privacy_review_gates`: redaction review, truncation review, sharing review,
  unsupported-schema review, and production-sensitive-source review;
- `sample_bundle`: a deterministic local/CI multi-source fixture that references
  existing artifact families without reading generated artifacts.

The report also emits non-goals, verification commands, and
`recommended_next_branch = codex/zigeffect-causal-durable-production-retention`.

## Considered Alternatives

### Markdown-Only Contract

This would be quick, but agents would have to parse prose before durable
retention and workbench branches can depend on the fields. A schema-governed
JSON report is more consistent with the existing causal tooling.

### Live Aggregator Prototype

A live prototype would be tempting, but it would prematurely decide ingestion,
storage, authentication, access control, and retention behavior. The current
roadmap needs the contract first.

### Extend `causal-artifacts`

`causal-artifacts` owns local/CI upload globs and known paths. Aggregation is a
different responsibility: it describes how multiple artifact sources become a
production-ready bundle with provenance and review gates. Keeping a separate
tool preserves the existing manifest.

## Artifact Shape

The JSON report should include:

- `schema`;
- `schema_version`;
- `status`;
- `generated_by`;
- `recommendation`;
- `recommended_next_branch`;
- `bundle_contract`;
- `source_provenance_fields`;
- `privacy_review_gates`;
- `sample_bundle`;
- `non_goals`;
- `verification_commands`.

The text report should mirror those sections for human review.

## Bundle Contract

The initial contract should define:

- stable bundle id format;
- supported source kinds: `ci-baseline`, `ci-head`, `ci-handoff`, `local-dev`,
  `registered-scenario`, `governance-chain`, and `app-remediation`;
- supported artifact classes: `core-runtime`, `handoff`, `advice`, `compare`,
  `governance`, `app-remediation`, `snapshot`, and `workbench-session`;
- required provenance fields for every source;
- required privacy review gates before sharing or retaining a bundle;
- downstream consumers: durable retention, access control, workbench,
  integrations, rollout evidence, benchmarks, and capacity planning.

## Sample Bundle

The deterministic sample bundle should include local/CI-style source records:

- CI baseline dogfood core artifact;
- CI head dogfood core artifact;
- CI verdict or handoff artifact;
- dev-loop audit-chain artifact;
- app remediation application artifact.

Each sample source should include a path, schema family, producer, source kind,
capture context, trust boundary, redaction state, retention state, and query
hint. The sample is a contract fixture, not a file existence check.

## Backlog Update

This branch should update `causal-production-hardening-backlog` after the
aggregation contract lands:

- mark `production-artifact-aggregation` as `delivered`;
- change recommendation to `start-durable-production-retention`;
- change recommended next branch to
  `codex/zigeffect-causal-durable-production-retention`;
- keep all later production-hardening items planned.

The master roadmap and package docs should make the same handoff.

## Documentation Updates

Add `packages/zigeffect/docs/production-artifact-aggregation.md` explaining:

- what the command emits;
- how the bundle contract differs from live ingestion;
- required source provenance fields;
- privacy review gates;
- how future durable retention should consume the contract;
- why NenDB, SolidJS plus `zig-webui`, and no mutation authority remain the
  standing constraints.

Update:

- `packages/zigeffect/README.md`;
- `packages/zigeffect/docs/operations.md`;
- `packages/zigeffect/docs/production-hardening-backlog.md`;
- `packages/zigeffect/docs/schema-governance.md`;
- `packages/zigeffect/docs/roadmap.md`;
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`.

## Verification

The branch should pass:

- `cd packages/zigeffect && zig build causal-production-artifact-aggregation`;
- `cd packages/zigeffect && zig build causal-production-artifact-aggregation -- --format json`;
- `cd packages/zigeffect && zig build causal-production-hardening-backlog`;
- `cd packages/zigeffect && zig build causal-schema-governance`;
- `cd packages/zigeffect && zig build examples`;
- `cd packages/zigeffect && zig build test`;
- `bun run check`;
- `bun run zig:test`;
- `git diff --check`.

## Self-Review

- No placeholders or unresolved questions remain.
- The branch scope is a contract artifact, not production ingestion.
- The design keeps NenDB-only durable direction, SolidJS plus `zig-webui`, and
  no production mutation authority.
- The backlog handoff advances to durable production retention only after this
  contract exists.
