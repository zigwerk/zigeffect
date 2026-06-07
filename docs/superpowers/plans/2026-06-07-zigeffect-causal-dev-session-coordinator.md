# zigeffect Causal Dev Session Coordinator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `zig build causal-dev-session -- start|assess|status [scenario]`, a local coordinator that turns the existing causal dev-loop, diagnosis, remediation-plan, and audit commands into one repeatable self-improvement harness.

**Architecture:** Create a focused `packages/zigeffect/tools/causal_dev_session.zig` executable with pure path/schema/report helpers, a fakeable command runner, and production child-process execution that invokes existing `zig build` causal commands without using a shell. Wire it into `packages/zigeffect/build.zig`, add session paths to `causal-artifacts`, and update docs.

**Tech Stack:** Zig 0.16 build system, Zig std JSON/text formatting, existing `causal_run` scenario registry, existing causal command-line tools, Bun repo verification commands.

---

## File Structure

- Create `packages/zigeffect/tools/causal_dev_session.zig`
  - Parses `start|assess|status [scenario]`.
  - Validates scenario slugs through `causal_run.scenarioByName`.
  - Builds deterministic session artifact paths.
  - Runs child commands through an injectable runner.
  - Writes session JSON and text reports.
  - Preserves a stable non-mutating guardrail.
- Modify `packages/zigeffect/build.zig`
  - Add module, executable, build step, tests, and `examples` dependencies.
  - Import `causal_run`.
- Modify `packages/zigeffect/tools/causal_artifacts.zig`
  - Add default and scenario session JSON/text paths to the manifest.
- Modify `packages/zigeffect/README.md`
  - Add the coordinator to the local causal workflow.
- Modify `packages/zigeffect/docs/agent-guide.md`
  - Add the recommended agent protocol.
- Modify `packages/zigeffect/docs/causal-scenarios.md`
  - Add session artifact paths and command usage.
- Modify `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`
  - Mark the coordinator as the next Milestone 7 slice while this plan is active.
- Modify `packages/zigeffect/docs/roadmap.md`
  - Add the coordinator to future/delivered status when the implementation lands.

## Task 1: Session Model, Paths, And Report Formatter

**Files:**
- Create: `packages/zigeffect/tools/causal_dev_session.zig`

- [x] **Step 1: Write the failing formatter/path tests**

Create `packages/zigeffect/tools/causal_dev_session.zig` with these tests and declarations:

```zig
const std = @import("std");
const causal_run = @import("causal_run");

const schema_name = "zigeffect.causal.dev-session.v1";

const SessionPhase = enum {
    baseline_captured,
    assessed,
    failed,
};

const CommandStatus = enum {
    ok,
    failed,
    skipped,
};

const CommandRecord = struct {
    name: []const u8,
    argv: []const []const u8,
    status: CommandStatus,
    exit_code: ?i32,
};

const SessionArtifacts = struct {
    session_json_path: []const u8,
    session_text_path: []const u8,
    before_json_path: []const u8,
    after_json_path: []const u8,
    verdict_json_path: []const u8,
    diagnosis_text_path: []const u8,
    remediation_plan_path: []const u8,
    remediation_audit_json_path: []const u8,
    remediation_audit_text_path: []const u8,
};

const SessionRecord = struct {
    schema: []const u8,
    schema_version: u32,
    mode: []const u8,
    target: []const u8,
    phase: SessionPhase,
    status: []const u8,
    commands: []const CommandRecord,
    artifacts: SessionArtifacts,
};

test "default session paths are deterministic" {
    const paths = defaultSessionArtifacts();

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-session.json",
        paths.session_json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-session.txt",
        paths.session_text_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json",
        paths.before_json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json",
        paths.remediation_audit_json_path,
    );
}

test "scenario session paths include slug" {
    const paths = try scenarioSessionArtifacts(std.testing.allocator, "causal-scoped-fiber");
    defer deinitOwnedSessionArtifacts(std.testing.allocator, paths);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-session-causal-scoped-fiber.json",
        paths.session_json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-after.json",
        paths.after_json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-audit.txt",
        paths.remediation_audit_text_path,
    );
}

test "session text shows next assessment command after baseline" {
    const commands = [_]CommandRecord{
        .{
            .name = "causal-dev-loop baseline",
            .argv = &.{ "zig", "build", "causal-dev-loop", "--", "baseline" },
            .status = .ok,
            .exit_code = 0,
        },
    };
    const record = SessionRecord{
        .schema = schema_name,
        .schema_version = 1,
        .mode = "local",
        .target = "dogfood",
        .phase = .baseline_captured,
        .status = "ready-for-edit",
        .commands = &commands,
        .artifacts = defaultSessionArtifacts(),
    };
    const report = try formatSessionText(std.testing.allocator, record);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal dev session") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "phase: baseline-captured") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "next: zig build causal-dev-session -- assess") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "source edits remain outside causal tools") != null);
}

test "assessed session text points at remediation audit and decision command" {
    const commands = [_]CommandRecord{
        .{
            .name = "causal-dev-loop after",
            .argv = &.{ "zig", "build", "causal-dev-loop", "--", "after", "causal-scoped-fiber" },
            .status = .ok,
            .exit_code = 0,
        },
        .{
            .name = "causal-remediation-audit",
            .argv = &.{ "zig", "build", "causal-remediation-audit", "--", "local", "causal-scoped-fiber" },
            .status = .ok,
            .exit_code = 0,
        },
    };
    const paths = try scenarioSessionArtifacts(std.testing.allocator, "causal-scoped-fiber");
    defer deinitOwnedSessionArtifacts(std.testing.allocator, paths);

    const record = SessionRecord{
        .schema = schema_name,
        .schema_version = 1,
        .mode = "local",
        .target = "causal-scoped-fiber",
        .phase = .assessed,
        .status = "audit-ready",
        .commands = &commands,
        .artifacts = paths,
    };
    const report = try formatSessionText(std.testing.allocator, record);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "target: causal-scoped-fiber") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "audit: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-audit.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "next: zig build causal-remediation-decision -- local approve|reject causal-scoped-fiber") != null);
}
```

- [x] **Step 2: Wire only the test module and verify red**

Modify `packages/zigeffect/build.zig` near the other causal tool modules:

```zig
const causal_dev_session_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_dev_session.zig"),
    .target = target,
    .optimize = optimize,
});
causal_dev_session_tool_module.addImport("causal_run", causal_run_tool_module);

const causal_dev_session_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-dev-session-tests",
    .root_module = causal_dev_session_tool_module,
});
const run_causal_dev_session_tool_tests = b.addRunArtifact(causal_dev_session_tool_tests);
```

Add the tests to `examples_step`:

```zig
examples_step.dependOn(&run_causal_dev_session_tool_tests.step);
```

Run:

```sh
cd packages/zigeffect
zig build examples
```

Expected: FAIL because `defaultSessionArtifacts`, `scenarioSessionArtifacts`,
`deinitOwnedSessionArtifacts`, and `formatSessionText` are not implemented.

- [x] **Step 3: Implement pure helpers**

Implement:

```zig
fn defaultSessionArtifacts() SessionArtifacts {
    return .{
        .session_json_path = causal_run.artifact_dir ++ "/zigeffect-causal-dev-session.json",
        .session_text_path = causal_run.artifact_dir ++ "/zigeffect-causal-dev-session.txt",
        .before_json_path = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-before.json",
        .after_json_path = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-after.json",
        .verdict_json_path = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-verdict.json",
        .diagnosis_text_path = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-diagnosis.txt",
        .remediation_plan_path = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-remediation-plan.md",
        .remediation_audit_json_path = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-remediation-audit.json",
        .remediation_audit_text_path = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-remediation-audit.txt",
    };
}

fn scenarioSessionArtifacts(allocator: std.mem.Allocator, slug: []const u8) !SessionArtifacts {
    return .{
        .session_json_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-session-{s}.json", .{ causal_run.artifact_dir, slug }),
        .session_text_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-session-{s}.txt", .{ causal_run.artifact_dir, slug }),
        .before_json_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-before.json", .{ causal_run.artifact_dir, slug }),
        .after_json_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-after.json", .{ causal_run.artifact_dir, slug }),
        .verdict_json_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-verdict.json", .{ causal_run.artifact_dir, slug }),
        .diagnosis_text_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-diagnosis.txt", .{ causal_run.artifact_dir, slug }),
        .remediation_plan_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-remediation-plan.md", .{ causal_run.artifact_dir, slug }),
        .remediation_audit_json_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-remediation-audit.json", .{ causal_run.artifact_dir, slug }),
        .remediation_audit_text_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-remediation-audit.txt", .{ causal_run.artifact_dir, slug }),
    };
}
```

Also implement `deinitOwnedSessionArtifacts`, `formatPhase`, `formatCommandStatus`,
and `formatSessionText`.

- [x] **Step 4: Run green verification for Task 1**

Run:

```sh
cd packages/zigeffect
zig build examples
```

Expected: PASS.

- [x] **Step 5: Commit Task 1**

Run:

```sh
git add packages/zigeffect/tools/causal_dev_session.zig packages/zigeffect/build.zig
git diff --cached --check
git commit -m "feat(zigeffect): add causal dev session formatter"
```

## Task 2: CLI, Command Runner, And Artifact Writes

**Files:**
- Modify: `packages/zigeffect/tools/causal_dev_session.zig`
- Modify: `packages/zigeffect/build.zig`

- [x] **Step 1: Add failing CLI and runner tests**

Add tests for:

- `parseOptions(&.{ "start" })` returns phase `start` and no scenario.
- `parseOptions(&.{ "assess", "causal-scoped-fiber" })` validates the scenario.
- duplicate scenarios fail with `DuplicateScenarioArgument`.
- unknown scenarios fail with `UnknownScenario`.
- a fake runner receives the exact command list for `start`.
- a fake runner receives the exact command list for `assess`.
- failed command records are included in the session report.

Run:

```sh
cd packages/zigeffect
zig build examples
```

Expected: FAIL until the parser and runner are implemented.

- [x] **Step 2: Implement parser and command planning**

Implement these command plans:

```zig
// start default
&.{ "zig", "build", "causal-dev-loop", "--", "baseline" }

// start scenario
&.{ "zig", "build", "causal-dev-loop", "--", "baseline", scenario }

// assess default
&.{ "zig", "build", "causal-dev-loop", "--", "after" }
&.{ "zig", "build", "causal-dev-agent", "--", "local" }
&.{ "zig", "build", "causal-diagnosis", "--", "local" }
&.{ "zig", "build", "causal-remediation-plan", "--", "local" }
&.{ "zig", "build", "causal-remediation-audit", "--", "local" }

// assess scenario: append scenario to each command after the mode argument.
```

Use a runner abstraction:

```zig
const RunOutput = struct {
    status: CommandStatus,
    exit_code: ?i32,
    stdout: []const u8,
    stderr: []const u8,
};

const Runner = struct {
    ptr: *anyopaque,
    runFn: *const fn (*anyopaque, std.mem.Allocator, []const []const u8) anyerror!RunOutput,

    fn run(self: Runner, allocator: std.mem.Allocator, argv: []const []const u8) !RunOutput {
        return self.runFn(self.ptr, allocator, argv);
    }
};
```

Production runner must use `std.process.Child.run` with argv arrays, not a
shell string.

- [x] **Step 3: Implement JSON/text writes and `status` mode**

Add:

- `formatSessionJson(allocator, record)`;
- `writeArtifact(path, contents)`;
- `readStatus(path)`;
- `runStart(allocator, runner, scenario)`;
- `runAssess(allocator, runner, scenario)`;
- `runStatus(allocator, scenario)`.

`assess` must check that `before_json_path` exists before running after-phase.
If missing, write a failed session report and return
`error.MissingBaselineArtifact`.

- [x] **Step 4: Wire executable build step**

In `packages/zigeffect/build.zig`, add:

```zig
const causal_dev_session_tool = b.addExecutable(.{
    .name = "zigeffect-causal-dev-session",
    .root_module = causal_dev_session_tool_module,
});
const run_causal_dev_session_tool = b.addRunArtifact(causal_dev_session_tool);
if (b.args) |args| run_causal_dev_session_tool.addArgs(args);
const causal_dev_session_step = b.step("causal-dev-session", "Run the local causal development session coordinator");
causal_dev_session_step.dependOn(&run_causal_dev_session_tool.step);
```

Add to `examples_step`:

```zig
examples_step.dependOn(&causal_dev_session_tool.step);
```

- [x] **Step 5: Run green verification for Task 2**

Run:

```sh
cd packages/zigeffect
zig build examples
```

Expected: PASS.

- [x] **Step 6: Commit Task 2**

Run:

```sh
git add packages/zigeffect/tools/causal_dev_session.zig packages/zigeffect/build.zig
git diff --cached --check
git commit -m "feat(zigeffect): wire causal dev session coordinator"
```

## Task 3: Manifest And Docs

**Files:**
- Modify: `packages/zigeffect/tools/causal_artifacts.zig`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify: `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`
- Modify: `packages/zigeffect/docs/roadmap.md`

- [x] **Step 1: Add failing manifest expectations**

Extend `causal_artifacts.zig` tests to expect:

```text
zigeffect-causal-dev-session.json
zigeffect-causal-dev-session.txt
zigeffect-causal-dev-session-causal-scoped-fiber.json
zigeffect-causal-dev-session-causal-scoped-fiber.txt
```

Run:

```sh
cd packages/zigeffect
zig build examples
```

Expected: FAIL until manifest output is updated.

- [x] **Step 2: Add session paths to manifest output**

In `appendDefaultLoopArtifacts`, add:

```zig
try output.print(allocator, "- dev session json {s}/zigeffect-causal-dev-session.json\n", .{causal_run.artifact_dir});
try output.print(allocator, "- dev session text {s}/zigeffect-causal-dev-session.txt\n", .{causal_run.artifact_dir});
```

In `appendScenarioLoopArtifacts`, add:

```zig
try output.print(allocator, "  dev session json: {s}/zigeffect-causal-dev-session-{s}.json\n", .{ causal_run.artifact_dir, slug });
try output.print(allocator, "  dev session text: {s}/zigeffect-causal-dev-session-{s}.txt\n", .{ causal_run.artifact_dir, slug });
```

- [x] **Step 3: Update docs**

Document this local sequence:

```sh
zig build causal-dev-session -- start [scenario]
# edit source
zig build causal-dev-session -- assess [scenario]
zig build causal-dev-session -- status [scenario]
zig build causal-remediation-decision -- local approve|reject [scenario]
```

Docs must state:

- `causal-dev-session` writes session JSON/text artifacts.
- `assess` can create a remediation audit but does not approve it.
- source edits and patch application remain outside causal tools.
- `causal-remediation-decision` remains the explicit review boundary.

- [x] **Step 4: Run green verification for Task 3**

Run:

```sh
cd packages/zigeffect
zig build examples
```

Expected: PASS.

- [x] **Step 5: Commit Task 3**

Run:

```sh
git add packages/zigeffect/tools/causal_artifacts.zig packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/causal-scenarios.md docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md packages/zigeffect/docs/roadmap.md
git diff --cached --check
git commit -m "docs(zigeffect): document causal dev session workflow"
```

## Task 4: Integration Verification

**Files:**
- Modify: `docs/superpowers/plans/2026-06-07-zigeffect-causal-dev-session-coordinator.md`

- [x] **Step 1: Verify default start and assess flow**

Run:

```sh
cd packages/zigeffect
rm -rf .zig-cache/causal-artifacts
zig build causal-dev-session -- start
test -f .zig-cache/causal-artifacts/zigeffect-causal-dev-session.json
test -f .zig-cache/causal-artifacts/zigeffect-causal-dev-session.txt
rg '"schema": "zigeffect.causal.dev-session.v1"' .zig-cache/causal-artifacts/zigeffect-causal-dev-session.json
rg '"phase": "baseline-captured"' .zig-cache/causal-artifacts/zigeffect-causal-dev-session.json
zig build causal-dev-session -- assess
rg '"phase": "assessed"' .zig-cache/causal-artifacts/zigeffect-causal-dev-session.json
test -f .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json
rg 'next: zig build causal-remediation-decision -- local approve|reject' .zig-cache/causal-artifacts/zigeffect-causal-dev-session.txt
```

Expected: all commands exit zero.

- [x] **Step 2: Verify scenario start and assess flow**

Run:

```sh
cd packages/zigeffect
rm -rf .zig-cache/causal-artifacts
zig build causal-dev-session -- start causal-scoped-fiber
zig build causal-dev-session -- assess causal-scoped-fiber
test -f .zig-cache/causal-artifacts/zigeffect-causal-dev-session-causal-scoped-fiber.json
test -f .zig-cache/causal-artifacts/zigeffect-causal-dev-session-causal-scoped-fiber.txt
rg '"target": "causal-scoped-fiber"' .zig-cache/causal-artifacts/zigeffect-causal-dev-session-causal-scoped-fiber.json
rg 'causal-remediation-decision -- local approve|reject causal-scoped-fiber' .zig-cache/causal-artifacts/zigeffect-causal-dev-session-causal-scoped-fiber.txt
```

Expected: all commands exit zero.

- [x] **Step 3: Verify missing baseline fails after writing session report**

Run:

```sh
cd packages/zigeffect
rm -rf .zig-cache/causal-artifacts
output=$(zig build causal-dev-session -- assess 2>&1)
exit_code=$?
printf "%s\n" "$output"
test "$exit_code" -ne 0
printf "%s\n" "$output" | rg "causal-dev-session error: MissingBaselineArtifact"
test -f .zig-cache/causal-artifacts/zigeffect-causal-dev-session.json
rg '"phase": "failed"' .zig-cache/causal-artifacts/zigeffect-causal-dev-session.json
```

Expected: the command fails intentionally, writes a failed session artifact,
and prints stable usage/error text.

- [x] **Step 4: Verify status mode**

Run:

```sh
cd packages/zigeffect
zig build causal-dev-session -- status
zig build causal-dev-session -- status causal-scoped-fiber
```

Expected: both commands print the latest session status when artifacts exist.

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

- [x] **Step 6: Mark this plan complete and commit**

Run:

```sh
git add docs/superpowers/plans/2026-06-07-zigeffect-causal-dev-session-coordinator.md
git diff --cached --check
git commit -m "docs(zigeffect): complete causal dev session checklist"
```

## Completion Checklist

- [x] `causal-dev-session start` runs the baseline dev-loop command.
- [x] `causal-dev-session assess` runs after, dev-agent, diagnosis,
  remediation-plan, and remediation-audit commands.
- [x] `causal-dev-session status` reads the latest session artifact.
- [x] Default session JSON/text paths are deterministic.
- [x] Scenario session JSON/text paths are deterministic.
- [x] Missing baseline fails with `MissingBaselineArtifact`.
- [x] Failed assessments write a session artifact before exiting nonzero.
- [x] Session artifacts include schema `zigeffect.causal.dev-session.v1`.
- [x] Session text states that source edits remain outside causal tools.
- [x] Session text points reviewers at `causal-remediation-decision`.
- [x] Manifest lists default and scenario session artifacts.
- [x] README, agent guide, causal scenarios, and roadmap docs mention the
  coordinator.
- [x] `zig build examples` passes in `packages/zigeffect`.
- [x] `zig build test --summary none` passes in `packages/zigeffect`.
- [x] `bun run zig:test` passes at the repo root.
