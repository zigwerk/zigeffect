# App-Facing Eight-Level Policy

`causal-app-facing-eight-level-policy` interprets applied eight-level application-boundary evidence for agents, reviewers, non-blocking CI advisory readers, and the local SolidJS `webui-dev/zig-webui` workbench.

The artifact schema remains fully expanded. The physical tool, build step, executable, docs path, and next branch use short aliases because the fully expanded lineage is no longer safe for filenames or branch ergonomics.

## Consumes

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1
```

## Emits

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1
```

## Aliases

- Tool file: `packages/zigeffect/tools/causal_app_facing_eight_level_policy.zig`
- Build step: `causal-app-facing-eight-level-policy`
- Executable: `zigeffect-causal-app-facing-eight-level-policy`
- Docs: `packages/zigeffect/docs/app-facing-eight-level-policy.md`
- Current branch: `codex/zigeffect-causal-app-facing-eight-level-policy`
- Next branch: `codex/zigeffect-causal-app-facing-eight-level-evaluator`

## Usage

Approve applied boundary evidence:

```sh
cd packages/zigeffect
zig build causal-app-facing-eight-level-policy -- \
  --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-eight-level-application-boundary.json \
  approve \
  --reason "reviewed app-facing eight-level policy" \
  --verified-command "bun run zigeffect:workbench:typecheck" \
  --verified-command "bun run zigeffect:workbench:test" \
  --verified-command "zig build causal-app-facing-eight-level-application-boundary -- --help" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Reject boundary evidence explicitly:

```sh
cd packages/zigeffect
zig build causal-app-facing-eight-level-policy -- \
  --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-eight-level-application-boundary.json \
  reject \
  --reason "rejected app-facing eight-level policy"
```

## Gates

- `approve` emits ready policy evidence only when the source boundary is `record-applied`, `applied=true`, `ready_for_next_branch=true`, and `mutation_authority=record-only`.
- Source application checks, source report checks, denied claims, negative fixtures, boundary rules, publication channels, and verification evidence must be present.
- The policy invocation must record every required verification command.
- `reject` emits blocked policy evidence while preserving interpretation and denied-inference guidance.
- Planned, blocked, incomplete, unsafe, or authority-drift source artifacts also emit blocked policy evidence.

## Non-Authority

This policy does not enable CI enforcement, required status checks, workflow mutation, GitHub API mutation, step-summary writes, pull request comments, app mutation, app config writes, app data writes, app runtime integration, live agent projection, raw payload capture, deployment mutation, production health proof, durable writes, NenDB writes, NenDB adapter execution, Cockroach scope, public artifact upload, hosted dashboards, auto-apply, registry mutation, or mutation authority.

## Handoff

Approved evidence hands off to:

```text
codex/zigeffect-causal-app-facing-eight-level-evaluator
```

Rejected or blocked evidence is review material only.
