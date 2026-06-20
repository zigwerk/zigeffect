//hygiene:allow-long-file reason=full agent query surface (cause/lineage/resources/fibers/requirements/retries/--agent)
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
    artifact_id: []const u8 = "",
    domain_entity_ref: []const u8 = "",
    data_subject_ref: []const u8 = "",
    schema_ref: []const u8 = "",
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

const workflow_sample_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 1,
    \\  "event_taxonomy_version": 1,
    \\  "events": [
    \\    {"id":1,"kind":"workflow_event_recorded","run_id":7,"parent_id":null,"fiber_id":null,"scope_id":8,"trace_id":7,"span_id":1,"label":"causal-workflow","type_name":"workflow.workflow_started","status":"running","redacted_detail":""},
    \\    {"id":2,"kind":"workflow_event_recorded","run_id":7,"parent_id":1,"fiber_id":null,"scope_id":8,"trace_id":7,"span_id":2,"label":"wake","type_name":"workflow.workflow_suspended","status":"waiting","redacted_detail":"timer"},
    \\    {"id":3,"kind":"workflow_event_recorded","run_id":7,"parent_id":2,"fiber_id":null,"scope_id":8,"trace_id":7,"span_id":3,"label":"wake","type_name":"workflow.workflow_resumed","status":"running","redacted_detail":"timer_fired"},
    \\    {"id":4,"kind":"workflow_event_recorded","run_id":7,"parent_id":3,"fiber_id":50,"scope_id":8,"trace_id":7,"span_id":4,"label":"charge","type_name":"workflow.activity_retry_scheduled","status":"retry","redacted_detail":"attempt=1;delay_ms=250;reason=retry"},
    \\    {"id":5,"kind":"workflow_event_recorded","run_id":7,"parent_id":4,"fiber_id":null,"scope_id":8,"trace_id":7,"span_id":5,"label":"causal-workflow","type_name":"workflow.workflow_failed","status":"failed","redacted_detail":"exit.cause.failure:Boom"},
    \\    {"id":6,"kind":"workflow_event_recorded","run_id":99,"parent_id":null,"fiber_id":null,"scope_id":100,"trace_id":99,"span_id":1,"label":"other-workflow","type_name":"workflow.workflow_started","status":"running","redacted_detail":""},
    \\    {"id":7,"kind":"schedule_decision","run_id":7,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"non workflow retry","type_name":"Schedule.exponential","status":"exhausted","redacted_detail":""}
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

const app_semantic_sample_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 1,
    \\  "event_taxonomy_version": 1,
    \\  "retention": {
    \\    "max_events": 64,
    \\    "dropped_events": 0,
    \\    "oldest_retained_event_id": 1
    \\  },
    \\  "sampling": {
    \\    "log_every_n": null,
    \\    "metric_every_n": null,
    \\    "span_every_n": null,
    \\    "sampled_events": 0
    \\  },
    \\  "truncation": {
    \\    "max_event_string_bytes": 128,
    \\    "truncated_fields": 0
    \\  },
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"layer_id":null,"service_key":"","resource_id":null,"cause_event_id":null,"schedule_id":null,"artifact_id":"","domain_entity_ref":"","data_subject_ref":"","schema_ref":"","trace_id":null,"span_id":null,"label":"app.request GET /api/projects/:id","type_name":"zigeffect.app.request","status":"started","redacted_detail":""},
    \\    {"id":2,"kind":"span_recorded","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"layer_id":null,"service_key":"","resource_id":null,"cause_event_id":null,"schedule_id":null,"artifact_id":"","domain_entity_ref":"project:123","data_subject_ref":"tenant:acme","schema_ref":"Project.v1","trace_id":null,"span_id":null,"label":"load project","type_name":"zigeffect.app.data_read","status":"success","redacted_detail":""},
    \\    {"id":3,"kind":"span_recorded","run_id":1,"parent_id":2,"fiber_id":null,"scope_id":null,"layer_id":null,"service_key":"","resource_id":null,"cause_event_id":2,"schedule_id":null,"artifact_id":"","domain_entity_ref":"project:123","data_subject_ref":"tenant:acme","schema_ref":"ProjectResponse.v1","trace_id":null,"span_id":null,"label":"shape project response","type_name":"zigeffect.app.data_transformed","status":"success","redacted_detail":""},
    \\    {"id":4,"kind":"span_recorded","run_id":1,"parent_id":3,"fiber_id":null,"scope_id":null,"layer_id":null,"service_key":"","resource_id":null,"cause_event_id":3,"schedule_id":null,"artifact_id":"","domain_entity_ref":"project:123","data_subject_ref":"tenant:acme","schema_ref":"ProjectCache.v1","trace_id":null,"span_id":null,"label":"cache project","type_name":"zigeffect.app.data_written","status":"success","redacted_detail":""},
    \\    {"id":5,"kind":"span_recorded","run_id":1,"parent_id":4,"fiber_id":null,"scope_id":null,"layer_id":null,"service_key":"","resource_id":null,"cause_event_id":4,"schedule_id":null,"artifact_id":"response:project:123","domain_entity_ref":"project:123","data_subject_ref":"tenant:acme","schema_ref":"ProjectResponse.v1","trace_id":null,"span_id":null,"label":"response sent","type_name":"zigeffect.app.response_sent","status":"200","redacted_detail":""}
    \\  ]
    \\}
;

const compare_runs_sample_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 1,
    \\  "event_taxonomy_version": 1,
    \\  "retention": {
    \\    "max_events": 64,
    \\    "dropped_events": 0,
    \\    "oldest_retained_event_id": 1
    \\  },
    \\  "sampling": {
    \\    "log_every_n": null,
    \\    "metric_every_n": null,
    \\    "span_every_n": null,
    \\    "sampled_events": 0
    \\  },
    \\  "truncation": {
    \\    "max_event_string_bytes": 128,
    \\    "truncated_fields": 0
    \\  },
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"layer_id":null,"service_key":"","resource_id":null,"cause_event_id":null,"schedule_id":null,"trace_id":null,"span_id":null,"label":"before","type_name":"Fixture","status":"started","redacted_detail":""},
    \\    {"id":2,"kind":"service_required","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"layer_id":7,"service_key":"services.config.Config","resource_id":null,"cause_event_id":1,"schedule_id":null,"trace_id":null,"span_id":null,"label":"Config","type_name":"services.config.Config","status":"missing","redacted_detail":"missing provider"},
    \\    {"id":3,"kind":"resource_finalized","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":1,"layer_id":null,"service_key":"","resource_id":44,"cause_event_id":2,"schedule_id":null,"trace_id":null,"span_id":null,"label":"connection","type_name":"DbConnection","status":"failure","redacted_detail":"CloseFailed"},
    \\    {"id":4,"kind":"schedule_decision","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"layer_id":null,"service_key":"","resource_id":null,"cause_event_id":2,"schedule_id":99,"trace_id":null,"span_id":null,"label":"retry-config","type_name":"","status":"exhausted","redacted_detail":"attempt=2"},
    \\    {"id":5,"kind":"run_started","run_id":2,"parent_id":null,"fiber_id":null,"scope_id":null,"layer_id":null,"service_key":"","resource_id":null,"cause_event_id":null,"schedule_id":null,"trace_id":null,"span_id":null,"label":"after","type_name":"Fixture","status":"started","redacted_detail":""},
    \\    {"id":6,"kind":"service_required","run_id":2,"parent_id":5,"fiber_id":null,"scope_id":null,"layer_id":7,"service_key":"services.config.Config","resource_id":null,"cause_event_id":5,"schedule_id":null,"trace_id":null,"span_id":null,"label":"Config","type_name":"services.config.Config","status":"provided","redacted_detail":"provider added"},
    \\    {"id":7,"kind":"exit_recorded","run_id":2,"parent_id":5,"fiber_id":null,"scope_id":null,"layer_id":null,"service_key":"","resource_id":null,"cause_event_id":6,"schedule_id":null,"trace_id":null,"span_id":null,"label":"after","type_name":"Fixture","status":"success","redacted_detail":""}
    \\  ]
    \\}
;

const compare_runs_right_sample_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 1,
    \\  "event_taxonomy_version": 1,
    \\  "retention": {
    \\    "max_events": 64,
    \\    "dropped_events": 0,
    \\    "oldest_retained_event_id": 10
    \\  },
    \\  "sampling": {
    \\    "log_every_n": null,
    \\    "metric_every_n": null,
    \\    "span_every_n": null,
    \\    "sampled_events": 0
    \\  },
    \\  "truncation": {
    \\    "max_event_string_bytes": 128,
    \\    "truncated_fields": 0
    \\  },
    \\  "events": [
    \\    {"id":10,"kind":"run_started","run_id":2,"parent_id":null,"fiber_id":null,"scope_id":null,"layer_id":null,"service_key":"","resource_id":null,"cause_event_id":null,"schedule_id":null,"trace_id":null,"span_id":null,"label":"candidate","type_name":"Fixture","status":"started","redacted_detail":""},
    \\    {"id":11,"kind":"service_required","run_id":2,"parent_id":10,"fiber_id":null,"scope_id":null,"layer_id":7,"service_key":"services.config.Config","resource_id":null,"cause_event_id":10,"schedule_id":null,"trace_id":null,"span_id":null,"label":"Config","type_name":"services.config.Config","status":"provided","redacted_detail":"provider added"},
    \\    {"id":12,"kind":"resource_acquired","run_id":2,"parent_id":10,"fiber_id":null,"scope_id":1,"layer_id":null,"service_key":"","resource_id":45,"cause_event_id":null,"schedule_id":null,"trace_id":null,"span_id":null,"label":"connection","type_name":"DbConnection","status":"success","redacted_detail":""},
    \\    {"id":13,"kind":"resource_finalized","run_id":2,"parent_id":12,"fiber_id":null,"scope_id":1,"layer_id":null,"service_key":"","resource_id":45,"cause_event_id":12,"schedule_id":null,"trace_id":null,"span_id":null,"label":"connection","type_name":"DbConnection","status":"success","redacted_detail":""},
    \\    {"id":14,"kind":"exit_recorded","run_id":2,"parent_id":10,"fiber_id":null,"scope_id":null,"layer_id":null,"service_key":"","resource_id":null,"cause_event_id":13,"schedule_id":null,"trace_id":null,"span_id":null,"label":"candidate","type_name":"Fixture","status":"success","redacted_detail":""}
    \\  ]
    \\}
;

pub const QueryOptions = struct {
    include_artifact_warnings: bool = true,
    artifact_label: []const u8 = "artifact",
};

const RunPair = struct {
    left_run_id: u64,
    right_run_id: u64,
};

pub fn runQuery(allocator: std.mem.Allocator, json: []const u8, args: []const []const u8) ![]const u8 {
    return runQueryWithOptions(allocator, json, args, .{});
}

pub fn runQueryCompareFiles(
    allocator: std.mem.Allocator,
    left_json: []const u8,
    right_json: []const u8,
    args: []const []const u8,
) ![]const u8 {
    return runQueryCompareFilesWithOptions(allocator, left_json, right_json, args, .{});
}

pub fn runQueryWithOptions(
    allocator: std.mem.Allocator,
    json: []const u8,
    args: []const []const u8,
    options: QueryOptions,
) ![]const u8 {
    return runQueryInternal(allocator, json, null, args, options);
}

pub fn runQueryCompareFilesWithOptions(
    allocator: std.mem.Allocator,
    left_json: []const u8,
    right_json: []const u8,
    args: []const []const u8,
    options: QueryOptions,
) ![]const u8 {
    return runQueryInternal(allocator, left_json, right_json, args, options);
}

fn runQueryInternal(
    allocator: std.mem.Allocator,
    json: []const u8,
    compare_json: ?[]const u8,
    args: []const []const u8,
    options: QueryOptions,
) ![]const u8 {
    const parsed_args = try parseQueryArgs(args);
    const query_args = parsed_args.query_args;
    const query = query_args[0];

    if (std.mem.eql(u8, query, "compare_runs")) {
        var left_parsed = try std.json.parseFromSlice(Artifact, allocator, json, .{ .ignore_unknown_fields = true });
        defer left_parsed.deinit();

        if (compare_json) |right_json| {
            var right_parsed = try std.json.parseFromSlice(Artifact, allocator, right_json, .{ .ignore_unknown_fields = true });
            defer right_parsed.deinit();
            return formatCompareRunsQuery(
                allocator,
                query_args,
                left_parsed.value,
                right_parsed.value,
                false,
                parsed_args,
                options,
            );
        }

        return formatCompareRunsQuery(
            allocator,
            query_args,
            left_parsed.value,
            left_parsed.value,
            true,
            parsed_args,
            options,
        );
    }

    var parsed = try std.json.parseFromSlice(Artifact, allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    var matched = std.ArrayList(Event).empty;
    defer matched.deinit(allocator);

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
    } else if (std.mem.eql(u8, query, "workflow")) {
        const run_id = try requiredU64(query_args, 1);
        for (parsed.value.events) |event| {
            if (event.run_id == run_id and isWorkflowEvent(event)) {
                try matched.append(allocator, event);
            }
        }
    } else if (std.mem.eql(u8, query, "workflow-findings")) {
        const run_id = try requiredU64(query_args, 1);
        for (parsed.value.events) |event| {
            if (event.run_id == run_id and isWorkflowFindingEvent(event)) {
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
    } else if (std.mem.eql(u8, query, "trace_data")) {
        if (query_args.len <= 1) return error.MissingQueryArgument;
        const data_subject_ref = query_args[1];
        for (parsed.value.events) |event| {
            if (std.mem.eql(u8, event.data_subject_ref, data_subject_ref)) {
                try matched.append(allocator, event);
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
    var compare_file_path: ?[]const u8 = null;
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
        if (std.mem.eql(u8, arg, "--compare-file")) {
            if (index + 1 >= args.len) failUsage(error.MissingCompareFileArgument);
            index += 1;
            compare_file_path = args[index];
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

    const output = if (compare_file_path) |right_path| output: {
        const right_json = try std.Io.Dir.cwd().readFileAlloc(
            init.io,
            right_path,
            allocator,
            .limited(1024 * 1024),
        );
        defer allocator.free(right_json);
        break :output runQueryCompareFiles(allocator, json, right_json, query_args.items) catch |err| switch (err) {
            error.MissingQueryName,
            error.MissingQueryArgument,
            error.InvalidQueryNumber,
            error.InvalidQueryLimit,
            error.UnknownQuery,
            => failUsage(err),
            else => return err,
        };
    } else runQuery(allocator, json, query_args.items) catch |err| switch (err) {
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
        "causal-query error: {s}\nusage: zig build causal-query -- [--agent] [--limit <n>] [--file <path>] [--compare-file <path>] <snapshot|cause|lineage|resources|fibers|requirements|retries|workflow|workflow-findings|summarize_run|find_failures|explain_event|trace_cause|trace_data|compare_runs|list_findings|next_queries> [argument]\n",
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

fn parseRunPair(args: []const []const u8, index: usize) !RunPair {
    if (args.len <= index) return error.MissingQueryArgument;
    const value = args[index];
    const colon_index = std.mem.indexOfScalar(u8, value, ':') orelse return error.InvalidQueryNumber;
    if (std.mem.indexOfScalar(u8, value[colon_index + 1 ..], ':') != null) return error.InvalidQueryNumber;
    if (colon_index == 0 or colon_index + 1 >= value.len) return error.InvalidQueryNumber;

    const left_run_id = std.fmt.parseInt(u64, value[0..colon_index], 10) catch return error.InvalidQueryNumber;
    const right_run_id = std.fmt.parseInt(u64, value[colon_index + 1 ..], 10) catch return error.InvalidQueryNumber;
    return .{
        .left_run_id = left_run_id,
        .right_run_id = right_run_id,
    };
}

fn appendRunEvents(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(Event),
    events: []const Event,
    run_id: u64,
) std.mem.Allocator.Error!void {
    for (events) |event| {
        if (event.run_id == run_id) try output.append(allocator, event);
    }
}

fn appendFirstN(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(Event),
    events: []const Event,
    limit: usize,
) std.mem.Allocator.Error!void {
    const count = @min(events.len, limit);
    for (events[0..count]) |event| {
        try output.append(allocator, event);
    }
}

fn countFailureEvents(events: []const Event) usize {
    var count: usize = 0;
    for (events) |event| {
        if (isFailureEvidence(event)) count += 1;
    }
    return count;
}

fn firstEventId(events: []const Event) ?u64 {
    if (events.len == 0) return null;
    return events[0].id;
}

fn lastEventId(events: []const Event) ?u64 {
    if (events.len == 0) return null;
    return events[events.len - 1].id;
}

fn signedDelta(right: usize, left: usize) isize {
    return @as(isize, @intCast(right)) - @as(isize, @intCast(left));
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

fn appendAgentWarningItems(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    artifact: Artifact,
    options: QueryOptions,
    wrote: *bool,
) std.mem.Allocator.Error!void {
    if (artifact.schema) |schema| {
        if (!std.mem.eql(u8, schema, causal_artifact.supported_causal_schema)) {
            const warning = try std.fmt.allocPrint(
                allocator,
                "{s} schema={s} unsupported; expected {s}",
                .{ options.artifact_label, schema, causal_artifact.supported_causal_schema },
            );
            defer allocator.free(warning);
            try appendAgentWarning(output, allocator, wrote, warning);
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
            try appendAgentWarning(output, allocator, wrote, warning);
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
            try appendAgentWarning(output, allocator, wrote, warning);
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
        try appendAgentWarning(output, allocator, wrote, warning);
    }
}

fn appendAgentWarnings(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    artifact: Artifact,
    options: QueryOptions,
) std.mem.Allocator.Error!void {
    try output.appendSlice(allocator, "\"warnings\":[");
    var wrote = false;
    try appendAgentWarningItems(output, allocator, artifact, options, &wrote);
    try output.append(allocator, ']');
}

fn appendAgentPolicyObject(output: *std.ArrayList(u8), allocator: std.mem.Allocator, artifact: Artifact) std.mem.Allocator.Error!void {
    try output.append(allocator, '{');
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

fn appendAgentPolicy(output: *std.ArrayList(u8), allocator: std.mem.Allocator, artifact: Artifact) std.mem.Allocator.Error!void {
    try output.appendSlice(allocator, "\"policy\":");
    try appendAgentPolicyObject(output, allocator, artifact);
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

fn agentCompareEvidenceConfidence(left: Artifact, right: Artifact, truncated: bool, left_missing: bool, right_missing: bool) []const u8 {
    if (truncated or left_missing or right_missing) return "partial";
    if (!std.mem.eql(u8, agentEvidenceConfidence(left, false), "complete")) return "partial";
    if (!std.mem.eql(u8, agentEvidenceConfidence(right, false), "complete")) return "partial";
    return "complete";
}

fn appendArtifactPolicyLimitations(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    wrote: *bool,
    label: []const u8,
    artifact: Artifact,
) std.mem.Allocator.Error!void {
    if (artifact.retention == null) {
        const limitation = try std.fmt.allocPrint(allocator, "{s} retention metadata unavailable", .{label});
        defer allocator.free(limitation);
        try appendAgentWarning(output, allocator, wrote, limitation);
    }
    if (artifact.sampling == null) {
        const limitation = try std.fmt.allocPrint(allocator, "{s} sampling metadata unavailable", .{label});
        defer allocator.free(limitation);
        try appendAgentWarning(output, allocator, wrote, limitation);
    }
    if (artifact.truncation == null) {
        const limitation = try std.fmt.allocPrint(allocator, "{s} truncation metadata unavailable", .{label});
        defer allocator.free(limitation);
        try appendAgentWarning(output, allocator, wrote, limitation);
    }
}

fn appendAgentComparePolicy(output: *std.ArrayList(u8), allocator: std.mem.Allocator, left: Artifact, right: Artifact, same_artifact: bool) std.mem.Allocator.Error!void {
    try output.appendSlice(allocator, "\"policy\":{\"left\":");
    try appendAgentPolicyObject(output, allocator, left);
    try output.appendSlice(allocator, ",\"right\":");
    try appendAgentPolicyObject(output, allocator, if (same_artifact) left else right);
    try output.append(allocator, '}');
}

fn appendAgentCompareWarnings(output: *std.ArrayList(u8), allocator: std.mem.Allocator, left: Artifact, right: Artifact, same_artifact: bool) std.mem.Allocator.Error!void {
    try output.appendSlice(allocator, "\"warnings\":[");
    var wrote = false;
    try appendAgentWarningItems(output, allocator, left, .{ .artifact_label = "left" }, &wrote);
    if (!same_artifact) {
        try appendAgentWarningItems(output, allocator, right, .{ .artifact_label = "right" }, &wrote);
    }
    try output.append(allocator, ']');
}

fn appendAgentCompareLimitations(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    left: Artifact,
    right: Artifact,
    same_artifact: bool,
    truncated: bool,
    left_missing: bool,
    right_missing: bool,
) std.mem.Allocator.Error!void {
    try output.appendSlice(allocator, "\"limitations\":[");
    var wrote = false;
    if (truncated) {
        try appendAgentWarning(output, allocator, &wrote, "result limited by query limit");
    }
    if (same_artifact) {
        try appendAgentWarning(output, allocator, &wrote, "compare-file not provided; both runs selected from same artifact");
    }
    if (left_missing) {
        try appendAgentWarning(output, allocator, &wrote, "left run has no retained events");
    }
    if (right_missing) {
        try appendAgentWarning(output, allocator, &wrote, "right run has no retained events");
    }
    try appendArtifactPolicyLimitations(output, allocator, &wrote, "left", left);
    if (!same_artifact) {
        try appendArtifactPolicyLimitations(output, allocator, &wrote, "right", right);
    }
    try output.append(allocator, ']');
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
    try output.appendSlice(allocator, ",\"artifact_id\":");
    try appendJsonString(output, allocator, event.artifact_id);
    try output.appendSlice(allocator, ",\"domain_entity_ref\":");
    try appendJsonString(output, allocator, event.domain_entity_ref);
    try output.appendSlice(allocator, ",\"data_subject_ref\":");
    try appendJsonString(output, allocator, event.data_subject_ref);
    try output.appendSlice(allocator, ",\"schema_ref\":");
    try appendJsonString(output, allocator, event.schema_ref);
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
        if (std.mem.eql(u8, event.type_name, "zigeffect.app.data_read")) {
            try appendAgentRelationship(output, allocator, &wrote, "reads", event, null, event.id);
        } else if (std.mem.eql(u8, event.type_name, "zigeffect.app.data_written")) {
            try appendAgentRelationship(output, allocator, &wrote, "writes", event, null, event.id);
        } else if (std.mem.eql(u8, event.type_name, "zigeffect.app.data_transformed")) {
            try appendAgentRelationship(output, allocator, &wrote, "transforms", event, event.cause_event_id, event.id);
        } else if (std.mem.eql(u8, event.type_name, "zigeffect.app.artifact_emitted") or std.mem.eql(u8, event.type_name, "zigeffect.app.response_sent")) {
            try appendAgentRelationship(output, allocator, &wrote, "emits", event, event.cause_event_id, event.id);
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
        if (event.data_subject_ref.len > 0) {
            try appendNextQueryString(output, allocator, &wrote, "zig build causal-query -- --agent --file <artifact.json> trace_data {s}", .{event.data_subject_ref});
        }
    }
    try output.append(allocator, ']');
}

fn containsKind(events: []const Event, kind: []const u8) bool {
    for (events) |event| {
        if (std.mem.eql(u8, event.kind, kind)) return true;
    }
    return false;
}

fn containsStatus(events: []const Event, status: []const u8) bool {
    for (events) |event| {
        if (std.mem.eql(u8, event.status, status)) return true;
    }
    return false;
}

fn appendKindDifference(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    key: []const u8,
    left: []const Event,
    right: []const Event,
) std.mem.Allocator.Error!void {
    try output.print(allocator, "\"{s}\":[", .{key});
    var wrote = false;
    for (left, 0..) |event, index| {
        if (containsKind(left[0..index], event.kind)) continue;
        if (containsKind(right, event.kind)) continue;
        if (wrote) try output.append(allocator, ',');
        try appendJsonString(output, allocator, event.kind);
        wrote = true;
    }
    try output.append(allocator, ']');
}

fn appendStatusDifference(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    key: []const u8,
    left: []const Event,
    right: []const Event,
) std.mem.Allocator.Error!void {
    try output.print(allocator, "\"{s}\":[", .{key});
    var wrote = false;
    for (left, 0..) |event, index| {
        if (event.status.len == 0) continue;
        if (containsStatus(left[0..index], event.status)) continue;
        if (containsStatus(right, event.status)) continue;
        if (wrote) try output.append(allocator, ',');
        try appendJsonString(output, allocator, event.status);
        wrote = true;
    }
    try output.append(allocator, ']');
}

fn appendEventIdArray(output: *std.ArrayList(u8), allocator: std.mem.Allocator, key: []const u8, events: []const Event) std.mem.Allocator.Error!void {
    try output.print(allocator, "\"{s}\":[", .{key});
    for (events, 0..) |event, index| {
        if (index > 0) try output.append(allocator, ',');
        try output.print(allocator, "{d}", .{event.id});
    }
    try output.append(allocator, ']');
}

fn appendAgentComparisonObject(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    pair: RunPair,
    left_events: []const Event,
    right_events: []const Event,
    selected_left_events: []const Event,
    selected_right_events: []const Event,
    same_artifact: bool,
) std.mem.Allocator.Error!void {
    const left_failures = countFailureEvents(left_events);
    const right_failures = countFailureEvents(right_events);
    const left_findings = left_failures;
    const right_findings = right_failures;

    try output.appendSlice(allocator, "\"comparison\":{");
    try output.print(
        allocator,
        "\"same_artifact\":{},\"left_run_id\":{d},\"right_run_id\":{d},\"left_matched_events\":{d},\"right_matched_events\":{d},\"left_returned_events\":{d},\"right_returned_events\":{d},\"left_failure_events\":{d},\"right_failure_events\":{d},\"left_finding_events\":{d},\"right_finding_events\":{d},\"left_first_event_id\":",
        .{
            same_artifact,
            pair.left_run_id,
            pair.right_run_id,
            left_events.len,
            right_events.len,
            selected_left_events.len,
            selected_right_events.len,
            left_failures,
            right_failures,
            left_findings,
            right_findings,
        },
    );
    try appendOptionalJsonU64(output, allocator, firstEventId(left_events));
    try output.appendSlice(allocator, ",\"left_last_event_id\":");
    try appendOptionalJsonU64(output, allocator, lastEventId(left_events));
    try output.appendSlice(allocator, ",\"right_first_event_id\":");
    try appendOptionalJsonU64(output, allocator, firstEventId(right_events));
    try output.appendSlice(allocator, ",\"right_last_event_id\":");
    try appendOptionalJsonU64(output, allocator, lastEventId(right_events));
    try output.appendSlice(allocator, ",\"left\":{\"artifact_label\":\"left\",\"run_id\":");
    try output.print(allocator, "{d},\"matched_events\":{d},\"returned_events\":{d},\"failure_events\":{d},\"finding_events\":{d}", .{
        pair.left_run_id,
        left_events.len,
        selected_left_events.len,
        left_failures,
        left_findings,
    });
    try output.appendSlice(allocator, "},\"right\":{\"artifact_label\":\"right\",\"run_id\":");
    try output.print(allocator, "{d},\"matched_events\":{d},\"returned_events\":{d},\"failure_events\":{d},\"finding_events\":{d}", .{
        pair.right_run_id,
        right_events.len,
        selected_right_events.len,
        right_failures,
        right_findings,
    });
    try output.appendSlice(allocator, "},\"deltas\":{");
    try output.print(
        allocator,
        "\"event_delta\":{d},\"failure_delta\":{d},\"finding_delta\":{d}",
        .{
            signedDelta(right_events.len, left_events.len),
            signedDelta(right_failures, left_failures),
            signedDelta(right_findings, left_findings),
        },
    );
    try output.appendSlice(allocator, "},");
    try appendKindDifference(output, allocator, "left_only_kinds", left_events, right_events);
    try output.append(allocator, ',');
    try appendKindDifference(output, allocator, "right_only_kinds", right_events, left_events);
    try output.append(allocator, ',');
    try appendStatusDifference(output, allocator, "left_only_statuses", left_events, right_events);
    try output.append(allocator, ',');
    try appendStatusDifference(output, allocator, "right_only_statuses", right_events, left_events);
    try output.append(allocator, ',');
    try appendEventIdArray(output, allocator, "selected_left_event_ids", selected_left_events);
    try output.append(allocator, ',');
    try appendEventIdArray(output, allocator, "selected_right_event_ids", selected_right_events);
    try output.append(allocator, '}');
}

fn appendAgentCompareNextQueries(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    pair: RunPair,
    selected_left_events: []const Event,
    selected_right_events: []const Event,
    same_artifact: bool,
) std.mem.Allocator.Error!void {
    const left_placeholder = if (same_artifact) "<artifact.json>" else "<left-artifact.json>";
    const right_placeholder = if (same_artifact) "<artifact.json>" else "<right-artifact.json>";

    try output.appendSlice(allocator, "\"next_queries\":[");
    var wrote = false;
    try appendNextQueryString(output, allocator, &wrote, "zig build causal-query -- --agent --file {s} summarize_run {d}", .{ left_placeholder, pair.left_run_id });
    try appendNextQueryString(output, allocator, &wrote, "zig build causal-query -- --agent --file {s} summarize_run {d}", .{ right_placeholder, pair.right_run_id });
    try appendNextQueryString(output, allocator, &wrote, "zig build causal-query -- --agent --file {s} find_failures {d}", .{ left_placeholder, pair.left_run_id });
    try appendNextQueryString(output, allocator, &wrote, "zig build causal-query -- --agent --file {s} find_failures {d}", .{ right_placeholder, pair.right_run_id });
    if (selected_left_events.len > 0) {
        const event = selected_left_events[selected_left_events.len - 1];
        try appendNextQueryString(output, allocator, &wrote, "zig build causal-query -- --agent --file {s} explain_event {d}", .{ left_placeholder, event.id });
        try appendNextQueryString(output, allocator, &wrote, "zig build causal-query -- --agent --file {s} trace_cause {d}", .{ left_placeholder, event.id });
    }
    if (selected_right_events.len > 0) {
        const event = selected_right_events[selected_right_events.len - 1];
        try appendNextQueryString(output, allocator, &wrote, "zig build causal-query -- --agent --file {s} explain_event {d}", .{ right_placeholder, event.id });
        try appendNextQueryString(output, allocator, &wrote, "zig build causal-query -- --agent --file {s} trace_cause {d}", .{ right_placeholder, event.id });
    }
    try output.append(allocator, ']');
}

fn formatAgentCompareRunsResult(
    allocator: std.mem.Allocator,
    query_args: []const []const u8,
    pair: RunPair,
    left_artifact: Artifact,
    right_artifact: Artifact,
    left_events: []const Event,
    right_events: []const Event,
    selected_left_events: []const Event,
    selected_right_events: []const Event,
    selected_events: []const Event,
    parsed_args: ParsedQueryArgs,
    same_artifact: bool,
) std.mem.Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    const total_matched_events = left_events.len + right_events.len;
    const truncated = selected_events.len < total_matched_events;
    const left_missing = left_events.len == 0;
    const right_missing = right_events.len == 0;

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
        .{ truncated, parsed_args.limit, total_matched_events, selected_events.len },
    );
    try appendJsonString(&output, allocator, agentCompareEvidenceConfidence(left_artifact, right_artifact, truncated, left_missing, right_missing));
    try output.append(allocator, ',');
    try appendAgentComparePolicy(&output, allocator, left_artifact, right_artifact, same_artifact);
    try output.append(allocator, ',');
    try appendAgentCompareWarnings(&output, allocator, left_artifact, right_artifact, same_artifact);
    try output.append(allocator, ',');
    try appendAgentCompareLimitations(&output, allocator, left_artifact, right_artifact, same_artifact, truncated, left_missing, right_missing);
    try output.append(allocator, ',');
    try appendAgentComparisonObject(&output, allocator, pair, left_events, right_events, selected_left_events, selected_right_events, same_artifact);
    try output.appendSlice(allocator, ",\"events\":[");
    for (selected_events, 0..) |event, index| {
        if (index > 0) try output.append(allocator, ',');
        try appendAgentEvent(&output, allocator, event);
    }
    try output.appendSlice(allocator, "],");
    try appendAgentRelationships(&output, allocator, selected_events);
    try output.append(allocator, ',');
    try appendAgentCompareNextQueries(&output, allocator, pair, selected_left_events, selected_right_events, same_artifact);
    try output.appendSlice(allocator, "}\n");

    return output.toOwnedSlice(allocator);
}

fn formatCompareRunsQuery(
    allocator: std.mem.Allocator,
    query_args: []const []const u8,
    left_artifact: Artifact,
    right_artifact: Artifact,
    same_artifact: bool,
    parsed_args: ParsedQueryArgs,
    options: QueryOptions,
) ![]const u8 {
    const pair = try parseRunPair(query_args, 1);

    var left_events = std.ArrayList(Event).empty;
    defer left_events.deinit(allocator);
    var right_events = std.ArrayList(Event).empty;
    defer right_events.deinit(allocator);
    var selected_left_events = std.ArrayList(Event).empty;
    defer selected_left_events.deinit(allocator);
    var selected_right_events = std.ArrayList(Event).empty;
    defer selected_right_events.deinit(allocator);
    var selected_events = std.ArrayList(Event).empty;
    defer selected_events.deinit(allocator);

    try appendRunEvents(allocator, &left_events, left_artifact.events, pair.left_run_id);
    try appendRunEvents(allocator, &right_events, right_artifact.events, pair.right_run_id);

    const left_limit = parsed_args.limit / 2;
    const right_limit = parsed_args.limit - left_limit;
    try appendFirstN(allocator, &selected_left_events, left_events.items, left_limit);
    try appendFirstN(allocator, &selected_right_events, right_events.items, right_limit);
    try appendAll(allocator, &selected_events, selected_left_events.items);
    try appendAll(allocator, &selected_events, selected_right_events.items);

    if (parsed_args.mode == .agent_json) {
        return formatAgentCompareRunsResult(
            allocator,
            query_args,
            pair,
            left_artifact,
            right_artifact,
            left_events.items,
            right_events.items,
            selected_left_events.items,
            selected_right_events.items,
            selected_events.items,
            parsed_args,
            same_artifact,
        );
    }

    return formatQueryResult(
        allocator,
        query_args,
        selected_events.items,
        left_artifact.events,
        .{
            .schema = left_artifact.schema,
            .schema_version = left_artifact.schema_version,
            .event_taxonomy_version = left_artifact.event_taxonomy_version,
        },
        options,
    );
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

fn isWorkflowEvent(event: Event) bool {
    return std.mem.eql(u8, event.kind, "workflow_event_recorded");
}

fn isWorkflowFindingEvent(event: Event) bool {
    if (!isWorkflowEvent(event)) return false;
    if (std.mem.eql(u8, event.type_name, "workflow.workflow_suspended")) return true;
    if (std.mem.eql(u8, event.type_name, "workflow.workflow_resumed")) return true;
    if (std.mem.endsWith(u8, event.type_name, "_retry_scheduled")) return true;
    if (std.mem.endsWith(u8, event.type_name, "_failed")) return true;
    if (std.mem.eql(u8, event.status, "retry")) return true;
    if (std.mem.eql(u8, event.status, "failed")) return true;
    return false;
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

test "workflow query selects workflow events by run" {
    const output = try runQuery(std.testing.allocator, workflow_sample_json, &.{ "workflow", "7" });
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "causal.query: workflow 7") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "events: 5") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "event id=1 kind=workflow_event_recorded") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "type=workflow.workflow_failed") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "event id=6 kind=workflow_event_recorded") == null);
    try std.testing.expect(std.mem.indexOf(u8, output, "event id=7 kind=schedule_decision") == null);
}

test "workflow findings query selects workflow evidence by run" {
    const output = try runQuery(std.testing.allocator, workflow_sample_json, &.{ "workflow-findings", "7" });
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "causal.query: workflow-findings 7") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "events: 4") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "type=workflow.workflow_suspended") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "type=workflow.workflow_resumed") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "type=workflow.activity_retry_scheduled") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "type=workflow.workflow_failed") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "type=workflow.workflow_started") == null);
    try std.testing.expect(std.mem.indexOf(u8, output, "event id=6 kind=workflow_event_recorded") == null);
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

test "agent trace_data returns semantic data lineage relationships" {
    const output = try runQuery(std.testing.allocator, app_semantic_sample_json, &.{ "--agent", "trace_data", "tenant:acme" });
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "\"query\":\"trace_data\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"data_subject_ref\":\"tenant:acme\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"domain_entity_ref\":\"project:123\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"schema_ref\":\"Project.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"artifact_id\":\"response:project:123\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"relationship\":\"reads\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"relationship\":\"writes\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"relationship\":\"transforms\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"relationship\":\"emits\"") != null);
}

test "agent compare_runs compares two runs from one artifact" {
    const output = try runQuery(std.testing.allocator, compare_runs_sample_json, &.{ "--agent", "compare_runs", "1:2" });
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "\"query\":\"compare_runs\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"comparison\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"same_artifact\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"left_run_id\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"right_run_id\":2") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"left_matched_events\":4") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"right_matched_events\":3") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"failure_delta\":-3") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"left_only_kinds\":[\"resource_finalized\",\"schedule_decision\"]") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "both runs selected from same artifact") != null);
}

test "agent compare_runs compares two files with bounded evidence" {
    const output = try runQueryCompareFiles(
        std.testing.allocator,
        compare_runs_sample_json,
        compare_runs_right_sample_json,
        &.{ "--agent", "--limit", "5", "compare_runs", "1:2" },
    );
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "\"query\":\"compare_runs\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"same_artifact\":false") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"truncated\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"limit\":5") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"total_matched_events\":9") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"returned_events\":5") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"selected_left_event_ids\":[1,2]") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"selected_right_event_ids\":[10,11,12]") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "<left-artifact.json>") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "<right-artifact.json>") != null);
}

test "agent compare_runs reports missing run evidence as partial" {
    const output = try runQuery(std.testing.allocator, compare_runs_sample_json, &.{ "--agent", "compare_runs", "99:2" });
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "\"query\":\"compare_runs\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"left_matched_events\":0") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"right_matched_events\":3") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"confidence\":\"partial\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "left run has no retained events") != null);
}

test "agent compare_runs rejects malformed run pair arguments" {
    try std.testing.expectError(error.MissingQueryArgument, runQuery(std.testing.allocator, compare_runs_sample_json, &.{ "--agent", "compare_runs" }));
    try std.testing.expectError(error.InvalidQueryNumber, runQuery(std.testing.allocator, compare_runs_sample_json, &.{ "--agent", "compare_runs", "nope" }));
    try std.testing.expectError(error.InvalidQueryNumber, runQuery(std.testing.allocator, compare_runs_sample_json, &.{ "--agent", "compare_runs", "1:" }));
    try std.testing.expectError(error.InvalidQueryNumber, runQuery(std.testing.allocator, compare_runs_sample_json, &.{ "--agent", "compare_runs", "1:2:3" }));
}

test "agent compare_runs preserves left and right artifact warnings" {
    const output = try runQueryCompareFiles(
        std.testing.allocator,
        future_schema_unknown_kind_sample_json,
        future_taxonomy_sample_json,
        &.{ "--agent", "compare_runs", "1:1" },
    );
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "left schema_version=2 newer than supported=1") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "left event kind effect_suspended unknown to supported taxonomy=1") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "right event_taxonomy_version=2 newer than supported=1") != null);
}
