# Production Telemetry CI Gate Required Status Check Policy

`causal-production-telemetry-ci-gate-required-status-check-policy` consumes
planned or externally applied required-status-check application-boundary
artifacts and emits record-only interpretation policy.

It does not create GitHub required checks, update branch protection, mutate
workflows, create check runs, call GitHub APIs, upload CI artifacts, write
GitHub step summaries, post pull request comments, enable CI gate enforcement,
ingest live telemetry, call networks, write NenDB, write durable production
storage, claim production health, claim cluster readiness, or grant mutation
authority.

## Command

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-required-status-check-policy -- \
  --from-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-application-boundary.json \
  approve \
  --reason "required status check policy reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

## Source Application Boundary

The source artifact must use schema
`zigeffect.causal.production-telemetry-ci-gate-required-status-check-application-boundary.v1`,
have status `planned` or `applied`, keep all tool-side GitHub, workflow, CI
upload, telemetry, durable, and NenDB authority disabled, include source
profiles and denied inference catalogs, and record required verification
commands.

`applied` sources must also include branch-protection evidence, before
evidence, after evidence, and workflow or check-run evidence. Planned sources
may pass policy review, but only as design input.

## Planned Versus Applied Sources

- Planned source: emits `source_applied=false`; agents may use it to prepare
  enforcement-readiness design only.
- Applied source: emits `source_applied=true`; agents may cite it as reviewed
  external evidence only.

Both paths keep `merge_blocker_claim_allowed=false` because this tool does not
prove an active protected-branch requirement.

## Denied Inferences

Policy readiness is not proof of GitHub mutation by this tool, branch
protection mutation, workflow mutation, check-run creation, CI upload
execution, GitHub step-summary or pull-request comment writes, production
health, deployment success, capacity, customer impact, production cluster
readiness, live telemetry coverage, durable writes, NenDB writes, or mutation
authority.

## Handoff

Ready policy artifacts hand off to:

`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness`

That branch should define what additional externally verifiable GitHub,
branch-protection, workflow, and CI evidence is required before an agent may
describe a required status check as active enforcement.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_policy.zig
zig build causal-production-telemetry-ci-gate-required-status-check-policy -- --help
zig build causal-production-telemetry-ci-gate-required-status-check-policy -- \
  --from-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-application-boundary.json \
  approve \
  --reason "required status check policy reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-production-telemetry-ci-gate-required-status-check-policy -- \
  --from-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-application-boundary-negative.json \
  reject \
  --reason "negative required status check policy path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-policy-negative
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
