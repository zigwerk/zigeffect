# zigeffect Causal Production Telemetry Capture Design

## Summary

Add a schema-governed production telemetry capture design report for zigeffect.
The report should define how production telemetry capture would be approved,
bounded, redacted, sampled, retained, and consumed by agents before any live
production telemetry ingestion exists.

This branch is a design and governance milestone. It must not enable a live
collector, send OTLP, read production systems, provision infrastructure, write
durable production storage, size production capacity, fail CI, or grant
mutation authority.

## Branch

- Branch: `codex/zigeffect-causal-production-telemetry-capture-design`
- Schema: `zigeffect.causal.production-telemetry-capture-design.v1`
- Command: `zig build causal-production-telemetry-capture-design`
- Recommendation: `start-production-telemetry-capture-fixtures`
- Next branch: `codex/zigeffect-causal-production-telemetry-capture-fixtures`

## Context

The load-test observation harness is now delivered. It records local advisory
observations and hands off to production telemetry capture design without
claiming production capacity or reading live production telemetry.

Existing source contracts relevant to this branch:

- `zigeffect.causal.load-test-observation-harness.v1` defines bounded local
  observations and the no-capacity-claim boundary.
- `zigeffect.causal.otel_record.v1` defines the exporter-neutral OpenTelemetry
  record bridge.
- `causal-backend-conformance` proves backends receive assigned, redacted,
  bounded stored events and do not receive sampled-out events.
- `zigeffect.causal.production-artifact-aggregation.v1` defines source
  provenance, redaction state, trust boundaries, and aggregation review.
- `zigeffect.causal.artifact-access-control.v1` defines visibility and
  redacted-only access decisions before retained evidence is shared.
- `zigeffect.causal.encryption-at-rest-policy.v1` defines key ownership and
  redaction ordering before retained production artifacts exist.
- `zigeffect.causal.production-capacity-planning.v1` records capacity domains
  and negative capacity fixtures, but remains planning-only.
- `zigeffect.causal.production-hardening-backlog.v1` currently recommends this
  branch and preserves NenDB-only durable direction, SolidJS `zig-webui`
  workbench direction, and `mutation_authority=none`.

## Goals

1. Define a deterministic report that agents and reviewers can cite before
   production telemetry work begins.
2. Make telemetry capture boundaries explicit: what may be captured, where it
   may flow, what gates must pass, and which claims remain blocked.
3. Connect the existing OpenTelemetry bridge to production design without
   turning it into a live exporter.
4. Preserve local observations as local evidence and production telemetry as a
   separate future evidence class.
5. Hand off to fixture work that can model approved telemetry records without
   touching production systems.

## Non-Goals

- Live production telemetry ingestion.
- OTLP serialization, SDK setup, collector delivery, or network calls.
- Production credentials, collector endpoints, secrets, headers, request
  bodies, prompts, or raw payload capture.
- Durable production writes.
- Non-NenDB durable adapter work.
- Cockroach adapter work.
- Production capacity sizing, autoscaling, or cost estimates.
- Production load generation.
- CI timing or telemetry gates.
- Production dashboards or multi-user hosting.
- React or alternate renderer work for the workbench path.
- Source, config, registry, deployment, rollout, alert, app, or production
  mutation authority.

## Recommended Approach

Use a deterministic Zig tool that emits text and JSON reports. This mirrors the
current production-hardening pattern and keeps the milestone inspectable by
humans, agents, tests, and future schema governance.

Rejected approaches:

- Live OTLP/collector wiring now: too much authority and too many secrets before
  review gates exist.
- Extending the local observation harness: conflates local development timing
  with production telemetry capture design.
- Documentation-only without a tool: weaker for agents because there is no
  stable schema, negative fixture list, or build-verifiable handoff.

## Report Model

The report should include:

- schema, schema_version, status, generated_by, source_branch, recommendation,
  and next_branch;
- `applied=false`;
- `mutation_authority="none"`;
- `production_telemetry_ingestion=false`;
- `live_exporter_enabled=false`;
- source contracts;
- capture surfaces;
- telemetry fields;
- redaction gates;
- sampling and retention gates;
- access and encryption gates;
- agent-consumption rules;
- readiness gates;
- negative fixtures;
- non-goals;
- verification commands.

## Capture Surfaces

The design should catalog these surfaces:

1. Runtime trace surface
   - Source: core causal runtime events.
   - Signal: spans or span events through the existing OTel record bridge.
   - Boundary: assigned, redacted, bounded stored events only.

2. App semantic surface
   - Source: app semantic trace API events such as data reads, writes,
     transforms, domain actions, policy decisions, artifacts, and responses.
   - Signal: redacted app semantic refs and schema refs.
   - Boundary: no raw request body, header, credential, prompt, or PII.

3. Backend export surface
   - Source: backend conformance and `CausalOtelBackendState`.
   - Signal: exporter-neutral `CausalOtelRecord` values.
   - Boundary: no OTLP serialization, network send, SDK setup, or collector
     endpoint in this branch.

4. Redaction and access surface
   - Source: aggregation, artifact access-control, and encryption policy
     contracts.
   - Signal: redaction state, trust boundary, visibility class, and review
     gate names.
   - Boundary: redacted-only evidence until a reviewer approves broader use.

5. Local observation correlation surface
   - Source: local load-test observation records.
   - Signal: scenario id, command status, sample count, median, p95, and review
     gate.
   - Boundary: local observations may shape telemetry design but do not become
     production capacity evidence.

## Telemetry Field Contract

Every future production telemetry record should be designed to carry:

- `capture_surface_id`;
- `source_schema`;
- `signal_kind`;
- `event_kind_policy`;
- `redaction_state`;
- `sampling_policy`;
- `retention_policy`;
- `access_policy_ref`;
- `encryption_policy_ref`;
- `telemetry_transport_state`;
- `durable_write_state`;
- `local_observation_refs`;
- `review_gate`;
- `blocked_claims`.

The design report should not include environment hostnames, endpoints, raw user
ids, tenant ids, credentials, request bodies, headers, prompts, or raw payload
fragments.

## Readiness Gates

The design should define these readiness gates:

- `schema-registered`: schema governance entry exists.
- `redaction-reviewed`: redaction behavior and forbidden fields are reviewed.
- `sampling-bounded`: sampling and event cardinality rules are explicit.
- `retention-nendb-compatible`: durable direction remains NenDB adapter only.
- `access-policy-reviewed`: artifact access and redacted-only sharing are
  compatible.
- `encryption-policy-reviewed`: encryption-at-rest policy is cited before
  retained production artifacts.
- `otel-bridge-reviewed`: OTel record mapping is cited without enabling live
  export.
- `local-observation-separated`: local observations remain local and advisory.
- `capacity-claim-blocked`: capacity sizing remains future.
- `fixture-handoff-ready`: next branch can create safe fixtures.

## Negative Fixtures

The design should reject:

- live exporter enabled by this branch;
- OTLP collector endpoint configured by this branch;
- raw request body capture;
- raw header capture;
- raw prompt capture;
- credential or token capture;
- unbounded attribute cardinality;
- sampled-out events forwarded to telemetry;
- local observation promoted to production capacity evidence;
- non-NenDB durable storage;
- Cockroach adapter work;
- React or alternate renderer authorization;
- CI timing or telemetry gate authorization;
- mutation authority granted.

## Agent Guidance

Agents should use this report to answer:

- which telemetry surface is being discussed;
- which source schema and event family supports it;
- which redaction, access, sampling, retention, and encryption gates apply;
- whether a claim is local observation, production telemetry design, or future
  capacity evidence;
- what next branch should create safe fixtures.

Agents must not infer that telemetry capture is live, that production capacity
has been measured, or that mutation authority exists.

## Documentation Updates

The implementation should update:

- `packages/zigeffect/README.md`;
- `packages/zigeffect/docs/operations.md`;
- `packages/zigeffect/docs/schema-governance.md`;
- `packages/zigeffect/docs/load-test-observation-harness.md`;
- `packages/zigeffect/docs/production-hardening-backlog.md`;
- `packages/zigeffect/docs/roadmap.md`;
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`.

## Verification

Expected focused verification:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_capture_design.zig
zig build causal-production-telemetry-capture-design
zig build causal-production-telemetry-capture-design -- --format json
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

- A committed design spec exists for production telemetry capture design.
- A committed implementation plan exists before implementation.
- The tool emits deterministic text and JSON reports.
- The schema governance inventory includes
  `zigeffect.causal.production-telemetry-capture-design.v1`.
- The production-hardening backlog marks this branch delivered and recommends
  `codex/zigeffect-causal-production-telemetry-capture-fixtures`.
- Docs state that this is not live production telemetry ingestion.
- All verification commands pass before committing the implementation.
