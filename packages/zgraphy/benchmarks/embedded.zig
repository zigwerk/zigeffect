pub const corpus = @embedFile("corpus.v1.json");
pub const zig_ambiguity = @embedFile("gold/zig-ambiguity.canonical.v1.json");
pub const fullstack_orders = @embedFile("gold/fullstack-orders.canonical.v1.json");
pub const mutation_pruning = @embedFile("gold/mutation-pruning.canonical.v1.json");
pub const graphify_zig_ambiguity = @embedFile("adapter-fixtures/graphify-0.9.17/zig-ambiguity.graph.json");
pub const quality_matrix = @embedFile("baselines/quality-matrix.v1.json");
pub const resource_matrix = @embedFile("baselines/resource-matrix.v1.json");
pub const freshness_receipt = @embedFile("baselines/freshness-receipt.v1.json");
