# zigeffect Causal Production Telemetry CI Archive Application Design

## Summary

Add a guarded production telemetry CI archive application contract for
zigeffect. The contract consumes a ready
`zigeffect.causal.production-telemetry-ci-harness-boundary.v1` artifact and
emits an application artifact that agents can use to distinguish a reviewed
archive plan from an actually applied CI workflow/archive change.

This branch does not edit `.github/workflows/zigeffect-causal.yml`, upload
artifacts, enable telemetry gates, configure secrets, ingest live telemetry,
write NenDB, write durable state, deploy infrastructure, or execute CI. It only
records whether the evidence is sufficient to plan the next workflow/archive
change or to record that a separately reviewed change was applied.

## Branch

- Branch:
  `codex/zigeffect-causal-production-telemetry-ci-archive-application`
- Schema:
  `zigeffect.causal.production-telemetry-ci-archive-application.v1`
- Command:
  `zig build causal-production-telemetry-ci-archive-application`
- Recommendation after delivery:
  `start-production-telemetry-ci-archive-evidence-policy`
- Next branch if applied:
  `codex/zigeffect-causal-production-telemetry-ci-archive-evidence-policy`

## Context

The previous milestone delivered
`causal-production-telemetry-ci-harness-boundary`. It consumes the CI artifact
preview, inspects `.github/workflows/zigeffect-causal.yml`, records the
cluster-aware release gate assumptions, and keeps workflow mutation, upload
execution, CI gates, live telemetry, runtime pipelines, durable writes, and
NenDB writes disabled.

The next missing boundary is an application record. Agents need to know whether
the archive configuration is only planned or whether a human-reviewed workflow
change really happened and was checked afterward. The distinction matters
because a ready harness boundary proves that the current CI shape is safe to
reason about; it does not prove that a telemetry archive change was made.

## Goals

1. Add a schema-governed archive application record.
2. Consume a CI harness boundary JSON artifact from disk.
3. Support two modes:
   - `plan`: produce an unapplied application plan when the source harness
     boundary is ready.
   - `record-applied`: produce `applied=true` only when a separately reviewed
     workflow/archive change, before evidence, after evidence, and required
     post-application verification are all present.
4. Validate the source harness boundary schema, ready status, reviewer
   approval, next-branch handoff, disabled authority flags, source workflow
   digest, workflow required/prohibited checks, upload policy, artifact
   candidates, blocked claims, cluster release-gate assumptions, and source
   verification evidence.
5. Require explicit `--reason` and explicit `--verified-command` evidence for
   `record-applied`.
6. Require `--workflow-change`, `--before`, and `--after` evidence for
   `record-applied`.
7. Require the after-workflow evidence to preserve bounded archive constraints:
   failure-only upload, `actions/upload-artifact@v4`,
   `if-no-files-found: ignore`, `retention-days: 14`, causal `.txt`, `.json`,
   and `.dot` globs, release-gate `.txt` and `.json` globs, read-only
   permissions, no secrets, no write permissions, no schedule, no OTLP endpoint,
   no production telemetry token, no deploy action, and no telemetry gate.
8. Keep `plan` mode strictly record-only:
   `applied=false`, `mutation_authority="none"`, no upload execution claim,
   no workflow mutation claim, and no CI gate claim.
9. Allow `record-applied` to set `applied=true` only as a record of external
   reviewed change evidence. The tool itself still has no mutation authority.
10. Update schema governance, production hardening backlog, README, operations,
    roadmap, completion audit, CI harness docs, and the master roadmap.

## Non-Goals

- No workflow file mutation by this tool.
- No new GitHub Actions workflow.
- No artifact upload execution from local tooling.
- No required status check, protected branch configuration, telemetry gate, or
  threshold enforcement.
- No GitHub secret creation, collector endpoint, OIDC permission, deployment
  action, or external telemetry upload destination.
- No live telemetry ingestion, runtime telemetry pipeline, OTLP serialization,
  exporter network send, NenDB write, durable write, hosted dashboard, alert
  delivery, rollout automation, or production cluster claim.
- No non-NenDB durable adapter scope and no Cockroach durable scope.
- No React renderer or alternate renderer decision. Workbench direction remains
  SolidJS inside `webui-dev/zig-webui`.

## Recommended Approach

Create one deterministic Zig tool,
`causal-production-telemetry-ci-archive-application`, that mirrors the guarded
application pattern already used by app and registry application tools:

1. Read a source CI harness boundary JSON artifact.
2. Parse and validate
   `zigeffect.causal.production-telemetry-ci-harness-boundary.v1`.
3. Fail closed unless the source boundary is `ready`,
   `ready_for_next_branch=true`, and reviewer decision is `approve`.
4. Check that source authority remains disabled and that workflow required and
   prohibited checks passed.
5. In `plan` mode, emit a planned application artifact with skipped evidence
   checks and `applied=false`.
6. In `record-applied` mode, require:
   - at least one `--workflow-change` citation;
   - at least one `--before` evidence citation;
   - at least one `--after` evidence citation;
   - every required verification command recorded;
   - after-workflow archive constraints still pass.
7. Emit JSON and text artifacts beside the source harness boundary input or at
   an explicit output prefix.
8. Update governance and backlog so the next branch starts from the
   machine-readable application record rather than a conversational summary.

This approach is useful because it gives development agents a concrete
question to answer before they claim progress: "Was a real archive change made
and verified, or are we still at plan-only evidence?"

Rejected approaches:

- Mutating the workflow in this tool. Application records should verify and
  cite external changes, not perform them silently.
- Treating the existing harness boundary as applied archive evidence. It
  inspects workflow shape but deliberately does not claim application.
- Enabling a CI telemetry gate. Gate policy needs a later threshold and failure
  semantics branch.
- Uploading or inspecting GitHub artifact storage from the local tool. The
  local contract should stay deterministic and file-based.

## Command Contract

Plan mode:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-archive-application -- \
  --from-harness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary.json \
  plan \
  --reason "CI archive application planned from reviewed harness boundary"
```

Record-applied mode:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-archive-application -- \
  --from-harness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary.json \
  record-applied \
  --reason "reviewed archive workflow change applied" \
  --workflow-after ../../.github/workflows/zigeffect-causal.yml \
  --workflow-change ".github/workflows/zigeffect-causal.yml" \
  --before "ci-harness-boundary workflow digest" \
  --after "post-change workflow review" \
  --verified-command "zig build causal-production-telemetry-ci-harness-boundary" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Parser rules:

- `--from-harness <ci-harness-boundary.json>` is required.
- Mode must be `plan` or `record-applied`.
- `--reason <reason>` is required and non-empty.
- `--by <actor>` defaults to `ci-archive-application-reviewer`.
- `--policy <policy>` defaults to
  `manual-production-telemetry-ci-archive-application`.
- `--workflow-after <workflow.yml>` is optional in `plan` mode and required in
  `record-applied` mode.
- `--workflow-change`, `--before`, `--after`, and `--verified-command` may be
  supplied multiple times.
- `--out-prefix <path-prefix>` overrides default output paths.

## Artifact Model

Top-level fields:

- `schema`
- `schema_version`
- `source_ci_harness_boundary`
- `source_ci_artifact_preview`
- `source_workbench_preview`
- `workflow_path`
- `source_workflow_digest`
- `after_workflow_path`
- `after_workflow_digest`
- `mode`
- `application_status`
- `applied`
- `mutation_authority`
- `ci_archive_application_enabled`
- `ci_upload_enabled`
- `ci_upload_execution_enabled`
- `ci_workflow_mutation_enabled`
- `ci_gate_enabled`
- `production_telemetry_ingestion`
- `live_exporter_enabled`
- `network_send_enabled`
- `collector_endpoint_configured`
- `otlp_serialization_enabled`
- `runtime_pipeline_enabled`
- `durable_write_enabled`
- `nendb_write_enabled`
- `reviewed_by`
- `policy`
- `reason`
- `workflow_changes`
- `before_evidence`
- `after_evidence`
- `source_checks`
- `checks`
- `required_verification_commands`
- `verified_commands`
- `application_steps`
- `guardrails`
- `blocked_claims`
- `recommendation`
- `next_branch_if_applied`
- `agent_guidance`

`applied=true` means the artifact has enough evidence to record that a
reviewed archive workflow change was applied outside this tool. It does not
mean this tool mutated GitHub Actions or executed artifact uploads.

## Testing

- Unit tests cover constants, option parsing, `plan`, `record-applied`, blocked
  source boundary evidence, and prohibited after-workflow features.
- Red path: before build wiring, `zig build
  causal-production-telemetry-ci-archive-application -- --help` must fail with
  an unknown step.
- Green path:
  `zig test tools/causal_production_telemetry_ci_archive_application.zig`,
  ready plan command, negative blocked command,
  `zig build causal-schema-governance -- --format json`,
  `zig build causal-production-hardening-backlog -- --format json`,
  `zig build examples`, `zig build test`, `bun run check`,
  `bun run zig:test`, and `git diff --check`.

