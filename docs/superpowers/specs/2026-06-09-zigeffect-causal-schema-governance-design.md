# zigeffect Causal Schema Governance Design

Date: 2026-06-09

## Purpose

M9 starts the production operating model for the causal self-improvement
runtime. The first gap is schema governance: zigeffect now emits and consumes
many causal artifacts, but agents and contributors still have to scrape code to
answer basic questions:

- which artifact schemas exist;
- which version is current;
- which tools produce or consume each schema;
- whether old artifacts remain readable;
- which checks are required before a schema changes.

This branch adds an authoritative schema governance surface. It should let a
development agent reason about causal artifact compatibility before changing
tooling, app remediation flows, durable adapters, or workbench support.

## Current Context

The codebase already has real compatibility foundations:

- core causal JSON uses `schema="zigeffect.causal.v1"`,
  `schema_version=1`, and `event_taxonomy_version=1`;
- `causal_artifact.zig` warns on unsupported core schema names, future
  `schema_version`, future `event_taxonomy_version`, and unknown event kinds;
- `causal-query`, `causal-compare`, `causal-loop`, and `causal-advice` parse
  legacy/current/future core artifacts with compatibility warnings;
- governance, registry, snapshot/replay, workbench, backend, and app
  remediation tools emit their own `*.v1` artifact families;
- the SolidJS workbench recognizes governance and app remediation schemas.

The missing piece is a single checked inventory. Right now schema constants are
spread across `src/services/*.zig`, `tools/*.zig`, tests, README sections, and
roadmap docs.

## Chosen Approach

Create a new report tool:

```sh
zig build causal-schema-governance
zig build causal-schema-governance -- --format json
zig build causal-schema-governance -- --format text
```

Default format is text. JSON output is machine-readable and uses:

```text
zigeffect.causal.schema-governance.v1
```

The report is static and intentionally explicit in v1. It records every
official causal artifact schema with category, version, producer, consumer,
compatibility posture, and governance requirements. The static inventory is
safer than runtime source scraping because it forces every new artifact family
to be reviewed and added intentionally.

## Alternatives Considered

### A: Documentation-only matrix

This would be fast, but agents and CI would not have a machine-readable
surface. Documentation can drift from code without a test failing.

### B: Runtime source-code scanner

Scanning Zig sources for `"zigeffect.causal.*.v1"` would find strings, but it
would also include test-only fake schemas such as `zigeffect.causal.other.v1`
and `zigeffect.causal.unknown.v1`. It cannot infer producers, consumers, or
compatibility posture reliably.

### C: Static governance registry plus report tool

This is the selected approach. It is small, deterministic, testable, and
explicit enough for agents. It can later become the source for CI drift checks
or generated docs without changing the artifact contract.

## Official Schema Inventory

The v1 inventory should include these official schemas:

- `zigeffect.causal.v1`
- `zigeffect.causal.event.v1`
- `zigeffect.causal.otel_record.v1`
- `zigeffect.causal.nendb_node.v1`
- `zigeffect.causal.nendb_edge.v1`
- `zigeffect.causal.app-runtime.v1`
- `zigeffect.causal.dev-loop-verdict.v1`
- `zigeffect.causal.dev-session.v1`
- `zigeffect.causal.ci-verdict.v1`
- `zigeffect.causal.workbench-session.v1`
- `zigeffect.causal.test-matrix.v1`
- `zigeffect.causal.remediation-audit.v1`
- `zigeffect.causal.remediation-decision.v1`
- `zigeffect.causal.patch-proposal.v1`
- `zigeffect.causal.audit-chain.v1`
- `zigeffect.causal.scenario-proposal.v1`
- `zigeffect.causal.registry-patch.v1`
- `zigeffect.causal.registry-application-readiness.v1`
- `zigeffect.causal.registry-application.v1`
- `zigeffect.causal.policy-decision.v1`
- `zigeffect.causal.snapshot-manifest.v1`
- `zigeffect.causal.snapshot-compare.v1`
- `zigeffect.causal.replay-feasibility.v1`
- `zigeffect.causal.deterministic-replay.v1`
- `zigeffect.causal.scenario-fork-proposal.v1`
- `zigeffect.causal.app-remediation-audit.v1`
- `zigeffect.causal.app-policy-decision.v1`
- `zigeffect.causal.app-human-review.v1`
- `zigeffect.causal.app-patch-proposal.v1`
- `zigeffect.causal.app-application-readiness.v1`
- `zigeffect.causal.app-application.v1`

Do not include test-only fake schemas in the official matrix:

- `zigeffect.causal.other.v1`
- `zigeffect.causal.unknown.v1`

## Compatibility Postures

The report should use a small controlled vocabulary:

- `legacy-tolerant`: current tools accept missing schema metadata and keep
  event ids usable.
- `warn-forward`: current tools parse the known shape and warn when schema,
  taxonomy, or event-kind semantics are newer than supported.
- `strict-v1`: consuming tools require the exact schema family, version `1`,
  and mode where applicable.
- `sink-contract`: backend/export rows are emitted for downstream systems and
  guarded by adapter tests rather than causal query compatibility.
- `record-only`: artifacts can record review/application state but do not
  mutate source or external systems.
- `viewer-session`: workbench/session artifacts are local read-only operating
  state and not remediation authority.

Most core causal JSON entries use `legacy-tolerant` and `warn-forward`.
Governance chain inputs use `strict-v1`. Application artifacts use
`record-only` in addition to strict schema validation by downstream consumers.

## Versioning Policy

The report and docs should define these rules:

- `schema` names the artifact family and should change only for incompatible
  family changes.
- `schema_version` is an integer for the current shape inside that family.
- Additive optional fields within an existing family may keep the same
  `schema_version` only when all current consumers ignore unknown fields and
  tests prove graceful behavior.
- Required fields, renamed fields, removed fields, or semantic changes must
  bump `schema_version` and add compatibility tests.
- New event kinds, finding roles, or sampleability semantics must bump
  `event_taxonomy_version`.
- New artifact families must add schema docs, governance registry entries,
  build/test coverage, and workbench mapping when user-facing.

## Migration Policy

The v1 migration policy is documentation and compatibility reporting, not a
rewriter:

- legacy core causal artifacts without root schema metadata remain readable;
- current tools should warn, not crash, on newer core schema/taxonomy versions
  when event ids can still be cited;
- strict governance artifacts that fail schema/version checks should remain
  blocked rather than guessed;
- migration tooling for rewriting old artifacts is deferred until a real v2
  artifact exists.

## JSON Output

`--format json` should emit:

```json
{
  "schema": "zigeffect.causal.schema-governance.v1",
  "schema_version": 1,
  "current_core_schema": "zigeffect.causal.v1",
  "current_core_schema_version": 1,
  "current_event_taxonomy_version": 1,
  "schema_count": 31,
  "policy": {
    "versioning": "schema names artifact family; schema_version tracks family shape; event_taxonomy_version tracks event-kind role semantics",
    "migration": "legacy core artifacts remain readable; strict governance artifacts fail closed; rewrite tooling is deferred until a real v2 exists",
    "new_schema_requirements": [
      "schema name",
      "schema_version",
      "producer",
      "consumer",
      "compatibility posture",
      "tests",
      "docs"
    ]
  },
  "schemas": [
    {
      "schema": "zigeffect.causal.v1",
      "version": 1,
      "category": "core-runtime",
      "status": "current",
      "emitted_by": ["formatCausalJson"],
      "consumed_by": ["causal-query", "causal-compare", "causal-loop", "causal-advice", "causal-workbench"],
      "compatibility": ["legacy-tolerant", "warn-forward"],
      "governance_requirements": ["compatibility tests", "taxonomy warning tests", "docs"]
    }
  ]
}
```

All official entries should use `version=1` in this branch.

## Text Output

Default text output should be easy to scan:

```text
zigeffect causal schema governance
schema: zigeffect.causal.schema-governance.v1
schema_version: 1
core schema: zigeffect.causal.v1 version 1
event taxonomy version: 1
schema count: 31

versioning policy:
- schema names artifact family
- schema_version tracks family shape
- event_taxonomy_version tracks event-kind role semantics

schemas:
- zigeffect.causal.v1
  version: 1
  category: core-runtime
  compatibility: legacy-tolerant, warn-forward
  emitted by: formatCausalJson
  consumed by: causal-query, causal-compare, causal-loop, causal-advice, causal-workbench
```

## Build Integration

Add:

```sh
zig build causal-schema-governance
```

The module should be tested by:

```sh
cd packages/zigeffect
zig build test
zig build examples
```

`examples` should compile the executable and run its tests, matching the rest
of the causal tool suite.

## Documentation Updates

Add:

- `packages/zigeffect/docs/schema-governance.md`

Update:

- `packages/zigeffect/README.md`
- `packages/zigeffect/docs/agent-guide.md`
- `packages/zigeffect/docs/agent-observable-runtime.md`
- `packages/zigeffect/docs/roadmap.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

The master roadmap should move M9 from `deferred` to `active` or partial, and
the immediate queue should advance to `codex/zigeffect-causal-operations-docs`
after this branch.

## Non-Goals

- No artifact migration rewriter.
- No schema auto-scanner.
- No broad refactor of existing schema constants.
- No workbench UI changes.
- No durable backend work.
- No NenDB adapter change.
- No Cockroach adapter work.
- No CI workflow mutation in this branch; CI ownership belongs to the
  operations-docs branch.

## Test Plan

Zig tests:

- usage names `causal-schema-governance`;
- the schema inventory contains every official schema listed above;
- test-only fake schemas are not in the inventory;
- every entry has `version=1`, non-empty category, producer, consumer, and
  compatibility posture;
- text output includes schema count, core schema, taxonomy version, versioning
  policy, migration policy, and representative app/registry/snapshot schemas;
- JSON output includes `schema`, `schema_version`, `schema_count`, `policy`,
  and `schemas`;
- `--format json` and `--format text` parse correctly;
- unknown format fails closed.

Docs verification:

```sh
git diff --check
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

## Acceptance Criteria

- `zig build causal-schema-governance` prints a complete text report.
- `zig build causal-schema-governance -- --format json` prints the JSON
  governance artifact.
- The report lists all official current causal schemas and excludes fake test
  schemas.
- Contributors have a documented rule for when to bump `schema`,
  `schema_version`, or `event_taxonomy_version`.
- Agents have a stable compatibility matrix to consult before changing causal
  artifact producers or consumers.
- The roadmap identifies operations docs as the next M9 branch.
