# Production Telemetry CI Gate Required Status Check Enforcement Report Design

## Status

Approved for implementation as the next sequential zigeffect causal
self-improvement roadmap milestone.

## Branch

`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report`

## Background

The required-status-check enforcement evaluator now consumes enforcement policy
artifacts plus explicit bounded evidence files and emits ready, advisory, or
blocked evaluator artifacts. The current available evaluator artifacts are
useful even when blocked: they preserve source-policy readiness failures,
active-enforcement overclaim observations, merge-blocking overclaim
observations, denied claims, and next-branch guidance.

Agents and reviewers need a local report artifact that summarizes evaluator
findings without converting them into CI enforcement, GitHub mutation,
branch-protection mutation, workflow mutation, live telemetry, durable writes,
NenDB writes, production health, deployment success, customer impact, cluster
readiness, or mutation authority.

## Goals

- Add
  `causal-production-telemetry-ci-gate-required-status-check-enforcement-report`.
- Consume
  `zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-evaluator.v1`.
- Emit
  `zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report.v1`.
- Accept one explicit `--from-evaluator <json>` source artifact and a
  `summarize` command.
- Render local JSON and text reports for reviewers and agents.
- Preserve ready, advisory, and blocked evaluator states without losing source
  evidence paths or finding severity.
- Summarize source evaluator checks, signals, blocked findings, advisory
  findings, evidence files, blocked claims, and report sections.
- Record a publication boundary catalog where only local JSON/text artifacts
  are allowed and executed by the tool.
- Hand off ready or advisory report artifacts to a future enforcement report
  application-boundary branch.
- Keep blocked report artifacts useful as stop-sign evidence while setting
  `ready_for_next_branch=false`.

## Non-Goals

- No GitHub API calls.
- No branch-protection mutation.
- No workflow mutation.
- No check-run creation.
- No CI artifact upload execution.
- No GitHub step-summary writes.
- No pull-request comments.
- No live telemetry ingestion.
- No network sends or collector configuration.
- No OTLP serialization.
- No runtime pipeline enablement.
- No durable production writes.
- No NenDB writes.
- No non-NenDB durable adapter work.
- No alternate renderer support.
- No production health, deployment success, customer impact, capacity, or
  cluster-readiness proof.
- No mutation authority.
- No conversion of advisory or blocked evaluator findings into required checks.

## Command

Positive path:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report -- \
  --from-evaluator ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-evaluator.json \
  summarize \
  --reason "required status check enforcement report reviewed"
```

Negative path:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report -- \
  --from-evaluator ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-evaluator-negative.json \
  summarize \
  --reason "negative required status check enforcement report path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report-negative
```

## CLI Contract

Required positional shape:

```sh
--from-evaluator <required-status-check-enforcement-evaluator.json> summarize --reason <reason>
```

Supported optional flags:

- `--by <actor>`
- `--policy <policy>`
- `--out-prefix <path-prefix>`
- `--help`

Stable option errors:

- `error.MissingEvaluatorPath`
- `error.InvalidEvaluatorPath`
- `error.MissingCommand`
- `error.UnknownCommand`
- `error.MissingReason`
- `error.MissingFlagValue`
- `error.UnknownFlag`
- `error.UnknownArgument`

## Output Paths

Default path derivation:

- `foo-ci-gate-required-status-check-enforcement-evaluator.json` becomes
  `foo-ci-gate-required-status-check-enforcement-report.json`.
- `foo.json` becomes
  `foo-ci-gate-required-status-check-enforcement-report.json`.
- `--out-prefix x` emits `x.json` and `x.txt`.

## Source Evaluator Contract

The source evaluator artifact must:

- use schema
  `zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-evaluator.v1`;
- use schema version `1`;
- include `required_status_check_enforcement_evaluator_status`;
- include `ready_for_next_branch`;
- include blocked and advisory finding counts;
- keep `mutation_authority="none"`;
- keep all GitHub, workflow, check-run, CI upload, summary, comment, live
  telemetry, runtime, durable, and NenDB authority fields disabled;
- include evidence files, checks, signal evaluations, findings, blocked claims,
  and required verification commands.

`ready` and `advisory-findings` evaluator statuses can produce report artifacts
with `ready_for_next_branch=true`. `blocked` evaluator status must produce a
blocked report with `ready_for_next_branch=false`, but the report should still
summarize blocked findings and evidence for reviewers.

## Report Semantics

The report emits `required_status_check_enforcement_report_status`:

- `ready`: the source evaluator is ready, has no blocked or advisory findings,
  source authority is disabled, required sections are present, and publication
  channels remain record-only.
- `advisory`: the source evaluator is advisory or contains advisory findings,
  has no blocked findings, source authority is disabled, required sections are
  present, and publication channels remain record-only.
- `blocked`: the source evaluator is blocked, invalid, missing required
  sections, contains blocked findings, or violates disabled-authority or
  publication boundaries.

The report must not hide blocked findings. It should surface them in a
dedicated `blocked_findings` section and guidance list so agents can stop or
repair source evidence instead of treating the report as a positive gate.

## Publication Boundary

The tool only writes local JSON and text artifacts. Publication channels:

- `local-json-artifact`: allowed and executed by this tool.
- `local-text-artifact`: allowed and executed by this tool.
- `ci-upload-artifact`: not allowed and not executed.
- `github-step-summary`: not allowed and not executed.
- `pull-request-comment`: not allowed and not executed.
- `required-status-check`: not allowed and not executed.
- `branch-protection-update`: not allowed and not executed.

## Output Fields

Required top-level JSON fields:

- `schema`
- `schema_version`
- `source_evaluator`
- `source_evaluator_status`
- `source_ready_for_next_branch`
- `required_status_check_enforcement_report_status`
- `ready_for_next_branch`
- `blocked_findings_count`
- `advisory_findings_count`
- all disabled authority booleans
- `mutation_authority`
- `reviewed_by`
- `policy`
- `reason`
- `headline`
- `report_sections`
- `evidence_summary`
- `signal_summary`
- `blocked_findings`
- `advisory_findings`
- `checks`
- `blocked_claims`
- `publication_channels`
- `required_verification_commands`
- `generated_by`
- `source_branch`
- `recommendation`
- `next_branch_if_ready`
- `json_output`
- `text_output`
- `agent_guidance`

## Handoff

Ready or advisory report artifacts hand off to:

`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary`

Blocked report artifacts do not hand off. They remain evidence for repairing
source evaluator or policy readiness.

## Files

- Create
  `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report.zig`.
- Modify `packages/zigeffect/build.zig`.
- Modify `packages/zigeffect/tools/causal_schema_governance.zig`.
- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`.
- Create
  `packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-enforcement-report.md`.
- Modify `packages/zigeffect/README.md`.
- Modify `packages/zigeffect/docs/operations.md`.
- Modify `packages/zigeffect/docs/production-hardening-backlog.md`.
- Modify `packages/zigeffect/docs/schema-governance.md`.
- Modify `packages/zigeffect/docs/roadmap.md`.
- Modify
  `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`.

## Testing

Focused verification:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report -- --help
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report -- \
  --from-evaluator ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-evaluator.json \
  summarize \
  --reason "required status check enforcement report reviewed"
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report -- \
  --from-evaluator ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-evaluator-negative.json \
  summarize \
  --reason "negative required status check enforcement report path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report-negative
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
  tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report.zig \
  tools/causal_schema_governance.zig \
  tools/causal_production_hardening_backlog.zig
cd ../..
git diff --check
```

## Acceptance Criteria

- The report tool parses CLI arguments and rejects invalid evaluator paths,
  unknown commands, missing reasons, and unknown flags.
- The report tool validates source schema and version.
- The report tool distinguishes ready, advisory, and blocked evaluator states.
- Blocked evaluator artifacts produce blocked report artifacts while preserving
  source findings and evidence summaries.
- Ready/advisory source artifacts can hand off to the report application
  boundary.
- Publication channels remain local-only and record-only.
- Schema governance includes the new report schema.
- Production hardening backlog marks the report milestone delivered and
  recommends the report application-boundary branch.
- Documentation surfaces the report command, output contract, and authority
  boundaries.
