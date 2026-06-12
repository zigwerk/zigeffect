# App-Facing Thirteen-Level Evaluator

`causal-app-facing-thirteen-level-evaluator` consumes approved thirteen-level
policy evidence plus bounded local request/support files and emits read-only
evaluator artifacts for the fourteen-level report branch.

This tool is advisory. It does not mutate CI, GitHub, app runtime, app data,
storage, deployment state, public artifact hosts, dashboards, registry state, or
production telemetry.

## Tool

- Tool file: `packages/zigeffect/tools/causal_app_facing_thirteen_level_evaluator.zig`
- Build step: `causal-app-facing-thirteen-level-evaluator`
- Executable: `zigeffect-causal-app-facing-thirteen-level-evaluator`
- Current branch: `codex/zigeffect-causal-app-facing-thirteen-level-evaluator`
- Next branch: `codex/zigeffect-causal-app-facing-fourteen-level-report`

## Schemas

Consumes:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1
```

Emits:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1
```

## Ready Artifact

```bash
zig build causal-app-facing-thirteen-level-evaluator -- \
  --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-policy.json \
  evaluate \
  --reason "reviewed app-facing thirteen-level evaluator" \
  --request ../../.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-evaluator-request.json \
  --evidence ../../.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-evaluator-support.txt \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-evaluator
```

Ready output has `evaluation_status=ready` and
`ready_for_next_branch=true`. It may feed the fourteen-level report branch.

## Advisory Artifact

```bash
zig build causal-app-facing-thirteen-level-evaluator -- \
  --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-policy.json \
  evaluate \
  --reason "advisory app-facing thirteen-level evaluator missing support" \
  --request ../../.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-evaluator-request.json \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-evaluator-advisory
```

Missing support evidence is advisory. The artifact is still useful for review,
but the missing support should be visible before handoff.

## Blocked Artifact

```bash
zig build causal-app-facing-thirteen-level-evaluator -- \
  --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-policy-reject.json \
  evaluate \
  --reason "blocked app-facing thirteen-level evaluator source" \
  --request ../../.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-evaluator-request.json \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-evaluator-blocked
```

Blocked output is a stop sign. Repair the source policy or unsafe request
evidence before continuing.

## Input Rules

Request and support evidence must be `.json` or `.txt` files under
`.zig-cache/causal-artifacts/`. The evaluator denies secret-shaped strings,
raw prompt/response fields, runtime integration flags, mutation authority,
CI enforcement flags, public upload claims, production health claims,
auto-apply claims, React renderer drift, Cockroach scope, NenDB writes, and
NenDB adapter execution.

SolidJS inside `webui-dev/zig-webui` is the expected read-only workbench
direction. NenDB remains a future adapter boundary only; this tool does not
write to NenDB or execute a NenDB adapter.

## Required Source Evidence

The source policy must be approved, ready for handoff, and non-mutating. It
must carry:

- applied thirteen-level application-boundary evidence
- ready thirteen-level report evidence
- thirteen-level digest and application-change evidence
- ready twelve-level evaluator and policy evidence
- twelve-level application-boundary/report evidence
- lower eleven-, ten-, nine-, eight-level, and inherited lineage
- interpretation rules, consumption scopes, denied claims, negative fixtures,
  and verification command evidence

The emitted artifact preserves those ids and summaries so agents can reason
about the chain without claiming production deployment, runtime integration, or
mutation authority.
