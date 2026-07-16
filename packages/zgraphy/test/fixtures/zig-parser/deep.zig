const std = @import("std");

const fake_source = "pub fn phantom() void { invented(); }";
// pub fn commented_out() void { also_invented(); }

pub const Service = struct {
    pub fn handle(
        self: *Service,
        value: u32,
    ) !void {
        _ = self;
        helper(value);
        std.debug.print("value={d}\n", .{value});
    }
};

fn helper(value: u32) void {
    _ = value;
}

test "service handles" {
    var service = Service{};
    try service.handle(1);
}
