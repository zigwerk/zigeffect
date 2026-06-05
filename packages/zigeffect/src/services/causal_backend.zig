const causal = @import("causal.zig");

pub const CausalBackendKind = enum {
    memory,
    json_lines,
    dot,
    opentelemetry,
    nendb_graph,
    cockroach_history,
    async_stream,
};

pub const CausalBackend = struct {
    kind: CausalBackendKind,
    state: ?*anyopaque = null,
    record: *const fn (?*anyopaque, causal.CausalEvent) anyerror!void,
};
