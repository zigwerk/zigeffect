# App-Facing Production Integration Local Fixtures

`causal-app-facing-production-integration-local-fixtures` consumes an approved
app-facing production integration boundary JSON artifact and emits
`zigeffect.causal.app-facing-production-integration-local-fixtures.v1`.

It is a local evidence milestone only. It builds fixture records that agents can
read when planning app-facing runtime work, bounded agent queries, NenDB handoff
records, audit/remediation review links, SolidJS webui previews, and advisory
CI artifacts. It does not integrate with an app runtime, query live app data,
capture raw payloads, write NenDB history, mutate app config/data, change
deployments, enforce CI, or mark anything as applied.

## Command

```sh
cd packages/zigeffect
mkdir -p ../../.zig-cache/causal-artifacts
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

The command writes:

- `<boundary-base>-local-fixtures.json`;
- `<boundary-base>-local-fixtures.txt`.

Use `--out-prefix <path-prefix>` to choose a different output path.

Use `reject --reason <reason>` to produce a blocked negative artifact:

```sh
zig build causal-app-facing-production-integration-local-fixtures -- \
  --from-boundary ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary.json \
  reject \
  --reason "negative local fixtures path" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-production-integration-local-fixtures-negative
```

## Authority

The local-fixtures artifact keeps these authority fields fixed:

- `applied=false`
- `mutation_authority="none"`
- `production_telemetry_ingestion=false`
- `live_exporter_enabled=false`
- `network_send_enabled=false`
- `collector_endpoint_configured=false`
- `otlp_serialization_enabled=false`
- `durable_write_enabled=false`
- `app_mutation_enabled=false`
- `ci_gate_enabled=false`
- `raw_payload_capture_enabled=false`
- `app_config_write_enabled=false`
- `app_data_write_enabled=false`
- `deployment_mutation_enabled=false`
- `nendb_write_enabled=false`
- `app_runtime_integration_enabled=false`
- `agent_query_live_projection_enabled=false`
- `solid_webui_preview_enabled=false`
- `local_fixture_mode=true`

`local_fixture_mode=true` means the artifact is usable as deterministic design
and test evidence. It is not proof that any runtime, app, workbench, CI, or
durable integration exists.

## Fixture Catalog

The emitted `fixture_catalog` contains:

- `worker-request-runtime-ref-fixture`
- `background-job-runtime-ref-fixture`
- `agent-query-bounded-projection-fixture`
- `nendb-history-handoff-ref-fixture`
- `audit-remediation-review-link-fixture`
- `solid-webui-readonly-preview-fixture`
- `ci-advisory-artifact-preview-fixture`

Each fixture records:

- the source boundary label it satisfies;
- an input reference name;
- an output artifact name;
- allowed output fields;
- blocked raw, mutation, live, durable, CI, renderer, and Cockroach fields.

## Checks

The local-fixtures report evaluates:

- source boundary schema, approved status, and approved decision;
- fixture decision and reason;
- disabled source and local fixture authority fields;
- linked source proposal, readiness, and fixture JSON paths;
- all required source boundary checks;
- app boundary contract entries;
- local projection fixture labels from the boundary;
- fixture catalog presence;
- runtime ref fixture coverage;
- bounded agent-query fixture coverage;
- NenDB handoff as ref-only with no writes;
- audit/remediation review-only links;
- SolidJS webui read-only preview handoff;
- advisory CI artifact preview;
- fixture validation checks;
- source boundary verification command evidence;
- local fixture verification command evidence;
- NenDB-only durable direction;
- SolidJS inside `webui-dev/zig-webui`.

## Status

- `ready`: the boundary is approved, every source boundary check passed, every
  required source and local verification command was recorded, and every local
  fixture family satisfies the guarded boundary.
- `blocked`: the reviewer rejected, boundary evidence is blocked, a required
  check failed, a fixture family is missing, or required verification command
  evidence is missing.

`ready_for_next_branch=true` means the next branch may be:

`codex/zigeffect-causal-app-facing-production-integration-nendb-handoff-fixtures`

It does not mean app runtime integration, live agent projection, raw payload
capture, production NenDB writes, app mutation, CI enforcement, deployment, or
SolidJS live preview has been implemented.

## Blocked Claims

The artifact blocks app runtime integration, live agent-query projection,
SolidJS preview serving, app mutation, raw payload capture, app config writes,
app data writes, deployment mutation, NenDB production writes, audit-chain
comparison as mutation proof, automatic remediation application, fixed or
deployed app claims, live telemetry, network send, OTLP serialization, durable
production writes, non-NenDB adapters, Cockroach adapter work, CI enforcement,
React or alternate renderer work, and mutation authority.

## Agent Guidance

Agents may use a ready local-fixtures artifact to start the app-facing NenDB
handoff fixture branch. They must cite the source boundary, proposal,
readiness, fixture paths, check names, fixture catalog ids, validation checks,
required commands, and recorded commands.

Blocked local-fixtures artifacts can guide repair work only. They cannot
justify app integration, production writes, CI gates, deployment changes, raw
payload capture, Cockroach work, alternate renderer work, or `applied=true`.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_local_fixtures.zig
zig test tools/causal_production_hardening_backlog.zig
zig build test
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
cd ../..
bun run check
bun run zig:test
git diff --check
```
