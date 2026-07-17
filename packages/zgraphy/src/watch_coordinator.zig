const std = @import("std");
const zstd = @import("zigeffect_std");
const discovery = @import("discovery.zig");
const freshness = @import("freshness.zig");
const operations = @import("operations.zig");
const project = @import("project.zig");
const repository_context = @import("repository_context.zig");

pub const pending_schema = "zgraphy.watch-pending.v1";
pub const pending_schema_version: u32 = 1;
pub const pending_path = ".zgraphy/runtime/watch/pending.json";
pub const pending_lock_path = ".zgraphy/runtime/watch/pending.lock";
pub const max_pending_bytes: usize = 1024 * 1024;
pub const max_pending_requests: usize = 1024;
pub const max_pending_hints: usize = 4096;
pub const max_request_id_bytes: usize = 128;

pub const State = enum {
    idle,
    debouncing,
    waiting_for_lease,
    refreshing,
    draining,
    retaining_last_good,
    stopping,
    stopped,
};

pub const Event = enum {
    observed,
    debounce_elapsed,
    lease_acquired,
    lease_contended,
    refresh_succeeded,
    refresh_succeeded_late,
    refresh_failed,
    drain_complete,
    retry_due,
    stop_requested,
};

pub const Command = enum {
    persist_request,
    attempt_refresh,
    drain_requests,
    record_failure,
    stop,
};

pub const Definition = zstd.fx.statechart.Definition(State, Event, void, Command);
pub const definition = Definition.init(.{
    .id = "zgraphy.watch-coordinator",
    .version = 1,
    .initial = .idle,
    .states = &.{
        .{ .id = .idle },
        .{ .id = .debouncing },
        .{ .id = .waiting_for_lease },
        .{ .id = .refreshing },
        .{ .id = .draining },
        .{ .id = .retaining_last_good },
        .{ .id = .stopping },
        .{ .id = .stopped, .kind = .final },
    },
    .transitions = &.{
        .{ .id = "observe-idle", .source = .idle, .event = .observed, .target = .debouncing },
        .{ .id = "observe-debouncing", .source = .debouncing, .event = .observed, .target = .debouncing },
        .{ .id = "observe-waiting", .source = .waiting_for_lease, .event = .observed, .target = .waiting_for_lease },
        .{ .id = "observe-refreshing", .source = .refreshing, .event = .observed, .target = .refreshing },
        .{ .id = "observe-draining", .source = .draining, .event = .observed, .target = .draining },
        .{ .id = "observe-retaining", .source = .retaining_last_good, .event = .observed, .target = .retaining_last_good },
        .{ .id = "debounce-elapsed", .source = .debouncing, .event = .debounce_elapsed, .target = .waiting_for_lease },
        .{ .id = "lease-acquired", .source = .waiting_for_lease, .event = .lease_acquired, .target = .refreshing },
        .{ .id = "lease-contended", .source = .waiting_for_lease, .event = .lease_contended, .target = .retaining_last_good },
        .{ .id = "refresh-contended", .source = .refreshing, .event = .lease_contended, .target = .retaining_last_good },
        .{ .id = "refresh-succeeded", .source = .refreshing, .event = .refresh_succeeded, .target = .idle },
        .{ .id = "refresh-succeeded-late", .source = .refreshing, .event = .refresh_succeeded_late, .target = .draining },
        .{ .id = "refresh-failed", .source = .refreshing, .event = .refresh_failed, .target = .retaining_last_good },
        .{ .id = "drain-complete", .source = .draining, .event = .drain_complete, .target = .idle },
        .{ .id = "retry-due", .source = .retaining_last_good, .event = .retry_due, .target = .debouncing },
        .{ .id = "stop-idle", .source = .idle, .event = .stop_requested, .target = .stopping },
        .{ .id = "stop-debouncing", .source = .debouncing, .event = .stop_requested, .target = .stopping },
        .{ .id = "stop-waiting", .source = .waiting_for_lease, .event = .stop_requested, .target = .stopping },
        .{ .id = "stop-refreshing", .source = .refreshing, .event = .stop_requested, .target = .stopping },
        .{ .id = "stop-draining", .source = .draining, .event = .stop_requested, .target = .stopping },
        .{ .id = "stop-retaining", .source = .retaining_last_good, .event = .stop_requested, .target = .stopping },
        .{ .id = "stop-complete", .source = .stopping, .event = .drain_complete, .target = .stopped },
    },
});

const Machine = zstd.fx.statechart.Machine(Definition);

pub const Options = struct {
    debounce_ms: u64 = 250,
    retry_ms: u64 = 100,
    max_pending_hints: usize = 1024,
    max_drain_passes: usize = 20,
};

pub const Action = enum {
    none,
    attempt_refresh,
    drain_pending,
    persist_and_stop,
};

pub const Decision = struct {
    state: State,
    action: Action = .none,
};

pub const Summary = struct {
    observations: usize = 0,
    unique_hints: usize = 0,
    coalesced_observations: usize = 0,
    refresh_attempts: usize = 0,
    refresh_successes: usize = 0,
    contentions: usize = 0,
    failures: usize = 0,
    drain_passes: usize = 0,
};

pub const Coordinator = struct {
    allocator: std.mem.Allocator,
    options: Options,
    snapshot: Machine.Snapshot,
    hints: std.ArrayList([32]u8) = .empty,
    summary_value: Summary = .{},
    last_observed_ms: u64 = 0,
    retry_due_ms: u64 = 0,
    refresh_batch_hints: usize = 0,
    batch_drain_passes: usize = 0,

    pub fn init(allocator: std.mem.Allocator, options: Options) !Coordinator {
        try validateOptions(options);
        if (!definition.validate().isValid()) return error.InvalidWatchStatechart;
        return .{
            .allocator = allocator,
            .options = options,
            .snapshot = Machine.initial(&definition, {}, 1),
        };
    }

    pub fn deinit(self: *Coordinator) void {
        self.hints.deinit(self.allocator);
        self.* = .{
            .allocator = self.allocator,
            .options = self.options,
            .snapshot = Machine.initial(&definition, {}, 1),
        };
    }

    pub fn observe(self: *Coordinator, path: []const u8, now_ms: u64) !void {
        if (!validRelativePath(path)) return error.InvalidWatchPath;
        var digest: [32]u8 = @splat(0);
        std.crypto.hash.sha2.Sha256.hash(path, &digest, .{});
        self.summary_value.observations += 1;
        var duplicate = false;
        for (self.hints.items) |existing| if (std.mem.eql(u8, &existing, &digest)) {
            duplicate = true;
            break;
        };
        if (duplicate) {
            self.summary_value.coalesced_observations += 1;
        } else {
            if (self.hints.items.len >= self.options.max_pending_hints) return error.WatchPendingLimitExceeded;
            try self.hints.append(self.allocator, digest);
            self.summary_value.unique_hints += 1;
        }
        self.last_observed_ms = now_ms;
        _ = try self.transition(.observed, .none);
    }

    pub fn advance(self: *Coordinator, now_ms: u64) !Decision {
        if (self.snapshot.state == .debouncing and elapsed(now_ms, self.last_observed_ms) >= self.options.debounce_ms) {
            return self.transition(.debounce_elapsed, .attempt_refresh);
        }
        if (self.snapshot.state == .retaining_last_good and now_ms >= self.retry_due_ms) {
            return self.transition(.retry_due, .none);
        }
        return .{ .state = self.snapshot.state };
    }

    pub fn leaseAcquired(self: *Coordinator) !Decision {
        self.summary_value.refresh_attempts += 1;
        self.refresh_batch_hints = self.hints.items.len;
        self.batch_drain_passes = 0;
        return self.transition(.lease_acquired, .none);
    }

    pub fn leaseContended(self: *Coordinator, now_ms: u64) !Decision {
        self.summary_value.contentions += 1;
        self.retry_due_ms = std.math.add(u64, now_ms, self.options.retry_ms) catch std.math.maxInt(u64);
        return self.transition(.lease_contended, .none);
    }

    pub fn refreshSucceeded(self: *Coordinator) !Decision {
        self.summary_value.refresh_successes += 1;
        const has_late_hints = self.hints.items.len > self.refresh_batch_hints;
        self.discardCoveredHints();
        if (has_late_hints) {
            return self.transition(.refresh_succeeded_late, .drain_pending);
        }
        return self.transition(.refresh_succeeded, .none);
    }

    pub fn refreshFailed(self: *Coordinator, now_ms: u64) !Decision {
        self.summary_value.failures += 1;
        self.retry_due_ms = std.math.add(u64, now_ms, self.options.retry_ms) catch std.math.maxInt(u64);
        return self.transition(.refresh_failed, .none);
    }

    pub fn drainComplete(self: *Coordinator, has_more: bool) !Decision {
        self.summary_value.drain_passes += 1;
        self.batch_drain_passes += 1;
        if (self.batch_drain_passes > self.options.max_drain_passes) return error.WatchDrainLimitExceeded;
        if (has_more) return .{ .state = self.snapshot.state, .action = .drain_pending };
        self.hints.items.len = 0;
        self.refresh_batch_hints = 0;
        const decision = try self.transition(.drain_complete, .none);
        self.batch_drain_passes = 0;
        return decision;
    }

    pub fn stop(self: *Coordinator) !Decision {
        if (self.snapshot.state == .stopping) return self.transition(.drain_complete, .none);
        if (self.snapshot.state == .stopped) return .{ .state = .stopped };
        return self.transition(.stop_requested, if (self.hints.items.len == 0) .none else .persist_and_stop);
    }

    pub fn summary(self: *const Coordinator) Summary {
        return self.summary_value;
    }

    fn transition(self: *Coordinator, event: Event, action: Action) !Decision {
        const decision = try Machine.step(&definition, self.snapshot, event);
        if (decision.outcome != .transitioned) return error.InvalidWatchTransition;
        self.snapshot = decision.next;
        return .{ .state = self.snapshot.state, .action = action };
    }

    fn discardCoveredHints(self: *Coordinator) void {
        const covered = @min(self.refresh_batch_hints, self.hints.items.len);
        if (covered == 0) return;
        const retained = self.hints.items.len - covered;
        if (retained > 0) std.mem.copyForwards([32]u8, self.hints.items[0..retained], self.hints.items[covered..]);
        self.hints.items.len = retained;
        self.refresh_batch_hints = 0;
    }
};

pub const RepositoryObservation = struct {
    fingerprint: [32]u8,
    observed_entries: usize,
    watched_entries: usize,
    watched_files: usize,
    skipped_entries: usize,
};

pub fn observeRepository(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    config: project.Config,
) !RepositoryObservation {
    try project.validateConfig(config);
    var context = try repository_context.inspect(allocator, io, root);
    defer context.deinit();
    const metadata = try discovery.scanMetadata(allocator, io, root, .{
        .repository_id = config.repository_id,
        .max_entries = config.max_entries,
        .max_files = config.max_files,
        .max_file_bytes = config.max_file_bytes,
        .max_total_bytes = config.max_source_bytes,
        .max_depth = config.max_depth,
        .max_path_bytes = config.max_path_bytes,
    });
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update("zgraphy.watch-observation.v1");
    hasher.update(&metadata.fingerprint);
    updateBytes(&hasher, context.value.fingerprint);
    var fingerprint: [32]u8 = @splat(0);
    hasher.final(&fingerprint);
    return .{
        .fingerprint = fingerprint,
        .observed_entries = metadata.observed_entries,
        .watched_entries = metadata.watched_entries,
        .watched_files = metadata.watched_files,
        .skipped_entries = metadata.skipped_entries,
    };
}

pub const Hint = struct {
    digest: [32]u8,
};

pub const Request = struct {
    request_id: []const u8,
    hints: []const Hint,
};

pub const PendingSummary = struct {
    pending_requests: usize = 0,
    pending_hints: usize = 0,
};

pub const PendingArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    repository_id: []const u8,
    requests: []const Request,
    summary: PendingSummary,
    fingerprint: [32]u8,
    complete: bool,
};

pub const RequestInput = struct {
    repository_id: []const u8,
    request_id: []const u8,
    paths: []const []const u8,
};

const PendingLease = struct {
    io: std.Io,
    file: std.Io.File,

    fn acquire(io: std.Io, root: std.Io.Dir) !PendingLease {
        try root.createDirPath(io, ".zgraphy/runtime/watch");
        const file = try root.createFile(io, pending_lock_path, .{
            .read = true,
            .truncate = false,
            .lock = .exclusive,
        });
        return .{ .io = io, .file = file };
    }

    fn deinit(self: *PendingLease) void {
        self.file.unlock(self.io);
        self.file.close(self.io);
    }
};

pub fn requestRefresh(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    input: RequestInput,
) !void {
    if (!discovery.isValidRepositoryId(input.repository_id) or !validRequestId(input.request_id) or
        input.paths.len == 0 or input.paths.len > max_pending_hints)
    {
        return error.InvalidWatchRequest;
    }
    var lease = try PendingLease.acquire(io, root);
    defer lease.deinit();

    var existing = readPending(allocator, io, root, input.repository_id) catch |failure| switch (failure) {
        error.FileNotFound => null,
        else => return failure,
    };
    defer if (existing) |*parsed| parsed.deinit();
    if (existing) |*parsed| for (parsed.value.requests) |request| {
        if (std.mem.eql(u8, request.request_id, input.request_id)) return;
    };

    var hints: std.ArrayList(Hint) = .empty;
    defer hints.deinit(allocator);
    for (input.paths) |path| {
        if (!validRelativePath(path)) return error.InvalidWatchPath;
        var digest: [32]u8 = @splat(0);
        std.crypto.hash.sha2.Sha256.hash(path, &digest, .{});
        var duplicate = false;
        for (hints.items) |hint| if (std.mem.eql(u8, &hint.digest, &digest)) {
            duplicate = true;
            break;
        };
        if (!duplicate) try hints.append(allocator, .{ .digest = digest });
    }
    std.mem.sort(Hint, hints.items, {}, hintLessThan);

    var requests: std.ArrayList(Request) = .empty;
    defer requests.deinit(allocator);
    if (existing) |*parsed| try requests.appendSlice(allocator, parsed.value.requests);
    if (requests.items.len >= max_pending_requests) return error.WatchPendingLimitExceeded;
    try requests.append(allocator, .{ .request_id = input.request_id, .hints = hints.items });
    std.mem.sort(Request, requests.items, {}, requestLessThan);
    try writePending(allocator, io, root, input.repository_id, requests.items);
}

pub fn readPending(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    repository_id: []const u8,
) !std.json.Parsed(PendingArtifact) {
    const bytes = root.readFileAlloc(io, pending_path, allocator, .limited(max_pending_bytes)) catch |failure| switch (failure) {
        error.StreamTooLong => return error.CorruptWatchPending,
        else => return failure,
    };
    defer allocator.free(bytes);
    var parsed = std.json.parseFromSlice(PendingArtifact, allocator, bytes, .{ .allocate = .alloc_always }) catch return error.CorruptWatchPending;
    errdefer parsed.deinit();
    try validatePending(parsed.value, repository_id);
    return parsed;
}

pub const RefreshStatus = enum {
    idle,
    current,
    refreshed,
    contended,
};

pub const RefreshResult = struct {
    status: RefreshStatus,
    drained_requests: usize = 0,
    generation: [66]u8 = @splat(0),
};

pub const PendingHealthStatus = enum {
    empty,
    ready,
    corrupt,
    unavailable,
};

pub const PendingHealth = struct {
    status: PendingHealthStatus,
    pending_requests: usize = 0,
    pending_hints: usize = 0,
    fingerprint: [32]u8 = @splat(0),
    has_fingerprint: bool = false,
    repair_hint: []const u8 = "",
};

pub fn inspectPending(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    repository_id: []const u8,
) PendingHealth {
    var pending = readPending(allocator, io, root, repository_id) catch |failure| return switch (failure) {
        error.FileNotFound => .{ .status = .empty },
        error.CorruptWatchPending => .{
            .status = .corrupt,
            .repair_hint = "remove the corrupt zgraphy-owned watch request artifact, then rerun zgraphy watch or a default query",
        },
        else => .{
            .status = .unavailable,
            .repair_hint = "restore local watch runtime readability and retry; the default pre-query freshness barrier remains authoritative",
        },
    };
    defer pending.deinit();
    return .{
        .status = .ready,
        .pending_requests = pending.value.summary.pending_requests,
        .pending_hints = pending.value.summary.pending_hints,
        .fingerprint = pending.value.fingerprint,
        .has_fingerprint = true,
    };
}

pub const ForegroundOptions = struct {
    poll_ms: u64 = 250,
    debounce_ms: u64 = 250,
    retry_ms: u64 = 100,
    max_cycles: ?usize = null,
    max_drain_passes: usize = 20,
};

pub const ForegroundSummary = struct {
    schema: []const u8 = "zgraphy.watch.v1",
    schema_version: u32 = 1,
    statechart_id: []const u8 = "zgraphy.watch-coordinator",
    statechart_version: u32 = 1,
    state: State,
    poll_ms: u64,
    debounce_ms: u64,
    retry_ms: u64,
    max_cycles: ?usize,
    max_drain_passes: usize,
    cycles: usize = 0,
    observation_changes: usize = 0,
    refresh_attempts: usize = 0,
    refreshed: usize = 0,
    current: usize = 0,
    contentions: usize = 0,
    failures: usize = 0,
    drained_requests: usize = 0,
    drain_passes: usize = 0,
    pending_requests: usize = 0,
    pending_hints: usize = 0,
    stop_signal: zstd.Application.Lifecycle.ProcessSignal = .none,
    canceled: bool = false,
    capabilities: freshness.Capabilities = freshness.Capabilities.currentM3_7(),
    complete: bool = true,
};

pub fn runForeground(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    config: project.Config,
    options: ForegroundOptions,
) !ForegroundSummary {
    try validateForegroundOptions(options);
    var coordinator = try Coordinator.init(allocator, .{
        .debounce_ms = options.debounce_ms,
        .retry_ms = options.retry_ms,
        .max_pending_hints = @min(max_pending_hints, config.max_files),
        .max_drain_passes = options.max_drain_passes,
    });
    defer coordinator.deinit();
    var summary = ForegroundSummary{
        .state = .idle,
        .poll_ms = options.poll_ms,
        .debounce_ms = options.debounce_ms,
        .retry_ms = options.retry_ms,
        .max_cycles = options.max_cycles,
        .max_drain_passes = options.max_drain_passes,
    };

    const initial_health = inspectPending(allocator, io, root, config.repository_id);
    if (initial_health.status == .corrupt) return error.CorruptWatchPending;
    if (initial_health.status == .unavailable) return error.WatchPendingUnavailable;
    if (initial_health.status == .empty) {
        const startup_paths = [_][]const u8{"repository-state"};
        try requestRefresh(allocator, io, root, .{
            .repository_id = config.repository_id,
            .request_id = "watch-startup",
            .paths = &startup_paths,
        });
    }
    try drainPendingBounded(allocator, io, root, config, options.max_drain_passes, &summary);

    var previous = try observeRepository(allocator, io, root, config);
    var logical_ms: u64 = 0;
    while (options.max_cycles == null or summary.cycles < options.max_cycles.?) {
        const signal = zstd.Application.Lifecycle.requestedSignal();
        if (signal != .none) {
            summary.stop_signal = signal;
            summary.canceled = true;
            break;
        }
        summary.cycles += 1;

        const observed = try observeRepository(allocator, io, root, config);
        if (!std.mem.eql(u8, &previous.fingerprint, &observed.fingerprint)) {
            summary.observation_changes += 1;
            var request_id_buffer: [96]u8 = @splat(0);
            const prefix = std.fmt.bytesToHex(observed.fingerprint[0..8].*, .lower);
            const request_id = try std.fmt.bufPrint(&request_id_buffer, "watch-{d}-{s}", .{ summary.cycles, &prefix });
            const changed_paths = [_][]const u8{"repository-state"};
            try requestRefresh(allocator, io, root, .{
                .repository_id = config.repository_id,
                .request_id = request_id,
                .paths = &changed_paths,
            });
            try coordinator.observe("repository-state", logical_ms);
            previous = observed;
        } else {
            const pending_health = inspectPending(allocator, io, root, config.repository_id);
            if (pending_health.status == .corrupt) return error.CorruptWatchPending;
            if (pending_health.status == .unavailable) return error.WatchPendingUnavailable;
            if (pending_health.status == .ready and coordinator.snapshot.state == .idle) {
                try coordinator.observe("repository-state", logical_ms);
            }
        }

        const decision = try coordinator.advance(logical_ms);
        if (decision.action == .attempt_refresh) {
            _ = try coordinator.leaseAcquired();
            summary.refresh_attempts += 1;
            const result = refreshPending(allocator, io, root, config) catch |failure| {
                summary.failures += 1;
                _ = try coordinator.refreshFailed(logical_ms);
                return failure;
            };
            switch (result.status) {
                .idle => {
                    _ = try coordinator.refreshSucceeded();
                },
                .current, .refreshed => {
                    summary.drained_requests += result.drained_requests;
                    summary.drain_passes += 1;
                    if (result.status == .current) summary.current += 1 else summary.refreshed += 1;
                    _ = try coordinator.refreshSucceeded();
                },
                .contended => {
                    summary.contentions += 1;
                    _ = try coordinator.leaseContended(logical_ms);
                },
            }
        }

        if (options.max_cycles != null and summary.cycles >= options.max_cycles.?) break;
        try (std.Io.Clock.Duration{
            .raw = .fromMilliseconds(@intCast(options.poll_ms)),
            .clock = .awake,
        }).sleep(io);
        logical_ms = std.math.add(u64, logical_ms, options.poll_ms) catch std.math.maxInt(u64);
    }

    var stop = try coordinator.stop();
    if (stop.state == .stopping) stop = try coordinator.stop();
    summary.state = stop.state;
    const final_health = inspectPending(allocator, io, root, config.repository_id);
    if (final_health.status == .corrupt) return error.CorruptWatchPending;
    if (final_health.status == .unavailable) return error.WatchPendingUnavailable;
    summary.pending_requests = final_health.pending_requests;
    summary.pending_hints = final_health.pending_hints;
    return summary;
}

fn drainPendingBounded(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    config: project.Config,
    max_passes: usize,
    summary: *ForegroundSummary,
) !void {
    for (0..max_passes) |_| {
        summary.refresh_attempts += 1;
        const result = refreshPending(allocator, io, root, config) catch |failure| {
            summary.failures += 1;
            return failure;
        };
        switch (result.status) {
            .idle => return,
            .contended => {
                summary.contentions += 1;
                return;
            },
            .current, .refreshed => {
                summary.drained_requests += result.drained_requests;
                summary.drain_passes += 1;
                if (result.status == .current) summary.current += 1 else summary.refreshed += 1;
            },
        }
        const health = inspectPending(allocator, io, root, config.repository_id);
        if (health.status == .corrupt) return error.CorruptWatchPending;
        if (health.status == .unavailable) return error.WatchPendingUnavailable;
        if (health.status == .empty) return;
    }
    if (inspectPending(allocator, io, root, config.repository_id).status == .ready) return error.WatchDrainLimitExceeded;
}

pub fn refreshPending(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    config: project.Config,
) !RefreshResult {
    var pending = readPending(allocator, io, root, config.repository_id) catch |failure| switch (failure) {
        error.FileNotFound => return .{ .status = .idle },
        else => return failure,
    };
    defer pending.deinit();
    var publication = operations.ensureFresh(allocator, io, root, config) catch |failure| switch (failure) {
        error.UpdateInProgress => return .{ .status = .contended },
        else => return failure,
    };
    defer publication.deinit();
    var generation: [66]u8 = @splat(0);
    if (publication.generation.len != generation.len) return error.InvalidWatchGeneration;
    @memcpy(&generation, publication.generation);
    try acknowledge(allocator, io, root, config.repository_id, pending.value.requests);
    return .{
        .status = if (publication.status == .current) .current else .refreshed,
        .drained_requests = pending.value.requests.len,
        .generation = generation,
    };
}

fn acknowledge(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    repository_id: []const u8,
    completed: []const Request,
) !void {
    var lease = try PendingLease.acquire(io, root);
    defer lease.deinit();
    var current = readPending(allocator, io, root, repository_id) catch |failure| switch (failure) {
        error.FileNotFound => return,
        else => return failure,
    };
    defer current.deinit();
    var retained: std.ArrayList(Request) = .empty;
    defer retained.deinit(allocator);
    for (current.value.requests) |request| {
        var covered = false;
        for (completed) |done| if (std.mem.eql(u8, done.request_id, request.request_id)) {
            covered = true;
            break;
        };
        if (!covered) try retained.append(allocator, request);
    }
    if (retained.items.len == 0) {
        root.deleteFile(io, pending_path) catch |failure| switch (failure) {
            error.FileNotFound => {},
            else => return failure,
        };
        return;
    }
    try writePending(allocator, io, root, repository_id, retained.items);
}

fn writePending(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    repository_id: []const u8,
    requests: []const Request,
) !void {
    var summary = PendingSummary{ .pending_requests = requests.len };
    for (requests) |request| summary.pending_hints = std.math.add(usize, summary.pending_hints, request.hints.len) catch return error.WatchPendingLimitExceeded;
    if (summary.pending_requests > max_pending_requests or summary.pending_hints > max_pending_hints) return error.WatchPendingLimitExceeded;
    var artifact = PendingArtifact{
        .schema = pending_schema,
        .schema_version = pending_schema_version,
        .repository_id = repository_id,
        .requests = requests,
        .summary = summary,
        .fingerprint = @splat(0),
        .complete = true,
    };
    artifact.fingerprint = pendingFingerprint(artifact);
    const bytes = try std.json.Stringify.valueAlloc(allocator, artifact, .{ .whitespace = .indent_2 });
    defer allocator.free(bytes);
    if (bytes.len > max_pending_bytes) return error.WatchPendingTooLarge;
    try atomicWrite(allocator, io, root, pending_path, bytes);
}

fn validatePending(artifact: PendingArtifact, repository_id: []const u8) !void {
    if (!artifact.complete or !std.mem.eql(u8, artifact.schema, pending_schema) or artifact.schema_version != pending_schema_version or
        !std.mem.eql(u8, artifact.repository_id, repository_id) or !discovery.isValidRepositoryId(repository_id) or
        artifact.requests.len == 0 or artifact.requests.len > max_pending_requests or
        artifact.summary.pending_requests != artifact.requests.len)
    {
        return error.CorruptWatchPending;
    }
    var hints: usize = 0;
    for (artifact.requests, 0..) |request, index| {
        if (!validRequestId(request.request_id) or request.hints.len == 0) return error.CorruptWatchPending;
        hints = std.math.add(usize, hints, request.hints.len) catch return error.CorruptWatchPending;
        if (hints > max_pending_hints) return error.CorruptWatchPending;
        if (index > 0 and !requestLessThan({}, artifact.requests[index - 1], request)) return error.CorruptWatchPending;
        for (request.hints, 0..) |hint, hint_index| {
            if (hint_index > 0 and !hintLessThan({}, request.hints[hint_index - 1], hint)) return error.CorruptWatchPending;
        }
    }
    if (hints != artifact.summary.pending_hints or !std.mem.eql(u8, &pendingFingerprint(artifact), &artifact.fingerprint)) {
        return error.CorruptWatchPending;
    }
}

fn pendingFingerprint(artifact: PendingArtifact) [32]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    updateBytes(&hasher, artifact.schema);
    updateBytes(&hasher, artifact.repository_id);
    for (artifact.requests) |request| {
        updateBytes(&hasher, request.request_id);
        for (request.hints) |hint| hasher.update(&hint.digest);
    }
    var counts: [16]u8 = @splat(0);
    std.mem.writeInt(u64, counts[0..8], artifact.summary.pending_requests, .little);
    std.mem.writeInt(u64, counts[8..16], artifact.summary.pending_hints, .little);
    hasher.update(&counts);
    var output: [32]u8 = @splat(0);
    hasher.final(&output);
    return output;
}

fn updateBytes(hasher: *std.crypto.hash.sha2.Sha256, value: []const u8) void {
    var length: [8]u8 = @splat(0);
    std.mem.writeInt(u64, &length, value.len, .little);
    hasher.update(&length);
    hasher.update(value);
}

fn requestLessThan(_: void, left: Request, right: Request) bool {
    return std.mem.lessThan(u8, left.request_id, right.request_id);
}

fn hintLessThan(_: void, left: Hint, right: Hint) bool {
    return std.mem.lessThan(u8, &left.digest, &right.digest);
}

fn validateOptions(options: Options) !void {
    if (options.debounce_ms == 0 or options.retry_ms == 0 or options.max_pending_hints == 0 or
        options.max_pending_hints > max_pending_hints or options.max_drain_passes == 0 or options.max_drain_passes > 256)
    {
        return error.InvalidWatchOptions;
    }
}

fn validateForegroundOptions(options: ForegroundOptions) !void {
    if (options.poll_ms == 0 or options.poll_ms > 60_000 or
        options.debounce_ms == 0 or options.debounce_ms > 60_000 or
        options.retry_ms == 0 or options.retry_ms > 60_000 or
        (options.max_cycles != null and options.max_cycles.? == 0) or
        options.max_drain_passes == 0 or options.max_drain_passes > 256)
    {
        return error.InvalidWatchOptions;
    }
}

fn validRequestId(value: []const u8) bool {
    if (value.len == 0 or value.len > max_request_id_bytes) return false;
    for (value) |byte| if (!std.ascii.isAlphanumeric(byte) and byte != '-' and byte != '_' and byte != '.') return false;
    return true;
}

fn validRelativePath(value: []const u8) bool {
    if (value.len == 0 or value.len > std.fs.max_path_bytes or std.fs.path.isAbsolute(value) or
        std.mem.indexOfScalar(u8, value, '\\') != null or std.mem.indexOfScalar(u8, value, 0) != null)
    {
        return false;
    }
    var components = std.mem.splitScalar(u8, value, '/');
    while (components.next()) |component| {
        if (component.len == 0 or std.mem.eql(u8, component, ".") or std.mem.eql(u8, component, "..")) return false;
    }
    return true;
}

fn elapsed(now_ms: u64, then_ms: u64) u64 {
    return if (now_ms >= then_ms) now_ms - then_ms else 0;
}

fn atomicWrite(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    path: []const u8,
    bytes: []const u8,
) !void {
    if (std.mem.lastIndexOfScalar(u8, path, '/')) |slash| try root.createDirPath(io, path[0..slash]);
    for (0..128) |slot| {
        const temporary = try std.fmt.allocPrint(allocator, "{s}.tmp.{d}", .{ path, slot });
        defer allocator.free(temporary);
        const file = root.createFile(io, temporary, .{ .exclusive = true }) catch |failure| switch (failure) {
            error.PathAlreadyExists => continue,
            else => return failure,
        };
        errdefer root.deleteFile(io, temporary) catch {};
        try file.writeStreamingAll(io, bytes);
        file.close(io);
        try root.rename(temporary, root, path, io);
        return;
    }
    return error.AtomicTemporaryPathExhausted;
}
