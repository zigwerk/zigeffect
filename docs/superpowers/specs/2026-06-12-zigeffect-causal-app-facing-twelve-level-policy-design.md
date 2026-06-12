# Zigeffect App-Facing Twelve-Level Policy Design

## Context

The active causal self-improvement roadmap has just delivered
`causal-app-facing-twelve-level-application-boundary`. The next branch,
`codex/zigeffect-causal-app-facing-twelve-level-policy`, must consume the
applied twelve-level application-boundary artifact and emit a local,
record-only approve/reject policy artifact for agents, reviewers,
non-blocking CI advisory readers, and the SolidJS `webui-dev/zig-webui`
workbench.

This milestone is not a runtime mutation feature. It is another bounded
causal evidence layer that helps agents reason about whether the previous
application-boundary evidence is safe to use as input for the next evaluator.

## Goals

- Add `causal-app-facing-twelve-level-policy` as the short alias command.
- Emit the fully expanded twelve-level policy schema:
  `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1`.
- Consume the fully expanded twelve-level application-boundary schema:
  `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1`.
- Preserve twelve-level source application-boundary/report evidence plus
  eleven-level, ten-level, nine-level, eight-level, and inherited lower
  lineage already carried by the source artifact.
- Keep all mutation authority disabled: no CI enforcement, no required status
  check, no workflow mutation, no GitHub mutation, no app mutation, no runtime
  integration, no live projection, no raw payload capture, no deployment
  mutation, no public upload, no durable write, and no NenDB adapter execution.
- Keep the durable-storage direction explicit: NenDB adapter only later,
  no Cockroach work in this branch.
- Hand ready policy evidence to
  `codex/zigeffect-causal-app-facing-twelve-level-evaluator`.

## Non-Goals

- Do not write to app runtime state, production systems, GitHub APIs, CI
  workflow files, branch protection, NenDB, CockroachDB, or public artifact
  stores.
- Do not introduce a hosted dashboard or live app-facing projection.
- Do not make the policy artifact a required status check or merge blocker.
- Do not add a generic schema generator; use the established explicit Zig
  artifact pattern for this ladder step.

## Approach Options

1. Promote the eleven-level policy implementation into a twelve-level alias.
   This preserves the existing gate catalog, output format, negative fixtures,
   and test shape while adding direct twelve-level source fields. This is the
   recommended option because the ladder already uses explicit alias promotion
   and agents can diff the milestone against the prior policy.
2. Build a generic `NLevelPolicy` generator. This would reduce future
   duplication, but it would be a large abstraction in the middle of a
   sequential roadmap and would risk changing previously verified artifacts.
3. Skip the twelve-level policy and route the application-boundary artifact
   directly to an evaluator. This would shorten the ladder but remove the
   explicit approve/reject policy evidence the roadmap asks for.

The chosen design is option 1.

## Architecture

`packages/zigeffect/tools/causal_app_facing_twelve_level_policy.zig` is a
standalone Zig build tool. It parses `--from-application <json>` plus an
`approve|reject` decision and emits paired JSON/text artifacts. The input
schema, command, executable, docs path, branch names, and output prefix use the
short twelve-level alias while schema fields remain fully expanded.

The policy evaluator has three groups of gates:

- Source boundary gates: source schema v1, `record-applied`, applied status,
  `ready_for_next_branch=true`, mutation authority `record-only`, and passing
  source application/report checks.
- Lineage and evidence gates: direct twelve-level application-boundary/report
  references, eleven/ten/nine lineage, inherited lower lineage, before/after
  evidence, application changes, denied claims, next queries, local publication
  channels, negative fixtures, and verification commands.
- Non-authority gates: all CI, GitHub, app, runtime, storage, deployment,
  public-upload, production-health, auto-apply, and adapter execution flags
  remain disabled; SolidJS inside `webui-dev/zig-webui` remains read-only.

An approve decision is `ready` only when every gate passes and all required
verification commands are recorded. A reject decision is always preserved as a
blocked policy artifact with the reviewer decision visible in the checks.

## Artifacts

The default output path replaces
`-ci-twelve-level-application-boundary.json` with `-ci-twelve-level-policy`.
Long path names compact to `app-facing-ci-twelve-level-policy-<digest>` using
the existing digest helper.

The output JSON must include:

- `schema`, `schema_version`, `generated_by`, `source_branch`,
  `recommendation`, and `next_branch_if_ready`.
- `source_twelve_level_application_boundary`,
  `source_twelve_level_application_boundary_schema`,
  `source_twelve_level_report`, `source_twelve_level_report_schema`,
  `source_twelve_level_report_status`,
  `source_twelve_level_after_digest`,
  `source_twelve_level_after_present`, and
  `source_twelve_level_application_changes`.
- Existing eleven-level, ten-level, nine-level, eight-level, and inherited
  lineage fields.
- `decision`, policy status, `ready_for_next_branch`, mutation authority,
  policy checks, interpretation rules, consumption scopes, denied inference
  rules, source negative fixtures, policy negative fixtures, required
  verification commands, verified commands, and agent guidance.

## Schema Governance And Backlog

`causal_schema_governance.zig` registers the new policy schema as
`app-runtime`, `current`, `record-only`, `policy-only`,
`source-twelve-level-application-boundary`, `approve-reject-decision`,
`solid-webui`, `webui-dev/zig-webui`, `no-cockroach`, `no-nendb-write`,
`no-nendb-adapter-execution`, and `no-mutation-authority`.

`causal_production_hardening_backlog.zig` marks the branch as delivered,
updates the recommendation to start the twelve-level evaluator, adds command
examples for approve and reject artifacts, and includes the policy in the
dependency order immediately after the twelve-level application boundary.

The master roadmap marks item 112 delivered and adds the next evaluator branch
as item 113.

## Testing

Tests follow the existing policy pattern and prove:

- Constants, schemas, command names, and output suffixes are stable.
- CLI parsing accepts approve/reject and rejects invalid inputs.
- Approval requires an applied twelve-level application-boundary source and
  all required verification commands.
- Rejection emits blocked policy evidence.
- Planned or blocked source application-boundary artifacts block readiness.
- Source authority drift blocks readiness.
- Direct twelve-level source fields and eleven/ten/nine lineage are preserved
  in JSON and text reports.
- Output JSON parses.
- Schema governance and production backlog tests include the new schema,
  branch, dependency, and build command.

## Handoff

Ready policy artifacts are advisory inputs for
`codex/zigeffect-causal-app-facing-twelve-level-evaluator`. The evaluator must
still perform its own bounded request/support-evidence classification and must
not infer runtime integration or mutation authority from policy readiness.
