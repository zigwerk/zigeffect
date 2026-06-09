# zigeffect App Application Readiness Implementation Plan

Date: 2026-06-09

## Goal

Add a non-mutating app application readiness artifact that consumes a draft app
patch proposal, re-checks proposal state, citations, high-risk human-review
links, and verification evidence, then writes a readiness report with:

```text
schema=zigeffect.causal.app-application-readiness.v1
applied=false
mutation_authority=none
```

This branch does not apply app changes. It prepares the next branch,
`codex/zigeffect-app-application-boundary`, where a separate guarded artifact
may record `applied=true` only after real reviewed source or external-state
updates and before/after verification.

## Architecture

Add one Zig CLI tool:

```text
packages/zigeffect/tools/causal_app_application_readiness.zig
```

Add one build step:

```sh
zig build causal-app-application-readiness -- local --proposal <app-patch-proposal-json> approve|reject --reason <reason> [--by <actor>] [--policy <policy>] [--verified <command>]... [--out-prefix <path-prefix>]
```

Add one schema:

```text
zigeffect.causal.app-application-readiness.v1
```

Add one workbench sample route:

```text
?sample=app-readiness -> sample-app-application-readiness.json
```

The SolidJS workbench remains the app inspection UI. The Zig-hosted shell
continues to be `zig-webui`; no React rewrite or broad UI redesign belongs in
this branch.

## Success Criteria

- The new tool writes JSON and text readiness artifacts.
- `approve` plus passing checks produces `readiness_status=ready` and
  `ready_for_application=true`.
- `reject` or any failed check produces `readiness_status=blocked` and
  `ready_for_application=false`.
- Every output preserves `applied=false` and `mutation_authority=none`.
- High-risk gates require proposal `source.human_review`.
- Gate-specific citations are re-validated from the proposal artifact.
- Required verification commands from the proposal must be supplied through
  repeated `--verified` flags for readiness to become ready.
- Workbench model/sample routing recognizes and renders app readiness evidence.
- Docs and roadmap describe the new chain and move the immediate queue to app
  application boundary.

## Task 1: Add RED Zig Tests And Build Wiring

Files:

- `packages/zigeffect/tools/causal_app_application_readiness.zig`
- `packages/zigeffect/build.zig`

Create the new tool file with constants, fixtures, test declarations, and
minimal placeholder functions only as needed to produce meaningful RED failures.

Required constants:

```zig
const app_patch_proposal_schema = "zigeffect.causal.app-patch-proposal.v1";
const app_application_readiness_schema = "zigeffect.causal.app-application-readiness.v1";
const app_patch_proposal_suffix = "-app-patch-proposal.json";
const app_application_readiness_suffix = "-app-application-readiness";
```

Core test fixtures:

- approved low-risk proposal with:
  - `proposal_status=draft`
  - `approval_status=pending`
  - `approved=false`
  - `applied=false`
  - `mutation_authority=none`
  - `policy_gates=["source-only", "config-only"]`
  - source and config citations
  - one required verification command
- high-risk proposal with:
  - `policy_gates=["migration-required", "operational-human-required", "rollback-required"]`
  - migration/runbook/rollback citations
  - `source.human_review`
- malformed variants:
  - already-applied proposal
  - approved proposal
  - mutating proposal
  - unknown gate
  - missing source citation
  - missing config citation
  - missing migration/runbook/rollback citation
  - high-risk proposal without human review

RED tests:

```zig
test "usage text names app application readiness inputs"
test "app readiness options parse reviewer policy decision reason verified commands and out prefix"
test "app readiness output paths derive from proposal path and out prefix"
test "approved low-risk proposal with verification becomes ready without mutation authority"
test "reject decision blocks readiness without applying"
test "missing required verification blocks readiness"
test "app readiness rejects unsupported or already applied proposal state"
test "app readiness blocks unknown policy gates"
test "app readiness requires source and config citations"
test "app readiness requires high risk citations and human review link"
test "app readiness text output includes checks verification steps and guardrails"
```

Build wiring:

- Create module:

```zig
const causal_app_application_readiness_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_app_application_readiness.zig"),
    .target = target,
    .optimize = optimize,
});
```

- Add test target:

```zig
const causal_app_application_readiness_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-app-application-readiness-tests",
    .root_module = causal_app_application_readiness_tool_module,
});
const run_causal_app_application_readiness_tool_tests = b.addRunArtifact(causal_app_application_readiness_tool_tests);
```

- Add executable and step:

```zig
const causal_app_application_readiness_tool = b.addExecutable(.{
    .name = "zigeffect-causal-app-application-readiness",
    .root_module = causal_app_application_readiness_tool_module,
});
const run_causal_app_application_readiness_tool = b.addRunArtifact(causal_app_application_readiness_tool);
if (b.args) |args| run_causal_app_application_readiness_tool.addArgs(args);
const causal_app_application_readiness_step = b.step("causal-app-application-readiness", "Write non-mutating app application readiness evidence from an app patch proposal");
causal_app_application_readiness_step.dependOn(&run_causal_app_application_readiness_tool.step);
```

- Add the test run artifact to both `test` and `examples` aggregate steps near
  the existing app human-review and app patch-proposal test dependencies.

Run:

```sh
cd packages/zigeffect && zig build test
```

Expected: FAIL because the tests name behavior that is not implemented yet.

## Task 2: Implement The Zig Tool

Implement:

- option parsing;
- output path derivation;
- proposal parsing;
- proposal validation;
- readiness evaluation;
- JSON formatting;
- text formatting;
- artifact reading/writing;
- `main` and usage failure mapping.

Suggested types:

```zig
const ReadinessDecision = enum {
    approve,
    reject,
};

const ReadinessStatus = enum {
    ready,
    blocked,
};

const CheckStatus = enum {
    pass,
    fail,
    skipped,
};

const ProposalSource = struct {
    policy: []const u8,
    app_remediation_audit: []const u8,
    app_artifact: []const u8,
    human_review: ?[]const u8 = null,
};

const ProposalCitations = struct {
    source_files: []const []const u8 = &.{},
    config_keys: []const []const u8 = &.{},
    migration_files: []const []const u8 = &.{},
    runbooks: []const []const u8 = &.{},
    rollback_plans: []const []const u8 = &.{},
};

const AppPatchProposalRecord = struct {
    schema: []const u8,
    schema_version: u32,
    mode: []const u8,
    target: []const u8,
    proposal_status: []const u8,
    approval_status: []const u8,
    approved: bool,
    applied: bool,
    mutation_authority: []const u8,
    summary: []const u8,
    change: []const u8,
    source: ProposalSource,
    policy_gates: []const []const u8,
    citations: ProposalCitations,
    event_ids: []const u64 = &.{},
    required_verification_commands: []const []const u8 = &.{},
    claim_guardrails: []const []const u8 = &.{},
    proposal_guardrails: []const []const u8 = &.{},
};
```

Validation rules:

- schema is `zigeffect.causal.app-patch-proposal.v1`;
- version is `1`;
- mode is `local`;
- target, summary, and change are non-empty;
- proposal status is `draft`;
- approval status is `pending`;
- approved is false;
- applied is false;
- mutation authority is `none`;
- source policy, audit, and app artifact paths are non-empty.

Readiness checks:

- `app-proposal-schema`
- `proposal-state`
- `reviewer-decision`
- `decision-approved`
- `source-chain-present`
- `policy-gates-known`
- `citations-complete`
- `high-risk-human-review-linked`
- `required-verification-recorded`

Helper behavior:

- `requiredCommandsSatisfied(verified, required)` mirrors the registry
  application helpers.
- `isHighRiskGate(gate)` mirrors app proposal/human-review helpers.
- `allChecksPassed(checks)` returns false if any check is not pass.
- `readinessGuardrails(status)` returns separate ready/blocked guardrails.
- `applicationSteps(status)` returns next-step guidance and repeats that the
  command does not mutate app state.

Write:

```text
<prefix>-app-application-readiness.json
<prefix>-app-application-readiness.txt
```

Run:

```sh
cd packages/zigeffect && zig build test
```

Expected: PASS for the new Zig tool tests and existing package tests.

## Task 3: Add RED Workbench Tests

Files:

- `packages/zigeffect/workbench/src/causalArtifact.test.ts`
- `packages/zigeffect/workbench/src/workbenchBridge.test.ts`

Add sample object to `causalArtifact.test.ts`:

```ts
const sampleAppReadiness = {
  schema: "zigeffect.causal.app-application-readiness.v1",
  schema_version: 1,
  mode: "local",
  target: "yachdee-platform",
  decision: "approve",
  readiness_status: "ready",
  ready_for_application: true,
  applied: false,
  mutation_authority: "none",
  source: {
    proposal: ".zig-cache/causal-artifacts/yachdee-platform-app-patch-proposal.json",
    policy: ".zig-cache/causal-artifacts/yachdee-platform-app-policy-decision.json",
    app_remediation_audit: ".zig-cache/causal-artifacts/yachdee-platform-app-remediation-audit.json",
    app_artifact: ".zig-cache/causal-artifacts/app.json",
    human_review: ".zig-cache/causal-artifacts/yachdee-platform-app-human-review.json",
  },
  policy_gates: ["source-only", "config-only"],
  citations: {
    source_files: ["apps/platform/src/worker.ts"],
    config_keys: ["YACHDEE_API_BASE_URL"],
    migration_files: [],
    runbooks: [],
    rollback_plans: [],
  },
  event_ids: [2],
  checks: [{ name: "proposal-state", status: "pass", detail: "proposal is draft" }],
  required_verification_commands: ["zig build causal-query -- --file app.json cause 2"],
  verified_commands: ["zig build causal-query -- --file app.json cause 2"],
  application_steps: ["Apply the reviewed change outside this readiness command."],
  readiness_guardrails: ["Readiness does not edit app source."],
};
```

Add tests:

```ts
test("deriveGovernanceModel detects app application readiness artifacts", () => {
  const governance = deriveGovernanceModel(sampleAppReadiness, { artifactPath: "app-readiness.json" });
  expect(governance?.kind).toBe("app-application-readiness");
  expect(governance?.summary).toContain("ready app application readiness");
  expect(governance?.applied).toBe(false);
  expect(governance?.mutationAuthority).toBe("none");
});

test("deriveAppRemediationModel reads app application readiness checks and steps", () => {
  const app = deriveAppRemediationModel(sampleAppReadiness, { artifactPath: "app-readiness.json" });
  expect(app?.kind).toBe("app-application-readiness");
  expect(app?.readinessStatus).toBe("ready");
  expect(app?.readyForApplication).toBe(true);
  expect(app?.checks.map((check) => `${check.name}:${check.status}`)).toEqual(["proposal-state:pass"]);
  expect(app?.sourceSteps.map((step) => step.label)).toEqual([
    "App patch proposal",
    "App policy decision",
    "App human review",
    "App remediation audit",
    "App artifact",
  ]);
  expect(app?.verificationCommands).toContain("zig build causal-query -- --file app.json cause 2");
  expect(app?.applicationSteps).toContain("Apply the reviewed change outside this readiness command.");
  expect(app?.guardrails).toContain("Readiness does not edit app source.");
});
```

Extend bridge test samples:

```ts
["?sample=app-readiness", "sample-app-application-readiness.json"]
```

Run:

```sh
bun run zigeffect:workbench:test
```

Expected: FAIL because the model and sample routing do not support readiness
yet.

## Task 4: Implement Workbench Model, UI, And Sample

Files:

- `packages/zigeffect/workbench/src/causalArtifact.ts`
- `packages/zigeffect/workbench/src/App.tsx`
- `packages/zigeffect/workbench/src/workbenchBridge.ts`
- `packages/zigeffect/workbench/public/sample-app-application-readiness.json`

Model changes:

- Add governance kind:

```ts
| "app-application-readiness"
```

- Add app remediation kind:

```ts
| "app-application-readiness"
```

- Add a check model:

```ts
export type AppReadinessCheckModel = {
  name: string;
  status: string;
  detail: string;
};
```

- Add to `AppRemediationModel`:

```ts
readinessStatus: string;
readyForApplication: boolean | null;
checks: AppReadinessCheckModel[];
applicationSteps: string[];
```

- Add schema mapping:

```ts
case "zigeffect.causal.app-application-readiness.v1":
  return "app-application-readiness";
```

- Include app readiness in `deriveAppRemediationModel`.
- Update `appSummary`.
- Update `appSourceSteps` for readiness:

```ts
[
  ["proposal", "App patch proposal"],
  ["policy", "App policy decision"],
  ["human_review", "App human review"],
  ["app_remediation_audit", "App remediation audit"],
  ["app_artifact", "App artifact"],
]
```

- Include `verified_commands` in `verificationCommands`.
- Include `readiness_guardrails` in guardrails.
- Read `checks` into the new check model.
- Read `application_steps` into the new steps array.

UI changes:

- In `AppRemediationStatus`, use readiness status as the posture when kind is
  `app-application-readiness`.
- Add a compact section for readiness checks, preferably next to citations or
  verification.
- Add a compact section for application steps.
- Keep all UI within the current SolidJS component/style vocabulary. Do not add
  cards inside cards, hero sections, or broad layout redesign.

Sample:

- Create `sample-app-application-readiness.json` from the same fields used in
  the workbench tests.
- Update sample routing in `workbenchBridge.ts`.

Run:

```sh
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
```

Expected: PASS.

## Task 5: Update Docs And Roadmaps

Files:

- `packages/zigeffect/README.md`
- `packages/zigeffect/docs/agent-guide.md`
- `packages/zigeffect/docs/agent-observable-runtime.md`
- `packages/zigeffect/docs/roadmap.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

Add the new command after the app patch proposal docs:

```sh
zig build causal-app-application-readiness -- local --proposal <app-patch-proposal-json> approve --reason <reason> --verified <command>
```

Document:

- schema `zigeffect.causal.app-application-readiness.v1`;
- output suffix `*-app-application-readiness.json/txt`;
- `readiness_status=ready|blocked`;
- `ready_for_application=true|false`;
- `applied=false`;
- `mutation_authority=none`;
- the command records readiness only and does not apply changes;
- high-risk gates still require human-review evidence in the proposal;
- config citations name keys/bindings only, not secret values.

Master roadmap changes:

- Update M8 evidence to include app application readiness artifacts.
- Move Immediate Branch Queue to:

```text
1. codex/zigeffect-app-application-boundary
   - Consume app application readiness artifacts and record guarded app
     application state only after reviewed source/external-state changes plus
     before/after verification.
```

Preserve:

- SolidJS plus `zig-webui` workbench direction;
- no Cockroach adapter work;
- NenDB adapter remains the only durable DB adapter direction for now.

Run:

```sh
rg -n "app-application-readiness|causal-app-application-readiness|app application readiness|Cockroach|NenDB|SolidJS|zig-webui" packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md packages/zigeffect/docs/roadmap.md docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
```

Expected: documentation consistently names the new command/schema and preserves
the requested platform constraints.

## Task 6: End-To-End Verification

Run all required checks:

```sh
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build test
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
bun run check
bun run zig:test
git diff --check
```

Browser QA:

1. Start the workbench dev server if needed:

```sh
bun run zigeffect:workbench:dev
```

2. Open:

```text
http://localhost:<port>/?sample=app-readiness
```

3. Verify desktop and narrow mobile screenshots:

- app remediation/governance summary identifies app application readiness;
- readiness status is visible;
- `applied=false` is visible and not styled as success for an applied change;
- mutation authority is `none`;
- citations, checks, verification, application steps, and guardrails are
  visible;
- text does not overflow on mobile.

If the dev server command or port differs, follow the existing workbench
scripts and report the actual URL.

## Task 7: Commit Implementation

Before staging:

```sh
git status --short
git diff --stat
```

Stage only files touched by this branch. Do not stage the unrelated untracked
file:

```text
docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
```

Commit:

```sh
git commit -m "feat(zigeffect): add app application readiness artifacts"
```

## Rollback Plan

If implementation becomes unstable:

- Keep the committed design and this plan.
- Revert only uncommitted files from this branch if necessary.
- Do not revert user/unrelated files.
- Leave the roadmap queue pointed at app application readiness until this branch
  is actually delivered.

## Completion Notes To Report

Final branch report should include:

- commit hashes for design, plan, and implementation;
- verification commands and outcomes;
- workbench browser QA URL and viewport coverage;
- a clear statement that `applied=true` is still deferred to
  `codex/zigeffect-app-application-boundary`;
- a clear statement that SolidJS plus `zig-webui` remains the UI direction;
- a clear statement that no Cockroach work was added and NenDB scope was not
  expanded.
