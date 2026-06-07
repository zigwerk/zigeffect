const std = @import("std");

pub const Duration = union(enum) {
    const Self = @This();

    finite: i128,
    infinite,

    pub fn zero() Self {
        return .{ .finite = 0 };
    }

    pub fn nanos(value: i128) Self {
        return finiteNanos(value);
    }

    pub fn micros(value: i128) Self {
        return scale(value, 1_000);
    }

    pub fn millis(value: i128) Self {
        return scale(value, 1_000_000);
    }

    pub fn seconds(value: i128) Self {
        return scale(value, 1_000_000_000);
    }

    pub fn minutes(value: i128) Self {
        return scale(value, 60 * 1_000_000_000);
    }

    pub fn hours(value: i128) Self {
        return scale(value, 60 * 60 * 1_000_000_000);
    }

    pub fn infinity() Self {
        return .infinite;
    }

    pub fn isFinite(self: Self) bool {
        return switch (self) {
            .finite => true,
            .infinite => false,
        };
    }

    pub fn isInfinite(self: Self) bool {
        return !self.isFinite();
    }

    pub fn plus(self: Self, other: Self) Self {
        return switch (self) {
            .infinite => infinity(),
            .finite => |left| switch (other) {
                .infinite => infinity(),
                .finite => |right| finiteNanos(std.math.add(i128, left, right) catch return infinity()),
            },
        };
    }

    pub fn minus(self: Self, other: Self) Self {
        return switch (self) {
            .infinite => infinity(),
            .finite => |left| switch (other) {
                .infinite => zero(),
                .finite => |right| finiteNanos(std.math.sub(i128, left, right) catch return zero()),
            },
        };
    }

    pub fn toNanos(self: Self) ?i128 {
        return switch (self) {
            .finite => |value| value,
            .infinite => null,
        };
    }

    pub fn toMillis(self: Self) ?i128 {
        if (self.toNanos()) |value| return @divTrunc(value, 1_000_000);
        return null;
    }

    fn scale(value: i128, factor: i128) Self {
        if (value <= 0) return zero();
        return finiteNanos(std.math.mul(i128, value, factor) catch return infinity());
    }

    fn finiteNanos(value: i128) Self {
        if (value <= 0) return zero();
        return .{ .finite = value };
    }
};
