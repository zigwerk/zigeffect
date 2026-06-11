# App-Facing CI Advisory Remediation Report Application Boundary

`causal-app-facing-production-integration-ci-advisory-remediation-report-application-boundary`
consumes a ready app-facing CI advisory remediation report artifact and emits
`zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-application-boundary.v1`.

The boundary turns a reviewed advisory report into local application evidence.
It has two successful states:

- `plan`: records intent only with `applied=false` and
  `mutation_authority="none"`;
- `record-applied`: records that a reviewed local publication/update happened
  elsewhere and only then sets `applied=true` with
  `mutation_authority="record-only"`.

The tool does not publish CI artifacts, write GitHub step summaries, post PR
comments, mutate GitHub workflows, create required status checks, call the
GitHub API, mutate app config or data, run a NenDB adapter, write NenDB, deploy
anything, prove production health, auto-apply remediation, or grant app runtime
integration authority.

## Plan Command

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-application-boundary -- \
  --from-report ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report.json \
  plan \
  --reason "app-facing advisory remediation report application boundary planned" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-application-boundary-plan
```

## Record-Applied Command

`record-applied` requires all review evidence. The after-report file must be
safe advisory content and must not claim required status checks, GitHub/app
mutation, NenDB writes, adapter execution, deployment mutation, production
health, or auto-apply authority.

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-application-boundary -- \
  --from-report ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report.json \
  record-applied \
  --reason "reviewed app-facing advisory remediation report application boundary" \
  --report-after ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-after.txt \
  --publication-change "reviewed local advisory remediation report publication boundary" \
  --before "before local advisory report application boundary evidence" \
  --after "after local advisory report application boundary evidence" \
  --verified-command "bun run zigeffect:workbench:typecheck" \
  --verified-command "bun run zigeffect:workbench:test" \
  --verified-command "zig build causal-app-facing-production-integration-ci-advisory-remediation-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

## Negative Path

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-application-boundary -- \
  --from-report ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report.json \
  record-applied \
  --reason "negative missing evidence path" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-application-boundary-negative
```

The negative path stays blocked until publication-change, before, after,
report-after, safe report-after content, and every required verification
command are present.

## Checks

- source schema is
  `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report.v1`;
- source report status is `ready`;
- source report is advisory-only, read-only, SolidJS, and
  `webui-dev/zig-webui` scoped;
- source bridge records include `ci-advisory-remediation-report-bridge`;
- source checks have no failures;
- source verification commands are recorded and verified;
- plan mode never claims applied state;
- record-applied requires publication-change, before, after, report-after, safe
  report-after content, and full verification evidence.

## Next Branch

Applied records hand off to:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy
```

That branch should define how reviewed advisory report evidence may be surfaced
or consumed without turning it into a required status check, workflow mutation,
GitHub API mutation, app mutation, NenDB write, adapter execution, deployment
mutation, or production-health claim.
