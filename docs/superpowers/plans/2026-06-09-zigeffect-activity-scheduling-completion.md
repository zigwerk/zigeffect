# zigeffect Activity Scheduling And Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add durable activity scheduling, completion, failure replay, attempt counters, and result serialization to `WorkflowContext`.

**Architecture:** Extend the journal with a first-class `attempt` field before changing context behavior. Then add a generic `WorkflowContext.activity` API that derives activity identity from the activity definition's idempotency key, journals scheduled/started/completed/failed rows, and replays terminal outcomes without invoking the activity function.

**Tech Stack:** Zig 0.16, existing `Activity`, existing `WorkflowContext`, existing `Codec`, existing journal store/replay/checkpoint modules, `bun:test` project scripts.

---

## File Structure

- Modify `packages/zigeffect/src/workflow/journal.zig`
  - Add `WorkflowEvent.attempt`, JSON parsing/formatting, and text formatting.
- Modify `packages/zigeffect/src/workflow/replay.zig`
  - Add `ActivityState.attempt` and preserve attempts during activity lifecycle folding.
- Modify `packages/zigeffect/src/workflow/store.zig`
  - Include activity attempts in checkpoint JSON formatting and parsing.
- Modify `packages/zigeffect/src/workflow/context.zig`
  - Add `WorkflowContext.activity`, activity id derivation, activity lifecycle appends, success replay, and typed failure replay.
- Modify `packages/zigeffect/src/workflow/root.zig`
  - Expose `activityId` if tests and users need stable activity id derivation.
- Modify `packages/zigeffect/test/workflow_test.zig`
  - Add attempt serialization tests, replay attempt tests, activity success replay tests, and activity failure replay tests.
- Modify `packages/zigeffect/docs/architecture.md`
  - Document activity calls under `workflow/context.zig`.
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
  - Mark Milestone 10 complete after the full gate.

## Task 1: Journal And Replay Attempts

**Files:**
- Modify `packages/zigeffect/src/workflow/journal.zig`
- Modify `packages/zigeffect/src/workflow/replay.zig`
- Modify `packages/zigeffect/src/workflow/store.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [x] **Step 1: Write failing attempt serialization tests**

Add assertions to the existing workflow event JSON/text tests:

```zig
const event = fx.workflow.WorkflowEvent{
    .sequence = 1,
    .kind = .activity_completed,
    .workflow_id = 7,
    .execution_id = 8,
    .activity_id = 9,
    .attempt = 2,
    .name = "charge-card",
    .status = "success",
    .redacted_detail = "ok",
    .idempotency_key = "event-1",
};

try std.testing.expect(std.mem.indexOf(u8, json, "\"attempt\":2") != null);
try std.testing.expect(std.mem.indexOf(u8, text, "attempt: 2") != null);
try std.testing.expectEqual(event.attempt, parsed.attempt);
```

Add attempt assertions to replay and checkpoint tests:

```zig
.{ .sequence = 2, .kind = .activity_scheduled, .workflow_id = 7, .execution_id = 8, .activity_id = 10, .attempt = 1, .name = "charge" },
.{ .sequence = 4, .kind = .activity_completed, .workflow_id = 7, .execution_id = 8, .activity_id = 10, .attempt = 1 },

try std.testing.expectEqual(@as(u32, 1), state.activities.items[0].attempt);
try std.testing.expect(std.mem.indexOf(u8, checkpoint_json, "\"attempt\":1") != null);
try std.testing.expectEqual(@as(u32, 1), parsed.activities.items[0].attempt);
```

- [x] **Step 2: Verify red**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL with missing `attempt` field/member errors.

- [x] **Step 3: Implement journal attempt field**

In `WorkflowEvent`, add:

```zig
attempt: u32 = 0,
```

In the JSON row struct, add:

```zig
attempt: u32 = 0,
```

Set `.attempt = parsed.value.attempt` in `parseWorkflowEventJson`, append
`"attempt"` in `formatWorkflowEventJson`, and append `attempt: {d}` in
`formatWorkflowEventText`.

- [x] **Step 4: Implement replay and checkpoint attempt preservation**

In `ActivityState`, add:

```zig
attempt: u32 = 0,
```

Set the scheduled state attempt from `event.attempt`. In `updateActivity`, copy
`event.attempt` into the state when the event attempt is non-zero.

In `ActivityCheckpointRow`, add:

```zig
attempt: u32 = 0,
```

Write `"attempt":{d}` in `appendActivityCheckpointRows` and read `.attempt =
row.attempt` in `parseWorkflowCheckpointJson`.

- [x] **Step 5: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 2: Activity Success Scheduling And Replay

**Files:**
- Modify `packages/zigeffect/src/workflow/context.zig`
- Modify `packages/zigeffect/src/workflow/root.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [x] **Step 1: Write failing activity success replay test**

Add this test shape to `workflow_test.zig`:

```zig
test "workflow context records and replays successful u64 activities" {
    const Payload = struct { account_id: u64 };
    const Charge = fx.workflow.Activity("charge", Payload, u64, error{Declined}, void).withIdempotencyKey(struct {
        fn key(allocator: std.mem.Allocator, payload: Payload) ![]const u8 {
            return std.fmt.allocPrint(allocator, "charge:{d}", .{payload.account_id});
        }
    }.key);
    const U64Codec = fx.Codec(u64);
    const codec = U64Codec{
        .encode = struct {
            fn encode(allocator: std.mem.Allocator, value: u64) ![]const u8 {
                return std.fmt.allocPrint(allocator, "{d}", .{value});
            }
        }.encode,
        .decode = struct {
            fn decode(_: std.mem.Allocator, bytes: []const u8) !u64 {
                return std.fmt.parseInt(u64, bytes, 10);
            }
        }.decode,
    };
    const Runner = struct {
        var calls: u64 = 0;
        fn run(payload: Payload) error{Declined}!u64 {
            calls += 1;
            return payload.account_id + 99;
        }
    };
    Runner.calls = 0;

    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();
    _ = try journal.append(.{ .event = .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8, .name = "stepper", .status = "running", .idempotency_key = "activity-success" } });

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{ .workflow_id = 7, .execution_id = 8 });
        defer context.deinit();
        const value = try context.activity(Charge, .{ .account_id = 5 }, codec, Runner.run);
        try std.testing.expectEqual(@as(u64, 104), value);
        try std.testing.expectEqual(@as(u64, 1), Runner.calls);
    }

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{ .workflow_id = 7, .execution_id = 8 });
        defer context.deinit();
        const value = try context.activity(Charge, .{ .account_id = 5 }, codec, Runner.run);
        try std.testing.expectEqual(@as(u64, 104), value);
        try std.testing.expectEqual(@as(u64, 1), Runner.calls);
    }

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 4), events.events.len);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.activity_scheduled, events.events[1].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.activity_started, events.events[2].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.activity_completed, events.events[3].kind);
    try std.testing.expectEqual(@as(u32, 1), events.events[3].attempt);
    try std.testing.expectEqualStrings("104", events.events[3].redacted_detail);
}
```

- [x] **Step 2: Verify red**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL because `WorkflowContext.activity` does not exist.

- [x] **Step 3: Implement activity identity and success replay**

In `context.zig`, import `traits/root.zig` and expose:

```zig
pub const ActivityId = journal_mod.ActivityId;
pub const Codec = traits_mod.Codec;

pub fn activityId(activity_name: []const u8, idempotency_key: []const u8) ActivityId {
    var hasher = std.hash.Fnv1a_64.init();
    hasher.update(activity_name);
    hasher.update(":");
    hasher.update(idempotency_key);
    return hasher.final();
}
```

Add `WorkflowContext.activity`:

```zig
pub fn activity(
    self: *WorkflowContext,
    comptime ActivityType: type,
    payload: ActivityType.PayloadType,
    result_codec: Codec(ActivityType.SuccessType),
    comptime run_fn: anytype,
) !ActivityType.SuccessType {
    assertActivityFailureIsErrorSet(ActivityType.FailureType);
    const logical_key = try ActivityType.idempotencyKey(self.allocator, payload);
    defer self.allocator.free(logical_key);
    const id = activityId(ActivityType.name, logical_key);

    if (try self.recordedActivity(ActivityType, id, result_codec)) |recorded| {
        return switch (recorded) {
            .completed => |value| value,
            .failed => |err| err,
        };
    }

    const attempt: u32 = 1;
    try self.appendActivityEvent(.activity_scheduled, id, ActivityType.name, attempt, "scheduled", "");
    try self.appendActivityEvent(.activity_started, id, ActivityType.name, attempt, "running", "");
    const value = try run_fn(payload);
    const encoded = try result_codec.encodeValue(self.allocator, value);
    defer self.allocator.free(encoded);
    try self.appendActivityEvent(.activity_completed, id, ActivityType.name, attempt, "completed", encoded);
    return value;
}
```

Add helpers `ActivityReplay`, `recordedActivity`, `appendActivityEvent`, and
`activityEventIdempotencyKey` so completed results decode from
`redacted_detail` and each lifecycle row has a distinct idempotency key.

Expose `activityId` from `workflow/root.zig`.

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 3: Activity Failure Scheduling And Replay

**Files:**
- Modify `packages/zigeffect/src/workflow/context.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [x] **Step 1: Write failing activity failure replay test**

Add a test where `Runner.run` returns `error.Declined`. The first call should
record `activity_failed`, return `error.Declined`, and increment calls to `1`.
The replay call should return `error.Declined` again while calls remain `1`.

Assert the failed row:

```zig
try std.testing.expectEqual(fx.workflow.WorkflowEventKind.activity_failed, events.events[3].kind);
try std.testing.expectEqual(@as(u32, 1), events.events[3].attempt);
try std.testing.expectEqualStrings("failed", events.events[3].status);
try std.testing.expectEqualStrings("exit.cause.failure:Declined", events.events[3].redacted_detail);
```

- [x] **Step 2: Verify red**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL because failed activities are not yet recorded or replayed.

- [x] **Step 3: Implement typed activity failure detail and replay**

In `WorkflowContext.activity`, wrap the runner call:

```zig
const value = run_fn(payload) catch |err| {
    const detail = try workflowStepFailureDetail(self.allocator, err);
    defer self.allocator.free(detail);
    try self.appendActivityEvent(.activity_failed, id, ActivityType.name, attempt, "failed", detail);
    return err;
};
```

Add a recorded failure parser:

```zig
fn errorFromName(comptime ErrorSet: type, name: []const u8) ?ErrorSet {
    switch (@typeInfo(ErrorSet)) {
        .error_set => |maybe_errors| {
            const errors = maybe_errors orelse return null;
            inline for (errors) |err| {
                if (std.mem.eql(u8, err.name, name)) return @field(anyerror, err.name);
            }
            return null;
        },
        else => return null,
    }
}
```

`recordedActivity` should parse `exit.cause.failure:` details and return the
matching `ActivityType.FailureType` error when present.

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 4: Docs, Roadmap, Full Gate, And Commit

**Files:**
- Modify `packages/zigeffect/docs/architecture.md`
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
- Add `docs/superpowers/specs/2026-06-09-zigeffect-activity-scheduling-completion-design.md`
- Add `docs/superpowers/plans/2026-06-09-zigeffect-activity-scheduling-completion.md`

- [x] **Step 1: Update architecture docs**

Update the `src/workflow/` section so `context.zig` mentions durable activity
scheduling, result codecs, attempt counters, and replayed terminal outcomes.

- [x] **Step 2: Run full gate**

Run:

```bash
bun run zigeffect:test
cd packages/zigeffect && zig build examples
bun run zig:test
git diff --check
rg -n 'T''BD|TO''DO|implement la''ter|fill in de''tails|appropriate error hand''ling|handle edge ca''ses|Similar to Ta''sk|deferred bu''cket|par''ked' packages/zigeffect/src/workflow packages/zigeffect/test/workflow_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/specs/2026-06-09-zigeffect-activity-scheduling-completion-design.md docs/superpowers/plans/2026-06-09-zigeffect-activity-scheduling-completion.md
```

Expected: compile/test commands PASS, `git diff --check` exits 0, and the
placeholder scan exits 1 with no matches.

- [x] **Step 3: Mark Milestone 10 complete**

After the full gate passes, mark all Milestone 10 deliverables and acceptance
boxes complete in
`docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`.

- [x] **Step 4: Commit**

```bash
git add packages/zigeffect/src/workflow/context.zig packages/zigeffect/src/workflow/journal.zig packages/zigeffect/src/workflow/replay.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/src/workflow/store.zig packages/zigeffect/test/workflow_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/specs/2026-06-09-zigeffect-activity-scheduling-completion-design.md docs/superpowers/plans/2026-06-09-zigeffect-activity-scheduling-completion.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
git commit -m "feat(zigeffect): add durable activity scheduling"
```

## Self-Review Checklist

- [x] Attempts are first-class fields, not string-only metadata.
- [x] Completed activity replay decodes through `Codec`.
- [x] Failed activity replay returns the declared activity error-set value.
- [x] Replaying terminal activity outcomes does not invoke the runner.
- [x] Lifecycle rows use deterministic sequence assignment.
- [x] No retries, timers, compensation, workers, or clustering are added in this milestone.
