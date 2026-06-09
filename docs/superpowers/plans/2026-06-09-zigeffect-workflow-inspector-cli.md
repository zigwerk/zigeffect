# zigeffect Workflow Inspector CLI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add workflow journal inspection, replay, and list CLI tools backed by reusable workflow inspection reports.

**Architecture:** `workflow/inspect.zig` owns event grouping, selected-execution replay, pending-work summaries, last-failure extraction, and text/JSON report formatting. `tools/workflow_journal_inspect.zig`, `tools/workflow_replay.zig`, and `tools/workflow_list.zig` are thin command entrypoints that load fixture JSONL files or real `FileJournalStore` directories and print reports. `build.zig` wires the three commands and their tests using the existing tool-module pattern.

**Tech Stack:** Zig 0.16, existing `fx.workflow` journal/replay/store modules, `std.json`, `std.Io`, Bun project scripts.

---

## File Structure

- Create `packages/zigeffect/src/workflow/inspect.zig`
  - Owns report structs, event grouping, selected-execution replay, pending
    summaries, last-failure detection, and text/JSON formatting.
- Modify `packages/zigeffect/src/workflow/root.zig`
  - Exposes workflow inspection types and formatters.
- Create `packages/zigeffect/tools/workflow_tool_support.zig`
  - Owns CLI args, fixture loading, file journal loading, output format parsing,
    and selected execution parsing shared by the three tools.
- Create `packages/zigeffect/tools/workflow_journal_inspect.zig`
  - Prints selected execution event history plus report metadata.
- Create `packages/zigeffect/tools/workflow_replay.zig`
  - Prints selected execution replay report.
- Create `packages/zigeffect/tools/workflow_list.zig`
  - Prints execution summaries.
- Modify `packages/zigeffect/build.zig`
  - Adds tool modules, executable steps, forwarded args, and tool tests.
- Modify `packages/zigeffect/test/workflow_test.zig`
  - Adds reusable module tests for reports and formatting.
- Create `packages/zigeffect/test/fixtures/workflow-journal.jsonl`
  - Stores a deterministic workflow journal fixture consumed by CLI build-step
    verification.
- Modify `packages/zigeffect/docs/architecture.md`
  - Documents workflow inspection ownership.
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
  - Marks Milestone 18 complete after verification.

## Task 1: Inspection Report Core

**Files:**
- Create `packages/zigeffect/src/workflow/inspect.zig`
- Modify `packages/zigeffect/src/workflow/root.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [x] **Step 1: Write failing report test**

Add a test named `workflow inspector summarizes replay state and pending work`.
Build fixture events with one running workflow, one scheduled timer, one
awaited deferred, one offered queue, one scheduled activity, and one failed
step. Assert the report has event count `7`, one execution summary, pending
counts of `1` for each durable work type, and last failure detail
`exit.cause.failure:Boom`.

- [x] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL because `fx.workflow.inspectExecution` and report types do not
exist.

- [x] **Step 3: Implement report structs and grouping**

Add these public types to `workflow/inspect.zig`:

```zig
pub const WorkflowReportError = error{
    EmptyWorkflowJournal,
    AmbiguousWorkflowExecution,
    UnknownWorkflowExecution,
};

pub const WorkflowExecutionKey = struct {
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
};

pub const WorkflowExecutionSummary = struct {
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    name: []const u8 = "",
    status: []const u8 = "",
    first_sequence: JournalSequence,
    last_sequence: JournalSequence,
    event_count: usize,
};

pub const WorkflowPendingSummary = struct {
    activities: []replay_mod.ActivityState,
    timers: []replay_mod.TimerState,
    deferreds: []replay_mod.DeferredState,
    queues: []replay_mod.QueueState,
};

pub const WorkflowInspectionReport = struct {
    allocator: Allocator,
    schema: []const u8,
    schema_version: u32,
    event_count: usize,
    first_sequence: ?JournalSequence,
    last_sequence: ?JournalSequence,
    executions: []WorkflowExecutionSummary,
    selected: ?WorkflowExecutionKey,
    state: ?replay_mod.WorkflowReplayState,
    pending: WorkflowPendingSummary,
    last_failure_detail: []const u8 = "",

    pub fn deinit(self: *WorkflowInspectionReport) void {
        for (self.executions) |summary| {
            if (summary.name.len != 0) self.allocator.free(summary.name);
            if (summary.status.len != 0) self.allocator.free(summary.status);
        }
        self.allocator.free(self.executions);
        if (self.state) |*state| state.deinit();
        self.allocator.free(self.pending.activities);
        self.allocator.free(self.pending.timers);
        self.allocator.free(self.pending.deferreds);
        self.allocator.free(self.pending.queues);
        if (self.last_failure_detail.len != 0) {
            self.allocator.free(self.last_failure_detail);
        }
    }
};
```

Implement:

```zig
pub fn listExecutions(allocator: Allocator, events: []const WorkflowEvent) !WorkflowInspectionReport
pub fn inspectExecution(allocator: Allocator, events: []const WorkflowEvent, selection: ?WorkflowExecutionKey) !WorkflowInspectionReport
```

The implementation filters events by selected key, folds them with
`WorkflowReplayState.fold`, copies pending rows out of the replay state, and
stores owned names/details so callers can free reports deterministically.

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 2: Text And JSON Formatting

**Files:**
- Modify `packages/zigeffect/src/workflow/inspect.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [x] **Step 1: Write failing formatting tests**

Add tests named:

- `workflow inspector formats text report`
- `workflow inspector formats json report`

Assert the text contains:

```text
zigeffect workflow replay
workflow_id: 7
execution_id: 8
status: running
pending_timers: 1
last_failure: exit.cause.failure:Boom
```

Assert the JSON contains:

```json
{"schema":"zigeffect.workflow.replay.v1","schema_version":1
```

and fields for `pending_timers`, `pending_deferreds`, `pending_queues`,
`pending_activities`, and `last_failure_detail`.

- [x] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL because formatting functions do not exist.

- [x] **Step 3: Implement formatters**

Add:

```zig
pub const WorkflowReportFormat = enum { text, json };
pub fn formatReplayReportText(allocator: Allocator, report: *const WorkflowInspectionReport) ![]const u8
pub fn formatReplayReportJson(allocator: Allocator, report: *const WorkflowInspectionReport) ![]const u8
pub fn formatListReportText(allocator: Allocator, report: *const WorkflowInspectionReport) ![]const u8
pub fn formatListReportJson(allocator: Allocator, report: *const WorkflowInspectionReport) ![]const u8
pub fn formatInspectReportText(allocator: Allocator, report: *const WorkflowInspectionReport, events: []const WorkflowEvent) ![]const u8
pub fn formatInspectReportJson(allocator: Allocator, report: *const WorkflowInspectionReport, events: []const WorkflowEvent) ![]const u8
```

Use `journal_mod.workflowEventKindName` and the existing JSON string escaping
pattern from `journal.zig`.

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 3: Shared CLI Loading Support

**Files:**
- Create `packages/zigeffect/tools/workflow_tool_support.zig`

- [x] **Step 1: Write failing support tests**

Add inline tests in `workflow_tool_support.zig`:

- `workflow tool args parse fixture input and json format`
- `workflow tool args reject conflicting inputs`
- `workflow tool fixture loader parses json lines`

Use a temporary fixture containing two workflow event JSON rows generated with
`fx.workflow.formatWorkflowEventJson`.

- [x] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build examples --summary all
```

Expected: FAIL after the tool module is wired into `build.zig` tests, because
support code does not exist yet.

- [x] **Step 3: Implement support module**

Add:

```zig
pub const WorkflowToolInput = union(enum) {
    fixture: []const u8,
    journal_dir: []const u8,
};

pub const WorkflowToolArgs = struct {
    input: WorkflowToolInput,
    format: fx.workflow.WorkflowReportFormat = .text,
    selection: ?fx.workflow.WorkflowExecutionKey = null,
};

pub const WorkflowToolError = error{
    MissingWorkflowJournalInput,
    ConflictingWorkflowJournalInput,
    InvalidWorkflowReportFormat,
    MissingWorkflowSelectionValue,
};

pub fn parseArgs(allocator: std.mem.Allocator, args: []const []const u8) !WorkflowToolArgs
pub fn loadEvents(allocator: std.mem.Allocator, io: std.Io, input: WorkflowToolInput) !fx.workflow.JournalEventBatch
```

`loadEvents` reads fixtures line-by-line with `parseWorkflowEventJson` and opens
real journal directories with `FileJournalStore.open`.

- [x] **Step 4: Verify green**

Run:

```bash
cd packages/zigeffect && zig build examples --summary all
```

Expected: PASS.

## Task 4: CLI Entrypoints And Build Steps

**Files:**
- Create `packages/zigeffect/tools/workflow_journal_inspect.zig`
- Create `packages/zigeffect/tools/workflow_replay.zig`
- Create `packages/zigeffect/tools/workflow_list.zig`
- Modify `packages/zigeffect/build.zig`

- [ ] **Step 1: Write failing build-step tests**

Wire tool modules into `build.zig` with tests first, then run:

```bash
cd packages/zigeffect && zig build workflow-list -- --fixture .zig-cache/missing.jsonl
```

Expected: FAIL because entrypoint modules are not implemented.

- [ ] **Step 2: Implement entrypoints**

Each entrypoint follows the existing tool shape:

```zig
pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const report = try runReplay(allocator, init.io, args[1..]);
    defer allocator.free(report);
    std.debug.print("{s}", .{report});
}
```

`workflow-list` calls `runList`, `workflow-replay` calls `runReplay`, and
`workflow-journal-inspect` calls `runInspect`.

- [ ] **Step 3: Add build steps**

Add module/executable/test definitions for:

```zig
workflow-journal-inspect
workflow-replay
workflow-list
```

Each run artifact forwards `b.args`.

- [ ] **Step 4: Verify build steps compile**

Run:

```bash
cd packages/zigeffect && zig build workflow-list -- --fixture .zig-cache/missing.jsonl
cd packages/zigeffect && zig build workflow-replay -- --fixture .zig-cache/missing.jsonl
cd packages/zigeffect && zig build workflow-journal-inspect -- --fixture .zig-cache/missing.jsonl
```

Expected: each command reaches fixture file loading and fails with
`FileNotFound`, proving the build step and CLI entrypoint compile.

## Task 5: Fixture And File-Journal CLI Coverage

**Files:**
- Modify `packages/zigeffect/tools/workflow_journal_inspect.zig`
- Modify `packages/zigeffect/tools/workflow_replay.zig`
- Modify `packages/zigeffect/tools/workflow_list.zig`
- Modify `packages/zigeffect/tools/workflow_tool_support.zig`
- Create `packages/zigeffect/test/fixtures/workflow-journal.jsonl`

- [ ] **Step 1: Write failing inline CLI tests**

Add tests that call public helper functions rather than spawning subprocesses:

```zig
pub fn runList(allocator: std.mem.Allocator, io: std.Io, args: []const []const u8) ![]const u8
pub fn runReplay(allocator: std.mem.Allocator, io: std.Io, args: []const []const u8) ![]const u8
pub fn runInspect(allocator: std.mem.Allocator, io: std.Io, args: []const []const u8) ![]const u8
```

Tests create a fixture JSONL file and a real `FileJournalStore` temp directory,
then assert text and JSON output for all three commands.

Create `packages/zigeffect/test/fixtures/workflow-journal.jsonl` with
newline-delimited rows generated by `formatWorkflowEventJson` for the same
single-execution fixture. The final full gate uses that file as a stable CLI
input.

- [ ] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL until helper functions and support coverage are implemented.

- [ ] **Step 3: Implement run helpers**

Make `main` call the same `run*` helper used by tests. Keep stdout-only
formatting inside entrypoints; keep data loading in `workflow_tool_support.zig`.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 6: Docs, Roadmap, Full Gate, And Commit

**Files:**
- Modify `packages/zigeffect/docs/architecture.md`
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
- Add `docs/superpowers/specs/2026-06-09-zigeffect-workflow-inspector-cli-design.md`
- Add `docs/superpowers/plans/2026-06-09-zigeffect-workflow-inspector-cli.md`

- [ ] **Step 1: Update architecture docs**

Document `workflow/inspect.zig` and workflow CLI tool ownership.

- [ ] **Step 2: Run full gate**

Run:

```bash
bun run zigeffect:test
cd packages/zigeffect && zig build workflow-list -- --fixture test/fixtures/workflow-journal.jsonl
cd packages/zigeffect && zig build workflow-replay -- --fixture test/fixtures/workflow-journal.jsonl
cd packages/zigeffect && zig build workflow-journal-inspect -- --fixture test/fixtures/workflow-journal.jsonl
cd packages/zigeffect && zig build examples
bun run zig:test
zig fmt --check packages/zigeffect/src/workflow/inspect.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/tools/workflow_tool_support.zig packages/zigeffect/tools/workflow_journal_inspect.zig packages/zigeffect/tools/workflow_replay.zig packages/zigeffect/tools/workflow_list.zig packages/zigeffect/build.zig packages/zigeffect/test/workflow_test.zig
git diff --check
rg -n 'T''BD|TO''DO|implement la''ter|fill in de''tails|appropriate error hand''ling|handle edge ca''ses|Similar to Ta''sk|deferred bu''cket|par''ked' packages/zigeffect/src/workflow packages/zigeffect/tools packages/zigeffect/test/workflow_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/specs/2026-06-09-zigeffect-workflow-inspector-cli-design.md docs/superpowers/plans/2026-06-09-zigeffect-workflow-inspector-cli.md
```

Expected: compile/test commands PASS, workflow commands print reports for the
fixture, format and diff checks exit 0, and the placeholder scan exits 1 with no
matches.

- [ ] **Step 3: Mark Milestone 18 complete**

After the full gate passes, mark all Milestone 18 deliverables and acceptance
boxes complete in
`docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`.

- [ ] **Step 4: Commit**

Run:

```bash
git add docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md docs/superpowers/plans/2026-06-09-zigeffect-workflow-inspector-cli.md docs/superpowers/specs/2026-06-09-zigeffect-workflow-inspector-cli-design.md packages/zigeffect/docs/architecture.md packages/zigeffect/src/workflow/inspect.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/tools/workflow_tool_support.zig packages/zigeffect/tools/workflow_journal_inspect.zig packages/zigeffect/tools/workflow_replay.zig packages/zigeffect/tools/workflow_list.zig packages/zigeffect/build.zig packages/zigeffect/test/workflow_test.zig packages/zigeffect/test/fixtures/workflow-journal.jsonl
git commit -m "feat(zigeffect): add workflow inspector cli"
```
