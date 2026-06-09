# zigeffect App Policy Gates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an advisory app policy decision artifact that evaluates app remediation audits against the five M8 app policy gates.

**Architecture:** Create a sibling Zig tool, `causal-app-policy-decision`, that reads `zigeffect.causal.app-remediation-audit.v1`, validates pending/unapplied/no-mutation posture, evaluates known app gates, and writes deterministic JSON/text reports with `mutation_authority=none` and `applied=false`. Add minimal SolidJS workbench governance recognition for `zigeffect.causal.app-policy-decision.v1`.

**Tech Stack:** Zig tools and `zig build`, existing app remediation audit JSON shape, Bun/SolidJS workbench tests.

---

## File Structure

- Create `packages/zigeffect/tools/causal_app_policy_decision.zig`
  - Owns CLI parsing, app audit parsing, gate evaluation, JSON/text rendering,
    artifact reads/writes, and unit tests.
- Modify `packages/zigeffect/build.zig`
  - Adds the tool module, test runner, executable build step, and examples-step
    dependencies.
- Modify `packages/zigeffect/workbench/src/causalArtifact.ts`
  - Adds `app-policy-decision` governance schema detection and summary text.
- Modify `packages/zigeffect/workbench/src/causalArtifact.test.ts`
  - Adds a focused app policy governance recognition test.
- Modify docs:
  - `packages/zigeffect/README.md`
  - `packages/zigeffect/docs/agent-guide.md`
  - `packages/zigeffect/docs/agent-observable-runtime.md`
  - `packages/zigeffect/docs/roadmap.md`
  - `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

## Task 1: Add App Policy Tool Tests

**Files:**
- Create: `packages/zigeffect/tools/causal_app_policy_decision.zig`

- [ ] **Step 1: Write the initial failing test skeleton**

Create `packages/zigeffect/tools/causal_app_policy_decision.zig` with tests for
usage, path derivation, approval, human review, rejection, JSON, and text:

```zig
const std = @import("std");

const app_policy_schema = "zigeffect.causal.app-policy-decision.v1";
const default_policy_name = "local-app-remediation-policy-v1";

const source_config_audit_json =
    \\{
    \\  "schema": "zigeffect.causal.app-remediation-audit.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "yachdee-platform",
    \\  "proposer": "local-agent",
    \\  "source": {
    \\    "app_artifact": ".zig-cache/causal-artifacts/app.json",
    \\    "advice": "inline-generated"
    \\  },
    \\  "approval_status": "pending",
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "incident_count": 2,
    \\  "incidents": [
    \\    {"action":"fix-app-config","event_id":2,"event_kind":"assertion_recorded","label":"YACHDEE_ENV","subsystem":"app_config","fix_category":"config-or-secret-binding","policy_gate":"config-only","query_commands":["zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 2"]},
    \\    {"action":"wire-app-requirement","event_id":3,"event_kind":"assertion_recorded","label":"HealthService","subsystem":"app_service_layer","fix_category":"service-provider-or-layer","policy_gate":"source-only","query_commands":["zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 3"]}
    \\  ],
    \\  "policy_gates": ["config-only", "source-only"],
    \\  "verification_commands": ["zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 2"],
    \\  "claim_guardrails": ["Do not claim an app fix without rerunning the app request/job scenario."]
    \\}
;

test "usage text names app policy audit flag" {
    try std.testing.expectEqualStrings(
        "usage: zig build causal-app-policy-decision -- local --audit <app-remediation-audit-json> [--policy <policy>] [--by <actor>] [--out-prefix <path-prefix>]\n",
        usage(),
    );
}

test "output paths derive from audit path and out prefix" {
    const defaults = try outputPathsForOptions(std.testing.allocator, .{
        .mode = "local",
        .audit_path = ".zig-cache/causal-artifacts/app-app-remediation-audit.json",
    });
    defer defaults.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/app-app-remediation-audit-app-policy-decision.json",
        defaults.json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/app-app-remediation-audit-app-policy-decision.txt",
        defaults.text_path,
    );

    const custom = try outputPathsForOptions(std.testing.allocator, .{
        .mode = "local",
        .audit_path = ".zig-cache/causal-artifacts/app-app-remediation-audit.json",
        .out_prefix = ".zig-cache/causal-artifacts/yachdee-platform",
    });
    defer custom.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/yachdee-platform-app-policy-decision.json",
        custom.json_path,
    );
}

test "source and config gates approve proposal drafting without mutation authority" {
    var parsed = try parseAppAudit(std.testing.allocator, source_config_audit_json);
    defer parsed.deinit();

    var result = try evaluateAppPolicy(std.testing.allocator, .{
        .options = .{ .mode = "local", .audit_path = "app-audit.json" },
        .audit_path = "app-audit.json",
        .audit = parsed.value,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(AppPolicyDecision.approve, result.decision);
    try std.testing.expectEqualStrings("none", result.mutation_authority);
    try std.testing.expect(!result.applied);
    try expectGateStatus(result.gate_results, "config-only", GateStatus.allow_proposal);
    try expectGateStatus(result.gate_results, "source-only", GateStatus.allow_proposal);
}

test "high risk gates require human review" {
    var parsed = try parseAppAudit(std.testing.allocator, migration_audit_json);
    defer parsed.deinit();

    var result = try evaluateAppPolicy(std.testing.allocator, .{
        .options = .{ .mode = "local", .audit_path = "app-audit.json" },
        .audit_path = "app-audit.json",
        .audit = parsed.value,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(AppPolicyDecision.needs_human_review, result.decision);
    try expectGateStatus(result.gate_results, "migration-required", GateStatus.human_review_required);
}

test "unknown gates reject the app policy decision" {
    var parsed = try parseAppAudit(std.testing.allocator, unknown_gate_audit_json);
    defer parsed.deinit();

    var result = try evaluateAppPolicy(std.testing.allocator, .{
        .options = .{ .mode = "local", .audit_path = "app-audit.json" },
        .audit_path = "app-audit.json",
        .audit = parsed.value,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(AppPolicyDecision.reject, result.decision);
    try expectGateStatus(result.gate_results, "database-maybe", GateStatus.blocked);
}

test "applied audits reject policy evaluation" {
    var parsed = try parseAppAudit(std.testing.allocator, applied_audit_json);
    defer parsed.deinit();

    var result = try evaluateAppPolicy(std.testing.allocator, .{
        .options = .{ .mode = "local", .audit_path = "app-audit.json" },
        .audit_path = "app-audit.json",
        .audit = parsed.value,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(AppPolicyDecision.reject, result.decision);
    try expectReasonCode(result.reason_codes, "app-audit-not-pending");
}
```

- [ ] **Step 2: Run missing build step red**

Run:

```sh
cd packages/zigeffect && zig build causal-app-policy-decision
```

Expected: fail with `no step named 'causal-app-policy-decision'`.

## Task 2: Wire The Tool Into Zig Build

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/tools/causal_app_policy_decision.zig`

- [ ] **Step 1: Add build module, tests, and executable**

Add near the other app/remediation tools:

```zig
const causal_app_policy_decision_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_app_policy_decision.zig"),
    .target = target,
    .optimize = optimize,
});

const causal_app_policy_decision_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-app-policy-decision-tests",
    .root_module = causal_app_policy_decision_tool_module,
});
const run_causal_app_policy_decision_tool_tests = b.addRunArtifact(causal_app_policy_decision_tool_tests);

const causal_app_policy_decision_tool = b.addExecutable(.{
    .name = "zigeffect-causal-app-policy-decision",
    .root_module = causal_app_policy_decision_tool_module,
});
const run_causal_app_policy_decision_tool = b.addRunArtifact(causal_app_policy_decision_tool);
if (b.args) |args| run_causal_app_policy_decision_tool.addArgs(args);
const causal_app_policy_decision_step = b.step("causal-app-policy-decision", "Evaluate app remediation audit policy gates");
causal_app_policy_decision_step.dependOn(&run_causal_app_policy_decision_tool.step);

examples_step.dependOn(&causal_app_policy_decision_tool.step);
examples_step.dependOn(&run_causal_app_policy_decision_tool_tests.step);
```

- [ ] **Step 2: Run compile red**

Run:

```sh
cd packages/zigeffect && zig build causal-app-policy-decision
```

Expected: compile failure naming missing functions/types from the test skeleton.

## Task 3: Implement The App Policy Evaluator

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_policy_decision.zig`

- [ ] **Step 1: Add data types**

Add `Options`, `OutputPaths`, `AuditSource`, `AuditIncident`,
`AppAuditRecord`, `AppPolicyDecision`, `GateStatus`, `GateResult`,
`AppPolicyInput`, `AppPolicyResult`, and `AppPolicyReports`.

`AppPolicyDecision` values:

```zig
const AppPolicyDecision = enum { approve, reject, needs_human_review };
```

`GateStatus` values:

```zig
const GateStatus = enum { allow_proposal, human_review_required, blocked };
```

- [ ] **Step 2: Add parsing and validation**

Implement:

```zig
fn usage() []const u8
fn parseOptions(args: []const []const u8) !Options
fn outputPathsForOptions(allocator: std.mem.Allocator, options: Options) !OutputPaths
fn parseAppAudit(allocator: std.mem.Allocator, json: []const u8) !std.json.Parsed(AppAuditRecord)
fn validateAppAudit(audit: AppAuditRecord) !void
```

Validation returns errors for unsupported schema/version/mode. Pending/applied
state is policy evidence, so it is evaluated into a reject result instead of a
parse error.

- [ ] **Step 3: Add gate evaluation**

Implement:

```zig
fn evaluateAppPolicy(allocator: std.mem.Allocator, input: AppPolicyInput) !AppPolicyResult
fn evaluateGate(gate: []const u8) GateResult
fn collectUniqueGates(allocator: std.mem.Allocator, audit: AppAuditRecord) ![]const []const u8
fn decisionText(decision: AppPolicyDecision) []const u8
fn gateStatusText(status: GateStatus) []const u8
```

Rules:

- `source-only` and `config-only` return `allow_proposal`.
- `migration-required`, `operational-human-required`, and `rollback-required`
  return `human_review_required`.
- unknown gates return `blocked`.
- any blocked gate or applied/non-pending/non-none audit rejects.
- any high-risk human-review gate returns `needs_human_review`.
- otherwise return `approve`.

- [ ] **Step 4: Add JSON/text formatting and CLI**

Implement:

```zig
fn formatAppPolicyDecisionReports(allocator: std.mem.Allocator, input: AppPolicyInput) !AppPolicyReports
fn formatAppPolicyDecisionJson(allocator: std.mem.Allocator, input: AppPolicyInput, result: AppPolicyResult) ![]const u8
fn formatAppPolicyDecisionText(allocator: std.mem.Allocator, input: AppPolicyInput, result: AppPolicyResult) ![]const u8
pub fn main(init: std.process.Init) !void
```

The CLI reads the audit with a 1 MiB ceiling, writes the output paths, and
prints the text report. Missing audit files use `MissingAppPolicyInput`.

- [ ] **Step 5: Verify green**

Run:

```sh
cd packages/zigeffect && zig fmt tools/causal_app_policy_decision.zig build.zig
cd packages/zigeffect && zig build examples
```

Expected: pass. `zig build causal-app-policy-decision` with no args remains an
argument-gated command and should print `MissingMode`.

## Task 4: Add Workbench Governance Recognition

**Files:**
- Modify: `packages/zigeffect/workbench/src/causalArtifact.ts`
- Modify: `packages/zigeffect/workbench/src/causalArtifact.test.ts`

- [ ] **Step 1: Write failing workbench test**

Add:

```ts
test("deriveGovernanceModel detects app policy decision artifacts", () => {
  const governance = deriveGovernanceModel({
    schema: "zigeffect.causal.app-policy-decision.v1",
    schema_version: 1,
    target: "yachdee-platform",
    decision: "needs-human-review",
    applied: false,
    mutation_authority: "none",
  }, { artifactPath: "app-policy.json" });

  expect(governance?.kind).toBe("app-policy-decision");
  expect(governance?.summary).toContain("needs-human-review app policy decision");
  expect(governance?.applied).toBe(false);
  expect(governance?.mutationAuthority).toBe("none");
});
```

- [ ] **Step 2: Verify red**

Run:

```sh
bun run zigeffect:workbench:test
```

Expected: fail because the schema is not recognized.

- [ ] **Step 3: Implement recognition**

Add `app-policy-decision` to `GovernanceArtifactKind`, add
`zigeffect.causal.app-policy-decision.v1` to `governanceKindForSchema`, and set
the summary to `${decision} app policy decision for ${target}`.

- [ ] **Step 4: Verify green**

Run:

```sh
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
```

Expected: both pass.

## Task 5: Update Documentation And Roadmaps

**Files:**
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Document command usage**

Document:

```sh
zig build causal-app-policy-decision -- local --audit <app-remediation-audit-json>
```

Mention schema `zigeffect.causal.app-policy-decision.v1`, gate outcomes, and
that the policy remains advisory with `mutation_authority=none` and
`applied=false`.

- [ ] **Step 2: Update master roadmap**

Move M8 evidence from "app remediation audit artifacts exist" to "app
remediation audit and app policy gate artifacts exist; app patch proposals
remain next".

- [ ] **Step 3: Verify docs**

Run:

```sh
rg -n "causal-app-policy-decision|app-policy-decision|app policy" packages/zigeffect/README.md packages/zigeffect/docs docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git diff --check
```

Expected: command/schema are findable and whitespace is clean.

## Task 6: Full Verification And Commit

**Files:**
- All files touched in this branch.

- [ ] **Step 1: Full verification**

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

Expected: all pass.

- [ ] **Step 2: Commit**

Stage only intended files:

```sh
git add \
  docs/superpowers/plans/2026-06-09-zigeffect-app-policy-gates.md \
  docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md \
  packages/zigeffect/README.md \
  packages/zigeffect/build.zig \
  packages/zigeffect/docs/agent-guide.md \
  packages/zigeffect/docs/agent-observable-runtime.md \
  packages/zigeffect/docs/roadmap.md \
  packages/zigeffect/tools/causal_app_policy_decision.zig \
  packages/zigeffect/workbench/src/causalArtifact.test.ts \
  packages/zigeffect/workbench/src/causalArtifact.ts
git commit -m "feat(zigeffect): add app policy gate decisions"
```

Do not stage unrelated untracked files.

## Self-Review

- Spec coverage: the plan covers command shape, schema, all five gates,
  non-mutating posture, workbench recognition, docs, and verification.
- Placeholder scan: no `TBD`, `TODO`, "implement later", or unspecified tests
  are used as work items.
- Type consistency: the plan consistently uses
  `zigeffect.causal.app-policy-decision.v1`, `causal-app-policy-decision`,
  `AppPolicyDecision`, `GateStatus`, `mutation_authority=none`, and
  `applied=false`.
