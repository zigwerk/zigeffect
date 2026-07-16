const std = @import("std");
const fx = @import("zigeffect");

fn expectWorkflowReplayStatesEqual(expected: *const fx.workflow.WorkflowReplayState, actual: *const fx.workflow.WorkflowReplayState) !void {
    try std.testing.expectEqual(expected.workflow_status, actual.workflow_status);
    try std.testing.expectEqual(expected.workflow_id, actual.workflow_id);
    try std.testing.expectEqual(expected.execution_id, actual.execution_id);
    try std.testing.expectEqual(expected.last_sequence, actual.last_sequence);

    try std.testing.expectEqual(expected.activities.items.len, actual.activities.items.len);
    for (expected.activities.items, actual.activities.items) |expected_row, actual_row| {
        try std.testing.expectEqual(expected_row.id, actual_row.id);
        try std.testing.expectEqual(expected_row.status, actual_row.status);
        try std.testing.expectEqual(expected_row.last_sequence, actual_row.last_sequence);
        try std.testing.expectEqual(expected_row.attempt, actual_row.attempt);
        try std.testing.expectEqualStrings(expected_row.name, actual_row.name);
    }

    try std.testing.expectEqual(expected.timers.items.len, actual.timers.items.len);
    for (expected.timers.items, actual.timers.items) |expected_row, actual_row| {
        try std.testing.expectEqual(expected_row.id, actual_row.id);
        try std.testing.expectEqual(expected_row.status, actual_row.status);
        try std.testing.expectEqual(expected_row.last_sequence, actual_row.last_sequence);
        try std.testing.expectEqualStrings(expected_row.name, actual_row.name);
    }

    try std.testing.expectEqual(expected.deferreds.items.len, actual.deferreds.items.len);
    for (expected.deferreds.items, actual.deferreds.items) |expected_row, actual_row| {
        try std.testing.expectEqual(expected_row.id, actual_row.id);
        try std.testing.expectEqual(expected_row.status, actual_row.status);
        try std.testing.expectEqual(expected_row.last_sequence, actual_row.last_sequence);
        try std.testing.expectEqualStrings(expected_row.name, actual_row.name);
    }

    try std.testing.expectEqual(expected.queues.items.len, actual.queues.items.len);
    for (expected.queues.items, actual.queues.items) |expected_row, actual_row| {
        try std.testing.expectEqual(expected_row.id, actual_row.id);
        try std.testing.expectEqual(expected_row.status, actual_row.status);
        try std.testing.expectEqual(expected_row.last_sequence, actual_row.last_sequence);
        try std.testing.expectEqualStrings(expected_row.name, actual_row.name);
    }

    try std.testing.expectEqual(expected.compensations.items.len, actual.compensations.items.len);
    for (expected.compensations.items, actual.compensations.items) |expected_row, actual_row| {
        try std.testing.expectEqual(expected_row.id, actual_row.id);
        try std.testing.expectEqual(expected_row.status, actual_row.status);
        try std.testing.expectEqual(expected_row.last_sequence, actual_row.last_sequence);
        try std.testing.expectEqualStrings(expected_row.name, actual_row.name);
    }
}

fn workflowInspectorFixtureEvents() [7]fx.workflow.WorkflowEvent {
    return .{
        .{
            .sequence = 1,
            .kind = .workflow_started,
            .workflow_id = 7,
            .execution_id = 8,
            .name = "inspected-workflow",
            .status = "running",
            .idempotency_key = "inspect-start",
        },
        .{
            .sequence = 2,
            .kind = .timer_scheduled,
            .workflow_id = 7,
            .execution_id = 8,
            .timer_id = 20,
            .name = "wake",
            .idempotency_key = "inspect-timer",
        },
        .{
            .sequence = 3,
            .kind = .deferred_created,
            .workflow_id = 7,
            .execution_id = 8,
            .deferred_id = 30,
            .name = "approval",
            .idempotency_key = "inspect-deferred-create",
        },
        .{
            .sequence = 4,
            .kind = .deferred_awaited,
            .workflow_id = 7,
            .execution_id = 8,
            .deferred_id = 30,
            .name = "approval",
            .idempotency_key = "inspect-deferred-await",
        },
        .{
            .sequence = 5,
            .kind = .queue_offered,
            .workflow_id = 7,
            .execution_id = 8,
            .queue_id = 40,
            .name = "email",
            .idempotency_key = "inspect-queue",
        },
        .{
            .sequence = 6,
            .kind = .activity_scheduled,
            .workflow_id = 7,
            .execution_id = 8,
            .activity_id = 50,
            .attempt = 1,
            .name = "charge",
            .idempotency_key = "inspect-activity",
        },
        .{
            .sequence = 7,
            .kind = .step_failed,
            .workflow_id = 7,
            .execution_id = 8,
            .name = "boom",
            .status = "failed",
            .redacted_detail = "exit.cause.failure:Boom",
            .idempotency_key = "inspect-step-failed",
        },
    };
}

fn workflowCausalFixtureEvents() [5]fx.workflow.WorkflowEvent {
    return .{
        .{
            .sequence = 1,
            .kind = .workflow_started,
            .workflow_id = 7,
            .execution_id = 8,
            .name = "causal-workflow",
            .status = "running",
            .idempotency_key = "causal-start",
        },
        .{
            .sequence = 2,
            .kind = .workflow_suspended,
            .workflow_id = 7,
            .execution_id = 8,
            .parent_sequence = 1,
            .name = "wake",
            .status = "waiting",
            .redacted_detail = "timer",
            .idempotency_key = "causal-suspend",
        },
        .{
            .sequence = 3,
            .kind = .workflow_resumed,
            .workflow_id = 7,
            .execution_id = 8,
            .parent_sequence = 2,
            .name = "wake",
            .status = "running",
            .redacted_detail = "timer_fired",
            .idempotency_key = "causal-resume",
        },
        .{
            .sequence = 4,
            .kind = .activity_retry_scheduled,
            .workflow_id = 7,
            .execution_id = 8,
            .parent_sequence = 3,
            .activity_id = 50,
            .attempt = 2,
            .name = "charge",
            .status = "retry",
            .redacted_detail = "attempt=1;delay_ms=250;reason=retry",
            .idempotency_key = "causal-retry",
        },
        .{
            .sequence = 5,
            .kind = .workflow_failed,
            .workflow_id = 7,
            .execution_id = 8,
            .parent_sequence = 4,
            .name = "causal-workflow",
            .status = "failed",
            .redacted_detail = "exit.cause.failure:Boom",
            .idempotency_key = "causal-failed",
        },
    };
}

fn replaceFirstOwned(
    allocator: std.mem.Allocator,
    source: []const u8,
    needle: []const u8,
    replacement: []const u8,
) ![]const u8 {
    const index = std.mem.indexOf(u8, source, needle) orelse return error.ExpectedReplacementNeedle;
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, source[0..index]);
    try output.appendSlice(allocator, replacement);
    try output.appendSlice(allocator, source[index + needle.len ..]);

    return output.toOwnedSlice(allocator);
}

fn parseWorkflowJsonLines(
    allocator: std.mem.Allocator,
    content: []const u8,
) !fx.workflow.JournalEventBatch {
    var output = std.ArrayList(fx.workflow.WorkflowEvent).empty;
    errdefer {
        for (output.items) |event| fx.workflow.deinitWorkflowEventStrings(allocator, event);
        output.deinit(allocator);
    }

    var line_start: usize = 0;
    while (line_start <= content.len) {
        const newline_index = std.mem.indexOfScalarPos(u8, content, line_start, '\n') orelse content.len;
        const line = std.mem.trim(u8, content[line_start..newline_index], "\r");
        if (line.len != 0) {
            const event = try fx.workflow.parseWorkflowEventJson(allocator, line);
            errdefer fx.workflow.deinitWorkflowEventStrings(allocator, event);
            try output.append(allocator, event);
        }
        if (newline_index == content.len) break;
        line_start = newline_index + 1;
    }

    return .{ .allocator = allocator, .events = try output.toOwnedSlice(allocator) };
}

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
        .{ fx.workflow.WorkflowEventKind.activity_retry_scheduled, "activity_retry_scheduled" },
        .{ fx.workflow.WorkflowEventKind.activity_timed_out, "activity_timed_out" },
        .{ fx.workflow.WorkflowEventKind.compensation_registered, "compensation_registered" },
        .{ fx.workflow.WorkflowEventKind.compensation_started, "compensation_started" },
        .{ fx.workflow.WorkflowEventKind.compensation_completed, "compensation_completed" },
        .{ fx.workflow.WorkflowEventKind.compensation_failed, "compensation_failed" },
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
        .{ fx.workflow.WorkflowEventKind.queue_retry_scheduled, "queue_retry_scheduled" },
        .{ fx.workflow.WorkflowEventKind.queue_acked, "queue_acked" },
        .{ fx.workflow.WorkflowEventKind.step_started, "step_started" },
        .{ fx.workflow.WorkflowEventKind.step_completed, "step_completed" },
        .{ fx.workflow.WorkflowEventKind.step_failed, "step_failed" },
        .{ fx.workflow.WorkflowEventKind.signal_received, "signal_received" },
        .{ fx.workflow.WorkflowEventKind.signal_consumed, "signal_consumed" },
    };

    inline for (cases) |case| {
        try std.testing.expectEqualStrings(case[1], fx.workflow.workflowEventKindName(case[0]));
    }
}

test "workflow event json includes schema metadata and optional ids" {
    const event = fx.workflow.WorkflowEvent{
        .sequence = 1,
        .kind = .activity_completed,
        .workflow_id = 7,
        .execution_id = 8,
        .activity_id = 9,
        .compensation_id = 50,
        .attempt = 2,
        .name = "charge-card",
        .status = "success",
        .redacted_detail = "ok",
        .idempotency_key = "event-1",
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
    try std.testing.expect(std.mem.indexOf(u8, json, "\"compensation_id\":50") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"attempt\":2") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"timer_id\":null") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"name\":\"charge-card\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"status\":\"success\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"redacted_detail\":\"ok\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"idempotency_key\":\"event-1\"") != null);
}

test "workflow event json escapes control bytes" {
    const event = fx.workflow.WorkflowEvent{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .name = "ansi \x1b[31mred\x1b[0m workflow",
        .status = "running",
        .idempotency_key = "escape-start",
    };

    const json = try fx.workflow.formatWorkflowEventJson(std.testing.allocator, event);
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\\u001b") != null);
    try std.testing.expect(std.mem.indexOfScalar(u8, json, 0x1b) == null);

    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{});
    defer parsed.deinit();
    try std.testing.expectEqualStrings("ansi \x1b[31mred\x1b[0m workflow", parsed.value.object.get("name").?.string);
}

test "workflow event text is readable for agents and CLIs" {
    const event = fx.workflow.WorkflowEvent{
        .sequence = 2,
        .kind = .timer_scheduled,
        .workflow_id = 7,
        .execution_id = 8,
        .timer_id = 10,
        .compensation_id = 50,
        .attempt = 2,
        .name = "wake-up",
        .status = "scheduled",
        .idempotency_key = "timer-2",
    };

    const text = try fx.workflow.formatWorkflowEventText(std.testing.allocator, event);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "zigeffect workflow journal event") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "kind: timer_scheduled") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "timer_id: 10") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "compensation_id: 50") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "attempt: 2") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "name: wake-up") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "idempotency_key: timer-2") != null);
}

test "workflow event json parses back into an owned event" {
    const event = fx.workflow.WorkflowEvent{
        .sequence = 3,
        .kind = .queue_claimed,
        .workflow_id = 7,
        .execution_id = 8,
        .parent_sequence = 2,
        .queue_id = 40,
        .compensation_id = 50,
        .attempt = 3,
        .name = "mailbox \"primary\"",
        .status = "claimed\nready",
        .redacted_detail = "safe\tpayload",
        .idempotency_key = "queue-claim",
    };

    const json = try fx.workflow.formatWorkflowEventJson(std.testing.allocator, event);
    defer std.testing.allocator.free(json);

    const parsed = try fx.workflow.parseWorkflowEventJson(std.testing.allocator, json);
    defer fx.workflow.deinitWorkflowEventStrings(std.testing.allocator, parsed);

    try std.testing.expectEqual(event.sequence, parsed.sequence);
    try std.testing.expectEqual(event.kind, parsed.kind);
    try std.testing.expectEqual(event.workflow_id, parsed.workflow_id);
    try std.testing.expectEqual(event.execution_id, parsed.execution_id);
    try std.testing.expectEqual(event.parent_sequence, parsed.parent_sequence);
    try std.testing.expectEqual(event.queue_id, parsed.queue_id);
    try std.testing.expectEqual(event.compensation_id, parsed.compensation_id);
    try std.testing.expectEqual(event.attempt, parsed.attempt);
    try std.testing.expectEqual(@as(?u64, null), parsed.activity_id);
    try std.testing.expectEqualStrings(event.name, parsed.name);
    try std.testing.expectEqualStrings(event.status, parsed.status);
    try std.testing.expectEqualStrings(event.redacted_detail, parsed.redacted_detail);
    try std.testing.expectEqualStrings(event.idempotency_key, parsed.idempotency_key);
}

test "workflow journal classifies schema headers before full parse" {
    const json = try fx.workflow.formatWorkflowEventJson(std.testing.allocator, .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .name = "compat",
        .status = "running",
        .idempotency_key = "compat-start",
    });
    defer std.testing.allocator.free(json);

    const future_json = try replaceFirstOwned(std.testing.allocator, json, "\"schema_version\":1", "\"schema_version\":2");
    defer std.testing.allocator.free(future_json);
    const version_zero_json = try replaceFirstOwned(std.testing.allocator, json, "\"schema_version\":1", "\"schema_version\":0");
    defer std.testing.allocator.free(version_zero_json);
    const unknown_kind_json = try replaceFirstOwned(std.testing.allocator, json, "\"kind\":\"workflow_started\"", "\"kind\":\"future_event\"");
    defer std.testing.allocator.free(unknown_kind_json);

    try std.testing.expectEqual(fx.workflow.WorkflowEventCompatibility.current, try fx.workflow.classifyWorkflowEventJson(std.testing.allocator, json));
    try std.testing.expectEqual(fx.workflow.WorkflowEventCompatibility.future_schema_version, try fx.workflow.classifyWorkflowEventJson(std.testing.allocator, future_json));
    try std.testing.expectEqual(fx.workflow.WorkflowEventCompatibility.missing_migration, try fx.workflow.classifyWorkflowEventJson(std.testing.allocator, version_zero_json));
    try std.testing.expectEqual(fx.workflow.WorkflowEventCompatibility.unknown_event_kind, try fx.workflow.classifyWorkflowEventJson(std.testing.allocator, unknown_kind_json));
}

test "workflow journal migration registry parses current v1 rows" {
    const json = try fx.workflow.formatWorkflowEventJson(std.testing.allocator, .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .name = "compat",
        .status = "running",
        .idempotency_key = "compat-start",
    });
    defer std.testing.allocator.free(json);

    const future_json = try replaceFirstOwned(std.testing.allocator, json, "\"schema_version\":1", "\"schema_version\":2");
    defer std.testing.allocator.free(future_json);
    const version_zero_json = try replaceFirstOwned(std.testing.allocator, json, "\"schema_version\":1", "\"schema_version\":0");
    defer std.testing.allocator.free(version_zero_json);
    const unknown_kind_json = try replaceFirstOwned(std.testing.allocator, json, "\"kind\":\"workflow_started\"", "\"kind\":\"future_event\"");
    defer std.testing.allocator.free(unknown_kind_json);

    const parsed = try fx.workflow.parseWorkflowEventJsonWithOptions(std.testing.allocator, json, .{});
    defer fx.workflow.deinitWorkflowEventStrings(std.testing.allocator, parsed);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_started, parsed.kind);

    try std.testing.expectError(error.FutureWorkflowEventSchemaVersion, fx.workflow.parseWorkflowEventJson(std.testing.allocator, future_json));
    try std.testing.expectError(error.MissingWorkflowEventMigration, fx.workflow.parseWorkflowEventJson(std.testing.allocator, version_zero_json));
    try std.testing.expectError(error.UnknownWorkflowEventKind, fx.workflow.parseWorkflowEventJson(std.testing.allocator, unknown_kind_json));
}

test "workflow v1 golden fixture replays under versioned reader" {
    const content = try std.Io.Dir.cwd().readFileAlloc(
        std.testing.io,
        "test/fixtures/workflow-journal-v1-golden.jsonl",
        std.testing.allocator,
        std.Io.Limit.limited(16 * 1024),
    );
    defer std.testing.allocator.free(content);

    var events = try parseWorkflowJsonLines(std.testing.allocator, content);
    defer events.deinit();

    var state = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, events.events);
    defer state.deinit();

    try std.testing.expectEqual(fx.workflow.WorkflowStatus.completed, state.workflow_status);
    try std.testing.expectEqual(@as(?u64, 11), state.workflow_id);
    try std.testing.expectEqual(@as(?u64, 12), state.execution_id);
    try std.testing.expectEqual(@as(u64, 4), state.last_sequence);
    try std.testing.expectEqual(@as(usize, 1), state.activities.items.len);
    try std.testing.expectEqual(fx.workflow.ActivityStatus.completed, state.activities.items[0].status);
    try std.testing.expectEqualStrings("charge", state.activities.items[0].name);
}

test "workflow compensation ids are stable by label" {
    try std.testing.expectEqual(
        fx.workflow.compensationId("refund-charge"),
        fx.workflow.compensationId("refund-charge"),
    );
    try std.testing.expect(fx.workflow.compensationId("refund-charge") != fx.workflow.compensationId("release-seat"));
}

test "workflow deferred ids are stable by label" {
    try std.testing.expectEqual(
        fx.workflow.deferredId("approval"),
        fx.workflow.deferredId("approval"),
    );
    try std.testing.expect(fx.workflow.deferredId("approval") != fx.workflow.deferredId("payment"));
    try std.testing.expect(@hasDecl(fx.workflow, "DurableDeferred"));
}

test "workflow timer ids are stable by label" {
    try std.testing.expectEqual(
        fx.workflow.timerId("wake"),
        fx.workflow.timerId("wake"),
    );
    try std.testing.expect(fx.workflow.timerId("wake") != fx.workflow.timerId("timeout"));
    try std.testing.expect(@hasDecl(fx.workflow, "DurableClock"));
}

test "workflow signal ids are stable by name" {
    try std.testing.expectEqual(
        fx.workflow.signalId("approval"),
        fx.workflow.signalId("approval"),
    );
    try std.testing.expect(fx.workflow.signalId("approval") != fx.workflow.signalId("webhook"));
    try std.testing.expect(@hasDecl(fx.workflow, "DurableSignal"));
    try std.testing.expect(@hasDecl(fx.workflow, "SignalWaitResult"));
}

test "workflow signal definitions expose metadata and timeout" {
    const Approval = fx.workflow.Signal("approval", u64);
    try std.testing.expect(Approval.PayloadType == u64);

    const metadata = Approval.metadata();
    try std.testing.expectEqualStrings("approval", metadata.name);
    try std.testing.expectEqualStrings(@typeName(u64), metadata.payload_type_name);
    try std.testing.expectEqual(@as(?u64, null), metadata.timeout_ms);

    const TimedApproval = Approval.withTimeoutMs(250);
    const timed_metadata = TimedApproval.metadata();
    try std.testing.expectEqualStrings("approval", timed_metadata.name);
    try std.testing.expectEqualStrings(@typeName(u64), timed_metadata.payload_type_name);
    try std.testing.expectEqual(@as(?u64, 250), timed_metadata.timeout_ms);
}

test "workflow queue definitions expose metadata and item ids" {
    const Payload = struct {
        account_id: u64,
    };
    const SendEmail = fx.workflow
        .Queue("email", Payload, u64, error{DeliveryFailed})
        .withIdempotencyKey(struct {
            fn key(allocator: std.mem.Allocator, payload: Payload) ![]const u8 {
                return std.fmt.allocPrint(allocator, "email:{d}", .{payload.account_id});
            }
        }.key)
        .withClaimTimeoutMs(250)
        .withMaxConcurrency(2);

    try std.testing.expect(SendEmail.PayloadType == Payload);
    try std.testing.expect(SendEmail.SuccessType == u64);
    try std.testing.expect(SendEmail.FailureType == error{DeliveryFailed});
    try std.testing.expect(@hasDecl(fx.workflow, "DurableQueue"));
    try std.testing.expect(@hasDecl(fx.workflow, "QueueAwaitResult"));
    try std.testing.expect(@hasDecl(fx.workflow, "QueueClaim"));

    const metadata = SendEmail.metadata();
    try std.testing.expectEqualStrings("email", metadata.name);
    try std.testing.expectEqualStrings(@typeName(Payload), metadata.payload_type_name);
    try std.testing.expectEqualStrings(@typeName(u64), metadata.success_type_name);
    try std.testing.expectEqualStrings(@typeName(error{DeliveryFailed}), metadata.failure_type_name);
    try std.testing.expect(metadata.has_idempotency_key);
    try std.testing.expectEqual(@as(?u64, 250), metadata.claim_timeout_ms);
    try std.testing.expectEqual(@as(usize, 2), metadata.max_concurrency);

    const payload = Payload{ .account_id = 42 };
    const key = try SendEmail.idempotencyKey(std.testing.allocator, payload);
    defer std.testing.allocator.free(key);
    try std.testing.expectEqualStrings("email:42", key);

    try std.testing.expectEqual(
        fx.workflow.queueItemId("email", "email:42"),
        try SendEmail.deriveItemId(std.testing.allocator, payload),
    );
}

test "workflow replay folds lifecycle events" {
    const events = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8, .name = "approval" },
        .{ .sequence = 2, .kind = .workflow_suspended, .workflow_id = 7, .execution_id = 8, .status = "waiting" },
        .{ .sequence = 3, .kind = .workflow_resumed, .workflow_id = 7, .execution_id = 8 },
        .{ .sequence = 4, .kind = .workflow_completed, .workflow_id = 7, .execution_id = 8, .status = "success" },
    };

    var state = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &events);
    defer state.deinit();

    try std.testing.expectEqual(fx.workflow.WorkflowStatus.completed, state.workflow_status);
    try std.testing.expectEqual(@as(?u64, 7), state.workflow_id);
    try std.testing.expectEqual(@as(?u64, 8), state.execution_id);
    try std.testing.expectEqual(@as(u64, 4), state.last_sequence);
}

test "workflow replay state clone owns copied names" {
    const events = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8, .name = "clone-workflow" },
        .{ .sequence = 2, .kind = .activity_scheduled, .workflow_id = 7, .execution_id = 8, .activity_id = 10, .attempt = 1, .name = "charge" },
        .{ .sequence = 3, .kind = .timer_scheduled, .workflow_id = 7, .execution_id = 8, .timer_id = 20, .name = "wake" },
    };

    var state = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &events);
    defer state.deinit();

    var cloned = try state.clone(std.testing.allocator);
    defer cloned.deinit();

    try expectWorkflowReplayStatesEqual(&state, &cloned);
    try std.testing.expect(cloned.activities.items[0].name.ptr != state.activities.items[0].name.ptr);
    try std.testing.expect(cloned.timers.items[0].name.ptr != state.timers.items[0].name.ptr);
}

test "workflow terminal status helper identifies retention-safe states" {
    try std.testing.expect(!fx.workflow.workflowStatusIsTerminal(.pending));
    try std.testing.expect(!fx.workflow.workflowStatusIsTerminal(.running));
    try std.testing.expect(!fx.workflow.workflowStatusIsTerminal(.suspended));
    try std.testing.expect(fx.workflow.workflowStatusIsTerminal(.completed));
    try std.testing.expect(fx.workflow.workflowStatusIsTerminal(.failed));
    try std.testing.expect(fx.workflow.workflowStatusIsTerminal(.interrupted));
    try std.testing.expect(fx.workflow.workflowStatusIsTerminal(.cancelled));
    try std.testing.expect(fx.workflow.workflowStatusIsTerminal(.defect));
}

test "workflow lifecycle suspend and resume are durable and idempotent" {
    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .name = "lifecycle-workflow",
        .status = "running",
        .idempotency_key = "lifecycle-start",
    } });

    {
        var lifecycle = fx.workflow.WorkflowLifecycle.init(std.testing.allocator, journal, 7, 8);
        try std.testing.expect(try lifecycle.suspendWorkflow("operator"));
        try std.testing.expect(!try lifecycle.suspendWorkflow("operator"));
    }

    var suspended_state = try journal.latestState(std.testing.allocator);
    defer suspended_state.deinit();
    try std.testing.expectEqual(fx.workflow.WorkflowStatus.suspended, suspended_state.workflow_status);

    {
        var lifecycle = fx.workflow.WorkflowLifecycle.init(std.testing.allocator, journal, 7, 8);
        try std.testing.expect(try lifecycle.resumeWorkflow("operator"));
        try std.testing.expect(!try lifecycle.resumeWorkflow("operator"));
    }

    var running_state = try journal.latestState(std.testing.allocator);
    defer running_state.deinit();
    try std.testing.expectEqual(fx.workflow.WorkflowStatus.running, running_state.workflow_status);

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 3), events.events.len);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_suspended, events.events[1].kind);
    try std.testing.expectEqualStrings("operator", events.events[1].redacted_detail);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_resumed, events.events[2].kind);
    try std.testing.expectEqualStrings("operator", events.events[2].redacted_detail);
}

test "workflow lifecycle is governed through the shared statechart control plane" {
    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();
    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 71,
        .execution_id = 81,
        .name = "controlled-workflow",
        .status = "running",
        .idempotency_key = "controlled-start",
    } });

    const Event = enum { unused };
    const Plane = fx.statechart.ControlPlane(Event);
    var lifecycle = fx.workflow.WorkflowLifecycle.init(std.testing.allocator, journal, 71, 81);
    var adapter = fx.workflow.WorkflowControlAdapter(Event).init(&lifecycle, 4242, 9);
    var plane = Plane.init(adapter.adapter());
    const Allow = struct {
        fn decide(_: *anyopaque, _: Plane.Request) fx.statechart.ControlDecision {
            return .allow;
        }
    };
    var policy_context: u8 = 0;
    plane.policy = .{ .context = &policy_context, .decide_fn = Allow.decide };
    const receipt = try plane.execute(.{
        .request_id = "suspend-workflow-71",
        .machine_id = "agent.controlled-workflow",
        .instance_id = 71,
        .operation = .@"suspend",
        .expected_definition_fingerprint = 4242,
        .expected_fence_epoch = 9,
        .reason = "human operator investigation",
    });
    try std.testing.expectEqual(fx.statechart.ControlStatus.applied, receipt.status);
    try std.testing.expectEqual(fx.workflow.WorkflowStatus.suspended, try lifecycle.inspectStatus());
}

test "workflow lifecycle interrupt is terminal and idempotent after restart" {
    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .name = "lifecycle-workflow",
        .status = "running",
        .idempotency_key = "interrupt-start",
    } });

    {
        var lifecycle = fx.workflow.WorkflowLifecycle.init(std.testing.allocator, journal, 7, 8);
        try std.testing.expect(try lifecycle.interrupt("operator"));
    }
    {
        var lifecycle = fx.workflow.WorkflowLifecycle.init(std.testing.allocator, journal, 7, 8);
        try std.testing.expect(!try lifecycle.interrupt("operator"));
    }

    var state = try journal.latestState(std.testing.allocator);
    defer state.deinit();
    try std.testing.expectEqual(fx.workflow.WorkflowStatus.interrupted, state.workflow_status);

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 2), events.events.len);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_interrupted, events.events[1].kind);
    try std.testing.expectEqualStrings("interrupted", events.events[1].status);
    try std.testing.expectEqualStrings("exit.cause.interrupted:0;reason=operator", events.events[1].redacted_detail);
}

test "workflow lifecycle cancel is terminal and idempotent after restart" {
    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .name = "lifecycle-workflow",
        .status = "running",
        .idempotency_key = "cancel-start",
    } });

    {
        var lifecycle = fx.workflow.WorkflowLifecycle.init(std.testing.allocator, journal, 7, 8);
        try std.testing.expect(try lifecycle.cancel("operator"));
    }
    {
        var lifecycle = fx.workflow.WorkflowLifecycle.init(std.testing.allocator, journal, 7, 8);
        try std.testing.expect(!try lifecycle.cancel("operator"));
    }

    var state = try journal.latestState(std.testing.allocator);
    defer state.deinit();
    try std.testing.expectEqual(fx.workflow.WorkflowStatus.cancelled, state.workflow_status);

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 2), events.events.len);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_cancelled, events.events[1].kind);
    try std.testing.expectEqualStrings("cancelled", events.events[1].status);
    try std.testing.expectEqualStrings("reason=operator", events.events[1].redacted_detail);
}

test "workflow lifecycle terminal controls ignore missing execution" {
    {
        var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
        defer journal_memory.deinit();
        const journal = journal_memory.asJournalStore();

        var lifecycle = fx.workflow.WorkflowLifecycle.init(std.testing.allocator, journal, 7, 8);
        try std.testing.expect(!try lifecycle.interrupt("operator"));

        var events = try journal.readAll(std.testing.allocator);
        defer events.deinit();
        try std.testing.expectEqual(@as(usize, 0), events.events.len);
    }

    {
        var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
        defer journal_memory.deinit();
        const journal = journal_memory.asJournalStore();

        var lifecycle = fx.workflow.WorkflowLifecycle.init(std.testing.allocator, journal, 7, 8);
        try std.testing.expect(!try lifecycle.cancel("operator"));

        var events = try journal.readAll(std.testing.allocator);
        defer events.deinit();
        try std.testing.expectEqual(@as(usize, 0), events.events.len);
    }
}

test "workflow lifecycle cancel terminates pending durable work" {
    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .name = "lifecycle-workflow",
        .status = "running",
        .idempotency_key = "pending-start",
    } });
    _ = try journal.append(.{ .event = .{
        .sequence = 2,
        .kind = .timer_scheduled,
        .workflow_id = 7,
        .execution_id = 8,
        .timer_id = 20,
        .name = "wake",
        .idempotency_key = "pending-timer",
    } });
    _ = try journal.append(.{ .event = .{
        .sequence = 3,
        .kind = .deferred_created,
        .workflow_id = 7,
        .execution_id = 8,
        .deferred_id = 30,
        .name = "approval",
        .idempotency_key = "pending-deferred-create",
    } });
    _ = try journal.append(.{ .event = .{
        .sequence = 4,
        .kind = .deferred_awaited,
        .workflow_id = 7,
        .execution_id = 8,
        .deferred_id = 30,
        .name = "approval",
        .idempotency_key = "pending-deferred-await",
    } });
    _ = try journal.append(.{ .event = .{
        .sequence = 5,
        .kind = .queue_offered,
        .workflow_id = 7,
        .execution_id = 8,
        .queue_id = 40,
        .name = "email",
        .idempotency_key = "pending-queue",
    } });
    _ = try journal.append(.{ .event = .{
        .sequence = 6,
        .kind = .activity_scheduled,
        .workflow_id = 7,
        .execution_id = 8,
        .activity_id = 10,
        .attempt = 1,
        .name = "charge",
        .idempotency_key = "pending-activity",
    } });

    var lifecycle = fx.workflow.WorkflowLifecycle.init(std.testing.allocator, journal, 7, 8);
    try std.testing.expect(try lifecycle.cancel("operator"));
    try std.testing.expect(!try lifecycle.cancel("operator"));

    var state = try journal.latestState(std.testing.allocator);
    defer state.deinit();
    try std.testing.expectEqual(fx.workflow.WorkflowStatus.cancelled, state.workflow_status);
    try std.testing.expectEqual(fx.workflow.TimerStatus.cancelled, state.timers.items[0].status);
    try std.testing.expectEqual(fx.workflow.DeferredStatus.cancelled, state.deferreds.items[0].status);
    try std.testing.expectEqual(fx.workflow.QueueStatus.failed, state.queues.items[0].status);
    try std.testing.expectEqual(fx.workflow.ActivityStatus.failed, state.activities.items[0].status);

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 11), events.events.len);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.timer_cancelled, events.events[6].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.deferred_cancelled, events.events[7].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.queue_failed, events.events[8].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.activity_failed, events.events[9].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_cancelled, events.events[10].kind);
    try std.testing.expectEqualStrings("lifecycle.cancel:operator", events.events[6].redacted_detail);
    try std.testing.expectEqualStrings("lifecycle.cancel:operator", events.events[7].redacted_detail);
    try std.testing.expectEqualStrings("lifecycle.cancel:operator", events.events[8].redacted_detail);
    try std.testing.expectEqualStrings("lifecycle.cancel:operator", events.events[9].redacted_detail);
}

test "workflow lifecycle controls replay after file journal reopen" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    {
        var file_store = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
        defer file_store.deinit();
        const journal = file_store.asJournalStore();

        _ = try journal.append(.{ .event = .{
            .sequence = 1,
            .kind = .workflow_started,
            .workflow_id = 7,
            .execution_id = 8,
            .name = "lifecycle-workflow",
            .status = "running",
            .idempotency_key = "file-lifecycle-start",
        } });

        var lifecycle = fx.workflow.WorkflowLifecycle.init(std.testing.allocator, journal, 7, 8);
        try std.testing.expect(try lifecycle.suspendWorkflow("operator"));
        try std.testing.expect(!try lifecycle.suspendWorkflow("operator"));

        var state = try journal.latestState(std.testing.allocator);
        defer state.deinit();
        try std.testing.expectEqual(fx.workflow.WorkflowStatus.suspended, state.workflow_status);
    }

    {
        var reopened = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
        defer reopened.deinit();
        const journal = reopened.asJournalStore();

        var lifecycle = fx.workflow.WorkflowLifecycle.init(std.testing.allocator, journal, 7, 8);
        try std.testing.expect(try lifecycle.resumeWorkflow("operator"));
        try std.testing.expect(!try lifecycle.resumeWorkflow("operator"));

        var state = try journal.latestState(std.testing.allocator);
        defer state.deinit();
        try std.testing.expectEqual(fx.workflow.WorkflowStatus.running, state.workflow_status);
    }

    {
        var reopened = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
        defer reopened.deinit();
        const journal = reopened.asJournalStore();

        var lifecycle = fx.workflow.WorkflowLifecycle.init(std.testing.allocator, journal, 7, 8);
        try std.testing.expect(try lifecycle.cancel("operator"));
        try std.testing.expect(!try lifecycle.cancel("operator"));

        var state = try journal.latestState(std.testing.allocator);
        defer state.deinit();
        try std.testing.expectEqual(fx.workflow.WorkflowStatus.cancelled, state.workflow_status);
    }

    {
        var reopened = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
        defer reopened.deinit();
        const journal = reopened.asJournalStore();

        var lifecycle = fx.workflow.WorkflowLifecycle.init(std.testing.allocator, journal, 7, 8);
        try std.testing.expect(!try lifecycle.cancel("operator"));

        var events = try journal.readAll(std.testing.allocator);
        defer events.deinit();
        try std.testing.expectEqual(@as(usize, 4), events.events.len);
        try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_started, events.events[0].kind);
        try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_suspended, events.events[1].kind);
        try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_resumed, events.events[2].kind);
        try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_cancelled, events.events[3].kind);
        try std.testing.expectEqualStrings("operator", events.events[1].redacted_detail);
        try std.testing.expectEqualStrings("operator", events.events[2].redacted_detail);
        try std.testing.expectEqualStrings("reason=operator", events.events[3].redacted_detail);
    }
}

test "workflow inspector summarizes replay state and pending work" {
    const events = workflowInspectorFixtureEvents();

    var report = try fx.workflow.inspectExecution(std.testing.allocator, &events, null);
    defer report.deinit();

    try std.testing.expectEqual(@as(usize, 7), report.event_count);
    try std.testing.expectEqual(@as(?u64, 1), report.first_sequence);
    try std.testing.expectEqual(@as(?u64, 7), report.last_sequence);
    try std.testing.expectEqual(@as(usize, 1), report.executions.len);
    try std.testing.expectEqual(@as(u64, 7), report.executions[0].workflow_id);
    try std.testing.expectEqual(@as(u64, 8), report.executions[0].execution_id);
    try std.testing.expectEqualStrings("inspected-workflow", report.executions[0].name);
    try std.testing.expectEqualStrings("running", report.executions[0].status);
    try std.testing.expectEqual(fx.workflow.WorkflowStatus.running, report.state.?.workflow_status);
    try std.testing.expectEqual(@as(usize, 1), report.pending.timers.len);
    try std.testing.expectEqual(@as(usize, 1), report.pending.deferreds.len);
    try std.testing.expectEqual(@as(usize, 1), report.pending.queues.len);
    try std.testing.expectEqual(@as(usize, 1), report.pending.activities.len);
    try std.testing.expectEqualStrings("exit.cause.failure:Boom", report.last_failure_detail);
}

test "workflow inspector formats text report" {
    const events = workflowInspectorFixtureEvents();
    var report = try fx.workflow.inspectExecution(std.testing.allocator, &events, null);
    defer report.deinit();

    const text = try fx.workflow.formatReplayReportText(std.testing.allocator, &report);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "zigeffect workflow replay\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "workflow_id: 7\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "execution_id: 8\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "status: running\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "pending_timers: 1\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "pending_deferreds: 1\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "pending_queues: 1\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "pending_activities: 1\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "last_failure: exit.cause.failure:Boom\n") != null);
}

test "workflow inspector formats json report" {
    const events = workflowInspectorFixtureEvents();
    var report = try fx.workflow.inspectExecution(std.testing.allocator, &events, null);
    defer report.deinit();

    const json = try fx.workflow.formatReplayReportJson(std.testing.allocator, &report);
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "{\"schema\":\"zigeffect.workflow.replay.v1\",\"schema_version\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"workflow_id\":7") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"execution_id\":8") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"status\":\"running\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"pending_timers\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"pending_deferreds\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"pending_queues\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"pending_activities\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"last_failure_detail\":\"exit.cause.failure:Boom\"") != null);
}

test "workflow inspector formats list reports" {
    const events = workflowInspectorFixtureEvents();
    var report = try fx.workflow.listExecutions(std.testing.allocator, &events);
    defer report.deinit();

    const text = try fx.workflow.formatListReportText(std.testing.allocator, &report);
    defer std.testing.allocator.free(text);
    try std.testing.expect(std.mem.indexOf(u8, text, "zigeffect workflow list\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "executions: 1\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "- workflow_id: 7 execution_id: 8 status: running events: 7\n") != null);

    const json = try fx.workflow.formatListReportJson(std.testing.allocator, &report);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "{\"schema\":\"zigeffect.workflow.list.v1\",\"schema_version\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"executions\":[{\"workflow_id\":7,\"execution_id\":8") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"event_count\":7") != null);
}

test "workflow inspector formats event inspection reports" {
    const events = workflowInspectorFixtureEvents();
    var report = try fx.workflow.inspectExecution(std.testing.allocator, &events, null);
    defer report.deinit();

    const text = try fx.workflow.formatInspectReportText(std.testing.allocator, &report, &events);
    defer std.testing.allocator.free(text);
    try std.testing.expect(std.mem.indexOf(u8, text, "zigeffect workflow journal inspect\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "events: 7\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "7 step_failed failed exit.cause.failure:Boom\n") != null);

    const json = try fx.workflow.formatInspectReportJson(std.testing.allocator, &report, &events);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "{\"schema\":\"zigeffect.workflow.inspect.v1\",\"schema_version\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"events\":[") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"kind\":\"step_failed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"redacted_detail\":\"exit.cause.failure:Boom\"") != null);
}

test "workflow inspector json escapes control bytes" {
    const events = [_]fx.workflow.WorkflowEvent{
        .{
            .sequence = 1,
            .kind = .workflow_started,
            .workflow_id = 7,
            .execution_id = 8,
            .name = "ansi \x1b[31mred\x1b[0m workflow",
            .status = "running",
            .idempotency_key = "escape-inspect",
        },
    };
    var report = try fx.workflow.inspectExecution(std.testing.allocator, &events, null);
    defer report.deinit();

    const json = try fx.workflow.formatInspectReportJson(std.testing.allocator, &report, &events);
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\\u001b") != null);
    try std.testing.expect(std.mem.indexOfScalar(u8, json, 0x1b) == null);

    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{});
    defer parsed.deinit();
}

test "workflow checkpoint json escapes control bytes" {
    const events = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8, .idempotency_key = "start" },
        .{ .sequence = 2, .kind = .activity_scheduled, .workflow_id = 7, .execution_id = 8, .activity_id = 10, .attempt = 1, .name = "charge \x1b[31mcard\x1b[0m" },
    };
    var state = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &events);
    defer state.deinit();

    const json = try fx.workflow.formatWorkflowCheckpointJson(std.testing.allocator, &state);
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\\u001b") != null);
    try std.testing.expect(std.mem.indexOfScalar(u8, json, 0x1b) == null);

    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{});
    defer parsed.deinit();
}

test "workflow causal mapping links journal events to causal ids" {
    const events = workflowCausalFixtureEvents();

    var mapped = try fx.workflow.mapWorkflowEventsToCausal(std.testing.allocator, &events);
    defer mapped.deinit();

    try std.testing.expectEqual(@as(usize, 5), mapped.events.len);
    try std.testing.expectEqual(fx.CausalEventKind.workflow_event_recorded, mapped.events[0].kind);
    try std.testing.expectEqual(@as(?u64, 7), mapped.events[0].run_id);
    try std.testing.expectEqual(@as(?u64, 8), mapped.events[0].scope_id);
    try std.testing.expectEqual(@as(?u64, 7), mapped.events[0].trace_id);
    try std.testing.expectEqual(@as(?u64, 1), mapped.events[0].span_id);
    try std.testing.expectEqual(@as(?u64, null), mapped.events[0].parent_id);
    try std.testing.expectEqualStrings("causal-workflow", mapped.events[0].label);
    try std.testing.expectEqualStrings("workflow.workflow_started", mapped.events[0].type_name);

    try std.testing.expectEqual(@as(?u64, 1), mapped.events[1].parent_id);
    try std.testing.expectEqual(@as(?u64, 2), mapped.events[1].span_id);
    try std.testing.expectEqualStrings("workflow.workflow_suspended", mapped.events[1].type_name);
    try std.testing.expectEqualStrings("waiting", mapped.events[1].status);

    try std.testing.expectEqual(@as(?u64, 50), mapped.events[3].fiber_id);
    try std.testing.expectEqualStrings("workflow.activity_retry_scheduled", mapped.events[3].type_name);
    try std.testing.expectEqualStrings("retry", mapped.events[3].status);

    try std.testing.expectEqualStrings("workflow.workflow_failed", mapped.events[4].type_name);
    try std.testing.expectEqualStrings("exit.cause.failure:Boom", mapped.events[4].redacted_detail);
}

test "workflow causal report explains failure retry suspend and resume" {
    const events = workflowCausalFixtureEvents();

    const report = try fx.workflow.formatWorkflowCausalReport(std.testing.allocator, &events);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "workflow.workflow_failed") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "workflow.activity_retry_scheduled") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "workflow.workflow_suspended") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "workflow.workflow_resumed") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "workflow findings: 4") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "workflow_failure") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "workflow_retry_scheduled") != null);
}

test "workflow causal dot renders workflow history" {
    const events = workflowCausalFixtureEvents();

    const dot = try fx.workflow.formatWorkflowCausalDot(std.testing.allocator, &events);
    defer std.testing.allocator.free(dot);

    try std.testing.expect(std.mem.indexOf(u8, dot, "digraph zigeffect_causal") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "workflow.workflow_failed") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "event_1 -> event_2 [label=\"parent\"]") != null);
}

test "workflow replay rejects events before start and duplicate starts" {
    const before_start = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_completed, .workflow_id = 7, .execution_id = 8 },
    };
    try std.testing.expectError(error.WorkflowNotStarted, fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &before_start));

    const duplicate_start = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
        .{ .sequence = 2, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
    };
    try std.testing.expectError(error.WorkflowAlreadyStarted, fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &duplicate_start));
}

test "workflow replay folds defect terminal status" {
    const events = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
        .{ .sequence = 2, .kind = .workflow_failed, .workflow_id = 7, .execution_id = 8, .status = "defect" },
    };

    var state = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &events);
    defer state.deinit();

    try std.testing.expectEqual(fx.workflow.WorkflowStatus.defect, state.workflow_status);
    try std.testing.expectEqual(@as(u64, 2), state.last_sequence);
}

test "workflow replay rejects terminal and lifecycle transition violations" {
    const after_terminal = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
        .{ .sequence = 2, .kind = .workflow_completed, .workflow_id = 7, .execution_id = 8 },
        .{ .sequence = 3, .kind = .timer_scheduled, .workflow_id = 7, .execution_id = 8, .timer_id = 20 },
    };
    try std.testing.expectError(error.WorkflowAlreadyTerminal, fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &after_terminal));

    const resume_without_suspend = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
        .{ .sequence = 2, .kind = .workflow_resumed, .workflow_id = 7, .execution_id = 8 },
    };
    try std.testing.expectError(error.InvalidWorkflowTransition, fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &resume_without_suspend));
}

test "workflow replay folds activity timer deferred and queue rows" {
    const events = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
        .{ .sequence = 2, .kind = .activity_scheduled, .workflow_id = 7, .execution_id = 8, .activity_id = 10, .attempt = 1, .name = "charge" },
        .{ .sequence = 3, .kind = .activity_started, .workflow_id = 7, .execution_id = 8, .activity_id = 10, .attempt = 1 },
        .{ .sequence = 4, .kind = .activity_completed, .workflow_id = 7, .execution_id = 8, .activity_id = 10, .attempt = 1 },
        .{ .sequence = 5, .kind = .timer_scheduled, .workflow_id = 7, .execution_id = 8, .timer_id = 20, .name = "wake-up" },
        .{ .sequence = 6, .kind = .timer_fired, .workflow_id = 7, .execution_id = 8, .timer_id = 20 },
        .{ .sequence = 7, .kind = .deferred_created, .workflow_id = 7, .execution_id = 8, .deferred_id = 30, .name = "approval" },
        .{ .sequence = 8, .kind = .deferred_awaited, .workflow_id = 7, .execution_id = 8, .deferred_id = 30 },
        .{ .sequence = 9, .kind = .deferred_completed, .workflow_id = 7, .execution_id = 8, .deferred_id = 30 },
        .{ .sequence = 10, .kind = .queue_offered, .workflow_id = 7, .execution_id = 8, .queue_id = 40, .name = "mailbox" },
        .{ .sequence = 11, .kind = .queue_claimed, .workflow_id = 7, .execution_id = 8, .queue_id = 40 },
        .{ .sequence = 12, .kind = .queue_acked, .workflow_id = 7, .execution_id = 8, .queue_id = 40 },
    };

    var state = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &events);
    defer state.deinit();

    try std.testing.expectEqual(@as(usize, 1), state.activities.items.len);
    try std.testing.expectEqual(@as(u64, 10), state.activities.items[0].id);
    try std.testing.expectEqual(fx.workflow.ActivityStatus.completed, state.activities.items[0].status);
    try std.testing.expectEqual(@as(u64, 4), state.activities.items[0].last_sequence);
    try std.testing.expectEqual(@as(u32, 1), state.activities.items[0].attempt);
    try std.testing.expectEqualStrings("charge", state.activities.items[0].name);

    try std.testing.expectEqual(@as(usize, 1), state.timers.items.len);
    try std.testing.expectEqual(@as(u64, 20), state.timers.items[0].id);
    try std.testing.expectEqual(fx.workflow.TimerStatus.fired, state.timers.items[0].status);
    try std.testing.expectEqual(@as(u64, 6), state.timers.items[0].last_sequence);
    try std.testing.expectEqualStrings("wake-up", state.timers.items[0].name);

    try std.testing.expectEqual(@as(usize, 1), state.deferreds.items.len);
    try std.testing.expectEqual(@as(u64, 30), state.deferreds.items[0].id);
    try std.testing.expectEqual(fx.workflow.DeferredStatus.completed, state.deferreds.items[0].status);
    try std.testing.expectEqual(@as(u64, 9), state.deferreds.items[0].last_sequence);
    try std.testing.expectEqualStrings("approval", state.deferreds.items[0].name);

    try std.testing.expectEqual(@as(usize, 1), state.queues.items.len);
    try std.testing.expectEqual(@as(u64, 40), state.queues.items[0].id);
    try std.testing.expectEqual(fx.workflow.QueueStatus.acked, state.queues.items[0].status);
    try std.testing.expectEqual(@as(u64, 12), state.queues.items[0].last_sequence);
    try std.testing.expectEqualStrings("mailbox", state.queues.items[0].name);
}

test "workflow replay folds queue retry rows" {
    const events = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
        .{ .sequence = 2, .kind = .queue_offered, .workflow_id = 7, .execution_id = 8, .queue_id = 40, .name = "mailbox" },
        .{ .sequence = 3, .kind = .queue_claimed, .workflow_id = 7, .execution_id = 8, .queue_id = 40 },
        .{ .sequence = 4, .kind = .queue_retry_scheduled, .workflow_id = 7, .execution_id = 8, .queue_id = 40 },
    };

    var state = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &events);
    defer state.deinit();

    try std.testing.expectEqual(@as(usize, 1), state.queues.items.len);
    try std.testing.expectEqual(@as(u64, 40), state.queues.items[0].id);
    try std.testing.expectEqual(fx.workflow.QueueStatus.retry_ready, state.queues.items[0].status);
    try std.testing.expectEqual(@as(u64, 4), state.queues.items[0].last_sequence);
}

test "workflow replay folds retry-ready activity failures" {
    const events = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
        .{ .sequence = 2, .kind = .activity_scheduled, .workflow_id = 7, .execution_id = 8, .activity_id = 10 },
        .{ .sequence = 3, .kind = .activity_failed, .workflow_id = 7, .execution_id = 8, .activity_id = 10, .status = "retry_ready" },
    };

    var state = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &events);
    defer state.deinit();

    try std.testing.expectEqual(fx.workflow.ActivityStatus.retry_ready, state.activities.items[0].status);
    try std.testing.expectEqual(@as(u64, 3), state.activities.items[0].last_sequence);
}

test "workflow replay folds activity retry and timeout events" {
    const retry_ready = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
        .{ .sequence = 2, .kind = .activity_scheduled, .workflow_id = 7, .execution_id = 8, .activity_id = 10, .attempt = 1 },
        .{ .sequence = 3, .kind = .activity_retry_scheduled, .workflow_id = 7, .execution_id = 8, .activity_id = 10, .attempt = 1, .status = "retry" },
    };
    var retry_state = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &retry_ready);
    defer retry_state.deinit();
    try std.testing.expectEqual(fx.workflow.ActivityStatus.retry_ready, retry_state.activities.items[0].status);
    try std.testing.expectEqual(@as(u32, 1), retry_state.activities.items[0].attempt);
    try std.testing.expectEqual(@as(u64, 3), retry_state.activities.items[0].last_sequence);

    const timeout = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
        .{ .sequence = 2, .kind = .activity_scheduled, .workflow_id = 7, .execution_id = 8, .activity_id = 20, .attempt = 1 },
        .{ .sequence = 3, .kind = .activity_timed_out, .workflow_id = 7, .execution_id = 8, .activity_id = 20, .attempt = 1, .status = "timeout" },
    };
    var timeout_state = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &timeout);
    defer timeout_state.deinit();
    try std.testing.expectEqual(fx.workflow.ActivityStatus.failed, timeout_state.activities.items[0].status);
    try std.testing.expectEqual(@as(u32, 1), timeout_state.activities.items[0].attempt);
    try std.testing.expectEqual(@as(u64, 3), timeout_state.activities.items[0].last_sequence);
}

test "workflow replay folds compensation rows" {
    const events = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
        .{ .sequence = 2, .kind = .compensation_registered, .workflow_id = 7, .execution_id = 8, .compensation_id = 50, .name = "refund-charge" },
        .{ .sequence = 3, .kind = .compensation_started, .workflow_id = 7, .execution_id = 8, .compensation_id = 50 },
        .{ .sequence = 4, .kind = .compensation_completed, .workflow_id = 7, .execution_id = 8, .compensation_id = 50 },
    };

    var state = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &events);
    defer state.deinit();
    try std.testing.expectEqual(@as(usize, 1), state.compensations.items.len);
    try std.testing.expectEqual(@as(u64, 50), state.compensations.items[0].id);
    try std.testing.expectEqual(fx.workflow.CompensationStatus.completed, state.compensations.items[0].status);
    try std.testing.expectEqual(@as(u64, 4), state.compensations.items[0].last_sequence);
    try std.testing.expectEqualStrings("refund-charge", state.compensations.items[0].name);
}

test "workflow replay rejects malformed resource histories" {
    const unknown_activity = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
        .{ .sequence = 2, .kind = .activity_completed, .workflow_id = 7, .execution_id = 8, .activity_id = 10 },
    };
    try std.testing.expectError(error.UnknownActivity, fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &unknown_activity));

    const duplicate_timer = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
        .{ .sequence = 2, .kind = .timer_scheduled, .workflow_id = 7, .execution_id = 8, .timer_id = 20 },
        .{ .sequence = 3, .kind = .timer_scheduled, .workflow_id = 7, .execution_id = 8, .timer_id = 20 },
    };
    try std.testing.expectError(error.DuplicateTimer, fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &duplicate_timer));

    const missing_deferred = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
        .{ .sequence = 2, .kind = .deferred_completed, .workflow_id = 7, .execution_id = 8 },
    };
    try std.testing.expectError(error.MissingTargetId, fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &missing_deferred));

    const unknown_queue = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
        .{ .sequence = 2, .kind = .queue_acked, .workflow_id = 7, .execution_id = 8, .queue_id = 40 },
    };
    try std.testing.expectError(error.UnknownQueue, fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &unknown_queue));
}

test "in-memory workflow journal store appends and reads ordered events" {
    var memory_store = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer memory_store.deinit();

    var journal_store = memory_store.asJournalStore();
    try std.testing.expect(@TypeOf(journal_store) == fx.workflow.JournalStore);

    const first_sequence = try journal_store.append(.{
        .event = .{
            .sequence = 1,
            .kind = .workflow_started,
            .workflow_id = 7,
            .execution_id = 8,
            .idempotency_key = "start",
        },
    });
    try std.testing.expectEqual(@as(u64, 1), first_sequence);

    const second_sequence = try journal_store.append(.{
        .expected_next_sequence = 2,
        .event = .{
            .sequence = 2,
            .kind = .timer_scheduled,
            .workflow_id = 7,
            .execution_id = 8,
            .timer_id = 20,
            .name = "wake-up",
            .idempotency_key = "timer",
        },
    });
    try std.testing.expectEqual(@as(u64, 2), second_sequence);

    var all = try journal_store.readAll(std.testing.allocator);
    defer all.deinit();
    try std.testing.expectEqual(@as(usize, 2), all.events.len);
    try std.testing.expectEqual(@as(u64, 1), all.events[0].sequence);
    try std.testing.expectEqual(@as(u64, 2), all.events[1].sequence);
    try std.testing.expectEqualStrings("timer", all.events[1].idempotency_key);

    var from_second = try journal_store.readFromSequence(std.testing.allocator, 2);
    defer from_second.deinit();
    try std.testing.expectEqual(@as(usize, 1), from_second.events.len);
    try std.testing.expectEqual(@as(u64, 2), from_second.events[0].sequence);
    try std.testing.expectEqualStrings("wake-up", from_second.events[0].name);
}

test "in-memory workflow journal store rejects duplicate keys and sequence conflicts" {
    var store = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer store.deinit();

    _ = try store.append(.{
        .event = .{
            .sequence = 1,
            .kind = .workflow_started,
            .workflow_id = 7,
            .execution_id = 8,
            .idempotency_key = "start",
        },
    });

    try std.testing.expectError(error.DuplicateEvent, store.append(.{
        .event = .{
            .sequence = 2,
            .kind = .workflow_suspended,
            .workflow_id = 7,
            .execution_id = 8,
            .idempotency_key = "start",
        },
    }));

    try std.testing.expectError(error.SequenceConflict, store.append(.{
        .event = .{
            .sequence = 3,
            .kind = .workflow_suspended,
            .workflow_id = 7,
            .execution_id = 8,
            .idempotency_key = "suspend",
        },
    }));

    try std.testing.expectError(error.SequenceConflict, store.append(.{
        .expected_next_sequence = 3,
        .event = .{
            .sequence = 2,
            .kind = .workflow_suspended,
            .workflow_id = 7,
            .execution_id = 8,
            .idempotency_key = "suspend",
        },
    }));
}

test "in-memory workflow journal store replays latest state and resets" {
    var store = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer store.deinit();

    _ = try store.append(.{
        .event = .{
            .sequence = 1,
            .kind = .workflow_started,
            .workflow_id = 7,
            .execution_id = 8,
            .idempotency_key = "start",
        },
    });
    _ = try store.append(.{
        .event = .{
            .sequence = 2,
            .kind = .activity_scheduled,
            .workflow_id = 7,
            .execution_id = 8,
            .activity_id = 10,
            .name = "charge",
            .idempotency_key = "activity-scheduled",
        },
    });
    _ = try store.append(.{
        .event = .{
            .sequence = 3,
            .kind = .activity_completed,
            .workflow_id = 7,
            .execution_id = 8,
            .activity_id = 10,
            .idempotency_key = "activity-completed",
        },
    });

    var state = try store.latestState(std.testing.allocator);
    defer state.deinit();
    try std.testing.expectEqual(fx.workflow.WorkflowStatus.running, state.workflow_status);
    try std.testing.expectEqual(@as(usize, 1), state.activities.items.len);
    try std.testing.expectEqual(fx.workflow.ActivityStatus.completed, state.activities.items[0].status);
    try std.testing.expectEqualStrings("charge", state.activities.items[0].name);

    store.reset();

    var empty_events = try store.readAll(std.testing.allocator);
    defer empty_events.deinit();
    try std.testing.expectEqual(@as(usize, 0), empty_events.events.len);

    var empty_state = try store.latestState(std.testing.allocator);
    defer empty_state.deinit();
    try std.testing.expectEqual(fx.workflow.WorkflowStatus.pending, empty_state.workflow_status);

    const restarted_sequence = try store.append(.{
        .event = .{
            .sequence = 1,
            .kind = .workflow_started,
            .workflow_id = 9,
            .execution_id = 10,
            .idempotency_key = "restart",
        },
    });
    try std.testing.expectEqual(@as(u64, 1), restarted_sequence);
}

test "file workflow journal store appends json lines and replays after reopen" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const events = [_]fx.workflow.WorkflowEvent{
        .{
            .sequence = 1,
            .kind = .workflow_started,
            .workflow_id = 7,
            .execution_id = 8,
            .idempotency_key = "start",
        },
        .{
            .sequence = 2,
            .kind = .activity_scheduled,
            .workflow_id = 7,
            .execution_id = 8,
            .activity_id = 10,
            .name = "charge",
            .idempotency_key = "activity-scheduled",
        },
        .{
            .sequence = 3,
            .kind = .activity_completed,
            .workflow_id = 7,
            .execution_id = 8,
            .activity_id = 10,
            .idempotency_key = "activity-completed",
        },
    };

    const segment_name = try fx.workflow.segmentFileName(std.testing.allocator, 1);
    defer std.testing.allocator.free(segment_name);

    {
        var file_store = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
        defer file_store.deinit();

        var journal_store = file_store.asJournalStore();
        try std.testing.expect(@TypeOf(journal_store) == fx.workflow.JournalStore);
        for (events) |event| {
            _ = try journal_store.append(.{ .event = event });
        }

        var file_state = try journal_store.latestState(std.testing.allocator);
        defer file_state.deinit();
        try std.testing.expectEqual(fx.workflow.ActivityStatus.completed, file_state.activities.items[0].status);
    }

    const raw_segment = try tmp.dir.readFileAlloc(
        std.testing.io,
        segment_name,
        std.testing.allocator,
        std.Io.Limit.limited(16 * 1024),
    );
    defer std.testing.allocator.free(raw_segment);
    try std.testing.expectEqual(@as(usize, 3), std.mem.count(u8, raw_segment, "\n"));
    try std.testing.expect(std.mem.indexOf(u8, raw_segment, "\"idempotency_key\":\"activity-completed\"") != null);

    var memory_store = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer memory_store.deinit();
    for (events) |event| {
        _ = try memory_store.append(.{ .event = event });
    }
    var memory_state = try memory_store.latestState(std.testing.allocator);
    defer memory_state.deinit();

    {
        var reopened = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
        defer reopened.deinit();

        var file_state = try reopened.latestState(std.testing.allocator);
        defer file_state.deinit();
        try expectWorkflowReplayStatesEqual(&memory_state, &file_state);
    }
}

test "file workflow journal store recovers partial trailing row" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const segment_name = try fx.workflow.segmentFileName(std.testing.allocator, 1);
    defer std.testing.allocator.free(segment_name);

    const started = fx.workflow.WorkflowEvent{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .idempotency_key = "start",
    };
    const started_json = try fx.workflow.formatWorkflowEventJson(std.testing.allocator, started);
    defer std.testing.allocator.free(started_json);

    const partial = "{\"schema\":\"zigeffect.workflow.journal-event.v1\",\"sequence\":";
    {
        const file = try tmp.dir.createFile(std.testing.io, segment_name, .{ .read = true });
        defer file.close(std.testing.io);
        try file.writeStreamingAll(std.testing.io, started_json);
        try file.writeStreamingAll(std.testing.io, "\n");
        try file.writeStreamingAll(std.testing.io, partial);
    }

    var store = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{ .fsync_policy = .after_recovery });
    defer store.deinit();

    try std.testing.expectEqual(partial.len, store.recoveredPartialBytes());
    try std.testing.expectEqual(@as(u64, 1), store.syncCount());

    var state = try store.latestState(std.testing.allocator);
    defer state.deinit();
    try std.testing.expectEqual(fx.workflow.WorkflowStatus.running, state.workflow_status);
    try std.testing.expectEqual(@as(u64, 1), state.last_sequence);

    const recovered_segment = try tmp.dir.readFileAlloc(
        std.testing.io,
        segment_name,
        std.testing.allocator,
        std.Io.Limit.limited(16 * 1024),
    );
    defer std.testing.allocator.free(recovered_segment);
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, recovered_segment, "\n"));
    try std.testing.expect(std.mem.indexOf(u8, recovered_segment, partial) == null);
}

test "file workflow journal snapshot plus tail replay equals full replay after reopen" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const events = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8, .name = "snap", .idempotency_key = "start" },
        .{ .sequence = 2, .kind = .activity_scheduled, .workflow_id = 7, .execution_id = 8, .activity_id = 10, .attempt = 1, .name = "charge", .idempotency_key = "activity" },
        .{ .sequence = 3, .kind = .activity_completed, .workflow_id = 7, .execution_id = 8, .activity_id = 10, .attempt = 1, .idempotency_key = "activity-done" },
        .{ .sequence = 4, .kind = .timer_scheduled, .workflow_id = 7, .execution_id = 8, .timer_id = 20, .name = "wake", .idempotency_key = "timer" },
        .{ .sequence = 5, .kind = .timer_fired, .workflow_id = 7, .execution_id = 8, .timer_id = 20, .idempotency_key = "timer-fired" },
    };

    var expected = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &events);
    defer expected.deinit();

    {
        var store = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
        defer store.deinit();
        for (events[0..3]) |event| _ = try store.append(.{ .event = event });

        const publication = try store.writeReplaySnapshot(null);
        defer publication.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(u64, 3), publication.last_sequence);

        for (events[3..]) |event| _ = try store.append(.{ .event = event });
    }

    {
        var reopened = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
        defer reopened.deinit();

        var actual = try reopened.latestState(std.testing.allocator);
        defer actual.deinit();
        try expectWorkflowReplayStatesEqual(&expected, &actual);
    }
}

test "file workflow journal ignores uncommitted checkpoint files" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const events = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8, .idempotency_key = "start" },
        .{ .sequence = 2, .kind = .workflow_completed, .workflow_id = 7, .execution_id = 8, .idempotency_key = "complete" },
    };

    {
        var store = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
        defer store.deinit();
        for (events[0..1]) |event| _ = try store.append(.{ .event = event });

        var state = try store.latestState(std.testing.allocator);
        defer state.deinit();
        const checkpoint_json = try fx.workflow.formatWorkflowCheckpointJson(std.testing.allocator, &state);
        defer std.testing.allocator.free(checkpoint_json);
        const checkpoint_name = try fx.workflow.checkpointFileName(std.testing.allocator, state.last_sequence);
        defer std.testing.allocator.free(checkpoint_name);
        const file = try tmp.dir.createFile(std.testing.io, checkpoint_name, .{ .read = true });
        defer file.close(std.testing.io);
        try file.writeStreamingAll(std.testing.io, checkpoint_json);

        _ = try store.append(.{ .event = events[1] });
    }

    var expected = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &events);
    defer expected.deinit();

    var reopened = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer reopened.deinit();
    var actual = try reopened.latestState(std.testing.allocator);
    defer actual.deinit();
    try expectWorkflowReplayStatesEqual(&expected, &actual);
}

test "file workflow journal archive export writes replayable json lines" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const events = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8, .idempotency_key = "start" },
        .{ .sequence = 2, .kind = .activity_scheduled, .workflow_id = 7, .execution_id = 8, .activity_id = 10, .name = "charge", .idempotency_key = "activity" },
        .{ .sequence = 3, .kind = .activity_completed, .workflow_id = 7, .execution_id = 8, .activity_id = 10, .idempotency_key = "activity-done" },
    };

    var expected = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &events);
    defer expected.deinit();

    var store = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer store.deinit();
    for (events) |event| _ = try store.append(.{ .event = event });

    const exported = try store.exportArchive(1, 3);
    defer exported.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("workflow-archive-0000000000000001-0000000000000003.jsonl", exported.archive_name);
    try std.testing.expectEqual(@as(usize, 3), exported.event_count);

    const archive = try tmp.dir.readFileAlloc(std.testing.io, exported.archive_name, std.testing.allocator, std.Io.Limit.limited(16 * 1024));
    defer std.testing.allocator.free(archive);
    try std.testing.expectEqual(@as(usize, 3), std.mem.count(u8, archive, "\n"));

    var archived_events = try parseWorkflowJsonLines(std.testing.allocator, archive);
    defer archived_events.deinit();
    var actual = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, archived_events.events);
    defer actual.deinit();
    try expectWorkflowReplayStatesEqual(&expected, &actual);
}

test "file workflow journal compacts completed workflow after archive and snapshot commit" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const events = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8, .idempotency_key = "start" },
        .{ .sequence = 2, .kind = .activity_scheduled, .workflow_id = 7, .execution_id = 8, .activity_id = 10, .name = "charge", .idempotency_key = "activity" },
        .{ .sequence = 3, .kind = .activity_completed, .workflow_id = 7, .execution_id = 8, .activity_id = 10, .idempotency_key = "activity-done" },
        .{ .sequence = 4, .kind = .workflow_completed, .workflow_id = 7, .execution_id = 8, .idempotency_key = "complete" },
    };
    var expected = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &events);
    defer expected.deinit();

    {
        var store = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
        defer store.deinit();
        for (events) |event| _ = try store.append(.{ .event = event });

        const result = try store.compactCompleted(.{ .export_archive = true });
        defer result.deinit(std.testing.allocator);
        try std.testing.expect(result.compacted);
        try std.testing.expectEqual(@as(u64, 4), result.last_sequence.?);
        try std.testing.expectEqual(@as(usize, 4), result.archived_event_count);

        var state = try store.latestState(std.testing.allocator);
        defer state.deinit();
        try expectWorkflowReplayStatesEqual(&expected, &state);
    }

    const segment_name = try fx.workflow.segmentFileName(std.testing.allocator, 1);
    defer std.testing.allocator.free(segment_name);
    const compacted_segment = try tmp.dir.readFileAlloc(std.testing.io, segment_name, std.testing.allocator, std.Io.Limit.limited(16 * 1024));
    defer std.testing.allocator.free(compacted_segment);
    try std.testing.expectEqual(@as(usize, 0), compacted_segment.len);

    var reopened = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer reopened.deinit();
    var actual = try reopened.latestState(std.testing.allocator);
    defer actual.deinit();
    try expectWorkflowReplayStatesEqual(&expected, &actual);
}

test "file workflow journal compaction leaves running workflow untouched" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var store = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer store.deinit();
    _ = try store.append(.{ .event = .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8, .idempotency_key = "start" } });

    const result = try store.compactCompleted(.{ .export_archive = true });
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(!result.compacted);
}

test "file workflow journal crash after snapshot commit replays without losing acknowledged rows" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const events = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8, .idempotency_key = "start" },
        .{ .sequence = 2, .kind = .workflow_completed, .workflow_id = 7, .execution_id = 8, .idempotency_key = "complete" },
    };
    var expected = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &events);
    defer expected.deinit();

    {
        var store = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
        defer store.deinit();
        for (events) |event| _ = try store.append(.{ .event = event });
        const publication = try store.writeReplaySnapshot(null);
        defer publication.deinit(std.testing.allocator);
    }

    var reopened = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer reopened.deinit();
    var actual = try reopened.latestState(std.testing.allocator);
    defer actual.deinit();
    try expectWorkflowReplayStatesEqual(&expected, &actual);
}

test "workflow retention keep all leaves completed segment intact" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var store = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{
        .retention_policy = .{ .completed = .keep_all },
    });
    defer store.deinit();
    _ = try store.append(.{ .event = .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8, .idempotency_key = "start" } });
    _ = try store.append(.{ .event = .{ .sequence = 2, .kind = .workflow_completed, .workflow_id = 7, .execution_id = 8, .idempotency_key = "complete" } });

    const result = try store.applyRetentionPolicy();
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(!result.compacted);

    const segment_name = try fx.workflow.segmentFileName(std.testing.allocator, 1);
    defer std.testing.allocator.free(segment_name);
    const segment = try tmp.dir.readFileAlloc(std.testing.io, segment_name, std.testing.allocator, std.Io.Limit.limited(16 * 1024));
    defer std.testing.allocator.free(segment);
    try std.testing.expectEqual(@as(usize, 2), std.mem.count(u8, segment, "\n"));
}

test "workflow retention archive then compact completed exports archive" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var store = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{
        .retention_policy = .{ .completed = .archive_then_compact_completed },
    });
    defer store.deinit();
    _ = try store.append(.{ .event = .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8, .idempotency_key = "start" } });
    _ = try store.append(.{ .event = .{ .sequence = 2, .kind = .workflow_completed, .workflow_id = 7, .execution_id = 8, .idempotency_key = "complete" } });

    const result = try store.applyRetentionPolicy();
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(result.compacted);
    try std.testing.expect(result.archive_name != null);
}

test "workflow retention checkpoint only completed skips archive export" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var store = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{
        .retention_policy = .{ .completed = .checkpoint_only_completed },
    });
    defer store.deinit();
    _ = try store.append(.{ .event = .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8, .idempotency_key = "start" } });
    _ = try store.append(.{ .event = .{ .sequence = 2, .kind = .workflow_completed, .workflow_id = 7, .execution_id = 8, .idempotency_key = "complete" } });

    const result = try store.applyRetentionPolicy();
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(result.compacted);
    try std.testing.expect(result.archive_name == null);
}

test "file journal refuses future schema versions without truncating" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const segment_name = try fx.workflow.segmentFileName(std.testing.allocator, 1);
    defer std.testing.allocator.free(segment_name);

    const started_json = try fx.workflow.formatWorkflowEventJson(std.testing.allocator, .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .name = "future-runtime",
        .status = "running",
        .idempotency_key = "future-start",
    });
    defer std.testing.allocator.free(started_json);
    const future_json = try replaceFirstOwned(std.testing.allocator, started_json, "\"schema_version\":1", "\"schema_version\":2");
    defer std.testing.allocator.free(future_json);

    {
        const file = try tmp.dir.createFile(std.testing.io, segment_name, .{ .read = true });
        defer file.close(std.testing.io);
        try file.writeStreamingAll(std.testing.io, future_json);
        try file.writeStreamingAll(std.testing.io, "\n");
    }

    try std.testing.expectError(
        error.JournalRequiresNewerRuntime,
        fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{}),
    );

    const recovered_segment = try tmp.dir.readFileAlloc(
        std.testing.io,
        segment_name,
        std.testing.allocator,
        std.Io.Limit.limited(16 * 1024),
    );
    defer std.testing.allocator.free(recovered_segment);
    try std.testing.expect(std.mem.indexOf(u8, recovered_segment, "\"schema_version\":2") != null);
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, recovered_segment, "\n"));
}

test "file workflow journal store reports complete-row corruption" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const segment_name = try fx.workflow.segmentFileName(std.testing.allocator, 1);
    defer std.testing.allocator.free(segment_name);

    {
        const file = try tmp.dir.createFile(std.testing.io, segment_name, .{ .read = true });
        defer file.close(std.testing.io);
        try file.writeStreamingAll(std.testing.io, "{\"schema\":\"not-json\"\n");
    }

    var store = try fx.workflow.FileJournalStore.init(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer store.deinit();
    try store.acquireLock();
    try std.testing.expectError(error.CorruptJournal, store.recover());

    const report = store.lastCorruption().?;
    try std.testing.expectEqualStrings(segment_name, report.segment_name);
    try std.testing.expectEqual(@as(u64, 0), report.offset);
    try std.testing.expectEqual(fx.workflow.JournalCorruptionReason.invalid_json, report.reason);
}

test "file workflow journal store lock rejects a second local opener" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var first = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer first.deinit();

    try std.testing.expectError(
        error.JournalStoreLocked,
        fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{}),
    );
}

test "file workflow journal store fsync policy is observable after appends" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var store = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{ .fsync_policy = .after_append });
    defer store.deinit();

    _ = try store.append(.{
        .event = .{
            .sequence = 1,
            .kind = .workflow_started,
            .workflow_id = 7,
            .execution_id = 8,
            .idempotency_key = "start",
        },
    });
    _ = try store.append(.{
        .event = .{
            .sequence = 2,
            .kind = .workflow_completed,
            .workflow_id = 7,
            .execution_id = 8,
            .idempotency_key = "complete",
        },
    });

    try std.testing.expectEqual(@as(u64, 2), store.syncCount());
}

test "workflow checkpoint json round-trips replay-equivalent state" {
    const events = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
        .{ .sequence = 2, .kind = .activity_scheduled, .workflow_id = 7, .execution_id = 8, .activity_id = 10, .attempt = 1, .name = "charge" },
        .{ .sequence = 3, .kind = .activity_completed, .workflow_id = 7, .execution_id = 8, .activity_id = 10, .attempt = 1 },
        .{ .sequence = 4, .kind = .timer_scheduled, .workflow_id = 7, .execution_id = 8, .timer_id = 20, .name = "wake-up" },
        .{ .sequence = 5, .kind = .timer_fired, .workflow_id = 7, .execution_id = 8, .timer_id = 20 },
        .{ .sequence = 6, .kind = .deferred_created, .workflow_id = 7, .execution_id = 8, .deferred_id = 30, .name = "approval" },
        .{ .sequence = 7, .kind = .deferred_completed, .workflow_id = 7, .execution_id = 8, .deferred_id = 30 },
        .{ .sequence = 8, .kind = .queue_offered, .workflow_id = 7, .execution_id = 8, .queue_id = 40, .name = "mailbox" },
        .{ .sequence = 9, .kind = .queue_acked, .workflow_id = 7, .execution_id = 8, .queue_id = 40 },
        .{ .sequence = 10, .kind = .compensation_registered, .workflow_id = 7, .execution_id = 8, .compensation_id = 50, .name = "refund-charge" },
        .{ .sequence = 11, .kind = .compensation_completed, .workflow_id = 7, .execution_id = 8, .compensation_id = 50 },
    };

    var state = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &events);
    defer state.deinit();

    const checkpoint_json = try fx.workflow.formatWorkflowCheckpointJson(std.testing.allocator, &state);
    defer std.testing.allocator.free(checkpoint_json);

    try std.testing.expect(std.mem.indexOf(u8, checkpoint_json, "\"schema\":\"zigeffect.workflow.checkpoint.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, checkpoint_json, "\"activity_id\":10") != null);
    try std.testing.expect(std.mem.indexOf(u8, checkpoint_json, "\"attempt\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, checkpoint_json, "\"queue_id\":40") != null);
    try std.testing.expect(std.mem.indexOf(u8, checkpoint_json, "\"compensations\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, checkpoint_json, "\"compensation_id\":50") != null);

    var parsed = try fx.workflow.parseWorkflowCheckpointJson(std.testing.allocator, checkpoint_json);
    defer parsed.deinit();

    try expectWorkflowReplayStatesEqual(&state, &parsed);
    try std.testing.expectEqual(@as(u32, 1), parsed.activities.items[0].attempt);
    try std.testing.expectEqual(fx.workflow.CompensationStatus.completed, parsed.compensations.items[0].status);
}

test "workflow snapshot commit json round-trips file references" {
    const checkpoint_name = try fx.workflow.checkpointFileName(std.testing.allocator, 42);
    defer std.testing.allocator.free(checkpoint_name);
    const commit_name = try fx.workflow.snapshotCommitFileName(std.testing.allocator, 42);
    defer std.testing.allocator.free(commit_name);
    const archive_name = try fx.workflow.archiveFileName(std.testing.allocator, 1, 42);
    defer std.testing.allocator.free(archive_name);

    try std.testing.expectEqualStrings("workflow-snapshot-commit-0000000000000042.json", commit_name);
    try std.testing.expectEqualStrings("workflow-archive-0000000000000001-0000000000000042.jsonl", archive_name);

    const json = try fx.workflow.formatWorkflowSnapshotCommitJson(std.testing.allocator, .{
        .last_sequence = 42,
        .checkpoint_name = checkpoint_name,
        .segment_name = "workflow-0000000000000001.jsonl",
        .archive_name = archive_name,
    });
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema\":\"zigeffect.workflow.snapshot-commit.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"archive_name\":\"workflow-archive-0000000000000001-0000000000000042.jsonl\"") != null);

    var parsed = try fx.workflow.parseWorkflowSnapshotCommitJson(std.testing.allocator, json);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(u64, 42), parsed.last_sequence);
    try std.testing.expectEqualStrings(checkpoint_name, parsed.checkpoint_name);
    try std.testing.expectEqualStrings("workflow-0000000000000001.jsonl", parsed.segment_name);
    try std.testing.expectEqualStrings(archive_name, parsed.archive_name.?);
}

test "in-memory journal store can validate compacted tail sequence" {
    var store = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer store.deinit();
    store.resetFromSequence(3);

    _ = try store.append(.{
        .event = .{ .sequence = 4, .kind = .workflow_completed, .workflow_id = 7, .execution_id = 8, .idempotency_key = "completed" },
    });

    try std.testing.expectError(error.SequenceConflict, store.append(.{
        .event = .{ .sequence = 4, .kind = .workflow_completed, .workflow_id = 7, .execution_id = 8, .idempotency_key = "duplicate-sequence" },
    }));
}

test "workflow definition exposes metadata requirements and execution ids" {
    const Payload = struct {
        account_id: u64,
        region: []const u8,
    };
    const Success = struct {
        approved: bool,
    };
    const Failure = error{Rejected};
    const Helpers = struct {
        fn key(allocator: std.mem.Allocator, payload: Payload) ![]const u8 {
            return std.fmt.allocPrint(allocator, "{d}:{s}", .{ payload.account_id, payload.region });
        }
    };

    const Approval = fx.workflow
        .Workflow("approval", Payload, Success, Failure, fx.TestServices)
        .withIdempotencyKey(Helpers.key)
        .requires(.{ fx.Logger, fx.Config });

    try std.testing.expect(Approval.PayloadType == Payload);
    try std.testing.expect(Approval.SuccessType == Success);
    try std.testing.expect(Approval.FailureType == Failure);
    try std.testing.expect(Approval.EnvType == fx.TestServices);
    try std.testing.expectEqual(@as(usize, 2), Approval.RequiredServices.len);

    const metadata = Approval.metadata();
    try std.testing.expectEqualStrings("approval", metadata.name);
    try std.testing.expectEqualStrings(@typeName(Payload), metadata.payload_type_name);
    try std.testing.expectEqualStrings(@typeName(Success), metadata.success_type_name);
    try std.testing.expectEqualStrings(@typeName(Failure), metadata.failure_type_name);
    try std.testing.expectEqualStrings(@typeName(fx.TestServices), metadata.env_type_name);
    try std.testing.expectEqual(@as(usize, 2), metadata.requirement_count);
    try std.testing.expect(metadata.has_idempotency_key);

    var required = try Approval.requiredServices(std.testing.allocator);
    defer required.deinit();
    try std.testing.expect(required.contains(@typeName(fx.Logger)));
    try std.testing.expect(required.contains(@typeName(fx.Config)));

    const payload = Payload{ .account_id = 42, .region = "eu" };
    const key = try Approval.idempotencyKey(std.testing.allocator, payload);
    defer std.testing.allocator.free(key);
    try std.testing.expectEqualStrings("42:eu", key);

    const execution_id = try Approval.deriveExecutionId(std.testing.allocator, payload);
    const same_execution_id = try Approval.deriveExecutionId(std.testing.allocator, payload);
    const different_execution_id = try Approval.deriveExecutionId(std.testing.allocator, .{ .account_id = 43, .region = "eu" });
    try std.testing.expectEqual(execution_id, same_execution_id);
    try std.testing.expect(execution_id != different_execution_id);
}

test "activity definition exposes metadata formatting requirements and retry policy" {
    const Payload = struct {
        invoice_id: u64,
        cents: u64,
    };
    const Success = struct {
        charge_id: []const u8,
    };
    const Failure = error{Declined};
    const Helpers = struct {
        fn key(allocator: std.mem.Allocator, payload: Payload) ![]const u8 {
            return std.fmt.allocPrint(allocator, "invoice:{d}:{d}", .{ payload.invoice_id, payload.cents });
        }
    };

    const ChargeCard = fx.workflow
        .Activity("charge-card", Payload, Success, Failure, fx.TestServices)
        .withIdempotencyKey(Helpers.key)
        .withRetrySchedule(fx.Schedule.fixed(.{ .max_retries = 3, .delay_ms = 25 }).withLabel("charge-retry"))
        .withTimeoutMs(30_000)
        .withCompensation("refund-charge")
        .requires(.{fx.Logger});

    try std.testing.expect(ChargeCard.PayloadType == Payload);
    try std.testing.expect(ChargeCard.SuccessType == Success);
    try std.testing.expect(ChargeCard.FailureType == Failure);
    try std.testing.expect(ChargeCard.EnvType == fx.TestServices);
    try std.testing.expectEqual(@as(usize, 1), ChargeCard.RequiredServices.len);

    const metadata = ChargeCard.metadata();
    try std.testing.expectEqualStrings("charge-card", metadata.name);
    try std.testing.expect(metadata.has_idempotency_key);
    try std.testing.expect(metadata.has_retry_schedule);
    try std.testing.expectEqualStrings("charge-retry", metadata.retry_schedule_label);
    try std.testing.expectEqual(@as(?u64, 30_000), metadata.timeout_ms);
    try std.testing.expectEqualStrings("refund-charge", metadata.compensation_name);
    try std.testing.expectEqual(@as(usize, 1), metadata.requirement_count);

    var retry = ChargeCard.retrySchedule().?;
    try std.testing.expectEqualStrings("charge-retry", retry.labelOrKind());

    var required = try ChargeCard.requiredServices(std.testing.allocator);
    defer required.deinit();
    try std.testing.expect(required.contains(@typeName(fx.Logger)));

    const payload = Payload{ .invoice_id = 77, .cents = 1299 };
    const key = try ChargeCard.idempotencyKey(std.testing.allocator, payload);
    defer std.testing.allocator.free(key);
    try std.testing.expectEqualStrings("invoice:77:1299", key);

    const formatted = try ChargeCard.format(std.testing.allocator);
    defer std.testing.allocator.free(formatted);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "activity: charge-card") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "retry: charge-retry") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "timeout_ms: 30000") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "compensation: refund-charge") != null);
}

test "workflow engine registers starts polls inspects and lists execution" {
    const Payload = struct {
        request_id: u64,
    };
    const Success = struct {
        accepted: bool,
    };
    const Failure = error{Rejected};
    const Helpers = struct {
        fn key(allocator: std.mem.Allocator, payload: Payload) ![]const u8 {
            return std.fmt.allocPrint(allocator, "request:{d}", .{payload.request_id});
        }
    };
    const NoopWorkflow = fx.workflow
        .Workflow("noop", Payload, Success, Failure, fx.TestServices)
        .withIdempotencyKey(Helpers.key)
        .requires(.{fx.Logger});

    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    var journal = journal_memory.asJournalStore();

    var engine = try fx.workflow.WorkflowEngine.initWithProviders(std.testing.allocator, journal, .{fx.Logger});
    defer engine.deinit();

    try engine.register(NoopWorkflow);
    const execution = try engine.execute(NoopWorkflow, .{ .request_id = 42 });
    try std.testing.expectEqual(fx.workflow.WorkflowExecutionStatus.running, execution.status);
    try std.testing.expectEqualStrings("noop", execution.workflow_name);

    const result = try engine.poll(NoopWorkflow, execution.execution_id);
    switch (result) {
        .running => |running| try std.testing.expectEqual(execution.execution_id, running.execution_id),
        else => return error.ExpectedRunningWorkflow,
    }

    const inspected = engine.inspect(execution.execution_id) orelse return error.ExpectedWorkflowExecution;
    try std.testing.expectEqual(execution.workflow_id, inspected.workflow_id);
    try std.testing.expectEqual(execution.execution_id, inspected.execution_id);

    var listed = try engine.list(std.testing.allocator);
    defer listed.deinit();
    try std.testing.expectEqual(@as(usize, 1), listed.executions.len);
    try std.testing.expectEqual(execution.execution_id, listed.executions[0].execution_id);

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 1), events.events.len);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_started, events.events[0].kind);
    try std.testing.expectEqual(execution.workflow_id, events.events[0].workflow_id);
    try std.testing.expectEqual(execution.execution_id, events.events[0].execution_id);
    try std.testing.expectEqualStrings("noop", events.events[0].name);
    try std.testing.expectEqualStrings("running", events.events[0].status);
    try std.testing.expectEqualStrings("request:42", events.events[0].idempotency_key);
}

test "workflow engine rejects duplicate executions and missing providers" {
    const Payload = struct {
        request_id: u64,
    };
    const Success = void;
    const Failure = error{Rejected};
    const Helpers = struct {
        fn key(allocator: std.mem.Allocator, payload: Payload) ![]const u8 {
            return std.fmt.allocPrint(allocator, "request:{d}", .{payload.request_id});
        }
    };
    const RequiredWorkflow = fx.workflow
        .Workflow("requires-logger", Payload, Success, Failure, fx.TestServices)
        .withIdempotencyKey(Helpers.key)
        .requires(.{fx.Logger});

    {
        var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
        defer journal_memory.deinit();
        const journal = journal_memory.asJournalStore();

        var engine = fx.workflow.WorkflowEngine.init(std.testing.allocator, journal);
        defer engine.deinit();
        try std.testing.expectError(error.MissingServiceRequirement, engine.register(RequiredWorkflow));
    }

    {
        var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
        defer journal_memory.deinit();
        const journal = journal_memory.asJournalStore();

        var engine = try fx.workflow.WorkflowEngine.initWithProviders(std.testing.allocator, journal, .{fx.Logger});
        defer engine.deinit();

        try engine.register(RequiredWorkflow);
        _ = try engine.execute(RequiredWorkflow, .{ .request_id = 42 });
        try std.testing.expectError(
            error.DuplicateWorkflowExecution,
            engine.execute(RequiredWorkflow, .{ .request_id = 42 }),
        );

        var events = try journal.readAll(std.testing.allocator);
        defer events.deinit();
        try std.testing.expectEqual(@as(usize, 1), events.events.len);
    }
}

test "workflow engine starts child workflows durably and idempotently" {
    const Payload = struct { request_id: u64 };
    const Helpers = struct {
        fn key(allocator: std.mem.Allocator, payload: Payload) ![]const u8 {
            return std.fmt.allocPrint(allocator, "request:{d}", .{payload.request_id});
        }
    };
    const ParentWorkflow = fx.workflow
        .Workflow("parent", Payload, void, error{Failed}, fx.TestServices)
        .withIdempotencyKey(Helpers.key);
    const ChildWorkflow = fx.workflow
        .Workflow("child", Payload, void, error{Failed}, fx.TestServices)
        .withIdempotencyKey(Helpers.key);

    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();
    var engine = fx.workflow.WorkflowEngine.init(std.testing.allocator, journal);
    defer engine.deinit();

    try engine.register(ParentWorkflow);
    try engine.register(ChildWorkflow);
    const parent = try engine.execute(ParentWorkflow, .{ .request_id = 1 });
    const child = try engine.executeChild(parent.workflow_id, parent.execution_id, ChildWorkflow, .{ .request_id = 2 });
    const duplicate = try engine.executeChild(parent.workflow_id, parent.execution_id, ChildWorkflow, .{ .request_id = 2 });

    try std.testing.expectEqual(child.execution_id, duplicate.execution_id);
    try std.testing.expectEqual(@as(?u64, parent.workflow_id), child.parent_workflow_id);
    try std.testing.expectEqual(@as(?u64, parent.execution_id), child.parent_execution_id);
    try std.testing.expectError(
        error.ParentWorkflowNotFound,
        engine.executeChild(parent.workflow_id + 1, parent.execution_id, ChildWorkflow, .{ .request_id = 3 }),
    );

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 2), events.events.len);
    try std.testing.expectEqual(@as(?u64, parent.started_sequence), events.events[1].parent_sequence);
    try std.testing.expectEqual(@as(?u64, parent.workflow_id), events.events[1].parent_workflow_id);
    try std.testing.expectEqual(@as(?u64, parent.execution_id), events.events[1].parent_execution_id);
}

test "workflow engine stores backend capabilities and checks requirements" {
    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();

    var engine = fx.workflow.WorkflowEngine.initWithBackend(
        std.testing.allocator,
        journal_memory.asJournalStore(),
        fx.durableLocalBackend(),
    );
    defer engine.deinit();

    try std.testing.expectEqual(fx.BackendKind.durable_local, engine.backendCapabilities().kind);
    try engine.requireBackendFeature(.{
        .feature = .timer,
        .operation = "workflow.sleep",
        .workflow_name = "approval",
    });
}

test "workflow engine formats backend requirement diagnostics" {
    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();

    var engine = fx.workflow.WorkflowEngine.init(std.testing.allocator, journal_memory.asJournalStore());
    defer engine.deinit();

    const requirement = fx.workflow.WorkflowBackendRequirement{
        .feature = .timer,
        .operation = "workflow.sleep",
        .workflow_name = "approval",
    };

    try std.testing.expectError(error.UnsupportedBackendCapability, engine.requireBackendFeature(requirement));
    const diagnostic = try engine.formatBackendRequirementDiagnostic(std.testing.allocator, requirement);
    defer std.testing.allocator.free(diagnostic);
    try std.testing.expect(std.mem.indexOf(u8, diagnostic, "backend=deterministic") != null);
    try std.testing.expect(std.mem.indexOf(u8, diagnostic, "workflow=approval") != null);
}

test "workflow context replays recorded u64 step without rerunning function" {
    const Step = struct {
        var calls: u64 = 0;

        fn run() !u64 {
            calls += 1;
            return 42;
        }
    };
    Step.calls = 0;

    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    _ = try journal.append(.{
        .event = .{
            .sequence = 1,
            .kind = .workflow_started,
            .workflow_id = 7,
            .execution_id = 8,
            .name = "stepper",
            .status = "running",
            .idempotency_key = "stepper:1",
        },
    });

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
        });
        defer context.deinit();

        const value = try context.stepU64("compute", Step.run);
        try std.testing.expectEqual(@as(u64, 42), value);
        try std.testing.expectEqual(@as(u64, 1), Step.calls);
    }

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
        });
        defer context.deinit();

        const value = try context.stepU64("compute", Step.run);
        try std.testing.expectEqual(@as(u64, 42), value);
        try std.testing.expectEqual(@as(u64, 1), Step.calls);
    }

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 3), events.events.len);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.step_started, events.events[1].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.step_completed, events.events[2].kind);
    try std.testing.expectEqualStrings("compute", events.events[2].name);
    try std.testing.expectEqualStrings("42", events.events[2].redacted_detail);
}

test "workflow context mirrors successful journal appends into attached causal store" {
    const Step = struct {
        fn run() !u64 {
            return 42;
        }
    };

    var causal = fx.CausalStore.init(std.testing.allocator);
    defer causal.deinit();
    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
        .workflow_id = 700,
        .execution_id = 800,
        .causal_store = &causal,
        .causal_run_id = 99,
    });
    defer context.deinit();

    const value = try context.stepU64("live-step", Step.run);
    try std.testing.expectEqual(@as(u64, 42), value);

    var snapshot = try causal.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 2), snapshot.events.len);
    try std.testing.expectEqual(fx.CausalEventKind.workflow_event_recorded, snapshot.events[0].kind);
    try std.testing.expectEqual(@as(?u64, 99), snapshot.events[0].run_id);
    try std.testing.expectEqual(@as(?u64, 800), snapshot.events[0].scope_id);
    try std.testing.expectEqual(@as(?u64, 700), snapshot.events[0].trace_id);
    try std.testing.expectEqualStrings("workflow.step_started", snapshot.events[0].type_name);
    try std.testing.expectEqualStrings("live-step", snapshot.events[0].label);
    try std.testing.expectEqualStrings("workflow.step_completed", snapshot.events[1].type_name);
    try std.testing.expectEqualStrings("42", snapshot.events[1].redacted_detail);
}

test "causal journal store records only successful workflow appends" {
    var causal = fx.CausalStore.init(std.testing.allocator);
    defer causal.deinit();
    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    var causal_journal = fx.workflow.CausalJournalStore.init(
        std.testing.allocator,
        journal_memory.asJournalStore(),
        &causal,
        11,
    );
    defer causal_journal.deinit();
    const journal = causal_journal.asJournalStore();

    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 700,
        .execution_id = 800,
        .name = "dedupe-workflow",
        .status = "running",
        .idempotency_key = "dedupe-start",
    } });

    try std.testing.expectError(error.DuplicateEvent, journal.append(.{ .event = .{
        .sequence = 2,
        .kind = .workflow_started,
        .workflow_id = 700,
        .execution_id = 800,
        .name = "dedupe-workflow",
        .status = "running",
        .idempotency_key = "dedupe-start",
    } }));

    var snapshot = try causal.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 1), snapshot.events.len);
    try std.testing.expectEqual(fx.CausalEventKind.workflow_event_recorded, snapshot.events[0].kind);
    try std.testing.expectEqual(@as(?u64, 11), snapshot.events[0].run_id);
    try std.testing.expectEqualStrings("workflow.workflow_started", snapshot.events[0].type_name);
}

test "causal journal store maps workflow parent sequences to causal event ids" {
    var causal = fx.CausalStore.init(std.testing.allocator);
    defer causal.deinit();
    _ = try causal.record(.{
        .kind = .run_started,
        .label = "pre-existing engine event",
    });

    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    var causal_journal = fx.workflow.CausalJournalStore.init(
        std.testing.allocator,
        journal_memory.asJournalStore(),
        &causal,
        11,
    );
    defer causal_journal.deinit();
    const journal = causal_journal.asJournalStore();

    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 700,
        .execution_id = 800,
        .name = "causal-parent-map",
        .status = "running",
        .idempotency_key = "parent-start",
    } });
    _ = try journal.append(.{ .event = .{
        .sequence = 2,
        .parent_sequence = 1,
        .kind = .step_completed,
        .workflow_id = 700,
        .execution_id = 800,
        .name = "causal-child",
        .status = "completed",
        .redacted_detail = "ok",
        .idempotency_key = "parent-child",
    } });

    var snapshot = try causal.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 3), snapshot.events.len);
    try std.testing.expectEqualStrings("pre-existing engine event", snapshot.events[0].label);
    try std.testing.expectEqualStrings("workflow.workflow_started", snapshot.events[1].type_name);
    try std.testing.expectEqualStrings("workflow.step_completed", snapshot.events[2].type_name);
    try std.testing.expectEqual(@as(?u64, snapshot.events[1].id), snapshot.events[2].parent_id);
    try std.testing.expectEqual(@as(?u64, snapshot.events[2].id), causal_journal.latestCausalId());
}

test "workflow context records failed u64 steps with typed error names" {
    const Step = struct {
        var calls: u64 = 0;

        fn fail() error{Boom}!u64 {
            calls += 1;
            return error.Boom;
        }
    };
    Step.calls = 0;

    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    _ = try journal.append(.{
        .event = .{
            .sequence = 1,
            .kind = .workflow_started,
            .workflow_id = 7,
            .execution_id = 8,
            .name = "stepper",
            .status = "running",
            .idempotency_key = "stepper:2",
        },
    });

    var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
        .workflow_id = 7,
        .execution_id = 8,
    });
    defer context.deinit();

    try std.testing.expectError(error.Boom, context.stepU64("boom", Step.fail));
    try std.testing.expectEqual(@as(u64, 1), Step.calls);

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 3), events.events.len);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.step_failed, events.events[2].kind);
    try std.testing.expectEqualStrings("boom", events.events[2].name);
    try std.testing.expectEqualStrings("failed", events.events[2].status);
    try std.testing.expectEqualStrings("exit.cause.failure:Boom", events.events[2].redacted_detail);
}

test "workflow context records and replays successful u64 activities" {
    const Payload = struct {
        account_id: u64,
    };
    const Charge = fx.workflow.Activity("charge", Payload, u64, error{Declined}, void).withIdempotencyKey(struct {
        fn key(allocator: std.mem.Allocator, payload: Payload) ![]const u8 {
            return std.fmt.allocPrint(allocator, "charge:{d}", .{payload.account_id});
        }
    }.key);
    const codec = fx.Codec(u64){
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

    _ = try journal.append(.{
        .event = .{
            .sequence = 1,
            .kind = .workflow_started,
            .workflow_id = 7,
            .execution_id = 8,
            .name = "activity-workflow",
            .status = "running",
            .idempotency_key = "activity-success",
        },
    });

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
        });
        defer context.deinit();

        const value = try context.activity(Charge, .{ .account_id = 5 }, codec, Runner.run);
        try std.testing.expectEqual(@as(u64, 104), value);
        try std.testing.expectEqual(@as(u64, 1), Runner.calls);
    }

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
        });
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
    try std.testing.expectEqual(@as(u32, 1), events.events[1].attempt);
    try std.testing.expectEqual(@as(u32, 1), events.events[2].attempt);
    try std.testing.expectEqual(@as(u32, 1), events.events[3].attempt);
    try std.testing.expectEqualStrings("104", events.events[3].redacted_detail);

    const activity_id = events.events[1].activity_id orelse return error.MissingActivityId;
    try std.testing.expectEqual(activity_id, events.events[2].activity_id.?);
    try std.testing.expectEqual(activity_id, events.events[3].activity_id.?);
    try std.testing.expect(!std.mem.eql(u8, events.events[1].idempotency_key, events.events[2].idempotency_key));
    try std.testing.expect(!std.mem.eql(u8, events.events[2].idempotency_key, events.events[3].idempotency_key));
}

test "workflow context records and replays failed u64 activities" {
    const Payload = struct {
        account_id: u64,
    };
    const Charge = fx.workflow.Activity("charge", Payload, u64, error{Declined}, void).withIdempotencyKey(struct {
        fn key(allocator: std.mem.Allocator, payload: Payload) ![]const u8 {
            return std.fmt.allocPrint(allocator, "charge:{d}", .{payload.account_id});
        }
    }.key);
    const codec = fx.Codec(u64){
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

        fn run(_: Payload) error{Declined}!u64 {
            calls += 1;
            return error.Declined;
        }
    };
    Runner.calls = 0;

    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    _ = try journal.append(.{
        .event = .{
            .sequence = 1,
            .kind = .workflow_started,
            .workflow_id = 7,
            .execution_id = 8,
            .name = "activity-workflow",
            .status = "running",
            .idempotency_key = "activity-failure",
        },
    });

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
        });
        defer context.deinit();

        try std.testing.expectError(error.Declined, context.activity(Charge, .{ .account_id = 9 }, codec, Runner.run));
        try std.testing.expectEqual(@as(u64, 1), Runner.calls);
    }

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
        });
        defer context.deinit();

        try std.testing.expectError(error.Declined, context.activity(Charge, .{ .account_id = 9 }, codec, Runner.run));
        try std.testing.expectEqual(@as(u64, 1), Runner.calls);
    }

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 4), events.events.len);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.activity_scheduled, events.events[1].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.activity_started, events.events[2].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.activity_failed, events.events[3].kind);
    try std.testing.expectEqual(@as(u32, 1), events.events[3].attempt);
    try std.testing.expectEqualStrings("failed", events.events[3].status);
    try std.testing.expectEqualStrings("exit.cause.failure:Declined", events.events[3].redacted_detail);
}

test "workflow context retries failed activities with clock and causal decisions" {
    const Payload = struct {
        account_id: u64,
    };
    const Charge = fx.workflow.Activity("charge", Payload, u64, error{Declined}, void)
        .withIdempotencyKey(struct {
            fn key(allocator: std.mem.Allocator, payload: Payload) ![]const u8 {
                return std.fmt.allocPrint(allocator, "charge:{d}", .{payload.account_id});
            }
        }.key)
        .withRetrySchedule(fx.Schedule.fixed(.{ .max_retries = 2, .delay_ms = 25 }).withLabel("charge-retry"));
    const codec = fx.Codec(u64){
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
            if (calls == 1) return error.Declined;
            return payload.account_id + 99;
        }
    };
    Runner.calls = 0;

    var clock = fx.FakeClock.fake(1_000);
    var causal = fx.CausalStore.init(std.testing.allocator);
    defer causal.deinit();
    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    _ = try journal.append(.{
        .event = .{
            .sequence = 1,
            .kind = .workflow_started,
            .workflow_id = 7,
            .execution_id = 8,
            .name = "activity-workflow",
            .status = "running",
            .idempotency_key = "activity-retry-success",
        },
    });

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
            .clock = &clock,
            .causal_store = &causal,
            .causal_run_id = 1,
        });
        defer context.deinit();

        const value = try context.activity(Charge, .{ .account_id = 5 }, codec, Runner.run);
        try std.testing.expectEqual(@as(u64, 104), value);
        try std.testing.expectEqual(@as(u64, 2), Runner.calls);
        try std.testing.expectEqual(@as(u64, 1_025), clock.nowMs());
    }

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
            .clock = &clock,
            .causal_store = &causal,
            .causal_run_id = 1,
        });
        defer context.deinit();

        const value = try context.activity(Charge, .{ .account_id = 5 }, codec, Runner.run);
        try std.testing.expectEqual(@as(u64, 104), value);
        try std.testing.expectEqual(@as(u64, 2), Runner.calls);
    }

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 7), events.events.len);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.activity_retry_scheduled, events.events[3].kind);
    try std.testing.expectEqual(@as(u32, 1), events.events[3].attempt);
    try std.testing.expectEqualStrings("retry", events.events[3].status);
    try std.testing.expectEqualStrings("attempt=0 delay_ms=25 decision=retry", events.events[3].redacted_detail);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.activity_completed, events.events[6].kind);
    try std.testing.expectEqual(@as(u32, 2), events.events[6].attempt);
    try std.testing.expectEqualStrings("104", events.events[6].redacted_detail);

    var retries = try causal.retries(std.testing.allocator, 1);
    defer retries.deinit();
    try std.testing.expectEqual(@as(usize, 1), retries.events.len);
    try std.testing.expectEqual(fx.CausalEventKind.schedule_decision, retries.events[0].kind);
    try std.testing.expectEqualStrings("charge-retry", retries.events[0].label);
    try std.testing.expectEqualStrings("retry", retries.events[0].status);
    try std.testing.expectEqualStrings("attempt=0 delay_ms=25 decision=retry", retries.events[0].redacted_detail);
}

test "workflow context records exhausted activity retry budgets" {
    const Payload = struct {
        account_id: u64,
    };
    const Charge = fx.workflow.Activity("charge", Payload, u64, error{Declined}, void)
        .withIdempotencyKey(struct {
            fn key(allocator: std.mem.Allocator, payload: Payload) ![]const u8 {
                return std.fmt.allocPrint(allocator, "charge:{d}", .{payload.account_id});
            }
        }.key)
        .withRetrySchedule(fx.Schedule.fixed(.{ .max_retries = 1, .delay_ms = 25 }).withLabel("charge-retry"));
    const codec = fx.Codec(u64){
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

        fn run(_: Payload) error{Declined}!u64 {
            calls += 1;
            return error.Declined;
        }
    };
    Runner.calls = 0;

    var clock = fx.FakeClock.fake(2_000);
    var causal = fx.CausalStore.init(std.testing.allocator);
    defer causal.deinit();
    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    _ = try journal.append(.{
        .event = .{
            .sequence = 1,
            .kind = .workflow_started,
            .workflow_id = 7,
            .execution_id = 8,
            .name = "activity-workflow",
            .status = "running",
            .idempotency_key = "activity-retry-exhausted",
        },
    });

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
            .clock = &clock,
            .causal_store = &causal,
            .causal_run_id = 2,
        });
        defer context.deinit();

        try std.testing.expectError(error.Declined, context.activity(Charge, .{ .account_id = 5 }, codec, Runner.run));
        try std.testing.expectEqual(@as(u64, 2), Runner.calls);
        try std.testing.expectEqual(@as(u64, 2_025), clock.nowMs());
    }

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
            .clock = &clock,
            .causal_store = &causal,
            .causal_run_id = 2,
        });
        defer context.deinit();

        try std.testing.expectError(error.Declined, context.activity(Charge, .{ .account_id = 5 }, codec, Runner.run));
        try std.testing.expectEqual(@as(u64, 2), Runner.calls);
    }

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 7), events.events.len);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.activity_retry_scheduled, events.events[3].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.activity_failed, events.events[6].kind);
    try std.testing.expectEqual(@as(u32, 2), events.events[6].attempt);
    try std.testing.expectEqualStrings("exhausted", events.events[6].status);
    try std.testing.expectEqualStrings(
        "attempt=1 delay_ms=null decision=exhausted;exit.cause.failure:Declined",
        events.events[6].redacted_detail,
    );

    var retries = try causal.retries(std.testing.allocator, 2);
    defer retries.deinit();
    try std.testing.expectEqual(@as(usize, 2), retries.events.len);
    try std.testing.expectEqualStrings("retry", retries.events[0].status);
    try std.testing.expectEqualStrings("exhausted", retries.events[1].status);
    try std.testing.expectEqualStrings("attempt=1 delay_ms=null decision=exhausted", retries.events[1].redacted_detail);
}

test "workflow context records and replays activity timeouts" {
    const Payload = struct {
        account_id: u64,
    };
    const Charge = fx.workflow.Activity("charge", Payload, u64, error{ActivityTimeout}, void)
        .withIdempotencyKey(struct {
            fn key(allocator: std.mem.Allocator, payload: Payload) ![]const u8 {
                return std.fmt.allocPrint(allocator, "charge:{d}", .{payload.account_id});
            }
        }.key)
        .withTimeoutMs(0);
    const codec = fx.Codec(u64){
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

        fn run(payload: Payload) error{ActivityTimeout}!u64 {
            calls += 1;
            return payload.account_id + 99;
        }
    };
    Runner.calls = 0;

    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    _ = try journal.append(.{
        .event = .{
            .sequence = 1,
            .kind = .workflow_started,
            .workflow_id = 7,
            .execution_id = 8,
            .name = "activity-workflow",
            .status = "running",
            .idempotency_key = "activity-timeout",
        },
    });

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
        });
        defer context.deinit();

        try std.testing.expectError(error.ActivityTimeout, context.activity(Charge, .{ .account_id = 5 }, codec, Runner.run));
        try std.testing.expectEqual(@as(u64, 0), Runner.calls);
    }

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
        });
        defer context.deinit();

        try std.testing.expectError(error.ActivityTimeout, context.activity(Charge, .{ .account_id = 5 }, codec, Runner.run));
        try std.testing.expectEqual(@as(u64, 0), Runner.calls);
    }

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 3), events.events.len);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.activity_scheduled, events.events[1].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.activity_timed_out, events.events[2].kind);
    try std.testing.expectEqual(@as(u32, 1), events.events[2].attempt);
    try std.testing.expectEqualStrings("timeout", events.events[2].status);
    try std.testing.expectEqualStrings("exit.cause.failure:ActivityTimeout", events.events[2].redacted_detail);
}

test "workflow context records elapsed activity timeouts" {
    const Payload = struct {
        account_id: u64,
    };
    const Charge = fx.workflow.Activity("charge", Payload, u64, error{ActivityTimeout}, void)
        .withIdempotencyKey(struct {
            fn key(allocator: std.mem.Allocator, payload: Payload) ![]const u8 {
                return std.fmt.allocPrint(allocator, "charge:{d}", .{payload.account_id});
            }
        }.key)
        .withTimeoutMs(5);
    const codec = fx.Codec(u64){
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
        var clock: ?*fx.Clock = null;

        fn run(payload: Payload) error{ActivityTimeout}!u64 {
            calls += 1;
            clock.?.sleep(10);
            return payload.account_id + 99;
        }
    };
    Runner.calls = 0;

    var clock = fx.FakeClock.fake(4_000);
    Runner.clock = &clock;
    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    _ = try journal.append(.{
        .event = .{
            .sequence = 1,
            .kind = .workflow_started,
            .workflow_id = 7,
            .execution_id = 8,
            .name = "activity-workflow",
            .status = "running",
            .idempotency_key = "activity-elapsed-timeout",
        },
    });

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
            .clock = &clock,
        });
        defer context.deinit();

        try std.testing.expectError(error.ActivityTimeout, context.activity(Charge, .{ .account_id = 5 }, codec, Runner.run));
        try std.testing.expectEqual(@as(u64, 1), Runner.calls);
    }

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
            .clock = &clock,
        });
        defer context.deinit();

        try std.testing.expectError(error.ActivityTimeout, context.activity(Charge, .{ .account_id = 5 }, codec, Runner.run));
        try std.testing.expectEqual(@as(u64, 1), Runner.calls);
    }

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 4), events.events.len);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.activity_started, events.events[2].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.activity_timed_out, events.events[3].kind);
    try std.testing.expectEqual(@as(u32, 1), events.events[3].attempt);
    try std.testing.expectEqualStrings("timeout", events.events[3].status);
    try std.testing.expectEqualStrings("exit.cause.failure:ActivityTimeout", events.events[3].redacted_detail);
}

test "workflow context runs registered compensations in reverse order" {
    const Log = struct {
        var entries: [2][]const u8 = undefined;
        var len: usize = 0;

        fn push(label: []const u8) void {
            entries[len] = label;
            len += 1;
        }
    };
    const ReleaseSeat = struct {
        fn run() !void {
            Log.push("release-seat");
        }
    };
    const RefundCharge = struct {
        fn run() !void {
            Log.push("refund-charge");
        }
    };
    Log.len = 0;

    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    _ = try journal.append(.{
        .event = .{
            .sequence = 1,
            .kind = .workflow_started,
            .workflow_id = 7,
            .execution_id = 8,
            .name = "compensating-workflow",
            .status = "running",
            .idempotency_key = "compensating-workflow",
        },
    });

    var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
        .workflow_id = 7,
        .execution_id = 8,
    });
    defer context.deinit();

    try context.registerCompensation("release-seat");
    try context.registerCompensation("refund-charge");
    try context.runCompensations(.{
        .{ .label = "release-seat", .run = ReleaseSeat.run },
        .{ .label = "refund-charge", .run = RefundCharge.run },
    });

    try std.testing.expectEqual(@as(usize, 2), Log.len);
    try std.testing.expectEqualStrings("refund-charge", Log.entries[0]);
    try std.testing.expectEqualStrings("release-seat", Log.entries[1]);

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 7), events.events.len);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.compensation_registered, events.events[1].kind);
    try std.testing.expectEqualStrings("release-seat", events.events[1].name);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.compensation_registered, events.events[2].kind);
    try std.testing.expectEqualStrings("refund-charge", events.events[2].name);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.compensation_started, events.events[3].kind);
    try std.testing.expectEqualStrings("refund-charge", events.events[3].name);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.compensation_completed, events.events[4].kind);
    try std.testing.expectEqualStrings("refund-charge", events.events[4].name);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.compensation_started, events.events[5].kind);
    try std.testing.expectEqualStrings("release-seat", events.events[5].name);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.compensation_completed, events.events[6].kind);
    try std.testing.expectEqualStrings("release-seat", events.events[6].name);
}

test "workflow context skips completed compensations on replay" {
    const RefundCharge = struct {
        var calls: u64 = 0;

        fn run() !void {
            calls += 1;
        }
    };
    RefundCharge.calls = 0;

    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();
    const id = fx.workflow.compensationId("refund-charge");

    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .name = "compensating-workflow",
        .status = "running",
        .idempotency_key = "completed-compensation",
    } });
    _ = try journal.append(.{ .event = .{
        .sequence = 2,
        .kind = .compensation_registered,
        .workflow_id = 7,
        .execution_id = 8,
        .compensation_id = id,
        .name = "refund-charge",
    } });
    _ = try journal.append(.{ .event = .{
        .sequence = 3,
        .kind = .compensation_started,
        .workflow_id = 7,
        .execution_id = 8,
        .compensation_id = id,
        .name = "refund-charge",
    } });
    _ = try journal.append(.{ .event = .{
        .sequence = 4,
        .kind = .compensation_completed,
        .workflow_id = 7,
        .execution_id = 8,
        .compensation_id = id,
        .name = "refund-charge",
    } });

    var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
        .workflow_id = 7,
        .execution_id = 8,
    });
    defer context.deinit();

    try context.runCompensations(.{
        .{ .label = "refund-charge", .run = RefundCharge.run },
    });
    try std.testing.expectEqual(@as(u64, 0), RefundCharge.calls);

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 4), events.events.len);
}

test "workflow context awaiting a missing deferred suspends durably" {
    const codec = fx.Codec(u64){
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

    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .name = "deferred-workflow",
        .status = "running",
        .idempotency_key = "deferred-await",
    } });

    var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
        .workflow_id = 7,
        .execution_id = 8,
    });
    defer context.deinit();

    const result = try context.awaitDeferred("approval", codec, error{Rejected});
    switch (result) {
        .suspended => |suspension| {
            try std.testing.expectEqual(fx.SuspensionKind.deferred, suspension.kind);
            try std.testing.expectEqual(fx.workflow.deferredId("approval"), suspension.id);
            try std.testing.expectEqualStrings("approval", suspension.label);
        },
        else => return error.ExpectedSuspension,
    }

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 4), events.events.len);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.deferred_created, events.events[1].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.deferred_awaited, events.events[2].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_suspended, events.events[3].kind);
    try std.testing.expectEqual(fx.workflow.deferredId("approval"), events.events[1].deferred_id.?);
    try std.testing.expectEqualStrings("waiting", events.events[3].status);
}

test "durable deferred external completion replays completed values" {
    const codec = fx.Codec(u64){
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

    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .name = "deferred-workflow",
        .status = "running",
        .idempotency_key = "deferred-complete",
    } });

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
        });
        defer context.deinit();

        const result = try context.awaitDeferred("approval", codec, error{Rejected});
        switch (result) {
            .suspended => {},
            else => return error.ExpectedSuspension,
        }
    }

    var external = fx.workflow.DurableDeferred.init(std.testing.allocator, journal, 7, 8);
    try external.complete("approval", codec, @as(u64, 42));
    try external.complete("approval", codec, @as(u64, 42));

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
        });
        defer context.deinit();

        const result = try context.awaitDeferred("approval", codec, error{Rejected});
        switch (result) {
            .completed => |value| try std.testing.expectEqual(@as(u64, 42), value),
            else => return error.ExpectedCompletedDeferred,
        }
    }

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 5), events.events.len);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.deferred_completed, events.events[4].kind);
    try std.testing.expectEqual(fx.workflow.deferredId("approval"), events.events[4].deferred_id.?);
    try std.testing.expectEqualStrings("42", events.events[4].redacted_detail);
}

test "durable deferred external failure replays typed failures" {
    const codec = fx.Codec(u64){
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

    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .name = "deferred-workflow",
        .status = "running",
        .idempotency_key = "deferred-fail",
    } });

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
        });
        defer context.deinit();
        _ = try context.awaitDeferred("approval", codec, error{Rejected});
    }

    var external = fx.workflow.DurableDeferred.init(std.testing.allocator, journal, 7, 8);
    try external.fail("approval", error.Rejected);

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
        });
        defer context.deinit();

        const result = try context.awaitDeferred("approval", codec, error{Rejected});
        switch (result) {
            .failed => |err| try std.testing.expectEqual(error.Rejected, err),
            else => return error.ExpectedFailedDeferred,
        }
    }

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 5), events.events.len);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.deferred_failed, events.events[4].kind);
    try std.testing.expectEqualStrings("exit.cause.failure:Rejected", events.events[4].redacted_detail);
}

test "durable deferred external cancellation replays cancellation reasons" {
    const codec = fx.Codec(u64){
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

    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .name = "deferred-workflow",
        .status = "running",
        .idempotency_key = "deferred-cancel",
    } });

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
        });
        defer context.deinit();
        _ = try context.awaitDeferred("approval", codec, error{Rejected});
    }

    var external = fx.workflow.DurableDeferred.init(std.testing.allocator, journal, 7, 8);
    try external.cancel("approval", "operator");

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
        });
        defer context.deinit();

        const result = try context.awaitDeferred("approval", codec, error{Rejected});
        switch (result) {
            .cancelled => |reason| try std.testing.expectEqualStrings("operator", reason),
            else => return error.ExpectedCancelledDeferred,
        }
    }

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 5), events.events.len);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.deferred_cancelled, events.events[4].kind);
    try std.testing.expectEqualStrings("operator", events.events[4].redacted_detail);
}

test "workflow context waiting for a missing signal suspends durably" {
    const Approval = fx.workflow.Signal("approval", u64);
    const codec = fx.Codec(u64){
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
    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .name = "signal-workflow",
        .status = "running",
        .idempotency_key = "signal-wait",
    } });

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
        });
        defer context.deinit();

        const result = try context.waitForSignal(Approval, codec);
        switch (result) {
            .suspended => |suspension| {
                try std.testing.expectEqual(fx.SuspensionKind.signal, suspension.kind);
                try std.testing.expectEqual(fx.workflow.signalId("approval"), suspension.id);
                try std.testing.expectEqualStrings("approval", suspension.label);
            },
            else => return error.ExpectedSignalSuspension,
        }
    }

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
        });
        defer context.deinit();

        const result = try context.waitForSignal(Approval, codec);
        switch (result) {
            .suspended => {},
            else => return error.ExpectedSignalSuspension,
        }
    }

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 2), events.events.len);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_suspended, events.events[1].kind);
    try std.testing.expectEqualStrings("approval", events.events[1].name);
    try std.testing.expectEqualStrings("waiting", events.events[1].status);
    try std.testing.expectEqualStrings("signal", events.events[1].redacted_detail);
}

test "durable signal append resumes and wait consumes once" {
    const Approval = fx.workflow.Signal("approval", u64);
    const codec = fx.Codec(u64){
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
    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .name = "signal-workflow",
        .status = "running",
        .idempotency_key = "signal-consume",
    } });

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
        });
        defer context.deinit();

        const result = try context.waitForSignal(Approval, codec);
        switch (result) {
            .suspended => {},
            else => return error.ExpectedSignalSuspension,
        }
    }

    var external = fx.workflow.DurableSignal.init(std.testing.allocator, journal, 7, 8);
    try std.testing.expect(try external.send(Approval, codec, 42, "operator-1"));
    try std.testing.expect(!try external.send(Approval, codec, 42, "operator-1"));

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
        });
        defer context.deinit();

        const result = try context.waitForSignal(Approval, codec);
        switch (result) {
            .received => |value| try std.testing.expectEqual(@as(u64, 42), value),
            else => return error.ExpectedReceivedSignal,
        }
    }

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
        });
        defer context.deinit();

        const result = try context.waitForSignal(Approval, codec);
        switch (result) {
            .received => |value| try std.testing.expectEqual(@as(u64, 42), value),
            else => return error.ExpectedReceivedSignal,
        }
    }

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 5), events.events.len);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.signal_received, events.events[2].kind);
    try std.testing.expectEqualStrings("approval", events.events[2].name);
    try std.testing.expectEqualStrings("42", events.events[2].redacted_detail);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_resumed, events.events[3].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.signal_consumed, events.events[4].kind);
    try std.testing.expectEqualStrings("received", events.events[4].status);
    try std.testing.expectEqualStrings("received_sequence=3", events.events[4].redacted_detail);
}

test "workflow signal wait times out through durable timer firing" {
    const Approval = fx.workflow.Signal("approval", u64).withTimeoutMs(250);
    const codec = fx.Codec(u64){
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
    var clock = fx.FakeClock.fake(1_000);
    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .name = "signal-workflow",
        .status = "running",
        .idempotency_key = "signal-timeout",
    } });

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
            .clock = &clock,
        });
        defer context.deinit();

        const result = try context.waitForSignal(Approval, codec);
        switch (result) {
            .suspended => {},
            else => return error.ExpectedSignalSuspension,
        }
    }

    var durable_clock = fx.workflow.DurableClock.init(std.testing.allocator, journal, 7, 8);
    try std.testing.expectEqual(@as(usize, 1), try durable_clock.fireDueTimers(1_250));

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
            .clock = &clock,
        });
        defer context.deinit();

        const result = try context.waitForSignal(Approval, codec);
        switch (result) {
            .timed_out => {},
            else => return error.ExpectedSignalTimeout,
        }
    }

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
            .clock = &clock,
        });
        defer context.deinit();

        const result = try context.waitForSignal(Approval, codec);
        switch (result) {
            .timed_out => {},
            else => return error.ExpectedSignalTimeout,
        }
    }

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 6), events.events.len);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.timer_scheduled, events.events[1].kind);
    try std.testing.expectEqualStrings("signal:approval:timeout", events.events[1].name);
    try std.testing.expectEqualStrings("fire_at_ms=1250", events.events[1].redacted_detail);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_suspended, events.events[2].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.timer_fired, events.events[3].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_resumed, events.events[4].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.signal_consumed, events.events[5].kind);
    try std.testing.expectEqualStrings("timed_out", events.events[5].status);
}

test "durable signal received before timeout cancels timeout timer" {
    const Approval = fx.workflow.Signal("approval", u64).withTimeoutMs(250);
    const codec = fx.Codec(u64){
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
    var clock = fx.FakeClock.fake(1_000);
    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .name = "signal-workflow",
        .status = "running",
        .idempotency_key = "signal-before-timeout",
    } });

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
            .clock = &clock,
        });
        defer context.deinit();

        const result = try context.waitForSignal(Approval, codec);
        switch (result) {
            .suspended => {},
            else => return error.ExpectedSignalSuspension,
        }
    }

    var external = fx.workflow.DurableSignal.init(std.testing.allocator, journal, 7, 8);
    try std.testing.expect(try external.send(Approval, codec, 42, "operator-1"));

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
            .clock = &clock,
        });
        defer context.deinit();

        const result = try context.waitForSignal(Approval, codec);
        switch (result) {
            .received => |value| try std.testing.expectEqual(@as(u64, 42), value),
            else => return error.ExpectedReceivedSignal,
        }
    }

    var durable_clock = fx.workflow.DurableClock.init(std.testing.allocator, journal, 7, 8);
    try std.testing.expectEqual(@as(usize, 0), try durable_clock.fireDueTimers(1_250));

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 7), events.events.len);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.timer_scheduled, events.events[1].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.signal_received, events.events[3].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_resumed, events.events[4].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.timer_cancelled, events.events[5].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.signal_consumed, events.events[6].kind);
    try std.testing.expectEqualStrings("received", events.events[6].status);
}

test "durable signal wait receives after file journal reopen" {
    const Approval = fx.workflow.Signal("approval", u64);
    const codec = fx.Codec(u64){
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
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    {
        var file_store = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
        defer file_store.deinit();
        const journal = file_store.asJournalStore();

        _ = try journal.append(.{ .event = .{
            .sequence = 1,
            .kind = .workflow_started,
            .workflow_id = 7,
            .execution_id = 8,
            .name = "signal-workflow",
            .status = "running",
            .idempotency_key = "signal-file",
        } });

        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
        });
        defer context.deinit();

        const result = try context.waitForSignal(Approval, codec);
        switch (result) {
            .suspended => {},
            else => return error.ExpectedSignalSuspension,
        }
    }

    {
        var reopened = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
        defer reopened.deinit();
        const journal = reopened.asJournalStore();

        var external = fx.workflow.DurableSignal.init(std.testing.allocator, journal, 7, 8);
        try std.testing.expect(try external.send(Approval, codec, 42, "operator-1"));
    }

    {
        var reopened = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
        defer reopened.deinit();
        const journal = reopened.asJournalStore();

        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
        });
        defer context.deinit();

        const result = try context.waitForSignal(Approval, codec);
        switch (result) {
            .received => |value| try std.testing.expectEqual(@as(u64, 42), value),
            else => return error.ExpectedReceivedSignal,
        }

        var state = try journal.latestState(std.testing.allocator);
        defer state.deinit();
        try std.testing.expectEqual(fx.workflow.WorkflowStatus.running, state.workflow_status);
    }
}

test "durable queue offers idempotently and survives file reopen" {
    const Payload = struct {
        account_id: u64,
    };
    const Email = fx.workflow
        .Queue("email", Payload, u64, error{DeliveryFailed})
        .withIdempotencyKey(struct {
        fn key(allocator: std.mem.Allocator, payload: Payload) ![]const u8 {
            return std.fmt.allocPrint(allocator, "email:{d}", .{payload.account_id});
        }
    }.key);
    const payload_codec = fx.Codec(Payload){
        .encode = struct {
            fn encode(allocator: std.mem.Allocator, payload: Payload) ![]const u8 {
                return std.fmt.allocPrint(allocator, "{d}", .{payload.account_id});
            }
        }.encode,
        .decode = struct {
            fn decode(_: std.mem.Allocator, bytes: []const u8) !Payload {
                return .{ .account_id = try std.fmt.parseInt(u64, bytes, 10) };
            }
        }.decode,
    };
    const payload = Payload{ .account_id = 42 };

    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();
    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .name = "queue-workflow",
        .status = "running",
        .idempotency_key = "queue-offer",
    } });

    var durable_queue = fx.workflow.DurableQueue.init(std.testing.allocator, journal, 7, 8);
    const first = try durable_queue.offer(Email, payload_codec, payload);
    try std.testing.expect(first.offered);
    try std.testing.expectEqual(fx.workflow.queueItemId("email", "email:42"), first.item_id);

    const duplicate = try durable_queue.offer(Email, payload_codec, payload);
    try std.testing.expect(!duplicate.offered);
    try std.testing.expectEqual(first.item_id, duplicate.item_id);

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 2), events.events.len);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.queue_offered, events.events[1].kind);
    try std.testing.expectEqual(first.item_id, events.events[1].queue_id.?);
    try std.testing.expectEqualStrings("email", events.events[1].name);
    try std.testing.expectEqualStrings("42", events.events[1].redacted_detail);

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    {
        var file_store = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
        defer file_store.deinit();
        const file_journal = file_store.asJournalStore();
        _ = try file_journal.append(.{ .event = .{
            .sequence = 1,
            .kind = .workflow_started,
            .workflow_id = 7,
            .execution_id = 8,
            .name = "queue-workflow",
            .status = "running",
            .idempotency_key = "queue-file",
        } });
        var file_queue = fx.workflow.DurableQueue.init(std.testing.allocator, file_journal, 7, 8);
        const file_offer = try file_queue.offer(Email, payload_codec, payload);
        try std.testing.expect(file_offer.offered);
    }

    {
        var reopened = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
        defer reopened.deinit();
        const file_journal = reopened.asJournalStore();
        var file_events = try file_journal.readAll(std.testing.allocator);
        defer file_events.deinit();
        try std.testing.expectEqual(@as(usize, 2), file_events.events.len);
        try std.testing.expectEqual(fx.workflow.WorkflowEventKind.queue_offered, file_events.events[1].kind);
        try std.testing.expectEqualStrings("42", file_events.events[1].redacted_detail);
    }
}

test "durable queue claims oldest item and respects max concurrency" {
    const Payload = struct {
        account_id: u64,
    };
    const Email = fx.workflow
        .Queue("email", Payload, u64, error{DeliveryFailed})
        .withIdempotencyKey(struct {
            fn key(allocator: std.mem.Allocator, payload: Payload) ![]const u8 {
                return std.fmt.allocPrint(allocator, "email:{d}", .{payload.account_id});
            }
        }.key)
        .withMaxConcurrency(1);
    const payload_codec = fx.Codec(Payload){
        .encode = struct {
            fn encode(allocator: std.mem.Allocator, payload: Payload) ![]const u8 {
                return std.fmt.allocPrint(allocator, "{d}", .{payload.account_id});
            }
        }.encode,
        .decode = struct {
            fn decode(_: std.mem.Allocator, bytes: []const u8) !Payload {
                return .{ .account_id = try std.fmt.parseInt(u64, bytes, 10) };
            }
        }.decode,
    };

    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();
    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .name = "queue-workflow",
        .status = "running",
        .idempotency_key = "queue-claim",
    } });

    var durable_queue = fx.workflow.DurableQueue.init(std.testing.allocator, journal, 7, 8);
    const first_offer = try durable_queue.offer(Email, payload_codec, .{ .account_id = 42 });
    const second_offer = try durable_queue.offer(Email, payload_codec, .{ .account_id = 43 });

    const first_claim = (try durable_queue.claim(Email, payload_codec, "worker-a")).?;
    try std.testing.expectEqual(first_offer.item_id, first_claim.item_id);
    try std.testing.expectEqual(@as(u64, 42), first_claim.payload.account_id);
    try std.testing.expectEqual(@as(u32, 1), first_claim.attempt);
    try std.testing.expectEqualStrings("email", first_claim.name);

    try std.testing.expectEqual(@as(?fx.workflow.QueueClaim(Payload), null), try durable_queue.claim(Email, payload_codec, "worker-b"));

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 4), events.events.len);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.queue_claimed, events.events[3].kind);
    try std.testing.expectEqual(first_offer.item_id, events.events[3].queue_id.?);
    try std.testing.expectEqualStrings("worker=worker-a claim_deadline_ms=null attempt=1", events.events[3].redacted_detail);
    try std.testing.expect(first_offer.item_id != second_offer.item_id);
}

test "workflow context queue await completes and acks once" {
    const Payload = struct {
        account_id: u64,
    };
    const Email = fx.workflow
        .Queue("email", Payload, u64, error{DeliveryFailed})
        .withIdempotencyKey(struct {
        fn key(allocator: std.mem.Allocator, payload: Payload) ![]const u8 {
            return std.fmt.allocPrint(allocator, "email:{d}", .{payload.account_id});
        }
    }.key);
    const payload_codec = fx.Codec(Payload){
        .encode = struct {
            fn encode(allocator: std.mem.Allocator, payload: Payload) ![]const u8 {
                return std.fmt.allocPrint(allocator, "{d}", .{payload.account_id});
            }
        }.encode,
        .decode = struct {
            fn decode(_: std.mem.Allocator, bytes: []const u8) !Payload {
                return .{ .account_id = try std.fmt.parseInt(u64, bytes, 10) };
            }
        }.decode,
    };
    const result_codec = fx.Codec(u64){
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
    const payload = Payload{ .account_id = 42 };

    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();
    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .name = "queue-workflow",
        .status = "running",
        .idempotency_key = "queue-await",
    } });

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
        });
        defer context.deinit();

        const result = try context.queue(Email, payload_codec, result_codec, payload);
        switch (result) {
            .suspended => |suspension| {
                try std.testing.expectEqual(fx.SuspensionKind.queue, suspension.kind);
                try std.testing.expectEqual(try Email.deriveItemId(std.testing.allocator, payload), suspension.id);
                try std.testing.expectEqualStrings("email", suspension.label);
            },
            else => return error.ExpectedQueueSuspension,
        }
    }

    const item_id = try Email.deriveItemId(std.testing.allocator, payload);
    var durable_queue = fx.workflow.DurableQueue.init(std.testing.allocator, journal, 7, 8);
    try durable_queue.complete(Email, item_id, result_codec, 99);

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
        });
        defer context.deinit();

        const result = try context.queue(Email, payload_codec, result_codec, payload);
        switch (result) {
            .completed => |value| try std.testing.expectEqual(@as(u64, 99), value),
            else => return error.ExpectedCompletedQueue,
        }
    }

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
        });
        defer context.deinit();

        const result = try context.queue(Email, payload_codec, result_codec, payload);
        switch (result) {
            .completed => |value| try std.testing.expectEqual(@as(u64, 99), value),
            else => return error.ExpectedCompletedQueue,
        }
    }

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 6), events.events.len);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.queue_offered, events.events[1].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_suspended, events.events[2].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.queue_completed, events.events[3].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_resumed, events.events[4].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.queue_acked, events.events[5].kind);
}

test "workflow context queue await replays typed failure and acks once" {
    const Payload = struct {
        account_id: u64,
    };
    const Email = fx.workflow
        .Queue("email", Payload, u64, error{DeliveryFailed})
        .withIdempotencyKey(struct {
        fn key(allocator: std.mem.Allocator, payload: Payload) ![]const u8 {
            return std.fmt.allocPrint(allocator, "email:{d}", .{payload.account_id});
        }
    }.key);
    const payload_codec = fx.Codec(Payload){
        .encode = struct {
            fn encode(allocator: std.mem.Allocator, payload: Payload) ![]const u8 {
                return std.fmt.allocPrint(allocator, "{d}", .{payload.account_id});
            }
        }.encode,
        .decode = struct {
            fn decode(_: std.mem.Allocator, bytes: []const u8) !Payload {
                return .{ .account_id = try std.fmt.parseInt(u64, bytes, 10) };
            }
        }.decode,
    };
    const result_codec = fx.Codec(u64){
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
    const payload = Payload{ .account_id = 42 };

    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();
    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .name = "queue-workflow",
        .status = "running",
        .idempotency_key = "queue-fail",
    } });

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
        });
        defer context.deinit();

        const result = try context.queue(Email, payload_codec, result_codec, payload);
        switch (result) {
            .suspended => {},
            else => return error.ExpectedQueueSuspension,
        }
    }

    const item_id = try Email.deriveItemId(std.testing.allocator, payload);
    var durable_queue = fx.workflow.DurableQueue.init(std.testing.allocator, journal, 7, 8);
    try durable_queue.fail(Email, item_id, error.DeliveryFailed);

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
        });
        defer context.deinit();

        const result = try context.queue(Email, payload_codec, result_codec, payload);
        switch (result) {
            .failed => |err| try std.testing.expectEqual(error.DeliveryFailed, err),
            else => return error.ExpectedFailedQueue,
        }
    }

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
        });
        defer context.deinit();

        const result = try context.queue(Email, payload_codec, result_codec, payload);
        switch (result) {
            .failed => |err| try std.testing.expectEqual(error.DeliveryFailed, err),
            else => return error.ExpectedFailedQueue,
        }
    }

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 6), events.events.len);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.queue_failed, events.events[3].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_resumed, events.events[4].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.queue_acked, events.events[5].kind);
}

test "durable queue retries expired claims and reclaims with incremented attempt" {
    const Payload = struct {
        account_id: u64,
    };
    const Email = fx.workflow
        .Queue("email", Payload, u64, error{DeliveryFailed})
        .withIdempotencyKey(struct {
            fn key(allocator: std.mem.Allocator, payload: Payload) ![]const u8 {
                return std.fmt.allocPrint(allocator, "email:{d}", .{payload.account_id});
            }
        }.key)
        .withClaimTimeoutMs(250)
        .withMaxConcurrency(1);
    const payload_codec = fx.Codec(Payload){
        .encode = struct {
            fn encode(allocator: std.mem.Allocator, payload: Payload) ![]const u8 {
                return std.fmt.allocPrint(allocator, "{d}", .{payload.account_id});
            }
        }.encode,
        .decode = struct {
            fn decode(_: std.mem.Allocator, bytes: []const u8) !Payload {
                return .{ .account_id = try std.fmt.parseInt(u64, bytes, 10) };
            }
        }.decode,
    };
    var clock = fx.FakeClock.fake(1_000);
    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();
    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .name = "queue-workflow",
        .status = "running",
        .idempotency_key = "queue-retry",
    } });

    var durable_queue = fx.workflow.DurableQueue.initWithClock(std.testing.allocator, journal, 7, 8, &clock);
    const offer = try durable_queue.offer(Email, payload_codec, .{ .account_id = 42 });
    const first_claim = (try durable_queue.claim(Email, payload_codec, "worker-a")).?;
    try std.testing.expectEqual(offer.item_id, first_claim.item_id);
    try std.testing.expectEqual(@as(u32, 1), first_claim.attempt);

    try std.testing.expectEqual(@as(usize, 0), try durable_queue.retryExpiredClaims(Email));
    clock.sleep(249);
    try std.testing.expectEqual(@as(usize, 0), try durable_queue.retryExpiredClaims(Email));
    clock.sleep(1);
    try std.testing.expectEqual(@as(usize, 1), try durable_queue.retryExpiredClaims(Email));

    const second_claim = (try durable_queue.claim(Email, payload_codec, "worker-b")).?;
    try std.testing.expectEqual(offer.item_id, second_claim.item_id);
    try std.testing.expectEqual(@as(u32, 2), second_claim.attempt);

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 5), events.events.len);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.queue_claimed, events.events[2].kind);
    try std.testing.expectEqualStrings("worker=worker-a claim_deadline_ms=1250 attempt=1", events.events[2].redacted_detail);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.queue_retry_scheduled, events.events[3].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.queue_claimed, events.events[4].kind);
    try std.testing.expectEqualStrings("worker=worker-b claim_deadline_ms=1500 attempt=2", events.events[4].redacted_detail);
}

test "workflow context sleep schedules a durable timer and replays pending suspension" {
    var clock = fx.FakeClock.fake(1_000);
    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .name = "timer-workflow",
        .status = "running",
        .idempotency_key = "timer-sleep",
    } });

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
            .clock = &clock,
        });
        defer context.deinit();

        const result = try context.sleep("wake", 250);
        switch (result) {
            .suspended => |suspension| {
                try std.testing.expectEqual(fx.SuspensionKind.timer, suspension.kind);
                try std.testing.expectEqual(fx.workflow.timerId("wake"), suspension.id);
                try std.testing.expectEqualStrings("wake", suspension.label);
            },
            else => return error.ExpectedTimerSuspension,
        }
    }

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
            .clock = &clock,
        });
        defer context.deinit();

        const result = try context.sleep("wake", 250);
        switch (result) {
            .suspended => {},
            else => return error.ExpectedTimerSuspension,
        }
    }

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 3), events.events.len);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.timer_scheduled, events.events[1].kind);
    try std.testing.expectEqual(fx.workflow.timerId("wake"), events.events[1].timer_id.?);
    try std.testing.expectEqualStrings("fire_at_ms=1250", events.events[1].redacted_detail);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_suspended, events.events[2].kind);
    try std.testing.expectEqualStrings("waiting", events.events[2].status);
}

test "durable clock queries due timers and fires them once" {
    var clock = fx.FakeClock.fake(1_000);
    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .name = "timer-workflow",
        .status = "running",
        .idempotency_key = "timer-fire",
    } });

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
            .clock = &clock,
        });
        defer context.deinit();

        const result = try context.sleep("wake", 250);
        switch (result) {
            .suspended => {},
            else => return error.ExpectedTimerSuspension,
        }
    }

    var durable_clock = fx.workflow.DurableClock.init(std.testing.allocator, journal, 7, 8);
    var early = try durable_clock.dueTimers(1_249);
    defer early.deinit();
    try std.testing.expectEqual(@as(usize, 0), early.timers.len);

    var due = try durable_clock.dueTimers(1_250);
    defer due.deinit();
    try std.testing.expectEqual(@as(usize, 1), due.timers.len);
    try std.testing.expectEqual(fx.workflow.timerId("wake"), due.timers[0].timer_id);
    try std.testing.expectEqual(@as(u64, 7), due.timers[0].workflow_id);
    try std.testing.expectEqual(@as(u64, 8), due.timers[0].execution_id);
    try std.testing.expectEqualStrings("wake", due.timers[0].name);
    try std.testing.expectEqual(@as(u64, 1_250), due.timers[0].fire_at_ms);

    try std.testing.expectEqual(@as(usize, 1), try durable_clock.fireDueTimers(1_250));
    try std.testing.expectEqual(@as(usize, 0), try durable_clock.fireDueTimers(1_250));

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
            .clock = &clock,
        });
        defer context.deinit();

        const result = try context.sleep("wake", 250);
        switch (result) {
            .fired => {},
            else => return error.ExpectedFiredTimer,
        }
    }

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 5), events.events.len);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.timer_scheduled, events.events[1].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_suspended, events.events[2].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.timer_fired, events.events[3].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_resumed, events.events[4].kind);
}

test "durable clock cancellation wakes timer sleepers once" {
    var clock = fx.FakeClock.fake(1_000);
    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .name = "timer-workflow",
        .status = "running",
        .idempotency_key = "timer-cancel",
    } });

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
            .clock = &clock,
        });
        defer context.deinit();

        const result = try context.sleep("wake", 250);
        switch (result) {
            .suspended => {},
            else => return error.ExpectedTimerSuspension,
        }
    }

    var durable_clock = fx.workflow.DurableClock.init(std.testing.allocator, journal, 7, 8);
    try std.testing.expect(try durable_clock.cancel("wake"));
    try std.testing.expect(!try durable_clock.cancel("wake"));
    try std.testing.expectEqual(@as(usize, 0), try durable_clock.fireDueTimers(1_250));

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
            .clock = &clock,
        });
        defer context.deinit();

        const result = try context.sleep("wake", 250);
        switch (result) {
            .cancelled => {},
            else => return error.ExpectedCancelledTimer,
        }
    }

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 5), events.events.len);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.timer_cancelled, events.events[3].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_resumed, events.events[4].kind);
}

test "durable clock fires file journal timers after reopen" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var clock = fx.FakeClock.fake(1_000);

    {
        var file_store = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
        defer file_store.deinit();
        const journal = file_store.asJournalStore();

        _ = try journal.append(.{ .event = .{
            .sequence = 1,
            .kind = .workflow_started,
            .workflow_id = 7,
            .execution_id = 8,
            .name = "timer-workflow",
            .status = "running",
            .idempotency_key = "timer-file",
        } });

        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
            .clock = &clock,
        });
        defer context.deinit();

        const result = try context.sleep("wake", 250);
        switch (result) {
            .suspended => {},
            else => return error.ExpectedTimerSuspension,
        }
    }

    {
        var reopened = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
        defer reopened.deinit();
        const journal = reopened.asJournalStore();

        var durable_clock = fx.workflow.DurableClock.init(std.testing.allocator, journal, 7, 8);
        try std.testing.expectEqual(@as(usize, 1), try durable_clock.fireDueTimers(1_250));

        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
            .clock = &clock,
        });
        defer context.deinit();

        const result = try context.sleep("wake", 250);
        switch (result) {
            .fired => {},
            else => return error.ExpectedFiredTimer,
        }

        var state = try journal.latestState(std.testing.allocator);
        defer state.deinit();
        try std.testing.expectEqual(fx.workflow.WorkflowStatus.running, state.workflow_status);
        try std.testing.expectEqual(fx.workflow.TimerStatus.fired, state.timers.items[0].status);
    }
}

test "workflow context records failed compensation cause details" {
    const RefundCharge = struct {
        var calls: u64 = 0;

        fn run() error{RefundFailed}!void {
            calls += 1;
            return error.RefundFailed;
        }
    };
    RefundCharge.calls = 0;

    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .name = "compensating-workflow",
        .status = "running",
        .idempotency_key = "failed-compensation",
    } });

    var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
        .workflow_id = 7,
        .execution_id = 8,
    });
    defer context.deinit();

    try context.registerCompensation("refund-charge");
    try std.testing.expectError(error.RefundFailed, context.runCompensations(.{
        .{ .label = "refund-charge", .run = RefundCharge.run },
    }));
    try std.testing.expectEqual(@as(u64, 1), RefundCharge.calls);

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 4), events.events.len);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.compensation_started, events.events[2].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.compensation_failed, events.events[3].kind);
    try std.testing.expectEqualStrings("failed", events.events[3].status);
    try std.testing.expectEqualStrings("exit.cause.failure:RefundFailed", events.events[3].redacted_detail);
}
