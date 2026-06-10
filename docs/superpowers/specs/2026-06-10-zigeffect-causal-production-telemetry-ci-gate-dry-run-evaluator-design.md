# zigeffect Causal Production Telemetry CI Gate Dry-Run Evaluator Design

## Summary

Create `causal-production-telemetry-ci-gate-dry-run-evaluator`, a bounded,
record-only evaluator that consumes a ready CI gate dry-run policy artifact and
explicit local or CI evidence files, then emits advisory signal evaluations,
findings, and next-query commands for agents and reviewers.

This branch still does not enable CI gate enforcement, required status checks,
workflow mutation, artifact upload execution, live telemetry ingestion, network
send, collector configuration, OTLP serialization, durable writes, NenDB
writes, production health claims, production cluster readiness claims,
non-NenDB durable adapter scope, alternate renderer scope, or mutation
authority.

## Goals

- Consume `zigeffect.causal.production-telemetry-ci-gate-dry-run-policy.v1`
  artifacts only when `dry_run_policy_status="ready"` and
  `ready_for_next_branch=true`.
- Evaluate the dry-run policy candidate signals against explicitly supplied
  evidence paths.
- Emit a deterministic JSON and text evaluator report with advisory findings,
  evidence classes, source policy metadata, disabled authority flags, next
  queries, and blocked claims.
- Make missing signal evidence visible as advisory findings, not CI
  enforcement.
- Block only when the source policy is invalid or evidence violates the input
  boundary, such as secret-shaped content, live telemetry markers, required
  status check claims, workflow mutation claims, durable write claims, NenDB
  write claims, or non-NenDB durable adapter claims.
- Preserve the NenDB-only durable direction and SolidJS inside
  `webui-dev/zig-webui` workbench direction.

## Non-Goals

- No required GitHub status checks.
- No workflow edits or workflow mutation by the tool.
- No artifact upload execution.
- No recursive directory crawling.
- No network calls, live telemetry ingestion, collector endpoint probing, or
  OTLP serialization.
- No durable production storage writes and no NenDB writes.
- No production health, deployment success, capacity, customer impact, or
  production cluster readiness claims.
- No Cockroach, non-NenDB durable adapter, or alternate frontend renderer work.
- No mutation authority.

## CLI

```sh
zig build causal-production-telemetry-ci-gate-dry-run-evaluator -- \
  --from-dry-run-policy <dry-run-policy.json> \
  evaluate \
  --reason <reason> \
  --evidence <path>...
```

Optional flags:

- `--by <actor>`: reviewer or agent id. Defaults to
  `ci-gate-dry-run-evaluator`.
- `--policy <policy>`: policy id. Defaults to
  `manual-production-telemetry-ci-gate-dry-run-evaluator`.
- `--out-prefix <path-prefix>`: override output paths.

The command requires at least one `--evidence` file. Evidence paths must be
explicit; the evaluator must not walk directories or infer files from globs.

Default output path replacement:

- `*-ci-gate-dry-run-policy.json` becomes
  `*-ci-gate-dry-run-evaluator.json`.
- Text output uses the same prefix with `.txt`.

## Source Policy Contract

The source policy artifact is accepted only when:

- `schema="zigeffect.causal.production-telemetry-ci-gate-dry-run-policy.v1"`
- `schema_version=1`
- `dry_run_policy_status="ready"`
- `ready_for_next_branch=true`
- `decision="approve"`
- source boundary mode is `plan` or `record-applied`
- source boundary status is `planned` or `applied`
- source boundary mutation authority is `none` or `record-only`
- all CI gate, required status check, workflow mutation, upload execution,
  live telemetry, network, collector, OTLP, runtime pipeline, durable write,
  and NenDB write flags are false
- policy checks contain no `fail`
- candidate signal policies and evidence requirements are present
- blocked claims are present

If any source condition fails, the evaluator emits
`evaluation_status="blocked"` and `ready_for_next_branch=false`.

## Evidence Contract

The evaluator reads each explicit evidence file with a bounded maximum of
1 MiB per file and a maximum of 32 evidence files.

Allowed evidence path classes:

- `.zig-cache/causal-artifacts/*.json`
- `.zig-cache/causal-artifacts/*.txt`
- `.zig-cache/release-gate/*.json`
- `.zig-cache/release-gate/*.txt`
- equivalent `packages/zigeffect/.zig-cache/...` paths

Allowed evidence content classes:

- causal JSON artifacts with schemas beginning `zigeffect.causal.`
- release-gate JSON artifacts with schema `zigeffect.release-gate.v1`
- release-gate text reports
- causal CI handoff text or JSON artifacts
- reviewed source-policy artifacts from the production telemetry chain

Denied evidence markers:

- secret-shaped values or secret references: `secrets.`, `PRODUCTION_`,
  `BEGIN PRIVATE KEY`, `Authorization:`, `sk-`, `ghp_`, `xoxb-`
- required status check claims: `required_status_check`,
  `"ci_required_status_check_enabled": true`
- CI gate enforcement claims: `"ci_gate_enforcement_enabled": true`
- workflow mutation claims: `"ci_workflow_mutation_enabled": true`
- artifact upload execution claims: `"ci_upload_execution_enabled": true`
- live telemetry or network claims: `"live_exporter_enabled": true`,
  `"network_send_enabled": true`, `"collector_endpoint_configured": true`,
  `"otlp_serialization_enabled": true`
- runtime pipeline claims: `"runtime_pipeline_enabled": true`
- durable write claims: `"durable_write_enabled": true`
- NenDB write claims: `"nendb_write_enabled": true`
- non-NenDB durable adapter claims: `durable_adapter=non-nendb`,
  `"durable_adapter": "non-nendb"`
- retention greater than 14 days: `retention-days: 15`,
  `"retention_days": 15`, or larger values when statically visible
- alternate renderer claims: `renderer=react`, `"renderer": "react"`

Denied evidence markers block the evaluator report because the input boundary
has been violated. Missing candidate evidence produces advisory findings.

## Signal Evaluation

The evaluator uses the candidate signal ids from the policy artifact and emits
one signal evaluation for each supported id.

### `release-gate-artifact-present`

Observed when at least one evidence file is a release-gate JSON/text artifact.
Missing evidence produces an advisory finding with a next query to run
`zig build release-gate --summary none` and `zig build release-gate-report`.

### `causal-artifact-schema-parse`

Observed when at least one evidence JSON file parses and includes a schema
starting with `zigeffect.causal.`. Missing or unparsable causal JSON evidence
produces an advisory finding.

### `archive-policy-conformance`

Observed when every evidence path is in an allowed path class and no denied
upload/public evidence markers are present. Path violations block the
evaluator report.

### `redaction-retention-conformance`

Observed when evidence contains no secret-shaped markers and no statically
visible retention value greater than 14 days. Denied secret or retention
markers block the evaluator report.

### `ci-handoff-present`

Observed when at least one evidence file path or content indicates a causal CI
handoff. Missing handoff evidence produces an advisory finding because a
passing local run may not have produced failure handoff evidence.

### `boundary-source-valid`

Observed when the source dry-run policy is valid and its policy checks have no
failures. Invalid source policy evidence blocks the evaluator report.

## Output Schema

Schema: `zigeffect.causal.production-telemetry-ci-gate-dry-run-evaluator.v1`

Top-level fields:

- `schema`
- `schema_version`
- `source_dry_run_policy`
- `source_policy_status`
- `source_policy_decision`
- `source_boundary_status`
- `source_boundary_mode`
- `evaluation_mode="dry-run"`
- `evaluation_status`: `ready`, `advisory-findings`, or `blocked`
- `ready_for_next_branch`
- `advisory_findings_count`
- `blocked_findings_count`
- all disabled authority flags
- `reviewed_by`
- `policy`
- `reason`
- `evidence_files`
- `signal_evaluations`
- `findings`
- `next_queries`
- `checks`
- `blocked_claims`
- `required_verification_commands`
- `generated_by`
- `source_branch`
- `recommendation`
- `next_branch_if_ready`
- `json_output`
- `text_output`
- `agent_guidance`

`evidence_files` fields:

- `path`
- `class`
- `bytes`
- `sha256`
- `parse_status`: `json`, `text`, or `unreadable`
- `allowed`
- `detail`

`signal_evaluations` fields:

- `id`
- `status`: `observed`, `missing`, or `blocked`
- `severity`: `info`, `advisory`, or `blocked`
- `evidence_path`
- `finding_id`
- `detail`
- `next_queries`

`findings` fields:

- `id`
- `signal_id`
- `severity`
- `summary`
- `evidence_path`
- `blocked_claim`
- `next_queries`

## Status Rules

- `blocked`: invalid source policy, no evidence files, unreadable required
  source, denied evidence markers, or evidence path outside allowed classes.
- `advisory-findings`: valid source and no blocked findings, but one or more
  candidate signals are missing.
- `ready`: valid source, no blocked findings, and every supported candidate
  signal is observed.

`ready_for_next_branch=true` for both `ready` and `advisory-findings` because
missing evidence is advisory and does not create a release gate. It is false
only for `blocked`.

## Handoff

Recommendation:

```text
start-production-telemetry-ci-gate-advisory-ci-report
```

Next branch:

```text
codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report
```

The next branch should decide how to present evaluator reports in CI artifacts
or reviewer summaries while still avoiding required checks, workflow mutation
by the tool, live telemetry, durable writes, NenDB writes, production cluster
claims, and mutation authority.

## Tests

Focused Zig tests must cover:

- constants and branch handoff
- CLI parsing with multiple `--evidence` values
- default output path replacement
- ready evaluator report with release-gate, causal JSON, and handoff evidence
- advisory report when CI handoff evidence is missing
- blocked report for invalid source policy
- blocked report for denied evidence markers
- blocked report for evidence paths outside allowed classes

Build-level verification must include:

- `zig test tools/causal_production_telemetry_ci_gate_dry_run_evaluator.zig`
- `zig build causal-production-telemetry-ci-gate-dry-run-evaluator -- --help`
- ready and negative evaluator artifact generation
- `zig build causal-schema-governance -- --format json`
- `zig build causal-production-hardening-backlog -- --format json`
- `zig build examples`
- `zig build test`
- `bun run check`
- `bun run zig:test`
- `git diff --check`
