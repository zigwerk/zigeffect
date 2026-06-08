comptime {
    _ = @import("architecture_test.zig");
    _ = @import("dependency_test.zig");
    _ = @import("effect_test.zig");
    _ = @import("scope_test.zig");
    _ = @import("runtime_test.zig");
    _ = @import("fiber_test.zig");
    _ = @import("causal_backend_conformance_test.zig");
    _ = @import("causal_jsonl_backend_test.zig");
    _ = @import("causal_dot_backend_test.zig");
    _ = @import("causal_otel_backend_test.zig");
    _ = @import("causal_graph_history_backend_test.zig");
    _ = @import("invariants_test.zig");
    _ = @import("layer_test.zig");
    _ = @import("schedule_test.zig");
    _ = @import("services_test.zig");
    _ = @import("support/causal_assertions.zig");
    _ = @import("traits_test.zig");
    _ = @import("data_test.zig");
    _ = @import("match_test.zig");
    _ = @import("pattern_test.zig");
}
