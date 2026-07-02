//! Multi-service hub emitter — two zigeffect services streaming causal NDJSON.
//!
//!     zig build multi-service-stream-example && ./zig-out/bin/zigeffect-multi-service-stream-example \
//!       | bun packages/zigeffect/workbench/src/hub/hub.ts
//!
//! then open the workbench at ?hub=ws://127.0.0.1:4600/live. The hub
//! demultiplexes the interleaved lines by `service_key`, so the services rail
//! auto-discovers `payments-api` and `ledger` with their layers.
//!
//! Each service is its own `CausalStore` created with `initForService`, which
//! stamps the service identity onto every event — the per-event fields only
//! carry the layer tags. `buildMultiServiceNdjson` is the testable core;
//! `main` streams it.

const std = @import("std");
const fx = @import("zigeffect");

fn drainTap(allocator: std.mem.Allocator, tap: *fx.causal_hub_backend.CausalNdjsonTapState) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    _ = try tap.drain(&out);
    return out.toOwnedSlice(allocator);
}

/// A payments service: a request scope that misses its gateway dependency
/// (integration layer) but acquires its database (persistence layer).
fn buildPaymentsNdjson(allocator: std.mem.Allocator) ![]u8 {
    var tap = fx.causal_hub_backend.CausalNdjsonTapState.init(allocator);
    defer tap.deinit();

    var store = fx.CausalStore.initForService(allocator, "payments-api");
    defer store.deinit();
    store.attachBackend(tap.backend());

    const persistence_layer = store.nextLayerId();
    const integration_layer = store.nextLayerId();
    const run_id = store.nextRunId();
    const scope_id = store.nextScopeId();

    const run = try store.record(.{ .kind = .run_started, .run_id = run_id, .status = "started", .label = "payments run" });
    const scope = try store.record(.{ .kind = .scope_opened, .run_id = run_id, .scope_id = scope_id, .parent_id = run, .status = "opened", .label = "request scope" });
    _ = try store.record(.{ .kind = .service_required, .run_id = run_id, .scope_id = scope_id, .parent_id = scope, .layer_id = integration_layer, .layer_name = "integration", .status = "missing", .label = "PaymentGateway" });
    _ = try store.record(.{ .kind = .resource_acquired, .run_id = run_id, .scope_id = scope_id, .parent_id = scope, .layer_id = persistence_layer, .layer_name = "persistence", .status = "success", .label = "primary db" });
    _ = try store.record(.{ .kind = .scope_closed, .run_id = run_id, .scope_id = scope_id, .status = "closed", .label = "request scope" });
    _ = try store.record(.{ .kind = .run_completed, .run_id = run_id, .status = "success", .label = "payments run" });

    return drainTap(allocator, &tap);
}

/// A ledger service: posts an entry against its database (persistence layer),
/// then exhausts a retry policy (resilience layer).
fn buildLedgerNdjson(allocator: std.mem.Allocator) ![]u8 {
    var tap = fx.causal_hub_backend.CausalNdjsonTapState.init(allocator);
    defer tap.deinit();

    var store = fx.CausalStore.initForService(allocator, "ledger");
    defer store.deinit();
    store.attachBackend(tap.backend());

    const persistence_layer = store.nextLayerId();
    const resilience_layer = store.nextLayerId();
    const run_id = store.nextRunId();
    const scope_id = store.nextScopeId();

    const run = try store.record(.{ .kind = .run_started, .run_id = run_id, .status = "started", .label = "ledger run" });
    const scope = try store.record(.{ .kind = .scope_opened, .run_id = run_id, .scope_id = scope_id, .parent_id = run, .status = "opened", .label = "post entry" });
    _ = try store.record(.{ .kind = .resource_acquired, .run_id = run_id, .scope_id = scope_id, .parent_id = scope, .layer_id = persistence_layer, .layer_name = "persistence", .status = "success", .label = "ledger db" });
    _ = try store.record(.{ .kind = .schedule_decision, .run_id = run_id, .parent_id = run, .layer_id = resilience_layer, .layer_name = "resilience", .status = "exhausted", .label = "retry policy" });
    _ = try store.record(.{ .kind = .scope_closed, .run_id = run_id, .scope_id = scope_id, .status = "closed", .label = "post entry" });
    _ = try store.record(.{ .kind = .run_completed, .run_id = run_id, .status = "failure", .label = "ledger run" });

    return drainTap(allocator, &tap);
}

/// Alternate the two services' lines to simulate concurrent processes sharing
/// one pipe — the hub must demultiplex purely by each line's `service_key`.
fn interleaveLines(allocator: std.mem.Allocator, first: []const u8, second: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    var first_lines = std.mem.tokenizeScalar(u8, first, '\n');
    var second_lines = std.mem.tokenizeScalar(u8, second, '\n');
    while (true) {
        const a = first_lines.next();
        const b = second_lines.next();
        if (a == null and b == null) break;
        if (a) |line| {
            try out.appendSlice(allocator, line);
            try out.append(allocator, '\n');
        }
        if (b) |line| {
            try out.appendSlice(allocator, line);
            try out.append(allocator, '\n');
        }
    }
    return out.toOwnedSlice(allocator);
}

/// Run both service scenarios and return their events as one interleaved
/// NDJSON stream (the hub ingest feed). Caller owns the returned bytes.
pub fn buildMultiServiceNdjson(allocator: std.mem.Allocator) ![]u8 {
    const payments = try buildPaymentsNdjson(allocator);
    defer allocator.free(payments);
    const ledger = try buildLedgerNdjson(allocator);
    defer allocator.free(ledger);
    return interleaveLines(allocator, payments, ledger);
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const ndjson = try buildMultiServiceNdjson(allocator);
    defer allocator.free(ndjson);

    try std.Io.File.stdout().writeStreamingAll(init.io, ndjson);
}

test "buildMultiServiceNdjson interleaves two service_key-tagged streams for the hub" {
    const allocator = std.testing.allocator;
    const ndjson = try buildMultiServiceNdjson(allocator);
    defer allocator.free(ndjson);

    var payments_lines: usize = 0;
    var ledger_lines: usize = 0;
    var it = std.mem.tokenizeScalar(u8, ndjson, '\n');
    while (it.next()) |line| {
        try std.testing.expect(line[0] == '{' and line[line.len - 1] == '}');
        // Every line carries a service identity — stamped by initForService,
        // not by per-event fields.
        if (std.mem.indexOf(u8, line, "\"service_key\":\"payments-api\"") != null) {
            payments_lines += 1;
        } else if (std.mem.indexOf(u8, line, "\"service_key\":\"ledger\"") != null) {
            ledger_lines += 1;
        } else {
            return error.LineWithoutServiceKey;
        }
    }
    // run + scope + 2 mid events + close + complete, per service.
    try std.testing.expectEqual(@as(usize, 6), payments_lines);
    try std.testing.expectEqual(@as(usize, 6), ledger_lines);

    // The streams are interleaved (not one service then the other): the first
    // two lines belong to different services.
    var head = std.mem.tokenizeScalar(u8, ndjson, '\n');
    const first = head.next().?;
    const second = head.next().?;
    try std.testing.expect(std.mem.indexOf(u8, first, "\"service_key\":\"payments-api\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, second, "\"service_key\":\"ledger\"") != null);

    // Layer identity rides along on the wire.
    try std.testing.expect(std.mem.indexOf(u8, ndjson, "\"layer_name\":\"integration\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ndjson, "\"layer_name\":\"persistence\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ndjson, "\"layer_name\":\"resilience\"") != null);
}
