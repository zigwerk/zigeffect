# zigeffect Causal Production Telemetry CI Harness Boundary Design

## Summary

Add a production telemetry CI harness boundary contract for zigeffect. The
contract consumes a ready
`zigeffect.causal.production-telemetry-ci-artifact-preview.v1` artifact,
inspects the current repository CI workflow shape, and emits a record-only
boundary report that tells agents and reviewers exactly what the existing
causal CI harness already does, what a later telemetry archive application may
touch, and which claims remain blocked.

This branch does not modify `.github/workflows/zigeffect-causal.yml`, upload
artifacts, enable telemetry gates, configure secrets, ingest live telemetry,
write NenDB, write durable state, or grant mutation authority.

## Branch

- Branch:
  `codex/zigeffect-causal-production-telemetry-ci-harness-boundary`
- Schema:
  `zigeffect.causal.production-telemetry-ci-harness-boundary.v1`
- Command:
  `zig build causal-production-telemetry-ci-harness-boundary`
- Recommendation after delivery:
  `start-production-telemetry-ci-archive-application`
- Next branch if ready:
  `codex/zigeffect-causal-production-telemetry-ci-archive-application`

## Context

The local `master` branch has been merged into this branch state. Git reported
`Already up to date`, and `master` is an ancestor of the harness-boundary
branch, so this work includes the latest local clustering and causal Zig code.

The repository currently has one causal GitHub Actions workflow at
`.github/workflows/zigeffect-causal.yml`. Its current responsibilities are:

- run on zigeffect-relevant pull requests, pushes to `master`, and manual
  dispatches;
- use `permissions: contents: read`;
- set up Zig `0.16.0` with `mlugg/setup-zig@v2.2.1`;
- on pull requests, capture base causal baselines by running
  `zig build causal-test` and `zig build causal-dev-loop -- baseline
  package-tests` in a base worktree;
- print the causal artifact manifest with `zig build causal-artifacts`;
- run the durable workflow and cluster release gate with
  `zig build release-gate --summary none`;
- on failure, write a causal CI handoff with `zig build causal-ci-handoff`;
- on failure, upload causal and release-gate `.txt`, `.json`, and `.dot`
  evidence using `actions/upload-artifact@v4`, `if-no-files-found: ignore`, and
  `retention-days: 14`.

The zigeffect build now has a real clustering release-gate surface. The
`release-gate` step depends on the main test suite, public API review, storage
conformance, property crash testing, performance bounds, examples,
`causal-test`, causal artifact generation, release-gate report generation, and
cluster example tests including the multi-runner cluster and cluster workflow
migration examples. That means the CI harness boundary can cite the existing
release gate as the clustering-aware execution body, while still refusing to
claim production telemetry upload execution or telemetry gates.

The previous milestone delivered a CI artifact preview. It answers: "Which
production telemetry evidence files may a future CI harness archive?" This
milestone answers the next question: "Does the current CI harness shape have a
reviewed boundary for using that catalog later?"

## Goals

1. Add a schema-governed CI harness boundary record.
2. Consume a CI artifact preview JSON artifact from disk so agents can cite the
   exact reviewed artifact-candidate handoff.
3. Inspect `.github/workflows/zigeffect-causal.yml` from disk without
   modifying it.
4. Require an explicit `approve` or `reject` decision and non-empty reason.
5. Require explicit verification command evidence before the boundary can be
   `ready`.
6. Verify the source preview schema, ready status, reviewer decision,
   next-branch handoff, disabled authority flags, upload policy, artifact
   candidates, source verification commands, and blocked claims.
7. Verify the workflow has the required causal harness features:
   `workflow_dispatch`, `pull_request`, `push` to `master`,
   `permissions: contents: read`, Zig `0.16.0`, base causal baseline capture,
   `zig build causal-artifacts`, `zig build release-gate --summary none`,
   failure-only `zig build causal-ci-handoff`, failure-only
   `actions/upload-artifact@v4`, `if-no-files-found: ignore`,
   `retention-days: 14`, causal artifact globs, and release-gate artifact
   globs.
8. Verify the workflow remains bounded: no telemetry collector endpoint, no
   live telemetry env vars, no secrets usage, no write permissions, no
   scheduled production polling, no push to non-`master` protected branches,
   no external telemetry upload endpoint, and no production deployment step.
9. Record the clustering release-gate assumptions that the boundary relies on:
   `release-gate`, storage conformance, property crash testing, performance
   bounds, examples, `causal-test`, causal artifacts, release-gate report,
   multi-runner cluster example tests, and cluster workflow migration tests.
10. Emit text and JSON artifacts with workflow checks, source-preview checks,
    allowed future workflow patch scope, explicitly disallowed workflow patch
    scope, clustering harness assumptions, implementation gates, blocked
    claims, required commands, recorded commands, and next branch.
11. Preserve `applied=false`, `mutation_authority="none"`,
    `production_telemetry_ingestion=false`, `live_exporter_enabled=false`,
    `network_send_enabled=false`, `collector_endpoint_configured=false`,
    `otlp_serialization_enabled=false`, `runtime_pipeline_enabled=false`,
    `durable_write_enabled=false`, `nendb_write_enabled=false`,
    `ci_upload_enabled=false`, `ci_upload_execution_enabled=false`,
    `ci_workflow_mutation_enabled=false`, and `ci_gate_enabled=false`.
12. Keep durable production direction NenDB-only and workbench direction
    SolidJS inside `webui-dev/zig-webui`.
13. Update schema governance, production hardening backlog, README,
    operations, roadmap, completion audit, CI artifact preview docs, and the
    master roadmap.

## Non-Goals

- No modification to `.github/workflows/zigeffect-causal.yml`.
- No new GitHub Actions workflow.
- No artifact upload execution beyond documenting the existing general
  failure-only causal upload shape.
- No CI telemetry gate, threshold, benchmark gate, required status check, or
  protected-branch enforcement.
- No GitHub secret creation, environment configuration, collector endpoint, or
  external telemetry upload destination.
- No live telemetry ingestion, runtime telemetry pipeline, exporter network
  send, OTLP serialization, or production instrumentation change.
- No NenDB writes, durable production writes, compaction execution, backup
  execution, or restore execution.
- No cluster daemon orchestration, production cluster deployment, hosted
  dashboard claim, RBAC, alert delivery, rollout automation, or production
  capacity claim.
- No non-NenDB adapter scope, Cockroach durable scope, React renderer, or
  alternate renderer.
- No source, config, registry, deployment, rollout, app, or production mutation
  authority.

## Recommended Approach

Create one deterministic Zig tool,
`causal-production-telemetry-ci-harness-boundary`, that mirrors the recent
review-tool pattern:

1. Read a CI artifact preview JSON artifact from disk.
2. Read `.github/workflows/zigeffect-causal.yml` from disk.
3. Parse and validate
   `zigeffect.causal.production-telemetry-ci-artifact-preview.v1`.
4. Fail closed unless the source preview is `ready`,
   `ready_for_next_branch=true`, and reviewer decision is `approve`.
5. Check that all live, network, runtime, durable, NenDB, CI upload execution,
   CI workflow mutation, and CI gate authority fields remain disabled.
6. Check that the source preview contains a preview-only upload policy,
   failure-only artifact candidates, allowlisted extensions, source workbench
   evidence, source retention evidence, and required verification evidence.
7. Evaluate the workflow text for required harness capabilities and prohibited
   mutation/secret/live-telemetry patterns.
8. Record clustering release-gate assumptions from the current build contract
   as explicit report fields.
9. Mark the boundary `ready` only when the reviewer approves, all source checks
   pass, all workflow checks pass, and every required verification command is
   recorded.
10. Write JSON and text artifacts beside the CI preview input or at an explicit
    output prefix.
11. Print the text report for local review.

This is the recommended approach because it gives agents a parseable boundary
before any workflow application branch. It lets a later branch propose or apply
the smallest reviewed workflow change with before/after verification, while
this branch stays record-only.

Rejected approaches:

- Mutating the GitHub Actions workflow here: the previous milestone explicitly
  stopped before workflow mutation, and this milestone should make the review
  boundary precise before changing CI.
- Uploading artifacts from the tool: local tools should not mutate CI state or
  remote artifacts.
- Enabling `ci_gate_enabled=true`: a telemetry gate needs threshold, failure,
  redaction, retention, and reviewer policy evidence in a later branch.
- Trusting the workflow by name only: agents need exact feature checks and
  prohibited-pattern checks, not just a path string.
- Documentation-only boundary: useful to humans, but too weak for agents
  because workflow assumptions, disabled authority, and next-branch gates
  cannot be parsed.

## Command Contract

Default invocation:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-harness-boundary -- \
  --from-ci-preview ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview.json \
  --workflow ../../.github/workflows/zigeffect-causal.yml \
  approve \
  --reason "CI harness boundary reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-artifact-preview" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Parser rules:

- `--from-ci-preview <ci-artifact-preview.json>` is required.
- `--workflow <path>` is optional and defaults to
  `../../.github/workflows/zigeffect-causal.yml` when run from
  `packages/zigeffect`.
- The input preview path must end with `.json`.
- The workflow path must end with `.yml` or `.yaml`.
- Decision must be `approve` or `reject`.
- `--reason <reason>` is required and non-empty.
- `--by <actor>` is optional and defaults to
  `ci-harness-boundary-reviewer`.
- `--policy <policy>` is optional and defaults to
  `manual-production-telemetry-ci-harness-boundary`.
- `--verified-command <command>` may be supplied multiple times.
- `--out-prefix <path-prefix>` is optional. Without it, output paths are
  derived from the CI preview JSON path by appending `-ci-harness-boundary`.
- Unknown flags, missing values, unsupported decisions, unsupported schemas,
  missing source evidence, and missing workflow evidence fail closed.

## Artifact Model

Top-level fields:

- `schema`
- `schema_version`
- `source_ci_artifact_preview`
- `source_workbench_preview`
- `source_retention`
- `source_local_pipeline`
- `source_boundary`
- `source_proposal`
- `source_readiness`
- `source_fixtures`
- `workflow_path`
- `workflow_digest`
- `decision`
- `ci_harness_boundary_status`
- `ready_for_next_branch`
- `reviewed_by`
- `policy`
- `reason`
- `applied`
- `mutation_authority`
- `production_telemetry_ingestion`
- `live_exporter_enabled`
- `network_send_enabled`
- `collector_endpoint_configured`
- `otlp_serialization_enabled`
- `runtime_pipeline_enabled`
- `durable_write_enabled`
- `nendb_write_enabled`
- `ci_upload_enabled`
- `ci_upload_execution_enabled`
- `ci_workflow_mutation_enabled`
- `ci_gate_enabled`
- `ci_harness_boundary_enabled`
- `source_branch`
- `recommendation`
- `next_branch_if_ready`
- `source_preview_checks`
- `workflow_required_features`
- `workflow_prohibited_features`
- `allowed_future_workflow_patch_scope`
- `disallowed_future_workflow_patch_scope`
- `artifact_upload_policy`
- `artifact_candidates`
- `cluster_release_gate_assumptions`
- `checks`
- `required_verification_commands`
- `verified_commands`
- `implementation_gates`
- `non_goals`
- `blocked_claims`
- `agent_guidance`

`ci_harness_boundary_status` is:

- `ready` when the reviewer approves, the source CI artifact preview is
  schema v1, ready, next-branch-ready, authority-disabled, preview-only,
  failure-only, and verified; the workflow has every required feature; the
  workflow lacks every prohibited feature; and every required command is
  recorded.
- `blocked` when the reviewer rejects, source preview evidence is blocked, the
  workflow contract is missing, prohibited workflow features are present,
  authority is enabled, artifact candidates violate policy, or required
  verification command evidence is missing.

## Workflow Checks

Required workflow features:

- `.github/workflows/zigeffect-causal.yml` exists and is readable.
- `name: zigeffect causal`.
- `pull_request` trigger includes zigeffect-relevant paths.
- `push` trigger targets `master`.
- `workflow_dispatch` exists.
- `permissions` are `contents: read`.
- checkout uses `actions/checkout@v4`.
- Zig setup uses `mlugg/setup-zig@v2.2.1` and version `0.16.0`.
- PR baseline capture runs `zig build causal-test`.
- PR baseline capture runs `zig build causal-dev-loop -- baseline
  package-tests`.
- manifest step runs `zig build causal-artifacts`.
- release gate runs `zig build release-gate --summary none`.
- failure handoff runs `zig build causal-ci-handoff`.
- upload step is guarded by `if: ${{ failure() }}`.
- upload step uses `actions/upload-artifact@v4`.
- upload step uses `if-no-files-found: ignore`.
- upload step uses `retention-days: 14`.
- upload paths include causal `.txt`, `.json`, and `.dot` artifacts.
- upload paths include release-gate `.txt` and `.json` artifacts.

Prohibited workflow features:

- `secrets.` usage.
- `permissions: write-all`.
- `contents: write`.
- `id-token: write`.
- `schedule:` trigger.
- non-`master` protected push branches.
- telemetry collector endpoint environment variables.
- OTLP endpoint environment variables.
- production telemetry API keys.
- `curl` or `wget` to a telemetry endpoint.
- deployment actions.
- NenDB production write commands.
- workflow steps named as production telemetry gate enforcement.

This branch uses conservative substring checks rather than a general YAML
parser because the workflow contract is small, stable, and intentionally
reviewed by exact text. A future workflow application branch may move to a
structured YAML parser if workflow mutations become programmatic.

## Clustering Harness Boundary

The boundary records that production telemetry CI work must respect the
clustering release-gate surface that now exists on `master`:

- `zig build release-gate --summary none` is the CI execution body for durable
  workflow and clustering health.
- `release-gate` depends on `storage-conformance`, `property-crash`,
  `performance-bounds`, `examples`, `causal-test`, `causal-artifacts`, and
  release-gate report generation.
- `examples` includes multi-runner cluster and cluster workflow migration
  examples plus their tests.
- The harness boundary does not start cluster daemons, provision infrastructure,
  run production shards, or claim production cluster readiness.

The report should expose these assumptions so an agent debugging future CI
failures knows whether it is looking at causal artifact policy, the general
release gate, or clustering-specific examples/tests.

## Allowed Future Workflow Patch Scope

A later workflow application branch may propose, review, and verify only these
changes:

- add a telemetry-specific preview artifact generation step that consumes the
  CI harness boundary artifact;
- add archive paths for the generated telemetry CI boundary/preview artifacts;
- keep upload failure-only;
- keep retention bounded at 14 days unless a later retention policy updates it;
- keep missing files ignored for preview-only evidence;
- keep `permissions: contents: read`;
- keep secrets absent;
- keep gates disabled.

## Disallowed Future Workflow Patch Scope

A later workflow application branch may not use this boundary to justify:

- CI gate enforcement;
- required status checks;
- production telemetry threshold failures;
- live exporter network sends;
- collector endpoint configuration;
- secret use;
- write permissions;
- NenDB writes;
- durable production writes;
- hosted dashboard deployment;
- production cluster orchestration;
- app or registry mutation authority.

## Output Paths

For this input:

```text
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview.json
```

default output paths are:

```text
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary.json
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary.txt
```

Use `--out-prefix <path-prefix>` to choose a custom artifact prefix.

## Agent Guidance

Agents may use a `ready` CI harness boundary to start
`codex/zigeffect-causal-production-telemetry-ci-archive-application`. They must
cite the source CI artifact preview, workflow path and digest, workflow
required/prohibited checks, upload policy preview, clustering release-gate
assumptions, authority boundary, required commands, recorded commands, and
blocked claims.

Agents must treat `blocked` CI harness boundaries as stop signs. Blocked
artifacts can guide source preview or workflow-boundary repair, but they cannot
justify CI upload configuration, CI gate work, workflow mutation, live
telemetry, durable writes, hosted dashboard claims, production cluster claims,
or mutation authority.

## Verification

Branch verification should include:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_harness_boundary.zig
zig build causal-production-telemetry-ci-harness-boundary -- \
  --from-ci-preview ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview.json \
  --workflow ../../.github/workflows/zigeffect-causal.yml \
  approve \
  --reason "CI harness boundary reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-artifact-preview" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-production-telemetry-ci-harness-boundary -- \
  --from-ci-preview ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview.json \
  --workflow ../../.github/workflows/zigeffect-causal.yml \
  reject \
  --reason "negative CI harness boundary path"
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
```

Repository-level verification:

```sh
bun run check
bun run zig:test
git diff --check
git merge-base --is-ancestor master HEAD
```

## Open Questions

- Should the later archive application branch mutate
  `.github/workflows/zigeffect-causal.yml`, or should it first generate a
  patch artifact for review? Recommended answer: generate and review a patch
  artifact first if the branch detects any ambiguity in workflow placement.
- Should telemetry boundary artifacts be archived on all failures or only when
  telemetry preview generation runs? Recommended answer: archive on failure
  only, with `if-no-files-found: ignore`, until a real gate exists.
- Should workflow inspection eventually use a structured YAML parser?
  Recommended answer: yes only when mutation becomes programmatic; exact
  substring checks are adequate for this boundary branch.
