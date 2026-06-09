# zigeffect App Application Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the guarded app application boundary that can record `applied=true` only after ready app-readiness evidence, real change evidence, before/after evidence, and post-application verification are recorded.

**Architecture:** Add a record-only Zig CLI, `causal-app-apply`, that mirrors `causal-registry-apply` while validating app-specific evidence categories. Extend the existing SolidJS workbench model and Chain tab to render `zigeffect.causal.app-application.v1` artifacts through the existing `zig-webui` host. Keep the command non-mutating and leave durable/NenDB work for its own milestone.

**Tech Stack:** Zig 0.16 build modules and tests, Bun test, SolidJS, Vite, `webui-dev/zig-webui`, Markdown docs.

---

## File Structure

- Create: `packages/zigeffect/tools/causal_app_apply.zig`
  - Owns CLI parsing, readiness validation, application evaluation, JSON/text formatting, output paths, and Zig tests for app application artifacts.
- Modify: `packages/zigeffect/build.zig`
  - Adds the app apply module, executable, build step, and test dependency.
- Modify: `packages/zigeffect/workbench/src/causalArtifact.ts`
  - Adds `app-application` kind, fields for application status and evidence, source-step mapping, summary text, and schema detection.
- Modify: `packages/zigeffect/workbench/src/causalArtifact.test.ts`
  - Adds RED tests for governance and app remediation derivation of app application artifacts.
- Modify: `packages/zigeffect/workbench/src/workbenchBridge.ts`
  - Adds `?sample=app-application`.
- Modify: `packages/zigeffect/workbench/src/workbenchBridge.test.ts`
  - Adds sample query coverage.
- Modify: `packages/zigeffect/workbench/src/App.tsx`
  - Renders app application evidence and before/after evidence in the existing Chain tab.
- Modify: `packages/zigeffect/workbench/src/styles.css`
  - Adds compact grid/list styling if current classes are insufficient.
- Create: `packages/zigeffect/workbench/public/sample-app-application.json`
  - Provides an applied app application fixture for workbench development and browser QA.
- Modify: `packages/zigeffect/README.md`
  - Documents the new command and schema.
- Modify: `packages/zigeffect/docs/agent-guide.md`
  - Adds agent workflow guidance for app readiness to application.
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
  - Adds the boundary to the observable runtime narrative.
- Modify: `packages/zigeffect/docs/roadmap.md`
  - Marks the app application boundary as delivered once implementation passes.
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Updates M8 status and immediate queue.

---

### Task 1: Add Zig RED Tests And Build Wiring

**Files:**
- Create: `packages/zigeffect/tools/causal_app_apply.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add the test-only Zig file**

Create `packages/zigeffect/tools/causal_app_apply.zig` with tests that describe the final API before implementation exists:

```zig
const std = @import("std");

test "app apply usage names guarded app application command" {
    try std.testing.expect(std.mem.indexOf(u8, usage(), "causal-app-apply") != null);
    try std.testing.expectEqualStrings("zigeffect.causal.app-application.v1", app_application_schema);
}

test "app apply output paths derive from readiness path" {
    const paths = try applicationPathsFromReadiness(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/yachdee-platform-app-application-readiness.json",
    );
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/yachdee-platform-app-application.json",
        paths.json,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/yachdee-platform-app-application.txt",
        paths.text,
    );
}

test "app apply plan creates planned report for ready readiness" {
    const options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-app-apply",
        "--from-readiness",
        ".zig-cache/causal-artifacts/yachdee-platform-app-application-readiness.json",
        "plan",
        "--reason",
        "plan reviewed app application",
    });
    defer options.deinit(std.testing.allocator);

    const result = try evaluateApplication(std.testing.allocator, .{
        .source_readiness_path = options.readiness_path,
        .readiness_json = readyReadinessJson(),
        .mode = options.mode,
        .applied_by = options.applied_by,
        .policy = options.policy,
        .reason = options.reason,
        .verified_commands = options.verified_commands,
        .change_evidence = options.change_evidence,
        .before_evidence = options.before_evidence,
        .after_evidence = options.after_evidence,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(ApplicationStatus.planned, result.status);
    try std.testing.expect(!result.applied);
    try std.testing.expect(checkPassed(result.checks, "readiness-ready"));
    try std.testing.expect(checkSkipped(result.checks, "change-evidence-present"));
}

test "app apply blocks blocked readiness" {
    const result = try evaluateApplication(std.testing.allocator, .{
        .source_readiness_path = ".zig-cache/causal-artifacts/yachdee-platform-app-application-readiness.json",
        .readiness_json = blockedReadinessJson(),
        .mode = .record_applied,
        .applied_by = "local-reviewer",
        .policy = "manual-app-application",
        .reason = "attempted blocked application",
        .verified_commands = &.{},
        .change_evidence = emptyChangeEvidence(),
        .before_evidence = &.{},
        .after_evidence = &.{},
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(ApplicationStatus.blocked, result.status);
    try std.testing.expect(!result.applied);
    try std.testing.expect(checkFailed(result.checks, "readiness-ready"));
}

test "app apply record-applied requires change and before after evidence" {
    const result = try evaluateApplication(std.testing.allocator, .{
        .source_readiness_path = ".zig-cache/causal-artifacts/yachdee-platform-app-application-readiness.json",
        .readiness_json = readyReadinessJson(),
        .mode = .record_applied,
        .applied_by = "local-reviewer",
        .policy = "manual-app-application",
        .reason = "missing application evidence",
        .verified_commands = &.{"zig build causal-query -- --file app.json cause 2"},
        .change_evidence = emptyChangeEvidence(),
        .before_evidence = &.{},
        .after_evidence = &.{},
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(ApplicationStatus.blocked, result.status);
    try std.testing.expect(!result.applied);
    try std.testing.expect(checkFailed(result.checks, "change-evidence-present"));
    try std.testing.expect(checkFailed(result.checks, "before-after-evidence-present"));
}

test "app apply record-applied emits applied true with complete low risk evidence" {
    const options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-app-apply",
        "--from-readiness",
        ".zig-cache/causal-artifacts/yachdee-platform-app-application-readiness.json",
        "record-applied",
        "--reason",
        "source and config change landed",
        "--verified-command",
        "zig build causal-query -- --file app.json cause 2",
        "--source-change",
        "apps/platform/src/worker.ts",
        "--config-change",
        "YACHDEE_API_BASE_URL",
        "--before",
        ".zig-cache/causal-artifacts/yachdee-platform-before-app.json",
        "--after",
        ".zig-cache/causal-artifacts/yachdee-platform-after-app.json",
    });
    defer options.deinit(std.testing.allocator);

    const reports = try formatApplicationReports(std.testing.allocator, .{
        .source_readiness_path = options.readiness_path,
        .readiness_json = readyReadinessJson(),
        .mode = options.mode,
        .applied_by = options.applied_by,
        .policy = options.policy,
        .reason = options.reason,
        .verified_commands = options.verified_commands,
        .change_evidence = options.change_evidence,
        .before_evidence = options.before_evidence,
        .after_evidence = options.after_evidence,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"application_status\": \"applied\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"applied\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"mutation_authority\": \"record-only\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"source_changes\": [\"apps/platform/src/worker.ts\"]") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"before_evidence\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "application_status: applied") != null);
}

test "app apply high risk gates require matching evidence categories" {
    const result = try evaluateApplication(std.testing.allocator, .{
        .source_readiness_path = ".zig-cache/causal-artifacts/yachdee-platform-app-application-readiness.json",
        .readiness_json = highRiskReadinessJson(),
        .mode = .record_applied,
        .applied_by = "local-reviewer",
        .policy = "manual-app-application",
        .reason = "missing rollback evidence",
        .verified_commands = &.{"zig build causal-query -- --file app.json cause 4"},
        .change_evidence = .{
            .source_changes = &.{},
            .config_changes = &.{},
            .migration_changes = &.{"packages/app/migrations/001.sql"},
            .operation_changes = &.{"docs/runbooks/migration.md"},
            .rollback_changes = &.{},
        },
        .before_evidence = &.{".zig-cache/causal-artifacts/before.json"},
        .after_evidence = &.{".zig-cache/causal-artifacts/after.json"},
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(ApplicationStatus.blocked, result.status);
    try std.testing.expect(checkFailed(result.checks, "change-evidence-present"));
}
```

- [ ] **Step 2: Add build wiring so the RED tests can run**

In `packages/zigeffect/build.zig`, after `causal_app_application_readiness_tool_module`, add:

```zig
    const causal_app_apply_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_app_apply.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_app_apply_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-app-apply-tests",
        .root_module = causal_app_apply_tool_module,
    });
    const run_causal_app_apply_tool_tests = b.addRunArtifact(causal_app_apply_tool_tests);
```

After the app application readiness executable step, add:

```zig
    const causal_app_apply_tool = b.addExecutable(.{
        .name = "zigeffect-causal-app-apply",
        .root_module = causal_app_apply_tool_module,
    });
    const run_causal_app_apply_tool = b.addRunArtifact(causal_app_apply_tool);
    if (b.args) |args| run_causal_app_apply_tool.addArgs(args);
    const causal_app_apply_step = b.step("causal-app-apply", "Record guarded app application evidence from app readiness");
    causal_app_apply_step.dependOn(&run_causal_app_apply_tool.step);
```

In the test dependency block near the other tool tests, add:

```zig
    test_step.dependOn(&run_causal_app_apply_tool_tests.step);
```

- [ ] **Step 3: Run the RED Zig test**

Run:

```sh
cd packages/zigeffect
zig build test
```

Expected: FAIL. The failure should be compile-time missing identifiers such as `usage`, `app_application_schema`, `ApplicationStatus`, `parseOptions`, or `evaluateApplication`.

- [ ] **Step 4: Commit the RED test checkpoint**

Do not commit this RED checkpoint separately unless the team wants compile-failing commits. Keep it unstaged until Task 2 makes it green.

---

### Task 2: Implement The Zig App Application Tool

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_apply.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add constants, enums, and options**

Implement these declarations above the tests in `causal_app_apply.zig`:

```zig
const app_application_readiness_schema = "zigeffect.causal.app-application-readiness.v1";
const app_application_schema = "zigeffect.causal.app-application.v1";
const readiness_suffix = "-app-application-readiness.json";
const application_suffix = "-app-application";

const Mode = enum { plan, record_applied };
const ApplicationStatus = enum { planned, applied, blocked };
const CheckStatus = enum { pass, fail, skipped };

const ChangeEvidence = struct {
    source_changes: []const []const u8 = &.{},
    config_changes: []const []const u8 = &.{},
    migration_changes: []const []const u8 = &.{},
    operation_changes: []const []const u8 = &.{},
    rollback_changes: []const []const u8 = &.{},

    fn deinit(self: ChangeEvidence, allocator: std.mem.Allocator) void {
        freeStringSlice(allocator, self.source_changes);
        freeStringSlice(allocator, self.config_changes);
        freeStringSlice(allocator, self.migration_changes);
        freeStringSlice(allocator, self.operation_changes);
        freeStringSlice(allocator, self.rollback_changes);
    }
};

const Options = struct {
    readiness_path: []const u8,
    mode: Mode,
    applied_by: []const u8 = "local-reviewer",
    policy: []const u8 = "manual-app-application",
    reason: []const u8,
    verified_commands: []const []const u8 = &.{},
    change_evidence: ChangeEvidence = .{},
    before_evidence: []const []const u8 = &.{},
    after_evidence: []const []const u8 = &.{},

    fn deinit(self: Options, allocator: std.mem.Allocator) void {
        freeStringSlice(allocator, self.verified_commands);
        self.change_evidence.deinit(allocator);
        freeStringSlice(allocator, self.before_evidence);
        freeStringSlice(allocator, self.after_evidence);
    }
};
```

- [ ] **Step 2: Add readiness and result structs**

Add structs that parse readiness with `.ignore_unknown_fields = true`:

```zig
const ReadinessSource = struct {
    proposal: []const u8 = "",
    policy: []const u8 = "",
    human_review: ?[]const u8 = null,
    app_remediation_audit: []const u8 = "",
    app_artifact: []const u8 = "",
};

const ReadinessCitations = struct {
    source_files: []const []const u8 = &.{},
    config_keys: []const []const u8 = &.{},
    migration_files: []const []const u8 = &.{},
    runbooks: []const []const u8 = &.{},
    rollback_plans: []const []const u8 = &.{},
};

const ReadinessCheck = struct {
    name: []const u8,
    status: []const u8,
    detail: []const u8,
};

const ReadinessReport = struct {
    schema: []const u8,
    schema_version: u32,
    mode: []const u8,
    source_proposal: []const u8,
    decision: []const u8,
    readiness_status: []const u8,
    ready_for_application: bool,
    reviewed_by: []const u8,
    policy: []const u8,
    reason: []const u8,
    applied: bool,
    mutation_authority: []const u8,
    target: []const u8,
    summary: []const u8,
    change: []const u8,
    source: ReadinessSource,
    policy_gates: []const []const u8 = &.{},
    citations: ReadinessCitations = .{},
    event_ids: []const u64 = &.{},
    checks: []const ReadinessCheck = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
    application_steps: []const []const u8 = &.{},
    readiness_guardrails: []const []const u8 = &.{},
};

const ApplicationCheck = struct {
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
};

const ApplicationResult = struct {
    status: ApplicationStatus,
    applied: bool,
    mutation_authority: []const u8,
    checks: []const ApplicationCheck,
    required_verification_commands: []const []const u8,

    fn deinit(self: ApplicationResult, allocator: std.mem.Allocator) void {
        if (self.checks.len > 0) allocator.free(self.checks);
        freeStringSlice(allocator, self.required_verification_commands);
    }
};
```

- [ ] **Step 3: Implement parsing and validation**

Implement `usage`, `parseOptions`, `applicationPathsFromReadiness`, and `validateReadiness`.

Command parsing must accept these exact flags:

```text
--from-readiness
--by
--policy
--reason
--verified-command
--source-change
--config-change
--migration-change
--operation-change
--rollback-change
--before
--after
```

Validation must reject:

```zig
if (!std.mem.eql(u8, report.schema, app_application_readiness_schema)) return error.UnsupportedReadinessSchema;
if (report.schema_version != 1) return error.UnsupportedReadinessSchema;
if (!std.mem.eql(u8, report.mode, "local")) return error.UnsupportedReadinessSchema;
if (report.target.len == 0) return error.MissingTarget;
if (report.summary.len == 0) return error.MissingSummary;
if (report.change.len == 0) return error.MissingChange;
if (report.reason.len == 0) return error.MissingReadinessReason;
if (report.applied) return error.ReadinessAlreadyApplied;
if (!std.mem.eql(u8, report.mutation_authority, "none")) return error.ReadinessMutationAuthorityNotNone;
if (!std.mem.endsWith(u8, report.source_proposal, "-app-patch-proposal.json")) return error.InvalidProposalPath;
if (!std.mem.eql(u8, report.readiness_status, "ready") and !std.mem.eql(u8, report.readiness_status, "blocked")) return error.UnknownReadinessStatus;
if (report.ready_for_application != std.mem.eql(u8, report.readiness_status, "ready")) return error.InconsistentReadinessStatus;
```

- [ ] **Step 4: Implement evaluation helpers**

Implement:

```zig
fn evaluateApplication(allocator: std.mem.Allocator, input: ApplicationInput) !ApplicationResult
fn changeEvidenceSatisfiesGates(gates: []const []const u8, evidence: ChangeEvidence) bool
fn requiredCommandsSatisfied(verified_commands: []const []const u8, required_commands: []const []const u8) bool
fn allChecksPassed(checks: []const ApplicationCheck) bool
fn checkPassed(checks: []const ApplicationCheck, name: []const u8) bool
fn checkFailed(checks: []const ApplicationCheck, name: []const u8) bool
fn checkSkipped(checks: []const ApplicationCheck, name: []const u8) bool
```

Evaluation rules:

```zig
// Always pass after successful parse and validation.
appendCheck("readiness-schema", .pass, "app application readiness schema is supported");

// Pass only when readiness_status=ready and ready_for_application=true.
appendCheck("readiness-ready", readinessReady ? .pass : .fail, "readiness is ready for app application");

// Pass only when decision=approve.
appendCheck("decision-approved", approved ? .pass : .fail, "readiness decision approved application");

// In plan mode, append evidence checks as skipped and return planned when the first three checks pass.
// In record-applied mode, append evidence checks as pass/fail and return applied only when every check passes.
```

- [ ] **Step 5: Implement JSON/text formatters and CLI main**

Implement:

```zig
fn formatApplicationReports(allocator: std.mem.Allocator, input: ApplicationInput) !ApplicationReports
fn formatApplicationJson(allocator: std.mem.Allocator, input: ApplicationInput, readiness: ReadinessReport, result: ApplicationResult) ![]const u8
fn formatApplicationText(allocator: std.mem.Allocator, input: ApplicationInput, readiness: ReadinessReport, result: ApplicationResult) ![]const u8
pub fn main() !void
```

The JSON formatter must include:

```text
schema
schema_version
source_readiness
source_proposal
mode
application_status
applied
mutation_authority
applied_by
policy
reason
readiness_status
ready_for_application
target
summary
change
source
policy_gates
citations
event_ids
checks
required_verification_commands
verified_commands
change_evidence
before_evidence
after_evidence
application_steps
guardrails
```

Use the existing helper style from `causal_app_application_readiness.zig` for `appendJsonString`, `appendStringArray`, `appendU64Array`, and text list formatting.

- [ ] **Step 6: Run GREEN Zig tests**

Run:

```sh
cd packages/zigeffect
zig build test
```

Expected: PASS.

- [ ] **Step 7: Run examples for integration coverage**

Run:

```sh
cd packages/zigeffect
zig build examples
```

Expected: PASS.

---

### Task 3: Add Workbench RED Tests

**Files:**
- Modify: `packages/zigeffect/workbench/src/causalArtifact.test.ts`
- Modify: `packages/zigeffect/workbench/src/workbenchBridge.test.ts`

- [ ] **Step 1: Add an app application fixture**

In `causalArtifact.test.ts`, after `sampleAppReadiness`, add:

```ts
const sampleAppApplication = {
  schema: "zigeffect.causal.app-application.v1",
  schema_version: 1,
  source_readiness: ".zig-cache/causal-artifacts/yachdee-platform-app-application-readiness.json",
  source_proposal: ".zig-cache/causal-artifacts/yachdee-platform-app-patch-proposal.json",
  mode: "record-applied",
  application_status: "applied",
  applied: true,
  mutation_authority: "record-only",
  applied_by: "local-reviewer",
  policy: "manual-app-application",
  reason: "source and config change landed",
  readiness_status: "ready",
  ready_for_application: true,
  target: "yachdee-platform",
  summary: "Wire HealthService and document config binding",
  change: "Add provider layer and document YACHDEE_ENV.",
  source: {
    readiness: ".zig-cache/causal-artifacts/yachdee-platform-app-application-readiness.json",
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
  checks: [
    { name: "readiness-ready", status: "pass", detail: "readiness is ready for app application" },
    { name: "change-evidence-present", status: "pass", detail: "caller recorded evidence for every policy-gate change category" },
  ],
  required_verification_commands: ["zig build causal-query -- --file app.json cause 2"],
  verified_commands: ["zig build causal-query -- --file app.json cause 2"],
  change_evidence: {
    source_changes: ["apps/platform/src/worker.ts"],
    config_changes: ["YACHDEE_API_BASE_URL"],
    migration_changes: [],
    operation_changes: [],
    rollback_changes: [],
  },
  before_evidence: [".zig-cache/causal-artifacts/yachdee-platform-before-app.json"],
  after_evidence: [".zig-cache/causal-artifacts/yachdee-platform-after-app.json"],
  application_steps: ["Keep this application artifact with the reviewed change evidence."],
  guardrails: ["This command records application state; it does not silently mutate source or external systems."],
};
```

- [ ] **Step 2: Add governance and model tests**

Add these tests after the app readiness tests:

```ts
test("deriveGovernanceModel detects app application artifacts", () => {
  const governance = deriveGovernanceModel(sampleAppApplication, { artifactPath: "app-application.json" });

  expect(governance?.kind).toBe("app-application");
  expect(governance?.summary).toContain("applied app application");
  expect(governance?.applied).toBe(true);
  expect(governance?.mutationAuthority).toBe("record-only");
});

test("deriveAppRemediationModel reads app application evidence", () => {
  const app = deriveAppRemediationModel(sampleAppApplication, { artifactPath: "app-application.json" });

  expect(app?.kind).toBe("app-application");
  expect(app?.applicationStatus).toBe("applied");
  expect(app?.readinessStatus).toBe("ready");
  expect(app?.readyForApplication).toBe(true);
  expect(app?.changeEvidence.map((group) => `${group.label}:${group.values.length}`)).toEqual([
    "Source changes:1",
    "Config changes:1",
    "Migration changes:0",
    "Operation changes:0",
    "Rollback changes:0",
  ]);
  expect(app?.beforeEvidence).toEqual([".zig-cache/causal-artifacts/yachdee-platform-before-app.json"]);
  expect(app?.afterEvidence).toEqual([".zig-cache/causal-artifacts/yachdee-platform-after-app.json"]);
  expect(app?.sourceSteps.map((step) => step.label)).toEqual([
    "App application readiness",
    "App patch proposal",
    "App policy decision",
    "App human review",
    "App remediation audit",
    "App artifact",
  ]);
});
```

- [ ] **Step 3: Add bridge sample test**

In `workbenchBridge.test.ts`, extend the sample table with:

```ts
["?sample=app-application", "sample-app-application.json"],
```

- [ ] **Step 4: Run RED workbench tests**

Run:

```sh
bun run zigeffect:workbench:test
```

Expected: FAIL. The failures should report unknown `app-application` kind, missing `applicationStatus`, missing evidence fields, or missing sample mapping.

---

### Task 4: Implement Workbench Model, UI, And Sample

**Files:**
- Modify: `packages/zigeffect/workbench/src/causalArtifact.ts`
- Modify: `packages/zigeffect/workbench/src/workbenchBridge.ts`
- Modify: `packages/zigeffect/workbench/src/App.tsx`
- Modify: `packages/zigeffect/workbench/src/styles.css`
- Create: `packages/zigeffect/workbench/public/sample-app-application.json`

- [ ] **Step 1: Extend workbench types and schema detection**

In `causalArtifact.ts`:

```ts
export type GovernanceArtifactKind =
  | "audit-chain"
  | "remediation-audit"
  | "app-remediation-audit"
  | "app-policy-decision"
  | "app-human-review"
  | "app-patch-proposal"
  | "app-application-readiness"
  | "app-application"
  | "remediation-decision"
  | "patch-proposal"
  | "registry-readiness"
  | "registry-application"
  | "policy-decision";

export type AppRemediationArtifactKind =
  | "app-remediation-audit"
  | "app-policy-decision"
  | "app-human-review"
  | "app-patch-proposal"
  | "app-application-readiness"
  | "app-application";
```

Add fields to `AppRemediationModel`:

```ts
applicationStatus: string;
changeEvidence: AppCitationGroup[];
beforeEvidence: string[];
afterEvidence: string[];
```

In `governanceKindForSchema`, add:

```ts
case "zigeffect.causal.app-application.v1":
  return "app-application";
```

- [ ] **Step 2: Extend app model derivation**

In `deriveAppRemediationModel`, include `kind !== "app-application"` in the allowed-kind check and set:

```ts
applicationStatus: textValue(artifact.application_status, "unknown"),
changeEvidence: appChangeEvidenceGroups(artifact.change_evidence),
beforeEvidence: stringList(artifact.before_evidence),
afterEvidence: stringList(artifact.after_evidence),
```

Add helper:

```ts
function appChangeEvidenceGroups(value: unknown): AppCitationGroup[] {
  const evidence = isRecord(value) ? value : {};
  return [
    { label: "Source changes", values: stringList(evidence.source_changes) },
    { label: "Config changes", values: stringList(evidence.config_changes) },
    { label: "Migration changes", values: stringList(evidence.migration_changes) },
    { label: "Operation changes", values: stringList(evidence.operation_changes) },
    { label: "Rollback changes", values: stringList(evidence.rollback_changes) },
  ];
}
```

Update `appSummary`:

```ts
if (kind === "app-application") {
  return `${textValue(artifact.application_status, "unknown")} app application for ${target}`;
}
```

Update `appSourceSteps` for `app-application`:

```ts
: kind === "app-application"
  ? [["readiness", "App application readiness"], ["proposal", "App patch proposal"], ["policy", "App policy decision"], ["human_review", "App human review"], ["app_remediation_audit", "App remediation audit"], ["app_artifact", "App artifact"]]
```

- [ ] **Step 3: Add sample mapping**

In `workbenchBridge.ts`, add:

```ts
if (sample === "app-application") return "sample-app-application.json";
```

- [ ] **Step 4: Add UI sections**

In `App.tsx`, update `AppRemediationStatus`:

```tsx
const posture = props.app.kind === "app-application"
  ? props.app.applicationStatus
  : props.app.kind === "app-application-readiness"
    ? props.app.readinessStatus
    : props.app.kind === "app-patch-proposal"
      ? props.app.proposalStatus
      : props.app.decision;
```

In `AppRemediationView`, after the citations/verification grid, add:

```tsx
<Show when={props.app.kind === "app-application"}>
  <div class="app-remediation-grid">
    <AppEvidenceGroups title="Change evidence" groups={props.app.changeEvidence} />
    <AppBeforeAfterEvidence before={props.app.beforeEvidence} after={props.app.afterEvidence} />
  </div>
</Show>
```

Add components:

```tsx
function AppEvidenceGroups(props: { title: string; groups: AppCitationGroup[] }) {
  return (
    <section class="chain-panel">
      <h3>{props.title}</h3>
      <div class="citation-grid">
        <For each={props.groups} fallback={<EmptyState label="No evidence groups" compact />}>
          {(group) => (
            <div class="citation-group">
              <span>{group.label}</span>
              <For each={group.values} fallback={<small>none</small>}>
                {(value) => <code>{value}</code>}
              </For>
            </div>
          )}
        </For>
      </div>
    </section>
  );
}

function AppBeforeAfterEvidence(props: { before: string[]; after: string[] }) {
  return (
    <section class="chain-panel">
      <h3>Before and after</h3>
      <div class="citation-grid">
        <div class="citation-group">
          <span>Before</span>
          <For each={props.before} fallback={<small>none</small>}>
            {(value) => <code>{value}</code>}
          </For>
        </div>
        <div class="citation-group">
          <span>After</span>
          <For each={props.after} fallback={<small>none</small>}>
            {(value) => <code>{value}</code>}
          </For>
        </div>
      </div>
    </section>
  );
}
```

- [ ] **Step 5: Add public sample**

Create `packages/zigeffect/workbench/public/sample-app-application.json` using the same shape as `sampleAppApplication` from Task 3, formatted as valid JSON.

- [ ] **Step 6: Run GREEN workbench tests**

Run:

```sh
bun run zigeffect:workbench:test
```

Expected: PASS.

- [ ] **Step 7: Run workbench typecheck and build**

Run:

```sh
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
```

Expected: both PASS.

---

### Task 5: Update Documentation And Roadmap

**Files:**
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Update README command docs**

Add a short section after app application readiness:

~~~md
Record guarded app application after readiness:

```sh
zig build causal-app-apply -- --from-readiness <app-application-readiness-json> plan --reason <reason>
zig build causal-app-apply -- --from-readiness <app-application-readiness-json> record-applied --reason <reason> --verified-command <command> --source-change <path> --before <evidence> --after <evidence>
```

`causal-app-apply` writes `zigeffect.causal.app-application.v1` artifacts as
`*-app-application.json` and `*-app-application.txt`. Plan mode keeps
`applied=false`. Record-applied mode writes `applied=true` only when readiness
is ready, the decision is approved, required change evidence exists,
before/after evidence exists, and required post-application verification is
recorded.
~~~

- [ ] **Step 2: Update agent guide workflow**

Add guidance that agents must:

```md
1. Treat app readiness as permission to attempt application, not proof of application.
2. Apply source/config/migration/operation/rollback changes outside `causal-app-apply`.
3. Capture before and after app evidence.
4. Run required post-application verification.
5. Use `causal-app-apply record-applied` only after every evidence category is recorded.
```

- [ ] **Step 3: Update observable runtime narrative**

Add `zigeffect.causal.app-application.v1` to the M8 app governance chain and state that it is record-only.

- [ ] **Step 4: Update roadmap**

In `packages/zigeffect/docs/roadmap.md`, replace the future app application boundary note with delivered status:

```md
- Delivered: `zig build causal-app-apply -- --from-readiness <app-application-readiness-json> plan|record-applied`
  records `zigeffect.causal.app-application.v1` evidence. `applied=true`
  is possible only in `record-applied` mode after ready readiness,
  category-specific change evidence, before/after evidence, and post-apply
  verification evidence are present.
```

- [ ] **Step 5: Update master roadmap**

In `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`:

```md
| M8 App remediation gates | delivered | app remediation audit artifacts, app policy gate decisions, app human-review boundary artifacts, draft app patch proposal artifacts, app application readiness artifacts, guarded app application records, and SolidJS/zig-webui workbench rendering exist | move to M9 production operating model |
```

Set immediate queue to:

```text
codex/zigeffect-causal-schema-governance
codex/zigeffect-causal-operations-docs
```

- [ ] **Step 6: Run docs whitespace check**

Run:

```sh
git diff --check
```

Expected: PASS.

---

### Task 6: Full Verification, Browser QA, And Commit

**Files:**
- All files changed in Tasks 1 through 5.

- [ ] **Step 1: Run Zig verification**

Run:

```sh
cd packages/zigeffect
zig build examples
zig build test
```

Expected: both PASS.

- [ ] **Step 2: Run workbench verification**

Run:

```sh
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
```

Expected: all PASS.

- [ ] **Step 3: Run workspace verification**

Run from repo root:

```sh
bun run check
bun run zig:test
git diff --check
```

Expected: all PASS.

- [ ] **Step 4: Run browser QA**

Start the local workbench:

```sh
bun run zigeffect:workbench:dev -- --host 127.0.0.1
```

Open:

```text
http://127.0.0.1:5173/?sample=app-application
```

Verify at desktop `1440x1000`:

```text
Chain tab renders app-application.
Posture is applied.
Applied is true.
Authority is record-only.
Source artifacts include app application readiness.
Change evidence shows source and config groups.
Before and after evidence are visible.
Checks, verification, application steps, and guardrails are visible.
No obvious text overlap.
```

Verify at mobile `390x900`:

```text
Chain tab remains usable.
Evidence sections stack vertically.
Long paths wrap inside panels.
No horizontal overflow is reported by the browser check.
```

Stop the dev server before finishing the turn.

- [ ] **Step 5: Inspect git status**

Run:

```sh
git status --short
```

Expected: only intended files are modified or added, plus the pre-existing unrelated untracked durable roadmap file.

- [ ] **Step 6: Commit implementation**

Stage only intended files:

```sh
git add packages/zigeffect/tools/causal_app_apply.zig \
  packages/zigeffect/build.zig \
  packages/zigeffect/workbench/src/causalArtifact.ts \
  packages/zigeffect/workbench/src/causalArtifact.test.ts \
  packages/zigeffect/workbench/src/workbenchBridge.ts \
  packages/zigeffect/workbench/src/workbenchBridge.test.ts \
  packages/zigeffect/workbench/src/App.tsx \
  packages/zigeffect/workbench/src/styles.css \
  packages/zigeffect/workbench/public/sample-app-application.json \
  packages/zigeffect/README.md \
  packages/zigeffect/docs/agent-guide.md \
  packages/zigeffect/docs/agent-observable-runtime.md \
  packages/zigeffect/docs/roadmap.md \
  docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
```

Commit:

```sh
git commit -m "feat(zigeffect): add guarded app application records"
```

Expected: commit succeeds and the unrelated durable roadmap file remains untracked.
