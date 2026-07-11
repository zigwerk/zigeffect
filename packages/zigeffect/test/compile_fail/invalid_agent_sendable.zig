const fx = @import("zigeffect");

pub fn main() void {
    fx.assertAgentSendable(struct { value: *u32 });
}
