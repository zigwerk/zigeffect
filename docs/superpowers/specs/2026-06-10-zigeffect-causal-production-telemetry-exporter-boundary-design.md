# zigeffect Causal Production Telemetry Exporter Boundary Design

## Summary

Add a production telemetry exporter-boundary artifact for zigeffect. The
artifact consumes an `approved` production telemetry implementation-proposal
JSON artifact, verifies that the proposal still preserves every non-live
boundary, and emits an exporter-neutral boundary contract for later local
pipeline work.

This branch defines the local no-network boundary only. It must not enable live
telemetry ingestion, serialize OTLP, configure exporters, send network
requests, configure collector endpoints, write durable production storage, fail
CI on telemetry thresholds, size production capacity, add non-NenDB adapter
work, switch the workbench renderer, or grant mutation authority.

## Branch

- Branch: `codex/zigeffect-causal-production-telemetry-exporter-boundary`
- Schema: `zigeffect.causal.production-telemetry-exporter-boundary.v1`
- Command: `zig build causal-production-telemetry-exporter-boundary`
- Recommendation after delivery: `start-production-telemetry-local-pipeline-fixtures`
- Next branch if approved:
  `codex/zigeffect-causal-production-telemetry-local-pipeline-fixtures`

## Context

The capture design, capture fixtures, readiness review, and implementation
proposal milestones are delivered. The approved proposal records the
`exporter-boundary` phase as the next safe implementation branch. The next
useful step is a small schema-governed boundary contract that future code can
cite before any local pipeline fixture, retention fixture, workbench preview,
or CI artifact preview work starts.

Relevant source contracts:

- `zigeffect.causal.production-telemetry-capture-design.v1` defines approved
  capture surfaces and blocked telemetry claims.
- `zigeffect.causal.production-telemetry-capture-fixtures.v1` provides safe
  fixture examples with disabled telemetry transport state.
- `zigeffect.causal.production-telemetry-readiness-review.v1` proves fixture
  readiness and required verification evidence.
- `zigeffect.causal.production-telemetry-implementation-proposal.v1` approves
  this exporter-boundary branch and records the later phase plan.
- `zigeffect.causal.otel_record.v1` is the existing exporter-neutral record
  bridge shape. This branch may cite it and define local envelope fixtures; it
  must not implement OTLP serialization or collector transport.

## Goals

1. Add a schema-governed exporter-boundary artifact.
2. Consume implementation-proposal JSON from a file path so agents can cite the
   exact approved proposal evidence they used.
3. Require a boundary decision and reason. `approve` means the boundary
   artifact may recommend the local-pipeline-fixtures branch; `reject` produces
   a blocked boundary artifact.
4. Require explicit verification command evidence before the boundary can be
   `approved`.
5. Verify proposal schema, approved status, authority boundary fields, proposal
   phase handoff, source readiness and fixture links, proposal checks, proposal
   verification command evidence, NenDB-only durable direction, and SolidJS
   `webui-dev/zig-webui` direction.
6. Emit text and JSON artifacts with boundary status, source proposal path,
   source readiness path, source fixture path, checks, local exporter boundary
   contract, local envelope fixture names, blocked claims, required commands,
   recorded commands, and next branch.
7. Keep `applied=false`, `mutation_authority="none"`,
   `production_telemetry_ingestion=false`, `live_exporter_enabled=false`,
   `network_send_enabled=false`, `collector_endpoint_configured=false`,
   `otlp_serialization_enabled=false`, `durable_write_enabled=false`, and
   `ci_gate_enabled=false`.
8. Update docs, schema governance, production hardening backlog, README,
   operations, roadmap, and the master roadmap.

## Non-Goals

- Live production telemetry ingestion.
- OTLP protobuf serialization, SDK setup, collector delivery, network calls, or
  collector endpoint configuration.
- Production credentials, hostnames, endpoints, secrets, raw user ids, tenant
  ids, request bodies, headers, prompts, or raw payload capture.
- Durable production writes.
- Non-NenDB durable adapter work.
- Cockroach adapter work.
- Production capacity sizing, autoscaling, cost estimates, or production load
  generation.
- CI timing gates or telemetry gates.
- Production dashboards, multi-user hosting, or dashboard streaming.
- React or alternate renderer work.
- Source, config, registry, deployment, rollout, alert, app, or production
  mutation authority.

## Recommended Approach

Create one deterministic Zig boundary tool that mirrors the proposal-review
shape:

1. Read an implementation-proposal JSON artifact from disk.
2. Parse and validate the proposal schema.
3. Fail closed unless the source proposal artifact is `approved` and
   `approved_for_next_branch=true`.
4. Evaluate fixed exporter-boundary checks for proposal integrity, authority
   boundaries, phase handoff, no-network transport posture, no-OTLP
   serialization, required command evidence, durable adapter scope, and
   workbench renderer scope.
5. Mark the boundary `approved` only when the reviewer approves, all checks
   pass, and every required exporter-boundary verification command is recorded.
6. Write JSON and text artifacts beside the proposal input or at an explicit
   output prefix.
7. Print the text report for local review.

This is the recommended approach because it creates a parseable artifact that
future local-pipeline fixture work can consume without accidentally claiming
live exporter capability.

Rejected approaches:

- Implementing a live exporter: violates the no-network boundary.
- Implementing OTLP protobuf serialization: the branch is exporter-neutral and
  local-only; OTLP serialization needs its own review branch.
- Reusing the implementation proposal as the boundary: the proposal approves a
  phase plan, while the boundary defines concrete local envelope and adapter
  invariants.
- Adding workbench UI now: workbench preview is a later proposal phase.

## Command Contract

Default invocation:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-exporter-boundary -- \
  --from-proposal ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.json \
  approve \
  --reason "approved proposal reviewed for no-network exporter boundary" \
  --verified-command "zig build causal-production-telemetry-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json approve --reason \"ready evidence reviewed for exporter boundary planning\" --verified-command \"zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \\\"fixtures reviewed for implementation proposal\\\" --verified-command \\\"zig build causal-production-telemetry-capture-fixtures -- validate --format json\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Parser rules:

- `--from-proposal <proposal.json>` is required.
- The input path must end with `.json`.
- Decision must be `approve` or `reject`.
- `--reason <reason>` is required and non-empty.
- `--by <actor>` is optional and defaults to `local-boundary-reviewer`.
- `--policy <policy>` is optional and defaults to
  `manual-production-telemetry-exporter-boundary`.
- `--verified-command <command>` may be supplied multiple times.
- `--out-prefix <path-prefix>` is optional. Without it, output paths are
  derived from the proposal JSON path by appending `-exporter-boundary`.
- Unknown flags, missing values, unsupported decisions, and unsupported
  proposal schemas fail closed.

## Boundary Model

Top-level fields:

- `schema`
- `schema_version`
- `source_proposal`
- `source_readiness`
- `source_fixtures`
- `decision`
- `boundary_status`
- `approved_for_next_branch`
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
- `source_branch`
- `recommendation`
- `next_branch_if_approved`
- `proposal_summary`
- `checks`
- `exporter_boundary_contract`
- `local_envelope_fixtures`
- `implementation_gates`
- `non_goals`
- `blocked_claims`
- `required_verification_commands`
- `verified_commands`
- `agent_guidance`

`boundary_status` is:

- `approved` when the reviewer approves, the source proposal artifact is
  approved, every boundary check passes, and every required verification
  command is recorded.
- `blocked` when the reviewer rejects, the proposal artifact is blocked, a
  required proposal or boundary check fails, or verification evidence is
  missing.

`approved_for_next_branch=true` means a later
`codex/zigeffect-causal-production-telemetry-local-pipeline-fixtures` branch may
be started. It does not mean telemetry is implemented or approved for live
export.

## Exporter Boundary Contract

The approved artifact should define these boundary statements:

- `boundary_id=exporter-neutral-no-network`
- `input_contract=redacted-causal-otel-record-or-fixture-ref`
- `output_contract=local-export-envelope-fixture`
- `transport_state=disabled`
- `network_state=disabled`
- `collector_endpoint_state=not-configured`
- `serialization_state=boundary-json-only-not-otlp`
- `durable_write_state=disabled`
- `review_gate=local-pipeline-fixtures-review`

Local envelope fixtures should be descriptive records only:

- `runtime-span-event-envelope`
- `app-semantic-ref-envelope`
- `backend-otel-record-envelope`
- `redaction-access-envelope`
- `sampling-boundary-envelope`

They may include schema names, fixture ids, redaction state, sampling state,
and blocked claims. They must not include production endpoints, network
destinations, raw payloads, credentials, or serialized OTLP bytes.

## Checks

The tool should emit one check per boundary concern:

- `proposal-schema`: source proposal schema is
  `zigeffect.causal.production-telemetry-implementation-proposal.v1`.
- `proposal-status`: source proposal status is `approved` and
  `approved_for_next_branch=true`.
- `proposal-decision-approved`: source proposal decision is `approve`.
- `boundary-decision`: boundary decision has a non-empty reason.
- `decision-approved`: boundary decision is `approve`.
- `authority-boundary`: proposal and boundary authority fields preserve
  `applied=false`, `mutation_authority="none"`,
  `production_telemetry_ingestion=false`, `live_exporter_enabled=false`,
  `durable_write_enabled=false`, and `ci_gate_enabled=false`.
- `no-network-boundary`: boundary fields keep `network_send_enabled=false`,
  `collector_endpoint_configured=false`, and no endpoint fields exist.
- `no-otlp-serialization`: boundary fields keep
  `otlp_serialization_enabled=false` and fixture contract remains
  boundary-JSON only.
- `source-chain-linked`: proposal links source readiness and source fixture
  JSON paths.
- `proposal-checks-passed`: every source proposal check is `pass`.
- `proposal-phase-handoff`: proposal phases include `exporter-boundary`.
- `proposal-verification-recorded`: source proposal recorded its required
  verification command evidence.
- `boundary-verification-recorded`: boundary invocation recorded all required
  exporter-boundary verification commands.
- `nendb-only-scope`: blocked claims and non-goals keep durable work scoped to
  future NenDB adapter work only.
- `solid-webui-scope`: blocked claims and non-goals keep workbench UI direction
  on SolidJS inside `webui-dev/zig-webui`.

## Required Verification

For an approved boundary, require these recorded commands:

- `zig build causal-production-telemetry-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json approve --reason "ready evidence reviewed for exporter boundary planning" --verified-command "zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \"fixtures reviewed for implementation proposal\" --verified-command \"zig build causal-production-telemetry-capture-fixtures -- validate --format json\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" --verified-command "zig build causal-schema-governance -- --format json" --verified-command "zig build causal-production-hardening-backlog -- --format json" --verified-command "zig build examples" --verified-command "zig build test"`
- `zig build causal-schema-governance -- --format json`
- `zig build causal-production-hardening-backlog -- --format json`
- `zig build examples`
- `zig build test`

## Agent Guidance

Agents may use an `approved` exporter-boundary artifact to start
`codex/zigeffect-causal-production-telemetry-local-pipeline-fixtures`. They
must cite the boundary artifact, source proposal path, source readiness path,
source fixture path, check names, required commands, recorded commands, and
local envelope fixture names.

Agents must treat `blocked` boundary artifacts as stop signs. A blocked
boundary can guide proposal, readiness, or boundary repair, but it cannot
justify local pipeline, retention, workbench, CI, live exporter, or transport
work.

Agents must not infer live telemetry, OTLP transport, collector configuration,
durable production writes, CI gates, capacity claims, non-NenDB adapter work,
React or alternate renderer work, or mutation authority from this artifact.

## Documentation Updates

Update:

- `packages/zigeffect/docs/production-telemetry-exporter-boundary.md`
- `packages/zigeffect/docs/production-telemetry-implementation-proposal.md`
- `packages/zigeffect/docs/production-hardening-backlog.md`
- `packages/zigeffect/docs/production-hardening-completion-audit.md`
- `packages/zigeffect/docs/operations.md`
- `packages/zigeffect/docs/schema-governance.md`
- `packages/zigeffect/docs/roadmap.md`
- `packages/zigeffect/README.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

## Testing

Use TDD for the Zig tool:

1. Write failing tests for schema constants and no-network authority fields.
2. Write failing tests for option parsing.
3. Write failing tests for output path derivation.
4. Write failing tests for approved and blocked boundary evaluation.
5. Implement the minimum code to pass.
6. Wire the tool into `packages/zigeffect/build.zig`.
7. Add schema governance and backlog tests.
8. Run focused Zig tests, artifact commands, `zig build examples`,
   `zig build test`, `bun run check`, `bun run zig:test`, and
   `git diff --check`.

## Spec Self-Review

- Placeholder scan: no placeholders remain.
- Internal consistency: branch, schema, command, recommendation, and next
  branch names are consistent.
- Scope check: this is one exporter-boundary milestone; local pipeline
  fixtures, NenDB retention fixtures, workbench preview, and CI artifact
  preview remain later phases.
- Ambiguity check: `approved` allows only the next branch to start and does not
  grant live telemetry, OTLP serialization, collector configuration, network
  send, storage, CI, renderer, or mutation authority.
