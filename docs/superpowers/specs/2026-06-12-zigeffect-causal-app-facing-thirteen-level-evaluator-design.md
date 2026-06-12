# Zigeffect App-Facing Thirteen-Level Evaluator Design

## Context

The causal self-improvement roadmap has delivered the thirteen-level policy
artifact. The next branch,
`codex/zigeffect-causal-app-facing-thirteen-level-evaluator`, consumes an
approved thirteen-level policy plus bounded local request and support evidence,
then emits read-only evaluator artifacts for agents, reviewers, non-blocking CI
advisory readers, and the local SolidJS `webui-dev/zig-webui` workbench.

This milestone remains advisory and local. It helps agents decide which
thirteen-level policy evidence is safe to hand to the fourteen-level report,
without converting that evidence into CI enforcement, runtime mutation, app
integration, storage writes, production health claims, public upload, or
automatic registry changes.

## Goals

- Add `causal-app-facing-thirteen-level-evaluator` as the short build command.
- Emit the fully expanded thirteen-level evaluator schema:
  `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1`.
- Consume the fully expanded thirteen-level policy schema:
  `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1`.
- Preserve direct thirteen-level policy, application-boundary, report, digest,
  and application-change evidence.
- Carry the twelve-level evaluator, twelve-level policy, twelve-level
  application-boundary/report evidence, and lower lineage forward for agents
  that need the whole causal ladder.
- Classify bounded request and support files under
  `.zig-cache/causal-artifacts/`, including request JSON/text, causal JSON/text,
  and SolidJS webui support text.
- Emit `ready`, `advisory-findings`, or `blocked`.
- Hand ready or advisory evaluator evidence to
  `codex/zigeffect-causal-app-facing-fourteen-level-report`.

## Non-Goals

- Do not create required CI status checks, merge blockers, branch protection
  rules, workflow mutations, GitHub API mutations, PR comments, or step
  summaries.
- Do not write app configuration, app data, runtime state, Durable Objects,
  D1, R2, NenDB, CockroachDB, production telemetry, public artifact stores, or
  hosted dashboard state.
- Do not execute the future NenDB adapter. The durable-storage direction
  remains NenDB adapter only, with no Cockroach work in this branch.
- Do not capture raw prompts, raw responses, private keys, provider tokens, or
  unredacted payloads.
- Do not auto-apply findings or mutate any registry. Registry application
  remains a later guarded boundary.

## Chosen Approach

Promote the twelve-level evaluator into a thirteen-level evaluator and add
direct thirteen-level source gates. This matches the existing artifact ladder,
keeps review mechanical where possible, and avoids introducing a generator
while the contract is still being hardened.

The evaluator is a standalone Zig build tool:

```text
zig build causal-app-facing-thirteen-level-evaluator -- \
  --from-policy <thirteen-level-policy.json> evaluate \
  --reason <reason> \
  --request <path>... \
  [--evidence <path>]... \
  [--by <actor>] \
  [--policy <policy>] \
  [--out-prefix <path-prefix>]
```

## Readiness Rules

The source policy is valid only when:

- The schema and schema version match the thirteen-level policy contract.
- The policy status is `ready`, `ready_for_next_branch=true`, and the decision
  is `approve`.
- Mutation authority is `none`.
- Direct thirteen-level application-boundary, report, report status, digest,
  after-present, and application-change evidence are present.
- Direct twelve-level evaluator and policy evidence remain present and ready.
- Direct twelve-level application-boundary/report/digest evidence and lower
  eleven-, ten-, nine-, eight-level, and inherited lineage remain present.
- Policy checks contain no failures.
- Interpretation rules, consumption scopes, denied inference rules, negative
  fixtures, required verification commands, and verified commands are present.
- CI, GitHub, app, runtime, storage, deployment, public upload, production
  health, adapter execution, and auto-apply authority remain disabled.
- SolidJS inside `webui-dev/zig-webui` remains the read-only rendering scope.

The request is valid only when at least one safe request file is supplied. A
missing support evidence file is advisory rather than blocking. Unsafe request
or evidence files block readiness.

## Artifact Contract

The JSON output includes:

- `schema`, `schema_version`, `generated_by`, `source_branch`,
  `recommendation`, and `next_branch_if_ready`.
- `source_thirteen_level_policy`, `source_thirteen_level_policy_schema`,
  `source_thirteen_level_policy_status`, and `source_policy_decision`.
- Direct thirteen-level application-boundary/report/digest fields and
  `source_thirteen_level_application_changes`.
- Direct twelve-level evaluator, policy, application-boundary/report/digest
  fields and `source_twelve_level_application_changes`.
- Lower lineage, source report checks, source request/support summaries,
  denied claims, policy rule ids, consumption scope ids, next queries, and
  local publication channel ids.
- `request_files`, `evidence_files`, `checks`, `signal_evaluations`,
  `findings`, `denied_claims`, `required_verification_commands`, output paths,
  and `agent_guidance`.

The text output mirrors the important fields for humans and terminal-oriented
agents. The default output prefix replaces
`-ci-thirteen-level-policy.json` with `-ci-thirteen-level-evaluator`; long names
compact to `app-facing-ci-thirteen-level-evaluator-<digest>`.

## Schema Governance And Backlog

`causal_schema_governance.zig` registers the thirteen-level evaluator schema as
`app-runtime`, `current`, `record-only`, `evaluator-only`,
`source-thirteen-level-policy`, `bounded-explicit-evidence`, `solid-webui`,
`webui-dev/zig-webui`, `no-cockroach`, `no-nendb-write`,
`no-nendb-adapter-execution`, and `no-mutation-authority`.

`causal_production_hardening_backlog.zig` marks the evaluator branch as
delivered, updates the recommendation to start the fourteen-level report, adds
ready/advisory/blocked command examples, and places the evaluator after the
thirteen-level policy in dependency order.

The master roadmap marks item 117 delivered and adds item 118:
`codex/zigeffect-causal-app-facing-fourteen-level-report`.

## Testing

Tests prove:

- Constants, schema strings, command names, source branch, recommendation, and
  next branch are stable.
- CLI parsing accepts multiple request and evidence inputs.
- The default output path replaces the thirteen-level policy suffix.
- File classification accepts bounded request, policy, causal, and SolidJS
  webui files while denying unbounded paths and unsafe content.
- Ready output preserves direct thirteen-level evidence, twelve-level evaluator
  and policy lineage, lower lineage, read-only authority, SolidJS webui scope,
  and redaction posture.
- Missing support evidence produces `advisory-findings`.
- Unsafe request evidence blocks readiness.
- Rejected or blocked source policy evidence blocks readiness.
- Schema governance, production backlog, docs, and the roadmap include the new
  evaluator and next-branch handoff.
