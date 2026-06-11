# App-Facing Production Integration CI Advisory Remediation Report

`causal-app-facing-production-integration-ci-advisory-remediation-report`
consumes a ready app-facing SolidJS read-only preview JSON artifact and emits
`zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report.v1`.

It is an advisory CI remediation report for agents and reviewers. It preserves
the app-facing bridge records, CI advisory refs, blocked claims, checks,
verification commands, and next-branch handoff while keeping all mutation and
enforcement authority disabled.

It does not create a required status check, mutate a GitHub workflow, call the
GitHub API, upload CI artifacts, write a step summary, comment on a pull
request, mutate app config or data, execute a NenDB adapter, write NenDB, deploy
anything, prove production health, prove a mutation, auto-apply remediation, or
set `applied=true`.

## Command

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report -- \
  --from-preview ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-solid-webui-readonly-preview.json \
  approve \
  --reason "ready app-facing SolidJS read-only preview reviewed for CI advisory remediation report" \
  --verified-command "bun run zigeffect:workbench:typecheck" \
  --verified-command "bun run zigeffect:workbench:test" \
  --verified-command "zig build causal-app-facing-production-integration-solid-webui-readonly-preview" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The default output paths replace `-solid-webui-readonly-preview.json` with
`-ci-advisory-remediation-report.json` and write a matching `.txt` report.

## Negative Path

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report -- \
  --from-preview ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-solid-webui-readonly-preview.json \
  reject \
  --reason "negative CI advisory remediation report path" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-production-integration-ci-advisory-remediation-report-negative
```

Rejected reports keep `applied=false` and `mutation_authority="none"`, set
`ready_for_next_branch=false`, and retain the source refs for debugging.

## Readiness Checks

- source schema is
  `zigeffect.causal.app-facing-production-integration-solid-webui-readonly-preview.v1`;
- source status is `ready`;
- source decision is `approve`;
- source authority is disabled;
- bridge records include `ci-advisory-remediation-report-bridge`;
- the CI advisory bridge status is `advisory-only`;
- CI enforcement, required status checks, workflow mutation, GitHub API
  mutation, report publication, step-summary writes, PR comments, app mutation,
  NenDB writes, NenDB adapter execution, durable writes, deployment mutation,
  production-health claims, mutation-proof claims, auto-apply, and `applied=true`
  remain disabled;
- required verification command evidence is present.

## Workbench

The SolidJS workbench can load the report with:

```text
?sample=app-ci-advisory
```

The sample lives at:

```text
packages/zigeffect/workbench/public/sample-app-facing-ci-advisory-remediation-report.json
```

The report reuses the app-facing preview view as a read-only inspection surface.
The mode is `ci-advisory-remediation-report`, so agents and humans can
distinguish it from the earlier SolidJS preview artifact.

## Next Branch

Ready artifacts hand off to:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-application-boundary
```

That next branch should verify a reviewed application boundary for interpreting
or publishing the advisory report. It still must not grant CI enforcement,
GitHub mutation, app mutation, NenDB writes, or production health authority.
