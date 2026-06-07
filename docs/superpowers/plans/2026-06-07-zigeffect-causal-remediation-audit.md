# zigeffect Causal Remediation Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `zig build causal-remediation-audit -- local [scenario]`, a deterministic non-mutating command that records pending remediation proposals from local causal evidence.

**Architecture:** Create a focused Zig tool that reads the existing local verdict, diagnosis, remediation-plan, advice, query, and compare artifacts, parses stable remediation-plan prefixes, and writes schema-versioned JSON plus a human text mirror. The command is a control boundary: it records proposer, evidence ids, source artifacts, verification commands, and pending approval state without approving, applying, or editing source.

**Tech Stack:** Zig 0.16 build system, Zig std JSON parser, existing `causal_run` scenario registry and artifact directory, existing causal dev-loop/diagnosis/remediation-plan artifact conventions, Bun repo verification commands.

---

## File Structure

- Create `packages/zigeffect/tools/causal_remediation_audit.zig`
  - Local/default and scenario path helpers.
  - Verdict JSON shape and schema validation.
  - Stable Markdown parser for remediation-plan prefixes.
  - Deterministic JSON formatter for `zigeffect.causal.remediation-audit.v1`.
  - Human text report formatter.
  - Artifact reader/writer and CLI `main`.
  - Unit tests.
- Modify `packages/zigeffect/build.zig`
  - Add module, executable, run step, tests, and `examples` dependencies.
  - Import `causal_run`.
- Modify `packages/zigeffect/tools/causal_artifacts.zig`
  - Add default and scenario audit JSON/text paths to the retention manifest.
  - Strengthen manifest tests.
- Modify `packages/zigeffect/README.md`
  - Document the audit command after remediation planning.
- Modify `packages/zigeffect/docs/agent-guide.md`
  - Add the audit command to the local self-improvement workflow.
- Modify `packages/zigeffect/docs/causal-scenarios.md`
  - Add audit command and artifact paths.
- Modify `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`
  - Mark remediation audit delivered after implementation.
- Modify `packages/zigeffect/docs/roadmap.md`
  - Move remediation audit from next slice to delivered after implementation.

## Task 1: Parser, Formatter, And Audit Schema

**Files:**
- Create: `packages/zigeffect/tools/causal_remediation_audit.zig`
- Modify: `packages/zigeffect/build.zig`

- [x] **Step 1: Write failing parser and formatter tests**

Create `packages/zigeffect/tools/causal_remediation_audit.zig` with the initial
types, fixtures, and tests below. The tests intentionally reference helpers
that do not exist yet.

```zig
const std = @import("std");
const causal_run = @import("causal_run");

const supported_local_schema = "zigeffect.causal.dev-loop-verdict.v1";
const audit_schema = "zigeffect.causal.remediation-audit.v1";

const Verdict = struct {
    schema: []const u8,
    schema_version: u32,
    status: []const u8,
    next_action: []const u8,
    json_artifacts: usize,
    baseline_pairs: usize,
    actions: usize,
    new_actions: usize,
    persisting_actions: usize,
    observed_actions: usize,
    artifacts: []const VerdictArtifact,
};

const VerdictArtifact = struct {
    json_path: []const u8,
    baseline_path: ?[]const u8,
    advice_report_path: []const u8,
    compare_report_path: ?[]const u8,
    actions: usize,
    new_actions: usize,
    persisting_actions: usize,
    observed_actions: usize,
};

const SourcePaths = struct {
    verdict: []const u8,
    diagnosis: []const u8,
    remediation_plan: []const u8,
    advice: []const u8,
    query: []const u8,
    compare: ?[]const u8,
};

const ParsedPlan = struct {
    target: []const u8,
    posture: []const u8,
    event_ids: []const u64,
    verification_commands: []const []const u8,
    claim_guardrails: []const []const u8,
};

const AuditInput = struct {
    mode: []const u8,
    target: []const u8,
    proposer: []const u8,
    source: SourcePaths,
    plan: ParsedPlan,
};

const remediation_plan_text =
    \\# zigeffect causal remediation plan
    \\
    \\mode: local
    \\target: dogfood
    \\posture: patch-candidate
    \\plan: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-plan.md
    \\verdict: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json
    \\diagnosis: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt
    \\
    \\## Evidence
    \\
    \\- event 3 `scope_closed` status=persisting
    \\  - subsystem: scope_lifecycle
    \\- event 4 `resource_acquired` status=persisting
    \\  - subsystem: scope_lifecycle
    \\
    \\## Required Verification
    \\
    \\- `zig build causal-dev-loop -- baseline`
    \\- `zig build causal-dev-loop -- after`
    \\- `zig build causal-diagnosis -- local`
    \\- `zig build test --summary none`
    \\
    \\## Claim Guardrails
    \\
    \\- Do not claim this patch fixed persisting evidence unless the after verdict is clear or the compare report shows fewer findings.
    \\- Cite event ids from the remediation evidence section in the patch summary.
    \\
;

const clear_plan_text =
    \\# zigeffect causal remediation plan
    \\
    \\mode: local
    \\target: causal-scoped-fiber
    \\posture: do-not-patch
    \\plan: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-plan.md
    \\verdict: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-verdict.json
    \\diagnosis: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-diagnosis.txt
    \\
    \\## Evidence
    \\
    \\- no causal advice actions selected
    \\
    \\## Required Verification
    \\
    \\- `zig build causal-dev-loop -- baseline causal-scoped-fiber`
    \\- `zig build causal-dev-loop -- after causal-scoped-fiber`
    \\- `zig build causal-diagnosis -- local causal-scoped-fiber`
    \\- `zig build test --summary none`
    \\
    \\## Claim Guardrails
    \\
    \\- Do not patch unrelated subsystems when the causal verdict is clear.
    \\
;

test "audit output paths are stable for default and scenario targets" {
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json",
        localAuditJsonPath(),
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.txt",
        localAuditTextPath(),
    );

    const scenario_json = try localAuditJsonPathForScenario(std.testing.allocator, "causal-scoped-fiber");
    defer std.testing.allocator.free(scenario_json);
    const scenario_text = try localAuditTextPathForScenario(std.testing.allocator, "causal-scoped-fiber");
    defer std.testing.allocator.free(scenario_text);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-audit.json",
        scenario_json,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-audit.txt",
        scenario_text,
    );
}

test "plan parser extracts posture events verification and guardrails" {
    const plan = try parseRemediationPlan(std.testing.allocator, remediation_plan_text);
    defer deinitParsedPlan(std.testing.allocator, plan);

    try std.testing.expectEqualStrings("dogfood", plan.target);
    try std.testing.expectEqualStrings("patch-candidate", plan.posture);
    try std.testing.expectEqualSlices(u64, &.{ 3, 4 }, plan.event_ids);
    try std.testing.expectEqual(@as(usize, 4), plan.verification_commands.len);
    try std.testing.expectEqualStrings("zig build causal-dev-loop -- baseline", plan.verification_commands[0]);
    try std.testing.expectEqual(@as(usize, 2), plan.claim_guardrails.len);
    try std.testing.expect(std.mem.indexOf(u8, plan.claim_guardrails[0], "Do not claim") != null);
}

test "plan parser allows do-not-patch plan with no event ids" {
    const plan = try parseRemediationPlan(std.testing.allocator, clear_plan_text);
    defer deinitParsedPlan(std.testing.allocator, plan);

    try std.testing.expectEqualStrings("causal-scoped-fiber", plan.target);
    try std.testing.expectEqualStrings("do-not-patch", plan.posture);
    try std.testing.expectEqual(@as(usize, 0), plan.event_ids.len);
    try std.testing.expectEqualStrings("zig build causal-dev-loop -- baseline causal-scoped-fiber", plan.verification_commands[0]);
}

test "audit JSON records pending approval and source bundle" {
    const plan = try parseRemediationPlan(std.testing.allocator, remediation_plan_text);
    defer deinitParsedPlan(std.testing.allocator, plan);

    const json = try formatAuditJson(std.testing.allocator, .{
        .mode = "local",
        .target = "dogfood",
        .proposer = "local-agent",
        .source = .{
            .verdict = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json",
            .diagnosis = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt",
            .remediation_plan = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-plan.md",
            .advice = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt",
            .query = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt",
            .compare = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt",
        },
        .plan = plan,
    });
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema\": \"zigeffect.causal.remediation-audit.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"approval_status\": \"pending\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"event_ids\": [3, 4]") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"verification_commands\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"claim_guardrails\"") != null);
}

test "audit text mirrors approval state and evidence ids" {
    const plan = try parseRemediationPlan(std.testing.allocator, remediation_plan_text);
    defer deinitParsedPlan(std.testing.allocator, plan);

    const text = try formatAuditText(std.testing.allocator, .{
        .mode = "local",
        .target = "dogfood",
        .proposer = "local-agent",
        .source = .{
            .verdict = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json",
            .diagnosis = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt",
            .remediation_plan = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-plan.md",
            .advice = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt",
            .query = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt",
            .compare = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt",
        },
        .plan = plan,
    });
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "zigeffect causal remediation audit") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "approval_status: pending") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "applied: false") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "- event 3") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "- review remediation plan before source edits") != null);
}
```

- [x] **Step 2: Wire only the test module and verify red**

Modify `packages/zigeffect/build.zig` near the remediation-plan tool module:

```zig
    const causal_remediation_audit_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_remediation_audit.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_remediation_audit_tool_module.addImport("causal_run", causal_run_tool_module);

    const causal_remediation_audit_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-remediation-audit-tests",
        .root_module = causal_remediation_audit_tool_module,
    });
    const run_causal_remediation_audit_tool_tests = b.addRunArtifact(causal_remediation_audit_tool_tests);
```

Add only the test dependency near the other `examples_step` tool tests:

```zig
    examples_step.dependOn(&run_causal_remediation_audit_tool_tests.step);
```

Run:

```sh
cd packages/zigeffect
zig build examples
```

Expected: FAIL because path helpers, parsing, deinit, and formatter functions
are missing.

- [x] **Step 3: Implement parser and deterministic formatters**

Implement these helpers in `causal_remediation_audit.zig`:

```zig
fn localAuditJsonPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-remediation-audit.json";
}

fn localAuditTextPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-remediation-audit.txt";
}

fn localAuditJsonPathForScenario(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-dev-loop-{s}-remediation-audit.json",
        .{ causal_run.artifact_dir, scenario_slug },
    );
}

fn localAuditTextPathForScenario(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-dev-loop-{s}-remediation-audit.txt",
        .{ causal_run.artifact_dir, scenario_slug },
    );
}
```

Implement `parseRemediationPlan` by scanning line-by-line:

- `target: ` sets `ParsedPlan.target`.
- `posture: ` sets `ParsedPlan.posture`.
- lines beginning `- event ` parse the integer between `- event ` and the next
  space.
- after `## Required Verification`, bullet lines of the form
  `- `command`` append the unbackticked command until the next `## ` section.
- after `## Claim Guardrails`, bullet lines append guardrail text until the
  next `## ` section or end of file.

Allocation rules:

```zig
fn deinitParsedPlan(allocator: std.mem.Allocator, plan: ParsedPlan) void {
    allocator.free(plan.target);
    allocator.free(plan.posture);
    allocator.free(plan.event_ids);
    for (plan.verification_commands) |command| allocator.free(command);
    allocator.free(plan.verification_commands);
    for (plan.claim_guardrails) |guardrail| allocator.free(guardrail);
    allocator.free(plan.claim_guardrails);
}
```

Implement deterministic JSON formatting with explicit escaping:

```zig
fn appendJsonString(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: []const u8) !void {
    try output.append(allocator, '"');
    for (value) |byte| switch (byte) {
        '"' => try output.appendSlice(allocator, "\\\""),
        '\\' => try output.appendSlice(allocator, "\\\\"),
        '\n' => try output.appendSlice(allocator, "\\n"),
        '\r' => try output.appendSlice(allocator, "\\r"),
        '\t' => try output.appendSlice(allocator, "\\t"),
        else => try output.append(allocator, byte),
    };
    try output.append(allocator, '"');
}
```

`formatAuditJson` must emit the exact top-level control fields:

```json
{
  "schema": "zigeffect.causal.remediation-audit.v1",
  "schema_version": 1,
  "mode": "local",
  "target": "dogfood",
  "proposer": "local-agent",
  "approval_status": "pending",
  "applied": false,
  "posture": "patch-candidate"
}
```

Then add `source`, `event_ids`, `verification_commands`, and
`claim_guardrails` in the same deterministic order used by the test.

`formatAuditText` must mirror the design:

```text
zigeffect causal remediation audit
schema: zigeffect.causal.remediation-audit.v1
mode: local
target: dogfood
proposer: local-agent
approval_status: pending
applied: false
posture: patch-candidate
```

- [x] **Step 4: Run green verification for Task 1**

Run:

```sh
cd packages/zigeffect
zig fmt tools/causal_remediation_audit.zig build.zig
zig build examples
```

Expected: PASS.

- [x] **Step 5: Commit Task 1**

Run:

```sh
git add packages/zigeffect/tools/causal_remediation_audit.zig packages/zigeffect/build.zig
git diff --cached --check
git commit -m "feat(zigeffect): add causal remediation audit formatter"
```

## Task 2: CLI Artifact Reader And Build Step

**Files:**
- Modify: `packages/zigeffect/tools/causal_remediation_audit.zig`
- Modify: `packages/zigeffect/build.zig`

- [x] **Step 1: Add failing CLI/path tests**

Add tests for usage, verdict validation, query-report path derivation, and
local input paths:

```zig
test "usage names local mode" {
    try std.testing.expectEqualStrings(
        "usage: zig build causal-remediation-audit -- local [scenario]\n",
        usage(),
    );
}

test "unsupported verdict schema is rejected" {
    const verdict = Verdict{
        .schema = "other.schema",
        .schema_version = 1,
        .status = "attention",
        .next_action = "inspect",
        .json_artifacts = 1,
        .baseline_pairs = 1,
        .actions = 1,
        .new_actions = 0,
        .persisting_actions = 1,
        .observed_actions = 0,
        .artifacts = &.{.{
            .json_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json",
            .baseline_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json",
            .advice_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt",
            .compare_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt",
            .actions = 1,
            .new_actions = 0,
            .persisting_actions = 1,
            .observed_actions = 0,
        }},
    };

    try std.testing.expectError(error.UnsupportedVerdictSchema, validateLocalVerdict(verdict));
}

test "query report path is derived from after json" {
    const path = try queryReportPathForJson(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json",
    );
    defer std.testing.allocator.free(path);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt",
        path,
    );
}

test "scenario local input paths are stable" {
    const verdict = try localVerdictPathForScenario(std.testing.allocator, "causal-scoped-fiber");
    defer std.testing.allocator.free(verdict);
    const diagnosis = try localDiagnosisPathForScenario(std.testing.allocator, "causal-scoped-fiber");
    defer std.testing.allocator.free(diagnosis);
    const plan = try localRemediationPlanPathForScenario(std.testing.allocator, "causal-scoped-fiber");
    defer std.testing.allocator.free(plan);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-verdict.json",
        verdict,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-diagnosis.txt",
        diagnosis,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-plan.md",
        plan,
    );
}
```

Run:

```sh
cd packages/zigeffect
zig build examples
```

Expected: FAIL because CLI helpers are missing.

- [x] **Step 2: Implement path helpers and verdict validation**

Add helpers that mirror `causal_remediation_plan.zig` naming:

```zig
fn localVerdictPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-verdict.json";
}

fn localDiagnosisPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-diagnosis.txt";
}

fn localRemediationPlanPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-remediation-plan.md";
}

fn validateLocalVerdict(verdict: Verdict) !void {
    if (!std.mem.eql(u8, verdict.schema, supported_local_schema)) return error.UnsupportedVerdictSchema;
    if (verdict.schema_version != 1) return error.UnsupportedVerdictSchema;
    if (verdict.artifacts.len == 0) return error.EmptyVerdictArtifacts;
}
```

Also add scenario path variants for verdict, diagnosis, and remediation plan
using the `zigeffect-causal-dev-loop-<scenario>-...` convention.

- [x] **Step 3: Implement artifact IO and `runLocal`**

Add IO helpers:

```zig
fn readArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => error.MissingRemediationAuditInput,
        else => return err,
    };
}

fn writeArtifact(io: std.Io, path: []const u8, contents: []const u8) !void {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return error.InvalidArtifactPath;
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, path[0..slash]);
    try cwd.writeFile(io, .{ .sub_path = path, .data = contents });
}
```

`runLocal` must:

1. Resolve default or scenario paths.
2. Read the verdict JSON and validate schema/version/artifacts.
3. Read diagnosis, remediation plan, advice, query, and compare artifacts.
4. Parse the remediation plan.
5. Format JSON and text audit records.
6. Write both audit artifacts.
7. Print the text report.

Use `proposer = "local-agent"`, `approval_status = "pending"`, and
`applied = false` in every record.

- [x] **Step 4: Implement CLI `main` and usage errors**

Add:

```zig
fn usage() []const u8 {
    return "usage: zig build causal-remediation-audit -- local [scenario]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-remediation-audit error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}
```

`main` must accept only:

```text
zig build causal-remediation-audit -- local
zig build causal-remediation-audit -- local <registered-scenario-slug>
```

Use `causal_run.scenarioByName` to validate a scenario slug.

- [x] **Step 5: Wire executable build step**

Modify `packages/zigeffect/build.zig` after the remediation-plan executable:

```zig
    const causal_remediation_audit_tool = b.addExecutable(.{
        .name = "zigeffect-causal-remediation-audit",
        .root_module = causal_remediation_audit_tool_module,
    });
    const run_causal_remediation_audit_tool = b.addRunArtifact(causal_remediation_audit_tool);
    if (b.args) |args| run_causal_remediation_audit_tool.addArgs(args);
    const causal_remediation_audit_step = b.step("causal-remediation-audit", "Write a pending causal remediation audit from local dev-loop reports");
    causal_remediation_audit_step.dependOn(&run_causal_remediation_audit_tool.step);
```

Add the executable dependency to `examples_step`:

```zig
    examples_step.dependOn(&causal_remediation_audit_tool.step);
```

- [x] **Step 6: Run green verification for Task 2**

Run:

```sh
cd packages/zigeffect
zig fmt tools/causal_remediation_audit.zig build.zig
zig build examples
```

Expected: PASS.

- [x] **Step 7: Commit Task 2**

Run:

```sh
git add packages/zigeffect/tools/causal_remediation_audit.zig packages/zigeffect/build.zig
git diff --cached --check
git commit -m "feat(zigeffect): wire causal remediation audit command"
```

## Task 3: Manifest And Documentation Catch-Up

**Files:**
- Modify: `packages/zigeffect/tools/causal_artifacts.zig`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify: `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`
- Modify: `packages/zigeffect/docs/roadmap.md`

- [x] **Step 1: Write failing manifest expectations**

In `packages/zigeffect/tools/causal_artifacts.zig`, extend the default manifest
test with:

```zig
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.txt") != null);
```

Extend the scenario manifest test with:

```zig
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-remediation-audit.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-remediation-audit.txt") != null);
```

Run:

```sh
cd packages/zigeffect
zig build examples
```

Expected: FAIL because the manifest does not print audit paths yet.

- [x] **Step 2: Add audit paths to manifest output**

In `appendDefaultLoopArtifacts`, print:

```zig
    try output.print(allocator, "- dev-loop remediation audit json {s}/zigeffect-causal-dev-loop-remediation-audit.json\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- dev-loop remediation audit text {s}/zigeffect-causal-dev-loop-remediation-audit.txt\n", .{causal_run.artifact_dir});
```

In `appendScenarioLoopArtifacts`, print:

```zig
    try output.print(allocator, "  loop remediation audit json: {s}/zigeffect-causal-dev-loop-{s}-remediation-audit.json\n", .{ causal_run.artifact_dir, slug });
    try output.print(allocator, "  loop remediation audit text: {s}/zigeffect-causal-dev-loop-{s}-remediation-audit.txt\n", .{ causal_run.artifact_dir, slug });
```

- [x] **Step 3: Update docs**

Update `packages/zigeffect/README.md`, `packages/zigeffect/docs/agent-guide.md`,
and `packages/zigeffect/docs/causal-scenarios.md` so the local workflow reads:

```sh
zig build causal-dev-loop -- baseline [scenario]
zig build causal-dev-loop -- after [scenario]
zig build causal-dev-agent -- local [scenario]
zig build causal-diagnosis -- local [scenario]
zig build causal-remediation-plan -- local [scenario]
zig build causal-remediation-audit -- local [scenario]
```

Document the new artifacts:

```text
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.txt
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-remediation-audit.json
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-remediation-audit.txt
```

Update both roadmap files:

- mark remediation audit as delivered;
- keep approval/rejection, patch proposals, and policy-controlled application as
  remaining work.

- [x] **Step 4: Run green verification for Task 3**

Run:

```sh
cd packages/zigeffect
zig fmt tools/causal_artifacts.zig
zig build examples
```

Expected: PASS.

- [x] **Step 5: Commit Task 3**

Run:

```sh
git add packages/zigeffect/tools/causal_artifacts.zig packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/causal-scenarios.md docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md packages/zigeffect/docs/roadmap.md
git diff --cached --check
git commit -m "docs(zigeffect): document causal remediation audit"
```

## Task 4: Integration Verification And Checklist Close

**Files:**
- Modify: `docs/superpowers/plans/2026-06-07-zigeffect-causal-remediation-audit.md`

- [x] **Step 1: Verify default local audit flow**

Run:

```sh
cd packages/zigeffect
rm -rf .zig-cache/causal-artifacts
zig build causal-dev-loop -- baseline
zig build causal-dev-loop -- after
zig build causal-diagnosis -- local
zig build causal-remediation-plan -- local
zig build causal-remediation-audit -- local
test -f .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json
test -f .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.txt
rg '"schema": "zigeffect.causal.remediation-audit.v1"' .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json
rg '"approval_status": "pending"' .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json
rg '"applied": false' .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json
rg '"event_ids": \\[3, 4, 5, 6\\]' .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json
rg 'approval_status: pending' .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.txt
```

Expected: all commands exit zero. If the dogfood event ids change because the
fixture changes, inspect the remediation plan and update only the exact event-id
assertion to match the new deterministic fixture.

- [x] **Step 2: Verify scenario local audit flow**

Run:

```sh
cd packages/zigeffect
rm -rf .zig-cache/causal-artifacts
zig build causal-dev-loop -- baseline causal-scoped-fiber
zig build causal-dev-loop -- after causal-scoped-fiber
zig build causal-diagnosis -- local causal-scoped-fiber
zig build causal-remediation-plan -- local causal-scoped-fiber
zig build causal-remediation-audit -- local causal-scoped-fiber
test -f .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-audit.json
test -f .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-audit.txt
rg '"target": "causal-scoped-fiber"' .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-audit.json
rg '"posture": "do-not-patch"' .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-audit.json
rg '"event_ids": \\[\\]' .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-audit.json
```

Expected: all commands exit zero.

- [x] **Step 3: Verify missing input failure**

Run:

```sh
cd packages/zigeffect
rm -rf .zig-cache/causal-artifacts
output=$(zig build causal-remediation-audit -- local 2>&1)
exit_code=$?
printf "%s\n" "$output"
test "$exit_code" -ne 0
printf "%s\n" "$output" | rg "causal-remediation-audit error: MissingRemediationAuditInput"
printf "%s\n" "$output" | rg "usage: zig build causal-remediation-audit -- local \\[scenario\\]"
```

Expected: exit code is nonzero and output includes the stable error plus usage.

- [x] **Step 4: Verify manifest paths**

Run:

```sh
cd packages/zigeffect
zig build causal-artifacts > /tmp/zigeffect-causal-artifacts.txt 2>&1
rg "zigeffect-causal-dev-loop-remediation-audit.json" /tmp/zigeffect-causal-artifacts.txt
rg "zigeffect-causal-dev-loop-remediation-audit.txt" /tmp/zigeffect-causal-artifacts.txt
rg "zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-audit.json" /tmp/zigeffect-causal-artifacts.txt
rg "zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-audit.txt" /tmp/zigeffect-causal-artifacts.txt
```

Expected: all commands exit zero. Capture stderr because the manifest uses
`std.debug.print`.

- [x] **Step 5: Run full verification**

Run:

```sh
cd packages/zigeffect
zig build examples
zig build test --summary none
cd ../..
git diff --check
bun run zig:test
```

Expected: all commands exit zero.

- [x] **Step 6: Mark this implementation plan complete**

Update every completed checkbox in this file from `- [ ]` to `- [x]`.

- [x] **Step 7: Commit final checklist update**

Run:

```sh
git add docs/superpowers/plans/2026-06-07-zigeffect-causal-remediation-audit.md
git diff --cached --check
git commit -m "docs(zigeffect): complete causal remediation audit checklist"
```

## Completion Checklist

- [x] `causal-remediation-audit` writes default JSON and text audit artifacts.
- [x] `causal-remediation-audit` writes scenario JSON and text audit artifacts.
- [x] Audit JSON uses schema `zigeffect.causal.remediation-audit.v1`.
- [x] Audit JSON and text show `approval_status=pending` and `applied=false`.
- [x] Audit artifacts cite source verdict, diagnosis, remediation plan, advice,
  query, and compare paths.
- [x] Audit artifacts cite evidence event ids when the remediation plan has
  event ids.
- [x] Do-not-patch plans can produce an empty `event_ids` array.
- [x] Missing inputs fail with stable usage text.
- [x] Manifest, README, agent guide, causal scenarios, and roadmap docs mention
  the audit command and artifacts.
- [x] `zig build examples` passes in `packages/zigeffect`.
- [x] `zig build test --summary none` passes in `packages/zigeffect`.
- [x] `bun run zig:test` passes at the repo root.

## Self-Review

- Spec coverage: this plan implements every requirement in
  `docs/superpowers/specs/2026-06-07-zigeffect-causal-remediation-audit-design.md`:
  command shape, schema, parsing rules, pending approval defaults, docs,
  manifest, default flow, scenario flow, and missing-input failure.
- Placeholder scan: no placeholder tokens or vague incomplete instructions
  remain.
- Type consistency: `SourcePaths`, `ParsedPlan`, `AuditInput`, `Verdict`, and
  `VerdictArtifact` are used consistently across parser, formatter, and CLI
  tasks.
