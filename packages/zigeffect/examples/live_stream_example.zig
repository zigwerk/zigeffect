//! Framework-internal live-attach emitter; not application scaffolding.
//! This deliberately constructs a store to exercise the backend contract.
//! Live-attach engine emitter — the runnable engine half of the live-attach loop.
//!
//!     zig build live-stream-example && ./zig-out/bin/zigeffect-live-stream-example \
//!       | bun packages/zigeffect/workbench/src/collector/collector.ts
//!
//! then open the workbench at ?live=ws://127.0.0.1:4500/live.
//!
//! It runs a representative causal scenario (a run that opens a scope, forks two
//! fibers, records a metric, suspends + resumes one fiber, then completes)
//! through a `CausalNdjsonTap` and writes the recorded events as NDJSON to
//! stdout — exactly the feed the collector ingests. `buildLiveStreamNdjson` is
//! the testable core; `main` streams it.

const std = @import("std");
const fx = @import("zigeffect");

/// Run the scenario through a CausalNdjsonTap and return the recorded events as
/// NDJSON (one JSON object per line). Caller owns the returned bytes.
pub fn buildLiveStreamNdjson(allocator: std.mem.Allocator) ![]u8 {
    var tap = fx.causal_hub_backend.CausalNdjsonTapState.init(allocator);
    defer tap.deinit();

    var store = fx.CausalStore.init(allocator);
    defer store.deinit();
    store.attachBackend(tap.backend());

    const run_id = store.nextRunId();
    const scope_id = store.nextScopeId();

    const run = try store.record(.{ .kind = .run_started, .run_id = run_id, .status = "started", .label = "live-stream demo" });
    const scope = try store.record(.{ .kind = .scope_opened, .run_id = run_id, .scope_id = scope_id, .parent_id = run, .status = "opened", .label = "request scope" });

    const worker = try store.record(.{ .kind = .fiber_forked, .run_id = run_id, .scope_id = scope_id, .fiber_id = 1, .parent_id = scope, .status = "pending", .label = "worker" });
    const reporter = try store.record(.{ .kind = .fiber_forked, .run_id = run_id, .scope_id = scope_id, .fiber_id = 2, .parent_id = scope, .status = "pending", .label = "reporter" });
    _ = try store.record(.{ .kind = .fiber_started, .run_id = run_id, .scope_id = scope_id, .fiber_id = 1, .parent_id = worker, .status = "running" });
    _ = try store.record(.{ .kind = .fiber_started, .run_id = run_id, .scope_id = scope_id, .fiber_id = 2, .parent_id = reporter, .status = "running" });

    _ = try store.record(.{ .kind = .metric_recorded, .run_id = run_id, .scope_id = scope_id, .fiber_id = 2, .status = "ready", .label = "requests_total" });

    const suspended = try store.record(.{ .kind = .fiber_suspended, .run_id = run_id, .scope_id = scope_id, .fiber_id = 1, .status = "suspended", .label = "await io" });
    _ = try store.record(.{ .kind = .fiber_resumed, .run_id = run_id, .scope_id = scope_id, .fiber_id = 1, .parent_id = suspended, .status = "running", .label = "io ready" });

    _ = try store.record(.{ .kind = .scope_closed, .run_id = run_id, .scope_id = scope_id, .status = "closed", .label = "request scope" });
    _ = try store.record(.{ .kind = .run_completed, .run_id = run_id, .status = "success", .label = "live-stream demo" });

    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    _ = try tap.drain(&out);
    return out.toOwnedSlice(allocator);
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const ndjson = try buildLiveStreamNdjson(allocator);
    defer allocator.free(ndjson);

    try std.Io.File.stdout().writeStreamingAll(init.io, ndjson);
}

test "buildLiveStreamNdjson emits well-formed NDJSON for the collector feed" {
    const allocator = std.testing.allocator;
    const ndjson = try buildLiveStreamNdjson(allocator);
    defer allocator.free(ndjson);

    var lines: usize = 0;
    var it = std.mem.tokenizeScalar(u8, ndjson, '\n');
    while (it.next()) |line| {
        lines += 1;
        // Each line is a complete JSON object with the canonical engine fields.
        try std.testing.expect(line[0] == '{' and line[line.len - 1] == '}');
        try std.testing.expect(std.mem.indexOf(u8, line, "\"id\":") != null);
        try std.testing.expect(std.mem.indexOf(u8, line, "\"kind\":") != null);
    }
    // run + scope + 2 forks + 2 starts + metric + suspend + resume + close + complete.
    try std.testing.expectEqual(@as(usize, 11), lines);
    // The lifecycle endpoints are present.
    try std.testing.expect(std.mem.indexOf(u8, ndjson, "\"kind\":\"run_started\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ndjson, "\"kind\":\"fiber_suspended\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ndjson, "\"kind\":\"run_completed\"") != null);
}
