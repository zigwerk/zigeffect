# Production Telemetry CI Gate Required Status Check Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `causal-production-telemetry-ci-gate-required-status-check-readiness`, a record-only readiness artifact that evaluates whether ready advisory CI report publication-policy evidence is sufficient to start a future required-status-check application boundary.

**Architecture:** Add one Zig tool following the existing production telemetry policy/readiness pattern. The tool parses a ready advisory CI report publication-policy artifact, validates disabled authority and complete verification evidence, renders deterministic JSON/text readiness reports, and updates build wiring, schema governance, backlog, roadmap, README, and operations docs. It never enables required checks, mutates branch protection, mutates workflows, calls networks, writes storage, or grants mutation authority.

**Tech Stack:** Zig 0.16.0, `std.json`, `std.crypto.hash.sha2.Sha256`, existing zigeffect build steps, Bun root verification.

---

## File Structure

- Create `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_readiness.zig`
  - CLI parsing, source publication-policy parsing, readiness checks, candidate
    required-check profiles, activation guardrails, negative fixtures,
    deterministic JSON/text rendering, file IO, and focused tests.
- Modify `packages/zigeffect/build.zig`
  - Add module, executable, build step, and test integration after the
    advisory CI report publication-policy tool.
- Modify `packages/zigeffect/tools/causal_schema_governance.zig`
  - Add the new schema entry and update schema count from 69 to 70.
- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
  - Mark required-status-check readiness delivered and recommend the
    required-status-check application-boundary branch.
- Create `packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-readiness.md`
  - Document command, source contract, candidate check profiles, activation
    guardrails, denied inferences, handoff, and verification.
- Modify `packages/zigeffect/README.md`
  - Add command example after the advisory CI report publication-policy.
- Modify `packages/zigeffect/docs/operations.md`
  - Add operations guidance and update current next branch.
- Modify `packages/zigeffect/docs/production-hardening-backlog.md`
  - Add delivered backlog item, dependency order item, and verification
    commands.
- Modify `packages/zigeffect/docs/schema-governance.md`
  - Add schema matrix prose.
- Modify `packages/zigeffect/docs/roadmap.md` and
  `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Mark the readiness milestone delivered and add the next branch.
- Update predecessor docs that currently point at this branch as current next.

## Task 1: Create Red Constants Test

**Files:**
- Create: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_readiness.zig`

- [ ] **Step 1: Add the failing constants test**

Create the file with only this test:

```zig
const std = @import("std");

test "ci gate required status check readiness schema and branch constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-ci-gate-required-status-check-readiness.v1", production_telemetry_ci_gate_required_status_check_readiness_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_ci_gate_required_status_check_readiness_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-readiness", source_branch);
    try std.testing.expectEqualStrings("start-production-telemetry-ci-gate-required-status-check-application-boundary", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-application-boundary", next_branch_if_ready);
}
```

- [ ] **Step 2: Run the test and confirm RED**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_readiness.zig
```

Expected: fail with an undeclared identifier for
`production_telemetry_ci_gate_required_status_check_readiness_schema`.

## Task 2: Implement Constants And CLI Parsing

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_readiness.zig`

- [ ] **Step 1: Add constants and enums**

Add constants:

```zig
pub const production_telemetry_ci_gate_required_status_check_readiness_schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-readiness.v1";
pub const production_telemetry_ci_gate_required_status_check_readiness_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-readiness";
pub const recommendation = "start-production-telemetry-ci-gate-required-status-check-application-boundary";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-application-boundary";

const source_publication_policy_schema = "zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-publication-policy.v1";
const generated_by = "causal-production-telemetry-ci-gate-required-status-check-readiness";
const output_prefix_suffix = "-ci-gate-required-status-check-readiness";
const compact_output_prefix_name = "production-telemetry-ci-gate-required-status-check-readiness";
```

Define `Decision = enum { approve, reject }`,
`RequiredStatusCheckReadinessStatus = enum { ready, blocked }`, and
`CheckStatus = enum { pass, fail }`.

- [ ] **Step 2: Add `Options` and parser**

Parse:

```sh
--from-publication-policy <publication-policy.json> approve|reject --reason <reason>
```

Also parse `--by`, `--policy`, `--verified-command`, and `--out-prefix`.

Validate:

- source path ends with `.json`
- decision is `approve` or `reject`
- `--reason` is present and non-empty

- [ ] **Step 3: Add parser tests**

Add tests for:

- approve mode with default actor and policy
- reject mode
- custom actor, policy, verified command, and output prefix
- unknown decision returns `error.UnknownDecision`
- missing reason returns `error.MissingReason`

- [ ] **Step 4: Run focused tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_readiness.zig
```

Expected: constants and parser tests pass.

## Task 3: Evaluate Source Publication Policy Artifacts

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_readiness.zig`

- [ ] **Step 1: Add source artifact structs**

Define structs for:

- `SourcePolicyCheck` with `name`, `status`, `detail`
- `SourceInterpretationRule` with `id`, `consumer_role`, `allowed_use`,
  `failure_effect`, `denied_claim`
- `SourcePublicationSurface` with `id`, `visibility_class`,
  `executed_by_tool`, `interpretation_scope`
- `SourceNegativeFixture` with `id`, `artifact_state`, `decision`,
  `failed_gate`, `reason`
- `PublicationPolicyArtifact` with source schema, source application-boundary
  fields, decision, publication-policy status, ready flag, disabled authority
  booleans, catalogs, checks, blocked claims, required verification commands,
  and verified commands
- `ReadinessCheck`
- `ReadinessResult`

- [ ] **Step 2: Add source checks**

Implement checks named exactly:

- `source-schema`
- `source-policy-ready`
- `source-advisory-non-blocking`
- `source-required-status-check-disabled`
- `source-ci-enforcement-disabled`
- `source-publication-execution-disabled`
- `source-runtime-and-storage-disabled`
- `source-interpretation-catalogs-present`
- `required-status-check-semantics-defined`
- `required-verification-recorded`
- `decision-approved`

- [ ] **Step 3: Add source evaluation tests**

Add sample JSON strings for:

- ready publication policy
- blocked publication policy
- source with `ci_required_status_check_enabled=true`
- source missing `required-status-check` denied inference
- source with incomplete verified commands

Assert approve mode returns ready only for the ready source with every required
verification command. Assert all other samples return blocked.

## Task 4: Add Candidate Profiles, Guardrails, And Negative Fixtures

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_readiness.zig`

- [ ] **Step 1: Add catalog structs**

Add:

```zig
const RequiredStatusCheckProfile = struct {
    id: []const u8,
    activation_enabled: bool,
    source: []const u8,
    intended_future_signal: []const u8,
    denied_claim: []const u8,
};

const ReadinessDimension = struct {
    id: []const u8,
    required: bool,
    evidence: []const u8,
};

const ActivationGuardrail = struct {
    id: []const u8,
    required_before_application: bool,
    reason: []const u8,
};

const NegativeFixture = struct {
    id: []const u8,
    artifact_state: []const u8,
    decision: []const u8,
    failed_gate: []const u8,
    reason: []const u8,
};
```

- [ ] **Step 2: Add required check profiles**

Create profiles with ids:

- `zigeffect-causal-telemetry-advisory-report`
- `zigeffect-causal-release-gate-report`
- `zigeffect-causal-required-check-contract`

Every profile must set `activation_enabled=false`.

- [ ] **Step 3: Add readiness dimensions**

Create dimensions with ids:

- `source-publication-policy-ready`
- `required-check-name-stability`
- `failure-semantics-reviewed`
- `branch-protection-evidence-required`
- `workflow-evidence-required`
- `rollback-and-bypass-policy-required`
- `flake-and-retry-policy-required`
- `redaction-retention-reviewed`
- `human-review-before-application`

- [ ] **Step 4: Add activation guardrails**

Create guardrails with ids:

- `stable-check-names`
- `owning-workflow-paths`
- `pass-fail-semantics`
- `advisory-to-required-review`
- `branch-protection-before-after`
- `workflow-before-after`
- `manual-rollback-plan`
- `maintainer-bypass-policy`
- `flake-noise-policy`
- `redaction-retention-policy`
- `no-github-mutation-by-this-tool`
- `no-mutation-authority`

- [ ] **Step 5: Add denied inference rules and negative fixtures**

Denied inference rules must include:

- `required-status-check-active`
- `merge-blocker-active`
- `branch-protection-updated`
- `github-check-run-created`
- `github-api-mutation`
- `workflow-mutated-by-tool`
- `artifact-upload-executed-by-tool`
- `github-step-summary-written-by-tool`
- `pull-request-comment-written-by-tool`
- `production-health-proof`
- `deployment-success-proof`
- `capacity-proof`
- `customer-impact-proof`
- `production-cluster-readiness-proof`
- `live-telemetry-coverage-proof`
- `durable-write-proof`
- `nendb-write-proof`
- `mutation-authority`
- `non-nendb-durable-adapter`
- `alternate-renderer`

Negative fixture ids must include:

- `blocked-source-policy-denied`
- `missing-required-status-check-denied`
- `required-status-check-active-denied`
- `merge-blocker-active-denied`
- `branch-protection-active-denied`
- `github-check-run-created-denied`
- `github-api-mutation-denied`
- `workflow-mutation-denied`
- `missing-release-gate-report-denied`
- `missing-human-review-gate-denied`
- `production-health-claim-denied`
- `cluster-readiness-claim-denied`
- `mutation-authority-claim-denied`
- `non-nendb-durable-scope-denied`
- `alternate-renderer-scope-denied`

- [ ] **Step 6: Add catalog tests**

Assert rendered JSON contains the three profile ids, the stable-check-names
guardrail, `required-status-check-active`, `branch-protection-updated`,
`github-check-run-created-denied`, and
`mutation-authority-claim-denied`.

## Task 5: Render Artifacts And File IO

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_readiness.zig`

- [ ] **Step 1: Add output path replacement**

Implement default output replacement:

```text
*-ci-gate-advisory-ci-report-publication-policy.json
*-ci-gate-required-status-check-readiness.json
```

Add a long-path compaction helper like the publication-policy tool so implicit
filenames remain filesystem-safe.

- [ ] **Step 2: Add JSON and text rendering**

JSON must include:

- `schema`
- `schema_version`
- `generated_by`
- `source_publication_policy`
- `source_publication_policy_status`
- `decision`
- `required_status_check_readiness_status`
- `ready_for_next_branch`
- `reviewed_by`
- `policy`
- `reason`
- disabled authority booleans
- `mutation_authority`
- `readiness_checks`
- `required_status_check_profiles`
- `readiness_dimensions`
- `activation_guardrails`
- `denied_inference_rules`
- `negative_fixtures`
- `blocked_claims`
- `required_verification_commands`
- `verified_commands`
- `recommendation`
- `next_branch_if_ready`
- `agent_guidance`

Text output must expose the same key status, handoff, checks, profiles,
guardrails, denied rules, fixtures, and guidance in deterministic order.

- [ ] **Step 3: Add render tests**

Assert:

- approved source emits
  `"required_status_check_readiness_status": "ready"`
- rejected source emits blocked status
- approved source emits `"ready_for_next_branch": true`
- output has `"ci_required_status_check_enabled": false`
- output has every profile with `activation_enabled=false`
- text output includes `next branch if ready`
- output paths end with `-ci-gate-required-status-check-readiness.json`

## Task 6: Wire Build Step And Schema Governance

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`

- [ ] **Step 1: Add build wiring**

In `packages/zigeffect/build.zig`, add a module, executable, run step, and test
step for
`causal-production-telemetry-ci-gate-required-status-check-readiness`
immediately after the advisory CI report publication-policy wiring.

- [ ] **Step 2: Add schema governance entry**

Add schema:

```text
zigeffect.causal.production-telemetry-ci-gate-required-status-check-readiness.v1
```

Use category `production-hardening`, emitted by
`causal-production-telemetry-ci-gate-required-status-check-readiness`, and
consumed by agents, reviewers, production-hardening backlog, and future
required-status-check application-boundary work.

Compatibility tags must include:

- `strict-v1`
- `record-only`
- `required-status-check-readiness`
- `gate-semantics`
- `activation-guardrails`
- `non-blocking-advisory-source`
- `cluster-release-gate-aware`
- `no-live-ingestion`
- `no-network`
- `no-durable-write`
- `no-nendb-write`
- `no-ci-gate-enforcement`
- `no-required-status-check`
- `no-branch-protection-mutation`
- `no-github-api-mutation`
- `no-tool-workflow-mutation`
- `no-tool-ci-upload`
- `no-tool-github-step-summary-write`
- `no-tool-pr-comment`

- [ ] **Step 3: Update schema count tests**

Update schema count expectations from 69 to 70 and assert the new schema entry
is present in text and JSON reports.

## Task 7: Update Backlog And Documentation

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Create: `packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-readiness.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Update backlog constants**

Set:

```zig
pub const recommendation = "start-production-telemetry-ci-gate-required-status-check-application-boundary";
pub const recommended_next_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-application-boundary";
```

Add delivered backlog item id:

```text
production-telemetry-ci-gate-required-status-check-readiness
```

- [ ] **Step 2: Add verification command strings**

Add commands:

```sh
zig build causal-production-telemetry-ci-gate-required-status-check-readiness -- --from-publication-policy ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-advisory-ci-report-publication-policy.json approve --reason "required status check readiness reviewed" --verified-command "zig build causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy" --verified-command "zig build causal-artifacts" --verified-command "zig build release-gate --summary none" --verified-command "zig build release-gate-report" --verified-command "zig build causal-schema-governance -- --format json" --verified-command "zig build causal-production-hardening-backlog -- --format json" --verified-command "zig build examples" --verified-command "zig build test"
zig build causal-production-telemetry-ci-gate-required-status-check-readiness -- --from-publication-policy ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-advisory-ci-report-publication-policy-negative.json reject --reason "negative required status check readiness path" --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-readiness-negative
```

- [ ] **Step 3: Update docs**

Document:

- source publication-policy contract
- required-status-check profiles
- activation guardrails
- denied inferences
- no GitHub required check activation
- no branch protection mutation
- no CI enforcement
- no GitHub API mutation
- next branch:
  `codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-application-boundary`

## Task 8: Generate Artifacts, Verify, And Commit

**Files:**
- All files modified above.

- [ ] **Step 1: Run focused verification**

Run:

```sh
cd packages/zigeffect
zig fmt build.zig tools/causal_production_telemetry_ci_gate_required_status_check_readiness.zig tools/causal_production_hardening_backlog.zig tools/causal_schema_governance.zig
zig test tools/causal_production_telemetry_ci_gate_required_status_check_readiness.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-production-telemetry-ci-gate-required-status-check-readiness -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

Expected:

- required-status-check readiness tests pass
- backlog tests pass
- schema governance reports `schema_count: 70`
- backlog recommends
  `codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-application-boundary`

- [ ] **Step 2: Generate positive and negative readiness artifacts**

Run:

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
  --verified-command "zig build test" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-readiness

zig build causal-production-telemetry-ci-gate-required-status-check-readiness -- \
  --from-publication-policy ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-advisory-ci-report-publication-policy-negative.json \
  reject \
  --reason "negative required status check readiness path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-readiness-negative
```

Expected:

- positive output has `required_status_check_readiness_status: ready`
- positive output has `ready_for_next_branch: true`
- positive output has `ci_required_status_check_enabled: false`
- positive output has all profiles with `activation_enabled=false`
- negative output has `required_status_check_readiness_status: blocked`

- [ ] **Step 3: Run full verification**

Run:

```sh
cd packages/zigeffect
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 4: Commit**

Run:

```sh
git status --short --branch
git add docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md packages/zigeffect/README.md packages/zigeffect/build.zig packages/zigeffect/docs packages/zigeffect/tools/causal_production_hardening_backlog.zig packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_readiness.zig packages/zigeffect/tools/causal_schema_governance.zig
git commit -m "feat(zigeffect): add required status check readiness"
```

Expected: commit succeeds on
`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-readiness`.
