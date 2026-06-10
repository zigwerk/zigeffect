# zigeffect Causal Production Telemetry CI Artifact Preview Design

## Summary

Add a production telemetry CI artifact preview contract for zigeffect. The
contract consumes a ready
`zigeffect.causal.production-telemetry-workbench-readonly-preview.v1` artifact
and emits a record-only CI preview artifact that tells agents and reviewers
which production telemetry evidence files a later CI harness may archive, how
long those files should be retained, and which claims remain blocked.

This branch does not add a new GitHub Actions workflow, modify the existing
general causal CI workflow, upload artifacts, enable telemetry gates, fail CI on
telemetry thresholds, ingest live telemetry, write NenDB, write durable state,
or grant mutation authority.

## Branch

- Branch:
  `codex/zigeffect-causal-production-telemetry-ci-artifact-preview`
- Schema:
  `zigeffect.causal.production-telemetry-ci-artifact-preview.v1`
- Command:
  `zig build causal-production-telemetry-ci-artifact-preview`
- Recommendation after delivery:
  `start-production-telemetry-ci-harness-boundary`
- Next branch if ready:
  `codex/zigeffect-causal-production-telemetry-ci-harness-boundary`

## Context

The production telemetry chain has delivered these evidence boundaries:

1. capture design;
2. safe fixture catalog;
3. readiness review;
4. implementation proposal;
5. no-network exporter boundary;
6. local pipeline fixtures;
7. NenDB retention fixtures;
8. read-only SolidJS `webui-dev/zig-webui` workbench preview.

The workbench preview proves that humans and agents can inspect source
telemetry fixture evidence, mapping fixtures, validation checks, authority
flags, blocked claims, and verification commands without enabling live
telemetry or writes.

The next useful artifact is not a CI gate. It is a CI artifact preview: a
machine-readable catalog of allowed archive candidates and failure attachments
for a future telemetry CI harness. That gives agents a stable answer to: "Which
files may CI preserve, what do they prove, and what must not be inferred from
them?"

## Goals

1. Add a schema-governed CI artifact preview record.
2. Consume a workbench-preview JSON artifact from disk so agents can cite the
   exact reviewed UI/evidence handoff.
3. Require an explicit `approve` or `reject` decision and non-empty reason.
4. Require explicit verification command evidence before the preview can be
   `ready`.
5. Verify workbench source schema, ready status, reviewer decision, disabled
   authority flags, source-retention link, mapping fixture evidence, source
   checks, workbench verification commands, and CI artifact allowlist rules.
6. Emit text and JSON artifacts with CI archive candidates, upload/retention
   preview policy, required and recorded commands, checks, blocked claims, and
   next branch.
7. Preserve `applied=false`, `mutation_authority="none"`,
   `production_telemetry_ingestion=false`, `live_exporter_enabled=false`,
   `network_send_enabled=false`, `collector_endpoint_configured=false`,
   `otlp_serialization_enabled=false`, `runtime_pipeline_enabled=false`,
   `durable_write_enabled=false`, `nendb_write_enabled=false`, and
   `ci_gate_enabled=false`.
8. Keep durable production direction NenDB-only and workbench direction
   SolidJS inside `webui-dev/zig-webui`.
9. Update schema governance, production hardening backlog, README, operations,
   roadmap, completion audit, production telemetry docs, and the master
   roadmap.

## Non-Goals

- No new GitHub Actions workflow and no modification to
  `.github/workflows/zigeffect-causal.yml`.
- No artifact upload, artifact download, CI retention mutation, or CI secret
  configuration.
- No CI failure gate, telemetry threshold, benchmark threshold, or required
  status check.
- No live telemetry ingestion, runtime telemetry pipeline, exporter network
  send, collector endpoint, or OTLP serialization.
- No NenDB writes, durable production writes, compaction execution, backup
  execution, or restore execution.
- No production dashboard hosting, RBAC, alert delivery, rollout automation, or
  production capacity claim.
- No non-NenDB adapter scope, Cockroach durable scope, React renderer, or
  alternate renderer.
- No source, config, registry, deployment, rollout, app, or production mutation
  authority.

## Recommended Approach

Create one deterministic Zig tool,
`causal-production-telemetry-ci-artifact-preview`, that mirrors the recent
review-tool pattern:

1. Read a workbench preview JSON artifact from disk.
2. Parse and validate
   `zigeffect.causal.production-telemetry-workbench-readonly-preview.v1`.
3. Fail closed unless the source preview is `ready`,
   `ready_for_next_branch=true`, and reviewer decision is `approve`.
4. Check that all live, network, runtime, durable, NenDB, and CI-gate authority
   fields remain disabled.
5. Carry forward source paths, mapping fixture ids, validation checks, blocked
   claims, and source verification evidence.
6. Emit a fixed CI artifact candidate catalog for later archive work.
7. Mark the preview `ready` only when the reviewer approves, all checks pass,
   required artifact candidates are present, upload globs are allowlisted, and
   every required verification command is recorded.
8. Write JSON and text artifacts beside the workbench input or at an explicit
   output prefix.
9. Print the text report for local review.

This is the recommended approach because it gives agents a concrete, parseable
handoff to future CI harness work without mutating CI configuration. It also
keeps artifact archiving policy reviewable before any workflow or gate changes.

Rejected approaches:

- Adding a GitHub Actions workflow here: the repo already has a general causal
  workflow, and this milestone is about telemetry-specific archive shape rather
  than CI execution.
- Uploading artifacts from the tool: local tools should not mutate CI state or
  remote artifacts.
- Enabling `ci_gate_enabled=true`: a gate needs a later branch with threshold,
  failure, redaction, retention, and reviewer policy evidence.
- Documentation-only preview: useful to humans, but too weak for agents because
  the artifact candidates, checks, and blocked claims cannot be parsed.

## Command Contract

Default invocation:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-artifact-preview -- \
  --from-workbench ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview.json \
  approve \
  --reason "CI artifact preview reviewed" \
  --verified-command "zig build causal-production-telemetry-workbench-readonly-preview" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Parser rules:

- `--from-workbench <workbench-preview.json>` is required.
- The input path must end with `.json`.
- Decision must be `approve` or `reject`.
- `--reason <reason>` is required and non-empty.
- `--by <actor>` is optional and defaults to `ci-artifact-preview-reviewer`.
- `--policy <policy>` is optional and defaults to
  `manual-production-telemetry-ci-artifact-preview`.
- `--verified-command <command>` may be supplied multiple times.
- `--out-prefix <path-prefix>` is optional. Without it, output paths are
  derived from the workbench JSON path by appending `-ci-artifact-preview`.
- Unknown flags, missing values, unsupported decisions, unsupported schemas,
  and missing source evidence fail closed.

## Artifact Model

Top-level fields:

- `schema`
- `schema_version`
- `source_workbench_preview`
- `source_retention`
- `source_local_pipeline`
- `source_boundary`
- `source_proposal`
- `source_readiness`
- `source_fixtures`
- `decision`
- `ci_artifact_preview_status`
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
- `ci_gate_enabled`
- `ci_upload_enabled`
- `ci_workflow_mutation_enabled`
- `ci_artifact_preview_enabled`
- `source_branch`
- `recommendation`
- `next_branch_if_ready`
- `artifact_upload_policy`
- `artifact_candidates`
- `mapping_fixture_ids`
- `checks`
- `required_verification_commands`
- `verified_commands`
- `implementation_gates`
- `non_goals`
- `blocked_claims`
- `agent_guidance`

`ci_artifact_preview_status` is:

- `ready` when the reviewer approves, the source workbench preview artifact is
  ready, every CI preview check passes, every artifact candidate is allowed,
  and every required verification command is recorded.
- `blocked` when the reviewer rejects, source workbench evidence is blocked,
  an authority field is enabled, an artifact candidate violates policy, or
  verification evidence is missing.

`ready_for_next_branch=true` means a later
`codex/zigeffect-causal-production-telemetry-ci-harness-boundary` branch may be
started. It does not approve CI upload execution, CI gates, live ingestion,
runtime pipelines, NenDB writes, durable writes, hosted dashboards, or mutation
authority.

## Artifact Upload Policy Preview

The preview should emit a fixed upload policy:

- `mode="preview-only"`
- `failure_only=true`
- `retention_days=14`
- `allowed_extensions=[".txt", ".json", ".dot"]`
- `allowed_roots=["packages/zigeffect/.zig-cache/causal-artifacts"]`
- `disallowed_roots=[".zig-cache", "packages/zigeffect/.zig-cache"]`
- `ignore_missing_files=true`
- `public_upload_claim=false`
- `ci_gate_claim=false`

This policy describes a future harness boundary. It does not upload files or
alter workflow configuration.

## Artifact Candidates

The tool should emit a compact candidate catalog:

- `source-workbench-preview-json`
  - source path: the input workbench preview JSON
  - extension: `.json`
  - purpose: reviewed UI/evidence handoff
- `source-workbench-preview-text`
  - source path: sibling workbench preview text report
  - extension: `.txt`
  - purpose: human-readable reviewed UI/evidence handoff
- `source-retention-fixtures-json`
  - source path: `source_retention`
  - extension: `.json`
  - purpose: NenDB mapping and retention fixture evidence
- `future-ci-preview-json`
  - source path: the generated CI preview JSON path
  - extension: `.json`
  - purpose: agent-readable archive policy preview
- `future-ci-preview-text`
  - source path: the generated CI preview text path
  - extension: `.txt`
  - purpose: human-readable archive policy preview

Every candidate must declare:

- `id`
- `path`
- `extension`
- `artifact_kind`
- `purpose`
- `retention_days`
- `failure_only`
- `allowed_root`
- `produced_by`
- `consumer`
- `redaction_required`
- `public_upload_allowed`

Candidates are advisory. They are not a guarantee that files exist in CI or are
uploaded.

## Checks

The tool should emit one check per concern:

- `workbench-schema`: source schema is
  `zigeffect.causal.production-telemetry-workbench-readonly-preview.v1`.
- `workbench-ready`: source preview status is `ready`.
- `decision-approved`: preview decision is `approve`.
- `workbench-review-approved`: source decision is `approve`.
- `workbench-next-branch-ready`: source `ready_for_next_branch=true`.
- `authority-disabled`: applied is false, mutation authority is none, and
  live/network/runtime/durable/NenDB/CI gate authority is disabled.
- `workbench-verification-recorded`: source workbench required verification
  commands are present in the source verified command list.
- `mapping-fixtures-carried`: at least one mapping fixture id is carried from
  the source artifact.
- `artifact-candidates-present`: required candidates are emitted.
- `artifact-extensions-allowlisted`: candidate extensions are `.txt`, `.json`,
  or `.dot`.
- `artifact-roots-allowlisted`: candidates live under the allowed causal
  artifact root or are explicit source evidence paths from the workbench chain.
- `upload-preview-only`: CI upload and workflow mutation flags are false.
- `preview-verification-recorded`: every required CI preview verification
  command is recorded.

Any failed check makes the preview `blocked`.

## Text Report

The text report should include:

- schema and status;
- reviewer, policy, and reason;
- source workbench preview path;
- source retention and upstream source paths;
- upload policy preview;
- artifact candidates;
- checks;
- required and recorded verification commands;
- implementation gates;
- blocked claims;
- agent guidance;
- next branch if ready.

The report should be concise enough to read in terminal output and stable
enough to diff in agent workflows.

## Docs And Governance

Update:

- `packages/zigeffect/tools/causal_schema_governance.zig`
- `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- `packages/zigeffect/docs/schema-governance.md`
- `packages/zigeffect/docs/production-hardening-backlog.md`
- `packages/zigeffect/docs/production-hardening-completion-audit.md`
- `packages/zigeffect/docs/production-telemetry-workbench-readonly-preview.md`
- `packages/zigeffect/docs/operations.md`
- `packages/zigeffect/docs/roadmap.md`
- `packages/zigeffect/README.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

The backlog should mark
`production-telemetry-ci-artifact-preview` as delivered and advance the
recommendation to `start-production-telemetry-ci-harness-boundary`.

## Testing

- Add Zig tests for option parsing, constants, approve report generation, and
  reject/blocked report generation.
- Watch the new tests fail before implementation.
- Add the build step and verify it fails before wiring.
- Verify the ready command emits JSON containing:
  - `ci_artifact_preview_status="ready"`;
  - `ready_for_next_branch=true`;
  - `ci_artifact_preview_enabled=true`;
  - `ci_upload_enabled=false`;
  - `ci_gate_enabled=false`;
  - `ci_workflow_mutation_enabled=false`;
  - allowed extensions `.txt`, `.json`, and `.dot`;
  - next branch
    `codex/zigeffect-causal-production-telemetry-ci-harness-boundary`.
- Verify the reject command emits a blocked artifact.
- Verify schema governance count and production backlog recommendation.
- Verify with `zig test tools/causal_production_telemetry_ci_artifact_preview.zig`,
  `zig build causal-production-telemetry-ci-artifact-preview`, `zig build
  examples`, `zig build test`, `bun run check`, `bun run zig:test`, and
  `git diff --check`.

## Agent Guidance

Agents may use a ready CI artifact preview to start the later CI harness
boundary branch only. They must cite the source workbench preview, source
retention artifact, candidate catalog, upload policy preview, checks, required
commands, recorded commands, and blocked claims.

Agents must treat blocked CI artifact previews as stop signs. A blocked preview
can guide evidence repair, but it cannot justify CI upload configuration, CI
gate work, live telemetry, durable writes, production capacity claims, or any
mutation authority.

## Spec Self-Review

- Placeholder scan: no placeholders remain.
- Internal consistency: schema, command, status names, next branch, and
  authority flags are consistent across sections.
- Scope check: one artifact-preview tool plus governance/docs; no workflow or
  telemetry runtime implementation.
- Ambiguity check: preview-only policy explicitly disables upload, workflow
  mutation, CI gates, live ingestion, and writes.
