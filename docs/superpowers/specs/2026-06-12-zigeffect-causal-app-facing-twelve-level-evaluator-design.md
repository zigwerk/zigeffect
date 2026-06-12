# Zigeffect App-Facing Twelve-Level Evaluator Design

## Context

The causal self-improvement roadmap has delivered the twelve-level policy
artifact. The next branch,
`codex/zigeffect-causal-app-facing-twelve-level-evaluator`, must consume an
approved twelve-level policy plus bounded local request and support evidence,
then emit read-only evaluator artifacts for agents, reviewers, non-blocking CI
advisory readers, and the local SolidJS `webui-dev/zig-webui` workbench.

This milestone is still advisory and local. It must help agents reason about
which evidence is safe to feed into the thirteen-level report, without turning
that evidence into runtime mutation, CI enforcement, app integration, storage
writes, production health claims, public upload, or automatic registry changes.

## Goals

- Add `causal-app-facing-twelve-level-evaluator` as the short alias command.
- Emit the fully expanded twelve-level evaluator schema:
  `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1`.
- Consume the fully expanded twelve-level policy schema:
  `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1`.
- Preserve direct twelve-level policy, application-boundary, report, digest,
  and application-change evidence, plus eleven-level, ten-level, nine-level,
  eight-level, and inherited lower lineage already carried by the source
  policy.
- Classify bounded request and support files under
  `.zig-cache/causal-artifacts/`, including request JSON/text, causal JSON/text,
  and SolidJS webui support text.
- Emit three outcomes: `ready`, `advisory-findings`, or `blocked`.
- Hand ready or advisory evaluator evidence to
  `codex/zigeffect-causal-app-facing-thirteen-level-report`.

## Non-Goals

- Do not create a required CI status check, merge blocker, branch protection
  rule, workflow mutation, GitHub API mutation, PR comment, or step summary.
- Do not write app configuration, app data, runtime state, Durable Objects,
  D1, R2, NenDB, CockroachDB, production telemetry, public artifact stores, or
  hosted dashboard state.
- Do not execute the future NenDB adapter. The durable-storage direction
  remains NenDB adapter only, with no Cockroach work in this branch.
- Do not capture raw prompts, raw responses, private keys, provider tokens, or
  unredacted payloads.
- Do not auto-apply findings or mutate any registry. Registry application is a
  later guarded boundary.

## Approach Options

1. Promote the eleven-level evaluator into a twelve-level evaluator while
   adding direct twelve-level source gates. This is the chosen path because the
   ladder already uses explicit alias promotion and the prior evaluator has the
   right request/support classification behavior.
2. Build a generic evaluator generator for every future level. This could
   reduce repetition later, but it would add abstraction while the roadmap is
   still proving the artifact contract and would make review harder.
3. Skip the evaluator and route policy artifacts directly to the thirteen-level
   report. This would remove the bounded request/support evidence check the
   roadmap specifically needs for agent-facing usefulness.

## Architecture

`packages/zigeffect/tools/causal_app_facing_twelve_level_evaluator.zig` is a
standalone Zig build tool. It accepts:

```text
zig build causal-app-facing-twelve-level-evaluator -- \
  --from-policy <twelve-level-policy.json> evaluate \
  --reason <reason> \
  --request <path>... \
  [--evidence <path>]... \
  [--by <actor>] \
  [--policy <policy>] \
  [--out-prefix <path-prefix>]
```

The tool parses the source policy artifact, reads bounded request/support
inputs, classifies each file, and writes paired JSON/text artifacts. File
classification is intentionally conservative: inputs must be `.json` or `.txt`
under `.zig-cache/causal-artifacts/`; secret-shaped strings, raw prompt or raw
response fields, mutation flags, runtime-integration flags, Cockroach claims,
public upload claims, production-health claims, React renderer drift, and
auto-apply claims are denied.

## Readiness Rules

The source policy is valid only when:

- The schema and schema version match the twelve-level policy contract.
- The policy status is `ready`, `ready_for_next_branch=true`, and the decision
  is `approve`.
- Mutation authority is `none`.
- Direct twelve-level application-boundary, report, report status, digest,
  after-present, and application-change evidence are present.
- Eleven-level, ten-level, nine-level, eight-level, and inherited lower lineage
  remain present and ready where the prior tools require it.
- Policy checks contain no failures.
- Interpretation rules, consumption scopes, denied inference rules, negative
  fixtures, required verification commands, and verified commands are present.
- CI, GitHub, app, runtime, storage, deployment, public upload, production
  health, adapter execution, and auto-apply authority remain disabled.
- SolidJS inside `webui-dev/zig-webui` remains the read-only rendering scope.

The request is valid only when at least one safe request file is supplied. A
missing support evidence file is advisory rather than blocking, because the
artifact can still help review while explicitly surfacing the missing support.
Unsafe request or evidence files block readiness.

## Artifact Contract

The JSON output includes:

- `schema`, `schema_version`, `generated_by`, `source_branch`,
  `recommendation`, and `next_branch_if_ready`.
- `source_twelve_level_policy`, `source_twelve_level_policy_schema`,
  `source_twelve_level_policy_status`, and `source_policy_decision`.
- Direct twelve-level source application-boundary/report/digest fields and
  `source_twelve_level_application_changes`.
- Eleven-level, ten-level, nine-level, eight-level, inherited lower lineage,
  source report checks, source request/support summaries, denied claims, policy
  rule ids, consumption scope ids, next queries, and local publication channel
  ids.
- `request_files`, `evidence_files`, `checks`, `signal_evaluations`,
  `findings`, `denied_claims`, `required_verification_commands`, output paths,
  and `agent_guidance`.

The text output mirrors the important fields for humans and terminal-oriented
agents. The default output prefix replaces
`-ci-twelve-level-policy.json` with `-ci-twelve-level-evaluator`; long names
compact to `app-facing-ci-twelve-level-evaluator-<digest>`.

## Schema Governance And Backlog

`causal_schema_governance.zig` registers the twelve-level evaluator schema as
`app-runtime`, `current`, `record-only`, `evaluator-only`,
`source-twelve-level-policy`, `bounded-explicit-evidence`, `solid-webui`,
`webui-dev/zig-webui`, `no-cockroach`, `no-nendb-write`,
`no-nendb-adapter-execution`, and `no-mutation-authority`.

`causal_production_hardening_backlog.zig` marks the evaluator branch as
delivered, updates the recommendation to start the thirteen-level report, adds
ready/advisory/blocked command examples, and places the evaluator after the
twelve-level policy in dependency order.

The master roadmap marks item 113 delivered and adds item 114:
`codex/zigeffect-causal-app-facing-thirteen-level-report`.

## Testing

Tests prove:

- Constants, schema strings, command names, source branch, recommendation, and
  next branch are stable.
- CLI parsing accepts multiple request and evidence inputs.
- The default output path replaces the twelve-level policy suffix.
- File classification accepts bounded request, policy, causal, and SolidJS
  webui files while denying unbounded paths and unsafe content.
- Ready output preserves direct twelve-level evidence, lower lineage, read-only
  authority, SolidJS webui scope, and redaction posture.
- Missing support evidence produces `advisory-findings`.
- Unsafe request evidence blocks readiness.
- Rejected or blocked source policy evidence blocks readiness.
- Schema governance, production backlog, docs, and the roadmap include the new
  evaluator and next-branch handoff.
