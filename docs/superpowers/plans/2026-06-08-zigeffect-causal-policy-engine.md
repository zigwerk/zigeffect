# zigeffect Causal Policy Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `zig build causal-policy-decision -- local [scenario]`, a deterministic policy-decision artifact generator for the zigeffect causal self-improvement loop.

**Architecture:** Add a single focused Zig tool that validates the existing causal remediation artifact chain, evaluates a named local policy catalog, and writes JSON/text policy-decision artifacts. The tool follows existing causal tool conventions: deterministic paths, schema/version validation, `applied=false`, `mutation_authority="none"`, module-local tests, build-step integration, and documentation/manifest updates.

**Tech Stack:** Zig stdlib, existing `packages/zigeffect/build.zig` tool modules, `std.json`, `std.ArrayList`, `bun` repo checks.

---

## File Map

- Create: `packages/zigeffect/tools/causal_policy_decision.zig`
  - CLI parsing, path derivation, source artifact structs, policy evaluator,
    JSON/text report formatting, IO, and module tests.
- Modify: `packages/zigeffect/build.zig`
  - Add tool module, module tests, executable, build step, and examples
    dependencies.
- Modify: `packages/zigeffect/tools/causal_artifacts.zig`
  - Add default and scenario policy-decision artifact paths plus tests.
- Modify: `packages/zigeffect/README.md`
  - Add command examples and explain advisory policy semantics.
- Modify: `packages/zigeffect/docs/agent-guide.md`
  - Add policy-decision step after audit-chain/registry application evidence.
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
  - Add artifact and workflow references.
- Modify: `packages/zigeffect/docs/roadmap.md`
  - Mark policy engine as delivered after implementation.
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Update current baseline, M1 ledger, and next active milestone.

## Implementation Constraints

- Do not mutate source files from the policy command.
- Always emit `applied=false`.
- Always emit `mutation_authority="none"`.
- Missing required artifacts fail the command.
- Missing optional artifacts are allowed and represented as `null`.
- Present optional artifacts with unsupported schemas fail validation.
- A policy outcome of `reject` or `needs-human-review` is a successful report,
  not a process failure.
- Use exact schema ids from the design doc.
- Keep the initial policy catalog code-first with one supported policy:
  `local-causal-self-improvement-v1`.
- Reject unknown policy names during CLI parsing.

---

### Task 1: CLI Options, Paths, And Build Test Wiring

**Files:**
- Create: `packages/zigeffect/tools/causal_policy_decision.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Write failing tests for option parsing and paths**

Add `packages/zigeffect/tools/causal_policy_decision.zig` with the test names
and assertions first. The file should initially contain only imports, schema
constants, test helpers, and tests that reference the intended functions.

```zig
const std = @import("std");
const causal_run = @import("causal_run");

const policy_schema = "zigeffect.causal.policy-decision.v1";
const default_policy_name = "local-causal-self-improvement-v1";

test "policy decision parses default and scenario local invocations" {
    const default_args = [_][]const u8{
        "zigeffect-causal-policy-decision",
        "local",
        "--by",
        "local-agent",
    };
    const default_options = try parseOptions(default_args[0..]);
    try std.testing.expectEqualStrings("local", default_options.mode);
    try std.testing.expect(default_options.scenario_slug == null);
    try std.testing.expectEqualStrings(default_policy_name, default_options.policy);
    try std.testing.expectEqualStrings("local-agent", default_options.evaluated_by);

    const scenario_args = [_][]const u8{
        "zigeffect-causal-policy-decision",
        "local",
        "causal-scoped-fiber",
        "--policy",
        default_policy_name,
    };
    const scenario_options = try parseOptions(scenario_args[0..]);
    try std.testing.expectEqualStrings("causal-scoped-fiber", scenario_options.scenario_slug.?);
    try std.testing.expectEqualStrings(default_policy_name, scenario_options.policy);
}

test "policy decision rejects unknown local policy" {
    const args = [_][]const u8{
        "zigeffect-causal-policy-decision",
        "local",
        "--policy",
        "experimental-remote-policy",
    };
    try std.testing.expectError(error.UnknownPolicy, parseOptions(args[0..]));
}

test "policy decision output paths are stable for default and scenario targets" {
    const default_paths = policyDecisionPathsForOptions(
        std.testing.allocator,
        .{ .mode = "local", .scenario_slug = null },
    ) catch unreachable;
    defer default_paths.deinit(std.testing.allocator, .{ .mode = "local", .scenario_slug = null });

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-policy-decision.json",
        default_paths.output_json,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-policy-decision.txt",
        default_paths.output_text,
    );

    const scenario_options = Options{ .mode = "local", .scenario_slug = "causal-scoped-fiber" };
    const scenario_paths = try policyDecisionPathsForOptions(std.testing.allocator, scenario_options);
    defer scenario_paths.deinit(std.testing.allocator, scenario_options);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-policy-decision.json",
        scenario_paths.output_json,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-policy-decision.txt",
        scenario_paths.output_text,
    );
}
```

- [ ] **Step 2: Wire module tests into `build.zig` before implementing**

Add a module and test artifact after `causal_registry_apply_tool_tests`:

```zig
const causal_policy_decision_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_policy_decision.zig"),
    .target = target,
    .optimize = optimize,
});
causal_policy_decision_tool_module.addImport("causal_run", causal_run_tool_module);

const causal_policy_decision_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-policy-decision-tests",
    .root_module = causal_policy_decision_tool_module,
});
const run_causal_policy_decision_tool_tests = b.addRunArtifact(causal_policy_decision_tool_tests);
```

Add the test dependency to the existing test step near the other causal tool
tests:

```zig
test_step.dependOn(&run_causal_policy_decision_tool_tests.step);
```

- [ ] **Step 3: Run RED**

Run:

```sh
zig build test --summary none
```

Expected: fail because `Options`, `parseOptions`, and
`policyDecisionPathsForOptions` are not implemented yet.

- [ ] **Step 4: Implement minimal options and path derivation**

Add these definitions to `causal_policy_decision.zig`:

```zig
const Options = struct {
    mode: []const u8,
    scenario_slug: ?[]const u8 = null,
    evaluated_by: []const u8 = "local-policy-engine",
    policy: []const u8 = default_policy_name,
};

const PolicyDecisionPaths = struct {
    audit_json: []const u8,
    decision_json: []const u8,
    proposal_json: []const u8,
    audit_chain_json: []const u8,
    scenario_proposal_json: []const u8,
    registry_patch_json: []const u8,
    registry_readiness_json: []const u8,
    registry_application_json: []const u8,
    output_json: []const u8,
    output_text: []const u8,

    fn deinit(self: PolicyDecisionPaths, allocator: std.mem.Allocator, options: Options) void {
        if (options.scenario_slug == null) return;
        allocator.free(self.audit_json);
        allocator.free(self.decision_json);
        allocator.free(self.proposal_json);
        allocator.free(self.audit_chain_json);
        allocator.free(self.scenario_proposal_json);
        allocator.free(self.registry_patch_json);
        allocator.free(self.registry_readiness_json);
        allocator.free(self.registry_application_json);
        allocator.free(self.output_json);
        allocator.free(self.output_text);
    }
};

fn parseOptions(args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingMode;
    if (!std.mem.eql(u8, args[1], "local")) return error.UnknownMode;

    var scenario_slug: ?[]const u8 = null;
    var evaluated_by: []const u8 = "local-policy-engine";
    var policy: []const u8 = default_policy_name;

    var index: usize = 2;
    while (index < args.len) {
        const arg = args[index];
        if (std.mem.startsWith(u8, arg, "--")) {
            if (index + 1 >= args.len) return error.MissingFlagValue;
            const value = args[index + 1];
            if (std.mem.eql(u8, arg, "--by")) {
                evaluated_by = value;
            } else if (std.mem.eql(u8, arg, "--policy")) {
                if (!std.mem.eql(u8, value, default_policy_name)) return error.UnknownPolicy;
                policy = value;
            } else {
                return error.UnknownFlag;
            }
            index += 2;
        } else {
            if (scenario_slug != null) return error.DuplicateScenarioArgument;
            _ = try causal_run.scenarioByName(arg);
            scenario_slug = arg;
            index += 1;
        }
    }

    return .{
        .mode = "local",
        .scenario_slug = scenario_slug,
        .evaluated_by = evaluated_by,
        .policy = policy,
    };
}
```

For paths, mirror the existing dev-loop conventions exactly. Implement a
`defaultPolicyDecisionPaths()` that returns string literals and a
`scenarioPolicyDecisionPaths()` that allocates all fields.

- [ ] **Step 5: Run GREEN**

Run:

```sh
zig build test --summary none
```

Expected: pass for the new option/path tests and existing tests.

- [ ] **Step 6: Commit Task 1**

```sh
git add packages/zigeffect/tools/causal_policy_decision.zig packages/zigeffect/build.zig
git commit -m "feat(zigeffect): add policy decision option parsing"
```

---

### Task 2: Policy Source Validation And Evaluation

**Files:**
- Modify: `packages/zigeffect/tools/causal_policy_decision.zig`

- [ ] **Step 1: Write failing tests for policy outcomes**

Add sample JSON constants for:

- remediation audit pending/unapplied;
- approved remediation decision;
- rejected remediation decision;
- patch proposal pointing to the audit;
- audit chain matching target;
- blocked registry readiness;
- malformed optional registry application schema.

Add tests:

```zig
test "policy evaluator requires human review without manual decision" {
    const input = PolicyInput{
        .options = .{ .mode = "local" },
        .paths = defaultPolicyDecisionPaths(),
        .audit_json = sample_audit_json,
        .decision_json = null,
        .proposal_json = sample_patch_proposal_json,
        .audit_chain_json = sample_audit_chain_json,
        .scenario_proposal_json = null,
        .registry_patch_json = null,
        .registry_readiness_json = null,
        .registry_application_json = null,
    };
    var result = try evaluatePolicy(std.testing.allocator, input);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(PolicyDecision.needs_human_review, result.decision);
    try expectStringInSlice("manual-decision-missing", result.reason_codes);
    try std.testing.expectEqualStrings("none", result.mutation_authority);
    try std.testing.expect(!result.applied);
}

test "policy evaluator approves approved manual decision with matching evidence" {
    const input = PolicyInput{
        .options = .{ .mode = "local" },
        .paths = defaultPolicyDecisionPaths(),
        .audit_json = sample_audit_json,
        .decision_json = sample_approved_decision_json,
        .proposal_json = sample_patch_proposal_with_decision_json,
        .audit_chain_json = sample_audit_chain_json,
        .scenario_proposal_json = null,
        .registry_patch_json = null,
        .registry_readiness_json = null,
        .registry_application_json = null,
    };
    var result = try evaluatePolicy(std.testing.allocator, input);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(PolicyDecision.approve, result.decision);
    try expectStringInSlice("manual-decision-approved", result.reason_codes);
}

test "policy evaluator rejects rejected manual decision" {
    const input = PolicyInput{
        .options = .{ .mode = "local" },
        .paths = defaultPolicyDecisionPaths(),
        .audit_json = sample_audit_json,
        .decision_json = sample_rejected_decision_json,
        .proposal_json = sample_patch_proposal_json,
        .audit_chain_json = sample_audit_chain_json,
        .scenario_proposal_json = null,
        .registry_patch_json = null,
        .registry_readiness_json = null,
        .registry_application_json = null,
    };
    var result = try evaluatePolicy(std.testing.allocator, input);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(PolicyDecision.reject, result.decision);
    try expectStringInSlice("manual-decision-rejected", result.reason_codes);
}

test "policy evaluator rejects target mismatch" {
    const input = PolicyInput{
        .options = .{ .mode = "local" },
        .paths = defaultPolicyDecisionPaths(),
        .audit_json = sample_audit_json,
        .decision_json = sample_approved_decision_json,
        .proposal_json = sample_patch_proposal_wrong_target_json,
        .audit_chain_json = sample_audit_chain_json,
        .scenario_proposal_json = null,
        .registry_patch_json = null,
        .registry_readiness_json = null,
        .registry_application_json = null,
    };
    var result = try evaluatePolicy(std.testing.allocator, input);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(PolicyDecision.reject, result.decision);
    try expectStringInSlice("target-mismatch", result.reason_codes);
}

test "policy evaluator sends blocked registry readiness to human review" {
    const input = PolicyInput{
        .options = .{ .mode = "local" },
        .paths = defaultPolicyDecisionPaths(),
        .audit_json = sample_audit_json,
        .decision_json = sample_approved_decision_json,
        .proposal_json = sample_patch_proposal_with_decision_json,
        .audit_chain_json = sample_audit_chain_json,
        .scenario_proposal_json = null,
        .registry_patch_json = sample_registry_patch_json,
        .registry_readiness_json = sample_blocked_readiness_json,
        .registry_application_json = null,
    };
    var result = try evaluatePolicy(std.testing.allocator, input);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(PolicyDecision.needs_human_review, result.decision);
    try expectStringInSlice("registry-readiness-blocked", result.reason_codes);
}

test "policy evaluator rejects unsupported optional artifact schema" {
    const input = PolicyInput{
        .options = .{ .mode = "local" },
        .paths = defaultPolicyDecisionPaths(),
        .audit_json = sample_audit_json,
        .decision_json = null,
        .proposal_json = sample_patch_proposal_json,
        .audit_chain_json = sample_audit_chain_json,
        .scenario_proposal_json = null,
        .registry_patch_json = null,
        .registry_readiness_json = null,
        .registry_application_json = sample_wrong_schema_json,
    };
    try std.testing.expectError(error.UnsupportedApplicationSchema, evaluatePolicy(std.testing.allocator, input));
}
```

- [ ] **Step 2: Run RED**

Run:

```sh
zig build test --summary none
```

Expected: fail because policy structs, samples, helpers, and evaluator are not
implemented.

- [ ] **Step 3: Implement source structs and validation helpers**

Add exact record structs for the fields needed by the evaluator:

- `AuditRecord`
- `DecisionRecord`
- `ProposalRecord`
- `AuditChainRecord`
- `ScenarioProposalRecord`
- `RegistryPatchRecord`
- `ReadinessReport`
- `ApplicationReport`

Each validator checks schema id, `schema_version == 1`, target/source
consistency, and review-only `applied` constraints.

Use helper signatures:

```zig
fn validateAudit(audit: AuditRecord) !void
fn validateDecision(decision: DecisionRecord) !void
fn validateProposal(proposal: ProposalRecord) !void
fn validateAuditChain(chain: AuditChainRecord) !void
fn validateOptionalScenarioProposal(proposal: ScenarioProposalRecord) !void
fn validateOptionalRegistryPatch(patch: RegistryPatchRecord) !void
fn validateOptionalReadiness(report: ReadinessReport) !void
fn validateOptionalApplication(report: ApplicationReport) !void
```

- [ ] **Step 4: Implement deterministic evaluator**

Add:

```zig
const PolicyDecision = enum {
    approve,
    reject,
    needs_human_review,
};

const RuleStatus = enum {
    pass,
    fail,
    skipped,
};

const PolicyRuleResult = struct {
    id: []const u8,
    status: RuleStatus,
    detail: []const u8,
};

const PolicyResult = struct {
    decision: PolicyDecision,
    reason: []const u8,
    reason_codes: []const []const u8,
    mutation_authority: []const u8,
    applied: bool,
    target: []const u8,
    event_ids: []const u64,
    required_verification_commands: []const []const u8,
    rules: []const PolicyRuleResult,

    fn deinit(self: PolicyResult, allocator: std.mem.Allocator) void {
        allocator.free(self.rules);
    }
};
```

Fold rules in this order:

1. Validate required schemas.
2. Validate target match across audit, proposal, and audit chain.
3. Validate optional decision.
4. Validate optional registry artifacts.
5. Append `mutation-authority-none`.
6. Choose decision:
   - reject on target mismatch, rejected decision, applied review artifact, or
     hard invalid source condition;
   - needs-human-review on missing manual decision or blocked downstream
     readiness/application;
   - approve on approved manual decision with clean required evidence.

Reason strings must be stable:

- `manual approval is required before policy can recommend approval`
- `manual decision approved the remediation evidence`
- `manual decision rejected the remediation evidence`
- `source artifact targets do not match`
- `registry readiness or application evidence is blocked`

- [ ] **Step 5: Run GREEN**

Run:

```sh
zig build test --summary none
```

Expected: pass for policy evaluation tests.

- [ ] **Step 6: Commit Task 2**

```sh
git add packages/zigeffect/tools/causal_policy_decision.zig
git commit -m "feat(zigeffect): evaluate causal policy decisions"
```

---

### Task 3: JSON And Text Report Formatting

**Files:**
- Modify: `packages/zigeffect/tools/causal_policy_decision.zig`

- [ ] **Step 1: Write failing formatter tests**

Add tests:

```zig
test "policy decision JSON records advisory approval without mutation authority" {
    const input = sampleApprovedPolicyInput();
    var reports = try formatPolicyDecisionReports(std.testing.allocator, input);
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"schema\": \"zigeffect.causal.policy-decision.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"decision\": \"approve\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"mutation_authority\": \"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"manual-decision-approved\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"mutation-authority-none\"") != null);
}

test "policy decision text records source paths and guardrails" {
    const input = sampleHumanReviewPolicyInput();
    var reports = try formatPolicyDecisionReports(std.testing.allocator, input);
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.text, "zigeffect causal policy decision") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "decision: needs-human-review") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "mutation_authority: none") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "source artifacts:") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "Policy approval is advisory and does not apply source changes.") != null);
}
```

- [ ] **Step 2: Run RED**

Run:

```sh
zig build test --summary none
```

Expected: fail because report formatting functions are not implemented.

- [ ] **Step 3: Implement report formatting**

Add:

```zig
const PolicyDecisionReports = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: PolicyDecisionReports, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
    }
};

fn formatPolicyDecisionReports(allocator: std.mem.Allocator, input: PolicyInput) !PolicyDecisionReports
fn formatPolicyDecisionJson(allocator: std.mem.Allocator, input: PolicyInput, result: PolicyResult) ![]const u8
fn formatPolicyDecisionText(allocator: std.mem.Allocator, input: PolicyInput, result: PolicyResult) ![]const u8
```

Reuse local JSON helper functions from neighboring tools:

- `appendJsonString`
- `appendNullableJsonString`
- `appendStringArray`
- `appendU64Array`

The JSON must include:

- schema and schema version;
- mode, target, decision, approval status;
- evaluated_by and policy;
- reason and reason_codes;
- mutation_authority and applied;
- source artifact object;
- event_ids;
- required_verification_commands;
- rules;
- guardrails.

The text report must include the same information as a short human-readable
summary.

- [ ] **Step 4: Run GREEN**

Run:

```sh
zig build test --summary none
```

Expected: formatter tests pass.

- [ ] **Step 5: Commit Task 3**

```sh
git add packages/zigeffect/tools/causal_policy_decision.zig
git commit -m "feat(zigeffect): format causal policy decision reports"
```

---

### Task 4: CLI IO, Build Step, And Local Integration

**Files:**
- Modify: `packages/zigeffect/tools/causal_policy_decision.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Write failing IO/build tests**

In the Zig tool, add path/usage tests:

```zig
test "policy decision usage names local command shape" {
    try std.testing.expectEqualStrings(
        "usage: zig build causal-policy-decision -- local [scenario] [--policy <policy>] [--by <actor>]\\n",
        usage(),
    );
}
```

- [ ] **Step 2: Run RED**

Run:

```sh
zig build test --summary none
```

Expected: fail until `usage` and CLI support exist.

- [ ] **Step 3: Implement IO and `main`**

Add:

```zig
const Init = struct {
    allocator: std.mem.Allocator,
    io: std.fs.Dir,
};

fn usage() []const u8 {
    return "usage: zig build causal-policy-decision -- local [scenario] [--policy <policy>] [--by <actor>]\\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-policy-decision error: {s}\\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}
```

Implement:

- `readRequiredArtifact`
- `readOptionalArtifact`
- `writeArtifact`
- `runLocalPolicyDecision`
- `pub fn main() !void`

`runLocalPolicyDecision` reads required and optional artifacts from
`PolicyDecisionPaths`, formats reports, and writes `output_json` and
`output_text`.

- [ ] **Step 4: Add executable build step**

In `build.zig`, add after `causal_registry_apply_tool`:

```zig
const causal_policy_decision_tool = b.addExecutable(.{
    .name = "zigeffect-causal-policy-decision",
    .root_module = causal_policy_decision_tool_module,
});
const run_causal_policy_decision_tool = b.addRunArtifact(causal_policy_decision_tool);
if (b.args) |args| run_causal_policy_decision_tool.addArgs(args);
const causal_policy_decision_step = b.step("causal-policy-decision", "Write a deterministic causal policy decision report");
causal_policy_decision_step.dependOn(&run_causal_policy_decision_tool.step);
```

Add to `examples_step`:

```zig
examples_step.dependOn(&causal_policy_decision_tool.step);
examples_step.dependOn(&run_causal_policy_decision_tool_tests.step);
```

- [ ] **Step 5: Run GREEN**

Run:

```sh
zig build test --summary none
zig build examples
```

Expected: both pass.

- [ ] **Step 6: Run local integration chain**

Use an existing scenario to create source artifacts, then run the new policy
decision:

```sh
zig build causal-dev-loop -- baseline causal-scoped-fiber
zig build causal-dev-loop -- after causal-scoped-fiber
zig build causal-dev-session -- start causal-scoped-fiber
zig build causal-dev-session -- assess causal-scoped-fiber
zig build causal-diagnosis -- local causal-scoped-fiber
zig build causal-remediation-plan -- local causal-scoped-fiber
zig build causal-remediation-audit -- local causal-scoped-fiber
zig build causal-remediation-decision -- local approve causal-scoped-fiber --policy manual-review --reason "reviewed causal policy engine integration"
zig build causal-patch-proposal -- local approved causal-scoped-fiber --summary "policy engine integration evidence" --file "packages/zigeffect/tools/causal_policy_decision.zig" --change "records advisory policy decisions"
zig build causal-audit-chain -- local causal-scoped-fiber
zig build causal-policy-decision -- local causal-scoped-fiber
```

Expected output files:

- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-policy-decision.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-policy-decision.txt`

Expected text includes:

- `decision: approve`
- `mutation_authority: none`
- `applied: false`

- [ ] **Step 7: Commit Task 4**

```sh
git add packages/zigeffect/tools/causal_policy_decision.zig packages/zigeffect/build.zig
git commit -m "feat(zigeffect): write causal policy decision artifacts"
```

---

### Task 5: Artifact Manifest And Documentation

**Files:**
- Modify: `packages/zigeffect/tools/causal_artifacts.zig`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Write failing manifest tests**

In `causal_artifacts.zig`, extend existing tests to expect:

```zig
try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-policy-decision.json") != null);
try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-policy-decision.txt") != null);
try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-policy-decision.json") != null);
try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-policy-decision.txt") != null);
```

- [ ] **Step 2: Run RED**

Run:

```sh
zig build test --summary none
```

Expected: fail because manifest entries are not printed yet.

- [ ] **Step 3: Add manifest entries**

Add default manifest lines near the registry application artifacts:

```zig
try output.print(allocator, "- dev-loop policy decision json {s}/zigeffect-causal-dev-loop-policy-decision.json\\n", .{causal_run.artifact_dir});
try output.print(allocator, "- dev-loop policy decision text {s}/zigeffect-causal-dev-loop-policy-decision.txt\\n", .{causal_run.artifact_dir});
```

Add scenario manifest lines near the scenario registry application artifacts:

```zig
try output.print(allocator, "  loop policy decision json: {s}/zigeffect-causal-dev-loop-{s}-policy-decision.json\\n", .{ causal_run.artifact_dir, slug });
try output.print(allocator, "  loop policy decision text: {s}/zigeffect-causal-dev-loop-{s}-policy-decision.txt\\n", .{ causal_run.artifact_dir, slug });
```

- [ ] **Step 4: Update docs**

Document:

- command usage;
- schema id;
- advisory-only policy semantics;
- default policy name;
- source artifacts consumed;
- output artifact paths;
- relationship to registry readiness/application reports.

Use exact command examples:

```sh
zig build causal-policy-decision -- local
zig build causal-policy-decision -- local causal-scoped-fiber
```

- [ ] **Step 5: Run GREEN**

Run:

```sh
zig build causal-artifacts
zig build test --summary none
```

Expected: manifest includes policy-decision paths and all tests pass.

- [ ] **Step 6: Commit Task 5**

```sh
git add docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/causal-scenarios.md packages/zigeffect/docs/roadmap.md packages/zigeffect/tools/causal_artifacts.zig
git commit -m "docs(zigeffect): document causal policy decisions"
```

---

### Task 6: Final Verification And Merge

**Files:**
- Verify repository state only.

- [ ] **Step 1: Check branch state**

Run:

```sh
git status --short --branch
git log --oneline master..HEAD
```

Expected: only intended commits on `codex/zigeffect-causal-policy-engine`;
unrelated untracked files remain unstaged.

- [ ] **Step 2: Run full verification**

Run from repo root unless a command states otherwise:

```sh
git diff --check HEAD
```

Run from `packages/zigeffect`:

```sh
zig build causal-policy-decision -- local causal-scoped-fiber
zig build examples
zig build test --summary none
```

Run from repo root:

```sh
bun run check
bun run zig:test
```

Expected:

- whitespace check exits 0;
- policy command writes JSON/text artifacts;
- Zig examples/tests exit 0;
- Bun check reports all tests passing;
- Bun Zig test chain exits 0.

- [ ] **Step 3: Merge locally after verification**

If verification passes, merge into `master`:

```sh
git switch master
git merge --ff-only codex/zigeffect-causal-policy-engine
```

- [ ] **Step 4: Verify merged result**

Run the same verification commands from Step 2 against `master`.

- [ ] **Step 5: Delete merged branch**

```sh
git branch -d codex/zigeffect-causal-policy-engine
```

- [ ] **Step 6: Start M2 branch**

Create the next sequential branch:

```sh
git switch -c codex/zigeffect-causal-test-matrix
```

Do not implement M2 until its focused design and implementation plan are
written and committed.
