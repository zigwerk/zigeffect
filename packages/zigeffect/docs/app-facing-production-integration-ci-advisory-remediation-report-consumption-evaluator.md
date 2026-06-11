# App-Facing CI Advisory Remediation Report Consumption Evaluator

`causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator`
consumes a ready app-facing advisory remediation report consumption-policy
artifact plus explicit local request and evidence files. It emits
`zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator.v1`.

The evaluator is a read-only gate for agent and workbench understanding. It
classifies bounded requests for agents, reviewers, non-blocking CI advisory
readers, and the local SolidJS `webui-dev/zig-webui` workbench. It returns
`ready`, `advisory-findings`, or `blocked` without creating app runtime,
storage, deployment, CI, GitHub, NenDB, adapter, or mutation authority.

It does not create required status checks, block merges, mutate workflows, call
the GitHub API, upload artifacts, write GitHub summaries, post pull request
comments, mutate app config or data, wire the app runtime, enable live agent
projection, capture raw prompts or responses, write durable storage, write
NenDB, execute a NenDB adapter, add Cockroach scope, deploy anything, prove
production health, auto-apply remediation, expose public artifacts, change the
renderer away from SolidJS, or grant mutation authority.

## Ready Command

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator -- \
  --from-policy ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-policy.json \
  evaluate \
  --reason "reviewed app-facing advisory remediation report consumption evaluator" \
  --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-request.json \
  --evidence ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-support.txt
```

Without `--out-prefix`, the tool writes sibling `.json` and `.txt` evaluator
artifacts beside the source consumption-policy artifact.

## Advisory Command

Missing optional support evidence is advisory when the source policy and request
are safe.

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator -- \
  --from-policy ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-policy.json \
  evaluate \
  --reason "advisory app-facing consumption evaluator missing support evidence" \
  --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-request.json \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-evaluator-advisory
```

## Blocked Command

Unsafe request or evidence content produces a blocked artifact.

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator -- \
  --from-policy ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-policy.json \
  evaluate \
  --reason "blocked app-facing consumption evaluator unsafe request" \
  --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-request-unsafe.json \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-evaluator-blocked
```

## Source Contract

The source artifact must use schema
`zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-policy.v1`,
have `decision="approve"`, have `consumption_policy_status="ready"`, set
`ready_for_next_branch=true`, and keep `mutation_authority="none"`.

The source must carry:

- source consumption-boundary status `applied`;
- source consumption-readiness status `ready`;
- source publication-policy refs;
- after-report and consumer-after digest refs;
- passing policy checks;
- interpretation rules;
- read-only consumption scopes;
- denied inference rules;
- denied boundary claims and blocked claims;
- negative fixtures;
- required and verified command evidence;
- SolidJS `webui-dev/zig-webui` read-only scope.

The source must preserve disabled authority for CI enforcement, required status
checks, workflow mutation, GitHub mutation, app mutation, app runtime
integration, live agent projection, raw payload capture, durable writes, NenDB
writes, NenDB adapter execution, Cockroach work, deployment mutation, and
production telemetry ingestion.

## Request And Evidence Classes

Accepted files are bounded local files under `.zig-cache/causal-artifacts/`.

- `request_json`: JSON request for an agent, reviewer, CI advisory reader,
  workbench, or evaluator consumer.
- `request_text`: text request for one of those consumers.
- `policy_json`: the source policy file when supplied as support evidence.
- `causal_json`: a zigeffect causal JSON artifact.
- `causal_text`: a zigeffect causal text artifact.
- `workbench_text`: local SolidJS or `webui-dev/zig-webui` support evidence.
- `denied`: unsupported paths, unsupported extensions, or unsafe content.

At least one safe request is required. Support evidence is optional, but a safe
request without support evidence produces `advisory-findings`.

## Statuses

`ready` means the source policy is ready, all supplied files are bounded and
safe, at least one request exists, support evidence exists, denied claims are
present, and redaction posture is bounded.

`advisory-findings` means the source policy and supplied files are safe, but a
non-blocking expected signal is missing, such as support evidence.

`blocked` means the source is invalid, no safe request exists, a path is
unsupported, or content claims secrets, raw prompt/response/payload capture,
mutation, CI enforcement, GitHub mutation, app runtime integration, live
projection, durable or NenDB writes, NenDB adapter execution, Cockroach scope,
deployment, production health, alternate renderers, public artifact upload, or
auto-apply behavior.

## Output

The JSON artifact includes source refs, evaluation status, request and evidence
file analysis, sha256 digests, detected schemas and roles, redaction posture,
checks, signal evaluations, findings, source rule ids, source scope ids, denied
claims, next queries, disabled authority fields, and next-branch guidance.

The text artifact mirrors the same evidence for reviewers.

## Handoff

Ready and advisory evaluator artifacts hand off to:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report
```

That branch should render local human/agent consumption reports from evaluator
artifacts. It must still avoid mutation authority, runtime wiring, required CI,
GitHub mutation, app mutation, NenDB writes, NenDB adapter execution, Cockroach
scope, deployment, production health claims, and alternate renderer scope.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_evaluator.zig
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_policy.zig
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
