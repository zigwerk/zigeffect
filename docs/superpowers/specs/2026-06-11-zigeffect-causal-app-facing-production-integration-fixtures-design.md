# zigeffect Causal App-Facing Production Integration Fixtures Design

Branch: `codex/zigeffect-causal-app-facing-production-integration-fixtures`

## Purpose

This branch creates the first deterministic production-integration fixture
surface for apps built with zigeffect. The goal is to let agents reason about
how app-facing causal traces, app remediation governance, agent queries,
retained audit-chain comparison, production telemetry fixture boundaries, and
NenDB durable-history evidence fit together before any live production
telemetry, durable writes, app mutation, or operational automation exists.

The output is a schema-governed fixture catalog and validation report, not a
runtime exporter or production adapter. It should be useful immediately to:

- developers building zigeffect itself;
- agents reviewing effectzig/zigeffect apps;
- future readiness-review branches that need a stable source fixture;
- the SolidJS `zig-webui` workbench roadmap;
- NenDB-only durable history planning.

## Current Context

The project already has these relevant pieces:

- `CausalAppTrace` emits app request and background-job evidence as bounded
  `zigeffect.causal.v1` runtime events, with app-facing schema metadata
  governed as `zigeffect.causal.app-runtime.v1`.
- App semantic APIs emit redacted refs for reads, writes, transforms, service
  calls, domain actions, policy decisions, emitted artifacts, and responses.
- `causal-query --agent trace_data` and `compare_runs` provide compact
  machine-native query output under `zigeffect.causal.agent-query.v1`.
- App remediation artifacts already form a non-mutating governance chain:
  audit, policy decision, human review, patch proposal, application readiness,
  and guarded application evidence.
- `causal-snapshot -- audit-chain-compare` emits
  `zigeffect.causal.audit-chain-snapshot-compare.v1` for retained audit-chain
  before/after review without treating audit artifacts as core runtime event
  arrays.
- `causal-nendb-durable-history-hardening` emits
  `zigeffect.causal.nendb-durable-history.v1` for NenDB-only durable-history
  evidence.
- `causal-production-telemetry-capture-fixtures` provides the existing
  fixture-only CLI pattern for source contracts, positive fixtures, negative
  fixtures, validation checks, non-goals, and agent guidance.

This branch should connect those surfaces into one app-facing production
integration contract.

## Goals

1. Add a deterministic CLI:
   `zig build causal-app-facing-production-integration-fixtures`.
2. Emit a new schema:
   `zigeffect.causal.app-facing-production-integration-fixtures.v1`.
3. Provide `catalog`, `emit <fixture-id>`, and `validate` modes with
   `--format text|json`.
4. Model app-facing production evidence as fixture records that connect:
   app runtime traces, app semantic refs, agent query output, audit-chain
   snapshot comparison, app remediation governance, production telemetry
   capture fixtures, and NenDB durable-history evidence.
5. Preserve hard boundaries:
   `applied=false`, `mutation_authority=none`,
   `production_telemetry_ingestion=false`, `live_exporter_enabled=false`,
   `durable_write_enabled=false`, `app_mutation_enabled=false`,
   `ci_gate_enabled=false`.
6. Make negative fixtures explicit so agents can reject unsafe inferences.
7. Register the schema in governance docs/tooling.
8. Mark the production-hardening backlog item as delivered and hand off to the
   next readiness-review branch.

## Non-Goals

This branch must not implement:

- live production telemetry ingestion;
- OTLP, collector, network, or hosted telemetry exporter behavior;
- production durable writes;
- Cockroach or any non-NenDB durable adapter work;
- request body, header, prompt, credential, token, tenant id, raw user id, or
  PII capture;
- app source, config, migration, rollout, deployment, data, registry, or
  operational mutation;
- CI enforcement gates;
- production workbench hosting;
- React or alternate renderer work.

The durable direction remains NenDB adapter only. The UI direction remains
SolidJS inside `webui-dev/zig-webui`.

## Design Options Considered

### Option A: Extend production telemetry capture fixtures

This would add app-facing records to
`causal-production-telemetry-capture-fixtures`.

Pros:

- fewer commands;
- existing fixture schema and tests are already familiar.

Cons:

- production telemetry capture and app-facing integration have different
  review questions;
- the app chain also needs audit-chain comparison, agent-query, remediation,
  and NenDB handoff semantics;
- the existing telemetry fixture would become too broad.

### Option B: Add a readiness review directly

This would skip a fixture catalog and go straight to a readiness review over
app production integration.

Pros:

- faster path toward an application boundary;
- mirrors later production telemetry governance steps.

Cons:

- reviewers and agents would not have stable positive and negative fixtures;
- unsafe inferences would be harder to test;
- the readiness tool would need to define its own source contract.

### Option C: Add a dedicated fixture-only app integration catalog

This creates a focused CLI and schema that composes existing source contracts
without granting implementation authority.

Pros:

- keeps production telemetry fixtures, app remediation governance, NenDB
  history, and audit-chain comparison distinct but connected;
- gives future readiness/application branches a stable input;
- lets agents cite fixture ids and blocked claims;
- maintains the current no-mutation roadmap discipline.

Cons:

- adds another schema and build target;
- requires backlog and schema-governance updates.

Recommendation: Option C. It is the smallest useful branch that advances the
roadmap without confusing fixture evidence with live production behavior.

## CLI Contract

Create:

`packages/zigeffect/tools/causal_app_facing_production_integration_fixtures.zig`

Build target:

```bash
cd packages/zigeffect
zig build causal-app-facing-production-integration-fixtures
zig build causal-app-facing-production-integration-fixtures -- --format json
zig build causal-app-facing-production-integration-fixtures -- emit worker-request-redacted-lineage --format json
zig build causal-app-facing-production-integration-fixtures -- validate --format json
```

Modes:

- default/catalog: print the full catalog;
- `emit <fixture-id>`: print one positive fixture;
- `validate`: print validation checks only.

Unsupported modes, unknown fixture ids, missing fixture ids, missing format
values, and unknown formats should fail with a usage message.

## Schema And Metadata

Constants:

```zig
pub const app_facing_production_integration_fixtures_schema =
    "zigeffect.causal.app-facing-production-integration-fixtures.v1";
pub const app_facing_production_integration_fixtures_schema_version: u32 = 1;
pub const source_branch =
    "codex/zigeffect-causal-app-facing-production-integration-fixtures";
pub const recommendation =
    "start-app-facing-production-integration-readiness-review";
pub const next_branch =
    "codex/zigeffect-causal-app-facing-production-integration-readiness-review";
```

Header fields:

- `schema`;
- `schema_version`;
- `status="fixtures-only"`;
- `generated_by="causal-app-facing-production-integration-fixtures"`;
- `source_branch`;
- `recommendation`;
- `next_branch`;
- `applied=false`;
- `mutation_authority="none"`;
- `production_telemetry_ingestion=false`;
- `live_exporter_enabled=false`;
- `durable_write_enabled=false`;
- `app_mutation_enabled=false`;
- `ci_gate_enabled=false`.

## Source Contracts

The catalog should define source contracts for:

- `app-runtime`: `zigeffect.causal.app-runtime.v1`, emitted by
  `CausalAppTrace`;
- `agent-query`: `zigeffect.causal.agent-query.v1`, emitted by
  `causal-query --agent`;
- `audit-chain-snapshot-compare`:
  `zigeffect.causal.audit-chain-snapshot-compare.v1`, emitted by
  `causal-snapshot -- audit-chain-compare`;
- `nendb-durable-history`:
  `zigeffect.causal.nendb-durable-history.v1`, emitted by
  `CausalNendbStorageBackendState.durableHistoryReport` and
  `causal-nendb-durable-history-hardening`;
- `production-telemetry-capture-fixtures`:
  `zigeffect.causal.production-telemetry-capture-fixtures.v1`, emitted by
  `causal-production-telemetry-capture-fixtures`;
- `app-remediation-chain`: the existing app remediation schemas for audit,
  policy decision, human review, patch proposal, application readiness, and
  application evidence.

Each source contract needs an `authority_boundary` that states it is
record-only or fixture-only and does not grant production mutation.

## Fixture Record Shape

Each positive fixture should include:

- `fixture_id`;
- `fixture_kind`;
- `integration_surface_id`;
- `source_schema`;
- `app_trace_kind`;
- `signal_kind`;
- `lineage_policy`;
- `redaction_state`;
- `sampling_policy`;
- `retention_policy`;
- `access_policy_ref`;
- `durable_history_ref`;
- `audit_chain_compare_ref`;
- `agent_query_ref`;
- `remediation_chain_ref`;
- `telemetry_transport_state`;
- `durable_write_state`;
- `app_mutation_state`;
- `review_gate`;
- `blocked_claims`;
- `sample_attributes`;
- `expected_agent_use`;
- `forbidden_inference`.

This keeps the app-facing contract richer than the telemetry fixture while
staying compact and deterministic.

## Positive Fixtures

The initial catalog should contain these positive fixtures:

1. `worker-request-redacted-lineage`
   - A Worker request trace using method, route, runtime, service call, data
     refs, domain action refs, and response refs.
   - It proves agents can inspect request lineage without raw bodies, headers,
     prompts, credentials, tenant ids, user ids, or PII.

2. `background-job-nendb-history-handoff`
   - A background-job trace that hands off to NenDB durable-history evidence.
   - It proves job evidence can be retained by reference without writing
     production storage in this branch.

3. `agent-query-app-trace-data`
   - A compact agent-query fixture over app `trace_data` refs.
   - It proves agents should cite bounded query evidence rather than scraping
     raw artifacts or inferring hidden app data.

4. `audit-chain-before-after-app-review`
   - A retained app remediation chain comparison fixture.
   - It proves audit-chain comparison can show before/after governance posture
     and evidence-classification deltas without claiming app mutation occurred.

5. `app-remediation-governance-bridge`
   - A bridge from app incident evidence through audit, policy, human review,
     patch proposal, readiness, and guarded application artifacts.
   - It proves agents can reason about proposed fixes while preserving
     `applied=false` unless separate reviewed application evidence exists.

6. `production-telemetry-fixture-boundary`
   - A link back to production telemetry capture fixtures.
   - It proves app-facing integration can reuse telemetry fixture boundaries
     without enabling live export or collector configuration.

## Negative Fixtures

The negative catalog must reject:

- raw request body capture;
- raw header capture;
- raw prompt capture;
- credential or token capture;
- tenant id, raw user id, or PII capture;
- live production telemetry ingestion;
- live exporter or collector endpoint configuration;
- production durable writes;
- non-NenDB durable adapter work;
- Cockroach adapter work;
- app source, config, migration, data, rollout, deployment, or rollback
  mutation;
- treating audit-chain compare as proof of app mutation;
- treating agent-query output as permission to scrape hidden app payloads;
- CI gate enforcement;
- React or alternate renderer work.

Each negative fixture should include a safe alternative, such as using redacted
refs, citing fixture ids, routing proposals through readiness review, or
limiting durable work to NenDB-compatible retention refs.

## Validation Checks

The `validate` mode should report passing checks for:

- source contract coverage;
- positive fixture coverage across request, job, agent-query, audit-chain,
  remediation, telemetry boundary, and NenDB handoff;
- app redaction and ref-only lineage;
- blocked claim coverage;
- no forbidden values in positive fixtures;
- NenDB-only durable direction;
- no live telemetry/exporter/durable writes/CI gates/app mutation;
- next branch handoff.

Validation is deterministic and local. It must not read live systems, clocks,
networks, generated artifacts, or production files.

## Schema Governance Updates

Add a schema entry:

- schema: `zigeffect.causal.app-facing-production-integration-fixtures.v1`;
- category: `app-runtime`;
- status: `current`;
- emitted by:
  `causal-app-facing-production-integration-fixtures`;
- consumed by:
  `agents`, `reviewers`,
  `future app-facing production integration readiness review`,
  `future SolidJS workbench production app views`;
- compatibility:
  `strict-v1`, `fixture-only`, `record-only`, `nendb-only`,
  `no-cockroach`, `no-live-telemetry`, `no-production-mutation`;
- governance requirements:
  fixture tool tests, source contract coverage, redaction negative fixtures,
  backlog update, docs update.

The schema governance text and JSON tests should assert the new schema appears.

## Backlog Updates

Update:

- `packages/zigeffect/tools/causal_production_hardening_backlog.zig`;
- `packages/zigeffect/docs/production-hardening-backlog.md`;
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`.

The backlog item should be:

- id: `app-facing-production-integration-fixtures`;
- title: `App-Facing Production Integration Fixtures`;
- status after implementation: `delivered`;
- branch:
  `codex/zigeffect-causal-app-facing-production-integration-fixtures`;
- depends on:
  app semantic trace API, agent query interface, audit-chain snapshot compare,
  NenDB durable-history hardening, production telemetry capture fixtures, app
  remediation governance tools.

After delivery, the recommendation should advance to:

`start-app-facing-production-integration-readiness-review`

with branch:

`codex/zigeffect-causal-app-facing-production-integration-readiness-review`

## Documentation Updates

Add a new doc:

`packages/zigeffect/docs/app-facing-production-integration-fixtures.md`

Update the README and agent-observable runtime docs with the CLI command and
the exact boundary:

- fixtures are safe app production integration examples;
- they are not live telemetry;
- they are not durable production writes;
- they are not app mutation;
- they are NenDB-only for durable handoff.

## Testing Strategy

Use TDD for implementation:

1. Start with failing tests in the new Zig tool for schema constants and
   metadata.
2. Add failing tests for source contract coverage.
3. Add failing tests for positive fixture coverage.
4. Add failing tests for negative fixture blocked claims.
5. Add failing tests for JSON/text rendering.
6. Add failing tests for `emit` and `validate` modes.
7. Add failing build integration by registering the tool in `build.zig`.
8. Add failing schema governance and backlog tests, then update the source
   arrays to pass.

Focused verification:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_fixtures.zig
zig build causal-app-facing-production-integration-fixtures
zig build causal-app-facing-production-integration-fixtures -- --format json
zig build causal-app-facing-production-integration-fixtures -- emit worker-request-redacted-lineage --format json
zig build causal-app-facing-production-integration-fixtures -- validate --format json
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

## Agent Use Cases

### zigeffect core development

A development agent can use the fixtures to understand how app-facing
production evidence should eventually flow through the runtime, query layer,
NenDB history, audit-chain comparison, and governance chain. That gives the
core project a stable target while still building locally and safely.

### App issue triage

An app-facing agent can inspect an app trace, ask for `trace_data`, compare
before/after audit-chain posture, and propose a remediation path. The fixtures
teach it to cite event ids, query ids, fixture ids, and review gates instead of
guessing from raw payloads.

### Future readiness review

The next branch can consume the fixture catalog and decide whether the app
production integration surface is ready for a reviewed implementation proposal.
It should not have to rediscover source contracts or negative boundaries.

### Workbench planning

The SolidJS `zig-webui` workbench can later render these fixture categories as
read-only production app evidence views. This branch should not implement that
UI, but it should keep fixture ids and source contract names stable enough for
future workbench panels.

## Risks And Mitigations

Risk: agents may treat fixtures as proof of production state.
Mitigation: every header and fixture carries fixture-only status, no live
telemetry, no durable write, no app mutation, and forbidden inference fields.

Risk: app integration scope expands into production telemetry exporter work.
Mitigation: telemetry transport state remains disabled and the existing
production telemetry fixture schema is referenced as a source contract only.

Risk: durable scope drifts toward Cockroach or another adapter.
Mitigation: validation checks and negative fixtures enforce NenDB-only durable
direction.

Risk: audit-chain comparison is misread as proof a source/app change happened.
Mitigation: negative fixtures explicitly reject that inference unless separate
reviewed application evidence exists.

Risk: the branch becomes another giant roadmap document without a runnable
artifact.
Mitigation: the implementation must ship a runnable CLI, JSON/text output,
schema governance tests, backlog tests, and docs.

## Acceptance Criteria

The branch is complete when:

- `causal-app-facing-production-integration-fixtures` builds and runs;
- text and JSON catalog output include the new schema and all fixture classes;
- `emit worker-request-redacted-lineage --format json` emits a single fixture;
- `validate --format json` emits validation checks only;
- tests cover schema constants, source contracts, fixtures, negative claims,
  output modes, and JSON escaping;
- schema governance includes the new schema;
- production hardening backlog marks the item delivered and advances the
  recommendation;
- docs explain the command and boundaries;
- focused and full verification commands pass.

## Spec Self-Review

- Placeholder scan: no placeholders, TODOs, or open-ended implementation
  requirements remain.
- Internal consistency: schema name, command name, branch name, recommendation,
  and next branch are consistent throughout.
- Scope check: this is one fixture-only sub-project and does not include the
  future readiness-review implementation.
- Ambiguity check: fixture evidence is defined as non-mutating, local,
  deterministic, NenDB-only for durable handoff, and not live production
  telemetry.
