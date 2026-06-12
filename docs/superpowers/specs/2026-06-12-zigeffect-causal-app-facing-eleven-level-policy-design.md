# Zigeffect App-Facing Eleven-Level Policy Design

## Context

The eleven-level application-boundary milestone now emits applied record-only
evidence with this schema:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1
```

That artifact records reviewed local application-boundary evidence for the
eleven-level app-facing report, carries direct ten-level policy/application/report
lineage plus inherited nine-level lineage, and keeps app, CI, GitHub, storage,
deployment, public upload, and mutation authority disabled. This milestone adds
the matching read-only policy producer on:

```text
codex/zigeffect-causal-app-facing-eleven-level-policy
```

The output hands approved policy evidence to:

```text
codex/zigeffect-causal-app-facing-eleven-level-evaluator
```

## Physical Naming Policy

The artifact schema remains fully expanded and authoritative. Physical names
continue to use short aliases:

- Tool file: `packages/zigeffect/tools/causal_app_facing_eleven_level_policy.zig`
- Build step: `causal-app-facing-eleven-level-policy`
- Executable: `zigeffect-causal-app-facing-eleven-level-policy`
- Docs: `packages/zigeffect/docs/app-facing-eleven-level-policy.md`
- Current branch: `codex/zigeffect-causal-app-facing-eleven-level-policy`
- Next branch if ready: `codex/zigeffect-causal-app-facing-eleven-level-evaluator`
- Recommendation: `start-app-facing-eleven-level-evaluator`

Future files and branches must not re-expand physical names past the
eleven-level alias.

## Artifact Contract

The policy emits:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1
```

It consumes only eleven-level application-boundary artifacts.

The emitted JSON and text reports include:

- source eleven-level application-boundary path, schema, mode, status, and
  applied state
- source eleven-level report refs
- direct source ten-level policy, application-boundary, and report refs
- inherited source nine-level policy, application-boundary, and report refs
- lower-level inherited policy/report lineage already carried by the source
- source readiness, mutation authority, denied claims, publication channels,
  negative fixtures, and verification commands
- decision: `approve` or `reject`
- policy status: `ready` or `blocked`
- `ready_for_next_branch=true` only for `approve` with every gate passing
- interpretation rules for agents, reviewers, non-blocking CI advisory readers,
  SolidJS `webui-dev/zig-webui`, and the future eleven-level evaluator
- local-only read-only consumption scopes
- denied inferences and negative fixtures
- required and observed verification commands
- local JSON and text output paths
- next branch alias for the evaluator milestone

The source eleven-level application status field is:

```text
evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status
```

The eleven-level policy status field is:

```text
consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status
```

## Policy Gates

Approval requires:

- source schema equals the eleven-level application-boundary schema and version
  is `1`
- source mode is `record-applied`
- source application status is `applied`
- source `applied=true`
- source `ready_for_next_branch=true`
- source mutation authority is `record-only`
- source eleven-level report refs are present and ready or advisory
- direct source ten-level policy/application-boundary/report refs are present
  and ready
- inherited source nine-level policy/application-boundary/report refs are
  present and ready
- inherited lower-level policy refs are present, approved, and ready
- source application checks do not contain failures
- source report checks do not contain failures
- source denied claims, negative fixtures, boundary rules, publication channels,
  and required verification commands are present
- policy invocation records every required verification command
- CI, GitHub, app runtime, raw payload, durable write, NenDB write, NenDB adapter
  execution, Cockroach, deployment, production-health, public upload, hosted
  dashboard, auto-apply, and mutation authority remain disabled

`reject` emits blocked policy evidence even when the source is otherwise
healthy. Planned, blocked, incomplete, unsafe, or authority-drift source
artifacts also emit blocked policy evidence.

## Non-Authority

The policy never creates or implies:

- CI enforcement or required status checks
- workflow mutation
- GitHub API mutation
- step summary or pull request comment writes
- app mutation, app config writes, app data writes, or app runtime integration
- live agent projection
- raw prompt, response, or payload capture
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

Schema governance must register the eleven-level policy schema as current, with
`emitted_by = causal-app-facing-eleven-level-policy`. The production hardening
backlog must mark `app-facing-eleven-level-policy` delivered, update the
recommendation to `start-app-facing-eleven-level-evaluator`, and point the
recommended next branch to:

```text
codex/zigeffect-causal-app-facing-eleven-level-evaluator
```

The master roadmap must mark the current policy branch delivered and add the
eleven-level evaluator branch as the next milestone.

## Tests

Focused Zig tests must cover:

- stable schema, branch, recommendation, next-branch, and alias constants
- approve and reject option parsing
- default output path replacement from eleven-level application-boundary suffix
  to eleven-level policy suffix
- approved policy ready only with applied source evidence and verification
  commands
- rejected policy blocked while preserving denied inference rules
- source eleven-level report lineage and source ten-level
  policy/application/report lineage are carried forward
- inherited nine-level policy/application/report lineage is carried forward
- planned source, blocked source, source authority drift, missing verification,
  and failed source checks block approval
- generated JSON is parseable

Registry tests must prove:

- schema governance count increments by one
- schema governance contains the eleven-level policy schema
- production backlog recommendation moves to the eleven-level evaluator branch
- generated backlog docs contain the eleven-level policy item and build commands

## Verification

Fresh verification must include:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_eleven_level_policy.zig
zig build causal-app-facing-eleven-level-policy -- --help
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
