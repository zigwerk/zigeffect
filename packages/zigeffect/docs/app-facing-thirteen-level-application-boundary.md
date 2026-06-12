# App-Facing Thirteen-Level Application Boundary

`causal-app-facing-thirteen-level-application-boundary` records planned or
reviewed local application-boundary evidence for the thirteen-level app-facing
report.

The expanded schema remains the durable contract. The physical tool, build
step, executable, docs path, fixture path, and follow-up branch use short
aliases because the full lineage is no longer ergonomic for filesystems or
branch names.

## Consumes

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1
```

## Emits

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1
```

## Aliases

- Tool file: `packages/zigeffect/tools/causal_app_facing_thirteen_level_application_boundary.zig`
- Build step: `causal-app-facing-thirteen-level-application-boundary`
- Executable: `zigeffect-causal-app-facing-thirteen-level-application-boundary`
- Fixture: `packages/zigeffect/test/fixtures/app-facing-thirteen-level-application-boundary-after-safe.txt`
- Current branch: `codex/zigeffect-causal-app-facing-thirteen-level-application-boundary`
- Next branch: `codex/zigeffect-causal-app-facing-thirteen-level-policy`

## Usage

Plan a local application-boundary record:

```sh
cd packages/zigeffect
zig build causal-app-facing-thirteen-level-application-boundary -- \
  --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-report.json \
  plan \
  --reason "planned app-facing thirteen-level application boundary"
```

Record reviewed local application-boundary evidence:

```sh
cd packages/zigeffect
zig build causal-app-facing-thirteen-level-application-boundary -- \
  --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-report.json \
  record-applied \
  --reason "reviewed app-facing thirteen-level application boundary" \
  --after-report test/fixtures/app-facing-thirteen-level-application-boundary-after-safe.txt \
  --application-change "reviewed local thirteen-level application boundary for agents reviewers CI advisory readers and SolidJS webui" \
  --before "before local thirteen-level application boundary evidence" \
  --after "after local thirteen-level application boundary evidence" \
  --verified-command "bun run zigeffect:workbench:typecheck" \
  --verified-command "bun run zigeffect:workbench:test" \
  --verified-command "zig build causal-app-facing-thirteen-level-report -- --help" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Record a blocked source probe:

```sh
cd packages/zigeffect
zig build causal-app-facing-thirteen-level-application-boundary -- \
  --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-report-blocked.json \
  record-applied \
  --reason "blocked app-facing thirteen-level application boundary source" \
  --after-report test/fixtures/app-facing-thirteen-level-application-boundary-after-safe.txt \
  --application-change "reviewed local thirteen-level blocked source boundary probe" \
  --before "before local thirteen-level blocked source evidence" \
  --after "after local thirteen-level blocked source evidence" \
  --verified-command "bun run zigeffect:workbench:typecheck" \
  --verified-command "bun run zigeffect:workbench:test" \
  --verified-command "zig build causal-app-facing-thirteen-level-report -- --help" \
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
- Direct source thirteen-level report schema and status are recorded.
- Direct source twelve-level evaluator, policy, application-boundary, report,
  after digest, after-present flag, and application changes are carried forward.
- Direct source eleven-level, ten-level, and nine-level policy,
  application-boundary, and report lineage remains available for deeper causal
  trace inspection.
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
codex/zigeffect-causal-app-facing-thirteen-level-policy
```

Planned evidence is preparatory. Blocked evidence is a stop sign.
