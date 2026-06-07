# zigeffect Causal Patch Proposal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `zig build causal-patch-proposal -- local draft|approved [scenario] --summary <summary> --file <path> --change <description>`, a deterministic non-mutating proposal artifact that links intended file changes to audit or approved decision evidence.

**Architecture:** Create a focused `causal_patch_proposal.zig` tool that reads either remediation audit JSON or remediation decision JSON, validates the review state, and writes schema-versioned JSON plus a human text report. Wire the command into `build.zig`, add proposal paths to the artifact manifest, update agent docs and roadmaps, and verify default/scenario flows.

**Tech Stack:** Zig 0.16 build system, Zig std JSON parser, existing `causal_run` scenario registry and artifact directory, existing remediation audit and decision artifact conventions, Bun repo verification commands.

---

## File Structure

- Create `packages/zigeffect/tools/causal_patch_proposal.zig`
  - Proposal path helpers for default and scenario artifacts.
  - CLI parser for `local draft|approved [scenario] --summary --file --change`.
  - Audit and decision input structs.
  - Validation for pending audits and approved decisions.
  - JSON formatter for `zigeffect.causal.patch-proposal.v1`.
  - Human text formatter.
  - Artifact reader/writer and CLI `main`.
  - Unit tests.
- Modify `packages/zigeffect/build.zig`
  - Add module, executable, run step, tests, and `examples` dependency.
  - Import `causal_run`.
- Modify `packages/zigeffect/tools/causal_artifacts.zig`
  - Add default and scenario patch proposal JSON/text paths to the retention
    manifest.
  - Strengthen manifest tests.
- Modify `packages/zigeffect/README.md`
  - Document patch proposal after audit/decision.
- Modify `packages/zigeffect/docs/agent-guide.md`
  - Add draft and approved proposal commands to the local self-improvement
    workflow.
- Modify `packages/zigeffect/docs/causal-scenarios.md`
  - Add command reference and artifact paths.
- Modify `docs/superpowers/specs/2026-06-07-zigeffect-self-improving-dev-harness-roadmap.md`
  - Expand Milestone 3 with the chosen first-slice contract.
- Modify `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`
  - Mark the patch-proposal branch as the next active milestone.
- Modify `packages/zigeffect/docs/roadmap.md`
  - Mention the proposed patch boundary in the causal self-improvement track.

## Task 1: Parser, Paths, And Build Test Wiring

**Files:**
- Create: `packages/zigeffect/tools/causal_patch_proposal.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Write failing tests for paths, parser, and usage**

Create `packages/zigeffect/tools/causal_patch_proposal.zig` with:

```zig
const std = @import("std");
const causal_run = @import("causal_run");

const audit_schema = "zigeffect.causal.remediation-audit.v1";
const decision_schema = "zigeffect.causal.remediation-decision.v1";
const proposal_schema = "zigeffect.causal.patch-proposal.v1";

const ProposalStatus = enum {
    draft,
    approved,
};

const ProposalOptions = struct {
    mode: []const u8,
    status: ProposalStatus,
    scenario_slug: ?[]const u8 = null,
    summary: []const u8,
    file: []const u8,
    change: []const u8,
};
```

Add tests:

```zig
test "patch proposal output paths are stable for default and scenario targets" {
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-patch-proposal.json",
        localProposalJsonPath(),
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-patch-proposal.txt",
        localProposalTextPath(),
    );

    const scenario_json = try localProposalJsonPathForScenario(std.testing.allocator, "causal-scoped-fiber");
    defer std.testing.allocator.free(scenario_json);
    const scenario_text = try localProposalTextPathForScenario(std.testing.allocator, "causal-scoped-fiber");
    defer std.testing.allocator.free(scenario_text);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-patch-proposal.json",
        scenario_json,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-patch-proposal.txt",
        scenario_text,
    );
}

test "parse options accepts draft metadata" {
    const args = [_][]const u8{
        "zigeffect-causal-patch-proposal",
        "local",
        "draft",
        "--summary",
        "tighten scope close ordering",
        "--file",
        "packages/zigeffect/src/core/scope.zig",
        "--change",
        "ensure child finalizers run before parent close is reported",
    };

    const options = try parseProposalOptions(args[0..]);
    try std.testing.expectEqual(ProposalStatus.draft, options.status);
    try std.testing.expect(options.scenario_slug == null);
    try std.testing.expectEqualStrings("tighten scope close ordering", options.summary);
    try std.testing.expectEqualStrings("packages/zigeffect/src/core/scope.zig", options.file);
    try std.testing.expectEqualStrings("ensure child finalizers run before parent close is reported", options.change);
}

test "parse options accepts approved scenario metadata" {
    const args = [_][]const u8{
        "zigeffect-causal-patch-proposal",
        "local",
        "approved",
        "causal-scoped-fiber",
        "--summary",
        "record scoped fiber interruption",
        "--file",
        "packages/zigeffect/src/runtime/fiber.zig",
        "--change",
        "emit interrupted event before release evidence",
    };

    const options = try parseProposalOptions(args[0..]);
    try std.testing.expectEqual(ProposalStatus.approved, options.status);
    try std.testing.expectEqualStrings("causal-scoped-fiber", options.scenario_slug.?);
}

test "parse options requires summary file and change" {
    const missing_summary = [_][]const u8{
        "zigeffect-causal-patch-proposal",
        "local",
        "draft",
        "--file",
        "packages/zigeffect/src/core/scope.zig",
        "--change",
        "change",
    };
    try std.testing.expectError(error.MissingSummary, parseProposalOptions(missing_summary[0..]));

    const missing_file = [_][]const u8{
        "zigeffect-causal-patch-proposal",
        "local",
        "draft",
        "--summary",
        "summary",
        "--change",
        "change",
    };
    try std.testing.expectError(error.MissingFile, parseProposalOptions(missing_file[0..]));

    const missing_change = [_][]const u8{
        "zigeffect-causal-patch-proposal",
        "local",
        "draft",
        "--summary",
        "summary",
        "--file",
        "packages/zigeffect/src/core/scope.zig",
    };
    try std.testing.expectError(error.MissingChange, parseProposalOptions(missing_change[0..]));
}

test "usage names local proposal shape" {
    try std.testing.expectEqualStrings(
        "usage: zig build causal-patch-proposal -- local draft|approved [scenario] --summary <summary> --file <path> --change <description>\n",
        usage(),
    );
}
```

- [ ] **Step 2: Wire the test module and verify red**

Add to `packages/zigeffect/build.zig` near the remediation tools:

```zig
const causal_patch_proposal_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_patch_proposal.zig"),
    .target = target,
    .optimize = optimize,
});
causal_patch_proposal_tool_module.addImport("causal_run", causal_run_tool_module);

const causal_patch_proposal_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-patch-proposal-tests",
    .root_module = causal_patch_proposal_tool_module,
});
const run_causal_patch_proposal_tool_tests = b.addRunArtifact(causal_patch_proposal_tool_tests);
```

Add the aggregate dependency:

```zig
examples_step.dependOn(&run_causal_patch_proposal_tool_tests.step);
```

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: FAIL with missing helper names such as `localProposalJsonPath` and
`parseProposalOptions`.

- [ ] **Step 3: Implement path helpers, status helpers, parser, and usage**

Add:

```zig
fn localProposalJsonPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-patch-proposal.json";
}

fn localProposalTextPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-patch-proposal.txt";
}

fn localProposalJsonPathForScenario(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-patch-proposal.json", .{ causal_run.artifact_dir, scenario_slug });
}

fn localProposalTextPathForScenario(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-patch-proposal.txt", .{ causal_run.artifact_dir, scenario_slug });
}

fn parseProposalStatus(value: []const u8) ?ProposalStatus {
    if (std.mem.eql(u8, value, "draft")) return .draft;
    if (std.mem.eql(u8, value, "approved")) return .approved;
    return null;
}

fn proposalStatusText(status: ProposalStatus) []const u8 {
    return switch (status) {
        .draft => "draft",
        .approved => "approved",
    };
}

fn parseProposalOptions(args: []const []const u8) !ProposalOptions {
    if (args.len < 2) return error.MissingMode;
    if (!std.mem.eql(u8, args[1], "local")) return error.UnknownMode;
    if (args.len < 3) return error.MissingProposalStatus;

    const status = parseProposalStatus(args[2]) orelse return error.UnknownProposalStatus;
    var scenario_slug: ?[]const u8 = null;
    var summary: ?[]const u8 = null;
    var file: ?[]const u8 = null;
    var change: ?[]const u8 = null;

    var index: usize = 3;
    while (index < args.len) {
        const arg = args[index];
        if (std.mem.startsWith(u8, arg, "--")) {
            if (index + 1 >= args.len) return error.MissingFlagValue;
            const value = args[index + 1];
            if (std.mem.eql(u8, arg, "--summary")) {
                summary = value;
            } else if (std.mem.eql(u8, arg, "--file")) {
                file = value;
            } else if (std.mem.eql(u8, arg, "--change")) {
                change = value;
            } else {
                return error.UnknownFlag;
            }
            index += 2;
        } else {
            if (scenario_slug != null) return error.DuplicateScenarioArgument;
            scenario_slug = arg;
            index += 1;
        }
    }

    return .{
        .mode = "local",
        .status = status,
        .scenario_slug = scenario_slug,
        .summary = summary orelse return error.MissingSummary,
        .file = file orelse return error.MissingFile,
        .change = change orelse return error.MissingChange,
    };
}

fn usage() []const u8 {
    return "usage: zig build causal-patch-proposal -- local draft|approved [scenario] --summary <summary> --file <path> --change <description>\n";
}
```

- [ ] **Step 4: Verify parser/path tests pass and commit**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: PASS.

Commit:

```sh
git add packages/zigeffect/tools/causal_patch_proposal.zig packages/zigeffect/build.zig
git commit -m "feat(zigeffect): add causal patch proposal parser"
```

## Task 2: Draft Proposal From Pending Audit

**Files:**
- Modify: `packages/zigeffect/tools/causal_patch_proposal.zig`

- [ ] **Step 1: Write failing tests for pending audit validation and draft JSON**

Add `ArtifactSource`, `AuditRecord`, `ProposalSource`, `ProposalInput`, a
`pending_audit_json` fixture matching `causal_remediation_audit.zig`, and tests
that assert:

```zig
try validateAuditRecord(parsed.value);
try std.testing.expectError(error.AuditNotPending, validateAuditRecord(non_pending));
try std.testing.expectError(error.AuditAlreadyApplied, validateAuditRecord(applied));
```

Add a draft formatter test that asserts the JSON contains:

```text
"schema": "zigeffect.causal.patch-proposal.v1"
"proposal_status": "draft"
"approval_status": "pending"
"approved": false
"applied": false
"decision": null
"file": "packages/zigeffect/src/core/scope.zig"
"event_ids": [3, 4, 5, 6]
"Draft proposals are not approval for source edits."
```

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: FAIL with missing validation and formatter helpers.

- [ ] **Step 2: Implement pending audit validation and conversion**

Add:

```zig
fn validateAuditRecord(audit: AuditRecord) !void {
    if (!std.mem.eql(u8, audit.schema, audit_schema)) return error.UnsupportedAuditSchema;
    if (audit.schema_version != 1) return error.UnsupportedAuditSchema;
    if (!std.mem.eql(u8, audit.mode, "local")) return error.UnsupportedAuditSchema;
    if (!std.mem.eql(u8, audit.approval_status, "pending")) return error.AuditNotPending;
    if (audit.applied) return error.AuditAlreadyApplied;
}

fn proposalInputFromAudit(options: ProposalOptions, audit_path: []const u8, audit: AuditRecord) ProposalInput {
    return .{
        .options = options,
        .target = audit.target,
        .source = .{
            .audit = audit_path,
            .decision = null,
            .artifacts = audit.source,
        },
        .event_ids = audit.event_ids,
        .verification_commands = audit.verification_commands,
        .claim_guardrails = audit.claim_guardrails,
    };
}
```

- [ ] **Step 3: Implement JSON formatter**

Follow the existing `causal_remediation_decision.zig` JSON style. Implement:

```zig
fn approvalStatusText(status: ProposalStatus) []const u8
fn approvedBool(status: ProposalStatus) bool
fn firstProposalGuardrail() []const u8
fn secondProposalGuardrail(status: ProposalStatus) []const u8
fn thirdProposalGuardrail() []const u8
fn appendJsonString(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: []const u8) !void
fn appendU64Array(allocator: std.mem.Allocator, output: *std.ArrayList(u8), values: []const u64) !void
fn appendStringArray(allocator: std.mem.Allocator, output: *std.ArrayList(u8), values: []const []const u8) !void
fn appendSourceJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), input: ProposalInput) !void
fn formatProposalJson(allocator: std.mem.Allocator, input: ProposalInput) ![]const u8
```

`formatProposalJson` must emit fields in this order: `schema`,
`schema_version`, `mode`, `target`, `proposal_status`, `approval_status`,
`approved`, `applied`, `summary`, `source`, `proposed_changes`, `event_ids`,
`verification_commands`, `claim_guardrails`, `proposal_guardrails`.

- [ ] **Step 4: Verify draft proposal tests and commit**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: PASS.

Commit:

```sh
git add packages/zigeffect/tools/causal_patch_proposal.zig
git commit -m "feat(zigeffect): draft causal patch proposals"
```

## Task 3: Approved Proposal From Decision

**Files:**
- Modify: `packages/zigeffect/tools/causal_patch_proposal.zig`

- [ ] **Step 1: Write failing tests for approved decision validation and JSON**

Add `DecisionSource`, `DecisionRecord`, and an `approved_decision_json` fixture
matching `causal_remediation_decision.zig`.

Add validation tests:

```zig
try validateDecisionRecord(parsed.value);
try std.testing.expectError(error.DecisionNotApproved, validateDecisionRecord(rejected));
try std.testing.expectError(error.DecisionAlreadyApplied, validateDecisionRecord(applied));
```

Add an approved formatter test that asserts the JSON contains:

```text
"proposal_status": "approved"
"approval_status": "approved"
"approved": true
"decision": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-decision.json"
"audit": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json"
"Approval permits reviewable patch work but does not prove the fix."
```

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: FAIL with missing decision validation and conversion helpers.

- [ ] **Step 2: Implement approved decision validation and conversion**

Add:

```zig
fn validateDecisionRecord(decision: DecisionRecord) !void {
    if (!std.mem.eql(u8, decision.schema, decision_schema)) return error.UnsupportedDecisionSchema;
    if (decision.schema_version != 1) return error.UnsupportedDecisionSchema;
    if (!std.mem.eql(u8, decision.mode, "local")) return error.UnsupportedDecisionSchema;
    if (!std.mem.eql(u8, decision.decision, "approved")) return error.DecisionNotApproved;
    if (!std.mem.eql(u8, decision.approval_status, "approved")) return error.DecisionNotApproved;
    if (decision.applied) return error.DecisionAlreadyApplied;
}

fn proposalInputFromDecision(options: ProposalOptions, decision_path: []const u8, decision: DecisionRecord) ProposalInput {
    return .{
        .options = options,
        .target = decision.target,
        .source = .{
            .audit = decision.source.audit,
            .decision = decision_path,
            .artifacts = .{
                .verdict = decision.source.verdict,
                .diagnosis = decision.source.diagnosis,
                .remediation_plan = decision.source.remediation_plan,
                .advice = decision.source.advice,
                .query = decision.source.query,
                .compare = decision.source.compare,
            },
        },
        .event_ids = decision.event_ids,
        .verification_commands = decision.verification_commands,
        .claim_guardrails = decision.claim_guardrails,
    };
}
```

- [ ] **Step 3: Verify approved proposal tests and commit**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: PASS.

Commit:

```sh
git add packages/zigeffect/tools/causal_patch_proposal.zig
git commit -m "feat(zigeffect): approve causal patch proposals from decisions"
```

## Task 4: CLI Main, Text Report, And Integration Command

**Files:**
- Modify: `packages/zigeffect/tools/causal_patch_proposal.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add executable build step**

Add after the remediation decision executable:

```zig
const causal_patch_proposal_tool = b.addExecutable(.{
    .name = "zigeffect-causal-patch-proposal",
    .root_module = causal_patch_proposal_tool_module,
});
const run_causal_patch_proposal_tool = b.addRunArtifact(causal_patch_proposal_tool);
if (b.args) |args| run_causal_patch_proposal_tool.addArgs(args);
const causal_patch_proposal_step = b.step("causal-patch-proposal", "Write a non-mutating causal patch proposal from audit or decision evidence");
causal_patch_proposal_step.dependOn(&run_causal_patch_proposal_tool.step);
```

- [ ] **Step 2: Implement artifact IO and `main`**

Add input path helpers for default and scenario audit/decision paths, using the
same string shapes as `causal_remediation_audit.zig` and
`causal_remediation_decision.zig`.

Implement:

```zig
fn formatProposalText(allocator: std.mem.Allocator, input: ProposalInput) ![]const u8
fn readArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8
fn writeArtifact(io: std.Io, path: []const u8, contents: []const u8) !void
fn runLocal(init: std.process.Init, options: ProposalOptions) !void
pub fn main(init: std.process.Init) !void
```

`runLocal` must:

- validate `options.scenario_slug` through `causal_run.scenarioByName`;
- choose proposal output paths from the scenario slug;
- for `draft`, read and validate the audit artifact;
- for `approved`, read and validate the decision artifact;
- write JSON and text proposal artifacts;
- print the text report.

`main` must route usage-style errors for parser, validation, and artifact input
failures.

- [ ] **Step 3: Verify command compiles**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: PASS.

- [ ] **Step 4: Run default draft and approved integration**

Run:

```sh
cd packages/zigeffect && zig build causal-dev-session -- start
cd packages/zigeffect && zig build causal-dev-session -- assess
cd packages/zigeffect && zig build causal-patch-proposal -- local draft --summary "tighten scope close ordering" --file packages/zigeffect/src/core/scope.zig --change "ensure child finalizers run before parent close is reported"
cd packages/zigeffect && zig build causal-remediation-decision -- local approve --by local-reviewer --policy manual-review
cd packages/zigeffect && zig build causal-patch-proposal -- local approved --summary "tighten scope close ordering" --file packages/zigeffect/src/core/scope.zig --change "ensure child finalizers run before parent close is reported"
```

Expected: proposal JSON/text artifacts exist; draft output says
`approved: false`; approved output says `approved: true`; both say
`applied: false`.

Commit:

```sh
git add packages/zigeffect/tools/causal_patch_proposal.zig packages/zigeffect/build.zig
git commit -m "feat(zigeffect): write causal patch proposal artifacts"
```

## Task 5: Manifest, Docs, And Roadmap Updates

**Files:**
- Modify: `packages/zigeffect/tools/causal_artifacts.zig`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify: `docs/superpowers/specs/2026-06-07-zigeffect-self-improving-dev-harness-roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`
- Modify: `packages/zigeffect/docs/roadmap.md`

- [ ] **Step 1: Add proposal paths to `causal-artifacts`**

Update manifest output and tests so it lists:

```text
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-patch-proposal.json
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-patch-proposal.txt
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-patch-proposal.json
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-patch-proposal.txt
```

Run:

```sh
cd packages/zigeffect && zig build causal-artifacts
cd packages/zigeffect && zig build examples
```

Expected: manifest includes proposal paths and examples pass.

- [ ] **Step 2: Update user-facing docs**

Add these commands to README, agent guide, and scenario docs:

```sh
zig build causal-patch-proposal -- local draft [scenario] --summary <summary> --file <path> --change <description>
zig build causal-patch-proposal -- local approved [scenario] --summary <summary> --file <path> --change <description>
```

The docs must state:

- draft proposals are unapproved;
- approved proposals require an approved remediation decision;
- proposal artifacts still have `applied=false`;
- the command never edits source.

- [ ] **Step 3: Update roadmaps**

Mark Milestone 3 as active or delivered, depending on implementation state, in:

```text
docs/superpowers/specs/2026-06-07-zigeffect-self-improving-dev-harness-roadmap.md
docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md
packages/zigeffect/docs/roadmap.md
```

Patch application and audit-chain comparison must remain future milestones.

- [ ] **Step 4: Verify docs and commit**

Run:

```sh
git diff --check
cd packages/zigeffect && zig build causal-artifacts
cd packages/zigeffect && zig build examples
```

Expected: all pass.

Commit:

```sh
git add packages/zigeffect/tools/causal_artifacts.zig packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/causal-scenarios.md docs/superpowers/specs/2026-06-07-zigeffect-self-improving-dev-harness-roadmap.md docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md packages/zigeffect/docs/roadmap.md
git commit -m "docs(zigeffect): document causal patch proposals"
```

## Task 6: Final Verification And Merge

**Files:**
- Verify all changed files.

- [ ] **Step 1: Run scenario integration**

Run:

```sh
cd packages/zigeffect && zig build causal-dev-session -- start causal-scoped-fiber
cd packages/zigeffect && zig build causal-dev-session -- assess causal-scoped-fiber
cd packages/zigeffect && zig build causal-patch-proposal -- local draft causal-scoped-fiber --summary "record scoped fiber interruption" --file packages/zigeffect/src/runtime/fiber.zig --change "emit interrupted event before release evidence"
cd packages/zigeffect && zig build causal-remediation-decision -- local approve causal-scoped-fiber --by local-reviewer --policy manual-review
cd packages/zigeffect && zig build causal-patch-proposal -- local approved causal-scoped-fiber --summary "record scoped fiber interruption" --file packages/zigeffect/src/runtime/fiber.zig --change "emit interrupted event before release evidence"
```

Expected: all commands pass and write scenario proposal artifacts.

- [ ] **Step 2: Verify rejected decision fails cleanly**

Run:

```sh
cd packages/zigeffect && zig build causal-remediation-decision -- local reject causal-scoped-fiber --reason "exercise rejection guardrail"
cd packages/zigeffect && zig build causal-patch-proposal -- local approved causal-scoped-fiber --summary "should fail" --file packages/zigeffect/src/runtime/fiber.zig --change "should fail"
```

Expected: second command exits nonzero with `DecisionNotApproved`.

Restore an approved decision for future local work:

```sh
cd packages/zigeffect && zig build causal-remediation-decision -- local approve causal-scoped-fiber --by local-reviewer --policy manual-review
```

- [ ] **Step 3: Run full verification**

Run:

```sh
git diff --check
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build test --summary none
bun run check
bun run zig:test
```

Expected: all pass.

- [ ] **Step 4: Merge to master**

Run:

```sh
git status --short
git checkout master
git merge --no-ff codex/zigeffect-causal-remediation-proposal -m "merge zigeffect causal patch proposal"
git branch -d codex/zigeffect-causal-remediation-proposal
```

Expected: merge succeeds and deleted branch is fully merged.

## Self-Review

- Spec coverage: command shape, artifact paths, schema, draft/approved behavior,
  validation, docs, manifest, integration, and future boundaries all have tasks.
- Placeholder scan: no placeholder tokens or unspecified implementation step remains.
- Type consistency: `ProposalStatus`, `ProposalOptions`, `ProposalInput`,
  `AuditRecord`, `DecisionRecord`, and command names are consistent across tasks.
