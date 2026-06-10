const fx = @import("zigeffect");

const Payload = struct {
    invoice_id: u64,
};

fn badKey(_: Payload) []const u8 {
    return "bad";
}

pub fn main() void {
    const BadActivity = fx.workflow
        .Activity("bad-activity", Payload, void, error{}, fx.TestServices)
        .withIdempotencyKey(badKey);
    _ = BadActivity;
}
