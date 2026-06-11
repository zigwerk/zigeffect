# App-Facing Production Integration Boundary

`causal-app-facing-production-integration-boundary` consumes an approved
app-facing production integration implementation-proposal JSON artifact and
emits `zigeffect.causal.app-facing-production-integration-boundary.v1`.

It is the gate between proposal approval and local app-facing integration
fixtures. It records a guarded app-runtime boundary only. It does not mutate an
app, capture raw payloads, write app config or app data, write NenDB production
history, change deployments, enforce CI, or mark anything as applied.

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

The command writes:

- `<proposal-base>-app-facing-boundary.json`;
- `<proposal-base>-app-facing-boundary.txt`.

Use `--out-prefix <path-prefix>` to choose a different output path.

Use `reject --reason <reason>` to produce a blocked negative artifact:

```sh
zig build causal-app-facing-production-integration-boundary -- \
  --from-proposal ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal.json \
  reject \
  --reason "negative boundary path" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-production-integration-boundary-negative
```

## Boundary Authority

The boundary artifact keeps these authority fields fixed:

- `applied=false`
- `mutation_authority="none"`
- `production_telemetry_ingestion=false`
- `live_exporter_enabled=false`
- `durable_write_enabled=false`
- `app_mutation_enabled=false`
- `ci_gate_enabled=false`
- `raw_payload_capture_enabled=false`
- `app_config_write_enabled=false`
- `app_data_write_enabled=false`
- `deployment_mutation_enabled=false`
- `nendb_write_enabled=false`

Network transport, collector endpoint, and OTLP serialization fields also remain
disabled because this is not a live telemetry branch.

## App Boundary Contract

The emitted `app_boundary_contract` contains:

- `boundary_id=app-facing-production-integration-guarded`
- `source_contract=app-runtime`
- `trace_ref_state=ref-only`
- `raw_payload_state=blocked`
- `app_mutation_state=disabled`
- `agent_query_state=bounded-trace-data-only`
- `nendb_handoff_state=ref-only-no-production-write`
- `audit_compare_state=evidence-only-not-mutation-proof`
- `remediation_governance_state=handoff-only`
- `solid_webui_state=read-only-preview-only`
- `ci_state=advisory-artifacts-only`

The emitted `local_projection_fixtures` names the next local-fixtures branch
must implement:

- `worker-request-runtime-ref-boundary`
- `background-job-runtime-ref-boundary`
- `agent-query-bounded-projection-boundary`
- `nendb-history-handoff-ref-boundary`
- `audit-remediation-review-link-boundary`
- `solid-webui-readonly-handoff-boundary`

## Checks

The boundary report evaluates:

- proposal schema, approved status, and approved decision;
- boundary decision and reason;
- disabled source and boundary authority fields;
- source readiness and fixture JSON chain;
- all required source proposal checks;
- proposal phase handoff for app runtime, agent query, and NenDB history;
- source proposal verification command evidence;
- boundary verification command evidence;
- app runtime reference-only boundary;
- bounded agent-query projection boundary;
- NenDB handoff as reference-only with no production writes;
- audit/remediation evidence-only boundary;
- no app config, app data, deployment, NenDB, or app mutation authority;
- NenDB-only durable direction;
- SolidJS inside `webui-dev/zig-webui`.

## Status

- `approved`: the source proposal is approved, every source proposal check
  passed, every required source and boundary verification command was recorded,
  and every app-facing authority boundary is disabled.
- `blocked`: the reviewer rejected, proposal evidence is blocked, a required
  check failed, or required verification command evidence is missing.

`approved_for_next_branch=true` means the next branch may be:

`codex/zigeffect-causal-app-facing-production-integration-local-fixtures`

It does not mean production integration is implemented, applied, deployed,
healthy, fixed, or approved for app mutation.

## Local-Fixtures Handoff

An approved boundary unlocks only the local-fixtures review. It must be
consumed by `causal-app-facing-production-integration-local-fixtures` before
any app-facing NenDB handoff fixture branch starts:

```sh
zig build causal-app-facing-production-integration-local-fixtures -- \
  --from-boundary ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary.json \
  approve \
  --reason "guarded boundary reviewed for local app-facing fixtures" \
  --verified-command "zig build causal-app-facing-production-integration-boundary -- --from-proposal ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal.json approve --reason \"proposal evidence reviewed for app-facing local fixtures\" --verified-command \"zig build causal-app-facing-production-integration-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review.json approve --reason \\\"ready evidence reviewed for app-facing integration planning\\\" --verified-command \\\"zig build causal-app-facing-production-integration-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json approve --reason \\\\\\\"fixtures reviewed for implementation proposal\\\\\\\" --verified-command \\\\\\\"zig build causal-app-facing-production-integration-fixtures -- validate --format json\\\\\\\" --verified-command \\\\\\\"zig build causal-schema-governance -- --format json\\\\\\\" --verified-command \\\\\\\"zig build causal-production-hardening-backlog -- --format json\\\\\\\" --verified-command \\\\\\\"zig build examples\\\\\\\" --verified-command \\\\\\\"zig build test\\\\\\\"\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The local-fixtures artifact records concrete worker request refs, background
job refs, bounded agent-query projections, NenDB handoff refs, audit/remediation
review links, SolidJS read-only preview samples, and advisory CI artifact
previews. It still keeps all app mutation, raw payload capture, production
NenDB writes, CI enforcement, deployment mutation, and live workbench authority
disabled.

## Blocked Claims

The artifact explicitly blocks app mutation, raw payload capture, app config
writes, app data writes, deployment mutation, NenDB production writes,
audit-chain comparisons as mutation proof, automatic remediation application,
live telemetry, durable production writes, non-NenDB durable adapters,
Cockroach adapter work, CI enforcement gates, React or alternate renderer work,
and `applied=true`.

## Agent Guidance

Agents may use an approved boundary to start
`codex/zigeffect-causal-app-facing-production-integration-local-fixtures`.
They must cite the boundary artifact, source proposal path, source readiness
path, source fixture path, check names, required commands, recorded commands,
and app boundary contract entries.

Agents must treat blocked boundary artifacts as stop signs. Blocked boundaries
can guide proposal or fixture repair, but they cannot justify app mutation,
raw payload capture, telemetry, durable writes, CI gates, Cockroach, renderer,
deployment, NenDB production write, or production-health work.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_boundary.zig
zig build test
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
cd ../..
bun run check
bun run zig:test
git diff --check
```
