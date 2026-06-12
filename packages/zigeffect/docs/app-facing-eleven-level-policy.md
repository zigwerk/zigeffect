# App-Facing Eleven-Level Policy

`causal-app-facing-eleven-level-policy` interprets applied eleven-level
application-boundary evidence for agents, reviewers, non-blocking CI advisory
readers, and the local SolidJS `webui-dev/zig-webui` workbench.

The artifact schema remains fully expanded. The physical tool, build step,
executable, docs path, and next branch use short aliases so future agents can
continue the ladder without unsafe filenames or branch names.

## Consumes

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1
```

## Emits

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1
```

## Aliases

- Tool file: `packages/zigeffect/tools/causal_app_facing_eleven_level_policy.zig`
- Build step: `causal-app-facing-eleven-level-policy`
- Executable: `zigeffect-causal-app-facing-eleven-level-policy`
- Docs: `packages/zigeffect/docs/app-facing-eleven-level-policy.md`
- Current branch: `codex/zigeffect-causal-app-facing-eleven-level-policy`
- Next branch: `codex/zigeffect-causal-app-facing-eleven-level-evaluator`

## Usage

Approve applied boundary evidence:

```sh
cd packages/zigeffect
zig build causal-app-facing-eleven-level-policy -- \
  --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-application-boundary.json \
  approve \
  --reason "reviewed app-facing eleven-level policy" \
  --verified-command "bun run zigeffect:workbench:typecheck" \
  --verified-command "bun run zigeffect:workbench:test" \
  --verified-command "zig build causal-app-facing-eleven-level-application-boundary -- --help" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Reject boundary evidence explicitly:

```sh
cd packages/zigeffect
zig build causal-app-facing-eleven-level-policy -- \
  --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-application-boundary.json \
  reject \
  --reason "rejected app-facing eleven-level policy"
```

## Gates

- `approve` emits ready policy evidence only when the source boundary is
  `record-applied`, `applied=true`, `ready_for_next_branch=true`, and
  `mutation_authority=record-only`.
- Source eleven-level report refs must be present and ready.
- Source ten-level policy, application-boundary, and report refs must be present
  and ready.
- Inherited source nine-level policy, application-boundary, and report refs must
  be present and ready.
- Inherited lower-level policy refs must be present, approved, and ready.
- Source application checks, source report checks, denied claims, negative
  fixtures, boundary rules, publication channels, and verification evidence must
  be present.
- The policy invocation must record every required verification command.
- `reject` emits blocked policy evidence while preserving interpretation and
  denied-inference guidance.
- Planned, blocked, incomplete, unsafe, or authority-drift source artifacts also
  emit blocked policy evidence.

## Non-Authority

This policy does not enable CI enforcement, required status checks, workflow
mutation, GitHub API mutation, step-summary writes, pull request comments, app
mutation, app config writes, app data writes, app runtime integration, live
agent projection, raw payload capture, deployment mutation, production health
proof, durable writes, NenDB writes, NenDB adapter execution, Cockroach scope,
public artifact upload, hosted dashboards, auto-apply, registry mutation, or
mutation authority.

## Handoff

Approved evidence hands off to:

```text
codex/zigeffect-causal-app-facing-eleven-level-evaluator
```

Rejected or blocked evidence is review material only.
