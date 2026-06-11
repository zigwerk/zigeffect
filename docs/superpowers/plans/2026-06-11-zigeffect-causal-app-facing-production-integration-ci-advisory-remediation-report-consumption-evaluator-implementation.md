# App-Facing CI Advisory Remediation Report Consumption Evaluator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the guarded read-only consumption evaluator for app-facing CI advisory remediation report consumption requests.

**Architecture:** Fix the upstream consumption-policy JSON regression, then add one Zig evaluator that consumes ready policy artifacts, classifies explicit request/evidence files, emits ready/advisory/blocked JSON and text artifacts, and never grants runtime, app, CI, GitHub, storage, deployment, or adapter authority. Wire it into build, schema governance, backlog, user docs, and the master roadmap.

**Tech Stack:** Zig 0.16.0, `std.json`, `std.crypto.hash.sha2.Sha256`, existing zigeffect build steps, Bun root verification.

---

## File Structure

- Modify `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_policy.zig`
  to keep generated policy JSON parseable and test that invariant.
- Create `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_evaluator.zig`
  for CLI parsing, source policy validation, request/evidence classification,
  evaluation, artifact rendering, and unit tests.
- Modify `packages/zigeffect/build.zig` to add the executable and test step
  after the app-facing consumption-policy tool.
- Create `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator.md`
  for command examples, source contract, request/evidence classes, evaluation
  statuses, denied claims, and next-branch handoff.
- Modify `packages/zigeffect/tools/causal_schema_governance.zig` and generated
  `packages/zigeffect/docs/schema-governance.md` for the new schema.
- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig` and
  generated `packages/zigeffect/docs/production-hardening-backlog.md` to mark
  this milestone delivered and advance the recommendation.
- Modify
  `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  to mark branch 61 delivered and add branch 62 for the consumption report.

## Tasks

### Task 1: Fix Policy JSON Regression

- [x] Add a failing test to
  `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_policy.zig`
  that parses generated ready policy JSON with `std.json.parseFromSlice`.
- [x] Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_policy.zig
```

Expected result before the fix: syntax error from malformed JSON.

- [x] Add the missing comma separator after `agent_guidance`.
- [x] Rerun the policy test until all tests pass.
- [x] Regenerate the ready consumption-policy artifact and confirm `jq` parses
  it.

### Task 2: Red Test The Consumption Evaluator Producer

- [x] Add the new Zig file with failing tests for constants, CLI parsing,
  output suffix replacement, request/evidence classification, ready output,
  advisory output, invalid source blocking, denied request/evidence blocking,
  disabled authority, denied claims, next queries, and next-branch guidance.
- [x] Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_evaluator.zig
```

Expected first result: compile failure or failing tests because implementation
constants/functions are not present yet.

### Task 3: Implement The Evaluator

- [x] Implement constants:
  - schema:
    `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator.v1`;
  - source schema:
    `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-policy.v1`;
  - tool:
    `causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator`;
  - next branch:
    `codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report`.
- [x] Implement option parsing for:
  `--from-policy`, `evaluate`, `--reason`, `--request`, `--evidence`, `--by`,
  `--policy`, and `--out-prefix`.
- [x] Implement source policy validation for ready consumption-policy evidence,
  disabled CI/GitHub/app/runtime/storage/deployment authority, source refs,
  policy checks, interpretation rules, consumption scopes, denied inference
  rules, negative fixtures, blocked claims, SolidJS WebUI scope, and
  verification evidence.
- [x] Implement request/evidence classification for `request_json`,
  `request_text`, `policy_json`, `causal_json`, `causal_text`,
  `workbench_text`, and `denied`.
- [x] Implement denied-content checks for secrets, raw prompt/response/payload
  markers, mutation claims, CI enforcement, GitHub mutation, app runtime
  integration, live projection, durable/NenDB writes, adapter execution,
  Cockroach, deployment, production health, alternate renderers, auto-apply,
  and public artifact upload claims.
- [x] Implement evaluation statuses:
  `ready`, `advisory-findings`, and `blocked`.
- [x] Render JSON and text artifacts with source refs, file analysis, checks,
  signal evaluations, findings, denied claims, redaction posture, next queries,
  disabled authority fields, and next-branch guidance.
- [x] Run the Zig test command until it passes.

### Task 4: Wire Build And Generate Artifacts

- [x] Add the build executable/test step.
- [x] Write local safe request/support fixtures:

```sh
mkdir -p ../../.zig-cache/causal-artifacts
printf '%s\n' \
  '{"request_id":"agent-bounded-context","consumer_role":"agent-readonly","requested_fields":["source ids","policy rules","guardrails","denied claims"],"redaction":"redacted","raw_payload_capture_enabled":false,"mutation_authority":"none"}' \
  > ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-request.json
printf '%s\n' \
  'SolidJS webui-dev/zig-webui read-only consumption support evidence with redacted source ids and no mutation authority.' \
  > ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-support.txt
printf '%s\n' \
  '{"request_id":"unsafe-runtime","app_runtime_integration_enabled":true}' \
  > ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-request-unsafe.json
```

- [x] Run:

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator -- --help
```

- [x] Generate a ready evaluator artifact:

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator -- \
  --from-policy ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-policy.json \
  evaluate \
  --reason "reviewed app-facing advisory remediation report consumption evaluator" \
  --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-request.json \
  --evidence ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-support.txt
```

- [x] Generate an advisory evaluator artifact:

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator -- \
  --from-policy ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-policy.json \
  evaluate \
  --reason "advisory app-facing consumption evaluator missing support evidence" \
  --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-request.json \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-evaluator-advisory
```

- [x] Generate a blocked evaluator artifact:

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator -- \
  --from-policy ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-policy.json \
  evaluate \
  --reason "blocked app-facing consumption evaluator unsafe request" \
  --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-request-unsafe.json \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-evaluator-blocked
```

### Task 5: Governance, Backlog, Docs, Roadmap

- [x] Register the schema in `causal_schema_governance.zig`.
- [x] Update schema count tests from `96` to `97` and add text/JSON coverage
  assertions for the new schema.
- [x] Add this milestone to `causal_production_hardening_backlog.zig` and move
  the recommendation to the consumption-report branch.
- [x] Add ready/advisory/blocked evaluator commands to backlog verification
  commands.
- [x] Add the user-facing docs file.
- [x] Update the master roadmap branch 61 to delivered and add branch 62 for
  the consumption-report milestone.
- [x] Regenerate:

```sh
cd packages/zigeffect
zig build causal-schema-governance > docs/schema-governance.md 2>&1
zig build causal-production-hardening-backlog > docs/production-hardening-backlog.md 2>&1
```

### Task 6: Verify And Commit

- [x] Run:

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
```

- [x] Run:

```sh
bun run check
bun run zig:test
git diff --check
```

- [x] Stage and commit:

```sh
git add docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md \
  docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator-design.md \
  docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator-implementation.md \
  packages/zigeffect/build.zig \
  packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator.md \
  packages/zigeffect/docs/production-hardening-backlog.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_evaluator.zig \
  packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_policy.zig \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  packages/zigeffect/tools/causal_schema_governance.zig
git commit -m "feat(zigeffect): add app-facing advisory report consumption evaluator"
```
