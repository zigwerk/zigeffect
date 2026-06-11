# Zigeffect Causal App-Facing Advisory Remediation Report Consumption Report Evaluation Report Policy Design

## Goal

Add a record-only policy producer for applied app-facing advisory remediation report consumption-report evaluation-report application-boundary artifacts. The producer lets agents, reviewers, non-blocking CI advisory readers, and the local SolidJS workbench decide whether a reviewed local evaluation-report boundary is acceptable evidence for the next evaluator branch.

## Context

The previous milestone added `causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary`. It records planned, applied, or blocked evidence for local evaluation-report application. This branch consumes only that applied JSON artifact and produces an interpretation policy artifact.

The new policy follows the existing app-facing policy pattern:

- `approve` records that a reviewer accepts the applied boundary as evidence for the next branch when every source and policy check passes.
- `reject` records a reviewer stop decision and never marks the policy ready.
- The tool never mutates application code, GitHub, CI workflows, deployment state, storage, runtime projections, or adapters.
- The output grants `mutation_authority = "none"` even when ready.

## Non-Goals

- No Cockroach scope.
- No NenDB writes or NenDB adapter execution.
- No app runtime integration.
- No SolidJS workbench write path.
- No GitHub API mutation, PR comment, step summary, artifact upload, required status check, or workflow mutation.
- No public artifact upload or hosted live dashboard claim.
- No auto-apply behavior.
- No production health, deployment success, or cluster readiness claim.

## Inputs

CLI shape:

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy -- \
  --from-application <consumption-report-evaluation-report-application-boundary.json> \
  approve|reject \
  --reason <reason> \
  [--by <reviewer>] \
  [--policy <policy-id>] \
  [--verified-command <command>]... \
  [--out-prefix <path-prefix>]
```

Source schema:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary.v1
```

The source must be the `record-applied` application-boundary output with `report_application_status = "applied"`, `applied = true`, `ready_for_next_branch = true`, and `mutation_authority = "record-only"`.

## Outputs

The new schema is:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy.v1
```

The tool writes JSON and text artifacts. The JSON includes:

- schema, schema version, generator, source branch, recommendation, and next branch;
- source application path, schema, status, and inherited evaluation-report refs;
- decision, reviewer, policy id, reason, policy status, ready flag, and mutation authority;
- authority-disable booleans;
- source evaluation-report application changes, before evidence, after evidence, checks, findings, denied claims, next queries, publication channels, and verification commands;
- policy checks, interpretation rules, consumption scopes, denied inference rules, and negative fixtures;
- output paths and agent guidance.

## Policy Checks

The policy evaluates these gates:

- `source-schema`: supported source schema and version.
- `source-applied-application`: source is `record-applied`, applied, ready, and record-only.
- `source-refs-present`: source links source evaluator, report policy, report application, consumption report, readiness/policy refs, and after-report digests.
- `source-application-evidence-present`: source includes evaluation-report application changes, before evidence, after evidence, after-report digest/presence, summaries, denied claims, next queries, and local publication channels.
- `source-application-checks-pass`: all source application checks passed.
- `source-evaluation-report-checks-pass`: source report checks have no failures.
- `source-authority-disabled`: all CI, GitHub, app, runtime, storage, deployment, public upload, auto-apply, and adapter authorities are disabled.
- `source-solid-webui-readonly`: source remains SolidJS inside `webui-dev/zig-webui` with read-only consumption.
- `source-local-publication-only`: source publication channels are local artifacts plus optional read-only SolidJS view only.
- `source-verification-evidence`: source carries every verification command required by the application-boundary milestone.
- `policy-catalogs-present`: interpretation, scope, denied-rule, and negative-fixture catalogs are present.
- `required-verification-commands`: approval records this policy milestone's required verification commands.
- `reviewer-decision`: rejection is preserved as blocked evidence.

## Interpretation Rules

Ready policy evidence may be used only to:

- cite reviewed local evaluation-report application evidence;
- feed the next read-only evaluation-report policy evaluator branch;
- help agents and the SolidJS workbench query bounded causal evidence;
- inform non-blocking CI advisory readers;
- preserve advisory findings as advisory context and blocked findings as stop signs.

Ready policy evidence may not be used to infer:

- production health;
- deployment success;
- required status checks;
- merge blocking;
- GitHub mutation;
- workflow mutation;
- app mutation or app runtime integration;
- live agent projection;
- raw payload capture;
- durable writes;
- NenDB writes or adapter execution;
- Cockroach work;
- public upload or hosted live dashboards;
- alternate renderer scope;
- auto-apply;
- mutation authority.

## Next Branch

If ready:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator
```

Recommendation:

```text
start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator
```

The evaluator branch will consume this policy artifact plus explicit local request and evidence files, then classify whether evaluation-report consumption evidence is ready, advisory, or blocked for app-facing agents and the SolidJS workbench.
