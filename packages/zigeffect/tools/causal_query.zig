const std = @import("std");

pub const default_artifact_path = ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.json";

const Artifact = struct {
    events: []Event,
};

const Event = struct {
    id: u64,
    kind: []const u8,
    run_id: ?u64,
    parent_id: ?u64,
    fiber_id: ?u64,
    scope_id: ?u64,
    trace_id: ?u64,
    span_id: ?u64,
    label: []const u8,
    type_name: []const u8,
    status: []const u8,
    redacted_detail: []const u8,
};

const sample_json =
    \\{
    \\  "events": [
    \\    {
    \\      "id": 1,
    \\      "kind": "run_started",
    \\      "run_id": 1,
    \\      "parent_id": null,
    \\      "fiber_id": null,
    \\      "scope_id": null,
    \\      "trace_id": null,
    \\      "span_id": null,
    \\      "label": "zigeffect dogfood",
    \\      "type_name": "DogfoodHarness",
    \\      "status": "",
    \\      "redacted_detail": ""
    \\    },
    \\    {
    \\      "id": 2,
    \\      "kind": "scope_opened",
    \\      "run_id": 1,
    \\      "parent_id": 1,
    \\      "fiber_id": null,
    \\      "scope_id": 1,
    \\      "trace_id": null,
    \\      "span_id": null,
    \\      "label": "dogfood scope",
    \\      "type_name": "",
    \\      "status": "opened",
    \\      "redacted_detail": ""
    \\    },
    \\    {
    \\      "id": 3,
    \\      "kind": "service_required",
    \\      "run_id": 1,
    \\      "parent_id": 2,
    \\      "fiber_id": null,
    \\      "scope_id": null,
    \\      "trace_id": null,
    \\      "span_id": null,
    \\      "label": "Config",
    \\      "type_name": "services.config.Config",
    \\      "status": "missing",
    \\      "redacted_detail": "missing provider for config descriptor"
    \\    },
    \\    {
    \\      "id": 4,
    \\      "kind": "resource_acquired",
    \\      "run_id": 1,
    \\      "parent_id": 2,
    \\      "fiber_id": null,
    \\      "scope_id": 1,
    \\      "trace_id": null,
    \\      "span_id": null,
    \\      "label": "dogfood database",
    \\      "type_name": "DogfoodDatabaseConnection",
    \\      "status": "success",
    \\      "redacted_detail": "resource intentionally left open by fixture"
    \\    },
    \\    {
    \\      "id": 5,
    \\      "kind": "fiber_forked",
    \\      "run_id": 1,
    \\      "parent_id": 2,
    \\      "fiber_id": 42,
    \\      "scope_id": 1,
    \\      "trace_id": null,
    \\      "span_id": null,
    \\      "label": "dogfood child fiber",
    \\      "type_name": "",
    \\      "status": "pending",
    \\      "redacted_detail": ""
    \\    },
    \\    {
    \\      "id": 6,
    \\      "kind": "schedule_decision",
    \\      "run_id": 1,
    \\      "parent_id": 1,
    \\      "fiber_id": null,
    \\      "scope_id": null,
    \\      "trace_id": null,
    \\      "span_id": null,
    \\      "label": "dogfood retry policy",
    \\      "type_name": "Schedule.exponential",
    \\      "status": "exhausted",
    \\      "redacted_detail": "retry budget exhausted after deterministic fixture"
    \\    }
    \\  ]
    \\}
;

pub fn runQuery(allocator: std.mem.Allocator, json: []const u8, args: []const []const u8) ![]const u8 {
    if (args.len == 0) return error.MissingQueryName;

    var parsed = try std.json.parseFromSlice(Artifact, allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    var selected = std.ArrayList(Event).empty;
    defer selected.deinit(allocator);

    const query = args[0];
    if (std.mem.eql(u8, query, "snapshot")) {
        try appendAll(allocator, &selected, parsed.value.events);
    } else if (std.mem.eql(u8, query, "cause")) {
        const event_id = try requiredU64(args, 1);
        try appendCauseChain(allocator, &selected, parsed.value.events, event_id);
    } else if (std.mem.eql(u8, query, "lineage")) {
        const event_id = try requiredU64(args, 1);
        for (parsed.value.events) |event| {
            if (event.id == event_id or event.parent_id == event_id) {
                try selected.append(allocator, event);
            }
        }
    } else if (std.mem.eql(u8, query, "resources")) {
        const scope_id = try requiredU64(args, 1);
        for (parsed.value.events) |event| {
            if (event.scope_id == scope_id and (std.mem.eql(u8, event.kind, "resource_acquired") or std.mem.eql(u8, event.kind, "resource_finalized"))) {
                try selected.append(allocator, event);
            }
        }
    } else if (std.mem.eql(u8, query, "fibers")) {
        const status = if (args.len > 1) args[1] else null;
        for (parsed.value.events) |event| {
            if (!isFiberEvent(event.kind)) continue;
            if (status) |expected| {
                if (!std.mem.eql(u8, event.status, expected)) continue;
            }
            try selected.append(allocator, event);
        }
    } else if (std.mem.eql(u8, query, "requirements")) {
        const run_id = try requiredU64(args, 1);
        for (parsed.value.events) |event| {
            if (event.run_id == run_id and std.mem.eql(u8, event.kind, "service_required")) {
                try selected.append(allocator, event);
            }
        }
    } else if (std.mem.eql(u8, query, "retries")) {
        const run_id = try requiredU64(args, 1);
        for (parsed.value.events) |event| {
            if (event.run_id == run_id and std.mem.eql(u8, event.kind, "schedule_decision")) {
                try selected.append(allocator, event);
            }
        }
    } else {
        return error.UnknownQuery;
    }

    return formatQueryResult(allocator, args, selected.items);
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());

    var normalized_args = std.ArrayList([]const u8).empty;
    defer normalized_args.deinit(allocator);
    for (args[1..]) |arg| {
        try normalized_args.append(allocator, arg);
    }

    var file_path: []const u8 = default_artifact_path;
    var query_start: usize = 0;
    if (normalized_args.items.len >= 1 and std.mem.eql(u8, normalized_args.items[0], "--file")) {
        if (normalized_args.items.len < 3) failUsage(error.MissingFileArgument);
        file_path = normalized_args.items[1];
        query_start = 2;
    }

    const json = try std.Io.Dir.cwd().readFileAlloc(
        init.io,
        file_path,
        allocator,
        .limited(1024 * 1024),
    );
    defer allocator.free(json);

    const output = runQuery(allocator, json, normalized_args.items[query_start..]) catch |err| switch (err) {
        error.MissingQueryName,
        error.MissingQueryArgument,
        error.InvalidQueryNumber,
        error.UnknownQuery,
        => failUsage(err),
        else => return err,
    };
    defer allocator.free(output);

    std.debug.print("{s}", .{output});
}

fn printUsage(err: anyerror) void {
    std.debug.print(
        "causal-query error: {s}\nusage: zig build causal-query -- [--file <path>] <snapshot|cause|lineage|resources|fibers|requirements|retries> [argument]\n",
        .{@errorName(err)},
    );
}

fn failUsage(err: anyerror) noreturn {
    printUsage(err);
    std.process.exit(1);
}

fn appendAll(allocator: std.mem.Allocator, output: *std.ArrayList(Event), events: []const Event) std.mem.Allocator.Error!void {
    for (events) |event| {
        try output.append(allocator, event);
    }
}

fn appendCauseChain(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(Event),
    events: []const Event,
    event_id: u64,
) std.mem.Allocator.Error!void {
    const event = findEvent(events, event_id) orelse return;
    if (event.parent_id) |parent_id| {
        try appendCauseChain(allocator, output, events, parent_id);
    }
    try output.append(allocator, event);
}

fn findEvent(events: []const Event, event_id: u64) ?Event {
    for (events) |event| {
        if (event.id == event_id) return event;
    }
    return null;
}

fn requiredU64(args: []const []const u8, index: usize) !u64 {
    if (args.len <= index) return error.MissingQueryArgument;
    return std.fmt.parseInt(u64, args[index], 10) catch return error.InvalidQueryNumber;
}

fn isFiberEvent(kind: []const u8) bool {
    return std.mem.eql(u8, kind, "fiber_forked") or
        std.mem.eql(u8, kind, "fiber_started") or
        std.mem.eql(u8, kind, "fiber_joined") or
        std.mem.eql(u8, kind, "fiber_interrupted");
}

fn formatQueryResult(allocator: std.mem.Allocator, args: []const []const u8, events: []const Event) std.mem.Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "causal.query:");
    for (args) |arg| {
        try output.print(allocator, " {s}", .{arg});
    }
    try output.print(allocator, "\nevents: {d}\n", .{events.len});
    for (events) |event| {
        try appendEventLine(&output, allocator, event);
    }

    return output.toOwnedSlice(allocator);
}

fn appendEventLine(output: *std.ArrayList(u8), allocator: std.mem.Allocator, event: Event) std.mem.Allocator.Error!void {
    try output.print(allocator, "- event id={d} kind={s}", .{ event.id, event.kind });
    if (event.run_id) |run_id| try output.print(allocator, " run={d}", .{run_id});
    if (event.scope_id) |scope_id| try output.print(allocator, " scope={d}", .{scope_id});
    if (event.fiber_id) |fiber_id| try output.print(allocator, " fiber={d}", .{fiber_id});
    if (event.label.len > 0) try output.print(allocator, " label={s}", .{event.label});
    if (event.type_name.len > 0) try output.print(allocator, " type={s}", .{event.type_name});
    if (event.status.len > 0) try output.print(allocator, " status={s}", .{event.status});
    try output.append(allocator, '\n');
}

test "snapshot query prints all events" {
    const output = try runQuery(std.testing.allocator, sample_json, &.{"snapshot"});
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "causal.query: snapshot") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "events: 6") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "event id=1 kind=run_started") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "event id=6 kind=schedule_decision") != null);
}

test "cause query prints parent chain" {
    const output = try runQuery(std.testing.allocator, sample_json, &.{ "cause", "3" });
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "events: 3") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "event id=1 kind=run_started") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "event id=2 kind=scope_opened") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "event id=3 kind=service_required") != null);
}

test "lineage query prints event and direct children" {
    const output = try runQuery(std.testing.allocator, sample_json, &.{ "lineage", "2" });
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "events: 4") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "event id=2 kind=scope_opened") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "event id=3 kind=service_required") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "event id=4 kind=resource_acquired") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "event id=5 kind=fiber_forked") != null);
}

test "resource fiber requirement and retry queries filter events" {
    const resources = try runQuery(std.testing.allocator, sample_json, &.{ "resources", "1" });
    defer std.testing.allocator.free(resources);
    try std.testing.expect(std.mem.indexOf(u8, resources, "event id=4 kind=resource_acquired") != null);

    const fibers = try runQuery(std.testing.allocator, sample_json, &.{ "fibers", "pending" });
    defer std.testing.allocator.free(fibers);
    try std.testing.expect(std.mem.indexOf(u8, fibers, "event id=5 kind=fiber_forked") != null);

    const requirements = try runQuery(std.testing.allocator, sample_json, &.{ "requirements", "1" });
    defer std.testing.allocator.free(requirements);
    try std.testing.expect(std.mem.indexOf(u8, requirements, "event id=3 kind=service_required") != null);

    const retries = try runQuery(std.testing.allocator, sample_json, &.{ "retries", "1" });
    defer std.testing.allocator.free(retries);
    try std.testing.expect(std.mem.indexOf(u8, retries, "event id=6 kind=schedule_decision") != null);
}

test "invalid query arguments return typed errors" {
    try std.testing.expectError(error.MissingQueryName, runQuery(std.testing.allocator, sample_json, &.{}));
    try std.testing.expectError(error.MissingQueryArgument, runQuery(std.testing.allocator, sample_json, &.{"cause"}));
    try std.testing.expectError(error.InvalidQueryNumber, runQuery(std.testing.allocator, sample_json, &.{ "cause", "not-a-number" }));
    try std.testing.expectError(error.UnknownQuery, runQuery(std.testing.allocator, sample_json, &.{"unknown"}));
}
