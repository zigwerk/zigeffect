const std = @import("std");
const fx = @import("zigeffect");

const kernel = fx.kernel;

const EmitContext = kernel.Effect(void, error{ OutOfMemory, MissingScope }, .{});
const emit_context = EmitContext.fromFn(struct {
    fn run(ctx: *EmitContext.Context) EmitContext.FailureType!void {
        _ = ctx.recordCausal(.{
            .kind = .activity_completed,
            .label = "development.change",
            .status = "complete",
        });
    }
}.run);

const ProductId = fx.Lineage.Key([]const u8, .{
    .name = "commerce.product.id",
    .privacy = .internal,
    .propagation = .distributed,
    .export_policy = .otel,
});
const OrderId = fx.Lineage.Key(u64, .{
    .name = "commerce.order.id",
    .privacy = .internal,
});
const Username = fx.Lineage.Key([]const u8, .{
    .name = "identity.username",
    .privacy = .personal,
    .propagation = .distributed,
});

const TrackedResource = struct {
    allocator: std.mem.Allocator,
};

fn releaseTrackedResource(resource: *TrackedResource) void {
    const allocator = resource.allocator;
    allocator.destroy(resource);
}

const lineage_child = EmitContext.fromFn(struct {
    fn run(ctx: *EmitContext.Context) EmitContext.FailureType!void {
        _ = ctx.recordCausal(.{
            .kind = .activity_completed,
            .label = "lineage.child.semantic",
            .status = "complete",
        });
    }
}.run);

const lineage_parent = EmitContext.fromFn(struct {
    fn run(ctx: *EmitContext.Context) EmitContext.FailureType!void {
        const resource = try ctx.allocator().create(TrackedResource);
        resource.* = .{ .allocator = ctx.allocator() };
        errdefer ctx.allocator().destroy(resource);
        try ctx.addFinalizerFor(TrackedResource, resource, releaseTrackedResource);

        var child = ctx.runtime();
        try child.run(lineage_child.named("lineage.child"));
    }
}.run);

const register_tracked_resource = EmitContext.fromFn(struct {
    fn run(ctx: *EmitContext.Context) EmitContext.FailureType!void {
        const resource = try ctx.allocator().create(TrackedResource);
        resource.* = .{ .allocator = ctx.allocator() };
        errdefer ctx.allocator().destroy(resource);
        try ctx.addFinalizerFor(TrackedResource, resource, releaseTrackedResource);
    }
}.run);

test "typed lineage references are private deterministic bounded and transport safe" {
    const product = try ProductId.reference(77, "product-42");
    const same_product = try ProductId.reference(77, "product-42");
    const other_project = try ProductId.reference(78, "product-42");
    try std.testing.expectEqual(product, same_product);
    try std.testing.expect(!std.meta.eql(product, other_project));
    try std.testing.expectEqual(fx.Lineage.Export.otel, product.export_policy);
    try std.testing.expectError(error.MissingProjectIdentity, Username.reference(null, "alice"));

    const username = try Username.reference(77, "alice");
    try std.testing.expectEqual(fx.Lineage.Export.graph_only, username.export_policy);

    var set = fx.Lineage.Set.empty;
    set = set.with(product);
    set = set.with(username);
    try std.testing.expect(set.contains(product));
    try std.testing.expect(set.contains(username));

    var buffer: [fx.Lineage.max_baggage_bytes]u8 = undefined;
    const baggage = try set.formatBaggage(&buffer);
    try std.testing.expect(std.mem.indexOf(u8, baggage, "product-42") == null);
    try std.testing.expect(std.mem.indexOf(u8, baggage, "alice") == null);
    const parsed = try fx.Lineage.Set.parseBaggage(baggage);
    try std.testing.expect(parsed.contains(product));
    try std.testing.expect(parsed.contains(username));

    var graph_only_otel = try fx.mapCausalEventToOtelRecord(std.testing.allocator, .{
        .id = 1,
        .kind = .activity_completed,
        .context = .{ .lineage = fx.Lineage.Set.empty.with(username) },
    });
    defer graph_only_otel.deinit(std.testing.allocator);
    try std.testing.expect(graph_only_otel.attribute("zigeffect.lineage.count") == null);
}

test "tracked effects enrich structural semantic child fiber graph and OTEL events" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    const empty = kernel.Layer.empty();
    var runtime = try kernel.ManagedRuntime(@TypeOf(empty)).make(std.testing.allocator, empty, .{
        .causal_store = &store,
        .causal_context = .{ .project_id = 77 },
    });
    defer runtime.deinit();

    try runtime.run(
        lineage_parent
            .track(OrderId, 9001)
            .track(ProductId, "product-42")
            .named("lineage.parent"),
    );

    const product = try ProductId.reference(77, "product-42");
    const order = try OrderId.reference(77, 9001);
    var product_flow = try store.trackedLineage(std.testing.allocator, product);
    defer product_flow.deinit();
    try std.testing.expect(product_flow.events.len >= 8);

    var found_child_fiber = false;
    var found_child_scope_opened = false;
    var found_child_scope_closed = false;
    var found_resource_acquired = false;
    var found_resource_finalized = false;
    var found_semantic = false;
    var found_joint_context = false;
    for (product_flow.events) |event| {
        if (event.context.lineage.contains(product) and event.context.lineage.contains(order)) {
            found_joint_context = true;
        }
        if (event.kind == .fiber_started and std.mem.eql(u8, event.label, "lineage.child")) {
            found_child_fiber = true;
        }
        if (event.kind == .scope_opened) found_child_scope_opened = true;
        if (event.kind == .scope_closed) found_child_scope_closed = true;
        if (event.kind == .resource_acquired and std.mem.eql(u8, event.type_name, @typeName(TrackedResource))) {
            found_resource_acquired = true;
        }
        if (event.kind == .resource_finalized and std.mem.eql(u8, event.type_name, @typeName(TrackedResource))) {
            found_resource_finalized = true;
        }
        if (event.kind == .activity_completed and std.mem.eql(u8, event.label, "lineage.child.semantic")) {
            found_semantic = true;
        }
    }
    try std.testing.expect(found_child_fiber);
    try std.testing.expect(found_child_scope_opened);
    try std.testing.expect(found_child_scope_closed);
    try std.testing.expect(found_resource_acquired);
    try std.testing.expect(found_resource_finalized);
    try std.testing.expect(found_semantic);
    try std.testing.expect(found_joint_context);

    const json = try fx.formatCausalJsonLine(std.testing.allocator, product_flow.events[product_flow.events.len - 1]);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "product-42") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"lineage\"") != null);

    var otel = try fx.mapCausalEventToOtelRecord(std.testing.allocator, product_flow.events[product_flow.events.len - 1]);
    defer otel.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u64, 1), otel.attribute("zigeffect.lineage.exported_count").?.u64);
    try std.testing.expectEqual(product.key_id, otel.attribute("zigeffect.lineage.0.key_id").?.u64);
    try std.testing.expectEqual(product.value_id_high, otel.attribute("zigeffect.lineage.0.value_id_high").?.u64);
    try std.testing.expectEqual(product.value_id_low, otel.attribute("zigeffect.lineage.0.value_id_low").?.u64);
}

test "resource finalizers retain immutable lineage without cross-scope contamination" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    const empty = kernel.Layer.empty();
    var runtime = try kernel.ManagedRuntime(@TypeOf(empty)).make(std.testing.allocator, empty, .{
        .causal_store = &store,
        .causal_context = .{ .project_id = 77 },
    });
    defer runtime.deinit();

    try runtime.run(
        register_tracked_resource
            .track(ProductId, "product-a")
            .andThen(register_tracked_resource.track(ProductId, "product-b")),
    );

    const product_a = try ProductId.reference(77, "product-a");
    const product_b = try ProductId.reference(77, "product-b");
    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    var resources_for_a: usize = 0;
    var resources_for_b: usize = 0;
    for (snapshot.events) |event| {
        if (event.kind != .resource_acquired and event.kind != .resource_finalized) continue;
        if (!std.mem.eql(u8, event.type_name, @typeName(TrackedResource))) continue;
        if (event.context.lineage.contains(product_a)) {
            try std.testing.expect(!event.context.lineage.contains(product_b));
            resources_for_a += 1;
        }
        if (event.context.lineage.contains(product_b)) {
            try std.testing.expect(!event.context.lineage.contains(product_a));
            resources_for_b += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 2), resources_for_a);
    try std.testing.expectEqual(@as(usize, 2), resources_for_b);
}

test "causal context v2 and typed links are bounded and survive every projection" {
    var event = fx.CausalEvent{
        .id = 41,
        .kind = .activity_completed,
        .label = "proof",
        .status = "complete",
        .context = .{
            .runtime_instance_id = 7,
            .graph_session_id = 9,
            .development_task_id = 11,
            .work_packet_id = 12,
            .change_set_id = 13,
            .trace_id_high = 14,
            .trace_id_low = 15,
            .span_id = 16,
        },
    };
    try event.addLink(.{ .kind = .proof, .event_id = 37, .graph_session_id = 9 });
    try event.addLink(.{ .kind = .change, .event_id = 38, .graph_session_id = 9 });
    try std.testing.expectEqual(@as(usize, 2), event.activeLinks().len);

    const jsonl = try fx.formatCausalJsonLine(std.testing.allocator, event);
    defer std.testing.allocator.free(jsonl);
    try std.testing.expect(std.mem.indexOf(u8, jsonl, "\"development_task_id\":11") != null);
    try std.testing.expect(std.mem.indexOf(u8, jsonl, "\"kind\":\"proof\"") != null);

    var nendb = try fx.mapCausalEventToNendbWrite(std.testing.allocator, event);
    defer fx.deinitCausalNendbWrite(std.testing.allocator, &nendb);
    try std.testing.expect(std.mem.indexOf(u8, nendb.node.properties, "\"change_set_id\":13") != null);
    try std.testing.expect(std.mem.indexOf(u8, nendb.node.properties, "\"graph_session_id\":9") != null);

    var otel = try fx.mapCausalEventToOtelRecord(std.testing.allocator, event);
    defer otel.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u64, 11), otel.attribute("zigeffect.causal.development_task_id").?.u64);
    try std.testing.expectEqual(@as(u64, 13), otel.attribute("zigeffect.causal.change_set_id").?.u64);
    try std.testing.expectEqual(@as(u64, 2), otel.attribute("zigeffect.causal.link_count").?.u64);
}

test "managed runtime handles propagate development context to every semantic event" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    const empty = kernel.Layer.empty();
    var runtime = try kernel.ManagedRuntime(@TypeOf(empty)).make(std.testing.allocator, empty, .{
        .causal_store = &store,
        .causal_context = .{ .runtime_instance_id = 101, .graph_session_id = 202 },
    });
    defer runtime.deinit();

    var handle = runtime.handle().withCausalContext(.{
        .development_task_id = 303,
        .work_packet_id = 404,
        .change_set_id = 505,
    });
    try handle.run(emit_context.named("development.context-propagation"));

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    var found = false;
    for (snapshot.events) |event| {
        if (!std.mem.eql(u8, event.label, "development.change")) continue;
        found = true;
        try std.testing.expectEqual(@as(?u64, 101), event.context.runtime_instance_id);
        try std.testing.expectEqual(@as(?u64, 202), event.context.graph_session_id);
        try std.testing.expectEqual(@as(?u64, 303), event.context.development_task_id);
        try std.testing.expectEqual(@as(?u64, 404), event.context.work_packet_id);
        try std.testing.expectEqual(@as(?u64, 505), event.context.change_set_id);
    }
    try std.testing.expect(found);
}

test "canonical OTLP projection emits correlated spans and logs from one causal batch" {
    var span = try fx.mapCausalEventToOtelRecord(std.testing.allocator, .{
        .id = 1,
        .kind = .activity_completed,
        .trace_id = 11,
        .span_id = 12,
        .context = .{ .development_task_id = 13, .graph_session_id = 14 },
        .label = "execute_tool",
        .status = "complete",
    });
    defer span.deinit(std.testing.allocator);
    var log = try fx.mapCausalEventToOtelRecord(std.testing.allocator, .{
        .id = 2,
        .kind = .log_recorded,
        .context = .{ .development_task_id = 13, .graph_session_id = 14 },
        .label = "proof recorded",
        .status = "info",
    });
    defer log.deinit(std.testing.allocator);
    const envelope = try fx.formatOtlpSignals(std.testing.allocator, &.{ span, log }, .{});
    defer std.testing.allocator.free(envelope);
    try std.testing.expect(std.mem.indexOf(u8, envelope, "\"resourceSpans\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, envelope, "\"resourceLogs\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, envelope, "\"resourceMetrics\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, envelope, "zigeffect.causal.events") != null);
    try std.testing.expect(std.mem.indexOf(u8, envelope, "zigeffect.causal.development_task_id") != null);
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, envelope, .{});
    defer parsed.deinit();
}

test "W3C traceparent parses and formats exact 128 bit causal identity" {
    const text = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01";
    const parsed = try fx.parseTraceParent(text);
    const formatted = parsed.format();
    try std.testing.expectEqualStrings(text, &formatted);
    const context = parsed.context();
    try std.testing.expectEqual(@as(?u64, 0x4bf92f3577b34da6), context.trace_id_high);
    try std.testing.expectEqual(@as(?u64, 0xa3ce929d0e0e4736), context.trace_id_low);
    try std.testing.expectEqual(@as(?u64, 0x00f067aa0ba902b7), context.span_id);
    try std.testing.expectError(error.InvalidTraceParent, fx.parseTraceParent("00-00000000000000000000000000000000-0000000000000000-01"));
}
