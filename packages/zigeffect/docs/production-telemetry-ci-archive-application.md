# Production Telemetry CI Archive Application

`causal-production-telemetry-ci-archive-application` consumes a ready
production telemetry CI harness boundary and emits a guarded application
artifact. It separates a reviewed archive application plan from a
`record-applied` artifact that can only say `applied=true` when workflow-change
evidence, before evidence, after evidence, and post-application verification
commands are all present.

It does not edit `.github/workflows/zigeffect-causal.yml`, run CI, upload
artifacts, enable telemetry gates, configure secrets, ingest live telemetry,
write NenDB, write durable production storage, orchestrate clusters, or grant
mutation authority.

## Plan Mode

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-archive-application -- \
  --from-harness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary.json \
  plan \
  --reason "CI archive application planned from reviewed harness boundary"
```

Plan mode emits `application_status=planned`, `applied=false`, and
`mutation_authority=none` when the source harness boundary is ready. It skips
workflow-change, before/after, and post-verification claims.

## Record-Applied Mode

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-archive-application -- \
  --from-harness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary.json \
  record-applied \
  --reason "reviewed archive workflow change applied" \
  --workflow-after ../../.github/workflows/zigeffect-causal.yml \
  --workflow-change ".github/workflows/zigeffect-causal.yml" \
  --before "source harness workflow digest" \
  --after "post-change workflow review" \
  --verified-command "zig build causal-production-telemetry-ci-harness-boundary" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

`record-applied` only passes when the source harness boundary is ready and the
caller records workflow changes, before evidence, after evidence, every
required verification command, and an after-workflow that still preserves the
bounded archive constraints.

## Source Evidence

The source artifact must use schema
`zigeffect.causal.production-telemetry-ci-harness-boundary.v1` and be `ready`.
The application carries forward:

- source CI artifact preview and workbench preview paths;
- source workflow path and digest;
- source workflow required/prohibited checks;
- source upload policy and artifact candidates;
- source cluster release-gate assumptions;
- blocked claims and verification evidence.

## Status

- `planned`: the source harness boundary is ready and the command is in plan
  mode. No application is claimed.
- `applied`: `record-applied` has source readiness, workflow-change evidence,
  before evidence, after evidence, safe after-workflow checks, and required
  verification commands.
- `blocked`: source evidence is blocked, record-applied evidence is missing,
  post-verification is incomplete, or the after-workflow contains prohibited
  features such as secrets, write permissions, schedules, OTLP endpoints,
  production telemetry tokens, deploy actions, or telemetry gates.

`applied=true` is record-only evidence that a separately reviewed workflow
change was applied. It does not mean this tool changed GitHub Actions or
executed artifact uploads.

## Agent Guidance

Agents may use `planned` artifacts to prepare a reviewed workflow/archive
patch. They may use `applied` artifacts to start
`codex/zigeffect-causal-production-telemetry-ci-archive-evidence-policy`.
Blocked artifacts are stop signs and cannot justify CI gates, live telemetry,
runtime ingestion, durable writes, NenDB writes, hosted dashboard readiness, or
mutation authority.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_archive_application.zig
zig build causal-production-telemetry-ci-archive-application -- --help
zig build causal-production-telemetry-ci-archive-application -- \
  --from-harness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary.json \
  plan \
  --reason "CI archive application planned from reviewed harness boundary"
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
```

