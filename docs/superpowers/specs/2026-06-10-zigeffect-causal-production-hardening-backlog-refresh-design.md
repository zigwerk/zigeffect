# zigeffect Causal Production Hardening Backlog Refresh Design

Date: 2026-06-10

## Purpose

Close the delivered production-hardening backlog sequence and emit a
deterministic refresh artifact that selects the next unresolved roadmap branch.
The refresh must not treat the CI required-status-check report policy chain as
production health, deployment success, customer impact, production capacity, or
cluster readiness.

The selected next branch is:

```text
codex/zigeffect-causal-nendb-durable-history-hardening
```

That branch is the best next foundation for the long-running goal because it
turns the existing NenDB storage writer and retention fixture contracts into a
harder durable-history evidence boundary before replay comparison, richer
workbench state, app-facing integrations, or self-improving agent memory depend
on persisted causal history.

## Context

`causal-production-hardening-backlog` currently reports
`refresh-production-hardening-backlog` and points to
`codex/zigeffect-causal-production-hardening-backlog-refresh`. The backlog now
lists the full production-hardening sequence through required-status-check
enforcement report policy as delivered.

The broader master roadmap still names unresolved or future work after the
production operating model:

- production-grade app-facing integrations;
- durable history hardening;
- comparing arbitrary named audit-chain snapshots;
- deeper runtime regression scenarios for partial config and cause coverage.

The user constraint remains:

- durable database work is NenDB adapter work only;
- no Cockroach adapter work in this sequence;
- workbench work remains SolidJS inside `webui-dev/zig-webui`.

## Approaches Considered

### Approach A: Documentation-Only Backlog Edit

Update the backlog recommendation directly to the next branch and stop there.
This is small, but weak for agents: there is no machine-readable decision
artifact, no candidate list, and no explicit denied-claim catalog.

### Approach B: Deterministic Refresh Artifact

Add `causal-production-hardening-backlog-refresh`, a local read-only tool that
consumes the current backlog JSON, validates the delivered sequence, records
candidate unresolved work, chooses the next branch, and emits JSON/text
artifacts. This matches the rest of the causal governance chain and gives
agents stable evidence for the handoff.

This is the recommended approach.

### Approach C: Start Durable History Directly

Skip the refresh artifact and begin the NenDB durable-history branch. This is
tempting, but it leaves the production-hardening queue in an ambiguous state
after many report-policy branches.

## Goals

- Emit schema
  `zigeffect.causal.production-hardening-backlog-refresh.v1`.
- Consume `zigeffect.causal.production-hardening-backlog.v1` JSON from
  `--from-backlog <path>`.
- Validate the source recommendation is either the transition recommendation
  `refresh-production-hardening-backlog` or the post-refresh recommendation
  `start-nendb-durable-history-hardening`.
- Validate the source recommended branch is either
  `codex/zigeffect-causal-production-hardening-backlog-refresh` or the
  selected post-refresh branch
  `codex/zigeffect-causal-nendb-durable-history-hardening`.
- Record the delivered production-hardening sequence count and the delivered
  terminal item:
  `production-telemetry-ci-gate-required-status-check-enforcement-report-policy`.
- Record unresolved candidates with dependency rationale.
- Select `codex/zigeffect-causal-nendb-durable-history-hardening`.
- Emit readiness fields:
  - `backlog_refresh_status`;
  - `ready_for_next_branch`;
  - `selected_next_branch`;
  - `selected_next_work`;
  - `mutation_authority`.
- Update schema governance, operations docs, backlog docs, roadmap docs, and
  README references.

## Non-Goals

- No source, config, registry, workflow, branch-protection, deployment, rollout,
  app, or production mutation.
- No GitHub API calls, check-run creation, required-status-check creation,
  step-summary writes, pull-request comments, or artifact upload execution.
- No live telemetry ingestion, exporter sends, collector configuration, OTLP
  serialization, runtime pipeline execution, durable writes, or NenDB writes.
- No Cockroach or non-NenDB durable adapter work.
- No hosted dashboard, production cluster readiness, production health,
  deployment success, customer impact, capacity, or cost claim.
- No alternate frontend renderer; future workbench UI remains SolidJS inside
  `zig-webui`.

## CLI

```sh
zig build causal-production-hardening-backlog-refresh -- \
  --from-backlog ../../.zig-cache/causal-artifacts/production-hardening-backlog.json \
  refresh \
  --reason "production hardening backlog refreshed after report policy"
```

Optional:

```sh
--out-prefix ../../.zig-cache/causal-artifacts/production-hardening-backlog-refresh
--verified-command "zig build causal-production-hardening-backlog -- --format json"
--verified-command "zig build causal-schema-governance -- --format json"
--verified-command "zig build examples"
--verified-command "zig build test"
```

The command writes:

- `production-hardening-backlog-refresh.json`;
- `production-hardening-backlog-refresh.txt`.

## Output Model

The JSON artifact includes:

- schema and schema version;
- generated-by command;
- source backlog path, schema, recommendation, and recommended branch;
- reviewer reason and verified commands;
- delivered terminal item and delivered item count;
- unresolved candidate list;
- selected next work and selected branch;
- denied-claim catalog;
- next branch guidance;
- authority booleans, all disabled;
- `mutation_authority="none"`.

Candidate records use a small stable shape:

```text
id
title
recommended_branch
priority
why_now
depends_on
blocked_claims
```

The selected candidate is:

```text
id: nendb-durable-history-hardening
branch: codex/zigeffect-causal-nendb-durable-history-hardening
```

## Checks

The refresh is ready only when all of these pass:

- source backlog schema is
  `zigeffect.causal.production-hardening-backlog.v1`;
- source recommendation is one of:
  - `refresh-production-hardening-backlog`;
  - `start-nendb-durable-history-hardening`;
- source recommended branch is one of:
  - `codex/zigeffect-causal-production-hardening-backlog-refresh`;
  - `codex/zigeffect-causal-nendb-durable-history-hardening`;
- source contains the terminal report-policy item;
- source contains the terminal report-policy build command;
- selected branch is NenDB-only and not Cockroach;
- selected work does not grant mutation authority;
- required verification command evidence is present when provided.

The tool has negative fixtures for:

- wrong source schema;
- unsupported source recommendation;
- missing terminal delivered item;
- Cockroach/non-NenDB branch selection;
- production health or cluster readiness inference;
- live telemetry or durable write inference;
- mutation authority inference.

## Documentation Updates

- `packages/zigeffect/docs/production-hardening-backlog.md` says the
  backlog refresh branch is delivered after implementation and points to the
  NenDB durable-history hardening branch.
- `packages/zigeffect/docs/operations.md` documents how to run the refresh and
  how agents interpret the selected next branch.
- `packages/zigeffect/docs/roadmap.md` and the master roadmap record the
  handoff from production hardening to NenDB durable history hardening.
- `packages/zigeffect/README.md` includes the command in the causal
  operations list.

## Verification

Focused verification:

```sh
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog_refresh.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-production-hardening-backlog -- --format json
zig build causal-production-hardening-backlog-refresh -- --help
```

Integration verification:

```sh
cd packages/zigeffect
zig build causal-production-hardening-backlog -- --format json 2> ../../.zig-cache/causal-artifacts/production-hardening-backlog.json
zig build causal-production-hardening-backlog-refresh -- --from-backlog ../../.zig-cache/causal-artifacts/production-hardening-backlog.json refresh --reason "production hardening backlog refreshed after report policy" --verified-command "zig build causal-production-hardening-backlog -- --format json" --verified-command "zig build causal-schema-governance -- --format json" --verified-command "zig build examples" --verified-command "zig build test"
zig build causal-schema-governance -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

## Success Criteria

- A future agent can run one command to see why production hardening returns to
  the main roadmap.
- The next branch is explicitly NenDB durable-history hardening.
- The artifact prevents overclaiming about CI publication, production health,
  deployment success, capacity, cluster readiness, and mutation authority.
- The long-running goal remains active after this branch; this branch is a
  handoff, not goal completion.
