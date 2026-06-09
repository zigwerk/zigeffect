# zigeffect Workflow Journal Event Model Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the first durable workflow journal event vocabulary, ids, envelope, and formatters.

**Architecture:** Implement a storage-agnostic `workflow/journal.zig` module and export it through `fx.workflow`. Keep this milestone limited to event facts and formatting; replay, stores, and workflow execution land in later milestones.

**Tech Stack:** Zig 0.16, existing zigeffect workflow namespace, `std.ArrayList`, `std.fmt`, `bun run zigeffect:test`.

---

## File Structure

- Create `packages/zigeffect/src/workflow/journal.zig`
  - Owns id aliases, schema constants, event kind names, `WorkflowEvent`, and
    JSON/text formatters.
- Modify `packages/zigeffect/src/workflow/root.zig`
  - Exposes journal names under `fx.workflow`.
- Create `packages/zigeffect/test/workflow_test.zig`
  - Tests event taxonomy and formatters.
- Modify `packages/zigeffect/test/all_test.zig`
  - Imports `workflow_test.zig`.
- Modify `packages/zigeffect/test/architecture_test.zig`
  - Verifies workflow journal facade exposure.
- Modify `packages/zigeffect/docs/architecture.md`
  - Documents `workflow/journal.zig`.
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
  - Marks Milestone 2 complete after verification.

## Task 1: Event Kinds And Id Types

**Files:**
- Create: `packages/zigeffect/test/workflow_test.zig`
- Modify: `packages/zigeffect/test/all_test.zig`
- Modify: `packages/zigeffect/test/architecture_test.zig`
- Create: `packages/zigeffect/src/workflow/journal.zig`
- Modify: `packages/zigeffect/src/workflow/root.zig`

- [ ] **Step 1: Write failing event-kind tests**

Create `workflow_test.zig` with tests for id aliases, schema constants, and
every event kind string:

```zig
const std = @import("std");
const fx = @import("zigeffect");

test "workflow journal schema constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.workflow.journal-event.v1", fx.workflow.workflow_journal_event_schema);
    try std.testing.expectEqual(@as(u32, 1), fx.workflow.workflow_journal_event_schema_version);
}

test "workflow journal ids are u64 aliases" {
    try std.testing.expect(fx.workflow.WorkflowId == u64);
    try std.testing.expect(fx.workflow.ExecutionId == u64);
    try std.testing.expect(fx.workflow.ActivityId == u64);
    try std.testing.expect(fx.workflow.TimerId == u64);
    try std.testing.expect(fx.workflow.DeferredId == u64);
    try std.testing.expect(fx.workflow.QueueId == u64);
    try std.testing.expect(fx.workflow.JournalSequence == u64);
}

test "workflow event kind names are stable" {
    const cases = .{
        .{ fx.workflow.WorkflowEventKind.workflow_started, "workflow_started" },
        .{ fx.workflow.WorkflowEventKind.workflow_suspended, "workflow_suspended" },
        .{ fx.workflow.WorkflowEventKind.workflow_resumed, "workflow_resumed" },
        .{ fx.workflow.WorkflowEventKind.workflow_completed, "workflow_completed" },
        .{ fx.workflow.WorkflowEventKind.workflow_failed, "workflow_failed" },
        .{ fx.workflow.WorkflowEventKind.workflow_interrupted, "workflow_interrupted" },
        .{ fx.workflow.WorkflowEventKind.workflow_cancelled, "workflow_cancelled" },
        .{ fx.workflow.WorkflowEventKind.activity_scheduled, "activity_scheduled" },
        .{ fx.workflow.WorkflowEventKind.activity_started, "activity_started" },
        .{ fx.workflow.WorkflowEventKind.activity_completed, "activity_completed" },
        .{ fx.workflow.WorkflowEventKind.activity_failed, "activity_failed" },
        .{ fx.workflow.WorkflowEventKind.timer_scheduled, "timer_scheduled" },
        .{ fx.workflow.WorkflowEventKind.timer_fired, "timer_fired" },
        .{ fx.workflow.WorkflowEventKind.timer_cancelled, "timer_cancelled" },
        .{ fx.workflow.WorkflowEventKind.deferred_created, "deferred_created" },
        .{ fx.workflow.WorkflowEventKind.deferred_awaited, "deferred_awaited" },
        .{ fx.workflow.WorkflowEventKind.deferred_completed, "deferred_completed" },
        .{ fx.workflow.WorkflowEventKind.deferred_failed, "deferred_failed" },
        .{ fx.workflow.WorkflowEventKind.deferred_cancelled, "deferred_cancelled" },
        .{ fx.workflow.WorkflowEventKind.queue_offered, "queue_offered" },
        .{ fx.workflow.WorkflowEventKind.queue_claimed, "queue_claimed" },
        .{ fx.workflow.WorkflowEventKind.queue_completed, "queue_completed" },
        .{ fx.workflow.WorkflowEventKind.queue_failed, "queue_failed" },
        .{ fx.workflow.WorkflowEventKind.queue_acked, "queue_acked" },
        .{ fx.workflow.WorkflowEventKind.signal_received, "signal_received" },
        .{ fx.workflow.WorkflowEventKind.signal_consumed, "signal_consumed" },
    };

    inline for (cases) |case| {
        try std.testing.expectEqualStrings(case[1], fx.workflow.workflowEventKindName(case[0]));
    }
}
```

Import `workflow_test.zig` from `all_test.zig`. Add architecture assertions:

```zig
try std.testing.expect(@hasDecl(fx.workflow, "journal"));
try std.testing.expect(fx.workflow.WorkflowEvent == fx.workflow.journal.WorkflowEvent);
```

- [ ] **Step 2: Verify red**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL because `workflow.journal` and event types do not exist.

- [ ] **Step 3: Implement event kinds and id types**

Create `workflow/journal.zig` with schema constants, id aliases,
`WorkflowEventKind`, and `workflowEventKindName`. Export names from
`workflow/root.zig`.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 2: Event Envelope And Formatters

**Files:**
- Modify: `packages/zigeffect/test/workflow_test.zig`
- Modify: `packages/zigeffect/src/workflow/journal.zig`

- [ ] **Step 1: Write failing formatter tests**

Add tests:

```zig
test "workflow event json includes schema metadata and optional ids" {
    const event = fx.workflow.WorkflowEvent{
        .sequence = 1,
        .kind = .activity_completed,
        .workflow_id = 7,
        .execution_id = 8,
        .activity_id = 9,
        .name = "charge-card",
        .status = "success",
        .redacted_detail = "ok",
    };

    const json = try fx.workflow.formatWorkflowEventJson(std.testing.allocator, event);
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema\":\"zigeffect.workflow.journal-event.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema_version\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"sequence\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"kind\":\"activity_completed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"workflow_id\":7") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"execution_id\":8") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"activity_id\":9") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"timer_id\":null") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"name\":\"charge-card\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"status\":\"success\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"redacted_detail\":\"ok\"") != null);
}

test "workflow event text is readable for agents and CLIs" {
    const event = fx.workflow.WorkflowEvent{
        .sequence = 2,
        .kind = .timer_scheduled,
        .workflow_id = 7,
        .execution_id = 8,
        .timer_id = 10,
        .name = "wake-up",
        .status = "scheduled",
    };

    const text = try fx.workflow.formatWorkflowEventText(std.testing.allocator, event);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "zigeffect workflow journal event") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "kind: timer_scheduled") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "timer_id: 10") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "name: wake-up") != null);
}
```

- [ ] **Step 2: Verify red**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL because `WorkflowEvent` and formatter functions are missing.

- [ ] **Step 3: Implement envelope and formatters**

Add `WorkflowEvent`, optional number JSON/text helpers, JSON string escaping,
`formatWorkflowEventJson`, and `formatWorkflowEventText`.

- [ ] **Step 4: Verify full gate**

Run:

```bash
bun run zigeffect:test
cd packages/zigeffect && zig build examples
bun run zig:test
```

Expected: all commands PASS.

## Task 3: Docs, Roadmap, And Commit

**Files:**
- Modify: `packages/zigeffect/docs/architecture.md`
- Modify: `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
- Add: `docs/superpowers/specs/2026-06-09-zigeffect-workflow-journal-event-model-design.md`
- Add: `docs/superpowers/plans/2026-06-09-zigeffect-workflow-journal-event-model.md`

- [ ] **Step 1: Update architecture docs**

Add `journal.zig` to the `src/workflow/` section as the owner of id aliases,
event kinds, event envelope, schema constants, and formatters.

- [ ] **Step 2: Mark Milestone 2 complete**

Mark all Milestone 2 deliverables and acceptance boxes in the durable workflows
and clustering roadmap after verification.

- [ ] **Step 3: Run diff checks**

Run:

```bash
git diff --check
```

Expected: PASS with no output.

- [ ] **Step 4: Commit**

```bash
git add packages/zigeffect/src/workflow/journal.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/test/workflow_test.zig packages/zigeffect/test/all_test.zig packages/zigeffect/test/architecture_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/specs/2026-06-09-zigeffect-workflow-journal-event-model-design.md docs/superpowers/plans/2026-06-09-zigeffect-workflow-journal-event-model.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
git commit -m "feat(zigeffect): add workflow journal event model"
```

## Self-Review Checklist

- [ ] Every event kind in the spec has a stable name test.
- [ ] Formatter output includes schema metadata.
- [ ] No parser, journal store, replay fold, workflow engine, or activity runner is added.
- [ ] `bun run zigeffect:test`, `zig build examples`, and `bun run zig:test` pass before Milestone 2 is marked complete.
