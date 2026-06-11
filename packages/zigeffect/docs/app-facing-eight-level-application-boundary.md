# App-Facing Eight-Level Application Boundary

`causal-app-facing-eight-level-application-boundary` records planned or reviewed local application-boundary evidence for the eight-level app-facing evaluation report.

The artifact schema remains fully expanded. The physical tool, build step, executable, docs path, and follow-up branch use short aliases because the next fully expanded names exceed safe filesystem and branch-name ergonomics.

## Consumes

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1
```

## Emits

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1
```

## Aliases

- Tool file: `packages/zigeffect/tools/causal_app_facing_eight_level_application_boundary.zig`
- Build step: `causal-app-facing-eight-level-application-boundary`
- Executable: `zigeffect-causal-app-facing-eight-level-application-boundary`
- Docs: `packages/zigeffect/docs/app-facing-eight-level-application-boundary.md`
- Current branch: `codex/zigeffect-causal-app-facing-eight-level-application-boundary`
- Next branch: `codex/zigeffect-causal-app-facing-eight-level-policy`

## Usage

Plan a local application-boundary record:

```sh
cd packages/zigeffect
zig build causal-app-facing-eight-level-application-boundary -- \
  --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.json \
  plan \
  --reason "planned app-facing eight-level application boundary"
```

Record reviewed local application-boundary evidence:

```sh
cd packages/zigeffect
zig build causal-app-facing-eight-level-application-boundary -- \
  --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.json \
  record-applied \
  --reason "reviewed app-facing eight-level application boundary" \
  --after-report test/fixtures/app-facing-eight-level-application-boundary-after-safe.txt \
  --application-change "reviewed local eight-level application boundary for agents reviewers CI advisory readers and SolidJS webui" \
  --before "before local eight-level application boundary evidence" \
  --after "after local eight-level application boundary evidence" \
  --verified-command "bun run zigeffect:workbench:typecheck" \
  --verified-command "bun run zigeffect:workbench:test" \
  --verified-command "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --help" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The tool also accepts the inherited long `--evaluation-report-...-after` and `--evaluation-report-...-application-change` flags for compatibility, but new commands should use `--after-report` and `--application-change`.

## Gates

- `plan` records local intent only, keeps `applied=false`, and never marks the next branch ready.
- `record-applied` sets `applied=true` only when the source report is ready or advisory, blocked finding count is zero, source mutation authority is `none`, and source checks pass.
- Reviewed application-change evidence, before evidence, after evidence, a safe bounded after-report, and every required verification command must be present.
- Source publication channels must remain local-only and non-mutating.
- SolidJS inside `webui-dev/zig-webui` remains read-only consumption, not app runtime integration.

## Non-Authority

This boundary does not enable CI enforcement, required status checks, workflow mutation, GitHub API mutation, step-summary writes, pull request comments, app mutation, app config writes, app data writes, app runtime integration, live agent projection, raw payload capture, deployment mutation, production health proof, durable writes, NenDB writes, NenDB adapter execution, Cockroach scope, public artifact upload, hosted dashboards, auto-apply, registry mutation, or mutation authority.

## Handoff

Applied evidence hands off to:

```text
codex/zigeffect-causal-app-facing-eight-level-policy
```

Planned evidence is preparatory. Blocked evidence is a stop sign.
