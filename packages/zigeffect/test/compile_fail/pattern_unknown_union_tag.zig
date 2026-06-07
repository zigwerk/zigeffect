const fx = @import("zigeffect");

const Command = union(enum) {
    quit,
};

fn onQuit() []const u8 {
    return "quit";
}

fn onScore(_: u8) []const u8 {
    return "score";
}

pub fn main() void {
    _ = fx.pattern.exhaustive([]const u8, @as(Command, .quit), .{
        .quit = fx.pattern.arm(fx.pattern.any, onQuit),
        .score = fx.pattern.arm(fx.pattern.any, onScore),
    });
}
