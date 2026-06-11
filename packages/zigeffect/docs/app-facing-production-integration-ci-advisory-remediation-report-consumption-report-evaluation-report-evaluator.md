# App-Facing CI Advisory Remediation Report Consumption Report Evaluation Report Evaluator

`causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator` consumes a ready consumption-report evaluation-report policy artifact plus explicit local request/evidence files and emits a read-only evaluator artifact for the next local evaluation-report handoff.

## Command

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator -- \
  --from-policy <consumption-report-evaluation-report-policy.json> \
  evaluate \
  --reason <reason> \
  --request <path>... \
  [--evidence <path>]... \
  [--by <actor>] \
  [--policy <policy>] \
  [--out-prefix <path-prefix>]
```

## Source Gate

The source policy must use schema `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy.v1`, be approved, be ready for the next branch, and preserve `mutation_authority = none`.

The evaluator also requires evaluation-report application-boundary refs, applied evaluation-report application status, before/after evidence, after digest evidence, inherited consumption-report refs, source report application evidence, request/support/signal summaries, advisory and blocked findings, source denied claims, denied application claims, next queries, local publication channels, policy checks, interpretation rules, consumption scopes, negative fixtures, and verified command evidence.

## Input Gate

Request and support evidence files must be `.json` or `.txt` files under `.zig-cache/causal-artifacts/`. The evaluator blocks secret-shaped inputs, raw prompt/response capture, raw payload capture, CI enforcement, required status checks, workflow mutation, GitHub mutation, app mutation, app runtime integration, live projection, deployment claims, production health claims, public upload, auto-apply, NenDB writes, NenDB adapter execution, Cockroach scope, and non-SolidJS renderer claims.

## Statuses

- `ready`: source policy is valid, request files are safe, support evidence is present, and redaction posture is bounded.
- `advisory-findings`: source policy and request files are safe, but support evidence is missing.
- `blocked`: source policy or any request/evidence file crosses a denied boundary.

## Handoff

Ready or advisory evaluator artifacts hand off to:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report
```

The evaluator is still local and advisory. It does not publish artifacts, mutate app state, enforce CI, execute adapters, write to NenDB, or claim production health.
