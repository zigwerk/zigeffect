# zigeffect Causal Production Hardening Completion Audit Design

## Context

The production-hardening backlog now reports
`start-production-hardening-completion-audit` and points to
`codex/zigeffect-causal-production-hardening-completion-audit`.

The immediately preceding milestone delivered
`zigeffect.causal.production-capacity-planning.v1` through
`zig build causal-production-capacity-planning`. That report records source
contracts, capacity domains, storage assumptions, load-test fixture plans,
workbench and graph concurrency assumptions, readiness gates, and negative
capacity fixtures. It also states that capacity planning is record-only,
planning-only, NenDB-only, and cannot claim production capacity.

The completion audit is the bridge between a long sequence of delivered
production-hardening reports and the next evidence-producing branch. It should
prove that the hardening sequence is coherent, that the documented authority
boundaries held, and that the next branch is chosen from explicit remaining
evidence gaps rather than drift or enthusiasm.

## Goals

- Add a deterministic completion audit tool:
  `zig build causal-production-hardening-completion-audit`.
- Emit schema
  `zigeffect.causal.production-hardening-completion-audit.v1`.
- Audit every delivered production-hardening milestone currently named by the
  backlog dependency order.
- Record whether each milestone is delivered, partial, or still future, and
  cite the canonical tool/doc evidence for that state.
- Confirm the durable direction remains NenDB adapter only.
- Confirm the workbench direction remains SolidJS inside
  `webui-dev/zig-webui`.
- Confirm mutation authority remains `none` and that all production-hardening
  reports are record-only or planning-only evidence.
- Confirm capacity planning did not become a production capacity claim.
- Identify remaining evidence gaps after this hardening sweep.
- Recommend the next evidence-producing branch:
  `codex/zigeffect-causal-load-test-observation-harness`.

## Non-Goals

- No live production telemetry ingestion.
- No load-test execution.
- No production capacity, cost, autoscaling, dashboard hosting, or incident
  volume claims.
- No source, config, registry, app, deployment, rollout, alert, ticket, page,
  RBAC, encryption, durable-store, or production mutation.
- No non-NenDB durable adapter work.
- No Cockroach adapter work.
- No alternate frontend renderer work.
- No promotion of `agent-query-interface` cross-run comparison from future to
  delivered.
- No automatic merge, release, deployment, or roadmap completion claim for the
  whole long-running project.

## Considered Approaches

### Approach A: Static schema-governed completion report

Create a Zig report tool, similar to `causal-m9-completion-audit` and
`causal-production-hardening-backlog`, with static audit records, boundary
checks, negative fixtures, verification commands, and a next-branch
recommendation.

This is the recommended approach. It matches the existing production-hardening
contract pattern, is deterministic, and creates stable evidence agents can read
without needing file IO, network access, live systems, clocks, or generated
artifacts.

### Approach B: Dynamic filesystem audit

Create a tool that opens docs and generated reports, parses current files, and
derives completion state dynamically.

This would be more automated, but it would violate the current hardening
pattern by making the audit depend on local filesystem shape and generated
outputs. It would also blur the line between a schema-governed contract and a
test runner.

### Approach C: Treat backlog JSON as the audit

Avoid a new artifact and use `causal-production-hardening-backlog` as the final
audit.

This is too weak. The backlog chooses the next branch and records ordered work,
but it does not explicitly prove boundary preservation, capacity-plan
non-claims, remaining evidence gaps, negative completion fixtures, or a final
handoff out of the production-hardening sweep.

## Architecture

Create `packages/zigeffect/tools/causal_production_hardening_completion_audit.zig`.

The tool should expose:

- schema constants;
- source branch and next branch constants;
- option parsing for `--format text|json`;
- static arrays for milestone checks, boundary checks, remaining gaps, negative
  audit fixtures, verification commands, and agent guidance;
- text and JSON formatters;
- tests for inventory coverage, boundary coverage, negative fixtures, parser
  behavior, text output, and JSON output.

The report should not import the other tools. The canonical evidence is cited
by schema, command, doc, branch, and status fields. This keeps the tool
deterministic and avoids introducing runtime dependencies between report tools.

## Schema Shape

Top-level JSON fields:

- `schema`
- `schema_version`
- `producer`
- `mode`
- `applied`
- `mutation_authority`
- `source_branch`
- `status`
- `recommendation`
- `next_branch`
- `milestone_checks`
- `boundary_checks`
- `remaining_evidence_gaps`
- `negative_audit_fixtures`
- `agent_guidance`
- `non_goals`
- `verification_commands`

Constants:

- `schema = "zigeffect.causal.production-hardening-completion-audit.v1"`
- `schema_version = 1`
- `producer = "causal-production-hardening-completion-audit"`
- `mode = "local-record"`
- `applied = false`
- `mutation_authority = "none"`
- `source_branch =
  "codex/zigeffect-causal-production-hardening-completion-audit"`
- `recommendation = "start-load-test-observation-harness"`
- `next_branch = "codex/zigeffect-causal-load-test-observation-harness"`

## Milestone Checks

The audit should include one check for each backlog dependency item:

- `production-artifact-aggregation`: delivered.
- `durable-production-retention`: delivered.
- `production-deployment-runbooks`: delivered.
- `artifact-access-control`: delivered.
- `unified-causal-spine-contract`: delivered.
- `deep-runtime-internals`: delivered.
- `app-semantic-trace-api`: delivered.
- `agent-query-interface`: partial, because runtime query JSON and app
  semantic `trace_data` are delivered while cross-run comparison remains
  future.
- `encryption-at-rest-policy`: delivered.
- `alerting-integrations`: delivered.
- `live-dashboard-streaming-workbench`: delivered.
- `workbench-graph-visual-debugging`: delivered.
- `human-agent-feedback-loop`: delivered.
- `rollout-automation-guardrails`: delivered.
- `wall-clock-benchmark-baselines`: delivered.
- `production-capacity-planning`: delivered.

Each check should include:

- `id`
- `status`
- `schema`
- `command`
- `doc`
- `evidence`
- `completion_boundary`
- `agent_guidance`

For delivered items that do not have their own standalone report tool
(`deep-runtime-internals`, `app-semantic-trace-api`,
`workbench-graph-visual-debugging`), use the authoritative docs, workbench
tests, and backlog record as the cited evidence.

## Boundary Checks

The audit should include explicit checks for:

- `record-only-authority`
- `mutation-authority-none`
- `nendb-only-durable-direction`
- `solidjs-webui-workbench-direction`
- `capacity-planning-non-claim`
- `wall-clock-advisory-only`
- `alerting-and-rollout-preview-only`
- `access-control-policy-only`
- `encryption-policy-only`
- `agent-query-bounded-read-only`
- `production-telemetry-absent`

Each check should include:

- `id`
- `decision`
- `evidence`
- `blocked_claim`
- `agent_guidance`

## Remaining Evidence Gaps

The audit should not pretend production hardening is complete in the production
runtime sense. It should separate delivered contracts from remaining future
evidence work:

- `load-test-observation-harness`: next recommended branch.
- `production-telemetry-capture-design`: future.
- `reviewed-production-capacity-sizing`: future.
- `live-alert-delivery`: future.
- `live-rollout-automation`: future.
- `live-rbac-enforcement`: future.
- `encryption-implementation`: future.
- `production-dashboard-hosting`: future.
- `agent-query-cross-run-comparison`: future.
- `nendb-durable-history-hardening`: future.

Each gap should include:

- `id`
- `status`
- `reason`
- `recommended_branch`
- `blocked_until`

Only `load-test-observation-harness` should be marked as `recommended-next`.
The rest remain future planning targets.

## Negative Audit Fixtures

The audit should reject:

- declaring all production hardening production-ready from contract reports;
- claiming capacity from the production capacity planning report;
- recommending Cockroach or non-NenDB durable adapter work;
- recommending React or another renderer for the workbench path;
- treating alert preview fixtures as sent alerts;
- treating rollout guardrail records as traffic shifts;
- treating access-control policy as live RBAC enforcement;
- treating encryption-at-rest policy as encrypted bytes;
- treating wall-clock benchmark baselines as CI failure gates;
- treating the completion audit as mutation authority.

## Documentation Updates

Add `packages/zigeffect/docs/production-hardening-completion-audit.md`.

Update:

- `packages/zigeffect/build.zig`
- `packages/zigeffect/tools/causal_schema_governance.zig`
- `packages/zigeffect/docs/schema-governance.md`
- `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- `packages/zigeffect/docs/production-hardening-backlog.md`
- `packages/zigeffect/docs/operations.md`
- `packages/zigeffect/docs/roadmap.md`
- `packages/zigeffect/README.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

The backlog should mark `production-hardening-completion-audit` delivered and
recommend `codex/zigeffect-causal-load-test-observation-harness`.

Schema governance should register
`zigeffect.causal.production-hardening-completion-audit.v1`, bump the schema
count, and add a compatibility posture if needed. The existing `record-only`
and `mutation-authority-none` postures are sufficient; the schema can use
`completion-audit` as an additional compatibility label if tests and docs define
it.

## Verification

Focused commands:

```sh
cd packages/zigeffect
zig test tools/causal_production_hardening_completion_audit.zig
zig build causal-production-hardening-completion-audit
zig build causal-production-hardening-completion-audit -- --format json
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
git diff --check
```

Broad commands:

```sh
cd packages/zigeffect
zig build examples
zig build test
cd ../..
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
bun run check
bun run zig:test
git diff --check
```

## Open Decisions Resolved

- The audit is static and deterministic, not a dynamic filesystem parser.
- The next branch is a local load-test observation harness contract, not live
  production telemetry or production sizing.
- The audit may record partial status for `agent-query-interface`; that partial
  state is not a blocker because the backlog already separates delivered
  bounded query slices from future cross-run comparison.
- The audit does not mark the full long-running roadmap complete. It only closes
  the current production-hardening sweep and hands off to the next
  evidence-producing branch.
