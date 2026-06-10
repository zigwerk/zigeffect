# zigeffect Causal Production Telemetry Implementation Proposal Design

## Summary

Add a production telemetry implementation proposal artifact for zigeffect. The
proposal consumes a `ready` production telemetry readiness-review JSON artifact,
checks that the reviewed fixture evidence is still safe, and emits a bounded
implementation proposal that agents and maintainers can use before starting the
first real telemetry implementation boundary branch.

This branch is proposal-only. It must not enable live telemetry ingestion,
configure exporters, send OTLP, write durable production storage, fail CI on
telemetry thresholds, size production capacity, add non-NenDB adapter work,
switch the workbench renderer, or grant mutation authority.

## Branch

- Branch:
  `codex/zigeffect-causal-production-telemetry-implementation-proposal`
- Schema:
  `zigeffect.causal.production-telemetry-implementation-proposal.v1`
- Command: `zig build causal-production-telemetry-implementation-proposal`
- Recommendation after delivery:
  `start-production-telemetry-exporter-boundary`
- Next branch if approved:
  `codex/zigeffect-causal-production-telemetry-exporter-boundary`

## Context

The production telemetry capture design, capture fixture catalog, and readiness
review milestones are delivered. The readiness review records whether a human
reviewer approved the fixture evidence for implementation proposal work. The
next useful artifact is not an exporter; it is a concrete proposal that converts
the approved fixture/readiness evidence into an implementation sequence with
explicit phase gates, non-goals, required verification, and blocked claims.

Relevant source contracts:

- `zigeffect.causal.production-telemetry-capture-design.v1` defines the future
  capture surfaces, field contracts, redaction posture, sampling posture,
  retention assumptions, access/encryption references, and negative fixture ids.
- `zigeffect.causal.production-telemetry-capture-fixtures.v1` provides safe
  positive and negative example records.
- `zigeffect.causal.production-telemetry-readiness-review.v1` records the
  reviewer decision, readiness checks, verified commands, and handoff.
- `zigeffect.causal.schema-governance.v1` registers produced schemas.
- `zigeffect.causal.production-hardening-backlog.v1` controls the ordered
  production-hardening branch queue.

## Goals

1. Add a schema-governed implementation proposal artifact.
2. Consume readiness-review JSON from a file path so agents can cite the exact
   reviewed evidence they used.
3. Require a proposal decision and reason. `approve` means the proposal artifact
   may recommend the next branch; `reject` produces a blocked proposal artifact.
4. Require explicit verification command evidence before the proposal can be
   `approved`.
5. Verify the readiness artifact schema, ready status, reviewer decision,
   authority boundary fields, source fixture link, readiness checks, required
   commands, NenDB-only durable direction, and SolidJS `webui-dev/zig-webui`
   direction.
6. Emit text and JSON proposal artifacts with proposal status, source readiness
   path, reviewer/proposer metadata, checks, phase plan, implementation gates,
   non-goals, required verification commands, recorded verification commands,
   agent guidance, blocked claims, and next branch.
7. Keep `applied=false`, `mutation_authority="none"`,
   `production_telemetry_ingestion=false`, `live_exporter_enabled=false`,
   `durable_write_enabled=false`, and `ci_gate_enabled=false`.
8. Update docs, schema governance, production hardening backlog, README,
   operations, roadmap, and the master roadmap.

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
- Production dashboards, multi-user hosting, or dashboard streaming.
- React or alternate renderer work.
- Source, config, registry, deployment, rollout, alert, app, or production
  mutation authority.

## Recommended Approach

Create one deterministic Zig proposal tool that mirrors the current
readiness-review shape:

1. Read a readiness-review JSON artifact from disk.
2. Parse and validate the readiness schema.
3. Fail closed unless the source readiness artifact is `ready` and
   `ready_for_implementation_proposal=true`.
4. Evaluate fixed proposal checks for readiness integrity, authority boundaries,
   required command evidence, durable adapter scope, and workbench renderer
   scope.
5. Mark the proposal `approved` only when the reviewer approves, all checks
   pass, and every required proposal verification command is recorded.
6. Write JSON and text artifacts beside the readiness input or at an explicit
   output prefix.
7. Print the text report for local review.

This is the recommended approach because it creates a parseable decision
boundary between "fixtures are ready" and "implementation work may start." It
also gives future agents a single artifact that says which implementation phase
comes next and which claims are still forbidden.

Rejected approaches:

- Implementing the exporter in this branch: skips the proposal review boundary.
- Documentation-only proposal: useful to humans but weak for agents because it
  cannot be parsed, checked, or compared.
- Treating readiness as the proposal: readiness says the fixture evidence is
  ready; it does not define an implementation sequence or next branch gates.
- Enabling CI or durable writes here: those require later branches with their
  own evidence and review artifacts.

## Command Contract

Default invocation:

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
```

Parser rules:

- `--from-readiness <readiness.json>` is required.
- The input path must end with `.json`.
- Decision must be `approve` or `reject`.
- `--reason <reason>` is required and non-empty.
- `--by <actor>` is optional and defaults to `local-proposer`.
- `--policy <policy>` is optional and defaults to
  `manual-production-telemetry-implementation-proposal`.
- `--verified-command <command>` may be supplied multiple times.
- `--out-prefix <path-prefix>` is optional. Without it, output paths are
  derived from the readiness JSON path by appending
  `-implementation-proposal`.
- Unknown flags, missing values, unsupported decisions, and unsupported
  readiness schemas fail closed.

## Proposal Model

Top-level fields:

- `schema`
- `schema_version`
- `source_readiness`
- `source_fixtures`
- `decision`
- `proposal_status`
- `approved_for_next_branch`
- `proposed_by`
- `policy`
- `reason`
- `applied`
- `mutation_authority`
- `production_telemetry_ingestion`
- `live_exporter_enabled`
- `durable_write_enabled`
- `ci_gate_enabled`
- `source_branch`
- `recommendation`
- `next_branch_if_approved`
- `readiness_summary`
- `checks`
- `proposal_phases`
- `implementation_gates`
- `non_goals`
- `blocked_claims`
- `required_verification_commands`
- `verified_commands`
- `agent_guidance`

`proposal_status` is:

- `approved` when the proposer approves, the source readiness artifact is
  ready, every proposal check passes, and every required verification command is
  recorded.
- `blocked` when the proposer rejects, the readiness artifact is blocked, a
  required readiness or proposal check fails, or verification evidence is
  missing.

`approved_for_next_branch=true` means a later
`codex/zigeffect-causal-production-telemetry-exporter-boundary` branch may be
started. It does not mean telemetry is implemented or approved for deployment.

## Checks

The tool should emit one check per proposal concern:

- `readiness-schema`: source readiness schema is
  `zigeffect.causal.production-telemetry-readiness-review.v1`.
- `readiness-status`: source readiness status is `ready` and
  `ready_for_implementation_proposal=true`.
- `readiness-decision-approved`: source readiness decision is `approve`.
- `proposal-decision`: proposal decision has a non-empty reason.
- `decision-approved`: proposal decision is `approve`.
- `authority-boundary`: readiness artifact and proposal artifact preserve
  `applied=false`, `mutation_authority="none"`,
  `production_telemetry_ingestion=false`, `live_exporter_enabled=false`,
  `durable_write_enabled=false`, and `ci_gate_enabled=false`.
- `source-fixtures-linked`: readiness artifact links a fixture JSON path.
- `readiness-checks-passed`: every source readiness check is `pass`.
- `readiness-verification-recorded`: source readiness artifact recorded all
  required readiness verification commands.
- `proposal-verification-recorded`: proposal invocation recorded all required
  proposal verification commands.
- `nendb-only-scope`: blocked claims and non-goals keep durable work scoped to
  future NenDB adapter work only.
- `solid-webui-scope`: blocked claims and non-goals keep workbench UI direction
  on SolidJS inside `webui-dev/zig-webui`.

## Proposal Phases

The approved proposal should define these later implementation phases:

1. `exporter-boundary`: add an exporter-neutral boundary and local no-network
   serializer fixtures, still with live export disabled.
2. `local-pipeline-fixtures`: route approved fixture shapes through local
   in-process pipeline fixtures with redaction and sampling checks.
3. `nendb-retention-fixtures`: prove retained telemetry can map to existing
   NenDB node/edge and retention records without production writes.
4. `workbench-readonly-preview`: expose fixture/proposal status in the
   SolidJS `zig-webui` workbench without live streaming or mutation.
5. `ci-artifact-preview`: emit advisory local artifacts that CI could archive
   later, without failing CI on telemetry thresholds.

Only the first phase becomes the next recommended branch. Later phases stay
advisory until their own reviewed artifacts exist.

## Required Verification

For an approved proposal, require these recorded commands:

- `zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason "fixtures reviewed for implementation proposal" --verified-command "zig build causal-production-telemetry-capture-fixtures -- validate --format json" --verified-command "zig build causal-schema-governance -- --format json" --verified-command "zig build causal-production-hardening-backlog -- --format json" --verified-command "zig build examples" --verified-command "zig build test"`
- `zig build causal-schema-governance -- --format json`
- `zig build causal-production-hardening-backlog -- --format json`
- `zig build examples`
- `zig build test`

The first command intentionally includes the full readiness invocation so the
proposal artifact records the exact upstream review gate it depends on.

## Agent Guidance

Agents may use an `approved` proposal to start the exporter-boundary branch.
They must cite the proposal artifact, source readiness path, source fixture
path, check names, required commands, recorded commands, and approved phase
names.

Agents must treat `blocked` proposal artifacts as stop signs. A blocked
proposal can guide fixture, readiness, or proposal repair, but it cannot justify
exporter work.

Agents must not infer live telemetry, OTLP transport, collector configuration,
durable production writes, CI gates, capacity claims, non-NenDB adapter work,
React or alternate renderer work, or mutation authority from this artifact.

## Documentation Updates

Update:

- `packages/zigeffect/docs/production-telemetry-implementation-proposal.md`
- `packages/zigeffect/docs/production-telemetry-readiness-review.md`
- `packages/zigeffect/docs/production-hardening-backlog.md`
- `packages/zigeffect/docs/production-hardening-completion-audit.md`
- `packages/zigeffect/docs/operations.md`
- `packages/zigeffect/docs/schema-governance.md`
- `packages/zigeffect/docs/roadmap.md`
- `packages/zigeffect/README.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

## Testing

Use TDD for the Zig tool:

1. Write failing tests for schema constants and authority fields.
2. Write failing tests for option parsing.
3. Write failing tests for output path derivation.
4. Write failing tests for approved and blocked proposal evaluation.
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
- Scope check: this is one implementation-proposal milestone; exporter,
  pipeline, NenDB retention, workbench preview, and CI artifact preview remain
  later phases.
- Ambiguity check: `approved` allows only the next branch to start and does not
  grant telemetry, storage, CI, renderer, or mutation authority.
