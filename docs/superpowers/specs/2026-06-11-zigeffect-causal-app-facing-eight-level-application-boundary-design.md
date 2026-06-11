# zigeffect Causal App-Facing Eight-Level Application Boundary Design

## Context

The prior milestone delivered the eight-level app-facing evaluation report and
handed off to `codex/zigeffect-causal-app-facing-eight-level-application-boundary`.
That report emits the full schema lineage:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1
```

The next boundary must consume ready or advisory eight-level report artifacts
and emit guarded local evidence that a reviewed application boundary step either
remains planned, was actually applied, or is blocked. The seven-level
application-boundary tool is the implementation template.

## Physical Naming Constraint

The fully expanded next file name would exceed common macOS filesystem limits.
The previous fully expanded application-boundary path is already too close to
the limit for safe continuation, and further expansion would make future agents
fight the filesystem instead of the runtime.

The artifact schema remains fully expanded and authoritative. The physical
names switch to aliases:

- Tool file: `packages/zigeffect/tools/causal_app_facing_eight_level_application_boundary.zig`
- Build step: `causal-app-facing-eight-level-application-boundary`
- Executable: `zigeffect-causal-app-facing-eight-level-application-boundary`
- Docs: `packages/zigeffect/docs/app-facing-eight-level-application-boundary.md`
- Current branch: `codex/zigeffect-causal-app-facing-eight-level-application-boundary`
- Next branch if applied: `codex/zigeffect-causal-app-facing-eight-level-policy`
- Recommendation: `start-app-facing-eight-level-policy`

This alias policy is part of the boundary contract. Do not expand future branch
or file names past this point.

## Artifact Contract

The boundary emits:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1
```

The emitted JSON and text reports must include:

- source eight-level report path and status
- source readiness, blocked finding count, and mutation authority
- inherited policy, application boundary, report, request, support, and finding summaries
- boundary mode: `plan` or `record-applied`
- application status: `planned`, `applied`, or `blocked`
- `applied=false` in plan mode
- `ready_for_next_branch=false` in plan mode
- `applied=true` only in record-applied mode after all reviewed evidence gates pass
- source and boundary checks
- denied claims and negative fixtures
- required and observed verification commands
- local JSON and text output paths
- next branch alias for the policy milestone

## Boundary Gates

The source report gate passes only when:

- source schema equals the eight-level report schema and schema version is `1`
- source report status is `ready` or `advisory`
- source `ready_for_next_branch` is true
- source blocked findings count is zero
- source mutation authority is `none`
- source checks do not contain failures
- source publication channels remain local-only and non-mutating
- source SolidJS `webui-dev/zig-webui` read-only posture is preserved
- source verification commands include schema governance and production backlog checks

Plan mode adds no application authority. It records only local intent and skips
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
- mutation authority
- alternate frontend renderer work

## Backlog And Governance Updates

Schema governance must register the new schema as `current`, with alias
`emitted_by = causal-app-facing-eight-level-application-boundary`, consumed by
agents, reviewers, non-blocking CI advisory readers, the local SolidJS workbench,
the production-hardening backlog, and the future eight-level policy branch.

The production hardening backlog must mark the eight-level application boundary
as delivered, update the recommendation to `start-app-facing-eight-level-policy`,
and point the recommended next branch to
`codex/zigeffect-causal-app-facing-eight-level-policy`.

The master roadmap must mark the current branch delivered and add the eight-level
policy branch as the next milestone.

## Tests

TDD coverage must prove:

- constants expose the full output schema and short alias branch names
- option parsing accepts the alias build step and promoted after/change flags
- default output prefix compacts long source paths under the configured limit
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
zig test tools/causal_app_facing_eight_level_application_boundary.zig
zig build causal-app-facing-eight-level-application-boundary -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
