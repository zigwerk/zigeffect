//! Pluggable execution-strategy types shared by FiberRuntime, the top-level
//! Runtime(Env) builder, and Context. Lives in its own module so both
//! `core/context.zig` and `runtime/fiber.zig` can import it without a cycle.

/// A unit of work the runtime hands to a `FiberExecutor`: run one fiber's
/// effect to completion. `run` is type-erased over the fiber's
/// Success/Failure/Env.
pub const FiberJob = struct {
    context: ?*anyopaque,
    run: *const fn (?*anyopaque) void,
};

/// Pluggable execution strategy for forked fibers (and, transitively, for any
/// future `ctx.fork(...)`-style API that runs an effect concurrently).
///
/// With NO executor (the default), fibers run synchronously to completion on
/// `join` — the deterministic model, unchanged. An executor (e.g. the zio
/// adapter) instead spawns each fiber as a real stackful coroutine at `fork`
/// time, and `join` awaits it — so the SAME `Effect.fork` program runs with
/// real concurrency while producing the same causal structure it does
/// deterministically.
///
/// Equivalence scope: the "same causal structure either way" guarantee holds
/// for fibers that are JOINED. The two paths differ in WHEN a fiber runs — an
/// executor runs it eagerly at fork, the default runs it lazily at join — so a
/// fiber that is forked and never joined diverges: under an executor it is
/// still drained (run + released) at deinit as a leak-safety net and thus
/// records its start, whereas the lazy default never runs it. Join the fibers
/// you fork.
pub const FiberExecutor = struct {
    context: ?*anyopaque = null,
    vtable: *const VTable,

    pub const VTable = struct {
        /// Schedule the job; return an opaque handle, or null to fall back to
        /// synchronous execution (e.g. on spawn failure).
        spawn: *const fn (?*anyopaque, FiberJob) ?*anyopaque,
        /// Block until a spawned job completes.
        join: *const fn (?*anyopaque, *anyopaque) void,
        /// Release a handle's resources after join.
        destroy: *const fn (?*anyopaque, *anyopaque) void,
    };
};
