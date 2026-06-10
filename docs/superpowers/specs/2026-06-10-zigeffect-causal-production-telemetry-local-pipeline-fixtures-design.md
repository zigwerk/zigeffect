# zigeffect Causal Production Telemetry Local Pipeline Fixtures Design

## Summary

Add a production telemetry local-pipeline-fixtures artifact for zigeffect. The
artifact consumes an `approved` production telemetry exporter-boundary JSON
artifact, verifies the no-network boundary, and emits deterministic local
fixture evidence for envelope shaping, redaction, access metadata, sampling,
and correlation before any retention fixture work starts.

This branch defines local fixture records only. It must not enable runtime
telemetry ingestion, run a live pipeline, serialize OTLP, configure exporters,
send network requests, configure collector endpoints, write durable production
storage, fail CI on telemetry thresholds, size production capacity, add
non-NenDB adapter work, switch the workbench renderer, or grant mutation
authority.

## Branch

- Branch: `codex/zigeffect-causal-production-telemetry-local-pipeline-fixtures`
- Schema: `zigeffect.causal.production-telemetry-local-pipeline-fixtures.v1`
- Command: `zig build causal-production-telemetry-local-pipeline-fixtures`
- Recommendation after delivery: `start-production-telemetry-nendb-retention-fixtures`
- Next branch if approved:
  `codex/zigeffect-causal-production-telemetry-nendb-retention-fixtures`

## Context

The capture design, capture fixtures, readiness review, implementation
proposal, and exporter-boundary milestones are delivered. The approved
exporter-boundary artifact records a local, exporter-neutral, no-network
contract plus five envelope fixture names:

- `runtime-span-event-envelope`
- `app-semantic-ref-envelope`
- `backend-otel-record-envelope`
- `redaction-access-envelope`
- `sampling-boundary-envelope`

The next useful artifact is a deterministic fixture catalog that shows how
those boundary envelopes can move through a local-only pipeline shape. This
must remain fixture evidence, not runtime wiring.

Relevant source contracts:

- `zigeffect.causal.production-telemetry-capture-design.v1` defines approved
  capture surfaces and blocked telemetry claims.
- `zigeffect.causal.production-telemetry-capture-fixtures.v1` provides safe
  source examples.
- `zigeffect.causal.production-telemetry-readiness-review.v1` proves fixture
  readiness.
- `zigeffect.causal.production-telemetry-implementation-proposal.v1` approves
  the phase sequence.
- `zigeffect.causal.production-telemetry-exporter-boundary.v1` defines the
  no-network local envelope boundary this branch consumes.

## Goals

1. Add a schema-governed local-pipeline-fixtures artifact.
2. Consume exporter-boundary JSON from a file path so agents can cite the exact
   approved boundary evidence they used.
3. Require a fixture decision and reason. `approve` means the fixture artifact
   may recommend the NenDB retention fixtures branch; `reject` produces a
   blocked fixture artifact.
4. Require explicit verification command evidence before local pipeline
   fixtures can be `approved`.
5. Verify boundary schema, approved boundary status, source authority fields,
   no-network/no-OTLP posture, source chain links, source boundary checks,
   boundary verification command evidence, boundary contract fields, envelope
   fixture names, redaction fixture coverage, sampling fixture coverage,
   pipeline validation checks, NenDB-only durable direction, and SolidJS
   `webui-dev/zig-webui` direction.
6. Emit text and JSON artifacts with fixture status, source boundary path,
   source proposal path, source readiness path, source fixture path, checks,
   pipeline fixture catalog, validation checks, blocked claims, required
   commands, recorded commands, and next branch.
7. Keep `applied=false`, `mutation_authority="none"`,
   `production_telemetry_ingestion=false`, `live_exporter_enabled=false`,
   `network_send_enabled=false`, `collector_endpoint_configured=false`,
   `otlp_serialization_enabled=false`, `durable_write_enabled=false`,
   `ci_gate_enabled=false`, `runtime_pipeline_enabled=false`, and
   `local_pipeline_fixture_mode=true`.
8. Update docs, schema governance, production hardening backlog, README,
   operations, roadmap, and the master roadmap.

## Non-Goals

- Runtime telemetry ingestion or runtime instrumentation changes.
- Live local or production pipeline execution.
- OTLP protobuf serialization, SDK setup, collector delivery, network calls,
  or collector endpoint configuration.
- Production credentials, hostnames, endpoints, secrets, raw user ids, tenant
  ids, request bodies, headers, prompts, or raw payload capture.
- Durable production writes.
- NenDB retention record writes. This branch may prepare fixture handoff names
  for a later NenDB branch, but it does not write NenDB records.
- Non-NenDB durable adapter work.
- Cockroach adapter work.
- Production capacity sizing, autoscaling, cost estimates, or production load
  generation.
- CI timing gates or telemetry gates.
- Production dashboards, multi-user hosting, dashboard streaming, or workbench
  UI implementation.
- React or alternate renderer work.
- Source, config, registry, deployment, rollout, alert, app, or production
  mutation authority.

## Recommended Approach

Create one deterministic Zig fixture tool that mirrors the exporter-boundary
review shape:

1. Read an exporter-boundary JSON artifact from disk.
2. Parse and validate the boundary schema.
3. Fail closed unless the source boundary artifact is `approved` and
   `approved_for_next_branch=true`.
4. Evaluate fixed local-pipeline checks for boundary integrity, no-network
   transport posture, no-OTLP serialization, envelope fixture names, redaction
   coverage, sampling coverage, source verification command evidence, durable
   adapter scope, and workbench renderer scope.
5. Mark fixtures `ready` only when the reviewer approves, all checks pass, and
   every required local-pipeline verification command is recorded.
6. Write JSON and text artifacts beside the boundary input or at an explicit
   output prefix.
7. Print the text report for local review.

This is the recommended approach because it gives future NenDB retention work a
concrete, machine-readable fixture contract without adding a live telemetry
pipeline.

Rejected approaches:

- Implementing a runnable local pipeline: useful later, but it would blur this
  branch's fixture-only authority boundary.
- Implementing OTLP serialization or collector transport: violates the
  exporter-boundary contract.
- Writing NenDB retention records now: retention fixture mapping is the next
  branch, not this one.
- Adding workbench UI now: workbench read-only preview is a later proposal
  phase.

## Command Contract

Default invocation:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-local-pipeline-fixtures -- \
  --from-boundary ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary.json \
  approve \
  --reason "approved boundary reviewed for local pipeline fixtures" \
  --verified-command "zig build causal-production-telemetry-exporter-boundary -- --from-proposal ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.json approve --reason \"proposal evidence reviewed for local pipeline fixtures\" --verified-command \"zig build causal-production-telemetry-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json approve --reason \\\"ready evidence reviewed for exporter boundary planning\\\" --verified-command \\\"zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \\\\\\\"fixtures reviewed for implementation proposal\\\\\\\" --verified-command \\\\\\\"zig build causal-production-telemetry-capture-fixtures -- validate --format json\\\\\\\" --verified-command \\\\\\\"zig build causal-schema-governance -- --format json\\\\\\\" --verified-command \\\\\\\"zig build causal-production-hardening-backlog -- --format json\\\\\\\" --verified-command \\\\\\\"zig build examples\\\\\\\" --verified-command \\\\\\\"zig build test\\\\\\\"\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Parser rules:

- `--from-boundary <boundary.json>` is required.
- The input path must end with `.json`.
- Decision must be `approve` or `reject`.
- `--reason <reason>` is required and non-empty.
- `--by <actor>` is optional and defaults to `local-pipeline-reviewer`.
- `--policy <policy>` is optional and defaults to
  `manual-production-telemetry-local-pipeline-fixtures`.
- `--verified-command <command>` may be supplied multiple times.
- `--out-prefix <path-prefix>` is optional. Without it, output paths are
  derived from the boundary JSON path by appending `-local-pipeline-fixtures`.
- Unknown flags, missing values, unsupported decisions, and unsupported
  boundary schemas fail closed.

## Fixture Model

Top-level fields:

- `schema`
- `schema_version`
- `source_boundary`
- `source_proposal`
- `source_readiness`
- `source_fixtures`
- `decision`
- `fixture_status`
- `ready_for_next_branch`
- `reviewed_by`
- `policy`
- `reason`
- `applied`
- `mutation_authority`
- `production_telemetry_ingestion`
- `live_exporter_enabled`
- `network_send_enabled`
- `collector_endpoint_configured`
- `otlp_serialization_enabled`
- `durable_write_enabled`
- `ci_gate_enabled`
- `runtime_pipeline_enabled`
- `local_pipeline_fixture_mode`
- `source_branch`
- `recommendation`
- `next_branch_if_ready`
- `boundary_summary`
- `checks`
- `pipeline_fixture_catalog`
- `pipeline_validation_checks`
- `implementation_gates`
- `non_goals`
- `blocked_claims`
- `required_verification_commands`
- `verified_commands`
- `agent_guidance`

`fixture_status` is:

- `ready` when the reviewer approves, the source boundary artifact is
  approved, every local pipeline fixture check passes, and every required
  verification command is recorded.
- `blocked` when the reviewer rejects, the source boundary artifact is blocked,
  a required boundary or fixture check fails, or verification evidence is
  missing.

`ready_for_next_branch=true` means a later
`codex/zigeffect-causal-production-telemetry-nendb-retention-fixtures` branch
may be started. It does not mean a pipeline is implemented, executed,
connected to runtime emission, retained durably, or approved for live
production use.

## Pipeline Fixture Catalog

The approved artifact should define these local fixture records:

- `runtime-span-normalized-envelope`
  - input: `runtime-span-event-envelope`
  - output: local JSON envelope with `event_id`, `trace_id_ref`,
    `span_id_ref`, `parent_span_id_ref`, `causal_event_ref`,
    `redaction_state`, and `sample_state`
  - blocked fields: raw payloads, headers, prompts, credentials, raw tenant
    ids, raw user ids, collector endpoint, network address
- `app-semantic-normalized-envelope`
  - input: `app-semantic-ref-envelope`
  - output: local JSON envelope with `event_id`, `domain_entity_ref`,
    `schema_ref`, `data_subject_ref`, `operation_ref`, `redaction_state`, and
    `sample_state`
  - blocked fields: raw request body, raw response body, prompt text,
    credential material, raw PII
- `backend-otel-local-envelope`
  - input: `backend-otel-record-envelope`
  - output: local JSON shape that references
    `zigeffect.causal.otel_record.v1` without OTLP protobuf serialization or
    network transport
  - blocked fields: collector endpoint, auth headers, wire payload bytes,
    exporter SDK configuration
- `redaction-access-reviewed-envelope`
  - input: `redaction-access-envelope`
  - output: local JSON envelope with `visibility_class`, `redaction_state`,
    `access_policy_ref`, and `denied_raw_fields`
  - blocked fields: raw secrets, raw credentials, raw headers, raw prompts,
    raw tenant ids, raw user ids
- `sampling-kept-envelope`
  - input: `sampling-boundary-envelope`
  - output: local JSON envelope with `sample_state=kept`,
    `sample_policy_ref`, and `sample_reason`
  - blocked fields: wall-clock randomness, production traffic rates,
    production capacity claims
- `sampling-dropped-envelope`
  - input: `sampling-boundary-envelope`
  - output: metadata-only local JSON envelope with `sample_state=dropped`,
    `sample_policy_ref`, and `retained_fields`
  - blocked fields: unsampled raw payload fields
- `correlation-link-envelope`
  - input: runtime, app semantic, backend, redaction, and sampling envelope
    refs
  - output: local JSON envelope linking `event_id`, `trace_id_ref`,
    `causal_event_ref`, `artifact_id_ref`, and `schema_ref`
  - blocked fields: raw payload joins or source database reads

## Validation Checks

The tool should emit these local validation checks:

- every pipeline fixture references one source boundary envelope;
- every fixture declares an output envelope id;
- every fixture declares redaction state;
- every fixture declares sample state;
- raw payload, prompt, credential, header, tenant id, and user id fields are
  explicitly blocked;
- collector endpoint, network address, and exporter SDK configuration fields
  are explicitly blocked;
- OTLP protobuf serialization remains absent;
- durable write fields remain absent;
- sampled-out fixtures retain metadata only;
- correlation fixtures link refs without raw joins.

## Required Checks

The local-pipeline report should evaluate:

- `boundary-schema`
- `boundary-status`
- `boundary-decision-approved`
- `fixture-decision`
- `decision-approved`
- `authority-boundary`
- `no-network-pipeline`
- `no-otlp-serialization`
- `no-durable-write`
- `source-chain-linked`
- `boundary-checks-passed`
- `boundary-contract-present`
- `envelope-fixtures-present`
- `pipeline-fixtures-present`
- `redaction-fixtures-present`
- `sampling-fixtures-present`
- `pipeline-validation-passed`
- `boundary-verification-recorded`
- `fixture-verification-recorded`
- `nendb-only-scope`
- `solid-webui-scope`

All checks must pass for `fixture_status=ready`.

## Output Paths

For this input:

```text
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary.json
```

default output paths are:

```text
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures.json
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures.txt
```

## Docs And Registry Updates

Update:

- `packages/zigeffect/build.zig`
- `packages/zigeffect/tools/causal_schema_governance.zig`
- `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- `packages/zigeffect/docs/production-telemetry-local-pipeline-fixtures.md`
- `packages/zigeffect/docs/production-telemetry-exporter-boundary.md`
- `packages/zigeffect/docs/production-hardening-backlog.md`
- `packages/zigeffect/docs/production-hardening-completion-audit.md`
- `packages/zigeffect/docs/operations.md`
- `packages/zigeffect/docs/schema-governance.md`
- `packages/zigeffect/docs/roadmap.md`
- `packages/zigeffect/README.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

Schema governance should register
`zigeffect.causal.production-telemetry-local-pipeline-fixtures.v1` with:

- category: `production-hardening`
- emitted by: `causal-production-telemetry-local-pipeline-fixtures`
- consumed by: agents, reviewers, production-hardening backlog, future
  production telemetry NenDB retention fixtures
- compatibility: `strict-v1`, `record-only`, `mutation-authority-none`,
  `local-pipeline-fixtures`, `fixtures-only`, `no-live-ingestion`,
  `no-network`

The production hardening backlog should mark
`production-telemetry-local-pipeline-fixtures` delivered and make the next
recommended branch
`codex/zigeffect-causal-production-telemetry-nendb-retention-fixtures`.

## Verification

Required focused checks:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_local_pipeline_fixtures.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

Required artifact checks:

```sh
cd packages/zigeffect
mkdir -p ../../.zig-cache/causal-artifacts
zig build causal-production-telemetry-capture-fixtures -- --format json \
  2> ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json
zig build causal-production-telemetry-readiness-review -- \
  --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json \
  approve \
  --reason "fixtures reviewed for implementation proposal" \
  --verified-command "zig build causal-production-telemetry-capture-fixtures -- validate --format json" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-production-telemetry-implementation-proposal -- \
  --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json \
  approve \
  --reason "ready evidence reviewed for exporter boundary planning" \
  --verified-command "zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \"fixtures reviewed for implementation proposal\" --verified-command \"zig build causal-production-telemetry-capture-fixtures -- validate --format json\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
implementation_proposal_command='zig build causal-production-telemetry-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json approve --reason "ready evidence reviewed for exporter boundary planning" --verified-command "zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \"fixtures reviewed for implementation proposal\" --verified-command \"zig build causal-production-telemetry-capture-fixtures -- validate --format json\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" --verified-command "zig build causal-schema-governance -- --format json" --verified-command "zig build causal-production-hardening-backlog -- --format json" --verified-command "zig build examples" --verified-command "zig build test"'
zig build causal-production-telemetry-exporter-boundary -- \
  --from-proposal ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.json \
  approve \
  --reason "proposal evidence reviewed for local pipeline fixtures" \
  --verified-command "$implementation_proposal_command" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
exporter_boundary_command='zig build causal-production-telemetry-exporter-boundary -- --from-proposal ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.json approve --reason "proposal evidence reviewed for local pipeline fixtures" --verified-command "zig build causal-production-telemetry-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json approve --reason \"ready evidence reviewed for exporter boundary planning\" --verified-command \"zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \\\"fixtures reviewed for implementation proposal\\\" --verified-command \\\"zig build causal-production-telemetry-capture-fixtures -- validate --format json\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" --verified-command "zig build causal-schema-governance -- --format json" --verified-command "zig build causal-production-hardening-backlog -- --format json" --verified-command "zig build examples" --verified-command "zig build test"'
zig build causal-production-telemetry-local-pipeline-fixtures -- \
  --from-boundary ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary.json \
  approve \
  --reason "approved boundary reviewed for local pipeline fixtures" \
  --verified-command "$exporter_boundary_command" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-production-telemetry-local-pipeline-fixtures -- \
  --from-boundary ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary.json \
  reject \
  --reason "negative local pipeline fixture path"
```

Broad checks:

```sh
cd packages/zigeffect
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

## Agent Guidance

Agents may use an approved local-pipeline-fixtures artifact to start
`codex/zigeffect-causal-production-telemetry-nendb-retention-fixtures`. They
must cite the fixture artifact, source boundary artifact, source proposal,
source readiness, source fixtures, fixture catalog, validation checks,
required commands, recorded commands, and blocked claims.

Agents must not treat local pipeline fixtures as a runnable runtime pipeline,
live exporter, network sender, OTLP serializer, durable writer, CI gate,
production capacity claim, non-NenDB adapter scope, alternate renderer scope,
or mutation authority.

## Spec Self-Review

- Completeness scan: no unfinished markers or incomplete sections remain. The
  verification snippets define shell variables for the exact nested command
  strings that must be recorded as verification evidence.
- Consistency check: branch, schema, command, status, recommendation, and next
  branch names are aligned.
- Scope check: this is a single deterministic artifact family plus docs/build
  wiring. Runtime pipeline implementation, NenDB retention, workbench UI, and
  live telemetry are explicitly excluded.
- Ambiguity check: `ready_for_next_branch=true` is defined as permission to
  start the NenDB retention fixtures branch only, not permission to run or ship
  telemetry.
