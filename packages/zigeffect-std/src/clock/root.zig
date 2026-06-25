const std = @import("std");

pub const Instant = struct {
    millis: u64,
};

pub const FakeClock = struct {
    current_millis: u64,
    slept_millis: u64 = 0,
    sleep_count: usize = 0,

    pub fn init(start_millis: u64) FakeClock {
        return .{ .current_millis = start_millis };
    }

    pub fn now(self: FakeClock) Instant {
        return .{ .millis = self.current_millis };
    }

    pub fn advance(self: *FakeClock, millis: u64) void {
        self.current_millis += millis;
    }

    pub fn sleep(self: *FakeClock, millis: u64) void {
        self.slept_millis += millis;
        self.sleep_count += 1;
        self.advance(millis);
    }
};

test "Clock fake advances and records sleeps" {
    var clock = FakeClock.init(100);

    try std.testing.expectEqual(@as(u64, 100), clock.now().millis);
    clock.advance(25);
    try std.testing.expectEqual(@as(u64, 125), clock.now().millis);
    clock.sleep(50);
    try std.testing.expectEqual(@as(u64, 175), clock.now().millis);
    try std.testing.expectEqual(@as(u64, 50), clock.slept_millis);
    try std.testing.expectEqual(@as(usize, 1), clock.sleep_count);
}
