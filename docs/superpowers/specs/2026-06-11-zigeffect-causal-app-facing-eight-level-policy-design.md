# Zigeffect App-Facing Eight-Level Policy Design

## Context

The eight-level application-boundary milestone now emits applied record-only
evidence with this schema:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1
```

The applied boundary artifact preserves full lineage while using short physical
aliases for files, build steps, and branches. The next branch is
`codex/zigeffect-causal-app-facing-eight-level-policy`, and this milestone adds
the matching policy producer.

## Physical Naming Policy

The artifact schema remains fully expanded and authoritative. Physical names
continue to use the short alias policy introduced by the eight-level
application-boundary milestone:

- Tool file: `packages/zigeffect/tools/causal_app_facing_eight_level_policy.zig`
- Build step: `causal-app-facing-eight-level-policy`
- Executable: `zigeffect-causal-app-facing-eight-level-policy`
- Docs: `packages/zigeffect/docs/app-facing-eight-level-policy.md`
- Current branch: `codex/zigeffect-causal-app-facing-eight-level-policy`
- Next branch if ready: `codex/zigeffect-causal-app-facing-eight-level-evaluator`
- Recommendation: `start-app-facing-eight-level-evaluator`

Future files and branches must not re-expand the physical name past this point.

## Artifact Contract

The policy emits:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1
```

It consumes only applied eight-level application-boundary artifacts.

The emitted JSON and text reports include:

- source application-boundary path, schema, mode, status, and applied state
- source readiness, mutation authority, denied claims, publication channels,
  negative fixtures, and verification commands
- decision: `approve` or `reject`
- policy status: `ready` or `blocked`
- `ready_for_next_branch=true` only for `approve` with all gates passing
- interpretation rules for agents, reviewers, non-blocking CI advisory readers,
  SolidJS `webui-dev/zig-webui`, and the future eight-level evaluator
- consumption scopes with local-only and read-only posture
- denied inferences and negative fixtures
- required and observed verification commands
- local JSON and text output paths
- next branch alias for the evaluator milestone

## Policy Gates

Approval requires:

- source schema equals the eight-level application-boundary schema and version
  is `1`
- source mode is `record-applied`
- source application status is `applied`
- source `applied=true`
- source `ready_for_next_branch=true`
- source mutation authority is `record-only`
- source application checks do not contain failures
- source denied claims, negative fixtures, boundary rules, publication channels,
  and required verification commands are present
- policy invocation records every required verification command
- CI, GitHub, app runtime, raw payload, durable write, NenDB write, NenDB
  adapter execution, Cockroach, deployment, production-health, public upload,
  hosted dashboard, auto-apply, and mutation authority remain disabled

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

Schema governance must register the eight-level policy schema as current, with
`emitted_by = causal-app-facing-eight-level-policy`. The production hardening
backlog must mark `app-facing-eight-level-policy` delivered, update the
recommendation to `start-app-facing-eight-level-evaluator`, and point the
recommended next branch to
`codex/zigeffect-causal-app-facing-eight-level-evaluator`.

## Tests

Focused Zig tests must cover:

- stable schema, branch, recommendation, next-branch, and alias constants
- approve and reject option parsing
- default output path replacement from eight-level application-boundary suffix
  to eight-level policy suffix
- approved policy ready only with applied source evidence and verification
  commands
- rejected policy blocked while preserving denied inference rules
- planned source, source authority drift, missing verification, and failed
  source checks block approval
- generated JSON is parseable

Registry tests must prove:

- schema governance count increments by one
- schema governance contains the eight-level policy schema
- production backlog recommendation moves to the eight-level evaluator branch
- generated backlog docs contain the eight-level policy item and build commands

## Verification

Fresh verification must include:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_eight_level_policy.zig
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-app-facing-eight-level-policy -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
