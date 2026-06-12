# App-Facing Ten-Level Evaluator

`causal-app-facing-ten-level-evaluator` consumes approved ten-level policy
evidence plus bounded local request and support evidence, then emits read-only
evaluator artifacts for agents, reviewers, non-blocking CI advisory readers, and
the local SolidJS `webui-dev/zig-webui` workbench.

The artifact schema remains fully expanded. The physical tool, build step,
executable, docs path, and branch use short aliases because the expanded lineage
is no longer safe for filenames or branch ergonomics.

## Consumes

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1
```

## Emits

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1
```

## Aliases

- Build step: `causal-app-facing-ten-level-evaluator`
- Executable: `zigeffect-causal-app-facing-ten-level-evaluator`
- Docs: `packages/zigeffect/docs/app-facing-ten-level-evaluator.md`
- Current branch: `codex/zigeffect-causal-app-facing-ten-level-evaluator`
- Next branch: `codex/zigeffect-causal-app-facing-eleven-level-report`

## Usage

```bash
zig build causal-app-facing-ten-level-evaluator -- \
  --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-policy.json \
  evaluate \
  --reason "reviewed app-facing ten-level evaluator" \
  --request ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-evaluator-request.json \
  --evidence ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-evaluator-support.txt \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-evaluator
```

Omitting `--evidence` keeps the evaluator read-only and emits
`advisory-findings` when the source policy and request are otherwise safe.
Rejected, blocked, or unsafe source evidence emits `blocked`.

## Ready Gates

Ready output requires:

- the source policy schema and version match the ten-level policy producer;
- the source policy decision is `approve`;
- the source policy status is `ready` and `ready_for_next_branch=true`;
- source aliases identify the ten-level policy, application-boundary, and report
  artifacts;
- nine-level policy, application-boundary, and report lineage is present;
- inherited source evidence, denied claims, negative fixtures, publication
  posture, and verification commands are present;
- at least one safe bounded request file is supplied;
- support evidence is present and bounded;
- all authority flags remain disabled.

## Denied Authority

This tool does not create required status checks, mutate workflows, call GitHub
APIs, write PR comments, upload public artifacts, mutate app config or app data,
integrate runtime projections, capture raw prompts or payloads, write durable
storage, write NenDB, execute NenDB adapters, add Cockroach scope, deploy, prove
production health, create hosted dashboards, auto-apply, mutate registries, or
grant mutation authority.

## Handoff

Ready or advisory ten-level evaluator artifacts may start:

```text
codex/zigeffect-causal-app-facing-eleven-level-report
```

Blocked evaluator artifacts are stop signs. They remain useful evidence for
agents and reviewers, but they are not permission to continue the report chain.
