# Production Telemetry CI Gate Required Status Check Enforcement Evaluator Design

## Status

Approved for implementation as the next sequential zigeffect causal
self-improvement roadmap milestone.

## Branch

`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator`

## Background

The required-status-check enforcement policy branch created a record-only
policy artifact that explains how agents may interpret planned enforcement
evidence, externally applied active required-status-check enforcement evidence,
and merge-blocking evidence. That policy intentionally does not inspect live
systems or mutate GitHub state.

Agents now need a bounded evaluator that consumes a ready enforcement-policy
artifact plus explicitly supplied local or CI evidence files and reports
whether observed evidence matches the policy. The evaluator must make the
evidence posture machine-readable without converting policy evidence into
GitHub mutation, live telemetry, deployment health, customer impact, durable
writes, or production authority.

## Goals

- Add `causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator`.
- Consume
  `zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-policy.v1`.
- Emit
  `zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-evaluator.v1`.
- Accept explicit `--evidence <file.json|file.txt>` inputs only.
- Classify evidence as source policy, source application-boundary, release gate
  JSON/text, causal JSON/text, or denied.
- Evaluate whether active-enforcement and merge-blocking observations are
  consistent with the source policy.
- Emit deterministic JSON and text reports with checks, evidence summaries,
  signal evaluations, findings, blocked finding counts, advisory finding counts,
  blocked claims, required verification commands, and next-branch guidance.
- Preserve the distinction between planned evidence, externally applied active
  enforcement evidence, and merge-blocking evidence.
- Hand off to a later report branch that can render evaluator findings for
  reviewers while remaining record-only.

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
- No recursive evidence discovery; every evidence file must be named
  explicitly.

## Command

Positive path:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator -- \
  --from-policy ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-policy.json \
  evaluate \
  --reason "required status check enforcement evidence evaluated" \
  --evidence ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-policy.json \
  --evidence ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.json \
  --evidence ../../.zig-cache/release-gate/zigeffect-release-gate.json
```

Negative path:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator -- \
  --from-policy ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-policy-negative.json \
  evaluate \
  --reason "negative required status check enforcement evaluator path" \
  --evidence ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-policy-negative.json \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-evaluator-negative
```

## CLI Contract

Required positional shape:

```sh
--from-policy <required-status-check-enforcement-policy.json> evaluate --reason <reason>
```

Supported optional flags:

- `--by <actor>`
- `--policy <policy>`
- `--evidence <file.json|file.txt>` repeated
- `--out-prefix <path-prefix>`
- `--help`

Stable option errors:

- `error.MissingPolicyPath`
- `error.InvalidPolicyPath`
- `error.MissingCommand`
- `error.UnknownCommand`
- `error.MissingReason`
- `error.MissingFlagValue`
- `error.InvalidEvidencePath`
- `error.UnknownFlag`
- `error.UnknownArgument`

## Output Paths

Default path derivation:

- `foo-ci-gate-required-status-check-enforcement-policy.json`
  becomes `foo-ci-gate-required-status-check-enforcement-evaluator.json`.
- `foo.json` becomes
  `foo-ci-gate-required-status-check-enforcement-evaluator.json`.
- `--out-prefix x` emits `x.json` and `x.txt`.

## Source Policy Contract

The source policy artifact must:

- use schema
  `zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-policy.v1`;
- use schema version `1`;
- have `required_status_check_enforcement_policy_status="ready"`;
- set `ready_for_next_branch=true`;
- keep `mutation_authority="none"`;
- keep all GitHub, workflow, check-run, CI upload, summary, comment, live
  telemetry, runtime, durable, and NenDB authority fields disabled;
- include enforcement interpretation policy records;
- include evidence requirements, denied inference rules, negative fixtures, and
  blocked claims;
- record no failed source checks;
- record every source required verification command.

If the source policy is blocked, the evaluator must emit `blocked` and
`ready_for_next_branch=false`.

## Evidence Boundary

Evidence inputs are bounded:

- maximum `32` files;
- maximum `1 MiB` per file;
- only `.json` and `.txt`;
- no recursive discovery;
- no network fetching;
- denied if evidence contains secret markers, GitHub mutation-enabled claims,
  workflow mutation-enabled claims, check-run creation claims, CI upload
  execution claims, live telemetry claims, durable write claims, NenDB write
  claims, non-NenDB adapter claims, production-health claims, deployment
  success claims, customer impact claims, production cluster readiness claims,
  or alternate renderer claims.

Evidence classes:

- `source_policy`: the supplied policy JSON itself.
- `source_application_boundary`: a required-status-check enforcement
  application-boundary JSON artifact.
- `release_gate_json`: release-gate JSON evidence.
- `release_gate_text`: release-gate text evidence.
- `causal_json`: causal JSON evidence.
- `causal_text`: causal text evidence.
- `denied`: evidence with denied markers or unsupported shape.

## Evaluation Semantics

The evaluator emits `required_status_check_enforcement_evaluator_status`:

- `ready`: source policy is ready, evidence is bounded and safe, and observed
  active/merge signals match the policy.
- `advisory-findings`: source policy is ready and evidence is safe, but
  expected active-enforcement or merge-blocking evidence is missing, or
  observed evidence makes claims that the policy does not allow.
- `blocked`: source policy is invalid/blocked, evidence is denied, verification
  is missing, or required policy sections are missing.

Signals:

- `policy-ready`: source policy is ready and verified.
- `active-enforcement-observed`: evidence contains active enforcement markers
  consistent with `active_enforcement_policy_ready`.
- `merge-blocking-observed`: evidence contains merge-blocking markers
  consistent with `merge_blocker_policy_ready`.
- `tool-mutation-denied`: no evidence may claim mutation by this evaluator.
- `production-claim-denied`: no evidence may claim production health,
  deployment success, customer impact, or cluster readiness.

Planned policy sources can be evaluator-ready with no active or merge-blocking
evidence. Applied active sources should produce advisory findings when active
evidence is missing. Applied merge-blocking sources should produce advisory
findings when merge-blocking evidence is missing.

## Output Fields

Required top-level fields:

- `schema`
- `schema_version`
- `source_enforcement_policy`
- `source_policy_status`
- `source_policy_ready_for_next_branch`
- `source_active_enforcement_policy_ready`
- `source_merge_blocker_policy_ready`
- `reason`
- `reviewed_by`
- `policy`
- `required_status_check_enforcement_evaluator_status`
- `ready_for_next_branch`
- `blocked_findings_count`
- `advisory_findings_count`
- every disabled authority boolean
- `mutation_authority`
- `evidence_files`
- `checks`
- `signal_evaluations`
- `findings`
- `blocked_claims`
- `required_verification_commands`
- `generated_by`
- `source_branch`
- `recommendation`
- `next_branch_if_ready`
- `json_output`
- `text_output`
- `agent_guidance`

## Next Branch

Recommendation:

`start-production-telemetry-ci-gate-required-status-check-enforcement-report`

Branch:

`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report`

The report branch should consume ready or advisory evaluator artifacts and
render local JSON/text reviewer guidance. It must remain record-only and must
not publish CI summaries, post comments, upload artifacts, mutate GitHub, or
claim production health.

## Documentation Updates

Create:

- `packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-enforcement-evaluator.md`

Update:

- `packages/zigeffect/README.md`
- `packages/zigeffect/docs/operations.md`
- `packages/zigeffect/docs/production-hardening-backlog.md`
- `packages/zigeffect/docs/schema-governance.md`
- `packages/zigeffect/docs/roadmap.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
- adjacent docs that currently identify enforcement evaluator as the current
  next branch.

## Verification

Focused:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_evaluator.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator -- --help
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator -- \
  --from-policy ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-policy.json \
  evaluate \
  --reason "required status check enforcement evidence evaluated" \
  --evidence ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-policy.json \
  --evidence ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.json \
  --evidence ../../.zig-cache/release-gate/zigeffect-release-gate.json
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator -- \
  --from-policy ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-policy-negative.json \
  evaluate \
  --reason "negative required status check enforcement evaluator path" \
  --evidence ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-policy-negative.json \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-evaluator-negative
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
