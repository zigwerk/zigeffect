# App-Facing CI Advisory Remediation Report Consumption Policy Design

## Summary

Add a guarded interpretation-policy artifact for applied app-facing CI advisory
remediation report consumption-boundary evidence.

The producer is:

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy -- \
  --from-boundary <consumption-boundary.json> \
  approve|reject \
  --reason <reason> \
  [--by <actor>] \
  [--policy <policy>] \
  [--verified-command <command>]... \
  [--out-prefix <path-prefix>]
```

It emits:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-policy.v1
```

This branch consumes applied
`zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary.v1`
artifacts and defines how agents, reviewers, non-blocking CI advisory readers,
and the SolidJS `webui-dev/zig-webui` workbench may interpret read-only
consumption evidence. It does not integrate the app runtime, mutate workbench
state, publish CI artifacts, write GitHub, write NenDB, execute a NenDB adapter,
add Cockroach scope, deploy anything, or grant mutation authority.

## Goals

- Record a deterministic policy decision over an applied consumption-boundary
  artifact.
- Preserve source boundary ids, source readiness refs, source publication-policy
  refs, after-report digests, consumer-change evidence, before/after evidence,
  boundary rules, denied boundary claims, source guardrails, source consumer
  profiles, source readiness dimensions, negative fixtures, and verified command
  evidence.
- Define allowed interpretation rules for maintainers, read-only agents,
  non-blocking CI advisory readers, SolidJS workbench viewers, and the future
  read-only consumption evaluator.
- Define explicit consumption scopes that are local, redacted, bounded, and
  non-mutating.
- Deny inference of required status checks, merge blocking, CI enforcement,
  workflow mutation, GitHub API mutation, app mutation, app runtime integration,
  live agent projection, raw payload capture, durable writes, NenDB writes,
  NenDB adapter execution, Cockroach work, deployment, production health,
  alternate renderers, auto-apply, and mutation authority.
- Hand off to a later read-only consumption evaluator branch that can apply this
  policy to concrete agent/workbench consumption requests.

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

## Source Contract

The source artifact must have:

- `schema="zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary.v1"`;
- `mode="record-applied"`;
- `consumption_boundary_status="applied"`;
- `applied=true`;
- `ready_for_next_branch=true`;
- `mutation_authority="record-only"`;
- non-empty `source_consumption_readiness`;
- `source_consumption_readiness_status="ready"`;
- non-empty `source_publication_policy`;
- non-empty `source_after_report_digest`;
- non-empty `consumer_after_digest`;
- non-empty `consumer_changes`, `before_evidence`, and `after_evidence`;
- non-empty source consumer profiles, readiness dimensions, consumption
  guardrails, source denied inference rules, denied boundary claims, negative
  fixtures, blocked claims, and boundary rules;
- passing boundary checks;
- every required verification command present in `verified_commands`.

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

## Decisions

### `approve`

`approve` validates the applied boundary source and required verification
commands. If every check passes, it emits:

- `consumption_policy_status="ready"`;
- `ready_for_next_branch=true`;
- `mutation_authority="none"`;
- interpretation rules and read-only consumption scopes.

Ready policy artifacts are only policy records. They can guide consumers and the
future evaluator, but they cannot apply changes or prove runtime behavior.

### `reject`

`reject` records a reviewed stop. It emits:

- `consumption_policy_status="blocked"`;
- `ready_for_next_branch=false`;
- `mutation_authority="none"`.

Rejected records keep the same denied claims and agent guidance as blocked
source validation failures.

## Interpretation Rules

The policy emits rules for:

- `maintainer-consumption-review`: maintainers may compare source ids, boundary
  checks, before/after evidence, and denied claims for triage.
- `agent-bounded-context`: agents may cite bounded source ids, policy rules,
  guardrails, blocked claims, and next-query guidance.
- `ci-advisory-reader`: CI readers may display non-blocking advisory context but
  must not infer merge-blocking or required-check status.
- `solid-webui-readonly-consumer`: the SolidJS workbench may render local
  read-only consumption evidence without mutation controls or runtime wiring.
- `future-consumption-evaluator-input`: the next evaluator may use ready policy
  artifacts as input for bounded request classification.

Every rule has a `failure_effect` of `informational`, `blocked`, or
`evaluator-input` and a denied claim.

## Consumption Scopes

The policy emits read-only scopes for:

- local JSON artifact evidence;
- local text report evidence;
- SolidJS workbench read-only rendering;
- bounded agent prompt context with redacted ids only;
- non-blocking CI advisory reading;
- future evaluator input.

Every scope has `executed_by_tool=false` and `mutation_authority="none"`.

## Output Shape

The JSON artifact includes:

- schema metadata, generated_by, source branch, recommendation, and next branch;
- source boundary refs and source digest refs;
- decision, reviewer, policy, reason, status, ready flag, and mutation authority;
- disabled CI, GitHub, app, runtime, deployment, raw payload, durable, NenDB,
  and adapter authority fields;
- SolidJS `webui-dev/zig-webui` read-only fields;
- source consumer changes, before/after evidence, source profiles, readiness
  dimensions, guardrails, rules, denied claims, negative fixtures, and blocked
  claims;
- policy checks, interpretation rules, consumption scopes, denied inference
  rules, negative fixtures, required verification commands, recorded verified
  commands, and agent guidance.

The text artifact mirrors the same information for reviewers.

## Build Integration

Add a Zig executable and build step:

```text
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy
```

Add its unit tests to the package `test` step after the consumption-boundary
tool.

## Governance And Roadmap

Register:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-policy.v1
```

Update schema governance from 95 to 96 schemas. Add a delivered backlog item for
this milestone and move the recommended next branch to:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator
```

Update the master roadmap so branch 60 is delivered and branch 61 is the
read-only consumption evaluator.

## Testing

Use TDD for the producer:

- constants and branch names;
- CLI parsing for `approve` and `reject`;
- default output suffix replacement and compact long-name fallback;
- approved policy validates applied source and becomes ready;
- rejected policy stays blocked;
- unsafe source artifacts stay blocked;
- missing verification evidence stays blocked;
- interpretation rules, consumption scopes, denied rules, and negative fixtures
  are present;
- JSON and text output preserve disabled authority and next-branch guidance.

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_policy.zig
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build test
zig build examples
cd ../..
bun run check
bun run zig:test
git diff --check
```
