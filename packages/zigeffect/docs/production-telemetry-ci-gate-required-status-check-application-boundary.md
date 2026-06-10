# Production Telemetry CI Gate Required Status Check Application Boundary

`causal-production-telemetry-ci-gate-required-status-check-application-boundary`
consumes a ready required-status-check readiness artifact and emits a guarded,
record-only boundary artifact for externally reviewed required-status-check
application evidence.

It does not create GitHub required checks, update branch protection, create
check runs, call GitHub APIs, mutate workflows, upload artifacts, write GitHub
step summaries, post pull request comments, enable CI gate enforcement, ingest
live telemetry, call networks, write NenDB, write durable production storage,
or grant mutation authority.

## Command

Plan the boundary from a ready readiness artifact:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary -- \
  --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-readiness.json \
  plan \
  --reason "required status check application boundary planned"
```

Use `record-applied` only for a separately reviewed external branch-protection,
workflow, or check-run update that has change evidence, before evidence, after
evidence, optional safe after-state files, and all post-application
verification commands.

## Modes

- `plan`: emits
  `required_status_check_application_status="planned"`, `applied=false`, and
  `mutation_authority="none"` when the source readiness evidence is ready.
- `record-applied`: emits
  `required_status_check_application_status="applied"` only when every source,
  selected profile, reviewed change, before/after, after-state safety, and
  verification check passes. Otherwise it emits `blocked` and keeps
  `applied=false`.

Applied records are evidence records only. This command never mutates GitHub,
branch protection, workflows, or check runs.

## Source Readiness

The source artifact must use schema
`zigeffect.causal.production-telemetry-ci-gate-required-status-check-readiness.v1`,
have `required_status_check_readiness_status="ready"`, have
`decision="approve"`, set `ready_for_next_branch=true`, keep
`mutation_authority="none"`, keep every execution and mutation authority
disabled, include inactive required-check profiles, and record complete
verification evidence.

## Record-Applied Evidence

`record-applied` requires:

- `--required-check-profile <profile-id>`
- at least one `--branch-protection-change`
- at least one `--workflow-change` or `--check-run-change`
- at least one `--before`
- at least one `--after`
- every required `--verified-command`

`--branch-protection-after` may point to `.json`, `.md`, or `.txt` evidence.
`--workflow-after` may point to `.yml` or `.yaml` evidence. These files are
read locally for safety checks only; the tool does not apply them.

## Handoff

Planned or applied application-boundary artifacts hand off to:

`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy`

That branch defines interpretation policy for planned or externally applied
required-status-check evidence and hands off to enforcement-readiness. It must
still avoid inferring active merge blocking, production health, deployment
success, cluster readiness, durable writes, NenDB writes, alternate renderer
scope, or mutation authority.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_application_boundary.zig
zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary -- --help
zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary -- \
  --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-readiness.json \
  plan \
  --reason "required status check application boundary planned"
zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary -- \
  --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-readiness-negative.json \
  record-applied \
  --reason "negative required status check application boundary path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-application-boundary-negative
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
