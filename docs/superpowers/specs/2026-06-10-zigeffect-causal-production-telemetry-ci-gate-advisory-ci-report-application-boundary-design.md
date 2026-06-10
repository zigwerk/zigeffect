# zigeffect Causal Production Telemetry CI Gate Advisory CI Report Application Boundary Design

## Summary

Create `causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary`,
a guarded, record-only boundary tool that consumes
`zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report.v1`
artifacts and records whether advisory CI report publication is only planned,
has been externally reviewed and applied, or is blocked.

This branch does not mutate GitHub Actions workflows, upload CI artifacts,
write GitHub step summaries, post pull request comments, create required
status checks, enable CI gate enforcement, ingest live telemetry, call
networks, configure collector endpoints, serialize OTLP, write durable
production storage, write NenDB, make production health or cluster-readiness
claims, add non-NenDB durable adapter scope, add alternate renderer scope, or
grant production mutation authority.

## Goals

- Consume ready or advisory
  `zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report.v1`
  artifacts.
- Preserve blocked source reports as blocked application-boundary artifacts.
- Emit deterministic JSON and text artifacts with `mode`, `report_application_status`,
  `applied`, `mutation_authority`, source checks, application checks,
  publication evidence, before/after evidence, after-report digest, denied
  publication claims, negative fixtures, required verification commands, and
  next-branch guidance.
- Support a `plan` mode that records reviewed application intent only and
  always emits `applied=false`.
- Support a `record-applied` mode that emits `applied=true` only after all
  source, publication evidence, before evidence, after evidence, after-report
  content, report safety, and post-application verification checks pass.
- Hand off only applied records to the next production-hardening branch.

## Non-Goals

- No workflow mutation by the tool.
- No GitHub step-summary writing by the tool.
- No pull request comments by the tool.
- No CI artifact upload execution by the tool.
- No required status checks or branch protection changes.
- No CI gate enforcement.
- No live telemetry, runtime pipeline execution, network send, collector
  configuration, or OTLP serialization.
- No durable writes and no NenDB writes.
- No production health, deployment success, capacity, customer impact, or
  production cluster readiness claims.
- No Cockroach, non-NenDB durable adapter, React, or alternate frontend
  renderer work.
- No mutation authority beyond a record-only evidence statement when
  `record-applied` passes every gate.

## CLI

```sh
zig build causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary -- \
  --from-report <advisory-ci-report.json> \
  plan|record-applied \
  --reason <reason>
```

Optional flags:

- `--by <actor>`: reviewer or agent id. Defaults to
  `ci-gate-advisory-ci-report-application-boundary-reviewer`.
- `--policy <policy>`: policy id. Defaults to
  `manual-production-telemetry-ci-gate-advisory-ci-report-application-boundary`.
- `--report-after <path>`: local `.txt`, `.md`, or `.json` report content
  after an external reviewed publication/update.
- `--publication-change <evidence>`: reviewed publication change evidence.
- `--before <evidence>`: before evidence.
- `--after <evidence>`: after evidence.
- `--verified-command <command>`: post-application verification evidence.
- `--out-prefix <path-prefix>`: override output paths.

Default output path replacement:

- `*-ci-gate-advisory-ci-report.json` becomes
  `*-ci-gate-advisory-ci-report-application-boundary.json`.
- Text output uses the same prefix with `.txt`.

## Source Report Contract

The source report is application-boundary-ready when:

- `schema` is
  `zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report.v1`.
- `schema_version` is `1`.
- `report_status` is `ready` or `advisory`.
- `ready_for_next_branch=true`.
- `ci_gate_enabled=false`.
- `ci_gate_enforcement_enabled=false`.
- `ci_required_status_check_enabled=false`.
- `ci_workflow_mutation_enabled=false`.
- `ci_upload_execution_enabled=false`.
- `ci_report_publication_enabled=false`.
- `github_step_summary_write_enabled=false`.
- `pull_request_comment_enabled=false`.
- `production_telemetry_ingestion=false`.
- `live_exporter_enabled=false`.
- `network_send_enabled=false`.
- `collector_endpoint_configured=false`.
- `otlp_serialization_enabled=false`.
- `runtime_pipeline_enabled=false`.
- `durable_write_enabled=false`.
- `nendb_write_enabled=false`.
- `publication_channels` is present and external publication channels are not
  executed by the source tool.
- `checks`, `blocked_claims`, `required_verification_commands`, and
  `agent_guidance` are present.
- Source checks have no `fail` statuses.

Blocked or invalid source reports produce `report_application_status="blocked"`
and `applied=false`.

## Modes

### Plan

`plan` records a reviewed publication boundary proposal. It may include
optional `--report-after` evidence for preview safety checks, but it never
records applied state.

Output:

- `report_application_status="planned"` when source checks pass.
- `applied=false`.
- `mutation_authority="none"`.
- publication, before, after, and post-verification checks are skipped unless
  optional evidence is present.

### Record Applied

`record-applied` records that an external reviewed publication/update has
already happened. The tool does not do that work itself.

It requires:

- valid source report
- at least one `--publication-change`
- at least one `--before`
- at least one `--after`
- `--report-after <path>` with safe local report content
- every required post-application verification command

Output:

- `report_application_status="applied"` only if every check is `pass`.
- `applied=true`.
- `mutation_authority="record-only"`.

If any check fails, output is blocked with `applied=false` and
`mutation_authority="none"`.

## Report Safety

The optional or required `--report-after` file must be local and bounded. The
tool reads only explicit files ending in `.txt`, `.md`, or `.json`.

Required report-after content markers:

- `zigeffect`
- `causal`
- `advisory`
- `report`

Prohibited report-after content markers:

- `required_status_check`
- `ci_gate_enabled=true`
- `ci_gate_enforcement_enabled=true`
- `ci_report_publication_enabled=true`
- `github_step_summary_write_enabled=true`
- `pull_request_comment_enabled=true`
- `ci_upload_execution_enabled=true`
- `production_telemetry_ingestion=true`
- `network_send_enabled=true`
- `durable_write_enabled=true`
- `nendb_write_enabled=true`
- `production_cluster_ready`
- `production_health_proven`
- `mutation_authority=granted`
- `secrets.`
- `PRODUCTION_TELEMETRY_TOKEN`
- `OTEL_EXPORTER_OTLP_ENDPOINT`

## Application Checks

The boundary emits these checks:

- `source-report-schema`: source schema and version are supported.
- `source-report-status`: source status is `ready` or `advisory` and ready for
  next branch.
- `source-publication-disabled`: source report did not publish externally.
- `source-authority-disabled`: all enforcement, workflow mutation, upload,
  live telemetry, network, runtime, durable, and NenDB flags are false.
- `source-publication-channels-carried`: publication channel data is present.
- `source-checks-passed`: source checks have no `fail` status.
- `source-blocked-claims-carried`: blocked claims are present.
- `source-verification-recorded`: source required verification commands are
  present.
- `plan-is-not-applied`: plan mode is never applied.
- `publication-change-present`: record-applied has reviewed publication
  evidence.
- `before-evidence-present`: record-applied has before evidence.
- `after-evidence-present`: record-applied has after evidence.
- `post-verification-recorded`: record-applied includes all required
  verification commands.
- `after-report-present`: record-applied has report-after content.
- `after-report-safe`: report-after content has required markers and no
  prohibited markers.

## Denied Claims And Negative Fixtures

The artifact carries denied claims for:

- CI gate enforcement
- required status checks
- workflow mutation by the tool
- CI upload execution by the tool
- GitHub step summary writes by the tool
- pull request comments by the tool
- live telemetry ingestion
- runtime pipeline execution
- durable production writes
- NenDB writes
- production health proof
- production cluster readiness
- non-NenDB durable adapters
- alternate renderers
- mutation authority grants

Negative fixtures cover blocked source reports, missing publication evidence,
missing before evidence, missing after evidence, missing report-after content,
unsafe report-after content, missing verification commands, enabled source
authority, external publication already enabled by the source tool, production
health claims, non-NenDB durable scope, and alternate renderer scope.

## Handoff

Applied report application-boundary artifacts hand off to the next branch:

`codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy`

That branch should define the interpretation policy for externally published
advisory CI reports before any CI gate enforcement or required status check
work is considered. Planned and blocked artifacts do not hand off as applied
evidence.

## Tests

Focused Zig tests must cover:

- schema and branch constants
- CLI parsing for `plan` and `record-applied`
- default output path replacement
- planned boundary from a ready/advisory source report
- blocked boundary from a blocked source report
- blocked boundary when source authority or publication flags are enabled
- blocked `record-applied` when publication/before/after/report-after or
  verification evidence is missing
- applied `record-applied` when every source and evidence check passes
- unsafe report-after content is blocked

Build-level verification must include:

- `zig test tools/causal_production_telemetry_ci_gate_advisory_ci_report_application_boundary.zig`
- `zig build causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary -- --help`
- planned artifact generation
- blocked negative artifact generation
- applied fixture generation with explicit local report-after evidence
- `zig build causal-schema-governance -- --format json`
- `zig build causal-production-hardening-backlog -- --format json`
- `zig build examples`
- `zig build test`
- `bun run check`
- `bun run zig:test`
- `git diff --check`
