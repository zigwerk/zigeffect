# App-Facing CI Advisory Remediation Report Consumption Evaluator Design

## Summary

Add a guarded read-only evaluator for app-facing CI advisory remediation report
consumption requests.

The producer is:

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator -- \
  --from-policy <consumption-policy.json> \
  evaluate \
  --reason <reason> \
  --request <request.json|request.txt>... \
  [--evidence <evidence.json|evidence.txt>]... \
  [--by <actor>] \
  [--policy <policy>] \
  [--out-prefix <path-prefix>]
```

It emits:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator.v1
```

The evaluator consumes ready
`zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-policy.v1`
artifacts and classifies explicit read-only consumption requests for agents,
reviewers, non-blocking CI advisory readers, and the SolidJS
`webui-dev/zig-webui` workbench. It returns `ready`, `advisory-findings`, or
`blocked`, while keeping every mutation, runtime, storage, deployment, CI, and
adapter authority disabled.

## Goals

- Validate a ready consumption-policy source before evaluating any request.
- Classify bounded request files and optional support evidence.
- Emit source ids, policy rule ids, consumption scope ids, denied claims,
  redaction posture, findings, signal evaluations, and next-query guidance.
- Treat missing optional support evidence as advisory, not blocked.
- Treat unsafe paths, secret-shaped content, raw payload capture, mutation
  claims, runtime integration claims, NenDB writes, adapter execution, Cockroach
  scope, deployment claims, production-health claims, alternate renderer scope,
  and auto-apply claims as blocked.
- Hand off ready or advisory evaluator artifacts to a local consumption-report
  branch that can render human/agent-facing summaries without adding authority.

## Non-Goals

- No app runtime integration.
- No app config writes or app data writes.
- No workbench state mutation, mutation buttons, or live UI wiring.
- No GitHub API calls, workflow edits, required status checks, check-run
  creation, CI uploads, step-summary writes, or pull request comments.
- No live agent projection, raw prompt capture, raw response capture, or raw
  payload capture.
- No durable writes, NenDB writes, NenDB adapter execution, Cockroach work, or
  non-NenDB durable adapter work.
- No deployment, production health, cluster readiness, or remediation success
  claims.
- No renderer change away from SolidJS inside `webui-dev/zig-webui`.

## Source Policy Contract

The source artifact must have:

- `schema="zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-policy.v1"`;
- `decision="approve"`;
- `consumption_policy_status="ready"`;
- `ready_for_next_branch=true`;
- `mutation_authority="none"`;
- non-empty `source_consumption_boundary`;
- `source_consumption_boundary_status="applied"`;
- non-empty `source_consumption_readiness`;
- `source_consumption_readiness_status="ready"`;
- non-empty `source_publication_policy`;
- non-empty `source_after_report_digest`;
- non-empty `source_consumer_after_digest`;
- passing policy checks;
- non-empty interpretation rules, consumption scopes, denied inference rules,
  source denied boundary claims, source blocked claims, negative fixtures, and
  required verification commands.

The source must preserve disabled authority:

- CI gate, CI enforcement, required status checks, workflow mutation, uploads,
  report publication, GitHub summaries, PR comments, and GitHub API mutation are
  all false;
- app mutation controls, app mutation, app config writes, app data writes, app
  runtime integration, live agent projections, raw payload capture, and
  deployment mutation are all false;
- live telemetry ingestion, exporter, network send, collector endpoint, OTLP
  serialization, runtime pipeline, durable writes, NenDB writes, and NenDB
  adapter execution are all false;
- `read_only_consumption_enabled=true`, `solid_webui_enabled=true`,
  `solid_webui_renderer="solidjs"`, and
  `webui_bridge="webui-dev/zig-webui"`.

## Request And Evidence Classes

The evaluator accepts explicit bounded local files only:

- `request_json`: JSON request file under `.zig-cache/causal-artifacts/` whose
  path or contents identify an agent, reviewer, CI advisory reader, workbench,
  or evaluator consumption request.
- `request_text`: text request file under `.zig-cache/causal-artifacts/`.
- `policy_json`: the source policy file when supplied as supporting evidence.
- `causal_json`: any zigeffect causal JSON artifact.
- `causal_text`: any zigeffect causal text artifact.
- `workbench_text`: local text evidence that mentions SolidJS or
  `webui-dev/zig-webui`.
- `denied`: unsupported paths, unsupported extensions, or unsafe content.

Requests are required. Evidence is optional. A ready result needs at least one
safe request and at least one safe support evidence file that is not a request.
If support evidence is missing but the source policy and requests are safe, the
result is `advisory-findings`.

## Evaluation Status

`ready` means:

- source policy is ready and non-mutating;
- all request and evidence files are bounded and safe;
- at least one request is present;
- at least one support evidence file is present;
- required consumer roles, policy rules, scopes, denied claims, and redaction
  posture are present.

`advisory-findings` means:

- source policy is ready and all supplied files are safe;
- at least one non-blocking expected signal is missing, such as support evidence.

`blocked` means:

- source policy is blocked, malformed, or authority-bearing;
- no request file is present;
- any request/evidence path is unsupported;
- any content contains secret-shaped markers, raw prompt/response/payload
  markers, mutation claims, CI enforcement claims, runtime integration claims,
  durable/NenDB/Cockroach claims, deployment claims, production-health claims,
  alternate renderer claims, or auto-apply claims.

## Output Shape

The JSON artifact includes:

- schema metadata, source branch, recommendation, and next branch;
- source policy refs, source boundary refs, source readiness refs, source
  publication-policy refs, digest refs, and source policy status;
- evaluation mode/status, ready flag, advisory/blocked finding counts,
  mutation authority, and disabled authority fields;
- request and evidence file analysis with sha256 digests, detected schemas,
  detected roles, redaction posture, classes, and denied reasons;
- signal evaluations, checks, findings, source interpretation rule ids, source
  consumption scope ids, denied claims, next queries, and agent guidance.

The text artifact mirrors the same information for reviewers.

## Build Integration

Add a Zig executable and build step:

```text
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator
```

Add its unit tests to the package `test` step after the consumption-policy tool.

## Governance And Roadmap

Register:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator.v1
```

Update schema governance from 96 to 97 schemas. Add a delivered backlog item for
this milestone and move the recommended next branch to:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report
```

Update the master roadmap so branch 61 is delivered and branch 62 is the local
consumption-report milestone.

## Testing

Use TDD for the evaluator:

- constants and branch names;
- CLI parsing for multiple requests and evidence files;
- default output suffix replacement and compact long-name fallback;
- evidence classification for request, policy, causal, workbench, and denied
  files;
- ready evaluation with safe request plus support evidence;
- advisory evaluation with safe request but missing support evidence;
- blocked evaluation for invalid source policy;
- blocked evaluation for unsafe request/evidence markers;
- JSON and text output preserve disabled authority, denied claims, next queries,
  and next-branch guidance.

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_evaluator.zig
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_policy.zig
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build test
zig build examples
cd ../..
bun run check
bun run zig:test
git diff --check
```
