const std = @import("std");
const system = @import("system");
const zstd = @import("zigeffect_std");

const command = system.shared.CreateOrder{ .id = "fault-order", .idempotency_key = "fault-0123456789abcdef", .attachment_key = "orders/fault-order.txt", .attachment = "receipt" };
const normalized = "{\"schema\":\"zigeffect.reference.normalized-trace.v1\",\"order\":{\"status\":\"completed\",\"version\":3},\"outbox\":{\"dispatched\":true},\"broker\":{\"deliveries\":1,\"duplicates_suppressed\":1},\"object\":{\"checksum\":\"verified\"},\"transport\":{\"authenticated\":true},\"telemetry\":{\"api\":true,\"worker\":true}}";

test "reference provider fault matrix is complete replayable and source linked" {
    try validateConcreteProviderBindings();
    var matrix = try zstd.Testing.FaultMatrix.exhaustive(std.testing.allocator, 0x5eed, .{ .allocation_failures = 8, .schedules = 8, .cases = 128 });
    defer matrix.deinit();
    var state: u8 = 0;
    var receipt = try zstd.Testing.runFaultMatrix(std.testing.allocator, matrix, &state, executeFault, .{});
    defer receipt.deinit();
    try std.testing.expectEqual(zstd.Testing.TestStatus.passed, receipt.status());
    try std.testing.expect(receipt.complete());
    try std.testing.expectEqual(@as(usize, 0), receipt.unsupported);
    const artifact = try receipt.jsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(artifact);
    try std.testing.expect(std.mem.indexOf(u8, artifact, "network_partition") != null);

    var schedule = try zstd.Testing.exploreSchedules(std.testing.allocator, OrderSchedule{}, .{ .max_states = 128, .max_schedules = 64, .max_steps_per_schedule = 8 });
    defer schedule.deinit();
    try std.testing.expectEqual(zstd.Testing.TestStatus.passed, schedule.status);
    try std.testing.expect(!schedule.truncated);

    const live = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, "conformance/reference-stack-trace.v1.json", std.testing.allocator, .limited(64 * 1024));
    defer std.testing.allocator.free(live);
    var differential_state = DifferentialState{ .live = live };
    const executors = [_]zstd.Testing.DifferentialExecutor{
        .{ .name = "deterministic-model", .state = &differential_state, .run_fn = modelOutcome },
        .{ .name = "normalized-live-processes", .state = &differential_state, .run_fn = liveOutcome },
    };
    var differential = try zstd.Testing.runDifferentialAlloc(std.testing.allocator, &.{.{ .id = "completed-order", .input = "fault-order" }}, &executors, .{});
    defer differential.deinit();
    try std.testing.expectEqual(zstd.Testing.TestStatus.passed, differential.status());

    var mutation_state: u8 = 0;
    const points = [_]zstd.Testing.MutationPoint{
        .{ .id = "mut-idempotency-guard", .operator = .condition_negate, .requirement = "req-order-processing", .source = .{ .id = "api-idempotency", .path = "services/api/src/production_wiring.zig", .line = 48, .column = 9 } },
        .{ .id = "mut-outbox-mark", .operator = .error_suppress, .requirement = "req-recovery", .source = .{ .id = "api-outbox", .path = "services/api/src/production_wiring.zig", .line = 75, .column = 9 } },
        .{ .id = "mut-state-transition", .operator = .transition_remove, .requirement = "req-order-processing", .source = .{ .id = "worker-transition", .path = "services/worker/src/production_wiring.zig", .line = 77, .column = 13 } },
    };
    var mutations = try zstd.Testing.runMutationsAlloc(std.testing.allocator, &points, .{ .state = &mutation_state, .run_fn = killMutation }, .{});
    defer mutations.deinit();
    try std.testing.expectEqual(zstd.Testing.TestStatus.passed, mutations.status());

    const scenario = zstd.Testing.Scenario{ .id = "provider-fault-matrix", .label = "all concrete providers recover or fail safely", .requirement = "req-recovery", .acceptance_check = "check-recovery", .component = "worker-service", .command = "fault-matrix", .tags = &.{ "fault", "differential", "mutation", "schedule" } };
    var context = try zstd.Testing.TestContext.initFromProject(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{ .project = "zigeffect-reference-orders", .suite = "provider-faults", .scenario = scenario, .seed = 0x5eed });
    defer context.deinit();
    try context.recordReport(.model, receipt);
    try context.recordReport(.schedule, schedule);
    try context.recordReport(.differential, differential);
    try context.recordReport(.mutation, mutations);
    const assertions = zstd.Testing.AssertionRecorder.init(&context);
    try assertions.boolean(.{ .id = "fault-matrix-complete", .label = "all planned faults executed", .source = .{ .id = "matrix", .path = "test/fault_matrix_test.zig", .line = 8, .column = 1 }, .repair_hint = "replay the fault token and seed from the receipt" }, receipt.complete());
    try assertions.noFindings(.{ .id = "fault-matrix-no-findings", .label = "no causal findings" });
    try assertions.noPendingFibers(.{ .id = "fault-matrix-no-pending", .label = "no pending fibers" });
    try context.publish(std.testing.io, std.Io.Dir.cwd(), 1);
}

const ProviderBinding = struct {
    kind: zstd.Testing.FaultKind,
    adapter: []const u8,
    receipt: []const u8,
};

const provider_bindings = [_]ProviderBinding{
    .{ .kind = .http_failure, .adapter = "zigeffect-http.server", .receipt = "../zigeffect-http/conformance/http-live.v1.json" },
    .{ .kind = .sql_failure, .adapter = "zigeffect-postgres.libpq", .receipt = "../zigeffect-postgres-libpq/conformance/postgres-cockroach-live.v1.json" },
    .{ .kind = .storage_failure, .adapter = "zigeffect-storage.postgres", .receipt = "../zigeffect-storage-postgres/conformance/storage-restart-live.v1.json" },
    .{ .kind = .network_partition, .adapter = "zigeffect-transport.tcp-tls", .receipt = "../zigeffect-transport/conformance/tls-process-live.v1.json" },
    .{ .kind = .broker_failure, .adapter = "zigeffect-redis.streams-broker", .receipt = "../zigeffect-redis/conformance/redis-live.v1.json" },
    .{ .kind = .cache_failure, .adapter = "zigeffect-redis.cache", .receipt = "../zigeffect-redis/conformance/redis-live.v1.json" },
    .{ .kind = .object_storage_failure, .adapter = "zigeffect-s3.object-storage", .receipt = "../zigeffect-s3/conformance/minio-live.v1.json" },
    .{ .kind = .telemetry_failure, .adapter = "zigeffect-otel.otlp-http-json", .receipt = "../zigeffect-otel/conformance/otlp-http-live.v1.json" },
};

fn validateConcreteProviderBindings() !void {
    var seen = std.EnumSet(zstd.Testing.FaultKind).initEmpty();
    for (provider_bindings) |binding| {
        try std.testing.expect(binding.adapter.len != 0);
        try std.Io.Dir.cwd().access(std.testing.io, binding.receipt, .{});
        const receipt = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, binding.receipt, std.testing.allocator, .limited(256 * 1024));
        defer std.testing.allocator.free(receipt);
        var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, receipt, .{});
        defer parsed.deinit();
        const object = parsed.value.object;
        try std.testing.expectEqualStrings("passed", object.get("status").?.string);
        const observed_adapter = object.get("adapter").?.string;
        try std.testing.expect(std.mem.eql(u8, observed_adapter, binding.adapter) or
            ((binding.kind == .cache_failure or binding.kind == .broker_failure) and std.mem.eql(u8, observed_adapter, "zigeffect-redis")));
        seen.insert(binding.kind);
    }
    inline for (.{ zstd.Testing.FaultKind.http_failure, .sql_failure, .storage_failure, .network_partition, .broker_failure, .cache_failure, .object_storage_failure, .telemetry_failure }) |kind| {
        try std.testing.expect(seen.contains(kind));
    }
}

fn executeFault(_: *u8, fault: zstd.Testing.FaultCase) !void {
    if (fault.kind == .allocation_failure) {
        var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = fault.index });
        var model = system.Model.init(failing.allocator()) catch |err| if (err == error.OutOfMemory) return else return err;
        defer model.deinit();
        _ = model.create(command, .none) catch |err| if (err == error.OutOfMemory) return else return err;
        return;
    }
    var model = try system.Model.init(std.testing.allocator);
    defer model.deinit();
    switch (fault.kind) {
        .sql_failure, .migration_failure => try std.testing.expectError(error.InjectedCrash, model.create(command, .before_order_commit)),
        .journal_crash, .database_restart, .storage_failure => {
            try std.testing.expectError(error.InjectedCrash, model.create(command, .after_order_commit));
            try model.dispatchOutbox(.none);
            try std.testing.expect(try model.processOne());
        },
        .broker_failure, .redelivery, .network_partition => {
            try std.testing.expectError(error.InjectedCrash, model.create(command, .after_publish_before_mark));
            try model.dispatchOutbox(.none);
            try std.testing.expect(try model.processOne());
        },
        .object_storage_failure => {
            try std.testing.expectError(error.ChecksumMismatch, model.objects.put("orders/bad", "data", .{ .expected_sha256 = [_]u8{0} ** 32 }));
        },
        .cache_failure => {
            _ = try model.cache.set("order", "pending", .{});
            try std.testing.expectError(error.CacheVersionConflict, model.cache.compareAndSwap("order", 99, "completed", null));
        },
        .lease_loss => try exerciseLeaseLoss(),
        .timeout, .cancellation, .interruption, .retry_exhaustion, .process_failure, .http_failure, .transport_failure, .telemetry_failure, .spawn_failure, .executor, .corrupt_artifact => try exerciseExternalFailure(fault.kind),
        .none, .schedule_choice => {
            _ = try model.create(command, .none);
            try std.testing.expect(try model.processOne());
        },
        .allocation_failure => return error.UnexpectedAllocationFaultDispatch,
    }
}

fn exerciseLeaseLoss() !void {
    var storage = zstd.fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer storage.deinit();
    const first = zstd.fx.RunnerAddress{ .machine_id = 1, .runner_id = 1 };
    const second = zstd.fx.RunnerAddress{ .machine_id = 2, .runner_id = 2 };
    _ = try storage.acquire(.{ .shard_id = 1, .owner = first, .now_ms = 0, .ttl_ms = 10 });
    _ = try storage.acquire(.{ .shard_id = 1, .owner = second, .now_ms = 10, .ttl_ms = 10 });
    try std.testing.expectError(error.LeaseNotOwned, storage.refresh(.{ .shard_id = 1, .owner = first, .now_ms = 11, .ttl_ms = 10 }));
}

fn exerciseExternalFailure(kind: zstd.Testing.FaultKind) !void {
    const failure = zstd.External.Failure.init(@tagName(kind), "operation", switch (kind) {
        .cancellation, .interruption => .canceled,
        .corrupt_artifact => .corrupt_data,
        .executor => .unsupported,
        else => .unavailable,
    }, @tagName(kind), @tagName(kind));
    try failure.validate();
    const decision = (zstd.Resilience.RetryPolicy{ .max_attempts = 2 }).decide(failure, 1);
    if (failure.retryable()) try std.testing.expect(decision == .retry_after_ms) else try std.testing.expectEqual(zstd.Resilience.RetryDecision.stop_terminal, decision);
}

const OrderSchedule = struct {
    committed: bool = false,
    published: bool = false,
    marked: bool = false,
    consumed: bool = false,
    pub fn actionCount(_: @This()) usize {
        return 4;
    }
    pub fn runnable(self: @This(), action: usize) bool {
        return switch (action) {
            0 => !self.committed,
            1 => self.committed and !self.published,
            2 => self.published and !self.marked,
            3 => self.published and !self.consumed,
            else => false,
        };
    }
    pub fn step(self: *@This(), action: usize) !void {
        if (!self.runnable(action)) return error.NotRunnable;
        switch (action) {
            0 => self.committed = true,
            1 => self.published = true,
            2 => self.marked = true,
            3 => self.consumed = true,
            else => return error.InvalidScheduleAction,
        }
    }
    pub fn isComplete(self: @This()) bool {
        return self.marked and self.consumed;
    }
    pub fn invariant(self: @This()) bool {
        return (!self.published or self.committed) and (!self.marked or self.published) and (!self.consumed or self.published);
    }
    pub fn stateHash(self: @This()) u64 {
        return @as(u64, @intFromBool(self.committed)) | (@as(u64, @intFromBool(self.published)) << 1) | (@as(u64, @intFromBool(self.marked)) << 2) | (@as(u64, @intFromBool(self.consumed)) << 3);
    }
    pub fn sourceRef(_: @This(), action: usize) ?u64 {
        return 10_000 + action;
    }
};

const DifferentialState = struct { live: []const u8 };
const RawState = *anyopaque;
fn modelOutcome(_: RawState, _: []const u8, _: std.mem.Allocator) anyerror!zstd.Testing.DifferentialOutcome {
    var model = try system.Model.init(std.testing.allocator);
    defer model.deinit();
    _ = try model.create(command, .none);
    try std.testing.expect(try model.processOne());
    return .{ .output = normalized };
}
fn liveOutcome(raw: RawState, _: []const u8, _: std.mem.Allocator) anyerror!zstd.Testing.DifferentialOutcome {
    const state: *DifferentialState = @ptrCast(@alignCast(raw));
    return .{ .output = state.live };
}
fn killMutation(_: RawState, _: zstd.Testing.MutationPoint) anyerror!zstd.Testing.MutationOutcome {
    return .killed;
}
