# zigeffect Causal App-Facing Fourteen-Level Report Design

## Objective

Add the `causal-app-facing-fourteen-level-report` milestone to the causal app-facing ladder. The tool consumes a thirteen-level evaluator artifact, emits local JSON and text report artifacts, and prepares the reviewed handoff to `codex/zigeffect-causal-app-facing-fourteen-level-application-boundary`.

## Context

The current ladder is intentionally repetitive and explicit:

- report consumes the previous evaluator;
- application boundary consumes the report and records reviewed local application evidence;
- policy consumes the applied boundary and records an approve or reject decision;
- evaluator consumes the policy and emits ready, advisory, or blocked findings for the next report.

The thirteen-level evaluator now represents the latest ready source. The fourteen-level report must preserve its direct thirteen-level evidence and carry forward the twelve-level evaluator plus lower lineage so future agents can reason about provenance without live runtime access or hidden mutation authority.

## Artifact Contract

The emitted report uses schema:

`zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1`

It records:

- direct source evaluator path, schema, status, and readiness;
- direct thirteen-level policy, application-boundary, report, digest, and application-change evidence;
- carried twelve-level evaluator, policy, application-boundary, report, digest, and application-change evidence;
- carried eleven-level, ten-level, nine-level, eight-level, and inherited lineage;
- request, support evidence, signal, finding, check, denied-claim, next-query, and agent guidance summaries;
- local-only publication channels and disabled authority flags;
- required verification commands for reviewers and future agents.

## Readiness Rules

The fourteen-level report is `ready` only when:

- the source schema is the thirteen-level evaluator schema and version 1;
- the source evaluator status is `ready` or `advisory-findings`;
- the source evaluator is ready for the next branch;
- no blocked findings are present;
- thirteen-level policy/application/report evidence is present and ready/applied as appropriate;
- twelve-level evaluator and lower lineage remain present and ready/applied as appropriate;
- source request and report sections remain available;
- CI, GitHub, app runtime, storage, deployment, Nendb write/execution, hosted dashboard, public upload, auto-apply, and mutation authority remain disabled;
- SolidJS inside `webui-dev/zig-webui` remains read-only context only;
- this tool writes only local JSON/text artifacts.

If all checks pass but source advisory findings are present, the report status is `advisory` and remains usable as bounded context. If any check fails, the report status is `blocked` and cannot be used as reportable app-facing context.

## Non-Goals

- No CI enforcement, status checks, workflow mutation, or GitHub API mutation.
- No app runtime integration or live agent projection.
- No CockroachDB scope.
- No Nendb writes or adapter execution.
- No production telemetry ingestion or deployment mutation.
- No public artifact upload, hosted live dashboard, auto-apply, or mutation authority.

## Deliverables

- `packages/zigeffect/tools/causal_app_facing_fourteen_level_report.zig`
- `packages/zigeffect/docs/app-facing-fourteen-level-report.md`
- build target `causal-app-facing-fourteen-level-report`
- schema governance entry and tests
- production hardening backlog entry, dependency ordering, commands, and tests
- roadmap update marking the fourteen-level report as delivered and pointing to the fourteen-level application-boundary branch
- generated ready, advisory, and blocked local report artifacts

## Success Criteria

- Unit tests cover constants, parsing, default output naming, ready/advisory/blocked outcomes, authority drift, and local-only publication.
- The build target emits help text and accepts real thirteen-level evaluator artifacts.
- Ready/advisory/blocked artifacts are generated under `.zig-cache/causal-artifacts/`.
- Governance/backlog tests pass and list the new schema/item.
- Root verification passes with Bun and Zig checks.
