const std = @import("std");
const fx = @import("zigeffect");
const Secrets = @import("../secrets/root.zig");

pub const Lifecycle = @import("lifecycle.zig");

pub const receipt_schema = "zigeffect.application-fact.v1";
pub const max_fact_string_bytes: usize = 4096;

pub const FactError = error{
    InvalidFact,
    FactTooLarge,
};

pub const FactKind = enum {
    config_load,
    schema_decode,
    command_execution,
    request_handling,
    sql_transaction,
    external_call,
    artifact_production,
    component_dependency,
    acceptance_evaluation,
    lifecycle_transition,
};

pub const References = struct {
    artifact_id: []const u8 = "",
    domain_entity_ref: []const u8 = "",
    data_subject_ref: []const u8 = "",
    schema_ref: []const u8 = "",
    service_key: []const u8 = "",
    cause_event_id: ?u64 = null,
};

pub const Fact = struct {
    kind: FactKind,
    status: []const u8,
    detail: []const u8 = "",
    refs: References = .{},

    pub fn validate(self: Fact) FactError!void {
        if (self.status.len == 0) return error.InvalidFact;
        inline for (.{
            self.status,
            self.detail,
            self.refs.artifact_id,
            self.refs.domain_entity_ref,
            self.refs.data_subject_ref,
            self.refs.schema_ref,
            self.refs.service_key,
        }) |value| {
            if (value.len > max_fact_string_bytes) return error.FactTooLarge;
        }
    }
};

pub fn label(kind: FactKind) []const u8 {
    return switch (kind) {
        .config_load => "app.config.load",
        .schema_decode => "app.schema.decode",
        .command_execution => "app.command.execute",
        .request_handling => "app.request.handle",
        .sql_transaction => "app.sql.transaction",
        .external_call => "app.external.call",
        .artifact_production => "app.artifact.produce",
        .component_dependency => "app.component.dependency",
        .acceptance_evaluation => "app.acceptance.evaluate",
        .lifecycle_transition => "app.lifecycle.transition",
    };
}

pub fn semanticKind(kind: FactKind) fx.CausalAppSemanticKind {
    return switch (kind) {
        .config_load => .data_read,
        .schema_decode => .data_transformed,
        .command_execution, .request_handling, .lifecycle_transition => .function_boundary,
        .sql_transaction, .external_call, .component_dependency => .service_call,
        .artifact_production => .artifact_emitted,
        .acceptance_evaluation => .policy_decision,
    };
}

pub fn typeName(kind: FactKind) []const u8 {
    return switch (semanticKind(kind)) {
        .function_boundary => "zigeffect.app.function_boundary",
        .data_read => "zigeffect.app.data_read",
        .data_transformed => "zigeffect.app.data_transformed",
        .data_written => "zigeffect.app.data_written",
        .service_call => "zigeffect.app.service_call",
        .domain_action => "zigeffect.app.domain_action",
        .policy_decision => "zigeffect.app.policy_decision",
        .artifact_emitted => "zigeffect.app.artifact_emitted",
        .response_sent => "zigeffect.app.response_sent",
    };
}

pub fn kindFromEvent(event: fx.CausalEvent) ?FactKind {
    if (event.kind != .span_recorded) return null;
    inline for (std.meta.tags(FactKind)) |kind| {
        if (std.mem.eql(u8, event.label, label(kind)) and
            std.mem.eql(u8, event.type_name, typeName(kind))) return kind;
    }
    return null;
}

pub fn record(ctx: anytype, fact: Fact) ?u64 {
    fact.validate() catch return null;
    return ctx.recordCausal(.{
        .kind = .span_recorded,
        .label = label(fact.kind),
        .type_name = typeName(fact.kind),
        .status = fact.status,
        .redacted_detail = fact.detail,
        .service_key = fact.refs.service_key,
        .artifact_id = fact.refs.artifact_id,
        .domain_entity_ref = fact.refs.domain_entity_ref,
        .data_subject_ref = fact.refs.data_subject_ref,
        .schema_ref = fact.refs.schema_ref,
        .cause_event_id = fact.refs.cause_event_id,
    });
}

pub fn configLoad(key: []const u8, status: []const u8, detail: []const u8) Fact {
    return .{ .kind = .config_load, .status = status, .detail = detail, .refs = .{ .data_subject_ref = key } };
}

pub fn schemaDecode(schema_ref: []const u8, status: []const u8, detail: []const u8) Fact {
    return .{ .kind = .schema_decode, .status = status, .detail = detail, .refs = .{ .schema_ref = schema_ref } };
}

pub fn commandExecution(command: []const u8, status: []const u8, detail: []const u8) Fact {
    return .{ .kind = .command_execution, .status = status, .detail = detail, .refs = .{ .domain_entity_ref = command } };
}

pub fn requestHandling(route: []const u8, status: []const u8, detail: []const u8) Fact {
    return .{ .kind = .request_handling, .status = status, .detail = detail, .refs = .{ .domain_entity_ref = route } };
}

pub fn sqlTransaction(database: []const u8, transaction: []const u8, status: []const u8) Fact {
    return .{ .kind = .sql_transaction, .status = status, .refs = .{ .service_key = database, .domain_entity_ref = transaction } };
}

pub fn externalCall(service: []const u8, operation: []const u8, status: []const u8) Fact {
    return .{ .kind = .external_call, .status = status, .refs = .{ .service_key = service, .domain_entity_ref = operation } };
}

pub fn artifactProduction(artifact_id: []const u8, status: []const u8, detail: []const u8) Fact {
    return .{ .kind = .artifact_production, .status = status, .detail = detail, .refs = .{ .artifact_id = artifact_id } };
}

pub fn componentDependency(component: []const u8, dependency: []const u8, status: []const u8) Fact {
    return .{ .kind = .component_dependency, .status = status, .refs = .{ .domain_entity_ref = component, .service_key = dependency } };
}

pub fn acceptanceEvaluation(check_id: []const u8, status: []const u8, detail: []const u8) Fact {
    return .{ .kind = .acceptance_evaluation, .status = status, .detail = detail, .refs = .{ .domain_entity_ref = check_id } };
}

pub fn lifecycleTransition(state: Lifecycle.State, status: []const u8, cause_event_id: ?u64) Fact {
    return .{
        .kind = .lifecycle_transition,
        .status = status,
        .detail = @tagName(state),
        .refs = .{ .domain_entity_ref = @tagName(state), .cause_event_id = cause_event_id },
    };
}

pub fn receiptJsonAlloc(allocator: std.mem.Allocator, fact: Fact) ![]u8 {
    try fact.validate();
    const safe_status = try Secrets.redactAlloc(allocator, fact.status);
    defer allocator.free(safe_status);
    const safe_detail = try Secrets.redactAlloc(allocator, fact.detail);
    defer allocator.free(safe_detail);
    const safe_artifact = try Secrets.redactAlloc(allocator, fact.refs.artifact_id);
    defer allocator.free(safe_artifact);
    const safe_entity = try Secrets.redactAlloc(allocator, fact.refs.domain_entity_ref);
    defer allocator.free(safe_entity);
    const safe_subject = try Secrets.redactAlloc(allocator, fact.refs.data_subject_ref);
    defer allocator.free(safe_subject);
    const safe_schema = try Secrets.redactAlloc(allocator, fact.refs.schema_ref);
    defer allocator.free(safe_schema);
    const safe_service = try Secrets.redactAlloc(allocator, fact.refs.service_key);
    defer allocator.free(safe_service);

    return std.json.Stringify.valueAlloc(allocator, .{
        .schema = receipt_schema,
        .kind = fact.kind,
        .label = label(fact.kind),
        .type_name = typeName(fact.kind),
        .status = safe_status,
        .detail = safe_detail,
        .references = .{
            .artifact_id = safe_artifact,
            .domain_entity_ref = safe_entity,
            .data_subject_ref = safe_subject,
            .schema_ref = safe_schema,
            .service_key = safe_service,
            .cause_event_id = fact.refs.cause_event_id,
        },
    }, .{});
}

pub fn tracesEquivalent(
    allocator: std.mem.Allocator,
    left: []const fx.CausalEvent,
    right: []const fx.CausalEvent,
) std.mem.Allocator.Error!bool {
    if (!try fx.causalStructurallyEquivalent(allocator, left, right)) return false;

    const matched = try allocator.alloc(bool, right.len);
    defer allocator.free(matched);
    @memset(matched, false);

    for (left) |left_event| {
        if (kindFromEvent(left_event) == null) continue;
        var found = false;
        for (right, 0..) |right_event, right_index| {
            if (matched[right_index] or kindFromEvent(right_event) == null) continue;
            if (!sameFactShape(left, left_event, right, right_event)) continue;
            matched[right_index] = true;
            found = true;
            break;
        }
        if (!found) return false;
    }
    for (right, 0..) |event, index| {
        if (kindFromEvent(event) != null and !matched[index]) return false;
    }
    return true;
}

fn sameFactShape(
    left_events: []const fx.CausalEvent,
    left: fx.CausalEvent,
    right_events: []const fx.CausalEvent,
    right: fx.CausalEvent,
) bool {
    if (kindFromEvent(left).? != kindFromEvent(right).?) return false;
    inline for (.{
        .{ left.status, right.status },
        .{ left.service_key, right.service_key },
        .{ left.artifact_id, right.artifact_id },
        .{ left.domain_entity_ref, right.domain_entity_ref },
        .{ left.data_subject_ref, right.data_subject_ref },
        .{ left.schema_ref, right.schema_ref },
    }) |pair| {
        if (!std.mem.eql(u8, pair[0], pair[1])) return false;
    }
    return sameRelation(left_events, left.parent_id, right_events, right.parent_id) and
        sameRelation(left_events, left.cause_event_id, right_events, right.cause_event_id);
}

fn sameRelation(
    left_events: []const fx.CausalEvent,
    left_id: ?u64,
    right_events: []const fx.CausalEvent,
    right_id: ?u64,
) bool {
    if (left_id == null or right_id == null) return left_id == null and right_id == null;
    const left_owner = eventById(left_events, left_id.?) orelse return eventById(right_events, right_id.?) == null;
    const right_owner = eventById(right_events, right_id.?) orelse return false;
    if (left_owner.kind != right_owner.kind) return false;
    const left_app_kind = kindFromEvent(left_owner);
    const right_app_kind = kindFromEvent(right_owner);
    if (left_app_kind != null or right_app_kind != null) return left_app_kind == right_app_kind;
    if (left_owner.kind == .span_recorded) {
        return std.mem.eql(u8, left_owner.label, right_owner.label) and
            std.mem.eql(u8, left_owner.type_name, right_owner.type_name);
    }
    return true;
}

fn eventById(events: []const fx.CausalEvent, id: u64) ?fx.CausalEvent {
    for (events) |event| if (event.id == id) return event;
    return null;
}

test "application facts record stable semantic intent and references" {
    const Provider = struct {};
    var provider = Provider{};
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    var scope = fx.Scope.init(std.testing.allocator);
    defer scope.deinit();
    var ctx = fx.Context(Provider).init(std.testing.allocator, &provider, &scope).withCausalStore(&store);

    const facts = [_]Fact{
        configLoad("MODE", "success", "source=env"),
        schemaDecode("schema.Invoice.v1", "success", "decoded invoice"),
        commandExecution("serve", "success", "exit=0"),
        requestHandling("GET /health", "success", "status=200"),
        sqlTransaction("postgres", "invoice-create", "committed"),
        externalCall("billing", "charge", "success"),
        artifactProduction("receipt-42", "created", "application receipt"),
        componentDependency("api", "shared-domain", "resolved"),
        acceptanceEvaluation("check-health", "passed", "health route passed"),
        lifecycleTransition(.ready, "ready", null),
    };
    for (facts) |fact| try std.testing.expect(record(&ctx, fact) != null);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(facts.len, snapshot.events.len);
    for (snapshot.events, 0..) |event, index| {
        try std.testing.expectEqual(facts[index].kind, kindFromEvent(event).?);
        try std.testing.expectEqualStrings(label(facts[index].kind), event.label);
        try std.testing.expectEqualStrings(typeName(facts[index].kind), event.type_name);
    }
    try std.testing.expectEqualStrings("schema.Invoice.v1", snapshot.events[1].schema_ref);
    try std.testing.expectEqualStrings("receipt-42", snapshot.events[6].artifact_id);
    try std.testing.expectEqualStrings("shared-domain", snapshot.events[7].service_key);
}

test "application facts fail closed on invalid input and redact causal and JSON output" {
    const oversized = try std.testing.allocator.alloc(u8, max_fact_string_bytes + 1);
    defer std.testing.allocator.free(oversized);
    @memset(oversized, 'x');
    try std.testing.expectError(error.InvalidFact, (Fact{ .kind = .config_load, .status = "" }).validate());
    try std.testing.expectError(error.FactTooLarge, (Fact{ .kind = .config_load, .status = oversized }).validate());

    const Provider = struct {};
    var provider = Provider{};
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    var scope = fx.Scope.init(std.testing.allocator);
    defer scope.deinit();
    var ctx = fx.Context(Provider).init(std.testing.allocator, &provider, &scope).withCausalStore(&store);
    const secret_fact = artifactProduction("token=sentinel-secret-for-tests", "success", "password=sentinel-secret-for-tests");
    try std.testing.expect(record(&ctx, secret_fact) != null);
    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expect(std.mem.indexOf(u8, snapshot.events[0].artifact_id, "sentinel-secret") == null);
    try std.testing.expect(std.mem.indexOf(u8, snapshot.events[0].redacted_detail, "sentinel-secret") == null);

    const json = try receiptJsonAlloc(std.testing.allocator, secret_fact);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "sentinel-secret") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "REDACTED") != null);
}

test "application traces preserve semantic shape across reordered executor ids" {
    const left = [_]fx.CausalEvent{
        .{ .id = 1, .kind = .run_started, .status = "started" },
        .{ .id = 2, .kind = .span_recorded, .parent_id = 1, .label = label(.request_handling), .type_name = typeName(.request_handling), .status = "success", .domain_entity_ref = "GET /health" },
        .{ .id = 3, .kind = .span_recorded, .parent_id = 1, .cause_event_id = 2, .label = label(.schema_decode), .type_name = typeName(.schema_decode), .status = "success", .schema_ref = "HealthResponse.v1" },
        .{ .id = 4, .kind = .run_completed, .parent_id = 1, .status = "success" },
    };
    const right = [_]fx.CausalEvent{
        .{ .id = 30, .kind = .span_recorded, .parent_id = 10, .cause_event_id = 20, .label = label(.schema_decode), .type_name = typeName(.schema_decode), .status = "success", .schema_ref = "HealthResponse.v1" },
        .{ .id = 10, .kind = .run_started, .status = "started" },
        .{ .id = 40, .kind = .run_completed, .parent_id = 10, .status = "success" },
        .{ .id = 20, .kind = .span_recorded, .parent_id = 10, .label = label(.request_handling), .type_name = typeName(.request_handling), .status = "success", .domain_entity_ref = "GET /health" },
    };
    try std.testing.expect(try tracesEquivalent(std.testing.allocator, &left, &right));

    var changed = right;
    changed[0].schema_ref = "HealthResponse.v2";
    try std.testing.expect(!try tracesEquivalent(std.testing.allocator, &left, &changed));
    changed = right;
    changed[0].cause_event_id = 10;
    try std.testing.expect(!try tracesEquivalent(std.testing.allocator, &left, &changed));
}

fn allocationReceipt(allocator: std.mem.Allocator, fact: Fact) !void {
    const json = try receiptJsonAlloc(allocator, fact);
    allocator.free(json);
}

test "application fact receipts survive every allocation failure" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        allocationReceipt,
        .{artifactProduction("receipt", "created", "bounded")},
    );
}
