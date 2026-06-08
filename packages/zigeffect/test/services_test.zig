const std = @import("std");
const fx = @import("zigeffect");
const fixtures = @import("support/fixtures.zig");

test "context resolves services and test environment captures state" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var ctx = env.context();
    const fs = ctx.service(fx.MemoryFileSystem);
    const config = ctx.service(fx.Config);
    const metrics = ctx.service(fx.Metrics);
    const tracing = ctx.service(fx.Tracing);
    const clock = ctx.service(fx.FakeClock);
    const clock_service = ctx.service(fx.Clock);

    try config.set("mode", "test");
    try fs.writeFile("schema.rg", "database yachdee {}");
    try metrics.increment("compile.count", 1);
    try tracing.event("compile.start");
    clock.sleep(25);
    clock_service.sleep(5);

    try std.testing.expectEqualStrings("test", config.get("mode").?);
    try std.testing.expectEqualStrings("database yachdee {}", fs.readFile("schema.rg").?);
    try std.testing.expectEqual(@as(i64, 1), metrics.get("compile.count"));
    try std.testing.expectEqualStrings("compile.start", env.services.tracing.events.items[0]);
    try std.testing.expectEqual(@as(u64, 30), clock.nowMs());
    try std.testing.expectEqual(@as(u64, 30), clock_service.nowMs());
    try env.expectFile("schema.rg", "database yachdee {}");
    try env.expectTrace("compile.start");
    try env.expectMetric("compile.count", 1);
}
test "logger config metrics tracing and memory fs support bootstrap helpers" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var ctx = env.context();
    const logger = ctx.service(fx.Logger);
    const config = ctx.service(fx.Config);
    const metrics = ctx.service(fx.Metrics);
    const tracing = ctx.service(fx.Tracing);
    const fs = ctx.service(fx.MemoryFileSystem);

    try logger.warn("warned");
    try logger.err("errored");
    try config.set("stage", "dev");
    try config.set("stage", "test");
    try metrics.gauge("queue.depth", 12);
    try tracing.spanStart("compile");
    try tracing.spanEnd("compile");
    try fs.writeFile("schema.rg", "old");
    try fs.writeFile("schema.rg", "new");

    try env.expectLog("warned");
    try env.expectLog("errored");
    try std.testing.expectEqualStrings("test", config.require("stage") catch unreachable);
    try env.expectMetric("queue.depth", 12);
    try env.expectTrace("span:start:compile");
    try env.expectTrace("span:end:compile");
    try env.expectFile("schema.rg", "new");
    try std.testing.expect(fs.exists("schema.rg"));
    fs.deleteFile("schema.rg");
    try std.testing.expect(!fs.exists("schema.rg"));
}
test "test env stores fixture and golden output" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    try env.putFixture("report", "first");
    try env.expectGolden("report", "first");

    try env.putFixture("report", "updated");
    try env.expectGolden("report", "updated");
    try std.testing.expectEqualStrings("updated", env.fixtures.get("report").?);
    try std.testing.expectError(error.ExpectedFixtureNotFound, env.expectGolden("missing", "value"));
}
test "config descriptors read typed values and defaults" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    const config = &env.services.config;
    try config.set("app.name", "yachdee");
    try config.set("http.port", "8080");
    try config.set("feature.enabled", "true");

    try std.testing.expectEqualStrings("yachdee", try config.read(fx.Config.string("app.name")));
    try std.testing.expectEqual(@as(i64, 8080), try config.read(fx.Config.int("http.port")));
    try std.testing.expectEqual(true, try config.read(fx.Config.boolean("feature.enabled")));

    try std.testing.expectEqualStrings("local", try config.read(fx.Config.string("region").withDefault("local")));
    try std.testing.expectEqual(@as(i64, 30), try config.read(fx.Config.int("timeout.seconds").withDefault(30)));
    try std.testing.expectEqual(false, try config.read(fx.Config.boolean("debug").withDefault(false)));
}
test "config schema loads typed structs from descriptors" {
    var config = fx.Config.init(std.testing.allocator);
    defer config.deinit();

    const entries = [_]fx.ConfigEntry{
        .{ .key = "app.name", .value = "yachdee" },
        .{ .key = "http.port", .value = "8080" },
        .{ .key = "feature.enabled", .value = "true" },
    };
    try config.loadEntries(&entries);

    const AppConfig = struct {
        name: []const u8,
        port: i64,
        enabled: bool,
        region: []const u8,
    };
    const schema = fx.Config.schema(AppConfig, .{
        .name = fx.Config.string("app.name"),
        .port = fx.Config.int("http.port"),
        .enabled = fx.Config.boolean("feature.enabled"),
        .region = fx.Config.string("region").withDefault("local"),
    });

    const app = try config.readSchema(schema);

    try std.testing.expectEqualStrings("yachdee", app.name);
    try std.testing.expectEqual(@as(i64, 8080), app.port);
    try std.testing.expectEqual(true, app.enabled);
    try std.testing.expectEqualStrings("local", app.region);
}
test "config providers load entries and dotenv text" {
    var config = fx.Config.init(std.testing.allocator);
    defer config.deinit();

    const entries = [_]fx.ConfigEntry{
        .{ .key = "app.name", .value = "entries" },
        .{ .key = "http.port", .value = "8080" },
        .{ .key = "app.name", .value = "override" },
    };
    try config.loadEntries(&entries);

    try std.testing.expectEqualStrings("override", try config.read(fx.Config.string("app.name")));
    try std.testing.expectEqual(@as(i64, 8080), try config.read(fx.Config.int("http.port")));

    try config.loadDotEnv(
        \\# file-style provider
        \\feature.enabled = true
        \\http.port = 9090
        \\
    );

    try std.testing.expectEqual(true, try config.read(fx.Config.boolean("feature.enabled")));
    try std.testing.expectEqual(@as(i64, 9090), try config.read(fx.Config.int("http.port")));
    try std.testing.expectError(error.InvalidConfigValue, config.loadDotEnv("not-a-pair"));
}
test "config diagnostics are typed and secret safe" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    const config = &env.services.config;
    try config.set("database.password", "not-an-int-secret");

    const descriptor = fx.Config.int("database.password").secret();
    try std.testing.expectError(error.InvalidConfigValue, config.read(descriptor));

    const formatted = try fx.services.config.formatConfigError(
        std.testing.allocator,
        descriptor,
        error.InvalidConfigValue,
    );
    defer std.testing.allocator.free(formatted);

    try std.testing.expect(std.mem.indexOf(u8, formatted, "database.password") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "redacted") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "not-an-int-secret") == null);
}
test "observability services expose structured logs metrics and spans" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    const logger = &env.services.logger;
    try logger.logFields(.info, "request handled", &.{
        .{ .key = "route", .value = "/health" },
        .{ .key = "status", .value = "200" },
    });

    try std.testing.expectEqual(fx.services.logger.LogLevel.info, logger.structured_entries.items[0].level);
    try std.testing.expectEqualStrings("request handled", logger.structured_entries.items[0].message);
    try std.testing.expectEqualStrings("route", logger.structured_entries.items[0].fields[0].key);
    try std.testing.expectEqualStrings("/health", logger.structured_entries.items[0].fields[0].value);
    try env.expectLog("request handled");
    try env.expectStructuredLog(.info, "request handled");

    const metrics = &env.services.metrics;
    try metrics.increment("requests.total", 1);
    try metrics.observe("request.ms", 10);
    try metrics.observe("request.ms", 25);

    const histogram = metrics.histogram("request.ms").?;
    try std.testing.expectEqual(@as(usize, 2), histogram.count);
    try std.testing.expectEqual(@as(i64, 35), histogram.sum);
    try std.testing.expectEqual(@as(i64, 10), histogram.min);
    try std.testing.expectEqual(@as(i64, 25), histogram.max);
    try env.expectHistogram("request.ms", 2, 35, 10, 25);

    var snapshot = try metrics.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 1), snapshot.counters.len);
    try std.testing.expectEqual(@as(usize, 1), snapshot.histograms.len);

    const tracing = &env.services.tracing;
    const root = try tracing.startSpan("compile", null);
    const child = try tracing.startSpan("parse", root);
    try tracing.endSpan(child);

    try std.testing.expectEqual(@as(fx.services.tracing.SpanId, 1), root);
    try std.testing.expectEqual(root, tracing.spans.items[1].parent_id.?);
    try std.testing.expect(tracing.spans.items[1].ended);
    try env.expectTrace("span:start:compile");
}
test "observability report formats logs metrics and traces" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    const tracing = &env.services.tracing;
    const root = try tracing.startSpanWithAttributes("request", null, &.{
        .{ .key = "route", .value = "/health" },
    });
    const child = try tracing.startSpan("database", root);
    try tracing.endSpan(child);

    const logger = &env.services.logger;
    try logger.logWithContext(
        .info,
        "request handled",
        &.{.{ .key = "status", .value = "200" }},
        .{ .timestamp_ms = 1234, .trace_id = tracing.spanTrace(root).?, .span_id = child },
    );

    const metrics = &env.services.metrics;
    try metrics.increment("requests.total", 1);
    try metrics.observe("request.ms", 25);

    const report = try fx.formatObservabilityReport(
        std.testing.allocator,
        "health check",
        logger,
        metrics,
        tracing,
    );
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect observability report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "program: health check") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "logs: 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "log: info request handled") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "counter: requests.total=1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "histogram: request.ms count=1 sum=25 min=25 max=25") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "span: id=1 trace=1 parent=null ended=false name=request") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "span: id=2 trace=1 parent=1 ended=true name=database") != null);
}
test "observability metadata preserves trace context" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    const tracing = &env.services.tracing;
    const root = try tracing.startSpanWithAttributes("request", null, &.{
        .{ .key = "route", .value = "/health" },
    });
    const child = try tracing.startSpan("database", root);

    try std.testing.expectEqual(@as(fx.services.tracing.TraceId, 1), tracing.spans.items[0].trace_id);
    try std.testing.expectEqual(tracing.spans.items[0].trace_id, tracing.spans.items[1].trace_id);
    try std.testing.expectEqualStrings("route", tracing.spans.items[0].attributes[0].key);
    try std.testing.expectEqualStrings("/health", tracing.spans.items[0].attributes[0].value);

    const logger = &env.services.logger;
    try logger.logWithContext(
        .info,
        "request handled",
        &.{.{ .key = "status", .value = "200" }},
        .{
            .timestamp_ms = 1234,
            .trace_id = tracing.spans.items[0].trace_id,
            .span_id = child,
        },
    );

    const entry = logger.structured_entries.items[0];
    try std.testing.expectEqual(@as(?u64, 1234), entry.timestamp_ms);
    try std.testing.expectEqual(@as(?fx.services.tracing.TraceId, tracing.spans.items[0].trace_id), entry.trace_id);
    try std.testing.expectEqual(@as(?fx.services.tracing.SpanId, child), entry.span_id);
    try std.testing.expectEqualStrings("status", entry.fields[0].key);
    try std.testing.expectEqualStrings("200", entry.fields[0].value);
}
test "tracing span lifecycle assertions inspect ended parent and trace state" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    const tracing = &env.services.tracing;
    const root = try tracing.startSpan("request", null);
    const child = try tracing.startSpan("database", root);
    try tracing.endSpan(child);

    try env.expectSpanEnded(child);
    try env.expectSpanParent(child, root);
    try env.expectSpanTrace(child, tracing.spanTrace(root).?);
}

test "causal store records events snapshots and lineage deterministically" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    const run_id = store.nextRunId();
    const parent = try store.record(.{
        .kind = .run_started,
        .run_id = run_id,
        .label = "readiness",
        .type_name = "ReadinessEffect",
    });
    const child = try store.record(.{
        .kind = .exit_recorded,
        .run_id = run_id,
        .parent_id = parent,
        .status = "success",
    });

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    try std.testing.expectEqual(@as(usize, 2), snapshot.events.len);
    try std.testing.expectEqual(parent, snapshot.events[0].id);
    try std.testing.expectEqual(child, snapshot.events[1].id);
    try std.testing.expectEqual(run_id, snapshot.events[0].run_id.?);
    try std.testing.expectEqual(fx.CausalEventKind.run_started, snapshot.events[0].kind);
    try std.testing.expectEqualStrings("readiness", snapshot.events[0].label);

    var lineage = try store.lineage(std.testing.allocator, parent);
    defer lineage.deinit();

    try std.testing.expectEqual(@as(usize, 2), lineage.events.len);
    try std.testing.expectEqual(parent, lineage.events[0].id);
    try std.testing.expectEqual(child, lineage.events[1].id);
}

test "bounded causal store keeps newest events and reports dropped count" {
    var store = fx.CausalStore.initBounded(std.testing.allocator, 2);
    defer store.deinit();

    const first = try store.record(.{ .kind = .run_started, .label = "first" });
    const second = try store.record(.{ .kind = .effect_started, .parent_id = first, .label = "second" });
    const third = try store.record(.{ .kind = .exit_recorded, .parent_id = second, .label = "third" });

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    try std.testing.expectEqual(@as(usize, 2), snapshot.events.len);
    try std.testing.expectEqual(second, snapshot.events[0].id);
    try std.testing.expectEqual(third, snapshot.events[1].id);
    try std.testing.expectEqual(@as(u64, 1), store.droppedEventCount());
    try std.testing.expectEqual(@as(?u64, second), store.oldestRetainedEventId());
}

test "causal report and backend kinds preserve adapter strategy" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    const run_id = store.nextRunId();
    _ = try store.record(.{
        .kind = .run_started,
        .run_id = run_id,
        .label = "adapter-check",
        .type_name = "AdapterEffect",
    });

    const report = try fx.formatCausalReport(std.testing.allocator, "adapter check", &store);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "program: adapter check") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "kind=run_started") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "type=AdapterEffect") != null);

    try std.testing.expectEqual(fx.CausalBackendKind.memory, fx.CausalBackendKind.memory);
    try std.testing.expectEqual(fx.CausalBackendKind.json_lines, fx.CausalBackendKind.json_lines);
    try std.testing.expectEqual(fx.CausalBackendKind.dot, fx.CausalBackendKind.dot);
    try std.testing.expectEqual(fx.CausalBackendKind.opentelemetry, fx.CausalBackendKind.opentelemetry);
    try std.testing.expectEqual(fx.CausalBackendKind.nendb_graph, fx.CausalBackendKind.nendb_graph);
    try std.testing.expectEqual(fx.CausalBackendKind.async_stream, fx.CausalBackendKind.async_stream);
    try std.testing.expectEqual(@as(usize, 6), std.meta.fields(fx.CausalBackendKind).len);
}

const FakeCausalBackendState = struct {
    ids: [8]u64 = undefined,
    kinds: [8]fx.CausalEventKind = undefined,
    labels: [8][]const u8 = undefined,
    count: usize = 0,
};

fn recordFakeCausalBackend(raw: ?*anyopaque, event: fx.CausalEvent) anyerror!void {
    const state: *FakeCausalBackendState = @ptrCast(@alignCast(raw.?));
    if (state.count >= state.ids.len) return error.TooManyEvents;
    state.ids[state.count] = event.id;
    state.kinds[state.count] = event.kind;
    state.labels[state.count] = event.label;
    state.count += 1;
}

fn fakeCausalBackend(state: *FakeCausalBackendState) fx.CausalBackend {
    return .{
        .kind = .memory,
        .state = state,
        .record = recordFakeCausalBackend,
    };
}

test "causal store forwards stored events to attached backend" {
    var backend_state = FakeCausalBackendState{};
    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(fakeCausalBackend(&backend_state));
    defer store.deinit();

    const first = try store.record(.{
        .kind = .run_started,
        .label = "backend-run",
    });
    const second = try store.record(.{
        .kind = .exit_recorded,
        .parent_id = first,
        .label = "backend-run",
        .status = "success",
    });

    try std.testing.expectEqual(@as(usize, 2), backend_state.count);
    try std.testing.expectEqual(first, backend_state.ids[0]);
    try std.testing.expectEqual(second, backend_state.ids[1]);
    try std.testing.expectEqual(fx.CausalEventKind.run_started, backend_state.kinds[0]);
    try std.testing.expectEqual(fx.CausalEventKind.exit_recorded, backend_state.kinds[1]);
    try std.testing.expectEqualStrings("backend-run", backend_state.labels[0]);
    try std.testing.expectEqualStrings("backend-run", backend_state.labels[1]);
    try std.testing.expectEqual(@as(usize, 2), store.events.items.len);
}

test "bounded causal store can retain zero events while forwarding backend events" {
    var backend_state = FakeCausalBackendState{};
    var store = fx.CausalStore.initBounded(std.testing.allocator, 0);
    store.attachBackend(fakeCausalBackend(&backend_state));
    defer store.deinit();

    const first = try store.record(.{ .kind = .run_started, .label = "backend-only" });
    const second = try store.record(.{ .kind = .exit_recorded, .parent_id = first, .label = "backend-only" });

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    try std.testing.expectEqual(@as(usize, 0), snapshot.events.len);
    try std.testing.expectEqual(@as(u64, 2), store.droppedEventCount());
    try std.testing.expectEqual(@as(?u64, null), store.oldestRetainedEventId());
    try std.testing.expectEqual(@as(usize, 2), backend_state.count);
    try std.testing.expectEqual(first, backend_state.ids[0]);
    try std.testing.expectEqual(second, backend_state.ids[1]);
}

test "causal sampling keeps every nth observability event and preserves structural events" {
    var backend_state = FakeCausalBackendState{};
    var store = fx.CausalStore.initWithOptions(std.testing.allocator, .{
        .sampling = .{ .log_every_n = 2, .metric_every_n = 3 },
    });
    store.attachBackend(fakeCausalBackend(&backend_state));
    defer store.deinit();

    const run_id = store.nextRunId();
    const run = try store.record(.{ .kind = .run_started, .run_id = run_id, .label = "sampled-run" });
    const log1 = try store.record(.{ .kind = .log_recorded, .run_id = run_id, .label = "log-1" });
    const log2 = try store.record(.{ .kind = .log_recorded, .run_id = run_id, .label = "log-2" });
    const metric1 = try store.record(.{ .kind = .metric_recorded, .run_id = run_id, .label = "metric-1" });
    const metric2 = try store.record(.{ .kind = .metric_recorded, .run_id = run_id, .label = "metric-2" });
    const metric3 = try store.record(.{ .kind = .metric_recorded, .run_id = run_id, .label = "metric-3" });
    const exit = try store.record(.{ .kind = .exit_recorded, .run_id = run_id, .parent_id = run, .label = "sampled-exit" });

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    try std.testing.expectEqual(@as(u64, 1), run);
    try std.testing.expectEqual(@as(u64, 2), log1);
    try std.testing.expectEqual(@as(u64, 3), log2);
    try std.testing.expectEqual(@as(u64, 4), metric1);
    try std.testing.expectEqual(@as(u64, 5), metric2);
    try std.testing.expectEqual(@as(u64, 6), metric3);
    try std.testing.expectEqual(@as(u64, 7), exit);
    try std.testing.expectEqual(@as(usize, 4), snapshot.events.len);
    try std.testing.expectEqual(run, snapshot.events[0].id);
    try std.testing.expectEqual(log2, snapshot.events[1].id);
    try std.testing.expectEqual(metric3, snapshot.events[2].id);
    try std.testing.expectEqual(exit, snapshot.events[3].id);
    try std.testing.expectEqual(@as(u64, 3), store.sampledEventCount());

    try std.testing.expectEqual(@as(usize, 4), backend_state.count);
    try std.testing.expectEqual(run, backend_state.ids[0]);
    try std.testing.expectEqual(log2, backend_state.ids[1]);
    try std.testing.expectEqual(metric3, backend_state.ids[2]);
    try std.testing.expectEqual(exit, backend_state.ids[3]);
    try std.testing.expectEqualStrings("sampled-run", backend_state.labels[0]);
    try std.testing.expectEqualStrings("log-2", backend_state.labels[1]);
    try std.testing.expectEqualStrings("metric-3", backend_state.labels[2]);
    try std.testing.expectEqualStrings("sampled-exit", backend_state.labels[3]);
}

test "causal event taxonomy classifies structural finding and sampleable roles" {
    try std.testing.expect(fx.isCausalStructuralEvent(.run_started));
    try std.testing.expect(fx.isCausalStructuralEvent(.resource_acquired));
    try std.testing.expect(fx.isCausalFindingEvidenceEvent(.resource_acquired));
    try std.testing.expect(fx.isCausalFindingEvidenceEvent(.fiber_forked));
    try std.testing.expect(fx.isCausalFindingEvidenceEvent(.assertion_recorded));
    try std.testing.expect(fx.isCausalSampleableEvent(.log_recorded));
    try std.testing.expect(fx.isCausalSampleableEvent(.metric_recorded));
    try std.testing.expect(fx.isCausalSampleableEvent(.span_recorded));
    try std.testing.expect(!fx.isCausalStructuralEvent(.log_recorded));
    try std.testing.expect(!fx.isCausalFindingEvidenceEvent(.log_recorded));
    try std.testing.expect(!fx.isCausalSampleableEvent(.assertion_recorded));
}

test "causal event taxonomy keeps sampleable events disjoint from finding evidence" {
    inline for (std.meta.fields(fx.CausalEventKind)) |field| {
        const kind: fx.CausalEventKind = @field(fx.CausalEventKind, field.name);
        if (fx.isCausalSampleableEvent(kind)) {
            try std.testing.expect(!fx.isCausalFindingEvidenceEvent(kind));
        }
        if (fx.isCausalFindingEvidenceEvent(kind)) {
            try std.testing.expect(!fx.isCausalSampleableEvent(kind));
        }
    }
}

fn expectFinding(findings: fx.CausalFindings, kind: fx.CausalFindingKind) !void {
    for (findings.items) |finding| {
        if (finding.kind == kind) return;
    }
    return error.ExpectedFindingMissing;
}

test "causal query helpers filter resources fibers requirements and retries" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    const run_id = store.nextRunId();
    const scope_id = store.nextScopeId();
    const parent = try store.record(.{
        .kind = .run_started,
        .run_id = run_id,
        .label = "query-run",
    });
    const child = try store.record(.{
        .kind = .exit_recorded,
        .run_id = run_id,
        .parent_id = parent,
        .status = "failure",
        .type_name = "Boom",
    });
    _ = try store.record(.{
        .kind = .resource_acquired,
        .run_id = run_id,
        .scope_id = scope_id,
        .type_name = "DatabaseConnection",
    });
    _ = try store.record(.{
        .kind = .fiber_forked,
        .run_id = run_id,
        .fiber_id = 44,
        .status = "pending",
    });
    _ = try store.record(.{
        .kind = .service_required,
        .run_id = run_id,
        .type_name = @typeName(fx.Config),
        .status = "missing",
    });
    _ = try store.record(.{
        .kind = .schedule_decision,
        .run_id = run_id,
        .label = "retry-config",
        .status = "exhausted",
        .redacted_detail = "attempt=2 delay_ms=null decision=exhausted",
    });

    var cause = try store.cause(std.testing.allocator, child);
    defer cause.deinit();
    try std.testing.expectEqual(@as(usize, 2), cause.events.len);
    try std.testing.expectEqual(parent, cause.events[0].id);
    try std.testing.expectEqual(child, cause.events[1].id);

    var resources = try store.resources(std.testing.allocator, scope_id);
    defer resources.deinit();
    try std.testing.expectEqual(@as(usize, 1), resources.events.len);
    try std.testing.expectEqual(fx.CausalEventKind.resource_acquired, resources.events[0].kind);

    var fibers = try store.fibers(std.testing.allocator, "pending");
    defer fibers.deinit();
    try std.testing.expectEqual(@as(usize, 1), fibers.events.len);
    try std.testing.expectEqual(@as(?u64, 44), fibers.events[0].fiber_id);

    var requirements = try store.requirements(std.testing.allocator, run_id);
    defer requirements.deinit();
    try std.testing.expectEqual(@as(usize, 1), requirements.events.len);
    try std.testing.expectEqualStrings(@typeName(fx.Config), requirements.events[0].type_name);

    var retries = try store.retries(std.testing.allocator, run_id);
    defer retries.deinit();
    try std.testing.expectEqual(@as(usize, 1), retries.events.len);
    try std.testing.expectEqualStrings("retry-config", retries.events[0].label);
}

test "causal findings surface missing cleanup pending fibers finalizer failures exhausted retries and missing services" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    const run_id = store.nextRunId();
    const leaked_scope_id = store.nextScopeId();
    const closed_scope_id = store.nextScopeId();

    _ = try store.record(.{
        .kind = .resource_acquired,
        .run_id = run_id,
        .scope_id = leaked_scope_id,
        .type_name = "LeakedResource",
    });
    _ = try store.record(.{
        .kind = .fiber_forked,
        .run_id = run_id,
        .scope_id = closed_scope_id,
        .fiber_id = 7,
        .status = "pending",
    });
    _ = try store.record(.{
        .kind = .scope_closed,
        .run_id = run_id,
        .scope_id = closed_scope_id,
        .status = "success",
    });
    _ = try store.record(.{
        .kind = .resource_finalized,
        .run_id = run_id,
        .scope_id = closed_scope_id,
        .type_name = "FailingResource",
        .status = "failure",
        .redacted_detail = "CloseFailed",
    });
    _ = try store.record(.{
        .kind = .schedule_decision,
        .run_id = run_id,
        .label = "retry-db",
        .status = "exhausted",
        .redacted_detail = "attempt=3 delay_ms=null decision=exhausted",
    });
    _ = try store.record(.{
        .kind = .service_required,
        .run_id = run_id,
        .type_name = @typeName(fx.Config),
        .status = "missing",
    });

    var findings = try store.findings(std.testing.allocator);
    defer findings.deinit();

    try expectFinding(findings, .resource_acquired_without_finalization);
    try expectFinding(findings, .fiber_pending_after_scope_close);
    try expectFinding(findings, .finalizer_failure);
    try expectFinding(findings, .retry_budget_exhausted);
    try expectFinding(findings, .service_requirement_without_provider);
}

test "causal findings surface failed assertions as agent-readable evidence" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    const run_id = store.nextRunId();
    _ = try store.record(.{
        .kind = .assertion_recorded,
        .run_id = run_id,
        .label = "missing-service-compile-fail",
        .type_name = "CommandExit",
        .status = "failure",
        .redacted_detail = "command exited with code 1",
    });

    var findings = try store.findings(std.testing.allocator);
    defer findings.deinit();

    try expectFinding(findings, .assertion_failure);
}

test "causal json and dot exports are deterministic and redacted" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    const run_id = store.nextRunId();
    const parent = try store.record(.{
        .kind = .run_started,
        .run_id = run_id,
        .label = "readiness",
        .type_name = "ReadinessEffect",
    });
    _ = try store.record(.{
        .kind = .exit_recorded,
        .run_id = run_id,
        .parent_id = parent,
        .status = "failure",
        .type_name = "InvalidConfig",
        .redacted_detail = "database.password=<redacted>",
    });

    const json = try fx.formatCausalJson(std.testing.allocator, &store);
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema\": \"zigeffect.causal.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema_version\": 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"event_taxonomy_version\": 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"events\": [") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"id\": 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"kind\": \"run_started\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"parent_id\": null") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"redacted_detail\": \"database.password=<redacted>\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "super-secret") == null);

    const dot = try fx.formatCausalDot(std.testing.allocator, &store);
    defer std.testing.allocator.free(dot);

    try std.testing.expect(std.mem.indexOf(u8, dot, "digraph zigeffect_causal") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "graph [rankdir=\"LR\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "event_1 [label=\"event 1\\nrun_started\\nreadiness\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "event_1 -> event_2 [label=\"parent\"]") != null);
}

test "causal artifacts disclose bounded retention state" {
    var store = fx.CausalStore.initBounded(std.testing.allocator, 1);
    defer store.deinit();

    _ = try store.record(.{ .kind = .run_started, .label = "dropped" });
    const retained = try store.record(.{ .kind = .exit_recorded, .label = "retained" });

    const json = try fx.formatCausalJson(std.testing.allocator, &store);
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"retention\": {") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"max_events\": 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"dropped_events\": 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"oldest_retained_event_id\": 2") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"id\": 1") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"id\": 2") != null);

    const report = try fx.formatCausalCiReport(std.testing.allocator, "bounded", &store);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "retention: max_events=1 dropped_events=1 oldest_retained_event=2") != null);
    try std.testing.expectEqual(retained, store.oldestRetainedEventId().?);
}

test "causal artifacts disclose sampling policy and sampled event count" {
    var store = fx.CausalStore.initWithOptions(std.testing.allocator, .{
        .sampling = .{ .span_every_n = 2 },
    });
    defer store.deinit();

    const first = try store.record(.{ .kind = .span_recorded, .label = "span-1" });
    const second = try store.record(.{ .kind = .span_recorded, .label = "span-2" });

    try std.testing.expectEqual(@as(u64, 1), first);
    try std.testing.expectEqual(@as(u64, 2), second);
    try std.testing.expectEqual(@as(u64, 1), store.sampledEventCount());

    const json = try fx.formatCausalJson(std.testing.allocator, &store);
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"sampling\": {") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"log_every_n\": null") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"metric_every_n\": null") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"span_every_n\": 2") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"sampled_events\": 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "span-1") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "span-2") != null);

    const report = try fx.formatCausalCiReport(std.testing.allocator, "sampled", &store);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "sampling: log_every_n=off metric_every_n=off span_every_n=2 sampled_events=1") != null);
}

test "causal artifacts disclose truncation policy when string limits are disabled" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    _ = try store.record(.{
        .kind = .run_started,
        .label = "unbounded-label",
        .type_name = "UnboundedEffect",
        .status = "success",
        .redacted_detail = "detail remains complete",
    });

    try std.testing.expectEqual(@as(u64, 0), store.truncatedFieldCount());

    const json = try fx.formatCausalJson(std.testing.allocator, &store);
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"truncation\": {") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"max_event_string_bytes\": null") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"truncated_fields\": 0") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "detail remains complete") != null);

    const report = try fx.formatCausalReport(std.testing.allocator, "default truncation", &store);
    defer std.testing.allocator.free(report);
    try std.testing.expect(std.mem.indexOf(u8, report, "truncation: max_event_string_bytes=off truncated_fields=0") != null);

    const ci_report = try fx.formatCausalCiReport(std.testing.allocator, "default truncation", &store);
    defer std.testing.allocator.free(ci_report);
    try std.testing.expect(std.mem.indexOf(u8, ci_report, "truncation: max_event_string_bytes=off truncated_fields=0") != null);
}

test "causal store truncates event strings before snapshots reports json dot and backend emission" {
    var backend_state = FakeCausalBackendState{};
    var store = fx.CausalStore.initWithOptions(std.testing.allocator, .{
        .max_event_string_bytes = 24,
    });
    store.attachBackend(fakeCausalBackend(&backend_state));
    defer store.deinit();

    _ = try store.record(.{
        .kind = .run_started,
        .label = "label-prefix-that-is-too-long",
        .type_name = "TypeNamePrefixThatIsTooLong",
        .status = "status-prefix-that-is-too-long",
        .redacted_detail = "detail-prefix-that-is-too-long",
    });

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    const event = snapshot.events[0];
    try std.testing.expect(event.label.len <= 24);
    try std.testing.expect(event.type_name.len <= 24);
    try std.testing.expect(event.status.len <= 24);
    try std.testing.expect(event.redacted_detail.len <= 24);
    try std.testing.expect(std.mem.indexOf(u8, event.label, "<truncated>") != null);
    try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "<truncated>") != null);
    try std.testing.expectEqual(@as(u64, 4), store.truncatedFieldCount());

    try std.testing.expectEqual(@as(usize, 1), backend_state.count);
    try std.testing.expect(backend_state.labels[0].len <= 24);
    try std.testing.expect(std.mem.indexOf(u8, backend_state.labels[0], "<truncated>") != null);
    try std.testing.expect(std.mem.indexOf(u8, backend_state.labels[0], "too-long") == null);

    const report = try fx.formatCausalReport(std.testing.allocator, "truncated", &store);
    defer std.testing.allocator.free(report);
    try std.testing.expect(std.mem.indexOf(u8, report, "truncation: max_event_string_bytes=24 truncated_fields=4") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "too-long") == null);

    const ci_report = try fx.formatCausalCiReport(std.testing.allocator, "truncated", &store);
    defer std.testing.allocator.free(ci_report);
    try std.testing.expect(std.mem.indexOf(u8, ci_report, "truncation: max_event_string_bytes=24 truncated_fields=4") != null);

    const json = try fx.formatCausalJson(std.testing.allocator, &store);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"max_event_string_bytes\": 24") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"truncated_fields\": 4") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "too-long") == null);

    const dot = try fx.formatCausalDot(std.testing.allocator, &store);
    defer std.testing.allocator.free(dot);
    try std.testing.expect(std.mem.indexOf(u8, dot, "<truncated>") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "too-long") == null);
}

test "causal string truncation happens after secret redaction" {
    var backend_state = FakeCausalBackendState{};
    var store = fx.CausalStore.initWithOptions(std.testing.allocator, .{
        .max_event_string_bytes = 40,
    });
    store.attachBackend(fakeCausalBackend(&backend_state));
    defer store.deinit();

    _ = try store.record(.{
        .kind = .log_recorded,
        .label = "token=raw-secret-token safe-context-safe-context-safe-context-safe-context",
        .type_name = "postgresql://root:raw-db-password@localhost/yachdee with trailing context",
        .status = "api_key=raw-api-key safe=kept with trailing context",
        .redacted_detail = "{\"email\":\"owner@example.com\",\"safe\":\"kept\",\"token\":\"raw-json-token\",\"note\":\"long\"}",
    });

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    const event = snapshot.events[0];
    try std.testing.expect(std.mem.indexOf(u8, event.label, "raw-secret-token") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.type_name, "raw-db-password") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.status, "raw-api-key") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "owner@example.com") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "raw-json-token") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.label, "<redacted>") != null);
    try std.testing.expect(std.mem.indexOf(u8, event.label, "<truncated>") != null);
    try std.testing.expectEqual(@as(u64, 4), store.truncatedFieldCount());

    try std.testing.expect(std.mem.indexOf(u8, backend_state.labels[0], "raw-secret-token") == null);

    const json = try fx.formatCausalJson(std.testing.allocator, &store);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "raw-secret-token") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "raw-db-password") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "raw-api-key") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "owner@example.com") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "raw-json-token") == null);
}

test "causal store redacts secret-shaped event strings before storage and export" {
    var backend_state = FakeCausalBackendState{};
    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(fakeCausalBackend(&backend_state));
    defer store.deinit();

    _ = try store.record(.{
        .kind = .log_recorded,
        .label = "Authorization: Bearer raw-bearer-token",
        .type_name = "postgresql://root:db-password@localhost/yachdee",
        .status = "api_key=sk-proj-raw-key",
        .redacted_detail = "database.password=hunter2 token: raw-token safe=kept",
    });

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    const event = snapshot.events[0];
    try std.testing.expect(std.mem.indexOf(u8, event.label, "raw-bearer-token") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.type_name, "db-password") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.status, "sk-proj-raw-key") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "hunter2") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "raw-token") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "safe=kept") != null);
    try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "database.password=<redacted>") != null);

    try std.testing.expect(std.mem.indexOf(u8, backend_state.labels[0], "raw-bearer-token") == null);

    const report = try fx.formatCausalReport(std.testing.allocator, "redaction", &store);
    defer std.testing.allocator.free(report);
    try std.testing.expect(std.mem.indexOf(u8, report, "hunter2") == null);
    try std.testing.expect(std.mem.indexOf(u8, report, "raw-token") == null);
    try std.testing.expect(std.mem.indexOf(u8, report, "db-password") == null);
    try std.testing.expect(std.mem.indexOf(u8, report, "<redacted>") != null);

    const json = try fx.formatCausalJson(std.testing.allocator, &store);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "hunter2") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "raw-token") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "db-password") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "<redacted>") != null);
}

test "causal redaction removes sensitive headers cookies and query params" {
    var backend_state = FakeCausalBackendState{};
    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(fakeCausalBackend(&backend_state));
    defer store.deinit();

    _ = try store.record(.{
        .kind = .log_recorded,
        .label = "Cookie: sid=raw-cookie; theme=dark",
        .type_name = "Proxy-Authorization: Basic raw-proxy",
        .status = "GET /v1?vessel=demo&x-api-key=raw-query-key",
        .redacted_detail = "Set-Cookie: session_id=raw-session; HttpOnly",
    });

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    const event = snapshot.events[0];
    try std.testing.expect(std.mem.indexOf(u8, event.label, "raw-cookie") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.label, "theme=dark") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.label, "Cookie: <redacted>") != null);
    try std.testing.expect(std.mem.indexOf(u8, event.type_name, "raw-proxy") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.status, "raw-query-key") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.status, "vessel=demo") != null);
    try std.testing.expect(std.mem.indexOf(u8, event.status, "x-api-key=<redacted>") != null);
    try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "raw-session") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "HttpOnly") == null);

    try std.testing.expect(std.mem.indexOf(u8, backend_state.labels[0], "raw-cookie") == null);
    try std.testing.expect(std.mem.indexOf(u8, backend_state.labels[0], "Cookie: <redacted>") != null);

    const json = try fx.formatCausalJson(std.testing.allocator, &store);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "raw-cookie") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "raw-proxy") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "raw-query-key") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "raw-session") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "vessel=demo") != null);
}

test "causal redaction handles quoted json-ish keys and key-bound personal data" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    _ = try store.record(.{
        .kind = .log_recorded,
        .label = "headers.authorization: \"Bearer raw-json-bearer\"",
        .type_name = "ip_address=\"203.0.113.42\" user=jane",
        .status = "'phone_number': 'raw-phone'",
        .redacted_detail = "{\"email\":\"owner@example.com\",\"safe\":\"kept\",\"auth\":{\"token\":\"raw-json-token\"}}",
    });

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    const event = snapshot.events[0];
    try std.testing.expect(std.mem.indexOf(u8, event.label, "raw-json-bearer") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.label, "headers.authorization: \"<redacted>\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, event.type_name, "203.0.113.42") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.type_name, "user=jane") != null);
    try std.testing.expect(std.mem.indexOf(u8, event.status, "raw-phone") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.status, "'phone_number': '<redacted>'") != null);
    try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "owner@example.com") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "raw-json-token") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "\"safe\":\"kept\"") != null);

    const report = try fx.formatCausalReport(std.testing.allocator, "quoted-redaction", &store);
    defer std.testing.allocator.free(report);
    try std.testing.expect(std.mem.indexOf(u8, report, "owner@example.com") == null);
    try std.testing.expect(std.mem.indexOf(u8, report, "raw-json-token") == null);
    try std.testing.expect(std.mem.indexOf(u8, report, "safe") != null);
}

test "causal redaction covers sql-ish config payloads without free-text pii scanning" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    _ = try store.record(.{
        .kind = .log_recorded,
        .label = "owner email 'owner@example.com' contact plain@example.com",
        .type_name = "headers['authorization']='Bearer raw-bracket' contact plain@example.com",
        .status = "config[database_url]=\"postgresql://root:raw-db@db/app\" retry_count:2",
        .redacted_detail = "select user_ip '198.51.100.42' attempt=2 delay_ms=null decision=exhausted",
    });

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    const event = snapshot.events[0];
    try std.testing.expect(std.mem.indexOf(u8, event.label, "owner@example.com") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.label, "email '<redacted>'") != null);
    try std.testing.expect(std.mem.indexOf(u8, event.label, "plain@example.com") != null);
    try std.testing.expect(std.mem.indexOf(u8, event.type_name, "raw-bracket") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.type_name, "headers['authorization']='<redacted>'") != null);
    try std.testing.expect(std.mem.indexOf(u8, event.type_name, "plain@example.com") != null);
    try std.testing.expect(std.mem.indexOf(u8, event.status, "raw-db") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.status, "config[database_url]=\"<redacted>\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, event.status, "retry_count:2") != null);
    try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "198.51.100.42") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "attempt=2 delay_ms=null decision=exhausted") != null);

    const json = try fx.formatCausalJson(std.testing.allocator, &store);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "owner@example.com") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "raw-bracket") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "raw-db") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "198.51.100.42") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "plain@example.com") != null);
}

test "causal redaction preserves safe retry diagnostics" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    _ = try store.record(.{
        .kind = .schedule_decision,
        .label = "retry",
        .status = "exhausted",
        .redacted_detail = "attempt=2 delay_ms=null decision=exhausted",
    });

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    try std.testing.expectEqualStrings(
        "attempt=2 delay_ms=null decision=exhausted",
        snapshot.events[0].redacted_detail,
    );
}

test "causal ci report includes findings next queries and citation ids" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    const run_id = store.nextRunId();
    const scope_id = store.nextScopeId();
    const started = try store.record(.{
        .kind = .run_started,
        .run_id = run_id,
        .label = "readiness",
    });
    const resource = try store.record(.{
        .kind = .resource_acquired,
        .run_id = run_id,
        .scope_id = scope_id,
        .label = "database",
        .type_name = "DatabaseConnection",
        .redacted_detail = "super-secret-password",
    });
    _ = try store.record(.{
        .kind = .service_required,
        .run_id = run_id,
        .parent_id = started,
        .label = "DatabaseLayer",
        .type_name = @typeName(fx.Config),
        .status = "missing",
    });
    _ = try store.record(.{
        .kind = .exit_recorded,
        .run_id = run_id,
        .parent_id = resource,
        .status = "failure",
        .type_name = "MissingConfig",
    });

    const report = try fx.formatCausalCiReport(std.testing.allocator, "readiness", &store);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal ci report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "program: readiness") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "events: 4") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "findings: 2") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "event id=1 kind=run_started") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "finding event=2 kind=resource_acquired_without_finalization") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "next queries:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "- causal.cause 2") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "- causal.lineage 2") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "- causal.resources 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "- causal.requirements 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "super-secret-password") == null);
}
