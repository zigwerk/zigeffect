# Zigeffect Causal App-Facing Production Integration CI Advisory Remediation Report Design

## Problem

The app-facing production integration chain now has a SolidJS read-only preview
artifact for local `webui-dev/zig-webui` inspection. The next useful step is a
CI-readable advisory remediation report that agents and reviewers can consume
when app-facing causal evidence indicates an issue.

This must not become a required status check, workflow mutator, GitHub API
mutator, deployment step, app mutator, NenDB writer, or production-health proof.
It is a report artifact only.

## Goals

- Consume
  `zigeffect.causal.app-facing-production-integration-solid-webui-readonly-preview.v1`.
- Emit
  `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report.v1`.
- Preserve the SolidJS/WebUI source refs and app-facing bridge records.
- Promote the `ci-advisory-remediation-report-bridge` into explicit advisory
  findings, remediation refs, next-query guidance, and denied CI claims.
- Keep `applied=false` and `mutation_authority="none"`.
- Make the artifact useful to local CI and agents without implying merge
  blocking, branch protection, workflow mutation, GitHub mutation, artifact
  upload, PR commenting, app mutation, NenDB write, or deployment authority.
- Add workbench read support and a sample route so the report can be inspected
  alongside app-facing preview evidence.

## Non-Goals

- No GitHub Actions workflow edits.
- No required status check enablement.
- No CI upload execution, step summary write, or PR comment.
- No live dashboard hosting.
- No app config/data mutation.
- No NenDB adapter execution or NenDB writes.
- No Cockroach scope.
- No deployment, production health, or `applied=true` claim.

## Artifact Contract

The producer is
`causal-app-facing-production-integration-ci-advisory-remediation-report`.

The source is a ready SolidJS read-only preview artifact. The report is ready
only when:

- the source schema matches the preview schema;
- the source decision is `approve`;
- the source status is `ready`;
- the source authority is disabled;
- all expected bridge records are retained;
- `ci-advisory-remediation-report-bridge` is present;
- the advisory bridge remains `advisory-only`;
- verification command evidence includes the previous preview tool.

The output includes:

- advisory summary rows for app-facing CI review;
- advisory findings linked to retained refs;
- agent next-query recommendations;
- report surfaces and their allowed interpretation;
- denied CI/app/durable/deployment claims;
- source bridge record snapshots;
- validation checks and required/verified commands;
- next branch guidance for a reviewed application boundary.

## Workbench Contract

The SolidJS workbench should parse the report without gaining any mutation
controls. A sample route should be available as `?sample=app-ci-advisory`.

The existing app-facing preview view can render the report if its model is
extended to understand both:

- `solid-webui-readonly-preview`;
- `ci-advisory-remediation-report`.

The UI should emphasize:

- advisory-only status;
- source preview status;
- disabled CI authority;
- remediation/advisory refs;
- next-query guidance;
- blocked claims.

## Verification

Required verification:

- `zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report.zig`
- `zig build causal-app-facing-production-integration-ci-advisory-remediation-report`
- approved and rejected artifact generation
- `zig build test`
- `zig build examples`
- `zig build causal-schema-governance -- --format json`
- `zig build causal-production-hardening-backlog -- --format json`
- `bun run zigeffect:workbench:typecheck`
- `bun run zigeffect:workbench:test`
- `bun run check`
- `bun run zig:test`
- `git diff --check`
