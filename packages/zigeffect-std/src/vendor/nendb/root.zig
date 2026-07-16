const layout = @import("memory/layout.zig");
const constants = @import("constants.zig");

pub const upstream_repository = "https://github.com/Nen-Co/nen-db";
pub const upstream_commit = "c990ef87d74e4dd7e77d3d8d1aafea2d57d12af7";
pub const upstream_version = "0.2.2-beta";
pub const port_toolchain = "zig-0.16";

pub const GraphData = layout.GraphData;
pub const Stats = layout.Stats;
pub const default_nodes: usize = constants.DEFAULT_NODE_POOL_SIZE;
pub const default_edges: usize = constants.DEFAULT_EDGE_POOL_SIZE;
pub const max_nodes: usize = constants.MAX_NODE_POOL_SIZE;
pub const max_edges: usize = constants.MAX_EDGE_POOL_SIZE;
