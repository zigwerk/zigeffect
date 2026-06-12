# zigeffect Causal App-Facing Twelve-Level Application Boundary Design

## Context

The prior milestone delivered `causal-app-facing-twelve-level-report` and handed
off to `codex/zigeffect-causal-app-facing-twelve-level-application-boundary`.
That report consumes eleven-level evaluator evidence and emits:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1
```

This milestone adds the guarded application boundary for that report. It
consumes ready or advisory twelve-level report artifacts and emits local
evidence that a reviewed boundary step is planned, applied, or blocked. The
shape follows the established app-facing rhythm: report, application boundary,
policy, evaluator, next report. `plan` records intent only. `record-applied`
requires reviewed application-change evidence, before evidence, after evidence,
safe after-report content, and complete verification command evidence.

## Physical Naming Constraint

The artifact schema remains fully expanded and authoritative. Physical files,
build steps, generated artifact prefixes, docs, fixtures, and branches use short
aliases because expanded names are not ergonomic for filesystems, shells,
branch tools, or agent context.

- Tool file: `packages/zigeffect/tools/causal_app_facing_twelve_level_application_boundary.zig`
- Build step: `causal-app-facing-twelve-level-application-boundary`
- Executable: `zigeffect-causal-app-facing-twelve-level-application-boundary`
- Docs: `packages/zigeffect/docs/app-facing-twelve-level-application-boundary.md`
- Fixture: `packages/zigeffect/test/fixtures/app-facing-twelve-level-application-boundary-after-safe.txt`
- Current branch: `codex/zigeffect-causal-app-facing-twelve-level-application-boundary`
- Next branch if applied: `codex/zigeffect-causal-app-facing-twelve-level-policy`
- Recommendation: `start-app-facing-twelve-level-policy`

## Artifact Contract

The boundary emits:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1
```

The source report schema is:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1
```

The emitted JSON and text reports must include:

- source twelve-level report path, schema, status, and readiness
- direct source eleven-level policy, application-boundary, and report lineage
- direct source ten-level policy, application-boundary, and report lineage
- inherited source nine-level and lower-level lineage
- source evaluator, request, support, signal, finding, denied-claim, and
  next-query summaries
- boundary mode: `plan` or `record-applied`
- application status: `planned`, `applied`, or `blocked`
- `applied=false` in plan mode
- `ready_for_next_branch=false` in plan mode
- `applied=true` only in record-applied mode after every hard gate passes
- source and boundary checks
- required and observed verification commands
- local JSON and text output paths
- next branch alias for the twelve-level policy milestone

The source report status field consumed by this boundary is:

```text
consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status
```

The application output fields use the twelve-segment application prefix:

```text
evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status
evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_path
evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest
evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_present
evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes
```

## Boundary Gates

The source report gate passes only when:

- source schema equals the twelve-level report schema and schema version is `1`
- source report was generated by `causal-app-facing-twelve-level-report`
- source report status is `ready` or `advisory`
- source `ready_for_next_branch` is true
- source blocked finding count is zero
- source mutation authority is `none`
- direct source eleven-level policy, application-boundary, and report refs are
  present and ready
- direct source ten-level policy, application-boundary, and report refs are
  present and ready
- inherited source nine-level policy, application-boundary, and report refs are
  present and ready
- source checks do not contain failures
- source publication channels remain local-only and non-mutating
- source SolidJS `webui-dev/zig-webui` read-only posture is preserved
- source verification commands include workbench, schema governance, production
  backlog, examples, and zigeffect test checks

Plan mode adds no application authority. It records local intent only and skips
before and after evidence requirements.

Record-applied mode requires:

- at least one reviewed application-change evidence item
- at least one before evidence item
- at least one after evidence item
- safe after-report content
- every required verification command
- every source and boundary gate passing

## Non-Authority

The boundary must not enable or imply:

- CI enforcement or required status checks
- workflow mutation
- GitHub API mutation
- step summary or pull request comment writes
- app mutation, app config writes, app data writes, or app runtime integration
- raw prompt, raw response, or raw payload capture
- live agent projection
- deployment mutation
- production health proof
- durable writes
- NenDB writes or adapter execution
- Cockroach or non-NenDB durable adapter scope
- public artifact upload
- hosted dashboards
- auto-apply
- registry mutation
- mutation authority
- alternate frontend renderer work

## Backlog And Governance Updates

Schema governance must register the new schema as `current`, with
`emitted_by = causal-app-facing-twelve-level-application-boundary`, consumed by
agents, reviewers, non-blocking CI advisory readers, the local SolidJS workbench,
the production-hardening backlog, and the future twelve-level policy branch.

The production hardening backlog must mark
`app-facing-twelve-level-application-boundary` as delivered, update the
recommendation to `start-app-facing-twelve-level-policy`, and point the
recommended next branch to `codex/zigeffect-causal-app-facing-twelve-level-policy`.

The master roadmap must mark the current branch delivered and add the
twelve-level policy branch as the next milestone.

## Tests

TDD coverage must prove:

- constants expose the full output schema and short alias branch names
- option parsing accepts the alias build step and promoted after/change flags
- default output prefix replaces twelve-level report suffix and compacts long
  paths
- plan mode emits planned state without applied authority
- plan mode carries direct twelve-level source report evidence, eleven-level
  lineage, ten-level lineage, and inherited nine-level lineage
- record-applied blocks without reviewed evidence
- record-applied applies only with reviewed change, before, after, safe report,
  and all verification commands
- unsafe after-report content blocks application
- blocked source report blocks application
- source authority drift blocks application
- emitted JSON is parseable
- schema governance count and schema entry include the new artifact
- production backlog text and JSON include the delivered item and next policy
  handoff

## Verification

The milestone is not complete until these commands exit 0:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_twelve_level_application_boundary.zig
zig build causal-app-facing-twelve-level-application-boundary -- --help
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
