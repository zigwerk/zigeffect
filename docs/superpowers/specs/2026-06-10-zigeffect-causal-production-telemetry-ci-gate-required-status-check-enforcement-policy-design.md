# Production Telemetry CI Gate Required Status Check Enforcement Policy Design

## Status

Approved for implementation as the next sequential zigeffect causal
self-improvement roadmap milestone.

## Branch

`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-policy`

## Background

The required-status-check enforcement application-boundary branch created a
record-only boundary for planned or externally applied active required-check
enforcement evidence. That boundary intentionally allows active-enforcement
and merge-blocker claims only inside the bounded artifact, and only when the
source readiness and external evidence gates pass.

Agents now need a policy artifact that explains how to interpret those claims
before any later evaluator, report, rollout, or production-authority work can
cite them. The policy must preserve the distinction between:

- planned enforcement application evidence;
- externally applied active required-check enforcement evidence;
- explicit merge-blocking evidence;
- GitHub mutation by this tool, which remains false;
- live production telemetry or deployment health, which remains unproven.

## Goals

- Add `causal-production-telemetry-ci-gate-required-status-check-enforcement-policy`.
- Consume
  `zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.v1`.
- Emit
  `zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-policy.v1`.
- Support `approve` and `reject` reviewer decisions.
- Produce deterministic JSON and text artifacts.
- Preserve source mode, source applied state, active-enforcement state, and
  merge-blocking state.
- Define allowed interpretation rules for planned, applied active-enforcement,
  and merge-blocking evidence.
- Define denied inference rules for GitHub mutation, workflow mutation,
  check-run creation, CI uploads, step summaries, pull-request comments, live
  telemetry, production health, deployment success, customer impact,
  production cluster readiness, durable writes, NenDB writes, non-NenDB durable
  adapters, alternate renderers, and mutation authority.
- Hand off to a later record-only enforcement evaluator branch.

## Non-Goals

- No GitHub API calls.
- No branch-protection mutation.
- No workflow mutation.
- No check-run creation.
- No CI artifact upload execution.
- No GitHub step-summary writes.
- No pull-request comments.
- No live telemetry ingestion.
- No network sends or collector configuration.
- No OTLP serialization.
- No runtime pipeline enablement.
- No durable production writes.
- No NenDB writes.
- No non-NenDB durable adapter work.
- No alternate renderer support.
- No production health, deployment success, customer impact, capacity, or
  cluster-readiness proof.
- No mutation authority.

## Command

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-policy -- \
  --from-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.json \
  approve \
  --reason "required status check enforcement policy reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Negative path:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-policy -- \
  --from-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-application-boundary-negative.json \
  reject \
  --reason "negative required status check enforcement policy path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-policy-negative
```

## CLI Contract

Required positional shape:

```sh
--from-application-boundary <required-status-check-enforcement-application-boundary.json> approve|reject --reason <reason>
```

Supported optional flags:

- `--by <actor>`
- `--policy <policy>`
- `--verified-command <command>` repeated
- `--out-prefix <path-prefix>`
- `--help`

Stable option errors:

- `error.MissingApplicationBoundaryPath`
- `error.InvalidApplicationBoundaryPath`
- `error.MissingDecision`
- `error.UnknownDecision`
- `error.MissingReason`
- `error.MissingFlagValue`
- `error.UnknownFlag`
- `error.UnknownArgument`

## Output Paths

Default path derivation:

- `foo-ci-gate-required-status-check-enforcement-application-boundary.json`
  becomes `foo-ci-gate-required-status-check-enforcement-policy.json`.
- `foo.json` becomes
  `foo-ci-gate-required-status-check-enforcement-policy.json`.
- `--out-prefix x` emits `x.json` and `x.txt`.

## Source Contract

The source artifact must:

- use schema
  `zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.v1`;
- use schema version `1`;
- have
  `required_status_check_enforcement_application_status` equal to `planned` or
  `applied`, never `blocked`;
- keep `mode`, `applied`, and `mutation_authority` internally consistent:
  `plan + applied=false + mutation_authority=none` or
  `record-applied + applied=true + mutation_authority=none`;
- keep all tool-side GitHub, workflow, check-run, CI upload, step-summary,
  pull-request-comment, live telemetry, runtime, durable, and NenDB authority
  disabled;
- record no failed source checks;
- include evidence requirements, denied inference rules, negative fixtures,
  blocked claims, and required verification commands;
- record every source required verification command.

Source `record-applied` artifacts may set
`active_enforcement_claim_allowed=true`. Source merge-blocking claims may be
set only when `merge_blocking_recorded=true`,
`merge_blocker_claim_allowed=true`, and merge-blocking evidence is present.

## Policy Semantics

The policy emits `required_status_check_enforcement_policy_status`.

`ready` requires:

- supported source schema;
- valid source planned or applied state;
- no failed source checks;
- complete source verification;
- reviewer decision `approve`;
- complete policy verification;
- active enforcement interpretation rules present;
- merge-blocker interpretation rules present;
- denied inference rules present;
- evidence requirements and negative fixtures present.

Any failed check emits `blocked` and `ready_for_next_branch=false`.

## Interpretation Rules

The artifact should include `enforcement_interpretation_policy` records:

- `planned-enforcement`: source planned evidence is useful for policy design
  only; active enforcement and merge blocking remain false.
- `applied-active-enforcement`: source applied evidence may be cited as a
  reviewed external active-enforcement record, but not as tool mutation,
  production health, or deployment success.
- `merge-blocking`: source merge-blocking evidence may be cited only when the
  source recorded merge-blocking evidence and allowed the merge-blocker claim.
  It still does not prove GitHub mutation by this tool.

## Denied Inferences

The policy must explicitly deny:

- `enforcement-policy-is-not-github-api-mutation-by-tool`
- `enforcement-policy-is-not-branch-protection-mutation-by-tool`
- `enforcement-policy-is-not-workflow-mutation-by-tool`
- `enforcement-policy-is-not-check-run-creation-by-tool`
- `enforcement-policy-is-not-ci-upload-execution-by-tool`
- `enforcement-policy-is-not-github-step-summary-or-pr-comment-write-by-tool`
- `active-enforcement-is-not-production-health-proof`
- `active-enforcement-is-not-deployment-success-proof`
- `active-enforcement-is-not-customer-impact-proof`
- `active-enforcement-is-not-production-cluster-readiness-proof`
- `active-enforcement-is-not-live-telemetry-coverage-proof`
- `active-enforcement-is-not-durable-or-nendb-write-proof`
- `merge-blocking-is-not-tool-mutation-proof`
- `enforcement-policy-grants-no-mutation-authority`

## Evidence Requirements

Allowed evidence:

- source enforcement application-boundary artifact;
- source branch-protection before and after summaries;
- source workflow or check-run evidence;
- source failure-mode evidence;
- source owner approval and rollback evidence;
- source merge-blocking evidence when present;
- required verification command list.

Denied evidence:

- secret-shaped values;
- GitHub mutation enabled claims;
- workflow mutation enabled claims;
- check-run creation enabled claims;
- CI upload execution enabled claims;
- live telemetry or collector configuration claims;
- durable write or NenDB write claims;
- non-NenDB durable adapter claims;
- production health, deployment success, customer impact, or cluster readiness
  claims;
- alternate renderer claims.

## Output Fields

Required top-level fields:

- `schema`
- `schema_version`
- `source_enforcement_application_boundary`
- `source_enforcement_application_status`
- `source_mode`
- `source_applied`
- `source_active_enforcement_recorded`
- `source_merge_blocking_recorded`
- `source_active_enforcement_claim_allowed`
- `source_merge_blocker_claim_allowed`
- `decision`
- `reviewed_by`
- `policy`
- `reason`
- `required_status_check_enforcement_policy_status`
- `ready_for_next_branch`
- `active_enforcement_policy_ready`
- `merge_blocker_policy_ready`
- every disabled authority boolean
- `mutation_authority`
- `enforcement_interpretation_policy`
- `evidence_requirements`
- `checks`
- `denied_inference_rules`
- `negative_fixtures`
- `blocked_claims`
- `required_verification_commands`
- `verified_commands`
- `generated_by`
- `source_branch`
- `recommendation`
- `next_branch_if_ready`
- `json_output`
- `text_output`
- `agent_guidance`

## Next Branch

Recommendation:

`start-production-telemetry-ci-gate-required-status-check-enforcement-evaluator`

Branch:

`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator`

The evaluator should consume ready enforcement-policy artifacts plus bounded
explicit evidence and report whether observed active enforcement and
merge-blocking claims match policy. It must remain record-only.

## Documentation Updates

Update:

- `packages/zigeffect/README.md`
- `packages/zigeffect/docs/operations.md`
- `packages/zigeffect/docs/production-hardening-backlog.md`
- `packages/zigeffect/docs/schema-governance.md`
- `packages/zigeffect/docs/roadmap.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
- adjacent docs that currently identify enforcement policy as the current next
  branch.

Create:

- `packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-enforcement-policy.md`

## Verification

Focused:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_policy.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-policy -- --help
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-policy -- \
  --from-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.json \
  approve \
  --reason "required status check enforcement policy reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-policy -- \
  --from-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-application-boundary-negative.json \
  reject \
  --reason "negative required status check enforcement policy path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-policy-negative
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

Full:

```sh
cd packages/zigeffect
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
