# Zigeffect Causal App-Facing Advisory Remediation Report Consumption Report Policy Design

## Goal

Add a record-only policy producer for applied app-facing advisory remediation report consumption-report application-boundary artifacts. The producer lets agents, reviewers, non-blocking CI advisory readers, and the local SolidJS workbench decide whether an applied report-consumption application record is acceptable evidence for the next evaluator branch.

## Context

The previous milestone added `causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary`. It records plan, applied, or blocked evidence for local consumption-report application. This branch consumes only the applied JSON artifact from that milestone and produces a review policy artifact.

The policy producer follows the existing app-facing policy pattern:

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

## Inputs

CLI shape:

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy -- \
  --from-application <consumption-report-application-boundary.json> \
  approve|reject \
  --reason <reason> \
  [--by <reviewer>] \
  [--policy <policy-id>] \
  [--verified-command <command>]... \
  [--out-prefix <path-prefix>]
```

Source schema:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary.v1
```

The source must be the `record-applied` application-boundary output with `report_application_status = "applied"`, `applied = true`, `ready_for_next_branch = true`, and `mutation_authority = "record-only"`.

## Outputs

The new schema is:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy.v1
```

The tool writes JSON and text artifacts. The JSON includes:

- schema, schema_version, generated_by
- source branch, recommendation, and `next_branch_if_ready`
- source application path and key source refs
- decision, reviewed_by, policy, reason
- `consumption_report_policy_status`
- `ready_for_next_branch`
- `mutation_authority = "none"`
- authority-disable booleans
- source changes, before/after evidence, checks, findings, denied claims, next queries, publication channels, and verification commands
- policy checks, interpretation rules, consumption scopes, denied inference rules, and negative fixtures
- output paths and agent guidance

## Policy Checks

The policy evaluates these gates:

- `source-schema`: supported source schema and version.
- `source-applied-application`: source is `record-applied`, applied, ready, and record-only.
- `source-refs-present`: source links consumption report, evaluator, policy, boundary, readiness, publication policy, and digests.
- `source-application-evidence-present`: source includes report application changes, before evidence, after evidence, after report digest/presence, summaries, denied claims, next queries, and local publication channels.
- `source-application-checks-pass`: all source application checks passed.
- `source-report-checks-pass`: source report checks have no failures.
- `source-authority-disabled`: all CI, GitHub, app, runtime, storage, deployment, public upload, auto-apply, and adapter authorities are disabled.
- `source-solid-webui-readonly`: source remains SolidJS inside `webui-dev/zig-webui` with read-only consumption.
- `source-local-publication-only`: source publication channels are local artifacts plus optional read-only SolidJS view only.
- `source-verification-evidence`: source carries every verification command required by the application-boundary milestone.
- `policy-catalogs-present`: interpretation, scope, denied-rule, and negative-fixture catalogs are present.
- `required-verification-commands`: approval records this policy milestone's required verification commands.
- `reviewer-decision`: rejection is preserved as blocked evidence.

## Interpretation Rules

Ready policy evidence may be used only to:

- cite reviewed local report application evidence,
- feed the next read-only report-consumption evaluator branch,
- help agents and the SolidJS workbench query bounded causal evidence,
- inform non-blocking CI advisory readers.

Ready policy evidence may not be used to infer:

- production health,
- deployment success,
- required status checks,
- merge blocking,
- GitHub mutation,
- workflow mutation,
- app runtime integration,
- live agent projection,
- raw payload capture,
- durable writes,
- NenDB writes or adapter execution,
- Cockroach work,
- public upload,
- auto-apply,
- mutation authority.

## Next Branch

If ready:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator
```

Recommendation:

```text
start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator
```

The evaluator branch will consume the policy artifact plus explicit local request/evidence files and classify whether report-consumption evidence is ready, advisory, or blocked for app-facing agents and the workbench.
