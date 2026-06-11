# App-Facing Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Policy

`causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy` interprets applied six-level application-boundary evidence as local, record-only policy evidence.

It consumes:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1
```

It emits:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1
```

## Usage

Approve a reviewed local application-boundary artifact:

```bash
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy -- \
  --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.json \
  approve \
  --reason "reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy" \
  --verified-command "bun run zigeffect:workbench:typecheck" \
  --verified-command "bun run zigeffect:workbench:test" \
  --verified-command "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --help" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Record a rejection:

```bash
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy -- \
  --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.json \
  reject \
  --reason "rejected app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy"
```

## Policy Boundary

`approve` emits `ready_for_next_branch=true` only when the source boundary is applied, ready, locally published only, has verified commands, includes reviewed application evidence, and preserves the denied authority posture.

`reject` emits blocked policy evidence and keeps `ready_for_next_branch=false`.

The policy is interpretation-only. It does not create required status checks, mutate workflows, call GitHub APIs, mutate app state, attach app runtime projections, capture raw payloads, write to durable storage, write to NenDB, execute NenDB adapters, publish artifacts publicly, deploy, prove production health, auto-apply, or grant mutation authority.

## Next Branch

Ready policy evidence prepares:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator
```
