//! zigeffect-zio — real zio backend.
//!
//! `ZioAsyncBackendState` implements the core `zigeffect` `AsyncBackend` vtable
//! on top of zio (https://github.com/lalinsky/zio) v0.14.0, which provides
//! stackful coroutines + a full `std.Io` implementation over io_uring/epoll/kqueue.
//!
//! STATUS: the vtable is implemented (Track E). `blocking_sleep` parks the
//! running coroutine on the real event loop (D1); the pull-model methods
//! (`suspend_runtime`/`register_io_wait`/`wake`/`complete_io`/`interrupt`/
//! `poll_wake`) are a real registration + wake-queue, and `schedule_timer` spawns
//! a REAL zio timer coroutine that enqueues a wake on fire. `advance_time` is the
//! single deterministic-specific concept — a no-op under zio, since real time
//! advances itself. All backend state is spinlock-guarded (thread-safe).
//!
//! The core engine (`packages/zigeffect`) stays zio-free and is the deterministic
//! reference; `LocalAsyncBackendState` must produce the same *structural* causal
//! trace as this backend for the same program (see
//! docs/superpowers/specs/2026-06-20-zigeffect-zio-backend-design.md).

const std = @import("std");
const fx = @import("zigeffect");
const zio = @import("zio");

/// The productized deep integration: a `fx.FiberExecutor` backed by real zio
/// coroutines. Configure it on a `FiberRuntime` via `withExecutor`, and an
/// ordinary `Effect.fork` spawns the fiber's effect as a stackful zio coroutine
/// at fork time; `join` awaits it. The engine core stays zio-free — all zio
/// lives here behind the executor vtable. The same effect program is therefore
/// deterministically debuggable (no executor) and really concurrent (this
/// executor), producing the same causal structure either way (for joined fibers
/// — see `fx.FiberExecutor`).
///
/// Usage contract:
///   - A live zio runtime must be active on the calling thread (i.e. you are
///     running under `zio.Runtime.init` / inside a zio task). `fork` calls
///     `zio.spawn`, which panics if invoked with no current executor.
///   - The zio runtime must be SINGLE-EXECUTOR (the default `.exact(1)`). The
///     engine's `CausalStore` (and typically the services the fibers touch) is
///     not thread-safe — it relies on cooperative single-threaded scheduling so
///     that `CausalStore.record` runs atomically between yields (see the
///     invariant on `CausalStore.record`). A multi-executor runtime would run
///     fibers in true parallel and race on the store.
///   - The zio runtime must outlive the `FiberRuntime`: a fiber forked but never
///     joined is awaited at the `FiberRuntime`'s deinit, which requires the
///     backing runtime to still be able to complete it.
pub const ZioFiberExecutor = struct {
    allocator: std.mem.Allocator,

    const HandleBox = struct {
        handle: zio.JoinHandle(void),
    };

    // zio.spawn needs a concrete fn; this thunk runs the type-erased fiber job.
    fn jobThunk(job: fx.FiberJob) void {
        job.run(job.context);
    }

    fn spawn(context: ?*anyopaque, job: fx.FiberJob) ?*anyopaque {
        const self: *ZioFiberExecutor = @ptrCast(@alignCast(context.?));
        const box = self.allocator.create(HandleBox) catch return null;
        box.handle = zio.spawn(jobThunk, .{job}) catch {
            self.allocator.destroy(box);
            return null; // engine falls back to synchronous execution on join
        };
        return box;
    }

    fn join(context: ?*anyopaque, handle: *anyopaque) void {
        _ = context;
        const box: *HandleBox = @ptrCast(@alignCast(handle));
        _ = box.handle.join();
    }

    fn destroy(context: ?*anyopaque, handle: *anyopaque) void {
        const self: *ZioFiberExecutor = @ptrCast(@alignCast(context.?));
        const box: *HandleBox = @ptrCast(@alignCast(handle));
        self.allocator.destroy(box);
    }

    /// M7.9 — interrupt a spawned coroutine via zio's `JoinHandle.cancel`,
    /// which requests cancellation, waits for the coroutine to unwind (its
    /// `zio.sleep` / IO wait returns `error.Canceled`), and releases the
    /// awaitable. After this returns the job has terminated; a subsequent
    /// `join` is a cached no-op and `destroy` frees the box.
    fn interruptJob(context: ?*anyopaque, handle: *anyopaque) void {
        _ = context;
        const box: *HandleBox = @ptrCast(@alignCast(handle));
        box.handle.cancel();
    }

    /// M4.0 — wait for the first of `handles` to complete, returning its index.
    /// Implemented by polling each coroutine's non-blocking `hasResult()` and
    /// cooperatively yielding between rounds so the spawned coroutines make
    /// progress. (zio has a more efficient `selectAwaitables` over a runtime
    /// slice, but it is not re-exported from the package root; poll+yield uses
    /// only the exported `hasResult` + `yield` and is correct under the
    /// cooperative single executor. Swap to selectAwaitables if/when upstream
    /// exports it — see docs/superpowers/upstream/zio-selectAwaitables.patch.)
    fn waitAny(context: ?*anyopaque, handles: []const *anyopaque) usize {
        _ = context;
        while (true) {
            for (handles, 0..) |h, i| {
                const box: *HandleBox = @ptrCast(@alignCast(h));
                if (box.handle.hasResult()) return i;
            }
            // Park briefly (not a busy `yield`, which would starve the event
            // loop's timer/IO servicing and make racing sleeps fire late). A
            // short sleep lets the loop advance the racers' timers/IO, then we
            // re-poll. ~100µs keeps latency low. (selectAwaitables would park
            // exactly on the futures — poll-park is the fallback while it is
            // unexported; see the upstream patch note.)
            zio.sleep(zio.Duration.fromMicroseconds(100)) catch {};
        }
    }

    const vtable = fx.FiberExecutor.VTable{
        .spawn = spawn,
        .join = join,
        .destroy = destroy,
        .interrupt = interruptJob,
        .waitAny = waitAny,
    };

    pub fn executor(self: *ZioFiberExecutor) fx.FiberExecutor {
        return .{ .context = self, .vtable = &vtable };
    }
};

/// Z1: a delay that suspends on a REAL zio coroutine timer, emitting the same
/// causal trace shape as the deterministic `fx.recordDelaySuspensionScenario`.
/// `zio.sleep` actually parks the coroutine on the event loop (io_uring/epoll/
/// kqueue) and resumes it when the timer fires — no virtual clock. The emitted
/// causal graph must compare STRUCTURALLY EQUAL to the deterministic trace
/// (same event kinds + cause edges + fiber net state), which is the Stage-1 gate.
pub fn recordZioDelayScenario(store: *fx.CausalStore, due_ms: u64) !void {
    const run_id = store.nextRunId();
    const scope_id = store.nextScopeId();
    const fiber_id: u64 = 1;
    const sid: u64 = 1;

    const run_started = try store.record(.{ .kind = .run_started, .run_id = run_id, .status = "started", .label = "zio-delay-suspension", .type_name = "ZioDelayScenario" });
    const scope_opened = try store.record(.{ .kind = .scope_opened, .run_id = run_id, .scope_id = scope_id, .parent_id = run_started, .status = "opened", .label = "delay scope" });
    const fiber_forked = try store.record(.{ .kind = .fiber_forked, .run_id = run_id, .scope_id = scope_id, .fiber_id = fiber_id, .parent_id = scope_opened, .status = "pending", .label = "delay fiber" });
    const fiber_started = try store.record(.{ .kind = .fiber_started, .run_id = run_id, .scope_id = scope_id, .fiber_id = fiber_id, .parent_id = fiber_forked, .status = "running", .label = "delay fiber" });
    const delay_effect = try store.record(.{ .kind = .effect_started, .run_id = run_id, .scope_id = scope_id, .fiber_id = fiber_id, .parent_id = fiber_started, .status = "started", .label = "delay", .type_name = "DelayEffect" });
    const suspended = try store.record(.{ .kind = .fiber_suspended, .run_id = run_id, .scope_id = scope_id, .fiber_id = fiber_id, .parent_id = fiber_started, .cause_event_id = delay_effect, .schedule_id = sid, .status = "pending", .label = "fiber suspended on timer", .type_name = "Suspension" });
    const scheduled = try store.record(.{ .kind = .timer_scheduled, .run_id = run_id, .scope_id = scope_id, .fiber_id = fiber_id, .parent_id = suspended, .cause_event_id = suspended, .schedule_id = sid, .status = "pending", .label = "delay", .type_name = "Timer" });

    // Real suspension: park this coroutine on the zio event loop for due_ms.
    try zio.sleep(zio.Duration.fromMilliseconds(due_ms));

    const fired = try store.record(.{ .kind = .timer_fired, .run_id = run_id, .scope_id = scope_id, .fiber_id = fiber_id, .parent_id = scheduled, .cause_event_id = scheduled, .schedule_id = sid, .status = "ready", .label = "timer fired", .type_name = "Timer" });
    _ = try store.record(.{ .kind = .fiber_resumed, .run_id = run_id, .scope_id = scope_id, .fiber_id = fiber_id, .parent_id = suspended, .cause_event_id = fired, .schedule_id = sid, .status = "running", .label = "fiber resumed", .type_name = "Suspension" });
    const scope_closed = try store.record(.{ .kind = .scope_closed, .run_id = run_id, .scope_id = scope_id, .parent_id = run_started, .status = "closed", .label = "delay scope" });
    _ = try store.record(.{ .kind = .fiber_joined, .run_id = run_id, .scope_id = scope_id, .fiber_id = fiber_id, .parent_id = scope_closed, .status = "success", .label = "delay fiber" });
    _ = try store.record(.{ .kind = .exit_recorded, .run_id = run_id, .parent_id = run_started, .status = "success", .label = "zio-delay-suspension" });
}

/// Z3: real structured cancellation. A parent spawns a child coroutine in a
/// zio.Group; the child suspends on a long sleep; the parent closes the scope
/// and cancels the group, which interrupts the child's real suspension. The
/// child's fiber_interrupted is caused by the parent's scope_closed — the
/// structured-concurrency invariant, proven against real zio cancellation.
const Z3Ctx = struct {
    store: *fx.CausalStore,
    run_id: u64,
    scope_id: u64,
    fiber_id: u64,
    fiber_forked_id: u64,
    scope_closed_id: u64 = 0,
    record_err: ?anyerror = null,
};

fn z3Child(ctx: *Z3Ctx) void {
    const started = ctx.store.record(.{ .kind = .fiber_started, .run_id = ctx.run_id, .scope_id = ctx.scope_id, .fiber_id = ctx.fiber_id, .parent_id = ctx.fiber_forked_id, .status = "running", .label = "child fiber" }) catch |e| {
        ctx.record_err = e;
        return;
    };
    const suspended = ctx.store.record(.{ .kind = .fiber_suspended, .run_id = ctx.run_id, .scope_id = ctx.scope_id, .fiber_id = ctx.fiber_id, .parent_id = started, .cause_event_id = started, .schedule_id = 1, .status = "pending", .label = "child suspended", .type_name = "Suspension" }) catch |e| {
        ctx.record_err = e;
        return;
    };

    // Real suspension that will be interrupted by the parent's group.cancel().
    zio.sleep(zio.Duration.fromMilliseconds(10_000)) catch {
        _ = ctx.store.record(.{ .kind = .fiber_interrupted, .run_id = ctx.run_id, .scope_id = ctx.scope_id, .fiber_id = ctx.fiber_id, .parent_id = suspended, .cause_event_id = ctx.scope_closed_id, .status = "interrupted", .label = "child interrupted by scope close" }) catch |e| {
            ctx.record_err = e;
        };
        return;
    };
    // Not reached in this scenario (the sleep is always canceled).
    _ = ctx.store.record(.{ .kind = .fiber_joined, .run_id = ctx.run_id, .scope_id = ctx.scope_id, .fiber_id = ctx.fiber_id, .parent_id = suspended, .status = "success", .label = "child fiber" }) catch {};
}

pub fn recordZioCancellationScenario(store: *fx.CausalStore) !void {
    const run_id = store.nextRunId();
    const scope_id = store.nextScopeId();
    const fiber_id: u64 = 1;

    const run_started = try store.record(.{ .kind = .run_started, .run_id = run_id, .status = "started", .label = "zio-cancellation", .type_name = "ZioCancellationScenario" });
    const scope_opened = try store.record(.{ .kind = .scope_opened, .run_id = run_id, .scope_id = scope_id, .parent_id = run_started, .status = "opened", .label = "parent scope" });
    const fiber_forked = try store.record(.{ .kind = .fiber_forked, .run_id = run_id, .scope_id = scope_id, .fiber_id = fiber_id, .parent_id = scope_opened, .status = "pending", .label = "child fiber" });

    var ctx = Z3Ctx{ .store = store, .run_id = run_id, .scope_id = scope_id, .fiber_id = fiber_id, .fiber_forked_id = fiber_forked };

    var group: zio.Group = .init;
    try group.spawn(z3Child, .{&ctx});

    // Let the child run to its suspend point, then close the scope and cancel.
    try zio.sleep(zio.Duration.fromMilliseconds(5));
    const scope_closed = try store.record(.{ .kind = .scope_closed, .run_id = run_id, .scope_id = scope_id, .parent_id = run_started, .status = "closed", .label = "parent scope" });
    ctx.scope_closed_id = scope_closed;
    group.cancel();
    group.wait() catch {};

    if (ctx.record_err) |err| return err;
    _ = try store.record(.{ .kind = .exit_recorded, .run_id = run_id, .parent_id = run_started, .status = "interrupted", .label = "zio-cancellation" });
}

/// Z2: real async IO wait. A fiber blocks on a real loopback-socket read, which
/// parks the coroutine on the zio event loop until a client writes; the engine
/// emits io_wait_started before the read and io_completed + fiber_resumed after.
/// This is the IO-wait counterpart of Z1's timer suspension.
fn z2Client(addr: zio.net.IpAddress) void {
    zio.sleep(zio.Duration.fromMilliseconds(5)) catch return;
    const stream = addr.connect(.{}) catch return;
    defer stream.close();
    _ = stream.write("x", .none) catch return;
}

pub fn recordZioIoScenario(store: *fx.CausalStore) !void {
    const addr = try zio.net.IpAddress.parseIp4("127.0.0.1", 19191);
    const server = try addr.listen(.{});
    defer server.close();

    const run_id = store.nextRunId();
    const scope_id = store.nextScopeId();
    const fiber_id: u64 = 1;

    const run_started = try store.record(.{ .kind = .run_started, .run_id = run_id, .status = "started", .label = "zio-io-wait", .type_name = "ZioIoScenario" });
    const scope_opened = try store.record(.{ .kind = .scope_opened, .run_id = run_id, .scope_id = scope_id, .parent_id = run_started, .status = "opened", .label = "io scope" });
    const fiber_forked = try store.record(.{ .kind = .fiber_forked, .run_id = run_id, .scope_id = scope_id, .fiber_id = fiber_id, .parent_id = scope_opened, .status = "pending", .label = "io fiber" });
    const fiber_started = try store.record(.{ .kind = .fiber_started, .run_id = run_id, .scope_id = scope_id, .fiber_id = fiber_id, .parent_id = fiber_forked, .status = "running", .label = "io fiber" });
    const io_effect = try store.record(.{ .kind = .effect_started, .run_id = run_id, .scope_id = scope_id, .fiber_id = fiber_id, .parent_id = fiber_started, .status = "started", .label = "socket read", .type_name = "IoEffect" });

    var group: zio.Group = .init;
    try group.spawn(z2Client, .{addr});

    const io_wait = try store.record(.{ .kind = .io_wait_started, .run_id = run_id, .scope_id = scope_id, .fiber_id = fiber_id, .parent_id = fiber_started, .cause_event_id = io_effect, .schedule_id = 1, .status = "pending", .label = "socket read", .type_name = "IoWait" });

    // Real async IO: accept + read park the coroutine on the event loop until data.
    const stream = try server.accept(.{});
    defer stream.close();
    var buf: [16]u8 = undefined;
    const n = try stream.read(&buf, .none);

    const io_done = try store.record(.{ .kind = .io_completed, .run_id = run_id, .scope_id = scope_id, .fiber_id = fiber_id, .parent_id = io_wait, .cause_event_id = io_wait, .schedule_id = 1, .status = "ready", .label = "socket readable", .type_name = "IoWait" });
    _ = try store.record(.{ .kind = .fiber_resumed, .run_id = run_id, .scope_id = scope_id, .fiber_id = fiber_id, .parent_id = io_wait, .cause_event_id = io_done, .schedule_id = 1, .status = "running", .label = "io fiber resumed", .type_name = "Suspension" });
    const scope_closed = try store.record(.{ .kind = .scope_closed, .run_id = run_id, .scope_id = scope_id, .parent_id = run_started, .status = "closed", .label = "io scope" });
    _ = try store.record(.{ .kind = .fiber_joined, .run_id = run_id, .scope_id = scope_id, .fiber_id = fiber_id, .parent_id = scope_closed, .status = "success", .label = "io fiber" });
    _ = try store.record(.{ .kind = .exit_recorded, .run_id = run_id, .parent_id = run_started, .status = "success", .label = "zio-io-wait" });

    group.wait() catch {};
    if (n == 0) return error.NoDataRead;
}

/// Z3b: real concurrent coordination. A consumer coroutine parks on an empty
/// zio.Channel; a producer coroutine sends a value, waking it. Two fibers
/// genuinely interleave on one cooperative executor; the consumer's fiber_resumed
/// is caused by the producer's send — cross-fiber coordination causality.
const Z3bCtx = struct {
    store: *fx.CausalStore,
    run_id: u64,
    scope_id: u64,
    channel: *zio.Channel(i32),
    producer_forked: u64,
    consumer_forked: u64,
    send_event_id: u64 = 0,
    received: i32 = -1,
    err: ?anyerror = null,
};

fn z3bConsumer(ctx: *Z3bCtx) void {
    const started = ctx.store.record(.{ .kind = .fiber_started, .run_id = ctx.run_id, .scope_id = ctx.scope_id, .fiber_id = 2, .parent_id = ctx.consumer_forked, .status = "running", .label = "consumer fiber" }) catch |e| {
        ctx.err = e;
        return;
    };
    const suspended = ctx.store.record(.{ .kind = .fiber_suspended, .run_id = ctx.run_id, .scope_id = ctx.scope_id, .fiber_id = 2, .parent_id = started, .cause_event_id = started, .schedule_id = 2, .status = "pending", .label = "consumer awaiting channel", .type_name = "Suspension" }) catch |e| {
        ctx.err = e;
        return;
    };
    ctx.received = ctx.channel.receive() catch |e| {
        ctx.err = e;
        return;
    };
    _ = ctx.store.record(.{ .kind = .fiber_resumed, .run_id = ctx.run_id, .scope_id = ctx.scope_id, .fiber_id = 2, .parent_id = suspended, .cause_event_id = ctx.send_event_id, .schedule_id = 2, .status = "running", .label = "consumer resumed by send", .type_name = "Suspension" }) catch |e| {
        ctx.err = e;
        return;
    };
    _ = ctx.store.record(.{ .kind = .fiber_joined, .run_id = ctx.run_id, .scope_id = ctx.scope_id, .fiber_id = 2, .parent_id = suspended, .status = "success", .label = "consumer fiber" }) catch |e| {
        ctx.err = e;
    };
}

fn z3bProducer(ctx: *Z3bCtx) void {
    zio.sleep(zio.Duration.fromMilliseconds(5)) catch {};
    const started = ctx.store.record(.{ .kind = .fiber_started, .run_id = ctx.run_id, .scope_id = ctx.scope_id, .fiber_id = 1, .parent_id = ctx.producer_forked, .status = "running", .label = "producer fiber" }) catch |e| {
        ctx.err = e;
        return;
    };
    const send_event = ctx.store.record(.{ .kind = .effect_started, .run_id = ctx.run_id, .scope_id = ctx.scope_id, .fiber_id = 1, .parent_id = started, .status = "started", .label = "channel send", .type_name = "ChannelSend" }) catch |e| {
        ctx.err = e;
        return;
    };
    ctx.send_event_id = send_event;
    ctx.channel.send(42) catch |e| {
        ctx.err = e;
        return;
    };
    _ = ctx.store.record(.{ .kind = .fiber_joined, .run_id = ctx.run_id, .scope_id = ctx.scope_id, .fiber_id = 1, .parent_id = started, .status = "success", .label = "producer fiber" }) catch |e| {
        ctx.err = e;
    };
}

pub fn recordZioCoordinationScenario(store: *fx.CausalStore) !void {
    const run_id = store.nextRunId();
    const scope_id = store.nextScopeId();

    const run_started = try store.record(.{ .kind = .run_started, .run_id = run_id, .status = "started", .label = "zio-coordination", .type_name = "ZioCoordinationScenario" });
    const scope_opened = try store.record(.{ .kind = .scope_opened, .run_id = run_id, .scope_id = scope_id, .parent_id = run_started, .status = "opened", .label = "coordination scope" });
    const producer_forked = try store.record(.{ .kind = .fiber_forked, .run_id = run_id, .scope_id = scope_id, .fiber_id = 1, .parent_id = scope_opened, .status = "pending", .label = "producer fiber" });
    const consumer_forked = try store.record(.{ .kind = .fiber_forked, .run_id = run_id, .scope_id = scope_id, .fiber_id = 2, .parent_id = scope_opened, .status = "pending", .label = "consumer fiber" });

    var buffer: [1]i32 = undefined;
    var channel = zio.Channel(i32).init(&buffer);
    var ctx = Z3bCtx{ .store = store, .run_id = run_id, .scope_id = scope_id, .channel = &channel, .producer_forked = producer_forked, .consumer_forked = consumer_forked };

    var group: zio.Group = .init;
    try group.spawn(z3bConsumer, .{&ctx});
    try group.spawn(z3bProducer, .{&ctx});
    try group.wait();

    if (ctx.err) |err| return err;

    _ = try store.record(.{ .kind = .scope_closed, .run_id = run_id, .scope_id = scope_id, .parent_id = run_started, .status = "closed", .label = "coordination scope" });
    _ = try store.record(.{ .kind = .exit_recorded, .run_id = run_id, .parent_id = run_started, .status = "success", .label = "zio-coordination" });

    if (ctx.received != 42) return error.WrongValue;
}

/// D2: engine fibers run as real zio coroutines and interleave. Each fiber body
/// uses the core SuspensionCoordinator.delay; under zio the bodies are spawned as
/// coroutines (a short-delay fiber resumes before a long-delay one, so the events
/// genuinely reorder), while under the deterministic backend the same bodies run
/// sequentially. The structural invariants (event-kind multiset + per-fiber net
/// state) are identical — proving the H5 equivalence holds under real reordering.
fn d2FiberBody(allocator: std.mem.Allocator, store: *fx.CausalStore, backend: fx.AsyncBackend, run_id: u64, scope_id: u64, fiber_id: u64, forked_id: u64, delay_ms: u64) !void {
    const started = try store.record(.{ .kind = .fiber_started, .run_id = run_id, .scope_id = scope_id, .fiber_id = fiber_id, .parent_id = forked_id, .status = "running", .label = "worker fiber" });
    var coord = fx.SuspensionCoordinator.init(allocator, store, backend);
    defer coord.deinit();
    try coord.delay(.{ .fiber_id = fiber_id, .scope_id = scope_id, .run_id = run_id, .started_event_id = started, .caused_by_event_id = started, .due_time_ms = delay_ms });
    _ = try store.record(.{ .kind = .fiber_joined, .run_id = run_id, .scope_id = scope_id, .fiber_id = fiber_id, .parent_id = started, .status = "success", .label = "worker fiber" });
}

const D2Ctx = struct {
    allocator: std.mem.Allocator,
    store: *fx.CausalStore,
    backend: fx.AsyncBackend,
    run_id: u64,
    scope_id: u64,
    fiber_id: u64,
    forked_id: u64,
    delay_ms: u64,
    err: ?anyerror = null,
};

fn d2Coroutine(ctx: *D2Ctx) void {
    d2FiberBody(ctx.allocator, ctx.store, ctx.backend, ctx.run_id, ctx.scope_id, ctx.fiber_id, ctx.forked_id, ctx.delay_ms) catch |e| {
        ctx.err = e;
    };
}

fn d2Prologue(store: *fx.CausalStore) !struct { run_id: u64, scope_id: u64, forked1: u64, forked2: u64 } {
    const run_id = store.nextRunId();
    const scope_id = store.nextScopeId();
    const run_started = try store.record(.{ .kind = .run_started, .run_id = run_id, .status = "started", .label = "two-fiber-delay", .type_name = "TwoFiberDelay" });
    _ = try store.record(.{ .kind = .scope_opened, .run_id = run_id, .scope_id = scope_id, .parent_id = run_started, .status = "opened", .label = "worker scope" });
    const forked1 = try store.record(.{ .kind = .fiber_forked, .run_id = run_id, .scope_id = scope_id, .fiber_id = 1, .status = "pending", .label = "worker fiber" });
    const forked2 = try store.record(.{ .kind = .fiber_forked, .run_id = run_id, .scope_id = scope_id, .fiber_id = 2, .status = "pending", .label = "worker fiber" });
    return .{ .run_id = run_id, .scope_id = scope_id, .forked1 = forked1, .forked2 = forked2 };
}

/// Two engine fibers run sequentially on the deterministic backend.
pub fn recordDetTwoFiberDelay(allocator: std.mem.Allocator, store: *fx.CausalStore) !void {
    var backend_state = fx.LocalAsyncBackendState.init(allocator, .{});
    defer backend_state.deinit();
    const p = try d2Prologue(store);
    try d2FiberBody(allocator, store, backend_state.backend(), p.run_id, p.scope_id, 1, p.forked1, 50);
    try d2FiberBody(allocator, store, backend_state.backend(), p.run_id, p.scope_id, 2, p.forked2, 1);
    _ = try store.record(.{ .kind = .scope_closed, .run_id = p.run_id, .scope_id = p.scope_id, .status = "closed", .label = "worker scope" });
    _ = try store.record(.{ .kind = .exit_recorded, .run_id = p.run_id, .status = "success", .label = "two-fiber-delay" });
}

/// The SAME two engine fibers spawned as real zio coroutines — they interleave.
pub fn recordZioTwoFiberDelay(allocator: std.mem.Allocator, store: *fx.CausalStore) !void {
    var backend_state = ZioAsyncBackendState.init(allocator);
    defer backend_state.deinit();
    const backend = backend_state.backend();
    const p = try d2Prologue(store);
    // Fiber 1 sleeps far longer than fiber 2, so fiber 2 completes (resumes)
    // while fiber 1 is still parked — robust proof of interleaving without a
    // tight timing race.
    var ctx1 = D2Ctx{ .allocator = allocator, .store = store, .backend = backend, .run_id = p.run_id, .scope_id = p.scope_id, .fiber_id = 1, .forked_id = p.forked1, .delay_ms = 50 };
    var ctx2 = D2Ctx{ .allocator = allocator, .store = store, .backend = backend, .run_id = p.run_id, .scope_id = p.scope_id, .fiber_id = 2, .forked_id = p.forked2, .delay_ms = 1 };
    var group: zio.Group = .init;
    try group.spawn(d2Coroutine, .{&ctx1});
    try group.spawn(d2Coroutine, .{&ctx2});
    // Always inspect child errors, even if wait() itself reports one.
    group.wait() catch {};
    if (ctx1.err) |e| return e;
    if (ctx2.err) |e| return e;
    _ = try store.record(.{ .kind = .scope_closed, .run_id = p.run_id, .scope_id = p.scope_id, .status = "closed", .label = "worker scope" });
    _ = try store.record(.{ .kind = .exit_recorded, .run_id = p.run_id, .status = "success", .label = "two-fiber-delay" });
}

/// Hardening (H1 regression): a fiber parked inside the engine's
/// SuspensionCoordinator.delay is cancelled mid-wait. delay()'s blockingSleep
/// (a real zio.sleep) is interrupted and propagates error.Interrupted; delay()
/// must record a fiber_interrupted and NOT fabricate a timer_fired/fiber_resumed.
const DelayCancelCtx = struct {
    allocator: std.mem.Allocator,
    store: *fx.CausalStore,
    backend: fx.AsyncBackend,
    run_id: u64,
    scope_id: u64,
    fiber_id: u64,
    forked_id: u64,
    err: ?anyerror = null,
};

fn delayCancelChild(ctx: *DelayCancelCtx) void {
    const started = ctx.store.record(.{ .kind = .fiber_started, .run_id = ctx.run_id, .scope_id = ctx.scope_id, .fiber_id = ctx.fiber_id, .parent_id = ctx.forked_id, .status = "running", .label = "delay-cancel fiber" }) catch |e| {
        ctx.err = e;
        return;
    };
    var coord = fx.SuspensionCoordinator.init(ctx.allocator, ctx.store, ctx.backend);
    defer coord.deinit();
    coord.delay(.{ .fiber_id = ctx.fiber_id, .scope_id = ctx.scope_id, .run_id = ctx.run_id, .started_event_id = started, .caused_by_event_id = started, .due_time_ms = 10_000 }) catch |e| {
        // Expected: delay() already recorded fiber_interrupted and returned Interrupted.
        if (e != error.Interrupted) ctx.err = e;
        return;
    };
    // Unreachable in this scenario — the delay is always cancelled.
    _ = ctx.store.record(.{ .kind = .fiber_joined, .run_id = ctx.run_id, .scope_id = ctx.scope_id, .fiber_id = ctx.fiber_id, .parent_id = started, .status = "success", .label = "delay-cancel fiber" }) catch {};
}

pub fn recordZioDelayCancellation(allocator: std.mem.Allocator, store: *fx.CausalStore) !void {
    var backend_state = ZioAsyncBackendState.init(allocator);
    defer backend_state.deinit();
    const run_id = store.nextRunId();
    const scope_id = store.nextScopeId();
    const run_started = try store.record(.{ .kind = .run_started, .run_id = run_id, .status = "started", .label = "zio-delay-cancellation", .type_name = "ZioDelayCancellation" });
    const scope_opened = try store.record(.{ .kind = .scope_opened, .run_id = run_id, .scope_id = scope_id, .parent_id = run_started, .status = "opened", .label = "scope" });
    const forked = try store.record(.{ .kind = .fiber_forked, .run_id = run_id, .scope_id = scope_id, .fiber_id = 1, .parent_id = scope_opened, .status = "pending", .label = "delay-cancel fiber" });

    var ctx = DelayCancelCtx{ .allocator = allocator, .store = store, .backend = backend_state.backend(), .run_id = run_id, .scope_id = scope_id, .fiber_id = 1, .forked_id = forked };
    var group: zio.Group = .init;
    try group.spawn(delayCancelChild, .{&ctx});
    try zio.sleep(zio.Duration.fromMilliseconds(5));
    group.cancel();
    group.wait() catch {};
    if (ctx.err) |e| return e;

    _ = try store.record(.{ .kind = .scope_closed, .run_id = run_id, .scope_id = scope_id, .parent_id = run_started, .status = "closed", .label = "scope" });
    _ = try store.record(.{ .kind = .exit_recorded, .run_id = run_id, .parent_id = run_started, .status = "interrupted", .label = "zio-delay-cancellation" });
}

fn kindCount(events: []fx.CausalEvent, kind: fx.CausalEventKind) usize {
    var count: usize = 0;
    for (events) |event| {
        if (event.kind == kind) count += 1;
    }
    return count;
}

pub const AsyncBackend = fx.AsyncBackend;
pub const AsyncBackendError = fx.AsyncBackendError;
pub const AsyncBackendSnapshot = fx.AsyncBackendSnapshot;
pub const BackendSuspendRequest = fx.BackendSuspendRequest;
pub const BackendWakeRequest = fx.BackendWakeRequest;
pub const BackendTimerRequest = fx.BackendTimerRequest;
pub const BackendInterruptRequest = fx.BackendInterruptRequest;
pub const BackendIoWaitRequest = fx.BackendIoWaitRequest;
pub const BackendIoCompleteRequest = fx.BackendIoCompleteRequest;
pub const BackendWakeEvent = fx.BackendWakeEvent;

pub const SpinLock = fx.SpinLock;
pub const Suspension = fx.Suspension;
pub const AsyncWaitKind = fx.AsyncWaitKind;
pub const AsyncWaitStatus = fx.AsyncWaitStatus;
pub const AsyncIoWaitKind = fx.AsyncIoWaitKind;
pub const AsyncIoInterest = fx.AsyncIoInterest;

// Track E — a faithful registration + wake-queue implementation of the
// AsyncBackend pull-model vtable on zio. The deterministic backend drives the
// engine's cluster/workflow subsystems with a virtual clock (advance_time fires
// due timers, poll_wake drains them). zio drives them with REAL state: an effect
// registers a suspension (suspend_runtime / register_io_wait / schedule_timer);
// it is woken by an explicit `wake` / `complete_io`, by a real zio timer
// (schedule_timer), or `interrupt`; poll_wake drains the resulting wake queue.
// `advance_time` is the only deterministic-specific concept — a no-op here
// (real time advances itself). All state is spinlock-guarded (thread-safe).
const PendingSuspension = struct {
    suspension: Suspension,
    wait_kind: AsyncWaitKind,
    workflow_id: ?u64 = null,
    execution_id: ?u64 = null,
    due_time_ms: ?u64 = null,
    io_kind: ?AsyncIoWaitKind = null,
    interest: ?AsyncIoInterest = null,
    descriptor: ?i64 = null,
};

pub const ZioAsyncBackendState = struct {
    allocator: std.mem.Allocator,
    mutex: SpinLock = .{},
    pending: std.ArrayList(PendingSuspension) = .empty,
    wakes: std.ArrayList(BackendWakeEvent) = .empty,
    timer_group: zio.Group = .init,
    completed_count: usize = 0,
    interrupted_count: usize = 0,
    duplicate_wake_count: usize = 0,

    pub fn init(allocator: std.mem.Allocator) ZioAsyncBackendState {
        return .{ .allocator = allocator };
    }

    /// MUST be called while the zio runtime is still alive (so pending timer
    /// coroutines can be cancelled + drained before their state is freed).
    pub fn deinit(self: *ZioAsyncBackendState) void {
        self.timer_group.cancel();
        self.timer_group.wait() catch {};
        self.pending.deinit(self.allocator);
        self.wakes.deinit(self.allocator);
    }

    fn register(self: *ZioAsyncBackendState, entry: PendingSuspension) AsyncBackendError!void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.pending.append(self.allocator, entry) catch return error.OutOfMemory;
    }

    /// Move a registered suspension to the wake queue with the given outcome.
    fn resolve(self: *ZioAsyncBackendState, id: u64, wait_kind: AsyncWaitKind, status: AsyncWaitStatus, reason: []const u8) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        for (self.pending.items, 0..) |p, i| {
            if (p.suspension.id == id) {
                _ = self.pending.orderedRemove(i);
                self.wakes.append(self.allocator, .{
                    .suspension = p.suspension,
                    .wait_kind = wait_kind,
                    .status = status,
                    .reason = reason,
                    .workflow_id = p.workflow_id,
                    .execution_id = p.execution_id,
                    .due_time_ms = p.due_time_ms,
                    .io_kind = p.io_kind,
                    .interest = p.interest,
                    .descriptor = p.descriptor,
                }) catch {};
                if (status == .interrupted) {
                    self.interrupted_count += 1;
                } else {
                    self.completed_count += 1;
                }
                return;
            }
        }
        self.duplicate_wake_count += 1; // wake for an unknown/already-resolved id
    }

    fn nextWake(self: *ZioAsyncBackendState) ?BackendWakeEvent {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.wakes.items.len == 0) return null;
        return self.wakes.orderedRemove(0);
    }

    pub fn backend(self: *ZioAsyncBackendState) AsyncBackend {
        return .{
            .context = self,
            .capabilities = fx.runtime.asyncLocalBackend(),
            .vtable = &zio_vtable,
        };
    }
};

/// Real zio timer coroutine: sleep for `due_ms`, then enqueue a `.ready` wake for
/// the suspension. Cancellation (group.cancel at deinit) makes the sleep return
/// an error and we skip the wake.
fn zioTimerFire(state: *ZioAsyncBackendState, suspension: Suspension, due_ms: u64) void {
    zio.sleep(zio.Duration.fromMilliseconds(due_ms)) catch return;
    state.resolve(suspension.id, .timer, .ready, "timer fired");
}

const zio_vtable = AsyncBackend.VTable{
    .suspend_runtime = suspendRuntime,
    .wake = wake,
    .schedule_timer = scheduleTimer,
    .interrupt = interrupt,
    .register_io_wait = registerIoWait,
    .complete_io = completeIo,
    .poll_wake = pollWake,
    .advance_time = advanceTime,
    .snapshot = snapshot,
    .blocking_sleep = blockingSleep,
};

/// The real wait: park the running coroutine on the zio event loop for `ms`.
/// This is what makes the engine's `SuspensionCoordinator.delay` suspend for
/// real when driven by this backend — the same core code the deterministic
/// backend runs virtually. If the coroutine is cancelled while parked (e.g. a
/// parent group.cancel()), propagate it as `error.Interrupted` so `delay()`
/// records a fiber_interrupted rather than fabricating a successful resume.
fn blockingSleep(context: ?*anyopaque, ms: u64) AsyncBackendError!void {
    _ = context;
    zio.sleep(zio.Duration.fromMilliseconds(ms)) catch {
        return error.Interrupted;
    };
}

/// Register a runtime suspension keyed by `request.suspension.id`. It stays
/// parked until `wake` / `interrupt` resolves it (then `poll_wake` drains it).
fn suspendRuntime(context: ?*anyopaque, request: BackendSuspendRequest) AsyncBackendError!void {
    const state: *ZioAsyncBackendState = @ptrCast(@alignCast(context.?));
    try state.register(.{
        .suspension = request.suspension,
        .wait_kind = .runtime,
        .workflow_id = request.workflow_id,
        .execution_id = request.execution_id,
    });
}

/// Resolve the suspension under `request.suspension_id` as ready.
fn wake(context: ?*anyopaque, request: BackendWakeRequest) AsyncBackendError!void {
    const state: *ZioAsyncBackendState = @ptrCast(@alignCast(context.?));
    state.resolve(request.suspension_id, .runtime, .ready, request.reason);
}

/// Register a timer suspension AND spawn a REAL zio timer coroutine that wakes
/// it after `due_time_ms`. The engine emits `timer_scheduled` here; the wake is
/// drained by `poll_wake` once the real timer fires.
fn scheduleTimer(context: ?*anyopaque, request: BackendTimerRequest) AsyncBackendError!void {
    const state: *ZioAsyncBackendState = @ptrCast(@alignCast(context.?));
    try state.register(.{
        .suspension = request.suspension,
        .wait_kind = .timer,
        .due_time_ms = request.due_time_ms,
        .workflow_id = request.workflow_id,
        .execution_id = request.execution_id,
    });
    // Best-effort: needs a live zio runtime on this thread. If spawn fails the
    // registration remains and an explicit `wake` can still resolve it.
    state.timer_group.spawn(zioTimerFire, .{ state, request.suspension, request.due_time_ms }) catch {};
}

/// Resolve the suspension under `request.target_id` as interrupted.
fn interrupt(context: ?*anyopaque, request: BackendInterruptRequest) AsyncBackendError!void {
    const state: *ZioAsyncBackendState = @ptrCast(@alignCast(context.?));
    state.resolve(request.target_id, .cancellation, .interrupted, request.reason);
}

/// Register an async IO suspension keyed by `request.suspension.id`. Resolved by
/// `complete_io` (or `interrupt`).
fn registerIoWait(context: ?*anyopaque, request: BackendIoWaitRequest) AsyncBackendError!void {
    const state: *ZioAsyncBackendState = @ptrCast(@alignCast(context.?));
    const wait_kind: AsyncWaitKind = switch (request.io_kind) {
        .network => .network,
        .file => .file,
    };
    try state.register(.{
        .suspension = request.suspension,
        .wait_kind = wait_kind,
        .io_kind = request.io_kind,
        .interest = request.interest,
        .descriptor = request.descriptor,
        .workflow_id = request.workflow_id,
        .execution_id = request.execution_id,
    });
}

/// Resolve an outstanding IO wait as ready.
fn completeIo(context: ?*anyopaque, request: BackendIoCompleteRequest) AsyncBackendError!void {
    const state: *ZioAsyncBackendState = @ptrCast(@alignCast(context.?));
    const wait_kind: AsyncWaitKind = switch (request.io_kind) {
        .network => .network,
        .file => .file,
    };
    state.resolve(request.suspension_id, wait_kind, .ready, request.reason);
}

/// Drain the next resolved wake (or null). The engine emits `timer_fired` /
/// `io_completed` / `fiber_resumed` (or `fiber_interrupted`) from the event.
fn pollWake(context: ?*anyopaque) AsyncBackendError!?BackendWakeEvent {
    const state: *ZioAsyncBackendState = @ptrCast(@alignCast(context.?));
    return state.nextWake();
}

/// Deterministic-backend concept only: under zio, time is real, so advancing a
/// virtual clock is a no-op. (Real timers fire via the event loop; see
/// scheduleTimer.)
fn advanceTime(context: ?*anyopaque, now_ms: u64) AsyncBackendError!usize {
    _ = context;
    _ = now_ms;
    return 0;
}

/// Report parked/ready/interrupted counts for tests and the workbench.
fn snapshot(context: ?*anyopaque) AsyncBackendSnapshot {
    const state: *ZioAsyncBackendState = @ptrCast(@alignCast(context.?));
    state.mutex.lock();
    defer state.mutex.unlock();
    return .{
        .pending_count = state.pending.items.len,
        .ready_count = state.wakes.items.len,
        .completed_count = state.completed_count,
        .interrupted_count = state.interrupted_count,
        .duplicate_wake_count = state.duplicate_wake_count,
    };
}

test "hardening: a delay cancelled mid-wait records fiber_interrupted, never a fabricated resume" {
    const allocator = std.testing.allocator;
    var rt = try zio.Runtime.init(allocator, .{});
    defer rt.deinit();

    var store = fx.CausalStore.init(allocator);
    defer store.deinit();
    try recordZioDelayCancellation(allocator, &store);

    var snap = try store.snapshot(allocator);
    defer snap.deinit();

    // The cancelled delay recorded an interruption and did NOT fabricate success.
    try std.testing.expectEqual(@as(usize, 1), kindCount(snap.events, .fiber_suspended));
    try std.testing.expectEqual(@as(usize, 1), kindCount(snap.events, .fiber_interrupted));
    try std.testing.expectEqual(@as(usize, 0), kindCount(snap.events, .fiber_resumed));
    try std.testing.expectEqual(@as(usize, 0), kindCount(snap.events, .timer_fired));

    // The hang detector must not fire: an interrupted fiber is resolved, not hung.
    var findings = try store.findings(allocator);
    defer findings.deinit();
    for (findings.items) |finding| {
        try std.testing.expect(finding.kind != .fiber_suspended_without_resume);
    }
}

test "D2: engine fibers run as real interleaving zio coroutines; structurally equal to the deterministic sequential run" {
    const allocator = std.testing.allocator;
    var rt = try zio.Runtime.init(allocator, .{});
    defer rt.deinit();

    var zio_store = fx.CausalStore.init(allocator);
    defer zio_store.deinit();
    try recordZioTwoFiberDelay(allocator, &zio_store);

    var det_store = fx.CausalStore.init(allocator);
    defer det_store.deinit();
    try recordDetTwoFiberDelay(allocator, &det_store);

    var zio_snap = try zio_store.snapshot(allocator);
    defer zio_snap.deinit();
    var det_snap = try det_store.snapshot(allocator);
    defer det_snap.deinit();

    // Structural equivalence despite real concurrency reordering the events,
    // via the engine structural-equivalence primitive (event kinds + cause-edge
    // kind pairs + per-fiber net states, ignoring ids and ordering).
    try std.testing.expect(try fx.causalStructurallyEquivalent(allocator, det_snap.events, zio_snap.events));

    // Prove zio genuinely interleaved (robustly, no tight timing race): the
    // short-delay fiber (2, 1ms) resumes while the long-delay fiber (1, 50ms) is
    // still parked, so fiber 2's resume precedes fiber 1's.
    var f1_resume: u64 = 0;
    var f2_resume: u64 = 0;
    for (zio_snap.events) |event| {
        if (event.kind != .fiber_resumed) continue;
        if (event.fiber_id == 1) f1_resume = event.id;
        if (event.fiber_id == 2) f2_resume = event.id;
    }
    try std.testing.expect(f1_resume != 0 and f2_resume != 0);
    try std.testing.expect(f2_resume < f1_resume);

    // Prove the deterministic run was sequential: fiber 1 fully resumed before fiber 2 started.
    var f1_resumed: u64 = 0;
    var f2_started: u64 = std.math.maxInt(u64);
    for (det_snap.events) |event| {
        if (event.kind == .fiber_resumed and event.fiber_id == 1) f1_resumed = event.id;
        if (event.kind == .fiber_started and event.fiber_id == 2) f2_started = event.id;
    }
    try std.testing.expect(f1_resumed < f2_started);
}

// --- Productization: an ordinary Effect.fork runs as a real zio coroutine ---

const ForkError = error{ Boom, OutOfMemory };

// Two effect bodies whose only zio dependency is the sleep — the kind of code a
// user writes. Under the zio executor they run as coroutines and interleave;
// without it they run synchronously on the main task, sequentially.
fn forkBodyLong(ctx: *fx.Context(fx.TestServices)) ForkError!u32 {
    _ = ctx;
    zio.sleep(zio.Duration.fromMilliseconds(50)) catch {};
    return 1;
}
fn forkBodyShort(ctx: *fx.Context(fx.TestServices)) ForkError!u32 {
    _ = ctx;
    zio.sleep(zio.Duration.fromMilliseconds(1)) catch {};
    return 2;
}

// Race bodies: a 10-SECOND loser and a 1ms winner. If the race genuinely
// short-circuits (cancels the loser), the test finishes in ~1ms; if not, it
// hangs ~10s. Fast completion IS the proof.
fn raceSlowBody(ctx: *fx.Context(fx.TestServices)) ForkError!u32 {
    _ = ctx;
    zio.sleep(zio.Duration.fromMilliseconds(10_000)) catch {};
    return 1;
}
fn raceFastBody(ctx: *fx.Context(fx.TestServices)) ForkError!u32 {
    _ = ctx;
    zio.sleep(zio.Duration.fromMilliseconds(1)) catch {};
    return 2;
}
fn raceMidBody(ctx: *fx.Context(fx.TestServices)) ForkError!u32 {
    _ = ctx;
    zio.sleep(zio.Duration.fromMilliseconds(5_000)) catch {};
    return 3;
}

fn raceRuntime(env: *fx.TestEnv, exec: *ZioFiberExecutor) fx.Runtime(fx.TestServices) {
    return fx.Runtime(fx.TestServices)
        .init(std.testing.allocator, &env.services)
        .withClock(&env.services.clock)
        .withExecutor(exec.executor())
        .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });
}

test "M4.4 raceFirst on zio: the fast branch wins, the 10s loser is cancelled (short-circuit, no 10s hang)" {
    const allocator = std.testing.allocator;
    var rt = try zio.Runtime.init(allocator, .{});
    defer rt.deinit();
    var env = try fx.TestEnv.init(allocator);
    defer env.deinit();
    var exec = ZioFiberExecutor{ .allocator = allocator };
    var runtime = raceRuntime(&env, &exec);

    const E = fx.Effect(u32, ForkError, fx.TestServices);
    const program = E.fromFn(raceSlowBody).raceFirst(E.fromFn(raceFastBody));
    const result = try runtime.run(program);
    // The 1ms branch wins; the 10s loser was interrupted (otherwise this test
    // would take ~10 seconds).
    try std.testing.expectEqual(@as(u32, 2), result);
}

fn raceSlowFailBody(ctx: *fx.Context(fx.TestServices)) ForkError!u32 {
    _ = ctx;
    zio.sleep(zio.Duration.fromMilliseconds(10_000)) catch {};
    return error.Boom;
}
fn raceFastFailBody(ctx: *fx.Context(fx.TestServices)) ForkError!u32 {
    _ = ctx;
    zio.sleep(zio.Duration.fromMilliseconds(1)) catch {};
    return error.Boom;
}

test "M4.3 race on zio: a fast FAILURE does not win — race waits for the slow SUCCESS" {
    const allocator = std.testing.allocator;
    var rt = try zio.Runtime.init(allocator, .{});
    defer rt.deinit();
    var env = try fx.TestEnv.init(allocator);
    defer env.deinit();
    var exec = ZioFiberExecutor{ .allocator = allocator };
    var runtime = raceRuntime(&env, &exec);

    const E = fx.Effect(u32, ForkError, fx.TestServices);
    // Fast branch FAILS at 1ms; slow branch SUCCEEDS at... use the short success
    // (1ms→2) as the "slow success" relative to an instant failure path. To make
    // the prefer-success behaviour unambiguous, pit a fast-FAIL vs a real success.
    const program = E.fromFn(raceFastFailBody).race(E.fromFn(raceFastBody));
    // raceFastFail returns error.Boom (fast), raceFast returns 2. race must
    // prefer the success, so the result is 2.
    const result = try runtime.run(program);
    try std.testing.expectEqual(@as(u32, 2), result);
}

test "M4.6 both on zio: a fast FAILURE fail-fasts, cancelling the 10s branch (no 10s hang)" {
    const allocator = std.testing.allocator;
    var rt = try zio.Runtime.init(allocator, .{});
    defer rt.deinit();
    var env = try fx.TestEnv.init(allocator);
    defer env.deinit();
    var exec = ZioFiberExecutor{ .allocator = allocator };
    var runtime = raceRuntime(&env, &exec);

    const E = fx.Effect(u32, ForkError, fx.TestServices);
    // Left fails fast (1ms); right would take 10s. `both` must fail-fast and
    // cancel the right — the test finishes in ~1s, not 10s.
    const program = E.fromFn(raceFastFailBody).both(E.fromFn(raceSlowBody));
    try std.testing.expectError(error.Boom, runtime.run(program));
}

test "M4.5 raceAll on zio: fastest of three wins, the slow two are cancelled" {
    const allocator = std.testing.allocator;
    var rt = try zio.Runtime.init(allocator, .{});
    defer rt.deinit();
    var env = try fx.TestEnv.init(allocator);
    defer env.deinit();
    var exec = ZioFiberExecutor{ .allocator = allocator };
    var runtime = raceRuntime(&env, &exec);

    const E = fx.Effect(u32, ForkError, fx.TestServices);
    const items = [_]E{ E.fromFn(raceSlowBody), E.fromFn(raceMidBody), E.fromFn(raceFastBody) };
    const program = fx.raceAll(E, ForkError, fx.TestServices, &items);
    const result = try runtime.run(program);
    // The 1ms branch wins; the 5s and 10s branches were interrupted.
    try std.testing.expectEqual(@as(u32, 2), result);
}

fn expectSuccess(exit: fx.Exit(u32, ForkError), expected: u32) !void {
    switch (exit) {
        .success => |value| try std.testing.expectEqual(expected, value),
        else => return error.UnexpectedExit,
    }
}

fn runTwoForkProgram(allocator: std.mem.Allocator, maybe_executor: ?fx.FiberExecutor, store: *fx.CausalStore) !void {
    var env = try fx.TestEnv.init(allocator);
    defer env.deinit();

    var runtime = fx.FiberRuntime(fx.TestServices)
        .init(allocator, &env.services)
        .withClock(&env.services.clock)
        .withCausalStore(store)
        .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });
    if (maybe_executor) |e| runtime = runtime.withExecutor(e);
    defer runtime.deinit();

    const long = fx.Effect(u32, ForkError, fx.TestServices).fromFn(forkBodyLong);
    const short = fx.Effect(u32, ForkError, fx.TestServices).fromFn(forkBodyShort);
    const f1 = try runtime.fork(long);
    const f2 = try runtime.fork(short);
    try expectSuccess(runtime.join(f1), 1);
    try expectSuccess(runtime.join(f2), 2);
}

// True iff both fibers STARTED before either's scope CLOSED — only possible when
// they ran concurrently. In a sequential run, fiber 1 closes before fiber 2 starts.
fn bothStartedBeforeEitherClosed(events: []fx.CausalEvent) bool {
    var max_started: u64 = 0;
    var min_closed: u64 = std.math.maxInt(u64);
    for (events) |event| {
        if (event.kind == .fiber_started and event.id > max_started) max_started = event.id;
        if (event.kind == .scope_closed and event.id < min_closed) min_closed = event.id;
    }
    return max_started != 0 and min_closed != std.math.maxInt(u64) and max_started < min_closed;
}

// M7.9 — a coroutine that parks on a long sleep, then (if not cancelled) marks
// itself completed. Cancellation makes zio.sleep return error.Canceled, so the
// body returns early and `completed` stays false.
const CancelProbe = struct {
    started: bool = false,
    completed: bool = false,
    fn run(raw: ?*anyopaque) void {
        const self: *CancelProbe = @ptrCast(@alignCast(raw.?));
        self.started = true;
        zio.sleep(zio.Duration.fromMilliseconds(10_000)) catch {
            return; // cancelled mid-sleep — never reach completed
        };
        self.completed = true;
    }
};

test "M7.9: ZioFiberExecutor.interrupt cancels a parked coroutine (no 10s wait)" {
    const allocator = std.testing.allocator;
    var rt = try zio.Runtime.init(allocator, .{});
    defer rt.deinit();

    var exec = ZioFiberExecutor{ .allocator = allocator };
    const e = exec.executor();
    try std.testing.expect(e.canInterrupt());

    var probe = CancelProbe{};
    const handle = e.vtable.spawn(e.context, .{ .context = &probe, .run = CancelProbe.run }).?;

    // Let the coroutine start and park on the 10s sleep.
    try zio.sleep(zio.Duration.fromMilliseconds(5));
    try std.testing.expect(probe.started);
    try std.testing.expect(!probe.completed);

    // Interrupt — must terminate the coroutine WITHOUT waiting the full 10s.
    // (If interrupt didn't work, this test would hang for 10 seconds.)
    try std.testing.expect(e.tryInterrupt(handle));
    e.vtable.destroy(e.context, handle);

    // The coroutine started but never completed — it was cancelled mid-sleep.
    try std.testing.expect(probe.started);
    try std.testing.expect(!probe.completed);
}

// M14.5 (zio variant) — the closed agent loop on REAL concurrency. A genuinely
// wedged coroutine (parked on a 10s sleep) is interrupted under policy via the
// real FiberExecutor.interrupt, and the runtime verifies the fix actually took
// (the coroutine unwound without completing). This is the deterministic M14.5
// demo with the injected action swapped for a real cancel.

const WedgeProbe = struct {
    started: bool = false,
    finished: bool = false, // set on ANY exit (normal return OR cancel unwind)
    completed: bool = false, // set ONLY if the sleep ran to completion
    fn run(raw: ?*anyopaque) void {
        const self: *WedgeProbe = @ptrCast(@alignCast(raw.?));
        self.started = true;
        defer self.finished = true; // runs even when the sleep is cancelled
        zio.sleep(zio.Duration.fromMilliseconds(10_000)) catch return;
        self.completed = true;
    }
};

const ZioLoopContext = struct {
    executor: fx.FiberExecutor,
    handle: *anyopaque,
    probe: *WedgeProbe,
    action_ran: bool = false,

    /// The remediation ACTION: interrupt the wedged coroutine for real.
    fn action(ctx: ?*anyopaque, request: fx.RemediationRequest) bool {
        const self: *ZioLoopContext = @ptrCast(@alignCast(ctx.?));
        _ = request;
        self.action_ran = true;
        return self.executor.tryInterrupt(self.handle);
    }

    /// The VERIFIER: the fix is proven iff the coroutine actually UNWOUND
    /// (finished) WITHOUT completing — i.e. it was cancelled, not still parked
    /// and not allowed to run its full duration. A still-parked coroutine has
    /// finished == false, so this discriminates a real cancel from a no-op.
    fn verify(ctx: ?*anyopaque, request: fx.RemediationRequest) bool {
        _ = request;
        const self: *ZioLoopContext = @ptrCast(@alignCast(ctx.?));
        return self.probe.started and self.probe.finished and !self.probe.completed;
    }
};

fn appliedStatusZio(snap: *fx.CausalSnapshot) ?[]const u8 {
    for (snap.events) |e| if (e.kind == .remediation_applied) return e.status;
    return null;
}

test "M14.5-zio: a wedged coroutine is interrupted under policy and the fix is verified → applied=true" {
    const allocator = std.testing.allocator;
    var rt = try zio.Runtime.init(allocator, .{});
    defer rt.deinit();

    var exec = ZioFiberExecutor{ .allocator = allocator };
    const e = exec.executor();

    var probe = WedgeProbe{};
    const handle = e.vtable.spawn(e.context, .{ .context = &probe, .run = WedgeProbe.run }).?;
    // Let the coroutine wedge on its 10s sleep.
    try zio.sleep(zio.Duration.fromMilliseconds(5));
    try std.testing.expect(probe.started and !probe.finished and !probe.completed);

    // The agent's remediation: interrupt the wedged fiber, under an
    // operator-enabled policy (gate ON, interrupt opted in).
    var audit_store = fx.CausalStore.init(allocator);
    defer audit_store.deinit();
    var ctx = ZioLoopContext{ .executor = e, .handle = handle, .probe = &probe };
    const engine = (fx.PolicyEngine{}).withApplyEnabled(true).withKindPolicy(.interrupt, .auto_approve);
    const boundary = fx.ApplyBoundary{
        .engine = engine,
        .action = ZioLoopContext.action,
        .verify = ZioLoopContext.verify,
        .action_context = &ctx,
        .verify_context = &ctx,
    };

    const result = boundary.apply(&audit_store, .{ .kind = .interrupt, .target_fiber_id = 1, .reason = "fiber wedged on 10s sleep" });
    e.vtable.destroy(e.context, handle);

    // The loop closed on REAL concurrency: the coroutine was actually cancelled
    // (unwound without completing) and the runtime proved it → applied=true.
    try std.testing.expect(ctx.action_ran);
    try std.testing.expect(probe.started and probe.finished and !probe.completed);
    try std.testing.expectEqual(fx.ApplyOutcome.applied, result.outcome);
    try std.testing.expect(result.isApplied());

    var snap = try audit_store.snapshot(allocator);
    defer snap.deinit();
    try std.testing.expectEqualStrings("applied", appliedStatusZio(&snap).?);
}

test "M14.5-zio: with the policy gate OFF the wedged coroutine is NOT touched (declined, record-only)" {
    const allocator = std.testing.allocator;
    var rt = try zio.Runtime.init(allocator, .{});
    defer rt.deinit();

    var exec = ZioFiberExecutor{ .allocator = allocator };
    const e = exec.executor();

    var probe = WedgeProbe{};
    const handle = e.vtable.spawn(e.context, .{ .context = &probe, .run = WedgeProbe.run }).?;
    try zio.sleep(zio.Duration.fromMilliseconds(5));
    try std.testing.expect(probe.started and !probe.finished);

    var audit_store = fx.CausalStore.init(allocator);
    defer audit_store.deinit();
    var ctx = ZioLoopContext{ .executor = e, .handle = handle, .probe = &probe };
    // Default engine — master gate OFF (record-only posture).
    const boundary = fx.ApplyBoundary{
        .engine = fx.PolicyEngine{},
        .action = ZioLoopContext.action,
        .verify = ZioLoopContext.verify,
        .action_context = &ctx,
        .verify_context = &ctx,
    };

    const result = boundary.apply(&audit_store, .{ .kind = .interrupt, .target_fiber_id = 1, .reason = "fiber wedged" });

    // Declined: the action NEVER ran, so the coroutine is untouched (still parked).
    try std.testing.expectEqual(fx.ApplyOutcome.declined, result.outcome);
    try std.testing.expect(!ctx.action_ran);
    try std.testing.expect(!probe.finished); // still wedged — the runtime did nothing

    // Clean up the still-parked coroutine.
    _ = e.tryInterrupt(handle);
    e.vtable.destroy(e.context, handle);

    var snap = try audit_store.snapshot(allocator);
    defer snap.deinit();
    try std.testing.expectEqualStrings("not_applied", appliedStatusZio(&snap).?);
}

test "productization: an ordinary Effect.fork runs as a real interleaving zio coroutine via FiberExecutor" {
    const allocator = std.testing.allocator;
    var rt = try zio.Runtime.init(allocator, .{});
    defer rt.deinit();

    // Default path: no executor — fibers run synchronously, sequentially.
    var det_store = fx.CausalStore.init(allocator);
    defer det_store.deinit();
    try runTwoForkProgram(allocator, null, &det_store);

    // Productized path: the real zio executor — each fork spawns a coroutine.
    var exec = ZioFiberExecutor{ .allocator = allocator };
    var zio_store = fx.CausalStore.init(allocator);
    defer zio_store.deinit();
    try runTwoForkProgram(allocator, exec.executor(), &zio_store);

    var det_snap = try det_store.snapshot(allocator);
    defer det_snap.deinit();
    var zio_snap = try zio_store.snapshot(allocator);
    defer zio_snap.deinit();

    // Same program shape regardless of execution strategy (the whole point: the
    // deterministic run is a faithful model of the real concurrent run).
    try std.testing.expect(try fx.causalStructurallyEquivalent(allocator, det_snap.events, zio_snap.events));

    // The zio run genuinely interleaved; the deterministic run did not.
    try std.testing.expect(bothStartedBeforeEitherClosed(zio_snap.events));
    try std.testing.expect(!bothStartedBeforeEitherClosed(det_snap.events));
}

// M4.9 — the Track 4 parallel primitives (forEachPar/zipPar) on the REAL zio
// executor must produce a structurally-equivalent causal trace to the
// deterministic sequential run. (The in-core test only used a synchronous
// ProbeExec; this exercises the genuine coroutine executor — the gap the
// Track 4 adversarial review flagged as Finding #4.)

const RecordingParBody = struct {
    fn run(item: u32, ctx: *fx.Context(fx.TestServices)) ForkError!u32 {
        _ = ctx.recordCausal(.{ .kind = .metric_recorded, .label = "forEachPar body ran", .status = "ready" });
        return item * 2;
    }
};

fn runForEachParProgram(allocator: std.mem.Allocator, maybe_executor: ?fx.FiberExecutor, store: *fx.CausalStore) ![]u32 {
    var env = try fx.TestEnv.init(allocator);
    defer env.deinit();
    var runtime = fx.Runtime(fx.TestServices)
        .init(allocator, &env.services)
        .withClock(&env.services.clock)
        .withCausalStore(store)
        .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });
    if (maybe_executor) |e| runtime = runtime.withExecutor(e);

    const items = [_]u32{ 1, 2, 3 };
    const program = fx.forEachPar(u32, u32, ForkError, fx.TestServices, &items, RecordingParBody.run);
    return runtime.run(program);
}

test "M4.9: forEachPar on the real zio executor is structurally equivalent to the deterministic sequential run" {
    const allocator = std.testing.allocator;
    var rt = try zio.Runtime.init(allocator, .{});
    defer rt.deinit();

    // Deterministic: no executor — bodies run sequentially inline.
    var det_store = fx.CausalStore.init(allocator);
    defer det_store.deinit();
    const det = try runForEachParProgram(allocator, null, &det_store);
    defer allocator.free(det);

    // Real zio executor: each body spawns a real coroutine.
    var exec = ZioFiberExecutor{ .allocator = allocator };
    var zio_store = fx.CausalStore.init(allocator);
    defer zio_store.deinit();
    const par = try runForEachParProgram(allocator, exec.executor(), &zio_store);
    defer allocator.free(par);

    // Same results.
    try std.testing.expectEqualSlices(u32, det, par);

    var det_snap = try det_store.snapshot(allocator);
    defer det_snap.deinit();
    var zio_snap = try zio_store.snapshot(allocator);
    defer zio_snap.deinit();

    // Non-vacuity: each run recorded one metric_recorded per item (3).
    var det_metrics: usize = 0;
    var zio_metrics: usize = 0;
    for (det_snap.events) |e| if (e.kind == .metric_recorded) {
        det_metrics += 1;
    };
    for (zio_snap.events) |e| if (e.kind == .metric_recorded) {
        zio_metrics += 1;
    };
    try std.testing.expectEqual(@as(usize, 3), det_metrics);
    try std.testing.expectEqual(@as(usize, 3), zio_metrics);

    // The load-bearing claim, now witnessed on a REAL coroutine executor:
    // parallel and sequential traversals are structurally equivalent.
    try std.testing.expect(try fx.causalStructurallyEquivalent(allocator, det_snap.events, zio_snap.events));
}

test "D1: the SAME engine delay scenario runs on the zio backend (real wait) and the deterministic backend (virtual) with identical causal traces" {
    const allocator = std.testing.allocator;
    var rt = try zio.Runtime.init(allocator, .{});
    defer rt.deinit();

    // Same core function (fx.recordDelaySuspensionScenario), zio backend: the
    // engine's SuspensionCoordinator.delay calls backend.blockingSleep, which on
    // this backend is a real zio.sleep — the coroutine actually parks.
    var zio_state = ZioAsyncBackendState.init(allocator);
    defer zio_state.deinit();
    var zio_store = fx.CausalStore.init(allocator);
    defer zio_store.deinit();
    _ = try fx.recordDelaySuspensionScenario(allocator, &zio_store, zio_state.backend(), 2);

    // Same core function, deterministic backend: blockingSleep advances a virtual
    // clock instantly. No hand-written zio scenario — the engine drives both.
    var det_state = fx.LocalAsyncBackendState.init(allocator, .{});
    defer det_state.deinit();
    var det_store = fx.CausalStore.init(allocator);
    defer det_store.deinit();
    _ = try fx.recordDelaySuspensionScenario(allocator, &det_store, det_state.backend(), 2);

    var zio_snap = try zio_store.snapshot(allocator);
    defer zio_snap.deinit();
    var det_snap = try det_store.snapshot(allocator);
    defer det_snap.deinit();

    // Identical causal structure via the engine structural-equivalence primitive
    // (same invariants as `causal-compare --structural`: event kinds, cause-edge
    // kind pairs, fiber net states): same engine code path, only the wait differed.
    try std.testing.expect(try fx.causalStructurallyEquivalent(allocator, det_snap.events, zio_snap.events));
}

test "Z1: zio-backed delay suspends for real and yields a structurally-equal causal trace" {
    const allocator = std.testing.allocator;
    var rt = try zio.Runtime.init(allocator, .{});
    defer rt.deinit();

    // Real suspension under zio (the coroutine parks on the event loop).
    var zio_store = fx.CausalStore.init(allocator);
    defer zio_store.deinit();
    try recordZioDelayScenario(&zio_store, 2);

    // Deterministic reference (virtual clock).
    var det_store = fx.CausalStore.init(allocator);
    defer det_store.deinit();
    var backend = fx.LocalAsyncBackendState.init(allocator, .{});
    defer backend.deinit();
    _ = try fx.recordDelaySuspensionScenario(allocator, &det_store, backend.backend(), 2);

    var zio_snap = try zio_store.snapshot(allocator);
    defer zio_snap.deinit();
    var det_snap = try det_store.snapshot(allocator);
    defer det_snap.deinit();

    // Structural equivalence: same event-kind multiset, including the load-bearing
    // suspend/timer/resume kinds that prove a real suspend->resume happened.
    try std.testing.expectEqual(det_snap.events.len, zio_snap.events.len);
    try std.testing.expectEqual(kindCount(det_snap.events, .fiber_suspended), kindCount(zio_snap.events, .fiber_suspended));
    try std.testing.expectEqual(kindCount(det_snap.events, .timer_scheduled), kindCount(zio_snap.events, .timer_scheduled));
    try std.testing.expectEqual(kindCount(det_snap.events, .timer_fired), kindCount(zio_snap.events, .timer_fired));
    try std.testing.expectEqual(kindCount(det_snap.events, .fiber_resumed), kindCount(zio_snap.events, .fiber_resumed));
    try std.testing.expectEqual(kindCount(det_snap.events, .fiber_joined), kindCount(zio_snap.events, .fiber_joined));
    try std.testing.expectEqual(@as(usize, 1), kindCount(zio_snap.events, .fiber_suspended));
    try std.testing.expectEqual(@as(usize, 1), kindCount(zio_snap.events, .fiber_resumed));
}

test "Z3b: two coroutines interleave over a zio.Channel; consumer resume is caused by producer send" {
    const allocator = std.testing.allocator;
    var rt = try zio.Runtime.init(allocator, .{});
    defer rt.deinit();

    var store = fx.CausalStore.init(allocator);
    defer store.deinit();
    try recordZioCoordinationScenario(&store);

    var snap = try store.snapshot(allocator);
    defer snap.deinit();

    // both fibers reached a terminal join; the consumer parked and resumed
    try std.testing.expectEqual(@as(usize, 2), kindCount(snap.events, .fiber_joined));
    try std.testing.expectEqual(@as(usize, 1), kindCount(snap.events, .fiber_suspended));
    try std.testing.expectEqual(@as(usize, 1), kindCount(snap.events, .fiber_resumed));

    // cross-fiber coordination: the consumer's resume is caused by the producer's send effect
    var send_effect_id: ?u64 = null;
    var resume_cause: ?u64 = null;
    for (snap.events) |event| {
        if (event.kind == .effect_started and std.mem.eql(u8, event.type_name, "ChannelSend")) send_effect_id = event.id;
        if (event.kind == .fiber_resumed) resume_cause = event.cause_event_id;
    }
    try std.testing.expect(send_effect_id != null);
    try std.testing.expectEqual(send_effect_id, resume_cause);

    // no hang: the parked consumer was woken
    var findings = try store.findings(allocator);
    defer findings.deinit();
    for (findings.items) |finding| {
        try std.testing.expect(finding.kind != .fiber_suspended_without_resume);
    }
}

test "Z2: a fiber blocks on a real socket read and resumes when data arrives" {
    const allocator = std.testing.allocator;
    var rt = try zio.Runtime.init(allocator, .{});
    defer rt.deinit();

    var store = fx.CausalStore.init(allocator);
    defer store.deinit();
    try recordZioIoScenario(&store);

    var snap = try store.snapshot(allocator);
    defer snap.deinit();

    try std.testing.expectEqual(@as(usize, 1), kindCount(snap.events, .io_wait_started));
    try std.testing.expectEqual(@as(usize, 1), kindCount(snap.events, .io_completed));
    try std.testing.expectEqual(@as(usize, 1), kindCount(snap.events, .fiber_resumed));
    try std.testing.expectEqual(@as(usize, 1), kindCount(snap.events, .fiber_joined));

    // the resume is caused by the IO completing
    var io_completed_id: ?u64 = null;
    var resume_cause: ?u64 = null;
    for (snap.events) |event| {
        if (event.kind == .io_completed) io_completed_id = event.id;
        if (event.kind == .fiber_resumed) resume_cause = event.cause_event_id;
    }
    try std.testing.expectEqual(io_completed_id, resume_cause);
}

test "Z3: zio.Group.cancel interrupts a parked child, caused by scope close" {
    const allocator = std.testing.allocator;
    var rt = try zio.Runtime.init(allocator, .{});
    defer rt.deinit();

    var store = fx.CausalStore.init(allocator);
    defer store.deinit();
    try recordZioCancellationScenario(&store);

    var snap = try store.snapshot(allocator);
    defer snap.deinit();

    // The child suspended for real and was interrupted (never resumed/joined).
    try std.testing.expectEqual(@as(usize, 1), kindCount(snap.events, .fiber_suspended));
    try std.testing.expectEqual(@as(usize, 1), kindCount(snap.events, .fiber_interrupted));
    try std.testing.expectEqual(@as(usize, 0), kindCount(snap.events, .fiber_resumed));

    // Structured-concurrency invariant: the interrupt is caused by scope_closed.
    var scope_closed_id: ?u64 = null;
    var interrupt_cause: ?u64 = null;
    for (snap.events) |event| {
        if (event.kind == .scope_closed) scope_closed_id = event.id;
        if (event.kind == .fiber_interrupted) interrupt_cause = event.cause_event_id;
    }
    try std.testing.expect(scope_closed_id != null);
    try std.testing.expectEqual(scope_closed_id, interrupt_cause);

    // The hang detector must NOT fire: an interrupted fiber is resolved, not hung.
    var findings = try store.findings(allocator);
    defer findings.deinit();
    for (findings.items) |finding| {
        try std.testing.expect(finding.kind != .fiber_suspended_without_resume);
    }
}

// Track E — the AsyncBackend vtable is now WORKING on zio (was: asserts
// Unsupported). The pull-model methods (suspend/register/wake/interrupt/poll)
// are a real registration + wake-queue; schedule_timer spawns a REAL zio timer.

test "zio AsyncBackend: suspend_runtime → wake → poll_wake round-trips" {
    const allocator = std.testing.allocator;
    var rt = try zio.Runtime.init(allocator, .{});
    defer rt.deinit();
    var state = ZioAsyncBackendState.init(allocator);
    defer state.deinit(); // runs before rt.deinit (defer LIFO)
    const b = state.backend();

    try b.suspendRuntime(.{ .suspension = .{ .kind = .external, .id = 1, .label = "park" }, .reason = "wait" });
    try std.testing.expectEqual(@as(?BackendWakeEvent, null), try b.pollWake()); // not woken yet
    try std.testing.expectEqual(@as(usize, 1), b.snapshot().pending_count);

    try b.wake(.{ .suspension_id = 1, .reason = "ready" });
    const w = (try b.pollWake()).?;
    try std.testing.expectEqual(@as(u64, 1), w.suspension.id);
    try std.testing.expectEqual(fx.AsyncWaitStatus.ready, w.status);
    try std.testing.expectEqual(fx.AsyncWaitKind.runtime, w.wait_kind);
    try std.testing.expectEqual(@as(?BackendWakeEvent, null), try b.pollWake()); // drained
}

test "zio AsyncBackend: interrupt resolves a suspension as interrupted" {
    const allocator = std.testing.allocator;
    var rt = try zio.Runtime.init(allocator, .{});
    defer rt.deinit();
    var state = ZioAsyncBackendState.init(allocator);
    defer state.deinit();
    const b = state.backend();

    try b.suspendRuntime(.{ .suspension = .{ .kind = .external, .id = 2, .label = "park" } });
    try b.interrupt(.{ .target_id = 2, .reason = "cancel" });
    const w = (try b.pollWake()).?;
    try std.testing.expectEqual(@as(u64, 2), w.suspension.id);
    try std.testing.expectEqual(fx.AsyncWaitStatus.interrupted, w.status);
    try std.testing.expectEqual(@as(usize, 1), b.snapshot().interrupted_count);
}

test "zio AsyncBackend: register_io_wait → complete_io round-trips with the io kind" {
    const allocator = std.testing.allocator;
    var rt = try zio.Runtime.init(allocator, .{});
    defer rt.deinit();
    var state = ZioAsyncBackendState.init(allocator);
    defer state.deinit();
    const b = state.backend();

    try b.registerIoWait(.{ .suspension = .{ .kind = .external, .id = 3, .label = "sock" }, .io_kind = .network, .interest = .readable, .descriptor = 7 });
    try b.completeIo(.{ .suspension_id = 3, .io_kind = .network, .reason = "readable" });
    const w = (try b.pollWake()).?;
    try std.testing.expectEqual(@as(u64, 3), w.suspension.id);
    try std.testing.expectEqual(fx.AsyncWaitStatus.ready, w.status);
    try std.testing.expectEqual(fx.AsyncWaitKind.network, w.wait_kind);
}

test "zio AsyncBackend: schedule_timer fires a REAL zio timer that poll_wake drains" {
    const allocator = std.testing.allocator;
    var rt = try zio.Runtime.init(allocator, .{});
    defer rt.deinit();
    var state = ZioAsyncBackendState.init(allocator);
    defer state.deinit();
    const b = state.backend();

    try b.scheduleTimer(.{ .suspension = .{ .kind = .timer, .id = 4, .label = "t" }, .due_time_ms = 5 });

    // Poll until the real timer coroutine fires (giving it event-loop time).
    var fired = false;
    var i: usize = 0;
    while (i < 5000 and !fired) : (i += 1) {
        if (try b.pollWake()) |w| {
            try std.testing.expectEqual(@as(u64, 4), w.suspension.id);
            try std.testing.expectEqual(fx.AsyncWaitStatus.ready, w.status);
            try std.testing.expectEqual(fx.AsyncWaitKind.timer, w.wait_kind);
            fired = true;
        } else {
            try zio.sleep(zio.Duration.fromMilliseconds(1));
        }
    }
    try std.testing.expect(fired);
}
