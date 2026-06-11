# App-Facing Production Integration Implementation Proposal

`causal-app-facing-production-integration-implementation-proposal` emits
`zigeffect.causal.app-facing-production-integration-implementation-proposal.v1`
as a record-only proposal artifact over a ready app-facing production
integration readiness-review JSON artifact.

It is the gate between reviewed readiness evidence and the next guarded
app-facing integration boundary branch. `proposal_status=approved` means a
future boundary branch may start. It does not mean app changes were applied,
production telemetry was enabled, durable writes exist, CI gates are active,
or production app health was proven.

## Command

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

The command writes:

- `<readiness-base>-implementation-proposal.json`;
- `<readiness-base>-implementation-proposal.txt`.

Use `--out-prefix <path-prefix>` to choose a different output path. A reject
proposal is also useful:

```sh
zig build causal-app-facing-production-integration-implementation-proposal -- \
  --from-readiness ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review.json \
  reject \
  --reason "negative proposal path" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-production-integration-implementation-proposal-negative
```

## Boundary Handoff

An approved proposal unlocks only the guarded boundary review. It must be
consumed by `causal-app-facing-production-integration-boundary` before any
local app-facing integration fixture branch starts:

```sh
zig build causal-app-facing-production-integration-boundary -- \
  --from-proposal ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal.json \
  approve \
  --reason "proposal evidence reviewed for app-facing local fixtures" \
  --verified-command "zig build causal-app-facing-production-integration-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review.json approve --reason \"ready evidence reviewed for app-facing integration planning\" --verified-command \"zig build causal-app-facing-production-integration-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json approve --reason \\\"fixtures reviewed for implementation proposal\\\" --verified-command \\\"zig build causal-app-facing-production-integration-fixtures -- validate --format json\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The boundary emits
`zigeffect.causal.app-facing-production-integration-boundary.v1` and keeps
app runtime refs, bounded agent-query projection, NenDB handoff refs, audit
remediation review links, SolidJS read-only preview scope, and advisory CI
artifact scope record-only.

## Required Evidence

Approved proposals require these exact verification commands to be recorded:

```sh
zig build causal-app-facing-production-integration-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json approve --reason "fixtures reviewed for implementation proposal" --verified-command "zig build causal-app-facing-production-integration-fixtures -- validate --format json" --verified-command "zig build causal-schema-governance -- --format json" --verified-command "zig build causal-production-hardening-backlog -- --format json" --verified-command "zig build examples" --verified-command "zig build test"
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
```

The source readiness artifact must separately record its readiness verification
commands. The proposal tool records evidence that a proposer ran them. It does
not run the commands itself.

## Proposal Checks

The report evaluates:

- readiness schema and ready status;
- source readiness reviewer approval;
- proposal decision and reason;
- `applied=false` and `mutation_authority=none`;
- disabled live telemetry, exporter, durable write, app mutation, and CI flags;
- linked source fixture JSON;
- all expected app-facing readiness checks;
- readiness verification command evidence;
- proposal verification command evidence;
- NenDB-only durable direction and Cockroach exclusion;
- SolidJS inside `webui-dev/zig-webui` by blocking React or alternate renderer
  work;
- app runtime scope by blocking raw payload capture and app mutation authority;
- agent-query scope by preserving bounded app trace/query evidence.

## Boundary

Every implementation-proposal artifact keeps:

- `applied=false`;
- `mutation_authority="none"`;
- `production_telemetry_ingestion=false`;
- `live_exporter_enabled=false`;
- `durable_write_enabled=false`;
- `app_mutation_enabled=false`;
- `ci_gate_enabled=false`.

Durable direction remains NenDB adapter only. Cockroach adapter work is out of
scope for this milestone.

## Status

- `approved`: the proposer approved, the source readiness artifact is ready,
  every proposal check passed, and every required verification command was
  recorded.
- `blocked`: the proposer rejected, readiness evidence is blocked, a required
  readiness or proposal check failed, or verification evidence is missing.

`approved_for_next_branch=true` means the next branch may be:

`codex/zigeffect-causal-app-facing-production-integration-boundary`

It does not mean production integration is implemented, applied, deployed, or
approved for live app mutation.

## Proposal Phases

The approved proposal records these later phases:

1. `app-runtime-boundary`
2. `agent-query-projection`
3. `nendb-history-handoff`
4. `audit-remediation-bridge`
5. `solid-webui-readonly-preview`
6. `ci-artifact-preview`

Only the guarded app-facing integration boundary is the next recommended
branch. Later phases remain advisory until reviewed by their own artifacts.

## Blocked Claims

The artifact explicitly blocks raw request/header/prompt/credential/PII
capture, raw agent-query payload scraping, app mutation authority, live
production telemetry ingestion, live exporters, durable production writes,
non-NenDB durable storage, Cockroach adapter work, CI gate enforcement, React
or alternate renderer work, and production health claims.

## Agent Guidance

Agents may use an approved proposal to start
`codex/zigeffect-causal-app-facing-production-integration-boundary`. They must
cite the proposal artifact, source readiness path, source fixture path, check
names, required commands, recorded commands, and approved phase names.

Agents must treat blocked proposal artifacts as stop signs. Blocked proposals
can guide fixture, readiness, or proposal repair, but they cannot justify app
mutation, telemetry, exporter, durable write, CI gate, Cockroach, renderer, raw
payload, or production-health work.

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
