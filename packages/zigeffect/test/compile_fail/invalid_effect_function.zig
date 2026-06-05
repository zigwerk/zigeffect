const fx = @import("zigeffect");

fn badEffect(_: *fx.Context(fx.TestServices), _: u8) error{}!u32 {
    return 1;
}

pub fn main() void {
    _ = fx.Effect(u32, error{}, fx.TestServices).fromFn(badEffect);
}
