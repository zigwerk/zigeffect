# Production Telemetry CI Archive Evidence Policy

`causal-production-telemetry-ci-archive-evidence-policy` consumes a production
telemetry CI archive application artifact and emits a bounded interpretation
policy for archived CI evidence. It defines which archive evidence classes
agents and maintainers may read, which provenance metadata is required, which
claims are denied, and which negative fixtures must fail closed before any CI
gate readiness branch.

It does not edit `.github/workflows/zigeffect-causal.yml`, upload artifacts,
enable CI gates, configure secrets, ingest live telemetry, write NenDB, write
durable production storage, orchestrate clusters, or grant mutation authority.

## Command

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-archive-evidence-policy -- \
  --from-archive-application ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-archive-application.json \
  approve \
  --reason "CI archive evidence policy reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-archive-application" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Use `reject --reason <reason>` to produce a blocked policy. Use
`--out-prefix <path-prefix>` for negative-path artifacts when the ready default
artifact should remain available for the next branch.

## Source Evidence

The source artifact must use schema
`zigeffect.causal.production-telemetry-ci-archive-application.v1` and have
`application_status` of `planned` or `applied`. The policy carries forward:

- source archive application path and status;
- source CI harness boundary and workflow digest;
- source blocked claims;
- source checks and verification evidence;
- clustering release-gate assumptions;
- disabled authority flags.

A `planned` archive application is enough for policy design because this branch
defines how archived evidence may be interpreted. It does not require
`applied=true`, and it does not claim an archive workflow change has run.

## Evidence Classes

The policy allowlists these archive evidence classes:

- causal text report;
- causal JSON artifact;
- causal DOT graph;
- release-gate text report;
- release-gate JSON report;
- CI handoff text;
- source preview JSON.

Only `.txt`, `.json`, and `.dot` evidence is in scope. Each class records a
visibility class, consumer role, interpretation scope, and denied claim.

## Required Metadata

Archived CI evidence must carry these fields before an agent treats it as
usable evidence:

- `schema`
- `source_artifact_path`
- `workflow_digest`
- `run_context_ref`
- `commit_or_branch_ref`
- `redaction_state`
- `retention_days`
- `visibility_class`
- `consumer_role`
- `interpretation_scope`

Evidence without stable provenance, bounded retention, and an explicit
interpretation scope fails closed.

## Interpretation Rules

Archived CI evidence may support local diagnosis, failure triage, causal query
hints, before/after comparison, release-gate debugging, and workbench
visualization.

Archived CI evidence may not prove production health, production capacity,
live telemetry coverage, customer impact, deployment success, root-cause
certainty, complete runtime topology, or CI gate pass/fail semantics.

Any evidence with visible secret-shaped content fails closed until redaction
evidence is regenerated.

## Negative Fixtures

The policy records deny fixtures for:

- visible secret-shaped content;
- missing source artifact paths;
- retention over fourteen days;
- public upload claims;
- telemetry gate claims;
- production health claims;
- non-NenDB durable adapter scope;
- React or alternate renderer scope.

These fixtures protect the current project constraints: durable production
storage remains NenDB adapter work only, and the workbench direction remains
SolidJS inside `webui-dev/zig-webui`.

## Status

- `ready`: the source archive application is schema v1, planned or applied,
  has no failing checks, preserves disabled execution authority, carries
  blocked claims, the reviewer approved, every required verification command is
  recorded, and the evidence class, metadata, and negative-fixture catalogs are
  valid.
- `blocked`: the reviewer rejected, source archive application evidence is
  blocked or malformed, authority is enabled, source blocked claims are
  missing, verification command evidence is incomplete, or policy catalogs are
  incomplete.

`ready_for_next_branch=true` means
`codex/zigeffect-causal-production-telemetry-ci-gate-readiness` may be
started. It does not approve CI gates, artifact upload execution, workflow
mutation, live telemetry, runtime pipelines, NenDB writes, durable writes,
hosted dashboards, production cluster claims, or mutation authority.

## Output Paths

For this input:

```text
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-archive-application.json
```

default output paths are:

```text
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-archive-evidence-policy.json
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-archive-evidence-policy.txt
```

## Agent Guidance

Agents may use a `ready` archive evidence policy to start CI gate readiness
design. They must cite the source archive application, source workflow digest,
evidence class catalog, required metadata, interpretation rules, negative
fixtures, blocked claims, required commands, and recorded commands.

Agents must treat `blocked` archive evidence policies as stop signs. Blocked
artifacts can guide source application or policy repair, but they cannot
justify CI gates, live telemetry, durable writes, hosted dashboard claims,
production cluster claims, or mutation authority.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_archive_evidence_policy.zig
zig build causal-production-telemetry-ci-archive-evidence-policy -- --help
zig build causal-production-telemetry-ci-archive-evidence-policy -- \
  --from-archive-application ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-archive-application.json \
  approve \
  --reason "CI archive evidence policy reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-archive-application" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-production-telemetry-ci-archive-evidence-policy -- \
  --from-archive-application ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-archive-application.json \
  reject \
  --reason "negative CI archive evidence policy path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-archive-evidence-policy-negative
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
