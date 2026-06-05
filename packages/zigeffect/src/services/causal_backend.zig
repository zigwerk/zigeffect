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
    /// Embedded Zig graph-query backend candidate for local agent workflows.
    nendb_graph,
    /// Durable history backend for app, CI, or fleet audit once semantics are stable.
    cockroach_history,
    /// Future non-blocking event stream adapter for async runtimes.
    async_stream,
};

pub const CausalBackend = struct {
    kind: CausalBackendKind,
    state: ?*anyopaque = null,
    /// Receives a stored event after the in-memory store assigns its event id.
    /// Backends that retain string fields must copy them before returning.
    record: *const fn (?*anyopaque, causal.CausalEvent) anyerror!void,
};
