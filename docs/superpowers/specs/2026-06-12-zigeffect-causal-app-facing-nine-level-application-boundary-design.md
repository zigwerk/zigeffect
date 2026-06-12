# zigeffect Causal App-Facing Nine-Level Application Boundary Design

## Context

The prior milestone delivered `causal-app-facing-nine-level-report` and handed
off to `codex/zigeffect-causal-app-facing-nine-level-application-boundary`.
That report emits:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1
```

This milestone adds the matching guarded application-boundary. It consumes
ready or advisory nine-level report artifacts and emits local evidence that a
reviewed boundary step is either planned, applied, or blocked. It follows the
eight-level application-boundary pattern exactly: `plan` records local intent
only, while `record-applied` requires reviewed change evidence, before/after
evidence, safe after-report content, and complete verification commands.

## Physical Naming Constraint

The artifact schema remains fully expanded and authoritative. Physical files,
build steps, docs, and branches use aliases because further expanded names are
not ergonomic for filesystems, shells, branch tooling, or agent context.

- Tool file: `packages/zigeffect/tools/causal_app_facing_nine_level_application_boundary.zig`
- Build step: `causal-app-facing-nine-level-application-boundary`
- Executable: `zigeffect-causal-app-facing-nine-level-application-boundary`
- Docs: `packages/zigeffect/docs/app-facing-nine-level-application-boundary.md`
- Fixture: `packages/zigeffect/test/fixtures/app-facing-nine-level-application-boundary-after-safe.txt`
- Current branch: `codex/zigeffect-causal-app-facing-nine-level-application-boundary`
- Next branch if applied: `codex/zigeffect-causal-app-facing-nine-level-policy`
- Recommendation: `start-app-facing-nine-level-policy`

## Artifact Contract

The boundary emits:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1
```

The emitted JSON and text reports must include:

- source nine-level report path, schema, status, and readiness
- inherited eight-level evaluator, policy, application-boundary, and report refs
- inherited lower-level report and application-boundary evidence
- source request, support, signal, finding, denied-claim, and next-query summaries
- boundary mode: `plan` or `record-applied`
- application status: `planned`, `applied`, or `blocked`
- `applied=false` in plan mode
- `ready_for_next_branch=false` in plan mode
- `applied=true` only in record-applied mode after all evidence gates pass
- source and boundary checks
- required and observed verification commands
- local JSON and text output paths
- next branch alias for the nine-level policy milestone

The status field for this boundary is:

```text
evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status
```

## Boundary Gates

The source report gate passes only when:

- source schema equals the nine-level report schema and schema version is `1`
- source report status is `ready` or `advisory`
- source `ready_for_next_branch` is true
- source blocked finding count is zero
- source mutation authority is `none`
- source checks do not contain failures
- source publication channels remain local-only and non-mutating
- source SolidJS `webui-dev/zig-webui` read-only posture is preserved
- source verification commands include workbench, schema governance, production
  backlog, examples, and zigeffect test checks

Plan mode adds no application authority. It records local intent only and skips
before/after evidence requirements.

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
`emitted_by = causal-app-facing-nine-level-application-boundary`, consumed by
agents, reviewers, non-blocking CI advisory readers, the local SolidJS workbench,
the production-hardening backlog, and the future nine-level policy branch.

The production hardening backlog must mark `app-facing-nine-level-application-boundary`
as delivered, update the recommendation to `start-app-facing-nine-level-policy`,
and point the recommended next branch to
`codex/zigeffect-causal-app-facing-nine-level-policy`.

The master roadmap must mark the current branch delivered and add the nine-level
policy branch as the next milestone.

## Tests

TDD coverage must prove:

- constants expose the full output schema and short alias branch names
- option parsing accepts the alias build step and promoted after/change flags
- default output prefix replaces nine-level report suffix and compacts long paths
- plan mode emits planned state without applied authority
- record-applied blocks without evidence
- record-applied applies only with reviewed change, before, after, safe report,
  and all verification commands
- unsafe after-report content blocks application
- blocked source report blocks application
- source authority drift blocks application
- emitted JSON is parseable
- schema governance count and schema entry include the new artifact
- production backlog text and JSON include the delivered item and next policy handoff

## Verification

Required verification for this milestone:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_nine_level_application_boundary.zig
zig build causal-app-facing-nine-level-application-boundary -- --help
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
