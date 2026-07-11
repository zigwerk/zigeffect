const std = @import("std");
const production = @import("production_wiring.zig");

pub const component_name = "api";
pub fn productionContract() bool { return production.compileContract(); }
pub fn run(allocator: std.mem.Allocator, io: std.Io, environ: std.process.Environ) !void {
    return production.run(allocator, io, environ);
}
