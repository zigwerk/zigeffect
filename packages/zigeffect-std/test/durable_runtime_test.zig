const std = @import("std");
const zstd = @import("zigeffect_std");

const fx = zstd.fx;
const kernel = fx.kernel;

const ProbeApi = struct {
    pub const operations: []const []const u8 = &.{"Probe.read"};
    value: u32,

    pub fn read(self: ProbeApi) u32 {
        return self.value;
    }
};

const Probe = kernel.Service("durable-runtime-test/Probe", ProbeApi);
const ProductId = zstd.Lineage.Key([]const u8, .{
    .name = "commerce.product.id",
    .privacy = .internal,
    .propagation = .distributed,
    .export_policy = .otel,
});
const ReadBase = kernel.Effect(u32, std.mem.Allocator.Error, .{Probe});
const Read = ReadBase.Stateful(void);

const ExistingBackend = struct {
    writes: usize = 0,
    fail: bool = false,

    fn record(raw: ?*anyopaque, _: fx.CausalEvent) anyerror!void {
        const self: *ExistingBackend = @ptrCast(@alignCast(raw.?));
        self.writes += 1;
        if (self.fail) return error.ExistingBackendFailure;
    }

    fn backend(self: *ExistingBackend) fx.CausalBackend {
        return .{ .kind = .memory, .state = self, .record = record };
    }
};

fn readProbe() Read {
    return Read.init({}, struct {
        fn run(_: void, ctx: *Read.Context) std.mem.Allocator.Error!u32 {
            const value = ctx.service(Probe).read();
            if (ctx.recordCausal(.{
                .kind = .activity_completed,
                .service_key = Probe.service_key,
                .label = "Probe.read",
                .status = "success",
                .domain_entity_ref = "probe/42",
                .redacted_detail = "value observed",
            }) == null) return error.OutOfMemory;
            return value;
        }
    }.run);
}

fn ConcurrentWriter(comptime Runtime: type) type {
    return struct {
        runtime: *Runtime,
        started: *std.atomic.Value(bool),
        release: *std.atomic.Value(bool),
        done: *std.atomic.Value(bool),
        failure: ?anyerror = null,

        fn run(self: *@This()) void {
            self.started.store(true, .release);
            while (!self.release.load(.acquire)) std.Thread.yield() catch {};
            for (0..128) |_| {
                _ = self.runtime.run(readProbe().named("probe.concurrent")) catch |err| {
                    self.failure = err;
                    break;
                };
            }
            self.done.store(true, .release);
        }
    };
}

test "application runtime owns one durable causal graph and agent map" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const layer = kernel.Layer.succeed(Probe, .{ .value = 42 });
    var runtime = try zstd.ManagedRuntime(@TypeOf(layer)).make(
        std.testing.allocator,
        std.testing.io,
        tmp.dir,
        layer,
        .{ .causal_context = .{ .project_id = 77 } },
    );
    defer runtime.deinit();

    const value = try runtime.run(readProbe().track(ProductId, "product-42").named("probe.program"));
    try std.testing.expectEqual(@as(u32, 42), value);
    _ = try runtime.causalRecorder().record(.{
        .kind = .external_signal_received,
        .service_key = "zigeffect-grpc",
        .label = "handler",
        .status = "succeeded",
        .redacted_detail = "service=Probe method=Read",
    });

    const health = runtime.causalHealth();
    try std.testing.expectEqual(zstd.CausalRuntime.HealthStatus.healthy, health.status);
    try std.testing.expectEqualStrings("nendb_embedded", health.backend);
    try std.testing.expectEqualStrings("0.2.2-beta", health.engine_version);
    try std.testing.expectEqualStrings("c990ef87d74e4dd7e77d3d8d1aafea2d57d12af7", health.engine_upstream_commit);
    try std.testing.expect(health.durable_records > 0);
    try std.testing.expect(health.durable_edges > 0);
    try std.testing.expectEqual(@as(u64, 0), health.backend_failures);

    const map_json = try runtime.agentMapJsonAlloc(std.testing.allocator, .{ .max_recent_events = 256 });
    defer std.testing.allocator.free(map_json);
    var map = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, map_json, .{});
    defer map.deinit();
    const map_object = map.value.object;
    try std.testing.expectEqualStrings(zstd.CausalRuntime.agent_map_schema, map_object.get("schema").?.string);
    try std.testing.expect(map_object.get("application") != null);
    try std.testing.expect(map_object.get("graph") != null);
    try std.testing.expect(map_object.get("causal_health") != null);
    try std.testing.expect(map_object.get("queries") != null);
    try std.testing.expect(std.mem.indexOf(u8, map_json, "graph_lineage") != null);
    try std.testing.expect(std.mem.indexOf(u8, map_json, "--budget 65536") != null);
    try std.testing.expect(std.mem.indexOf(u8, map_json, Probe.service_key) != null);
    try std.testing.expect(std.mem.indexOf(u8, map_json, "probe.program") != null);
    try std.testing.expect(std.mem.indexOf(u8, map_json, "probe/42") != null);

    const summary = runtime.graphSummary();
    try std.testing.expectEqualStrings("nendb_embedded", summary.engine);
    try std.testing.expectEqual(summary.records, summary.engine_nodes);
    try std.testing.expectEqual(summary.edges, summary.engine_edges);
    const newest = summary.newest_durable_event_id.?;
    const product = try runtime.lineageReference(ProductId, "product-42");
    const lineage_json = try runtime.graphLineageJsonAlloc(std.testing.allocator, product, 0, 128, 2048);
    defer std.testing.allocator.free(lineage_json);
    var lineage = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, lineage_json, .{});
    defer lineage.deinit();
    try std.testing.expect(lineage.value.object.get("matched").?.integer > 0);
    try std.testing.expect(std.mem.indexOf(u8, lineage_json, "product-42") == null);
    const record_json = try runtime.graphRecordJsonAlloc(std.testing.allocator, newest);
    defer std.testing.allocator.free(record_json);
    try std.testing.expect(std.mem.indexOf(u8, record_json, "source_event_id") != null);

    const delta_json = try runtime.graphSinceJsonAlloc(std.testing.allocator, newest - 1, 1);
    defer std.testing.allocator.free(delta_json);
    var delta = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, delta_json, .{});
    defer delta.deinit();
    try std.testing.expectEqualStrings(zstd.CausalGraph.records_since_schema, delta.value.object.get("schema").?.string);
    try std.testing.expectEqual(@as(usize, 1), delta.value.object.get("records").?.array.items.len);
    try std.testing.expectEqual(newest, @as(u64, @intCast(delta.value.object.get("next_event_id").?.integer)));
    try std.testing.expectError(error.InvalidGraphQueryLimit, runtime.graphSinceJsonAlloc(std.testing.allocator, newest, 0));
    try std.testing.expectError(error.InvalidGraphQueryLimit, runtime.graphSinceJsonAlloc(std.testing.allocator, newest, 4097));

    var found_parent = false;
    var durable_id: u64 = 1;
    while (durable_id <= newest) : (durable_id += 1) {
        const children_json = try runtime.graphChildrenJsonAlloc(std.testing.allocator, durable_id);
        defer std.testing.allocator.free(children_json);
        var children = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, children_json, .{});
        defer children.deinit();
        if (children.value.object.get("children").?.array.items.len > 0) {
            found_parent = true;
            break;
        }
    }
    try std.testing.expect(found_parent);

    const records_before_shutdown = summary.records;
    try runtime.shutdown();

    var durable = try zstd.CausalGraph.Snapshot.open(
        std.testing.allocator,
        std.testing.io,
        tmp.dir,
        .{},
    );
    defer durable.deinit();
    try std.testing.expect(durable.summary().records > records_before_shutdown);
    const durable_content = try durable.recordJsonAlloc(std.testing.allocator, durable.summary().newest_durable_event_id.?);
    defer std.testing.allocator.free(durable_content);
    try std.testing.expect(std.mem.indexOf(u8, durable_content, "ManagedRuntime.dispose") != null);
}

test "application runtime uses a caller causal store and restores its backend" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var existing = ExistingBackend{};
    var supplied = fx.CausalStore.initWithOptions(std.testing.allocator, .{
        .max_events = 4096,
        .max_event_string_bytes = 512,
    });
    defer supplied.deinit();
    supplied.attachBackend(existing.backend());
    existing.fail = true;
    _ = try supplied.record(.{ .kind = .external_signal_received, .label = "caller-before-runtime" });
    try std.testing.expectEqual(@as(u64, 1), supplied.backendFailureCount());
    existing.fail = false;

    const layer = kernel.Layer.succeed(Probe, .{ .value = 84 });
    var runtime = try zstd.ManagedRuntime(@TypeOf(layer)).make(
        std.testing.allocator,
        std.testing.io,
        tmp.dir,
        layer,
        .{ .causal_store = &supplied },
    );
    try std.testing.expectEqual(fx.CausalBackendKind.fanout, supplied.attachedBackendKind().?);
    try std.testing.expectEqual(@as(u32, 84), try runtime.run(readProbe().named("probe.supplied-store")));
    try std.testing.expectEqual(zstd.CausalRuntime.HealthStatus.healthy, runtime.causalHealth().status);

    var live = try supplied.snapshot(std.testing.allocator);
    defer live.deinit();
    var saw_probe = false;
    for (live.events) |event| {
        if (event.kind == .activity_completed and std.mem.eql(u8, event.label, "Probe.read")) saw_probe = true;
    }
    try std.testing.expect(saw_probe);
    try std.testing.expect(runtime.graphSummary().records > 0);

    try runtime.shutdown();
    try std.testing.expectEqual(fx.CausalBackendKind.memory, supplied.attachedBackendKind().?);
    const writes_before = existing.writes;
    _ = try supplied.record(.{ .kind = .external_signal_received, .label = "caller-after-runtime" });
    try std.testing.expectEqual(writes_before + 1, existing.writes);
}

test "agent map joins live topology to validated project intent" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const commands = [_]zstd.Project.Command{.{ .id = "test", .argv = &.{ "zig", "build", "test" } }};
    const requirements = [_]zstd.Project.Requirement{.{
        .id = "req-probe",
        .summary = "the probe is readable",
        .component = "runtime-map",
        .status = .active,
    }};
    const checks = [_]zstd.Project.AcceptanceCheck{.{
        .id = "check-probe",
        .requirement = "req-probe",
        .command = "test",
        .expectation = "the probe scenario passes",
    }};
    const scenarios = [_]zstd.Project.TestScenario{.{
        .id = "probe-scenario",
        .label = "read the probe through the runtime",
        .requirement = "req-probe",
        .acceptance_check = "check-probe",
        .component = "runtime-map",
        .command = "test",
        .source_roots = &.{ "src", "test" },
    }};
    const components = [_]zstd.Project.Component{.{
        .id = "runtime-map",
        .kind = .application,
        .path = ".",
        .capabilities = &.{ .agent, .causal_graph },
    }};
    const manifest = zstd.Project.Manifest{
        .name = "runtime-map",
        .kind = .application,
        .components = &components,
        .commands = &commands,
        .requirements = &requirements,
        .acceptance_checks = &checks,
        .test_scenarios = &scenarios,
    };
    const manifest_json = try manifest.jsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(manifest_json);
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "zigeffect.project.json", .data = manifest_json });

    const layer = kernel.Layer.succeed(Probe, .{ .value = 42 });
    var runtime = try zstd.ManagedRuntime(@TypeOf(layer)).make(
        std.testing.allocator,
        std.testing.io,
        tmp.dir,
        layer,
        .{},
    );
    defer runtime.deinit();
    _ = try runtime.run(readProbe());

    const map_json = try runtime.agentMapJsonAlloc(std.testing.allocator, .{ .max_recent_events = 64 });
    defer std.testing.allocator.free(map_json);
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, map_json, .{});
    defer parsed.deinit();
    try std.testing.expectEqual(@as(i64, zstd.CausalRuntime.agent_map_schema_version), parsed.value.object.get("schema_version").?.integer);
    const development = parsed.value.object.get("development").?.object;
    try std.testing.expectEqualStrings("runtime-map", development.get("manifest").?.object.get("name").?.string);
    const observed = development.get("observed").?.object;
    try std.testing.expectEqual(@as(i64, 1), observed.get("requirements_open").?.integer);
    try std.testing.expectEqual(@as(i64, 1), observed.get("checks_pending").?.integer);
    try std.testing.expect(std.mem.indexOf(u8, map_json, "req-probe") != null);
    try std.testing.expect(std.mem.indexOf(u8, map_json, "probe-scenario") != null);
    try std.testing.expect(std.mem.indexOf(u8, map_json, "zigeffect test run --scenario <id> --json") != null);
    try std.testing.expect(std.mem.indexOf(u8, map_json, "zigeffect agent context --task") != null);
    try std.testing.expect(std.mem.indexOf(u8, map_json, "zigeffect graph path <from> <to>") != null);
    const causal_context = parsed.value.object.get("causal_context").?.object;
    try std.testing.expect(causal_context.get("graph_session_id") != null);
    try std.testing.expect(causal_context.get("project_id") != null);
}

test "TestContext can observe one canonical durable runtime execution" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const scenario = zstd.Testing.Scenario{
        .id = "runtime-context",
        .label = "one runtime feeds testing and NenDB",
        .requirement = "req-runtime",
        .acceptance_check = "check-runtime",
        .component = "std-runtime",
        .command = "test",
    };
    var context = try zstd.Testing.TestContext.init(std.testing.allocator, .{
        .project = "std-runtime",
        .suite = "durable-runtime",
        .scenario = scenario,
        .seed = 42,
    });
    defer context.deinit();

    const layer = kernel.Layer.succeed(Probe, .{ .value = 21 });
    var runtime = try zstd.ManagedRuntime(@TypeOf(layer)).make(
        std.testing.allocator,
        std.testing.io,
        tmp.dir,
        layer,
        .{ .causal_store = context.causalStore(), .causal_context = context.causalContext() },
    );
    try std.testing.expectEqual(@as(u32, 21), try runtime.run(readProbe().named("probe.test-context")));
    const assertions = zstd.Testing.AssertionRecorder.init(&context);
    _ = try assertions.event(.{
        .id = "probe-causal",
        .label = "probe execution is causally addressable",
        .repair_hint = "run the application with the TestContext causal store",
    }, .{ .kind = .activity_completed, .label = "Probe.read", .status = "success" });
    try context.mapCausalEventIds(&runtime);
    try runtime.shutdown();

    const receipt = try context.finish(1);
    try std.testing.expectEqual(zstd.Testing.TestStatus.passed, receipt.status);
    try std.testing.expect(receipt.causal.events > 0);
    try std.testing.expectEqual(@as(usize, 1), receipt.assertions[0].causal_event_ids.len);
    try std.testing.expectEqual(zstd.Testing.CausalEventIdSpace.graph_durable, receipt.causal_event_id_space);
    try std.testing.expect(receipt.causal_graph_session_id != null);
    var graph = try zstd.CausalGraph.Snapshot.open(std.testing.allocator, std.testing.io, tmp.dir, .{});
    defer graph.deinit();
    try std.testing.expect(graph.summary().records > 0);
    const durable_event = try graph.recordJsonAlloc(std.testing.allocator, receipt.assertions[0].causal_event_ids[0]);
    defer std.testing.allocator.free(durable_event);
    try std.testing.expect(std.mem.indexOf(u8, durable_event, "Probe.read") != null);
}

test "TestContext rejects causal ID mapping from a detached runtime" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var context = try zstd.Testing.TestContext.init(std.testing.allocator, .{
        .project = "std-runtime",
        .suite = "durable-runtime",
        .scenario = .{
            .id = "detached-runtime",
            .label = "detached runtime IDs cannot become graph evidence",
            .requirement = "req-runtime",
            .acceptance_check = "check-runtime",
            .component = "std-runtime",
            .command = "test",
        },
    });
    defer context.deinit();
    const layer = kernel.Layer.succeed(Probe, .{ .value = 1 });
    var runtime = try zstd.ManagedRuntime(@TypeOf(layer)).make(std.testing.allocator, std.testing.io, tmp.dir, layer, .{});
    defer runtime.deinit();
    try std.testing.expectError(error.CausalStoreMismatch, context.mapCausalEventIds(&runtime));
}

test "durable graph failure degrades health and fails checked shutdown" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const layer = kernel.Layer.succeed(Probe, .{ .value = 7 });
    var runtime = try zstd.ManagedRuntime(@TypeOf(layer)).make(
        std.testing.allocator,
        std.testing.io,
        tmp.dir,
        layer,
        .{ .graph = .{ .max_records = 1 } },
    );
    defer runtime.deinit();

    try std.testing.expectEqual(zstd.CausalRuntime.HealthStatus.degraded, runtime.causalHealth().status);
    try std.testing.expect(runtime.causalHealth().backend_failures > 0);
    try std.testing.expectError(error.CausalNendbStorageBackendFull, runtime.shutdown());
}

test "agent graph remains queryable while effects are recording" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const layer = kernel.Layer.succeed(Probe, .{ .value = 99 });
    var runtime = try zstd.ManagedRuntime(@TypeOf(layer)).make(
        std.testing.allocator,
        std.testing.io,
        tmp.dir,
        layer,
        .{},
    );
    defer runtime.deinit();

    var started = std.atomic.Value(bool).init(false);
    var release = std.atomic.Value(bool).init(false);
    var done = std.atomic.Value(bool).init(false);
    const Writer = ConcurrentWriter(@TypeOf(runtime));
    var writer = Writer{
        .runtime = &runtime,
        .started = &started,
        .release = &release,
        .done = &done,
    };
    const thread = try std.Thread.spawn(.{}, Writer.run, .{&writer});
    while (!started.load(.acquire)) std.Thread.yield() catch {};
    _ = runtime.graphSummary();
    release.store(true, .release);
    var observations: usize = 0;
    while (!done.load(.acquire)) {
        const summary = runtime.graphSummary();
        try std.testing.expectEqual(summary.records, summary.engine_nodes);
        observations += 1;
        std.Thread.yield() catch {};
    }
    thread.join();
    if (writer.failure) |failure| return failure;
    try std.testing.expect(observations > 0);
    try std.testing.expect(runtime.graphSummary().records > 128);
}
