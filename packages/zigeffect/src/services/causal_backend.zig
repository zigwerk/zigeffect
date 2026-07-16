const causal = @import("causal.zig");

pub const CausalBackendKind = enum {
    /// Reference deterministic backend owned by `CausalStore`.
    memory,
    /// JSON Lines artifact adapter for CLIs, CI jobs, and agent tools.
    json_lines,
    /// DOT artifact adapter for graph visualization.
    dot,
    /// Production bridge into OpenTelemetry span and event ecosystems.
    opentelemetry,
    /// Embedded Zig graph-query backend used by canonical application runtimes.
    nendb_graph,
    /// Future non-blocking event stream adapter for async runtimes.
    async_stream,
    /// One runtime stream delivered to multiple independent exporters.
    fanout,
};

pub const CausalBackend = struct {
    kind: CausalBackendKind,
    state: ?*anyopaque = null,
    /// Receives a stored event after the in-memory store assigns its event id.
    /// Backends that retain string fields must copy them before returning.
    record: *const fn (?*anyopaque, causal.CausalEvent) anyerror!void,
};

pub const CausalFanoutBackendState = struct {
    backends: []const CausalBackend,
    attempted_write_count: u64 = 0,
    successful_write_count: u64 = 0,
    failed_write_count: u64 = 0,

    pub fn init(backends: []const CausalBackend) CausalFanoutBackendState {
        return .{ .backends = backends };
    }

    pub fn backend(self: *CausalFanoutBackendState) CausalBackend {
        return .{
            .kind = .fanout,
            .state = self,
            .record = recordFanout,
        };
    }

    pub fn attemptedWriteCount(self: *const CausalFanoutBackendState) u64 {
        return self.attempted_write_count;
    }

    pub fn successfulWriteCount(self: *const CausalFanoutBackendState) u64 {
        return self.successful_write_count;
    }

    pub fn failedWriteCount(self: *const CausalFanoutBackendState) u64 {
        return self.failed_write_count;
    }
};

fn recordFanout(raw: ?*anyopaque, event: causal.CausalEvent) anyerror!void {
    const state: *CausalFanoutBackendState = @ptrCast(@alignCast(raw.?));
    var failed = false;
    for (state.backends) |backend| {
        state.attempted_write_count += 1;
        backend.record(backend.state, event) catch {
            state.failed_write_count += 1;
            failed = true;
            continue;
        };
        state.successful_write_count += 1;
    }
    if (failed) return error.CausalFanoutWriteFailed;
}
