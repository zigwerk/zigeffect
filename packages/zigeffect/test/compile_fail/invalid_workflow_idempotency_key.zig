const fx = @import("zigeffect");

const Payload = struct {
    account_id: u64,
};

fn badKey(_: Payload) []const u8 {
    return "bad";
}

pub fn main() void {
    const BadWorkflow = fx.workflow
        .Workflow("bad", Payload, void, error{}, fx.TestServices)
        .withIdempotencyKey(badKey);
    _ = BadWorkflow;
}
