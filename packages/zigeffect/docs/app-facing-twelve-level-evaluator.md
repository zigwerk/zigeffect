# App-Facing Twelve-Level Evaluator

`causal-app-facing-twelve-level-evaluator` consumes approved twelve-level
policy evidence plus bounded local request and support evidence, then emits
read-only evaluator artifacts for agents, reviewers, non-blocking CI advisory
readers, and the local SolidJS `webui-dev/zig-webui` workbench.

The artifact schema stays fully expanded. The physical tool, build step,
executable, docs path, and branch use short aliases because the expanded
lineage is too long for practical filenames and branch names.

## Consumes

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1
```

## Emits

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1
```

## Tool Surface

- Tool file: `packages/zigeffect/tools/causal_app_facing_twelve_level_evaluator.zig`
- Build step: `causal-app-facing-twelve-level-evaluator`
- Executable: `zigeffect-causal-app-facing-twelve-level-evaluator`
- Current branch: `codex/zigeffect-causal-app-facing-twelve-level-evaluator`
- Next branch: `codex/zigeffect-causal-app-facing-thirteen-level-report`

## Ready Artifact

```bash
zig build causal-app-facing-twelve-level-evaluator -- \
  --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-policy.json \
  evaluate \
  --reason "reviewed app-facing twelve-level evaluator" \
  --request ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator-request.json \
  --evidence ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator-support.txt \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator
```

Ready output requires an approved twelve-level policy, direct twelve-level
application-boundary/report/digest evidence, preserved eleven/ten/nine
lineage, a bounded request file, bounded support evidence, read-only SolidJS
webui posture, and no authority drift.

## Advisory Artifact

```bash
zig build causal-app-facing-twelve-level-evaluator -- \
  --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-policy.json \
  evaluate \
  --reason "advisory app-facing twelve-level evaluator missing support" \
  --request ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator-request.json \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator-advisory
```

Missing support evidence is advisory rather than blocking. The artifact can
still help review, but agents should collect support evidence before treating it
as the preferred thirteen-level report input.

## Blocked Artifact

```bash
zig build causal-app-facing-twelve-level-evaluator -- \
  --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-policy-reject.json \
  evaluate \
  --reason "blocked app-facing twelve-level evaluator source" \
  --request ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator-request.json \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator-blocked
```

Blocked output is a stop sign. Repair the rejected or unsafe source policy, or
the unsafe request/evidence file, before continuing the ladder.

## Input Boundary

Request and support inputs must be `.json` or `.txt` files under
`.zig-cache/causal-artifacts/`. The evaluator denies unbounded paths and
secret-shaped or mutation-shaped content, including raw prompt/response fields,
provider tokens, private keys, authorization headers, CI enforcement flags,
GitHub mutation flags, app/runtime mutation flags, Durable or NenDB write
flags, adapter execution flags, public upload claims, production-health claims,
Cockroach scope, React renderer drift, and auto-apply claims.

## Denied Authority

This evaluator cannot prove or perform:

- required status checks or merge blocking
- CI workflow mutation or GitHub API mutation
- app config writes, app data writes, or runtime integration
- live agent projection or raw payload capture
- Durable, D1, R2, NenDB, or Cockroach writes
- NenDB adapter execution
- public artifact upload or hosted dashboards
- deployment success or production health
- registry mutation, auto-apply, or mutation authority

## Handoff

Ready and advisory twelve-level evaluator artifacts may start
`codex/zigeffect-causal-app-facing-thirteen-level-report`. The thirteen-level
report must still preserve the evaluator outcome and must not infer mutation
authority from readiness.
