const std = @import("std");
const zstd = @import("zigeffect_std");

const fx = zstd.fx;

test "runtime defaults are requirement-free effects with semantic aspect fanout" {
    try std.testing.expectEqual(@as(usize, 0), @TypeOf(zstd.Clock.currentTimeMillis()).RequiredServices.len);
    try std.testing.expectEqual(@as(usize, 0), @TypeOf(zstd.Console.writeOut("hello")).RequiredServices.len);
    try std.testing.expectEqual(@as(usize, 0), @TypeOf(zstd.Randomness.integer(u64)).RequiredServices.len);
    try std.testing.expectEqual(@as(usize, 0), @TypeOf(zstd.Config.getAlloc("MODE")).RequiredServices.len);

    var logger = fx.Logger.init(std.testing.allocator);
    defer logger.deinit();
    var metrics = fx.Metrics.init(std.testing.allocator);
    defer metrics.deinit();
    var tracing = fx.Tracing.init(std.testing.allocator);
    defer tracing.deinit();

    const Empty = fx.kernel.Layer.empty();
    var runtime = try fx.kernel.ManagedRuntime(@TypeOf(Empty)).make(
        std.testing.allocator,
        Empty,
        .{ .observability = .{ .logger = &logger, .metrics = &metrics, .tracer = &tracing } },
    );
    defer runtime.deinit();

    var clock = fx.FakeClock.fake(1_000);
    const now = try runtime.run(zstd.Clock.currentTimeMillis().withClock(&clock));
    try std.testing.expectEqual(@as(u64, 1_000), now);
    try runtime.run(zstd.Clock.sleep(25).withClock(&clock));
    try std.testing.expectEqual(@as(u64, 1_025), clock.nowMs());

    var console = zstd.Console.CapturedConsole.init(std.testing.allocator);
    defer console.deinit();
    try runtime.run(zstd.Console.writeOut("hello").withDefaults(.{
        .console = console.asDefault(),
    }));
    try std.testing.expectEqualStrings("hello", console.stdoutText());

    var random = zstd.Randomness.Deterministic.init(42);
    const first = try runtime.run(zstd.Randomness.integer(u64).withDefaults(.{
        .random = random.asDefault(),
    }));
    var replay = zstd.Randomness.Deterministic.init(42);
    const second = try runtime.run(zstd.Randomness.integer(u64).withDefaults(.{
        .random = replay.asDefault(),
    }));
    try std.testing.expectEqual(first, second);

    var config = zstd.Config.LayeredConfig.init(std.testing.allocator);
    defer config.deinit();
    try config.put("MODE", "test", false);
    const mode = try runtime.run(zstd.Config.getAlloc("MODE").withDefaults(.{
        .config_provider = config.asDefault(),
    }));
    defer std.testing.allocator.free(mode);
    try std.testing.expectEqualStrings("test", mode);

    var snapshot = try runtime.inspect(std.testing.allocator, .{ .max_recent_events = 256 });
    defer snapshot.deinit();
    try expectSemanticEvent(snapshot.causal.recent_events, .timer_scheduled, zstd.Clock.service_key, "Clock.sleep");
    try expectSemanticEvent(snapshot.causal.recent_events, .timer_fired, zstd.Clock.service_key, "Clock.sleep");
    try expectSemanticEvent(snapshot.causal.recent_events, .log_recorded, zstd.Console.service_key, "Console.stdout");
    try expectSemanticEvent(snapshot.causal.recent_events, .span_recorded, zstd.Randomness.service_key, "Random.integer");
    try expectSemanticEvent(snapshot.causal.recent_events, .span_recorded, zstd.Config.service_key, "Config.get");

    try std.testing.expect(metrics.get("zigeffect.semantic.events.total") >= 5);
    try std.testing.expect(logger.entries.items.len >= 5);
    var traced_semantic = false;
    for (tracing.events.items) |event| {
        if (std.mem.startsWith(u8, event, "semantic:")) traced_semantic = true;
    }
    try std.testing.expect(traced_semantic);
}

test "FileSystem and Process are stable services composed once in a ManagedRuntime" {
    var files = zstd.FileSystem.MemoryFileSystem.init(std.testing.allocator);
    defer files.deinit();
    var process = zstd.Process.FakeRunner.init(.{
        .exit_code = 0,
        .stdout = "ok",
    });

    const MainLayer = fx.kernel.Layer.mergeAll(.{
        zstd.FileSystem.memory(&files),
        zstd.Process.fake(&process),
    });
    var runtime = try fx.kernel.ManagedRuntime(@TypeOf(MainLayer)).make(
        std.testing.allocator,
        MainLayer,
        .{},
    );
    defer runtime.deinit();

    try runtime.run(zstd.FileSystem.writeFile("notes/token=abc123.txt", "hello"));
    try std.testing.expect(try runtime.run(zstd.FileSystem.exists("notes/token=abc123.txt")));
    const content = try runtime.run(zstd.FileSystem.readFileAlloc("notes/token=abc123.txt"));
    defer std.testing.allocator.free(content);
    try std.testing.expectEqualStrings("hello", content);

    var output = try runtime.run(zstd.Process.run(.{
        .argv = &.{ "echo", "token=abc123" },
    }));
    defer output.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("ok", output.stdout);

    var snapshot = try runtime.inspect(std.testing.allocator, .{ .max_recent_events = 256 });
    defer snapshot.deinit();

    var evidence = try zstd.Testing.TestContext.init(std.testing.allocator, .{
        .project = "zigeffect-std",
        .suite = "canonical-architecture",
        .scenario = .{
            .id = "std-services-compose",
            .label = "standard services compose through one managed runtime",
            .requirement = "std-canonical-services",
            .acceptance_check = "services-and-causal-map",
            .component = "zigeffect-std",
            .command = "canonical-architecture-test",
        },
        .seed = 42,
    });
    defer evidence.deinit();
    const assertions = zstd.Testing.AssertionRecorder.init(&evidence);
    try assertions.applicationService(.{
        .id = "filesystem-visible",
        .label = "FileSystem is visible in the application map",
        .repair_hint = "provide the stable FileSystem tag from the root layer",
    }, &snapshot, zstd.FileSystem.FileSystem.service_key, true);
    try assertions.applicationService(.{
        .id = "process-visible",
        .label = "Process is visible in the application map",
        .repair_hint = "provide the stable Process tag from the root layer",
    }, &snapshot, zstd.Process.Process.service_key, true);
    try assertions.applicationOperation(.{
        .id = "filesystem-write-visible",
        .label = "FileSystem write is discoverable in the application map",
        .repair_hint = "publish canonical operation metadata on the FileSystem service tag",
    }, &snapshot, zstd.FileSystem.FileSystem.service_key, "FileSystem.writeFile");
    try assertions.applicationOperation(.{
        .id = "process-run-visible",
        .label = "Process run is discoverable in the application map",
        .repair_hint = "publish canonical operation metadata on the Process service tag",
    }, &snapshot, zstd.Process.Process.service_key, "Process.run");
    try assertions.applicationHealthy(.{
        .id = "runtime-healthy",
        .label = "the composed runtime has no causal findings or escaped fibers",
        .repair_hint = "close every child scope and preserve complete semantic operation pairs",
    }, &snapshot);

    try expectOperationPair(
        snapshot.causal.recent_events,
        zstd.FileSystem.FileSystem.service_key,
        "FileSystem.writeFile",
    );
    try expectOperationPair(
        snapshot.causal.recent_events,
        zstd.Process.Process.service_key,
        "Process.run",
    );
    for (snapshot.causal.recent_events) |event| {
        try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "abc123") == null);
    }
}

fn expectSemanticEvent(
    events: []const fx.CausalEvent,
    kind: fx.CausalEventKind,
    service_key: []const u8,
    label: []const u8,
) !void {
    for (events) |event| {
        if (event.kind == kind and
            std.mem.eql(u8, event.service_key, service_key) and
            std.mem.eql(u8, event.label, label)) return;
    }
    return error.ExpectedSemanticEventMissing;
}

fn expectOperationPair(events: []const fx.CausalEvent, service_key: []const u8, label: []const u8) !void {
    var started_id: ?u64 = null;
    for (events) |event| {
        if (!std.mem.eql(u8, event.service_key, service_key) or !std.mem.eql(u8, event.label, label)) continue;
        if (event.kind == .io_wait_started) started_id = event.id;
        if (event.kind == .io_completed and started_id != null and event.parent_id == started_id) return;
    }
    return error.ExpectedCausalOperationPairMissing;
}
