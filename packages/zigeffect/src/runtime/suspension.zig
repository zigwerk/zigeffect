const std = @import("std");
const causal_mod = @import("../services/causal.zig");
const async_backend_mod = @import("async_backend.zig");
const control = @import("control.zig");

pub const Allocator = std.mem.Allocator;
pub const CausalStore = causal_mod.CausalStore;
pub const CausalEvent = causal_mod.CausalEvent;
pub const AsyncBackend = async_backend_mod.AsyncBackend;
pub const AsyncBackendError = async_backend_mod.AsyncBackendError;
pub const Suspension = control.Suspension;

pub const SuspensionError = AsyncBackendError || Allocator.Error;

const Record = struct {
    suspension_id: u64,
    fiber_id: u64,
    scope_id: ?u64,
    run_id: ?u64,
    suspended_event_id: u64,
    scheduled_event_id: u64,
    due_time_ms: u64,
    resumed: bool = false,
};

/// Backend-agnostic coordinator that emits causal suspend/timer/resume events
/// around an `AsyncBackend` timer. The deterministic `LocalAsyncBackendState`
/// drives it with a virtual clock (`advanceAndResume`); a future zio backend
/// drives the identical event emission with real coroutine park/unpark, so the
/// causal trace stays comparable across backends.
///
/// Edge contract (so `cause`/`lineage` queries work):
/// - `fiber_suspended.cause_event_id` -> the effect that triggered the park
/// - `timer_scheduled.cause_event_id`  -> `fiber_suspended`
/// - `timer_fired` correlates to `timer_scheduled` by shared `schedule_id`
/// - `fiber_resumed.cause_event_id`    -> `timer_fired`  (load-bearing edge)
pub const SuspensionCoordinator = struct {
    allocator: Allocator,
    store: *CausalStore,
    backend: AsyncBackend,
    records: std.ArrayList(Record) = .empty,
    next_suspension_id: u64 = 1,

    pub fn init(allocator: Allocator, store: *CausalStore, backend: AsyncBackend) SuspensionCoordinator {
        return .{ .allocator = allocator, .store = store, .backend = backend };
    }

    pub fn deinit(self: *SuspensionCoordinator) void {
        self.records.deinit(self.allocator);
    }

    pub const SuspendOnTimer = struct {
        fiber_id: u64,
        scope_id: ?u64 = null,
        run_id: ?u64 = null,
        /// parent for the fiber chain (typically the fiber_started event id)
        started_event_id: ?u64 = null,
        /// the effect that triggered the park (e.g. the delay effect_started)
        caused_by_event_id: ?u64 = null,
        due_time_ms: u64,
        now_ms: u64 = 0,
        label: []const u8 = "delay",
    };

    /// Park a fiber on a timer: emit `fiber_suspended` + `timer_scheduled` and
    /// register the timer with the backend. Returns the suspension id.
    pub fn suspendOnTimer(self: *SuspensionCoordinator, request: SuspendOnTimer) SuspensionError!u64 {
        const sid = self.next_suspension_id;
        self.next_suspension_id += 1;

        const suspended_id = try self.store.record(.{
            .kind = .fiber_suspended,
            .run_id = request.run_id,
            .fiber_id = request.fiber_id,
            .scope_id = request.scope_id,
            .parent_id = request.started_event_id,
            .cause_event_id = request.caused_by_event_id,
            .schedule_id = sid,
            .status = "pending",
            .label = "fiber suspended on timer",
            .type_name = "Suspension",
        });

        const scheduled_id = try self.store.record(.{
            .kind = .timer_scheduled,
            .run_id = request.run_id,
            .fiber_id = request.fiber_id,
            .scope_id = request.scope_id,
            .parent_id = suspended_id,
            .cause_event_id = suspended_id,
            .schedule_id = sid,
            .status = "pending",
            .label = request.label,
            .type_name = "Timer",
        });

        try self.backend.scheduleTimer(.{
            .suspension = .{ .kind = .timer, .id = sid, .label = request.label },
            .due_time_ms = request.due_time_ms,
            .now_ms = request.now_ms,
        });

        try self.records.append(self.allocator, .{
            .suspension_id = sid,
            .fiber_id = request.fiber_id,
            .scope_id = request.scope_id,
            .run_id = request.run_id,
            .suspended_event_id = suspended_id,
            .scheduled_event_id = scheduled_id,
            .due_time_ms = request.due_time_ms,
        });
        return sid;
    }

    /// The unified delay — the heart of the deterministic↔real backend bridge.
    /// Emits fiber_suspended + timer_scheduled, waits via the backend's
    /// `blockingSleep` (virtual/instant on `LocalAsyncBackendState`, a real
    /// coroutine yield on the zio backend), then emits timer_fired +
    /// fiber_resumed. The SAME engine code drives both backends, so the causal
    /// trace is identical — only the wait is virtual vs real.
    pub fn delay(self: *SuspensionCoordinator, request: SuspendOnTimer) SuspensionError!void {
        const sid = self.next_suspension_id;
        self.next_suspension_id += 1;

        const suspended = try self.store.record(.{
            .kind = .fiber_suspended,
            .run_id = request.run_id,
            .fiber_id = request.fiber_id,
            .scope_id = request.scope_id,
            .parent_id = request.started_event_id,
            .cause_event_id = request.caused_by_event_id,
            .schedule_id = sid,
            .status = "pending",
            .label = "fiber suspended on timer",
            .type_name = "Suspension",
        });
        const scheduled = try self.store.record(.{
            .kind = .timer_scheduled,
            .run_id = request.run_id,
            .fiber_id = request.fiber_id,
            .scope_id = request.scope_id,
            .parent_id = suspended,
            .cause_event_id = suspended,
            .schedule_id = sid,
            .status = "pending",
            .label = request.label,
            .type_name = "Timer",
        });

        try self.backend.blockingSleep(request.due_time_ms);

        const fired = try self.store.record(.{
            .kind = .timer_fired,
            .run_id = request.run_id,
            .fiber_id = request.fiber_id,
            .scope_id = request.scope_id,
            .parent_id = scheduled,
            .cause_event_id = scheduled,
            .schedule_id = sid,
            .status = "ready",
            .label = "timer fired",
            .type_name = "Timer",
        });
        _ = try self.store.record(.{
            .kind = .fiber_resumed,
            .run_id = request.run_id,
            .fiber_id = request.fiber_id,
            .scope_id = request.scope_id,
            .parent_id = suspended,
            .cause_event_id = fired,
            .schedule_id = sid,
            .status = "running",
            .label = "fiber resumed",
            .type_name = "Suspension",
        });
    }

    /// Advance virtual time and resume any fibers whose timers fired. For each
    /// fired timer, emit `timer_fired` (correlated by `schedule_id`) and
    /// `fiber_resumed` (`cause_event_id` -> `timer_fired`). Returns count resumed.
    pub fn advanceAndResume(self: *SuspensionCoordinator, now_ms: u64) SuspensionError!usize {
        _ = try self.backend.advanceTime(now_ms);
        var resumed: usize = 0;
        while (try self.backend.pollWake()) |event| {
            const rec = self.findRecord(event.suspension.id) orelse continue;
            if (rec.resumed) continue;

            const fired_id = try self.store.record(.{
                .kind = .timer_fired,
                .run_id = rec.run_id,
                .fiber_id = rec.fiber_id,
                .scope_id = rec.scope_id,
                .parent_id = rec.scheduled_event_id,
                .cause_event_id = rec.scheduled_event_id,
                .schedule_id = rec.suspension_id,
                .status = "ready",
                .label = "timer fired",
                .type_name = "Timer",
            });

            _ = try self.store.record(.{
                .kind = .fiber_resumed,
                .run_id = rec.run_id,
                .fiber_id = rec.fiber_id,
                .scope_id = rec.scope_id,
                .parent_id = rec.suspended_event_id,
                .cause_event_id = fired_id,
                .schedule_id = rec.suspension_id,
                .status = "running",
                .label = "fiber resumed",
                .type_name = "Suspension",
            });

            rec.resumed = true;
            resumed += 1;
        }
        return resumed;
    }

    /// Number of suspensions still parked (no `fiber_resumed` emitted yet).
    pub fn pendingCount(self: *const SuspensionCoordinator) usize {
        var count: usize = 0;
        for (self.records.items) |rec| {
            if (!rec.resumed) count += 1;
        }
        return count;
    }

    fn findRecord(self: *SuspensionCoordinator, suspension_id: u64) ?*Record {
        for (self.records.items) |*rec| {
            if (rec.suspension_id == suspension_id) return rec;
        }
        return null;
    }
};

pub const DelayScenarioAnchors = struct {
    run_id: u64,
    scope_id: u64,
    fiber_id: u64,
    scope_opened_id: u64,
    scope_closed_id: u64,
};

/// Canonical deterministic delay scenario, the single source of truth for the
/// suspend/resume causal contract used by the test and the example artifact.
///
/// A scoped fiber forks, starts, runs a `delay` effect that suspends it on a
/// timer; the virtual clock advances (`backend`, typically a
/// `LocalAsyncBackendState`); the timer fires, the fiber resumes and is joined
/// as the scope closes. The join is recorded after `scope_closed` so the scope
/// teardown awaits its child (keeping the pending-fiber finding clean).
pub fn recordDelaySuspensionScenario(
    allocator: Allocator,
    store: *CausalStore,
    backend: AsyncBackend,
    due_time_ms: u64,
) SuspensionError!DelayScenarioAnchors {
    const run_id = store.nextRunId();
    const scope_id = store.nextScopeId();
    const fiber_id: u64 = 1;

    const run_started = try store.record(.{
        .kind = .run_started,
        .run_id = run_id,
        .status = "started",
        .label = "causal-delay-suspension",
        .type_name = "CausalDelayScenario",
    });
    const scope_opened = try store.record(.{
        .kind = .scope_opened,
        .run_id = run_id,
        .scope_id = scope_id,
        .parent_id = run_started,
        .status = "opened",
        .label = "delay scope",
    });
    const fiber_forked = try store.record(.{
        .kind = .fiber_forked,
        .run_id = run_id,
        .scope_id = scope_id,
        .fiber_id = fiber_id,
        .parent_id = scope_opened,
        .status = "pending",
        .label = "delay fiber",
    });
    const fiber_started = try store.record(.{
        .kind = .fiber_started,
        .run_id = run_id,
        .scope_id = scope_id,
        .fiber_id = fiber_id,
        .parent_id = fiber_forked,
        .status = "running",
        .label = "delay fiber",
    });
    const delay_effect = try store.record(.{
        .kind = .effect_started,
        .run_id = run_id,
        .scope_id = scope_id,
        .fiber_id = fiber_id,
        .parent_id = fiber_started,
        .status = "started",
        .label = "delay",
        .type_name = "DelayEffect",
    });

    var coordinator = SuspensionCoordinator.init(allocator, store, backend);
    defer coordinator.deinit();

    // Unified path: the same delay() that the zio backend uses; here the wait is
    // virtual (the deterministic backend's blockingSleep advances a clock).
    try coordinator.delay(.{
        .fiber_id = fiber_id,
        .scope_id = scope_id,
        .run_id = run_id,
        .started_event_id = fiber_started,
        .caused_by_event_id = delay_effect,
        .due_time_ms = due_time_ms,
    });

    const scope_closed = try store.record(.{
        .kind = .scope_closed,
        .run_id = run_id,
        .scope_id = scope_id,
        .parent_id = run_started,
        .status = "closed",
        .label = "delay scope",
    });
    _ = try store.record(.{
        .kind = .fiber_joined,
        .run_id = run_id,
        .scope_id = scope_id,
        .fiber_id = fiber_id,
        .parent_id = scope_closed,
        .status = "success",
        .label = "delay fiber",
    });
    _ = try store.record(.{
        .kind = .exit_recorded,
        .run_id = run_id,
        .parent_id = run_started,
        .status = "success",
        .label = "causal-delay-suspension",
    });

    return .{
        .run_id = run_id,
        .scope_id = scope_id,
        .fiber_id = fiber_id,
        .scope_opened_id = scope_opened,
        .scope_closed_id = scope_closed,
    };
}

/// Hang fixture: a scoped fiber forks, starts, suspends on a timer, and the
/// timer is NEVER advanced — so the fiber is parked forever. Produces exactly
/// one `fiber_suspended_without_resume` finding. Used to verify the hang
/// detector (the failure-mode counterpart of recordDelaySuspensionScenario).
pub fn recordHangSuspensionScenario(
    allocator: Allocator,
    store: *CausalStore,
    backend: AsyncBackend,
    due_time_ms: u64,
) SuspensionError!DelayScenarioAnchors {
    const run_id = store.nextRunId();
    const scope_id = store.nextScopeId();
    const fiber_id: u64 = 1;

    const run_started = try store.record(.{
        .kind = .run_started,
        .run_id = run_id,
        .status = "started",
        .label = "causal-suspension-hang",
        .type_name = "CausalHangScenario",
    });
    const scope_opened = try store.record(.{
        .kind = .scope_opened,
        .run_id = run_id,
        .scope_id = scope_id,
        .parent_id = run_started,
        .status = "opened",
        .label = "hang scope",
    });
    const fiber_forked = try store.record(.{
        .kind = .fiber_forked,
        .run_id = run_id,
        .scope_id = scope_id,
        .fiber_id = fiber_id,
        .parent_id = scope_opened,
        .status = "pending",
        .label = "hung fiber",
    });
    const fiber_started = try store.record(.{
        .kind = .fiber_started,
        .run_id = run_id,
        .scope_id = scope_id,
        .fiber_id = fiber_id,
        .parent_id = fiber_forked,
        .status = "running",
        .label = "hung fiber",
    });
    const delay_effect = try store.record(.{
        .kind = .effect_started,
        .run_id = run_id,
        .scope_id = scope_id,
        .fiber_id = fiber_id,
        .parent_id = fiber_started,
        .status = "started",
        .label = "delay",
        .type_name = "DelayEffect",
    });

    var coordinator = SuspensionCoordinator.init(allocator, store, backend);
    defer coordinator.deinit();

    // Park the fiber but never advance the clock: it stays suspended.
    _ = try coordinator.suspendOnTimer(.{
        .fiber_id = fiber_id,
        .scope_id = scope_id,
        .run_id = run_id,
        .started_event_id = fiber_started,
        .caused_by_event_id = delay_effect,
        .due_time_ms = due_time_ms,
    });

    _ = try store.record(.{
        .kind = .exit_recorded,
        .run_id = run_id,
        .parent_id = run_started,
        .status = "incomplete",
        .label = "causal-suspension-hang",
    });

    return .{
        .run_id = run_id,
        .scope_id = scope_id,
        .fiber_id = fiber_id,
        .scope_opened_id = scope_opened,
        .scope_closed_id = 0,
    };
}
