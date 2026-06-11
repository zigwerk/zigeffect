# zigeffect Causal App-Facing Production Integration Implementation Proposal Design

## Summary

Add an app-facing production integration implementation proposal artifact for
zigeffect. The proposal consumes a ready
`zigeffect.causal.app-facing-production-integration-readiness-review.v1` JSON
artifact, checks that the reviewed fixture evidence and authority boundaries are
still intact, and emits a proposal-only implementation sequence for the next
guarded app-facing integration boundary branch.

This branch is a planning and review boundary. It must not enable live
telemetry ingestion, configure exporters, write durable production storage,
mutate app source/config/data/deployments, fail CI gates, introduce Cockroach
adapter work, or switch away from SolidJS inside `webui-dev/zig-webui`.

## Branch

- Branch:
  `codex/zigeffect-causal-app-facing-production-integration-implementation-proposal`
- Schema:
  `zigeffect.causal.app-facing-production-integration-implementation-proposal.v1`
- Command:
  `zig build causal-app-facing-production-integration-implementation-proposal`
- Recommendation after delivery:
  `start-app-facing-production-integration-boundary`
- Next branch if approved:
  `codex/zigeffect-causal-app-facing-production-integration-boundary`

## Context

The app-facing production integration fixture catalog and readiness review are
now delivered. The fixture catalog connected app runtime traces, bounded agent
queries, audit-chain comparison evidence, app remediation governance, production
telemetry fixture boundaries, and NenDB durable-history handoff. The readiness
review then checked fixture coverage, source contracts, required verification,
NenDB-only durable direction, app mutation disablement, live telemetry
disablement, and SolidJS renderer direction.

The missing step is not production integration itself. The missing step is a
machine-readable proposal that tells agents and maintainers what implementation
sequence may start next, which evidence must be cited, and which authority
claims remain blocked.

Relevant source contracts:

- `zigeffect.causal.app-facing-production-integration-fixtures.v1` provides
  safe positive and negative app-facing evidence records.
- `zigeffect.causal.app-facing-production-integration-readiness-review.v1`
  records the reviewer decision, readiness checks, verified commands, and
  implementation-proposal handoff.
- `zigeffect.causal.agent-query.v1` provides bounded app trace/query evidence
  for agents without raw payload scraping.
- `zigeffect.causal.audit-chain-snapshot-compare.v1` provides before/after
  comparison evidence without treating audit-chain JSON as mutation proof.
- `zigeffect.causal.nendb-durable-history.v1` remains the durable-history
  direction. Cockroach adapter work is explicitly out of scope.
- `zigeffect.causal.schema-governance.v1` registers produced schemas.
- `zigeffect.causal.production-hardening-backlog.v1` controls the ordered
  production-hardening branch queue.

## Goals

1. Add a schema-governed app-facing implementation proposal artifact.
2. Consume readiness-review JSON from a file path so agents can cite the exact
   reviewed evidence they used.
3. Require a proposal decision and reason. `approve` means the proposal artifact
   may recommend the next boundary branch; `reject` produces a blocked proposal
   artifact.
4. Require explicit verification command evidence before the proposal can be
   `approved`.
5. Verify the readiness artifact schema, ready status, reviewer decision,
   authority boundary fields, source fixture link, readiness checks, readiness
   verification commands, proposal verification commands, NenDB-only durable
   direction, SolidJS `webui-dev/zig-webui` direction, app runtime scope, and
   bounded agent-query scope.
6. Emit text and JSON proposal artifacts with proposal status, source readiness
   path, source fixture path, proposer metadata, checks, phase plan,
   implementation gates, non-goals, required verification commands, recorded
   verification commands, blocked claims, and agent guidance.
7. Keep `applied=false`, `mutation_authority="none"`,
   `production_telemetry_ingestion=false`, `live_exporter_enabled=false`,
   `durable_write_enabled=false`, `app_mutation_enabled=false`, and
   `ci_gate_enabled=false`.
8. Update docs, schema governance, production hardening backlog, README,
   operations, and the master roadmap.

## Non-Goals

- Live production telemetry ingestion.
- Exporter, OTLP, network, collector endpoint, or production telemetry transport
  implementation.
- Durable production writes.
- Non-NenDB durable adapter work.
- Cockroach adapter work.
- Raw request bodies, headers, prompts, credentials, tokens, tenant identities,
  PII, or raw payload capture.
- App source, config, migration, data, deployment, rollout, rollback, or
  operational mutation.
- CI enforcement gates or required status checks.
- Production workbench hosting or live production dashboard streaming.
- React or alternate renderer work.
- A claim that a production app is healthy, fixed, deployed, or integrated.

## Recommended Approach

Create one deterministic Zig proposal tool that mirrors the existing
implementation-proposal pattern but extends the authority boundary for
app-facing integration:

1. Read an app-facing readiness-review JSON artifact from disk.
2. Parse it with unknown fields ignored but fail closed on unsupported schema,
   missing readiness state, or missing authority fields.
3. Require the source readiness artifact to be `ready`,
   `ready_for_implementation_proposal=true`, and reviewer-approved.
4. Evaluate fixed proposal checks for readiness integrity, authority boundaries,
   verification command evidence, NenDB-only durable scope, SolidJS renderer
   scope, raw app payload restrictions, app mutation restrictions, and bounded
   agent-query evidence.
5. Mark the proposal `approved` only when the proposer approves, all checks
   pass, and every required proposal verification command is recorded.
6. Write JSON and text artifacts beside the readiness input or at an explicit
   output prefix.
7. Print the text report for local review.

This creates a parseable decision boundary between "readiness evidence is
reviewed" and "the app-facing integration boundary branch may start." It also
gives future agents a single artifact that says which implementation phase comes
next and which claims are still forbidden.

Rejected approaches:

- Implementing app-facing integration in this branch: skips the proposal review
  boundary and makes readiness evidence look like implementation authority.
- Documentation-only proposal: useful for humans but weak for agents because it
  cannot be parsed, checked, or compared.
- Treating readiness as the proposal: readiness says the fixture evidence is
  ready; it does not define the implementation sequence or next branch gates.
- Enabling live telemetry, app mutation, durable writes, CI gates, or Cockroach
  scope here: each requires a later artifact with its own review and
  verification evidence.

## Command Contract

Default invocation:

```sh
cd packages/zigeffect
mkdir -p ../../.zig-cache/causal-artifacts
zig build causal-app-facing-production-integration-fixtures -- --format json \
  2> ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json
zig build causal-app-facing-production-integration-readiness-review -- \
  --from-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json \
  approve \
  --reason "fixtures reviewed for implementation proposal" \
  --verified-command "zig build causal-app-facing-production-integration-fixtures -- validate --format json" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-app-facing-production-integration-implementation-proposal -- \
  --from-readiness ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review.json \
  approve \
  --reason "ready evidence reviewed for app-facing integration planning" \
  --verified-command "zig build causal-app-facing-production-integration-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json approve --reason \"fixtures reviewed for implementation proposal\" --verified-command \"zig build causal-app-facing-production-integration-fixtures -- validate --format json\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" \
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
  `manual-app-facing-production-integration-implementation-proposal`.
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
- `generated_by`
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
- `app_mutation_enabled`
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
`codex/zigeffect-causal-app-facing-production-integration-boundary` branch may
be started. It does not mean production integration is implemented, applied,
deployed, or approved for live app mutation.

## Checks

The tool should emit one check per proposal concern:

- `readiness-schema`: source readiness schema is
  `zigeffect.causal.app-facing-production-integration-readiness-review.v1` with
  schema version `1`.
- `readiness-status`: source readiness status is `ready` and
  `ready_for_implementation_proposal=true`.
- `readiness-decision-approved`: source readiness decision is `approve`.
- `proposal-decision`: proposal includes a non-empty reason.
- `decision-approved`: proposal decision is `approve`.
- `authority-boundary`: readiness and proposal keep `applied=false`,
  `mutation_authority=none`, live telemetry disabled, exporter disabled,
  durable writes disabled, app mutation disabled, and CI gates disabled.
- `source-fixtures-linked`: readiness artifact links a source fixture JSON path.
- `readiness-checks-passed`: source readiness contains every expected app-facing
  readiness check with `pass` status and contains no failed/skipped checks.
- `readiness-verification-recorded`: readiness verified commands contain every
  readiness required command.
- `proposal-verification-recorded`: proposal verified commands contain every
  proposal required command.
- `nendb-only-scope`: proposal non-goals and blocked claims preserve
  NenDB-only durable direction and block Cockroach/non-NenDB scope.
- `solid-webui-scope`: proposal non-goals and blocked claims preserve SolidJS
  inside `webui-dev/zig-webui` and block React/alternate renderer work.
- `app-runtime-scope`: proposal non-goals and blocked claims block raw payload
  capture and app mutation authority.
- `agent-query-scope`: proposal phases and gates include bounded agent-query
  evidence rather than raw scraping.

Expected source readiness check names:

- `fixture-schema`
- `fixture-status`
- `reviewer-decision`
- `decision-approved`
- `authority-boundary`
- `source-contracts-present`
- `positive-fixture-coverage`
- `integration-surface-coverage`
- `negative-fixture-coverage`
- `validation-checks-passed`
- `nendb-only-durable-direction`
- `app-mutation-disabled`
- `telemetry-and-durable-disabled`
- `solid-webui-direction`
- `required-verification-recorded`

## Required Verification Commands

An approved proposal requires these recorded commands:

```text
zig build causal-app-facing-production-integration-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json approve --reason "fixtures reviewed for implementation proposal" --verified-command "zig build causal-app-facing-production-integration-fixtures -- validate --format json" --verified-command "zig build causal-schema-governance -- --format json" --verified-command "zig build causal-production-hardening-backlog -- --format json" --verified-command "zig build examples" --verified-command "zig build test"
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
```

The source readiness artifact must separately record its own required commands:

```text
zig build causal-app-facing-production-integration-fixtures -- validate --format json
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
```

## Proposal Phases

The approved proposal should record these later phases:

1. `app-runtime-boundary`: connect app runtime trace refs and source-contract
   guards without raw payload capture or app mutation.
2. `agent-query-projection`: expose bounded app trace-data/query evidence and
   next-query hints without raw payload scraping.
3. `nendb-history-handoff`: map approved refs to NenDB durable-history handoff
   records without production writes.
4. `audit-remediation-bridge`: preserve audit-chain compare and app remediation
   governance handoffs without treating comparison evidence as mutation proof.
5. `solid-webui-readonly-preview`: prepare a future read-only SolidJS/webui
   production app evidence view without production hosting or mutation.
6. `ci-artifact-preview`: allow optional local/advisory artifacts only, with no
   CI gate enforcement.

Only `app-facing-production-integration-boundary` is the next recommended
branch. Later phases remain advisory until reviewed by their own artifacts.

## Implementation Gates

- Source readiness artifact is approved and ready.
- All expected readiness checks pass.
- Source readiness verification commands are recorded.
- Proposal verification commands are recorded.
- No raw request/header/prompt/credential/PII/tenant identity capture.
- No app source/config/migration/data/deployment/rollout/rollback mutation.
- No live telemetry, exporter, durable production writes, or CI gates.
- Durable direction remains NenDB-only; Cockroach remains out of scope.
- Workbench direction remains SolidJS inside `webui-dev/zig-webui`.

## Blocked Claims

The artifact should explicitly block:

- `raw-request-body-capture`
- `raw-header-capture`
- `raw-prompt-capture`
- `credential-token-capture`
- `pii-or-tenant-identity-capture`
- `app-mutation-authority`
- `live-production-telemetry-ingestion`
- `live-exporter-enabled`
- `production-durable-write`
- `non-nendb-durable-storage`
- `cockroach-adapter-work`
- `ci-gate-enforcement`
- `react-or-alternate-renderer`
- `production-health-claim`

## Schema Governance And Backlog

Schema governance should register
`zigeffect.causal.app-facing-production-integration-implementation-proposal.v1`
as:

- category: `app-runtime`
- status: `current`
- emitted by:
  `causal-app-facing-production-integration-implementation-proposal`
- consumed by: agents, reviewers, production-hardening backlog, and the future
  app-facing production integration boundary branch
- compatibility:
  `strict-v1`, `record-only`, `implementation-proposal`, `nendb-only`,
  `no-cockroach`, `no-live-telemetry`, `no-production-mutation`

The production hardening backlog should:

- add delivered item `app-facing-production-integration-implementation-proposal`;
- depend on `app-facing-production-integration-readiness-review`,
  `app-facing-production-integration-fixtures`, `agent-query-interface`,
  `audit-chain-snapshot-compare`, `nendb-durable-history-hardening`, and
  `production-telemetry-capture-fixtures`;
- update the recommendation to
  `start-app-facing-production-integration-boundary`;
- update the next branch to
  `codex/zigeffect-causal-app-facing-production-integration-boundary`;
- add approve and reject proposal verification commands after the readiness
  review commands.

## Agent Guidance

Agents may use an `approved` proposal to start
`codex/zigeffect-causal-app-facing-production-integration-boundary`. They must
cite the proposal artifact, source readiness path, source fixture path, check
names, required commands, recorded commands, and approved phase names.

Agents must treat `blocked` proposal artifacts as stop signs. Blocked proposals
can guide fixture, readiness, or proposal repair, but they cannot justify app
mutation, telemetry, exporter, durable write, CI gate, Cockroach, or renderer
work.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_implementation_proposal.zig
mkdir -p ../../.zig-cache/causal-artifacts
zig build causal-app-facing-production-integration-fixtures -- --format json \
  2> ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json
zig build causal-app-facing-production-integration-readiness-review -- \
  --from-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json \
  approve \
  --reason "fixtures reviewed for implementation proposal" \
  --verified-command "zig build causal-app-facing-production-integration-fixtures -- validate --format json" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-app-facing-production-integration-implementation-proposal -- \
  --from-readiness ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review.json \
  approve \
  --reason "ready evidence reviewed for app-facing integration planning" \
  --verified-command "zig build causal-app-facing-production-integration-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json approve --reason \"fixtures reviewed for implementation proposal\" --verified-command \"zig build causal-app-facing-production-integration-fixtures -- validate --format json\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-app-facing-production-integration-implementation-proposal -- \
  --from-readiness ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review.json \
  reject \
  --reason "negative proposal path" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-production-integration-implementation-proposal-negative
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
