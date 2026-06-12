# App-Facing Ten-Level Application Boundary

`causal-app-facing-ten-level-application-boundary` records planned or reviewed
local application-boundary evidence for the ten-level app-facing report.

The artifact schema remains fully expanded. The physical tool, build step,
executable, docs path, fixture path, and follow-up branch use short aliases
because expanded lineage names are no longer ergonomic for filesystems or
branch handling.

## Consumes

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1
```

## Emits

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1
```

## Aliases

- Tool file: `packages/zigeffect/tools/causal_app_facing_ten_level_application_boundary.zig`
- Build step: `causal-app-facing-ten-level-application-boundary`
- Executable: `zigeffect-causal-app-facing-ten-level-application-boundary`
- Fixture: `packages/zigeffect/test/fixtures/app-facing-ten-level-application-boundary-after-safe.txt`
- Current branch: `codex/zigeffect-causal-app-facing-ten-level-application-boundary`
- Next branch: `codex/zigeffect-causal-app-facing-ten-level-policy`

## Usage

Plan a local application-boundary record:

```sh
cd packages/zigeffect
zig build causal-app-facing-ten-level-application-boundary -- \
  --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-report.json \
  plan \
  --reason "planned app-facing ten-level application boundary"
```

Record reviewed local application-boundary evidence:

```sh
cd packages/zigeffect
zig build causal-app-facing-ten-level-application-boundary -- \
  --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-report.json \
  record-applied \
  --reason "reviewed app-facing ten-level application boundary" \
  --after-report test/fixtures/app-facing-ten-level-application-boundary-after-safe.txt \
  --application-change "reviewed local ten-level application boundary for agents reviewers CI advisory readers and SolidJS webui" \
  --before "before local ten-level application boundary evidence" \
  --after "after local ten-level application boundary evidence" \
  --verified-command "bun run zigeffect:workbench:typecheck" \
  --verified-command "bun run zigeffect:workbench:test" \
  --verified-command "zig build causal-app-facing-ten-level-report -- --help" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

## Gates

- `plan` records local intent only, keeps `applied=false`, and never marks the
  next branch ready.
- `record-applied` sets `applied=true` only when the source report is ready or
  advisory, blocked finding count is zero, source mutation authority is `none`,
  and source checks pass.
- Reviewed application-change evidence, before evidence, after evidence, a safe
  bounded after-report, and every required verification command must be present.
- Source nine-level policy, application-boundary, and report lineage is carried
  forward for agents that need to reason about why the ten-level report exists.
- Source publication channels must remain local-only and non-mutating.
- SolidJS inside `webui-dev/zig-webui` remains read-only consumption, not app
  runtime integration.

## Non-Authority

This boundary does not enable CI enforcement, required status checks, workflow
mutation, GitHub API mutation, step-summary writes, pull request comments, app
mutation, app config writes, app data writes, app runtime integration, live
agent projection, raw payload capture, deployment mutation, production health
proof, durable writes, NenDB writes, NenDB adapter execution, Cockroach scope,
public artifact upload, hosted dashboards, auto-apply, registry mutation, or
mutation authority.

## Handoff

Applied evidence hands off to:

```text
codex/zigeffect-causal-app-facing-ten-level-policy
```

Planned evidence is preparatory. Blocked evidence is a stop sign.
