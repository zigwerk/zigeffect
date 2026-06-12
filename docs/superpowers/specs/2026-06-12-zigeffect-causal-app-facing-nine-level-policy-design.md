# Zigeffect App-Facing Nine-Level Policy Design

## Context

The nine-level application-boundary milestone now emits applied record-only
evidence with this schema:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1
```

That artifact records that the reviewed local nine-level application boundary
was actually applied, preserves inherited eight-level policy lineage, and keeps
all app, CI, GitHub, storage, deployment, public upload, and mutation authority
disabled. The next branch is
`codex/zigeffect-causal-app-facing-nine-level-policy`, and this milestone adds
the matching read-only policy producer.

## Physical Naming Policy

The artifact schema remains fully expanded and authoritative. Physical names
continue to use short aliases:

- Tool file: `packages/zigeffect/tools/causal_app_facing_nine_level_policy.zig`
- Build step: `causal-app-facing-nine-level-policy`
- Executable: `zigeffect-causal-app-facing-nine-level-policy`
- Docs: `packages/zigeffect/docs/app-facing-nine-level-policy.md`
- Current branch: `codex/zigeffect-causal-app-facing-nine-level-policy`
- Next branch if ready: `codex/zigeffect-causal-app-facing-nine-level-evaluator`
- Recommendation: `start-app-facing-nine-level-evaluator`

Future files and branches must not re-expand physical names past this point.

## Artifact Contract

The policy emits:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1
```

It consumes only applied nine-level application-boundary artifacts.

The emitted JSON and text reports include:

- source nine-level application-boundary path, schema, mode, status, and applied
  state
- source nine-level report refs and inherited eight-level policy/report lineage
- source readiness, mutation authority, denied claims, publication channels,
  negative fixtures, and verification commands
- decision: `approve` or `reject`
- policy status: `ready` or `blocked`
- `ready_for_next_branch=true` only for `approve` with every gate passing
- interpretation rules for agents, reviewers, non-blocking CI advisory readers,
  SolidJS `webui-dev/zig-webui`, and the future nine-level evaluator
- consumption scopes with local-only, read-only, no-mutation posture
- denied inferences and negative fixtures
- required and observed verification commands
- local JSON and text output paths
- next branch alias for the evaluator milestone

## Policy Gates

Approval requires:

- source schema equals the nine-level application-boundary schema and version is
  `1`
- source mode is `record-applied`
- source application status is `applied`
- source `applied=true`
- source `ready_for_next_branch=true`
- source mutation authority is `record-only`
- source nine-level report refs are present and ready
- inherited eight-level policy refs are present, approved, and ready
- source application checks do not contain failures
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

Schema governance must register the nine-level policy schema as current, with
`emitted_by = causal-app-facing-nine-level-policy`. The production hardening
backlog must mark `app-facing-nine-level-policy` delivered, update the
recommendation to `start-app-facing-nine-level-evaluator`, and point the
recommended next branch to
`codex/zigeffect-causal-app-facing-nine-level-evaluator`.

## Tests

Focused Zig tests must cover:

- stable schema, branch, recommendation, next-branch, and alias constants
- approve and reject option parsing
- default output path replacement from nine-level application-boundary suffix to
  nine-level policy suffix
- approved policy ready only with applied source evidence and verification
  commands
- rejected policy blocked while preserving denied inference rules
- planned source, source authority drift, missing verification, and failed
  source checks block approval
- generated JSON is parseable

Registry tests must prove:

- schema governance count increments by one
- schema governance contains the nine-level policy schema
- production backlog recommendation moves to the nine-level evaluator branch
- generated backlog docs contain the nine-level policy item and build commands

## Verification

Fresh verification must include:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_nine_level_policy.zig
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-app-facing-nine-level-policy -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
