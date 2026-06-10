# Production Telemetry CI Harness Boundary

`causal-production-telemetry-ci-harness-boundary` consumes a ready production
telemetry CI artifact preview, inspects the existing causal GitHub Actions
workflow, records clustering release-gate assumptions, and emits a record-only
CI harness boundary artifact.

It does not modify `.github/workflows/zigeffect-causal.yml`, upload artifacts,
enable CI gates, configure secrets, ingest live telemetry, write NenDB, write
durable production storage, orchestrate production clusters, or grant mutation
authority.

## Command

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-harness-boundary -- \
  --from-ci-preview ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview.json \
  --workflow ../../.github/workflows/zigeffect-causal.yml \
  approve \
  --reason "CI harness boundary reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-artifact-preview" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Use `reject --reason <reason>` to produce a blocked boundary. Use
`--out-prefix <path-prefix>` for negative-path artifacts when the ready default
artifact should remain available for the next branch.

## Source Evidence

The source artifact must use schema
`zigeffect.causal.production-telemetry-ci-artifact-preview.v1` and be `ready`.
The boundary carries forward:

- source workbench preview path;
- source NenDB retention fixture path;
- source local pipeline, exporter boundary, proposal, readiness, and capture
  fixture paths;
- preview-only upload policy;
- failure-only artifact candidates;
- source checks and verification commands;
- blocked claims.

## Workflow Checks

The workflow inspection checks the current
`.github/workflows/zigeffect-causal.yml` text for required features:

- pull request, push-to-`master`, and manual dispatch triggers;
- `permissions: contents: read`;
- `actions/checkout@v4`;
- `mlugg/setup-zig@v2.2.1` with Zig `0.16.0`;
- PR baseline capture using `zig build causal-test` and
  `zig build causal-dev-loop -- baseline package-tests`;
- causal artifact manifest printing with `zig build causal-artifacts`;
- durable workflow and cluster release gate with
  `zig build release-gate --summary none`;
- failure handoff with `zig build causal-ci-handoff`;
- failure-only artifact upload with `actions/upload-artifact@v4`;
- `if-no-files-found: ignore`;
- `retention-days: 14`;
- causal artifact `.txt`, `.json`, and `.dot` globs;
- release-gate `.txt` and `.json` globs.

It also checks prohibited workflow features are absent:

- GitHub secrets usage;
- write-all, contents-write, or id-token-write permissions;
- scheduled production polling;
- OTLP collector endpoint configuration;
- production telemetry token configuration;
- deployment actions;
- production telemetry gate enforcement.

## Clustering Assumptions

The report records that `zig build release-gate --summary none` is the
clustering-aware CI execution body. That release gate depends on the main test
step, public API review, storage conformance, property crash testing,
performance bounds, examples, `causal-test`, causal artifact generation, and
release-gate reports. The examples include multi-runner cluster and cluster
workflow migration tests.

The boundary does not start cluster daemons, provision infrastructure, run
production shards, or claim production cluster readiness.

## Status

- `ready`: the source CI artifact preview is schema v1, ready, approved,
  next-branch-ready, authority-disabled, preview-only, failure-only, and
  verified; the workflow has every required feature; the workflow lacks every
  prohibited feature; and every required harness-boundary verification command
  is recorded.
- `blocked`: the reviewer rejected, source preview evidence is blocked, the
  workflow is missing a required feature, the workflow includes a prohibited
  feature, authority is enabled, artifact candidates violate policy, or
  required verification command evidence is missing.

`ready_for_next_branch=true` means
`codex/zigeffect-causal-production-telemetry-ci-archive-application` may be
started. It does not approve workflow mutation, artifact upload execution, CI
gates, live telemetry, runtime pipelines, NenDB writes, durable writes, hosted
dashboards, production cluster claims, or mutation authority.

## Output Paths

For this input:

```text
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview.json
```

default output paths are:

```text
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary.json
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary.txt
```

## Agent Guidance

Agents may use a `ready` CI harness boundary to start
`codex/zigeffect-causal-production-telemetry-ci-archive-application` and run
`causal-production-telemetry-ci-archive-application` in `plan` mode. They must
cite the source CI artifact preview, workflow path and digest, workflow
required/prohibited checks, upload policy preview, clustering release-gate
assumptions, authority boundary, required commands, recorded commands, and
blocked claims.

Plan mode does not prove a workflow/archive change was applied.
`record-applied` requires workflow-change evidence, before evidence, after
evidence, safe after-workflow checks, and post-application verification
commands before `applied=true`.

Agents must treat `blocked` CI harness boundaries as stop signs. Blocked
artifacts can guide source preview or workflow-boundary repair, but they cannot
justify CI upload configuration, CI gate work, workflow mutation, live
telemetry, durable writes, hosted dashboard claims, production cluster claims,
or mutation authority.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_harness_boundary.zig
zig build causal-production-telemetry-ci-harness-boundary -- \
  --from-ci-preview ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview.json \
  --workflow ../../.github/workflows/zigeffect-causal.yml \
  approve \
  --reason "CI harness boundary reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-artifact-preview" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-production-telemetry-ci-harness-boundary -- \
  --from-ci-preview ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview.json \
  --workflow ../../.github/workflows/zigeffect-causal.yml \
  reject \
  --reason "negative CI harness boundary path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-harness-boundary-negative
zig build causal-production-telemetry-ci-archive-application -- \
  --from-harness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary.json \
  plan \
  --reason "CI archive application planned from reviewed harness boundary"
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
```
