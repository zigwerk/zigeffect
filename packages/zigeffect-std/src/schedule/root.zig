const std = @import("std");

pub const Stepper = struct {
    next_delay_millis: u64,
    factor: u64,
    remaining: usize,

    pub fn next(self: *Stepper) ?u64 {
        if (self.remaining == 0) return null;
        const delay = self.next_delay_millis;
        self.remaining -= 1;
        self.next_delay_millis *= self.factor;
        return delay;
    }
};

pub fn fixed(delay_millis: u64, count: usize) Stepper {
    return .{
        .next_delay_millis = delay_millis,
        .factor = 1,
        .remaining = count,
    };
}

pub fn exponential(initial_millis: u64, factor: u64, count: usize) Stepper {
    return .{
        .next_delay_millis = initial_millis,
        .factor = factor,
        .remaining = count,
    };
}

test "Schedule fixed and exponential steppers are deterministic" {
    var fixed_stepper = fixed(10, 2);
    try std.testing.expectEqual(@as(?u64, 10), fixed_stepper.next());
    try std.testing.expectEqual(@as(?u64, 10), fixed_stepper.next());
    try std.testing.expectEqual(@as(?u64, null), fixed_stepper.next());

    var exponential_stepper = exponential(5, 3, 3);
    try std.testing.expectEqual(@as(?u64, 5), exponential_stepper.next());
    try std.testing.expectEqual(@as(?u64, 15), exponential_stepper.next());
    try std.testing.expectEqual(@as(?u64, 45), exponential_stepper.next());
    try std.testing.expectEqual(@as(?u64, null), exponential_stepper.next());
}
