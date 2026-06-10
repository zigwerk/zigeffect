# Production Telemetry CI Gate Required Status Check Enforcement Application Boundary

`causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary`
consumes a ready required-status-check enforcement-readiness artifact and emits
a guarded, record-only application-boundary artifact for externally reviewed
active required-status-check enforcement evidence.

It does not create GitHub required checks, update branch protection, mutate
workflows, create check runs, call GitHub APIs, upload CI artifacts, write
GitHub step summaries, post pull request comments, ingest live telemetry, call
networks, write NenDB, write durable production storage, claim production
health, claim deployment success, claim cluster readiness, or grant mutation
authority.

## Command

Plan the boundary from a ready enforcement-readiness artifact:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary -- \
  --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-readiness.json \
  plan \
  --reason "required status check enforcement application boundary planned"
```

Use `record-applied` only when a separately reviewed branch-protection,
workflow, or check-run update is already externally active and bounded evidence
has been collected:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary -- \
  --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-readiness.json \
  record-applied \
  --reason "required status check enforcement evidence recorded" \
  --required-check-name "zigeffect causal release gate" \
  --branch-protection-before "reviewed branch protection before evidence" \
  --branch-protection-after "reviewed branch protection after evidence" \
  --workflow-evidence "reviewed release gate workflow evidence" \
  --failure-mode-evidence "reviewed failing release gate blocks future required check" \
  --owner-approval "reviewed owner approval for active enforcement" \
  --rollback-evidence "reviewed rollback removes required status check enforcement" \
  --merge-blocking-evidence "reviewed branch protection blocks merges on the required check" \
  --verified-command "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

## Modes

- `plan`: emits
  `required_status_check_enforcement_application_status="planned"`,
  `applied=false`, `active_enforcement_recorded=false`,
  `merge_blocking_recorded=false`, and `mutation_authority="none"` when the
  source enforcement-readiness evidence is ready.
- `record-applied`: emits
  `required_status_check_enforcement_application_status="applied"` and
  `applied=true` only when every source, evidence, safety, and verification
  check passes. Otherwise it emits `blocked` and keeps `applied=false`.

`record-applied` sets `active_enforcement_claim_allowed=true` only for the
bounded external evidence record. It sets `merge_blocker_claim_allowed=true`
only when `--merge-blocking-evidence` is present and all other checks pass.
Neither field proves that this tool mutated GitHub or production systems.

## Source Readiness

The source artifact must use schema
`zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-readiness.v1`,
have `decision="approve"`, have `enforcement_readiness_status="ready"`, set
`ready_for_next_branch=true`, keep `mutation_authority="none"`, keep every
GitHub, workflow, CI upload, telemetry, durable, and NenDB authority disabled,
include evidence catalogs, record no failed source checks, and record every
required verification command.

The source must still deny active enforcement and merge-blocker claims. This
boundary is the first place those claims may be recorded, and only with
external applied evidence.

## Record-Applied Evidence

`record-applied` requires:

- at least one `--required-check-name`;
- at least one `--branch-protection-before`;
- at least one `--branch-protection-after`;
- at least one `--workflow-evidence` or `--check-run-evidence`;
- at least one `--failure-mode-evidence`;
- at least one `--owner-approval`;
- at least one `--rollback-evidence`;
- every required `--verified-command`.

`--merge-blocking-evidence` is optional, but without it the artifact must keep
`merge_blocking_recorded=false` and `merge_blocker_claim_allowed=false`.

Evidence may describe externally reviewed branch-protection state, workflow
snippets, check-run summaries, required-check failure behavior, owner approval,
rollback steps, and merge-blocking behavior. Evidence may not contain
credentials, tokens, network claims, live telemetry ingestion, production
writes, NenDB writes, non-NenDB durable adapter claims, production health,
deployment success, customer impact, cluster readiness, or alternate renderer
claims.

## Denied Inferences

Applied enforcement evidence is not GitHub API mutation by this tool,
branch-protection mutation by this tool, workflow mutation by this tool,
check-run creation by this tool, CI upload execution by this tool, GitHub
step-summary or pull-request comment writes by this tool, production health
proof, deployment success proof, customer impact proof, production cluster
readiness proof, live telemetry coverage proof, durable writes, NenDB writes,
or mutation authority.

## Handoff

Planned or externally applied enforcement application-boundary artifacts hand
off to:

`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-policy`

That branch should define interpretation policy for active enforcement evidence
and merge-blocker evidence before any future evaluator or production authority
work can cite those claims.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_application_boundary.zig
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary -- --help
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary -- \
  --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-readiness.json \
  plan \
  --reason "required status check enforcement application boundary planned"
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary -- \
  --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-readiness-negative.json \
  record-applied \
  --reason "negative required status check enforcement application boundary path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-application-boundary-negative
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
