const fx = @import("zigeffect");

fn escape(value: *u32) *u32 {
    return value;
}

pub fn main() !void {
    var table = fx.ResourceTable(u32).init(@import("std").heap.page_allocator, null);
    defer table.deinit();
    const handle = try table.open(1, null);
    _ = try table.with(handle, escape);
}
