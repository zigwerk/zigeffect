const std = @import("std");

pub const fx = @import("zigeffect");
pub const Cli = @import("cli/root.zig");
pub const Console = @import("console/root.zig");
pub const Env = @import("env/root.zig");
pub const FileSystem = @import("filesystem/root.zig");

test "zigeffect-std re-exports the engine facade" {
    try std.testing.expect(@hasDecl(fx, "effect"));
}
