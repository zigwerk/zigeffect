const std = @import("std");
const causal_artifact = @import("causal_artifact");

pub const default_artifact_path = ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.json";
pub const agent_query_schema = "zigeffect.causal.agent-query.v1";
pub const agent_query_schema_version: u32 = 1;
pub const default_agent_query_limit: usize = 32;
pub const max_agent_query_limit: usize = 256;

const OutputMode = enum {
    text,
    agent_json,
};

const ParsedQueryArgs = struct {
    mode: OutputMode = .text,
    limit: usize = default_agent_query_limit,
    query_args: []const []const u8,
};

const Retention = struct {
    max_events: ?usize = null,
    dropped_events: u64 = 0,
    oldest_retained_event_id: ?u64 = null,
};

const Sampling = struct {
    log_every_n: ?usize = null,
    metric_every_n: ?usize = null,
    span_every_n: ?usize = null,
    sampled_events: u64 = 0,
};

const Truncation = struct {
    max_event_string_bytes: ?usize = null,
    truncated_fields: u64 = 0,
};

const Artifact = struct {
    schema: ?[]const u8 = null,
    schema_version: ?u32 = null,
    event_taxonomy_version: ?u32 = null,
    retention: ?Retention = null,
    sampling: ?Sampling = null,
    truncation: ?Truncation = null,
    events: []Event,
};

const Event = struct {
    id: u64,
    kind: []const u8,
    run_id: ?u64,
    parent_id: ?u64,
    fiber_id: ?u64,
    scope_id: ?u64,
    layer_id: ?u64 = null,
    service_key: []const u8 = "",
    resource_id: ?u64 = null,
    cause_event_id: ?u64 = null,
    schedule_id: ?u64 = null,
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

const versioned_sample_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 1,
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"versioned artifact","type_name":"Fixture","status":"started","redacted_detail":""}
    \\  ]
    \\}
;

const future_taxonomy_sample_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 1,
    \\  "event_taxonomy_version": 2,
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"future taxonomy","type_name":"Fixture","status":"started","redacted_detail":""}
    \\  ]
    \\}
;

const future_schema_unknown_kind_sample_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 2,
    \\  "event_taxonomy_version": 1,
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"future schema","type_name":"Fixture","status":"started","redacted_detail":""},
    \\    {"id":2,"kind":"effect_suspended","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"future event","type_name":"Fixture","status":"pending","redacted_detail":""},
    \\    {"id":3,"kind":"effect_suspended","run_id":1,"parent_id":2,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"future duplicate","type_name":"Fixture","status":"pending","redacted_detail":""}
    \\  ]
    \\}
;

const unsupported_schema_sample_json =
    \\{
    \\  "schema": "zigeffect.causal.v2",
    \\  "schema_version": 1,
    \\  "event_taxonomy_version": 1,
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"unsupported schema","type_name":"Fixture","status":"started","redacted_detail":""}
    \\  ]
    \\}
;

const deep_runtime_sample_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 1,
    \\  "event_taxonomy_version": 1,
    \\  "retention": {
    \\    "max_events": 64,
    \\    "dropped_events": 2,
    \\    "oldest_retained_event_id": 1
    \\  },
    \\  "sampling": {
    \\    "log_every_n": null,
    \\    "metric_every_n": null,
    \\    "span_every_n": null,
    \\    "sampled_events": 3
    \\  },
    \\  "truncation": {
    \\    "max_event_string_bytes": 128,
    \\    "truncated_fields": 1
    \\  },
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"layer_id":null,"service_key":"","resource_id":null,"cause_event_id":null,"schedule_id":null,"trace_id":null,"span_id":null,"label":"deep runtime","type_name":"Fixture","status":"started","redacted_detail":""},
    \\    {"id":2,"kind":"layer_started","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":1,"layer_id":7,"service_key":"","resource_id":null,"cause_event_id":null,"schedule_id":null,"trace_id":null,"span_id":null,"label":"ConfigLayer","type_name":"","status":"starting","redacted_detail":""},
    \\    {"id":3,"kind":"service_required","run_id":1,"parent_id":2,"fiber_id":null,"scope_id":1,"layer_id":7,"service_key":"services.config.Config","resource_id":null,"cause_event_id":2,"schedule_id":null,"trace_id":null,"span_id":null,"label":"ConfigLayer","type_name":"services.config.Config","status":"missing","redacted_detail":"missing provider"},
    \\    {"id":4,"kind":"resource_acquired","run_id":1,"parent_id":2,"fiber_id":null,"scope_id":1,"layer_id":7,"service_key":"","resource_id":44,"cause_event_id":null,"schedule_id":null,"trace_id":null,"span_id":null,"label":"connection","type_name":"DbConnection","status":"success","redacted_detail":""},
    \\    {"id":5,"kind":"resource_finalized","run_id":1,"parent_id":4,"fiber_id":null,"scope_id":1,"layer_id":7,"service_key":"","resource_id":44,"cause_event_id":4,"schedule_id":null,"trace_id":null,"span_id":null,"label":"connection","type_name":"DbConnection","status":"failure","redacted_detail":"CloseFailed"},
    \\    {"id":6,"kind":"schedule_decision","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"layer_id":null,"service_key":"","resource_id":null,"cause_event_id":3,"schedule_id":99,"trace_id":null,"span_id":null,"label":"retry-config","type_name":"","status":"exhausted","redacted_detail":"attempt=2 delay_ms=null decision=exhausted"},
    \\    {"id":7,"kind":"fiber_interrupted","run_id":1,"parent_id":1,"fiber_id":12,"scope_id":1,"layer_id":null,"service_key":"","resource_id":null,"cause_event_id":1,"schedule_id":null,"trace_id":null,"span_id":null,"label":"worker","type_name":"","status":"interrupted","redacted_detail":""}
    \\  ]
    \\}
;

const cyclic_cause_sample_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 1,
    \\  "event_taxonomy_version": 1,
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"cause_event_id":3,"trace_id":null,"span_id":null,"label":"cycle root","type_name":"","status":"started","redacted_detail":""},
    \\    {"id":2,"kind":"service_required","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"cause_event_id":1,"trace_id":null,"span_id":null,"label":"Config","type_name":"services.config.Config","status":"missing","redacted_detail":""},
    \\    {"id":3,"kind":"exit_recorded","run_id":1,"parent_id":2,"fiber_id":null,"scope_id":null,"cause_event_id":2,"trace_id":null,"span_id":null,"label":"exit","type_name":"","status":"failure","redacted_detail":""}
    \\  ]
    \\}
;

pub const QueryOptions = struct {
    include_artifact_warnings: bool = true,
    artifact_label: []const u8 = "artifact",
};

pub fn runQuery(allocator: std.mem.Allocator, json: []const u8, args: []const []const u8) ![]const u8 {
    return runQueryWithOptions(allocator, json, args, .{});
}

pub fn runQueryWithOptions(
    allocator: std.mem.Allocator,
    json: []const u8,
    args: []const []const u8,
    options: QueryOptions,
) ![]const u8 {
    const parsed_args = try parseQueryArgs(args);

    var parsed = try std.json.parseFromSlice(Artifact, allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    var matched = std.ArrayList(Event).empty;
    defer matched.deinit(allocator);

    const query_args = parsed_args.query_args;
    const query = query_args[0];
    if (std.mem.eql(u8, query, "snapshot")) {
        try appendAll(allocator, &matched, parsed.value.events);
    } else if (std.mem.eql(u8, query, "cause")) {
        const event_id = try requiredU64(query_args, 1);
        try appendCauseChain(allocator, &matched, parsed.value.events, event_id);
    } else if (std.mem.eql(u8, query, "trace_cause")) {
        const event_id = try requiredU64(query_args, 1);
        try appendCauseChain(allocator, &matched, parsed.value.events, event_id);
    } else if (std.mem.eql(u8, query, "lineage")) {
        const event_id = try requiredU64(query_args, 1);
        for (parsed.value.events) |event| {
            if (event.id == event_id or event.parent_id == event_id or event.cause_event_id == event_id) {
                try matched.append(allocator, event);
            }
        }
    } else if (std.mem.eql(u8, query, "resources")) {
        const scope_id = try requiredU64(query_args, 1);
        for (parsed.value.events) |event| {
            if (event.scope_id == scope_id and (std.mem.eql(u8, event.kind, "resource_acquired") or std.mem.eql(u8, event.kind, "resource_finalized"))) {
                try matched.append(allocator, event);
            }
        }
    } else if (std.mem.eql(u8, query, "fibers")) {
        const status = if (query_args.len > 1) query_args[1] else null;
        for (parsed.value.events) |event| {
            if (!isFiberEvent(event.kind)) continue;
            if (status) |expected| {
                if (!std.mem.eql(u8, event.status, expected)) continue;
            }
            try matched.append(allocator, event);
        }
    } else if (std.mem.eql(u8, query, "requirements")) {
        const run_id = try requiredU64(query_args, 1);
        for (parsed.value.events) |event| {
            if (event.run_id == run_id and std.mem.eql(u8, event.kind, "service_required")) {
                try matched.append(allocator, event);
            }
        }
    } else if (std.mem.eql(u8, query, "retries")) {
        const run_id = try requiredU64(query_args, 1);
        for (parsed.value.events) |event| {
            if (event.run_id == run_id and std.mem.eql(u8, event.kind, "schedule_decision")) {
                try matched.append(allocator, event);
            }
        }
    } else if (std.mem.eql(u8, query, "summarize_run")) {
        const run_id = try requiredU64(query_args, 1);
        for (parsed.value.events) |event| {
            if (event.run_id == run_id) try matched.append(allocator, event);
        }
    } else if (std.mem.eql(u8, query, "find_failures") or std.mem.eql(u8, query, "list_findings")) {
        const run_id = try requiredU64(query_args, 1);
        for (parsed.value.events) |event| {
            if (event.run_id == run_id and isFailureEvidence(event)) {
                try matched.append(allocator, event);
            }
        }
    } else if (std.mem.eql(u8, query, "explain_event")) {
        const event_id = try requiredU64(query_args, 1);
        try appendCauseChain(allocator, &matched, parsed.value.events, event_id);
        for (parsed.value.events) |event| {
            if (event.parent_id == event_id or event.cause_event_id == event_id) {
                try appendUniqueEvent(allocator, &matched, event);
            }
        }
    } else if (std.mem.eql(u8, query, "next_queries")) {
        const event_id = try requiredU64(query_args, 1);
        if (findEvent(parsed.value.events, event_id)) |event| {
            try matched.append(allocator, event);
        }
    } else {
        return error.UnknownQuery;
    }

    if (parsed_args.mode == .agent_json) {
        const returned_len = @min(matched.items.len, parsed_args.limit);
        return formatAgentQueryResult(
            allocator,
            query_args,
            matched.items[0..returned_len],
            matched.items.len,
            parsed.value.events,
            parsed.value,
            parsed_args,
            options,
        );
    }

    return formatQueryResult(
        allocator,
        query_args,
        matched.items,
        parsed.value.events,
        .{
            .schema = parsed.value.schema,
            .schema_version = parsed.value.schema_version,
            .event_taxonomy_version = parsed.value.event_taxonomy_version,
        },
        options,
    );
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());

    var file_path: []const u8 = default_artifact_path;
    var query_args = std.ArrayList([]const u8).empty;
    defer query_args.deinit(allocator);

    var index: usize = 1;
    while (index < args.len) : (index += 1) {
        const arg = args[index];
        if (std.mem.eql(u8, arg, "--file")) {
            if (index + 1 >= args.len) failUsage(error.MissingFileArgument);
            index += 1;
            file_path = args[index];
            continue;
        }
        try query_args.append(allocator, arg);
    }

    const json = try std.Io.Dir.cwd().readFileAlloc(
        init.io,
        file_path,
        allocator,
        .limited(1024 * 1024),
    );
    defer allocator.free(json);

    const output = runQuery(allocator, json, query_args.items) catch |err| switch (err) {
        error.MissingQueryName,
        error.MissingQueryArgument,
        error.InvalidQueryNumber,
        error.InvalidQueryLimit,
        error.UnknownQuery,
        => failUsage(err),
        else => return err,
    };
    defer allocator.free(output);

    std.debug.print("{s}", .{output});
}

fn printUsage(err: anyerror) void {
    std.debug.print(
        "causal-query error: {s}\nusage: zig build causal-query -- [--agent] [--limit <n>] [--file <path>] <snapshot|cause|lineage|resources|fibers|requirements|retries|summarize_run|find_failures|explain_event|trace_cause|list_findings|next_queries> [argument]\n",
        .{@errorName(err)},
    );
}

fn failUsage(err: anyerror) noreturn {
    printUsage(err);
    std.process.exit(1);
}

fn parseQueryArgs(args: []const []const u8) !ParsedQueryArgs {
    var mode: OutputMode = .text;
    var limit: usize = default_agent_query_limit;
    var index: usize = 0;

    while (index < args.len) : (index += 1) {
        const arg = args[index];
        if (!std.mem.startsWith(u8, arg, "--")) break;
        if (std.mem.eql(u8, arg, "--agent")) {
            mode = .agent_json;
        } else if (std.mem.eql(u8, arg, "--limit")) {
            if (index + 1 >= args.len) return error.MissingQueryArgument;
            index += 1;
            limit = std.fmt.parseInt(usize, args[index], 10) catch return error.InvalidQueryNumber;
            if (limit == 0 or limit > max_agent_query_limit) return error.InvalidQueryLimit;
        } else {
            return error.UnknownQuery;
        }
    }

    if (index >= args.len) return error.MissingQueryName;
    return .{
        .mode = mode,
        .limit = limit,
        .query_args = args[index..],
    };
}

fn appendAll(allocator: std.mem.Allocator, output: *std.ArrayList(Event), events: []const Event) std.mem.Allocator.Error!void {
    for (events) |event| {
        try output.append(allocator, event);
    }
}

fn appendUniqueEvent(allocator: std.mem.Allocator, output: *std.ArrayList(Event), event: Event) std.mem.Allocator.Error!void {
    for (output.items) |existing| {
        if (existing.id == event.id) return;
    }
    try output.append(allocator, event);
}

fn appendCauseChain(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(Event),
    events: []const Event,
    event_id: u64,
) std.mem.Allocator.Error!void {
    var visiting = std.ArrayList(u64).empty;
    defer visiting.deinit(allocator);
    try appendCauseChainBounded(allocator, output, events, event_id, &visiting);
}

fn appendCauseChainBounded(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(Event),
    events: []const Event,
    event_id: u64,
    visiting: *std.ArrayList(u64),
) std.mem.Allocator.Error!void {
    for (visiting.items) |seen_id| {
        if (seen_id == event_id) return;
    }

    const event = findEvent(events, event_id) orelse return;
    try visiting.append(allocator, event_id);
    defer _ = visiting.pop();

    if (event.cause_event_id orelse event.parent_id) |cause_id| {
        try appendCauseChainBounded(allocator, output, events, cause_id, visiting);
    }
    try appendUniqueEvent(allocator, output, event);
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

fn isFailureEvidence(event: Event) bool {
    if (std.mem.eql(u8, event.status, "failure")) return true;
    if (std.mem.eql(u8, event.status, "missing")) return true;
    if (std.mem.eql(u8, event.status, "exhausted")) return true;
    if (std.mem.eql(u8, event.status, "defect")) return true;
    if (std.mem.eql(u8, event.status, "interrupted")) return true;
    if (std.mem.eql(u8, event.kind, "fiber_interrupted")) return true;
    return false;
}

fn appendJsonString(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: []const u8) std.mem.Allocator.Error!void {
    try output.append(allocator, '"');
    for (value) |byte| {
        switch (byte) {
            '"' => try output.appendSlice(allocator, "\\\""),
            '\\' => try output.appendSlice(allocator, "\\\\"),
            '\n' => try output.appendSlice(allocator, "\\n"),
            '\r' => try output.appendSlice(allocator, "\\r"),
            '\t' => try output.appendSlice(allocator, "\\t"),
            else => try output.append(allocator, byte),
        }
    }
    try output.append(allocator, '"');
}

fn appendOptionalJsonU64(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: ?u64) std.mem.Allocator.Error!void {
    if (value) |number| {
        try output.print(allocator, "{d}", .{number});
    } else {
        try output.appendSlice(allocator, "null");
    }
}

fn appendOptionalJsonUsize(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: ?usize) std.mem.Allocator.Error!void {
    if (value) |number| {
        try output.print(allocator, "{d}", .{number});
    } else {
        try output.appendSlice(allocator, "null");
    }
}

fn appendAgentWarning(output: *std.ArrayList(u8), allocator: std.mem.Allocator, wrote: *bool, warning: []const u8) std.mem.Allocator.Error!void {
    if (wrote.*) try output.append(allocator, ',');
    try appendJsonString(output, allocator, warning);
    wrote.* = true;
}

fn appendAgentWarnings(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    artifact: Artifact,
    options: QueryOptions,
) std.mem.Allocator.Error!void {
    try output.appendSlice(allocator, "\"warnings\":[");
    var wrote = false;

    if (artifact.schema) |schema| {
        if (!std.mem.eql(u8, schema, causal_artifact.supported_causal_schema)) {
            const warning = try std.fmt.allocPrint(
                allocator,
                "{s} schema={s} unsupported; expected {s}",
                .{ options.artifact_label, schema, causal_artifact.supported_causal_schema },
            );
            defer allocator.free(warning);
            try appendAgentWarning(output, allocator, &wrote, warning);
        }
    }
    if (artifact.schema_version) |version| {
        if (version > causal_artifact.supported_causal_schema_version) {
            const warning = try std.fmt.allocPrint(
                allocator,
                "{s} schema_version={d} newer than supported={d}; artifact shape may be incomplete",
                .{ options.artifact_label, version, causal_artifact.supported_causal_schema_version },
            );
            defer allocator.free(warning);
            try appendAgentWarning(output, allocator, &wrote, warning);
        }
    }
    if (artifact.event_taxonomy_version) |version| {
        if (version > causal_artifact.supported_event_taxonomy_version) {
            const warning = try std.fmt.allocPrint(
                allocator,
                "{s} event_taxonomy_version={d} newer than supported={d}; event-kind role semantics may be incomplete",
                .{ options.artifact_label, version, causal_artifact.supported_event_taxonomy_version },
            );
            defer allocator.free(warning);
            try appendAgentWarning(output, allocator, &wrote, warning);
        }
    }

    var seen = std.ArrayList([]const u8).empty;
    defer seen.deinit(allocator);
    for (artifact.events) |event| {
        if (causal_artifact.isKnownCausalEventKind(event.kind)) continue;
        var already_seen = false;
        for (seen.items) |kind| {
            if (std.mem.eql(u8, kind, event.kind)) {
                already_seen = true;
                break;
            }
        }
        if (already_seen) continue;
        try seen.append(allocator, event.kind);
        const warning = try std.fmt.allocPrint(
            allocator,
            "{s} event kind {s} unknown to supported taxonomy={d}; query role semantics may be incomplete",
            .{ options.artifact_label, event.kind, causal_artifact.supported_event_taxonomy_version },
        );
        defer allocator.free(warning);
        try appendAgentWarning(output, allocator, &wrote, warning);
    }
    try output.append(allocator, ']');
}

fn appendAgentPolicy(output: *std.ArrayList(u8), allocator: std.mem.Allocator, artifact: Artifact) std.mem.Allocator.Error!void {
    try output.appendSlice(allocator, "\"policy\":{");
    try output.appendSlice(allocator, "\"retention\":{");
    if (artifact.retention) |retention| {
        try output.appendSlice(allocator, "\"metadata_available\":true,\"max_events\":");
        try appendOptionalJsonUsize(output, allocator, retention.max_events);
        try output.print(
            allocator,
            ",\"dropped_events\":{d},\"oldest_retained_event_id\":",
            .{retention.dropped_events},
        );
        try appendOptionalJsonU64(output, allocator, retention.oldest_retained_event_id);
    } else {
        try output.appendSlice(allocator, "\"metadata_available\":false,\"max_events\":null,\"dropped_events\":0,\"oldest_retained_event_id\":null");
    }
    try output.appendSlice(allocator, "},\"sampling\":{");
    if (artifact.sampling) |sampling| {
        try output.appendSlice(allocator, "\"metadata_available\":true,\"log_every_n\":");
        try appendOptionalJsonUsize(output, allocator, sampling.log_every_n);
        try output.appendSlice(allocator, ",\"metric_every_n\":");
        try appendOptionalJsonUsize(output, allocator, sampling.metric_every_n);
        try output.appendSlice(allocator, ",\"span_every_n\":");
        try appendOptionalJsonUsize(output, allocator, sampling.span_every_n);
        try output.print(allocator, ",\"sampled_events\":{d}", .{sampling.sampled_events});
    } else {
        try output.appendSlice(allocator, "\"metadata_available\":false,\"log_every_n\":null,\"metric_every_n\":null,\"span_every_n\":null,\"sampled_events\":0");
    }
    try output.appendSlice(allocator, "},\"truncation\":{");
    if (artifact.truncation) |truncation| {
        try output.appendSlice(allocator, "\"metadata_available\":true,\"max_event_string_bytes\":");
        try appendOptionalJsonUsize(output, allocator, truncation.max_event_string_bytes);
        try output.print(allocator, ",\"truncated_fields\":{d}", .{truncation.truncated_fields});
    } else {
        try output.appendSlice(allocator, "\"metadata_available\":false,\"max_event_string_bytes\":null,\"truncated_fields\":0");
    }
    try output.appendSlice(allocator, "}}");
}

fn appendAgentLimitations(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    artifact: Artifact,
    truncated: bool,
) std.mem.Allocator.Error!void {
    try output.appendSlice(allocator, "\"limitations\":[");
    var wrote = false;
    if (truncated) {
        try appendAgentWarning(output, allocator, &wrote, "result limited by query limit");
    }
    if (artifact.retention == null) {
        try appendAgentWarning(output, allocator, &wrote, "retention metadata unavailable");
    }
    if (artifact.sampling == null) {
        try appendAgentWarning(output, allocator, &wrote, "sampling metadata unavailable");
    }
    if (artifact.truncation == null) {
        try appendAgentWarning(output, allocator, &wrote, "truncation metadata unavailable");
    }
    try output.append(allocator, ']');
}

fn agentEvidenceConfidence(artifact: Artifact, truncated: bool) []const u8 {
    if (truncated) return "partial";
    if (artifact.retention) |retention| {
        if (retention.dropped_events > 0) return "partial";
    }
    if (artifact.sampling) |sampling| {
        if (sampling.sampled_events > 0) return "partial";
    }
    if (artifact.truncation) |truncation| {
        if (truncation.truncated_fields > 0) return "partial";
    }
    return "complete";
}

fn appendAgentEvent(output: *std.ArrayList(u8), allocator: std.mem.Allocator, event: Event) std.mem.Allocator.Error!void {
    try output.appendSlice(allocator, "{\"id\":");
    try output.print(allocator, "{d}", .{event.id});
    try output.appendSlice(allocator, ",\"kind\":");
    try appendJsonString(output, allocator, event.kind);
    try output.appendSlice(allocator, ",\"run_id\":");
    try appendOptionalJsonU64(output, allocator, event.run_id);
    try output.appendSlice(allocator, ",\"parent_id\":");
    try appendOptionalJsonU64(output, allocator, event.parent_id);
    try output.appendSlice(allocator, ",\"cause_event_id\":");
    try appendOptionalJsonU64(output, allocator, event.cause_event_id);
    try output.appendSlice(allocator, ",\"fiber_id\":");
    try appendOptionalJsonU64(output, allocator, event.fiber_id);
    try output.appendSlice(allocator, ",\"scope_id\":");
    try appendOptionalJsonU64(output, allocator, event.scope_id);
    try output.appendSlice(allocator, ",\"layer_id\":");
    try appendOptionalJsonU64(output, allocator, event.layer_id);
    try output.appendSlice(allocator, ",\"service_key\":");
    try appendJsonString(output, allocator, event.service_key);
    try output.appendSlice(allocator, ",\"resource_id\":");
    try appendOptionalJsonU64(output, allocator, event.resource_id);
    try output.appendSlice(allocator, ",\"schedule_id\":");
    try appendOptionalJsonU64(output, allocator, event.schedule_id);
    try output.appendSlice(allocator, ",\"label\":");
    try appendJsonString(output, allocator, event.label);
    try output.appendSlice(allocator, ",\"type_name\":");
    try appendJsonString(output, allocator, event.type_name);
    try output.appendSlice(allocator, ",\"status\":");
    try appendJsonString(output, allocator, event.status);
    try output.append(allocator, '}');
}

fn appendAgentRelationship(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    wrote: *bool,
    relationship: []const u8,
    event: Event,
    from_event_id: ?u64,
    to_event_id: ?u64,
) std.mem.Allocator.Error!void {
    if (wrote.*) try output.append(allocator, ',');
    try output.appendSlice(allocator, "{\"relationship\":");
    try appendJsonString(output, allocator, relationship);
    try output.appendSlice(allocator, ",\"event_id\":");
    try output.print(allocator, "{d}", .{event.id});
    try output.appendSlice(allocator, ",\"from_event_id\":");
    try appendOptionalJsonU64(output, allocator, from_event_id);
    try output.appendSlice(allocator, ",\"to_event_id\":");
    try appendOptionalJsonU64(output, allocator, to_event_id);
    try output.appendSlice(allocator, ",\"run_id\":");
    try appendOptionalJsonU64(output, allocator, event.run_id);
    try output.appendSlice(allocator, ",\"scope_id\":");
    try appendOptionalJsonU64(output, allocator, event.scope_id);
    try output.appendSlice(allocator, ",\"fiber_id\":");
    try appendOptionalJsonU64(output, allocator, event.fiber_id);
    try output.appendSlice(allocator, ",\"layer_id\":");
    try appendOptionalJsonU64(output, allocator, event.layer_id);
    try output.appendSlice(allocator, ",\"resource_id\":");
    try appendOptionalJsonU64(output, allocator, event.resource_id);
    try output.appendSlice(allocator, ",\"service_key\":");
    try appendJsonString(output, allocator, event.service_key);
    try output.append(allocator, '}');
    wrote.* = true;
}

fn appendAgentRelationships(output: *std.ArrayList(u8), allocator: std.mem.Allocator, events: []const Event) std.mem.Allocator.Error!void {
    try output.appendSlice(allocator, "\"relationships\":[");
    var wrote = false;
    for (events) |event| {
        if (event.parent_id) |parent_id| {
            try appendAgentRelationship(output, allocator, &wrote, "parent_of", event, parent_id, event.id);
        }
        if (event.cause_event_id) |cause_event_id| {
            try appendAgentRelationship(output, allocator, &wrote, "caused_by", event, cause_event_id, event.id);
        }
        if (std.mem.eql(u8, event.kind, "service_required")) {
            try appendAgentRelationship(output, allocator, &wrote, "requires", event, event.layer_id, null);
        } else if (std.mem.eql(u8, event.kind, "service_provided") or std.mem.eql(u8, event.kind, "service_replaced")) {
            try appendAgentRelationship(output, allocator, &wrote, "provides", event, event.layer_id, null);
        } else if (std.mem.eql(u8, event.kind, "resource_acquired")) {
            try appendAgentRelationship(output, allocator, &wrote, "owns", event, event.scope_id, event.resource_id);
        } else if (std.mem.eql(u8, event.kind, "resource_finalized")) {
            try appendAgentRelationship(output, allocator, &wrote, "finalizes", event, event.resource_id, event.id);
        } else if (isFiberEvent(event.kind) and event.scope_id != null) {
            try appendAgentRelationship(output, allocator, &wrote, "owns", event, event.scope_id, event.fiber_id);
        }
    }
    try output.append(allocator, ']');
}

fn appendNextQueryString(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    wrote: *bool,
    comptime format: []const u8,
    args: anytype,
) std.mem.Allocator.Error!void {
    const command = try std.fmt.allocPrint(allocator, format, args);
    defer allocator.free(command);
    if (wrote.*) try output.append(allocator, ',');
    try appendJsonString(output, allocator, command);
    wrote.* = true;
}

fn appendAgentNextQueries(output: *std.ArrayList(u8), allocator: std.mem.Allocator, events: []const Event) std.mem.Allocator.Error!void {
    try output.appendSlice(allocator, "\"next_queries\":[");
    var wrote = false;
    if (events.len > 0) {
        const event = events[events.len - 1];
        try appendNextQueryString(output, allocator, &wrote, "zig build causal-query -- --agent --file <artifact.json> explain_event {d}", .{event.id});
        try appendNextQueryString(output, allocator, &wrote, "zig build causal-query -- --agent --file <artifact.json> trace_cause {d}", .{event.id});
        if (event.run_id) |run_id| {
            try appendNextQueryString(output, allocator, &wrote, "zig build causal-query -- --agent --file <artifact.json> summarize_run {d}", .{run_id});
            try appendNextQueryString(output, allocator, &wrote, "zig build causal-query -- --agent --file <artifact.json> find_failures {d}", .{run_id});
            try appendNextQueryString(output, allocator, &wrote, "zig build causal-query -- --agent --file <artifact.json> list_findings {d}", .{run_id});
        }
    }
    try output.append(allocator, ']');
}

fn formatAgentQueryResult(
    allocator: std.mem.Allocator,
    query_args: []const []const u8,
    events: []const Event,
    total_matched_events: usize,
    all_events: []const Event,
    artifact: Artifact,
    parsed_args: ParsedQueryArgs,
    options: QueryOptions,
) std.mem.Allocator.Error![]const u8 {
    _ = all_events;
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    const truncated = total_matched_events > events.len;
    try output.appendSlice(allocator, "{\"schema\":");
    try appendJsonString(&output, allocator, agent_query_schema);
    try output.print(allocator, ",\"schema_version\":{d},\"query\":", .{agent_query_schema_version});
    try appendJsonString(&output, allocator, query_args[0]);
    try output.appendSlice(allocator, ",\"arguments\":[");
    for (query_args[1..], 0..) |arg, index| {
        if (index > 0) try output.append(allocator, ',');
        try appendJsonString(&output, allocator, arg);
    }
    try output.print(
        allocator,
        "],\"bounded\":true,\"truncated\":{},\"limit\":{d},\"total_matched_events\":{d},\"returned_events\":{d},\"confidence\":",
        .{ truncated, parsed_args.limit, total_matched_events, events.len },
    );
    try appendJsonString(&output, allocator, agentEvidenceConfidence(artifact, truncated));
    try output.append(allocator, ',');
    try appendAgentPolicy(&output, allocator, artifact);
    try output.append(allocator, ',');
    try appendAgentWarnings(&output, allocator, artifact, options);
    try output.append(allocator, ',');
    try appendAgentLimitations(&output, allocator, artifact, truncated);
    try output.appendSlice(allocator, ",\"events\":[");
    for (events, 0..) |event, index| {
        if (index > 0) try output.append(allocator, ',');
        try appendAgentEvent(&output, allocator, event);
    }
    try output.appendSlice(allocator, "],");
    try appendAgentRelationships(&output, allocator, events);
    try output.append(allocator, ',');
    try appendAgentNextQueries(&output, allocator, events);
    try output.appendSlice(allocator, "}\n");

    return output.toOwnedSlice(allocator);
}

fn formatQueryResult(
    allocator: std.mem.Allocator,
    args: []const []const u8,
    events: []const Event,
    all_events: []const Event,
    metadata: causal_artifact.ArtifactMetadata,
    options: QueryOptions,
) std.mem.Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "causal.query:");
    for (args) |arg| {
        try output.print(allocator, " {s}", .{arg});
    }
    try output.append(allocator, '\n');
    if (options.include_artifact_warnings) {
        try causal_artifact.appendArtifactCompatibilityWarnings(&output, allocator, options.artifact_label, metadata);
        try causal_artifact.appendUnknownEventKindWarnings(&output, allocator, options.artifact_label, all_events);
    }
    try output.print(allocator, "events: {d}\n", .{events.len});
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

test "query accepts versioned causal artifacts" {
    const output = try runQuery(std.testing.allocator, versioned_sample_json, &.{"snapshot"});
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "causal.query: snapshot") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "events: 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "event id=1 kind=run_started") != null);
}

test "query warns when artifact taxonomy is newer than supported" {
    const output = try runQuery(std.testing.allocator, future_taxonomy_sample_json, &.{"snapshot"});
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "warning: artifact event_taxonomy_version=2 newer than supported=1") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "events: 1") != null);
}

test "query warns on future schema version and unknown event kinds" {
    const output = try runQuery(std.testing.allocator, future_schema_unknown_kind_sample_json, &.{"snapshot"});
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "warning: artifact schema_version=2 newer than supported=1") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "warning: artifact event kind effect_suspended unknown to supported taxonomy=1") != null);
    try std.testing.expectEqual(@as(usize, 2), std.mem.count(u8, output, "warning:"));
    try std.testing.expect(std.mem.indexOf(u8, output, "events: 3") != null);
}

test "query warns on unsupported schema family" {
    const output = try runQuery(std.testing.allocator, unsupported_schema_sample_json, &.{"snapshot"});
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "warning: artifact schema=zigeffect.causal.v2 unsupported; expected zigeffect.causal.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "events: 1") != null);
}

test "query keeps legacy artifacts warning-free" {
    const output = try runQuery(std.testing.allocator, sample_json, &.{"snapshot"});
    defer std.testing.allocator.free(output);

    try std.testing.expectEqual(@as(usize, 0), std.mem.count(u8, output, "warning:"));
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

test "agent explain_event returns bounded schema relationships and next queries" {
    const output = try runQuery(std.testing.allocator, deep_runtime_sample_json, &.{ "--agent", "explain_event", "3" });
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "\"schema\":\"zigeffect.causal.agent-query.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"query\":\"explain_event\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"bounded\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"truncated\":false") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"id\":3") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"layer_id\":7") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"service_key\":\"services.config.Config\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"relationship\":\"requires\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"relationship\":\"caused_by\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"next_queries\"") != null);
}

test "agent summarize_run is bounded by explicit limit" {
    const output = try runQuery(std.testing.allocator, deep_runtime_sample_json, &.{ "--agent", "--limit", "3", "summarize_run", "1" });
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "\"query\":\"summarize_run\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"bounded\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"truncated\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"limit\":3") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"total_matched_events\":7") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"returned_events\":3") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"confidence\":\"partial\"") != null);
}

test "agent find_failures reports failure evidence and policy metadata" {
    const output = try runQuery(std.testing.allocator, deep_runtime_sample_json, &.{ "--agent", "find_failures", "1" });
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "\"query\":\"find_failures\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"id\":3") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"id\":5") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"id\":6") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"dropped_events\":2") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"sampled_events\":3") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"truncated_fields\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"confidence\":\"partial\"") != null);
}

test "agent next_queries returns commands for selected event" {
    const output = try runQuery(std.testing.allocator, deep_runtime_sample_json, &.{ "--agent", "next_queries", "5" });
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "\"query\":\"next_queries\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "zig build causal-query -- --agent --file <artifact.json> explain_event 5") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "zig build causal-query -- --agent --file <artifact.json> trace_cause 5") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "zig build causal-query -- --agent --file <artifact.json> summarize_run 1") != null);
}

test "invalid agent options return typed usage errors" {
    try std.testing.expectError(error.InvalidQueryNumber, runQuery(std.testing.allocator, deep_runtime_sample_json, &.{ "--agent", "--limit", "nope", "summarize_run", "1" }));
    try std.testing.expectError(error.InvalidQueryLimit, runQuery(std.testing.allocator, deep_runtime_sample_json, &.{ "--agent", "--limit", "999", "summarize_run", "1" }));
    try std.testing.expectError(error.UnknownQuery, runQuery(std.testing.allocator, deep_runtime_sample_json, &.{ "--agent", "--bogus", "summarize_run", "1" }));
}

test "agent cause chains stop at malformed cycles" {
    const output = try runQuery(std.testing.allocator, cyclic_cause_sample_json, &.{ "--agent", "trace_cause", "3" });
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "\"query\":\"trace_cause\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"total_matched_events\":3") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"returned_events\":3") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"id\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"id\":2") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"id\":3") != null);
}
