# Zigeffect Causal Production Telemetry CI Gate Required Status Check Enforcement Report Policy Design

## Summary

This branch adds the record-only policy layer after the required status check enforcement report application boundary. It consumes
`zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary.v1`
artifacts and emits
`zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report-policy.v1`
artifacts.

The tool does not publish reports, upload CI artifacts, write GitHub step summaries, post pull request comments, create check runs, mutate branch protection, mutate workflows, ingest live telemetry, write durable stores, or write NenDB. It interprets already-recorded evidence so agents and reviewers can decide what is safe to cite next.

## Goals

- Provide a deterministic `approve|reject` policy artifact for externally reviewed enforcement report application-boundary evidence.
- Preserve the distinction between planned report publication evidence and externally applied report publication evidence.
- Mark the policy `ready` only when the source artifact is planned or applied, internally consistent, non-mutating, fully verified, and reviewer-approved.
- Mark `published_report_policy_ready=true` only when the source artifact is `record-applied`, `applied=true`, and the source report application-boundary status is `applied`.
- Keep all authority fields false and `mutation_authority="none"`.
- Add schema governance, backlog, roadmap, README, and operations coverage so agents can discover the next branch without guessing.

## Non-Goals

- No GitHub API calls.
- No branch-protection, workflow, required-status-check, or check-run mutation.
- No CI artifact upload execution.
- No GitHub step summary or pull request comment writing.
- No live production telemetry ingestion.
- No runtime pipeline enablement.
- No durable writes and no NenDB writes.
- No non-NenDB durable adapter work.
- No React or alternate renderer scope.
- No production health, deployment success, customer impact, capacity, or cluster readiness claim.

## CLI Contract

The new build step is:

```sh
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy -- \
  --from-application-boundary <required-status-check-enforcement-report-application-boundary.json> \
  approve|reject \
  --reason <reason> \
  [--by <actor>] \
  [--policy <policy>] \
  [--verified-command <command>]... \
  [--out-prefix <path-prefix>]
```

Default output paths replace the source suffix:

- Source:
  `production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary.json`
- Output:
  `production-telemetry-ci-gate-required-status-check-enforcement-report-policy.json`
  and `.txt`

## Source Validation

The policy reads the source artifact with unknown fields ignored, then evaluates:

- `schema` equals
  `zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary.v1`.
- `schema_version == 1`.
- `report_application_boundary_status` is `planned` or `applied`, never `blocked`.
- `mode`, `applied`, and `mutation_authority` are consistent:
  - planned source: `mode="plan"`, `applied=false`, `mutation_authority="none"`;
  - applied source: `mode="record-applied"`, `applied=true`, `mutation_authority="none"`.
- All tool-authority booleans are false.
- Live telemetry, network, runtime pipeline, durable write, and NenDB write booleans are false.
- Source checks exist and none have status `fail`.
- Source denied-claim, negative-fixture, blocked-claim, and required-verification catalogs are present.
- Source `verified_commands` contains every source `required_verification_commands` entry.
- Reviewer decision is `approve`.
- Policy `verified_commands` contains every policy required command.

## Policy Semantics

The output has two readiness layers:

- `ready_for_next_branch`: all checks passed and the artifact is safe to consume.
- `published_report_policy_ready`: all checks passed and the source is an externally applied report application-boundary record.

Planned source artifacts can still produce `ready_for_next_branch=true` because they are valid policy design inputs. They do not produce `published_report_policy_ready=true`.

Applied source artifacts can produce both readiness signals, but only as record-only interpretation. The policy never claims the tool created, uploaded, posted, required, or enforced anything.

## Output Shape

The JSON output includes:

- schema and schema version;
- source application-boundary path, status, mode, and applied state;
- reviewer decision, reviewer, policy name, and reason;
- `required_status_check_enforcement_report_policy_status`;
- `ready_for_next_branch`;
- `published_report_policy_ready`;
- all disabled authority booleans;
- `mutation_authority`;
- interpretation policy entries;
- evidence requirements;
- checks;
- denied inference rules;
- negative fixtures;
- blocked claims;
- required and verified commands;
- generated-by, source branch, recommendation, next branch, and output paths;
- agent guidance.

The text output mirrors the same facts for humans.

## Interpretation Policy

The policy catalog contains three source-state interpretations:

- `planned-report-application`: planned report application-boundary evidence can guide future publication review, but is not publication proof.
- `applied-report-publication`: applied source evidence can be cited as externally reviewed report publication/application evidence.
- `blocked-report-application`: blocked source evidence is a stop sign and cannot feed policy readiness.

The denied inference catalog explicitly blocks:

- GitHub API mutation by the tool;
- branch-protection mutation by the tool;
- workflow mutation by the tool;
- check-run creation by the tool;
- required-status-check creation by the tool;
- CI artifact upload execution by the tool;
- GitHub step summary writes or PR comments by the tool;
- live telemetry, runtime pipeline, durable writes, NenDB writes;
- non-NenDB durable adapters;
- alternate renderers;
- production health, deployment success, customer impact, capacity, or cluster readiness;
- mutation authority.

## Documentation And Registry Updates

The branch updates:

- `packages/zigeffect/build.zig`;
- `packages/zigeffect/tools/causal_schema_governance.zig`;
- `packages/zigeffect/tools/causal_production_hardening_backlog.zig`;
- `packages/zigeffect/docs/schema-governance.md`;
- `packages/zigeffect/docs/production-hardening-backlog.md`;
- `packages/zigeffect/docs/roadmap.md`;
- `packages/zigeffect/docs/operations.md`;
- `packages/zigeffect/README.md`;
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`;
- new user-facing docs for the policy tool.

After this branch, the conservative handoff should be a backlog and roadmap refresh branch:
`codex/zigeffect-causal-production-hardening-backlog-refresh`. That branch can choose the next unresolved roadmap item, likely the remaining cross-run comparison work in the agent query interface, without treating CI report evidence as production readiness.

## Testing

Focused tests cover:

- schema, branch, recommendation, and next-branch constants;
- CLI parsing for approve, reject, reviewer, policy, verified commands, and output prefix;
- default output path rewriting;
- approved planned source yields `ready_for_next_branch=true` and `published_report_policy_ready=false`;
- approved applied source yields both readiness signals;
- blocked source, reviewer reject, missing verification, failed source checks, authority-enabled source, and inconsistent source state all block;
- formatted JSON and text include schema, readiness, disabled authority, next branch, and guidance.

Verification commands:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy -- --help
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy -- \
  --from-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary.json \
  approve \
  --reason "required status check enforcement report policy reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy -- \
  --from-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary-negative.json \
  reject \
  --reason "negative required status check enforcement report policy path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report-policy-negative
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
