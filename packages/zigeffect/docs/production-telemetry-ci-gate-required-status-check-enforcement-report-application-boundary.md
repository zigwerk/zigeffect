# Production Telemetry CI Gate Required Status Check Enforcement Report Application Boundary

Schema:
`zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary.v1`

`causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary`
consumes a required-status-check enforcement report artifact and emits a
guarded, record-only application-boundary artifact. It can record either a
planned application boundary or externally reviewed applied evidence.

It does not create GitHub required checks, update branch protection, mutate
workflows, create check runs, call GitHub APIs, upload CI artifacts, write
GitHub step summaries, post pull-request comments, ingest live telemetry, call
networks, write NenDB, write durable production storage, claim production
health, claim deployment success, claim cluster readiness, or grant mutation
authority.

## Command

Plan the boundary from an enforcement report artifact:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary -- \
  --from-report ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report.json \
  plan \
  --reason "required status check enforcement report application boundary planned"
```

Use `record-applied` only when a separately reviewed report publication,
required-check, or branch-protection application record exists and bounded
evidence has been collected:

```sh
cd packages/zigeffect
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

Use `--out-prefix <path-prefix>` to choose an explicit artifact prefix. Without
`--out-prefix`, the tool writes sibling `.json` and `.txt` artifacts beside the
source report. Deeply chained source artifact names are compacted to a
deterministic filesystem-safe prefix with a short source-path digest.

## Modes

- `plan`: emits `report_application_boundary_status="planned"`,
  `applied=false`, and `mutation_authority="none"` when the source report is
  ready or advisory and all source boundary checks pass.
- `record-applied`: emits `report_application_boundary_status="applied"` and
  `applied=true` only when source checks, application-change evidence,
  before/after evidence, report-after safety, and verification evidence all
  pass. Otherwise it emits `blocked` and keeps `applied=false`.

Applied records are evidence records only. This command never publishes a
report, creates a required status check, mutates branch protection, or mutates
CI.

## Source Report

The source artifact must use schema
`zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report.v1`,
have `required_status_check_enforcement_report_status="ready"` or
`"advisory"`, and set `ready_for_next_branch=true`.

The source must preserve disabled authority:

- `ci_gate_enabled=false`
- `ci_gate_enforcement_enabled=false`
- `ci_required_status_check_enabled=false`
- `ci_workflow_mutation_enabled=false`
- `ci_upload_execution_enabled=false`
- `ci_report_publication_enabled=false`
- `github_api_mutation_enabled=false`
- `github_check_run_creation_enabled=false`
- `branch_protection_mutation_by_tool_enabled=false`
- `github_step_summary_write_enabled=false`
- `pull_request_comment_enabled=false`
- `production_telemetry_ingestion=false`
- `network_send_enabled=false`
- `runtime_pipeline_enabled=false`
- `durable_write_enabled=false`
- `nendb_write_enabled=false`
- `mutation_authority=none`

Source publication/application channels must be present. Local JSON/text
channels may be allowed and executed by the source report tool. External
channels such as CI upload, GitHub step summary, pull-request comment,
required status check, and branch protection update must remain not allowed and
not executed by the source report tool.

## Record-Applied Evidence

`record-applied` requires:

- at least one `--application-change`;
- at least one `--before`;
- at least one `--after`;
- `--report-after` local content;
- every required `--verified-command`.

Evidence may describe externally reviewed publication state, required-check
state, branch-protection state, or reviewer-visible report output. Evidence may
not contain credentials, tokens, network claims, live telemetry ingestion,
production writes, NenDB writes, non-NenDB durable adapter claims, production
health, deployment success, customer impact, cluster readiness, or alternate
renderer claims.

## Report-After Safety

`--report-after` may point only to explicit local `.txt`, `.md`, or `.json`
files. The file must contain `zigeffect`, `causal`, `required status check`,
`enforcement`, and `report`.

It is blocked when it contains markers for GitHub API mutation, branch
protection mutation, workflow mutation, check-run creation, CI upload
execution, GitHub step summary writes, pull-request comments, live telemetry,
network sends, durable writes, NenDB writes, production health, production
cluster readiness, mutation authority grants, secrets, GitHub tokens,
production telemetry tokens, or OTLP endpoints.

## Denied Inferences

Applied report application evidence is not GitHub API mutation by this tool,
branch-protection mutation by this tool, workflow mutation by this tool,
check-run creation by this tool, required status check creation by this tool,
CI upload execution by this tool, GitHub step-summary or pull-request comment
writes by this tool, production health proof, deployment success proof,
customer impact proof, production cluster readiness proof, live telemetry
coverage proof, durable writes, NenDB writes, or mutation authority.

## Handoff

Applied report application-boundary artifacts hand off to:

`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy`

That branch should define how agents may interpret externally reviewed report
application evidence before any workflow, branch protection, required status
check, or production authority work can cite it.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary.zig
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
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
