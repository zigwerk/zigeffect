const std = @import("std");
const zstd = @import("zigeffect_std");

pub fn initAlloc(allocator: std.mem.Allocator) !*zstd.Clock.FakeClock {
    const clock = try allocator.create(zstd.Clock.FakeClock);
    clock.* = zstd.Clock.FakeClock.init(0);
    return clock;
}

pub fn deinit(allocator: std.mem.Allocator, clock: *zstd.Clock.FakeClock) void {
    allocator.destroy(clock);
}
