# Zigeffect App-Facing Ten-Level Evaluator Design

## Context

The ten-level policy milestone now emits approved, rejected, and blocked-source
policy evidence. The approved artifact is local, read-only, and ready for:

```text
codex/zigeffect-causal-app-facing-ten-level-evaluator
```

This milestone adds the matching evaluator. It consumes approved ten-level
policy evidence plus bounded local request/support evidence, emits ready,
advisory, or blocked evaluator findings, preserves no-mutation authority, and
hands ready or advisory evaluator evidence to:

```text
codex/zigeffect-causal-app-facing-eleven-level-report
```

## Physical Naming Policy

The artifact schema remains fully expanded and authoritative. Physical names use
short aliases:

- Tool file: `packages/zigeffect/tools/causal_app_facing_ten_level_evaluator.zig`
- Build step: `causal-app-facing-ten-level-evaluator`
- Executable: `zigeffect-causal-app-facing-ten-level-evaluator`
- Docs: `packages/zigeffect/docs/app-facing-ten-level-evaluator.md`
- Current branch: `codex/zigeffect-causal-app-facing-ten-level-evaluator`
- Next branch if ready: `codex/zigeffect-causal-app-facing-eleven-level-report`
- Recommendation: `start-app-facing-eleven-level-report`

Future files and branches must keep alias naming and avoid re-expanding physical
names past the ten-level alias.

## Artifact Contract

The evaluator consumes:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1
```

It emits:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1
```

The evaluator output includes:

- source ten-level policy path, schema, status, decision, and ready flag
- source ten-level report refs
- source nine-level policy, application-boundary, and report lineage
- inherited eight-level and lower-level evidence
- request and support evidence summaries
- source policy checks, interpretation rules, consumption scopes, denied claims,
  negative fixtures, publication posture, and verification commands
- evaluator checks, signal evaluations, findings, next queries, and agent
  guidance
- disabled authority flags for CI, GitHub, app runtime, raw payload, storage,
  NenDB, NenDB adapter execution, Cockroach scope, public upload, dashboard,
  deployment, production-health, auto-apply, and mutation authority

## Evaluation Gates

Ready output requires:

- source schema equals the ten-level policy schema and version is `1`
- source decision is `approve`
- source policy status is `ready`
- source `ready_for_next_branch=true`
- source mutation authority is `none`
- source ten-level report refs are present and ready
- source nine-level policy/application-boundary/report refs are present and
  ready
- inherited lower-level policy/application/report refs are present and ready
- source policy checks contain no failures
- source catalogs, denied claims, negative fixtures, local publication posture,
  and verification evidence are present
- at least one bounded request file under `.zig-cache/causal-artifacts`
- bounded support evidence under `.zig-cache/causal-artifacts`
- request and evidence inputs do not contain raw payloads, secret-shaped tokens,
  runtime integration, mutation, deployment, production health, Cockroach,
  public upload, alternate renderer, or auto-apply claims

Missing support evidence emits `advisory-findings` when the source policy and
request are otherwise safe. Rejected, blocked, authority-drift, unsafe-source,
or unsafe-request evidence emits `blocked`.

## Non-Authority

The evaluator writes local JSON and text artifacts only. It never creates or
proves CI enforcement, required status checks, workflow mutation, GitHub API
mutation, step summary writes, pull request comments, public uploads, app
mutation, app config writes, app data writes, app runtime integration, live
agent projection, raw prompt/response/payload capture, durable writes, NenDB
writes, NenDB adapter execution, Cockroach adapter work, deployment success,
production health, hosted dashboards, auto-apply, registry mutation, or mutation
authority.

## Tests

Focused Zig tests must cover:

- stable schema, branch, recommendation, next branch, and alias constants
- option parsing for request and support evidence inputs
- default output path replacement from ten-level policy suffix to ten-level
  evaluator suffix
- file classification for request, policy, causal, workbench, and denied inputs
- ready evaluator output with approved ten-level policy and bounded support
  evidence
- advisory evaluator output when support evidence is missing
- blocked evaluator output for unsafe request evidence
- blocked evaluator output for rejected or blocked source policy evidence
- source ten-level report and nine-level lineage carryover
- generated JSON parseability

Registry tests must prove:

- schema governance count increments by one
- schema governance contains the ten-level evaluator schema
- production backlog recommendation moves to the eleven-level report branch
- generated backlog docs contain the ten-level evaluator item and build commands

## Verification

Fresh verification must include:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_ten_level_evaluator.zig
zig build causal-app-facing-ten-level-evaluator -- --help
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
