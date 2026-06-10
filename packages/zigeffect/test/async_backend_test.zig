const std = @import("std");
const fx = @import("zigeffect");

const AsyncEnv = struct {};

fn suspendFromContext(ctx: *fx.Context(AsyncEnv)) fx.AsyncBackendError!fx.RuntimeDecision {
    const suspension = fx.Suspension{ .kind = .external, .id = 61, .label = "runtime-io" };
    try ctx.suspendRuntime(suspension, "runtime wait");
    return .{ .suspended = suspension };
}

fn suspendFromFiberContext(ctx: *fx.Context(AsyncEnv)) fx.AsyncBackendError!fx.RuntimeDecision {
    const suspension = fx.Suspension{ .kind = .external, .id = 62, .label = "fiber-io" };
    try ctx.registerIoWait(suspension, .file, .completion, 9, "fiber file wait");
    return .{ .suspended = suspension };
}

test "unsupported deterministic async backend rejects io waits and wake polling" {
    var state = fx.UnsupportedAsyncBackendState.init(fx.deterministicBackend());
    const backend = state.backend();
    const suspension = fx.Suspension{ .kind = .external, .id = 1, .label = "deterministic-io" };

    try std.testing.expectError(error.UnsupportedBackendCapability, backend.registerIoWait(.{
        .suspension = suspension,
        .io_kind = .network,
        .interest = .readable,
        .descriptor = 7,
        .reason = "socket read",
    }));
    try std.testing.expectError(error.UnsupportedBackendCapability, backend.completeIo(.{
        .suspension_id = suspension.id,
        .io_kind = .network,
        .reason = "socket ready",
    }));
    try std.testing.expectError(error.UnsupportedBackendCapability, backend.pollWake());

    const snapshot = backend.snapshot();
    try std.testing.expectEqual(@as(usize, 0), snapshot.pending_count);
    try std.testing.expectEqual(@as(usize, 0), snapshot.ready_count);
}

test "local async backend exposes snapshot and idempotent wake lifecycle" {
    var state = fx.LocalAsyncBackendState.init(std.testing.allocator, .{ .now_ms = 100 });
    defer state.deinit();
    const backend = state.backend();

    const suspension = fx.Suspension{ .kind = .external, .id = 11, .label = "io" };
    try backend.suspendRuntime(.{ .suspension = suspension, .reason = "runtime wait" });
    try backend.wake(.{ .suspension_id = 11, .reason = "ready" });
    try backend.wake(.{ .suspension_id = 11, .reason = "duplicate" });

    const snapshot = backend.snapshot();
    try std.testing.expectEqual(@as(usize, 0), snapshot.pending_count);
    try std.testing.expectEqual(@as(usize, 1), snapshot.ready_count);
    try std.testing.expectEqual(@as(usize, 1), snapshot.completed_count);
    try std.testing.expectEqual(@as(usize, 1), snapshot.duplicate_wake_count);

    const wake = (try backend.pollWake()).?;
    try std.testing.expectEqual(@as(u64, 11), wake.suspension.id);
    try std.testing.expectEqual(fx.AsyncWaitKind.runtime, wake.wait_kind);
    try std.testing.expectEqual(fx.AsyncWaitStatus.ready, wake.status);
    try std.testing.expectEqualStrings("ready", wake.reason);
    try std.testing.expect((try backend.pollWake()) == null);
}

test "local async backend schedules timers against backend time" {
    var state = fx.LocalAsyncBackendState.init(std.testing.allocator, .{ .now_ms = 100 });
    defer state.deinit();
    const backend = state.backend();

    try backend.scheduleTimer(.{
        .suspension = .{ .kind = .timer, .id = 21, .label = "wake" },
        .due_time_ms = 250,
        .now_ms = 100,
    });
    var snapshot = backend.snapshot();
    try std.testing.expectEqual(@as(usize, 1), snapshot.pending_count);
    try std.testing.expectEqual(@as(usize, 0), snapshot.ready_count);
    try std.testing.expectEqual(@as(u64, 250), snapshot.next_due_time_ms.?);

    try std.testing.expectEqual(@as(usize, 0), try state.advanceTo(249));
    try std.testing.expect((try backend.pollWake()) == null);

    try std.testing.expectEqual(@as(usize, 1), try state.advanceTo(250));
    snapshot = backend.snapshot();
    try std.testing.expectEqual(@as(usize, 0), snapshot.pending_count);
    try std.testing.expectEqual(@as(usize, 1), snapshot.ready_count);

    const wake = (try backend.pollWake()).?;
    try std.testing.expectEqual(fx.AsyncWaitKind.timer, wake.wait_kind);
    try std.testing.expectEqual(@as(u64, 21), wake.suspension.id);
    try std.testing.expectEqual(@as(?u64, 250), wake.due_time_ms);
}

test "local async backend completes typed network and file waits" {
    var state = fx.LocalAsyncBackendState.init(std.testing.allocator, .{});
    defer state.deinit();
    const backend = state.backend();

    try backend.registerIoWait(.{
        .suspension = .{ .kind = .external, .id = 31, .label = "socket" },
        .io_kind = .network,
        .interest = .readable,
        .descriptor = 3,
        .reason = "socket read",
    });
    try backend.registerIoWait(.{
        .suspension = .{ .kind = .external, .id = 32, .label = "file" },
        .io_kind = .file,
        .interest = .completion,
        .descriptor = 4,
        .reason = "file read",
    });

    try std.testing.expectEqual(@as(usize, 2), backend.snapshot().pending_count);
    try backend.completeIo(.{ .suspension_id = 31, .io_kind = .network, .reason = "socket ready" });
    try backend.completeIo(.{ .suspension_id = 32, .io_kind = .file, .reason = "file ready" });

    const network = (try backend.pollWake()).?;
    try std.testing.expectEqual(fx.AsyncWaitKind.network, network.wait_kind);
    try std.testing.expectEqual(fx.AsyncIoInterest.readable, network.interest.?);
    try std.testing.expectEqual(@as(?i64, 3), network.descriptor);

    const file = (try backend.pollWake()).?;
    try std.testing.expectEqual(fx.AsyncWaitKind.file, file.wait_kind);
    try std.testing.expectEqual(fx.AsyncIoInterest.completion, file.interest.?);
    try std.testing.expectEqual(@as(?i64, 4), file.descriptor);
}

test "local async backend interrupts pending waits once" {
    var state = fx.LocalAsyncBackendState.init(std.testing.allocator, .{});
    defer state.deinit();
    const backend = state.backend();

    try backend.suspendRuntime(.{
        .suspension = .{ .kind = .external, .id = 41, .label = "interruptible" },
        .reason = "waiting",
    });
    try backend.interrupt(.{ .target_id = 41, .reason = "operator" });
    try backend.interrupt(.{ .target_id = 41, .reason = "duplicate" });

    const snapshot = backend.snapshot();
    try std.testing.expectEqual(@as(usize, 0), snapshot.pending_count);
    try std.testing.expectEqual(@as(usize, 1), snapshot.interrupted_count);
    try std.testing.expectEqual(@as(usize, 1), snapshot.interrupt_count);

    const wake = (try backend.pollWake()).?;
    try std.testing.expectEqual(fx.AsyncWaitStatus.interrupted, wake.status);
    try std.testing.expectEqualStrings("operator", wake.reason);
}

test "scope finalization interrupts async backend wait" {
    var state = fx.LocalAsyncBackendState.init(std.testing.allocator, .{});
    defer state.deinit();
    const backend = state.backend();
    var scope = fx.Scope.init(std.testing.allocator);
    defer scope.deinit();

    try backend.suspendRuntime(.{
        .suspension = .{ .kind = .external, .id = 51, .label = "scoped" },
        .reason = "scoped wait",
    });
    try fx.attachAsyncInterruptFinalizer(&scope, backend, 51, "scope closed");
    scope.closeWithExit(.{ .interrupted = 99 });

    const wake = (try backend.pollWake()).?;
    try std.testing.expectEqual(@as(u64, 51), wake.suspension.id);
    try std.testing.expectEqual(fx.AsyncWaitStatus.interrupted, wake.status);
    try std.testing.expectEqual(@as(usize, 1), backend.snapshot().interrupt_count);
}

test "runtime and fiber runtime propagate async backend into context" {
    var state = fx.LocalAsyncBackendState.init(std.testing.allocator, .{});
    defer state.deinit();
    const backend = state.backend();
    var env = AsyncEnv{};

    var runtime = fx.Runtime(AsyncEnv).init(std.testing.allocator, &env).withAsyncBackend(backend);
    const effect = fx.Effect(fx.RuntimeDecision, fx.AsyncBackendError, AsyncEnv).fromFn(suspendFromContext);
    const decision = try runtime.run(effect);
    switch (decision) {
        .suspended => |suspension| try std.testing.expectEqual(@as(u64, 61), suspension.id),
        else => return error.ExpectedRuntimeSuspension,
    }

    var fiber_runtime = fx.FiberRuntime(AsyncEnv).init(std.testing.allocator, &env).withAsyncBackend(backend);
    defer fiber_runtime.deinit();
    const fiber_effect = fx.Effect(fx.RuntimeDecision, fx.AsyncBackendError, AsyncEnv).fromFn(suspendFromFiberContext);
    const fiber = try fiber_runtime.fork(fiber_effect);
    switch (fiber.joinExit()) {
        .success => |fiber_decision| switch (fiber_decision) {
            .suspended => |suspension| try std.testing.expectEqual(@as(u64, 62), suspension.id),
            else => return error.ExpectedFiberSuspension,
        },
        else => return error.ExpectedFiberSuccess,
    }
}

test "workflow engine stores async backend handle and capabilities" {
    var state = fx.LocalAsyncBackendState.init(std.testing.allocator, .{});
    defer state.deinit();
    const backend = state.backend();
    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();

    var engine = fx.workflow.WorkflowEngine.initWithAsyncBackend(
        std.testing.allocator,
        journal_memory.asJournalStore(),
        backend,
    );
    defer engine.deinit();

    try std.testing.expectEqual(fx.BackendKind.async_local, engine.backendCapabilities().kind);
    try std.testing.expect(engine.asyncBackend() != null);
}

test "workflow scheduler tickAsync wakes durable timer once" {
    var state = fx.LocalAsyncBackendState.init(std.testing.allocator, .{ .now_ms = 1_000 });
    defer state.deinit();
    const backend = state.backend();
    var clock = fx.FakeClock.fake(1_000);
    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 71,
        .execution_id = 72,
        .name = "async-timer-workflow",
        .status = "running",
        .idempotency_key = "async-timer-start",
    } });

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 71,
            .execution_id = 72,
            .clock = &clock,
        });
        defer context.deinit();
        const sleep = try context.sleep("async-wake", 250);
        switch (sleep) {
            .suspended => {},
            else => return error.ExpectedTimerSuspension,
        }
    }

    var scheduler = fx.workflow.WorkflowScheduler.initWithAsyncBackend(std.testing.allocator, journal, &clock, backend);
    defer scheduler.deinit();
    try scheduler.registerTimerWatch(.{ .workflow_id = 71, .execution_id = 72 });

    const early = try scheduler.tickAsync(.{ .max_workflow_polls = 0, .max_timers = 1, .max_queue_retries = 0, .max_queue_claims = 0 });
    try std.testing.expectEqual(@as(usize, 0), early.timers_fired);
    try std.testing.expectEqual(@as(usize, 1), backend.snapshot().pending_count);

    clock.sleep(250);
    const due = try scheduler.tickAsync(.{ .max_workflow_polls = 0, .max_timers = 1, .max_queue_retries = 0, .max_queue_claims = 0 });
    try std.testing.expectEqual(@as(usize, 1), due.timers_fired);
    const duplicate = try scheduler.tickAsync(.{ .max_workflow_polls = 0, .max_timers = 1, .max_queue_retries = 0, .max_queue_claims = 0 });
    try std.testing.expectEqual(@as(usize, 0), duplicate.timers_fired);

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.timer_fired, events.events[3].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_resumed, events.events[4].kind);
}

const AsyncQueuePayload = struct {
    account_id: u64,
};

const AsyncQueue = fx.workflow
    .Queue("async-backend-email", AsyncQueuePayload, u64, error{DeliveryFailed})
    .withIdempotencyKey(struct {
    fn key(allocator: std.mem.Allocator, payload: AsyncQueuePayload) ![]const u8 {
        return std.fmt.allocPrint(allocator, "async-backend-email:{d}", .{payload.account_id});
    }
}.key);

const async_queue_payload_codec = fx.Codec(AsyncQueuePayload){
    .encode = struct {
        fn encode(allocator: std.mem.Allocator, payload: AsyncQueuePayload) ![]const u8 {
            return std.fmt.allocPrint(allocator, "{d}", .{payload.account_id});
        }
    }.encode,
    .decode = struct {
        fn decode(_: std.mem.Allocator, bytes: []const u8) !AsyncQueuePayload {
            return .{ .account_id = try std.fmt.parseInt(u64, bytes, 10) };
        }
    }.decode,
};

const async_queue_result_codec = fx.Codec(u64){
    .encode = struct {
        fn encode(allocator: std.mem.Allocator, value: u64) ![]const u8 {
            return std.fmt.allocPrint(allocator, "{d}", .{value});
        }
    }.encode,
    .decode = struct {
        fn decode(_: std.mem.Allocator, bytes: []const u8) !u64 {
            return std.fmt.parseInt(u64, bytes, 10);
        }
    }.decode,
};

const AsyncQueueHandler = struct {
    var calls: usize = 0;

    fn run(payload: AsyncQueuePayload, _: u32) error{DeliveryFailed}!u64 {
        calls += 1;
        return payload.account_id + 500;
    }
};

test "workflow scheduler tickAsync wakes queue suspension after terminal write" {
    AsyncQueueHandler.calls = 0;
    var state = fx.LocalAsyncBackendState.init(std.testing.allocator, .{});
    defer state.deinit();
    const backend = state.backend();
    var clock = fx.FakeClock.fake(1_000);
    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 81,
        .execution_id = 82,
        .name = "async-queue-workflow",
        .status = "running",
        .idempotency_key = "async-queue-start",
    } });

    var queue_suspension: fx.Suspension = undefined;
    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 81,
            .execution_id = 82,
        });
        defer context.deinit();
        const queued = try context.queue(AsyncQueue, async_queue_payload_codec, async_queue_result_codec, .{ .account_id = 42 });
        switch (queued) {
            .suspended => |suspension| queue_suspension = suspension,
            else => return error.ExpectedQueueSuspension,
        }
    }
    try backend.suspendRuntime(.{ .suspension = queue_suspension, .reason = "queue wait" });

    var worker = fx.workflow.QueueWorker(AsyncQueue, AsyncQueueHandler.run).init(
        std.testing.allocator,
        journal,
        81,
        82,
        async_queue_payload_codec,
        async_queue_result_codec,
        "async-queue-worker",
    );
    var scheduler = fx.workflow.WorkflowScheduler.initWithAsyncBackend(std.testing.allocator, journal, &clock, backend);
    defer scheduler.deinit();
    try scheduler.registerQueueWorker(worker.asRegisteredQueueWorker());

    const tick = try scheduler.tickAsync(.{ .max_workflow_polls = 0, .max_timers = 0, .max_queue_retries = 0, .max_queue_claims = 1 });
    try std.testing.expectEqual(@as(usize, 1), tick.queue_claims);
    try std.testing.expectEqual(@as(usize, 1), tick.queue_completions);
    try std.testing.expectEqual(@as(usize, 1), AsyncQueueHandler.calls);

    const wake = (try backend.pollWake()).?;
    try std.testing.expectEqual(queue_suspension.id, wake.suspension.id);
    try std.testing.expectEqual(fx.AsyncWaitStatus.ready, wake.status);

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.queue_completed, events.events[4].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_resumed, events.events[5].kind);
}

test "async duplicate wake does not duplicate completed durable activity result" {
    const Payload = struct {
        account_id: u64,
    };
    const Charge = fx.workflow.Activity("async-charge", Payload, u64, error{Declined}, void).withIdempotencyKey(struct {
        fn key(allocator: std.mem.Allocator, payload: Payload) ![]const u8 {
            return std.fmt.allocPrint(allocator, "async-charge:{d}", .{payload.account_id});
        }
    }.key);
    const codec = fx.Codec(u64){
        .encode = struct {
            fn encode(allocator: std.mem.Allocator, value: u64) ![]const u8 {
                return std.fmt.allocPrint(allocator, "{d}", .{value});
            }
        }.encode,
        .decode = struct {
            fn decode(_: std.mem.Allocator, bytes: []const u8) !u64 {
                return std.fmt.parseInt(u64, bytes, 10);
            }
        }.decode,
    };
    const Runner = struct {
        var calls: u64 = 0;

        fn run(payload: Payload) error{Declined}!u64 {
            calls += 1;
            return payload.account_id + 900;
        }
    };
    Runner.calls = 0;

    var state = fx.LocalAsyncBackendState.init(std.testing.allocator, .{});
    defer state.deinit();
    const backend = state.backend();
    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 91,
        .execution_id = 92,
        .name = "async-activity-workflow",
        .status = "running",
        .idempotency_key = "async-activity-start",
    } });

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 91,
            .execution_id = 92,
        });
        defer context.deinit();
        try std.testing.expectEqual(@as(u64, 905), try context.activity(Charge, .{ .account_id = 5 }, codec, Runner.run));
    }

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    const activity_id = events.events[1].activity_id.?;
    try backend.suspendRuntime(.{
        .suspension = .{ .kind = .activity, .id = activity_id, .label = "async-charge" },
        .reason = "activity wait",
    });
    try backend.wake(.{ .suspension_id = activity_id, .reason = "activity ready" });
    try backend.wake(.{ .suspension_id = activity_id, .reason = "activity duplicate" });

    {
        var replay_context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 91,
            .execution_id = 92,
        });
        defer replay_context.deinit();
        try std.testing.expectEqual(@as(u64, 905), try replay_context.activity(Charge, .{ .account_id = 5 }, codec, Runner.run));
    }
    try std.testing.expectEqual(@as(u64, 1), Runner.calls);
    try std.testing.expectEqual(@as(usize, 1), backend.snapshot().duplicate_wake_count);
}

test "cluster transport async wait completes through existing transport storage" {
    var state = fx.LocalAsyncBackendState.init(std.testing.allocator, .{});
    defer state.deinit();
    const backend = state.backend();
    var storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asMessageStorage();
    var transport_state = try fx.InProcessClusterTransport.init(std.testing.allocator, storage, .{ .shard_count = 16 });
    defer transport_state.deinit();
    const transport = transport_state.asClusterTransport();

    const address = fx.entityAddress("counter", "async-transport");
    var wait = try fx.registerClusterTransportWait(std.testing.allocator, backend, .{
        .kind = .request,
        .address = address,
        .payload_type_name = "text",
        .payload = "get",
        .redacted_detail = "read current value",
        .idempotency_key = "async-transport-key",
    }, 101);
    defer wait.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), backend.snapshot().pending_count);
    var response = try fx.completeClusterTransportWait(std.testing.allocator, backend, transport, &wait);
    defer response.deinit(std.testing.allocator);

    try std.testing.expectEqual(fx.ClusterTransportKind.in_process, response.transport);
    try std.testing.expect(response.correlation_id != null);
    const shard_id = try fx.shardIdForAddress(address, 16);
    var by_shard = try storage.unprocessedByShard(shard_id, std.testing.allocator);
    defer by_shard.deinit();
    try std.testing.expectEqual(@as(usize, 1), by_shard.records.len);
}
