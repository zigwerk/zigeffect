const std = @import("std");
const fx = @import("zigeffect");
const Secrets = @import("../secrets/root.zig");
const Contract = @import("contract.zig");
const Context = @import("context.zig");

pub const AssertionError = error{AssertionFailed};

pub const EventPattern = struct {
    kind: fx.CausalEventKind,
    label: ?[]const u8 = null,
    type_name: ?[]const u8 = null,
    status: ?[]const u8 = null,
    detail_contains: ?[]const u8 = null,
};

pub const Metadata = struct {
    id: []const u8,
    label: []const u8,
    source: Contract.SourceReference = .{},
    repair_hint: []const u8 = "",
};

pub const Recorder = struct {
    context: *Context.TestContext,

    pub fn init(context: *Context.TestContext) Recorder {
        return .{ .context = context };
    }

    pub fn boolean(self: Recorder, metadata: Metadata, actual: bool) !void {
        try self.record(metadata, actual, "true", if (actual) "true" else "false", "", &.{});
    }

    pub fn equal(self: Recorder, metadata: Metadata, expected: anytype, actual: @TypeOf(expected)) !void {
        const passed = std.meta.eql(expected, actual);
        const expected_text = try std.fmt.allocPrint(self.context.allocator, "{any}", .{expected});
        defer self.context.allocator.free(expected_text);
        const actual_text = try std.fmt.allocPrint(self.context.allocator, "{any}", .{actual});
        defer self.context.allocator.free(actual_text);
        try self.record(metadata, passed, expected_text, actual_text, "value equality", &.{});
    }

    pub fn stringEqual(self: Recorder, metadata: Metadata, expected: []const u8, actual: []const u8) !void {
        try self.record(metadata, std.mem.eql(u8, expected, actual), expected, actual, "string equality", &.{});
    }

    pub fn contains(self: Recorder, metadata: Metadata, haystack: []const u8, needle: []const u8) !void {
        try self.record(metadata, std.mem.indexOf(u8, haystack, needle) != null, needle, haystack, "substring containment", &.{});
    }

    pub fn noSecrets(self: Recorder, metadata: Metadata, actual: []const u8) !void {
        try self.record(metadata, !Secrets.containsSecret(actual), "no sentinel secret", actual, "secret scan", &.{});
    }

    pub fn semanticJson(self: Recorder, metadata: Metadata, expected: []const u8, actual: []const u8) !void {
        var expected_parsed = std.json.parseFromSlice(std.json.Value, self.context.allocator, expected, .{}) catch {
            try self.record(metadata, false, "valid semantic JSON", "invalid expected JSON", "expected fixture is malformed", &.{});
            return;
        };
        defer expected_parsed.deinit();
        var actual_parsed = std.json.parseFromSlice(std.json.Value, self.context.allocator, actual, .{}) catch {
            try self.record(metadata, false, expected, "invalid actual JSON", "program output is malformed", &.{});
            return;
        };
        defer actual_parsed.deinit();
        try self.record(metadata, jsonEqual(expected_parsed.value, actual_parsed.value), expected, actual, "semantic JSON equality; object key order ignored", &.{});
    }

    pub fn exitTag(self: Recorder, metadata: Metadata, exit: anytype, expected_tag: []const u8) !void {
        const actual_tag = @tagName(std.meta.activeTag(exit));
        try self.record(metadata, std.mem.eql(u8, expected_tag, actual_tag), expected_tag, actual_tag, "Exit variant", &.{});
    }

    pub fn causeDefect(self: Recorder, metadata: Metadata, cause: anytype, expected: []const u8) !void {
        try self.record(metadata, fx.causeHasDefect(cause, expected), expected, @tagName(std.meta.activeTag(cause)), "Cause contains defect", &.{});
    }

    pub fn causeFinalizerFailure(self: Recorder, metadata: Metadata, cause: anytype, expected: []const u8) !void {
        try self.record(metadata, fx.causeHasFinalizerFailure(cause, expected), expected, @tagName(std.meta.activeTag(cause)), "Cause contains finalizer failure", &.{});
    }

    pub fn causeInterruption(self: Recorder, metadata: Metadata, cause: anytype, fiber_id: u64) !void {
        const expected = try std.fmt.allocPrint(self.context.allocator, "fiber {d}", .{fiber_id});
        defer self.context.allocator.free(expected);
        try self.record(metadata, fx.causeHasInterruption(cause, fiber_id), expected, @tagName(std.meta.activeTag(cause)), "Cause contains interruption", &.{});
    }

    pub fn event(self: Recorder, metadata: Metadata, pattern: EventPattern) !fx.CausalEvent {
        var snapshot = try self.context.causal_store.snapshot(self.context.allocator);
        defer snapshot.deinit();
        for (snapshot.events) |item| {
            if (!eventMatches(item, pattern)) continue;
            const ids = [_]u64{item.id};
            try self.record(metadata, true, @tagName(pattern.kind), @tagName(item.kind), "causal event matched", &ids);
            return itemWithoutOwnedStrings(item);
        }
        try self.record(metadata, false, @tagName(pattern.kind), "missing", "causal event not found", &.{});
        unreachable;
    }

    pub fn eventSequence(self: Recorder, metadata: Metadata, expected: []const fx.CausalEventKind) !void {
        var snapshot = try self.context.causal_store.snapshot(self.context.allocator);
        defer snapshot.deinit();
        var matched: usize = 0;
        var ids = std.ArrayList(u64).empty;
        defer ids.deinit(self.context.allocator);
        for (snapshot.events) |item| {
            if (matched >= expected.len) break;
            if (item.kind != expected[matched]) continue;
            try ids.append(self.context.allocator, item.id);
            matched += 1;
        }
        const expected_text = try eventKindsAlloc(self.context.allocator, expected);
        defer self.context.allocator.free(expected_text);
        const actual_text = try eventKindsFromEventsAlloc(self.context.allocator, snapshot.events);
        defer self.context.allocator.free(actual_text);
        try self.record(metadata, matched == expected.len, expected_text, actual_text, "ordered causal subsequence", ids.items);
    }

    pub fn finding(self: Recorder, metadata: Metadata, expected: fx.CausalFindingKind) !void {
        var findings = try self.context.causal_store.findings(self.context.allocator);
        defer findings.deinit();
        for (findings.items) |item| {
            if (item.kind != expected) continue;
            const ids = [_]u64{item.event_id};
            try self.record(metadata, true, @tagName(expected), @tagName(item.kind), "causal finding matched", &ids);
            return;
        }
        try self.record(metadata, false, @tagName(expected), "missing", "causal finding not found", &.{});
    }

    pub fn noFindings(self: Recorder, metadata: Metadata) !void {
        var findings = try self.context.causal_store.findings(self.context.allocator);
        defer findings.deinit();
        const actual = try std.fmt.allocPrint(self.context.allocator, "{d} findings", .{findings.items.len});
        defer self.context.allocator.free(actual);
        try self.record(metadata, findings.items.len == 0, "0 findings", actual, "runtime causal safety findings", &.{});
    }

    pub fn noPendingFibers(self: Recorder, metadata: Metadata) !void {
        var states = try self.context.causal_store.fiberStates(self.context.allocator);
        defer states.deinit();
        const pending = states.unresolvedCount();
        const actual = try std.fmt.allocPrint(self.context.allocator, "{d} pending fibers", .{pending});
        defer self.context.allocator.free(actual);
        try self.record(metadata, pending == 0, "0 pending fibers", actual, "collapsed causal fiber lifecycle", &.{});
    }

    fn record(
        self: Recorder,
        metadata: Metadata,
        passed: bool,
        expected: []const u8,
        actual: []const u8,
        detail: []const u8,
        causal_ids: []const u64,
    ) !void {
        try self.context.addAssertion(.{
            .id = metadata.id,
            .label = metadata.label,
            .status = if (passed) .passed else .failed,
            .source = metadata.source,
            .causal_event_ids = causal_ids,
            .expected = expected,
            .actual = actual,
            .detail = detail,
            .repair_hint = metadata.repair_hint,
        });
        if (!passed) return error.AssertionFailed;
    }
};

pub fn renderHumanAlloc(allocator: std.mem.Allocator, assertions: []const Contract.AssertionResult) ![]u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    for (assertions) |assertion| {
        try output.print(allocator, "[{s}] {s} ({s})\n", .{ @tagName(assertion.status), assertion.label, assertion.id });
        if (assertion.status == .failed) {
            try output.print(allocator, "  expected: {s}\n  actual: {s}\n  repair: {s}\n", .{ assertion.expected, assertion.actual, assertion.repair_hint });
        }
    }
    return output.toOwnedSlice(allocator);
}

fn eventMatches(event: fx.CausalEvent, pattern: EventPattern) bool {
    if (event.kind != pattern.kind) return false;
    if (pattern.label) |value| if (!std.mem.eql(u8, event.label, value)) return false;
    if (pattern.type_name) |value| if (!std.mem.eql(u8, event.type_name, value)) return false;
    if (pattern.status) |value| if (!std.mem.eql(u8, event.status, value)) return false;
    if (pattern.detail_contains) |value| if (std.mem.indexOf(u8, event.redacted_detail, value) == null) return false;
    return true;
}

fn itemWithoutOwnedStrings(event: fx.CausalEvent) fx.CausalEvent {
    var value = event;
    value.label = "";
    value.type_name = "";
    value.status = "";
    value.redacted_detail = "";
    value.layer_name = "";
    value.service_key = "";
    value.artifact_id = "";
    value.domain_entity_ref = "";
    value.data_subject_ref = "";
    value.schema_ref = "";
    return value;
}

fn jsonEqual(expected: std.json.Value, actual: std.json.Value) bool {
    if (std.meta.activeTag(expected) != std.meta.activeTag(actual)) return false;
    return switch (expected) {
        .null => true,
        .bool => |value| value == actual.bool,
        .integer => |value| value == actual.integer,
        .float => |value| value == actual.float,
        .number_string => |value| std.mem.eql(u8, value, actual.number_string),
        .string => |value| std.mem.eql(u8, value, actual.string),
        .array => |value| blk: {
            if (value.items.len != actual.array.items.len) break :blk false;
            for (value.items, actual.array.items) |left, right| if (!jsonEqual(left, right)) break :blk false;
            break :blk true;
        },
        .object => |value| blk: {
            if (value.count() != actual.object.count()) break :blk false;
            var iterator = value.iterator();
            while (iterator.next()) |entry| {
                const right = actual.object.get(entry.key_ptr.*) orelse break :blk false;
                if (!jsonEqual(entry.value_ptr.*, right)) break :blk false;
            }
            break :blk true;
        },
    };
}

fn eventKindsAlloc(allocator: std.mem.Allocator, kinds: []const fx.CausalEventKind) ![]u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    for (kinds, 0..) |kind, index| {
        if (index != 0) try output.appendSlice(allocator, " -> ");
        try output.appendSlice(allocator, @tagName(kind));
    }
    return output.toOwnedSlice(allocator);
}

fn eventKindsFromEventsAlloc(allocator: std.mem.Allocator, events: []const fx.CausalEvent) ![]u8 {
    var kinds = try allocator.alloc(fx.CausalEventKind, events.len);
    defer allocator.free(kinds);
    for (events, 0..) |event, index| kinds[index] = event.kind;
    return eventKindsAlloc(allocator, kinds);
}

fn scenario() Contract.Scenario {
    return .{ .id = "assertions", .label = "assertions record evidence", .requirement = "req-testing", .acceptance_check = "check-assertions", .component = "std-testing", .command = "test" };
}

test "assertions record pass and failure before returning" {
    var ctx = try Context.TestContext.init(std.testing.allocator, .{ .project = "demo", .suite = "unit", .scenario = scenario() });
    defer ctx.deinit();
    const assertions = Recorder.init(&ctx);
    try assertions.stringEqual(.{ .id = "equal", .label = "strings equal" }, "value", "value");
    try std.testing.expectError(error.AssertionFailed, assertions.contains(.{ .id = "contains", .label = "contains value", .repair_hint = "emit the missing field" }, "abc", "xyz"));
    try std.testing.expectEqual(@as(usize, 2), ctx.assertions.items.len);
    try std.testing.expectEqual(Contract.AssertionStatus.failed, ctx.assertions.items[1].status);
    const receipt = try ctx.finish(1);
    try std.testing.expectEqual(Contract.TestStatus.failed, receipt.status);
}

test "semantic JSON ignores object key order and secret assertion redacts receipts" {
    var ctx = try Context.TestContext.init(std.testing.allocator, .{ .project = "demo", .suite = "unit", .scenario = scenario() });
    defer ctx.deinit();
    const assertions = Recorder.init(&ctx);
    try assertions.semanticJson(.{ .id = "json", .label = "semantic JSON" }, "{\"a\":1,\"b\":[true]}", "{\"b\":[true],\"a\":1}");
    try std.testing.expectError(error.AssertionFailed, assertions.noSecrets(.{ .id = "secrets", .label = "no secrets" }, "sentinel-secret-for-tests"));
    const json = try ctx.finishAlloc(1);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "sentinel-secret") == null);
}

test "causal matchers cite event ids and ordered subsequences" {
    var ctx = try Context.TestContext.init(std.testing.allocator, .{ .project = "demo", .suite = "unit", .scenario = scenario() });
    defer ctx.deinit();
    _ = try ctx.causal_store.record(.{ .kind = .run_started, .label = "test" });
    _ = try ctx.causal_store.record(.{ .kind = .run_completed, .label = "test", .status = "success" });
    const assertions = Recorder.init(&ctx);
    _ = try assertions.event(.{ .id = "event", .label = "run starts" }, .{ .kind = .run_started, .label = "test" });
    try assertions.eventSequence(.{ .id = "sequence", .label = "run lifecycle" }, &.{ .run_started, .run_completed });
    try assertions.noFindings(.{ .id = "findings", .label = "no findings" });
    try std.testing.expectEqual(@as(usize, 1), ctx.assertions.items[0].causal_event_ids.len);
}
