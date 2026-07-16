const std = @import("std");
const production = @import("production_wiring.zig");

pub const component_name = "worker";
pub const RuntimeInputs = production.RuntimeInputs;
pub const ApplicationConfig = production.ApplicationConfig;
pub const OrderProcessor = production.OrderProcessor;
pub const WorkerLease = production.WorkerLease;
pub const rootLayer = production.rootLayer;
pub const program = production.program;
pub fn productionContract() bool {
    return production.compileContract();
}
pub fn run(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, environ: std.process.Environ) !void {
    return production.run(allocator, io, root, environ);
}
