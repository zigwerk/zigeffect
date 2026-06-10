const std = @import("std");
const fx = @import("zigeffect");

pub fn expectReplayStatesEqual(
    expected: *const fx.workflow.WorkflowReplayState,
    actual: *const fx.workflow.WorkflowReplayState,
) !void {
    try std.testing.expectEqual(expected.workflow_status, actual.workflow_status);
    try std.testing.expectEqual(expected.workflow_id, actual.workflow_id);
    try std.testing.expectEqual(expected.execution_id, actual.execution_id);
    try std.testing.expectEqual(expected.last_sequence, actual.last_sequence);

    try expectActivitiesEqual(expected.activities.items, actual.activities.items);
    try expectTimersEqual(expected.timers.items, actual.timers.items);
    try expectDeferredsEqual(expected.deferreds.items, actual.deferreds.items);
    try expectQueuesEqual(expected.queues.items, actual.queues.items);
    try expectCompensationsEqual(expected.compensations.items, actual.compensations.items);
}

fn expectActivitiesEqual(
    expected: []const fx.workflow.ActivityState,
    actual: []const fx.workflow.ActivityState,
) !void {
    try std.testing.expectEqual(expected.len, actual.len);
    for (expected, actual) |expected_row, actual_row| {
        try std.testing.expectEqual(expected_row.id, actual_row.id);
        try std.testing.expectEqual(expected_row.status, actual_row.status);
        try std.testing.expectEqual(expected_row.last_sequence, actual_row.last_sequence);
        try std.testing.expectEqual(expected_row.attempt, actual_row.attempt);
        try std.testing.expectEqualStrings(expected_row.name, actual_row.name);
    }
}

fn expectTimersEqual(
    expected: []const fx.workflow.TimerState,
    actual: []const fx.workflow.TimerState,
) !void {
    try std.testing.expectEqual(expected.len, actual.len);
    for (expected, actual) |expected_row, actual_row| {
        try std.testing.expectEqual(expected_row.id, actual_row.id);
        try std.testing.expectEqual(expected_row.status, actual_row.status);
        try std.testing.expectEqual(expected_row.last_sequence, actual_row.last_sequence);
        try std.testing.expectEqualStrings(expected_row.name, actual_row.name);
    }
}

fn expectDeferredsEqual(
    expected: []const fx.workflow.DeferredState,
    actual: []const fx.workflow.DeferredState,
) !void {
    try std.testing.expectEqual(expected.len, actual.len);
    for (expected, actual) |expected_row, actual_row| {
        try std.testing.expectEqual(expected_row.id, actual_row.id);
        try std.testing.expectEqual(expected_row.status, actual_row.status);
        try std.testing.expectEqual(expected_row.last_sequence, actual_row.last_sequence);
        try std.testing.expectEqualStrings(expected_row.name, actual_row.name);
    }
}

fn expectQueuesEqual(
    expected: []const fx.workflow.QueueState,
    actual: []const fx.workflow.QueueState,
) !void {
    try std.testing.expectEqual(expected.len, actual.len);
    for (expected, actual) |expected_row, actual_row| {
        try std.testing.expectEqual(expected_row.id, actual_row.id);
        try std.testing.expectEqual(expected_row.status, actual_row.status);
        try std.testing.expectEqual(expected_row.last_sequence, actual_row.last_sequence);
        try std.testing.expectEqualStrings(expected_row.name, actual_row.name);
    }
}

fn expectCompensationsEqual(
    expected: []const fx.workflow.CompensationState,
    actual: []const fx.workflow.CompensationState,
) !void {
    try std.testing.expectEqual(expected.len, actual.len);
    for (expected, actual) |expected_row, actual_row| {
        try std.testing.expectEqual(expected_row.id, actual_row.id);
        try std.testing.expectEqual(expected_row.status, actual_row.status);
        try std.testing.expectEqual(expected_row.last_sequence, actual_row.last_sequence);
        try std.testing.expectEqualStrings(expected_row.name, actual_row.name);
    }
}
