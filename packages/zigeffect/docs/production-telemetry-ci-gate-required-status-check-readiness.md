# Production Telemetry CI Gate Required Status Check Readiness

`causal-production-telemetry-ci-gate-required-status-check-readiness` consumes
a ready advisory CI report publication-policy artifact and emits record-only
readiness evidence for the guarded required-status-check application-boundary
and policy sequence.

It does not create GitHub required checks, update branch protection, create
check runs, call GitHub APIs, mutate workflows, upload artifacts, write GitHub
step summaries, post pull request comments, enable CI gate enforcement, ingest
live telemetry, call networks, write NenDB, write durable production storage,
or grant mutation authority.

## Command

Approve readiness from a ready publication-policy artifact:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-required-status-check-readiness -- \
  --from-publication-policy ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-advisory-ci-report-publication-policy.json \
  approve \
  --reason "required status check readiness reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Use `reject` to record a reviewed stop. Rejected records always emit blocked
status and never hand off to the next branch.

Use `--out-prefix <path-prefix>` to choose an explicit artifact prefix.

## Source Contract

The source artifact must use schema
`zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-publication-policy.v1`,
have decision `approve`, have
`advisory_ci_report_publication_policy_status="ready"`, set
`ready_for_next_branch=true`, and keep `mutation_authority="none"`.

The source must preserve disabled authority:

- `ci_gate_enabled=false`
- `ci_gate_enforcement_enabled=false`
- `ci_required_status_check_enabled=false`
- `ci_workflow_mutation_enabled=false`
- `ci_upload_execution_enabled=false`
- `ci_report_publication_enabled=false`
- `github_step_summary_write_enabled=false`
- `pull_request_comment_enabled=false`
- `production_telemetry_ingestion=false`
- `network_send_enabled=false`
- `runtime_pipeline_enabled=false`
- `durable_write_enabled=false`
- `nendb_write_enabled=false`

The source must also include interpretation rules, publication surfaces,
denied inference rules, negative fixtures, blocked claims, required
verification commands, and matching verified commands.

## Readiness Meaning

Ready artifacts define candidate required-check profiles with
`activation_enabled=false`, readiness dimensions, activation guardrails, denied
inference rules, and negative fixtures.

They deny required checks being active, merge blocking, branch protection
updates, GitHub check-run creation, GitHub API mutation, workflow mutation,
artifact uploads, GitHub summary writes by the tool, pull request comments by
the tool, production health, deployment success, capacity, customer impact,
cluster readiness, live telemetry coverage, durable write proof, NenDB write
proof, alternate renderer scope, non-NenDB durable adapter scope, and mutation
authority.

## Handoff

Ready artifacts hand off to
`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy`
after the delivered application-boundary milestone. That policy branch is now
delivered and hands off to enforcement-readiness. The readiness branch is not
enforcement and does not apply branch protection.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_readiness.zig
zig build causal-production-telemetry-ci-gate-required-status-check-readiness -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
