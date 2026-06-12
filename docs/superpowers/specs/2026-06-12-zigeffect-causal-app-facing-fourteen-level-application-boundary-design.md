# zigeffect causal app-facing fourteen-level application boundary design

## Intent

Add the guarded application-boundary layer after the app-facing fourteen-level
report. This boundary records either planned intent or reviewed applied evidence
for local agents, reviewers, advisory CI readers, and the SolidJS webui. It must
not mutate applications, GitHub, CI workflows, storage, runtime integrations,
deployments, or adapters.

Local `master` is already fast-forwarded through the fourteen-level report. This
branch continues from that visible checkpoint and keeps the next layer small,
explicit, and locally auditable.

## Source contract

The source artifact is produced by:

- Build step: `causal-app-facing-fourteen-level-report`
- Generator: `causal-app-facing-fourteen-level-report`
- Schema:
  `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1`
- Ready source status:
  `consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status=ready`

The boundary accepts a source report only when:

- the schema and generator match the fourteen-level report contract;
- the report is ready or advisory, has `ready_for_next_branch=true`, has zero
  blocked findings, and has `mutation_authority=none`;
- all authority toggles remain disabled, including CI enforcement, GitHub API
  mutation, app mutation, app runtime integration, live agent projection, raw
  payload capture, deployment mutation, production telemetry ingestion, NenDB
  writes, NenDB adapter execution, public upload, hosted dashboard, and
  auto-apply;
- publication remains local-only, with local JSON/text artifacts written by the
  tool and SolidJS webui preview remaining read-only;
- source checks contain no failures;
- source evidence includes direct thirteen-level report, policy, application
  boundary, evaluator, twelve-level evaluator, and lower lineage carryover.

## Output contract

The new artifact is produced by:

- Build step: `causal-app-facing-fourteen-level-application-boundary`
- Generator: `causal-app-facing-fourteen-level-application-boundary`
- Schema:
  `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1`
- Current branch:
  `codex/zigeffect-causal-app-facing-fourteen-level-application-boundary`
- Recommended next branch:
  `codex/zigeffect-causal-app-facing-fourteen-level-policy`

The output must add `source_fourteen_level_report`,
`source_fourteen_level_report_schema`, and `source_fourteen_level_report_status`
while preserving direct `source_thirteen_level_*`, `source_twelve_level_*`,
`source_eleven_level_*`, `source_ten_level_*`, and `source_nine_level_*` fields.
This keeps the latest source leg obvious for agents without forcing them to
chase only generic source aliases.

## Modes

`plan` records local intent only:

- `applied=false`
- `ready_for_next_branch=false`
- `mutation_authority=none`
- evidence checks for actual application are skipped

`record-applied` records reviewed local evidence only:

- requires at least one application change;
- requires before and after evidence;
- requires safe after-report content;
- requires every required verification command;
- sets `applied=true`, `ready_for_next_branch=true`, and
  `mutation_authority=record-only` only when all gates pass.

The applied record is not authority to mutate apps, CI, GitHub, workflows,
storage, deployments, or the NenDB adapter. It is evidence for the next
fourteen-level policy branch.

## Out of scope

- No Cockroach work.
- No non-NenDB durable adapter scope.
- No NenDB writes or adapter execution in this boundary.
- No hosted dashboard or public artifact upload.
- No app runtime integration.
- No auto-apply behavior.
- No required status check or CI enforcement.

## Verification

The milestone is complete when these pass:

- `zig test tools/causal_app_facing_fourteen_level_application_boundary.zig`
- `zig build causal-app-facing-fourteen-level-application-boundary -- --help`
- `zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig`
- `zig test tools/causal_production_hardening_backlog.zig`
- `zig build causal-schema-governance -- --format json`
- `zig build causal-production-hardening-backlog -- --format json`
- `zig build examples`
- `zig build test`
- `bun run check`
- `bun run zig:test`
- `git diff --check`
