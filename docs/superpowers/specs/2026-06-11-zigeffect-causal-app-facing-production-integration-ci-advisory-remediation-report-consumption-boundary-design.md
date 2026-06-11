# App-Facing CI Advisory Remediation Report Consumption Boundary Design

## Summary

Add a guarded, record-only consumption-boundary artifact for app-facing CI
advisory remediation report evidence.

The producer is:

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary -- \
  --from-readiness <consumption-readiness.json> \
  plan|record-applied \
  --reason <reason> \
  [--consumer-after <report.txt|report.md|report.json>] \
  [--consumer-change <evidence>]... \
  [--before <evidence>]... \
  [--after <evidence>]... \
  [--verified-command <command>]... \
  [--out-prefix <path-prefix>]
```

It emits:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary.v1
```

This branch consumes ready
`zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness.v1`
artifacts and records whether a read-only consumer boundary has been planned or
reviewed as applied. "Applied" here means an evidence record for bounded
read-only consumption has been reviewed; it does not mean app runtime
integration, workbench mutation, CI enforcement, GitHub mutation, storage
writes, deployment authority, production health proof, or any live projection.

## Goals

- Record a concrete boundary for consuming app-facing advisory remediation
  report evidence by reviewers, agents, non-blocking CI advisory readers, and
  the local SolidJS `webui-dev/zig-webui` workbench.
- Require a ready consumption-readiness source before `record-applied` can set
  `applied=true`.
- Require reviewed consumer-change evidence, before evidence, after evidence,
  post-application verification commands, and a local consumer-after report
  before `record-applied` is accepted.
- Preserve source ids, denied claims, consumer profiles, readiness dimensions,
  guardrails, and verification evidence from the readiness artifact.
- Keep every authority flag disabled except the artifact-local
  `mutation_authority="record-only"` marker on successfully applied records.
- Hand off to a later policy branch that can define how consumption-boundary
  records are interpreted by agents and the workbench.

## Non-Goals

- No app runtime integration.
- No app config or app data writes.
- No workbench state mutation, mutation buttons, or live UI wiring.
- No GitHub API calls, workflow edits, check creation, step-summary writes,
  pull request comments, artifact uploads, or required status checks.
- No live agent projection, raw prompt capture, raw response capture, or raw
  payload capture.
- No NenDB writes, NenDB adapter execution, Cockroach work, or non-NenDB
  durable storage work.
- No deployment, production health, cluster readiness, or remediation success
  claims.
- No renderer change away from SolidJS inside `webui-dev/zig-webui`.

## Source Contract

The source artifact must have:

- `schema="zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness.v1"`;
- `decision="approve"`;
- `consumption_readiness_status="ready"`;
- `ready_for_next_branch=true`;
- `mutation_authority="none"`;
- `source_publication_policy_schema` matching the app-facing publication-policy
  schema;
- `source_after_report_digest` present;
- passing readiness checks;
- consumer profiles present;
- readiness dimensions present;
- consumption guardrails present;
- denied inference rules, negative fixtures, and blocked claims present;
- every required verification command recorded in `verified_commands`.

The source must also preserve disabled authority:

- CI gate, CI enforcement, required status checks, workflow mutation, uploads,
  report publication, GitHub summaries, PR comments, and GitHub API mutation are
  all false;
- app mutation controls, app mutation, app config writes, app data writes, app
  runtime integration, live agent projections, raw payload capture, and
  deployment mutation are all false;
- live telemetry ingestion, exporter, network send, collector endpoint, OTLP
  serialization, runtime pipeline, durable write, NenDB write, and NenDB
  adapter execution are all false;
- `solid_webui_enabled=true`, `solid_webui_renderer="solidjs"`, and
  `webui_bridge="webui-dev/zig-webui"`.

## Modes

### `plan`

Plan mode validates the source and records intent to create a read-only
consumption boundary. It always emits:

- `consumption_boundary_status="planned"` when the source is valid;
- `applied=false`;
- `mutation_authority="none"`;
- `ready_for_next_branch=false`.

Plan mode does not require before/after evidence or post-application
verification. It is useful for documenting intent before any local consumer
contract is reviewed.

### `record-applied`

`record-applied` validates the source and requires:

- at least one `--consumer-change`;
- at least one `--before`;
- at least one `--after`;
- `--consumer-after <path>` with safe local content;
- every required verification command recorded with `--verified-command`.

When all checks pass it emits:

- `consumption_boundary_status="applied"`;
- `applied=true`;
- `ready_for_next_branch=true`;
- `mutation_authority="record-only"`.

If any check fails it emits a blocked artifact with `applied=false` and
`mutation_authority="none"`.

## Consumer-After Safety

The `--consumer-after` content must be local text evidence describing the
reviewed read-only consumption boundary. It must include these marker words:

- `zigeffect`;
- `causal`;
- `read-only`;
- `consumption`;
- `boundary`.

It must not include strings that claim or imply:

- required status check or CI enforcement activation;
- GitHub API, workflow, upload, step-summary, or PR-comment mutation;
- app mutation, app config write, app data write, or app runtime integration;
- live agent projection or raw payload capture;
- NenDB write, NenDB adapter execution, Cockroach work, or non-NenDB durable
  adapter work;
- production health, deployment success, cluster readiness, or auto-apply;
- mutation authority beyond record-only;
- React or alternate renderer scope.

## Output Shape

The JSON artifact includes:

- schema metadata, generated_by, source branch, recommendation, and next branch;
- source consumption-readiness refs and source digest refs;
- mode, status, `applied`, `ready_for_next_branch`, and `mutation_authority`;
- disabled CI, GitHub, app, runtime, deployment, live projection, raw payload,
  durable, NenDB, and adapter authority fields;
- SolidJS `webui-dev/zig-webui` read-only fields;
- reviewed consumer changes, before evidence, after evidence, and
  consumer-after digest;
- consumer boundary checks;
- source consumer profiles, readiness dimensions, guardrails, denied inference
  rules, negative fixtures, and blocked claims;
- required verification commands and recorded verified commands;
- agent guidance.

The text artifact mirrors the same information in a compact human-readable
format.

## Build Integration

Add a Zig executable and build step:

```text
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary
```

Add its unit tests to the package `test` step.

## Governance And Roadmap

Register:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary.v1
```

Update schema governance from 94 to 95 schemas. Add a delivered backlog item for
this milestone and move the recommended next branch to:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy
```

Update the master roadmap so branch 59 is delivered and branch 60 is the
consumption-policy branch.

## Testing

Use TDD for the producer:

- constants and branch names;
- CLI parsing for `plan` and `record-applied`;
- default output suffix replacement and compact long-name fallback;
- plan mode validates source but stays unapplied;
- `record-applied` with missing evidence stays blocked;
- `record-applied` with complete evidence becomes applied and record-only;
- unsafe source artifacts stay blocked;
- unsafe consumer-after text stays blocked;
- JSON and text output preserve disabled authority and next-branch guidance.

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_boundary.zig
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build test
zig build examples
cd ../..
bun run check
bun run zig:test
git diff --check
```
