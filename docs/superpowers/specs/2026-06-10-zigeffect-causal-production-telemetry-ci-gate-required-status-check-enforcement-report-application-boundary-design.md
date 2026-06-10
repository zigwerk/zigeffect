# Required Status Check Enforcement Report Application Boundary Design

## Context

`causal-production-telemetry-ci-gate-required-status-check-enforcement-report`
now emits local JSON/text reviewer artifacts from required-status-check
enforcement evaluator output. Those reports intentionally do not publish CI
artifacts, write GitHub step summaries, post pull-request comments, create
required status checks, mutate branch protection, or grant mutation authority.

This branch defines the next guarded boundary: agents and reviewers need a
deterministic artifact that records either planned report application intent or
externally reviewed application evidence. The tool still must not perform the
application itself. It can only record that a separate reviewed action happened,
with before/after evidence and verification commands.

## Goal

Add a record-only application-boundary tool that consumes enforcement report
artifacts and emits plan or record-applied artifacts for report publication and
required-status-check application evidence. The artifact should be useful to
agents, reviewers, and the production-hardening backlog without creating any
GitHub, CI, production telemetry, durable storage, NenDB, renderer, or mutation
authority.

## Non-Goals

- Do not create GitHub required status checks.
- Do not update branch protection.
- Do not mutate GitHub Actions workflows.
- Do not create check runs.
- Do not upload CI artifacts.
- Do not write GitHub step summaries or pull-request comments.
- Do not call GitHub APIs or networks.
- Do not ingest live telemetry.
- Do not write durable production storage or NenDB.
- Do not add non-NenDB durable adapter scope.
- Do not add React or alternate renderer scope.
- Do not claim production health, deployment success, customer impact, or
  production cluster readiness.
- Do not grant source, config, registry, CI, or production mutation authority.

## Recommended Approach

Use the existing
`causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary`
shape as the implementation template, with stricter required-status-check and
branch-protection semantics:

- parse `--from-report <required-status-check-enforcement-report.json>`;
- support `plan` and `record-applied`;
- emit deterministic JSON and text artifacts;
- compact default output paths when chained artifact names are long;
- require explicit before/after evidence and verification commands for
  `record-applied`;
- keep `applied=false` unless every source, evidence, safety, and verification
  check passes;
- preserve blocked report artifacts as blocked application-boundary artifacts
  rather than silently accepting them.

This mirrors the existing local causal governance chain and avoids inventing a
new application model.

## Source Report Contract

The source artifact must use schema:

`zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report.v1`

The source report is application-boundary eligible only when:

- `required_status_check_enforcement_report_status` is `ready` or `advisory`;
- `ready_for_next_branch=true`;
- `mutation_authority="none"`;
- all GitHub, CI, telemetry, durable, and NenDB authority booleans are false;
- publication channels are present;
- local JSON/text channels may be allowed and executed by the source report;
- external channels remain not allowed and not executed:
  `ci-upload-artifact`, `github-step-summary`, `pull-request-comment`,
  `required-status-check`, and `branch-protection-update`;
- source checks contain no failures;
- source blocked claims and required verification commands are present.

Blocked source reports still produce blocked application-boundary artifacts so
agents can explain the failure, but they must not set `applied=true`.

## Command Contract

Plan mode:

```sh
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary -- \
  --from-report ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report.json \
  plan \
  --reason "required status check enforcement report application boundary planned"
```

Record-applied mode:

```sh
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary -- \
  --from-report ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report.json \
  record-applied \
  --reason "required status check enforcement report application evidence recorded" \
  --report-after ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report.txt \
  --application-change "reviewed report publication or required-check application evidence" \
  --before "reviewed before evidence" \
  --after "reviewed after evidence" \
  --verified-command "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Shared options:

- `--by <actor>`
- `--policy <policy>`
- `--out-prefix <path-prefix>`

`--report-after` may point only to explicit local `.txt`, `.md`, or `.json`
files. It is required for `record-applied` and optional for `plan`.

## Output Schema

New schema:

`zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary.v1`

Core fields:

- `schema`, `schema_version`
- `source_enforcement_report`
- `source_report_status`
- `mode`
- `report_application_boundary_status`: `planned`, `applied`, or `blocked`
- `applied`
- `mutation_authority`
- disabled authority booleans
- `reviewed_by`, `policy`, `reason`
- `report_after_path`, `after_report_digest`, `after_report_present`
- `application_changes`
- `before_evidence`
- `after_evidence`
- `source_checks`
- `application_checks`
- `application_boundary_rules`
- `denied_application_claims`
- `negative_fixtures`
- `blocked_claims`
- `required_verification_commands`
- `verified_commands`
- `generated_by`
- `source_branch`
- `recommendation`
- `next_branch_if_applied`
- `json_output`, `text_output`
- `agent_guidance`

`mutation_authority` remains `none` for `plan` and blocked outputs. For
successful `record-applied`, it may be `record-only` to indicate evidence
interpretation authority only, not mutation authority.

## Application Checks

Source checks:

- `source-report-schema`
- `source-report-status`
- `source-application-disabled`
- `source-authority-disabled`
- `source-publication-channels-carried`
- `source-checks-passed`
- `source-blocked-claims-carried`
- `source-verification-recorded`

Plan-only checks:

- `plan-is-not-applied`
- `application-change-present` skipped
- `before-evidence-present` skipped
- `after-evidence-present` skipped
- `post-verification-recorded` skipped
- `after-report-present` skipped or pass when optional evidence is present
- `after-report-safe` skipped or pass when optional evidence is present

Record-applied checks:

- `application-change-present`
- `before-evidence-present`
- `after-evidence-present`
- `post-verification-recorded`
- `after-report-present`
- `after-report-safe`

All record-applied checks must pass before `applied=true`.

## Report-After Safety

The after-report content must contain markers showing it is the expected
zigeffect causal enforcement report:

- `zigeffect`
- `causal`
- `required status check`
- `enforcement`
- `report`

It is blocked when it contains markers that imply out-of-scope effects:

- `github_api_mutation_enabled=true`
- `branch_protection_mutation_by_tool_enabled=true`
- `ci_workflow_mutation_enabled=true`
- `github_check_run_creation_enabled=true`
- `ci_upload_execution_enabled=true`
- `github_step_summary_write_enabled=true`
- `pull_request_comment_enabled=true`
- `production_telemetry_ingestion=true`
- `network_send_enabled=true`
- `durable_write_enabled=true`
- `nendb_write_enabled=true`
- `mutation_authority=granted`
- `production_health_proven`
- `production_cluster_ready`
- `non-nendb-durable-adapter`
- `react-or-alternate-renderer`
- `secrets.`
- `GITHUB_TOKEN`
- `PRODUCTION_TELEMETRY_TOKEN`
- `OTEL_EXPORTER_OTLP_ENDPOINT`

## Negative Fixtures

The tool should render a negative fixture catalog covering:

- blocked source report denied;
- source application enabled denied;
- source authority enabled denied;
- plan applied claim denied;
- missing application change denied;
- missing before evidence denied;
- missing after evidence denied;
- missing after report denied;
- unsafe after report required-check mutation claim denied;
- unsafe after report branch-protection mutation claim denied;
- unsafe after report secret claim denied;
- missing verification command denied;
- production health claim denied;
- non-NenDB durable scope denied;
- alternate renderer scope denied.

## Handoff

Applied application-boundary artifacts hand off to:

`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy`

That future branch should define how agents may interpret externally reviewed
report application evidence before any workflow, branch protection, required
status check, or production authority work can cite it.

## Documentation And Registry Updates

This branch should:

- add the new tool to `packages/zigeffect/build.zig`;
- register the schema in `causal_schema_governance.zig`;
- move production hardening backlog recommendation to the future report policy
  branch;
- add a delivered backlog item;
- create
  `packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary.md`;
- update README, operations, production hardening backlog docs, schema
  governance docs, roadmap, and master roadmap.

## Verification

Focused verification:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary -- --help
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary -- \
  --from-report ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report.json \
  plan \
  --reason "required status check enforcement report application boundary planned"
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary -- \
  --from-report ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report-negative.json \
  record-applied \
  --reason "negative required status check enforcement report application boundary path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary-negative
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

Full verification:

```sh
cd packages/zigeffect
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
cd packages/zigeffect
zig fmt --check build.zig \
  tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary.zig \
  tools/causal_schema_governance.zig \
  tools/causal_production_hardening_backlog.zig
cd ../..
git diff --check
```
