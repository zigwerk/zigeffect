# zigeffect App Patch Proposal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a non-mutating app patch proposal artifact that consumes approved app policy decisions and cites app files, config keys, migrations, runbooks, and rollback plans.

**Architecture:** Create a focused `causal_app_patch_proposal.zig` tool that reads `zigeffect.causal.app-policy-decision.v1`, validates the policy posture, validates proposal citations against policy gates, and writes JSON/text reports. Wire the tool into `build.zig`, register the schema in the SolidJS workbench model, and update the zigeffect docs/roadmaps.

**Tech Stack:** Zig 0.16 build system and std JSON parser, existing causal app remediation/policy artifact conventions, Bun/SolidJS workbench model tests, repository verification through Bun and Zig.

---

## File Structure

- Create: `packages/zigeffect/tools/causal_app_patch_proposal.zig`
  - Owns CLI parsing, policy JSON parsing, proposal validation, JSON/text formatting, artifact writes, and unit tests.
- Modify: `packages/zigeffect/build.zig`
  - Adds module/test/executable/run step for `causal-app-patch-proposal`.
  - Adds the new test/executable to `test` and `examples` aggregate steps.
- Modify: `packages/zigeffect/workbench/src/causalArtifact.ts`
  - Adds `app-patch-proposal` to governance schema detection and summary text.
- Modify: `packages/zigeffect/workbench/src/causalArtifact.test.ts`
  - Adds a focused governance detection test for app patch proposals.
- Modify: `packages/zigeffect/README.md`
  - Adds the app patch proposal command and non-mutating safety note.
- Modify: `packages/zigeffect/docs/agent-guide.md`
  - Adds the app policy to app proposal workflow for agents.
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
  - Documents the app causal remediation chain through proposal drafting.
- Modify: `packages/zigeffect/docs/roadmap.md`
  - Marks app patch proposals as delivered and app workbench detail as next.
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Updates M8 status and branch queue.

## Task 1: Specify the Zig App Proposal Tool

**Files:**
- Create: `packages/zigeffect/tools/causal_app_patch_proposal.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Verify the build step is absent**

Run:

```sh
cd packages/zigeffect && zig build causal-app-patch-proposal
```

Expected: FAIL with an unknown build step error.

- [ ] **Step 2: Add the minimal tool test module**

Create `packages/zigeffect/tools/causal_app_patch_proposal.zig` with a first failing usage test:

```zig
const std = @import("std");

const app_policy_schema = "zigeffect.causal.app-policy-decision.v1";
const app_patch_proposal_schema = "zigeffect.causal.app-patch-proposal.v1";

fn usage() []const u8 {
    return "usage: zig build causal-app-patch-proposal -- local --policy <app-policy-decision-json> --summary <summary> --change <description> [--file <path>] [--config <key>] [--migration <path>] [--runbook <path>] [--rollback <path>] [--out-prefix <path-prefix>]\n";
}

test "usage text names app proposal inputs" {
    try std.testing.expect(std.mem.indexOf(u8, usage(), "causal-app-patch-proposal") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage(), "--policy <app-policy-decision-json>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage(), "--config <key>") != null);
}
```

- [ ] **Step 3: Wire only the test module into `build.zig`**

Add a module near `causal_app_policy_decision_tool_module`:

```zig
const causal_app_patch_proposal_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_app_patch_proposal.zig"),
    .target = target,
    .optimize = optimize,
});

const causal_app_patch_proposal_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-app-patch-proposal-tests",
    .root_module = causal_app_patch_proposal_tool_module,
});
const run_causal_app_patch_proposal_tool_tests = b.addRunArtifact(causal_app_patch_proposal_tool_tests);
```

Add:

```zig
test_step.dependOn(&run_causal_app_patch_proposal_tool_tests.step);
```

- [ ] **Step 4: Run the new test**

Run:

```sh
cd packages/zigeffect && zig build test --summary none
```

Expected: PASS for the usage-only tool after build wiring.

## Task 2: Add Proposal Parsing and Output Path Tests

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_patch_proposal.zig`

- [ ] **Step 1: Add failing tests for parse/options behavior**

Append tests that expect:

```zig
test "app proposal options parse repeated citations" {
    const args = [_][]const u8{
        "zigeffect-causal-app-patch-proposal",
        "local",
        "--policy",
        "app-policy.json",
        "--summary",
        "wire app requirement",
        "--change",
        "add provider layer",
        "--file",
        "apps/platform/src/worker.ts",
        "--config",
        "YACHDEE_ENV",
        "--rollback",
        "docs/runbooks/revert-yachdee.md",
    };

    var options = try parseOptions(std.testing.allocator, &args);
    defer options.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("local", options.mode);
    try std.testing.expectEqualStrings("app-policy.json", options.policy_path);
    try std.testing.expectEqual(@as(usize, 1), options.source_files.len);
    try std.testing.expectEqual(@as(usize, 1), options.config_keys.len);
    try std.testing.expectEqual(@as(usize, 1), options.rollback_plans.len);
}
```

and:

```zig
test "app proposal output paths derive from policy path and out prefix" {
    const defaults = try outputPathsForOptions(std.testing.allocator, .{
        .mode = "local",
        .policy_path = ".zig-cache/causal-artifacts/app-policy.json",
        .summary = "summary",
        .change = "change",
    });
    defer defaults.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/app-policy-app-patch-proposal.json",
        defaults.json_path,
    );

    const custom = try outputPathsForOptions(std.testing.allocator, .{
        .mode = "local",
        .policy_path = "app-policy.json",
        .summary = "summary",
        .change = "change",
        .out_prefix = ".zig-cache/causal-artifacts/yachdee-platform",
    });
    defer custom.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/yachdee-platform-app-patch-proposal.json",
        custom.json_path,
    );
}
```

- [ ] **Step 2: Run and confirm RED**

Run:

```sh
cd packages/zigeffect && zig test tools/causal_app_patch_proposal.zig
```

Expected: FAIL because `parseOptions`, `Options`, and `outputPathsForOptions` are not implemented yet.

- [ ] **Step 3: Implement minimal parsing**

Implement:

- `Options` with owned repeated slices and `deinit`.
- `OutputPaths` with `deinit`.
- `parseOptions(allocator, args)` for `local`, required `--policy`, `--summary`, and `--change`, and repeated citation flags.
- `outputPathsForOptions`.

- [ ] **Step 4: Run and confirm GREEN**

Run:

```sh
cd packages/zigeffect && zig test tools/causal_app_patch_proposal.zig
```

Expected: PASS for usage/options/path tests.

## Task 3: Add Policy Validation and Proposal Formatting

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_patch_proposal.zig`

- [ ] **Step 1: Add failing tests for approved policy input**

Add sample JSON constants:

```zig
const approved_policy_json =
    \\{
    \\  "schema": "zigeffect.causal.app-policy-decision.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "yachdee-platform",
    \\  "decision": "approve",
    \\  "approval_status": "approve",
    \\  "evaluated_by": "local-app-policy-engine",
    \\  "policy": "local-app-remediation-policy-v1",
    \\  "reason": "app audit is eligible for proposal drafting",
    \\  "reason_codes": ["app-gates-proposal-eligible"],
    \\  "mutation_authority": "none",
    \\  "applied": false,
    \\  "source": {
    \\    "app_remediation_audit": ".zig-cache/causal-artifacts/app-audit.json",
    \\    "app_artifact": ".zig-cache/causal-artifacts/app.json"
    \\  },
    \\  "policy_gates": ["config-only", "source-only"],
    \\  "gate_results": [],
    \\  "event_ids": [2, 3],
    \\  "required_verification_commands": ["zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 2"],
    \\  "guardrails": ["Policy approval is advisory and does not apply app source, config, migrations, operations, or rollback actions."]
    \\}
;
```

Add a test that parses the policy, builds a proposal with one `--file` and one
`--config`, and expects JSON/text to contain:

```text
"schema": "zigeffect.causal.app-patch-proposal.v1"
"approval_status": "pending"
"approved": false
"applied": false
"mutation_authority": "none"
"source_files": ["apps/platform/src/worker.ts"]
"config_keys": ["YACHDEE_ENV"]
zigeffect app patch proposal
```

- [ ] **Step 2: Add failing tests for rejection cases**

Add tests that expect:

- non-`approve` policy returns `error.PolicyNotApproved`;
- `source-only` with no source file returns `error.MissingSourceCitation`;
- `config-only` with no config key returns `error.MissingConfigCitation`;
- `migration-required` returns `error.HighRiskGateRequiresHumanReview`;
- no citations at all returns `error.MissingProposalCitation`.

- [ ] **Step 3: Run and confirm RED**

Run:

```sh
cd packages/zigeffect && zig test tools/causal_app_patch_proposal.zig
```

Expected: FAIL because policy structs and formatting are missing.

- [ ] **Step 4: Implement policy validation and formatting**

Implement the following units:

- `PolicySource`
- `AppPolicyRecord`
- `CitationSet`
- `ProposalInput`
- `parseAppPolicy`
- `validateAppPolicy`
- `proposalInputFromPolicy`
- `formatAppPatchProposalJson`
- `formatAppPatchProposalText`
- JSON helpers copied from sibling tools.

Guardrails must include:

```text
This proposal does not edit app source, config, migrations, operations, or rollback plans.
Policy approval only authorizes drafting; the proposal still requires review before application.
Config citations name keys or bindings only; never include secret values.
```

- [ ] **Step 5: Run and confirm GREEN**

Run:

```sh
cd packages/zigeffect && zig test tools/causal_app_patch_proposal.zig
```

Expected: PASS.

## Task 4: Wire the CLI Executable

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_patch_proposal.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add CLI read/write functions and `main`**

Implement:

- `readArtifact`
- `writeArtifact`
- `runLocal`
- `failUsage`
- `main`

The no-args path must fail with usage and exit code `2`.

- [ ] **Step 2: Add executable and examples wiring**

Add near the app policy executable:

```zig
const causal_app_patch_proposal_tool = b.addExecutable(.{
    .name = "zigeffect-causal-app-patch-proposal",
    .root_module = causal_app_patch_proposal_tool_module,
});
const run_causal_app_patch_proposal_tool = b.addRunArtifact(causal_app_patch_proposal_tool);
if (b.args) |args| run_causal_app_patch_proposal_tool.addArgs(args);
const causal_app_patch_proposal_step = b.step("causal-app-patch-proposal", "Write a non-mutating app patch proposal from an app policy decision");
causal_app_patch_proposal_step.dependOn(&run_causal_app_patch_proposal_tool.step);
```

Add to examples:

```zig
examples_step.dependOn(&causal_app_patch_proposal_tool.step);
examples_step.dependOn(&run_causal_app_patch_proposal_tool_tests.step);
```

- [ ] **Step 3: Verify command gating and examples**

Run:

```sh
cd packages/zigeffect && zig build causal-app-patch-proposal
cd packages/zigeffect && zig build examples
```

Expected: first command exits with usage because required args are missing;
second command passes.

## Task 5: Register Workbench Governance Detection

**Files:**
- Modify: `packages/zigeffect/workbench/src/causalArtifact.test.ts`
- Modify: `packages/zigeffect/workbench/src/causalArtifact.ts`

- [ ] **Step 1: Add failing model test**

Append:

```ts
test("deriveGovernanceModel detects app patch proposal artifacts", () => {
  const governance = deriveGovernanceModel({
    schema: "zigeffect.causal.app-patch-proposal.v1",
    schema_version: 1,
    target: "yachdee-platform",
    proposal_status: "draft",
    approval_status: "pending",
    applied: false,
    mutation_authority: "none",
  }, { artifactPath: "app-proposal.json" });

  expect(governance?.kind).toBe("app-patch-proposal");
  expect(governance?.summary).toContain("draft app patch proposal");
  expect(governance?.applied).toBe(false);
  expect(governance?.mutationAuthority).toBe("none");
});
```

- [ ] **Step 2: Run and confirm RED**

Run:

```sh
bun run zigeffect:workbench:test
```

Expected: FAIL because `app-patch-proposal` is not a governance kind yet.

- [ ] **Step 3: Implement governance detection**

In `causalArtifact.ts`:

- Add `"app-patch-proposal"` to `GovernanceArtifactKind`.
- Add schema case for `zigeffect.causal.app-patch-proposal.v1`.
- Add summary:

```ts
kind === "app-patch-proposal"
  ? `${textValue(artifact.proposal_status, "unknown")} app patch proposal for ${target}`
```

- [ ] **Step 4: Run and confirm GREEN**

Run:

```sh
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
```

Expected: PASS.

## Task 6: Update Documentation and Roadmaps

**Files:**
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Document the command**

Add the command after app policy decision docs:

```sh
zig build causal-app-patch-proposal -- local --policy <app-policy-decision-json> --summary <summary> --change <description> --file <path> --config <key>
```

State that it writes `*-app-patch-proposal.json` and
`*-app-patch-proposal.txt`, preserves `applied=false` and
`mutation_authority=none`, and cites only names/paths, not secret values.

- [ ] **Step 2: Update roadmap status**

Change M8 status to say app remediation audit, app policy decisions, and app
patch proposal artifacts exist. The next branch should be:

```text
codex/zigeffect-app-remediation-workbench
```

with SolidJS plus `zig-webui` as the UI path.

- [ ] **Step 3: Run docs checks**

Run:

```sh
rg -n "app patch proposals remain|Still future: .*app patch proposals" packages/zigeffect docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git diff --check
```

Expected: no stale "remain/future" phrasing about app patch proposals and no whitespace errors.

## Task 7: Full Verification and Commit

**Files:**
- All files changed in Tasks 1-6.

- [ ] **Step 1: Run full verification**

Run:

```sh
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build test
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run check
bun run zig:test
git diff --check
```

Expected: all commands pass.

- [ ] **Step 2: Review git status**

Run:

```sh
git status --short
```

Expected: only intended branch changes plus the pre-existing untracked durable
roadmap file.

- [ ] **Step 3: Commit implementation**

Run:

```sh
git add packages/zigeffect/tools/causal_app_patch_proposal.zig \
  packages/zigeffect/build.zig \
  packages/zigeffect/workbench/src/causalArtifact.ts \
  packages/zigeffect/workbench/src/causalArtifact.test.ts \
  packages/zigeffect/README.md \
  packages/zigeffect/docs/agent-guide.md \
  packages/zigeffect/docs/agent-observable-runtime.md \
  packages/zigeffect/docs/roadmap.md \
  docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md

git commit -m "feat(zigeffect): add app patch proposal artifacts"
```

Expected: commit succeeds and the branch is ready for the next M8 workbench
slice.
