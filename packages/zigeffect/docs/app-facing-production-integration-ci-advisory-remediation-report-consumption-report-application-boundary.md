# App-Facing CI Advisory Remediation Report Consumption Report Application Boundary

`causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary`
consumes a ready or advisory consumption-report artifact and emits guarded,
record-only evidence for reviewed local report application by agents, reviewers,
non-blocking CI advisory readers, and the SolidJS `webui-dev/zig-webui`
workbench.

It does not mutate apps, workbench state, GitHub, workflows, CI gates, storage,
runtime integrations, deployment state, NenDB, or a NenDB adapter. It does not
add Cockroach scope, public artifact upload, required status checks, production
health proof, alternate renderers, or auto-apply authority.

## Command

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary -- \
  --from-report <consumption-report.json> \
  plan|record-applied \
  --reason <reason> \
  [--report-after <report.txt|report.md|report.json>] \
  [--report-application-change <evidence>]... \
  [--before <evidence>]... \
  [--after <evidence>]... \
  [--verified-command <command>]... \
  [--by <actor>] \
  [--policy <policy>] \
  [--out-prefix <path-prefix>]
```

## Modes

`plan` records local report application intent only. It never sets
`applied=true`, never sets `ready_for_next_branch=true`, and always keeps
`mutation_authority="none"`.

`record-applied` sets `applied=true` only when all source, evidence, safety, and
verification checks pass. Otherwise it emits `report_application_status` as
`blocked`, keeps `applied=false`, and keeps `mutation_authority="none"`.

## Applied Gates

Applied records require:

- source schema
  `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report.v1`
- source status `ready` or `advisory`
- source `ready_for_next_branch=true`
- source `blocked_findings_count=0`
- source mutation authority `none`
- source app, GitHub, CI, runtime, durable, deployment, public upload, and
  adapter authority disabled
- SolidJS `webui-dev/zig-webui` read-only source posture
- source evaluator, policy, boundary, readiness, publication-policy, and digest
  refs
- local-only source publication channels
- report application change evidence
- before evidence
- after evidence
- safe after-report content
- all required post-application verification commands

## After-Report Safety

After-report content must include:

- `zigeffect`
- `causal`
- `read-only`
- `consumption`
- `report`
- `application`

It must not claim required checks, CI enforcement, workflow mutation, GitHub
mutation, app mutation, app runtime integration, live projection, raw prompt or
response capture, public artifact upload, deployment success, production health,
durable writes, NenDB writes, NenDB adapter execution, Cockroach scope,
alternate renderers, auto-apply, mutation authority, or secrets.

## Next Branch

Applied evidence hands off to:

`codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy`

That policy branch should interpret applied report application-boundary
evidence for bounded local consumption without adding mutation authority.
