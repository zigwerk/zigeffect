# zigeffect Causal Production Telemetry Capture Fixtures Design

## Summary

Add deterministic production telemetry capture fixtures for zigeffect. The
fixtures should model what approved production telemetry records would look
like after redaction, sampling, retention, access, encryption, and OTel bridge
review, while still proving that no live production telemetry capture exists.

This branch is still record-only. It must not enable a live exporter, configure
an OTLP collector, read production systems, send network telemetry, write
durable production storage, create CI telemetry gates, size production
capacity, add non-NenDB adapter work, switch the workbench renderer, or grant
mutation authority.

## Branch

- Branch: `codex/zigeffect-causal-production-telemetry-capture-fixtures`
- Schema: `zigeffect.causal.production-telemetry-capture-fixtures.v1`
- Command: `zig build causal-production-telemetry-capture-fixtures`
- Recommendation: `start-production-telemetry-readiness-review`
- Next branch: `codex/zigeffect-causal-production-telemetry-readiness-review`

## Context

The production telemetry capture design report is delivered. It defines the
approved capture surfaces, future telemetry fields, readiness gates, negative
fixtures, and non-goals. The next useful milestone is to turn that design into
machine-readable fixture records that agents can use as examples and validation
evidence before any live telemetry capture work exists.

Relevant upstream source contracts:

- `zigeffect.causal.production-telemetry-capture-design.v1` defines approved
  capture surfaces, required fields, readiness gates, blocked claims, and
  negative fixture ids.
- `zigeffect.causal.load-test-observation-harness.v1` provides local advisory
  observations that may be referenced but never promoted to production
  evidence.
- `zigeffect.causal.otel_record.v1` defines exporter-neutral span and span
  event records without requiring OTLP serialization or network sends.
- `zigeffect.causal.backend-conformance.v1` proves assigned, redacted, bounded
  stored event behavior and sampled-out exclusion.
- `zigeffect.causal.production-artifact-aggregation.v1` defines source
  provenance, redaction state, trust boundary, and aggregation review.
- `zigeffect.causal.artifact-access-control.v1` defines redacted-only access
  review before retained evidence is shared.
- `zigeffect.causal.encryption-at-rest-policy.v1` defines key ownership,
  redaction ordering, and encrypted artifact fixture policy before retained
  production storage exists.
- `zigeffect.causal.production-capacity-planning.v1` records capacity planning
  assumptions and negative capacity fixtures, but remains planning-only.
- `zigeffect.causal.production-hardening-backlog.v1` currently recommends this
  branch while preserving NenDB-only durable direction, SolidJS inside
  `webui-dev/zig-webui`, and `mutation_authority=none`.

## Goals

1. Add a schema-governed fixture catalog that covers every approved capture
   surface from the production telemetry capture design report.
2. Emit positive fixture records that carry every required telemetry field.
3. Emit negative fixture records for every forbidden claim from the design
   report.
4. Add deterministic validation that verifies fixture field coverage, forbidden
   value absence, and blocked-claim coverage.
5. Provide text and JSON output so humans, agents, and future tools can consume
   the fixtures.
6. Keep local observation refs separate from production telemetry evidence.
7. Update schema governance, production hardening backlog, README, operations,
   roadmap, and the master roadmap with the delivered fixture milestone.
8. Hand off to a readiness-review branch that can audit whether fixture
   coverage is enough to consider any later telemetry implementation proposal.

## Non-Goals

- Live production telemetry ingestion.
- OTLP serialization, SDK setup, collector delivery, network calls, or
  collector endpoint configuration.
- Production credentials, hostnames, endpoints, secrets, raw user ids, tenant
  ids, request bodies, headers, prompts, or raw payload capture.
- Durable production writes.
- Non-NenDB durable adapter work.
- Cockroach adapter work.
- Production capacity sizing, autoscaling, cost estimates, or production load
  generation.
- CI timing gates or telemetry gates.
- Production dashboards, multi-user hosting, or production dashboard streaming.
- React or alternate renderer work.
- Source, config, registry, deployment, rollout, alert, app, or production
  mutation authority.

## Recommended Approach

Create one deterministic Zig report tool with three surfaces:

1. Catalog output:
   - lists source contracts, positive fixtures, negative fixtures, validation
     checks, readiness gates, non-goals, and verification commands.
2. Selected fixture output:
   - emits one named fixture record in text or JSON so agents can inspect the
     exact field contract without scanning the whole catalog.
3. Validation output:
   - emits a deterministic validation report that proves fixture coverage and
     forbidden-claim blocking without reading external files or live systems.

This is the recommended approach because it turns the design into executable
evidence while preserving a non-live boundary. The validation mode also gives
future agents a stable way to decide whether a later branch has preserved the
fixture contract.

Rejected approaches:

- Live telemetry dry run: still needs endpoint, credential, exporter, and
  operational review, so it violates the current branch boundary.
- Documentation-only fixtures: useful for humans but weak for agents because
  there is no schema-governed machine-readable fixture corpus.
- Extending the design report: would blur "what should be allowed" with
  "which concrete examples satisfy the contract." The fixture branch should
  be a separate schema and handoff.
- CI-gated telemetry checks: thresholds and production-like timing evidence
  remain future work and require human review.

## Command Contract

Default catalog:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-capture-fixtures
zig build causal-production-telemetry-capture-fixtures -- --format json
```

Selected fixture:

```sh
zig build causal-production-telemetry-capture-fixtures -- emit runtime-trace-span-event
zig build causal-production-telemetry-capture-fixtures -- emit runtime-trace-span-event --format json
```

Validation report:

```sh
zig build causal-production-telemetry-capture-fixtures -- validate
zig build causal-production-telemetry-capture-fixtures -- validate --format json
```

Parser rules:

- No args after the executable means catalog text.
- `--format text|json` selects catalog output.
- `emit <fixture-id>` emits one fixture in text output.
- `emit <fixture-id> --format json` emits one fixture in JSON output.
- `validate` emits validation text output.
- `validate --format json` emits validation JSON output.
- Unknown fixture ids return `error.UnknownFixture`.
- `--format` without a value returns `error.MissingFormat`.
- Unknown formats return `error.UnknownFormat`.
- Unknown flags return `error.UnknownFlag`.

## Fixture Model

Top-level catalog fields:

- `schema`
- `schema_version`
- `status`
- `generated_by`
- `source_branch`
- `recommendation`
- `next_branch`
- `applied`
- `mutation_authority`
- `production_telemetry_ingestion`
- `live_exporter_enabled`
- `durable_write_enabled`
- `ci_gate_enabled`
- `source_contracts`
- `positive_fixtures`
- `negative_fixtures`
- `validation_checks`
- `agent_rules`
- `non_goals`
- `verification_commands`

Fixture record fields:

- `fixture_id`
- `fixture_kind`
- `capture_surface_id`
- `source_schema`
- `signal_kind`
- `event_kind_policy`
- `redaction_state`
- `sampling_policy`
- `retention_policy`
- `access_policy_ref`
- `encryption_policy_ref`
- `telemetry_transport_state`
- `durable_write_state`
- `local_observation_refs`
- `review_gate`
- `blocked_claims`
- `sample_attributes`
- `expected_agent_use`
- `forbidden_inference`

Positive fixtures should have `fixture_kind="positive"` and represent approved
record shapes. Negative fixtures should have `fixture_kind="negative"` and
represent rejected claims or forbidden record shapes. Both fixture kinds should
preserve `applied=false`, `mutation_authority="none"`, and no live/durable/CI
authority.

## Positive Fixtures

The initial positive fixtures should be:

1. `runtime-trace-span-event`
   - Capture surface: `runtime-trace`.
   - Source schema: `zigeffect.causal.otel_record.v1`.
   - Signal kind: `span-event`.
   - Purpose: show how a redacted runtime event maps to exporter-neutral OTel
     record shape without enabling export.

2. `app-semantic-redacted-ref`
   - Capture surface: `app-semantic`.
   - Source schema: `zigeffect.causal.app-runtime.v1`.
   - Signal kind: `app-semantic`.
   - Purpose: show how apps cite schema refs, data refs, domain refs, and
     policy decisions without raw request or prompt payloads.

3. `backend-export-otel-record`
   - Capture surface: `backend-export-otel`.
   - Source schema: `zigeffect.causal.otel_record.v1`.
   - Signal kind: `span`.
   - Purpose: show the backend bridge record shape while preserving
     `telemetry_transport_state="disabled-fixture"`.

4. `redaction-access-evidence`
   - Capture surface: `redaction-access`.
   - Source schema: `zigeffect.causal.production-artifact-aggregation.v1`.
   - Signal kind: `policy-evidence`.
   - Purpose: show how redaction, access, and encryption policy refs travel
     with retained evidence.

5. `local-observation-correlation-ref`
   - Capture surface: `local-observation-correlation`.
   - Source schema: `zigeffect.causal.load-test-observation-harness.v1`.
   - Signal kind: `local-observation-ref`.
   - Purpose: show how local observation ids can be cited while still blocking
     production telemetry and capacity claims.

6. `sampling-boundary-sampled-in`
   - Capture surface: `runtime-trace`.
   - Source schema: `zigeffect.causal.backend-conformance.v1`.
   - Signal kind: `sampling-policy`.
   - Purpose: show a sampled-in record and explicitly preserve the rule that
     sampled-out events are not forwarded.

## Negative Fixtures

The initial negative fixtures should cover every blocked claim from the design
report:

- `live-exporter-enabled`
- `otlp-collector-endpoint-configured`
- `raw-request-body-capture`
- `raw-header-capture`
- `raw-prompt-capture`
- `credential-token-capture`
- `unbounded-attribute-cardinality`
- `sampled-out-event-forwarded`
- `local-observation-as-production-capacity`
- `non-nendb-durable-storage`
- `cockroach-adapter-work`
- `react-or-alternate-renderer`
- `ci-telemetry-gate`
- `mutation-authority-granted`

Each negative fixture should include the attempted claim, the rejection
decision, the reason, the violated field or gate, and the safe alternative.

## Validation Checks

The validation report should include deterministic checks:

- `positive-fixture-surface-coverage`: every approved capture surface has at
  least one positive fixture.
- `required-field-coverage`: every positive fixture carries every required
  telemetry field from the design report.
- `negative-fixture-claim-coverage`: every blocked claim has a negative
  fixture.
- `forbidden-value-absence`: no positive fixture uses raw payload, header,
  prompt, credential, unbounded, non-NenDB, live exporter, collector endpoint,
  production write, CI gate, or mutation-authority values.
- `local-observation-separated`: local observation refs appear only as refs and
  do not set production telemetry or capacity evidence flags.
- `nendb-retention-direction`: retention policy remains NenDB-compatible and
  does not introduce another adapter.
- `solid-webui-direction`: workbench renderer direction remains SolidJS inside
  `webui-dev/zig-webui`.
- `authority-boundary`: all top-level and fixture-level authority fields keep
  `applied=false`, `mutation_authority="none"`, and disabled live/durable/CI
  state.

For v1, validation can be implemented over static tables. It must not read live
systems, generated artifacts, environment data, clocks, or network resources.

## Agent Guidance

Agents should use these fixtures to:

- learn canonical record shapes for every approved capture surface;
- explain why raw payload, endpoint, credential, unbounded, non-NenDB, CI, and
  mutation claims remain blocked;
- propose future telemetry work only by citing fixture ids, field names, and
  validation checks;
- keep local observations advisory and separate from production telemetry;
- route future implementation proposals through a readiness review before any
  live telemetry capture is discussed.

Agents must not infer that the fixture catalog proves production telemetry is
live, that production capacity has been measured, that CI can fail on telemetry
thresholds, or that any mutation authority exists.

## Documentation Updates

The implementation should update:

- `packages/zigeffect/README.md`
- `packages/zigeffect/docs/operations.md`
- `packages/zigeffect/docs/schema-governance.md`
- `packages/zigeffect/docs/production-telemetry-capture-design.md`
- `packages/zigeffect/docs/production-hardening-backlog.md`
- `packages/zigeffect/docs/roadmap.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

It should create:

- `packages/zigeffect/docs/production-telemetry-capture-fixtures.md`

## Verification

Expected focused verification:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_capture_fixtures.zig
zig build causal-production-telemetry-capture-fixtures
zig build causal-production-telemetry-capture-fixtures -- --format json
zig build causal-production-telemetry-capture-fixtures -- emit runtime-trace-span-event --format json
zig build causal-production-telemetry-capture-fixtures -- validate --format json
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
bun run check
bun run zig:test
git diff --check
```

## Acceptance Criteria

- A committed design spec exists for production telemetry capture fixtures.
- A committed implementation plan exists before implementation.
- The tool emits deterministic text and JSON fixture catalogs.
- The tool emits selected fixture text and JSON by id.
- The tool emits deterministic validation text and JSON.
- The schema governance inventory includes
  `zigeffect.causal.production-telemetry-capture-fixtures.v1`.
- The production hardening backlog marks this branch delivered and recommends
  `codex/zigeffect-causal-production-telemetry-readiness-review`.
- Docs state that fixtures are examples and validation evidence only, not live
  production telemetry ingestion.
- All verification commands pass before committing the implementation.
