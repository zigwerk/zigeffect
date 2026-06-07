const fx = @import("zigeffect");

const Pair = struct {
    left: u8,
    right: u8,
};

pub fn main() void {
    _ = fx.pattern.capture(Pair{ .left = 1, .right = 2 }, .{
        .left = fx.pattern.bind("same"),
        .right = fx.pattern.bind("same"),
    });
}
