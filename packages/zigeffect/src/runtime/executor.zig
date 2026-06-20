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
        ///
        /// MEMORY ORDERING: `spawn` MUST establish a happens-before edge from
        /// the caller's writes preparing `job.context` to the worker's reads
        /// inside `job.run`. On single-threaded cooperative coroutines this is
        /// the natural sequence; on a threaded pool the executor's submission
        /// queue lock typically provides it.
        spawn: *const fn (?*anyopaque, FiberJob) ?*anyopaque,
        /// Block until a spawned job completes.
        ///
        /// MEMORY ORDERING: `join` MUST establish a happens-before edge from
        /// the job's final write (inside `job.run`) to the joiner. A primitive
        /// like `forEachPar` reads a result slot the job wrote; without this
        /// edge the read is racy.
        join: *const fn (?*anyopaque, *anyopaque) void,
        /// Release a handle's resources after join.
        destroy: *const fn (?*anyopaque, *anyopaque) void,
        /// Request cancellation of a spawned job (M7.8). OPTIONAL — executors
        /// that cannot interrupt leave this null, and primitives fall back to
        /// joining the job to completion. When present, after
        /// `interrupt(handle)` the job is guaranteed to have terminated; a
        /// subsequent `join` returns its (possibly interrupted) result and
        /// `destroy` releases the handle. Used by Phase-8 remediation (cut a
        /// wedged fiber) and, in future, by `race`/`both` to cancel losers.
        interrupt: ?*const fn (?*anyopaque, *anyopaque) void = null,
    };

    /// Whether this executor can interrupt a spawned job. Primitives branch on
    /// this to choose early-cancel vs join-to-completion.
    pub fn canInterrupt(self: FiberExecutor) bool {
        return self.vtable.interrupt != null;
    }

    /// Best-effort interrupt: cancels the job if the executor supports it,
    /// returns whether an interrupt was issued. After a true return the job has
    /// terminated and the handle is still valid for `join`/`destroy`.
    pub fn tryInterrupt(self: FiberExecutor, handle: *anyopaque) bool {
        if (self.vtable.interrupt) |interrupt_fn| {
            interrupt_fn(self.context, handle);
            return true;
        }
        return false;
    }

    /// Threading contract for v1: the engine's `CausalStore`, `Scope`, and the
    /// state primitives (`Ref`, `Hub`) are not thread-safe. Executors used with
    /// the structured-concurrency primitives (`forEachPar`, `zipPar`, etc.) and
    /// with any code that records causal events MUST be cooperatively
    /// single-threaded (e.g. `zio.Runtime` with `executors: .exact(1)`). A
    /// multi-threaded pool requires lifting the engine state primitives to
    /// thread-safe in a future v2 — at which point this comment must change.
    pub const ThreadingContract = enum { single_executor_v1 };
};
