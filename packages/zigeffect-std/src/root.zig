const std = @import("std");

pub const fx = @import("zigeffect");
pub const Service = @import("service/root.zig");
pub const Secrets = @import("secrets/root.zig");
pub const Json = @import("json/root.zig");
pub const Jsonl = @import("jsonl/root.zig");
pub const Path = @import("path/root.zig");
pub const Config = @import("config/root.zig");
pub const Clock = @import("clock/root.zig");
pub const Schedule = @import("schedule/root.zig");
pub const Cli = @import("cli/root.zig");
pub const Console = @import("console/root.zig");
pub const Env = @import("env/root.zig");
pub const FileSystem = @import("filesystem/root.zig");
pub const Workspace = @import("workspace/root.zig");
pub const Process = @import("process/root.zig");
pub const Testing = @import("testing/root.zig");
pub const Sql = @import("sql/root.zig");
pub const Http = @import("http/root.zig");
pub const Agent = @import("agent/root.zig");

test "zigeffect-std re-exports the engine facade" {
    try std.testing.expect(@hasDecl(fx, "effect"));
}
