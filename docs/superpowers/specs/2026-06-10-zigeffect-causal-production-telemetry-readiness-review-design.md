# zigeffect Causal Production Telemetry Readiness Review Design

## Summary

Add a production telemetry readiness review gate for zigeffect. The gate should
consume the delivered production telemetry capture fixture catalog, record a
reviewer decision, verify that the fixture evidence still preserves every
non-live boundary, and emit a readiness artifact that agents can cite before any
later telemetry implementation proposal.

This branch is still record-only. It must not enable live telemetry ingestion,
configure exporters, send OTLP, write durable production storage, fail CI on
telemetry thresholds, size production capacity, add non-NenDB adapter work,
switch the workbench renderer, or grant mutation authority.

## Branch

- Branch: `codex/zigeffect-causal-production-telemetry-readiness-review`
- Schema: `zigeffect.causal.production-telemetry-readiness-review.v1`
- Command: `zig build causal-production-telemetry-readiness-review`
- Recommendation after delivery: `start-production-telemetry-implementation-proposal`
- Next branch if ready:
  `codex/zigeffect-causal-production-telemetry-implementation-proposal`

## Context

The production telemetry capture design and fixture milestones are delivered.
The design report defines approved capture surfaces, future telemetry fields,
readiness gates, and blocked claims. The fixture catalog provides deterministic
positive and negative records that model approved shapes without touching live
systems. The next useful milestone is a review artifact that checks whether
those fixtures are complete and safe enough to allow a later proposal branch to
design a real telemetry implementation boundary.

Relevant source contracts:

- `zigeffect.causal.production-telemetry-capture-design.v1` defines capture
  surfaces, field contracts, readiness gates, negative fixtures, and non-goals.
- `zigeffect.causal.production-telemetry-capture-fixtures.v1` provides the
  fixture catalog that this review consumes.
- `zigeffect.causal.schema-governance.v1` must register every produced schema.
- `zigeffect.causal.production-hardening-backlog.v1` controls the current
  milestone recommendation and roadmap handoff.
- Artifact access control and encryption policy reports define how retained
  telemetry evidence would be reviewed later, but this branch does not retain
  production telemetry.

## Goals

1. Add a schema-governed readiness review artifact for production telemetry
   capture fixtures.
2. Consume fixture JSON from a file path so reviewers can audit the exact
   fixture evidence they ran.
3. Require a reviewer decision and reason.
4. Require explicit verification command evidence before readiness can be
   `ready`.
5. Verify the fixture catalog schema, status, authority fields, source
   contracts, positive fixture coverage, negative fixture coverage, validation
   checks, non-goal boundaries, NenDB-only durable direction, and SolidJS
   `webui-dev/zig-webui` renderer direction.
6. Emit text and JSON readiness artifacts with status, checks, source fixture
   path, reviewer metadata, required commands, verified commands, guardrails,
   and next steps.
7. Keep `applied=false`, `mutation_authority="none"`,
   `production_telemetry_ingestion=false`, `live_exporter_enabled=false`,
   `durable_write_enabled=false`, and `ci_gate_enabled=false`.
8. Update schema governance, production hardening backlog, README, operations,
   roadmap, and the master roadmap with the delivered readiness milestone.

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

Create one deterministic Zig readiness tool that mirrors the existing registry
and app readiness tools:

1. Read a fixture JSON artifact from disk.
2. Parse and validate the fixture schema.
3. Evaluate a fixed set of readiness checks.
4. Mark readiness `ready` only when the reviewer approves, all checks pass, and
   every required verification command is recorded.
5. Write JSON and text artifacts beside the fixture input or at an explicit
   output prefix.
6. Print the text report for local review.

This is the recommended approach because it gives agents a durable review
boundary before implementation work without granting any operational authority.
It also keeps the evidence chain inspectable: fixture catalog -> readiness
review -> later implementation proposal.

Rejected approaches:

- Implementing an exporter in this branch: violates the review-only boundary.
- Documentation-only readiness: useful to humans but weak for agents because it
  cannot be parsed or checked.
- Reusing the fixture validation mode as readiness: validation proves fixture
  shape, while readiness records a reviewer decision, command evidence, and
  explicit handoff.
- CI telemetry gates: thresholds and telemetry-based failure gates require a
  later reviewed implementation and production evidence policy.

## Command Contract

Default invocation:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-capture-fixtures -- --format json \
  > .zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json
zig build causal-production-telemetry-readiness-review -- \
  --from-fixtures .zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json \
  approve \
  --reason "fixtures reviewed for implementation proposal" \
  --verified-command "zig build causal-production-telemetry-capture-fixtures -- validate --format json" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Parser rules:

- `--from-fixtures <fixtures.json>` is required.
- The input path must end with `.json`.
- Decision must be `approve` or `reject`.
- `--reason <reason>` is required and non-empty.
- `--by <actor>` is optional and defaults to `local-reviewer`.
- `--policy <policy>` is optional and defaults to
  `manual-production-telemetry-readiness`.
- `--verified-command <command>` may be supplied multiple times.
- `--out-prefix <path-prefix>` is optional. Without it, output paths are
  derived from the fixture JSON path by appending `-readiness-review`.
- Unknown flags, missing values, unsupported decisions, and unsupported fixture
  schemas fail closed.

## Readiness Model

Top-level fields:

- `schema`
- `schema_version`
- `source_fixtures`
- `decision`
- `readiness_status`
- `ready_for_implementation_proposal`
- `reviewed_by`
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
- `next_branch_if_ready`
- `fixture_summary`
- `checks`
- `required_verification_commands`
- `verified_commands`
- `implementation_proposal_steps`
- `readiness_guardrails`

`readiness_status` is:

- `ready` when the reviewer approves, all evidence checks pass, and all
  required verification commands are recorded.
- `blocked` when the reviewer rejects, evidence checks fail, verification
  evidence is missing, or fixture boundaries are incomplete.

`ready_for_implementation_proposal=true` means a later proposal branch may be
started. It does not mean telemetry is implemented or approved for deployment.

## Checks

The tool should emit one check per readiness concern:

- `fixture-schema`: fixture schema is
  `zigeffect.causal.production-telemetry-capture-fixtures.v1`.
- `fixture-status`: fixture status is `fixtures-only`.
- `reviewer-decision`: decision and reason are present.
- `decision-approved`: decision is `approve`.
- `authority-boundary`: fixture artifact and readiness artifact preserve
  `applied=false`, `mutation_authority="none"`,
  `production_telemetry_ingestion=false`, `live_exporter_enabled=false`,
  `durable_write_enabled=false`, and `ci_gate_enabled=false`.
- `source-contracts-present`: fixture catalog cites the design report, load
  observation harness, OTel record bridge, backend conformance,
  production-artifact aggregation, artifact access control, and encryption
  policy contracts.
- `positive-fixture-coverage`: positive fixtures cover runtime trace, app
  semantic, backend OTel export, redaction access, local observation
  correlation, and sampling boundary examples.
- `negative-fixture-coverage`: negative fixtures reject live exporters,
  collector endpoints, raw request bodies, raw headers, raw prompts,
  credentials, unbounded cardinality, sampled-out forwarding, production
  capacity claims, non-NenDB durable storage, Cockroach adapter work, alternate
  renderers, CI telemetry gates, and mutation authority.
- `validation-checks-passed`: every fixture validation check is `passed`.
- `nendb-only-retention`: retention and negative fixtures keep durable storage
  scoped to NenDB-compatible future work.
- `solid-webui-direction`: negative fixtures continue to reject React and
  alternate renderer work.
- `required-verification-recorded`: reviewer recorded every required command.

## Required Verification Commands

The readiness report requires these exact commands:

```sh
zig build causal-production-telemetry-capture-fixtures -- validate --format json
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
```

Repo-level verification after implementation also includes:

```sh
bun run check
bun run zig:test
git diff --check
```

## Artifact Paths

If the fixture input is:

```text
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json
```

then default output paths are:

```text
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.txt
```

If `--out-prefix .zig-cache/causal-artifacts/custom-telemetry` is supplied,
output paths are:

```text
.zig-cache/causal-artifacts/custom-telemetry.json
.zig-cache/causal-artifacts/custom-telemetry.txt
```

## Agent Guidance

Agents may use a `ready` report to propose the next implementation-proposal
branch. They must cite readiness check names and the source fixture path. They
must not claim that readiness enables live telemetry, grants exporter
authority, authorizes durable writes, proves production capacity, changes CI
gates, or applies source changes.

Agents must treat `blocked` reports as explicit stop signs. A blocked report can
guide fixture or design repairs, but it cannot justify implementation work.

## Files

- Create:
  `packages/zigeffect/tools/causal_production_telemetry_readiness_review.zig`
- Create:
  `packages/zigeffect/docs/production-telemetry-readiness-review.md`
- Modify `packages/zigeffect/build.zig`
- Modify `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify `packages/zigeffect/README.md`
- Modify `packages/zigeffect/docs/operations.md`
- Modify `packages/zigeffect/docs/schema-governance.md`
- Modify `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify `packages/zigeffect/docs/production-telemetry-capture-fixtures.md`
- Modify `packages/zigeffect/docs/roadmap.md`
- Modify
  `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_readiness_review.zig
zig build causal-production-telemetry-capture-fixtures -- --format json \
  > ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json
zig build causal-production-telemetry-readiness-review -- \
  --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json \
  approve \
  --reason "fixtures reviewed for implementation proposal" \
  --verified-command "zig build causal-production-telemetry-capture-fixtures -- validate --format json" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-production-telemetry-readiness-review -- \
  --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json \
  reject \
  --reason "negative readiness path"
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

## Self-Review

- Incomplete marker scan: no incomplete markers remain.
- Consistency check: the command contract, fields, checks, guardrails, and
  verification commands all preserve record-only telemetry readiness.
- Scope check: this is a single milestone that produces one readiness tool and
  supporting docs.
- Ambiguity check: `ready` only authorizes a future implementation proposal; it
  does not authorize live telemetry or source mutation.
