const std = @import("std");
const fx = @import("zigeffect");
const causal = @import("support/causal_assertions.zig");
const fixtures = @import("support/fixtures.zig");

test "fiber runtime forks and joins successful effects" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var runtime = fx.FiberRuntime(fx.TestServices)
        .init(std.testing.allocator, &env.services)
        .withClock(&env.services.clock)
        .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });
    defer runtime.deinit();

    const program = fx.Effect(u32, fixtures.TestError, fx.TestServices).fromFn(fixtures.succeedsWithFiberFinalizer);
    const fiber = try runtime.fork(program);

    try std.testing.expectEqual(@as(fx.FiberId, 1), fiber.id);
    try std.testing.expectEqual(fx.FiberStatus.pending, fiber.status());

    const exit = runtime.join(fiber);
    switch (exit) {
        .success => |value| try std.testing.expectEqual(@as(u32, 42), value),
        else => return error.Empty,
    }
    try std.testing.expectEqual(fx.FiberStatus.done, fiber.status());
    try std.testing.expectEqualStrings("success", fixtures.fiber_success_finalizer_probe.status);
}
test "fiber runtime propagates trace context into joined fibers" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var runtime = fx.FiberRuntime(fx.TestServices)
        .init(std.testing.allocator, &env.services)
        .withClock(&env.services.clock)
        .withTraceContext(303, 404)
        .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });
    defer runtime.deinit();

    const program = fx.Effect(void, fixtures.TestError, fx.TestServices)
        .fromFn(fixtures.logTraceContext)
        .requires(.{fx.Logger});
    const fiber = try runtime.fork(program);

    const exit = runtime.join(fiber);
    switch (exit) {
        .success => {},
        else => return error.Empty,
    }

    const entry = env.services.logger.structured_entries.items[0];
    try std.testing.expectEqual(@as(?u64, 303), entry.trace_id);
    try std.testing.expectEqual(@as(?u64, 404), entry.span_id);
}
test "fiber runtime preserves typed failure exits" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var runtime = fx.FiberRuntime(fx.TestServices)
        .init(std.testing.allocator, &env.services)
        .withClock(&env.services.clock)
        .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });
    defer runtime.deinit();

    const program = fx.Effect(u32, fixtures.TestError, fx.TestServices).fromFn(fixtures.failsWithFiberFinalizer);
    const fiber = try runtime.fork(program);
    const exit = runtime.join(fiber);

    switch (exit) {
        .failure => |err| try std.testing.expectEqual(error.Boom, err),
        else => return error.Empty,
    }
    try std.testing.expectEqual(fx.FiberStatus.failed, fiber.status());
    try std.testing.expectEqualStrings("Boom", fixtures.fiber_failure_finalizer_probe.status);
}
test "fiber runtime interrupts pending fibers" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var runtime = fx.FiberRuntime(fx.TestServices)
        .init(std.testing.allocator, &env.services)
        .withClock(&env.services.clock)
        .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });
    defer runtime.deinit();

    const program = fx.Effect(u32, fixtures.TestError, fx.TestServices).fromFn(fixtures.succeedsWithFiberFinalizer);
    const fiber = try runtime.fork(program);

    runtime.interrupt(fiber);

    const exit = runtime.join(fiber);
    switch (exit) {
        .interrupted => |id| try std.testing.expectEqual(fiber.id, id),
        else => return error.Empty,
    }
    try std.testing.expectEqual(fx.FiberStatus.interrupted, fiber.status());
}
test "fiber runtime emits causal events when forked and joined" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var runtime = fx.FiberRuntime(fx.TestServices)
        .init(std.testing.allocator, &env.services)
        .withClock(&env.services.clock)
        .withTraceContext(303, 404)
        .withCausalContext(.{ .development_task_id = 707, .agent_id = 808 })
        .withCausalStore(&store)
        .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });
    defer runtime.deinit();

    const program = fx.Effect(u32, fixtures.TestError, fx.TestServices).succeed(7);
    const fiber = try runtime.fork(program);

    const exit = runtime.join(fiber);
    switch (exit) {
        .success => |value| try std.testing.expectEqual(@as(u32, 7), value),
        else => return error.Empty,
    }

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    try causal.expectEventSequence(snapshot, &.{
        .fiber_forked,
        .scope_opened,
        .fiber_started,
        .effect_started,
        .effect_completed,
        .scope_closed,
        .fiber_joined,
    });
    try std.testing.expectEqual(fiber.id, snapshot.events[0].fiber_id.?);
    try std.testing.expectEqual(fiber.id, snapshot.events[2].fiber_id.?);
    try std.testing.expectEqual(fiber.id, snapshot.events[6].fiber_id.?);
    try std.testing.expectEqual(snapshot.events[0].run_id.?, snapshot.events[6].run_id.?);
    try std.testing.expectEqual(snapshot.events[0].scope_id.?, snapshot.events[1].scope_id.?);
    try std.testing.expectEqual(snapshot.events[0].scope_id.?, snapshot.events[2].scope_id.?);
    try std.testing.expectEqual(snapshot.events[0].scope_id.?, snapshot.events[6].scope_id.?);
    try std.testing.expectEqual(@as(?u64, 303), snapshot.events[0].trace_id);
    try std.testing.expectEqual(@as(?u64, 404), snapshot.events[2].span_id);
    try std.testing.expectEqual(@as(?u64, 707), snapshot.events[0].context.development_task_id);
    try std.testing.expectEqual(@as(?u64, 707), snapshot.events[2].context.development_task_id);
    try std.testing.expectEqual(@as(?u64, 808), snapshot.events[6].context.agent_id);
    try std.testing.expectEqual(@as(?u64, 303), snapshot.events[1].context.trace_id_low);
    try std.testing.expectEqualStrings("success", snapshot.events[6].status);

    const second_exit = runtime.join(fiber);
    switch (second_exit) {
        .success => |value| try std.testing.expectEqual(@as(u32, 7), value),
        else => return error.Empty,
    }
    var second_snapshot = try store.snapshot(std.testing.allocator);
    defer second_snapshot.deinit();
    try std.testing.expectEqual(snapshot.events.len, second_snapshot.events.len);
}
test "fiber runtime emits causal events when interrupted" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var runtime = fx.FiberRuntime(fx.TestServices)
        .init(std.testing.allocator, &env.services)
        .withClock(&env.services.clock)
        .withCausalStore(&store)
        .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });
    defer runtime.deinit();

    const program = fx.Effect(u32, fixtures.TestError, fx.TestServices).succeed(7);
    const fiber = try runtime.fork(program);

    runtime.interrupt(fiber);
    const exit = runtime.join(fiber);
    switch (exit) {
        .interrupted => |id| try std.testing.expectEqual(fiber.id, id),
        else => return error.Empty,
    }

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    try causal.expectEventSequence(snapshot, &.{
        .fiber_forked,
        .scope_opened,
        .fiber_interrupted,
        .scope_closed,
        .fiber_joined,
    });
    try std.testing.expectEqual(fiber.id, snapshot.events[2].fiber_id.?);
    try std.testing.expectEqualStrings("interrupted", snapshot.events[2].status);
    try std.testing.expectEqualStrings("interrupted", snapshot.events[4].status);
}
test "forkScoped leases children to the parent scope" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var runtime = fx.FiberRuntime(fx.TestServices)
        .init(std.testing.allocator, &env.services)
        .withClock(&env.services.clock)
        .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });
    defer runtime.deinit();

    var ctx = env.context();
    const program = fx.Effect(u32, fixtures.TestError, fx.TestServices).fromFn(fixtures.pendingScopedFiber);
    const fiber = try runtime.forkScoped(&ctx, program);

    env.scope.closeWithExit(.success);

    const exit = runtime.join(fiber);
    switch (exit) {
        .interrupted => |id| try std.testing.expectEqual(fiber.id, id),
        else => return error.Empty,
    }
    try std.testing.expectEqual(fx.FiberStatus.interrupted, fiber.status());
}
test "forkScoped parent close emits child fiber interruption causality" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var runtime = fx.FiberRuntime(fx.TestServices)
        .init(std.testing.allocator, &env.services)
        .withClock(&env.services.clock)
        .withCausalStore(&store)
        .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });
    defer runtime.deinit();

    var ctx = env.context();
    const program = fx.Effect(u32, fixtures.TestError, fx.TestServices).fromFn(fixtures.pendingScopedFiber);
    const fiber = try runtime.forkScoped(&ctx, program);

    env.scope.closeWithExit(.success);
    const exit = runtime.join(fiber);
    switch (exit) {
        .interrupted => |id| try std.testing.expectEqual(fiber.id, id),
        else => return error.Empty,
    }

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    try causal.expectEventSequence(snapshot, &.{
        .fiber_forked,
        .scope_opened,
        .fiber_interrupted,
        .scope_closed,
        .fiber_joined,
    });
    try std.testing.expectEqual(fiber.id, snapshot.events[2].fiber_id.?);
    try std.testing.expectEqualStrings("interrupted", snapshot.events[2].status);
}
test "fiber runtime validates dependency requirements before forking" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var runtime = fx.FiberRuntime(fx.TestServices)
        .init(std.testing.allocator, &env.services)
        .withClock(&env.services.clock)
        .provides(.{fx.Logger});
    defer runtime.deinit();

    const program = fx.Effect(u32, fixtures.TestError, fx.TestServices)
        .fromFn(fixtures.succeeds)
        .requires(.{ fx.Logger, fx.Config });

    try std.testing.expectError(error.MissingServiceRequirement, runtime.fork(program));
}
test "interrupted fiber exits format with fiber id" {
    const report = try fx.formatExit(
        std.testing.allocator,
        "load profile fiber",
        fx.Exit(u32, fixtures.TestError){ .interrupted = 22 },
    );
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "status: interrupted") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "fiber: 22") != null);
}
test "deferred completes once with structured exits" {
    var deferred = fx.Deferred(u32, fixtures.TestError).init();

    try std.testing.expectEqual(fx.DeferredAwaitState.pending, deferred.awaitState());
    try std.testing.expectError(error.DeferredNotCompleted, deferred.awaitExit());
    try deferred.completeSuccess(55);
    try std.testing.expectEqual(fx.DeferredAwaitState.ready, deferred.awaitState());
    try std.testing.expectError(error.DeferredAlreadyCompleted, deferred.completeFailure(error.Boom));

    const exit = try deferred.awaitExit();
    switch (exit) {
        .success => |value| try std.testing.expectEqual(@as(u32, 55), value),
        else => return error.Empty,
    }
}
test "queue preserves fifo order and reports empty or full" {
    var queue = fx.Queue(u32).bounded(std.testing.allocator, 2);
    defer queue.deinit();

    try std.testing.expectEqual(fx.QueueTakeState.empty, queue.takeState());
    try std.testing.expectEqual(fx.QueueOfferState.ready, queue.offerState());
    try std.testing.expectError(error.QueueEmpty, queue.take());
    try queue.offer(1);
    try std.testing.expectEqual(fx.QueueTakeState.ready, queue.takeState());
    try queue.offer(2);
    try std.testing.expectEqual(fx.QueueOfferState.backpressured, queue.offerState());
    try std.testing.expectError(error.QueueFull, queue.offer(3));

    try std.testing.expectEqual(@as(u32, 1), try queue.take());
    try std.testing.expectEqual(@as(u32, 2), try queue.take());
    try std.testing.expectError(error.QueueEmpty, queue.take());
}
test "queue shutdown rejects offers and drains buffered items" {
    var queue = fx.Queue(u32).bounded(std.testing.allocator, 2);
    defer queue.deinit();

    try queue.offer(1);
    queue.shutdown();

    try std.testing.expect(queue.isShutdown());
    try std.testing.expectEqual(fx.QueueOfferState.shutdown, queue.offerState());
    try std.testing.expectEqual(fx.QueueTakeState.ready, queue.takeState());
    try std.testing.expectError(error.QueueShutdown, queue.offer(2));
    try std.testing.expectEqual(@as(u32, 1), try queue.take());
    try std.testing.expectEqual(fx.QueueTakeState.shutdown, queue.takeState());
    try std.testing.expectError(error.QueueShutdown, queue.take());
}
test "deterministic fibers run queue producer consumer workflow" {
    const QueueWorkflowError = std.mem.Allocator.Error || fx.FiberPrimitiveError;
    const QueueWorkflowEnv = struct {
        queue: fx.Queue(u32),

        pub fn service(self: *@This(), comptime Service: type) *Service {
            if (Service == fx.Queue(u32)) return &self.queue;
            return fx.serviceNotFound(@This(), Service);
        }
    };
    const Workflow = struct {
        fn produce(ctx: *fx.Context(QueueWorkflowEnv)) QueueWorkflowError!usize {
            const queue = ctx.service(fx.Queue(u32));
            try queue.offer(1);
            try queue.offer(2);
            queue.shutdown();
            return queue.len();
        }

        fn consume(ctx: *fx.Context(QueueWorkflowEnv)) QueueWorkflowError!u32 {
            const queue = ctx.service(fx.Queue(u32));
            const first = try queue.take();
            const second = try queue.take();
            _ = queue.take() catch |err| switch (err) {
                error.QueueShutdown => return first + second,
                else => return err,
            };
            return error.QueueEmpty;
        }
    };

    var env = QueueWorkflowEnv{ .queue = fx.Queue(u32).bounded(std.testing.allocator, 2) };
    defer env.queue.deinit();

    var runtime = fx.FiberRuntime(QueueWorkflowEnv)
        .init(std.testing.allocator, &env)
        .provides(.{fx.Queue(u32)});
    defer runtime.deinit();

    const Producer = fx.Effect(usize, QueueWorkflowError, QueueWorkflowEnv).fromFn(Workflow.produce);
    const Consumer = fx.Effect(u32, QueueWorkflowError, QueueWorkflowEnv).fromFn(Workflow.consume);

    const producer = try runtime.fork(Producer);
    try fx.testing.expectFiberStatus(producer, .pending);

    const producer_exit = runtime.join(producer);
    switch (producer_exit) {
        .success => |value| try std.testing.expectEqual(@as(usize, 2), value),
        else => return error.Empty,
    }
    try fx.testing.expectFiberStatus(producer, .done);
    try fx.testing.expectQueueLen(&env.queue, 2);
    try fx.testing.expectQueueShutdown(&env.queue, true);

    const consumer = try runtime.fork(Consumer);
    const consumer_exit = runtime.join(consumer);
    switch (consumer_exit) {
        .success => |value| try std.testing.expectEqual(@as(u32, 3), value),
        else => return error.Empty,
    }
    try fx.testing.expectFiberStatus(consumer, .done);
    try fx.testing.expectQueueLen(&env.queue, 0);
}
test "semaphore acquires and releases bounded permits" {
    var semaphore = fx.Semaphore.init(2);

    try std.testing.expectEqual(@as(usize, 2), semaphore.available());
    try std.testing.expectEqual(fx.SemaphoreAcquireState.ready, semaphore.acquireState(2));
    try semaphore.acquire(2);
    try std.testing.expectEqual(@as(usize, 0), semaphore.available());
    try std.testing.expectEqual(fx.SemaphoreAcquireState.unavailable, semaphore.acquireState(1));
    try std.testing.expectError(error.SemaphoreUnavailable, semaphore.acquire(1));
    try semaphore.release(1);
    try std.testing.expectEqual(@as(usize, 1), semaphore.available());
    try std.testing.expectError(error.SemaphoreOverRelease, semaphore.release(2));
}
test "semaphore scoped permits release on scope close" {
    var semaphore = fx.Semaphore.init(2);
    var scope = fx.Scope.init(std.testing.allocator);
    defer scope.deinit();

    try semaphore.acquireScoped(&scope, 2);
    try std.testing.expectEqual(@as(usize, 0), semaphore.available());
    try std.testing.expectError(error.SemaphoreUnavailable, semaphore.acquire(1));

    scope.close();

    try std.testing.expectEqual(@as(usize, 2), semaphore.available());
    try std.testing.expectError(error.SemaphoreOverRelease, semaphore.release(1));
}
