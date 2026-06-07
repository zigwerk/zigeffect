const std = @import("std");
const duration_mod = @import("duration.zig");

const nanos_per_second: i128 = 1_000_000_000;
const seconds_per_day: i128 = 86_400;
const nanos_per_day: i128 = seconds_per_day * nanos_per_second;

pub const DateTime = union(enum) {
    const Self = @This();

    utc: i128,

    pub const ParseError = error{InvalidDateTime};

    pub fn fromEpochNanos(nanos: i128) Self {
        return .{ .utc = nanos };
    }

    pub fn parseIsoUtc(text: []const u8) ParseError!Self {
        if (text.len < 20) return error.InvalidDateTime;
        if (text[4] != '-' or text[7] != '-' or text[10] != 'T' or text[13] != ':' or text[16] != ':') {
            return error.InvalidDateTime;
        }

        const year = try parseInt(i64, text[0..4]);
        const month = try parseInt(u32, text[5..7]);
        const day = try parseInt(u32, text[8..10]);
        const hour = try parseInt(u32, text[11..13]);
        const minute = try parseInt(u32, text[14..16]);
        const second = try parseInt(u32, text[17..19]);

        if (month < 1 or month > 12 or day < 1 or day > 31 or hour > 23 or minute > 59 or second > 59) {
            return error.InvalidDateTime;
        }

        var index: usize = 19;
        var nanos: i128 = 0;
        if (index < text.len and text[index] == '.') {
            index += 1;
            const start = index;
            while (index < text.len and text[index] != 'Z') : (index += 1) {
                if (text[index] < '0' or text[index] > '9') return error.InvalidDateTime;
                if (index - start >= 9) return error.InvalidDateTime;
                nanos = (nanos * 10) + (text[index] - '0');
            }
            if (index == start) return error.InvalidDateTime;
            var digits = index - start;
            while (digits < 9) : (digits += 1) {
                nanos *= 10;
            }
        }

        if (index != text.len - 1 or text[index] != 'Z') return error.InvalidDateTime;

        const days = daysFromCivil(year, month, day);
        const day_seconds = (@as(i128, hour) * 60 * 60) + (@as(i128, minute) * 60) + @as(i128, second);
        return fromEpochNanos((days * nanos_per_day) + (day_seconds * nanos_per_second) + nanos);
    }

    pub fn formatIsoUtc(self: Self, allocator: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
        const nanos = self.epochNanos();
        const days = @divFloor(nanos, nanos_per_day);
        const day_nanos = @mod(nanos, nanos_per_day);
        const civil = civilFromDays(days);
        const hour: u32 = @intCast(@divTrunc(day_nanos, 60 * 60 * nanos_per_second));
        const after_hour = @mod(day_nanos, 60 * 60 * nanos_per_second);
        const minute: u32 = @intCast(@divTrunc(after_hour, 60 * nanos_per_second));
        const after_minute = @mod(after_hour, 60 * nanos_per_second);
        const second: u32 = @intCast(@divTrunc(after_minute, nanos_per_second));
        const fractional: u32 = @intCast(@mod(after_minute, nanos_per_second));

        return std.fmt.allocPrint(
            allocator,
            "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}.{d:0>9}Z",
            .{ @as(u32, @intCast(civil.year)), civil.month, civil.day, hour, minute, second, fractional },
        );
    }

    pub fn epochNanos(self: Self) i128 {
        return switch (self) {
            .utc => |value| value,
        };
    }

    pub fn distance(self: Self, other: Self) duration_mod.Duration {
        const left = self.epochNanos();
        const right = other.epochNanos();
        if (left >= right) return duration_mod.Duration.nanos(left - right);
        return duration_mod.Duration.nanos(right - left);
    }
};

fn parseInt(comptime T: type, text: []const u8) DateTime.ParseError!T {
    return std.fmt.parseInt(T, text, 10) catch error.InvalidDateTime;
}

fn daysFromCivil(year_value: i64, month: u32, day: u32) i128 {
    var year: i128 = year_value;
    if (month <= 2) year -= 1;
    const era = @divFloor(year, 400);
    const year_of_era = year - (era * 400);
    const shifted_month: i128 = if (month > 2) month - 3 else month + 9;
    const day_of_year = @divTrunc((153 * shifted_month) + 2, 5) + day - 1;
    const day_of_era = (year_of_era * 365) + @divTrunc(year_of_era, 4) - @divTrunc(year_of_era, 100) + day_of_year;
    return (era * 146_097) + day_of_era - 719_468;
}

const CivilDate = struct {
    year: i64,
    month: u32,
    day: u32,
};

fn civilFromDays(days: i128) CivilDate {
    const shifted = days + 719_468;
    const era = @divFloor(shifted, 146_097);
    const day_of_era = shifted - (era * 146_097);
    const year_of_era = @divTrunc(day_of_era - @divTrunc(day_of_era, 1460) + @divTrunc(day_of_era, 36_524) - @divTrunc(day_of_era, 146_096), 365);
    var year = year_of_era + (era * 400);
    const day_of_year = day_of_era - ((365 * year_of_era) + @divTrunc(year_of_era, 4) - @divTrunc(year_of_era, 100));
    const month_prime = @divTrunc((5 * day_of_year) + 2, 153);
    const day = day_of_year - @divTrunc((153 * month_prime) + 2, 5) + 1;
    const month = if (month_prime < 10) month_prime + 3 else month_prime - 9;
    if (month <= 2) year += 1;

    return .{
        .year = @intCast(year),
        .month = @intCast(month),
        .day = @intCast(day),
    };
}
