# zigeffect App Human Review Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a non-mutating app human-review artifact and require approved review evidence before high-risk app patch proposals can be drafted.

**Architecture:** Implement a new Zig CLI tool, `causal-app-human-review`, that consumes `app-policy-decision` artifacts whose decision is `needs-human-review` and writes schema-versioned review evidence with `mutation_authority=none` and `applied=false`. Extend `causal-app-patch-proposal` so low-risk approved policies keep the existing path, while high-risk policies require a matching approved human-review artifact. Register the new schema in the SolidJS workbench model and sample routing.

**Tech Stack:** Zig build tools and tests, `std.json`, existing zigeffect artifact formatting patterns, Bun/SolidJS workbench tests, `zig-webui`-hosted workbench.

---

## File Structure

- Create `packages/zigeffect/tools/causal_app_human_review.zig`
  - Owns CLI parsing, policy parsing, high-risk gate citation validation,
    review report formatting, artifact IO, and focused Zig tests.
- Modify `packages/zigeffect/build.zig`
  - Adds test module, executable, and `causal-app-human-review` build step.
- Modify `packages/zigeffect/tools/causal_app_patch_proposal.zig`
  - Adds optional `--review`, parses app human-review artifacts, validates
    matching approved review evidence, and includes `source.human_review` in
    high-risk proposals.
- Modify `packages/zigeffect/workbench/src/causalArtifact.ts`
  - Adds `app-human-review` kind, summary, source step, and schema detection.
- Modify `packages/zigeffect/workbench/src/causalArtifact.test.ts`
  - Adds model coverage for app human review and proposal source review paths.
- Modify `packages/zigeffect/workbench/src/workbenchBridge.ts`
  - Adds `?sample=app-review` sample routing.
- Modify `packages/zigeffect/workbench/src/workbenchBridge.test.ts`
  - Adds sample route coverage.
- Create `packages/zigeffect/workbench/public/sample-app-human-review.json`
  - Development fixture for the workbench.
- Modify docs:
  - `packages/zigeffect/README.md`
  - `packages/zigeffect/docs/agent-guide.md`
  - `packages/zigeffect/docs/agent-observable-runtime.md`
  - `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

## Task 1: Add Focused RED Tests For Human Review Tool

**Files:**
- Create: `packages/zigeffect/tools/causal_app_human_review.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Wire the new Zig tool module in `build.zig`**

Add a sibling module near the other app remediation tools:

```zig
const causal_app_human_review_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_app_human_review.zig"),
    .target = target,
    .optimize = optimize,
});

const causal_app_human_review_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-app-human-review-tests",
    .root_module = causal_app_human_review_tool_module,
});
const run_causal_app_human_review_tool_tests = b.addRunArtifact(causal_app_human_review_tool_tests);
```

Add the executable step near `causal-app-policy-decision` and
`causal-app-patch-proposal`:

```zig
const causal_app_human_review_tool = b.addExecutable(.{
    .name = "zigeffect-causal-app-human-review",
    .root_module = causal_app_human_review_tool_module,
});
const run_causal_app_human_review_tool = b.addRunArtifact(causal_app_human_review_tool);
if (b.args) |args| run_causal_app_human_review_tool.addArgs(args);
const causal_app_human_review_step = b.step("causal-app-human-review", "Write non-mutating app human-review evidence from a high-risk app policy decision");
causal_app_human_review_step.dependOn(&run_causal_app_human_review_tool.step);
```

Add the tests to the package test aggregator:

```zig
test_step.dependOn(&run_causal_app_human_review_tool_tests.step);
```

- [ ] **Step 2: Create the RED test file**

Create `packages/zigeffect/tools/causal_app_human_review.zig` with test code
that references the intended API before implementation:

```zig
const std = @import("std");

const app_policy_schema = "zigeffect.causal.app-policy-decision.v1";
const app_human_review_schema = "zigeffect.causal.app-human-review.v1";

const needs_review_policy_json =
    \\{
    \\  "schema": "zigeffect.causal.app-policy-decision.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "yachdee-platform",
    \\  "decision": "needs-human-review",
    \\  "approval_status": "needs-human-review",
    \\  "evaluated_by": "local-app-policy-engine",
    \\  "policy": "local-app-remediation-policy-v1",
    \\  "reason": "app audit contains high-risk gates that require human review",
    \\  "reason_codes": ["app-high-risk-gate-review-required"],
    \\  "mutation_authority": "none",
    \\  "applied": false,
    \\  "source": {
    \\    "app_remediation_audit": ".zig-cache/causal-artifacts/app-audit.json",
    \\    "app_artifact": ".zig-cache/causal-artifacts/app.json"
    \\  },
    \\  "policy_gates": ["migration-required", "operational-human-required", "rollback-required"],
    \\  "gate_results": [],
    \\  "event_ids": [4],
    \\  "required_verification_commands": ["zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 4"],
    \\  "guardrails": ["Policy approval is advisory and does not apply app source, config, migrations, operations, or rollback actions."]
    \\}
;

test "usage text names human review inputs" {
    try std.testing.expect(std.mem.indexOf(u8, usage(), "causal-app-human-review") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage(), "--policy <app-policy-decision-json>") != null);
    try std.testing.expectEqualStrings("zigeffect.causal.app-policy-decision.v1", app_policy_schema);
    try std.testing.expectEqualStrings("zigeffect.causal.app-human-review.v1", app_human_review_schema);
}

test "human review options parse repeated citations and verified commands" {
    const args = [_][]const u8{
        "zigeffect-causal-app-human-review",
        "local",
        "--policy",
        "app-policy.json",
        "--reviewer",
        "local-reviewer",
        "--decision",
        "approve",
        "--reason",
        "reviewed migration and rollback evidence",
        "--migration",
        "packages/app/migrations/001.sql",
        "--runbook",
        "docs/runbooks/migration.md",
        "--rollback",
        "docs/runbooks/rollback.md",
        "--verified",
        "zig build causal-query -- --file app.json cause 4",
    };

    var options = try parseOptions(std.testing.allocator, &args);
    defer options.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("local", options.mode);
    try std.testing.expectEqualStrings("app-policy.json", options.policy_path);
    try std.testing.expectEqualStrings("local-reviewer", options.reviewer);
    try std.testing.expectEqual(ReviewDecision.approve, options.decision);
    try std.testing.expectEqual(@as(usize, 1), options.migration_files.len);
    try std.testing.expectEqual(@as(usize, 1), options.runbooks.len);
    try std.testing.expectEqual(@as(usize, 1), options.rollback_plans.len);
    try std.testing.expectEqual(@as(usize, 1), options.reviewed_verification_commands.len);
}

test "human review output paths derive from policy path and out prefix" {
    const defaults = try outputPathsForOptions(std.testing.allocator, .{
        .mode = "local",
        .policy_path = ".zig-cache/causal-artifacts/app-policy.json",
        .reviewer = "reviewer",
        .decision = .approve,
        .reason = "reason",
    });
    defer defaults.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/app-policy-app-human-review.json",
        defaults.json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/app-policy-app-human-review.txt",
        defaults.text_path,
    );
}

test "needs human review policy produces approved non-mutating review artifact" {
    var parsed = try parseAppPolicy(std.testing.allocator, needs_review_policy_json);
    defer parsed.deinit();

    const options = Options{
        .mode = "local",
        .policy_path = "app-policy.json",
        .reviewer = "local-reviewer",
        .decision = .approve,
        .reason = "reviewed migration and rollback evidence",
        .migration_files = &.{"packages/app/migrations/001.sql"},
        .runbooks = &.{"docs/runbooks/migration.md"},
        .rollback_plans = &.{"docs/runbooks/rollback.md"},
        .reviewed_verification_commands = &.{"zig build causal-query -- --file app.json cause 4"},
    };

    var input = try reviewInputFromPolicy(std.testing.allocator, options, "app-policy.json", parsed.value);
    defer input.deinit(std.testing.allocator);

    var reports = try formatAppHumanReviewReports(std.testing.allocator, input);
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"schema\": \"zigeffect.causal.app-human-review.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"review_status\": \"approved\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"approved\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"mutation_authority\": \"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "zigeffect app human review") != null);
}
```

- [ ] **Step 3: Run focused RED verification**

Run:

```sh
cd packages/zigeffect && zig build causal-app-human-review
```

Expected: fails because `usage`, `parseOptions`, `ReviewDecision`,
`outputPathsForOptions`, `Options`, `parseAppPolicy`, `reviewInputFromPolicy`,
and `formatAppHumanReviewReports` are not implemented yet.

## Task 2: Implement `causal-app-human-review`

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_human_review.zig`

- [ ] **Step 1: Add the CLI data model**

Implement these top-level types:

```zig
const ReviewDecision = enum {
    approve,
    reject,
    changes_requested,
};

const Options = struct {
    mode: []const u8,
    policy_path: []const u8,
    reviewer: []const u8,
    decision: ReviewDecision,
    reason: []const u8,
    source_files: []const []const u8 = &.{},
    config_keys: []const []const u8 = &.{},
    migration_files: []const []const u8 = &.{},
    runbooks: []const []const u8 = &.{},
    rollback_plans: []const []const u8 = &.{},
    reviewed_verification_commands: []const []const u8 = &.{},
    out_prefix: ?[]const u8 = null,

    fn deinit(self: *Options, allocator: std.mem.Allocator) void {
        if (self.source_files.len > 0) allocator.free(self.source_files);
        if (self.config_keys.len > 0) allocator.free(self.config_keys);
        if (self.migration_files.len > 0) allocator.free(self.migration_files);
        if (self.runbooks.len > 0) allocator.free(self.runbooks);
        if (self.rollback_plans.len > 0) allocator.free(self.rollback_plans);
        if (self.reviewed_verification_commands.len > 0) allocator.free(self.reviewed_verification_commands);
    }
};
```

Also implement `OutputPaths`, `PolicySource`, `AppPolicyRecord`,
`ReviewSource`, `ReviewInput`, and `AppHumanReviewReports` with fields matching
the design spec.

- [ ] **Step 2: Implement parsing and validation**

Implement:

```zig
fn usage() []const u8
fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options
fn parseReviewDecision(value: []const u8) !ReviewDecision
fn outputPathsForOptions(allocator: std.mem.Allocator, options: Options) !OutputPaths
fn parseAppPolicy(allocator: std.mem.Allocator, json: []const u8) !std.json.Parsed(AppPolicyRecord)
fn validateAppPolicy(policy: AppPolicyRecord) !void
fn reviewInputFromPolicy(
    allocator: std.mem.Allocator,
    options: Options,
    policy_path: []const u8,
    policy: AppPolicyRecord,
) !ReviewInput
```

Validation behavior:

```zig
if (!std.mem.eql(u8, policy.schema, app_policy_schema)) return error.UnsupportedAppPolicySchema;
if (policy.schema_version != 1) return error.UnsupportedAppPolicySchema;
if (!std.mem.eql(u8, policy.mode, "local")) return error.UnsupportedAppPolicySchema;
if (!std.mem.eql(u8, policy.decision, "needs-human-review") or
    !std.mem.eql(u8, policy.approval_status, "needs-human-review"))
{
    return error.PolicyDoesNotNeedHumanReview;
}
if (policy.applied) return error.PolicyAlreadyApplied;
if (!std.mem.eql(u8, policy.mutation_authority, "none")) return error.PolicyMutationAuthorityNotNone;
if (options.reviewer.len == 0) return error.MissingReviewer;
if (options.reason.len == 0) return error.MissingReason;
```

For each policy gate:

```zig
if (std.mem.eql(u8, gate, "migration-required")) {
    saw_high_risk = true;
    if (options.migration_files.len == 0) return error.MissingMigrationCitation;
} else if (std.mem.eql(u8, gate, "operational-human-required")) {
    saw_high_risk = true;
    if (options.runbooks.len == 0) return error.MissingRunbookCitation;
} else if (std.mem.eql(u8, gate, "rollback-required")) {
    saw_high_risk = true;
    if (options.rollback_plans.len == 0) return error.MissingRollbackCitation;
} else if (std.mem.eql(u8, gate, "source-only") or std.mem.eql(u8, gate, "config-only")) {
    continue;
} else {
    return error.UnknownPolicyGate;
}
```

If no high-risk gate is found, return `error.PolicyDoesNotNeedHumanReview`.

- [ ] **Step 3: Implement report formatting and IO**

Implement:

```zig
fn formatAppHumanReviewReports(allocator: std.mem.Allocator, input: ReviewInput) !AppHumanReviewReports
fn formatAppHumanReviewJson(allocator: std.mem.Allocator, input: ReviewInput) ![]const u8
fn formatAppHumanReviewText(allocator: std.mem.Allocator, input: ReviewInput) ![]const u8
fn readArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8
fn writeArtifact(io: std.Io, path: []const u8, contents: []const u8) !void
fn runLocal(init: std.process.Init, options: Options) !void
pub fn main(init: std.process.Init) !void
```

The JSON output must include:

```json
"schema": "zigeffect.causal.app-human-review.v1",
"review_status": "approved",
"approval_status": "approved",
"approved": true,
"applied": false,
"mutation_authority": "none",
"reviewed_by": "local-reviewer"
```

The text output must include:

```text
zigeffect app human review
review_status: approved
approved: true
applied: false
mutation_authority: none
```

- [ ] **Step 4: Add negative tests**

Add focused tests to the same Zig file:

Define these supporting fixtures and helpers before the negative tests:

```zig
const approved_policy_json =
    \\{
    \\  "schema": "zigeffect.causal.app-policy-decision.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "yachdee-platform",
    \\  "decision": "approve",
    \\  "approval_status": "approve",
    \\  "mutation_authority": "none",
    \\  "applied": false,
    \\  "source": {"app_remediation_audit": "app-audit.json", "app_artifact": "app.json"},
    \\  "policy_gates": ["source-only"],
    \\  "event_ids": [2],
    \\  "required_verification_commands": [],
    \\  "guardrails": []
    \\}
;

const applied_needs_review_policy_json =
    \\{
    \\  "schema": "zigeffect.causal.app-policy-decision.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "yachdee-platform",
    \\  "decision": "needs-human-review",
    \\  "approval_status": "needs-human-review",
    \\  "mutation_authority": "none",
    \\  "applied": true,
    \\  "source": {"app_remediation_audit": "app-audit.json", "app_artifact": "app.json"},
    \\  "policy_gates": ["migration-required"],
    \\  "event_ids": [4],
    \\  "required_verification_commands": [],
    \\  "guardrails": []
    \\}
;

const mutating_needs_review_policy_json =
    \\{
    \\  "schema": "zigeffect.causal.app-policy-decision.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "yachdee-platform",
    \\  "decision": "needs-human-review",
    \\  "approval_status": "needs-human-review",
    \\  "mutation_authority": "app-source",
    \\  "applied": false,
    \\  "source": {"app_remediation_audit": "app-audit.json", "app_artifact": "app.json"},
    \\  "policy_gates": ["migration-required"],
    \\  "event_ids": [4],
    \\  "required_verification_commands": [],
    \\  "guardrails": []
    \\}
;

fn validHumanReviewOptions() Options {
    return .{
        .mode = "local",
        .policy_path = "app-policy.json",
        .reviewer = "local-reviewer",
        .decision = .approve,
        .reason = "reviewed evidence",
        .migration_files = &.{"packages/app/migrations/001.sql"},
        .runbooks = &.{"docs/runbooks/migration.md"},
        .rollback_plans = &.{"docs/runbooks/rollback.md"},
    };
}

fn rejectedHumanReviewOptions() Options {
    return .{
        .mode = "local",
        .policy_path = "app-policy.json",
        .reviewer = "local-reviewer",
        .decision = .reject,
        .reason = "evidence incomplete",
        .migration_files = &.{"packages/app/migrations/001.sql"},
        .runbooks = &.{"docs/runbooks/migration.md"},
        .rollback_plans = &.{"docs/runbooks/rollback.md"},
    };
}
```

```zig
test "human review rejects policies that do not need review" {
    var parsed = try parseAppPolicy(std.testing.allocator, approved_policy_json);
    defer parsed.deinit();

    try std.testing.expectError(error.PolicyDoesNotNeedHumanReview, reviewInputFromPolicy(std.testing.allocator, .{
        .mode = "local",
        .policy_path = "app-policy.json",
        .reviewer = "local-reviewer",
        .decision = .approve,
        .reason = "reviewed evidence",
        .migration_files = &.{"packages/app/migrations/001.sql"},
    }, "app-policy.json", parsed.value));
}

test "human review requires high risk citations" {
    var parsed = try parseAppPolicy(std.testing.allocator, needs_review_policy_json);
    defer parsed.deinit();

    try std.testing.expectError(error.MissingMigrationCitation, reviewInputFromPolicy(std.testing.allocator, .{
        .mode = "local",
        .policy_path = "app-policy.json",
        .reviewer = "local-reviewer",
        .decision = .approve,
        .reason = "reviewed evidence",
        .runbooks = &.{"docs/runbooks/migration.md"},
        .rollback_plans = &.{"docs/runbooks/rollback.md"},
    }, "app-policy.json", parsed.value));
}

test "human review rejects applied or mutating policies" {
    var applied = try parseAppPolicy(std.testing.allocator, applied_needs_review_policy_json);
    defer applied.deinit();
    try std.testing.expectError(error.PolicyAlreadyApplied, reviewInputFromPolicy(std.testing.allocator, validHumanReviewOptions(), "app-policy.json", applied.value));

    var mutating = try parseAppPolicy(std.testing.allocator, mutating_needs_review_policy_json);
    defer mutating.deinit();
    try std.testing.expectError(error.PolicyMutationAuthorityNotNone, reviewInputFromPolicy(std.testing.allocator, validHumanReviewOptions(), "app-policy.json", mutating.value));
}

test "human review formats rejected and changes requested outcomes without approval" {
    var parsed = try parseAppPolicy(std.testing.allocator, needs_review_policy_json);
    defer parsed.deinit();

    var rejected = try reviewInputFromPolicy(std.testing.allocator, rejectedHumanReviewOptions(), "app-policy.json", parsed.value);
    defer rejected.deinit(std.testing.allocator);
    var reports = try formatAppHumanReviewReports(std.testing.allocator, rejected);
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"review_status\": \"rejected\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"approved\": false") != null);
}
```

Use exact expected errors:

```zig
error.PolicyDoesNotNeedHumanReview
error.MissingMigrationCitation
error.MissingRunbookCitation
error.MissingRollbackCitation
error.PolicyAlreadyApplied
error.PolicyMutationAuthorityNotNone
```

- [ ] **Step 5: Run focused GREEN verification**

Run:

```sh
cd packages/zigeffect && zig build causal-app-human-review
cd packages/zigeffect && zig build test
```

Expected: both pass.

- [ ] **Step 6: Commit Task 1-2**

```sh
git add packages/zigeffect/build.zig packages/zigeffect/tools/causal_app_human_review.zig
git commit -m "feat(zigeffect): add app human review artifacts"
```

## Task 3: Extend App Patch Proposal With Review Evidence

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_patch_proposal.zig`

- [ ] **Step 1: Write RED tests**

Add tests:

```zig
test "app proposal rejects high-risk needs-review policy without review artifact" {
    var parsed = try parseAppPolicy(std.testing.allocator, needs_review_policy_json);
    defer parsed.deinit();

    try std.testing.expectError(error.HumanReviewRequired, proposalInputFromPolicy(std.testing.allocator, .{
        .mode = "local",
        .policy_path = "app-policy.json",
        .summary = "summary",
        .change = "change",
        .migration_files = &.{"packages/app/migrations/001.sql"},
    }, "app-policy.json", parsed.value, null));
}

test "app proposal accepts high-risk policy with approved human review" {
    var policy = try parseAppPolicy(std.testing.allocator, needs_review_policy_json);
    defer policy.deinit();
    var review = try parseAppHumanReview(std.testing.allocator, approved_human_review_json);
    defer review.deinit();

    var input = try proposalInputFromPolicy(std.testing.allocator, .{
        .mode = "local",
        .policy_path = "app-policy.json",
        .summary = "reviewed migration",
        .change = "draft reviewed migration plan",
    }, "app-policy.json", policy.value, review.value);
    defer input.deinit(std.testing.allocator);

    var reports = try formatAppPatchProposalReports(std.testing.allocator, input);
    defer reports.deinit(std.testing.allocator);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"human_review\": \"app-human-review.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"applied\": false") != null);
}

test "app proposal rejects rejected human review" {
    var policy = try parseAppPolicy(std.testing.allocator, needs_review_policy_json);
    defer policy.deinit();
    var review = try parseAppHumanReview(std.testing.allocator, rejected_human_review_json);
    defer review.deinit();

    try std.testing.expectError(error.HumanReviewNotApproved, proposalInputFromPolicy(std.testing.allocator, .{
        .mode = "local",
        .policy_path = "app-policy.json",
        .summary = "summary",
        .change = "change",
    }, "app-policy.json", policy.value, review.value));
}

test "app proposal rejects human review for a different policy path" {
    var policy = try parseAppPolicy(std.testing.allocator, needs_review_policy_json);
    defer policy.deinit();
    var review = try parseAppHumanReview(std.testing.allocator, mismatched_human_review_json);
    defer review.deinit();

    try std.testing.expectError(error.HumanReviewPolicyMismatch, proposalInputFromPolicy(std.testing.allocator, .{
        .mode = "local",
        .policy_path = "app-policy.json",
        .summary = "summary",
        .change = "change",
    }, "app-policy.json", policy.value, review.value));
}
```

The approved review fixture must use schema
`zigeffect.causal.app-human-review.v1` and include:

```zig
const needs_review_policy_json =
    \\{
    \\  "schema": "zigeffect.causal.app-policy-decision.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "yachdee-platform",
    \\  "decision": "needs-human-review",
    \\  "approval_status": "needs-human-review",
    \\  "mutation_authority": "none",
    \\  "applied": false,
    \\  "source": {"app_remediation_audit": "app-audit.json", "app_artifact": "app.json"},
    \\  "policy_gates": ["migration-required"],
    \\  "event_ids": [4],
    \\  "required_verification_commands": [],
    \\  "guardrails": []
    \\}
;

const approved_human_review_json =
    \\{
    \\  "schema": "zigeffect.causal.app-human-review.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "yachdee-platform",
    \\  "review_status": "approved",
    \\  "approval_status": "approved",
    \\  "approved": true,
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "source": {"policy": "app-policy.json", "app_remediation_audit": "app-audit.json", "app_artifact": "app.json"},
    \\  "policy_gates": ["migration-required"],
    \\  "citations": {"source_files": [], "config_keys": [], "migration_files": ["packages/app/migrations/001.sql"], "runbooks": [], "rollback_plans": []}
    \\}
;

const rejected_human_review_json =
    \\{
    \\  "schema": "zigeffect.causal.app-human-review.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "yachdee-platform",
    \\  "review_status": "rejected",
    \\  "approval_status": "rejected",
    \\  "approved": false,
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "source": {"policy": "app-policy.json", "app_remediation_audit": "app-audit.json", "app_artifact": "app.json"},
    \\  "policy_gates": ["migration-required"],
    \\  "citations": {"source_files": [], "config_keys": [], "migration_files": ["packages/app/migrations/001.sql"], "runbooks": [], "rollback_plans": []}
    \\}
;

const mismatched_human_review_json =
    \\{
    \\  "schema": "zigeffect.causal.app-human-review.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "yachdee-platform",
    \\  "review_status": "approved",
    \\  "approval_status": "approved",
    \\  "approved": true,
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "source": {"policy": "other-policy.json", "app_remediation_audit": "app-audit.json", "app_artifact": "app.json"},
    \\  "policy_gates": ["migration-required"],
    \\  "citations": {"source_files": [], "config_keys": [], "migration_files": ["packages/app/migrations/001.sql"], "runbooks": [], "rollback_plans": []}
    \\}
;
```

Run:

```sh
cd packages/zigeffect && zig build causal-app-patch-proposal
```

Expected: fails because `--review` and review validation are not implemented.

- [ ] **Step 2: Add review option parsing**

Extend `Options`:

```zig
review_path: ?[]const u8 = null,
```

Parse:

```zig
} else if (std.mem.eql(u8, arg, "--review")) {
    review_path = value;
}
```

Update usage:

```text
[--review <app-human-review-json>]
```

- [ ] **Step 3: Add review schema structs and parser**

Add:

```zig
const app_human_review_schema = "zigeffect.causal.app-human-review.v1";

const ReviewSource = struct {
    policy: []const u8,
    app_remediation_audit: []const u8,
    app_artifact: []const u8,
};

const ReviewCitations = struct {
    source_files: []const []const u8 = &.{},
    config_keys: []const []const u8 = &.{},
    migration_files: []const []const u8 = &.{},
    runbooks: []const []const u8 = &.{},
    rollback_plans: []const []const u8 = &.{},
};

const AppHumanReviewRecord = struct {
    schema: []const u8,
    schema_version: u32,
    mode: []const u8,
    target: []const u8,
    review_status: []const u8,
    approval_status: []const u8,
    approved: bool,
    applied: bool,
    mutation_authority: []const u8,
    source: ReviewSource,
    policy_gates: []const []const u8,
    citations: ReviewCitations,
};
```

Implement:

```zig
fn parseAppHumanReview(allocator: std.mem.Allocator, json: []const u8) !std.json.Parsed(AppHumanReviewRecord)
fn validateAppHumanReview(review: AppHumanReviewRecord) !void
```

- [ ] **Step 4: Update proposal input validation**

Change `proposalInputFromPolicy` to accept optional review:

```zig
fn proposalInputFromPolicy(
    allocator: std.mem.Allocator,
    options: Options,
    policy_path: []const u8,
    policy: AppPolicyRecord,
    review: ?AppHumanReviewRecord,
) !ProposalInput
```

Rules:

```zig
if (isHighRiskGate(gate)) {
    const approved_review = review orelse return error.HumanReviewRequired;
    try validateReviewMatchesPolicy(options, policy_path, policy, approved_review);
    try validateReviewCitationsForGate(gate, approved_review.citations);
}
```

Keep malformed `decision=approve` plus high-risk gates rejected:

```zig
if (std.mem.eql(u8, policy.decision, "approve") and isHighRiskGate(gate)) {
    return error.HighRiskGateRequiresHumanReview;
}
```

For needs-review policies, require:

```zig
policy.decision == "needs-human-review"
policy.approval_status == "needs-human-review"
review.review_status == "approved"
review.approval_status == "approved"
review.approved == true
review.applied == false
review.mutation_authority == "none"
review.source.policy == policy_path
review.target == policy.target
```

- [ ] **Step 5: Include review source in proposal output**

Extend `ProposalSource`:

```zig
human_review: ?[]const u8 = null,
```

When formatting JSON, include:

```json
"human_review": "app-human-review.json"
```

only when review evidence was used.

- [ ] **Step 6: Run focused GREEN verification**

Run:

```sh
cd packages/zigeffect && zig build causal-app-patch-proposal
cd packages/zigeffect && zig build test
```

Expected: both pass.

- [ ] **Step 7: Commit Task 3**

```sh
git add packages/zigeffect/tools/causal_app_patch_proposal.zig
git commit -m "feat(zigeffect): require human review for high-risk app proposals"
```

## Task 4: Register Human Review In Workbench Model

**Files:**
- Modify: `packages/zigeffect/workbench/src/causalArtifact.ts`
- Modify: `packages/zigeffect/workbench/src/causalArtifact.test.ts`
- Modify: `packages/zigeffect/workbench/src/workbenchBridge.ts`
- Modify: `packages/zigeffect/workbench/src/workbenchBridge.test.ts`
- Create: `packages/zigeffect/workbench/public/sample-app-human-review.json`

- [ ] **Step 1: Write RED workbench tests**

In `causalArtifact.test.ts`, add a `sampleAppReview` fixture and tests:

```ts
test("deriveGovernanceModel detects app human review artifacts", () => {
  const governance = deriveGovernanceModel(sampleAppReview, { artifactPath: "app-review.json" });

  expect(governance?.kind).toBe("app-human-review");
  expect(governance?.summary).toContain("approved app human review");
  expect(governance?.applied).toBe(false);
  expect(governance?.mutationAuthority).toBe("none");
});

test("deriveAppRemediationModel reads app human review citations and verification", () => {
  const app = deriveAppRemediationModel(sampleAppReview, { artifactPath: "app-review.json" });

  expect(app?.kind).toBe("app-human-review");
  expect(app?.approvalStatus).toBe("approved");
  expect(app?.approved).toBe(true);
  expect(app?.policyGates).toEqual(["migration-required", "rollback-required"]);
  expect(app?.citations.map((group) => `${group.label}:${group.values.length}`)).toContain("Migration files:1");
  expect(app?.verificationCommands).toContain("zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 4");
});
```

In `workbenchBridge.test.ts`, add:

```ts
["?sample=app-review", "sample-app-human-review.json"],
```

Run:

```sh
bun run zigeffect:workbench:test
```

Expected: fails because the schema and sample route are not recognized yet.

- [ ] **Step 2: Extend the app model**

Update `AppRemediationArtifactKind`:

```ts
| "app-human-review";
```

Update schema detection:

```ts
case "zigeffect.causal.app-human-review.v1":
  return "app-human-review";
```

Update `deriveAppRemediationModel` supported kinds and `appSummary`:

```ts
if (kind === "app-human-review") {
  return `${textValue(artifact.review_status, "unknown")} app human review for ${target}`;
}
```

Use `review_status` as the proposal/status posture when present:

```ts
proposalStatus: textValue(artifact.proposal_status, textValue(artifact.review_status, "unknown")),
approvalStatus: textValue(artifact.approval_status, "unknown"),
```

Include reviewed commands:

```ts
verificationCommands: uniqueInOrder([
  ...stringList(artifact.verification_commands),
  ...stringList(artifact.required_verification_commands),
  ...stringList(artifact.reviewed_verification_commands),
]),
```

Include review guardrails:

```ts
guardrails: uniqueInOrder([
  ...stringList(artifact.claim_guardrails),
  ...stringList(artifact.guardrails),
  ...stringList(artifact.proposal_guardrails),
  ...stringList(artifact.review_guardrails),
]),
```

Extend `appSourceSteps`:

```ts
: kind === "app-human-review"
  ? [["policy", "App policy decision"], ["app_remediation_audit", "App remediation audit"], ["app_artifact", "App artifact"]]
```

For app patch proposals, include optional human review:

```ts
["human_review", "App human review"]
```

- [ ] **Step 3: Add workbench sample route and fixture**

Update `sampleNameFromSearch`:

```ts
if (sample === "app-review") return "sample-app-human-review.json";
```

Create `sample-app-human-review.json` with the schema shape from the design
spec, using `migration-required` and `rollback-required` gates.

- [ ] **Step 4: Run GREEN workbench verification**

Run:

```sh
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
```

Expected: all pass.

- [ ] **Step 5: Commit Task 4**

```sh
git add packages/zigeffect/workbench/src/causalArtifact.ts packages/zigeffect/workbench/src/causalArtifact.test.ts packages/zigeffect/workbench/src/workbenchBridge.ts packages/zigeffect/workbench/src/workbenchBridge.test.ts packages/zigeffect/workbench/public/sample-app-human-review.json
git commit -m "feat(zigeffect): show app human review artifacts in workbench"
```

## Task 5: Documentation And Roadmap

**Files:**
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Update README command chain**

Add the human-review command after app policy decision and before app patch
proposal:

```bash
cd packages/zigeffect
zig build causal-app-human-review -- local --policy <app-policy-decision-json> --reviewer <actor> --decision approve --reason <reason> --migration <path> --runbook <path> --rollback <path>
```

State that the artifact uses schema `zigeffect.causal.app-human-review.v1` and
keeps `mutation_authority=none` and `applied=false`.

- [ ] **Step 2: Update agent runtime docs**

In `agent-observable-runtime.md`, document:

```text
app causal artifact -> app remediation audit -> app policy decision -> app human review when needed -> app patch proposal
```

Mention that approved human review allows draft proposal creation only.

- [ ] **Step 3: Update agent guide**

Add an agent instruction:

```text
When app policy returns needs-human-review, do not retry app patch proposal directly. Produce or request an app human-review artifact with migration/runbook/rollback citations, then pass it to causal-app-patch-proposal with --review.
```

- [ ] **Step 4: Update master roadmap**

Change M8 evidence to include app human-review boundary artifacts and move the
Immediate Branch Queue to:

```text
1. codex/zigeffect-app-application-readiness
2. codex/zigeffect-app-application-boundary
```

Keep M9 deferred.

- [ ] **Step 5: Run docs checks**

Run:

```sh
rg -n "app-human-review|causal-app-human-review|needs-human-review" packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git diff --check
```

Expected: the new command and schema are documented; no whitespace errors.

- [ ] **Step 6: Commit Task 5**

```sh
git add packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "docs(zigeffect): document app human review boundary"
```

## Task 6: Final Verification

**Files:**
- No new files unless verification exposes a defect.

- [ ] **Step 1: Run focused Zig gates**

```sh
cd packages/zigeffect && zig build causal-app-human-review
cd packages/zigeffect && zig build causal-app-patch-proposal
```

Expected: both pass.

- [ ] **Step 2: Run package Zig gates**

```sh
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build test
```

Expected: both pass.

- [ ] **Step 3: Run workbench gates**

```sh
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
```

Expected: all pass.

- [ ] **Step 4: Run repo gates**

```sh
bun run check
bun run zig:test
git diff --check
```

Expected: all pass.

- [ ] **Step 5: Confirm scoped status**

```sh
git status --short --branch
git log --oneline -6
```

Expected: branch is `codex/zigeffect-app-human-review-boundary`; only the
known unrelated untracked durable roadmap file may remain outside the commit
set.

## Self-Review

- Spec coverage: the plan covers CLI schema, validation, patch proposal
  integration, workbench recognition, docs, and verification.
- Placeholder scan: no `TBD`, `TODO`, or unspecified implementation steps are
  present.
- Type consistency: the schema name, CLI step, kind name, and sample route are
  consistently `app-human-review`, `causal-app-human-review`, and
  `?sample=app-review`.
- Safety consistency: no task permits `applied=true`, mutation authority,
  automatic source edits, migrations, deployments, or rollback actions.
