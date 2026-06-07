const fx = @import("zigeffect");

const Command = union(enum) {
    quit,
    score: u8,
};

fn onQuit() []const u8 {
    return "quit";
}

pub fn main() void {
    _ = fx.pattern.exhaustive([]const u8, @as(Command, .quit), .{
        .quit = fx.pattern.arm(fx.pattern.any, onQuit),
    });
}
