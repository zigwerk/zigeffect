# zigeffect Causal Production Telemetry NenDB Retention Fixtures Design

## Summary

Add a production telemetry NenDB-retention-fixtures artifact for zigeffect. The
artifact consumes a `ready` production telemetry local-pipeline-fixtures JSON
artifact and emits deterministic fixture evidence showing how redacted local
telemetry envelopes can map onto NenDB node, edge, retention policy,
compaction, backup, and recovery records.

This branch is a mapping and review gate only. It must not write NenDB records,
run a durable writer, ingest live telemetry, execute a runtime pipeline,
serialize OTLP, configure exporters, send network requests, configure collector
endpoints, write durable production storage, fail CI on telemetry thresholds,
size production capacity, add non-NenDB adapter work, switch the workbench
renderer, or grant mutation authority.

## Branch

- Branch:
  `codex/zigeffect-causal-production-telemetry-nendb-retention-fixtures`
- Schema:
  `zigeffect.causal.production-telemetry-nendb-retention-fixtures.v1`
- Command:
  `zig build causal-production-telemetry-nendb-retention-fixtures`
- Recommendation after delivery:
  `start-production-telemetry-workbench-readonly-preview`
- Next branch if ready:
  `codex/zigeffect-causal-production-telemetry-workbench-readonly-preview`

## Context

The production telemetry chain is now:

1. capture design;
2. capture fixtures;
3. readiness review;
4. implementation proposal;
5. exporter boundary;
6. local pipeline fixtures.

The ready local-pipeline artifact records normalized envelope fixtures for:

- runtime spans;
- app semantic references;
- backend OTel records;
- redaction and access metadata;
- sampling kept/dropped states;
- correlation links.

The existing NenDB storage boundary already exposes:

- `zigeffect.causal.nendb_node.v1`;
- `zigeffect.causal.nendb_edge.v1`;
- `zigeffect.causal.nendb-retention-report.v1`;
- `CausalNendbRetentionPolicy`;
- `CausalNendbRetentionReport`;
- retention policy values used by durable production retention:
  - TTL: 14 days;
  - max events per retained bundle: 4096;
  - compaction trigger: 2048 events;
  - compaction target: 1024 events;
  - backup required: true;
  - recovery verification required: true.

This branch should connect those two worlds without enabling writes. It gives
future agents a concrete bridge from telemetry fixture envelopes to NenDB
record shapes, while keeping the durable adapter path narrowly NenDB-only.

Relevant source contracts:

- `zigeffect.causal.production-telemetry-local-pipeline-fixtures.v1` provides
  the ready local envelope fixture catalog this branch consumes.
- `zigeffect.causal.production-telemetry-exporter-boundary.v1` proves the
  no-network, no-OTLP, no-collector boundary behind the local fixtures.
- `zigeffect.causal.durable-production-retention.v1` defines the general
  NenDB-only durable retention policy.
- `zigeffect.causal.nendb-retention-report.v1` defines the backend-side
  retention report shape future runtime tests and agents can evaluate.

## Goals

1. Add a schema-governed NenDB-retention-fixtures artifact.
2. Consume local-pipeline fixture JSON from a file path so agents can cite the
   exact ready fixture evidence they used.
3. Require a retention fixture decision and reason. `approve` means the
   artifact may recommend the workbench read-only preview branch; `reject`
   produces a blocked retention fixture artifact.
4. Require explicit verification command evidence before retention fixtures can
   be `ready`.
5. Verify local-pipeline schema, ready status, approved decision, source
   authority fields, no-network/no-OTLP/no-durable-write posture, source chain
   links, local-pipeline checks, local-pipeline verification command evidence,
   local fixture catalog, NenDB node and edge fixture mappings, retention
   policy records, TTL metadata policy, compaction records, backup and recovery
   markers, NenDB-only durable direction, and SolidJS `webui-dev/zig-webui`
   direction.
6. Emit text and JSON artifacts with retention fixture status, source local
   pipeline path, source boundary/proposal/readiness/fixture paths, checks,
   mapping catalog, retention policy fixtures, validation checks, blocked
   claims, required commands, recorded commands, and next branch.
7. Keep `applied=false`, `mutation_authority="none"`,
   `production_telemetry_ingestion=false`, `live_exporter_enabled=false`,
   `network_send_enabled=false`, `collector_endpoint_configured=false`,
   `otlp_serialization_enabled=false`, `runtime_pipeline_enabled=false`,
   `durable_write_enabled=false`, `nendb_write_enabled=false`,
   `ci_gate_enabled=false`, `local_pipeline_fixture_mode=true`, and
   `nendb_retention_fixture_mode=true`.
8. Update docs, schema governance, production hardening backlog, README,
   operations, roadmap, and the master roadmap.

## Non-Goals

- Runtime telemetry ingestion or runtime instrumentation changes.
- Running a local, CI, or production telemetry pipeline.
- OTLP protobuf serialization, SDK setup, collector delivery, network calls,
  or collector endpoint configuration.
- Production credentials, hostnames, endpoints, secrets, raw user ids, tenant
  ids, request bodies, headers, prompts, or raw payload capture.
- NenDB writes, durable writer execution, compaction execution, backup
  execution, restore execution, or production storage mutation.
- Direct upstream NenDB package integration beyond the existing local adapter
  boundary.
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

Create one deterministic Zig fixture tool that mirrors the local-pipeline
review shape:

1. Read a local-pipeline-fixtures JSON artifact from disk.
2. Parse and validate the local-pipeline schema.
3. Fail closed unless the source artifact is `ready` and
   `ready_for_next_branch=true`.
4. Evaluate fixed NenDB retention fixture checks for authority boundaries,
   no-network transport posture, no-OTLP serialization, disabled durable and
   NenDB writes, source fixture catalog coverage, source verification command
   evidence, node/edge mapping coverage, retention policy constants, TTL
   metadata policy, compaction policy, backup/recovery marker coverage,
   durable adapter scope, and workbench renderer scope.
5. Mark fixtures `ready` only when the reviewer approves, all checks pass, and
   every required NenDB-retention verification command is recorded.
6. Write JSON and text artifacts beside the local-pipeline input or at an
   explicit output prefix.
7. Print the text report for local review.

This is the recommended approach because it gives future workbench and agent
preview work a concrete, machine-readable durable mapping contract while still
keeping actual durable writes behind a later reviewed authority boundary.

Rejected approaches:

- Writing NenDB retention records now: this branch is the fixture and mapping
  gate, not the durable writer.
- Pulling in upstream NenDB now: the current path is the existing zigeffect
  NenDB adapter boundary, not a new package integration.
- Extending to Cockroach or RoachGraph storage: the user explicitly narrowed
  this roadmap lane to NenDB only.
- Adding workbench UI now: workbench read-only preview is the next branch after
  retention fixtures.

## Command Contract

Default invocation:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-nendb-retention-fixtures -- \
  --from-local-pipeline ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures.json \
  approve \
  --reason "ready local pipeline fixtures reviewed for NenDB retention mapping" \
  --verified-command "zig build causal-production-telemetry-local-pipeline-fixtures" \
  --verified-command "zig build causal-nendb-storage-backend" \
  --verified-command "zig build causal-durable-production-retention -- --format json" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Parser rules:

- `--from-local-pipeline <local-pipeline.json>` is required.
- The input path must end with `.json`.
- Decision must be `approve` or `reject`.
- `--reason <reason>` is required and non-empty.
- `--by <actor>` is optional and defaults to `nendb-retention-reviewer`.
- `--policy <policy>` is optional and defaults to
  `manual-production-telemetry-nendb-retention-fixtures`.
- `--verified-command <command>` may be supplied multiple times.
- `--out-prefix <path-prefix>` is optional. Without it, output paths are
  derived from the local-pipeline JSON path by appending
  `-nendb-retention-fixtures`.
- Unknown flags, missing values, unsupported decisions, and unsupported source
  schemas fail closed.

## Fixture Model

Top-level fields:

- `schema`
- `schema_version`
- `source_local_pipeline`
- `source_boundary`
- `source_proposal`
- `source_readiness`
- `source_fixtures`
- `decision`
- `retention_fixture_status`
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
- `runtime_pipeline_enabled`
- `durable_write_enabled`
- `nendb_write_enabled`
- `ci_gate_enabled`
- `local_pipeline_fixture_mode`
- `nendb_retention_fixture_mode`
- `source_branch`
- `recommendation`
- `next_branch_if_ready`
- `source_summary`
- `checks`
- `nendb_mapping_fixtures`
- `retention_policy_fixture`
- `retention_validation_checks`
- `implementation_gates`
- `non_goals`
- `blocked_claims`
- `required_verification_commands`
- `verified_commands`
- `agent_guidance`

`retention_fixture_status` is:

- `ready` when the reviewer approves, the source local-pipeline artifact is
  ready, every retention fixture check passes, and every required verification
  command is recorded.
- `blocked` when the reviewer rejects, the source local-pipeline artifact is
  blocked, a required source or retention check fails, or verification evidence
  is missing.

`ready_for_next_branch=true` means a later
`codex/zigeffect-causal-production-telemetry-workbench-readonly-preview`
branch may be started. It does not mean NenDB records are written, compaction
or backups are executed, retention is enforced, production telemetry is
ingested, or live production use is approved.

## NenDB Mapping Fixtures

The approved artifact should define these mapping fixtures:

- `nendb-runtime-event-node-fixture`
  - source: `runtime-span-normalized-envelope`
  - target schema: `zigeffect.causal.nendb_node.v1`
  - label: `causal.telemetry.runtime_span`
  - retained fields: `event_id_ref`, `trace_id_ref`, `span_id_ref`,
    `parent_span_id_ref`, `causal_event_ref`, `redaction_state`,
    `sample_state`
  - blocked fields: raw payloads, headers, prompts, credentials, raw tenant
    ids, raw user ids, collector endpoint, network address
- `nendb-app-semantic-node-fixture`
  - source: `app-semantic-normalized-envelope`
  - target schema: `zigeffect.causal.nendb_node.v1`
  - label: `causal.telemetry.app_semantic`
  - retained fields: `event_id_ref`, `domain_entity_ref`, `schema_ref`,
    `data_subject_ref`, `operation_ref`, `redaction_state`, `sample_state`
  - blocked fields: raw request bodies, raw response bodies, prompt text,
    credential material, raw PII
- `nendb-otel-attribute-node-fixture`
  - source: `backend-otel-local-envelope`
  - target schema: `zigeffect.causal.nendb_node.v1`
  - label: `causal.telemetry.otel_ref`
  - retained fields: `otel_schema_ref`, `trace_id_ref`, `span_id_ref`,
    `attribute_refs`, `redaction_state`, `sample_state`
  - blocked fields: collector endpoint, auth headers, wire payload bytes,
    exporter SDK configuration, OTLP protobuf bytes
- `nendb-redaction-access-node-fixture`
  - source: `redaction-access-reviewed-envelope`
  - target schema: `zigeffect.causal.nendb_node.v1`
  - label: `causal.telemetry.redaction_access`
  - retained fields: `visibility_class`, `redaction_state`,
    `access_policy_ref`, `denied_raw_fields`
  - blocked fields: raw secrets, raw credentials, raw headers, raw prompts,
    raw tenant ids, raw user ids
- `nendb-sampling-retention-node-fixture`
  - source: `sampling-kept-envelope` and `sampling-dropped-envelope`
  - target schema: `zigeffect.causal.nendb_node.v1`
  - label: `causal.telemetry.sampling`
  - retained fields: `sample_state`, `sample_policy_ref`, `sample_reason`,
    `retained_fields`
  - blocked fields: unsampled raw payload fields, wall-clock randomness,
    production traffic rates, production capacity claims
- `nendb-correlation-edge-fixture`
  - source: `correlation-link-envelope`
  - target schema: `zigeffect.causal.nendb_edge.v1`
  - label: `causal.telemetry.correlates`
  - retained fields: `from_event_ref`, `to_artifact_ref`,
    `causal_event_ref`, `trace_id_ref`, `schema_ref`
  - blocked fields: raw payload joins, source database reads
- `nendb-retention-policy-record-fixture`
  - source: durable production retention policy
  - target schema: `zigeffect.causal.nendb-retention-report.v1`
  - retained fields: `ttl_days=14`, `max_events=4096`,
    `compaction_trigger_events=2048`, `compact_to_events=1024`,
    `backup_required=true`, `recovery_required=true`
  - blocked fields: production byte estimates, production cost estimates,
    live deletion decisions
- `nendb-compaction-window-fixture`
  - source: durable production retention policy
  - target schema: `zigeffect.causal.nendb-retention-report.v1`
  - retained fields: `compaction_required_ref`, `preserve_run_roots`,
    `preserve_terminal_failures`, `preserve_governance_artifacts`
  - blocked fields: compaction execution, destructive deletion
- `nendb-backup-recovery-marker-fixture`
  - source: durable production retention policy
  - target schema: `zigeffect.causal.nendb-retention-report.v1`
  - retained fields: `backup_required`, `recovery_required`,
    `oldest_retained_event_id_ref`, `newest_retained_event_id_ref`,
    `lineage_recovery_check_ref`
  - blocked fields: backup execution, restore execution, live credentials

## Retention Validation Checks

The report should include fixed validation checks:

- `source-local-pipeline-ready`
- `source-authority-disabled`
- `source-fixture-catalog-covered`
- `nendb-node-mappings-present`
- `nendb-edge-mappings-present`
- `retention-policy-constants-match`
- `ttl-policy-record-only`
- `compaction-policy-record-only`
- `backup-recovery-markers-present`
- `nendb-write-disabled`
- `durable-write-disabled`
- `non-nendb-scope-rejected`
- `cockroach-scope-rejected`
- `workbench-preview-next-only`

## Checks

The report should evaluate:

- source local-pipeline schema, ready status, and approved decision;
- retention fixture decision and reason;
- authority boundary fields;
- disabled runtime pipeline, network send, collector endpoint, OTLP
  serialization, durable writes, NenDB writes, and CI gates;
- source proposal, readiness, fixture, boundary, and local-pipeline path
  linkage;
- source local-pipeline checks and verification command evidence;
- mapping fixture catalog presence;
- node mapping coverage for runtime, app semantic, OTel, redaction/access, and
  sampling records;
- edge mapping coverage for correlation links;
- retention policy fixture constants;
- TTL, compaction, backup, and recovery validation checks;
- NenDB-only durable direction;
- SolidJS `webui-dev/zig-webui` direction.

## Output Paths

For this input:

```text
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures.json
```

default output paths are:

```text
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures.json
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures.txt
```

## Agent Guidance

Agents may use a `ready` NenDB-retention-fixtures artifact to start
`codex/zigeffect-causal-production-telemetry-workbench-readonly-preview`. They
must cite the retention fixture artifact, source local-pipeline artifact,
source boundary, source proposal, source readiness, source fixtures, mapping
catalog, retention policy constants, validation checks, required commands,
recorded commands, and blocked claims.

Agents must treat `blocked` retention artifacts as stop signs. Blocked
artifacts can guide source local-pipeline repair, mapping repair, retention
policy review, or verification evidence repair, but they cannot justify
workbench preview work or durable writes.

## Documentation And Governance Updates

Update:

- `packages/zigeffect/build.zig`;
- `packages/zigeffect/tools/causal_schema_governance.zig`;
- `packages/zigeffect/tools/causal_production_hardening_backlog.zig`;
- `packages/zigeffect/docs/schema-governance.md`;
- `packages/zigeffect/docs/production-hardening-backlog.md`;
- `packages/zigeffect/docs/production-hardening-completion-audit.md`;
- `packages/zigeffect/docs/operations.md`;
- `packages/zigeffect/docs/roadmap.md`;
- `packages/zigeffect/README.md`;
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`.

The backlog should mark `production-telemetry-nendb-retention-fixtures`
delivered and move the recommendation to
`start-production-telemetry-workbench-readonly-preview`.

## Testing And Verification

Use test-driven implementation:

1. red tests for schema constants, option parsing, missing source path, output
   path derivation, and authority-preserving ready/blocked reports;
2. green implementation of parser, source artifact parser, fixture evaluator,
   JSON/text formatters, and build wiring;
3. schema-governance and backlog tests updated to include the new schema and
   next handoff;
4. artifact-chain verification from capture fixtures through ready
   local-pipeline fixtures into ready and blocked NenDB retention artifacts;
5. full repo verification.

Verification suite:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_nendb_retention_fixtures.zig
zig build causal-production-telemetry-nendb-retention-fixtures -- \
  --from-local-pipeline ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures.json \
  approve \
  --reason "ready local pipeline fixtures reviewed for NenDB retention mapping" \
  --verified-command "zig build causal-production-telemetry-local-pipeline-fixtures" \
  --verified-command "zig build causal-nendb-storage-backend" \
  --verified-command "zig build causal-durable-production-retention -- --format json" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-production-telemetry-nendb-retention-fixtures -- \
  --from-local-pipeline ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures.json \
  reject \
  --reason "negative NenDB retention fixture path"
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

## Spec Self-Review

- Placeholder scan: no placeholder sections or open TODOs remain.
- Scope check: the branch is one fixture-only artifact and documentation pass;
  real NenDB writes, upstream package integration, workbench UI, live telemetry,
  and non-NenDB storage are explicitly excluded.
- Consistency check: schema, command, branch, recommendation, output suffix,
  source artifact type, and next branch all match throughout.
- Ambiguity check: `ready` permits only the next read-only workbench preview
  branch and does not grant durable write, compaction, backup, restore,
  production telemetry, CI gate, or mutation authority.
